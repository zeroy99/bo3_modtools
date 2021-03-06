#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\systems\shared;

// INTERFACE
#using scripts\shared\ai\archetype_human_riotshield_interface;

#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_mocomps_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_human_riotshield.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

function autoexec main()
{
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_HUMAN_RIOTSHIELD, &HumanRiotshieldBehavior::ArchetypeHumanRiotshieldBlackboardInit );
	
	// INIT RIOTSHIELD ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_HUMAN_RIOTSHIELD, &HumanRiotshieldServerUtils::humanRiotshieldSpawnSetup );
	
	HumanRiotshieldBehavior::RegisterBehaviorScriptFunctions();

	HumanRiotshieldInterface::RegisterHumanRiotshieldInterfaceAttributes();
}

#namespace HumanRiotshieldBehavior;

function RegisterBehaviorScriptFunctions()
{
	// ------- TACTICAL WALK -----------//	
	BT_REGISTER_API( "riotshieldShouldTacticalWalk", &riotshieldShouldTacticalWalk );
	BT_REGISTER_API( "riotshieldNonCombatLocomotionCondition", &riotshieldNonCombatLocomotionCondition );
	BT_REGISTER_API( "unarmedWalkAction", &unarmedWalkActionStart );
	BT_REGISTER_API( "riotshieldTacticalWalkStart", &riotshieldTacticalWalkStart );

	BT_REGISTER_API( "riotshieldAdvanceOnEnemyService",	&riotshieldAdvanceOnEnemyService );
	
	BT_REGISTER_API( "riotshieldShouldFlinch",			&riotshieldShouldFlinch );
	BT_REGISTER_API( "riotshieldIncrementFlinchCount",	&riotshieldIncrementFlinchCount );
	BT_REGISTER_API( "riotshieldClearFlinchCount",		&riotshieldClearFlinchCount );

	// ------- UNARMED -----------//	
	BT_REGISTER_API( "riotshieldUnarmedTargetService", &riotshieldUnarmedTargetService );
	BT_REGISTER_API( "riotshieldUnarmedAdvanceOnEnemyService",	&riotshieldUnarmedAdvanceOnEnemyService );
}

function private ArchetypeHumanRiotshieldBlackboardInit()
{
	entity = self;
	
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( entity );
	
	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( entity );
	
	// USE UTILITY BLACKBOARD
	entity AiUtility::RegisterUtilityBlackboardAttributes();
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeHumanRiotshieldOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING( entity );
	
	BB_REGISTER_ATTRIBUTE( MOVE_MODE, "normal", &riotshieldMoveMode );
}

function private ArchetypeHumanRiotshieldOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeHumanRiotshieldBlackboardInit();
}

function private riotshieldMoveMode()
{
	entity = self;

	if ( entity ai::get_behavior_attribute( "phalanx" ) )
	{
		return "marching";
	}
	
	return "normal";
}

function private riotshieldShouldFlinch( entity )
{
	if ( entity HasPath() && entity ai::get_behavior_attribute( "phalanx" ))
	{
		// Always flinch when moving in a phalanx.
		return true;
	}

	if ( entity.damagelocation != "riotshield" )
	{
		return false;
	}

	if ( entity.damagelocation == "riotshield" &&
		entity.flinchCount >= RIOTSHIELD_FLINCH_COUNT_TO_STAGGER &&
		( entity.lastFlinchTime + RIOTSHIELD_FLINCH_RESET_TIME ) >= GetTime() )
	{
		return false;
	}
	
	return true;
}

function private riotshieldIncrementFlinchCount( entity )
{
	entity.flinchCount++;
	entity.lastFlinchTime = GetTime();
}

function private riotshieldClearFlinchCount( entity )
{
	entity.lastFlinchTime = GetTime();
	entity.flinchCount = 0;
}

function private riotshieldShouldTacticalWalk( behaviorTreeEntity )
{
	// always tactical walk
	return true;
}

