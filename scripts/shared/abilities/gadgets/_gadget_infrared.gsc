#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\abilities\_ability_gadgets;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_infrared", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_INFRARED, &infrared_gadget_on, &infrared_gadget_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_INFRARED, &infrared_on_give, &infrared_on_take );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_INFRARED, &infrared_is_inuse );
	
	clientfield::register( "toplayer", "infrared_on", VERSION_SHIP, 1, "int" );	

	callback::on_connect( &infrared_on_connect );
	callback::on_spawned( &infrared_on_spawn );
	callback::on_disconnect( &infrared_on_disconnect );
}

function infrared_is_inuse( slot )
{
	return self flagsys::get( "infrared_on" );
}

function infrared_on_connect()
{
}

function infrared_on_disconnect()
{
}

function infrared_on_spawn()
{
	self flagsys::clear( "infrared_on" );
	self notify( "infrared_off" );
	self clientfield::set_to_player( "infrared_on", 0 );
}


function infrared_on_give( slot, weapon )
{
	self clientfield::set_to_player( "infrared_on", 0 );
}

function infrared_on_take( slot, weapon )
{
	self notify( "infrared_removed" );

	self clientfield::set_to_player( "infrared_on", 0 );
}

function infrared_gadget_on( slot, weapon )
{	
	self clientfield::set_to_player( "infrared_on", 1 );

	self flagsys::set( "infrared_suit_on" );
	
	//self playsound ("gdt_infrared_on");
}


function infrared_gadget_off( slot, weapon )
{
	self flagsys::clear( "infrared_suit_on" );
	
	self notify( "infrared_off" );
	
	self clientfield::set_to_player( "infrared_on", 0 );
	
	//self playsound ("gdt_infrared_off");
}

