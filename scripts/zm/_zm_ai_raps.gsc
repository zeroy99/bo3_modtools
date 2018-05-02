#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicles\_raps;
#using scripts\shared\clientfield_shared;
#using scripts\shared\visionset_mgr_shared;

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

#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\zm\_zm_utility.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_ai_raps.gsh;

#precache( "fx", "zombie/fx_meatball_trail_sky_zod_zmb" );
#precache( "fx", "zombie/fx_meatball_impact_ground_tell_zod_zmb" );
#precache( "fx", "zombie/fx_meatball_portal_sky_zod_zmb" );
//#precache( "fx", "zombie/fx_raps_eyes_zmb" );
#precache( "fx", "zombie/fx_meatball_impact_ground_zod_zmb" );
#precache( "fx", "zombie/fx_meatball_trail_ground_zod_zmb" );
#precache( "fx", "zombie/fx_meatball_explo_zod_zmb" );

// Number of RAPs to spawn, accurately weighted for the number of players
#define N_NUM_RAPS_PER_ROUND_1PLAYER	10	// 10
#define N_NUM_RAPS_PER_ROUND_2PLAYER	18	// 18
#define N_NUM_RAPS_PER_ROUND_3PLAYER	28	// 34
#define N_NUM_RAPS_PER_ROUND_4PLAYER	34	// 44

#define N_RAPS_HEALTH_INCREASE		50	// Amount to increase RAPS health
#define N_RAPS_HEALTH_MAX		  1600	// Maximum health
#define N_RAPS_KILL_POINTS			70	// Points per kill

#define N_RAPS_DROP_HEIGHT_MAX	   720	// Maximum height to fall from
#define N_RAPS_DROP_SPEED		   720	// Fall speed Units/sec

#define N_RAPS_SPAWN_DELAY_1P	   2.25 // Delay between spawns 1st round
#define N_RAPS_SPAWN_DELAY_2P	   1.75	// Delay between spawns 2nd round
#define N_RAPS_SPAWN_DELAY_3P	   1.25	// Delay between spawns 3rd round
#define N_RAPS_SPAWN_DELAY_4P	   0.75	// Delay between spawns thereafter


#namespace zm_ai_raps;


//*****************************************************************************
//*****************************************************************************

function init()
{
	level.raps_enabled = true;
	level.raps_rounds_enabled = false;
	level.raps_round_count = 1;

	level.raps_spawners = [];

	level flag::init( "raps_round" );
	level flag::init( "raps_round_in_progress" );

	level.melee_range_sav  = GetDvarString( "ai_meleeRange" );
	level.melee_width_sav = GetDvarString( "ai_meleeWidth" );
	level.melee_height_sav  = GetDvarString( "ai_meleeHeight" );

	DEFAULT( level.vsmgr_prio_overlay_zm_raps_round, ZM_ELEMENTAL_VISION_OVERLAY_PRIORITY );
	
	clientfield::register( "toplayer", "elemental_round_fx", VERSION_SHIP, 1, "counter" );
	clientfield::register( "toplayer", ELEMENTAL_ROUND_RING_FX, VERSION_SHIP, 1, "counter" );
		
	visionset_mgr::register_info( "visionset", ZM_ELEMENTAL_ROUND_VISIONSET, VERSION_SHIP, level.vsmgr_prio_overlay_zm_raps_round, ZM_ELEMENTAL_VISION_LERP_COUNT, false, &visionset_mgr::ramp_in_out_thread, false );
	
	level._effect[ "raps_meteor_fire" ]		= "zombie/fx_meatball_trail_sky_zod_zmb";
	level._effect[ "raps_ground_spawn" ]	= "zombie/fx_meatball_impact_ground_tell_zod_zmb";
	level._effect[ "raps_portal" ]			= "zombie/fx_meatball_portal_sky_zod_zmb";
	level._effect[ "raps_gib" ]				= "zombie/fx_meatball_explo_zod_zmb";
	level._effect[ "raps_trail_blood" ]		= "zombie/fx_meatball_trail_ground_zod_zmb";
	level._effect[ "raps_impact" ]			= "zombie/fx_meatball_impact_ground_zod_zmb";

	// AAT IMMUNITIES
	level thread aat::register_immunity( ZM_AAT_BLAST_FURNACE_NAME, ARCHETYPE_RAPS, false, true, false );
	level thread aat::register_immunity( ZM_AAT_DEAD_WIRE_NAME, ARCHETYPE_RAPS, true, true, true );
	level thread aat::register_immunity( ZM_AAT_FIRE_WORKS_NAME, ARCHETYPE_RAPS, true, true, true );
	level thread aat::register_immunity( ZM_AAT_THUNDER_WALL_NAME, ARCHETYPE_RAPS, false, false, true );
	level thread aat::register_immunity( ZM_AAT_TURNED_NAME, ARCHETYPE_RAPS, true, true, true );
	
	// Init raps targets - mainly for testing purposes.
	//	If you spawn a raps without having a raps round, you'll get SREs on hunted_by.
	raps_spawner_init();
}


