#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\bots\_bot;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\weapons\replay_gun;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_gadgets;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#using scripts\shared\abilities\gadgets\_gadget_armor; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_speed_burst;   // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_camo;   // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_vision_pulse; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_hero_weapon; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_other; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_combat_efficiency; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_flashback; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_cleanse; // for loading purposes only - do not use from here

#using scripts\shared\abilities\gadgets\_gadget_system_overload; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_servo_shortout; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_exo_breakdown; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_surge; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_security_breach; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_iff_override; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_cacophany; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_es_strike; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_ravage_core; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_concussive_wave; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_overdrive; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_unstoppable_force; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_rapid_strike; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_sensory_overload; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_forced_malfunction; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_immolation; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_firefly_swarm; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_smokescreen; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_misdirection; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_mrpukey; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_active_camo; // for loading purposes only - do not use from here

#using scripts\shared\abilities\gadgets\_gadget_shock_field; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_resurrect; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_heat_wave; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_clone; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_roulette; // for loading purposes only - do not use from here
#using scripts\shared\abilities\gadgets\_gadget_thief; // for loading purposes only - do not use from here

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\statstable_shared.gsh;

#namespace ability_player;

REGISTER_SYSTEM( "ability_player", &__init__, undefined )

//---------------------------------------------------------
// Init
function __init__()
{
	init_abilities();

	setup_clientfields();
	
	level thread gadgets_wait_for_game_end();

	callback::on_connect(&on_player_connect);
	callback::on_spawned( &on_player_spawned );
	callback::on_disconnect( &on_player_disconnect );
	
	DEFAULT( level._gadgets_level, [] );
}

function init_abilities()
{
}

function setup_clientfields()
{
}

function on_player_connect()
{
	DEFAULT( self._gadgets_player, [] );	
}

function on_player_spawned()
{	
	self thread gadgets_wait_for_death();
	self.heroAbilityActivateTime = undefined;
	self.heroAbilityDectivateTime = undefined;
	self.heroAbilityActive = undefined;
}

function on_player_disconnect()
{
}

function is_using_any_gadget()
{
	if ( !isPlayer( self ) )
		return false;
	
	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( self gadget_is_in_use( i ) )
		{
			return true;
		}
	}	
	
	return false;
}

function gadgets_save_power( game_ended )
{
	for ( slot = GADGET_HELD_0; slot < GADGET_HELD_COUNT; slot++ )
	{			
		if ( !isdefined( self._gadgets_player[slot] ) )
		{
			continue;
		}			
			
		gadgetWeapon = self._gadgets_player[slot];
		
		powerLeft = self GadgetPowerChange( slot, 0.0 );
		
		if ( game_ended && gadget_is_in_use( slot ) )
		{
			self GadgetDeactivate( slot, gadgetweapon );
			
			if ( gadgetWeapon.gadget_power_round_end_active_penalty > 0 )
			{
				powerLeft = powerLeft - gadgetWeapon.gadget_power_round_end_active_penalty;
				powerLeft = max( 0.0, powerLeft );
			}			
		}
			
		self.pers["held_gadgets_power"][gadgetWeapon] = powerLeft;
	}
}

function gadgets_wait_for_death()
{
	self endon( "disconnect" );

	self.pers["held_gadgets_power"] = [];

	self waittill( "death" );

	if ( !isdefined( self._gadgets_player ) )
	{
		return;
	}	
		
	self gadgets_save_power( false );
}

function gadgets_wait_for_game_end()
{	
	level waittill( "game_ended" );	
	
	players = GetPlayers();
	
	foreach ( player in players )
	{
		if ( !IsAlive( player ) )
		{
			continue;
		}
		
		if ( !isdefined( player._gadgets_player ) )
		{
			continue;
		}
		
		player gadgets_save_power( true );
	}
}

// Call this to change player class from script	
function script_set_cclass( cclass, save = true )
{
}

//---------------------------------------------------------
// gadgets

function update_gadget( weapon )
{	
}

