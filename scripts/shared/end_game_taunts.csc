#using scripts\codescripts\struct;
#using scripts\shared\animation_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\audio_shared;

#using scripts\shared\abilities\gadgets\_gadget_camo_render;
#using scripts\shared\abilities\gadgets\_gadget_clone_render;
#using scripts\shared\ai\systems\fx_character;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\weapons\weapon_group_anims.gsh;

#using_animtree("all_player");

#define TAUNT_FIRST_PLACE 0

#define GESTURE_TYPE_GOOD_GAME	0
#define GESTURE_TYPE_THREATEN	1
#define GESTURE_TYPE_BOAST		2
	
#define FROM_IDLE_BLEND_TIME		0.4
#define TO_IDLE_BLEND_TIME			0.4
	
#define TO_TAUNT_BLEND_TIME			0
#define FROM_TAUNT_BLEND_TIME		0.4
	
#define TO_GESTURE_BLEND_TIME		0.4
#define FROM_GESTURE_BLEND_TIME		0.4

#define CAMERA_GLASS	"gfx_p7_zm_asc_data_recorder_glass"
#define MINIGUN_PROP	"wpn_t7_hero_reaper_minigun_prop"
#define MINIGUN_PROP_3	"wpn_t7_loot_hero_reaper3_minigun_prop"
#define GI_UNIT_BODY	"c_zsf_robot_grunt_body"
#define GI_UNIT_HEAD	"c_zsf_robot_grunt_head"
#define RAP_FRIENDLY	"veh_t7_drone_raps_mp_lite"
#define RAP_ENEMY		"veh_t7_drone_raps_mp_dark"
#define TALON_FRIENDLY	"veh_t7_drone_attack_gun_litecolor"
#define TALON_ENEMY		"veh_t7_drone_attack_gun_darkcolor"

#precache( "client_fx", "player/fx_loot_taunt_e_reaper_main_03" );

#define TALON_LIGHT_FX "player/fx_loot_taunt_outrider_talon_lights"
#precache( "client_fx", TALON_LIGHT_FX );

#namespace end_game_taunts;

REGISTER_SYSTEM( "end_game_taunts", &__init__, undefined )

function __init__()
{
	animation::add_notetrack_func( "taunts::hide", &hideModel );
	animation::add_notetrack_func( "taunts::show", &showModel );

	animation::add_notetrack_func( "taunts::cloneshaderon", &cloneShaderOn );
	animation::add_notetrack_func( "taunts::cloneshaderoff", &cloneShaderOff );

	animation::add_notetrack_func( "taunts::camoshaderon", &camoShaderOn );
	animation::add_notetrack_func( "taunts::camoshaderoff", &camoShaderOff );

	animation::add_notetrack_func( "taunts::spawncameraglass", &spawnCameraGlass );
	animation::add_notetrack_func( "taunts::deletecameraglass", &deleteCameraGlass );
	
	animation::add_notetrack_func( "taunts::reaperbulletglass", &reaperBulletGlass );
	animation::add_notetrack_func( "taunts::centerbulletglass", &centerBulletGlass );

	animation::add_notetrack_func( "taunts::talonbulletglassleft", &talonBulletGlassLeft );
	animation::add_notetrack_func( "taunts::talonbulletglassright", &talonBulletGlassRight );

	animation::add_notetrack_func( "taunts::fireweapon", &fireWeapon );
	animation::add_notetrack_func( "taunts::stopfireweapon", &stopFireWeapon );
	
	animation::add_notetrack_func( "taunts::firebeam", &fireBeam );
	animation::add_notetrack_func( "taunts::stopfirebeam", &stopFireBeam );
	
	animation::add_notetrack_func( "taunts::playwinnerteamfx", &playWinnerTeamFx );
	animation::add_notetrack_func( "taunts::playlocalteamfx", &playLocalTeamFx );
	
	level.epicTauntXModels = array(
		// Models used in script
		 CAMERA_GLASS,
		 MINIGUN_PROP,
		 MINIGUN_PROP_3,
		 GI_UNIT_BODY,
		 GI_UNIT_HEAD,
		 RAP_FRIENDLY,
		 RAP_ENEMY,
		 TALON_FRIENDLY,
		 TALON_ENEMY,

		// Notetrack and Scriptbundle models
		"wpn_t7_arm_blade_prop",
		"wpn_t7_hero_annihilator_prop",
		"wpn_t7_hero_bow_prop",
		"wpn_t7_hero_electro_prop_animate",
		"wpn_t7_hero_flamethrower_world",
		"wpn_t7_hero_mgl_world",
		"wpn_t7_hero_mgl_prop",
		"wpn_t7_hero_spike_prop",
		"wpn_t7_hero_seraph_machete_prop",
		"wpn_t7_loot_crowbar_world",
		"wpn_t7_spider_mine_world",
		"wpn_t7_zmb_katana_prop"
	);
	
	// Stop streaming epic models whenever we start up a new VM
	stop_stream_epic_models();
}

/#
function check_force_taunt()
{
	while ( 1 )
	{
		SetDvar( "forceTaunt", "" );
		
		WAIT_SERVER_FRAME;
		
		taunt = GetDvarString( "forceTaunt" );
	
		if ( taunt == "" )
			continue;
	
		model = level.topPlayerCharacters[ 0 ];
		
		if ( !isdefined( model ) ||
		     isdefined( model.playingTaunt ) ||
		     IS_TRUE( model.playingGesture ) )
			continue;
		
		bodyType = GetDvarInt( "forceTauntBodyType", -1 );
		SetDvar( "forceTauntBodyType", -1 );
		
		if ( bodyType >= 0 )
		{
			tauntModel = spawn_temp_specialist_model( model.localClientNum, bodyType, model.origin, model.angles, model.showcaseWeapon );
			model Hide();
		}
		else
		{
			tauntModel = model;
		}
		
		idleAnimName = getIdleAnimName( model.localClientNum, model, 0 );
		playTaunt( model.localClientNum, tauntModel, 0, idleAnimName, taunt );	
		
		if ( tauntModel != model )
		{
			tauntModel Delete();
			model Show();
		}
	}
}

