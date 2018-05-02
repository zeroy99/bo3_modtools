#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_decoy;

#insert scripts\shared\shared.gsh;

#namespace decoy;

REGISTER_SYSTEM( "decoy", &__init__, undefined )

function __init__()
{
	decoy::init_shared();
}
