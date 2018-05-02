#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\shared\weapons\_heatseekingmissile;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#insert scripts\shared\ai\utility.gsh;

#using scripts\shared\turret_shared;

#define AMWS_MAX_TIME_AT_SAME_POSITION				1.0
#define AMWS_CHANGE_POSITION_TOATTACK_TARGET_DELAY	0.5

#define AMWS_MOVE_DIST_MIN							80
#define AMWS_MOVE_DIST_MAX							500
#define AMWS_AWAY_FROM_CHARACTER					200
	
#define AMWS_EVADE_DIST_MIN							120
#define AMWS_EVADE_DIST_MAX							360
#define AMWS_EVADE_HALF_HEIGHT						( AMWS_MOVE_DIST_MAX * 0.5 )
#define AMWS_EVADE_POINT_SPACING_FACTOR				( 1.5 )
#define AMWS_ACCELERATION							VAL( self.settings.default_move_acceleration, 10.0 )

#define AMWS_ENEMY_TOO_CLOSE_DIST					( 0.8 * 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax ) )

#define AMWS_REPATH_RANGE							100

#define WEAPON_REGULAR								"amws_gun_turret"
#define WEAPON_STATIONARY							"amws_gun_turret_stationary"
	
#using_animtree( "generic" );

#namespace amws;

REGISTER_SYSTEM( "amws", &__init__, undefined )

function __init__()
{	
	vehicle::add_main_callback( "amws", &amws_initialize );
}

function amws_initialize()
{
	self UseAnimTree( #animtree );
	
	Target_Set( self, ( 0, 0, 0 ) );

	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	self EnableAimAssist();
	self SetNearGoalNotifyDist( 40 );
	
	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0.574;	//+/- 55 degrees = 110 fov

	self.vehAirCraftCollisionEnabled = true;

	assert( isdefined( self.scriptbundlesettings ) );

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	self.goalRadius = 999999;
	self.goalHeight = 512;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );

	//self.waittime_before_delete = 40;
	self.delete_on_death = false;
	
	self.overrideVehicleDamage = &drone_callback_damage;

	self thread vehicle_ai::nudge_collision();

	self.cobra = false;
	self ASMRequestSubstate( "locomotion@movement" );

	self.variant = "light_weight";
	if( IsSubStr( self.vehicleType, "pamws" ) )
	{
		self.variant = "armored";
	}

	self vehicle_ai::Cooldown( "cobra_up", 10 );

	//disable some cybercom abilities
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}
	
	defaultRole();
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &state_combat_enter;
    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
    self vehicle_ai::get_state_callbacks( "driving" ).update_func = &state_driving_update;
    self vehicle_ai::get_state_callbacks( "emped" ).update_func = &state_emped_update;
    self vehicle_ai::get_state_callbacks( "surge" ).update_func = &state_surge_update;
    self vehicle_ai::get_state_callbacks( "surge" ).exit_func = &state_surge_exit;
    
    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;

	self vehicle_ai::add_state( "stationary",
		&state_stationary_enter,
		&state_stationary_update,
		&state_stationary_exit );

	vehicle_ai::add_interrupt_connection( "stationary",	"scripted",	"enter_scripted" );
	vehicle_ai::add_interrupt_connection( "stationary",	"emped",	"emped" );
	vehicle_ai::add_interrupt_connection( "stationary",	"off",		"shut_off" );
	vehicle_ai::add_interrupt_connection( "stationary",	"driving",	"enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "stationary",	"pain",		"pain" );
	vehicle_ai::add_interrupt_connection( "stationary",	"surge",	"surge" );

	vehicle_ai::add_utility_connection( "stationary", "combat" );
	vehicle_ai::add_utility_connection( "combat", "stationary" );

	self vehicle_ai::StartInitialState( "combat" );
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function state_death_update( params )
{
	self endon( "death" );	

	death_type = vehicle_ai::get_death_type( params );
	if ( !isdefined( death_type ) )
	{
		params.death_type = "gibbed";
		death_type = params.death_type;
	}

	if ( death_type === "suicide_crash" )
	{
		self death_suicide_crash( params );
	}

	self vehicle_ai::defaultstate_death_update( params );
}

function death_suicide_crash( params )
{
	self endon( "death" );	

	goaldir = AnglesToForward( self.angles );
	goalDist = RandomFloatRange( 300, 400 );
	goalpos = self.origin + goaldir * goalDist;
	self SetMaxSpeedScale( 50 * MPH_TO_INCHES_PER_SEC / ( self GetMaxSpeed( true ) ) );
	self SetMaxAccelerationScale( 50 / self GetDefaultAcceleration() );
	self SetSpeed( self.settings.surgespeedmultiplier * self.settings.defaultMoveSpeed );
	self SetVehGoalPos( goalpos, false );
	self util::waittill_any_timeout( 3.5, "near_goal", "veh_collision" );

	self SetMaxSpeedScale( 0.1 );
	self SetSpeed( 0.1 );
	self vehicle_ai::ClearAllMovement();
	self vehicle_ai::ClearAllLookingAndTargeting();
	self.death_type = "gibbed";
}

// ----------------------------------------------
// State: driving
// ----------------------------------------------
function state_driving_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	driver = self GetSeatOccupant( 0 );

	if ( isPlayer( driver ) )
	{
		while ( true )
		{
			driver endon( "disconnect" );

			driver util::waittill_vehicle_move_up_button_pressed();

			if ( self.cobra === false )
			{
				self cobra_raise();
			}
			else
			{
				self cobra_retract();
			}
		}
	}
}