//*****************************************************************************
// If you want to enable raps rounds, then call this.
//	- Specify an override func if needed.
//*****************************************************************************

function enable_raps_rounds()
{
	level.raps_rounds_enabled = true;

	if( !isdefined( level.raps_round_track_override ) )
	{
		level.raps_round_track_override = &raps_round_tracker;
	}

	level thread [[level.raps_round_track_override]]();
}


//*****************************************************************************
// Initialization
//*****************************************************************************

function raps_spawner_init()
{
	level.raps_spawners = getEntArray( "zombie_raps_spawner", "script_noteworthy" ); 
	later_raps = getentarray("later_round_raps_spawners", "script_noteworthy" );
	level.raps_spawners = ArrayCombine( level.raps_spawners, later_raps, true, false );
	
	if( level.raps_spawners.size == 0 )
	{
		return;
	}
	
	for( i = 0; i < level.raps_spawners.size; i++ )
	{
		if ( zm_spawner::is_spawner_targeted_by_blocker( level.raps_spawners[i] ) )
		{
			level.raps_spawners[i].is_enabled = false;
		}
		else
		{
			level.raps_spawners[i].is_enabled = true;
			level.raps_spawners[i].script_forcespawn = true;
		}
	}

	assert( level.raps_spawners.size > 0 );
	level.n_raps_health = 100;

	vehicle::add_main_callback( "spawner_enemy_zombie_vehicle_raps_suicide", &raps_init );
}


//*****************************************************************************
// Checks at the start of a round if its time for a raps round
//*****************************************************************************

function raps_round_tracker()
{	
	level.raps_round_count = 1;
	
	// PI_CHANGE_BEGIN - JMA - making raps rounds random between round 5 thru 7
	// NOTE:  RandomIntRange returns a random integer r, where min <= r < max
	level.n_next_raps_round = RandomIntRange( 9, 11 );
	// PI_CHANGE_END
	
	old_spawn_func = level.round_spawn_func;
	old_wait_func  = level.round_wait_func;

	while ( 1 )
	{
		level waittill ( "between_round_over" );

		/#
			if( GetDvarInt( "force_raps" ) > 0 )
			{
				level.n_next_raps_round= level.round_number; 
			}
		#/

		if( level.round_number == level.n_next_raps_round )
		{
			level.sndMusicSpecialRound = true;
			old_spawn_func = level.round_spawn_func;
			old_wait_func = level.round_wait_func;
			
			raps_round_start();
			
			level.round_spawn_func = &raps_round_spawning;
			level.round_wait_func = &raps_round_wait_func;

			// Get the next raps round
			if( isdefined(level.zm_custom_get_next_raps_round) )
			{
				level.n_next_raps_round = [[level.zm_custom_get_next_raps_round]]();
			}
			else
			{
				//	Alternating with Wasps, so every other special round...there's probably a better way to do this
				level.n_next_raps_round = 10 + (level.raps_round_count * 10) + RandomIntRange( -1, 1 );
			}

			/#
				GetPlayers()[0] iprintln( "Next raps round: " + level.n_next_raps_round);
			#/
		}
		else if ( level flag::get( "raps_round" ) )
		{
			raps_round_stop();
			level.round_spawn_func = old_spawn_func;
			level.round_wait_func  = old_wait_func;
			level.raps_round_count++;
		}
	}	
}


//*****************************************************************************
//*****************************************************************************

function raps_round_start()
{
	level flag::set( "raps_round" );
	level flag::set( "special_round" );
	
	if(!isdefined (level.rapsround_nomusic))
	{
		level.rapsround_nomusic = 0;
	}
	level.rapsround_nomusic = 1;
	level notify( "raps_round_starting" );
	level thread zm_audio::sndMusicSystem_PlayState( "meatball_start" );

	if(isdefined(level.raps_melee_range))
	{
	 	SetDvar( "ai_meleeRange", level.raps_melee_range ); 
	}
	else
	{
	 	SetDvar( "ai_meleeRange", 100 ); 
	}
}


//*****************************************************************************
//*****************************************************************************

