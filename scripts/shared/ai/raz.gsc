
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\archetype_mocomps_utility;
#using scripts\zm\_zm_behavior;	//@Temp - Should use callback functions to keep this shared
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\raz.gsh; 
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define PERK_JUGGERNOG	"specialty_armorvest"

#precache( "xmodel", RAZ_TORPEDO_MODEL );
#precache( "xmodel", RAZ_GUN_MODEL );
#precache( "xmodel", RAZ_GUN_CORE_MODEL );
#precache( "xmodel", RAZ_HELMET_MODEL );
#precache( "xmodel", RAZ_CHEST_ARMOR_MODEL );
#precache( "xmodel", RAZ_L_SHOULDER_ARMOR_MODEL );
#precache( "xmodel", RAZ_R_THIGH_ARMOR_MODEL );
#precache( "xmodel", RAZ_L_THIGH_ARMOR_MODEL );

#namespace RazBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitRazBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_RAZ, &ArchetypeRazBlackboardInit );

	// INIT RAZ ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_RAZ, &RazServerUtils::razSpawnSetup );
	
	clientfield::register( "scriptmover", RAZ_TORPEDO_DETONATION_CLIENTFIELD, VERSION_DLC3, 1, "int" );
	clientfield::register( "scriptmover", RAZ_TORPEDO_SELF_FX_CLIENTFIELD, VERSION_DLC3, 1, "int" );
	clientfield::register( "scriptmover", RAZ_TORPEDO_TRAIL_CLIENTFIELD, VERSION_DLC3, 1, "counter" );
	clientfield::register( "actor", RAZ_GUN_DETACH_CLIENTFIELD, VERSION_DLC3, 1, "int");
	clientfield::register( "actor", RAZ_GUN_WEAKPOINT_HIT_CLIENTFIELD, VERSION_DLC3, 1, "counter");
	clientfield::register( "actor", RAZ_DETACH_HELMET_CLIENTFIELD, VERSION_DLC3, 1, "int");
	clientfield::register( "actor", RAZ_DETACH_CHEST_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int");
	clientfield::register( "actor", RAZ_DETACH_L_SHOULDER_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int");
	clientfield::register( "actor", RAZ_DETACH_R_THIGH_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int");
	clientfield::register( "actor", RAZ_DETACH_L_THIGH_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int");
}

function private InitRazBehaviorsAndASM()
{
	// SERVICES
	BT_REGISTER_API( "razTargetService", 				&RazBehavior::razTargetService );
	BT_REGISTER_API( "razSprintService", 				&RazBehavior::razSprintService );

	// CONDITIONS
	BT_REGISTER_API( "razShouldMelee", 					&RazBehavior::razShouldMelee );
	BT_REGISTER_API( "razShouldShowPain", 				&RazBehavior::razShouldShowPain );
	BT_REGISTER_API( "razShouldShowSpecialPain",		&RazBehavior::razShouldShowSpecialPain );
	BT_REGISTER_API( "razShouldShowShieldPain",			&RazBehavior::razShouldShowShieldPain );
	BT_REGISTER_API( "razShouldShootGroundTorpedo", 	&RazBehavior::razShouldShootGroundTorpedo );
	BT_REGISTER_API( "razShouldGoBerserk", 				&RazBehavior::razShouldGoBerserk );
	BT_REGISTER_API( "razShouldTraverseWindow", 		&RazBehavior::razShouldTraverseWindow );

	// ACTIONS
	BT_REGISTER_API( "razStartMelee", 					&RazBehavior::razStartMelee );
	BT_REGISTER_API( "razFinishMelee", 					&RazBehavior::razFinishMelee );
	BT_REGISTER_API( "razFinishGroundTorpedo", 			&RazBehavior::razFinishGroundTorpedo );
	BT_REGISTER_API( "razGoneBerserk", 					&RazBehavior::razGoneBerserk );
	BT_REGISTER_API( "razStartTraverseWindow", 			&RazBehavior::razStartTraverseWindow );
	BT_REGISTER_API( "razFinishTraverseWindow", 		&RazBehavior::razFinishTraverseWindow );
	BT_REGISTER_API( "razTookPain", 					&RazBehavior::razTookPain );
	BT_REGISTER_API( "razStartDeath", 					&RazBehavior::razStartDeath );
	
	// FUNCTIONS

	// MOCOMPS
	
	// NOTETRACKS
	ASM_REGISTER_NOTETRACK_HANDLER( RAZ_TORPEDO_NOTETRACK, &RazBehavior::razNotetrackShootGroundTorpedo );
	
}

function private ArchetypeRazBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE RAZ BLACKBOARD
	BB_REGISTER_ATTRIBUTE( GIBBED_LIMBS,				"none",								undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,		LOCOMOTION_SPEED_WALK,				undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SHOULD_TURN,		SHOULD_NOT_TURN,					&BB_GetShouldTurn );
	BB_REGISTER_ATTRIBUTE( ZOMBIE_DAMAGEWEAPON_TYPE,	ZOMBIE_DAMAGEWEAPON_REGULAR,		undefined );
	BB_REGISTER_ATTRIBUTE( GIB_LOCATION,				RAZ_ARMOR_PAIN_NONE,				undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeRazOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private ArchetypeRazOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeRazBlackboardInit();
	
	if( IS_TRUE( entity.started_running ))
	{
		entity.invoke_sprint_time = undefined;
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
	}
	
	if(!IS_TRUE(entity.razHasGunAttached))
	{
		Blackboard::SetBlackBoardAttribute( entity, GIBBED_LIMBS, "right_arm" );
	}
}

function private BB_GetShouldTurn()
{
	if( IsDefined( self.should_turn ) && self.should_turn )
	{
		return SHOULD_TURN;
	}
	return SHOULD_NOT_TURN;
}

//----------------------------------------------------------------------------------------------------------------------------
// NOTETRACK HANDLERS
//----------------------------------------------------------------------------------------------------------------------------


//----------------------------------------------------------------------------------------------------------------------------
// BEHAVIOR TREE
//----------------------------------------------------------------------------------------------------------------------------

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
		behaviorTreeEntity.goalradius = 80; 
		
		behaviorTreeEntity.mocomp_barricade_offset = GetDvarInt("raz_node_origin_offset", -22);
		node_origin = node.origin + AnglesToForward(node.angles) * behaviorTreeEntity.mocomp_barricade_offset;
			       
		behaviorTreeEntity SetGoal( node_origin );

		// zombie spawned within the entrance
		if ( zm_behavior::zombieIsAtEntrance( behaviorTreeEntity ) )
		{
			behaviorTreeEntity.got_to_entrance = true;
		}

		return true;
	}
}

function shouldSkipTeardown( entity )
{
	if(IS_TRUE(entity.destroying_window))
	{
		return true;
	}
	
	if(!isdefined(entity.script_string) || entity.script_string == "find_flesh")
	{
		return true;
	}

	return false;
}

function private razGetNonDestroyedChuncks()
{
	chunks = undefined;
	
	if( isdefined(self.first_node) )
	{
		chunks = zm_utility::get_non_destroyed_chunks( self.first_node, self.first_node.barrier_chunks);
	}
	
	return chunks;
}

function private razDestroyWindow( entity, b_destroy_actual_pieces )
{
	if( !IS_TRUE(b_destroy_actual_pieces) )
	{
		entity.got_to_entrance = false;
		entity.destroying_window = true;
		entity ForceTeleport( entity.origin, entity.first_node.angles);
		
		chunks = entity razGetNonDestroyedChuncks();
		
		if( !isdefined(chunks) || chunks.size == 0 )
		{
			entity.jump_through_window = true;
			entity.jump_through_window_angle = entity.angles;
		}
		else
		{
			if( IS_TRUE(entity.razHasGunAttached) )
			{
				entity.destroy_window_by_torpedo = true;
			}
			else
			{
				entity.destroy_window_by_melee = true;
			}
		}
	}
	else
	{
		entity.jump_through_window = true;
		entity.jump_through_window_angle = entity.angles;
			
		if( isdefined(entity.first_node) )
		{
			chunks = entity razGetNonDestroyedChuncks();
			
			if ( isdefined( chunks ) )
			{
				for(i = 0; i < chunks.size; i++)
				{
					entity.first_node.zbarrier SetZBarrierPieceState( chunks[i], "opening", 0.2 );
				}
			}
		}
	}
}

function private razTargetService( entity )
{
	if ( IS_TRUE( entity.ignoreall ) )
	{
		return false;
	}
	
	if( IS_TRUE(entity.jump_through_window) )
	{
		return false;
	}
	
	if(!zm_behavior::InPlayableArea( entity) && !shouldSkipTeardown( entity) )
	{
		if(IS_TRUE(entity.got_to_entrance))
		{
			razDestroyWindow( entity );
		}
		else
		{
			if(zm_behavior::zombieEnteredPlayable(entity))
			{
				return false;
			}
			
			findNodesService( entity );
		}
		
		return false;
	}
	
	if ( level.zombie_poi_array.size > 0 )
	{
		zombie_poi = entity zm_utility::get_zombie_point_of_interest( entity.origin );
		
		if(isdefined(zombie_poi))
		{
			targetPos = GetClosestPointOnNavMesh( zombie_poi[0], RAZ_NAVMESH_RADIUS, RAZ_NAVMESH_BOUNDARY_DIST );
			
			entity.zombie_poi = zombie_poi;
			entity.enemyoverride = zombie_poi;
			
			if(isdefined(targetPos) )
			{
				self SetGoal( targetPos );
			}
			else
			{
				self SetGoal( zombie_poi[0] );
			}
			
			return;
		}
		else
		{
			entity.zombie_poi = undefined;
			entity.enemyoverride = undefined;
		}
	}
	else
	{
		entity.zombie_poi = undefined;
		entity.enemyoverride = undefined;
	}
	
	player = zombie_utility::get_closest_valid_player( self.origin, self.ignore_player, true );

	entity.favoriteenemy = player;

	if( !IsDefined( player ) || player IsNoTarget() )
	{
		if( IsDefined( self.ignore_player ) )
		{
			if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
			{
				return;
			}
			self.ignore_player = [];
		}

		self SetGoal( self.origin );	
		return false;
	}
	else
	{
		targetPos = GetClosestPointOnNavMesh( player.origin, RAZ_NAVMESH_RADIUS, RAZ_NAVMESH_BOUNDARY_DIST );
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

function private razSprintService( entity )
{
	if(IS_TRUE(entity.started_running))
	{
		return false;
	}
	
	if(!isdefined(entity.invoke_sprint_time))
	{
		return false;
	}
	
	if(GetTime() > entity.invoke_sprint_time)
	{
		entity.invoke_sprint_time = undefined;
		entity.started_running = true;
		entity.berserk = true;
		entity thread razSprintKnockdownZombies();
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
	}
}


//----------------------------------------------------------------------------------------------------------------------------------
// CONDITIONS
//----------------------------------------------------------------------------------------------------------------------------------
function razShouldMelee( entity )
{
	if(IS_TRUE(entity.destroy_window_by_melee))
	{
		return true;
	}
	
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if( DistanceSquared( entity.origin, entity.enemy.origin ) > RAZ_MELEE_DIST_SQ )
	{
		return false;
	}

	yaw = abs( zombie_utility::getYawToEnemy() );
	if( ( yaw > RAZ_MELEE_YAW ) )
	{
		return false;
	}
	
	return true;
}

function private razShouldShowPain( entity )
{
	if( IS_TRUE( entity.berserk ) && !IS_TRUE( entity.razHasGoneBerserk ) )
	{
		return false;
	}
	
	return true;
}

function private razShouldShowSpecialPain( entity )
{
	gib_location = Blackboard::GetBlackBoardAttribute( entity, GIB_LOCATION );
	
	if(gib_location == "right_arm")
	{
		return true;
	}
	
	if(!razShouldShowPain( entity ))
	{
		return false;
	}
	
	if( gib_location == "head" ||
		gib_location == "arms" ||
		gib_location == "right_leg" ||
		gib_location == "left_leg" ||
		gib_location == "left_arm"
	  )
	{
		return true;
	}
	
	return false;
}

function private razShouldShowShieldPain( entity )
{
	if( isdefined(entity.damageWeapon) && isdefined(entity.damageWeapon.name) )
	{
		return ( entity.damageWeapon.name == "dragonshield" );
	}
			
	return false;
}

function private razShouldGoBerserk( entity )
{
	if( IS_TRUE( entity.berserk ) && !IS_TRUE( entity.razHasGoneBerserk ))
	{
		return true;
	}
	
	return false;
}

function private razShouldTraverseWindow( entity )
{
	return IS_TRUE(entity.jump_through_window);
}

function private razGoneBerserk( entity )
{
	entity.razHasGoneBerserk = true;
}

function private razStartTraverseWindow( entity )
{
	//entity ClearPath();
	//entity ForceTeleport( entity.origin, entity.first_node.angles);
	
	raz_dir = AnglesToForward( entity.first_node.angles );
	raz_dir = VectorScale(raz_dir, 100);
	entity SetGoal( entity.origin + raz_dir );
}

function private razFinishTraverseWindow( entity )
{
	entity SetGoal( entity.origin );
	entity.jump_through_window = undefined;
	entity.first_node = undefined;
	
	if( !IS_TRUE(entity.completed_emerging_into_playable_area) )
	{
		entity zm_spawner::zombie_complete_emerging_into_playable_area();
	}
}

function private razTookPain( entity )
{
	//revert back to normal pain
	Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, RAZ_ARMOR_PAIN_NONE);
}

function private razStartDeath( entity )
{

	entity playsoundontag( "zmb_raz_death", "tag_eye" );
	
	if( IS_TRUE( entity.razHasGunAttached ) )
	{
		entity Clientfield::Set( RAZ_GUN_DETACH_CLIENTFIELD, 1 );
		entity.razHasGunAttached = false;
		
		entity detach( "c_zom_dlc3_raz_cannon_arm" );
		
		entity HidePart( RAZ_GUN_CORE_HIDE_TAG, "", true );
		entity HidePart( RAZ_GUN_HIDE_TAG );
		
		wait 0.05;
		
		if(isdefined( entity) )
		{
			entity razserverutils::razInvalidateGibbedArmor();
		}
	}
	
	if(isdefined( entity) )
	{
		if( IS_TRUE( entity.razHasHelmet ) )
		{
			entity Clientfield::set( RAZ_DETACH_HELMET_CLIENTFIELD, 1 );
			entity HidePart( RAZ_HELMET_TAG, "", true );
			entity.razHasHelmet = false;
		}
		
		if( IS_TRUE( entity.razHasChestArmor ) )
		{
			entity Clientfield::set( RAZ_DETACH_CHEST_ARMOR_CLIENTFIELD, 1 );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_1, "", true );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_2, "", true );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_3, "", true );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_4, "", true );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_5, "", true );
			entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_6, "", true );
			entity.razHasChestArmor = false;
		}
		
		if( IS_TRUE( entity.razHasLeftShoulderArmor ) )
		{
			entity Clientfield::set( RAZ_DETACH_L_SHOULDER_ARMOR_CLIENTFIELD, 1 );
			entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_1, "", true );
			entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_2, "", true );
			entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_3, "", true );
			entity.razHasLeftShoulderArmor = false;
		}
		
		if( IS_TRUE( entity.razHasLeftThighArmor ) )
		{
			entity Clientfield::set( RAZ_DETACH_L_THIGH_ARMOR_CLIENTFIELD, 1 );
			entity HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_1, "", true );
			entity HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_2, "", true );
			entity.razHasLeftThighArmor = false;
		}
		
		if( IS_TRUE( entity.razHasRightThighArmor ) )
		{
			entity Clientfield::set( RAZ_DETACH_R_THIGH_ARMOR_CLIENTFIELD, 1 );
			entity HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_1, "", true );
			entity HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_2, "", true );
			entity.razHasRightThighArmor = false;
		}
	}
}


