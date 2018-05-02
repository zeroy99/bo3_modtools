#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\mechz.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", MECHZ_FT_FX_FILE );
#precache( "client_fx", MECHZ_FACEPLATE_OFF_FX_FILE );
#precache( "client_fx", MECHZ_POWERCAP_OFF_FX_FILE );
#precache( "client_fx", MECHZ_CLAW_OFF_FX_FILE );
#precache( "client_fx", MECHZ_115_GUN_MUZZLE_FLASH_FX_FILE );
#precache( "client_fx", MECHZ_RKNEE_ARMOR_OFF_FX_FILE );
#precache( "client_fx", MECHZ_LKNEE_ARMOR_OFF_FX_FILE );
#precache( "client_fx", MECHZ_RSHOULDER_AMOR_OFF_FX_FILE );
#precache( "client_fx", MECHZ_LSHOULDER_AMOR_OFF_FX_FILE );
#precache( "client_fx", MECHZ_HEADLIGHT_FX_FILE );
#precache( "client_fx", MECHZ_ARMOR_OFF_SPARKS_FX_FILE );
#precache( "client_fx", MECHZ_GUN_OFF_SPARKS_FX_FILE );
#precache( "client_fx", MECHZ_FOOTSTEP_FX_FILE );
#precache( "client_fx", MECHZ_HEADLAMP_DESTROYED_FX_FILE );
#precache( "client_fx", MECHZ_FOOTSTEP_STEAM_FX_FILE );
#precache( "client_fx", MECHZ_KNEE_ARMOR_OFF_SPARKS_FX_FILE );
#precache( "client_fx", MECHZ_POWERCORE_FX_FILE );

