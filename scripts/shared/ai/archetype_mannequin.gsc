#using scripts\shared\spawner_shared;
#using scripts\shared\ai\zombie;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\archetype_mannequin_interface;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\behavior_tree_utility;

#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;

#namespace MannequinBehavior;

function autoexec init()
{
	level.zm_variant_type_max						= [];
	level.zm_variant_type_max[ "walk" ]				= [];
	level.zm_variant_type_max[ "run" ]				= [];
	level.zm_variant_type_max[ "sprint" ] 			= [];
	level.zm_variant_type_max[ "walk" ][ "down" ]	= 14;
	level.zm_variant_type_max[ "walk" ][ "up" ] 	= 16;
	level.zm_variant_type_max[ "run" ][ "down" ]	= 13;
	level.zm_variant_type_max[ "run" ][ "up" ]		= 12;
	level.zm_variant_type_max[ "sprint" ][ "down" ]	= 7;
	level.zm_variant_type_max[ "sprint" ][ "up" ]	= 6;

	// INIT BLACKBOARD
	spawner::add_archetype_spawn_function( ARCHETYPE_MANNEQUIN, &ZombieBehavior::ArchetypeZombieBlackboardInit );
	spawner::add_archetype_spawn_function( ARCHETYPE_MANNEQUIN, &ZombieBehavior::ArchetypeZombieDeathOverrideInit );
		
	// INIT ZOMBIE ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_MANNEQUIN, &zombie_utility::zombieSpawnSetup );
	spawner::add_archetype_spawn_function( ARCHETYPE_MANNEQUIN, &mannequinSpawnSetup );
			
	MannequinInterface::RegisterMannequinInterfaceAttributes();
	
	BT_REGISTER_API( "mannequinCollisionService", 	&mannequinCollisionService );
	BT_REGISTER_API( "mannequinShouldMelee", 		&mannequinShouldMelee );
}

function mannequinCollisionService( entity )
{
	if ( IsDefined( entity.enemy ) &&
		DistanceSquared( entity.origin, entity.enemy.origin ) > SQR( 300 ) )
	{
		// Allow clipping with other AI's at a distance, this helps when the AI's move diagonally into each other.
		entity PushActors( false );
	}
	else
	{
		// Force AI's to push each other close to their enemy.
		entity PushActors( true );
	}
}

function mannequinSpawnSetup( entity )
{
}

#define MANNEQUIN_MELEE_HEIGHT 72
#define MANNEQUIN_MELEE_DIST_SQ SQR( 64 )
#define MANNEQUIN_MELEE_YAW 45
function private mannequinShouldMelee( entity )
{
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if( IsDefined( entity.marked_for_death ) )
	{
		return false;
	}

	if( IS_TRUE( entity.ignoreMelee ) )
	{
		return false;
	}
	
	if( Distance2DSquared( entity.origin, entity.enemy.origin ) > MANNEQUIN_MELEE_DIST_SQ )
	{
		return false;
	}
	
	if( abs( entity.origin[2] - entity.enemy.origin[2] ) > MANNEQUIN_MELEE_HEIGHT )
	{
		return false;
	}
	
	yawToEnemy = AngleClamp180( entity.angles[ 1 ] - GET_YAW( entity, entity.enemy.origin ) );
	if( abs( yawToEnemy ) > MANNEQUIN_MELEE_YAW )
	{
		return false;
	}
	
	return true;
}
