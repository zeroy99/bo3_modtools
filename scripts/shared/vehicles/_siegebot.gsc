// ----------------------------------------------------------------------------
// #using
// ----------------------------------------------------------------------------
#using scripts\codescripts\struct;

#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;

#using scripts\shared\turret_shared;
#using scripts\shared\weapons\_spike_charge_siegebot;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#insert scripts\shared\ai\utility.gsh;

#define JUMP_COOLDOWN 7
#define DEBUG_ON false

#namespace siegebot;

REGISTER_SYSTEM( "siegebot", &__init__, undefined )

#using_animtree( "generic" );

function __init__()
{	
	vehicle::add_main_callback( "siegebot", &siegebot_initialize );
}

function siegebot_initialize()
{
	self useanimtree( #animtree );
	
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();
	
	Target_Set( self, ( 0, 0, 84 ) );

	self EnableAimAssist();
	self SetNearGoalNotifyDist( 40 );
	
	self.fovcosine = 0.5; // +/-60 degrees = 120 fov
	self.fovcosinebusy = 0.5;
	self.maxsightdistsqrd = SQR( 10000 );

	assert( isdefined( self.scriptbundlesettings ) );

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	self.goalRadius = 9999999;
	self.goalHeight = 5000;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	
	self.overrideVehicleDamage = &siegebot_callback_damage;
	
	self siegebot_update_difficulty();
	
	self SetGunnerTurretOnTargetRange( 0, self.settings.gunner_turret_on_target_range );
	
	self ASMRequestSubstate( "locomotion@movement" );
	
	if( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 0.5 );
		self HidePart( "tag_turret_canopy_animate" );
		self HidePart( "tag_turret_panel_01_d0" );
		self HidePart( "tag_turret_panel_02_d0" );
		self HidePart( "tag_turret_panel_03_d0" );
		self HidePart( "tag_turret_panel_04_d0" );
		self HidePart( "tag_turret_panel_05_d0" );
	}
	else if( self.vehicletype == "zombietron_veh_siegebot" )
	{
		self ASMSetAnimationRate( 1.429 );
	}

	self initJumpStruct();

	//disable some cybercom abilities
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}

	self.ignoreFireFly = true;
	self.ignoreDecoy = true;
	self vehicle_ai::InitThreatBias();

	self thread vehicle_ai::target_hijackers();

	if( !SessionModeIsMultiplayerGame() )
		defaultRole();
}


function siegebot_update_difficulty()
{
	value = gameskill::get_general_difficulty_level();
	
	scale_up = mapfloat( 0, 9, 0.8, 2.0, value );
	scale_down = mapfloat( 0, 9, 1.0, 0.5, value );
	
	self.difficulty_scale_up = scale_up;
	self.difficulty_scale_down = scale_down;
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
    self vehicle_ai::get_state_callbacks( "combat" ).exit_func = &state_combat_exit;
    
    self vehicle_ai::get_state_callbacks( "driving" ).update_func = &siegebot_driving;

    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;

    self vehicle_ai::get_state_callbacks( "pain" ).update_func = &pain_update;

    self vehicle_ai::get_state_callbacks( "emped" ).enter_func = &emped_enter;
    self vehicle_ai::get_state_callbacks( "emped" ).update_func = &emped_update;
    self vehicle_ai::get_state_callbacks( "emped" ).exit_func = &emped_exit;
    self vehicle_ai::get_state_callbacks( "emped" ).reenter_func = &emped_reenter;

	self vehicle_ai::add_state( "jump",
		&state_jump_enter,
		&state_jump_update,
		&state_jump_exit );

	vehicle_ai::add_utility_connection( "combat", "jump", &state_jump_can_enter );
	vehicle_ai::add_utility_connection( "jump", "combat" );

	self vehicle_ai::add_state( "unaware",
		undefined,
		&state_unaware_update,
		undefined );
	// don't use this for now unless we really need it

	vehicle_ai::StartInitialState( "combat" );
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function state_death_update( params )
{
	self endon( "death" );	
	self endon( "nodeath_thread" );

	// Need to prep the death model
	StreamerModelHint( self.deathmodel, 6 );

	death_type = vehicle_ai::get_death_type( params );
	if ( !isdefined( death_type ) )
	{
		params.death_type = "gibbed";
		death_type = params.death_type;
	}

	self clean_up_spawned();

	self SetTurretSpinning( false );
	self stopMovementAndSetBrake();

	self vehicle::set_damage_fx_level( 0 );
	self playsound("veh_quadtank_sparks");

	if ( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 1.0 );
	}

	self.turretRotScale = 3;
	self SetTurretTargetRelativeAngles( (0,0,0), 0 );
	self SetTurretTargetRelativeAngles( (0,0,0), 1 );
	self SetTurretTargetRelativeAngles( (0,0,0), 2 );

	self ASMRequestSubstate( "death@stationary" );

	self waittill( "model_swap" ); // give the streamer time to load
	self vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	self vehicle::do_death_dynents();
	self vehicle_death::death_radius_damage();
	
	self waittill( "bodyfall large" );

	// falling damage
	self RadiusDamage( self.origin + (0,0,10), self.radius * 0.8, 150, 60, self, "MOD_CRUSH" );

	//BadPlace_Box( "", 0, self.origin, 50, "neutral" );

	vehicle_ai::waittill_asm_complete( "death@stationary", 3 );

	self thread vehicle_death::CleanUp();
	self vehicle_death::FreeWhenSafe();
}

