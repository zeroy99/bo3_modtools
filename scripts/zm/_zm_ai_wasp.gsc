#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_parasite;
#using scripts\shared\clientfield_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\vehicles\_parasite;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\weapons\grapple.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_zod_idgun_quest;

#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\zm\_zm_utility.gsh;
#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_ai_wasp.gsh;
#insert scripts\zm\zm_zod_craftables.gsh;

#precache( "fx", "zombie/fx_parasite_spawn_buildup_zod_zmb" );

#define N_MAX_WASPS					16	// Max number that can be alive at any one time (mainly limited by networking concerns)
#define N_MAX_WASPS_PER_PLAYER		 5	// Max alive per player in the game

#define N_SWARM_SIZE				1

// Number of wasps to spawn = N_NUM_WASPS_PER_ROUND * (a scalar if more than one player)
#define N_NUM_WASPS_PER_ROUND		10
#define N_WASP_PLAYER_SCALAR	  0.75

#define N_SPAWN_HEIGHT_MIN			60	// Minimum ground height to spawn at
#define N_WASP_HEALTH_INCREASE		50	// Amount to increase Wasp health
#define N_WASP_HEALTH_MAX		  1600	// Maximum health
#define N_WASP_KILL_POINTS			70	// Points per kill
	
	
#namespace zm_ai_wasp;

function init()
{
	level.wasp_enabled = true;
	level.wasp_rounds_enabled = false;
	level.wasp_round_count = 1;

	level.wasp_spawners = [];

	level.a_wasp_priority_targets = [];

	level flag::init( "wasp_round" );
	level flag::init( "wasp_round_in_progress" );
	
	level.melee_range_sav  = GetDvarString( "ai_meleeRange" );
	level.melee_width_sav = GetDvarString( "ai_meleeWidth" );
	level.melee_height_sav  = GetDvarString( "ai_meleeHeight" );

	DEFAULT( level.vsmgr_prio_overlay_zm_wasp_round, ZM_WASP_VISION_OVERLAY_PRIORITY );

	clientfield::register( "toplayer", "parasite_round_fx", VERSION_SHIP, 1, "counter" );
	clientfield::register( "toplayer", PARASITE_ROUND_RING_FX, VERSION_SHIP, 1, "counter" );
	clientfield::register( "world",		"toggle_on_parasite_fog",	VERSION_SHIP, 2, "int" );
	
	visionset_mgr::register_info( "visionset", ZM_WASP_ROUND_VISIONSET, VERSION_SHIP, level.vsmgr_prio_overlay_zm_wasp_round, ZM_WASP_VISION_LERP_COUNT, false, &visionset_mgr::ramp_in_out_thread, false );

	level._effect[ "lightning_wasp_spawn" ]	= "zombie/fx_parasite_spawn_buildup_zod_zmb";

	callback::on_connect( &watch_player_melee_events);
	
	// AAT IMMUNITIES
	level thread aat::register_immunity( ZM_AAT_BLAST_FURNACE_NAME, ARCHETYPE_PARASITE, true, true, true );
	level thread aat::register_immunity( ZM_AAT_DEAD_WIRE_NAME, ARCHETYPE_PARASITE, true, true, true );
	level thread aat::register_immunity( ZM_AAT_FIRE_WORKS_NAME, ARCHETYPE_PARASITE, true, true, true );
	level thread aat::register_immunity( ZM_AAT_THUNDER_WALL_NAME, ARCHETYPE_PARASITE, true, true, true );
	level thread aat::register_immunity( ZM_AAT_TURNED_NAME, ARCHETYPE_PARASITE, true, true, true );
	
	// Init wasp targets - mainly for testing purposes.
	//	If you spawn a wasp without having a wasp round, you'll get SREs on hunted_by.
	wasp_spawner_init();
}


//
//	If you want to enable wasp rounds, then call this.
//	Specify an override func if needed.
function enable_wasp_rounds()
{
	level.wasp_rounds_enabled = true;

	if( !isdefined( level.wasp_round_track_override ) )
	{
		level.wasp_round_track_override =&wasp_round_tracker;
	}

	level thread [[level.wasp_round_track_override]]();
}


function wasp_spawner_init()
{
	level.wasp_spawners = getEntArray( "zombie_wasp_spawner", "script_noteworthy" ); 
	later_wasp = getentarray("later_round_wasp_spawners", "script_noteworthy" );
	level.wasp_spawners = ArrayCombine( level.wasp_spawners, later_wasp, true, false );
	
	if( level.wasp_spawners.size == 0 )
	{
		return;
	}
	
	for( i = 0; i < level.wasp_spawners.size; i++ )
	{
		if ( zm_spawner::is_spawner_targeted_by_blocker( level.wasp_spawners[i] ) )
		{
			level.wasp_spawners[i].is_enabled = false;
		}
		else
		{
			level.wasp_spawners[i].is_enabled = true;
			level.wasp_spawners[i].script_forcespawn = true;
		}
	}

	assert( level.wasp_spawners.size > 0 );
	level.wasp_health = 100;

	vehicle::add_main_callback( "spawner_bo3_parasite_enemy_tool", &wasp_init );
}

