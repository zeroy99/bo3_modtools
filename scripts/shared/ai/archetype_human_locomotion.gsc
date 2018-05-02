// COMMON AI SYSTEMS INCLUDES
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
// ADDITIONAL INCLUDES
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

function autoexec RegisterBehaviorScriptfunctions()
{	
	// ------- PREPARE FOR MOVEMENT -----------//
	BT_REGISTER_API( "prepareForMovement",								&prepareForMovement ); 
	BSM_REGISTER_API( "prepareForMovement",								&prepareForMovement );
	
	// ------- TACTICAL WALK ARRIVE -----------//
	BT_REGISTER_API( "shouldTacticalArrive", 							&shouldTacticalArriveCondition );
	
	// ------- SPRINT -----------//
	BT_REGISTER_API( "humanShouldSprint", 								&humanShouldSprint );
	
	// ------- ARRIVAL -----------//
	BSM_REGISTER_API( "planHumanArrivalAtCover",						&planHumanArrivalAtCover );
	BSM_REGISTER_API( "shouldPlanArrivalIntoCover",						&shouldPlanArrivalIntoCover );
	BSM_REGISTER_CONDITION( "shouldArriveExposed",						&shouldArriveExposed );
	
	// ------- LOCOMOTION UPDATE -----------//
	BSM_REGISTER_API( "nonCombatLocomotionUpdate",						&nonCombatLocomotionUpdate );
	BSM_REGISTER_API( "combatLocomotionStart",							&combatLocomotionStart );
	BSM_REGISTER_API( "combatLocomotionUpdate",							&combatLocomotionUpdate );
	BSM_REGISTER_CONDITION( "humanNonCombatLocomotionCondition",		&humanNonCombatLocomotionCondition ); 
	BSM_REGISTER_CONDITION( "humanCombatLocomotionCondition",			&humanCombatLocomotionCondition ); 
	
	BSM_REGISTER_CONDITION( "shouldSwitchToTacticalWalkFromRun",		&shouldSwitchToTacticalWalkFromRun );
	
	BT_REGISTER_API( "prepareToStopNearEnemy",							&prepareToStopNearEnemy );
	BSM_REGISTER_CONDITION( "prepareToStopNearEnemy",					&prepareToStopNearEnemy );
	BT_REGISTER_API( "prepareToMoveAwayFromNearByEnemy",				&prepareToMoveAwayFromNearByEnemy );
	
	BSM_REGISTER_CONDITION( "shouldTacticalWalkPain",					&shouldTacticalWalkPain );
	BSM_REGISTER_CONDITION( "beginTacticalWalkPain",					&beginTacticalWalkPain );
	BSM_REGISTER_CONDITION( "shouldContinueTacticalWalkPain",			&shouldContinueTacticalWalkPain );
	
	BSM_REGISTER_CONDITION( "shouldTacticalWalkScan",					&shouldTacticalWalkScan );
	BSM_REGISTER_CONDITION( "continueTacticalWalkScan",					&continueTacticalWalkScan );
	BSM_REGISTER_API( "tacticalWalkScanTerminate",						&tacticalWalkScanTerminate );
	
	// ------- PAIN -----------//
	BSM_REGISTER_CONDITION( "BSMLocomotionHasValidPainInterrupt",		&BSMLocomotionHasValidPainInterrupt );		// only to be used by the BSM
}

// ------- PAIN -----------//
function private tacticalWalkScanTerminate( entity )
{
	entity.lastTacticalScanTime = GetTime();
	
	return true;
}

#define TACTICAL_SCAN_INTERVAL 2000
function private shouldTacticalWalkScan( entity )
{
	if ( IsDefined( entity.lastTacticalScanTime ) &&
		( entity.lastTacticalScanTime + TACTICAL_SCAN_INTERVAL ) > GetTime() )
	{
		return false;
	}

	if( !entity HasPath() )
	{
		return false;
	}

	if ( IsDefined( entity.enemy ) )
	{
		return false;
	}
	
	if ( entity ShouldFaceMotion() )
	{
		if ( ai::HasAiAttribute( entity, "forceTacticalWalk" ) &&
			!ai::GetAiAttribute( entity, "forceTacticalWalk" ) )
		{
			return false;
		}
	}

	animation = entity AsmGetCurrentDeltaAnimation();
	
	// Scan animations can only be played at tactical walk animation boundaries.
	if ( IsDefined( animation ) )
	{
		animTime = entity GetAnimTime( animation );
		return animTime <= 0.05;
	}
	
	return false;
}