// ----------------------------------------------
// State: scripted
// ----------------------------------------------
function siegebot_driving( params )
{
	self thread siegebot_player_fireupdate();
	self thread siegebot_kill_on_tilting();

	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();	
}

function siegebot_kill_on_tilting()
{
	self endon( "death" );
	self endon( "exit_vehicle" );

	tileCount = 0;

	while( 1 )
	{
		selfup = AnglesToUp( self.angles );
		worldup = ( 0, 0, 1 );

		if ( VectorDot( selfup, worldup ) < 0.64 ) // angle diff more than 50 degree
		{
			tileCount += 1;
		}
		else
		{
			tileCount = 0;
		}

		if ( tileCount > 20 ) // more than 1 full second
		{
			driver = self GetSeatOccupant( 0 );
			self Kill( self.origin );
		}

		WAIT_SERVER_FRAME;
	}
}

function siegebot_player_fireupdate()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	weapon = self SeatGetWeapon( 2 );
	fireTime = weapon.fireTime;
	driver = self GetSeatOccupant( 0 );

	self thread siegebot_player_aimUpdate();
	
	while( 1 )
	{
		if( driver attackButtonPressed() )
		{
			self FireWeapon( 2 );
			wait fireTime;
		}
		else
		{
			WAIT_SERVER_FRAME;
		}
	}
}

function siegebot_player_aimUpdate()
{
	self endon( "death" );
	self endon( "exit_vehicle" );

	while( 1 )
	{
		self SetGunnerTargetVec( self GetGunnerTargetVec( 0 ), 1 );
		WAIT_SERVER_FRAME;
	}
}
// State: scripted ----------------------------------

// ----------------------------------------------
// State: emped
// ----------------------------------------------
function emped_enter( params )
{
	if ( !isdefined( self.abnormal_status ) )
	{
		self.abnormal_status = spawnStruct();
	}

	self.abnormal_status.emped = true;
	self.abnormal_status.attacker = params.notify_param[1];
	self.abnormal_status.inflictor = params.notify_param[2];

	self vehicle::toggle_emp_fx( true );
}

function emped_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self stopMovementAndSetBrake();
	
	if ( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 1.0 );
	}

	asmState = "damage_2@pain";
	self ASMRequestSubstate( asmState );	
	self vehicle_ai::waittill_asm_complete( asmState, 3 );
	
	self SetBrake( 0 );
	
	self vehicle_ai::evaluate_connections();
}

