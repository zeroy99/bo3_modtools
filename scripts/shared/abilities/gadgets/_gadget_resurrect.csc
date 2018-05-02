#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\postfx_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_resurrect.gsh;

#define RESURRECT_OUTLINE_MATERIAL "mc/hud_keyline_resurrect"	
	
REGISTER_SYSTEM( "gadget_resurrect", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "resurrecting", VERSION_SHIP, 1, "int", &player_resurrect_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "resurrect_state", VERSION_SHIP, RESURRECT_STATE_BITS, "int", &player_resurrect_state_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	duplicate_render::set_dr_filter_offscreen( "resurrecting", 99, 
	                                "resurrecting",                        undefined,                    
	                                DR_TYPE_OFFSCREEN, RESURRECT_OUTLINE_MATERIAL, DR_CULL_ALWAYS  );
	
	visionset_mgr::register_visionset_info( RESURRECT_VISIONSET_ALIAS, VERSION_SHIP, RESURRECT_VISIONSET_STEPS, undefined, RESURRECT_VISIONSET );
	visionset_mgr::register_visionset_info( RESURRECT_VISIONSET_UP_ALIAS, VERSION_SHIP, RESURRECT_VISIONSET_UP_STEPS, undefined, RESURRECT_VISIONSET_UP );
}


function player_resurrect_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	self duplicate_render::update_dr_flag( localClientNum, "resurrecting", newVal );
}

function resurrect_down_fx( localClientNum )
{
	self endon ( "entityshutdown" );
	self endon ( "finish_rejack" );
		
	self thread postfx::PlayPostfxBundle( RESURRECT_POSTFX_BUNDLE_CLOSE );
	wait( RESURRECT_POSTFX_BUNDLE_CLOSE_DURATION );
	self thread postfx::PlayPostfxBundle( RESURRECT_POSTFX_BUNDLE_PUS );
}

function resurrect_up_fx( localClientNum )
{
	self endon ( "entityshutdown" );
	self notify( "finish_rejack" );
	
	self thread postfx::PlayPostfxBundle( RESURRECT_POSTFX_BUNDLE_OPEN );
}

function player_resurrect_state_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == RESURRECT_STATE_DOWN )
	{
		self thread resurrect_down_fx( localClientNum );
	}
	else if( newVal == RESURRECT_STATE_UP )
	{
		self thread resurrect_up_fx( localClientNum );
	}
	else
	{
		self thread postfx::stopPostfxBundle();
	}
}

