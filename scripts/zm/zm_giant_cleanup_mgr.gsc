#insert scripts\shared\shared.gsh;

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_zonemgr;


#namespace giant_cleanup;

#define TRACKING_INNER_DIST					2000
#define TRACKING_OUTER_DIST					2200
#define TOO_HIGH_DIST						800

#define N_CLEANUP_INTERVAL_MIN				3000	// Minimum time in msec for cleanup checks
#define N_CLEANUP_AGE_MIN					5000	// You must be this old (in msec) before considering for cleanup
#define N_CLEANUP_AGE_TIMEOUT				45000	// If you are at least this old (in msec) then allow cleanup no matter what
#define N_CLEANUP_EVALS_PER_FRAME_MAX		1		// Maximum number of AI to process per frame
#define N_CLEANUP_FOV_COS					0.766	// cos(40) == 80 degree FOV
#define N_CLEANUP_DIST_SQ_MIN_AGGRESSIVE	189225	// Minimum distance squared.  435^2
#define N_CLEANUP_DIST_SQ_MIN				250000	// Minimum distance squared.  500^2
#define N_CLEANUP_DIST_SQ_ROUND_END			2250000	// Minimum distance squared.  1500^2
	
REGISTER_SYSTEM_EX( "giant_cleanup", &__init__, &__main__, undefined )


#define N_MSEC 1000

	
function __init__()
{
	level.n_cleanups_processed_this_frame = 0;
}

function __main__()
{
	level thread cleanup_main();
}

function force_check_now()
{
	level notify( "pump_distance_check" );
}

// Periodically loop through the AI to see if they need cleanup
function private cleanup_main()
{
	n_next_eval = 0;
	
	while ( true )
	{
		util::wait_network_frame();

		n_time = GetTime();
		if ( n_time < n_next_eval )
		{
			continue;
		}

		// Has the cleanup manager been delayed?
		if( isdefined(level.n_cleanup_manager_restart_time) )
		{
			n_current_time = gettime() / N_MSEC;
			n_delta_time = n_current_time - level.n_cleanup_manager_restart_time;
			if( n_delta_time < 0 )
			{
				continue;
			}
			level.n_cleanup_manager_restart_time = undefined;
		}

		// Don't do cleanup early in the round, attempt to stop lulls between rounds
		n_round_time = ( n_time - level.round_start_time ) / N_MSEC;
		if( (level.round_number <= 5) && (n_round_time < 30) )
		{
			continue;
		}
		else if( (level.round_number > 5) && (n_round_time < 20) )
		{
			continue;
		}

		// If there are no zombies left to spawn in the round AND there are less then 3 zombies alive, then use a much bigger cleanup distance check
		// This will stop the last zombie constantly despawning and respawning if the players are running around looking for him
		n_override_cleanup_dist_sq = undefined;
		if( ( level.zombie_total == 0 ) && ( zombie_utility::get_current_zombie_count() < 3 ) )
		{
			n_override_cleanup_dist_sq = N_CLEANUP_DIST_SQ_ROUND_END;
		}
		
		n_next_eval += N_CLEANUP_INTERVAL_MIN;

		// Process all enemies alive at this point in time
		a_ai_enemies = GetAITeamArray( "axis" );
		foreach( ai_enemy in a_ai_enemies )
		{
			if ( level.n_cleanups_processed_this_frame >= N_CLEANUP_EVALS_PER_FRAME_MAX )
			{
				level.n_cleanups_processed_this_frame = 0;
				util::wait_network_frame();
			}

			ai_enemy do_cleanup_check( n_override_cleanup_dist_sq );
		}		
	}
}


