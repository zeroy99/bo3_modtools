#using scripts\shared\util_shared;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flagsys_shared;

#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_devgui;



#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_perk_random.gsh;
#insert scripts\zm\_zm_utility.gsh;

#define RANDOM_PERK_MOVE_MIN 3
#define RANDOM_PERK_MOVE_MAX 7 




#precache( "string", "ZOMBIE_RANDOM_PERK_TOO_MANY" );
#precache( "string", "ZOMBIE_RANDOM_PERK_BUY" );
#precache( "string", "ZOMBIE_RANDOM_PERK_PICKUP" );
#precache( "string", "ZOMBIE_RANDOM_PERK_ELSEWHERE" );



#namespace zm_perk_random;

REGISTER_SYSTEM_EX( "zm_perk_random", &__init__, &__main__, undefined )

function __init__()
{
	level._random_zombie_perk_cost = 1500;

	clientfield::register( "scriptmover", "perk_bottle_cycle_state", 		VERSION_DLC1, 2, "int" );
	clientfield::register( "zbarrier", 		"set_client_light_state", 		VERSION_DLC1, 2, "int" );
	clientfield::register( "zbarrier", 		"client_stone_emmissive_blink",	VERSION_DLC1, 1, "int" );
	clientfield::register( "zbarrier", 		"init_perk_random_machine", 	VERSION_DLC1, 1, "int" );
	clientfield::register( "scriptmover", "turn_active_perk_light_green", 	VERSION_DLC1, 1, "int" );
	clientfield::register( "scriptmover", "turn_on_location_indicator", 	VERSION_DLC1, 1, "int" );
	clientfield::register( "zbarrier", "lightning_bolt_FX_toggle", 	VERSION_TU10, 1, "int");
	clientfield::register( "scriptmover", "turn_active_perk_ball_light",	VERSION_DLC1, 1, "int" );
	clientfield::register( "scriptmover", "zone_captured", 					VERSION_DLC1, 1, "int" );

	level._effect[ "perk_machine_light_yellow" ] = 				"dlc1/castle/fx_wonder_fizz_light_yellow";
	level._effect[ "perk_machine_light_red" ] = 				"dlc1/castle/fx_wonder_fizz_light_red";
	level._effect[ "perk_machine_light_green" ] = 				"dlc1/castle/fx_wonder_fizz_light_green";
	level._effect[ "perk_machine_location" ] = 					"fx/zombie/fx_wonder_fizz_lightning_all";
	

	level flag::init( "machine_can_reset" );
}

function __main__()
{	
	if ( !IsDefined( level.perk_random_machine_count ) )
	{
		level.perk_random_machine_count = 1;
	}
	if ( !IsDefined( level.perk_random_machine_state_func ) )
	{
		level.perk_random_machine_state_func = &process_perk_random_machine_state;
	}
	
	/#
	level thread setup_devgui();
	#/
	
	level thread setup_perk_random_machines();
}

function private setup_perk_random_machines()
{
	waittillframeend;
	
	level.perk_bottle_weapon_array = ArrayCombine( level.machine_assets, level._custom_perks, false, true );
	
	level.perk_random_machines = GetEntArray( "perk_random_machine", "targetname" );
	level.perk_random_machine_count = level.perk_random_machines.size;
	
	perk_random_machine_init();
}

function perk_random_machine_init()
{

	foreach( machine in level.perk_random_machines )
	{
		if ( !isDefined(machine.cost ) )
		{
			// default perk machine cost
			machine.cost = ZM_PERK_RANDOM_COST;
		}

		machine.current_perk_random_machine = false;
		machine.uses_at_current_location = 0;
		machine create_perk_random_machine_unitrigger_stub();
		machine clientfield::set( "init_perk_random_machine", 1 );
		
		wait .5; //let machine init before setting its state
		
		machine thread set_perk_random_machine_state( "power_off" );
		
	}
	
	level.perk_random_machines = array::randomize( level.perk_random_machines );
	
	init_starting_perk_random_machine_location();
}


