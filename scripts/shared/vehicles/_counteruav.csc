#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\archetype_shared\archetype_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace counteruav;

REGISTER_SYSTEM( "counteruav", &__init__, undefined )

function __init__()
{
}
