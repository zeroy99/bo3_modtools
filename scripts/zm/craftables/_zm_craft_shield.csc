#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_weap_riotshield;
#using scripts\zm\craftables\_zm_craftables;
#using scripts\zm\_zm_powerup_shield_charge;
#using scripts\zm\_zm_utility;

#insert scripts\zm\craftables\_zm_craftables.gsh;
#insert scripts\zm\_zm_utility.gsh;

#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOLLY			"piece_riotshield_dolly"
#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOOR				"piece_riotshield_door"
#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_CLAMP			"piece_riotshield_clamp"
#define CRAFTABLE_SHIELD										"craft_shield_zm"
#define ZMUI_SHIELD_PART_PICKUP 								"ZMUI_SHIELD_PART_PICKUP"
#define ZMUI_SHIELD_CRAFTED										"ZMUI_SHIELD_CRAFTED"
	
#namespace zm_craft_shield;

REGISTER_SYSTEM( "zm_craft_shield", &__init__, undefined )

// RIOT SHIELD	
function __init__()
{
	zm_craftables::include_zombie_craftable( CRAFTABLE_SHIELD );
	zm_craftables::add_zombie_craftable( CRAFTABLE_SHIELD );
	
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOLLY,	VERSION_SHIP, 1, "int", &zm_utility::setSharedInventoryUIModels, false );
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOOR, VERSION_SHIP, 1, "int", &zm_utility::setSharedInventoryUIModels, false );
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_CLAMP,	VERSION_SHIP, 1, "int", &zm_utility::setSharedInventoryUIModels, false );
	
	clientfield::register( "toplayer", ZMUI_SHIELD_PART_PICKUP, VERSION_SHIP, 1, "int", &zm_utility::zm_ui_infotext, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", ZMUI_SHIELD_CRAFTED, VERSION_SHIP, 1, "int", &zm_utility::zm_ui_infotext, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