function private razShouldShootGroundTorpedo( entity )
{
	if(IS_TRUE(entity.destroy_window_by_torpedo))
	{
		return true;
	}
	
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}
	
	if( !IS_TRUE( entity.razHasGunAttached ))
	{
		return false;
	}
	
	time = GetTime();
	if( time < entity.next_torpedo_time )
	{
		return false;
	}
	
	enemy_dist_sq = DistanceSquared( entity.origin, entity.enemy.origin );
	
	if(	!(enemy_dist_sq >= RAZ_MIN_TORPEDO_RANGE_SQ && enemy_dist_sq <= RAZ_MAX_TORPEDO_RANGE_SQ && entity razCanSeeTorpedoTarget( entity.enemy )) )
	{
		return false;
	}
	
	if( isdefined(entity.check_point_in_enabled_zone ) )
	{
	   	in_enabled_zone = [[entity.check_point_in_enabled_zone]](entity.origin);
	   	
	   	if(!in_enabled_zone)
	   	{
	   		return false;
	   	}
	}
	
	return true;
}

function private razCanSeeTorpedoTarget( enemy )
{
	entity = self; 
	origin_point = entity GetTagOrigin( RAZ_TORPEDO_ORIGIN_TAG );
	target_point = enemy.origin + (0,0,48);

	forward_vect = AnglesToForward( self.angles );
	vect_to_enemy = target_point - origin_point;
	
	if( VectorDot(forward_vect, vect_to_enemy) <= 0 ) //player behind RAZ
	{
		return false;
	}
	
	//Check if the enemy is inside my sight rect range
	right_vect = AnglesToRight( self.angles );
	
	projected_distance = VectorDot(vect_to_enemy, right_vect);
	

	/*
	/#
		sight_horiz_dist = GetDvarInt("raz_sight_horiz_dist", 50);
	
		line( origin_point, origin_point + VectorScale(right_vect, sight_horiz_dist), ( 1, 0, 0 ), 1, false, 100 );
		line( origin_point, origin_point + VectorScale(right_vect, -sight_horiz_dist), ( 1, 0, 0 ), 1, false, 100 );
		
		line( target_point, origin_point + VectorScale(right_vect, projected_distance), ( 0, 1, 0 ), 1, false, 100 );
		
		Sphere( origin_point + VectorScale(right_vect, projected_distance), 10, ( 0, 0, 1 ), 1, false,100 );
	
	#/
	*/
	
	if(abs(projected_distance) > RAZ_TORPEDO_SIGHT_HORIZ_RANGE)
	{
		return false;
	}

	trace = BulletTrace( origin_point, target_point, false, self );
	
	if( trace[ "position" ] === target_point )
	{
		return true;
	}
	
	return false;
}


