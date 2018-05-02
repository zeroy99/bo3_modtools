#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\ai\behavior_zombie_dog;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_direwolf.gsh;

#namespace ArchetypeDirewolf;

REGISTER_SYSTEM( "direwolf", &__init__, undefined )

function __init__()
{
	// INIT BLACKBOARD
	spawner::add_archetype_spawn_function( ARCHETYPE_DIREWOLF, &ZombieDogBehavior::ArchetypeZombieDogBlackboardInit );
	spawner::add_archetype_spawn_function( ARCHETYPE_DIREWOLF, &direwolfSpawnSetup );

	// REGISTER AI INTERFACE ATTRIBUTES
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "sprint", false, array( true, false ) );
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "howl_chance", 0.3 );	// 30% chance to howl when we spot our target
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "can_initiateaivsaimelee", true, array( true, false ) );
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "spacing_near_dist", 120 );
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "spacing_far_dist", 480 );
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "spacing_horz_dist", 144 );
	ai::RegisterMatchedInterface( ARCHETYPE_DIREWOLF, "spacing_value", 0 );	// between -1 and 1
	
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_DIREWOLF ) )
	{
		clientfield::register(
			"actor",
			DIREWOLF_EYE_GLOW_FX_CLIENTFIELD,
			VERSION_SHIP,
			DIREWOLF_EYE_GLOW_FX_BITS,
			DIREWOLF_EYE_GLOW_FX_TYPE );
	}
}

function private direwolfSpawnSetup()
{
	// init the entity
	self SetTeam( "team3" );
	self AllowPitchAngle( 1 );
	self setPitchOrient();
	self setAvoidanceMask( "avoid all" );
	self PushActors( true );
	self ai::set_behavior_attribute( "spacing_value", RandomFloatRange( -1.0, 1.0 ) );

	// enable eye glow
	self clientfield::set( DIREWOLF_EYE_GLOW_FX_CLIENTFIELD, 1 );
}

// end #namespace ArchetypeDirewolf;
