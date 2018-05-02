
#using scripts\codescripts\struct;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_giant_amb;
#using scripts\zm\zm_giant_fx;
#using scripts\zm\zm_giant_teleporter;

#using scripts\zm\_load;
#using scripts\zm\_zm_weapons;

//Perks
#using scripts\zm\_zm_pack_a_punch;
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

#using scripts\zm\zm_usermap;


#precache( "client_fx", "zombie/fx_glow_eye_orange" );
#precache( "client_fx", "zombie/fx_bul_flesh_head_fatal_zmb" );
#precache( "client_fx", "zombie/fx_bul_flesh_head_nochunks_zmb" );
#precache( "client_fx", "zombie/fx_bul_flesh_neck_spurt_zmb" );
#precache( "client_fx", "zombie/fx_blood_torso_explo_zmb" );
#precache( "client_fx", "trail/fx_trail_blood_streak" );
#precache( "client_fx", "dlc0/factory/fx_snow_player_os_factory" );

function autoexec opt_in()
{
	clientfield::register( "world", "console_blue", VERSION_SHIP, 1, "int", &console_blue, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "console_green", VERSION_SHIP, 1, "int", &console_green, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "console_red", VERSION_SHIP, 1, "int", &console_red, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "console_start", VERSION_SHIP, 1, "int", &console_start, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "lightning_strike", VERSION_SHIP, 1, "counter", &lightning_strike, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function main()
{
	zm_usermap::main();
	
	zm_giant_fx::main();

	level._effect["animscript_gib_fx"]		= "zombie/fx_blood_torso_explo_zmb"; 
	level._effect["animscript_gibtrail_fx"]	= "trail/fx_trail_blood_streak"; 	

	level._effect[ "player_snow" ]			= "dlc0/factory/fx_snow_player_os_factory";
	
	//If enabled then the zombies will get a keyline round them so we can see them through walls
	level.debug_keyline_zombies = false;

	level thread zm_giant_amb::main();
	level thread power_on_fxanims();

	util::waitforclient( 0 );
}

function power_on_fxanims()
{
	level waittill( "power_on" );

	//level thread scene::play( "p7_fxanim_gp_wire_sparking_ground_01_bundle" );
}


function console_blue( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	s_scene = struct::get( "top_dial" );
	if( newVal )
	{
		exploder::kill_exploder( "teleporter_controller_red_light_1" );
		exploder::exploder( "teleporter_controller_light_1" );
		s_scene thread scene::play();
	}
	else
	{
		exploder::kill_exploder( "teleporter_controller_light_1" );
		s_scene scene::stop( true );
		s_scene scene::init();
	}
}

function console_green( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	s_scene = struct::get( "middle_dial" );
	if( newVal )
	{
		exploder::kill_exploder( "teleporter_controller_red_light_2" );
		exploder::exploder( "teleporter_controller_light_2" );
		s_scene thread scene::play();
	}
	else
	{
		exploder::kill_exploder( "teleporter_controller_light_2" );
		s_scene scene::stop( true );
		s_scene scene::init();
	}
}

function console_red( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	s_scene = struct::get( "bottom_dial" );
	if( newVal )
	{
		exploder::kill_exploder( "teleporter_controller_red_light_3" );
		exploder::exploder( "teleporter_controller_light_3" );
		s_scene thread scene::play();
	}
	else
	{
		exploder::kill_exploder( "teleporter_controller_light_3" );
		s_scene scene::stop( true );
		s_scene scene::init();	
	}
}

function console_start( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		exploder::exploder( "teleporter_controller_red_light_1" );
		exploder::exploder( "teleporter_controller_red_light_2" );
		exploder::exploder( "teleporter_controller_red_light_3" );
	}
}

function lightning_strike( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	SetUkkoScriptIndex( localClientNum, 1, 1 );   //index 3 and 4
    
    playsound (0, "amb_lightning_dist_low", (0,0,0));

    wait 0.02;         // off, start after sound
    SetUkkoScriptIndex( localClientNum, 3, 1 );
    wait 0.15;         //on
    SetUkkoScriptIndex( localClientNum, 1, 1 );
    wait 0.1;           //off
    SetUkkoScriptIndex( localClientNum, 4, 1 );
    wait 0.1;         //on
    SetUkkoScriptIndex( localClientNum, 3, 1 );
    wait 0.25;         //on
    SetUkkoScriptIndex( localClientNum, 1, 1 );
    wait 0.15;         //off
	SetUkkoScriptIndex( localClientNum, 3, 1 );
    wait 0.15;         //on
    SetUkkoScriptIndex( localClientNum, 1, 1 );  // off
}
