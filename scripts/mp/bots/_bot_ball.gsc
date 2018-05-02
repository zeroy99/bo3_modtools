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

#namespace bot_ball;

function init()
{
	level.botIdle = &bot_idle;
	level.botCombat = &bot_combat;
	level.botPreCombat = &bot_pre_combat;
}

function release_control_on_landing()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	while ( self IsOnGround() )
	{
		WAIT_SERVER_FRAME;
	}
	
	while ( !self IsOnGround() )
	{
		WAIT_SERVER_FRAME;
	}
	
	self BotReleaseManualControl();
}

function bot_pre_combat()
{
	if ( isdefined( self.carryObject ) )
	{
		if ( self IsOnGround() && self BotGoalSet() )
		{
			goal = level.ball_goals[util::getotherteam( self.team )];
			
			radius = 300;
			radiusSq = radius * radius;
			
			if ( Distance2DSquared( self.origin, goal.trigger.origin ) <= radiusSq )
			{
				if ( self BotSightTrace( goal.trigger ) )
				{
					self BotTakeManualControl();
					self thread bot::jump_to( goal.trigger.origin );
					self thread release_control_on_landing();
					
					// TODO: Try throwing the ball
					
					return;
				}
			}
		}
		
		if ( !self IsMeleeing() )
		{
			self bot::use_killstreak();
		}
		
		return;
	}
	
	self bot_combat::mp_pre_combat();
}

function bot_combat()
{
	if ( isdefined( self.carryObject ) )
	{
		if ( self bot_combat::has_threat() )
		{
			self bot_combat::clear_threat();
		}
		
		meleeThreat = bot_combat::get_greatest_threat( level.botSettings.meleeRange );
		
		if ( isdefined( meleeThreat ) )
		{
			angles = self GetPlayerAngles();
			fwd = AnglesToForward( angles );
		
			threatDir = meleeThreat.origin - self.origin ;
			threatDir = VectorNormalize( threatDir );
		
			dot = VectorDot( fwd, threatDir );
			
			if ( dot > level.botSettings.meleeDot )
			{
				self bot::tap_melee_button();
			}
		}
		                                  
		return;
	}
	
	self bot_combat::combat_think();
}

function bot_idle()
{
	if ( isdefined( self.carryObject ) )
	{		
		if ( !self BotGoalSet() )
		{
			// The goal trigger is too far off the navmesh
			goal = level.ball_goals[util::getotherteam( self.team )];
			goalPoint = goal.origin - ( 0, 0, 125 );
			self bot::approach_point( goalPoint );
			self bot::sprint_to_goal();	
		}
		
		return;	
	}
	
	triggers = [];
	balls = array::randomize( level.balls );
	
	foreach( ball in balls )
	{
		if ( !isdefined( ball.carrier ) && !ball.in_goal )
		{
			triggers[triggers.size] = ball.trigger;
		}
		else if ( isdefined( ball.carrier ) && ball.carrier.team != self.team )
		{
			// Don't go straight for the carrier since the objective doesn't update perfectly
			self bot::approach_point( ball.carrier.origin, 250, 1000, 128 );
			self bot::sprint_to_goal();
			return;
		}
	}

	// Go pick up the closest ball
	if ( triggers.size > 0 )
	{
		triggers = ArraySort( triggers, self.origin );
		
		self BotSetGoal( triggers[0].origin );
		self bot::sprint_to_goal();
		
		return;
	}
	
	self bot::bot_idle();
}