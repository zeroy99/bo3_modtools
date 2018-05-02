#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perk_quick_revive.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", "zombie/fx_perk_quick_revive_zmb" );

#namespace zm_perk_quick_revive;

REGISTER_SYSTEM( "zm_perk_quick_revive", &__init__, undefined )

// QUICK REVIVE ( QUICK REVIVE )
	
function __init__()
{
	enable_quick_revive_perk_for_level();
}

function enable_quick_revive_perk_for_level()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_QUICK_REVIVE, &quick_revive_client_field_func, &quick_revive_callback_func );
	zm_perks::register_perk_effects( PERK_QUICK_REVIVE, QUICK_REVIVE_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_QUICK_REVIVE, &init_quick_revive );
}

function init_quick_revive()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[QUICK_REVIVE_MACHINE_LIGHT_FX]	= "zombie/fx_perk_quick_revive_zmb";
	}	
}

function quick_revive_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_QUICK_REVIVE, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function quick_revive_callback_func()
{
}
