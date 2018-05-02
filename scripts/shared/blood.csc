#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\filter_shared;

#insert scripts\shared\shared.gsh;

#namespace blood;

#define BLOOD_STAGE_1_THRESHOLD					.99
#define BLOOD_STAGE_2_THRESHOLD					.80
#define BLOOD_STAGE_3_THRESHOLD					.5

#define BLOOD_SPRITE_LIGHT_PASS					0
#define BLOOD_SPRITE_HEAVY_PASS					1
#define BLOOD_FRAME_PASS						2

#define BLOOD_FADE_RATE							1000 // per ms
	
REGISTER_SYSTEM( "blood", &__init__, undefined )
	
function __init__()
{
	level.bloodStage3 = GetDvarFloat( "cg_t7HealthOverlay_Threshold3", BLOOD_STAGE_3_THRESHOLD );
	level.bloodStage2 = GetDvarFloat( "cg_t7HealthOverlay_Threshold2", BLOOD_STAGE_2_THRESHOLD );
	level.bloodStage1 = GetDvarFloat( "cg_t7HealthOverlay_Threshold1", BLOOD_STAGE_1_THRESHOLD );
	level.use_digital_blood_enabled = GetDvarFloat( "scr_use_digital_blood_enabled", true );
	
	callback::on_localplayer_spawned( &localplayer_spawned );
}

function localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

/#
	level.use_digital_blood_enabled = GetDvarFloat( "scr_use_digital_blood_enabled", level.use_digital_blood_enabled );
#/
	self.use_digital_blood = false;
	bodyType = self GetCharacterBodyType();
	if ( ( level.use_digital_blood_enabled ) && ( bodyType >= 0 ) )
	{
		bodyTypeFields = GetCharacterFields( bodyType, CurrentSessionMode() );
		self.use_digital_blood = VAL( bodyTypeFields.digitalBlood, false );
	}
	
	self thread player_watch_blood( localClientNum );
	self thread player_watch_blood_shutdown( localClientNum );
}

function player_watch_blood_shutdown( localClientNum )
{
	self util::waittill_any ( "entityshutdown", "death" );
	self disable_blood( localClientNum );
}

function enable_blood( localClientNum )
{
	self.blood_enabled = true;
	filter::init_filter_feedback_blood( localClientNum, self.use_digital_blood );
	filter::enable_filter_feedback_blood( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, self.use_digital_blood );
	filter::set_filter_feedback_blood_sundir( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, 65, 32 );
	
	filter::init_filter_sprite_blood_heavy( localClientNum, self.use_digital_blood );
	filter::enable_filter_sprite_blood_heavy( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, self.use_digital_blood );
	filter::set_filter_sprite_blood_seed_offset( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, RandomFloat( 1 ) );
}

function disable_blood( localClientNum )
{
	if( isdefined( self ) )
	{
		self.blood_enabled = false;
	}
	
	filter::disable_filter_feedback_blood( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS );
	filter::disable_filter_sprite_blood( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS );

	if(!IS_TRUE(self.noBloodLightBarChange))
	{
		SetControllerLightbarColor( localClientNum );
	}
}

function blood_in( localClientNum, playerHealth )
{
	if( playerHealth < level.bloodStage3 )
	{
		self.stage3Amount = ( level.bloodStage3 - playerHealth ) / ( level.bloodStage3 );
	}
	else
	{
		self.stage3Amount = 0;
	}
	
	if( playerHealth < level.bloodStage2 )
	{
		self.stage2Amount = ( level.bloodStage2 - playerHealth ) / level.bloodStage2;
	}
	else
	{
		self.stage2Amount = 0;
	}
	
	filter::set_filter_feedback_blood_vignette( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, self.stage3Amount );
	filter::set_filter_feedback_blood_opacity( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, self.stage2Amount );
	
	if( playerHealth < level.bloodStage1 )
	{	
		minStage1Health = 0.55;
		
		assert( level.bloodStage1 > minStage1Health );
		
		stageHealth = playerHealth - minStage1Health;
		if( stagehealth < 0 )
			stagehealth = 0;
		self.stage1Amount = 1.0 - ( stageHealth / ( level.bloodStage1 - minStage1Health ) );
	}
	else
	{
		self.stage1Amount = 0;
	}
	
	filter::set_filter_sprite_blood_opacity( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, self.stage1Amount );
	filter::set_filter_sprite_blood_elapsed( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, GetServerTime( localClientNum ) );
}

