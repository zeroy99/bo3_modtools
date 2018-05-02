#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\weapons\_hacker_tool;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\math_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\mp\killstreaks\_qrdrone;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\shared\vehicle_ai_shared;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_remote_weapons;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#using scripts\shared\visionset_mgr_shared;

#namespace dart;
#define DART_NAME 				"dart"
#define DART_KILLSTREAK_NAME 	"killstreak_dart"
#define DART_STAT_NAME 			"dart_used"
	
#precache( "string", "KILLSTREAK_DART_HACKED" );
#precache( "string", "KILLSTREAK_DART_EARNED" );
#precache( "string", "KILLSTREAK_DART_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_DART_INBOUND" );
#precache( "string", "KILLSTREAK_DART_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_DART" );
#precache( "string", "mpl_killstreak_dart_strt" );
	
function init()
{
	killstreaks::register( DART_NAME, DART_NAME, DART_KILLSTREAK_NAME, DART_STAT_NAME, &ActivateDart, true) ;
	killstreaks::register_strings( DART_NAME, &"KILLSTREAK_DART_EARNED", &"KILLSTREAK_DART_NOT_AVAILABLE", &"KILLSTREAK_DART_INBOUND", undefined, &"KILLSTREAK_DART_HACKED" );
	killstreaks::register_dialog( DART_NAME, "mpl_killstreak_dart_strt", "dartDialogBundle", "dartPilotDialogBundle", "friendlyDart", "enemyDart",  "enemyDartMultiple", "friendlyDartHacked", "enemyDartHacked", "requestDart", "threatDart" );
	killstreaks::override_entity_camera_in_demo( DART_NAME, true );

	killstreaks::register_alt_weapon( DART_NAME, "killstreak_remote" );
	killstreaks::register_alt_weapon( DART_NAME, "dart_blade" );
	killstreaks::register_alt_weapon( DART_NAME, "dart_turret" );
	
	clientfield::register( "toplayer", "dart_update_ammo", VERSION_SHIP, 2, "int" );
	clientfield::register( "toplayer", "fog_bank_3", VERSION_SHIP, 1, "int" );	

	remote_weapons::RegisterRemoteWeapon( DART_NAME, &"", &StartDartRemoteControl, &EndDartRemoteControl, DART_HIDE_COMPASS_ON_REMOTE_CONTROL );
	
	visionset_mgr::register_info( "visionset", DART_VISIONSET_ALIAS, VERSION_SHIP, 90, 16, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false  );
}

function wait_dart_timed_out( time )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "dart_throw_failed" );
	self endon( "dart_entered" );

	wait( time );
	
	self notify( "dart_throw_timed_out" );
}

function wait_for_throw_status()
{
	thread dart::wait_dart_timed_out( 5 );
	
	notifyString = self util::waittill_any_return( "death", "disconnect", "dart_entered", "dart_throw_timed_out","dart_throw_failed" );

	if ( notifyString == "dart_entered" || notifyString == "death" )
		return true;
	
	return false;
}

function ActivateDart( killstreakType )
{
	player = self;
	
	assert( IsPlayer( player ) );
	
	if( !player killstreakrules::isKillstreakAllowed( DART_NAME, player.team ) )
		return false;
	
	player DisableOffhandWeapons();
	
	missileWeapon = player GetCurrentWeapon();
	if( !( isdefined( missileWeapon ) && ( ( missileWeapon.name == "dart" ) || ( missileWeapon.name == "inventory_dart" ) ) ) )
		return false;
	
	player thread WatchThrow( missileWeapon );

	notifyString = player util::waittill_any_return( "weapon_change", "grenade_fire", "death", "disconnect", "joined_team", "emp_jammed", "emp_grenaded" );

	if( notifyString == "death" || notifyString == "emp_jammed" || notifyString == "emp_grenaded" )
	{
		if( player.waitingOnDartThrow ) 
			player notify( "dart_putaway" );
		
		player EnableOffhandWeapons();
		return false; 
	}
	
	if( notifyString == "grenade_fire" )
	{
		// wait for the killStreakStart results
		return player wait_for_throw_status();
	}

	if( notifyString == "weapon_change" )
	{
		if( player.waitingOnDartThrow ) 
			player notify( "dart_putaway" );
		
		player EnableOffhandWeapons();
		return false; 
	}
	
	return true;
}

