#using scripts\shared\array_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic_utils;

#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;
#using scripts\shared\bots\bot_buttons;
#using scripts\mp\bots\_bot;
#using scripts\mp\bots\_bot_combat;

#insert scripts\mp\bots\_bot.gsh;

#namespace bot_sd;

#define ZONE_APPROACH_RADIUS_MAX 750
#define ZONE_DEFEND_PERCENT 70

function init()
{
	level.botIdle = &bot_idle;
}

function bot_idle()
{
	if( !level.bombPlanted && !level.multibomb && self.team == game["attackers"] )
	{
		carrier = level.sdBomb gameobjects::get_carrier();
		
		if( !isdefined( carrier ) )
		{
			self BotSetGoal( level.sdBomb.trigger.origin );
			self bot::sprint_to_goal();
			return;
		}
	}
	
	approachRadiusSq = ZONE_APPROACH_RADIUS_MAX * ZONE_APPROACH_RADIUS_MAX;
	
	// Check for Plant / Defuse
	foreach( zone in level.bombZones )
	{
		if ( IS_TRUE( level.bombPlanted ) && !IS_TRUE( zone.isPlanted ) )
		{
			continue;
		}
		
		zoneTrigger = self get_zone_trigger( zone );
		
		if ( self IsTouching( zoneTrigger ) )
		{
			if ( self can_plant( zone ) || self can_defuse( zone ) )
			{
				self bot::press_use_button();
				return;
			}
		}
		
		if ( DistanceSquared( self.origin, zone.trigger.origin ) < approachRadiusSq )
		{
			// Defuse / Plant nearby zone
			if ( self can_plant( zone ) || self can_defuse( zone ) )
			{
				self bot::path_to_trigger( zoneTrigger );
				self bot::sprint_to_goal();
				return;
			}
		}
	}
	
	// Shuffle zones
	zones = array::randomize( level.bombZones );
	
	// Check for zones to defuse
	foreach( zone in zones )
	{
		if ( IS_TRUE( level.bombPlanted ) && !IS_TRUE( zone.isPlanted ) )
		{
			continue;
		}
	
		if ( self can_defuse( zone ) )
		{
			self bot::approach_goal_trigger( zoneTrigger, ZONE_APPROACH_RADIUS_MAX );
			self bot::sprint_to_goal();
			return;
		}
	}
	
	// Go to a random zone to plant / guard
	foreach( zone in zones )
	{
		if ( IS_TRUE( level.bombPlanted ) && !IS_TRUE( zone.isPlanted ) )
		{
			continue;
		}

		// Defend the nearby point
		if ( DistanceSquared( self.origin, zone.trigger.origin ) < approachRadiusSq &&
			 RandomInt( 100 ) < ZONE_DEFEND_PERCENT )
		{
			triggerRadius = self bot::get_trigger_radius( zone.trigger );
			self bot::approach_point( zone.trigger.origin, triggerRadius, ZONE_APPROACH_RADIUS_MAX );
			self bot::sprint_to_goal();
			return;
		}
	}
	
	self bot::bot_idle();
}

function get_zone_trigger( zone )
{
	if ( self.team ==  zone gameobjects::get_owner_team() )
	{
		return zone.bombDefuseTrig;
	}
	
	return zone.trigger;
}

function can_plant( zone )
{
	if ( level.multibomb )
	{
		return !IS_TRUE( zone.isPlanted ) && self.team != zone gameobjects::get_owner_team();
	}
	
	carrier = level.sdBomb gameobjects::get_carrier();
	
	return isdefined( carrier ) && self == carrier;
}

function can_defuse( zone )
{
	return IS_TRUE( zone.isPlanted ) && self.team == zone gameobjects::get_owner_team();
}