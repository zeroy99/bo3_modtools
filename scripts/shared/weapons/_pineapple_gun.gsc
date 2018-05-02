#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#precache( "fx", "weapon/fx_hero_pineapple_trail_blue" );
#precache( "fx", "weapon/fx_hero_pineapple_trail_orng" );

#namespace pineapple_gun;

REGISTER_SYSTEM( "pineapple_gun", &__init__, undefined )

function __init__()
{
}

function watch_bolt_detonation( owner ) // self == explosive_bolt entity
{
	//self SetTeam( owner.team );
}