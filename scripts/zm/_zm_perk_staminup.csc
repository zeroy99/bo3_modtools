#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perk_staminup.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;
	
#precache( "client_fx", STAMINUP_MACHINE_FX_FILE_MACHINE_LIGHT );

#namespace zm_perk_staminup;

REGISTER_SYSTEM( "zm_perk_staminup", &__init__, undefined )

// STAMINUP ( STAMIN-UP )
	
function __init__()
{
	enable_staminup_perk_for_level();
}

function enable_staminup_perk_for_level()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_STAMINUP, &staminup_client_field_func, &staminup_callback_func );
	zm_perks::register_perk_effects( PERK_STAMINUP, STAMINUP_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_STAMINUP, &init_staminup );
}

function init_staminup()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect["marathon_light"]	= STAMINUP_MACHINE_FX_FILE_MACHINE_LIGHT;
	}	
}

function staminup_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_STAMINUP, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

function staminup_callback_func()
{
}
