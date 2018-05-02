#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

//AI VS AI MELEE BEHAVIOR
#using scripts\shared\ai\archetype_aivsaimelee;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

#define ARCHETYPE_VEHICLE_RAPS "raps"

#precache( "fx", "lensflares/fx_lensflare_sniper_glint" );

#namespace AiUtility;

function autoexec RegisterBehaviorScriptFunctions()
{	
	BT_REGISTER_API("forceRagdoll",								&forceRagdoll);
	BT_REGISTER_API("hasAmmo",									&hasAmmo);
	BT_REGISTER_API("hasLowAmmo",								&hasLowAmmo);
	BT_REGISTER_API("hasEnemy",									&hasEnemy);
	BT_REGISTER_API("isSafeFromGrenades",						&isSafeFromGrenades);
	BT_REGISTER_API("inGrenadeBlastRadius",						&inGrenadeBlastRadius);
	BT_REGISTER_API("recentlySawEnemy",							&recentlySawEnemy);
	BT_REGISTER_API("shouldBeAggressive",						&shouldBeAggressive);
	BT_REGISTER_API("shouldOnlyFireAccurately",					&shouldOnlyFireAccurately);
	
	BT_REGISTER_API("shouldReactToNewEnemy",					&shouldReactToNewEnemy);
	BSM_REGISTER_CONDITION("shouldReactToNewEnemy",				&shouldReactToNewEnemy);
	
	BT_REGISTER_API("hasWeaponMalfunctioned",					&hasWeaponMalfunctioned);
	
	BT_REGISTER_API("shouldStopMoving",							&shouldStopMoving);
	BSM_REGISTER_CONDITION("shouldStopMoving",					&shouldStopMoving);
	
	BT_REGISTER_API("chooseBestCoverNodeASAP",					&chooseBestCoverNodeASAP);
	BT_REGISTER_API("chooseBetterCoverService",					&chooseBetterCoverServiceCodeVersion);
	BT_REGISTER_API("trackCoverParamsService",					&trackCoverParamsService);
	BT_REGISTER_API("refillAmmoIfNeededService",				&refillAmmo);
	BT_REGISTER_API("tryStoppingService",						&tryStoppingService);
	BT_REGISTER_API("isFrustrated",								&isFrustrated);
	BT_REGISTER_API("updatefrustrationLevel",					&updateFrustrationLevel);
	BT_REGISTER_API("isLastKnownEnemyPositionApproachable",		&isLastKnownEnemyPositionApproachable);
	BT_REGISTER_API("tryAdvancingOnLastKnownPositionBehavior",	&tryAdvancingOnLastKnownPositionBehavior);
	BT_REGISTER_API("tryGoingToClosestNodeToEnemyBehavior",		&tryGoingToClosestNodeToEnemyBehavior);
	BT_REGISTER_API("tryRunningDirectlyToEnemyBehavior",		&tryRunningDirectlyToEnemyBehavior);
	BT_REGISTER_API("flagEnemyUnAttackableService",				&flagEnemyUnAttackableService);
	
	BT_REGISTER_API("keepClaimNode",							&keepClaimNode);
	BSM_REGISTER_API("keepClaimNode",							&keepClaimNode);
		
	BT_REGISTER_API("releaseClaimNode",							&releaseClaimNode);
	BT_REGISTER_API("startRagdoll",								&scriptStartRagdoll);
	BT_REGISTER_API("notStandingCondition", 					&notStandingCondition );
	BT_REGISTER_API("notCrouchingCondition", 					&notCrouchingCondition );
	BT_REGISTER_API("explosiveKilled",							&explosiveKilled );
	BT_REGISTER_API("electrifiedKilled",						&electrifiedKilled );
	BT_REGISTER_API("burnedKilled",								&burnedKilled );
	BT_REGISTER_API("rapsKilled",								&rapsKilled );
	BT_REGISTER_API( "meleeAcquireMutex",						&meleeAcquireMutex );
	BT_REGISTER_API( "meleeReleaseMutex",						&meleeReleaseMutex );
	BT_REGISTER_API( "shouldMutexMelee",						&shouldMutexMelee );
	BT_REGISTER_API( "prepareForExposedMelee",					&prepareForExposedMelee );
	BT_REGISTER_API( "cleanupMelee",							&cleanupMelee );
	BT_REGISTER_API( "shouldNormalMelee",						&shouldNormalMelee );
	
	BT_REGISTER_API( "shouldMelee",								&shouldMelee );
	BSM_REGISTER_CONDITION( "shouldMelee",						&shouldMelee );
	
	BT_REGISTER_API( "hasCloseEnemyMelee",						&hasCloseEnemyToMelee );
	BT_REGISTER_API( "isBalconyDeath",							&isBalconyDeath );
	BT_REGISTER_API( "balconyDeath",							&balconyDeath );
	BT_REGISTER_API( "useCurrentPosition",						&useCurrentPosition );
	BT_REGISTER_API( "isUnarmed",								&isUnarmed );
		
	// ------- CHARGE MELEE -----------//
	BT_REGISTER_API( "shouldChargeMelee",						&shouldChargeMelee );
	BT_REGISTER_API( "shouldAttackInChargeMelee",				&shouldAttackInChargeMelee );
	BT_REGISTER_API( "cleanupChargeMelee",						&cleanupChargeMelee );
	BT_REGISTER_API( "cleanupChargeMeleeAttack",				&cleanupChargeMeleeAttack );
	BT_REGISTER_API( "setupChargeMeleeAttack",					&setupChargeMeleeAttack );
	
	// ------- SPECIAL PAIN -----------//
	BT_REGISTER_API( "shouldChooseSpecialPain",					&shouldChooseSpecialPain );
	BT_REGISTER_API( "shouldChooseSpecialPronePain",			&shouldChooseSpecialPronePain );
	
	
	// ------- SPECIAL DEATH -----------//
	BT_REGISTER_API( "shouldChooseSpecialDeath",				&shouldChooseSpecialDeath );
	BT_REGISTER_API( "shouldChooseSpecialProneDeath",			&shouldChooseSpecialProneDeath );
	BT_REGISTER_API( "setupExplosionAnimScale",					&setupExplosionAnimScale );

	// ------- STEALTH -----------//
	BT_REGISTER_API( "shouldStealth",							&shouldStealth );
	BT_REGISTER_API( "stealthReactCondition",					&stealthReactCondition );
	BT_REGISTER_API( "locomotionShouldStealth",					&locomotionShouldStealth );
	BT_REGISTER_API( "shouldStealthResume",						&shouldStealthResume );
	BSM_REGISTER_CONDITION( "locomotionShouldStealth",			&locomotionShouldStealth ); 
	BSM_REGISTER_CONDITION( "stealthReactCondition",			&stealthReactCondition ); 
	BT_REGISTER_API( "stealthReactStart",						&stealthReactStart );	
	BT_REGISTER_API( "stealthReactTerminate",					&stealthReactTerminate );	
	BT_REGISTER_API( "stealthIdleTerminate",					&stealthIdleTerminate );

	// ------- PHALANX -----------//
	BT_REGISTER_API( "isInPhalanx",								&isInPhalanx );
	BT_REGISTER_API( "isInPhalanxStance",						&isInPhalanxStance );
	BT_REGISTER_API( "togglePhalanxStance",						&togglePhalanxStance );
	
	// ------- FLASHBANG -----------//
	BT_REGISTER_API( "tookFlashbangDamage",						&tookFlashbangDamage );

	// ------- ATTACKABLES ---------//
	BT_REGISTER_API( "isAtAttackObject",						&isAtAttackObject );
	BT_REGISTER_API( "shouldAttackObject",						&shouldAttackObject );

	// DEFAULT ACTIONS
	BT_REGISTER_ACTION_SIMPLE( "defaultAction" );
	
	//AI vs AI MELEE BEHAVIOR
	archetype_aivsaimelee::RegisterAIvsAIMeleeBehaviorFunctions();
}

// ------- UTILITY BLACKBOARD -----------//

