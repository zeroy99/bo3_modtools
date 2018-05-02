#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_thrasher.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", THRASHER_FOOTSTEP_FX_FILE );
#precache( "client_fx", THRASHER_SPORE_DESTROY_FX1_FILE );
#precache( "client_fx", THRASHER_SPORE_DESTROY_FX2_FILE );
#precache( "client_fx", THRASHER_SPORE_IMPACT_FX_FILE );
#precache( "client_fx", THRASHER_EYE_FX_FILE );
#precache( "client_fx", THRASHER_BERSERK_EYE_FX_FILE );
#precache( "client_fx", THRASHER_BERSERK_FX1_FILE );
#precache( "client_fx", THRASHER_BERSERK_FX2_FILE );
#precache( "client_fx", THRASHER_BERSERK_FX3_FILE );
#precache( "client_fx", THRASHER_SPORE_INFLATE_FX_FILE );
#precache( "client_fx", THRASHER_SPORE_CLOUD_SM_FX_FILE );
#precache( "client_fx", THRASHER_SPORE_CLOUD_MD_FX_FILE );
#precache( "client_fx", THRASHER_SPORE_CLOUD_LRG_FX_FILE );
#precache( "client_fx", THRASHER_CONSUMED_PLAYER_FX_FILE );

#using_animtree( "generic" );

REGISTER_SYSTEM( "thrasher", &__init__, undefined )

function __init__()
{
	visionset_mgr::register_visionset_info( THRASHER_CONSUMED_PLAYER_VISIONSET_ALIAS, VERSION_DLC2, THRASHER_CONSUMED_PLAYER_VISIONSET_LERP_STEP_COUNT, undefined, THRASHER_CONSUMED_PLAYER_VISIONSET_FILE );
	
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_THRASHER ) )
	{		
		clientfield::register(
			"actor",
			THRASHER_SPORE_CF,
			VERSION_TU5,  // Leave at VERSION_TU5
			THRASHER_SPORE_CF_BITS,
			THRASHER_SPORE_CF_TYPE,
			&ThrasherClientUtils::thrasherSporeExplode,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT );
			
		clientfield::register(
			"actor",
			THRASHER_BERSERK_CF,
			VERSION_TU5,  // Leave at VERSION_TU5
			THRASHER_BERSERK_CF_BITS,
			THRASHER_BERSERK_CF_TYPE,
			&ThrasherClientUtils::thrasherBerserkMode,
			!CF_HOST_ONLY,
			CF_CALLBACK_ZERO_ON_NEW_ENT );
			
		clientfield::register(
			"actor",
			"thrasher_player_hide",
			VERSION_TU8,  // Leave at VERSION_TU8
			4,
			"int",
			&ThrasherClientUtils::thrasherHideFromPlayer,
			!CF_HOST_ONLY,
			!CF_CALLBACK_ZERO_ON_NEW_ENT );
		
		clientfield::register(
			"toplayer",
			"sndPlayerConsumed",
			VERSION_TU10,  // Leave at VERSION_TU10
			1,
			"int",
			&ThrasherClientUtils::sndPlayerConsumed,
			!CF_HOST_ONLY,
			CF_CALLBACK_ZERO_ON_NEW_ENT );
		
		foreach ( spore in THRASHER_SPORE_CF_SPORES )
		{
			clientfield::register(
				"actor",
				THRASHER_SPORE_IMPACT_CF + spore,
				VERSION_TU8,  // Leave at VERSION_TU8
				THRASHER_SPORE_IMPACT_CF_BITS,
				THRASHER_SPORE_IMPACT_CF_TYPE,
				&ThrasherClientUtils::thrasherSporeImpact,
				!CF_HOST_ONLY,
				!CF_CALLBACK_ZERO_ON_NEW_ENT );
		}
	}
	
	ai::add_archetype_spawn_function( ARCHETYPE_THRASHER, &ThrasherClientUtils::thrasherSpawn );
	
	level.thrasherPustules = [];
	level thread ThrasherClientUtils::thrasherFxCleanup();
}

