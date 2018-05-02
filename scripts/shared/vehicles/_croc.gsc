#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\flag_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\shared\ai\utility.gsh;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;


#define NUM_DAMAGE_STATES 4
#define DAMAGE_STATE_THRESHOLD_PCT_1 0.75
#define DAMAGE_STATE_THRESHOLD_PCT_2 0.5
#define DAMAGE_STATE_THRESHOLD_PCT_3 0.25
#define DAMAGE_STATE_THRESHOLD_PCT_4 0.1	

#define SCAN_HEIGHT_OFFSET 40
	
#define DEFAULT_WEAK_SPOT_DAMAGE_LIMIT 600
	
#define MELEE_RADIUS 270
#define MELEE_INNER_RADIUS_DAMAGE 200
#define MELEE_OUTER_RADIUS_DAMAGE 150
	
#define NEAR_POINTS_DIST 1000
#define FAR_POINTS_DIST 2500
	
#namespace croc;

REGISTER_SYSTEM( "croc", &__init__, undefined )
	
#using_animtree( "generic" );

function __init__()
{
	vehicle::add_main_callback( "croc", &main );

	SetDvar( "phys_buoyancy", 1 ); // turn on buoyancy
		
	level.difficultySettings[ "crocburst_scale" ][ "easy" ]			= 1.15;
	level.difficultySettings[ "crocburst_scale" ][ "normal" ]		= 1;
	level.difficultySettings[ "crocburst_scale" ][ "hardened" ] 	= 0.85;
	level.difficultySettings[ "crocburst_scale" ][ "veteran" ] 		= 0.7;

	level.difficultySettings[ "crochealth_boost" ][ "easy" ]		= -70;
	level.difficultySettings[ "crochealth_boost" ][ "normal" ]		= 0;
	level.difficultySettings[ "crochealth_boost" ][ "hardened" ] 	= 70;
	level.difficultySettings[ "crochealth_boost" ][ "veteran" ] 	= 140;
}

function main()
{
	self useanimtree( #animtree );
	self thread croc_think();
	self.overrideVehicleDamage = &crocCallback_VehicleDamage;
}

function isInWater()
{
	return GetEntNavMaterial( self ) == 2;
}

function isOnLand()
{
	return !isInWater();
}

function croc_requestASMState( statename )
{
	if ( self isInWater() )
	{
		self ASMRequestSubstate( statename + "@water" );
	}
	else if ( self isOnLand() )
	{
		self ASMRequestSubstate( statename + "@land" );
	}
}

function croc_think()
{
	self EnableAimAssist();
	self SetNearGoalNotifyDist( 35 );
	
	self.current_damage_state = 0;
	
	// Set this on the metal storm to specify the cuttoff distance at which he can see
	self.highlyawareradius = 150;
	self.weak_spot_health = DEFAULT_WEAK_SPOT_DAMAGE_LIMIT;
	
	self.fovcosine = 0; // +/-90 degrees = 180 fov, err 0 actually means 360 degree view
	self.fovcosinebusy = 0;
	self.maxsightdistsqrd = 10000 * 10000;
	
	//assert( isdefined( self.scriptbundlesettings ) );
	//self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	//self SetSpeed( self.settings.defaultMoveSpeed, 5, 5 );
	
	self.goalradius = 10000;
	
	if( !isdefined( self.goalpos ) )
	{
		self.goalpos = self.origin;
	}
	
	self.state_machine = self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "default", "scripted" ).update_func = &croc_scripted;
    self vehicle_ai::get_state_callbacks( "default", "combat" ).update_func = &croc_main;

    self vehicle_ai::get_state_callbacks( "default", "death" ).update_func = &croc_death;

	self vehicle_ai::set_role( "default" );
	self vehicle_ai::set_state( "combat" );
	
	
	// Set the first state
	if ( isdefined( self.script_startstate ) )
	{
		if( self.script_startstate == "off" )
		{
			self croc_off();
		}
		else
		{
			self.state_machine statemachine::set_state( self.script_startstate );
		}
	}
	else
	{
		// Set the first state
		croc_start_ai();
	}	
	
	self thread croc_set_team( self.team );
	
	waittillframeend;
	
	//self.health += gameskill::getCurrentDifficultySetting( "crochealth_boost" );
}

