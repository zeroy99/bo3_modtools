#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\ai\zombie_utility;

//Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;

//Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;
#using scripts\zm\_zm_powerup_weapon_minigun;

//Traps
#using scripts\zm\_zm_trap_electric;

// Misc
#using scripts\zm\zm_giant_cleanup_mgr;
#using scripts\zm\zm_giant_fx;
#using scripts\zm\zm_giant_teleporter;


#using scripts\zm\zm_usermap;


#precache( "fx", "zombie/fx_glow_eye_orange" );
#precache( "fx", "zombie/fx_bul_flesh_head_fatal_zmb" );
#precache( "fx", "zombie/fx_bul_flesh_head_nochunks_zmb" );
#precache( "fx", "zombie/fx_bul_flesh_neck_spurt_zmb" );
#precache( "fx", "zombie/fx_blood_torso_explo_zmb" );
#precache( "fx", "trail/fx_trail_blood_streak" );
#precache( "fx", "electric/fx_elec_sparks_directional_orange" );

#precache( "string", "ZOMBIE_NEED_POWER" );
#precache( "string", "ZOMBIE_ELECTRIC_SWITCH" );

#precache( "model", "zombie_zapper_cagelight_red");
#precache( "model", "zombie_zapper_cagelight_green");
#precache( "model", "lights_indlight_on" );
#precache( "model", "lights_milit_lamp_single_int_on" );
#precache( "model", "lights_tinhatlamp_on" );
#precache( "model", "lights_berlin_subway_hat_0" );
#precache( "model", "lights_berlin_subway_hat_50" );
#precache( "model", "lights_berlin_subway_hat_100" );

#precache( "model", "p6_power_lever" );

#precache( "triggerstring", "ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST","1250" );
#precache( "triggerstring", "ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST","750" );
#precache( "triggerstring", "ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_COST","1000" );
#precache( "triggerstring", "ZOMBIE_BUTTON_BUY_TRAP","1000" );
#precache( "triggerstring", "ZOMBIE_UNDEFINED" );
#precache( "triggerstring", "ZOMBIE_TELEPORT_COOLDOWN" );
#precache( "triggerstring", "ZOMBIE_TELEPORT_TO_CORE" );
#precache( "triggerstring", "ZOMBIE_RANDOM_WEAPON_COST","950" );
#precache( "triggerstring", "ZOMBIE_RANDOM_WEAPON_COST","10" );
#precache( "triggerstring", "ZOMBIE_PERK_PACKAPUNCH","5000" );
#precache( "triggerstring", "ZOMBIE_PERK_PACKAPUNCH_AAT","2500" );


#precache( "fx", "zombie/fx_perk_juggernaut_factory_zmb" );
#precache( "fx", "zombie/fx_perk_quick_revive_factory_zmb" );
#precache( "fx", "zombie/fx_perk_sleight_of_hand_factory_zmb" );
#precache( "fx", "zombie/fx_perk_doubletap2_factory_zmb" );
#precache( "fx", "zombie/fx_perk_daiquiri_factory_zmb" );
#precache( "fx", "zombie/fx_perk_stamin_up_factory_zmb" );
#precache( "fx", "zombie/fx_perk_mule_kick_factory_zmb" );
#precache( "triggerstring", "ZOMBIE_PERK_QUICKREVIVE","500" );
#precache( "triggerstring", "ZOMBIE_PERK_QUICKREVIVE","1500" );
#precache( "triggerstring", "ZOMBIE_PERK_FASTRELOAD","3000" );
#precache( "triggerstring", "ZOMBIE_PERK_DOUBLETAP","2000" );
#precache( "triggerstring", "ZOMBIE_PERK_JUGGERNAUT","2500" );
#precache( "triggerstring", "ZOMBIE_PERK_ADDITIONALPRIMARYWEAPON","4000" );


//*****************************************************************************
// MAIN
//*****************************************************************************

