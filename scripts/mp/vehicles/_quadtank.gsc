#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\gameobjects_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#insert scripts\shared\ai\utility.gsh;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;

#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_bundles;

#define SCAN_HEIGHT_OFFSET 40
	
#define TURRET_STATE_SCAN_AT_ENEMY 0
#define TURRET_STATE_SCAN_FORWARD 1
#define TURRET_STATE_SCAN_RIGHT 2
#define TURRET_STATE_SCAN_FORWARD2 3
#define TURRET_STATE_SCAN_LEFT 4
#define NUM_TURRET_STATES 5
	
#define DEFAULT_WEAK_SPOT_DAMAGE_LIMIT 600
#define TROPHY_DISABLE_LIMIT 1 //Number of times that a player can destroy the trophy weakspot before it is permanently destroyed
	
#define SPIKE_HIT_LIMIT 5 //Used to limit the number of spikes that can hit a QT before trophy system gets re-enabled
	
#define MELEE_RADIUS 270
#define MELEE_INNER_RADIUS_DAMAGE 400
#define MELEE_OUTER_RADIUS_DAMAGE 400
	
#define ROCKET_LAUNCHER_MIN_DIST				350

#define WEAPON_JAVELIN			"quadtank_main_turret_rocketpods_javelin"
#define WEAPON_STRAIGHT			"quadtank_main_turret_rocketpods_straight"
#define JAVELIN_MIN_USE_DISTANCE 	800  //an actor target must be at least this range from the QT for the QT to use the javelin attack

#define NEAR_GOAL_DIST			50
	
#define WEAKSPOT_BONE_NAME "tag_target_lower"
#precache( "string", WEAKSPOT_BONE_NAME );

#define QUADTANK_BUNDLE "quadtank"
	
#namespace quadtank;

REGISTER_SYSTEM( "quadtank", &__init__, undefined )
	
#using_animtree( "generic" );

function __init__()
{
	vehicle::add_main_callback( "quadtank", &quadtank_initialize );

	clientfield::register( "toplayer", "player_shock_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "quadtank_trophy_state", VERSION_SHIP, 1, "int" ); 
}

function quadtank_initialize() 
{
	self useanimtree( #animtree );
	
	self EnableAimAssist();
	self SetNearGoalNotifyDist( NEAR_GOAL_DIST );
	
	// AI SPECIFIC INITIALIZATION
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();
	
	self.turret_state = TURRET_STATE_SCAN_FORWARD;
	
	self.fovcosine = 0; // +/-90 degrees = 180 fov, err 0 actually means 360 degree view
	self.fovcosinebusy = 0;
	self.maxsightdistsqrd = SQR( 10000 );
	
	self.weakpointobjective = 0;
	self.combatactive = true; //used for weakpoint marker to make sure that objective is not added if tank is off
	self.damage_during_trophy_down = 0;
	self.spike_hits_during_trophy_down = 0;
	self.trophy_disables = 0;
	self.allow_movement = true;
	
	assert( isdefined( self.scriptbundlesettings ) );
	
	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	self.variant = "cannon";
	
	if( IsSubStr( self.vehicleType, "mlrs" ) )
	{
		self.variant = "rocketpod";
	}
	
	self.goalRadius = 9999999;
	self.goalHeight = 512;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );

	self SetSpeed( self.settings.defaultMoveSpeed, 10, 10 );
	self SetMinDesiredTurnYaw( 45 );
	self show_weak_spots( false );
	
	turret::_init_turret( 1 );
	turret::_init_turret( 2 );
	
	turret::set_best_target_func( &_get_best_target_quadtank_side_turret, 1 );
	turret::set_best_target_func( &_get_best_target_quadtank_side_turret, 2 );
	
	self quadtank_update_difficulty();
	
	self quadtank_side_turrets_forward();	
	self.overrideVehicleDamage = &QuadtankCallback_VehicleDamage;

	//disable some cybercom abilities
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}

	self.ignoreFireFly = true;
	self.ignoreDecoy = true;
	self vehicle_ai::InitThreatBias();

	self.disableElectroDamage = true;
	self.disableBurnDamage = true;

	self thread vehicle_ai::target_hijackers();

	self HidePart( "tag_defense_active" );
	
	
	self quadtank_enabletrophy();
	self quadtank_disabletrophy();
	
	killstreak_bundles::register_killstreak_bundle( QUADTANK_BUNDLE );
	self.maxhealth = killstreak_bundles::get_max_health( QUADTANK_BUNDLE );
	self.heatlh = self.maxhealth;
	
	self thread monitor_enter_vehicle();
}

function quadtank_update_difficulty()
{
//	testing out changing the turret parameters based solely upon the number of players, since damage
//	is alread scaled based upon the difficulty of the individual player
//	so, saving out current method until change has been tested
//
//	value = gameskill::get_general_difficulty_level();
//	
//	scale_up = mapfloat( 0, 7, 0.8, 2.0, value );
//	scale_down = mapfloat( 0, 7, 1.0, 0.5, value );
	
	if( isDefined( level.players) )
	{
		value = level.players.size;
	}
	else
	{
		value = 1;
	}
	
	
	scale_up = mapfloat( 1, 4, 1, 1.5, value );
	scale_down = mapfloat( 1, 4, 1.0, 0.75, value );
	
	turret::set_burst_parameters( 1.5, 2.5 * scale_up, 0.25 * scale_down, 0.75 * scale_down, 1 );
	turret::set_burst_parameters( 1.5, 2.5 * scale_up, 0.25 * scale_down, 0.75 * scale_down, 2 );
	
	self.difficulty_scale_up = scale_up;
	self.difficulty_scale_down = scale_down;
}

