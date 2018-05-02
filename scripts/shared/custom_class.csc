
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\exploder_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;
#using scripts\shared\postfx_shared;

#using scripts\core\_multi_extracam;
#using scripts\codescripts\struct;

// ARCHETYPE SCRIPTS - by putting them here, any autoexec functions will execute automatically.
#using scripts\shared\ai\zombie;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\archetype_damage_effects;

#using scripts\shared\_character_customization;
#using scripts\shared\lui_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\statstable_shared.gsh;

#define PAINTSHOP_WEAPON_KICK_EXPLODER_NAME		"weapon_kick"
#define PAINTSHOP_LIGHT_EXPLODER_NAME			"lights_paintshop"
#define PAINTSHOP_LIGHT_ZOOM_EXPLODER_NAME		"lights_paintshop_zoom"
#define CAC_LOCKED_WEAPON						"mc/sonar_frontend_locked_gun"

#namespace customclass;

function localClientConnect(localClientNum)
{
	level thread custom_class_init( localClientNum );
}

function init()
{
	level.weapon_script_model = [];
	level.preload_weapon_model = [];
	level.last_weapon_name = [];
	level.current_weapon = [];
	level.attachment_names = [];
	level.attachment_indices = [];
	level.paintshopHiddenPosition = [];
	level.camo_index = [];
	level.reticle_index = [];
	level.show_player_tag = [];
	level.show_emblem = [];
	level.preload_weapon_complete = [];
	level.preload_weapon_complete = [];
	level.weapon_clientscript_cac_model = [];
	
	level.weaponNone = GetWeapon( "none" );
	level.weapon_position = struct::get("paintshop_weapon_position");
	duplicate_render::set_dr_filter_offscreen( "cac_locked_weapon", 10, "cac_locked_weapon", undefined, DR_TYPE_OFFSCREEN, CAC_LOCKED_WEAPON, DR_CULL_NEVER );
}

function custom_class_init( localClientNum )
{
	level.last_weapon_name[ localClientNum ] = "";
	level.current_weapon[ localClientNum ] = undefined;

	level thread custom_class_start_threads( localClientNum );
	level thread handle_cac_customization( localClientNum );
}

function custom_class_start_threads( localClientNum )
{
	level endon( "disconnect" );
	
	while( 1 )
	{
		level thread custom_class_update( localClientNum );
		level thread custom_class_attachment_select_focus( localClientNum );
		level thread custom_class_remove( localClientNum );
		level thread custom_class_closed( localClientNum );
		
		level util::waittill_any( "CustomClass_update" + localClientNum, "CustomClass_focus" + localClientNum, "CustomClass_remove" + localClientNum, "CustomClass_closed" + localClientNum);
	}
}

function handle_cac_customization( localClientNum )
{
	level endon( "disconnect" );

	self.lastXcam = [];
	self.lastSubxcam = [];
	self.lastNotetrack = [];

	while( 1 )
	{
		level thread handle_cac_customization_focus( localClientNum );
		level thread handle_cac_customization_weaponoption( localClientNum );
		level thread handle_cac_customization_attachmentvariant( localClientNum );
		level thread handle_cac_customization_closed( localClientNum );

		level waittill( "cam_customization_closed" + localClientNum);
	}
}

