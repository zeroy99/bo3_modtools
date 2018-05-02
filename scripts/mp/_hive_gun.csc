#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_hive_gun;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;
	
#namespace hive_gun;

REGISTER_SYSTEM( "hive_gun", &__init__, undefined )	

function __init__()
{
	hive_gun::init_shared();
}


