#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_satchel_charge;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace satchel_charge;

REGISTER_SYSTEM( "satchel_charge", &__init__, undefined )

function __init__( localClientNum )
{
	satchel_charge::init_shared();
}
