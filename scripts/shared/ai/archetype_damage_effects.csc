#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\archetype_damage_effects.gsh;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\shared\clientfield_shared;
#using scripts\shared\array_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\util_shared;
#using scripts\shared\math_shared;

//firebug human torching...
#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_torso_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_torso_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_head_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_head_os" );

#precache( "client_fx", "fire/fx_fire_ai_robot_arm_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_arm_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_robot_arm_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_arm_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_robot_head_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_head_os" );
#precache( "client_fx", "fire/fx_fire_ai_robot_leg_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_leg_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_robot_leg_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_leg_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_robot_torso_loop" );
#precache( "client_fx", "fire/fx_fire_ai_robot_torso_os" );

#precache( "client_fx", "smoke/fx_smk_ai_human_arm_left_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_arm_right_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_head_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_hip_left_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_hip_right_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_leg_left_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_leg_right_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_torso_os" );
#precache( "client_fx", "smoke/fx_smk_ai_human_waist_os" );





function autoexec main()
{
	// clientfield setup
	RegisterClientFields();
	
	//effects caching
	LoadEffects();
}

function RegisterClientFields()
{
	clientfield::register( "actor", "arch_actor_fire_fx", VERSION_SHIP, 2, "int", &actor_fire_fx_state, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "arch_actor_char", VERSION_SHIP, 2, "int", &actor_char, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function LoadEffects()
{
	//fire fx
	level._effect["fire_human_j_elbow_le_loop"]		= "fire/fx_fire_ai_human_arm_left_loop";	// hand and forearm fires
	level._effect["fire_human_j_elbow_ri_loop"]		= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_human_j_shoulder_le_loop"]	= "fire/fx_fire_ai_human_arm_left_loop";	// upper arm fires
	level._effect["fire_human_j_shoulder_ri_loop"]	= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_human_j_spine4_loop"]		= "fire/fx_fire_ai_human_torso_loop";		// upper torso fires
	level._effect["fire_human_j_hip_le_loop"]		= "fire/fx_fire_ai_human_hip_left_loop";	// thigh fires
	level._effect["fire_human_j_hip_ri_loop"]		= "fire/fx_fire_ai_human_hip_right_loop";
	level._effect["fire_human_j_knee_le_loop"]		= "fire/fx_fire_ai_human_leg_left_loop";	// shin fires
	level._effect["fire_human_j_knee_ri_loop"]		= "fire/fx_fire_ai_human_leg_right_loop";
	level._effect["fire_human_j_head_loop"] 		= "fire/fx_fire_ai_human_head_loop";		// head fire
	
	level._effect["fire_human_j_elbow_le_os"]		= "fire/fx_fire_ai_human_arm_left_os";		// hand and forearm fires
	level._effect["fire_human_j_elbow_ri_os"]		= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_human_j_shoulder_le_os"]	= "fire/fx_fire_ai_human_arm_left_os";		// upper arm fires
	level._effect["fire_human_j_shoulder_ri_os"]	= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_human_j_spine4_os"]			= "fire/fx_fire_ai_human_torso_os";		// upper torso fires
	level._effect["fire_human_j_hip_le_os"]			= "fire/fx_fire_ai_human_hip_left_os";		// thigh fire
	level._effect["fire_human_j_hip_ri_os"]			= "fire/fx_fire_ai_human_hip_right_os";
	level._effect["fire_human_j_knee_le_os"]		= "fire/fx_fire_ai_human_leg_left_os";		// shin fires
	level._effect["fire_human_j_knee_ri_os"]		= "fire/fx_fire_ai_human_leg_right_os";
	level._effect["fire_human_j_head_os"] 			= "fire/fx_fire_ai_human_head_os";			// head fire

	level._effect["fire_human_riotshield_j_elbow_le_loop"]		= "fire/fx_fire_ai_human_arm_left_loop";	// hand and forearm fires
	level._effect["fire_human_riotshield_j_elbow_ri_loop"]		= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_human_riotshield_j_shoulder_le_loop"]	= "fire/fx_fire_ai_human_arm_left_loop";	// upper arm fires
	level._effect["fire_human_riotshield_j_shoulder_ri_loop"]	= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_human_riotshield_j_spine4_loop"]		= "fire/fx_fire_ai_human_torso_loop";		// upper torso fires
	level._effect["fire_human_riotshield_j_hip_le_loop"]		= "fire/fx_fire_ai_human_hip_left_loop";	// thigh fires
	level._effect["fire_human_riotshield_j_hip_ri_loop"]		= "fire/fx_fire_ai_human_hip_right_loop";
	level._effect["fire_human_riotshield_j_knee_le_loop"]		= "fire/fx_fire_ai_human_leg_left_loop";	// shin fires
	level._effect["fire_human_riotshield_j_knee_ri_loop"]		= "fire/fx_fire_ai_human_leg_right_loop";
	level._effect["fire_human_riotshield_j_head_loop"] 		= "fire/fx_fire_ai_human_head_loop";		// head fire
	
	level._effect["fire_human_riotshield_j_elbow_le_os"]		= "fire/fx_fire_ai_human_arm_left_os";		// hand and forearm fires
	level._effect["fire_human_riotshield_j_elbow_ri_os"]		= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_human_riotshield_j_shoulder_le_os"]	= "fire/fx_fire_ai_human_arm_left_os";		// upper arm fires
	level._effect["fire_human_riotshield_j_shoulder_ri_os"]	= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_human_riotshield_j_spine4_os"]			= "fire/fx_fire_ai_human_torso_os";		// upper torso fires
	level._effect["fire_human_riotshield_j_hip_le_os"]			= "fire/fx_fire_ai_human_hip_left_os";		// thigh fire
	level._effect["fire_human_riotshield_j_hip_ri_os"]			= "fire/fx_fire_ai_human_hip_right_os";
	level._effect["fire_human_riotshield_j_knee_le_os"]		= "fire/fx_fire_ai_human_leg_left_os";		// shin fires
	level._effect["fire_human_riotshield_j_knee_ri_os"]		= "fire/fx_fire_ai_human_leg_right_os";
	level._effect["fire_human_riotshield_j_head_os"] 			= "fire/fx_fire_ai_human_head_os";			// head fire
	
	//fire fx
	level._effect["fire_warlord_j_elbow_le_loop"]		= "fire/fx_fire_ai_human_arm_left_loop";	// hand and forearm fires
	level._effect["fire_warlord_j_elbow_ri_loop"]		= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_warlord_j_shoulder_le_loop"]	= "fire/fx_fire_ai_human_arm_left_loop";	// upper arm fires
	level._effect["fire_warlord_j_shoulder_ri_loop"]	= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["fire_warlord_j_spine4_loop"]		= "fire/fx_fire_ai_human_torso_loop";		// upper torso fires
	level._effect["fire_warlord_j_hip_le_loop"]		= "fire/fx_fire_ai_human_hip_left_loop";	// thigh fires
	level._effect["fire_warlord_j_hip_ri_loop"]		= "fire/fx_fire_ai_human_hip_right_loop";
	level._effect["fire_warlord_j_knee_le_loop"]		= "fire/fx_fire_ai_human_leg_left_loop";	// shin fires
	level._effect["fire_warlord_j_knee_ri_loop"]		= "fire/fx_fire_ai_human_leg_right_loop";
	level._effect["fire_warlord_j_head_loop"] 		= "fire/fx_fire_ai_human_head_loop";		// head fire
	
	level._effect["fire_warlord_j_elbow_le_os"]		= "fire/fx_fire_ai_human_arm_left_os";		// hand and forearm fires
	level._effect["fire_warlord_j_elbow_ri_os"]		= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_warlord_j_shoulder_le_os"]	= "fire/fx_fire_ai_human_arm_left_os";		// upper arm fires
	level._effect["fire_warlord_j_shoulder_ri_os"]	= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_warlord_j_spine4_os"]			= "fire/fx_fire_ai_human_torso_os";		// upper torso fires
	level._effect["fire_warlord_j_hip_le_os"]			= "fire/fx_fire_ai_human_hip_left_os";		// thigh fire
	level._effect["fire_warlord_j_hip_ri_os"]			= "fire/fx_fire_ai_human_hip_right_os";
	level._effect["fire_warlord_j_knee_le_os"]		= "fire/fx_fire_ai_human_leg_left_os";		// shin fires
	level._effect["fire_warlord_j_knee_ri_os"]		= "fire/fx_fire_ai_human_leg_right_os";
	level._effect["fire_warlord_j_head_os"] 			= "fire/fx_fire_ai_human_head_os";			// head fire

	
	//fire fx
	level._effect["fire_zombie_j_elbow_le_os"]		= "fire/fx_fire_ai_human_arm_left_os";		// hand and forearm fires
	level._effect["fire_zombie_j_elbow_ri_os"]		= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_zombie_j_shoulder_le_os"]	= "fire/fx_fire_ai_human_arm_left_os";		// upper arm fires
	level._effect["fire_zombie_j_shoulder_ri_os"]	= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["fire_zombie_j_spine4_os"]			= "fire/fx_fire_ai_human_torso_os";		// upper torso fires
	level._effect["fire_zombie_j_hip_le_os"]			= "fire/fx_fire_ai_human_hip_left_os";		// thigh fire
	level._effect["fire_zombie_j_hip_ri_os"]			= "fire/fx_fire_ai_human_hip_right_os";
	level._effect["fire_zombie_j_knee_le_os"]		= "fire/fx_fire_ai_human_leg_left_os";		// shin fires
	level._effect["fire_zombie_j_knee_ri_os"]		= "fire/fx_fire_ai_human_leg_right_os";
	level._effect["fire_zombie_j_head_os"] 			= "fire/fx_fire_ai_human_head_os";			// head fire	
	
	//smoke fx
	level._effect["smolder_human_j_elbow_le_os"]	= "smoke/fx_smk_ai_human_arm_left_os";
	level._effect["smolder_human_j_elbow_ri_os"]	= "smoke/fx_smk_ai_human_arm_right_os";
	level._effect["smolder_human_j_shoulder_le_os"]	= "smoke/fx_smk_ai_human_arm_left_os";
	level._effect["smolder_human_j_shoulder_ri_os"]	= "smoke/fx_smk_ai_human_arm_right_os";
	level._effect["smolder_human_j_spine4_os"]		= "smoke/fx_smk_ai_human_torso_os";		
	level._effect["smolder_human_j_hip_le_os"]		= "smoke/fx_smk_ai_human_hip_left_os";	
	level._effect["smolder_human_j_hip_ri_os"]		= "smoke/fx_smk_ai_human_hip_right_os";
	level._effect["smolder_human_j_knee_le_os"]		= "smoke/fx_smk_ai_human_leg_left_os";	
	level._effect["smolder_human_j_knee_ri_os"]		= "smoke/fx_smk_ai_human_leg_right_os";
	level._effect["smolder_human_j_head_os"] 		= "smoke/fx_smk_ai_human_head_os";		
	

	// robot-specific fires
	level._effect["fire_robot_j_elbow_le_rot_loop"]		= "fire/fx_fire_ai_robot_arm_left_loop";	// hand and forearm fires
	level._effect["fire_robot_j_elbow_ri_rot_loop"]		= "fire/fx_fire_ai_robot_arm_right_loop";
	level._effect["fire_robot_j_shoulder_le_rot_loop"]	= "fire/fx_fire_ai_robot_arm_left_loop";	// upper arm fires
	level._effect["fire_robot_j_shoulder_ri_rot_loop"]	= "fire/fx_fire_ai_robot_arm_right_loop";
	level._effect["fire_robot_j_spine4_loop"]			= "fire/fx_fire_ai_robot_torso_loop";		// upper torso fires
	level._effect["fire_robot_j_knee_le_loop"]			= "fire/fx_fire_ai_robot_leg_left_loop";	// shin fires
	level._effect["fire_robot_j_knee_ri_loop"]			= "fire/fx_fire_ai_robot_leg_right_loop";
	level._effect["fire_robot_j_head_loop"] 			= "fire/fx_fire_ai_robot_head_loop";		// head fire
	level._effect["fire_robot_j_elbow_le_rot_os"]		= "fire/fx_fire_ai_robot_arm_left_os";	// hand and forearm fires
	level._effect["fire_robot_j_elbow_ri_rot_os"]		= "fire/fx_fire_ai_robot_arm_right_os";
	level._effect["fire_robot_j_shoulder_le_rot_os"]	= "fire/fx_fire_ai_robot_arm_left_os";	// upper arm fires
	level._effect["fire_robot_j_shoulder_ri_rot_os"]	= "fire/fx_fire_ai_robot_arm_right_os";
	level._effect["fire_robot_j_spine4_os"]				= "fire/fx_fire_ai_robot_torso_os";		// upper torso fires
	level._effect["fire_robot_j_knee_le_os"]			= "fire/fx_fire_ai_robot_leg_left_os";	// shin fires
	level._effect["fire_robot_j_knee_ri_os"]			= "fire/fx_fire_ai_robot_leg_right_os";
	level._effect["fire_robot_j_head_os"] 				= "fire/fx_fire_ai_robot_head_os";		// head fire
}

//------------------------------FIRE FX------------------------------

function private _burnTag(localClientNum, tag, postfix)
{
	if(isDefined(self) && self HasDObj(localClientNum) )
	{
		fx_to_play = undefined;
		
		fxname = "fire_"+self.archetype+"_"+tag+postfix;
		
		if( isdefined(level._effect[fxname]))
		{
			fx_to_play = level._effect[fxname];
		}
		
		if( isdefined( self._effect ) && isdefined( self._effect[fxname]))
		{
			fx_to_play = self._effect[fxname];
		}
			
		if( isDefined( fx_to_play ))
		{
			fx = PlayFXOnTag(localClientNum, fx_to_play, self, tag);
			
			if( IS_BONUSZM && IsDefined(fx) )
			{
				SetFXIgnorePause( localClientNum, fx, true );					
			}
			
			return fx;
		}
	}
}

function private _burnStage(localClientNum, tagArray, shouldWait )
{
	if(!isDefined(self))
		return;
		
	self endon("entityshutdown");
	
	tags = array::randomize(tagArray);
	
	for(i=1;i<tags.size;i++)//drop random one for variance.
	{
		if ( tags[i] == "null" )
		{
			continue;
		}
		self.activeFX[self.activeFX.size] = self _burnTag(localClientNum, tags[i],(shouldWait?"_loop":"_os") );
		if(shouldWait)
		{
			wait RandomFloatRange(0.1,.3);
		}
	}
	if(shouldWait)
	{
		wait RandomFloatRange(0,1);
	}
	if (  isDefined(self) )
		self notify("burn_stage_finished");
}

function private _burnBody(localClientNum)
{
	self endon("entityshutdown");
	
	self.burn_loop_sound_handle = self playloopsound( "chr_burn_npc_loop1", .2);
	timer = 10;

	boneModifier = "";
	if ( self.archetype == "robot" )
	{
		boneModifier = "_rot";
		timer = 6;
	}
	
	if( IS_BONUSZM ) // special case for a suicidal zombie in campaign zombies
	{
		if( self.archetype !== ARCHETYPE_ZOMBIE )
		{
			self thread sndStopBurnLoop(timer);
		}
	}
	else
	{
		self thread sndStopBurnLoop(timer);
	}
	
	stage1BurnTags	= array("j_elbow_le"+boneModifier, "j_elbow_ri"+boneModifier, "null");
	stage2BurnTags	= array("j_shoulder_le"+boneModifier, "j_shoulder_ri"+boneModifier, "null");
	stage3BurnTags	= array("j_spine4", "null");
	stage4BurnTags	= array("j_hip_le", "j_hip_ri", "j_head", "null");
	stage5BurnTags	= array("j_knee_le", "j_knee_ri", "null");
	
	matureMask = 0.0;
	if ( util::is_mature() ) 
		matureMask = 1.0;

	self.activeFX = [];
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage1BurnTags,true);
	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 0.20 ); 
	self waittill("burn_stage_finished");
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage2BurnTags,true);
	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 0.40 ); 
	self waittill("burn_stage_finished");
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage3BurnTags,true);
	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 0.60 ); 
	self waittill("burn_stage_finished");
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage4BurnTags,true);
	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 0.80 ); 
	self waittill("burn_stage_finished");
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage5BurnTags,true);
	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 1.00 ); 
}