function main()
{
	SetClearanceCeiling( 17 );	// only zombies and dogs in this level

	zm_giant_fx::main();
	init_clientfields();
	
	//Setup callbacks for bridge fxanim
	scene::add_scene_func("p7_fxanim_zm_factory_bridge_lft_bundle", &bridge_disconnect , "init" );
	scene::add_scene_func("p7_fxanim_zm_factory_bridge_lft_bundle", &bridge_connect , "done" );
	scene::add_scene_func("p7_fxanim_zm_factory_bridge_rt_bundle", &bridge_disconnect , "init" );
	scene::add_scene_func("p7_fxanim_zm_factory_bridge_rt_bundle", &bridge_connect , "done" );	

	level.randomize_perk_machine_location = true; // set before zm_usermap::main 
	level.dog_rounds_allowed=1; // set before zm_usermap::main
	
	zm_usermap::main();
	
	level._uses_default_wallbuy_fx = 1;
	
	callback::on_spawned( &on_player_spawned );
	
	//Setup game mode defaults
	level.default_start_location = "start_room";	
	level.default_game_mode = "zclassic";	

	zm::spawn_life_brush( (700, -986, 280), 128, 128 );
		
	level.random_pandora_box_start = true;	

	clock = GetEnt( "factory_clock", "targetname" );
	clock thread scene::play( "p7_fxanim_zm_factory_clock_bundle" );

	level.has_richtofen = false;	
	
	level.powerup_special_drop_override = &powerup_special_drop_override;

	level thread custom_add_vox();
	level.enemy_location_override_func = &enemy_location_override;
	level.no_target_override = &no_target_override;

	zm_pap_util::enable_swap_attachments();

	//Level specific stuff
	level.zm_custom_spawn_location_selection = &factory_custom_spawn_location_selection;

	//If enabled then the zombies will get a keyline round them so we can see them through walls
	level.debug_keyline_zombies = false;

	level.burning_zombies = [];		//JV max number of zombies that can be on fire
	level.max_barrier_search_dist_override = 400;

	level.door_dialog_function = &zm::play_door_dialog;

	level.zombie_anim_override = &zm_giant::anim_override_func;

	level._round_start_func = &zm::round_start;	

	init_sounds();
	init_achievement();
	level thread power_electric_switch();
	
	level thread magic_box_init();

	//Setup the levels Zombie Zone Volumes
	level.zones = [];
	level.zone_manager_init_func =&factory_zone_init;
	init_zones[0] = "receiver_zone";
	level thread zm_zonemgr::manage_zones( init_zones );

	level.zombie_ai_limit = 24;

	level thread jump_from_bridge();
	level lock_additional_player_spawner();

	level thread bridge_init();
	
	level thread sndFunctions();
	level.sndTrapFunc = &sndPA_Traps;
	level.monk_scream_trig = getent( "monk_scream_trig", "targetname" );

	// Special level specific settings
	zombie_utility::set_zombie_var( "zombie_powerup_drop_max_per_round", 4 );	// lower this to make drop happen more often

	level.use_powerup_volumes = true;
}

function init_clientfields()
{
	clientfield::register( "world", "console_blue", VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "console_green", VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "console_red", VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "console_start", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "lightning_strike", VERSION_SHIP, 1, "counter" );
}

function clock_shot( a_ents )
{
	clock = GetEnt( "factory_clock", "targetname" );
	clock thread scene::play( "p7_fxanim_zm_factory_clock_igc_bundle" );
}

function on_player_spawned()
{
	self thread periodic_lightning_strikes();
}

function periodic_lightning_strikes()
{
	self endon( "disconnect" );
	util::wait_network_frame(); // Hotjoin fix: Wait one network frame to make sure the clientfield has completed registration. 
	
	while( true )
	{
		n_random_wait = RandomIntRange( 12, 18 );
		
		if( isdefined( self ) && IsPlayer( self ) )
		{
			self notify( "lightning_strike" );
			self clientfield::increment_to_player( "lightning_strike", 1 );
		}
		wait n_random_wait;
	}
}


function custom_add_vox()
{
	zm_audio::loadPlayerVoiceCategories("gamedata/audio/zm/zm_factory_vox.csv");
}


function init_achievement()
{
}


