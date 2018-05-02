#using scripts\codescripts\struct;

#using scripts\shared\gameskill_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\math_shared;
#using scripts\shared\array_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicles\_attack_drone;
#using scripts\shared\flag_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\ai_interface;
//#using scripts\cp\_util; // for getOtherTeam function

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#insert scripts\shared\ai\utility.gsh;

#define HUNTER_RADIUS									200
#define HUNTER_HALFHEIGHT								100

// Speeds
#define	HUNTER_UNAWARE_SPEED_RATIO						0.5
#define	HUNTER_COMBAT_SPEED_RATIO						1.0
#define	HUNTER_STRAFE_SPEED_RATIO						2.0

// scanner
#define HUNTER_SCANNER_TAG									"tag_gunner_flash3"
#define HUNTER_SCANNER_SCANSPEED						1
#define HUNTER_SCANNER_PITCH							50 // 0 as horizontal, 90 as straight down
#define HUNTER_SCANNER_RANGE_PITCH						20
#define HUNTER_SCANNER_RANGE_YAW						45
#define HUNTER_SCANNER_FOV									190 //90
#define HUNTER_SCANNER_VIEW_DISTANCE						10000

// weapon
#define HUNTER_MISSILE_WEAPON							"hunter_rocket_turret"
#define HUNTER_MISSILE_WEAPON_PLAYER					"hunter_rocket_turret_player"
#define HUNTER_TURRET_RANGE								1500
#define HUNTER_MISSILE_LOCKON_DELAY						1.5 // tunable length of persistent sight on target before fire rocket
#define HUNTER_MISSILE_MINIMAL_INTERVAL					8

// drone
#define HUNTER_DRONE_SPAWNER							"spawner_bo3_attack_drone_enemy"
#define HUNTER_WAITTIME_BEFORE_DEPLOYDRONE				2.2 // will wait this amount of time after player run into a non-reachable space to deploy attack drones

// other
#define HUNTER_ATTACK_TARGET_RANGE						1200
#define HUNTER_FOLLOWING_TARGET_RANGE					1200
#define HUNTER_CHANGE_POSITION_TOATTACK_TARGET_DELAY	0.5
#define HUNTER_GOAL_POINT_STEP							HUNTER_RADIUS * 4

// pain
#define HUNTER_DAMAGE_AMOUNT_TO_SHOW_PAIN				1000 // 0 to disable

// feature control
#define HUNTER_ENABLE_SCANNER_FX						false
#define HUNTER_ENABLE_SIDETURRETS_YIELD_MAINTURRET_TARGET	true // if true, side turret will not choose same target as main turret (so the player being targeted won't get cross fired by all three turrets)
#define HUNTER_ENABLE_WEAKSPOTS							false
#define HUNTER_ENABLE_ATTACK_DRONES						false

#define HUNTER_SEEK_ENEMY_DELAY							1.0

#define HUNTER_STRAFE_COOLDOWN							2.0
#define HUNTER_STRAFE_DISTANCE_TO_ENEMY_DISTANCE_RATIO	0.08

#namespace hunter;

REGISTER_SYSTEM( "hunter", &__init__, undefined )
	
#using_animtree( "generic" );

// ----------------------------------------------
// initialization
// ----------------------------------------------
function __init__()
{
	RegisterInterfaceAttributes( "hunter" );
	vehicle::add_main_callback( "hunter", &hunter_initialize );
}

function RegisterInterfaceAttributes( archetype )
{
	vehicle_ai::RegisterSharedInterfaceAttributes( archetype );

	// Strafe distance
	ai::RegisterNumericInterface(
		archetype,
		"strafe_speed",
		0,
		0, 100 );

	ai::RegisterNumericInterface(
		archetype,
		"strafe_distance",
		0,
		0, 10000 );
}

function hunter_initTagArrays()
{
	self.weakSpotTags = [];
	if ( HUNTER_ENABLE_WEAKSPOTS )
	{
		ARRAY_ADD( self.weakSpotTags, "tag_target_l" );
		ARRAY_ADD( self.weakSpotTags, "tag_target_r" );
	}

	self.explosiveWeakSpotTags = [];
	if ( HUNTER_ENABLE_WEAKSPOTS )
	{
		ARRAY_ADD( self.explosiveWeakSpotTags, "tag_fan_base_l" );
		ARRAY_ADD( self.explosiveWeakSpotTags, "tag_fan_base_r" );
	}

	self.missileTags = [];
	ARRAY_ADD( self.missileTags, "tag_rocket1" );
	ARRAY_ADD( self.missileTags, "tag_rocket2" );

	self.droneAttachTags = [];
	if ( HUNTER_ENABLE_ATTACK_DRONES )
	{
		ARRAY_ADD( self.droneAttachTags, "tag_drone_attach_l" );
		ARRAY_ADD( self.droneAttachTags, "tag_drone_attach_r" );
	}
}

function hunter_SpawnDrones()
{
	self.dronesOwned = [];

	if ( HUNTER_ENABLE_ATTACK_DRONES )
	{
		foreach( droneTag in self.droneAttachTags )
		{
			origin = self GetTagOrigin( droneTag );
			angles = self GetTagAngles( droneTag );

			drone = SpawnVehicle( HUNTER_DRONE_SPAWNER, origin, angles );

			drone.owner = self;
			drone.attachTag = droneTag;
			drone.team = self.team;

			ARRAY_ADD( self.dronesOwned, drone );
		}
	}
}

function hunter_initialize()
{
	self endon( "death" );
	
	self UseAnimTree( #animtree );
	
	Target_Set( self, ( 0, 0, 90 ) );

	ai::CreateInterfaceForEntity( self );

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	//self EnableAimAssist();
	self SetNearGoalNotifyDist( 50 );

	self SetHoverParams( 15, 100, 40 );
	self.flyheight = GetDvarFloat( "g_quadrotorFlyHeight" );

	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0.574;	//+/- 55 degrees = 110 fov

	self.vehAirCraftCollisionEnabled = true;

	self.original_vehicle_type = self.vehicletype;

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	self.goalRadius = 999999;
	self.goalHeight = 999999;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );

	self hunter_initTagArrays();

	self.overrideVehicleDamage = &HunterCallback_VehicleDamage;

	self thread vehicle_ai::nudge_collision();
	
	//disable some cybercom abilities
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}	

	self.ignoreFireFly = true;
	self.ignoreDecoy = true;
	self vehicle_ai::InitThreatBias();

