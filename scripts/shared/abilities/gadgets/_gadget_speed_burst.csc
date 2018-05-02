#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\postfx_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_speed_burst.gsh;

REGISTER_SYSTEM( "gadget_speed_burst", &__init__, undefined )

function __init__()
{
	callback::on_localplayer_spawned( &on_localplayer_spawned );
	clientfield::register( "toplayer", "speed_burst", VERSION_SHIP, 1, "int", &player_speed_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	visionset_mgr::register_visionset_info( SPEED_BURST_VISIONSET_ALIAS, VERSION_SHIP, SPEED_BURST_VISIONSET_STEPS, undefined, SPEED_BURST_VISIONSET );
}	


function on_localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	filter::init_filter_speed_burst(self);
	filter::disable_filter_speed_burst( self,FILTER_INDEX_SPEED_BURST );
}

function player_speed_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	if ( newVal )
	{
		if( self == GetLocalPlayer( localClientNum ) )
		{
			filter::enable_filter_speed_burst( self, FILTER_INDEX_SPEED_BURST );
		}
	}
	else
	{
		if( self == GetLocalPlayer( localClientNum ) )
		{
			filter::disable_filter_speed_burst( self,FILTER_INDEX_SPEED_BURST );
		}
	}
}