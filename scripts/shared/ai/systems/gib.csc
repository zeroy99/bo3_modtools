#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#namespace GibClientUtils;

function autoexec main()
{

	clientfield::register(
		"actor",
		GIB_CLIENTFIELD,
		VERSION_SHIP,
		GIB_CLIENTFIELD_BITS_ACTOR,
		GIB_CLIENTFIELD_TYPE,
		&GibClientUtils::_GibHandler,
		!CF_HOST_ONLY,
		!CF_CALLBACK_ZERO_ON_NEW_ENT);

	clientfield::register(
		"playercorpse",
		GIB_CLIENTFIELD,
		VERSION_SHIP,
		GIB_CLIENTFIELD_BITS_PLAYER,
		GIB_CLIENTFIELD_TYPE,
		&GibClientUtils::_GibHandler,
		!CF_HOST_ONLY,
		!CF_CALLBACK_ZERO_ON_NEW_ENT);

	gibDefinitions = GET_GIB_BUNDLES();
	
	gibPieceLookup = [];
	gibPieceLookup[GIB_ANNIHILATE_FLAG] = "annihilate";
	gibPieceLookup[GIB_TORSO_HEAD_FLAG] = "head";
	gibPieceLookup[GIB_TORSO_RIGHT_ARM_FLAG] = "rightarm";
	gibPieceLookup[GIB_TORSO_LEFT_ARM_FLAG] = "leftarm";
	gibPieceLookup[GIB_LEGS_RIGHT_LEG_FLAG] = "rightleg";
	gibPieceLookup[GIB_LEGS_LEFT_LEG_FLAG] = "leftleg";
	
	processedBundles = [];
	
	// Process each gib bundle to allow quick access to information in the future.
	foreach ( definitionName, definition in gibDefinitions )
	{
		gibBundle = SpawnStruct();
		gibBundle.gibs = [];
		gibBundle.name = definitionName;
		
		foreach ( gibPieceFlag, gibPieceName in gibPieceLookup )
		{
			gibStruct = SpawnStruct();
			gibStruct.gibmodel = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibmodel" );
			gibStruct.gibtag = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibtag" );
			gibStruct.gibfx = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibfx" );
			gibStruct.gibfxtag = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibeffecttag" );
			gibStruct.gibdynentfx = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibdynentfx" );
			gibStruct.gibsound = GetStructField( definition, gibPieceLookup[ gibPieceFlag ] + "_gibsound" );
				
			gibBundle.gibs[ gibPieceFlag ] = gibStruct;
		}
		
		processedBundles[ definitionName ] = gibBundle;
	}
	
	// Replaces all gib character define bundles with their processed form to free unncessary script variables.
	level.scriptbundles[ "gibcharacterdef" ] = processedBundles;
	
	// Thread that handles any corpse annihilate request.
	level thread _AnnihilateCorpse();
}

#define MIN_DISTANCE_SQ ( 120 * 120 )
function private _AnnihilateCorpse()
{
	while( true )
	{
		level waittill( "corpse_explode", localClientNum, body, origin );
		
		if ( !util::is_mature() || util::is_gib_restricted_build() )
		{
			continue;
		}
		
		if ( IsDefined( body ) && _HasGibDef( body ) && body IsRagdoll() )
		{
			ClientEntGibHead( localClientNum, body );
			ClientEntGibRightArm( localClientNum, body );
			ClientEntGibLeftArm( localClientNum, body );
			ClientEntGibRightLeg( localClientNum, body );
			ClientEntGibLeftLeg( localClientNum, body );
		}
		
		// TODO(David Young 6-8-15): Human bodies are currently the only supported gibbable corpse.
		// Need to add support to the gib definition to flag if a corpse can be annihilated instead.
		if( IsDefined( body ) && _HasGibDef( body ) && body.archetype == ARCHETYPE_HUMAN )
		{
			// Only allow human gibbing at a 50% rate.
			if ( RandomInt( 100 ) >= 50 )
			{
				continue;
			}
		
			if ( IsDefined( origin ) && DistanceSquared( body.origin, origin ) <= MIN_DISTANCE_SQ )
			{
				// Toggle hiding the ragdoll.
				body.ignoreRagdoll = true;

				body _GibEntity(
					localClientNum,
					GIB_ANNIHILATE_FLAG |
					GIB_TORSO_RIGHT_ARM_FLAG |
					GIB_TORSO_LEFT_ARM_FLAG |
					GIB_LEGS_BOTH_LEGS_FLAG,
					true );
			}
		}
	}
}

