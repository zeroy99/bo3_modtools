/*
 * AI VS AI MELEE SYSTEM
 * The AI vs AI Melee system is initiated from the behavior tree.
 * A set of conditions are used to check if an AI can initiate a scripted melee attack against its enemy.
 * If these pass, the AI designates itself as the initiator of the setup. The initiator then picks the two animations, and sets AnimScripted on both itself and its enemy from the AIvsAIMeleeAction
 * Threads are spawned on the entities to handle death during the sequence since it is outside the tree. The loser is killed and the survivor kicks back into the behavior tree.
TODO: 
- Rethink the initiator system to see if melee can be triggered without it
- Add support for few more animations, including close range melee without runup
- Add more archetypes
 */
 
#using scripts\codescripts\struct;

// COMMON AI SYSTEMS INCLUDES
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\aivsaimelee.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;

function autoexec main()
{
	meleeBundles = GET_MELEE_BUNDLES;
	
	level._aivsai_meleeBundles = [];
	
	foreach( meleeBundle in meleeBundles )
	{
		attacker_archetype = meleeBundle.attackerArchetype;
		defender_archetype = meleeBundle.defenderArchetype;
		attacker_variant = meleeBundle.attackerVariant;
		defender_variant = meleeBundle.defenderVariant;
		
		if( !IsDefined( level._aivsai_meleeBundles[ attacker_archetype ] ) )
		{
			level._aivsai_meleeBundles[ attacker_archetype ] = [];
			level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ] = [];
			level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ][ attacker_variant ] = [];
		}
		else if( !IsDefined( level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ] ) )
		{
			level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ] = [];
			level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ][ attacker_variant ] = [];
		}
		else if( !IsDefined( level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ][ attacker_variant ] ) )
		{
			level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ][ attacker_variant ] = [];
		}
		
		level._aivsai_meleeBundles[ attacker_archetype ][ defender_archetype ][ attacker_variant ][ defender_variant ] = meleeBundle;
	}
}

function RegisterAIvsAIMeleeBehaviorFunctions()
{			
	// ------- AI vs AI BEHAVIOR TREE FUNCTIONS -----------//
	BT_REGISTER_API( "hasAIvsAIEnemy", 					&hasAIvsAIEnemy );
	BT_REGISTER_API( "decideInitiator", 				&decideInitiator );
	BT_REGISTER_API( "isInitiator", 					&isInitiator );
	BT_REGISTER_API( "hasCloseAIvsAIEnemy", 			&hasCloseAIvsAIEnemy );
	BT_REGISTER_API( "chooseAIvsAIMeleeAnimations", 	&chooseAIvsAIMeleeAnimations );
	
	BT_REGISTER_API( "isCloseEnoughForAIvsAIMelee", 	&isCloseEnoughForAIvsAIMelee );
	BT_REGISTER_API( "hasPotentalAIvsAIMeleeEnemy", 	&hasPotentalAIvsAIMeleeEnemy );
		
	BT_REGISTER_ACTION( "AIvsAIMeleeAction",			&AIvsAIMeleeInitialize,	undefined,	undefined );
}


// ------- AI vs AI BEHAVIOR TREE FUNCTIONS -----------//

function hasPotentalAIvsAIMeleeEnemy( behaviorTreeEntity )
{
	if( !hasAIvsAIEnemy( behaviorTreeEntity ) )
		return false;
	
	if( !chooseAIvsAIMeleeAnimations( behaviorTreeEntity ) )
		return false;
	
	if( !hasCloseAIvsAIEnemy( behaviorTreeEntity ) )
		return true;
	
	return false;
}

function isCloseEnoughForAIvsAIMelee( behaviorTreeEntity )
{	
	if( !hasAIvsAIEnemy( behaviorTreeEntity ) )
		return false;
	
	if( !chooseAIvsAIMeleeAnimations( behaviorTreeEntity ) )
		return false;
	
	if( !hasCloseAIvsAIEnemy( behaviorTreeEntity ) )
		return false;
	
	return true;
}