function private init_starting_perk_random_machine_location()
{	
	b_starting_machine_found = false;
	for ( i = 0; i < level.perk_random_machines.size; i++ )
	{
		//level.perk_random_machines[i] clientfield::set( ZM_BGB_MACHINE_CF_NAME, 1 );

		// Semi-random implementation (not completely random).  The list is randomized
		//	prior to getting here.
		// Pick from the first perk_random_machine marked as the "start_perk_random_machine"
		if ( IsDefined( level.perk_random_machines[i].script_noteworthy ) && IsSubStr( level.perk_random_machines[i].script_noteworthy, "start_perk_random_machine" ) && !IS_TRUE(b_starting_machine_found))
		{
			level.perk_random_machines[i].current_perk_random_machine = true;
			level.perk_random_machines[i] thread machine_think();
			level.perk_random_machines[i] thread set_perk_random_machine_state("initial");
			b_starting_machine_found = true;
				
		}
		else
		{
			level.perk_random_machines[i] thread wait_for_power();
		}
			
	}
}

function create_perk_random_machine_unitrigger_stub()
{
	self.unitrigger_stub = spawnstruct();
	self.unitrigger_stub.script_width = 70;
	self.unitrigger_stub.script_height = 30;
	self.unitrigger_stub.script_length = 40;
	self.unitrigger_stub.origin = self.origin + (AnglesToRight( self.angles ) * (self.unitrigger_stub.script_length)) + (AnglesToUp( self.angles ) * (self.unitrigger_stub.script_height / 2));
	self.unitrigger_stub.angles = self.angles;
	self.unitrigger_stub.script_unitrigger_type = "unitrigger_box_use";
	self.unitrigger_stub.trigger_target = self;
	zm_unitrigger::unitrigger_force_per_player_triggers( self.unitrigger_stub, true );
	self.unitrigger_stub.prompt_and_visibility_func = &perk_random_machine_trigger_update_prompt;
	
	// Used for multiple power sources
	self.unitrigger_stub.script_int = self.script_int;
	
	thread zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, &perk_random_unitrigger_think );
	
}

function perk_random_machine_trigger_update_prompt( player )
{
	can_use = self perk_random_machine_stub_update_prompt( player );

	if ( isdefined( self.hint_string ) )
	{
		if ( isdefined( self.hint_parm1 ) )
		{
			self SetHintString( self.hint_string, self.hint_parm1 );
		}
		else
		{
			self SetHintString( self.hint_string );
		}
	}

	return can_use;
}

function perk_random_machine_stub_update_prompt( player )
{
	self SetCursorHint( "HINT_NOICON" );

	if ( !self trigger_visible_to_player( player ) )
	return false;
	
	self.hint_parm1 = undefined;

	// Is the power on?
	n_power_on = is_power_on( self.stub.script_int );
	if ( !n_power_on )
	{
		self.hint_string = &"ZOMBIE_NEED_POWER";
		return false;
	}
	else // machine is powered
	{
		if ( self.stub.trigger_target.state == "idle" || self.stub.trigger_target.state == "vending" ) // machine is usable ( orb is present )
		{
			n_purchase_limit = player zm_utility::get_player_perk_purchase_limit();
			if ( !player zm_utility::can_player_purchase_perk() )
			{
				self.hint_string = &"ZOMBIE_RANDOM_PERK_TOO_MANY";

				if ( IsDefined( n_purchase_limit ) )
				{
					self.hint_parm1 = n_purchase_limit; // purchase limit in prompt will update as player gets more slots
				}

				return false;
			}
			else if ( IsDefined( self.stub.trigger_target.machine_user ) ) // machine is currently activated
			{
				if ( IS_TRUE( self.stub.trigger_target.grab_perk_hint ) ) // perk is ready to grab
				{
					
		
						self.hint_string = &"ZOMBIE_RANDOM_PERK_PICKUP";
						return true;

				}
				else // perk is emerging from portal ( don't show prompt during this time )
				{
					self.hint_string = "";
					return false;
				}
			}
			else // machine is not currently activated, but can be activated
			{
				n_purchase_limit = player zm_utility::get_player_perk_purchase_limit();
				if ( !player zm_utility::can_player_purchase_perk() )
				{
					self.hint_string = &"ZOMBIE_RANDOM_PERK_TOO_MANY";

					if ( IsDefined( n_purchase_limit ) )
					{
						self.hint_parm1 = n_purchase_limit; // purchase limit in prompt will update as player gets more slots
					}

					return false;
				}
				else
				{
					self.hint_string = &"ZOMBIE_RANDOM_PERK_BUY";
					self.hint_parm1 = level._random_zombie_perk_cost;
					return true;
				}
			}
		}
		else // machine is unusable because the orb is not present
		{
			self.hint_string = &"ZOMBIE_RANDOM_PERK_ELSEWHERE";
			return false;
		}
	}

}