function cleanup_grenade()
{
	self thread waitThenDelete( 0.05 );
	self.origin = self.origin + ( 0, 0, 1000 );	
}

function WatchThrow( missileWeapon )
{
	assert( IsPlayer( self ) );
	player = self;
	playerEntNum = player.entNum;
	
	player endon( "disconnect" );
	player endon( "joined_team" );
	// player endon( "death" ); // once the dart is thrown, even after death, the player should control it
	player endon( "dart_putaway" );
	
	level endon( "game_ended" );

	player.waitingOnDartThrow = 1;
	player waittill( "grenade_fire", grenade, weapon );
	player.waitingOnDartThrow = 0;
	
	if( weapon != missileWeapon )
	{
		self notify("dart_throw_failed");
		return;
	}
	
	trace = player check_launch_space(grenade.origin);
	
	if ( trace["fraction"] < 1.0 )
	{
		self iprintlnbold( &"KILLSTREAK_DART_NOT_AVAILABLE" );
		grenade cleanup_grenade();
		self notify("dart_throw_failed");
		return;
	}
	
	killstreak_id = player killstreakrules::killstreakStart( DART_NAME, player.team, undefined, false );
	if( killstreak_id == INVALID_KILLSTREAK_ID )
	{
		grenade cleanup_grenade();
		self notify("dart_throw_failed");
		return;
	}
	
	player.dart_thrown_time = GetTime();
	
	player TakeWeapon( missileWeapon );
	
	player killstreaks::set_killstreak_delay_killcam( DART_NAME ); // special case: death while watching does not prevent riding dart, and thus no killcam
	player.resurrect_not_allowed_by = DART_NAME;

	player AddWeaponStat( GetWeapon( "dart" ), "used", 1 );
	level thread popups::DisplayKillstreakTeamMessageToAll( DART_NAME, player );
	
	dart = player SpawnDart( grenade, killstreak_id, trace["position"] );
	if( isdefined( dart ) )
	{
		player killstreaks::play_killstreak_start_dialog( DART_NAME, player.team, killstreak_id );
	}
}

function HackedPreFunction( hacker )
{
	dart = self;
	dart.owner util::freeze_player_controls( false );
	visionset_mgr::deactivate( "visionset", DART_VISIONSET_ALIAS, dart.owner );
	dart.owner clientfield::set_to_player( "fog_bank_3", 0 );
	dart.owner unlink();
	dart clientfield::set( "vehicletransition", 0 );
	dart.owner killstreaks::clear_using_remote();
	dart.owner killstreaks::unhide_compass();
	dart.owner vehicle::stop_monitor_missiles_locked_on_to_me();
	dart.owner vehicle::stop_monitor_damage_as_occupant();
	dart DisableDartMissileLocking();
}

function HackedPostFunction( hacker )
{
	dart = self;
	hacker StartDartRemoteControl( dart );
	
	hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( dart );
	hacker remote_weapons::UseRemoteWeapon( dart, DART_NAME, false );
	hacker killstreaks::set_killstreak_delay_killcam( DART_NAME );
}

function dart_hacked_health_update( hacker )
{
	dart = self;
	if ( dart.health > dart.hackedhealth )
	{
		dart.health = dart.hackedhealth;	
	}
}

function check_launch_space(origin)
{
	player_angles = self getPlayerAngles();
	forward = AnglesToForward( player_angles );
	spawn_origin = origin + VectorScale( forward, 50 );
	
	radius = 10;
	return physicstrace( origin, spawn_origin, ( -radius, -radius, 0 ), ( radius, radius, 2 * radius ), self, PHYSICS_TRACE_MASK_PHYSICS );
}

