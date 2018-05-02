#using scripts\core\_multi_extracam;

#using scripts\codescripts\struct;
#using scripts\shared\abilities\gadgets\_gadget_camo_render;
#using scripts\shared\animation_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\end_game_taunts;
#using scripts\shared\filter_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\weapons\weapon_group_anims.gsh;

#namespace character_customization;

#define HERO_HELMET_BONE ""
#define HERO_HEAD_BONE ""
#define HERO_WEAPON_BONE "tag_weapon_right"
#define HERO_CUSTOMIZE_IDLE_ANIM "pb_cac_main_lobby_idle"
#define HERO_LOBBY_CLIENT_IDLE_ANIM "pb_cac_vs_screen_idle_1"
#define RS_ROTATION_SPEED_MULTIPLIER 3.0

#define HERO_MESH_LODS STREAM_LOD_HIGHEST
#define HERO_TEXTURE_LODS STREAM_MIP_EXCLUDE_HIGHEST

#define HELMET_MESH_LODS STREAM_LOD_HIGHEST
#define HELMET_TEXTURE_LODS STREAM_MIP_EXCLUDE_HIGHEST

#define HEAD_MESH_LODS STREAM_LOD_HIGHEST
#define HEAD_TEXTURE_LODS STREAM_MIP_EXCLUDE_HIGHEST

#define LIVE_CHARACTER_SPAWN_TARGET		"character_customization"
#define DEFAULT_LIVE_CHARACTER_EXPLODER "char_customization"
	
#define SHOWCASE_WEAPON_PAINTSHOP_CLASS		1
#define LOCAL_WEAPON_PAINTSHOP_CLASS		2
	
#using_animtree("all_player");

REGISTER_SYSTEM( "character_customization", &__init__, undefined )

///////////////////////////////////////////////////////////////////////////
// SETUP
///////////////////////////////////////////////////////////////////////////
function __init__()
{
	level.extra_cam_render_hero_func_callback = &process_character_extracam_request;
	level.extra_cam_render_lobby_client_hero_func_callback = &process_lobby_client_character_extracam_request;
	level.extra_cam_render_current_hero_headshot_func_callback = &process_current_hero_headshot_extracam_request;
	level.extra_cam_render_outfit_preview_func_callback = &process_outfit_preview_extracam_request;
	level.extra_cam_render_character_body_item_func_callback = &process_character_body_item_extracam_request;
	level.extra_cam_render_character_helmet_item_func_callback = &process_character_helmet_item_extracam_request;
	level.extra_cam_render_character_head_item_func_callback = &process_character_head_item_extracam_request;
	level.model_type_bones = associativearray( "helmet", HERO_HELMET_BONE, "head", HERO_HEAD_BONE );

	DEFAULT( level.liveCCData, [] );
	DEFAULT( level.custom_characters, [] );
	DEFAULT( level.extra_cam_hero_data, [] );
	DEFAULT( level.extra_cam_lobby_client_hero_data, [] );
	DEFAULT( level.extra_cam_headshot_hero_data, [] );
	DEFAULT( level.extra_cam_outfit_preview_data, [] );

	level.characterCustomizationSetup = &localClientConnect;
}

function localClientConnect( localClientNum )
{
	// setup our live and static characters
	level.liveCCData[localClientNum] = setup_live_character_customization_target( localClientNum );
	if( IsDefined( level.liveCCData[localClientNum] ) )
	{
		setup_character_streaming( level.liveCCData[localClientNum] );
	}

	level.staticCCData = setup_static_character_customization_target( localClientNum );
}

function create_character_data_struct( characterModel, localClientNum, alt_render_mode = true )
{
	if ( !isdefined( characterModel ) )
	{
		return undefined;
	}

	DEFAULT( level.custom_characters[localClientNum], [] );

	if ( isdefined( level.custom_characters[localClientNum][characterModel.targetname] ) )
	{
		return level.custom_characters[localClientNum][characterModel.targetname];
	}
	
	data_struct = SpawnStruct();
	level.custom_characters[localClientNum][characterModel.targetname] = data_struct;
	
	// models
	data_struct.characterModel = characterModel;
	data_struct.attached_model_anims = array();
	data_struct.attached_models = array();
	data_struct.attached_entities = array();
	data_struct.origin = characterModel.origin;
	data_struct.angles = characterModel.angles;
	
	// indices
	data_struct.characterIndex = 0;
	data_struct.characterMode = SESSIONMODE_INVALID;
	data_struct.splitScreenClient = undefined;
	
	data_struct.bodyIndex = 0;
	data_struct.bodyColors = array( 0, 0, 0 );

	data_struct.helmetIndex = 0;
	data_struct.helmetColors = array( 0, 0, 0 );
	
	data_struct.headIndex = 0;
	
	data_struct.align_target = undefined;
	data_struct.currentAnimation = undefined;
	data_struct.currentScene = undefined;
	
	// render options
	data_struct.body_render_options = GetCharacterBodyRenderOptions( 0, 0, 0, 0, 0 );
	data_struct.helmet_render_options = GetCharacterHelmetRenderOptions( 0, 0, 0, 0, 0 );
	data_struct.head_render_options = GetCharacterHeadRenderOptions( 0 );
	data_struct.mode_render_options = GetCharacterModeRenderOptions( 0 );
	data_struct.alt_render_mode = alt_render_mode;
	
	// menu options
	data_struct.useFrozenMomentAnim = false;
	data_struct.frozenMomentStyle = "weapon";
	data_struct.show_helmets = true;
	data_struct.allow_showcase_weapons = false;

	data_struct.force_prologue_body = false;
	if ( SessionModeIsCampaignGame() )
	{
		highestMapReached = GetDStat( localClientNum, "highestMapReached" );
		data_struct.force_prologue_body = ( !isdefined(highestMapReached) || highestMapReached == 0 ) && GetDvarString( "mapname" ) == "core_frontend";
	}

	characterModel SetHighDetail( true, data_struct.alt_render_mode );
	return data_struct;
}

function handle_forced_streaming( game_mode )
{
	return; // MJD - disable all forcing

	heroes = GetHeroes( game_mode );
	foreach( hero in heroes )
	{
		bodies = GetHeroBodyModelIndices( hero, game_mode );
		helmets = GetHeroHelmetModelIndices( hero, game_mode );
		foreach( helmet in helmets )
		{
			ForceStreamXModel( helmet, HELMET_MESH_LODS, HELMET_TEXTURE_LODS );
		}
		foreach( body in bodies )
		{
			ForceStreamXModel( body, HERO_MESH_LODS, HERO_TEXTURE_LODS );
		}
	}
	
	heads = GetHeroHeadModelIndices( game_mode );
	foreach( head in heads )
	{
		ForceStreamXModel( head, HEAD_MESH_LODS, HEAD_TEXTURE_LODS );
	}
}

///////////////////////////////////////////////////////////////////////////
// UTILITY
///////////////////////////////////////////////////////////////////////////