//----------------------------------------------------------------------------------------------------------------------------------
// ACTIONS
//----------------------------------------------------------------------------------------------------------------------------------

function private razStartMelee( entity )
{
	if( IS_TRUE(entity.destroy_window_by_melee) )
	{
		wait 1.1;
		razDestroyWindow( entity, true);
	}
}

function private razFinishMelee( entity )
{
	entity.destroy_window_by_melee = undefined;
}

function private razFinishGroundTorpedo( entity )
{
	entity.destroy_window_by_torpedo = undefined;
	
	entity.next_torpedo_time = GetTime() + RAZ_TORPEDO_COOLDOWN;
}

function private razNotetrackShootGroundTorpedo( entity )
{
	if( !isdefined( entity.enemy) && !IS_TRUE(entity.destroy_window_by_torpedo) )
	{
		/#println( "RAZ does not have an enemy to shoot Ground Torpedo at" );#/
		return;
	}
	
	if(IS_TRUE(entity.destroy_window_by_torpedo))
	{
		razDestroyWindow( entity, true);
		
		raz_dir = AnglesToForward( entity.first_node.angles );
		entity razShootGroundTorpedo( entity.first_node, VectorScale(raz_dir, 100) + (0 , 0, 48) );
	}
	else
	{
		entity razShootGroundTorpedo( entity.enemy, (0, 0, 48) );
	}
		
	entity.next_torpedo_time = GetTime() + RAZ_TORPEDO_COOLDOWN;
}

