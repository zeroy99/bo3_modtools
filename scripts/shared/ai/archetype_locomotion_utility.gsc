#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\math_shared;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

#namespace AiUtility;

// Use this utility if AI moves around using pathfinding should not be archetype dependent at all
// SUMEET TODO - add cover specific blackboard variables here.

function autoexec RegisterBehaviorScriptFunctions()
{	
	BT_REGISTER_API( "locomotionBehaviorCondition",				&locomotionBehaviorCondition ); 
	BSM_REGISTER_CONDITION( "locomotionBehaviorCondition",		&locomotionBehaviorCondition ); 
		
	BT_REGISTER_API( "nonCombatLocomotionCondition",			&nonCombatLocomotionCondition ); 
			
	BT_REGISTER_API( "setDesiredStanceForMovement",				&setDesiredStanceForMovement ); 
	BT_REGISTER_API( "clearPathFromScript",						&clearPathFromScript ); 
	
	// ------- PATROL -----------//	
	BT_REGISTER_API( "locomotionShouldPatrol",					&locomotionShouldPatrol ); 
	BSM_REGISTER_CONDITION( "locomotionShouldPatrol",			&locomotionShouldPatrol ); 
	
	// ------- TACTICAL WALK -----------//	
	BT_REGISTER_API( "shouldTacticalWalk",						&AiUtility::shouldTacticalWalk );
	BSM_REGISTER_CONDITION( "shouldTacticalWalk",				&AiUtility::shouldTacticalWalk );
		
	BT_REGISTER_API( "shouldAdjustStanceAtTacticalWalk",		&shouldAdjustStanceAtTacticalWalk );
	BT_REGISTER_API( "adjustStanceToFaceEnemyInitialize",		&adjustStanceToFaceEnemyInitialize );
	BT_REGISTER_API( "adjustStanceToFaceEnemyTerminate",		&adjustStanceToFaceEnemyTerminate );

	BT_REGISTER_API( "tacticalWalkActionStart",					&tacticalWalkActionStart );
	BSM_REGISTER_API( "tacticalWalkActionStart",				&tacticalWalkActionStart);
	
	// ------- ARRIVAL -----------//
	BT_REGISTER_API( "clearArrivalPos",							&clearArrivalPos ); 
	BSM_REGISTER_API("clearArrivalPos",							&clearArrivalPos);
	
	BT_REGISTER_API( "shouldStartArrival",						&shouldStartArrivalCondition );
	BSM_REGISTER_CONDITION( "shouldStartArrival",				&shouldStartArrivalCondition );
		
	// ------- TRAVERSAL -----------//
	BT_REGISTER_API( "locomotionShouldTraverse",				&locomotionShouldTraverse );
	BSM_REGISTER_CONDITION( "locomotionShouldTraverse",			&locomotionShouldTraverse ); 
	
	BT_REGISTER_ACTION( "traverseActionStart",					&traverseActionStart, undefined, undefined );
	BSM_REGISTER_CONDITION( "traverseSetup",					&traverseSetup ); 
	
	BT_REGISTER_API( "disableRepath",							&disableRepath );
	BT_REGISTER_API( "enableRepath",							&enableRepath );
	
	// ------- JUKE -----------//
	BT_REGISTER_API( "canJuke",									&canJuke );
	BT_REGISTER_API( "chooseJukeDirection",						&chooseJukeDirection );
	
	// ------- PAIN -----------//
	BSM_REGISTER_CONDITION( "locomotionPainBehaviorCondition",	&locomotionPainBehaviorCondition ); 
	
	// ------- STAIRS -----------//
	BSM_REGISTER_CONDITION( "locomotionIsOnStairs",				&locomotionIsOnStairs );
	BSM_REGISTER_CONDITION( "locomotionShouldLoopOnStairs",		&locomotionShouldLoopOnStairs );		
	BSM_REGISTER_CONDITION( "locomotionShouldSkipStairs",		&locomotionShouldSkipStairs );		
	
	BSM_REGISTER_API( "locomotionStairsStart",					&locomotionStairsStart );
	BSM_REGISTER_API( "locomotionStairsEnd",					&locomotionStairsEnd );
	
	BT_REGISTER_API( "delayMovement",							&delayMovement );
	BSM_REGISTER_API( "delayMovement",							&delayMovement );
}

// ------- STAIRS -----------//
function private locomotionIsOnStairs( behaviorTreeEntity )
{
	startNode = behaviorTreeEntity.traverseStartNode;
	if ( IsDefined( startNode ) && behaviorTreeEntity ShouldStartTraversal() )
	{
		if( IsDefined( startNode.animscript ) && IsSubStr( ToLower( startNode.animscript ), "stairs" ) )
			return true;
	}

	return false;
}

