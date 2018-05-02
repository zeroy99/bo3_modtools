#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\vehicle_ai_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_weap_octobomb.gsh;

#using scripts\zm\_zm_clone;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#precache( "fx", "zombie/fx_monkey_lightning_zmb" );

REGISTER_SYSTEM_EX( "zm_weap_octobomb", &__init__, &__main__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "octobomb_fx",		VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "octobomb_spores_fx",		VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "octobomb_tentacle_hit_fx",	VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "octobomb_zombie_explode_fx",		VERSION_TU8, 1, "counter" );
	clientfield::register( "toplayer", 	"octobomb_state",		VERSION_SHIP, 3, "int" );
	clientfield::register( "missile", "octobomb_spit_fx",		VERSION_SHIP, 2, "int" );
	
	/#
		level thread octobomb_devgui();
	#/
}

function __main__()
{
	level.w_octobomb = GetWeapon( STR_WEAP_OCTOBOMB );
	level.w_octobomb_upgraded = GetWeapon( STR_WEAP_OCTOBOMB_UPGRADED );
	level.mdl_octobomb = "p7_fxanim_zm_zod_octobomb_mod";
	
	if( !octobomb_exists() )
	{
		return;
	}
	
	level._effect[ "grenade_samantha_steal" ] 	= "zombie/fx_monkey_lightning_zmb";
	
	zm_weapons::register_zombie_weapon_callback( level.w_octobomb, &player_give_octobomb );
	zm_weapons::register_zombie_weapon_callback( level.w_octobomb_upgraded, &player_give_octobomb_upgraded );
	
	level.octobombs = [];
}


// Need a parameter-less function for the weapon callback
// self is a player
function player_give_octobomb_upgraded()
{
	self player_give_octobomb( STR_WEAP_OCTOBOMB_UPGRADED );
}


// self is a player
function player_give_octobomb( str_weapon = STR_WEAP_OCTOBOMB )
{
	// Must remove the old weapon first
	w_tactical = self zm_utility::get_player_tactical_grenade();
	if ( isdefined( w_tactical ) )
	{
		self TakeWeapon( w_tactical );	
	}

	w_weapon = GetWeapon( str_weapon );
	self GiveWeapon( w_weapon );
	self zm_utility::set_player_tactical_grenade( w_weapon );
	self thread player_handle_octobomb();
}


function player_handle_octobomb()
{
	self notify( "starting_octobomb_watch" );
	self endon( "death" );
	self endon( "starting_octobomb_watch" );
	
	// Min distance to attract positions
	attract_dist_custom = level.octobomb_attract_dist_custom;
	if( !isdefined( attract_dist_custom ) ) // Attraction point radius
	{
		attract_dist_custom = 10;
	}
		
	num_attractors = level.num_octobomb_attractors;
	if( !isdefined( num_attractors ) )
	{
		num_attractors = 64;
	}
	
	max_attract_dist = level.octobomb_attract_dist;
	if( !isdefined( max_attract_dist ) )
	{
		max_attract_dist = 1024;
	}
	
	while ( true )
	{
		e_grenade = get_thrown_octobomb();
		if ( isdefined( e_grenade ) )
		{
			self thread player_throw_octobomb( e_grenade, num_attractors, max_attract_dist, attract_dist_custom );
		}
	}
}

function show_briefly( showtime )
{
	self endon("show_owner");
	if (isdefined(self.show_for_time))
	{
		self.show_for_time = showtime;
		return;
	}
	self.show_for_time = showtime;
	self SetVisibleToAll();
	while ( self.show_for_time > 0 )
	{
		self.show_for_time -= 0.05;
		WAIT_SERVER_FRAME;
	}
	self SetVisibleToAllExceptTeam( level.zombie_team );
	self.show_for_time = undefined;
}


function show_owner_on_attack( owner )
{
	owner endon("hide_owner");
	owner endon("show_owner");
	self endon( "explode" );
	self endon( "death" );
	self endon( "grenade_dud" );
	
	owner.show_for_time = undefined;
	
	for( ;; )
	{
		owner waittill( "weapon_fired" );
		owner thread show_briefly(0.5);
	}
}