#define TACTICAL_SCAN_BLEND_OUT 0.2
function private continueTacticalWalkScan( entity )
{
	if( !entity HasPath() )
	{
		return false;
	}

	if ( IsDefined( entity.enemy ) )
	{
		return false;
	}
	
	if ( entity ShouldFaceMotion() )
	{
		if ( ai::HasAiAttribute( entity, "forceTacticalWalk" ) &&
			!ai::GetAiAttribute( entity, "forceTacticalWalk" ) )
		{
			return false;
		}
	}
	
	animation = entity AsmGetCurrentDeltaAnimation();
	
	if ( IsDefined( animation ) )
	{
		animLength = GetAnimLength( animation );
		animTime = entity GetAnimTime( animation ) * animLength;
		
		normalizedTime = ( animTime + TACTICAL_SCAN_BLEND_OUT ) / animLength;
		
		return normalizedTime < 1.0;
	}
	
	return false;
}

#define PAIN_TIME_WINDOW 3000
#define PAIN_CHANCE 0.25
function private shouldTacticalWalkPain( entity )
{
	if ( ( !IsDefined( entity.startPainTime ) || ( entity.startPainTime + PAIN_TIME_WINDOW ) < GetTime() ) &&
		RandomFloat( 1.0 ) > PAIN_CHANCE )
	{
		return BSMLocomotionHasValidPainInterrupt( entity );
	}
	
	return false;
}

function private beginTacticalWalkPain( entity )
{
	entity.startPainTime = GetTime();
	
	return true;
}

#define PAIN_TIME_LENGTH 100
function private shouldContinueTacticalWalkPain( entity )
{
	return ( entity.startPainTime + PAIN_TIME_LENGTH ) >= GetTime();
}

function private BSMLocomotionHasValidPainInterrupt( entity )
{
	return ( entity HasValidInterrupt("pain") );
}

function private shouldArriveExposed( behaviorTreeEntity )
{
	if( behaviorTreeEntity ai::get_behavior_attribute( "disablearrivals" ) )
		return false;
	
	if( behaviorTreeEntity HasPath() )
	{
		if( IsDefined( behaviorTreeEntity.node )
		    && IsCoverNode( behaviorTreeEntity.node )
			&& IsDefined( behaviorTreeEntity.pathGoalPos )
	    	&& DistanceSquared( behaviorTreeEntity.pathGoalPos, behaviorTreeEntity GetNodeOffsetPosition( behaviorTreeEntity.node ) ) < 8
	   	)
		{
			return false;
		}
	}
	
	return true;
}

function private prepareToStopNearEnemy( behaviorTreeEntity )
{
	behaviorTreeEntity ClearPath();
	behaviorTreeEntity.keepClaimedNode = true;
}

function private prepareToMoveAwayFromNearByEnemy( behaviorTreeEntity )
{
	behaviorTreeEntity ClearPath();
	behaviorTreeEntity.keepClaimedNode = true;
}

