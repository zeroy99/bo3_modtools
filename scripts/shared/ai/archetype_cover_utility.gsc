#using scripts\shared\ai_shared;
#using scripts\shared\math_shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

#namespace AiUtility;
// Use this utility if AI takes cover, behavior here should not be archetype dependent at all

#define COVER_AIM_ANGLE_EPSILON 10 // 10 degree allowable threshold for aims against the aimtables

function autoexec RegisterBehaviorScriptFunctions()
{	
	BT_REGISTER_API( "isAtCrouchNode",								&isAtCrouchNode );
	BT_REGISTER_API( "isAtCoverCondition",							&isAtCoverCondition );
	BT_REGISTER_API( "isAtCoverStrictCondition",					&isAtCoverStrictCondition );
	BT_REGISTER_API( "isAtCoverModeOver",							&isAtCoverModeOver );
	BT_REGISTER_API( "isAtCoverModeNone",							&isAtCoverModeNone );
	BT_REGISTER_API( "isExposedAtCoverCondition",					&isExposedAtCoverCondition );
	BT_REGISTER_API( "keepClaimedNodeAndChooseCoverDirection",		&keepClaimedNodeAndChooseCoverDirection);	
	BT_REGISTER_API( "resetCoverParameters",						&resetCoverParameters );
	BT_REGISTER_API( "cleanupCoverMode",							&cleanupCoverMode );
	BT_REGISTER_API( "canBeFlankedService",							&canBeFlankedService );
	BT_REGISTER_API( "shouldCoverIdleOnly",							&shouldCoverIdleOnly );
	BT_REGISTER_API( "isSuppressedAtCoverCondition",				&isSuppressedAtCoverCondition );
	
	// ------- COVER - IDLE BEHAVIOR -----------//	
	BT_REGISTER_API( "coverIdleInitialize",						&coverIdleInitialize );
	BT_REGISTER_API( "coverIdleUpdate",							&coverIdleUpdate );
	BT_REGISTER_API( "coverIdleTerminate",						&coverIdleTerminate );
	
	// ------- COVER - FLANKED BEHAVIOR -----------//	
	BT_REGISTER_API( "isFlankedByEnemyAtCover",					&isFlankedByEnemyAtCover );
	BT_REGISTER_API( "coverFlankedActionStart",					&coverFlankedInitialize );
	BT_REGISTER_API( "coverFlankedActionTerminate",				&coverFlankedActionTerminate );

	// ------- COVER - OVER SHOOT BEHAVIOR -----------//	
	BT_REGISTER_API( "supportsOverCoverCondition",					&supportsOverCoverCondition );
	BT_REGISTER_API( "shouldOverAtCoverCondition",					&shouldOverAtCoverCondition );
	BT_REGISTER_API( "coverOverInitialize",							&coverOverInitialize );
	BT_REGISTER_API( "coverOverTerminate",							&coverOverTerminate );
	
	// ------- COVER - LEAN SHOOT BEHAVIOR -----------//	
	BT_REGISTER_API( "supportsLeanCoverCondition",					&supportsLeanCoverCondition );
	BT_REGISTER_API( "shouldLeanAtCoverCondition",					&shouldLeanAtCoverCondition );
	BT_REGISTER_API( "continueLeaningAtCoverCondition",				&continueLeaningAtCoverCondition );
	BT_REGISTER_API( "coverLeanInitialize",							&coverLeanInitialize );
	BT_REGISTER_API( "coverLeanTerminate",							&coverLeanTerminate );
	
	// ------- COVER - PEEK SHOOT BEHAVIOR -----------//	
	BT_REGISTER_API( "supportsPeekCoverCondition",					&supportsPeekCoverCondition );
	BT_REGISTER_API( "coverPeekInitialize",							&coverPeekInitialize );
	BT_REGISTER_API( "coverPeekTerminate",							&coverPeekTerminate );	
	
	// ------- COVER - RELOAD BEHAVIOR -----------//	
	BT_REGISTER_API( "coverReloadInitialize",						&coverReloadInitialize );
	BT_REGISTER_API( "refillAmmoAndCleanupCoverMode",				&refillAmmoAndCleanupCoverMode );
}