// Has to be called from the any archetype who wants to use the utility blackboard  
function RegisterUtilityBlackboardAttributes() // has to be called on AI
{
	BB_REGISTER_ATTRIBUTE( ARRIVAL_STANCE,								undefined,						&BB_GetArrivalStance );
	BB_REGISTER_ATTRIBUTE( CONTEXT, 									undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( CONTEXT_2, 									undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( COVER_CONCEALED,								undefined,						&BB_GetCoverConcealed );
	BB_REGISTER_ATTRIBUTE( COVER_DIRECTION,								COVER_FRONT_DIRECTION,			undefined );
	BB_REGISTER_ATTRIBUTE( COVER_MODE,									COVER_MODE_NONE,				undefined );
	BB_REGISTER_ATTRIBUTE( COVER_TYPE,									undefined,						&BB_GetCurrentCoverNodeType );
	BB_REGISTER_ATTRIBUTE( CURRENT_LOCATION_COVER_TYPE,					undefined,						&BB_GetCurrentLocationCoverNodeType );
	BB_REGISTER_ATTRIBUTE( EXPOSED_TYPE,								undefined,						&BB_GetCurrentExposedType );
	BB_REGISTER_ATTRIBUTE( DAMAGE_DIRECTION,							undefined,						&BB_GetDamageDirection );
	BB_REGISTER_ATTRIBUTE( DAMAGE_LOCATION,								undefined,						&BB_ActorGetDamageLocation );
	BB_REGISTER_ATTRIBUTE( DAMAGE_WEAPON_CLASS,							undefined,						&BB_GetDamageWeaponClass );
	BB_REGISTER_ATTRIBUTE( DAMAGE_WEAPON,								undefined,						&BB_GetDamageWeapon );
	BB_REGISTER_ATTRIBUTE( DAMAGE_MOD,									undefined,						&BB_GetDamageMOD );
	BB_REGISTER_ATTRIBUTE( DAMAGE_TAKEN,								undefined, 						&BB_GetDamageTaken );
	BB_REGISTER_ATTRIBUTE( DESIRED_STANCE,								STANCE_STAND,					undefined );
	BB_REGISTER_ATTRIBUTE( ENEMY,										undefined,						&BB_ActorHasEnemy );
	BB_REGISTER_ATTRIBUTE( ENEMY_YAW,									undefined,						&BB_ActorGetEnemyYaw );
	BB_REGISTER_ATTRIBUTE( REACT_YAW,									undefined,						&BB_ActorGetReactYaw );
	BB_REGISTER_ATTRIBUTE( FATAL_DAMAGE_LOCATION,						undefined,						&BB_ActorGetFatalDamageLocation );
	BB_REGISTER_ATTRIBUTE( FIRE_MODE,									undefined,						&GetFireMode);
	BB_REGISTER_ATTRIBUTE( GIB_LOCATION,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( JUKE_DIRECTION,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( JUKE_DISTANCE,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_ARRIVAL_DISTANCE,					undefined,						&BB_GetLocomotionArrivalDistance );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_ARRIVAL_YAW,						undefined,						&BB_GetLocomotionArrivalYaw );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_EXIT_YAW,							undefined,						&BB_GetLocomotionExitYaw );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_FACE_ENEMY_QUADRANT,				LOCOMOTION_FACE_ENEMY_NONE,		&BB_GetLocomotionFaceEnemyQuadrant );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_MOTION_ANGLE,						undefined,						&BB_GetLocomotionMotionAngle );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_FACE_ENEMY_QUADRANT_PREVIOUS,		LOCOMOTION_FACE_ENEMY_NONE,		&BB_GetLocomotionFaceEnemyQuadrantPrevious );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_PAIN_TYPE,						undefined,						&BB_GetLocomotionPainType );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_TURN_YAW,							undefined,						&BB_GetLocomotionTurnYaw );
	BB_REGISTER_ATTRIBUTE( LOOKAHEAD_ANGLE,								undefined,						&BB_GetLookaheadAngle );
	BB_REGISTER_ATTRIBUTE( PATROL,										undefined,						&BB_ActorIsPatroling );
	BB_REGISTER_ATTRIBUTE( PERFECT_ENEMY_YAW,							undefined,						&BB_ActorGetPerfectEnemyYaw );
	BB_REGISTER_ATTRIBUTE( PREVIOUS_COVER_DIRECTION,					COVER_FRONT_DIRECTION,			undefined );
	BB_REGISTER_ATTRIBUTE( PREVIOUS_COVER_MODE,							COVER_MODE_NONE,				undefined );
	BB_REGISTER_ATTRIBUTE( PREVIOUS_COVER_TYPE,							undefined,						&BB_GetPreviousCoverNodeType );
	BB_REGISTER_ATTRIBUTE( STANCE,										STANCE_STAND,					undefined );
	BB_REGISTER_ATTRIBUTE( TRAVERSAL_TYPE,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( MELEE_DISTANCE,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( TRACKING_TURN_YAW,							undefined,						&BB_ActorGetTrackingTurnYaw );
	BB_REGISTER_ATTRIBUTE( WEAPON_CLASS,								"rifle",						&BB_GetWeaponClass );
	BB_REGISTER_ATTRIBUTE( THROW_DISTANCE,								undefined,						undefined );
	BB_REGISTER_ATTRIBUTE( YAW_TO_COVER,								undefined,						&BB_GetYawToCoverNode );
	BB_REGISTER_ATTRIBUTE( SPECIAL_DEATH,								SPECIAL_DEATH_NONE, 			undefined );
	BB_REGISTER_ATTRIBUTE( AST_AWARENESS,								"combat", 						&BB_GetAwareness );
	BB_REGISTER_ATTRIBUTE( AST_AWARENESS_PREVIOUS,						"combat", 						&BB_GetAwarenessPrevious );
	BB_REGISTER_ATTRIBUTE( MELEE_ENEMY_TYPE, 							undefined,						undefined );
			
	BB_REGISTER_ATTRIBUTE( STAIRCASE_NUM_STEPS,							0,								undefined );
	BB_REGISTER_ATTRIBUTE( STAIRCASE_NUM_TOTAL_STEPS,					0,								undefined );
	BB_REGISTER_ATTRIBUTE( STAIRCASE_STATE,								undefined,			 			undefined );
	BB_REGISTER_ATTRIBUTE( STAIRCASE_DIRECTION,							undefined,			 			undefined );
	BB_REGISTER_ATTRIBUTE( STAIRCASE_EXIT_TYPE,							undefined,			 			undefined );	
	BB_REGISTER_ATTRIBUTE( STAIRCASE_STEP_SKIP_NUM,						undefined,			 			&BB_GetStairsNumSkipSteps );		
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private BB_GetStairsNumSkipSteps()
{	
	assert( IsDefined( self._stairsStartNode ) && IsDefined( self._stairsEndNode ) );

	numTotalSteps 	= Blackboard::GetBlackBoardAttribute( self, STAIRCASE_NUM_TOTAL_STEPS );
	stepsSoFar 		= Blackboard::GetBlackBoardAttribute( self, STAIRCASE_NUM_STEPS );
	
	direction	 	= Blackboard::GetBlackBoardAttribute( self, STAIRCASE_DIRECTION );
	
	numOutSteps	= 2;
	totalStepsWithoutOut = numTotalSteps - numOutSteps;
	
	assert( stepsSoFar < ( totalStepsWithoutOut ) );
	
	remainingSteps = totalStepsWithoutOut - stepsSoFar;
	
	// Try 8 steps first
	if( remainingSteps >= 8 )
	{
		return STAIR_SKIP_8;
	}
	else if( remainingSteps >= 6 )
	{
		return STAIR_SKIP_6;
	}

	assert( remainingSteps >= 3 );	
	return STAIR_SKIP_3;
}

function private BB_GetAwareness()
{
	// Awareness is always "combat" unless this agent is in stealth mode
	if( !isDefined( self.stealth ) || !IsDefined( self.awarenesslevelcurrent ) )
		return "combat";
	
	return self.awarenesslevelcurrent;
}

function private BB_GetAwarenessPrevious()
{
	// Awareness is always "combat" unless this agent is in stealth mode
	if( !isDefined( self.stealth ) || !IsDefined( self.awarenesslevelprevious ) )
		return "combat";
	
	return self.awarenesslevelprevious;
}

#define NEAR_COVER_NODE_SQ SQR( 24 )
#define NEAR_COVER_NODE_WIDE_SQ SQR( 64 )
function private BB_GetYawToCoverNode()
{
	if( !IsDefined( self.node ) )
	{
		return 0;
	}
	
	distToNodeSqr = Distance2DSquared( self GetNodeOffsetPosition( self.node ), self.origin );
	
	if ( IS_TRUE( self.keepClaimedNode ) )
	{
		if ( distToNodeSqr > NEAR_COVER_NODE_WIDE_SQ )
		{
			return 0;
		}
	}
	else if ( distToNodeSqr > NEAR_COVER_NODE_SQ )
	{
		return 0;
	}
	
	angleToNode = Ceil( AngleClamp180( self.angles[1] - self GetNodeOffsetAngles( self.node )[1] ) );
	
	return angleToNode;
}

function BB_GetHighestStance()
{
	If( self IsAtCoverNodeStrict() && self ShouldUseCoverNode() )
	{
		highestStance = AiUtility::getHighestNodeStance( self.node );
		return highestStance;
	}
	else
	{
		return Blackboard::GetBlackBoardAttribute( self, STANCE );
	}
}


function BB_GetLocomotionFaceEnemyQuadrantPrevious()
{
	if( IsDefined( self.prevrelativedir ) )
	{
		direction = self.prevrelativedir;

		switch( direction )
		{
			case RELATIVE_DIR_NONE:
				return LOCOMOTION_FACE_ENEMY_NONE;
			case RELATIVE_DIR_FRONT:
				return LOCOMOTION_FACE_ENEMY_FRONT;
			case RELATIVE_DIR_LEFT:
				return LOCOMOTION_FACE_ENEMY_RIGHT;							
			case RELATIVE_DIR_RIGHT:
				return LOCOMOTION_FACE_ENEMY_LEFT;
			case RELATIVE_DIR_BACK:
				return LOCOMOTION_FACE_ENEMY_BACK;		
		}
	}
	
	return LOCOMOTION_FACE_ENEMY_NONE;
}

function BB_GetCurrentCoverNodeType()
{
	return AiUtility::getCoverType( self.node );
}

function BB_GetCoverConcealed()
{
	if ( AiUtility::isCoverConcealed( self.node ) )
	{
		return COVER_TYPE_CONCEALED;
	}
	
	return COVER_TYPE_UNCONCEALED;
}

function BB_GetCurrentLocationCoverNodeType()
{
	// Returns the cover node type that the AI is currently at.
	// This version of cover node type is resilient to timing issues during node selections.
	
	if ( IsDefined( self.node ) && DistanceSquared( self.origin, self.node.origin ) < SQR( 48 ) )
	{
		return BB_GetCurrentCoverNodeType();
	}
	
	return BB_GetPreviousCoverNodeType();
}

function BB_GetDamageDirection()
{	
/#	
	if( IsDefined( level._debug_damage_direction ) )
		return level._debug_damage_direction;
#/
	if ( self.damageyaw > 135 || self.damageyaw <= -135 )
	{
		self.damage_direction = DAMAGE_DIRECTION_FRONT;
		return DAMAGE_DIRECTION_FRONT;
	}
	
	if ( ( self.damageyaw > 45 ) && ( self.damageyaw <= 135 ) )
	{
		self.damage_direction = DAMAGE_DIRECTION_RIGHT;
		return DAMAGE_DIRECTION_RIGHT;
	}
	
	if ( ( self.damageyaw > -45 ) && ( self.damageyaw <= 45 ) )
	{
		self.damage_direction = DAMAGE_DIRECTION_BACK;
		return DAMAGE_DIRECTION_BACK;
	}
		
	self.damage_direction = DAMAGE_DIRECTION_LEFT;
	return DAMAGE_DIRECTION_LEFT;
}

function BB_ActorGetDamageLocation()
{
/#
	if( IsDefined( level._debug_damage_pain_location ) )
		return level._debug_damage_pain_location;
#/
	
	sHitLoc = self.damagelocation;
	
	possibleHitLocations = array();
	
	if ( IS_HITLOC_HEAD(sHitLoc) )
	{
		possibleHitLocations[possibleHitLocations.size] = HITLOC_HEAD;				
	}
	
	if ( IS_HITLOC_CHEST(sHitLoc) )
	{
		possibleHitLocations[possibleHitLocations.size] = HITLOC_CHEST;		
	}
		
	if( IS_HITLOC_HIPS(sHitLoc) )
	{
		possibleHitLocations[possibleHitLocations.size] = HITLOC_GROIN;		
	}
	
	if ( IS_HITLOC_HIPS(sHitLoc) )
	{		
		possibleHitLocations[possibleHitLocations.size] = HITLOC_LEGS;
	}
	
	if ( IS_HITLOC_LEFT_ARM(sHitLoc) )
	{			
		possibleHitLocations[possibleHitLocations.size] = HITLOC_LEFT_ARM;			
	}
	
	if ( IS_HITLOC_RIGHT_ARM(sHitLoc) )
	{				
		possibleHitLocations[possibleHitLocations.size] = HITLOC_RIGHT_ARM;		
	}
	
	if ( IS_HITLOC_LEGS(sHitLoc) )
	{
		possibleHitLocations[possibleHitLocations.size] = HITLOC_LEGS;
	}
	
	// if this AI was shot recently, then try to not repeat the same damagelocation, so that we get two different responses
	if( IsDefined( self.lastDamageTime ) && GetTime() > self.lastDamageTime && GetTime() <= self.lastDamageTime + 1 * 1000 )
	{
		if( IsDefined( self.lastDamageLocation ) )
			ArrayRemoveValue( possibleHitLocations, self.lastDamageLocation );
	}
	
	if( possibleHitLocations.size == 0 )
	{
		// SUMEET (07/02/2015) - There is an underlying VM bug where something modifying 0 size array does not work. 
		// This script happens to be one of the places where that issue happens often. Just creating a completely new 
		// array seems to fix the issue in this case.
		possibleHitLocations = undefined;
		possibleHitLocations = [];
		
		possibleHitLocations[0] = HITLOC_CHEST;
		possibleHitLocations[1] = HITLOC_GROIN;			
	}
		
	assert( possibleHitLocations.size > 0, possibleHitLocations.size );
	
	damageLocation = possibleHitLocations[RandomInt(possibleHitLocations.size)];
	
	// save the last damage location
	self.lastDamageLocation = damageLocation;
		
	return damageLocation;
}

function BB_GetDamageWeaponClass()
{
	if ( IsDefined( self.damageMod ) )
	{
		if ( IsInArray( array( "mod_rifle_bullet" ), ToLower( self.damageMod ) ) )
		return "rifle";
	
		if ( IsInArray( array( "mod_pistol_bullet" ), ToLower( self.damageMod ) ) )
			return "pistol";
		
		if ( IsInArray( array( "mod_melee", "mod_melee_assassinate", "mod_melee_weapon_butt" ), ToLower( self.damageMod ) ) )
			return "melee";
		
		if ( IsInArray( array( "mod_grenade", "mod_grenade_splash", "mod_projectile", "mod_projectile_splash", "mod_explosive" ), ToLower( self.damageMod ) ) )
			return "explosive";
	}
	
	return "rifle";
}

function BB_GetDamageWeapon()
{
	if(isdefined(self.special_weapon) &&isdefined(self.special_weapon.name) )
	{
		return self.special_weapon.name;
	}
	
	if (isDefined(self.damageWeapon) && isDefined(self.damageWeapon.name) )
	{
		return self.damageWeapon.name;
	}

	return "unknown";
}

function BB_GetDamageMOD()
{
	if (isDefined(self.damageMod))
	{
		return ToLower(self.damageMod);
	}
	
	return "unknown";
}

function BB_GetDamageTaken()
{	
/#	
	if( IsDefined( level._debug_damage_intensity ) )
		return level._debug_damage_intensity;
#/
		
	damageTaken 	= self.damageTaken;
	maxHealth 		= self.maxHealth;
	damageTakenType = DAMAGE_LIGHT;
	
	if( IsAlive( self ) )
	{
		// pain damage
//		if( IsDefined( self.lastDamageTime ) && IsDefined( self.lastDamageLocation ) )
//		{
//			if( GetTime() > self.lastDamageTIme && GetTime() < self.lastDamageTime + HEAVY_CONSECUTIVE_ATTACK_INTERVAL )
//				damageTakenType = DAMAGE_HEAVY;
//		}
//		else 
//		{
			ratio = damageTaken / self.maxHealth;
			
			if( ratio > HEAVY_DAMAGE_RATIO )
				damageTakenType = DAMAGE_HEAVY;
//		}
				
		self.lastDamageTime = GetTime();
	}
	else
	{
		// death/fatal damage
		ratio = damageTaken / self.maxHealth;
			
		if( ratio > HEAVY_DAMAGE_RATIO )
			damageTakenType = DAMAGE_HEAVY;		
	}	
	
	return damageTakenType;
}

/*
///BehaviorUtilityDocBegin
"Name: AddAIOverrideDamageCallback \n"
"Summary: Adds an AI damage callback function.  This should only be used by the AI system.\n"
"MandatoryArg: <entity> : Entity to add the damage callback to.\n"
"MandatoryArg: <function> : Damage callback function.\n"
"OptionalArg: <boolean> : Whether to add the callback to the front of the overrides\n"
///BehaviorUtilityDocEnd
*/
function AddAIOverrideDamageCallback( entity, callback, addToFront )
{
	assert( IsEntity( entity ) );
	assert( IsFunctionPtr( callback ) );
	assert( !IsDefined( entity.aiOverrideDamage ) || IsArray( entity.aiOverrideDamage ) );
	
	MAKE_ARRAY( entity.aiOverrideDamage );
	
	if ( IS_TRUE( addToFront ) )
	{
		damageOverrides = [];
		damageOverrides[ damageOverrides.size ] = callback;
		
		foreach( override in entity.aiOverrideDamage )
		{
			damageOverrides[ damageOverrides.size ] = override;
		}
		
		entity.aiOverrideDamage = damageOverrides;
	}
	else
	{
		ARRAY_ADD( entity.aiOverrideDamage, callback );
	}
}

/*
///BehaviorUtilityDocBegin
"Name: RemoveAIOverrideDamageCallback \n"
"Summary: Removes an AI damage callback function.  This should only be used by the AI system.\n"
"MandatoryArg: <entity> : Entity to remove the damage callback from.\n"
"MandatoryArg: <function> : Damage callback function.\n"
"OptionalArg: \n"
///BehaviorUtilityDocEnd
*/
function RemoveAIOverrideDamageCallback( entity, callback )
{
	assert( IsEntity( entity ) );
	assert( IsFunctionPtr( callback ) );
	assert( IsArray( entity.aiOverrideDamage ) );
	
	currentDamageCallbacks = entity.aiOverrideDamage;
	
	entity.aiOverrideDamage = [];
	
	foreach (key, value in currentDamageCallbacks)
	{
		if ( value != callback )
		{
			entity.aiOverrideDamage[ entity.aiOverrideDamage.size ] = value;
		}
	}
}

/*
///BehaviorUtilityDocBegin
"Name: ClearAIOverrideDamageCallbacks \n"
"Summary: Removes all AI damage callback function.  This should only be used by the AI system.\n"
"MandatoryArg: <entity> : Entity to clear the damage callbacks from.\n"
"OptionalArg: \n"
///BehaviorUtilityDocEnd
*/
function ClearAIOverrideDamageCallbacks( entity )
{
	entity.aiOverrideDamage = [];
}

/*
///BehaviorUtilityDocBegin
"Name: AddAIOverrideKilledCallback \n"
"Summary: Adds a AI killed callback function.  This should only be used by the AI system.\n"
"MandatoryArg: <entity> : Entity to add the killed callback to.\n"
"MandatoryArg: <function> : Killed callback function.\n"
"OptionalArg: \n"
///BehaviorUtilityDocEnd
*/
function AddAIOverrideKilledCallback( entity, callback )
{
	assert( IsEntity( entity ) );
	assert( IsFunctionPtr( callback ) );
	assert( !IsDefined( entity.aiOverrideKilled ) || IsArray( entity.aiOverrideKilled ) );
	
	ARRAY_ADD( entity.aiOverrideKilled, callback );
}

function ActorGetPredictedYawToEnemy( entity, lookAheadTime )
{
	// don't run this more than once per frame
	if( IsDefined(entity.predictedYawToEnemy) && IsDefined(entity.predictedYawToEnemyTime) && entity.predictedYawToEnemyTime == GetTime() )
		return entity.predictedYawToEnemy;

	selfPredictedPos = entity.origin;
	moveAngle = entity.angles[1] + entity getMotionAngle();
	selfPredictedPos += (cos( moveAngle ), sin( moveAngle ), 0) * 200.0 * lookAheadTime;

	yaw = VectorToAngles( entity LastKnownPos( entity.enemy ) - selfPredictedPos)[1] - entity.angles[1];
	yaw = AbsAngleClamp360( yaw );
	
	// cache
	entity.predictedYawToEnemy = yaw;
	entity.predictedYawToEnemyTime = GetTime();
	
	return yaw;
}

function BB_ActorIsPatroling()
{
	entity = self;

	if( entity ai::has_behavior_attribute( "patrol" ) 
		&& entity ai::get_behavior_attribute( "patrol" ) )
	{
		return PATROL_ENABLED;
	}
	
	return PATROL_DISABLED;
}

function BB_ActorHasEnemy()
{
	entity = self;

	if ( IsDefined( entity.enemy ) )
	{
		return HAS_ENEMY;
	}
	
	return NO_ENEMY;
}

#define DEFAULT_ENEMY_YAW 0
function BB_ActorGetEnemyYaw()
{
	// enemy yaw from AI's forward direction
	enemy = self.enemy;
	
	if( !IsDefined( enemy ) )
		return DEFAULT_ENEMY_YAW;
	
	toEnemyYaw = ActorGetPredictedYawToEnemy( self, 0.2 );
	///# recordEntText( "EnemyYaw: " + toEnemyYaw, self, RED, "Animscript" ); #/

	return toEnemyYaw;
}

function BB_ActorGetPerfectEnemyYaw()
{
	// enemy yaw from AI's forward direction
	enemy = self.enemy;
	
	if( !IsDefined( enemy ) )
		return DEFAULT_ENEMY_YAW;
	
	toEnemyYaw = VectorToAngles( enemy.origin - self.origin )[1] - self.angles[1];
	toEnemyYaw = AbsAngleClamp360( toEnemyYaw );
	/# recordEntText( "EnemyYaw: " + toEnemyYaw, self, RED, "Animscript" ); #/

	return toEnemyYaw;
}

function BB_ActorGetReactYaw()
{
	result = 0;
	
	if ( isDefined( self.react_yaw ) )
	{
		result = self.react_yaw;
		self.react_yaw = undefined;
	}
	else
	{		
		v_origin = self GetEventPointOfInterest();
		if ( isDefined( v_origin ) )
		{
			str_typeName = self GetCurrentEventTypeName();
			e_originator = self GetCurrentEventOriginator();
			
			if ( str_typeName == "bullet" && isDefined( e_originator ) )
			{
				// React to the source of the bullet, not the bullet whiz by location
				v_origin = e_originator.origin;
			}
	
			deltaOrigin = v_origin - self.origin;
			deltaAngles = VectorToAngles( deltaOrigin );
			result = AbsAngleClamp360( self.angles[YAW] - deltaAngles[YAW] );
		}
	}
	
	return result;
}

function BB_ActorGetFatalDamageLocation()
{
/#	
	if( IsDefined( level._debug_damage_location ) )
		return level._debug_damage_location;
#/
	sHitLoc = self.damagelocation;
	
	if( IsDefined( sHitLoc ) )
	{
		if( IS_HITLOC_HEAD( sHitLoc ) )
			return HITLOC_HEAD;
		
		if( IS_HITLOC_CHEST( sHitLoc ) )
			return HITLOC_CHEST;
		
		if( IS_HITLOC_HIPS( sHitLoc ) )
			return HITLOC_HIPS;
		
		if( IS_HITLOC_RIGHT_ARM( sHitLoc ) )
			return HITLOC_RIGHT_ARM;
		
		if( IS_HITLOC_LEFT_ARM( sHitLoc ) )
			return HITLOC_LEFT_ARM;
		
		if( IS_HITLOC_LEGS( sHitLoc ) )
			return HITLOC_LEGS;
	}
	
	randomLocs = array( HITLOC_CHEST, HITLOC_HIPS );
	return randomLocs[ RandomInt( randomLocs.size ) ];
}

function GetAngleUsingDirection( direction )
{
	directionYaw = VectorToAngles(direction)[1];
	yawDiff =  directionYaw - self.angles[1];
	yawDiff = yawDiff * (1.0 / 360.0);
	flooredYawDiff = floor(yawDiff + 0.5);
	turnAngle = (yawDiff - flooredYawDiff) * 360.0;
	
	///# recordEntText( "YawAngle: " + AbsAngleClamp360( turnAngle ), self, RED, "Animscript" ); #/
			
	return AbsAngleClamp360( turnAngle );
}


function wasAtCoverNode()
{
	if( IsDefined( self.prevNode ) )
	{
		if( NODE_TYPE_COVER( self.prevNode ) )
			return true;
	}
	
	return false;
}

function BB_GetLocomotionExitYaw( blackboard, yaw )
{
	exitYaw = undefined;
	
	if( self HasPath() )
	{			
		predictedLookAheadInfo = self PredictExit();
		status = predictedLookAheadInfo["path_prediction_status"];
		
		if( !IsDefined( self.pathgoalpos ) )
		{
			return INVALID_EXIT_YAW;
		}
		
		if( DistanceSquared( self.origin, self.pathgoalpos ) <= MIN_EXITYAW_DISTANCE_SQ )
		{
			return INVALID_EXIT_YAW;
		}
	
		if( status == CORNER_PREDICTOR_STATUS_EXITING_COVER )
		{
			start = self.origin;
			end = start + VectorScale( ( 0, predictedLookAheadInfo["path_prediction_travel_vector"][1], 0 ), 100 );
			
			angleToExit = VectorToAngles( predictedLookAheadInfo["path_prediction_travel_vector"] )[1];
			exitYaw = AbsAngleClamp360( angleToExit - self.prevnode.angles[1] );	
		}
		else if( status == CORNER_PREDICTOR_STATUS_EXITING_EXPOSED )
		{
			start = self.origin;
			end = start + VectorScale( ( 0, predictedLookAheadInfo["path_prediction_travel_vector"][1], 0 ), 100 );
				
			angleToExit = VectorToAngles( predictedLookAheadInfo["path_prediction_travel_vector"] )[1];
			exitYaw = AbsAngleClamp360( angleToExit - self.angles[1] );	
		}
		else if( status == CORNER_PREDICTOR_STATUS_SUCCESS )
		{
			if( wasAtCoverNode() && DistanceSquared( self.prevNode.origin, self.origin ) < (5 * 5) )
			{
				end = self.pathgoalpos;
				
				angleToDestination = VectorToAngles( end - self.origin )[1];
				angleDifference = AbsAngleClamp360( angleToDestination - self.prevnode.angles[1] );
				///#recordEntText( "Exit Yaw: "+angleDifference, self, RED, "Animscript" );#/
				return angleDifference;
			}
			
			start = predictedLookAheadInfo["path_prediction_start_point"];
			end = start + predictedLookAheadInfo["path_prediction_travel_vector"];
			
			exitYaw = GetAngleUsingDirection( predictedLookAheadInfo["path_prediction_travel_vector"] );		
		}
		else if( status == CORNER_PREDICTOR_STATUS_STRAIGHT_LINE_TO_GOAL )
		{	
			if( DistanceSquared( self.origin, self.pathgoalpos ) <= MIN_EXITYAW_DISTANCE_SQ )
			{
				///#recordEntText( "Exit Yaw: undefined", self, RED, "Animscript" );#/
				return undefined;
			}
			
			if( wasAtCoverNode() && DistanceSquared( self.prevNode.origin, self.origin ) < (5 * 5) )
			{
				end = self.pathgoalpos;
				
				angleToDestination = VectorToAngles( end - self.origin )[1];
				angleDifference = AbsAngleClamp360( angleToDestination - self.prevnode.angles[1] );
				///#recordEntText( "Exit Yaw: "+angleDifference, self, RED, "Animscript" );#/
				return angleDifference;
			}
			
			start = self.origin;
			end = self.pathgoalpos;
			
			exitYaw = GetAngleUsingDirection( VectorNormalize( end - start ) );			
		}
	}
	
	/#
	if ( IsDefined( exitYaw ) )
	{
		Record3DText( "Exit Yaw: " + Int( exitYaw ), self.origin - ( 0, 0, 5 ), RED, "Animscript", undefined, 0.4 );
	}
	#/
	
	return exitYaw;
}

function BB_GetLocomotionFaceEnemyQuadrant()
{
	/#
	// Used by cp_ai_arrival to force a tactical walk direction
	walkString = GetDvarString( "tacticalWalkDirection" );
	switch( walkString )
	{
		case "RIGHT":
			return LOCOMOTION_FACE_ENEMY_RIGHT;							
		case "LEFT":
			return LOCOMOTION_FACE_ENEMY_LEFT;
		case "BACK":
			return LOCOMOTION_FACE_ENEMY_BACK;			  
	}
	#/
	
	if( IsDefined( self.relativedir ) )
	{
		direction = self.relativedir;
		
		switch( direction )
		{
			case RELATIVE_DIR_NONE:
				return LOCOMOTION_FACE_ENEMY_FRONT;
			case RELATIVE_DIR_FRONT:
				return LOCOMOTION_FACE_ENEMY_FRONT;
			case RELATIVE_DIR_LEFT:
				return LOCOMOTION_FACE_ENEMY_RIGHT;							
			case RELATIVE_DIR_RIGHT:
				return LOCOMOTION_FACE_ENEMY_LEFT;
			case RELATIVE_DIR_BACK:
				return LOCOMOTION_FACE_ENEMY_BACK;		
		}
	}
	
	return LOCOMOTION_FACE_ENEMY_FRONT;
}


function BB_GetLocomotionPainType()
{
	if( self HasPath() )
	{
		
		predictedLookAheadInfo = self PredictPath();
		status = predictedLookAheadInfo["path_prediction_status"];
		
		startPos = self.origin;	
		
		// if AI is going in a straight line to the goal, then just need to make sure that, AI will not overshoot
		furthestPointTowardsGoalClear = true;
		
		if( status == CORNER_PREDICTOR_STATUS_STRAIGHT_LINE_TO_GOAL )
		{
			furthestPointAlongTowardsGoal = startPos + VectorScale( self.lookaheaddir, LOCOMOTION_MOVING_PAIN_DIST_LONG );
			furthestPointTowardsGoalClear = self FindPath( startPos, furthestPointAlongTowardsGoal, false, false ) && self MayMoveToPoint( furthestPointAlongTowardsGoal );
		}
				
		if( furthestPointTowardsGoalClear )
		{
			forwardDir = AnglesToForward( self.angles );
			possiblePainTypes = [];
		
			endPos = startPos + VectorScale( forwardDir, LOCOMOTION_MOVING_PAIN_DIST_LONG );
			if( self MayMoveToPoint( endpos ) && self FindPath( startPos, endpos, false, false ) )
			{
				possiblePainTypes[possiblePainTypes.size] = LOCOMOTION_MOVING_PAIN_LONG;
			}
			
			endPos = startPos + VectorScale( forwardDir, LOCOMOTION_MOVING_PAIN_DIST_MED );
			if( self MayMoveToPoint( endpos ) && self FindPath( startPos, endpos, false, false ) )
			{
				possiblePainTypes[possiblePainTypes.size] = LOCOMOTION_MOVING_PAIN_MED;			
			}
			
			endPos = startPos + VectorScale( forwardDir, LOCOMOTION_MOVING_PAIN_DIST_SHORT );
			if( self MayMoveToPoint( endpos ) && self FindPath( startPos, endpos, false, false )  )
			{
				possiblePainTypes[possiblePainTypes.size] = LOCOMOTION_MOVING_PAIN_SHORT;			
			}
			
			if( possiblePainTypes.size )
			{
				return array::random( possiblePainTypes );
			}
		}
	}	
	
	return LOCOMOTION_INPLACE_PAIN;		
}

function BB_GetLookaheadAngle()
{
	return AbsAngleClamp360( VectorToAngles( self.lookaheaddir )[1] - self.angles[1] );
}

function BB_GetPreviousCoverNodeType()
{	
	return AiUtility::getCoverType( self.prevNode );	
}

#define TRACKING_TURN_PERFECT_INFO_DIST 180
#define TRACKING_TURN_GIVE_UP_TIME 5000
function BB_ActorGetTrackingTurnYaw()
{
	PixBeginEvent( "BB_ActorGetTrackingTurnYaw" );

	if( IsDefined( self.enemy ) )
	{
		predictedPos = undefined;
	
		// If the enemy is less than the perfect info distance to enemy it looks better
		// to just turn to the enemy, instead of using smaller turns.
		
		// TODO(David Young 2-16-15): Look into using the highlyawareradius instead of a define.
		if ( Distance2DSquared( self.enemy.origin, self.origin ) < SQR( TRACKING_TURN_PERFECT_INFO_DIST ) )
		{
			predictedPos = self.enemy.origin;
			
			// Cheating the enemy's position, don't react to the enemy.
			self.newEnemyReaction = false;
		}
		else if ( !IsSentient( self.enemy ) || ( self LastKnownTime( self.enemy ) + TRACKING_TURN_GIVE_UP_TIME ) >= GetTime() )
		{
			predictedPos = self LastKnownPos( self.enemy );
		}
		
		if( IsDefined( predictedPos ) )
		{
			turnYaw = AbsAngleClamp360( self.angles[1] - GET_YAW( self, predictedPos ) );
			PixEndEvent();
			return turnYaw;
		}
	}
	
	PixEndEvent();
    return undefined;
}

function BB_GetWeaponClass()
{
	// Default to rifle.
	return DEFAULT_WEAPON;
}

// ------- UTILITY -----------//
function notStandingCondition( behaviorTreeEntity )
{
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) != STANCE_STAND )
	{
		return true;
	}
	
	return false;
}

