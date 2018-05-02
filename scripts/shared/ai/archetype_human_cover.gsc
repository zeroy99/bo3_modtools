// COMMON AI SYSTEMS INCLUDES
#using scripts\shared\ai_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;

// ADDITIONAL INCLUDES
#using scripts\shared\ai\archetype_utility; 
#using scripts\shared\ai\archetype_cover_utility; 
#using scripts\shared\array_shared;
#using scripts\shared\laststand_shared;

#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

function autoexec RegisterBehaviorScriptfunctions()
{	
	BT_REGISTER_API( "shouldReturnToCoverCondition",		&shouldReturnToCoverCondition );
	BT_REGISTER_API( "shouldReturnToSuppressedCover",		&shouldReturnToSuppressedCover );
			
	BT_REGISTER_API( "shouldAdjustToCover",					&shouldAdjustToCover );
	BT_REGISTER_API( "prepareForAdjustToCover",				&prepareForAdjustToCover );
			
	BT_REGISTER_API( "coverBlindfireShootStart",			&coverBlindfireShootActionStart );
	
	BT_REGISTER_API( "canChangeStanceAtCoverCondition",		&canChangeStanceAtCoverCondition );
	BT_REGISTER_API( "coverChangeStanceActionStart",		&coverChangeStanceActionStart );
		
	BT_REGISTER_API( "prepareToChangeStanceToStand",		&prepareToChangeStanceToStand );
	BT_REGISTER_API( "cleanUpChangeStanceToStand",			&cleanUpChangeStanceToStand );

	BT_REGISTER_API( "prepareToChangeStanceToCrouch",		&prepareToChangeStanceToCrouch );
	BT_REGISTER_API( "cleanUpChangeStanceToCrouch",			&cleanUpChangeStanceToCrouch );

	BT_REGISTER_API( "shouldVantageAtCoverCondition",		&shouldVantageAtCoverCondition );
	BT_REGISTER_API( "supportsVantageCoverCondition",		&supportsVantageCoverCondition );
	BT_REGISTER_API( "coverVantageInitialize",				&coverVantageInitialize );
	
	BT_REGISTER_API( "shouldThrowGrenadeAtCoverCondition",	&shouldThrowGrenadeAtCoverCondition );
	BT_REGISTER_API( "coverPrepareToThrowGrenade",			&coverPrepareToThrowGrenade );
	BT_REGISTER_API( "coverCleanUpToThrowGrenade",			&coverCleanUpToThrowGrenade );
	
	BT_REGISTER_API( "senseNearbyPlayers",					&senseNearbyPlayers );
}

