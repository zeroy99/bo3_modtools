#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\throttle_shared;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

function private fields_equal( field_a, field_b)
{
	if ( !isDefined(field_a) && !isDefined(field_b))
		return true;
	if ( isDefined(field_a) && isDefined(field_b) && field_a == field_b )
		return true;
	return false;
}

function private _IsDefaultPlayerGib( gibPieceFlag, gibStruct )
{
	if ( !fields_equal( level.playerGibBundle.gibs[gibPieceFlag].gibdynentfx , gibStruct.gibdynentfx ) )
	{
		return false;
	}
	if ( !fields_equal( level.playerGibBundle.gibs[gibPieceFlag].gibfxtag, gibStruct.gibfxtag ) )
	{
		return false;
	}
	if ( !fields_equal( level.playerGibBundle.gibs[gibPieceFlag].gibfx, gibStruct.gibfx ) )
	{
		return false;
	}
	if ( !fields_equal( level.playerGibBundle.gibs[gibPieceFlag].gibtag, gibStruct.gibtag ) )
	{
		return false;
	}
	
	return true;
}

function autoexec main()
{
	clientfield::register(
		"actor",
		GIB_CLIENTFIELD,
		VERSION_SHIP,
		GIB_CLIENTFIELD_BITS_ACTOR,
		GIB_CLIENTFIELD_TYPE );

	clientfield::register(
		"playercorpse",
		GIB_CLIENTFIELD,
		VERSION_SHIP,
		GIB_CLIENTFIELD_BITS_PLAYER,
		GIB_CLIENTFIELD_TYPE );
		
	gibDefinitions = GET_GIB_BUNDLES();
	
	gibPieceLookup = [];
	gibPieceLookup[GIB_ANNIHILATE_FLAG] = "annihilate";
	gibPieceLookup[GIB_TORSO_HEAD_FLAG] = "head";
	gibPieceLookup[GIB_TORSO_RIGHT_ARM_FLAG] = "rightarm";
	gibPieceLookup[GIB_TORSO_LEFT_ARM_FLAG] = "leftarm";
	gibPieceLookup[GIB_LEGS_RIGHT_LEG_FLAG] = "rightleg";
	gibPieceLookup[GIB_LEGS_LEFT_LEG_FLAG] = "leftleg";
	
	processedBundles = [];
	
	if ( SessionModeIsMultiplayerGame() )
	{
		level.playerGibBundle = SpawnStruct();
		level.playerGibBundle.gibs = [];
		level.playerGibBundle.name = "default_player";
		
		level.playerGibBundle.gibs[GIB_ANNIHILATE_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_TORSO_HEAD_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG] = SpawnStruct();
		level.playerGibBundle.gibs[GIB_ANNIHILATE_FLAG].gibfxtag = "j_spinelower";
		level.playerGibBundle.gibs[GIB_ANNIHILATE_FLAG].gibfx = "blood/fx_blood_impact_exp_body_lg";
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG].gibmodel = "c_t7_mp_battery_mpc_body1_s_larm";
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG].gibdynentfx = "blood/fx_blood_gib_limb_trail_emitter";
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG].gibfxtag = "j_elbow_le";
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG].gibfx = "blood/fx_blood_gib_arm_sever_burst";
		level.playerGibBundle.gibs[GIB_TORSO_LEFT_ARM_FLAG].gibtag = "j_elbow_le";
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG].gibmodel = "c_t7_mp_battery_mpc_body1_s_lleg";
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG].gibdynentfx = "blood/fx_blood_gib_limb_trail_emitter";
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG].gibfxtag = "j_knee_le";
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG].gibfx = "blood/fx_blood_gib_leg_sever_burst";
		level.playerGibBundle.gibs[GIB_LEGS_LEFT_LEG_FLAG].gibtag = "j_knee_le";
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG].gibmodel = "c_t7_mp_battery_mpc_body1_s_rarm";
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG].gibdynentfx = "blood/fx_blood_gib_limb_trail_emitter";
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG].gibfxtag = "j_elbow_ri";
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG].gibfx = "blood/fx_blood_gib_arm_sever_burst_rt";
		level.playerGibBundle.gibs[GIB_TORSO_RIGHT_ARM_FLAG].gibtag = "j_elbow_ri";
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG].gibmodel = "c_t7_mp_battery_mpc_body1_s_rleg";
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG].gibdynentfx = "blood/fx_blood_gib_limb_trail_emitter";
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG].gibfxtag = "j_knee_ri";
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG].gibfx = "blood/fx_blood_gib_leg_sever_burst_rt";
		level.playerGibBundle.gibs[GIB_LEGS_RIGHT_LEG_FLAG].gibtag = "j_knee_ri";
	}
	
	// Process each gib bundle to allow quick access to information in the future.
	foreach ( definitionName, definition in gibDefinitions )
	{
		gibBundle = SpawnStruct();
		gibBundle.gibs = [];
		gibBundle.name = definitionName;
		default_player = false;
		
		foreach ( gibPieceFlag, gibPieceName in gibPieceLookup )
		{
			gibStruct = SpawnStruct();
			gibStruct.gibmodel = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibmodel" );
			gibStruct.gibtag = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibtag" );
			gibStruct.gibfx = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibfx" );
			gibStruct.gibfxtag = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibeffecttag" );
			gibStruct.gibdynentfx = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibdynentfx" );
			gibStruct.gibsound = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibsound" );
			gibStruct.gibhidetag = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibhidetag" );
				
			if ( SessionModeIsMultiplayerGame() && _IsDefaultPlayerGib( gibPieceFlag, gibStruct ) )
			{
				default_player = true;
			}
			
			gibBundle.gibs[ gibPieceFlag ] = gibStruct;
		}
		
		if ( SessionModeIsMultiplayerGame() && default_player )
		{
			processedBundles[ definitionName ] = level.playerGibBundle;
		}
		else
		{
			processedBundles[ definitionName ] = gibBundle;
		}
	}
	
	// Replaces all gib character define bundles with their processed form to free unncessary script variables.
	level.scriptbundles[ "gibcharacterdef" ] = processedBundles;
	
	if ( !IsDefined( level.gib_throttle ) )
	{
		level.gib_throttle = new Throttle();
		// Two gibs every 0.2 seconds.
		[[ level.gib_throttle ]]->Initialize( 2, 0.2 );
	}
}

