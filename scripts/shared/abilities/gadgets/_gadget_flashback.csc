#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_flashback.gsh;

REGISTER_SYSTEM( "gadget_flashback", &__init__, undefined )

#define FLASHBACK_TRAIL_FX							"player/fx_plyr_flashback_trail"
#define FLASHBACK_DISAPPEAR_FX						"player/fx_plyr_flashback_demat"
#define FLASHBACK_MATERIAL_GHOST					"mc/mtl_glitch" 
#define FLASHBACK_SHADER_X_UNUSED					1	
#define FLASHBACK_SHADER_Y_HDR_BRIGHTNESS			1	
#define FLASHBACK_SHADER_Z_TINT_INDEX				0	
#define FLASHBACK_SHADER_CONST						"scriptVector3"
	
#define FLASHBACK_REAPPEAR_TAGFX					"gadget_flashback_3p_off"
	
#define FLASHBACK_DISAPPEAR_SOUND_1P				"mpl_flashback_disappear_plr"
#define FLASHBACK_DISAPPEAR_SOUND_3P				"mpl_flashback_disappear_npc"
#define FLASHBACK_REAPPEAR_SOUND_1P					"mpl_flashback_reappear_plr"
#define FLASHBACK_REAPPEAR_SOUND_3P					"mpl_flashback_reappear_npc"
	

#precache( "client_fx", FLASHBACK_TRAIL_FX );
#precache( "client_tagfxset", FLASHBACK_REAPPEAR_TAGFX );
	
function __init__()
{
	clientfield::register( "scriptmover", "flashback_trail_fx", VERSION_SHIP, 1, "int", &set_flashback_trail_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "playercorpse", "flashback_clone", VERSION_SHIP, 1, "int", &clone_flashback_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", "flashback_activated" , VERSION_SHIP, 1, "int", &flashback_activated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	visionset_mgr::register_overlay_info_style_postfx_bundle( "flashback_warp", VERSION_SHIP, 1, "pstfx_flashback_warp", FLASHBACK_WARP_LENGTH );
	duplicate_render::set_dr_filter_framebuffer( "flashback", 90, "flashback_on", "", DR_TYPE_FRAMEBUFFER, FLASHBACK_MATERIAL_GHOST, DR_CULL_ALWAYS );
}

function flashback_activated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self notify ( "player_flashback" );
	player = GetLocalPlayer( localclientnum );
	isFirstPerson = !IsThirdPerson( localclientnum ) && ( player == self );
	if( newVal )
	{
		if( isFirstPerson )
		{
			self PlaySound( localclientnum, FLASHBACK_REAPPEAR_SOUND_1P );
		}
		else
		{
			self endon( "entityshutdown" );
			self util::waittill_dobj( localClientNum ); 
			   
			self PlaySound( localclientnum, FLASHBACK_REAPPEAR_SOUND_3P );
			PlayTagFXSet( localClientNum, FLASHBACK_REAPPEAR_TAGFX, self );
		}
	}
}

function set_flashback_trail_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = GetLocalPlayer( localclientnum );
	isFirstPerson = !IsThirdPerson( localclientnum ) && isDefined( self.owner ) && isDefined( player ) && ( self.owner == player );
	if( newVal )
	{
		if( isFirstPerson )
		{
			player PlaySound( localclientnum, FLASHBACK_DISAPPEAR_SOUND_1P );
		}
		else
		{
			self endon( "entityshutdown" );
			self util::waittill_dobj( localClientNum ); 

			self PlaySound( localclientnum, FLASHBACK_DISAPPEAR_SOUND_3P );
			PlayFxOnTag( localclientnum, FLASHBACK_DISAPPEAR_FX, self, "tag_origin" );
			PlayFxOnTag( localclientnum, FLASHBACK_TRAIL_FX, self, "tag_origin" );
		}
	}
}

function clone_flashback_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	if ( newVal )
	{
		self clone_flashback_changed_event( localClientNum, newVal);
	}
}

function clone_fade( localClientNum )
{
	self endon ( "entityshutdown" );
	
	startTime = GetServerTime( localClientnum );
	while( true )
	{
		currentTime = GetServerTime( localClientnum );
		elapsedTime = currentTime - startTime;
		elapsedtime = float( elapsedtime / 1000 );
		if( elapsedTime < FLASHBACK_CLONE_DURATION  )
		{
			amount = 1.0 - elapsedTime / FLASHBACK_CLONE_DURATION;
			self MapShaderConstant( localClientNum, 0, FLASHBACK_SHADER_CONST, FLASHBACK_SHADER_X_UNUSED, FLASHBACK_SHADER_Y_HDR_BRIGHTNESS, FLASHBACK_SHADER_Z_TINT_INDEX, amount	 ); 
		}
		else
		{
			self MapShaderConstant( localClientNum, 0, FLASHBACK_SHADER_CONST, FLASHBACK_SHADER_X_UNUSED, FLASHBACK_SHADER_Y_HDR_BRIGHTNESS, FLASHBACK_SHADER_Z_TINT_INDEX, 0 ); 
			break;
		}
		
		WAIT_CLIENT_FRAME;
	}
}

function clone_flashback_changed_event( localClientNum, armorStatusNew )
{
	if ( armorStatusNew )
	{
		self duplicate_render::set_dr_flag( "flashback_on", true );
		self duplicate_render::update_dr_filters(localClientNum);
		self clone_fade( localClientNum );
	}
}