function shouldThrowGrenadeAtCoverCondition( behaviorTreeEntity, throwIfPossible = false )
{	
	// sjakatdar - Please do not use level.AIDisableGrenadeThrows, not a preferred method to disable grenades by script. Only used by campaign zombies.
	if( IS_TRUE(level.AIDisableGrenadeThrows) )
	{
		return false;
	}
	
	if( !IsDefined(  behaviorTreeEntity.enemy ) )
	{
		return false;
	}
	
	if ( !IsSentient( behaviorTreeEntity.enemy ) )
	{
		return false;
	}
	
	if ( IsVehicle( behaviorTreeEntity.enemy ) && behaviorTreeEntity.enemy.vehicleclass === "helicopter" )
	{
		return false;
	}
	
	if ( ai::HasAiAttribute( behaviorTreeEntity, "useGrenades" ) && !ai::GetAiAttribute( behaviorTreeEntity, "useGrenades" ) )
	{
		return false;
	}
	
	// Only throw a grenade if the enemy is within 60 degrees to the left or right of where the actor or the actor's node is facing.
	entityAngles = behaviorTreeEntity.angles;

	if ( IsDefined( behaviorTreeEntity.node ) &&
		NODE_TYPE_COVER( behaviorTreeEntity.node ) &&
		behaviorTreeEntity IsAtCoverNodeStrict() )
	{
		entityAngles = behaviorTreeEntity.node.angles;
	}
	
	toEnemy = behaviorTreeEntity.enemy.origin - behaviorTreeEntity.origin;
	toEnemy = VectorNormalize( ( toEnemy[0], toEnemy[1], 0 ) );
	
	entityForward = AnglesToForward( entityAngles );
	entityForward = VectorNormalize( ( entityForward[0], entityForward[1], 0 ) );
	
	// cos( 60 degrees ) = 0.5
	if ( VectorDot( toEnemy, entityForward ) < 0.5 )
	{
		return false;
	}
	
	if ( !throwIfPossible ) 
	{
		// Don't throw grenades at enemys that are next to players.
		if ( behaviorTreeEntity.team === "allies" )
		{
			foreach( player in level.players )
			{
				if( DistanceSquared( behaviorTreeEntity.enemy.origin, player.origin ) <= ALLIED_GRENADE_SAFE_DIST_SQ )
				{
					return false;
				}
			}
		}
		
		// Don't throw grenades at enemies that are close to laststand players.
		foreach( player in level.players )
		{
			if ( player laststand::player_is_in_laststand() &&
				DistanceSquared( behaviortreeentity.enemy.origin, player.origin ) <= LASTSTAND_GRENADE_SAFE_DIST_SQ )
			{
				return false;
			}
		}
	
		// if there was a grenade thrown by the same team recently, don't throw another one
		grenadeThrowInfos = Blackboard::GetBlackboardEvents( "team_grenade_throw" );
		foreach ( grenadeThrowInfo in grenadeThrowInfos )
		{
			if( grenadeThrowInfo.data.grenadeThrowerTeam === behaviorTreeEntity.team )
			{
				return false;
			}
		}
	
		// if there was a grenade that was thrown at the enemy recently, then dont throw it again
		grenadeThrowInfos = Blackboard::GetBlackboardEvents( "human_grenade_throw" );
		
		foreach ( grenadeThrowInfo in grenadeThrowInfos )
		{
			if( IsDefined( grenadeThrowInfo.data.grenadeThrownAt ) && IsAlive( grenadeThrowInfo.data.grenadeThrownAt ) )
			{
				if( grenadeThrowInfo.data.grenadeThrower == behaviorTreeEntity )
				{
					return false;
				}
			
				if( IsDefined( grenadeThrowInfo.data.grenadeThrownAt ) &&
					grenadeThrowInfo.data.grenadeThrownAt == behaviorTreeEntity.enemy )
				{
					return false;
				}
				
				if ( IsDefined( grenadeThrowInfo.data.grenadeThrownPosition ) &&
					IsDefined( behaviorTreeEntity.grenadeThrowPosition ) &&
					DistanceSquared( grenadeThrowInfo.data.grenadeThrownPosition, behaviorTreeEntity.grenadeThrowPosition ) <= GRENADE_OVERLAP_DIST_SQ )
				{
					// Prevent too many grenades in the same area.
					return false;
				}
			}
		}
	}
	
	throw_dist = Distance2DSquared( behaviorTreeEntity.origin, behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) );
	if ( throw_dist < MIN_GRENADE_THROW_DIST_SQ || throw_dist > MAX_GRENADE_THROW_DIST_SQ )
	{
		return false;
	}
	
	arm_offset = TEMP_get_arm_offset( behaviorTreeEntity, behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) );
	throw_vel = behaviorTreeEntity CanThrowGrenadePos( arm_offset, behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) );

	if ( !IsDefined( throw_vel ) )
	{
		return false;
	}
	
	return true;
}

#define SENSE_DISTANCE 360
#define SENSE_DISTANCE_SQ SQR(SENSE_DISTANCE)
function private senseNearbyPlayers( entity )
{
	players = GetPlayers();
	
	foreach ( player in players )
	{
		distanceSq = DistanceSquared( player.origin, entity.origin );
		
		if ( distanceSq <= SENSE_DISTANCE_SQ )
		{
			distanceToPlayer = Sqrt( distanceSq );
			
			chanceToDetect = RandomFloat( 1.0 );
			
			if ( chanceToDetect < ( distanceToPlayer / SENSE_DISTANCE ) )
			{
				entity GetPerfectInfo( player );
			}
		}
	}
}