function register_gadget( type )
{
	DEFAULT( level._gadgets_level, [] );

	if ( !IsDefined( level._gadgets_level[ type ] ) )
	{
		level._gadgets_level[ type ] = spawnstruct();
		level._gadgets_level[ type ].should_notify = true;
	}
}

function register_gadget_should_notify( type, should_notify )
{
	register_gadget( type ); 
	
	if( isDefined( should_notify ) )
	{
		level._gadgets_level[ type ].should_notify = should_notify;
	}
}

function register_gadget_possession_callbacks( type, on_give, on_take )
{
	register_gadget( type ); 

	DEFAULT(level._gadgets_level[ type ].on_give, []);
	DEFAULT(level._gadgets_level[ type ].on_take, []);
	if ( IsDefined(on_give) )
	{
		ARRAY_ADD(level._gadgets_level[ type ].on_give,on_give);
	}
	if ( IsDefined(on_take) )
	{
		ARRAY_ADD(level._gadgets_level[ type ].on_take,on_take);
	}
}

function register_gadget_activation_callbacks( type, turn_on, turn_off )
{
	register_gadget( type );

	DEFAULT(level._gadgets_level[ type ].turn_on, []);
	DEFAULT(level._gadgets_level[ type ].turn_off, []);
	if ( IsDefined(turn_on) )
	{
		ARRAY_ADD(level._gadgets_level[ type ].turn_on,turn_on);
	}
	if ( IsDefined(turn_off) )
	{
		ARRAY_ADD(level._gadgets_level[ type ].turn_off,turn_off);
	}
}

function register_gadget_flicker_callbacks( type, on_flicker )
{
	register_gadget( type );

	DEFAULT( level._gadgets_level[ type ].on_flicker, [] );

	if ( IsDefined( on_flicker ) )
	{
		ARRAY_ADD( level._gadgets_level[ type ].on_flicker, on_flicker );
	}
}

function register_gadget_ready_callbacks( type, ready_func )
{
	register_gadget( type ); 

	DEFAULT( level._gadgets_level[ type ].on_ready, [] );

	if ( IsDefined( ready_func ) )
	{
		ARRAY_ADD( level._gadgets_level[ type ].on_ready, ready_func );
	}
}

function register_gadget_primed_callbacks( type, primed_func )
{
	register_gadget( type ); 

	DEFAULT( level._gadgets_level[ type ].on_primed, [] );

	if ( IsDefined( primed_func ) )
	{
		ARRAY_ADD( level._gadgets_level[ type ].on_primed, primed_func );
	}
}

function register_gadget_is_inuse_callbacks( type, inuse_func )
{
	register_gadget( type );
	
	if ( IsDefined( inuse_func ) )
	{
		level._gadgets_level[ type ].isInUse = inuse_func;
	}
}

function register_gadget_is_flickering_callbacks( type, flickering_func )
{
	register_gadget( type ); 

	if ( IsDefined( flickering_func ) )
	{
		level._gadgets_level[ type ].isFlickering = flickering_func;
	}
}

function register_gadget_failed_activate_callback( type, failed_activate )
{
	register_gadget( type );

	DEFAULT( level._gadgets_level[ type ].failed_activate, [] );

	if ( IsDefined( failed_activate ) )
	{
		ARRAY_ADD( level._gadgets_level[ type ].failed_activate, failed_activate );
	}
}

function gadget_is_in_use( slot )
{
	if ( IsDefined( self._gadgets_player[slot] ) )
	{
		if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
		{
			if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].isInUse ) )
			{
				return self [[level._gadgets_level[ self._gadgets_player[slot].gadget_type ].isInUse]]( slot );
			}
		}
	}
	
	return self GadgetIsActive( slot );
}

function gadget_is_flickering( slot )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return false;
	}

	if ( !IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].isFlickering ) )
	{
		return false;
	}

	return self [[level._gadgets_level[ self._gadgets_player[slot].gadget_type ].isFlickering]]( slot );
}

