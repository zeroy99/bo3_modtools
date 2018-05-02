#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\archetype_shared\archetype_shared;
#using scripts\shared\beam_shared;

#using scripts\shared\postfx_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\vehicles\_sentinel_drone.gsh;

#namespace sentinel_drone;

#using_animtree( "generic" );

#define SENTINEL_DRONE_CLAW_RIGHT_FX_TAG		"tag_fx1"
#define SENTINEL_DRONE_CLAW_LEFT_FX_TAG			"tag_fx2"
#define SENTINEL_DRONE_CLAW_TOP_FX_TAG			"tag_fx3"
#define SENTINEL_DRONE_CAMERA_FX_TAG			"tag_flash"	
	
#define SENTINEL_DRONE_ENGINE_FX_TAG			"tag_fx_engine_left"		

#define SENTINEL_DRONE_BEAM						"electric_taser_beam_1"
#define SENTINEL_DRONE_BEAM_TARGET_FX			"dlc3/stalingrad/fx_sentinel_drone_taser_fire_tgt"

#define SENTINEL_DRONE_CLAWS_AMBIENT_FX			"dlc3/stalingrad/fx_sentinel_drone_taser_idle"
#define SENTINEL_DRONE_CLAWS_CHARGING_FX		"dlc3/stalingrad/fx_sentinel_drone_taser_charging"
#define SENTINEL_DRONE_CAMERA_AMBIENT_FX		"dlc3/stalingrad/fx_sentinel_drone_eye_camera_lens_glow"
#define SENTINEL_DRONE_CORE_GLOW_FX				"dlc3/stalingrad/fx_sentinel_drone_energy_core_glow"
#define SENTINEL_DRONE_SCANNER_LIGHT_FX			"dlc3/stalingrad/fx_sentinel_drone_scanner_light_glow"
	
#define SENTINEL_DRONE_FACE_BREAK_FX			"dlc3/stalingrad/fx_sentinel_drone_dest_core"
#define SENTINEL_DRONE_ARM_BREAK_FX				"dlc3/stalingrad/fx_sentinel_drone_dest_arm"
#define SENTINEL_DRONE_EYE_BREAK_FX				"dlc3/stalingrad/fx_sentinel_drone_dest_camera_eye"
	
#define SENTINEL_DRONE_ENGINE_FX				"dlc3/stalingrad/fx_sentinel_drone_engine_idle"	
#define SENTINEL_DRONE_ENGINE_ROLL_FX			"dlc3/stalingrad/fx_sentinel_drone_engine_smk_fast"	
	
#define SENTINEL_DRONE_PLAYER_DAMAGE_FX			"sentinel_pstfx_shock_charge"	

//Effects	
#precache( "client_fx", SENTINEL_DRONE_BEAM );
#precache( "client_fx", SENTINEL_DRONE_BEAM_TARGET_FX );

#precache( "client_fx", SENTINEL_DRONE_CLAWS_AMBIENT_FX );
#precache( "client_fx", SENTINEL_DRONE_CLAWS_CHARGING_FX );
#precache( "client_fx", SENTINEL_DRONE_CAMERA_AMBIENT_FX );
#precache( "client_fx", SENTINEL_DRONE_CORE_GLOW_FX );
#precache( "client_fx", SENTINEL_DRONE_SCANNER_LIGHT_FX );

#precache( "client_fx", SENTINEL_DRONE_FACE_BREAK_FX );
#precache( "client_fx", SENTINEL_DRONE_ARM_BREAK_FX );
#precache( "client_fx", SENTINEL_DRONE_EYE_BREAK_FX );

#precache( "client_fx", SENTINEL_DRONE_ENGINE_FX );
#precache( "client_fx", SENTINEL_DRONE_ENGINE_ROLL_FX );

//Models
#precache( "client_fx", SENTINEL_DRONE_FACE_MODEL );
#precache( "client_fx", SENTINEL_DRONE_ARM_MODEL );
#precache( "client_fx", SENTINEL_DRONE_CLAW_MODEL );


