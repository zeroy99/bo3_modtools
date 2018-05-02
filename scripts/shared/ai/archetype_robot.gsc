#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;

#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_mocomps_utility;
#using scripts\shared\ai\archetype_robot_interface;
#using scripts\shared\ai\archetype_utility;

#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\ai_squads;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\systems\shared;

#using scripts\shared\vehicles\_raps;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

REGISTER_SYSTEM( "robot", &__init__, undefined )

function __init__()
{
	// INIT BLACKBOARD
	spawner::add_archetype_spawn_function( ARCHETYPE_ROBOT, &RobotSoldierBehavior::ArchetypeRobotBlackboardInit );
	
	// INIT ROBOT ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_ROBOT, &RobotSoldierServerUtils::robotSoldierSpawnSetup );
	
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_ROBOT ) )
	{		
		clientfield::register(
			"actor",
			ROBOT_MIND_CONTROL_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_MIND_CONTROL_BITS,
			ROBOT_MIND_CONTROL_TYPE );
		
		clientfield::register(
			"actor",
			ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_MIND_CONTROL_EXPLOSION_BITS,
			ROBOT_MIND_CONTROL_EXPLOSION_TYPE );
			
		clientfield::register(
			"actor",
			ROBOT_LIGHTS_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_LIGHTS_BITS,
			ROBOT_LIGHTS_TYPE );
			
		clientfield::register(
			"actor",
			ROBOT_EMP_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_EMP_BITS,
			ROBOT_EMP_TYPE );
	}
	
	RobotInterface::RegisterRobotInterfaceAttributes();
	RobotSoldierBehavior::RegisterBehaviorScriptFunctions();
}

#namespace RobotSoldierBehavior;

function RegisterBehaviorScriptFunctions()
{
	// ------- ROBOT ACTIONS -----------//
	BT_REGISTER_ACTION( "robotStepIntoAction",			&stepIntoInitialize,		undefined,					&stepIntoTerminate );
	BT_REGISTER_ACTION( "robotStepOutAction",			&stepOutInitialize,			undefined,					&stepOutTerminate );
	BT_REGISTER_ACTION( "robotTakeOverAction",			&takeOverInitialize,		undefined,					&takeOverTerminate );
	BT_REGISTER_ACTION( "robotEmpIdleAction",			&robotEmpIdleInitialize,	&robotEmpIdleUpdate, 		&robotEmpIdleTerminate );

	// ------- ROBOT ACTION APIS ----------//
	BT_REGISTER_API( "robotBecomeCrawler",				&robotBecomeCrawler );
	BT_REGISTER_API( "robotDropStartingWeapon",			&robotDropStartingWeapon );
	BT_REGISTER_API( "robotDontTakeCover",				&robotDontTakeCover );
	BT_REGISTER_API( "robotCoverOverInitialize",		&robotCoverOverInitialize );
	BT_REGISTER_API( "robotCoverOverTerminate",			&robotCoverOverTerminate );
	BT_REGISTER_API( "robotExplode",					&robotExplode );
	BT_REGISTER_API( "robotExplodeTerminate",			&robotExplodeTerminate );
	BT_REGISTER_API( "robotDeployMiniRaps",				&robotDeployMiniRaps );
	BT_REGISTER_API( "robotMoveToPlayer",				&moveToPlayerUpdate );
	BT_REGISTER_API( "robotStartSprint",				&robotStartSprint );
	BSM_REGISTER_API( "robotStartSprint",				&robotStartSprint );
	BT_REGISTER_API( "robotStartSuperSprint",			&robotStartSuperSprint );
	BT_REGISTER_API( "robotTacticalWalkActionStart",	&robotTacticalWalkActionStart );
	BSM_REGISTER_API( "robotTacticalWalkActionStart",	&robotTacticalWalkActionStart );
	BT_REGISTER_API( "robotDie",						&robotDie );
	BT_REGISTER_API( "robotCleanupChargeMeleeAttack",	&robotCleanupChargeMeleeAttack );
	
	// ------- ROBOT CONDITIONS -----------//
	BT_REGISTER_API( "robotIsMoving",					&robotIsMoving );
	BT_REGISTER_API( "robotAbleToShoot",				&robotAbleToShootCondition );
	BT_REGISTER_API( "robotCrawlerCanShootEnemy",		&robotCrawlerCanShootEnemy );
	BT_REGISTER_API( "canMoveToEnemy",					&canMoveToEnemyCondition );
	BT_REGISTER_API( "canMoveCloseToEnemy",				&canMoveCloseToEnemyCondition );
	BT_REGISTER_API( "hasMiniRaps",						&hasMiniRaps );
	BT_REGISTER_API( "robotIsAtCover",					&robotIsAtCoverCondition );
	BT_REGISTER_API( "robotShouldTacticalWalk",			&robotShouldTacticalWalk );
	BT_REGISTER_API( "robotHasCloseEnemyToMelee",		&robotHasCloseEnemyToMelee );
	BT_REGISTER_API( "robotHasEnemyToMelee",			&robotHasEnemyToMelee );
	BT_REGISTER_API( "robotRogueHasCloseEnemyToMelee",	&robotRogueHasCloseEnemyToMelee );
	BT_REGISTER_API( "robotRogueHasEnemyToMelee",		&robotRogueHasEnemyToMelee );
	BT_REGISTER_API( "robotIsCrawler",					&robotIsCrawler );
	BT_REGISTER_API( "robotIsMarching",					&robotIsMarching );
	BT_REGISTER_API( "robotPrepareForAdjustToCover",	&robotPrepareForAdjustToCover );
	BT_REGISTER_API( "robotShouldAdjustToCover",		&robotShouldAdjustToCover );
	BT_REGISTER_API( "robotShouldBecomeCrawler",		&robotShouldBecomeCrawler );
	BT_REGISTER_API( "robotShouldReactAtCover",			&robotShouldReactAtCover );
	BT_REGISTER_API( "robotShouldExplode",				&robotShouldExplode );
	BT_REGISTER_API( "robotShouldShutdown",				&robotShouldShutdown );
	BT_REGISTER_API( "robotSupportsOverCover",			&robotSupportsOverCover );
	BT_REGISTER_API( "shouldStepIn",					&shouldStepInCondition );
	BT_REGISTER_API( "shouldTakeOver",					&shouldTakeOverCondition );
	BT_REGISTER_API( "supportsStepOut",					&supportsStepOutCondition );
	BT_REGISTER_API( "setDesiredStanceToStand",			&setDesiredStanceToStand );
	BT_REGISTER_API( "setDesiredStanceToCrouch",		&setDesiredStanceToCrouch );
	BT_REGISTER_API( "toggleDesiredStance",				&toggleDesiredStance );
	BT_REGISTER_API( "robotMovement",					&robotMovement );
	BT_REGISTER_API( "robotDelayMovement",				&robotDelayMovement );
	BT_REGISTER_API( "robotInvalidateCover",			&robotInvalidateCover );
	BT_REGISTER_API( "robotShouldChargeMelee",			&robotShouldChargeMelee );
	BT_REGISTER_API( "robotShouldMelee",				&robotShouldMelee );
	BT_REGISTER_API( "robotScriptRequiresToSprint",		&scriptRequiresToSprintCondition );
	BT_REGISTER_API( "robotScanExposedPainTerminate",	&robotScanExposedPainTerminate );
	BT_REGISTER_API( "robotTookEmpDamage",				&robotTookEmpDamage );
	BT_REGISTER_API( "robotNoCloseEnemyService",		&robotNoCloseEnemyService );
	
	BT_REGISTER_API( "robotWithinSprintRange",			&robotWithinSprintRange );
	BT_REGISTER_API( "robotWithinSuperSprintRange",		&robotWithinSuperSprintRange );
	BSM_REGISTER_API( "robotWithinSuperSprintRange",	&robotWithinSuperSprintRange );
	BT_REGISTER_API( "robotOutsideTacticalWalkRange",	&robotOutsideTacticalWalkRange );
	BT_REGISTER_API( "robotOutsideSprintRange",			&robotOutsideSprintRange );
	BT_REGISTER_API( "robotOutsideSuperSprintRange",	&robotOutsideSuperSprintRange );
	BSM_REGISTER_API( "robotOutsideSuperSprintRange",	&robotOutsideSuperSprintRange );
	
	BT_REGISTER_API( "robotLightsOff",					&robotLightsOff );
	BT_REGISTER_API( "robotLightsFlicker",				&robotLightsFlicker );
	BT_REGISTER_API( "robotLightsOn",					&robotLightsOn );
	
	BT_REGISTER_API( "robotShouldGibDeath",				&robotShouldGibDeath );
	
	// ------- ROBOT - PROCEDURAL TRAVERSE BEHAVIOR -----------//
	BT_REGISTER_ACTION( "robotProceduralTraversal",		&robotTraverseStart, &robotProceduralTraversalUpdate, &robotTraverseRagdollOnDeath );
	BT_REGISTER_API( "robotCalcProceduralTraversal",	&robotCalcProceduralTraversal );
	BT_REGISTER_API( "robotProceduralLanding",			&robotProceduralLandingUpdate );
	BT_REGISTER_API( "robotTraverseEnd",				&robotTraverseEnd );
	BT_REGISTER_API( "robotTraverseRagdollOnDeath",		&robotTraverseRagdollOnDeath );
	BT_REGISTER_API( "robotShouldProceduralTraverse",	&robotShouldProceduralTraverse );
	BT_REGISTER_API( "robotWallrunTraverse",			&robotWallrunTraverse );
	BT_REGISTER_API( "robotShouldWallrun",				&robotShouldWallrun );
	BT_REGISTER_API( "robotSetupWallRunJump",			&robotSetupWallRunJump );
	BT_REGISTER_API( "robotSetupWallRunLand",			&robotSetupWallRunLand );
	BT_REGISTER_API( "robotWallrunStart",				&robotWallrunStart );
	BT_REGISTER_API( "robotWallrunEnd",					&robotWallrunEnd );
	
	// ------- ROBOT - JUKE BEHAVIOR -----------//
	BT_REGISTER_API( "robotCanJuke",					&robotCanJuke );
	BT_REGISTER_API( "robotCanTacticalJuke",			&robotCanTacticalJuke );
	BT_REGISTER_API( "robotCanPreemptiveJuke",			&robotCanPreemptiveJuke );
	BT_REGISTER_API( "robotJukeInitialize",				&robotJukeInitialize );
	BT_REGISTER_API( "robotPreemptiveJukeTerminate",	&robotPreemptiveJukeTerminate );
	
	// ------- ROBOT - COVER SCAN BEHAVIOR -----------//
	BT_REGISTER_API( "robotCoverScanInitialize",		&robotCoverScanInitialize );
	BT_REGISTER_API( "robotCoverScanTerminate",			&robotCoverScanTerminate );
	BT_REGISTER_API( "robotIsAtCoverModeScan",			&robotIsAtCoverModeScan );
	
	// ------- ROBOT SERVICES -----------//
	BT_REGISTER_API( "robotExposedCoverService",		&robotExposedCoverService );
	BT_REGISTER_API( "robotPositionService",			&robotPositionService );
	BT_REGISTER_API( "robotTargetService",				&robotTargetService );
	BT_REGISTER_API( "robotTryReacquireService",		&robotTryReacquireService );
	BT_REGISTER_API( "robotRushEnemyService",			&robotRushEnemyService );
	BT_REGISTER_API( "robotRushNeighborService",		&robotRushNeighborService );
	BT_REGISTER_API( "robotCrawlerService",				&robotCrawlerService );
	BT_REGISTER_API( "robotMoveToPlayerService",		&moveToPlayerUpdate );
	
	// ------- ROBOT MOCOMPS -----------//
	ASM_REGISTER_MOCOMP( "mocomp_ignore_pain_face_enemy", &mocompIgnorePainFaceEnemyInit, &mocompIgnorePainFaceEnemyUpdate, &mocompIgnorePainFaceEnemyTerminate );
	ASM_REGISTER_MOCOMP( "robot_procedural_traversal", &mocompRobotProceduralTraversalInit, &mocompRobotProceduralTraversalUpdate, &mocompRobotProceduralTraversalTerminate);
	ASM_REGISTER_MOCOMP( "robot_start_traversal", &mocompRobotStartTraversalInit, undefined, &mocompRobotStartTraversalTerminate );
	ASM_REGISTER_MOCOMP( "robot_start_wallrun", &mocompRobotStartWallrunInit, &mocompRobotStartWallrunUpdate, &mocompRobotStartWallrunTerminate );
}

function robotCleanupChargeMeleeAttack( behaviorTreeEntity )
{
	AiUtility::meleeReleaseMutex( behaviorTreeEntity );
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, undefined);
}

function private robotLightsOff( entity, asmStateName )
{
	entity ai::set_behavior_attribute( "robot_lights", ROBOT_LIGHTS_OFF );
	
	clientfield::set( ROBOT_EMP_CLIENTFIELD, ROBOT_EMP_ON );

	return BHTN_SUCCESS;
}

function private robotLightsFlicker( entity, asmStateName )
{
	entity ai::set_behavior_attribute( "robot_lights", ROBOT_LIGHTS_FLICKER );

	clientfield::set( ROBOT_EMP_CLIENTFIELD, ROBOT_EMP_ON );
	
	entity notify( "emp_fx_start" );

	return BHTN_SUCCESS;
}

function private robotLightsOn( entity, asmStateName )
{
	entity ai::set_behavior_attribute( "robot_lights", ROBOT_LIGHTS_ON );
	
	clientfield::set( ROBOT_EMP_CLIENTFIELD, ROBOT_EMP_OFF );

	return BHTN_SUCCESS;
}

function private robotShouldGibDeath( entity, asmStateName )
{
	return entity.gibDeath;
}

function private robotEmpIdleInitialize( entity, asmStateName )
{
	entity.empStopTime = GetTime() + entity.empShutdownTime;
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	
	entity notify( "emp_shutdown_start" );
	
	return BHTN_RUNNING;
}

function private robotEmpIdleUpdate( entity, asmStateName )
{
	if ( GetTime() < entity.empStopTime || entity ai::get_behavior_attribute( "shutdown" ) )
	{
		if ( entity ASMGetStatus() == ASM_STATE_COMPLETE )
		{
			// Loop the idle animation until enough time has passed.
			AnimationStateNetworkUtility::RequestState( entity, asmStateName );
		}
	
		return BHTN_RUNNING;
	}
	
	return BHTN_SUCCESS;
}

function private robotEmpIdleTerminate( entity, asmStateName )
{
	entity notify( "emp_shutdown_end" );

	return BHTN_SUCCESS;
}

function robotProceduralTraversalUpdate( entity, asmStateName )
{
	assert( IsDefined( entity.traversal ) );

	traversal = entity.traversal;

	t = min( ( GetTime() - traversal.startTime ) / traversal.totalTime, 1 );
	curveRemaining = traversal.curveLength * ( 1 - t );

	if ( curveRemaining < traversal.landingDistance )
	{
		traversal.landing = true;
		return BHTN_SUCCESS;
	}

	return BHTN_RUNNING;
}

function robotProceduralLandingUpdate( entity, asmStateName )
{
	if ( IsDefined( entity.traversal ) )
	{
		entity Finishtraversal();
	}

	return BHTN_RUNNING;
}