function private locomotionShouldSkipStairs( behaviorTreeEntity )
{	
	assert( IsDefined( behaviorTreeEntity._stairsStartNode ) && IsDefined( behaviorTreeEntity._stairsEndNode ) );

	numTotalSteps 	= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_TOTAL_STEPS );
	stepsSoFar 		= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_STEPS );
	
	direction	 	= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_DIRECTION );
	
	if( direction != STAIRCASE_UP )
	{
		return false;
	}
	
	numOutSteps	= 2;
	totalStepsWithoutOut = numTotalSteps - numOutSteps;
	
	if( stepsSoFar >= ( totalStepsWithoutOut ) )
	{
		return false;
	}
	
	remainingSteps = totalStepsWithoutOut - stepsSoFar;
	
	if( remainingSteps >=3 || remainingSteps >= 6 || remainingSteps >= 8 )
	{
		return true;
	}
	
	return false;
}

function private locomotionShouldLoopOnStairs( behaviorTreeEntity )
{
	assert( IsDefined( behaviorTreeEntity._stairsStartNode ) && IsDefined( behaviorTreeEntity._stairsEndNode ) );

	numTotalSteps 	= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_TOTAL_STEPS );
	stepsSoFar 		= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_STEPS );
	exitType		= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_EXIT_TYPE );
	direction	 	= Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_DIRECTION );
	
	numOutSteps	= 2; // 2 steps out unless we are going up
	if( direction == STAIRCASE_UP )
	{
		switch( exitType )
		{
		case STAIRCASE_UP_EXIT_L_3_STAIRS:
		case STAIRCASE_UP_EXIT_R_3_STAIRS:
			numOutSteps = 3;
			break;
		case STAIRCASE_UP_EXIT_L_4_STAIRS:
		case STAIRCASE_UP_EXIT_R_4_STAIRS:
			numOutSteps = 4;
			break;
		}
	}
	
	if( stepsSoFar >= ( numTotalSteps - numOutSteps ) )
	{
		behaviorTreeEntity SetStairsExitTransform();
		return false;
	}
	
	return true;
}

function private locomotionStairsStart( behaviorTreeEntity )
{
	startNode = behaviorTreeEntity.traverseStartNode;
	endNode	  = behaviorTreeEntity.traverseEndNode;
	
	assert( IsDefined( startNode ) && IsDefined( endNode ) );
	
	behaviorTreeEntity._stairsStartNode = startNode;
	behaviorTreeEntity._stairsEndNode	= endNode;
	
	if( startNode.type == "Begin" )
		direction = STAIRCASE_DOWN;
	else
		direction = STAIRCASE_UP;
		
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_TYPE, behaviorTreeEntity._stairsStartNode.animscript );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_STATE, STAIRCASE_START );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_DIRECTION, direction );	
	
	numTotalSteps = undefined;
	
	if( IsDefined( startNode.script_int ) )
	{
		numTotalSteps = int( endNode.script_int );
	}
	else if( IsDefined( endNode.script_int ) )
	{
		numTotalSteps = int( endNode.script_int );
	}
	
	// Set total number of steps
	assert( IsDefined( numTotalSteps ) && IsInt( numTotalSteps ) && numTotalSteps > 0 );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_TOTAL_STEPS, numTotalSteps );
	
	// so far, we have not taken any steps
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_NUM_STEPS, 0 );

	exitType = undefined;
	if ( direction == STAIRCASE_UP )
	{
		switch( int( behaviorTreeEntity._stairsStartNode.script_int ) % 4 )
		{
		case 0:	exitType = STAIRCASE_UP_EXIT_R_3_STAIRS;	break;
		case 1:	exitType = STAIRCASE_UP_EXIT_R_4_STAIRS;	break;
		case 2:	exitType = STAIRCASE_UP_EXIT_L_3_STAIRS;	break;
		case 3:	exitType = STAIRCASE_UP_EXIT_L_4_STAIRS;	break;
		}
	}
	else
	{
		switch( int( behaviorTreeEntity._stairsStartNode.script_int ) % 2 )
		{
		case 0:	exitType = STAIRCASE_DOWN_EXIT_L_2_STAIRS;	break;
		case 1:	exitType = STAIRCASE_DOWN_EXIT_R_2_STAIRS;	break;
		}
	}
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_EXIT_TYPE, exitType );

	return true;
}

