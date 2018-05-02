#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_wasp;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\weapons\_heatseekingmissile;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_qrdrone;
#using scripts\mp\killstreaks\_rcbomb;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\teams\_teams;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "mpl_killstreak_sentinel_strt" );
#precache( "string", "KILLSTREAK_SENTINEL_HACKED" );
#precache( "string", "KILLSTREAK_SENTINEL_INBOUND" );
#precache( "string", "KILLSTREAK_SENTINEL_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_SENTINEL_EARNED" );
#precache( "string", "KILLSTREAK_SENTINEL_NOT_PLACEABLE" );
#precache( "string", "KILLSTREAK_DESTROYED_SENTINEL" );
                    
#precache( "triggerstring", "KILLSTREAK_SENTINEL_USE_REMOTE" );

#namespace sentinel;
#define SENTINEL_NAME 				"sentinel"
#define INVENTORY_SENTINEL_NAME 	"inventory_sentinel"
#define SENTINEL_SHUTOWN_NOTIFY 	"sentinel_shutdown"

function init()
{
	killstreaks::register( SENTINEL_NAME, SENTINEL_NAME, "killstreak_" + SENTINEL_NAME, SENTINEL_NAME + "_used", &ActivateSentinel, true );
	killstreaks::register_strings( SENTINEL_NAME, &"KILLSTREAK_SENTINEL_EARNED", &"KILLSTREAK_SENTINEL_NOT_AVAILABLE", &"KILLSTREAK_SENTINEL_INBOUND", undefined, &"KILLSTREAK_SENTINEL_HACKED" );
	killstreaks::register_dialog( SENTINEL_NAME, "mpl_killstreak_sentinel_strt", "sentinelDialogBundle", "sentinelPilotDialogBundle", "friendlySentinel", "enemySentinel", "enemySentinelMultiple", "friendlySentinelHacked", "enemySentinelHacked", "requestSentinel", "threatSentinel" );
	killstreaks::register_alt_weapon( SENTINEL_NAME, "killstreak_remote" );
	killstreaks::register_alt_weapon( SENTINEL_NAME, "sentinel_turret" );
	remote_weapons::RegisterRemoteWeapon( SENTINEL_NAME, &"KILLSTREAK_SENTINEL_USE_REMOTE", &StartSentinelRemoteControl, &EndSentinelRemoteControl, SENTINEL_HIDE_COMPASS_ON_REMOTE_CONTROL );
	
	// TODO: Move to killstreak data
	level.killstreaks[SENTINEL_NAME].threatOnKill = true;

	vehicle::add_main_callback( SENTINEL_VEHICLE_NAME, &InitSentinel );
	
	visionset_mgr::register_info( "visionset", SENTINEL_VISIONSET_ALIAS, VERSION_SHIP, 100, 16, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false  );
}

function InitSentinel()
{
	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	Target_Set( self, ( 0, 0, 0 ) );
	self.health = self.healthdefault;
	self.numFlares = 1;
	self.damageTaken = 0;
	self vehicle::friendly_fire_shield();
	self EnableAimAssist();
	self SetNearGoalNotifyDist( SENTINEL_NEAR_GOAL_NOTIFY_DIST );
	self SetHoverParams( SENTINEL_HOVER_RADIUS, SENTINEL_HOVER_SPEED, SENTINEL_HOVER_ACCELERATION );
	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0;	//+/- 55 degrees = 110 fov
	self.vehAirCraftCollisionEnabled = true;
	
	self thread vehicle_ai::nudge_collision();
	self thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "explode", "death" );			// fires chaff if needed
	self thread helicopter::create_flare_ent( (0,0,-20) );
	self thread audio::vehicleSpawnContext();
	self.do_scripted_crash = false;
	
	self.overrideVehicleDamage = &SentinelDamageOverride;
	self.selfDestruct = false;

	self.enable_target_laser = true;
	self.aggresive_navvolume_recover = true;
		
	self vehicle_ai::init_state_machine_for_role( "default" );
	self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &wasp::state_combat_enter;
    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &wasp::state_combat_update;
   	self vehicle_ai::get_state_callbacks( "death" ).update_func = &wasp::state_death_update;
   	self vehicle_ai::get_state_callbacks( "driving" ).enter_func = &driving_enter;
 
   	wasp::init_guard_points();
   	self vehicle_ai::add_state( "guard",
		&wasp::state_guard_enter,
		&wasp::state_guard_update,
		&wasp::state_guard_exit );

   	vehicle_ai::add_utility_connection( "combat", "guard", &wasp::state_guard_can_enter );
	vehicle_ai::add_utility_connection( "guard", "combat" );
	vehicle_ai::add_interrupt_connection( "guard",	"emped",	"emped" );
	vehicle_ai::add_interrupt_connection( "guard",	"surge",	"surge" );
	vehicle_ai::add_interrupt_connection( "guard",	"off",		"shut_off" );
	vehicle_ai::add_interrupt_connection( "guard",	"pain",		"pain" );
	vehicle_ai::add_interrupt_connection( "guard",	"driving",	"enter_vehicle" );
  	
	self vehicle_ai::StartInitialState( "combat" );
}