//-------------------------------------------------------------------------------
//	Create the zone information for zombie spawning
//-------------------------------------------------------------------------------
function factory_zone_init()
{
	// Note this setup is based on a flag-centric view of setting up your zones.  A brief
	//	zone-centric example exists below in comments

	// Outside East Door
	zm_zonemgr::add_adjacent_zone( "receiver_zone",		"outside_east_zone",	"enter_outside_east" );

	// Outside West Door
	zm_zonemgr::add_adjacent_zone( "receiver_zone",		"outside_west_zone",	"enter_outside_west" );

	// Wnuen building ground floor
	zm_zonemgr::add_adjacent_zone( "wnuen_zone",		"outside_east_zone",	"enter_wnuen_building" );

	// Wnuen stairway
	zm_zonemgr::add_adjacent_zone( "wnuen_zone",		"wnuen_bridge_zone",	"enter_wnuen_loading_dock" );

	// Warehouse bottom 
	zm_zonemgr::add_adjacent_zone( "warehouse_bottom_zone", "outside_west_zone",	"enter_warehouse_building" );

	// Warehosue top
	zm_zonemgr::add_adjacent_zone( "warehouse_bottom_zone", "warehouse_top_zone",	"enter_warehouse_second_floor" );
	zm_zonemgr::add_adjacent_zone( "warehouse_top_zone",	"bridge_zone",			"enter_warehouse_second_floor" );

	// TP East
	zm_zonemgr::add_adjacent_zone( "tp_east_zone",			"wnuen_zone",			"enter_tp_east" );
	
	zm_zonemgr::add_adjacent_zone( "tp_east_zone",			"outside_east_zone",	"enter_tp_east",			true );
	zm_zonemgr::add_zone_flags(	"enter_tp_east",										"enter_wnuen_building" );

	// TP South
	zm_zonemgr::add_adjacent_zone( "tp_south_zone",			"outside_south_zone",	"enter_tp_south" );

	// TP West
	zm_zonemgr::add_adjacent_zone( "tp_west_zone",			"warehouse_top_zone",	"enter_tp_west" );
	
	//_zm_zonemgr::add_adjacent_zone( "tp_west_zone",			"warehouse_bottom_zone", "enter_tp_west",		true );
	//_zm_zonemgr::add_zone_flags(	"enter_tp_west",										"enter_warehouse_second_floor" );
}


function enemy_location_override( zombie, enemy )
{
	AIProfile_BeginEntry( "factory-enemy_location_override" );

	if ( IS_TRUE( zombie.is_trapped ) )
	{
		AIProfile_EndEntry();
		return zombie.origin;
	}

	AIProfile_EndEntry();
	return undefined;
}

// --------------------------------
//	NO TARGET OVERRIDE
// --------------------------------
function validate_and_set_no_target_position( position )
{
	if( IsDefined( position ) )
	{
		goal_point = GetClosestPointOnNavMesh( position.origin, 100 );
		if( IsDefined( goal_point ) )
		{
			self SetGoal( goal_point );
			self.has_exit_point = 1;
			return true;
		}
	}
	
	return false;
}

function no_target_override( zombie )
{
	if( isdefined( zombie.has_exit_point ) )
	{
		return;
	}
	
	players = level.players;
	
	dist_zombie = 0;
	dist_player = 0;
	dest = 0;

	if ( isdefined( level.zm_loc_types[ "dog_location" ] ) )
	{
		locs = array::randomize( level.zm_loc_types[ "dog_location" ] );
		
		for ( i = 0; i < locs.size; i++ )
		{
			found_point = false;
			foreach( player in players )
			{
				if( player laststand::player_is_in_laststand() )
				{
					continue;
				}
				
				away = VectorNormalize( self.origin - player.origin );
				endPos = self.origin + VectorScale( away, 600 );
				dist_zombie = DistanceSquared( locs[i].origin, endPos );
				dist_player = DistanceSquared( locs[i].origin, player.origin );
		
				if ( dist_zombie < dist_player )
				{
					dest = i;
					found_point= true;
				}
				else
				{
					found_point = false;
				}
			}
			if( found_point )
			{
				if( zombie validate_and_set_no_target_position( locs[i] ) )
				{
					return;
				}
			}
		}
	}
	
	
	escape_position = zombie giant_cleanup::get_escape_position_in_current_zone();
			
	if( zombie validate_and_set_no_target_position( escape_position ) )
	{
		return;
	}
	
	escape_position = zombie giant_cleanup::get_escape_position();
	
	if( zombie validate_and_set_no_target_position( escape_position ) )
	{
		return;
	}
	
	zombie.has_exit_point = 1;
	
	zombie SetGoal( zombie.origin );
}

