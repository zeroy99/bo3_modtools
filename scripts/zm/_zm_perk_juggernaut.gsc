#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_util;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perk_juggernaut.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", "specialty_juggernaut_zombies" );
#precache( "string", "ZOMBIE_PERK_JUGGERNAUT" );
#precache( "fx", "zombie/fx_perk_juggernaut_zmb" );

#namespace zm_perk_juggernaut;

REGISTER_SYSTEM( "zm_perk_juggernaut", &__init__, undefined )

// JUGGERNAUT

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_juggernaut_perk_for_level();
}

function enable_juggernaut_perk_for_level()
{	
	// register juggernaut perk for level
	zm_perks::register_perk_basic_info( PERK_JUGGERNOG, "juggernog", JUGGERNAUT_PERK_COST, &"ZOMBIE_PERK_JUGGERNAUT", GetWeapon( JUGGERNAUT_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_JUGGERNOG, &juggernaut_precache );
	zm_perks::register_perk_clientfields( PERK_JUGGERNOG, &juggernaut_register_clientfield, &juggernaut_set_clientfield );
	zm_perks::register_perk_machine( PERK_JUGGERNOG, &juggernaut_perk_machine_setup, &init_juggernaut );
	zm_perks::register_perk_threads( PERK_JUGGERNOG, &give_juggernaut_perk, &take_juggernaut_perk );
	zm_perks::register_perk_host_migration_params( PERK_JUGGERNOG, JUGGERNAUT_RADIANT_MACHINE_NAME, JUGGERNAUT_MACHINE_LIGHT_FX );
}	
	
function init_juggernaut()
{	
	// tweakable variables
	zombie_utility::set_zombie_var( "zombie_perk_juggernaut_health",	100 );
	zombie_utility::set_zombie_var( "zombie_perk_juggernaut_health_upgrade",	150 );		
}

function juggernaut_precache()
{
	if( IsDefined(level.juggernaut_precache_override_func) )
	{
		[[ level.juggernaut_precache_override_func ]]();
		return;
	}
	
	level._effect[JUGGERNAUT_MACHINE_LIGHT_FX] = "zombie/fx_perk_juggernaut_zmb";
	
	level.machine_assets[PERK_JUGGERNOG] = SpawnStruct();
	level.machine_assets[PERK_JUGGERNOG].weapon = GetWeapon( JUGGERNAUT_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_JUGGERNOG].off_model = JUGGERNAUT_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_JUGGERNOG].on_model = JUGGERNAUT_MACHINE_ACTIVE_MODEL;
}

function juggernaut_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_JUGGERNAUT, VERSION_SHIP, 2, "int" );
}

function juggernaut_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_JUGGERNAUT, state );
}

function juggernaut_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_jugganog_jingle";
	use_trigger.script_string = "jugg_perk";
	use_trigger.script_label = "mus_perks_jugganog_sting";
	use_trigger.longJingleWait = true;
	use_trigger.target = "vending_jugg";
	perk_machine.script_string = "jugg_perk";
	perk_machine.targetname = "vending_jugg";
	if( IsDefined( bump_trigger ) )
	{
		bump_trigger.script_string = "jugg_perk";
	}
}

function give_juggernaut_perk()
{
	// Increment player max health if its the jugg perk
	self zm_perks::perk_set_max_health_if_jugg( PERK_JUGGERNOG, true, false );
}

function take_juggernaut_perk( b_pause, str_perk, str_result )
{
	// Increment player max health if its the jugg perk
	self zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, true );
}
