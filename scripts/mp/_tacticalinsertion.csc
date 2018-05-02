#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_tacticalinsertion;

#using scripts\mp\_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace tacticalinsertion;

REGISTER_SYSTEM( "tacticalinsertion", &__init__, undefined )

function __init__()
{
	tacticalinsertion::init_shared();
}