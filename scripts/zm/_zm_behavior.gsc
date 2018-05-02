#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\zombie;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_attackables;
#using scripts\zm\_zm_behavior_utility;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\zombie.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#insert scripts\zm\_zm_behavior.gsh;


#namespace zm_behavior;

#define BHB_BURST "bhb_burst"

function autoexec init()
{
	// INIT BEHAVIORS
	InitZmBehaviorsAndASM();

	// minimum distance from the enemy for deviation to occur
	level.zigzag_activation_distance = ZIGZAG_ACTIVATION_DISTANCE;
	
	// how far along the path the deviation will occur
	level.zigzag_distance_min = ZIGZAG_DISTANCE_MIN;
	level.zigzag_distance_max = ZIGZAG_DISTANCE_MAX;
	
	// how far zombie can deviate from the path
	level.inner_zigzag_radius = INNER_ZIGZAG_RADIUS;
	level.outer_zigzag_radius = OUTER_ZIGZAG_RADIUS;
}

function private InitZmBehaviorsAndASM()
{
	BT_REGISTER_API( "zombieFindFleshService", 	&zombieFindFlesh);
	BT_REGISTER_API( "zombieEnteredPlayableService", 	&zombieEnteredPlayable);

	// functionName, functionPtr, functionParamCount // functionParam names (For documentation purposes)

	// ------- BEHAVIOR CONDITIONS -----------//
	BT_REGISTER_API( "zombieShouldMove", &shouldMoveCondition );
	BT_REGISTER_API( "zombieShouldTear", &zombieShouldTearCondition );
	BT_REGISTER_API( "zombieShouldAttackThroughBoards", &zombieShouldAttackThroughBoardsCondition );
	BT_REGISTER_API( "zombieShouldTaunt", &zombieShouldTauntCondition );
	BT_REGISTER_API( "zombieGotToEntrance", &zombieGotToEntranceCondition );
	BT_REGISTER_API( "zombieGotToAttackSpot", &zombieGotToAttackSpotCondition );
	BT_REGISTER_API( "zombieHasAttackSpotAlready", &zombieHasAttackSpotAlreadyCondition );
	BT_REGISTER_API( "zombieShouldEnterPlayable", &zombieShouldEnterPlayableCondition );
	BT_REGISTER_API( "isChunkValid", &isChunkValidCondition );
	
	BT_REGISTER_API( "inPlayableArea", &inPlayableArea );
	BT_REGISTER_API( "shouldSkipTeardown", &shouldSkipTeardown );
	BT_REGISTER_API( "zombieIsThinkDone", &zombieIsThinkDone );
	BT_REGISTER_API( "zombieIsAtGoal", &zombieIsAtGoal );
	BT_REGISTER_API( "zombieIsAtEntrance", &zombieIsAtEntrance );
	BT_REGISTER_API( "zombieShouldMoveAway", &zombieShouldMoveAwayCondition);
	BT_REGISTER_API( "wasKilledByTesla", &wasKilledByTeslaCondition);
	BT_REGISTER_API( "zombieShouldStun", &zombieShouldStun );
	BT_REGISTER_API( "zombieIsBeingGrappled", &zombieIsBeingGrappled );
	BT_REGISTER_API( "zombieShouldKnockdown", &zombieShouldKnockdown );
	BT_REGISTER_API( "zombieIsPushed", &zombieIsPushed );
	BT_REGISTER_API( "zombieKilledWhileGettingPulled", &zombieKilledWhileGettingPulled );
	BT_REGISTER_API( "zombieKilledByBlackHoleBombCondition", &zombieKilledByBlackHoleBombCondition );
	
	// ------- BEHAVIOR UTILITY -----------//
	BT_REGISTER_API( "disablePowerups", &disablePowerups);
	BT_REGISTER_API( "enablePowerups", &enablePowerups);

	// ------- ZOMBIE LOCOMOTION -----------//
	BT_REGISTER_ACTION( "zombieMoveToEntranceAction", &zombieMoveToEntranceAction, undefined, &zombieMoveToEntranceActionTerminate );
	BT_REGISTER_ACTION( "zombieMoveToAttackSpotAction", &zombieMoveToAttackSpotAction, undefined, &zombieMoveToAttackSpotActionTerminate );
	BT_REGISTER_ACTION( "zombieIdleAction", undefined, undefined, undefined );
	BT_REGISTER_ACTION( "zombieMoveAway", &zombieMoveAway, undefined, undefined );
	BT_REGISTER_ACTION( "zombieTraverseAction", &zombieTraverseAction, undefined, &zombieTraverseActionTerminate );
	
	// ------- ZOMBIE TEAR DOWN -----------//
	BT_REGISTER_ACTION( "holdBoardAction", &zombieHoldBoardAction, undefined, &zombieHoldBoardActionTerminate );
	BT_REGISTER_ACTION( "grabBoardAction", &zombieGrabBoardAction, undefined, &zombieGrabBoardActionTerminate );
	BT_REGISTER_ACTION( "pullBoardAction", &zombiePullBoardAction, undefined, &zombiePullBoardActionTerminate );
	// ------- ZOMBIE MELEE BEHIND BOARDS -----------//
	BT_REGISTER_ACTION( "zombieAttackThroughBoardsAction", &zombieAttackThroughBoardsAction, undefined, &zombieAttackThroughBoardsActionTerminate );
	// ------- ZOMBIE TAUNT -----------//
	BT_REGISTER_ACTION( "zombieTauntAction", &zombieTauntAction, undefined, &zombieTauntActionTerminate );
	// ------- ZOMBIE BOARD MANTLE -----------//
	BT_REGISTER_ACTION( "zombieMantleAction", &zombieMantleAction, undefined, &zombieMantleActionTerminate );
	// ------- ZOMBIE ELECTRIC STUN -----------//
	BT_REGISTER_API( "zombieStunActionStart", &zombieStunActionStart );
	BT_REGISTER_API( "zombieStunActionEnd", &zombieStunActionEnd );

	// ------- ZOMBIE GRAPPLE -----------//
	BT_REGISTER_API( "zombieGrappleActionStart", &zombieGrappleActionStart );
	
	// ------- ZOMBIE KNOCKDOWN -----------//
	BT_REGISTER_API( "zombieKnockdownActionStart", &zombieKnockdownActionStart );
	BT_REGISTER_API( "zombieGetupActionTerminate", &zombieGetupActionTerminate);

	// ------- ZOMBIE PUSHED -----------//
	BT_REGISTER_API( "zombiePushedActionStart", &zombiePushedActionStart);
	BT_REGISTER_API( "zombiePushedActionTerminate", &zombiePushedActionTerminate);
	
	// ------- ZOMBIE BLACK HOLE BOMB -----------//
	BT_REGISTER_ACTION( "zombieBlackHoleBombPullAction", &zombieBlackHoleBombPullStart, &zombieBlackHoleBombPullUpdate, &zombieBlackHoleBombPullEnd );
	BT_REGISTER_ACTION( "zombieBlackHoleBombDeathAction", &zombieKilledByBlackHoleBombStart, undefined, &zombieKilledByBlackHoleBombEnd );

	// ------- ZOMBIE SERVICES -----------//
	BT_REGISTER_API( "getChunkService", &getChunkService );
	BT_REGISTER_API( "updateChunkService", &updateChunkService );
	BT_REGISTER_API( "updateAttackSpotService", &updateAttackSpotService );
	BT_REGISTER_API( "findNodesService", &findNodesService );

	BT_REGISTER_API( "zombieAttackableObjectService",	&zombieAttackableObjectService );

	// ------- ZOMBIE MOCOMP -----------//
	ASM_REGISTER_MOCOMP( "mocomp_board_tear@zombie",	&boardTearMocompStart, &boardTearMocompUpdate, undefined );
	ASM_REGISTER_MOCOMP( "mocomp_barricade_enter@zombie", &barricadeEnterMocompStart, &barricadeEnterMocompUpdate, &barricadeEnterMocompTerminate );
	ASM_REGISTER_MOCOMP( "mocomp_barricade_enter_no_z@zombie", &barricadeEnterMocompNoZStart, &barricadeEnterMocompNoZUpdate, &barricadeEnterMocompNoZTerminate );

	// ------- ZOMBIE NOTETRACKS -----------//
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_ZOMBIES_BOARD_TEAR, &notetrackBoardTear );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_ZOMBIES_BOARD_MELEE, &notetrackBoardMelee );
	ASM_REGISTER_NOTETRACK_HANDLER( BHB_BURST, &zombieBHBBurst );
	
	SetDvar( "scr_zm_use_code_enemy_selection", 1 );
}