//	Check to see if we need to be cleaned up
//	self is an ai
function do_cleanup_check( n_override_cleanup_dist )
{
	if ( !IsAlive( self ) )
	{
		return;
	}

	if ( self.b_ignore_cleanup === true )
	{
		return;
	}

	n_time_alive = GetTime() - self.spawn_time;
	if ( n_time_alive < N_CLEANUP_AGE_MIN )
	{
		return;
	}

	
	// Try not to clean up guys who are just trying to break through boards before they get through.
	//   But we still have to do something in case they get stuck...
	//if( IS_EQUAL( self.archetype, ARCHETYPE_ZOMBIE ) )
	{
		if ( n_time_alive < N_CLEANUP_AGE_TIMEOUT &&
		     self.script_string !== "find_flesh" &&
		     self.completed_emerging_into_playable_area !== true )
		{
			return;
		}
	}

	// If we're not in an Active zone, we are a candidate to be cleaned up.
	b_in_active_zone = self zm_zonemgr::entity_in_active_zone();
	level.n_cleanups_processed_this_frame++;
	
	if ( !b_in_active_zone )
	{
		// Minimum distance check.  Don't delete if you're too close to players
		n_dist_sq_min = 10000000;	// lowest distance squared value, init to a very large value
		e_closest_player = level.activeplayers[0];
		foreach( player in level.activeplayers )
		{
			n_dist_sq = DistanceSquared( self.origin, player.origin );
			if ( n_dist_sq < n_dist_sq_min )
			{
				n_dist_sq_min = n_dist_sq;
				e_closest_player = player;
			}                      
		}

		// Get the required distance check
		if( isdefined(n_override_cleanup_dist) )
		{
			n_cleanup_dist_sq = n_override_cleanup_dist;
		}
		// If the player is ahead of me, use an aggressive closer distance check
		else if( isdefined(e_closest_player) && player_ahead_of_me( e_closest_player ) )
		{
			n_cleanup_dist_sq = N_CLEANUP_DIST_SQ_MIN_AGGRESSIVE;
		}
		else
		{
			n_cleanup_dist_sq = N_CLEANUP_DIST_SQ_MIN;
		}
		
		// Distance check
		if ( n_dist_sq_min >= n_cleanup_dist_sq )
		{
			// process for cleanup
			self thread delete_zombie_noone_looking();
		}
	}
}
	

//-------------------------------------------------------------------------------
//  Deletes the zombie and adds him back into the queue if unseen & out of range.
//
//	self = zombie
//-------------------------------------------------------------------------------
function private delete_zombie_noone_looking()
{
	// exclude rising zombies that haven't finished rising.
	if( IS_TRUE( self.in_the_ground ) )
	{
		return;
	}
	
	foreach ( player in level.players )
	{
		// pass through players in spectator mode.
		if( player.sessionstate == "spectator" )
		{
			continue;
		}		
		
		if( self player_can_see_me( player ) )
		{
			return;
		}
	}	

	// put him back into the list to be respawned.
	if ( !IS_TRUE( self.exclude_cleanup_adding_to_total ) )
	{
		level.zombie_total++;
		level.zombie_respawns++;	// Increment total of zombies needing to be respawned
		
		if(self.health < self.maxhealth)
		{
			if ( !isdefined( level.a_zombie_respawn_health[ self.archetype ] ) )
			{
				level.a_zombie_respawn_health[ self.archetype ] = [];
			}
			ARRAY_ADD( level.a_zombie_respawn_health[ self.archetype ], self.health);
		}
	}
	
	self zombie_utility::reset_attack_spot();
	self Kill(); 
	wait( 0.05 );	// allow death to process
	
	if ( isdefined( self ) )
	{
	
			
		self Delete();
	}
}


//-------------------------------------------------------------------------------
// Utility for checking if the player can see the zombie (ai).
// Just does a simple FOV check.
//	self is the entity to check against
//-------------------------------------------------------------------------------
function private player_can_see_me( player )
{
	v_player_angles = player GetPlayerAngles();
	v_player_forward = AnglesToForward( v_player_angles );

	v_player_to_self = self.origin - player GetOrigin();
	v_player_to_self = VectorNormalize( v_player_to_self );

	n_dot = VectorDot( v_player_forward, v_player_to_self );
	if ( n_dot < N_CLEANUP_FOV_COS )
	{
		return false;
	}
	
	return true;
}