REGISTER_SYSTEM( "sentinel_drone", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "sentinel_drone_beam_set_target_id", VERSION_DLC3, 5, "int", &sentinel_drone_beam_set_target_id, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	clientfield::register( "vehicle", "sentinel_drone_beam_set_source_to_target", VERSION_DLC3, 5, "int", &sentinel_drone_beam_set_source_to_target, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "toplayer", "sentinel_drone_damage_player_fx", VERSION_DLC3, 1, "counter", &sentinel_drone_damage_player_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_beam_fire1", VERSION_DLC3, 1, "int", &sentinel_drone_beam_fire1, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "sentinel_drone_beam_fire2", VERSION_DLC3, 1, "int", &sentinel_drone_beam_fire2, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "sentinel_drone_beam_fire3", VERSION_DLC3, 1, "int", &sentinel_drone_beam_fire3, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_1", VERSION_DLC3, 1, "int", &sentinel_drone_arm_cut_1, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_2", VERSION_DLC3, 1, "int", &sentinel_drone_arm_cut_2, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "sentinel_drone_arm_cut_3", VERSION_DLC3, 1, "int", &sentinel_drone_arm_cut_3, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_face_cut", VERSION_DLC3, 1, "int", &sentinel_drone_face_cut, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_beam_charge", VERSION_DLC3, 1, "int", &sentinel_drone_beam_charge, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_camera_scanner", VERSION_DLC3, 1, "int", &sentinel_drone_camera_scanner, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", "sentinel_drone_camera_destroyed", VERSION_DLC3, 1, "int", &sentinel_drone_camera_destroyed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "scriptmover", "sentinel_drone_deathfx", VERSION_SHIP, 1, "int", &sentinel_drone_deathfx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	
	level._sentinel_Enemy_Detected_Taunts = [];
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_0");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_1");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_2");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_3");
	ARRAY_ADD(level._sentinel_Enemy_Detected_Taunts, "vox_valk_valkyrie_detected_4");
	
	level._sentinel_Attack_Taunts = [];
	ARRAY_ADD(level._sentinel_Attack_Taunts, "vox_valk_valkyrie_attack_0");
	ARRAY_ADD(level._sentinel_Attack_Taunts, "vox_valk_valkyrie_attack_1");
	ARRAY_ADD(level._sentinel_Attack_Taunts, "vox_valk_valkyrie_attack_2");
	ARRAY_ADD(level._sentinel_Attack_Taunts, "vox_valk_valkyrie_attack_3");
	ARRAY_ADD(level._sentinel_Attack_Taunts, "vox_valk_valkyrie_attack_4");
}

function sentinel_is_drone_initialized( localClientNum, b_check_for_target_existance_only )
{
	if(!IS_TRUE(b_check_for_target_existance_only) )
	{
		if( !IS_TRUE(self.init) )
		{
			return false;
		}
		
		if( (!self HasDObj( localClientNum )) )
		{
			return false;
		}
		
		return true;
	}
	else
	{
		source_num = self GetEntityNumber();
		
		if( isdefined(level.sentinel_drone_source_to_target) && isdefined(level.sentinel_drone_source_to_target[source_num]) && isdefined(level.sentinel_drone_target_id) && isdefined(level.sentinel_drone_target_id[level.sentinel_drone_source_to_target[source_num]]) )
		{
			return true;
		}
		
		return false;
	}
}

function sentinel_drone_damage_player_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	localPlayer = GetLocalPlayer( localClientNum );
	
	if(isdefined(localPlayer))
	{
		localPlayer thread postfx::PlayPostfxBundle( SENTINEL_DRONE_PLAYER_DAMAGE_FX );
	}
}

