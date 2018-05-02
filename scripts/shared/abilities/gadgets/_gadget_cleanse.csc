#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\system_shared;

#define CLEANSE_MATERIAL "mc/hud_outline_model_z_green" // no alpha to differentiate from view model in shader

REGISTER_SYSTEM( "gadget_cleanse", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "gadget_cleanse_on", VERSION_SHIP, 1, "int", &has_cleanse_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	duplicate_render::set_dr_filter_offscreen( "cleanse_pl", 50, "cleanse_player", undefined, DR_TYPE_OFFSCREEN, CLEANSE_MATERIAL );
}


function has_cleanse_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal != oldVal )
	{
		self duplicate_render::update_dr_flag( localClientNum, "cleanse_player", newVal );
	}
}