// supported "params" fields: align_struct, anim_name, weapon_left, weapon_right, scene, extracam_data
function loadEquippedCharacterOnModel( localClientNum, data_struct, characterIndex, params )
{
	assert( isdefined( data_struct ) );
	
	data_lcn = VAL( data_struct.splitScreenClient, localClientNum );

	if( !isdefined( characterIndex ) )
	{
		characterIndex = GetEquippedHeroIndex( data_lcn, params.sessionMode );
	}

	defaultIndex = undefined;

	if ( IS_TRUE( params.isDefaultHero ) )
	{
		defaultIndex = 0;
	}
	
	set_character( data_struct, characterIndex );
	
	characterMode = params.sessionMode;
	set_character_mode( data_struct, characterMode );
	
	
	body = get_character_body( data_lcn, characterMode, characterIndex, params.extracam_data );
	bodyColors = get_character_body_colors( data_lcn, characterMode, characterIndex, body, params.extracam_data );
	set_body( data_struct, characterMode, characterIndex, body, bodyColors );

	head = character_customization::get_character_head( data_lcn, characterMode, params.extracam_data );
	set_head( data_struct, characterMode, head );
	
	helmet = get_character_helmet( data_lcn, characterMode, characterIndex, params.extracam_data );
	helmetColors = get_character_helmet_colors( data_lcn, characterMode, data_struct.characterIndex, helmet, params.extracam_data );
	set_helmet( data_struct, characterMode, characterIndex, helmet, helmetColors );
	

	if ( IS_TRUE( data_struct.allow_showcase_weapons ) )
	{
		showcaseWeapon = get_character_showcase_weapon( data_lcn, characterMode, characterIndex, params.extracam_data );
		set_showcase_weapon( data_struct, characterMode, data_lcn, undefined, characterIndex, showcaseWeapon.weaponName, showcaseWeapon.attachmentInfo, showcaseWeapon.weaponRenderOptions, false, true );
	}
	
	return update( localClientNum, data_struct, params );
}

#using_animtree("generic");
#define ANIM_NOTIFY "_anim_notify_"