function emped_exit( params )
{
}

function emped_reenter( params )
{
	return false;
}
// State: emped ----------------------------------

// ----------------------------------------------
// State: pain
// ----------------------------------------------
function pain_toggle( enabled )
{
	self._enablePain = enabled;
}

function pain_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self stopMovementAndSetBrake();
	
	if ( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 1.0 );
	}

	if ( self.newDamageLevel == 3 )
	{
		asmState = "damage_2@pain";
	}
	else
	{
		asmState = "damage_1@pain";
	}

	self ASMRequestSubstate( asmState );	
	self vehicle_ai::waittill_asm_complete( asmState, 1.5 );
	
	self SetBrake( 0 );
	
	self vehicle_ai::evaluate_connections();
}
// State: pain ----------------------------------

// ----------------------------------------------
// State: unaware
// ----------------------------------------------
function state_unaware_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self SetTurretTargetRelativeAngles( (0,90,0), 1 );
	self SetTurretTargetRelativeAngles( (0,90,0), 2 );

	self thread Movement_Thread_Unaware();

	while ( true ) 
	{
		self vehicle_ai::evaluate_connections();
		wait 1;
	}
}

function Movement_Thread_Unaware()
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "end_movement_thread" );
	self endon( "end_movement_thread" );

	while( true )
	{
		self.current_pathto_pos = self GetNextMovePosition_unaware();

		foundpath = self SetVehGoalPos( self.current_pathto_pos, false, true );
		
		if ( foundPath )
		{
			locomotion_start();
			self thread path_update_interrupt();
			self vehicle_ai::waittill_pathing_done();
			self notify( "near_goal" );		// kill path_update_interrupt thread
			self CancelAIMove();
			self ClearVehGoalPos();

			Scan();
		}
		else
		{
			wait 1;
		}

		WAIT_SERVER_FRAME;
	}
}

function GetNextMovePosition_unaware()
{
	if( self.goalforced )
	{
		return self.goalpos;
	}

	minSearchRadius = 500;
	maxSearchRadius = 1500;
	halfHeight = 400;
	spacing = 80;

	queryResult = PositionQuery_Source_Navigation( self.origin, minSearchRadius, maxSearchRadius, halfHeight, spacing, self, spacing );
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );

	forward = AnglesToForward( self.angles );
	foreach ( point in queryResult.data )
	{
		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, 30 ) );

		pointDirection = VectorNormalize( point.origin - self.origin );
		factor = VectorDot( pointDirection, forward );
		if ( factor > 0.7 )
		{
			ADD_POINT_SCORE( point, "directionDiff", 600 );
		}
		else if ( factor > 0 )
		{
			ADD_POINT_SCORE( point, "directionDiff", 0 );
		}
		else if ( factor > -0.5 )
		{
			ADD_POINT_SCORE( point, "directionDiff", -600 );
		}
		else
		{
			ADD_POINT_SCORE( point, "directionDiff", -1200 );
		}
	}

	vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	if( queryResult.data.size == 0 )
		return self.origin;

	return queryResult.data[0].origin;
}

// ----------------------------------------------
// State: jump
// ----------------------------------------------
function clean_up_spawned()
{
	if ( isdefined( self.jump ) && isDefined(self.jump.linkEnt) )
	{
		self.jump.linkEnt Delete();
	}
}
function clean_up_spawnedOnDeath(entToWatch)
{
	self endon("death");
	entToWatch waittill("death");
	self delete();
}


function initJumpStruct()
{
	if ( isdefined( self.jump ) )
	{
		self Unlink();
		self.jump.linkEnt Delete();
		self.jump Delete();
	}

	self.jump = spawnstruct();
	self.jump.linkEnt = Spawn( "script_origin", self.origin );
	self.jump.linkEnt thread clean_up_spawnedOnDeath(self);
	self.jump.in_air = false;
	self.jump.highgrounds = struct::get_array( "balcony_point" );
	self.jump.groundpoints = struct::get_array( "ground_point" );

	//assert( self.jump.highgrounds.size > 0 );
	//assert( self.jump.groundpoints.size > 0 );
}