function blood_out( localClientNum )
{
	currentTime = GetServerTime( localClientNum );
	elapsedTime = currentTime - self.lastBloodUpdate;
	self.lastBloodUpdate = currentTime;
	subTract = elapsedTime / BLOOD_FADE_RATE;
	
	if( self.stage3Amount > 0 )
	{
		self.stage3Amount -= subTract;
	}
	
	if( self.stage3Amount < 0 )
	{
		self.stage3Amount = 0;
	}
	
	if( self.stage2Amount > 0 )
	{
		self.stage2Amount -= subTract;
	}
	
	if( self.stage2Amount < 0 )
	{
		self.stage2Amount = 0;
	}
	
	filter::set_filter_feedback_blood_vignette( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, self.stage3Amount );
	filter::set_filter_feedback_blood_opacity( localClientNum, FILTER_INDEX_BLOOD, BLOOD_FRAME_PASS, self.stage2Amount );
	
	if( self.stage1Amount > 0 )
	{
		self.stage1Amount -= subTract;
	}
	
	if( self.stage1Amount < 0 )
	{
		self.stage1Amount = 0;
	}
	
	filter::set_filter_sprite_blood_opacity( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, self.stage1Amount );
	filter::set_filter_sprite_blood_elapsed( localClientNum, FILTER_INDEX_BLOOD, BLOOD_SPRITE_HEAVY_PASS, GetServerTime( localClientNum ) );
}

function player_watch_blood( localClientNum )
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	self endon( "death" );
	self endon("killBloodOverlay");
	
	self.stage2Amount = 0;
	self.stage3Amount = 0;
	self.lastBloodUpdate = 0;
	priorPlayerHealth = renderhealthoverlayhealth( localClientNum );
	self blood_in( localClientNum, priorPlayerHealth );
	while( true )
	{
		if( renderHealthOverlay( localClientNum ) && !IS_TRUE(self.noBloodOverlay) )
		{
			shouldEnabledOverlay = false;
			playerHealth = renderhealthoverlayhealth( localClientNum );
			if( playerHealth < priorPlayerHealth )
			{
				shouldEnabledOverlay = true;
				self blood_in( localClientNum, playerHealth );
			}
			else if( ( playerHealth == priorplayerhealth ) && ( playerhealth != 1.0 ) )
			{
				shouldEnabledOverlay = true;
				self.lastBloodUpdate = GetServerTime( localClientNum );
			}
			else if( ( self.stage2Amount > 0 ) || ( self.stage3Amount > 0 ) ) // while we're recovering till we're done fading out
			{
				shouldEnabledOverlay = true;
				self blood_out( localClientNum );
			}
			else if( IS_TRUE( self.blood_enabled ) )
			{
				self disable_blood( localClientNum );
			}
			priorPlayerHealth = playerHealth;
			
			if( !IS_TRUE( self.blood_enabled ) && shouldEnabledOverlay )
			{
				self enable_blood( localClientNum );
			}
			if(!IS_TRUE(self.noBloodLightBarChange))
			{
				if( self.stage3Amount > 0 )
				{
					SetControllerLightBarColorPulsing( localClientNum, (1,0,0), 600 );
				}
				else if( self.stage2Amount == 1 )
				{
					SetControllerLightBarColorPulsing( localClientNum, (0.8,0,0), 1200 );
				}
				else
				{
					if( GetGadgetPower( localClientNum ) == 1.0 && ( !SessionModeIsCampaignGame() || CodeGetUIModelClientField( self, "playerAbilities.inRange" ) ) )
					{
						SetControllerLightBarColorPulsing( localClientNum, (1,1,0), 2000 );
					}
					else
					{
						if( isdefined( self.controllerColor ) )
						{
							SetControllerLightbarColor( localClientNum, self.controllerColor );
						}
						else
						{
							SetControllerLightbarColor( localClientNum );
						}
					}
				}
			}
		}
		else if( IS_TRUE( self.blood_enabled ) )
		{
			self disable_blood( localClientNum );
		}
		
		WAIT_CLIENT_FRAME;
	}
}

// This function needs to be called every frame to keep the pulse going
function SetControllerLightBarColorPulsing( localClientNum, color, pulseRate )
{
	curColor = color * 0.2;
	scale = ( ( GetTime() % pulseRate ) / (pulseRate * 0.5) );
	if( scale > 1.0 )
	{
		scale = (scale - 2.0) * -1.0;
	}
	curColor += color * 0.8 * scale;
	
	SetControllerLightbarColor( localClientNum, curColor );
}