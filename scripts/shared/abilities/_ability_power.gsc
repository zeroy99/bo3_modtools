#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\abilities\_ability_gadgets;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace ability_power;

REGISTER_SYSTEM( "ability_power", &__init__, undefined )

function __init__()
{
	callback::on_connect( &on_player_connect );
}

//---------------------------------------------------------
// power and gadget activation

function on_player_connect()
{	
}

function power_is_hero_ability( gadget )
{
	return gadget.gadget_type != GADGET_TYPE_NONE;
}

function is_weapon_or_variant_same_as_gadget( weapon, gadget )
{
	if ( weapon == gadget )
	{
		return true;
	}
	
	if ( isdefined( level.weaponLightningGun ) && gadget == level.weaponLightningGun )
	{
		if ( isdefined( level.weaponLightningGunArc ) && weapon == level.weaponLightningGunArc )
		{
			return true;
		}
	}	
	
	return false;
}

function power_gain_event_score( eAttacker, score, weapon, hero_restricted )
{
	if( score > 0 )
	{
		for ( slot = GADGET_HELD_0; slot < GADGET_HELD_COUNT; slot++ )
		{
			gadget = self._gadgets_player[slot];
			
			if ( isdefined( gadget ) )
			{	
				ignoreSelf = gadget.gadget_powerGainScoreIgnoreSelf;

				if ( isdefined( weapon ) && ignoreSelf && is_weapon_or_variant_same_as_gadget( weapon, gadget ) )
				{
					continue;
				}

				ignoreWhenActive = gadget.gadget_powerGainScoreIgnoreWhenActive;
				
				if ( ignoreWhenActive && self GadgetIsActive( slot ) )
				{
					continue;
				}				
				
				if ( isdefined( hero_restricted ) && hero_restricted && power_is_hero_ability( gadget ) )
				{
					continue;
				}	
				
				scoreFactor = gadget.gadget_powerGainScoreFactor;
				if ( isdefined( self.gadgetThiefActive ) && self.gadgetThiefActive == true )
				{
					continue; // handled exclusively by gadget_thief
				}
				
				gametypeFactor = GetGametypeSetting( "scoreHeroPowerGainFactor" );

				perkFactor = 1.0;
				if ( self hasperk( "specialty_overcharge" ) )
				{
					perkFactor = GetDvarFloat( "gadgetPowerOverchargePerkScoreFactor" ); 
				}
				
				if ( scoreFactor > 0 && gametypeFactor > 0 )
				{				
					gainToAdd = score * scoreFactor * gametypeFactor * perkFactor;
					self power_gain_event( slot, eAttacker, gainToAdd, "score" );
				}				
			}
		}
	}
}

function power_gain_event_damage_actor( eAttacker )
{
	baseGain = 0.0;
	
	if( baseGain > 0 )
	{
		for ( slot = GADGET_HELD_0; slot < GADGET_HELD_COUNT; slot++ )
		{
			if ( IsDefined( self._gadgets_player[slot] ) )
			{
				self power_gain_event( slot, eAttacker, baseGain, "damaged actor" );
			}
		}
	}
}

function power_gain_event_killed_actor( eAttacker, meansOfDeath )
{
	baseGain = 5.0;	

	for ( slot = GADGET_HELD_0; slot < GADGET_HELD_COUNT; slot++ )
	{
		if ( IsDefined( self._gadgets_player[slot] ) )
		{
			if ( meansOfDeath == "MOD_MELEE_ASSASSINATE" && self ability_util::gadget_is_camo_suit_on() )
			{
				if ( self._gadgets_player[slot].gadget_powertakedowngain > 0 )
				{
					source = "assassinate actor";
					self power_gain_event( slot, eAttacker, self._gadgets_player[slot].gadget_powertakedowngain, source );
				}
			}
	
			if ( self._gadgets_player[slot].gadget_powerreplenishfactor > 0 )
			{			
				gainToAdd = baseGain * self._gadgets_player[slot].gadget_powerreplenishfactor;
				if ( gainToAdd > 0 )
				{
					source = "killed actor";
					self power_gain_event( slot, eAttacker, gainToAdd, source );
				}
			}
		}
	}
}