//----------------------------------------------------------------------------------------------------------------------------------
// Ground Torpedo
//----------------------------------------------------------------------------------------------------------------------------------
function private razTorpedoLaunchDirection( forward_dir, torpedo_pos, torpedo_target_pos, max_angle)
{
	vec_to_enemy = torpedo_target_pos - torpedo_pos;
	vec_to_enemy_normal = VectorNormalize(vec_to_enemy);
	
	angle_to_enemy = VectorDot(forward_dir, vec_to_enemy_normal);
	
	if( angle_to_enemy >= max_angle )
	{
		return vec_to_enemy_normal;
	}
	
	//enemy outside our range, let's get the vector near the age of our maximum spectrum facing the enemy
	//Algorithm is to get a perpendicular vector to the forward_dir on the to enemy plane, then use te angle to get the vector on the border
	
	plane_normal = VectorCross(forward_dir, vec_to_enemy_normal);
	perpendicular_normal = VectorCross(plane_normal, forward_dir);
	
	torpedo_dir = forward_dir * cos(max_angle) + perpendicular_normal * sin(max_angle);
	
	return torpedo_dir;
}

function private razShootGroundTorpedo( torpedo_target, torpedo_target_offset )
{
	// self is the RAZ shooting the torpedo
	torpedo_pos = self GetTagOrigin( RAZ_TORPEDO_ORIGIN_TAG );
	torpedo_target_pos = torpedo_target.origin + torpedo_target_offset;
	torpedo = Spawn( "script_model", torpedo_pos ); //if this number changes, will need to update razCanSeeTorpedoTarget function to account for it
	torpedo SetModel( RAZ_TORPEDO_MODEL );
	torpedo clientfield::set( RAZ_TORPEDO_SELF_FX_CLIENTFIELD, 1 );
	torpedo.torpedo_trail_iterations = 0;
	torpedo.raz_torpedo_owner = self; //used for determining damage so RAZ is immune to own torpedoes
	
	//Torpedo starting direction
	vec_to_enemy = razTorpedoLaunchDirection(AnglesToForward(self.angles), torpedo_pos, torpedo_target_pos, RAZ_TORPEDO_MAX_LAUNCH_ANGLE);
	angles_to_enemy = VectorToAngles( vec_to_enemy );
	torpedo.angles = angles_to_enemy;
	normal_vector = VectorNormalize( vec_to_enemy );
	torpedo.torpedo_old_normal_vector = normal_vector;
	torpedo.knockdown_iterations = 0;
		
	iteration_move_distance = RAZ_TORPEDO_VELOCITY *  RAZ_TORPEDO_MOVE_INTERVAL_TIME;
	max_trail_iterations = Int( RAZ_MAX_TORPEDO_RANGE / iteration_move_distance );
	
	torpedo thread razTorpedoKnockdownZombies( torpedo_target );
	torpedo thread razTorpedoDetonateIfCloseToTarget( torpedo_target, torpedo_target_offset );
	
	while( isDefined( torpedo ))
	{
		if( !isdefined( torpedo_target) || torpedo.torpedo_trail_iterations >= max_trail_iterations )
		{
			torpedo thread razTorpedoDetonate( 0 );
		}	
		else
		{
			torpedo razTorpedoMoveToTarget( torpedo_target );
//			torpedo razTorpedoPlayTrailEffect();
			torpedo.torpedo_trail_iterations += 1;
		}
		
		wait RAZ_TORPEDO_MOVE_INTERVAL_TIME;	
	}
}

function private razTorpedoDetonateIfCloseToTarget( torpedo_target, torpedo_target_offset )
{
	self endon( "death" );
	self endon( "detonated" );
	torpedo = self;
	
	While( isdefined( torpedo) && isdefined( torpedo_target ))
	{
		torpedo_target_pos = torpedo_target.origin + torpedo_target_offset;
		
		if( DistanceSquared( torpedo.origin, torpedo_target_pos ) <= RAZ_TORPEDO_DETONATION_DIST_SQ )
		{
			torpedo thread razTorpedoDetonate( 0 );
		}
			
			
		WAIT_SERVER_FRAME;	
	}
}