function private _CloneGibData( localClientNum, entity, clone )
{
	clone.gib_data = SpawnStruct();

	// Copy gib data.
	clone.gib_data.gib_state = entity.gib_state;
	clone.gib_data.gibdef = entity.gibdef;
	
	// Copy all model data.
	clone.gib_data.hatmodel = entity.hatmodel;
	clone.gib_data.head = entity.head;
	clone.gib_data.legdmg1 = entity.legdmg1;
	clone.gib_data.legdmg2 = entity.legdmg2;
	clone.gib_data.legdmg3 = entity.legdmg3;
	clone.gib_data.legdmg4 = entity.legdmg4;
	clone.gib_data.torsodmg1 = entity.torsodmg1;
	clone.gib_data.torsodmg2 = entity.torsodmg2;
	clone.gib_data.torsodmg3 = entity.torsodmg3;
	clone.gib_data.torsodmg4 = entity.torsodmg4;
	clone.gib_data.torsodmg5 = entity.torsodmg5;
}

function private _GetGibDef( entity )
{
	if ( entity IsPlayer() || entity IsPlayerCorpse() )
	{
		return entity GetPlayerGibDef();
	}
	else if ( IsDefined( entity.gib_data ) )
	{
		return entity.gib_data.gibdef;
	}
	
	return entity.gibdef;
}

function private _GetGibbedState( localClientNum, entity )
{
	if ( IsDefined( entity.gib_data ) && IsDefined( entity.gib_data.gib_state ) )
	{
		return entity.gib_data.gib_state;
	}
	else if ( IsDefined( entity.gib_state ) )
	{
		return entity.gib_state;
	}
	
	return GIB_UNDAMAGED_FLAG;
}