function private shouldPlanArrivalIntoCover( behaviorTreeEntity )
{
	goingToCoverNode = IsDefined( behaviorTreeEntity.node ) && IsCoverNode( behaviorTreeEntity.node );
	
	if( !goingToCoverNode )
	{
		return false;
	}
		
	if( IsDefined( behaviorTreeEntity.pathGoalPos ) )
	{
		if( IsDefined( behaviorTreeEntity.arrivalfinalpos ) )
		{
			if( behaviorTreeEntity.arrivalfinalpos != behaviorTreeEntity.pathGoalPos )
			{
				return true;
			}
			else if ( behaviorTreeEntity.replannedCoverArrival === false &&
				IsDefined( behaviorTreeEntity.exitPos ) &&
				IsDefined( behaviorTreeEntity.predictedExitPos ) )
			{
				behaviorTreeEntity.replannedCoverArrival = true;
				
				exitDir = VectorNormalize( behaviorTreeEntity.predictedExitPos - behaviorTreeEntity.exitPos );
				currentDir = VectorNormalize( behaviorTreeEntity.origin - behaviorTreeEntity.exitPos );
				
				// If the AI deviated more than 30 degrees from the exit direction we used
				// for planning an arrival, force a replan. This can typically happen when
				// an exit animation moves the AI out of cover in a different direction
				// than we planned for.
				// Without replanning the AI's path can change significantly enough that
				// the original planned arrival will be aborted.
				if ( VectorDot( exitDir, currentDir ) < Cos( 30 ) )
				{
					// Force the predicted arrival direction to be recalculated upon a replan.
					behaviorTreeEntity.predictedArrivalDirectionValid = false;
					return true;
				}
			}
		}
	}
	
	return false;
}

function private shouldSwitchToTacticalWalkFromRun( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
	{
		return false;
	}
	
	if ( ai::HasAiAttribute( behaviorTreeEntity, "forceTacticalWalk" ) &&
		ai::GetAiAttribute( behaviorTreeEntity, "forceTacticalWalk" ) )
	{
		return true;
	}
	
	goalPos = undefined;
	
	if( IsDefined( behaviorTreeEntity.arrivalFinalPos ) )
	{
		goalPos = behaviorTreeEntity.arrivalFinalPos;
	}
	else
	{
		goalPos = behaviorTreeEntity.pathGoalPos;
	}
	
	// for moving short distances
	if( Isdefined( behaviorTreeEntity.pathStartPos ) && Isdefined( goalPos ) )
	{
		pathDist = DistanceSquared( behaviorTreeEntity.pathStartPos, goalPos );
		
		if( pathDist < SQR( 250 ) )
		{
			return true;
		}
	}
	
	if( !behaviorTreeEntity ShouldFaceMotion() )
	{
		return true;
	}

	return false;		
}

function private humanNonCombatLocomotionCondition( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
		
	if( IS_TRUE( behaviorTreeEntity.accurateFire ) )
		return true;
	
	if( behaviorTreeEntity humanShouldSprint() )
		return true;
			
	if( IsDefined( behaviorTreeEntity.enemy ) )
		return false;
	
	return true;		
}

function private humanCombatLocomotionCondition( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
	
	// AI's like snipers will not fire when on the move.
	if( IS_TRUE( behaviorTreeEntity.accurateFire ) )
		return false;
		
	if( behaviorTreeEntity humanShouldSprint() )
		return false;
		
	if( IsDefined( behaviorTreeEntity.enemy ) )
		return true;
	
	return false;
}

function private combatLocomotionStart( behaviorTreeEntity )
{
	// Choose a runNGun variation. 
	randomChance = RandomInt( 100 );
	
	if( randomChance > 50 )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, RUN_N_GUN_VARIATION, RUN_N_GUN_FORWARD );		
		return true;
	}
	
	if( randomChance > 25 )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, RUN_N_GUN_VARIATION, RUN_N_GUN_STRAFE_1 );		
		return true;
	}
		
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, RUN_N_GUN_VARIATION, RUN_N_GUN_STRAFE_2 );		
	return true;
}

function private nonCombatLocomotionUpdate( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
			
	// AI will go into CombatLocomotion, unless they are set to accurate fire or sprinting
	if( IsDefined( behaviorTreeEntity.enemy ) && ( !IS_TRUE( behaviorTreeEntity.accurateFire ) && !behaviorTreeEntity humanShouldSprint() ) )
		return false;	
	
	if( !behaviorTreeEntity ASMIsTransitionRunning() )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );
		
		if ( !IsDefined( behaviorTreeEntity.replannedCoverArrival ) )
		{
			// Force an arrival replan once the transition animation completes.
			behaviorTreeEntity.replannedCoverArrival = false;
		}
	}
	else
	{
		behaviorTreeEntity.replannedCoverArrival = undefined;
	}

	return true;		
}