function sentinel_drone_deathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
	settings = struct::get_script_bundle( "vehiclecustomsettings", "sentinel_drone_settings" );
	
	if( isdefined( settings ) )
	{
		if( newVal )
		{
			handle = PlayFX( localClientNum, settings.drone_secondary_death_fx_1, self.origin );
			SetFXIgnorePause( localClientNum, handle, true );
			
			//Turn off the beam target FX
			if(isdefined(self.beam_target_fx) && isdefined(self.beam_target_fx[localClientNum]))
			{
				StopFX(localClientNum, self.beam_target_fx[localClientNum]);
				self.beam_target_fx[localClientNum] = undefined;
			}
		}
	}
}

function sentinel_drone_camera_scanner( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	if(newVal == 1)
	{
		if(!isdefined(self.CameraScannerFX) && !IS_TRUE(self.CameraDestroyed) )
		{
			self.CameraScannerFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_SCANNER_LIGHT_FX, self, SENTINEL_DRONE_CAMERA_FX_TAG);
		}
		
		//Turn on the engine roll FX
		sentinel_play_engine_fx( localclientnum, false, true );
	}
	else
	{
		//Turn off the scanner light
		/#
			keep_scanner_on = GetDvarInt("sentinel_DebugFX_KeepScannerOn", 0);
		#/
			
		if( isdefined(self.CameraScannerFX) && !IS_TRUE(keep_scanner_on))
		{
			StopFX(localClientNum, self.CameraScannerFX);
			self.CameraScannerFX = undefined;
		}
		
		//Turn off the engine roll FX
		sentinel_play_engine_fx( localclientnum, true, false );
	}
}

function sentinel_drone_camera_destroyed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.CameraDestroyed = true;
	
	if( isdefined(self.CameraScannerFX) )
	{
		StopFX(localClientNum, self.CameraScannerFX);
		self.CameraScannerFX = undefined;
	}
	
	if(isdefined(self.CameraAmbientFX))
	{
		StopFX(localClientNum, self.CameraAmbientFX);
		self.CameraAmbientFX = undefined;
	}
}

function sentinel_drone_beam_fire1( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_beam_fire(localClientNum, newVal, SENTINEL_DRONE_CLAW_RIGHT_FX_TAG);
}

function sentinel_drone_beam_fire2( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_beam_fire(localClientNum, newVal, SENTINEL_DRONE_CLAW_LEFT_FX_TAG);
}

function sentinel_drone_beam_fire3( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_beam_fire(localClientNum, newVal, SENTINEL_DRONE_CLAW_TOP_FX_TAG);
}

function sentinel_drone_beam_fire(localClientNum, newVal, tag_id)
{
	if(sentinel_is_drone_initialized(localClientNum, newVal == 0))
	{
		source_num = self GetEntityNumber();
		beam_target = level.sentinel_drone_target_id[level.sentinel_drone_source_to_target[source_num]];
	}
	else
	{
		return;
	}
		
	if(newVal == 1)
	{
		level beam::launch( self, tag_id, beam_target, "tag_origin", SENTINEL_DRONE_BEAM );
		
		self playsound(0, "zmb_sentinel_attack_short" );
		
		//Turn on the beam target FX
		if(!isdefined(beam_target.beam_target_fx))
		{
			beam_target.beam_target_fx = [];
		}
		
		if(!isdefined(beam_target.beam_target_fx[localClientNum]))
		{
			beam_target.beam_target_fx[localClientNum] = PlayFXOnTag( localClientNum, SENTINEL_DRONE_BEAM_TARGET_FX, beam_target, "tag_origin" );
		}
		
		//Turn off the scanner light
		/#
			keep_scanner_on = GetDvarInt("sentinel_DebugFX_KeepScannerOn", 0);
		#/
			
		if( isdefined(self.CameraScannerFX) && !IS_TRUE(keep_scanner_on))
		{
			StopFX(localClientNum, self.CameraScannerFX);
			self.CameraScannerFX = undefined;
		}
	}
	else
	{
		level beam::kill( self, tag_id, beam_target, "tag_origin", SENTINEL_DRONE_BEAM );
		
		//Turn off the beam target FX
		if(isdefined(beam_target.beam_target_fx) && isdefined(beam_target.beam_target_fx[localClientNum]))
		{
			StopFX(localClientNum, beam_target.beam_target_fx[localClientNum]);
			beam_target.beam_target_fx[localClientNum] = undefined;
		}
		
		//Turn on the claws ambient FX
		self sentinel_play_claws_ambient_fx(localclientnum);
	}
}
	