function update_model_attachment( localClientNum, data_struct, attached_model, slot, model_anim, model_intro_anim, force_update )
{
	assert( isdefined( data_struct.attached_models ) );
	assert( isdefined( data_struct.attached_model_anims ) );
	assert( isdefined( level.model_type_bones ) );
	
	if ( force_update || attached_model !== data_struct.attached_models[slot] || model_anim !== data_struct.attached_model_anims[slot] )
	{
		bone = slot;
		if ( isdefined( level.model_type_bones[slot] ) )
		{
			bone = level.model_type_bones[slot];
		}
		
		assert( isdefined( bone ) );
	
		if ( isdefined( data_struct.attached_models[slot] ) )
		{
			if ( isDefined(data_struct.attached_entities[slot]) )
			{
				data_struct.attached_entities[slot] Unlink();
				data_struct.attached_entities[slot] Delete();
				data_struct.attached_entities[slot] = undefined;
			}
			else
			{
				if( data_struct.characterModel IsAttached( data_struct.attached_models[slot], bone ) )
				{
					data_struct.characterModel Detach( data_struct.attached_models[slot], bone );
				}
			}
			
			data_struct.attached_models[slot] = undefined;
		}

		data_struct.attached_models[slot] = attached_model;
		if ( isdefined( data_struct.attached_models[slot] ) )
		{
			if ( isDefined(model_anim) )
			{
				ent = Spawn( localClientNum, data_struct.characterModel.origin, "script_model" );
				ent SetHighDetail( true, data_struct.alt_render_mode );
				data_struct.attached_entities[slot] = ent;
				ent SetModel( data_struct.attached_models[slot] );
				if ( !ent HasAnimTree() )
				{
					ent UseAnimTree( #animtree );
				}
				
				ent.origin = data_struct.characterModel.origin;
				ent.angles = data_struct.characterModel.angles;
				ent.chosenOrigin = ent.origin;
				ent.chosenAngles = ent.angles;
				ent thread play_intro_and_animation( model_intro_anim, model_anim, true );
			}
			else
			{
				if ( !data_struct.characterModel IsAttached( data_struct.attached_models[slot], bone ) )
				{
					data_struct.characterModel Attach( data_struct.attached_models[slot], bone );
				}
			}

			data_struct.attached_model_anims[slot] = model_anim;
		}
	}

	// Need to set the customization since it could have changed without changing attachments. 
	if ( isDefined( data_struct.attached_entities[slot] ) )
		data_struct.attached_entities[slot] SetBodyRenderOptions( data_struct.mode_render_options, data_struct.body_render_options, data_struct.helmet_render_options, data_struct.head_render_options );
}

function set_character( data_struct, characterIndex )
{
	data_struct.characterIndex = characterIndex;
}

function set_character_mode( data_struct, characterMode )
{
	assert( isdefined( characterMode ) );
	data_struct.characterMode = characterMode;
	data_struct.mode_render_options = GetCharacterModeRenderOptions( characterMode );
}

function set_body( data_struct, mode, characterIndex, bodyIndex, bodyColors )
{
	assert( isdefined( mode ) );
	assert( mode != SESSIONMODE_INVALID );
	
	if ( mode == SESSIONMODE_CAMPAIGN && IS_TRUE(data_struct.force_prologue_body) )
	{
		bodyIndex = 1; // force pbt_cp_male_body_01_prologue or pbt_cp_female_body_01_prologue since we're not cyber yet
	}

	data_struct.bodyIndex = bodyIndex;
	data_struct.bodyModel = GetCharacterBodyModel( characterIndex, bodyIndex, mode );
	
	if( isdefined( data_struct.bodyModel ) )
	{
		data_struct.characterModel SetModel( data_struct.bodyModel );
	}
	
	if( isdefined( bodyColors ) )
	{
		set_body_colors( data_struct, mode, bodyColors );
	}
	
	render_options = GetCharacterBodyRenderOptions( data_struct.characterIndex, data_struct.bodyIndex, data_struct.bodyColors[0], data_struct.bodyColors[1], data_struct.bodyColors[2] );
	data_struct.body_render_options = render_options;
}

function set_body_colors( data_struct, mode, bodyColors )
{
	for( i = 0; i < bodyColors.size && i < bodyColors.size; i++ )
	{
		set_body_color( data_struct, i, bodyColors[ i ] );
	}
}

function set_body_color( data_struct, colorSlot, colorIndex )
{
	data_struct.bodyColors[ colorSlot ] = colorIndex;
	
	render_options = GetCharacterBodyRenderOptions( data_struct.characterIndex, data_struct.bodyIndex, data_struct.bodyColors[0], data_struct.bodyColors[1], data_struct.bodyColors[2] );
	data_struct.body_render_options = render_options;
}

function set_head( data_struct, mode, headIndex )
{
	data_struct.headIndex = headIndex;
	data_struct.headModel = GetCharacterHeadModel( headIndex, mode );
	
	render_options = GetCharacterHeadRenderOptions( headIndex );
	data_struct.head_render_options = render_options;
}

function set_helmet( data_struct, mode, characterIndex, helmetIndex, helmetColors )
{
	data_struct.helmetIndex = helmetIndex;
	data_struct.helmetModel = GetCharacterHelmetModel( characterIndex, helmetIndex, mode );
	
	set_helmet_colors( data_struct, helmetColors );
}

function set_showcase_weapon( data_struct, mode, localClientNum, xuid, characterIndex, showcaseWeaponName, showcaseWeaponAttachmentInfo, weaponRenderOptions, useShowcasePaintjob, useLocalPaintshop )
{
	if ( isdefined( xuid ) )
	{
		SetShowcaseWeaponPaintshopXUID( localClientNum, xuid );
	}
	else
	{
		SetShowcaseWeaponPaintshopXUID( localClientNum );
	}	
	
	data_struct.showcaseWeaponName = showcaseWeaponName;
	data_struct.showcaseWeaponModel = GetWeaponWithAttachments( showcaseWeaponName );
	
	if ( data_struct.showcaseWeaponModel == GetWeapon( "none" ) )
	{
		// Fallback in case there is no weapon.
		data_struct.showcaseWeaponModel = GetWeapon( "ar_standard" );
		data_struct.showcaseWeaponName = data_struct.showcaseWeaponModel.name;
	}
	
	attachmentNames = [];
	attachmentIndices = [];
	tokenizedAttachmentInfo = strtok( showcaseWeaponAttachmentInfo, "," );
	for ( index = 0; index + 1 < tokenizedAttachmentInfo.size; index += 2 )
	{
		attachmentNames[ attachmentNames.size ] = tokenizedAttachmentInfo[ index ];
		attachmentIndices[ attachmentIndices.size ] = int( tokenizedAttachmentInfo[ index + 1 ] );
	}
	for ( index = tokenizedAttachmentInfo.size; index + 1 < 16; index += 2 )
	{
		attachmentNames[ attachmentNames.size ] = "none";
		attachmentIndices[ attachmentIndices.size ] = 0;
	}
	data_struct.acvi = GetAttachmentCosmeticVariantIndexes( data_struct.showcaseWeaponModel,
															attachmentNames[ 0 ], attachmentIndices[ 0 ],
															attachmentNames[ 1 ], attachmentIndices[ 1 ],
															attachmentNames[ 2 ], attachmentIndices[ 2 ],
															attachmentNames[ 3 ], attachmentIndices[ 3 ],
															attachmentNames[ 4 ], attachmentIndices[ 4 ],
															attachmentNames[ 5 ], attachmentIndices[ 5 ],
															attachmentNames[ 6 ], attachmentIndices[ 6 ],
															attachmentNames[ 7 ], attachmentIndices[ 7 ] );
	
	camoIndex = 0;
	paintjobSlot = CUSTOMIZATION_INVALID_PAINTJOB_SLOT;
	paintjobIndex = CUSTOMIZATION_INVALID_PAINTJOB_INDEX;
	showPaintshop = false;
	tokenizedWeaponRenderOptions = strtok( weaponRenderOptions, "," );
	if ( tokenizedWeaponRenderOptions.size > 2 )
	{
		camoIndex = int( tokenizedWeaponRenderOptions[ 0 ] );
		paintjobSlot = int( tokenizedWeaponRenderOptions[ 1 ] );
		paintjobIndex = int( tokenizedWeaponRenderOptions[ 2 ] );
		showPaintshop = paintjobSlot != CUSTOMIZATION_INVALID_PAINTJOB_SLOT && paintjobIndex != CUSTOMIZATION_INVALID_PAINTJOB_INDEX;
	}
	
	paintshopClassType = 0;
	if ( useShowcasePaintjob )
	{
		paintshopClassType = SHOWCASE_WEAPON_PAINTSHOP_CLASS;
	}
	else if ( useLocalPaintshop )
	{
		paintshopClassType = LOCAL_WEAPON_PAINTSHOP_CLASS;
	}
	data_struct.weaponRenderOptions = CalcWeaponOptions( localClientNum, camoIndex, 0, 0, false, false, showPaintshop, paintshopClassType );
	
	weapon_root_name = data_struct.showcaseWeaponModel.rootWeapon.name;
	weapon_is_dual_wield = data_struct.showcaseWeaponModel.isdualwield;
	weapon_group = GetItemGroupForWeaponName( weapon_root_name );
	
	if ( weapon_group == "weapon_launcher" )
	{
		if ( weapon_root_name == "launcher_lockonly" ||
		     weapon_root_name == "launcher_multi" )
		{
			weapon_group = "weapon_launcher_alt";
		}
		else if ( weapon_root_name == "launcher_ex41" )
		{
			weapon_group = "weapon_smg_ppsh";
		}
	}
	else if ( weapon_group == "weapon_pistol" && weapon_is_dual_wield )
	{
		weapon_group = "weapon_pistol_dw";
	}
	else if ( weapon_group == "weapon_smg")
	{
		if ( weapon_root_name == "smg_ppsh" )
		{
			weapon_group = "weapon_smg_ppsh";
		}
	}
	else if ( weapon_group == "weapon_cqb")
	{
		if ( weapon_root_name == "shotgun_olympia" )
		{
			weapon_group = "weapon_shotgun_olympia";
		}
	}
	else if ( weapon_group == "weapon_special" )
	{
		if ( weapon_root_name == "special_crossbow" ||
				weapon_root_name == "special_discgun" )
		{
			weapon_group = "weapon_smg";
		}
		else if( weapon_root_name == "special_crossbow_dw" )
		{
			weapon_group = "weapon_pistol_dw";
		}
		else if( weapon_root_name == "knife_ballistic" )
		{
			weapon_group = "weapon_knife_ballistic";
		}
	}
	else if ( weapon_group == "weapon_knife" )
	{
		if ( weapon_root_name == "melee_knuckles" || 
				weapon_root_name == "melee_boxing" )
		{
			weapon_group = "weapon_knuckles";
		}
		else if ( weapon_root_name == "melee_chainsaw" || 
				weapon_root_name == "melee_boneglass" || 
				weapon_root_name == "melee_crescent" )
		{
			weapon_group = "weapon_chainsaw";
		}
		else if ( weapon_root_name == "melee_improvise" ||
		          weapon_root_name == "melee_shovel" )
		{
			weapon_group = "weapon_improvise";
		}
		else if ( weapon_root_name == "melee_wrench" ||
		          weapon_root_name == "melee_crowbar" ||
		          weapon_root_name == "melee_shockbaton" )
		{
			weapon_group = "weapon_wrench";
		}
		else if ( weapon_root_name == "melee_nunchuks" )
		{
			weapon_group = "weapon_nunchucks";
		}
		else if ( weapon_root_name == "melee_sword" ||
		          weapon_root_name == "melee_bat" ||
		          weapon_root_name == "melee_fireaxe" ||
		          weapon_root_name == "melee_mace" ||
		          weapon_root_name == "melee_katana" )
		{
			weapon_group = "weapon_sword";
		}
		else if ( weapon_root_name == "melee_prosthetic" )
		{
			weapon_group = "weapon_prosthetic";
		}
	}
	else if ( weapon_group == "miscweapon" )
	{
		if ( weapon_root_name == "blackjack_coin" )
		{
			weapon_group = "brawler";
		}
		else if ( weapon_root_name == "blackjack_cards" )
		{
			weapon_group = "brawler";
		}
	}
	
	if ( data_struct.characterMode === SESSIONMODE_ZOMBIES )
	{
		data_struct.anim_name = INSPECTION_POSE_ZM;
	}
	else if ( isdefined( WEAPON_GROUP_FRONTEND_ANIMS[ weapon_group ] ) )
	{
		data_struct.anim_name = WEAPON_GROUP_FRONTEND_ANIMS[ weapon_group ];
	}
}


function set_helmet_colors( data_struct, colors )
{
	for ( i = 0; i < colors.size && i < data_struct.helmetColors.size; i++ )
	{
		set_helmet_color( data_struct, i, colors[ i ] );
	}
	
	render_options = GetCharacterHelmetRenderOptions( data_struct.characterIndex, data_struct.helmetIndex, data_struct.helmetColors[0], data_struct.helmetColors[1], data_struct.helmetColors[2] );
	data_struct.helmet_render_options = render_options;
}

function set_helmet_color( data_struct, colorSlot, colorIndex )
{
	data_struct.helmetColors[ colorSlot ] = colorIndex;
	
	render_options = GetCharacterHelmetRenderOptions( data_struct.characterIndex, data_struct.helmetIndex, data_struct.helmetColors[0], data_struct.helmetColors[1], data_struct.helmetColors[2] );
	data_struct.helmet_render_options = render_options;
}

function update( localClientNum, data_struct, params )
{
	data_struct.characterModel SetBodyRenderOptions( data_struct.mode_render_options, data_struct.body_render_options, data_struct.helmet_render_options, data_struct.head_render_options );
	
	helmet_model = "tag_origin";
	
	show_helmet = data_struct.show_helmets && ( !isdefined( params ) || !IS_TRUE( params.hide_helmet ) );
	if ( show_helmet )
	{
		helmet_model = data_struct.helmetModel;
	}

	update_model_attachment( localClientNum, data_struct, helmet_model, "helmet", undefined, undefined, true );
	
	head_model = data_struct.headModel;
	if ( show_helmet && isdefined( params ) && GetCharacterHelmetHidesHead( data_struct.characterIndex, data_struct.helmetIndex, VAL( params.sessionMode, data_struct.characterMode ) ) )
	{
		assert( helmet_model != "tag_origin" );
		head_model = "tag_origin";
	}
	update_model_attachment( localClientNum, data_struct, head_model, "head", undefined, undefined, true );
	
	changed = update_character_animation_and_attachments( localClientNum, data_struct, params );
	
	// Used by epic taunts to clone the model and match skins
	data_struct.characterModel.bodyModel = data_struct.bodyModel;
	data_struct.characterModel.helmetModel = data_struct.helmetModel;
	data_struct.characterModel.modeRenderOptions = data_struct.mode_render_options;
	data_struct.characterModel.bodyRenderOptions = data_struct.body_render_options;
	data_struct.characterModel.helmetRenderOptions = data_struct.helmet_render_options;
	data_struct.characterModel.headRenderOptions = data_struct.head_render_options;
	
	return changed;
}

function is_character_streamed( data_struct )
{
	if( isDefined( data_struct.characterModel ) )
	{
		if( !( data_struct.characterModel isStreamed() ) )
		{
			return false;
		}
	}

	foreach( ent in data_struct.attached_entities )
	{
		if( isDefined( ent ) )
		{
			if( !( ent isStreamed() ) )
			{
				return false;
			}
		}
	}

	return true;
}

function setup_character_streaming( data_struct )
{
	// init, force high detail
	if( isDefined( data_struct.characterModel ) )
	{
		data_struct.characterModel SetHighDetail( true, data_struct.alt_render_mode );
	}

	foreach( ent in data_struct.attached_entities )
	{
		if( isDefined( ent ) )
		{
			ent SetHighDetail( true, data_struct.alt_render_mode );
		}
	}
}

function get_character_mode( localClientNum )
{
	return GetEquippedHeroMode( localClientNum );
}

function get_character_body( localClientNum, characterMode, characterIndex, extracamData )
{
	assert( isdefined( characterIndex ) );
	
	if ( characterMode === SESSIONMODE_CAMPAIGN && SessionModeIsCampaignGame() && GetDvarString( "mapname" ) == "core_frontend" )
	{
		mapIndex = GetDStat( localClientNum, "highestMapReached" );
		if ( isDefined( mapindex ) && mapIndex < 1) //robot after ethiopia mission
		{
			str_gender = GetHeroGender( GetEquippedHeroIndex( localClientNum, SESSIONMODE_CAMPAIGN ), "cp" );
			n_body_id = GetCharacterBodyStyleIndex( str_gender=="female", "CPUI_OUTFIT_PROLOGUE" );
			return n_body_id;//always the flesh body in the frontend for cp - user edits body in safehouse
		}
	}

	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return 0;
	}
	else if( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedBodyIndexForHero( localClientNum, characterMode, extracamData.jobIndex, true );
	}
	else if ( isdefined( extracamData ) && isdefined( extracamData.useBodyIndex ) )
	{
		return extracamData.useBodyIndex;
	}
	else if ( isdefined( extracamData ) && IS_TRUE( extracamData.defaultImageRender ) )
	{
		return 0;
	}
	else
	{
		return GetEquippedBodyIndexForHero( localClientNum, characterMode, characterIndex );
	}
}

