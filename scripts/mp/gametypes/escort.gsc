#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\math_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\archetype_robot;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\vehicleriders_shared;
#using scripts\shared\flagsys_shared;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_supplydrop;

#insert scripts\shared\ai\archetype_damage_effects.gsh;
#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\gametypes\ctf;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;

#using scripts\mp\teams\_teams;
#using scripts\mp\_util;

#define ESCORT_ROBOT		"escort_robot" 

/*
	Safeguard: Get robot to the enemy goal
	
	Level requirements
	------------------
		Spawnpoints:
		Attacker Start Spawnpoints:
			classname		mp_escort_spawn_attacker_start
			Attackers spawn from these at start of match.
		
		Attacker Respawn Spawnpoints:
			classname		mp_escort_spawn_attacker
			Attackers respawn from these. Place on the attacking side of the map.

		Defender Start Spawnpoints:
			classname		mp_escort_spawn_defender_start
			Defenders spawn from these at start of match.
		
		Defender Respawn Spawnpoints:
			classname		mp_escort_spawn_defender_start
			Defenders respawn from these. Place on the defending side of the map.

		Spectator Spawnpoints:
		
		Triggers:
			escort_robot_move_trig - The robot will spawn in the middle of this trigger and will move when friendly players are inside it
			escort_robot_goal_trig - The robot reaching the trigger ends the round
			
		Use Triggers:
			escort_robot_reboot_trig - Not used
			
		Pathnodes:
			escort_robot_path_start - This is the first node the robot will move to
*/


#define MOVE_CHATTER_MIN	1.5
#define MOVE_CHATTER_MAX	2.5
	
#define ROBOT_ANIM_RATE 1.1
#define PLAYER_REBOOT_BONUS 0	
#define RED_ZONE_NEAR_GOAL_DISTANCE_FROM_GOAL_RADIUS	50
	
#define GOAL_FX "ui/fx_dom_marker_team_r120"
#define ROBOT_EXPLODE_FX "weapon/fx_c4_exp_metal"
	
#define RIOTSHIELD_WEAPON				"riotshield"
#define RIOTSHIELD_MODEL				"wpn_t7_shield_riot_world_lh"
#define RIOTSHIELD_HELD_TAG				"tag_weapon_left"
#define RIOTSHIELD_STOWED_TAG			"tag_stowed_back"

#define ROBOT_STATE_IDLE 0
#define ROBOT_STATE_MOVING 1
#define ROBOT_STATE_SHUTDOWN 2

// Tweaks to how the combat robot's body is thrown after exploding
#define ROBOT_VELOCITY_SCALAR ( 1 / 8 )		// Scales the initial velocity
#define ROBOT_ADD_X_VELOCITY_MIN -20
#define ROBOT_ADD_X_VELOCITY_MAX 20
#define ROBOT_ADD_Y_VELOCITY_MIN -20
#define ROBOT_ADD_Y_VELOCITY_MAX 20
#define ROBOT_ADD_Z_VELOCITY_MIN 60
#define ROBOT_ADD_Z_VELOCITY_MAX 80

#define ROBOT_EXPLOSION_RADIUS_OUTER 200
#define ROBOT_EXPLOSION_RADIUS_INNER 1
#define ROBOT_EXPLOSION_DAMAGE_OUTER 1
#define ROBOT_EXPLOSION_DAMAGE_INNER 1
#define ROBOT_EXPLOSION_MAGNITUDE 1
	
#define ROBOT_PATH_TO_GOAL_TOO_LONG_MULTIPLIER 2.5
#define ROBOT_NAV_MESH_GOAL_REACHED_RADIUS 24
#define ROBOT_PATH_GOAL_REACHED_RADIUS	( ( ROBOT_NAV_MESH_GOAL_REACHED_RADIUS * 2 ) + 1 )
#define ROBOT_BLOCKED_KILL_RADIUS 108
#define ROBOT_POST_PATH_BLOCK_KILL_WAIT_TIME_MS 200

#define ROBOT_EXPLOSION_RUMBLE "grenade_rumble"
	
#precache( "string", "OBJECTIVES_ESCORT_ATTACKER" );
#precache( "string", "OBJECTIVES_ESCORT_DEFENDER" );
#precache( "string", "OBJECTIVES_ESCORT_ATTACKER_SCORE" );
#precache( "string", "OBJECTIVES_ESCORT_DEFENDER_SCORE" );
#precache( "string", "OBJECTIVES_ESCORT_ATTACKER_HINT" );
#precache( "string", "OBJECTIVES_ESCORT_DEFENDER_HINT" );

//#precache( "string", "MPUI_ESCORT_ROBOT_IDLE" );
#precache( "string", "MPUI_ESCORT_ROBOT_MOVING" );
//#precache( "string", "MPUI_ESCORT_ROBOT_REBOOTING" );

#precache( "string", "MP_ESCORT_OVERTIME_ROUND_1_ATTACKERS" );
#precache( "string", "MP_ESCORT_OVERTIME_ROUND_1_DEFENDERS" );
#precache( "string", "MP_ESCORT_OVERTIME_ROUND_2_ATTACKERS" );
#precache( "string", "MP_ESCORT_OVERTIME_ROUND_2_DEFENDERS" );
#precache( "string", "MP_ESCORT_OVERTIME_ROUND_2_TIE_ATTACKERS" );
#precache( "string", "MP_ESCORT_OVERTIME_ROUND_2_TIE_DEFENDERS" );

#precache( "string", "MP_ESCORT_ROBOT_DISABLED" );

#precache( "triggerstring", "PLATFORM_HOLD_TO_REBOOT_ROBOT" );
#precache( "string", "MP_REBOOTING_ROBOT" );	

#precache( "fx", GOAL_FX );
#precache( "fx", ROBOT_EXPLODE_FX );

#precache( "objective", "escort_goal" );
#precache( "objective", "escort_robot" );


REGISTER_SYSTEM( "escort", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "actor", "robot_state" , VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "escort_robot_burn" , VERSION_SHIP, 1, "int" );
	
	callback::on_spawned( &on_player_spawned );
}

