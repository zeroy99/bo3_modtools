#using scripts\codescripts\struct;

#using scripts\shared\damagefeedback_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\drown.gsh;

#namespace drown;

#define DROWN_DAMAGE					25

REGISTER_SYSTEM( "drown", &__init__, undefined )

function __init__()
{
	callback::on_spawned( &on_player_spawned );
	level.drown_damage = GetDvarFloat( "player_swimDamage" );
	level.drown_damage_interval = GetDvarFloat( "player_swimDamagerInterval" ) * 1000;
	level.drown_damage_after_time = GetDvarFloat( "player_swimTime" ) * 1000;
	level.drown_pre_damage_stage_time = DROWN_START_BEFORE_DAMAGE_TIME;
	
	DEFAULT( level.vsmgr_prio_overlay_drown_blur, DROWN_OVERLAY_PRIORITY );
	
	visionset_mgr::register_info( "overlay", DROWN_SCREEN_EFFECT_NAME, VERSION_SHIP, level.vsmgr_prio_overlay_drown_blur, DROWN_OVERLAY_LERP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, true );
	
	clientfield::register( "toplayer", "drown_stage", VERSION_SHIP, DROWN_STAGE_BITS, "int" );
}

function activate_player_health_visionset()
{
	self deactivate_player_health_visionset();
	if( !self.drown_vision_set )
	{
		visionset_mgr::activate( "overlay", DROWN_SCREEN_EFFECT_NAME, self, DROWN_OVERLAY_DURATION_IN, DROWN_OVERLAY_DURATION_LOOP, DROWN_OVERLAY_DURATION_OUT );
		self.drown_vision_set = true;
	}
}

function deactivate_player_health_visionset()
{
	if( !isDefined( self.drown_vision_set ) || self.drown_vision_set )
	{
		visionset_mgr::deactivate( "overlay", DROWN_SCREEN_EFFECT_NAME, self );
		self.drown_vision_set = false;
	}
}

function on_player_spawned()
{
	self thread watch_player_drowning();
	self thread watch_player_drown_death();
	self thread watch_game_ended();
	self deactivate_player_health_visionset();
}

function watch_player_drowning()
{
	self endon ( "disconnect" );
	self endon ( "death" );
	level endon( "game_ended" );

	self.lastWaterDamageTime = self getlastoutwatertime();
	self.drownStage = DROWN_STAGE_NONE;
	self clientfield::set_to_player( "drown_stage", DROWN_STAGE_NONE );
	
	if( !isdefined( self.drown_damage_after_time ) )
	{
		self.drown_damage_after_time = level.drown_damage_after_time;
	}
	
	while( 1 )
	{
		if( ( self isplayerunderwater() ) && ( self isplayerswimming() ) )
		{
			if( ( GetTime() - self.lastWaterDamageTime > self.drown_damage_after_time - level.drown_pre_damage_stage_time ) && ( self.drownStage == DROWN_STAGE_NONE ) )
			{
				self.drownStage++;
				self clientfield::set_to_player( "drown_stage", self.drownStage );
			}
			
			if( GetTime() - self.lastWaterDamageTime > self.drown_damage_after_time )
			{
				self.lastWaterDamageTime += level.drown_damage_interval;
				drownFlags = IDFLAGS_NO_KNOCKBACK | IDFLAGS_NO_ARMOR;
				self dodamage( level.drown_damage, self.origin, undefined, undefined, undefined, "MOD_DROWN", drownFlags );
				self activate_player_health_visionset();
				if( self.drownStage < DROWN_STAGE_4 )
				{
					self.drownStage++;
					self clientfield::set_to_player( "drown_stage", self.drownStage );
				}
			}
		}
		else
		{
			self.drownStage = DROWN_STAGE_NONE;
			self clientfield::set_to_player( "drown_stage", DROWN_STAGE_NONE );
			self.lastWaterDamageTime = self getlastoutwatertime();
			self deactivate_player_health_visionset();
		}
		
		WAIT_SERVER_FRAME;
	}
}

function watch_player_drown_death()
{
	self endon ( "disconnect" );
	self endon ( "game_ended" );
	self waittill ( "death" );
	
	self.drownStage = DROWN_STAGE_NONE;
	self clientfield::set_to_player( "drown_stage", DROWN_STAGE_NONE );
	
	self deactivate_player_health_visionset();
}

function watch_game_ended()
{
	self endon ( "disconnect" );
	self endon ( "death" );
	level waittill( "game_ended" );
	
	self.drownStage = DROWN_STAGE_NONE;
	self clientfield::set_to_player( "drown_stage", DROWN_STAGE_NONE );
	
	self deactivate_player_health_visionset();
}

function is_player_drowning()
{
	drowning = true;
	if ( !isdefined( self.drownStage ) || self.drownStage == DROWN_STAGE_NONE )
	{
		drowning = false;
	}
	return drowning;
}