function get_character_body_color( localClientNum, characterMode, characterIndex, bodyIndex, colorSlot, extracamData )
{
	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return 0;
	}
	else if( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedBodyAccentColorForHero( localClientNum, characterMode, extracamData.jobIndex, bodyIndex, colorSlot, true );
	}
	else if ( isdefined( extracamData ) && IS_TRUE( extracamData.defaultImageRender ) )
	{
		return 0;
	}
	else
	{
		return GetEquippedBodyAccentColorForHero( localClientNum, characterMode, characterIndex, bodyIndex, colorSlot );
	}
}

function get_character_body_colors( localClientNum, characterMode, characterIndex, bodyIndex, extracamData )
{
	bodyAccentColorCount = GetBodyAccentColorCountForHero( localClientNum, characterMode, characterIndex, bodyIndex );
	
	colors = [];
	for( i = 0; i < 3; i++ )
	{
		colors[ i ] = 0;
	}
	
	for( i = 0; i < bodyAccentColorCount; i++ )
	{
		colors[ i ] = get_character_body_color( localClientNum, characterMode, characterIndex, bodyIndex, i, extracamData );
	}
	
	return colors;
}

function get_character_head( localClientNum, characterMode, extracamData )
{
	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return 0;
	}
	else if ( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedHeadIndexForHero( localClientNum, characterMode, extracamData.jobIndex );
	}
	else if ( isdefined( extracamData ) && isdefined( extracamData.useHeadIndex ) )
	{
		return extracamData.useHeadIndex;
	}
	else if ( isdefined( extracamData ) && IS_TRUE( extracamData.defaultImageRender ) )
	{
		return 0;
	}
	else
	{
		return GetEquippedHeadIndexForHero( localClientNum, characterMode );
	}
}

function get_character_helmet( localClientNum, characterMode, characterIndex, extracamData )
{
	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return 0;
	}
	else if ( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedHelmetIndexForHero( localClientNum, characterMode, extracamData.jobIndex, true );
	}
	else if ( isdefined( extracamData ) && isdefined( extracamData.useHelmetIndex ) )
	{
		return extracamData.useHelmetIndex;
	}
	else if ( isdefined( extracamData ) && IS_TRUE( extracamData.defaultImageRender ) )
	{
		return 0;
	}
	else
	{
		return GetEquippedHelmetIndexForHero( localClientNum, characterMode, characterIndex );
	}
}

function get_character_showcase_weapon( localClientNum, characterMode, characterIndex, extracamData )
{
	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return undefined;
	}
	else if ( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedShowcaseWeaponForHero( localClientNum, characterMode, extracamData.jobIndex, true );
	}
	else if ( isdefined( extracamData ) && isdefined( extracamData.useShowcaseWeapon ) )
	{
		return extracamData.useShowcaseWeapon;
	}
	else
	{
		return GetEquippedShowcaseWeaponForHero( localClientNum, characterMode, characterIndex );
	}
}