function sentinel_drone_beam_set_target_id( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(!isdefined(level.sentinel_drone_target_id))
	{
		level.sentinel_drone_target_id = [];
	}
	
	level.sentinel_drone_target_id[ newVal ] = self;
}

function sentinel_drone_beam_set_source_to_target( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(!isdefined(level.sentinel_drone_source_to_target))
	{
		level.sentinel_drone_source_to_target = [];
	}
	
	source_num = self GetEntityNumber();
	level.sentinel_drone_source_to_target[source_num] = newVal;
	
	self.init = true;
	
	//Turn on the claws ambient FX
	self sentinel_play_claws_ambient_fx(localclientnum);
	
	//Set Camera Ambient FX
	self.CameraAmbientFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_CAMERA_AMBIENT_FX, self, SENTINEL_DRONE_CAMERA_FX_TAG);
	
	//Scanner light
	self.CameraScannerFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_SCANNER_LIGHT_FX, self, SENTINEL_DRONE_CAMERA_FX_TAG);
	
	//Turn on the engine FX
	sentinel_play_engine_fx( localclientnum, true, false );
	
	//Play the antenna twitch animation
	self UseAnimTree( #animtree );
	self SetAnim("ai_zm_dlc3_sentinel_antenna_twitch");
}

function sentinel_drone_arm_cut_1( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_arm_cut( localClientNum, SENTINEL_DRONE_ARM_RIGHT );
}

function sentinel_drone_arm_cut_2( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_arm_cut( localClientNum, SENTINEL_DRONE_ARM_LEFT );
}

function sentinel_drone_arm_cut_3( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	sentinel_drone_arm_cut( localClientNum, SENTINEL_DRONE_ARM_TOP );
}

function sentinel_spawn_broken_arm( localClientNum, arm, arm_tag, claw_tag )
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	velocity = self GetVelocity();
	velocity_normal = VectorNormalize(velocity);
	velocity_length = Length(velocity);
	
	if( arm == SENTINEL_DRONE_ARM_TOP )
	{
		launch_dir = AnglesToForward( self.angles) * -1;
		launch_dir = launch_dir + ( 0, 0, 1);
		launch_dir = VectorNormalize( launch_dir );
	}
	else if( arm == SENTINEL_DRONE_ARM_RIGHT )
	{
		launch_dir = AnglesToRight( self.angles);
	}
	else
	{
		launch_dir = AnglesToRight( self.angles) * -1;
	}
	
	velocity_length = velocity_length * 0.1;
	
	if(velocity_length < 10)
	{
		velocity_length = 10;
	}
	
	launch_dir = launch_dir * 0.5 + velocity_normal * 0.5;
	launch_dir = launch_dir * velocity_length;
	
	claw_pos = self GetTagOrigin( claw_tag ) + launch_dir * 3;
	claw_ang = self GetTagAngles( claw_tag );
	thread sentinel_launch_piece( localClientNum, SENTINEL_DRONE_CLAW_MODEL, claw_pos, claw_ang, self.origin, launch_dir * 1.3 );
	
	arm_pos = self GetTagOrigin( arm_tag ) + launch_dir * 2;
	arm_ang = self GetTagAngles( arm_tag );
	thread sentinel_launch_piece( localClientNum, SENTINEL_DRONE_ARM_MODEL, arm_pos, arm_ang, self.origin, launch_dir );
}