function trigger_visible_to_player( player )
{
	self SetInvisibleToPlayer( player );

	visible = true;

	// if the machine is activated, trigger is only visible to the player who is using the machine
	if ( IsDefined( self.stub.trigger_target.machine_user ) )
	{
		if ( ( player != self.stub.trigger_target.machine_user ) || zm_utility::is_placeable_mine( self.stub.trigger_target.machine_user GetCurrentWeapon() ) )
		{
			visible = false;
		}
	}
	else // only show the trigger if the player can buy the perk
	{
		if ( !player can_buy_perk() )
		{
			visible = false;
		}
	}

	if ( !visible )
	{
		return false;
	}

	if( player player_has_all_available_perks() )
	{
		return false;
	}		

	self SetVisibleToPlayer( player );
	return true;
}

// check to see if player has all available perks from this machine
function player_has_all_available_perks() // self = player
{
	for( i = 0; i < level._random_perk_machine_perk_list.size; i++ )
	{
		if( !self HasPerk( level._random_perk_machine_perk_list[i] ) )
		{
			return false;
		}		
	}	
	
	return true;
}	

function can_buy_perk() // note: hitting the perk limit is a special case, handled through trigger_visible_to_player and the machine_think function
{
	if ( IsDefined( self.is_drinking ) && IS_DRINKING( self.is_drinking ) )
	{
		return false;
	}

	current_weapon = self GetCurrentWeapon();
	if ( zm_utility::is_placeable_mine( current_weapon ) || zm_equipment::is_equipment_that_blocks_purchase( current_weapon ) )
	{
		return false;
	}

	if ( self zm_utility::in_revive_trigger() )
	{
		return false;
	}

	if ( current_weapon == level.weaponNone )
	{
		return false;
	}

	return true;
}

function perk_random_unitrigger_think( player )
{
	self endon( "kill_trigger" );

	while ( 1 )
	{
		self waittill( "trigger", player );
		self.stub.trigger_target notify( "trigger", player );
	}
}