function main()
{
	globallogic::init();
	
	util::registerTimeLimit( 0, 1440 );
	util::registerRoundScoreLimit( 0, 2000 );
	util::registerScoreLimit( 0, 5000 );	
	util::registerRoundLimit( 0, 12 );
	util::registerRoundSwitch( 0, 9 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerNumLives( 0, 100 );
	
	level.bootTime = GetGametypeSetting( "bootTime" );				// Initial time for the robot to boot when the game starts
	level.rebootTime = GetGametypeSetting( "rebootTime" );			// Time it takes for the robot to reboot
	level.rebootPlayers = GetGametypeSetting( "rebootPlayers" );	// 0 auto rebot, 1 players in radius, 2 players in radius with bonus
	level.movePlayers = GetGametypeSetting( "movePlayers" );		// 0 auto move, 1 players in radius
	
	level.robotShield = GetGametypeSetting( "robotShield" );		// 0 no riot shield, 1 riot shield
	
	switch( GetGametypeSetting( "shutdownDamage" ) )
	{
		case 1:	// Low
			level.escortRobotKillstreakBundle = "escort_robot_low";
			break;
		case 2:	// Normal
			level.escortRobotKillstreakBundle = "escort_robot";
			break;
		case 3:	// High
			level.escortRobotKillstreakBundle = "escort_robot_high";
		case 0: // Invulnerable
		default:
			level.shutdownDamage = 0;
	}
	
	if ( isdefined( level.escortRobotKillstreakBundle ) )
	{
		killstreak_bundles::register_killstreak_bundle( level.escortRobotKillstreakBundle );
		level.shutdownDamage = killstreak_bundles::get_max_health( level.escortRobotKillstreakBundle );
	}
	
	switch ( GetGametypeSetting( "robotSpeed" ) )
	{
		case 1:
			level.robotSpeed = "run";
			break;
		case 2:
			level.robotSpeed = "sprint";
			break;
		case 0:
		default:
			level.robotSpeed = "walk";
	}
	
	globallogic_audio::set_leader_gametype_dialog ( "startSafeguard", "hcStartSafeguard", "sfgStartAttack", "sfgStartDefend" );
	
	// Sets the scoreboard columns and determines with data is sent across the network
	if ( !SessionModeIsSystemlink() && !SessionModeIsOnlineGame() && IsSplitScreen() )
		// local matches only show the first three columns
		globallogic::setvisiblescoreboardcolumns( "score", "kills", "escorts", "disables", "deaths" );
	else
		globallogic::setvisiblescoreboardcolumns( "score", "kills", "deaths", "escorts", "disables" );
	
	level.teamBased = true;
	level.overrideTeamScore = true;
	level.scoreRoundWinBased = true;
	level.doubleOvertime = true;
	
	level.onStartGameType =&onStartGameType;
	
	level.onPlayerKilled =&onPlayerKilled;
	
	level.onTimeLimit =&onTimeLimit;
	level.onRoundSwitch =&onRoundSwitch;
	level.onEndGame =&onEndGame;
	level.shouldPlayOvertimeRound =&shouldPlayOvertimeRound;
	
	level.onRoundEndGame =&onRoundEndGame;
	
	gameobjects::register_allowed_gameobject( level.gameType );
	
	killstreak_bundles::register_killstreak_bundle( ESCORT_ROBOT );
}

function onStartGameType()
{
	level.useStartSpawns = true;

	if ( !isdefined( game["switchedsides"] ) )
	{
		game["switchedsides"] = false;
	}
	
	setClientNameMode("auto_change");
	
	if ( game["switchedsides"] )
	{
		oldAttackers = game["attackers"];
		oldDefenders = game["defenders"];
		game["attackers"] = oldDefenders;
		game["defenders"] = oldAttackers;
	}
	
	util::setObjectiveText( game["attackers"], &"OBJECTIVES_ESCORT_ATTACKER" );
	util::setObjectiveText( game["defenders"], &"OBJECTIVES_ESCORT_DEFENDER" );
	
	util::setObjectiveScoreText( game["attackers"], &"OBJECTIVES_ESCORT_ATTACKER_SCORE" );
	util::setObjectiveScoreText( game["defenders"], &"OBJECTIVES_ESCORT_DEFENDER_SCORE" );
	
	util::setObjectiveHintText( game["attackers"], &"OBJECTIVES_ESCORT_ATTACKER_HINT" );
	util::setObjectiveHintText( game["defenders"], &"OBJECTIVES_ESCORT_DEFENDER_HINT" );
	
	if ( isdefined( game["overtime_round"] ) )
	{
		[[level._setTeamScore]]( "allies", 0 );
		[[level._setTeamScore]]( "axis", 0 );
		
		if ( isdefined( game["escort_overtime_time_to_beat"] ) )
		{
			// Round down to the last second to prevent losses where the displayed resolutions of the time match
			timeS = game["escort_overtime_time_to_beat"] / 1000;
			timeM = Int( timeS ) / 60;
			util::registerTimeLimit( timeM, timeM );
		}
		
		if ( game["overtime_round"] == 1 )
		{
			level.onTimeLimit = &onTimeLimit_Overtime1;
			util::setObjectiveHintText( game["attackers"], &"MP_ESCORT_OVERTIME_ROUND_1_ATTACKERS" );
			util::setObjectiveHintText( game["defenders"], &"MP_ESCORT_OVERTIME_ROUND_1_DEFENDERS" );
		}
		else
		{
			level.onTimeLimit = &onTimeLimit_Overtime2;
			util::setObjectiveHintText( game["attackers"], &"MP_ESCORT_OVERTIME_ROUND_2_TIE_ATTACKERS" );
			util::setObjectiveHintText( game["defenders"], &"MP_ESCORT_OVERTIME_ROUND_2_TIE_DEFENDERS" );
		}
	}
	
	// Set up Spawn points
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	
	spawnlogic::place_spawn_points( "mp_escort_spawn_attacker_start" );
	spawnlogic::place_spawn_points( "mp_escort_spawn_defender_start" );
 
	level.spawn_start = [];
	level.spawn_start["allies"] = spawnlogic::get_spawnpoint_array( "mp_escort_spawn_attacker_start" );
	level.spawn_start["axis"] = spawnlogic::get_spawnpoint_array( "mp_escort_spawn_defender_start" );
	
	spawnlogic::add_spawn_points( "allies", "mp_escort_spawn_attacker" );
	spawnlogic::add_spawn_points( "axis", "mp_escort_spawn_defender" );
	
	spawning::updateAllSpawnPoints();
	
	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );

	spawnpoint = spawnlogic::get_random_intermission_point();
	setDemoIntermissionPoint( spawnpoint.origin, spawnpoint.angles );
	
	level thread drop_robot();
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( !isdefined( attacker ) || attacker == self || !IsPlayer( attacker ) || attacker.team == self.team )
	{
		return;
	}
	
	if ( self.team == game["defenders"] && IS_TRUE( attacker.escortingRobot ) )
	{
		attacker RecordGameEvent("attacking");
		scoreevents::processScoreEvent( "killed_defender", attacker );
	}
}
	
