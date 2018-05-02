#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace teamset;

REGISTER_SYSTEM( "teamset_seals", &__init__, undefined )
	
function __init__()
{
	level.allies_team	= "allies";
	level.axis_team		= "axis";
}