// rise up and turn into a turret
function cobra_raise()
{
	self.cobra = true;
	if ( isdefined( self.settings.cobra_fx_1 ) && isdefined( self.settings.cobra_tag_1 ) )
	{
		PlayFxOnTag( self.settings.cobra_fx_1, self, self.settings.cobra_tag_1 );
	}
	self ASMRequestSubstate( "cobra@stationary" );
	self vehicle_ai::waittill_asm_complete( "cobra@stationary", 4 );
	self laserOn();
}

// retract turret and be mobile again
function cobra_retract()
{
	self.cobra = false;
	self laserOff();
	self notify( "disable_lens_flare" );
	self ASMRequestSubstate( "locomotion@movement" );
	self vehicle_ai::waittill_asm_complete( "locomotion@movement", 4 );
}

// ----------------------------------------------
// State: emped
// ----------------------------------------------
function state_emped_update( params )
{
	self endon ("death");
	self endon ("change_state");

	angles = self GetTagAngles( "tag_turret" );
	self SetTurretTargetRelativeAngles( ( 45, angles[1] - self.angles[1], 0 ), 0 );
	angles = self GetTagAngles( "tag_gunner_turret1" );
	self SetTurretTargetRelativeAngles( ( 45, angles[1] - self.angles[1], 0 ), 1 );

	self vehicle_ai::defaultstate_emped_update( params );
}

// ----------------------------------------------
// State: surge
// ----------------------------------------------
function state_surge_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	self SetMaxSpeedScale( 50 * MPH_TO_INCHES_PER_SEC / ( self GetMaxSpeed( true ) ) );
	self SetMaxAccelerationScale( 50 / self GetDefaultAcceleration() );

	self vehicle_ai::defaultstate_surge_update( params );
}

function state_surge_exit( params )
{
	self SetMaxSpeedScale( 0.1 );
	self SetSpeed( 0.1 );
	self vehicle_ai::ClearAllMovement();
	self vehicle_ai::ClearAllLookingAndTargeting();
}

// ----------------------------------------------
// State: stationary
// ----------------------------------------------
function state_stationary_enter( params )
{
	vehicle_ai::ClearAllLookingAndTargeting();
	vehicle_ai::ClearAllMovement();
	self SetBrake( 1 );
	//self SetVehWeapon( GetWeapon( WEAPON_STATIONARY ) );
}