function driving_enter( params )
{
	vehicle_ai::defaultstate_driving_enter( params );
}

function drone_pain_for_time( time, stablizeParam, restoreLookPoint, weapon )
{
	self endon( "death" );
	
	self.painStartTime = GetTime();

	if ( !IS_TRUE( self.inpain ) && isdefined( self.health ) && self.health > 0 )
	{
		self.inpain = true;
		

		while ( GetTime() < self.painStartTime + time * 1000 )
		{
			self SetVehVelocity( self.velocity * stablizeParam );
			self SetAngularVelocity( self GetAngularVelocity() * stablizeParam );
			wait 0.1;
		}

		if ( isdefined( restoreLookPoint ) && isdefined( self.health ) && self.health > 0 )
		{
			restoreLookEnt = Spawn( "script_model", restoreLookPoint );
			restoreLookEnt SetModel( "tag_origin" );

			self ClearLookAtEnt();
			self SetLookAtEnt( restoreLookEnt );
			self setTurretTargetEnt( restoreLookEnt );
			wait 1.5;

			self ClearLookAtEnt();
			self ClearTurretTarget();
			restoreLookEnt delete();
		}
		
		if( weapon.isEmp ) remote_weapons::set_static( 0 );

		self.inpain = false;
	}
}

function drone_pain( eAttacker, damageType, hitPoint, hitDirection, hitLocationInfo, partName, weapon )
{
	if ( !IS_TRUE( self.inpain ) )
	{
		yaw_vel = math::randomSign() * RandomFloatRange( 280, 320 );

		ang_vel = self GetAngularVelocity();
		ang_vel += ( RandomFloatRange( -120, -100 ), yaw_vel, RandomFloatRange( -200, 200 ) );
		self SetAngularVelocity( ang_vel );

		self thread drone_pain_for_time( 0.8, 0.7, undefined, weapon );
	}
}

function SentinelDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if( sMeansOfDeath == "MOD_TRIGGER_HURT" )
		return 0;
	
	emp_damage = self.healthdefault * SENTINEL_EMP_DAMAGE_PERCENTAGE + 0.5;
	
	iDamage = killstreaks::OnDamagePerWeapon( SENTINEL_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, &destroyed_cb, self.maxhealth*0.4, &low_health_cb, emp_damage, undefined, true, 1.0 );	
	
	if( isdefined( eAttacker ) && isdefined( eAttacker.team ) && eAttacker.team != self.team )
	{
		drone_pain( eAttacker, sMeansOfDeath, vPoint, vDir, sHitLoc, partName, weapon );
	}
	self.damageTaken += iDamage;
	return iDamage;
}

function destroyed_cb( attacker, weapon )
{
	if( isdefined( attacker ) && isdefined( attacker.team ) && attacker.team != self.team )
		self.owner.dofutz = true;
}

function low_health_cb( attacker, weapon )
{
	if( self.playedDamaged == false )
	{
		self killstreaks::play_pilot_dialog_on_owner( "damaged", SENTINEL_NAME, self.killstreak_id );
		self.playedDamaged = true;
	}
}