// ------- BEHAVIOR CONDITIONS -----------//
function zombieFindFlesh( behaviorTreeEntity )
{
	if ( isdefined( behaviorTreeEntity.enablePushTime ) )
	{
		if ( GetTime() >= behaviorTreeEntity.enablePushTime )
		{
			behaviorTreeEntity PushActors( true );
			behaviorTreeEntity.enablePushTime = undefined;
		}
	}

	if( GetDvarInt( "scr_zm_use_code_enemy_selection", 0 ) )
	{
		zombieFindFleshCode( behaviorTreeEntity );
		return;
	}
	
	if( level.intermission )
	{
		return;
	}

	if ( behaviorTreeEntity GetPathMode() == "dont move" )
	{
		return;
	}

	behaviorTreeEntity.ignoreme = false; // don't let attack dogs give chase until the zombie is in the playable area

	behaviorTreeEntity.ignore_player = [];

	behaviorTreeEntity.goalradius = ZM_FIND_FLESH_RADIUS;

	if ( IS_TRUE( behaviorTreeEntity.ignore_find_flesh ) )
	{
		return;
	}

	if ( behaviorTreeEntity.team == "allies" )
	{
		behaviorTreeEntity findZombieEnemy();
		return;
	}

	if ( zm_behavior::zombieShouldMoveAwayCondition( behaviorTreeEntity ) )
	{
		return;
	}

	zombie_poi = behaviorTreeEntity zm_utility::get_zombie_point_of_interest( behaviorTreeEntity.origin );
	behaviorTreeEntity.zombie_poi = zombie_poi;
	
	players = GetPlayers();
	
	// If playing single player, never ignore the player
	if( !isdefined(behaviorTreeEntity.ignore_player) || (players.size == 1) )
	{
		behaviorTreeEntity.ignore_player = [];
	}
	else if(!isDefined(level._should_skip_ignore_player_logic) || ![[level._should_skip_ignore_player_logic]]() )
	{
		i=0;
		while (i < behaviorTreeEntity.ignore_player.size)
		{
			if( IsDefined( behaviorTreeEntity.ignore_player[i] ) && IsDefined( behaviorTreeEntity.ignore_player[i].ignore_counter ) && behaviorTreeEntity.ignore_player[i].ignore_counter > 3 )
			{
				behaviorTreeEntity.ignore_player[i].ignore_counter = 0;
				behaviorTreeEntity.ignore_player = ArrayRemoveValue( behaviorTreeEntity.ignore_player, behaviorTreeEntity.ignore_player[i] );
				if (!IsDefined(behaviorTreeEntity.ignore_player))
					behaviorTreeEntity.ignore_player = [];
				i=0;
				continue;
			}
			i++;
		}
	}

	behaviorTreeEntity zombie_utility::run_ignore_player_handler();

	player = zm_utility::get_closest_valid_player( behaviorTreeEntity.origin, behaviorTreeEntity.ignore_player );

	designated_target = false;
	if ( IsDefined( player ) && IS_TRUE( player.b_is_designated_target ) )
	{
		designated_target = true;
	}

	if( !isDefined( player ) && !isDefined( zombie_poi ) && !isDefined( behaviorTreeEntity.attackable ) )
	{
		//behaviorTreeEntity zm_spawner::zombie_history( "find flesh -> can't find player, continue" );
		if( IsDefined( behaviorTreeEntity.ignore_player )  )
		{
			if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
			{
				return;
			}			
			behaviorTreeEntity.ignore_player = [];
		}
		
		/#
		if( IS_TRUE( behaviortreeentity.isPuppet ) )
		{
			return;
		}
		#/
		
		if( isdefined( level.no_target_override ) )
		{
			[[ level.no_target_override ]]( behaviorTreeEntity );			
		}
		else
		{
			behaviorTreeEntity SetGoal( behaviorTreeEntity.origin );
		}
		
		return;
	}
	
	//PI_CHANGE - 7/2/2009 JV Reenabling change 274916 (from DLC3)
	//behaviorTreeEntity.ignore_player = undefined;
	if ( !isDefined( level.check_for_alternate_poi ) || ![[level.check_for_alternate_poi]]() )
	{
		behaviorTreeEntity.enemyoverride = zombie_poi;
		
		behaviorTreeEntity.favoriteenemy = player;
	}

	if( isdefined( behaviorTreeEntity.v_zombie_custom_goal_pos ) )
	{
		goalPos = behaviorTreeEntity.v_zombie_custom_goal_pos;

		if ( isdefined( behaviorTreeEntity.n_zombie_custom_goal_radius ) )
		{
			behaviorTreeEntity.goalradius = behaviorTreeEntity.n_zombie_custom_goal_radius;
		}
		
		behaviorTreeEntity SetGoal( goalPos );
	}
	else if ( isdefined( behaviorTreeEntity.enemyoverride ) && isdefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		behaviorTreeEntity.has_exit_point = undefined;
		
		goalPos = behaviorTreeEntity.enemyoverride[0];
		
		// if behaviorTreeEntity.enemyoverride is populated by level script explicitely, as compared to something like cymbal monkey
		// then zombie_poi will be undefined, and we should use position query to find a good point.
		if( !IsDefined(zombie_poi) )
		{
			AIProfile_BeginEntry( "zombiefindflesh-enemyoverride" );
			queryResult = PositionQuery_Source_Navigation( goalPos, 0, 48, 36, 4 );
			AIProfile_EndEntry();
			
			foreach( point in queryResult.data )
			{
				goalPos = point.origin;
				break;
			}
		}
		
		behaviorTreeEntity SetGoal( goalPos );
		
	}
	else if ( isdefined( behaviorTreeEntity.attackable ) && !designated_target )
	{
		if ( isdefined( behaviorTreeEntity.attackable_slot ) )
		{
			if ( isdefined( behaviorTreeEntity.attackable_goal_radius ) )
			{
				behaviorTreeEntity.goalradius = behaviorTreeEntity.attackable_goal_radius;
			}

			nav_mesh = GetClosestPointOnNavMesh( behaviorTreeEntity.attackable_slot.origin, 64 );
			if ( isdefined( nav_mesh ) )
			{
				behaviorTreeEntity SetGoal( nav_mesh );
			}
			else
			{
				behaviorTreeEntity SetGoal( behaviorTreeEntity.attackable_slot.origin );
			}
		}
	}
	else if ( IsDefined( behaviorTreeEntity.favoriteenemy ) )
	{
		behaviorTreeEntity.has_exit_point = undefined;
		
		behaviorTreeEntity.ignoreall = false;

		if ( IsDefined( level.enemy_location_override_func ) )
		{
			goalPos = [[ level.enemy_location_override_func ]]( behaviorTreeEntity, behaviorTreeEntity.favoriteenemy );

			if ( IsDefined( goalPos ) )
			{
				behaviorTreeEntity SetGoal( goalPos );
			}
			else
			{
				behaviorTreeEntity zombieUpdateGoal();
			}
		}
		else if( IS_TRUE(behaviorTreeEntity.is_rat_test) )
		{
		}
		else if ( zm_behavior::zombieShouldMoveAwayCondition( behaviorTreeEntity ) )
		{
		}
		else if ( IsDefined( behaviorTreeEntity.favoriteenemy.last_valid_position ) )
		{
			behaviorTreeEntity zombieUpdateGoal();
		}
		else
		{
			//AssertMsg( "no last_valid_position" );
		}
	}
	
	//PI_CHANGE_BEGIN - 7/2/2009 JV Reenabling change 274916 (from DLC3)
	if( players.size > 1 )
	{
		for(i = 0; i < behaviorTreeEntity.ignore_player.size; i++)
		{
			if( IsDefined( behaviorTreeEntity.ignore_player[i] ) )
			{
				if( !IsDefined( behaviorTreeEntity.ignore_player[i].ignore_counter ) )
					behaviorTreeEntity.ignore_player[i].ignore_counter = 0;
				else
					behaviorTreeEntity.ignore_player[i].ignore_counter += 1;
			}
		}
	}
	//PI_CHANGE_END
}