function get_character_helmet_color( localClientNum, characterMode, characterIndex, helmetIndex, colorSlot, extracamData )
{
	if( isdefined( extracamData ) && IS_TRUE(extracamData.isDefaultHero) )
	{
		return 0;
	}
	else if ( isdefined( extracamData ) && extracamData.useLobbyPlayers )
	{
		return GetEquippedHelmetAccentColorForHero( localClientNum, characterMode, extracamData.jobIndex, helmetIndex, colorSlot, true );
	}
	else if ( isdefined( extracamData ) && IS_TRUE( extracamData.defaultImageRender ) )
	{
		return 0;
	}
	else
	{
		return GetEquippedHelmetAccentColorForHero( localClientNum, characterMode, characterIndex, helmetIndex, colorSlot );
	}
}

function get_character_helmet_colors( localClientNum, characterMode, characterIndex, helmetIndex, extracamData )
{
	helmetColorCount = GetHelmetAccentColorCountForHero( localClientNum, characterMode, characterIndex, helmetIndex );
	
	colors = [];
	for( i = 0; i < 3; i++ )
	{
		colors[ i ] = 0;
	}
	
	for( i = 0; i < helmetColorCount; i++ )
	{
		colors[ i ] = get_character_helmet_color( localClientNum, characterMode, characterIndex, helmetIndex, i, extracamData );
	}
	
	return colors;
}