//	self thread hunter_frontScanning();

//	self hunter_SpawnDrones();
//
//	wait 0.5;
//
//	foreach ( drone in self.dronesOwned )
//	{
//		if ( isalive( drone ) )
//		{
//			drone vehicle_ai::set_state( "attached" );
//		}
//	}
	self turret::_init_turret( 1 );
	self turret::_init_turret( 2 );

	self turret::set_best_target_func( &side_turret_get_best_target, 1 );
	self turret::set_best_target_func( &side_turret_get_best_target, 2 );

	self turret::set_burst_parameters( 1, 2, 1, 2, 1 );
	self turret::set_burst_parameters( 1, 2, 1, 2, 2 );

	self turret::set_target_flags( TURRET_TARGET_AI | TURRET_TARGET_PLAYERS, 1 );
	self turret::set_target_flags( TURRET_TARGET_AI | TURRET_TARGET_PLAYERS, 2 );

	self side_turrets_forward();

	self PathVariableOffset( (10, 10, -30), 1 );

	defaultRole();
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role();

	self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &state_combat_enter;
	self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
	self vehicle_ai::get_state_callbacks( "combat" ).exit_func = &state_combat_exit;
	
	self vehicle_ai::get_state_callbacks( "driving" ).enter_func = &hunter_scripted;
	self vehicle_ai::get_state_callbacks( "scripted" ).enter_func = &hunter_scripted;

	self vehicle_ai::get_state_callbacks( "death" ).enter_func = &state_death_enter;
	self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;

	self vehicle_ai::get_state_callbacks( "emped" ).update_func = &hunter_emped;

	self vehicle_ai::add_state( "unaware",
		undefined,
		&state_unaware_update,
		&state_unaware_exit );

	vehicle_ai::add_interrupt_connection( "unaware",	"scripted",	"enter_scripted" );
	vehicle_ai::add_interrupt_connection( "unaware",	"emped",	"emped" );
	vehicle_ai::add_interrupt_connection( "unaware",	"off",		"shut_off" );
	vehicle_ai::add_interrupt_connection( "unaware",	"driving",	"enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "unaware",	"pain",		"pain" );

	self vehicle_ai::add_state( "strafe",
		&state_strafe_enter,
		&state_strafe_update,
		&state_strafe_exit );

	vehicle_ai::add_interrupt_connection( "strafe",	"scripted",	"enter_scripted" );
	vehicle_ai::add_interrupt_connection( "strafe",	"emped",	"emped" );
	vehicle_ai::add_interrupt_connection( "strafe",	"off",		"shut_off" );
	vehicle_ai::add_interrupt_connection( "strafe",	"driving",	"enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "strafe",	"pain",		"pain" );
	vehicle_ai::add_utility_connection( "strafe",	"combat" );

	vehicle_ai::add_utility_connection( "emped",	"strafe" );
	vehicle_ai::add_utility_connection( "pain",	"strafe" );

	vehicle_ai::StartInitialState();
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function shut_off_fx()
{
	self endon( "death" );

	self notify( "death_shut_off" );

	if ( isdefined( self.frontScanner ) )
	{
		self.frontScanner.sndScanningEnt delete();
		self.frontScanner delete();
	}
}

function kill_drones()
{
	self endon( "death" );

	foreach ( drone in self.dronesOwned )
	{
		if ( isalive( drone ) && Distance2DSquared( self.origin, drone.origin ) < SQR( 80 ) )
		{
			damageOrigin = self.origin + (0,0,1);
			drone finishVehicleRadiusDamage(self.death_info.attacker, self.death_info.attacker, 32000, 32000, 10, 0, "MOD_EXPLOSIVE", level.weaponNone,  damageOrigin, 400, -1, (0,0,1), 0);
		}
	}
}

function state_death_enter( params )
{
	self endon( "death" );

	if ( isdefined( self.fakeTargetEnt ) )
	{
		self.fakeTargetEnt Delete();
	}

	vehicle_ai::defaultstate_death_enter();

	self.inpain = true;

	self thread shut_off_fx();
	//self thread kill_drones();
}

function state_death_update( params )
{
	self endon( "death" );

	death_type = vehicle_ai::get_death_type( params );
	if ( !isdefined( death_type ) )
	{
		params.death_type = "gibbed";
		death_type = params.death_type;
	}

	self vehicle_ai::ClearAllLookingAndTargeting();
	self vehicle_ai::ClearAllMovement();
	self CancelAIMove();
	self SetSpeedImmediate( 0 );
	self SetVehVelocity( ( 0, 0, 0 ) );
	self SetPhysAcceleration( ( 0, 0, 0 ) );
	self SetAngularVelocity( ( 0, 0, 0 ) );
	self vehicle_ai::defaultstate_death_update( params );
}
// ----------------------------------------------

// ----------------------------------------------
// State: unaware
// ----------------------------------------------
function state_unaware_enter( params )
{
	ratio = HUNTER_UNAWARE_SPEED_RATIO;
	accel = self GetDefaultAcceleration();
	self SetSpeed( ratio * self.settings.defaultmovespeed, ratio * accel, ratio * accel );
}

function state_unaware_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	if ( isdefined( self.enemy ) )
	{
		self vehicle_ai::set_state( "combat" );
	}

	self ClearLookAtEnt();
	self disable_turrets();
	self thread Movement_Thread_Wander();

	while ( 1 )
	{
		self waittill( "enemy" );
		self vehicle_ai::set_state( "combat" );
	}
}

function state_unaware_exit( params )
{
	self notify( "end_movement_thread" );
}

function Movement_Thread_Wander()
{
	self endon( "death" );
	self notify( "end_movement_thread" );
	self endon( "end_movement_thread" );

	constMinSearchRadius = 120;
	constMaxSearchRadius = 800;

	minSearchRadius = math::clamp( constMinSearchRadius, 0, self.goalRadius );
	maxSearchRadius = math::clamp( constMaxSearchRadius, constMinSearchRadius, self.goalRadius );
	halfHeight = 400;
	innerSpacing = 80;
	outerSpacing = 50;
	maxGoalTimeout = 15;
	timeAtSamePosition = 2.5 + randomfloat( 1 );

	while ( true )
	{
		queryResult = PositionQuery_Source_Navigation( self.origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, self, outerSpacing );
		PositionQuery_Filter_DistanceToGoal( queryResult, self );
		vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
		vehicle_ai::PositionQuery_Filter_Random( queryResult, 0, 10 );
		vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );

		stayAtGoal = timeAtSamePosition > 0.2;

		foundpath = false;
		for ( i = 0; i < queryResult.data.size && !foundpath; i++ )
		{
			goalPos = queryResult.data[i].origin;
			foundpath = self SetVehGoalPos( goalPos, stayAtGoal, true );
		}

		if ( foundPath )
		{
			msg = self util::waittill_any_timeout( maxGoalTimeout, "near_goal", "force_goal", "reached_end_node", "goal" );

			if ( stayAtGoal )
			{
				wait randomFloatRange( 0.5 * timeAtSamePosition, timeAtSamePosition );
			}
		}
		else
		{
			wait 1;
		}
	}
}
// ----------------------------------------------

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function enable_turrets()
{
	//self turret::enable( 0, false );
	self turret::enable( 1, false );
	self turret::enable( 2, false );
}