function state_stationary_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self notify( "stop_rocket_firing_thread" );
	vehicle_ai::ClearAllLookingAndTargeting();
	vehicle_ai::ClearAllMovement();

	wait 1;

	self cobra_raise();

	minTime = 6; // don't retract before this
	maxTime = 12; // retract after this
	transformWhenEnemyClose = ( RandomInt( 100 ) < 25 );
	losePatientTime = 3 + RandomFloat( 2 ); // retract if don't see enemy for this long

	startTime = GetTime();
	vehicle_ai::Cooldown( "rocket", 2 );

	evade_now = false;

	while ( true )
	{
		// /# self vehicle_ai::UpdatePersonalThreatBias_Bots( 800, 2.0 ); #/ // give bots more threat (for testing purposes -- DO NOT CHECK IN active)

		evade_now = ( ( ( self.settings.evade_enemies_locked_on_me === true ) && self.locked_on ) || ( ( self.settings.evade_enemies_locking_on_me === true ) && self.locking_on ) );
		
		if ( vehicle_ai::TimeSince( startTime ) > maxTime || evade_now )
		{
			break;
		}

		if( isdefined( self.enemy ) )
		{
			distSqr = DistanceSquared( self.enemy.origin, self.origin );

			// check get out of stationary state
			if ( vehicle_ai::TimeSince( startTime ) > minTime )
			{
				// enemy is too close, emergency transform
				if ( transformWhenEnemyClose && distSqr < SQR( AMWS_AWAY_FROM_CHARACTER ) )
				{
					break;
				}

				// haven't seen enemy for too long, transform
				if ( !self VehSeenRecently( self.enemy, losePatientTime ) )
				{
					break;
				}
			}

			if ( self VehCanSee( self.enemy ) )
			{
				if( distSqr < SQR( self.settings.engagementDistMax * 3 ) ) 
				{
					self SetTurretTargetEnt( self.enemy, (0,0,-5) );
					self SetGunnerTargetEnt( self.enemy, (0,0,-5), 0 );

					if ( vehicle_ai::IsCooldownReady( "rocket" ) && self.turretontarget && self.gib_rocket !== true )
					{
						self thread FireRocketLauncher( self.enemy );
						vehicle_ai::Cooldown( "rocket", self.settings.rocketcooldown );
					}

					weapon = self SeatGetWeapon( 1 );
					if ( weapon.name=="none" )
						idx = 0;
					else
						idx = 1;

					self vehicle_ai::fire_for_time( 1, idx, self.enemy, 0.5 );
				}
				else
				{
					break;
				}
			}
		}

		wait 0.1;
	}

	self notify( "stop_rocket_firing_thread" );
	vehicle_ai::ClearAllLookingAndTargeting();
	vehicle_ai::ClearAllMovement();

	if ( evade_now )
	{
		self wait_evasion_reaction_time();
	}
	else
	{
		self state_stationary_update_wait( 0.5 );
	}

	self cobra_retract();

	self vehicle_ai::evaluate_connections();
}

function state_stationary_update_wait( wait_time ) // self == sentient
{
	waittill_weapon_lock_or_timeout( wait_time );
}

function state_stationary_exit( params )
{
	//self SetVehWeapon( GetWeapon( WEAPON_REGULAR ) );
	vehicle_ai::ClearAllLookingAndTargeting();
	vehicle_ai::ClearAllMovement();
	self SetBrake( 0 );
	self vehicle_ai::Cooldown( "cobra_up", 10 );
}

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_enter( params )
{
	self thread turretFireUpdate();
}

function is_ai_using_minigun()
{
	return VAL( self.settings.ai_uses_minigun, true );
}

