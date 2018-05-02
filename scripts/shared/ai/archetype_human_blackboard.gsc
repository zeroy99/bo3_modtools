#using scripts\shared\array_shared;

#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_locomotion_utility;

#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

#namespace Blackboard;

//*****************************************************************************
// NOTE! When adding a new blackboard variable you must also declare the 
// blackboard variable within the ast_definitions file found at:
//
// //t7/main/game/share/raw/animtables/ast_definitions.json
//
// This allows the Animation Selector Table system to determine how to create
// queries based on the blackboard variable.
//
// Also, all blackboard values must be lowercased! No convert to lower is
// perform when assigning values to the blackboard.
//
//*****************************************************************************
function RegisterActorBlackBoardAttributes()
{
	BB_REGISTER_ATTRIBUTE( TACTICAL_ARRIVAL_FACING_YAW,				undefined,				&BB_GetTacticalArrivalFacingYaw );
	BB_REGISTER_ATTRIBUTE( HUMAN_LOCOMOTION_MOVEMENT_TYPE,			undefined,			 	&BB_GetLocomotionMovementType ); 
	BB_REGISTER_ATTRIBUTE( HUMAN_COVER_FLANKABILITY,				undefined,			 	&BB_GetCoverFlankability );
	BB_REGISTER_ATTRIBUTE( ARRIVAL_TYPE,							undefined,			 	&BB_GetArrivalType );
	BB_REGISTER_ATTRIBUTE( HUMAN_LOCOMOTION_VARIATION,				undefined,			 	undefined );
}

function private BB_GetArrivalType()
{
	if( self ai::get_behavior_attribute( "disablearrivals" ) )
		return DONT_ARRIVE_AT_GOAL;
	
	return ARRIVE_AT_GOAL;
}

function private BB_GetTacticalArrivalFacingYaw()
{
	return AngleClamp180( self.angles[ 1 ] - self.node.angles[ 1 ] );
}

#define CLOSE_FRIENDLY_DISTANCE ( 120 )
#define MAX_NEARBY_FRIENDLIES 3
function private BB_GetLocomotionMovementType()
{	
	if ( !ai::GetAiAttribute( self, "disablesprint" ) )
	{
		// if the script interface needs sprinting
		if ( ai::GetAiAttribute( self, "sprint" ) )
		{
			return HUMAN_LOCOMOTION_MOVEMENT_SPRINT;
		}
		
		if ( !isDefined( self.nearbyFriendlyCheck ) )
			self.nearbyFriendlyCheck = 0;
		
		now = GetTime();
		
		if ( now >= self.nearbyFriendlyCheck )
		{
			self.nearbyFriendlyCount = GetActorTeamCountRadius( self.origin, CLOSE_FRIENDLY_DISTANCE, self.team, "neutral" );
			self.nearbyFriendlyCheck = now + 500;
		}
		
		if ( self.nearbyFriendlyCount >= MAX_NEARBY_FRIENDLIES )
		{
			// Too many nearby friendlies to sprint, run instead.
			return HUMAN_LOCOMOTION_MOVEMENT_DEFAULT;
		}
				
		// should sprint if too far away from enemy
		if ( IsDefined( self.enemy ) && IsDefined( self.runAndGunDist ) )
		{
			if ( DistanceSquared( self.origin, self LastKnownPos( self.enemy ) ) 
			   > ( self.runAndGunDist * self.runAndGunDist ) )
			{
				return HUMAN_LOCOMOTION_MOVEMENT_SPRINT;
			}
		}
		else if ( IsDefined( self.goalpos ) && IsDefined( self.runAndGunDist ) )
		{
			if ( DistanceSquared( self.origin, self.goalpos ) 
			   > ( self.runAndGunDist * self.runAndGunDist ) )
			{
				return HUMAN_LOCOMOTION_MOVEMENT_SPRINT;
			}
		}
	}
	
	return HUMAN_LOCOMOTION_MOVEMENT_DEFAULT;
}

function private BB_GetCoverFlankability()
{
	if( self ASMIsTransitionRunning() )
	{
		return HUMAN_COVER_UNFLANKABLE;
	}
	
	if( !IsDefined( self.node ) )
	{
		return HUMAN_COVER_UNFLANKABLE;
	}
			
	coverMode = Blackboard::GetBlackBoardAttribute( self, COVER_MODE );
				
	if( IsDefined( coverMode ) )
	{			
		coverNode = self.node;
		
		if( coverMode == COVER_ALERT_MODE || coverMode == COVER_MODE_NONE )
		{
			return HUMAN_COVER_FLANKABLE;
		}
		
		if( NODE_COVER_PILLAR( coverNode ) )
		{
			return ( coverMode == COVER_BLIND_MODE );
		}
		else if( NODE_COVER_LEFT( coverNode ) || NODE_COVER_RIGHT( coverNode ) )			
		{
			return ( coverMode == COVER_BLIND_MODE || coverMode == COVER_OVER_MODE );
		}
		else if( NODE_COVER_STAND( coverNode ) || NODE_COVER_CROUCH( coverNode ) )
		{
			return HUMAN_COVER_FLANKABLE;
		}				
	}

	return HUMAN_COVER_UNFLANKABLE;
}
