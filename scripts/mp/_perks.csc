#using scripts\codescripts\struct;
#using scripts\shared\abilities\_ability_util;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\system_shared;

#namespace perks;

REGISTER_SYSTEM( "perks", &__init__, undefined )

#define TRAIL_FX_FOOT_L  		"player/fx_plyr_footstep_tracker_l"
#define TRAIL_FX_FOOT_R 		"player/fx_plyr_footstep_tracker_r"
#define TRAIL_FX_FLY_L 			"player/fx_plyr_flying_tracker_l"
#define TRAIL_FX_FLY_R  		"player/fx_plyr_flying_tracker_r"
#define TRAIL_FX_FOOT_L_FAST  	"player/fx_plyr_footstep_tracker_lf"
#define TRAIL_FX_FOOT_R_FAST 	"player/fx_plyr_footstep_tracker_rf"
#define TRAIL_FX_FLY_L_FAST 	"player/fx_plyr_flying_tracker_lf"
#define TRAIL_FX_FLY_R_FAST  	"player/fx_plyr_flying_tracker_rf"

#precache( "client_fx", TRAIL_FX_FOOT_L );
#precache( "client_fx", TRAIL_FX_FOOT_R );
#precache( "client_fx", TRAIL_FX_FLY_L );
#precache( "client_fx", TRAIL_FX_FLY_R );
#precache( "client_fx", TRAIL_FX_FOOT_L_FAST );
#precache( "client_fx", TRAIL_FX_FOOT_R_FAST );
#precache( "client_fx", TRAIL_FX_FLY_L_FAST );
#precache( "client_fx", TRAIL_FX_FLY_R_FAST );