function defaultRole()
{
	self.state_machine = self vehicle_ai::init_state_machine_for_role( "default" );
	
    self vehicle_ai::get_state_callbacks( "pain" ).update_func = &pain_update;
    self vehicle_ai::get_state_callbacks( "emped" ).update_func = &quadtank_emped;

    self vehicle_ai::get_state_callbacks( "off" ).enter_func = &state_off_enter;
    self vehicle_ai::get_state_callbacks( "off" ).exit_func = &state_off_exit;

    self vehicle_ai::get_state_callbacks( "scripted" ).update_func = &state_scripted_update;
    self vehicle_ai::get_state_callbacks( "driving" ).update_func = &state_driving_update;
    
    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
    self vehicle_ai::get_state_callbacks( "combat" ).exit_func = &state_combat_exit;

    self vehicle_ai::get_state_callbacks( "death" ).update_func = &quadtank_death;

    self vehicle_ai::call_custom_add_state_callbacks();
    
	self vehicle_ai::StartInitialState();
}

// ----------------------------------------------
// State: off
// ----------------------------------------------
function quadtank_off()
{
	self vehicle_ai::set_state( "off" );
	self.combatactive = false;
}

function quadtank_on()
{
	self vehicle_ai::set_state( "combat" );
	self.combatactive = true;
}
	
function state_off_enter( params )
{
	self playsound( "veh_quadtank_power_down" );

	self LaserOff();
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();

	vehicle_ai::TurnOffAllLightsAndLaser();
	vehicle_ai::TurnOffAllAmbientAnims();
	self vehicle::toggle_tread_fx( 0 );
	self vehicle::toggle_sounds( 0 );
	self vehicle::toggle_exhaust_fx( 0 );
	
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	target_vec = target_vec + ( 0, 0, -500 );
	self SetTargetOrigin( target_vec );		
	self set_side_turrets_enabled( false );
	self thread quadtank_disabletrophy();

	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
}

function state_off_exit( params )
{
	self vehicle::lights_on();
	self vehicle::toggle_tread_fx( 1 );
	self vehicle::toggle_sounds( 1 );
	self thread bootup();
	self vehicle::toggle_exhaust_fx( 1 );
	self EnableAimAssist();
}

function bootup()
{
	self endon("death");
	self playsound( "veh_quadtank_power_up" );
	self vehicle_ai::blink_lights_for_time( 1.5 );
	
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	self.turretRotScale = 0.3;
	
	driver = self GetSeatOccupant( 0 );
	if( !isdefined(driver) )
	{
		self SetTargetOrigin( target_vec );
	}
	wait 1;
	
	self.turretRotScale = 1 * self.difficulty_scale_up;
}
// State: off -----------------------------------

// ----------------------------------------------
// State: pain
// ----------------------------------------------
function pain_update( params )
{
	self endon( "change_state" );
	self endon( "death" );
	
	isTrophyDownPain = params.notify_param[0];

	if( isTrophyDownPain === true )
	{
		// trophy system must be going down now
		asmState = "trophy_disabled@stationary";
	}
	else 
	{
		// can only take pain when trophy is down
		asmState = "pain@stationary";
	}
	self ASMRequestSubstate( asmState );
	playsoundatposition ("prj_quad_impact", self.origin);
	
	self CancelAIMove();
	self ClearVehGoalPos();	
	self ClearTurretTarget();
	self SetBrake( 1 );
	
	self vehicle_ai::waittill_asm_complete( asmState, 6 );
	
	self SetBrake( 0 );

	self ASMRequestSubstate( "locomotion@movement" );
	
	driver = self GetSeatOccupant( 0 );
	if( !isdefined( driver ) )
	{
		self vehicle_ai::set_state( "combat" );
	}
	else
	{
		self vehicle_ai::set_state( "driving" );
	}
}
// State: pain ----------------------------------

// ----------------------------------------------
// State: scripted
// ----------------------------------------------
function state_scripted_update( params )
{
	self endon( "death" );
	self endon( "change_state" );
	
	self set_side_turrets_enabled( false );
	self LaserOff();
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();

	self vehicle::toggle_ambient_anim_group( 2, true );
}
// State: scripted ------------------------------

// ----------------------------------------------
// State: driving
// ----------------------------------------------
function state_driving_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	self set_side_turrets_enabled( false );
	self LaserOff();
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();

	self vehicle::toggle_ambient_anim_group( 2, true );

	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self.turretRotScale = 1;
		self DisableAimAssist();
		self thread quadtank_set_team( driver.team );
		self SetBrake( 0 );
		self ASMRequestSubstate( "locomotion@movement" );
		self thread quadtank_player_fireupdate();
		self thread footstep_handler();

		self.trophy_disables = TROPHY_DISABLE_LIMIT - 1;
		self thread quadtank_disabletrophy();
	}
}

function quadtank_exit_vehicle()
{
	self SetGoal( self.origin );
}
// State: driving -------------------------------

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_update( params )
{
	self endon( "death" );
	self endon( "change_state" );

	if ( isalive( self ) )
	{
	}

	if ( isalive( self ) && !trophy_disabled() )
	{
		self thread quadtank_enabletrophy();
	}
	
	if ( self.allow_movement )
	{
		self thread quadtank_movementupdate();
	}
	else
	{
		self SetBrake( 1 );
	}
	
	switch ( self.variant )
	{
	case "cannon":
		vehicle_ai::Cooldown( "main_cannon", 4 ); // don't shoot cannon immediately
		self thread quadtank_weapon_think_cannon();	
		break;
	case "rocketpod":
		self thread Attack_Thread_rocket();
		break;
	}
}

function state_combat_exit( params )
{
	self notify( "end_attack_thread" );
	self notify( "end_movement_thread" );
	self ClearTurretTarget();
	self ClearLookAtEnt();
}
// State: combat --------------------------------