function autoexec main()
{
	clientfield::register( "actor", MECHZ_FT_CLIENTFIELD, VERSION_DLC1, 1, "int", &MechzClientUtils::mechzFlamethrowerCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_faceplate_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_faceplate, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_powercap_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_powercap, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_claw_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_claw, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_115_gun_firing", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_115_gun_muzzle_flash, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_rknee_armor_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_rknee_armor, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_lknee_armor_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_lknee_armor, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_rshoulder_armor_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_rshoulder_armor, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_lshoulder_armor_detached", VERSION_DLC1, 1, "int", &MechzClientUtils::mechz_detach_lshoulder_armor, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "mechz_headlamp_off", VERSION_DLC1, 2, "int", &MechzClientUtils::mechz_headlamp_off, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "actor", MECHZ_FACE_CLIENTFIELD, VERSION_SHIP, 3, "int", &MechzClientUtils::mechzFaceCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	ai::add_archetype_spawn_function( ARCHETYPE_MECHZ, &MechzClientUtils::mechzSpawn );

	level._mechz_face = [];
	level._mechz_face[ MECHZ_FACE_ATTACK ] = "ai_face_zombie_generic_attack_1";
	level._mechz_face[ MECHZ_FACE_DEATH ] = "ai_face_zombie_generic_death_1";
	level._mechz_face[ MECHZ_FACE_IDLE ] = "ai_face_zombie_generic_idle_1";
	level._mechz_face[ MECHZ_FACE_PAIN ] = "ai_face_zombie_generic_pain_1";
}

function autoexec precache()
{
	level._effect[ MECHZ_FT_FX ] 					= MECHZ_FT_FX_FILE;
	level._effect[ MECHZ_FACEPLATE_OFF_FX ]			= MECHZ_FACEPLATE_OFF_FX_FILE;
	level._effect[ MECHZ_POWERCAP_OFF_FX ]			= MECHZ_POWERCAP_OFF_FX_FILE;
	level._effect[ MECHZ_CLAW_OFF_FX ] 				= MECHZ_CLAW_OFF_FX_FILE;
	level._effect[ MECHZ_115_GUN_MUZZLE_FLASH_FX ]	= MECHZ_115_GUN_MUZZLE_FLASH_FX_FILE;
	level._effect[ MECHZ_RKNEE_ARMOR_OFF_FX ]		= MECHZ_RKNEE_ARMOR_OFF_FX_FILE;
	level._effect[ MECHZ_LKNEE_ARMOR_OFF_FX ]		= MECHZ_LKNEE_ARMOR_OFF_FX_FILE;
	level._effect[ MECHZ_RSHOULDER_AMOR_OFF_FX ]	= MECHZ_RSHOULDER_AMOR_OFF_FX_FILE;
	level._effect[ MECHZ_LSHOULDER_AMOR_OFF_FX ]	= MECHZ_LSHOULDER_AMOR_OFF_FX_FILE;
	level._effect[ MECHZ_HEADLIGHT_FX ]				= MECHZ_HEADLIGHT_FX_FILE;
	level._effect[ MECHZ_ARMOR_OFF_SPARKS_FX ]		= MECHZ_ARMOR_OFF_SPARKS_FX_FILE;
	level._effect[ MECHZ_KNEE_ARMOR_OFF_SPARKS_FX ]	= MECHZ_KNEE_ARMOR_OFF_SPARKS_FX_FILE;
	level._effect[ MECHZ_GUN_OFF_SPARKS_FX ]		= MECHZ_GUN_OFF_SPARKS_FX_FILE;
	level._effect[ MECHZ_FOOTSTEP_FX ]				= MECHZ_FOOTSTEP_FX_FILE;
	level._effect[ MECHZ_HEADLAMP_DESTROYED_FX ]	= MECHZ_HEADLAMP_DESTROYED_FX_FILE;
	level._effect[ MECHZ_FOOTSTEP_STEAM_FX ]		= MECHZ_FOOTSTEP_STEAM_FX_FILE;
	level._effect[ MECHZ_POWERCORE_FX ]				= MECHZ_POWERCORE_FX_FILE;
}

#namespace MechzClientUtils;

function private mechzSpawn( localClientNum )
{
	level._footstepCBFuncs[ self.archetype ] = &mechzProcessFootstep;
	// setting sound context with wait to ensure the entity is fully spawned  
	level thread mechzSndContext( self );
	self.headlight_fx = PlayFXOnTag( localClientNum, level._effect[ MECHZ_HEADLIGHT_FX ], self, "tag_headlamp_FX" );
	self.headlamp_on = true;
}

function mechzSndContext ( mechz )
{
	wait 1;
	if ( IsDefined( mechz ) )
	{
		mechz setsoundentcontext("movement", "normal");	
	}
}
	

function mechzProcessFootstep( localClientNum, pos, surface, notetrack, bone )
{
	e_player = GetLocalPlayer( localClientNum );
	n_dist = DistanceSquared( pos, e_player.origin );
	n_mechz_dist = ( MECHZ_FOOTSTEP_EARTHQUAKE_MAX_RADIUS * MECHZ_FOOTSTEP_EARTHQUAKE_MAX_RADIUS );
	if(n_mechz_dist>0)
		n_scale = ( n_mechz_dist - n_dist ) / n_mechz_dist;
	else
		return;
	
	if( n_scale > 1 || n_scale < 0 ) return;
		
	if( n_scale <= 0.01 ) return;
	earthquake_scale = n_scale * 0.1;
	
	if( earthquake_scale > 0.01)
	{
		e_player Earthquake( earthquake_scale, 0.1, pos, n_dist );
	}
	
	if( n_scale <= 1 && n_scale > 0.8 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "shotgun_fire" );
	}
	
	else if( n_scale <= 0.8 && n_scale > 0.4 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "damage_heavy" );
	}
	else
	{
		e_player PlayRumbleOnEntity( localClientNum, "reload_small" );
	}
	
	fx = PlayFXOnTag( localClientNum, level._effect[ MECHZ_FOOTSTEP_FX ], self, bone );
	if( bone == "j_ball_le" )
	{
		steam_bone = "tag_foot_steam_le";
	}
	else
	{
		steam_bone = "tag_foot_steam_ri";
	}
	steam_fx = PlayFXOnTag( localClientNum, level._effect[ MECHZ_FOOTSTEP_STEAM_FX ], self, steam_bone );
}


function private mechzFlamethrowerCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	switch ( newValue )
	{
	case MECHZ_FT_ON:
		self.fire_beam_id = BeamLaunch( localclientnum, self, MECHZ_FT_TAG, undefined, "none", "flamethrower_beam_3p_zm_mechz" );
		self playsound (0 , "wpn_flame_thrower_start_mechz");
		self.sndLoopID = self PlayLoopSound ("wpn_flame_thrower_loop_mechz");
		break;

	case MECHZ_FT_OFF:
		self notify( "stopFlamethrower" );
		if ( IsDefined( self.fire_beam_id ) )
		{
			BeamKill( localclientnum, self.fire_beam_id );				
			self playsound (0 , "wpn_flame_thrower_stop_mechz");
			self stoploopsound ( self.sndLoopID );
		}
		break;
	}
}

function mechz_detach_faceplate( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_FACEPLATE );
	ang = self gettagangles( MECHZ_TAG_FACEPLATE );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_FACEPLATE, pos, ang, self.origin, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_FACEPLATE_OFF_FX ], self, MECHZ_TAG_FACEPLATE );
	self setsoundentcontext("movement", "loud");
	self playsound (0, "zmb_ai_mechz_faceplate");		
}

function mechz_detach_powercap( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_POWERSUPPLY );
	ang = self gettagangles( MECHZ_TAG_POWERSUPPLY );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_POWERSUPPLY, pos, ang, self.origin, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_POWERCAP_OFF_FX ], self, MECHZ_TAG_POWERSUPPLY );
	self playsound (0, "zmb_ai_mechz_destruction");
	self.mechz_powercore_fx = playFXonTag( localClientNum, level._effect[ MECHZ_POWERCORE_FX ], self, MECHZ_TAG_POWERSUPPLY );
}