function private shouldAquireMutexOnEnemyForAIvsAIMelee( behaviorTreeEntity )
{	
	if( IsPlayer ( behaviorTreeEntity.enemy ) )
		return false;
	
	if( !IsDefined( behaviorTreeEntity.enemy ) )
		return false;
	
	// if already meleeing, then see if the enemy we are meleeing is the same as 
	// the one we want to perform AI vs AI melee
	if( IsDefined( behaviorTreeEntity.melee ) )
	{
		if( IsDefined( behaviorTreeEntity.melee.enemy ) && behaviorTreeEntity.melee.enemy == behaviorTreeEntity.enemy )
			return true;
	}
	
	if( IsDefined( behaviorTreeEntity.enemy.melee ) )
	{
		if( IsDefined( behaviorTreeEntity.enemy.melee.enemy ) && behaviorTreeEntity.enemy.melee.enemy != behaviorTreeEntity )
			return false;		
	}
	
	return true;
}

function private hasAIvsAIEnemy( behaviorTreeEntity )
{
	enemy = behaviorTreeEntity.enemy; 

	if( GetDvarInt( "disable_aivsai_melee", 0 ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Disable dvar set", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	if( !IsDefined( enemy ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: No enemy", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	if( !( IsAlive( behaviorTreeEntity ) && IsAlive( enemy ) ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: A participant may not be alive", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;	
	}
	
	// Only support AI Actors.
	if( !IsAI( enemy ) || !IsActor( enemy ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Not an actor nor AI", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	//for now only human vs human and riotshield and robot
	//NOTE: dog cannot be on the losing side
	if( IsDefined( enemy.archetype ) )
	{
		if(IS_BONUSZM)
		{
			if( enemy.archetype != ARCHETYPE_HUMAN && enemy.archetype != ARCHETYPE_HUMAN_RIOTSHIELD && enemy.archetype != ARCHETYPE_ROBOT && enemy.archetype!= ARCHETYPE_ZOMBIE )
			{
				/#
				Record3DText( "AI vs AI Melee Failure: Non human/riotshield/robot/zombie enemy", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
				#/	
				return false;
			}
		}
		else
		{
			if( enemy.archetype != ARCHETYPE_HUMAN && enemy.archetype != ARCHETYPE_HUMAN_RIOTSHIELD && enemy.archetype != ARCHETYPE_ROBOT )
			{
				/#
				Record3DText( "AI vs AI Melee Failure: Non human/riotshield/robot enemy", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
				#/
				return false;
			}
		}
	}
	
	if( enemy.team == behaviorTreeEntity.team )
	{
		/#
			Record3DText( "AI vs AI Melee Failure: Enemy is on same team", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	if( enemy IsRagdoll() )
	{
		/#
			Record3DText( "AI vs AI Melee Failure: Enemy is in ragdoll", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	//enemy should be ignored
	if( IS_TRUE( enemy.ignoreMe ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Enemy should be ignored", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//already a part of an aivsai melee, _ai_melee_markedDead is used to designate that a decision has been made on the conflict
	if( IS_TRUE( enemy._ai_melee_markedDead ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Enemy engaged in another AI vs AI melee", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//AI should not initiate aivsai melee
	if ( behaviorTreeEntity ai::has_behavior_attribute( "can_initiateaivsaimelee" ) &&
		!behaviorTreeEntity ai::get_behavior_attribute( "can_initiateaivsaimelee" ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: can_initiateaivsaimelee disabled for attacker", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	// Check if the AI can melee.
	if ( behaviorTreeEntity ai::has_behavior_attribute( "can_melee" ) &&
		!behaviorTreeEntity ai::get_behavior_attribute( "can_melee" ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: can_melee disabled for attacker", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	// Check if the enemy can be meleed.
	if ( enemy ai::has_behavior_attribute( "can_be_meleed" ) &&
		!enemy ai::get_behavior_attribute( "can_be_meleed" ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: can_melee disabled for enemy", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	//to check if enemy is close by
	if( Distance2DSquared( behaviorTreeEntity.origin, enemy.origin ) > CLOSE_ENEMY_DISTANCE_SQ )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Enemy too far", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		behaviorTreeEntity._ai_melee_initiator = undefined;
		return false;
	}
	//making sure our enemy is in front of us
	forwardVec = VectorNormalize( AnglesToForward( behaviorTreeEntity.angles ) );
	rightVec = VectorNormalize( AnglesToRight( behaviorTreeEntity.angles ) );
	toEnemyVec = VectorNormalize( enemy.origin - behaviorTreeEntity.origin );
					
	fDot = VectorDot( toEnemyVec, forwardVec );

	if ( fDot < 0 )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Enemy behind us", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//do not melee an enemy that is already playing scripted anim
	if( enemy isInScriptedState() )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: Enemy in scripted state", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//only allow standing ai vs ai melee
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	enemyStance = Blackboard::GetBlackBoardAttribute( enemy, STANCE );
	if( currentStance != STANCE_STAND || enemyStance != STANCE_STAND )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: attacker or enemy not standing", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//return if we should not acquire melee mutex
	if( !shouldAquireMutexOnEnemyForAIvsAIMelee( behaviorTreeEntity ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: should not acquire melee mutex", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//slope test
	if( Abs( behaviorTreeEntity.origin[2] - behaviorTreeEntity.enemy.origin[2] ) > SYNC_MELEE_SLOPE_THRESHOLD )
	{
		/#
			Record3DText( "AI vs AI Melee Failure: Slope test failed", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//return if there is not enough open space
	raisedEnemyEntOrigin = ( behaviorTreeEntity.enemy.origin[0], behaviorTreeEntity.enemy.origin[1], behaviorTreeEntity.enemy.origin[2] + MELEE_TRACE_Z_OFFSET );
	if( !behaviorTreeEntity MayMoveToPoint( raisedEnemyEntOrigin, false, true, behaviorTreeEntity.enemy ) )
	{
		/#
			Record3DText( "AI vs AI Melee Failure: Trace failed", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	//cannot kill an AI that is not supposed to die
	if( IsDefined( enemy.allowDeath ) && !enemy.allowDeath )
	{
		if( IsDefined( behaviorTreeEntity.allowDeath ) && !behaviorTreeEntity.allowDeath )
		{
			/#
			Record3DText( "AI vs AI Melee Failure: Enemy and attacker cannot die", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
			#/
			
			self notify( "failed_melee_mbs", enemy );
			return false;
		}
		behaviorTreeEntity._ai_melee_attacker_loser = true;
		return true;
	}
	return true;
}

function private decideInitiator( behaviorTreeEntity )
{
	if( !IsDefined( behaviorTreeEntity._ai_melee_initiator ) )
	{
		if( !IsDefined( behaviorTreeEntity.enemy._ai_melee_initiator ) )
		{
			behaviorTreeEntity._ai_melee_initiator = true;
			return true;
		}
	}
	return false;
}

function private isInitiator( behaviorTreeEntity )
{
	if( !IS_TRUE( behaviorTreeEntity._ai_melee_initiator ) )
	{
		return false;
	}
	return true;
}

function private hasCloseAIvsAIEnemy( behaviorTreeEntity )
{
	if( !( IsDefined( behaviorTreeEntity._ai_melee_animname ) && IsDefined( behaviorTreeEntity.enemy._ai_melee_animname ) ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failure: anim pair not found", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	animationStartOrigin = GetStartOrigin( behaviorTreeEntity.enemy GetTagOrigin( TAG_SYNC ), behaviorTreeEntity.enemy GetTagAngles( TAG_SYNC ), behaviorTreeEntity._ai_melee_animname );
	
/#
	Record3DText("Threshold Initiator distance from AnimStart = " + Sqrt( SYNCED_MELEE_DIST_THRESHOLD_SQ ), behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	Record3DText("Initiatior distance from AnimStart = " + Distance( animationStartOrigin, behaviorTreeEntity.origin ), behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	RecordCircle( behaviorTreeEntity.enemy GetTagOrigin( TAG_SYNC ), 8, RED, "Animscript", behaviorTreeEntity );
	
	RecordCircle( animationStartOrigin, 8, ORANGE, "Animscript", behaviorTreeEntity );
	RecordLine( animationStartOrigin, behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity );
#/		
		
	if( Distance2DSquared( behaviorTreeEntity.origin, animationStartOrigin ) <= SYNCED_MELEE_DIST_THRESHOLD_SQ )
	{
		return true;
	}
		
	//check predicted position of entity, and extrapolate position for back anims
	if( behaviorTreeEntity HasPath() )
	{
		selfPredictedPos = behaviorTreeEntity.origin;
		moveAngle		 = behaviorTreeEntity.angles[1] + behaviorTreeEntity getMotionAngle();
		selfPredictedPos += (cos( moveAngle ), sin( moveAngle ), 0) * 200.0 * 0.2; //0.2 is the lookahead time
		
/#		
		Record3DText("Initiator predicted distance from AnimStart= " + Distance( selfPredictedPos, animationStartOrigin ), behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
#/
			
		if( Distance2DSquared( selfPredictedPos, animationStartOrigin ) <= SYNCED_MELEE_DIST_THRESHOLD_SQ )
		{
			return true;
		}		
	}
	
	return false;
}

function private chooseAIvsAIMeleeAnimations( behaviorTreeEntity )
{
	anglesToEnemy = VectorToAngles( behaviorTreeEntity.enemy.origin - behaviorTreeEntity.origin );
	yawToEnemy	  = AngleClamp180( behaviorTreeEntity.enemy.angles[ 1 ] - anglesToEnemy[ 1 ] );
	
	/#
	//record yaw to enemy for debugging
	Record3DText("Yaw to enemy = " + abs( yawToEnemy ), behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/
	
	//clear out old anims
	behaviorTreeEntity._ai_melee_animname = undefined;
	behaviorTreeEntity.enemy._ai_melee_animname = undefined;
	
	//get the scriptbundle for these archetypes
	attacker_variant = chooseArchetypeVariant( behaviorTreeEntity );
	defender_variant = chooseArchetypeVariant( behaviorTreeEntity.enemy );
	
	//TODO: Change this into an assert and ensure a bundle is always available if we get here
	if( !AIvsAIMeleeBundleExists( behaviorTreeEntity, attacker_variant, defender_variant  ) )
	{
		/#
		Record3DText( "AI vs AI melee Failure: Bundle does not exist for " + behaviorTreeEntity.archetype + " " + behaviorTreeEntity.enemy.archetype + " " + attacker_variant + " " + defender_variant, behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		#/
		return false;
	}
	
	animBundle = level._aivsai_meleeBundles[ behaviorTreeEntity.archetype ][ behaviorTreeEntity.enemy.archetype ][ attacker_variant ][ defender_variant ];
		
	/#
		if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
		{
			Record3DText( "AI vs AI Melee: Attacker selected as loser", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		}
	#/
	
	foundAnims = false;
	possibleMelees = [];
	
	if( abs( yawToEnemy ) > FRONT_ANGLE_THRESHOLD )
	{			
		if( IsDefined( behaviorTreeEntity.__forceAIFlipMelee ) )
		{
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeFrontFlipAnimations;
		}
		else if( IsDefined( behaviorTreeEntity.__forceAIWrestleMelee ) )
		{
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeFrontWrestleAnimations;
		}
		else
		{
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeFrontFlipAnimations;
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeFrontWrestleAnimations;
		}			
	}
	else if( abs( yawToEnemy ) < BACK_ANGLE_THRESHOLD )
	{		
		possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeBackAnimations;
	}
	else
	{
		//possibly left/right directional
		rightVec = VectorNormalize( AnglesToRight( behaviorTreeEntity.enemy.angles ) );
		toAttackerVec = VectorNormalize( behaviorTreeEntity.origin - behaviorTreeEntity.enemy.origin );

		rDot = VectorDot( toAttackerVec, rightVec );
		
		if( rDot > 0 )
		{
			//coming in from the right
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeRightAnimations;
		}
		else
		{
			//coming in from the left
			possibleMelees[possibleMelees.size] = &chooseAIVsAIMeleeLeftAnimations;
		}
	}
	
	if( possibleMelees.size > 0 )
	{
		[[RANDOM( possibleMelees )]]( behaviorTreeEntity, animBundle );
	}
		
	if( IsDefined( behaviorTreeEntity._ai_melee_animname ) )
	{
		Debug_ChosenMeleeAnimations( behaviorTreeEntity );
		return true;
	}
	
	return false;
}

function private chooseArchetypeVariant( entity )
{
	if( entity.archetype == ARCHETYPE_ROBOT )
	{
		robot_state = entity ai::get_behavior_attribute( "rogue_control" );
		
		if( IsInArray( array( "forced_level_1", "level_1", "level_0" ), robot_state ) )
		{
			return REGULAR_VARIANT;
		}
		if( IsInArray( array( "forced_level_2", "level_2", "level_3", "forced_level_3" ), robot_state ) )
		{
			return MELEE_VARIANT;
		}
	}
	
	return REGULAR_VARIANT;
}

function private AIvsAIMeleeBundleExists( behaviorTreeEntity, attacker_variant, defender_variant )
{
	if( !IsDefined( level._aivsai_meleeBundles[ behaviorTreeEntity.archetype ] ) )
	{
		return false;
	}
	else if( !IsDefined( level._aivsai_meleeBundles[ behaviorTreeEntity.archetype ][ behaviorTreeEntity.enemy.archetype ] ) )
	{
		return false;
	}
	else if( !IsDefined( level._aivsai_meleeBundles[ behaviorTreeEntity.archetype ][ behaviorTreeEntity.enemy.archetype ][ attacker_variant ] ) )
	{
		return false;
	}
	else if( !IsDefined( level._aivsai_meleeBundles[ behaviorTreeEntity.archetype ][ behaviorTreeEntity.enemy.archetype ][ attacker_variant ][ defender_variant ] ) )
	{
		return false;
	}
	return true;
}

function AIvsAIMeleeInitialize( behaviorTreeEntity, asmStateName )
{
	behaviorTreeEntity.blockingPain = true;
	behaviorTreeEntity.enemy.blockingPain = true;
	//acquire the mutex since we are about to melee
	AiUtility::meleeAcquireMutex( behaviorTreeEntity );
	//keep a reference to the other person incase one of the participants does not have the other selected as enemy (especially in case of back melees)
	behaviorTreeEntity._ai_melee_opponent = behaviorTreeEntity.enemy;
	behaviorTreeEntity.enemy._ai_melee_opponent = behaviorTreeEntity;
	   
	//the winner will call playScriptedMeleeAnimations, since this function waits on winner's victory before resetting some flags
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_markedDead = true;
		behaviorTreeEntity.enemy thread playScriptedMeleeAnimations();
	}
	else
	{
		behaviorTreeEntity.enemy._ai_melee_markedDead = true;
		behaviorTreeEntity thread playScriptedMeleeAnimations();
	}
	
	return BHTN_RUNNING;	
}

// ------- AI vs AI INTERNAL FUNCTIONS -----------//

//Threaded call to animscripted so that anim is not blended out too early
function playScriptedMeleeAnimations()
{
	self endon("death");
	
	Assert( IsDefined( self._ai_melee_opponent ) );
	opponent = self._ai_melee_opponent;
	
	// In rare cases the enemy or AI could have died.
	if ( !( IsAlive( self ) && IsAlive( opponent ) ) )
	{
		/#
		Record3DText( "AI vs AI Melee Failsafe Failure: A participant may not be alive", self.origin, ORANGE, "Animscript", self, 0.4 );
		#/
		return false;
	}
	
	if( IS_TRUE( opponent._ai_melee_attacker_loser ) )
	{
		//link to the defender
		
		//call animscripted on both
		opponent AnimScripted( "aivsaimeleeloser", self GetTagOrigin(TAG_SYNC), self GetTagAngles(TAG_SYNC), opponent._ai_melee_animname, "normal", undefined, 1.0, SYNC_MELEE_BLEND_TIME, SYNC_MELEE_LERP_TIME );
		self AnimScripted( "aivsaimeleewinner", self GetTagOrigin(TAG_SYNC), self GetTagAngles(TAG_SYNC), self._ai_melee_animname, "normal", undefined, 1.0, SYNC_MELEE_BLEND_TIME, SYNC_MELEE_LERP_TIME );
		
		/#
		RecordCircle( self GetTagOrigin(TAG_SYNC), 2, ORANGE, "Animscript" );
		RecordLine( self GetTagOrigin(TAG_SYNC), opponent.origin, ORANGE, "Animscript" );
		#/
	}
	else
	{
		//link to the defender
		
		//call animscripted on both
		self AnimScripted( "aivsaimeleewinner", opponent GetTagOrigin(TAG_SYNC), opponent GetTagAngles(TAG_SYNC), self._ai_melee_animname, "normal", undefined, 1.0, SYNC_MELEE_BLEND_TIME, SYNC_MELEE_LERP_TIME );
		opponent AnimScripted( "aivsaimeleeloser", opponent GetTagOrigin(TAG_SYNC), opponent GetTagAngles(TAG_SYNC), opponent._ai_melee_animname, "normal", undefined, 1.0, SYNC_MELEE_BLEND_TIME, SYNC_MELEE_LERP_TIME );
		
		/#
		RecordCircle( opponent GetTagOrigin(TAG_SYNC), 2, ORANGE, "Animscript" );
		RecordLine( opponent GetTagOrigin(TAG_SYNC), self.origin, ORANGE, "Animscript" );
		#/
	}
	//spawn a thread that kills off the loser at the end
	opponent thread handleDeath( opponent._ai_melee_animname, self );
	
	if ( GetDvarInt( "tu1_aivsaiMeleeDisableGib", 1 ) )
	{
		// TU1 fix to prevent vertex stretching when robots are killed in AI vs AI melee.
	
		// Don't gib robots upon an AI vs AI melee death, since robots don't have
		// enough time post death to correctly hide/show tags and swap models.
		if ( opponent ai::has_behavior_attribute( "can_gib" ) )
		{
			opponent ai::set_behavior_attribute( "can_gib", false );
		}
	}
	
	//process interrupted deaths
	self thread processInterruptedDeath();
	opponent thread processInterruptedDeath();
	
	//wait for winner to finish
	self waittillmatch( "aivsaimeleewinner", "end" );
	
	self.fixedLinkYawOnly = false;
	
	//flag cleanup
	//release the melee mutex
	AiUtility:: cleanupChargeMeleeAttack( self );
	//remove knife model if necessary
	if( IS_TRUE( self._ai_melee_attachedKnife ) )
	{
		self Detach( KNIFE_MODEL, "TAG_WEAPON_LEFT" );
		self._ai_melee_attachedKnife = false;
	}
	self.blockingPain = false;
	self._ai_melee_initiator = undefined;
	self notify("meleeCompleted");
	
	self PathMode( "move delayed", true, 3 );
}

function private chooseAIVsAIMeleeFrontFlipAnimations( behaviorTreeEntity, animBundle )
{
	/#
	Record3DText( "AI vs AI Melee: Direction is front", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/

	assert( IsDefined( animBundle ) );
		
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLoserFrontAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.defenderWinnerFrontAnim;
	}
	else
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerFrontAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.victimFrontAnim;
	}
	
	behaviorTreeEntity._ai_melee_animtype = FRONT_FLIP_TYPE;
	behaviorTreeEntity.enemy._ai_melee_animtype = FRONT_FLIP_TYPE;			
}

function private chooseAIVsAIMeleeFrontWrestleAnimations( behaviorTreeEntity, animBundle )
{
	/#
	Record3DText( "AI vs AI Melee: Direction is front", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/
	
	assert( IsDefined( animBundle ) );
		
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLoserAlternateFrontAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.defenderWinnerAlternateFrontAnim;
	}
	else
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerAlternateFrontAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.victimAlternateFrontAnim;
	}
	
	behaviorTreeEntity._ai_melee_animtype = FRONT_WRESTLE_TYPE;
	behaviorTreeEntity.enemy._ai_melee_animtype = FRONT_WRESTLE_TYPE;				
}

function private chooseAIVsAIMeleeBackAnimations( behaviorTreeEntity, animBundle )
{
	/#
	Record3DText( "AI vs AI Melee: Direction is back", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/
		
	assert( IsDefined( animBundle ) );	
	
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLoserBackAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.defenderWinnerBackAnim;
	}
	else
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerBackAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.victimBackAnim;
	}
	
	behaviorTreeEntity._ai_melee_animtype = BACK_TYPE;
	behaviorTreeEntity.enemy._ai_melee_animtype = BACK_TYPE;			
}

function private chooseAIVsAIMeleeRightAnimations( behaviorTreeEntity, animBundle )
{
	/#
	Record3DText( "AI vs AI Melee: Direction is right", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/
		
	assert( IsDefined( animBundle ) );	
	
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLoserRightAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.defenderWinnerRightAnim;
	}
	else
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerRightAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.victimRightAnim;
	}
	
	behaviorTreeEntity._ai_melee_animtype = RIGHT_TYPE;
	behaviorTreeEntity.enemy._ai_melee_animtype = RIGHT_TYPE;			
}

function private chooseAIVsAIMeleeLeftAnimations( behaviorTreeEntity, animBundle )
{
	/#
	Record3DText( "AI vs AI Melee: Direction is left", behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	#/
		
	assert( IsDefined( animBundle ) );	
	
	if( IS_TRUE( behaviorTreeEntity._ai_melee_attacker_loser ) )
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLoserLeftAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.defenderWinnerLeftAnim;
	}
	else
	{
		behaviorTreeEntity._ai_melee_animname = animBundle.attackerLeftAnim;
		behaviorTreeEntity.enemy._ai_melee_animname = animBundle.victimLeftAnim;
	}
	
	behaviorTreeEntity._ai_melee_animtype = LEFT_TYPE;
	behaviorTreeEntity.enemy._ai_melee_animtype = LEFT_TYPE;			
}

function private Debug_ChosenMeleeAnimations( behaviorTreeEntity ) 
{
	/#
	if( IsDefined( behaviorTreeEntity._ai_melee_animname ) && IsDefined( behaviorTreeEntity.enemy._ai_melee_animname ) )
	{
		Record3DText("AI vs AI chosen anim = " + behaviorTreeEntity._ai_melee_animname, behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
		Record3DText("AI vs AI enemy chosen anim = " + behaviorTreeEntity.enemy._ai_melee_animname, behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity, 0.4 );
	}
	#/
}

//Need this to handle deaths for the loser
function handleDeath( animationName, attacker )
{
	self endon("death");
	self endon("interruptedDeath");
	
	self.skipDeath = true;
	self.diedInScriptedAnim = true;
	
	totalTime = GetAnimLength( animationName );
	wait( totalTime - 0.2 );
	
	self killWrapper( attacker );
}

//To deal with deaths during animscripted
function processInterruptedDeath()
{
	self endon("meleeCompleted");
	
	Assert( IsDefined( self._ai_melee_opponent ) );
	opponent = self._ai_melee_opponent;
	//do not interrupt and kill someone that is not supposed to die
	if( !IS_TRUE( self.allowDeath ) )
	{
		return;
	}
	self waittill("death");
	
	//cleanup knife if required
	if( IsDefined( self ) && IS_TRUE( self._ai_melee_attachedKnife ) )
	{
		self Detach( KNIFE_MODEL, "TAG_WEAPON_LEFT" );
	}
	
	if( IsAlive( opponent ) )
	{
		//loser always dies
		if( IS_TRUE( opponent._ai_melee_markedDead ) )
		{
			opponent.diedInScriptedAnim = true;
			opponent.skipDeath = true;
			opponent notify ( "interruptedDeath" );
			opponent notify ( "meleeCompleted" );
		
			opponent StopAnimScripted();
			opponent killWrapper();
			opponent StartRagDoll();
		}
		else
		{
			opponent._ai_melee_initiator = undefined;
			opponent.blockingPain = false;
			opponent._ai_melee_markedDead = undefined;
			opponent.skipDeath = false;
			opponent.diedInScriptedAnim = false;
			//release the melee mutex for opponent
			AiUtility:: cleanupChargeMeleeAttack( opponent );
			opponent notify( "interruptedDeath" );	
			opponent notify( "meleeCompleted" );
			opponent StopAnimScripted();
		}
	}
	
	if( IsDefined( self ) )
	{
		self.diedInScriptedAnim = true;
		self.skipDeath = true;
		self notify ( "interruptedDeath" );
		
		self StopAnimScripted();
		self killWrapper();
		self StartRagDoll();
	}
}

function killWrapper( attacker )
{
	if( IsDefined( self.overrideActorDamage ) )
	{
		self.overrideActorDamage = undefined;
	}
	
	self.TokubetsuKogekita = undefined; //this var reduces damage for certain cybercom affected robots
	
	//guarding against team changes
	if( IsDefined( attacker ) && self.team != attacker.team )
	{
		self kill(self.origin,attacker);
	}
	else
	{
		self kill();
	}
}