function state_jump_can_enter( from_state, to_state, connection )
{
	if(IS_TRUE(self.noJumping))
		return false;
	
	return ( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" );
}

function state_jump_enter( params )
{
	goal = params.jumpgoal;

	trace = PhysicsTrace( goal + ( 0, 0, 500 ), goal - ( 0, 0, 10000 ), ( -10, -10, -10 ), ( 10, 10, 10 ), self, PHYSICS_TRACE_MASK_VEHICLE );
	if ( DEBUG_ON )
	{
	/#debugstar( goal, 60000, (0,1,0) ); #/
	/#debugstar( trace[ "position" ], 60000, (0,1,0) ); #/
	/#line(goal, trace[ "position" ], (0,1,0), 1, false, 60000 ); #/
	}
	if ( trace[ "fraction" ] < 1 )
	{
		goal = trace[ "position" ];
	}

	self.jump.goal = goal;

	params.scaleForward = 40;
	params.gravityForce = (0, 0, -6);
	params.upByHeight = 50;
	params.landingState = "land@jump";

	self pain_toggle( false );

	self stopMovementAndSetBrake();
}

function state_jump_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	goal = self.jump.goal;

	self face_target( goal );

	self.jump.linkEnt.origin = self.origin;
	self.jump.linkEnt.angles = self.angles;

	WAIT_SERVER_FRAME;

	self LinkTo( self.jump.linkEnt );

	self.jump.in_air = true;

	if ( DEBUG_ON ) 
	{
	/#debugstar( goal, 60000, (0,1,0) ); #/
	/#debugstar( goal + (0,0,100), 60000, (0,1,0) ); #/
	/#line(goal, goal + (0,0,100), (0,1,0), 1, false, 60000 ); #/
	}

	// calculate distance and forces
	totalDistance = Distance2D(goal, self.jump.linkEnt.origin);
	forward = FLAT_ORIGIN( ((goal - self.jump.linkEnt.origin) / totalDistance) );
	upByDistance = MapFloat( 500, 2000, 46, 52, totalDistance );
	antiGravityByDistance = 0;//MapFloat( 500, 2000, 0, 0.5, totalDistance );

	initVelocityUp = (0,0,1) * ( upByDistance + params.upByHeight );
	initVelocityForward = forward * params.scaleForward * MapFloat( 500, 2000, 0.8, 1, totalDistance );
	velocity = initVelocityUp + initVelocityForward;

	// start jumping
	if ( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 1.0 );
	}

	self ASMRequestSubstate( "inair@jump" );
	self waittill( "engine_startup" );
	self vehicle::impact_fx( self.settings.startupfx1 );
	self waittill( "leave_ground" );
	self vehicle::impact_fx( self.settings.takeofffx1 );

	while( true )
	{
		distanceToGoal = Distance2D(self.jump.linkEnt.origin, goal);

		antiGravityScaleUp = 1.0;//MapFloat( 0, 0.5, 0.6, 0, abs( 0.5 - distanceToGoal / totalDistance ) );
		antiGravityScale = 1.0;//MapFloat( (self.radius * 1.0), (self.radius * 3), 0, 1, distanceToGoal );
		antiGravity = (0,0,0);//antiGravityScale * antiGravityScaleUp * (-params.gravityForce) + (0,0,antiGravityByDistance);
		if ( DEBUG_ON ) /#line(self.jump.linkEnt.origin, self.jump.linkEnt.origin + antiGravity, (0,1,0), 1, false, 60000 ); #/

		velocityForwardScale = MapFloat( (self.radius * 1), (self.radius * 4), 0.2, 1, distanceToGoal );
		velocityForward = initVelocityForward * velocityForwardScale;
		if ( DEBUG_ON ) /#line(self.jump.linkEnt.origin, self.jump.linkEnt.origin + velocityForward, (0,1,0), 1, false, 60000 ); #/

		oldVerticleSpeed = velocity[2];
		velocity = (0,0, velocity[2]);
		velocity += velocityForward + params.gravityForce + antiGravity;

		if ( oldVerticleSpeed > 0 && velocity[2] < 0 )
		{
			self ASMRequestSubstate( "fall@jump" );
		}

		if ( velocity[2] < 0 && self.jump.linkEnt.origin[2] + velocity[2] < goal[2] )
		{
			break;
		}

		heightThreshold = goal[2] + 110;
		oldHeight = self.jump.linkEnt.origin[2];
		self.jump.linkEnt.origin += velocity;

		if ( self.jump.linkEnt.origin[2] < heightThreshold && ( oldHeight > heightThreshold || ( oldVerticleSpeed > 0 && velocity[2] < 0 ) ) )
		{
			self notify( "start_landing" );
			self ASMRequestSubstate( params.landingState );
		}

		if ( DEBUG_ON ) /#debugstar( self.jump.linkEnt.origin, 60000, (1,0,0) ); #/
		WAIT_SERVER_FRAME;
	}

	// landed
	self.jump.linkEnt.origin = FLAT_ORIGIN( self.jump.linkEnt.origin ) + ( 0, 0, goal[2] );
	self notify( "land_crush" );

	// don't damage player, but crush player vehicle
	foreach( player in level.players )
	{
		player._takedamage_old = player.takedamage;
		player.takedamage = false;
	}
	self RadiusDamage( self.origin + ( 0,0,15 ), self.radiusdamageradius, self.radiusdamagemax, self.radiusdamagemin, self, "MOD_EXPLOSIVE" );

	foreach( player in level.players )
	{
		player.takedamage = player._takedamage_old;
		player._takedamage_old = undefined;

		if ( Distance2DSquared( self.origin, player.origin ) < SQR( 200 ) )
		{
			direction = FLAT_ORIGIN( ( player.origin - self.origin ) );
			if ( Abs( direction[0] ) < 0.01 && Abs( direction[1] ) < 0.01 )
			{
				direction = ( RandomFloatRange( 1, 2 ), RandomFloatRange( 1, 2 ), 0 );
			}
			direction = VectorNormalize( direction );
			strength = 700;
			player SetVelocity( player GetVelocity() + direction * strength );

			if ( player.health > 80 )
			{
				player DoDamage( player.health - 70, self.origin, self );
			}
		}
	}

	self vehicle::impact_fx( self.settings.landingfx1 );
	self stopMovementAndSetBrake();

	//rumble for landing from jump
	//self clientfield::increment( "sarah_rumble_on_landing" );

	wait 0.3;

	self Unlink();
	
	WAIT_SERVER_FRAME;

	self.jump.in_air = false;

	self notify ( "jump_finished" );

	vehicle_ai::Cooldown( "jump", JUMP_COOLDOWN );

	self vehicle_ai::waittill_asm_complete( params.landingState, 3 );

	self vehicle_ai::evaluate_connections();
}

