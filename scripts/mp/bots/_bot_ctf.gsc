#using scripts\shared\array_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;

#using scripts\mp\gametypes\ctf;
#using scripts\mp\_util;
#using scripts\mp\bots\_bot;
#using scripts\mp\bots\_bot_combat;

#insert scripts\shared\shared.gsh;
#insert scripts\mp\bots\_bot.gsh;

#define CTF_GOAL_RADIUS 16

#define BOT_DEFEND_CHANCE 80
#define BOT_DEFEND_RADIUS 1024
	
#namespace bot_ctf;

function init()
{
	level.onBotConnect = &on_bot_connect;
	level.botIdle = &bot_idle;
}

function on_bot_connect()
{
	foreach( flag in level.flags )
	{
		if ( flag gameobjects::get_owner_team() == self.team )
		{
			self.bot.flag = flag;
		}
		else
		{
			self.bot.enemyFlag = flag;
		}
	}

	self bot::on_bot_connect();
}

function bot_idle()
{
	carrier = self.bot.enemyFlag gameobjects::get_carrier();
	
	// Carrying the enemy flag
	if ( isdefined( carrier ) && carrier == self )
	{
		// Wander around the home flag area until it comes back
		if ( self.bot.flag gameobjects::is_object_away_from_home() )
		{
			self bot::approach_point( self.bot.flag.flagBase.trigger.origin, 0, BOT_DEFEND_RADIUS );
		}
		// Capture the enemy flag
		else
		{
			self bot::approach_goal_trigger( self.bot.flag.flagBase.trigger );
		}
		
		self bot::sprint_to_goal();
		return;
	}
	// Defend home base
	else if ( Distance2DSquared( self.origin, self.bot.flag.flagBase.trigger.origin ) < ( BOT_DEFEND_RADIUS * BOT_DEFEND_RADIUS ) &&
	          RandomInt( 100 ) < BOT_DEFEND_CHANCE )
	{
		self bot::approach_point( self.bot.flag.flagBase.trigger.origin, 0, BOT_DEFEND_RADIUS );
		self bot::sprint_to_goal();
		return;
	}
	// Return the friendly flag
	else if ( self.bot.flag gameobjects::is_object_away_from_home() )
	{
		enemyCarrier = self.bot.flag gameobjects::get_carrier();
		
		if ( isdefined( enemyCarrier ) )
		{
			// Don't go straight for the carrier since the objective doesn't update perfectly
			self bot::approach_point( enemyCarrier.origin, 250, 1000, 128 );
			self bot::sprint_to_goal();
			return;
		}
		else
		{
			self BotSetGoal( self.bot.flag.trigger.origin );
			self bot::sprint_to_goal();
			return;
		}
	}
	// Take the enemy flag
	else if ( !isdefined( carrier ) )
	{
		self bot::approach_goal_trigger( self.bot.enemyFlag.trigger );
		self bot::sprint_to_goal();
		return;
	}
	
	self bot::bot_idle();
}