function raps_round_stop()
{
	level flag::clear( "raps_round" );
	level flag::clear( "special_round" );
	
	//zm_utility::play_sound_2D( "mus_zombie_raps_end" );	
	if(!isdefined (level.rapsround_nomusic))
	{
		level.rapsround_nomusic = 0;
	}
	level.rapsround_nomusic = 0;
	level notify( "raps_round_ending" );

 	SetDvar( "ai_meleeRange", level.melee_range_sav ); 
 	SetDvar( "ai_meleeWidth", level.melee_width_sav );
 	SetDvar( "ai_meleeHeight", level.melee_height_sav );
}


//*****************************************************************************
//*****************************************************************************

function raps_round_spawning()
{
	level endon( "intermission" );
	level endon( "raps_round" );

	level.raps_targets = GetPlayers();
	for( i = 0 ; i < level.raps_targets.size; i++ )
	{
		level.raps_targets[i].hunted_by = 0;
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
	
	array::thread_all( level.players,&play_raps_round );
	
	// Calculate wave size
	n_wave_count = get_raps_spawn_total();

	// Health increases on round basis
	raps_health_increase();
	
	level.zombie_total = Int( n_wave_count );

/#
	if( GetDvarString( "force_raps" ) != "" && GetDvarInt( "force_raps" ) > 0 )
 	{
 		level.zombie_total = GetDvarInt( "force_raps" );
		SetDvar( "force_raps", 0 );
	}
 #/		

	wait 1;
	
	elemental_round_fx();
	visionset_mgr::activate( "visionset", ZM_ELEMENTAL_ROUND_VISIONSET, undefined, ZM_ELEMENTAL_RING_ENTER_DURATION, ZM_ELEMENTAL_RING_LOOP_DURATION, ZM_ELEMENTAL_RING_EXIT_DURATION );
	PlaySoundAtPosition( "vox_zmba_event_rapsstart_0", ( 0, 0, 0 ) );
	
	wait 6; // wait before spawning raps

	n_raps_alive = 0;

	// Start spawning loop
	level flag::set( "raps_round_in_progress" );

	level endon( "last_ai_down" );
	
	level thread raps_round_aftermath();

	while( true )
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
				spawn_raps();
			}

			util::wait_network_frame();
		}

		util::wait_network_frame();
	}
}


function spawn_raps()
{
	// Spawn limiter - wait until there's space and a place to spawn a raps, and the spawning flag is set
	while( !can_we_spawn_raps() )
	{
		wait 0.1;
	}

	/* Find the base spawn position for the swarm */
	s_spawn_loc = undefined;

	favorite_enemy = get_favorite_enemy();
			
	if( !IsDefined( favorite_enemy ) )
	{
		WAIT_ABOUT( 0.5 );  // try again after wait
		return;
	}

	if ( isdefined( level.raps_spawn_func ) )
	{
		s_spawn_loc = [[level.raps_spawn_func]]( favorite_enemy );
	}
	else
	{
		// Default method
		s_spawn_loc = calculate_spawn_position( favorite_enemy );
	}

	if ( !isdefined( s_spawn_loc ) )
	{
		WAIT_ABOUT( 0.5 );  // try again after wait
		return;
	}
			
	ai = zombie_utility::spawn_zombie( level.raps_spawners[0] );
	if( isdefined( ai ) ) 	
	{
		ai.favoriteenemy = favorite_enemy;
		ai.favoriteenemy.hunted_by++;
		s_spawn_loc thread raps_spawn_fx( ai, s_spawn_loc );
		level.zombie_total--;
		waiting_for_next_raps_spawn();
	}
}


//*****************************************************************************
// Its better to tune to specific player numbers than use a scaler
//*****************************************************************************

function get_raps_spawn_total()
{
	switch( level.players.size )
	{
		case 1:
			n_wave_count = N_NUM_RAPS_PER_ROUND_1PLAYER;
		break;

		case 2:
			n_wave_count = N_NUM_RAPS_PER_ROUND_2PLAYER;
		break;

		case 3:
			n_wave_count = N_NUM_RAPS_PER_ROUND_3PLAYER;
		break;

		default:
		case 4:
			n_wave_count = N_NUM_RAPS_PER_ROUND_4PLAYER;
		break;
	}

	return( n_wave_count );
}


//*****************************************************************************
//*****************************************************************************

function raps_round_wait_func()
{
	level endon( "restart_round" );
	level endon( "kill_round" );
	
	if( level flag::get("raps_round" ) )
	{
		level flag::wait_till( "raps_round_in_progress" );
		
		level flag::wait_till_clear( "raps_round_in_progress" );
	}
	
	level.sndMusicSpecialRound = false;
}