function CalcSpawnOrigin( origin, angles )
{
	heightOffset = rcbomb::GetPlacementStartHeight();
	
	mins = ( -5, -5, 0 );
	maxs = ( 5, 5, 10 );
	
	startPoints = [];
	testangles = [];
	
	testangles[0] = ( 0,   0, 0 );
	testangles[1] = ( 0,  30, 0 );
	testangles[2] = ( 0, -30, 0 );
	testangles[3] = ( 0,  60, 0 );
	testangles[4] = ( 0, -60, 0 );
	testangles[3] = ( 0,  90, 0 );
	testangles[4] = ( 0, -90, 0 );
	
	bestOrigin = origin;
	bestAngles = angles;
	bestFrac = 0;
	
	for( i = 0; i < testangles.size; i++ )
	{
		startPoint = origin + ( 0, 0, heightOffset );
		endPoint = startPoint + VectorScale( anglestoforward( ( 0, angles[1], 0 ) + testangles[i] ), RCBOMB_PLACMENT_FROM_PLAYER );
		
		mask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_VEHICLE;
		trace = physicstrace( startPoint, endPoint, mins, maxs, self, mask );
			
		if( isdefined( trace["entity"] ) && IsPlayer( trace["entity"] ) )
			continue;
		
		if( trace["fraction"] > bestFrac )
		{
			bestFrac = trace["fraction"];
			bestOrigin = trace["position"];
			bestAngles = ( 0, angles[1], 0 ) + testangles[i];
			if( bestFrac == 1 )
				break;
		}
	}
	
	if( bestFrac > 0 )
	{
		if( Distance2DSquared( origin, bestOrigin ) < 20 * 20 )
			return undefined;
		
 		trace = physicstrace( bestOrigin, bestOrigin + ( 0, 0, SENTINEL_SPAWN_Z_OFFSET ), mins, maxs, self, mask );
 		
 		placement = SpawnStruct();
 		placement.origin = trace["position"];
		placement.angles = bestAngles;
		return placement;
	}
	else
		return undefined;
}
	
function ActivateSentinel( killstreakType )
{
	assert( IsPlayer( self ) );
	player = self;
	
	if( !IsNavVolumeLoaded() )
	{
		/# IPrintLnBold( "Error: NavVolume Not Loaded" ); #/
		self iPrintLnBold( &"KILLSTREAK_SENTINEL_NOT_AVAILABLE" );
		return false;
	}
	
	if( player IsPlayerSwimming() )
	{
		self iPrintLnBold( &"KILLSTREAK_SENTINEL_NOT_PLACEABLE" );
		return false;
	}	
	
	spawnPos = CalcSpawnOrigin( player.origin, player.angles );
	if( !isdefined( spawnPos ) )
	{
		self iPrintLnBold( &"KILLSTREAK_SENTINEL_NOT_PLACEABLE" );
		return false;
	}
	
	killstreak_id = player killstreakrules::killstreakStart( SENTINEL_NAME, player.team, false, true );
	if( killstreak_id == INVALID_KILLSTREAK_ID )
	{
		return false;
	}
	
	player AddWeaponStat( GetWeapon( "sentinel" ), "used", 1 );

	sentinel = SpawnVehicle( SENTINEL_VEHICLE_NAME, spawnPos.origin, spawnPos.angles, "dynamic_spawn_ai" );
	
	sentinel killstreaks::configure_team( SENTINEL_NAME, killstreak_id, player, "small_vehicle", undefined, &ConfigureTeamPost );
	sentinel killstreak_hacking::enable_hacking( SENTINEL_NAME, &HackedCallbackPre, &HackedCallbackPost );
	sentinel.killstreak_id = killstreak_id;
	sentinel.killstreak_end_time = GetTime() + SENTINEL_DURATION;
	sentinel.original_vehicle_type = sentinel.vehicletype;
	sentinel.ignore_vehicle_underneath_splash_scalar = true;

	sentinel clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	sentinel.hardpointType = SENTINEL_NAME;
	sentinel.soundmod = "player";

	sentinel.maxhealth = killstreak_bundles::get_max_health( SENTINEL_NAME );
	sentinel.lowhealth = killstreak_bundles::get_low_health( SENTINEL_NAME );
	sentinel.health = sentinel.maxhealth;
	sentinel.hackedhealth = killstreak_bundles::get_hacked_health( SENTINEL_NAME );
	sentinel.rocketDamage = ( sentinel.maxhealth / SENTINEL_MISSILES_TO_DESTROY ) + 1;	
	sentinel.playedDamaged = false;
	sentinel.treat_owner_damage_as_friendly_fire = true;
	sentinel.ignore_team_kills = true;
	sentinel thread HealthMonitor();
	
	sentinel.goalradius = SENTINEL_MAX_DISTANCE_FROM_OWNER;
	sentinel.goalHeight = 500;
	//sentinel SetGoal( player, false, sentinel.goalRadius, sentinel.goalHeight );
	sentinel.enable_guard = true;
	sentinel.always_face_enemy = true;
		
	sentinel thread killstreaks::WaitForTimeout( SENTINEL_NAME, SENTINEL_DURATION, &OnTimeout, SENTINEL_SHUTOWN_NOTIFY );
	sentinel thread WatchWater();
	sentinel thread WatchDeath();
	sentinel thread WatchShutdown();
	
	player remote_weapons::UseRemoteWeapon( sentinel, SENTINEL_NAME, false );
	
	sentinel killstreaks::play_pilot_dialog_on_owner( "arrive", SENTINEL_NAME, killstreak_id );
	
	sentinel vehicle::init_target_group();
	sentinel vehicle::add_to_target_group( sentinel );
	
	self killstreaks::play_killstreak_start_dialog( SENTINEL_NAME, self.team, killstreak_id );
	
	sentinel thread WatchGameEnded();

	return true;
}

