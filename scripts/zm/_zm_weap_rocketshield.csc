#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_weapons;

#using scripts\zm\_zm_weap_riotshield;
#using scripts\zm\craftables\_zm_craft_shield;

#namespace zm_equip_turret;

REGISTER_SYSTEM( "zm_weap_rocketshield", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "rs_ammo",	VERSION_SHIP, 1, "int", &set_rocketshield_ammo, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}


function set_rocketshield_ammo( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == 1 )
	{
		self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 1, 0, 0 );
	}
	else
	{
		self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 0, 0, 0 );
	}
}