function robotCalcProceduralTraversal( entity, asmStateName )
{
	if ( !IsDefined( entity.traverseStartNode ) ||
		!IsDefined( entity.traverseEndNode ) )
	{
		return true;
	}

	entity.traversal = SpawnStruct();
	
	traversal = entity.traversal;
	
	// Static data
	traversal.landingDistance = 24;  // Inches
	traversal.minimumSpeed = 18;  // Feet
	
	traversal.startNode = entity.traverseStartNode;
	traversal.endNode = entity.traverseEndNode;
	
	startIsWallrun = traversal.startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	endIsWallrun = traversal.endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	
	// Bezier start and end points
	traversal.startPoint1 = entity.origin;
	traversal.endPoint1 = traversal.endNode.origin;
	
	if ( endIsWallrun )
	{
		// Find the offset point from the wall to jump to, this prevents the AI from clipping during landings.
		faceNormal = GetNavMeshFaceNormal( traversal.endPoint1, 30 );
		traversal.endPoint1 += faceNormal * ROBOT_DIAMETER / 2;
	}
	
	if ( !IsDefined( traversal.endPoint1 ) )
	{
		// This indicates the end node is way off the navmesh.
		traversal.endPoint1 = traversal.endNode.origin;
	}
	
	traversal.distanceToEnd = Distance( traversal.startPoint1, traversal.endPoint1 );
	traversal.absHeightToEnd = Abs( traversal.startPoint1[2] - traversal.endPoint1[2] );
	traversal.absLengthToEnd = Distance2D( traversal.startPoint1, traversal.endPoint1 );
	
	// Calculate approximate speed.  Longer traversals require faster movement.
	speedBoost = 0;
	
	if ( traversal.absLengthToEnd > 200 )
	{
		speedBoost = 16;
	}
	else if ( traversal.absLengthToEnd > 120 )
	{
		speedBoost = 8;
	}
	else if ( traversal.absLengthToEnd > 80 || traversal.absHeightToEnd > 80 )
	{
		speedBoost = 4;
	}

	if ( IsDefined( entity.traversalSpeedBoost ) )
	{
		speedBoost = entity [[ entity.traversalSpeedBoost ]]();
	}
	
	traversal.speedOnCurve = ( traversal.minimumSpeed + speedBoost ) * 12;  // Inches per second
	// End of speed calculations
	
	// Bezier control points
	heightOffset = max( traversal.absHeightToEnd * 0.8, min( traversal.absLengthToEnd, 96 ) );
	
	traversal.startPoint2 = entity.origin + ( 0, 0, heightOffset );
	traversal.endPoint2 = traversal.endPoint1 + ( 0, 0, heightOffset );
	
	// Adjust the lower control point to make a symmetric curve.
	if ( traversal.startPoint1[2] < traversal.endPoint1[2] )
	{
		traversal.startPoint2 += ( 0, 0, traversal.absHeightToEnd );
	}
	else
	{
		traversal.endPoint2 += ( 0, 0, traversal.absHeightToEnd );
	}
	
	// Wallrun traversals may jump directly off or onto the wall, adjust bezier control points.
	if ( startIsWallrun || endIsWallrun )
	{
		startDirection = robotStartJumpDirection();
		endDirection = robotEndJumpDirection();
		
		if ( startDirection == "out" )
		{
			point2Scale = 0.5;
			towardEnd = ( traversal.endNode.origin - entity.origin ) * point2Scale;
		
			traversal.startPoint2 = entity.origin + ( towardEnd[0], towardEnd[1], 0 );
			traversal.endPoint2 = traversal.endPoint1 + ( 0, 0, traversal.absHeightToEnd * point2Scale );
			
			traversal.angles = entity.angles;
		}
		
		if ( endDirection == "in" )
		{
			point2Scale = 0.5;
			towardStart = ( entity.origin - traversal.endNode.origin ) * point2Scale;
		
			traversal.startPoint2 = entity.origin + ( 0, 0, traversal.absHeightToEnd * point2Scale );
			traversal.endPoint2 = traversal.endNode.origin + ( towardStart[0], towardStart[1], 0 );
			
			faceNormal = GetNavMeshFaceNormal( traversal.endNode.origin, 30 );
			direction = _CalculateWallrunDirection( traversal.startNode.origin, traversal.endNode.origin );
			moveDirection = VectorCross( faceNormal, ( 0, 0, 1 ) );
			
			if ( direction == "right" )
			{
				moveDirection = -moveDirection;
			}
			
			traversal.angles = VectortoAngles( moveDirection );
		}
		
				// These are animation specific, and speed specific.
		if ( endIsWallrun )
		{
			traversal.landingDistance = 110;
		}
		else
		{
			traversal.landingDistance = 60;
		}
		
		// Wallruns require faster movement.
		traversal.speedOnCurve *= 1.2;
	}
	
	/#
	// Draw Bezier control point extents.
	RecordLine( traversal.startPoint1, traversal.startPoint2, ORANGE, "Animscript", entity );
	RecordLine( traversal.startPoint1, traversal.endPoint1, ORANGE, "Animscript", entity );
	RecordLine( traversal.endPoint1, traversal.endPoint2, ORANGE, "Animscript", entity );
	RecordLine( traversal.startPoint2, traversal.endPoint2, ORANGE, "Animscript", entity );
	
	Record3DText( traversal.absLengthToEnd, traversal.endPoint1 + (0, 0, 12), ORANGE, "Animscript", entity );
	#/
	
	// Calculate an approximate length of the curve.
	segments = 10;
	previousPoint = traversal.startPoint1;
	traversal.curveLength = 0;
	
	for ( index = 1; index <= segments; index++ )
	{
		t = index / segments;
		
		nextPoint = CalculateCubicBezier( t, traversal.startPoint1, traversal.startPoint2, traversal.endPoint2, traversal.endPoint1 );
		
		/#
		recordLine( previousPoint, nextPoint, GREEN, "Animscript", entity );
		#/
		
		traversal.curveLength += Distance( previousPoint, nextPoint );
		
		previousPoint = nextPoint;
	}
	
	// Traversal time based on speed.
	traversal.startTime = GetTime();
	traversal.endTime = traversal.startTime + traversal.curveLength * ( 1000 / traversal.speedOnCurve );
	traversal.totalTime = traversal.endTime - traversal.startTime;
	
	traversal.landing = false;
	
	return true;
}

function robotTraverseStart( entity, asmStateName )
{
	entity.skipdeath = true;
	
	// Reset the traversal timings after playing a jump animation.
	traversal = entity.traversal;
	
	traversal.startTime = GetTime();
	traversal.endTime = traversal.startTime + traversal.curveLength * ( 1000 / traversal.speedOnCurve );
	traversal.totalTime = traversal.endTime - traversal.startTime;
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	
	return BHTN_RUNNING;
}

function robotTraverseEnd( entity )
{
	robotTraverseRagdollOnDeath( entity );

	entity.skipdeath = false;
	entity.traversal = undefined;
	
	entity notify( "traverse_end" );
	
	return BHTN_SUCCESS;
}

function private robotTraverseRagdollOnDeath( entity, asmStateName )
{
	if ( !IsAlive( entity ) )
	{
		entity StartRagdoll();
	}
	
	return BHTN_SUCCESS;
}

function private robotShouldProceduralTraverse( entity )
{
	if ( IsDefined( entity.traverseStartNode ) && IsDefined( entity.traverseEndNode ) )
	{
		isProcedural = entity ai::get_behavior_attribute( "traversals" ) == "procedural" ||
			entity.traverseStartNode.spawnflags & SPAWNFLAG_PATH_PROCEDURAL ||
			entity.traverseEndNode.spawnflags & SPAWNFLAG_PATH_PROCEDURAL;
		
		return isProcedural;
	}

	return false;
}

function private robotWallrunTraverse( entity )
{
	startNode = entity.traverseStartNode;
	endNode = entity.traverseEndNode;
	
	if ( IsDefined( startNode ) &&
		IsDefineD( endNode ) &&
		entity ShouldStartTraversal() )
	{
		startIsWallrun = startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		endIsWallrun = endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	
		return startIsWallrun || endIsWallrun;
	}

	return false;
}

function private robotShouldWallrun( entity )
{
	return Blackboard::GetBlackBoardAttribute( entity, ROBOT_TRAVERSAL_TYPE ) == "wall";
}

function private mocompRobotStartWallrunInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity SetRepairPaths( false );
	entity OrientMode( "face angle", entity.angles[1] );
	entity.blockingPain = true;
	entity.clampToNavMesh = false;
	
	// entity OrientMode( "face motion" );
	entity AnimMode( AI_ANIM_MOVE_CODE_NOGRAVITY, false );
	entity SetAvoidanceMask( "avoid none" );
}

function private mocompRobotStartWallrunUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	faceNormal = GetNavMeshFaceNormal( entity.origin, 30 );
	positionOnWall = GetClosestPointOnNavMesh( entity.origin, 30, 0 );
	direction = Blackboard::GetBlackBoardAttribute( entity, ROBOT_WALLRUN_DIRECTION );
	
	if ( IsDefined( faceNormal ) && IsDefined( positionOnWall ) )
	{
		// Ignore any slank in the face normal.
		faceNormal = ( faceNormal[0], faceNormal[1], 0 );
		faceNormal = VectorNormalize( faceNormal );
		
		moveDirection = VectorCross( faceNormal, ( 0, 0, 1 ) );
		
		if ( direction == "right" )
		{
			moveDirection = -moveDirection;
		}
		
		forwardPositionOnWall = GetClosestPointOnNavMesh( positionOnWall + moveDirection * 12, 30, 0 );
		
		anglesToEnd = VectortoAngles( forwardPositionOnWall - positionOnWall );
		
		/# recordLine( positionOnWall, forwardPositionOnWall, RED, "Animscript", entity ); #/
		
		entity OrientMode( "face angle", anglesToEnd[1] );
	}
}

function private mocompRobotStartWallrunTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity SetRepairPaths( true );
	entity SetAvoidanceMask( "avoid all" );
	entity.blockingPain = false;
	entity.clampToNavMesh = true;
}

function private CalculateCubicBezier( t, p1, p2, p3, p4 )
{
	return pow( 1 - t, 3 ) * p1 +
		3 * pow( 1 - t, 2 ) * t * p2 +
		3 * ( 1 - t ) * pow( t, 2 ) * p3 +
		pow( t, 3 ) * p4;
}

function private mocompRobotStartTraversalInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	startNode = entity.traverseStartNode;
	startIsWallrun = startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	endNode = entity.traverseEndNode;
	endIsWallrun = endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	
	if ( !endIsWallrun )
	{
		angleToEnd = VectortoAngles( entity.traverseEndNode.origin - entity.traverseStartNode.origin );
		entity OrientMode( "face angle", angleToEnd[1] );
		
		if ( startIsWallrun )
		{
			entity AnimMode( AI_ANIM_MOVE_CODE_NOGRAVITY, false );
		}
		else
		{
			entity AnimMode( AI_ANIM_USE_BOTH_DELTAS, false );
		}
	}
	else
	{
		// Orient toward the direction of the movement along the wall.
		faceNormal = GetNavMeshFaceNormal( endNode.origin, 30 );
		direction = _CalculateWallrunDirection( startNode.origin, endNode.origin );
		moveDirection = VectorCross( faceNormal, ( 0, 0, 1 ) );
		
		if ( direction == "right" )
		{
			moveDirection = -moveDirection;
		}
		
		/# recordLine( endNode.origin, endNode.origin + faceNormal * 20, RED,  "Animscript", entity ); #/
		/# recordLine( endNode.origin, endNode.origin + moveDirection * 20, RED, "Animscript", entity ); #/
		
		angles = VectortoAngles( moveDirection );
		entity OrientMode( "face angle", angles[1] );
		
		if ( startIsWallrun )
		{
			entity AnimMode( AI_ANIM_MOVE_CODE_NOGRAVITY, false );
		}
		else
		{
			entity AnimMode( AI_ANIM_USE_BOTH_DELTAS, false );
		}
	}
	
	entity SetRepairPaths( false );
	entity.blockingPain = true;
	entity.clampToNavMesh = false;
	
	entity PathMode( "dont move" );
}

function private mocompRobotStartTraversalTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
}

function private mocompRobotProceduralTraversalInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	traversal = entity.traversal;

	entity SetAvoidanceMask( "avoid none" );
	entity OrientMode( "face angle", entity.angles[1] );
	entity SetRepairPaths( false );
	
	// Initial jump can noclip.
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity.blockingPain = true;
	entity.clampToNavMesh = false;
	
	if ( IsDefined( traversal ) && traversal.landing )
	{
		// Traversal is still going on, and we're landing.
		entity AnimMode( AI_ANIM_USE_ANGLE_DELTAS, false );
	}
}

function private mocompRobotProceduralTraversalUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	traversal = entity.traversal;
	
	if ( IsDefined( traversal ) )
	{
		if ( entity IsPaused() )
		{
			traversal.startTime += SERVER_FRAME * 1000;
			return;
		}
	
		endIsWallrun = traversal.endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		realT = ( GetTime() - traversal.startTime ) / traversal.totalTime;
		t = min( realT, 1 );
		
		if ( t < 1.0 || realT == 1.0 || !endIsWallrun )
		{
			currentPos = CalculateCubicBezier( t, traversal.startPoint1, traversal.startPoint2, traversal.endPoint2, traversal.endPoint1 );
			
			angles = entity.angles;
			
			if ( IsDefined( traversal.angles ) )
			{
				angles = traversal.angles;
			}
			
			// TODO(David Young 3-5-15): Convert to anim mode eventually.
			entity ForceTeleport( currentPos, angles, false );
		}
		else
		{
			entity AnimMode( AI_ANIM_MOVE_CODE_NOGRAVITY, false );
		}
	}
}

function private mocompRobotProceduralTraversalTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	traversal = entity.traversal;
	
	if ( IsDefined( traversal ) && GetTime() >= traversal.endTime )
	{
		// entity ForceTeleport( traversal.endPoint1, entity.angles, false );
		
		endIsWallrun = traversal.endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		
		if ( !endIsWallrun )
		{
			// Landed on the ground, allow repathing.
			entity PathMode( "move allowed" );
		}
	}
	
	entity.clampToNavMesh = true;
	entity.blockingPain = false;
	entity SetRepairPaths( true );
	entity SetAvoidanceMask( "avoid all" );
}

function private mocompIgnorePainFaceEnemyInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingpain = true;
	
	if ( IsDefined( entity.enemy ) )
	{
		entity OrientMode( "face enemy" );
	}
	else
	{
		entity OrientMode( "face angle", entity.angles[1] );
	}
	
	entity AnimMode( AI_ANIM_USE_POS_DELTAS );
}

function private mocompIgnorePainFaceEnemyUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if ( IsDefined( entity.enemy ) && entity GetAnimTime( mocompAnim ) < 0.5 )
	{
		entity OrientMode( "face enemy" );
	}
	else
	{
		entity OrientMode( "face angle", entity.angles[1] );
	}
}

function private mocompIgnorePainFaceEnemyTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingpain = false;
}

