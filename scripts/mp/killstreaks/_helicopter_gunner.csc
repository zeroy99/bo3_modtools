#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;

#insert scripts\shared\version.gsh;

#namespace helicopter_gunner;

REGISTER_SYSTEM( "helicopter_gunner", &__init__, undefined )	

function __init__()
{
	clientfield::register( "vehicle", "vtol_turret_destroyed_0", VERSION_SHIP, 1, "int", &turret_destroyed_0, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "vtol_turret_destroyed_1", VERSION_SHIP, 1, "int", &turret_destroyed_1, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "vtol_update_client", VERSION_SHIP, 1, "counter", &update_client, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "fog_bank_2", VERSION_SHIP, 1, "int", &fog_bank_2_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	
	visionset_mgr::register_visionset_info( MOTHERSHIP_VISIONSET_ALIAS, VERSION_SHIP, 1, undefined, MOTHERSHIP_VISIONSET_FILE );
}

function turret_destroyed_0( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
}

function turret_destroyed_1( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
}

function update_turret_destroyed( localClientNum, ui_model_name, new_value )
{
	part_destroyed_ui_model = GetUIModel( GetUIModelForController( localClientNum ), ui_model_name );

	if ( isdefined( part_destroyed_ui_model ) )
		SetUIModelValue( part_destroyed_ui_model, new_value );
}

function update_client( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	veh = GetPlayerVehicle( self );
	if( isdefined( veh ) )
	{
		update_turret_destroyed( localClientNum, "vehicle.partDestroyed.0", veh clientfield::get( "vtol_turret_destroyed_0" ) );
		update_turret_destroyed( localClientNum, "vehicle.partDestroyed.1", veh clientfield::get( "vtol_turret_destroyed_1" ) );
	}
}

function fog_bank_2_callback(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( oldVal != newVal )
	{
		if ( newVal == 1 )
		{
			SetLitFogBank( localClientNum, -1, 1, 0);
		}
		else
		{
			SetLitFogBank( localClientNum, -1, 0, 0);
		}
	}
}