#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\util_shared;


#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\margwa.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "client_fx", MARGWA_TELEPORT_FX_FILE );
#precache( "client_fx", MARGWA_TELEPORT_TRAVEL_FX_FILE );
#precache( "client_fx", MARGWA_TELEPORT_TRAVEL_TELL_FX_FILE );
#precache( "client_fx", MARGWA_SPAWN_FX_FILE );
#precache( "client_fx", MARGWA_IMPACT_FX_FILE );
#precache( "client_fx", MARGWA_ROAR_FX_FILE );
#precache( "client_fx", MARGWA_SUPER_ROAR_FX_FILE );


#using_animtree( "generic" );

function autoexec main()
{
	clientfield::register( "actor", MARGWA_HEAD_LEFT_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE, &MargwaClientUtils::margwaHeadLeftCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_MID_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE, &MargwaClientUtils::margwaHeadMidCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_RIGHT_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE, &MargwaClientUtils::margwaHeadRightCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_FX_IN_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaFxInCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_FX_OUT_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaFxOutCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_FX_SPAWN_CLIENTFIELD, VERSION_SHIP, MARGWA_FX_SPAWN_CLIENTFIELD_BITS, MARGWA_FX_SPAWN_CLIENTFIELD_TYPE, &MargwaClientUtils::margwaFxSpawnCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_SMASH_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaSmashCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_LEFT_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaLeftHitCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_MID_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaMidHitCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_RIGHT_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter", &MargwaClientUtils::margwaRightHitCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_HEAD_KILLED_CLIENTFIELD, VERSION_SHIP, 2, "int", &MargwaClientUtils::margwaHeadKilledCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", MARGWA_JAW_CLIENTFIELD, VERSION_SHIP, 6, "int", &MargwaClientUtils::margwaJawCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	clientfield::register( "toplayer", MARGWA_HEAD_EXPLODE_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_EXPLODE_CLIENTFIELD_BITS, MARGWA_HEAD_EXPLODE_CLIENTFIELD_TYPE, &MargwaClientUtils::margwaHeadExplosion, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", MARGWA_FX_TRAVEL_CLIENTFIELD, VERSION_SHIP, 1, "int", &MargwaClientUtils::margwaFxTravelCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", MARGWA_FX_TRAVEL_TELL_CLIENTFIELD, VERSION_SHIP, 1, "int", &MargwaClientUtils::margwaFxTravelTellCallback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	clientfield::register( "actor", "supermargwa", VERSION_SHIP, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT ); // set this bit when spawning supermargwa for ee quest

	ai::add_archetype_spawn_function( ARCHETYPE_MARGWA, &MargwaClientUtils::margwaSpawn );

	level._jaw = [];
	level._jaw[ MARGWA_JAW_IDLE ] = "idle_1";
	level._jaw[ MARGWA_JAW_HEAD_L_EXPLODE ] = "idle_pain_head_l_explode";
	level._jaw[ MARGWA_JAW_HEAD_M_EXPLODE ] = "idle_pain_head_m_explode";
	level._jaw[ MARGWA_JAW_HEAD_R_EXPLODE ] = "idle_pain_head_r_explode";
	level._jaw[ MARGWA_JAW_REACT_STUN ] = "react_stun";
	level._jaw[ MARGWA_JAW_REACT_IDGUN ] = "react_idgun";
	level._jaw[ MARGWA_JAW_REACT_IDGUN_PACKED ] = "react_idgun_pack";
	level._jaw[ MARGWA_JAW_RUN_CHARGE ] = "run_charge_f";
	level._jaw[ MARGWA_JAW_RUN ] = "run_f";
	level._jaw[ MARGWA_JAW_SMASH_ATTACK ] = "smash_attack_1";
	level._jaw[ MARGWA_JAW_SWIPE ] = "swipe";
	level._jaw[ MARGWA_JAW_SWIPE_PLAYER ] = "swipe_player";
	level._jaw[ MARGWA_JAW_TELEPORT_IN ] = "teleport_in";
	level._jaw[ MARGWA_JAW_TELEPORT_OUT ] = "teleport_out";
	level._jaw[ MARGWA_JAW_TRV_JUMP_ACROSS_256 ] = "trv_jump_across_256";
	level._jaw[ MARGWA_JAW_TRV_JUMP_DOWN_128 ] = "trv_jump_down_128";
	level._jaw[ MARGWA_JAW_TRV_JUMP_DOWN_36 ] = "trv_jump_down_36";
	level._jaw[ MARGWA_JAW_TRV_JUMP_DOWN_96 ] = "trv_jump_down_96";
	level._jaw[ MARGWA_JAW_TRV_JUMP_UP_128 ] = "trv_jump_up_128";
	level._jaw[ MARGWA_JAW_TRV_JUMP_UP_36 ] = "trv_jump_up_36";
	level._jaw[ MARGWA_JAW_TRV_JUMP_UP_96 ] = "trv_jump_up_96";
}

function autoexec precache()
{
	level._effect[ MARGWA_TELEPORT_FX ] = MARGWA_TELEPORT_FX_FILE;
	level._effect[ MARGWA_TELEPORT_TRAVEL_FX ] = MARGWA_TELEPORT_TRAVEL_FX_FILE;
	level._effect[ MARGWA_TELEPORT_TRAVEL_TELL_FX ] = MARGWA_TELEPORT_TRAVEL_TELL_FX_FILE;
	level._effect[ MARGWA_SPAWN_FX ] = MARGWA_SPAWN_FX_FILE;
	level._effect[ MARGWA_IMPACT_FX ] = MARGWA_IMPACT_FX_FILE;
	level._effect[ MARGWA_ROAR_FX ] = MARGWA_ROAR_FX_FILE;
	level._effect[ MARGWA_SUPER_ROAR_FX ] = MARGWA_SUPER_ROAR_FX_FILE;
}

#namespace MargwaClientUtils;

function private margwaSpawn( localClientNum )
{
	self util::waittill_dobj(localClientNum);
	if (!isdefined(self))
		return; 
	
	self SetAnim( MARGWA_ANIM_HEAD_LEFT_CLOSED, 1.0, 0.2, 1.0 );
	self SetAnim( MARGWA_ANIM_HEAD_MID_CLOSED, 1.0, 0.2, 1.0 );
	self SetAnim( MARGWA_ANIM_HEAD_RIGHT_CLOSED, 1.0, 0.2, 1.0 );

	for ( i = 1; i <= MARGWA_NUM_TENTACLES_PER_SIDE; i++ )
	{
		leftTentacle = MARGWA_ANIM_TENTACLE_LEFT_BASE + i;
		rightTentacle = MARGWA_ANIM_TENTACLE_RIGHT_BASE + i;

		self SetAnim( leftTentacle, 1.0, 0.2, 1.0 );
		self SetAnim( rightTentacle, 1.0, 0.2, 1.0 );
	}

	level._footstepCBFuncs[self.archetype] = &margwaProcessFootstep;

	self.heads = [];
	self.heads[ MARGWA_HEAD_KILLED_LEFT ] = SpawnStruct();
	self.heads[ MARGWA_HEAD_KILLED_LEFT ].index = MARGWA_HEAD_KILLED_LEFT;
	self.heads[ MARGWA_HEAD_KILLED_LEFT ].prevHeadAnim = MARGWA_ANIM_HEAD_LEFT_CLOSED;
	self.heads[ MARGWA_HEAD_KILLED_LEFT ].jawBase = MARGWA_JAW_BASE_L;

	self.heads[ MARGWA_HEAD_KILLED_MID ] = SpawnStruct();
	self.heads[ MARGWA_HEAD_KILLED_MID ].index = MARGWA_HEAD_KILLED_MID;
	self.heads[ MARGWA_HEAD_KILLED_MID ].prevHeadAnim = MARGWA_ANIM_HEAD_MID_CLOSED;
	self.heads[ MARGWA_HEAD_KILLED_MID ].jawBase = MARGWA_JAW_BASE_M;

	self.heads[ MARGWA_HEAD_KILLED_RIGHT ] = SpawnStruct();
	self.heads[ MARGWA_HEAD_KILLED_RIGHT ].index = MARGWA_HEAD_KILLED_RIGHT;
	self.heads[ MARGWA_HEAD_KILLED_RIGHT ].prevHeadAnim = MARGWA_ANIM_HEAD_RIGHT_CLOSED;
	self.heads[ MARGWA_HEAD_KILLED_RIGHT ].jawBase = MARGWA_JAW_BASE_R;
}

function private margwaHeadLeftCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( IsDefined( self.leftGlowFx ) )
	{
		StopFx( localClientNum, self.leftGlowFx );
	}

	self util::waittill_dobj(localClientNum);
	if (!isdefined(self))
		return; 
	
	switch ( newValue )
	{
	case MARGWA_HEAD_OPEN:
		self.heads[ MARGWA_HEAD_KILLED_LEFT ].prevHeadAnim = MARGWA_ANIM_HEAD_LEFT_OPEN;
		self SetAnim( MARGWA_ANIM_HEAD_LEFT_OPEN, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_LEFT_CLOSED, MARGWA_MOUTH_BLEND_TIME );
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.leftGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_LEFT );
		}
		else
		{
			self.leftGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_LEFT );
		}
		break;

	case MARGWA_HEAD_CLOSED:
		self.heads[ MARGWA_HEAD_KILLED_LEFT ].prevHeadAnim = MARGWA_ANIM_HEAD_LEFT_CLOSED;
		self SetAnim( MARGWA_ANIM_HEAD_LEFT_CLOSED, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_LEFT_OPEN, MARGWA_MOUTH_BLEND_TIME );
		self ClearAnim( MARGWA_ANIM_HEAD_LEFT_SMASH, MARGWA_MOUTH_BLEND_TIME );
		break;

	case MARGWA_HEAD_SMASH_ATTACK:
		self.heads[ MARGWA_HEAD_KILLED_LEFT ].prevHeadAnim = MARGWA_ANIM_HEAD_LEFT_SMASH;
		self ClearAnim( MARGWA_ANIM_HEAD_LEFT_OPEN, 0.1 );
		self ClearAnim( MARGWA_ANIM_HEAD_LEFT_CLOSED, 0.1 );
		self SetAnimRestart( MARGWA_ANIM_HEAD_LEFT_SMASH, 1, 0.1, 1);
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.leftGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_LEFT );
		}
		else
		{
			self.leftGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_LEFT );
		}
		self thread margwaStopSmashFx( localClientNum );
		break;
	}
}