function autoexec precache()
{
	level._effect[ THRASHER_FOOTSTEP_FX ]				= THRASHER_FOOTSTEP_FX_FILE;
	level._effect[ THRASHER_SPORE_DESTROY_FX1 ]			= THRASHER_SPORE_DESTROY_FX1_FILE;
	level._effect[ THRASHER_SPORE_DESTROY_FX2 ]			= THRASHER_SPORE_DESTROY_FX2_FILE;
	level._effect[ THRASHER_SPORE_IMPACT_FX ]			= THRASHER_SPORE_IMPACT_FX_FILE;
	level._effect[ THRASHER_EYE_FX ]					= THRASHER_EYE_FX_FILE;
	level._effect[ THRASHER_BERSERK_EYE_FX ]			= THRASHER_BERSERK_EYE_FX_FILE;
	level._effect[ THRASHER_BERSERK_FX1 ]				= THRASHER_BERSERK_FX1_FILE;
	level._effect[ THRASHER_BERSERK_FX2 ]				= THRASHER_BERSERK_FX2_FILE;
	level._effect[ THRASHER_BERSERK_FX3 ]				= THRASHER_BERSERK_FX3_FILE;
	level._effect[ THRASHER_SPORE_INFLATE_FX ]			= THRASHER_SPORE_INFLATE_FX_FILE;
	level._effect[ THRASHER_SPORE_CLOUD_SM_FX ]			= THRASHER_SPORE_CLOUD_SM_FX_FILE;
	level._effect[ THRASHER_SPORE_CLOUD_MD_FX ]			= THRASHER_SPORE_CLOUD_MD_FX_FILE;
	level._effect[ THRASHER_SPORE_CLOUD_LRG_FX ]		= THRASHER_SPORE_INFLATE_FX_FILE;
	level._effect[ THRASHER_CONSUMED_PLAYER_FX ]		= THRASHER_CONSUMED_PLAYER_FX_FILE;
}

#namespace ThrasherClientUtils;

function private thrasherSpawn( localClientNum )
{
	entity = self;
	entity.ignoreRagdoll = true;

	level._footstepCBFuncs[entity.archetype] = &thrasherProcessFootstep;
	
	GibClientUtils::AddGibCallback( localClientNum, entity, GIB_HEAD_HAT_FLAG, &thrasherDisableEyeGlow );
}

function private thrasherFxCleanup()
{
	while ( true )
	{
		pustules = level.thrasherPustules;
		level.thrasherPustules = [];
		time = GetTime();
		
		foreach ( pustule in pustules )
		{
			if ( pustule.endTime <= time )
			{
				if( isdefined( pustule.fx ) )
				{
					StopFX( pustule.localClientNum, pustule.fx );
				}
			}
			else
			{
				level.thrasherPustules[ level.thrasherPustules.size ] = pustule;
			}
		}
		
		wait 0.5;
	}
}

#define THRASHER_RUMBLE_COOLDOWN 400
function thrasherProcessFootstep( localClientNum, pos, surface, notetrack, bone )
{
	e_player = GetLocalPlayer( localClientNum );
	n_dist = DistanceSquared( pos, e_player.origin );
	n_thrasher_dist = ( THRASHER_FOOTSTEP_EARTHQUAKE_MAX_RADIUS * THRASHER_FOOTSTEP_EARTHQUAKE_MAX_RADIUS );
	
	if (n_thrasher_dist <= 0)
	{
		return;
		
	}
	
	n_scale = ( n_thrasher_dist - n_dist ) / n_thrasher_dist;
	
	if ( n_scale > 1 || n_scale < 0 || n_scale <= 0.01 )
	{
		return;
	}
	
	fx = PlayFXOnTag( localClientNum, level._effect[ THRASHER_FOOTSTEP_FX ], self, bone );
	
	if ( IsDefined( e_player.thrasherLastFootstep ) &&
		( e_player.thrasherLastFootstep + THRASHER_RUMBLE_COOLDOWN ) > GetTime() )
	{
		return;
	}

	earthquake_scale = n_scale * 0.1;
	
	if( earthquake_scale > 0.01)
	{
		e_player Earthquake( earthquake_scale, 0.1, pos, n_dist );
	}
	
	if( n_scale <= 1 && n_scale > 0.8 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "damage_heavy" );
	}
	else if( n_scale <= 0.8 && n_scale > 0.4 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "reload_small" );
	}
	
	e_player.thrasherLastFootstep = GetTime();
}

