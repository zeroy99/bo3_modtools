#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_shield", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_ENERGY_SHIELD, &shield_gadget_on, &shield_gadget_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_ENERGY_SHIELD, &shield_on_give, &shield_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_ENERGY_SHIELD, &shield_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_ENERGY_SHIELD, &shield_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_ENERGY_SHIELD, &shield_is_flickering );
	
	callback::on_connect( &shield_on_connect );

	clientfield::register( "toplayer", "shield_on", VERSION_SHIP, 1, "int" );
}

function shield_is_inuse( slot )
{
	return self flagsys::get( "gadget_shield_on" );
}

function shield_is_flickering( slot )
{
	return self GadgetFlickering( slot );
}

function shield_on_flicker( slot )
{
	self shield_flicker( slot );	
}

function shield_on_give( slot )
{
	self clientfield::set_to_player( "shield_on", 0 );
}

function shield_on_take( slot )
{
	self clientfield::set_to_player( "shield_on", 0 );
}

//self is the player
function shield_on_connect()
{
}

function shield_gadget_on( slot )
{
	self flagsys::set( "gadget_shield_on" );

	self clientfield::set_to_player( "shield_on", 1 );
	
	//self thread reflectBulletsHandler( slot );	
}

function shield_gadget_off( slot )
{
	self flagsys::clear( "gadget_shield_on" );
	
	self clientfield::set_to_player( "shield_on", 0 );

	self notify( "shield_off" );
}

function reflectBulletsHandler( slot )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "shield_off" );

	if ( !self shield_is_inuse( slot ) )
	{
		return;
	}

	while ( 1 )
	{
		self waittill( "riotshield" );

		if ( !self shield_is_inuse( slot ) )
		{
			return;
		}

		if ( self._gadgets_player[slot].gadget_shieldReflectPowerGain )
		{
			self ability_power::power_gain_event( undefined, self._gadgets_player[slot].gadget_shieldReflectPowerGain, "reflected" );
		}

		if ( self._gadgets_player[slot].gadget_shieldReflectPowerLoss )
		{
			self ability_power::power_loss_event( undefined, self._gadgets_player[slot].gadget_shieldReflectPowerLoss, "reflected" );
		}

	}
}

function shield_flicker( slot )
{
	self endon( "disconnect" );

	if ( !self shield_is_inuse( slot ) )
	{
		return;
	}
	
	eventTime = self._gadgets_player[slot].gadget_flickertime;

	self set_shield_flicker_status( "^1" + "Flickering.", eventTime );
	
	while( 1 )
	{		
		if ( !self GadgetFlickering( slot ) )
		{
			set_shield_flicker_status( "^2" + "Normal" );
			return;
		}

		wait( 0.25 );
	}
}

function set_shield_flicker_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Shield Flicker: " + status + timeStr );
}

