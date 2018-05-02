#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\ai_shared;

#using scripts\shared\ai\systems\gib;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\zombie.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\archetype_apothicon_fury.gsh;

#namespace apothiconFuryBehavior;

#precache( "client_fx", FURY_DAMAGE_EFFECT );
#precache( "client_fx", FURY_BREATH_EFFECT );
#precache( "client_fx", FURY_BAMF_LAND_FX );
#precache( "client_fx", FURY_BODY_SMOKE_EFFECT );
#precache( "client_fx", FURY_FOOTSTEP_AMB_EFFECT );
#precache( "client_fx", FURY_DEATH_MODEL_SWAP_EFFECT );

function autoexec main()
{	
	ai::add_archetype_spawn_function( ARCHETYPE_APOTHICON_FURY, &apothiconSpawnSetup );
	
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_APOTHICON_FURY ) )
	{			
		clientfield::register("actor", FURY_DAMAGE_CLIENTFIELD, VERSION_DLC4, GetMinBitCountForNum(7), "counter", &apothiconFireDamageEffect, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);		
		clientfield::register("actor", FURY_FURIOUS_MODE_CLIENTFIELD, VERSION_DLC4, 1, "int", &apothiconFuriousModeEffect, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
		clientfield::register("actor", FURY_BAMF_LAND_CLIENTFIELD, VERSION_DLC4, 1, "counter", &apothiconBamfLandEffect, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
		clientfield::register("actor", FURY_DEATH_CLIENTFIELD, VERSION_DLC4, 2, "int", &apothiconFuryDeath, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
		clientfield::register("actor", FURY_JUKE_CLIENTFIELD, VERSION_DLC4, 1, "int", &apothiconJukeActive, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	}
		
	level._effect[ FURY_DAMAGE_EFFECT ] 				= FURY_DAMAGE_EFFECT;	
	level._effect[ FURY_BREATH_EFFECT ] 				= FURY_BREATH_EFFECT;
	level._effect[ FURY_BAMF_LAND_FX ] 				= FURY_BAMF_LAND_FX;
	level._effect[ FURY_BODY_SMOKE_EFFECT ] 			= FURY_BODY_SMOKE_EFFECT;
	level._effect[ FURY_FOOTSTEP_AMB_EFFECT ] 			= FURY_FOOTSTEP_AMB_EFFECT;	
	level._effect[ FURY_DEATH_MODEL_SWAP_EFFECT ] 		= FURY_DEATH_MODEL_SWAP_EFFECT;		
}

function apothiconSpawnSetup( localClientNum )
{	
	self thread apothiconSpawnShader( localClientNum );
	
	self apothiconStartLoopingEffects( localClientNum );
}

function apothiconStartLoopingEffects( localClientNum )
{
	self.loopingEffects = [];
	
	self.loopingEffects[0] = PlayFXOnTag( localClientNum, level._effect[ FURY_BREATH_EFFECT ], self, "j_head" );
	self.loopingEffects[1] = PlayFXOnTag( localClientNum, level._effect[ FURY_BODY_SMOKE_EFFECT ], self, "j_spine4" );
	
	self.loopingEffects[2] = PlayFXOnTag( localClientNum, level._effect[ FURY_FOOTSTEP_AMB_EFFECT ], self, "j_ball_le" );
	self.loopingEffects[3] = PlayFXOnTag( localClientNum, level._effect[ FURY_FOOTSTEP_AMB_EFFECT ], self, "j_ball_ri" );
	self.loopingEffects[4] = PlayFXOnTag( localClientNum, level._effect[ FURY_FOOTSTEP_AMB_EFFECT ], self, "j_wrist_le" );
	self.loopingEffects[5] = PlayFXOnTag( localClientNum, level._effect[ FURY_FOOTSTEP_AMB_EFFECT ], self, "j_wrist_ri" );
}

function apothiconStopLoopingEffects( localClientNum )
{
	foreach( fx in self.loopingEffects )
	{
		KillFX( localClientNum, fx );
	}
}

function apothiconSpawnShader( localClientNum )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
	
	s_timer = new_timer( localClientNum );
	
	n_phase_in = 1;

	do
	{
	    util::server_wait( localClientNum, 0.11 );
	    n_current_time = s_timer get_time_in_seconds();
	    n_delta_val = LerpFloat( 0, 0.01, n_current_time / n_phase_in );
	    
	    self MapShaderConstant( localclientnum, 0, "scriptVector2", n_delta_val );
	}
	while ( n_current_time < n_phase_in );	
	
	s_timer notify("timer_done");
}

function apothiconJukeActive( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
	
	if( newVal )
	{
		playsound(0,"zmb_fury_bamf_teleport_in",self.origin);
		self apothiconStartLoopingEffects( localClientNum );
	}
	else
	{
		playsound(0,"zmb_fury_bamf_teleport_out",self.origin);
		self apothiconStopLoopingEffects( localClientNum );
	}		
}

function apothiconFireDamageEffect( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
	
	tag = undefined;
	
	if( newVal == IMPACT_R_LEG )
	{
		tag = array::random( array( "J_Hip_RI", "J_Knee_RI" ) );
	}
	if( newVal == IMPACT_L_LEG )
	{
		tag = array::random( array( "J_Hip_LE", "J_Knee_LE" ) );
	}
	else if( newVal == IMPACT_R_ARM )
	{
		tag = array::random( array( "J_Shoulder_RI", "J_Shoulder_RI_tr", "J_Elbow_RI" ) );
	}
	else if( newVal == IMPACT_L_ARM )
	{
		tag = array::random( array( "J_Shoulder_LE", "J_Shoulder_LE_tr", "J_Elbow_LE" ) );
	}
	else if( newVal == IMPACT_HIPS )
	{
		tag = array::random( array( "J_MainRoot" ) );
	}
	else if( newVal == IMPACT_CHEST )
	{
		tag = array::random( array( "J_SpineUpper", "J_Clavicle_RI", "J_Clavicle_LE" ) );
	}
	else
	{
		tag = array::random( array( "J_Neck", "J_Head", "J_Helmet" ) );
	}
	
	fx = PlayFXOnTag( localClientNum, level._effect[ FURY_DAMAGE_EFFECT ], self, tag );			
}

function apothiconFuryDeath( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
	
	if( newVal == 1 )
	{		
		s_timer = new_timer( localClientNum );		
		n_phase_in = 1;	// change this for initial fire shader
		self.removingFireShader = true;
		
		do
		{
		    util::server_wait( localClientNum, 0.11 );
		    n_current_time = s_timer get_time_in_seconds();
		    n_delta_val = LerpFloat( 1, 0.1, n_current_time / n_phase_in );
		    
		    self MapShaderConstant( localclientnum, 0, "scriptVector2", n_delta_val );
		}
		while ( n_current_time < n_phase_in );	
		
		s_timer notify("timer_done");
		
		self.removingFireShader = false;
	}
	else if( newVal == 2 )
	{		
		if ( !IsDefined(self) )
			return;
		
		PlayFXOnTag( localClientNum, level._effect[ FURY_DEATH_MODEL_SWAP_EFFECT ], self, "j_spine4" );  
		self apothiconStopLoopingEffects( localClientNum );
		
		n_phase_in = 0.3;	
		s_timer = new_timer( localClientNum );		
		
		stopTime = GetTime() + ( n_phase_in * 1000 );
		
		do
		{
		    util::server_wait( localClientNum, 0.11 );
		    n_current_time = s_timer get_time_in_seconds();
		    n_delta_val = LerpFloat( 1, 0, n_current_time / n_phase_in );
		    
		    self MapShaderConstant( localclientnum, 0, "scriptVector0", n_delta_val );
		}
		while ( ( n_current_time < n_phase_in ) && ( GetTime() <= stopTime ) );
		
		s_timer notify("timer_done");
		
		self MapShaderConstant( localclientnum, 0, "scriptVector0", 0 );
	}
}

function apothiconFuriousModeEffect( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
	
	if( newVal )
	{		
		s_timer = new_timer( localClientNum );
		
		n_phase_in = 2; //flicker from 0 to 1 time
	
		do
		{
		    util::server_wait( localClientNum, 0.11 );
		    n_current_time = s_timer get_time_in_seconds();
		    n_delta_val = LerpFloat( 0.1, 1, n_current_time / n_phase_in );
		    
		    self MapShaderConstant( localclientnum, 0, "scriptVector2", n_delta_val );
		}
		while ( n_current_time < n_phase_in );
		
		s_timer notify("timer_done");
	}	
}

function new_timer( localClientNum )
{
	s_timer = SpawnStruct();
	s_timer.n_time_current = 0;
	s_timer thread timer_increment_loop( localClientNum, self );
	return s_timer;
}

function timer_increment_loop( localClientNum, entity )
{	
	entity endon( "entityshutdown" );
	self endon("timer_done");
	
	while( IsDefined( self ) )
	{
		util::server_wait( localClientNum, 0.016 );
		self.n_time_current += 0.016;
	}
}

function get_time()
{
	return self.n_time_current * 1000;
}

function get_time_in_seconds()
{
	return self.n_time_current;
}

function reset_timer()
{
	self.n_time_current = 0;
}

function apothiconBamfLandEffect( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );
	
	if ( !IsDefined(self) )
		return;
		
	if( newVal )
	{
		PlayFXOnTag( localClientNum, level._effect[ FURY_BAMF_LAND_FX ], self, "tag_origin" );
	}	
	
	player = GetLocalPlayer( localClientNum );
	player Earthquake( 0.5, 1.4, self.origin, FURY_BAMF_MELEE_RANGE * 1.5 );
	PlayRumbleOnPosition( localClientNum, "apothicon_fury_land", self.origin );
}