//*****************************************************************************
// Get the number of raps alive in the level
//*****************************************************************************

function get_current_raps_count()
{
	raps = GetEntArray( "zombie_raps", "targetname" );
	num_alive_raps = raps.size;
	foreach( rapsAI in raps )
	{
		if( !IsAlive( rapsAI ) )
		{
			num_alive_raps--;
		}
	}
	return num_alive_raps;
}


//*****************************************************************************
//*****************************************************************************

function elemental_round_fx()
{
	foreach ( player in level.players )
	{
		player clientfield::increment_to_player( "elemental_round_fx" );
		player clientfield::increment_to_player( ELEMENTAL_ROUND_RING_FX );
	}
}


//*****************************************************************************
//*****************************************************************************

function show_hit_marker()  // self = player
{
	if ( isdefined( self ) && isdefined( self.hud_damagefeedback ) )
	{
		self.hud_damagefeedback SetShader( "damage_feedback", 24, 48 );
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback FadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}	
}


//*****************************************************************************
//*****************************************************************************

function rapsDamage( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if( isdefined(attacker) )
	{
		attacker show_hit_marker();
	}
	return damage;
}


//*********************************************************************************
// Check if there's space and a place to spawn a raps, and the spawning flag is set
//*********************************************************************************

function can_we_spawn_raps()
{
	n_raps_alive = get_current_raps_count();
	
	b_raps_count_at_max = n_raps_alive >= N_MAX_RAPS_ALIVE;
	b_raps_count_per_player_at_max = n_raps_alive >= level.players.size * N_MAX_RAPS_PER_PLAYER;

	if( b_raps_count_at_max || b_raps_count_per_player_at_max || !( level flag::get( "spawn_zombies" ) ) )
	{
		return false;
	}
	return true;
}


//*****************************************************************************
//*****************************************************************************

function waiting_for_next_raps_spawn()
{
	switch( level.players.size )
	{
		case 1:
			n_default_wait = N_RAPS_SPAWN_DELAY_1P;
			break;
		case 2:
			n_default_wait = N_RAPS_SPAWN_DELAY_2P;
			break;
		case 3:
			n_default_wait = N_RAPS_SPAWN_DELAY_3P;
			break;
		default:
			n_default_wait = N_RAPS_SPAWN_DELAY_4P;
			break;
	}
	
	wait( n_default_wait );
}


//*****************************************************************************
//*****************************************************************************

function raps_round_aftermath()
{
	level waittill( "last_ai_down", e_enemy_ai );
	
	level thread zm_audio::sndMusicSystem_PlayState( "meatball_over" );
	
	if( isdefined(level.zm_override_ai_aftermath_powerup_drop) )
	{
		[[level.zm_override_ai_aftermath_powerup_drop]]( e_enemy_ai, level.last_ai_origin );
	}
	else
	{
		power_up_origin = level.last_ai_origin;
		trace = GroundTrace(power_up_origin + (0, 0, 100), power_up_origin + (0, 0, -1000), false, undefined);
		power_up_origin = trace["position"];

		if( isdefined( power_up_origin ) )
		{
			level thread zm_powerups::specific_powerup_drop( "full_ammo", power_up_origin );
		}
	}
	
	wait(2);
	level.sndMusicSpecialRound = false;
	wait(6);

	level flag::clear( "raps_round_in_progress" );

	//level thread raps_round_aftermath()
}