// --------------------------------

function anim_override_func()
{
}

function lock_additional_player_spawner()
{
	spawn_points = struct::get_array("player_respawn_point", "targetname");
	for( i = 0; i < spawn_points.size; i++ )
	{
		spawn_points[i].locked = true;
	}
}

//-------------------------------------------------------------------------------
// handles lowering the bridge when power is turned on
//-------------------------------------------------------------------------------
function bridge_init()
{
	level flag::init( "bridge_down" );
	
	bridge_audio = struct::get( "bridge_audio", "targetname" );

	// wait for power
	level flag::wait_till( "power_on" );
	level util::clientnotify ("pl1");
	
	level thread scene::play( "p7_fxanim_zm_factory_bridge_lft_bundle" );
	level scene::play( "p7_fxanim_zm_factory_bridge_rt_bundle" );
	// wait until the bridges are down.
	
	level flag::set( "bridge_down" );

	wnuen_bridge_clip = getent( "wnuen_bridge_clip", "targetname" );
	wnuen_bridge_clip connectpaths();
	wnuen_bridge_clip delete();

	warehouse_bridge_clip = getent( "warehouse_bridge_clip", "targetname" );
	warehouse_bridge_clip connectpaths();
	warehouse_bridge_clip delete();

	wnuen_bridge = getent( "wnuen_bridge", "targetname" );
	wnuen_bridge connectpaths();

	zm_zonemgr::connect_zones( "wnuen_bridge_zone", "bridge_zone" );
	zm_zonemgr::connect_zones( "warehouse_top_zone", "bridge_zone" );
	
	wait(14);
	
	level thread zm_giant::sndPA_DoVox( "vox_maxis_teleporter_lost_0" );
}

function bridge_disconnect( a_parts )
{
	foreach( part in a_parts )
	{
		part DisconnectPaths();
	}
}

function bridge_connect( a_parts )
{
	foreach( part in a_parts )
	{
		part ConnectPaths();
	}
}

function jump_from_bridge()
{
	trig = GetEnt( "trig_outside_south_zone", "targetname" );
	trig waittill( "trigger" );

	zm_zonemgr::connect_zones( "outside_south_zone", "bridge_zone", true );
	zm_zonemgr::connect_zones( "outside_south_zone", "wnuen_bridge_zone", true );
}


function init_sounds()
{
	zm_utility::add_sound( "break_stone", "evt_break_stone" );
	zm_utility::add_sound( "gate_door",	"zmb_gate_slide_open" );
	zm_utility::add_sound( "heavy_door",	"zmb_heavy_door_open" );

	// override the default slide with the buzz slide
	zm_utility::add_sound("zmb_heavy_door_open", "zmb_heavy_door_open");
}

//
//	This initialitze the box spawn locations
//	You can disable boxes from appearing by not adding their script_noteworthy ID to the list
//
function magic_box_init()
{
	//MM - all locations are valid.  If it goes somewhere you haven't opened, you need to open it.
	level.open_chest_location = [];
	level.open_chest_location[0] = "chest1";	// TP East
	level.open_chest_location[1] = "chest2";	// TP West
	level.open_chest_location[2] = "chest3";	// TP South
	level.open_chest_location[3] = "chest4";	// WNUEN
	level.open_chest_location[4] = "chest5";	// Warehouse bottom
	level.open_chest_location[5] = "start_chest";
}


#define JUGGERNAUT_MACHINE_LIGHT_FX				"jugger_light"		
#define QUICK_REVIVE_MACHINE_LIGHT_FX			"revive_light"		
#define STAMINUP_MACHINE_LIGHT_FX				"marathon_light"	
#define WIDOWS_WINE_FX_MACHINE_LIGHT				"widow_light"
#define SLEIGHT_OF_HAND_MACHINE_LIGHT_FX				"sleight_light"		
#define DOUBLETAP2_MACHINE_LIGHT_FX				"doubletap2_light"		
#define DEADSHOT_MACHINE_LIGHT_FX				"deadshot_light"		
#define ADDITIONAL_PRIMARY_WEAPON_MACHINE_LIGHT_FX					"additionalprimaryweapon_light"



