
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\clientfield_shared;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\animation_shared;
#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;

#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\vehicles\_sentinel_drone.gsh;

#using_animtree( "generic" );
	
#namespace sentinel_drone;

REGISTER_SYSTEM( "sentinel_drone", &__init__, undefined )

function __init__()
{	
	clientfield::register( "scriptmover", "sentinel_drone_beam_set_target_id", VERSION_DLC3, 5, "int" );
	clientfield::register( "vehicle", "sentinel_drone_beam_set_source_to_target", VERSION_DLC3, 5, "int" );
	
	clientfield::register( "toplayer", "sentinel_drone_damage_player_fx", VERSION_DLC3, 1, "counter" );
	
	clientfield::register( "vehicle", "sentinel_drone_beam_fire1", VERSION_DLC3, 1, "int" );	//left
	clientfield::register( "vehicle", "sentinel_drone_beam_fire2", VERSION_DLC3, 1, "int" );	//right
	clientfield::register( "vehicle", "sentinel_drone_beam_fire3", VERSION_DLC3, 1, "int" );	//top
	
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_1", VERSION_DLC3, 1, "int" );		//left
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_2", VERSION_DLC3, 1, "int" );		//right
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_3", VERSION_DLC3, 1, "int" );		//top
	
	clientfield::register( "vehicle", "sentinel_drone_face_cut", VERSION_DLC3, 1, "int" );		//face
	
	clientfield::register( "vehicle", "sentinel_drone_beam_charge", VERSION_DLC3, 1, "int" );
	
	clientfield::register( "vehicle", "sentinel_drone_camera_scanner", VERSION_DLC3, 1, "int" );
	
	clientfield::register( "vehicle", "sentinel_drone_camera_destroyed", VERSION_DLC3, 1, "int" );
	
	clientfield::register( "scriptmover", "sentinel_drone_deathfx", VERSION_SHIP, 1, "int" ); //Sentinel Death Effect
	
	vehicle::add_main_callback( "sentinel_drone", &sentinel_drone_initialize );
	
	level._sentinel_Enemy_Detected_Taunts = [];
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_0");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_1");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_2");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_3");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_4");
	
	level._sentinel_System_Critical_Taunts = [];
	ARRAY_ADD(level._sentinel_System_Critical_Taunts, "vox_valk_valkyrie_health_low_0");
	ARRAY_ADD(level._sentinel_System_Critical_Taunts, "vox_valk_valkyrie_health_low_1");
	ARRAY_ADD(level._sentinel_System_Critical_Taunts, "vox_valk_valkyrie_health_low_2");
	ARRAY_ADD(level._sentinel_System_Critical_Taunts, "vox_valk_valkyrie_health_low_3");
	ARRAY_ADD(level._sentinel_System_Critical_Taunts, "vox_valk_valkyrie_health_low_4");
}

// ----------------------------------------------
// Initialization
// ----------------------------------------------

function sentinel_drone_initialize()
{	
	self UseAnimTree( #animtree );
	
	Target_Set( self, ( 0, 0, 0 ) );

	self.health = self.healthdefault;
	
	if( !isDefined( level.sentinelDroneMaxHealth ) )
	{
		level.sentinelDroneMaxHealth = self.health;
	}
	
	self.maxHealth = level.sentinelDroneMaxHealth;
	
	if( !isDefined( level.sentinelDroneHealthArmLeft ))
	{
		level.sentinelDroneHealthArmLeft = SENTINEL_DRONE_DEFAULT_HEALTH_ARM_LEFT;
	}
	if( !isDefined( level.sentinelDroneHealthArmRight ))
	{
		level.sentinelDroneHealthArmRight = SENTINEL_DRONE_DEFAULT_HEALTH_ARM_RIGHT;
	}
	if( !isDefined( level.sentinelDroneHealthArmTop ))
	{
		level.sentinelDroneHealthArmTop = SENTINEL_DRONE_DEFAULT_HEALTH_ARM_TOP;
	}
	if( !isDefined( level.sentinelDroneHealthFace ))
	{
		level.sentinelDroneHealthFace = SENTINEL_DRONE_DEFAULT_HEALTH_FACE;
	}
	if( !isDefined( level.sentinelDroneHealthCamera ))
	{
		level.sentinelDroneHealthCamera = SENTINEL_DRONE_DEFAULT_HEALTH_CAMERA;
	}
	if( !isDefined( level.sentinelDroneHealthCore ))
	{
		level.sentinelDroneHealthCore = SENTINEL_DRONE_DEFAULT_HEALTH_CORE;
	}
	
	self.sentinelDroneHealthArms = [];
	self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_LEFT] = level.sentinelDroneHealthArmLeft;
	self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_RIGHT] = level.sentinelDroneHealthArmRight;
	self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_TOP] = level.sentinelDroneHealthArmTop;
	
	self.sentinelDroneHealthFace = level.sentinelDroneHealthFace;
	self.sentinelDroneHealthCamera = level.sentinelDroneHealthCamera;
	self.sentinelDroneHealthCore = level.sentinelDroneHealthCore;

	////Setup Beam Ssurce and Target script movers

	//Target
	self.beam_fire_target = util::spawn_model("tag_origin", self.position, self.angles);
	
	if(!isdefined(level.sentinel_drone_target_id))
	{
		level.sentinel_drone_target_id = 0;
	}
	
	level.sentinel_drone_target_id = (level.sentinel_drone_target_id + 1) % SENTINEL_DRONE_MAX_INSTANCES;
	
	if(level.sentinel_drone_target_id == 0)
	{
		level.sentinel_drone_target_id = 1;
	}
	
	self.drone_target_id = level.sentinel_drone_target_id;
	
	
	//// AI SPECIFIC INITIALIZATION
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();
	ai::CreateInterfaceForEntity( self );
	
	self vehicle::friendly_fire_shield();

	self EnableAimAssist();
	self SetNearGoalNotifyDist( SENTINEL_DRONE_NEARGOAL_DIST );
	
	self SetVehicleAvoidance( true ); // this is ORCA avoidance

	self SetDrawInfrared( true ); 
	
	self SetHoverParams( 0, 0, 10 );
	
	self.no_gib = 1;
	self.fovcosine = 0;
	self.fovcosinebusy = 0;

	self.vehAirCraftCollisionEnabled = true;

	assert( isdefined( self.scriptbundlesettings ) );

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	self.goalRadius = 999999;
	self.goalHeight = 4000;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	
	self.nextJukeTime = 0;
	self.nextRollTime = 0;
	self.arms_count = 3;
	
	//Set Initial Drone Speeds
	SetDvar("Sentinel_Move_Speed", 25);
	SetDvar("Sentinel_Evade_Speed", 40);
	
	self.should_buff_zombies = false;
	self.disable_flame_fx = true;
	self.no_widows_wine = true;
	
	self.targetPlayerTime = GetTime() + 1000 + RandomInt(1000);
	
	// necessary array creation element for weapon watcher stuff used in the electroball grenade
	self.pers = [];
	self.pers["team"] = self.team;
		
	self.overrideVehicleDamage = &sentinel_CallbackDamage;
	self.overrideVehicleRadiusDamage = &sentinel_drone_CallbackRadiusDamage;
	
	if( !isdefined(level.a_sentinel_drones))
	{
		level.a_sentinel_drones = [];
	}
	
	array::add(level.a_sentinel_drones, self);
	
	if ( isdefined( level.func_custom_sentinel_drone_cleanup_check ) )
	{ 
		self.func_custom_cleanup_check = level.func_custom_sentinel_drone_cleanup_check;
	}
	
	self thread vehicle_ai::nudge_collision();
   
	self thread sentinel_HideInitialBrokenParts();
	
	self thread sentinel_InitBeamLaunchers();
	
	//@Debug
/#	
	self thread sentinel_DebugFX();	
	self thread sentinel_DebugBehavior();
#/

	defaultRole();
}

function sentinel_InitBeamLaunchers()
{
	self endon( "death" );
	
	if(!isdefined(self.target_initialized))
	{
		wait 1;

		//Send Target ID
		self.beam_fire_target clientfield::set("sentinel_drone_beam_set_target_id", self.drone_target_id);
		wait 0.1;
		
		self clientfield::set("sentinel_drone_beam_set_source_to_target", self.drone_target_id);
		
		wait 1;
		
		self.target_initialized = true;
	}
}

function defaultRole()
{	
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;
    
	self vehicle_ai::call_custom_add_state_callbacks();

	vehicle_ai::StartInitialState( "combat" );
}

// ----------------------------------------------
// Target Selection functions
// ----------------------------------------------
function private is_target_valid( target )
{
	if( !isdefined( target ) ) 
	{
		return false; 
	}

	if( !IsAlive( target ) )
	{
		return false; 
	} 
	
	if( IsPlayer( target ) && target.sessionstate == "spectator" )
	{
		return false; 
	}

	if( IsPlayer( target ) && target.sessionstate == "intermission" )
	{
		return false; 
	}
	
	if( IS_TRUE( target.ignoreme ) )
	{
		return false;
	}

	if( target IsNoTarget() )
	{
		return false;
	}
	
	if( IS_TRUE(target.is_elemental_zombie) )
	{
		return false;
	}
	
	if( isdefined(level.is_valid_player_for_sentinel_drone) )
	{
		if( ![[level.is_valid_player_for_sentinel_drone]](target) )
		{
			return false;
		}
	}
	
	if( IS_TRUE(self.should_buff_zombies) && IsPlayer(target) )
	{
		if( isdefined(get_sentinel_nearest_zombie()) )
		{
			return false;
		}
	}
	
	return true; 
}