function SpawnDart( grenade, killstreak_id, spawn_origin )
{
	player = self;
	assert( IsPlayer( player ) );
	playerEntNum = player.entNum;
	player_angles = player getPlayerAngles();
	
	grenade cleanup_grenade();
	
	params = level.killstreakBundle[DART_NAME];

	DEFAULT( params.ksDartVehicle, "veh_dart_mp" );
	DEFAULT( params.ksDartInitialSpeed, 35 );
	DEFAULT( params.ksDartAcceleration, 35 );
		
	dart = SpawnVehicle( params.ksDartVehicle, spawn_origin, player_angles, "dynamic_spawn_ai" );
	
	dart.is_shutting_down = 0;
	dart.team = player.team;
	dart SetSpeedImmediate( params.ksDartInitialSpeed, params.ksDartAcceleration );
	dart.maxhealth = killstreak_bundles::get_max_health( DART_NAME );
	dart.health = dart.maxhealth;
	dart.hackedhealth = killstreak_bundles::get_hacked_health( DART_NAME );
	dart.hackedHealthUpdateCallback = &dart_hacked_health_update;
	
	dart killstreaks::configure_team( DART_NAME, killstreak_id, player, "small_vehicle" );
	dart killstreak_hacking::enable_hacking( DART_NAME, &HackedPreFunction, &HackedPostFunction );

	dart clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	dart.killstreak_id = killstreak_id;
	dart.hardpointType = DART_NAME;
	dart thread killstreaks::WaitForTimeout( DART_NAME, DART_DURATION, &stop_remote_weapon, "remote_weapon_end", "death" );
	dart hacker_tool::registerWithhackerTool( DART_HACKER_TOOL_RADIUS, DART_HACKER_TOOL_DURATION );
	dart.overrideVehicleDamage = &dartDamageOverride;	
	dart.DetonateViaEMP = &emp_damage_cb;
	dart.do_scripted_crash = false;
	dart.delete_on_death = true;
	dart.one_remote_use = true;
	dart.vehcheckforpredictedcrash = true;
	dart.predictedCollisionTime = 0.2;
	dart.glasscollision_alt = true;
	dart.damageTaken = 0;
	dart.death_enter_cb = &waitRemoteControl;
	
	Target_Set( dart );
	
	dart vehicle::init_target_group();
	dart vehicle::add_to_target_group( dart );
	
	dart thread WatchCollision();
	
	dart thread WatchDeath();
	
	dart thread WatchOwnerNonDeathEvents();
	
	dart.forceWaitRemoteControl = true;
	
	player util::waittill_any( "weapon_change", "death" ); // wait for the killstreak weapon to go away, or the player dies (special case for Dart)

	player remote_weapons::UseRemoteWeapon( dart, DART_NAME, true, true, true );
	
	player notify( "dart_entered" );
	
	return dart;
}

function waitRemoteControl()
{
	dart = self;
	
	remote_controlled = IS_TRUE( dart.control_initiated ) || IS_TRUE( dart.controlled );
	
	if( remote_controlled )
	{
		notifyString = dart util::waittill_any_return( "remote_weapon_end", "dart_left" );
		if ( isdefined( notifyString ) )
		{
			if( notifyString == "remote_weapon_end" )
				dart waittill( "dart_left" );
			else
				dart waittill( "remote_weapon_end" );
		}
	}
	else
		dart waittill( "dart_left" );
}

function StartDartRemoteControl( dart )
{
	player = self;
	assert( IsPlayer( player ) );

	if( !dart.is_shutting_down )
	{
		player.dart_thrown_time = undefined;
	
		dart UseVehicle( player, 0 );/// 
		player.resurrect_not_allowed_by = undefined;
		dart clientfield::set( "vehicletransition", 1 );
		dart thread WatchAmmo();
		dart thread vehicle::monitor_missiles_locked_on_to_me( player );
		dart thread vehicle::monitor_damage_as_occupant( player );
		
		player vehicle::set_vehicle_drivable_time_starting_now( DART_DURATION );
		player.no_fade2black = true;
		
		dart.inHeliProximity = false;
		
		minHeightOverride = undefined;
		minz_struct = struct::get( "vehicle_oob_minz", "targetname");
		if( isdefined( minz_struct ) )
			minHeightOverride = minz_struct.origin[2];			
		
		dart thread qrdrone::QRDrone_watch_distance( DART_MAX_HEIGHT_OFFSET, minHeightOverride );
		dart.distance_shutdown_override = &DartDistanceFailure;
		
		dart EnableDartMissileLocking();
		visionset_mgr::activate( "visionset", DART_VISIONSET_ALIAS, self, 1, 90000, 1 );		
		player clientfield::set_to_player( "fog_bank_3", 1 );
	}
}