function disable_turrets()
{
	//self turret::disable( 0 );
	self turret::disable( 1 );
	self turret::disable( 2 );
	self side_turrets_forward();
}

function side_turrets_forward()
{	
	self SetTurretTargetRelativeAngles( (10, -90, 0), 1 );
	self SetTurretTargetRelativeAngles( (10, 90, 0), 2 );
}

function state_combat_enter( params )
{
	ratio = HUNTER_COMBAT_SPEED_RATIO;
	accel = self GetDefaultAcceleration();
	self SetSpeed( ratio * self.settings.defaultmovespeed, ratio * accel, ratio * accel );

	self hunter_lockon_fx();

	self enable_turrets();
}

function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	if ( !isdefined( self.enemy ) )
	{
		self vehicle_ai::set_state( "unaware" );
	}

	self thread Movement_Thread_StayInDistance();
	self thread Attack_Thread_MainTurret();
	self thread Attack_Thread_rocket();

	while ( 1 )
	{
		self waittill( "no_enemy" );
		self vehicle_ai::set_state( "unaware" );
	}
}

function state_combat_exit( params )
{
	self notify( "end_attack_thread" );
	self notify( "end_movement_thread" );
	self ClearTurretTarget();
}
// ----------------------------------------------

// ----------------------------------------------
// State: strafe
// ----------------------------------------------
function state_strafe_enter( params )
{
	ratio = HUNTER_STRAFE_SPEED_RATIO;
	accel = ratio * self GetDefaultAcceleration();
	speed = ratio * self.settings.defaultmovespeed;
	strafe_speed_attribute = ai::get_behavior_attribute("strafe_speed");
	if ( strafe_speed_attribute > 0 )
	{
		speed = strafe_speed_attribute;
	}
	self SetSpeed( speed , accel, accel );
}

function state_strafe_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	self ClearVehGoalPos();

	distanceToTarget = 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax );

	target = self.origin + AnglesToForward( self.angles ) * distanceToTarget;
	if ( isdefined( self.enemy ) )
	{
		distanceToTarget = Distance( self.origin, self.enemy.origin );
	}
	
	distanceThreshold = 500 + distanceToTarget * HUNTER_STRAFE_DISTANCE_TO_ENEMY_DISTANCE_RATIO;
	strafe_distance_attribute = ai::get_behavior_attribute("strafe_distance");
	if ( strafe_distance_attribute > 0 )
	{
		distanceThreshold = strafe_distance_attribute;
	}

	maxSearchRadius = distanceThreshold * 1.5;
	halfHeight = 300;
	outerSpacing = maxSearchRadius * 0.05;
	innerSpacing = outerSpacing * 2;
	
	queryResult = PositionQuery_Source_Navigation( self.origin, 0, maxSearchRadius, halfHeight, innerSpacing, self, outerSpacing );
	PositionQuery_Filter_Directness( queryResult, self.origin, target );
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	PositionQuery_Filter_InClaimedLocation( queryResult, self );
	self vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult, HUNTER_RADIUS );

	foreach ( point in queryResult.data )
	{
		distanceToPointSqr = distanceSquared( point.origin, self.origin );
		if( distanceToPointSqr < distanceThreshold * 0.5 )
		{
			ADD_POINT_SCORE( point, "distAway", -distanceThreshold );
		}
		ADD_POINT_SCORE( point, "distAway", sqrt( distanceToPointSqr ) );

		diffToPreferedDirectness = abs( point.directness - 0 );
		directnessScore = MapFloat( 0, 1, 1000, 0, diffToPreferedDirectness );
		if ( diffToPreferedDirectness > 0.1 )
		{
			directnessScore -= 500;
		}
		ADD_POINT_SCORE( point, "directnessRaw", point.directness );
		ADD_POINT_SCORE( point, "directness", directnessScore );

		if ( point.directionChange < 0.6 )
		{
			ADD_POINT_SCORE( point, "directionChange", -2000 );
		}
		ADD_POINT_SCORE( point, "directionChangeRaw", point.directionChange );
	}

	vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );
	self vehicle_ai::PositionQuery_DebugScores( queryResult );
	
	foreach ( point in queryResult.data )
	{
		self.current_pathto_pos = point.origin;

		foundpath = self SetVehGoalPos( self.current_pathto_pos, true, true );

		if ( foundPath )
		{
			msg = self util::waittill_any_timeout( 5, "near_goal", "force_goal", "goal", "enemy_visible" );
			break;
		}
	}

	previous_state = self vehicle_ai::get_previous_state();

	if ( !isdefined( previous_state ) || previous_state == "strafe" )
	{
		previous_state = "combat";
	}

	self vehicle_ai::set_state( previous_state );
}

function state_strafe_exit( params )
{
	vehicle_ai::Cooldown( "strafe_again", HUNTER_STRAFE_COOLDOWN );
}

// ----------------------------------------------

