#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\drown.gsh;

#namespace drown;

#define DROWN_FRAME_PASS					1
#define DROWN_BLUR_DURATION					500
#define DROWN_FADE_DURATION					250
	
#define DROWN_RADIUS_SCALE					1.41421	// sqr( 2 )
	
// keep all these between 0 and 1, they will be scaled by DROWN_RADIUS_SCALE later
// where 0 is center, 1 is corner
#define RADIUS_INNER_STAGE_1_BEGIN			.8
#define RADIUS_INNER_STAGE_1_END			.5
#define RADIUS_OUTER_STAGE_1_BEGIN			 1		
#define RADIUS_OUTER_STAGE_1_END			.8
	
#define RADIUS_INNER_STAGE_2_BEGIN			.6		
#define RADIUS_INNER_STAGE_2_END			.3
#define RADIUS_OUTER_STAGE_2_BEGIN			.8		
#define RADIUS_OUTER_STAGE_2_END			.6
	
#define RADIUS_INNER_STAGE_3_BEGIN			.6		
#define RADIUS_INNER_STAGE_3_END			.3
#define RADIUS_OUTER_STAGE_3_BEGIN			.8		
#define RADIUS_OUTER_STAGE_3_END			.6
	
#define RADIUS_INNER_STAGE_4_BEGIN			.5		
#define RADIUS_INNER_STAGE_4_END			.2
#define RADIUS_OUTER_STAGE_4_BEGIN			.7		
#define RADIUS_OUTER_STAGE_4_END			.5
	
//OPACTIY
#define OPACITY_STAGE_1_BEGIN				.4
#define OPACITY_STAGE_1_END					.5
	
#define OPACITY_STAGE_2_BEGIN				.5
#define OPACITY_STAGE_2_END					.6
	
#define OPACITY_STAGE_3_BEGIN				.6
#define OPACITY_STAGE_3_END					.7
	
#define OPACITY_STAGE_4_BEGIN				.6
#define OPACITY_STAGE_4_END					.7
	
	
REGISTER_SYSTEM( "drown", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "toplayer", "drown_stage", VERSION_SHIP, DROWN_STAGE_BITS, "int", &drown_stage_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	callback::on_localplayer_spawned( &player_spawned );
	
	level.playerMaxHealth = GetGametypeSetting( "playerMaxHealth" );
	level.player_swim_damage_interval = GetDvarFloat( "player_swimDamagerInterval", 5000 ) * 1000;
	level.player_swim_damage = GetDvarFloat( "player_swimDamage", 5000 );
	level.player_swim_time = GetDvarFloat( "player_swimTime", 5000 ) * 1000;
	level.player_swim_death_time = ( level.playerMaxHealth / level.player_swim_damage ) * level.player_swim_damage_interval + DROWN_START_BEFORE_DAMAGE_TIME;
	
	visionset_mgr::register_overlay_info_style_speed_blur( DROWN_SCREEN_EFFECT_NAME, 
	                                                      VERSION_SHIP, 
	                                                      DROWN_OVERLAY_LERP_COUNT, 
	                                                      DROWN_OVERLAY_BLUR_AMOUNT, 
	                                                      DROWN_OVERLAY_INNER_RADIUS, 
	                                                      DROWN_OVERLAY_OUTER_RADIUS, 
	                                                      DROWN_OVERLAY_SHOULD_VELOCITY_SCALE, 
	                                                      DROWN_OVERLAY_SHOULD_VELOCITY_SCALE, 
	                                                      DROWN_OVERLAY_TIME_FADE_IN, 
	                                                      DROWN_OVERLAY_TIME_FADE_OUT, 
	                                                      DROWN_OVERLAY_SHOULD_OFFSET );

	setup_radius_values();
}

function setup_radius_values()
{
	level.drown_radius["inner"]["begin"][DROWN_STAGE_1] = RADIUS_INNER_STAGE_1_BEGIN;
	level.drown_radius["inner"]["begin"][DROWN_STAGE_2] = RADIUS_INNER_STAGE_2_BEGIN;
	level.drown_radius["inner"]["begin"][DROWN_STAGE_3] = RADIUS_INNER_STAGE_3_BEGIN;
	level.drown_radius["inner"]["begin"][DROWN_STAGE_4] = RADIUS_INNER_STAGE_4_BEGIN;
	
	level.drown_radius["inner"]["end"][DROWN_STAGE_1] = RADIUS_INNER_STAGE_1_END;
	level.drown_radius["inner"]["end"][DROWN_STAGE_2] = RADIUS_INNER_STAGE_2_END;
	level.drown_radius["inner"]["end"][DROWN_STAGE_3] = RADIUS_INNER_STAGE_3_END;
	level.drown_radius["inner"]["end"][DROWN_STAGE_4] = RADIUS_INNER_STAGE_4_END;
	
	level.drown_radius["outer"]["begin"][DROWN_STAGE_1] = RADIUS_OUTER_STAGE_1_BEGIN;
	level.drown_radius["outer"]["begin"][DROWN_STAGE_2] = RADIUS_OUTER_STAGE_2_BEGIN;
	level.drown_radius["outer"]["begin"][DROWN_STAGE_3] = RADIUS_OUTER_STAGE_3_BEGIN;
	level.drown_radius["outer"]["begin"][DROWN_STAGE_4] = RADIUS_OUTER_STAGE_4_BEGIN;
	
	level.drown_radius["outer"]["end"][DROWN_STAGE_1] = RADIUS_OUTER_STAGE_1_END;
	level.drown_radius["outer"]["end"][DROWN_STAGE_2] = RADIUS_OUTER_STAGE_2_END;
	level.drown_radius["outer"]["end"][DROWN_STAGE_3] = RADIUS_OUTER_STAGE_3_END;
	level.drown_radius["outer"]["end"][DROWN_STAGE_4] = RADIUS_OUTER_STAGE_4_END;
	
	
	level.opacity["begin"][DROWN_STAGE_1] = OPACITY_STAGE_1_BEGIN;
	level.opacity["begin"][DROWN_STAGE_2] = OPACITY_STAGE_2_BEGIN;
	level.opacity["begin"][DROWN_STAGE_3] = OPACITY_STAGE_3_BEGIN;
	level.opacity["begin"][DROWN_STAGE_4] = OPACITY_STAGE_4_BEGIN;
	
	level.opacity["end"][DROWN_STAGE_1] = OPACITY_STAGE_1_END;
	level.opacity["end"][DROWN_STAGE_2] = OPACITY_STAGE_2_END;
	level.opacity["end"][DROWN_STAGE_3] = OPACITY_STAGE_3_END;
	level.opacity["end"][DROWN_STAGE_4] = OPACITY_STAGE_4_END;
}