function EndDartRemoteControl( dart, exitRequestedByOwner )
{
	dart thread leave_dart();
}

function DartDistanceFailure()
{
	thread stop_remote_weapon();
}
 
function stop_remote_weapon( attacker, weapon )
{
	dart = self;

	dart.DetonateViaEMP = undefined; 
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if ( isdefined( attacker ) && ( !isdefined( dart.owner ) ||  dart.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, true );
		attacker challenges::addFlySwatterStat( weapon, self );
		scoreevents::processScoreEvent( "destroyed_dart", attacker, dart.owner, weapon );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_DART", attacker.entnum );		
	}
	
	if( isdefined( attacker ) && attacker != dart.owner )
	{
		dart killstreaks::play_destroyed_dialog_on_owner( DART_NAME, dart.killstreak_id );
	}		

	dart thread remote_weapons::EndRemoteControlWeaponUse( false );		
}

function dartDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	dart = self;
	
	if( ( sMeansOfDeath == "MOD_TRIGGER_HURT" ) || IS_TRUE( dart.is_shutting_down ) )
		return 0;
	
	player = dart.owner;

	iDamage = killstreaks::OnDamagePerWeapon( DART_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, &stop_remote_weapon, self.maxhealth*0.4, undefined, 
	                                         0, &emp_damage_cb, true, 1.0 );

	return iDamage;
}

function emp_damage_cb( attacker, weapon )
{
	dart = self;
	dart stop_remote_weapon( attacker, weapon );
}

function DarPredictedCollision()
{
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "veh_predictedcollision", velocity, normal, ent, stype );
		self notify( "veh_collision", velocity, normal, ent, stype );
		
		if( stype == "glass" )
			continue;
		else
			break;
	}
}

function WatchCollision()
{
	dart = self;
	dart endon( "death" );
	dart.owner endon( "disconnect" );
	
	dart thread DarPredictedCollision();
	
	
	while( 1 )
	{
		dart waittill( "veh_collision", velocity, normal, ent, stype );
		
		if( stype === "glass" )
			continue;
		
		dart SetSpeedImmediate( 0 );
		dart vehicle_death::death_fx();
		
		dart thread stop_remote_weapon();
		break;
	}
}

function WatchDeath()
{
	dart = self;
	player = dart.owner;
	
	player endon( "dart_entered" ); // the remote weapon script should handle it from here on
	dart endon( "delete" );

	dart waittill( "death" );
	//dart waittill( "death", attacker, damageFromUnderneath, weapon, point, dir, modType );
	
	dart thread leave_dart();
}

function WatchOwnerNonDeathEvents( endCondition1, endCondition2 )
{
	dart = self;
	player = dart.owner;
	
	player endon( "dart_entered" ); // the remote weapon script should handle it from here on
	dart endon( "death" );
	
	dart thread WatchForGameEnd();
	
	player util::waittill_any( "joined_team", "disconnect", "joined_spectators", "emp_jammed" );
	
	dart thread leave_dart();
}

function WatchForGameEnd()
{
	dart = self;
	dart endon( "death" );	

	level waittill( "game_ended" );

	dart thread leave_dart();
}
	
function WatchAmmo()
{
	dart = self;
	dart endon( "death" );
	
	player = dart.owner;
	
	player endon( "disconnect" );
	
	shotCount = 0;
	
	params = level.killstreakBundle[DART_NAME];

	DEFAULT( params.ksDartShotCount, 3 );
	DEFAULT( params.ksDartBladeCount, 6 );
	DEFAULT( params.ksDartWaitTimeAfterLastShot, 1 );
	
	DEFAULT( params.ksBladeStartDistance, 0 );
	DEFAULT( params.ksBladeEndDistance, 10000 );
	DEFAULT( params.ksBladeStartSpreadRadius, 50 );
	DEFAULT( params.ksBladeEndSpreadRadius, 1 );
	
	player clientfield::set_to_player( "dart_update_ammo", params.ksDartShotCount );

	while( true )
	{
		dart waittill( "weapon_fired" );
		shotCount++;
		
		player clientfield::set_to_player( "dart_update_ammo", params.ksDartShotCount - shotCount );
		
		if( shotCount >= params.ksDartShotCount )
		{
			dart DisableDriverFiring( true );
			wait( params.ksDartWaitTimeAfterLastShot );
			dart stop_remote_weapon();
		}
	}
}

