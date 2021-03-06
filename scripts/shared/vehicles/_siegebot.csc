#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\callbacks_shared;

#using scripts\shared\weapons\spike_charge_siegebot;

#namespace siegebot;

function autoexec main()
{
	vehicle::add_vehicletype_callback( "siegebot", &_setup_ );
}

function _setup_( localClientNum )
{
	if( isdefined( self.scriptbundlesettings ) )
	{
		settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}

	if ( !isdefined( settings ) )
	{
		return;
	}
}