function private combatLocomotionUpdate( behaviorTreeEntity )
{
	if( !behaviorTreeEntity HasPath() )
		return false;
	
	if( behaviorTreeEntity humanShouldSprint() )
		return false;
	
	if( !behaviorTreeEntity ASMIsTransitionRunning() )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );
		
		if ( !IsDefined( behaviorTreeEntity.replannedCoverArrival ) )
		{
			// Force an arrival replan once the transition animation completes.
			behaviorTreeEntity.replannedCoverArrival = false;
		}
	}
	else
	{
		behaviorTreeEntity.replannedCoverArrival = undefined;
	}
		
	if( IsDefined( behaviorTreeEntity.enemy ) )
		return true;
	
	return false;
}


// ------- PREPARE FOR MOVEMENT -----------//
function private prepareForMovement( behaviorTreeEntity )
{	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );		
	
	return true;
}

// ------- TACTICAL WALK ARRIVE -----------//

// Here's how the arrival angles look relative to the cover node x, with the direction
// numbers on the outside
//	   7			8			   9			
//
//			45		0		315
//			
//	   4	90		x		270    6
//					
//			135	   180		225
//
//	   1			2			   3

function private isArrivingFour( arrivalAngle )
{
	if ( arrivalAngle >= 45 && arrivalAngle <= 120 )
	{
		return true;
	}
	return false;
}

function private isArrivingOne( arrivalAngle )
{
	if ( arrivalAngle >= 120 && arrivalAngle <= 165 )
	{
		return true;
	}
	return false;
}

function private isArrivingTwo( arrivalAngle )
{
	if ( arrivalAngle >= 165 && arrivalAngle <= 195 )
	{
		return true;
	}
	return false;
}

function private isArrivingThree( arrivalAngle )
{
	if ( arrivalAngle >= 195 && arrivalAngle <= 240 )
	{
		return true;
	}
	return false;
}

function private isArrivingSix( arrivalAngle )
{
	if ( arrivalAngle >= 240 && arrivalAngle <= 315 )
	{
		return true;
	}
	return false;
}

// Here's how the facing angles look relative to the player x, with the direction
// numbers on the outside
//	  7			    8		        9
//								
//			45		0		-45
//			
//	  4 	90		x		-90	    6
//					
//			135	 180/-180	-135
//
//	  1			    2			    3

function private isFacingFour( facingAngle )
{
	if ( facingAngle >= 45 && facingAngle <= 135 )
	{
		return true;
	}
	return false;
}

function private isFacingEight( facingAngle )
{
	if ( facingAngle >= -45 && facingAngle <= 45 )
	{
		return true;
	}
	return false;
}

function private isFacingSeven( facingAngle )
{
	if ( facingAngle >= 0 && facingAngle <= 90 )
	{
		return true;
	}
	return false;
}

function private isFacingSix( facingAngle )
{
	if ( facingAngle >= -135 && facingAngle <= -45 )
	{
		return true;
	}
	return false;
}

function private isFacingNine( facingAngle )
{
	if ( facingAngle >= -90 && facingAngle <= 0 )
	{
		return true;
	}
	return false;
}

#define DEFAULT_TAC_ARRIVE_DISTANCE 35
#define MINIMUM_TAC_ARRIVE_DISTANCE 25
#define MINIMUM_TAC_ARRIVE_ANGLE 60