function private _CalculateWallrunDirection( startPosition, endPosition )
{
	entity = self;

	faceNormal = GetNavMeshFaceNormal( endPosition, 30 );

	/# recordLine( startPosition, endPosition, ORANGE, "Animscript", entity ); #/

	if ( IsDefined( faceNormal ) )
	{
		/# recordLine( endPosition, endPosition + faceNormal * 12, ORANGE, "Animscript", entity ); #/
	
		angles = VectorToAngles( faceNormal );
		right = AnglesToRight( angles );
		
		d = -VectorDot( right, endPosition );
		
		if ( VectorDot( right, startPosition ) + d > 0 )
		{
			return "right";
		}
		
		return "left";
	}
	
	return "unknown";
}

function private robotWallrunStart()
{
	entity = self;
	entity.skipdeath = true;
	
	entity PushActors( false );
	entity PushPlayer( true );
	entity.pushable = false;
}

function private robotWallrunEnd()
{
	entity = self;

	robotTraverseRagdollOnDeath( entity );
	
	entity.skipdeath = false;
	
	entity PushActors( true );
	entity PushPlayer( false );
	entity.pushable = true;
}

function private robotSetupWallRunJump()
{
	entity = self;
	startNode = entity.traverseStartNode;
	endNode = entity.traverseEndNode;
	
	direction = "unknown";
	jumpDirection = "unknown";
	traversalType = "unknown";
	
	if ( IsDefined( startNode ) && IsDefined( endNode ) )
	{
		startIsWallrun = startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		endIsWallrun = endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
	
		if ( endIsWallrun )
		{
			direction = _CalculateWallrunDirection( startNode.origin, endNode.origin );
		}
		else
		{
			direction = _CalculateWallrunDirection( endNode.origin, startNode.origin );
			
			if ( direction == "right" )
			{
				direction = "left";
			}
			else
			{
				direction = "right";
			}
		}
		jumpDirection = robotStartJumpDirection();
		traversalType = robotTraversalType( startNode );
	}
	
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_JUMP_DIRECTION, jumpDirection );
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_WALLRUN_DIRECTION, direction );
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_TRAVERSAL_TYPE, traversalType );
	
	robotCalcProceduralTraversal( entity, undefined );
	
	return BHTN_RUNNING;
}

function private robotSetupWallRunLand()
{
	entity = self;
	startNode = entity.traverseStartNode;
	endNode = entity.traverseEndNode;
	
	landDirection = "unknown";
	traversalType = "unknown";
	
	if ( IsDefined( startNode ) && IsDefined( endNode ) )
	{
		landDirection = robotEndJumpDirection( );
		traversalType = robotTraversalType( endNode );
	}
	
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_JUMP_DIRECTION, landDirection );
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_TRAVERSAL_TYPE, traversalType );
	
	return BHTN_RUNNING;
}

function private robotStartJumpDirection()
{
	entity = self;
	startNode = entity.traverseStartNode;
	endNode = entity.traverseEndNode;

	if ( IsDefined( startNode ) && IsDefined( endNode ) )
	{
		startIsWallrun = startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		endIsWallrun = endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		
		if ( startIsWallrun )
		{
			absLengthToEnd = Distance2D( startNode.origin, endNode.origin );
		
			if ( startNode.origin[2] - endNode.origin[2] > 48 &&
				absLengthToEnd < 250 )
			{
				// End position is below the start position, jump outwards.
				return "out";
			}
		}
		
		return "up";
	}
	
	return "unknown";
}

function private robotEndJumpDirection()
{
	entity = self;
	startNode = entity.traverseStartNode;
	endNode = entity.traverseEndNode;

	if ( IsDefined( startNode ) && IsDefined( endNode ) )
	{
		startIsWallrun = startNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		endIsWallrun = endNode.spawnflags & SPAWNFLAG_PATH_WALLRUN;
		
		if ( endIsWallrun )
		{
			absLengthToEnd = Distance2D( startNode.origin, endNode.origin );
		
			if ( endNode.origin[2] - startNode.origin[2] > 48 &&
				absLengthToEnd < 250 )
			{
				// start position is below the end position, jump outwards.
				return "in";
			}
		}
		
		return "down";
	}
	
	return "unknown";
}

function private robotTraversalType( node )
{
	if ( IsDefined( node ) )
	{
		if ( node.spawnflags & SPAWNFLAG_PATH_WALLRUN )
		{
			return "wall";
		}
		
		return "ground";
	}

	return "unknown";
}

function private ArchetypeRobotBlackboardInit()
{
	entity = self;

	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( entity );
	
	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( entity );
	
	// USE UTILITY BLACKBOARD
	entity AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE ROBOT BLACKBOARD
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT, undefined );
	BB_REGISTER_ATTRIBUTE( MIND_CONTROL, "normal", &robotIsMindControlled );
	BB_REGISTER_ATTRIBUTE( MOVE_MODE, "normal", undefined );
	BB_REGISTER_ATTRIBUTE( GIBBED_LIMBS, undefined, &robotGetGibbedLimbs );
	BB_REGISTER_ATTRIBUTE( ROBOT_JUMP_DIRECTION, undefined, undefined );
	BB_REGISTER_ATTRIBUTE( ROBOT_LOCOMOTION_TYPE, undefined, undefined );
	BB_REGISTER_ATTRIBUTE( ROBOT_TRAVERSAL_TYPE, undefined, undefined );
	BB_REGISTER_ATTRIBUTE( ROBOT_WALLRUN_DIRECTION, undefined, undefined );
	BB_REGISTER_ATTRIBUTE( ROBOT_MODE, "normal", undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	entity.___ArchetypeOnAnimscriptedCallback = &ArchetypeRobotOnAnimScriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING( entity );	
	
	// THREAD PRE BULLET FIRE CALLBACK
	if ( SessionModeIsCampaignGame() || SessionModeIsZombiesGame() )
	{
		self thread gameskill::accuracy_buildup_before_fire( self );
	}
	
	// RUN SNIPER GLINT AND LASER IF ACCURATE FIRE IS ON
	if( self.accurateFire )
	{
		self thread AiUtility::preShootLaserAndGlintOn( self );
		self thread AiUtility::postShootLaserAndGlintOff( self );
	}
}

function private robotCrawlerCanShootEnemy( entity )
{
	if ( !IsDefined( entity.enemy ) )
	{
		return false;
	}

	aimLimits = entity GetAimLimitsFromEntry( "robot_crawler" );

	yawToEnemy = AngleClamp180(
		VectorToAngles( ( entity LastKnownPos( entity.enemy ) ) - entity.origin )[1] - entity.angles[1] );

	angleEpsilon = 10;
	
	return yawToEnemy <= ( aimLimits[AIM_LEFT] + angleEpsilon ) &&
		yawToEnemy >= ( aimLimits[AIM_RIGHT] + angleEpsilon );
}

function private ArchetypeRobotOnAnimScriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeRobotBlackboardInit();
}

function private robotGetGibbedLimbs()
{
	entity = self;

	rightArmGibbed = GibServerUtils::IsGibbed( entity, GIB_TORSO_RIGHT_ARM_FLAG );
	leftArmGibbed = GibServerUtils::IsGibbed( entity, GIB_TORSO_LEFT_ARM_FLAG );
	
	if ( rightArmGibbed && leftArmGibbed )
	{
		return "both_arms";
	}
	else if ( rightArmGibbed )
	{
		return "right_arm";
	}
	else if ( leftArmGibbed )
	{
		return "left_arm";
	}
	
	return "none";
}

function private robotInvalidateCover( entity )
{
	entity.steppedOutOfCover = false;
	entity PathMode( "move allowed" );
}

function private robotDelayMovement( entity )
{
	entity PathMode( "move delayed", false, RandomFloatRange( 1, 2 ) );
}

function private robotMovement( entity )
{
	if( Blackboard::GetBlackBoardAttribute( entity, STANCE ) != DEFAULT_MOVEMENT_STANCE )
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );
	}
}

function private robotCoverScanInitialize( entity )
{
	Blackboard::SetBlackBoardAttribute( entity, COVER_MODE, COVER_SCAN_MODE );
	Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_STAND );
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_STEP_IN, "slow" );
	
	AiUtility::keepClaimNode( entity );
	
	AiUtility::chooseCoverDirection( entity, true );
	
	entity.steppedOutOfCoverNode = entity.node;
}

function private robotCoverScanTerminate( entity )
{	
	AiUtility::cleanupCoverMode( entity );
	
	entity.steppedOutOfCover = true;
	entity.steppedOutTime = GetTime() - ( MAX_EXPOSED_TIME * 1000 );
	
	AiUtility::releaseClaimNode( entity );
	
	entity PathMode( "dont move" );
}

function robotCanJuke( entity )
{	
	if ( !entity ai::get_behavior_attribute( "phalanx" ) &&
		!IS_TRUE( entity.steppedOutOfCover ) &&
		AiUtility::canJuke( entity ) )
	{
		jukeEvents = Blackboard::GetBlackboardEvents( "actor_juke" );
		tooCloseJukeDistanceSqr = 240 * 240;
	
		foreach ( event in jukeEvents )
		{
			if ( Distance2DSquared( entity.origin, event.data.origin ) <= tooCloseJukeDistanceSqr )
			{
				return false;
			}
		}
		
		return true;
	}
	
	return false;
}

function robotCanTacticalJuke( entity )
{
	if ( entity HasPath () &&
		AiUtility::BB_GetLocomotionFaceEnemyQuadrant() == LOCOMOTION_FACE_ENEMY_FRONT )
	{
		jukeDirection = AiUtility::calculateJukeDirection(
			entity, ROBOT_TACTICAL_JUKE_RADIUS, entity.jukeDistance );
		
		return jukeDirection != "forward";
	}
	
	return false;
}

function robotCanPreemptiveJuke( entity )
{
	if ( !IsDefined( entity.enemy ) || !IsPlayer( entity.enemy ) )
	{
		return false;
	}
	
	if ( Blackboard::GetBlackBoardAttribute( entity, STANCE ) == STANCE_CROUCH )
	{
		return false;
	}
	
	if ( !entity.shouldPreemptiveJuke )
	{
		return false;
	}
	
	if ( IsDefined( entity.nextPreemptiveJuke ) && entity.nextPreemptiveJuke > GetTime() )
	{
		return false;
	}
	
	if ( entity.enemy PlayerADS() < entity.nextPreemptiveJukeAds )
	{
		return false;
	}
	
	jukeMaxDistance = ROBOT_JUKE_PREEMPTIVE_MAX_DISTANCE;
	
	if ( IsWeapon( entity.enemy.currentweapon ) && 
		IsDefined( entity.enemy.currentweapon.enemycrosshairrange ) &&
		entity.enemy.currentweapon.enemycrosshairrange > 0)
	{
		jukeMaxDistance = entity.enemy.currentweapon.enemycrosshairrange;
		
		if ( jukeMaxDistance > ( ROBOT_JUKE_PREEMPTIVE_MAX_DISTANCE * 2 ) )
		{
			// limit the weapons preemptive juking out to twice the max distance (1200)
			jukeMaxDistance = ROBOT_JUKE_PREEMPTIVE_MAX_DISTANCE * 2;
		}
	}
	
	// Only juke if the robot is close enough to their enemy.
	if ( DistanceSquared( entity.origin, entity.enemy.origin ) < SQR( jukeMaxDistance ) )
	{
		angleDifference = AbsAngleClamp180( entity.angles[1] - entity.enemy.angles[1] );
	
		/#
		record3DText( angleDifference, entity.origin + (0, 0, 5), GREEN, "Animscript" );
		#/
	
		// Make sure the robot could actually see their enemy.
		if ( angleDifference > 135 )
		{
			enemyAngles = entity.enemy GetGunAngles();
			toEnemy = entity.enemy.origin - entity.origin;
			forward = AnglesToForward( enemyAngles );
			dotProduct = Abs( VectorDot( VectorNormalize( toEnemy ), forward ) );
			
			/#
			record3DText( ACos( dotProduct ), entity.origin + (0, 0, 10), GREEN, "Animscript" );
			#/
			
			// Make sure the player is aiming close to the robot.
			if ( dotProduct > 0.9848 )
			{
				// Less than cos(10 degrees) between forard vector and vector to enemy.
				return robotCanJuke( entity );
			}
		}
	}
	
	return false;
}

function robotIsAtCoverModeScan( entity )
{
	coverMode = Blackboard::GetBlackBoardAttribute( entity, COVER_MODE );
	
	return coverMode == COVER_SCAN_MODE;
}

function private robotPrepareForAdjustToCover( entity )
{
	AiUtility::keepClaimNode( entity );
	
	Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_CROUCH );
}

function private robotCrawlerService( entity )
{
	if ( IsDefined( entity.crawlerLifeTime ) &&
		entity.crawlerLifeTime <= GetTime() &&
		entity.health > 0 )
	{
		entity Kill();
	}
	
	return true;
}

function robotIsCrawler( entity )
{
	return entity.isCrawler;
}

function private robotBecomeCrawler( entity )
{
	if ( !entity ai::get_behavior_attribute( "can_become_crawler" ) )
	{
		return;
	}

	entity.isCrawler = true;
	entity.becomeCrawler = false;
	entity AllowPitchAngle( 1 );
	entity SetPitchOrient();
	entity.crawlerLifeTime = GetTime() + RandomIntRange( 10000, 20000 );
	entity notify( "bhtn_action_notify", "rbCrawler" );
}

function robotShouldBecomeCrawler( entity )
{
	return entity.becomeCrawler;
}

function private robotIsMarching( entity )
{
	return Blackboard::GetBlackBoardAttribute( entity, MOVE_MODE ) == "marching";
}

function private robotLocomotionSpeed()
{
	entity = self;
	
	if ( robotIsMindControlled() == "mind_controlled" )
	{
		switch ( ai::GetAiAttribute( entity, "rogue_control_speed" ) )
		{
		case "walk":
			return LOCOMOTION_SPEED_WALK;
		case "run":
			return LOCOMOTION_SPEED_RUN;
		case "sprint":
			return LOCOMOTION_SPEED_SPRINT;
		}
	}
	else if ( ai::GetAiAttribute( entity, "sprint" ) )
	{
		return LOCOMOTION_SPEED_SPRINT;
	}
	
	return LOCOMOTION_SPEED_WALK;
}

function private robotCoverOverInitialize( behaviorTreeEntity )
{
	AiUtility::setCoverShootStartTime( behaviorTreeEntity );
	AiUtility::keepClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_OVER_MODE );	
}

function private robotCoverOverTerminate( behaviorTreeEntity )
{	
	AiUtility::cleanupCoverMode( behaviorTreeEntity );
	AiUtility::clearCoverShootStartTime( behaviorTreeEntity );
}

function private robotIsMindControlled()
{
	entity = self;
	
	if ( entity.controlLevel > 1 )
	{
		return "mind_controlled";
	}
	
	return "normal";
}

function private robotDontTakeCover( entity )
{
	entity.combatmode = "no_cover";
	entity.resumeCover = GetTime() + ROBOT_RESUME_COVER_TIME;
}

function private _IsValidPlayer( player )
{
	if( !IsDefined( player ) ||
		!IsAlive( player ) ||
		!IsPlayer( player ) ||
		player.sessionstate == "spectator" ||
		player.sessionstate == "intermission" ||
		player laststand::player_is_in_laststand() ||
		player.ignoreme ) 
	{
		return false;
	}
	
	return true;
}

