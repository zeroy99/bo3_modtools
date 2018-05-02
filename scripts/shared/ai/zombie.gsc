#using scripts\shared\ai_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_shared;
#using scripts\codescripts\struct;
#using scripts\shared\ai\archetype_mocomps_utility;

//INTERFACE
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\archetype_zombie_interface;

#insert scripts\shared\ai\archetype_damage_effects.gsh;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\zombie.gsh; 
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace ZombieBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitZombieBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &ArchetypeZombieBlackboardInit );
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &ArchetypeZombieDeathOverrideInit );
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &ArchetypeZombieSpecialEffectsInit );
		
	// INIT ZOMBIE ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &zombie_utility::zombieSpawnSetup );
	
	clientfield::register(
		"actor",
		ZOMBIE_CLIENTFIELD,
		VERSION_SHIP,
		1,
		"int");
	
	clientfield::register(
		"actor",
	    ZOMBIE_SPECIAL_DAY_EFFECTS_CLIENTFIELD, 
	    VERSION_TU6_FFOTD_020416_0, 
	    1, 
	    "counter" );
	
	ZombieInterface::RegisterZombieInterfaceAttributes();
}

function private InitZombieBehaviorsAndASM()
{
	BT_REGISTER_ACTION( "zombieMoveAction", 			&zombieMoveAction, &zombieMoveActionUpdate, undefined );
	BT_REGISTER_API( "zombieTargetService", 			&zombieTargetService );
	BT_REGISTER_API( "zombieCrawlerCollisionService", 	&zombieCrawlerCollision);
	BT_REGISTER_API( "zombieTraversalService",			&zombieTraversalService);

	BT_REGISTER_API( "zombieIsAtAttackObject",			&zombieIsAtAttackObject );
	BT_REGISTER_API( "zombieShouldAttackObject",		&zombieShouldAttackObject );
	BT_REGISTER_API( "zombieShouldMelee", 				&zombieShouldMeleeCondition );
	BT_REGISTER_API( "zombieShouldJumpMelee", 			&zombieShouldJumpMeleeCondition );
	BT_REGISTER_API( "zombieShouldJumpUnderwaterMelee", &zombieShouldJumpUnderwaterMelee );
	BT_REGISTER_API( "zombieGibLegsCondition",			&zombieGibLegsCondition ); 
	BT_REGISTER_API( "zombieShouldDisplayPain", 		&zombieShouldDisplayPain ); 
	BT_REGISTER_API( "isZombieWalking", 				&isZombieWalking );

	BT_REGISTER_API( "zombieShouldMeleeSuicide", 		&zombieShouldMeleeSuicide );
	BT_REGISTER_API( "zombieMeleeSuicideStart", 		&zombieMeleeSuicideStart );	
	BT_REGISTER_API( "zombieMeleeSuicideUpdate", 		&zombieMeleeSuicideUpdate );	
	BT_REGISTER_API( "zombieMeleeSuicideTerminate", 	&zombieMeleeSuicideTerminate );	
		
	BT_REGISTER_API( "zombieShouldJuke",				&zombieShouldJukeCondition );
	BT_REGISTER_API( "zombieJukeActionStart",			&zombieJukeActionStart );
	BT_REGISTER_API( "zombieJukeActionTerminate",		&zombieJukeActionTerminate );

	BT_REGISTER_API( "zombieDeathAction", 				&zombieDeathAction ); 
	
	BT_REGISTER_API( "zombieJukeService", 				&zombieJuke );
	BT_REGISTER_API( "zombieStumbleService",			&zombieStumble );
	BT_REGISTER_API( "zombieStumbleCondition",			&zombieShouldStumbleCondition );
	BT_REGISTER_API( "zombieStumbleActionStart",		&zombieStumbleActionStart );

	BT_REGISTER_API( "zombieAttackObjectStart",			&zombieAttackObjectStart );
	BT_REGISTER_API( "zombieAttackObjectTerminate",		&zombieAttackObjectTerminate );

	BT_REGISTER_API( "wasKilledByInterdimensionalGun", &wasKilledByInterdimensionalGunCondition);
	BT_REGISTER_API( "wasCrushedByInterdimensionalGunBlackhole", &wasCrushedByInterdimensionalGunBlackholeCondition);
	BT_REGISTER_API( "zombieIDGunDeathUpdate", 			&zombieIDGunDeathUpdate);
	BT_REGISTER_API( "zombieVortexPullUpdate", 			&zombieIDGunDeathUpdate); //for doa
		
	BT_REGISTER_API( "zombieHasLegs", 					&zombieHasLegs);
	BT_REGISTER_API( "zombieShouldProceduralTraverse",	&zombieShouldProceduralTraverse );
	
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_ZOMBIE_MELEE_NOTETRACK, &zombieNotetrackMeleeFire );
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_ZOMBIE_CRUSH_NOTETRACK, &zombieNotetrackCrushFire );
	
	// ------- ZOMBIE DEATH -----------//
	ASM_REGISTER_MOCOMP( "mocomp_death_idgun@zombie",		&zombieIDGunDeathMocompStart, undefined, undefined);
	ASM_REGISTER_MOCOMP( "mocomp_vortex_pull@zombie",		&zombieIDGunDeathMocompStart, undefined, undefined); //for doa
	ASM_REGISTER_MOCOMP( "mocomp_death_idgun_hole@zombie",	&zombieIDGunHoleDeathMocompStart, undefined, &zombieIDGunHoleDeathMocompTerminate);
	ASM_REGISTER_MOCOMP( "mocomp_turn@zombie",				&zombieTurnMocompStart, &zombieTurnMocompUpdate, &zombieTurnMocompTerminate );
	ASM_REGISTER_MOCOMP( "mocomp_melee_jump@zombie",		&zombieMeleeJumpMocompStart, &zombieMeleeJumpMocompUpdate, &zombieMeleeJumpMocompTerminate );
	ASM_REGISTER_MOCOMP( "mocomp_zombie_idle@zombie",		&zombieZombieIdleMocompStart, undefined, undefined );

	ASM_REGISTER_MOCOMP( "mocomp_attack_object@zombie",		&zombieAttackObjectMocompStart, &zombieAttackObjectMocompUpdate, undefined );
}

function ArchetypeZombieBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();

	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( self );
	
	// CREATE ZOMBIE BLACKBOARD
	BB_REGISTER_ATTRIBUTE( ARMS_POSITION, 			ARMS_UP,				&BB_GetArmsPosition );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,	LOCOMOTION_SPEED_WALK,	&BB_GetLocomotionSpeedType );
	BB_REGISTER_ATTRIBUTE( HAS_LEGS_TYPE,			HAS_LEGS_YES,			&BB_GetHasLegsStatus );
	BB_REGISTER_ATTRIBUTE( VARIANT_TYPE, 			0,						&BB_GetVariantType );
	BB_REGISTER_ATTRIBUTE( WHICH_BOARD_PULL_TYPE,	undefined, 				undefined );
	BB_REGISTER_ATTRIBUTE( BOARD_ATTACK_SPOT,		undefined, 				undefined );	
	BB_REGISTER_ATTRIBUTE( GRAPPLE_DIRECTION,		undefined,				undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SHOULD_TURN,	SHOULD_NOT_TURN,		&BB_GetShouldTurn );
	BB_REGISTER_ATTRIBUTE( IDGUN_DAMAGE_DIRECTION, 	DAMAGE_DIRECTION_BACK,	&BB_IDGunGetDamageDirection );
	BB_REGISTER_ATTRIBUTE( LOW_GRAVITY_VARIANT, 	0,						&BB_GetLowGravityVariant );
	BB_REGISTER_ATTRIBUTE( KNOCKDOWN_DIRECTION, 	undefined,				undefined );
	BB_REGISTER_ATTRIBUTE( KNOCKDOWN_TYPE, 			undefined,				undefined );
	BB_REGISTER_ATTRIBUTE( WHIRLWIND_SPEED, 		WHIRLWIND_NORMAL,		undefined );
	BB_REGISTER_ATTRIBUTE( BLACKHOLEBOMB_PULL_STATE,undefined,				undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeZombieOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
	
}

function private ArchetypeZombieOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeZombieBlackboardInit();
}

function ArchetypeZombieSpecialEffectsInit()
{
	AiUtility::AddAIOverrideDamageCallback( self, &ArchetypeZombieSpecialEffectsCallback );
}

function private ArchetypeZombieSpecialEffectsCallback( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	specialDayEffectChance = GetDvarInt("tu6_ffotd_zombieSpecialDayEffectsChance", 0);

	if( specialDayEffectChance && RandomInt(100) < specialDayEffectChance )
	{
		if( IsDefined( eAttacker ) && IsPlayer( eAttacker ) )
		{
			self clientfield::increment(ZOMBIE_SPECIAL_DAY_EFFECTS_CLIENTFIELD);
		}
	}
	
	return iDamage;
}

// ------- BLACKBOARD -----------//

function BB_GetArmsPosition()
{
	if( IsDefined( self.zombie_arms_position ) )
	{
		if( self.zombie_arms_position == "up" )
			return ARMS_UP;
		return ARMS_DOWN;
	}
	
	return ARMS_UP;
}

function BB_GetLocomotionSpeedType()
{
	if ( IsDefined( self.zombie_move_speed ) )
	{
		if( self.zombie_move_speed == "walk" )
		{
			return LOCOMOTION_SPEED_WALK;
		}
		else if( self.zombie_move_speed == "run" )
		{
			return LOCOMOTION_SPEED_RUN;
		}
		else if( self.zombie_move_speed == "sprint" )
		{
			return LOCOMOTION_SPEED_SPRINT;
		}
		else if( self.zombie_move_speed == "super_sprint" )
		{
			return LOCOMOTION_SPEED_SUPER_SPRINT;
		}
		else if( self.zombie_move_speed == "jump_pad_super_sprint" )
		{
			return LOCOMOTION_SPEED_JUMP_PAD_SUPER_SPRINT;
		}
		else if( self.zombie_move_speed == "burned" )
		{
			return LOCOMOTION_SPEED_BURNED;
		}
		else if( self.zombie_move_speed == "slide" )
		{
			return LOCOMOTION_SPEED_SLIDE;
		}
	}
	return LOCOMOTION_SPEED_WALK;
}

function BB_GetVariantType()
{
	if( IsDefined( self.variant_type ) )
	{
		return self.variant_type;
	}
	return 0;
}

function BB_GetHasLegsStatus()
{
	if( self.missingLegs )
		return HAS_LEGS_NO;
	return HAS_LEGS_YES;
}

function BB_GetShouldTurn()
{
	if( IsDefined( self.should_turn ) && self.should_turn )
	{
		return SHOULD_TURN;
	}
	return SHOULD_NOT_TURN;
}

function BB_IDGunGetDamageDirection()
{
	if( IsDefined( self.damage_direction ) )
	{
		return self.damage_direction;
	}
	return self AiUtility::BB_GetDamageDirection();
}

function BB_GetLowGravityVariant()
{
	if ( isdefined( self.low_gravity_variant ) )
	{
		return self.low_gravity_variant;
	}

	return 0;
}

// ------- BLACKBOARD -----------//

function isZombieWalking( behaviorTreeEntity )
{
	return !IS_TRUE(behaviorTreeEntity.missingLegs);
}

function zombieShouldDisplayPain( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.suicidalDeath ) )
		return false;
	
	return !IS_TRUE(behaviorTreeEntity.missingLegs);
}

function zombieShouldJukeCondition( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.juke ) && ( behaviorTreeEntity.juke == "left" || behaviorTreeEntity.juke == "right" ) )
	{
		return true;
	}

	return false;
}

function zombieShouldStumbleCondition( behaviorTreeEntity )
{
	if ( isDefined( behaviorTreeEntity.stumble ) )
	{
		return true;
	}
	return false;
}

function private zombieJukeActionStart( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, JUKE_DIRECTION, behaviorTreeEntity.juke );
	
	if ( IsDefined( behaviorTreeEntity.jukeDistance ) )
	{
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, JUKE_DISTANCE, behaviorTreeEntity.jukeDistance );
	}
	else
	{
		//default to short although this should never happen
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, JUKE_DISTANCE, "short" ); 
	}

	behaviorTreeEntity.jukeDistance = undefined;
	behaviorTreeEntity.juke = undefined;
}

function private zombieJukeActionTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity ClearPath();
}

function  private zombieStumbleActionStart( behaviorTreeEntity )
{
	behaviorTreeEntity.stumble = undefined;
}

