#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\ai_puppeteer_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\objpoints_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\entityheadicons_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicleriders_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\ai\systems\blackboard;

#using scripts\mp\_challenges;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_supplydrop;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\mp\killstreaks\_remote_weapons.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\archetype_damage_effects.gsh;
#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#namespace combat_robot;

#define COMBAT_ROBOT_FORWARD_SPAWN_OFFSET 72
#define COMBAT_ROBOT_GUARD_RADIUS 1000
#define COMBAT_ROBOT_DEFEND_ICON "t7_hud_ks_c54i_drop"
#define COMBAT_ROBOT_NAME "combat_robot"
#define COMBAT_ROBOT_INFLUENCER "small_vehicle"
#define COMBAT_ROBOT_MARKER_NAME "combat_robot_marker"
#define INVENTORY_COMBAT_ROBOT_NAME "inventory_combat_robot"

// Tweaks to how the combat robot's body is thrown after exploding
#define COMBAT_ROBOT_VELOCITY_SCALAR ( 1 / 8 )		// Scales the initial velocity
#define COMBAT_ROBOT_ADD_X_VELOCITY_MIN -20
#define COMBAT_ROBOT_ADD_X_VELOCITY_MAX 20
#define COMBAT_ROBOT_ADD_Y_VELOCITY_MIN -20
#define COMBAT_ROBOT_ADD_Y_VELOCITY_MAX 20
#define COMBAT_ROBOT_ADD_Z_VELOCITY_MIN 60
#define COMBAT_ROBOT_ADD_Z_VELOCITY_MAX 80

// Time in seconds the combat robot will shutdown before exploding.
#define COMBAT_ROBOT_MIN_SHUTDOWN 3.0
#define COMBAT_ROBOT_MAX_SHUTDOWN 4.5

// The combat robot will give up chasing an enemy if they haven't attacked them for this long.
#define COMBAT_ROBOT_GIVE_UP_ON_ENEMY 10000

// The combat robot will ignore unattackable enemies for this long.
#define COMBAT_ROBOT_IGNORE_UNATTACKABLE_ENEMY 5000
	
#define COMBAT_ROBOT_NAV_MESH_VALID_LOCATION_BOUNDARY 	18
#define COMBAT_ROBOT_NAV_MESH_VALID_LOCATION_TOLERANCE	4
	
#define COMBAT_ROBOT_KILLCAM_TIME_OFFSET		( 750 )

#precache( "string", "KILLSTREAK_COMBAT_ROBOT_ESCORT_HINT" );
#precache( "string", "KILLSTREAK_COMBAT_ROBOT_GUARD_HINT" );
#precache( "string", "KILLSTREAK_COMBAT_ROBOT_INBOUND" );
#precache( "string", "KILLSTREAK_COMBAT_ROBOT_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_COMBAT_ROBOT_HACKED" );
#precache( "string", "KILLSTREAK_COMBAT_ROBOT_PATROL_FAIL" );
#precache( "string", "KILLSTREAK_DESTROYED_COMBAT_ROBOT" );
#precache( "triggerstring", "KILLSTREAK_COMBAT_ROBOT_ESCORT_HINT" );
#precache( "triggerstring", "KILLSTREAK_COMBAT_ROBOT_GUARD_HINT" );

#precache( "material", COMBAT_ROBOT_DEFEND_ICON );

function init()
{
	killstreaks::register( COMBAT_ROBOT_NAME, COMBAT_ROBOT_MARKER_NAME, "killstreak_" + COMBAT_ROBOT_NAME, COMBAT_ROBOT_NAME + "_used", &ActivateCombatRobot, undefined, true );
	killstreaks::register_alt_weapon( COMBAT_ROBOT_NAME, "lmg_light_robot" );
	killstreaks::register_strings( COMBAT_ROBOT_NAME, &"KILLSTREAK_COMBAT_ROBOT_EARNED", &"KILLSTREAK_COMBAT_ROBOT_NOT_AVAILABLE", &"KILLSTREAK_COMBAT_ROBOT_INBOUND", undefined,  &"KILLSTREAK_COMBAT_ROBOT_HACKED" );
	killstreaks::register_dialog( COMBAT_ROBOT_NAME, "mpl_killstreak_combat_robot", "combatRobotDialogBundle", "combatRobotPilotDialogBundle", "friendlyCombatRobot", "enemyCombatRobot", "enemyCombatRobotMultiple", "friendlyCombatRobotHacked", "enemyCombatRobotHacked", "requestCombatRobot", "threatCombatRobot" );
	
	// TODO: Move to killstreak data
	level.killstreaks[INVENTORY_COMBAT_ROBOT_NAME].threatOnKill = true;
	level.killstreaks[COMBAT_ROBOT_NAME].threatOnKill = true;
	
	level thread _CleanupRobotCorpses();
}

