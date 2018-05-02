#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\postfx_shared;


#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\raz.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", RAZ_FOOTSTEP_FX_FILE );
#precache( "client_fx", RAZ_TORPEDO_EXPLOSION_FX_FILE );
#precache( "client_fx", RAZ_TORPEDO_TRAIL_FX_FILE );
#precache( "client_fx", RAZ_GUN_DETACH_FX_FILE );
#precache( "client_fx", RAZ_GUN_ONGOING_DAMAGE_FX_FILE );
#precache( "client_fx", RAZ_GUN_WEAKPOINT_HIT_FX_FILE );
#precache( "client_fx", RAZ_TORPEDO_SELF_FX_FILE );
#precache( "client_fx", RAZ_ARMOR_DETACH_FX_FILE );


#using_animtree( "generic" );

function autoexec main()
{
	clientfield::register( "scriptmover", RAZ_TORPEDO_DETONATION_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razDetonateGroundTorpedo, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", RAZ_TORPEDO_SELF_FX_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razPlaySelfFX, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", RAZ_TORPEDO_TRAIL_CLIENTFIELD, VERSION_DLC3, 1, "counter", &RazClientUtils::razTorpedoPlayTrailFX, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_GUN_DETACH_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razDetachGunFX, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_GUN_WEAKPOINT_HIT_CLIENTFIELD, VERSION_DLC3, 1, "counter", &RazClientUtils::razGunWeakpointHitFX, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_DETACH_HELMET_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razHelmetDetach, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_DETACH_CHEST_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razChestArmorDetach, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_DETACH_L_SHOULDER_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razLeftShoulderArmorDetach, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_DETACH_R_THIGH_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razRightThighArmorDetach, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", RAZ_DETACH_L_THIGH_ARMOR_CLIENTFIELD, VERSION_DLC3, 1, "int", &RazClientUtils::razLeftThighArmorDetach, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	ai::add_archetype_spawn_function( ARCHETYPE_RAZ, &RazClientUtils::razSpawn );

}

function autoexec precache()
{
	level._effect[ RAZ_FOOTSTEP_FX ]				= RAZ_FOOTSTEP_FX_FILE;
	level._effect[ RAZ_TORPEDO_EXPLOSION_FX ]		= RAZ_TORPEDO_EXPLOSION_FX_FILE;
	level._effect[ RAZ_TORPEDO_TRAIL_FX ]			= RAZ_TORPEDO_TRAIL_FX_FILE;
	level._effect[ RAZ_TORPEDO_SELF_FX ]			= RAZ_TORPEDO_SELF_FX_FILE;
	level._effect[ RAZ_GUN_DETACH_FX ]				= RAZ_GUN_DETACH_FX_FILE;
	level._effect[ RAZ_GUN_ONGOING_DAMAGE_FX ]		= RAZ_GUN_ONGOING_DAMAGE_FX_FILE;
	level._effect[ RAZ_GUN_WEAKPOINT_HIT_FX ]		= RAZ_GUN_WEAKPOINT_HIT_FX_FILE;
	level._effect[ RAZ_ARMOR_DETACH_FX ]			= RAZ_ARMOR_DETACH_FX_FILE;
	
	level._raz_taunts = [];
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_0");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_1");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_2");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_3");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_4");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_5");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_6");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_7");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_8");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_9");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_10");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_11");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_12");
	ARRAY_ADD(level._raz_taunts, "vox_mang_mangler_taunt_13");
}

#namespace RazClientUtils;

function private razSpawn( localClientNum )
{
	level._footstepCBFuncs[self.archetype] = &razProcessFootstep;
	
	self thread razPlayFireEmissiveShader( localClientNum );
	self thread razPlayRoarSound( localClientNum );
	self thread razPlayTaunts( localClientNum );
}

function private razPlayFireEmissiveShader( localClientNum )
{
	self endon("death");
	
	while( isdefined(self) )
	{
		self waittill("lights_on");
		self MapShaderConstant( localClientNum, 0, "scriptVector3", 0, 1, 1);
		
		self waittill("lights_off");
		self MapShaderConstant( localClientNum, 0, "scriptVector3", 0, 0, 0);
	}
}

function private razPlayRoarSound( localClientNum )
{
	self endon("death");
	
	while( isdefined(self) )
	{
		self waittill("roar");
		self PlaySound(localClientNum,"vox_raz_exert_enrage",self GetTagOrigin( "tag_eye" ));
	}
	
}

