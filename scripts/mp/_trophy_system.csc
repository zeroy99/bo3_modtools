#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_trophy_system;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;

#namespace trophy_system;

REGISTER_SYSTEM( "trophy_system", &__init__, undefined )

function __init__( localClientNum )
{
	trophy_system::init_shared();
}