function private _CalculateProjectedGuardPosition( player )
{
	// Find the closest navmesh position projected out from the reticle.
	return GetClosestPointOnNavMesh( player.origin, 48 );
}

function private _CalculateRobotSpawnPosition( player )
{
	desiredSpawnPosition = AnglesToForward( player.angles ) *
		COMBAT_ROBOT_FORWARD_SPAWN_OFFSET + player.origin;
	
	return GetClosestPointOnNavMesh( desiredSpawnPosition, 48 );
}

function private _CleanupRobotCorpses()
{
	corpseDeleteTime = 15000;

	while ( true )
	{
		deleteCorpses = [];
	
		foreach ( corpse in GetCorpseArray() )
		{
			if ( IsDefined( corpse.birthtime ) &&
				IsDefined( corpse.archetype ) &&
				corpse.archetype == "robot" &&
				( corpse.birthtime + corpseDeleteTime ) < GetTime() )
			{
				deleteCorpses[ deleteCorpses.size ] = corpse;
			}
		}
		
		for ( index = 0; index < deleteCorpses.size; index++ )
		{
			deleteCorpses[ index ] Delete();
		}
	
		wait ( corpseDeleteTime / 1000 ) / 2;
	}
}

function ConfigureTeamPost( player, isHacked )
{
	robot = self;
	robot.properName = "";
	// Prevent the robot from being damaged based on a hurt trigger when being called in.
	robot.ignoreTriggerDamage = true;
	
	robot.empShutdownTime = COMBAT_ROBOT_EMP_DURATION;
	robot.minWalkDistance = 60;
	robot.superSprintDistance = 180;
	robot.robotRusherMinRadius = 64;
	robot.robotRusherMaxRadius = 120;
	robot.allowPushActors = false;
	robot.chargeMeleeDistance = 0;  		// Disable charge melee, more effective to shoot.
	robot.fovcosine = 0;  					// 360 degree field of view
	robot.fovcosinebusy = 0;  				// 360 degree field of view even when busy
	robot.MaxSightDistSqrd = SQR( 2000 );
	
	Blackboard::SetBlackBoardAttribute( robot, ROBOT_MODE, "combat" );
	
	// Disable head gibbing.
	robot.gib_state = SET_GIBBED( GIB_UNDAMAGED_FLAG, GIB_TORSO_HEAD_FLAG );
	robot clientfield::set( GIB_CLIENTFIELD, robot.gib_state );
	
	_ConfigureRobotTeam( robot, player, isHacked );
	
	robot ai::set_behavior_attribute( "can_become_crawler", false );
	robot ai::set_behavior_attribute( "can_be_meleed", false );
	robot ai::set_behavior_attribute( "can_initiateaivsaimelee", false );
	robot ai::set_behavior_attribute( "supports_super_sprint", true );
}

function private _ConfigureRobotTeam( robot, player, isHacked )
{
	if ( isHacked ) 
	{
		lightsState = ROBOT_LIGHTS_HACKED;
	}
	else
	{
		lightsState = ROBOT_LIGHTS_ON;
	}
	robot ai::set_behavior_attribute( "robot_lights", lightsState );
	robot thread WatchCombatRobotOwnerDisconnect( player );
	
	if ( !isdefined( robot.objective ) )
	{
		robot.objective = GetEquipmentHeadObjective( GetWeapon( "combat_robot_marker" ) );
	}

	robot thread _WatchModeSwap( robot, player );
	robot thread _Underwater( robot );
}

	
function private _CreateGuardMarker( robot, position )
{
	owner = robot.owner;
	guardMarker = spawn( "script_model", ( 0, 0, 0 ) );	
	guardMarker.origin = position;
	guardMarker entityheadicons::setEntityHeadIcon( owner.pers["team"], owner, undefined, &"airdrop_combatrobot" );
	
	return guardMarker;
}