function private robotRushEnemyService( entity )
{
	if ( !IsDefined( entity.enemy ) )
	{
		return false;
	}
	
	distanceToEnemy = Distance2DSquared( entity.origin, entity.enemy.origin );

	if ( distanceToEnemy >= ROBOT_RUSHER_DISTANCE_SQ &&
		distanceToEnemy <= ROBOT_RUSHER_MAX_ENEMY_DISTANCE_SQ )
	{
		findPathResult = entity FindPath( entity.origin, entity.enemy.origin, true, false );
	
		if ( findPathResult )
		{
			entity ai::set_behavior_attribute( "move_mode", "rusher" );
		}
	}
}

function private _IsValidRusher( entity, neighbor )
{
	return IsDefined( neighbor ) &&
		IsDefined( neighbor.archetype ) &&
		neighbor.archetype == "robot" &&
		IsDefined( neighbor.team ) &&
		entity.team == neighbor.team &&
		entity != neighbor &&
		IsDefined( neighbor.enemy ) &&
		neighbor ai::get_behavior_attribute( "move_mode" ) == "normal" &&
		!( neighbor ai::get_behavior_attribute( "phalanx" ) ) &&
		neighbor ai::get_behavior_attribute( "rogue_control" ) == "level_0" &&
		DistanceSquared( entity.origin, neighbor.origin ) < ROBOT_RUSHER_NEIGHBOR_DISTANCE_SQ &&
		DistanceSquared( neighbor.origin, neighbor.enemy.origin ) < ROBOT_RUSHER_MAX_ENEMY_DISTANCE_SQ;
}

function private robotRushNeighborService( entity )
{
	actors = GetAiArray();
	
	closestEnemy = undefined;
	closestEnemyDistance = undefined;
	
	foreach( index, ai in actors )
	{
		if ( _IsValidRusher( entity, ai ) )
		{
			enemyDistance = DistanceSquared( entity.origin, ai.origin );
			
			if ( !IsDefined( closestEnemyDistance ) ||
				enemyDistance < closestEnemyDistance )
			{
				closestEnemyDistance = enemyDistance;
				closestEnemy = ai;
			}
		}
	}
	
	if ( IsDefined( closestEnemy ) )
	{
		findPathResult = entity FindPath( closestEnemy.origin, closestEnemy.enemy.origin, true, false );
	
		if ( findPathResult )
		{
			closestEnemy ai::set_behavior_attribute( "move_mode", "rusher" );
		}
	}
}

function private _FindClosest( entity, entities )
{
	closest = SpawnStruct();

	if ( entities.size > 0 )
	{
		closest.entity = entities[0];
		closest.distanceSquared = DistanceSquared( entity.origin, closest.entity.origin );
		
		for ( index = 1; index < entities.size; index++ )
		{
			distanceSquared = DistanceSquared( entity.origin, entities[index].origin );
			
			if ( distanceSquared < closest.distanceSquared )
			{
				closest.distanceSquared = distanceSquared;
				closest.entity = entities[index];
			}
		}
	}
	
	return closest;
}

function private robotTargetService( entity )
{
	if ( robotAbleToShootCondition( entity ) )
	{
		return false;
	}
	
	if ( IS_TRUE( entity.ignoreall ) )
	{
		return false;
	}
	
	// Wait to select a new target so long as the current one is alive.
	if ( IsDefined( entity.nextTargetServiceUpdate ) &&
		entity.nextTargetServiceUpdate > GetTime() &&
		IsAlive( entity.favoriteenemy ) )
	{
		return false;
	}
	
	positionOnNavMesh = GetClosestPointOnNavMesh( entity.origin, ROBOT_NAVMESH_TOLERANCE );
	
	if ( !IsDefined( positionOnNavMesh ) )
	{
		return;
	}
	
	// Clean up favoriteenemy information if set.
	if ( IsDefined( entity.favoriteenemy ) &&
		IsDefined( entity.favoriteenemy._currentRogueRobot ) &&
		entity.favoriteenemy._currentRogueRobot == entity )
	{
		entity.favoriteenemy._currentRogueRobot = undefined;
	}

	aiEnemies = [];
	playerEnemies = [];
	ai = GetAiArray();
	players = GetPlayers();

	// Add AI's that are on different teams.
	foreach( index, value in ai )
	{
		// if this entity is a sentient and this robot is told to ignore it, skip over and consider others.
		if ( IsSentient( value ) && entity GetIgnoreEnt( value ) )
		{
			continue;
		}
		
		// Throw out other AI's that are outside the entity's goalheight.
		// This prevents considering enemies on other floors.
		if ( value.team != entity.team && IsActor( value ) && !IsDefined( entity.favoriteenemy ) )
		{
			enemyPositionOnNavMesh = GetClosestPointOnNavMesh( value.origin, ROBOT_NAVMESH_TOLERANCE, ROBOT_DIAMETER );
		
			if ( IsDefined( enemyPositionOnNavMesh ) &&
				entity FindPath( positionOnNavMesh, enemyPositionOnNavMesh, true, false ) )
			{
				aiEnemies[aiEnemies.size] = value;
			}
		}
	}
	
	// Add valid players
	foreach( index, value in players )
	{
		if ( _IsValidPlayer( value ) && value.team != entity.team  )
		{
			// if this robot is told to ignore this player, skip over and consider others.
			if ( IsSentient( value ) && entity GetIgnoreEnt( value ) )
			{
				continue;
			}
			
			enemyPositionOnNavMesh = GetClosestPointOnNavMesh( value.origin, ROBOT_NAVMESH_TOLERANCE, ROBOT_DIAMETER );
		
			if ( IsDefined( enemyPositionOnNavMesh ) &&
				entity FindPath( positionOnNavMesh, enemyPositionOnNavMesh, true, false ) )
			{
				playerEnemies[playerEnemies.size] = value;
			}
		}
	}
	
	closestPlayer = _FindClosest( entity, playerEnemies );
	closestAI = _FindClosest( entity, aiEnemies );
	
	if ( !IsDefined( closestPlayer.entity ) && !IsDefined( closestAI.entity ) )
	{
		// No player or actor to choose, bail out.
		return;
	}
	else if ( !IsDefined( closestAI.entity ) )
	{
		// Only has a player to choose.
		entity.favoriteenemy = closestPlayer.entity;
	}
	else if ( !IsDefined( closestPlayer.entity ) )
	{
		// Only has an AI to choose.
		entity.favoriteenemy = closestAI.entity;
		entity.favoriteenemy._currentRogueRobot = entity;
	}
	else if ( closestAI.distanceSquared < closestPlayer.distanceSquared )
	{
		// AI is closer than a player, time for additional checks.
		entity.favoriteenemy = closestAI.entity;
		entity.favoriteenemy._currentRogueRobot = entity;
	}
	else
	{
		// Player is closer, choose them.
		entity.favoriteenemy = closestPlayer.entity;
	}
	
	entity.nextTargetServiceUpdate = GetTime() + RandomIntRange( 2500, 3500 );
}

function private setDesiredStanceToStand( behaviorTreeEntity )
{
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	
	if( currentStance == STANCE_CROUCH )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
	}	
}

function private setDesiredStanceToCrouch( behaviorTreeEntity )
{
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	
	if( currentStance == STANCE_STAND )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_CROUCH );
	}
}

function private toggleDesiredStance( entity )
{
	currentStance = Blackboard::GetBlackBoardAttribute( entity, STANCE );
	
	if( currentStance == STANCE_STAND )
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_CROUCH );
	}
	else
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_STAND );
	}
}

function private robotShouldShutdown( entity )
{
	return entity ai::get_behavior_attribute( "shutdown" );
}

function private robotShouldExplode( entity )
{
	if ( entity.controlLevel >= 3 )
	{
		if ( entity ai::get_behavior_attribute( "rogue_force_explosion" ) )
		{
			return true;
		}
		else if ( IsDefined( entity.enemy ) )
		{
			enemyDistSq = DistanceSquared( entity.origin, entity.enemy.origin );
	
			return enemyDistSq < ( ROBOT_DETONATION_RANGE * ROBOT_DETONATION_RANGE );
		}
	}
	
	return false;
}

function private robotShouldAdjustToCover( entity )
{
	if( !IsDefined( entity.node ) )
	{
		return false;
	}
	
	return Blackboard::GetBlackBoardAttribute( entity, STANCE ) != STANCE_CROUCH;
}

function private robotShouldReactAtCover( behaviorTreeEntity )
{
	return
		Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) == STANCE_CROUCH &&
		AiUtility::canBeFlanked( behaviorTreeEntity ) &&
		behaviorTreeEntity IsAtCoverNodeStrict() &&
		behaviorTreeEntity IsFlankedAtCoverNode() &&
		!behaviorTreeEntity HasPath();
}

function private robotExplode( entity )
{
	entity.allowDeath = false;
	entity.noCyberCom = true;
}

function private robotExplodeTerminate( entity )
{
	Blackboard::SetBlackBoardAttribute( entity, GIB_LOCATION, "legs" );
	
	entity RadiusDamage(
		entity.origin + (0, 0, ROBOT_HEIGHT / 2),
		ROBOT_DETONATION_RANGE,
		ROBOT_DETONATION_INNER_DAMAGE,
		ROBOT_DETONATION_OUTER_DAMAGE,
		entity,
		ROBOT_DETONATION_DAMAGE_TYPE );
	
	if ( math::cointoss() )
	{
		GibServerUtils::GibLeftArm( entity );		
	}
	else
	{
		GibServerUtils::GibRightArm( entity );		
	}
	
	GibServerUtils::GibLegs( entity );
	GibServerUtils::GibHead( entity );
	
	clientfield::set(
		ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD, ROBOT_MIND_CONTROL_EXPLOSION_ON );

	if ( IsAlive( entity ) )
	{
		entity.allowDeath = true;
		entity Kill();
	}
	
	entity StartRagdoll();
}

function private robotExposedCoverService( entity )
{
	// Allows robot AI to move away from their "step out" cover position when
	// the node becomes invalid.
	if ( IsDefined( entity.steppedOutOfCover ) &&
		IsDefined( entity.steppedOutOfCoverNode ) &&
		( !entity IsCoverValid( entity.steppedOutOfCoverNode ) ||
		entity HasPath() ||
		!entity IsSafeFromGrenade() ) )
	{
		entity.steppedOutOfCover = false;
		entity PathMode( "move allowed" );
	}
	
	if ( IsDefined( entity.resumeCover ) && GetTime() > entity.resumeCover )
	{
		entity.combatMode = "cover";
		entity.resumeCover = undefined;
	}
}

function private robotIsAtCoverCondition( entity )
{
	enemyTooClose = false;

	if( IsDefined( entity.enemy ) )
	{
		lastKnownEnemyPos = entity LastKnownPos( entity.enemy );
		distanceToEnemySqr = Distance2DSquared( entity.origin, lastKnownEnemyPos );
		enemyTooClose = distanceToEnemySqr <= ( ROBOT_INVALID_COVER_DISTANCE * ROBOT_INVALID_COVER_DISTANCE );
	}

	return !enemyTooClose &&
		!entity.steppedOutOfCover &&
		entity IsAtCoverNodeStrict() &&
		entity ShouldUseCoverNode() &&
		!entity HasPath() &&
		entity IsSafeFromGrenade() &&
		entity.combatMode != "no_cover";
}

function private robotSupportsOverCover( entity )
{
	if ( IsDefined( entity.node ) )
	{
		if ( NODE_SUPPORTS_STANCE_STAND( entity.node ) )
		{
			return NODE_COVER_STAND(entity.node);
		}
	
		return NODE_COVER_LEFT(entity.node) ||
			NODE_COVER_RIGHT(entity.node) ||
			NODE_COVER_CROUCH(entity.node);
	}
	
	return false;
}

function private canMoveToEnemyCondition( entity )
{
	if ( !IsDefined( entity.enemy ) || entity.enemy.health <= 0 )
	{
		return false;
	}

	positionOnNavMesh = GetClosestPointOnNavMesh( entity.origin, ROBOT_NAVMESH_TOLERANCE );
	enemyPositionOnNavMesh = GetClosestPointOnNavMesh( entity.enemy.origin, ROBOT_NAVMESH_TOLERANCE, ROBOT_DIAMETER );
	
	if ( !IsDefined( positionOnNavMesh ) || !IsDefined( enemyPositionOnNavMesh ) )
	{
		return false;
	}

	findPathResult = entity FindPath( positionOnNavMesh, enemyPositionOnNavMesh, true, false );
	
	/#
	if ( !findPathResult )
	{
		record3DText( "NO PATH", enemyPositionOnNavMesh + (0, 0, 5), ORANGE, "Animscript" );
		recordLine( positionOnNavMesh, enemyPositionOnNavMesh, ORANGE, "Animscript", entity );
	}
	#/
	
	return findPathResult;
}

function private canMoveCloseToEnemyCondition( entity )
{
	if ( !IsDefined( entity.enemy ) || entity.enemy.health <= 0 )
	{
		return false;
	}
	
	queryResult = PositionQuery_Source_Navigation(
		entity.enemy.origin,
		0,
		ROBOT_POSITION_QUERY_MOVE_DIST_MAX,
		ROBOT_POSITION_QUERY_MOVE_DIST_MAX,
		ROBOT_POSITION_QUERY_RADIUS,
		entity );
	
	PositionQuery_Filter_InClaimedLocation( queryResult, entity );

	return queryResult.data.size > 0;
}

function private robotStartSprint( entity )
{
	Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
	
	return true;
}

function private robotStartSuperSprint( entity )
{
	Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SUPER_SPRINT );
	
	return true;
}

function private robotTacticalWalkActionStart( entity )
{	
	AiUtility::resetCoverParameters( entity );
	AiUtility::setCanBeFlanked( entity, false );
	
	Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_WALK );
	Blackboard::SetBlackBoardAttribute( entity, STANCE, DEFAULT_MOVEMENT_STANCE );

	return true;
}

function private robotDie( entity )
{
	if ( IsAlive( entity ) )
	{
		entity Kill();
	}
}

