#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\archetype_shared\archetype_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace wasp;

REGISTER_SYSTEM( "wasp", &__init__, undefined )

function __init__()
{
	// clientfield setup
	clientfield::register( "vehicle", "rocket_wasp_hijacked", VERSION_SHIP, 1, "int", &handle_lod_display_for_driver, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level.sentinelBundle = struct::get_script_bundle( "killstreak", "killstreak_sentinel" );
	if( isdefined( level.sentinelBundle ) )
		vehicle::add_vehicletype_callback( level.sentinelBundle.ksVehicle, &spawned );
}

function spawned( localClientNum )
{
	self.killstreakBundle = level.sentinelBundle;
}

function handle_lod_display_for_driver(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{	
	self endon( "entityshutdown" );
	if( isDefined( self ) )
	{			
		if( self IsLocalClientDriver( localClientNum ))
		{
			self SetHighDetail( true );
			wait 0.05;
			self vehicle::lights_off( localClientNum );
		}
	}
}