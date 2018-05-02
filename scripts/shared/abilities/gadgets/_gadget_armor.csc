#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#define ARMOR_MATERIAL "mc/mtl_power_armor"
#define ARMOR_COLOR_R 							.3
#define ARMOR_COLOR_G 							.3
#define ARMOR_COLOR_B 							.2
#define ARMOR_EXPANSION							.3
	
REGISTER_SYSTEM( "gadget_armor", &__init__, undefined )

function __init__()
{
	callback::on_localplayer_spawned( &on_local_player_spawned );
	clientfield::register( "allplayers", "armor_status", VERSION_SHIP, 5, "int", &player_armor_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "player_damage_type", VERSION_SHIP, 1, "int", &player_damage_type_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	duplicate_render::set_dr_filter_framebuffer_duplicate( "armor_pl", 40, "armor_on", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, ARMOR_MATERIAL, DR_CULL_ALWAYS );
}

function on_local_player_spawned( localClientNum )
{	
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	newVal = self clientfield::get( "armor_status" );
	
	self player_armor_changed_event( localClientNum, newVal );
}

function player_damage_type_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	self armor_update_fx_event( localClientNum, newVal);
}

function player_armor_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	self player_armor_changed_event( localClientNum, newVal);
}

function player_armor_changed_event( localClientNum, newVal )
{		
	self armor_update_fx_event( localClientNum, newVal);
	
	self armor_update_shader_event( localClientNum, newVal );	
}

function armor_update_shader_event( localClientNum, armorStatusNew )
{
	if ( armorStatusNew )
	{
		self duplicate_render::update_dr_flag( localClientNum, "armor_on", true );
		
		shieldExpansionNcolor = "scriptVector3";
		shieldExpansionValueX = ARMOR_EXPANSION;
		
		colorVector = armor_get_shader_color( armorStatusNew ); //( 0.2, 0.8, 1 );
			
		if ( GetDvarInt( "scr_armor_dev" ) )
		{
			shieldExpansionValueX = GetDvarFloat( "scr_armor_expand", shieldExpansionValueX );
			colorVector = ( GetDvarFloat( "scr_armor_colorR", colorVector[0] ), GetDvarFloat( "scr_armor_colorG", colorVector[1] ), GetDvarFloat( "scr_armor_colorB", colorVector[2] ) );
		}		
		
		colorTintValueY = colorVector[0];
		colorTintValueZ = colorVector[1];
		colorTintValueW = colorVector[2];
		
		damageState = "scriptVector4";
		damageStateValue = armorStatusNew / ARMOR_STATUS_FULL;
		
		self MapShaderConstant( localClientNum, 0, shieldExpansionNcolor, shieldExpansionValueX, colorTintValueY, colorTintValueZ, colorTintValueW );
		self MapShaderConstant( localClientNum, 0, damageState, damageStateValue );
	}
	else
	{
		self duplicate_render::update_dr_flag( localClientNum, "armor_on", false );
	}
}

function armor_get_shader_color( armorStatusNew )
{
//	if ( armorStatusNew == ARMOR_STATUS_FULL )
//	{
//		color = ( 0.03, 0.11, 0.97 );
//	}
//	else if ( armorStatusNew == ARMOR_STATUS_GOOD )
//	{
//		color = ( 0.02, 0.65, 0.98 );
//	}
//	else if ( armorStatusNew == ARMOR_STATUS_OK )
//	{
//		color = ( 0.03, 0.82, 0.97 );
//	}
//	else if ( armorStatusNew == ARMOR_STATUS_DANGER )
//	{
//		color = ( 0.47, 0.97, 0.96 );
//	}
//	else if ( armorStatusNew == ARMOR_STATUS_CRITICAL )
//	{
//		color = ( 0.97, 0.04, 0.10 );
//	}
//	else
//	{
//		color = (0.03, 0.11, 0.97 );
//	}
	
	color = ( ARMOR_COLOR_R, ARMOR_COLOR_G, ARMOR_COLOR_B );
	
	return color;
}

function armor_update_fx_event( localClientNum, doArmorFx )
{	
	if ( !self armor_is_local_player( localClientNum ) )
	{
		return;
	}

	if ( doArmorFx )
	{
		self SetDamageDirectionIndicator(1);
		setsoundcontext( "plr_impact", "pwr_armor" );
	}
	else
	{
		self SetDamageDirectionIndicator(0);
		setsoundcontext( "plr_impact", "" );
	}		
}

function armor_overlay_transition_fx( localClientNum, armorStatusNew )
{
	self endon( "disconnect" );
	
	if ( !isdefined( self._gadget_armor_state ) )
	{
		self._gadget_armor_state = ARMOR_STATUS_OFF;
	}
	
	if ( armorStatusNew == self._gadget_armor_state )
	{
		return;
	}
	
	self._gadget_armor_state = armorStatusNew;
	
	if ( armorStatusNew == ARMOR_STATUS_FULL )
	{
		return;
	}	
	
	if ( IS_TRUE( self._armor_doing_transition ) )
	{
		return;
	}
	
	self._armor_doing_transition = true;
	
	transition = 0;
	flicker_start_time = GetRealTime();
	saved_vision = GetVisionSetNaked( localClientNum );

	visionsetnaked( localClientNum, "taser_mine_shock", transition );
	
	self playsound (0, "wpn_taser_mine_tacmask");

	wait( 0.3 );

	visionSetNaked( localClientNum, saved_vision, transition );
	
	self._armor_doing_transition = false;
}

function armor_is_local_player( localClientNum )
{	
	player_view = getlocalplayer( localClientNum );	

	sameEntity = ( self == player_view );

	return sameEntity;
}

	
