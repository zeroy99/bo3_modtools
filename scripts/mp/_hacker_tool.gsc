#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_hacker_tool;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace hacker_tool;

REGISTER_SYSTEM( "hacker_tool", &__init__, undefined )

function __init__()
{
	hacker_tool::init_shared();
}