function hide_owner( owner )
{
	owner notify("hide_owner");
	owner endon("hide_owner");

	owner SetPerk("specialty_immunemms");
	owner.no_burning_sfx = true;	
	owner notify( "stop_flame_sounds" );
	owner SetVisibleToAllExceptTeam( level.zombie_team );

	owner.hide_owner = true;

	if (isdefined(level._effect[ "human_disappears" ]))
		PlayFX( level._effect[ "human_disappears" ], owner.origin );

	self thread show_owner_on_attack( owner );
	
	evt = self util::waittill_any_ex( "explode", "death", "grenade_dud", owner, "hide_owner" );
	/# println( "ZMCLONE: Player visible again because of "+evt ); #/

	owner notify("show_owner");
	
	owner UnsetPerk("specialty_immunemms");
	if (isdefined(level._effect[ "human_disappears" ]))
		PlayFX( level._effect[ "human_disappears" ], owner.origin );
	owner.no_burning_sfx = undefined;
	owner SetVisibleToAll();

	owner.hide_owner = undefined;

	owner Show();
}

// hack because grenades can't linkto 
function FakeLinkto(linkee)
{
	self notify("fakelinkto");
	self endon("fakelinkto");
	self.backlinked = 1;
	while (isdefined(self) && isdefined(linkee))
	{
		self.origin = linkee.origin;
		self.angles = linkee.angles;
		wait 0.05;
	}
}


function grenade_planted( grenade, model )
{
	ride_vehicle = undefined; 
	grenade.ground_ent = grenade GetGroundEnt();
	if ( isdefined( grenade.ground_ent ) )
	{
		if ( IsVehicle( grenade.ground_ent ) && !IS_EQUAL(level.zombie_team,grenade.ground_ent) )
		{
			ride_vehicle = grenade.ground_ent; 
		}
	}

	if ( IsDefined(ride_vehicle) )
	{
		if (isdefined(grenade))
		{
			//grenade enableLinkTo();
			//grenade LinkTo( ride_vehicle );
			grenade SetMovingPlatformEnabled( true );
			grenade.equipment_can_move = true;
			grenade.isOnVehicle = true;
			grenade.move_parent = ride_vehicle;
			if (isdefined(model))
			{
				model SetMovingPlatformEnabled( true );
				model LinkTo( ride_vehicle );
				model.isOnVehicle = true;
				grenade FakeLinkto(model);
			}
		}
	}
}

// If octobomb lands on train, detonates when train starts moving (or if already moving)
// Self == octobomb
function check_octobomb_on_train()
{
	self endon( "death" );
	
	if ( self zm_zonemgr::entity_in_zone( "zone_train_rail" ) )
	{
		while( !level.o_zod_train flag::get( "moving" ) )
		{
			wait SERVER_FRAME;
			continue;
		}
	
		self detonate();
    }
}