function get_current_wasp_count()
{
	wasps = GetEntArray( "zombie_wasp", "targetname" );
	num_alive_wasps = wasps.size;
	foreach( wasp in wasps )
	{
		if( !IsAlive( wasp ) )
		{
			num_alive_wasps--;
		}
	}
	return num_alive_wasps;
}

function wasp_round_spawning()
{
	level endon( "intermission" );
	level endon( "wasp_round" );
		
	level.wasp_targets = level.players;
	for( i = 0 ; i < level.wasp_targets.size; i++ )
	{
		level.wasp_targets[i].hunted_by = 0;
	}

	level endon( "restart_round" );
	level endon( "kill_round" );

/#
	if ( GetDvarInt( "zombie_cheat" ) == 2 || GetDvarInt( "zombie_cheat" ) >= 4 ) 
	{
		return;
	}
#/

	if( level.intermission )
	{
		return;
	}

	array::thread_all( level.players, &play_wasp_round );
	
	// spawn one at a time, recalculating position each time
	n_wave_count = N_NUM_WASPS_PER_ROUND;
	if ( level.players.size > 1 )
	{
		n_wave_count *= level.players.size * N_WASP_PLAYER_SCALAR;
	}
	
	wasp_health_increase();
	
	// The wait function uses this to determine whether or not to end the round.
	level.zombie_total = Int( n_wave_count * N_SWARM_SIZE );

/#
	if( GetDvarString( "force_wasp" ) != "" && GetDvarInt( "force_wasp" ) > 0 )
 	{
 		level.zombie_total = GetDvarInt( "force_wasp" );
		SetDvar( "force_wasp", 0 );
	}
 #/		

	wait 1;
	
	parasite_round_fx();
	visionset_mgr::activate( "visionset", ZM_WASP_ROUND_VISIONSET, undefined, ZM_WASP_RING_ENTER_DURATION, ZM_WASP_RING_LOOP_DURATION, ZM_WASP_RING_EXIT_DURATION );
	level clientfield::set( "toggle_on_parasite_fog", 1 );
	
	PlaySoundAtPosition( "vox_zmba_event_waspstart_0", ( 0, 0, 0 ) );
	
	wait 6; // wait before spawning parasites
	
	n_wasps_alive = 0;

	// Start spawning loop
	level flag::set( "wasp_round_in_progress" );

	level endon( "last_ai_down" );
	
	level thread wasp_round_aftermath();

	while ( true )
	{
		while( level.zombie_total > 0 )
		{
			if( IS_TRUE( level.bzm_worldPaused ) )
			{
				util::wait_network_frame();
				continue;
			}
			if( isdefined(level.zm_mixed_wasp_raps_spawning) )
			{
				[[level.zm_mixed_wasp_raps_spawning]]();
			}
			else
			{
				spawn_wasp();
			}

			util::wait_network_frame();
		}

		util::wait_network_frame(); // wait network frame between swarms
	}
}


function spawn_wasp()
{
	b_swarm_spawned = false;
			
	while ( !b_swarm_spawned )
	{
		// Spawn limiter - wait until there's space and a place to spawn a wasp, and the spawning flag is set
		while( !ready_to_spawn_wasp() )
		{
			wait( 1.0 );
		}
				
		/* Find the base spawn position for the swarm */
		spawn_point = undefined;
				
		while ( !isdefined( spawn_point ) )
		{
			favorite_enemy = get_favorite_enemy();
			spawn_enemy = favorite_enemy;
			if( !IsDefined( spawn_enemy ) )
			{
				//default to spawn near first player
				spawn_enemy = GetPlayers()[0];
			}
			
			if ( isdefined( level.wasp_spawn_func ) )
			{
				spawn_point = [[ level.wasp_spawn_func ]]( spawn_enemy );
			}
			else
			{
				// Default method
				spawn_point = wasp_spawn_logic( spawn_enemy );
			}
					
			if ( !isdefined( spawn_point ) )
			{
				WAIT_ABOUT( 1 );  // try again after wait
			}
		}
				
		/* Query the navvolume for valid spawn points around base spawn point */
		v_spawn_origin = spawn_point.origin;
		v_ground = GROUNDPOS( undefined, spawn_point.origin + ( 0, 0, N_SPAWN_HEIGHT_MIN ) );
		if ( DistanceSquared( v_ground, spawn_point.origin ) < ( N_SPAWN_HEIGHT_MIN * N_SPAWN_HEIGHT_MIN ) )
		{
			v_spawn_origin = v_ground + ( 0, 0, N_SPAWN_HEIGHT_MIN );
		}
			
		queryResult = PositionQuery_Source_Navigation( v_spawn_origin, 0, 80, 80, 15, "navvolume_small" );
		a_points = array::randomize( queryResult.data );
				
		/* Extra bullettrace to be sure. Save only points that pass test */
				
		a_spawn_origins = [];
			
		// Only check the number of points we need.
		n_points_found = 0;
		foreach ( point in a_points )
		{
			if ( BulletTracePassed( point.origin, spawn_point.origin, false, spawn_enemy ) )
			{
				ARRAY_ADD( a_spawn_origins, point.origin );
				n_points_found++;
				if ( n_points_found >= N_SWARM_SIZE )
				{
					break;
				}
			}
		}
				
		/* Spawn the swarm only if we have found enough safe points for the whole swarm */
		if ( a_spawn_origins.size >= N_SWARM_SIZE )
		{
			n_spawn = 0;
			while ( n_spawn < N_SWARM_SIZE && level.zombie_total > 0 )
			{
				for ( i = a_spawn_origins.size - 1; i >= 0; i-- )
				{
					v_origin = a_spawn_origins[ i ];
							
					level.wasp_spawners[ 0 ].origin = v_origin;
							
					ai = zombie_utility::spawn_zombie( level.wasp_spawners[ 0 ] );
					
					if ( isdefined( ai ) )
					{
						ai parasite::set_parasite_enemy( favorite_enemy );
						level thread wasp_spawn_init( ai, v_origin );
						ArrayRemoveIndex( a_spawn_origins, i );

						if( isdefined(level.zm_wasp_spawn_callback) )
						{
							ai thread [[level.zm_wasp_spawn_callback]]();
						}

						n_spawn++;
						level.zombie_total--;
						WAIT_ABOUT( .1 ); // a little seperation between spawns
						break;
					}
							
					WAIT_ABOUT( .1 ); // a little wait if spawn failed
				}
			}
					
			b_swarm_spawned = true;
		}
			
		util::wait_network_frame(); // wait network frame between swarms
	}
}


