#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#using scripts\shared\_burnplayer;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_heat_wave.gsh;

#define VICTIM_FX_PUMP_DURATION 1
#define HEATWAVE_EXPLOSION_FX								"player/fx_plyr_heat_wave"
#define HEATWAVE_EXPLOSION_1P_FX							"player/fx_plyr_heat_wave_1p"
#define HEATWAVE_EXPLOSION_DISTORTION_VOLUME_FX				"player/fx_plyr_heat_wave_distortion_volume"
#define HEATWAVE_EXPLOSION_DISTORTION_VOLUME_AIR_FX			"player/fx_plyr_heat_wave_distortion_volume_air"
#define HEATWAVE_VICTIM_TAGFXSET							"ability_hero_heat_wave_player_impact"

#define HEATWAVE_ACTIVATE_POSTFX							"pstfx_heat_pulse"
	
#define EXPLOSION_RADIUS 									400
#define CENTER_OFFSET_Z 									30
#define FX_PER_FRAME										2	// This does more traces accordingly.

#precache( "client_fx", HEATWAVE_EXPLOSION_FX );
#precache( "client_fx", HEATWAVE_EXPLOSION_1P_FX );
#precache( "client_fx", HEATWAVE_EXPLOSION_DISTORTION_VOLUME_FX );
#precache( "client_fx", HEATWAVE_EXPLOSION_DISTORTION_VOLUME_AIR_FX );
#precache( "client_tagfxset", HEATWAVE_VICTIM_TAGFXSET );

REGISTER_SYSTEM( "gadget_heat_wave", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "heatwave_fx", VERSION_SHIP, 1, "int", &set_heatwave_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", "heatwave_victim", VERSION_SHIP, 1, "int", &update_victim, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "heatwave_activate", VERSION_SHIP, 1, "int", &update_activate, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level.debug_heat_wave_traces = GetDvarInt( "scr_debug_heat_wave_traces", 0 );
	
	visionset_mgr::register_visionset_info( HEATWAVE_ACTIVATE_VISIONSET_ALIAS, VERSION_SHIP, HEATWAVE_ACTIVATE_VISIONSET_STEPS, undefined, HEATWAVE_ACTIVATE_VISIONSET );
	visionset_mgr::register_visionset_info( HEATWAVE_CHARRED_VISIONSET_ALIAS, VERSION_SHIP, HEATWAVE_CHARRED_VISIONSET_STEPS, undefined, HEATWAVE_CHARRED_VISIONSET );
	
}


function update_activate( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self thread postfx::PlayPostfxBundle( HEATWAVE_ACTIVATE_POSTFX );
	}
}
	
function update_victim( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self endon( "entityshutdown" );
		self util::waittill_dobj( localClientNum );    
		
		self PlayRumbleOnEntity( localClientNum, "heat_wave_damage" );
		PlayTagFXSet( localClientNum, HEATWAVE_VICTIM_TAGFXSET, self );
	}
}

function set_heatwave_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self clear_heat_wave_fx( localClientNum );
	if( newVal )
	{
		self.heatWaveFx = [];
		self thread aoe_fx( localClientNum );
	}
}

function clear_heat_wave_fx( localClientNum )
{
	if( !isDefined( self.heatWaveFx ) )
	{
		return;
	}
	
	foreach( fx in self.heatWaveFx )
	{
		StopFx( localClientNum, fx );
	}
}

function aoe_fx( localClientNum )
{
	self endon ( "entityshutdown" );
	
	center = self.origin + ( 0, 0, CENTER_OFFSET_Z );
	
	startPitch = -90;
	yaw_count = [];
	yaw_count[ 0 ] = 1;
	yaw_count[ 1 ] = 4;
	yaw_count[ 2 ] = 6;
	yaw_count[ 3 ] = 8;
	yaw_count[ 4 ] = 6;
	yaw_count[ 5 ] = 4;
	yaw_count[ 6 ] = 1;
	
	pitch_vals = [];
	pitch_vals[0] = 90;
	pitch_vals[3] = 0;
	pitch_vals[6] = -90;
	
	trace = bullettrace( center, center + ( 0, 0, -1 ) * EXPLOSION_RADIUS, false, self );
	if ( trace["fraction"] < 1.0 )
	{
		pitch_vals[1] = 90 - atan( 150 / ( trace["fraction"] * EXPLOSION_RADIUS ) );	// evenly spaced 200 units away
		pitch_vals[2] = 90 - atan( 300 / ( trace["fraction"] * EXPLOSION_RADIUS ) );
	}
	else
	{
		pitch_vals[1] = 60;
		pitch_vals[2] = 30;
	}
	
	trace = bullettrace( center, center + ( 0, 0, 1 ) * EXPLOSION_RADIUS, false, self );
	if ( trace["fraction"] < 1.0 )
	{
		pitch_vals[5] = -90 + atan( 150 / ( trace["fraction"] * EXPLOSION_RADIUS ) );	// evenly spaced 200 units away
		pitch_vals[4] = -90 + atan( 300 / ( trace["fraction"] * EXPLOSION_RADIUS ) );
	}
	else
	{
		pitch_vals[5] = -60;
		pitch_vals[4] = -30;
	}
	
	currentPitch = startPitch;
	for ( yaw_level = 0; yaw_level < yaw_count.size; yaw_level++ )
	{
		currentPitch = pitch_vals[yaw_level];
		do_fx( localClientNum, center, yaw_count[yaw_level], currentPitch );
	}
}

function do_fx( localClientNum, center, yaw_count, pitch )
{
	currentYaw = RandomInt( 360 );
	for( fxCount = 0; fxCount < yaw_count; fxCount++ )
	{
		randomOffsetPitch = RandomInt( 5 ) - 2.5;
		randomOffsetYaw = RandomInt( 30 ) - 15;
		angles = ( pitch + randomOffsetPitch, currentYaw + randomOffsetYaw, 0 );
		traceDir = AnglesToForward( angles );
		currentYaw += 360 / yaw_count;
		fx_position = center + traceDir * EXPLOSION_RADIUS;
		trace = bullettrace( center, fx_position, false, self ); 
		sphere_size = 5;
		angles = ( 0, RandomInt( 360 ), 0 );
		forward = AnglesToForward( angles );
		
		if ( trace["fraction"] < 1.0 )
		{
			fx_position = center + traceDir * EXPLOSION_RADIUS * trace["fraction"];
			
			normal = trace["normal"];
			if ( LengthSquared( normal ) == 0 )
			{
				normal = -1 * traceDir;
			}
			right = ( normal[2] * -1, normal[1] * -1, normal[0] );
			if( LengthSquared( VectorCross( forward, normal ) ) == 0 )
			{
				forward = VectorCross( right, forward );
			}
			self.heatWaveFx[self.heatWaveFx.size] = PlayFx( localClientNum, HEATWAVE_EXPLOSION_DISTORTION_VOLUME_FX, trace["position"], normal, forward  );
		}
		else
		{
			if( LengthSquared( VectorCross( forward, traceDir * -1 ) ) == 0 )
			{
				forward = VectorCross( right, forward );
			}
			self.heatWaveFx[self.heatWaveFx.size] = PlayFx( localClientNum, HEATWAVE_EXPLOSION_DISTORTION_VOLUME_AIR_FX, fx_position, traceDir * -1, forward  );
		}
		
		if( fxCount % FX_PER_FRAME )
		{
			WAIT_CLIENT_FRAME;
		}
	}
}