//modified zombieFindFlesh. Calls update_valid_players to decide who should be ignored. Considers enemy and not favoriteenemy.

function zombieFindFleshCode( behaviorTreeEntity )
{
	AIProfile_BeginEntry( "zombieFindFleshCode" );

	if( level.intermission )
	{
		AIProfile_EndEntry();
		return;
	}

	behaviorTreeEntity.ignore_player = [];

	behaviorTreeEntity.goalradius = ZM_FIND_FLESH_RADIUS;

	if ( behaviorTreeEntity.team == "allies" )
	{
		behaviorTreeEntity findZombieEnemy();

		AIProfile_EndEntry();
		return;
	}

	if ( level.wait_and_revive )
	{
		AIProfile_EndEntry();
		return;
	}

	if ( level.zombie_poi_array.size > 0 )
	{
		zombie_poi = behaviorTreeEntity zm_utility::get_zombie_point_of_interest( behaviorTreeEntity.origin );	
	}
	
	behaviorTreeEntity zombie_utility::run_ignore_player_handler();

	zm_utility::update_valid_players( behaviorTreeEntity.origin, behaviorTreeEntity.ignore_player );

	if( !isDefined( behaviorTreeEntity.enemy ) && !isDefined( zombie_poi ) )
	{
		/#
			if( IS_TRUE( behaviortreeentity.isPuppet ) )
			{
				AIProfile_EndEntry();
				return;
			}
		#/
		
		if( isdefined( level.no_target_override ) )
		{
			[[ level.no_target_override ]]( behaviorTreeEntity );			
		}
		else
		{
			behaviorTreeEntity SetGoal( behaviorTreeEntity.origin );
		}

		AIProfile_EndEntry();
		return;
	}
	
	behaviorTreeEntity.enemyoverride = zombie_poi;

	if ( IsDefined( behaviorTreeEntity.enemyoverride ) && IsDefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		behaviorTreeEntity.has_exit_point = undefined;
		
		goalPos = behaviorTreeEntity.enemyoverride[0];
		queryResult = PositionQuery_Source_Navigation( goalPos, 0, 48, 36, 4 );
		foreach( point in queryResult.data )
		{
			goalPos = point.origin;
			break;
		}
		behaviorTreeEntity SetGoal( goalPos );
	}
	else if ( IsDefined( behaviorTreeEntity.enemy ) )
	{
		behaviorTreeEntity.has_exit_point = undefined;

		/#
			if ( IS_TRUE( behaviorTreeEntity.is_rat_test ) )
			{
				AIProfile_EndEntry();
				return;
			}
		#/

		if ( IsDefined( level.enemy_location_override_func ) )
		{
			goalPos = [[ level.enemy_location_override_func ]]( behaviorTreeEntity, behaviorTreeEntity.enemy );

			if ( IsDefined( goalPos ) )
			{
				behaviorTreeEntity SetGoal( goalPos );
			}
			else
			{
				behaviorTreeEntity zombieUpdateGoalCode();
			}
		}
		else if ( IsDefined( behaviorTreeEntity.enemy.last_valid_position ) )
		{
			behaviorTreeEntity zombieUpdateGoalCode();
		}
		else
		{
			//AssertMsg( "no last_valid_position" );
		}
	}

	AIProfile_EndEntry();
}