function sentinel_drone_arm_cut( localClientNum, arm )
{
	if( arm == SENTINEL_DRONE_ARM_RIGHT)
	{
		if(!IS_TRUE(self.rightArmLost))
		{
			//Spawn Dynant
			sentinel_spawn_broken_arm( localClientNum, SENTINEL_DRONE_ARM_RIGHT, SENTINEL_DRONE_ARM_RIGHT_FX_TAG, SENTINEL_DRONE_CLAW_RIGHT_FX_TAG);
				
			//Stop Ambient, Charging and Beam effects
			
			self.rightArmLost = true;
			sentinel_drone_beam_fire(localClientNum, 0, SENTINEL_DRONE_CLAW_RIGHT_FX_TAG);
			
			if(isdefined(self.rightClawAmbientFX))
			{
				StopFX(localClientNum, self.rightClawAmbientFX);
				self.rightClawAmbientFX = undefined;
			}
			
			if(isdefined(self.rightClawChargeFX))
			{
				StopFX(localClientNum, self.rightClawChargeFX);
				self.rightClawChargeFX = undefined;
			}
			
			if(sentinel_is_drone_initialized(localClientNum))
			{
				//Play Break Effect
				PlayFXOnTag( localClientNum, SENTINEL_DRONE_ARM_BREAK_FX, self, SENTINEL_DRONE_ARM_RIGHT_FX_TAG );
				
				//Play Twitch Animation
				self SetAnim("ai_zm_dlc3_sentinel_arms_broken_right");
			}
		}
	}
	else if ( arm == SENTINEL_DRONE_ARM_LEFT)
	{
		if(!IS_TRUE(self.leftArmLost))
		{
			//Spawn Dynant
			sentinel_spawn_broken_arm( localClientNum, SENTINEL_DRONE_ARM_LEFT, SENTINEL_DRONE_ARM_LEFT_FX_TAG, SENTINEL_DRONE_CLAW_LEFT_FX_TAG);
			
			//Stop Ambient, Charging and Beam effects
			
			self.leftArmLost = true;
			sentinel_drone_beam_fire(localClientNum, 0, SENTINEL_DRONE_CLAW_LEFT_FX_TAG);
			
			if(isdefined(self.leftClawAmbientFX))
			{
				StopFX(localClientNum, self.leftClawAmbientFX);
				self.leftClawAmbientFX = undefined;
			}
			
			if(isdefined(self.leftClawChargeFX))
			{
				StopFX(localClientNum, self.leftClawChargeFX);
				self.leftClawChargeFX = undefined;
			}
			
			if(sentinel_is_drone_initialized(localClientNum))
			{
				//Play Break Effect
				PlayFXOnTag( localClientNum, SENTINEL_DRONE_ARM_BREAK_FX, self, SENTINEL_DRONE_ARM_LEFT_FX_TAG );
				
				//Play Twitch Animation
				self SetAnim("ai_zm_dlc3_sentinel_arms_broken_left");
			}
		}
	}
	else if ( arm == SENTINEL_DRONE_ARM_TOP)
	{
		if(!IS_TRUE(self.topArmLost))
		{
			//Spawn Dynant
			sentinel_spawn_broken_arm( localClientNum, SENTINEL_DRONE_ARM_TOP, SENTINEL_DRONE_ARM_TOP_FX_TAG, SENTINEL_DRONE_CLAW_TOP_FX_TAG);
			
			//Stop Ambient, Charging and Beam effects
			
			self.topArmLost = true;
			sentinel_drone_beam_fire(localClientNum, 0, SENTINEL_DRONE_CLAW_TOP_FX_TAG);
			
			if(isdefined(self.topClawAmbientFX))
			{
				StopFX(localClientNum, self.topClawAmbientFX);
				self.topClawAmbientFX = undefined;
			}
			
			if(isdefined(self.topClawChargeFX))
			{
				StopFX(localClientNum, self.topClawChargeFX);
				self.topClawChargeFX = undefined;
			}
			
			if(sentinel_is_drone_initialized(localClientNum))
			{
				//Play Break Effect
				PlayFXOnTag( localClientNum, SENTINEL_DRONE_ARM_BREAK_FX, self, SENTINEL_DRONE_ARM_TOP_FX_TAG );
				
				//Play Twitch Animation
				self SetAnim("ai_zm_dlc3_sentinel_arms_broken_top");
			}
		}
	}
}

