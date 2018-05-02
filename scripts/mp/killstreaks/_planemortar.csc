#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "killstreaks/fx_ls_exhaust_afterburner" );

#namespace planemortar;

REGISTER_SYSTEM( "planemortar", &__init__, undefined )
	
function __init__()
{	
	level.planeMortarExhaustFX = "killstreaks/fx_ls_exhaust_afterburner";

	clientfield::register( "scriptmover", "planemortar_contrail", VERSION_SHIP, 1, "int",&planemortar_contrail, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function planemortar_contrail( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	if ( newVal )
	{
		self.fx = PlayFXOnTag( localClientNum, level.planeMortarExhaustFX, self, "tag_fx" );	
	}
}
