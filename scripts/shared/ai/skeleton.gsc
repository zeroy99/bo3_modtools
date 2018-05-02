#using scripts\shared\ai_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\system_shared;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\codescripts\struct;
#using scripts\shared\ai\archetype_mocomps_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\skeleton.gsh; 
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace SkeletonBehavior;

REGISTER_SYSTEM( "skeleton", &__init__, undefined )

function __init__()
{
	// INIT BEHAVIORS
	InitSkeletonBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_SKELETON, &ArchetypeSkeletonBlackboardInit );
	
	// INIT SKELETON ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_SKELETON, &skeletonSpawnSetup ); 

	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_SKELETON ) )
	{
		clientfield::register(
			"actor",
			SKELETON_CLIENTFIELD,
			VERSION_SHIP,
			1,
			"int");
	}
}

function skeletonSpawnSetup()
{
	self.zombie_move_speed = "walk";
	if(randomint( 2 ) == 0)
		self.zombie_arms_position = "up";
	else
		self.zombie_arms_position = "down";
	self.missingLegs = false;
	self setAvoidanceMask( "avoid none" );	
	self PushActors( true );

	clientfield::set( SKELETON_CLIENTFIELD, true );
}


function private InitSkeletonBehaviorsAndASM()
{
	BT_REGISTER_API( "skeletonTargetService", 		&skeletonTargetService );
	BT_REGISTER_API( "skeletonShouldMelee", 		&skeletonShouldMeleeCondition );
	BT_REGISTER_API( "skeletonGibLegsCondition", 	&skeletonGibLegsCondition ); 
	BT_REGISTER_API( "isSkeletonWalking", 			&isSkeletonWalking ); 

	BT_REGISTER_API( "skeletonDeathAction", 		&skeletonDeathAction ); 
		
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_SKELETON_MELEE_NOTETRACK, &skeletonNotetrackMeleeFire );
}

function private ArchetypeSkeletonBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE SKELETON BLACKBOARD
	BB_REGISTER_ATTRIBUTE( ARMS_POSITION, 			ARMS_UP,				&BB_GetArmsPosition );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,	LOCOMOTION_SPEED_WALK,	&BB_GetLocomotionSpeedType );
	BB_REGISTER_ATTRIBUTE( HAS_LEGS_TYPE,			HAS_LEGS_YES,			&BB_GetHasLegsStatus );
	BB_REGISTER_ATTRIBUTE( WHICH_BOARD_PULL_TYPE,	undefined, 				undefined );
	BB_REGISTER_ATTRIBUTE( BOARD_ATTACK_SPOT,		undefined, 				undefined );	
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeSkeletonOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private ArchetypeSkeletonOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeSkeletonBlackboardInit();
}

// ------- BLACKBOARD -----------//

function BB_GetArmsPosition()
{
	if( IsDefined( self.skeleton_arms_position ) )
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
	}
	return LOCOMOTION_SPEED_WALK;
}

function BB_GetHasLegsStatus()
{
	if( self.missingLegs )
		return HAS_LEGS_NO;
	return HAS_LEGS_YES;
}

// ------- BLACKBOARD -----------//



function isSkeletonWalking( behaviorTreeEntity )
{
	if( !isdefined(behaviorTreeEntity.zombie_move_speed))
		return true;
	return behaviorTreeEntity.zombie_move_speed == "walk" && !IS_TRUE(behaviorTreeEntity.missingLegs) && behaviorTreeEntity.zombie_arms_position == "up";
}

function skeletonGibLegsCondition( behaviorTreeEntity)
{
	return GibServerUtils::IsGibbed( behaviorTreeEntity, GIB_LEGS_LEFT_LEG_FLAG) || GibServerUtils::IsGibbed( behaviorTreeEntity, GIB_LEGS_RIGHT_LEG_FLAG);
}

function skeletonNotetrackMeleeFire( animationEntity )
{
	hitEnt = animationentity Melee();
	if(isDefined(hitEnt) && isDefined(animationentity.aux_melee_damage) && self.team != hitEnt.team )
	{
		animationentity [[animationentity.aux_melee_damage]](hitEnt);
	}
}

function is_within_fov( start_origin, start_angles, end_origin, fov )
{
	normal = VectorNormalize( end_origin - start_origin ); 
	forward = AnglesToForward( start_angles ); 
	dot = VectorDot( forward, normal ); 

	return dot >= fov; 
}

#define LAST_SEEN_LOSS_LATENCY	3000