function custom_class_update( localClientNum )
{
	level endon( "disconnect" );
	level endon( "CustomClass_focus" + localClientNum );
	level endon( "CustomClass_remove"  + localClientNum);
	level endon( "CustomClass_closed"  + localClientNum);
	
	level waittill( "CustomClass_update" + localClientNum, param1, param2, param3, param4, param5, param6, param7 );

	base_weapon_slot = param1;
	weapon_full_name = param2;
	camera = param3; //"select01", "select02", or "select03"
	weapon_options_param = param4;
	acv_param = param5;
	is_item_unlocked = param6;
	is_item_tokenlocked = param7;
	DEFAULT( is_item_unlocked, true );
	DEFAULT( is_item_tokenlocked, false );

	if( IsDefined( weapon_full_name ) )
	{
		if( IsDefined( acv_param ) && acv_param != "none" )
		{
			set_attachment_cosmetic_variants( localClientNum, acv_param );
		}

		if( IsDefined( weapon_options_param ) && weapon_options_param != "none" )
		{
			set_weapon_options( localClientNum, weapon_options_param );
		}
		
		postfx::setFrontendStreamingOverlay( localClientNum, "cac", true );

		position = level.weapon_position;
			
		if( !IsDefined( level.weapon_script_model[ localClientNum ] ) )
		{
			level.weapon_script_model[ localClientNum ] = spawn_weapon_model( localClientNum, position.origin, position.angles );
			level.preload_weapon_model[ localClientNum ] = spawn_weapon_model( localClientNum, position.origin, position.angles );
			level.preload_weapon_model[ localClientNum ] Hide();
		}

		toggle_locked_weapon_shader( localClientNum, is_item_unlocked );
		toggle_tokenlocked_weapon_shader( localClientNum, is_item_unlocked && is_item_tokenlocked );
			
		update_weapon_script_model( localClientNum, weapon_full_name, undefined, is_item_unlocked, is_item_tokenlocked );
		
		level notify( "xcamMoved" );
		
		lerpDuration = get_lerp_duration( camera );
		setup_paintshop_bg( localClientNum, camera );
		level transition_camera_immediate( localClientNum, base_weapon_slot, "cam_cac_weapon", "cam_cac", lerpDuration, camera );
	}
	else if( IsDefined(param1) && param1 == "purchased" )
	{
		toggle_tokenlocked_weapon_shader( localClientNum, false );
	}
}

function toggle_locked_weapon_shader( localClientNum, is_item_unlocked = true )
{
	if( !IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		return;
	}

	if( is_item_unlocked != 1 )
	{
		EnableFrontendLockedWeaponOverlay( localClientNum, true );
	}
	else
	{
		EnableFrontendLockedWeaponOverlay( localClientNum, false );
	}
}

function toggle_tokenlocked_weapon_shader( localClientNum, is_item_tokenlocked = false )
{
	if( !IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		return;
	}

	if( is_item_tokenlocked )
	{
		EnableFrontendTokenLockedWeaponOverlay( localClientNum, true );
	}
	else
	{
		EnableFrontendTokenLockedWeaponOverlay( localClientNum, false );
	}
}

function is_optic( attachmentName )
{
	csv_filename = "gamedata/weapons/common/attachmentTable.csv";
	
	row = tableLookupRowNum( csv_filename, ATTACHMENT_TABLE_COL_NAME, attachmentName );
	
	if ( row > -1 )
	{
		group = tableLookupColumnForRow( csv_filename, row, ATTACHMENT_TABLE_COL_GROUP );
		return ( group == "optic" );
	}

	return false;
}

function custom_class_attachment_select_focus( localClientNum )
{
	level endon( "disconnect" );
	level endon( "CustomClass_update" + localClientNum );
	level endon( "CustomClass_remove" + localClientNum );
	level endon( "CustomClass_closed" + localClientNum );
	
	level waittill( "CustomClass_focus" + localClientNum, param1, param2, param3, param4, param5, param6 );
	level endon( "CustomClass_focus" + localClientNum );
	
	base_weapon_slot = param1;
	weapon_full_name = param2;
	attachment = param3;
	weapon_options_param = param4;
	acv_param = param5;
	doNotMoveCamera = param6;

	update_weapon_options = false;
	weaponAttachmentIntersection = get_attachments_intersection( level.last_weapon_name[ localClientNum ], weapon_full_name );
	
	if( IsDefined( acv_param ) && acv_param != "none" )
	{
		set_attachment_cosmetic_variants( localClientNum, acv_param );
	}
	
	initialdelay = .30;
	lerpDuration = 400;
	
	if( is_optic(attachment) )
	{
		initialdelay = 0;
		lerpDuration = 200;
	}

	preload_weapon_model( localClientNum, weaponAttachmentIntersection, update_weapon_options );
	wait_preload_weapon( localClientNum );
	
	update_weapon_script_model( localClientNum, weaponAttachmentIntersection, update_weapon_options );

	//update camera transitions
	if( weapon_full_name == weaponAttachmentIntersection )
	{
		weapon_full_name = undefined;
	}
	
	if ( IS_TRUE( doNotMoveCamera ) )
	{	
		if( IsDefined( weapon_full_name ) )
		{
			preload_weapon_model( localClientNum, weapon_full_name, false );
		
			wait initialDelay;
		
			wait_preload_weapon( localClientNum );
		
			update_weapon_script_model( localClientNum, weapon_full_name, false );
		}
	}
	else
	{
		level thread transition_camera( localClientNum, base_weapon_slot, "cam_cac_attachments", "cam_cac", initialDelay, lerpDuration, attachment, weapon_full_name );
	}
	
	if( IsDefined( weapon_options_param ) && weapon_options_param != "none" )
	{
		set_weapon_options( localClientNum, weapon_options_param );
	}
}