function get_sentinel_nearest_zombie( b_ignore_elemental = true, b_outside_playable_area = true, radius = 2000 )
{
	if (isdefined(self.sentinel_GetNearestZombie))
	{
		ai_zombie = [[self.sentinel_GetNearestZombie]]( self.origin, b_ignore_elemental, b_outside_playable_area, radius );
		return ai_zombie;
	}
	
	return undefined;
}

function get_sentinel_drone_enemy()
{
	sentinel_drone_targets = GetPlayers();
	least_hunted = sentinel_drone_targets[0];
	
	search_distance_sq = SQR(2000);
	
	for( i = 0; i < sentinel_drone_targets.size; i++ )
	{
		if ( !isdefined( sentinel_drone_targets[i].hunted_by_sentinel ) )
		{
			sentinel_drone_targets[i].hunted_by_sentinel = 0;
		}

		if( !is_target_valid( sentinel_drone_targets[i] ) )
		{
			continue;
		}

		if( !is_target_valid( least_hunted ) )
		{
			least_hunted = sentinel_drone_targets[i];
			continue;
		}
		
		//if the target is near enough we try to split the targetting
		dist_to_target_sq = Distance2DSquared(self.origin, sentinel_drone_targets[i].origin);
		dist_to_least_hunted_sq = Distance2DSquared(self.origin, least_hunted.origin);
		
		if( dist_to_least_hunted_sq >= search_distance_sq && dist_to_target_sq < search_distance_sq )
		{
			least_hunted = sentinel_drone_targets[i];
			continue;
		}
		
		if( sentinel_drone_targets[i].hunted_by_sentinel < least_hunted.hunted_by_sentinel )
		{
			least_hunted = sentinel_drone_targets[i];
		}
	}
	
	// do not return the default first player if he is invalid
	if( !is_target_valid( least_hunted ) )
	{
		return undefined;
	}
	else
	{
		return least_hunted;
	}
}

function set_sentinel_drone_enemy( enemy )
{
	if( isdefined( self.sentinel_droneEnemy ) )
	{
		if( !isdefined( self.sentinel_droneEnemy.hunted_by_sentinel ) )
		{
			self.sentinel_droneEnemy.hunted_by_sentinel = 0;
		}
		
		if( self.sentinel_droneEnemy.hunted_by_sentinel > 0 )
		{
			self.sentinel_droneEnemy.hunted_by_sentinel--;
		}
	}
	
	if( !is_target_valid( enemy ) )
	{
		self.sentinel_droneEnemy = undefined;
		self ClearLookAtEnt();
		self ClearTurretTarget(0);
		return;
	}
	
	self.sentinel_droneEnemy = enemy;
	
	//Play enemy detected taunt
	if(isdefined(self.skip_first_taunt))
	{
		if(IsPlayer(enemy) )
		{
			sentinel_play_taunt( level._sentinel_Enemy_Detected_Taunts );
		}
	}
	else
	{
		self.skip_first_taunt = true;
	}
	
	if( !isdefined( self.sentinel_droneEnemy.hunted_by_sentinel ) )
	{
		self.sentinel_droneEnemy.hunted_by_sentinel = 0;
	}
	self.sentinel_droneEnemy.hunted_by_sentinel++;
	self SetLookAtEnt( self.sentinel_droneEnemy );
	self SetTurretTargetEnt( self.sentinel_droneEnemy );
}

function private sentinel_drone_target_selection()
{
	self endon( "change_state" );
	self endon( "death" );
	
	for( ;; )
	{
		if ( IS_TRUE( self.ignoreall ) )
		{
			wait 0.5;
			continue;
		}
		
		if( is_target_valid( self.sentinel_droneEnemy ) )
		{
			wait 0.5;
			continue;
		}
		//decide who the enemy should be
		
		if( IS_TRUE(self.should_buff_zombies) )
		{
			target = get_sentinel_nearest_zombie();
			
			if( !isdefined(target) )
			{
				target = get_sentinel_drone_enemy();
			}
		}
		else
		{
			target = get_sentinel_drone_enemy();
		}

		set_sentinel_drone_enemy( target );

		wait 0.5;
	}
}


// ----------------------------------------------
// State: combat
// ----------------------------------------------

function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	self.lastTimeTargetInSight = 0;
	self.nextJukeTime= 0;
	
	wait 0.3;
	
	if ( IsDefined( self.owner ) && IsDefined( self.owner.enemy ) )
	{
		self.sentinel_droneEnemy = self.owner.enemy;
	}
	
	thread sentinel_drone_target_selection();
	thread sentinel_NavigateTheWorld();
	thread sentine_RumbleWhenNearPlayer();
	
	while( true )
	{
		if(IS_TRUE(self.playing_intro_anim))
		{
			wait 0.1;
		}
		else if( IS_TRUE(self.is_charging_at_player) )
		{
			wait 0.1; //check to see if I can go to the player directly
		}
		else if ( !isdefined(self.forced_pos) && IS_TRUE( self.shouldRoll ) )
		{	
			if( sentinel_DodgeRoll() )
			{
				thread sentinel_NavigateTheWorld();
			}
		}
		else if ( !IsDefined( self.sentinel_droneEnemy ) )
		{
			//no enemy, do nothing
			wait( 0.25 );
		}
		else
		{
			if(self.arms_count > 0)
			{
				if( RandomInt( 100 ) < SENTINEL_DRONE_FIRE_CHANCE )
				{
					if( self sentinel_FireLogic() )
					{
						thread sentinel_NavigateTheWorld();
					}
				}
			}
		}
		
		wait 0.1;
	}
}


// ----------------------------------------------Intro Logic

function sentinel_Intro()
{	
	sentinel_NavigationStandStill();	
	self.playing_intro_anim = true;
	self ASMRequestSubstate( "intro@default" );
}

function sentinel_IntroCompleted()
{	
	self.playing_intro_anim = false;
	if ( !self vehicle_ai::is_instate( "scripted" ) )
	{
		self thread sentinel_NavigateTheWorld();
	}
}

// ----------------------------------------------Roll Dodge Logic

function sentinel_DodgeRoll()
{
	self endon( "change_state" );
	self endon( "death" );
	
	roll_dir = AnglesToRight( self.angles );
	roll_dir = VectorNormalize( roll_dir );
	
	juke_initial_pause = GetDvarFloat("sentinel_drone_juke_initial_pause_dvar", 0.2);
	juke_speed = GetDvarInt("sentinel_drone_juke_speed_dvar", 300);
	juke_offset = GetDvarInt("sentinel_drone_juke_offset_dvar", 20);
	juke_distance = GetDvarInt("sentinel_drone_juke_distance_dvar", 100);
	juke_distance_max = GetDvarInt("sentinel_drone_juke_distance_max_dvar", 250);
	juke_min_anim_rate = GetDvarFloat("sentinel_drone_juke_min_anim_rate_dvar", 0.9);
	
	can_roll = false;
	
	if( math::cointoss() )
	{
		roll_point = self.origin + VectorScale( roll_dir, juke_distance_max);
		roll_asm_state = "dodge_right@attack";
	}
	else
	{
		roll_dir = VectorScale(roll_dir, -1);
		roll_point = self.origin - VectorScale( roll_dir, -juke_distance_max);
		roll_asm_state = "dodge_left@attack";
	}

	trace = sentinel_Trace(self.origin, roll_point, self, true);
	
	if (isdefined(trace["position"]) )
	{
		if( !IsPointInNavVolume( trace["position"], "navvolume_small" ) )
		{
			trace["position"] = self GetClosestPointOnNavVolume( trace["position"], 100 );
		}
		
		if( isdefined(trace["position"]) )
		{
			if(trace["fraction"] == 1)
			{
				roll_distance = juke_distance_max - juke_offset;
			}
			else
			{
				roll_distance = juke_distance_max * trace["fraction"] - juke_offset;
			}
			
			if(roll_distance >= juke_distance )
			{
				roll_anim_rate =  juke_distance / roll_distance;
				
				if(roll_anim_rate < juke_min_anim_rate)
				{
					roll_anim_rate = juke_min_anim_rate;
				}
				
				roll_speed = (roll_distance / juke_distance) * juke_speed;
				can_roll = true;
			}
		}
	}
	
	self.shouldRoll = false;
	
	if(can_roll)
	{
		sentinel_NavigationStandStill();
		wait 0.1;
		
		self clientfield::set("sentinel_drone_camera_scanner", 1);
		
		self ASMRequestSubstate( roll_asm_state );
		self ASMSetAnimationRate( roll_anim_rate );
		
		wait juke_initial_pause;
		
		self SetSpeed(roll_speed);
		self SetVehVelocity( VectorScale(roll_dir, roll_speed) );
		self SetVehGoalPos( trace["position"], true, false );
		
		/*
		/#
			RecordSphere(trace["position"], 10, GREEN, "script");
			RecordLine(self.origin, trace["position"], WHITE, "script");
			
			Sphere(self.origin, 10, WHITE, 1, false, 10, 120);
			Sphere(trace["position"], 10, GREEN, 1, false, 10, 120);
			Line(self.origin, trace["position"], GREEN, 1, false, 120);
		#/
		*/
		
		wait 1;
		self ASMSetAnimationRate( 1 );
		
		sentinel_NavigationStandStill();
		self clientfield::set("sentinel_drone_camera_scanner", 0);
		wait 0.1;
	}

	if( math::cointoss() )
	{
		self sentinel_FireLogic();
	}
	
	return can_roll;
}

// ----------------------------------------------Navigation Logic

