#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\system_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\abilities\gadgets\_gadget_armor;

#insert scripts\shared\shared.gsh;

#precache( "material", "damage_feedback" );
#precache( "material", "damage_feedback_flak" );
#precache( "material", "damage_feedback_tac" );
#precache( "material", "damage_feedback_armor" );
#precache( "material", "damage_feedback_glow_orange" );

#namespace damagefeedback;

REGISTER_SYSTEM( "damagefeedback", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
	callback::on_connect( &on_player_connect );
}

function init()
{
}

function on_player_connect()
{
	// MP has a new damage feedback indicator in LUI
	if ( !SessionModeIsMultiplayerGame() )
	{
		self.hud_damagefeedback = newdamageindicatorhudelem(self);
		self.hud_damagefeedback.horzAlign = "center";
		self.hud_damagefeedback.vertAlign = "middle";
		self.hud_damagefeedback.x = -11;
		self.hud_damagefeedback.y = -11;
		self.hud_damagefeedback.alpha = 0;
		self.hud_damagefeedback.archived = true;
		self.hud_damagefeedback setShader( "damage_feedback", 22, 44 );
	
		self.hud_damagefeedback_additional = newdamageindicatorhudelem(self);
		self.hud_damagefeedback_additional.horzAlign = "center";
		self.hud_damagefeedback_additional.vertAlign = "middle";
		self.hud_damagefeedback_additional.x = -12;
		self.hud_damagefeedback_additional.y = -12;
		self.hud_damagefeedback_additional.alpha = 0;
		self.hud_damagefeedback_additional.archived = true;
		self.hud_damagefeedback_additional setShader( "damage_feedback", 24, 48 );
	}
}

function should_play_sound( mod )
{
	if ( !isdefined( mod ) )
		return false;
		
	switch( mod )
	{
	case "MOD_CRUSH":
	case "MOD_GRENADE_SPLASH":
	case "MOD_HIT_BY_OBJECT":
	case "MOD_MELEE_ASSASSINATE":
	case "MOD_MELEE":
	case "MOD_MELEE_WEAPON_BUTT":
		return false;
	};
	
	return true;
}

