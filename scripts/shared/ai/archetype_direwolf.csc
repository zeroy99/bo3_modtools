#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_direwolf.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", DIREWOLF_EYE_GLOW_FX_FILE );

#namespace ArchetypeDirewolf;

REGISTER_SYSTEM( "direwolf", &__init__, undefined )

function autoexec precache()
{
	level._effect[ DIREWOLF_EYE_GLOW_FX ] = DIREWOLF_EYE_GLOW_FX_FILE;
}

function __init__()
{
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_DIREWOLF ) )
	{
		clientfield::register(
			"actor",
			DIREWOLF_EYE_GLOW_FX_CLIENTFIELD,
			VERSION_SHIP,
			DIREWOLF_EYE_GLOW_FX_BITS,
			DIREWOLF_EYE_GLOW_FX_TYPE,
			&direwolfEyeGlowFxHandler,
			!CF_HOST_ONLY,
			CF_CALLBACK_ZERO_ON_NEW_ENT );
	}
}

function private direwolfEyeGlowFxHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( IsDefined( entity.archetype ) && entity.archetype != "direwolf" )
	{
		return;
	}
	
	if ( IsDefined( entity.eyeGlowFx ) )
	{
		StopFx( localClientNum, entity.eyeGlowFx );
		entity.eyeGlowFx = undefined;
	}

	if ( newValue )
	{
		entity.eyeGlowFx = PlayFxOnTag( localClientNum, level._effect[ DIREWOLF_EYE_GLOW_FX ], entity, DIREWOLF_EYE_GLOW_FX_TAG );
	}
}