function sentinel_NavigationStandStill()
{
	self endon( "change_state" );
	self endon( "death" );
	
	self notify( "abort_navigation" );
	self notify( "near_goal" );
	
	wait 0.05;
	
	if(GetDvarInt("sentinel_NavigationStandStill_new", 0) > 0)
	{
		self ClearVehGoalPos();
		self SetVehVelocity( ( 0, 0, 0 ) );
		self.vehAirCraftCollisionEnabled = true;
		
		/#
		if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
		{
			RecordSphere(self.origin, 30, ORANGE);
		}
		#/
			
		return;	
	}
	
	if(GetDvarInt("sentinel_ClearVehGoalPos", 1) == 1)
	{
		self ClearVehGoalPos();
	}
	
	if(GetDvarInt("sentinel_PathVariableOffsetClear", 1) == 1)
	{
		self PathVariableOffsetClear();
	}
	
	if(GetDvarInt("sentinel_PathFixedOffsetClear", 1) == 1)
	{
		self PathFixedOffsetClear();
	}
	
	if(GetDvarInt("sentinel_ClearSpeed", 1) == 1)
	{
		self SetSpeed( 0 );
		self SetVehVelocity( ( 0, 0, 0 ) );
		self SetPhysAcceleration( ( 0, 0, 0 ) );
		self SetAngularVelocity( ( 0, 0, 0 ) );
	}
	
	self.vehAirCraftCollisionEnabled = true;
	
	/#
		if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
		{
			RecordSphere(self.origin, 30, ORANGE);
		}
	#/
}

function private sentinel_ShouldChangeSentinelPosition()
{
	if( GetTime() > self.nextJukeTime )
	{
		return true;
	}
	
	if( isdefined(self.sentinel_droneEnemy) )
	{
		if(isdefined(self.lastJukeTime))
		{
			if( (GetTime() - self.lastJukeTime) > 3000 )
			{
				speed = self GetSpeed();
				
				if(speed < 1)
				{
					if( !sentinel_IsInsideEngagementDistance( self.origin, self.sentinel_droneEnemy.origin + (0, 0, 48), true) )
					{
						return true;
					}
				}
			}
		}
	}
	
	return false;
}

function private sentinel_changeSentinelPosition()
{
	self.nextJukeTime = 0;
}

function sentinel_NavigateTheWorld()
{
	self endon( "change_state" );
	self endon( "death" );
	self endon( "abort_navigation" );
	
	self notify( "sentinel_NavigateTheWorld" );
	
	self endon( "sentinel_NavigateTheWorld" );
	
	lastTimeChangePosition = 0;
	self.shouldGotoNewPosition = false;
	self.last_failsafe_count = 0;
	
	Sentinel_Move_Speed = GetDvarInt("Sentinel_Move_Speed", 25);
	Sentinel_Evade_Speed = GetDvarInt("Sentinel_Evade_Speed", 40);
	
	self SetSpeed( Sentinel_Move_Speed );
	
	//request movement animations
	self ASMRequestSubstate( "locomotion@movement" );
	
	self.current_pathto_pos = undefined;
	self.next_near_player_check = 0;
	
	b_use_path_finding = true;
	
	while(true)
	{
		current_pathto_pos = undefined;
		b_in_tactical_position = false;
		
		if(IS_TRUE(self.playing_intro_anim))
		{
			wait 0.1;
		}
		else if( self.goalforced )
		{
			returnData = [];
			returnData["origin"] = self GetClosestPointOnNavVolume( self.goalpos, 100 );
			returnData["centerOnNav"] = IsPointInNavVolume( self.origin, "navvolume_small" );
			current_pathto_pos = returnData["origin"];
		}
		else if( isdefined(self.forced_pos) )
		{
			returnData = [];
			returnData["origin"] = self GetClosestPointOnNavVolume( self.forced_pos, 100 );
			returnData["centerOnNav"] = IsPointInNavVolume( self.origin, "navvolume_small" );
			current_pathto_pos = returnData["origin"];
		}
		else if( sentinel_ShouldChangeSentinelPosition() )
		{
			if(IS_TRUE(self.evading_player))
			{
				self.evading_player = false;
				self SetSpeed( Sentinel_Evade_Speed );
			}
			else
			{
				self SetSpeed( Sentinel_Move_Speed );
			}
			
			returnData = sentinel_GetNextMovePositionTactical( self.should_buff_zombies );
			current_pathto_pos = returnData[ "origin" ];
			
			self.lastJukeTime = GetTime();
			self.nextJukeTime = GetTime() + 1000 + RandomInt(4000);
			
			b_in_tactical_position = true;
		}
		else if( GetTime() > self.next_near_player_check && sentinel_IsNearAnotherPlayer(self.origin, 100) )
		{
			self.evading_player = true;
			self.next_near_player_check = GetTime() + 1000;
			self.nextJukeTime = 0;
			self notify( "near_goal" );
		}
		
		is_on_nav_volume = IsPointInNavVolume(self.origin, "navvolume_small");
		
/#
		if( GetDvarInt("sentinel_DebugFX_NoMove", 0) == 1 )
		{
			current_pathto_pos = undefined;
			is_on_nav_volume = true;
		}
#/			
			
		if ( isdefined( current_pathto_pos ) )
		{
			if( isdefined( self.stuckTime ) && IS_TRUE( is_on_nav_volume ) )
			{
				self.stuckTime = undefined;
			}
			
			/#
				if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
				{
					RecordSphere(current_pathto_pos, 8, BLUE);
				}
			#/
			
			/#
			if( GetDvarInt("debug_sentinel_drone_paths") > 0 )
			{
				if(!IsPointInNavVolume(current_pathto_pos, "navvolume_small") )
				{
					recordLine( current_pathto_pos, level.players[0].origin + (0, 0, 48), WHITE );
					RecordSphere(current_pathto_pos, 10, WHITE);
					PrintTopRightln("Target Fail ID: " + self GetEntityNumber(), WHITE);
				}
				
				if(!IS_TRUE(is_on_nav_volume))
				{
					recordLine( self.origin, level.players[0].origin + (0, 0, 48), GREEN );
					RecordSphere(self.origin, 10, GREEN);
					PrintTopRightln("Me Fail ID: " + self GetEntityNumber(), GREEN);
				}
			}
			#/

			if ( self SetVehGoalPos( current_pathto_pos, true, b_use_path_finding ) )
			{
				b_use_path_finding = true;
				
				self.b_in_tactical_position = b_in_tactical_position;
				
				self thread sentinel_PathUpdateInterrupt();
				self vehicle_ai::waittill_pathing_done( 5 );
				current_pathto_pos = undefined;
			}
			else if( IS_TRUE(is_on_nav_volume) )
			{
				/#
				if( GetDvarInt("debug_sentinel_drone_paths") > 0 )
				{
					PrintTopRightln("FAILED TO FIND PATH ID: " + self GetEntityNumber(), RED);
					
					recordLine( current_pathto_pos, level.players[0].origin + (0, 0, 48), RED );
					RecordSphere(current_pathto_pos, 10, RED);
					
					recordLine( self.origin, level.players[0].origin + (0, 0, 48), (1, 0.2, 0.2) );
					RecordSphere(self.origin, 10, RED);
				}
				#/
				
				self sentinel_KillMyself();	
				self.last_failsafe_time = undefined;
			}
		}
		
		if( !IS_TRUE(is_on_nav_volume) )
		{
			if(!isdefined(self.last_failsafe_time))
			{
				self.last_failsafe_time = GetTime();
			}
			
			if( (GetTime() - self.last_failsafe_time) >= 3000)
			{
				self.last_failsafe_count = 0;
			}
			else
			{
				self.last_failsafe_count++;
			}
			
			self.last_failsafe_time = GetTime();
			
			if( self.last_failsafe_count > 25 )
			{
				new_sentinel_pos = self GetClosestPointOnNavVolume( self.origin, 120 );
				
				if(isdefined(new_sentinel_pos))
				{
					dvar_sentinel_getback_to_volume_epsilon = GetDvarInt("dvar_sentinel_getback_to_volume_epsilon", 5);
					if( Distance(self.origin, new_sentinel_pos) < dvar_sentinel_getback_to_volume_epsilon )
					{
						self.origin = new_sentinel_pos;
						
						/#
						if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
						{
							RecordSphere(new_sentinel_pos, 8, RED);
						}
						#/
					}
					else
					{
						self.vehAirCraftCollisionEnabled = false;
						
						/#
						if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
						{
							RecordSphere(new_sentinel_pos, 8, RED);
						}
						#/
							
						if( self SetVehGoalPos( new_sentinel_pos, true, false ) )
						{
							self thread sentinel_PathUpdateInterrupt();
							self vehicle_ai::waittill_pathing_done( 5 );
							current_pathto_pos = undefined;
						}
						
						self.vehAirCraftCollisionEnabled = true;
					}
				}
				else if( self.last_failsafe_count > 100 )
				{
					self sentinel_KillMyself();
				}
			}
		}

		if( !IS_TRUE( is_on_nav_volume ) )
		{
			//not on navmesh, no valid goto points, kill sentinel_drone as failsafe
			if( !isdefined( self.stuckTime ) )
			{
				self.stuckTime = GetTime();
			}
			
			if( GetTime() - self.stuckTime > 15000 )
			{
				self sentinel_KillMyself();
			}
		}
		
		wait 0.1;
	}
}