function onTimeLimit()
{
	winner = game["defenders"];
	globallogic_score::giveTeamScoreForObjective_DelayPostProcessing( winner, 1 );
	level thread globallogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

function onTimeLimit_Overtime1()
{
	winner = game["defenders"];
	level thread globallogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

function onTimeLimit_Overtime2()
{
	winner = game["defenders"];
	prevWinner = game["escort_overtime_first_winner"];
	
	if( winner == prevWinner )
	{
		level thread globallogic::endGame( winner, game["strings"]["time_limit_reached"] );
	}
	else
	{
		level thread globallogic::endGame( "tie", game["strings"]["time_limit_reached"] );
	}
}

function onRoundSwitch()
{
	game["switchedsides"] = !game["switchedsides"];
}

function onEndGame( winningTeam )
{
	if ( isdefined( game["overtime_round"] ) ) 
	{
		if ( game["overtime_round"] == 1 )
		{
			game["escort_overtime_first_winner"] = winningTeam;
			if( winningTeam == game["defenders"] )
			   game["escort_overtime_time_to_beat"] = undefined;
			else
				game["escort_overtime_time_to_beat"] = globallogic_utils::getTimePassed();
		}
		else
		{			
			game["escort_overtime_second_winner"] = winningTeam;
			if( isdefined( winningTeam ) && winningTeam != "tie" )
				game["escort_overtime_best_time"] = globallogic_utils::getTimePassed();
		}	
	}
	
	level.robot thread delete_on_endgame_sequence();
}

function shouldPlayOvertimeRound()
{
	if ( isdefined( game["overtime_round"] ) )
	{
		if ( game["overtime_round"] == 1 || !level.gameEnded ) // If we've only played 1 round or we're in the middle of the 2nd keep going
		{
			return true;
		}
		
		return false;
	}
	
	alliesRoundsWon = util::getRoundsWon( "allies" );
	axisRoundsWon = util::getRoundsWon( "axis" );
	
	if ( util::hitRoundLimit() && ( alliesRoundsWon == axisRoundsWon ) )
	{
		return true;
	}
	
	return false;
}

function onRoundEndGame( winningTeam )
{
	if ( isdefined( game["overtime_round"] ) )
	{
		foreach( team in level.teams )
		{
			score = game["roundswon"][team];
			[[level._setTeamScore]]( team, score );
		}			

		return winningTeam;
	}

	return globallogic::determineTeamWinnerByTeamScore();
}

// Callbacks
//========================================

function on_player_spawned()
{
	self.escortingRobot = undefined;
}

function drop_robot()
{
	globallogic::waitForPlayers();
	
	moveTrigger = GetEnt( "escort_robot_move_trig", "targetname" );
	pathArray = get_robot_path_array();
	startDir = pathArray[0] - moveTrigger.origin;
	startAngles = VectorToAngles( startDir );
	
	drop_origin = moveTrigger.origin;
	drop_height = VAL( level.escort_drop_height, supplydrop::getDropHeight( drop_origin ) );
	heli_drop_goal = ( drop_origin[0], drop_origin[1], drop_height );
	
	goalPath = undefined;
	
	dropOffset = ( 0, -120, 0 );
	
	goalPath = supplydrop::supplyDropHeliStartPath_v2_setup( heli_drop_goal, dropOffset );
	supplydrop::supplyDropHeliStartPath_v2_part2_local( heli_drop_goal, goalPath, dropOffset );

	drop_direction = VectorToAngles( ( heli_drop_goal[0], heli_drop_goal[1], 0 ) - ( goalPath.start[0], goalPath.start[1], 0 ) );
	
	chopper = spawnHelicopter( getplayers()[0], heli_drop_goal, ( 0, 0, 0 ), "combat_escort_robot_dropship", "" );
	
	chopper.maxhealth = 999999;
	chopper.health = 999999;	
	chopper.spawnTime = GetTime();
	supplydropSpeed = VAL( level.escort_drop_speed, GetDvarInt ( "scr_supplydropSpeedStarting" , 1000 )) ; // 250);
	supplydropAccel = VAL( level.escort_drop_accel, GetDvarInt ( "scr_supplydropAccelStarting" , 1000 )); //175);
	chopper SetSpeed( supplydropSpeed, supplydropAccel );	
	maxPitch = GetDvarInt( "scr_supplydropMaxPitch", 25);
	maxRoll = GetDvarInt( "scr_supplydropMaxRoll", 45 ); // 85);
	chopper SetMaxPitchRoll( 0, maxRoll );	
	
	spawnPosition = ( 0,0,0 );
	spawnAngles = ( 0,0,0 );
		
	level.robot = spawn_robot( spawnPosition, spawnAngles );
	level.robot.onground = undefined;
	level.robot.team = game["attackers"];
	level.robot SetForceNoCull();	
	level.robot vehicle::get_in( chopper , "driver", true );	
	level.robot.DropUnderVehicleOriginOverride = true;

	level.robot.targetAngles = startAngles;
	
	chopper vehicle::unload( "all" );
	level.robot playsound ("evt_safeguard_robot_land");
	
	chopper thread drop_heli_leave();
	
	while( level.robot flagsys::get( "in_vehicle" ) )  
	{
		wait 1;
	}	
	
	level.robot.pathArray = pathArray;
	level.robot.pathIndex = 0;
	level.robot.victimSoundMod = "safeguard_robot";
	level.robot.goalJustBlocked = false;
	
	level.robot thread update_stop_position();
	level.robot thread watch_robot_damaged();
	level.robot thread wait_robot_moving();
	level.robot thread wait_robot_stopped();

	level.robot.spawn_influencer_friendly = level.robot spawning::create_entity_friendly_influencer( "escort_robot_attackers", game["attackers"] );
	
/#
	debug_draw_robot_path();
	level thread debug_reset_robot_to_start();
#/

	// Triggers
	level.moveObject = setup_move_object( level.robot, "escort_robot_move_trig" );
	level.goalObject = setup_goal_object( level.robot, "escort_robot_goal_trig" );
	
	// Deprecated, just deletes the trigger
	setup_reboot_object( level.robot, "escort_robot_reboot_trig" );
	
	// Start the robot shutdown
	if ( level.bootTime )
	{
		level.robot clientfield::set( "robot_state", ROBOT_STATE_SHUTDOWN );
		level.moveObject gameobjects::set_flags( ROBOT_STATE_SHUTDOWN );
		
		Blackboard::SetBlackBoardAttribute( level.robot, STANCE, STANCE_CROUCH );
		level.robot ai::set_behavior_attribute( "rogue_control_speed", level.robotSpeed );  // Reset blackboard value after AnimScripted
		level.robot shutdown_robot();
	}
	else
	{
		Objective_SetProgress( level.moveObject.objectiveID, 1 );
		level.moveObject gameobjects::allow_use( "friendly" );
	}
	
	level.robot thread wait_robot_shutdown();
	level.robot thread wait_robot_reboot();
	
	while ( level.inPrematchPeriod )
	{
		WAIT_SERVER_FRAME;
	}
	
	level.robot.onground = 1;
	
	// Start the robot boot or move once prematch is over
	if ( level.bootTime )
	{
		level.robot thread auto_reboot_robot( level.bootTime );
	}
	else if ( level.movePlayers == 0 )
	{
		level.robot move_robot();
	}	
}

function drop_heli_leave()
{
	chopper = self;
	
	wait ( 1 );
	
	supplydropSpeed = GetDvarInt( "scr_supplydropSpeedLeaving", 250 ); 
	supplydropAccel = GetDvarInt( "scr_supplydropAccelLeaving", 60 );
	
	chopper setspeed( supplydropSpeed, supplydropAccel );	
	goalPath = supplydrop::supplyDropHeliEndPath_v2( chopper.origin );
	chopper airsupport::followPath( goalPath.path, undefined, false );
	
	chopper Delete();
}

// Safeguard Robot
//========================================

function start_robot_escort()
{
	globallogic::waitForPlayers();

	// Robot
	moveTrigger = GetEnt( "escort_robot_move_trig", "targetname" );
	
	pathArray = get_robot_path_array();
	startDir = pathArray[0] - moveTrigger.origin;
	startAngles = VectorToAngles( startDir );
/#
	calc_robot_path_length( moveTrigger.origin, pathArray );
#/
	//level.robot = spawn_robot( moveTrigger.origin, ( 0, startAngles[1], 0 ) );
	spawnPosition = ( 0,0,0 );
	spawnAngles = ( 0,0,0 );
		
	level.robot = spawn_robot( spawnPosition, spawnAngles );
	level.robot.team = game["attackers"];
	level.robot.pathArray = pathArray;
	level.robot.pathIndex = 0;
	level.robot.goalJustBlocked = false;
	level.robot.victimSoundMod = "safeguard_robot";
	level.robot SetForceNoCull();
	
	level.robot thread update_stop_position();
	level.robot thread watch_robot_damaged();
	level.robot thread wait_robot_moving();
	level.robot thread wait_robot_stopped();

	level.robot.spawn_influencer_friendly = level.robot spawning::create_entity_friendly_influencer( "escort_robot_attackers", game["attackers"] );
	
/#
	debug_draw_robot_path();
	level thread debug_reset_robot_to_start();
#/
	
	// Triggers
	level.moveObject = setup_move_object( level.robot, "escort_robot_move_trig" );
	level.goalObject = setup_goal_object( level.robot, "escort_robot_goal_trig" );
	
	// Deprecated, just deletes the trigger
	setup_reboot_object( level.robot, "escort_robot_reboot_trig" );
	
	// Start the robot shutdown
	if ( level.bootTime )
	{
		level.robot clientfield::set( "robot_state", ROBOT_STATE_SHUTDOWN );
		level.moveObject gameobjects::set_flags( ROBOT_STATE_SHUTDOWN );
		
		level.robot shutdown_robot();
	}
	else
	{
		Objective_SetProgress( level.moveObject.objectiveID, 1 );
		level.moveObject gameobjects::allow_use( "friendly" );
	}
	
	level.robot thread wait_robot_shutdown();
	level.robot thread wait_robot_reboot();
	
	while ( level.inPrematchPeriod )
	{
		WAIT_SERVER_FRAME;
	}
	
	// Start the robot boot or move once prematch is over
	if ( level.bootTime )
	{
		level.robot thread auto_reboot_robot( level.bootTime );
	}
	else if ( level.movePlayers == 0 )
	{
		level.robot move_robot();
	}
}

/#
	
function debug_draw_robot_path()
{
	// early out if we do not need to debug robot path
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;
	
	// now debug robot path
	debug_duration = 999999999;
	pathNodes = level.robot.pathArray;
	for( i = 0; i < pathNodes.size - 1; i++ )
	{
		currNode = pathNodes[ i ];
		nextNode = pathNodes[ i + 1 ];
		
		util::debug_line( currNode, nextNode, ( 0, 0.9, 0 ), 0.9, 0, debug_duration );
	}
	
	foreach( path in pathNodes )
	{
		util::debug_sphere( path, 6, ( 0, 0, 0.9 ), 0.9, debug_duration );
	}
}

function debug_draw_approximate_robot_path_to_goal( &goalPathArray )
{
	// early out if we do not need to debug robot path
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;
	
	// now debug robot path
	debug_duration = 60;
	pathNodes = goalPathArray;
	for( i = 0; i < pathNodes.size - 1; i++ )
	{
		currNode = pathNodes[ i ];
		nextNode = pathNodes[ i + 1 ];
		
		util::debug_line( currNode, nextNode, ( 0.9, 0.9, 0 ), 0.9, 0, debug_duration );
	}
	
	foreach( path in pathNodes )
	{
		util::debug_sphere( path, 3, ( 0, 0.5, 0.5 ), 0.9, debug_duration );
	}
}

function debug_draw_current_robot_goal( goal )
{
	// early out if we do not need to debug robot path
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;

	if ( isdefined( goal ) )
	{
		debug_duration = 60;
		util::debug_sphere( goal, 8, ( 0, 0.9, 0 ), 0.9, debug_duration );
	}
}

function debug_draw_find_immediate_goal( pathGoal )
{
	// early out if we do not need to debug robot path
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;
	
	if ( isdefined( pathGoal ) )
	{
		debug_duration = 60;
		util::debug_sphere( pathGoal + ( 0, 0, 18 ), 6, ( 0.9, 0, 0 ), 0.9, debug_duration );
	}
}

function debug_draw_find_immediate_goal_override( immediateGoal )
{
	// early out if we do not need to debug robot path
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;
	
	if ( isdefined( immediateGoal ) )
	{
		debug_duration = 60;
		util::debug_sphere( immediateGoal + ( 0, 0, 18 ), 6, ( 0.9, 0, 0.9 ), 0.9, debug_duration );
	}
}

function debug_draw_blocked_path_kill_radius( center, radius )
{
	if ( VAL( GetDvarInt( "scr_escort_debug_robot_path" ), 0 ) == 0 )
		return;
	
	if ( isdefined( center ) )
	{
		debug_duration = ROBOT_POST_PATH_BLOCK_KILL_WAIT_TIME_MS;
		circle( center + ( 0, 0, 2 ), radius, ( 0.9, 0, 0.0 ), true, true, debug_duration );
		circle( center + ( 0, 0, 4 ), radius, ( 0.9, 0, 0.0 ), true, true, debug_duration );
	}
}

#/
	
function wait_robot_moving()
{
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill( "robot_moving" );
		
		
		self clientfield::set( "robot_state", ROBOT_STATE_MOVING );
		level.moveObject gameobjects::set_flags( ROBOT_STATE_MOVING );
	}
}
		
function wait_robot_stopped()
{
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill( "robot_stopped" );
		
		if ( self.active )
		{
			self clientfield::set( "robot_state", ROBOT_STATE_IDLE );
			level.moveObject gameobjects::set_flags( ROBOT_STATE_IDLE );
		}
	}
}
	
