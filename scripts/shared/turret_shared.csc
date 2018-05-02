#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace turret;

REGISTER_SYSTEM( "turret", &__init__, undefined )

function __init__()
{
	clientfield::register( "vehicle", "toggle_lensflare", 					VERSION_SHIP, 1, "int", &field_toggle_lensflare, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function field_toggle_lensflare( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
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

	if( isdefined( self.turret_lensflare_id ) )
	{
		DeleteFX( localClientNum, self.turret_lensflare_id );
		self.turret_lensflare_id = undefined;
	}

	if( newVal )
	{
		if ( isdefined( settings.lensflare_fx ) && isdefined( settings.lensflare_tag ) )
		{
			self.turret_lensflare_id = PlayFxOnTag( localClientNum, settings.lensflare_fx, self, settings.lensflare_tag );
		}
		else
		{
		}
	}
}