function private zombieAttackObjectStart( behaviorTreeEntity )
{
	behaviorTreeEntity.is_inert = true;
}

function private zombieAttackObjectTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity.is_inert = false;
}

function zombieGibLegsCondition( behaviorTreeEntity)
{
	return GibServerUtils::IsGibbed( behaviorTreeEntity, GIB_LEGS_LEFT_LEG_FLAG) || GibServerUtils::IsGibbed( behaviorTreeEntity, GIB_LEGS_RIGHT_LEG_FLAG);
}

function zombieNotetrackMeleeFire( entity )
{
	if ( IS_TRUE( entity.aat_turned ) )
	{
		if ( IsDefined( entity.enemy ) && !isPlayer( entity.enemy ) )
		{
			if ( entity.enemy.archetype == ARCHETYPE_ZOMBIE && IS_TRUE( entity.enemy.allowDeath ))
			{
				GibServerUtils::GibHead( entity.enemy );
				entity.enemy zombie_utility::gib_random_parts();
				entity.enemy Kill();
				entity.n_aat_turned_zombie_kills++; // Tracked in _zm_aat_turned.gsc
			}
			else if ( ( entity.enemy.archetype == ARCHETYPE_ZOMBIE_QUAD || entity.enemy.archetype == ARCHETYPE_SPIDER ) && IS_TRUE( entity.enemy.allowDeath ))
			{
				entity.enemy Kill();
				entity.n_aat_turned_zombie_kills++; // Tracked in _zm_aat_turned.gsc
			}
			else if( IS_TRUE(entity.enemy.canBeTargetedByTurnedZombies) )
			{
				entity Melee();
			}
		}
	}
	else
	{
		if ( IsDefined(	entity.enemy ) && ( IS_TRUE( entity.enemy.bgb_in_plain_sight_active ) || IS_TRUE( entity.enemy.bgb_idle_eyes_active ) ) )
		{
			return;	
		}

		if ( IsDefined( entity.enemy ) && IS_TRUE( entity.enemy.allow_zombie_to_target_ai ) )
		{
			if ( entity.enemy.health > 0 )
			{
				entity.enemy DoDamage( entity.meleeWeapon.meleeDamage, entity.origin, entity, entity, "none", "MOD_MELEE" );
			}
			return;
		}
		
		entity Melee();
		/#
		Record3DText( "melee", self.origin, RED, "Script", entity );
		#/

		if ( zombieShouldAttackObject( entity ) )
		{
			if ( IsDefined( level.attackableCallback ) )
			{
				entity.attackable [[ level.attackableCallback ]]( entity );
			}
		}
	}
}

function zombieNotetrackCrushFire( behaviorTreeEntity )
{
	behaviorTreeEntity delete();
}

function zombieTargetService( behaviorTreeEntity)
{
	if ( isdefined( behaviorTreeEntity.enablePushTime ) )
	{
		if ( GetTime() >= behaviorTreeEntity.enablePushTime )
		{
			behaviorTreeEntity PushActors( true );
			behaviorTreeEntity.enablePushTime = undefined;
		}
	}

	if( IS_TRUE( behaviorTreeEntity.disableTargetService ) )
	{
		return false;
	}
	
	if ( IS_TRUE( behaviorTreeEntity.ignoreall ) )
	{
		return false;
	}
	
	specificTarget = undefined;
	
	// Check if there is a point of interest
	if( IsDefined( level.zombieLevelSpecificTargetCallback ) )
	{
		specificTarget = [[level.zombieLevelSpecificTargetCallback]]();
	}	

	if( IsDefined( specificTarget ) )
	{
		behaviorTreeEntity SetGoal( specificTarget.origin );
	}
	else if( isdefined( behaviorTreeEntity.v_zombie_custom_goal_pos ) )
	{
		goalPos = behaviorTreeEntity.v_zombie_custom_goal_pos;

		if ( isdefined( behaviorTreeEntity.n_zombie_custom_goal_radius ) )
		{
			behaviorTreeEntity.goalradius = behaviorTreeEntity.n_zombie_custom_goal_radius;
		}
		
		behaviorTreeEntity SetGoal( goalPos );
	}
	else
	{	   
		player = zombie_utility::get_closest_valid_player( self.origin, self.ignore_player );
			
		if( !IsDefined( player ) )
		{
			if( IsDefined( self.ignore_player )  )
			{
				if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
				{
					return false;
				}
				
				self.ignore_player = [];
			}
	
			self SetGoal( self.origin );		
			return false;
		}
		else
		{
			if ( IsDefined( player.last_valid_position ) )
			{
				if( !IS_TRUE( self.zombie_do_not_update_goal ) )
				{
					if( IS_TRUE( level.zombie_use_zigzag_path ) )
					{
						behaviorTreeEntity zombieUpdateZigZagGoal();
					}
					else
					{
						behaviorTreeEntity SetGoal( player.last_valid_position );
					}
				}				
				
				return true;
			}
			else
			{
				if( !IS_TRUE( self.zombie_do_not_update_goal ) )
				{
					behaviorTreeEntity SetGoal( behaviorTreeEntity.origin );
				}
				
				return false;
			}
		}
	}
}