function private _GetGibbedLegModel( localClientNum, entity )
{
	gibState = _GetGibbedState( localClientNum, entity );
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

function private _GetGibExtraModel( localClientNumm, entity, gibFlag )
{
	if ( gibFlag == GIB_HEAD_HAT_FLAG )
		return GIB_HAT_MODEL( entity );
	else if ( gibFlag == GIB_TORSO_HEAD_FLAG )
		return GIB_HEAD_MODEL( entity );
	else
		AssertMsg( "Unable to find gib model." );
}

function private _GetGibbedTorsoModel( localClientNum, entity )
{
	gibState = _GetGibbedState( localClientNum, entity );
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

function private _GibPieceTag( localClientNum, entity, gibFlag )
{
	if ( !_HasGibDef( self ) )
	{
		return;
	}
	
	gibBundle = GET_GIB_BUNDLE( _GetGibDef( entity ) );
	gibPiece = gibBundle.gibs[ gibFlag ];
	
	if ( IsDefined( gibPiece ) )
	{
		return gibPiece.gibfxtag;
	}
}

function private _GibEntity( localClientNum, gibFlags, shouldSpawnGibs )
{
	entity = self;

	if ( !_HasGibDef( entity ) )
	{
		return;
	}
	
	// Skip the toggle flag, GIB_TOGGLE_GIB_MODEL_FLAG.
	currentGibFlag = GIB_ANNIHILATE_FLAG;
	gibDir = undefined;
	
	if ( entity IsPlayer() || entity IsPlayerCorpse() )
	{
		// TODO(David Young 6-8-15): Add support for yaw bits for AI as well.
		yaw_bits = GET_GIB_DIR_BITS( gibFlags );
		yaw = getanglefrombits( yaw_bits, GIB_DIR_BITS );
		gibDir = AnglesToForward( ( 0, yaw, 0 ) );
	}
	
	gibBundle = GET_GIB_BUNDLE( _GetGibDef( entity ) );
	
	// Handles any number of simultaneous gibbings.
	while ( gibFlags >= currentGibFlag )
	{
		if ( gibFlags & currentGibFlag )
		{
			gibPiece = gibBundle.gibs[ currentGibFlag ];
		
			if ( IsDefined( gibPiece ) )
			{
				if ( shouldSpawnGibs )
				{
					entity thread _GibPiece( localClientNum, entity, gibPiece.gibmodel, gibPiece.gibtag, gibPiece.gibdynentfx, gibDir );
				}
				
				_PlayGibFX( localClientNum, entity, gibPiece.gibfx, gibPiece.gibfxtag );
				_PlayGibSound( localClientNum, entity, gibPiece.gibsound );
				
				if ( currentGibFlag == GIB_ANNIHILATE_FLAG )
				{
					entity Hide();
					entity.ignoreRagdoll = true;
				}
			}
			
			_HandleGibCallbacks( localClientNum, entity, currentGibFlag );
		}
		
		currentGibFlag = currentGibFlag << 1;
	}
}

function private _SetGibbed( localClientNum, entity, gibFlag )
{
	gib_state = SET_GIBBED( _GetGibbedState( localClientNum, entity ), gibFlag );
	
	if ( IsDefined( entity.gib_data ) )
	{
		entity.gib_data.gib_state = gib_state;
	}
	else
	{
		entity.gib_state = gib_state;
	}
}

function private _GibClientEntityInternal( localClientNum, entity, gibFlag )
{
	if ( !util::is_mature() || util::is_gib_restricted_build() )
	{
		return;
	}

	if ( !IsDefined( entity ) || !_HasGibDef( entity ) )
	{
		return;
	}
	
	if ( entity.type !== "scriptmover" )
	{
		// Clientside gibbing currently only supports script models.
		return;
	}
	
	if ( IsGibbed( localClientNum, entity, gibFlag ) )
	{
		return;
	}

	if ( !IS_BODY_UNDAMAGED( _GetGibbedState( localClientNum, entity ) ) )
	{
		legModel = _GetGibbedLegModel( localClientNum, entity );
		entity Detach( legModel, "" );
	}
	
	_SetGibbed( localClientNum, entity, gibFlag );
	
	entity SetModel( _GetGibbedTorsoModel( localClientNum, entity ) );
	entity Attach( _GetGibbedLegModel( localClientNum, entity ), "" );
	
	entity _GibEntity( localClientNum, gibFlag, true );
}

function private _GibClientExtraInternal( localClientNum, entity, gibFlag )
{
	if ( !util::is_mature() || util::is_gib_restricted_build() )
	{
		return;
	}

	if ( !IsDefined( entity ) )
	{
		return;
	}
	
	if ( entity.type !== "scriptmover" )
	{
		// Clientside gibbing currently only supports script models.
		return;
	}
	
	if ( IsGibbed( localClientNum, entity, gibFlag ) )
	{
		return;
	}
	
	gibModel = _GetGibExtraModel( localClientNum, entity, gibFlag );
	
	if ( IsDefined( gibModel ) && entity IsAttached( gibModel, "" ) )
	{
		entity Detach( gibModel, "" );
	}
	
	if ( gibFlag == GIB_TORSO_HEAD_FLAG )
	{
		if ( IsDefined( GIB_TORSO_HEAD_GONE_MODEL( entity ) ) )
		{
			entity Attach( GIB_TORSO_HEAD_GONE_MODEL( entity ), "" ); 
		}
	}

	_SetGibbed( localClientNum, entity, gibFlag );
	entity _GibEntity( localClientNum, gibFlag, true );
}

function private _GibHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	entity = self;
	
	if ( entity IsPlayer() || entity IsPlayerCorpse() )
	{
		if ( !util::is_mature() || util::is_gib_restricted_build() )
		{
			return;
		}
	}
	else
	{
		if ( IsDefined( entity.maturegib ) && entity.maturegib && !util::is_mature() )
		{
			return;
		}
		
		if ( IsDefined( entity.restrictedgib ) && entity.restrictedgib && !IsShowGibsEnabled() )
		{
			return;
		}
	}
	
	gibFlags = GET_GIB_FLAG( oldValue, newValue );
	shouldSpawnGibs = SHOULD_SPAWN_GIBS( newValue );
	
	// Don't use the old clientfield value for new entities.
	if ( bNewEnt )
	{
		gibFlags = GET_GIB_FLAG( 0, newValue );
	}
	
	entity _GibEntity( localClientNum, gibFlags, shouldSpawnGibs );
	
	entity.gib_state = newValue;
}

function _GibPiece( localClientNum, entity, gibModel, gibTag, gibFx, gibDir )
{
	if ( !IsDefined( gibTag ) || !IsDefined( gibModel ) )
	{
		return;
	}

	startPosition = entity GetTagOrigin( gibTag );
	startAngles = entity GetTagAngles( gibTag );
	endPosition = startPosition;
	endAngles = startAngles;
	forwardVector = undefined;
	
	if ( !IsDefined( startPosition ) || !IsDefined( startAngles ) )
	{
		return false;
	}
	
	if ( IsDefined( gibDir ) )
	{
		startPosition = (0,0,0);
		forwardVector = gibDir;
		// TODO: define the scale on the server from the damage
		forwardVector *= RandomFloatRange( 100.0, 500.0 );
	}
	else
	{
		// Let a frame pass to approximate the linear and angular velocity of the tag.
		WAIT_CLIENT_FRAME;
		
		if ( IsDefined( entity ) )
		{
			endPosition = entity GetTagOrigin( gibTag );
			endAngles = entity GetTagAngles( gibTag );
		}
		else
		{
			// Entity already removed.
			endPosition = startPosition + ( AnglesToForward( startAngles ) * 10 );
			endAngles = startAngles;
		}
		
		if ( !IsDefined( endPosition ) || !IsDefined( endAngles ) )
		{
			return false;
		}
		
		forwardVector = VectorNormalize( endPosition - startPosition );
		forwardVector *= RandomFloatRange( 0.6, 1.0 );
		forwardVector += ( RandomFloatRange( 0, 0.2 ), RandomFloatRange( 0, 0.2 ), RandomFloatRange( 0.2, 0.7 ) );
	}

	if( IsDefined( entity ) )
	{
		gibEntity = CreateDynEntAndLaunch( localClientNum, gibModel, endPosition, endAngles, startPosition, forwardVector, gibFx, true );
		if ( IsDefined( gibEntity ) )
		{
			SetDynEntBodyRenderOptionsPacked( gibEntity, entity GetBodyRenderOptionsPacked() );
		}
	}
}

function private _HandleGibCallbacks( localClientNum, entity, gibFlag )
{
	if ( IsDefined( entity._gibCallbacks ) &&
		IsDefined( entity._gibCallbacks[gibFlag] ) )
	{
		foreach ( callback in entity._gibCallbacks[gibFlag] )
		{
			[[callback]]( localClientNum, entity, gibFlag );
		}
	}
}

function private _HandleGibAnnihilate( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib_annihilate" );
	GibClientUtils::ClientEntGibAnnihilate( localClientNum, entity );
}

function private _HandleGibHead( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib = \"head\"" );
	GibClientUtils::ClientEntGibHead( localClientNum, entity );
}

