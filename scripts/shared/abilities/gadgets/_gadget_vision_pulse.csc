#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_vision_pulse.gsh;

#using scripts\shared\system_shared;

#namespace gadget_vision_pulse;

REGISTER_SYSTEM( "gadget_vision_pulse", &__init__, undefined )

function __init__()
{
	if ( !SessionModeIsCampaignGame() )
	{
		callback::on_localplayer_spawned( &on_localplayer_spawned );
		
		duplicate_render::set_dr_filter_offscreen( "reveal_en", 50, "reveal_enemy", undefined, DR_TYPE_OFFSCREEN, REVEAL_MATERIAL_ENEMY, DR_CULL_NEVER  );
		duplicate_render::set_dr_filter_offscreen( "reveal_self", 50, "reveal_self", undefined, DR_TYPE_OFFSCREEN, REVEAL_MATERIAL_SELF, DR_CULL_NEVER  );
	}
	
	clientfield::register( "toplayer", "vision_pulse_active", VERSION_SHIP, 1, "int", &vision_pulse_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	visionset_mgr::register_visionset_info( VISION_PULSE_VISIONSET_ALIAS, VERSION_SHIP, VISION_PULSE_VISIONSET_STEPS, undefined, VISION_PULSE_VISIONSET );
}

function on_localplayer_spawned( localClientNum )
{
	if( self == GetLocalPlayer( localClientNum ) )
	{
		self.vision_pulse_owner = undefined;
		filter::init_filter_vision_pulse( localClientNum );
	
		self gadgetpulseresetreveal();
		self set_reveal_self( localClientNum, false );
		self set_reveal_enemy( localClientNum, false );
		self thread watch_emped( localClientNum );
	}
}

function watch_emped( localClientNum )
{
	self endon( "entityshutdown" );
	
	while( 1 )
	{
		if( self IsEMPJammed() )
		{
			self thread disableShader( localClientNum, 0 );
			self notify ( "emp_jammed_vp" );
			break;
		}
		WAIT_CLIENT_FRAME;
	}
}

function disableShader( localClientNum, duration )
{
	self endon ("startVPShader" );
	self endon( "death" );
	self endon( "entityshutdown" );
	self notify( "disableVPShader" );
	self endon( "disableVPShader" );
	
	wait( duration );
	
	filter::disable_filter_vision_pulse( localClientNum, FILTER_INDEX_VISION_PULSE );
}

function watch_world_pulse_end( localClientNum )
{
	self notify ( "watchworldpulseend" );
	self endon ( "watchworldpulseend" );
	self util::waittill_any( "entityshutdown", "death", "emp_jammed_vp" );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_RADIUS, getvisionpulsemaxradius( localClientNum ) + 1 ); 	// Weird thing needed by the shader
}

function do_vision_world_pulse( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "death" );
	
	self notify( "startVPShader" );
	
	self thread watch_world_pulse_end( localClientNum );
	
	filter::enable_filter_vision_pulse( localClientNum, FILTER_INDEX_VISION_PULSE );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_PULSE_WIDTH, 1.0 );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_EDGE_WIDTH, 0.08 );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_IRIS_FADE, 0.0 );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_HIGHLIGHT_ENEMIES, 1.0 );
	
	startTime = GetServerTime( localClientNum );
	
	WAIT_CLIENT_FRAME;
	amount = 1.0;
	irisAmount = 0.0;
	pulsemaxradius = 0;
	while( ( GetServerTime( localClientNum ) - starttime ) < VISION_PULSE_DURATION )
	{
		elapsedTime = ( GetServerTime( localClientNum ) - starttime ) * 1.0;
		if( elapsedTime < ( VISION_PULSE_DURATION * VISION_PULSE_FADE_RAMP_IN ) )
		{
			irisAmount = elapsedTime / ( VISION_PULSE_DURATION * VISION_PULSE_FADE_RAMP_IN );
		}
		else if( elapsedTime < ( VISION_PULSE_DURATION * ( VISION_PULSE_FADE_RAMP_OUT + VISION_PULSE_FADE_RAMP_IN ) ) )
		{
			irisAmount = 1.0 - elapsedTime / ( VISION_PULSE_DURATION * VISION_PULSE_FADE_RAMP_OUT );
		}
		else
		{
			irisAmount = 0.0;
		}
		amount = 1.0 -  elapsedTime / VISION_PULSE_DURATION;
		pulseRadius = getvisionpulseradius( localClientNum );
		pulseMaxRadius = getvisionpulsemaxradius( localClientNum );
		filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_RADIUS, pulseRadius );
		filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_IRIS_FADE, irisAmount );
		filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_MAX_RADIUS, pulseMaxRadius );
		WAIT_CLIENT_FRAME;
	}
	
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_RADIUS, pulseMaxRadius + 1 ); 	// Weird thing needed by the shader
	
	self thread disableShader( localClientNum, VISION_PULSE_REVEAL_TIME / 1000 );	
}

function vision_pulse_owner_valid( owner )
{
	if( isDefined( owner ) && ( owner isPlayer() ) && isAlive( owner ) )
	{
		return true;
	}
	
	return false;
}

