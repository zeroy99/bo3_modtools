#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_scrambler;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;

#namespace scrambler;

REGISTER_SYSTEM( "scrambler", &__init__, undefined )	

function __init__()
{
	scrambler::init_shared();
}