function wait_robot_shutdown()
{
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill( "robot_shutdown" );
		
		level.moveObject gameobjects::allow_use( "none" );
		
		Objective_SetProgress( level.moveObject.objectiveID, -0.05 );
		
		self clientfield::set( "robot_state", ROBOT_STATE_SHUTDOWN );
		level.moveObject gameobjects::set_flags( ROBOT_STATE_SHUTDOWN );
	
		otherTeam = util::getOtherTeam( self.team );
		
		globallogic_audio::leader_dialog( "sfgRobotDisabledAttacker", self.team, undefined, "robot" );
		globallogic_audio::leader_dialog( "sfgRobotDisabledDefender", otherTeam, undefined, "robot" );
		
		globallogic_audio::play_2d_on_team( "mpl_safeguard_disabled_sting_friend", self.team );
		globallogic_audio::play_2d_on_team( "mpl_safeguard_disabled_sting_enemy", otherTeam );
		
		self thread auto_reboot_robot( level.rebootTime );
	}
}

function wait_robot_reboot()
{
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill( "robot_reboot" );
		
			
		level.moveObject gameobjects::allow_use( "friendly" );
		
		otherTeam = util::getOtherTeam( self.team );
		
		globallogic_audio::leader_dialog( "sfgRobotRebootedAttacker", self.team, undefined, "robot" );
		globallogic_audio::leader_dialog( "sfgRobotRebootedDefender", otherTeam, undefined, "robot" );
		
		globallogic_audio::play_2d_on_team( "mpl_safeguard_reboot_sting_friend", self.team );
		globallogic_audio::play_2d_on_team( "mpl_safeguard_reboot_sting_enemy", otherTeam );
				
		Objective_SetProgress( level.moveObject.objectiveID, 1 );
		
		if ( level.movePlayers == 0 )
		{
			self move_robot();
		}
		else if ( level.moveObject.numTouching[level.moveObject.ownerTeam] == 0 )
		{
			self clientfield::set( "robot_state", ROBOT_STATE_IDLE );
			level.moveObject gameobjects::set_flags( ROBOT_STATE_IDLE );
		}
	}
}

function auto_reboot_robot( time )
{
	self endon( "robot_reboot" );
	self endon( "game_ended" );
	
	shutdownTime = 0;
	
	while( shutdownTime < time )
	{
		rate = 0;
		friendlyCount = level.moveObject.numTouching[level.moveObject.ownerTeam];
		
		if ( !level.rebootPlayers )
		{
			rate = SERVER_FRAME;
		}
		else if ( friendlyCount > 0 )
		{
			rate = SERVER_FRAME;	// Base rate for interactive reboot
			
			if ( friendlyCount > 1 )	// Add in multiple player bonus if any
			{
				bonusRate = ( friendlyCount - 1 ) * SERVER_FRAME * PLAYER_REBOOT_BONUS;

				rate += bonusRate;
			}
		}
		
		if ( rate > 0 )
		{
			shutdownTime += rate;
			percent = Min( 1, shutdownTime / time );
			Objective_SetProgress( level.moveObject.objectiveID, percent );
		}
		
		WAIT_SERVER_FRAME;
	}
	
	if ( level.rebootPlayers > 0 )
	{
		foreach( struct in level.moveObject.touchList[game["attackers"]] )
		{
			scoreevents::processScoreEvent( "escort_robot_reboot", struct.player );
		}
	}
	
	self thread reboot_robot();
}

function watch_robot_damaged()
{
	level endon( "game_ended" );
	
	while (1)
	{
		self waittill( "robot_damaged" );
		
		percent = Min( 1, ( self.shutdownDamage / level.shutdownDamage ) );
		Objective_SetProgress( level.moveObject.objectiveID, 1 - percent );
		
		health = level.shutdownDamage - self.shutdownDamage;
		
		lowHealth = killstreak_bundles::get_low_health( level.escortRobotKillstreakBundle );
		
		if ( !IS_TRUE( self.playedDamage ) && health <= lowHealth )
		{
			globallogic_audio::leader_dialog( "sfgRobotUnderFire", self.team, undefined, "robot" );
			self.playedDamage = true;
		}
		else if ( health > lowHealth )
		{
			self.playedDamage = false;
		}
	}
}

function delete_on_endgame_sequence()
{
	self endon( "death" );
	level waittill( "endgame_sequence" );
	
	self Delete();
}

function get_robot_path_array()
{	
	if ( isdefined( level.escortRobotPath ) )
	{
/#		
		PrintLn( "Using script level.escortRobotPath" );
#/		
		return level.escortRobotPath;
	}

/#
	PrintLn( "Using bsp pathnodes" );
#/	
	pathArray = [];
	
	currNode = GetNode( "escort_robot_path_start", "targetname" );
	pathArray[pathArray.size] = currNode.origin;
	
	while( isdefined( currNode.target ) )
	{
		currNode = GetNode( currNode.target, "targetname" );
		
		pathArray[pathArray.size] = currNode.origin;
	}

	if ( isdefined( level.update_escort_robot_path ) )
	{
		[[ level.update_escort_robot_path ]] ( pathArray );
	}
	
	return pathArray;
}