function GetNextMovePosition_tactical( enemy )
{
	if( self.goalforced )
	{
		return self.goalpos;
	}
	
	selfDistToEnemy = Distance2D( self.origin, enemy.origin );

	// distance based multipliers
	goodDist = 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax );

	tooCloseDist = 0.8 * goodDist;
	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToEnemy );

	preferedDistAwayFromOrigin = 150;

	maxSearchRadius = 1000 * queryMultiplier;
	halfHeight = 300 * queryMultiplier;
	innerSpacing = 80 * queryMultiplier;
	outerSpacing = 80 * queryMultiplier;
	
	queryResult = PositionQuery_Source_Navigation( self.origin, 0, maxSearchRadius, halfHeight, innerSpacing, self, outerSpacing );
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	PositionQuery_Filter_InClaimedLocation( queryResult, self );
	PositionQuery_Filter_Sight( queryResult, enemy.origin, self GetEye() - self.origin, self, 0, enemy );
	self vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult, HUNTER_RADIUS );
	self vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, enemy, self.settings.engagementDistMin, self.settings.engagementDistMax );
	self vehicle_ai::PositionQuery_Filter_Random( queryResult, 0, 30 );

	goalHeight = enemy.origin[2] + 0.5 * ( self.settings.engagementHeightMin + self.settings.engagementHeightMax );
			
	foreach ( point in queryResult.data )
	{
		if ( !point.visibility )
		{
			ADD_POINT_SCORE( point, "no visibility", -600 );
		}

		ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );
		
		// distance from origin
		ADD_POINT_SCORE( point, "distToOrigin", MapFloat( 0, preferedDistAwayFromOrigin, 0, 600, point.distToOrigin2D ) );
		
		if( point.inClaimedLocation )
		{
			ADD_POINT_SCORE( point, "inClaimedLocation", -500 );
		}
		
		// height
		preferedHeightRange = 75;
		distFromPreferredHeight = abs( point.origin[2] - goalHeight );
		if ( distFromPreferredHeight > preferedHeightRange )
		{
			heightScore = -MapFloat( preferedHeightRange, 5000, 0, 9000, distFromPreferredHeight );
			ADD_POINT_SCORE( point, "height", heightScore );
		}
	}
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );
	
	if( queryResult.data.size )
	{
		return queryResult.data[0].origin;
	}
	
	return self.origin;
}

function Movement_Thread_StayInDistance()
{
	self endon( "death" );
	self notify( "end_movement_thread" );
	self endon( "end_movement_thread" );

	maxGoalTimeout = 10;
	
	stuckCount = 0;

	while ( true )
	{
		enemy = self.enemy;
		if ( !isdefined( enemy ) )
		{
			wait 1;
			continue;
		}

		usePathfinding = true;
		onNavVolume = IsPointInNavVolume( self.origin, "navvolume_big" );
		if ( !onNavVolume )
		{
			// off nav volume, try getting back
			getbackPoint = undefined;
			pointOnNavVolume = self GetClosestPointOnNavVolume( self.origin, 500 );
			if ( isdefined( pointOnNavVolume ) )
			{
				if ( SightTracePassed( self.origin, pointOnNavVolume, false, self ) )
				{
					getbackPoint = pointOnNavVolume;
				}
			}

			if ( !isdefined( getbackPoint ) )
			{
				queryResult = PositionQuery_Source_Navigation( self.origin, 0, 800, 400, 1.5 * self.radius );
				PositionQuery_Filter_Sight( queryResult, self.origin, (0, 0, 0), self, 1 );
				getbackPoint = undefined;
				foreach( point in queryResult.data )
				{
					if ( point.visibility === true )
					{
						getbackPoint = point.origin;
						break;
					}
				}
			}

			if ( isdefined( getbackPoint ) )
			{
				self.current_pathto_pos = getbackPoint;
				usePathfinding = false;
			}
			else
			{
				stuckCount++;
				if ( stuckCount == 1 )
				{
					stuckLocation = self.origin;
				}
				else if ( stuckCount > 10 )
				{
					/# 
					assert( false, "Hunter fall outside of NavVolume at " + self.origin );
					v_box_min = ( -self.radius, -self.radius, -self.radius );
					v_box_max = ( self.radius, self.radius, self.radius );
					Box( self.origin, v_box_min, v_box_max, self.angles[1], (1,0,0), 1, false, 1000000 ); 
					if ( isdefined( stuckLocation ) )
					{
						Line( stuckLocation, self.origin, (1,0,0), 1, true, 1000000 );
					}
					#/
					self Kill();
				}
			}
		}
		else
		{
			stuckCount = 0;

			if( self.goalforced )
			{
				goalpos = self GetClosestPointOnNavVolume( self.goalpos, 200 );
				if ( isdefined( goalpos ) )
				{
					self.current_pathto_pos = goalpos;
					usePathfinding = true;
				}
				else
				{
					self.current_pathto_pos = self.goalpos;
					usePathfinding = false;
				}
			}
			else
			{
				self.current_pathto_pos = GetNextMovePosition_tactical( enemy );
				usePathfinding = true;
			}
		}
		
		if ( !isDefined( self.current_pathto_pos ) )
		{
			wait 0.5;
			continue;
		}

		distanceToGoalSq = DistanceSquared( self.current_pathto_pos, self.origin );
		
		if ( distanceToGoalSq > SQR( 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax ) ) )
		{
			self SetSpeed( self.settings.defaultMoveSpeed * 2 );
		}
		else
		{
			self SetSpeed( self.settings.defaultMoveSpeed );
		}
				
		self SetLookAtEnt( enemy );

		foundpath = self SetVehGoalPos( self.current_pathto_pos, true, usePathfinding );

		if ( foundPath )
		{
			/#
			if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
			{
				recordLine( self.origin, self.current_pathto_pos, (0.3,1,0) );
				recordLine( self.origin, enemy.origin, (1,0,0.4) );
			}
			#/

			msg = self util::waittill_any_timeout( maxGoalTimeout, "near_goal", "force_goal", "goal" );
		}
		else
		{
			wait 0.5;
		}

		enemy = self.enemy;
		if ( isdefined( enemy ) )
		{
			goalHeight = enemy.origin[2] + 0.5 * ( self.settings.engagementHeightMin + self.settings.engagementHeightMax );
			distFromPreferredHeight = abs( self.origin[2] - goalHeight );

			farDist = self.settings.engagementDistMax;
			nearDist = self.settings.engagementDistMin;

			selfDistToEnemy = Distance2D( self.origin, enemy.origin );

			if ( self VehCanSee( enemy ) && selfDistToEnemy < farDist && selfDistToEnemy > nearDist && distFromPreferredHeight < 230 )
			{
				msg = self util::waittill_any_timeout( RandomFloatRange( 2, 4 ), "enemy_not_visible" );
				if ( msg == "enemy_not_visible" )
				{
					msg = self util::waittill_any_timeout( HUNTER_SEEK_ENEMY_DELAY, "enemy_visible" );
					if ( msg != "timeout" )
					{
						wait 1;
					}
				}
			}
		}
		else
		{
			wait 1;
		}
	}
}