function mechz_detach_claw( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if( IsDefined( level.mechz_detach_claw_override ) )
	{
		self [[level.mechz_detach_claw_override]]( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump );
		return;
	}
	
	pos = self gettagorigin( MECHZ_TAG_CLAW );
	ang = self gettagangles( MECHZ_TAG_CLAW );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_CLAW, pos, ang, self.origin, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_CLAW_OFF_FX ], self, MECHZ_TAG_CLAW );
	self playsound (0, "zmb_ai_mechz_destruction");
	playFXonTag( localClientNum, level._effect[ MECHZ_GUN_OFF_SPARKS_FX ], self, MECHZ_TAG_CLAW );
}

function mechz_115_gun_muzzle_flash( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	playFXonTag( localClientNum, level._effect[ MECHZ_115_GUN_MUZZLE_FLASH_FX ], self, MECHZ_GRENADE_TAG );
}

function mechz_detach_rknee_armor( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_ARMOR_KNEE_RIGHT );
	ang = self gettagangles( MECHZ_TAG_ARMOR_KNEE_RIGHT );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_ARMOR_KNEE_RIGHT, pos, ang, pos, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_RKNEE_ARMOR_OFF_FX ], self, MECHZ_TAG_ARMOR_KNEE_RIGHT );
	self playsound (0, "zmb_ai_mechz_destruction");	
	playFXonTag( localClientNum, level._effect[ MECHZ_KNEE_ARMOR_OFF_SPARKS_FX ], self, MECHZ_TAG_ARMOR_KNEE_RIGHT );
}

function mechz_detach_lknee_armor( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_ARMOR_KNEE_LEFT );
	ang = self gettagangles( MECHZ_TAG_ARMOR_KNEE_LEFT );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_ARMOR_KNEE_LEFT, pos, ang, pos, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_LKNEE_ARMOR_OFF_FX ], self, MECHZ_TAG_ARMOR_KNEE_LEFT );
	self playsound (0, "zmb_ai_mechz_destruction");	
	playFXonTag( localClientNum, level._effect[ MECHZ_KNEE_ARMOR_OFF_SPARKS_FX ], self, MECHZ_TAG_ARMOR_KNEE_LEFT );
}

function mechz_detach_rshoulder_armor( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_ARMOR_SHOULDER_RIGHT );
	ang = self gettagangles( MECHZ_TAG_ARMOR_SHOULDER_RIGHT );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_ARMOR_SHOULDER_RIGHT, pos, ang, pos, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_RSHOULDER_AMOR_OFF_FX ], self, MECHZ_TAG_ARMOR_SHOULDER_RIGHT );
	self playsound (0, "zmb_ai_mechz_destruction");
	playFXonTag( localClientNum, level._effect[ MECHZ_ARMOR_OFF_SPARKS_FX ], self, MECHZ_TAG_ARMOR_SHOULDER_RIGHT );	
}

function mechz_detach_lshoulder_armor( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( MECHZ_TAG_ARMOR_SHOULDER_LEFT );
	ang = self gettagangles( MECHZ_TAG_ARMOR_SHOULDER_LEFT );
	velocity = self GetVelocity();
	
	dynent = CreateDynEntAndLaunch( localClientNum, MECHZ_MODEL_ARMOR_SHOULDER_LEFT, pos, ang, pos, velocity );
	playFXonTag( localClientNum, level._effect[ MECHZ_LSHOULDER_AMOR_OFF_FX ], self, MECHZ_TAG_ARMOR_SHOULDER_LEFT );
	self playsound (0, "zmb_ai_mechz_destruction");	
	playFXonTag( localClientNum, level._effect[ MECHZ_ARMOR_OFF_SPARKS_FX ], self, MECHZ_TAG_ARMOR_SHOULDER_LEFT );
}

function mechz_headlamp_off( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if( self.headlamp_on === true && newValue != 0  && isDefined( self.headlight_fx ))
	{
		StopFX( localClientNum, self.headlight_fx );
		self.headlamp_on = false;
		
		if( newValue == 2 )
		{
			playFXonTag( localClientNum, level._effect[ MECHZ_FOOTSTEP_FX ], self, "tag_headlamp_fx" );
			//play break fx and sound
		}
	}
}

function private mechzFaceCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		if ( IsDefined( self.prevFaceAnim ) )
		{
			self ClearAnim( self.prevFaceAnim, 0.2 );
		}

		faceAnim = level._mechz_face[ newValue ];
		self SetAnim( faceAnim, 1.0, 0.2, 1.0 );
		self.prevFaceAnim = faceAnim;
	}
}