function player_throw_octobomb( e_grenade, num_attractors, max_attract_dist, attract_dist_custom )
{
	self endon( "starting_octobomb_watch" );

	e_grenade endon( "death" );

	if ( self laststand::player_is_in_laststand() )
	{
		if ( isdefined( e_grenade.damagearea ) )
		{
			e_grenade.damagearea Delete();
		}
		
		e_grenade Delete();
		return;
	}
	
	// Angle fixes for spawned models
	v_angles_clone_model = self.angles + ( 90, 0, 90 );
	v_angles_anim_model = self.angles - ( 0, 90, 0 );
	
	is_upgraded = ( e_grenade.weapon == level.w_octobomb_upgraded );
	if ( is_upgraded )
	{
		n_cf_val = CF_OCTOBOMB_UG_FX;
	}
	else
	{
		n_cf_val = CF_OCTOBOMB_FX;
	}
	
	e_grenade Ghost();
	e_grenade.angles = v_angles_clone_model; // clockwise turn so that Li'l Arnie points at the throwing player
	e_grenade.clone_model = util::spawn_model( e_grenade.model, e_grenade.origin, e_grenade.angles );
	e_grenade.clone_model LinkTo( e_grenade );
	
	e_grenade thread octobomb_cleanup();

	e_grenade waittill( "stationary", v_position, v_normal );

	e_grenade thread check_octobomb_on_train();
	
	self thread grenade_planted(e_grenade,e_grenade.clone_model);
	
	e_grenade ResetMissileDetonationTime();
	
	e_grenade is_on_navmesh(); // Checks if octobomb is on navmesh
	b_valid_poi = zm_utility::check_point_in_enabled_zone( e_grenade.origin, undefined, undefined );
	
	if ( isdefined( level.check_b_valid_poi) )
	{
		b_valid_poi= e_grenade [[ level.check_b_valid_poi]]( b_valid_poi);
	}
	
	if ( b_valid_poi && e_grenade.navmesh_check )
	{
		if ( isdefined( level.octobomb_attack_callback ) && IsFunctionPtr( level.octobomb_attack_callback ) )
		{
			[[ level.octobomb_attack_callback ]]( e_grenade );
		}
	
		e_grenade move_away_from_edges(); // Moves the grenade origin away from walls and collision
		
		e_grenade zm_utility::create_zombie_point_of_interest( max_attract_dist, num_attractors, 10000 );
		e_grenade thread zm_utility::create_zombie_point_of_interest_attractor_positions( 4, attract_dist_custom );
		e_grenade thread zm_utility::wait_for_attractor_positions_complete();
		
		// e_grenade thread zm_utility::debug_draw_claimed_attractor_positions(); // DEBUG Draws lines from the octobomb origin to each of the claimed attractors
		// e_grenade thread zm_utility::debug_draw_attractor_positions(); // DEBUG Draws lines from the octobomb origin to each of the attractors
		
		// If b_special_octobomb is true it's being handled differently.
		if ( !IS_TRUE( e_grenade.b_special_octobomb ) )
		{
			e_grenade.clone_model zm_utility::self_delete();
			
			e_grenade.angles = v_angles_anim_model;
			e_grenade.anim_model = util::spawn_model( level.mdl_octobomb, e_grenade.origin, e_grenade.angles );
			if ( IS_TRUE(e_grenade.isOnVehicle) )
			{
				e_grenade.anim_model SetMovingPlatformEnabled( true );
				e_grenade.anim_model LinkTo( e_grenade.ground_ent );
				e_grenade.anim_model.isOnVehicle = true;
				e_grenade thread FakeLinkto(e_grenade.anim_model);
			}
			e_grenade.anim_model clientfield::set( "octobomb_fx", CF_OCTOBOMB_EXPLODE_FX );
			wait SERVER_FRAME; // Wait for explostion FX to get called and fired before starting spore FX
			e_grenade.anim_model clientfield::set( "octobomb_fx", n_cf_val );
			
			e_grenade thread animate_octobomb( is_upgraded );
			e_grenade thread do_octobomb_sound();
		}
		
		e_grenade thread do_tentacle_burst( self, is_upgraded );
		e_grenade thread do_tentacle_grab( self, is_upgraded );
		e_grenade thread sndAttackVox();
		
		// Attracts elementals and parasites
		e_grenade thread special_attractor_spawn( self, max_attract_dist );

		level.octobombs[ level.octobombs.size ] = e_grenade;
	}
	else
	{
		e_grenade.script_noteworthy = undefined;
		level thread grenade_stolen_by_sam( e_grenade );
	}
}

// Checks if octobomb is on or within 200 units of a valid navmesh point. If not, will cause grenade to be stolen by Samantha
function is_on_navmesh()
{	
	self endon( "death" );
	
	if ( IsPointOnNavMesh( self.origin, 60 ) == true )
	{
		self.navmesh_check = true;
		return;
	}

	v_valid_point = GetClosestPointOnNavMesh( self.origin, 100 );

	if ( isdefined( v_valid_point ) )
	{
		n_z_correct = 0.0;
		
		if ( self.origin[2] > v_valid_point[2] )
		{
			n_z_correct = self.origin[2] - v_valid_point[2];
		}
		
		self.origin = v_valid_point + ( 0, 0, n_z_correct );
		self.navmesh_check = true;
		return;
	}
		self.navmesh_check = false;
}

function animate_octobomb( is_upgraded )
{
	self endon( "death" );

	self playsound( "wpn_octobomb_explode" );
	self scene::play( "p7_fxanim_zm_zod_octobomb_start_bundle", self.anim_model );
	self thread scene::play( "p7_fxanim_zm_zod_octobomb_loop_bundle", self.anim_model );

	n_start_anim_length = GetAnimLength( "p7_fxanim_zm_zod_octobomb_start_anim" );
	n_end_anim_length = GetAnimLength( "p7_fxanim_zm_zod_octobomb_end_anim" );
	n_life_time = ( ( self.weapon.fusetime - ( n_end_anim_length * 1000 ) - ( n_start_anim_length * 1000 ) ) / 1000 );
	
	wait n_life_time * .75;
	
	if ( is_upgraded )
	{
		n_fx = CF_OCTOBOMB_UG_FX;
	}
	else
	{
		n_fx = CF_OCTOBOMB_FX;
	}
	self thread clientfield::set( "octobomb_spit_fx", n_fx ); // with a quarter of Li'l Arnie's lifespan left, start spitting
	
	wait n_life_time * .25;
	
	self scene::play( "p7_fxanim_zm_zod_octobomb_end_bundle", self.anim_model );

	self playsound( "wpn_octobomb_end" );
}

