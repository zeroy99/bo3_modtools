#using scripts\shared\util_shared;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_perk_random.gsh;

#precache( "client_fx", "dlc1/castle/fx_wonder_fizz_light_yellow" );
#precache( "client_fx", "dlc1/castle/fx_wonder_fizz_light_red" );
#precache( "client_fx", "dlc1/castle/fx_wonder_fizz_light_green" );
#precache( "client_fx", "zombie/fx_wonder_fizz_lightning_all" );

#namespace zm_perk_random;

REGISTER_SYSTEM( "zm_perk_random", &__init__, undefined )

//* #using_animtree( "zm_perk_random" );

function __init__()
{
	clientfield::register( "scriptmover", "perk_bottle_cycle_state", 		VERSION_DLC1, 2, "int", &start_bottle_cycling, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "zbarrier",	 	"set_client_light_state", 		VERSION_DLC1, 2, "int", &set_light_state, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "zbarrier", 		"init_perk_random_machine", 	VERSION_DLC1, 1, "int", &perk_random_machine_init, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "zbarrier", 		"client_stone_emmissive_blink",	VERSION_DLC1, 1, "int", &perk_random_machine_rock_emissive, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	
	clientfield::register( "scriptmover", "turn_active_perk_light_green", 	VERSION_DLC1, 1, "int", &turn_on_active_light_green, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "turn_on_location_indicator", 	VERSION_DLC1, 1, "int", &turn_on_location_indicator, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "zbarrier", "lightning_bolt_FX_toggle", 	VERSION_TU10, 1, "int", &lightning_bolt_fx_toggle, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "turn_active_perk_ball_light",	VERSION_DLC1, 1, "int", &turn_on_active_ball_light, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "zone_captured", 					VERSION_DLC1, 1, "int", &zone_captured_cb, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	level._effect[ "perk_machine_light_yellow" ] = 				"dlc1/castle/fx_wonder_fizz_light_yellow";
	level._effect[ "perk_machine_light_red" ] = 				"dlc1/castle/fx_wonder_fizz_light_red";
	level._effect[ "perk_machine_light_green" ] = 				"dlc1/castle/fx_wonder_fizz_light_green";

	level._effect[ "perk_machine_location" ] = 					"zombie/fx_wonder_fizz_lightning_all";
}

function init_animtree()
{
	//* ScriptModelsUseAnimTree( #animtree );
}

//this is here to make sure old theatre files don't break
function turn_on_location_indicator( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	
}

// indicator effect for when machine has the ancient sphere present
function lightning_bolt_fx_toggle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IsDemoPlaying() && GetDemoVersion() < 17 )
	{
		return;
	}
	
	self notify( "lightning_bolt_fx_toggle" + localClientNum );
	self endon( "lightning_bolt_fx_toggle" + localClientNum );
	
	player = GetLocalPlayer( localClientNum );
	player endon( "entityshutdown" );
	
	DEFAULT( self._location_indicator, [] );
	
	while ( true )
	{	
		if ( ( newVal == 1 ) && !IsIGCActive( localClientNum ) )
		{
			if ( !isdefined( self._location_indicator[ localClientNum ] ) )
			{
				self._location_indicator[ localClientNum ] = PlayFX( localClientNum, level._effect[ "perk_machine_location" ], self.origin );
			}
		}
		else if ( isdefined( self._location_indicator[ localClientNum ] ) )
		{
			StopFX( localClientNum, self._location_indicator[ localClientNum ] );
			self._location_indicator[ localClientNum ] = undefined;
		}
		
		wait 1;
	}
}


// only need this to turn off shader effects when the zone is recaptured
function zone_captured_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	// default mapped_const to 0
	if ( !isdefined( self.mapped_const ) )
	{
		self MapShaderConstant( localClientNum, 1, "ScriptVector0" );
		self.mapped_const = true;
	}

	if ( newVal == 1 )
	{
	}
	else
	{
		// shader
		self.artifact_glow_setting = ARTIFACT_DIM;
		self.machinery_glow_setting = MACHINE_OFF;
		self SetShaderConstant( localClientNum, 1, self.artifact_glow_setting, 0, self.machinery_glow_setting, 0 );
	}
}

function perk_random_machine_rock_emissive(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if (newVal == 1)
	{
		//thread off a function to blink emissive - it dies when new val called as 0
		piece = self ZBarrierGetPiece( ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX );
		piece.blinking = true;
		
		piece thread rock_emissive_think(localClientNum);
	}
	else if (newVal == 0)
	{
		//end prev function
		self.blinking = false;
	}
}

function rock_emissive_think(localClientNum)
{
	level endon("demo_jump"); // end when theater mode rewinds
	
	while (IS_TRUE(self.blinking))
	{
		self rock_emissive_fade(localClientNum, 8, 0);
		self rock_emissive_fade(localClientNum, 0, 8);
	}
}