function Delay_Target_ToEnemy_Thread( point, enemy, timeToHit )
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "end_attack_thread" );
	self endon( "faketarget_stop_moving" );
	enemy endon( "death" );

	if ( !isdefined( self.fakeTargetEnt ) )
	{
		self.fakeTargetEnt = Spawn( "script_origin", point );
	}
	
	self.fakeTargetEnt Unlink();

	self.fakeTargetEnt.origin = point;
	self SetTurretTargetEnt( self.fakeTargetEnt );
	self waittill( "turret_on_target" );

	timeStart = GetTime();
	offset = (0, 0, 0);
	if( IsSentient( enemy ) )
	{
		offset = enemy GetEye() - enemy.origin;
	}

	while( GetTime() < timeStart + timeToHit * 1000 )
	{
		self.fakeTargetEnt.origin = LerpVector( point, enemy.origin + offset, ( GetTime() - timeStart ) / ( timeToHit * 1000 ) );
		///#debugstar( self.fakeTargetEnt.origin, 1000, (0,1,0) ); #/
		WAIT_SERVER_FRAME;
	}

	self.fakeTargetEnt.origin = enemy.origin + offset;
	WAIT_SERVER_FRAME;
	self.fakeTargetEnt LinkTo( enemy );
}

function Attack_Thread_MainTurret()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "end_attack_thread" );
	
	while( 1 )
	{
		enemy = self.enemy;
		if( isdefined( enemy ) )
		{
			self SetLookAtEnt( enemy );
			
			if( self VehCanSee( enemy ) )
			{
				vectorFromEnemy = VectorNormalize( FLAT_ORIGIN( (self.origin - enemy.origin) ) );

				self thread Delay_Target_ToEnemy_Thread( enemy.origin + vectorFromEnemy * 300, enemy, 1.5 );

				self waittill( "turret_on_target" );
				self vehicle_ai::fire_for_time( 2 + RandomFloat( 0.8 ) );
				
				self ClearTurretTarget();
				self SetTurretTargetRelativeAngles( (15,0,0), 0 );

				if( isdefined( enemy ) && IsAI( enemy ) )
				{
					wait( 2.5 + RandomFloat( 0.5 ) );
				}
				else
				{
					wait( 2.0 + RandomFloat( 0.4 ) );
				}
			}
			else
			{
				wait 0.4;
			}
		}
		else
		{
			self ClearTurretTarget();
			self ClearLookAtEnt();
			wait 0.4;
		}
	}
}

function Attack_Thread_rocket()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "end_attack_thread" );

	while( true )
	{
		enemy = self.enemy;
		if ( !isdefined( enemy ) )
		{
			wait 1;
			continue;
		}

		if ( isdefined( enemy ) && self VehCanSee( enemy ) && vehicle_ai::IsCooldownReady( "rocket_launcher" ) )
		{
			vehicle_ai::Cooldown( "rocket_launcher", HUNTER_MISSILE_MINIMAL_INTERVAL );

			self notify( "end_movement_thread" );
			self ClearVehGoalPos();
			self SetVehGoalPos( self.origin, true, false );

			target = enemy.origin;
			self SetLookAtEnt( enemy );
			self hunter_lockon_fx();

			wait HUNTER_MISSILE_LOCKON_DELAY;

			eye = self GetTagOrigin( "tag_eye" );
			if ( isdefined( enemy ) )
			{
				anglesToTarget = VectorToAngles( enemy.origin - eye );
				angles = anglesToTarget - self.angles;
				if ( -30 < angles[0] && angles[0] < 60 && -70 < angles[1] && angles[1] < 70 )
				{
					target = enemy.origin;
				}
				else
				{
					anglesToTarget = VectorToAngles( target - eye );
				}
			}
			else
			{
				anglesToTarget = VectorToAngles( target - eye );
			}

			rightDir = AnglesToRight( anglesToTarget );

			randomRange = 30;
			offset = [];
			offset[0] = -rightDir * randomRange * 2 + ( RandomFloatRange( -randomRange, randomRange ), RandomFloatRange( -randomRange, randomRange ), 0 );
			offset[1] = rightDir * randomRange * 2 + ( RandomFloatRange( -randomRange, randomRange ), RandomFloatRange( -randomRange, randomRange ), 0 );

			self hunter_fire_one_missile( 0, target, offset[0] );

			wait 0.5;

			if ( isdefined( enemy ) )
			{
				eye = self GetTagOrigin( "tag_eye" );
				angles = VectorToAngles( enemy.origin - eye ) - self.angles;
				if ( -30 < angles[0] && angles[0] < 60 && -70 < angles[1] && angles[1] < 70 )
				{
					target = enemy.origin;
				}
			}
			self hunter_fire_one_missile( 1, target, offset[1] );

			wait 1;

			self thread Movement_Thread_StayInDistance();
		}
		wait 0.5;
	}
}
// ----------------------------------------------

// best target of side turrets: closest, can hit, and not target of main turret or other turret
function side_turret_get_best_target( a_potential_targets, n_index )
{
	if ( self.ignoreall === true )
	{
		return undefined;
	}	

	shouldYield = HUNTER_ENABLE_SIDETURRETS_YIELD_MAINTURRET_TARGET && level.gameskill < 3;

	main_turret_target = self.enemy;

	if ( n_index === 2 )
	{
		other_turret_target = turret::get_target( 1 );
	}

	if ( shouldYield )
	{
		ArrayRemoveValue( a_potential_targets, main_turret_target );
		ArrayRemoveValue( a_potential_targets, other_turret_target );
	}

	e_best_target = undefined;

	while ( !isdefined( e_best_target ) && ( a_potential_targets.size > 0 ) )
	{
		e_closest_target = ArrayGetClosest( self.origin, a_potential_targets );

		if( self turret::can_hit_target( e_closest_target, n_index ) )
		{
			e_best_target = e_closest_target;
		}
		else
		{
			ArrayRemoveValue( a_potential_targets, e_closest_target );
		}
	}

	return e_best_target;
}

