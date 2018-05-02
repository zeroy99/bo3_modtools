#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#namespace heatseekingmissile;

REGISTER_SYSTEM( "heatseekingmissile", &__init__, undefined )

function __init__()
{
	level.lockOnCloseRange = 220;
	level.lockOnCloseRadiusScaler = 1;	
	
	heatseekingmissile::init_shared();
}