function rock_emissive_fade(localClientNum, n_max_val, n_min_val)
{
	const N_CONVERT_FROM_SECONDS = 1000;
	const N_RAMP_DURATION = .5;
	
	n_start_time = GetTime();

	n_end_time = n_start_time + N_RAMP_DURATION * N_CONVERT_FROM_SECONDS;

	b_is_updating = true;
	while(b_is_updating)
	{
		n_time = GetTime();
					
		if( n_time >= n_end_time )
		{
			n_shader_value = MapFloat( n_start_time, n_end_time, n_min_val, n_max_val, n_end_time );
			b_is_updating = false;
		}
		else
		{
			n_shader_value = MapFloat( n_start_time, n_end_time, n_min_val, n_max_val, n_time );
		}
		
		if ( isdefined(self) )
		{
			self MapShaderConstant( localClientNum, 0, "scriptVector2", n_shader_value, 0, 0 ); // 			2 x
			self MapShaderConstant( localClientNum, 0, "scriptVector0", 0, n_shader_value, 0 ); // 			0 y
			self MapShaderConstant( localClientNum, 0, "scriptVector0", 0, 0, n_shader_value ); // 			0 y
		}
		
		wait 0.01;
	}
}

function private perk_random_machine_init( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IsDefined( self.perk_random_machine_fx ) )
	{
		return;
	}
	
	if (!IsDefined(self))
		return;
	
	self.perk_random_machine_fx = [];

	self.perk_random_machine_fx[ZM_PERK_RANDOM_STATUS_FX_TAG+ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX] = [];
	self.perk_random_machine_fx[ZM_PERK_RANDOM_STATUS_FX_TAG+ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX] = [];
	self.perk_random_machine_fx[ZM_PERK_RANDOM_STATUS_FX_TAG+ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX] = [];

}

// effects for when machine is powered
function set_light_state( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//loop over all three peices
	a_n_piece_indices = array(ZM_PERK_RANDOM_BODY_ON_OFF_PIECE_INDEX, ZM_PERK_RANDOM_BODY_AVAILABLE_PIECE_INDEX, ZM_PERK_RANDOM_BODY_IDLE_PIECE_INDEX);
	foreach (n_piece_index in a_n_piece_indices)
	{
		//send piece index and get it in function
		if ( newVal == ZM_PERK_RANDOM_NO_LIGHT_BIT )
		{
			perk_random_machine_play_fx(localClientNum, n_piece_index, ZM_PERK_RANDOM_STATUS_FX_TAG, undefined);
		}
		else if ( newVal == ZM_PERK_RANDOM_RED_LIGHT_BIT )
		{
			//red light
			perk_random_machine_play_fx(localClientNum, n_piece_index, ZM_PERK_RANDOM_STATUS_FX_TAG, level._effect[ "perk_machine_light_red" ]);
			
		}
		else if ( newVal == ZM_PERK_RANDOM_GREEN_LIGHT_BIT )
		{
			//green light
			perk_random_machine_play_fx(localClientNum, n_piece_index, ZM_PERK_RANDOM_STATUS_FX_TAG, level._effect[ "perk_machine_light_green" ]);
			
		}
		else if ( newVal == ZM_PERK_RANDOM_YELLOW_LIGHT_BIT )
		{
			//yellow light
			//perk_random_machine_play_fx(localClientNum, fx_piece, ZM_PERK_RANDOM_STATUS_FX_TAG, level._effect[ "perk_machine_light_yellow" ]);
		}
	}
}

function private perk_random_machine_play_fx( localClientNum, piece_index, tag, fx, deleteImmediate = true )
{
	piece = self ZBarrierGetPiece( piece_index );
	
	if ( IsDefined( self.perk_random_machine_fx[tag+piece_index][localClientNum] ) )
	{
		DeleteFX( localClientNum, self.perk_random_machine_fx[tag+piece_index][localClientNum], deleteImmediate );
		self.perk_random_machine_fx[tag+piece_index][localClientNum] = undefined;
	}

	if ( IsDefined( fx ) )
	{
		self.perk_random_machine_fx[tag+piece_index][localClientNum] = PlayFXOnTag( localClientNum, fx, piece, tag );
	}
}

function turn_on_active_light_green( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 1 )
	{
		//* self._active_glow_green = PlayFXOnTag( localClientNum, level._effect[ "perk_machine_light_green" ], self, "tag_origin" );
		// shader
		self.artifact_glow_setting = ARTIFACT_DIM;
		self.machinery_glow_setting = MACHINE_AVAILABLE;
		self SetShaderConstant( localClientNum, 1, self.artifact_glow_setting, 0, self.machinery_glow_setting, 0 );
	}
	else
	{
		//* StopFX( localClientNum, self._active_glow_green );
	}
}

