#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#precache( "fx", "weapon/fx_equip_light_os" );

#namespace sticky_grenade;

REGISTER_SYSTEM( "sticky_grenade", &__init__, undefined )

function __init__()
{
}

function watch_bolt_detonation( owner ) // self == explosive_bolt entity
{
	//self SetTeam( owner.team );
}