function private margwaHeadMidCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( IsDefined( self.midGlowFx ) )
	{
		StopFx( localClientNum, self.midGlowFx );
	}

	self util::waittill_dobj(localClientNum);
	if (!isdefined(self))
		return; 
	
	switch ( newValue )
	{
	case MARGWA_HEAD_OPEN:
		self SetAnim( MARGWA_ANIM_HEAD_MID_OPEN, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_MID_CLOSED, MARGWA_MOUTH_BLEND_TIME );
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.midGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_MID );
		}
		else
		{
			self.midGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_MID );
		}
		break;

	case MARGWA_HEAD_CLOSED:
		self SetAnim( MARGWA_ANIM_HEAD_MID_CLOSED, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_MID_OPEN, MARGWA_MOUTH_BLEND_TIME );
		self ClearAnim( MARGWA_ANIM_HEAD_MID_SMASH, MARGWA_MOUTH_BLEND_TIME );
		break;

	case MARGWA_HEAD_SMASH_ATTACK:
		self ClearAnim( MARGWA_ANIM_HEAD_MID_OPEN, 0.1 );
		self ClearAnim( MARGWA_ANIM_HEAD_MID_CLOSED, 0.1 );
		self SetAnimRestart( MARGWA_ANIM_HEAD_MID_SMASH, 1, 0.1, 1);
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.midGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_MID );
		}
		else
		{
			self.midGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_MID );
		}
		self thread margwaStopSmashFx( localClientNum );
		break;
	}
}