function notCrouchingCondition( behaviorTreeEntity )
{
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE ) != STANCE_CROUCH )
	{
		return true;
	}
	
	return false;
}

function scriptStartRagdoll( behaviorTreeEntity )
{
	behaviorTreeEntity StartRagdoll();
}


// ------- EXPOSED MELEE -----------//
function private prepareForExposedMelee( behaviorTreeEntity )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	AiUtility::meleeAcquireMutex( behaviorTreeEntity );
	
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	
	if(isDefined(behaviorTreeEntity.enemy) && isDefined(behaviorTreeEntity.enemy.vehicletype) && isSubStr(behaviorTreeEntity.enemy.vehicletype,"firefly") )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, MELEE_ENEMY_TYPE_FIREFLY);
	}
	
	if( currentStance == STANCE_CROUCH )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
	}	
}


/*
///BehaviorUtilityDocBegin
"Name: isFrustrated \n"
"Summary: When AI has nothing to do from the cover, then AI's frustration will grow. When he will perform one of the actions, he will reset it.
This should give AI a better behavior to handle situations where he has nothing to do that will be considered as effective attack."
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isFrustrated( behaviorTreeEntity )
{
	return ( IsDefined( behaviorTreeEntity.frustrationLevel ) && behaviorTreeEntity.frustrationLevel > 0 );
}

#define MAX_FRUSTRATION 4
#define MIN_FRUSTRATION 0

function clampFrustration( frustrationLevel )
{
	if ( frustrationLevel > MAX_FRUSTRATION )
	{
		return MAX_FRUSTRATION;
	}
	else if ( frustrationLevel < MIN_FRUSTRATION )
	{
		return MIN_FRUSTRATION;
	}
	
	return frustrationLevel;
}

#define AGGRESSIVE_BOOST_TIME 5000

/*
///BehaviorUtilityDocBegin
"Name: updateFrustrationLevel \n"
"Summary: When AI has nothing to do from the cover, then AI's frustration will grow. We track this using frustrationLevel
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function updateFrustrationLevel( entity )
{
	if( !entity IsBadGuy() )
	{
		return false;
	}
	
	if( !IsDefined( entity.frustrationLevel ) )
	{
		entity.frustrationLevel = 0;
	}
		
	if( !IsDefined( entity.enemy ) )
	{
		entity.frustrationLevel = 0;
		return false;
	}
		
	/#record3DText( "frustrationLevel " + entity.frustrationLevel, entity.origin, ORANGE, "Animscript" );#/
	
	if ( IsActor( entity.enemy ) || IsPlayer( entity.enemy ) )
	{
		// Aggressive AI types get frustrated regularly to keep them close to their enemy.
		if ( entity.aggressiveMode ) 
		{
			if ( !IsDefined( entity.lastFrustrationBoost ) )
			{
				entity.lastFrustrationBoost = GetTime();
			}
			
			if ( ( entity.lastFrustrationBoost + AGGRESSIVE_BOOST_TIME ) < GetTime() )
			{
				entity.frustrationLevel++;
				entity.lastFrustrationBoost = GetTime();
				entity.frustrationLevel = clampFrustration( entity.frustrationLevel );
			}
		}
	
		// AI is aware of the enemy for a while?
		isAwareOfEnemy = ( GetTime() - entity LastKnownTime( entity.enemy ) ) < 10 * 1000;
		
		// AI has seen the enemy for a while?
		if( entity.frustrationLevel == 4 )
			hasSeenEnemy = entity SeeRecently( entity.enemy, 2 );
		else
			hasSeenEnemy = entity SeeRecently( entity.enemy, 5 );
		
		// AI has attacked the enemy recently
		hasAttackedEnemyRecently = entity AttackedRecently( entity.enemy, 5 );
		
		if( !isAwareOfEnemy || IsActor( entity.enemy ) )
		{
			if ( !hasSeenEnemy )
			{
				entity.frustrationLevel++;
			}
			else if ( !hasAttackedEnemyRecently )
			{
				entity.frustrationLevel += 2;
			}
			
			entity.frustrationLevel = clampFrustration( entity.frustrationLevel );
			
			return true;	
		}
		
		if ( hasAttackedEnemyRecently )
		{
			entity.frustrationLevel -= 2;
			entity.frustrationLevel = clampFrustration( entity.frustrationLevel );
			
			return true;
		}
		else if ( hasSeenEnemy )
		{
			entity.frustrationLevel--;
			entity.frustrationLevel = clampFrustration( entity.frustrationLevel );
			
			return true;
		}
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: flagEnemyUnAttackableService \n"
"Summary: AI will mark the enemy unattackable for certain amount of time. Desired result will be that he will look for some other enemy to fight against.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function flagEnemyUnAttackableService( behaviorTreeEntity )
{
	behaviorTreeEntity FlagEnemyUnattackable();	
}

/*
///BehaviorUtilityDocBegin
"Name: isLastKnownEnemyPositionApproachable \n"
"Summary: Returns true if the last known position of the enemy is within goal and pathable.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isLastKnownEnemyPositionApproachable( behaviorTreeEntity )
{	
	if( IsDefined( behaviorTreeEntity.enemy ) )	   
	{
		lastKnownPositionOfEnemy = behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy );
			
		if( behaviorTreeEntity IsInGoal( lastKnownPositionOfEnemy ) 
		   && behaviorTreeEntity FindPath( behaviorTreeEntity.origin, lastKnownPositionOfEnemy, true, false ) 
			)
			{	
				return true;
			}	
	}
		
	return false;
}


/*
///BehaviorUtilityDocBegin
"Name: tryAdvancingOnLastKnownPositionBehavior \n"
"Summary: AI will try to run to the last known position of the enemy as long as it is within the goal.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function tryAdvancingOnLastKnownPositionBehavior( behaviorTreeEntity )
{	
	if( IsDefined( behaviorTreeEntity.enemy ) )	   
	{
		if( IS_TRUE( behaviorTreeEntity.aggressiveMode ) )
		{
			lastKnownPositionOfEnemy = behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy );
			
			if( behaviorTreeEntity IsInGoal( lastKnownPositionOfEnemy ) 
			   && behaviorTreeEntity FindPath( behaviorTreeEntity.origin, lastKnownPositionOfEnemy, true, false ) 
			  )
			{				
				behaviorTreeEntity UsePosition( lastKnownPositionOfEnemy, lastKnownPositionOfEnemy );
				
				AiUtility::setNextFindBestCoverTime( behaviorTreeEntity, undefined );
						
				return true;				
			}
		}
	}
		
	return false;
}


/*
///BehaviorUtilityDocBegin
"Name: tryGoingToClosestNodeToEnemyBehavior \n"
"Summary: AI will try to run to the closest node to the enemy as long as it is within the goal.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function tryGoingToClosestNodeToEnemyBehavior( behaviorTreeEntity )
{	
	if( IsDefined( behaviorTreeEntity.enemy ) )	 
	{
		closestRandomNode = behaviorTreeEntity FindBestCoverNodes( behaviorTreeEntity.engageMaxDist, behaviorTreeEntity.enemy.origin )[0];
		
       if( IsDefined( closestRandomNode ) 
		   && behaviorTreeEntity IsInGoal( closestRandomNode.origin )
		   && behaviorTreeEntity FindPath( behaviorTreeEntity.origin, closestRandomNode.origin, true, false ) 
		  )
		{
			useCoverNodeWrapper( behaviorTreeEntity, closestRandomNode );
							
			return true;				
		}
	}			
	
	return false;
}


/*
///BehaviorUtilityDocBegin
"Name: tryRunningDirectlyToEnemyBehavior \n"
"Summary: AI will try to run directly to enemy as long as it is within the goal. This is a little cheating as we share the origin directly\n
with the enemy, but in combat, it will make AI look smarter."
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function tryRunningDirectlyToEnemyBehavior( behaviorTreeEntity )
{	
	if( IsDefined( behaviorTreeEntity.enemy ) && IS_TRUE( behaviorTreeEntity.aggressiveMode )  )
	{
		origin = behaviorTreeEntity.enemy.origin;
		
		if( behaviorTreeEntity IsInGoal( origin ) 
		   && behaviorTreeEntity FindPath( behaviorTreeEntity.origin, origin, true, false ) 
		  )
		{
			behaviorTreeEntity UsePosition( origin, origin );
			
			AiUtility::setNextFindBestCoverTime( behaviorTreeEntity, undefined );
					
			return true;				
		}
	}
		
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: shouldReactToNewEnemy \n"
"Summary: returns true if AI should react to enemy.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldReactToNewEnemy( behaviorTreeEntity )
{
	// TODO(David Young 4-25-15): Currently disabling reactions till they are more reliable.
	return false;

	if( IS_TRUE( behaviorTreeEntity.newEnemyReaction ) )
	{
		return true;	
	}
	
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );

	return stance == STANCE_STAND && behaviorTreeEntity.newEnemyReaction && !(behaviorTreeEntity IsAtCoverNodeStrict());
}

/*
///BehaviorUtilityDocBegin
"Name: hasWeaponMalfunctioned \n"
"Summary: returns true if AI has malfunction state.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function hasWeaponMalfunctioned( behaviorTreeEntity )
{
	return( IS_TRUE( behaviorTreeEntity.malFunctionReaction ) );
}

/*
///BehaviorUtilityDocBegin
"Name: isSafeFromGrenades\n"
"Summary: returns if the AI is safe from grenades.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isSafeFromGrenades( entity )
{
	if( IsDefined( entity.grenade ) &&
		IsDefined( entity.grenade.weapon ) &&
		entity.grenade !== entity.knownGrenade &&
		!entity IsSafeFromGrenade() )
	{
		if ( IsDefined( entity.node ) )
		{
			offsetOrigin = entity GetNodeOffsetPosition( entity.node );
		
			// If the entity is going towards a node, check if the node is safe from a grenade.
			percentRadius = Distance( entity.grenade.origin, offsetOrigin );
			
			if ( entity.grenadeAwareness >= percentRadius )
			{
				return true;
			}
		}
		else
		{
			percentRadius = Distance( entity.grenade.origin, entity.origin ) / entity.grenade.weapon.explosionradius;
			
			if ( entity.grenadeAwareness >= percentRadius )
			{
				return true;
			}
		}
		
		entity.knownGrenade = entity.grenade;
		return false;
	}
		
	// if this AI is not supposed to be aware of the grenades then just assume that he is safe.
	return true;	
}

/*
///BehaviorUtilityDocBegin
"Name: inGrenadeBlastRadius\n"
"Summary: returns true if the AI is within the blast radius of an enemy grenade.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function inGrenadeBlastRadius( entity )
{
	return !entity IsSafeFromGrenade();
}

/*
///BehaviorUtilityDocBegin
"Name: recentlySawEnemy \n"
"Summary: returns true if an AI has recently seen the enemy (within 4 sec).\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function recentlySawEnemy( behaviorTreeEntity )
{
	const RECENTLY_SEEN_TIME = 6;
	
	if( IsDefined( behaviorTreeEntity.enemy ) && behaviorTreeEntity SeeRecently( behaviorTreeEntity.enemy, RECENTLY_SEEN_TIME ) )
		return true;
	
	return false;	
}

/*
///BehaviorUtilityDocBegin
"Name: shouldOnlyFireAccurately \n"
"Summary: returns at the aitype accurateFire flag.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldOnlyFireAccurately( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.accurateFire ) )
		return true;
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: shouldBeAggressive \n"
"Summary: returns at the aitype agressiveMode flag.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldBeAggressive( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.aggressiveMode ) )
		return true;
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: useCoverNodeWrapper \n"
"Summary: Tells an actor to use a given cover node. Also updates nextFindBestCoverTime based on engagement distance.\n"
"MandatoryArg: node\n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function useCoverNodeWrapper( behaviorTreeEntity, node )
{
	sameNode = behaviorTreeEntity.node === node;

	behaviorTreeEntity UseCoverNode( node );		
	
	if ( !sameNode )
	{
		// TODO(David Young 4-10-14): This fixes issues where cover_mode is still set to cover_alert
		// even when AI's are walking around.  Need to find a better way of doing this.
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE, COVER_MODE_NONE );
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_MODE, COVER_MODE_NONE );
	}
	
	setNextFindBestCoverTime( behaviorTreeEntity, node );
}

function setNextFindBestCoverTime( behaviorTreeEntity, node )
{
	// Optimized to code as this function rose to the top of time spent in script VM
	behaviorTreeEntity.nextFindBestCoverTime = behaviorTreeEntity GetNextFindBestCoverTime( behaviorTreeEntity.engageMinDist, behaviorTreeEntity.engagemaxdist, behaviorTreeEntity.coversearchinterval );
}

/*
///BehaviorUtilityDocBegin
"Name: trackCoverParamsService \n"
"Summary: tracks behaviorTreeEntity.coverNode and nextFindBestCoverTime.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function trackCoverParamsService( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.node ) 
	   && behaviorTreeEntity IsAtCoverNodeStrict() 
	   && behaviorTreeEntity ShouldUseCoverNode() )
	{
		if( !IsDefined( behaviorTreeEntity.coverNode ) )
		{
			behaviorTreeEntity.coverNode = behaviorTreeEntity.node;
			setNextFindBestCoverTime( behaviorTreeEntity, behaviorTreeEntity.node );
		}
		
		return;
	}
	
	behaviorTreeEntity.coverNode = undefined;	
}


function chooseBestCoverNodeASAP( behaviorTreeEntity )
{
	if( !IsDefined( behaviorTreeEntity.enemy ) )
		return false;
	
	node = AiUtility::getBestCoverNodeIfAvailable( behaviorTreeEntity );
	if ( IsDefined( node ) )
	{
		useCoverNodeWrapper( behaviorTreeEntity, node );
	}
}

/*
///BehaviorUtilityDocBegin
"Name: shouldChooseBetterCover \n"
"Summary: Returns true if AI should find a better cover node soon.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldChooseBetterCover( behaviorTreeEntity )
{			
	const NEAR_ARRIVAL_DIST_SQ = 64 * 64;		
	
	if( behaviorTreeEntity ai::has_behavior_attribute( "stealth" ) 
	    && behaviorTreeEntity ai::get_behavior_attribute( "stealth" ) )
	{
		return false;
	}	

	if ( IS_TRUE( behaviorTreeEntity.avoid_cover ) )
	{
		return false;
	}
	
	if( behaviorTreeEntity IsInAnyBadPlace() )
	{
		return true;
	}
		
	if( IsDefined( behaviorTreeEntity.enemy ) )
	{
		shouldUseCoverNodeResult		= false;
		shouldBeBoredAtCurrentCover 	= false;	
		aboutToArriveAtCover 			= false; 
		isWithinEffectiveRangeAlready 	= false;
		isLookingAroundForEnemy			= false;
				
		// SHOULD HOLD GROUND AGAINST THE ENEMY - Withing pathEnemyFightDist
		if( behaviorTreeEntity ShouldHoldGroundAgainstEnemy() )
			return false;
			
		// ABOUT TO ARRIVE AT COVER	
		if( behaviorTreeEntity HasPath() && IsDefined( behaviorTreeEntity.arrivalFinalPos ) && IsDefined( behaviorTreeEntity.pathGoalPos ) && self.pathGoalPos == behaviorTreeEntity.arrivalFinalPos )
		{
			if( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.arrivalFinalPos ) < NEAR_ARRIVAL_DIST_SQ )
			{
				aboutToArriveAtCover = true;	
			}
		}
					
		// COVER RANGES ARE VALID
		shouldUseCoverNodeResult = behaviorTreeEntity ShouldUseCoverNode();
		
		// ONLY CARE FOR ENGAGEMENT DISTANCE AND LOOKING AROUND IF WITHIN THE GOAL
		if( self IsAtGoal() )
		{
			// IS WITHIN APPROPRIATE ENGAGEMENT DISTANCE BAND
			if( shouldUseCoverNodeResult && IsDefined( behaviorTreeEntity.node ) && self IsAtGoal() )
			{
				lastKnownPos = behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy );
				
				dist = Distance2D( behaviorTreeEntity.origin, lastKnownPos );
				
				if( dist > behaviorTreeEntity.engageMinFalloffDist && dist <= behaviorTreeEntity.engageMaxFalloffDist )
					isWithinEffectiveRangeAlready = true;
			}
			
			// SHOULD BE BORED AT CURRENT COVER
			shouldBeBoredAtCurrentCover = !isWithinEffectiveRangeAlready && behaviorTreeEntity IsAtCoverNode() && ( GetTime() > self.nextFindBestCoverTime );
			
			// IS LOOKING AROUND ENEMY AND FRUSTRATED
			if( !shouldUseCoverNodeResult )
			{
				if( IsDefined( behaviorTreeEntity.frustrationLevel ) && behaviorTreeEntity.frustrationLevel > 0 && behaviorTreeEntity HasPath() )
					isLookingAroundForEnemy = true;
			}
		}
		
		shouldLookForBetterCover = !isLookingAroundForEnemy 
									&& !aboutToArriveAtCover 
									&& !isWithinEffectiveRangeAlready
									&& ( !shouldUseCoverNodeResult || shouldBeBoredAtCurrentCover || !self IsAtGoal() );
	
		/#	
		if( shouldLookForBetterCover )
			color = GREEN;
		else
			color = RED;
		
		recordEntText( "ChooseBetterCoverReason: SUC:" + shouldUseCoverNodeResult 
			           + " LAE:" + isLookingAroundForEnemy
			           + " ARR:" + aboutToArriveAtCover
			           + " EFF:" + isWithinEffectiveRangeAlready
			           + " BOR:" + shouldBeBoredAtCurrentCover
			           , behaviorTreeEntity, color, "Animscript" );
		#/			
	}
	else
	{
		return !( behaviorTreeEntity ShouldUseCoverNode() && behaviorTreeEntity IsApproachingGoal() );
	}
	
	return shouldLookForBetterCover;
}


/*
///BehaviorUtilityDocBegin
"Name: chooseBetterCoverServiceCodeVersion \n"
"Summary: Finds a better cover node using faster code version.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function chooseBetterCoverServiceCodeVersion( behaviorTreeEntity )
{
	if( isDefined( behaviorTreeEntity.stealth ) && behaviorTreeEntity ai::get_behavior_attribute( "stealth" ) )
	{
		return false;
	}

	if ( IS_TRUE( behaviorTreeEntity.avoid_cover ) )
	{
		return false;
	}
	
	if ( IsDefined( behaviorTreeEntity.knownGrenade ) )
	{
		// Don't choose a new cover if the AI is already reacting to a grenade.
		return false;
	}

	if ( !aiutility::isSafeFromGrenades( behaviorTreeEntity ) )
	{
		// Force a new cover selection if not safe from a grenade.
		behaviorTreeEntity.nextFindBestCoverTime = 0;
	}

	newNode = behaviorTreeEntity ChooseBetterCoverNode();

	if( IsDefined( newNode ) )
	{			
		useCoverNodeWrapper( behaviorTreeEntity, newNode );
		return true;		
	}

	setNextFindBestCoverTime( behaviorTreeEntity, undefined );

	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: chooseBetterCoverService \n"
"Summary: Finds a better cover node.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function private chooseBetterCoverService( behaviorTreeEntity )
{		
	shouldChooseBetterCoverResult = shouldChooseBetterCover( behaviorTreeEntity );
			
	// Only search for a new cover node if the AI isn't trying to keep their current claimed node.
	if( shouldChooseBetterCoverResult && !behaviorTreeEntity.keepClaimedNode	)
	{			
		transitionRunning = behaviorTreeEntity ASMIsTransitionRunning();
		subStatePending = behaviorTreeEntity ASMIsSubStatePending();
		transDecRunning = behaviorTreeEntity AsmIsTransDecRunning();
		isBehaviorTreeInRunningState = behaviorTreeEntity GetBehaviortreeStatus() == BHTN_RUNNING;
	
		if( !transitionRunning && !subStatePending && !transDecRunning && isBehaviorTreeInRunningState )
		{			
			node = AiUtility::getBestCoverNodeIfAvailable( behaviorTreeEntity );
			goingToDifferentNode =  IsDefined( node ) && ( !IsDefined( behaviorTreeEntity.node ) || node != behaviorTreeEntity.node );
					
			if ( goingToDifferentNode )
			{
				useCoverNodeWrapper( behaviorTreeEntity, node );
				return true;
			}			
			
			// Set the next find time, even though we did not find a cover to go to
			setNextFindBestCoverTime( behaviorTreeEntity, undefined );
		}
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: refillAmmo \n"
"Summary: Refills the bullets in clip of the AI.\n"
"MandatoryArg: AI behaviorTreeEntity\n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function refillAmmo( behaviorTreeEntity )
{
	if ( behaviorTreeEntity.weapon != level.weaponNone )
	{
		behaviorTreeEntity.bulletsInClip = behaviorTreeEntity.weapon.clipSize;
	}
}

/*
///BehaviorUtilityDocBegin
"Name: hasAmmo \n"
"Summary: Returns true if AI has any ammo left.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function hasAmmo( behaviorTreeEntity )
{
	if( behaviorTreeEntity.bulletsInClip > 0 )
		return true;
	else
		return false;
}

function hasLowAmmo( behaviorTreeEntity )
{
	if ( behaviorTreeEntity.weapon != level.weaponNone )
	{
		return behaviorTreeEntity.bulletsInClip < (behaviorTreeEntity.weapon.clipSize * 0.2);
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: HasEnemy \n"
"Summary: Returns true if AI has enemy.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function hasEnemy( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.enemy ) )
	{		
		return true;
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: getBestCoverNodeIfAvailable \n"
"Summary: Get a good covernode to take against enemy.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function getBestCoverNodeIfAvailable( behaviorTreeEntity )
{
	node = behaviorTreeEntity FindBestCoverNode();
		
	if ( !IsDefined(node) )
	{
		return undefined;
	}
	
	if( behaviorTreeEntity NearClaimNode() )
	{
		currentNode = self.node;
	}
	
	if ( IsDefined( currentNode ) && node == currentNode )
	{
		return undefined;
	}
	
	// work around FindBestCoverNode() resetting my .node in rare cases involving overlapping nodes
	// This prevents us from thinking we've found a new node somewhere when in reality it's the one we're already at, so we won't abort our script.
	if ( IsDefined( behaviorTreeEntity.coverNode ) && node == behaviorTreeEntity.coverNode )
	{
		return undefined;
	}
	
	return node;
}

function getSecondBestCoverNodeIfAvailable( behaviorTreeEntity )
{
	// when fixed node is set, AI should not try to find a better cover on its own.
	if( IsDefined( behaviorTreeEntity.fixedNode ) && behaviorTreeEntity.fixedNode )
		return undefined;
		
	nodes = behaviorTreeEntity FindBestCoverNodes( behaviorTreeEntity.goalRadius, behaviorTreeEntity.origin );
		
	if ( nodes.size > 1 )
	{
		node = nodes[1];
	}
		
	if ( !IsDefined(node) )
	{
		return undefined;
	}
	
	if( behaviorTreeEntity NearClaimNode() )
	{
		currentNode = self.node;
	}
	
	if ( IsDefined( currentNode ) && node == currentNode )
	{
		return undefined;
	}
	
	// work around FindBestCoverNode() resetting my .node in rare cases involving overlapping nodes
	// This prevents us from thinking we've found a new node somewhere when in reality it's the one we're already at, so we won't abort our script.
	if ( IsDefined( behaviorTreeEntity.coverNode ) && node == behaviorTreeEntity.coverNode )
	{
		return undefined;
	}
	
	return node;
}

/*
///BehaviorUtilityDocBegin
"Name: getCoverType \n"
"Summary: returns a covernode type.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function getCoverType( node )
{
	if( IsDefined( node ) )
	{			
		if( NODE_COVER_PILLAR( node ) )
			return COVER_PILLAR;
		else if( NODE_COVER_LEFT( node ) )			
			return COVER_LEFT;
		else if( NODE_COVER_RIGHT( node ) )			
			return COVER_RIGHT;
		else if( NODE_COVER_STAND( node ) )			
			return COVER_STAND;
		else if( NODE_COVER_CROUCH( node ) )				
			return COVER_CROUCH;
		else if( NODE_EXPOSED( node ) || NODE_GUARD( node ) )
			return COVER_EXPOSED;				
	}
	
	return COVER_NONE;
}

/*
///BehaviorUtilityDocBegin
"Name: isCoverConcealed \n"
"Summary: checks if node is a concealed node.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isCoverConcealed( node )
{
	if ( IsDefined( node ) )
	{
		return NODE_CONCEALED( node );
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: canSeeEnemyWrapper \n"
"Summary: checks if the enemy can be seen from a node or from exposed.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function canSeeEnemyWrapper()
{
	if( !IsDefined( self.enemy ) )
		return false;
	
	if( !IsDefined( self.node ) )
	{
		return self canSee( self.enemy );
	}
	else
	{
		node = self.node;		
		enemyEye = self.enemy GetEye();
		yawToEnemy = GET_YAW_TO_ORIGIN180( node, enemyEye );
		
		// check corner yaw first
		if( NODE_COVER_LEFT(node) || NODE_COVER_RIGHT(node) )
		{
			// we don't need anything like this for pillar as we switch sides if needed.	
			if( yawToEnemy > COVER_CORNER_VALID_YAW_RANGE_MAX || yawToEnemy < -COVER_CORNER_VALID_YAW_RANGE_MAX )
				return false;
				
			// if this is stand node, then AI can not shoot in "Over" mode
			if( NODE_SUPPORTS_STANCE_STAND(node) )
			{
				if( NODE_COVER_LEFT(node) && yawToEnemy > COVER_CORNER_VALID_YAW_RANGE_MIN )
				{
					///# recordLine( self.origin, self.enemy.origin, RED, "Animscript", self ); #/
					return false;
				}
				
				if( NODE_COVER_RIGHT(node) && yawToEnemy < -COVER_CORNER_VALID_YAW_RANGE_MIN )
				{
					///# recordLine( self.origin, self.enemy.origin, RED, "Animscript", self ); #/
					return false;
				}
			}
		}
		
		nodeOffset = (0,0,0);
				
		if( NODE_COVER_PILLAR(node) )
		{
			Assert( !ISNODEDONTRIGHT(node) || !ISNODEDONTLEFT(node) );
			canSeeFromLeft = true;
			canSeeFromRight = true;
			
			// PILLAR LEFT		
			nodeOffset = COVER_PILLAR_LEFT_OFFSET;
			lookFromPoint = calculateNodeOffsetPosition( node, nodeOffset );
			canSeeFromLeft = sightTracePassed( lookFromPoint, enemyEye, false, undefined );
		
			// PILLAR RIGHT		
			nodeOffset = COVER_PILLAR_RIGHT_OFFSET;
			lookFromPoint = calculateNodeOffsetPosition( node, nodeOffset );
			canSeeFromRight = sightTracePassed( lookFromPoint, enemyEye, false, undefined );
		
			return ( canSeeFromRight || canSeeFromLeft );
		}
		else 
		{
			if( NODE_COVER_LEFT(node) )
			{
				nodeOffset = COVER_LEFT_OFFSET;
			}
			else if( NODE_COVER_RIGHT(node) )
			{
				nodeOffset = COVER_RIGHT_OFFSET;
			}
			else if( NODE_COVER_STAND(node) )
			{
				nodeOffset = COVER_STAND_OFFSET;
			}
			else if( NODE_COVER_CROUCH(node) )
			{
				nodeOffset = COVER_CROUCH_OFFSET;
			}
			
			lookFromPoint = calculateNodeOffsetPosition( node, nodeOffset );
						
			if( sightTracePassed( lookFromPoint, enemyEye, false, undefined ) )
			{
				///# recordLine( lookFromPoint, self.enemy.origin, GREEN, "Animscript", self ); #/
				return true;
			}
			else
			{
				///# recordLine( lookFromPoint, self.enemy.origin, RED, "Animscript", self ); #/
				return false;
			}
		}
	
	}
}

function calculateNodeOffsetPosition( node, nodeOffset )
{
	right 	= AnglesToRight( node.angles );
	forward = AnglesToForward( node.angles );
		
	return node.origin + VectorScale( right, nodeOffset[0] ) + VectorScale( forward, nodeOffset[1] ) + ( 0, 0, nodeOffset[2] );
}

/*
///BehaviorUtilityDocBegin
"Name: getHighestNodeStance \n"
"Summary: returns the highest stance allowed at a given cover node.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function getHighestNodeStance( node ) 
{
	assert( IsDefined( node ) );

	if( NODE_SUPPORTS_STANCE_STAND(node) ) // check for stand
		return "stand";
	
	if( NODE_SUPPORTS_STANCE_CROUCH(node) ) // check for crouch
		return "crouch";
	
	if( NODE_SUPPORTS_STANCE_PRONE(node) ) // check for crouch
		return "prone";
	
	/#
	ErrorMsg( node.type + " node at"  + node.origin + " supports no stance." );
	#/
	
	// Fallback just in case there are no valid spawn flags(bad node).
	if ( NODE_COVER_CROUCH( node ) )
	{
		return "crouch";
	}
	
	return "stand";
}

/*
///BehaviorUtilityDocBegin
"Name: isStanceAllowedAtNode \n"
"Summary: returns whether a given stance is allowed at a given cover node.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isStanceAllowedAtNode( stance, node )
{
	assert( IsDefined( stance ) );
	assert( IsDefined( node ) );

	if( stance == STANCE_STAND && NODE_SUPPORTS_STANCE_STAND( node ) )
		return true;
	
	if( stance == STANCE_CROUCH && NODE_SUPPORTS_STANCE_CROUCH( node ) )
		return true;

	if( stance == STANCE_PRONE && NODE_SUPPORTS_STANCE_PRONE( node ) )
		return true;

	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: tryStoppingService \n"
"Summary: Clears the path if enemy is within pathEnemyFightDist.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function tryStoppingService( behaviorTreeEntity )
{
	if ( behaviorTreeEntity ShouldHoldGroundAgainstEnemy() )
	{
		behaviorTreeEntity ClearPath();
		behaviorTreeEntity.keepClaimedNode = true;
		return true;
	}

	behaviorTreeEntity.keepClaimedNode = false;
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: shouldStopMoving \n"
"Summary: Return true if enemy is within pathEnemyFightDist.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldStopMoving( behaviorTreeEntity )
{
	if ( behaviorTreeEntity ShouldHoldGroundAgainstEnemy() ) 
	{
		return true;
	}

	return false;
}

function setCurrentWeapon(weapon)
{
	self.weapon = weapon;
	self.weaponclass = weapon.weapClass;
	
	if( weapon != level.weaponNone )
		assert( IsDefined( weapon.worldModel ), "Weaopon " + weapon.name + " has no world model set in GDT." );
	
	self.weaponmodel = weapon.worldModel;
}

function setPrimaryWeapon(weapon)
{
	self.primaryweapon = weapon;
	self.primaryweaponclass = weapon.weapClass;
	
	if( weapon != level.weaponNone )
		assert( IsDefined( weapon.worldModel ), "Weaopon " + weapon.name + " has no world model set in GDT." );
}

function setSecondaryWeapon(weapon)
{
	self.secondaryweapon = weapon;
	self.secondaryweaponclass = weapon.weapClass;
	
	if( weapon != level.weaponNone )
		assert( IsDefined( weapon.worldModel ), "Weaopon " + weapon.name + " has no world model set in GDT." );
}

function keepClaimNode( behaviorTreeEntity )
{
	behaviorTreeEntity.keepClaimedNode = true;
	
	return true;
}

function releaseClaimNode( behaviorTreeEntity )
{
	behaviorTreeEntity.keepClaimedNode = false;
	
	return true;
}

/**
 * Returns the yaw angles between a node and an enemy behaviorTreeEntity
 */