function croc_off()
{
	self playsound( "veh_croc_power_down" );
	if( isdefined( self.sndEnt ) )
	{
		self.sndEnt stoploopsound( .5 );
	}
	self.state_machine statemachine::set_state( "scripted" );
	self vehicle::lights_off();
	self LaserOff();
	self vehicle::toggle_tread_fx( 0 );
	self vehicle::toggle_sounds( 0 );
	self vehicle::toggle_exhaust_fx( 0 );
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	target_vec = target_vec + ( 0, 0, -500 );
	self SetTargetOrigin( target_vec );		
	self.off = true;
	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
}

function croc_on()
{
	self vehicle::lights_on();
	self vehicle::toggle_tread_fx( 1 );
	self EnableAimAssist();
	self vehicle::toggle_sounds( 1 );
	self bootup();
	self vehicle::toggle_exhaust_fx( 1 );
	self.off = undefined;
	croc_start_ai();
}

function bootup()
{
	self playsound( "veh_croc_power_up" );
	
	for( i = 0; i < 6; i++ )
	{
		wait 0.1;
		vehicle::lights_off();
		wait 0.1;
		vehicle::lights_on();
	}
	
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	
	driver = self GetSeatOccupant( 0 );
	if( !isdefined(driver) )
	{
		self SetTargetOrigin( target_vec );
	}
	wait 1;
}

function show_weak_spots( show )	// vents on the sides that are exposed when firing the main gun
{
	if( show )
	{
		//self ShowPart( "tag_target_turret_left" );
		//self ShowPart( "tag_target_turret_right" );
		//self HidePart( "tag_target_turret_left_closed" );
		//self HidePart( "tag_target_turret_right_closed" );
		
		self vehicle::toggle_exhaust_fx( 1 );
	}
	else
	{
		//self HidePart( "tag_target_turret_left" );
		//self HidePart( "tag_target_turret_right" );
		//self ShowPart( "tag_target_turret_left_closed" );
		//self ShowPart( "tag_target_turret_right_closed" );
		
		self vehicle::toggle_exhaust_fx( 0 );
	}
}

function aim_at_best_shoot_location()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "weapon_fired" );
	
	while( isdefined( self.enemy ) )
	{
		start = self GetTagOrigin( "tag_flash" );
		enemy_origin = self.enemy.origin;
		
		if( start[2] < enemy_origin[2] )	// if above croc then use the eye
		{
			enemy_origin = self.enemy GetEye();
		}
		
		dir_to_enemy = enemy_origin - start;
		dir_to_enemy = VectorNormalize( dir_to_enemy );
		right = VectorCross( dir_to_enemy, (0,0,1) );
		right = VectorNormalize( right );
		
		dist_to_enemy_squared = DistanceSquared( start, enemy_origin ) - (5*5);
		
		behind_end = enemy_origin + dir_to_enemy * 200;
		
		best_dist = -100000;
		
		end = behind_end;
		results = bullettrace( start, end, false, self );
		
		if( results["fraction"] < 1.0 )
		{
			dist_squared = DistanceSquared( start, results["position"] );
			dist_beyond_enemy = dist_squared - dist_to_enemy_squared;
			if( dist_beyond_enemy > 0 )
			{
				self SetTurretTargetVec( end );
				wait 0.1;
				continue;
			}
		}
		
		end = behind_end + right * 60;
		results = bullettrace( start, end, false, self );
		
		if( results["fraction"] < 1.0 )
		{
			dist_squared = DistanceSquared( start, results["position"] );
			dist_beyond_enemy = dist_squared - dist_to_enemy_squared;
			if( dist_beyond_enemy > 0 )
			{
				self SetTurretTargetVec( end );
				wait 0.1;
				continue;
			}
		}
		
		end = behind_end + right * -60;
		results = bullettrace( start, end, false, self );
		
		if( results["fraction"] < 1.0 )
		{
			dist_squared = DistanceSquared( start, results["position"] );
			dist_beyond_enemy = dist_squared - dist_to_enemy_squared;
			if( dist_beyond_enemy > 0 )
			{
				self SetTurretTargetVec( end );
				wait 0.1;
				continue;
			}
		}
		
		self SetTurretTargetEnt( self.enemy );
		wait 0.1;
	}
}