function HackedCallbackPre( hacker )
{
	sentinel = self;
	sentinel.owner unlink();
	sentinel clientfield::set( "vehicletransition", 0 );
	if( sentinel.controlled === true )
		visionset_mgr::deactivate( "visionset", SENTINEL_VISIONSET_ALIAS, sentinel.owner );
	sentinel.owner remote_weapons::RemoveAndAssignNewRemoteControlTrigger( sentinel.useTrigger );
	sentinel remote_weapons::EndRemoteControlWeaponUse( true );
	EndSentinelRemoteControl( sentinel, true );
}

function HackedCallbackPost( hacker )
{
	sentinel = self;

	hacker remote_weapons::UseRemoteWeapon( sentinel, SENTINEL_NAME, false );
	sentinel notify("WatchRemoteControlDeactivate_remoteWeapons");
	sentinel.killstreak_end_time = hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( sentinel );
}

function ConfigureTeamPost( owner, isHacked )
{
	sentinel = self;
	sentinel thread WatchTeamChange();
}

function WatchGameEnded()
{
	sentinel = self;
	sentinel endon( "death" );
	
	level waittill("game_ended");

	sentinel.abandoned = true;
	sentinel.selfDestruct = true;
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
}

function StartSentinelRemoteControl( sentinel )
{
	player = self;
	assert( IsPlayer( player ) );
	
	sentinel UseVehicle( player, 0 );
	
	sentinel clientfield::set( "vehicletransition", 1 );
	sentinel thread audio::sndUpdateVehicleContext(true);
	sentinel thread vehicle::monitor_missiles_locked_on_to_me( player );
	
	sentinel.inHeliProximity = false;
	sentinel.treat_owner_damage_as_friendly_fire = false;
	sentinel.ignore_team_kills = false;
	
	minHeightOverride = undefined;
	minz_struct = struct::get( "vehicle_oob_minz", "targetname");
	if( isdefined( minz_struct ) )
		minHeightOverride = minz_struct.origin[2];			
	
	sentinel thread qrdrone::QRDrone_watch_distance( SENTINEL_MAX_HEIGHT_OFFSET, minHeightOverride );
	sentinel.distance_shutdown_override = &SentinelDistanceFailure;
	
	player vehicle::set_vehicle_drivable_time( SENTINEL_DURATION, sentinel.killstreak_end_time );
	visionset_mgr::activate( "visionset", SENTINEL_VISIONSET_ALIAS, player, 1, 90000, 1 );	

	if ( isdefined( sentinel.PlayerDrivenVersion ) )
		sentinel SetVehicleType( sentinel.PlayerDrivenVersion );
}

function EndSentinelRemoteControl( sentinel, exitRequestedByOwner )
{
	sentinel.treat_owner_damage_as_friendly_fire = true;
	sentinel.ignore_team_kills = true;
			
	if ( isdefined( sentinel.owner ) )
	{
		sentinel.owner vehicle::stop_monitor_missiles_locked_on_to_me();
		if( sentinel.controlled === true )
			visionset_mgr::deactivate( "visionset", SENTINEL_VISIONSET_ALIAS, sentinel.owner );
	}

	if( exitRequestedByOwner )
	{
		if ( isdefined( sentinel.owner ) )
		{
			sentinel.owner qrdrone::destroyHud();
			sentinel.owner unlink();
			sentinel clientfield::set( "vehicletransition", 0 );
		}
		sentinel thread audio::sndUpdateVehicleContext(false);
	}
	
	if ( isdefined( sentinel.original_vehicle_type ) )
		sentinel SetVehicleType( sentinel.original_vehicle_type );
	
}

