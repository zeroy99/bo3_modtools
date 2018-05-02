#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#precache( "client_fx", "_t6/weapon/claymore/fx_claymore_laser" );

#namespace claymore;

REGISTER_SYSTEM( "claymore", &__init__, undefined )

function __init__( localClientNum )
{
	level._effect["fx_claymore_laser"] = "_t6/weapon/claymore/fx_claymore_laser";
	
	callback::add_weapon_type( "claymore", &spawned );
}

function spawned( localClientNum )
{
	self endon( "entityshutdown" );

	self util::waittill_dobj(localClientNum);

	while( true )
	{
		if( isdefined( self.stunned ) && self.stunned )
		{
			wait( 0.1 );
			continue;
		}


		self.claymoreLaserFXId = PlayFXOnTag( localClientNum, level._effect["fx_claymore_laser"], self, "tag_fx" );

		self waittill( "stunned" );
		stopfx(localClientNum, self.claymoreLaserFXId);

	}
}
