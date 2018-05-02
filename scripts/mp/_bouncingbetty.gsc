#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_bouncingbetty;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace bouncingbetty;

REGISTER_SYSTEM( "bouncingbetty", &__init__, undefined )

function __init__()
{
	bouncingbetty::init_shared();
	
	level.trackBouncingBettiesOnOwner = true;
}