function turretFireUpdate()
{
	weapon = self SeatGetWeapon( 1 );
	if ( weapon.name=="none" )
		return;
	
	self endon( "death" );
	self endon( "change_state" );
	
	self SetOnTargetAngle( 7 );
	self SetOnTargetAngle( 7, 0 );
	
	

	
	while( 1 )
	{
		if ( self.avoid_shooting_owner === true && isdefined( self.owner ) )
		{
			if ( self vehicle_ai::owner_in_line_of_fire() )
			{
				wait 0.5;
				continue;
			}
		}
		
		if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) && DistanceSquared( self.enemy.origin, self.origin ) < SQR( self.settings.engagementDistMax * 3 ) )
		{
			self SetGunnerTargetEnt( self.enemy, (0,0,0), 0 );

			if ( self is_ai_using_minigun() )
			{
				self SetTurretSpinning( true );
			}

			wait 0.05; // allow gunner1ontarget to update before checking

			if ( !self.gunner1ontarget )
			{
				wait 0.5;
			}

			if ( self.gunner1ontarget )
			{
				if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
				{
					self vehicle_ai::fire_for_time( RandomFloatRange( self.settings.burstFireDurationMin, self.settings.burstFireDurationMax ), 1, self.enemy );
				}

				if ( self is_ai_using_minigun() )
				{
					self SetTurretSpinning( false );
				}

				if( isdefined( self.enemy ) && IsAI( self.enemy ) )
				{
					wait( RandomFloatRange( self.settings.burstFireAIDelayMin, self.settings.burstFireAIDelayMax ) );
				}
				else
				{
					wait( RandomFloatRange( self.settings.burstFireDelayMin, self.settings.burstFireDelayMax ) );
				}
			}
			else
			{
				wait 0.5;
			}
		}
		else
		{
			wait 0.4;
		}
	}
}

function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	lastTimeChangePosition = 0;
	self.shouldGotoNewPosition = false;
	self.lastTimeTargetInSight = 0;
	
	heatseekingmissile::InitLockField( self );
	self.lock_evading = 0; // for use with self.locked_on and self.locking_on

	for( ;; )
	{
		if ( self.lock_evading == 0 )
		{
			self SetSpeed( self.settings.defaultMoveSpeed );
			self SetAcceleration( AMWS_ACCELERATION );
		}

		if ( RandomInt( 100 ) < 3 && vehicle_ai::IsCooldownReady( "cobra_up" ) && ( self.lock_evading == 0 ))
		{
			if ( isdefined( self.enemy ) && DistanceSquared( self.enemy.origin, self.origin ) > SQR( AMWS_AWAY_FROM_CHARACTER ) )
			{
				if( DistanceSquared( self.enemy.origin, self.origin ) < SQR( self.settings.engagementDistMax * 2 ) ) 
				{
					self vehicle_ai::evaluate_connections();
				}
			}
		}
		

		// /# self vehicle_ai::UpdatePersonalThreatBias_Bots( 800, 2.0 ); #/ // give bots more threat (for testing purposes -- DO NOT CHECK IN active)
		
		
		// evaluate lock threats to engage them
		if ( self.settings.engage_enemies_locked_on_me === true && self.locked_on )
		{
			self vehicle_ai::UpdatePersonalThreatBias_AttackerLockedOnToMe( VAL( self.settings.enemies_locked_on_me_threat_bias, 5000 ), VAL( self.settings.enemies_locked_on_me_threat_bias_duration, 1.0 ) );
			self.shouldGotoNewPosition = true;
		}
		else if ( self.settings.engage_enemies_locking_on_me === true && self.locking_on )
		{
			self vehicle_ai::UpdatePersonalThreatBias_AttackerLockingOnToMe( VAL( self.settings.enemies_locking_on_me_threat_bias, 2000 ), VAL( self.settings.enemies_locking_on_me_threat_bias_duration, 1.0 ) );
			self.shouldGotoNewPosition = true;
		}
		
		
		// evalate lock threats for evading
		self.lock_evading = 0;
		if ( self.settings.evade_enemies_locked_on_me === true )
		{
			self.lock_evading |= self.locked_on;
		}
		if ( self.settings.evade_enemies_locking_on_me === true )
		{
			self.lock_evading |= self.locking_on;
			self.lock_evading |= self.locking_on_hacking;
		}
		
		
		if ( IS_TRUE( self.inpain ) )
		{
			wait 0.1;
		}
		else if ( !IsDefined( self.enemy ) )
		{
			should_slow_down_at_goal = true;
			
			if ( self.lock_evading )
			{
				self.current_pathto_pos = GetNextMovePosition_evasive( self.lock_evading );
				should_slow_down_at_goal = false;
			}
			else
			{
				self.current_pathto_pos = GetNextMovePosition_wander();
			}

			if ( IsDefined( self.current_pathto_pos ) )
			{
				if ( self SetVehGoalPos( self.current_pathto_pos, should_slow_down_at_goal, true ) )
				{
					self thread path_update_interrupt_by_attacker();
					self thread path_update_interrupt();
					self vehicle_ai::waittill_pathing_done();
					self notify( "amws_end_interrupt_watch" );
					self playsound ("veh_amws_scan");
				}
			}
			
			self state_combat_update_wait( 0.5 );
		}
		else
		{
			self SetTurretTargetEnt( self.enemy );

			if ( self vehCanSee( self.enemy ) )
			{
				self.lastTimeTargetInSight = GetTime();
			}
			
			if ( self.shouldGotoNewPosition == false )
			{
				if ( GetTime() > lastTimeChangePosition + 1000 * AMWS_MAX_TIME_AT_SAME_POSITION )
				{
					self.shouldGotoNewPosition = true;
				}
				else if ( GetTime() > self.lastTimeTargetInSight + 1000 * AMWS_CHANGE_POSITION_TOATTACK_TARGET_DELAY )
				{
					self.shouldGotoNewPosition = true;
				}
			}

			if ( self.shouldGotoNewPosition )
			{
				should_slow_down_at_goal = true;
				
				if ( self.lock_evading )
				{
					self.current_pathto_pos = GetNextMovePosition_evasive( self.lock_evading );
					should_slow_down_at_goal = false;
				}
				else
				{
					self.current_pathto_pos = GetNextMovePosition_tactical( self.enemy );
				}


				if ( IsDefined( self.current_pathto_pos ) )
				{
					if ( self SetVehGoalPos( self.current_pathto_pos, should_slow_down_at_goal, true ) )
					{
						self thread path_update_interrupt_by_attacker();
						self thread path_update_interrupt();
						self vehicle_ai::waittill_pathing_done();
						self notify( "amws_end_interrupt_watch" );
					}

					if ( isdefined( self.enemy ) && vehicle_ai::IsCooldownReady( "rocket", 0.5 ) && self VehCanSee( self.enemy ) && self.gib_rocket !== true )
					{
						self thread aim_and_fire_rocket_launcher( 0.4 ); // call as thread to prevent blocking movement while aiming rockets
					}

					lastTimeChangePosition = GetTime();
					self.shouldGotoNewPosition = false;
				}
			}

			self state_combat_update_wait( 0.5 );
		}
	}
}