function sndStopBurnLoop(timer)
{
	self util::waittill_any_timeout(timer, "entityshutdown", "stopBurningSounds" );
	
	if(isDefined(self))
	{
		if( isdefined( self.burn_loop_sound_handle ) )
		{
			self stoploopsound( self.burn_loop_sound_handle );
		}
	}
}

function private _burnCorpse(localClientNum, burningDuration)
{
	self endon("entityshutdown");
	
	timer = 10;
	
	boneModifier = "";
	if ( self.archetype == "robot" )
	{
		boneModifier = "_rot";
		timer = 3;
	}
	
	stage1BurnTags	= array("j_elbow_le"+boneModifier, "j_elbow_ri"+boneModifier);
	stage2BurnTags	= array("j_shoulder_le"+boneModifier, "j_shoulder_ri"+boneModifier);
	stage3BurnTags	= array("j_spine4", "j_spinelower", "null");
	stage4BurnTags	= array("j_hip_le", "j_hip_ri", "j_head");
	stage5BurnTags	= array("j_knee_le", "j_knee_ri");	
	
	self.burn_loop_sound_handle =  self playloopsound( "chr_burn_npc_loop1", .2);
	self thread sndStopBurnLoop(timer);
	
	// TODO: If self is a robot, check which parts have gibbed and don't play effects on those bones.
	// TODO: If there's a way to find out which effects were played on this archetype before it became a corpse, play only the oneshot versions of those effects.
	self.activeFX = [];
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage1BurnTags, false);
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage2BurnTags, false);
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage3BurnTags, false);
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage4BurnTags, false);
	self.activeFX[self.activeFX.size] = self thread _burnStage(localClientNum, stage5BurnTags, false);

  	matureMask = 0.0;
	if ( util::is_mature() ) 
		matureMask = 1.0;

	self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 1.0 ); 
	
	wait 20;
	
	if(isDefined(self))
	{
		foreach(fx in self.activeFX)
		{
			StopFx(localClientNum,fx);
			//wait RandomFloatRange(0.25,2);	// effect timeouts are baked in, so they should all have stopped by now
			self notify( "stopBurningSounds" );
		}
		if(isDefined(self))
			self.activeFX = [];
	}
}