// ------- COVER - RELOAD BEHAVIOR -----------//	
function private coverReloadInitialize( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_ALERT_MODE );
	AiUtility::keepClaimNode( behaviorTreeEntity );
}

function refillAmmoAndCleanupCoverMode( behaviorTreeEntity )
{
	if( IsAlive( behaviorTreeEntity ) )
	{
		AiUtility::refillAmmo( behaviorTreeEntity );
	}
	
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
}

// ------- COVER - PEEK BEHAVIOR -----------//
function private supportsPeekCoverCondition( behaviorTreeEntity )
{
	return IsDefined( behaviorTreeEntity.node );
}

function private coverPeekInitialize( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_ALERT_MODE );
	AiUtility::keepClaimNode( behaviorTreeEntity );
	chooseCoverDirection( behaviorTreeEntity );
}

function private coverPeekTerminate( behaviorTreeEntity )
{
	AiUtility::chooseFrontCoverDirection( behaviorTreeEntity );
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
}
// ------- COVER - PEEK BEHAVIOR -----------//


// ------- COVER - LEAN SHOOT BEHAVIOR -----------//
function private supportsLeanCoverCondition( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.node ) )
	{
		if( NODE_COVER_LEFT( behaviorTreeEntity.node ) || NODE_COVER_RIGHT( behaviorTreeEntity.node ) )
		{
			return true;
		}
		else if ( NODE_COVER_PILLAR( behaviorTreeEntity.node ) )
		{
			if ( !ISNODEDONTLEFT( behaviorTreeEntity.node ) || !ISNODEDONTRIGHT( behaviorTreeEntity.node ) )
			{
				return true;
			}
		}
	}
	
	return false;
}