function private razPlayTaunts( localClientNum )
{
	self endon("death_start");
	
	self thread razStopTauntsOnDeath( localClientNum );
	
	while( isdefined(self) )
	{
		taunt_wait = RandomIntRange(5, 12);
		wait taunt_wait;
		
		if( IS_TRUE( level.voxAIdeactivate ) )
		{
			continue;
		}
		
		else if(isdefined(self))
		{
			taunt_alias = level._raz_taunts[RandomInt(level._raz_taunts.size)];
			self.taunt_id = self PlaySound(localClientNum, taunt_alias,self GetTagOrigin( "tag_eye" ));
		}
	}
}

function private razStopTauntsOnDeath( localClientNum )
{
	self waittill("death_start");

	if( isdefined(self.taunt_id) )
	{
		StopSound( self.taunt_id );
	}
}

function razProcessFootstep( localClientNum, pos, surface, notetrack, bone )
{
	e_player = GetLocalPlayer( localClientNum );
	n_dist = DistanceSquared( pos, e_player.origin );
	n_raz_dist = ( RAZ_FOOTSTEP_EARTHQUAKE_MAX_RADIUS * RAZ_FOOTSTEP_EARTHQUAKE_MAX_RADIUS );
	if(n_raz_dist > 0)
		n_scale = ( n_raz_dist - n_dist ) / n_raz_dist;
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
		e_player PlayRumbleOnEntity( localClientNum, "damage_heavy" );
	}
	
	else if( n_scale <= 0.8 && n_scale > 0.4 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "damage_light" );
	}
	else
	{
		e_player PlayRumbleOnEntity( localClientNum, "reload_small" );
	}
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_FOOTSTEP_FX ], self, bone );
}

function private razDetonateGroundTorpedo( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	fx = PlayFX( localClientNum, level._effect[ RAZ_TORPEDO_EXPLOSION_FX ], self.origin );
}

function private razTorpedoPlayTrailFX( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	fx = PlayFX( localClientNum, level._effect[ RAZ_TORPEDO_TRAIL_FX ], self.origin );
}

function private razPlaySelfFX( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if( newValue == 0 && isDefined( self.raz_torpedo_self_fx ) )
	{
		stopFX( localClientNum, self.raz_torpedo_self_fx );
		self.raz_torpedo_self_fx = undefined;
	}
	if( newValue == 1 && !isDefined( self.raz_torpedo_self_fx ) )
	{
		self.raz_torpedo_self_fx = playFXOnTag( localClientNum, level._effect[ RAZ_TORPEDO_SELF_FX ], self, RAZ_TORPEDO_SELF_FX_TAG );
	}
}

function private razCreateDynEntAndLaunch( localClientNum, model, pos, angles, hitpos, vel_factor = 1, direction )
{
	if( !isdefined(pos) || !isdefined(angles) )
	{
		return;
	}
	
	velocity = self GetVelocity();
	
	velocity_normal = VectorNormalize(velocity);
	velocity_length = Length(velocity);
	
	if( isdefined(direction) && direction == "back" )
	{
		launch_dir = AnglesToForward( self.angles) * -1;
	}
	else
	{
		launch_dir = AnglesToForward( self.angles);
	}
	
	velocity_length = velocity_length * 0.1;
	
	if(velocity_length < 10)
	{
		velocity_length = 10;
	}
	
	launch_dir = launch_dir * 0.5 + velocity_normal * 0.5;
	launch_dir = launch_dir * velocity_length;
	
	CreateDynEntAndLaunch( localClientNum, model, pos, angles, self.origin, launch_dir * vel_factor );
}

function private razDetachGunFX( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_GUN_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_CANNON_TAG );
	//self.gun_damage_fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_GUN_ONGOING_DAMAGE_FX ], self, RAZ_GUN_ONGOING_DAMAGE_FX_TAG );
	
	gun_pos = self gettagorigin( RAZ_GUN_DYNENT_LAUNCH_TAG );
	gun_ang = self gettagangles( RAZ_GUN_DYNENT_LAUNCH_TAG );
	gun_core_pos = self gettagorigin( RAZ_GUN_CORE_DYNENT_LAUNCH_TAG );
	gun_core_ang = self gettagangles( RAZ_GUN_CORE_DYNENT_LAUNCH_TAG );
	
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_GUN_MODEL, gun_pos, gun_ang, self.origin, 1.3, "back" );
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_GUN_CORE_MODEL, gun_core_pos, gun_core_ang, self.origin, 1, "back" );
	
	self PlaySound( localClientNum, "zmb_raz_gun_explo", self GetTagOrigin( "tag_eye" ) );
}