function croc_start_ai( state )
{
	self.goalpos = self.origin;
	
	if ( !isdefined( state ) )
		state = "combat";
	
	self.state_machine statemachine::set_state( state );
}

function croc_stop_ai()
{
	self.state_machine statemachine::set_state( "scripted" );
}

function croc_main()
{
	while( isdefined( self.emped ) )
	{
		wait 1;
	}
	
	self SetSpeed( 5, 5, 5 );	
		
	self thread croc_movementupdate();
}

function check_melee()
{
	if ( isdefined( self.enemy ) )
	{
		if( distanceSquared( self.enemy.origin, self.origin ) < MELEE_RADIUS * MELEE_RADIUS )
		{
			/*if( isdefined( self.settings.meleefx ) )
			{
				PlayFxOnTag( self.settings.meleefx, self, "tag_origin" );
			}*/
			RadiusDamage( self.origin + (0,0,40), MELEE_RADIUS, MELEE_INNER_RADIUS_DAMAGE, MELEE_OUTER_RADIUS_DAMAGE, self );
			self playsound( "veh_croc_emp" );
			return true;
		}
	}
	
	foreach ( player in level.players )
	{
		if( !isdefined( self.enemy ) || player != self.enemy )
		{
			if( distanceSquared( player.origin, self.origin ) < MELEE_RADIUS * MELEE_RADIUS )
			{
				/*if( isdefined( self.settings.meleefx ) )
				{
					PlayFxOnTag( self.settings.meleefx, self, "tag_origin" );
				}*/	
				RadiusDamage( self.origin + (0,0,40), MELEE_RADIUS, MELEE_INNER_RADIUS_DAMAGE, MELEE_OUTER_RADIUS_DAMAGE, self );
				self playsound( "veh_croc_emp" );
				return true;
			}
		}
	}
	
	return false;
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
		if ( self check_melee() )
		{
			self.move_now = true;
			self notify( "near_goal" );
		}
		
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
					if( !self canSeeEnemyFromPosition( self.current_pathto_pos, self.enemy ) )
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

function waittill_pathing_done()
{
	self endon( "death" );
	self endon( "change_state" );
	
	if( self.vehonpath )
	{
		self thread goal_flag_monitor();
		self flag::wait_till( "goal_reached" );
	}
}

function goal_flag_monitor()
{
	self endon( "death" );
	self endon( "change_state" );

	self flag::clear( "goal_reached" );
	self util::waittill_any( "near_goal", "reached_end_node", "force_goal" );
	self flag::set( "goal_reached" );
}

function croc_set_swim_depth( swimDepth )
{
	self SetBuoyancyOffset( -swimDepth );
}

function croc_testBuoyancy()
{
	self endon( "death" );

	base = 10;
	floatingOffset = base;

	while ( true )
	{
		floatingOffset = -floatingOffset;
		croc_set_swim_depth( base + floatingOffset );
		wait RandomFloatRange( 5, 8 );
	}
}

function croc_movementupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	//if( distance2dSquared( self.origin, self.goalpos ) > 20 * 20 )
	//	self SetVehGoalPos( self.goalpos, true, 2 );
	
	self.sndEnt = spawn( "script_origin", self.origin );
	self.sndEnt linkto( self, "tag_origin" );
	self.sndEnt playloopsound( "veh_croc_movement_loop", 2 );
	self croc_requestASMState( "idle" );
	
	if ( !self flag::exists( "goal_reached" ) )
	{
		self flag::init( "goal_reached" );
	}
	
	wait 0.5;
	
	goalfailures = 0;

	croc_find_next_patrol_node();

	//self thread croc_testBuoyancy();

	return;

	while( 1 )
	{
		self waittill_pathing_done();	// might be scripted on a spline
		
		//goalpos = croc_find_new_position();
		goalpos = self.patrol_node.origin;
		
		//self SetSpeed( self.settings.defaultMoveSpeed, 5, 5 );

		if( self SetVehGoalPos( goalpos, false, 1 ) )
		{
			self croc_requestASMState( "locomotion" );

			self.sndEnt playloopsound( "veh_croc_movement_loop", 2 );
			
			self.current_pathto_pos = goalpos;
			self thread path_update_interrupt();
			
			goalfailures = 0;
			self util::waittill_any( "near_goal", "reached_end_node" );
			self CancelAIMove();
			self ClearVehGoalPos();

			croc_find_next_patrol_node();
			
			if( isdefined( self.move_now ) )
			{
				self.move_now = undefined;
				wait 0.1;
			}
			else
			{
				self.sndEnt stoploopsound( .5 );
				
				if( !isdefined( self.getreadytofire ) )
				{
					self croc_requestASMState( "idle" );
				}
				
				wait 0.5;
			}
		}
		else
		{
			goalfailures++;
			
			self.current_pathto_pos = undefined;
			self LaunchVehicle( (0,0,-50) );
			
			WAIT_SERVER_FRAME;
		}
		
		if( isdefined( self.getreadytofire ) )
		{
			self.sndEnt stoploopsound( .5 );
				
			while( isdefined( self.getreadytofire ) )
			{
				wait 0.2;
				self check_melee();
			}
		}
		
	}
}

