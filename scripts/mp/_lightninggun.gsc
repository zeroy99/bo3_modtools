#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_lightninggun;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace lightninggun;

REGISTER_SYSTEM( "lightninggun", &__init__, undefined )	

function __init__()
{
	lightninggun::init_shared();
}