// ----------------------------------------------
// State: death
// ----------------------------------------------
function quadtank_death( params )
{
	self endon( "death" );	
	self endon( "nodeath_thread" );

	//self set_trophy_state( false );
	self quadtank_weakpoint_display( false );
	self remove_repulsor();
	self HidePart( "tag_lidar_null", "", true );
	self vehicle::set_damage_fx_level( 0 );

	// Need to prep the death model
	StreamerModelHint( self.deathmodel, 6 );
	
	if ( !isdefined( self.custom_death_sequence ) )
	{
		playsoundatposition ("prj_quad_impact", self.origin);
		self playsound( "veh_quadtank_power_down" );
		self playsound("veh_quadtank_sparks");
		self ASMRequestSubstate( "death@stationary" );
		self waittill( "explosion_c" );
	}
	else
	{
		self [[self.custom_death_sequence]]();
	}

	if( isdefined( level.disable_thermal ) )
	{
		[[level.disable_thermal]]();
	}

	if( isdefined( self.stun_fx ) )
	{
		self.stun_fx delete();
	}
	
	BadPlace_Box( "", 0, self.origin, 90, "neutral" );
	self vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	self vehicle_death::death_radius_damage();

	vehicle_ai::waittill_asm_complete( "death@stationary", 5 );

	self thread vehicle_death::CleanUp();
	vehicle_death::FreeWhenSafe();
}

// ----------------------------------------------
// State: emped
// ----------------------------------------------
function quadtank_emped( params )
{
	self endon ("death");
	self endon( "change_state" );
	self endon( "emped" );
	
	if( isdefined( self.emped ) )
	{
		// already emped, just return for now.
		return;
	}
	
	self.emped = true;
	PlaySoundAtPosition( "veh_quadtankemp_down", self.origin );
	self.turretRotScale = 0.2;
	if( !isdefined( self.stun_fx) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
		//PlayFXOnTag( level._effect[ "quadtank_stun" ], self.stun_fx, "tag_origin" );
	}
	
	time = params.notify_param[0];
	assert( isdefined( time ) );
	vehicle_ai::Cooldown( "emped_timer", time );

	while( !vehicle_ai::IsCooldownReady( "emped_timer" ) )
	{
		timeLeft = max( vehicle_ai::GetCooldownLeft( "emped_timer" ), 0.5 );
		wait timeLeft;
	}
	
	self.stun_fx delete();
	self.emped = undefined;
	self playsound ("veh_boot_quadtank");

	self vehicle_ai::evaluate_connections();
}

// ----------------------------------------------
// trophy system
// ----------------------------------------------
function trophy_disabled()
{
	if( self.trophy_down === true )
	{
		return true;
	}

	if ( trophy_destroyed() )
	{
		return true;
	}
	
	return false;
}

function trophy_destroyed()
{
	if ( self.trophy_disables >= TROPHY_DISABLE_LIMIT )
	{
		return true;
	}
	return false;
}

function quadtank_disabletrophy()
{
	self endon( "death" );
	self notify( "stop_disabletrophy" );
	self endon( "stop_disabletrophy" );
	self notify( "stop_enabletrophy" );
	
	//set_trophy_state( false );

	if( trophy_disabled() )
		return;
	
	self.trophy_down = true;

	driver = self GetSeatOccupant( 0 );
	curr_state = self vehicle_ai::get_current_state();
	next_state = self vehicle_ai::get_next_state();
	if( !isdefined( driver ) && isdefined( curr_state ) && ( curr_state != "off" ) && isdefined( next_state ) && ( next_state != "off" ) )
	{
		self notify( "pain", true ); // Play a trophy system down animation using the pain state
	}
	
	//Target_Set( self, ( 0, 0, 60 ) );7
	self.targetOffset = ( 0, 0, 60 );
	
	self HidePart( "tag_defense_active" );
	//self HidePart( "tag_target_upper" );
	
	self.attackerAccuracy = 0.5;
	self.damage_during_trophy_down = 0;
	self.spike_hits_during_trophy_down = 0;
	self.trophy_disables += 1;
	
	self quadtank_weakpoint_display( false );
	self remove_repulsor();
	
	driver = self GetSeatOccupant( 0 );

	self set_side_turrets_enabled( false );
	
	if( IsDefined( level.vehicle_defense_cb ) )
	{
    	[[level.vehicle_defense_cb]]( self, false );
	}

	if( trophy_destroyed() )
	{
		self notify("trophy_system_destroyed");
		level notify("trophy_system_destroyed",self);
		self playsound ("wpn_trophy_disable");
		PlayFXOnTag( self.settings.trophydetonationfx, self, "tag_target_lower" );
		self HidePart( "tag_lidar_null", "", true );
		return;
	}

	self notify("trophy_system_disabled");
	level notify("trophy_system_disabled",self);
	self playsound ("wpn_trophy_disable");
	
	self vehicle_ai::Cooldown( "trophy_down", self.settings.trophySystemDownTime );
	while( !self vehicle_ai::IsCooldownReady("trophy_down") || self vehicle_ai::get_current_state() === "off" )
	{
		if ( vehicle_ai::GetCooldownLeft( "trophy_down" ) < 0.5 * self.settings.trophySystemDownTime && ( self.damage_during_trophy_down >= self.settings.trophysystemdisablethreshold ||
			self.spike_hits_during_trophy_down >= SPIKE_HIT_LIMIT ) )
		{
			self vehicle_ai::ClearCooldown( "trophy_down" );
		}

		wait 1;
	}

	// player's trophy don't get back up
	driver = self GetSeatOccupant( 0 );
	if( isdefined( driver ) )
	{
		self.trophy_disables = TROPHY_DISABLE_LIMIT;
	}

	if( !trophy_destroyed() )
	{	
		self thread quadtank_enabletrophy();
	}
}