function private _StopFx( localClientNum, effect )
{
	if ( IsDefined( effect ) )
	{
		StopFX( localClientNum, effect );
	}
}

function private thrasherHideFromPlayer( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) || entity.archetype !== "thrasher" || !entity HasDObj( localClientNum ) )
	{
		return;
	}
	
	localPlayer = GetLocalPlayer( localClientNum );
	localPlayerNum = localPlayer GetEntityNumber();
	localPlayerBit = 1 << localPlayerNum;
	
	if ( localPlayerBit & newValue )
	{
		entity Hide();
	}
	else
	{
		entity Show();
	}
}

function private thrasherBerserkMode( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( !IsDefined( entity ) || entity.archetype !== "thrasher" || !entity HasDObj( localClientNum ) )
	{
		return;
	}
	
	_StopFx( localClientNum, entity.thrasherEyeGlow );
	entity.thrasherEyeGlow = undefined;
	
	_StopFx( localClientNum, entity.thrasherAmbientFX1 );
	entity.thrasherAmbientFX1 = undefined;
	_StopFx( localClientNum, entity.thrasherAmbientFX2 );
	entity.thrasherAmbientFX2 = undefined;
	_StopFx( localClientNum, entity.thrasherAmbientFX3 );
	entity.thrasherAmbientFX3 = undefined;
	
	hasHead = !GibClientUtils::IsGibbed( localClientNum, entity, GIB_HEAD_HAT_FLAG );
	
	switch ( newValue )
	{
	case THRASHER_BERSERK_CF_NORMAL:
		if ( hasHead )
		{
			entity.thrasherEyeGlow = PlayFXOnTag( localClientNum, level._effect[ THRASHER_EYE_FX ], entity, THRASHER_EYE_TAG );
		}
		break;
	case THRASHER_BERSERK_CF_BERSERK:
		if ( hasHead )
		{
			entity.thrasherEyeGlow = PlayFXOnTag( localClientNum, level._effect[ THRASHER_BERSERK_EYE_FX ], entity, THRASHER_EYE_TAG );
		}
		entity.thrasherAmbientFX1 = PlayFXOnTag( localClientNum, level._effect[ THRASHER_BERSERK_FX1 ], entity, THRASHER_BERSERK_FX1_TAG );
		entity.thrasherAmbientFX2 = PlayFXOnTag( localClientNum, level._effect[ THRASHER_BERSERK_FX2 ], entity, THRASHER_BERSERK_FX2_TAG );
		entity.thrasherAmbientFX3 = PlayFXOnTag( localClientNum, level._effect[ THRASHER_BERSERK_FX3 ], entity, THRASHER_BERSERK_FX3_TAG );
		break;
	}
}