#using_animtree("all_player");
function update_character_animation_tree_for_scene(characterModel)
{
	if ( !characterModel HasAnimTree() )
	{
		characterModel UseAnimTree( #animtree );
	}
}

function reaper_body3_hack( params )
{
	if ( IsDefined(params.weapon_right) && params.weapon_right == "wpn_t7_hero_reaper_minigun_prop" && isDefined( level.mp_lobby_data_struct.characterModel ) && IsSubStr(level.mp_lobby_data_struct.characterModel.model, "body3")  )
	{
		params.weapon_right = "wpn_t7_loot_hero_reaper3_minigun_prop";
		params.weapon = GetWeapon("hero_minigun_body3");
		return true;
	}
	return false;
}
	
function get_current_frozen_moment_params( localClientNum, data_struct, params )
{
	fields = GetCharacterFields( data_struct.characterIndex, data_struct.characterMode );
		
	if ( data_struct.frozenMomentStyle == "weapon" )
	{
		SET_IF_DEFINED( params.anim_name, fields.weaponFrontendFrozenMomentXAnim );
		params.scene = undefined;
		SET_IF_DEFINED( params.weapon_left, fields.weaponFrontendFrozenMomentWeaponLeftModel );
		SET_IF_DEFINED( params.weapon_left_anim, fields.weaponFrontendFrozenMomentWeaponLeftAnim );
		SET_IF_DEFINED( params.weapon_right, fields.weaponFrontendFrozenMomentWeaponRightModel );
		SET_IF_DEFINED( params.weapon_right_anim, fields.weaponFrontendFrozenMomentWeaponRightAnim );
		SET_IF_DEFINED( params.exploder_id, fields.weaponFrontendFrozenMomentExploder );
		SET_IF_DEFINED( params.align_struct, struct::get( fields.weaponFrontendFrozenMomentAlignTarget ) );
		SET_IF_DEFINED( params.xcam, fields.weaponFrontendFrozenMomentXCam );
		SET_IF_DEFINED( params.subXCam, fields.weaponFrontendFrozenMomentXCamSubXCam );
		SET_IF_DEFINED( params.xcamFrame, fields.weaponFrontendFrozenMomentXCamFrame );
	}
	else if ( data_struct.frozenMomentStyle == "ability" )
	{
		SET_IF_DEFINED( params.anim_name, fields.abilityFrontendFrozenMomentXAnim );
		params.scene = undefined;
		SET_IF_DEFINED( params.weapon_left, fields.abilityFrontendFrozenMomentWeaponLeftModel );
		SET_IF_DEFINED( params.weapon_left_anim, fields.abilityFrontendFrozenMomentWeaponLeftAnim );
		SET_IF_DEFINED( params.weapon_right, fields.abilityFrontendFrozenMomentWeaponRightModel );
		SET_IF_DEFINED( params.weapon_right_anim, fields.abilityFrontendFrozenMomentWeaponRightAnim );
		SET_IF_DEFINED( params.exploder_id, fields.abilityFrontendFrozenMomentExploder );
		SET_IF_DEFINED( params.align_struct, struct::get( fields.abilityFrontendFrozenMomentAlignTarget ) );
		SET_IF_DEFINED( params.xcam, fields.abilityFrontendFrozenMomentXCam );
		SET_IF_DEFINED( params.subXCam, fields.abilityFrontendFrozenMomentXCamSubXCam );
		SET_IF_DEFINED( params.xcamFrame, fields.abilityFrontendFrozenMomentXCamFrame );
	}
	
	reaper_body3_hack( params );
	
	if ( !isdefined( params.align_struct ) )
	{
		params.align_struct = data_struct; // moves the character back to their original position
	}
}

function play_intro_and_animation( intro_anim_name, anim_name, b_keep_link )
{
	self notify( "stop_vignette_animation" );
	self endon( "stop_vignette_animation" );

	if ( isdefined(intro_anim_name) )
	{
		self animation::play( intro_anim_name, self.chosenOrigin, self.chosenAngles, 1, 0, 0, 0, b_keep_link );
	}
	self animation::play( anim_name, self.chosenOrigin, self.chosenAngles, 1, 0, 0, 0, b_keep_link );
}

function update_character_animation_based_on_showcase_weapon( data_struct, params )
{
	if ( !isdefined( params.weapon_right ) && !isdefined( params.weapon_left ) )
	{
		if ( isdefined( data_struct.anim_name ) )
		{
			params.anim_name = data_struct.anim_name;
		}
	}
}

function update_character_animation_and_attachments( localClientNum, data_struct, params )
{
	changed = false;
	
	if ( !isdefined( params ) )
	{
		params = SpawnStruct();
	}
	
	if ( data_struct.useFrozenMomentAnim && isdefined( data_struct.frozenMomentStyle ) )
	{
		get_current_frozen_moment_params( localClientNum, data_struct, params );
	}
	
	if ( !isdefined( params.exploder_id ) )
	{
		params.exploder_id = data_struct.default_exploder;
	}
	
	align_changed = false;
	DEFAULT( params.align_struct, struct::get( data_struct.align_target ) );
	DEFAULT( params.align_struct, data_struct );
	if ( isdefined( params.align_struct ) && ( params.align_struct.origin !== data_struct.characterModel.chosenOrigin || params.align_struct.angles !== data_struct.characterModel.chosenAngles ) )
	{	
		data_struct.characterModel.chosenOrigin = params.align_struct.origin;
		data_struct.characterModel.chosenAngles = params.align_struct.angles;
		params.anim_name = ( isdefined( params.anim_name ) ? params.anim_name : data_struct.currentAnimation );
		align_changed = true;
	}
	
	if ( IS_TRUE( data_struct.allow_showcase_weapons ) )
	{
		update_character_animation_based_on_showcase_weapon( data_struct, params );
	}
	
	if ( character_customization::reaper_body3_hack( params ) )
	{
		align_changed = true;
		changed = true;
	}
	
	if ( IsDefined( params.weapon_right ) && params.weapon_right !== data_struct.weapon_right )
	{
		align_changed = true;
	}
	
	if ( isdefined( params.anim_name ) && ( params.anim_name !== data_struct.currentAnimation || align_changed ) )
	{
		changed = true;

		end_game_taunts::cancelTaunt( localClientNum, data_struct.characterModel );
		end_game_taunts::cancelGesture( data_struct.characterModel );
		
		data_struct.currentAnimation = params.anim_name;
		data_struct.weapon_right = params.weapon_right;
		if ( !data_struct.characterModel HasAnimTree() )
		{
			data_struct.characterModel UseAnimTree( #animtree );
		}
		
		data_struct.characterModel thread play_intro_and_animation( params.anim_intro_name, params.anim_name, false );
	}
	else if ( isdefined( params.scene ) && params.scene !== data_struct.currentScene )
	{
		if ( isdefined( data_struct.currentScene ) )
		{
			level scene::stop( data_struct.currentScene, false );
		}
		
		update_character_animation_tree_for_scene(data_struct.characterModel);
		
		data_struct.currentScene = params.scene;
		level thread scene::play( params.scene );
	}
	
	if ( data_struct.exploder_id !== params.exploder_id )
	{
		if ( isdefined( data_struct.exploder_id ) )
		{
			KillRadiantExploder( localClientNum, data_struct.exploder_id );
		}
		
		if ( isdefined( params.exploder_id ) )
		{
			PlayRadiantExploder( localClientNum, params.exploder_id );
		}
		
		data_struct.exploder_id = params.exploder_id;
	}
	
	if ( isdefined( params.weapon_right ) || isdefined( params.weapon_left ) )
	{
		update_model_attachment( localClientNum, data_struct, params.weapon_right, "tag_weapon_right", params.weapon_right_anim, params.weapon_right_anim_intro, align_changed );
		update_model_attachment( localClientNum, data_struct, params.weapon_left, "tag_weapon_left", params.weapon_left_anim, params.weapon_left_anim_intro, align_changed );
	}
	else if ( isdefined( data_struct.showcaseWeaponModel ) )
	{
		if( isdefined( data_struct.attached_models["tag_weapon_right"] ) && data_struct.characterModel IsAttached( data_struct.attached_models["tag_weapon_right"], "tag_weapon_right" ) )
		{
			data_struct.characterModel Detach( data_struct.attached_models["tag_weapon_right"], "tag_weapon_right" );
		}
		
		if( isdefined( data_struct.attached_models["tag_weapon_left"] ) && data_struct.characterModel IsAttached( data_struct.attached_models["tag_weapon_left"], "tag_weapon_left" ) )
		{
			data_struct.characterModel Detach( data_struct.attached_models["tag_weapon_left"], "tag_weapon_left" );
		}
		
		data_struct.characterModel AttachWeapon( data_struct.showcaseWeaponModel, data_struct.weaponRenderOptions, data_struct.acvi );
		data_struct.characterModel UseWeaponHideTags( data_struct.showcaseWeaponModel );
		
		data_struct.characterModel.showcaseWeapon = data_struct.showcaseWeaponModel;
		data_struct.characterModel.showcaseWeaponRenderOptions = data_struct.weaponRenderOptions;
		data_struct.characterModel.showcaseWeaponACVI = data_struct.acvi;
	}
	
	return changed;
}

function update_use_frozen_moments( localClientNum, data_struct, useFrozenMoments )
{
	if ( data_struct.useFrozenMomentAnim != useFrozenMoments )
	{
		data_struct.useFrozenMomentAnim = useFrozenMoments;
		params = SpawnStruct();
		if ( !data_struct.useFrozenMomentAnim )
		{
			params.align_struct = struct::get( LIVE_CHARACTER_SPAWN_TARGET );
			params.anim_name = HERO_CUSTOMIZE_IDLE_ANIM;
		}
		
		MarkAsDirty( data_struct.characterModel );
		update_character_animation_and_attachments( localClientNum, data_struct, params );
		
		if ( data_struct.useFrozenMomentAnim )
		{
			level notify( "frozenMomentChanged" + localClientNum );
		}
	}
}

function update_show_helmets( localClientNum, data_struct, show_helmets )
{
	if ( data_struct.show_helmets != show_helmets )
	{
		data_struct.show_helmets = show_helmets;
		
		params = SpawnStruct();
		params.weapon_right = data_struct.attached_models["tag_weapon_right"];
		params.weapon_left = data_struct.attached_models["tag_weapon_left"];
		update( localClientNum, data_struct, params );
	}
}

function set_character_align( localClientNum, data_struct, align_target )
{
	if ( data_struct.align_target !== align_target )
	{
		data_struct.align_target = align_target;
		
		params = SpawnStruct();
		params.weapon_right = data_struct.attached_models["tag_weapon_right"];
		params.weapon_left = data_struct.attached_models["tag_weapon_left"];
		update( localClientNum, data_struct, params );
	}
}

///////////////////////////////////////////////////////////////////////////
// LIVE CHARACTER
///////////////////////////////////////////////////////////////////////////

function setup_live_character_customization_target( localClientNum )
{
	characterEnt = GetEnt( localClientNum, LIVE_CHARACTER_SPAWN_TARGET, "targetname" );
	
	if ( isdefined( characterEnt ) )
	{
		customization_data_struct = character_customization::create_character_data_struct( characterEnt, localClientNum, true );
		customization_data_struct.default_exploder = DEFAULT_LIVE_CHARACTER_EXPLODER;
		customization_data_struct.allow_showcase_weapons = true;
		level thread updateEventThread( localClientNum, customization_data_struct );
		
		return customization_data_struct;
	}
	
	return undefined;
}

function update_locked_shader( localClientNum, params )
{
	if( IsDefined( params.isItemUnlocked ) && params.isItemUnlocked != 1 )
	{
		EnableFrontendLockedWeaponOverlay( localClientNum, true );
	}
	else
	{
		EnableFrontendLockedWeaponOverlay( localClientNum, false );
	}
}

function updateEventThread( localClientNum, data_struct )
{
	while( 1 )
	{
		level waittill( "updateHero" + localClientNum, eventType, param1, param2, param3, param4 );
		
		switch( eventType )
		{
			case "update_lcn":
				data_struct.splitScreenClient = param1;
				break;
				
			case "refresh":
				data_struct.splitScreenClient = param1;
				
				params = spawnstruct();
				params.anim_name = HERO_CUSTOMIZE_IDLE_ANIM;
				params.sessionMode = param2;
				character_customization::loadEquippedCharacterOnModel( localClientNum, data_struct, undefined, params );
				if (isdefined(param3) && param3 != "")
				{
					level.mp_lobby_data_struct.playSound = param3;
				}
				
				break;
				
			case "changeHero":
				// param1 = hero index
				// param2 = session mode
				params = spawnstruct();
				params.anim_name = HERO_CUSTOMIZE_IDLE_ANIM;
				params.sessionMode = param2;
				character_customization::loadEquippedCharacterOnModel( localClientNum, data_struct, param1, params );
				break;
				
			case "changeBody":
				//param1 = new body index
				//param2 = session mode
				//param3 = is item unlocked
				params = spawnstruct();
				params.sessionMode = param2;
				params.isItemUnlocked = param3;
				character_customization::set_body( data_struct, param2, data_struct.characterIndex, param1, get_character_body_colors( localClientNum, param2, data_struct.characterIndex, param1 ) );
				character_customization::update( localClientNum, data_struct, params );
				//update the locked shader
				update_locked_shader( localClientNum, params );
				break;
				
			case "changeHelmet":
				//param1 = new helmet index
				//param2 = session mode
				//param3 = is item unlocked
				params = spawnstruct();
				params.sessionMode = param2;
				params.isItemUnlocked = param3;
				character_customization::set_helmet( data_struct, param2, data_struct.characterIndex, param1, get_character_helmet_colors( localClientNum, param2, data_struct.characterIndex, param1 ) );
				character_customization::update( localClientNum, data_struct, params );
				//update the locked shader
				update_locked_shader( localClientNum, params );
				break;
				
			case "changeShowcaseWeapon":
				//param1 = showcase weapon name
				//param2 = attachment info
				//param3 = camo and paintjob info
				//param4 = session mode
				params = spawnstruct();
				params.sessionMode = param4;
				character_customization::set_showcase_weapon( data_struct, param4, localClientNum, undefined, data_struct.characterIndex, param1, param2, param3, false, true );
				character_customization::update( localClientNum, data_struct, params );
				break;
				
			case "changeHead":
				//param1 = head index
				params = spawnstruct();
				params.sessionMode = param2;
				character_customization::set_head( data_struct, param2, param1 );
				character_customization::update( localClientNum, data_struct, params );
				break;
				
			case "changeBodyAccentColor":
				//param1 = accent color slot
				//param2 = accent color index
				params = spawnstruct();
				params.sessionMode = param3;
				character_customization::set_body_color( data_struct, param1, param2 );
				character_customization::update( localClientNum, data_struct, params );
				break;
				
			case "changeHelmetAccentColor":
				//param1 = accent color slot
				//param2 = accent color index
				//param3 = sessionMode
				params = spawnstruct();
				params.sessionMode = param3;
				character_customization::set_helmet_color( data_struct, param1, param2 );
				character_customization::update( localClientNum, data_struct, params );
				break;
				
			case "changeFrozenMoment":
				//param1 = new frozen moment type
				data_struct.frozenMomentStyle = param1;
				if ( data_struct.useFrozenMomentAnim )
				{
					MarkAsDirty( data_struct.characterModel );
					update_character_animation_and_attachments( localClientNum, data_struct, undefined );
				}
				level notify( "frozenMomentChanged" + localClientNum );
				break;
				
			case "previewGesture":
				//param1 = new anim name
				data_struct.currentAnimation = param1;
				thread end_game_taunts::previewGesture( localClientNum, data_struct.characterModel, data_struct.anim_name, param1 );
				break;
				
			case "previewTaunt":
				//param1 = new anim name
				if ( character_customization::is_character_streamed( data_struct ) )
				{
					data_struct.currentAnimation = param1;
					thread end_game_taunts::previewTaunt( localClientNum, data_struct.characterModel, data_struct.anim_name, param1 );
				}
				break;
		}
	}
}

function rotation_thread_spawner( localClientNum, data_struct, endOnEvent )
{
	if ( !isdefined( endOnEvent ) )
	{
		return;
	}
	
	assert( isdefined( data_struct.characterModel ) );
	model = data_struct.characterModel;
	baseAngles = model.angles;
	
	level thread update_model_rotation_for_right_stick( localClientNum, data_struct, endOnEvent );
	level waittill( endOnEvent );
	
	if ( !IS_TRUE( data_struct.characterModel.anglesOverride ) )
	{
		model.angles = baseAngles;
	}
}

function update_model_rotation_for_right_stick( localClientNum, data_struct, endOnEvent )
{
	level endon( endOnEvent );
	assert( isdefined( data_struct.characterModel ) );
	model = data_struct.characterModel;
	
	while ( true )
	{
		data_lcn = VAL( data_struct.splitScreenClient, localClientNum );
		
		if ( LocalClientActive( data_lcn ) && !IS_TRUE( data_struct.characterModel.anglesOverride ) )
		{
			pos = GetControllerPosition( data_lcn );
			
			if ( isdefined( pos["rightStick"] ) )
			{
				model.angles = ( model.angles[0], AbsAngleClamp360( model.angles[1] + pos["rightStick"][0] * RS_ROTATION_SPEED_MULTIPLIER ), model.angles[2] );
			}
			else
			{
				model.angles = ( model.angles[0], AbsAngleClamp360( model.angles[1] + pos["look"][0] * RS_ROTATION_SPEED_MULTIPLIER ), model.angles[2] );
			}
			
			if ( IsPC() )
			{
				pos = GetXCamMouseControl( data_lcn );
				model.angles = ( model.angles[0], AbsAngleClamp360( model.angles[1] - pos["yaw"] * RS_ROTATION_SPEED_MULTIPLIER ), model.angles[2] );
			}
		}
		WAIT_CLIENT_FRAME;
	}
}

///////////////////////////////////////////////////////////////////////////
// STATIC CHARACTER
///////////////////////////////////////////////////////////////////////////

function setup_static_character_customization_target( localClientNum )
{
	characterEnt = GetEnt( localClientNum, "character_customization_staging", "targetname" );
	level.extra_cam_hero_data[localClientNum] = setup_character_extracam_struct( "ui_cam_character_customization", "cam_menu_unfocus", HERO_CUSTOMIZE_IDLE_ANIM, false );
	level.extra_cam_lobby_client_hero_data[localClientNum] = setup_character_extracam_struct( "ui_cam_char_identity", "cam_bust", HERO_LOBBY_CLIENT_IDLE_ANIM, true );
	level.extra_cam_headshot_hero_data[localClientNum] = setup_character_extracam_struct( "ui_cam_char_identity", "cam_bust", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
	level.extra_cam_outfit_preview_data[localClientNum] = setup_character_extracam_struct( "ui_cam_char_identity", "cam_bust", HERO_CUSTOMIZE_IDLE_ANIM, false );
	
	if ( isdefined( characterEnt ) )
	{
		customization_data_struct = character_customization::create_character_data_struct( characterEnt, localClientNum, false );
		level thread update_character_extracam( localClientNum, customization_data_struct );
		
		return customization_data_struct;
	}
	
	return undefined;
}

function setup_character_extracam_struct( xcam, subXCam, model_animation, useLobbyPlayers )
{
	newStruct = SpawnStruct();
	newStruct.xcam = xcam;
	newStruct.subXCam = subXCam;
	newStruct.anim_name = model_animation;
	newStruct.useLobbyPlayers = useLobbyPlayers;
	return newStruct;
}

function wait_for_extracam_close( localClientNum, camera_ent, extraCamIndex )
{
	level waittill( "render_complete_" + localClientNum + "_" + extraCamIndex );
	multi_extracam::extracam_reset_index( localClientNum, extraCamIndex );
}

function setup_character_extracam_settings( localClientNum, data_struct, extracam_data_struct )
{
	assert( isdefined( extracam_data_struct.jobIndex ) );
	
	DEFAULT( level.camera_ents, [] );

	initializedExtracam = false;
	camera_ent = (isDefined(level.camera_ents[localClientNum]) ? level.camera_ents[localClientNum][extracam_data_struct.extraCamIndex] : undefined);
	if( !isdefined( camera_ent ) )
	{
		initializedExtracam = true;
		multi_extracam::extracam_init_index( localClientNum, "character_staging_extracam" + (extracam_data_struct.extraCamIndex+1), extracam_data_struct.extraCamIndex);
		camera_ent = level.camera_ents[localClientNum][extracam_data_struct.extraCamIndex];
	}

	assert( isdefined( camera_ent ) );
	
	camera_ent PlayExtraCamXCam( extracam_data_struct.xcam, 0, extracam_data_struct.subXCam );
	
	params = spawnstruct();
	params.anim_name = extracam_data_struct.anim_name;
	params.extracam_data = extracam_data_struct;
	params.isDefaultHero = extracam_data_struct.isDefaultHero;
	params.sessionMode = extracam_data_struct.sessionMode;
	params.hide_helmet = IS_TRUE( extracam_data_struct.hideHelmet );

	data_struct.alt_render_mode = false;
	
	loadEquippedCharacterOnModel( localClientNum, data_struct, extracam_data_struct.characterIndex, params );

	while( !is_character_streamed( data_struct ) )
	{
		WAIT_CLIENT_FRAME;
	}
	
	if ( IS_TRUE( extracam_data_struct.defaultImageRender ) )
	{
		wait 0.5;		// we can afford longer waits for the default images just make sure they look pretty
	}
	else
	{
		wait 0.1;	// wait for a bit to allow the models to get set up correctly and have the lighting update
	}

	setExtraCamRenderReady( extracam_data_struct.jobIndex );
	
	extracam_data_struct.jobIndex = undefined;
	
	if( initializedExtracam )
	{
		level thread wait_for_extracam_close( localClientNum, camera_ent, extracam_data_struct.extraCamIndex );
	}
}

function update_character_extracam( localClientNum, data_struct )
{
	level endon( "disconnect" );
	
	while ( true )
	{
		level waittill( "process_character_extracam" + localClientNum, extracam_data_struct );
		setup_character_extracam_settings( localClientNum, data_struct, extracam_data_struct );
	}
}

function process_character_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, characterIndex )
{
	level.extra_cam_hero_data[localClientNum].jobIndex = jobIndex;
	level.extra_cam_hero_data[localClientNum].extraCamIndex = extraCamIndex;
	level.extra_cam_hero_data[localClientNum].characterIndex = characterIndex;
	level.extra_cam_hero_data[localClientNum].sessionMode = sessionMode;
	
	level notify( "process_character_extracam" + localClientNum, level.extra_cam_hero_data[localClientNum] );
}

function process_lobby_client_character_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode )
{
	level.extra_cam_lobby_client_hero_data[localClientNum].jobIndex = jobIndex;
	level.extra_cam_lobby_client_hero_data[localClientNum].extraCamIndex = extraCamIndex;
	level.extra_cam_lobby_client_hero_data[localClientNum].characterIndex = GetEquippedCharacterIndexForLobbyClientHero( localClientNum, jobIndex );
	level.extra_cam_lobby_client_hero_data[localClientNum].sessionMode = sessionMode;
	
	level notify( "process_character_extracam" + localClientNum, level.extra_cam_lobby_client_hero_data[localClientNum] );
}

function process_current_hero_headshot_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, characterIndex, isDefaultHero )
{
	level.extra_cam_headshot_hero_data[localClientNum].jobIndex = jobIndex;
	level.extra_cam_headshot_hero_data[localClientNum].extraCamIndex = extraCamIndex;
	level.extra_cam_headshot_hero_data[localClientNum].characterIndex = characterIndex;
	level.extra_cam_headshot_hero_data[localClientNum].isDefaultHero = isDefaultHero;	
	level.extra_cam_headshot_hero_data[localClientNum].sessionMode = sessionMode;
	
	level notify( "process_character_extracam" + localClientNum, level.extra_cam_headshot_hero_data[localClientNum] );
}