function quadtank_enabletrophy()
{
	self endon( "death" );
	self notify( "stop_enabletrophy" );
	self endon( "stop_enabletrophy" );

	//set_trophy_state( true );
	time = VAL( self.settings.trophywarmup, 0.1 );
	wait time;
		
	driver = self GetSeatOccupant( 0 );

	self.trophy_down = false;
	self.attackerAccuracy = 1;
	self ShowPart( "tag_defense_active" );
	//self ShowPart( "tag_target_upper" );

	self quadtank_projectile_watcher();
	self thread quadtank_automelee_update();

	if( !isdefined( driver ) )
	{
		self quadtank_weakpoint_display( true );
	}
	else
	{
		self quadtank_weakpoint_display( false );
	}
	
	if ( Target_IsTarget( self ) )
	{
		//Target_Remove( self ); 
	}
	
	if( !isdefined( driver ) )
	{
		self set_side_turrets_enabled( true );
	}
	self.trophy_system_health = self.settings.trophySystemHealth;
	
	if( isDefined( level.players) && level.players.size > 0 )
	{
		num_players_trophy_health_modifier = 0.75;
		
		if( level.players.size == 2) 
		{
			num_players_trophy_health_modifier = 1;	
		}
		if( level.players.size == 3) 
		{
			num_players_trophy_health_modifier = 1.25;	
		}
		if( level.players.size >= 4) 
		{
			num_players_trophy_health_modifier = 1.5;	
		}
		self.trophy_system_health = self.trophy_system_health * num_players_trophy_health_modifier;
	}
	
	if( IsDefined( level.vehicle_defense_cb ) )
	{
    	[[level.vehicle_defense_cb]]( self, true );
	}

	self notify("trophy_system_enabled");
	level notify("trophy_system_enabled",self);
}

// trophy system --------------------------------

function quadtank_side_turrets_forward()
{	
	self SetTurretTargetRelativeAngles( (10, -90, 0), 1 );
	self SetTurretTargetRelativeAngles( (10, 90, 0), 2 );
	self.turretRotScale = 1 * self.difficulty_scale_up;
}

// rotates the turret around until he can see his enemy
function quadtank_turret_scan( scan_forever )
{
	self endon( "death" );
	self endon( "change_state" );
	
	self.turretRotScale = 0.3;

	while( scan_forever || ( !isdefined( self.enemy ) || !(self VehCanSee( self.enemy )) ) )
	{
		if( self.turretontarget && self.turret_state != TURRET_STATE_SCAN_AT_ENEMY )
		{
			self.turret_state++;
			if( self.turret_state >= NUM_TURRET_STATES )
				self.turret_state = TURRET_STATE_SCAN_FORWARD;
		}
		
		switch( self.turret_state )
		{	
			// reserved for taking damage and looking responsive
			case TURRET_STATE_SCAN_AT_ENEMY:
				if( isdefined( self.enemy ) )
				{
					self SetLookAtEnt( self.enemy );
					target_vec = self.enemy.origin + ( 0, 0, SCAN_HEIGHT_OFFSET );
					self SetTargetOrigin( target_vec );		
					wait 1.0;
					self ClearLookAtEnt();
					self.turret_state++;
				}	// else fall through to FORWARD
				
			case TURRET_STATE_SCAN_FORWARD:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1], 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_RIGHT:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1] + 30, 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_FORWARD2:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1], 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_LEFT:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1] - 30, 0 ) ) * 1000;
				break;
		}

		target_vec = target_vec + ( 0, 0, SCAN_HEIGHT_OFFSET );
		self SetTargetOrigin( target_vec );		
		
		wait 0.2;
	}
}

function set_side_turrets_enabled( on )
{
	if( on )
	{
		turret::enable( 1, false );
		turret::enable( 2, false );
	}
	else
	{
		turret::disable( 1 );
		turret::disable( 2 );
	}
}

function show_weak_spots( show )	// vents on the sides that are exposed when firing the main gun
{
	if( show )
	{
		self vehicle::toggle_exhaust_fx( 1 );
	}
	else
	{
		self vehicle::toggle_exhaust_fx( 0 );
	}
}

function set_detonation_time( target )
{
	self endon( "change_state" );

	self playsound("veh_quadtank_cannon_charge");
	
	self waittill( "weapon_fired", proj );
	
	self thread railgun_sound(proj);
	
	if( isdefined( target ) && isdefined( proj ) )
	{	
		vel = proj GetVelocity();
		
		proj_speed = length( vel );
		
		dist = Distance( proj.origin, target.origin ) + RandomFloatRange( 0, 40 );
		
		time_to_enemy = dist / proj_speed;
		
		proj ResetMissileDetonationTime( time_to_enemy );
	}
}

