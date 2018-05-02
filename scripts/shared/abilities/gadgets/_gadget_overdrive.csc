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

#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\lui_shared;

#insert scripts\shared\abilities\gadgets\_gadget_overdrive.gsh;

#define	MAX_FLASH_ALPHA 					GetDvarFloat("scr_overdrive_flash_alpha", 0.7)
#define	FLASH_FADE_IN_TIME 					GetDvarFloat("scr_overdrive_flash_fade_in_time", 0.075)
#define	FLASH_FADE_OUT_TIME 				GetDvarFloat("scr_overdrive_flash_fade_out_time", 0.45)
#define	OVERDRIVE_BOOST_FX_DURATION			GetDvarFloat("scr_overdrive_boost_fx_time", 0.75)
#define OVERDRIVE_BLUR_AMOUNT				GetDvarFloat( "scr_overdrive_amount", 0.15 )
#define OVERDRIVE_BLUR_INNER_RADIUS			GetDvarFloat( "scr_overdrive_inner_radius", 0.6 )
#define OVERDRIVE_BLUR_OUTER_RADIUS			GetDvarFloat( "scr_overdrive_outer_radius", 1 )
#define OVERDRIVE_BLUR_VELOCITY_SHOULDSCALE	GetDvarInt( "scr_overdrive_velShouldScale", 1 )
#define OVERDRIVE_BLUR_VELOCITY_SCALE		GetDvarInt( "scr_overdrive_velScale", 220 )

#define OVERDRIVE_SHOW_BOOST_SPEED_TOLERANCE	GetDvarInt( "scr_overdrive_boost_speed_tol", 280 )

	
#precache( "client_fx", "player/fx_plyr_ability_screen_blur_overdrive" );



REGISTER_SYSTEM( "gadget_overdrive", &__init__, undefined )

function __init__()
{
	callback::on_localclient_connect( &on_player_connect );
	callback::on_localplayer_spawned( &on_localplayer_spawned );
	callback::on_localclient_shutdown( &on_localplayer_shutdown );

	clientfield::register( "toplayer", "overdrive_state", VERSION_SHIP, 1, "int", &player_overdrive_handler, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT);
	
	visionset_mgr::register_visionset_info( OVERDRIVE_VISIONSET_ALIAS, VERSION_SHIP, OVERDRIVE_VISIONSET_STEPS, undefined, OVERDRIVE_VISIONSET );
}

function on_localplayer_shutdown(localClientNum)
{
	self overdrive_shutdown( localClientNum );
}


function on_localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	filter::init_filter_overdrive(self);
	filter::disable_filter_overdrive( self,FILTER_INDEX_OVERDRIVE );
	DisableSpeedBlur( localClientNum );
}

function on_player_connect( local_client_num )
{
	
}

function player_overdrive_handler(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( !self IsLocalPlayer() || IsSpectating( localClientNum, false ) || ( (isdefined(level.localPlayers[localClientNum])) && (self GetEntityNumber() != level.localPlayers[localClientNum] GetEntityNumber())) )
	{
		return;
	}
	
	if( (newVal != oldval) && newval ) 
	{
	   	EnableSpeedBlur( localClientNum, OVERDRIVE_BLUR_AMOUNT, OVERDRIVE_BLUR_INNER_RADIUS, OVERDRIVE_BLUR_OUTER_RADIUS, OVERDRIVE_BLUR_VELOCITY_SHOULDSCALE,OVERDRIVE_BLUR_VELOCITY_SCALE);
		filter::enable_filter_overdrive( self, FILTER_INDEX_OVERDRIVE );
		self UseAlternateAimParams();
		self thread activation_flash(localClientNum);
		self boost_fx_on_velocity(localClientNum);
	}
	else if ( (newVal != oldval) && !newval )
	{
		self overdrive_shutdown( localClientNum );
	}
}


