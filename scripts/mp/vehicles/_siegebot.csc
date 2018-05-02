#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\weapons\spike_charge_siegebot;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace siegebot;

REGISTER_SYSTEM( "siegebot_mp", &__init__, undefined )

function __init__()
{
	vehicle::add_vehicletype_callback( "siegebot_mp", &_setup_ );
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

	self thread player_enter( localClientNum );
	self thread player_exit( localClientNum );
}

function player_enter( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	while( 1 )
	{
		self waittill( "enter_vehicle", player );
		
		if( self IsLocalClientDriver( localClientNum ) )
		{
			self SetHighDetail( true );
		}
		
		wait CLIENT_FRAME;
	}
}

function player_exit( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	while( 1 )
	{
		self waittill( "exit_vehicle", player );
		if( player islocalplayer() )
		{
			self SetHighDetail( false );
		}
		wait CLIENT_FRAME;
	}
}