// ----------------------------------------------
// missile
// ----------------------------------------------
function hunter_fire_one_missile( launcher_index, target, offset, blinkLights, waittimeAfterBlinkLights )
{
	self endon( "death" );

	if ( IS_TRUE( blinkLights ) )
	{
		self vehicle_ai::blink_lights_for_time( 1 );

		if ( isdefined( waittimeAfterBlinkLights ) && waittimeAfterBlinkLights > 0 )
		{
			wait waittimeAfterBlinkLights;
		}
	}

	if ( !isdefined( offset ) )
	{
		offset = ( 0, 0, 0 );
	}

	spawnTag = self.missileTags[ launcher_index ];
	origin = self GetTagOrigin( spawnTag );
	angles = self GetTagAngles( spawnTag );
	forward = AnglesToForward( angles );
	up = AnglesToUp( angles );

	if ( isdefined( spawnTag ) && isdefined( target ) )
	{
		weapon = GetWeapon( HUNTER_MISSILE_WEAPON );
		
		//only do the full MagicBullet parameter list if target is a real entity, and not a script_struct
		if ( IsEntity( target ) )
		{
			missile = MagicBullet( weapon, origin, target.origin + offset, self, target, offset );
			//missile thread remote_missile_life();
		}
		else if ( IsVec( target ) )
		{
			missile = MagicBullet( weapon, origin, target + offset, self );
		}
		else
		{
			missile = MagicBullet( weapon, origin, target.origin + offset, self );
		}
	}
}

function remote_missile_life()
{
	self endon( "death" );

	hostmigration::waitLongDurationWithHostMigrationPause( 10 );

	playFX( level.remote_mortar_fx["missileExplode"], self.origin );
	self playlocalsound( "mpl_ks_reaper_explosion" );
	self delete();
}

function hunter_lockon_fx()
{
	self thread vehicle_ai::blink_lights_for_time( 1.5 );
	self playsound( "veh_hunter_alarm_target" );
}

//self == hunter
function getEnemyArray( include_ai, include_player )
{
	enemyArray = [];

	enemy_team = "allies";//util::getOtherTeam( self.team );

	if ( IS_TRUE( include_ai ) )
	{
		aiArray = GetAITeamArray( enemy_team );
		enemyArray = ArrayCombine( enemyArray, aiArray, false, false );
	}

	if ( IS_TRUE( include_player ) )
	{
		playerArray = GetPlayers( enemy_team );
		enemyArray = ArrayCombine( enemyArray, playerArray, false, false );
	}

	return enemyArray;
}

// ----------------------------------------------
// scanner
// ----------------------------------------------

//self == hunter
function is_point_in_view( point, do_trace )
{
	if ( !isdefined( point ) )
	{
		return false;
	}

	scanner = self.frontScanner;
	vector_to_point = point - scanner.origin;
	in_view = ( LengthSquared( vector_to_point ) <= SQR( HUNTER_SCANNER_VIEW_DISTANCE ) );

	if ( in_view )
	{
		in_view = util::within_fov( scanner.origin, scanner.angles, point, Cos( HUNTER_SCANNER_FOV ) );
	}

	if ( in_view && IS_TRUE( do_trace ) && isdefined( self.enemy ) )
	{
		in_view = SightTracePassed( scanner.origin, point, false, self.enemy );
	}

	return in_view;
}

//self == hunter
function is_valid_target( target, do_trace )
{
	target_is_valid = true;

	// check script properties
	if ( IS_TRUE( target.ignoreme ) || ( target.health <= 0 ) )
	{
		target_is_valid = false;
	}
	// check sentient properties
	else if ( IsSentient( target ) && ( ( target IsNoTarget() ) || ( target ai::is_dead_sentient() ) ) )
	{
		target_is_valid = false;
	}
	// check fov
	else if ( isdefined( target.origin ) && !is_point_in_view( target.origin, do_trace ) )
	{
		target_is_valid = false;
	}

	return target_is_valid;
}

//self == hunter
function get_enemies_in_view( do_trace )
{
	validEnemyArray = [];
	enemyArray = getEnemyArray( true, true );

	foreach( enemy in enemyArray )
	{
		if ( is_valid_target( enemy, do_trace ) )
		{
			ARRAY_ADD( validEnemyArray, enemy );
		}
	}

	return validEnemyArray;
}

// self == hunter
function hunter_scanner_init()
{
	self.frontScanner = Spawn( "script_model", self GetTagOrigin( HUNTER_SCANNER_TAG ) );
	self.frontScanner SetModel( "tag_origin" );

	self.frontScanner.angles = self GetTagAngles( HUNTER_SCANNER_TAG );
	self.frontScanner LinkTo( self, HUNTER_SCANNER_TAG );

	self.frontScanner.owner = self;
	self.frontScanner.hasTargetEnt = false;

	self.frontScanner.sndScanningEnt = spawn( "script_origin", self.frontScanner.origin + anglesToForward( self.angles ) * 1000 );
	self.frontScanner.sndScanningEnt linkto( self.frontScanner );

	wait 0.25;

	//self.frontScanner thread hunter_scanner_lookTarget( self );

	if ( HUNTER_ENABLE_SCANNER_FX )
	{
		PlayFxOnTag( self.settings.spotlightfx, self.frontScanner, "tag_origin" );
	}
}

// self == hunter
function hunter_scanner_SetTargetEntity( targetEnt, offset )
{
	if ( !isdefined( offset ) )
	{
		offset = ( 0, 0, 0 );
	}

	if( IsDefined( targetEnt ) )
	{
		self.frontScanner.targetEnt = targetEnt;
		self.frontScanner.hasTargetEnt = true;
		self SetGunnerTargetEnt( self.frontScanner.targetEnt, offset, 2 );
	}
}

// self == hunter
function hunter_scanner_ClearLookTarget()
{
	self.frontScanner.hasTargetEnt = false;
	self ClearGunnerTarget( 2 );
}

// self == hunter
function hunter_scanner_SetTargetPosition( targetPos )
{
	if( IsDefined( targetPos ) )
	{
		self.frontScanner.targetPos = targetPos;
		self SetGunnerTargetVec( self.frontScanner.targetPos, 2 );
	}
}

