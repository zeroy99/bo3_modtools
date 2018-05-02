#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weap_riotshield;
#using scripts\zm\craftables\_zm_craftables;
#using scripts\zm\_zm_powerup_shield_charge;

#using scripts\shared\ai\zombie_utility;

#insert scripts\zm\craftables\_zm_craftables.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_CRAFT_RIOT" );
#precache( "string", "ZOMBIE_GRAB_RIOTSHIELD" );
#precache( "triggerstring", "ZOMBIE_CRAFT_RIOT" );
#precache( "triggerstring", "ZOMBIE_GRAB_RIOTSHIELD" );
#precache( "triggerstring", "ZOMBIE_BOUGHT_RIOT" );
#precache( "string", "ZOMBIE_EQUIP_RIOTSHIELD_HOWTO" );


#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOLLY			"piece_riotshield_dolly"
#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOOR				"piece_riotshield_door"
#define CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_CLAMP			"piece_riotshield_clamp"
#define ZMUI_SHIELD_PART_PICKUP 								"ZMUI_SHIELD_PART_PICKUP"
#define ZMUI_SHIELD_CRAFTED										"ZMUI_SHIELD_CRAFTED"

#define ZM_CRAFTABLES_NOT_ENOUGH_PIECES_UI_DURATION		3.5
#define ZM_CRAFTABLES_FULLY_CRAFTED_UI_DURATION			3.5
	
#define GROUND_LEVEL 		0
#define RIOTSHIELD_OFFSET 	26

#namespace zm_craft_shield;

REGISTER_SYSTEM_EX( "zm_craft_shield", &__init__, &__main__, undefined )

// RIOT SHIELD

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
}

function init( shield_equipment, shield_weapon, shield_model, str_to_craft = &"ZOMBIE_CRAFT_RIOT", str_taken = &"ZOMBIE_BOUGHT_RIOT", str_grab = &"ZOMBIE_GRAB_RIOTSHIELD" )
{
	level.craftable_shield_equipment = shield_equipment; 
	level.craftable_shield_weapon = shield_weapon; 
	level.craftable_shield_model = shield_model;
	
	level.craftable_shield_grab = str_grab;
	
	level.riotshield_supports_deploy = false; 
		
	riotShield_dolly = zm_craftables::generate_zombie_craftable_piece( level.craftable_shield_equipment, "dolly", 32, 64, GROUND_LEVEL, undefined, &on_pickup_common, &on_drop_common, undefined, undefined, undefined, undefined, CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOLLY, CRAFTABLE_IS_SHARED, "build_zs" );
	riotShield_door  = zm_craftables::generate_zombie_craftable_piece( level.craftable_shield_equipment, "door", 48, 15, 25, undefined, &on_pickup_common, &on_drop_common, undefined, undefined, undefined, undefined, CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOOR, CRAFTABLE_IS_SHARED, "build_zs" );
	riotShield_clamp  = zm_craftables::generate_zombie_craftable_piece( level.craftable_shield_equipment, "clamp", 48, 15, 25, undefined, &on_pickup_common, &on_drop_common, undefined, undefined, undefined, undefined, CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_CLAMP, CRAFTABLE_IS_SHARED, "build_zs" );
	
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOLLY,	VERSION_SHIP, 1, "int", undefined, false );
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_DOOR,	VERSION_SHIP, 1, "int", undefined, false );
	RegisterClientField( "world", CLIENTFIELD_CRAFTABLE_PIECE_RIOTSHIELD_CLAMP, VERSION_SHIP, 1, "int", undefined, false );
	
	clientfield::register( "toplayer", ZMUI_SHIELD_PART_PICKUP, VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", ZMUI_SHIELD_CRAFTED, VERSION_SHIP, 1, "int" );
	
	riotShield = SpawnStruct();
	riotShield.name = level.craftable_shield_equipment;
	riotShield.weaponname = level.craftable_shield_weapon;
	riotShield zm_craftables::add_craftable_piece( riotShield_dolly );
	riotShield zm_craftables::add_craftable_piece( riotShield_door );
	riotShield zm_craftables::add_craftable_piece( riotShield_clamp );
	riotShield.onBuyWeapon = &on_buy_weapon_riotshield;
	riotShield.triggerThink = &riotshield_craftable;
	
	zm_craftables::include_zombie_craftable( riotShield );
	
	zm_craftables::add_zombie_craftable( level.craftable_shield_equipment, str_to_craft, "ERROR", str_taken, &on_fully_crafted, CRAFTABLE_NEED_ALL_PIECES );
	zm_craftables::add_zombie_craftable_vox_category( level.craftable_shield_equipment, "build_zs" );
	zm_craftables::make_zombie_craftable_open( level.craftable_shield_equipment, level.craftable_shield_model, (0, -90, 0), (0, 0, RIOTSHIELD_OFFSET) );
}