function zombieUpdateGoal()
{
	AIProfile_BeginEntry( "zombieUpdateGoal" );
	
	shouldRepath = false;
	
	if ( !shouldRepath && IsDefined( self.favoriteenemy ) )
	{
		if ( !IsDefined( self.nextGoalUpdate ) || self.nextGoalUpdate <= GetTime() )
		{
			// It's been a while, repath!
			shouldRepath = true;
		}
		else if ( DistanceSquared( self.origin, self.favoriteenemy.origin ) <= SQR( level.zigzag_activation_distance ) )
		{
			// Repath if close to the enemy.
			shouldRepath = true;
		}
		else if ( IsDefined( self.pathGoalPos ) )
		{
			// Repath if close to the current goal position.
			distanceToGoalSqr = DistanceSquared( self.origin, self.pathGoalPos );
			
			shouldRepath = distanceToGoalSqr < SQR( 72 );
		}
	}

	if ( IS_TRUE( level.validate_on_navmesh ) )
	{
		if ( !IsPointOnNavMesh( self.origin, self ) )
		{
			shouldRepath = false;
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
		self SetGoal( goalPos );

		should_zigzag = true;
		if ( IsDefined( level.should_zigzag ) )
		{
			should_zigzag = self [[ level.should_zigzag ]]();
		}
		
		// Randomized zig-zag path following if 20+ feet away from the enemy.
		if( IS_TRUE(level.do_randomized_zigzag_path) && should_zigzag )
		{
			if ( DistanceSquared( self.origin, goalPos ) > SQR( level.zigzag_activation_distance ) )
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
			
				deviationDistance = RandomIntRange( level.zigzag_distance_min, level.zigzag_distance_max );  // 20 to 40 feet
			
				if( IsDefined( self.zigzag_distance_min ) && IsDefined( self.zigzag_distance_max ) )
				{
					deviationDistance = RandomIntRange( self.zigzag_distance_min, self.zigzag_distance_max );  // 20 to 40 feet
				}
				
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
			
						innerZigZagRadius = level.inner_zigzag_radius;
						outerZigZagRadius = level.outer_zigzag_radius;
						
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
		}
		
		// Force repathing after a certain amount of time to smooth out movement.
		self.nextGoalUpdate = GetTime() + RandomIntRange(500, 1000);
	}
	AIProfile_EndEntry();
}

//modified version of zombieUpdateGoal that considers self.enemy and not self.favoriteenemy
function zombieUpdateGoalCode()
{
	AIProfile_BeginEntry( "zombieUpdateGoalCode" );
	
	shouldRepath = false;
	
	if ( !shouldRepath && IsDefined( self.enemy ) )
	{
		if ( !IsDefined( self.nextGoalUpdate ) || self.nextGoalUpdate <= GetTime() )
		{
			// It's been a while, repath!
			shouldRepath = true;
		}
		else if ( DistanceSquared( self.origin, self.enemy.origin ) <= SQR( 200 ) )
		{
			// Repath if close to the enemy.
			shouldRepath = true;
		}
		else if ( IsDefined( self.pathGoalPos ) )
		{
			// Repath if close to the current goal position.
			distanceToGoalSqr = DistanceSquared( self.origin, self.pathGoalPos );
			
			shouldRepath = distanceToGoalSqr < SQR( 72 );
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
		goalPos = self.enemy.origin;
		if ( IsDefined( self.enemy.last_valid_position ) )
		{
			goalPos = self.enemy.last_valid_position;
		}
		
		// Randomized zig-zag path following if 20+ feet away from the enemy.
		if( IS_TRUE(level.do_randomized_zigzag_path) )
		{
			if ( DistanceSquared( self.origin, goalPos ) > SQR( 240 ) )
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
					
						/# RecordCircle( seedPosition, 2, ORANGE, "Animscript", self ); #/
			
						innerZigZagRadius = level.inner_zigzag_radius;
						outerZigZagRadius = level.outer_zigzag_radius;
						
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
							
							if ( TracePassedOnNavMesh( seedPosition, point.origin, 16 ) )
							{
								// Use the deviated point as the path instead.
								goalPos = point.origin;
							}
						}
					
						break;
					}
					
					segmentLength += currentSegLength;
				}
			}
		}
		
		self SetGoal( goalPos );

		self.nextGoalUpdate = GetTime() + RandomIntRange(500, 1000);
	}
	AIProfile_EndEntry();
}

function zombieEnteredPlayable( behaviorTreeEntity )
{
	if ( !IsDefined( level.playable_areas ) )
	{
		level.playable_areas = GetEntArray("player_volume", "script_noteworthy" );
	}

	foreach(area in level.playable_areas)
	{
		if(behaviorTreeEntity IsTouching(area))
		{
			behaviorTreeEntity zm_spawner::zombie_complete_emerging_into_playable_area();
			return true;
		}
	}

	return false;
}	

function shouldMoveCondition( behaviorTreeEntity )
{
	if ( behaviorTreeEntity HasPath() )
	{
		return true;
	}

	if ( IS_TRUE( behaviorTreeEntity.keep_moving ) )
	{
		return true;
	}

	return false;
}

function zombieShouldMoveAwayCondition( behaviorTreeEntity )
{
	return level.wait_and_revive;
}

function wasKilledByTeslaCondition( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.tesla_death ) )
	{
		return true;
	}

	return false;
}

function disablePowerups( behaviorTreeEntity )
{
	behaviorTreeEntity.no_powerups = true;
}

function enablePowerups( behaviorTreeEntity )
{
	behaviorTreeEntity.no_powerups = false;
}

function zombieMoveAway( behaviorTreeEntity, asmStateName)
{
	player = util::GetHostPlayer();
	queryResult = level.move_away_points;
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );

	if ( !IsDefined( queryResult ) )
	{
		return BHTN_RUNNING;
	}
	
	for(i = 0; i < queryResult.data.size; i++)
	{
		if ( !zm_utility::check_point_in_playable_area( queryResult.data[i].origin ) )
		{
			continue;
		}

		isBehind = vectordot( player.origin - behaviorTreeEntity.origin, queryResult.data[i].origin - behaviorTreeEntity.origin );
		if(isBehind < 0 )
		{
			behaviorTreeEntity SetGoal( queryResult.data[i].origin );
			ArrayRemoveIndex(level.move_away_points.data, i, false);
			i--;
			return BHTN_RUNNING;
		}
	}
	
	for(i = 0; i < queryResult.data.size; i++)
	{
		if ( !zm_utility::check_point_in_playable_area( queryResult.data[i].origin ) )
		{
			continue;
		}

		dist_zombie = DistanceSquared( queryResult.data[i].origin, behaviorTreeEntity.origin );
		dist_player = DistanceSquared( queryResult.data[i].origin, player.origin );

		if ( dist_zombie < dist_player )
		{
			behaviorTreeEntity SetGoal( queryResult.data[i].origin );
			ArrayRemoveIndex(level.move_away_points.data, i, false);
			i--;
			return BHTN_RUNNING;
		}
	}
	return BHTN_RUNNING;
}

function zombieIsBeingGrappled( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.grapple_is_fatal ) )
	{
		return true;
	}
	return false;
}

function zombieShouldKnockdown( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.knockdown ) )
	{
		return true;
	}

	return false;
}

function zombieIsPushed( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.pushed ) )
	{
		return true;
	}

	return false;
}

function zombieGrappleActionStart( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, GRAPPLE_DIRECTION, self.grapple_direction );
}

function private zombieKnockdownActionStart( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, KNOCKDOWN_DIRECTION, behaviorTreeEntity.knockdown_direction );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, KNOCKDOWN_TYPE, behaviorTreeEntity.knockdown_type );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, GETUP_DIRECTION, behaviorTreeEntity.getup_direction );
}

function private zombieGetupActionTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity.knockdown = false;
}

function private zombiePushedActionStart( behaviorTreeEntity )
{
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, PUSH_DIRECTION, behaviorTreeEntity.push_direction );
}

