#using scripts\shared\system_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace oob;

REGISTER_SYSTEM( "out_of_bounds", &__init__, undefined )		

#define OOB_TIMELIMIT_MS_DEFAULT 6000	//Change the value in the _oob.gsc file to match this one
#define OOB_TIMELIMIT_MS_DEFAULT_MP 3000 //Change the value in the _oob.gsc file to match this one
#define OOB_TIMEKEEP_MP	3000  //Change the value in the _oob.gsc file to match this one
	
function __init__()
{
	if(SessionModeIsMultiplayerGame())
	{
		level.oob_timelimit_ms = GetDvarInt( "oob_timelimit_ms", OOB_TIMELIMIT_MS_DEFAULT_MP );
		level.oob_timekeep_ms = GetDvarInt( "oob_timekeep_ms", OOB_TIMEKEEP_MP );
	}
	else
	{
		level.oob_timelimit_ms = GetDvarInt( "oob_timelimit_ms", OOB_TIMELIMIT_MS_DEFAULT );
	}
	
	clientfield::register( "toplayer", "out_of_bounds", VERSION_SHIP, 5, "int", &onOutOfBoundsChange,!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	

 	if( !SessionModeIsZombiesGame() )
   	{
		callback::on_localclient_connect( &on_localplayer_connect );
		callback::on_localplayer_spawned( &on_localplayer_spawned );
		callback::on_localclient_shutdown( &on_localplayer_shutdown );
	}
}

function on_localplayer_connect( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	oobModel = GetOObUIModel( localClientNum );
	SetUIModelValue( oobModel, 0 );
}

function on_localplayer_spawned( localClientNum )
{
	filter::disable_filter_oob( self, FILTER_INDEX_OOB );
	self Randomfade( 0 );
}

function on_localplayer_shutdown( localClientNum )
{
	localPlayer = self;
	if ( isdefined( localPlayer ) )
	{
		StopOutOfBoundsEffects( localClientNum, localPlayer );
	}
}

function onOutOfBoundsChange( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	
	localPlayer = GetLocalPlayer( localClientNum );
	
	if(!isdefined(level.oob_sound_ent))
	{
		level.oob_sound_ent = [];
	}
	
	if( !isdefined( level.oob_sound_ent[localClientNum] ) )
	{
		level.oob_sound_ent[localClientNum] = Spawn( localClientNum, (0,0,0), "script_origin" );
	}
	
	if( newVal > 0)
	{
		if( !isdefined( localPlayer.oob_effect_enabled ) )
		{
			filter::init_filter_oob( localPlayer );
			filter::enable_filter_oob( localPlayer, FILTER_INDEX_OOB );
			localPlayer.oob_effect_enabled = true;
			
			level.oob_sound_ent[localClientNum] PlayLoopSound( "uin_out_of_bounds_loop", 0.5 );//not sure why this sound was added
		
			oobModel = GetOObUIModel( localClientNum );
			
			//Logic to pause/continue the OOB time for a certain duration if the player come out/in from it.
			if( isdefined(level.oob_timekeep_ms) && isdefined(self.oob_start_time) && isdefined(self.oob_active_duration) &&
			   ((getServerTime(0) - self.oob_end_time) < level.oob_timekeep_ms) )
			{
				SetUIModelValue( oobModel, getServerTime( 0, true ) + (level.oob_timelimit_ms - self.oob_active_duration) );
			}
			else
			{
				self.oob_active_duration = undefined;
				SetUIModelValue( oobModel, getServerTime( 0, true ) + level.oob_timelimit_ms );
			}
			
			self.oob_start_time = getServerTime(0, true);
		}
		
		newValf = newVal / 31.0;
		
		localPlayer Randomfade( newValf );
	}
	else
	{
		if( isdefined(level.oob_timekeep_ms) && isdefined(self.oob_start_time))
		{
			self.oob_end_time = getServerTime( 0, true );
			
			if(!isdefined(self.oob_active_duration))
			{
				self.oob_active_duration = 0;
			}
			
			self.oob_active_duration += self.oob_end_time - self.oob_start_time;
		}
		
		StopOutOfBoundsEffects( localClientNum, localPlayer );
	}
}

function StopOutOfBoundsEffects( localClientNum, localPlayer )
{
	filter::disable_filter_oob( localPlayer, FILTER_INDEX_OOB );
	localPlayer Randomfade( 0 );
	
	if( isDefined(level.oob_sound_ent) && isdefined( level.oob_sound_ent[localClientNum] ) )
	{
		level.oob_sound_ent[localClientNum] StopAllLoopSounds( 0.5 );
	}

	oobModel = GetOObUIModel( localClientNum );
	SetUIModelValue( oobModel, 0 );
	
	if( isdefined( localPlayer.oob_effect_enabled ) )
	{	
		localPlayer.oob_effect_enabled = false;
		localPlayer.oob_effect_enabled = undefined;
	}
}

function GetOObUIModel( localClientNum )
{
	controllerModel = GetUIModelForController( localClientNum );
	return CreateUIModel( controllerModel, "hudItems.outOfBoundsEndTime" );
}
