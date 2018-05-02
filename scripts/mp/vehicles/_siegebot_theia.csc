#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace siegebot_theia;

REGISTER_SYSTEM( "siegebot_theia", &__init__, undefined )

function __init__()
{
	vehicle::add_vehicletype_callback( "siegebot_theia", &_setup_ );

	clientfield::register( "vehicle", "sarah_rumble_on_landing", VERSION_SHIP, 1, "counter", &sarah_rumble_on_landing, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT ); 
	clientfield::register( "vehicle", "sarah_minigun_spin", VERSION_SHIP, 1, "int", &sarah_minigun_spin, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

function _setup_( localClientNum )
{
}

//Rumble and quake when sarah jumps and lands
function sarah_rumble_on_landing( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self PlayRumbleOnEntity(localClientNum, "cp_infection_sarah_battle_land" );
}

function sarah_minigun_spin( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	if ( !isdefined( settings ) )
	{
		return;
	}

	if ( isdefined( self.minigun_spin_fx_handle ) )
	{
		DeleteFX( localClientNum, self.minigun_spin_fx_handle );
	}

	if ( newVal )
	{
		self.minigun_spin_fx_handle = PlayFXOnTag( localClientNum, settings.spin, self, settings.tag_spin );
	}
}