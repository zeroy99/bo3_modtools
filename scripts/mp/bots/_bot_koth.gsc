#using scripts\shared\array_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;
#using scripts\mp\bots\_bot;
#using scripts\mp\bots\_bot_combat;

#insert scripts\mp\bots\_bot.gsh;

#namespace bot_koth;

function init()
{
	level.onBotSpawned = &on_bot_spawned;
	level.botUpdateThreatGoal = &bot_update_threat_goal;
	level.botIdle = &bot_idle;
}

function on_bot_spawned()
{
	self thread wait_zone_moved();
	
	self bot::on_bot_spawned();
}

function wait_zone_moved()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	while(1)
	{
		level waittill( "zone_moved" );
		
		if ( !self bot_combat::has_threat() && self BotGoalSet() )
		{
			self BotSetGoal( self.origin );
		}
	}
}

function bot_update_threat_goal()
{
	if ( isdefined( level.zone ) && self IsTouching( level.zone.gameobject.trigger ) )
	{
		if ( self BotGoalReached() )
		{
			self bot::path_to_point_in_trigger( level.zone.gameobject.trigger );
		}
		return;
	}
	
	self bot_combat::update_threat_goal();
}

function bot_idle()
{
	if ( isdefined( level.zone ) )
	{
		if ( self IsTouching( level.zone.gameobject.trigger ) )
		{
			self bot::path_to_point_in_trigger( level.zone.gameobject.trigger );
		}
		else
		{	
			self bot::approach_goal_trigger( level.zone.gameobject.trigger );
			self bot::sprint_to_goal();
		}
		return;
	}
	
	self bot::bot_idle();
}