function process_outfit_preview_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, outfitIndex )
{
	level.extra_cam_outfit_preview_data[localClientNum].jobIndex = jobIndex;
	level.extra_cam_outfit_preview_data[localClientNum].extraCamIndex = extraCamIndex;
	level.extra_cam_outfit_preview_data[localClientNum].characterIndex = outfitIndex;
	level.extra_cam_outfit_preview_data[localClientNum].sessionMode = sessionMode;
	
	level notify( "process_character_extracam" + localClientNum, level.extra_cam_outfit_preview_data[localClientNum] );
}

function process_character_body_item_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, characterIndex, itemIndex, defaultImageRender )
{
	extracam_data = undefined;
	if ( defaultImageRender )
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons_render", "loot_body", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
		extracam_data.useHeadIndex = GetFirstHeadOfGender( GetHeroGender( characterIndex, sessionMode ), sessionMode );
	}
	else
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons", "cam_body", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
	}
	extracam_data.jobIndex = jobIndex;
	extracam_data.extraCamIndex = extraCamIndex;
	extracam_data.sessionMode = sessionMode;
	extracam_data.characterIndex = characterIndex;
	extracam_data.useBodyIndex = itemIndex;
	extracam_data.defaultImageRender = defaultImageRender;
	
	level notify( "process_character_extracam" + localClientNum, extracam_data );
}