/*------------------------------------
the electric switch under the bridge
once this is used, it activates other objects in the map
and makes them available to use
------------------------------------*/
function power_electric_switch()
{
	trig = getent("use_power_switch","targetname");
	trig sethintstring(&"ZOMBIE_ELECTRIC_SWITCH");
	trig SetCursorHint( "HINT_NOICON" ); 

	//turn off the buyable door triggers for electric doors
// 	door_trigs = getentarray("electric_door","script_noteworthy");
// 	array::thread_all(door_trigs,::set_door_unusable);
// 	array::thread_all(door_trigs,::play_door_dialog);

	cheat = false;
	
	user = undefined;
	if ( cheat != true )
	{
		trig waittill("trigger",user);
		if( isdefined( user ) )
		{
			//user zm_audio::create_and_play_dialog( "general", "power_on" );
		}
	}
	
	level thread scene::play( "power_switch", "targetname" );

	//TO DO (TUEY) - kick off a 'switch' on client script here that operates similiarly to Berlin2 subway.
	level flag::set( "power_on" );
	util::wait_network_frame();
	level notify( "sleight_on" );
	util::wait_network_frame();
	level notify( "revive_on" );
	util::wait_network_frame();
	level notify( "doubletap_on" );
	util::wait_network_frame();
	level notify( "juggernog_on" );
	util::wait_network_frame();
	level notify( "Pack_A_Punch_on" );
	util::wait_network_frame();
	level notify( "specialty_armorvest_power_on" );
	util::wait_network_frame();
	level notify( "specialty_rof_power_on" );
	util::wait_network_frame();
	level notify( "specialty_quickrevive_power_on" );
	util::wait_network_frame();
	level notify( "specialty_fastreload_power_on" );
	util::wait_network_frame();

	level util::set_lighting_state( 0 );

	util::clientNotify("ZPO");	// Zombie Power On!
	util::wait_network_frame();

	trig delete();	
	
	wait 1;
	
	s_switch = struct::get("power_switch_fx","targetname");
	forward = AnglesToForward( s_switch.origin );
	playfx( level._effect["switch_sparks"], s_switch.origin, forward );

	// Don't want east or west to spawn when in south zone, but vice versa is okay
	zm_zonemgr::connect_zones( "outside_east_zone", "outside_south_zone" );
	zm_zonemgr::connect_zones( "outside_west_zone", "outside_south_zone", true );
	
	level util::delay( 19, undefined, &zm_audio::sndMusicSystem_PlayState, "power_on" );
}

//*** AUDIO SECTION ***


//-------------------------------------------------------------------------------
// Solo Revive zombie exit points.
//-------------------------------------------------------------------------------
function factory_exit_level()
{
	zombies = GetAiArray( level.zombie_team );
	for ( i = 0; i < zombies.size; i++ )
	{
		zombies[i] thread factory_find_exit_point();
	}
}

function factory_find_exit_point()
{
	self endon( "death" );

	player = GetPlayers()[0];

	dist_zombie = 0;
	dist_player = 0;
	dest = 0;

	away = VectorNormalize( self.origin - player.origin );
	endPos = self.origin + VectorScale( away, 600 );

	locs = array::randomize( level.zm_loc_types[ "dog_location" ] );

	for ( i = 0; i < locs.size; i++ )
	{
		dist_zombie = DistanceSquared( locs[i].origin, endPos );
		dist_player = DistanceSquared( locs[i].origin, player.origin );

		if ( dist_zombie < dist_player )
		{
			dest = i;
			break;
		}
	}

	self notify( "stop_find_flesh" );
	self notify( "zombie_acquire_enemy" );

	self SetGoal( locs[dest].origin );

	while ( 1 )
	{
		if ( !level flag::get( "wait_and_revive" ) )
		{
			break;
		}
		util::wait_network_frame();
	}
	
}