function hunter_frontScanning()
{
	self endon( "death_shut_off" );
	self endon( "crash_done" );
	self endon( "death" );

	hunter_scanner_init();

	offsetFactorPitch = 0;
	offsetFactorYaw = 0;

	// use 2 different irrational numbers here to help avoiding repetitive patterns
	pitchStep = HUNTER_SCANNER_SCANSPEED * 2.23606797749978969640; // irrational number sqrt(5)
	yawStep = HUNTER_SCANNER_SCANSPEED * 3.14159265358979323846; // irrational number PI

	pitchRange = HUNTER_SCANNER_RANGE_PITCH;
	yawRange = HUNTER_SCANNER_RANGE_YAW;

	scannerDirection = undefined;

	while ( 1 )
	{
		scannerOrigin = self.frontScanner.origin;

		if ( IS_TRUE( self.inpain ) )
		{
			wait 0.3;
			offset = ( HUNTER_SCANNER_PITCH, 0, 0 ) + ( math::randomSign() * RandomFloatRange( 1, 2 ) * pitchRange, math::randomSign() * RandomFloatRange( 1, 2 ) * yawRange, 0 );
			scannerDirection = anglesToForward( self.angles + offset );
		}
		else if ( !IsDefined( self.enemy ) )
		{
			if ( HUNTER_ENABLE_SCANNER_FX )
			{
				self.frontScanner.sndScanningEnt playloopsound( "veh_hunter_scanner_loop", 1 );
			}

			offsetFactorPitch = offsetFactorPitch + pitchStep;
			offsetFactorYaw = offsetFactorYaw + yawStep;

			offset = ( HUNTER_SCANNER_PITCH, 0, 0 ) + ( Sin( offsetFactorPitch ) * pitchRange, Cos( offsetFactorYaw ) * yawRange, 0 );
			scannerDirection = anglesToForward( self.angles + offset );

			enemies = get_enemies_in_view( true );

			if ( enemies.size > 0 )
			{
				closest_enemy = ArrayGetClosest( self.origin, enemies );
				
				self.favoriteEnemy = closest_enemy;
				/# line( scannerOrigin, closest_enemy.origin, ( 0, 1, 0 ), 1, 3 ); #/
			}
		}
		else
		{
			if ( self is_point_in_view( self.enemy.origin, true ) )
			{
				self notify ( "hunter_lockOnTargetInSight" );
			}
			else
			{
				self notify ( "hunter_lockOnTargetOutSight" );
			}

			scannerDirection = VectorNormalize( self.enemy.origin - scannerOrigin );

			if ( HUNTER_ENABLE_SCANNER_FX )
			{
				self.frontScanner.sndScanningEnt stoploopsound( 1 );
			}
		}

		targetLocation = scannerOrigin + scannerDirection * 1000; // any big value will do
		self hunter_scanner_SetTargetPosition( targetLocation );

		/# line( scannerOrigin, self.frontScanner.targetPos, ( 0, 1, 0 ), 1, 1000 ); #/
		wait 0.1;
	}
}

function hunter_exit_vehicle()
{
	self waittill( "exit_vehicle", player );

	player.ignoreme = false;
	player DisableInvulnerability();

	self SetHeliHeightLock( false );
	self EnableAimAssist();
	self SetVehicleType( self.original_vehicle_type );
	self.attachedpath = undefined;
	self SetGoal( self.origin, false, 4096, 512 );
}

function hunter_scripted( params )
{
	// do nothing state
	params.driver = self GetSeatOccupant( 0 );
	if ( isdefined( params.driver ) )
	{
		self DisableAimAssist();

		self thread vehicle_death::vehicle_damage_filter( "firestorm_turret" );
		//self thread hunter_set_team( driver.team );
		params.driver.ignoreme = true;
		params.driver EnableInvulnerability();

		if ( isdefined( self.vehicle_weapon_override ) )
		{
			self SetVehWeapon( self.vehicle_weapon_override );
		}

		self thread hunter_exit_vehicle();
		//self thread hunter_update_rumble();
		self thread hunter_collision_player();
		//self thread hunter_self_destruct();
		self thread player_fire_update_side_turret_1();
		self thread player_fire_update_side_turret_2();
		self thread player_fire_update_rocket();
	}

	if ( isdefined( self.goal_node ) && isdefined( self.goal_node.hunter_claimed ) )
	{
		self.goal_node.hunter_claimed = undefined;
	}

	self ClearTargetEntity();
	self ClearVehGoalPos();
	self PathVariableOffsetClear();
	self PathFixedOffsetClear();
	self ClearLookAtEnt();
	self ResumeSpeed();
}

function player_fire_update_side_turret_1()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	weapon = self SeatGetWeapon( 1 );
	fireTime = weapon.fireTime;
	
	while( 1 )
	{
		self SetGunnerTargetVec( self GetTurretTargetVec( 0 ), 0 );
		if( self IsDriverFiring( ) )
		{
			self FireWeapon( 1 );
		}
		wait fireTime;
	}
}

function player_fire_update_side_turret_2()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	weapon = self SeatGetWeapon( 2 );
	fireTime = weapon.fireTime;
	
	while( 1 )
	{
		self SetGunnerTargetVec( self GetTurretTargetVec( 0 ), 1 );
		if( self IsDriverFiring( ) )
		{
			self FireWeapon( 2 );
		}
		wait fireTime;
	}
}

function player_fire_update_rocket()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	weapon = GetWeapon( HUNTER_MISSILE_WEAPON_PLAYER );
	fireTime = weapon.fireTime;
	driver = self GetSeatOccupant( 0 );
	
	while( 1 )
	{

		if( driver ButtonPressed( "BUTTON_A" ) )
		{
			spawnTag0 = self.missileTags[ 0 ];
			spawnTag1 = self.missileTags[ 1 ];
			origin0 = self GetTagOrigin( spawnTag0 );
			origin1 = self GetTagOrigin( spawnTag1 );
			target = self GetTurretTargetVec( 0 );
			
			MagicBullet( weapon, origin0, target );
			MagicBullet( weapon, origin1, target );
			
			wait fireTime;
		}
		
		Wait 0.05;
	}
}

function hunter_collision_player()
{
	self endon( "change_state" );
	self endon( "crash_done" );
	self endon( "death" );

	while ( 1 )
	{
		self waittill( "veh_collision", velocity, normal );
		driver = self GetSeatOccupant( 0 );
		if ( isdefined( driver ) && LengthSquared( velocity ) > 70 * 70 )
		{
			Earthquake( 0.25, 0.25, driver.origin, 50 );
			driver PlayRumbleOnEntity( "damage_heavy" );
		}
	}
}