function state_jump_exit( params )
{
}

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self thread Movement_Thread();
	self thread Attack_Thread_machinegun();
	self thread Attack_Thread_rocket();
}

function state_combat_exit( params )
{
	self ClearTurretTarget();
	self SetTurretSpinning( false );
}

function locomotion_start()
{
	if( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
	{
		self ASMSetAnimationRate( 0.5 );
	}

	self ASMRequestSubstate( "locomotion@movement" );
}

function GetNextMovePosition_tactical()
{
	if( self.goalforced )
	{
		return self.goalpos;
	}

	maxSearchRadius = 800;
	halfHeight = 400;
	innerSpacing = 50;
	outerSpacing = 60;

	queryResult = PositionQuery_Source_Navigation( self.origin, 0, maxSearchRadius, halfHeight, innerSpacing, self, outerSpacing );
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );

	if( isdefined( self.enemy ) )
	{
		PositionQuery_Filter_Sight( queryResult, self.enemy.origin, self GetEye() - self.origin, self, 0, self.enemy );
		self vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, self.enemy, self.settings.engagementDistMin, self.settings.engagementDistMax );
	}

	foreach ( point in queryResult.data )
	{
		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, 30 ) );

		if( point.disttoorigin2d < 120 )
		{
			ADD_POINT_SCORE( point, "tooCloseToSelf", (120 - point.disttoorigin2d) * -1.5 );
		}

		if( isdefined( self.enemy ) )
		{
			ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );

			if ( !point.visibility )
			{
				ADD_POINT_SCORE( point, "visibility", -600 );
			}
		}
	}

	vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	if( queryResult.data.size == 0 )
		return self.origin;

	return queryResult.data[0].origin;
}