function powerup_special_drop_override()
{
	// Always give something at lower rounds or if a player is in last stand mode.
	if ( level.round_number <= 10 )
	{
		powerup = zm_powerups::get_valid_powerup();
	}
	// Gets harder now
	else
	{
		powerup = level.zombie_special_drop_array[ RandomInt(level.zombie_special_drop_array.size) ];
		if ( level.round_number > 15 && ( RandomInt(100) < (level.round_number - 15)*5 ) )
		{
			powerup = "nothing";
		}
	}

	//MM test  Change this if you want the same thing to keep spawning
	//powerup = "dog";
	switch ( powerup )
	{
		// Limit max ammo drops because it's too powerful
		case "full_ammo":
			if ( level.round_number > 10 && ( RandomInt(100) < (level.round_number - 10)*5 ) )
			{
				// Randomly pick another one
				powerup = level.zombie_powerup_array[ RandomInt(level.zombie_powerup_array.size) ];
			}
			break;

		// Nothing drops!!
		case "free_perk":	// "nothing"
		case "nothing":	// "nothing"
			// RAVEN BEGIN bhackbarth: callback for level specific powerups
			if ( IsDefined( level._zombiemode_special_drop_setup ) )
			{
				is_powerup = [[ level._zombiemode_special_drop_setup ]]( powerup );
			}
			// RAVEN END
			else
			{
				Playfx( level._effect["lightning_dog_spawn"], self.origin );
				playsoundatposition( "zmb_hellhound_prespawn", self.origin );
				wait( 1.5 );
				playsoundatposition( "zmb_hellhound_bolt", self.origin );
	
				Earthquake( 0.5, 0.75, self.origin, 1000);
				//PlayRumbleOnPosition("explosion_generic", self.origin);//TODO T7 - fix rumble
				playsoundatposition( "zmb_hellhound_spawn", self.origin );
	
				wait( 1.0 );
				//iprintlnbold( "Samantha Sez: No Powerup For You!" );
				thread zm_utility::play_sound_2d( "vox_sam_nospawn" );
				self Delete();
			}
			powerup = undefined;
			break;
	}
	return powerup;
}

//AUDIO
#define DEMPSEY 0
#define NIKOLAI 1
#define RICHTOFEN 2
#define TAKEO 3
#define RANDOM_PLAYER 4
function sndFunctions()
{
	level thread setupMusic();
	level thread sndFirstDoor();
	level thread sndPASetup();
	level thread sndConversations();
}

function sndConversations()
{
	level flag::wait_till( "initial_blackscreen_passed" );
	
	level zm_audio::sndConversation_Init( "round1start" );
	level zm_audio::sndConversation_AddLine( "round1start", "round1_start_0", RANDOM_PLAYER, RICHTOFEN );
	level zm_audio::sndConversation_AddLine( "round1start", "round1_start_0", RICHTOFEN );
	level zm_audio::sndConversation_AddLine( "round1start", "round1_start_1", RANDOM_PLAYER, RICHTOFEN );
	level zm_audio::sndConversation_AddLine( "round1start", "round1_start_1", RICHTOFEN );
	
	level zm_audio::sndConversation_Init( "round1during", "end_of_round" );
	level zm_audio::sndConversation_AddLine( "round1during", "round1_during_0", NIKOLAI );
	level zm_audio::sndConversation_AddLine( "round1during", "round1_during_0", TAKEO );
	level zm_audio::sndConversation_AddLine( "round1during", "round1_during_0", DEMPSEY );
	level zm_audio::sndConversation_AddLine( "round1during", "round1_during_0", RICHTOFEN );
	
	level zm_audio::sndConversation_Init( "round1end" );
	level zm_audio::sndConversation_AddLine( "round1end", "round1_end_0", RANDOM_PLAYER, RICHTOFEN );
	level zm_audio::sndConversation_AddLine( "round1end", "round1_end_0", RICHTOFEN );
	
	level zm_audio::sndConversation_Init( "round2during", "end_of_round" );
	level zm_audio::sndConversation_AddLine( "round2during", "round2_during_0", DEMPSEY );
	level zm_audio::sndConversation_AddLine( "round2during", "round2_during_0", TAKEO );
	level zm_audio::sndConversation_AddLine( "round2during", "round2_during_0", NIKOLAI );
	level zm_audio::sndConversation_AddLine( "round2during", "round2_during_0", RICHTOFEN );
	
	if( level.players.size >= 2 )
	{
		level thread sndConvo1();
		level thread sndConvo2();
		level thread sndConvo3();
		level thread sndConvo4();
	}
	else
	{
		level thread sndFieldReport1();
	}
}