function update( mod, inflictor, perkFeedback, weapon, victim, psOffsetTime, sHitLoc )
{
	if ( !isPlayer( self ) )
		return;
	if ( IS_TRUE(self.noHitMarkers) )
		return false;

	if (isDefined(weapon) && IS_TRUE(weapon.nohitmarker) )
		return;
	
	if ( !isDefined( self.lastHitMarkerTime ) )
	{
		self.lastHitMarkerTimes = [];
		self.lastHitMarkerTime = 0;
		self.lastHitMarkerOffsetTime = 0;
	}	
	
	if ( isdefined( psOffsetTime ) )
	{
		victim_id = victim GetEntityNumber();
		
		if ( !IsDefined( self.lastHitMarkerTimes[ victim_id ] ) )
		{
			self.lastHitMarkerTimes[ victim_id ] = 0;
		}
	
		if ( self.lastHitMarkerTime == GetTime() )
		{
			if ( self.lastHitMarkerTimes[ victim_id ] === psOffsetTime )
				return;	
		}
		self.lastHitMarkerOffsetTime = psOffsetTime;
		self.lastHitMarkerTimes[ victim_id ] = psOffsetTime;
	}
	else
	{
		if ( self.lastHitMarkerTime == GetTime() )
			return;
	}
		
	self.lastHitMarkerTime = GetTime();
	hitAlias = undefined;
	
	if ( should_play_sound( mod ) )
	{	
		if ( isdefined( victim ) && isdefined( victim.victimSoundMod ) )
		{
			switch( victim.victimSoundMod )
			{
				case "safeguard_robot":
					hitAlias = "mpl_hit_alert_escort";
					break;
				default:
					hitAlias = "mpl_hit_alert";
					break;
			}
		}
		else if ( isdefined( inflictor ) && isdefined( inflictor.soundMod ))
		{
			//Add sound stuff here for specific inflictor types	
			switch ( inflictor.soundMod )
			{
				case "player":
					if( isdefined( victim ) && IS_TRUE( victim.isAiClone ) )
					{
						hitAlias = "mpl_hit_alert_clone";
					}
					else if ( isdefined( victim ) && isPlayer( victim ) && victim flagsys::get( "gadget_armor_on" ) && armor::armor_should_take_damage( inflictor, weapon, mod, sHitLoc ) )
					{
						hitAlias = "mpl_hit_alert_armor";
					}
					else if( isdefined( victim ) && isPlayer( victim ) && isDefined( victim.carryObject ) && isDefined( victim.carryObject.hitSound ) && isDefined( perkfeedback ) && ( perkfeedback == "armor" ) )
					{
						hitAlias = victim.carryObject.hitSound;
					}
					else if ( mod == "MOD_BURNED" )
					{
						hitAlias = "mpl_hit_alert_burn";
					}
					else
					{
						hitAlias = "mpl_hit_alert";
					}
					break;	
					
				case "heatwave":
					hitAlias = "mpl_hit_alert_heatwave";
					break;

				case "heli":	
					hitAlias = "mpl_hit_alert_air";
					break;
					
				case "hpm":	
					hitAlias = "mpl_hit_alert_hpm";
					break;
	
				case "taser_spike":
					hitAlias = "mpl_hit_alert_taser_spike";
					break;	
					
				case "straferun":				
				case "dog":
					break;

				case "firefly":
					hitAlias = "mpl_hit_alert_firefly";
					break;
					
				case "drone_land":
					hitAlias = "mpl_hit_alert_air";
					break;
				
				case "raps":
					hitAlias = "mpl_hit_alert_air";
					break;
										
				case "default_loud":
					hitAlias = "mpl_hit_heli_gunner";
					break;						
				
				default:
					hitAlias = "mpl_hit_alert";
					break;
			}
		}
		else if ( mod == "MOD_BURNED" )
		{
			hitAlias = "mpl_hit_alert_burn";
		}
		else
		{
			hitAlias = "mpl_hit_alert";
		}
	}
	
	if( isdefined( victim ) && IS_TRUE( victim.isAiClone ) )
	{
		self PlayHitMarker( hitAlias );
		return;
	}
	
	damageStage = 1; // always show at least stage 1 hit marker, per design
	if ( isdefined(level.growing_hitmarker) && isdefined(victim) && isplayer(victim) )
	{
		damageStage = damage_feedback_get_stage( victim );
	}
	self PlayHitMarker( hitAlias, damageStage, perkFeedback, damage_feedback_get_dead( victim, mod, weapon, damageStage ) );
	
	if ( isdefined( perkFeedback ) )
	{
		if ( isDefined( self.hud_damagefeedback_additional ) )
		{
			switch( perkFeedback )
			{
				case "flakjacket": 
					self.hud_damagefeedback_additional setShader( "damage_feedback_flak", 24, 48 );
				break; 
				case "tacticalMask": 
					self.hud_damagefeedback_additional setShader( "damage_feedback_tac", 24, 48 );
				break;
				case "armor":
					self.hud_damagefeedback_additional setShader( "damage_feedback_armor", 24, 48 );
				break;
			}
			self.hud_damagefeedback_additional.alpha = 1;
			self.hud_damagefeedback_additional fadeovertime(1);
			self.hud_damagefeedback_additional.alpha = 0;
		}
	}
	else
	{
		if (isDefined(self.hud_damagefeedback))
		{
				self.hud_damagefeedback setShader( "damage_feedback", 24, 48 );
		}
	}
	
	if (isDefined(self.hud_damagefeedback) && isdefined(level.growing_hitmarker) && isdefined(victim) && isplayer(victim) )
	{
		self thread damage_feedback_growth(victim, mod, weapon);
	}
	else if ( isDefined(self.hud_damagefeedback))
	{
		self.hud_damagefeedback.x = -12;
		self.hud_damagefeedback.y = -12;
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback fadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}
}

function damage_feedback_get_stage( victim )
{
 	if( isDefined( victim.laststand) && victim.laststand ) 		
 		return 5;
	else if ( (victim.health/victim.maxhealth) > .74 )
		return 1;
	else if ( (victim.health/victim.maxhealth) > .49 )
		return 2;
	else if ( (victim.health/victim.maxhealth) > .24 )
		return 3;
	else if ( (victim.health) > 0 )
		return 4;
	else
		return 5;
}