function private razTorpedoMoveToTarget( torpedo_target )
{
	self endon( "death" );
	self endon( "detonated" );
	
	if( !isDefined( self.torpedo_max_yaw_cos ) )
	{
		torpedo_yaw_per_interval = RAZ_TORPEDO_MAX_YAW_PER_SECOND * RAZ_TORPEDO_MOVE_INTERVAL_TIME;
		self.torpedo_max_yaw_cos = Cos( torpedo_yaw_per_interval );
	}
	
	if( isDefined( self.torpedo_old_normal_vector ) )
	{
		torpedo_target_point = torpedo_target.origin + (0,0, 48); //if this number changes, will need to update razCanSeeTorpedoTarget function to account for it
		if( isPlayer( torpedo_target ))
		{
			torpedo_target_point = torpedo_target GetPlayerCameraPos();
		}
		vector_to_target = torpedo_target_point - self.origin;
		normal_vector = VectorNormalize( vector_to_target );
	
		flat_mapped_normal_vector = VectorNormalize( (normal_vector[0], normal_vector[1], 0) );
		flat_mapped_old_normal_vector = VectorNormalize( (self.torpedo_old_normal_vector[0], self.torpedo_old_normal_vector[1], 0) );
		dot = VectorDot( flat_mapped_normal_vector, flat_mapped_old_normal_vector );
		
		if( dot >= 1 )
		{
			dot = 1;
		}
		else if( dot <= -1 )
		{
			dot = -1;
		}
		
		if( dot < self.torpedo_max_yaw_cos )
		{
			new_vector = normal_vector - self.torpedo_old_normal_vector;
			angle_between_vectors = Acos( dot );
			
			if( !isDefined( angle_between_vectors ))// in case dot product is -1, Acos returns undefined
			{
				angle_between_vectors = 180;
			}

			if(angle_between_vectors == 0)
			{
				angle_between_vectors = 0.0001;
			}
			
			
			max_angle_per_interval = RAZ_TORPEDO_MAX_YAW_PER_SECOND * RAZ_TORPEDO_MOVE_INTERVAL_TIME;
			ratio = max_angle_per_interval / angle_between_vectors;
			
			if(ratio > 1)
			{
				ratio = 1;
			}
			
			new_vector = new_vector * ratio;
			new_vector = new_vector + self.torpedo_old_normal_vector;
			normal_vector = VectorNormalize( new_vector );		
		}
		else
		{
			normal_vector = self.torpedo_old_normal_vector;
		}
	}
	
	move_distance = RAZ_TORPEDO_VELOCITY *  RAZ_TORPEDO_MOVE_INTERVAL_TIME;
	move_vector = move_distance * normal_vector;
	
	move_to_point = self.origin  + move_vector;
//	terrain_check_offset_high = (0,0,RAZ_TORPEDO_TERRAIN_CHECK_OFFSET - RAZ_TORPEDO_GROUND_OFFSET);
//	terrain_check_offset_low = (0,0,RAZ_TORPEDO_TERRAIN_CHECK_OFFSET + RAZ_TORPEDO_GROUND_OFFSET);
//	trace = BulletTrace( move_to_point + terrain_check_offset_high, move_to_point - terrain_check_offset_low, false, self );
//	
//	if( trace[ "surfacetype" ] !== "none" )
//	{
//		move_to_point = trace[ "position" ] + (0,0,RAZ_TORPEDO_GROUND_OFFSET );
//	}
	
	trace = BulletTrace( self.origin, move_to_point, false, self );
	if( trace[ "surfacetype" ] !== "none" )
	{
		detonate_point = trace[ "position" ];
		
		dist_sq = DistanceSquared( detonate_point, self.origin );
		move_dist_sq = move_distance * move_distance;
		ratio = dist_sq / move_dist_sq;
		delay = ratio * RAZ_TORPEDO_MOVE_INTERVAL_TIME;
		
		self thread razTorpedoDetonate( delay );
	}		
	
	
	self.torpedo_old_normal_vector = normal_vector;
	
	self MoveTo( move_to_point, RAZ_TORPEDO_MOVE_INTERVAL_TIME );
}

function private razTorpedoPlayTrailEffect()
{
	self endon( "death" );
	self endon( "detonated" );
	
	surface_check_offset = RAZ_TORPEDO_GROUND_OFFSET + 10;
	if( self.torpedo_trail_iterations >= 1 )
	{
		trace = BulletTrace( self.origin + (0,0,10), self.origin - (0,0,surface_check_offset), false, self );
		if( trace[ "surfacetype" ] !== "none" )
		{
			self clientfield::increment( RAZ_TORPEDO_TRAIL_CLIENTFIELD, 1 );
		}
	}
}