function canSeeEnemyFromPosition( position, enemy )
{
	sightCheckOrigin = position + (0,0,80);
	return sighttracepassed( sightCheckOrigin, enemy.origin + (0,0,30), false, self );
}

function croc_find_next_patrol_node()
{
	self endon( "change_state" );
	self endon( "death" );

	if ( !IsDefined( self.patrol_node ) )
	{
/#	println( "^1WARNING: No patrol path defined, taking the nearest one" );	#/

		searchRadius = 256;
		while ( !isdefined( self.patrol_node ) )
		{
			searchRadius = searchRadius * 2;
			nodes = GetNodesInRadius( self.origin, searchRadius, 0, searchRadius, "Path", 1 );

			if ( nodes.size > 0 )
			{
				self.patrol_node = nodes[ 0 ];
			}
			wait 0.02;
		}
	}

	if ( !isdefined( self.patrol_start_node ) )
	{
		self.patrol_start_node = self.patrol_node;
	}

	if ( IsDefined( self.patrol_node.target ) )
	{
		self.patrol_node = GetNode( self.patrol_node.target, "targetname" );

		if ( self.patrol_node == self.patrol_start_node )
		{
			self notify("patrol_route_complete");
		}
	}

	//AnimationStateNetworkUtility::RequestState( self, asmStateName );
}