function private margwaHeadRightCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( IsDefined( self.rightGlowFx ) )
	{
		StopFx( localClientNum, self.rightGlowFx );
	}

	self util::waittill_dobj(localClientNum);
	if (!isdefined(self))
		return; 
	
	switch ( newValue )
	{
	case MARGWA_HEAD_OPEN:
		self SetAnim( MARGWA_ANIM_HEAD_RIGHT_OPEN, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_RIGHT_CLOSED, MARGWA_MOUTH_BLEND_TIME );
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.rightGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_RIGHT );
		}
		else
		{
			self.rightGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_RIGHT );
		}
		break;

	case MARGWA_HEAD_CLOSED:
		self SetAnim( MARGWA_ANIM_HEAD_RIGHT_CLOSED, 1.0, MARGWA_MOUTH_BLEND_TIME, 1.0 );
		self ClearAnim( MARGWA_ANIM_HEAD_RIGHT_OPEN, MARGWA_MOUTH_BLEND_TIME );
		self ClearAnim( MARGWA_ANIM_HEAD_RIGHT_SMASH, MARGWA_MOUTH_BLEND_TIME );
		break;

	case MARGWA_HEAD_SMASH_ATTACK:
		self ClearAnim( MARGWA_ANIM_HEAD_RIGHT_OPEN, 0.1 );
		self ClearAnim( MARGWA_ANIM_HEAD_RIGHT_CLOSED, 0.1 );
		self SetAnimRestart( MARGWA_ANIM_HEAD_RIGHT_SMASH, 1, 0.1, 1);
		roar_effect = level._effect[ MARGWA_ROAR_FX ];
		if( isDefined( self.margwa_roar_effect ))
		{
			roar_effect = self.margwa_roar_effect;
		}
		if( self clientfield::get( "supermargwa" ) )
		{
			self.rightGlowFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_SUPER_ROAR_FX ], self, MARGWA_TAG_HEAD_RIGHT );
		}
		else
		{
			self.rightGlowFx = PlayFxOnTag( localClientNum, roar_effect, self, MARGWA_TAG_HEAD_RIGHT );
		}
		self thread margwaStopSmashFx( localClientNum );
		break;
	}
}