#namespace GibServerUtils;

function private _Annihilate( entity )
{
	if ( IsDefined( entity ) )
	{
		entity NotSolid();
	}
}

function private _GetGibExtraModel( entity, gibFlag )
{
	if ( gibFlag == GIB_HEAD_HAT_FLAG )
		return GIB_HAT_MODEL( entity );
	else if ( gibFlag == GIB_TORSO_HEAD_FLAG )
		return GIB_HEAD_MODEL( entity );
	else
		AssertMsg( "Unable to find gib model." );
}

// Used to solely gib equipment and the actor's head.
// Does not change the torso or leg models.
function private _GibExtra( entity, gibFlag )
{
	if ( IsGibbed( entity, gibFlag ) )
	{
		return false;
	}
	
	if ( !_HasGibDef( entity ) )
	{
		return false;
	}

	entity thread _GibExtraInternal( entity, gibFlag );
	
	return true;
}

function private _GibExtraInternal( entity, gibFlag )
{
	// Allow simulatenous gibs to happen on the same frame, since the network
	// cost is negligible if the gib is for the same entity.
	if ( entity.gib_time !== GetTime() )
	{
		[[ level.gib_throttle ]]->WaitInQueue( entity );
	}
	
	if ( !IsDefined( entity ) )
	{
		return;
	}
	
	entity.gib_time = GetTime();
	
	if ( IsGibbed( entity, gibFlag ) )
	{
		return false;
	}
	
	if ( gibFlag == GIB_TORSO_HEAD_FLAG )
	{
		if ( IsDefined( GIB_TORSO_HEAD_GONE_MODEL( entity ) ) )
		{
			entity Attach( GIB_TORSO_HEAD_GONE_MODEL( entity ), "", true ); 
		}
	}
	
	_SetGibbed( entity, gibFlag, undefined );

	DestructServerUtils::ShowDestructedPieces( entity );
	ShowHiddenGibPieces( entity );
	
	gibModel = _GetGibExtraModel( entity, gibFlag );
	if ( IsDefined( gibModel ) )
	{
		entity Detach( gibModel, "" );
	}
	
	DestructServerUtils::ReapplyDestructedPieces( entity );
	ReapplyHiddenGibPieces( entity );
}