function private _smolderCorpse(localClientNum)
{
	self endon("entityshutdown");
	
	boneModifier = "";
	if ( self.archetype == "robot" )
	{
		boneModifier = "_rot";
	}
	
	activeFX 	= [];
	fxToPlay 	= [];
	tags 		= array("j_elbow_le"+boneModifier,"j_elbow_ri"+boneModifier,"j_shoulder_le","j_shoulder_ri","j_spine4","j_hip_le","j_hip_ri","j_knee_le","j_knee_ri","j_head");
	num	 		= RandomIntRange(6,10);
	while(num)
	{
		fxToPlay[fxToPlay.size] = tags[RandomInt(tags.size)];		//dont care if there are dups
		num--;
	}
	foreach(tag in fxToPlay)
	{
		fx = "smolder_"+self.archetype+tag+"_os";
		if(isDefined(level._effect[fx]))
		{
			activeFX[activeFX.size] = playfxontag(localClientNum,level._effect[fx],self,tag);
			wait RandomFloatRange(0.1,1);
		}
	}
	wait 20;	
	if(isDefined(self))
	{
		foreach(fx in activeFX)
		{
			StopFx(localClientNum,fx);
		}
	}
}


function actor_fire_fx(localClientNum, value, burningDuration)
{
	switch(value)
	{
		case BURN_CLEAR: //turn off burning
		if (isDefined(self.activeFX))
		{
			self StopAllLoopSounds(1);
			
			foreach(fx in self.activeFX)
			{
				StopFx(localClientNum,fx);
			}
		}
		self.activeFX = [];
		break;
		case BURN_BODY:	//burning
			self thread _burnBody(localClientNum);
		break;
		case BURN_CORPSE:
			self thread _burnCorpse(localClientNum, burningDuration);
		break;
		case BURN_SMOLDER:
			self thread _smolderCorpse(localClientNum);
		break;
	}
}
function actor_fire_fx_state(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self actor_fire_fx(localClientNum, newVal, FIRE_FX_MAX_DURATION);
}