function aim_and_fire_rocket_launcher( aim_time ) // self == amws
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "stop_rocket_firing_thread" );
	self endon( "stop_rocket_firing_thread" );

	if ( !self.turretontarget )
	{
		wait aim_time;
	}

	if ( isdefined( self.enemy ) && self.turretontarget )
	{
		vehicle_ai::Cooldown( "rocket", self.settings.rocketcooldown );
		self thread FireRocketLauncher( self.enemy );
	}
}

function state_combat_update_wait( wait_time ) // self == sentient
{
	self waittill_weapon_lock_or_timeout( wait_time );
}

function waittill_weapon_lock_or_timeout( wait_time ) // self == sentient
{
	if ( self.lock_evade_now === true )
	{
		perform_evasion_reaction_wait = true;
	}
	else
	{
		locked_on_notify = undefined;
		locking_on_notify = undefined;
		
		reacting_to_locks = ( self.settings.evade_enemies_locked_on_me === true ) || ( self.settings.engage_enemies_locked_on_me === true );
		reacting_to_locking = ( self.settings.evade_enemies_locking_on_me === true ) || ( self.settings.engage_enemies_locking_on_me === true );
		
		previous_locked_on_to_me = self.locked_on;
		previous_locking_on_to_me = self.locking_on;
		
		if ( reacting_to_locks )
		{
			locked_on_notify = "missle_lock";
		}
		
		if ( reacting_to_locking )
		{
			locking_on_notify = "locking on";
		}

		self util::waittill_any_timeout( wait_time, "damage", locking_on_notify, locked_on_notify );
	
		locked_on_to_me_just_changed = previous_locked_on_to_me != self.locked_on && self.locked_on;
		locking_on_to_me_just_changed = previous_locking_on_to_me != self.locking_on && self.locking_on;
		
		perform_evasion_reaction_wait = ( ( reacting_to_locks && locked_on_to_me_just_changed ) || ( reacting_to_locking && locking_on_to_me_just_changed ) );
	}

	// perform evasion reaction time if need be	
	if ( perform_evasion_reaction_wait )
		self wait_evasion_reaction_time();
}