function sentinel_drone_beam_charge( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	if(newVal == 1)
	{
		//Scanner light
		if(!isdefined(self.CameraScannerFX))
		{
			self.CameraScannerFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_SCANNER_LIGHT_FX, self, SENTINEL_DRONE_CAMERA_FX_TAG);
		}
		
		//Turn off the claws ambient FX
		self sentinel_play_claws_ambient_fx(localclientnum, true);
		
		if(!IS_TRUE(self.rightArmLost))
		{
			self.rightClawChargeFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_CHARGING_FX, self, SENTINEL_DRONE_CLAW_RIGHT_FX_TAG);
		}
		
		if(!IS_TRUE(self.leftArmLost))
		{
			self.leftClawChargeFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_CHARGING_FX, self, SENTINEL_DRONE_CLAW_LEFT_FX_TAG);
		}
		
		if(!IS_TRUE(self.topArmLost))
		{
			self.topClawChargeFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_CHARGING_FX, self, SENTINEL_DRONE_CLAW_TOP_FX_TAG);
		}
		
		if( isdefined(self.enemy_already_spotted) )
		{
			if( RandomInt(100) < 30 )
			{
				sentinel_play_taunt( localClientNum, level._sentinel_Attack_Taunts);
			}
		}
		else
		{
			self.enemy_already_spotted = true;
			sentinel_play_taunt( localClientNum, level._sentinel_Enemy_Detected_Taunts);
		}
	}
	else
	{
		if(isdefined(self.rightClawChargeFX))
		{
			StopFX(localClientNum, self.rightClawChargeFX);
			self.rightClawChargeFX = undefined;
		}
		
		if(isdefined(self.leftClawChargeFX))
		{
			StopFX(localClientNum, self.leftClawChargeFX);
			self.leftClawChargeFX = undefined;
		}
		
		if(isdefined(self.topClawChargeFX))
		{
			StopFX(localClientNum, self.topClawChargeFX);
			self.topClawChargeFX = undefined;
		}
	}
}

function sentinel_drone_face_cut( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	face_pos = self GetTagOrigin( SENTINEL_DRONE_FACE_TAG );
	face_ang = self GetTagAngles( SENTINEL_DRONE_FACE_TAG );
	velocity = self GetVelocity();
	
	velocity_normal = VectorNormalize(velocity);
	velocity_length = Length(velocity);
	
	launch_dir = AnglesToForward( self.angles);
	
	velocity_length = velocity_length * 0.1;
	
	if(velocity_length < 10)
	{
		velocity_length = 10;
	}
	
	launch_dir = launch_dir * 0.5 + velocity_normal * 0.5;
	launch_dir = launch_dir * velocity_length;
	
	thread sentinel_launch_piece( localClientNum, SENTINEL_DRONE_FACE_MODEL, face_pos, face_ang, self.origin, launch_dir );
	
	PlayFXOnTag( localClientNum, SENTINEL_DRONE_FACE_BREAK_FX, self, SENTINEL_DRONE_FACE_TAG );
	
	PlayFXOnTag( localClientNum, SENTINEL_DRONE_CORE_GLOW_FX, self, SENTINEL_DRONE_CORE_TAG );
}