function custom_class_remove( localClientNum )
{
	level endon( "disconnect" );
	level endon( "CustomClass_update" + localClientNum );
	level endon( "CustomClass_focus" + localClientNum );
	level endon( "CustomClass_closed" + localClientNum );
	
	level waittill( "CustomClass_remove" + localClientNum, param1, param2, param3, param4, param5, param6 );
	
	postfx::setFrontendStreamingOverlay( localClientNum, "cac", false );
	EnableFrontendLockedWeaponOverlay( localClientNum, false );
	EnableFrontendTokenLockedWeaponOverlay( localClientNum, false );
	
	//creating a default position for the camera in case we land on a loadout slot that doesn't have a model (perks and wildcards)
	position = level.weapon_position;
	camera = "select01";
	xcamName = "ui_cam_cac_ar_standard";
	PlayMainCamXCam( localClientNum, xcamName, 0, "cam_cac", camera, position.origin, position.angles );
	setup_paintshop_bg( localClientNum, camera );
	
	if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		level.weapon_script_model[ localClientNum ] forcedelete();
	}
	level.last_weapon_name[ localClientNum ] = "";
}

function custom_class_closed( localClientNum )
{
	level endon( "disconnect" );
	level endon( "CustomClass_update" + localClientNum );
	level endon( "CustomClass_focus" + localClientNum );
	level endon( "CustomClass_remove" + localClientNum );
	
	level waittill( "CustomClass_closed" + localClientNum, param1, param2, param3, param4, param5, param6 );
	
	if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		level.weapon_script_model[ localClientNum ] forcedelete();
	}
		
	postfx::setFrontendStreamingOverlay( localClientNum, "cac", false );
	EnableFrontendLockedWeaponOverlay( localClientNum, false );
	EnableFrontendTokenLockedWeaponOverlay( localClientNum, false );
	
	level.last_weapon_name[ localClientNum ] = "";
}

function spawn_weapon_model( localClientNum, origin, angles )
{
	weapon_model = Spawn( localClientNum, origin, "script_model" );
	weapon_model SetHighDetail( true, true );
	
	if( IsDefined( angles ) )
	{
		weapon_model.angles = angles;
	}

	return weapon_model;
}

function set_attachment_cosmetic_variants( localClientNum, acv_param )
{
	acv_indexes = strtok( acv_param, "," );
	
	level.attachment_names[ localClientNum ] = [];
	level.attachment_indices[ localClientNum ] = [];

	for( i = 0; i + 1 < acv_indexes.size; i += 2 )
	{
		level.attachment_names[ localClientNum ][ level.attachment_names[ localClientNum ].size ] = acv_indexes[i];
		level.attachment_indices[ localClientNum ][ level.attachment_indices[ localClientNum ].size ] = int( acv_indexes[i+1] );
	}
}

function hide_paintshop_bg( localClientNum )
{
	paintshop_bg = GetEnt( localClientNum, "paintshop_black", "targetname" );
	if( IsDefined( paintshop_bg ) )
	{
		if( !IsDefined( level.paintshopHiddenPosition[ localClientNum ] ) )
		{
			level.paintshopHiddenPosition[ localClientNum ] = paintshop_bg.origin;
		}
		paintshop_bg hide();
		paintshop_bg moveto( level.paintshopHiddenPosition[ localClientNum ], 0.01 );
	}
}