function give_gadget( slot, weapon )
{
	if ( IsDefined( self._gadgets_player[slot] ) )
	{
		self take_gadget( slot, self._gadgets_player[slot] );
	}
	
	for ( eSlot = GADGET_HELD_0; eSlot < GADGET_HELD_COUNT; eSlot++ )
	{
		existingGadget	= self._gadgets_player[eSlot];
		
		if ( IsDefined( existingGadget ) && existingGadget == weapon )
		{
			self take_gadget( eSlot, existingGadget );
		}
	}

	self._gadgets_player[slot] = weapon;
	
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}

	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_give ) )
		{
			foreach( on_give in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_give )
				self [[on_give]]( slot, weapon );
		}	
	}
	
	if ( SessionModeIsMultiplayerGame() )
	{
		self.heroAbilityName = ( isdefined( weapon ) ? weapon.name : undefined );
	}
}

function take_gadget( slot, weapon )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}	
	
	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_take ) )
		{
			foreach( on_take in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_take )
				self [[on_take]]( slot, weapon );
		}
	}	
	
	self._gadgets_player[slot] = undefined;

}

function turn_gadget_on( slot, weapon )
{	    
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}
	
	self.playedGadgetSuccess = false;
	
	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].turn_on ) )
		{
			foreach( turn_on in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].turn_on )
			{
				self [[turn_on]]( slot, weapon );

				self trackHeroPowerActivated( game["timepassed"] );
				
				level notify( "hero_gadget_activated", self, weapon );
				self notify( "hero_gadget_activated", weapon );
			}
		}
	}
	
	if( IsDefined( level.cybercom ) && IsDefined( level.cybercom._ability_turn_on ) )
	{
		self [[level.cybercom._ability_turn_on]]( slot, weapon );
	}
	
	// Make this persistant so we don't re-notify when a new round begins
	self.pers["heroGadgetNotified"] = false;
	
	xuid = self GetXUID();

	
	if ( isdefined( level.playGadgetActivate ) )
	{
		self [[level.playGadgetActivate]]( weapon );
	}
	
	if ( weapon.gadget_type != GADGET_TYPE_HERO_WEAPON )
	{		
		if ( isdefined ( self.isNearDeath ) && self.isNearDeath == true )
		{
			if ( isdefined( level.heroAbilityActivateNearDeath ) )
			{
				[[level.heroAbilityActivateNearDeath]]();
			}
		}
		self.heroAbilityActivateTime = getTime();
		self.heroAbilityActive = true;
		self.heroAbility = weapon;
	} 
	
	self thread ability_power::power_consume_timer_think( slot, weapon );
}

function turn_gadget_off( slot, weapon )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}
	
	if ( !IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		return;
	}

	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].turn_off ) )
	{
		foreach( turn_off in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].turn_off )
		{
			self [[turn_off]]( slot, weapon );

			// self.heroweaponShots and self.heroweaponHits may be undefined, and that's ok
			dead = self.health <= 0;
			self trackHeroPowerExpired( game["timepassed"], dead, self.heroweaponShots, self.heroweaponHits );

		}
	}	
	
	if( IsDefined( level.cybercom ) && IsDefined( level.cybercom._ability_turn_off ) )
	{
		self [[level.cybercom._ability_turn_off]]( slot, weapon );
	}
	
	if ( weapon.gadget_type != GADGET_TYPE_HERO_WEAPON )
	{
		if ( self IsEMPJammed() == true )
		{
			self GadgetTargetResult( false );

			if ( isdefined( level.callbackEndHeroSpecialistEMP ) )
			{
				if ( isdefined( weapon.gadget_turnoff_onempjammed ) && weapon.gadget_turnoff_onempjammed == true ) 
				{
					self thread [[level.callbackEndHeroSpecialistEMP]]();
				}
			}
		}
		
		self.heroAbilityDectivateTime = getTime();
		self.heroAbilityActive = undefined;
		self.heroAbility = weapon;
	}
	
	self notify( "heroAbility_off", weapon );
		
	xuid = self GetXUID();
	
	if ( IS_TRUE( level.oldschool ) )
	{
		self TakeWeapon( weapon );
	}
}

