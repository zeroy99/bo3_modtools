#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\weapons\_ballistic_knife;

#insert scripts\shared\shared.gsh;

#namespace ballistic_knife;

REGISTER_SYSTEM( "ballistic_knife", &__init__, undefined )

function __init__()
{
	ballistic_knife::init_shared();	
}