function sndConvo1()
{
	wait(randomintrange(2,5));
	level zm_audio::sndConversation_Play( "round1start" );
}

function sndConvo2()
{
	level waittill( "sndConversationDone" );
	wait(randomintrange(20,30));
	level zm_audio::sndConversation_Play( "round1during" );
}

function sndConvo3()
{
	level waittill( "end_of_round" );
	wait(randomintrange(4,7));
	level zm_audio::sndConversation_Play( "round1end" );
}

function sndConvo4()
{
	while(1)
	{
		level waittill( "start_of_round" );
		
		if( !IS_TRUE( level.first_round ) )
			break;
	}
	
	wait(randomintrange(45,60));
	level zm_audio::sndConversation_Play( "round2during" );
}

function sndFieldReport1()
{
	wait(randomintrange(7,10));
	
	while( IS_TRUE( level.players[0].isSpeaking ) )
		wait(.5);
	
	level.sndVoxOverride = true;
	doLine( level.players[0], "fieldreport_start_0" );
	if( isdefined( getSpecificCharacter(2) ) )
	{
		doLine( level.players[0], "fieldreport_start_1" );
	}
	level.sndVoxOverride = false;
	
	level thread sndFieldReport2();
}

function sndFieldReport2()
{
	level waittill( "end_of_round" );
	wait(randomintrange(1,3));
	
	while( IS_TRUE( level.players[0].isSpeaking ) )
		wait(.5);
	
	level.sndVoxOverride = true;
	doLine( level.players[0], "fieldreport_round1_0" );
	level.sndVoxOverride = false;
	
	level thread sndFieldReport3();
}

function sndFieldReport3()
{
	level waittill( "end_of_round" );
	wait(randomintrange(1,3));
	
	while( IS_TRUE( level.players[0].isSpeaking ) )
		wait(.5);
	
	level.sndVoxOverride = true;
	doLine( level.players[0], "fieldreport_round2_0" );
	if( isdefined( getSpecificCharacter(2) ) )
	{
		doLine( level.players[0], "fieldreport_round2_1" );
	}
	level.sndVoxOverride = false;
}

function doLine( guy, alias )
{
	if( isdefined( guy ) )
	{
		guy clientfield::set_to_player( "isspeaking",1 ); 
		guy playsoundontag( "vox_plr_"+guy.characterIndex+"_"+alias, "J_Head" );
		waitPlaybackTime("vox_plr_"+guy.characterIndex+"_"+alias);
		guy clientfield::set_to_player( "isspeaking",0 );
	}
}

function waitPlaybackTime(alias)
{
	playbackTime = soundgetplaybacktime( alias );
			
	if( !isdefined( playbackTime ) )
		playbackTime = 1;
			
	if ( playbackTime >= 0 )
		playbackTime = playbackTime * .001;
	else
		playbackTime = 1;
			
	wait(playbacktime);
}
function getRandomNotRichtofen()
{
	array = level.players;
	array::randomize( array );
	
	foreach( guy in array )
	{
		if( guy.characterIndex != 2 )
			return guy;
	}
	return undefined;
}
function getSpecificCharacter(charIndex)
{
	foreach( guy in level.players )
	{
		if( guy.characterIndex == charIndex )
			return guy;
	}
	return undefined;
}
function isAnyoneTalking()
{
	foreach( player in level.players )
	{
		if( IS_TRUE( player.isSpeaking ) )
		{
			return true;
		}
	}
	
	return false;
}