// self = machine
function machine_think()
{
	level notify( "machine_think" );
	level endon( "machine_think" );

	//SOUND - Shawn J
	//self thread machine_sounds();

	self.num_time_used = 0;
	self.num_til_moved = RandomIntRange( RANDOM_PERK_MOVE_MIN, RANDOM_PERK_MOVE_MAX );
	
	// should only play when the ball first arrives at a location
	// turn on the light on the ball, because the ball is here and the power is on
	if (self.state !== "initial" || "idle" ) // ball is already there from initial state 
	{
		self thread set_perk_random_machine_state("arrive");
		
		self waittill("arrived");
		
		self thread set_perk_random_machine_state("initial");
		
		wait( 1 ); //wait for the machine to initialize
	}
	
	if( isdefined(level.zm_custom_perk_random_power_flag) )
	{
		level flag::wait_till( level.zm_custom_perk_random_power_flag );
	}
	else
	{
		// past this point we know that the zone is captured ( power is on )
		while( !is_power_on(self.script_int) )
		{
			wait( 1 );
		}
	}
	self thread set_perk_random_machine_state("idle");
	
	if ( isdefined( level.bottle_spawn_location ) )
	{
		level.bottle_spawn_location Delete();
	}
	
	level.bottle_spawn_location = spawn( "script_model", self.origin );
	level.bottle_spawn_location setmodel( "tag_origin" );
	level.bottle_spawn_location.angles = self.angles;

	level.bottle_spawn_location.origin += ( 0, 0, 65 );

	while( 1 )
	{
		self waittill( "trigger", player );
		level flag::clear( "machine_can_reset" ); // machine won't reset until time out or player acquires perk

		//check to see if this is in a capture zone and continue out of the loop if triggered
		if ( !player zm_score::can_player_purchase( level._random_zombie_perk_cost ) )
		{
			//player iprintln( "Not enough points to buy Perk: " + perk );
			self playsound( "evt_perk_deny" );
			//* player zm_audio::create_and_play_dialog( "general", "perk_deny", undefined, 0 );
			continue;
		}

		// MACHINE IS BEING USED
		self.machine_user = player;
		self.num_time_used++;
		player zm_stats::increment_client_stat( "use_perk_random" );
		player zm_stats::increment_player_stat( "use_perk_random" );
		player zm_score::minus_to_player_score( level._random_zombie_perk_cost );
		self thread set_perk_random_machine_state( "vending" );

		// use-machine vo line
		if ( IsDefined( level.perk_random_vo_func_usemachine ) && IsDefined( player ) )
		{
			player thread [[ level.perk_random_vo_func_usemachine ]]();
		}

		while( 1 )
		{
			// ACTIVATION SEQUENCE
			random_perk = get_weighted_random_perk( player ); // decide which perk will be made available
			//self clientfield::set( "perk_bottle_cycle_state", 1 ); // start effects before we start the bottle cycling
			
			self playsound( "zmb_rand_perk_start" );
			self playloopsound( "zmb_rand_perk_loop", 1 );
		
			//bottle spawn/perk cycling will be handled via code like the magic box
			wait( DELAY_UNTIL_BOTTLE_SPAWN );
			self notify ("bottle_spawned");
			self thread start_perk_bottle_cycling();
			self thread perk_bottle_motion(); // bottle moves into place
			model = get_perk_weapon_model( random_perk ); // show the actual available perk
			wait( DELAY_UNTIL_BOTTLE_IN_PLACE ); // delay until the perk becomes unavailable
			self notify( "done_cycling" );

			// DOES MACHINE MOVE?
			if ( self.num_time_used >= self.num_til_moved && level.perk_random_machine_count > 1 )
			{
				level.bottle_spawn_location setmodel( "wpn_t7_zmb_perk_bottle_bear_world" );
				self stoploopsound( .5 );

				self thread set_perk_random_machine_state( "leaving" );
				
				wait 3; // wait for maching to start leaving
				player zm_score::add_to_player_score( level._random_zombie_perk_cost );
				level.bottle_spawn_location setmodel( "tag_origin" );
				self thread machine_selector();
				
				//self clientfield::set( "perk_bottle_cycle_state", 0 ); // close vortex effect
				self clientfield::set( "lightning_bolt_FX_toggle", 0 ); // turn off location indicator
				//* self HidePart( "j_ball" );
				self.machine_user = undefined;
				break;
			}
			else
			{
				level.bottle_spawn_location setmodel( model );
			}

			// PERK IS AVAILABLE TO PLAYER
			self playsound( "zmb_rand_perk_bottle" );
			self.grab_perk_hint = true; // unitrigger prompt will show the grab_perk message
			self thread grab_check( player, random_perk );
			self thread time_out_check();
			self util::waittill_either( "grab_check", "time_out_check" );
			self.grab_perk_hint = false;

			self playsound( "zmb_rand_perk_stop" );
			self stoploopsound( .5 );

			// PERK IS GONE, RETURN TO IDLE STATE
			//self clientfield::set( "perk_bottle_cycle_state", 0 );
			self.machine_user = undefined;
			level.bottle_spawn_location setmodel( "tag_origin" );
			self thread set_perk_random_machine_state( "idle" );
			break;
		}

		// if the player picked up the perk, this will make us wait until the perk is fully acquired before allowing a reroll
		level flag::wait_till( "machine_can_reset" );
	}

}