/#
function calc_robot_path_length( robotOrigin, pathArray )
{
	distance = 0;
	
	lastPoint = robotOrigin;
	
	for( i = 0; i < pathArray.size; i++ )
	{
		distance += Distance( lastPoint, pathArray[i] );
		lastPoint = pathArray[i];
	}
	
	PrintLn( "Escort Path Length: " + distance );
}
#/


// Robot
//========================================

function spawn_robot( position, angles )
{
	robot = SpawnActor( "spawner_bo3_robot_grunt_assault_mp_escort",
	                   	position,
						angles,
						"",
						true );	
	
	robot ai::set_behavior_attribute( "rogue_allow_pregib", false );
	robot ai::set_behavior_attribute( "rogue_allow_predestruct", false );
	
	robot ai::set_behavior_attribute( "rogue_control", "forced_level_2" ); // Lights
	robot ai::set_behavior_attribute( "rogue_control_speed", level.robotSpeed );
	
	robot ai::set_ignoreall( true );
	robot.allowdeath = false;
	
	robot ai::set_behavior_attribute( "can_become_crawler", false );
	robot ai::set_behavior_attribute( "can_be_meleed", false );
	robot ai::set_behavior_attribute( "can_initiateaivsaimelee", false );
	robot ai::set_behavior_attribute( "traversals", "procedural" );
	
	AiUtility::ClearAIOverrideDamageCallbacks( robot );
	
	robot.active = true;
	robot.moving = false;
	robot.shutdownDamage = 0;
	robot.properName = "";
	robot.ignoreTriggerDamage = true;
	
	robot clientfield::set( ROBOT_MIND_CONTROL_CLIENTFIELD, ROBOT_MIND_CONTROL_LEVEL_0 );
	robot ai::set_behavior_attribute( "robot_lights", ROBOT_LIGHTS_HACKED );
	
	robot.pushable = false;
	robot PushActors( true );
	robot PushPlayer( true );
	robot SetAvoidanceMask( "avoid none" );
	robot DisableAimAssist();
	
	robot SetSteeringMode( "slow steering" );
	Blackboard::SetBlackBoardAttribute( robot, ROBOT_LOCOMOTION_TYPE, "alt1" );
	
	if ( level.robotShield )
	{
		aiutility::attachRiotshield( robot, GetWeapon( RIOTSHIELD_WEAPON ), RIOTSHIELD_MODEL, RIOTSHIELD_STOWED_TAG );
	}
	
	robot ASMSetAnimationRate( ROBOT_ANIM_RATE );
	
	if ( IS_TRUE( level.shutdownDamage ) )
	{
		Target_Set( robot, ( 0, 0, 50 ) );
	}
	
	robot.overrideActorDamage = &robot_damage;

	robot thread robot_move_chatter();
	
	robot.missileTargetMissDistance = 64;
	robot thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile();
	
	return robot;
}

function robot_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex, modelIndex )
{	
	if( !IS_TRUE( self.onground ) )
		return 0;
	
	if ( level.shutdownDamage <= 0 ||
	     !self.active ||
	     eAttacker.team == game["attackers"] )
	{
		return 0;
	}

	level.useStartSpawns = false;

	weapon_damage = killstreak_bundles::get_weapon_damage( level.escortRobotKillstreakBundle, level.shutdownDamage, eAttacker, weapon, sMeansOfDeath, iDamage, iDFlags, undefined );

	DEFAULT( weapon_damage, iDamage );
	
	if ( !weapon_damage )
	{
		return 0;
	}
	
	self.shutdownDamage += weapon_damage;

	self notify( "robot_damaged" );
	
	DEFAULT( eAttacker.damageRobot, 0 );
	
	eAttacker.damageRobot += weapon_damage;
	
	if ( self.shutdownDamage >= level.shutdownDamage )
	{
		origin = (0,0,0);
		
		if ( IsPlayer( eAttacker ) )
		{
			level thread popups::DisplayTeamMessageToAll( &"MP_ESCORT_ROBOT_DISABLED", eAttacker );
			
			
			if ( Distance2DSquared( self.origin, level.goalObject.trigger.origin ) < SQR( level.goalObject.trigger.radius + RED_ZONE_NEAR_GOAL_DISTANCE_FROM_GOAL_RADIUS ) )
			{
				scoreevents::processScoreEvent( "escort_robot_disable_near_goal", eAttacker );
			}
			else
			{
				scoreevents::processScoreEvent( "escort_robot_disable", eAttacker );
			}
			
			if( isdefined( eAttacker.pers["disables"]) )
			{
				eAttacker.pers["disables"]++;
				eAttacker.disables = eAttacker.pers["disables"];
			}
			
			eAttacker AddPlayerStatWithGameType( "DISABLES", 1 );
			origin = eAttacker.origin;
		}
		
		foreach( player in level.players )
		{
			if ( player == eAttacker ||
			     player.team == self.team ||
			     !isdefined( player.damageRobot ) )
			{
				continue;
			}
			
			damagePercent = player.damageRobot / level.shutdownDamage;
				
			if ( damagePercent >= 0.5 )
			{
				scoreevents::processScoreEvent( "escort_robot_disable_assist_50", player );
			}
			else if ( damagePercent >= 0.25 )
			{
				scoreevents::processScoreEvent( "escort_robot_disable_assist_25", player );
			}
			
			player.damageRobot = undefined;
		}
		
		self shutdown_robot();
	}

	self.health += 1;
	return 1;
}

function robot_damage_none( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex, modelIndex )
{
	return 0;
}

function shutdown_robot()
{
	self.active = false;
	self ai::set_ignoreme( true );
	
	self stop_robot();
	
	self notify( "robot_shutdown" );	
	
	if ( Target_IsTarget( self ) )
	{
		Target_Remove( self );
	}
	
	if ( isdefined( self.riotshield ) )
	{
		self AsmChangeAnimMappingTable( 1 );
		self Detach( self.riotshield.model, self.riotshield.tag );
		aiutility::attachRiotshield( self, GetWeapon( RIOTSHIELD_WEAPON ), RIOTSHIELD_MODEL, RIOTSHIELD_HELD_TAG );
	}
	
	self ai::set_behavior_attribute( "shutdown", true );
}

function reboot_robot()
{
	self.active = true;
	self.shutdownDamage = 0;
	self ai::set_ignoreme( false );

	self notify( "robot_reboot" );
	
	if ( IS_TRUE( level.shutdownDamage ) )
	{
		Target_Set( self, ( 0, 0, 50 ) );
	}
	
	if ( isdefined( self.riotshield ) )
	{
		self AsmChangeAnimMappingTable( 0 );
		
		self Detach( self.riotshield.model, self.riotshield.tag );
		aiutility::attachRiotshield( self, GetWeapon( RIOTSHIELD_WEAPON ), RIOTSHIELD_MODEL, RIOTSHIELD_STOWED_TAG );
	}
	
	self ai::set_behavior_attribute( "shutdown", false );
}

function move_robot()
{
	if ( self.active == false ||
	     self.moving ||
	     !isdefined( self.pathIndex ) )
	{
		return;
	}
	
	if ( self check_blocked_goal_and_kill() )
		return;
	
	if ( GetTime() < VAL( self.blocked_wait_end_time, 0 ) )
		return;

	self notify ( "robot_moving" );
	
	self.moving = true;
	self set_goal_to_point_on_path();
	
	self thread robot_wait_next_point();
}

function get_current_goal()
{
	return ( isdefined( self.immediateGoalOverride ) ? self.immediateGoalOverride : self.pathArray[ self.pathIndex ] );
}