function wait_evasion_reaction_time() // self == vehicle with setting
{
	wait RandomFloatRange( VAL( self.settings.enemy_evasion_reaction_time_min, 0.1 ), VAL( self.settings.enemy_evasion_reaction_time_max, 0.2 ) );
}

function FireRocketLauncher( enemy )
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "stop_rocket_firing_thread" );
	self endon( "stop_rocket_firing_thread" );

	if ( isdefined( enemy ) )
	{
		self SetTurretTargetEnt( enemy );
		self util::waittill_any_timeout( 1, "turret_on_target" );

		if ( self.variant == "armored" )
		{
			vehicle_ai::fire_for_rounds( 1, 0, enemy );
		}
		else
		{
			vehicle_ai::fire_for_rounds( 2, 0, enemy );
		}
	}
}

function GetNextMovePosition_wander() // no self.enemy
{
	if( self.goalforced )
	{
		return self.goalpos;
	}
	
	queryMultiplier = 1.5;

	queryResult = PositionQuery_Source_Navigation( self.origin, AMWS_MOVE_DIST_MIN, AMWS_MOVE_DIST_MAX * queryMultiplier, 0.5 * AMWS_MOVE_DIST_MAX, 3 * self.radius * queryMultiplier, self, self.radius * queryMultiplier );	
	if ( queryResult.data.size == 0 )
	{
		// try to move a little bit away since we couldn't find any points in the first position query
		queryResult = PositionQuery_Source_Navigation( self.origin, 36, 120, 240, self.radius, self );
	}

	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	PositionQuery_Filter_InClaimedLocation( queryResult, self );

	best_point = undefined;
	best_score = -999999;

	foreach ( point in queryResult.data )
	{
		randomScore = randomFloatRange( 0, 100 );
		distToOriginScore = point.distToOrigin2D * 0.2;

		if( point.inClaimedLocation )
		{
			point.score -= 500;
		}

		point.score += randomScore + distToOriginScore;
		
		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}
	
	/# self.debug_ai_move_to_points_considered = queryResult.data; #/

	if( !isdefined( best_point ) )
	{
		/# self.debug_ai_movement_type = "wander ( 0 / " + queryResult.data.size + " )"; #/
		/# self.debug_ai_move_to_point = undefined; #/
		return undefined;
	}

	/# self.debug_ai_movement_type = "wander - " + queryResult.data.size; #/
	/# self.debug_ai_move_to_point = best_point.origin; #/
	return best_point.origin;
}