function leave_dart()
{
	dart = self;
	owner = dart.owner;
	
	if( isdefined( owner ) )
	{
		visionset_mgr::deactivate( "visionset", DART_VISIONSET_ALIAS, owner );
		owner clientfield::set_to_player( "fog_bank_3", 0 );
		owner qrdrone::destroyHud();	
	}
	
	if( isdefined( dart ) && ( dart.is_shutting_down == 1 ) )
		return;
	
	dart.is_shutting_down = 1;
	
	dart clientfield::set( "timeout_beep", 0 );
	dart vehicle::lights_off();
	dart vehicle_death::death_fx();
	dart Hide();
	
	dart_original_team = dart.originalteam;
	dart_killstreak_id = dart.killstreak_id;
	
	if( Target_IsTarget( dart ) )
		Target_Remove( dart );
	
	iF( isalive( dart ) )
		dart notify( "death" );	
	
	params = level.killstreakBundle[DART_NAME];
	
	DEFAULT( params.ksDartExplosionOuterRadius, 200 ); 
	DEFAULT( params.ksDartExplosionInnerRadius, 1 );
	DEFAULT( params.ksDartExplosionOuterDamage, 25 );
	DEFAULT( params.ksDartExplosionInnerDamage, 350 );
	DEFAULT( params.ksDartExplosionMagnitude, 1 );
	
	PhysicsExplosionSphere( dart.origin, 
	                       params.ksDartExplosionOuterRadius, 
	                       params.ksDartExplosionInnerRadius, 
	                       params.ksDartExplosionMagnitude,
	                       params.ksDartExplosionOuterDamage,
	                       params.ksDartExplosionInnerDamage );
	
	if( isdefined( owner ) )
	{
		owner killstreaks::set_killstreak_delay_killcam( DART_NAME ); // hold the respawn till we finish here
		
		dart RadiusDamage( dart.origin, 
		             params.ksDartExplosionOuterRadius,
		             params.ksDartExplosionInnerDamage,
		             params.ksDartExplosionOuterDamage,
		             owner, 
		             "MOD_EXPLOSIVE",
		             GetWeapon( "dart" ) );
		
		owner thread play_bda_dialog( self.pilotIndex );		
		
		if( IS_TRUE( dart.controlled ) || IS_TRUE( dart.control_initiated ) )
		{
			owner SetClientUIVisibilityFlag( "hud_visible", 0 );
			owner unlink();
			dart clientfield::set( "vehicletransition", 0 );
			
			if( isdefined( params.ksExplosionRumble ) )
				owner PlayRumbleOnEntity( params.ksExplosionRumble );

			owner vehicle::stop_monitor_missiles_locked_on_to_me();
			owner vehicle::stop_monitor_damage_as_occupant();
			
			dart DisableDartMissileLocking();
			
			owner util::freeze_player_controls( true );
		
			forward = AnglesToForward( dart.angles );
			DEFAULT( params.ksDartCameraWatchDistance, 350 );
			moveAmount = VectorScale( forward, -( params.ksDartCameraWatchDistance ) );
			
			size = 4;
			trace = physicstrace( dart.origin, dart.origin + moveAmount, ( -size, -size, -size ), ( size, size, size ), undefined, PHYSICS_TRACE_MASK_PHYSICS );
			
			cam = spawn( "script_model", trace["position"] );
			cam SetModel( "tag_origin" );
			cam LinkTo( dart );
			dart SetSpeedImmediate( 0 );
			
			owner CameraSetPosition( cam.origin );
			owner CameraSetLookAt( dart.origin );
			owner CameraActivate( true );	
		
			DEFAULT( params.ksDartCameraWatchDuration, 2 );
			wait( params.ksDartCameraWatchDuration );
			
			if ( isdefined( owner ) )
			{
				owner CameraActivate( false );
			}
			
			cam delete();
			
			if( isdefined( owner ) )
			{
				if( !level.gameEnded )
					owner util::freeze_player_controls( false );
				
				owner SetClientUIVisibilityFlag( "hud_visible", 1 );
			}
		}
		
		if ( isdefined( owner ) )
		{
			owner killstreaks::reset_killstreak_delay_killcam();
		}
	}

	killstreakrules::killstreakStop( DART_NAME, dart_original_team, dart_killstreak_id );
	
	if ( isdefined( dart ) )
	{
		dart notify( "dart_left" );
	}
}

