#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
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
#using scripts\shared\ai\archetype_mocomps_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\archetype_clone.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace CloneBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitThrasherBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_HUMAN_CLONE, &ArchetypeCloneBlackboardInit );

	// INIT THRASHER ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_HUMAN_CLONE, &cloneSpawnSetup );
}

function private InitThrasherBehaviorsAndASM()
{
}

function private ArchetypeCloneBlackboardInit()
{
	entity = self;

	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( entity );
	
	// USE UTILITY BLACKBOARD
	entity AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( entity );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	entity.___ArchetypeOnAnimscriptedCallback = &ArchetypeCloneOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING( entity );
}

function private ArchetypeCloneOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeCloneBlackboardInit();
}

function private perfectInfoThread()
{
	entity = self;
	
	entity endon( "death" );

	while ( true )
	{
		if ( IsDefined( entity.enemy ) )
		{
			entity GetPerfectInfo( entity.enemy, true );
		}
		
		wait SERVER_FRAME;
	}
}

function private cloneSpawnSetup()
{
	entity = self;
	
	entity.ignoreme = true;
	entity.ignoreall = true;
	// entity.pushable = false;
	
	// entity PushActors( true );  // Don't collide with other actors.
	// entity PushPlayer( true );  // Don't collide with players.
	entity SetContents( CONTENTS_CLIPSHOT );  // Collide with bullets.
	entity SetAvoidanceMask( "avoid none" );
	
	entity SetClone();
	
	entity thread perfectInfoThread();
}

#namespace CloneServerUtils;

function clonePlayerLook( clone, clonePlayer, targetPlayer )
{
	assert( IsActor( clone ) );
	assert( IsPlayer( clonePlayer ) );
	assert( IsPlayer( targetPlayer ) );
	
	clone.owner = clonePlayer;
	clone SetEntityTarget( targetPlayer, 1.0 );
	clone SetEntityOwner( clonePlayer );
	clone DetachAll();
	
	// Clone player's look
	bodyModel = clonePlayer GetCharacterBodyModel();
	if ( IsDefined( bodyModel ) )
	{
		clone SetModel( bodyModel );
	}
	
	headModel = clonePlayer GetCharacterHeadModel();
	if ( IsDefined( headModel ) && headModel != "tag_origin" )
	{
		if ( IsDefined( clone.head ) )
		{
			clone Detach( clone.head );
		}
		
		clone Attach( headModel );
	}
	
	helmetModel = clonePlayer GetCharacterHelmetModel();
	if ( IsDefined( helmetModel ) && headModel != "tag_origin" )
	{
		clone Attach( helmetModel );
	}
}