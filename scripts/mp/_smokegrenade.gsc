#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_smokegrenade;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace smokegrenade;

REGISTER_SYSTEM( "smokegrenade", &__init__, undefined )	

function __init__()
{
	smokegrenade::init_shared();
}