function private coverPrepareToThrowGrenade( behaviorTreeEntity )
{	
	AiUtility::keepClaimedNodeAndChooseCoverDirection( behaviorTreeEntity );
	
	if ( IsDefined( behaviorTreeEntity.enemy ) )
	{
		behaviorTreeEntity.grenadeThrowPosition = behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy );
	}
	
	grenadeThrowInfo = SpawnStruct();
	grenadeThrowInfo.grenadeThrower = behaviorTreeEntity;
	grenadeThrowInfo.grenadeThrownAt = behaviorTreeEntity.enemy;
	grenadeThrowInfo.grenadeThrownPosition = behaviorTreeEntity.grenadeThrowPosition;
	Blackboard::AddBlackboardEvent( "human_grenade_throw", grenadeThrowInfo, RandomIntRange( MIN_GRENADE_THROW_TIME, MAX_GRENADE_THROW_TIME ) );
	
	grenadeThrowInfo = SpawnStruct();
	grenadeThrowInfo.grenadeThrowerTeam = behaviorTreeEntity.team;
	Blackboard::AddBlackboardEvent( "team_grenade_throw", grenadeThrowInfo, RandomIntRange( MIN_GRENADE_TEAM_TIME, MAX_GRENADE_TEAM_TIME ) );
	
	behaviorTreeEntity.prepareGrenadeAmmo = behaviorTreeEntity.grenadeammo;
}

function private coverCleanUpToThrowGrenade( behaviorTreeEntity )
{
	AiUtility::resetCoverParameters( behaviorTreeEntity );
	
	if ( behaviorTreeEntity.prepareGrenadeAmmo == behaviorTreeEntity.grenadeammo )
	{
		// Actor was killed before being able to drop a grenade, drop one instead.
		if ( behaviorTreeEntity.health <= 0 )
		{
			grenade = undefined;
		
			// Need someone living to spawn the dropped grenade, otherwise it cannot be picked up.
			if ( IsActor( behaviorTreeEntity.enemy ) && IsDefined( behaviorTreeEntity.grenadeweapon ) )
			{
				grenade = behaviorTreeEntity.enemy MagicGrenadeType(
					behaviorTreeEntity.grenadeweapon,
					behaviorTreeEntity GetTagOrigin( "j_wrist_ri" ),
					(0, 0, 0),
					behaviorTreeEntity.grenadeweapon.aifusetime / 1000 );
			}
			else if ( IsPlayer( behaviorTreeEntity.enemy ) && IsDefined( behaviorTreeEntity.grenadeweapon ) )
			{
				grenade = behaviorTreeEntity.enemy MagicGrenadePlayer(
					behaviorTreeEntity.grenadeweapon,
					behaviorTreeEntity GetTagOrigin( "j_wrist_ri" ),
					(0, 0, 0) );
			}
			
			if ( IsDefined( grenade ) )
			{
				grenade.owner = behaviorTreeEntity;
				grenade.team = behaviorTreeEntity.team;
				// Since the grenade is spawned so closely to the actor, disable collision against the actor.
				grenade SetContents( grenade SetContents( 0 ) & ~( CONTENTS_ACTOR | CONTENTS_CORPSE | CONTENTS_VEHICLE | CONTENTS_PLAYER ) );
			}
		}
	}
}

function private canChangeStanceAtCoverCondition( behaviorTreeEntity )
{
	switch ( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) )
	{
		case STANCE_STAND:
			return AiUtility::isStanceAllowedAtNode( STANCE_CROUCH, behaviorTreeEntity.node );
		case STANCE_CROUCH:
			return AiUtility::isStanceAllowedAtNode( STANCE_STAND, behaviorTreeEntity.node );
	}
	
	return false;
}

function private shouldReturnToSuppressedCover( entity )
{
	if ( !entity IsAtGoal() )
	{
		return true;
	}

	return false;
}

function private shouldReturnToCoverCondition( behaviorTreeEntity )
{
	if ( behaviorTreeEntity ASMIsTransitionRunning() )
	{
		return false;
	}
		
	if ( IsDefined( behaviorTreeEntity.coverShootStartTime ) )
	{
		// take a few shots before returning
		if ( GetTime() < behaviorTreeEntity.coverShootStartTime + COVER_SHOOT_MIN_TIME )
		{
			return false;
		}

		// try to finish off enemy
		if ( IsDefined( behaviorTreeEntity.enemy ) &&
			IsPlayer( behaviorTreeEntity.enemy ) &&
			behaviorTreeEntity.enemy.health < behaviorTreeEntity.enemy.maxHealth * 0.5 )
		{
			if ( GetTime() < behaviorTreeEntity.coverShootStartTime + COVER_SHOOT_TAKEDOWN_TIME )
			{
				return false;
			}
		}
	}
	
	if ( AiUtility::isSuppressedAtCoverCondition( behaviorTreeEntity ) )
	{
		return true;
	}
	
	if ( !behaviorTreeEntity IsAtGoal() )
	{
		// AI's that lean out of cover can fall outside of a very small goalradius, use the node's position instead.
		if ( IsDefined( behaviorTreeEntity.node ) )
		{
			offsetOrigin = behaviorTreeEntity GetNodeOffsetPosition( behaviorTreeEntity.node );
		
			return !behaviorTreeEntity IsPosAtGoal( offsetOrigin );
		}
		
		return true;
	}
	
	if ( !behaviorTreeEntity IsSafeFromGrenade() )
	{
		return true;
	}

	return false;
}