function private razKnockdownZombies( target )
{
	self endon( "death" );
	
	While( isDefined( self ))
	{
		if(isdefined(target)) //Torpedo
		{
			if( IsPlayer( target ) )
			{
				torpedo_target_position = target.origin + ( 0,0,48 );
			}
			else 
			{
				torpedo_target_position = target.origin;
			}
			
			prediction_time = 0.3;
			
			// gradually increase prediction time to catch zombies right in front of raz in knockdown from torpedo
			if( isDefined( self.knockdown_iterations ) && self.knockdown_iterations < 3 )
			{
				if( self.knockdown_iterations == 0 )
				{
					prediction_time = 0.075;
				}
				
				if( self.knockdown_iterations == 1 )
				{
					prediction_time = 0.15;
				}
				
				if( self.knockdown_iterations == 2 )
				{
					prediction_time = 0.225;
				}
			}
			
			self.knockdown_iterations += 1;
			 
			vector_to_target = torpedo_target_position - self.origin;
			normal_vector = VectorNormalize( vector_to_target );
			move_distance = RAZ_TORPEDO_VELOCITY *  prediction_time;
			move_vector = move_distance * normal_vector;
			
			self.angles = VectorToAngles( move_vector );
		}
		else //Raz
		{
			velocity = self GetVelocity();
			velocityMag = Length(velocity);
			
			b_sprinting = velocityMag >= 40;
			
			if(b_sprinting)
			{
				predict_time = 0.2;
				move_vector = velocity * predict_time;
			}
		}
		

		if(!isdefined(b_sprinting) || b_sprinting == true)
		{
			predicted_pos = self.origin + move_vector;
			
//			/#
//				thread util::debug_sphere(predicted_pos,48,(0,0,1),0.5,200);
//			#/
			
			a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
			a_filtered_zombies = array::filter( a_zombies, false, &razZombieEligibleForKnockdown, self, predicted_pos );
		}
		else
		{
			wait 0.2;
			continue;
		}
		
		if( a_filtered_zombies.size > 0 )
		{
				

			foreach( zombie in a_filtered_zombies )
			{
				zombie.knockdown = true;
				zombie.knockdown_type = KNOCKDOWN_SHOVED;
				zombie_to_target = self.origin - zombie.origin;
				zombie_to_target_2d = VectorNormalize( ( zombie_to_target[0], zombie_to_target[1], 0 ) );
				
				zombie_forward = AnglesToForward( zombie.angles );
				zombie_forward_2d = VectorNormalize( ( zombie_forward[0], zombie_forward[1], 0 ) );
				
				zombie_right = AnglesToRight( zombie.angles );
				zombie_right_2d = VectorNormalize( ( zombie_right[0], zombie_right[1], 0 ) );
				
				dot = VectorDot( zombie_to_target_2d, zombie_forward_2d );
				
				if( dot >= 0.5 )
				{
					zombie.knockdown_direction = "front";
					zombie.getup_direction = GETUP_BACK;
				}
				else if ( dot < 0.5 && dot > -0.5 )
				{
					dot = VectorDot( zombie_to_target_2d, zombie_right_2d );
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
		}
		wait 0.2;	
	}
}

function private razTorpedoKnockdownZombies( torpedo_target )
{
	self endon( "death" );
	self endon( "detonated" );
	
	razKnockdownZombies( torpedo_target );
}

function private razSprintKnockdownZombies()
{
	self endon( "death" );
	
	self notify("razSprintKnockdownZombies");
	self endon("razSprintKnockdownZombies");
	
	razKnockdownZombies();
}


function private razTorpedoDetonate( delay )
{
	self notify( "detonated" );
	
	torpedo = self;
	raz_torpedo_owner = self.raz_torpedo_owner;
	
	if( delay > 0 )
	{
		wait delay;
	}
	
	if( isdefined( self ) )
	{
		self razApplyPlayerDetonationEffects();
		
		w_weapon = GetWeapon( "none" );
		explosion_point = torpedo.origin;
		torpedo clientfield::set( RAZ_TORPEDO_DETONATION_CLIENTFIELD, 1);
		RadiusDamage( explosion_point + ( 0,0,18 ), RAZ_TORPEDO_BLAST_RADIUS, RAZ_TORPEDO_BLAST_INNER_DAMAGE, RAZ_TORPEDO_BLAST_OUTER_DAMAGE, self.raz_torpedo_owner, "MOD_UNKNOWN", w_weapon );
		razApplyTorpedoDetonationPushToPlayers( explosion_point + ( 0,0,18 ) );
		self clientfield::set( RAZ_TORPEDO_SELF_FX_CLIENTFIELD, 0 );
		wait 0.05;
		
		
		if( isdefined( raz_torpedo_owner ) && IS_TRUE( level.b_raz_ignore_mangler_cooldown ))
		{
			raz_torpedo_owner.next_torpedo_time = GetTime();
		}

		if ( isdefined( self ) )
		{
			self Delete();
		}
	}
	
}

function private razApplyTorpedoDetonationPushToPlayers( torpedo_origin )
{
	players = GetPlayers();

	v_length = SQR(100);
	
	for( i = 0; i < players.size; i++ )
	{
		player = players[i];
		
		if( !IsAlive( player ) )
		{
			continue; 
		} 
		
		if( player.sessionstate == "spectator" )
		{
			continue;
		}
	
		if( player.sessionstate == "intermission" )
		{
			continue;
		}
		
		if( IS_TRUE( player.ignoreme ) )
		{
			continue;
		}
	
		if( player IsNoTarget() )
		{
			continue;
		}
		
		if ( !player IsOnGround() )
		{
			continue;
		}
		
	
		n_distance = Distance2DSquared( torpedo_origin, player.origin );
		
		if( n_distance < 0.01 )
		{
			continue;
		}
		
		if( n_distance < v_length)
		{
			v_dir = player.origin - torpedo_origin;
			v_dir = (v_dir[0], v_dir[1], 0.1);
			v_dir = VectorNormalize( v_dir );
			
			n_push_strength = GetDvarInt("raz_n_push_strength", 500);
			n_push_strength = 200 + RandomInt( n_push_strength - 200 );
			
			v_player_velocity = player GetVelocity();
			player SetVelocity( v_player_velocity + (v_dir * n_push_strength) );
		}
	}
}

function private razApplyPlayerDetonationEffects()
{
	Earthquake( 0.4, 0.8, self.origin, 300 );
	
	for(i = 0;i < level.activeplayers.size; i++)
	{
		distanceSq = DistanceSquared(self.origin, level.activeplayers[i].origin + (0, 0, 48));
		
		if(distanceSq > RAZ_TORPEDO_DETONATION_DIST_SQ)
		{
			continue;
		}

		//Apply effects
		level.activeplayers[i] playrumbleonentity("damage_heavy");
	}
}
	
function private razZombieEligibleForKnockdown( zombie, target, predicted_pos )
{
	if( zombie.knockdown === true )
	{
		return false;
	}
	
	if ( GibServerUtils::IsGibbed( zombie, GIB_LEGS_BOTH_LEGS_FLAG ) )
	{
		return false;
	}
	
	knockdown_dist = 48;
	check_pos = zombie.origin;
	
	if( !isActor( target ))
	{
		check_pos = zombie GetCentroid();
		knockdown_dist = 64;
	}
	
	knockdown_dist_sq = knockdown_dist * knockdown_dist;	
	dist_sq = DistanceSquared( predicted_pos, check_pos );
	
	if( dist_sq > knockdown_dist_sq )
	{
		return false;
	}
	
	origin = target.origin;

	facing_vec = AnglesToForward( target.angles );
	enemy_vec = zombie.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < 0 )
	{
		return false;
	}
	
	return true;
	
}



#namespace razServerUtils;

function private razSpawnSetup()
{
	self.invoke_sprint_time = GetTime() + RAZ_INVOKE_SPRINT_TIME;
	self.next_torpedo_time = GetTime();
	self.razHasGunAttached = true;
	self.razHasHelmet = true;
	self.razHasLeftShoulderArmor = true;
	self.razHasChestArmor = true;
	self.razHasRightThighArmor = true;
	self.razHasLeftThighArmor = true;
	self.razHasGoneBerserk = false;
	if( !isDefined( level.razGunHealth ) )
	{
		level.razGunHealth = RAZ_GUN_HEALTH_DEFAULT;
	}
	if( !isDefined( level.razMaxHealth ) )
	{
		level.razMaxHealth = self.health;
	}
	if( !isDefined( level.razHelmetHealth ))
	{
		level.razHelmetHealth = RAZ_DEFAULT_HELMET_HEALTH;
	}
	if( !isDefined( level.razLeftShoulderArmorHealth ))
	{
		level.razLeftShoulderArmorHealth = RAZ_DEFAULT_L_SHOULDER_ARMOR_HEALTH;
	}
	if( !isDefined( level.razChestArmorHealth ))
	{
		level.razChestArmorHealth = RAZ_DEFAULT_CHEST_ARMOR_HEALTH;
	}
	if( !isDefined( level.razThighArmorHealth ))
	{
		level.razThighArmorHealth = RAZ_DEFAULT_THIGH_ARMOR_HEALTH;
	}
	self.maxHealth = level.razMaxHealth;
	self.razGunHealth = level.razGunHealth;
	self.razHelmetHealth = level.razHelmetHealth;
	self.razChestArmorHealth = level.razChestArmorHealth;
	self.razRightThighHealth = level.razThighArmorHealth;
	self.razLeftThighHealth = level.razThighArmorHealth;
	self.razLeftShoulderArmorHealth = level.razLeftShoulderArmorHealth;
	
	self.canBeTargetedByTurnedZombies= true;
	self.no_widows_wine = true;
	self.flame_fx_timeout = 3;

	AiUtility::AddAiOverrideDamageCallback( self, &razServerUtils::razDamageCallback );
	
	self thread razGibZombiesOnMelee();

}

function private razGibZombiesOnMelee()
{
	self endon("death");
	self endon("disconnect");
	
	while(true)
	{
		self waittill("melee_fire");
		a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
		
		foreach( zombie in a_zombies )
		{
			if(IS_TRUE(zombie.no_gib))
				continue;
			
			heightDiff = abs(zombie.origin[2] - self.origin[2]);
			
			if(heightDiff > 50)
				continue;
			
			distance2DSq = Distance2DSquared(zombie.origin, self.origin);
			
			if( distance2DSq > SQR(90) )
				continue;
			
			raz_forward = AnglesToForward( self.angles );
			vect_to_enemy = zombie.origin - self.origin;
			
			if( VectorDot(raz_forward, vect_to_enemy) <= 0 ) //zombie behind RAZ
			{
				continue;
			}
			
			//Check if the zombie is inside my sight rect range
			right_vect = AnglesToRight( self.angles );
			
			projected_distance = VectorDot(vect_to_enemy, right_vect);
			
			if(abs(projected_distance) > 35)
			{
				continue;
			}
			
			b_gibbed = false;
			
			val = randomint( 100 );
			if( val > 50 )
			{
				zombie zombie_utility::zombie_head_gib();
				b_gibbed = true;
			}
	
			val = randomint( 100 );
			if( val > 50 )
			{
				if ( !GibServerUtils::IsGibbed( zombie, GIB_TORSO_LEFT_ARM_FLAG ) )
				{
					GibServerUtils::GibRightArm( zombie );
					b_gibbed = true;
				}
			}
			
			val = randomint( 100 );
			if( val > 50 )
			{
				if ( !GibServerUtils::IsGibbed( zombie, GIB_TORSO_RIGHT_ARM_FLAG ) )
				{
					GibServerUtils::GibLeftArm( zombie );
					b_gibbed = true;
				}
			}
			
			if( !IS_TRUE(b_gibbed) )
			{
				if ( !GibServerUtils::IsGibbed( zombie, GIB_TORSO_LEFT_ARM_FLAG ) )
				{
					GibServerUtils::GibRightArm( zombie );
				}
				else if ( !GibServerUtils::IsGibbed( zombie, GIB_TORSO_RIGHT_ARM_FLAG ) )
				{
					GibServerUtils::GibLeftArm( zombie );
				}
				else
				{
					zombie zombie_utility::zombie_head_gib();
				}
			}
		}
	}
}

function private razInvalidateGibbedArmor()
{
	if( !IS_TRUE( self.razHasGunAttached ))
	{
		self HidePart( RAZ_GUN_CORE_HIDE_TAG, "", true );
		self HidePart( RAZ_GUN_HIDE_TAG );
	}
	
	if( !IS_TRUE( self.razHasChestArmor ))
	{
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_1, "", true );
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_2, "", true );
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_3, "", true );
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_4, "", true );
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_5, "", true );
		self HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_6, "", true );
	}
	
	if( !IS_TRUE( self.razHasLeftShoulderArmor ))
	{
		self HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_1, "", true );
		self HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_2, "", true );
		self HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_3, "", true );
	}
	
	if( !IS_TRUE( self.razHasRightThighArmor ))
	{
		self HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_1, "", true );
		self HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_2, "", true );
	}
	
	if( !IS_TRUE( self.razHasLeftThighArmor ))
	{
		self HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_1, "", true );
		self HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_2, "", true );
	}

	if( !IS_TRUE( self.razHasHelmet ) )
	{
		self HidePart( RAZ_HELMET_TAG, "", true );
	}
}