function quadtank_weapon_think_cannon()
{
	self endon( "death" );
	self endon( "change_state" );
	
	cant_see_enemy_count = 0;
	
	self set_side_turrets_enabled( true );
	self SetOnTargetAngle( 10 );	// self.turretontarget will be true when the turret is aimed within this rage
	
	self.getreadytofire = undefined;
	
	while ( 1 )
	{
		{
			if ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				self SetTurretTargetEnt( self.enemy );
				self SetLookAtEnt( self.enemy );
			}

			wait 0.2;
			continue;
		}

		if ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
		{
			self.turretRotScale = 1 * self.difficulty_scale_up;
			self SetTurretTargetEnt( self.enemy );
			self SetLookAtEnt( self.enemy );
			
			if( cant_see_enemy_count >= 2 )
			{
				wait 0.1;	// let the self.turretontarget have time to update so we don't shoot in a bad direction
				
				// found enemy, react by changing goal positions
				self CancelAIMove();
				self ClearVehGoalPos();
				self notify( "near_goal" );
			}
			cant_see_enemy_count = 0;
			fired = false;
			
			if ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				if( DistanceSquared( self.origin, self.enemy.origin ) > MELEE_RADIUS * MELEE_RADIUS && self.turretontarget )
				{
					v_my_forward = Anglestoforward( self.angles );
					v_to_enemy = self.enemy.origin - self.origin;
					v_to_enemy = VectorNormalize( v_to_enemy );
					dot = VectorDot( v_to_enemy, v_my_forward );
				
					if( dot > 0.707 ) // body is facing within 45' of enemy
					{
						self ASMRequestSubstate( "fire@stationary" );
						self SetTurretTargetEnt( self.enemy );
						self thread set_detonation_time( self.enemy );
						
						if( isDefined( level.players) && level.players.size < 3)
						{
							self set_side_turrets_enabled( false );
						}
						
						self show_weak_spots( true );
						self.getreadytofire = true;
						fired = true;
						
						self CancelAIMove();
						self ClearVehGoalPos();
						self notify( "near_goal" );
						
						self.turretRotScale = 0.7;

						wait 1;
						
						level notify( "sndStopCountdown" );
						
						self vehicle_ai::waittill_asm_complete( "fire@stationary", 6 );
						
						self set_side_turrets_enabled( true );

						self.turretRotScale = 1;
					}
				}
			}
			
			self.getreadytofire = undefined;
			
			if ( isdefined( self.enemy ) )
			{
				self SetTurretTargetEnt( self.enemy );
				self SetLookAtEnt( self.enemy );
			}
			
			if( fired )
			{
				self show_weak_spots( false );
				
				vehicle_ai::Cooldown( "main_cannon", RandomFloatRange( 5, 7.5 ) );
			}
			else
			{
				wait 0.25;
			}
		}
		else
		{	
			cant_see_enemy_count++;
			
			wait 0.5;
			
			if( cant_see_enemy_count > 40 )
			{
				self quadtank_turret_scan( false );
			}
			else if( cant_see_enemy_count > 30 )
			{
				self ClearLookAtEnt();
				self ClearTargetEntity();
			}
			else
			{
				if( isdefined( self.enemy ) )
				{
					self SetTurretTargetEnt( self.enemy );
					self ClearLookAtEnt();
				}
				else
				{
					self ClearLookAtEnt();
					self quadtank_turret_scan( false );
				}
			}
		}
	}
}


function Attack_Thread_rocket()
{
	self endon( "death" );
	self endon( "end_attack_thread" );

	self vehicle::toggle_ambient_anim_group( 2, false ); // close the weapon doors

	while( true )
	{
		useJavelin = false;
		
		if ( isdefined( self.enemy ) )
		{
			self SetTurretTargetEnt( self.enemy );
			self SetLookAtEnt( self.enemy );
		}

		if( isdefined( self.enemy) && vehicle_ai::IsCooldownReady( "javelin_rocket_launcher", 0.5 )  )
		{
			if( isVehicle( self.enemy ) || Distance2DSquared( self.origin, self.enemy.origin) >= SQR( JAVELIN_MIN_USE_DISTANCE ) )
			{
				useJavelin = !self vehseenrecently( self.enemy, 3 ) || ( RandomInt( 100 ) < 3 );
			}
		}

		if ( isdefined( self.enemy ) && vehicle_ai::IsCooldownReady( "rocket_launcher", 0.5 ) )
		{
			if( isDefined( level.players) && level.players.size < 3)
			{
				self set_side_turrets_enabled( false );
			}
			self ClearVehGoalPos();
			self notify( "near_goal" );
			self show_weak_spots( true );
			self vehicle::toggle_ambient_anim_group( 2, true );

			if( !useJavelin )
			{
				self SetVehWeapon( GetWeapon( WEAPON_STRAIGHT ) );
				offset = ( 0, 0, -50 );
				if ( isPlayer( self.enemy ) )
				{
					origin = self.enemy.origin;
					eye = self.enemy GetEye();
					offset = ( 0, 0, origin[2] - eye[2] - 5 );
				}
				vehicle_ai::SetTurretTarget( self.enemy, 0, offset );
			}
			else
			{
				self playsound ("veh_quadtank_mlrs_plant_start");				
				
				self SetVehWeapon( GetWeapon( WEAPON_JAVELIN ) );
		
				vehicle_ai::SetTurretTarget( self.enemy, 0, (0,0,300) );
			}

			wait 1;
			msg = self util::waittill_any_timeout( 2, "turret_on_target", "end_attack_thread" );

			if ( isdefined( self.enemy ) && Distance2DSquared( self.origin, self.enemy.origin ) > SQR( ROCKET_LAUNCHER_MIN_DIST ) )
			{	
				fired = false;
				for( i = 0; i < 4 && isdefined( self.enemy ); i++ )
				{
					if( useJavelin )
					{
						if ( isPlayer( self.enemy ) )
						{
							self thread vehicle_ai::Javelin_LoseTargetAtRightTime( self.enemy );
						}
						self thread javeline_incoming(GetWeapon( WEAPON_JAVELIN ));
					}
					self FireWeapon( 0, self.enemy );
										
					fired = true;
					wait 0.8;
				}

				if ( fired )
				{
					vehicle_ai::Cooldown( "rocket_launcher", randomFloatRange( 8, 10 ) );
					
					if( useJavelin )
					{
						vehicle_ai::Cooldown( "javelin_rocket_launcher", 20 );
					}
				}
			}

			self set_side_turrets_enabled( true );
			self vehicle::toggle_ambient_anim_group( 2, false );			
		}
		wait 1;
	}
}

// self == player
function trigger_player_shock_fx()
{
	if ( !isdefined( self._player_shock_fx_quadtank_melee ) )
	{
		self._player_shock_fx_quadtank_melee = 0;
	}

	self._player_shock_fx_quadtank_melee = !self._player_shock_fx_quadtank_melee;
	self clientfield::set_to_player( "player_shock_fx", self._player_shock_fx_quadtank_melee );
}