function reached_closest_nav_mesh_goal_but_still_too_far_and_blocked( goalOnNavMesh )
{
	if ( isdefined( self.immediateGoalOverride ) )
		return false;

	distSqr = DistanceSquared( goalOnNavMesh, self.origin );
	robotReachedClosestGoalOnNavMesh = ( distSqr <= SQR( ROBOT_NAV_MESH_GOAL_REACHED_RADIUS ) );
	if ( robotReachedClosestGoalOnNavMesh )
	{
		closestGoalOnNavMeshTooFarFromPathGoal = ( DistanceSquared( goalOnNavMesh, self.pathArray[ self.pathIndex ] ) > SQR( 1.0 ) );
		if ( closestGoalOnNavMeshTooFarFromPathGoal )
		{		
			robotIsBlockedFromGettingToPathGoal = self check_if_goal_is_blocked( self.origin, self.pathArray[ self.pathIndex ] );
			if ( robotIsBlockedFromGettingToPathGoal )
		    	return true;
		}
	}

	return false;
}

function check_blocked_goal_and_kill()
{
	// wait until we kill again
	if ( GetTime() < VAL( self.blocked_wait_end_time, 0 ) )
	{
		wait ( ( self.blocked_wait_end_time - GetTime() ) / 1000 );
	}

	goalOnNavMesh = self get_closest_point_on_nav_mesh_for_current_goal();
	previousGoal = ( ( self.pathIndex > 0 && !isdefined( self.immediateGoalOverride ) ) ? self.pathArray[ self.pathIndex - 1 ] : self.origin );

	if ( self.goalJustBlocked || self reached_closest_nav_mesh_goal_but_still_too_far_and_blocked( goalOnNavMesh ) || self check_if_goal_is_blocked( previousGoal, goalOnNavMesh ) )
	{
		// we are blocked now, try to kill something to get unblocked

		self.goalJustBlocked = false;
		stillBlocked = true;
		
		killedSomething = self kill_anything_blocking_goal( goalOnNavMesh );

		if ( killedSomething )
		{
			stillBlocked = self check_if_goal_is_blocked( previousGoal, goalOnNavMesh );
			if ( stillBlocked )
			{
				self.blocked_wait_end_time = GetTime() + ROBOT_POST_PATH_BLOCK_KILL_WAIT_TIME_MS;
				self stop_robot();
			}
		}
		else
		{
			self find_immediate_goal();
		}

		return stillBlocked;
	}
	
	return false;
}

function find_immediate_goal()
{
	// cannot get to goal and cannot kill anything, try to find nearby immediate goal along the line-of-sight path
	// this does assume that the path from one node to the other has all points on navmesh. (No corners or walls are in the way.)
	
	pathGoal = self.pathArray[ self.pathIndex ];
	currPos = self.origin;
	
	/# debug_draw_find_immediate_goal( pathGoal ); #/

	immediateGoal = get_closest_point_on_nav_mesh( VectorLerp( currPos, pathGoal, 0.5 ) ); // get closest point
	while( self check_if_goal_is_blocked( currPos, immediateGoal ) )
	{
		immediateGoal = get_closest_point_on_nav_mesh( VectorLerp( currPos, immediateGoal, 0.5 ) );
	}

	self.immediateGoalOverride = immediateGoal;
	
	/# debug_draw_find_immediate_goal_override( self.immediateGoalOverride ); #/
}

function check_if_goal_is_blocked( previousGoal, goal )
{
	// check path distance; note: a zero-length array does not mean there isn't a path, using robot origin to detect that
	approxPathArray = self CalcApproximatePathToPosition( goal );
	distanceToNextGoal = min( Distance( self.origin, goal ), Distance( previousGoal, Goal ) );
	approxPathTooLong = is_path_distance_to_goal_too_long( approxPathArray, distanceToNextGoal * ROBOT_PATH_TO_GOAL_TOO_LONG_MULTIPLIER );
	
	return approxPathTooLong;
}

function watch_goal_becoming_blocked( goal )
{
	self notify( "end_watch_goal_becoming_blocked_singleton" );
	self endon( "end_watch_goal_becoming_blocked_singleton" );

	self endon( "robot_stopped" );
	self endon( "goal" );
	level endon( "game_ended" );

	distToGoalSqr = 999999999.0;

	while ( 1 )
	{
		wait 0.1;

		// don't check distances when taking traversals
		if ( isdefined( self.traverseStartNode ) )
		{
			self waittill( "traverse_end" );
			continue;
		}

		newDistToGoalSqr = DistanceSquared( self.origin, goal );
		if ( newDistToGoalSqr < distToGoalSqr )
		{
			distToGoalSqr = newDistToGoalSqr;
		}
		else
		{
			self.goalJustBlocked = true;
			self notify( "goal_blocked" );
			// self stop_robot();
		}
	}
}

function watch_becoming_blocked_at_goal()
{
	self notify( "end_watch_becoming_blocked_at_goal" );
	self endon( "end_watch_becoming_blocked_at_goal" );

	self endon( "robot_stop" );
	//self endon( "goal" ); // IMPORTANT: never setup an endon( "goal" for this function. This is why it was created in the first place.
	level endon( "game_ended" );

	// don't check distances when taking traversals
	while ( isdefined( self.traverseStartNode ) )
	{
		self waittill( "traverse_end" );
	}
	
	self.watch_becoming_blocked_at_goal_established = true;
	
	startPos = self.origin;
	atSamePosCount = 0;
	iterationCount = 0;
		
	while ( self.moving )
	{
		wait 0.1;

		if ( DistanceSquared( startPos, self.origin ) < 1.0 )
		{
			atSamePosCount++;
		}

		if ( atSamePosCount >= 2 )
		{
			self.goalJustBlocked = true;
			self notify( "goal_blocked" );
		}
		
		iterationCount++;
		
		if ( iterationCount >= 3 )
			break;
	}
	
	self.watch_becoming_blocked_at_goal_established = false;
}

function stop_robot()
{
	if ( !self.moving )
	{
		return;
	}
	
	if ( isdefined( self.traverseStartNode ) )
	{
		self thread check_robot_on_travesal_end();
		return;
	}
	
	self.moving = false;
	self.mostRecentClosestPathPointGoal = undefined;
	self.watch_becoming_blocked_at_goal_established = false;
	self SetGoal( self.origin, false );
	
	self notify ( "robot_stopped" );
}

function check_robot_on_travesal_end()
{
	self notify( "check_robot_on_travesal_end_singleton" );
	self endon( "check_robot_on_travesal_end_singleton" );
	self endon( "death" );

	self waittill( "traverse_end" );
	
	numOwners = VAL( level.moveObject.numTouching[ level.moveObject.ownerTeam ], 0 );
	if ( numOwners < level.movePlayers )
	{
		self stop_robot();
	}
	else
	{
		self move_robot();
	}
}
	
function update_stop_position()
{
	self endon( "death" );
	level endon( "game_ended" );

	while ( true )
	{
		self waittill( "traverse_end" );
		
		// Make the robot update it's goal position after taking a traversal.
		// Prevents oscillating across a traversal edge.
		if ( !self.moving )
		{
			self SetGoal( self.origin, true );
		}
	}
}
	
function robot_wait_next_point()
{
	self endon( "robot_stopped" );
	self endon( "death" );
	level endon( "game_ended" );
	
	while( 1 )
	{
		self util::waittill_any( "goal", "goal_blocked" );
		
		if ( !isdefined( self.watch_becoming_blocked_at_goal_established ) || self.watch_becoming_blocked_at_goal_established == false )
		{
			self thread watch_becoming_blocked_at_goal();
		}
		
		if ( DistanceSquared( self.origin, get_current_goal() ) < SQR( ROBOT_NAV_MESH_GOAL_REACHED_RADIUS ) )
		{
			self.pathIndex += ( isdefined( self.immediateGoalOverride ) ? 0 : 1 ); // only increment when not pathing to immediate goal override
			self.immediateGoalOverride = undefined;
		}
		
		while ( ( self.pathIndex < self.pathArray.size ) && DistanceSquared( self.origin, self.pathArray[ self.pathIndex ] ) < SQR( ROBOT_PATH_GOAL_REACHED_RADIUS ) )
		{
			self.pathIndex++;
		}

		if ( self.pathIndex >= self.pathArray.size )
		{
			self.pathIndex = undefined;
			self stop_robot();
			return;
		}
		
		if ( ( self.pathIndex + 1 ) >= self.pathArray.size )
	    {
			otherTeam = util::getOtherTeam( self.team );
	
			globallogic_audio::leader_dialog( "sfgRobotCloseAttacker", self.team, undefined, "robot" );
			globallogic_audio::leader_dialog( "sfgRobotCloseDefender", otherTeam, undefined, "robot" );
	    }

		if ( self check_blocked_goal_and_kill() )
		{
			self stop_robot();
		}

		set_goal_to_point_on_path();
	}
}