function private razDamageCallback( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	
	entity.last_damage_hit_armor = false;
	
	if( isDefined( attacker ) && attacker == entity )
	{
		return 0;
	}
	
	if( mod !== "MOD_PROJECTILE_SPLASH" )
	{
		if( IS_TRUE( entity.razHasGunAttached ))
		{
			b_hit_shoulder_weakpoint = raz_check_for_location_hit( entity, hitloc, point, "right_arm_upper", RAZ_GUN_TAG_HIT_RADIUS_SQ, RAZ_R_SHOULDER_WEAKSPOT_TAG );
	
			if ( IS_TRUE( b_hit_shoulder_weakpoint ))
			{
				entity razTrackGunDamage( damage, attacker ); // PORTIZ: passing attacker to award credit for RAZ arm destroying challenge
				
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				
				if( !IS_TRUE(entity.razHasGunAttached)) //if the damage pops the gun off, either kill RAZ, or reduce him to a percentage of his max health
				{
					post_hit_health = entity.health - damage;
					gun_detach_damage = entity.maxHealth * RAZ_GUN_DETACH_DAMAGE_HEALTH_PERCENT;
					post_hit_health_percent = ( post_hit_health - gun_detach_damage ) / entity.maxHealth;
					
					// If his health is greater than the max health post-detach, reduce health to max health post-detach
					if( post_hit_health_percent > RAZ_GUN_DETACH_HEALTH_PERCENT_MAX )
					{
						return( entity.health - ( entity.maxHealth * RAZ_GUN_DETACH_HEALTH_PERCENT_MAX ) );
					}
					else
					{
						return gun_detach_damage;
					}
				}
				
				return damage;
			}
		}
		
		if( IS_TRUE( entity.razHasChestArmor ))
		{
			b_hit_chest = raz_check_for_location_hit( entity, hitloc, point, "torso_upper", RAZ_CHEST_ARMOR_HIT_RADIUS_SQ, RAZ_CHEST_ARMOR_HIT_TAG );
			
			if( b_hit_chest || hitloc === "torso_lower" || hitloc === "torso_mid" )
			{
				entity razTrackChestArmorDamage( damage );
				entity.last_damage_hit_armor = true;
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				return damage;
			}
		}
		
		if( IS_TRUE( entity.razHasLeftShoulderArmor ))
		{
			b_hit_l_shoulder_armor = raz_check_for_location_hit( entity, hitloc, point, "left_arm_upper", RAZ_L_SHOUDLER_ARMOR_HIT_RADIUS_SQ, RAZ_L_SHOULDER_ARMOR_HIT_TAG );
			
			if( b_hit_l_shoulder_armor )
			{
				entity razTrackLeftShoulderArmorDamage( damage );
				entity.last_damage_hit_armor = true;
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				return damage;
			}
		}
		
		if( IS_TRUE( entity.razHasRightThighArmor ))
		{
			b_hit_r_thigh_armor = raz_check_for_location_hit( entity, hitloc, point, "right_leg_upper", RAZ_R_THIGH_ARMOR_HIT_RADIUS_SQ, RAZ_R_THIGH_ARMOR_HIT_TAG );
			
			if( b_hit_r_thigh_armor )
			{
				entity razTrackRightThighArmorDamage( damage );
				entity.last_damage_hit_armor = true;
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				return damage;
			}
		}
		
		if( IS_TRUE( entity.razHasLeftThighArmor ))
		{
			b_hit_l_thigh_armor = raz_check_for_location_hit( entity, hitloc, point, "left_leg_upper", RAZ_L_THIGH_ARMOR_HIT_RADIUS_SQ, RAZ_L_THIGH_ARMOR_HIT_TAG );
			
			if( b_hit_l_thigh_armor )
			{
				entity razTrackLeftThighArmorDamage( damage );
				entity.last_damage_hit_armor = true;
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				return damage;
			}
		}			
		

		if( IS_TRUE( entity.razHasHelmet ) )
		{
			b_hit_head = raz_check_for_location_hit( entity, hitloc, point, "head", RAZ_HELMET_HIT_RADIUS_SQ, RAZ_HELMET_HIT_TAG );
			
			if( b_hit_head || hitloc === "neck" || hitloc === "helmet" )
			{
				entity razTrackHelmetDamage( damage, attacker ); // PORTIZ: passing attacker to award credit for RAZ mask destroying challenge
				entity.last_damage_hit_armor = true;
				damage = damage * RAZ_ARMOR_DAMAGE_MODIFIER;
				return damage;
			}
		}
		
	}
	
	return damage;
}