// effects for when machine is powered and ball is present
function turn_on_active_ball_light( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 1 )
	{
		//* self._ball_glow = PlayFXOnTag( localClientNum, level._effect[ "perk_machine_light" ], self, "j_ball" );

		// shader
		self.artifact_glow_setting = ARTIFACT_DIM;
		self.machinery_glow_setting = MACHINE_ACTIVATED;
		self SetShaderConstant( localClientNum, 1, self.artifact_glow_setting, 0, self.machinery_glow_setting, 0 );
	}
	else
	{
		//* StopFX( localClientNum, self._ball_glow );
	}
}

// vortex for when machine is activated, start a thread that calls every 0.1 seconds
function start_bottle_cycling( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 1 )
	{
		self thread start_vortex_fx( localClientNum );
	}
	else
	{
		self thread stop_vortex_fx( localClientNum );
	}
}

function start_vortex_fx( localClientNum )
{
	self endon( "activation_electricity_finished" );
	self endon( "entityshutdown" );

	if ( !isdefined( self.glow_location ) )
	{
		self.glow_location = spawn( localclientNum, self.origin, "script_model" );
		self.glow_location.angles = self.angles;
		self.glow_location setmodel( "tag_origin" );
	}

	// progression of effects
	self thread fx_activation_electric_loop( localClientNum );
	self thread fx_artifact_pulse_thread( localClientNum );
	//SOUND - Shawn J
	//* playsound( localClientNum, "zmb_rand_perk_vortex_sparks", self.origin );
	wait DELAY_PRE_PORTAL_EFFECT;

	self thread fx_bottle_cycling( localClientNum );
	//SOUND - Shawn J
	//* soundloopemitter ( "zmb_rand_perk_vortex", self.origin );
}

function stop_vortex_fx( localClientNum )
{
	self endon( "entityshutdown" );
	// progression of effects - shutdown is in reverse
	self notify( "bottle_cycling_finished" );
	//SOUND - Shawn J
	//* playsound( localClientNum, "zmb_rand_perk_vortex_sparks", self.origin );
	wait DELAY_POST_PORTAL_EFFECT;

	//SOUND - Shawn J
	//* soundstoploopemitter ( "zmb_rand_perk_vortex", self.origin );

	if ( !IsDefined( self ) )
	{
		return;
	}

	self notify( "activation_electricity_finished" );
	if ( isdefined( self.glow_location ) )
	{
		self.glow_location delete();
	}

	// shader
	self.artifact_glow_setting = ARTIFACT_DIM;
	self.machinery_glow_setting = MACHINE_AVAILABLE;
	self SetShaderConstant( localClientNum, 1, self.artifact_glow_setting, 0, self.machinery_glow_setting, 0 );
}

function fx_artifact_pulse_thread( localClientNum )
{
	self endon( "activation_electricity_finished" );
	self endon( "entityshutdown" );

	// shader
	while ( IsDefined( self ) )
	{
		const ARTIFACT_PULSE_TIMESCALE = 0.2;
		const ARTIFACT_PULSE_BASELINE = 0.75; // max glow is 0, min is 1
		shader_amount = ( Sin( getrealtime() * ARTIFACT_PULSE_TIMESCALE ) );
		if ( shader_amount < 0 )
		{
			shader_amount *= -1;
		}
		shader_amount = ARTIFACT_PULSE_BASELINE - ( shader_amount * ARTIFACT_PULSE_BASELINE ); // max glow is 0, min is 1
		self.artifact_glow_setting = shader_amount;
		self.machinery_glow_setting = MACHINE_ACTIVATED;
		self SetShaderConstant( localClientNum, 1, self.artifact_glow_setting, 0, self.machinery_glow_setting, 0 );
		wait 0.05;
	}
}

// this controls the activation electrical effect - loops every tenth of a second
function fx_activation_electric_loop( localClientNum )
{
	self endon( "activation_electricity_finished" );
	self endon( "entityshutdown" );

	while ( true )
	{
		if ( IsDefined( self.glow_location ) )
		{
			//* PlayFXOnTag( localClientNum, level._effect[ "perk_machine_activation_electric_loop" ], self.glow_location, "tag_origin" );
		}
		wait 0.1;
	}
}

// this controls the portal effect - loops every tenth of a second
function fx_bottle_cycling( localClientNum )
{
	self endon( "bottle_cycling_finished" );

	while ( true )
	{
		if ( IsDefined( self.glow_location ) )
		{
			//* PlayFXOnTag( localClientNum, level._effect[ "bottle_glow" ], self.glow_location, "tag_origin" );
		}
		wait 0.1;
	}
}