function zombieUpdateZigZagGoal()
{
	AIProfile_BeginEntry( "zombieUpdateZigZagGoal" );
	
	const ZM_ZOMBIE_HEIGHT						= 72;
	const ZM_ZOMBIE_ZIGZAG_GOAL_TOLERENCE_DIST 	= 72;
	const ZM_ZOMBIE_ZIGZAZ_ACTIVATION_DIST		= 250;
	shouldRepath = false;
	
	if ( !shouldRepath && IsDefined( self.favoriteenemy ) )
	{
		if ( !IsDefined( self.nextGoalUpdate ) || self.nextGoalUpdate <= GetTime() )
		{
			// It's been a while, repath!
			shouldRepath = true;
		}
		else if ( DistanceSquared( self.origin, self.favoriteenemy.origin ) <= SQR( ZM_ZOMBIE_ZIGZAZ_ACTIVATION_DIST ) )
		{
			// Repath if close to the enemy.
			shouldRepath = true;
		}
		else if ( IsDefined( self.pathGoalPos ) )
		{
			// Repath if close to the current goal position.
			distanceToGoalSqr = DistanceSquared( self.origin, self.pathGoalPos );
			
			shouldRepath = distanceToGoalSqr < SQR( ZM_ZOMBIE_ZIGZAG_GOAL_TOLERENCE_DIST );
		}
	}

	if ( IS_TRUE( self.keep_moving ) )
	{
		if ( GetTime() > self.keep_moving_time )
		{
			self.keep_moving = false;
		}
	}
	
	if ( shouldRepath )
	{
		goalPos = self.favoriteenemy.origin;
		if ( IsDefined( self.favoriteenemy.last_valid_position ) )
		{
			goalPos = self.favoriteenemy.last_valid_position;
		}
		
		// Fist set the position directly to the current goal position
		self SetGoal( goalPos );
		
		// Randomize zig-zag path following if 20+ feet away from the enemy. This will override the goal position set earlier if needed.
		if ( DistanceSquared( self.origin, goalPos ) > SQR( ZM_ZOMBIE_ZIGZAZ_ACTIVATION_DIST ) )
		{
			self.keep_moving = true;
			self.keep_moving_time = GetTime() + 250;
			path = self CalcApproximatePathToPosition( goalPos,false );
			
			/#
			if ( GetDvarInt( "ai_debugZigZag" ) )
			{
				for ( index = 1; index < path.size; index++ )
				{
					RecordLine( path[index - 1], path[index], ORANGE, "Animscript", self );
				}
			}
			#/
		
			if( IsDefined( level._zombieZigZagDistanceMin ) && IsDefined( level._zombieZigZagDistanceMax ) )
			{
				min = level._zombieZigZagDistanceMin;
				max = level._zombieZigZagDistanceMax;
			}
			else
			{
				min = 240;
				max = 600;
			}
				
			deviationDistance = RandomIntRange( min, max );  // 20 to 50 feet
		
			segmentLength = 0;
		
			// Walks the current path to find the point where the AI should deviate from their normal path.
			for ( index = 1; index < path.size; index++ )
			{
				currentSegLength = Distance( path[index - 1], path[index] );
				
				if ( ( segmentLength + currentSegLength ) > deviationDistance )
				{
					remainingLength = deviationDistance - segmentLength;
				
					seedPosition = path[index - 1] + ( VectorNormalize( path[index] - path[index - 1] ) * remainingLength );
				
					/# RecordCircle( seedPosition, 2, ORANGE, "Animscript", self ); #/
		
					innerZigZagRadius = 0;
					outerZigZagRadius = 96;
					
					// Find a point offset from the deviation point along the path.
					queryResult = PositionQuery_Source_Navigation(
						seedPosition,
						innerZigZagRadius,
						outerZigZagRadius,
						0.5 * ZM_ZOMBIE_HEIGHT,
						16,
						self,
						16 );
					
					PositionQuery_Filter_InClaimedLocation( queryResult, self );
		
					if ( queryResult.data.size > 0 )
					{
						point = queryResult.data[ RandomInt( queryResult.data.size ) ];
						
						// Use the deviated point as the path instead.
						self SetGoal( point.origin );
					}
				
					break;
				}
				
				segmentLength += currentSegLength;
			}
		}

		if( IsDefined( level._zombieZigZagTimeMin ) && IsDefined( level._zombieZigZagTimeMax ) )
		{
			minTime = level._zombieZigZagTimeMin;
			maxTime = level._zombieZigZagTimeMax;
		}
		else
		{
			minTime = 2500;
			maxTime = 3500;
		}
		
		// Force repathing after a certain amount of time to smooth out movement.
		self.nextGoalUpdate = GetTime() + RandomIntRange(minTime, maxTime);
	}
	
	AIProfile_EndEntry();
}

// turn off actor pushing if a regular zombie is too close
function zombieCrawlerCollision( behaviorTreeEntity )
{
	if ( !IS_TRUE( behaviorTreeEntity.missingLegs ) && !IS_TRUE( behaviorTreeEntity.knockdown ) )
	{
		return false;
	}
	
	if ( IsDefined( behaviorTreeEntity.dontPushTime ) )
	{
		if ( GetTime() < behaviorTreeEntity.dontPushTime )
		{
			return true;
		}
	}

	zombies = GetAITeamArray( level.zombie_team );
	foreach( zombie in zombies )
	{
		if ( zombie == behaviorTreeEntity )
		{
			continue;
		}

		if ( IS_TRUE( zombie.missingLegs ) || IS_TRUE( zombie.knockdown ) )
		{
			continue;
		}

		dist_sq = DistanceSquared( behaviorTreeEntity.origin, zombie.origin );
		if ( dist_sq < ZM_CRAWLER_PUSH_DIST_SQ )
		{
			behaviorTreeEntity PushActors( false );
			behaviorTreeEntity.dontPushTime = GetTime() + ZM_CRAWLER_PUSH_DISABLE_TIME;
			return true;
		}
	}

	behaviorTreeEntity PushActors( true );
	return false;
}

function zombieTraversalService( entity )
{
	if ( isdefined( entity.traverseStartNode ) )
	{
		entity PushActors( false );
		return true;
	}

	return false;
}	

function zombieIsAtAttackObject( entity )
{
	if ( IS_TRUE( entity.missingLegs ) )
	{
		return false;
	}

	if ( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) )
	{
		return false;
	}

	if ( IsDefined( entity.favoriteenemy ) && IS_TRUE( entity.favoriteenemy.b_is_designated_target ) )
	{
		return false;
	}

	if ( IS_TRUE( entity.aat_turned ) )
	{
		return false;
	}

	if ( IsDefined( entity.attackable ) && IS_TRUE( entity.attackable.is_active ) )
	{
		if ( !IsDefined( entity.attackable_slot ) )
		{
			return false;
		}

		//if ( entity IsAtGoal() )
		//{
		//	entity.is_at_attackable = true;
		//	return true;
		//}

		dist = Distance2DSquared( entity.origin, entity.attackable_slot.origin );
		if ( dist < 256 ) 
		{
			height_offset = Abs( entity.origin[2] - entity.attackable_slot.origin[2] );
			if ( height_offset < 32 )
			{
				entity.is_at_attackable = true;
				return true;
			}
		}

		//yawToObject = AngleClamp180( entity.angles[ 1 ] - entity.attackable_slot.angles[ 1 ] );
		//if( abs( yawToObject ) > ZM_MELEE_YAW )
		//{
		//	return false;
		//}

	}

	return false;
}

