#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_mocomps_utility;
#using scripts\shared\ai\archetype_thrasher_interface;

#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\archetype_thrasher.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define N_THRASHER_CHARGE_HEALTH_THRESHOLD_PCT 0.6 //how low health has to be before Thrasher can start charging

#namespace ThrasherBehavior;

REGISTER_SYSTEM( "thrasher", &__init__, undefined )
	
function __init__()
{
	visionset_mgr::register_info( "visionset", THRASHER_CONSUMED_PLAYER_VISIONSET_ALIAS, VERSION_DLC2, THRASHER_CONSUMED_PLAYER_VISIONSET_PRIORITY, THRASHER_CONSUMED_PLAYER_VISIONSET_LERP_STEP_COUNT, true, &visionset_mgr::ramp_in_thread_per_player, false );
	
	// INIT BEHAVIORS
	InitThrasherBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_THRASHER, &ArchetypeThrasherBlackboardInit );

	// INIT THRASHER ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_THRASHER, &thrasherSpawnSetup );
		
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_THRASHER ) )
	{		
		clientfield::register( "actor", THRASHER_SPORE_CF, VERSION_TU5, THRASHER_SPORE_CF_BITS, THRASHER_SPORE_CF_TYPE );  // Leave at VERSION_TU5
		clientfield::register( "actor", THRASHER_BERSERK_CF, VERSION_TU5, THRASHER_BERSERK_CF_BITS, THRASHER_BERSERK_CF_TYPE );  // Leave at VERSION_TU5
		
		clientfield::register( "actor", "thrasher_player_hide", VERSION_TU8, 4, "int" );	// Leave at VERSION_TU8
		clientfield::register( "toplayer", "sndPlayerConsumed", VERSION_TU10, 1, "int" );	// Leave at VERSION_TU10
		
		foreach ( spore in THRASHER_SPORE_CF_SPORES )
		{
			clientfield::register(
				"actor",
				THRASHER_SPORE_IMPACT_CF + spore,
				VERSION_TU8,  // Leave at VERSION_TU8
				THRASHER_SPORE_IMPACT_CF_BITS,
				THRASHER_SPORE_IMPACT_CF_TYPE );
		}
	}
	
	ThrasherInterface::RegisterThrasherInterfaceAttributes();
}

function private InitThrasherBehaviorsAndASM()
{
	// SERVICES
	BT_REGISTER_API( "thrasherRageService",					&ThrasherBehavior::thrasherRageService );
	BT_REGISTER_API( "thrasherTargetService", 				&ThrasherBehavior::thrasherTargetService );
	BT_REGISTER_API( "thrasherKnockdownService", 			&ThrasherBehavior::thrasherKnockdownService );
	BT_REGISTER_API( "thrasherAttackableObjectService",		&ThrasherBehavior::thrasherAttackableObjectService );

	// CONDITIONS
	BT_REGISTER_API( "thrasherShouldBeStunned",				&ThrasherBehavior::thrasherShouldBeStunned );
	BT_REGISTER_API( "thrasherShouldMelee", 				&ThrasherBehavior::thrasherShouldMelee );
	BT_REGISTER_API( "thrasherShouldShowPain", 				&ThrasherBehavior::thrasherShouldShowPain );
	BT_REGISTER_API( "thrasherShouldTurnBerserk", 			&ThrasherBehavior::thrasherShouldTurnBerserk );
	BT_REGISTER_API( "thrasherShouldTeleport", 				&ThrasherBehavior::thrasherShouldTeleport );
	BT_REGISTER_API( "thrasherShouldConsumePlayer", 		&ThrasherBehavior::thrasherShouldConsumePlayer );
	BT_REGISTER_API( "thrasherShouldConsumeZombie", 		&ThrasherBehavior::thrasherShouldConsumeZombie );

	// ACTIONS
	BT_REGISTER_API( "thrasherConsumePlayer",				&ThrasherBehavior::thrasherConsumePlayer );
	BT_REGISTER_API( "thrasherConsumeZombie",				&ThrasherBehavior::thrasherConsumeZombie );
	BT_REGISTER_API( "thrasherPlayedBerserkIntro", 			&ThrasherServerUtils::thrasherPlayedBerserkIntro );
	BT_REGISTER_API( "thrasherTeleport", 					&ThrasherServerUtils::thrasherTeleport );
	BT_REGISTER_API( "thrasherTeleportOut", 				&ThrasherServerUtils::thrasherTeleportOut );
	BT_REGISTER_API( "thrasherDeath",						&ThrasherBehavior::thrasherDeath );
	BT_REGISTER_API( "thrasherStartTraverse", 				&ThrasherServerUtils::thrasherStartTraverse );
	BT_REGISTER_API( "thrasherTerminateTraverse", 			&ThrasherServerUtils::thrasherTerminateTraverse );

	// FUNCTIONS
	BT_REGISTER_API( "thrasherStunInitialize", 				&ThrasherServerUtils::thrasherStunInitialize );
	BT_REGISTER_API( "thrasherStunUpdate", 					&ThrasherServerUtils::thrasherStunUpdate );

	// MOCOMPS

	// NOTETRACKS
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_THRASHER_MELEE_NOTETRACK, &ThrasherBehavior::thrasherNotetrackMelee );
}