function croc_find_new_position()
{
	//sweet_spot_dist = self.settings.engagementDist;
	sweet_spot_dist = 700; // TODO temporary value before setting up scriptbundle

	quad_tank_radius = 120;
	height_check_dist = 300;

	// deprecated // closepoints = GetNavPointsInRadius( self.origin, 0, NEAR_POINTS_DIST, quad_tank_radius, 100 );
	// deprecated // farpoints = GetNavPointsInRadius( self.origin, NEAR_POINTS_DIST, FAR_POINTS_DIST, quad_tank_radius, 100 );
	closepoints = [];
	farpoints = [];

	points = arraycombine( closepoints, farpoints, false, false );
	
	if( points.size < 5 )
	{
		// deprecated // points = GetNavPointsInRadius( self.origin, 0, FAR_POINTS_DIST, quad_tank_radius, 100 );
		points = [];
	}
	
	origin = self.goalpos;
		
	best_point = undefined;
	best_score = -999999;
	
	if ( isdefined( self.enemy ) )
	{
		vec_enemy_to_self = VectorNormalize( FLAT_ORIGIN( self.origin ) - FLAT_ORIGIN( self.enemy.origin ) );
	
		foreach( point in points )
		{
			if( distanceSquared( point, self.goalpos ) > self.goalRadius * self.goalRadius )
			{
				continue;
			}
			
			vec_enemy_to_point = ( FLAT_ORIGIN( point ) - FLAT_ORIGIN( self.enemy.origin ) );
			
			dist_in_front_of_enemy = VectorDot( vec_enemy_to_point, vec_enemy_to_self );
			dist_away_from_sweet_line = Abs( dist_in_front_of_enemy - sweet_spot_dist );
			
			score = 10 + RandomFloat( 1.5 );

			if( dist_away_from_sweet_line > 160 )
			{
				score -= math::clamp( dist_away_from_sweet_line / 1500, 0, 10 );
			}
			
			too_far_dist = sweet_spot_dist + 200;
			dist_from_enemy = distance2dSquared( point, self.enemy.origin );
			if( dist_from_enemy > too_far_dist * too_far_dist )
			{
				score -= math::clamp( dist_from_enemy / (too_far_dist * too_far_dist), 1, 10 );
			}
			
			if( distance2dSquared( self.origin, point ) < 170 * 170 )
			{
				score -= 1.0;
			}
			
			if( self canSeeEnemyFromPosition( point, self.enemy ) )
			{
				score += 2.0;
			}
			
			/#
				//DebugStar( point + (0,0,30), 100, ( 1, score, 1 ) );
				//Print3d( point + (0,0,30), "Score: " + score, ( 1, 1, 1 ), 1, 100 );
				//Record3dText( "Score: " + score, point + (0,0,30), WHITE, "Script" );
			#/

			if ( score > best_score )
			{
				best_score = score;
				best_point = point;
			}
		}
	}
	else
	{
		foreach( point in points )
		{
			score = RandomFloat( 1 );			
			
			if( distance2dSquared( self.origin, point ) < 250 )
			{
				score -= 0.5;
			}
			
			if( score > best_score )
			{
				best_score = score;
				best_point = point;
			}		
		}
	}
	
	if( isdefined( best_point ) )
	{
		/#
			//line( best_point, best_point + (0,0,100), (.3,1,.3), 1.0, true, 100 );
		#/
		origin = best_point;
	}
	
	return origin;
}

// self is vehicle
function croc_exit_vehicle()
{
	self waittill( "exit_vehicle", player );
	
	player.ignoreme = false;
	player DisableInvulnerability();
	
	self.goalpos = self.origin;
}

function croc_scripted()
{
	self endon( "change_state" );
	
	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self.turretRotScale = 1;
		self DisableAimAssist();
		//self thread vehicle_death::vehicle_damage_filter( "firestorm_turret" );
		self thread croc_set_team( driver.team );
		driver EnableInvulnerability();
		driver.ignoreme = true;
		//self thread croc_player_rocket_recoil( driver );
		//self thread croc_player_bullet_shake( driver );
		self thread croc_exit_vehicle();
		self SetBrake( 0 );
	}
	
	self LaserOff();
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();
}