function gadget_CheckHeroAbilityKill( attacker )
{
	heroAbilityStat = false;
	
	if ( isdefined( attacker.heroAbility ) )
	{
		switch( attacker.heroAbility.name )
		{
			case "gadget_armor":
			case "gadget_clone":
			case "gadget_speed_burst":
			case "gadget_heat_wave":
			{
				if ( isdefined( attacker.heroAbilityActive ) || ( isdefined( attacker.heroAbilityDectivateTime ) && attacker.heroAbilityDectivateTime > gettime() - 100 ) )
				{
					heroAbilityStat = true;
				}
				break;
			}
			case "gadget_camo":
			case "gadget_flashback":
			case "gadget_resurrect":
			{
				if ( isdefined( attacker.heroAbilityActive ) 
					    || ( isdefined( attacker.heroAbilityDectivateTime ) && attacker.heroAbilityDectivateTime > gettime() - 6000 ) )
				{
					heroAbilityStat = true;
				}
				break;
			}				
			case "gadget_vision_pulse":	     
			{
				if ( isdefined( attacker.visionPulseSpottedEnemyTime ) )
				{
					timeCutoff = getTime();
					if ( attacker.visionPulseSpottedEnemyTime + 10000 > timeCutoff )
					{
						for ( i = 0; i < attacker.visionPulseSpottedEnemy.size; i++ )
						{
							spottedEnemy = attacker.visionPulseSpottedEnemy[i];
							if ( spottedEnemy == self ) 
							{
								if (  self.lastSpawnTime < attacker.visionPulseSpottedEnemyTime )
								{
									heroAbilityStat = true;
									break;
								}
							}
						}
					}
				}
			}
			case "gadget_combat_efficiency":
			{
				if ( isdefined( attacker._gadget_combat_efficiency  ) && attacker._gadget_combat_efficiency == true )
				{
					heroAbilityStat = true;
					break;
				}
				else if ( isdefined( attacker.combatEfficiencyLastOnTime ) && attacker.combatEfficiencyLastOnTime > gettime() - 100 )
				{
					heroAbilityStat = true;
					break;
				}
			}
		}
	}
	return heroAbilityStat;
}


function gadget_flicker( slot, weapon )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}
	
	if ( !IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		return;
	}
	
	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_flicker ) )
	{
		foreach( on_flicker in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_flicker )
			self [[on_flicker]]( slot, weapon );
	}
}

function gadget_ready( slot, weapon )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}
	
	if ( !IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		return;
	}
	
	if( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].should_notify ) && level._gadgets_level[ self._gadgets_player[slot].gadget_type ].should_notify )
	{
		if ( IsDefined( level.statsTableID ) )
		{
			itemRow = tableLookupRowNum( level.statsTableID, STATS_TABLE_COL_REFERENCE, self._gadgets_player[slot].name );
			if ( itemRow > -1 )
			{
				index = int(tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_NUMBERING ));
				if ( index != 0 )
				{
					self LUINotifyEvent( &"hero_weapon_received", 1, index );
					self LUINotifyEventToSpectators( &"hero_weapon_received", 1, index );
				}
			}
		}
		
		if ( !isdefined( level.gameEnded ) || !level.gameEnded )
		{
			if ( !isdefined( self.pers["heroGadgetNotified"] ) || !self.pers["heroGadgetNotified"] )
			{
				self.pers["heroGadgetNotified"] = true;
				
				if ( isdefined( level.playGadgetReady ) )
				{
					self [[level.playGadgetReady]]( weapon );
				}
	
				self trackHeroPowerAvailable( game["timepassed"] );
			}
		}
	}
	
	xuid = self GetXUID();

	// Do gadget callback last, as it can modify the gadget itself ( roulette )
	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_ready ) )
	{
		foreach( on_ready in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_ready )
			self [[on_ready]]( slot, weapon );
	}
}

function gadget_primed( slot, weapon )
{
	if ( !IsDefined( self._gadgets_player[slot] ) )
	{
		return;
	}
	
	if ( !IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ] ) )
	{
		return;
	}
	
	if ( IsDefined( level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_primed ) )
	{
		foreach( on_primed in level._gadgets_level[ self._gadgets_player[slot].gadget_type ].on_primed )
			self [[on_primed]]( slot, weapon );
	}
}