function getAimYawToEnemyFromNode( behaviorTreeEntity, node, enemy )
{
	return AngleClamp180( VectorToAngles( ( behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) ) - node.origin )[1] - node.angles[1] );
}

/**
 * Returns the pitch angles between a node and an enemy behaviorTreeEntity
 */
function getAimPitchToEnemyFromNode( behaviorTreeEntity, node, enemy )
{
	return AngleClamp180( VectorToAngles( ( behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) ) - node.origin )[0] - node.angles[0] );
}


/**
 * Sets the cover direction blackboard to the front direction
 */
function chooseFrontCoverDirection( behaviorTreeEntity )
{
	coverDirection = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_DIRECTION );
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PREVIOUS_COVER_DIRECTION, coverDirection );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, COVER_DIRECTION, COVER_FRONT_DIRECTION );
}

/*
///BehaviorUtilityDocBegin
"Name: shouldTacticalWalk \n"
"Summary: returns true if AI should tactical walk facing the enemy/target.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldTacticalWalk( behaviorTreeEntity )
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

	if ( ai::HasAiAttribute( behaviorTreeEntity, "disablesprint" ) &&
		!ai::GetAiAttribute( behaviorTreeEntity, "disablesprint" ) )
	{
		// if the script interface needs sprinting
		if ( ai::HasAiAttribute( behaviorTreeEntity, "sprint" ) &&
			ai::GetAiAttribute( behaviorTreeEntity, "sprint" ) )
		{
			return false;
		}
	}

	goalPos = undefined;
	
	if( IsDefined( behaviorTreeEntity.arrivalFinalPos ) )
		goalPos = behaviorTreeEntity.arrivalFinalPos;
	else
		goalPos = behaviorTreeEntity.pathGoalPos;
	
	// for moving short distances
	if( Isdefined( behaviorTreeEntity.pathStartPos ) && Isdefined( goalPos ) )
	{
		pathDist = DistanceSquared( behaviorTreeEntity.pathStartPos, goalPos );
		
		if( pathDist < TACTICAL_WALK_SHORT_DIST_SQ )
		{
			return true;
		}
	}

	if( behaviorTreeEntity ShouldFaceMotion() )
	{
		return false;
	}
	
	if ( !behaviorTreeEntity IsSafeFromGrenade() )
	{
		return false;
	}
	
	return true;
}

/*
///BehaviorUtilityDocBegin
"Name: shouldStealth \n"
"Summary: returns true if AI should be doing stealth behavior.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldStealth( behaviorTreeEntity )
{
	if ( isDefined( behaviorTreeEntity.stealth ) )
	{
		now = GetTime();
		
		if ( behaviorTreeEntity IsInScriptedState() )
			return false;
		
		// Make sure that while transitioning from stealth to combat the stealth reaction still takes place
		if ( behaviorTreeEntity HasValidInterrupt( "react" ) )
		{
			behaviorTreeEntity.stealth_react_last = now;
			return true;
		}	
		if ( IS_TRUE( behaviorTreeEntity.stealth_reacting ) || ( isDefined( behaviorTreeEntity.stealth_react_last ) && ( now - behaviorTreeEntity.stealth_react_last ) < 250 ) )
		{
			return true;
		}
		
		if( behaviorTreeEntity ai::has_behavior_attribute( "stealth" ) 
		    && behaviorTreeEntity ai::get_behavior_attribute( "stealth" ) )
		{
			return true;
		}
	}

	return false;
}

/*
///locomotionShouldStealth
"Name: locomotionShouldStealth \n"
"Summary: returns true if AI should be moving along a path in stealth.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function locomotionShouldStealth( behaviorTreeEntity )
{
	if ( !shouldStealth( behaviorTreeEntity ) )
		return false;

	if( behaviorTreeEntity HasPath() )
	{ 
		if ( isDefined( behaviorTreeEntity.arrivalFinalPos ) || isDefined( behaviorTreeEntity.pathGoalPos ) )
		{
			hasWait = ( isDefined( self.currentgoal ) && isDefined( self.currentgoal.script_wait_min ) && isDefined( self.currentgoal.script_wait_max ) );
			if ( hasWait )
				hasWait = self.currentgoal.script_wait_min > 0 || self.currentgoal.script_wait_max > 0;

			if ( hasWait || !isDefined( self.currentgoal ) || ( isDefined( self.currentgoal ) && isDefined( self.currentgoal.scriptbundlename ) ) )
			{
				// Needs to stop at current goal
				goalPos = undefined;
				if( IsDefined( behaviorTreeEntity.arrivalFinalPos ) )
					goalPos = behaviorTreeEntity.arrivalFinalPos;
				else
					goalPos = behaviorTreeEntity.pathGoalPos;
		
				goalDistSq = DistanceSquared( behaviorTreeEntity.origin, goalPos );

				// FIXME: base this on arrival animation movement delta?
				if ( goalDistSq <= ( 44 * 44 ) && ( goalDistSq <= behaviorTreeEntity.goalradius * behaviorTreeEntity.goalradius ) )
					return false; // do arrival and stop
			}
		}
		
		return true;
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: shouldStealthResume \n"
"Summary: returns true if AI is resuming back to less aware status.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function shouldStealthResume( behaviorTreeEntity )
{
	if ( !shouldStealth( behaviorTreeEntity ) )
		return false;
	
	if ( IS_TRUE( behaviorTreeEntity.stealth_resume ) )
	{
		behaviorTreeEntity.stealth_resume = undefined;
		return true;
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: stealthReactCondition \n"
"Summary: returns true if AI should react to spotting/hearing something.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function private stealthReactCondition( entity )
{
	inScene = ( isDefined( self._o_scene ) && isDefined( self._o_scene._str_state ) && self._o_scene._str_state == "play" );
	
	return ( !IS_TRUE( entity.stealth_reacting ) && entity HasValidInterrupt( "react" ) && !inScene );
}

/*
///BehaviorUtilityDocBegin
"Name: stealthReactStart \n"
"Summary: called when actor starts reacting to stealth alert event.\n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function private stealthReactStart( behaviorTreeEntity )
{
	behaviorTreeEntity.stealth_reacting = true;
}

/*
///BehaviorUtilityDocBegin
"Name: stealthReactTerminate \n"
"Summary: called when actor finishes reacting to stealth alert event.\n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function private stealthReactTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity.stealth_reacting = undefined;
}

/*
///BehaviorUtilityDocBegin
"Name: stealthIdleTerminate \n"
"Summary: called when actor finishes a stealth idle anim.\n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function private stealthIdleTerminate( behaviorTreeEntity )
{
	behaviortreeentity notify("stealthIdleTerminate");
	
	if ( IS_TRUE( behaviortreeentity.stealth_resume_after_idle ) )
	{
		behaviortreeentity.stealth_resume_after_idle = undefined;
		behaviortreeentity.stealth_resume = true;
	}
}

/*
///BehaviorUtilityDocBegin
"Name: locomotionShouldPatrol \n"
"Summary: returns true if AI should patrol walk.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function locomotionShouldPatrol( behaviorTreeEntity )
{
	// Stealth state takes precedence over normal patrol state
	if ( shouldStealth( behaviortreeentity ) )
		return false;

	// if the script interface needs patrol
	if( behaviorTreeEntity HasPath() &&
		behaviorTreeEntity ai::has_behavior_attribute( "patrol" ) 
	    && behaviorTreeEntity ai::get_behavior_attribute( "patrol" ) )
	{
		return true;
	}
	
	return false;
}


/*
///BehaviorUtilityDocBegin
"Name: explosiveKilled \n"
"Summary: returns true if AI was killed by an explosive weapon.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function explosiveKilled( behaviorTreeEntity )
{
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, DAMAGE_WEAPON_CLASS ) == "explosive" )
	{
		return true;
	}
	
	return false;	
}

function private _dropRiotShield( riotshieldInfo )
{
	entity = self;

	entity shared::ThrowWeapon( riotshieldInfo.weapon, riotshieldInfo.tag, false );
	
	if ( IsDefined( entity ) )
	{
		entity Detach( riotshieldInfo.model, riotshieldInfo.tag );
	}
}

/*
///BehaviorUtilityDocBegin
"Name: attachRiotshield \n"
"Summary: Attaches a riotshield to the AI.\n"
"MandatoryArg: <entity> : Entity to attach the riotshield to.\n"
"MandatoryArg: <weapon> : Specific riotshield weapon, used for dropping.\n"
"MandatoryArg: <string> : Model to attach to the entity.\n"
"MandatoryArg: <string> : Tag to attach the riotshield to.\n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function attachRiotshield( entity, riotshieldWeapon, riotshieldModel, riotshieldTag )
{
	riotshield = SpawnStruct();
	riotshield.weapon = riotshieldWeapon;
	riotshield.tag = riotshieldTag;
	riotshield.model = riotshieldModel;

	entity Attach( riotshieldModel, riotshield.tag );
	
	entity.riotshield = riotshield;
}

/*
///BehaviorUtilityDocBegin
"Name: dropRiotshield \n"
"Summary: Drops the AI's riotshield if the AI has a riotshield.\n"
"MandatoryArg: <entity> : Entity to drop the riotshield from.\n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function dropRiotshield( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.riotshield ) )
	{
		riotshieldInfo = behaviorTreeEntity.riotshield;
	
		behaviorTreeEntity.riotshield = undefined;
		behaviorTreeEntity thread _dropRiotShield( riotshieldInfo );
	}
}


/*
///BehaviorUtilityDocBegin
"Name: electrifiedKilled \n"
"Summary: returns true if AI was killed by an electrified weapon.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function electrifiedKilled( behaviorTreeEntity )
{
	if(  behaviorTreeEntity.damageweapon.rootweapon.name == "shotgun_pump_taser" )
	{
		return true;
	}
	
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, DAMAGE_MOD ) == "mod_electrocuted" )
	{
		return true;
	}
	
	return false;
	
}

/*
///BehaviorUtilityDocBegin
"Name: burnedKilled \n"
"Summary: returns true if AI was killed by flames.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function burnedKilled( behaviorTreeEntity )
{
	if( Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, DAMAGE_MOD ) == "mod_burned" )
	{
		return true;
	}
	
	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: rapsKilled \n"
"Summary: returns true if AI was killed by a Raps explosion.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function rapsKilled( behaviorTreeEntity )
{
	if( isDefined(self.attacker) && isDefined(self.attacker.archetype) && self.attacker.archetype == ARCHETYPE_VEHICLE_RAPS)
	{
		return true;
	}
	
	return false;
}


// ------- EXPOSED - MELEE MUTEX -----------//
function meleeAcquireMutex( behaviorTreeEntity )
{
	if( isDefined( behaviorTreeEntity ) && isDefined( behaviorTreeEntity.enemy ))
	{
		behaviorTreeEntity.melee = spawnStruct();
		behaviorTreeEntity.melee.enemy = behaviorTreeEntity.enemy;
		
		if( IsPlayer( behaviorTreeEntity.melee.enemy ) )
		{
			if( !isDefined( behaviorTreeEntity.melee.enemy.meleeAttackers) )
			{
				behaviorTreeEntity.melee.enemy.meleeAttackers = 0;
			}
			//assert( behaviorTreeEntity.enemy.meleeAttackers <= MAX_MELEE_PLAYER_ATTACKERS);
			behaviorTreeEntity.melee.enemy.meleeAttackers++;
		}
	}
}

function meleeReleaseMutex( behaviorTreeEntity )
{	
	if( isdefined(behaviorTreeEntity.melee) )
	{
		if( isdefined(behaviorTreeEntity.melee.enemy) )
		{
			if( IsPlayer( behaviorTreeEntity.melee.enemy ) )
			{
				if( isDefined( behaviorTreeEntity.melee.enemy.meleeAttackers) )
				{
					behaviorTreeEntity.melee.enemy.meleeAttackers = behaviorTreeEntity.melee.enemy.meleeAttackers - 1;
					if ( behaviorTreeEntity.melee.enemy.meleeAttackers <= 0 )
					{
						behaviorTreeEntity.melee.enemy.meleeAttackers = undefined;
					}
				}
			}
		}
		
		behaviorTreeEntity.melee = undefined;
	}
}


function shouldMutexMelee( behaviorTreeEntity )
{
	// Can't acquire when someone is targeting us for a melee
	if ( isDefined( behaviorTreeEntity.melee ) )
	{
		return false;
	}
	
	// Can't acquire enemy mutex if he's already in a melee process
	if ( isDefined( behaviorTreeEntity.enemy))
	{
		if( !isPlayer ( behaviorTreeEntity.enemy ))
		{
			if( isDefined( behaviorTreeEntity.enemy.melee ) )
			{
				return false;
			}
		}
		else
		{
			// Disregard the mutex melee check against the player when not in a campaign game.
			if ( !SessionModeIsCampaignGame() )
			{
				return true;
			}
		
			if (!isDefined( behaviorTreeEntity.enemy.meleeAttackers))
			{
				behaviorTreeEntity.enemy.meleeAttackers = 0;
			}
			
			return behaviorTreeEntity.enemy.meleeAttackers < MAX_MELEE_PLAYER_ATTACKERS;
		}
	}
	
	return true;
}

function shouldNormalMelee( behaviorTreeEntity)
{
	return AiUtility::hasCloseEnemyToMelee( behaviorTreeEntity );
}

#define SHOULD_MELEE_CHECK_TIME 50
function shouldMelee( entity )
{
	if ( IsDefined( entity.lastShouldMeleeResult ) &&
		!entity.lastShouldMeleeResult &&
		( entity.lastShouldMeleeCheckTime + SHOULD_MELEE_CHECK_TIME ) >= GetTime() )
	{
		// Last check was false, and very little time has progressed, return false.
		return false;
	}
	
	entity.lastShouldMeleeCheckTime = GetTime();
	entity.lastShouldMeleeResult = false;

	if ( !IsDefined( entity.enemy ) )
		return false;

	if ( !( entity.enemy.allowDeath ) )
		return false;
	
	if ( !IsAlive( entity.enemy ) )
		return false;
	
	if ( !IsSentient( entity.enemy ) )
		return false;
	
	if ( IsVehicle( entity.enemy ) && !IS_TRUE( entity.enemy.good_melee_target ) )
		return false;
	
	// Don't melee prone players.
	if ( IsPlayer( entity.enemy ) && entity.enemy GetStance() == "prone" )
		return false;
	
	chargeDistSQ = ( IsDefined( entity.melee_charge_rangeSQ) ? entity.melee_charge_rangeSQ : CHARGE_RANGE_SQ_VS_PLAYER );
	if( DistanceSquared( entity.origin, entity.enemy.origin ) > chargeDistSQ )
		return false;
	
	if( !AiUtility::shouldMutexMelee( entity ) )
		return false;
	
	if( ai::HasAiAttribute( entity, "can_melee" ) && !ai::GetAiAttribute( entity, "can_melee" ) )
		return false;
		
	if(	ai::HasAiAttribute( entity.enemy, "can_be_meleed" ) && !ai::GetAiAttribute( entity.enemy, "can_be_meleed" ) )
		return false;
	
	if( AiUtility::shouldNormalMelee( entity ) || AiUtility::shouldChargeMelee( entity ) )
	{
		entity.lastShouldMeleeResult = true;
		return true;
	}
			
	return false;
}

function hasCloseEnemyToMelee( entity )
{
	return hasCloseEnemyToMeleeWithRange( entity, MELEE_RANGE_SQ);
}


function hasCloseEnemyToMeleeWithRange( entity, melee_range_sq )
{
	assert( IsDefined( entity.enemy ) );
	
	if ( !entity CanSee( entity.enemy ) )
	{
		return false;
	}

	predicitedPosition = entity.enemy.origin + VectorScale(entity GetEnemyVelocity(), MELEE_ENEMY_DISTANCE_PREDICTION_TIME );
	distSQ = DistanceSquared( entity.origin, predicitedPosition );
	yawToEnemy = AngleClamp180( entity.angles[ 1 ] - GET_YAW( entity, entity.enemy.origin ) );
	
	//within 3feet, dont need the movetopoint check
	if( distSQ <= MELEE_NEAR_RANGE_SQ )
	{		
		return abs( yawToEnemy ) <= MELEE_YAW_THRESHOLDNEAR;
	}
	
	//less than minThresh and there isn't anything blocking us.
	if( distSQ <= melee_range_sq && entity MayMoveToPoint( entity.enemy.origin ) )  
	{			
		return abs( yawToEnemy ) <= MELEE_YAW_THRESHOLD;
	}	
	
	return false;
}

// ------- CHARGE MELEE -----------//
function shouldChargeMelee( entity )
{	
	assert( IsDefined( entity.enemy ) );
	
	currentStance = Blackboard::GetBlackBoardAttribute( entity, STANCE );
	if ( currentStance != STANCE_STAND )
		return false;
	
	if ( IsDefined( entity.nextChargeMeleeTime ) )
	{
		if ( GetTime() < entity.nextChargeMeleeTime )
			return false;
	}
	
	enemyDistSq = DistanceSquared( entity.origin, entity.enemy.origin );
	
	// already close, no need to charge
	if ( enemyDistSq < MELEE_RANGE_SQ )
		return false;
	
	// not trying to move to the EXACT location of enemy, just within close melee range
	offset = entity.enemy.origin - ( VectorNormalize( entity.enemy.origin - entity.origin) * MELEE_NEAR_RANGE);
	
	chargeDistSQ = (isDefined(entity.melee_charge_rangeSQ)?entity.melee_charge_rangeSQ:CHARGE_RANGE_SQ_VS_PLAYER);
	if ( enemyDistSq < chargeDistSQ && entity MayMoveToPoint(offset,true,true)  )
	{
		yawToEnemy = AngleClamp180( entity.angles[ 1 ] - GET_YAW( entity, entity.enemy.origin ) );
		return abs( yawToEnemy ) <= MELEE_YAW_THRESHOLD;
	}
	
	return false;
}

function private shouldAttackInChargeMelee( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.enemy ) )
	{
		if ( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) < BLEND_MELEE_RANGE_SQ )
		{
			yawToEnemy = AngleClamp180( behaviorTreeEntity.angles[ 1 ] - GET_YAW(behaviorTreeEntity, behaviorTreeEntity.enemy.origin ) );
			if ( abs( yawToEnemy ) > MELEE_YAW_THRESHOLD )
				return false;

			return true;
		}
	}
}

function private setupChargeMeleeAttack( behaviorTreeEntity )
{
	if(isDefined(behaviorTreeEntity.enemy) && isDefined(behaviorTreeEntity.enemy.vehicletype) && isSubStr(behaviorTreeEntity.enemy.vehicletype,"firefly") )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, MELEE_ENEMY_TYPE_FIREFLY);
	}
	aiutility::meleeAcquireMutex( behaviorTreeEntity );
	aiutility::keepClaimNode( behaviorTreeEntity );
}

function private cleanupMelee( behaviorTreeEntity )
{
	aiutility::meleeReleaseMutex( behaviorTreeEntity );
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, undefined);
}


function private cleanupChargeMelee( behaviorTreeEntity )
{
	behaviorTreeEntity.nextChargeMeleeTime = GetTime() + NEXT_CHARGE_MELEE_TIME;
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, undefined);

	aiutility::meleeReleaseMutex( behaviorTreeEntity );
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	
	// Dont move for a sec
	behaviorTreeEntity PathMode( "move delayed", true, RandomFloatRange( 0.75, 1.5 ) );
}

function cleanupChargeMeleeAttack( behaviorTreeEntity )
{
	AiUtility::meleeReleaseMutex( behaviorTreeEntity );
	AiUtility::releaseClaimNode( behaviorTreeEntity );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, MELEE_ENEMY_TYPE, undefined);
	
	// Dont move for a sec
	behaviorTreeEntity PathMode( "move delayed", true, RandomFloatRange( 0.5, 1 ) );
}
// ------- CHARGE MELEE -----------//

function private shouldChooseSpecialPronePain ( behaviorTreeEntity )
{
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	return (stance == STANCE_PRONE_ON_BACK || stance == STANCE_PRONE_ON_FRONT);
}

// ------- SPECIAL PAIN -----------//
function private shouldChooseSpecialPain( behaviorTreeEntity )
{	
	if(IsDefined( behaviorTreeEntity.damageWeapon )) 
	{
		return behaviorTreeEntity.damageWeapon.specialpain || isdefined(behaviorTreeEntity.special_weapon);
	}
			
	return false;
}

// ------- SPECIAL DEATH -----------//
function private shouldChooseSpecialDeath( behaviorTreeEntity )
{
	if(IsDefined( behaviorTreeEntity.damageWeapon )) 
	{
		return behaviorTreeEntity.damageWeapon.specialpain;
	}
	return false;
}

function private shouldChooseSpecialProneDeath( behaviorTreeEntity )
{
	stance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	return (stance == STANCE_PRONE_ON_BACK || stance == STANCE_PRONE_ON_FRONT);
}

function private setupExplosionAnimScale( entity, asmStateName )
{
	self.animtranslationScale = 2.0;
	self ASMSetAnimationRate( 0.7 );
	
	return BHTN_SUCCESS;
}

/*
///BehaviorUtilityDocBegin
"Name: isBalconyDeath \n"
"Summary: returns true if AI was killed while on a balcony node.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isBalconyDeath( behaviorTreeEntity )
{
	//do i have a node?
	if( !isDefined(behaviorTreeEntity.node) )
		return false;
	
	if(!((behaviorTreeEntity.node.spawnflags & SPAWNFLAG_PATH_BALCONY) || (behaviorTreeEntity.node.spawnflags & SPAWNFLAG_PATH_BALCONY_NORAILING)))
	{
		return false;
	}
	
	coverMode = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, COVER_MODE );

	// Don't trigger a balcony death when AI is idling at cover.
	if ( coverMode == COVER_ALERT_MODE || coverMode == COVER_MODE_NONE )
	{
		return false;
	}

	if (isDefined(behaviorTreeEntity.node.script_balconydeathchance) && RandomInt(100) > int(100.0 * behaviorTreeEntity.node.script_balconydeathchance))
		return false;

	//am i close enough to the cover node?
	distSQ = DistanceSquared(behaviorTreeEntity.origin,behaviorTreeEntity.node.origin);
	if (distSQ > SQR(16))
		return false;
	
	// get the closest player
	if(isDefined(level.players) && level.players.size > 0)
	{
		closest_player = util::get_closest_player( behaviorTreeEntity.origin, level.players[0].team);
		
		if(isDefined(closest_player))
		{
			//Am I in the same level as the closest player
			if(abs(closest_player.origin[2] - behaviorTreeEntity.origin[2]) < 100)
			{
				distance2DfromPlayerSq = Distance2DSquared(closest_player.origin, behaviorTreeEntity.origin);
				
				//Am I too close to that player
				if(distance2DfromPlayerSq < SQR(600))
				{
					return false;
				}
			}
		}
	}
	
	self.b_balcony_death = true;
	return true;
}


/*
///BehaviorUtilityDocBegin
"Name: balconyDeath \n"
"Summary: sets the BB special_death attribute to appropriate balcony type\n"
"MandatoryArg: AI behaviorTreeEntity\n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function balconyDeath( behaviorTreeEntity )
{	
	behaviorTreeEntity.clamptonavmesh = 0;

	if( behaviorTreeEntity.node.spawnflags & SPAWNFLAG_PATH_BALCONY )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, SPECIAL_DEATH, SPECIAL_DEATH_BALCONY);
	}
	else if( behaviorTreeEntity.node.spawnflags & SPAWNFLAG_PATH_BALCONY_NORAILING )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, SPECIAL_DEATH, SPECIAL_DEATH_BALCONY_NORAIL );
	}
}

function useCurrentPosition( entity )
{
	entity UsePosition( entity.origin );
}

/*
///BehaviorUtilityDocBegin
"Name: isUnarmed \n"
"Summary: returns true if AI doesn't have a weapon.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function isUnarmed( behaviorTreeEntity )
{
	if ( behaviorTreeEntity.weapon == level.weaponNone )
	{
		return true;
	}

	return false;
}

/*
///BehaviorUtilityDocBegin
"Name: forceRagdoll \n"
"Summary: Starts ragdoll on the entity.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///BehaviorUtilityDocEnd
*/
function forceRagdoll( entity )
{
	entity StartRagdoll();
}



