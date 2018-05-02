#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_acousticsensor;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace acousticsensor;

REGISTER_SYSTEM( "acousticsensor", &__init__, undefined )

function __init__()
{
	acousticsensor::init_shared();
}