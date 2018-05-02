#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\aats\_zm_aat_turned.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", ZM_AAT_TURNED_ZOMBIE_EYE_FX );
#precache( "client_fx", ZM_AAT_TURNED_ZOMBIE_TORSO_FX );

#namespace zm_aat_turned;

REGISTER_SYSTEM( ZM_AAT_TURNED_NAME, &__init__, undefined )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	aat::register( ZM_AAT_TURNED_NAME, ZM_AAT_TURNED_NAME_LOCALIZED_STRING, ZM_AAT_TURNED_ICON );
	
	clientfield::register( "actor", ZM_AAT_TURNED_NAME, VERSION_SHIP, 1, "int", &zm_aat_turned_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

// self == targeted zombie
function zm_aat_turned_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self SetDrawName( MakeLocalizedString( ZM_AAT_TURNED_NAME_LOCALIZED_STRING ), true );

		self.fx_aat_turned_eyes = PlayFXOnTag( localClientNum, ZM_AAT_TURNED_ZOMBIE_EYE_FX, self, "j_eyeball_le" );
		self.fx_aat_turned_torso = PlayFXOnTag( localClientNum, ZM_AAT_TURNED_ZOMBIE_TORSO_FX, self, "j_spine4" );
		self PlaySound( localClientNum, ZM_AAT_TURNED_SOUND );
	}
	else
	{
		if ( isdefined( self.fx_aat_turned_eyes ) )
		{
			StopFX( localClientNum, self.fx_aat_turned_eyes );
			self.fx_aat_turned_eyes = undefined;
		}
		if ( isdefined( self.fx_aat_turned_torso ) )
		{
			StopFX( localClientNum, self.fx_aat_turned_torso );
			self.fx_aat_turned_torso = undefined;
		}
	}
}