function path_update_interrupt()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );

	wait 1;
	
	cantSeeEnemyCount = 0;
	
	while( 1 )
	{
		if( isdefined( self.current_pathto_pos ) )
		{
			if( isdefined( self.enemy ) ) 
			{
				if( distance2dSquared( self.enemy.origin, self.current_pathto_pos ) < 250 * 250 )
				{
					self.move_now = true;
					self notify( "near_goal" );
				}
				
				if( !self VehCanSee( self.enemy ) )
				{
					if( !self vehicle_ai::CanSeeEnemyFromPosition( self.current_pathto_pos, self.enemy, 80 ) )
					{
						cantSeeEnemyCount++;
						if( cantSeeEnemyCount > 5 )
						{
							self.move_now = true;
							self notify( "near_goal" );
						}
					}
				}
			}
			
			if( distance2dSquared( self.current_pathto_pos, self.goalpos ) > self.goalradius * self.goalradius )
			{
				wait 1;
				
				self.move_now = true;
				self notify( "near_goal" );
			}
		}
		
		wait 0.3;
	}
}

function Movement_Thread_Wander()
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "end_movement_thread" );
	self endon( "end_movement_thread" );

	if( self.goalforced )
	{
		return self.goalpos;
	}
	
	minSearchRadius = 0;
	maxSearchRadius = 2000;
	halfHeight = 300;
	innerSpacing = 90;
	outerSpacing = innerSpacing * 2;
	maxGoalTimeout = 15;

	self ASMRequestSubstate( "locomotion@movement" );

	wait 0.5;
	self SetBrake( 0 );

	while ( true )
	{
		self SetSpeed( self.settings.defaultMoveSpeed, 5, 5 );

		PixBeginEvent( "_quadtank::Movement_Thread_Wander" );
		queryResult = PositionQuery_Source_Navigation( self.origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, self, outerSpacing );
		PixEndEvent();

		// filter
		PositionQuery_Filter_DistanceToGoal( queryResult, self );
		vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
		vehicle_ai::PositionQuery_Filter_Random( queryResult, 200, 250 );

		foreach ( point in queryResult.data )
		{
			if( distance2dSquared( self.origin, point.origin ) < 170 * 170 )
			{
				ADD_POINT_SCORE( point, "tooCloseToSelf", -100 );
			}
		}
		self vehicle_ai::PositionQuery_DebugScores( queryResult );

		vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );

		foundpath = false;
		goalPos = self.origin;
		count = queryResult.data.size;
		if( count > 3 )
			count = 3;
		
		for ( i = 0; i < count && !foundpath; i++ )
		{
			goalPos = queryResult.data[i].origin;
			foundpath = self SetVehGoalPos( goalPos, false, true );
		}

		if( foundpath )
		{
	
			self.current_pathto_pos = goalpos;
			self thread path_update_interrupt();
			self ASMRequestSubstate( "locomotion@movement" );
			
			msg = self util::waittill_any_timeout( maxGoalTimeout, "near_goal", "force_goal", "reached_end_node", "goal" );
			self CancelAIMove();
			self ClearVehGoalPos();
			
			if( isdefined( self.move_now ) )
			{
				self.move_now = undefined;
				
				wait 0.1;
			}
			else
			{
				wait 0.5;
			}
		}
		else
		{
			self.current_pathto_pos = undefined;
			
			goalYaw = self GetGoalYaw();
			
			wait 1;
		}
	}
}

function quadtank_movementupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	//if( distance2dSquared( self.origin, self.goalpos ) > 20 * 20 )
	//	self SetVehGoalPos( self.goalpos, true, 2 );
	
	self ASMRequestSubstate( "locomotion@movement" );
	wait 0.5;
	
	self SetBrake( 0 );
	
	while ( self.allow_movement )
	{
		if ( self.getreadytofire !== true )
		{
			goalpos = vehicle_ai::FindNewPosition( 80 );

			if ( isdefined( goalpos ) && ( Distance2DSquared( goalpos, self.origin ) > SQR( NEAR_GOAL_DIST ) || Abs( goalpos[2] - self.origin[2] ) > self.height  ) )
			{
				self SetSpeed( self.settings.defaultMoveSpeed, 5, 5 );
				self SetVehGoalPos( goalpos, false, true );
				self.current_pathto_pos = goalpos;
				self thread path_update_interrupt();
				self ASMRequestSubstate( "locomotion@movement" );
				result = self util::waittill_any_return( "near_goal", "reached_end_node", "force_goal" );
			}
			else
			{
				self notify( "goal" );
			}

			self CancelAIMove();
			self ClearVehGoalPos();

			if ( isdefined( self.move_now ) )
			{
				self.move_now = undefined;

				wait 0.1;
			}
			else
			{
				wait 0.5;
			}
		}
		else
		{
			while ( isdefined( self.getreadytofire ) )
			{
				wait 0.2;
			}
		}

	}
}

function quadtank_player_fireupdate()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	weapon = self SeatGetWeapon( 1 );
	fireTime = weapon.fireTime;
	
	while( 1 )
	{
		self SetGunnerTargetVec( self GetGunnerTargetVec( 0 ), 1 );
		if( self IsGunnerFiring( 0 ) )
		{
			self FireWeapon( 2 );
		}
		wait fireTime;
	}
}