function skeletonCanSeePlayer( player )
{
	self endon( "death" );

	if(!isDefined(self.players_visCache))
	{
		self.players_visCache = [];
	}
	entNum = player GetEntityNumber();
	if(!isDefined(self.players_visCache[entNum]))
	{
		self.players_visCache[entNum] = 0;
	}
	if (self.players_visCache[entNum] > GetTime() )
	{
		return true;
	}
	
	//zombie_eye = self GetTagOrigin( "tag_eye" );
	zombie_eye = self.origin + ( 0, 0, 40);
	player_pos = player.origin + ( 0, 0, 40);
	
	//as_debug::drawDebugCross( zombie_eye, 5.0, ( 0.0, 0.0, 1.0 ), 1 );
	//as_debug::drawDebugCross( player_pos, 5.0, ( 0.0, 1.0, 1.0 ), 1 );
	
	distanceSq = DistanceSquared( zombie_eye, player_pos );
	
	//Check to see if the skeleton is super close OR super far
	if( distanceSq < ZM_MELEE_DIST_SQ )
	{
		self.players_visCache[entNum] = GetTime() + LAST_SEEN_LOSS_LATENCY;
		return true;
	}	
	else if( distanceSq > 1024*1024 )
	{
		return false;
	}	
	
	if( is_within_fov( zombie_eye, self.angles, player_pos, cos(60.0) ) )
	{
		trace = GroundTrace( zombie_eye, player_pos, false, undefined );
	
		if( trace["fraction"] < 1.0 )
		{
			return false;
		}
		else
		{
			//as_debug::debugLine( zombie_eye, player_pos, ( 0.0, 1.0, 1.0 ), 1 );
			self.players_visCache[entNum] = GetTime() + LAST_SEEN_LOSS_LATENCY;
			return true;
		}
	}
	return false;
}


function is_player_valid( player, checkIgnoreMeFlag, ignore_laststand_players )
{
	if( !IsDefined( player ) ) 
	{
		return false; 
	}

	if( !IsAlive( player ) )
	{
		return false; 
	} 

	if( !IsPlayer( player ) )
	{
		return false;
	}

	if( IsDefined(player.is_zombie) && player.is_zombie == true )
	{
		return false; 
	}

	if( player.sessionstate == "spectator" )
	{
		return false; 
	}

	if( player.sessionstate == "intermission" )
	{
		return false; 
	}
	
	if( IS_TRUE(self.intermission) )
	{
		return false;
	}
	
	if(!IS_TRUE(ignore_laststand_players))
	{
		if(  player laststand::player_is_in_laststand() )
		{
			return false; 
		}
	}

//T6.5todo	if ( player isnotarget() )
//T6.5todo	{
//T6.5todo		return false;
//T6.5todo	}
	
	//We only want to check this from the zombie attack script
	if( IS_TRUE(checkIgnoreMeFlag) && player.ignoreme )
	{
		return false;
	}
	
	//for additional level specific checks
	if( IsDefined( level.is_player_valid_override ) )
	{
		return [[ level.is_player_valid_override ]]( player );
	}
	
	return true; 
}

function get_closest_valid_player( origin, ignore_player )
{
	valid_player_found = false; 
	
	players = GetPlayers();	

	if( IsDefined( ignore_player ) )
	{
		//PI_CHANGE_BEGIN - 7/2/2009 JV Reenabling change 274916 (from DLC3)
		for(i = 0; i < ignore_player.size; i++ )
		{
			ArrayRemoveValue( players, ignore_player[i] );
		}
		//PI_CHANGE_END
	}

	// pre-cull any players that are in last stand 
	done = false; 
	while ( players.size && !done )
	{
		done = true;
		for(i = 0; i < players.size; i++ )
		{
			player = players[i];
			if( !is_player_valid( player, true ) )
			{
				ArrayRemoveValue( players, player ); 
				done = false;
				break;
			}
		}
	}
	
	if( players.size == 0 )
	{
		return undefined; 
	}
	
	while( !valid_player_found )
	{
		// find the closest player
		if( IsDefined( self.closest_player_override ) )
		{
			player = [[ self.closest_player_override ]]( origin, players );
		}
		else if( isdefined( level.closest_player_override ) )
		{
			player = [[ level.closest_player_override ]]( origin, players );
		}
		else
		{
			player = ArrayGetClosest( origin, players );
		} 

		if( !isdefined( player ) || players.size == 0 )
		{
			return undefined; 
		}
		
		// make sure they're not a zombie or in last stand
		if( !is_player_valid( player, true ) )
		{
			// unlikely to get here unless there is a wait in one of the closest player overrides
			ArrayRemoveValue( players, player ); 
			if( players.size == 0 )
			{
				return undefined;
			}
		
			continue;
		}
		
		return player; 
	}
}