function grab_check( player, random_perk )
{
	self endon( "time_out_check" );

	// only trigger if it's the player who bought the perk
	perk_is_bought = false;

	while ( !perk_is_bought )
	{
		self waittill( "trigger", e_triggerer );
		if ( e_triggerer == player )
		{
			if ( IsDefined( player.is_drinking ) && IS_DRINKING( player.is_drinking ) )
			{
				wait( 0.1 );
				continue;
			}

			if ( player zm_utility::can_player_purchase_perk() )
			{
				perk_is_bought = true;
			}
			else
			{
				self playsound( "evt_perk_deny" );
				// COLLIN: do we have a VO that would work for this? if not we'll leave it at just the deny sound
				//* player zm_audio::create_and_play_dialog( "general", "sigh" );
				self notify( "time_out_or_perk_grab" );
				return;
			}
		}
	}

	player zm_stats::increment_client_stat( "grabbed_from_perk_random" );
	player zm_stats::increment_player_stat( "grabbed_from_perk_random" );
	player thread monitor_when_player_acquires_perk();
	self notify( "grab_check" );
	self notify( "time_out_or_perk_grab" );
	player notify( "perk_purchased", random_perk );
	gun = player zm_perks::perk_give_bottle_begin( random_perk );
	evt = player util::waittill_any_ex( "fake_death", "death", "player_downed", "weapon_change_complete", self, "time_out_check" );

	if ( evt == "weapon_change_complete" )
	{
		player thread zm_perks::wait_give_perk( random_perk, true );
	}

	// restore player controls and movement
	player zm_perks::perk_give_bottle_end( gun, random_perk );

	if ( !IS_TRUE( player.has_drunk_wunderfizz ) )
	{
		//* player do_player_general_vox( "wunderfizz", "perk_wonder", undefined, 100 );
		player.has_drunk_wunderfizz = true;
	}
}

// if the player picked up the perk, this will make us wait until the perk is fully acquired before allowing a reroll
// self = player
function monitor_when_player_acquires_perk()
{
	self util::waittill_any( "perk_acquired", "death_or_disconnect", "player_downed" );
	level flag::set( "machine_can_reset" );
}

function time_out_check()
{
	self endon( "grab_check" );
	wait( DELAY_MACHINE_TIMEOUT );

	self notify( "time_out_check" );
	level flag::set( "machine_can_reset" );
}

function wait_for_power()
{
	if( isdefined(self.script_int) )
	{
		str_wait = "power_on" + self.script_int;
		level flag::wait_till( str_wait );
	}
	else if( isdefined(level.zm_custom_perk_random_power_flag) )
	{
		level flag::wait_till( level.zm_custom_perk_random_power_flag );
	}
	else
	{
		level flag::wait_till( "power_on" );
	}
	self thread set_perk_random_machine_state( "away" );
}

function machine_selector()
{

	if ( level.perk_random_machines.size == 1 )
	{
		new_machine = level.perk_random_machines[ 0 ];
		new_machine thread machine_think();
	}
	else
	{
		do
		{
			new_machine = level.perk_random_machines[ RandomInt( level.perk_random_machines.size ) ];
		}
		while( new_machine.current_perk_random_machine == true );
	
		new_machine.current_perk_random_machine = true;
		self.current_perk_random_machine = false;
		
		wait( 10 );
		new_machine thread machine_think();
	}
}

function include_perk_in_random_rotation( perk )
{
	if ( !IsDefined( level._random_perk_machine_perk_list ) )
	{
		level._random_perk_machine_perk_list = [];
	}

	ARRAY_ADD( level._random_perk_machine_perk_list, perk );
}