function do_melee( shouldDoDamage, enemy )
{
	if( !isAlive( enemy ) || distanceSquared( enemy.origin, self.origin ) > SQR( MELEE_RADIUS ) )
	{
		return false;
	}

	if ( vehicle_ai::EntityIsArchetype( enemy, "quadtank" ) || vehicle_ai::EntityIsArchetype( enemy, "raps" ) )
	{
		return false;
	}
	
	if ( isPlayer( enemy ) && enemy laststand::player_is_in_laststand() )
	{
		return false;
	}

	self notify ( "play_meleefx" );

	if ( shouldDoDamage )
	{
		// don't damage player, but crush player vehicle
		players = GetPlayers();
		foreach( player in players )
		{
			player._takedamage_old = player.takedamage;
			player.takedamage = false;
		}

		RadiusDamage( self.origin + (0,0,40), MELEE_RADIUS, MELEE_INNER_RADIUS_DAMAGE, MELEE_OUTER_RADIUS_DAMAGE, self );

		foreach( player in players )
		{
			player.takedamage = player._takedamage_old;
			player._takedamage_old = undefined;
		}
	}

	if ( isdefined( enemy ) && isPlayer( enemy ) )
	{
		direction = FLAT_ORIGIN( ( enemy.origin - self.origin ) );
		if ( Abs( direction[0] ) < 0.01 && Abs( direction[1] ) < 0.01 )
		{
			direction = ( RandomFloatRange( 1, 2 ), RandomFloatRange( 1, 2 ), 0 );
		}
		direction = VectorNormalize( direction );
		strength = 1000;
		enemy SetVelocity( enemy GetVelocity() + direction * strength );
		enemy trigger_player_shock_fx();
		enemy DoDamage( 15, self.origin, self );
	}

	self playsound( "veh_quadtank_emp" );

	return true;
}

function quadtank_automelee_update()
{
	self endon( "death" );

	assert( isdefined( self.team ) );

	while( !trophy_disabled() )
	{
		enemies = self GetEnemies();
		
		meleed = false;

		foreach( enemy in enemies )
		{
			if( enemy IsNoTarget() )
			{
				continue;
			}

			meleed = meleed || self do_melee( !meleed, enemy );
			if ( meleed )
			{
				break;
			}
		}

		wait 0.3;
	}
}


function quadtank_destroyturret( index )
{
	turret::disable( index );
	
	if( index == 1 )
	{
		self HidePart( "tag_gunner_barrel1" );
		self HidePart( "tag_gunner_turret1" );
	}
	else if( index == 2 )
	{
		self HidePart( "tag_gunner_barrel2" );
		self HidePart( "tag_gunner_turret2" );
	}
}


function monitor_enter_vehicle()
{
	self endon( "death" );

	while( 1 )
	{
		self waittill( "enter_vehicle", player );

		if ( isdefined( player ) && isPlayer( player ) )
		{
			player vehicle::update_damage_as_occupant( self.maxhealth - self.health, self.maxhealth );
		}
	}
}

function QuadtankCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if ( isdefined( eAttacker ) && ( eAttacker == self || isplayer( eAttacker ) && eAttacker.usingvehicle && eAttacker.viewlockedentity === self ) )
	{
		return 0;
	}

	if ( sMeansOfDeath === "MOD_MELEE" || sMeansOfDeath === "MOD_MELEE_WEAPON_BUTT" || sMeansOfDeath === "MOD_MELEE_ASSASSINATE" || sMeansOfDeath === "MOD_ELECTROCUTED" || sMeansOfDeath === "MOD_CRUSH" || weapon.isEmp )
	{
		return 0;
	}
	
	iDamage = self killstreaks::OnDamagePerWeapon( QUADTANK_BUNDLE, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth * 0.4, undefined, 0, undefined, true, 1.0 );

	
	driver = self GetSeatOccupant( 0 );
	if ( isPlayer( driver ) )
	{
		driver vehicle::update_damage_as_occupant( self.maxhealth - ( self.health - iDamage ), self.maxhealth );
	}	
	
	return iDamage;
}

function quadtank_set_team( team )
{
	self.team = team;
	
	if( !self vehicle_ai::is_instate( "off" ) )
	{
		self vehicle_ai::blink_lights_for_time( 0.5 );
	}
}

function remove_repulsor()
{
	if( isdefined( self.missile_repulsor ) ) 
	{
		missile_deleteattractor( self.missile_repulsor );
		self.missile_repulsor = undefined;
	}
	self notify( "end_repulsor_fx" );
}

function repulsor_fx()
{
	self notify( "end_repulsor_fx" );
	self endon( "end_repulsor_fx" );
	self endon( "death" );
	self endon( "change_state" );
	
	while( 1 )
	{	
		self util::waittill_any( "projectile_applyattractor", "play_meleefx" );
		if ( vehicle_ai::IsCooldownReady("repulsorfx_interval") )
		{
			PlayFxOnTag( self.settings.trophyrepulsefx, self, "tag_body" );

			self vehicle::impact_fx( self.settings.trophyrepulsefx_ground );
			
			vehicle_ai::Cooldown( "repulsorfx_interval", 0.5 );

			self PlaySound( "wpn_quadtank_shield_impact" );			
		}
	}
}
		
function quadtank_projectile_watcher()
{
	if( !isdefined( self.missile_repulsor ) ) 
	{
		self.missile_repulsor = missile_createrepulsorent( self, 40000, self.settings.trophysystemrange, true );
	}
	self thread repulsor_fx();
}

function turn_off_laser_after( time )
{
	self notify( "turn_off_laser_thread" );
	self endon( "turn_off_laser_thread" );
	self endon( "death" );
	
	wait time;
	
	self LaserOff();
}