function private zombiePushedActionTerminate( behaviorTreeEntity )
{
	behaviorTreeEntity.pushed = false;
}

function zombieShouldStun( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.zombie_tesla_hit ) && !IS_TRUE( behaviorTreeEntity.tesla_death ) )
	{
		return true;
	}
	return false;
}

function zombieStunActionStart( behaviorTreeEntity )
{

}

function zombieStunActionEnd( behaviorTreeEntity )
{
	behaviorTreeEntity.zombie_tesla_hit = false;
}

function zombieTraverseAction( behaviorTreeEntity, asmStateName )
{
	AiUtility::traverseActionStart( behaviorTreeEntity, asmStateName );

	behaviorTreeEntity.old_powerups = behaviorTreeEntity.no_powerups;

	disablePowerups( behaviorTreeEntity );

	return BHTN_RUNNING;
}

function zombieTraverseActionTerminate( behaviorTreeEntity, asmStateName )
{
	if ( behaviorTreeEntity ASMGetStatus() == ASM_STATE_COMPLETE )
	{
		behaviorTreeEntity.no_powerups = behaviorTreeEntity.old_powerups;

		if ( !IS_TRUE( behaviorTreeEntity.missingLegs ) )
		{
			behaviorTreeEntity PushActors( false );
			behaviorTreeEntity.enablePushTime = GetTime() + ZM_TURN_OFF_PUSH_TIME;
		}
	}

	return BHTN_SUCCESS;	
}

function zombieGotToEntranceCondition( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.got_to_entrance ) )
	{
		return true;
	}

	return false;
}

function zombieGotToAttackSpotCondition( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.at_entrance_tear_spot ) )
	{
		return true;
	}

	return false;
}

function zombieHasAttackSpotAlreadyCondition( behaviorTreeEntity )
{
	//if( IsDefined( behaviorTreeEntity.script_parameters ) && behaviorTreeEntity.script_parameters == "ignore_attack_spot" )
	//{
	//	return true;
	//}

	if( IsDefined( behaviorTreeEntity.attacking_spot_index ) && behaviorTreeEntity.attacking_spot_index >= 0 )
	{
		return true;
	}

	return false;
}

function zombieShouldTearCondition( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.first_node ) && IsDefined( behaviorTreeEntity.first_node.barrier_chunks ) )
	{
		if( !zm_utility::all_chunks_destroyed( behaviorTreeEntity.first_node, behaviorTreeEntity.first_node.barrier_chunks ) )
		{
			return true;
		}
	}
		
	return false;
}

function zombieShouldAttackThroughBoardsCondition( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.missingLegs ) )
		return false;
	
	if( isdefined( behaviorTreeEntity.first_node.zbarrier ) )
	{
		if( !behaviorTreeEntity.first_node.zbarrier ZBarrierSupportsZombieReachThroughAttacks() )
		{
			// can only try if all chunks are down
			chunks = undefined;
			if ( isdefined( behaviorTreeEntity.first_node ) )
			{
				chunks = zm_utility::get_non_destroyed_chunks( behaviorTreeEntity.first_node, behaviorTreeEntity.first_node.barrier_chunks );
			}

			if ( isdefined( chunks ) && chunks.size > 0 )
			{
				return false;
			}
		}
	}
	
	if(GetDvarString( "zombie_reachin_freq") == "")
	{
		SetDvar("zombie_reachin_freq","50");
	}
	freq = GetDvarInt( "zombie_reachin_freq");
	
	players = GetPlayers();
	attack = false;

    behaviorTreeEntity.player_targets = [];
    for(i=0;i<players.size;i++)
    {
    	if ( isAlive( players[i] ) && !isDefined( players[i].revivetrigger ) && distance2d( behaviorTreeEntity.origin, players[i].origin ) <= 109.8 && !IS_TRUE( players[i].zombie_vars[ "zombie_powerup_zombie_blood_on" ] ) &&
			 !IS_TRUE( players[i].ignoreme ) )
        {
            behaviorTreeEntity.player_targets[behaviorTreeEntity.player_targets.size] = players[i];
            attack = true;
        }
    }

    if ( !attack || freq < randomint(100) )
	{
		return false;	
	}

	return true;
}

function zombieShouldTauntCondition( behaviorTreeEntity )
{
	if( IS_TRUE( behaviorTreeEntity.missingLegs) )
		return false;
	
	if( !IsDefined(behaviorTreeEntity.first_node.zbarrier) )
	{
		return false;
	}

	if( !behaviorTreeEntity.first_node.zbarrier ZBarrierSupportsZombieTaunts() )
	{
		return false;
	}
	
	if(GetDvarString( "zombie_taunt_freq") == "")
	{
		SetDvar("zombie_taunt_freq","5"); 
	}
	freq = GetDvarInt( "zombie_taunt_freq");

	if( freq >= randomint(100) )
	{
		return true;
	}
	return false;
}

function zombieShouldEnterPlayableCondition( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.first_node ) && IsDefined( behaviorTreeEntity.first_node.barrier_chunks ) )
	{
		if( zm_utility::all_chunks_destroyed( behaviorTreeEntity.first_node, behaviorTreeEntity.first_node.barrier_chunks ) )
		{
			if( IS_TRUE( behaviorTreeEntity.at_entrance_tear_spot ) && !IS_TRUE( behaviorTreeEntity.completed_emerging_into_playable_area ) )
			{
				return true;
			}
		}
	}

	return false;
}

function isChunkValidCondition( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.chunk ) )
	{
		return true;
	}

	return false;
}

function inPlayableArea( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.completed_emerging_into_playable_area ) )
	{
		return true;
	}

	return false;
}

function shouldSkipTeardown( behaviorTreeEntity )
{
	if ( behaviorTreeEntity zm_spawner::should_skip_teardown( behaviorTreeEntity.find_flesh_struct_string ) )
	{
		return true;
	}

	return false;
}

function zombieIsThinkDone( behaviorTreeEntity )
{
	/#
		if( IS_TRUE( behaviorTreeEntity.is_rat_test ) )
			return false;
	#/
		
		
	if ( IS_TRUE( behaviorTreeEntity.zombie_think_done ) )
	{
		return true;
	}

	return false;
}

function zombieIsAtGoal( behaviorTreeEntity )
{
	isAtScriptGoal = behaviorTreeEntity IsAtGoal();

	return isAtScriptGoal;
}

function zombieIsAtEntrance( behaviorTreeEntity )
{
	isAtScriptGoal = behaviorTreeEntity IsAtGoal();
	isAtEntrance = IsDefined( behaviorTreeEntity.first_node ) && isAtScriptGoal;

	return isAtEntrance;
}

