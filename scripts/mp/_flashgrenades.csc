#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\weapons\_flashgrenades;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;

#namespace flashgrenades;

REGISTER_SYSTEM( "flashgrenades", &__init__, undefined )
	
function __init__( localClientNum )
{
	flashgrenades::init_shared();
}