function private ArchetypeThrasherBlackboardInit()
{
	entity = self;

	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( entity );
	
	// USE UTILITY BLACKBOARD
	entity AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( entity );
	
	// CREATE THRASHER BLACKBOARD
	thrasher_speed = LOCOMOTION_SPEED_WALK;
	if( entity.thrasherHasTurnedBerserk === true )
	{
		thrasher_speed = LOCOMOTION_SPEED_RUN;
	}
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,		thrasher_speed,						undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SHOULD_TURN,		SHOULD_NOT_TURN,					&BB_GetShouldTurn );
	BB_REGISTER_ATTRIBUTE( ZOMBIE_DAMAGEWEAPON_TYPE,	ZOMBIE_DAMAGEWEAPON_REGULAR,		undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	entity.___ArchetypeOnAnimscriptedCallback = &ArchetypeThrasherOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING( entity );
}

function private ArchetypeThrasherOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeThrasherBlackboardInit();
}

function private thrasherSpawnSetup()
{
	entity = self;

	entity.health = THRASHER_TOTAL_HEALTH;
	entity.maxHealth = entity.health;
	entity.thrasherConsumedPlayer = false;
	
	// Berserk
	entity.thrasherIsBerserk = false;
	entity.thrasherHasTurnedBerserk = false;
	
	entity.thrasherHeadHealth = THRASHER_HEAD_HEALTH;
	
	// Consume Zombies
	entity.thrasherLastConsume = GetTime();
	entity.thrasherConsumeCooldown = THRASHER_CONSUME_COOLDOWN;
	entity.thrasherConsumeCount = 0;
	entity.thrasherConsumeMax = THRASHER_CONSUME_MAX;
	
	// Teleport
	entity.thrasherLastTeleportTime = GetTime();
	
	// Stunned
	entity.thrasherStunHealth = THRASHER_STUN_HEALTH;
	
	// Rage
	entity.thrasherRageCount = 0;
	entity.thrasherRageLevel = 1;
	
	// entity SetAvoidanceMask( "avoid none" );
	
	// Spores
	thrasherInitSpores();
	
	// Spikes
	ThrasherServerUtils::thrasherHideSpikes( entity, true );
	
	AiUtility::AddAiOverrideDamageCallback( entity, &ThrasherServerUtils::thrasherDamageCallback );
}

function private BB_GetShouldTurn()
{
	entity = self;

	if ( IsDefined( entity.should_turn ) && entity.should_turn )
	{
		return SHOULD_TURN;
	}
	return SHOULD_NOT_TURN;
}

function private thrasherInitSpores()
{
	entity = self;
	
	assert( THRASHER_SPORES.size == THRASHER_SPORE_CF_SPORES.size );
	
	thrasherSpores = THRASHER_SPORES;
	thrasherSporeDamageDists = THRASHER_SPORE_DAMAGE_DISTS;
	thrasherClientfields = THRASHER_SPORE_CF_SPORES;
	entity.thrasherSpores = [];

	for ( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeStruct = SpawnStruct();
		
		sporeStruct.dist = thrasherSporeDamageDists[ index ];
		sporeStruct.health = THRASHER_PUSTULE_HEALTH;
		sporeStruct.maxhealth = sporeStruct.health;
		sporeStruct.state = THRASHER_SPORE_STATE_HEALTHY;
		sporeStruct.tag = thrasherSpores[ index ];
		sporeStruct.clientfield = thrasherClientfields[ index ];
		
		entity.thrasherSpores[ index ] = sporeStruct;
	}
}