function private shouldLeanAtCoverCondition( behaviorTreeEntity )
{
	if( !IsDefined( behaviorTreeEntity.node ) ||
		!IsDefined( behaviorTreeEntity.node.type ) ||
		!IsDefined( behaviorTreeEntity.enemy) ||
		!IsDefined( behaviorTreeEntity.enemy.origin ) )
	{
		return false;
	}

	yawToEnemyPosition = AiUtility::GetAimYawToEnemyFromNode( behaviorTreeEntity, behaviorTreeEntity.node, behaviorTreeEntity.enemy );
	
	legalAimYaw = false;
		
	if( NODE_COVER_LEFT(behaviorTreeEntity.node) )
	{
		aimLimitsForCover = behaviortreeentity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_COVER_LEFT_LEAN);
		legalAimYaw = yawToEnemyPosition <= ( aimLimitsForCover[AIM_LEFT] + COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition >= -COVER_AIM_ANGLE_EPSILON;
	}
	else if( NODE_COVER_RIGHT(behaviorTreeEntity.node) )
	{
		aimLimitsForCover = behaviortreeentity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_COVER_RIGHT_LEAN);
		legalAimYaw = yawToEnemyPosition >= ( aimLimitsForCover[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition <= COVER_AIM_ANGLE_EPSILON;
	}
	else if( NODE_COVER_PILLAR(behaviorTreeEntity.node) )
	{
		aimLimitsForCover = behaviortreeentity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_COVER);
		supportsLeft = !ISNODEDONTLEFT( behaviorTreeEntity.node );
		supportsRight = !ISNODEDONTRIGHT( behaviorTreeEntity.node );
		
		// If both left and right are supported, then split the 180 coverage along the center, otherwise pad the leeway to force the AI to lean more often.
		angleLeeway = COVER_AIM_ANGLE_EPSILON;
		
		if ( supportsRight && supportsLeft )
		{
			angleLeeway = 0;
		}
		
		if ( supportsLeft )
		{
			legalAimYaw = yawToEnemyPosition <= ( aimLimitsForCover[AIM_LEFT] + COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition >= -angleLeeway;
		}
		
		if ( !legalAimYaw && supportsRight )
		{
			legalAimYaw = yawToEnemyPosition >= ( aimLimitsForCover[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition <= angleLeeway;
		}
	}
	
	return legalAimYaw;
}


function private continueLeaningAtCoverCondition( behaviorTreeEntity )
{
	if ( behaviorTreeEntity ASMIsTransitionRunning() )
	{
		return true; 
	}
	
	return AiUtility::shouldLeanAtCoverCondition( behaviorTreeEntity );
}


function private coverLeanInitialize( behaviorTreeEntity )
{
	AiUtility::setCoverShootStartTime( behaviorTreeEntity );
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_LEAN_MODE );
	AiUtility::chooseCoverDirection( behaviorTreeEntity );
}

function private coverLeanTerminate( behaviorTreeEntity )
{
	AiUtility::chooseFrontCoverDirection( behaviorTreeEntity );
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	AiUtility::clearCoverShootStartTime( behaviorTreeEntity );
}
// ------- COVER - LEAN SHOOT BEHAVIOR -----------//

// ------- COVER - OVER SHOOT BEHAVIOR -----------//
function private supportsOverCoverCondition( behaviorTreeEntity )
{
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	
	if ( IsDefined( behaviorTreeEntity.node ) )
	{
		if ( !IsInArray( GetValidCoverPeekOuts( behaviorTreeEntity.node ), COVER_MODE_OVER ) )
		{
			return false;
		}
	
		if( NODE_COVER_LEFT(behaviorTreeEntity.node) 
			|| NODE_COVER_RIGHT(behaviorTreeEntity.node) 
			|| NODE_COVER_CROUCH(behaviorTreeEntity.node) )
		{
			if( stance == STANCE_CROUCH )
			{
				return true;
			}
		}
		else if( NODE_COVER_STAND(behaviorTreeEntity.node) )
		{
			if( stance == STANCE_STAND )
				return true;
		}
	}
	
	return false;
}

function private shouldOverAtCoverCondition( entity )
{
	if ( !IsDefined( entity.node ) ||
		!IsDefined( entity.node.type ) ||
		!IsDefined( entity.enemy) ||
		!IsDefined( entity.enemy.origin ) )
	{
		return false;
	}
	
	aimTable = ( AiUtility::isCoverConcealed( entity.node ) ?
		AIM_LIMIT_TABLE_ENTRY_COVER_CONCEALED_OVER : AIM_LIMIT_TABLE_ENTRY_COVER_OVER );
		
	aimLimitsForCover = entity GetAimLimitsFromEntry( aimTable );
	
	yawToEnemyPosition = AiUtility::GetAimYawToEnemyFromNode( entity, entity.node, entity.enemy );
	
	legalAimYaw = ( yawToEnemyPosition >= ( aimLimitsForCover[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) ) &&
		( yawToEnemyPosition <= ( aimLimitsForCover[AIM_LEFT] + COVER_AIM_ANGLE_EPSILON ) );
		
	if ( !legalAimYaw )
	{
		return false;
	}

	pitchToEnemyPosition = AiUtility::GetAimPitchToEnemyFromNode( entity, entity.node, entity.enemy );
		
	legalAimPitch = ( pitchToEnemyPosition >= ( aimLimitsForCover[AIM_UP] + COVER_AIM_ANGLE_EPSILON ) ) &&
		( pitchToEnemyPosition <= ( aimLimitsForCover[AIM_DOWN] + COVER_AIM_ANGLE_EPSILON ) );
	
	if ( !legalAimPitch )
	{
		return false;
	}
	
	return true;
}

function private coverOverInitialize( behaviorTreeEntity )
{
	AiUtility::setCoverShootStartTime( behaviorTreeEntity );
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_OVER_MODE );	
}

function private coverOverTerminate( behaviorTreeEntity )
{	
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	AiUtility::clearCoverShootStartTime( behaviorTreeEntity );
}
// ------- COVER - OVER SHOOT BEHAVIOR -----------//


// ------- COVER - IDLE BEHAVIOR -----------//	
function private coverIdleInitialize( behaviorTreeEntity )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_ALERT_MODE );
}

function private coverIdleUpdate( behaviorTreeEntity )
{		
	if( !behaviorTreeEntity ASMIsTransitionRunning() )
	{
		AiUtility::releaseClaimNode( behaviorTreeEntity );
	}
}

function private coverIdleTerminate( behaviorTreeEntity )
{		
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
}
// ------- COVER - IDLE BEHAVIOR -----------//	