function private shouldTacticalArriveCondition( behaviorTreeEntity )
{
	// TEMP: Alden Higgins 7-30-2014 don't tactical arrive unless dvar is set
	if ( getDvarInt("enableTacticalArrival") != 1 )
	{
		return false;
	}
	
	// Check if behaviorTreeEntity has a cover node as a goal
	if ( !IsDefined( behaviorTreeEntity.node ) )
	{
		return false;
	}
	
	// TEMP: Alden Higgins 7-31-2014 Temporary check cover node type as new tactical arrival animations are added
	if ( !NODE_COVER_LEFT( behaviorTreeEntity.node )
//	    && !NODE_COVER_RIGHT( behaviorTreeEntity.node )
//	    && !NODE_COVER_STAND( behaviorTreeEntity.node )
//	    && !NODE_COVER_CROUCH( behaviorTreeEntity.node )
	)
	{
		return false;
	}
	
	// TEMP: Alden Higgins 8-5-2014 Temporary check cover node stance as well
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, ARRIVAL_STANCE );
	if ( stance != STANCE_STAND )
	{
		return false;
	}
	
	arrivalDistance = DEFAULT_TAC_ARRIVE_DISTANCE;
	/#
	// Can be used for testing purposes to see if an animation works better from a different distance
	arrivalDvar = getDvarInt( "tacArrivalDistance" );
	if ( arrivalDvar != 0 )
	{
		arrivalDistance = arrivalDvar;
	}
	#/
	
	nodeOffsetPosition = behaviorTreeEntity GetNodeOffsetPosition( behaviorTreeEntity.node );

	if ( Distance( nodeOffsetPosition, behaviorTreeEntity.origin ) > arrivalDistance ||
	    Distance( nodeOffsetPosition, behaviorTreeEntity.origin ) < MINIMUM_TAC_ARRIVE_DISTANCE )
	{
		return false;
	}

	// If the player is entering from an angle less than minimumTacArrivalAngle degrees away from the cover node's forward angles
	// then don't tactically arrive...here's a diagram where x is the cover node, the dashes are the cover's geo, and the angles
	// are the differences from the node's forward that we are checking:
	//
	//				45	25	0	25	45
	//				60				60
	//					  -----		
	//				90		x		90
	//
	//				135	   180		135
	//				
	entityAngles = VectorToAngles( behaviorTreeEntity.origin - nodeOffsetPosition );
	if ( abs( behaviorTreeEntity.node.angles[ 1 ] - entityAngles[ 1 ] ) < MINIMUM_TAC_ARRIVE_ANGLE )
	{
		return false;
	}
	
	tacticalFaceAngle = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, TACTICAL_ARRIVAL_FACING_YAW );
	arrivalAngle = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, LOCOMOTION_ARRIVAL_YAW );
	// Check and make sure the player is facing the right way depending on the the angle they arrive at in order to play a tactical arrival
	if ( isArrivingFour( arrivalAngle ) )
	{
		if ( !isFacingSix( tacticalFaceAngle ) && !isFacingEight( tacticalFaceAngle ) && !isFacingFour( tacticalFaceAngle ) )
		{
			return false;
		}
	}
	else if ( isArrivingOne( arrivalAngle ) )
	{
		if ( !isFacingNine( tacticalFaceAngle ) && !isFacingSeven( tacticalFaceAngle ) )
		{
			return false;
		}
	}
	else if ( isArrivingTwo( arrivalAngle ) )
	{
		if ( !isFacingEight( tacticalFaceAngle ) )
		{
			return false;
		}
	}
	else if ( isArrivingThree( arrivalAngle ) )
	{
		if ( !isFacingSeven( tacticalFaceAngle ) && !isFacingNine( tacticalFaceAngle ) )
		{
			return false;
		}
	}
	else if ( isArrivingSix( arrivalAngle ) )
	{
		if ( !isFacingFour( tacticalFaceAngle ) && !isFacingEight( tacticalFaceAngle ) && !isFacingSix( tacticalFaceAngle ) )
		{
			return false;
		}
	}
	else
	{
		return false;
	}
	return true;
}

// ------- SPRINT -----------//
function private humanShouldSprint()
{
	currentLocoMovementType = Blackboard::GetBlackBoardAttribute( self, HUMAN_LOCOMOTION_MOVEMENT_TYPE );
	
	return ( currentLocoMovementType == HUMAN_LOCOMOTION_MOVEMENT_SPRINT );
}

