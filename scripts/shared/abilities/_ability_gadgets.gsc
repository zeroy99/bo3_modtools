#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace ability_gadgets;

REGISTER_SYSTEM( "ability_gadgets", &__init__, undefined )

function __init__()
{
	callback::on_connect( &on_player_connect );
	callback::on_spawned( &on_player_spawned );
}


function gadgets_print( str )
{
}


//---------------------------------------------------------
// power and gadget activation

function on_player_connect()
{
}

function SetFlickering( slot, length )
{
	if ( !IsDefined( length ) )
	{
		length = 0;
	}

	self GadgetFlickering( slot, true, length );
}

function on_player_spawned()
{
}


function gadget_give_callback( ent, slot, weapon )
{
	ent ability_player::give_gadget( slot, weapon );
}

function gadget_take_callback( ent, slot, weapon )
{
	ent ability_player::take_gadget( slot, weapon );
}

function gadget_primed_callback( ent, slot, weapon )
{
	ent ability_player::gadget_primed( slot, weapon );
}

function gadget_ready_callback( ent, slot, weapon )
{
	ent ability_player::gadget_ready( slot, weapon );
}

function gadget_on_callback( ent, slot, weapon )
{
	BONUSZM_CYBERCOM_ON_CALLBACK(ent);
	
	ent ability_player::turn_gadget_on( slot, weapon );
}

function gadget_off_callback( ent, slot, weapon )
{
	ent ability_player::turn_gadget_off( slot, weapon );
}

function gadget_flicker_callback( ent, slot, weapon )
{
	ent ability_player::gadget_flicker( slot, weapon );
}