function private razGunWeakpointHitFX( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_GUN_WEAKPOINT_HIT_FX ], self, RAZ_GUN_WEAKPOINT_HIT_FX_TAG );
}

function razHelmetDetach( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( RAZ_GUN_DYNENT_LAUNCH_TAG );
	ang = self gettagangles( RAZ_GUN_DYNENT_LAUNCH_TAG );
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_ARMOR_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_HELMET_TAG );		
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_HELMET_MODEL, pos, ang, self.origin, 1, "back" );
	
	thread ApplyNewFaceAnim( localClientNum, "ai_zm_dlc3_face_armored_zombie_generic_idle_1");
	
	self PlaySound( localClientNum, "zmb_raz_armor_explo", self GetTagOrigin( "tag_eye" ) );
}

function razChestArmorDetach( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( RAZ_CHEST_ARMOR_DYNENT_LAUNCH_TAG );
	ang = self gettagangles( RAZ_CHEST_ARMOR_DYNENT_LAUNCH_TAG );
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_ARMOR_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_CHEST_TAG );	
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_CHEST_ARMOR_MODEL, pos, ang, self.origin );
	
	self PlaySound( localClientNum, "zmb_raz_armor_explo", self GetTagOrigin( "tag_eye" ) );
}

function razLeftShoulderArmorDetach( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( RAZ_L_SHOULDER_ARMOR_DYNENT_LAUNCH_TAG );
	ang = self gettagangles( RAZ_L_SHOULDER_ARMOR_DYNENT_LAUNCH_TAG );
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_ARMOR_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_LEFT_SHOULDER_TAG );	
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_L_SHOULDER_ARMOR_MODEL, pos, ang, self.origin );
	
	self PlaySound( localClientNum, "zmb_raz_armor_explo", self GetTagOrigin( "tag_eye" ) );
}

function razLeftThighArmorDetach( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( RAZ_L_THIGH_ARMOR_DYNENT_LAUNCH_TAG );
	ang = self gettagangles( RAZ_L_THIGH_ARMOR_DYNENT_LAUNCH_TAG );
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_ARMOR_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_LEFT_LEG_TAG );
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_L_THIGH_ARMOR_MODEL, pos, ang, self.origin );
	
	self PlaySound( localClientNum, "zmb_raz_armor_explo", self GetTagOrigin( "tag_eye" ) );
}

function razRightThighArmorDetach( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	pos = self gettagorigin( RAZ_R_THIGH_ARMOR_DYNENT_LAUNCH_TAG );
	ang = self gettagangles( RAZ_R_THIGH_ARMOR_DYNENT_LAUNCH_TAG );
	
	fx = PlayFXOnTag( localClientNum, level._effect[ RAZ_ARMOR_DETACH_FX ], self, RAZ_ARMOR_DETACH_FX_RIGHT_LEG_TAG );
	dynent = razCreateDynEntAndLaunch( localClientNum, RAZ_R_THIGH_ARMOR_MODEL, pos, ang, self.origin );
	
	self PlaySound( localClientNum, "zmb_raz_armor_explo", self GetTagOrigin( "tag_eye" ) );
}


//----------Facial animation for Raz

function private ApplyNewFaceAnim( localClientNum, animation)
{
	self endon("disconnect");
	
	ClearCurrentFacialAnim(localClientNum);
	
	if( isdefined( animation ) )
	{
		self._currentFaceAnim = animation;
		
		if( self HasDObj(localClientNum) && self HasAnimTree() )
		{
			self SetFlaggedAnimKnob( "ai_secondary_facial_anim", animation, 1.0, 0.1, 1.0 );
		
			self waittill( "death_start" );
			
			ClearCurrentFacialAnim(localClientNum);
		}
	}
}

function private ClearCurrentFacialAnim(localClientNum)
{
	if( isdefined( self._currentFaceAnim ) && self HasDObj(localClientNum) && self HasAnimTree() )
	{
		self ClearAnim( self._currentFaceAnim, 0.2 );
	}
	
	self._currentFaceAnim = undefined;
}
