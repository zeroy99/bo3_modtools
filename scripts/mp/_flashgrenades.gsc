#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_flashgrenades;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace flashgrenades;

REGISTER_SYSTEM( "flashgrenades", &__init__, undefined )
	
function __init__()
{
	flashgrenades::init_shared();	
}