function path_update_interrupt()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );
	
	canSeeEnemyCount = 0;
	
	old_enemy = self.enemy;
	
	startPath = GetTime(); // assume we just started a new path
	old_origin = self.origin;
	move_dist = 300;

	wait 1.5;
	
	while( 1 )
	{
		self SetMaxSpeedScale( 1 );
		self SetMaxAccelerationScale( 1 );
		self SetSpeed( self.settings.defaultMoveSpeed );
		
		if ( isdefined( self.enemy ) )
		{
			selfDistToTarget = Distance2D( self.origin, self.enemy.origin );
		
			farEngagementDist = self.settings.engagementDistMax + 150;
			closeEngagementDist = self.settings.engagementDistMin - 150;
		
			if( self VehCanSee( self.enemy ) )
			{
				self SetLookAtEnt( self.enemy );	// try to keep the basic orientation towards the enemy
				self SetTurretTargetEnt( self.enemy );
			
				// check the distance so we don't trigger a new path when we are already moving
				if( selfDistToTarget < farEngagementDist && selfDistToTarget > closeEngagementDist )
				{	
					canSeeEnemyCount++;

					// Stop if we can see our enemy	for a bit
					if( canSeeEnemyCount > 3 && ( vehicle_ai::TimeSince( startPath ) > 5 || Distance2DSquared( old_origin, self.origin ) > SQR( move_dist ) ) )
					{
						self notify( "near_goal" );
					}
				}
				else
				{
					// too far go fast
					self SetMaxSpeedScale( 2.5 );
					self SetMaxAccelerationScale( 3 );
					self SetSpeed( self.settings.defaultMoveSpeed * 2 );
				}
			}
			else if( (!self VehSeenRecently( self.enemy, 1.5 ) && self VehSeenRecently( self.enemy, 15 )) || selfDistToTarget > farEngagementDist ) // move fast if we just lost sight of our target or we are too far
			{
				self SetMaxSpeedScale( 1.8 );
				self SetMaxAccelerationScale( 2 );
				self SetSpeed( self.settings.defaultMoveSpeed * 1.5 );
			}
		}
		else
		{
			canSeeEnemyCount = 0;
		}

		if ( isdefined( self.enemy ) )
		{
			if( !isdefined( old_enemy ) )
			{
				self notify( "near_goal" );		// new enemy
			}
			else if( self.enemy != old_enemy )
			{
				self notify( "near_goal" );		// new enemy
			}

			if( self VehCanSee( self.enemy ) && distance2dSquared( self.origin, self.enemy.origin ) < SQR( 150 ) && Distance2DSquared( old_origin, self.enemy.origin ) > SQR( 151 ) ) // don't walk pass the player
			{
				self notify( "near_goal" );
			}
		}
		
		wait 0.2;
	}
}

function weapon_doors_state( isOpen, waittime = 0 )
{
	self endon( "death" );
	self notify( "weapon_doors_state" );
	self endon( "weapon_doors_state" );

	if ( isdefined( waittime ) && waittime > 0 )
	{
		wait waittime;
	}

	self vehicle::toggle_ambient_anim_group( 1, isOpen );
}