function private locomotionStairLoopStart( behaviorTreeEntity )
{
	assert( IsDefined( behaviorTreeEntity._stairsStartNode ) && IsDefined( behaviorTreeEntity._stairsEndNode ) );
			
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_STATE, STAIRCASE_LOOP );
}

function private locomotionStairsEnd( behaviorTreeEntity )
{		
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_STATE, undefined );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STAIRCASE_DIRECTION, undefined );	
}

// ------- PAIN -----------//
function private locomotionPainBehaviorCondition( entity )
{
	return ( entity HasPath() && entity HasValidInterrupt("pain") );
}

function clearPathFromScript( behaviorTreeEntity )
{
	behaviorTreeEntity ClearPath();
}

function private nonCombatLocomotionCondition( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
		
	if( IS_TRUE( behaviorTreeEntity.accurateFire ) )
		return true;
		
			
	if( IsDefined( behaviorTreeEntity.enemy ) )
		return false;
	
	return true;		
}

function private combatLocomotionCondition( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
	
	// AI's like snipers will not fire when on the move.
	if( IS_TRUE( behaviorTreeEntity.accurateFire ) )
		return false;
	
	
		
	if( IsDefined( behaviorTreeEntity.enemy ) )
		return true;
	
	return false;
}

function locomotionBehaviorCondition( behaviorTreeEntity )
{		
	return behaviorTreeEntity HasPath();
}

function private setDesiredStanceForMovement( behaviorTreeEntity )
{	
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) != DEFAULT_MOVEMENT_STANCE )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );
	}
}

// ------- TRAVERSAL -----------//
function private locomotionShouldTraverse( behaviorTreeEntity )
{
	startNode = behaviorTreeEntity.traverseStartNode;
	if ( IsDefined( startNode ) && behaviorTreeEntity ShouldStartTraversal() )
	{
		return true;
	}

	return false;
}

function traverseSetup( behaviorTreeEntity )
{
	// TODO(David Young 7-25-14): This is really weird that we have to set the stance before taking a traversal.
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, TRAVERSAL_TYPE, behaviorTreeEntity.traverseStartNode.animscript );
	
	return true;
}

function traverseActionStart( behaviorTreeEntity, asmStateName )
{
	traverseSetup( behaviorTreeEntity );
	
	/#
	// Assert if no animation is found for the given traversal.
	animationResults = behaviorTreeEntity ASTSearch( IString( asmStateName ) );
	
	assert( IsDefined( animationResults[ ASM_ALIAS_ATTRIBUTE ] ), 
	       behaviorTreeEntity.archetype 
	       + " does not support traversal of type "
	       + behaviorTreeEntity.traverseStartNode.animscript 
	       + " \n@"
		   + behaviorTreeEntity.traverseStartNode.origin
		   + "\n"
	      );
	#/
		
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	return BHTN_RUNNING;
}

function private disableRepath( entity )
{
	entity.disableRepath = true;
}

function private enableRepath( entity )
{
	entity.disableRepath = false;
}

// ------- ARRIVAL BEHAVIOR -----------//
function shouldStartArrivalCondition( behaviorTreeEntity )
{
	if( behaviorTreeEntity ShouldStartArrival() )
		return true;
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: ClearArrivalPos \n"
"Summary: Clear arrival planning to a cover.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function clearArrivalPos( behaviorTreeEntity )
{
	// TODO(David Young 7-13-15): Default to clearing the path, until new executables post and "isarrivalpending" is available to script.
	if ( !IsDefined( behaviorTreeEntity.isarrivalpending ) || IS_TRUE( behaviorTreeEntity.isarrivalpending ) )
	{
		self ClearUsePosition();
	}
	
	return true;
}

function delayMovement( entity )
{
	entity PathMode( "move delayed", false, RandomFloatRange( 1, 2 ) );
	
	return true;
}

// ------- LOCOMOTION - TACTICAL WALK -----------//	
function private shouldAdjustStanceAtTacticalWalk( behaviorTreeEntity )
{
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	if( stance != DEFAULT_MOVEMENT_STANCE )
	{
		return true;
	}

	return false;
}

function private adjustStanceToFaceEnemyInitialize( behaviorTreeEntity )
{
	// AI's standing up out of cover should not play a reaction.
	behaviorTreeEntity.newEnemyReaction = false;
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );
	behaviorTreeEntity OrientMode( "face enemy" );	
	
	return true;
}

function private adjustStanceToFaceEnemyTerminate( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );
}