function parasite_round_fx()
{
	foreach ( player in level.players )
	{
		player clientfield::increment_to_player( "parasite_round_fx" );
		player clientfield::increment_to_player( PARASITE_ROUND_RING_FX );
	}
}

function show_hit_marker()  // self = player
{
	if ( IsDefined( self ) && IsDefined( self.hud_damagefeedback ) )
	{
		self.hud_damagefeedback SetShader( "damage_feedback", 24, 48 );
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback FadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}	
}

function waspDamage( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if( isdefined(attacker) )
	{
		attacker show_hit_marker();
	}
	return damage;
}

// check if there's space and a place to spawn a wasp, and the spawning flag is set
function ready_to_spawn_wasp()
{
	n_wasps_alive = get_current_wasp_count();

	b_wasp_count_at_max = n_wasps_alive >= N_MAX_WASPS;
	b_wasp_count_per_player_at_max = n_wasps_alive >= level.players.size * N_MAX_WASPS_PER_PLAYER;

	if( b_wasp_count_at_max || b_wasp_count_per_player_at_max || !( level flag::get( "spawn_zombies" ) ) )
	{
		return false;
	}
	return true;
}


function wasp_round_aftermath()
{
	level waittill( "last_ai_down", e_wasp );

	level thread zm_audio::sndMusicSystem_PlayState( "parasite_over" );

	if( isdefined(level.zm_override_ai_aftermath_powerup_drop) )
	{
		[[level.zm_override_ai_aftermath_powerup_drop]]( e_wasp, level.last_ai_origin );
	}
	else
	{
		if( isdefined( level.last_ai_origin ) )
		{		
			enemy = e_wasp.favoriteenemy; 
			if (!IsDefined(enemy))
				enemy = array::random(level.players); 
			enemy parasite_drop_item( level.last_ai_origin );
		}
	}
	
	wait(2);
	level clientfield::set( "toggle_on_parasite_fog", 2 );
	level.sndMusicSpecialRound = false;
	wait(6);

	level flag::clear( "wasp_round_in_progress" );

	//level thread wasp_round_aftermath();
}

// Calculates spawn position for Max Ammo and moves it if in invalid spawn position
function parasite_drop_item( v_parasite_origin )
{	
	if ( !( zm_utility::check_point_in_enabled_zone( v_parasite_origin, true, level.active_zones ) ) )
	{
		// Checks type of item, then spawns item at the parasite's origin
		e_parasite_drop = level zm_powerups::specific_powerup_drop( "full_ammo", v_parasite_origin );
		
		current_zone = self zm_utility::get_current_zone();
		if( isdefined( current_zone ) )
		{
			const n_ground_offset = 20;

			v_start = e_parasite_drop.origin;
						
			e_closest_player = ArrayGetClosest( v_start, level.activeplayers );
			if( isdefined( e_closest_player ) )
			{
				v_target = e_closest_player.origin + (0, 0, n_ground_offset);

				// We know the target position is valid
				// - Project a vector to the target position and drop the item at the first available point along the vector 
				//   that is inside playable space
				
				n_distance_to_target = Distance( v_start, v_target );
				v_dir = VectorNormalize( v_target - v_start );

				n_step = 50;
				n_distance_moved = 0;
				v_position = v_start;
				while( n_distance_moved <= n_distance_to_target )
				{
					v_position += (v_dir * n_step);

					if ( zm_utility::check_point_in_enabled_zone( v_position, true, level.active_zones ) )
					{
						// Only accept the position if the dist to the target ground position isn't too large
						// - This check stops pickups getting stuck on ledges
						n_height_diff = abs( v_target[2] - v_position[2] );
						if( n_height_diff < 60 )
						{
							break;
						}
					}

					n_distance_moved += n_step;
				}

				// Push the drop position to the floor
				trace = bullettrace( v_position, v_position + (0,0,-256 ), false, undefined );
				v_ground_position = trace["position"];
				if( isdefined(v_ground_position) )
				{
					v_position = ( v_position[0], v_position[1], v_ground_position[2] + n_ground_offset );
				}

				// Move to the drop position
				n_flight_time = Distance( v_start, v_position ) / 100;
				if( n_flight_time > 4.0 )
				{
					n_flight_time = 4.0;
				}
				e_parasite_drop MoveTo( v_position, n_flight_time );
			}
			else
			{
				// Failsafe
				v_nav_check = GetClosestPointOnNavMesh( e_parasite_drop.origin, 2000, 32 );
			}
		}
	}
	else
	{
		// If parasite is above navmesh, checks type of item and then spawns item on the ground below the parasite
		level zm_powerups::specific_powerup_drop( "full_ammo", GetClosestPointOnNavMesh( v_parasite_origin, 1000, 30 ) );
	}
}

