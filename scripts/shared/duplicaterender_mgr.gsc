#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace duplicate_render;

REGISTER_SYSTEM( "duplicate_render", &__init__, undefined )

#define EQUIPMENT_RETRIEVABLE_MATERIAL "mc/hud_keyline_retrievable"	
#define EQUIPMENT_UNPLACEABLE_MATERIAL "mc/hud_keyline_unplaceable"	
#define EQUIPMENT_ENEMYEQUIP_MATERIAL  "mc/hud_keyline_enemyequip"	
#define PLAYER_HACKER_TOOL_HACKED 		"mc/mtl_hacker_tool_hacked"
#define PLAYER_HACKER_TOOL_HACKING 		"mc/mtl_hacker_tool_hacking"
#define PLAYER_HACKER_TOOL_BREACHING 	"mc/mtl_hacker_tool_breaching"

#precache( "material", EQUIPMENT_RETRIEVABLE_MATERIAL );
#precache( "material", EQUIPMENT_UNPLACEABLE_MATERIAL );
#precache( "material", EQUIPMENT_ENEMYEQUIP_MATERIAL );
#precache( "material", PLAYER_HACKER_TOOL_HACKED );
#precache( "material", PLAYER_HACKER_TOOL_HACKING );
#precache( "material", PLAYER_HACKER_TOOL_BREACHING );


function __init__()
{
}

