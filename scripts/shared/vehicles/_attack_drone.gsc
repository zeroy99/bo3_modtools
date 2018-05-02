#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;

#insert scripts\shared\ai\utility.gsh;

#define ATTACK_DRONE_ACTIVETIME					70
#define ATTACK_DRONE_ACTIVETIME_VARIETY			4
#define ATTACK_DRONE_ATTACK_DISTANCE_ATTACHED	1000

#namespace attack_drone;

REGISTER_SYSTEM( "attack_drone", &__init__, undefined )

function __init__()
{	
}
