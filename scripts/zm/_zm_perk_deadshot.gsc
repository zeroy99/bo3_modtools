#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perk_deadshot.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", DEADSHOT_SHADER );
#precache( "string", "ZOMBIE_PERK_DEADSHOT" );
#precache( "fx", "_t6/misc/fx_zombie_cola_dtap_on" );

#namespace zm_perk_deadshot;

REGISTER_SYSTEM( "zm_perk_deadshot", &__init__, undefined )

// DEAD SHOT ( DEADSHOT DAIQUIRI )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_deadshot_perk_for_level();
}

function enable_deadshot_perk_for_level()
{	
	// register sleight of hand perk for level
	zm_perks::register_perk_basic_info( PERK_DEAD_SHOT, "deadshot", DEADSHOT_PERK_COST, &"ZOMBIE_PERK_DEADSHOT", GetWeapon( DEADSHOT_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_DEAD_SHOT, &deadshot_precache );
	zm_perks::register_perk_clientfields( PERK_DEAD_SHOT, &deadshot_register_clientfield, &deadshot_set_clientfield );
	zm_perks::register_perk_machine( PERK_DEAD_SHOT, &deadshot_perk_machine_setup );
	zm_perks::register_perk_threads( PERK_DEAD_SHOT, &give_deadshot_perk, &take_deadshot_perk );
	zm_perks::register_perk_host_migration_params( PERK_DEAD_SHOT, DEADSHOT_RADIANT_MACHINE_NAME, DEADSHOT_MACHINE_LIGHT_FX );
}

function deadshot_precache()
{
	if( IsDefined(level.deadshot_precache_override_func) )
	{
		[[ level.deadshot_precache_override_func ]]();
		return;
	}
	
	level._effect[DEADSHOT_MACHINE_LIGHT_FX] = "_t6/misc/fx_zombie_cola_dtap_on";
	
	level.machine_assets[PERK_DEAD_SHOT] = SpawnStruct();
	level.machine_assets[PERK_DEAD_SHOT].weapon = GetWeapon( DEADSHOT_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_DEAD_SHOT].off_model = DEADSHOT_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_DEAD_SHOT].on_model = DEADSHOT_MACHINE_ACTIVE_MODEL;
}

function deadshot_register_clientfield()
{
	clientfield::register("toplayer", "deadshot_perk", VERSION_SHIP, 1, "int");
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_DEAD_SHOT, VERSION_SHIP, 2, "int" );
}

function deadshot_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_DEAD_SHOT, state );
}

function deadshot_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_deadshot_jingle";
	use_trigger.script_string = "deadshot_perk";
	use_trigger.script_label = "mus_perks_deadshot_sting";
	use_trigger.target = DEADSHOT_RADIANT_MACHINE_NAME;
	perk_machine.script_string = "deadshot_vending";
	perk_machine.targetname = DEADSHOT_RADIANT_MACHINE_NAME;
	if(IsDefined(bump_trigger))
	{
		bump_trigger.script_string = "deadshot_vending";
	}
}

function give_deadshot_perk()
{
	self clientfield::set_to_player( "deadshot_perk", 1);
}

function take_deadshot_perk( b_pause, str_perk, str_result )
{
	self clientfield::set_to_player( "deadshot_perk", 0);
}