// Flashes the screen white on activation.
function activation_flash(localClientNum)
{
	self notify("activation_flash");
	self endon("activation_flash");
	self endon("death");
	self endon("entityshutdown");
	self endon("stop_player_fx");
	self endon("disable_cybercom");
	           
	self.whiteFlashFade = 1;
	lui::screen_fade( FLASH_FADE_IN_TIME, MAX_FLASH_ALPHA, 0, "white" );
	wait FLASH_FADE_IN_TIME;
	lui::screen_fade( FLASH_FADE_OUT_TIME, 0, MAX_FLASH_ALPHA, "white" );
	self.whiteFlashFade = undefined;
}

// Turn on the "hyperdrive" boost effects on camera
function enable_boost_camera_fx(localClientNum)
{
	if (isDefined(self.firstperson_fx_overdrive))
	{
		StopFX(localClientNum, self.firstperson_fx_overdrive);
		self.firstperson_fx_overdrive = undefined;
   	}
	self.firstperson_fx_overdrive = PlayFXOnCamera( localClientNum, "player/fx_plyr_ability_screen_blur_overdrive", (0,0,0), (1,0,0), (0,0,1) );
	self thread watch_stop_player_fx( localClientNum,  self.firstperson_fx_overdrive );
}

function watch_stop_player_fx( localClientNum, fx )
{
	self notify("watch_stop_player_fx");
	self endon("watch_stop_player_fx");
	self endon("entityshutdown");
	
	self util::waittill_any( "stop_player_fx","death","disable_cybercom" );
	
	if ( IsDefined( fx ) )
	{
		StopFx( localClientNum, fx );	
		self.firstperson_fx_overdrive = undefined;  	   
	}
}

// Turn off the "hyperdrive" boost effects on camera
function stop_boost_camera_fx(localClientNum)
{
	self notify( "stop_player_fx" );
	
	if(IS_TRUE(self.whiteFlashFade))
	{
		lui::screen_fade( FLASH_FADE_OUT_TIME, 0, MAX_FLASH_ALPHA, "white" );
	}
}

// Stop FX when we die or hit a cybercom turnoff event.
function overdrive_boost_fx_interrupt_handler(localClientNum)
{
	self endon("overdrive_boost_fx_interrupt_handler");
	self endon("end_overdrive_boost_fx");
	self endon("entityshutdown");
	
	self util::waittill_any( "death", "disable_cybercom" );
	
	self overdrive_shutdown( localClientNum );
}

// Turns off all effects and ability buffs given by overdrive.
// self == player
function overdrive_shutdown( localClientNum )
{
	if (isdefined(localClientNum))
	{
		self stop_boost_camera_fx( localClientNum );
		self ClearAlternateAimParams();
		filter::disable_filter_overdrive( self,FILTER_INDEX_OVERDRIVE );
	   	DisableSpeedBlur( localClientNum );
	   	self notify( "end_overdrive_boost_fx");
	}
}

// Turn on boost FX (hyperdrive!) when we're moving forward fast enough.
// This effectively translates to sprinting forward with its current tuning.
function boost_fx_on_velocity(localClientNum)	//self == player
{
	self endon("disable_cybercom");
	self endon("death");
	self endon("end_overdrive_boost_fx");
	self endon("disconnect");
	
	// Ensure the boost plays for at least a short time on activation.
	self enable_boost_camera_fx(localClientNum);

	//Keep track of when we might need to turn force off the boost FX
	self thread overdrive_boost_fx_interrupt_handler(localclientnum);

	wait OVERDRIVE_BOOST_FX_DURATION;
	
	while (isDefined(self))
	{
		// Get forward direction and speed information.
		v_player_velocity = self GetVelocity();
		v_player_forward = Anglestoforward(self.angles);
		n_dot = VectorDot(VectorNormalize(v_player_velocity), v_player_forward);
		n_speed = Length(v_player_velocity);
	
		// If we're moving forward fast enough:
		if (n_speed >= OVERDRIVE_SHOW_BOOST_SPEED_TOLERANCE && n_dot > 0.8)
		{
			if (!isdefined(self.firstperson_fx_overdrive))
			{
				self enable_boost_camera_fx(localClientNum);
			}
		}
		else
		{
			if (isdefined(self.firstperson_fx_overdrive))
			{
				self stop_boost_camera_fx(localClientNum);
			}
		}
		WAIT_CLIENT_FRAME;
	}
}