function zombieShouldAttackObject( entity )
{
	if ( IS_TRUE( entity.missingLegs ) )
	{
		return false;
	}

	if ( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) )
	{
		return false;
	}

	if ( IsDefined( entity.favoriteenemy ) && IS_TRUE( entity.favoriteenemy.b_is_designated_target ) )
	{
		return false;
	}

	if ( IS_TRUE( entity.aat_turned ) )
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

function zombieShouldMeleeCondition( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.enemyoverride ) && IsDefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		return false;
	}
	
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}

	if( IS_TRUE( behaviorTreeEntity.ignoreMelee ) )
	{
		return false;
	}
	
	if( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) > ZM_MELEE_DIST_SQ )
	{
		return false;
	}
	
	yawToEnemy = AngleClamp180( behaviorTreeEntity.angles[ 1 ] - GET_YAW( behaviorTreeEntity, behaviorTreeEntity.enemy.origin ) );
	if( abs( yawToEnemy ) > ZM_MELEE_YAW )
	{
		return false;
	}
	
	return true;
}

#define ZM_MELEE_JUMP_DISTANCE_ABOVE 60
#define ZM_MELEE_JUMP_DIST 180
#define ZM_MELEE_JUMP_CHANCE 0.5
function zombieShouldJumpMeleeCondition( behaviorTreeEntity )
{
	if ( !IS_TRUE( behaviorTreeEntity.low_gravity ) )
	{
		return false;
	}
	
	if( IsDefined( behaviorTreeEntity.enemyoverride ) && IsDefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		return false;
	}
	
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}

	if( IS_TRUE( behaviorTreeEntity.ignoreMelee ) )
	{
		return false;
	}
	
	if ( behaviorTreeEntity.enemy IsOnGround() )
	{
		return false;
	}
	
	jumpChance = GetDvarFloat( "zmMeleeJumpChance", ZM_MELEE_JUMP_CHANCE );
	if ( ( ( behaviorTreeEntity GetEntityNumber() % 10 ) / 10 ) > jumpChance )
	{
		return false;
	}
	
	predictedPosition = behaviorTreeEntity.enemy.origin + behaviorTreeEntity.enemy GetVelocity() * SERVER_FRAME * 2;
	
	jumpDistanceSq = pow( GetDvarInt( "zmMeleeJumpDistance", ZM_MELEE_JUMP_DIST ), 2 );
	
	if( Distance2DSquared( behaviorTreeEntity.origin, predictedPosition ) > jumpDistanceSq )
	{
		return false;
	}
	
	yawToEnemy = AngleClamp180( behaviorTreeEntity.angles[ 1 ] - GET_YAW( behaviorTreeEntity, behaviorTreeEntity.enemy.origin ) );
	if( abs( yawToEnemy ) > ZM_MELEE_YAW )
	{
		return false;
	}

	heightToEnemy = behaviorTreeEntity.enemy.origin[2] - behaviorTreeEntity.origin[2];
	if ( heightToEnemy <= GetDvarInt( "zmMeleeJumpHeightDifference", ZM_MELEE_JUMP_DISTANCE_ABOVE ) )
	{
		return false;
	}
	
	return true;
}

#define ZM_MELEE_JUMP_DISTANCE_ABOVE_WATER 48
#define ZM_MIN_IN_WATER_DEPTH 48
#define ZM_MELEE_WATER_JUMP_DIST 64
function zombieShouldJumpUnderwaterMelee( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.enemyoverride ) && IsDefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		return false;
	}
	
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}

	if( IS_TRUE( behaviorTreeEntity.ignoreMelee ) )
	{
		return false;
	}
	
	if ( behaviorTreeEntity.enemy IsOnGround() )
	{
		return false;
	}
	
	if ( behaviorTreeEntity DepthInWater() < ZM_MIN_IN_WATER_DEPTH )
	{
		return false;
	}
	
	jumpDistanceSq = pow( GetDvarInt( "zmMeleeWaterJumpDistance", ZM_MELEE_WATER_JUMP_DIST ), 2 );
	
	if( Distance2DSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) > jumpDistanceSq )
	{
		return false;
	}
	
	yawToEnemy = AngleClamp180( behaviorTreeEntity.angles[ 1 ] - GET_YAW( behaviorTreeEntity, behaviorTreeEntity.enemy.origin ) );
	if( abs( yawToEnemy ) > ZM_MELEE_YAW )
	{
		return false;
	}
	
	heightToEnemy = behaviorTreeEntity.enemy.origin[2] - behaviorTreeEntity.origin[2];
	if ( heightToEnemy <= GetDvarInt( "zmMeleeJumpUnderwaterHeightDifference", ZM_MELEE_JUMP_DISTANCE_ABOVE_WATER ) )
	{
		return false;
	}
	
	return true;
}

function zombieStumble( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.missingLegs ) )
	{
		return false;
	}
	if ( !IS_TRUE( behaviorTreeEntity.canStumble ) )
	{
		return false;
	}
	if ( !IsDefined( behaviorTreeEntity.zombie_move_speed ) || behaviorTreeEntity.zombie_move_speed != "sprint" )
	{
		return false;
	}
	if ( IsDefined( behaviorTreeEntity.stumble ) )
	{
		return false;
	}
	if (!IsDefined( behaviorTreeEntity.next_stumble_time ) )
	{
		behaviorTreeEntity.next_stumble_time = GetTime() + RandomIntRange( ZM_STUMBLE_TIME_MIN, ZM_STUMBLE_TIME_MAX );
	}
	if ( GetTime() > behaviorTreeEntity.next_stumble_time ) 
	{
		if ( RandomInt( 100 ) < ZM_STUMBLE_CHANCE )
		{
			closestPlayer = ArrayGetClosest( behaviorTreeEntity.origin, level.players );
			if( DistanceSquared( closestPlayer.origin, behaviorTreeEntity.origin ) > ZM_STUMBLE_MIN_DISTANCE_SQ )
			{
				if ( IsDefined( behaviorTreeEntity.next_juke_time ) )
				{
					behaviorTreeEntity.next_juke_time = undefined;
				}
				
				behaviorTreeEntity.next_stumble_time = undefined;
				behaviorTreeEntity.stumble = true;
				return true;
			}
		}
	}
	return false;
}

