#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\filter_shared;

#insert scripts\shared\shared.gsh;

#namespace explode;

#define MAX_SCREEN_FX_RANGE						600
#define EXPLOSION_DIRT_DURATION					2000
#define EXPLOSION_DIRT_FADE_TIME				500
#define SLIDE_DIRT_DURATION						300
#define SLIDE_DIRT_FADE_TIME					300
#define FALL_DAMAGE_DIRT_DURATION				1000
#define FALL_DAMAGE_FADE_TIME					500

REGISTER_SYSTEM( "explode", &__init__, undefined )		

function __init__()
{
	level.dirt_enable_explosion = GetDvarInt( "scr_dirt_enable_explosion", 1 );
	level.dirt_enable_slide = GetDvarInt( "scr_dirt_enable_slide", 1 );
	level.dirt_enable_fall_damage = GetDvarInt( "scr_dirt_enable_fall_damage", 1 );
	
	callback::on_localplayer_spawned( &localplayer_spawned );
	
	/#
	level thread updateDvars();
	#/
}

/#
function updateDvars()
{
	while(1)
	{
		level.dirt_enable_explosion = GetDvarInt( "scr_dirt_enable_explosion", level.dirt_enable_explosion );
		level.dirt_enable_slide = GetDvarInt( "scr_dirt_enable_slide", level.dirt_enable_slide );
		level.dirt_enable_fall_damage = GetDvarInt( "scr_dirt_enable_fall_damage", level.dirt_enable_fall_damage );
		
		wait(1.0);
	}
}
#/

function localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	if ( level.dirt_enable_explosion || level.dirt_enable_slide || level.dirt_enable_fall_damage )
	{
		filter::init_filter_sprite_dirt( self );
		filter::disable_filter_sprite_dirt( self, FILTER_INDEX_DIRT );
		
		if( level.dirt_enable_explosion )
		{
			self thread watchForExplosion( localClientNum );
		}
		
		if( level.dirt_enable_slide )
		{
			self thread watchForPlayerSlide( localClientNum );
		}
		
		if( level.dirt_enable_fall_damage )
		{
			self thread watchForPlayerFallDamage( localClientNum );
		}
	}
}

function watchForPlayerFallDamage( localClientNum )
{
	self endon ( "entityshutdown" );
	seed = 0;
	xDir = 0.0;
	yDir = 270.0;
	while( 1 )
	{
		self waittill( "fall_damage" );
		self thread doTheDirty( localclientnum, xDir, yDir, 1.0, FALL_DAMAGE_DIRT_DURATION, FALL_DAMAGE_FADE_TIME );
	}
}

function watchForPlayerSlide( localClientNum )
{
	self endon ( "entityshutdown" );
	seed = 0;
	self.wasPlayerSliding = false;
	xDir = 0.0;
	yDir = 6000.0;
	while( 1 )
	{
		self.isPlayerSliding = self IsPlayerSliding();
		if( self.isPlayerSliding )
		{
			if( !self.wasPlayerSliding )
			{
				self notify( "endTheDirty" );
				seed = RandomFloatRange( 0.0, 1.0 );
			}
			filter::set_filter_sprite_dirt_opacity( self, FILTER_INDEX_DIRT, 1.0 );
			filter::set_filter_sprite_dirt_seed_offset( self, FILTER_INDEX_DIRT, seed );
			filter::enable_filter_sprite_dirt( self, FILTER_INDEX_DIRT );
			filter::set_filter_sprite_dirt_source_position( self, FILTER_INDEX_DIRT, xDir, yDir, 1.0 );
			filter::set_filter_sprite_dirt_elapsed( self, FILTER_INDEX_DIRT, GetServerTime( localClientNum ) );
		}
		else if( self.wasPlayerSliding )
		{
			self thread doTheDirty( localclientnum, xDir, yDir, 1.0, SLIDE_DIRT_DURATION, SLIDE_DIRT_FADE_TIME );
		}
		
		self.wasPlayerSliding = self.isPlayerSliding;
		WAIT_CLIENT_FRAME;
	}
}

function doTheDirty( localClientNum, right, up, distance, dirtDuration, dirtFadeTime )
{
	self endon( "entityshutdown" );
	self notify( "doTheDirty" );
	self endon( "doTheDirty" );
	self endon( "endTheDirty" );
	
	filter::enable_filter_sprite_dirt( self, FILTER_INDEX_DIRT );
	filter::set_filter_sprite_dirt_seed_offset( self, FILTER_INDEX_DIRT, RandomFloatRange( 0.0, 1.0 ) );
	                                           
	startTime = GetServerTime( localClientNum );
	currentTime = startTime;
	elapsedTime = 0;
	while( elapsedTime < dirtDuration )
	{
		if( elapsedTime > dirtDuration - dirtFadeTime )
		{
			filter::set_filter_sprite_dirt_opacity( self, FILTER_INDEX_DIRT, ( ( dirtDuration - elapsedTime ) / dirtFadeTime ) );
		}
		else
		{
			filter::set_filter_sprite_dirt_opacity( self, FILTER_INDEX_DIRT, 1.0 );
		}
		
		filter::set_filter_sprite_dirt_source_position( self, FILTER_INDEX_DIRT, right, up, distance );
		filter::set_filter_sprite_dirt_elapsed( self, FILTER_INDEX_DIRT, currentTime );
		WAIT_CLIENT_FRAME;
		currentTime = GetServerTime( localClientNum );
		elapsedTime = currentTime - startTime;
	}
	
	filter::disable_filter_sprite_dirt( self, FILTER_INDEX_DIRT );
}

function watchForExplosion( localClientNum )
{
	self endon ( "entityshutdown" );
	
	while ( true )
	{
		level waittill( "explode", localClientNum, position, mod, weapon, owner_cent );
		
		explosionDistance = Distance( self.origin, position );
		if ( ( ( mod == "MOD_GRENADE_SPLASH" ) || ( mod == "MOD_PROJECTILE_SPLASH" ) ) && ( explosionDistance < MAX_SCREEN_FX_RANGE ) && !GetInKillcam( localClientNum ) && !IsThirdPerson( localClientNum ) )
		{
			cameraAngles = self GetCamAngles();
			if( !isDefined( cameraAngles ) )
				continue;
			
			forwardVec = VectorNormalize( AnglesToForward( cameraAngles ) );
			upVec = VectorNormalize( AnglesToUp( cameraAngles ) );
			rightVec = VectorNormalize( AnglesToRight( cameraAngles ) );
			explosionVec = VectorNormalize( position - (self GetCamPos() ) );
			
			if( VectorDot( forwardVec, explosionVec ) > 0 )
			{
				trace = bulletTrace( GetLocalClientEyePos( localClientNum ), position, false, self );
				if ( trace["fraction"] >= .9 )
				{
					uDot = -1.0 * VectorDot( explosionVec, upVec );
					rDot = VectorDot( explosionVec, rightVec );
					uDotAbs = abs( uDot );
					rDotAbs = abs( rDot );
					if( udotabs > rdotabs )
					{
						if( udot > 0 )
						{
							uDot = 1.0;
						}
						else
						{
							uDot = -1.0;
						}
					}
					else
					{
						if( rDot > 0 )
						{
							rDot = 1.0;
						}
						else
						{
							rDot = -1.0;
						}
					}
					self thread doTheDirty( localClientNum, rDot, uDot, ( 1.0 - explosionDistance / MAX_SCREEN_FX_RANGE ), EXPLOSION_DIRT_DURATION, EXPLOSION_DIRT_FADE_TIME );
				}
			}
		}
	}
}