function private _DestroyGuardMarker( robot )
{
	if ( isdefined( robot.guardMarker ) )
	{
		robot.guardMarker delete();
	}
}

function private _Underwater( robot )
{
	robot endon( "death" );
	
	while ( true )
	{
		if ( ( robot.origin[2] + ROBOT_HEIGHT / 2.0 ) <= GetWaterHeight( robot.origin ) )
		{
			robot ASMSetAnimationRate( 0.85 );
		}
		else
		{
			robot ASMSetAnimationRate( 1.0 );
		}
		
		wait 0.1;
	}
}

function private _Escort( robot )
{
	robot endon( "death" );

	robot.escorting = true;
	robot.guarding = false;
	
	_DestroyGuardMarker( robot );
	
	while ( robot.escorting )
	{
		attackingEnemy = false;
	
		if ( IsDefined( robot.enemy ) && IsAlive( robot.enemy ) )
		{
			if ( ( robot LastKnownTime( robot.enemy ) + COMBAT_ROBOT_GIVE_UP_ON_ENEMY ) >= GetTime() )
			{
				robot ai::set_behavior_attribute( "move_mode", "rusher" );
				
				attackingEnemy = true;
			}
			else
			{
				robot ClearEnemy();
			}
		}
		
		if ( !attackingEnemy && IsDefined( robot.owner ) && IsAlive( robot.owner ) )
		{
			lookAheadTime = 1.0;
			predicitedPosition =
				robot.owner.origin + VectorScale( robot.owner GetVelocity(), lookAheadTime );
		
			robot ai::set_behavior_attribute( "escort_position", predicitedPosition );
			robot ai::set_behavior_attribute( "move_mode", "escort" );
		}
		
		wait 1;
	}
}

function private _IgnoreUnattackableEnemy( robot, enemy )
{
	robot endon( "death" );
	
	robot SetIgnoreEnt( enemy, true );
	
	wait COMBAT_ROBOT_IGNORE_UNATTACKABLE_ENEMY / 1000;
	
	robot SetIgnoreEnt( enemy, false );
}

function private _GuardPosition( robot, position )
{
	robot endon( "death" );

	robot.goalradius = COMBAT_ROBOT_GUARD_RADIUS;
	robot SetGoal( position );
	
	robot.escorting = false;
	robot.guarding = true;
	
	_DestroyGuardMarker( robot );
	
	robot.guardMarker = _CreateGuardMarker( robot, position );
	
	while ( robot.guarding )
	{
		attackingEnemy = false;
	
		if ( IsDefined( robot.enemy ) && IsAlive( robot.enemy ) )
		{
			if ( ( robot LastKnownTime( robot.enemy ) + COMBAT_ROBOT_GIVE_UP_ON_ENEMY ) >= GetTime() )
			{
				// Robot still within goalradius, continue pursuit.
				robot ai::set_behavior_attribute( "move_mode", "rusher" );
				
				attackingEnemy = true;
			}
			else
			{
				robot ClearEnemy();
			}
		}
		
		if ( !attackingEnemy )
		{
			robot ai::set_behavior_attribute( "move_mode", "guard" );
		}
		
		wait 1;
	}
}

