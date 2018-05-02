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
#using scripts\shared\abilities\gadgets\_gadget_clone_render;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\system_shared;

#define CLONE_SHADER_CONST					"scriptVector3"
	
REGISTER_SYSTEM( "gadget_clone", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "actor", "clone_activated", VERSION_SHIP, 1, "int", &clone_activated, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "clone_damaged", VERSION_SHIP, 1, "int", &clone_damaged, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
		
	clientfield::register( "allplayers", "clone_activated", VERSION_SHIP, 1, "int", &player_clone_activated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function set_shader( localClientNum, enabled, entity )
{
	if( entity isfriendly( localclientnum ) )
	{
		self duplicate_render::update_dr_flag( localClientNum, "clone_ally_on", enabled );
	}
	else
	{
		self duplicate_render::update_dr_flag( localClientNum, "clone_enemy_on", enabled );
	}
}

function clone_activated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self._isClone = true;
		self set_shader( localClientNum, true, self getowner( localClientNum ) );
		if( isDefined( level._monitor_tracker ) )
		{
			self thread [[level._monitor_tracker]]( localClientNum );
		}
		self thread gadget_clone_render::transition_shader( localClientNum );
	}
}

function player_clone_activated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !isdefined( self ) )
		return;
	
	if( newVal )
	{
		self set_shader( localclientnum, true, self );
		self thread gadget_clone_render::transition_shader( localClientNum );
	}
	else
	{
		self set_shader( localclientnum, false, self );
		self notify ( "clone_shader_off" );
		self MapShaderConstant( localClientNum, 0, CLONE_SHADER_CONST, 1, 0, 0, 1 ); 
	}
}

function clone_damage_flicker( localClientNum )
{
	self endon( "entityshutdown" );
	self notify( "start_flicker" );
	self endon( "start_flicker" );
	
	self duplicate_render::update_dr_flag( localClientNum, "clone_damage", true );
	self waittill( "stop_flicker" );
	self duplicate_render::update_dr_flag( localClientNum, "clone_damage", false );
}

function clone_damage_finish()
{
	self endon( "entityshutdown" );
	self endon( "start_flicker" );
	self endon( "stop_flicker" );
	
	wait( .2 );
	self notify( "stop_flicker" );
}

function clone_damaged( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self thread clone_damage_flicker( localClientNum );
	}
	else
	{
		self thread clone_damage_finish();
	}
}