function Movement_Thread()
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "end_movement_thread" );
	self endon( "end_movement_thread" );

	while ( 1 )
	{
		self.current_pathto_pos = self GetNextMovePosition_tactical();

		if( self.vehicletype === "spawner_enemy_boss_siegebot_zombietron" )
		{
			if ( vehicle_ai::IsCooldownReady( "jump" ) )
			{
				params = SpawnStruct();
				params.jumpgoal = self.current_pathto_pos;
				locomotion_start();
				wait 0.5;
				self vehicle_ai::evaluate_connections( undefined, params );
				wait 0.5;
			}
		}

		foundpath = self SetVehGoalPos( self.current_pathto_pos, false, true );
		
		if ( foundPath )
		{
			if ( isdefined( self.enemy ) && self VehSeenRecently( self.enemy, 1 ) )
			{
				self SetLookAtEnt( self.enemy );
				self SetTurretTargetEnt( self.enemy );
			}
			locomotion_start();
			self thread path_update_interrupt();
			self vehicle_ai::waittill_pathing_done();
			self notify( "near_goal" );		// kill path_update_interrupt thread
			self CancelAIMove();
			self ClearVehGoalPos();
			if ( isdefined( self.enemy ) && self VehSeenRecently( self.enemy, 2 ) )
			{
				self face_target( self.enemy.origin );
			}
		}

		wait 1;

		startAdditionalWaiting = GetTime();
		while ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) && vehicle_ai::TimeSince( startAdditionalWaiting ) < 1.5 )
		{
			wait 0.4;
		}
	}
}

function stopMovementAndSetBrake()
{
	self notify( "end_movement_thread" );
	self notify( "near_goal" );
	self CancelAIMove();
	self ClearVehGoalPos();	
	self ClearTurretTarget();
	self ClearLookAtEnt();
	self SetBrake( 1 );
}

function face_target( position, targetAngleDiff )
{
	if ( !isdefined( targetAngleDiff ) )
	{
		targetAngleDiff = 30;
	}

	v_to_enemy = FLAT_ORIGIN( (position - self.origin) );
	v_to_enemy = VectorNormalize( v_to_enemy );
	goalAngles = VectortoAngles( v_to_enemy );

	angleDiff = AbsAngleClamp180( self.angles[1] - goalAngles[1] );
	if ( angleDiff <= targetAngleDiff )
	{
		return;
	}

	self SetLookAtOrigin( position );
	self SetTurretTargetVec( position );
	self locomotion_start();

	angleAdjustingStart = GetTime();
	while( angleDiff > targetAngleDiff && vehicle_ai::TimeSince( angleAdjustingStart ) < 4 )
	{
		angleDiff = AbsAngleClamp180( self.angles[1] - goalAngles[1] );
		WAIT_SERVER_FRAME;
	}

	self ClearVehGoalPos();
	self ClearLookAtEnt();
	self ClearTurretTarget();
	self CancelAIMove();
}

function Scan()
{
	angles = self GetTagAngles( "tag_barrel" );
	angles = (0,angles[1],0);	// get rid of pitch
	
	rotate = 360;
	
	while( rotate > 0 )
	{
		angles += (0,30,0);
		rotate -= 30;
		forward = AnglesToForward( angles );
		
		aimpos = self.origin + forward * 1000;
		self SetTurretTargetVec( aimpos );
		msg = self util::waittill_any_timeout( 0.5, "turret_on_target" );
		wait 0.1;
		
		if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )	// use VehCanSee, if recently attacked this will return true and not use FOV check
		{
			self SetTurretTargetEnt( self.enemy );
			self SetLookAtEnt( self.enemy );
			self face_target( self.enemy );
			return;
		}
	}
	
	// return the turret to forward
	forward = AnglesToForward( self.angles );
		
	aimpos = self.origin + forward * 1000;
	self SetTurretTargetVec( aimpos );
	msg = self util::waittill_any_timeout( 3.0, "turret_on_target" );
	self ClearTurretTarget();
}