//self = turret/vehicle
function side_turret_is_target_in_view_score( v_target, n_index )
{
	s_turret = turret::_get_turret_data( n_index );
	
	v_pivot_pos = self GetTagOrigin( s_turret.str_tag_pivot );
	v_angles_to_target = VectorToAngles( v_target - v_pivot_pos );
	
	n_rest_angle_pitch = s_turret.n_rest_angle_pitch + self.angles[0];
	n_rest_angle_yaw = s_turret.n_rest_angle_yaw + self.angles[1];
	
	n_ang_pitch = AngleClamp180( v_angles_to_target[0] - n_rest_angle_pitch );
	n_ang_yaw = AngleClamp180( v_angles_to_target[1] - n_rest_angle_yaw );
	
	b_out_of_range = false;

	if ( n_ang_pitch > 0 )
	{
		if ( n_ang_pitch > s_turret.bottomarc )
		{
			b_out_of_range =  true;
		}
	}
	else
	{
		if ( Abs( n_ang_pitch ) > s_turret.toparc )
		{
			b_out_of_range =  true;
		}
	}
	
	if ( n_ang_yaw > 0 )
	{
		if ( n_ang_yaw > s_turret.leftarc )
		{
			b_out_of_range =  true;
		}
	}
	else
	{
		if ( Abs( n_ang_yaw ) > s_turret.rightarc )
		{
			b_out_of_range =  true;
		}
	}

	if( b_out_of_range )
	{
		return 0.0;
	}
	
	return ( Abs( n_ang_yaw ) / 90 * 800 );
}

function _get_best_target_quadtank_side_turret( a_potential_targets, n_index )
{
	takeEasyOnOneTarget = MapFloat( 0, 4, 800, 0, level.gameskill );

	if ( n_index === 1 )
	{
		other_turret_target = turret::get_target( 2 );
	}
	else if ( n_index === 2 )
	{
		other_turret_target = turret::get_target( 1 );
	}

	e_best_target = undefined;
	f_best_score = 100000;		// lower is better
	
	s_turret = turret::_get_turret_data( n_index );

	foreach( e_target in a_potential_targets )
	{
		f_score = Distance( self.origin, e_target.origin );
		
		b_current_target = turret::is_target( e_target, n_index );
		
		if( b_current_target )
		{
			f_score -= 100;
		}
		
		if( e_target === self.enemy )
		{
			f_score += 300;
		}

		if ( e_target === other_turret_target )
		{
			f_score += ( 100 + takeEasyOnOneTarget );
		}
		
		if( IsSentient( e_target ) && e_target AttackedRecently( self, 2 ) )
		{
			f_score -= 200;
		}
		
		if ( isAlive( self.lockon_owner ) && e_target === self.lockon_owner )
		{
			f_score -= 1000;
		}

		v_offset = turret::_get_default_target_offset( e_target, n_index );
			
		view_score = side_turret_is_target_in_view_score( e_target.origin + v_offset, n_index );
		
		if( view_score != 0.0 )
		{
			f_score += view_score;
			
			b_trace_passed = turret::trace_test( e_target, v_offset, n_index );
						
			if ( b_current_target && !b_trace_passed && !isdefined( s_turret.n_time_lose_sight ) )
			{
				s_turret.n_time_lose_sight = GetTime();
			}
			
			if( b_trace_passed )
			{
				f_score -= 500;
			}
		}
		else if ( b_current_target )
		{	
			s_turret.b_target_out_of_range = true;
			f_score += 5000;
		}
	
		if( f_score < f_best_score )
		{
			f_best_score = f_score;
			e_best_target = e_target;
		}
	}
	
	return e_best_target;
}

function quadtank_weakpoint_display( state )
{
	if( self.displayweakpoint !== state )
	{
		self.displayweakpoint = state;
		
		if( !self.displayweakpoint && self.weakpointobjective === 1 )
		{
			self.weakpointobjective = 0;
		}
		
		player = level.players[0];
		if( self.displayweakpoint && self.combatactive && self.weakpointobjective !== 1 && ( !isdefined( player ) || player.team !== self.team ) )
		{
			self.weakpointobjective = 1;
		}
	}
}

function footstep_handler()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	while( 1 )
	{
		note = self util::waittill_any_return( "footstep_front_left", "footstep_front_right", "footstep_rear_left", "footstep_rear_right" );
		
		switch( note )
		{
			case "footstep_front_left":
			{
				bone = "tag_foot_fx_left_front";
				break;
			}
			case "footstep_front_right":
			{
				bone = "tag_foot_fx_right_front";
				break;
			}
			case "footstep_rear_left":
			{
				bone = "tag_foot_fx_left_back";
				break;
			}
			case "footstep_rear_right":
			{
				bone = "tag_foot_fx_right_back";
				break;
			}
		}
		
		position = self GetTagOrigin( bone ) + (0,0,15);
		
		self RadiusDamage( position, 60, 50, 50, self, "MOD_CRUSH" );
	}
}

function javeline_incoming(projectile)
{
	self endon( "entityshutdown" );
	self endon ("death");

	self waittill( "weapon_fired", projectile );

	distance = 1400;
	alias = "prj_quadtank_javelin_incoming";

	wait(5);

	if(!isdefined( projectile ) )
		return;

	while(isdefined(projectile) && isdefined( projectile.origin ))
	{
		if ( isdefined( self.enemy ) && isdefined( self.enemy.origin ))
		{
			projectileDistance = DistanceSquared( projectile.origin, self.enemy.origin);

			if( projectileDistance <= distance * distance )
			{
				projectile playsound (alias);
				return;
			}
		}

		wait (.2);	
	}
}

function railgun_sound(projectile)
{
	self endon( "entityshutdown" );
	self endon ("death");
	
		self waittill( "weapon_fired", projectile );
		
			distance = 900;
			alais = "wpn_quadtank_railgun_fire_rocket_flux";
			players = level.players;
							
			while(isdefined(projectile) && isdefined( projectile.origin ))
			{
				if ( isdefined( players[0] ) && isdefined( players[0].origin ))
				{
					projectileDistance = DistanceSquared( projectile.origin, players[0].origin);
					
					if( projectileDistance <= distance * distance )
					{
						projectile playsound (alais);
						return;
					}
				}
				
				wait (.2);	
			}	
	
}


