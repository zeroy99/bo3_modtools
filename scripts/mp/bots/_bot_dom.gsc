#using scripts\shared\array_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\dom;

#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;
#using scripts\mp\bots\_bot;
#using scripts\mp\bots\_bot_combat;

#insert scripts\mp\bots\_bot.gsh;

#define BOT_DOM_FLAG_NEAR_DIST_SQ	384 * 384
	
#namespace bot_dom;	

#define ARBITARY_RADIUS 160 // size of radius trigger in BO2
#define MAX_FLAG_TARGET_POINTS 256
#define MAX_FLAG_TARGET_HEIGHT 72
#define FLAG_TARGET_SPACING 37.5	// Default Radius * 2.5
#define BOT_RADIUS 15

function init()
{
	level.botUpdate = &bot_update;
	level.botPreCombat = &bot_pre_combat;
	level.botUpdateThreatGoal = &bot_update_threat_goal;
	level.botIdle = &bot_idle;
}

function bot_update()
{
	self.bot.capturingFlag = self get_capturing_flag();
	
	self.bot.goalFlag = undefined;
	
	if ( !self BotGoalReached() )
	{
		foreach( flag in level.domFlags )
		{
			if ( self bot::goal_in_trigger( flag.trigger ) )
			{
				self.bot.goalFlag = flag;
				break;
			}
		}
	}
	
	self bot::bot_update();
}

function bot_pre_combat()
{
	// Stop heading to goals that have been captured
	if ( !self bot_combat::has_threat() &&
	     isdefined( self.bot.goalFlag ) &&
	     self.bot.goalflag gameobjects::get_owner_team() == self.team )
	{
    	self BotSetGoal( self.origin );
	}
	
	self bot_combat::mp_pre_combat();
}


function bot_idle()
{
	if ( isdefined( self.bot.capturingFlag ) )
	{
		self bot::path_to_point_in_trigger( self.bot.capturingFlag.trigger );
		return;
	}
	
	bestFlag = get_best_flag();
	
	if ( isdefined( bestFlag ) )
	{
		self bot::approach_goal_trigger( bestFlag.trigger );
		self bot::sprint_to_goal();
		return;
	}
	
	self bot::bot_idle();
}

// Combat
//========================================

// Stay inside the goal when attacking
function bot_update_threat_goal()
{
	if ( isdefined( self.bot.capturingFlag ) )
	{
		if ( self BotGoalReached() )
		{
			self bot::path_to_point_in_trigger( self.bot.capturingFlag.trigger ); 
		}
		return;
	}
	
	self bot_combat::update_threat_goal();
}

// Dom Flags
//========================================

function get_capturing_flag()
{
	foreach( flag in level.domFlags )
	{
		if ( self.team != flag gameobjects::get_owner_team() && self IsTouching( flag.trigger ) )
		{
			return flag;
		}
	}
	
	return undefined;
}

function get_best_flag()
{	
	bestFlag = undefined;	
	bestFlagDistSq = undefined;

	// Closest flag under attack by the enemy, or not owned by their team
	foreach( flag in level.domFlags )
	{
		ownerTeam = flag gameobjects::get_owner_team();
		contested = flag gameobjects::get_num_touching_except_team( ownerTeam );
		distSq = Distance2DSquared( self.origin, flag.origin );
		
		if ( ownerTeam == self.team && !contested )
		{
			continue;
		}
		
		if ( !isdefined( bestFlag ) ||
		   	 distSq < bestFlagDistSq )
		{
			bestFlag = flag;
			bestFlagDistSq = distSq;
		}
	}
	
	return bestFlag;
}