function preShootLaserAndGlintOn( ai )
{
	self endon( "death" );
	if( !isDefined( ai.laserstatus ))
	{
		ai.laserstatus = false;
	}
	
	sniper_glint = "lensflares/fx_lensflare_sniper_glint";

	While( 1 )
	{		
		self waittill( "about_to_fire" );
		if( ai.laserstatus !== true )
		{
			ai LaserOn();
			ai.laserstatus = true;
			
			if( ai.team != "allies" )
			{
				tag = ai GetTagOrigin( "tag_glint");
				
				if( isDefined( tag ))
				{
					playfxontag( sniper_glint , ai , "tag_glint" );
				}
				else
				{
					type = STR( ai.classname );
					/#println( "AI " + type + " does not have a tag_glint to play sniper glint effects from, playing from tag_eye" );#/
					playfxontag( sniper_glint , ai , "tag_eye" );
				}
			}
		}
	}
	
}


function postShootLaserAndGlintOff( ai )
{
	self endon( "death" );

	While( 1 )
	{		
		self waittill( "stopped_firing" );
		if( ai.laserstatus === true )
		{
			ai LaserOff();
			ai.laserstatus = false;
		}
	}
	
}

function private isInPhalanx( entity )
{
	return entity ai::get_behavior_attribute( "phalanx" );
}