// ------- ZOMBIE SERVICES -----------//
function getChunkService( behaviorTreeEntity )
{
	behaviorTreeEntity.chunk = zm_utility::get_closest_non_destroyed_chunk( behaviorTreeEntity.origin, behaviorTreeEntity.first_node, behaviorTreeEntity.first_node.barrier_chunks );
	if( IsDefined( behaviorTreeEntity.chunk ) )
	{
		behaviorTreeEntity.first_node.zbarrier SetZBarrierPieceState(behaviorTreeEntity.chunk, "targetted_by_zombie");
		behaviorTreeEntity.first_node thread zm_spawner::check_zbarrier_piece_for_zombie_death( behaviorTreeEntity.chunk, behaviorTreeEntity.first_node.zbarrier, behaviorTreeEntity );
	}
}

function updateChunkService( behaviorTreeEntity )
{
	while( 0 < behaviorTreeEntity.first_node.zbarrier.chunk_health[behaviorTreeEntity.chunk] )
	{
		behaviorTreeEntity.first_node.zbarrier.chunk_health[behaviorTreeEntity.chunk]--;
	}
	behaviorTreeEntity.lastchunk_destroy_time = GetTime();
}

function updateAttackSpotService( behaviorTreeEntity )
{
	if ( IS_TRUE( behaviorTreeEntity.marked_for_death ) || behaviorTreeEntity.health < 0 )
	{
		return false;
	}

	if( !IsDefined( behaviorTreeEntity.attacking_spot ) )
	{
		if ( !behaviorTreeEntity zm_spawner::get_attack_spot( behaviorTreeEntity.first_node ) )
		{
			//if( IsDefined( behaviorTreeEntity.script_parameters ) && behaviorTreeEntity.script_parameters == "ignore_attack_spot" )
			//{
			//	behaviorTreeEntity.goalradius = ZM_ATTACKING_SPOT_DIST;
			//	behaviorTreeEntity SetGoal( behaviorTreeEntity.first_node );
			//	return true;
			//}

			return false;
		}
	}

	if( IsDefined( behaviorTreeEntity.attacking_spot ) )
	{
		behaviorTreeEntity.goalradius = ZM_ATTACKING_SPOT_DIST;
		behaviorTreeEntity SetGoal( behaviorTreeEntity.attacking_spot );

		if ( behaviorTreeEntity IsAtGoal() )
		{
			behaviorTreeEntity.at_entrance_tear_spot = true;
		}

		return true;
	}

	return false;
}

function findNodesService( behaviorTreeEntity )
{
	node = undefined;

	behaviorTreeEntity.entrance_nodes = [];

	if( IsDefined( behaviorTreeEntity.find_flesh_struct_string ) )
	{
		if ( behaviorTreeEntity.find_flesh_struct_string == "find_flesh" )
		{
			return false;
		}

		for( i=0; i<level.exterior_goals.size; i++ )
		{
			if( IsDefined(level.exterior_goals[i].script_string) && level.exterior_goals[i].script_string == behaviorTreeEntity.find_flesh_struct_string )
			{
				node = level.exterior_goals[i];
				break;
			}
		}

		behaviorTreeEntity.entrance_nodes[behaviorTreeEntity.entrance_nodes.size] = node;

		assert( IsDefined( node ), "Did not find an entrance node with .script_string:" + behaviorTreeEntity.find_flesh_struct_string+ "!!! [Fix this!]" );

		behaviorTreeEntity.first_node = node;
		//behaviorTreeEntity.pushable = false; //turn off pushable
		behaviorTreeEntity.goalradius = ZM_ENTRANCE_DIST; 
		behaviorTreeEntity SetGoal( node.origin );

		// zombie spawned within the entrance
		if ( zombieIsAtEntrance( behaviorTreeEntity ) )
		{
			behaviorTreeEntity.got_to_entrance = true;
		}

		return true;
	}
}

function zombieAttackableObjectService( behaviorTreeEntity )
{
	if ( !behaviorTreeEntity ai::has_behavior_attribute( "use_attackable" ) || !behaviorTreeEntity ai::get_behavior_attribute( "use_attackable" ) )
	{
		behaviorTreeEntity.attackable = undefined;
		return false;
	}

	if ( IS_TRUE( behaviorTreeEntity.missingLegs ) )
	{
		behaviorTreeEntity.attackable = undefined;
		return false;
	}

	if ( IS_TRUE( behaviorTreeEntity.aat_turned ) )
	{
		behaviorTreeEntity.attackable = undefined;
		return false;
	}

	if ( !IsDefined( behaviorTreeEntity.attackable ) )
	{
		behaviorTreeEntity.attackable = zm_attackables::get_attackable();
	}
	else
	{
		if ( !IS_TRUE( behaviorTreeEntity.attackable.is_active ) )
		{
			behaviorTreeEntity.attackable = undefined;
		}
	}
}

function zombieMoveToEntranceAction( behaviorTreeEntity, asmStateName )
{	
	behaviorTreeEntity.got_to_entrance = false;
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );

	return BHTN_RUNNING;
}

function zombieMoveToEntranceActionTerminate( behaviorTreeEntity, asmStateName )
{
	if ( zombieIsAtEntrance( behaviorTreeEntity ) )
	{
		behaviorTreeEntity.got_to_entrance = true;
	}

	return BHTN_SUCCESS;	
}

function zombieMoveToAttackSpotAction( behaviorTreeEntity, asmStateName )
{	
	behaviorTreeEntity.at_entrance_tear_spot = false;
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );

	return BHTN_RUNNING;
}

function zombieMoveToAttackSpotActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviorTreeEntity.at_entrance_tear_spot = true;

	return BHTN_SUCCESS;	
}

// ------- ZOMBIE TEAR DOWN -----------//
function zombieHoldBoardAction( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = true;
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, WHICH_BOARD_PULL_TYPE, int( behaviorTreeEntity.chunk ) );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, BOARD_ATTACK_SPOT, float( behaviorTreeEntity.attacking_spot_index ) );
	
	boardActionAST = behaviorTreeEntity ASTSearch(  IString( asmStateName ) );
	boardActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( behaviorTreeEntity, boardActionAST[ ASM_ALIAS_ATTRIBUTE ] );
	//behaviorTreeEntity AnimScripted( "grab_anim", behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	
	//origin = GetStartOrigin( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//angles = GetStartAngles( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//
	//behaviorTreeEntity ForceTeleport( origin, angles, true );
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombieHoldBoardActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = false;
	return BHTN_SUCCESS;	
}

function zombieGrabBoardAction( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = true;
	
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, WHICH_BOARD_PULL_TYPE, int( behaviorTreeEntity.chunk ) );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, BOARD_ATTACK_SPOT, float( behaviorTreeEntity.attacking_spot_index ) );
	
	boardActionAST = behaviorTreeEntity ASTSearch(  IString( asmStateName ) );
	boardActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( behaviorTreeEntity, boardActionAST[ ASM_ALIAS_ATTRIBUTE ] );
	//behaviorTreeEntity AnimScripted( "grab_anim", behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	
	//origin = GetStartOrigin( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//angles = GetStartAngles( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//
	//behaviorTreeEntity ForceTeleport( origin, angles, true );
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombieGrabBoardActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = false;
	return BHTN_SUCCESS;	
}