function zombieJuke( behaviorTreeEntity )
{
	if ( !behaviorTreeEntity ai::has_behavior_attribute( "can_juke" ) )
	{
		return false;
	}
	
	if( !behaviorTreeEntity ai::get_behavior_attribute( "can_juke" ) )
	{
		return false;
	}
	
	if ( IS_TRUE( behaviorTreeEntity.missingLegs ) )
	{
		return false;
	}

	if ( behaviorTreeEntity ZombieBehavior::bb_getlocomotionspeedtype() != LOCOMOTION_SPEED_WALK )
	{
		if ( behaviorTreeEntity ai::has_behavior_attribute( "spark_behavior" ) && !behaviorTreeEntity ai::get_behavior_attribute( "spark_behavior" ) )
		{
			return false;
		}
	}

	if ( IsDefined( behaviorTreeEntity.juke ) )
	{
		return false;
	}

	if ( !IsDefined( behaviorTreeEntity.next_juke_time ) )
	{
		behaviorTreeEntity.next_juke_time = GetTime() + RandomIntRange( ZM_JUKE_TIME_MIN, ZM_JUKE_TIME_MAX );
	}

	if ( GetTime() > behaviorTreeEntity.next_juke_time )
	{
		behaviorTreeEntity.next_juke_time = undefined;
		
		if ( RandomInt( 100 ) < ZM_JUKE_CHANCE || ( behaviorTreeEntity ai::has_behavior_attribute( "spark_behavior" ) && behaviorTreeEntity ai::get_behavior_attribute( "spark_behavior" ) ) )
		{			
			
			if ( IsDefined( behaviorTreeEntity.next_stumble_time ) )
			{
				behaviorTreeEntity.next_stumble_time = undefined;
			}
			
			forwardOffset = 15;
			behaviorTreeEntity.ignoreBackwardPosition = true; //TODO remove this temp var
			
			if( math::cointoss() ) //decide if going to be short or long juke
			{
				//try long juke
				jukeDistance = 101;
				behaviorTreeEntity.jukeDistance = "long";
							
				switch( behaviorTreeEntity ZombieBehavior::bb_getlocomotionspeedtype() )
				{
					case LOCOMOTION_SPEED_WALK:
					case LOCOMOTION_SPEED_RUN:
						forwardOffset = 122;
						break;
					case LOCOMOTION_SPEED_SPRINT:
						forwardOffset = 129;
						break;
				}
				
				behaviorTreeEntity.juke = AiUtility::calculateJukeDirection( behaviorTreeEntity, forwardOffset, jukeDistance );
				//juke == forward -> can't juke left or right
			}
			
			if ( !IsDefined( behaviorTreeEntity.juke ) || behaviorTreeEntity.juke == "forward" ) // could not long juke
			{
				//long juke didn't work out, so try short juke
				jukeDistance = 69;
				behaviorTreeEntity.jukeDistance = "short";
				
				switch( behaviorTreeEntity ZombieBehavior::bb_getlocomotionspeedtype() )
				{
					case LOCOMOTION_SPEED_WALK:
					case LOCOMOTION_SPEED_RUN:
						forwardOffset = 127;
						break;
					case LOCOMOTION_SPEED_SPRINT:
						forwardOffset = 148;
						break;
				}
				
				behaviorTreeEntity.juke = AiUtility::calculateJukeDirection( behaviorTreeEntity, forwardOffset, jukeDistance );
				if( behaviorTreeEntity.juke == "forward" )
				{
					//both juke checks failed, so don't juke at all
					behaviorTreeEntity.juke = undefined;
					behaviorTreeEntity.jukeDistance = undefined;
					return false;
				}
			}
			
		}
		

	}
}

function zombieDeathAction( behaviorTreeEntity )
{
	//insert anything that needs to be done right before zombie death
}

function wasKilledByInterdimensionalGunCondition( behaviorTreeEntity )
{
	if( isdefined( behaviorTreeEntity.interdimensional_gun_kill ) &&
		!isdefined( behaviorTreeEntity.killby_interdimensional_gun_hole ) &&
		IsAlive( behaviorTreeEntity ) )
	{
		return true;
	}

	return false;
}

function wasCrushedByInterdimensionalGunBlackholeCondition( behaviorTreeEntity )
{
	if(isdefined(behaviorTreeEntity.killby_interdimensional_gun_hole))
	{
		return true;
	}

	return false;
}

function zombieIDGunDeathMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode(AI_ANIM_USE_BOTH_DELTAS_NOCLIP);
	entity.pushable = false;
	entity.blockingPain = true;
	entity PathMode( "dont move" );
	
	entity.hole_pull_speed = 0;
}

function zombieMeleeJumpMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face enemy" );
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity.pushable = false;
	entity.blockingPain = true;
	entity.clampToNavMesh = false;
	entity PushActors( false );
	
	entity.jumpStartPosition = entity.origin;
}

function zombieMeleeJumpMocompUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	normalizedTime = ( ( entity GetAnimTime( mocompAnim ) * GetAnimLength( mocompAnim ) ) + mocompAnimBlendOutTime ) / mocompDuration;
	
	if (normalizedTime > 0.5)
	{
		entity OrientMode( "face angle", entity.angles[1] );
	}
	
	speed = 5;
	
	if ( IsDefined( entity.zombie_move_speed ) )
	{
		switch ( entity.zombie_move_speed )
		{
			case "walk":
				speed = 5;
				break;
			case "run":
				speed = 6;
				break;
			case "sprint":
				speed = 7;
				break;
		}
	}
	
	newPosition = entity.origin + AnglesToForward( entity.angles ) * speed;
	
	// Test that the new position only moves the zombie across valid navmesh.
	newTestPosition = ( newPosition[0], newPosition[1], entity.jumpStartPosition[2] );
	newValidPosition = GetClosestPointOnNavMesh( newTestPosition, 12, 20 );
	
	if ( IsDefined( newValidPosition ) )
	{
		// New position appears to be valid.
		newValidPosition = ( newValidPosition[0], newValidPosition[1], entity.origin[2] );
	}
	else
	{
		// New position is not above navmesh, prevent all lateral movement.
		newValidPosition = entity.origin;
	}
	
	// Prevent zombie from penetrating the ground.
	groundPoint = GetClosestPointOnNavMesh( newValidPosition, 12, 20 );
	if ( IsDefined( groundPoint ) && groundPoint[2] > newValidPosition[2] )
	{
		newValidPosition = ( newValidPosition[0], newValidPosition[1], groundPoint[2] );
	}
	
	entity ForceTeleport( newValidPosition );
}

function zombieMeleeJumpMocompTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.pushable = true;
	entity.blockingPain = false;
	entity.clampToNavMesh = true;
	entity PushActors( true );
	
	groundPoint = GetClosestPointOnNavMesh( entity.origin, 12 );
	if ( IsDefined( groundPoint ) )
	{
		entity ForceTeleport( groundPoint );
	}
}

// Offset also defined in _zm_weap_idgun.gsc
#define VORTEX_Z_OFFSET		36

function zombieIDGunDeathUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if(!isdefined(entity.killby_interdimensional_gun_hole))
	{
		entity_eye = entity GetEye();

		// if world is paused unpause entity to be pulled into vortex
		if( entity IsPaused() )
		{
			entity SetIgnorePauseWorld( true );
			entity SetEntityPaused( false );
		}
			
		if ( entity.b_vortex_repositioned !== true )
		{
			entity.b_vortex_repositioned = true;
			v_nearest_navmesh_point = GetClosestPointOnNavMesh( entity.damageOrigin, VORTEX_Z_OFFSET, 15 );
			if ( isdefined(v_nearest_navmesh_point) )
			{
				f_distance = Distance( entity.damageOrigin, v_nearest_navmesh_point);
				
				// Added 5 units to offset to capture a larger set of points
				if ( f_distance < VORTEX_Z_OFFSET + 5 )
			    {
					entity.damageOrigin = entity.damageOrigin + ( 0, 0, VORTEX_Z_OFFSET);
				}
			}
		}
		
		entity_center = entity.origin + ( ( entity_eye - entity.origin ) / 2 );
		flyingDir = entity.damageOrigin - entity_center;
		lengthFromHole = Length(flyingDir);
	
		if(lengthFromHole < entity.hole_pull_speed)
		{
			entity.killby_interdimensional_gun_hole = true;
			entity.allowdeath = true;
			entity.takedamage = true;
			entity.aiOverrideDamage = undefined;
			entity.magic_bullet_shield = false;
			level notify("interdimensional_kill",entity);
			if( IsDefined( entity.interdimensional_gun_weapon ) && IsDefined( entity.interdimensional_gun_attacker ) )
			{
				entity kill(entity.origin, entity.interdimensional_gun_attacker, entity.interdimensional_gun_attacker, entity.interdimensional_gun_weapon);
			}
			else
			{
				entity kill( entity.origin );
			}
		}
		else
		{
			if(entity.hole_pull_speed < ZM_IDGUN_HOLE_PULL_MAX_SPEED)
			{
				entity.hole_pull_speed += ZM_IDGUN_HOLE_PULL_ACC;
				
				if(entity.hole_pull_speed > ZM_IDGUN_HOLE_PULL_MAX_SPEED)
					entity.hole_pull_speed = ZM_IDGUN_HOLE_PULL_MAX_SPEED;
			}
			
			flyingDir = VectorNormalize(flyingDir);
			entity ForceTeleport(entity.origin + flyingDir * entity.hole_pull_speed);
		}
	}	
}

function zombieIDGunHoleDeathMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode(AI_ANIM_USE_BOTH_DELTAS_NOCLIP);
	entity.pushable = false;
}

function zombieIDGunHoleDeathMocompTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( !IS_TRUE( entity.interdimensional_gun_kill_vortex_explosion ) )
	{
		entity hide();
	}
}

function private zombieTurnMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode( AI_ANIM_USE_ANGLE_DELTAS, false );
}

function private zombieTurnMocompUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	normalizedTime = ( entity GetAnimTime( mocompAnim ) + mocompAnimBlendOutTime ) / mocompDuration;

	if ( normalizedTime > 0.25 )
	{
		entity OrientMode( "face motion" );
		entity AnimMode( AI_ANIM_MOVE_CODE, false );
	}
}

function private zombieTurnMocompTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face motion" );
	entity AnimMode( AI_ANIM_MOVE_CODE, false );
}

function zombieHasLegs( behaviorTreeEntity )
{
	if( behaviorTreeEntity.missingLegs === true )
	{
		return false;
	}
	
	return true;
}

function zombieShouldProceduralTraverse( entity )
{
	return IsDefined( entity.traverseStartNode ) &&
		IsDefined( entity.traverseEndNode ) &&
		entity.traverseStartNode.spawnflags & SPAWNFLAG_PATH_PROCEDURAL &&
		entity.traverseEndNode.spawnflags & SPAWNFLAG_PATH_PROCEDURAL;
}

function zombieShouldMeleeSuicide( behaviorTreeEntity )
{
	if( !behaviorTreeEntity ai::get_behavior_attribute( "suicidal_behavior" ) )
	{
		return false;
	}
	
	if( IS_TRUE( behaviorTreeEntity.magic_bullet_shield ) )
	{
		return false;
	}
	
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}
	
	if( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) > ZOMBIE_SUICIDE_RANGE_SQ )
	{
		return false;
	}
	
	return true;
}

function zombieMeleeSuicideStart( behaviorTreeEntity )
{
	behaviorTreeEntity.blockingPain = true;
		
	if( IsDefined( level.zombieMeleeSuicideCallback ) )
	{
		behaviorTreeEntity thread [[level.zombieMeleeSuicideCallback]](behaviorTreeEntity);
	}
}

function zombieMeleeSuicideUpdate( behaviorTreeEntity )
{

}
	
function zombieMeleeSuicideTerminate( behaviorTreeEntity )
{					
	if( IsAlive( behaviorTreeEntity ) && zombieShouldMeleeSuicide( behaviorTreeEntity ) )
	{
		behaviorTreeEntity.takedamage = true;
		behaviorTreeEntity.allowDeath = true;
		
		// SUMEET : I dont like how this is being done but have to do this, as killing an entity in
		// Terminate functon can lead to an interrupt that might get dropped by the behavior tree update
		if( IsDefined( level.zombieMeleeSuicideDoneCallback ) )
		{
			behaviorTreeEntity thread [[level.zombieMeleeSuicideDoneCallback]](behaviorTreeEntity);			
		}		
	}		
}

