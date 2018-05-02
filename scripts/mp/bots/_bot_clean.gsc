#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#insert scripts\mp\bots\_bot.gsh;

#using scripts\mp\bots\_bot;
#using scripts\mp\bots\_bot_combat;
#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;
#using scripts\shared\bots\bot_traversals;
#using scripts\shared\bots\bot_buttons;


#using scripts\mp\teams\_teams;
#using scripts\mp\_util;

#namespace bot_clean;

#define IDLE_TACO_RADIUS 1024
#define COMBAT_TACO_RADIUS 256
#define DEPOSIT_NUM 10
	
function init()
{
	level.botPostCombat = &bot_post_combat;
	level.botIdle = &bot_idle;
	
	level.botUpdateThreatGoal = &update_threat_goal;
}

function bot_post_combat()
{
	// Forget about the current target or hub when entering combat
	//if ( self bot_combat::has_threat() )
	//{
	//	self.targetTaco = undefined;
	//	self.targetHub = undefined;
	//}
	
	// Ditch the hub if it's inactive or out of tacos
	if ( isdefined( self.targetHub ) )
	{
		if ( self.carriedTacos == 0 || self.targetHub.interactTeam == "none" )
		{
			self.targetHub = undefined;
			self BotSetGoal( self.origin );
		}
	}
	
	// Ditch the taco if it's inactive or recycled
	if ( isdefined( self.targetTaco ) )
	{
		if ( self.targetTaco.interactTeam == "none" || self.targetTaco.DropTime != self.targetTacoDropTime )
		{
			self.targetTaco = undefined;
			self BotSetGoal( self.origin );
		}
	}
	
	// Check for nearby tacos
	if ( !self bot_combat::has_threat() )
	{
		look_for_taco( IDLE_TACO_RADIUS );
	}
	
	self bot_combat::mp_post_combat();
}

function bot_idle()
{
	// Go to/stay in the deposit point
	if ( isdefined( self.targetHub ) )
	{
		self bot::path_to_point_in_trigger( self.targetHub.trigger );
		self bot::sprint_to_goal();
		return;
	}
			
	// Go look for a deposit point
	if ( RandomInt( DEPOSIT_NUM ) < self.carriedTacos )
	{
		foreach( hub in level.cleanDepositHubs )
		{
			if ( hub.interactTeam == "any" )
			{
				self.targetHub = hub;
				self.targetTaco = undefined;
				self bot::path_to_point_in_trigger( self.targetHub.trigger );
				self bot::sprint_to_goal();
				return;
			}
		}
	}		
	
	if ( look_for_taco( IDLE_TACO_RADIUS ) )
	{
		return;
	}
	
	self bot::bot_idle();
}

function look_for_taco( radius )
{
	bestTaco = get_best_taco( radius );
	
	if ( !isdefined( bestTaco ) )
	{
		return false;	
	}
	
	self.targetTaco = bestTaco;
	self.targetTacoDropTime = bestTaco.dropTime;
	
	self bot::path_to_point_in_trigger( bestTaco.trigger );
	self bot::sprint_to_goal();
	
	return true;
}

function get_best_taco( radius )
{
	radiusSq = radius * radius;
	
	// Look for the closest taco in the nearby radius, or the closest one on the map
	bestTaco = undefined;
	bestTacoDistSq = undefined;
	
	foreach ( taco in level.tacos )
	{
		if ( taco.interactTeam == "none" || !IsPointOnNavMesh( taco.origin , self ) )
		{
			continue;
		}
		
		tacoDistSq = Distance2DSquared( self.origin, taco.origin );
		
		if ( taco.attacker != self && tacoDistSq > radiusSq )
		{
			continue;
		}
		
		if ( !isdefined( bestTaco ) || tacoDistSq < bestTacoDistSq )
		{
			bestTaco = taco;
			bestTacoDistSq = tacoDistSq;
		}
	}
	
	return bestTaco;
}

function update_threat_goal()
{
	if ( isdefined( self.targetHub ) )
	{
		if ( !self BotGoalSet() )
	    {
			self bot::path_to_point_in_trigger( self.targetHub.trigger );
			self bot::sprint_to_goal();
	    }
		return;
	}
	
	radiusSq = COMBAT_TACO_RADIUS * COMBAT_TACO_RADIUS;
	
	if ( isdefined( self.targetTaco ) )
	{
		tacoDistSq = Distance2DSquared( self.origin, self.targetTaco.origin );
		if ( tacoDistSq > radiusSq )
		{
			self.targetTaco = undefined;
		}
	}
	
	if ( isdefined( self.targetTaco ) || self look_for_taco( IDLE_TACO_RADIUS ) )
	{
		return;
	}
	
	self bot_combat::update_threat_goal();
}