function show_paintshop_bg( localClientNum )
{
	paintshop_bg = GetEnt( localClientNum, "paintshop_black", "targetname" );
	if( IsDefined( paintshop_bg ) )
	{
		paintshop_bg show();
		paintshop_bg moveto( level.paintshopHiddenPosition[ localClientNum ] + (0,0,227), 0.01 );
	}
}

function get_camo_index( localClientNum )
{
	if( !IsDefined( level.camo_index[ localClientNum ] ) )
	{
		level.camo_index[ localClientNum ] = 0;
	}

	return level.camo_index[ localClientNum ];
}

function get_reticle_index( localClientNum )
{
	if( !IsDefined( level.reticle_index[ localClientNum ] ) )
	{
		level.reticle_index[ localClientNum ] = 0;
	}

	return level.reticle_index[ localClientNum ];
}

function get_show_payer_tag( localClientNum )
{
	if( !IsDefined( level.show_player_tag[ localClientNum ] ) )
	{
		level.show_player_tag[ localClientNum ] = false;
	}

	return level.show_player_tag[ localClientNum ];
}

function get_show_emblem( localClientNum )
{
	if( !IsDefined( level.show_emblem[ localClientNum ] ) )
	{
		level.show_emblem[ localClientNum ] = false;
	}

	return level.show_emblem[ localClientNum ];
}

function get_show_paintshop( localClientNum )
{
	if( !IsDefined( level.show_paintshop[ localClientNum ] ) )
	{
		level.show_paintshop[ localClientNum ] = false;
	}

	return level.show_paintshop[ localClientNum ];
}

function set_weapon_options( localClientNum, weapon_options_param )
{
	weapon_options = strtok( weapon_options_param, "," );

	level.camo_index[ localClientNum ] = int( weapon_options[0] );
	level.show_player_tag[ localClientNum ] = false;
	level.show_emblem[ localClientNum ] = false;
	level.reticle_index[ localClientNum ] = int( weapon_options[1] );
	level.show_paintshop[ localClientNum ] = int( weapon_options[2] );
	
	if( IsDefined( weapon_options ) && IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		level.weapon_script_model[ localClientNum ] SetWeaponRenderOptions( get_camo_index( localClientNum ), get_reticle_index( localClientNum ), get_show_payer_tag( localClientNum ), get_show_emblem( localClientNum ), get_show_paintshop( localClientNum ) );
	}
}

function get_lerp_duration( camera )
{
	lerpDuration = 0;
	if( IsDefined( camera ) )
	{
		paintshopCameraCloseUp = ( camera == "left" || camera == "right" || camera == "top" || camera == "paintshop_preview_left" || camera == "paintshop_preview_right" || camera == "paintshop_preview_top");
		if( paintshopCameraCloseUp )
		{
			lerpDuration = 500;
		}
	}

	return lerpDuration;
}

function setup_paintshop_bg( localClientNum, camera )
{
	if( IsDefined( camera ) )
	{
		paintshopCameraCloseUp = ( camera == "left" || camera == "right" || camera == "top" || camera == "paintshop_preview_left" || camera == "paintshop_preview_right" || camera == "paintshop_preview_top" );
		PlayRadiantExploder( localClientNum, PAINTSHOP_WEAPON_KICK_EXPLODER_NAME );
		if( paintshopCameraCloseUp )
		{
			show_paintshop_bg( localCLientNum );
			KillRadiantExploder( localClientNum, PAINTSHOP_LIGHT_EXPLODER_NAME );
			KillRadiantExploder( localClientNum, PAINTSHOP_WEAPON_KICK_EXPLODER_NAME );
			PlayRadiantExploder( localClientNum, PAINTSHOP_LIGHT_ZOOM_EXPLODER_NAME );
		}
		else
		{
			hide_paintshop_bg( localClientNum );
			KillRadiantExploder( localClientNum, PAINTSHOP_LIGHT_ZOOM_EXPLODER_NAME );
			PlayRadiantExploder( localClientNum, PAINTSHOP_LIGHT_EXPLODER_NAME );
			PlayRadiantExploder( localClientNum, PAINTSHOP_WEAPON_KICK_EXPLODER_NAME );
		}
	}
}