// Used to gib torso or leg pieces, not including equipment or the actor's head.
// Changes the torso and leg models.
function private _GibEntity( entity, gibFlag )
{
	if ( IsGibbed( entity, gibFlag ) || !_HasGibPieces( entity, gibFlag ) )
	{
		return false;
	}
	
	if ( !_HasGibDef( entity ) )
	{
		return false;
	}
	
	entity thread _GibEntityInternal( entity, gibFlag );
	
	return true;
}

function private _GibEntityInternal( entity, gibFlag )
{
	// Allow simulatenous gibs to happen on the same frame, since the network
	// cost is negligible if the gib is for the same entity.
	if ( entity.gib_time !== GetTime() )
	{
		[[ level.gib_throttle ]]->WaitInQueue( entity );
	}
	
	if ( !IsDefined( entity ) )
	{
		return;
	}
	
	entity.gib_time = GetTime();

	if ( IsGibbed( entity, gibFlag ) )
	{
		return;
	}

	DestructServerUtils::ShowDestructedPieces( entity );
	ShowHiddenGibPieces( entity );
	
	if ( !IS_BODY_UNDAMAGED( _GetGibbedState( entity ) ) )
	{
		legModel = _GetGibbedLegModel( entity );
		entity Detach( legModel );
	}
	
	_SetGibbed( entity, gibFlag, undefined );
	
	entity SetModel( _GetGibbedTorsoModel( entity ) );
	entity Attach( _GetGibbedLegModel( entity ) );
	
	DestructServerUtils::ReapplyDestructedPieces( entity );
	ReapplyHiddenGibPieces( entity );
}

function private _GetGibbedLegModel( entity )
{
	gibState = _GetGibbedState( entity );
	rightLegGibbed = IS_GIBBED( gibState, GIB_LEGS_RIGHT_LEG_FLAG);
	leftLegGibbed = IS_GIBBED( gibState, GIB_LEGS_LEFT_LEG_FLAG);
	
	if ( rightLegGibbed && leftLegGibbed)
	{
		return GIB_LEGS_NO_LEGS_MODEL( entity );
	}
	else if ( rightLegGibbed )
	{
		return GIB_LEGS_RIGHT_LEG_GONE_MODEL( entity );
	}
	else if ( leftLegGibbed )
	{
		return GIB_LEGS_LEFT_LEG_GONE_MODEL( entity );
	}
	
	return GIB_LEGS_UNDAMAGED_MODEL( entity );
}

function private _GetGibbedState( entity )
{
	if ( IsDefined( entity.gib_state ) )
	{
		return entity.gib_state;
	}
	
	return GIB_UNDAMAGED_FLAG;
}

function private _GetGibbedTorsoModel( entity )
{
	gibState = _GetGibbedState( entity );
	rightArmGibbed = IS_GIBBED( gibState, GIB_TORSO_RIGHT_ARM_FLAG);
	leftArmGibbed = IS_GIBBED( gibState, GIB_TORSO_LEFT_ARM_FLAG);
	
	if ( rightArmGibbed && leftArmGibbed )
	{
		return GIB_TORSO_RIGHT_ARM_GONE_MODEL( entity );
		
		// TODO(David Young 5-14-14): Currently AI's don't support both arms getting blown off.
		// return GIB_TORSO_NO_ARMS_MODEL( entity );
	}
	else if ( rightArmGibbed )
	{
		return GIB_TORSO_RIGHT_ARM_GONE_MODEL( entity );
	}
	else if ( leftArmGibbed )
	{
		return GIB_TORSO_LEFT_ARM_GONE_MODEL( entity );
	}
	
	return GIB_TORSO_UNDAMAGED_MODEL( entity );
}

function private _HasGibDef( entity )
{
	return IsDefined( entity.gibdef );
}

function private _HasGibPieces( entity, gibFlag )
{
	hasGibPieces = false;
	gibState = _GetGibbedState( entity );
	entity.gib_state = SET_GIBBED( gibState, gibFlag );
	
	if ( IsDefined( _GetGibbedTorsoModel( entity ) ) &&
		IsDefined( _GetGibbedLegModel( entity ) ) )
	{
		hasGibPieces = true;
	}
	
	entity.gib_state = gibState;
	
	return hasGibPieces;
}