//*****************************************************************************
// There's a single spawner and the struct is passed in as the second argument.
//*****************************************************************************
function raps_spawn_fx( ai, ent )
{
	ai endon( "death" );
	
	if ( !isdefined(ent) )
	{
		ent = self;
	}
	
	ai vehicle_ai::set_state( "scripted" );

	//find the nearest spot on the ground below the struct, since wasps and raps use the same structs and they are floating
	trace = bullettrace( ent.origin, ent.origin + (0,0,-N_RAPS_DROP_HEIGHT_MAX), false, ai );
	raps_impact_location = trace[ "position" ];
	
	// face the enemy
	angle = VectorToAngles( ai.favoriteenemy.origin - ent.origin );
	angles = ( ai.angles[0], angle[1], ai.angles[2] );

	ai.origin = raps_impact_location;
	ai.angles = angles;
	ai Hide(); 
	
	//TODO need to clientside these FX.  spawning script_models is highly network unfriendly
	//look for ceiling height
	pos = raps_impact_location + (0 , 0, N_RAPS_DROP_HEIGHT_MAX );
	if ( !bullettracepassed( ent.origin, pos, false, ai) )
	{
		trace = bullettrace( ent.origin, pos, false, ai );
		pos = trace["position"];
	}
	portal_fx_location = spawn( "script_model" , pos );
	portal_fx_location SetModel( "tag_origin" );
	playfxontag( level._effect["raps_portal"], portal_fx_location, "tag_origin" );
	
	ground_tell_location = spawn( "script_model" , raps_impact_location );
	ground_tell_location SetModel( "tag_origin" );
	playfxontag( level._effect["raps_ground_spawn"], ground_tell_location, "tag_origin" );
	ground_tell_location playsound( "zmb_meatball_spawn_tell" );
	playsoundatposition( "zmb_meatball_spawn_rise", pos );

	ai thread cleanup_meteor_fx( portal_fx_location, ground_tell_location );

	wait 0.5;

	raps_meteor = spawn( "script_model", pos);
	model = ai.model;
	raps_meteor SetModel( model );
	raps_meteor.angles = angles;
	raps_meteor playloopsound( "zmb_meatball_spawn_loop", .25 );
	

	playfxontag( level._effect[ "raps_meteor_fire" ], raps_meteor, "tag_origin" );
	
	fall_dist = sqrt( DistanceSquared( pos, raps_impact_location ));
	fall_time = fall_dist / N_RAPS_DROP_SPEED;  //keeps velocity constant, even for short fall distances, such as inside

	raps_meteor MoveTo(raps_impact_location, fall_time);

	raps_meteor.ai = ai;
	raps_meteor thread cleanup_meteor();
	
	wait(fall_time);
	raps_meteor delete();
	
	if( isdefined (portal_fx_location ))
	{
		portal_fx_location delete();
	}
	
	if ( isdefined( ground_tell_location ) )
	{
		ground_tell_location delete();
	}
	
	ai vehicle_ai::set_state( "combat" );
	
	//DCS 080714: this should work for an ai vehicle but currently doesn't. Support should be added soon.
	//ai ForceTeleport( ent.origin, angles );
	ai.origin = raps_impact_location;
	ai.angles = angles;
	ai Show(); 
	Playfx( level._effect[ "raps_impact" ], raps_impact_location );
	playsoundatposition( "zmb_meatball_spawn_impact", raps_impact_location );
	
	Earthquake( 0.3, 0.75, raps_impact_location, 512);

	assert( isdefined( ai ), "Ent isn't defined." );
	assert( IsAlive( ai ), "Ent is dead." );

	ai zombie_setup_attack_properties_raps();

	//wait( 0.1 ); 
	ai SetVisibleToAll();
	ai.ignoreme = false; // don't let attack raps give chase until the wolf is visible
	ai notify( "visible" );
}

function cleanup_meteor()
{
	self endon( "death" );

	self.ai waittill( "death" );

	self delete();
}

function cleanup_meteor_fx( portal_fx, ground_tell )
{
	self waittill( "death" );

	if ( isdefined( portal_fx ) )
	{
		portal_fx delete();
	}

	if ( isdefined( ground_tell ) )
	{
		ground_tell delete();
	}
}

//*****************************************************************************
//*****************************************************************************

function create_global_raps_spawn_locations_list()
{
	if( !isdefined(level.enemy_raps_global_locations) )
	{
		level.enemy_raps_global_locations = [];	
		keys = GetArrayKeys( level.zones );
		for( i=0; i<keys.size; i++ )
		{
			zone = level.zones[keys[i]];
	
			// add raps_spawn locations
			foreach( loc in zone.a_locs[ "raps_location" ] )
			{
				ARRAY_ADD( level.enemy_raps_global_locations, loc );
			}
		}
	}
}


//*****************************************************************************
//*****************************************************************************
	
function raps_find_closest_in_global_pool( favorite_enemy )
{
	index_to_use = 0;
	closest_distance_squared = DistanceSquared( level.enemy_raps_global_locations[index_to_use].origin, favorite_enemy.origin );
	for( i = 0; i < level.enemy_raps_global_locations.size; i++ )
	{
		if( level.enemy_raps_global_locations[i].is_enabled )
		{
			dist_squared = DistanceSquared( level.enemy_raps_global_locations[i].origin, favorite_enemy.origin );
			if( dist_squared<closest_distance_squared )
			{
				index_to_use = i;
				closest_distance_squared = dist_squared;
			}
		}
	}
	return level.enemy_raps_global_locations[index_to_use];
}


//*****************************************************************************
//	Makes use of the _zm_zone_manager to validate possible spawn locations
//*****************************************************************************