#define NUM_TRIES 5
function move_away_from_edges()
{
	v_orig = self.origin;
	n_angles = self.angles;
	n_z_correct = 0.0; // Corrects for PositionQuery_Source_Navigation lowering Z positioning
	queryResult = PositionQuery_Source_Navigation(
					self.origin,		// origin
					0,					// min radius
					200,				// max radius
					100,				// half height
					2,					// inner spacing
					20					// radius from edges
				);
					
	if ( queryResult.data.size )
	{
		foreach ( point in queryResult.data )
		{
			if ( BulletTracePassed( point.origin + ( 0, 0, 20 ), v_orig + ( 0, 0, 20 ), false, self, undefined, false, false ) )
			{
				if ( self.origin[2] > queryResult.origin[2] )
				{
					n_z_correct = self.origin[2] - queryResult.origin[2];
				}
				self.origin = point.origin + (0, 0, n_z_correct);
				self.angles = n_angles;
				break;
			}
		}
	}
}


// if the player throws it to an unplayable area samantha steals it
function grenade_stolen_by_sam( e_grenade )
{
	if( !isdefined( e_grenade ) )
	{
		return;
	}
	
	//ent_grenade notify( "sam_stole_it" );
	
	direction = e_grenade.origin;
	direction = ( direction[ 1 ], direction[ 0 ], 0 );
 
	if ( direction[ 1 ] < 0 || ( direction[ 0 ]  > 0 && direction[ 1 ]  > 0 ) )
	{
		direction = ( direction[ 0 ], direction[ 1 ] * -1, 0 );
	}
	else if ( direction[ 0 ] < 0 )
	{
		direction = ( direction[ 0 ] * -1, direction[ 1 ], 0 );
	}
	
	// Play laugh sound here, players should connect the laugh with the movement which will tell the story of who is moving it
	if( !IS_TRUE(e_grenade.sndNoSamLaugh) )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			if ( IsAlive( players[ i ] ) )
			{
				players[ i ] PlayLocalSound( level.zmb_laugh_alias );
			}
		}
	}
	
	// play the fx on the model
	PlayFXOnTag( level._effect[ "grenade_samantha_steal" ], e_grenade, "tag_origin" );
	
	e_grenade.clone_model Unlink();
	
	// raise the model
	e_grenade.clone_model MoveZ( 60, 1.0, 0.25, 0.25 );

	// spin it
	e_grenade.clone_model Vibrate( direction, 1.5,  2.5, 1.0 );
	e_grenade.clone_model waittill( "movedone" );
	
	if ( isdefined( self.damagearea ) )
	{
		self.damagearea Delete();
	}
	
	e_grenade.clone_model Delete();
		
	if ( isdefined( e_grenade ) )
	{
		if ( isdefined( e_grenade.damagearea ) )
		{
			e_grenade.damagearea Delete();
		}
		
		e_grenade Delete();
	}
}

