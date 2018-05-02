#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#precache( "fx", "light/fx_light_red_spike_charge_os" );

#namespace spike_charge_siegebot;

REGISTER_SYSTEM( "spike_charge_siegebot", &__init__, undefined )

function __init__()
{
}

function watch_bolt_detonation( owner ) // self == explosive_bolt entity
{
	//self SetTeam( owner.team );
}