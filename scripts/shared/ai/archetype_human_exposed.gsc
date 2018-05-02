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
#insert scripts\shared\ai\utility.gsh;

// ADDITIONAL INCLUDES
#insert scripts\shared\shared.gsh;

function autoexec RegisterBehaviorScriptfunctions()
{			
	// ------- EXPOSED - CONDITIONS -----------//
	BT_REGISTER_API( "hasCloseEnemy",					&hasCloseEnemy ); 
	BT_REGISTER_API( "noCloseEnemyService",				&noCloseEnemyService );
	BT_REGISTER_API( "tryReacquireService",				&tryReacquireService );
	BT_REGISTER_API( "prepareToReactToEnemy",			&prepareToReactToEnemy );	
	BT_REGISTER_API( "resetReactionToEnemy",			&resetReactionToEnemy );	
	
	BT_REGISTER_API( "exposedSetDesiredStanceToStand",	&exposedSetDesiredStanceToStand );
	BT_REGISTER_API( "setPathMoveDelayedRandom",		&setPathMoveDelayedRandom );
	
	BT_REGISTER_API( "vengeanceService",				&vengeanceService );
}

// ------- EXPOSED REACT TO ENEMY -----------//
function private prepareToReactToEnemy( behaviorTreeEntity )
{
	behaviorTreeEntity.newEnemyReaction = false;
	behaviorTreeEntity.malFunctionReaction = false;
	
	// Delay movement when surprised.
	behaviorTreeEntity PathMode( "move delayed", true, 3 );	
}

function private resetReactionToEnemy( behaviorTreeEntity )
{
	behaviorTreeEntity.newEnemyReaction = false;
	behaviorTreeEntity.malFunctionReaction = false;
}

// ------- EXPOSED CHARGE MELEE -----------//
function private noCloseEnemyService( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.enemy ) &&
		AiUtility::hasCloseEnemyToMelee( behaviorTreeEntity ) )
	{
		behaviorTreeEntity ClearPath();
		return true;
	}
	
	return false;
}

function private hasCloseEnemy( behaviorTreeEntity )
{	
	if( !IsDefined( behaviorTreeEntity.enemy ) )
	   return false;
	
	if ( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) < CLOSE_ENEMY_DISTANCE_SQ ) 
		return true;
	
	return false;
}

function private _IsValidNeighbor( entity, neighbor )
{
	return IsDefined( neighbor ) &&
		entity.team === neighbor.team;
}

#define VENGEANCE_CHANCE 0.5
#define VENGEANCE_DISTANCE_SQ SQR( 360 )
function private vengeanceService( entity )
{
	actors = GetAiArray();
	
	if ( !IsDefined( entity.attacker ) )
	{
		return;
	}
	
	foreach( index, ai in actors )
	{
		if ( _IsValidNeighbor( entity, ai ) &&
			DistanceSquared( entity.origin, ai.origin ) <= VENGEANCE_DISTANCE_SQ &&
			RandomFloat( 1 ) >= VENGEANCE_CHANCE )
		{
			ai GetPerfectInfo( entity.attacker, true );
		}
	}
}

#define DONT_MOVE_TIME_MIN 1
#define DONT_MOVE_TIME_MAX 3
function private setPathMoveDelayedRandom( behaviorTreeEntity, asmStateName )
{	
	// Delay movement to prevent jittering.
	behaviorTreeEntity PathMode( "move delayed", false, RandomFloatRange( DONT_MOVE_TIME_MIN, DONT_MOVE_TIME_MAX ) );
}

function private exposedSetDesiredStanceToStand( behaviorTreeEntity, asmStateName )
{
	AiUtility::keepClaimNode( behaviorTreeEntity );
	
	currentStance = Blackboard::GetBlackBoardAttribute( behaviorTreeEntity, STANCE );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, DESIRED_STANCE, STANCE_STAND );
}

// ------- EXPOSED - REACQUIRE -----------//
function private tryReacquireService( behaviorTreeEntity )
{
	if ( !IsDefined( behaviorTreeEntity.reacquire_state ) )
	{
		behaviorTreeEntity.reacquire_state = 0;
	}

	if ( !IsDefined( behaviorTreeEntity.enemy ) )
	{
		behaviorTreeEntity.reacquire_state = 0;
		return false;
	}

	if ( behaviorTreeEntity HasPath() )
	{
		behaviorTreeEntity.reacquire_state = 0;
		return false;
	}

	if ( behaviorTreeEntity SeeRecently( behaviorTreeEntity.enemy, 4 ) )
	{
		behaviorTreeEntity.reacquire_state = 0;
		return false;
	}

	// don't do reacquire unless facing enemy 
	dirToEnemy = VectorNormalize( behaviorTreeEntity.enemy.origin - behaviorTreeEntity.origin );
	forward = AnglesToForward( behaviorTreeEntity.angles );

	if ( VectorDot( dirToEnemy, forward ) < COS_60 )	
	{
		behaviorTreeEntity.reacquire_state = 0;
		return false;
	}

	switch ( behaviorTreeEntity.reacquire_state )
	{
	case 0:
	case 1:
	case 2:
		step_size = REACQUIRE_STEP_SIZE + behaviorTreeEntity.reacquire_state * REACQUIRE_STEP_SIZE;
		reacquirePos = behaviorTreeEntity ReacquireStep( step_size );
		break;

	case 4:
		if ( !( behaviorTreeEntity CanSee( behaviorTreeEntity.enemy ) ) || !( behaviorTreeEntity CanShootEnemy() ) )
		{
			behaviorTreeEntity FlagEnemyUnattackable();
		}
		break;

	default:
		if ( behaviorTreeEntity.reacquire_state > REACQUIRE_RESET )
		{
			behaviorTreeEntity.reacquire_state = 0;
			return false;
		}
		break;
	}

	if ( IsVec( reacquirePos ) )
	{
		behaviorTreeEntity UsePosition( reacquirePos );
		return true;
	}

	behaviorTreeEntity.reacquire_state++;
	return false;
}