function actor_char(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
  	matureMask = 0.0;
	if ( util::is_mature() ) 
		matureMask = 1.0;

	switch(newVal)
	{
		case CHAR_RAMP:
			self thread actorCharRampTo(localClientNum,1);
			break;
		case CHAR_CLEAR:
			self MapShaderConstant( localClientNum, 0, "scriptVector0", 0); 
			break;
		case CHAR_FULL:
			self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * 1.0 ); 
			break;
	}
}

#define CHAR_RAMP_TIME	2
function actorCharRampTo(localClientNum,charDesired)
{
	self endon("entityshutdown");

	if(!isDefined(self.curCharLevel))
		self.curCharLevel = 0;

	matureMask = 0.0;
	if ( util::is_mature() ) 
		matureMask = 1.0;
	
	if(!isDefined(self.charsteps))
	{
		assert(isDefined(charDesired));
		self.charsteps 	= int(CHAR_RAMP_TIME / 0.01);
		delta 			= charDesired - self.curCharLevel;
		self.charinc   	= delta/self.charsteps;
	}
	while(self.charsteps)
	{
		self.curCharLevel = math::clamp(self.curCharLevel+self.charinc,0,1);
		self MapShaderConstant( localClientNum, 0, "scriptVector0", matureMask * self.curCharLevel ); 
		self.charsteps--;
		wait 0.01;
	}
}
