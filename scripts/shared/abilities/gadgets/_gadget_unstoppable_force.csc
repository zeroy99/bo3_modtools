#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\lui_shared;

#using scripts\shared\system_shared;

#define	MAX_FLASH_ALPHA 					GetDvarFloat("scr_unstoppableforce_flash_alpha", 0.6)
#define	FLASH_FADE_IN_TIME 					GetDvarFloat("scr_unstoppableforce_flash_fade_in_time", 0.075)
#define	FLASH_FADE_OUT_TIME 				GetDvarFloat("scr_unstoppableforce_flash_fade_out_time", 0.9)
#define UNSTOPPABLEFORCE_BLUR_AMOUNT				GetDvarFloat( "scr_unstoppableforce_amount", 0.15 )
#define UNSTOPPABLEFORCE_BLUR_INNER_RADIUS			GetDvarFloat( "scr_unstoppableforce_inner_radius", 0.6 )
#define UNSTOPPABLEFORCE_BLUR_OUTER_RADIUS			GetDvarFloat( "scr_unstoppableforce_outer_radius", 1 )
#define UNSTOPPABLEFORCE_BLUR_VELOCITY_SHOULDSCALE	GetDvarInt( "scr_unstoppableforce_velShouldScale", 1 )
#define UNSTOPPABLEFORCE_BLUR_VELOCITY_SCALE		GetDvarInt( "scr_unstoppableforce_velScale", 220 )

#define UNSTOPPABLEFORCE_SHOW_BOOST_SPEED_TOLERANCE	GetDvarInt( "scr_unstoppableforce_boost_speed_tol", 320 )
	
#define UNSTOPPABLEFORCE_ACTIVATION_DELAY	GetDvarFloat( "scr_unstoppableforce_activation_delay", 0.35 )
	
#precache( "client_fx", "player/fx_plyr_ability_screen_blur_overdrive" );

REGISTER_SYSTEM( "gadget_unstoppable_force", &__init__, undefined )

function __init__()
{
	callback::on_localclient_shutdown( &on_localplayer_shutdown );
	
	clientfield::register( "toplayer", "unstoppableforce_state", VERSION_SHIP, 1, "int", &player_unstoppableforce_handler, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT);
}

function on_localplayer_shutdown(localClientNum)
{
	stop_boost_camera_fx( localClientNum );
}


function player_unstoppableforce_handler(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( !self IsLocalPlayer() || IsSpectating( localClientNum, false ) || ( (isdefined(level.localPlayers[localClientNum])) && (self GetEntityNumber() != level.localPlayers[localClientNum] GetEntityNumber())) )
	{
		return;
	}
	
	if( (newVal != oldval) && newVal)
	{
		EnableSpeedBlur( localClientNum, UNSTOPPABLEFORCE_BLUR_AMOUNT, UNSTOPPABLEFORCE_BLUR_INNER_RADIUS, UNSTOPPABLEFORCE_BLUR_OUTER_RADIUS, UNSTOPPABLEFORCE_BLUR_VELOCITY_SHOULDSCALE,UNSTOPPABLEFORCE_BLUR_VELOCITY_SCALE);
		self thread activation_flash(localClientNum);
		self boost_fx_on_velocity(localClientNum);
	}
	else if ( (newVal != oldval) && !newval )
	{
		self stop_boost_camera_fx(localClientNum);
	   	DisableSpeedBlur( localClientNum );
	   	
	   	// Notify child threads to end.
	   	self notify( "end_unstoppableforce_boost_fx");
	}
}


// Flashes the screen white on activation.
function activation_flash(localClientNum)
{
	self util::waittill_any_timeout(UNSTOPPABLEFORCE_ACTIVATION_DELAY, "unstoppableforce_arm_cross_end");

	lui::screen_fade( FLASH_FADE_IN_TIME, MAX_FLASH_ALPHA, 0, "white" );
	wait FLASH_FADE_IN_TIME;
	lui::screen_fade( FLASH_FADE_OUT_TIME, 0, MAX_FLASH_ALPHA, "white" );
}

// Turn on the "hyperdrive" boost effects on camera
function enable_boost_camera_fx(localClientNum)
{
	self.firstperson_fx_unstoppableforce = PlayFXOnCamera( localClientNum, "player/fx_plyr_ability_screen_blur_overdrive", (0,0,0), (1,0,0), (0,0,1) );
}

// Turn off the "hyperdrive" boost effects on camera
function stop_boost_camera_fx(localClientNum)
{
	if (isdefined(self.firstperson_fx_unstoppableforce))
	{
		StopFX(localClientNum, self.firstperson_fx_unstoppableforce);
		self.firstperson_fx_unstoppableforce = undefined;
	}
}

// Stop FX when we die or hit a cybercom turnoff event.
function boost_fx_interrupt_handler(localClientNum)
{
	self endon("end_unstoppableforce_boost_fx");
	
	self util::waittill_any("disable_cybercom", "death");
	stop_boost_camera_fx( localClientNum );
	
	self notify( "end_unstoppableforce_boost_fx");
}

// Turn on boost FX (hyperdrive!) when we're moving forward fast enough.
// This effectively translates to sprinting forward with its current tuning.
function boost_fx_on_velocity(localClientNum)	//self == player
{
	self endon("disable_cybercom");
	self endon("death");
	self endon("end_unstoppableforce_boost_fx");
	self endon("disconnect");
	
	//Keep track of when we might need to turn force off the boost FX
	self thread boost_fx_interrupt_handler(localclientnum);
	
	while (isDefined(self))
	{
		// Get forward direction and speed information.
		v_player_velocity = self GetVelocity();
		v_player_forward = Anglestoforward(self.angles);
		n_dot = VectorDot(VectorNormalize(v_player_velocity), v_player_forward);
		n_speed = Length(v_player_velocity);
	
		// If we're moving forward fast enough:
		if (n_speed >= UNSTOPPABLEFORCE_SHOW_BOOST_SPEED_TOLERANCE && n_dot > 0.8)
		{
			if (!isdefined(self.firstperson_fx_unstoppableforce))
			{
				self enable_boost_camera_fx(localClientNum);
			}
		}
		else
		{
			if (isdefined(self.firstperson_fx_unstoppableforce))
			{
				self stop_boost_camera_fx(localClientNum);
			}
		}
		WAIT_CLIENT_FRAME;
	}
}