#define PLAYTYPE_REJECT 1
#define PLAYTYPE_QUEUE 2
#define PLAYTYPE_ROUND 3
#define PLAYTYPE_SPECIAL 4
#define PLAYTYPE_GAMEEND 5
function setupMusic()
{
	zm_audio::musicState_Create("round_start", PLAYTYPE_ROUND, "roundstart1", "roundstart2", "roundstart3", "roundstart4" );
	zm_audio::musicState_Create("round_start_short", PLAYTYPE_ROUND, "roundstart_short1", "roundstart_short2", "roundstart_short3", "roundstart_short4" );
	zm_audio::musicState_Create("round_start_first", PLAYTYPE_ROUND, "roundstart_first" );
	zm_audio::musicState_Create("round_end", PLAYTYPE_ROUND, "roundend1" );
	zm_audio::musicState_Create("game_over", PLAYTYPE_GAMEEND, "gameover" );
	zm_audio::musicState_Create("dog_start", PLAYTYPE_ROUND, "dogstart1" );
	zm_audio::musicState_Create("dog_end", PLAYTYPE_ROUND, "dogend1" );
	zm_audio::musicState_Create("timer", PLAYTYPE_ROUND, "timer" );
	zm_audio::musicState_Create("power_on", PLAYTYPE_QUEUE, "poweron" );
}

function sndFirstDoor()
{
	level waittill( "sndDoorOpening" );
	level thread zm_audio::sndMusicSystem_PlayState( "first_door" );
}

function sndPASetup()
{
	level.paTalking = false;
	level.paArray = array();
	
	array = struct::get_array( "pa_system", "targetname" );
	foreach( pa in array )
	{
		ent = spawn( "script_origin", pa.origin );
		ARRAY_ADD(level.paArray, ent);
	}
}
function sndPA_DoVox( alias, delay, nowait = false )
{
	if( isdefined( delay ) )
		wait(delay);
	
	if( !IS_TRUE( level.paTalking ) )
	{
		level.paTalking = true;
		
		level thread sndPA_playvox(alias);
		
		playbacktime = soundgetplaybacktime( alias );
		if( !isdefined( playbacktime ) || playbacktime <= 2 )
			waittime = 1;
		else
			waittime = playbackTime * .001;
	
		if( !nowait )
		{
			wait(waittime-.9);
		}
		
		level.paTalking = false;
	}
}
function sndPA_playvox( alias )
{
	array::randomize(level.paArray);
	
	foreach( pa in level.paArray )
	{
		pa playsound( alias );
		wait(.05);
	}
}
function sndPA_Traps(trap,stage)
{
	if( isdefined( trap ) )
	{
		if( stage == 1 )
		{
			switch( trap.target )
			{
				case "trap_b":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_warehouse_inuse_0", 2 );
					break;
				case "trap_a":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_lab_inuse_0", 2 );
					break;
				case "trap_c":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_bridge_inuse_0", 2 );
					break;
			}
		}
		else
		{
			switch( trap.target )
			{
				case "trap_b":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_warehouse_active_0", 4 );
					break;
				case "trap_a":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_lab_active_0", 4 );
					break;
				case "trap_c":
					level thread zm_giant::sndPA_DoVox( "vox_maxis_trap_bridge_active_0", 4 );
					break;
			}
		}
	}
}

function factory_custom_spawn_location_selection( a_spots )
{
	if( level.zombie_respawns > 0 )
	{
		if( !isdefined(level.n_player_spawn_selection_index) )
		{
			level.n_player_spawn_selection_index = 0;
		}

		// Get a player to spawn close by
		a_players = GetPlayers();
		level.n_player_spawn_selection_index++;
		if(		level.n_player_spawn_selection_index >= a_players.size )
		{
			level.n_player_spawn_selection_index = 0;
		}
		e_player = a_players[ level.n_player_spawn_selection_index ];

		// Order the spots so they are closest to the player
		ArraySortClosest( a_spots, e_player.origin );

		a_candidates = [];

		// Now pick the first 10 spots ahead of the player
		v_player_dir = anglestoforward( e_player.angles );
		for( i=0; i<a_spots.size; i++ )
		{
			v_dir = a_spots[i].origin - e_player.origin;
			dp = vectordot( v_player_dir, v_dir );
			if( dp >= 0.0 )
			{
				a_candidates[a_candidates.size] = a_spots[i];
				if( a_candidates.size > 10 )
				{
					break;
				}
			}
		}

		if( a_candidates.size )
		{
			s_spot = array::random(a_candidates);
		}
		else
		{
			s_spot = array::random(a_spots);
		}
	}

	else
	{
		s_spot = array::random(a_spots);
	}
	
	return( s_spot );
}


function fx_overrides()
{
}