function DeleteOnConditions( condition )
{
	dart = self;
	dart endon( "delete" );
	
	if( isdefined( condition ) )
		dart waittill( condition );
	
	dart notify( "delete" );
	dart delete();
}

function waitThenDelete( waitTime )
{
	self endon( "delete" );
	self endon( "death" );
	wait( waitTime );
	self delete();
}

function play_bda_dialog( pilotIndex )
{
	self endon( "game_ended" );

	wait( 0.5 );
	
	if ( !isdefined( self.dartBda ) || self.dartBda == 0 )
	{
		bdaDialog = "killNone";
	}
	else if ( self.dartBda == 1 )
	{
		bdaDialog = "kill1";
	}
	else if ( self.dartBda == 2 )
	{
		bdaDialog = "kill2";
	}
	else if ( self.dartBda == 3 )
	{
		bdaDialog = "kill3";
	}
	else if ( self.dartBda > 3 )
	{
		bdaDialog = "killMultiple";
	}

	self killstreaks::play_pilot_dialog( bdaDialog, DART_NAME, undefined, pilotIndex );
	
	self.dartBda = undefined;
}

function EnableDartMissileLocking() // self == dart
{	
	dart = self;
	player = dart.owner;
	weapon = dart SeatGetWeapon( 0 );
	
	player.get_stinger_target_override = &GetDartMissileTargets;
	player.is_still_valid_target_for_stinger_override = &IsStillValidDartMissileTarget;
	player.is_valid_target_for_stinger_override = &IsValidDartMissileTarget;
	player.dart_killstreak_weapon = weapon;

	player thread heatseekingmissile::StingerIRTLoop( weapon );
}

function DisableDartMissileLocking() // self == dart
{
	player = self.owner;
	
	player.get_stinger_target_override = undefined;
	player.is_still_valid_target_for_stinger_override = undefined;
	player.is_valid_target_for_stinger_override = undefined;
	player.dart_killstreak_weapon = undefined;
	
	player notify( "stinger_IRT_off" );
	player heatseekingmissile::ClearIRTarget();
}

function GetDartMissileTargets()
{
	targets = ArrayCombine( target_getArray(), level.MissileEntities, false, false );
	targets = ArrayCombine( targets, level.players, false, false );
	
	return targets;
}

function IsValidDartMissileTarget( ent ) // self == player
{
	player = self;
	
	if ( !isdefined( ent ) )
		return false;
	
	entIsPlayer = IsPlayer( ent );

	if ( entIsPlayer && !IsAlive( ent ) )
		return false;

	if ( ent.ignoreme === true )
		return false;

	dart = player GetVehicleOccupied();
	if ( !isdefined( dart ) )
		return false;

	if ( DistanceSquared( dart.origin, ent.origin ) > SQR( player.dart_killstreak_weapon.lockOnMaxRange ) )
		return false;

	if ( entIsPlayer && ent HasPerk( "specialty_nokillstreakreticle" ) )
		return false;

	return true;	
}

function IsStillValidDartMissileTarget( ent, weapon ) // self == player
{
	player = self;
	
	if ( !( target_isTarget( ent ) || IsPlayer( ent ) ) && !( isdefined( ent.allowContinuedLockonAfterInvis ) && ent.allowContinuedLockonAfterInvis ) )
		return false;
	
	dart = player GetVehicleOccupied();
	if ( !isdefined( dart ) )
		return false;
	
	entIsPlayer = IsPlayer( ent );
	
	if ( entIsPlayer && !IsAlive( ent ) )
		return false;
	
	if ( ent.ignoreme === true )
		return false;

	if ( DistanceSquared( dart.origin, ent.origin ) > SQR( player.dart_killstreak_weapon.lockOnMaxRange ) )
		return false;
	
	if ( entIsPlayer && ent HasPerk( "specialty_nokillstreakreticle" ) )
		return false;
		
	if ( !heatseekingmissile::InsideStingerReticleLocked( ent, weapon ) )
		return false;

	return true;
}