function get_closest_point_on_nav_mesh_for_current_goal()
{
 	immediateGoal = get_current_goal();
 
	closestPathPoint = GetClosestPointOnNavMesh( immediateGoal, 48, 15 );
	if ( !isdefined( closestPathPoint ) )
		closestPathPoint = GetClosestPointOnNavMesh( immediateGoal, 96, 15 );
	
	return VAL( closestPathPoint, immediateGoal );
}

function get_closest_point_on_nav_mesh( point )
{
	closestPathPoint = GetClosestPointOnNavMesh( point, 48, 15 );
	if ( !isdefined( closestPathPoint ) )
		closestPathPoint = GetClosestPointOnNavMesh( point, 96, 15 );
	
	// during large traversals, the intermediate points can be in mid air like the big window in Metro
	if ( !isdefined( closestPathPoint ) )
	{
		iterCount = 0;
		lowerPoint = point - ( 0, 0, 36 );
		// keep trying lower points until we find one on the mesh
		while ( !isdefined( closestPathPoint ) && iterCount < 5 )
		{
			closestPathPoint = GetClosestPointOnNavMesh( lowerPoint, 48, 15 );
			lowerPoint = lowerPoint - ( 0, 0, 36 );
			iterCount++;			
		}
	}

	return VAL( closestPathPoint, point );
}

function set_goal_to_point_on_path( recursionCount = 0 )
{
 	self.goalJustBlocked = false;
 	
 	closestPathPoint = self get_closest_point_on_nav_mesh_for_current_goal();

	if ( isdefined( closestPathPoint ) )
	{
		if ( !isdefined( self.mostRecentClosestPathPointGoal ) || ( DistanceSquared( closestPathPoint, self.mostRecentClosestPathPointGoal ) > 1.0 ) )
		{
			self SetGoal( closestPathPoint, false, ROBOT_NAV_MESH_GOAL_REACHED_RADIUS ); // use nav mesh goal radius as it is smaller of the two
			self thread watch_goal_becoming_blocked( closestPathPoint );
			self.mostRecentClosestPathPointGoal = closestPathPoint;
		}
	}
	else if ( recursionCount < 3 )
	{
		self find_immediate_goal();
		self set_goal_to_point_on_path( recursionCount + 1 );
	}
	else
	{
		// this should never happen
		self stop_robot();
	}

/#
	debug_draw_current_robot_goal( closestPathPoint );
#/
}

function is_path_distance_to_goal_too_long( &pathArray, tooLongThreshold )
{
	
/#
	debug_draw_approximate_robot_path_to_goal( pathArray );
#/
	
	if ( tooLongThreshold < 20.0 )
		tooLongThreshold = 20.0;

	goalDistance = 0;

	lastIndexToCheck = pathArray.size - 1;
	for( i = 0; i < lastIndexToCheck; i++ )
	{
		goalDistance += Distance( pathArray[ i ], pathArray[ i + 1 ] );
		if (goalDistance >= tooLongThreshold )
			return true;
	}

	return false;
}

/#
function debug_reset_robot_to_start()
{
	level endon( "game_ended" );

	while( 1 )
	{
		if ( VAL( GetDvarInt( "scr_escort_robot_reset_path" ), 0 ) > 0 )
		{
			if( isdefined( level.robot ) )
			{
				pathIndex = VAL( GetDvarInt( "scr_escort_robot_reset_path" ), 0 ) - 1;
				pathPoint = level.robot.pathArray[ pathIndex ];
				robotAngles = ( 0, 0, 0 );
				if ( pathIndex < level.robot.pathArray.size - 1 )
				{
					nextPoint = level.robot.pathArray[ pathIndex + 1 ];
					robotAngles = VectorToAngles( nextPoint - pathPoint );
				}
				level.robot forceTeleport( pathPoint, robotAngles );
				level.robot.pathIndex = pathIndex;
				level.robot.immediateGoalOverride = undefined;
				
				while ( isdefined( self.traverseStartNode ) )
				{
					WAIT_SERVER_FRAME;
				}
					
				level.robot stop_robot();
				level.robot SetGoal( level.robot.origin, false ); // set goal to self again as stop_robot may not have
			}
			SetDvar( "scr_escort_robot_reset_path", 0 );
		}
		
		wait 0.5;
	}
}
#/

function explode_robot( )
{
	self clientfield::set( "escort_robot_burn", 1 );
	clientfield::set(
		ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD, ROBOT_MIND_CONTROL_EXPLOSION_ON );
	self thread wait_robot_corpse();
	
	if ( RandomInt( 100 ) >= 50 )
		GibServerUtils::GibLeftArm( self );
	else
		GibServerUtils::GibRightArm( self );
	
	GibServerUtils::GibLegs( self );
	GibServerUtils::GibHead( self );
	
	velocity = self GetVelocity() * ROBOT_VELOCITY_SCALAR;
	
	self StartRagdoll();
	self LaunchRagdoll(
		( velocity[0] + RandomFloatRange( ROBOT_ADD_X_VELOCITY_MIN, ROBOT_ADD_X_VELOCITY_MAX ),
		velocity[1] + RandomFloatRange( ROBOT_ADD_Y_VELOCITY_MIN, ROBOT_ADD_Y_VELOCITY_MAX ),
		RandomFloatRange( ROBOT_ADD_Z_VELOCITY_MIN, ROBOT_ADD_Z_VELOCITY_MAX ) ),
		"j_mainroot" );
	
	PlayFXOnTag( ROBOT_EXPLODE_FX, self, "tag_origin" );
	
	if ( Target_IsTarget( self ) )
	{
		Target_Remove( self );
	}
	
	PhysicsExplosionSphere( self.origin, 
   	              			ROBOT_EXPLOSION_RADIUS_OUTER,
							ROBOT_EXPLOSION_RADIUS_INNER,
	              			ROBOT_EXPLOSION_MAGNITUDE,
	              			ROBOT_EXPLOSION_DAMAGE_OUTER,
	              			ROBOT_EXPLOSION_DAMAGE_INNER );
	
	RadiusDamage( self.origin, 
	              ROBOT_EXPLOSION_RADIUS_OUTER,
	              ROBOT_EXPLOSION_DAMAGE_INNER,
	              ROBOT_EXPLOSION_DAMAGE_OUTER,
	              undefined, 
	              "MOD_EXPLOSIVE" );	
	
	PlayRumbleOnPosition( ROBOT_EXPLOSION_RUMBLE, self.origin );
}

function wait_robot_corpse()
{
	archetype = self.archetype;
 	self waittill("actor_corpse", corpse);
 	corpse clientfield::set( "escort_robot_burn", 1 );
}

function robot_move_chatter()
{
	level endon( "game_ended" );
	
	while(1)
	{
		if ( self.moving )
		{
			self PlaySoundOnTag( "vox_robot_chatter", "J_Head" );
		}
			
		wait( RandomFloatRange( MOVE_CHATTER_MIN, MOVE_CHATTER_MAX ) );
	}
}


// Robot Move Trigger
//========================================

function setup_move_object( robot, triggerName )
{
	trigger = GetEnt( triggerName, "targetname" );
	
	useObj = gameobjects::create_use_object( game["attackers"], trigger, [], ( 0, 0 ,0 ), &"escort_robot" );
	useObj gameobjects::set_objective_entity( robot );
	useObj gameobjects::allow_use( "none" );
	useObj gameobjects::set_visible_team( "any" );
	useObj gameobjects::set_use_time( 0 );
	
	trigger EnableLinkTo();
	trigger LinkTo( robot );

	useObj.onUse = &on_use_robot_move;
	useObj.onUpdateUseRate = &on_update_use_rate_robot_move;
	useObj.robot = robot;
	               	
	return useObj;
}