function __init__()
{
	clientfield::register( "allplayers", "flying", VERSION_SHIP, 1, "int", &flying_callback, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	callback::on_localclient_connect( &on_local_client_connect );
	callback::on_localplayer_spawned( &on_localplayer_spawned );
	callback::on_spawned( &on_player_spawned );
	
	// kill tracker FX when tracked player dies
	level.killTrackerFXEnable = true;
	level._monitor_tracker = &monitor_tracker_perk;
	
	level.sitrepscan1_enable 			= GetDvarInt( "scr_sitrepscan1_enable", 2 );
	level.sitrepscan1_setoutline 		= GetDvarInt( "scr_sitrepscan1_setoutline", 1 );
	level.sitrepscan1_setsolid 			= GetDvarInt( "scr_sitrepscan1_setsolid", 1 );
	level.sitrepscan1_setlinewidth 		= GetDvarInt( "scr_sitrepscan1_setlinewidth", 1 );
	level.sitrepscan1_setradius 		= GetDvarInt( "scr_sitrepscan1_setradius", 50000 );
	level.sitrepscan1_setfalloff 		= GetDvarFloat( "scr_sitrepscan1_setfalloff", .01 );
	level.sitrepscan1_setdesat	 		= GetDvarFloat( "scr_sitrepscan1_setdesat", .4 );
	
	level.sitrepscan2_enable 			= GetDvarInt( "scr_sitrepscan2_enable", 2 );
	level.sitrepscan2_setoutline 		= GetDvarInt( "scr_sitrepscan2_setoutline", 10 );
	level.sitrepscan2_setsolid 			= GetDvarInt( "scr_sitrepscan2_setsolid", 0 );
	level.sitrepscan2_setlinewidth 		= GetDvarInt( "scr_sitrepscan2_setlinewidth", 1 );
	level.sitrepscan2_setradius 		= GetDvarInt( "scr_sitrepscan2_setradius", 50000 );
	level.sitrepscan2_setfalloff 		= GetDvarFloat( "scr_sitrepscan2_setfalloff", .01 );
	level.sitrepscan2_setdesat 			= GetDvarFloat( "scr_sitrepscan2_setdesat", .4 );

}

function updateSitrepScan()
{
	self endon ( "entityshutdown" );
	while(1)
	{
		self oed_sitrepscan_enable( level.sitrepscan1_enable );
		self oed_sitrepscan_setoutline( level.sitrepscan1_setoutline );
		self oed_sitrepscan_setsolid( level.sitrepscan1_setsolid );
		self oed_sitrepscan_setlinewidth( level.sitrepscan1_setlinewidth );
	    self oed_sitrepscan_setradius( level.sitrepscan1_setradius );
		self oed_sitrepscan_setfalloff( level.sitrepscan1_setfalloff );
		self oed_sitrepscan_setdesat( level.sitrepscan1_setdesat );
		
		self oed_sitrepscan_enable( level.sitrepscan2_enable, 1 );
		self oed_sitrepscan_setoutline( level.sitrepscan2_setoutline, 1 );
		self oed_sitrepscan_setsolid( level.sitrepscan2_setsolid, 1 );
		self oed_sitrepscan_setlinewidth( level.sitrepscan2_setlinewidth, 1 );
	    self oed_sitrepscan_setradius( level.sitrepscan2_setradius, 1 );
		self oed_sitrepscan_setfalloff( level.sitrepscan2_setfalloff, 1 );
		self oed_sitrepscan_setdesat( level.sitrepscan2_setdesat, 1 );
		wait(1.0);
	}
}

function flying_callback( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.flying = newVal;
}

function on_local_client_connect( local_client_num )
{
	RegisterRewindFX( local_client_num, TRAIL_FX_FOOT_L );
	RegisterRewindFX( local_client_num, TRAIL_FX_FOOT_R );
	RegisterRewindFX( local_client_num, TRAIL_FX_FLY_L );
	RegisterRewindFX( local_client_num, TRAIL_FX_FLY_R );
	RegisterRewindFX( local_client_num, TRAIL_FX_FOOT_L_FAST );
	RegisterRewindFX( local_client_num, TRAIL_FX_FOOT_R_FAST );
	RegisterRewindFX( local_client_num, TRAIL_FX_FLY_L_FAST );
	RegisterRewindFX( local_client_num, TRAIL_FX_FLY_R_FAST );
}

function on_localplayer_spawned( local_client_num )
{
	if( self != GetLocalPlayer( local_client_num ) )
		return;

	self thread monitor_tracker_perk_killcam( local_client_num );
	self thread monitor_detectnearbyenemies( local_client_num );
	self thread monitor_tracker_existing_players( local_client_num );
}

function on_player_spawned( local_client_num )
{
	self notify("perks_changed");
	self thread updateSitrepScan();
	self thread killTrackerFX_on_death( local_client_num );
	self thread monitor_tracker_perk( local_client_num );
}


#define TRACKER_FX_FLY_HEIGHT GetDvarFloat( "perk_tracker_fx_fly_height", 0 )
#define TRACKER_FX_FLY_DISTANCE 32
#define TRACKER_FX_FLY_DISTANCE_SQ ( TRACKER_FX_FLY_DISTANCE * TRACKER_FX_FLY_DISTANCE )

#define TRACKER_FX_FOOT_HEIGHT GetDvarFloat( "perk_tracker_fx_foot_height", 0 )
#define TRACKER_FX_FOOT_DISTANCE 32
#define TRACKER_FX_FOOT_DISTANCE_SQ ( TRACKER_FX_FOOT_DISTANCE * TRACKER_FX_FOOT_DISTANCE )

#define TRACKER_STATIONARY_VEL	1
#define TRACKER_STATIONARY_VEL_SQ	( TRACKER_STATIONARY_VEL * TRACKER_STATIONARY_VEL )

#define TRACKER_KILLCAM_COUNT	20	
#define TRACKER_KILLCAM_TIME 	5000

#define TRACKER_KILLFX_COUNT	40	// keep the handle to the last 40 tracker fx
#define TRACKER_KILLFX_TIME 	5000  // handle fx older than this are ignored

function get_players( local_client_num )
{
	players = [];
	entities = GetEntArray( local_client_num );
	if (IsDefined(entities))
	{
		foreach( ent in entities )
		{
			if ( ent IsPlayer() )
			{
				players[players.size] = ent;
			}
		}
	}
	return players;
}

function monitor_tracker_existing_players( local_client_num ) // self == localplayer
{
	self endon( "death" );
	self endon ( "monitor_tracker_existing_players" );
	self notify( "monitor_tracker_existing_players" );
	players = GetPlayers( local_client_num );
	foreach( player in players )
	{
		if ( isdefined( player ) && player != self )
		{
			player thread monitor_tracker_perk( local_client_num );
		}
		WAIT_CLIENT_FRAME;
	}
}

function monitor_tracker_perk_killcam( local_client_num )
{
	self notify( "monitor_tracker_perk_killcam" + local_client_num );
	self endon( "monitor_tracker_perk_killcam" + local_client_num );
	self endon( "entityshutdown" );	
	
	predictedLocalPlayer = getlocalplayer( local_client_num );
	if ( !isdefined( level.trackerSpecialtySelf ) )
	{
		level.trackerSpecialtySelf = [];

		level.trackerSpecialtyCounter = 0;
	}
	
	if ( !isdefined( level.trackerSpecialtySelf[local_client_num] ) )
	{
		level.trackerSpecialtySelf[local_client_num] = [];
	}
		
	if ( predictedLocalPlayer GetInKillcam( local_client_num ) )
	{
		nonPredictedLocalPlayer = GetNonPredictedLocalPlayer( local_client_num );
		if ( predictedLocalPlayer HasPerk( local_client_num, "specialty_tracker" ) )
		{
			serverTime = getServerTime( local_client_num );
			for(count = 0; count < level.trackerSpecialtySelf[local_client_num].size; count++ )
			{
				if ( level.trackerSpecialtySelf[local_client_num][count].time < serverTime && level.trackerSpecialtySelf[local_client_num][count].time > serverTime - TRACKER_KILLCAM_TIME )
				{
					positionAndRotationStruct = level.trackerSpecialtySelf[local_client_num][count];
					tracker_playFX(local_client_num, positionAndRotationStruct);
				}
			}
		}
	}
	else
	{
		for(;;)
		{
			wait 0.05;
			
			positionAndRotationStruct = self getTrackerFXPosition( local_client_num );
			if ( isdefined ( positionAndRotationStruct ) )
			{
				positionAndRotationStruct.time = getServerTime( local_client_num );
				
				level.trackerSpecialtySelf[local_client_num][level.trackerSpecialtyCounter] = positionAndRotationStruct;
				level.trackerSpecialtyCounter++;
				if ( level.trackerSpecialtyCounter > TRACKER_KILLCAM_COUNT )
				{
					level.trackerSpecialtyCounter = 0;
				}
			}
		}
	}
}

function monitor_tracker_perk( local_client_num )
{
	self notify( "monitor_tracker_perk" );
	self endon( "monitor_tracker_perk" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "entityshutdown" );	
	
	self.flying = false;
	self.tracker_flying = false;
	self.tracker_last_pos = self.origin;

	offset = ( 0,0,TRACKER_FX_FOOT_HEIGHT );
	dist2 = TRACKER_FX_FOOT_DISTANCE_SQ;
	
	while(IsDefined(self))
	{
		wait 0.05;
		
		watcher = GetLocalPlayer( local_client_num );

		if ( !isdefined( watcher ) || self == watcher )
			return; // no need to monitor the watcher
	
		if ( IsDefined( watcher ) && watcher HasPerk( local_client_num, "specialty_tracker" ) )
		{
			friend = self isFriendly( local_client_num, true );
			
			camoOff = true;
			if( !isDefined( self._isClone ) || !self._isClone )
			{
				camo_val = self clientfield::get( "camo_shader" );
				if( camo_val != GADGET_CAMO_SHADER_OFF )
				{
					camoOff = false;
				}
			}

			if ( !friend && IsAlive(self) && camoOff )
			{
				positionAndRotationStruct = self getTrackerFXPosition( local_client_num );
				if ( isdefined( positionAndRotationStruct ) )
				{
					self tracker_playFX(local_client_num, positionAndRotationStruct);
				}
			}
			else
			{
				self.tracker_flying = false;
			}
		}
	}
}

function tracker_playFX( local_client_num, positionAndRotationStruct )
{
	handle = playFX( local_client_num, positionAndRotationStruct.fx, positionAndRotationStruct.pos, positionAndRotationStruct.fwd, positionAndRotationStruct.up );		
	
	self killTrackerFX_track( local_client_num, handle );
}

function killTrackerFX_track( local_client_num, handle )
{
	if ( handle && isdefined( self.killTrackerFX ) )
	{
		serverTime = getServerTime( local_client_num );
		
		killFXStruct = SpawnStruct();
		killFXStruct.time = serverTime;
		killFXStruct.handle = handle;
		
		index = self.killTrackerFX.index;
		
		if ( index >= TRACKER_KILLFX_COUNT )
		{
			index = 0;
		}
			
		self.killTrackerFX.array[index] = killFXStruct;
		self.killTrackerFX.index = index + 1;
	}
}

function killTrackerFX_on_death( local_client_num )
{
	self endon( "disconnect" );
	
	if ( !IS_TRUE( level.killTrackerFXEnable ) )
	{
		return;
	}
	
	predictedLocalPlayer = getlocalplayer( local_client_num );
	
	if ( predictedLocalPlayer == self )
	{
		return;
	}
	
	if ( isdefined( self.killTrackerFX ) )
	{
		self.killTrackerFX.array = [];
		self.killTrackerFX.index = 0;
		self.killTrackerFX = undefined;
	}	
	
	killTrackerFX = SpawnStruct();
	killTrackerFX.array = [];
	killTrackerFX.index = 0;		
	
	self.killTrackerFX = killTrackerFX;
	
	self waittill( "entityshutdown" );
	
	serverTime = getServerTime( local_client_num );
	
	foreach( killFXStruct in killTrackerFX.array )
	{		
		if ( isdefined( killFXStruct ) && killFXStruct.time + TRACKER_KILLFX_TIME > serverTime )
		{
			KillFX( local_client_num, killFXStruct.handle );
		}
	}
	
	killTrackerFX.array = [];
	killTrackerFX.index = 0;
	killTrackerFX = undefined;
}

function getTrackerFXPosition( local_client_num )
{
	positionAndRotation = undefined;
	player = self;
	if( IS_TRUE( self._isClone ) )
	{
		player = self.owner;
	}
	playFastFX = player hasperk( local_client_num, "specialty_trackerjammer" );
	if ( IS_TRUE(self.flying) )
	{
		offset = ( 0,0,TRACKER_FX_FLY_HEIGHT );
		dist2 = TRACKER_FX_FLY_DISTANCE_SQ;
		if ( IS_TRUE( self.trailRightFoot ) )
		{
			if ( playFastFX )
			{
				fx = TRAIL_FX_FLY_R_FAST;
			}
			else
			{
				fx = TRAIL_FX_FLY_R;
			}
		}
		else 
		{
			if ( playFastFX )
			{
				fx = TRAIL_FX_FLY_L_FAST;
			}
			else
			{
				fx = TRAIL_FX_FLY_L;
			}
		}
	}
	else
	{
		offset = ( 0,0,TRACKER_FX_FOOT_HEIGHT );
		dist2 = TRACKER_FX_FOOT_DISTANCE_SQ;
		if ( IS_TRUE( self.trailRightFoot ) )
		{
			if ( playFastFX )
			{
				fx = TRAIL_FX_FOOT_R_FAST;
			}
			else
			{
				fx = TRAIL_FX_FOOT_R;
			}
		}
		else 
		{
			if ( playFastFX )
			{
				fx = TRAIL_FX_FOOT_L_FAST;
			}
			else
			{
				fx = TRAIL_FX_FOOT_L;
			}
		}
	}

	pos = self.origin + offset;
	fwd = AnglesToForward( self.angles );
	right = AnglesToRight( self.angles );
	up = AnglesToUp( self.angles );

	vel = self getvelocity(); 
	if (LengthSquared(vel) > TRACKER_STATIONARY_VEL_SQ)
	{
		up = VectorCross(vel,right);
		if ( LengthSquared( up ) < 0.0001 )
		{
			up = VectorCross(fwd, vel);
		}
		fwd = vel;
	}
	
	if( self isplayer() && self isplayerwallrunning() )
	{
		if( self isplayerwallrunningright() )
		{
			up = VectorCross( up, fwd );
		}
		else
		{
			up = VectorCross( fwd, up );
		}
	}

	if ( !self.tracker_flying )
	{
		self.tracker_flying = true;
		self.tracker_last_pos = self.origin;
	}
	else
	{
		if ( DistanceSquared( self.tracker_last_pos, pos ) > dist2 )
		{
			positionAndRotation = SpawnStruct();
			positionAndRotation.fx = fx;
			positionAndRotation.pos = pos;
			positionAndRotation.fwd = fwd;
			positionAndRotation.up = up;
			
			self.tracker_last_pos = self.origin;
			
			if ( IS_TRUE( self.trailRightFoot ) )
			{
				self.trailRightFoot = false;
			}
			else
			{
				self.trailRightFoot = true;
			}
		}
	}
	
	return positionAndRotation;
}


#define DETECT_NEARBY_ENEMIES_WAIT_TIME 0.05
#define DETECT_Z_THRESHOLD				50
#define DETECT_LOSE_Z_THRESHOLD			350
#define DETECT_RADIUS_NEAR				300
#define DETECT_LOSE_RADIUS_NEAR			350
#define DETECT_RADIUS 					300
#define DETECT_LOSE_RADIUS 				350
#define DETECT_INDICATOR_APPEAR_DELAY	0.05
#define DETECT_INDICATOR_LOST_DELAY		0.05
	
	
#define DETECT_FRONT_MASK				( 1 << 0 )
#define DETECT_BACK_MASK				( 1 << 1 )
#define DETECT_LEFT_MASK				( 1 << 2 )
#define DETECT_RIGHT_MASK				( 1 << 3 )


function monitor_detectnearbyenemies( local_client_num )
{
	self endon( "entityshutdown" );
	
	controllerModel = GetUIModelForController( local_client_num );
	sixthsenseModel = CreateUIModel( controllerModel, "hudItems.sixthsense" );
	
	enemyNearbyTime = 0.0;
	enemyLostTime = 0.0;
	previousEnemyDetectedBitField = 0;
	
	SetUIModelValue( sixthsenseModel, 0 );

	while(1) 
	{
		localPlayer = GetLocalPlayer( local_client_num );
		
		if ( !( localPlayer IsPlayer() ) ||
		    ( localPlayer HasPerk( local_client_num, "specialty_detectnearbyenemies" ) == false ) ||
			( localPlayer GetInKillcam( local_client_num ) == true || IsAlive( localPlayer ) == false ) )
		{
 			SetUIModelValue( sixthsenseModel, 0 );
 			previousEnemyDetectedBitField = 0;
 			self util::waittill_any( "death", "spawned", "perks_changed" );
 			continue;
		}
 		
		enemyNearbyFront = false;
		enemyNearbyBack = false;
		enemyNearbyLeft = false;
		enemyNearbyRight = false;
		enemyDetectedBitField = 0;
		
		team = localPlayer.team;
		innerDetect = getdvarint( "specialty_detectnearbyenemies_inner", 1 );
		outerDetect = getdvarint( "specialty_detectnearbyenemies_outer", 1 );
		zDetect = getdvarint( "specialty_detectnearbyenemies_zthreshold", 1 );
		
		localPlayerAnglesToForward = anglesToForward( localPlayer.Angles );
	
		players = getplayers( local_client_num );
		clones = getclones( local_client_num );
		sixthSenseEnts = arraycombine( players, clones, false, false );
		foreach( sixthSenseEnt in sixthSenseEnts )
		{
			if ( sixthSenseEnt isfriendly( local_client_num, true ) || sixthSenseEnt == localPlayer ) // SJC: IsEntityFriendly check returns false on yourself in FFA
				continue;
			
			if( !isAlive( sixthSenseEnt ) )
				continue;
			
			distanceScalarSq = 1;
			zScalarSq = 1;
			
			player = sixthSenseEnt;
			if( IS_TRUE( sixthSenseEnt._isClone ) )
			{
				player = sixthSenseEnt.owner;
			}
			
			if ( player isplayer() && player HasPerk( local_client_num, "specialty_sixthsensejammer" ) )
			{
				distanceScalarSq = GetDvarFloat( "specialty_sixthsensejammer_distance_scalar", 0.01 );
				zScalarSq = GetDvarFloat( "specialty_sixthsensejammer_z_scalar", 0.01 );
			}
				
			if ( previousEnemyDetectedBitField == 0 ) 
			{
				distanceSq = DETECT_RADIUS * DETECT_RADIUS * distanceScalarSq;
			}
			else
			{
				distanceSq = DETECT_LOSE_RADIUS * DETECT_LOSE_RADIUS * distanceScalarSq;
			}
			
			distCurrentSq = DistanceSquared( sixthSenseEnt.origin, localPlayer.origin );
			zdistCurrent = sixthSenseEnt.origin[2] - localPlayer.origin[2];
			zdistCurrentSq = zdistCurrent * zdistCurrent;
			if ( distCurrentSq < distanceSq ) 
			{
				distanceMask = 1;
				
				if ( previousEnemyDetectedBitField > 16 )
				{
					zNearbyCheck = DETECT_LOSE_Z_THRESHOLD * DETECT_LOSE_Z_THRESHOLD * zScalarSq;
				}
				else
				{
					zNearbyCheck = DETECT_Z_THRESHOLD * DETECT_Z_THRESHOLD * zScalarSq;
				}
				
				if ( zdistCurrentSq < zNearbyCheck && zDetect )
				{
					distanceMask = 16;
				}
				
				vector = sixthSenseEnt.origin - localPlayer.origin;
				vector = ( vector[0], vector[1], 0 );
				vectorFlat = vectorNormalize( vector );
				cosAngle = VectorDot( vectorFlat, localPlayerAnglesToForward );
				
				if ( cosAngle > COS_45 )
				{
					enemyDetectedBitField = enemyDetectedBitField | ( DETECT_FRONT_MASK * distanceMask );
					
				}
				else if ( cosAngle < -COS_45 )
				{
					enemyDetectedBitField = enemyDetectedBitField | ( DETECT_BACK_MASK * distanceMask );
				}
				else
				{
					localPlayerAnglesToRight = anglesToRight( localPlayer.Angles );
					cosAngle = VectorDot( vectorFlat, localPlayerAnglesToRight );
					if ( cosAngle < 0 )
					{
						enemyDetectedBitField = enemyDetectedBitField | ( DETECT_LEFT_MASK * distanceMask );
					}
					else
					{
						enemyDetectedBitField = enemyDetectedBitField | ( DETECT_RIGHT_MASK * distanceMask );
					}
				}
			}
		}

		if ( enemyDetectedBitField )
		{
			enemyLostTime = 0;
			if ( previousEnemyDetectedBitField != enemyDetectedBitField && enemyNearbyTime >= DETECT_INDICATOR_APPEAR_DELAY )
			{
				SetUIModelValue( sixthsenseModel, enemyDetectedBitField );
				enemyNearbyTime = 0;
				
				diff = enemyDetectedBitField ^ previousEnemyDetectedBitField;
				if ( diff & enemyDetectedBitField )
				{
					// SOUND DEPT
					// player has entered area
					self playsound (0, "uin_sixth_sense_ping_on");
				}
				if ( diff & previousEnemyDetectedBitField )
				{
					// SOUND DEPT
					// player has left area
					//self playsound (0, "uin_sixth_sense_off");
				}
				
				previousEnemyDetectedBitField = enemyDetectedBitField;
			}
			enemyNearbyTime += DETECT_NEARBY_ENEMIES_WAIT_TIME;
		}
		else
		{
			enemyNearbyTime = 0;
			if ( previousEnemyDetectedBitField != 0 && enemyLostTime >= DETECT_INDICATOR_LOST_DELAY )
			{
				SetUIModelValue( sixthsenseModel, 0 );
				previousEnemyDetectedBitField = 0;
			}
			enemyLostTime += DETECT_NEARBY_ENEMIES_WAIT_TIME;
		}
		
		wait( DETECT_NEARBY_ENEMIES_WAIT_TIME );
	}
	SetUIModelValue( sixthsenseModel, 0 );
}