// return a random perk that the player doesn't have ( use level-specific weighting function for the perk array if defined )
function get_weighted_random_perk( player )
{
	keys = array::randomize( GetArrayKeys( level._random_perk_machine_perk_list ) );

	// if the level has a custom perk weights function, use that to set up the array with appropriate weighting
	if ( IsDefined( level.custom_random_perk_weights ) )
	{
		keys = player [[ level.custom_random_perk_weights ]]();
	}

	/#
	forced_perk = GetDvarString( "scr_force_perk" );
	if ( forced_perk != "" && IsDefined( level._random_perk_machine_perk_list[ forced_perk ] ) )
	{
		ArrayInsert( keys, forced_perk, 0 );
	}
	#/

	// loop through the list of perks until you find one the player doesn't have; return that perk from the array
	for ( i = 0; i < keys.size; i++ )
	{
		if ( player HasPerk( level._random_perk_machine_perk_list[ keys[ i ]] ) )
		{
			continue;
		}
		else
		{
			return level._random_perk_machine_perk_list[ keys[ i ]];
		}
	}

	return level._random_perk_machine_perk_list[ keys[ 0 ]];
}

//TEMP until we get this implemented code side
function perk_bottle_motion()
{
	const FLOAT_HEIGHT = 10;
	const BASE_HEIGHT = 53;
	const TILT_Z = 10;
	const FWD_YAW = 90;
	putOutTime = 3;
	putBackTime = 10;

	v_float = AnglesToForward( self.angles - ( 0, FWD_YAW, 0 ) ) * FLOAT_HEIGHT; // draw vector straight forward with reference to the machine angles

	// reset to original location before we start moving around
	level.bottle_spawn_location.origin = self.origin + ( 0, 0, BASE_HEIGHT );
	level.bottle_spawn_location.angles = self.angles;

	// bottle slides out from behind the portal
	level.bottle_spawn_location.origin -= v_float;
	level.bottle_spawn_location MoveTo( level.bottle_spawn_location.origin + v_float, putOutTime, ( putOutTime * 0.5 ) );
	// what a twist!
	level.bottle_spawn_location.angles += ( 0, 0, TILT_Z );
	level.bottle_spawn_location RotateYaw( 720, putOutTime, ( putOutTime * 0.5 ) );

	//SOUND - Shawn J
	//level notify( "pmstrt" );

	self waittill( "done_cycling" );
	level.bottle_spawn_location.angles = self.angles;

	// bottle slides back into the portal
	level.bottle_spawn_location MoveTo( level.bottle_spawn_location.origin - v_float, putBackTime, ( putBackTime * 0.5 ) );
	level.bottle_spawn_location RotateYaw( 90, putBackTime, ( putBackTime * 0.5 ) );
}

//TEMP until we get this implemented code side
function start_perk_bottle_cycling()
{
	self endon( "done_cycling" );

	array_key = GetArrayKeys( level.perk_bottle_weapon_array );
	timer = 0;

	while( 1 )
	{
		for( i = 0; i < array_key.size; i++ )
		{
			if ( isdefined( level.perk_bottle_weapon_array[ array_key[ i ]].weapon ) )
			{
				model = GetWeaponModel( level.perk_bottle_weapon_array[ array_key[ i ]].weapon );
			}
			else
			{
				model = GetWeaponModel( level.perk_bottle_weapon_array[ array_key[ i ]].perk_bottle_weapon );
			}

			level.bottle_spawn_location setmodel( model );
			
			wait( 0.2 );
		}
	}
}

//TEMP until we get this implemented code side
function get_perk_weapon_model( perk )
{
	weapon = level.machine_assets[ perk ].weapon;

	if ( IsDefined( level._custom_perks[ perk ] ) && IsDefined( level._custom_perks[ perk ].perk_bottle_weapon ) )
	{
		weapon = level._custom_perks[ perk ].perk_bottle_weapon;
	}

	return GetWeaponModel( weapon );
}