function skeletonSetGoal(goal)
{
	if(isDefined(self.setGoalOverrideCB))
	{
		return [[self.setGoalOverrideCB]](goal);
	}
	else
	{
		self SetGoal(goal);
	}
}
function skeletonTargetService( behaviorTreeEntity)
{

	self endon( "death" );
	
	if ( IS_TRUE( behaviorTreeEntity.ignoreall ) )
	{
		return false;
	}
	if(isDefined(behaviorTreeEntity.enemy) && behaviorTreeEntity.enemy.team == behaviorTreeEntity.team )
		behaviorTreeEntity ClearEntityTarget();
	
	if(behaviorTreeEntity.team == "allies")
	{
		if(isDefined(behaviorTreeEntity.favoriteenemy))
		{
			behaviorTreeEntity skeletonSetGoal( behaviorTreeEntity.favoriteenemy.origin );	
			return true;			
		}
		if(isDefined(behaviorTreeEntity.enemy))
		{
			behaviorTreeEntity skeletonSetGoal( behaviorTreeEntity.enemy.origin );	
			return true;			
		}
		target = getClosestToMe(GetAITeamArray( "axis" ));
		if(isDefined(target))
		{
			behaviorTreeEntity skeletonSetGoal( target.origin );		
			return true;
		}
		else
		{
			behaviorTreeEntity skeletonSetGoal( behaviorTreeEntity.origin );		
			return false;
		}
	}
	else
	{
	
		player = get_closest_valid_player( behaviorTreeEntity.origin, behaviorTreeEntity.ignore_player );
		
		if( !isDefined( player ) )
		{
			if( IsDefined( behaviorTreeEntity.ignore_player )  )
			{
				if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
				{
					return;
				}
				behaviorTreeEntity.ignore_player = [];
			}
		
			behaviorTreeEntity skeletonSetGoal( behaviorTreeEntity.origin );		
			return false;
		}
		else
		{
			if ( IsDefined( player.last_valid_position ) )
			{
				canSEE = self skeletonCanSeePlayer( player );
			
				//Fill in influence map
				if( canSEE )
				{
					//self SetInfluenceAt( 5, player.last_valid_position, 1.0 );
					behaviorTreeEntity skeletonSetGoal( player.last_valid_position );		
					//as_debug::drawDebugCross( player.last_valid_position, 5.0, ( 0.0, 1.0, 0.0 ), 5 );
					return true;
				}
				else
				{
					influencePos = undefined;
					//try to find player - get hottest point on influence map and go there
					//influencePos = self GetBestInfluencepos( 5, 0.01, 1.0 );
					
					if( isdefined(influencePos) )
					{
						//as_debug::drawDebugCross( influencePos, 5.0, ( 1.0, 0.0, 0.0 ), 5 );
						
						//Are we close to our goal?
						if( DistanceSquared( influencePos, behaviorTreeEntity.origin ) > 32*32 )
						{
							behaviorTreeEntity skeletonSetGoal( influencePos );
							return true;
						}
						//self SetGoal( self.origin );	
						behaviorTreeEntity ClearPath();
						return false;
					}
					else
					{
						//self SetGoal( self.origin );		
						behaviorTreeEntity ClearPath();
						return false;
					}
				}
	
				/*attackPlayer = false;
				if( DistanceSquared( player.last_valid_position, self.origin ) < (512*512) )
				{
					if( canSEE )
					{
						behaviorTreeEntity SetGoal( player.last_valid_position );		
						attackPlayer = true;
					}
				}		
				
				if( !attackPlayer )
				{	
					//Get hottest point on influence map and go there
					influencePos = self GetBestInfluencepos( 5, 0.01, 1.0 );
					if( isdefined(influencePos) )
					{
						as_debug::drawDebugCross( influencePos, 5.0, ( 1.0, 0.0, 0.0 ), 5 );
						self SetGoal( influencePos );		
						return true;
					}
					else
					{
						self SetGoal( self.origin );		
						return false;
					}
				}*/
				return true;
			}
			else
			{
				behaviorTreeEntity skeletonSetGoal( behaviorTreeEntity.origin );
				return false;
			}
		}
	}
}

function isValidEnemy( enemy )
{
	if ( !isdefined( enemy ) )
	{
		return false;
	}
	
	return true;
}

function GetYaw(org)
{
	angles = VectorToAngles(org-self.origin);
	return angles[1];
}

// warning! returns (my yaw - yaw to enemy) instead of (yaw to enemy - my yaw)
function GetYawToEnemy()
{
	pos = undefined;
	if ( isValidEnemy( self.enemy ) )
	{
		pos = self.enemy.origin;
	}
	else
	{
		forward = AnglesToForward(self.angles);
		forward = VectorScale (forward, 150);
		pos = self.origin + forward;
	}
	
	yaw = self.angles[1] - GetYaw(pos);
	yaw = AngleClamp180( yaw );
	return yaw;
}

function skeletonShouldMeleeCondition( behaviorTreeEntity )
{
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}
	
	if( IS_TRUE( behaviorTreeEntity.stunned ) )
	{
		return false;
	}
	
	yaw = abs( getYawToEnemy() );
	if( ( yaw > ZM_MELEE_YAW ) )
	{
		return false;
	}
	if( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) < ZM_MELEE_DIST_SQ )
	{
		return true;
	}
	
	return false;
}

function skeletonDeathAction( behaviorTreeEntity )
{
	if ( IsDefined( behaviorTreeEntity.deathFunction ) )
	{
		behaviorTreeEntity [[ behaviorTreeEntity.deathFunction ]]();
	}
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function getClosestTo(origin,entArray)
{
	if (!isDefined(entArray) )
		return;

	if (entArray.size == 0 )
		return;

	return ArrayGetClosest( origin, entArray );
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function getClosestToMe(entArray)
{
	return getClosestTo(self.origin,entArray);
}