// ------- COVER - FLANKED BEHAVIOR ---------//	
function private isFlankedByEnemyAtCover( behaviorTreeEntity )
{
	return canBeFlanked( behaviorTreeEntity ) &&
		behaviorTreeEntity IsAtCoverNodeStrict() &&
		behaviorTreeEntity IsFlankedAtCoverNode() &&
		!behaviorTreeEntity HasPath();
}

function private canBeFlankedService( behaviorTreeEntity )
{
	AiUtility::setCanBeFlanked( behaviorTreeEntity, true );
}

function private coverFlankedInitialize( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.enemy ) )
	{
		// cheat and give perfect info about the close enemy, makes it feel like AI is smart :)
		behaviorTreeEntity GetPerfectInfo( behaviorTreeEntity.enemy );
		
		// Dont move for a few sec, this may trigger AI to charge melee attack
		behaviorTreeEntity PathMode( "move delayed", false, 2 );
	}
		
	setCanBeFlanked( behaviorTreeEntity, false );
	
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
}

function private coverFlankedActionTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity.newEnemyReaction = false;
	AiUtility::releaseClaimNode( behaviorTreeEntity );
}
// ------- COVER - FLANKED BEHAVIOR ---------//


// ------- COVER - COMMON CONDITIONS ---------//
#define NEAR_NODE_DIST_SQR SQR(24)
function isAtCrouchNode( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.node ) &&
		( NODE_EXPOSED( behaviorTreeEntity.node ) || NODE_GUARD( behaviorTreeEntity.node ) || NODE_PATH( behaviorTreeEntity.node ) ) )
	{
		if ( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.node.origin ) <= NEAR_NODE_DIST_SQR )
		{
			return !AiUtility::isStanceAllowedAtNode( STANCE_STAND, behaviorTreeEntity.node ) &&
				AiUtility::isStanceAllowedAtNode( STANCE_CROUCH, behaviorTreeEntity.node );
		}
	}
	
	return false;
}

function isAtCoverCondition( behaviorTreeEntity )
{
	return behaviorTreeEntity IsAtCoverNodeStrict() &&
		behaviorTreeEntity ShouldUseCoverNode() &&
		!behaviorTreeEntity HasPath();
}

function isAtCoverStrictCondition( behaviorTreeEntity )
{
	return behaviorTreeEntity IsAtCoverNodeStrict() &&
		!behaviorTreeEntity HasPath();
}

function isAtCoverModeOver( behaviorTreeEntity )
{
	coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );
	
	return coverMode == COVER_OVER_MODE;
}

function isAtCoverModeNone( behaviorTreeEntity )
{
	coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );
	
	return coverMode == COVER_MODE_NONE;
}

function isExposedAtCoverCondition( behaviorTreeEntity )
{
	return behaviorTreeEntity IsAtCoverNodeStrict() && !behaviorTreeEntity ShouldUseCoverNode();
}

function shouldCoverIdleOnly( behaviorTreeEntity )
{
	if( behaviorTreeEntity ai::get_behavior_attribute( "coverIdleOnly" ) )
	{
		return true;
	}
	
	if( IS_TRUE( behaviorTreeEntity.node.script_onlyidle ) )
	{
		return true;
	}
	
	return false;
}

function isSuppressedAtCoverCondition( behaviorTreeEntity )
{
	// TODO(David Young 9-6-13): Move this to code.
	return behaviorTreeEntity.suppressionMeter > behaviorTreeEntity.suppressionThreshold;
}

function keepClaimedNodeAndChooseCoverDirection( behaviorTreeEntity )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	chooseCoverDirection( behaviorTreeEntity );
}

function resetCoverParameters( behaviorTreeEntity )
{
	AiUtility::chooseFrontCoverDirection( behaviorTreeEntity );
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	
	AiUtility::clearCoverShootStartTime( behaviorTreeEntity );
}

function chooseCoverDirection( behaviorTreeEntity, stepOut )
{
	if ( !IsDefined( behaviorTreeEntity.node ) )
	{
		return;
	}
	
	coverDirection = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_DIRECTION );
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_DIRECTION, coverDirection );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_DIRECTION, calculateCoverDirection( behaviorTreeEntity, stepOut ) );
}