function perk_random_vending()
{
	self clientfield::set( "client_stone_emmissive_blink", 1 );
		
	self thread perk_random_loop_anim(ZM_PERK_RANDOM_BALL_SPIN_PIECE_INDEX, "opening", "opening");
	self thread perk_random_loop_anim(ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX, "closing", "closing");
	self thread perk_random_vend_sfx();
	self notify("vending");
	
	self waittill("bottle_spawned");
	
	self SetZBarrierPieceState(ZM_PERK_RANDOM_BOTTLE_TAG_PIECE_INDEX, "opening"); //move tag origin for bottle
	
}

function perk_random_loop_anim(n_piece, s_anim_1, s_anim_2)
{
	self endon ("zbarrier_state_change");
	current_state = self.state;
	while (self.state == current_state)
	{
		self SetZBarrierPieceState(n_piece, s_anim_1);	
		while ( self GetZBarrierPieceState( n_piece ) == s_anim_1 )
		{
			WAIT_SERVER_FRAME;
		}
		
		self SetZBarrierPieceState(n_piece, s_anim_2);	
		while ( self GetZBarrierPieceState( n_piece ) == s_anim_2 )
		{
			WAIT_SERVER_FRAME;
		}
	}
	
}

function perk_random_vend_sfx()
{
	self PlayLoopSound("zmb_rand_perk_sparks");
	level.bottle_spawn_location PlayLoopSound("zmb_rand_perk_vortex"); //the precise location of the protal
	self waittill ("zbarrier_state_change");
	self StopLoopSound();
	level.bottle_spawn_location StopLoopSound();
}

function perk_random_initial()
{
	self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX, "opening");
}

function perk_random_idle()
{
	self clientfield::set( "client_stone_emmissive_blink", 0 );
	if(IsDefined(level.perk_random_idle_effects_override))
	{
		self [[level.perk_random_idle_effects_override]]();
	}
	else 
	{
		self clientfield::set( "lightning_bolt_FX_toggle", 1 );
		while (self.state == "idle")
	  	{
	   		WAIT_SERVER_FRAME;
	   	}
		self clientfield::set( "lightning_bolt_FX_toggle", 0 );
	}
	
}

function perk_random_arrive()
{	
	

	while(self GetZBarrierPieceState(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX) == "opening")
	{
		WAIT_SERVER_FRAME;
	}
		
	self notify("arrived");
}

function perk_random_leaving()
{
	while(self GetZBarrierPieceState(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX) == "closing")
	{
		WAIT_SERVER_FRAME;
	}
	WAIT_SERVER_FRAME; // make sure animation can end for shutdowns
	self thread set_perk_random_machine_state( "away" );
	
}

function set_perk_random_machine_state(state)
{
	//self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_NO_LIGHT_BIT );
	
	wait .1;
	
	for(i = 0; i < self GetNumZBarrierPieces(); i ++)
	{
		self HideZBarrierPiece(i);
	}
	self notify("zbarrier_state_change");
	
	
	self [[level.perk_random_machine_state_func]](state);
}

