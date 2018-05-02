#using scripts\shared\system_shared;
#using scripts\codescripts\struct;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_playerhealth.gsh;

#namespace zm_playerhealth;

REGISTER_SYSTEM( "zm_playerhealth", &__init__, undefined )
	
function __init__()
{
	visionset_mgr::register_overlay_info_style_speed_blur( ZM_HEALTH_BLUR_SCREEN_EFFECT_NAME, 
	                                                      VERSION_SHIP, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_LERP_COUNT, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_BLUR_AMOUNT, 
	                                                      ZM_HEALTH_BLUROVERLAY_INNER_RADIUS, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_OUTER_RADIUS, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_SHOULD_VELOCITY_SCALE, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_SHOULD_VELOCITY_SCALE, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_TIME_FADE_IN, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_TIME_FADE_OUT, 
	                                                      ZM_HEALTH_BLUR_OVERLAY_SHOULD_OFFSET );
}