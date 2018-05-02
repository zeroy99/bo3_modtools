#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_sensor_grenade;

#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;

#namespace sensor_grenade;

REGISTER_SYSTEM( "sensor_grenade", &__init__, undefined )		

function __init__()
{
	sensor_grenade::init_shared();
}