//-------------------------------------------------------------------------------
//	self is the entity to check against
//-------------------------------------------------------------------------------
function private player_ahead_of_me( player )
{
	v_player_angles = player GetPlayerAngles();
	v_player_forward = AnglesToForward( v_player_angles );

	v_dir = player GetOrigin() - self.origin;
	
	n_dot = VectorDot( v_player_forward, v_dir );
	if ( n_dot < 0 )
	{
		return false;
	}
	
	return true;
}


//-------------------------------------------------------------------------------
// Cleanup for when zombies have bad pathing.
//-------------------------------------------------------------------------------

function get_escape_position()  // self = AI
{
	self endon( "death" );
	
	// get zombie's current zone
	str_zone = self.zone_name;
	
	//if not in a zone use the zone they were spawned from
	if( !IsDefined( str_zone ) )
	{
		str_zone = self.zone_name;
	}
	
	// get adjacent zones to current zone
	if ( IsDefined( str_zone ) )
	{
		a_zones = get_adjacencies_to_zone( str_zone );
		
		// get all dog locations in all zones + adjacencies
		a_wait_locations = get_wait_locations_in_zones( a_zones );
		
		// find farthest point away
		s_farthest = self get_farthest_wait_location( a_wait_locations );
	}
	
	// return farthest
	return s_farthest;
}


function get_adjacencies_to_zone( str_zone )
{
	a_adjacencies = [];
	a_adjacencies[ 0 ] = str_zone;  // the return value of this array will be referenced directly, so make sure initial zone is included
	
	a_adjacent_zones = GetArrayKeys( level.zones[ str_zone ].adjacent_zones );
	for ( i = 0; i < a_adjacent_zones.size; i++ )
	{
		if ( level.zones[ str_zone ].adjacent_zones[ a_adjacent_zones[ i ] ].is_connected )
		{
			ARRAY_ADD( a_adjacencies, a_adjacent_zones[ i ] );
		}
	}
	
	return a_adjacencies;
}


function private get_wait_locations_in_zones( a_zones )
{
	a_wait_locations = [];
	
	foreach ( zone in a_zones )
	{
		a_wait_locations = ArrayCombine( a_wait_locations, level.zones[ zone ].a_loc_types[ "dog_location" ], false, false );
	}
	
	return a_wait_locations;
}


// self == AI
function private get_farthest_wait_location( a_wait_locations )
{
	if ( !isdefined( a_wait_locations ) || a_wait_locations.size == 0 )
	{
		return undefined;
	}
	
	n_farthest_index = 0;  // initialization
	n_distance_farthest = 0;
	for ( i = 0; i < a_wait_locations.size; i++ )
	{
		
		n_distance_sq = DistanceSquared( self.origin, a_wait_locations[ i ].origin );
		
		if ( n_distance_sq > n_distance_farthest )
		{
			n_distance_farthest = n_distance_sq;
			n_farthest_index = i;
		}
	}
	
	return a_wait_locations[ n_farthest_index ];
}


function private get_wait_locations_in_zone( zone )
{
	if( isdefined(level.zones[ zone ].a_loc_types[ "dog_location" ]) )
	{
		a_wait_locations = [];
		a_wait_locations = ArrayCombine( a_wait_locations, level.zones[ zone ].a_loc_types[ "dog_location" ], false, false );
		return a_wait_locations;
	}
	return( undefined );
}


// self = AI
function get_escape_position_in_current_zone()
{
	self endon( "death" );
	
	// get zombie's current zone
	str_zone = self.zone_name; 
	
	//if not in a zone use the zone they were spawned from
	if( !IsDefined( str_zone ) )
	{
		str_zone = self.zone_name;
	}

	if ( IsDefined( str_zone ) )
	{
		// get all wait locations in this zone
		a_wait_locations = get_wait_locations_in_zone( str_zone );
		
		// find farthest point away
		if( isdefined(a_wait_locations) )
		{
			s_farthest = self get_farthest_wait_location( a_wait_locations );
		}
	}
	
	return s_farthest;
}