function _WatchModeSwap( robot, player )
{
	robot endon( "death" );
	
	nextSwitchTime = GetTime();
	
	while ( true )
	{
		WAIT_SERVER_FRAME;
		
		if( !isdefined( robot.useTrigger ) )
		   continue;
		   
		robot.useTrigger waittill( "trigger" );

		if ( nextSwitchTime <= GetTime() && IsAlive( player ) )
		{
			if ( IS_TRUE( robot.guarding ) )
			{
				robot.guarding = false;
				robot.escorting = true;
				
				player playsoundtoplayer( "uin_mp_combat_bot_escort", player );
				robot thread _Escort( robot );
				if( isdefined( robot.useTrigger ) )
					robot.useTrigger SetHintString( &"KILLSTREAK_COMBAT_ROBOT_GUARD_HINT" );
				
				if( isdefined( robot.markerFXHandle ) )
					robot.markerFXHandle delete();
			}
			else
			{
				navGuardPosition = _CalculateProjectedGuardPosition( player );
				
				if ( IsDefined( navGuardPosition ) )
				{
					robot.guarding = true;
					robot.escorting = false;
					
					player playsoundtoplayer( "uin_mp_combat_bot_guard", player );
					robot thread _GuardPosition( robot, navGuardPosition );
					if( isdefined( robot.useTrigger ) )
						robot.useTrigger SetHintString( &"KILLSTREAK_COMBAT_ROBOT_ESCORT_HINT" );
					
					if( isdefined( robot.markerFXHandle ) )
						robot.markerFXHandle delete();
					
					params = level.killstreakBundle[COMBAT_ROBOT_NAME];
					if( isdefined( params.ksCombatRobotPatrolFX ) )
					{
						point = player.origin;
						if( !isdefined( point ) )
							point = navGuardPosition;
						
						robot.markerFXHandle = SpawnFx( params.ksCombatRobotPatrolFX, point + ( 0, 0, 3 ), ( 0, 0, 1 ), ( 1, 0, 0 ) );
						robot.markerFXHandle.team = player.team;
						TriggerFX( robot.markerFXHandle );
						
						robot.markerFXHandle SetInvisibleToAll();
						robot.markerFXHandle SetVisibleToPlayer( player );
					}
				}
				else
				{
					player iPrintLnBold( &"KILLSTREAK_COMBAT_ROBOT_PATROL_FAIL" );
				}
			}
			
			robot notify("bhtn_action_notify", "modeSwap");
			
			nextSwitchTime = GetTime() + 1000;
		}
	}
}

function ActivateCombatRobot( killstreak )
{
	player = self;
	team = self.team;
	
	if( !self supplydrop::isSupplyDropGrenadeAllowed( killstreak ) )
	{
		return false;
	}

	killstreak_id = self killstreakrules::killstreakStart( killstreak, team, false, false );
	if ( killstreak_id == -1 )
	{
		return false;
	}
	
	context = SpawnStruct();
	context.prolog = &Prolog;
	context.epilog = &Epilog;
	
	context.hasFlares = 1;
	context.radius = level.killstreakCoreBundle.ksAirdropRobotRadius;
	context.dist_from_boundary = COMBAT_ROBOT_NAV_MESH_VALID_LOCATION_BOUNDARY;
	context.max_dist_from_location = COMBAT_ROBOT_NAV_MESH_VALID_LOCATION_TOLERANCE;
	context.perform_physics_trace = true;
	context.drop_from_goal_distance2d = 96; // combat robot doesn't need this value to be strict (note: drop ship related)
	context.isLocationGood = &supplydrop::IsLocationGood;
	context.objective = &"airdrop_combatrobot";	
	context.killstreakRef = killstreak;
	context.validLocationSound = level.killstreakCoreBundle.ksValidCombatRobotLocationSound;	
	context.vehiclename = "combat_robot_dropship";
	context.killstreak_id = killstreak_id;
	context.tracemask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_WATER;
	
	// This offset is specific to the exit vtol animation of the combat rider.
	context.dropOffset = (0, -120, 0);
	
	result = self supplydrop::useSupplyDropMarker( killstreak_id, context );
	
	if ( !isdefined(result) || !result )
	{
		killstreakrules::killstreakStop( killstreak, team, killstreak_id );
		return false;
	}

	self killstreaks::play_killstreak_start_dialog( COMBAT_ROBOT_NAME, self.team, killstreak_id );	
	self killstreakrules::displayKillstreakStartTeamMessageToAll( COMBAT_ROBOT_NAME );
	
	self AddWeaponStat( GetWeapon( COMBAT_ROBOT_MARKER_NAME ), "used", 1 );
	
	return result;
}	