function private _SetGibbed( entity, gibFlag, gibDir )
{
	if ( IsDefined( gibDir ) )
	{
		angles = VectortoAngles( gibDir );
		yaw = angles[1];
		yaw_bits = getbitsforangle( yaw, GIB_DIR_BITS );
		entity.gib_state = SET_GIBBED_PLAYER( _GetGibbedState( entity ), gibFlag, yaw_bits );
	}
	else
	{
		entity.gib_state = SET_GIBBED( _GetGibbedState( entity ), gibFlag );	
	}

	entity.gibbed = true;
	
	entity clientfield::set( GIB_CLIENTFIELD, entity.gib_state );
}

function Annihilate( entity )
{
	if ( !_HasGibDef( entity ) )
	{
		return false;
	}

	gibBundle = GET_GIB_BUNDLE( entity.gibdef );
	
	if ( !IsDefined( gibBundle ) || !IsDefined( gibBundle.gibs ) )
	{
		return false;
	}
	
	gibPieceStruct = gibBundle.gibs[ GIB_ANNIHILATE_FLAG ];
	
	// Make sure there is some sort of FX to play if we're annihilating the AI.
	if ( IsDefined( gibPieceStruct ) )
	{
		if ( IsDefined( gibPieceStruct.gibfx ) )
		{
			_SetGibbed( entity, GIB_ANNIHILATE_FLAG, undefined );

			entity thread _Annihilate( entity );
			return true;
		}
	}
	
	return false;
}

function CopyGibState( originalEntity, newEntity )
{
	newEntity.gib_state = _GetGibbedState( originalEntity );
	
	ToggleSpawnGibs( newEntity, false );
	
	ReapplyHiddenGibPieces( newEntity );
}

function IsGibbed( entity, gibFlag )
{
	return IS_GIBBED( _GetGibbedState( entity ), gibFlag );
}

function GibHat( entity )
{
	return _GibExtra( entity, GIB_HEAD_HAT_FLAG );
}

function GibHead( entity )
{
	GibHat( entity );
	
	return _GibExtra( entity, GIB_TORSO_HEAD_FLAG );
}

function GibLeftArm( entity )
{
	// TODO(David Young 5-14-14): Currently AI's don't support both arms getting blown off.
	if ( IsGibbed( entity, GIB_TORSO_RIGHT_ARM_FLAG ) )
	{
		return false;
	}
	
	if ( _GibEntity( entity, GIB_TORSO_LEFT_ARM_FLAG ) )
	{
		DestructServerUtils::DestructLeftArmPieces( entity );
		return true;
	}
	
	return false;
}

function GibRightArm( entity )
{
	// TODO(David Young 5-14-14): Currently AI's don't support both arms getting blown off.
	if ( IsGibbed( entity, GIB_TORSO_LEFT_ARM_FLAG ) )
	{
		return false;
	}

	if ( _GibEntity( entity, GIB_TORSO_RIGHT_ARM_FLAG ) )
	{
		DestructServerUtils::DestructRightArmPieces( entity );
		entity thread shared::DropAIWeapon();
		return true;
	}

	return false;
}

function GibLeftLeg( entity )
{
	if ( _GibEntity( entity, GIB_LEGS_LEFT_LEG_FLAG ) )
	{
		DestructServerUtils::DestructLeftLegPieces( entity );
		return true;
	}
	
	return false;
}

function GibRightLeg( entity )
{
	if ( _GibEntity( entity, GIB_LEGS_RIGHT_LEG_FLAG ) )
	{
		DestructServerUtils::DestructRightLegPieces( entity );
		return true;
	}
	
	return false;
}

function GibLegs( entity )
{
	if ( _GibEntity( entity, GIB_LEGS_BOTH_LEGS_FLAG ) )
	{
		DestructServerUtils::DestructRightLegPieces( entity );
		DestructServerUtils::DestructLeftLegPieces( entity );
		return true;
	}
	
	return false;
}

