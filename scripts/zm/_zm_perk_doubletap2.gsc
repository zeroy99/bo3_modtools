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

#insert scripts\zm\_zm_perk_doubletap2.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", DOUBLETAP2_SHADER );
#precache( "string", "ZOMBIE_PERK_DOUBLETAP" );
#precache( "fx", "zombie/fx_perk_doubletap2_zmb" );

#namespace zm_perk_doubletap2;

REGISTER_SYSTEM( "zm_perk_doubletap2", &__init__, undefined )

// DOUBLETAP2 ( DOUBLE TAP II )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_doubletap2_perk_for_level();
}

function enable_doubletap2_perk_for_level()
{	
	// register sleight of hand perk for level
	zm_perks::register_perk_basic_info( PERK_DOUBLETAP2, "doubletap", DOUBLETAP2_PERK_COST, &"ZOMBIE_PERK_DOUBLETAP", GetWeapon( DOUBLETAP2_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_DOUBLETAP2, &doubletap2_precache );
	zm_perks::register_perk_clientfields( PERK_DOUBLETAP2, &doubletap2_register_clientfield, &doubletap2_set_clientfield );
	zm_perks::register_perk_machine( PERK_DOUBLETAP2, &doubletap2_perk_machine_setup );
	zm_perks::register_perk_host_migration_params( PERK_DOUBLETAP2, DOUBLETAP2_RADIANT_MACHINE_NAME, DOUBLETAP2_MACHINE_LIGHT_FX );
}

function doubletap2_precache()
{
	if( IsDefined(level.doubletap2_precache_override_func) )
	{
		[[ level.doubletap2_precache_override_func ]]();
		return;
	}
	
	level._effect[DOUBLETAP2_MACHINE_LIGHT_FX] = "zombie/fx_perk_doubletap2_zmb";
	
	level.machine_assets[PERK_DOUBLETAP2] = SpawnStruct();
	level.machine_assets[PERK_DOUBLETAP2].weapon = GetWeapon( DOUBLETAP2_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_DOUBLETAP2].off_model = DOUBLETAP2_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_DOUBLETAP2].on_model = DOUBLETAP2_MACHINE_ACTIVE_MODEL;
}

function doubletap2_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_DOUBLETAP2, VERSION_SHIP, 2, "int" );
}

function doubletap2_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_DOUBLETAP2, state );
}

function doubletap2_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_doubletap_jingle";
	use_trigger.script_string = "tap_perk";
	use_trigger.script_label = "mus_perks_doubletap_sting";
	use_trigger.target = DOUBLETAP2_RADIANT_MACHINE_NAME;
	perk_machine.script_string = "tap_perk";
	perk_machine.targetname = DOUBLETAP2_RADIANT_MACHINE_NAME;
	if( IsDefined( bump_trigger ) )
	{
		bump_trigger.script_string = "tap_perk";
	}
}