function Attack_Thread_machinegun()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "end_attack_thread" );
	self notify( "end_machinegun_attack_thread" );
	self endon( "end_machinegun_attack_thread" );

	self.turretrotscale = 1 * self.difficulty_scale_up;
	
	spinning = false;

	while( 1 )
	{
		if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
		{
			self SetLookAtEnt( self.enemy );
			self SetTurretTargetEnt( self.enemy );

			if ( !spinning )
			{
				spinning = true;
				self SetTurretSpinning( true );
				wait 0.5;
				continue;
			}

			self SetGunnerTargetEnt( self.enemy, (0,0,0), 0 );
			self SetGunnerTargetEnt( self.enemy, (0,0,0), 1 );
	
			self vehicle_ai::fire_for_time( RandomFloatRange( 0.75, 1.5 ) * self.difficulty_scale_up, 1 );
			
			if( isdefined( self.enemy ) && IsAI( self.enemy ) )
			{
				wait( RandomFloatRange( 0.1, 0.2 ) );
			}
			else
			{
				wait( RandomFloatRange( 0.2, 0.3 ) ) * self.difficulty_scale_down;
			}
		}
		else
		{
			spinning = false;
			self SetTurretSpinning( false );
			self ClearGunnerTarget( 0 );
			self ClearGunnerTarget( 1 );
			wait 0.4;
		}
	}
}

function Attack_Rocket( target )
{		
	if ( isdefined( target ) )
	{
		self SetTurretTargetEnt( target );
		self SetGunnerTargetEnt( target, (0,0,-10), 2 );
		msg = self util::waittill_any_timeout( 1, "turret_on_target" );
		self FireWeapon( 2, target, (0,0,-10) );
		self ClearGunnerTarget( 1 );
	}
}

function Attack_Thread_Rocket()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "end_attack_thread" );
	self notify( "end_rocket_attack_thread" );
	self endon( "end_rocket_attack_thread" );

	vehicle_ai::Cooldown( "rocket", 3 );

	while( 1 )
	{
		if ( isdefined( self.enemy ) && self VehSeenRecently( self.enemy, 3 ) && ( vehicle_ai::IsCooldownReady( "rocket", 1.5 ) ) )
		{
			self SetGunnerTargetEnt( self.enemy, (0,0,0), 0 );
			self SetGunnerTargetEnt( self.enemy, (0,0,-10), 2 );

			self thread weapon_doors_state( true );
			wait 1.5;
			if ( isdefined( self.enemy ) && self VehSeenRecently( self.enemy, 1 ) )
			{
				vehicle_ai::Cooldown( "rocket", 5 );
				Attack_Rocket( self.enemy );
				wait 1;
				if ( isdefined( self.enemy ) )
				{
					Attack_Rocket( self.enemy );
				}
				self thread weapon_doors_state( false, 1 );
			}
			else
			{
				self thread weapon_doors_state( false );
			}
		}
		else
		{
			self ClearGunnerTarget( 0 );
			self ClearGunnerTarget( 1 );
			wait 0.4;
		}
	}
}

function siegebot_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	num_players = GetPlayers().size;
	maxDamage = self.healthdefault * ( 0.40 - 0.02 * num_players );
	if ( sMeansOfDeath !== "MOD_UNKNOWN" && iDamage > maxDamage )
	{
		iDamage = maxDamage;
	}

	if ( vehicle_ai::should_emp( self, weapon, sMeansOfDeath, eInflictor, eAttacker ) )
	{
		minEmpDownTime = 0.8 * self.settings.empdowntime;
		maxEmpDownTime = 1.2 * self.settings.empdowntime;
		self notify ( "emped", RandomFloatRange( minEmpDownTime, maxEmpDownTime ), eAttacker, eInflictor );
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

		driver = self GetSeatOccupant( 0 );
		if ( !isdefined( driver ) ) // no pain for player driving version
		{
			self notify( "pain" );
		}

		vehicle::set_damage_fx_level( self.damageLevel );
	}

	return iDamage;
}


