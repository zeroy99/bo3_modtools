#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\entityheadicons_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace entityheadicons;

REGISTER_SYSTEM( "entityheadicons", &__init__, undefined )
	
function __init__()
{
	entityheadicons::init_shared();
}