function damage_feedback_get_dead( victim, mod, weapon, stage )
{
	return ( stage == 5 && (mod == "MOD_BULLET" || mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET" || mod == "MOD_HEAD_SHOT") && (isdefined(weapon.isheroweapon) && !weapon.isheroweapon) && !killstreaks::is_killstreak_weapon( weapon ) && !( weapon.name === "siegebot_gun_turret" ) && !( weapon.name === "siegebot_launcher_turret" ) );
}

function damage_feedback_growth(victim, mod, weapon)
{
	if ( isdefined( self.hud_damagefeedback ) )
	{
		stage = damage_feedback_get_stage( victim );
	
		self.hud_damagefeedback.x = -11 + (-1 * (stage));
		self.hud_damagefeedback.y = -11 + (-1 * (stage));
		size_x = 22 + (2 * (stage) );
		size_y = size_x * 2;
		self.hud_damagefeedback setShader( "damage_feedback", size_x, size_y );
		
		if ( damage_feedback_get_dead( victim, mod, weapon, stage ) )
		{
			self.hud_damagefeedback setShader( "damage_feedback_glow_orange", size_x, size_y );
			self thread kill_hitmarker_fade ();
		}
		else
		{	
			self.hud_damagefeedback setShader( "damage_feedback", size_x, size_y );
			self.hud_damagefeedback.alpha = 1;
			self.hud_damagefeedback fadeOverTime(1);
			self.hud_damagefeedback.alpha = 0;
		}
	}
}

function kill_hitmarker_fade()
{
	self notify("kill_hitmarker_fade");
	self endon ("kill_hitmarker_fade");
	self endon ("disconnect");
	self.hud_damagefeedback.alpha = 1;
	wait 0.25;
	self.hud_damagefeedback fadeOverTime(0.3);
	self.hud_damagefeedback.alpha = 0;
}

function update_override( icon, sound, additional_icon )
{
	if ( !IsPlayer( self ) )
		return;

	self PlayLocalSound( sound );

	if ( IsDefined( self.hud_damagefeedback ) )
	{
		self.hud_damagefeedback setShader( icon, 24, 48 );
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback fadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}

	if ( isDefined( self.hud_damagefeedback_additional ) )
	{
		if ( !IsDefined( additional_icon ) )
		{
			self.hud_damagefeedback_additional.alpha = 0;
		}
		else
		{
			self.hud_damagefeedback_additional setShader( additional_icon, 24, 48 );
			self.hud_damagefeedback_additional.alpha = 1;
			self.hud_damagefeedback_additional fadeOverTime(1);
			self.hud_damagefeedback_additional.alpha = 0;
		}
	}
}

function update_special( hitEnt )
{
	if ( !isPlayer( self ) )
		return;
	
	if ( !isdefined(hitEnt) )
		return;
		
	if ( !isPlayer( hitEnt ) )
		return;

	WAIT_SERVER_FRAME;
	if ( !isdefined( self.directionalHitArray ) )
	{
		self.directionalHitArray = [];
		hitEntNum = hitEnt getEntityNumber();
		self.directionalHitArray[hitEntNum] = 1;
		self thread send_hit_special_event_at_frame_end(hitEnt);
	}
	else
	{
		hitEntNum = hitEnt getEntityNumber();
		self.directionalHitArray[hitEntNum] = 1;
	}
}

function send_hit_special_event_at_frame_end(hitEnt)
{
	self endon ("disconnect");
	waittillframeend;

	enemysHit = 0;
	value = 1;
		
	entBitArray0 = 0;
	for ( i = 0; i < 32; i++ )
	{
		if (isdefined (self.directionalHitArray[i]) && self.directionalHitArray[i] != 0 )
		{
			entBitArray0 += value;
			enemysHit++;
		}
		value *= 2;
	}	
	entBitArray1 = 0;
	for (  i = 33; i < 64; i++ )
	{
		if (isdefined (self.directionalHitArray[i]) && self.directionalHitArray[i] != 0 )
		{
			entBitArray1 += value;
			enemysHit++;
		}
		value *= 2;
	}
	

	if ( enemysHit )
	{
		self directionalHitIndicator( entBitArray0, entBitArray1 );
	}
	self.directionalHitArray = undefined;
	entBitArray0 = 0;
	entBitArray1 = 0;
}

function doDamageFeedback( weapon, eInflictor, iDamage, sMeansOfDeath )
{
	if ( !isdefined( weapon ) )
		return false;
		
	if (IS_TRUE(weapon.nohitmarker)	)
		return false;

	if ( level.allowHitMarkers == 0 ) 
		return false;

	if ( level.allowHitMarkers == 1 ) // no tac grenades
	{
		if ( isdefined( sMeansOfDeath ) && isdefined( iDamage ) ) 
		{
			if ( isTacticalHitMarker( weapon, sMeansOfDeath, iDamage ) )
			{
				return false;
			}
		}
	}
	
	return true;
}


function isTacticalHitMarker( weapon, sMeansOfDeath, iDamage )
{
	if ( weapons::is_grenade( weapon ) )
	{
		if ( "Smoke Grenade" == weapon.offhandClass ) 
		{
			if ( sMeansOfDeath == "MOD_GRENADE_SPLASH" )
				return true;
		}
		else if ( iDamage == 1 )
		{
			return true;
		}
	}	
	return false;
}