function private margwaStopSmashFx( localClientNum )
{
	self endon( "entityshutdown" );

	wait( 0.6 );

	if ( IsDefined( self.leftGlowFx ) )
	{
		StopFx( localClientNum, self.leftGlowFx );
	}

	if ( IsDefined( self.midGlowFx ) )
	{
		StopFx( localClientNum, self.midGlowFx );
	}

	if ( IsDefined( self.rightGlowFx ) )
	{
		StopFx( localClientNum, self.rightGlowFx );
	}
}

function private margwaFxInCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		self.teleportFxIn = PlayFx( localClientNum, level._effect[ MARGWA_TELEPORT_FX ], self GetTagOrigin( MARGWA_TAG_TELEPORT ) );
	}
}

function private margwaFxOutCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		tagPos = self GetTagOrigin( MARGWA_TAG_TELEPORT );
		self.teleportFxOut = PlayFx( localClientNum, level._effect[ MARGWA_TELEPORT_FX ], tagPos );
	}
}

function private margwaFxTravelCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	switch ( newValue )
	{
	case MARGWA_TELEPORT_OFF:
		DeleteFx( localClientNum, self.travelerFx );
		break;

	case MARGWA_TELEPORT_ON:
		self.travelerFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_TELEPORT_TRAVEL_FX ], self, "tag_origin" );
		break;
	}
}

function private margwaFxTravelTellCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	switch ( newValue )
	{
	case MARGWA_TELEPORT_OFF:
		DeleteFx( localClientNum, self.travelerTellFx );
		self notify( "stop_margwaTravelTell" );
		break;

	case MARGWA_TELEPORT_ON:
		self.travelerTellFx = PlayFxOnTag( localClientNum, level._effect[ MARGWA_TELEPORT_TRAVEL_TELL_FX ], self, "tag_origin" );
		self thread margwaTravelTellUpdate( localClientNum );
		break;
	}
}

function private margwaTravelTellUpdate( localClientNum )
{
	self notify( "stop_margwaTravelTell" );
	self endon( "stop_margwaTravelTell" );
	self endon( "entityshutdown" );

	player = GetLocalPlayer( localClientNum );

	while ( 1 )
	{
		if( isdefined(player) )
		{
			dist_sq = DistanceSquared( player.origin, self.origin );
			if ( dist_sq < MARGWA_TELL_DIST_SQ )
			{
				player PlayRumbleOnEntity( localClientNum, "tank_rumble" );
			}
		}
		wait( 0.05 );
	}
}


function private margwaFxSpawnCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		spawnfx = level._effect[ MARGWA_SPAWN_FX ];
		if( isDefined( self.margwa_spawn_effect ))
		{
			spawnfx = self.margwa_spawn_effect;
		}

		if ( isDefined( self.margwa_play_spawn_effect ) )
		{
			self thread [[ self.margwa_play_spawn_effect ]]( localClientNum );
		}
		else
		{
			self.spawnFx = PlayFx( localClientNum, spawnfx, self GetTagOrigin( MARGWA_TAG_TELEPORT ) );
		}

		playsound(0, "zmb_margwa_spawn", self GetTagOrigin( MARGWA_TAG_TELEPORT ) );
	}
}

