#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_riotshield;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;

#namespace riotshield;

REGISTER_SYSTEM( "riotshield", &__init__, undefined )

function __init__()
{
	riotshield::init_shared();
}