//----------------------------------------------------------------------------------------------------------------------------
// NOTETRACK HANDLERS
//----------------------------------------------------------------------------------------------------------------------------
function private thrasherNotetrackMelee( entity )
{
	if( isDefined( entity.thrasher_melee_knockdown_function ))
	{
		entity thread [[ entity.thrasher_melee_knockdown_function ]]();
	}
	
	hitEntity = entity Melee();
	
	if ( IsDefined( hitEntity ) && IsDefined( entity.thrasherMeleeHitCallback ) )
	{
		entity thread [[ entity.thrasherMeleeHitCallback ]]( hitEntity );
	}

	if ( AiUtility::shouldAttackObject( entity ) )
	{
		if ( IsDefined( level.attackableCallback ) )
		{
			entity.attackable [[ level.attackableCallback ]]( entity );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------------
// BEHAVIOR TREE
//----------------------------------------------------------------------------------------------------------------------------
function private thrasherGetClosestLaststandPlayer( entity )
{
	if ( entity.thrasherConsumedPlayer )
	{
		return;
	}
	
	maxConsumeDistanceSq = SQR( THRASHER_CONSUME_PLAYER_DISTANCE );

	targets = GetPlayers();
	
	// Don't consume single players
	if ( targets.size == 1 )
	{
		return;
	}
	
	laststandTargets = [];
	
	foreach ( target in targets )
	{
		if ( !IsDefined( target.laststandStartTime ) ||
			( target.laststandStartTime + THRASHER_LASTSTAND_SAFETY ) > GetTime() )
		{
			// At least THRASHER_LASTSTAND_SAFETY time must pass before targeting.
			continue;
		}
		
		if ( IsDefined( target.thrasherFreedTime ) &&
			( target.thrasherFreedTime + THRASHER_FREED_SAFETY ) > GetTime() )
		{
			// At least THRASHER_FREED_SAFETY time must pass before targeting.
			continue;
		}
	
		if ( target laststand::player_is_in_laststand() &&
			!IS_TRUE( target.thrasherConsumed ) &&
			DistanceSquared( target.origin, entity.origin ) <= maxConsumeDistanceSq )
		{
			laststandTargets[ laststandTargets.size ] = target;
		}
	}
	
	if ( laststandTargets.size > 0 )
	{
		sortedPotentialTargets = ArraySortClosest( laststandTargets, entity.origin );
		
		return sortedPotentialTargets[0];
	}
}

function private thrasherRageService( entity )
{
	entity.thrasherRageCount += entity.thrasherRageLevel * THRASHER_RAGE_AUTO_MULTIPLIER + THRASHER_RAGE_AUTO;
	
	if ( entity.thrasherRageCount >= THRASHER_RAGE_THRESHOLD )
	{
		ThrasherServerUtils::thrasherGoBerserk( entity );
	}
}

function private thrasherTargetService( entity )
{
	if ( IS_TRUE( entity.ignoreall ) )
	{
		return false;
	}
	
	if ( entity ai::get_behavior_attribute( "move_mode" ) == "friendly" )
	{
		if ( IsDefined( entity.thrasherMoveModeFriendlyCallback ) )
		{
			entity [[ entity.thrasherMoveModeFriendlyCallback ]]();
		}
		
		return true;
	}
	
	laststandPlayer = thrasherGetClosestLaststandPlayer( entity );
	
	if ( IsDefined( laststandPlayer ) )
	{
		entity.favoriteenemy = laststandPlayer;
		entity SetGoal( entity.favoriteenemy.origin );
		
		return true;
	}
	
	entity.ignore_player = [];
	players = GetPlayers();
	
	foreach ( player in players )
	{
		if ( player IsNoTarget() ||
			player.ignoreme || 
			player laststand::player_is_in_laststand() ||
			IS_TRUE( player.thrasherConsumed ) )
		{
			entity.ignore_player[ entity.ignore_player.size ] = player;
		}
	}

	player = undefined;
	
	if ( IsDefined( entity.thrasherClosestValidPlayer ) )
	{
		player = [[ entity.thrasherClosestValidPlayer ]]( entity.origin, entity.ignore_player );
	}
	else
	{
		player = zombie_utility::get_closest_valid_player( entity.origin, entity.ignore_player );
	}

	entity.favoriteenemy = player;

	if( !IsDefined( player ) || player IsNoTarget() )
	{
		if( IsDefined( entity.ignore_player ) )
		{
			if( IsDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
			{
				return;
			}
			entity.ignore_player = [];
		}

		entity SetGoal( entity.origin );		
		return false;
	}
	else if ( IsDefined( entity.attackable ) )
	{
		if ( IsDefined( entity.attackable_slot ) )
		{
			entity SetGoal( entity.attackable_slot.origin, true );
		}
	}
	else
	{
		targetPos = GetClosestPointOnNavMesh( player.origin, THRASHER_NAVMESH_RADIUS, THRASHER_NAVMESH_BOUNDARY_DIST );
		if ( IsDefined( targetPos ) )
		{
			entity SetGoal( targetPos );		
			return true;
		}
		else
		{
			entity SetGoal( entity.origin );
			return false;
		}
	}
}

function private thrasherAttackableObjectService( entity )
{
	if ( IsDefined( entity.thrasherAttackableObjectCallback ) )
	{
		return [[ entity.thrasherAttackableObjectCallback ]]( entity );
	}
	
	return false;
}

function private thrasherKnockdownService( entity )
{
	velocity = entity GetVelocity();
	predict_time = 0.3;
	predicted_pos = entity.origin + ( velocity * predict_time );
	move_dist_sq = DistanceSquared( predicted_pos, entity.origin );
	speed = move_dist_sq /  predict_time;
	
	if( speed >= 10 )
	{
		a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
		
		a_filtered_zombies = array::filter( a_zombies, false, &thrasherZombieEligibleForKnockdown, entity, predicted_pos );
		
		if( a_filtered_zombies.size > 0 )
		{
			foreach( zombie in a_filtered_zombies )
			{
				ThrasherServerUtils::thrasherKnockdownZombie( entity, zombie );
			}
		}
	}
}

function private thrasherZombieEligibleForKnockdown( zombie, thrasher, predicted_pos )
{
	if( zombie.knockdown === true )
	{
		return false;
	}
	
	knockdown_dist_sq = 48*48;
		                               	
	dist_sq = DistanceSquared( predicted_pos, zombie.origin );
	
	if( dist_sq > knockdown_dist_sq )
	{
		return false;
	}
	
	origin = thrasher.origin;

	facing_vec = AnglesToForward( thrasher.angles );
	enemy_vec = zombie.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < 0 )// is enemy behind thrasher
	{
		return false;
	}
	
	return true;
	
}

//----------------------------------------------------------------------------------------------------------------------------------
// CONDITIONS
//----------------------------------------------------------------------------------------------------------------------------------
function thrasherShouldMelee( entity )
{
	if( !IsDefined( entity.favoriteenemy ) )
    {
		return false;
	}

	if( DistanceSquared( entity.origin, entity.favoriteenemy.origin ) > THRASHER_MELEE_DIST_SQ )
	{
		return false;
	}
	
	if ( entity.favoriteenemy IsNoTarget() )
	{
		return false;
	}

	yaw = abs( zombie_utility::getYawToEnemy() );
	if( ( yaw > THRASHER_MELEE_YAW ) )
	{
		return false;
	}
	
	if ( entity.favoriteenemy laststand::player_is_in_laststand() )
	{
		return false;
	}
	
	return true;
}

function private thrasherShouldShowPain( entity )
{
	return false;
}

function private thrasherShouldTurnBerserk( entity )
{
	return entity.thrasherIsBerserk && !entity.thrasherHasTurnedBerserk;
}

function private thrasherShouldTeleport( entity )
{
	if ( !IsDefined( entity.favoriteenemy ) )
	{
		return false;
	}
	
	if ( ( entity.thrasherLastTeleportTime + THRASHER_TELEPORT_COOLDOWN ) > GetTime() )
	{
		return false;
	}
	
	if ( DistanceSquared( entity.origin, entity.favoriteenemy.origin ) >= THRASHER_TELERPOT_MIN_DISTANCE_SQ )
	{
		if ( IsDefined( entity.thrasherShouldTeleportCallback ) )
		{
			return ( [[ entity.thrasherShouldTeleportCallback ]]( entity.origin ) &&
				[[ entity.thrasherShouldTeleportCallback ]]( entity.favoriteenemy.origin ) );
		}
		else
		{
			return true;
		}
	}
	
	return false;
}

function private thrasherShouldConsumePlayer( entity )
{
	if( !IsDefined( entity.favoriteenemy ) )
    {
		return false;
	}
	
	targets = GetPlayers();
	
	// Don't consume single players
	if ( targets.size == 1 )
	{
		return false;
	}

	if( DistanceSquared( entity.origin, entity.favoriteenemy.origin ) > THRASHER_CONSUME_DIST_SQ )
	{
		return false;
	}

	if ( !entity.favoriteenemy laststand::player_is_in_laststand() )
	{
		return false;
	}
	
	if ( IS_TRUE( entity.favoriteenemy.thrasherConsumed ) )
	{
		return false;
	}
	
	if ( IsDefined( entity.thrasherCanConsumePlayerCallback ) && !entity [[ entity.thrasherCanConsumePlayerCallback ]]( entity ) )
	{
		return false;
	}
	
	return true;
}

function private thrasherShouldConsumeZombie( entity )
{
	if ( entity.thrasherConsumeCount >= entity.thrasherConsumeMax )
	{
		return false;
	}
	
	if ( ( entity.thrasherLastConsume + entity.thrasherConsumeCooldown ) >= GetTime() )
	{
		return false;
	}

	hasPoppedPustule = false;

	for( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeStruct = entity.thrasherSpores[ index ];
		if ( sporeStruct.health <= 0 )
		{
			hasPoppedPustule = true;
			break;
		}
	}
	
	if ( hasPoppedPustule )
	{
		if ( IsDefined( entity.thrasherCanConsumeCallback ) )
		{
			return [[ entity.thrasherCanConsumeCallback ]]( entity );
		}
	}

	return false;
}

function private thrasherConsumePlayer( entity )
{
	if ( IsPlayer( entity.favoriteenemy ) )
	{
		entity thread ThrasherServerUtils::thrasherConsumePlayerUtil( entity, entity.favoriteenemy );
	}
}

function private thrasherDeath( entity )
{
	GibServerUtils::Annihilate( entity );
}

function private thrasherConsumeZombie( entity )
{
	if ( IsDefined( entity.thrasherConsumeZombieCallback ) )
	{
		if ( [[ entity.thrasherConsumeZombieCallback ]]( entity ) )
		{
			entity.thrasherConsumeCount++;
			entity.thrasherLastConsume = GetTime();
		}
	}
}

function private thrasherShouldBeStunned( entity )
{
	return entity ai::get_behavior_attribute( "stunned" );
}

#namespace ThrasherServerUtils;

function thrasherKnockdownZombie( entity, zombie )
{
	zombie.knockdown = true;
	zombie.knockdown_type = KNOCKDOWN_SHOVED;
	zombie_to_thrasher = entity.origin - zombie.origin;
	zombie_to_thrasher_2d = VectorNormalize( ( zombie_to_thrasher[0], zombie_to_thrasher[1], 0 ) );
	
	zombie_forward = AnglesToForward( zombie.angles );
	zombie_forward_2d = VectorNormalize( ( zombie_forward[0], zombie_forward[1], 0 ) );
	
	zombie_right = AnglesToRight( zombie.angles );
	zombie_right_2d = VectorNormalize( ( zombie_right[0], zombie_right[1], 0 ) );
	
	dot = VectorDot( zombie_to_thrasher_2d, zombie_forward_2d );
	
	if( dot >= 0.5 )
	{
		zombie.knockdown_direction = "front";
		zombie.getup_direction = GETUP_BACK;
	}
	else if ( dot < 0.5 && dot > -0.5 )
	{
		dot = VectorDot( zombie_to_thrasher_2d, zombie_right_2d );
		if( dot > 0 )
		{
			zombie.knockdown_direction = "right";

			if ( math::cointoss() )
			{
				zombie.getup_direction = GETUP_BACK;
			}
			else
			{
				zombie.getup_direction = GETUP_BELLY;
			}
		}
		else
		{
			zombie.knockdown_direction = "left";
			zombie.getup_direction = GETUP_BELLY;
		}
	}
	else
	{
		zombie.knockdown_direction = "back";
		zombie.getup_direction = GETUP_BELLY;
	}
}

function thrasherGoBerserk( entity )
{
	if ( !entity.thrasherIsBerserk )
	{
		entity thread thrasherInvulnerability( THRASHER_RAGE_INVULNERABLE_TIME );
		entity.thrasherIsBerserk = true;
		entity.health += THRASHER_RAGE_HEALTH_BONUS;
		entity clientfield::set( THRASHER_BERSERK_CF, THRASHER_BERSERK_CF_BERSERK );
		ThrasherServerUtils::thrasherHideSpikes( entity, false );
	}
}

function private thrasherPlayedBerserkIntro( entity )
{
	entity.thrasherHasTurnedBerserk = true;
	meleeWeapon = GetWeapon( THRASHER_MELEE_ENRAGED );
	entity.meleeweapon = GetWeapon( THRASHER_MELEE_ENRAGED );
	entity ai::set_behavior_attribute( "stunned", false );
	entity.thrasherStunHealth = THRASHER_STUN_HEALTH;
	
	Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );
}

function thrasherDamageCallback( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	if ( hitLoc == THRASHER_HEAD_HITLOC &&
		!GibServerUtils::IsGibbed( entity, GIB_TORSO_HEAD_FLAG ) )
	{
		entity.thrasherRageCount += THRASHER_RAGE_INC_HEADSHOT;
		entity.thrasherHeadHealth -= damage;
	
		if( entity.thrasherHeadHealth <= 0 )
		{
			if( isdefined( attacker ) )
			{
				attacker notify( "destroyed_thrasher_head" );
			}
			
			GibServerUtils::GibHead( entity );
			thrasherHidePoppedPustules( entity );
		}
	}
	else
	{
		entity.thrasherRageCount += THRASHER_RAGE_INC_NONVITAL;
		
		entity.thrasherStunHealth -= damage;
		if ( entity.thrasherStunHealth <= 0 )
		{
			entity ai::set_behavior_attribute( "stunned", true );
			if ( IsDefined( attacker ) )
			{
				attacker notify( "player_stunned_thrasher" ); // For VO and other applications.
			}
		}
	}
	
	damage = thrasherSporeDamageCallback( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
	
	if ( entity.thrasherRageCount >= THRASHER_RAGE_THRESHOLD )
	{
		thrasherGoBerserk( entity );
		
		if ( IsDefined( attacker ) )
		{
			attacker notify( "player_enraged_thrasher" ); // For VO and other applications.
		}
	}
	
	if ( IS_TRUE( entity.b_thrasher_temp_invulnerable ) )
	{
		damage = 1;
	}
	
	damage = Int( damage );
	
	return damage;
}

function private thrasherInvulnerability( n_time )
{
	entity = self;
	
	entity endon( "death" );
	entity notify( "end_invulnerability" );
	
	entity.b_thrasher_temp_invulnerable = true;
	
	entity util::waittill_notify_or_timeout( "end_invulnerability", n_time );
	
	entity.b_thrasher_temp_invulnerable = false;
}

function thrasherSporeDamageCallback( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	assert( IsDefined( entity.thrasherSpores ) );
	
	if ( !IsDefined( point ) )
	{
		return damage;
	}

	healthySpores = 0;

	for( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeStruct = entity.thrasherSpores[ index ];
		assert( IsDefined( sporeStruct ) );
		
		if ( sporeStruct.health < 0 )
		{
			// Pustule already destroyed.
			continue;
		}
		
		tagOrigin = entity GetTagOrigin( sporeStruct.tag );
		
		if ( IsDefined( tagOrigin ) && DistanceSquared( tagOrigin, point ) < SQR( sporeStruct.dist ) )
		{
			entity.thrasherRageCount += THRASHER_RAGE_INC_PUSTULE;
			sporeStruct.health -= damage;
			
			entity clientfield::increment( THRASHER_SPORE_IMPACT_CF + sporeStruct.clientfield );
			
			if ( sporeStruct.health <= 0 )
			{
				entity HidePart( sporeStruct.tag );
				sporeStruct.state = THRASHER_SPORE_STATE_DESTROYED;
				
				destroyedSpores = entity clientfield::get( THRASHER_SPORE_CF );
				destroyedSpores |= sporeStruct.clientfield;
				entity clientfield::set( THRASHER_SPORE_CF, destroyedSpores );
				
				if ( IsDefined( entity.thrasherPustulePopCallback ) )
				{
					entity thread [[ entity.thrasherPustulePopCallback ]]( tagOrigin, weapon, attacker );
				}
				
				entity ai::set_behavior_attribute( "stunned", true );
				
				damage = entity.maxHealth / THRASHER_SPORES.size;
			}
			
			/#
			RecordSphere( tagOrigin, sporeStruct.dist, YELLOW, "Script", entity );
			#/
		}
		
		if ( sporeStruct.health > 0 )
		{
			healthySpores++;
		}
	}
	
	if ( healthySpores == 0 )
	{
		// All weak spots destroyed, kill off the thrasher.
		damage = entity.maxHealth;
	}
	
	return damage;
}

function private thrasherTeleportOut( entity )
{
	if ( IsDefined( entity.thrasherTeleportCallback ) )
	{
		entity thread [[ entity.thrasherTeleportCallback ]]( entity );
	}
}

function thrasherStartTraverse( entity )
{
	AiUtility::traverseSetup( entity );

	if ( IsDefined( entity.thrasherStartTraverseCallback ) )
	{
		entity [[ entity.thrasherStartTraverseCallback ]]( entity );
	}
}

function thrasherTerminateTraverse( entity )
{
	if ( IsDefined( entity.thrasherTerminateTraverseCallback ) )
	{
		entity [[ entity.thrasherTerminateTraverseCallback ]]( entity );
	}
}

function thrasherTeleport( entity )
{
	if( !IsDefined( entity.favoriteenemy ))
	{
		/#println ("*** Thrasher is trying to teleport, but has no favorite enemy, so he cannot ***" );#/
		return;			
	}
	
	points = util::PositionQuery_PointArray(
		entity.favoriteenemy.origin,
		THRASHER_TELEPORT_DESTINATION_SAFE_RADIUS,
		THRASHER_TELEPORT_DESTINATION_MAX_RADIUS,
		32,
		64,
		entity );
	
	filteredPoints = [];
	thrashers = GetAIArchetypeArray( "thrasher" );
	overlapSqr = SQR( THRASHER_TELEPORT_OVERLAP );
	
	foreach ( point in points )
	{
		valid = true;
		
		foreach ( thrasher in thrashers )
		{
			if ( DistanceSquared( point, thrasher.origin ) <= overlapSqr )
			{
				valid = false;
				break;
			}
		}
		
		if ( valid )
		{
			filteredPoints[ filteredPoints.size ] = point;
		}
	}
	
	//filter points again if needed with stricter criteria
	if( isdefined( entity.thrasher_teleport_dest_func ) )
	{
		filteredPoints = entity [[entity.thrasher_teleport_dest_func]]( filteredPoints );
	}
	
	sortedPoints = ArraySortClosest( filteredPoints, entity.origin );
	teleport_point = sortedPoints[0];
	
	if ( IsDefined( teleport_point ) )
	{
		v_dir = ( entity.favoriteenemy.origin - teleport_point );
		v_dir = VectorNormalize( v_dir );
		v_angles = VectorToAngles( v_dir );
			
		entity ForceTeleport( teleport_point, v_angles );
	}
	
	entity.thrasherLastTeleportTime = GetTime();
}

function private thrasherStunInitialize( entity )
{
	entity.thrasherStunStartTime = GetTime();
}

function private thrasherStunUpdate( entity )
{
	if ( entity.thrasherStunStartTime + THRASHER_STUN_TIME < GetTime() )
	{
		entity ai::set_behavior_attribute( "stunned", false );
		entity.thrasherStunHealth = THRASHER_STUN_HEALTH;
	}
}

function private thrasherHideSpikes( entity, hide )
{
	for ( index = 1; index <= THRASHER_SPIKE_COUNT; index++ )
	{
		tag = "j_spike";
		if ( index < 10 )
		{
			tag = tag + "0";
		}
		tag = tag + index + "_root";
		
		if ( hide )
		{
			entity HidePart( tag, "", true );
		}
		else
		{
			entity ShowPart( tag, "", true );
		}
	}
}

function thrasherHideFromPlayer( thrasher, player, hide )
{
	entityNumber = player GetEntityNumber();
	entityBit = 1 << entityNumber;
	
	currentHidden = clientfield::get( "thrasher_player_hide" );
	hiddenPlayers = currentHidden;
	
	if (hide )
	{
		hiddenPlayers = currentHidden | entityBit;
	}
	else
	{
		hiddenPlayers = currentHidden & ~entityBit;
	}
	
	thrasher clientfield::set( "thrasher_player_hide", hiddenPlayers );
}

function thrasherHidePoppedPustules( entity )
{
	for( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeStruct = entity.thrasherSpores[ index ];
		
		if ( sporeStruct.health <= 0 )
		{
			entity HidePart( sporeStruct.tag );
		}
		else
		{
			entity ShowPart( sporeStruct.tag );
		}
	}
}

function thrasherRestorePustule( entity )
{
	for( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeStruct = entity.thrasherSpores[ index ];
		
		if ( sporeStruct.health <= 0 )
		{
			sporeStruct.health = sporeStruct.maxhealth;
			entity.health += Int( entity.maxHealth / THRASHER_SPORES.size );
			
			destroyedSpores = entity clientfield::get( THRASHER_SPORE_CF );
			destroyedSpores &= ~sporeStruct.clientfield;
			entity clientfield::set( THRASHER_SPORE_CF, destroyedSpores );
			
			break;
		}
	}
	
	thrasherHidePoppedPustules( entity );
}

function thrasherCreatePlayerClone( player )
{
	clone = Spawn( "script_model", player.origin );
	clone.angles = player.angles;
	
	// Clone player's look
	bodyModel = player GetCharacterBodyModel();
	if ( IsDefined( bodyModel ) )
	{
		clone SetModel( bodyModel );
	}
	
	headModel = player GetCharacterHeadModel();
	if ( IsDefined( headModel ) && headModel != "tag_origin" )
	{
		if ( IsDefined( clone.head ) )
		{
			clone Detach( clone.head );
		}
		
		clone Attach( headModel );
	}
	
	helmetModel = player GetCharacterHelmetModel();
	if ( IsDefined( helmetModel ) && headModel != "tag_origin" )
	{
		clone Attach( helmetModel );
	}
	
	return clone;
}

function thrasherHidePlayerBody( thrasher, player )
{
	player endon( "death" );
	
	player waittill( "hide_body" );
	
	player Hide();
}

function thrasherCanBeRevived( revivee )
{
	if ( IsDefined( revivee.thrasherConsumed ) && revivee.thrasherConsumed )
	{
		return false;
	}
	
	return true;
}

function private thrasherStopConsumePlayerScene( thrasher, playerClone )
{
	thrasher endon( "consume_scene_end" );
	
	thrasher waittill( "death" );
	
	if ( IsDefined( thrasher ) )
	{
		thrasher scene::stop( "scene_zm_dlc2_thrasher_eat_player" );
	}
	
	if ( IsDefined( playerClone ) )
	{
		playerClone Delete();
	}
}

function private thrasherConsumePlayerScene( thrasher, playerClone )
{
	thrasher endon( "death" );
	
	thrasher thread thrasherStopConsumePlayerScene( thrasher, playerClone );
	thrasher scene::play( "scene_zm_dlc2_thrasher_eat_player", array( thrasher, playerClone ) );
	thrasher notify( "consume_scene_end" );
	
	targetPos = GetClosestPointOnNavMesh( thrasher.origin, 1024, 18 );
	
	if ( IsDefined( targetPos ) )
	{
		thrasher ForceTeleport( targetPos );
	}
}

function thrasherConsumePlayerUtil( thrasher, player )
{
	assert( IsActor( thrasher ) );
	assert( thrasher.archetype == "thrasher" );
	assert( IsPlayer( player ) );
	
	thrasher endon( "kill_consume_player" );
	
	if ( IS_TRUE( player.thrasherConsumed ) )
	{
		return;
	}
	
	playerClone = thrasherCreatePlayerClone( player );
	playerClone.origin = player.origin;
	playerClone.angles = player.angles;
	playerClone Hide();
	
	thrasher.offsetModel = Spawn( "script_model", thrasher.origin );
	
	util::wait_network_frame();
	
	if ( !IsDefined( thrasher ) || IS_TRUE( player.thrasherConsumed ) )
	{
		playerClone Destroy();
		return;
	}
	
	thrasherHideFromPlayer( thrasher, player, true );
	
	if ( IsDefined( thrasher.thrasherConsumedCallback ) )
	{
		[[ thrasher.thrasherConsumedCallback ]]( thrasher, player );
	}
	
	if ( IsDefined( player.revivetrigger ) )
	{
		player.revivetrigger SetInvisibleToAll();
		player.revivetrigger TriggerEnable( false );
	}
	
	player SetClientUIVisibilityFlag( "hud_visible", 0 );
	player SetClientUIVisibilityFlag( "weapon_hud_visible", 0 );
	player.thrasherConsumed = true;
	player.thrasher = thrasher;
	player SetPlayerCollision( false );
	player WalkUnderwater( true );
	player.ignoreme = true;
	player HideViewModel();
	player FreezeControls( false );
	player FreezeControlsAllowLook( true );
	player thread lui::screen_fade_in( 10 );
	player clientfield::set_to_player( "sndPlayerConsumed", 1 );
	visionset_mgr::activate( "visionset", THRASHER_CONSUMED_PLAYER_VISIONSET_ALIAS, player, THRASHER_CONSUMED_PLAYER_VISIONSET_RAMP_IN_DURATION );
	player thread thrasherKillThrasherOnAutoRevive( thrasher, player );
	
	eyePosition = player GetTagOrigin( "tag_eye" );
	eyeOffset = abs( eyePosition[2] - player.origin[2] ) + 10;
	
	thrasher.offsetModel LinkTo( thrasher, "tag_camera_thrasher", ( 0, 0, -eyeOffset + 27 ) ); //HACK raising player body another 27 units so that revive icon is above thrasher's head. Check if there's a UI-specific way to do this
	
	// player PlayerLinkTo( thrasher.offsetModel, undefined, 0.2, 25, 25, 5, 5 );
	// player PlayerLinkTo( thrasher.offsetModel );
	player PlayerLinkTo( thrasher.offsetModel, undefined, 1, 0, 0, 0, 0, true );
	
	thrasher thread thrasherPlayerDeath( thrasher, player );
	
	thrasher.thrasherConsumedPlayer = true;
	thrasher.thrasherPlayer = player;
	
	// Prevent the thrasher from teleporting to the next enemy.
	thrasher.thrasherLastTeleportTime = GetTime();
	
	player Ghost();
	playerClone Show();
	
	if ( IsDefined( playerClone ) )
	{
		thrasher thread thrasherConsumePlayerScene( thrasher, playerClone );
		playerClone thread thrasherHidePlayerBody( thrasher, playerClone );
		
		// Notify for VO and other applications.
		player notify( "player_eaten_by_thrasher" );
	}
	
	thrasher waittill( "death" );
	
	thrasherReleasePlayer( thrasher, player );
}

function thrasherKillThrasherOnAutoRevive( thrasher, player )
{
	player endon( "death" );
	player endon( "kill_thrasher_on_auto_revive" );
	
	player waittill( "bgb_revive" );
	
	if ( IsDefined( player.thrasher ) )
	{
		player.thrasher Kill();
	}
}

function thrasherReleasePlayer( thrasher, player )
{
	if ( !IsAlive( player ) )
	{
		return;
	}

	if ( IsDefined( thrasher.offsetModel ) )
	{
		thrasher.offsetModel Unlink();
		thrasher.offsetModel Delete();
	}

	if ( IsDefined( player.revivetrigger ) )
	{
		player.revivetrigger SetVisibleToAll();
		player.revivetrigger TriggerEnable( true );
	}
	
	// thrasherHideFromPlayer( thrasher, player, false );
	
	if ( IsDefined( thrasher.thrasherReleaseConsumedCallback ) )
	{
		[[ thrasher.thrasherReleaseConsumedCallback ]]( thrasher, player );
	}
	
	thrasher.thrasherPlayer = undefined;
	
	player SetClientUIVisibilityFlag( "hud_visible", 1 );
	player SetClientUIVisibilityFlag( "weapon_hud_visible", 1 );
	player.thrasherFreedTime = GetTime();
	player SetStance( "prone" );
	player notify( "kill_thrasher_on_auto_revive" );
	player.thrasherConsumed = undefined;
	player.thrasher = undefined;
	player WalkUnderwater( false );
	player Unlink();
	player SetPlayerCollision( true );
	player Show();
	player.ignoreme = false;
	player ShowViewModel();
	player FreezeControlsAllowLook( false );
	player thread lui::screen_fade_in( 2 );
	player clientfield::set_to_player( "sndPlayerConsumed", 0 );
	visionset_mgr::deactivate( "visionset", THRASHER_CONSUMED_PLAYER_VISIONSET_ALIAS, player );
	player thread check_revive_after_consumed();
	
	targetPos = GetClosestPointOnNavMesh( player.origin, 1024, 18 );
	
	if ( IsDefined( targetPos ) )
	{
		newPosition = player.origin;
		groundPosition = bullettrace( targetPos + (0, 0, -128), targetPos + (0, 0, 128), false, player );
		
		if ( IsDefined( groundPosition[ "position" ] ) )
		{
			newPosition = groundPosition[ "position" ];
		}
		else
		{
			groundPosition = bullettrace( targetPos + (0, 0, -256), targetPos + (0, 0, 256), false, player );
			
			if ( IsDefined( groundPosition[ "position" ] ) )
			{
				newPosition = groundPosition[ "position" ];
			}
			else
			{
				groundPosition = bullettrace( targetPos + (0, 0, -512), targetPos + (0, 0, 512), false, player );
			
				if ( IsDefined( groundPosition[ "position" ] ) )
				{
					newPosition = groundPosition[ "position" ];
				}
			}
		}
		
		if ( newPosition[2] > player.origin[2] )
		{
			player.origin = newPosition;
		}
	}
		
	// Kill off the thread waiting to release the player, just in case.
	thrasher notify( "kill_consume_player" );
}

//self is a player
function check_revive_after_consumed()
{
	self endon( "death" );
	
	self waittill( "player_revived" );
	
	self notify( "achievement_ZM_ISLAND_THRASHER_RESCUE" );
}

function thrasherPlayerDeath( thrasher, player )
{
	thrasher endon( "kill_consume_player" );
	
	thrasher.thrasherPlayer = undefined;
	
	characterIndex = player.characterindex;
	
	if ( !IsDefined( characterIndex ) )
	{
		return;
	}
	
	level waittill( "bleed_out", characterIndex );
	
	if ( IsDefined( thrasher.thrasherReleaseConsumedCallback ) )
	{
		[[ thrasher.thrasherReleaseConsumedCallback ]]( thrasher, player );
	}
	
	if ( IsDefined( thrasher ) && IsDefined( player ) )
	{
		thrasherHideFromPlayer( thrasher, player, false );
	}
	
	if ( IsDefined( player ) )
	{
		player ShowViewModel();
		player clientfield::set_to_player( "sndPlayerConsumed", 0 );
		visionset_mgr::deactivate( "visionset", THRASHER_CONSUMED_PLAYER_VISIONSET_ALIAS, player );
	}
}

function thrasherMoveModeAttributeCallback( entity, attribute, oldValue, value )
{
	if ( value == "normal" )
	{
		entity.team = "axis";
	}
	else if ( value == "friendly" )
	{
		entity.team = "allies";
	}
}