function private _HandleGibRightArm( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib = \"arm_right\"" );
	GibClientUtils::ClientEntGibRightArm( localClientNum, entity );
}

function private _HandleGibLeftArm( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib = \"arm_left\"" );
	GibClientUtils::ClientEntGibLeftArm( localClientNum, entity );
}

function private _HandleGibRightLeg( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib = \"leg_right\"" );
	GibClientUtils::ClientEntGibRightLeg( localClientNum, entity );
}

function private _HandleGibLeftLeg( localClientNum )
{
	entity = self;
	entity endon( "entityshutdown" );
	
	entity waittillmatch( "_anim_notify_", "gib = \"leg_left\"" );
	GibClientUtils::ClientEntGibLeftLeg( localClientNum, entity );
}

function private _HasGibDef( entity )
{
	return ( IsDefined( entity.gib_data ) && IsDefined( entity.gib_data.gibdef ) ) ||
		IsDefined( entity.gibdef ) ||
		( ( entity GetPlayerGibDef() ) != "unknown" );
}

function _PlayGibFX( localClientNum, entity, fxFileName, fxTag )
{
	if ( IsDefined( fxFileName ) && IsDefined( fxTag ) && entity hasDobj(localClientNum) )
	{
		fx = PlayFxOnTag( localClientNum, fxFileName, entity, fxTag );
		if(isDefined(fx))
		{
			if(isDefined(entity.team))
			{
				SetFxTeam( localClientNum, fx, entity.team );
			}
		
			if( IS_TRUE( level.SetGibFXToIgnorePause ) )
			{
				SetFXIgnorePause( localClientNum, fx, true );
			}
		}
		
		return fx;
	}
}

