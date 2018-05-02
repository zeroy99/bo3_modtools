#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using  scripts\shared\vehicle_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_helicopter_sounds;
#using scripts\mp\_util;

#insert scripts\mp\killstreaks\_killstreaks.gsh;

#using scripts\shared\duplicaterender_mgr;
#insert scripts\shared\duplicaterender.gsh;

#namespace flak_drone;

#define CAMO_REVEAL_TIME 	0.5

REGISTER_SYSTEM( "flak_drone", &__init__, undefined )
	
function __init__()
{		
	clientfield::register( "vehicle", "flak_drone_camo", VERSION_SHIP, 3, "int", &active_camo_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function active_camo_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	flags_changed = self duplicate_render::set_dr_flag( "active_camo_flicker", newVal == HELICOPTER_CAMO_STATE_FLICKER );
	flags_changed = self duplicate_render::set_dr_flag( "active_camo_on", false ) || flags_changed;
	flags_changed = self duplicate_render::set_dr_flag( "active_camo_reveal", true ) || flags_changed;
	if ( flags_changed )
	{
		self duplicate_render::update_dr_filters(localClientNum);
	}
	
	self notify( "endtest" );
	
	self thread doReveal( localClientNum, newVal != HELICOPTER_CAMO_STATE_OFF );
}

function doReveal( localClientNum, direction )
{
	self notify( "endtest" );
	self endon( "endtest" );
	
	self endon( "entityshutdown" );
	
	if( direction )
	{
		startVal = 1;
	}
	else
	{
		startVal = 0;
	}
	
	while( ( startVal >= 0 ) && ( startVal <= 1 ) )
	{
		self MapShaderConstant( localClientNum, 0, "scriptVector0", startVal, 0, 0, 0 );
		if( direction )
		{
			startVal -= CLIENT_FRAME / CAMO_REVEAL_TIME;
		}
		else
		{
			startVal += CLIENT_FRAME / CAMO_REVEAL_TIME;
		}
		wait( CLIENT_FRAME );
	}
	
	flags_changed = self duplicate_render::set_dr_flag( "active_camo_reveal", false );
	flags_changed = self duplicate_render::set_dr_flag( "active_camo_on", direction ) || flags_changed;
	if ( flags_changed )
	{
		self duplicate_render::update_dr_filters(localClientNum);
	}
}