function calculate_spawn_position( favorite_enemy )
{
	position = favorite_enemy.last_valid_position;
	if( !IsDefined( position ) )
	{
		position = favorite_enemy.origin;
	}
	
	// Set the min and max spawn distances based on the number of players
	if( level.players.size == 1 )
	{
		N_RAPS_SPAWN_DIST_MIN = 450;		// 450
		N_RAPS_SPAWN_DIST_MAX = 900;		// 900
	}
	else if( level.players.size == 2 )
	{
		N_RAPS_SPAWN_DIST_MIN = 450;		// 450
		N_RAPS_SPAWN_DIST_MAX = 850;		// 850
	}

	// With more players the meatballs can become overwhelming, so push out the spawn radius

	else if( level.players.size == 3 )
	{
		N_RAPS_SPAWN_DIST_MIN = 700;		// 500
		N_RAPS_SPAWN_DIST_MAX = 1000;		// 900
	}
	else
	{
		N_RAPS_SPAWN_DIST_MIN = 800;		// 550
		N_RAPS_SPAWN_DIST_MAX = 1200;		// 1000
	}
	
	// Get a spawn location on the navigation mesh
	query_result = PositionQuery_Source_Navigation(
					position,					// origin
					N_RAPS_SPAWN_DIST_MIN,		// min radius
					N_RAPS_SPAWN_DIST_MAX,		// max radius
					200,						// half height
					32,							// inner spacing
					16							// radius from edges
				);	

	if ( query_result.data.size )
	{
		a_s_locs = array::randomize( query_result.data );
	
		if ( isdefined( a_s_locs ) )
		{
			foreach( s_loc in a_s_locs )
			{
				if ( zm_utility::check_point_in_enabled_zone( s_loc.origin, true, level.active_zones ) )
				{
					s_loc.origin += (0,0,16);	// Add some allowance so it is above ground, otherwise it may spawn and get shoved below the ground.
					return s_loc;
				}
			}
		}
	}
	
	return undefined;
}


//*****************************************************************************
//*****************************************************************************

function get_favorite_enemy()
{
	raps_targets = GetPlayers();
	e_least_hunted = undefined;
	
	for( i=0; i<raps_targets.size; i++ )
	{
		e_target = raps_targets[i];

		// Initialize .hunted_by?
		if( !isdefined( e_target.hunted_by ) )
		{
			e_target.hunted_by = 0;
		}

		// Make sure the player is a valid target
		if( !zm_utility::is_player_valid( e_target ) )
		{
			continue;
		}
		
		//
		if( IsDefined( level.is_player_accessible_to_raps ) && ![[level.is_player_accessible_to_raps]]( e_target ) )
		{
			continue;
		}

		// Does this target have less things targetting it?		
		if( !isdefined(e_least_hunted) )
		{
			e_least_hunted = e_target;
		}
		else if( e_target.hunted_by < e_least_hunted.hunted_by )
		{
			e_least_hunted = e_target;
		}
	}
	
	return e_least_hunted;
}


//*****************************************************************************
//*****************************************************************************

function raps_health_increase()
{
	players = GetPlayers();

	level.n_raps_health = level.round_number * N_RAPS_HEALTH_INCREASE;

	if( level.n_raps_health > N_RAPS_HEALTH_MAX )
	{
		level.n_raps_health = N_RAPS_HEALTH_MAX;
	}
}


//*****************************************************************************
//*****************************************************************************

function play_raps_round()
{
	self playlocalsound( "zmb_raps_round_start" );
	variation_count =5;
	
	wait(4.5);

	players = GetPlayers();
	num = RandomIntRange(0,players.size);
	players[num] zm_audio::create_and_play_dialog( "general", "raps_spawn" );
}


//*****************************************************************************
//*****************************************************************************