// ------- ARRIVAL PLANNER -----------//
function private planHumanArrivalAtCover( behaviorTreeEntity, arrivalAnim )
{
	if( behaviorTreeEntity ai::get_behavior_attribute( "disablearrivals" ) )
		return false;
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );
	
	if( !IsDefined( arrivalAnim ) )
		return false;
	
	if( IsDefined( behaviorTreeEntity.node ) && IsDefined( behaviorTreeEntity.pathGoalPos ) )
	{
		if( !IsCoverNode( behaviorTreeEntity.node ) )
		{
			return false;
		}
		
		nodeOffsetPosition = behaviorTreeEntity GetNodeOffsetPosition( behaviorTreeEntity.node );
			
		if( nodeOffsetPosition != behaviorTreeEntity.pathGoalPos )
		{
			return false;
		}
	
		if( IsDefined( arrivalAnim ) )
		{			
			isRight = NODE_COVER_RIGHT(behaviorTreeEntity.node);
			splitTime = GetArrivalSplitTime( arrivalAnim, isRight );
			isSplitArrival = ( splitTime < 1 );
				
			nodeApproachYaw = behaviorTreeEntity GetNodeOffsetAngles( behaviorTreeEntity.node )[1];
			
			angle = (0, nodeApproachYaw - GetAngleDelta( arrivalAnim ), 0);
			
			if( isSplitArrival )
			{					
				forwardDir = AnglesToForward( angle );
				rightDir = AnglesToRight( angle );
								
				// TODO(David Young 2-25-15): This assumes a blend out of 0.2 seconds.
				animLength = GetAnimLength( arrivalAnim );
				moveDelta = GetMoveDelta( arrivalAnim, 0, (animLength - 0.2) / animLength );
				preMoveDelta = GetMoveDelta( arrivalAnim, 0, splitTime );
				postMoveDelta = moveDelta - preMoveDelta;
							
				// post delta
				forward			   = VectorScale( forwardDir, postMoveDelta[0] );
				right			   = VectorScale( rightDir, postMoveDelta[1] );
				coverEnterPos      = nodeOffsetPosition - forward + right;
				postEnterPos 	   = coverEnterPos;
								
				// pre delta
				forward			   = VectorScale( forwardDir, preMoveDelta[0] );
				right			   = VectorScale( rightDir, preMoveDelta[1] );
				coverEnterPos      = coverEnterPos - forward + right;
				
				/#
				RecordLine( postEnterPos, nodeOffsetPosition, ORANGE, "Animscript", behaviorTreeEntity );
				RecordLine( coverEnterPos, postEnterPos, ORANGE, "Animscript", behaviorTreeEntity );
				#/
				
				if( !behaviorTreeEntity MayMoveFromPointToPoint( postEnterPos, nodeOffsetPosition, true, false ) )
				{
					return false;
				}
				
				if( !behaviorTreeEntity MayMoveFromPointToPoint( coverEnterPos, postEnterPos, true, false ) )
				{
					return false;
				}
			}
			else	
			{
				forwardDir = AnglesToForward( angle );
				rightDir = AnglesToRight( angle );
			
				moveDeltaArray	   = GetMoveDelta( arrivalAnim );
				forward			   = VectorScale( forwardDir, moveDeltaArray[0] );
				right			   = VectorScale( rightDir, moveDeltaArray[1] );
				coverEnterPos      = nodeOffsetPosition - forward + right;			
				
				if( !behaviorTreeEntity MayMoveFromPointToPoint( coverEnterPos, nodeOffsetPosition, true, true ) )
				{
					return false;				  
				}
			}
			
			if( !checkCoverArrivalConditions( coverEnterPos, nodeOffsetPosition ) )
			{
				return false;
			}
								
			// Make sure the arrival pos is clear
			if( IsPointOnNavMesh( coverEnterPos, behaviorTreeEntity ) )
			{
				/# RecordCircle( coverEnterPos, 2, (1,0,0), "Script", behaviorTreeEntity ); #/
				behaviorTreeEntity UsePosition( coverEnterPos, behaviorTreeEntity.pathGoalPos );
				
				return true;
			}
		}
	}
	
	return false;
}