function private margwaHeadExplosion( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		self postfx::PlayPostfxBundle( "pstfx_parasite_dmg" );
	}
}

function margwaProcessFootstep( localClientNum, pos, surface, notetrack, bone )
{
	e_player = GetLocalPlayer( localClientNum );
	n_dist = DistanceSquared( pos, e_player.origin );
	n_margwa_dist = ( MARGWA_FOOTSTEP_EARTHQUAKE_MAX_RADIUS * MARGWA_FOOTSTEP_EARTHQUAKE_MAX_RADIUS );
	if(n_margwa_dist>0)
		n_scale = ( n_margwa_dist - n_dist ) / n_margwa_dist;
	else
		return;
	
	if( n_scale > 1 || n_scale < 0 ) return;
		
	n_scale = n_scale * 0.25;
	if( n_scale <= 0.01 ) return;
	e_player Earthquake( n_scale, 0.1, pos, n_dist );
	
	if( n_scale <= 0.25 && n_scale > 0.2 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "shotgun_fire" );
	}
	
	else if( n_scale <= 0.2 && n_scale > 0.1 )
	{
		e_player PlayRumbleOnEntity( localClientNum, "damage_heavy" );
	}
	else
	{
		e_player PlayRumbleOnEntity( localClientNum, "reload_small" );
	}
}

function private margwaSmashCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		e_player = GetLocalPlayer( localClientNum );

		smashPos = self.origin + VectorScale( AnglesToForward( self.angles ), MARGWA_SMASH_ATTACK_OFFSET );
		distSq = DistanceSquared( smashPos, e_player.origin );
		if ( distSq < MARGWA_SMASH_ATTACK_RANGE )
		{
			e_player Earthquake( 0.7, 0.25, e_player.origin, 3000 );
			e_player PlayRumbleOnEntity( localClientNum, "shotgun_fire" );
		}
		else if ( distSq < MARGWA_SMASH_ATTACK_RANGE_LIGHT )
		{
			e_player Earthquake( 0.7, 0.25, e_player.origin, 1500 );
			e_player PlayRumbleOnEntity( localClientNum, "damage_heavy" );
		}
	}
}

function private margwaLeftHitCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		effect = level._effect[ MARGWA_IMPACT_FX ];
		if( isdefined( self.margwa_head_hit_fx ))
		{
			effect = self.margwa_head_hit_fx;
		}
		self.leftHitFx = PlayFxOnTag( localClientNum, effect, self, MARGWA_TAG_HEAD_LEFT );
	}
}

function private margwaMidHitCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		effect = level._effect[ MARGWA_IMPACT_FX ];
		if( isdefined( self.margwa_head_hit_fx ))
		{
			effect = self.margwa_head_hit_fx;
		}
		self.midHitFx = PlayFxOnTag( localClientNum, effect, self, MARGWA_TAG_HEAD_MID );
	}
}

function private margwaRightHitCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		effect = level._effect[ MARGWA_IMPACT_FX ];
		if( isdefined( self.margwa_head_hit_fx ))
		{
			effect = self.margwa_head_hit_fx;
		}
		self.rightHitFx = PlayFxOnTag( localClientNum, effect, self, MARGWA_TAG_HEAD_RIGHT );
	}
}

function private margwaHeadKilledCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		self.heads[ newValue ].killed = true;
	}
}

function private margwaJawCallback( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		foreach( head in self.heads )
		{
			if ( IS_TRUE( head.killed ) )
			{
				if ( IsDefined( head.prevJawAnim ) )
				{
					self ClearAnim( head.prevJawAnim, 0.2 );
				}

				if ( IsDefined( head.prevHeadAnim ) )
				{
					self ClearAnim( head.prevHeadAnim, MARGWA_MOUTH_BLEND_TIME );
				}
				
				jawAnim = head.jawBase + level._jaw[ newValue ];
				head.prevJawAnim = jawAnim;

				self SetAnim( jawAnim, 1.0, 0.2, 1.0 );
			}
		}
	}
}


