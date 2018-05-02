#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;
#using scripts\shared\abilities\gadgets\_gadget_camo_render;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_camo", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "camo_shader", VERSION_SHIP, 3, "int", &ent_camo_material_callback, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function ent_camo_material_callback( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( oldVal == newVal && oldVal == 0 && !bWasTimeJump )
	{
		return;
	}

	flags_changed = self duplicate_render::set_dr_flag_not_array( "gadget_camo_friend", util::friend_not_foe( local_client_num, true ) );
	flags_changed |= self duplicate_render::set_dr_flag_not_array( "gadget_camo_flicker", newVal == GADGET_CAMO_SHADER_FLICKER );
	flags_changed |= self duplicate_render::set_dr_flag_not_array( "gadget_camo_break", newVal == GADGET_CAMO_SHADER_BREAK );
	flags_changed |= self duplicate_render::set_dr_flag_not_array( "gadget_camo_reveal", newVal != oldVal );
	flags_changed |= self duplicate_render::set_dr_flag_not_array( "gadget_camo_on", newVal != GADGET_CAMO_SHADER_OFF );
	flags_changed |= self duplicate_render::set_dr_flag_not_array( "hide_model",  newVal == GADGET_CAMO_SHADER_OFF );
	flags_changed |= bNewEnt;

	if ( flags_changed )
	{
		self duplicate_render::update_dr_filters(local_client_num);
	}
	
	self notify( "endtest" );
	
	if ( newVal && ( bWasTimeJump || bNewEnt ) )
	{
		self thread gadget_camo_render::forceOn( local_client_num );
	}
	else if ( newVal != oldVal )
	{
		self thread gadget_camo_render::doReveal( local_client_num, newVal != GADGET_CAMO_SHADER_OFF );
	}
	
	if ( newVal && !oldVal || ( newVal && ( bWasTimeJump || bNewEnt ) ) )
	{
		self GadgetPulseResetReveal();
	}
}