function croc_update_damage_fx()
{
	next_damage_state = 0;
	
	max_health = self.healthdefault;
	if( isdefined( self.health_max ) )
	{
		max_health = self.health_max;
	}
	
	health_pct = self.health / max_health;
	
	if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_1 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_2 )
	{
		next_damage_state = 1;
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_2 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_3 )
	{
		next_damage_state = 2;			
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_3 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_4 )
	{
		next_damage_state = 3;			
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_4 )
	{
		next_damage_state = 4;
	}
	
	if ( next_damage_state != self.current_damage_state )
	{
		/*if ( isdefined( level.fx_damage_effects[ STR_VEHICLETYPE ][ next_damage_state - 1 ] ) )
		{
			fx_ent = self get_damage_fx_ent();
			
			//PlayFXOnTag( level.fx_damage_effects[ STR_VEHICLETYPE ][ next_damage_state - 1 ], fx_ent, "tag_origin" );
		}
		else
		{
			// This will get rid of the fx ent
			get_damage_fx_ent();
		}*/
		
		self.current_damage_state = next_damage_state;
	}
}

function get_damage_fx_ent()
{
	if ( isdefined( self.damage_fx_ent ) )
		self.damage_fx_ent Delete();

	self.damage_fx_ent = Spawn( "script_model", ( 0, 0, 0 ) );
	self.damage_fx_ent SetModel( "tag_origin" );
	self.damage_fx_ent.origin = self.origin;
	self.damage_fx_ent.angles = self.angles;
	self.damage_fx_ent LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
	
	return self.damage_fx_ent;
}

function cleanup_fx_ents()
{
	if( isdefined( self.damage_fx_ent ) )
	{
		self.damage_fx_ent delete();
	}
	
	if( isdefined( self.stun_fx ) )
	{
		self.stun_fx delete();
	}
}



// Death 

function croc_death()
{
	if ( isdefined( self ) )
	{
		self playsound( "veh_croc_power_down" );

		self croc_requestASMState( "death" );
	}
	
	if( isdefined( self.sndEnt ) )
	{
		self.sndEnt stoploopsound( .5 );
	}
	
	if( isdefined( self.delete_on_death ) )
	{
		self cleanup_fx_ents();
		self delete();
		return;
	}
	
	if ( !isdefined( self ) )
	{
		return;
	}
	
	self vehicle_death::death_cleanup_level_variables();			
	
	self DisableAimAssist();
	self vehicle::toggle_sounds( false );
	self vehicle::lights_off();
	self LaserOff();
	self cleanup_fx_ents();
	self vehicle::toggle_tread_fx( false );
	self vehicle::toggle_exhaust_fx( false );
	
	
	fx_ent = self get_damage_fx_ent();			
	//PlayFXOnTag( level._effect[ "croc_explo" ], fx_ent, "tag_origin" );
	
	self croc_crash_movement( self.death_info.attacker );
	
	wait 5;
	
	//self NotSolid();
	
	if ( isdefined( self ) )
	{
		//radius = 18;
		//height = 50;
		//badplace_box( "", 80, self.origin, radius, "all" );		
		//self freeVehicle();
	}
	
	wait 240;
	
	if ( isdefined( self ) )
	{
		self delete();
	}
}


function death_fx()
{
	self vehicle::do_death_fx();
	self playsound("veh_croc_sparks");
}

function croc_crash_movement( attacker )
{
	self endon( "crash_done" );
	self endon( "death" );
	
	self CancelAIMove();
	self ClearVehGoalPos();	

	self.takedamage = 0;
	
	self ClearTurretTarget();
	self SetBrake( 1 );
	
	self thread vehicle_death::death_radius_damage();
	
	self thread vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	
	self vehicle::do_death_fx();
	
	self notify( "crash_done" );
}


