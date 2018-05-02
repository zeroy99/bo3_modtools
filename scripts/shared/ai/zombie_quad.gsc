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
#using scripts\shared\ai\zombie;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_shared;
#using scripts\codescripts\struct;
#using scripts\shared\ai\archetype_mocomps_utility;

//INTERFACE
#using scripts\shared\ai\systems\ai_interface;

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

#namespace ZombieQuad;

function autoexec init()
{
	// INIT BEHAVIORS
	InitZombieBehaviorsAndASM();

	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE_QUAD, &ZombieQuad::ArchetypeQuadBlackboardInit );
	
	// INIT QUAD ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_ZOMBIE_QUAD, &ZombieQuad::quadSpawnSetup );	
}

function ArchetypeQuadBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();

	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( self );
	
	// CREATE QUAD BLACKBOARD
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,	LOCOMOTION_SPEED_WALK,	&ZombieBehavior::BB_GetLocomotionSpeedType );

	BB_REGISTER_ATTRIBUTE( QUAD_WALL_CRAWL, 		undefined,				undefined );
	BB_REGISTER_ATTRIBUTE( QUAD_PHASE_DIRECTION, 	undefined,				undefined );
	BB_REGISTER_ATTRIBUTE( QUAD_PHASE_DISTANCE, 	undefined,				undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeQuadOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
	
}

function private ArchetypeQuadOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeQuadBlackboardInit();
}

function private InitZombieBehaviorsAndASM()
{
	// ------- ZOMBIE MOCOMP -----------//
	ASM_REGISTER_MOCOMP( "mocomp_teleport_traversal@zombie_quad", &quadTeleportTraversalMocompStart, undefined, undefined );
}

//*****************************************************************************
//*****************************************************************************

function quadSpawnSetup()
{
	self SetPitchOrient();
}

//*****************************************************************************
//*****************************************************************************

function quadTeleportTraversalMocompStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode( AI_ANIM_MOVE_CODE );

	if ( IsDefined( entity.traverseEndNode ) )
	{
		/#
			Print3D( entity.traverseStartNode.origin, ".", RED, 1, 1, 60 );
			Print3D( entity.traverseEndNode.origin, ".", GREEN, 1, 1, 60 );
			Line( entity.traverseStartNode.origin, entity.traverseEndNode.origin, GREEN, 1, false, 60 );
		#/

		entity ForceTeleport( entity.traverseEndNode.origin, entity.traverseEndNode.angles, false );
	}
}