function private moveToPlayerUpdate( entity, asmStateName )
{
	entity.keepclaimednode = false;

	positionOnNavMesh = GetClosestPointOnNavMesh(entity.origin, ROBOT_NAVMESH_TOLERANCE );
	
	if ( !IsDefined( positionOnNavMesh ) )
	{
		// Not on the navmesh, bail out.
		return BHTN_SUCCESS;
	}
	
	if ( IS_TRUE( entity.ignoreall ) )
	{
		entity ClearUsePosition();
		return BHTN_SUCCESS;
	}
	
	if ( !IsDefined( entity.enemy ) )
	{
		return BHTN_SUCCESS;
	}
	
	if ( robotRogueHasCloseEnemyToMelee( entity ) )
	{
		// Already at their enemy, bail out.
		return BHTN_SUCCESS;
	}
	
	if ( entity.allowPushActors )
	{
		if ( IsDefined( entity.enemy ) &&
			DistanceSquared( entity.origin, entity.enemy.origin ) > SQR( 300 ) )
		{
			// Allow clipping with other AI's at a distance, this helps when the AI's move diagonally into each other.
			entity PushActors( false );
		}
		else
		{
			// Force AI's to push each other close to their enemy.
			entity PushActors( true );
		}
	}
	
	if ( entity AsmIsTransDecRunning() || entity AsmIsTransitionRunning() )
	{
		// Let the transition animation finish before trying to zig-zag.
		return BHTN_SUCCESS;
	}
	
	if ( !IsDefined( entity.lastKnownEnemyPos) )
	{
		entity.lastKnownEnemyPos = entity.enemy.origin;
	}
	
	shouldRepath = !IsDefined( entity.lastValidEnemyPos );
	
	if ( !shouldRepath && IsDefined( entity.enemy ) )
	{
		if ( IsDefined( entity.nextMoveToPlayerUpdate ) && entity.nextMoveToPlayerUpdate <= GetTime() )
		{
			// It's been a while, repath!
			shouldRepath = true;
		}
		else if ( DistanceSquared( entity.lastKnownEnemyPos, entity.enemy.origin ) > SQR( 72 ) )
		{
			// Enemy has moved far enough to force repathing.
			shouldRepath = true;
		}
		else if ( DistanceSquared( entity.origin, entity.enemy.origin ) <= SQR( 120 ) )
		{
			// Repath if close to the enemy.
			shouldRepath = true;
		}
		else if ( IsDefined( entity.pathGoalPos ) )
		{
			// Repath if close to the current goal position.
			distanceToGoalSqr = DistanceSquared( entity.origin, entity.pathGoalPos );
			
			shouldRepath = distanceToGoalSqr < SQR( 72 );
		}
	}

	if ( shouldRepath )
	{
		entity.lastKnownEnemyPos = entity.enemy.origin;
		
		// Find the closest pathable position on the navmesh to the enemy.
		queryResult = PositionQuery_Source_Navigation(
			entity.lastKnownEnemyPos,
			0,
			ROBOT_POSITION_QUERY_MOVE_DIST_MAX,
			ROBOT_POSITION_QUERY_MOVE_DIST_MAX,
			ROBOT_POSITION_QUERY_RADIUS,
			entity );
			
		PositionQuery_Filter_InClaimedLocation( queryResult, entity );
		
		if ( queryResult.data.size > 0 )
		{
			entity.lastValidEnemyPos = queryResult.data[0].origin;
		}
		
		if ( IsDefined( entity.lastValidEnemyPos ) )
		{
			entity UsePosition( entity.lastValidEnemyPos );
		
		// Randomized zig-zag path following if 20+ feet away from the enemy.
			if ( DistanceSquared( entity.origin, entity.lastValidEnemyPos ) > SQR( 240 ) )
		{
				path = entity CalcApproximatePathToPosition( entity.lastValidEnemyPos, false );
			
			/#
			if ( GetDvarInt( "ai_debugZigZag" ) )
			{
				for ( index = 1; index < path.size; index++ )
				{
					RecordLine( path[index - 1], path[index], ORANGE, "Animscript", entity );
				}
			}
			#/
		
			deviationDistance = RandomIntRange( 240, 480 );  // 20 to 40 feet
		
			segmentLength = 0;
		
			// Walks the current path to find the point where the AI should deviate from their normal path.
			for ( index = 1; index < path.size; index++ )
			{
				currentSegLength = Distance( path[index - 1], path[index] );
				
				if ( ( segmentLength + currentSegLength ) > deviationDistance )
				{
					remainingLength = deviationDistance - segmentLength;
				
					seedPosition = path[index - 1] + ( VectorNormalize( path[index] - path[index - 1] ) * remainingLength );
				
					/# RecordCircle( seedPosition, 2, ORANGE, "Animscript", entity ); #/
		
					innerZigZagRadius = 0;
					outerZigZagRadius = 64;
					
					// Find a point offset from the deviation point along the path.
					queryResult = PositionQuery_Source_Navigation(
						seedPosition,
						innerZigZagRadius,
						outerZigZagRadius,
						0.5 * ROBOT_HEIGHT,
						16,
						entity,
						16 );
					
					PositionQuery_Filter_InClaimedLocation( queryResult, entity );
		
					if ( queryResult.data.size > 0 )
					{
						point = queryResult.data[ RandomInt( queryResult.data.size ) ];
						
						// Use the deviated point as the path instead.
						entity UsePosition( point.origin );
					}
					
					break;
				}
				
				segmentLength += currentSegLength;
			}
		}
	}
	
	// Force repathing after a certain amount of time to smooth out movement.
	entity.nextMoveToPlayerUpdate = GetTime() + RandomIntRange(2000, 3000);
	}
	
	return BHTN_RUNNING;
}

function private robotShouldChargeMelee(entity)
{
	if( AiUtility::shouldMutexMelee( entity )
	   && robotHasEnemyToMelee( entity ))
	{
		return true;
	}
	
	return false;	
}

function private robotHasEnemyToMelee( entity )
{
	if ( IsDefined( entity.enemy ) &&
		IsSentient( entity.enemy ) &&
		entity.enemy.health > 0 )
	{
		enemyDistSq = DistanceSquared( entity.origin, entity.enemy.origin );

		if ( enemyDistSq < SQR( entity.chargeMeleeDistance ) && Abs( entity.enemy.origin[2] - entity.origin[2] ) < 24 )
		{
			yawToEnemy = AngleClamp180( entity.angles[ 1 ] -
				GET_YAW(entity, entity.enemy.origin ) );
			
			return abs( yawToEnemy ) <= MELEE_YAW_THRESHOLD;
		}
	}

	return false;
}

function private robotRogueHasEnemyToMelee( entity )
{
	if ( IsDefined( entity.enemy ) &&
		IsSentient( entity.enemy ) &&
		entity.enemy.health > 0 &&
		entity ai::get_behavior_attribute( "rogue_control" ) != "level_3" )
	{
		if ( !entity CanSee( entity.enemy ) )
		{
			return false;
		}
	
		return DistanceSquared( entity.origin, entity.enemy.origin ) < SQR( 132 );
	}

	return false;
}

function private robotShouldMelee(entity)
{
	if( AiUtility::shouldMutexMelee( entity )
	   && robotHasCloseEnemyToMelee( entity ))
	{
		return true;
	}
	
	return false;	
}	

function private robotHasCloseEnemyToMelee( entity )
{
	if ( IsDefined( entity.enemy ) &&
		IsSentient( entity.enemy ) &&
		entity.enemy.health > 0 )
	{
		if ( !entity CanSee( entity.enemy ) )
		{
			return false;
		}
	
		enemyDistSq = DistanceSquared( entity.origin, entity.enemy.origin );

		if ( enemyDistSq < MELEE_RANGE_SQ )
		{
			yawToEnemy = AngleClamp180( entity.angles[ 1 ] -
				GET_YAW(entity, entity.enemy.origin ) );
			
			return abs( yawToEnemy ) <= MELEE_YAW_THRESHOLD;
		}
	}

	return false;
}

function private robotRogueHasCloseEnemyToMelee( entity )
{
	if ( IsDefined( entity.enemy ) &&
		IsSentient( entity.enemy ) &&
		entity.enemy.health > 0 &&
		entity ai::get_behavior_attribute( "rogue_control" ) != "level_3" )
	{
		return DistanceSquared( entity.origin, entity.enemy.origin ) < MELEE_RANGE_SQ;
	}

	return false;
}

function private scriptRequiresToSprintCondition( entity )
{
	// TODO (David Young 1-29-14): Design is requesting that forcing sprint
	// always occurs, regardless of distance.
	/*
	if ( entity HasPath() &&
		DistanceSquared( entity.pathstartpos, entity.pathgoalpos ) <= ROBOT_WALK_MIN_DISTANCE_SQ )
	{
		return false;
	}
	*/
	
	// if the script interface needs sprinting, then no randomness
	return entity ai::get_behavior_attribute( "sprint" ) &&
		!entity ai::get_behavior_attribute( "disablesprint" );
}

function private robotScanExposedPainTerminate( entity )
{
	AiUtility::cleanupCoverMode( entity );
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_STEP_IN, "fast" );
}

function private robotTookEmpDamage( entity )
{
	if ( IsDefined( entity.damageweapon ) && IsDefined( entity.damagemod ) )
	{
		weapon = entity.damageweapon;
		
		return entity.damagemod == "MOD_GRENADE_SPLASH" &&
			IsDefined( weapon.rootweapon ) &&
			isSubStr(weapon.rootweapon.name,"emp_grenade");		//checking substring for emp grenade variant;  probably this should be a gdt checkbox 'emp damage' or similar
	}
	return false;
}

function private robotNoCloseEnemyService( entity )
{
	if ( IsDefined( entity.enemy ) &&
		AiUtility::shouldMelee( entity ) )
	{
		entity ClearPath();
		return true;
	}
	
	return false;
}

function private _robotOutsideMovementRange( entity, range, useEnemyPos )
{
	assert( IsDefined( range ) );
	
	if ( !IsDefined( entity.enemy ) && !entity HasPath() )
	{
		return false;
	}
	
	goalPos = entity.pathgoalpos;
	
	if ( IsDefined( entity.enemy ) && useEnemyPos )
	{
		goalPos = entity LastKnownPos( entity.enemy );
	}
	
	if( !isdefined( goalPos ) )
	{
		return false;
	}
	
	outsideRange = DistanceSquared( entity.origin, goalPos ) > SQR( range );
	
	return outsideRange;
}

function private robotOutsideSuperSprintRange( entity )
{
	return !robotWithinSuperSprintRange( entity );
}

function private robotWithinSuperSprintRange( entity )
{
	if ( entity ai::get_behavior_attribute( "supports_super_sprint" ) &&
		!entity ai::get_behavior_attribute( "disablesprint" ) )
	{
		return _robotOutsideMovementRange( entity, entity.superSprintDistance, false );
	}
	
	return false;
}

function private robotOutsideSprintRange( entity )
{
	if ( entity ai::get_behavior_attribute( "supports_super_sprint" ) &&
		!entity ai::get_behavior_attribute( "disablesprint" ) )
	{
		return _robotOutsideMovementRange( entity, entity.superSprintDistance * 1.15, false );
	}
	
	return false;
}

function private robotOutsideTacticalWalkRange( entity )
{
	if ( entity ai::get_behavior_attribute( "disablesprint" ) )
	{
		return false;
	}

	if ( IsDefined( entity.enemy ) &&
		DistanceSquared( entity.origin, entity.goalPos ) < SQR( entity.minWalkDistance ) )
	{
		// Slow down when closing in on the enemy.
		return false;
	}

	return _robotOutsideMovementRange( entity, entity.runAndGunDist * 1.15, true );
}

function private robotWithinSprintRange( entity )
{
	if ( entity ai::get_behavior_attribute( "disablesprint" ) )
	{
		return false;
	}

	if ( IsDefined( entity.enemy ) &&
		DistanceSquared( entity.origin, entity.goalPos ) < SQR( entity.minWalkDistance ) )
	{
		// Slow down when closing in on the enemy.
		return false;
	}

	return _robotOutsideMovementRange( entity, entity.runAndGunDist, true );
}

function private shouldTakeOverCondition( entity )
{
	switch ( entity.controlLevel )
	{
		case 0:
			return IsInArray( array( "level_1", "level_2", "level_3" ),
				entity ai::get_behavior_attribute( "rogue_control" ) );
		case 1:
			return IsInArray( array( "level_2", "level_3" ),
				entity ai::get_behavior_attribute( "rogue_control" ) );
		case 2:
			return entity ai::get_behavior_attribute( "rogue_control" ) == "level_3";
	}

	return false;
}

function private hasMiniRaps( entity )
{
	return IsDefined( entity.miniRaps );
}

function private robotIsMoving( entity )
{
	velocity = entity GetVelocity();
	velocity = ( velocity[0], 0, velocity[1] );
	
	velocitySqr = LengthSquared( velocity );
	
	return velocitySqr > SQR( 24 );
}

function private robotAbleToShootCondition( entity )
{
	// Mind control level 2 and 3 are the only robots that can't shoot.
	return entity.controlLevel <= 1;
}

function private robotShouldTacticalWalk( entity )
{
	if ( !entity HasPath() )
	{
		return false;
	}

	return !robotIsMarching( entity );
}

function private _robotCoverPosition( entity )
{
	if( entity IsFlankedAtCoverNode() )
	{
		return false;
	}
		
	if( entity ShouldHoldGroundAgainstEnemy() )
	{
		return false;
	}

	shouldUseCoverNode = undefined;
	itsBeenAWhile  	   = GetTime() > entity.nextFindBestCoverTime;
	isAtScriptGoal 	   = undefined;	
	
	if ( IsDefined( entity.robotNode ) )
	{
		isAtScriptGoal = entity IsPosAtGoal( entity.robotNode.origin );
		shouldUseCoverNode = entity IsCoverValid( entity.robotNode );
	}
	else
	{
		isAtScriptGoal = entity IsAtGoal();
		shouldUseCoverNode = entity ShouldUseCoverNode();
	}
		
	shouldLookForBetterCover = !shouldUseCoverNode || itsBeenAWhile || !isAtScriptGoal;

/#	
	recordEntText( "ChooseBetterCoverReason: shouldUseCoverNode:" + shouldUseCoverNode 
		           + " itsBeenAWhile:" + itsBeenAWhile
		           + " isAtScriptGoal:" + isAtScriptGoal
		           , entity, ( shouldLookForBetterCover ? GREEN : RED ), "Animscript" );
#/

	// Only search for a new cover node if the AI isn't trying to keep their current claimed node.
	if ( shouldLookForBetterCover && IsDefined( entity.enemy ) && !entity.keepClaimedNode )
	{
		transitionRunning = entity ASMIsTransitionRunning();
		subStatePending = entity ASMIsSubStatePending();
		transDecRunning = entity AsmIsTransDecRunning();
		isBehaviorTreeInRunningState = entity GetBehaviortreeStatus() == BHTN_RUNNING;
	
		if ( !transitionRunning && !subStatePending && !transDecRunning && isBehaviorTreeInRunningState )
		{
			nodes = entity FindBestCoverNodes( entity.goalRadius, entity.goalPos );
			node = undefined;

			// Find the first unclaimed node or the node that is already claimed by entity.
			for ( nodeIndex = 0; nodeIndex < nodes.size; nodeIndex++ )
			{
				if ( entity.robotNode === nodes[nodeIndex] ||
					!IsDefined( nodes[nodeIndex].robotClaimed ) )
				{
					node = nodes[nodeIndex];
					break;
				}
			}
		
			// This covers a case where a robot is sent to a node specifically.
			if ( IsEntity( entity.node ) &&
				( !IsDefined( entity.robotNode ) || entity.robotNode != entity.node ) )
			{
				entity.robotNode = entity.node;
				entity.robotNode.robotClaimed = true;
			}
		
			goingToDifferentNode =
				IsDefined( node ) &&
				( !IsDefined( entity.robotNode ) || node != entity.robotNode ) &&
				( !IsDefined( entity.steppedOutOfCoverNode ) || entity.steppedOutOfCoverNode != node );
			
			AiUtility::setNextFindBestCoverTime( entity, node );
			
			if ( goingToDifferentNode )
			{
				if ( RandomFloat( 1 ) <= ROBOT_CHOOSE_COVER_CHANCE || entity ai::get_behavior_attribute( "force_cover" ) )
				{
					AiUtility::useCoverNodeWrapper( entity, node );
				}
				else
				{
					searchRadius = entity.goalRadius;
					
					if ( searchRadius > ( ROBOT_OFF_COVER_NODE_MAX_DISTANCE / 2 ) )
					{
						searchRadius = ROBOT_OFF_COVER_NODE_MAX_DISTANCE / 2;
					}
				
					coverNodePoints = util::PositionQuery_PointArray( 
					    node.origin,
						ROBOT_OFF_COVER_NODE_MIN_DISTANCE / 2,
						searchRadius,
						ROBOT_HEIGHT,
						ROBOT_DIAMETER );
					
					if ( coverNodePoints.size > 0 )
					{
						entity UsePosition( coverNodePoints[ RandomInt( coverNodePoints.size ) ] );
					}
					else
					{
						entity UsePosition( entity GetNodeOffsetPosition( node ) );
					}
				}
				
				if ( IsDefined( entity.robotNode ) )
				{
					entity.robotNode.robotClaimed = undefined;
				}
				
				entity.robotNode = node;
				entity.robotNode.robotClaimed = true;
				
				entity PathMode( "move delayed", false, RandomFloatRange( 0.25, 2 ) );
				
				return true;
			}
		}
	}
	
	return false;
}

