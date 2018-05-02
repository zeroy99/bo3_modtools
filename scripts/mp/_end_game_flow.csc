#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\end_game_taunts;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\weapons\weapon_group_anims.gsh;

#define HERO_HELMET_BONE ""
#define WEAPON_NONE "wpn_t7_none_world"

#define RUNNER_UP_GESTURE_DELAY	3

#using_animtree("all_player");
#namespace end_game_flow;

REGISTER_SYSTEM( "end_game_flow", &__init__, undefined )

function __init__()
{
	clientfield::register( "world", "displayTop3Players", VERSION_SHIP, 1, "int", &handleTopThreePlayers, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "triggerScoreboardCamera", VERSION_SHIP, 1, "int", &showScoreboard, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "playTop0Gesture", VERSION_TU1, 3, "int", &handlePlayTop0Gesture, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "playTop1Gesture", VERSION_TU1, 3, "int", &handlePlayTop1Gesture, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "playTop2Gesture", VERSION_TU1, 3, "int", &handlePlayTop2Gesture, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	level thread streamerWatcher();
}

function setAnimationOnModel( localClientNum, characterModel, topPlayerIndex )
{
	anim_name = end_game_taunts::getidleanimname( localClientNum, characterModel, topPlayerIndex );
	
	if( isDefined(anim_name) )
	{
		characterModel util::waittill_dobj( localClientNum );

		if( !characterModel HasAnimTree() )
		{
			characterModel UseAnimTree( #animtree );
		}

		characterModel SetAnim( anim_name );
	}
}


function loadCharacterOnModel( localClientNum, characterModel, topPlayerIndex )
{
	assert( isdefined( characterModel ) );

	// swap out our body
	bodyModel = GetTopPlayersBodyModel( localClientNum, topPlayerIndex );
	displayTopPlayerModel = CreateUIModel( GetUIModelForController( localClientNum ), "displayTopPlayer" + (topPlayerIndex+1) );
	SetUIModelValue( displayTopPlayerModel, 1 );

	// This happens when the client has never spawned in, we should not show his model and not show his playercard as well.
	if ( !IsDefined( bodyModel ) || bodymodel == "" )
	{
		SetUIModelValue( displayTopPlayerModel, 0 );
		return;
	}

	characterModel SetModel( bodyModel );

	// swap out our helmet
	helmetModel = GetTopPlayersHelmetModel( localClientNum, topPlayerIndex );

	if ( !( characterModel IsAttached( helmetModel, HERO_HELMET_BONE ) ) )
	{
		characterModel.helmetModel = helmetModel;	// Keep refcount on this string because we'll need it later
		characterModel Attach( helmetModel, HERO_HELMET_BONE );
	}

	// set up our render options
	modeRenderOptions =  GetCharacterModeRenderOptions( CurrentSessionMode() );
	bodyRenderOptions = GetTopPlayersBodyRenderOptions( localClientNum, topPlayerIndex );
	helmetRenderOptions = GetTopPlayersHelmetRenderOptions( localClientNum, topPlayerIndex );
	weaponRenderOptions = GetTopPlayersWeaponRenderOptions( localClientNum, topPlayerIndex );

	// Used by epic taunts to clone the model and match skins
	characterModel.bodyModel = bodyModel;
	// Headmodel is attached above
	characterModel.modeRenderOptions = modeRenderOptions;
	characterModel.bodyRenderOptions = bodyRenderOptions;
	characterModel.helmetRenderOptions = helmetRenderOptions;
	characterModel.headRenderOptions = helmetRenderOptions;
		
	weapon_right = GetTopPlayersWeaponInfo( localClientNum, topPlayerIndex );

	if ( !isDefined( level.weaponNone ) )
	{
	  	level.weaponNone = GetWeapon( "none" );
	}

	characterModel SetBodyRenderOptions( modeRenderOptions, bodyRenderOptions, helmetRenderOptions, helmetRenderOptions );

	if ( weapon_right["weapon"] == level.weaponNone )
	{
		weapon_right["weapon"] = GetWeapon("ar_standard");
		characterModel.showcaseWeapon = weapon_right["weapon"];
		characterModel AttachWeapon( weapon_right["weapon"] );
	}
	else
	{
		characterModel.showcaseWeapon = weapon_right["weapon"];
		characterModel.showcaseWeaponRenderOptions = weaponRenderOptions;
		characterModel.showcaseWeaponACVI = weapon_right["acvi"];

		characterModel AttachWeapon( weapon_right["weapon"], weaponRenderOptions, weapon_right["acvi"] );
		characterModel UseWeaponHideTags( weapon_right["weapon"] );
	}
}



function setupModelAndAnimation( localClientNum, characterModel, topPlayerIndex )
{
	characterModel endon("entityshutdown");

	loadCharacterOnModel( localClientNum, characterModel, topPlayerIndex );
	setAnimationOnModel( localClientNum, characterModel, topPlayerIndex );
}



function prepareTopThreePlayers( localClientNum )
{
	numClients = GetTopScorerCount( localClientNum );
	position = struct::get( "endgame_top_players_struct", "targetname" );

	if( !isdefined( position ) )
	{
		return;
	}

	for( index = 0; index < 3; index++ )
	{
		if ( index < numClients )
		{
			model = Spawn( localClientNum, position.origin, "script_model" );
			loadCharacterOnModel( localClientNum, model, index );
			model Hide();
			model SetHighDetail( true );
		}
	}
}

function showTopThreePlayers( localClientNum )
{
	level.topPlayerCharacters = [];
	topPlayerScriptStructs = [];

	topPlayerScriptStructs[0] = struct::get( "TopPlayer1", "targetname" );
	topPlayerScriptStructs[1] = struct::get( "TopPlayer2", "targetname" );
	topPlayerScriptStructs[2] = struct::get( "TopPlayer3", "targetname" );

	foreach( index, scriptStruct in topPlayerScriptStructs )
	{
		level.topPlayerCharacters[index] = Spawn( localClientNum, scriptStruct.origin, "script_model" );
		// level.topPlayerCharacters[index] SetDedicatedShadow( true );
		level.topPlayerCharacters[index].angles = scriptStruct.angles;
	}
	numClients = GetTopScorerCount( localClientNum );

	foreach( index, characterModel in level.topPlayerCharacters )
	{
		if ( index < numClients )
		{
			thread setupModelAndAnimation( localClientNum, characterModel, index );

			if ( index == 0  )
			{
				thread end_game_taunts::playCurrentTaunt( localClientNum, characterModel, index );
			}
		}
	}

	position = struct::get( "endgame_top_players_struct", "targetname" );
	PlayMainCamXCam( localClientNum, level.endGameXCamName, 0, "cam_topscorers", "topscorers", position.origin, position.angles );
	PlayRadiantExploder( localClientNum, "exploder_mp_endgame_lights" );

	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "displayTop3Players" ), 1 );

	thread spamUIModelValue( localClientNum );
	thread checkForGestures( localClientNum );
}