function transition_camera_immediate( localClientNum, weaponType, camera, subxcam, lerpDuration, notetrack )
{
	xcam = GetWeaponXCam( level.current_weapon[ localClientNum ], camera );

	if( !IsDefined( xcam ) )
	{
		if( StrStartsWith( weaponType, "specialty" ) )
		{
			xcam = "ui_cam_cac_perk";
		}
		else if( StrStartsWith( weaponType, "bonuscard" ) )
		{
			xcam = "ui_cam_cac_wildcard";
		}
		else if( StrStartsWith( weaponType, "cybercore" ) || StrStartsWith( weaponType, "cybercom" ) )
		{
			xcam = "ui_cam_cac_perk";
		}
		else if ( StrStartsWith( weaponType, "bubblegum" ) )
		{
			xcam = "ui_cam_cac_bgb";
		}
		else
		{
			xcam = GetWeaponXCam( GetWeapon( "ar_standard" ), camera );
		}
	}
	
	self.lastXcam[weaponType] = xcam;
	self.lastSubxcam[weaponType] = subxcam;
	self.lastNotetrack[weaponType] = notetrack;

	position = level.weapon_position;
	model = level.weapon_script_model[ localClientNum ];

	PlayMainCamXCam( localClientNum, xcam, lerpDuration, subxcam, notetrack, position.origin, position.angles, model, position.origin, position.angles );
	if( notetrack == "top" || notetrack == "right" || notetrack == "left" )
	{
		SetAllowXCamRightStickRotation( localClientNum, false );
	}
}

function wait_preload_weapon( localClientNum )
{
	if( level.preload_weapon_complete[ localClientNum ] )
	{
		return;
	}

	level waittill( "preload_weapon_complete_" + localClientNum );
}

function preload_weapon_watcher( localClientNum )
{
	level endon( "preload_weapon_changing_" + localClientNum );
	level endon( "preload_weapon_complete_" + localClientNum );

	while( true )
	{
		if( level.preload_weapon_model[ localClientNum ] isStreamed() )
		{
			level.preload_weapon_complete[ localClientNum ] = true;
			level notify( "preload_weapon_complete_" + localClientNum );
			return;
		}

		wait 0.1;
	}
}

function preload_weapon_model( localClientNum, newWeaponString, should_update_weapon_options = true )
{
	level notify( "preload_weapon_changing_" + localClientNum );

	level.preload_weapon_complete[ localClientNum ]  = false;
	current_weapon = GetWeaponWithAttachments( newWeaponString );
	if ( current_weapon == level.weaponNone )
	{
		level.preload_weapon_complete[ localClientNum ] = true;
		level notify( "preload_weapon_complete_" + localClientNum );
		return;
	}
	
	if( isDefined(current_weapon.frontendmodel) )
	{
		level.preload_weapon_model[ localClientNum ] UseWeaponModel( current_weapon, current_weapon.frontendmodel );
	}
	else
	{
		level.preload_weapon_model[ localClientNum ] UseWeaponModel( current_weapon );
	}
	
	if( IsDefined( level.preload_weapon_model[ localClientNum ] ) )
	{
		if( IsDefined( level.attachment_names[ localClientNum ] ) && IsDefined( level.attachment_indices[ localClientNum ] ) )
		{
			for( i = 0; i < level.attachment_names[ localClientNum ].size; i++ )
			{
				level.preload_weapon_model[ localClientNum ] SetAttachmentCosmeticVariantIndex( newWeaponString, level.attachment_names[ localClientNum ][i], level.attachment_indices[ localClientNum ][i] );
			}
		}
		
		if( should_update_weapon_options )
		{
			level.preload_weapon_model[ localClientNum ] SetWeaponRenderOptions( get_camo_index( localClientNum ), get_reticle_index( localClientNum ), get_show_payer_tag( localClientNum ), get_show_emblem( localClientNum ), get_show_paintshop( localClientNum ) );
		}
	}

	level thread preload_weapon_watcher( localClientNum );
}