function private _robotEscortPosition( entity )
{
	if ( entity ai::get_behavior_attribute( "move_mode" ) == "escort" )
	{
		escortPosition = entity ai::get_behavior_attribute( "escort_position" );
	
		if ( !IsDefined( escortPosition ) )
		{
			return true;
		}
	
		if ( Distance2DSquared( entity.origin, escortPosition ) <=
			ROBOT_ESCORT_MAX_RADIUS * ROBOT_ESCORT_MAX_RADIUS )
		{
			return true;
		}
		
		if ( IsDefined( entity.escortNextTime ) &&
			GetTime() < entity.escortNextTime )
		{
			return true;
		}
		
		if ( entity GetPathMode() == "dont move" )
		{
			return true;
		}
		
		positionOnNavMesh = GetClosestPointOnNavMesh( escortPosition, ROBOT_NAVMESH_TOLERANCE );
		
		if ( !IsDefined( positionOnNavMesh ) )
		{
			positionOnNavMesh = escortPosition;
		}
		
		queryResult = PositionQuery_Source_Navigation(
			positionOnNavMesh,
			ROBOT_ESCORT_MIN_RADIUS,
			ROBOT_ESCORT_MAX_RADIUS,
			0.5 * ROBOT_HEIGHT,
			16,
			entity,
			16 );
		
		PositionQuery_Filter_InClaimedLocation( queryResult, entity );
		
		if ( queryResult.data.size > 0 )
		{
			closestPoint = undefined;
			closestDistance = undefined;
		
			foreach ( point in queryResult.data )
			{
				if ( !point.inclaimedlocation )
				{
					newClosestDistance = Distance2DSquared( entity.origin, point.origin );
				
					if ( !IsDefined( closestPoint ) ||
						newClosestDistance < closestDistance )
					{
						closestPoint = point.origin;
						closestDistance = newClosestDistance;
					}
				}
			}
			
			if ( IsDefined( closestPoint ) )
			{
				entity UsePosition( closestPoint );
				entity.escortNextTime = GetTime() + RandomIntRange( 200, 300 );
			}
		}
		
		return true;
	}
	
	return false;
}

function private _robotRusherPosition( entity )
{
	if ( entity ai::get_behavior_attribute( "move_mode" ) == "rusher" )
	{
		entity PathMode( "move allowed" );
	
		if ( !IsDefined( entity.enemy ) )
		{
			return true;
		}
		
		distToEnemySqr = Distance2DSquared( entity.origin, entity.enemy.origin );
	
		if ( distToEnemySqr <= SQR( entity.robotRusherMaxRadius ) &&
			distToEnemySqr >= SQR( entity.robotRusherMinRadius ) )
		{
			return true;
		}
		
		if ( IsDefined( entity.rusherNextTime ) &&
			GetTime() < entity.rusherNextTime )
		{
			return true;
		}
		
		positionOnNavMesh = GetClosestPointOnNavMesh( entity.enemy.origin, ROBOT_NAVMESH_TOLERANCE );
		
		if ( !IsDefined( positionOnNavMesh ) )
		{
			positionOnNavMesh = entity.enemy.origin;
		}
		
		queryResult = PositionQuery_Source_Navigation(
			positionOnNavMesh,
			entity.robotRusherMinRadius,
			entity.robotRusherMaxRadius,
			0.5 * ROBOT_HEIGHT,
			16,
			entity,
			16 );
		
		PositionQuery_Filter_InClaimedLocation( queryResult, entity );
		PositionQuery_Filter_Sight( queryResult, entity.enemy.origin, entity GetEye() - entity.origin, entity, 2, entity.enemy );
		
		if ( queryResult.data.size > 0 )
		{
			closestPoint = undefined;
			closestDistance = undefined;
		
			foreach ( point in queryResult.data )
			{
				if ( !point.inclaimedlocation && point.visibility === true )
				{
					newClosestDistance = Distance2DSquared( entity.origin, point.origin );
				
					if ( !IsDefined( closestPoint ) ||
						newClosestDistance < closestDistance )
					{
						closestPoint = point.origin;
						closestDistance = newClosestDistance;
					}
				}
			}
			
			if ( IsDefined( closestPoint ) )
			{
				entity UsePosition( closestPoint );
				entity.rusherNextTime = GetTime() + RandomIntRange( 500, 1500 );
			}
		}
		
		return true;
	}
	
	return false;
}

function private _robotGuardPosition( entity )
{
	if ( entity ai::get_behavior_attribute( "move_mode" ) == "guard" )
	{
	if ( entity GetPathMode() == "dont move" )
	{
			return true;
	}

		if ( ( !IsDefined( entity.guardPosition ) ||
		DistanceSquared( entity.origin , entity.guardPosition ) < SQR( 60 ) ) )
	{
			entity PathMode( "move delayed", true, RandomFloatRange( 1, 1.5 ) );
	
		queryResult = PositionQuery_Source_Navigation(
			entity.goalPos,
			0,
			entity.goalradius / 2,
			0.5 * ROBOT_HEIGHT,
			36,
			entity,
			72 );
		
		PositionQuery_Filter_InClaimedLocation( queryResult, entity );
		
		if ( queryResult.data.size > 0 )
		{
			minimumDistanceSq = entity.goalradius * 0.2;
			minimumDistanceSq = minimumDistanceSq * minimumDistanceSq;
			
			distantPoints = [];
			
			foreach( point in queryResult.data )
			{
				if ( DistanceSquared( entity.origin, point.origin ) > minimumDistanceSq )
				{
					distantPoints[ distantPoints.size ] = point;
				}
			}
		
			if ( distantPoints.size > 0 )
			{
				randomPosition = distantPoints[ RandomInt( distantPoints.size ) ];
				
				entity.guardPosition = randomPosition.origin;
				entity.intermediateGuardPosition = undefined;
				entity.intermediateGuardTime = undefined;
			}
		}
	}
	
		// Checks every second to make sure the robot has moved.  If less than 2 feet
		// have changed, then set the guard position to be the robots current position
		// so a new guard position can be selected.
		currentTime = GetTime();
		
		if ( !IsDefined( entity.intermediateGuardTime ) ||
			entity.intermediateGuardTime < currentTime )
		{
			if ( IsDefined( entity.intermediateGuardPosition ) &&
				DistanceSquared( entity.intermediateGuardPosition , entity.origin ) < SQR( 24 ) )
			{
				entity.guardPosition = entity.origin;
			}
		
			entity.intermediateGuardPosition = entity.origin;
			entity.intermediateGuardTime = currentTime + 3000;
		}
	
		if ( IsDefined( entity.guardPosition ) )
	{
		// Keep reapplying the guardPosition.
		entity UsePosition( entity.guardPosition );
		
		return true;
	}
	}
	
	entity.guardPosition = undefined;
	entity.intermediateGuardPosition = undefined;
	entity.intermediateGuardTime = undefined;
	
	return false;
}

function private robotPositionService( entity )
{
	/#
	if ( GetDvarInt( "ai_debugLastKnown" ) && IsDefined( entity.enemy ) )
	{
		lastKnownPos = entity LastKnownPos( entity.enemy );
		recordLine( entity.origin, lastKnownPos, ORANGE, "Animscript", entity );
		record3DText( "lastKnownPos", lastKnownPos + (0, 0, 5), ORANGE, "Animscript" );
	}
	#/
	
	// Release robotNode information upon death.
	if ( !IsAlive( entity ) )
	{
		if ( IsDefined( entity.robotNode ) )
		{
			AiUtility::releaseClaimNode( entity );
			entity.robotNode.robotClaimed = undefined;
			entity.robotNode = undefined;
		}
		
		return false;
	}
	
	if ( entity.disableRepath )
	{
		return false;
	}
	
	// Early out tests.
	if ( !robotAbleToShootCondition( entity ) )
	{
		return false;
	}

	if ( entity ai::get_behavior_attribute( "phalanx" ) )
	{
		return false;
	}
	
	if( AiSquads::isFollowingSquadLeader( entity ) )
	{
		return false;
	}
	
	// Position selection logic, ordered by priority.
	if ( _robotRusherPosition( entity ) )
	{
		return true;
	}
	
	if ( _robotGuardPosition( entity ) )
	{
		return true;
	}
	
	if ( _robotEscortPosition( entity ) )
	{
		return true;
	}

	if ( !AiUtility::isSafeFromGrenades( entity ) )
	{
		AiUtility::releaseClaimNode( entity );
		AiUtility::chooseBestCoverNodeASAP( entity );
	}

	if ( _robotCoverPosition( entity ) )
	{
		return true;
	}
	
	// Go into exposed.
	return false;
}

function private robotDropStartingWeapon( entity, asmStateName )
{
	if ( entity.weapon.name == level.weaponNone.name )
	{
		entity shared::placeWeaponOn( entity.startingWeapon, "right" );
		entity thread shared::DropAIWeapon();
	}
}

function private robotJukeInitialize( entity )
{
	AiUtility::chooseJukeDirection( entity );
	entity ClearPath();
	entity notify( "bhtn_action_notify", "rbJuke" );
	
	jukeInfo = SpawnStruct();
	jukeInfo.origin = entity.origin;
	jukeInfo.entity = entity;

	Blackboard::AddBlackboardEvent( "actor_juke", jukeInfo, 3000 );
}

function private robotPreemptiveJukeTerminate( entity )
{
	entity.nextPreemptiveJuke = GetTime() + RandomIntRange( 4000, 6000 );
	entity.nextPreemptiveJukeAds = RandomFloatRange( 0.5, 0.95 );
}

function private robotTryReacquireService( entity )
{
	moveMode = entity ai::get_behavior_attribute( "move_mode" );
	if ( moveMode == "rusher" || moveMode == "escort" || moveMode == "guard" )
	{
		return false;
	}

	if ( !IsDefined( entity.reacquire_state ) )
	{
		entity.reacquire_state = 0;
	}

	if ( !IsDefined( entity.enemy ) )
	{
		entity.reacquire_state = 0;
		return false;
	}

	if ( entity HasPath() )
	{
		return false;
	}
	
	if ( !robotAbleToShootCondition( entity ) )
	{
		return false;
	}
	
	if ( entity ai::get_behavior_attribute( "force_cover" ) )
	{
		return false;
	}

	if ( entity CanSee( entity.enemy ) && entity CanShootEnemy() )
	{
		entity.reacquire_state = 0;
		return false;
	}

	// don't do reacquire unless facing enemy 
	dirToEnemy = VectorNormalize( entity.enemy.origin - entity.origin );
	forward = AnglesToForward( entity.angles );

	if ( VectorDot( dirToEnemy, forward ) < COS_60 )	
	{
		entity.reacquire_state = 0;
		return false;
	}

	switch ( entity.reacquire_state )
	{
	case 0:
	case 1:
	case 2:
		step_size = REACQUIRE_STEP_SIZE + entity.reacquire_state * REACQUIRE_STEP_SIZE;
		reacquirePos = entity ReacquireStep( step_size );
		break;

	case 4:
		if ( !( entity CanSee( entity.enemy ) ) || !( entity CanShootEnemy() ) )
		{
			entity FlagEnemyUnattackable();
		}
		break;

	default:
		if ( entity.reacquire_state > REACQUIRE_RESET )
		{
			entity.reacquire_state = 0;
			return false;
		}
		break;
	}

	if ( IsVec( reacquirePos ) )
	{
		entity UsePosition( reacquirePos );
		return true;
	}

	entity.reacquire_state++;
	return false;
}

function private takeOverInitialize( entity, asmStateName )
{
	switch ( entity ai::get_behavior_attribute( "rogue_control" ) )
	{
		case "level_1":
			entity RobotSoldierServerUtils::forceRobotSoldierMindControlLevel1();
			break;
		case "level_2":
			entity RobotSoldierServerUtils::forceRobotSoldierMindControlLevel2();
			break;
		case "level_3":
			entity RobotSoldierServerUtils::forceRobotSoldierMindControlLevel3();
			break;
	}
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	return BHTN_RUNNING;
}

function private takeOverTerminate( entity, asmStateName )
{
	switch ( entity ai::get_behavior_attribute( "rogue_control" ) )
	{
		case "level_2":
		case "level_3":
			entity thread shared::DropAIWeapon();
			break;
	}
	
	return BHTN_SUCCESS;
}

function private stepIntoInitialize( entity, asmStateName )
{
	// TODO(David Young 9-2-14): This is required in a very rare case, determine why that is.
	AiUtility::releaseClaimNode( entity );
	
	AiUtility::useCoverNodeWrapper( entity, entity.steppedOutOfCoverNode );
	Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_CROUCH );
	AiUtility::keepClaimNode( entity );
	
	entity.steppedOutOfCoverNode = undefined;
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	
	return BHTN_RUNNING;
}

function private stepIntoTerminate( entity, asmStateName )
{
	entity.steppedOutOfCover = false;
	
	AiUtility::releaseClaimNode( entity );
	
	entity PathMode( "move allowed" );
	
	return BHTN_SUCCESS;
}

function private stepOutInitialize( entity, asmStateName )
{
	entity.steppedOutOfCoverNode = entity.node;
	
	AiUtility::keepClaimNode( entity );
	
	if ( math::cointoss() )
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_STAND );
	}
	else
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_CROUCH );
	}
	
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_STEP_IN, "fast" );
	
	AiUtility::chooseCoverDirection( entity, true );
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	
	return BHTN_RUNNING;
}

function private stepOutTerminate( entity, asmStateName )
{
	entity.steppedOutOfCover = true;
	entity.steppedOutTime = GetTime();
	
	AiUtility::releaseClaimNode( entity );
	
	entity PathMode( "dont move" );
	
	return BHTN_SUCCESS;
}

function private supportsStepOutCondition( entity )
{
	return NODE_COVER_LEFT( entity.node ) ||
		NODE_COVER_RIGHT( entity.node ) ||
		NODE_COVER_PILLAR( entity.node );
}