function raps_init()
{
	self.inpain = true;
	thread raps::raps_initialize();
	self.inpain = false;

	self.targetname = "zombie_raps";
	self.script_noteworthy = undefined;
	self.animname = "zombie_raps"; 		 
	self.ignoreme = true; // don't let attack raps give chase until the wolf is visible
	self.allowdeath = true; 			// allows death during animscripted calls
	self.allowpain = false;
	self.no_gib = true; //gibbing disabled
	self.is_zombie = true; 			// needed for melee.gsc in the animscripts
	// out both legs and then the only allowed stance should be prone.
	self.gibbed = false; 
	self.head_gibbed = false;
	self.default_goalheight = 40;
	self.ignore_inert = true;	
	self.no_eye_glow = true;

	self.lightning_chain_immune = true;

	self.holdfire			= true;

	//	self.disableArrivals = true; 
	//	self.disableExits = true; 
	self.grenadeawareness = 0;
	self.badplaceawareness = 0;

	self.ignoreSuppression = true; 	
	self.suppressionThreshold = 1; 
	self.noDodgeMove = true; 
	self.dontShootWhileMoving = true;
	self.pathenemylookahead = 0;
	self.test_failed_path = true; // make raps explode if can't find path

	self.badplaceawareness = 0;
	self.chatInitialized = false;
	self.missingLegs = false;
	self.isdog = false;
	self.teslafxtag = "tag_origin";

	self.custom_player_shellshock = &raps_custom_player_shellshock;
	
	self.grapple_type = GRAPPLE_TYPE_PULLENTIN;
	self SetGrapplableType( self.grapple_type );
	
	self.team = level.zombie_team;
	self.sword_kill_power = ZM_RAPS_SWORD_KILL_POWER;

	health_multiplier = 1.0;
	if ( GetDvarString( "scr_raps_health_walk_multiplier" ) != "" )
	{
		health_multiplier = GetDvarFloat( "scr_raps_health_walk_multiplier" );
	}

	self.maxhealth = int( level.n_raps_health * health_multiplier );
	if( isdefined(level.a_zombie_respawn_health[ self.archetype ] ) && level.a_zombie_respawn_health[ self.archetype ].size > 0 )
	{
		self.health = level.a_zombie_respawn_health[ self.archetype ][0];
		ArrayRemoveValue(level.a_zombie_respawn_health[ self.archetype ], level.a_zombie_respawn_health[ self.archetype ][0]);		
	}
	else
	{
		self.health = int( level.n_raps_health * health_multiplier );
	}
	
	self thread raps_run_think();

	self SetInvisibleToAll();

	self thread raps_death();
	self thread raps_timeout_after_xsec( 90.0 );
	
	level thread zm_spawner::zombie_death_event( self ); 
	self thread zm_spawner::enemy_death_detection();
	
	self zm_spawner::zombie_history( "zombie_raps_spawn_init -> Spawned = " + self.origin );
	
	if ( isdefined(level.achievement_monitor_func) )
	{
		self [[level.achievement_monitor_func]]();
	}
}


//*****************************************************************************
//*****************************************************************************

function raps_timeout_after_xsec( timeout )
{
	self endon( "death" );
	wait( timeout );
	self DoDamage( self.health + 100, self.origin, self, undefined, "none", "MOD_UNKNOWN" );
}


//*****************************************************************************
//*****************************************************************************

function raps_death()
{
	self waittill( "death", attacker );

	if( get_current_raps_count() == 0 && level.zombie_total == 0 )
	{
		// Can be overridded for mixed AI rounds, in this case the last AI may be a wasp ro raps etc...
		if( ( !isdefined(level.zm_ai_round_over) || [[level.zm_ai_round_over]]() ) )
		{
			level.last_ai_origin = self.origin;
			level notify( "last_ai_down", self );
		}
	}

	// rewards
	if( IsPlayer( attacker ) )
	{
		// score
		if( !IS_TRUE( self.deathpoints_already_given ) )
		{
			attacker zm_score::player_add_points( "death_raps", N_RAPS_KILL_POINTS );	// points awarded
		}
		
		// bonus weapon power
		if( isdefined(level.hero_power_update))
		{
			[[level.hero_power_update]](attacker, self);
		}
	    
		// dialog responses to kill
	    if( RandomIntRange(0,100) >= 80 )
	    {
	        attacker zm_audio::create_and_play_dialog( "kill", "hellhound" );
	    }
	    
	    //stats
		attacker zm_stats::increment_client_stat( "zraps_killed" );
		attacker zm_stats::increment_player_stat( "zraps_killed" );		    

	}

	// switch to inflictor when SP DoDamage supports it
	if( isdefined( attacker ) && isai( attacker ) )
	{
		attacker notify( "killed", self );
	}

	if ( isdefined( self ) )
	{
		// sound
		self stoploopsound();

		self thread raps_explode_fx( self.origin );
	}
}


//*****************************************************************************
//*****************************************************************************

function raps_custom_player_shellshock( damage, attacker, direction_vec, point, mod )
{
	if( mod == "MOD_EXPLOSIVE" )
	{
		self thread player_watch_shellshock_accumulation(); 
	}
}


//*****************************************************************************
//*****************************************************************************

#define N_RAPS_SHELLSHOCK_HIT_LIMIT	4

function player_watch_shellshock_accumulation()
{
	self endon("death");
	DEFAULT(self.raps_recent_explosions, 0);
	self.raps_recent_explosions++;
	if ( self.raps_recent_explosions >= N_RAPS_SHELLSHOCK_HIT_LIMIT )
	{
		self ShellShock( "explosion_elementals", 2.0 );
	}
	self util::waittill_any_timeout( 20, "death" );
	self.raps_recent_explosions--;
}