function PlayerGibLeftArm( entity )
{
	if ( IsDefined( entity.body ) )
	{
		dir = (1,0,0);
		_SetGibbed( entity.body, GIB_TORSO_LEFT_ARM_FLAG, dir );
	}
}

function PlayerGibRightArm( entity )
{
	if ( IsDefined( entity.body ) )
	{
		dir = (1,0,0);
		_SetGibbed( entity.body, GIB_TORSO_RIGHT_ARM_FLAG, dir );
	}
}

function PlayerGibLeftLeg( entity )
{
	if ( IsDefined( entity.body ) )
	{
		dir = (1,0,0);
		_SetGibbed( entity.body, GIB_LEGS_LEFT_LEG_FLAG, dir );
	}
}

function PlayerGibRightLeg( entity )
{
	if ( IsDefined( entity.body ) )
	{
		dir = (1,0,0);
		_SetGibbed( entity.body, GIB_LEGS_RIGHT_LEG_FLAG, dir );
	}
}

function PlayerGibLegs( entity )
{
	if ( IsDefined( entity.body ) )
	{
		dir = (1,0,0);
		_SetGibbed( entity.body, GIB_LEGS_RIGHT_LEG_FLAG, dir );
		_SetGibbed( entity.body, GIB_LEGS_LEFT_LEG_FLAG, dir );
	}
}

function PlayerGibLeftArmVel( entity, dir )
{
	if ( IsDefined( entity.body ) )
	{
		_SetGibbed( entity.body, GIB_TORSO_LEFT_ARM_FLAG, dir );
	}
}

function PlayerGibRightArmVel( entity, dir )
{
	if ( IsDefined( entity.body ) )
	{
		_SetGibbed( entity.body, GIB_TORSO_RIGHT_ARM_FLAG, dir );
	}
}

function PlayerGibLeftLegVel( entity, dir )
{
	if ( IsDefined( entity.body ) )
	{
		_SetGibbed( entity.body, GIB_LEGS_LEFT_LEG_FLAG, dir );
	}
}

function PlayerGibRightLegVel( entity, dir )
{
	if ( IsDefined( entity.body ) )
	{
		_SetGibbed( entity.body, GIB_LEGS_RIGHT_LEG_FLAG, dir );
	}
}

function PlayerGibLegsVel( entity, dir )
{
	if ( IsDefined( entity.body ) )
	{
		_SetGibbed( entity.body, GIB_LEGS_RIGHT_LEG_FLAG, dir );
		_SetGibbed( entity.body, GIB_LEGS_LEFT_LEG_FLAG, dir );
	}
}

function ReapplyHiddenGibPieces( entity )
{
	if ( !_HasGibDef( entity ) )
	{
		return;
	}
	
	gibBundle = GET_GIB_BUNDLE( entity.gibdef );
	
	foreach ( gibFlag, gib in gibBundle.gibs )
	{
		if ( !IsGibbed( entity, gibFlag ) )
		{
			continue;
		}
		
		if ( IsDefined( gib.gibhidetag ) && IsAlive( entity ) && entity HasPart( gib.gibhidetag ) )
		{
			if ( !IS_TRUE( entity.skipDeath ) )
			{
				// Gighidetag's are only used for hiding hitlocations.  If the entity is already dead or skipping death animations don't apply them.
				entity HidePart( gib.gibhidetag, "", true );
			}
		}
	}
}

function ShowHiddenGibPieces( entity )
{
	if ( !_HasGibDef( entity ) )
	{
		return;
	}
	
	gibBundle = GET_GIB_BUNDLE( entity.gibdef );
	
	foreach ( gibFlag, gib in gibBundle.gibs )
	{
		if ( IsDefined( gib.gibhidetag ) && entity HasPart( gib.gibhidetag ) )
		{
			entity ShowPart( gib.gibhidetag, "", true );
		}
	}
}

function ToggleSpawnGibs( entity, shouldSpawnGibs )
{
	if ( !shouldSpawnGibs )
	{
		entity.gib_state = _GetGibbedState( entity ) | GIB_TOGGLE_GIB_MODEL_FLAG;
	}
	else
	{
		entity.gib_state = _GetGibbedState( entity ) & ~GIB_TOGGLE_GIB_MODEL_FLAG;
	}
	
	entity clientfield::set( GIB_CLIENTFIELD, entity.gib_state );
}
