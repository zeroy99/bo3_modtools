#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\skeleton.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

REGISTER_SYSTEM( "skeleton", &__init__, undefined )

function autoexec precache()
{
}

function __init__()
{
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_SKELETON ) )
	{
		clientfield::register(
			"actor",
			SKELETON_CLIENTFIELD,
			VERSION_SHIP,
			1,
			"int",
			&ZombieClientUtils::zombieHandler,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT);
	}
}

#namespace ZombieClientUtils;

function zombieHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( IsDefined( entity.archetype ) && entity.archetype != "zombie" )
	{
		return;
	}
	
	if ( !IsDefined( entity.initializedGibCallbacks ) || !entity.initializedGibCallbacks )
	{
		entity.initializedGibCallbacks = true;

		GibClientUtils::AddGibCallback( localClientNum, entity, GIB_TORSO_HEAD_FLAG, &_gibCallback );
		GibClientUtils::AddGibCallback( localClientNum, entity, GIB_TORSO_RIGHT_ARM_FLAG, &_gibCallback );
		GibClientUtils::AddGibCallback( localClientNum, entity, GIB_TORSO_LEFT_ARM_FLAG, &_gibCallback );
		GibClientUtils::AddGibCallback( localClientNum, entity, GIB_LEGS_RIGHT_LEG_FLAG, &_gibCallback );
		GibClientUtils::AddGibCallback( localClientNum, entity, GIB_LEGS_LEFT_LEG_FLAG, &_gibCallback );
	}
}

function private _gibCallback( localClientNum, entity, gibFlag )
{
	switch (gibFlag)
	{
	case GIB_TORSO_HEAD_FLAG:
		playsound(0, "zmb_zombie_head_gib", self.origin);
		break;
	case GIB_TORSO_RIGHT_ARM_FLAG:
	case GIB_TORSO_LEFT_ARM_FLAG:
	case GIB_LEGS_RIGHT_LEG_FLAG:
	case GIB_LEGS_LEFT_LEG_FLAG:
		playsound(0, "zmb_death_gibs", self.origin);
		break;
	}
}