function private shouldStepInCondition( entity )
{
	if ( !IsDefined( entity.steppedOutOfCover ) ||
		!entity.steppedOutOfCover ||
		!IsDefined( entity.steppedOutTime ) ||
		!entity.steppedOutOfCover )
	{
		return false;
	}
		
	exposedTimeInSeconds = (GetTime() - entity.steppedOutTime) / 1000;
	
	exceededTime = exposedTimeInSeconds >= MIN_EXPOSED_TIME ||
		exposedTimeInSeconds >= MAX_EXPOSED_TIME;
	
	suppressed = entity.suppressionMeter > entity.suppressionThreshold;
	
	return exceededtime || ( exceededtime && suppressed );
}

function private robotDeployMiniRaps()
{
	entity = self;
	
	if ( IsDefined( entity ) && IsDefined( entity.miniRaps ) )
	{
		/*
		raps = SpawnVehicle(
			ROBOT_MINI_RAPS_SPAWNER,
			entity.miniRaps.origin + ROBOT_MINI_RAPS_OFFSET_POSITION,
			( 0, 0, 0 ) );
		*/
		
		positionOnNavMesh = GetClosestPointOnNavMesh( entity.origin, ROBOT_NAVMESH_TOLERANCE );
		
		raps = SpawnVehicle(
			ROBOT_MINI_RAPS_SPAWNER,
			positionOnNavMesh,
			( 0, 0, 0 ) );
		raps.team = entity.team;
		raps thread RobotSoldierServerUtils::RapsDetonateCountdown( raps );
		
		/*
		entity.miniRaps Delete();
		*/
		entity.miniRaps = undefined;
	}
}

// end #namespace RobotSoldierBehavior;

#namespace RobotSoldierServerUtils;

function private _tryGibbingHead( entity, damage, hitLoc, isExplosive )
{
	if ( isExplosive &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_HEAD_EXPLOSION_CHANCE )
	{
		GibServerUtils::GibHead( entity );
	}
	else if ( IsInArray( array( "head", "neck", "helmet" ), hitLoc ) &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_HEAD_HEADSHOT_CHANCE )
	{
		GibServerUtils::GibHead( entity );
	}
	else if ( ( entity.health - damage ) <= 0 &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_HEAD_DEATH_CHANCE )
	{
		GibServerUtils::GibHead( entity );
	}
}

function private _tryGibbingLimb( entity, damage, hitLoc, isExplosive, onDeath )
{
	// Early out if one arm is already gibbed.
	if ( GibServerUtils::IsGibbed( entity, GIB_TORSO_LEFT_ARM_FLAG ) ||
		GibServerUtils::IsGibbed( entity, GIB_TORSO_RIGHT_ARM_FLAG) )
	{
		return;
	}

	if ( isExplosive &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LIMB_EXPLOSION_CHANCE )
	{
		if ( onDeath && math::cointoss() )
		{
			// Only gib the right arm if the robot died.
			GibServerUtils::GibRightArm( entity );
		}
		else
		{
			GibServerUtils::GibLeftArm( entity );
		}
	}
	else if ( IsInArray( array( "left_hand", "left_arm_lower", "left_arm_upper" ), hitLoc ) )
	{
		GibServerUtils::GibLeftArm( entity );
	}
	else if ( onDeath &&
		IsInArray( array( "right_hand", "right_arm_lower", "right_arm_upper" ), hitLoc ) )
	{
		GibServerUtils::GibRightArm( entity );
	}
	else if ( RobotSoldierBehavior::robotIsMindControlled() == "mind_controlled" && 
		IsInArray( array( "right_hand", "right_arm_lower", "right_arm_upper" ), hitLoc ) )
	{
		GibServerUtils::GibRightArm( entity );
	}
	else if ( onDeath && RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LIMB_DEATH_CHANCE )
	{
		if ( math::cointoss() )
		{
			GibServerUtils::GibLeftArm( entity );
		}
		else
		{
			GibServerUtils::GibRightArm( entity );
		}
	}
}

function private _tryGibbingLegs( entity, damage, hitLoc, isExplosive, attacker )
{
	if ( !IsDefined( attacker ) )
	{
		attacker = entity;
	}

	// Gib on death.
	canGibLegs = ( entity.health - damage ) <= 0 && entity.allowdeath;
	
	// Gib based on damage.
	if ( entity ai::get_behavior_attribute( "can_become_crawler" ) )
	{
		canGibLegs = canGibLegs ||
			( ( ( entity.health - damage ) / entity.maxHealth ) <= ROBOT_GIB_LEG_HEALTH_THRESHOLD &&
			DistanceSquared( entity.origin, attacker.origin ) <= ROBOT_CRAWL_MAX_DISTANCE &&
			!RobotSoldierBehavior::robotIsAtCoverCondition( entity ) &&
			entity.allowdeath );
	}
	
	if ( entity.gibDeath &&
		( entity.health - damage ) <= 0 &&
		entity.allowdeath &&
		!RobotSoldierBehavior::robotIsCrawler( entity ) )
	{
		// Don't gib legs on death, let a gib animation do it.
		return;
	}
	
	if ( ( entity.health - damage ) <= 0 &&
		entity.allowdeath &&
		isExplosive &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LEGS_EXPLOSION_CHANCE )
	{
		GibServerUtils::GibLegs( entity );
		entity StartRagdoll();
	}
	else if ( canGibLegs &&
		IsInArray( array( "left_leg_upper", "left_leg_lower", "left_foot" ), hitLoc ) &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LEGS_CHANCE )
	{
		if ( ( entity.health - damage ) > 0 )
		{
			BecomeCrawler( entity );
		}
		
		GibServerUtils::GibLeftLeg( entity );
	}
	else if ( canGibLegs &&
		IsInArray( array( "right_leg_upper", "right_leg_lower", "right_foot" ), hitLoc ) &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LEGS_CHANCE )
	{
		if ( ( entity.health - damage ) > 0 )
		{
			BecomeCrawler( entity );
		}
		
		GibServerUtils::GibRightLeg( entity );
	}
	else if ( ( entity.health - damage ) <= 0 &&
		entity.allowdeath &&
		RandomFloatRange( 0, 1 ) <= ROBOT_GIB_LEGS_DEATH_CHANCE )
	{
		// Randomly gib a leg when dead.
		if ( math::cointoss() )
		{
			GibServerUtils::GibLeftLeg( entity );
		}
		else
		{
			GibServerUtils::GibRightLeg( entity );
		}
	}
}

function private robotGibDamageOverride(
	inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	if ( IsDefined( attacker ) && ( attacker.team == entity.team ) )
	{
		return damage;
	}
	
	if ( !entity ai::get_behavior_attribute( "can_gib" ) )
	{
		return damage;
	}
	
	// Check if any gibbing is allowed.
	if ( ( ( entity.health - damage ) / entity.maxHealth ) > ROBOT_GIB_HEALTH_THRESHOLD )
	{
		return damage;
	}
	
	// Enable spawning gib pieces.
	GibServerUtils::ToggleSpawnGibs( entity, true );
	DestructServerUtils::ToggleSpawnGibs( entity, true );

	isExplosive = IsInArray(
		array(
			"MOD_CRUSH",
			"MOD_GRENADE",
			"MOD_GRENADE_SPLASH",
			"MOD_PROJECTILE",
			"MOD_PROJECTILE_SPLASH",
			"MOD_EXPLOSIVE" ),
		meansOfDeath );
	
	_tryGibbingHead( entity, damage, hitLoc, isExplosive );
	_tryGibbingLimb( entity, damage, hitLoc, isExplosive, false );
	_tryGibbingLegs( entity, damage, hitLoc, isExplosive, attacker );

	return damage;
}

function private robotDeathOverride(
	inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTime )
{
	entity = self;

	entity ai::set_behavior_attribute( "robot_lights", ROBOT_LIGHTS_DEATH );
	
	return damage;
}

function private robotGibDeathOverride(
	inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTime )
{
	entity = self;

	if ( !entity ai::get_behavior_attribute( "can_gib" ) || entity.skipdeath )
	{
		return damage;
	}

	// Enable spawning gib pieces.
	GibServerUtils::ToggleSpawnGibs( entity, true );
	DestructServerUtils::ToggleSpawnGibs( entity, true );

	isExplosive = false;

	if ( entity.controlLevel >= 3 )
	{
		clientfield::set(
			ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD, ROBOT_MIND_CONTROL_EXPLOSION_ON );
	
		DestructServerUtils::DestructNumberRandomPieces( entity );
		GibServerUtils::GibHead( entity );
		if ( math::cointoss() )
		{
			GibServerUtils::GibLeftArm( entity );
		}
		else
		{
			GibServerUtils::GibRightArm( entity );
		}
		GibServerUtils::GibLegs( entity );
		
		velocity = entity GetVelocity() / 9;
		
		entity StartRagdoll();
		entity LaunchRagdoll(
			( velocity[0] + RandomFloatRange( -10, 10 ),
			velocity[1] + RandomFloatRange( -10, 10 ),
			RandomFloatRange( 40, 50 ) ),
			"j_mainroot" );
			
		PhysicsExplosionSphere(
			entity.origin + (0, 0, ROBOT_HEIGHT / 2), 120, 32, 1 );
	}
	else {
		isExplosive = IsInArray(
		array(
			"MOD_CRUSH",
			"MOD_GRENADE",
			"MOD_GRENADE_SPLASH",
			"MOD_PROJECTILE",
			"MOD_PROJECTILE_SPLASH",
			"MOD_EXPLOSIVE" ),
		meansOfDeath );
		
		_tryGibbingLimb( entity, damage, hitLoc, isExplosive, true );
	}
	
	return damage;
}

function private robotDestructDeathOverride(
	inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTime )
{
	entity = self;
	
	if ( entity.skipdeath )
	{
		return damage;
	}
	
	// Enable spawning gib pieces.
	DestructServerUtils::ToggleSpawnGibs( entity, true );
		
	pieceCount = DestructServerUtils::GetPieceCount( entity );
	possiblePieces = [];
	
	// Find all pieces that haven't been destroyed yet.
	for ( index = 1; index <= pieceCount; index++ )
	{
		if ( !DestructServerUtils::IsDestructed( entity, index ) &&
			RandomFloatRange( 0, 1 ) <= ROBOT_DESTRUCT_DEATH_CHANCE )
		{
			possiblePieces[ possiblePieces.size ] = index;
		}
	}
	
	gibbedPieces = 0;
	
	// Destroy up to the maximum number of pieces.
	for ( index = 0; index < possiblePieces.size && possiblePieces.size > 1 && gibbedPieces < ROBOT_DESTRUCT_MAX_DEATH_PIECES; index++ )
	{
		randomPiece = RandomIntRange( 0, possiblePieces.size - 1 );
		
		if ( !DestructServerUtils::IsDestructed( entity, possiblePieces[ randomPiece ] ) )
		{
			DestructServerUtils::DestructPiece( entity, possiblePieces[ randomPiece ] );
			gibbedPieces++;
		}
	}
	
	return damage;
}

function private robotDamageOverride(
	inflictor, attacker, damage, flags, meansOfDamage, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	if( hitLoc != "helmet" || hitLoc != "head" || hitLoc != "neck" )
	{
		if( isDefined( attacker ) && !isPlayer( attacker ) && !isVehicle( attacker ) )
		{
			dist = DistanceSquared( entity.origin, attacker.origin );
			
			if( dist < 256*256 )
			{
				damage = Int( damage * 10 );
			}
			else
			{
				damage = Int( damage * 1.5 );
			}
		}
	}

	
	// Reduce headshot damage to robots in script, since this is hardcoded elsewhere for AI's.
	if ( hitLoc == "helmet" || hitLoc == "head" || hitLoc == "neck" )
	{
		damage = Int( damage * ROBOT_HEADSHOT_MULTIPLIER );
	}
	
	if ( IsDefined( dir ) &&
		IsDefined( meansOfDamage ) &&
		IsDefined( hitLoc ) &&
		VectorDot( AnglesToForward( entity.angles ), dir ) > 0 )
	{
		// Bullet came from behind.
		isBullet = IsInArray(
			array( "MOD_RIFLE_BULLET", "MOD_PISTOL_BULLET" ),
			meansOfDamage );
	
		isTorsoShot = IsInArray(
			array( "torso_upper", "torso_lower" ),
			hitLoc );
		
		if ( isBullet && isTorsoShot )
		{
			damage = Int( damage * ROBOT_BACKSHOT_MULTIPLIER );
		}
	}
	
	// TODO(David Young 9-23-14): This is a hacky way to guarantee a kill when a sticky_grenade lands on a robot.
	if ( weapon.name == "sticky_grenade" )
	{
		switch ( meansOfDamage )
		{
			case "MOD_IMPACT":
				entity.stuckWithStickyGrenade = true;
				break;
			case "MOD_GRENADE_SPLASH":
				if ( IS_TRUE( entity.stuckWithStickyGrenade ) )
				{
					damage = entity.health;
				}
			break;
		}
	}
	
	if ( meansOfDamage == "MOD_TRIGGER_HURT" && entity.ignoreTriggerDamage )
	{
		damage = 0;
	}
	
	return damage;
}

function private robotDestructRandomPieces(
	inflictor, attacker, damage, flags, meansOfDamage, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;

	isExplosive = IsInArray(
		array(
			"MOD_CRUSH",
			"MOD_GRENADE",
			"MOD_GRENADE_SPLASH",
			"MOD_PROJECTILE",
			"MOD_PROJECTILE_SPLASH",
			"MOD_EXPLOSIVE" ),
		meansOfDamage );
		
	if ( isExplosive )
	{
		DestructServerUtils::DestructRandomPieces( entity );
	}
	
	return damage;
}

function private findClosestNavMeshPositionToEnemy( enemy )
{
	enemyPositionOnNavMesh = undefined;

	for ( toleranceLevel = 1; toleranceLevel <= ROBOT_NAVMESH_MAX_TOLERANCE_LEVELS; toleranceLevel++ )
	{
		enemyPositionOnNavMesh = GetClosestPointOnNavMesh(
			enemy.origin,
			ROBOT_NAVMESH_TOLERANCE * toleranceLevel,
			ROBOT_DIAMETER );
			
		if ( IsDefined( enemyPositionOnNavMesh ) )
		{
			break;
		}
	}
	
	return enemyPositionOnNavMesh;
}

function private robotChooseCoverDirection( entity, stepOut )
{
	if ( !IsDefined( entity.node ) )
	{
		return;
	}
	
	coverDirection = Blackboard::GetBlackBoardAttribute( entity, COVER_DIRECTION );
	Blackboard::SetBlackBoardAttribute( entity, PREVIOUS_COVER_DIRECTION, coverDirection );
	Blackboard::SetBlackBoardAttribute( entity, COVER_DIRECTION, AiUtility::calculateCoverDirection( entity, stepOut ) );
}