function private riotshieldNonCombatLocomotionCondition( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.enemy ) )
	{
		if ( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity LastKnownPos( behaviorTreeEntity.enemy ) ) > RIOTSHIELD_RUN_DIST_SQ )
		{
			return true;
		}
	}

	return false;
}

function private riotshieldAdvanceOnEnemyService( behaviorTreeEntity )
{
	itsBeenAWhile  	   = ( GetTime() > behaviorTreeEntity.nextFindBestCoverTime );
	isAtScriptGoal 	   = behaviorTreeEntity IsAtGoal();	
	tooLongAtNode	   = false;
	
	if ( behaviorTreeEntity ai::get_behavior_attribute( "phalanx" ) )
	{
		return false;
	}

	if ( IsDefined( behaviorTreeEntity.chosenNode ) )
	{
		dist_sq = DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.chosenNode.origin );
		if ( dist_sq < RIOTSHIELD_AT_NODE_DIST_SQ )
		{
			if ( !IsDefined( behaviorTreeEntity.timeAtChosenNode ) )
			{
				behaviorTreeEntity.timeAtChosenNode = GetTime();
			}
		}
	}

	if ( IsDefined( behaviorTreeEntity.timeAtChosenNode ) )
	{
		if ( GetTime() - behaviorTreeEntity.timeAtChosenNode > behaviorTreeEntity.timeAtNodeMax )
		{
			tooLongAtNode = true;
			behaviorTreeEntity.timeAtChosenNode = undefined;
		}
	}

	shouldLookForBetterCover = itsBeenAWhile || !isAtScriptGoal || tooLongAtNode;

	if ( shouldLookForBetterCover && IsDefined( behaviorTreeEntity.enemy ) )	 
	{
		closestRandomNode = undefined;
		closestRandomNodes = behaviorTreeEntity FindBestCoverNodes( behaviorTreeEntity.goalradius, behaviorTreeEntity.goalpos );

		foreach( node in closestRandomNodes )
		{
			if ( IsDefined( behaviorTreeEntity.chosenNode ) && behaviorTreeEntity.chosenNode == node )
			{
				continue;
			}

			if ( AiUtility::getCoverType( node ) == COVER_EXPOSED )
			{
				closestRandomNode = node;
				break;
			}
		}

		if ( !IsDefined( closestRandomNode ) )
		{
			closestRandomNode = closestRandomNodes[0];
		}
		
		if( IsDefined( closestRandomNode ) 
			&& behaviorTreeEntity FindPath( behaviorTreeEntity.origin, closestRandomNode.origin, true, false ) 
			)
		{
			AiUtility::ReleaseClaimNode( behaviorTreeEntity );
			AiUtility::useCoverNodeWrapper( behaviorTreeEntity, closestRandomNode );

			behaviorTreeEntity.chosenNode = closestRandomNode;
			behaviorTreeEntity.timeAtNodeMax = RandomIntRange( behaviorTreeEntity.moveDelayMin, behaviorTreeEntity.moveDelayMax );
			behaviorTreeEntity.timeAtChosenNode = undefined;

			return true;				
		}
	}		

	return false;
}

function private riotshieldTacticalWalkStart( behaviorTreeEntity )
{	
	AiUtility::resetCoverParameters( behaviorTreeEntity );
	AiUtility::setCanBeFlanked( behaviorTreeEntity, false );
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );		
	behaviorTreeEntity OrientMode( "face enemy" );	
}