function OnTimeout()
{
	sentinel = self;
	
	sentinel killstreaks::play_pilot_dialog_on_owner( "timeout", SENTINEL_NAME );
	
	params = level.killstreakBundle[SENTINEL_NAME];
	
	if( isdefined( sentinel.owner ) )
	{
		RadiusDamage( sentinel.origin, 
					params.ksExplosionOuterRadius,
					params.ksExplosionInnerDamage,
					params.ksExplosionOuterDamage,
					sentinel.owner, 
					"MOD_EXPLOSIVE",
					GetWeapon( SENTINEL_NAME ) );
		if( isdefined( params.ksExplosionRumble ) )
			sentinel.owner PlayRumbleOnEntity( params.ksExplosionRumble );
	}
	
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
}

function HealthMonitor()
{
	self endon( "death" );
	
	params = level.killstreakBundle[SENTINEL_NAME];
	
	if( isdefined( params.fxLowHealth ) )
	{
		while( 1 )
		{
			if( self.lowhealth > self.health )
			{
				PlayFXOnTag( params.fxLowHealth, self, "tag_origin" );
				break;
			}
			WAIT_SERVER_FRAME;
		}
	}
}

function SentinelDistanceFailure()
{
	sentinel = self;
	
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
}

function WatchDeath()
{
	sentinel = self;
	sentinel waittill( "death", attacker, damageFromUnderneath, weapon, point, dir, modType );
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if ( isdefined( attacker ) && ( !isdefined( self.owner ) || self.owner util::IsEnemyPlayer( attacker ) ) )
	{
		if ( isPlayer( attacker ) )
		{
			challenges::destroyedAircraft( attacker, weapon, sentinel.controlled === true );
			attacker challenges::addFlySwatterStat( weapon, self );
			attacker AddWeaponStat( weapon, "destroy_aitank_or_setinel", 1 );
			scoreevents::processScoreEvent( "destroyed_sentinel", attacker, sentinel.owner, weapon );
			if ( modType == "MOD_RIFLE_BULLET" || modType == "MOD_PISTOL_BULLET" )
			{
				attacker addPlayerStat( "shoot_down_sentinel", 1 );
			}
			LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_SENTINEL", attacker.entnum );
		}
		
		if ( isdefined( sentinel ) && isdefined( sentinel.owner ) )
		{
			sentinel killstreaks::play_destroyed_dialog_on_owner(  SENTINEL_NAME, sentinel.killstreak_id );
		}
	}
}

function WatchTeamChange()
{
	self notify( "Sentinel_WatchTeamChange_Singleton" );
	self endon ( "Sentinel_WatchTeamChange_Singleton" );
	sentinel = self;
	
	sentinel endon( SENTINEL_SHUTOWN_NOTIFY );
	sentinel.owner util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
}

#define SENTINEL_IN_WATER_TRACE_MINS		( -2, -2, -2 )
#define SENTINEL_IN_WATER_TRACE_MAXS		(  2,  2,  2 )
#define SENTINEL_IN_WATER_TRACE_MASK		( PHYSICS_TRACE_MASK_WATER )
#define SENTINEL_IN_WATER_TRACE_WAIT		( 0.1 )
	
function WatchWater()
{
	sentinel = self;
	sentinel endon( SENTINEL_SHUTOWN_NOTIFY );
			
	while( true )
	{
		wait SENTINEL_IN_WATER_TRACE_WAIT;
		trace = physicstrace( self.origin + ( 0, 0, 10 ), self.origin + ( 0, 0, 6 ), SENTINEL_IN_WATER_TRACE_MINS, SENTINEL_IN_WATER_TRACE_MAXS, self, SENTINEL_IN_WATER_TRACE_MASK);
		if( trace["fraction"] < 1.0 )
			break;
	}
	
	sentinel notify( SENTINEL_SHUTOWN_NOTIFY );
}

function WatchShutdown()
{
	sentinel = self;
	
	sentinel waittill( SENTINEL_SHUTOWN_NOTIFY );
	
	if( IS_TRUE( sentinel.control_initiated ) || IS_TRUE( sentinel.controlled ) )
	{
		sentinel remote_weapons::EndRemoteControlWeaponUse( false );
		while( IS_TRUE( sentinel.control_initiated ) || IS_TRUE( sentinel.controlled ) )
			WAIT_SERVER_FRAME;
	}
	
	if( isdefined( sentinel.owner ) )
	{
		sentinel.owner qrdrone::destroyHud();
	}
	
	killstreakrules::killstreakStop( SENTINEL_NAME, sentinel.originalTeam, sentinel.killstreak_id );
	
	if( isalive( sentinel ) )
		sentinel Kill();
}