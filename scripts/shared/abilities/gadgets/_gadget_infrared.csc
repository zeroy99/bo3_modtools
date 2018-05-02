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
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;


REGISTER_SYSTEM( "gadget_infrared", &__init__, undefined )

function __init__()
{
	callback::on_spawned( &on_player_spawned );

	clientfield::register( "toplayer", "infrared_on", VERSION_SHIP, 1, "int", &infrared_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level.thermalActive = 0;
}


function infrared_changed( localclientnum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	level.thermalActive = newVal;
	
	GadgetSetInfrared( localclientnum, newVal );
		
	players = GetPlayers( localclientnum );
	foreach( player in players )
	{
		if( self util::IsEnemyPlayer( player ) )
		{
			player duplicate_render::set_entity_thermal( localclientnum, newVal );
		}
	}
}

function on_player_spawned( localClientNum )
{
	localPlayer = GetLocalPlayer( localClientNum );
	if( localPlayer != self )
	{
		if( localPlayer util::IsEnemyPlayer( self ) )
	{
		self duplicate_render::set_entity_thermal( localClientNum, level.thermalActive );
	}
		
		return;
	}
}