function player_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	self player_init_drown_values();
	self thread player_watch_drown_shutdown( localClientNum );
}

function player_init_drown_values()
{
	if( !isDefined( self.drown_start_time ) )
	{
		self.drown_start_time = 0;
		self.drown_outerRadius = 0;
		self.drown_innerRadius = 0;
		self.drown_opacity = 0;
	}
}

function player_watch_drown_shutdown( localClientNum )
{
	self util::waittill_any ( "entityshutdown", "death" );
	self disable_drown( localClientNum );
}

function enable_drown( localClientNum , stage )
{
	filter::init_filter_drowning_damage( localClientNum );
	filter::enable_filter_drowning_damage( localClientNum, DROWN_FRAME_PASS );
	self.drown_start_time = GetServerTime( localClientNum ) - ( stage - 1 ) * level.player_swim_damage_interval;
	self.drown_outerRadius = 0;
	self.drown_innerRadius = 0;
	self.drown_opacity = 0;
}

function disable_drown( localClientNum )
{
	filter::disable_filter_drowning_damage( localClientNum, DROWN_FRAME_PASS );
}

function player_drown_fx( localClientNum, stage )
{
	self endon ( "death" );
	self endon ( "entityshutdown" );
	self endon ( "player_fade_out_drown_fx" );
	self notify ( "player_drown_fx" );
	self endon ( "player_drown_fx" );
	
	self player_init_drown_values();
	
	lastOutWaterTimeStage = self.drown_start_time + ( stage - 1 ) * level.player_swim_damage_interval;
	
	stageDuration = level.player_swim_damage_interval;
	if( stage == DROWN_STAGE_1 )
	{
		stageDuration = DROWN_START_BEFORE_DAMAGE_TIME;
	}
		
	while( 1 )
	{
		currentTime = GetServerTime( localClientNum );
		elapsedTime = currentTime - self.drown_start_time;

		stageRatio = math::clamp( ( currentTime - lastOutWaterTimeStage ) / stageDuration, 0.0, 1.0 );
		self.drown_outerRadius = lerpFloat(level.drown_radius["outer"]["begin"][stage], level.drown_radius["outer"]["end"][stage], stageRatio ) * DROWN_RADIUS_SCALE;
		self.drown_innerRadius = lerpFloat(level.drown_radius["inner"]["begin"][stage], level.drown_radius["inner"]["end"][stage], stageRatio ) * DROWN_RADIUS_SCALE;
		self.drown_opacity = lerpFloat(level.opacity["begin"][stage], level.opacity["end"][stage], stageRatio );
		
		filter::set_filter_drowning_damage_inner_radius( localClientNum, DROWN_FRAME_PASS, self.drown_innerRadius );
		filter::set_filter_drowning_damage_outer_radius( localClientNum, DROWN_FRAME_PASS, self.drown_outerRadius );
		filter::set_filter_drowning_damage_opacity( localClientNum, DROWN_FRAME_PASS, self.drown_opacity );
		
		WAIT_CLIENT_FRAME;
	}
}

function player_fade_out_drown_fx( localClientNum )
{
	self endon ( "death" );
	self endon ( "entityshutdown" );
	self endon ( "player_drown_fx" );
	self notify ( "player_fade_out_drown_fx" );
	self endon ( "player_fade_out_drown_fx" );
	
	self player_init_drown_values();
	
	fadeStartTime = GetServerTime( localClientNum );
	currentTime = GetServerTime( localClientNum );
	while( currentTime - fadeStartTime < DROWN_FADE_DURATION )
	{
		ratio = ( currentTime - fadeStartTime ) / DROWN_FADE_DURATION;
		outerRadius = lerpFloat( self.drown_outerRadius, DROWN_RADIUS_SCALE, ratio );
		innerRadius = lerpFloat( self.drown_innerRadius, DROWN_RADIUS_SCALE, ratio );
		opacity = lerpFloat( self.drown_opacity, 0, ratio );
		
		filter::set_filter_drowning_damage_outer_radius( localClientNum, DROWN_FRAME_PASS, outerRadius );
		filter::set_filter_drowning_damage_inner_radius( localClientNum, DROWN_FRAME_PASS, innerRadius );
		filter::set_filter_drowning_damage_opacity( localClientNum, DROWN_FRAME_PASS, opacity );
		
		WAIT_CLIENT_FRAME;
		currentTime = GetServerTime( localClientNum );
	}
	
	self disable_drown( localClientNum );
}

function drown_stage_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal > DROWN_STAGE_NONE )
	{
		self enable_drown( localClientNum, newVal );
		self thread player_drown_fx( localClientNum, newVal );
	}
	else if( !bNewEnt )
	{
		self thread player_fade_out_drown_fx( localClientNum );
	}
	else
	{
		self disable_drown( localClientNum );
	}
}