function _PlayGibSound( localClientNum, entity, soundAlias )
{
	if ( IsDefined( soundAlias ) )
	{
		PlaySound( localClientNum, soundAlias, entity.origin );
	}
}

/@
"Name: AddGibCallback( localClientNum, entity, gibFlag, callbackFunction )"
"Summary: Register a function callback that is called when the corresponding piece is gibbed."
"MandatoryArg: <num> : Client number."
"MandatoryArg: <entity> : Entity to add callbacks to."
"MandatoryArg: <num> : Gib piece to register for."
"MandatoryArg: <function> : Function to call, function is passed the localClientNum, entity, and gibFlag."
"Module: Gib"
@/
function AddGibCallback( localClientNum, entity, gibFlag, callbackFunction )
{
	assert( IsFunctionPtr( callbackFunction ) );

	if ( !IsDefined( entity._gibCallbacks ) )
	{
		entity._gibCallbacks = [];
	}

	if ( !IsDefined( entity._gibCallbacks[gibFlag] ) )
	{
		entity._gibCallbacks[gibFlag] = [];
	}
	
	gibCallbacks = entity._gibCallbacks[gibFlag];
	gibCallbacks[gibCallbacks.size] = callbackFunction;
	entity._gibCallbacks[gibFlag] = gibCallbacks;
}

function ClientEntGibAnnihilate( localClientNum, entity )
{
	if ( !util::is_mature() || util::is_gib_restricted_build() )
	{
		return;
	}

	// Toggle hiding the ragdoll.
	entity.ignoreRagdoll = true;

	entity _GibEntity(
		localClientNum,
		GIB_ANNIHILATE_FLAG |
		GIB_TORSO_RIGHT_ARM_FLAG |
		GIB_TORSO_LEFT_ARM_FLAG |
		GIB_LEGS_BOTH_LEGS_FLAG,
		true );
}

function ClientEntGibHead( localClientNum, entity )
{
	_GibClientExtraInternal( localClientNum, entity, GIB_HEAD_HAT_FLAG );
	_GibClientExtraInternal( localClientNum, entity, GIB_TORSO_HEAD_FLAG );
}

function ClientEntGibLeftArm( localClientNum, entity )
{
	if ( IsGibbed( localClientNum, entity, GIB_TORSO_RIGHT_ARM_FLAG ) )
	{
		return;
	}

	_GibClientEntityInternal( localClientNum, entity, GIB_TORSO_LEFT_ARM_FLAG );
}

function ClientEntGibRightArm( localClientNum, entity )
{
	if ( IsGibbed( localClientNum, entity, GIB_TORSO_LEFT_ARM_FLAG ) )
	{
		return;
	}

	_GibClientEntityInternal( localClientNum, entity, GIB_TORSO_RIGHT_ARM_FLAG );
}

function ClientEntGibLeftLeg( localClientNum, entity )
{
	_GibClientEntityInternal( localClientNum, entity, GIB_LEGS_LEFT_LEG_FLAG );
}

