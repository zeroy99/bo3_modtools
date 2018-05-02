#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\fx_character;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", ROBOT_EMP_FX_FILE );
#precache( "client_fx", ROBOT_MIND_CONTROL_EXPLOSION_FX_FILE );

REGISTER_SYSTEM( "robot", &__init__, undefined )

function autoexec precache()
{
	level._effect[ ROBOT_EMP_FX ] = ROBOT_EMP_FX_FILE;
	level._effect[ ROBOT_MIND_CONTROL_EXPLOSION_FX ] = ROBOT_MIND_CONTROL_EXPLOSION_FX_FILE;
}

function __init__()
{
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_ROBOT ) )
	{		
		clientfield::register(
			"actor",
			ROBOT_MIND_CONTROL_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_MIND_CONTROL_BITS,
			ROBOT_MIND_CONTROL_TYPE,
			&RobotClientUtils::robotMindControlHandler,
			!CF_HOST_ONLY,
			CF_CALLBACK_ZERO_ON_NEW_ENT);
			
		clientfield::register(
			"actor",
			ROBOT_MIND_CONTROL_EXPLOSION_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_MIND_CONTROL_EXPLOSION_BITS,
			ROBOT_MIND_CONTROL_EXPLOSION_TYPE,
			&RobotClientUtils::robotMindControlExplosionHandler,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT);
			
		clientfield::register(
			"actor",
			ROBOT_LIGHTS_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_LIGHTS_BITS,
			ROBOT_LIGHTS_TYPE,
			&RobotClientUtils::robotLightsHandler,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT);
			
		clientfield::register(
			"actor",
			ROBOT_EMP_CLIENTFIELD,
			VERSION_SHIP,
			ROBOT_EMP_BITS,
			ROBOT_EMP_TYPE,
			&RobotClientUtils::robotEmpHandler,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT);
	}
	
	ai::add_archetype_spawn_function( ARCHETYPE_ROBOT, &RobotClientUtils::robotSoldierSpawnSetup );
}

#namespace RobotClientUtils;

function private robotSoldierSpawnSetup( localClientNum )
{
	entity = self;
}

function private robotLighting( localClientNum, entity, flicker, mindControlState )
{
	switch ( mindControlState )
	{
	case ROBOT_MIND_CONTROL_LEVEL_0:
		entity TmodeClearFlag( 0 );
		
		if ( flicker )
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_BASE_FLICKER( entity ) );
		}
		else
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_BASE( entity ) );
		}
		break;
	case ROBOT_MIND_CONTROL_LEVEL_1:
		entity TmodeClearFlag( 0 );
	
		FxClientUtils::StopAllFXBundles( localClientNum, entity );
		
		if ( flicker )
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_1_FLICKER( entity ) );
		}
		else
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_1( entity ) );
		}
	
		if ( !GibClientUtils::IsGibbed( localClientNum, entity, GIB_TORSO_HEAD_FLAG ) )
		{
			entity PlaySound(localClientNum, "fly_bot_ctrl_lvl_01_start", entity.origin);
		}
		break;
	case ROBOT_MIND_CONTROL_LEVEL_2:
		entity TmodeSetFlag( 0 );
	
		FxClientUtils::StopAllFXBundles( localClientNum, entity );
		
		if ( flicker )
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_2_FLICKER( entity ) );
		}
		else
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_2( entity ) );
		}
	
		if ( !GibClientUtils::IsGibbed( localClientNum, entity, GIB_TORSO_HEAD_FLAG ) )
		{
			entity PlaySound(localClientNum, "fly_bot_ctrl_lvl_02_start", entity.origin);
		}
		break;
	case ROBOT_MIND_CONTROL_LEVEL_3:
		entity TmodeSetFlag( 0 );
	
		FxClientUtils::StopAllFXBundles( localClientNum, entity );
		
		if ( flicker )
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_3_FLICKER( entity ) );
		}
		else
		{
			FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_ROGUE_LEVEL_3( entity ) );
		}
		
		entity PlaySound(localClientNum, "fly_bot_ctrl_lvl_03_start", entity.origin);
		
		break;
	}
}

function private robotLightsHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) ||
		!entity IsAI() ||
		( IsDefined( entity.archetype ) && entity.archetype != "robot" ) )
	{
		return;
	}
	
	FxClientUtils::StopAllFXBundles( localClientNum, entity );
	
	flicker = newValue == ROBOT_LIGHTS_FLICKER;
	
	if ( newValue == ROBOT_LIGHTS_ON || newValue == ROBOT_LIGHTS_HACKED || flicker )
	{
		robotLighting( localClientNum, entity, flicker, clientfield::get( ROBOT_MIND_CONTROL_CLIENTFIELD ) );
	}
	else if ( newValue == ROBOT_LIGHTS_DEATH )
	{
		FxClientUtils::PlayFxBundle( localClientNum, entity, ROBOT_FX_DEATH( entity ) );
	}
}

function private robotEmpHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) ||
		!entity IsAI() ||
		( IsDefined( entity.archetype ) && entity.archetype != "robot" ) )
	{
		return;
	}
	
	if ( IsDefined( entity.empFX ) )
	{
		StopFx( localClientNum, entity.empFX );
	}
	
	switch ( newValue )
	{
	case ROBOT_EMP_OFF:
		break;
	case ROBOT_EMP_ON:
		entity.empFX = PlayFxOnTag(
			localClientNum,
			level._effect[ ROBOT_EMP_FX ],
			entity,
			ROBOT_EMP_FX_TAG );
		break;
	}
}

function private robotMindControlHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) ||
		!entity IsAI() ||
		( IsDefined( entity.archetype ) && entity.archetype != "robot" ) )
	{
		return;
	}
	
	lights = clientfield::get( ROBOT_LIGHTS_CLIENTFIELD );
	flicker = lights == ROBOT_LIGHTS_FLICKER;
	
	if ( lights == ROBOT_LIGHTS_ON || flicker )
	{
		robotLighting( localClientNum, entity, flicker, newValue );
	}
}

function robotMindControlExplosionHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) ||
		!entity IsAI() ||
		( IsDefined( entity.archetype ) && entity.archetype != "robot" ) )
	{
		return;
	}
	
	switch ( newValue )
	{
	case ROBOT_MIND_CONTROL_EXPLOSION_ON:
		entity.explosionFx =
			PlayFxOnTag(
				localClientNum,
				level._effect[ ROBOT_MIND_CONTROL_EXPLOSION_FX ],
				entity,
				ROBOT_MIND_CONTROL_EXPLOSION_FX_TAG );
		break;
	}
}
