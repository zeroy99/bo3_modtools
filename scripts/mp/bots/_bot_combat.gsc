#using scripts\shared\array_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\weapons\_weapon_utils;
#using scripts\shared\weapons\_weapons;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;
#using scripts\mp\bots\_bot;
#using scripts\shared\bots\_bot;
#using scripts\shared\bots\_bot_combat;
#using scripts\shared\bots\bot_traversals;
#using scripts\shared\killstreaks_shared;

#insert scripts\mp\bots\_bot.gsh;

#define EXPLOSION_RADIUS_FRAG	256
#define EXPLOSION_RADIUS_FLASH	650

#define JUMP_TAG_RADIUS_SQ	16384	// 128 * 128
	
#namespace bot_combat;

function bot_ignore_threat( entity )
{
	if ( threat_requires_launcher( entity ) && !self bot::has_launcher() )
	{
		return true;
/*	TODO:
		eyePos = self GetEye();
	
		pitchMax = GetDvarFloat( "player_view_pitch_up" );
		pitchMin = -GetDvarFloat( "player_view_pitch_down" );
		
		// Entity is in FOV but outside pitch range
		threatAngles = VectorToAngles( entity.origin - eyePos );
		
		// TODO: Is threatAngles[0] in 0 to 360 or -180 to 180?
		if ( threatAngles[0] > pitchMax || threatAngles[0] < pitchMin )
		{
			continue;
		}
*/		
	}
	
	return false;
}

function mp_pre_combat()
{
	self bot_combat::bot_pre_combat();
	
	if ( self IsReloading() ||
	     self IsSwitchingWeapons() ||
	     self IsThrowingGrenade() ||
	     self IsMeleeing() ||
	     self IsRemoteControlling() ||
	     self IsInVehicle() ||
	     self IsWeaponViewOnlyLinked() )
	{
		return;
	}
	
	if ( self has_threat() )
	{		
		self threat_switch_weapon();
		return;
	}
	
	if ( self switch_weapon() )
	{
		return;
	}
	
	if ( self reload_weapon() )
	{
		return;
	}
	
	self bot::use_killstreak();
}


function mp_post_combat()
{
	// Dogtag handling
	if( !IsDefined( level.dogtags ) )
	{
		return;
	}
		
	if ( isdefined( self.bot.goalTag ) )
	{
		if ( !self.bot.goalTag gameobjects::can_interact_with( self ) )
		{
			// Cancel the tag
			self.bot.goalTag = undefined;
			
			if ( !self bot_combat::has_threat() && self BotGoalSet() )
			{
				self BotSetGoal( self.origin );
			}
		}
		else if ( !self.bot.goalTagOnGround &&
		          !self bot_combat::has_threat() &&
		          self IsOnGround() &&
		          Distance2DSquared( self.origin , self.bot.goalTag.origin ) < JUMP_TAG_RADIUS_SQ && 
		          self BotSightTrace( self.bot.goalTag ) )
		{
			self thread bot::jump_to( self.bot.goalTag.origin );
		}
	}
	else if ( !self BotGoalSet() )
	{
		closestTag = self get_closest_tag();
	
		if ( isdefined( closestTag ) )
		{
			// Trigger radius from _dogtags.gsc
			self set_goal_tag( closestTag );
		}
	}
	
}

function threat_requires_launcher( enemy ) 
{
	if ( !isdefined( enemy ) || IsPlayer( enemy ) )
	{
		return false;
	}
	
	killstreakType = undefined;
	
	if ( isdefined( enemy.killstreakType ) )
	{
		killstreakType = enemy.killstreakType;
	}
	else if ( isdefined( enemy.parentStruct ) && isdefined( enemy.parentStruct.killstreakType ) )
	{
		killstreakType = enemy.parentStruct.killstreakType;
	}
	
	if ( !isdefined( killstreakType ) )
	{
		return false;
	}
	
	switch( killstreakType )
	{
		case "uav":
		case "counteruav":
		case "satellite":
		case "helicopter_gunner":
			return true;
	}
	
	return false;
}

function combat_throw_proximity( origin )
{
}

function combat_throw_smoke( origin )
{
}

function combat_throw_lethal( origin )
{
}

function combat_throw_tactical( origin )
{
}

function combat_toss_frag( origin )
{
}

function combat_toss_flash( origin )
{
}

function combat_tactical_insertion( origin )
{
	return false;
}

function nearest_node( origin )
{
	return undefined;
}

function dot_product( origin )
{
	return bot::fwd_dot( origin );
}

// Dogtags
//========================================

function get_closest_tag()
{
	closestTag = undefined;
	closestTagDistSq = undefined;
	
	foreach( tag in level.dogtags )
	{
		if ( !tag gameobjects::can_interact_with( self ) )
		{
			continue;
		}
		
		distSq = DistanceSquared( self.origin, tag.origin );
		
		if ( !isdefined( closestTag ) || distSq  < closestTagDistSq )
		{
			closestTag = tag;
			closestTagDistSq = distSq;
		}
	}
	
	return closestTag;
}

function set_goal_tag( tag )
{
	self.bot.goalTag = tag;
	
	traceStart = tag.origin;
	traceEnd = tag.origin + (0,0,-64);
	trace = BulletTrace( traceStart, traceEnd, false, undefined );
	
	self.bot.goalTagOnGround = ( trace["fraction"] < 1 );
	
	self bot::path_to_trigger( tag.trigger );
	self bot::sprint_to_goal();
}