function check_force_gesture()
{
	while ( 1 )
	{
		SetDvar( "forceGesture", "" );
		
		WAIT_SERVER_FRAME;
		
		gesture = GetDvarString( "forceGesture" );
	
		if ( gesture == "" )
			continue;
	
		model = level.topPlayerCharacters[ 0 ];
		
		if ( !isdefined( model ) ||
		     isdefined( model.playingTaunt ) ||
		     IS_TRUE( model.playingGesture ) )
			continue;
		
		idleAnimName = getIdleAnimName( model.localClientNum, model, 0 );
		playGesture( model.localClientNum, model, 0, idleAnimName, gesture, true );
	}
}

function draw_runner_up_bounds()
{
	while( 1 )
	{
		WAIT_CLIENT_FRAME;
		
		if ( !GetDvarInt( "runnerupboxes", 0 ) )
			continue;
		
		for ( i = 1; i < 3; i++ )
		{
			model = level.topPlayerCharacters[i];
			Box( model.origin, ( -15, -15, 0 ), ( 15, 15, 72 ), model.angles[1], ( 0, 0, 1 ), false, 1 );
		}	
	}
}

function spawn_temp_specialist_model( localClientNum, characterIndex, origin, angles, showcaseWeapon )
{
	tempModel = Spawn( localClientNum, origin, "script_model" );
	tempModel.angles = angles;
	tempModel.showcaseWeapon = showcaseWeapon;
	
	tempModel.bodyModel = GetCharacterBodyModel( characterIndex, 0, CurrentSessionMode() );
	tempModel.helmetModel = GetCharacterHelmetModel( characterIndex, 0, CurrentSessionMode() );
	
	tempModel SetModel( tempModel.bodyModel );
	tempModel Attach( tempModel.helmetModel, "" );
	
	tempModel.modeRenderOptions =  GetCharacterModeRenderOptions( CurrentSessionMode() );
	
	tempModel.bodyRenderOptions = GetCharacterBodyRenderOptions( characterIndex, 0, 0, 0, 0 );
	tempModel.helmetRenderOptions = GetCharacterHelmetRenderOptions( characterIndex, 0, 0, 0, 0 );
	
	tempModel SetBodyRenderOptions( tempModel.modeRenderOptions,
	                                tempModel.bodyRenderOptions,
	                                tempModel.helmetRenderOptions,
	                                tempModel.helmetRenderOptions );
	
	return tempModel;
}

#/

function playCurrentTaunt( localClientNum, characterModel, topPlayerIndex )
{
	tauntAnimName = GetTopPlayersTaunt( localClientNum, topPlayerIndex, TAUNT_FIRST_PLACE );
	
	idleAnimName = getIdleAnimName( localClientNum, characterModel, topPlayerIndex );
	
	playTaunt( localClientNum, characterModel, topPlayerIndex, idleAnimName, tauntAnimName );
}

function previewTaunt( localClientNum, characterModel, idleAnimName, tauntAnimName )
{
	cancelGesture( characterModel );
	
	deleteCameraGlass( undefined );
	
	playTaunt( localClientNum, characterModel, 0, idleAnimName, tauntAnimName, TO_TAUNT_BLEND_TIME, false );
}

