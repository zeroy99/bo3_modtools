#using scripts\shared\clientfield_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\zombie.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#precache( "client_fx", "zombie/fx_val_chest_burst");

#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_torso_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_hip_left_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_hip_right_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_leg_left_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_leg_right_loop_optim");
#precache( "client_fx", "fire/fx_fire_ai_human_head_loop_optim");

function autoexec precache()
{
	
}

function autoexec main()
{
	level._effect["zombie_special_day_effect"]		= "zombie/fx_val_chest_burst";
	
	ai::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &ZombieClientUtils::zombie_override_burn_fx );
	
	clientfield::register(
		"actor",
		ZOMBIE_CLIENTFIELD,
		VERSION_SHIP,
		1,
		"int",
		&ZombieClientUtils::zombieHandler,
		!CF_HOST_ONLY,
		!CF_CALLBACK_ZERO_ON_NEW_ENT);
	
	clientfield::register(
		"actor",
		ZOMBIE_SPECIAL_DAY_EFFECTS_CLIENTFIELD,
		VERSION_TU6_FFOTD_020416_0,
		1,
		"counter",
		&ZombieClientUtils::zombieSpecialDayEffectsHandler,
		!CF_HOST_ONLY,
		!CF_CALLBACK_ZERO_ON_NEW_ENT);
}

#namespace ZombieClientUtils;

function zombieHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( IsDefined( entity.archetype ) && entity.archetype != ARCHETYPE_ZOMBIE )
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
		playsound(0, "zmb_zombie_head_gib", self.origin + (0,0,60));
		break;
	case GIB_TORSO_RIGHT_ARM_FLAG:
	case GIB_TORSO_LEFT_ARM_FLAG:
	case GIB_LEGS_RIGHT_LEG_FLAG:
	case GIB_LEGS_LEFT_LEG_FLAG:
		playsound(0, "zmb_death_gibs", self.origin + (0,0,30));
		break;
	}
}

function zombieSpecialDayEffectsHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( IsDefined( entity.archetype ) && entity.archetype != ARCHETYPE_ZOMBIE )
	{
		return;
	}
	
	origin = entity GetTagOrigin( "j_spine4" );
	
	fx = PlayFX( localClientNum, level._effect["zombie_special_day_effect"], origin );
	SetFXIgnorePause( localClientNum, fx, true );
}

function zombie_override_burn_fx( localClientNum )
{
	if( SessionModeIsZombiesGame() )
	{
		if( !isdefined( self._effect ))
		{
			self._effect = [];
		}
		level._effect["fire_zombie_j_elbow_le_loop"]		= "fire/fx_fire_ai_human_arm_left_loop_optim";	// hand and forearm fires
		level._effect["fire_zombie_j_elbow_ri_loop"]		= "fire/fx_fire_ai_human_arm_right_loop_optim";
		level._effect["fire_zombie_j_shoulder_le_loop"]	= "fire/fx_fire_ai_human_arm_left_loop_optim";	// upper arm fires
		level._effect["fire_zombie_j_shoulder_ri_loop"]	= "fire/fx_fire_ai_human_arm_right_loop_optim";
		level._effect["fire_zombie_j_spine4_loop"]		= "fire/fx_fire_ai_human_torso_loop_optim";		// upper torso fires
		level._effect["fire_zombie_j_hip_le_loop"]		= "fire/fx_fire_ai_human_hip_left_loop_optim";	// thigh fires
		level._effect["fire_zombie_j_hip_ri_loop"]		= "fire/fx_fire_ai_human_hip_right_loop_optim";
		level._effect["fire_zombie_j_knee_le_loop"]		= "fire/fx_fire_ai_human_leg_left_loop_optim";	// shin fires
		level._effect["fire_zombie_j_knee_ri_loop"]		= "fire/fx_fire_ai_human_leg_right_loop_optim";
		level._effect["fire_zombie_j_head_loop"] 		= "fire/fx_fire_ai_human_head_loop_optim";		// head fire
	}
}