// Lots of gross hardcoded values! :(
function hunter_update_rumble()
{
	self endon( "death" );
	self endon( "exit_vehicle" );

	while ( 1 )
	{
		vr = Abs( self GetSpeed() / self GetMaxSpeed() );

		if ( vr < 0.1 )
		{
			level.player PlayRumbleOnEntity( "hunter_fly" );
			wait 0.35;
		}
		else
		{
			time = RandomFloatRange( 0.1, 0.2 );
			Earthquake( RandomFloatRange( 0.1, 0.15 ), time, self.origin, 200 );
			level.player PlayRumbleOnEntity( "hunter_fly" );
			wait time;
		}
	}
}

function hunter_self_destruct()
{
	self endon( "death" );
	self endon( "exit_vehicle" );

	const max_self_destruct_time = 5;

	self_destruct = false;
	self_destruct_time = 0;

	while ( 1 )
	{
		if ( !self_destruct )
		{
			if ( level.player MeleeButtonPressed() )
			{
				self_destruct = true;
				self_destruct_time = max_self_destruct_time;
			}

			WAIT_SERVER_FRAME;
			continue;
		}
		else
		{
			IPrintLnBold( self_destruct_time );

			wait 1;

			self_destruct_time -= 1;
			if ( self_destruct_time == 0 )
			{
				driver = self GetSeatOccupant( 0 );
				if ( isdefined( driver ) )
				{
					driver DisableInvulnerability();
				}

				Earthquake( 3, 1, self.origin, 256 );
				RadiusDamage( self.origin, 1000, 15000, 15000, level.player, "MOD_EXPLOSIVE" );
				self DoDamage( self.health + 1000, self.origin );
			}

			continue;
		}
	}
}

function hunter_level_out_for_landing()
{
	self endon( "death" );
	self endon( "emped" );
	self endon( "landed" );

	while ( isdefined( self.emped ) )
	{
		velocity = self.velocity;	// setting the angles clears the velocity so we save it off and set it back
		self.angles = ( self.angles[0] * 0.85, self.angles[1], self.angles[2] * 0.85 );
		ang_vel = self GetAngularVelocity() * 0.85;
		self SetAngularVelocity( ang_vel );
		self SetVehVelocity( velocity );
		WAIT_SERVER_FRAME;
	}
}

function hunter_emped( params )
{
	self endon( "death" );
	self endon( "emped" );

	self.emped = true;

	wait RandomFloatRange( 4, 7 );

	self vehicle_ai::evaluate_connections();

/*
	PlaySoundAtPosition( "veh_qrdrone_emp_down", self.origin );

	if ( !isdefined( self.stun_fx ) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_origin", ( 0, 0, 0 ), ( 0, 0, 0 ) );
		PlayFXOnTag( level._effect[ "hunter_stun" ], self.stun_fx, "tag_origin" );
	}

	wait RandomFloatRange( 4, 7 );

	self.stun_fx delete();

	self playsound ( "veh_qrdrone_boot_qr" );
*/
}

// ----------------------------------------------
// pain/hit reaction
// ----------------------------------------------
function hunter_pain_for_time( time, velocityStablizeParam, rotationStablizeParam, restoreLookPoint )
{
	self endon( "death" );
	self.painStartTime = GetTime();

	if ( !IS_TRUE( self.inpain ) )
	{
		self.inpain = true;

		while ( GetTime() < self.painStartTime + time * 1000 )
		{
			self SetVehVelocity( self.velocity * velocityStablizeParam );
			self SetAngularVelocity( self GetAngularVelocity() * rotationStablizeParam );
			wait 0.1;
		}

		if ( isdefined( restoreLookPoint ) )
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

		self.inpain = false;
	}
}

function hunter_pain_small( eAttacker, damageType, hitPoint, hitDirection, hitLocationInfo, partName )
{
	if( !isdefined( hitPoint ) || !isdefined( hitDirection ) )
	{
		return;
	}
	
	self SetVehVelocity( self.velocity + VectorNormalize( hitDirection ) * 20 );

	if ( !IS_TRUE( self.inpain ) )
	{
		vecRight = anglesToRight( self.angles );
		sign = math::sign( vectorDot( vecRight, hitDirection ) );
		yaw_vel =  sign * RandomFloatRange( 100, 140 );

		ang_vel = self GetAngularVelocity();
		ang_vel += ( RandomFloatRange( -120, -100 ), yaw_vel, RandomFloatRange( -100, 100 ) );
		self SetAngularVelocity( ang_vel );

		self thread hunter_pain_for_time( 1.5, 1.0, 0.8 );
	}

	self vehicle_ai::set_state( "strafe" );
}

function HunterCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	driver = self GetSeatOccupant( 0 );

	// no friendly fire
	if ( isdefined( eAttacker ) && eAttacker.team == self.team )
	{
		return 0;
	}

	num_players = GetPlayers().size;
	maxDamage = self.healthdefault * ( 0.35 - 0.025 * num_players );
	if ( sMeansOfDeath !== "MOD_UNKNOWN" && iDamage > maxDamage )
	{
		iDamage = maxDamage;
	}

	if ( !isdefined( self.damageLevel ) )
	{
		self.damageLevel = 0;
		self.newDamageLevel = self.damageLevel;
	}

	newDamageLevel = vehicle::should_update_damage_fx_level( self.health, iDamage, self.healthdefault );
	if ( newDamageLevel > self.damageLevel )
	{
		self.newDamageLevel = newDamageLevel;
	}

	if ( self.newDamageLevel > self.damageLevel )
	{
		self.damageLevel = self.newDamageLevel;
		if ( self.pain_when_damagelevel_change === true )
		{
			hunter_pain_small( eAttacker, sMeansOfDeath, vPoint, vDir, sHitLoc, partName );
		}
		vehicle::set_damage_fx_level( self.damageLevel );
	}
	
	if ( vehicle_ai::should_emp( self, weapon, sMeansOfDeath, eInflictor, eAttacker ) )
	{
		hunter_pain_small( eAttacker, sMeansOfDeath, vPoint, vDir, sHitLoc, partName );
	}

	return iDamage;
}
