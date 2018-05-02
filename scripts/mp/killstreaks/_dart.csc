#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#using scripts\shared\visionset_mgr_shared;

#define DART_VISIONSET_FILE				"mp_vehicles_dart"
#define SENTINEL_VISIONSET_FILE			"mp_vehicles_sentinel"
#define REMOTE_MISSILE_VISIONSET_FILE	"mp_hellstorm"

#namespace dart;

REGISTER_SYSTEM( "dart", &__init__, undefined )	

function __init__()
{	
	clientfield::register( "toplayer", "dart_update_ammo", VERSION_SHIP, 2, "int", &update_ammo, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "fog_bank_3", VERSION_SHIP, 1, "int", &fog_bank_3_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	
	level.dartBundle = struct::get_script_bundle( "killstreak", "killstreak_dart" );
	vehicle::add_vehicletype_callback( level.dartBundle.ksDartVehicle,&spawned );
	visionset_mgr::register_visionset_info( DART_VISIONSET_ALIAS, VERSION_SHIP, 1, undefined, DART_VISIONSET_FILE );
	visionset_mgr::register_visionset_info( SENTINEL_VISIONSET_ALIAS, VERSION_SHIP, 1, undefined, SENTINEL_VISIONSET_FILE );
	visionset_mgr::register_visionset_info( REMOTE_MISSILE_VISIONSET_ALIAS, VERSION_SHIP, 1, undefined, REMOTE_MISSILE_VISIONSET_FILE );
}

function update_ammo( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	SetUIModelValue( GetUIModel( GetUIModelForController( localClientNum ), "vehicle.ammo" ), newVal );
}

function spawned(localClientNum)
{
	self.killstreakBundle = level.dartBundle;
}

function fog_bank_3_callback(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( oldVal != newVal )
	{
		if ( newVal == 1 )
		{
			SetWorldFogActiveBank(localClientNum, FOG_BANK_3);
		}
		else
		{
			SetWorldFogActiveBank(localClientNum, FOG_BANK_1);
		}
	}
}