function DropKillThread()
{
	robot = self;
	robot endon( "death" );
	robot endon( "combat_robot_land" );

	while( true )
	{	
		robot supplydrop::is_touching_crate();
		robot supplydrop::is_clone_touching_crate();
		WAIT_SERVER_FRAME;
	}
}

function WatchHelicopterDeath( context )
{
	helicopter = self;
	helicopter waittill( "death" );
	
	callback::callback( #"on_vehicle_killed" );
	
	if( isdefined( context.marker ) )
	{
		context.marker delete();
		context.marker = undefined;
		
		if( isdefined( context.markerFXHandle ) )
		{
			context.markerFXHandle delete();
			context.markerFXHandle = undefined;
		}
		supplydrop::DelDropLocation( context.killstreak_id );
	}		
}

function Prolog( context )
{
	helicopter = self;
	player = helicopter.owner;
	
	spawnPosition = ( 0,0,0 );
	spawnAngles = ( 0,0,0 );
	
	combatRobot = SpawnActor(
						"spawner_bo3_robot_grunt_assault_mp",
						spawnPosition,
						spawnAngles,
						"",
						true );
	combatRobot.missileTrackDamage = 0;
	combatRobot killstreaks::configure_team( COMBAT_ROBOT_NAME, context.killstreak_id, player, COMBAT_ROBOT_INFLUENCER, undefined, &ConfigureTeamPost );
	combatRobot killstreak_hacking::enable_hacking( COMBAT_ROBOT_NAME, undefined, &HackedCallbackPost );
	combatRobot thread _Escort( combatRobot );

	combatRobot thread WatchCombatRobotHelicopterHacked( helicopter );
	combatRobot thread WatchCombatRobotShutdown();
	combatRobot thread WatchCombatRobotDeath();
	combatRobot thread killstreaks::WaitForTimeout( COMBAT_ROBOT_NAME, COMBAT_ROBOT_DURATION, &OnCombatRobotTimeout, "combat_robot_shutdown" );
	combatRobot thread sndWatchCombatRobotVoxNotifies();
	
	helicopter thread WatchHelicopterDeath( context );
	helicopter.unloadTimeout = 6;
	
	killstreak_detect::killstreakTargetSet( combatRobot, ( 0, 0, 50 ) );
	
	combatRobot.maxhealth = combatRobot.health;
	
	tableHealth = killstreak_bundles::get_max_health( COMBAT_ROBOT_NAME );
	
	if ( isdefined( tableHealth ) )
	{
		combatRobot.maxhealth = tableHealth;
	}
	
	combatRobot.health = combatRobot.maxhealth;
	combatRobot.treat_owner_damage_as_friendly_fire = true;
	combatRobot.ignore_team_kills = true;
	combatRobot.remoteMissileDamage = combatRobot.maxhealth + 1;
	combatRobot.rocketDamage = combatRobot.maxhealth / 2 + 1;
	combatRobot thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile("death");
	combatRobot clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	combatRobot.soundmod = "drone_land";
	
	AiUtility::AddAIOverrideDamageCallback( combatRobot, &combatRobotDamageOverride );	
	
	combatRobot.vehicle = helicopter;
	combatRobot.vehicle.ignore_seat_check = true;
	combatRobot vehicle::get_in( helicopter , "driver", true );	
	
	combatRobot.overrideDropPosition = player.markerPosition;

	combatRobot thread WatchCombatRobotLanding();
	combatRobot thread sndWatchExit();
	combatRobot thread sndWatchLanding();
	combatRobot thread sndWatchActivate();
	
	foreach( player in level.players )
	{
		combatRobot respectNotTargetedByRobotPerk( player );
	}
	
	callback::on_spawned( &respectNotTargetedByRobotPerk, combatRobot );
	context.robot = combatRobot;
}

function respectNotTargetedByRobotPerk( player )
{
	combatRobot = self;
	combatRobot setignoreent( player, player hasperk( "specialty_nottargetedbyrobot" ) );
}

function Epilog( context )
{
	helicopter = self;
	
	context.robot thread DropKillThread();
	context.robot.startTime = GetTime() + COMBAT_ROBOT_KILLCAM_TIME_OFFSET; // set killcam to start a time offset from when drop ship arrives
	thread CleanupThread( context );

	helicopter WaitThenSetDeleteAfterDestructionWaitTime( 0.8, VAL( self.unloadTimeout, 0 ) + 0.1 );

	helicopter vehicle::unload( "all", undefined, true, 0.8 ); // removes robot as rider so that it doesn't
}

function WaitThenSetDeleteAfterDestructionWaitTime( set_wait_time, delete_after_destruction_wait_time )
{
	wait set_wait_time;

	if ( isdefined( self ) )
	{		
		self.delete_after_destruction_wait_time = delete_after_destruction_wait_time; 
	}
}

function HackedCallbackPost( hacker )
{
	robot = self;
	robot ClearEnemy();
	robot SetupCombatRobotHintTrigger( hacker );	
}


function WatchCombatRobotHelicopterHacked( helicopter )
{
	robot = self;
	robot endon( "death" );
	robot endon( "killstreak_hacked" );
	robot endon( "combat_robot_land" );

	helicopter endon( "death" );

	helicopter waittill( "killstreak_hacked", hacker );

	if( robot flagsys::get( "in_vehicle" ) == false )
		return;
	
	robot [[ robot.killstreak_hackedCallback ]]( hacker );
}

function CleanupThread( context )
{
	robot = context.robot;
	while( isdefined( robot ) && isdefined( context.marker ) && ( robot flagsys::get( "in_vehicle" ) ) ) 
	{
		wait 1;
	}
	if( isdefined( context.marker ) )
	{
		context.marker delete();
		context.marker = undefined;
		
		if( isdefined( context.markerFXHandle ) )
		{
			context.markerFXHandle delete();
			context.markerFXHandle = undefined;
		}
		supplydrop::DelDropLocation( context.killstreak_id );
	}
}

function WatchCombatRobotDeath()
{
	combatRobot = self;
	combatRobot endon( "combat_robot_shutdown" );
	callback::remove_on_spawned( &respectNotTargetedByRobotPerk, combatRobot );
	combatRobot waittill( "death", attacker, damageFromUnderneath, weapon );
	// combatRobot waittill( "death", attacker, damageFromUnderneath, weapon, point, dir, modType );
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );

	if ( isdefined( attacker ) && IsPlayer( attacker ) && ( !isdefined( combatRobot.owner ) || combatRobot.owner util::IsEnemyPlayer( attacker ) ) )
	{
		attacker challenges::destroyScoreStreak( weapon, false, true );
		attacker challenges::destroyNonAirScoreStreak_PostStatsLock( weapon );
		scoreevents::processScoreEvent( "destroyed_combat_robot", attacker, combatRobot.owner, weapon );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_COMBAT_ROBOT", attacker.entnum );		
	}
	
	combatRobot killstreaks::play_destroyed_dialog_on_owner( COMBAT_ROBOT_NAME, combatRobot.killstreak_id );
	
	combatRobot notify( "combat_robot_shutdown" );
}