function playTaunt( localClientNum, characterModel, topPlayerIndex, idleAnimName, tauntAnimName, toTauntBlendTime = 0, playTransitions = true )
{
	if ( !isdefined( tauntAnimName ) || tauntAnimName == "" )
	{
		return;
	}
	
	cancelTaunt( localClientNum, characterModel );
	characterModel StopSounds();
	characterModel endon( "cancelTaunt" );
	
	characterModel util::waittill_dobj( localClientNum );

	if( !characterModel HasAnimTree() )
	{
		characterModel UseAnimTree( #animtree );
	}

	characterModel.playingTaunt = tauntAnimName;
	characterModel notify( "tauntStarted" );

	// Clear the idle
	characterModel ClearAnim( idleAnimName, toTauntBlendTime );
	
	// Get the transition anim, dependent on the weapon
	idleInAnimName = getIdleInAnimName( characterModel, topPlayerIndex );
	
	// Hide the weapon
	hideWeapon( characterModel );
	
	characterModel thread playEpicTauntScene( localClientNum, tauntAnimName );
	
	// Play taunt anim, VO is hooked up in the exported notetracks
	characterModel animation::play( tauntAnimName, undefined, undefined, 1, toTauntBlendTime, FROM_TAUNT_BLEND_TIME );
	
	// Play transition to idle anim
	if ( IS_TRUE( playTransitions ) )
	{
		self thread waitAppearWeapon( characterModel );
		playTransitionAnim( characterModel, idleInAnimName, FROM_TAUNT_BLEND_TIME, TO_IDLE_BLEND_TIME );
	}
	
	// Reattach the weapon
	showWeapon( characterModel );
	
	// Play idle anim
	characterModel thread animation::play( idleAnimName, undefined, undefined, 1, TO_IDLE_BLEND_TIME, 0 );
	
	characterModel.playingTaunt = undefined;
	characterModel notify( "tauntFinished" );
	characterModel shutdownEpicTauntModels();
}

function cancelTaunt( localClientNum, characterModel )
{	
	if ( isdefined( characterModel.playingTaunt ) )
	{
		characterModel cloneShaderOff();
		characterModel shutdownEpicTauntModels();
		characterModel stopEpicTauntScene( localClientNum, characterModel.playingTaunt );
		characterModel StopSounds();
	}
	
	characterModel notify( "cancelTaunt" );
	characterModel.playingTaunt = undefined;
	characterModel.epicTauntModels = undefined;
}

function playGestureType( localClientNum, characterModel, topPlayerIndex, gestureType )
{
	idleAnimName = getIdleAnimName( localClientNum, characterModel, topPlayerIndex );
	
	gestureAnimName = GetTopPlayersGesture( localClientNum, topPlayerIndex, gestureType );
	
	playGesture( localClientNum, characterModel, topPlayerIndex, idleAnimName, gestureAnimName );
}

function previewGesture( localClientNum, characterModel, idleAnimName, gestureAnimName )
{
	cancelTaunt( localClientNum, characterModel );
	
	deleteCameraGlass( undefined );
	
	playGesture( localClientNum, characterModel, 0, idleAnimName, gestureAnimName, false );
}

function playGesture( localClientNum, characterModel, topPlayerIndex, idleAnimName, gestureAnimName, playTransitions = true )
{
	if ( !isdefined( gestureAnimName ) || gestureAnimName == "" )
	{
		return;
	}
	
	cancelGesture( characterModel );
	characterModel endon( "cancelGesture" );
	
	characterModel util::waittill_dobj( localClientNum );

	if( !characterModel HasAnimTree() )
	{
		characterModel UseAnimTree( #animtree );
	}
	
	characterModel.playingGesture = true;
	characterModel notify( "gestureStarted" );
	
	// Get and clear the idle
	characterModel ClearAnim( idleAnimName, FROM_IDLE_BLEND_TIME );
	
	// Get transition anims, dependent on the weapon
	idleOutAnimName = getIdleOutAnimName( characterModel, topPlayerIndex );
	idleInAnimName = getIdleInAnimName( characterModel, topPlayerIndex );
	
	// Play transition out of idle anim
	if ( IS_TRUE( playTransitions ) )
	{
		self thread waitRemoveWeapon( characterModel );
		playTransitionAnim( characterModel, idleOutAnimName, FROM_IDLE_BLEND_TIME, TO_GESTURE_BLEND_TIME );
	}
	
	// Get and hide the weapon
	hideWeapon( characterModel );
	
	// Play gesture anim
	characterModel animation::play( gestureAnimName, undefined, undefined, 1, TO_GESTURE_BLEND_TIME, FROM_GESTURE_BLEND_TIME );
	
	// Play transition to idle anim
	if ( IS_TRUE( playTransitions ) )
	{
		self thread waitAppearWeapon( characterModel );
		playTransitionAnim( characterModel, idleInAnimName, FROM_GESTURE_BLEND_TIME, TO_IDLE_BLEND_TIME );
	}
	
	// Reattach the weapon
	showWeapon( characterModel );
	
	// Play idle anim
	characterModel thread animation::play( idleAnimName, undefined, undefined, 1, TO_IDLE_BLEND_TIME, 0 );
	
	characterModel.playingGesture = false;
	characterModel notify( "gestureFinished" );
}

function cancelGesture( characterModel )
{
	characterModel notify( "cancelGesture" );
	characterModel.playingGesture = false;
}

function playTransitionAnim( characterModel, transitionAnimName, blendInTime = 0, blendOutTime = 0 )
{
	characterModel endon( "cancelTaunt" );
	
	// This should go away when all the transitions are in
	if ( !isdefined( transitionAnimName ) || transitionAnimName == "" )
	{
		return;
	}
	
	characterModel animation::play( transitionAnimName, undefined, undefined, 1, blendInTime, blendOutTime );
}

function waitRemoveWeapon( characterModel )
{
	characterModel endon( "weaponHidden" );
	
	while( 1 )
	{
		characterModel waittill( "_anim_notify_", param1 );
		
		if ( param1 == "remove_from_hand" )
		{			
			hideWeapon( characterModel );
			return;
		}
	}
}

function waitAppearWeapon( characterModel )
{
	characterModel endon( "weaponShown" );	
	
	while( 1 )
	{
		characterModel waittill( "_anim_notify_", param1 );
	
		if ( param1 == "appear_in_hand" )
		{
			showWeapon( characterModel );			
			return;
		}
	}
}

function hideWeapon( characterModel )
{
	if ( characterModel.weapon == level.weaponNone )
	{
		return;	
	}
	
	MarkAsDirty( characterModel );
	characterModel AttachWeapon( level.weaponNone );
	characterModel UseWeaponHideTags( level.weaponNone );
	
	characterModel notify ( "weaponHidden" );
}

function showWeapon( characterModel )
{
	if ( !isdefined( characterModel.showcaseWeapon ) || characterModel.weapon != level.weaponNone )
	{
		return;
	}
	
	MarkAsDirty( characterModel );
	
	if ( isdefined( characterModel.showcaseWeaponRenderOptions ) )
	{
		characterModel AttachWeapon( characterModel.showcaseWeapon, characterModel.showcaseWeaponRenderOptions, characterModel.showcaseWeaponACVI );
		characterModel UseWeaponHideTags( characterModel.showcaseWeapon );
	}
	else
	{
		characterModel AttachWeapon( characterModel.showcaseWeapon );
	}
	
	characterModel notify ( "weaponShown" );
}

function getIdleAnimName( localClientNum, characterModel, topPlayerIndex )
{
	if ( isdefined( characterModel.weapon ) )
	{
		weapon_group = GetItemGroupForWeaponName( characterModel.weapon.rootWeapon.name );
		if ( weapon_group == "weapon_launcher" )
		{
			if ( characterModel.weapon.rootWeapon.name == "launcher_lockonly" ||
			     characterModel.weapon.rootWeapon.name == "launcher_multi" )
			{
				weapon_group = "weapon_launcher_alt";
			}
			else if ( characterModel.weapon.rootWeapon.name == "launcher_ex41" )
			{
				weapon_group = "weapon_smg_ppsh";
			}
		}
		else if ( weapon_group == "weapon_pistol" && characterModel.weapon.isdualwield )
		{
			weapon_group = "weapon_pistol_dw";
		}
		else if ( weapon_group == "weapon_smg")
		{
			if ( characterModel.weapon.rootWeapon.name == "smg_ppsh" )
			{
				weapon_group = "weapon_smg_ppsh";
			}
		}
		else if ( weapon_group == "weapon_cqb")
		{
			if ( characterModel.weapon.rootWeapon.name == "shotgun_olympia" )
			{
				weapon_group = "weapon_smg_ppsh";
			}
		}
		else if ( weapon_group == "weapon_special" )
		{
			if ( characterModel.weapon.rootWeapon.name == "special_crossbow" ||
					characterModel.weapon.rootWeapon.name == "special_discgun" )
			{
				weapon_group = "weapon_smg";
			}
			else if( characterModel.weapon.rootWeapon.name == "special_crossbow_dw" )
			{
				weapon_group = "weapon_pistol_dw";
			}
			else if( characterModel.weapon.rootWeapon.name == "knife_ballistic" )
			{
				weapon_group = "weapon_knife_ballistic";
			}
		}
		else if ( weapon_group == "weapon_knife" )
		{
			if ( characterModel.weapon.rootWeapon.name == "melee_wrench" ||
			     characterModel.weapon.rootWeapon.name == "melee_crowbar" ||
			     characterModel.weapon.rootWeapon.name == "melee_improvise" ||
			     characterModel.weapon.rootWeapon.name == "melee_shockbaton" ||
			     characterModel.weapon.rootWeapon.name == "melee_shovel" )
			{
				return WRENCH_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_knuckles" )
			{
				return KNUCKLES_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_chainsaw" ||
					 	characterModel.weapon.rootWeapon.name == "melee_boneglass" ||
					 	characterModel.weapon.rootWeapon.name == "melee_crescent" )
			{
				return CHAINSAW_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_boxing" )
			{
				return BOXING_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_sword" ||
						characterModel.weapon.rootWeapon.name == "melee_katana")
			{
				return SWORD_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_nunchuks" )
			{
				return NUNCHUCKS_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_bat" ||
		          	  characterModel.weapon.rootWeapon.name == "melee_fireaxe" ||
		          	  characterModel.weapon.rootWeapon.name == "melee_mace" )
			{
				return MACE_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "melee_prosthetic" )
			{
				return PROSTHETIC_ENDGAME_ARRAY[ topPlayerIndex ];
			}
		}
		else if ( weapon_group == "miscweapon" )
		{
			if ( characterModel.weapon.rootWeapon.name == "blackjack_coin" )
			{
				return BRAWLER_ENDGAME_ARRAY[ topPlayerIndex ];
			}
			else if ( characterModel.weapon.rootWeapon.name == "blackjack_cards" )
			{
				return BRAWLER_ENDGAME_ARRAY[ topPlayerIndex ];
			}
		}
		
		if ( isdefined( WEAPON_GROUP_TOP_3_ANIMS[ weapon_group ] ) )
		{
			anim_name = WEAPON_GROUP_TOP_3_ANIMS[ weapon_group ][ topPlayerIndex ];
		}
	}
	
	if ( !isdefined( anim_name ) )
	{
		anim_name = BRAWLER_ENDGAME_ARRAY[ topPlayerIndex ];
	}
	
	return anim_name;
}

function getIdleOutAnimName( characterModel, topPlayerIndex )
{
	weapon_group = getWeaponGroup( characterModel );
	
	switch( weapon_group )
	{
		case "weapon_smg":
			return array( "pb_smg_endgame_1stplace_out", "pb_smg_endgame_2ndplace_out", "pb_smg_endgame_3rdplace_out" )[ topPlayerIndex ];
		case "weapon_assault":
			return array( "pb_rifle_endgame_1stplace_out", "pb_rifle_endgame_2ndplace_out", "pb_rifle_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_cqb":
			return array( "pb_shotgun_endgame_1stplace_out", "pb_shotgun_endgame_2ndplace_out", "pb_shotgun_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_lmg":
			return array( "pb_lmg_endgame_1stplace_out", "pb_lmg_endgame_2ndplace_out", "pb_lmg_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_sniper":
			return array( "pb_sniper_endgame_1stplace_out", "pb_sniper_endgame_2ndplace_out", "pb_sniper_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_pistol":
			return array( "pb_pistol_endgame_1stplace_out", "pb_pistol_endgame_2ndplace_out", "pb_pistol_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_pistol_dw":
			return array( "pb_pistol_dw_endgame_1stplace_out", "pb_pistol_dw_endgame_2ndplace_out", "pb_pistol_dw_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_launcher":
			return array( "pb_launcher_endgame_1stplace_out", "pb_launcher_endgame_2ndplace_out", "pb_launcher_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_launcher_alt":
			return array( "pb_launcher_alt_endgame_1stplace_out", "pb_launcher_alt_endgame_2ndplace_out", "pb_launcher_alt_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_knife":
			return array( "pb_knife_endgame_1stplace_out", "pb_knife_endgame_2ndplace_out", "pb_knife_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_knuckles":
			return array( "pb_brass_knuckles_endgame_1stplace_out", "pb_brass_knuckles_endgame_2ndplace_out", "pb_brass_knuckles_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_boxing":
			return array( "pb_boxing_gloves_endgame_1stplace_out", "pb_boxing_gloves_endgame_2ndplace_out", "pb_boxing_gloves_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_wrench":
			return array( "pb_wrench_endgame_1stplace_out", "pb_wrench_endgame_2ndplace_out", "pb_wrench_endgame_3rdplace_out" )[ topPlayerIndex ];
		case"weapon_sword":
			return array( "pb_sword_endgame_1stplace_out", "pb_sword_endgame_2ndplace_out", "pb_sword_endgame_3rdplace_out" )[ topPlayerIndex ];			
		case"weapon_nunchucks":
			return array( "pb_nunchucks_endgame_1stplace_out", "pb_nunchucks_endgame_2ndplace_out", "pb_nunchucks_endgame_3rdplace_out" )[ topPlayerIndex ];			
		case"weapon_mace":
			return array( "pb_mace_endgame_1stplace_out", "pb_mace_endgame_2ndplace_out", "pb_mace_endgame_3rdplace_out" )[ topPlayerIndex ];	
		case"weapon_prosthetic":
			return array( "pb_prosthetic_arm_endgame_1stplace_out", "pb_prosthetic_arm_endgame_2ndplace_out", "pb_prosthetic_arm_endgame_3rdplace_out" )[ topPlayerIndex ];			
		case"weapon_chainsaw":
			return array( "pb_chainsaw_endgame_1stplace_idle_out", "pb_chainsaw_endgame_1stplace_idle_out", "pb_chainsaw_endgame_1stplace_idle_out" )[ topPlayerIndex ];			
		case"weapon_smg_ppsh":
			return array( "pb_smg_ppsh_endgame_1stplace_out", "pb_smg_ppsh_endgame_1stplace_out", "pb_smg_ppsh_endgame_1stplace_out" )[ topPlayerIndex ];			
		case"weapon_knife_ballistic":
			return array( "pb_b_knife_endgame_1stplace_out", "pb_b_knife_endgame_1stplace_out", "pb_b_knife_endgame_1stplace_out" )[ topPlayerIndex ];			
	}
	
	return "";
}

function getIdleInAnimName( characterModel, topPlayerIndex )
{
	weapon_group = getWeaponGroup( characterModel );

	switch( weapon_group )
	{
		case "weapon_smg":
			return array( "pb_smg_endgame_1stplace_in", "pb_smg_endgame_2ndplace_in", "pb_smg_endgame_3rdplace_in" )[ topPlayerIndex ];
		case "weapon_assault":
			return array( "pb_rifle_endgame_1stplace_in", "pb_rifle_endgame_2ndplace_in", "pb_rifle_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_cqb":
			return array( "pb_shotgun_endgame_1stplace_in", "pb_shotgun_endgame_2ndplace_in", "pb_shotgun_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_lmg":
			return array( "pb_lmg_endgame_1stplace_in", "pb_lmg_endgame_2ndplace_in", "pb_lmg_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_sniper":
			return array( "pb_sniper_endgame_1stplace_in", "pb_sniper_endgame_2ndplace_in", "pb_sniper_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_pistol":
			return array( "pb_pistol_endgame_1stplace_in", "pb_pistol_endgame_2ndplace_in", "pb_pistol_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_pistol_dw":
			return array( "pb_pistol_dw_endgame_1stplace_in", "pb_pistol_dw_endgame_2ndplace_in", "pb_pistol_dw_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_launcher":
			return array( "pb_launcher_endgame_1stplace_in", "pb_launcher_endgame_2ndplace_in", "pb_launcher_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_launcher_alt":
			return array( "pb_launcher_alt_endgame_1stplace_in", "pb_launcher_alt_endgame_2ndplace_in", "pb_launcher_alt_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_knife":
			return array( "pb_knife_endgame_1stplace_in", "pb_knife_endgame_2ndplace_in", "pb_knife_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_knuckles":
			return array( "pb_brass_knuckles_endgame_1stplace_in", "pb_brass_knuckles_endgame_2ndplace_in", "pb_brass_knuckles_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_boxing":
			return array( "pb_boxing_gloves_endgame_1stplace_in", "pb_boxing_gloves_endgame_2ndplace_in", "pb_boxing_gloves_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_wrench":
			return array( "pb_wrench_endgame_1stplace_in", "pb_wrench_endgame_2ndplace_in", "pb_wrench_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_sword":
			return array( "pb_sword_endgame_1stplace_in", "pb_sword_endgame_2ndplace_in", "pb_sword_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_nunchucks":
			return array( "pb_nunchucks_endgame_1stplace_in", "pb_nunchucks_endgame_2ndplace_in", "pb_nunchucks_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_mace":
			return array( "pb_mace_endgame_1stplace_in", "pb_mace_endgame_2ndplace_in", "pb_mace_endgame_3rdplace_in" )[ topPlayerIndex ];	
		case"weapon_prosthetic":
			return array( "pb_prosthetic_arm_endgame_1stplace_in", "pb_prosthetic_arm_endgame_2ndplace_in", "pb_prosthetic_arm_endgame_3rdplace_in" )[ topPlayerIndex ];
		case"weapon_chainsaw":
			return array( "pb_chainsaw_endgame_1stplace_idle_in", "pb_chainsaw_endgame_1stplace_idle_in", "pb_chainsaw_endgame_1stplace_idle_in" )[ topPlayerIndex ];
		case"weapon_smg_ppsh":
			return array( "pb_smg_ppsh_endgame_1stplace_in", "pb_smg_ppsh_endgame_1stplace_in", "pb_smg_ppsh_endgame_1stplace_in" )[ topPlayerIndex ];
		case"weapon_knife_ballistic":
			return array( "pb_b_knife_endgame_1stplace_in", "pb_b_knife_endgame_1stplace_in", "pb_b_knife_endgame_1stplace_in" )[ topPlayerIndex ];
	}
	
	return "";
}

function getWeaponGroup( characterModel )
{
	if ( !isdefined( characterModel.weapon ) )
	{
		return "";
	}
	
	weapon = characterModel.weapon;
	
	if ( weapon == level.weaponNone && isdefined( characterModel.showcaseWeapon ) )
	{
		weapon = characterModel.showcaseWeapon;
	}
	
	weapon_group = GetItemGroupForWeaponName( weapon.rootWeapon.name );
	if ( weapon_group == "weapon_launcher" )
	{
		if ( characterModel.weapon.rootWeapon.name == "launcher_lockonly" ||
		     characterModel.weapon.rootWeapon.name == "launcher_multi" )
		{
			weapon_group = "weapon_launcher_alt";
		}
		else if ( characterModel.weapon.rootWeapon.name == "launcher_ex41" )
		{
			weapon_group = "weapon_smg_ppsh";
		}
	}
	else if ( weapon_group == "weapon_pistol" && weapon.isdualwield )
	{
		weapon_group = "weapon_pistol_dw";
	}
	else if ( weapon_group == "weapon_smg")
	{
		if ( characterModel.weapon.rootWeapon.name == "smg_ppsh" )
		{
			weapon_group = "weapon_smg_ppsh";
		}
	}
	else if ( weapon_group == "weapon_cqb")
	{
		if ( characterModel.weapon.rootWeapon.name == "shotgun_olympia" )
		{
			weapon_group = "weapon_smg_ppsh";
		}
	}
	else if ( weapon_group == "weapon_special" )
	{
		if ( characterModel.weapon.rootWeapon.name == "special_crossbow" ||
				characterModel.weapon.rootWeapon.name == "special_discgun" )
		{
			weapon_group = "weapon_smg";
		}
		else if( characterModel.weapon.rootWeapon.name == "special_crossbow_dw" )
		{
			weapon_group = "weapon_pistol_dw";
		}
		else if( characterModel.weapon.rootWeapon.name == "knife_ballistic" )
		{
			weapon_group = "weapon_knife_ballistic";
		}
	}
	else if ( weapon_group == "weapon_knife" )
	{
		if ( characterModel.weapon.rootWeapon.name == "melee_wrench" ||
			 characterModel.weapon.rootWeapon.name == "melee_crowbar" ||
			 characterModel.weapon.rootWeapon.name == "melee_improvise" ||
			 characterModel.weapon.rootWeapon.name == "melee_shockbaton" ||
			 characterModel.weapon.rootWeapon.name == "melee_shovel" )
		{
			weapon_group = "weapon_wrench";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_knuckles" )
		{
			weapon_group = "weapon_knuckles";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_chainsaw" ||
					 characterModel.weapon.rootWeapon.name == "melee_boneglass" ||
					 characterModel.weapon.rootWeapon.name == "melee_crescent" )
		{
			weapon_group = "weapon_chainsaw";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_boxing" )
		{
			weapon_group = "weapon_boxing";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_sword" ||
					 characterModel.weapon.rootWeapon.name == "melee_katana" )
		{
			weapon_group = "weapon_sword";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_nunchuks" )
		{
			weapon_group = "weapon_nunchucks";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_bat" ||
		          characterModel.weapon.rootWeapon.name == "melee_fireaxe" ||
		          characterModel.weapon.rootWeapon.name == "melee_mace" )
		{
			weapon_group = "weapon_mace";
		}
		else if ( characterModel.weapon.rootWeapon.name == "melee_prosthetic" )
		{
			weapon_group = "weapon_prosthetic";
		}
	}
	
	return weapon_group;
}

// Epic Taunts
//========================================

function stream_epic_models()
{	
	foreach( model in level.epicTauntXModels )
	{
		ForceStreamXModel( model );
	}
}

function stop_stream_epic_models()
{
	foreach( model in level.epicTauntXModels )
	{
		StopForceStreamingXModel( model );
	}
}

function playEpicTauntScene( localClientNum, tauntAnimName )
{		
	sceneBundle = struct::get_script_bundle( "scene", tauntAnimName );
	
	if ( !isdefined( sceneBundle ) )
		return false;
	
	// Set up any scene object overrides
	switch( tauntAnimName )
	{
		case "t7_loot_taunt_e_reaper_01":
			self thread setupReaperMinigun( localClientNum );
			break;
		case "t7_loot_taunt_e_nomad_03":
			self thread spawnGiUnit( localClientNum, "gi_unit_victim" );
			break;			
		case "t7_loot_taunt_e_seraph_04":
			self thread spawnRap(localClientNum, "rap_1");
			self thread spawnRap(localClientNum, "rap_2");
			break;
		case "t7_loot_taunt_e_reaper_main_03":
			self thread spawnHiddenClone( localClientNum, "reaper_l" );
			self thread spawnHiddenClone( localClientNum, "reaper_r" );
			break;
		case "t7_loot_taunt_e_spectre_03":
			if ( GetDvarString( "mapname" ) == "core_frontend" )
			{
				// disable the "alt streaming" effect since this disables the cloaking shader
				self SetHighDetail( true, false );
				self handleCamoChange( self.localClientNum, true );
			}
			else
			{
				self thread gadget_camo_render::forceOn( localClientNum );
			}
			self thread spawnGiUnit( localClientNum, "gi_unit_victim" );
			break;
		case "t7_loot_taunt_e_outrider_05":
			self thread spawnTalon( localClientNum, "talon_bro_1", 0.65 );
			self thread spawnTalon( localClientNum, "talon_bro_2", 0.65 );
			break;
	}
	
	self thread scene::play( tauntAnimName );
	return true;
}

function stopEpicTauntScene( localClientNum, tauntAnimName )
{
	sceneBundle = struct::get_script_bundle( "scene", tauntAnimName );
	
	if ( !isdefined( sceneBundle ) )
		return;
	
	switch( tauntAnimName )
	{
		case "t7_loot_taunt_e_spectre_03":
			if ( GetDvarString( "mapname" ) == "core_frontend" )
			{
				// renabled the "alt streaming" now that cloaking is off
				self SetHighDetail( true, false );
			}
			break;
	}
	
	self thread scene::stop( tauntAnimName );
}

function addEpicSceneFunc( tauntAnimName, func, state )
{
	sceneBundle = struct::get_script_bundle( "scene", tauntAnimName );
	
	if ( !isdefined( sceneBundle ) )
		return;
	
	scene::add_scene_func( tauntAnimName, func, state );
}

function shutdownEpicTauntModels()
{
	if ( isdefined( self.epicTauntModels ) )
	{
		foreach ( model in self.epicTauntModels )
		{
			if ( isdefined( model ) )
			{
				model StopSounds();
				model Delete();
			}
		}
		
		self.epicTauntModels = undefined;
	}
}

// Epic Taunt Anim Effects
//========================================

function hideModel( param )
{
	self Hide();
}

function showModel( param )
{
	self Show();
}

function spawnCameraGlass( param )
{
	if ( isdefined( level.cameraGlass ) )
	{
		deleteCameraGlass( param );
	}

	level.cameraGlass = Spawn( self.localClientNum, (0,0,0), "script_model" );
	level.cameraGlass SetModel( CAMERA_GLASS );
	level.cameraGlass SetScale( 2.0 );
	
	level.cameraGlass thread updateGlassPosition();
}

function updateGlassPosition()
{
	self endon( "entityshutdown" );
	
	while ( 1 )
	{
		camAngles = GetCamAnglesByLocalClientNum( self.localClientNum );
		camPos =  GetCamPosByLocalClientNum( self.localClientNum );
		
		fwd = AnglesToForward( camAngles );
		
		self.origin = camPos +( fwd * 60 );
		self.angles = camAngles + (0, 180, 0);
		
		WAIT_CLIENT_FRAME;
	}
}

function deleteCameraGlass( param )
{
	if ( !isdefined( level.cameraGlass ) )
		return;
	
	level.cameraGlass Delete();
	level.cameraGlass = undefined;
}

function reaperBulletGlass( param )
{
	waittillframeend;
	
	minigun = GetWeapon( "hero_minigun" );
	
	for ( i = 30; i > -30; i -= 7 )
	{
		if ( !isdefined( self ) )
		{
			return;
		}
		
		self magicGlassBullet( self.localClientNum, minigun, RandomFloatRange(2, 12), i );
		self playsound (0, "pfx_magic_bullet_glass");
		wait minigun.fireTime;	
	}
}

function centerBulletGlass( weaponName )
{
	waittillframeend;
	
	weapon = GetWeapon( weaponName );
	
	if ( weapon == level.weaponNone )
	{
		return;
	}
	
	self magicGlassBullet( self.localClientNum, weapon, 4, -2 );
	self playsound (0, "pfx_magic_bullet_glass");
}	

function talonBulletGlassLeft( param )
{
	self talonBulletGlass( -28, -10 );
}

function talonBulletGlassRight( param )
{
	self talonBulletGlass( 10, 28 );
}

function talonBulletGlass( yawMin, yawMax )
{
	waittillframeend;
	
	minigun = GetWeapon( "hero_minigun" );
	
	for( i = 0; i < 15; i++ )
	{
		if ( !isdefined( self ) )
		{
			return;
		}
		self magicGlassBullet( self.localClientNum, minigun, RandomFloatRange(4, 16), RandomFloatRange( yawMin, yawMax ) );
		self playsound (0, "pfx_magic_bullet_glass");
		wait minigun.fireTime;	
	}
	
}

function cloneShaderOn( param )
{
	if ( GetDvarString( "mapname" ) == "core_frontend" )
	{
		self SetHighDetail( true, false );
	}
	
	localPlayerTeam = GetLocalPlayerTeam( self.localClientNum );
	topPlayerTeam = GetTopPlayersTeam( self.localClientNum, 0 );
	
	friendly = localPlayerTeam === topPlayerTeam;
	
	if( friendly )
	{
		self duplicate_render::update_dr_flag( self.localClientNum, "clone_ally_on", true );
	}
	else
	{
		self duplicate_render::update_dr_flag( self.localClientNum, "clone_enemy_on", true );
	}

	self thread gadget_clone_render::transition_shader( self.localClientNum );
}

function cloneShaderOff( param )
{
	self duplicate_render::update_dr_flag( self.localClientNum, "clone_ally_on", false );
	self duplicate_render::update_dr_flag( self.localClientNum, "clone_enemy_on", false );
}

function handleCamoChange( localClientNum, camo_on )
{
	flags_changed = self duplicate_render::set_dr_flag( "gadget_camo_friend", false );
	flags_changed = flags_changed && self duplicate_render::set_dr_flag( "gadget_camo_flicker", false );
	flags_changed = flags_changed && self duplicate_render::set_dr_flag( "gadget_camo_break", false );
	flags_changed = flags_changed && self duplicate_render::set_dr_flag( "gadget_camo_reveal", false );
	flags_changed = flags_changed && self duplicate_render::set_dr_flag( "gadget_camo_on", false );
	
	if ( flags_changed )
	{
		self duplicate_render::update_dr_filters();
	}
	
	if ( camo_on )
	{
		self thread gadget_camo_render::forceOn( localClientNum );
	}
	else
	{
		self thread gadget_camo_render::doReveal( self.localClientNum, 0 );
	}
}

function camoShaderOn( param )
{
	if ( GetDvarString( "mapname" ) == "core_frontend" )
	{
		self handleCamoChange( self.localClientNum, true );
	}
	else
	{
		self thread gadget_camo_render::doReveal( self.localClientNum, 1 );
	}
}

function camoShaderOff( param )
{
	if ( GetDvarString( "mapname" ) == "core_frontend" )
	{
		self handleCamoChange( self.localClientNum, false );
	}
	else
	{
		self thread gadget_camo_render::doReveal( self.localClientNum, 0 );
	}
}

function fireWeapon( weaponName )
{
	if ( !isdefined( weaponName ) )
		return;
	
	self endon( "stopFireWeapon" );
	
	weapon = GetWeapon( weaponName );
	
	waittillframeend;
	
	while( 1 && isdefined( self ) )
	{
		self MagicBullet( weapon, (0, 0, 0), (0, 0, 0) );
		wait( weapon.fireTime );
	}
}

function stopFireWeapon( param )
{
	self notify( "stopFireWeapon" );
}

function fireBeam( beam )
{	
	if ( isdefined( self.beamFx ) )
	{
		return;	
	}
	
	self.beamFx = BeamLaunch( self.localClientNum, self, "tag_flash", undefined, "none", beam );
}

function stopFireBeam( param )
{
	if ( !isdefined( self.beamFx ) )
	{
		return;
	}
	
	BeamKill( self.localClientNum, self.beamFx );
	
	self.beamFx = undefined;
}

function playWinnerTeamFx( fxName )
{
	waittillframeend;
	
	topPlayerTeam = GetTopPlayersTeam( self.localClientNum, 0 );
	DEFAULT( topPlayerTeam, GetLocalPlayerTeam( self.localClientNum ) );
	
	fxHandle = PlayFxOnTag( self.localClientNum, fxName, self, "tag_origin" );
	
	if ( isdefined( fxHandle ) )
	{
		SetFxTeam( self.localClientNum, fxHandle, topPlayerTeam );	
	}
}

function playLocalTeamFx( fxName )
{
	waittillframeend;
	
	localPlayerTeam = GetLocalPlayerTeam( self.localClientNum );
	
	fxHandle = PlayFxOnTag( self.localClientNum, fxName, self, "tag_origin" );
	
	if ( isdefined( fxHandle ) )
	{
		SetFxTeam( self.localClientNum, fxHandle, localPlayerTeam );	
	}
}

// Effect Helpers
//========================================

function magicGlassBullet( localClientNum, weapon, pitchAngle, yawAngle )
{	
	camPos =  GetCamPosByLocalClientNum( localClientNum );
	camAngles = GetCamAnglesByLocalClientNum( localClientNum );

	bulletAngles = camAngles + ( pitchAngle, yawAngle, 0 );
	
	self MagicBullet( weapon, camPos, bulletAngles  );
}

function launchProjectile( localClientNum, projectileModel, projectileTrail )
{
	launchOrigin = self GetTagOrigin( "tag_flash" );
	
	if ( !isdefined( launchOrigin ) )
		return;
	
	launchAngles = self GetTagAngles( "tag_flash" );
	launchDir = AnglesToForward( launchAngles );
	
	CreateDynEntAndLaunch( localClientNum, projectileModel, launchOrigin, (0,0,0), launchOrigin, launchDir * GetDvarFloat( "launchspeed", 3.5 ), projectileTrail );
}

function setupReaperMinigun( localClientNum )
{
	model = Spawn( localClientNum, self.origin, "script_model" );
	model.angles = self.angles;
	model.targetName = "scythe_prop";
	
	model SetHighDetail( true );
	scytheModel = MINIGUN_PROP;
	
	if ( isdefined( self.bodyModel ) )
	{
		if ( StrStartsWith( self.bodyModel, "c_t7_mp_reaper_mpc_body3" ) )
		{
			scytheModel = MINIGUN_PROP_3;
		}
	}
	
	model SetModel( scytheModel );
	model SetBodyRenderOptions( self.modeRenderOptions, self.bodyRenderOptions, self.helmetRenderOptions, self.helmetRenderOptions );
	
	self HidePart( localClientNum, "tag_minigun_flaps" );
	
	ARRAY_ADD( self.epicTauntModels, model );
}

// The scene system will try to show and anchor the model when the animation starts, so shrink it and hide it
function spawnHiddenClone( localClientNum, targetName)
{
	clone = self spawnPlayerModel( localClientNum, targetName, self.origin, self.angles, self.bodyModel, self.helmetModel, self.modeRenderOptions, self.bodyRenderOptions, self.helmetRenderOptions );
	
	clone SetScale( 0 );
	
	WAIT_CLIENT_FRAME;

	clone Hide();
	clone SetScale( 1 );
	
	ARRAY_ADD( self.epicTauntModels, clone );
}

function spawnTopPlayerModel( localClientNum, targetName, origin, angles, topPlayerIndex )
{
	bodyModel = GetTopPlayersBodyModel( localClientNum, topPlayerIndex );
	helmetModel = GetTopPlayersHelmetModel( localClientNum, topPlayerIndex );
	modeRenderOptions =  GetCharacterModeRenderOptions( CurrentSessionMode() );
	bodyRenderOptions = GetTopPlayersBodyRenderOptions( localClientNum, topPlayerIndex );
	helmetRenderOptions = GetTopPlayersHelmetRenderOptions( localClientNum, topPlayerIndex );
	
	return spawnPlayerModel( localClientNum, targetName, origin, angles, bodyModel, helmetModel, modeRenderOptions, bodyRenderOptions, helmetRenderOptions );
}

function spawnPlayerModel( localClientNum, targetName, origin, angles, bodyModel, helmetModel, modeRenderOptions, bodyRenderOptions, helmetRenderOptions )
{
	model = Spawn( localClientNum, origin, "script_model" );
	model.angles = angles;
	model.targetName = targetName;
	
	model SetHighDetail( true );

	model SetModel( bodyModel );
	model Attach( helmetModel, "" );
	
	model SetBodyRenderOptions( modeRenderOptions, bodyRenderOptions, helmetRenderOptions, helmetRenderOptions );
	
	model Hide();
	
	model UseAnimTree( #animtree );
	
	return model;
}

function spawnGiUnit( localClientNum, targetName )
{
	model = Spawn( localClientNum, self.origin, "script_model" );
	model.angles = self.angles;
	model.targetName = targetName;
	
	model SetHighDetail( true );
	
	model SetModel( GI_UNIT_BODY );
	model Attach( GI_UNIT_HEAD, "" );
	
	ARRAY_ADD( self.epicTauntModels, model );
}

function spawnRap( localClientNum, targetName)
{
	model = Spawn( localClientNum, self.origin, "script_model" );
	model.angles = self.angles;
	model.targetName = targetName;

	localPlayerTeam = GetLocalPlayerTeam( self.localClientNum );
	topPlayerTeam = GetTopPlayersTeam( localClientNum, 0 );	
	
	if ( !isdefined( topPlayerTeam) || localPlayerTeam == topPlayerTeam )
	{
		model SetModel( RAP_FRIENDLY );
		fxTeam = localPlayerTeam;
	}
	else
	{
		model SetModel( RAP_ENEMY );
		fxTeam = topPlayerTeam;
	}
	
	model util::waittill_dobj( localClientNum );
	/*
	fxHandle = PlayFxOnTag( localClientNum, TALON_LIGHT_FX, model, "tag_body" );
	SetFxTeam( localClientNum, fxHandle, fxTeam );
	*/
	ARRAY_ADD( self.epicTauntModels, model );
}	

function spawnTalon( localClientNum, targetName, scale = 1.0 )
{
	model = Spawn( localClientNum, self.origin, "script_model" );
	model.angles = self.angles;
	model.targetName = targetName;

	localPlayerTeam = GetLocalPlayerTeam( self.localClientNum );
	topPlayerTeam = GetTopPlayersTeam( localClientNum, 0 );	
	
	if ( !isdefined( topPlayerTeam) || localPlayerTeam == topPlayerTeam )
	{
		model SetModel( TALON_FRIENDLY );
		fxTeam = localPlayerTeam;
	}
	else
	{
		model SetModel( TALON_ENEMY );
		fxTeam = topPlayerTeam;
	}
	
	model SetScale( scale );
	
	model util::waittill_dobj( localClientNum );
	
	fxHandle = PlayFxOnTag( localClientNum, TALON_LIGHT_FX, model, "tag_body" );
	SetFxTeam( localClientNum, fxHandle, fxTeam );
	
	ARRAY_ADD( self.epicTauntModels, model );
}
