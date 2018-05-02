#using scripts\codescripts\struct;

#using scripts\shared\audio_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;//DO NOT REMOVE - needed for system registration
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\load_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\music_shared;
#using scripts\shared\_oob;
#using scripts\shared\scene_shared;
#using scripts\shared\serverfaceanim_shared;
#using scripts\shared\system_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\archetype_shared\archetype_shared;

//Abilities
#using scripts\shared\abilities\_ability_player;	//DO NOT REMOVE - needed for system registration

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm;
#using scripts\zm\gametypes\_spawnlogic;

#using scripts\zm\_destructible;
#using scripts\zm\_util;

//REGISTRATION - These scripts are initialized here
//Do not remove unless you are removing the script from the game

//Gametypes Registration
#using scripts\zm\gametypes\_clientids;
#using scripts\zm\gametypes\_scoreboard;
#using scripts\zm\gametypes\_serversettings;
#using scripts\zm\gametypes\_shellshock;
#using scripts\zm\gametypes\_spawnlogic;
#using scripts\zm\gametypes\_spectating;
#using scripts\zm\gametypes\_weaponobjects;

//Systems registration
#using scripts\zm\_art;
#using scripts\zm\_callbacks;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_behavior;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_bot;
#using scripts\zm\_zm_clone;
#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_playerhealth;
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_zonemgr;

//Weapon registration
#using scripts\zm\gametypes\_weaponobjects;

#precache( "fx", "_t6/bio/player/fx_footstep_dust" );
#precache( "fx", "_t6/bio/player/fx_footstep_sand" );
#precache( "fx", "_t6/bio/player/fx_footstep_mud" );
#precache( "fx", "_t6/bio/player/fx_footstep_water" );

#namespace load;

function main()
{
	zm::init();

	level._loadStarted = true;
	
	register_clientfields();

	level.aiTriggerSpawnFlags = getaitriggerflags();
	level.vehicleTriggerSpawnFlags = getvehicletriggerflags();
		
	level thread start_intro_screen_zm();

	//thread _spawning::init();
	//thread _deployable_weapons::init();
	//thread _minefields::init();
	//thread _rotating_object::init();
	//thread _shutter::main();
	//thread _flare::init();
	//thread _pipes::main();
	//thread _vehicles::init();
	//thread _dogs::init();
	//thread _tutorial::init();
	
	setup_traversals();

 	footsteps();
 	
	system::wait_till( "all" );

	level thread load::art_review();

 	level flagsys::set( "load_main_complete" );
}

function footsteps()
{
	if ( IS_TRUE( level.FX_exclude_footsteps ) ) 
	{
		return;
	}

	zombie_utility::setFootstepEffect( "asphalt",  "_t6/bio/player/fx_footstep_dust" ); 
	zombie_utility::setFootstepEffect( "brick",    "_t6/bio/player/fx_footstep_dust" );
	zombie_utility::setFootstepEffect( "carpet",   "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "cloth",    "_t6/bio/player/fx_footstep_dust" );
	zombie_utility::setFootstepEffect( "concrete", "_t6/bio/player/fx_footstep_dust" ); 
	zombie_utility::setFootstepEffect( "dirt",     "_t6/bio/player/fx_footstep_sand" );
	zombie_utility::setFootstepEffect( "foliage",  "_t6/bio/player/fx_footstep_sand" );  
	zombie_utility::setFootstepEffect( "gravel",   "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "grass",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "metal",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "mud",      "_t6/bio/player/fx_footstep_mud" ); 
	zombie_utility::setFootstepEffect( "paper",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "plaster",  "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "rock",     "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "sand",     "_t6/bio/player/fx_footstep_sand" );  
	zombie_utility::setFootstepEffect( "water",    "_t6/bio/player/fx_footstep_water" );
	zombie_utility::setFootstepEffect( "wood",     "_t6/bio/player/fx_footstep_dust" ); 
}

function setup_traversals()
{
	/*
	potential_traverse_nodes = GetAllNodes();
	for (i = 0; i < potential_traverse_nodes.size; i++)
	{
		node = potential_traverse_nodes[i];
		if (node.type == "Begin")
		{
			node zombie_shared::init_traverse();
		}
	}
	*/
}

function start_intro_screen_zm( )
{
	players = GetPlayers();
	for(i = 0; i < players.size; i++)
	{
		players[i] lui::screen_fade_out( 0, undefined );
		players[i] freezecontrols(true);
	}
	wait 1;
}

function register_clientfields()
{
	//clientfield::register( "missile", "cf_m_proximity", VERSION_SHIP, 1, "int" );
	//clientfield::register( "missile", "cf_m_emp", VERSION_SHIP, 1, "int" );
	//clientfield::register( "missile", "cf_m_stun", VERSION_SHIP, 1, "int" );
	
	//clientfield::register( "scriptmover", "cf_s_emp", VERSION_SHIP, 1, "int" );
	//clientfield::register( "scriptmover", "cf_s_stun", VERSION_SHIP, 1, "int" );
	
	//clientfield::register( "world", "sndPrematch", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "sndMelee", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "sndEMP", VERSION_SHIP, 1, "int" );	
	
	clientfield::register( "allplayers", "zmbLastStand", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "zmbLastStand", VERSION_SHIP, 1, "int" );

	clientfield::register( "clientuimodel", "zmhud.swordEnergy", VERSION_SHIP, 7, "float" ); // energy: 0 to 1
	clientfield::register( "clientuimodel", "zmhud.swordState", VERSION_SHIP, 4, "int" ); // state: 0 = hidden, 1 = charging, 2 = ready, 3 = inuse, 4 = unavailable (grey), 5 = ele-charging, 6 = ele-ready, 7 = ele-inuse,
	clientfield::register( "clientuimodel", "zmhud.swordChargeUpdate", VERSION_SHIP, 1, "counter" );
}