//
//	Spawn in fx and initialization
// - ai.favoriteenemy = the wasps target
function wasp_spawn_init( ai, origin, should_spawn_fx = true )
{
	ai endon( "death" );
	
	ai SetInvisibleToAll();
	
	if ( isdefined( origin ) )
	{
		v_origin = origin;
	}
	else
	{
		v_origin = ai.origin;
	}
	
	if( should_spawn_fx )
	{
		PlayFx( level._effect["lightning_wasp_spawn"], v_origin );
	}

//	playsoundatposition( "zmb_hellhound_prespawn", v_origin );
	wait( 1.5 );
//	playsoundatposition( "zmb_hellhound_bolt", v_origin );

	Earthquake( 0.3, 0.5, v_origin, 256);
	//PlayRumbleOnPosition("explosion_generic", v_origin);
//	playsoundatposition( "zmb_hellhound_spawn", v_origin );

	// face the enemy
	if ( IsDefined(ai.favoriteenemy) )
		angle = VectorToAngles( ai.favoriteenemy.origin - v_origin );
	else
		angle = ai.angles;
	angles = ( ai.angles[0], angle[1], ai.angles[2] );
		
	//DCS 080714: this should work for an ai vehicle but currently doesn't. Support should be added soon.
	//ai ForceTeleport( v_origin, angles );
	ai.origin = v_origin;
	ai.angles = angles;

	assert( isdefined( ai ), "Ent isn't defined." );
	assert( IsAlive( ai ), "Ent is dead." );

	ai thread zombie_setup_attack_properties_wasp();

	if( isdefined( level._wasp_death_cb ) )
	{
		ai callback::add_callback( #"on_vehicle_killed", level._wasp_death_cb );
	}
	
	ai SetVisibleToAll();
	ai.ignoreme = false; // don't let attack wasp give chase until it is visible
	ai notify( "visible" );
}

//
//	Makes use of the _zm_zone_manager and specially named structs for each zone to
//	indicate wasp spawn locations instead of constantly using ents.
function create_global_wasp_spawn_locations_list()
{
	if( !isdefined(level.enemy_wasp_global_locations) )
	{
		level.enemy_wasp_global_locations = [];	
		keys = GetArrayKeys( level.zones );
		for( i=0; i<keys.size; i++ )
		{
			zone = level.zones[keys[i]];
	
			// add wasp_spawn locations
			foreach( loc in zone.a_locs[ "wasp_location" ] )
			{
				ARRAY_ADD( level.enemy_wasp_global_locations, loc );
			}
		}
	}
}
	
function wasp_find_closest_in_global_pool( favorite_enemy )
{
	index_to_use = 0;
	closest_distance_squared = DistanceSquared( level.enemy_wasp_global_locations[index_to_use].origin, favorite_enemy.origin );
	for( i = 0; i < level.enemy_wasp_global_locations.size; i++ )
	{
		if( level.enemy_wasp_global_locations[i].is_enabled )
		{
			dist_squared = DistanceSquared( level.enemy_wasp_global_locations[i].origin, favorite_enemy.origin );
			if( dist_squared<closest_distance_squared )
			{
				index_to_use = i;
				closest_distance_squared = dist_squared;
			}
		}
	}
	return level.enemy_wasp_global_locations[index_to_use];
}

#define WASP_SPAWN_DIST_MIN 400
#define WASP_SPAWN_DIST_MAX 600
	
function wasp_spawn_logic( favorite_enemy )
{
	if ( !GetDvarInt( "zm_wasp_open_spawning", 0 ) )
	{
		wasp_locs = level.zm_loc_types[ "wasp_location" ];
		
		if ( wasp_locs.size == 0 )
		{
			//none - use backup global pool - just find first within range
			create_global_wasp_spawn_locations_list();
			return wasp_find_closest_in_global_pool( favorite_enemy );
		}
		
		// if the old one is in the desired range, return it so we get bigger swarms
		if ( isdefined( level.old_wasp_spawn ) )
		{
			dist_squared = DistanceSquared( level.old_wasp_spawn.origin, favorite_enemy.origin );
			if ( dist_squared > ( WASP_SPAWN_DIST_MIN * WASP_SPAWN_DIST_MIN ) && dist_squared < ( WASP_SPAWN_DIST_MAX * WASP_SPAWN_DIST_MAX ) )
			{
				return level.old_wasp_spawn;
			}
		}
	
		// Find a spawn point that's in the min/max range and use that
		foreach ( loc in wasp_locs )
		{
			dist_squared = DistanceSquared( loc.origin, favorite_enemy.origin );
			if ( dist_squared > ( WASP_SPAWN_DIST_MIN * WASP_SPAWN_DIST_MIN ) && dist_squared < ( WASP_SPAWN_DIST_MAX * WASP_SPAWN_DIST_MAX ) )
			{
				level.old_wasp_spawn = loc;
				return loc;
			}
		}
	}
	
	/* If we still haven't found a valid spot or we are using open spawing, find something suitable using the navvolume */
	
	const spawn_height_min	= 40;
	const spawn_height_max	= 100;
	const spawn_dist_min	= 300;

	switch( level.players.size )
	{
		case 4:
			spawn_dist_max	= 600;
		break;

		case 3:
			spawn_dist_max	= 700;
		break;

		case 2:
			spawn_dist_max	= 900;
		break;

		default:
		case 1:
			spawn_dist_max	= 1200;
		break;
	}

	queryResult = PositionQuery_Source_Navigation(
		favorite_enemy.origin + ( 0, 0, RandomIntRange( spawn_height_min, spawn_height_max ) ),
		spawn_dist_min,
		spawn_dist_max,
		10,
		10,
		"navvolume_small" );
	
	a_points = array::randomize( queryResult.data );
	
	foreach ( point in a_points )
	{
		if ( BulletTracePassed( point.origin, favorite_enemy.origin, false, favorite_enemy ) )
		{
			level.old_wasp_spawn = point;
			return point;
		}
	}
	
	// Failsafe
	return a_points[0];
}

function get_favorite_enemy()
{
	// First check if we have a priority target
	if( level.a_wasp_priority_targets.size > 0 )
	{
		e_enemy = level.a_wasp_priority_targets[0];
		if( isdefined(e_enemy) )
		{
			ArrayRemoveValue( level.a_wasp_priority_targets, e_enemy );
			return( e_enemy );
		}
	}

	// Check for custom wasp spawner selection
	if ( isdefined( level.fn_custom_wasp_favourate_enemy ) )
	{
		e_enemy = [[ level.fn_custom_wasp_favourate_enemy ]]();
		return( e_enemy );
	}
	
	target = parasite::get_parasite_enemy();
	
	return target;
}


function wasp_health_increase()
{
	players = getplayers();

	level.wasp_health = level.round_number * N_WASP_HEALTH_INCREASE;
	
	if( level.wasp_health > N_WASP_HEALTH_MAX )
	{
		level.wasp_health = N_WASP_HEALTH_MAX;
	}
}


function wasp_round_wait_func()
{
	level endon( "restart_round" );
	level endon( "kill_round" );
	
	if( level flag::get("wasp_round" ) )
	{
		level flag::wait_till( "wasp_round_in_progress" );
		
		level flag::wait_till_clear( "wasp_round_in_progress" );
	}
}

function wasp_round_tracker()
{	
	level.wasp_round_count = 1;
	
	// PI_CHANGE_BEGIN - JMA - making wasp rounds random between round 5 thru 7
	// NOTE:  RandomIntRange returns a random integer r, where min <= r < max

	// Start Round
	level.next_wasp_round = level.round_number + RandomIntRange( 4, 6 );
	// PI_CHANGE_END
	
	old_spawn_func = level.round_spawn_func;
	old_wait_func  = level.round_wait_func;

	while ( 1 )
	{
		level waittill ( "between_round_over" );

		/#
			if( GetDvarInt( "force_wasp" ) > 0 )
			{
				level.next_wasp_round = level.round_number; 
			}
		#/

		if ( level.round_number == level.next_wasp_round )
		{
			level.sndMusicSpecialRound = true;
			old_spawn_func = level.round_spawn_func;
			old_wait_func  = level.round_wait_func;
			wasp_round_start();
			level.round_spawn_func =&wasp_round_spawning;
			level.round_wait_func = &wasp_round_wait_func;

			// Get the next wasp round
			if( isdefined(level.zm_custom_get_next_wasp_round) )
			{
				level.next_wasp_round = [[level.zm_custom_get_next_wasp_round]]();
			}
			else
			{
				//	Setup so this alternates with Raps rounds... probably a better way to do this
				level.next_wasp_round = 5 + (level.wasp_round_count * 10) + RandomIntRange( -1, 1 );
			}
			
			/#
				GetPlayers()[0] iprintln( "Next wasp round: " + level.next_wasp_round );
			#/
		}
		else if ( level flag::get( "wasp_round" ) )
		{
			wasp_round_stop();
			level.round_spawn_func = old_spawn_func;
			level.round_wait_func  = old_wait_func;
			level.wasp_round_count += 1;
		}
	}	
}


function wasp_round_start()
{
	level flag::set( "wasp_round" );
	level flag::set( "special_round" );
	
	if(!isdefined (level.waspround_nomusic))
	{
		level.waspround_nomusic = 0;
	}
	level.waspround_nomusic = 1;
	level notify( "wasp_round_starting" );
	level thread zm_audio::sndMusicSystem_PlayState( "parasite_start" );

	if(isdefined(level.wasp_melee_range))
	{
	 	SetDvar( "ai_meleeRange", level.wasp_melee_range ); 
	}
	else
	{
	 	SetDvar( "ai_meleeRange", 100 ); 
	}
}


function wasp_round_stop()
{
	level flag::clear( "wasp_round" );
	level flag::clear( "special_round" );
	
	if(!isdefined (level.waspround_nomusic))
	{
		level.waspround_nomusic = 0;
	}
	level.waspround_nomusic = 0;
	level notify( "wasp_round_ending" );

 	SetDvar( "ai_meleeRange", level.melee_range_sav ); 
 	SetDvar( "ai_meleeWidth", level.melee_width_sav );
 	SetDvar( "ai_meleeHeight", level.melee_height_sav );
}


function play_wasp_round()
{
	self playlocalsound( "zmb_wasp_round_start" );
	variation_count =5;
	
	wait(4.5);

	players = getplayers();
	num = RandomIntRange(0,players.size);
	players[num] zm_audio::create_and_play_dialog( "general", "wasp_spawn" );
}

function wasp_init()
{
	self.targetname = "zombie_wasp";
	self.script_noteworthy = undefined;
	self.animname = "zombie_wasp"; 		
	self.ignoreall = true; 
	self.ignoreme = true; // don't let attack wasp give chase until the wolf is visible
	self.allowdeath = true; 			// allows death during animscripted calls
	self.allowpain = false;
	self.no_gib = true; //gibbing disabled for now
	self.is_zombie = true; 			// needed for melee.gsc in the animscripts
	// out both legs and then the only allowed stance should be prone.
	self.gibbed = false; 
	self.head_gibbed = false;
	self.default_goalheight = 40;
	self.ignore_inert = true;	
	self.no_eye_glow = true;

	self.lightning_chain_immune = true;

	self.holdfire			= false;

	//	self.disableArrivals = true; 
	//	self.disableExits = true; 
	self.grenadeawareness = 0;
	self.badplaceawareness = 0;

	self.ignoreSuppression = true; 	
	self.suppressionThreshold = 1; 
	self.noDodgeMove = true; 
	self.dontShootWhileMoving = true;
	self.pathenemylookahead = 0;

	self.badplaceawareness = 0;
	self.chatInitialized = false;
	self.missingLegs = false;
	self.isdog = false;
	self.teslafxtag = "tag_origin";

	self.grapple_type = GRAPPLE_TYPE_PULLENTIN;
	self SetGrapplableType( self.grapple_type );

	self.team = level.zombie_team;
	
	self.sword_kill_power = ZM_WASP_SWORD_KILL_POWER;
	
	parasite::parasite_initialize();
/*
	self AllowPitchAngle( 1 );
	self setPitchOrient();
	self setAvoidanceMask( "avoid none" );

	self PushActors( true );
*/
	health_multiplier = 1.0;
	if ( GetDvarString( "scr_wasp_health_walk_multiplier" ) != "" )
	{
		health_multiplier = GetDvarFloat( "scr_wasp_health_walk_multiplier" );
	}

	self.maxhealth = int( level.wasp_health * health_multiplier );
	if( IsDefined(level.a_zombie_respawn_health[ self.archetype ] ) && level.a_zombie_respawn_health[ self.archetype ].size > 0 )
	{
		self.health = level.a_zombie_respawn_health[ self.archetype ][0];
		ArrayRemoveValue(level.a_zombie_respawn_health[ self.archetype ], level.a_zombie_respawn_health[ self.archetype ][0]);		
	}
	else
	{
		self.health = int( level.wasp_health * health_multiplier );
	}

	self thread wasp_run_think();
	self thread watch_player_melee();

	self SetInvisibleToAll();

	self thread wasp_death();
	self thread wasp_cleanup_failsafe();
	
	level thread zm_spawner::zombie_death_event( self ); 
	self thread zm_spawner::enemy_death_detection();

	self.thundergun_knockdown_func =&wasp_thundergun_knockdown;
	
	self zm_spawner::zombie_history( "zombie_wasp_spawn_init -> Spawned = " + self.origin );
	
	if ( isdefined(level.achievement_monitor_func) )
	{
		self [[level.achievement_monitor_func]]();
	}
}


function wasp_thundergun_knockdown( e_player, gib )
{
	self endon( "death" );

	n_damage = Int( self.maxhealth * 0.5 );
	self DoDamage( n_damage, self.origin, e_player );
}

#define N_WASP_NOT_MOVED_TIMEOUT	20
#define N_WASP_MAX_LIFE_TIMEOUT		150
#define N_WASP_HAS_MOVE_DIST		100
#define	N_MSEC						1000

// Wasp failsafe cleanup conditions
function wasp_cleanup_failsafe()
{
	self endon( "death" );

	n_wasp_created_time = GetTime();
	
	n_check_time = n_wasp_created_time;
	v_check_position = self.origin;

	while( true )
	{
		n_current_time = GetTime();
		
		if( IS_TRUE( level.bzm_worldPaused ) )
		{
			n_check_time = n_current_time; //reset the stuck time when world is paused
			wait 1;
			continue;
		}
		
		// If the wasp has moved he is not stuck, so reset the position to check against
		n_dist = Distance( v_check_position, self.origin );
		if( n_dist > N_WASP_HAS_MOVE_DIST )
		{
			n_check_time = n_current_time;
			v_check_position = self.origin;
		}

		// Failsafe 1: If the wasp hasn't significantly moved for a while, kill him
		else
		{
			n_delta_time = ( n_current_time - n_check_time ) / N_MSEC;
			if( n_delta_time >= N_WASP_NOT_MOVED_TIMEOUT )
			{
				break;
			}
		}

		// Failsafe 2: If the wasp has been alive for too long, kill him
		n_delta_time = ( n_current_time - n_wasp_created_time ) / N_MSEC;
		if( n_delta_time >= N_WASP_MAX_LIFE_TIMEOUT )
		{
			break;
		}

		wait 1;
	}

	self DoDamage( self.health + 100, self.origin );
}

function wasp_death()
{
	self waittill( "death", attacker );
	
	if ( get_current_wasp_count() == 0 && level.zombie_total == 0 )
	{
		// Can be overridded for mixed AI rounds, in this case the last AI may be a wasp or raps etc...
		if( ( !isdefined(level.zm_ai_round_over) || [[level.zm_ai_round_over]]() ) )
		{
			level.last_ai_origin = self.origin;
			level notify( "last_ai_down", self );
		}
	}
	
	// score
	if( IsPlayer( attacker ) )
	{
		if( IS_TRUE(attacker.on_train) )
		{
			attacker notify( "wasp_train_kill" );
		}

		attacker zm_score::player_add_points( "death_wasp", N_WASP_KILL_POINTS );	// points awarded
		
		if( isdefined(level.hero_power_update))
		{
			[[level.hero_power_update]](attacker, self);
		}
	    
	    if( RandomIntRange(0,100) >= 80 )
	    {
	        attacker zm_audio::create_and_play_dialog( "kill", "hellhound" );
	    }
	    
	    //stats
		attacker zm_stats::increment_client_stat( "zwasp_killed" );
		attacker zm_stats::increment_player_stat( "zwasp_killed" );

	}

	// switch to inflictor when SP DoDamage supports it
	if( isdefined( attacker ) && isai( attacker ) )
	{
		attacker notify( "killed", self );
	}

	// sound
	self stoploopsound();
}


// this is where zombies go into attack mode, and need different attributes set up
function zombie_setup_attack_properties_wasp()
{
	self zm_spawner::zombie_history( "zombie_setup_attack_properties()" );
	
	self thread wasp_behind_audio();

	// allows zombie to attack again
	self.ignoreall = false; 

	//self.pathEnemyFightDist = 64;
	self.meleeAttackDist = 64;

	// turn off transition anims
	self.disableArrivals = true; 
	self.disableExits = true;
		
	if( level.wasp_round_count == 2 )
	{
		self ai::set_behavior_attribute( "firing_rate", "medium" );
	}
	else if( level.wasp_round_count > 2 )
	{
		self ai::set_behavior_attribute( "firing_rate", "fast" );
	}
}


//COLLIN'S Audio Scripts
function stop_wasp_sound_on_death()
{
	self waittill("death");
	self stopsounds();
}

function wasp_behind_audio()
{
	self thread stop_wasp_sound_on_death();

	self endon("death");
	self util::waittill_any( "wasp_running", "wasp_combat" );
	
//	self PlaySound( "zmb_hellhound_vocals_close" );
	wait( 3 );

	while(1)
	{
		players = GetPlayers();
		for(i=0;i<players.size;i++)
		{
			waspAngle = AngleClamp180( vectorToAngles( self.origin - players[i].origin )[1] - players[i].angles[1] );
		
			if(isAlive(players[i]) && !isdefined(players[i].revivetrigger))
			{
				if ((abs(waspAngle) > 90) && distance2d(self.origin,players[i].origin) > 100)
				{
//					self playsound( "zmb_hellhound_vocals_close" );
					wait( 3 );
				}
			}
		}
		
		wait(.75);
	}
}


//
//	Allows wasp to be spawned independent of the round spawning
/@
"Name: special_wasp_spawn(<n_to_spawn>, <spawn_point>, <radius> , <half-height> )"
"Summary: Allows wasp to be spawned independent of the round spawning. Can return spawned AI or boolean."
"Module: zm_ai_wasp"
"MandatoryArg: <spawn_point> - position where parasite will be spawned"	
"OptionalArg: <n_to_spawn> - Number to spawn, if left undefined, 1 will spawn."
"OptionalArg: <radius> - Radius horizontally that the parasite can spawn in from the spawn_point.  Defaults to 32 units"
"OptionalArg: <half_height> - Vertical offset that the parasite can spawn in from the spawn_point. Defaults to 32 units"
"OptionalArg: <b_non_round> - If true, parasite will not count to completing a parasite round, nor will it drop Xenomatter"
"OptionalArg: <spawn_fx> - Whether to use the parasite spawn fx or not. Defaults to true"
"OptionalArg: <b_return_ai> - If true, returns the wasp entity. Defaults to false"	
"OptionalArg: <spawner_override> - Specify a spawner to use instead of the default level wasp spawner.  Defaults to undefined"	
"Example: self zm_ai_wasp::special_wasp_spawn( s_temp, 1 );"
"SPMP: Zombie"
@/
function special_wasp_spawn( n_to_spawn = 1, spawn_point, n_radius = 32, n_half_height = 32, b_non_round, spawn_fx = true, b_return_ai = false, spawner_override = undefined )
{
	wasp = GetEntArray( "zombie_wasp", "targetname" );

	if ( isdefined( wasp ) && wasp.size >= 9 )
	{
		return false;
	}
	
	count = 0;
	while ( count < n_to_spawn )
	{
		//update the player array.
		players = GetPlayers();
		favorite_enemy = get_favorite_enemy();
		spawn_enemy = favorite_enemy;
		if( !IsDefined( spawn_enemy ) )
		{
			spawn_enemy = players[0];
		}

		// Overrides standard parasite spawning
		if ( isdefined( level.wasp_spawn_func ) )
		{
			spawn_point = [[level.wasp_spawn_func]]( spawn_enemy );
		}
		
		// Rarely spawn_point will be undefined
		while ( !isdefined( spawn_point ) )
		{
			if ( !isdefined( spawn_point ) )
			{
				spawn_point = wasp_spawn_logic( spawn_enemy );
			}
			
			if ( isdefined( spawn_point ) )
			{
				break;
			}
			
			wait( 0.05 );
		}
		
		spawner = level.wasp_spawners[0];

		if( isDefined( spawner_override))
		{
			spawner = spawner_override;
		}
			
		ai = zombie_utility::spawn_zombie( spawner );
		
		v_spawn_origin = spawn_point.origin;
			
		if ( isdefined( ai ) )
		{
			// just try to path strait to a nearby position on the path
			queryResult = PositionQuery_Source_Navigation( v_spawn_origin, 0, n_radius, n_half_height, 15, "navvolume_small" );
			if( queryResult.data.size )
			{
				point = queryResult.data[ randomint( queryResult.data.size ) ];	
				v_spawn_origin = point.origin;
			}
			
			ai parasite::set_parasite_enemy( favorite_enemy );
			ai.does_not_count_to_round = b_non_round;
			level thread wasp_spawn_init( ai, v_spawn_origin, spawn_fx );
			count++;
		}

		wait level.zombie_vars[ "zombie_spawn_delay" ];
	}

	if ( b_return_ai )
	{
		return ai;
	}
	
	return true;
}

function wasp_run_think()
{
	self endon( "death" );

	// these should go back in when the stalking stuff is put back in, the visible check will do for now
	//self util::waittill_any( "wasp_running", "wasp_combat" );
	//self playsound( "zwasp_close" );
	self waittill( "visible" );
	
	// decrease health
	if ( self.health > level.wasp_health )
	{
		self.maxhealth = level.wasp_health;
		self.health = level.wasp_health;
	}
	
	//Check to see if the enemy is not valid anymore
	while( 1 )
	{
		if( !zm_utility::is_player_valid(self.favoriteenemy) )
		{
			//We are targetting an invalid player - select another one
			//self.favoriteenemy = get_favorite_enemy();
		}
		wait( 0.2 );
	}
}

#define MELEE_RANGE_SQ (72 * 72)
#define MELEE_RANGE_Z  (64)
#define MELEE_VIEW_DOT 0.5

function watch_player_melee()
{
	self endon( "death" );
	self waittill( "visible" );

	while( IsDefined(self) )
	{
		level waittill( "player_melee", player, weapon );

		peye = player GetEye(); 
		dist2 = Distance2DSquared( peye, self.origin );
		if ( dist2 > MELEE_RANGE_SQ )
			continue;

		if ( abs( peye[2] - self.origin[2]) > MELEE_RANGE_Z )
			continue;
		         
		pfwd = player GetWeaponForwardDir();
		tome = self.origin - peye; 
		tome = VectorNormalize( tome );
		dot = VectorDot( pfwd, tome );
		if ( dot < MELEE_VIEW_DOT )
			continue;

		damage = 150; 
		if ( IsDefined(weapon) )
			damage = weapon.meleedamage;
		
		self DoDamage( damage, peye, player, player, "none", "MOD_MELEE", 0, weapon );
	}
}

function watch_player_melee_events()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "weapon_melee", weapon );
		level notify( "player_melee", self, weapon );
	}
}

function wasp_stalk_audio()
{
	self endon( "death" );
	self endon( "wasp_running" );
	self endon( "wasp_combat" );
	
	while(1)
	{
//		self playsound( "zmb_hellhound_vocals_amb" );
		wait randomfloatrange(3,6);		
	}
}

function wasp_add_to_spawn_pool( optional_player_target )
{
	if( isdefined(optional_player_target) )
	{
		array::add( level.a_wasp_priority_targets, optional_player_target );
	}
	level.zombie_total++;
}