function private isInPhalanxStance( entity )
{
	phalanxStance = entity ai::get_behavior_attribute( "phalanx_force_stance" );
	currentStance = Blackboard::GetBlackBoardAttribute( entity, STANCE );
	
	switch ( phalanxStance )
	{
		case "stand":
			return currentStance == STANCE_STAND;
		case "crouch":
			return currentStance == STANCE_CROUCH;
	}
	
	return true;
}

function private togglePhalanxStance( entity )
{
	phalanxStance = entity ai::get_behavior_attribute( "phalanx_force_stance" );
	
	switch ( phalanxStance )
	{
		case "stand":
			Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_STAND );
			break;
		case "crouch":
			Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, STANCE_CROUCH );
			break;
	}
}

function private tookFlashbangDamage( entity )
{
	if ( IsDefined( entity.damageweapon ) && IsDefined( entity.damagemod ) )
	{
		weapon = entity.damageweapon;
		
		return entity.damagemod == "MOD_GRENADE_SPLASH" &&
			IsDefined( weapon.rootweapon ) &&
			( IsSubStr( weapon.rootweapon.name, "flash_grenade" ) ||
			IsSubStr( weapon.rootweapon.name, "concussion_grenade" ) ||
			IsSubStr( weapon.rootweapon.name, "proximity_grenade" ) );		//checking substring for flashbang grenade variant;  probably this should be a gdt checkbox 'flashbang damage' or similar
	}
	return false;
}

function isAtAttackObject( entity )
{
	if ( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) )
	{
		return false;
	}

	if ( IsDefined( entity.attackable ) && IS_TRUE( entity.attackable.is_active ) )
	{
		if ( !IsDefined( entity.attackable_slot ) )
		{
			return false;
		}

		if ( entity IsAtGoal() )
		{
			entity.is_at_attackable = true;
			return true;
		}
	}

	return false;
}

function shouldAttackObject( entity )
{
	if ( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) )
	{
		return false;
	}

	if ( IsDefined( entity.attackable ) && IS_TRUE( entity.attackable.is_active ) )
	{
		if ( IS_TRUE( entity.is_at_attackable ) )
		{
			return true;
		}
	}

	return false;
}

