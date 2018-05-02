#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\weapons\grapple.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace grapple;

REGISTER_SYSTEM( "grapple", &__init__, undefined )

#define GRAPPLE_OUTLINE_MATERIAL	"mc/hud_outline_model_white"
	
function __init__()
{
}