//*****************************************************************************
//*****************************************************************************

function raps_explode_fx( origin )
{
	PlayFX( level._effect["raps_gib"], origin );
}


//*****************************************************************************
// this is where zombies go into attack mode, and need different attributes set up
//*****************************************************************************

function zombie_setup_attack_properties_raps()
{
	self zm_spawner::zombie_history( "zombie_setup_attack_properties()" );

	// allows zombie to attack again
	self.ignoreall = false; 

	//self.pathEnemyFightDist = 64;
	self.meleeAttackDist = 64;

	// turn off transition anims
	self.disableArrivals = true; 
	self.disableExits = true; 

}


//*****************************************************************************
//*****************************************************************************
//COLLIN'S Audio Scripts

function stop_raps_sound_on_death()
{
	self waittill("death");
	self stopsounds();
}


//*****************************************************************************
//	Allows raps to be spawned independent of the round spawning
//*****************************************************************************

function special_raps_spawn( n_to_spawn = 1, s_spawn_loc, fn_on_spawned )
{
	raps = GetEntArray( "zombie_raps", "targetname" );

	if ( isdefined( raps ) && raps.size >= 9 )
	{
		return false;
	}
	
	count = 0;
	while ( count < n_to_spawn )
	{
		//update the player array.
		players = GetPlayers();
		favorite_enemy = get_favorite_enemy();
		
		if( !IsDefined( favorite_enemy ) )
		{
			WAIT_ABOUT( 1 );  // try again after wait
			continue;
		}
		
		if ( isdefined( level.raps_spawn_func ) )
		{
			s_spawn_loc = [[level.raps_spawn_func]]( favorite_enemy );
		}
		else
		{
			// Default method
			s_spawn_loc = calculate_spawn_position( favorite_enemy );
		}

		if ( !isdefined( s_spawn_loc ) )
		{
			WAIT_ABOUT( 1 );  // try again after wait
			continue;
		}
			
		ai = zombie_utility::spawn_zombie( level.raps_spawners[0] );
		if( isdefined( ai ) ) 	
		{
			ai.favoriteenemy = favorite_enemy;
			ai.favoriteenemy.hunted_by++;	
			s_spawn_loc thread raps_spawn_fx( ai, s_spawn_loc );
			count++;
			
			if ( isdefined( fn_on_spawned ) )
			{
				ai thread [[fn_on_spawned]]();
			}
		}

		waiting_for_next_raps_spawn();
	}

	return true;
}


//*****************************************************************************
//*****************************************************************************

function raps_run_think()
{
	self endon( "death" );

	self waittill( "visible" );
	
	// decrease health
	if ( self.health > level.n_raps_health )
	{
		self.maxhealth = level.n_raps_health;
		self.health = level.n_raps_health;
	}
	
	//Check to see if the enemy is not valid anymore
	while( 1 )
	{
		if( ( !zm_utility::is_player_valid(self.favoriteenemy) && self.b_attracted_to_octobomb !== true ) || self should_raps_giveup_inaccessible_player( self.favoriteenemy ) )
		{
			//We are targetting an invalid player - select another one
			potential_target = get_favorite_enemy();
			if( IsDefined( potential_target ) )
			{
				self.favoriteenemy = potential_target;
				self.favoriteenemy.hunted_by++;
				self.raps_force_patrol_behavior = undefined;
			}
			else
			{
				self.raps_force_patrol_behavior = true;
			}
		}
		wait( 0.1 );
	}
}


//*****************************************************************************
//*****************************************************************************

function should_raps_giveup_inaccessible_player( player )
{
	if( IsDefined( level.raps_can_reach_inaccessible_location ) && self [[level.raps_can_reach_inaccessible_location]]() )
	{
		return false;
	}
	if( IsDefined( level.is_player_accessible_to_raps ) && ![[level.is_player_accessible_to_raps]]( player ) )
	{
		return true;
	}
	return false;
}


//*****************************************************************************
//*****************************************************************************

function raps_stalk_audio()
{
	self endon( "death" );
	
	while(1)
	{
		self playsound( "zmb_hellhound_vocals_amb" );
		wait randomfloatrange(3,6);		
	}
}


//*****************************************************************************
//*****************************************************************************

function raps_thundergun_knockdown( player, gib )
{
	self endon( "death" );

	damage = int( self.maxhealth * 0.5 );
	self DoDamage( damage, player.origin, player, undefined, "none", "MOD_UNKNOWN" );
}

