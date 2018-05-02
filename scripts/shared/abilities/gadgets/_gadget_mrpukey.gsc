#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
	
#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_mrpukey", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_on, &gadget_mrpukey_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_on_give, &gadget_mrpukey_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_is_flickering );
	ability_player::register_gadget_primed_callbacks( GADGET_TYPE_MRPUKEY, &gadget_mrpukey_is_primed );
}

function gadget_mrpukey_is_inuse( slot )
{
	// returns true when the gadget is on
	return self flagsys::get( "gadget_mrpukey_on" );
}

function gadget_mrpukey_is_flickering( slot )
{
	// returns true when the gadget is flickering
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		return self [[level.cybercom.mrpukey._is_flickering]](slot);
	}
}

function gadget_mrpukey_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._on_flicker]](slot, weapon);
	}
}

function gadget_mrpukey_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._on_give]](slot, weapon);
	}
}

function gadget_mrpukey_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._on_take]](slot, weapon);
	}
}

//self is the player
function gadge_mrpukey_on_connect()
{
	// setup up stuff on player connect	
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._on_connect]]();
	}
}

function gadget_mrpukey_on( slot, weapon )
{
	// excecutes when the gadget is turned on
	self flagsys::set( "gadget_mrpukey_on" );
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._on]](slot, weapon);
	}
}

function gadget_mrpukey_off( slot, weapon )
{
	// excecutes when the gadget is turned off`
	self flagsys::clear( "gadget_mrpukey_on" );
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._off]](slot, weapon);
	}
}

function gadget_mrpukey_is_primed( slot, weapon )
{
	// excecutes when the gadget is turned off`
	if(isDefined(level.cybercom) && isDefined(level.cybercom.mrpukey))
	{
		self [[level.cybercom.mrpukey._is_primed]](slot, weapon);
	}
}