function __main__()
{
}

function riotshield_craftable()
{
	zm_craftables::craftable_trigger_think( "riotshield_zm_craftable_trigger", level.craftable_shield_equipment, level.craftable_shield_weapon, level.craftable_shield_grab, DELETE_TRIGGER, PERSISTENT );
}

// thread this to show a UI infotext string for a defined duration
// self = player to show the infotext string
// str_infotext = the infotext string
// n_duration = how long to set the infotext
function show_infotext_for_duration( str_infotext, n_duration )
{
	self clientfield::set_to_player( str_infotext, 1 );
	wait n_duration;
	self clientfield::set_to_player( str_infotext, 0 );
}

// self is a WorldPiece
function on_pickup_common( player )
{
	// CallBack When Player Picks Up Craftable Piece
	//----------------------------------------------

	player playsound( "zmb_craftable_pickup" );	
	
	if( isdefined( level.craft_shield_piece_pickup_vo_override ) )
	{
		player thread [[level.craft_shield_piece_pickup_vo_override]]();
	}
	
	foreach( e_player in level.players )
	{
		e_player thread zm_craftables::player_show_craftable_parts_ui( "zmInventory.player_crafted_shield", "zmInventory.widget_shield_parts", false ); // show ui for parts
		e_player thread show_infotext_for_duration( ZMUI_SHIELD_PART_PICKUP, ZM_CRAFTABLES_NOT_ENOUGH_PIECES_UI_DURATION );
	}

	self pickup_from_mover();
	self.piece_owner = player;
}

// self is a WorldPiece
function on_drop_common( player )
{
	// CallBack When Player Drops Craftable Piece
	//-------------------------------------------

	self drop_on_mover( player );
	self.piece_owner = undefined;
}

function pickup_from_mover()
{	
	//Setup for override
	if( isdefined( level.craft_shield_pickup_override ) )
	{
		[[level.craft_shield_pickup_override]]();
	}
}

function on_fully_crafted()
{
	players = level.players;
	foreach( e_player in players )
	{
		if( zm_utility::is_player_valid( e_player ) )
		{
			e_player thread zm_craftables::player_show_craftable_parts_ui( "zmInventory.player_crafted_shield", "zmInventory.widget_shield_parts", true );
			e_player thread show_infotext_for_duration( ZMUI_SHIELD_CRAFTED, ZM_CRAFTABLES_FULLY_CRAFTED_UI_DURATION );
		}
	}
	
	return true;
}

function drop_on_mover( player )
{
	//Setup for override
	if( isdefined( level.craft_shield_drop_override ) )
	{
		[[level.craft_shield_drop_override]]();
	}	
}

function on_buy_weapon_riotshield( player )
{
	if ( isdefined(player.player_shield_reset_health))
	{
		player [[player.player_shield_reset_health]]();
	}
	if ( isdefined(player.player_shield_reset_location))
	{
		player [[player.player_shield_reset_location]]();
	}
	
	// Notifies pods to start dropping shield recharge
	player playsound( "zmb_craftable_buy_shield" );
	level notify( "shield_built", player );
}