function update_weapon_script_model( localClientNum, newWeaponString, should_update_weapon_options = true, is_item_unlocked = true, is_item_tokenlocked = false )
{
	level.last_weapon_name[ localClientNum ] = newWeaponString;
	level.current_weapon[ localClientNum ] = GetWeaponWithAttachments( level.last_weapon_name[ localClientNum ] );
	if ( level.current_weapon[ localClientNum ] == level.weaponNone )
	{
		// for perks and wildcards
		level.weapon_script_model[ localClientNum ] delete();
		position = level.weapon_position;
		level.weapon_script_model[ localClientNum ] = spawn_weapon_model( localClientNum, position.origin, position.angles );
		toggle_locked_weapon_shader( localClientNum, is_item_unlocked );
		toggle_tokenlocked_weapon_shader( localClientNum, is_item_unlocked && is_item_tokenlocked );

		level.weapon_script_model[ localClientNum ] SetModel( level.last_weapon_name[ localClientNum ] );
		level.weapon_script_model[ localClientNum ] SetDedicatedShadow( true );

		return;
	}
	
	if( isDefined(level.current_weapon[ localClientNum ].frontendmodel) )
	{
		level.weapon_script_model[ localClientNum ] UseWeaponModel( level.current_weapon[ localClientNum ], level.current_weapon[ localClientNum ].frontendmodel );
	}
	else
	{
		level.weapon_script_model[ localClientNum ] UseWeaponModel( level.current_weapon[ localClientNum ] );
	}
	
	if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
	{
		if( IsDefined( level.attachment_names[ localClientNum ] ) && IsDefined( level.attachment_indices[ localClientNum ] ) )
		{
			for( i = 0; i < level.attachment_names[ localClientNum ].size; i++ )
			{
				level.weapon_script_model[ localClientNum ] SetAttachmentCosmeticVariantIndex( newWeaponString, level.attachment_names[ localClientNum ][i], level.attachment_indices[ localClientNum ][i] );
			}
		}
		
		if( should_update_weapon_options )
		{
			level.weapon_script_model[ localClientNum ] SetWeaponRenderOptions( get_camo_index( localClientNum ), get_reticle_index( localClientNum ), get_show_payer_tag( localClientNum ), get_show_emblem( localClientNum ), get_show_paintshop( localClientNum ) );
		}
	}
	
	level.weapon_script_model[ localClientNum ] SetDedicatedShadow( true );
}

function transition_camera( localClientNum, weaponType, camera, subxcam, initialDelay, lerpDuration, notetrack, newWeaponString, should_update_weapon_options = false )
{
	self endon( "entityshutdown" );
	self notify( "xcamMoved" );
	self endon( "xcamMoved" );
	level endon( "cam_customization_closed" );

	if( IsDefined( newWeaponString ) )
	{
		preload_weapon_model( localClientNum, newWeaponString, should_update_weapon_options );
	}

	wait initialDelay;

	transition_camera_immediate( localClientNum, weaponType, camera, subxcam, lerpDuration, notetrack );

	if( IsDefined( newWeaponString ) )
	{
		wait lerpDuration / 1000;

		wait_preload_weapon( localClientNum );

		update_weapon_script_model( localClientNum, newWeaponString, should_update_weapon_options );
	}
}

function get_attachments_intersection( oldWeapon, newWeapon )
{
	if( !isDefined(oldWeapon) )
	{
		return newWeapon;
	}

	oldWeaponParams = strtok(oldWeapon, "+");
	newWeaponParams = strtok(newWeapon, "+");
	
	if( oldWeaponParams[0] != newWeaponParams[0] )
	{
		return newWeapon;
	}
	
	newWeaponString = newWeaponParams[0];
	
	for ( i = 1; i < newWeaponParams.size; i++ )
	{
		if( isinarray( oldWeaponParams, newWeaponParams[i] ) )
		{
			newWeaponString += "+" + newWeaponParams[i];
		}
	}
	
	return newWeaponString;
}