function private raz_check_for_location_hit( entity, hitloc, point, location, hit_radius_sq, tag )
{
	b_hit_location = false;
	
	if ( isDefined( hitloc) && hitloc != "none" )
    {
		if ( hitLoc == location )
		{
			b_hit_location = true;
		}
	}
	else
	{
		dist_sq = DistanceSquared( point, entity GetTagOrigin( tag ));
	
		if( dist_sq <= hit_radius_sq )
		{
			b_hit_location = true;
		}
	}
	
	return b_hit_location;
}

function private razTrackGunDamage( damage, attacker )
{
	entity = self;
	entity.razGunHealth = entity.razGunHealth - damage;
	
	post_hit_health = entity.health - damage;
	post_hit_health_percent = post_hit_health / entity.maxHealth;
	
	if( entity.razGunHealth > 0 )
	{
		entity Clientfield::Increment( RAZ_GUN_WEAKPOINT_HIT_CLIENTFIELD, 1 );
	}
	
	if( entity.razGunHealth <= 0 )
	{
		entity.razGunHealth = 0;
		entity Clientfield::Set( RAZ_GUN_DETACH_CLIENTFIELD, 1 );
		entity.razHasGunAttached = false;
		entity.invoke_sprint_time = undefined;
		entity.started_running = true;
		entity thread razbehavior::razSprintKnockdownZombies();
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
		Blackboard::SetBlackBoardAttribute( entity, GIBBED_LIMBS, "right_arm" );
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "right_arm");
		
		explosion_max_damage = RAZ_GUN_DETACH_EXPLOSION_DAMAGE_MAX * entity.maxHealth;
		explosion_min_damage = RAZ_GUN_DETACH_EXPLOSION_DAMAGE_MIN * entity.maxHealth;
		
		weapon = GetWeapon( "raz_melee" );
		
		RadiusDamage( self.origin + (0,0,18), RAZ_GUN_DETACH_EXPLOSION_RADIUS, explosion_max_damage, explosion_min_damage, entity, "MOD_PROJECTILE_SPLASH", weapon );
		
		self detach( "c_zom_dlc3_raz_cannon_arm" );
		
		self HidePart( RAZ_GUN_CORE_HIDE_TAG, "", true );
		self HidePart( RAZ_GUN_HIDE_TAG );
		
		razInvalidateGibbedArmor();
		
		level notify( "raz_arm_detach", attacker ); // send notify to be caught by challenge system
		self notify( "raz_arm_detach", attacker ); // send notify to be caught by vo/general systems
	}
}

function private razTrackHelmetDamage( damage, attacker )
{
	entity = self;
	
	entity.razHelmetHealth = entity.razHelmetHealth - damage;
	if( entity.razHelmetHealth <= 0 )
	{
		entity Clientfield::set( RAZ_DETACH_HELMET_CLIENTFIELD, 1 );
		entity HidePart( RAZ_HELMET_TAG, "", true );
		entity.razHasHelmet = false;
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "head");
		
		level notify( "raz_mask_destroyed", attacker ); //notify for minor EE and challenge
	}
}

function private razTrackChestArmorDamage( damage )
{
	entity = self;
	
	entity.razChestArmorHealth = entity.razChestArmorHealth - damage;
	if( entity.razChestArmorHealth <= 0 )
	{
		entity Clientfield::set( RAZ_DETACH_CHEST_ARMOR_CLIENTFIELD, 1 );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_1, "", true );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_2, "", true );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_3, "", true );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_4, "", true );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_5, "", true );
		entity HidePart( RAZ_CHEST_ARMOR_HIDE_TAG_6, "", true );
		entity.razHasChestArmor = false;
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "arms"); //This will trigger the Chest pain
	}
}

function private razTrackLeftShoulderArmorDamage(  damage )
{
	entity = self;
	
	entity.razLeftShoulderArmorHealth = entity.razLeftShoulderArmorHealth - damage;
	if( entity.razLeftShoulderArmorHealth <= 0 )
	{
		entity Clientfield::set( RAZ_DETACH_L_SHOULDER_ARMOR_CLIENTFIELD, 1 );
		entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_1, "", true );
		entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_2, "", true );
		entity HidePart( RAZ_L_SHOULDER_ARMOR_HIDE_TAG_3, "", true );
		entity.razHasLeftShoulderArmor = false;
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "left_arm");
	}
}

function private razTrackLeftThighArmorDamage(  damage )
{
	entity = self;
	
	entity.razLeftThighHealth = entity.razLeftThighHealth - damage;
	if( entity.razLeftThighHealth <= 0 )
	{
		entity Clientfield::set( RAZ_DETACH_L_THIGH_ARMOR_CLIENTFIELD, 1 );
		entity HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_1, "", true );
		entity HidePart( RAZ_L_THIGH_ARMOR_HIDE_TAG_2, "", true );
		entity.razHasLeftThighArmor = false;
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "left_leg");
	}
}

function private razTrackRightThighArmorDamage(  damage )
{
	entity = self;
	
	entity.razRightThighHealth = entity.razRightThighHealth - damage;
	if( entity.razRightThighHealth <= 0 )
	{
		entity Clientfield::set( RAZ_DETACH_R_THIGH_ARMOR_CLIENTFIELD, 1 );
		entity HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_1, "", true );
		entity HidePart( RAZ_R_THIGH_ARMOR_HIDE_TAG_2, "", true );
		entity.razHasRightThighArmor = false;
		Blackboard::SetBlackBoardAttribute(entity, GIB_LOCATION, "right_leg");
	}
}

	