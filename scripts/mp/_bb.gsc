#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\bb_shared;

#insert scripts\shared\shared.gsh;

#namespace bb;

REGISTER_SYSTEM( "bb", &__init__, undefined )

function __init__()
{
	bb::init_shared();
}