function private thrasherSporeExplode( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	sporeClientfields = THRASHER_SPORE_CF_SPORES;
	sporeTags = THRASHER_SPORES;

	// Flags bits that are 1 in the newValue and 0 in the oldValue.
	newSporesExploded = (oldValue ^ newValue) & ~oldValue;
	// Flags bits that are 0 in the newValue and 1 in the oldValue.
	oldSporesInflated = (oldValue ^ newValue) & ~newValue;
	currentSpore = sporeClientfields[0];
	
	for ( index = 0; index < THRASHER_SPORES.size; index++ )
	{
		sporeTag = sporeTags[index];
	
		pustuleInfo = undefined;
	
		if ( newSporesExploded & currentSpore )
		{
			PlayFXOnTag( localClientNum, level._effect[ THRASHER_SPORE_DESTROY_FX1 ], entity, sporeTag );
			PlayFXOnTag( localClientNum, level._effect[ THRASHER_SPORE_DESTROY_FX2 ], entity, sporeTag );
			
			// Ambient spore cloud.
			pustuleInfo = SpawnStruct();
			pustuleInfo.length = THRASHER_SPORE_CLOUD_TIME;
			
			if( !IS_TRUE( level.b_thrasher_custom_spore_fx ) )
			{
				pustuleInfo.fx = PlayFX( localClientNum, level._effect[ THRASHER_SPORE_CLOUD_MD_FX ], entity GetTagOrigin( sporeTag ) );
			}
		}
		else if ( oldSporesInflated & currentSpore )
		{
			pustuleInfo = SpawnStruct();
			pustuleInfo.length = THRASHER_SPORE_INFLATE_TIME;
			
			pustuleInfo.fx = PlayFXOnTag( localClientNum, level._effect[ THRASHER_SPORE_INFLATE_FX ], entity, sporeTag );
		}
		
		if ( IsDefined( pustuleInfo ) )
		{
			pustuleInfo.localClientNum = localClientNum;
			pustuleInfo.startTime = GetTime();
			pustuleInfo.endTime = pustuleInfo.startTime + pustuleInfo.length;
			level.thrasherPustules[ level.thrasherPustules.size ] = pustuleInfo;
		}
		
		currentSpore <<= 1;
	}
}

function private thrasherSporeImpact( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	sporeTag = undefined;
	sporeClientfields = THRASHER_SPORE_CF_SPORES;

	assert( sporeClientfields.size == THRASHER_SPORES.size );
	
	for ( index = 0; index < sporeClientfields.size; index++ )
	{
		if ( fieldName == ( THRASHER_SPORE_IMPACT_CF + sporeClientfields[ index ] ) )
		{
			sporeTag = THRASHER_SPORES[ index ];
			break;
		}
	}

	if ( IsDefined( sporeTag ) )
	{
		PlayFXOnTag( localClientNum, level._effect[ THRASHER_SPORE_IMPACT_FX ], entity, sporeTag );
	}
}

function private thrasherDisableEyeGlow( localClientNum, entity, gibFlag )
{
	if ( !IsDefined( entity ) || entity.archetype !== "thrasher" || !entity HasDObj( localClientNum ) )
	{
		return;
	}
	
	_StopFx( localClientNum, entity.thrasherEyeGlow );
	entity.thrasherEyeGlow = undefined;
}

function private sndPlayerConsumed( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if( newValue )
	{
		if( !isdefined( self.sndPlayerConsumedID ) )
		{
			self.sndPlayerConsumedID = self playloopsound( "zmb_thrasher_consumed_lp", 5 );
		}
		
		if( !isdefined( self.n_fx_id_player_consumed ) )
		{
			self.n_fx_id_player_consumed = PlayFXOnCamera( localClientNum, level._effect[ THRASHER_CONSUMED_PLAYER_FX ] );
		}
		
		self thread postfx::playpostfxbundle( THRASHER_CONSUMED_PLAYER_POSTFX );
		EnableSpeedBlur( localClientNum, 0.07, 0.55, 0.9, false, 100, 100 );
	}
	else
	{
		if( isdefined( self.sndPlayerConsumedID ) )
		{
			self stoploopsound( self.sndPlayerConsumedID, .5 );
			self.sndPlayerConsumedID = undefined;
		}
		
		if( isdefined( self.n_fx_id_player_consumed ) )
		{
			StopFX( localClientNum, self.n_fx_id_player_consumed );
			self.n_fx_id_player_consumed = undefined;
		}
		
		self StopAllLoopSounds(1);
		
		if( isdefined( self.playingPostfxBundle ) )
		{
			self thread postfx::stopplayingpostfxbundle();
		}
		DisableSpeedBlur( localClientNum );
	}
}