function private shouldAdjustToCover( behaviorTreeEntity ) 
{
	if( !IsDefined( behaviorTreeEntity.node ) )
	{
		return false;
	}
	
	// if the current stance is crouch, and highest supported stance for the node is crouch too then, 
	// there are no animations for that. Just do a pure animation blend.
	highestSupportedStance = AiUtility::getHighestNodeStance( behaviorTreeEntity.node );
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	
	if( currentStance == STANCE_CROUCH && highestSupportedStance == STANCE_CROUCH )
	{
		return false;
	}
	
	// if AI has just arrived at this cover node ( meaning previousCoverMode != COVER_ALERT_MODE )
	// That means he needs to adjust to the cover for the first time
	coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );
	previousCoverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_MODE );

	if ( coverMode != COVER_ALERT_MODE && previousCoverMode != COVER_ALERT_MODE && !behaviorTreeEntity.keepClaimedNode )
	{		
		return true;
	}

	// if somehow the AI is at the covernode with appropriate COVER_MODE, but unsupported stance, then 
	// let him adjust to the cover node.
	if( !AiUtility::isStanceAllowedAtNode( currentStance, behaviorTreeEntity.node ) )
	{
		return true;
	}
	
	return false;
}


// ------- COVER - VANTAGE SHOOT BEHAVIOR -----------//
// TODO - Fix and enable vantage behavior.
function private shouldVantageAtCoverCondition( behaviorTreeEntity )
{
	if( !IsDefined( behaviorTreeEntity.node ) ||
		!IsDefined( behaviorTreeEntity.node.type ) ||
		!IsDefined( behaviorTreeEntity.enemy) ||
		!IsDefined( behaviorTreeEntity.enemy.origin ) )
	{
		return false;
	}
		
	yawToEnemyPosition = AiUtility::GetAimYawToEnemyFromNode( behaviorTreeEntity, behaviorTreeEntity.node, behaviorTreeEntity.enemy );
	pitchToEnemyPosition = AiUtility::GetAimPitchToEnemyFromNode( behaviorTreeEntity, behaviorTreeEntity.node, behaviorTreeEntity.enemy );
	aimLimitsForCover = behaviortreeentity GetAimLimitsFromEntry(AIM_LIMIT_TABLE_ENTRY_COVER_VANTAGE);
	
	legalAim = false;

	// allow vantage aiming if our target is within the 25 to 85 degree arc in front of us and 3 or more feet below us
	if ( yawToEnemyPosition < aimLimitsForCover[AIM_LEFT] &&
		 yawToEnemyPosition > aimLimitsForCover[AIM_RIGHT] &&
		 pitchToEnemyPosition < 85.0 &&
		 pitchToEnemyPosition > 25.0 &&
		 ( behaviorTreeEntity.node.origin[2] - behaviorTreeEntity.enemy.origin[2] ) >= ( 3 * 12 ) )
	{
		legalAim = true;
	}

	return legalAim;
}

function private supportsVantageCoverCondition( behaviorTreeEntity )
{
	return false;
	
	/*
	coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );
	
	if ( IsDefined( behaviorTreeEntity.node ) && IsDefined( coverMode ) && coverMode == COVER_ALERT_MODE )
	{
		if( NODE_COVER_CROUCH( behaviorTreeEntity.node ) || NODE_COVER_STAND( behaviorTreeEntity.node ) )
		{
			return true;
		}			
	}
	
	return false;
	*/
}

function private coverVantageInitialize( behaviorTreeEntity, asmStateName )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_VANTAGE_MODE );
}
	
// ------- COVER - BLINDFIRE SHOOT BEHAVIOR -----------//
function private coverBlindfireShootActionStart( behaviorTreeEntity, asmStateName )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_BLIND_MODE );
	AiUtility::chooseCoverDirection( behaviorTreeEntity );
}