function private robotSoldierSpawnSetup()
{
	entity = self;
	entity.isCrawler = false;
	entity.becomeCrawler = false;
	entity.combatmode = "cover";
	entity.fullHealth = entity.health;
	entity.controlLevel = 0;
	entity.steppedOutOfCover = false;
	entity.ignoreTriggerDamage = false;
	entity.startingWeapon = entity.weapon;
	entity.jukeDistance = ROBOT_JUKE_DISTANCE;
	entity.jukeMaxDistance = ROBOT_JUKE_MAX_DISTANCE;
	entity.entityRadius = ROBOT_DIAMETER / 2;
	entity.empShutdownTime = ROBOT_EMP_SHUTDOWN_TIME;
	entity.NoFriendlyfire = true;
	entity.ignorerunAndgundist = true;
	entity.disableRepath = false;
	
	entity.robotRusherMaxRadius = ROBOT_RUSHER_MAX_RADIUS;
	entity.robotRusherMinRadius = ROBOT_RUSHER_MIN_RADIUS;
	
	entity.gibDeath = math::cointoss();
	
	// Movement parameters
	entity.minWalkDistance = ROBOT_WALK_MIN_DISTANCE;
	entity.superSprintDistance = ROBOT_SUPER_SPRINT_DISTANCE;
	
	entity.treatAllCoversAsGeneric = true;
	entity.onlyCrouchArrivals = true;
	
	entity.chargeMeleeDistance = 125;
	entity.allowPushActors = true;
	
	entity.nextPreemptiveJukeAds = RandomFloatRange( 0.5, 0.95 );
	entity.shouldPreemptiveJuke = math::cointoss();
	
	DestructServerUtils::ToggleSpawnGibs( entity, true );
	GibServerUtils::ToggleSpawnGibs( entity, true );
	
	clientfield::set( ROBOT_MIND_CONTROL_CLIENTFIELD, ROBOT_MIND_CONTROL_LEVEL_0 );
	
	/#
	if ( GetDvarInt( "ai_robotForceProcedural" ) )
	{
		entity ai::set_behavior_attribute( "traversals", "procedural" );
	}
	#/
	
	entity thread CleanUpEquipment( entity );
	
	AiUtility::AddAIOverrideDamageCallback( entity, &DestructServerUtils::HandleDamage );
	AiUtility::AddAIOverrideDamageCallback( entity, &robotDamageOverride );
	AiUtility::AddAIOverrideDamageCallback( entity, &robotDestructRandomPieces );
	AiUtility::AddAiOverrideDamageCallback( entity, &robotGibDamageOverride );
	AiUtility::AddAIOverrideKilledCallback( entity, &robotDeathOverride );
	AiUtility::AddAIOverrideKilledCallback( entity, &robotGibDeathOverride );
	AiUtility::AddAIOverrideKilledCallback( entity, &robotDestructDeathOverride );
	
	/#
	if ( GetDvarInt( "ai_robotForceControl" ) == 1 )
		entity ai::set_behavior_attribute( "rogue_control", "level_1" );
	else if ( GetDvarInt( "ai_robotForceControl" ) == 2 )
		entity ai::set_behavior_attribute( "rogue_control", "level_2" );
	else if ( GetDvarInt( "ai_robotForceControl" ) == 3 )
		entity ai::set_behavior_attribute( "rogue_control", "level_3" );
		
	if ( GetDvarInt( "ai_robotSpawnForceControl" ) == 1 )
		entity ai::set_behavior_attribute( "rogue_control", "forced_level_1" );
	else if ( GetDvarInt( "ai_robotSpawnForceControl" ) == 2 )
		entity ai::set_behavior_attribute( "rogue_control", "forced_level_2" );
	else if ( GetDvarInt( "ai_robotSpawnForceControl" ) == 3 )
		entity ai::set_behavior_attribute( "rogue_control", "forced_level_3" );
	#/

	if ( GetDvarInt( "ai_robotForceCrawler" ) == 1 )
		entity ai::set_behavior_attribute( "force_crawler", "gib_legs" );
	else if ( GetDvarInt( "ai_robotForceCrawler" ) == 2 )
		entity ai::set_behavior_attribute( "force_crawler", "remove_legs" );
	
	// entity ai::set_behavior_attribute( "robot_mini_raps", true );
	// robotGiveWasp( entity );
	// entity thread robotDeployWasp( entity );
}

function private robotGiveWasp( entity )
{
	if ( IsDefined( entity ) && !IsDefined( entity.wasp ) )
	{
		wasp = Spawn( "script_model", ( 0, 0, 0 ) );
		wasp SetModel( "veh_t7_drone_attack_red" );
		wasp SetScale( 0.75 );
		wasp LinkTo( entity, "j_spine4", ( 5, -15, 0 ), ( 0, 0, 90 ) );
		entity.wasp = wasp;
	}
}

function private robotDeployWasp( entity )
{
	entity endon( "death" );
	
	wait RandomFloatRange( 7, 10 );
	
	if ( IsDefined( entity ) && IsDefined( entity.wasp ) )
	{
		spawnOffset = ( 5, -15, 0 );
		
		while ( !IsPointInNavvolume( entity.wasp.origin + spawnOffset, "small volume" ) )
		{
			wait 1;
		}
		
		entity.wasp Unlink();
		
		wasp = SpawnVehicle( "spawner_bo3_wasp_enemy", entity.wasp.origin + spawnOffset, ( 0, 0, 0 ) );
		
		entity.wasp Delete();
	}
	
	entity.wasp = undefined;
}

function private RapsDetonateCountdown( entity )
{
	entity endon( "death" );
	
	wait RandomFloatRange(
		ROBOT_MINI_RAPS_AUTO_DETONATE_MIN_TIME,
		ROBOT_MINI_RAPS_AUTO_DETONATE_MAX_TIME );
	
	raps::detonate();
}

function private BecomeCrawler( entity )
{
	if ( !RobotSoldierBehavior::robotIsCrawler( entity ) &&
		entity ai::get_behavior_attribute( "can_become_crawler" ) )
	{
		entity.becomeCrawler = true;
	}
}

function private CleanUpEquipment( entity )
{
	entity waittill( "death" );
	
	if ( !IsDefined( entity ) )
	{
		return;
	}
	
	if ( IsDefined( entity.miniRaps ) )
	{
		/*
		entity.miniRaps Delete();
		*/
		entity.miniRaps = undefined;
	}
	
	if ( IsDefined( entity.wasp ) )
	{
		entity.wasp Delete();
		entity.wasp = undefined;
	}
}

function private forceRobotSoldierMindControlLevel1()
{
	entity = self;
	
	if ( entity.controlLevel >= 1 )
	{
		return;
	}
	
	entity.team = "team3";
	entity.controlLevel = 1;
	clientfield::set( ROBOT_MIND_CONTROL_CLIENTFIELD, ROBOT_MIND_CONTROL_LEVEL_1 );
	entity ai::set_behavior_attribute( "rogue_control", "level_1" );
}

function private forceRobotSoldierMindControlLevel2()
{
	entity = self;
	
	if ( entity.controlLevel >= 2 )
	{
		return;
	}
	
	rogue_melee_weapon = GetWeapon( "rogue_robot_melee" );
	
	locomotionTypes = array( "alt1", "alt2", "alt3", "alt4", "alt5" );
	
	Blackboard::SetBlackBoardAttribute( entity, ROBOT_LOCOMOTION_TYPE, locomotionTypes[ RandomInt( locomotionTypes.size ) ] );
	entity ASMSetAnimationRate( RandomFloatRange( 0.95, 1.05 ) );
	entity forceRobotSoldierMindControlLevel1();
	entity.combatmode = "no_cover";
	entity SetAvoidanceMask( "avoid none" );
	entity.controlLevel = 2;
	entity shared::placeWeaponOn( entity.weapon, "none" );
	entity.meleeweapon = rogue_melee_weapon;
	entity.dontDropWeapon = true;
	entity.ignorepathenemyfightdist = true;
	
	if ( entity ai::get_behavior_attribute( "rogue_allow_predestruct" ) )
	{
		DestructServerUtils::DestructRandomPieces( entity );
	}
	
	// Half the health when robots become mind controlled.
	if ( entity.health > entity.maxhealth * 0.6 )
	{
		entity.health = int( entity.maxhealth * 0.6 );
	}
	
	clientfield::set( ROBOT_MIND_CONTROL_CLIENTFIELD, ROBOT_MIND_CONTROL_LEVEL_2 );
	entity ai::set_behavior_attribute( "rogue_control", "level_2" );
	entity ai::set_behavior_attribute( "can_become_crawler", false );
}

function private forceRobotSoldierMindControlLevel3()
{
	entity = self;
	
	if ( entity.controlLevel >= 3 )
	{
		return;
	}
	
	forceRobotSoldierMindControlLevel2();
	entity.controlLevel = 3;
		
	clientfield::set( ROBOT_MIND_CONTROL_CLIENTFIELD, ROBOT_MIND_CONTROL_LEVEL_3 );
	entity ai::set_behavior_attribute( "rogue_control", "level_3" );
}

function robotEquipMiniRaps(  entity, attribute, oldValue, value  )
{
	entity.miniRaps = value;

	// Do not display a miniraps on a robot.
	/*
	if ( IsDefined( entity ) && !IsDefined( entity.miniRaps ) )
	{
		entity.miniRaps = Spawn( "script_model", ( 0, 0, 0 ) );
		entity.miniRaps SetModel( ROBOT_MINI_RAPS_MODEL );
		entity.miniRaps LinkTo(
			entity,
			ROBOT_MINI_RAPS_LINK_TO_BONE,
			ROBOT_MINI_RAPS_OFFSET_POSITION,
			( 0, 0, 0 ) );
	}
	*/
}

function robotLights( entity, attribute, oldValue, value )
{
	if ( value == ROBOT_LIGHTS_HACKED )
	{
		clientfield::set( ROBOT_LIGHTS_CLIENTFIELD, ROBOT_LIGHTS_HACKED );
	}
	else if ( value == ROBOT_LIGHTS_ON )
	{
		clientfield::set( ROBOT_LIGHTS_CLIENTFIELD, ROBOT_LIGHTS_ON );
	}
	else if ( value == ROBOT_LIGHTS_FLICKER )
	{
		clientfield::set( ROBOT_LIGHTS_CLIENTFIELD, ROBOT_LIGHTS_FLICKER );
	}
	else if ( value == ROBOT_LIGHTS_OFF )
	{
		clientfield::set( ROBOT_LIGHTS_CLIENTFIELD, ROBOT_LIGHTS_OFF );
	}
	else if ( value == ROBOT_LIGHTS_DEATH )
	{
		clientfield::set( ROBOT_LIGHTS_CLIENTFIELD, ROBOT_LIGHTS_DEATH );
	}
}

function RandomGibRogueRobot( entity )
{
	GibServerUtils::ToggleSpawnGibs( entity, false );
	
	if ( math::cointoss() )
	{
		if ( math::cointoss() )
		{
			GibServerUtils::GibRightArm( entity );
		}
		else if ( math::cointoss() )
		{
			GibServerUtils::GibLeftArm( entity );
		}
	}
	else
	{
		if ( math::cointoss() )
		{
			GibServerUtils::GibLeftArm( entity );
		}
		else if ( math::cointoss() )
		{
			GibServerUtils::GibRightArm( entity );
		}
	}
}

function rogueControlAttributeCallback( entity, attribute, oldValue, value )
{
	switch ( value )
	{
		case "forced_level_1":
			if ( entity.controlLevel <= 0 )
			{
				forceRobotSoldierMindControlLevel1();
			}
			break;
		case "forced_level_2":
			if ( entity.controlLevel <= 1 )
			{
				forceRobotSoldierMindControlLevel2();
				DestructServerUtils::ToggleSpawnGibs( entity, false );
				
				if ( entity ai::get_behavior_attribute( "rogue_allow_pregib" ) )
				{
					RandomGibRogueRobot( entity );
				}
			}
			break;
		case "forced_level_3":
			if ( entity.controlLevel <= 2 )
			{
				forceRobotSoldierMindControlLevel3();
				DestructServerUtils::ToggleSpawnGibs( entity, false );
				
				if ( entity ai::get_behavior_attribute( "rogue_allow_pregib" ) )
				{
					RandomGibRogueRobot( entity );
				}
			}
			break;
	}
}

function robotMoveModeAttributeCallback( entity, attribute, oldValue, value )
{
	entity.ignorepathenemyfightdist = false;
	Blackboard::SetBlackBoardAttribute( entity, MOVE_MODE, "normal" );

	if ( value != "guard" )
	{
		entity.guardPosition = undefined;
	}

	switch ( value )
	{
		case "normal":
			break;
		case "rambo":
			entity.ignorepathenemyfightdist = true;
			break;
		case "marching":
			entity.ignorepathenemyfightdist = true;
			Blackboard::SetBlackBoardAttribute( entity, MOVE_MODE, "marching" );
			break;
		case "rusher":
			if ( !entity ai::get_behavior_attribute( "can_become_rusher" ) )
			{
				entity ai::set_behavior_attribute( "move_mode", oldValue );
			}
			break;
	}
}

function robotForceCrawler( entity, attribute, oldValue, value )
{
	if ( RobotSoldierBehavior::robotIsCrawler( entity ) )
	{
		return;
	}
	
	if ( !entity ai::get_behavior_attribute( "can_become_crawler" ) )
	{
		return;
	}

	switch ( value )
	{
		case "normal":
			return;
			break;
		case "gib_legs":
			GibServerUtils::ToggleSpawnGibs( entity, true );
			DestructServerUtils::ToggleSpawnGibs( entity, true );
			break;
		case "remove_legs":
			GibServerUtils::ToggleSpawnGibs( entity, false );
			DestructServerUtils::ToggleSpawnGibs( entity, false );
			break;
	}
	
	if ( value == "gib_legs" || value == "remove_legs" )
	{
		if ( math::cointoss() )
		{
			if ( math::cointoss() )
			{
				GibServerUtils::GibRightLeg( entity );
			}
			else
			{
				GibServerUtils::GibLeftLeg( entity );
			}
		}
		else
		{
			GibServerUtils::GibLegs( entity );
		}
		
		// Set the robot to "crawler" levels of health.
		if ( entity.health > ( entity.maxHealth * ROBOT_GIB_LEG_HEALTH_THRESHOLD ) )
		{
			entity.health = Int( entity.maxHealth * ROBOT_GIB_LEG_HEALTH_THRESHOLD );
		}
		
		DestructServerUtils::DestructRandomPieces( entity );
		
		if ( value == "gib_legs" )
		{
			BecomeCrawler( entity );
		}
		else
		{
			RobotSoldierBehavior::robotBecomeCrawler( entity );
		}
	}
}

function rogueControlForceGoalAttributeCallback( entity, attribute, oldValue, value )
{
	if ( !IsVec( value ) )
	{
		return;
	}

	rogueControlled = IsInArray( array( "level_2", "level_3" ),
		entity ai::get_behavior_attribute( "rogue_control" ) );

	if ( !rogueControlled )
	{
		entity ai::set_behavior_attribute( "rogue_control_force_goal", undefined );
	}
	else
	{
		entity.favoriteenemy = undefined;
		entity ClearPath();
		
		entity UsePosition( entity ai::get_behavior_attribute( "rogue_control_force_goal" ) );
	}
}

function rogueControlSpeedAttributeCallback( entity, attribute, oldValue, value )
{
	switch ( value )
	{
	case "walk":
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_WALK );
		break;
	case "run":
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );
		break;
	case "sprint":
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
		break;
	}
}

function robotTraversalAttributeCallback( entity, attribute, oldValue, value )
{
	switch ( value )
	{
	case "normal":
		entity.manualTraverseMode = false;
		break;
	case "procedural":
		entity.manualTraverseMode = true;
		break;
	}
}

// end #namespace RobotSoldierServerUtils;