// ------- ZOMBIE LOCOMOTION -----------//
function zombieMoveAction( behaviorTreeEntity, asmStateName )
{	
	behaviorTreeEntity.moveTime = GetTime();
	behaviorTreeEntity.moveOrigin = behaviorTreeEntity.origin;

	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	//Stumble at the end of the current move animation
	if( IsDefined( behaviorTreeEntity.stumble ) && !IsDefined( behaviorTreeEntity.move_anim_end_time ) )
	{
		stumbleActionResult = behaviorTreeEntity ASTSearch(  IString( asmStateName ) );
		stumbleActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( behaviorTreeEntity, stumbleActionResult[ ASM_ALIAS_ATTRIBUTE ] );
		
		behaviorTreeEntity.move_anim_end_time = behaviorTreeEntity.moveTime + GetAnimLength( stumbleActionAnimation );
	}
	
	if( IsDefined( behaviorTreeEntity.zombieMoveActionCallback ) )
	{
		behaviorTreeEntity [[behaviorTreeEntity.zombieMoveActionCallback]]( behaviorTreeEntity );
	}
		
	return BHTN_RUNNING;
}

// Looping Action will always return BHTN_RUNNING and request the state again when the ASM_STATE_COMPLETE
function zombieMoveActionUpdate( behaviorTreeEntity, asmStateName )
{		
	if ( IsDefined( behaviorTreeEntity.move_anim_end_time ) && ( GetTime() >= behaviorTreeEntity.move_anim_end_time ) )
	{
		behaviorTreeEntity.move_anim_end_time = undefined;
		return BHTN_SUCCESS;
	}
	
	if ( !IS_TRUE( behaviorTreeEntity.missingLegs ) && ( GetTime() - behaviorTreeEntity.moveTime > ZM_MOVE_TIME ) )
	{
		distSq = Distance2DSquared( behaviorTreeEntity.origin, behaviorTreeEntity.moveOrigin );
		if ( distSq < ZM_MOVE_DIST_SQ )
		{
			behaviorTreeEntity SetAvoidanceMask( "avoid all" );
			behaviorTreeEntity.cant_move = true;

			if ( IsDefined( behaviorTreeEntity.cant_move_cb ) )
			{
				behaviorTreeEntity [[ behaviorTreeEntity.cant_move_cb ]]();
			}
		}
		else
		{
			behaviorTreeEntity SetAvoidanceMask( "avoid none" );
			behaviorTreeEntity.cant_move = false;
		}

		behaviorTreeEntity.moveTime = GetTime();
		behaviorTreeEntity.moveOrigin = behaviorTreeEntity.origin;
	}
	
	if( behaviorTreeEntity ASMGetStatus() == ASM_STATE_COMPLETE )
	{
		if( behaviorTreeEntity IsCurrentBTActionLooping() )
			zombieMoveAction( behaviorTreeEntity, asmStateName );
		else 
			return BHTN_SUCCESS;
	}
	
	return BHTN_RUNNING;
}

function zombieMoveActionTerminate( behaviorTreeEntity, asmStateName )
{
	if ( !IS_TRUE( behaviorTreeEntity.missingLegs ) )
	{
		behaviorTreeEntity SetAvoidanceMask( "avoid none" );
	}

	return BHTN_SUCCESS;	
}

// ------- ZOMBIE DEATH GIB OVERRIDE -----------//
function ArchetypeZombieDeathOverrideInit() // Self = AI
{
	AiUtility::AddAIOverrideKilledCallback( self, &ZombieGibKilledAnhilateOverride );
}

#define CLOSE_EXPLOSIVE SQR(60)
function private ZombieGibKilledAnhilateOverride( inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTime ) // self = AI
{	
	// Level must opt-in to anhilation	
	if( !IS_TRUE( level.zombieAnhilationEnabled ) )
		return damage;
	
	if( IS_TRUE( self.forceAnhilateOnDeath ) )
	{
		self zombie_utility::gib_random_parts();		
		GibServerUtils::Annihilate( self );
		return damage;
	}
	
	// Forced anhilation for players
	if( IsDefined( attacker ) && IsPlayer( attacker ) && ( IS_TRUE( attacker.forceAnhilateOnDeath ) || IS_TRUE( level.forceAnhilateOnDeath ) ) )
	{
		self zombie_utility::gib_random_parts();
		GibServerUtils::Annihilate( self );
		return damage;
	}
	 
	// Generic anhilation
	attackerDistance = 0;
	
	if ( IsDefined( attacker ) )
	{
		attackerDistance = DistanceSquared( attacker.origin, self.origin );
	}
	
	isExplosive = IsInArray(
		array(
			"MOD_CRUSH",
			"MOD_GRENADE",
			"MOD_GRENADE_SPLASH",
			"MOD_PROJECTILE",
			"MOD_PROJECTILE_SPLASH",
			"MOD_EXPLOSIVE" ),
		meansOfDeath );
	
	if ( IsDefined( weapon.weapclass ) && weapon.weapclass == "turret" )
	{
		// Annihilate AI's from turrent explosives that are inflicted at a close distance.
		if ( IsDefined( inflictor ) )
		{
			isDirectExplosive = IsInArray(
				array(
					"MOD_GRENADE",
					"MOD_GRENADE_SPLASH",
					"MOD_PROJECTILE",
					"MOD_PROJECTILE_SPLASH",
					"MOD_EXPLOSIVE" ),
				meansOfDeath );
			
			isCloseExplosive = DistanceSquared( inflictor.origin, self.origin ) <= CLOSE_EXPLOSIVE;
			
			if ( isDirectExplosive && isCloseExplosive )
			{
				self zombie_utility::gib_random_parts();
				GibServerUtils::Annihilate( self );
			}
		}
	}	

	return damage;
}


function private zombieZombieIdleMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) && entity != entity.enemyoverride[1] )
	{
		entity OrientMode( "face direction", entity.enemyoverride[1].origin - entity.origin );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
	else
	{
		entity OrientMode( "face current" );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
}

function private zombieAttackObjectMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( IsDefined( entity.attackable_slot ) )
	{
		entity OrientMode( "face angle", entity.attackable_slot.angles[1] );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
	else
	{
		entity OrientMode( "face current" );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
}

function private zombieAttackObjectMocompUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( IsDefined( entity.attackable_slot ) )
	{
		entity ForceTeleport( entity.attackable_slot.origin );
	}
}