function power_gain_event( slot, eAttacker, val, source )
{
	if ( !isdefined( self ) || !isalive( self ) )
	{
		return;
	}
	
	powerToAdd = val;

	if ( powerToAdd > 0.1 || powerToAdd < -0.1 )
	{
		powerLeft = self GadgetPowerChange( slot, powerToAdd );
	}
}

function power_loss_event_took_damage( eAttacker, eInflictor, weapon, sMeansOfDeath, iDamage )
{
	baseLoss = iDamage;

	for ( slot = GADGET_HELD_0; slot < GADGET_HELD_COUNT; slot++ )
	{
		if ( IsDefined( self._gadgets_player[slot] ) )
		{
			if ( self GadgetIsActive( slot ) )
			{
				powerLoss = baseLoss * self._gadgets_player[slot].gadget_powerOnLossOnDamage;
				if ( powerLoss > 0 )
				{
					self power_loss_event( slot, eAttacker, powerLoss, "took damage with power on" );					
				}
				
				if ( self._gadgets_player[slot].gadget_flickerOnDamage > 0 )
				{
					self ability_gadgets::SetFlickering( slot, self._gadgets_player[slot].gadget_flickerOnDamage );
				}
			}
			else
			{
				powerLoss = baseLoss * self._gadgets_player[slot].gadget_powerOffLossOnDamage;
				if ( powerLoss > 0 )
				{
					self power_loss_event( slot, eAttacker, powerLoss, "took damage" );
				}
			}		
		}	
	}
}

function power_loss_event( slot, eAttacker, val, source )
{
	powerToRemove = -val;

	if ( powerToRemove > 0.1 || powerToRemove < -0.1 )
	{
		powerLeft = self GadgetPowerChange( slot, powerToRemove );		
	}
}

function power_drain_completely( slot )
{
	powerLeft = self GadgetPowerChange( slot, 0 );		
	powerLeft = self GadgetPowerChange( slot, -powerLeft );		
}

function IsMovingPowerloss()
{
	velocity = self GetVelocity();
	speedsq = lengthsquared( velocity );

	return speedsq > self._gadgets_player.gadget_powermovespeed * self._gadgets_player.gadget_powermovespeed;
}

function power_consume_timer_think( slot, weapon )
{
	self endon( "disconnect" );
	self endon( "death" );

	time =  GetTime();

	while ( 1 )
	{		
		wait( 0.1 );		
		
		if ( !IsDefined( self._gadgets_player[slot] ) )
		{
			return;
		}

		if ( !self GadgetIsActive( slot ) )
		{
			return;
		}

		currentTime =  GetTime();
		interval = currentTime - time;
		time = currentTime;
		powerConsumpted = 0;

		//sprint
		if( self IsOnGround() )
		{
			if ( self._gadgets_player[slot].gadget_powersprintloss > 0 && self IsSprinting() )
			{
				powerConsumpted += 1.0 * interval / 1000 * self._gadgets_player[slot].gadget_powersprintloss;				
			}
			//move
			else if ( self._gadgets_player[slot].gadget_powermoveloss && self IsMovingPowerloss() )
			{
				powerConsumpted += 1.0 * interval / 1000 * self._gadgets_player[slot].gadget_powermoveloss;
			}
		}

		//--jump
		//--juke
		//--melee
		//--attack

		if ( powerConsumpted > 0.1 )
		{
			self power_loss_event( slot, self, powerConsumpted, "consume" );
			if ( self._gadgets_player[slot].gadget_flickerOnPowerloss > 0 )
			{
				self ability_gadgets::SetFlickering( slot, self._gadgets_player[slot].gadget_flickerOnPowerloss );
			}
		}
	}
}