function sentinel_play_claws_ambient_fx( localClientNum, b_false )
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	if(!IS_TRUE(b_false))
	{
		if(!IS_TRUE(self.rightArmLost) && !isdefined(self.rightClawAmbientFX) )
		{
			self.rightClawAmbientFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_AMBIENT_FX, self, SENTINEL_DRONE_CLAW_RIGHT_FX_TAG);
		}
		
		if(!IS_TRUE(self.leftArmLost) && !isdefined(self.leftClawAmbientFX) )
		{
			self.leftClawAmbientFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_AMBIENT_FX, self, SENTINEL_DRONE_CLAW_LEFT_FX_TAG);
		}
		
		if(!IS_TRUE(self.topArmLost) && !isdefined(self.topClawAmbientFX) )
		{
			self.topClawAmbientFX = PlayFXOnTag(localClientNum, SENTINEL_DRONE_CLAWS_AMBIENT_FX, self, SENTINEL_DRONE_CLAW_TOP_FX_TAG);
		}
	}
	else
	{
		if( isdefined(self.rightClawAmbientFX) )
		{
			StopFX(localClientNum, self.rightClawAmbientFX);
			self.rightClawAmbientFX = undefined;
		}
		
		if( isdefined(self.leftClawAmbientFX) )
		{
			StopFX(localClientNum, self.leftClawAmbientFX);
			self.leftClawAmbientFX = undefined;
		}
		
		if( isdefined(self.topClawAmbientFX) )
		{
			StopFX(localClientNum, self.topClawAmbientFX);
			self.topClawAmbientFX = undefined;
		}
	}
}

function sentinel_play_engine_fx( localClientNum, b_engine, b_roll_engine)
{
	if(!sentinel_is_drone_initialized(localClientNum))
	{
		return false;
	}
	
	//Turn on the engine FX
	if( IS_TRUE(b_engine) )
	{
		self.EngineFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_ENGINE_FX, self, SENTINEL_DRONE_ENGINE_FX_TAG);
	}
	else if( isdefined(self.EngineFX) )
	{
		StopFX(localclientnum,self.EngineFX);
	}
	
	//Turn on the engine Roll FX
	//Turn on the engine FX
	if( IS_TRUE(b_roll_engine) )
	{
		self.EngineRollFX = PlayFXOnTag(localclientnum, SENTINEL_DRONE_ENGINE_ROLL_FX, self, SENTINEL_DRONE_ENGINE_FX_TAG);
	}
	else if( isdefined(self.EngineRollFX) )
	{
		StopFX(localclientnum,self.EngineRollFX);
	}
}

function sentinel_play_taunt( localClientNum, taunt_Arr )
{
	if ( isdefined( level._lastplayed_drone_taunt ) && ( GetTime() - level._lastplayed_drone_taunt ) < 6000 )
	{
		return;
	}
	
	if( IS_TRUE( level.voxAIdeactivate ) )
	{
		return;
	}
	
	taunt = RandomInt(taunt_Arr.size);
	
	level._lastplayed_drone_taunt = GetTime();
	self PlaySound( localClientNum, taunt_Arr[taunt]);
}

function sentinel_launch_piece( localClientNum, model, pos, angles, hitPos, force)
{
	dynEnt = CreateDynEntAndLaunch( localClientNum, model, pos, angles, hitPos, force );
	
	if(!isdefined(dynEnt))
	{
		return;
	}
	
	posHeight = pos[2];

	wait 0.5;
	
	if( !isdefined(dynEnt) || !IsDynEntValid(dynEnt) )
	{
		return false;
	}
	
	if( dynEnt.origin == pos )
	{	
		SetDynEntEnabled(dynEnt, false);
		return;
	}
	
	pos = dynEnt.origin;
	
	wait 0.4;
	
	if( !isdefined(dynEnt) || !IsDynEntValid(dynEnt) )
	{
		return false;
	}
	
	if( dynEnt.origin == pos )
	{
		SetDynEntEnabled(dynEnt, false);
		return;
	}
	
	wait 1;
	
	if( !isdefined(dynEnt) || !IsDynEntValid(dynEnt) )
	{
		return false;
	}
	
	count = 0;
	old_pos = dynEnt.origin;
	
	while( isdefined(dynEnt) && IsDynEntValid(dynEnt) )
	{
		if( old_pos ==  dynEnt.origin)
		{
			old_pos = dynEnt.origin;
			count++;
			
			if(count == 5)
			{
				if( posHeight - dynEnt.origin[2] < 15)
				{
					SetDynEntEnabled(dynEnt, false);
				}
				else
				{
					break;
				}
			}
		}
		else
		{
			count = 0;
		}
		
		wait 0.2;
	}
}