function process_perk_random_machine_state( state )
{
	switch(state)
	{
		case "arrive":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX); // ball
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX); // base
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX, "opening");
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX, "opening");
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_GREEN_LIGHT_BIT );
			self thread perk_random_arrive();
			self.state = "arrive";
			break;
		case "idle":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BALL_SPIN_PIECE_INDEX); //idling ball
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX); //idling base
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX, "opening");	
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_GREEN_LIGHT_BIT );
			self.state = "idle";
			self thread perk_random_idle();
			break;
		case "power_off":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX); //base	
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX, "closing");
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_NO_LIGHT_BIT );	
			self.state = "power_off";
			break;
		case "vending":
			//show base piece
			//this handles waiting for the player to take the perk, if needed
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BALL_SPIN_PIECE_INDEX);
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX);
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BOTTLE_TAG_PIECE_INDEX);
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_GREEN_LIGHT_BIT );
			self.state = "vending";
			self thread perk_random_vending();
			break;
		case "leaving":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX);
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX);
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BALL_ON_OFF_PIECE_INDEX, "closing");	
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX, "closing");	
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_RED_LIGHT_BIT );
			self thread perk_random_leaving();
			self.state = "leaving";
			break;		
		case "away":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX); //base	
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX, "closing");	
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_RED_LIGHT_BIT );
			self.state = "away";
			break;	
		case "initial":
			//show base piece
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX); //base	
			self SetZBarrierPieceState(ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX, "opening");	
			self ShowZBarrierPiece(ZM_PERK_RANDOM_BALL_SPIN_PIECE_INDEX); //base	
			self clientfield::set( "set_client_light_state", ZM_PERK_RANDOM_NO_LIGHT_BIT );
			self.state = "initial";
			break;
		default:
			if( IsDefined( level.custom_perk_random_state_handler ) )
			{
				self [[ level.custom_perk_random_state_handler ]]( state );
			}
			break;
	}
	
}

function machine_sounds()
{
	level endon ( "machine_think" );

	while ( true )
	{
		level waittill ( "pmstrt" );
		rndprk_ent = spawn( "script_origin", self.origin );
		rndprk_ent stopsounds ();
		//* rndprk_ent playsound ( "zmb_rand_perk_start" );
		//* rndprk_ent playloopsound ( "zmb_rand_perk_loop", ( .5 ) );
		//state_switch = level util::waittill_any_return ( "pmstop", "random_perk_moving" );
		state_switch = level util::waittill_any_return ( "pmstop", "pmmove", "machine_think" );
		rndprk_ent stoploopsound ( 1 );

		if ( state_switch == "pmstop" )
		{
			//* rndprk_ent playsound ( "zmb_rand_perk_stop" );
		}

		else
		{
			//* rndprk_ent playsound ( "zmb_rand_perk_leave" );
		}

		rndprk_ent delete();
	}
}

function GetWeaponModel( weapon )
{
	return weapon.worldModel;
}

function is_power_on( n_power_index )
{
	if( isdefined(n_power_index) )
	{
		str_power = "power_on" + n_power_index;
		n_power_on = level flag::get( str_power );
	}
	else if( isdefined(level.zm_custom_perk_random_power_flag) )
	{
		n_power_on = level flag::get( level.zm_custom_perk_random_power_flag );
	}
	else
	{
		n_power_on = level flag::get( "power_on" );
	}

	return( n_power_on );
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DEVGUI
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/#
function setup_devgui()
{
	level.perk_random_devgui_callback = &wunderfizz_devgui_callback;
}

function wunderfizz_devgui_callback( cmd )
{
	players = GetPlayers();

	a_e_wunderfizzes = GetEntArray( "perk_random_machine", "targetname" );
	e_wunderfizz = ArrayGetClosest( GetPlayers()[0].origin, a_e_wunderfizzes );


	switch ( cmd )
	{
	case "wunderfizz_leaving":
		e_wunderfizz thread set_perk_random_machine_state( "leaving" );	
		break;
		
	case "wunderfizz_arriving":
		e_wunderfizz thread set_perk_random_machine_state( "arrive" );	
		
		break;
	case "wunderfizz_vending":
		e_wunderfizz thread set_perk_random_machine_state( "vending" );	
		e_wunderfizz notify ("bottle_spawned");
		
		
		break;
	case "wunderfizz_idle":
		e_wunderfizz thread set_perk_random_machine_state( "idle" );	
		
		break;
	case "wunderfizz_power_off":
		e_wunderfizz thread set_perk_random_machine_state( "power_off" );	
		
		break;
	case "wunderfizz_initial":
		e_wunderfizz thread set_perk_random_machine_state( "initial" );	
		break;
	case "wunderfizz_away":
		e_wunderfizz thread set_perk_random_machine_state( "away" );	
		
		break;
	}
}

#/