function zombiePullBoardAction( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = true;
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, WHICH_BOARD_PULL_TYPE, int( behaviorTreeEntity.chunk ) );
	Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, BOARD_ATTACK_SPOT, float( behaviorTreeEntity.attacking_spot_index ) );
	
	boardActionAST = behaviorTreeEntity ASTSearch(  IString( asmStateName ) );
	boardActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( behaviorTreeEntity, boardActionAST[ ASM_ALIAS_ATTRIBUTE ] );
	//behaviorTreeEntity AnimScripted( "grab_anim", behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	
	//origin = GetStartOrigin( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//angles = GetStartAngles( behaviorTreeEntity.first_node.zbarrier.origin, behaviorTreeEntity.first_node.zbarrier.angles, boardActionAnimation );
	//
	//behaviorTreeEntity ForceTeleport( origin, angles, true );
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombiePullBoardActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = false;

    //to prevent the zombie from being deleted by the failsafe system
    self.lastchunk_destroy_time = GetTime();

	return BHTN_SUCCESS;	
}

// ------- ZOMBIE MELEE BEHIND BOARDS -----------//

function zombieAttackThroughBoardsAction( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = true;
	behaviortreeentity.boardAttack = true;
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombieAttackThroughBoardsActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = false;
	behaviortreeentity.boardAttack = false;

	
	return BHTN_SUCCESS;	
}

// ------- ZOMBIE TAUNT -----------//

function zombieTauntAction( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = true;
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombieTauntActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviortreeentity.keepClaimedNode = false;

	return BHTN_SUCCESS;	
}

function zombieMantleAction( behaviorTreeEntity, asmStateName )
{
	behaviorTreeEntity.clamptonavmesh = 0;
	if( IsDefined( behaviorTreeEntity.attacking_spot_index ) )
	{
		behaviorTreeEntity.saved_attacking_spot_index = behaviorTreeEntity.attacking_spot_index;
		Blackboard::SetBlackBoardAttribute( behaviorTreeEntity, BOARD_ATTACK_SPOT, float( behaviorTreeEntity.attacking_spot_index ) );
	}
	
	behaviorTreeEntity.isInMantleAction = true;
	
	// the attack spot needs to be cleared when a zombie enters playable area
	behaviorTreeEntity zombie_utility::reset_attack_spot();
	
	AnimationStateNetworkUtility::RequestState( behaviorTreeEntity, asmStateName );
	
	return BHTN_RUNNING;
}
	
function zombieMantleActionTerminate( behaviorTreeEntity, asmStateName )
{
	behaviorTreeEntity.clamptonavmesh = 1;
	
	behaviorTreeEntity.isInMantleAction = undefined;
	
	behaviorTreeEntity zm_behavior_utility::enteredPlayableArea();

	return BHTN_SUCCESS;	
}

// ------- ZOMBIE MOCOMP -----------//
function boardTearMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	origin = GetStartOrigin( entity.first_node.zbarrier.origin, entity.first_node.zbarrier.angles, mocompAnim );
	angles = GetStartAngles( entity.first_node.zbarrier.origin, entity.first_node.zbarrier.angles, mocompAnim );
	
	entity ForceTeleport( origin, angles, true );

	entity.pushable = false;
	entity.blockingPain = true;

	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, true );
	entity OrientMode( "face angle", angles[1] );
}

function boardTearMocompUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity.pushable = false;
	entity.blockingPain = true;
}

function barricadeEnterMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	origin = GetStartOrigin( entity.first_node.zbarrier.origin, entity.first_node.zbarrier.angles, mocompAnim );
	angles = GetStartAngles( entity.first_node.zbarrier.origin, entity.first_node.zbarrier.angles, mocompAnim );
	
	if( isdefined(entity.mocomp_barricade_offset) )
	{
		origin = origin + AnglesToForward(angles) * entity.mocomp_barricade_offset;
	}
	
	entity ForceTeleport( origin, angles, true );

	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity OrientMode( "face angle", angles[1] );

	entity.pushable = false;
	entity.blockingPain = true;
	entity PathMode( "dont move" );
	entity.useGoalAnimWeight = true;
}

function barricadeEnterMocompUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );

	entity.pushable = false;
}

function barricadeEnterMocompTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.pushable = true;
	entity.blockingPain = false;
	entity PathMode( "move allowed" );
	entity.useGoalAnimWeight = false;

	entity AnimMode( AI_ANIM_MOVE_CODE, false );
	entity OrientMode( "face motion" );
}

function barricadeEnterMocompNoZStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	zbarrier_origin = (entity.first_node.zbarrier.origin[0], entity.first_node.zbarrier.origin[1], entity.origin[2]);
		
	origin = GetStartOrigin( zbarrier_origin, entity.first_node.zbarrier.angles, mocompAnim );
	angles = GetStartAngles( zbarrier_origin, entity.first_node.zbarrier.angles, mocompAnim );

	if( isdefined(entity.mocomp_barricade_offset) )
	{
		origin = origin + AnglesToForward(angles) * entity.mocomp_barricade_offset;
	}
	
	entity ForceTeleport( origin, angles, true );

	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity OrientMode( "face angle", angles[1] );

	entity.pushable = false;
	entity.blockingPain = true;
	entity PathMode( "dont move" );
	entity.useGoalAnimWeight = true;
}

function barricadeEnterMocompNoZUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );
	entity.pushable = false;
}

function barricadeEnterMocompNoZTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.pushable = true;
	entity.blockingPain = false;
	entity PathMode( "move allowed" );
	entity.useGoalAnimWeight = false;

	entity AnimMode( AI_ANIM_MOVE_CODE, false );
	entity OrientMode( "face motion" );
}

// ------- ZM NOTETRACK HANDLERS -----------//
function notetrackBoardTear( animationEntity )
{
	if( IsDefined( animationEntity.chunk ) )
	{
		animationEntity.first_node.zbarrier SetZBarrierPieceState( animationEntity.chunk, "opening" );
	}
}

function notetrackBoardMelee( animationEntity )
{
	assert( animationEntity.meleeWeapon != level.weaponnone, "Actor does not have a melee weapon" );
	// just hit a player
	if ( IsDefined( animationEntity.first_node ) )
	{
		meleeDistSq = ZM_BOARD_MELEE_DIST_SQ;
				
		if ( IsDefined( level.attack_player_thru_boards_range ) )
 		{
 			meleeDistSq = level.attack_player_thru_boards_range * level.attack_player_thru_boards_range;
		}
				
		triggerDistSq = ZM_BOARD_TRIGGER_DIST_SQ;

		for ( i = 0; i < animationEntity.player_targets.size; i++ )
		{
			playerDistSq = Distance2DSquared( animationEntity.player_targets[i].origin, animationEntity.origin );
			heightDiff = abs( animationEntity.player_targets[i].origin[2] - animationEntity.origin[2] ); // be sure we're on the same floor
			if ( playerDistSq < meleeDistSq && (heightDiff * heightDiff) < meleeDistSq )
			{
				playerTriggerDistSq = Distance2DSquared( animationEntity.player_targets[i].origin, animationEntity.first_node.trigger_location.origin );
				heightDiff = abs( animationEntity.player_targets[i].origin[2] - animationEntity.first_node.trigger_location.origin[2] ); // be sure we're on the same floor
				if ( playerTriggerDistSq < triggerDistSq && (heightDiff * heightDiff) < triggerDistSq )
				{
					animationEntity.player_targets[i] DoDamage( animationEntity.meleeWeapon.meleeDamage, animationEntity.origin, self, self, "none", "MOD_MELEE" );
					break;
				}
			}
		}
	}
	else
	{
		animationentity Melee();
	}
}