function ClientEntGibRightLeg( localClientNum, entity )
{
	_GibClientEntityInternal( localClientNum, entity, GIB_LEGS_RIGHT_LEG_FLAG );
}

function CreateScriptModelOfEntity( localClientNum, entity )
{
	clone = Spawn( localClientNum, entity.origin, "script_model" );
	clone.angles = entity.angles;
	
	_CloneGibData( localClientNum, entity, clone );
	gibState = _GetGibbedState( localClientNum, clone );
	
	if ( !util::is_mature() || util::is_gib_restricted_build() )
	{
		// Don't display gibbed entities for non-mature clients.
		gibState = GIB_UNDAMAGED_FLAG;
	}
	
	if ( !IS_BODY_UNDAMAGED( _GetGibbedState( localClientNum, entity ) ) )
	{
		// Attach torso or full body model.
		clone SetModel( _GetGibbedTorsoModel( localClientNum, entity ) );
		// Only attach separate legs if the body is damage already.
		clone Attach( _GetGibbedLegModel( localClientNum, entity ), "" );
	}
	else
	{
		// Attach full body model.
		clone SetModel( entity.model );
	}
	
	if ( IS_GIBBED( gibState, GIB_TORSO_HEAD_FLAG ) )
	{
		// Attach head stump.
		if ( IsDefined( GIB_TORSO_HEAD_GONE_MODEL( clone ) ) )
		{
			clone Attach( GIB_TORSO_HEAD_GONE_MODEL( clone ), "" ); 
		}
	}
	else
	{
		// Attach head.
		if ( IsDefined( GIB_HEAD_MODEL( clone ) ) )
		{
			clone Attach( GIB_HEAD_MODEL( clone ), "" );
		}
		
		if ( !IS_GIBBED( gibState, GIB_HEAD_HAT_FLAG ) && IsDefined( GIB_HAT_MODEL( clone ) ) )
		{
			clone Attach( GIB_HAT_MODEL( clone ), "" );
		}
	}
	
	return clone;
}

function IsGibbed( localClientNum, entity, gibFlag )
{
	return IS_GIBBED( _GetGibbedState( localClientNum, entity ), gibFlag );
}

function IsUndamaged( localClientNum, entity )
{
	return _GetGibbedState( localClientNum, entity ) == GIB_UNDAMAGED_FLAG;
}

function GibEntity( localClientNum, gibFlags )
{	
	self _GibEntity( localClientNum, gibFlags, true );
	
	self.gib_state = SET_GIBBED( _GetGibbedState( localClientNum, self ), gibFlags );
}

function HandleGibNotetracks( localClientNum )
{
	entity = self;
	
	entity thread _HandleGibAnnihilate( localClientNum );
	entity thread _HandleGibHead( localClientNum );
	entity thread _HandleGibRightArm( localClientNum );
	entity thread _HandleGibLeftArm( localClientNum );
	entity thread _HandleGibRightLeg( localClientNum );
	entity thread _HandleGibLeftLeg( localClientNum );
}

function PlayerGibLeftArm( localClientNum )
{	
	self GibEntity( localClientNum, GIB_TORSO_LEFT_ARM_FLAG );
}

function PlayerGibRightArm( localClientNum )
{
	self GibEntity( localClientNum, GIB_TORSO_RIGHT_ARM_FLAG );
}

function PlayerGibLeftLeg( localClientNum )
{
	self GibEntity( localClientNum, GIB_LEGS_LEFT_LEG_FLAG );
}

function PlayerGibRightLeg( localClientNum )
{
	self GibEntity( localClientNum, GIB_LEGS_RIGHT_LEG_FLAG );
}

function PlayerGibLegs( localClientNum )
{
	self GibEntity( localClientNum, GIB_LEGS_RIGHT_LEG_FLAG );
	self GibEntity( localClientNum, GIB_LEGS_LEFT_LEG_FLAG );
}

function PlayerGibTag( localClientNum, gibFlag )
{	
	return _GibPieceTag( localClientNum, self, gibFlag );
}