function sentinel_GetNextMovePositionTactical( b_do_not_chase_enemy ) // has self.sentinel_droneEnemy
{
	self endon( "change_state" );
	self endon( "death" );
	
	// distance based multipliers
	if(isdefined(self.sentinel_droneEnemy))
	{
		selfDistToTarget = Distance2D( self.origin, self.sentinel_droneEnemy.origin );
	}
	else
	{
		selfDistToTarget = 0;
	}

	goodDist = 0.5 * ( sentinel_GetEngagementDistMin() + sentinel_GetEngagementDistMax() );

	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToTarget );
	
	//the preferred height range should be half the max possible difference to not exceed valid heights for points near the goalheight
	preferedHeightRange = 0.5 * ( sentinel_GetEngagementHeightMax() + sentinel_GetEngagementHeightMin() );
	randomness = 20;

	SENTINEL_DRONE_TOO_CLOSE_TO_SELF_DIST_EX = GetDvarInt("SENTINEL_DRONE_TOO_CLOSE_TO_SELF_DIST_EX", 70);
	SENTINEL_DRONE_MOVE_DIST_MAX_EX = GetDvarInt("SENTINEL_DRONE_MOVE_DIST_MAX_EX", 600);
	SENTINEL_DRONE_MOVE_SPACING = GetDvarInt("SENTINEL_DRONE_MOVE_SPACING", 25);
	SENTINEL_DRONE_RADIUS_EX = GetDvarInt("SENTINEL_DRONE_RADIUS_EX", 35);
	SENTINEL_DRONE_HIGHT_EX = GetDvarInt("SENTINEL_DRONE_HIGHT_EX", int(preferedHeightRange));
	
	spacing_multiplier = 1.5;
	query_min_dist = self.settings.engagementDistMin;
	query_max_dist = SENTINEL_DRONE_MOVE_DIST_MAX_EX;
	
	// query
	if(!IS_TRUE(b_do_not_chase_enemy) && isdefined(self.sentinel_droneEnemy) && (GetTime() > self.targetPlayerTime) )
	{
		charge_at_position = self.sentinel_droneEnemy.origin + (0, 0, 48);
		
		if(!IsPointInNavVolume( charge_at_position, "navvolume_small" ))
		{
			closest_point_on_nav_volume = GetDvarInt("closest_point_on_nav_volume", 120);
			charge_at_position = self GetClosestPointOnNavVolume( charge_at_position, closest_point_on_nav_volume );
		}
		
		if(!isdefined(charge_at_position))
		{
			queryResult = PositionQuery_Source_Navigation( self.origin, SENTINEL_DRONE_TOO_CLOSE_TO_SELF_DIST_EX, SENTINEL_DRONE_MOVE_DIST_MAX_EX * queryMultiplier, SENTINEL_DRONE_HIGHT_EX * queryMultiplier, SENTINEL_DRONE_MOVE_SPACING, "navvolume_small", SENTINEL_DRONE_MOVE_SPACING * spacing_multiplier );
		}
		else
		{
			if( sentinel_IsEnemyInNarrowPlace() )
			{
				spacing_multiplier = 1;
				SENTINEL_DRONE_MOVE_SPACING = 15;
				query_min_dist = self.settings.engagementDistMin * GetDvarFloat("sentinel_query_min_dist", 0.2);
				query_max_dist = query_max_dist * 0.5;
			}
			else if(IS_TRUE(self.in_compact_mode) || sentinel_IsEnemyIndoors())
			{
				spacing_multiplier = 1;
				SENTINEL_DRONE_MOVE_SPACING = 15;
				query_min_dist = self.settings.engagementDistMin * GetDvarFloat("sentinel_query_min_dist", 0.5);
			}
			
			queryResult = PositionQuery_Source_Navigation( charge_at_position, query_min_dist, query_max_dist * queryMultiplier, SENTINEL_DRONE_HIGHT_EX * queryMultiplier, SENTINEL_DRONE_MOVE_SPACING, "navvolume_small", SENTINEL_DRONE_MOVE_SPACING * spacing_multiplier );
		}
	}
	else
	{
		queryResult = PositionQuery_Source_Navigation( self.origin, SENTINEL_DRONE_TOO_CLOSE_TO_SELF_DIST_EX, SENTINEL_DRONE_MOVE_DIST_MAX_EX * queryMultiplier, SENTINEL_DRONE_HIGHT_EX * queryMultiplier, SENTINEL_DRONE_MOVE_SPACING, "navvolume_small", SENTINEL_DRONE_MOVE_SPACING * spacing_multiplier );
	}
	
	// filter
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	
	if(isdefined(self.sentinel_droneEnemy))
	{
		if( RandomInt(100) > 15)
		{
			self vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, self.sentinel_droneEnemy, sentinel_GetEngagementDistMin(), sentinel_GetEngagementDistMax() );
		}
		
		goalHeight = self.sentinel_droneEnemy.origin[2] + 0.5 * ( sentinel_GetEngagementHeightMin() + sentinel_GetEngagementHeightMax() );	
		enemy_origin = self.sentinel_droneEnemy.origin + (0, 0, 48);
	}
	else
	{
		goalHeight = self.origin[2] + 0.5 * ( sentinel_GetEngagementHeightMin() + sentinel_GetEngagementHeightMax() );	
		enemy_origin = self.origin;
	}
	
	// score points
	best_point = undefined;
	best_score = undefined;
	trace_count = 0;
	foreach ( point in queryResult.data )
	{
		if( sentinel_IsInsideEngagementDistance( enemy_origin, point.origin ) )
		{
			ADD_POINT_SCORE( point, "insideEngagementDistance", 25 );
		}
		
		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, randomness ) );

		if(isdefined(point.distAwayFromEngagementArea))
		{
			ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );
		}
		
		is_near_another_sentinel = Sentinel_IsNearAnotherSentinel( point.origin, 200 ); //@ToDo move to variable
		
		if(IS_TRUE(is_near_another_sentinel))
		{
			ADD_POINT_SCORE( point, "NearAnotherSentinel", -200 ); //@ToDo move to variable
		}
		
		is_overlap_another_sentinel = Sentinel_IsNearAnotherSentinel( point.origin, 100 ); //@ToDo move to variable
		
		if(IS_TRUE(is_overlap_another_sentinel))
		{
			ADD_POINT_SCORE( point, "OverlapAnotherSentinel", -2000 ); //@ToDo move to variable
		}
		
		is_near_another_player = sentinel_IsNearAnotherPlayer(point.origin, 150); //@ToDo move to variable
		
		if(IS_TRUE(is_near_another_player))
		{
			ADD_POINT_SCORE( point, "NearAnotherPlayer", -200 ); //@ToDo move to variable
		}
		
		// height
		distFromPreferredHeight = abs( point.origin[2] - goalHeight );
		if ( distFromPreferredHeight > preferedHeightRange )
		{
			heightScore = (distFromPreferredHeight - preferedHeightRange) * 3;//  MapFloat( 0, 500, 0, 1000, distFromPreferredHeight );
			ADD_POINT_SCORE( point, "height", -heightScore );
		}

		if(!isdefined(best_score))
		{
			best_score = point.score;
			best_point = point;
			
			if( isdefined(self.sentinel_droneEnemy) )
			{
				best_point.visibile = int(BulletTracePassed(point.origin, enemy_origin, false, self, self.sentinel_droneEnemy));
			}
			else
			{
				best_point.visibile = int(BulletTracePassed(point.origin, enemy_origin, false, self));
			}
		}
		else
		{
			if ( point.score > best_score )
			{
				if( isdefined(self.sentinel_droneEnemy) )
				{
					point.visibile = int(BulletTracePassed(point.origin, enemy_origin, false, self, self.sentinel_droneEnemy));
				}
				else
				{
					point.visibile = int(BulletTracePassed(point.origin, enemy_origin, false, self));
				}
				
				if(point.visibile >= best_point.visibile)
				{
					best_score = point.score;
					best_point = point;
				}
			}	
		}
		
	}
	
	//do not get too close to other sentinels
	if( isdefined( best_point) )
	{
		if( best_point.score < -1000)
		{
			best_point = undefined;
		}
	}
	
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/#
	if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
	{
		if(isdefined(best_point) )
		{
			recordLine( self.origin, best_point.origin, (0.3,1,0) );
		}
		
		if(isdefined(self.sentinel_droneEnemy))
		{
			recordLine( self.origin, self.sentinel_droneEnemy.origin, (1,0,0.4) );
		}
	}
#/
	returnData = [];
	returnData[ "origin" ] = ( ( IsDefined( best_point ) ) ? best_point.origin : undefined );
	returnData[ "centerOnNav" ] = queryResult.centerOnNav;
	return returnData;
}

function sentinel_ChargeAtPlayerNavigation( b_charge_at_player, time_out, charge_at_position )
{
	self endon( "change_state" );
	self endon( "death" );
	
	if( isdefined(time_out) )
	{
		max_charge_time = GetTime() + time_out;
	}
	
	if( !isdefined(charge_at_position) )
	{
		if( IS_TRUE(b_charge_at_player) )
		{
			charge_at_position = self.sentinel_droneEnemy.origin + (0, 0, 48);
		}
		else
		{
			sentinel_dir = AnglesToForward(self.angles);
			charge_at_position = self.origin + sentinel_dir * Length( self.sentinel_droneEnemy.origin - self.origin);
			charge_at_position = ( charge_at_position[0], charge_at_position[1], self.sentinel_droneEnemy.origin[2] );
		}
	}
	
	charge_at_dir = VectorNormalize(charge_at_position - self.origin);
	charge_at_position = self.origin + charge_at_dir * SENTINEL_DRONE_BEAM_MAX_LENGTH;
	
	self ClearLookAtEnt();
	self SetVehGoalPos( charge_at_position, true, false );
	self SetLookAtOrigin( charge_at_position );
	
	while(true)
	{
		velocity = self GetVelocity() * 0.1;
		velocityMag = Length(velocity);
		
		if(velocityMag < 1)
		{
			velocityMag = 1;
		}
		
		predicted_pos = self.origin + velocity;
		
		offset = VectorNormalize(predicted_pos - self.origin) * SENTINEL_DRONE_RADIUS;
		
		trace = sentinel_Trace( self.origin + offset, predicted_pos + offset, self, true);
		
		if( trace["fraction"] < 1)
		{
			if( !(isdefined(trace["entity"]) && trace["entity"].archetype === ARCHETYPE_ZOMBIE && isdefined(trace["entity"].health) && trace["entity"].health == 0) )
			{
				sentinel_KillMyself();
				return;
			}
		}
		
		if( isdefined(max_charge_time) && (GetTime() > max_charge_time) )
		{
			sentinel_KillMyself();
			return;
		}
		
		wait 0.1;
	}
}