function on_use_robot_move( player )
{
	level.useStartSpawns = false;
	
	if ( !IS_TRUE( player.escortingRobot ) )
	{
		self thread track_escort_time( player );
	}
		
	if ( self.robot.moving ||
	     !self.robot.active  || 
	     self.numTouching[self.ownerTeam] < level.movePlayers )
	{
		return;
	}
	
	self.robot move_robot();
}

function on_update_use_rate_robot_move( team, progress, change )
{
	numOwners = self.numTouching[self.ownerTeam];
	
	if ( numOwners < level.movePlayers )
	{
		self.robot stop_robot();
	}
}

function WatchPlayerDeath()
{
	player = self;
	player endon( "escorting_stopped" );
	
	level endon( "game_ended" );
	
	player waittill( "death" );
	
}

function track_escort_time( player )
{
	player endon( "death" );
	level endon( "game_ended" );
	
	player.escortingRobot = true;
	
	player thread WatchPlayerDeath();
	
	consecutiveEscorts = 0;
	
	while( 1 )
	{
		wait 1;
		
		if( !self.robot.active )
		{
			continue;
		}
		
		touching = false;
		
		foreach( struct in self.touchList[self.team] )
		{
			if ( struct.player == player )
			{
				touching = true;
				break;
			}
		}
		
		if( touching )
		{
			if( isdefined( player.pers["escorts"] ) )
			{
				player.pers["escorts"]++;
				player.escorts = player.pers["escorts"];
				consecutiveEscorts++;
				if( ( consecutiveEscorts % 3 ) == 0 ) // award score every 3 secs
				{
					scoreevents::processScoreEvent( "escort_robot_escort", player );
				}
			}
			
			player AddPlayerStatWithGameType( "ESCORTS", 1 );
		}
		else
		{
			player.escortingRobot = false;
			player notify( "escorting_stopped" );
			return;
		}
	}
}

// Robot Reboot Trigger
//========================================

function setup_reboot_object( robot, triggerName )
{
	trigger = GetEnt( triggerName, "targetname" );
	
	if ( isdefined( trigger ) )
	{
		trigger Delete();
	}
}


// Goal
//========================================

function setup_goal_object( robot, triggerName )
{	
	trigger = GetEnt( triggername, "targetname" );
	
	useObj = gameobjects::create_use_object( game["defenders"], trigger, [], ( 0, 0 ,0 ), &"escort_goal" );
	useObj gameobjects::set_visible_team( "any" );
	useObj gameobjects::allow_use( "none" );
	useObj gameobjects::set_use_time( 0 );
	
	fwd = ( 0, 0, 1 );
	right = ( 0, -1, 0 );
	
	useObj.fx = SpawnFx( GOAL_FX, trigger.origin, fwd, right );
	useObj.fx.team = game["defenders"];
	TriggerFx( useObj.fx, 0.001 );
	
	useObj thread watch_robot_enter( robot );
	
	return useObj;
}

function watch_robot_enter( robot )
{
	robot endon( "death" );
	level endon( "game_ended" );
	
	radiusSq = self.trigger.radius * self.trigger.radius;
	
	while(1)
	{
		if ( robot.moving === true &&
		     Distance2DSquared( self.trigger.origin, robot.origin ) < radiusSq )
		{
			level.movePlayers = 0;	// Keep moving
			robot.overrideActorDamage = &robot_damage_none;	// Don't actually take damage
			
			if ( Target_IsTarget( self ) )
			{
				Target_Remove( self );
			}
			
			attackers = game["attackers"];
			self.fx.team = attackers;
			
			foreach( player in level.alivePlayers[attackers] )
			{
				if ( IS_TRUE( player.escortingRobot ) )
				{
					scoreevents::processScoreEvent( "escort_robot_escort_goal", player );
				}
			}
			
			setGameEndTime( 0 );
			
			robot ai::set_ignoreme( true );
	
			robot thread explode_robot_after_wait( 1.0 );
			
			globallogic_score::giveTeamScoreForObjective( attackers, 1 );
			level thread globallogic::endGame( attackers, game["strings"][attackers + "_mission_accomplished"] );

			return;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function explode_robot_after_wait( wait_time )
{
	robot = self;

	wait wait_time;

	if ( isdefined( robot ) )
	{
		robot explode_robot();
	}
}

function kill_anything_blocking_goal( goal )
{
	self endon( "end_kill_anything" );
	self.disableFinalKillcam = true;
	
	dirToGoal = VectorNormalize( goal - self.origin );
	atLeastOneDestroyed = false;
	bestCandidate = undefined;
	bestCandidateDot = -999999999.0;
	
	/# debug_draw_blocked_path_kill_radius( self.origin, ROBOT_BLOCKED_KILL_RADIUS ); #/

	entities = GetDamageableEntArray( self.origin, ROBOT_BLOCKED_KILL_RADIUS );
	foreach( entity in entities )
	{
		if ( IsPlayer( entity ) )
			continue;

		if ( entity == self )
			continue;

		if ( entity.classname == "grenade" )
			continue;
		
		if ( !IsAlive( entity ) )
			continue;
		
		// isTouching does not work with some killstreaks like Guardian vs robot, not sure why
		//	if ( !entity IsTouching( self ) )
		//		continue;

		entityDot = VectorDot( dirToGoal, entity.origin - self.origin );
		if ( entityDot > bestCandidateDot )
		{
			bestCandidate = entity;
			bestCandidateDot = entityDot;			
		}
	}
	
	if ( isdefined( bestCandidate ) )
	{
		entity = bestCandidate;

		if ( IsDefined( entity.targetname ) )
		{
			if ( entity.targetname == "talon" )
			{
				entity notify( "death" );
				return true;
			}
		}
	
		if ( IsDefined( entity.helitype ) && entity.helitype == "qrdrone" )
		{
			watcher = entity.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
			watcher thread weaponobjects::waitAndDetonate( entity, 0.0, undefined );
			return true;
		}
						
		if ( entity.classname == "auto_turret" )
		{
			if ( !IsDefined( entity.damagedToDeath ) || !entity.damagedToDeath )
			{
				entity util::DoMaxDamage( self.origin + ( 0, 0, 1 ), self, self, 0, "MOD_CRUSH" );
			}
			return true;
		}
		
		if( IsVehicle( entity ) && ( !isdefined( entity.team ) || entity.team != "neutral" ) ) // vehicles are immune from MOD_CRUSH
		{
			entity kill();
			return true;
		}
	
		entity DoDamage( entity.health * 2, self.origin + ( 0, 0, 1 ), self, self, 0, "MOD_CRUSH" );
		atLeastOneDestroyed = true;
	}
	
	atLeastOneDestroyed = atLeastOneDestroyed || self destroy_supply_crate_blocking_goal( dirToGoal );
	
	return atLeastOneDestroyed;
}


function destroy_supply_crate_blocking_goal( dirToGoal )
{
	crates = GetEntArray( "care_package", "script_noteworthy" );
	bestCrate = undefined;
	bestCrateeDot = -999999999.0;
	
	// find the best crate to destroy
	foreach( crate in crates )
	{
		if ( DistanceSquared( crate.origin, self.origin ) > SQR( ROBOT_BLOCKED_KILL_RADIUS ) )
			continue;
			
		crateDot = VectorDot( dirToGoal, crate.origin - self.origin );
		if ( crateDot > bestCrateeDot )
		{
			bestCrate = crate;
			bestCrateeDot = crateDot;			
		}			
	}
	
	if( isdefined( bestCrate ) )
	{
		PlayFX( level._supply_drop_explosion_fx, bestCrate.origin );
		PlaySoundAtPosition( "wpn_grenade_explode", bestCrate.origin );
		wait ( 0.1 );
		bestCrate supplydrop::crateDelete();
		return true;
	}
		
	return false;
}