function watch_vision_pulse_owner_death( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "death" );
	self endon( "finished_local_pulse" );
	self notify ( "watch_vision_pulse_owner_death" );
	self endon ( "watch_vision_pulse_owner_death" );
	
	owner = self.vision_pulse_owner;
	if( vision_pulse_owner_valid( owner ) )
	{
		owner util::waittill_any( "entityshutdown", "death" );
	}
	
	self notify ( "vision_pulse_owner_death" );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_IS_PULSED, 0 );
	self thread disableShader( localClientNum, VISION_PULSE_REVEAL_TIME / 1000 );
	self.vision_pulse_owner = undefined;
}

function do_vision_local_pulse( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "death" );
	self endon ( "vision_pulse_owner_death" );
	
	self notify( "startVPShader" );
	
	self notify( "startLocalPulse" );
	self endon( "startLocalPulse" );
	
	self thread watch_vision_pulse_owner_death( localClientNum );
	
	origin = getrevealpulseorigin( localClientNum );
	//pulseMaxRadius = getrevealpulsemaxradius( localClientNum );
	filter::enable_filter_vision_pulse( localClientNum, FILTER_INDEX_VISION_PULSE );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_PULSE_WIDTH, 0.4 );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_EDGE_WIDTH, 0.0001 );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_ORIGIN_X, origin[0] );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_ORIGIN_Y, origin[1] );
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_IS_PULSED, 1 );
	
	startTime = GetServerTime( localClientNum );
	while( ( GetServerTime( localClientNum ) - starttime ) < VISION_PULSE_REVEAL_TIME )
	{
		if( (GetServerTime( localClientNum ) - starttime ) < VISION_PULSE_DURATION )
		{
			pulseRadius = ( (GetServerTime( localClientNum ) - starttime ) / VISION_PULSE_DURATION) * 2000;
		}
		//pulseRadius = GetRevealPulseRadius( localClientNum );
		filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_PULSE_POSITION, pulseRadius );
		
		WAIT_CLIENT_FRAME;
	}
	
	filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_IS_PULSED, 0 );
	self thread disableShader( localClientNum, VISION_PULSE_REVEAL_TIME / 1000 );
	self notify ( "finished_local_pulse" );
	self.vision_pulse_owner = undefined;
}

function vision_pulse_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	if ( newVal )
	{
		if( self == GetLocalPlayer( localClientNum ) )
		{
			if ( IsDemoPlaying() && (bnewent || oldval == newval ) )
			{
				return;
			}
			
			self thread do_vision_world_pulse( localClientNum );
		}
	}
}

function do_reveal_enemy_pulse( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "death" );
	
	self notify( "startEnemyPulse" );
	self endon( "startEnemyPulse" );
	startTime = GetServerTime( localClientNum );
	currTime = startTime;
		
	self MapShaderConstant( localclientnum, 0, VISION_PULSE_ENT_SCRIPT_VECTOR, 0.0, 0, 0, 0 );
	while( ( currTime - starttime ) < VISION_PULSE_REVEAL_TIME )
	{
		if( ( currTime - starttime ) > ( VISION_PULSE_REVEAL_TIME - VISION_PULSE_RAMP_OUT_TIME ) )
		{
			value = float( ( currTime - starttime - ( VISION_PULSE_REVEAL_TIME - VISION_PULSE_RAMP_OUT_TIME ) ) / VISION_PULSE_RAMP_OUT_TIME );
			self MapShaderConstant( localclientnum, 0, VISION_PULSE_ENT_SCRIPT_VECTOR, value, 0, 0, 0 );
		}

		WAIT_CLIENT_FRAME;
		currTime = GetServerTime( localClientNum );
	}
}

function set_reveal_enemy( localClientNum, on_off )
{
	if( on_off )
	{
		self thread do_reveal_enemy_pulse( localClientNum );
	}
	self duplicate_render::update_dr_flag( localClientNum, "reveal_enemy", on_off );
}

function set_reveal_self( localClientNum, on_off )
{
	if( on_off && ( self == GetLocalPlayer( localClientNum ) ) )
	{
		self thread do_vision_local_pulse( localClientNum );
	}
	else if( !on_off )
	{
		filter::set_filter_vision_pulse_constant( localClientNum, FILTER_INDEX_VISION_PULSE, VISION_PULSE_CONSTID_VIEWMODEL_IS_PULSED, 0 );
	}
}

function gadget_visionpulse_reveal(localClientNum, bReveal)
{
	self notify( "gadget_visionpulse_changed" );
	
	player = GetLocalPlayer( localClientNum );
	//player motionpulse_enable( true );
	if( !isDefined( self.visionPulseRevealSelf ) && player == self )
	{
		self.visionPulseRevealSelf = false;
	}
	
	if( !isDefined( self.visionPulseReveal ) )
	{
		self.visionPulseReveal = false;
	}
	
	if(player == self)
	{
		owner = self gadgetpulsegetowner( localClientNum );
		if ( ( self.visionPulseRevealSelf != bReveal ) || ( isDefined( self.vision_pulse_owner ) && isDefined( owner ) && ( self.vision_pulse_owner != owner ) ) )
		{
			self.vision_pulse_owner = owner;
			self.visionPulseRevealSelf = bReveal;
			self set_reveal_self( localClientNum, bReveal );
		}
	}
	else
	{
		if ( self.visionPulseReveal != bReveal )
		{
			self.visionPulseReveal = bReveal;
			self set_reveal_enemy( localClientNum, bReveal );
		}
	}
}