function WatchCombatRobotLanding()
{
	robot = self;
	robot endon( "death" );
	robot endon( "combat_robot_shutdown" );
	
	// wait for landing
	while( robot flagsys::get( "in_vehicle" ) )  
	{
		wait 1;
	}
	
	robot notify( "combat_robot_land" );
	
	robot.ignoreTriggerDamage = false;
	
	// only check if on nav mesh after finishing traversals
	while ( isdefined( robot.traverseStartNode ) )
	{
		robot waittill( "traverse_end" );
	}
	
	v_on_navmesh = GetClosestPointOnNavMesh( robot.origin, 50, 20 );
	
	if ( isdefined ( v_on_navmesh ) )
	{
		player = robot.owner;
		
		robot SetupCombatRobotHintTrigger( player );
	}
	else
	{
		robot notify( "combat_robot_shutdown" );
	}
}

function SetupCombatRobotHintTrigger( player )
{
	robot = self;
	if ( isdefined( robot.useTrigger ) )
	{
		robot.useTrigger delete();
	}
	robot.useTrigger = spawn( "trigger_radius_use", player.origin, 32, 32 );
	robot.useTrigger EnableLinkTo();
	robot.useTrigger LinkTo( player );
	robot.useTrigger SetHintLowPriority( true );
	robot.useTrigger SetCursorHint( "HINT_NOICON" );
	robot.useTrigger SetHintString( &"KILLSTREAK_COMBAT_ROBOT_GUARD_HINT" );
		
	robot.useTrigger SetTeamForTrigger( player.team );
	robot.useTrigger.team = player.team;
	
	player ClientClaimTrigger( robot.useTrigger );
	player.remoteControlTrigger = robot.useTrigger;
	robot.useTrigger.ClaimedBy = player;	
}