function private tacticalWalkActionStart( behaviorTreeEntity )
{	
	AiUtility::clearArrivalPos( behaviorTreeEntity );
	
	AiUtility::resetCoverParameters( behaviorTreeEntity );
	AiUtility::setCanBeFlanked( behaviorTreeEntity, false );
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );		
	behaviorTreeEntity OrientMode( "face enemy" );	
	
	return true;
}

// ------- LOCOMOTION - JUKE -----------//	

function private validJukeDirection( entity, entityNavMeshPosition, forwardOffset, lateralOffset )
{
 	jukeNavmeshThreshold = 6;
	
 	forwardPosition = entity.origin + lateralOffset + forwardOffset;
 	backwardPosition = entity.origin + lateralOffset - forwardOffset;
	
	forwardPositionValid = IsPointOnNavMesh( forwardPosition, entity ) && TracePassedOnNavMesh( entity.origin, forwardPosition );
	backwardPositionValid = IsPointOnNavMesh( backwardPosition, entity ) && TracePassedOnNavMesh( entity.origin, backwardPosition );
	
	if ( !IsDefined( entity.ignoreBackwardPosition ) )
	{
		return forwardPositionValid && backwardPositionValid;
	}
	else
	{
		return forwardPositionValid;
	}
	
	return false;
}

function calculateJukeDirection( entity, entityRadius, jukeDistance )
{
	jukeNavmeshThreshold = 6;
	defaultDirection = "forward";

	if ( IsDefined( entity.defaultJukeDirection ) )
    {
    	defaultDirection = entity.defaultJukeDirection;
    }
	
	if ( IsDefined( entity.enemy ) )
	{
		navmeshPosition = GetClosestPointOnNavMesh( entity.origin, jukeNavmeshThreshold );

		if ( !IsVec( navmeshPosition ) )
		{
			return defaultDirection;
		}

		vectorToEnemy = entity.enemy.origin - entity.origin;
		vectorToEnemyAngles = VectorToAngles( vectorToEnemy );
		forwardDistance = AnglesToForward( vectorToEnemyAngles ) * entityRadius;
		rightJukeDistance = AnglesToRight( vectorToEnemyAngles ) * jukeDistance;
		
		preferLeft = undefined;
		
		if ( entity HasPath() )
		{
			// Juke closer to the path goal position.
			rightPosition = entity.origin + rightJukeDistance;
			leftPosition = entity.origin - rightJukeDistance;
			
			preferLeft = DistanceSquared( leftPosition, entity.pathgoalpos ) <=
				DistanceSquared( rightPosition, entity.pathgoalpos );
		}
		else
		{
			preferLeft = math::cointoss();
		}

		if ( preferLeft )
		{
			if ( validJukeDirection( entity, navmeshPosition, forwardDistance, -rightJukeDistance ) )
			{
				return "left";
			}
			else if ( validJukeDirection( entity, navmeshPosition, forwardDistance, rightJukeDistance ) )
			{
				return "right";
			}
		}
		else
		{
			if ( validJukeDirection( entity, navmeshPosition, forwardDistance, rightJukeDistance ) )
			{
				return "right";
			}
			else if ( validJukeDirection( entity, navmeshPosition, forwardDistance, -rightJukeDistance ) )
			{
				return "left";
			}
		}
	}

	return defaultDirection;
}

function private calculateDefaultJukeDirection( entity )
{
	jukeDistance = 30;
	entityRadius = 15;
	
	if ( IsDefined( entity.jukeDistance ) )
	{
		jukeDistance = entity.jukeDistance;
	}
	
	if ( IsDefined( entity.entityRadius ) )
	{
		entityRadius = entity.entityRadius;
	}
	
	return AiUtility::calculateJukeDirection( entity, entityRadius, jukeDistance );
}

function canJuke( entity )
{
	// Don't juke if the enemy is too far away.
	if (IS_TRUE(self.is_disabled))
		return false;
		
	
	if ( IsDefined( entity.jukeMaxDistance ) && IsDefined( entity.enemy ) )
	{
		maxDistSquared = entity.jukeMaxDistance * entity.jukeMaxDistance;
		
		if ( Distance2DSquared( entity.origin, entity.enemy.origin ) > maxDistSquared )
		{
			return false;
		}
	}

	jukeDirection =
		AiUtility::calculateDefaultJukeDirection( entity );

	return jukeDirection != "forward";
}

function chooseJukeDirection( entity )
{
	jukeDirection =
		AiUtility::calculateDefaultJukeDirection( entity );

	Blackboard::SetBlackBoardAttribute( entity, JUKE_DIRECTION, jukeDirection );
}