function handle_cac_customization_focus( localClientNum )
{
	level endon( "disconnect" );
	level endon( "cam_customization_closed" + localClientNum );

	while( true )
	{
		level waittill( "cam_customization_focus" + localClientNum, param1, param2 );

		base_weapon_slot = param1;
		notetrack = param2;
		if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
		{
			should_update_weapon_options = true;
			level thread customclass::transition_camera( localClientNum, base_weapon_slot, "cam_cac_weapon", "cam_cac", .30, 400, notetrack, level.last_weapon_name[ localClientNum ], should_update_weapon_options );
		}
	}
}

function handle_cac_customization_weaponoption( localClientNum )
{
	level endon("disconnect");
	level endon( "cam_customization_closed" + localClientNum );
	
	while( true )
	{
		level waittill( "cam_customization_wo" + localClientNum, weapon_option, weapon_option_new_index, is_item_locked );
	
		if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
		{
			if( IS_TRUE( is_item_locked ) )
			{
				weapon_option_new_index = 0;
			}

			switch( weapon_option )
			{
				case "camo":
					level.camo_index[ localClientNum ] = int( weapon_option_new_index );
					break;
				case "reticle":
					level.reticle_index[ localClientNum ] = int( weapon_option_new_index );
					break;
				case "paintjob":
					level.show_paintshop[ localClientNum ] = int( weapon_option_new_index );
					break;
				default:
					break;
			}

			level.weapon_script_model[ localClientNum ] SetWeaponRenderOptions( customclass::get_camo_index( localClientNum ), customclass::get_reticle_index( localClientNum ), customclass::get_show_payer_tag( localClientNum ), customclass::get_show_emblem( localClientNum ), customclass::get_show_paintshop( localClientNum ) );
		}
	}
}

function handle_cac_customization_attachmentvariant( localClientNum )
{
	level endon( "disconnect" );
	level endon( "cam_customization_closed" + localClientNum );
	
	while( true )
	{
		level waittill( "cam_customization_acv" + localClientNum, weapon_attachment_name, acv_index );
	
		for ( i = 0; i < level.attachment_names[ localClientNum ].size; i++ )
		{
			if( level.attachment_names[ localClientNum ][i] == weapon_attachment_name )
			{
				level.attachment_indices[ localClientNum ][i] = int( acv_index );
				break;
			}
		}

		if( IsDefined( level.weapon_script_model[ localClientNum ] ) )
		{
			level.weapon_script_model[ localClientNum ] SetAttachmentCosmeticVariantIndex( level.last_weapon_name[ localClientNum ], weapon_attachment_name, int( acv_index ) );
		}
	}
}

function handle_cac_customization_closed( localClientNum )
{
	level endon("disconnect");
	
	level waittill( "cam_customization_closed" + localClientNum, param1, param2, param3, param4 );

	if( IsDefined( level.weapon_clientscript_cac_model[ localClientNum ] ) && IsDefined( level.weapon_clientscript_cac_model[ localClientNum ][ level.loadout_slot_name ] ) )
	{
		level.weapon_clientscript_cac_model[ localClientNum ][ level.loadout_slot_name ] SetWeaponRenderOptions( customclass::get_camo_index( localClientNum ), customclass::get_reticle_index( localClientNum ), customclass::get_show_payer_tag( localClientNum ), customclass::get_show_emblem( localClientNum ), customclass::get_show_paintshop( localClientNum ) );
		for( i = 0; i < level.attachment_names[ localClientNum ].size; i++ )
		{
			level.weapon_clientscript_cac_model[ localClientNum ][ level.loadout_slot_name ] SetAttachmentCosmeticVariantIndex( level.last_weapon_name[ localClientNum ], level.attachment_names[ localClientNum ][i], level.attachment_indices[ localClientNum ][i] );
		}
	}
}