// ------- COVER - CHANGE STANCE BEHAVIOR -----------//
function private prepareToChangeStanceToStand( behaviorTreeEntity, asmStateName )
{
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
}

function private cleanUpChangeStanceToStand( behaviorTreeEntity, asmStateName )
{
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	behaviorTreeEntity.newEnemyReaction = false;
}

function private prepareToChangeStanceToCrouch( behaviorTreeEntity, asmStateName )
{
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_CROUCH );
}

function private cleanUpChangeStanceToCrouch( behaviorTreeEntity, asmStateName )
{
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	behaviorTreeEntity.newEnemyReaction = false;
}

// ------- COVER - ADJUST STANCE BEHAVIOR -----------//
function private prepareForAdjustToCover( behaviorTreeEntity, asmStateName )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	
	highestSupportedStance = AiUtility::getHighestNodeStance( behaviorTreeEntity.node );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, highestSupportedStance );
}

// ------- COVER - CHANGE STANCE BEHAVIOR -----------
function private coverChangeStanceActionStart( behaviorTreeEntity, asmStateName )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_ALERT_MODE );
	AiUtility::keepClaimNode( behaviorTreeEntity );

	switch ( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) )
	{
		case STANCE_STAND:
			Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_CROUCH );
			break;
		case STANCE_CROUCH:
			Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
			break;
	}
}

#define COVER_AIM_ANGLE_EPSILON 10

function TEMP_get_arm_offset( behaviorTreeEntity, throwPosition )
{
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	arm_offset = undefined;

	// ( forward/back, left/right, up/down )
	if ( stance == STANCE_CROUCH )
	{
		arm_offset = ( 13, -1, 56 );
	}
	else
	{
		arm_offset = ( 14, -3, 80 );
	}
	
	if( IsDefined( behaviorTreeEntity.node ) && behaviorTreeEntity IsAtCoverNodeStrict() )
	{
		if( NODE_COVER_LEFT(behaviorTreeEntity.node) )
		{
			if ( stance == STANCE_CROUCH )
			{
				arm_offset = ( -38, 15, 23 );
			}
			else
			{
				arm_offset = ( -45, 0, 40 );
			}
		}
		else if( NODE_COVER_RIGHT(behaviorTreeEntity.node) )
		{
			if ( stance == STANCE_CROUCH )
			{
				arm_offset = ( 46, 12, 26 );
			}
			else
			{
				arm_offset = ( 34, -21, 50 );
			}
		}
		else if( NODE_COVER_STAND(behaviorTreeEntity.node) )
		{
			arm_offset = ( 10, 7, 77 );
		}
		else if( NODE_COVER_CROUCH(behaviorTreeEntity.node) )
		{
			arm_offset = ( 19, 5, 60 );
		}
		else if( NODE_COVER_PILLAR(behaviorTreeEntity.node) )
		{
			leftOffset = undefined;
			rightOffset = undefined;
		
			if ( stance == STANCE_CROUCH )
			{
				leftOffset = ( -20, 0, 35 );
				rightOffset = ( 34, 6, 50 );
			}
			else
			{
				leftOffset = ( -24, 0, 76 );
				rightOffset = ( 24, 0, 76 );
			}
		
			if( ISNODEDONTLEFT( behaviorTreeEntity.node ) )
			{
				arm_offset = rightOffset;
			}
			else if( ISNODEDONTRIGHT( behaviorTreeEntity.node ) )
			{
				arm_offset = leftOffset;
			}
			else
			{
				yawToEnemyPosition = AngleClamp180( VectorToAngles( throwPosition - behaviorTreeEntity.node.origin )[1] - behaviorTreeEntity.node.angles[1] );
				aimLimitsForDirectionRight = behaviortreeentity GetAimLimitsFromEntry( AIM_LIMIT_TABLE_ENTRY_PILLAR_RIGHT_LEAN );
				
				legalRightDirectionYaw = yawToEnemyPosition >= ( aimLimitsForDirectionRight[AIM_RIGHT] - COVER_AIM_ANGLE_EPSILON ) && yawToEnemyPosition <= 0;
				
				if( legalRightDirectionYaw )
				{
					arm_offset = rightOffset;
				}
				else
				{
					arm_offset = leftOffset;
				}
			}
		}
	}

	return arm_offset;
}