#define ARRIVAL_HEIGHT_TOLERANCE 30
function private checkCoverArrivalConditions( coverEnterPos, coverPos )
{
	distSqToNode = DistanceSquared( self.origin, coverPos );
	distSqFromNodeToEnterPos = DistanceSquared( coverPos, coverEnterPos );
			
	// check if the AI is enough distance away from the coverEnterPos
	awayFromEnterPos = distSqToNode >= ( distSqFromNodeToEnterPos + 150 );
	
	if( !awayFromEnterPos )
		return false;
	
	trace = GroundTrace( coverEnterPos + ( 0, 0, 72 ), coverEnterPos + ( 0, 0, -72 ), false, false, false );
	
	// Make sure the arrival position is within a height tolerance to the cover position.
	if ( IsDefined( trace[ "position" ] ) && Abs( trace[ "position" ][2] - coverPos[2] ) > ARRIVAL_HEIGHT_TOLERANCE )
	{
/#
		if ( GetDvarInt( "ai_debugArrivals" ) )
		{
			RecordCircle( coverEnterPos, 1, (1,0,0), "Animscript" );
			Record3DText( "Arrival Start Position", coverEnterPos, RED, "Animscript", undefined, 0.4 );
			
			RecordCircle( trace[ "position" ], 1, (1,0,0), "Animscript" );
			Record3DText( "Distance To Ground: " + Int( Abs( trace[ "position" ][2] - coverPos[2] ) ), trace[ "position" ] + ( 0, 0, 5 ), RED, "Animscript", undefined, 0.4 );
			Record3DText( "Ground Position Below Height Tolerance of " + ARRIVAL_HEIGHT_TOLERANCE, trace[ "position" ], RED, "Animscript", undefined, 0.4 );
			
			RecordLine( coverEnterPos, trace[ "position" ], (1,0,0), "Animscript" );
		}
#/
		return false;
	}
	
	return true;	
}

// TODO - This function is very expensive, 
// we need to have cover_split notetrack in all the arrival/exit animations wherever there is a split.
function private GetArrivalSplitTime( arrivalAnim, isright )
{
	if ( !isdefined( level.animArrivalSplitTimes ) )
	{
		level.animArrivalSplitTimes = [];
	}
	
	if ( isdefined( level.animArrivalSplitTimes[arrivalAnim] ) )
	{
		return level.animArrivalSplitTimes[arrivalAnim];
	}

	bestsplit = -1;
	
	if( AnimHasNotetrack( arrivalAnim, ARRIVAL_COVER_SPLIT_NOTETRACK ) )
	{
		times = GetNotetrackTimes( arrivalAnim, ARRIVAL_COVER_SPLIT_NOTETRACK );
		Assert( times.size > 0 );
		bestsplit = times[0];			
	}
	else
	{
		// TODO(David Young 2-25-15): Hardcoded assumption of 0.2 blendout.
		animLength = GetAnimLength( arrivalAnim );
		normalizedLength = (animLength - 0.2) / animLength;
		
		angleDelta = getAngleDelta( arrivalAnim, 0, normalizedLength );
		fullDelta = getMoveDelta( arrivalAnim, 0, normalizedLength );
		const numiter = 100;
			
		bestvalue = -100000000;
	
		for ( i = 0; i < numiter; i++ )
		{
			splitTime = 1.0 * i / (numiter - 1);
			
			delta = getMoveDelta( arrivalAnim, 0, splitTime );
			delta = DeltaRotate( fullDelta - delta, 180 - angleDelta );
			
			if ( isright )
				delta = ( delta[0], 0 - delta[1], delta[2] );
				
			val = min( delta[0] - 32, delta[1] );
			
			if ( val > bestvalue || bestsplit < 0 )
			{
				bestvalue = val;
				bestsplit = splitTime;
			}
		}
	}
	
	level.animArrivalSplitTimes[arrivalAnim] = bestsplit;

	return bestsplit;
}

function private DeltaRotate( delta, yaw )
{
	cosine = cos( yaw );
	sine = sin( yaw );
	return ( delta[0] * cosine - delta[1] * sine, delta[1] * cosine + delta[0] * sine, 0);
}
