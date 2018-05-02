#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\ai\systems\gib;

#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\weapons\_hive_gun.gsh;

#namespace hive_gun;

#precache( "client_fx", "weapon/fx_hero_firefly_hunting" );
#precache( "client_fx", "weapon/fx_hero_firefly_death" );
#precache( "client_fx", "weapon/fx_hero_firefly_attack" );
#precache( "client_fx", "weapon/fx_ability_firefly_attack_1p" );
#precache( "client_fx", "weapon/fx_ability_firefly_chase_1p" );
#precache( "client_fx", "weapon/fx_hero_firefly_attack_limb" );
#precache( "client_fx", "weapon/fx_hero_firefly_attack_limb_reaper" );
//#precache( "client_fx", "weapon/fx_hero_firefly_start" );
#precache( "client_fx", "weapon/fx_hero_firefly_start_entity" );

function init_shared()
{	
//	visionset_mgr::register_overlay_info_style_postfx_bundle( "hive_gungun_splat", VERSION_SHIP, 7, "pstfx_hive_gun_splat", hive_gun_SPLAT_DURATION_MAX );
	level thread register();
}

function register()
{
	clientfield::register( "scriptmover", "firefly_state", VERSION_SHIP, 3, "int",&firefly_state_change, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
//	clientfield::register( "scriptmover", "firefly_target", VERSION_SHIP, 6, "int",&firefly_target, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "fireflies_attacking", VERSION_SHIP, 1, "int", &fireflies_attacking, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "fireflies_chasing", VERSION_SHIP, 1, "int", &fireflies_chasing, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function getOtherTeam( team )
{
	if ( team == "allies" )
		return "axis";
	else if ( team == "axis" )
		return "allies";
	else
		return "free";
}

function fireflies_attacking( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");
	self util::waittill_dobj( localClientNum );

	if ( !isdefined(self) )
		return;
		
	if ( newVal )
	{
		self notify ( "stop_player_fx" );
		
		if ( self IsLocalPlayer() && !(self GetInKillcam( localClientNum )) )
		{
			fx = PlayFXOnCamera( localClientNum, "weapon/fx_ability_firefly_attack_1p", (0,0,0), (1,0,0), (0,0,1)  );
			self thread watch_player_fx_finished( localClientNum, fx );
		}
	}
	else
	{
		self notify ( "stop_player_fx" );
	}
}

function fireflies_chasing( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");
	self util::waittill_dobj( localClientNum );

	if ( !isdefined(self) )
		return;
		
	if ( newVal )
	{
		self notify ( "stop_player_fx" );

		if ( self IsLocalPlayer() && !(self GetInKillcam( localClientNum )) )
		{
			fx = PlayFXOnCamera( localClientNum, "weapon/fx_ability_firefly_chase_1p", (0,0,0), (1,0,0), (0,0,1) );
			sound = self PlayLoopSound("wpn_gelgun_hive_hunt_lp" );
			self PlayRumbleLoopOnEntity( localClientNum, "firefly_chase_rumble_loop" );
			self thread watch_player_fx_finished( localClientNum, fx, sound );
		}
	}
	else
	{
		self notify ( "stop_player_fx" );
	}
}

function watch_player_fx_finished( localClientNum, fx, sound )
{
	self util::waittill_any( "entityshutdown", "stop_player_fx" );
	
	if( isDefined( self ) )
	{
		self StopRumble( localClientNum, "firefly_chase_rumble_loop" );
	}
	
	if ( IsDefined( fx ) )
	{
		StopFx( localClientNum, fx );		
	}
	
	if ( isdefined( sound ) && isDefined( self ) )
	{
		self StopLoopSound( sound );
	}
}

function firefly_state_change( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );

	if ( !isdefined(self) )
		return;
	
	if ( !isdefined( self.initied ) )
	{
		self thread firefly_init( localClientNum );
		self.initied = true;
	}
	
	switch( newVal )
	{
		case FIREFLY_INIT:
		{
			break;
		}
		case FIREFLY_DEPLOYING:
		{
			self firefly_deploying( localClientNum );
			break;
		}
		case FIREFLY_HUNTING:
		{
			self firefly_hunting( localClientNum );
			break;
		}
		case FIREFLY_ATTACKING:
		{
			self firefly_attacking( localClientNum );
			break;
		}
		case FIREFLY_LINK_ATTACKING:
		{
			self firefly_link_attacking( localClientNum );
			break;
		}
	}
}

function on_shutdown(localClientNum, ent)
{
	if ( isdefined(ent) && isdefined(ent.origin) && self === ent && !IS_TRUE( self.no_death_fx ) )
	{
		fx = PlayFX( localClientNum,"weapon/fx_hero_firefly_death", ent.origin, (0,0,1) );
		SetFXTeam( localClientNum, fx, ent.team );
	}
}

function firefly_init( localClientNum )
{
	self callback::on_shutdown( &on_shutdown, self );
}

function firefly_deploying( localClientNum )
{
	fx = PlayFX( localClientNum, "weapon/fx_hero_firefly_start", self.origin, AnglesToUp(self.angles) );
	SetFXTeam( localClientNum, fx, self.team );
}

function firefly_hunting( localClientNum )
{
	fx = PlayFXOnTag( localClientNum, "weapon/fx_hero_firefly_hunting", self, "tag_origin");
	SetFXTeam( localClientNum, fx, self.team );	
	self thread firefly_watch_fx_finished( localClientNum, fx );
}

function firefly_watch_fx_finished( localClientNum, fx )
{
	self util::waittill_any( "entityshutdown", "stop_effects" );
	
	if ( isdefined( fx ) )
	{
		StopFx( localClientNum, fx );
	}
}

function firefly_attacking( localClientNum )
{
	self notify ( "stop_effects" );
	self.no_death_fx = true;
}

function firefly_link_attacking( localClientNum )
{
	fx = PlayFX( localClientNum, "weapon/fx_hero_firefly_start_entity", self.origin, AnglesToUp(self.angles) );
	SetFXTeam( localClientNum, fx, self.team );

	self notify ( "stop_effects" );
	self.no_death_fx = true;
}

function gib_fx( localClientNum, fxFileName, gibFlag )
{
	fxTag = GibClientUtils::PlayerGibTag( localClientNum, gibFlag );
	if ( isdefined( fxTag ) )
	{
		fx = PlayFxOnTag( localClientNum, fxFileName, self, fxTag );
		SetFXTeam( localClientNum, fx, getOtherTeam( self.team ) );
	}
}

function gib_corpse( localClientNum, value ) 
{
	self endon("entityshutdown");
	
	self thread watch_for_gib_notetracks( localClientNum );
}

function watch_for_gib_notetracks( localClientNum )
{
	self endon("entityshutdown");
	
	if ( !util::is_mature() || util::is_gib_restricted_build() )
		return;

	fxFileName = "weapon/fx_hero_firefly_attack_limb";
	bodyType = self GetCharacterBodyType();
	if ( bodyType >= 0 )
	{
		bodyTypeFields = GetCharacterFields( bodyType, CurrentSessionMode() );
		if( VAL( bodyTypeFields.digitalBlood, false ) )
		{
			fxFileName = "weapon/fx_hero_firefly_attack_limb_reaper";
		}
	}

	
	arm_gib = 0;
	leg_gib = 0;
	while( 1 )
	{
		notetrack = self util::waittill_any_return( "gib_leftarm", "gib_leftleg", "gib_rightarm", "gib_rightleg", "entityshutdown" );
		
		switch( noteTrack )
		{
			case "gib_rightarm":
				{
					arm_gib = arm_gib | 1;
					gib_fx( localClientNum, fxFileName, GIB_TORSO_RIGHT_ARM_FLAG );
					self GibClientUtils::PlayerGibLeftArm( localClientNum );
					self SetCorpseGibState( leg_gib, arm_gib );
				}
				break;
			case "gib_leftarm":
				{
					arm_gib = arm_gib | 2;
					gib_fx( localClientNum, fxFileName, GIB_TORSO_LEFT_ARM_FLAG );
					self GibClientUtils::PlayerGibLeftArm( localClientNum );
					self SetCorpseGibState( leg_gib, arm_gib );
				}
				break;
			case "gib_rightleg":
				{
					leg_gib = leg_gib | 1;
					gib_fx( localClientNum, fxFileName, GIB_LEGS_RIGHT_LEG_FLAG );
					self GibClientUtils::PlayerGibLeftLeg( localClientNum );	
					self SetCorpseGibState( leg_gib, arm_gib );
				}
				break;
			case "gib_leftleg":
				{
					leg_gib = leg_gib | 2;
					gib_fx( localClientNum, fxFileName, GIB_LEGS_LEFT_LEG_FLAG );
					self GibClientUtils::PlayerGibLeftLeg( localClientNum );	
					self SetCorpseGibState( leg_gib, arm_gib );
				}
				break;
			default:
			break;
		}	
	}
}
