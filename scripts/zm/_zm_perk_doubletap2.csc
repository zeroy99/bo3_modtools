#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perk_doubletap2.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", "zombie/fx_perk_doubletap2_zmb" );

#namespace zm_perk_doubletap2;

REGISTER_SYSTEM( "zm_perk_doubletap2", &__init__, undefined )

// DOUBLETAP2 ( DOUBLE TAP II )
	
function __init__()
{
	enable_doubletap2_perk_for_level();
}

function enable_doubletap2_perk_for_level()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_DOUBLETAP2, &doubletap2_client_field_func, &doubletap2_code_callback_func );
	zm_perks::register_perk_effects( PERK_DOUBLETAP2, DOUBLETAP2_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_DOUBLETAP2, &init_doubletap2 );
}

function init_doubletap2()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[DOUBLETAP2_MACHINE_LIGHT_FX]						= "zombie/fx_perk_doubletap2_zmb";
	}	
}

function doubletap2_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_DOUBLETAP2, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

function doubletap2_code_callback_func()
{
}