function sentinel_PathUpdateInterrupt()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );
	
	self notify( "sentinel_PathUpdateInterrupt" );
	self endon( "sentinel_PathUpdateInterrupt" );

	skip_sentinel_PathUpdateInterrupt = GetDvarInt("skip_sentinel_PathUpdateInterrupt", 1);
	
	if(skip_sentinel_PathUpdateInterrupt == 1)
	{
		return;
	}
	
	wait 1;
	
	while( 1 )
	{
		if( isdefined( self.current_pathto_pos ) )
		{
			if( distance2dSquared( self.origin, self.goalpos ) < SQR( self.goalradius ) )
			{
				/#
					if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
					{
						RecordSphere(self.origin, 30, RED);
					}
				#/
							
				wait 0.2;
				self notify( "near_goal" );
			}
		}
		wait 0.2;
	}
}


function sentine_RumbleWhenNearPlayer()
{
	self endon( "death" );
	self endon( "change_state" );
	
	while(true)
	{
		while( sentinel_IsNearAnotherPlayer(self.origin, 120) )
		{
			self playrumbleonentity("damage_heavy");
			wait 0.1;
		}
		
		wait 0.5;
	}
}

// ----------------------------------------------Beam Fire Logic

function sentinel_CanSeeEnemy( sentinel_origin, prev_enemy_position )
{
	result = SpawnStruct();
	result.can_see_enemy = false;
	enemy_moved = false;
	b_still_enemy_in_pos_check = false;
	
	origin_point = sentinel_origin;
	
	if(!isdefined(prev_enemy_position) )
	{
		target_point = self.sentinel_droneEnemy.origin + (0,0,48);
		
		if( IsPlayer(self.sentinel_droneEnemy) )
		{
			enemy_stance = self.sentinel_droneEnemy GetStance();
			
			if( enemy_stance == "prone" )
			{
				target_point = self.sentinel_droneEnemy.origin + (0,0,2);
			}
		}
	}
	else
	{
		b_still_enemy_in_pos_check = true;
		target_point = prev_enemy_position;
	}
	
	forward_vect = AnglesToForward( self.angles );
	vect_to_enemy = target_point - origin_point;

	if( VectorDot(forward_vect, vect_to_enemy) <= 0 ) //player behind drone
	{
		if(!b_still_enemy_in_pos_check)
		{
			return result;
		}
		else
		{
			enemy_moved = true;
		}
	}
	
	if(!IS_TRUE(enemy_moved))
	{
		//Check if the enemy is inside my sight rect range
		right_vect = AnglesToRight( self.angles );
		vect_to_enemy_2d = (vect_to_enemy[0], vect_to_enemy[1], 0);
		
		projected_distance = VectorDot(vect_to_enemy_2d, right_vect);
		
		if(abs(projected_distance) > 50)
		{
			if(!b_still_enemy_in_pos_check)
			{
				return result;
			}
			else
			{
				enemy_moved = true;
			}
		}
	}
	
	//extend the ray check if the enemy moved
	if(b_still_enemy_in_pos_check)
	{
		beam_to_enemy_length = Distance(target_point, origin_point);
		beam_to_enemy_dir = target_point - origin_point;
		beam_to_enemy_dir = VectorNormalize(beam_to_enemy_dir);
		target_point = origin_point + VectorScale(beam_to_enemy_dir, SENTINEL_DRONE_BEAM_MAX_LENGTH);
	}
	
	trace = sentinel_Trace(origin_point, target_point, self.sentinel_droneEnemy, false);

	/#
		if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
		{	
			recordLine( origin_point, target_point, GREEN );
			RecordSphere(target_point, 8);
		}
	#/
	
	result.hit_entity = trace["entity"];
	result.hit_position = trace["position"];
	
	if(	( IsPlayer(trace["entity"]) ) || ( IS_TRUE(self.should_buff_zombies) && isdefined(trace["entity"]) && isdefined(trace["entity"].archetype) && (trace["entity"].archetype == ARCHETYPE_ZOMBIE) ) )
	{
		result.can_see_enemy = true;
		return result;
	}

	return result;
}

function sentinel_FireLogic()
{
	if(IS_TRUE(self.playing_intro_anim))
	{
		return false;
	}
	
	if(self.arms_count <= 0)
	{
		return false;
	}
	
	if(!IS_TRUE(self.target_initialized))
	{
		wait 0.5;
		return false;
	}
	
	if( isdefined( self.sentinel_droneEnemy ) && (!isdefined(self.nextFireTime) || (GetTime() > self.nextFireTime) ) )
	{	
		if( ( ( IS_TRUE(self.b_in_tactical_position) && (IS_TRUE(self.in_compact_mode) || sentinel_IsEnemyIndoors()) ) ||
		     (sentinel_IsInsideEngagementDistance(self.origin, self.sentinel_droneEnemy.origin + (0, 0, 48), true) && IsPointInNavVolume( self.origin, "navvolume_small" )) ) &&
		  	!Sentinel_IsNearAnotherSentinel( self.origin, 100 ) )
		{
			result = sentinel_CanSeeEnemy( self.origin );
		
			if(result.can_see_enemy)
			{
				self.nextFireTime = GetTime() + 2500 + RandomInt(2500);
					
				sentinel_NavigationStandStill();
				wait 0.1;
				
				if(!isdefined( self.sentinel_droneEnemy ))
				{
					return true;
				}
				
				enemy_pos = self.sentinel_droneEnemy.origin;
				
				if(RandomInt(100) < 70 ) //@ToDo move to variable
				{
					b_succession = true;
				}
				
				//switch to fire animation
				self.beam_start_position = self.origin;
				
				if(IS_TRUE(b_succession))
				{
					fire_state_name = "fire_succession@attack"; //@Todo: move state name to variable
				}
				else
				{
					fire_state_name = "fire@attack"; //@Todo: move state name to variable
				}
				
				self ASMRequestSubstate( fire_state_name );  
				
				//Start the claws charging
				self clientfield::set("sentinel_drone_beam_charge", 1);
				
				//Look at fire direction
				beam_dir = result.hit_position - self.origin;
		
				self.beam_fire_target.origin = result.hit_position;
				self.beam_fire_target.angles = VectorToAngles( -beam_dir );	
				
				/#
					if( GetDvarInt("debug_sentinel_drone_traces") > 0 )
					{	
						recordLine( self.origin, result.hit_position, (0.9, 0.7, 0.6) );
						RecordSphere(result.hit_position, 8, (0.9, 0.7, 0.6));
					}
				#/
				
				self clearlookatent();
				self.angles = VectorToAngles(beam_dir);
				
				self SetLookAtEnt( self.beam_fire_target );
				self setTurretTargetEnt( self.beam_fire_target );
				
				//reached the point in the animation to start firing
				self waittill( "fire_beam" );
				
				//Stop claws charging before firing the beam
				self clientfield::set("sentinel_drone_beam_charge", 0);
				
				result = sentinel_CanSeeEnemy( self.beam_start_position, result.hit_position );
				
				if(result.can_see_enemy)
				{
					if(!IS_TRUE(b_succession) && IsPlayer(result.hit_entity))
					{
						result.hit_entity thread sentinel_DamagePlayer( int(SENTINEL_DRONE_BEAM_DAMAGE_PER_SECOND * 0.5), self); //@ToDo move damage to variable
					}
					
					sentinel_FireBeam( result.hit_position, b_succession );
				}
				else
				{
					sentinel_FireBeam(result.hit_position, b_succession);
				}			
				
				self vehicle_ai::waittill_asm_complete( fire_state_name, 5 );
				
				if( isdefined(self.sentinel_droneEnemy) )
				{
					self SetLookAtEnt( self.sentinel_droneEnemy );
					self setTurretTargetEnt( self.sentinel_droneEnemy );
				}
				
				//switch back to locomotion
				self ASMRequestSubstate( "locomotion@movement" );  //@Todo: move state name to variable
				
				//Change position 
				if( RandomInt(100) < 40 )
				{
					sentinel_changeSentinelPosition();
				}
				
				//Reset next fire time
				if(RandomInt(100) < 30)
				{
					self.nextFireTime = GetTime() + 2500 + RandomInt(2500);
				}
				
				return true;
			}
		}
	}
	
	return false;
}