function octobomb_cleanup()
{
	while ( true )
	{
		if ( !isdefined( self ) )
		{
			if ( isdefined( self.clone_model ) )
			{
				self.clone_model Delete();
			}
			
			if ( isdefined( self.anim_model ) )
			{
				self.anim_model Delete();
			}
				
			if ( isdefined( self ) && IS_TRUE( self.dud ) ) // wait for the screams to die out
			{
				wait 6;
			}
			
			if ( isdefined( self.simulacrum ) )
			{
				self.simulacrum delete();
			}
			
			zm_utility::self_delete();
			return;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function do_octobomb_sound()
{
	self waittill( "explode", position );
	level notify( "grenade_exploded", position, 100, 5000, 450 );

	octobomb_index = -1;
	for ( i = 0; i < level.octobombs.size; i++ )
	{
		if ( !isdefined( level.octobombs[ i ] ) )
		{
			octobomb_index = i;
			break;
		}
	}
	
	if ( octobomb_index >= 0 )
	{
		ArrayRemoveIndex( level.octobombs, octobomb_index );
	}
}

// self == octobomb
function do_tentacle_burst( e_player, is_upgraded )
{
	self endon( "explode" );
	
	n_time_started = GetTime() / 1000;
	
	while ( true )
	{
		n_time_current = GetTime() / 1000;
		n_time_elapsed = n_time_current - n_time_started;
		
		if ( n_time_elapsed < OCTOBOMB_DAMAGE_GROWTH_DURATION )
		{
			n_radius = LerpFloat( 0, OCTOBOMB_DAMAGE_RADIUS, n_time_elapsed / OCTOBOMB_DAMAGE_GROWTH_DURATION );
		}
		else if ( n_time_elapsed == OCTOBOMB_DAMAGE_GROWTH_DURATION )
		{
			n_radius = OCTOBOMB_DAMAGE_RADIUS;
		}

		a_ai_potential_targets = zombie_utility::get_zombie_array();

		if ( isdefined( level.octobomb_targets ) )
		{
			a_ai_potential_targets = [[ level.octobomb_targets ]]( a_ai_potential_targets );
		}

		a_ai_targets = ArraySortClosest( a_ai_potential_targets, self.origin, a_ai_potential_targets.size, 0, OCTOBOMB_DAMAGE_RADIUS );
		
		foreach ( ai_target in a_ai_targets )
		{
			if ( IsAlive( ai_target ) )
			{
				ai_target thread clientfield::set( "octobomb_tentacle_hit_fx", 1 );
				
				if ( ai_target.b_octobomb_infected !== true )
				{ 
					self notify( "sndKillVox" );
				
					ai_target playsound( "wpn_octobomb_zombie_imp" );
					ai_target thread zombie_explodes();
					ai_target thread zombie_spore_infect( e_player, self, is_upgraded );
				}
				
				wait SERVER_FRAME;
				
				ai_target thread clientfield::set( "octobomb_tentacle_hit_fx", 0 );
			}
		}
		wait OCTOBOMB_DAMAGE_INTERVAL;
	}
}

// DOT on zombie
// self is a zombie
function zombie_spore_infect( e_player, e_grenade, is_upgraded )
{
	self endon( "death" );
	
	self.octobomb_infected = true;
	n_infection_time = 0;
	n_infection_half_time = OCTOBOMB_DAMAGE_TIME / 2;
	n_burst_damage = 3;
	
	if ( is_upgraded )
	{
		n_damage = OCTOBOMB_UG_DAMAGE_TICK;
		n_spore_val = CF_OCTOBOMB_UG_FX;
	}
	else
	{
		n_damage = OCTOBOMB_DAMAGE_TICK;
		n_spore_val = CF_OCTOBOMB_FX;
	}
	
	self clientfield::set( "octobomb_spores_fx", n_spore_val );
	while ( n_infection_time < OCTOBOMB_DAMAGE_TIME )
	{	
		wait OCTOBOMB_DAMAGE_INTERVAL;
		n_infection_time++;
		
		// Initial burst damage
		self DoDamage( n_damage * n_burst_damage, self.origin, e_player, e_grenade );
		n_burst_damage = 1;
	}
	self.octobomb_infected = false;
	self clientfield::set( "octobomb_spores_fx", 0 );
}

// If infected, zombie explodes on death
function zombie_explodes()
{
	self waittill( "death" );
	if ( isdefined(self) )
	{
		if ( self.octobomb_infected == true )
		{
			self clientfield::increment( "octobomb_zombie_explode_fx", 1 );
			self octo_gib();
		}
	}
}

// self == octobomb
function do_tentacle_grab( e_player, is_upgraded ) // Randomly grabs farthest zombie with a time range of n_wait_grab
{
	self endon( "death" );
	
	b_fast_grab = true; // Tracks if the octobomb immediately grabs the next targetR
	n_grabs = 0; // Tracks consecutive fast grabs
	
	if ( is_upgraded )
	{
		n_spore_val = CF_OCTOBOMB_UG_FX;
		n_time_min = OCTOBOMB_UG_GRAB_MIN_TIME;
		n_time_max = OCTOBOMB_UG_GRAB_MAX_TIME;
	}
	else
	{
		n_spore_val = CF_OCTOBOMB_FX;
		n_time_min = OCTOBOMB_GRAB_MIN_TIME;
		n_time_max = OCTOBOMB_GRAB_MAX_TIME;
	}
	
	while ( true )
	{
		if ( b_fast_grab == false )
		{
			n_wait_grab = RandomFloatRange( n_time_min, n_time_max );
		}
		else
		{
			n_wait_grab = 0.1;
		}
		
		wait n_wait_grab;
		
		a_ai_potential_targets = zombie_utility::get_zombie_array();

		if ( isdefined( level.octobomb_targets ) )
		{
			a_ai_potential_targets = [[ level.octobomb_targets ]]( a_ai_potential_targets );
		}

		a_ai_targets = ArraySort( a_ai_potential_targets, self.origin, true, a_ai_potential_targets.size, OCTOBOMB_GRAB_RADIUS );
		
		n_random_x = RandomFloatRange( -5, 5 );
		n_random_y = RandomFloatRange( -5, 5 );
		
		if ( a_ai_targets.size > 0 )
		{
			ai_target = array::random( a_ai_targets );
			
			if ( IsAlive( ai_target ) )
			{
				ai_target clientfield::set( "octobomb_spores_fx", n_spore_val );
				self.octobomb_infected = true;

				self notify( "sndKillVox" );
				
				ai_target playsound( "wpn_octobomb_zombie_imp" );
				ai_target octo_gib();
				ai_target DoDamage( ai_target.health, ai_target.origin, e_player, self );
	           	ai_target StartRagdoll();
	           	ai_target LaunchRagdoll( 105 * VectorNormalize( ai_target.origin - self.origin + ( n_random_x, n_random_y, 200) ) );
			}
			
			// 4+ on D6 roll to grab a second zombie. Becomes 5+, 6+, with each successful grab, then restarts
			if ( RandomInt( 6 ) > ( n_grabs + 3 ) )
			{
				b_fast_grab = true;
				n_grabs++;
			}
			else
			{
				b_fast_grab = false;
				n_grabs = 0;
			}
		}
		else
		{
			b_fast_grab = true;
		}
	}
}

function octo_gib()
{
	gibserverutils::gibhead( self );
	
	if ( math::cointoss() )
	{
		gibserverutils::gibleftarm( self );
	}
	else
	{
		gibserverutils::gibrightarm( self );
	}
	
	gibserverutils::giblegs( self );
}

// Spawn elemental/parasite attractor
function special_attractor_spawn( e_player, max_attract_dist )
{
	self endon ( "death" );
	self MakeSentient();
	self SetMaxHealth ( 1000 ) ;
	self SetNormalHealth( 1 );
	
	self thread parasite_attractor_grab( self );
	
	while ( true )
	{
		a_ai_zombies = array::get_all_closest( self.origin, getAITeamArray( level.zombie_team ), undefined, undefined, max_attract_dist * 1.5 );
				
		foreach ( ai_zombie in a_ai_zombies )
		{
			if ( IsVehicle( ai_zombie ) )
			{
				// Li'l Arnie attracts parasites (only does so after the parasites have done their spawn in FX)
				if ( ai_zombie.archetype == ARCHETYPE_PARASITE && ai_zombie.ignoreme !== true && ai_zombie vehicle_ai::get_current_state() != "scripted" )
				{
					if ( !isdefined( self.v_parasite_attractor_center ) )
					{
						self parasite_attractor_init();
					}
					ai_zombie thread parasite_variables( self );
					ai_zombie thread parasite_attractor( self );
					continue;
				}
				
				// Li'l Arnie attracts elementals
				if ( ai_zombie.archetype == ARCHETYPE_RAPS  && ai_zombie.b_attracted_to_octobomb !== true )
				{
					ai_zombie thread vehicle_attractor( self );
				}
				
				// Li'l Arnie infects/DOTs elementals
				if ( ai_zombie.archetype == ARCHETYPE_RAPS && ai_zombie.octobomb_infected !== true && Distance( self.origin, ai_zombie.origin) <= OCTOBOMB_DAMAGE_RADIUS )
				{
					ai_zombie thread vehicle_attractor_damage( e_player );
				}

				// Li'l Arnie infects/DOTs spiders
				if ( ai_zombie.archetype == ARCHETYPE_SPIDER && ai_zombie.octobomb_infected !== true && Distance( self.origin, ai_zombie.origin) <= OCTOBOMB_DAMAGE_RADIUS )
				{
					ai_zombie thread vehicle_attractor_damage( e_player );
				}
			}
		}
		wait SERVER_FRAME;
	}
}

// Attracts Vehicles
function vehicle_attractor( e_grenade )
{
	self endon( "death" );
	
	self.favoriteenemy = e_grenade;
	self.b_attracted_to_octobomb = true;
    self.ignoreme = true;
    
    e_grenade waittill( "death" );
       
   	self.b_attracted_to_octobomb = false;
    self.ignoreme = false;
}

// DOT on Vehicles
function vehicle_attractor_damage( e_player )
{
	self endon( "death" );
	
	self.octobomb_infected = true;
	n_infection_time = 0;
	
	while ( n_infection_time < OCTOBOMB_DAMAGE_TIME )
	{	
		self DoDamage( OCTOBOMB_DAMAGE_TICK, self.origin, e_player );
		wait OCTOBOMB_DAMAGE_INTERVAL;
	}
	self.octobomb_infected = false;
}

// Initializes Parasite attractor points
function parasite_attractor_init()
{
	self.v_parasite_attractor_center = self.origin + (0, 0, OCTOBOMB_PARASITE_ATTRACT_RADIUS);
	
	// Initialize attractor points
	self.a_v_parasite_attractors = [];
	ARRAY_ADD( self.a_v_parasite_attractors, self.v_parasite_attractor_center + ( OCTOBOMB_PARASITE_ATTRACT_RADIUS, 0, 0 ) );
	ARRAY_ADD( self.a_v_parasite_attractors, self.v_parasite_attractor_center + ( 0, OCTOBOMB_PARASITE_ATTRACT_RADIUS, 0 ) );
	ARRAY_ADD( self.a_v_parasite_attractors, self.v_parasite_attractor_center + ( -OCTOBOMB_PARASITE_ATTRACT_RADIUS, 0, 0 ) );
	ARRAY_ADD( self.a_v_parasite_attractors, self.v_parasite_attractor_center + ( 0, -OCTOBOMB_PARASITE_ATTRACT_RADIUS, 0 ) );
}

// Shuts off variables for surviving parasites
function parasite_variables( e_grenade )
{
	self endon( "death" );	
	
	self.favoriteenemy = e_grenade;
	self vehicle_ai::set_state( "scripted" );
	self.b_parasite_attracted = true;
	self.ignoreme = true;
	self.parasiteEnemy = e_grenade;
	self ai::set_ignoreall( true );
	
    e_grenade waittill( "death" );
    
    self ResumeSpeed();
    self vehicle_ai::set_state( "combat" );
    self.b_parasite_attracted = false;	
	self.ignoreme = false;
	self ai::set_ignoreall( false );
}

// Attract Parasites
function parasite_attractor( e_grenade )
{
	self endon( "death" );
	e_grenade endon( "death" );

	f_speed = 10.0;
	
	if ( Distance( e_grenade.v_parasite_attractor_center, self.origin ) > OCTOBOMB_PARASITE_ATTRACT_RADIUS )
	{
		self SetSpeed( 10 );
		self SetVehGoalPos( e_grenade.v_parasite_attractor_center, false, true );
		while (	Distance( e_grenade.v_parasite_attractor_center, self.origin ) > OCTOBOMB_PARASITE_ATTRACT_RADIUS )
		{
			wait SERVER_FRAME;
		}
		self ClearVehGoalPos();
	}

	i = 0;
	while( self.b_parasite_attracted )
	{
		// Resets array of attractors
		if ( i == 4 )
		{
			i = 0;
		}
		
		// Get as close as possible to the goal POS
		self SetVehGoalPos( e_grenade.a_v_parasite_attractors[i], false, true );
		while (	Distance( e_grenade.a_v_parasite_attractors[i], self.origin ) > 10 )
		{
			if ( !self.b_parasite_attracted )
			{
				break;
			}
			wait SERVER_FRAME;
		}
		self ClearVehGoalPos();
		
		i++;
		
		wait SERVER_FRAME;
	}
}

// Grabs and flings parasites
function parasite_attractor_grab( e_grenade )
{
	e_grenade endon( "death" );
	self endon( "death" );

	b_fast_grab = true;
	n_grabs = 0;
	
	while ( true )
	{
		if ( b_fast_grab == false )
		{
			n_wait_grab = RandomFloatRange( OCTOBOMB_GRAB_MIN_TIME, OCTOBOMB_GRAB_MAX_TIME );
		}
		else
		{
			n_wait_grab = 0.1;
		}
		wait n_wait_grab;
				
		a_ai_parasites = array::get_all_closest( self.origin, getAITeamArray( level.zombie_team ), undefined, undefined, 150 );
		i=0;
		while (i < a_ai_parasites.size)
		{
			if ( isdefined( a_ai_parasites[i] ) && (a_ai_parasites[i].archetype != ARCHETYPE_PARASITE) )
			{
				ArrayRemoveValue( a_ai_parasites, a_ai_parasites[i] );
				i=0;
				continue;
			}
			i++;
		}
					
		if ( a_ai_parasites.size > 0 )
		{
			ai_parasite = array::random( a_ai_parasites );
			
			v_fling = VectorNormalize( ai_parasite.origin - e_grenade.origin );
			
			ai_parasite DoDamage( ai_parasite.maxhealth, self.origin );
		
			if ( RandomInt( 6 ) > ( n_grabs + 3 ) )
			{
				b_fast_grab = true;
				n_grabs++;
			}
			else
			{
				b_fast_grab = false;
				n_grabs = 0;
			}
			}
		else
		{
			b_fast_grab = true;
		}
	}
}

function sndAttackVox()
{
	self endon( "explode" );
	
	while(1)
	{
		self waittill( "sndKillVox" );
		wait(.25);
		self playsound( "wpn_octobomb_attack_vox" );
		wait(2.5);
	}
}

function get_thrown_octobomb()
{
	self endon( "death" );
	self endon( "starting_octobomb_watch" );
	
	while ( true )
	{
		self waittill( "grenade_fire", e_grenade, w_weapon );
		if ( w_weapon == level.w_octobomb || w_weapon == level.w_octobomb_upgraded )
		{
			e_grenade.use_grenade_special_long_bookmark = true;
			e_grenade.grenade_multiattack_bookmark_count = 1;
			e_grenade.weapon = w_weapon;
			return e_grenade;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function octobomb_exists()
{
	return zm_weapons::is_weapon_included( level.w_octobomb );
}

// devgui so we can test the Octobomb
// let the player give themselves the magic jar or the octobomb itself
function octobomb_devgui()
{
    for( i = 0; i < 4; i++ )
    {
        // devgui to give the octobomb to individual players
        level thread setup_devgui_func( "ZM/Weapons/Offhand/Octobomb/Give" + i,        "zod_give_octobomb",    i, &devgui_octobomb_give );
    }
    // devgui to give the octobomb to ALL players
    level thread setup_devgui_func( "ZM/Weapons/Offhand/Octobomb/Give to All",    "zod_give_octobomb",     4, &devgui_octobomb_give );    
}

function private setup_devgui_func( str_devgui_path, str_dvar, n_value, func, n_base_value )
{
	if( !isdefined( n_base_value ) )
	{
		n_base_value = -1;
	}
	
	SetDvar( str_dvar, n_base_value );

	AddDebugCommand( "devgui_cmd \"" + str_devgui_path + "\" \"" + str_dvar + " " + n_value + "\"\n" );
	
	// now watch the dvar
	while ( true )
	{
		n_dvar = GetDvarInt( str_dvar );
		if ( n_dvar > n_base_value )
		{
			// call the target func, then reset the dvar
			[[ func ]]( n_dvar );
			SetDvar( str_dvar, n_base_value );
		}
		
		util::wait_network_frame();
	}
}

function devgui_octobomb_give( n_player_index )
{
    players = GetPlayers();
    
    player = players[ n_player_index ];
    if( isdefined( player ) ) // give the activating player the octobomb
    {
        octobomb_give( player );
    }
    else if( n_player_index === 4 ) // give all players the octobomb
    {
        foreach( player in players )
        {
        	octobomb_give( player );
        }
    }
}

function octobomb_give( player )
{
        player clientfield::set_to_player( "octobomb_state", 3 );

        weapon = GetWeapon( STR_WEAP_OCTOBOMB );
        player TakeWeapon( weapon ); // take away if it's already there, to make sure it replenishes properly
        player zm_weapons::weapon_give( weapon, undefined, undefined, true );
}