function process_character_helmet_item_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, characterIndex, itemIndex, defaultImageRender )
{
	extracam_data = undefined;
	if ( defaultImageRender )
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons_render", "loot_helmet", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
#if XFILE_VERSION >= 553
		extracam_data.useHeadIndex = GetFirstHeadOfGender( GetHeroGender( characterIndex, sessionMode ), sessionMode );
#endif // #if XFILE_VERSION >= 553
	}
	else
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons", "cam_helmet", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
	}
	extracam_data.jobIndex = jobIndex;
	extracam_data.extraCamIndex = extraCamIndex;
	extracam_data.sessionMode = sessionMode;
	extracam_data.characterIndex = characterIndex;
	extracam_data.useHelmetIndex = itemIndex;
	extracam_data.defaultImageRender = defaultImageRender;
	
	level notify( "process_character_extracam" + localClientNum, extracam_data );
}

function process_character_head_item_extracam_request( localClientNum, jobIndex, extraCamIndex, sessionMode, headIndex, defaultImageRender )
{
	extracam_data = undefined;
	if ( defaultImageRender )
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons_render", "cam_head", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
#if XFILE_VERSION >= 553
		extracam_data.characterIndex = GetFirstHeroOfGender( GetHeadGender( headIndex, sessionMode ), sessionMode );
#endif // #if XFILE_VERSION >= 553
	}
	else
	{
		extracam_data = setup_character_extracam_struct( "ui_cam_char_customization_icons", "cam_head", HERO_LOBBY_CLIENT_IDLE_ANIM, false );
	}
	extracam_data.jobIndex = jobIndex;
	extracam_data.extraCamIndex = extraCamIndex;
	extracam_data.sessionMode = sessionMode;
	extracam_data.useHeadIndex = headIndex;
	extracam_data.hideHelmet = true;
	extracam_data.defaultImageRender = defaultImageRender;
	
	level notify( "process_character_extracam" + localClientNum, extracam_data );
}
