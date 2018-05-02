#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_proximity_grenade;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace proximity_grenade;

REGISTER_SYSTEM( "proximity_grenade", &__init__, undefined )	

function __init__()
{
	proximity_grenade::init_shared();
	
	level.trackProximityGrenadesOnOwner = true;
}
