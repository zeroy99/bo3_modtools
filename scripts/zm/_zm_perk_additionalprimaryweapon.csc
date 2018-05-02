#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perk_additionalprimaryweapon.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", ADDITIONAL_PRIMARY_WEAPON_MACHINE_FX_FILE_MACHINE_LIGHT );

#namespace zm_perk_additionalprimaryweapon;

REGISTER_SYSTEM( "zm_perk_additionalprimaryweapon", &__init__, undefined )

// ADDITIONAL PRIMARY WEAPON ( MULE KICK )
	
function __init__()
{
	enable_additional_primary_weapon_perk_for_level();
}

function enable_additional_primary_weapon_perk_for_level()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_ADDITIONAL_PRIMARY_WEAPON, &additional_primary_weapon_client_field_func, &additional_primary_weapon_code_callback_func );
	zm_perks::register_perk_effects( PERK_ADDITIONAL_PRIMARY_WEAPON, ADDITIONAL_PRIMARY_WEAPON_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_ADDITIONAL_PRIMARY_WEAPON, &init_additional_primary_weapon );
}

function init_additional_primary_weapon()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[ADDITIONAL_PRIMARY_WEAPON_MACHINE_LIGHT_FX] = ADDITIONAL_PRIMARY_WEAPON_MACHINE_FX_FILE_MACHINE_LIGHT;
	}	
}

function additional_primary_weapon_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_ADDITIONAL_PRIMARY_WEAPON, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function additional_primary_weapon_code_callback_func()
{
}