function WatchCombatRobotOwnerDisconnect( player )
{
	combatRobot = self;
	combatRobot notify( "WatchCombatRobotOwnerDisconnect_singleton" );
	combatRobot endon( "WatchCombatRobotOwnerDisconnect_singleton" );
	combatRobot endon( "combat_robot_shutdown" );
	
	player util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	combatRobot notify( "combat_robot_shutdown" );
}

function private _corpseWatcher()
{
	archetype = self.archetype;
 	self waittill("actor_corpse", corpse);
 	corpse clientfield::set("arch_actor_fire_fx", BURN_SMOLDER);
}

function private _explodeRobot( combatRobot )
{
	combatRobot clientfield::set("arch_actor_fire_fx", BURN_BODY);
	clientfield::set(
		ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD, ROBOT_MIND_CONTROL_EXPLOSION_ON );
	combatRobot thread _corpseWatcher();
	
	if ( RandomInt( 100 ) >= 50 )
		GibServerUtils::GibLeftArm( combatRobot );
	else
		GibServerUtils::GibRightArm( combatRobot );
	
	GibServerUtils::GibLegs( combatRobot );
	GibServerUtils::GibHead( combatRobot );
	
	velocity = combatRobot GetVelocity() * COMBAT_ROBOT_VELOCITY_SCALAR;
	
	combatRobot StartRagdoll();
	combatRobot LaunchRagdoll(
		( velocity[0] + RandomFloatRange( COMBAT_ROBOT_ADD_X_VELOCITY_MIN, COMBAT_ROBOT_ADD_X_VELOCITY_MAX ),
		velocity[1] + RandomFloatRange( COMBAT_ROBOT_ADD_Y_VELOCITY_MIN, COMBAT_ROBOT_ADD_Y_VELOCITY_MAX ),
		RandomFloatRange( COMBAT_ROBOT_ADD_Z_VELOCITY_MIN, COMBAT_ROBOT_ADD_Z_VELOCITY_MAX ) ),
		"j_mainroot" );
}

function OnCombatRobotTimeout()
{
	combatRobot = self;
	
	combatRobot killstreaks::play_pilot_dialog_on_owner( "timeout", COMBAT_ROBOT_NAME );
	
	combatRobot ai::set_behavior_attribute( "shutdown", true );
	
	wait RandomFloatRange( COMBAT_ROBOT_MIN_SHUTDOWN, COMBAT_ROBOT_MAX_SHUTDOWN );
	
	_explodeRobot( combatRobot );
	
	params = level.killstreakBundle[COMBAT_ROBOT_NAME];
	
	if( isdefined( params.ksExplosionFX ) )
	{
		PlayFXOnTag( params.ksExplosionFX, combatRobot, "tag_origin" );
	}
	Target_Remove( combatRobot );
	
	DEFAULT( params.ksExplosionOuterRadius, 200 ); 
	DEFAULT( params.ksExplosionInnerRadius, 1 );
	DEFAULT( params.ksExplosionOuterDamage, 25 );
	DEFAULT( params.ksExplosionInnerDamage, 350 );
	DEFAULT( params.ksExplosionMagnitude, 1 );
	
	PhysicsExplosionSphere( combatRobot.origin, 
	                       params.ksExplosionOuterRadius, 
	                       params.ksExplosionInnerRadius, 
	                       params.ksExplosionMagnitude,
	                       params.ksExplosionOuterDamage,
	                       params.ksExplosionInnerDamage );
	
	if( isdefined( combatRobot.owner ) )
	{
		RadiusDamage( combatRobot.origin, 
					params.ksExplosionOuterRadius,
					params.ksExplosionInnerDamage,
					params.ksExplosionOuterDamage,
					combatRobot.owner, 
					"MOD_EXPLOSIVE",
					GetWeapon( COMBAT_ROBOT_MARKER_NAME ) );
		
		if( isdefined( params.ksExplosionRumble ) )
			combatRobot.owner PlayRumbleOnEntity( params.ksExplosionRumble );
	}
		
	wait( 0.2 );
	
	combatRobot notify( "combat_robot_shutdown" );
}