function GetNextMovePosition_evasive( client_flags )
{
	assert( isdefined( client_flags ) );

	self SetSpeed( self.settings.defaultMoveSpeed * VAL( self.settings.lock_evade_speed_boost, 2.0 ) );
	self SetAcceleration( AMWS_ACCELERATION * VAL( self.settings.lock_evade_acceleration_boost, 2.0 ) );

	// query points to where to evade
	queryResult = PositionQuery_Source_Navigation( self.origin,
	         			VAL( self.settings.lock_evade_dist_min, AMWS_EVADE_DIST_MIN ),
	         			VAL( self.settings.lock_evade_dist_max, AMWS_EVADE_DIST_MAX ), 
	         			math::clamp( VAL( self.settings.lock_evade_dist_half_height, AMWS_EVADE_HALF_HEIGHT ), 0.1, 99000 ),
	         			VAL( self.settings.lock_evade_point_spacing_factor, AMWS_EVADE_POINT_SPACING_FACTOR ) * self.radius,
	         			self );
	
	// initial filter
	PositionQuery_Filter_InClaimedLocation( queryResult, self );
	//note: goalpos related filters intentionally left out as the amws is trying to evade getting killed by a rocket

	// process claimed location score
	foreach ( point in queryResult.data )
	{
		if( point.inClaimedLocation )
		{
			ADD_POINT_SCORE( point, "inClaimedLocation", -500 );
		}
	}

	remaining_lock_threats_to_evaluate = 3; // used as iteration cap

	remaining_flags_to_process = client_flags;
	for ( i = 0; remaining_flags_to_process && remaining_lock_threats_to_evaluate > 0 && i < level.players.size; i++ )
	{
		attacker = level.players[ i ];
		if ( isdefined( attacker ) )
		{
			client_flag = ( 1 << attacker getEntityNumber() );
			if ( client_flag & remaining_flags_to_process )
			{
				// filter directness relative to lock threat
				PositionQuery_Filter_Directness( queryResult, self.origin, attacker.origin );
				
				// update score based on directness
				foreach ( point in queryResult.data )
				{
					abs_directness = Abs( point.directness );
					if( abs_directness < 0.2 )
					{
						ADD_POINT_SCORE( point, "evading_directness", 200 );
					}
					else if ( abs_directness > VAL( self.settings.lock_evade_enemy_line_of_sight_directness, 0.9 ) )
					{
						ADD_POINT_SCORE( point, "evading_directness_line_of_sight", -101 );
					}
				}

				// update for next threat
				remaining_flags_to_process &= ~client_flag;
				remaining_lock_threats_to_evaluate--;
			}
		}
	}

	// give a point "ahead" of the amws more points
	PositionQuery_Filter_Directness( queryResult, self.origin, self.origin + ( AnglesToForward( self.angles ) * AMWS_EVADE_DIST_MAX ) );
	foreach ( point in queryResult.data )
	{
		if( point.directness > 0.5 )
		{
			ADD_POINT_SCORE( point, "prefer forward motion", 105 );
		}
	}

	// score points
	best_point = undefined;
	best_score = -999999;
	
	foreach ( point in queryResult.data )
	{
		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}

	self.lock_evade_now = false;

	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/# self.debug_ai_move_to_points_considered = queryResult.data; #/

	if( !isdefined( best_point ) )
	{
		/# self.debug_ai_movement_type = "evasive ( 0 / " + queryResult.data.size + " )"; #/
		/# self.debug_ai_move_to_point = undefined; #/
		return undefined;
	}

	/# self.debug_ai_movement_type = "evasive - " + queryResult.data.size; #/
	/# self.debug_ai_move_to_point = best_point.origin; #/
	return best_point.origin;
}

