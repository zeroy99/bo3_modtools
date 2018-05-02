#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perk_sleight_of_hand.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", "zombie/fx_perk_sleight_of_hand_zmb" );

#namespace zm_perk_sleight_of_hand;

REGISTER_SYSTEM( "zm_perk_sleight_of_hand", &__init__, undefined )

// SLEIGHT OF HAND PERK ( SPEED COLA )
	
function __init__()
{
	enable_sleight_of_hand_perk_for_level();
}

function enable_sleight_of_hand_perk_for_level()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_SLEIGHT_OF_HAND, &sleight_of_hand_client_field_func, &sleight_of_hand_code_callback_func );
	zm_perks::register_perk_effects( PERK_SLEIGHT_OF_HAND, SLEIGHT_OF_HAND_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_SLEIGHT_OF_HAND, &init_sleight_of_hand );
}

function init_sleight_of_hand()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[SLEIGHT_OF_HAND_MACHINE_LIGHT_FX]	= "zombie/fx_perk_sleight_of_hand_zmb";
	}	
}

function sleight_of_hand_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_SLEIGHT_OF_HAND, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function sleight_of_hand_code_callback_func()
{
}