function spamUIModelValue( localClientNum )
{
	while( 1 )
	{
		wait (0.25);
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "displayTop3Players" ), 1 );
	}
}

function checkForGestures( localClientNum )
{
	localPlayers = GetLocalPlayers();

	for ( i = 0; i < localPlayers.size; i++ )
	{
		thread checkForPlayerGestures( localClientNum, localPlayers[i], i );
	}
}

function checkForPlayerGestures( localClientNum, localPlayer, playerIndex )
{
	localTopPlayerIndex = localPlayer GetTopPlayersIndex( localClientNum );
	
	if ( !isdefined( localTopPlayerIndex ) ||
	     !isdefined( level.topPlayerCharacters ) ||
	     localTopPlayerIndex >= level.topPlayerCharacters.size )
	{
		return;
	}

	characterModel = level.topPlayerCharacters[localTopPlayerIndex];

	if ( localTopPlayerIndex > 0 )
	{
		wait( RUNNER_UP_GESTURE_DELAY );
	}
	else if ( isdefined( characterModel.playingTaunt ) )
	{
		characterModel waittill( "tauntFinished" );
	}

	showGestures( localClientNum, playerIndex );
}

function showGestures( localClientNum, playerIndex )
{
	gesturesModel = GetUIModel( GetUIModelForController( localClientNum ), "topPlayerInfo.showGestures" );
	if ( isdefined( gesturesModel ) )
	{
		SetUIModelValue( gesturesModel, true );
		AllowActionSlotInput( playerIndex );
	}
}

function handlePlayTop0Gesture( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	handlePlayGesture( localClientNum, 0, newVal );
}

function handlePlayTop1Gesture( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	handlePlayGesture( localClientNum, 1, newVal );
}

function handlePlayTop2Gesture( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	handlePlayGesture( localClientNum, 2, newVal );
}

function handlePlayGesture( localClientNum, topPlayerIndex, gestureType )
{
	if ( gestureType > 2 ||
	     !isdefined( level.topPlayerCharacters ) ||
	     topPlayerIndex >= level.topPlayerCharacters.size )
	{
		return;
	}

	characterModel = level.topPlayerCharacters[topPlayerIndex];

	if ( isdefined( characterModel.playingTaunt ) ||
	     IS_TRUE( characterModel.playingGesture ) )
	{
		return;
	}

	thread end_game_taunts::playGestureType( localClientNum, characterModel, topPlayerIndex, gestureType );
}

function streamerWatcher()
{
	while( true )
	{
		level waittill( "streamFKsl", localClientNum );
		prepareTopThreePlayers( localClientNum );
		end_game_taunts::stream_epic_models();
	}
}


function handleTopThreePlayers( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isdefined( newVal ) && newVal > 0 && isDefined( level.endGameXCamName ) )
	{
		level.showedTopThreePlayers = true;
		showTopThreePlayers( localClientNum );
	}
}

function showScoreboard( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isdefined( newVal ) && newVal > 0 && isDefined( level.endGameXCamName ) )
	{
		end_game_taunts::stop_stream_epic_models();
		end_game_taunts::deleteCameraGlass( undefined );
		position = struct::get( "endgame_top_players_struct", "targetname" );
		PlayMainCamXCam( localClientNum, level.endGameXCamName, 0, "cam_topscorers", "", position.origin, position.angles );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "forceScoreboard" ), 1 );
		level.inEndGameFlow = true;
	}
}