function WatchCombatRobotShutdown()
{
	combatRobot = self;
	combatRobotTeam = combatRobot.originalteam;
	combatRobotKillstreakId = combatRobot.killstreak_id;
	combatRobot waittill( "combat_robot_shutdown" );
	
	combatRobot playsound ("evt_combat_bot_mech_fail_explode");
	
	if( isdefined( combatRobot.useTrigger ) )
		combatRobot.useTrigger delete();
	
	if( isdefined( combatRobot.markerFXHandle ) )
		combatRobot.markerFXHandle delete();
	
	_DestroyGuardMarker( combatRobot );
	
	killstreakrules::killstreakStop( COMBAT_ROBOT_NAME, combatRobotTeam, combatRobotKillstreakId );
	
	if( isdefined( combatRobot ) )
	{
		if( Target_IsTarget( combatRobot ) )
			Target_Remove( combatRobot );
		if( !level.gameEnded ) // kill and do damage do nothing after game end
		{
			if( combatRobot flagsys::get( "in_vehicle" ) )
				combatRobot Unlink();
			combatRobot Kill();
		}
	}
}

function sndWatchCombatRobotVoxNotifies()
{
	combatRobot = self;
	combatRobot endon( "combat_robot_shutdown" );
	combatRobot endon( "death" );
	
	combatRobot PlaySoundOnTag( "vox_robot_chatter", "j_head" );
	
	while( 1 )
	{
		soundAlias = undefined;
		combatRobot waittill("bhtn_action_notify", notify_string);
		
		switch( notify_string )
		{
			case "charge":
			case "attack_melee":
			case "attack_kill":
			case "modeSwap":
				soundAlias = "vox_robot_chatter";
				break;
		}
		
		if( isdefined( soundAlias ) )
		{
			combatRobot PlaySoundOnTag( soundAlias, "j_head" );
			wait(1.2);
		}
	}
}
function sndWatchExit()
{
	combatRobot = self;
	combatRobot endon( "combat_robot_shutdown" );
	combatRobot endon( "death" );
	
	combatRobot waittill( "exiting_vehicle" );
	
	combatRobot playsound( "veh_vtol_supply_robot_launch" );
}
function sndWatchLanding()
{
	combatRobot = self;
	combatRobot endon( "combat_robot_shutdown" );
	combatRobot endon( "death" );
	
	combatRobot waittill( "falling", falltime );
	
	wait_time = falltime - .5;
	
	if ( wait_time > 0 )
		wait( wait_time );
	
	combatRobot playsound( "veh_vtol_supply_robot_land" );
}
function sndWatchActivate()
{
	combatRobot = self;
	combatRobot endon( "combat_robot_shutdown" );
	combatRobot endon( "death" );
	
	combatRobot waittill( "landing" );
	wait(.1);
	combatRobot playsound( "veh_vtol_supply_robot_activate" );
}

function combatRobotDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex, modelIndex )
{
	combatRobot = self;
	
	if( combatRobot flagsys::get( "in_vehicle" ) && ( sMeansOfDeath == "MOD_TRIGGER_HURT" ) ) // the dropship goes through hurt triggers sometimes
		iDamage = 0;
	else
		iDamage = killstreaks::OnDamagePerWeapon( COMBAT_ROBOT_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth*0.4, undefined, 0, undefined, true, 1.0 );
	
	combatRobot.missileTrackDamage += iDamage;
	
	if ( iDamage > 0 && isdefined( eAttacker ) )
	{
		if ( isPlayer( eAttacker) )
		{
			if ( isdefined( combatRobot.owner ) )
			{
				challenges::combat_robot_damage( eAttacker, combatRobot.Owner );
			}
		}
	}
	return iDamage;
}
