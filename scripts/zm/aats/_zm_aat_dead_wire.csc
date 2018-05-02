#using scripts\shared\aat_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\aats\_zm_aat_dead_wire.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", ZM_AAT_DEAD_WIRE_ZOMBIE_ZAP_FX );

#namespace zm_aat_dead_wire;

REGISTER_SYSTEM( ZM_AAT_DEAD_WIRE_NAME, &__init__, undefined )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	aat::register( ZM_AAT_DEAD_WIRE_NAME, ZM_AAT_DEAD_WIRE_LOCALIZED_STRING, ZM_AAT_DEAD_WIRE_ICON );
	
	clientfield::register( "actor", ZM_AAT_DEAD_WIRE_CF_NAME_ZAP, VERSION_SHIP, 1, "int", &zm_aat_dead_wire_zap, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", ZM_AAT_DEAD_WIRE_CF_NAME_ZAP_VEH, VERSION_SHIP, 1, "int", &zm_aat_dead_wire_zap_vehicle, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level._effect[ ZM_AAT_DEAD_WIRE_NAME ] = ZM_AAT_DEAD_WIRE_ZOMBIE_ZAP_FX;
}

// self == targeted zombie
function zm_aat_dead_wire_zap( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self.fx_aat_dead_wire_zap = PlayFXOnTag( localClientNum, ZM_AAT_DEAD_WIRE_ZOMBIE_ZAP_FX, self, "J_SpineUpper" );
	}
	else if ( isdefined( self.fx_aat_dead_wire_zap ) )
	{
		StopFX( localClientNum, self.fx_aat_dead_wire_zap );
		self.fx_aat_dead_wire_zap = undefined;
	}
}

// self == targeted vehicle
function zm_aat_dead_wire_zap_vehicle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		tag = "tag_body";
	
		// Checks if tag exists
		v_tag = self gettagorigin( tag );
		if ( !isdefined( v_tag ) )
		{
			tag = "tag_origin";
		}
		
		self.fx_aat_dead_wire_zap = PlayFXOnTag( localClientNum, ZM_AAT_DEAD_WIRE_ZOMBIE_ZAP_FX, self, tag );
	}
	else if ( isdefined( self.fx_aat_dead_wire_zap ) )
	{
		StopFX( localClientNum, self.fx_aat_dead_wire_zap );
		self.fx_aat_dead_wire_zap = undefined;
	}
}