function private riotshieldUnarmedTargetService( behaviorTreeEntity )
{
	// Don't change targets during melee
	if ( !AiUtility::shouldMutexMelee( behaviorTreeEntity ) )
	{
		return false;
	}

	enemies = [];
	ai = GetAiArray();

	// Add AI's that are on different teams.
	foreach( index, value in ai )
	{
		if ( value.team != behaviorTreeEntity.team && IsActor( value ) )
		{
			enemies[enemies.size] = value;
		}
	}

	// Find the closest enemy based on distance.
	if ( enemies.size > 0 )
	{
		closestEnemy = undefined;
		closestEnemyDistance = 0;
		
		for ( index = 0; index < enemies.size; index++ )
		{
			enemy = enemies[index];
			enemyDistance = DistanceSquared( behaviorTreeEntity.origin, enemy.origin );
			checkEnemy = false;

			if ( enemyDistance > behaviorTreeEntity.goalradius * behaviorTreeEntity.goalradius )
			{
				continue;
			}

			if ( !IsDefined( enemy.targeted_by ) || enemy.targeted_by == behaviorTreeEntity )
			{
				checkEnemy = true;
			}
			else
			{
				targetDistance = DistanceSquared( enemy.targeted_by.origin, enemy.origin );
				if ( enemyDistance < targetDistance )
				{
					checkEnemy = true;
				}
			}

			if ( checkEnemy )
			{
				if ( !IsDefined( closestEnemy ) || enemyDistance < closestEnemyDistance )
				{
					closestEnemyDistance = enemyDistance;
					closestEnemy = enemy;
				}
			}
		}

		if ( IsDefined( behaviorTreeEntity.favoriteenemy ) )
		{
			behaviorTreeEntity.favoriteenemy.targeted_by = undefined;
		}

		behaviorTreeEntity.favoriteenemy = closestEnemy;

		if ( IsDefined( behaviorTreeEntity.favoriteenemy ) )
		{
			behaviorTreeEntity.favoriteenemy.targeted_by = behaviorTreeEntity;
		}

		return true;
	}

	return false;
}

function private riotshieldUnarmedAdvanceOnEnemyService( behaviorTreeEntity )
{
	if ( GetTime() < behaviorTreeEntity.nextFindBestCoverTime )
	{
		return false;
	}

	if( IsDefined( behaviorTreeEntity.favoriteenemy ) )	 
	{
		/#
		RecordLine( behaviorTreeEntity.favoriteenemy.origin, behaviorTreeEntity.origin, ORANGE, "Animscript", behaviorTreeEntity );
		#/	

		enemyDistance = DistanceSquared( behaviorTreeEntity.favoriteenemy.origin, behaviorTreeEntity.origin );
		if ( enemyDistance < behaviorTreeEntity.goalradius * behaviorTreeEntity.goalradius )
		{
			behaviorTreeEntity UsePosition( behaviorTreeEntity.favoriteenemy.origin );
			return true;
		}
	}

	behaviorTreeEntity ClearUsePosition();
	return false;
}

function private unarmedWalkActionStart( behaviorTreeEntity )
{	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, STANCE, DEFAULT_MOVEMENT_STANCE );		
	behaviorTreeEntity OrientMode( "face enemy" );	
}


function private riotshieldKilledOverride(
	inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTime )
{
	entity = self;

	aiutility::dropRiotshield( entity );
	
	return damage;
}

function private riotshieldDamageOverride(
	eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	if ( sHitLoc == "riotshield" )
	{
		riotshieldIncrementFlinchCount( entity );
		entity.health += 1;
		
		return 1;
	}
	
	if ( sWeapon.name == "incendiary_grenade" )
	{
		iDamage = entity.health;
	}
	
	return iDamage;
}

#namespace HumanRiotshieldServerUtils;

function humanRiotshieldSpawnSetup()
{
	entity = self;
	
	aiutility::attachRiotshield( entity, GetWeapon( RIOTSHIELD_WEAPON ), RIOTSHIELD_MODEL, RIOTSHIELD_TAG );

	entity.moveDelayMin = RIOTSHIELD_MOVE_DELAY_MIN;
	entity.moveDelayMax = RIOTSHIELD_MOVE_DELAY_MAX;
	entity.ignoreRunAndGunDist = true;
	
	AiUtility::AddAIOverrideDamageCallback( entity, &HumanRiotshieldBehavior::riotshieldDamageOverride );
	AiUtility::AddAIOverrideKilledCallback( entity, &HumanRiotshieldBehavior::riotshieldKilledOverride );
	
	HumanRiotshieldBehavior::riotshieldClearFlinchCount( entity );
}

// end #namespace HumanRiotshieldServerUtils;