function GetNextMovePosition_tactical( enemy )
{
	if( self.goalforced )
	{
		return self.goalpos;
	}
	
	// distance based multipliers
	selfDistToTarget = Distance2D( self.origin, enemy.origin );

	goodDist = 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax );

	tooCloseDist = AMWS_ENEMY_TOO_CLOSE_DIST;
	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToTarget );
	preferedDirectness = 0;
	if ( selfDistToTarget > goodDist )
	{
		preferedDirectness = MapFloat( closeDist, farDist, 0, 1, selfDistToTarget );
	}
	else
	{
		preferedDirectness = MapFloat( tooCloseDist * 0.4, tooCloseDist, -1, -0.6, selfDistToTarget );
	}

	preferedDistAwayFromOrigin = 300;
	randomness = 30;

	// query
	queryResult = PositionQuery_Source_Navigation( self.origin, AMWS_MOVE_DIST_MIN, AMWS_MOVE_DIST_MAX * queryMultiplier, 0.5 * AMWS_MOVE_DIST_MAX, 2 * self.radius * queryMultiplier, self, 1 * self.radius * queryMultiplier );

	// filter
	PositionQuery_Filter_Directness( queryResult, self.origin, enemy.origin );
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	PositionQuery_Filter_InClaimedLocation( queryResult, self );
	vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, enemy, self.settings.engagementDistMin, self.settings.engagementDistMax );
	
	if ( isdefined( self.avoidEntities ) && isdefined( self.avoidEntitiesDistance ) )
	{
		vehicle_ai::PositionQuery_Filter_DistAwayFromTarget( queryResult, self.avoidEntities, self.avoidEntitiesDistance, -500 );
	}

	// score points
	best_point = undefined;
	best_score = -999999;

	foreach ( point in queryResult.data )
	{
		// directness
		diffToPreferedDirectness = abs( point.directness - preferedDirectness );
		directnessScore = MapFloat( 0, 1, 100, 0, diffToPreferedDirectness );
		if ( diffToPreferedDirectness > 0.2 )
		{
			directnessScore -= 200;
		}
		ADD_POINT_SCORE( point, "directnessRaw", point.directness );
		ADD_POINT_SCORE( point, "directness", directnessScore );

		// distance from origin
		ADD_POINT_SCORE( point, "distToOrigin", MapFloat( 0, preferedDistAwayFromOrigin, 0, 100, point.distToOrigin2D ) );

		// distance to target
		targetDistScore = 0;
		if ( point.targetDist < tooCloseDist )
		{
			targetDistScore -= 200;
		}

		if( point.inClaimedLocation )
		{
			ADD_POINT_SCORE( point, "inClaimedLocation", -500 );
		}

		ADD_POINT_SCORE( point, "distToTarget", targetDistScore );

		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, randomness ) );

		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}
	
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/# self.debug_ai_move_to_points_considered = queryResult.data; #/

	if( !isdefined( best_point ) )
	{
		/# self.debug_ai_movement_type = "tactical ( 0 / " + queryResult.data.size + " )"; #/
		/# self.debug_ai_move_to_point = undefined; #/
		return undefined;
	}

/#
	if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
	{
		recordLine( self.origin, best_point.origin, (0.3,1,0) );
		recordLine( self.origin, enemy.origin, (1,0,0.4) );
	}
#/
		
	/# self.debug_ai_movement_type = "tactical - "  + queryResult.data.size; #/
	/# self.debug_ai_move_to_point = best_point.origin; #/

	return best_point.origin;
}

function path_update_interrupt_by_attacker() //self == vehicle
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );
	self endon( "amws_end_interrupt_watch" );
	
	self util::waittill_any( "locking on", "missile_lock", "damage" );
	
	if ( self.locked_on || self.locking_on )
	{
		/# self.debug_ai_move_to_points_considered = []; #/
		/# self.debug_ai_movement_type = "interrupted"; #/
		/# self.debug_ai_move_to_point = undefined; #/

		self ClearVehGoalPos(); // do this to prevent the "stopping" of the vehicle
		
		self.lock_evade_now = true;
	}
	
	self notify( "near_goal" );
}

function path_update_interrupt()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );
	self endon( "amws_end_interrupt_watch" );
	
	wait 1;
	
	while( 1 )
	{
		if( isdefined( self.current_pathto_pos ) )
		{
			if( distance2dSquared( self.current_pathto_pos, self.goalpos ) > SQR( self.goalradius ) )
			{
				wait 0.2;
				self notify( "near_goal" );
			}
		}

		if ( isdefined( self.enemy ) )
		{
			if( self VehCanSee( self.enemy ) && distance2dSquared( self.origin, self.enemy.origin ) < SQR( AMWS_ENEMY_TOO_CLOSE_DIST ) )
			{
				self notify( "near_goal" );
			}

			if ( vehicle_ai::IsCooldownReady( "rocket" ) && vehicle_ai::IsCooldownReady( "rocket_launcher_check" ) )
			{
				vehicle_ai::Cooldown( "rocket_launcher_check", 2.5 );
				self notify( "near_goal" );
			}
		}
		
		wait 0.2;
	}
}

function gib( attacker )
{
	if ( self.gibbed !== true )
	{
		self vehicle::do_gib_dynents();
		self.gibbed = true;
		self.death_type = "suicide_crash";
		self kill( self.origin + (0,0,10), attacker );
	}
}

function drone_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	iDamage = vehicle_ai::shared_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal );

	return iDamage;
}
