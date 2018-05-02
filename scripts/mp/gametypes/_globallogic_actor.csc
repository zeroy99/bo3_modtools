#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace globallogic_actor;

REGISTER_SYSTEM( "globallogic_actor", &__init__, undefined )


function __init__()
{
	level._effect[ "rcbombexplosion" ] = "killstreaks/fx_rcxd_exp";
}