function findZombieEnemy()
{
	zombies = GetAiSpeciesArray( level.zombie_team, "all" );

	zombie_enemy = undefined;
	closest_dist = undefined;

	foreach( zombie in zombies )
	{
		if ( IsAlive( zombie ) && IS_TRUE( zombie.completed_emerging_into_playable_area ) && !zm_utility::is_magic_bullet_shield_enabled( zombie ) &&
		    (zombie.archetype == ARCHETYPE_ZOMBIE || IS_TRUE(zombie.canBeTargetedByTurnedZombies)) )
		{
			dist = DistanceSquared( self.origin, zombie.origin );
			if ( !isdefined( closest_dist ) || dist < closest_dist )
			{
				closest_dist = dist;
				zombie_enemy = zombie;
			}
		}
	}

	self.favoriteenemy = zombie_enemy;

	if ( isdefined( self.favoriteenemy ) )
	{
		self SetGoal( self.favoriteenemy.origin );
	}
	else
	{
		self SetGoal( self.origin );
	}
}

function zombieBlackHoleBombPullStart( entity, asmStateName )
{
	entity.pullTime = GetTime();
	entity.pullOrigin = entity.origin;
	
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );
	
	zombieUpdateBlackHoleBombPullState( entity );
	
	if( IsDefined( entity.damageOrigin ) )
	{
		entity.n_zombie_custom_goal_radius = 8;
		entity.v_zombie_custom_goal_pos = entity.damageOrigin;
	}
	
	return BHTN_RUNNING;
}

#define SOUL_BURST_RANGE	2500 //50*50
#define PULLED_IN_RANGE		16384 //128*128
#define INNER_RANGE			1048576 //1024*1024
#define OUTER_RANGE			4227136 //2056*2056

function zombieUpdateBlackHoleBombPullState( entity )
{
	dist_to_bomb = DistanceSquared( entity.origin, entity.damageOrigin );
	
	if( dist_to_bomb < PULLED_IN_RANGE )
	{
		entity._black_hole_bomb_collapse_death = true;
	}
	else if( dist_to_bomb < INNER_RANGE )
	{
		Blackboard::SetBlackBoardAttribute( entity, BLACKHOLEBOMB_PULL_STATE, BLACKHOLEBOMB_PULL_FAST );
	}
	else if( dist_to_bomb < OUTER_RANGE )
	{
		Blackboard::SetBlackBoardAttribute( entity, BLACKHOLEBOMB_PULL_STATE, BLACKHOLEBOMB_PULL_SLOW );
	}
}
	
function zombieBlackHoleBombPullUpdate( entity, asmStateName )
{
	if( !IsDefined( entity.interdimensional_gun_kill ) )
	{
		return BHTN_SUCCESS;
	}
	
	zombieUpdateBlackHoleBombPullState( entity );
	
	if( IS_TRUE( entity._black_hole_bomb_collapse_death ) )
	{
		entity.skipAutoRagdoll = true;
		entity DoDamage( entity.health + 666, entity.origin + ( 0, 0, 50 ), entity.interdimensional_gun_attacker, undefined, undefined, "MOD_CRUSH" );
		return BHTN_SUCCESS;
	}
	
	if( IsDefined( entity.damageOrigin ) )
	{
		entity.v_zombie_custom_goal_pos = entity.damageOrigin;
	}
	
	if ( !IS_TRUE( entity.missingLegs ) && ( GetTime() - entity.pullTime > ZM_MOVE_TIME ) )
	{
		distSq = Distance2DSquared( entity.origin, entity.pullOrigin );
		if ( distSq < ZM_MOVE_DIST_SQ )
		{
			entity SetAvoidanceMask( "avoid all" );
			entity.cant_move = true;

			if ( IsDefined( entity.cant_move_cb ) )
			{
				entity [[ entity.cant_move_cb ]]();
			}
		}
		else
		{
			entity SetAvoidanceMask( "avoid none" );
			entity.cant_move = false;
		}

		entity.pullTime = GetTime();
		entity.pullOrigin = entity.origin;
	}
	
	return BHTN_RUNNING;
}

function zombieBlackHoleBombPullEnd( entity, asmStateName )
{
	entity.v_zombie_custom_goal_pos = undefined;
	entity.n_zombie_custom_goal_radius = undefined;
	
	entity.pullTime = undefined;
	entity.pullOrigin = undefined;
	
	return BHTN_SUCCESS;
}

function zombieKilledWhileGettingPulled( entity )
{
	if( !IS_TRUE( self.missingLegs) && IS_TRUE( entity.interdimensional_gun_kill ) && !IS_TRUE( entity._black_hole_bomb_collapse_death ) )
	{
		return true;
	}
	
	return false;
}

function zombieKilledByBlackHoleBombCondition( entity )
{
	if( IS_TRUE( entity._black_hole_bomb_collapse_death ) )
	{
		return true;
	}
	
	return false;
}

function zombieKilledByBlackHoleBombStart( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	if( IsDefined( level.black_hole_bomb_death_start_func ) )
	{
		entity thread [[level.black_hole_bomb_death_start_func]]( entity.damageOrigin, entity.interdimensional_gun_projectile );
	}
	
	return BHTN_RUNNING;
}

function zombieKilledByBlackHoleBombEnd( entity, asmStateName )
{
	if( IsDefined( level._effect ) && IsDefined( level._effect[ "black_hole_bomb_zombie_gib" ] ) )
	{
		fxOrigin = entity GetTagOrigin( "tag_origin" );
		
		forward = AnglesToForward( entity.angles );
		
		PlayFX( level._effect[ "black_hole_bomb_zombie_gib" ], fxOrigin, forward, ( 0, 0, 1 ) );
	}
	entity Hide();
	
	return BHTN_SUCCESS;
}

function zombieBHBBurst( entity )
{
	if( IsDefined( level._effect ) && IsDefined( level._effect[ "black_hole_bomb_zombie_destroy" ] ) )
	{
		fxOrigin = entity GetTagOrigin( "tag_origin" );
		PlayFx(level._effect[ "black_hole_bomb_zombie_destroy" ], fxOrigin );
	}
	
	if( IsDefined( entity.interdimensional_gun_projectile ) )
	{
		entity.interdimensional_gun_projectile notify( "black_hole_bomb_kill" );
	}
}