function calculateCoverDirection( behaviorTreeEntity, stepOut )
{
	if( IsDefined( behaviorTreeEntity.treatAllCoversAsGeneric ) )
	{
		if ( !IsDefined( stepOut ) )
		{
			stepOut = false;
		}
	
		coverDirection = COVER_FRONT_DIRECTION;
		
		if ( NODE_COVER_LEFT( behaviorTreeEntity.node ) )
		{
			if ( NODE_SUPPORTS_STANCE_STAND( behaviorTreeEntity.node ) || math::cointoss() || stepOut )
			{
				coverDirection = COVER_LEFT_DIRECTION;
			}
		}
		else if ( NODE_COVER_RIGHT( behaviorTreeEntity.node ) )
		{
			if ( NODE_SUPPORTS_STANCE_STAND( behaviorTreeEntity.node ) || math::cointoss() || stepOut )
			{
				coverDirection = COVER_RIGHT_DIRECTION;
			}
		}
		else if ( NODE_COVER_PILLAR( behaviorTreeEntity.node ) )
		{
			// must choose either left or right		
			if( ISNODEDONTLEFT( behaviorTreeEntity.node ) )
			{
				return COVER_RIGHT_DIRECTION;
			}
			
			if( ISNODEDONTRIGHT( behaviorTreeEntity.node ) )
			{
				return COVER_LEFT_DIRECTION;
			}
	
			coverDirection = COVER_LEFT_DIRECTION;
			
			if ( IsDefined( behaviorTreeEntity.enemy ) )
			{
				yawToEnemyPosition = AiUtility::GetAimYawToEnemyFromNode( behaviorTreeEntity, behaviorTreeEntity.node, behaviorTreeEntity.enemy );
				aimLimitsForDirectionRight = behaviorTreeEntity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_PILLAR_RIGHT_LEAN);
							
				legalRightDirectionYaw = yawToEnemyPosition >= ( aimLimitsForDirectionRight[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition <= 0;
				
				if ( legalRightDirectionYaw )
				{
					coverDirection = COVER_RIGHT_DIRECTION;
				}
			}
		}
		
		return coverDirection;
	}
	else
	{
		coverDirection = COVER_FRONT_DIRECTION;
		
		if ( NODE_COVER_PILLAR(behaviorTreeEntity.node) )
		{
			// must choose either left or right		
			if( ISNODEDONTLEFT( behaviorTreeEntity.node ) )
			{
				return COVER_RIGHT_DIRECTION;
			}
			
			if( ISNODEDONTRIGHT( behaviorTreeEntity.node ) )
			{
				return COVER_LEFT_DIRECTION;
			}
	
			coverDirection = COVER_LEFT_DIRECTION;
			
			if ( IsDefined( behaviorTreeEntity.enemy ) )
			{
				yawToEnemyPosition = AiUtility::GetAimYawToEnemyFromNode( behaviorTreeEntity, behaviorTreeEntity.node, behaviorTreeEntity.enemy );
				aimLimitsForDirectionRight = behaviorTreeEntity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_PILLAR_RIGHT_LEAN);
							
				legalRightDirectionYaw = yawToEnemyPosition >= ( aimLimitsForDirectionRight[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition <= 0;
				
				if ( legalRightDirectionYaw )
				{
					coverDirection = COVER_RIGHT_DIRECTION;
				}
			}
		}
	}
	
	return coverDirection;
}

function clearCoverShootStartTime( behaviorTreeEntity )
{
	behaviorTreeEntity.coverShootStartTime = undefined;
}

function setCoverShootStartTime( behaviorTreeEntity )
{
	behaviorTreeEntity.coverShootStartTime = GetTime();
}

function canBeFlanked( behaviorTreeEntity )
{
	return IsDefined( behaviorTreeEntity.canBeFlanked ) && behaviorTreeEntity.canBeFlanked;
}

function setCanBeFlanked( behaviorTreeEntity, canBeFlanked )
{
	behaviorTreeEntity.canBeFlanked = canBeFlanked;
}

function cleanupCoverMode( behaviorTreeEntity )
{
	if( isAtCoverCondition( behaviorTreeEntity ) )
	{
		coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );
		
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_MODE, coverMode );
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_MODE_NONE );
	}
	else
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_MODE, COVER_MODE_NONE );
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_MODE_NONE );
	}
}

// ------- COVER - COMMON CONDITIONS ---------//