function sentinel_FireBeam( target_position, b_succession )
{
	self endon( "change_state" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon("death_state_activated");
	
	self.lastTimeFired = GetTime();

	//Look at fire direction
	beam_dir = target_position - self.origin;

	self.beam_fire_target.origin = target_position;
	self.beam_fire_target.angles = VectorToAngles( -beam_dir );	
	
	//self clearlookatent();
	self.angles = VectorToAngles(beam_dir);
	//self SetLookAtEnt( self.beam_fire_target );
	self setTurretTargetEnt( self.beam_fire_target );
	/*
	/#
	forward_dir = AnglesToForward( self.angles );
	recordLine( self.origin, self.origin + VectorScale(forward_dir, 300), GREEN );
	recordLine( self.origin, self.origin + VectorScale(beam_dir, 500), RED );
	#/
	*/
		
	/*
	/#
		Sphere(target_position, 15, GREEN,0.5, false, 10, 360);
	#/
	*/
	self.is_firing_beam = true;
	
	if(!IS_TRUE(b_succession))
	{
		sentinel_FireBeamBurst( target_position );
	}
	else
	{
		sentinel_FireBeamSuccession( target_position );
	}
	
	self.is_firing_beam = false;
}

function sentinel_FireBeamBurst( target_position )
{
	self endon( "change_state" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon("death_state_activated");
	
	for(i = 1; i <= 3; i++)
	{
		if( self.sentinelDroneHealthArms[i] <= 0 ) //no arm
		{
			continue;
		}
		
		self clientfield::set("sentinel_drone_beam_fire" + i, 1);
		
		/*
		/#
			Sphere(self.beam_fire_start_models[i].origin, 10, WHITE,0.5, false, 10, 360);
		#/
		*/
	}
	
	wait 0.1;
	
	start_beam_time = GetTime() + 2000;
	beam_damage_update = 0.1;
	
	player_damage = int(SENTINEL_DRONE_BEAM_DAMAGE_PER_SECOND * beam_damage_update);
		
	while(GetTime() < start_beam_time || IS_TRUE(self.sentinel_DebugFX_PlayAll))
	{
		sentinel_DamageBeamTouchingEntity( player_damage, target_position );
	
		wait beam_damage_update;
	}
		
	for(i = 1; i <= 3; i++)
	{
		if( self.sentinelDroneHealthArms[i] <= 0 ) //no arm
		{
			continue;
		}
		
		self clientfield::set("sentinel_drone_beam_fire" + i, 0);
	}
}

function sentinel_FireBeamSuccession( target_position )
{
	self endon( "change_state" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon("death_state_activated");
	
	player_damage = int(SENTINEL_DRONE_BEAM_DAMAGE_PER_SECOND * 0.3);
	
	arms_order = [];
	arms_order[0] = SENTINEL_DRONE_ARM_LEFT;
	arms_order[1] = SENTINEL_DRONE_ARM_RIGHT;
	arms_order[2] = SENTINEL_DRONE_ARM_TOP;
	
	arms_notifies = [];
	arms_notifies[0] = "attack_quick_left";
	arms_notifies[1] = "attack_quick_right";
	arms_notifies[2] = "attack_quick_top";
	
	for(i = 0; i < 3; i++)
	{
		if( self.sentinelDroneHealthArms[arms_order[i]] <= 0 ) //no arm
		{
			continue;
		}
		
		self util::waittill_any_timeout(0.3, arms_notifies[i], "change_state", "disconnect", "death", "death_state_activated" );

		
		self clientfield::set("sentinel_drone_beam_fire" + arms_order[i], 1);
		
		sentinel_DamageBeamTouchingEntity( player_damage, target_position, true );
		
		wait 0.1;
		
		self clientfield::set("sentinel_drone_beam_fire" + arms_order[i], 0);
	}
}

function sentinel_DamageBeamTouchingEntity( player_damage, target_position, b_succession = false )
{
	trace = sentinel_Trace(self.origin, target_position, self.sentinel_droneEnemy, false);
	trace_entity = trace["entity"];

	if( IsPlayer(trace_entity) )
	{
		trace_entity thread sentinel_DamagePlayer( player_damage, self, b_succession);
	}
	else if( isdefined(trace_entity) && isdefined(trace_entity.archetype) && trace_entity.archetype == ARCHETYPE_ZOMBIE)
	{
		self thread sentinel_ElectrifyZombie( trace_entity.origin, trace_entity, 80);
	}
}


//----------------------------------------------Self Destruct logic

function sentinel_SelfDestruct( time )
{
	self endon( "change_state" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon("death_state_activated");
	
	wait time;
	
	Sentinel_KillMySelf();
}

// ----------------------------------------------Charge at Player Logic

function sentinel_ChargeAtPlayer( )
{
	if(!isdefined(self))
	{
		return;
	}
	
	self endon( "change_state" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon("death_state_activated");
	
	//self sentinel_DeactivateAllEffects();
	
	charge_at_position = self.sentinel_droneEnemy.origin + (0, 0, 48);
	
	wait 0.3;
	
	self.is_charging_at_player = true;
	self sentinel_NavigationStandStill();
	
	sentinel_play_taunt( level._sentinel_System_Critical_Taunts );
	
	self ASMRequestSubstate( "suicide_intro@death" ); //Play charge intro anim
	
	wait 2;
	
	if( self.sentinelDroneHealthCamera <= 0 )
	{
		b_charge_at_player = false;
	}
	else
	{
		charge_at_position = undefined;
		b_charge_at_player = true;
	}
	
	self ASMRequestSubstate( "suicide_charge@death" ); //Play charge movement anim
	
	self SetSpeed( 60 ); //@ToDo: move to GDT
	
	self thread sentinel_ChargeAtPlayerNavigation( b_charge_at_player, SENTINEL_CHARGE_AT_PLAYER_TIME_OUT, charge_at_position);
	
	detonation_distance_sq = 100 * 100; //@ToDo: move to GDT
	
	while(isdefined(self) && isdefined(self.sentinel_droneEnemy))
	{
		distance_sq = DistanceSquared(self.sentinel_droneEnemy.origin + (0, 0, 48), self.origin);
		
		if( distance_sq <= detonation_distance_sq)
		{
			sentinel_killmyself();
		}
		
		wait 0.2;
	}
}

// ----------------------------------------------
// Damage States functions
// ----------------------------------------------

function IsLeftArm(part_name)
{
	if(!isdefined(part_name))
	{
		return false;
	}
	
	return IsSubStr(part_name, "tag_arm_left");
}

function IsRightArm(part_name)
{
	if(!isdefined(part_name))
	{
		return false;
	}
	
	return IsSubStr(part_name, "tag_arm_right");
}

function IsTopArm(part_name)
{
	if(!isdefined(part_name))
	{
		return false;
	}
	
	return IsSubStr(part_name, "tag_arm_top");
}

function IsCore(part_name)
{
	if(!isdefined(part_name))
	{
		return false;
	}
	
	if( part_name == SENTINEL_DRONE_FACE_TAG ||
	   part_name == SENTINEL_DRONE_CORE_TAG ||
	   part_name == SENTINEL_DRONE_CORE_TAG_2 ||
	   part_name == SENTINEL_DRONE_CORE_TAG_3 )
	{
		return true;
	}
	
	return false;
}

function IsCamera(part_name)
{
	if(!isdefined(part_name))
	{
		return false;
	}
	
	if( part_name == "tag_camera_dead" ||
	   part_name == "tag_flash" ||
	   part_name == "tag_laser" ||
	  part_name == "tag_turret")
	{
		return true;
	}
	
	return false;
}

function sentinel_GetArmNumber(part_name)
{
	if(!isdefined(part_name))
	{
		return 0;
	}
	
	if( IsLeftArm(part_name) )
	{
		return SENTINEL_DRONE_ARM_LEFT;
	}
	else if( IsRightArm(part_name) )
	{
		return SENTINEL_DRONE_ARM_RIGHT;
	}
	else if( IsTopArm(part_name) )
	{
		return SENTINEL_DRONE_ARM_TOP;
	}
	
	return 0;
}

function private sentinel_ArmDamage( damage, arm, eAttacker = undefined )
{
	if(self.arms_count == 0)
	{
		return;
	}
	
	if(arm == 0 || damage == 0)
	{
		return;
	}
	
	if(self.sentinelDroneHealthArms[arm] <= 0)
	{
		return;
	}
	
	self.sentinelDroneHealthArms[arm] = self.sentinelDroneHealthArms[arm] - damage;
	
	if( self.sentinelDroneHealthArms[arm] <= 0 )
	{
		self.arms_count--;
		
		if ( IsPlayer( eAttacker ) ) // track whether the same player was responsible for all arms being destroyed, as that's a challenge requirement
		{
			if ( !isdefined( self.e_arms_attacker ) && self.arms_count == 2 )
			{
				self.e_arms_attacker = eAttacker;
				self.b_same_arms_attacker = true;
			}
			else
			{
				if ( self.e_arms_attacker !== eAttacker )
				{
					self.b_same_arms_attacker = false;
				}
			}
		}
		
		self clientfield::set( "sentinel_drone_arm_cut_" + arm, 1 );
		
		if(arm == SENTINEL_DRONE_ARM_LEFT)
		{
			self HidePart( SENTINEL_DRONE_ARM_LEFT_TAG, "", true );
			self ShowPart( SENTINEL_DRONE_ARM_LEFT_BROKEN_TAG, "", true );
		}
		else if(arm == SENTINEL_DRONE_ARM_RIGHT)
		{
			self HidePart( SENTINEL_DRONE_ARM_RIGHT_TAG, "", true );
			self ShowPart( SENTINEL_DRONE_ARM_RIGHT_BROKEN_TAG, "", true );
		}
		else if(arm == SENTINEL_DRONE_ARM_TOP)
		{
			self HidePart( SENTINEL_DRONE_ARM_TOP_TAG, "", true );
			self ShowPart( SENTINEL_DRONE_ARM_TOP_BROKEN_TAG, "", true );
		}
		
		if( self.arms_count == 0 && !IS_TRUE(self.disable_charge_when_no_arms) )
		{
			sentinel_OnAllArmsDestroyed();
			
			if ( IsPlayer( eAttacker ) ) // check to make sure attacker is defined and a player
			{
				level notify( "all_sentinel_arms_destroyed", self.b_same_arms_attacker, eAttacker ); //used by DLC3 minor EE and challenges
			}
		}
	}
}

function sentinel_DestroyAllArms( b_disable_charge )
{
	self.disable_charge_when_no_arms = IS_TRUE(b_disable_charge);
	
	sentinel_ArmDamage(self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_LEFT] + 1000, SENTINEL_DRONE_ARM_LEFT);
	sentinel_ArmDamage(self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_RIGHT] + 1000, SENTINEL_DRONE_ARM_RIGHT);
	sentinel_ArmDamage(self.sentinelDroneHealthArms[SENTINEL_DRONE_ARM_TOP] + 1000, SENTINEL_DRONE_ARM_TOP);
}

function private sentinel_OnAllArmsDestroyed()
{
	sentinel_DestroyFace();
	sentinel_DestroyCore();
	
	wait 0.1;
	self thread sentinel_ChargeAtPlayer();
}

function private sentinel_DestroyFace()
{
	sentinel_FaceDamage( self.sentinelDroneHealthFace + 1000, SENTINEL_DRONE_FACE_TAG );
}

function private sentinel_DestroyCore()
{
	sentinel_CoreDamage( self.sentinelDroneHealthCore + 1000, SENTINEL_DRONE_CORE_TAG );
}

function private sentinel_FaceDamage( damage, partName )
{
	if(damage == 0)
	{
		return;
	}
	
	if(self.sentinelDroneHealthFace <= 0)
	{
		return;
	}
	
	if(!isdefined(partName) || partName != SENTINEL_DRONE_FACE_TAG)
	{
		return;
	}
	
	self.sentinelDroneHealthFace = self.sentinelDroneHealthFace - damage;
	
	if( self.sentinelDroneHealthFace <= 0 )
	{
		self clientfield::set( "sentinel_drone_face_cut", 1 );
		
		self HidePart( SENTINEL_DRONE_FACE_TAG, "", true );
	}
}

function private sentinel_CoreDamage( damage, partName )
{
	if(damage == 0)
	{
		return;
	}
	
	if(self.sentinelDroneHealthFace > 0)
	{
		return;
	}
	
	if(self.sentinelDroneHealthCore <= 0)
	{
		return;
	}
	
	if(!IsCore(partName) )
	{
		return;
	}
	
	self.sentinelDroneHealthCore = self.sentinelDroneHealthCore - damage;
	
	if( self.sentinelDroneHealthCore <= 0 )
	{
		self HidePart( SENTINEL_DRONE_CORE_BLUE_TAG, "", true );
		self ShowPart( SENTINEL_DRONE_CORE_RED_TAG, "", true );
	}
}

function private sentinel_CameraDamage( damage, partName, eAttacker )
{
	if(damage == 0)
	{
		return;
	}
	
	if(self.sentinelDroneHealthCamera <= 0)
	{
		return;
	}
	
	if(!IsCamera(partName) )
	{
		return;
	}
	
	self.sentinelDroneHealthCamera = self.sentinelDroneHealthCamera - damage;
	
	if( self.sentinelDroneHealthCamera <= 0 )
	{
		self HidePart( SENTINEL_DRONE_CAMERA_TURRET_TAG, "", true );	
		self ShowPart( SENTINEL_DRONE_CAMERA_BROKEN_TAG, "", true );
		
		self clientfield::set("sentinel_drone_camera_destroyed", 1);
		
		sentinel_DestroyFace();
		sentinel_DestroyCore();
	
		self thread sentinel_SelfDestruct( 2000 );
		self thread sentinel_ChargeAtPlayer();
		
		if ( IsPlayer( eAttacker ) )
		{
			level notify( "sentinel_camera_destroyed", eAttacker );
		}
	}
}

function sentinel_CallbackDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName,  vSurfaceNormal )
{
	//Ignore other sentinels damage
	if(isdefined(eAttacker) && eAttacker.archetype === ARCHETYPE_SENTINEL_DRONE)
	{
		return 0;
	}
	
	if(isdefined(eInflictor) && eInflictor.archetype === ARCHETYPE_SENTINEL_DRONE)
	{
		return 0;
	}
	
	//InstaKill Multiplier
	if( isdefined(eAttacker) && isdefined(eAttacker.team) && isdefined(level.zombie_vars) && isdefined(level.zombie_vars[eAttacker.team]) && 
	    IS_TRUE( level.zombie_vars[eAttacker.team]["zombie_insta_kill"] ) )
	{
		iDamage = iDamage * 4; //@ToDo move to variable
	}
	
	if(self.sentinelDroneHealthFace <= 0 && IsCore(partName) )
	{
		iDamage = iDamage * 2; //@ToDo move to variable
	}
	
	if(GetTime() > self.nextRollTime)
	{
		if(math::cointoss())
		{
			self.shouldRoll = true;
		}
		else
		{
			self.nextRollTime = GetTime() + RandomInt( 3000 );
		}
	}
	
	// PORTIZ: passing in the attacker for challenge tracking
	thread sentinel_ArmDamage(iDamage, sentinel_GetArmNumber(partName), eAttacker );
	thread sentinel_FaceDamage(iDamage, partName);
	thread sentinel_CameraDamage(iDamage, partName, eAttacker);
	
	return iDamage;
}

function sentinel_drone_CallbackRadiusDamage( eInflictor, eAttacker, iDamage, fInnerDamage, fOuterDamage, iDFlags, sMeansOfDeath, weapon, vPoint, fRadius, fConeAngleCos, vConeDir, psOffsetTime )
{
	//Ignore other sentinels damage
	if(isdefined(eAttacker) && eAttacker.archetype === ARCHETYPE_SENTINEL_DRONE)
	{
		return 0;
	}
	
	if(isdefined(eInflictor) && eInflictor.archetype === ARCHETYPE_SENTINEL_DRONE)
	{
		return 0;
	}

	if(GetTime() > self.nextRollTime)
	{
		if(math::cointoss())
		{
			self.shouldRoll = true;
		}
		else
		{
			self.nextRollTime = GetTime() + 3000 + RandomInt( 4000 );
		}
	}
	
	return iDamage;
}


// ----------------------------------------------
// State: death
// ----------------------------------------------

function state_death_update( params )
{
	self endon( "death" );
	
	self sentinel_RemoveFromLevelArray();
	self sentinel_DeactivateAllEffects();
	
	self ASMRequestSubstate( "normal@death" );
	
	set_sentinel_drone_enemy( undefined );
	   	
	//self SetPhysAcceleration( ( 0, 0, -300 ) );
	//self.vehcheckforpredictedcrash = true;
	
	self thread vehicle_death::death_fx();
	//self playsound( "zmb_parasite_explo" );
	
	//self util::waittill_notify_or_timeout( "veh_predictedcollision", 4.0 );
	
	self.beam_fire_target thread sentinel_DeleteDroneDeathFX( self.origin );
	
	
//////Do damage to the nearby players
	min_distance = 110;
		
	players = GetPlayers();

	for( i = 0; i < players.size; i++ )
	{
		if( !is_target_valid( players[i] ) )
		{
			continue;
		}

		min_distance_sq = min_distance * min_distance;
	
		distance_sq = DistanceSquared( self.origin, players[i].origin + (0, 0, 48) );
		
		if(distance_sq < min_distance_sq)
		{
			players[i] sentinel_DamagePlayer( 60, self);
		}
	}

//////Electrify Zombies around
	self sentinel_ElectrifyZombie( self.origin, undefined, 100);
	
	//make sure the client gets a chance to play the second fx before deleting
	wait 0.1;
	
	self Delete();
}

function sentinel_DeleteDroneDeathFX( explosion_origin )
{
	self endon("disconnect");
	self endon( "death" );
	
	self.origin = explosion_origin;
		
	wait 0.1;
	
	self clientfield::set( "sentinel_drone_deathfx", 1 );
	
	wait 6;
	
	self Delete();
}

// ----------------------------------------------
// State: Utility
// ----------------------------------------------

function sentinel_ForceGoAndStayInPosition( b_enable, position)
{
	if( IS_TRUE(b_enable) )
	{
		self.forced_pos = position;
	}
	else
	{
		self.shouldRoll = false;
		self.forced_pos = undefined;
	}
}

function sentinel_IsEnemyIndoors()
{
	if(!isdefined(self.v_compact_mode))
	{
		v_compact_mode = GetEnt( "sentinel_compact", "targetname" );
	}
	
	if(isdefined(v_compact_mode))
	{
		if ( self.sentinel_droneEnemy IsTouching( v_compact_mode ) )
		{
			return true;
		}
	}
	
	return false;
}

function sentinel_IsEnemyInNarrowPlace()
{
	if(!isdefined(self.sentinel_droneEnemy))
	{
		return false;
	}
	
	if(!isdefined(self.v_narrow_volume))
	{
		self.v_narrow_volume = GetEnt( "sentinel_narrow_nav", "targetname" );
	}
	
	if(isdefined(self.v_narrow_volume) && isdefined(self.sentinel_droneEnemy) )
	{
		if ( self.sentinel_droneEnemy IsTouching( self.v_narrow_volume ) )
		{
			return true;
		}
	}
	
	return false;
}


function sentinel_SetCompactMode(b_compact)
{
	if( IS_TRUE(b_compact) )
	{
		self.in_compact_mode = true;
		Blackboard::SetBlackBoardAttribute( self, STANCE, STANCE_CROUCH );
	}
	else
	{
		self.in_compact_mode = false;
		Blackboard::SetBlackBoardAttribute( self, STANCE, STANCE_STAND );
	}
}

function sentinel_HideInitialBrokenParts()
{
	self endon("disconnect");
	self endon( "death" );
	
	wait 0.2;
	
	self HidePart( SENTINEL_DRONE_ARM_LEFT_BROKEN_TAG, "", true );
	self HidePart( SENTINEL_DRONE_ARM_RIGHT_BROKEN_TAG, "", true );
	self HidePart( SENTINEL_DRONE_ARM_TOP_BROKEN_TAG, "", true );
	self HidePart( SENTINEL_DRONE_CAMERA_BROKEN_TAG, "", true );
	self HidePart( SENTINEL_DRONE_CORE_RED_TAG, "", true );
}

function sentinel_KillMyself()
{
	self DoDamage( self.health + 100, self.origin );
}


function sentinel_GetEngagementDistMax()
{
	if( sentinel_IsEnemyInNarrowPlace() )
	{
		return self.settings.engagementDistMax * 0.3;
	}
	else if(IS_TRUE(self.in_compact_mode))
	{
		return self.settings.engagementDistMax * 0.85;
	}
	
	return self.settings.engagementDistMax;
}

function sentinel_GetEngagementDistMin()
{
	if( sentinel_IsEnemyInNarrowPlace() )
	{
		return self.settings.engagementDistMin * 0.2;
	}
	else if(IS_TRUE(self.in_compact_mode))
	{
		return self.settings.engagementDistMin * 0.5;
	}
	
	return self.settings.engagementDistMin;
}

function sentinel_GetEngagementHeightMax()
{
	if(IS_TRUE(self.in_compact_mode))
	{
		return self.settings.engagementHeightMax * 0.8;
	}
	
	return self.settings.engagementHeightMax;
}

function sentinel_GetEngagementHeightMin()
{
	if(!isdefined(self.sentinel_droneEnemy))
	{
		return self.settings.engagementHeightMin * 3;
	}
		
	return self.settings.engagementHeightMin;
}

function sentinel_IsInsideEngagementDistance( origin, position, b_accept_negative_height )
{
	if( ! (Distance2DSquared( position, origin ) > SQR( sentinel_GetEngagementDistMin()) &&
	       Distance2DSquared( position, origin ) < SQR( sentinel_GetEngagementDistMax())) )
	{
		return false;
	}

	if( IS_TRUE(b_accept_negative_height) )
	{
		return (abs(origin[2] - position[2]) >= sentinel_GetEngagementHeightMin()) && (abs(origin[2] - position[2]) <= sentinel_GetEngagementHeightMax());
	}
	else
	{	
		return ((position[2] - origin[2]) >= sentinel_GetEngagementHeightMin()) && (( position[2] - origin[2]) <= sentinel_GetEngagementHeightMax() );
	}
}

function sentinel_Trace(start, end, ignore_ent, b_physics_trace, ignore_characters)
{
	if(IS_TRUE(b_physics_trace))
	{
		trace = PhysicsTrace( start, end, ( -10, -10, -10 ), ( 10, 10, 10 ), self, PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_VEHICLE );
		
		if(trace[ "fraction" ] < 1)
		{
			return trace;
		}
	}

	trace = BulletTrace( start, end, !IS_TRUE(ignore_characters), self, false, false, self, true );
	
	return trace;
}

function sentinel_ElectrifyZombie( origin, zombie, radius )
{
	self endon( "disconnect" );
	self endon( "death" );
	
	if(isdefined(self.sentinel_ElectrifyZombie))
	{
		self thread [[self.sentinel_ElectrifyZombie]]( origin, zombie, radius );
	}
}

function sentinel_DeactivateAllEffects()
{
	for(i = 1; i <= 3; i++)
	{
		self clientfield::set("sentinel_drone_arm_cut_" + i, 0);
	}
}

function sentinel_DamagePlayer( damage, eAttacker, b_light_damage = false ) // self = player in radius
{
	self notify( "proximityGrenadeDamageStart" );
	self endon( "proximityGrenadeDamageStart" );
	self endon( "disconnect" );
	self endon( "death" );
	eAttacker endon( "disconnect" );	
	
	self DoDamage( damage, eAttacker.origin, eAttacker, eAttacker );
	
	if(b_light_damage)
	{
		self playrumbleonentity("damage_heavy");
	}
	else
	{
		self playrumbleonentity("proximity_grenade");
	}
	
	if ( self util::mayApplyScreenEffect() )
	{
		self clientfield::increment_to_player("sentinel_drone_damage_player_fx");
		
		if(b_light_damage)
		{
			self shellshock( "electrocution_sentinel_drone", 0.5 );
		}
		else
		{
			self shellshock( "electrocution_sentinel_drone", 1 );
		}
	}
	

}

function sentinel_RemoveFromLevelArray()
{
	if(!isdefined(level.a_sentinel_drones))
	{
		return;
	}
		
	for(i = 0; i < level.a_sentinel_drones.size; i++)
	{
		if( level.a_sentinel_drones[i] == self)
		{
			level.a_sentinel_drones[i] = undefined;
			break;
		}
	}
	
	level.a_sentinel_drones = array::remove_undefined( level.a_sentinel_drones );
}

function sentinel_IsNearAnotherSentinel( point, min_distance )
{
	if(!isdefined(level.a_sentinel_drones))
	{
		return false;
	}
	
	for(i = 0; i < level.a_sentinel_drones.size; i++)
	{
		if(!isdefined(level.a_sentinel_drones[i]))
		{
			continue;
		}
		
		if(level.a_sentinel_drones[i] == self)
			continue;
		
		min_distance_sq = min_distance * min_distance;
		
		distance_sq = DistanceSquared( level.a_sentinel_drones[i].origin, point );
		
		if(distance_sq < min_distance_sq)
		{
			return true;
		}
	}
	
	return false;
}

function sentinel_IsNearAnotherPlayer( origin, min_distance )
{
	players = GetPlayers();

	for( i = 0; i < players.size; i++ )
	{
		if( !is_target_valid( players[i] ) )
		{
			continue;
		}
		

		min_distance_sq = min_distance * min_distance;
	
		distance_sq = DistanceSquared( origin, players[i].origin + (0, 0, 48) );
		
		if(distance_sq < min_distance_sq)
		{
			return true;
		}
	}
	
	return false;
}

function sentinel_play_taunt( taunt_Arr )
{
	if( isdefined(level._lastplayed_drone_taunt) && (GetTime() - level._lastplayed_drone_taunt) < 6000 )
	{
		return;
	}
	
	taunt = RandomInt(taunt_Arr.size);
	
	level._lastplayed_drone_taunt = GetTime();
	self PlaySound( taunt_Arr[taunt] );
}

// ----------------------------------------------
// DEBUG
// ----------------------------------------------

/#
function sentinel_DebugDrawSize()
{
	self endon("death");
	
	while(true)
	{
		radius = GetDvarInt("drone_radius2", 35);
		Sphere(self.origin, radius, GREEN, 0.5);
			
		wait 0.01;
	}
}


function sentinel_DebugFX()
{
	self endon("death");
	
	while(true)
	{
		if(GetDvarInt("sentinel_DebugFX_PlayAll", 0) == 1)
		{
			self.sentinel_DebugFX_PlayAll = true;
			
			forward_vector = AnglesToForward(self.angles);
			forward_vector = self.origin + VectorScale(forward_vector, SENTINEL_DRONE_BEAM_MAX_LENGTH);
			thread sentinel_FireBeam( forward_vector );
			
			self clientfield::set("sentinel_drone_beam_charge", 1);
		}
		else if(IS_TRUE(self.sentinel_DebugFX_PlayAll))
		{
			self.sentinel_DebugFX_PlayAll = false;
			
			self clientfield::set("sentinel_drone_beam_charge", 0);
		}
		
		if(GetDvarInt("sentinel_DebugFX_BeamCharge", 0) == 1)
		{
			self.sentinel_DebugFX_BeamCharge = true;
		}
		else if(IS_TRUE(self.sentinel_DebugFX_BeamCharge))
		{
			self.sentinel_DebugFX_BeamCharge = false;
			
			self clientfield::set("sentinel_drone_beam_charge", 0);
		}
		
		if(GetDvarInt("sentinel_DebugFX_NoArms", 0) == 1)
		{
			if( !IS_TRUE(self.sentinel_DebugFX_NoArms) )
			{
				self.sentinel_DebugFX_NoArms = true;
				
				thread sentinel_ArmDamage(1000, SENTINEL_DRONE_ARM_LEFT);
				thread sentinel_ArmDamage(1000, SENTINEL_DRONE_ARM_RIGHT);
				thread sentinel_ArmDamage(1000, SENTINEL_DRONE_ARM_TOP);
			}
		}
		
		if(GetDvarInt("sentinel_DebugFX_NoFace", 0) == 1)
		{
			if( !IS_TRUE(self.sentinel_DebugFX_NoFace) )
			{
				self.sentinel_DebugFX_NoFace = true;
				thread sentinel_FaceDamage(1000, SENTINEL_DRONE_FACE_TAG);
			}
		}
		
		wait 3;
	}
}

function sentinel_DebugBehavior()
{
	self endon( "death" );
	
	while(isdefined(self))
	{
		if(GetDvarInt("sentinel_debug_buff_zombies", 0) == 1)
		{
			self.debug_should_buff_zombies = true;
			self.should_buff_zombies = true;
		}
		else if( isdefined(self.debug_should_buff_zombies) )
		{
			self.debug_should_buff_zombies = undefined;
			self.should_buff_zombies = false;
		}
		
		if(GetDvarInt("sentinel_debug_compact", 0) == 1)
		{
			self.debug_sentinel_debug_compact = true;
			Blackboard::SetBlackBoardAttribute( self, STANCE, STANCE_CROUCH );
		}
		else if( isdefined(self.debug_sentinel_debug_compact) )
		{
			self.debug_sentinel_debug_compact = undefined;
			Blackboard::SetBlackBoardAttribute( self, STANCE, STANCE_STAND );
		}
		
		wait 1;
	}
}

#/