function croc_emped()
{
	if( isdefined( self.emped ) )
	{
		// already emped, just return for now.
		return;
	}
	
	self endon( "death" );
	self notify( "emped" );
	self endon( "emped" );
	
	self.emped = true;
	PlaySoundAtPosition( "veh_crocemp_down", self.origin );
	self.turretRotScale = 0.2;
	self croc_off();
	if( !isdefined( self.stun_fx) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
		//PlayFXOnTag( level._effect[ "croc_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait RandomFloatRange( 4, 8 );
	
	self.stun_fx delete();
	
	self.emped = undefined;
	self.weak_spot_health = DEFAULT_WEAK_SPOT_DAMAGE_LIMIT;
	self croc_on();
	self playsound ("veh_boot_croc");
}

function crocCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	is_damaged_by_grenade = weapon.weapClass == "grenade";
	
	if( isdefined( eAttacker ) && ( eAttacker == self || eAttacker.team == self.team ) )
	{
		return 0;
	}
	
	if( partName == "tag_target_turret_right" || partName == "tag_target_turret_left" || 
	   partName == "tag_target_left" || partName == "tag_target_right" || partName == "tag_target_left1" || partName == "tag_target_right1" )
	{
		self.weak_spot_health -= iDamage;
		if( self.weak_spot_health <= 0 )
		{
			self thread croc_emped();
		}
		
		iDamage = Int( iDamage * 3 );
		
		self playsound( "veh_croc_panel_hit" );
		//PlayFxOnTag( self.settings.weakSpotFx, self, partName );
	}
	else if( partName == "tag_gunner_barrel1" || partName == "tag_gunner_turret1" )
	{
		//PlayFxOnTag( self.settings.weakSpotFx, self, partName );
		
		self.left_turret_health -= iDamage;
		if( self.left_turret_health <= 0 )
		{
			//croc_destroyturret( 1 );
		}
	}
	else if( partName == "tag_gunner_barrel2" || partName == "tag_gunner_turret2" )
	{
		//PlayFxOnTag( self.settings.weakSpotFx, self, partName );
		
		self.right_turret_health -= iDamage;
		if( self.right_turret_health <= 0 )
		{
			//croc_destroyturret( 2 );
		}
	}
	else if ( is_damaged_by_grenade || sMeansOfDeath == "MOD_EXPLOSIVE" )
	{
		iDamage = Int( iDamage * 3 );
	}
	
	// when taking damage let the turret know if it is scanning to look at our enemy
	// hopefully code will update our enemy
	self.turretRotScale = 1.0;
		
	croc_update_damage_fx();

	driver = self GetSeatOccupant( 0 );
	
	if( weapon.isEmp && sMeansOfDeath != "MOD_IMPACT" )
	{
		if( !isdefined(driver) )
		{
			self thread croc_emped();
		}
	}
	
	if( isdefined( driver ) )
	{
		// Lets get some hit indicators
		//driver FinishPlayerDamage( eInflictor, eAttacker, 1, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, "none", 0, psOffsetTime );
	}
	
	return iDamage;
}


function croc_set_team( team )
{
	self.team = team;
	
	if( !isdefined( self.off ) )
	{
		croc_blink_lights();
	}
}

function croc_blink_lights()
{
	self endon( "death" );
	
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
	wait 0.1;
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
}

function croc_player_bullet_shake( player )
{
	self endon( "death" );
	self endon( "recoil_thread" );
	
	while( 1 )
	{
		self waittill( "turret_fire" );
		angles = self GetTagAngles( "tag_barrel" );
		dir = AnglesToForward( angles );
		self LaunchVehicle( dir * -5, self.origin + (0,0,30), false );
		Earthquake( 0.2, 0.2, player.origin, 200 );
	}
}

function croc_player_rocket_recoil( player )
{
	self notify( "recoil_thread" );
	self endon( "recoil_thread" );
	self endon( "death" );
	
	while( 1 )
	{
		player waittill( "missile_fire" );
		
		angles = self GetTagAngles( "tag_barrel" );
		dir = AnglesToForward( angles );
		
		self LaunchVehicle( dir * -30, self.origin + (0,0,70), false );
		Earthquake( 0.4, 0.3, player.origin, 200 );
		
		//self SetAnimRestart( %vehicles::o_drone_tank_missile_fire_sp, 1, 0, 0.4 );
	}
}
