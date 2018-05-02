#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\rank_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\weapons\_weapon_utils;

#insert scripts\shared\abilities\gadgets\_gadget_vision_pulse.gsh;
#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic_score;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\_teamops;

#insert scripts\shared\scoreevents_shared.gsh;

#namespace scoreevents;

REGISTER_SYSTEM( "scoreevents", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
}

function init()
{
	level.scoreEventCallbacks = [];
	level.scoreEventGameEndCallback =&onGameEnd;
	
	registerScoreEventCallback( "playerKilled", &scoreevents::scoreEventPlayerKill );	
}
function scoreEventTableLookupInt( index, scoreEventColumn )
{
	return int( tableLookup( getScoreEventTableName(), 0, index, scoreEventColumn ) );
}

function scoreEventTableLookup( index, scoreEventColumn )
{
	return tableLookup( getScoreEventTableName(), 0, index, scoreEventColumn );
}

function registerScoreEventCallback( callback, func )
{
	if ( !isdefined( level.scoreEventCallbacks[callback] ) )
	{
		level.scoreEventCallbacks[callback] = [];
	}
	level.scoreEventCallbacks[callback][level.scoreEventCallbacks[callback].size] = func;
}

function scoreEventPlayerKill( data, time )
{
	victim = data.victim;
	attacker = data.attacker;
	time = data.time;
	level.numKills++;
	attacker.lastKilledPlayer = victim;
	wasDefusing = data.wasDefusing;
	wasPlanting = data.wasPlanting;
	victimWasOnGround = data.victimOnGround;
	attackerWasOnGround = data.attackerOnGround;
	meansOfDeath = data.sMeansOfDeath;
	attackerTraversing = data.attackerTraversing;
	attackerWallRunning = data.attackerWallRunning;
	attackerDoubleJumping = data.attackerDoubleJumping;	
	attackerSliding = data.attackerSliding;	
	victimWasWallRunning = data.victimWasWallRunning;
	victimWasDoubleJumping = data.victimWasDoubleJumping;
	attackerSpeedburst = data.attackerSpeedburst;
	victimSpeedburst = data.victimSpeedburst;
	victimCombatEfficieny = data.victimCombatEfficieny;
	attackerflashbackTime = data.attackerflashbackTime;
	victimflashbackTime = data.victimflashbackTime;
	victimSpeedburstLastOnTime = data.victimSpeedburstLastOnTime;
	victimCombatEfficiencyLastOnTime = data.victimCombatEfficiencyLastOnTime;
	victimVisionPulseActivateTime = data.victimVisionPulseActivateTime;
	attackerVisionPulseActivateTime = data.attackerVisionPulseActivateTime;
	victimVisionPulseActivateTime = data.victimVisionPulseActivateTime;
	attackerVisionPulseArray = data.attackerVisionPulseArray;
	victimVisionPulseArray = data.victimVisionPulseArray;
	attackerVisionPulseOriginArray = data.attackerVisionPulseOriginArray;
	victimVisionPulseOriginArray = data.victimVisionPulseOriginArray;
	attackerVisionPulseOrigin = data.attackerVisionPulseOrigin;
	victimVisionPulseOrigin = data.victimVisionPulseOrigin;
	attackerWasFlashed = data.attackerWasFlashed;
	attackerWasConcussed = data.attackerWasConcussed;
	victimWasUnderwater = data.wasUnderwater;
	victimHeroAbilityActive = data.victimHeroAbilityActive;
	victimHeroAbility = data.victimHeroAbility;
	attackerHeroAbilityActive = data.attackerHeroAbilityActive;
	attackerHeroAbility = data.attackerHeroAbility;
	attackerWasHeatWaveStunned = data.attackerWasHeatWaveStunned;
	victimWasHeatWaveStunned = data.victimWasHeatWaveStunned;
	victimElectrifiedBy = data.victimElectrifiedBy;
	victimWasInSlamState = data.victimWasInSlamState;
	victimBledOut = data.bledOut;
	victimWasLungingWithArmBlades = data.victimWasLungingWithArmBlades;
	victimPowerArmorLastTookDamageTime = data.victimPowerArmorLastTookDamageTime;
	victimHeroWeaponKillsThisActivation = data.victimHeroWeaponKillsThisActivation;
	victimGadgetPower = data.victimGadgetPower;
	victimGadgetWasActiveLastDamage = ( data.victimGadgetWasActiveLastDamage === true );
	victimIsThiefOrRoulette = data.victimIsThiefOrRoulette;
	attackerIsRoulette = data.attackerIsRoulette;
	victimHeroAbilityName = data.victimHeroAbilityName; // note that victim hero ability name cannot be reliably taken from victimHeroAbility, so this is done instead
	attackerInVehicleArchetype = data.attackerInVehicleArchetype;
	if ( isdefined( victimHeroAbilityName ) )
		victimHeroAbilityEquipped = GetWeapon( victimHeroAbilityName );
	
	if ( victimBledOut == true ) // do not process player killed score events if the player bled out
		return;
	
	exlosiveDamage = false;
	attackerShotVictim = ( meansOfDeath == "MOD_PISTOL_BULLET" || meansOfDeath == "MOD_RIFLE_BULLET" || meansOfDeath == "MOD_HEAD_SHOT" );
	
	weapon = level.weaponNone;
	inflictor =	data.eInflictor;
	isGrenade = false;
	if ( isdefined( data.weapon ) )
	{
		weapon = data.weapon;
		weaponClass = util::getWeaponClass( data.weapon );
		isGrenade = weapon.isGrenadeWeapon;
		killstreak = killstreaks::get_from_weapon( data.weapon );
	}

	victim.anglesOnDeath = victim getPlayerAngles();

	if ( meansOfDeath == "MOD_GRENADE" || meansOfDeath == "MOD_GRENADE_SPLASH" || meansOfDeath == "MOD_EXPLOSIVE"  || meansOfDeath == "MOD_EXPLOSIVE_SPLASH" ||  meansOfDeath == "MOD_PROJECTILE" || meansOfDeath == "MOD_PROJECTILE_SPLASH" )
	{
		if ( weapon == level.weaponNone && isdefined( data.victim.explosiveInfo["weapon"] ) )
			weapon = data.victim.explosiveInfo["weapon"];
		
		exlosiveDamage = true;
	}


	if ( !isdefined( killstreak ) )
	{		
		if ( level.teamBased )
		{	
			if ( isdefined( victim.lastKillTime ) && ( victim.lastKillTime > time - 3000 ) )
			{
				if ( isdefined( victim.lastkilledplayer ) && victim.lastkilledplayer util::IsEnemyPlayer( attacker ) == false && attacker != victim.lastkilledplayer )
				{
					processScoreEvent( "kill_enemy_who_killed_teammate", attacker, victim, weapon );
					victim RecordKillModifier("avenger");
				}
			}
			
			if ( isdefined( victim.damagedPlayers ) )
			{
				keys = getarraykeys(victim.damagedPlayers);
		
				for ( i = 0; i < keys.size; i++ )
				{
					key = keys[i];
					if ( key == attacker.clientid )
						continue;
					
					if ( !isdefined( victim.damagedPlayers[key].entity ) )
						continue;
					
					if ( attacker util::IsEnemyPlayer( victim.damagedPlayers[key].entity ) )
						continue;
		
					if ( ( time - victim.damagedPlayers[key].time ) < 1000 )
					{
						processScoreEvent( "kill_enemy_injuring_teammate", attacker, victim, weapon );
						if ( isdefined( victim.damagedPlayers[key].entity ) )
						{
							victim.damagedPlayers[key].entity.lastRescuedBy = attacker;
							victim.damagedPlayers[key].entity.lastRescuedTime = time;
						}
						victim RecordKillModifier("defender");
					}
				}
			}
		}
			
		if ( isGrenade == false || ( weapon.name == "hero_gravityspikes" ) )
		{
			if ( victimWasDoubleJumping == true  )
			{
				if ( attackerDoubleJumping == true )
				{
					processScoreEvent( "kill_enemy_while_both_in_air", attacker, victim, weapon );	
				}
				
				processScoreEvent( "kill_enemy_that_is_in_air", attacker, victim, weapon );
				attacker addPlayerStat( "kill_enemy_that_in_air", 1 );
			}
	
			if ( attackerDoubleJumping == true )
			{
				processScoreEvent( "kill_enemy_while_in_air", attacker, victim, weapon );
				attacker addPlayerStat( "kill_while_in_air", 1 );
			}
	
			if ( victimWasWallRunning == true )
			{
				processScoreEvent( "kill_enemy_that_is_wallrunning", attacker, victim, weapon );
				attacker addPlayerStat( "kill_enemy_thats_wallrunning", 1 );
			}
	
			if ( attackerWallRunning == true )
			{
				processScoreEvent( "kill_enemy_while_wallrunning", attacker, victim, weapon );
				attacker addPlayerStat( "kill_while_wallrunning", 1 );
			}
	
			if ( attackerSliding == true )
			{
				processScoreEvent( "kill_enemy_while_sliding", attacker, victim, weapon );
				attacker addPlayerStat( "kill_while_sliding", 1 );
			}
	
			if ( attackerTraversing == true )
			{
				processScoreEvent( "traversal_kill", attacker, victim, weapon );
				attacker addPlayerStat( "kill_while_mantling", 1 );
			}

			if ( attackerWasFlashed )
			{
				processScoreEvent( "kill_enemy_while_flashbanged", attacker, victim, weapon );			
			}
		
			if ( attackerWasConcussed )	
			{
				processScoreEvent( "kill_enemy_while_stunned", attacker, victim, weapon );
			}
		
			if ( attackerWasHeatWaveStunned )
			{
				processScoreEvent( "kill_enemy_that_heatwaved_you", attacker, victim, weapon );
				attacker util::player_contract_event( "killed_hero_ability_enemy" );
			}
			
			if ( victimWasHeatWaveStunned )
			{
				if ( isdefined( victim._heat_wave_stunned_by ) &&
				     isdefined( victim._heat_wave_stunned_by[attacker.clientid] ) &&
				     victim._heat_wave_stunned_by[attacker.clientid] >= time )
				{
					processScoreEvent( "heatwave_kill", attacker, victim, weapon );
					attacker hero_ability_kill_event( getWeapon( "gadget_heat_wave" ), get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
				}
				
				if ( attackerIsRoulette && !victimIsThiefOrRoulette && victimHeroAbilityName === "gadget_heat_wave" )
				{
					processScoreEvent( "kill_enemy_with_their_hero_ability", attacker, victim, weapon );
				}				
			}
		}

		if ( attackerSpeedburst == true )
		{
			processScoreEvent( "speed_burst_kill", attacker, victim, weapon );
			attacker hero_ability_kill_event( GetWeapon( "gadget_speed_burst" ), get_equipped_hero_ability( victimHeroAbilityName ) );
			attacker specialistMedalAchievement();
			attacker thread specialistStatAbilityUsage( 4, false );
			
			if ( attackerIsRoulette && !victimIsThiefOrRoulette && victimHeroAbilityName === "gadget_speed_burst" )
			{
				processScoreEvent( "kill_enemy_with_their_hero_ability", attacker, victim, weapon );
			}
		}
		
		if ( victimSpeedburstLastOnTime > time - 50 )
		{
			processScoreEvent( "kill_enemy_who_is_speedbursting", attacker, victim, weapon );
			attacker util::player_contract_event( "killed_hero_ability_enemy" );
		}

		if ( victimCombatEfficiencyLastOnTime > time - 50 )
		{
			processScoreEvent( "kill_enemy_who_is_using_focus", attacker, victim, weapon );
			attacker util::player_contract_event( "killed_hero_ability_enemy" );
		}			

		if ( attackerflashbackTime != 0 && attackerflashbackTime > time - 4000 )
		{
			processScoreEvent( "flashback_kill", attacker, victim, weapon );
			attacker hero_ability_kill_event( GetWeapon( "gadget_flashback" ), get_equipped_hero_ability( victimHeroAbilityName ) );
			attacker specialistMedalAchievement();
			attacker thread specialistStatAbilityUsage( 4, false );
			
			if ( attackerIsRoulette && !victimIsThiefOrRoulette && victimHeroAbilityName === "gadget_flashback" )
			{
				processScoreEvent( "kill_enemy_with_their_hero_ability", attacker, victim, weapon );
			}
		}

		if ( victimflashbackTime != 0 && victimflashbackTime > time - 4000 )
		{
			processScoreEvent( "kill_enemy_who_has_flashbacked", attacker, victim, weapon );
			attacker util::player_contract_event( "killed_hero_ability_enemy" );
		}
		
		if ( victimWasInSlamState ) 
		{
			processScoreEvent( "end_enemy_gravity_spike_attack", attacker, victim, weapon );
			attacker util::player_contract_event( "killed_hero_weapon_enemy" );
		}

		if ( challenges::isHighestScoringPlayer( victim ) )
		{
			processScoreEvent( "kill_enemy_who_has_high_score", attacker, victim, weapon );
		}
		
		if ( victimWasUnderwater && exlosiveDamage )
		{
			processScoreEvent( "kill_underwater_enemy_explosive", attacker, victim, weapon );
		}
		
		if ( isdefined ( victimElectrifiedBy ) && victimElectrifiedBy != attacker )
		{
			processScoreEvent( "electrified", victimElectrifiedBy, victim, weapon );
		}

		if ( victimVisionPulseActivateTime != 0 && victimVisionPulseActivateTime > time - 4000 )
		{
			gadgetWeapon = getWeapon("gadget_vision_pulse");
			for ( i = 0; i < victimVisionPulseArray.size; i++ )
			{
				player = victimVisionPulseArray[i];
				if ( player == attacker )
				{	
					gadget = GetWeapon( "gadget_vision_pulse" );
					
					if ( victimVisionPulseActivateTime + 300 > time - gadgetWeapon.gadget_pulse_duration )
					{
						distanceToPulse = distance( victimVisionPulseOriginArray[i], victimVisionPulseOrigin );
						
						ratio = distanceToPulse / gadgetWeapon.gadget_pulse_max_range;
						timing = ratio * gadgetWeapon.gadget_pulse_duration;
						if ( victimVisionPulseActivateTime + 300 > time - timing )
						{
							break;	
						}
					}
					
					processScoreEvent( "kill_enemy_that_pulsed_you", attacker, victim, weapon );
					attacker util::player_contract_event( "killed_hero_ability_enemy" );
					break;
				}
			}
			
			if ( isdefined( victimHeroAbility ) )
			{
				attacker notify( "hero_shutdown",  victimHeroAbility );
				attacker notify( "hero_shutdown_gadget", victimHeroAbility, victim );
			}
		}

		if ( attackerVisionPulseActivateTime != 0 && attackerVisionPulseActivateTime > time - ( VISION_PULSE_DURATION + VISION_PULSE_REVEAL_TIME + 500 ) )
		{
			gadgetWeapon = getWeapon("gadget_vision_pulse");
			for ( i = 0; i < attackerVisionPulseArray.size; i++ )
			{
				player = attackerVisionPulseArray[i];
				if ( player == victim )
				{	
					gadget = GetWeapon( "gadget_vision_pulse" );
					
					if ( attackerVisionPulseActivateTime > time - gadgetWeapon.gadget_pulse_duration )
					{
						distanceToPulse = distance( attackerVisionPulseOriginArray[i], attackerVisionPulseOrigin );
						
						ratio = distanceToPulse / gadgetWeapon.gadget_pulse_max_range;
						timing = ratio * gadgetWeapon.gadget_pulse_duration;
						if ( attackerVisionPulseActivateTime > time - timing )
						{
							break;	
						}
					}
					
					processScoreEvent( "vision_pulse_kill", attacker, victim, weapon );
					attacker hero_ability_kill_event( gadgetWeapon, get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
					
					if ( attackerIsRoulette && !victimIsThiefOrRoulette && victimHeroAbilityName === "gadget_vision_pulse" )
					{
						processScoreEvent( "kill_enemy_with_their_hero_ability", attacker, victim, weapon );
					}
					break;
				}
			}
		}

		if ( victimHeroAbilityActive && isdefined ( victimHeroAbility ) ) 
		{
			attacker notify( "hero_shutdown",  victimHeroAbility );
			attacker notify( "hero_shutdown_gadget", victimHeroAbility, victim );
		
			switch( victimHeroAbility.name )
			{
				case "gadget_armor":
					processScoreEvent( "kill_enemy_who_has_powerarmor", attacker, victim, weapon );
					attacker util::player_contract_event( "killed_hero_ability_enemy" );
				break;
				case "gadget_resurrect":
					processScoreEvent( "kill_enemy_that_used_resurrect", attacker, victim, weapon );
					attacker util::player_contract_event( "killed_hero_ability_enemy" );
				break;
				case "gadget_camo":
					processScoreEvent( "kill_enemy_that_is_using_optic_camo", attacker, victim, weapon );
					attacker util::player_contract_event( "killed_hero_ability_enemy" );
				break;
				case "gadget_clone":
					processScoreEvent( "end_enemy_psychosis", attacker, victim, weapon );
					attacker util::player_contract_event( "killed_hero_ability_enemy" );
				break;
			}		
		}
		else
		{
			if ( isdefined( victimPowerArmorLastTookDamageTime ) && ( time - victimPowerArmorLastTookDamageTime <= 3000 ) )
			{
				attacker notify( "hero_shutdown",  victimHeroAbility );
				attacker notify( "hero_shutdown_gadget", victimHeroAbility, victim );
				processScoreEvent( "kill_enemy_who_has_powerarmor", attacker, victim, weapon );
				attacker util::player_contract_event( "killed_hero_ability_enemy" );
			}
		}
		
		
		if ( isdefined( data.victimWeapon ) && isdefined( data.victimWeapon.isHeroWeapon ) && data.victimWeapon.isHeroWeapon == true )
		{
			attacker notify( "hero_shutdown",  data.victimWeapon );
			attacker notify( "hero_shutdown_gadget",  data.victimWeapon, victim );
		}
		else if ( isdefined( victim.heroWeapon ) && victimGadgetWasActiveLastDamage && victimGadgetPower < 100 )
		{
			// need to do this for some hero weapons like armblades
			attacker notify( "hero_shutdown", victim.heroWeapon );
			attacker notify( "hero_shutdown_gadget",  victim.heroWeapon, victim );
		}
		
		if ( attackerHeroAbilityActive && isdefined ( attackerHeroAbility )  )
		{
			abilityToCheck = undefined;

			switch( attackerHeroAbility.name )
			{
				case "gadget_armor":
				{
					processScoreEvent( "power_armor_kill", attacker, victim, weapon );
					attacker hero_ability_kill_event( attackerHeroAbility, get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
					abilityToCheck = attackerHeroAbility.name;
				}
				break;
				case "gadget_resurrect":
				{
					processScoreEvent( "resurrect_kill", attacker, victim, weapon );
					attacker hero_ability_kill_event( attackerHeroAbility, get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
					abilityToCheck = attackerHeroAbility.name;
				}
				break;
				case "gadget_camo":
				{
					processScoreEvent( "optic_camo_kill", attacker, victim, weapon );
					attacker hero_ability_kill_event( attackerHeroAbility, get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
					abilityToCheck = attackerHeroAbility.name;
				}
				break;
				case "gadget_clone":
				{
					processScoreEvent( "kill_enemy_while_using_psychosis", attacker, victim, weapon );
					attacker hero_ability_kill_event( attackerHeroAbility, get_equipped_hero_ability( victimHeroAbilityName ) );
					attacker specialistMedalAchievement();
					attacker thread specialistStatAbilityUsage( 4, false );
					abilityToCheck = attackerHeroAbility.name;
				}
				break;
			}

			if ( attackerIsRoulette && !victimIsThiefOrRoulette && isdefined( abilityToCheck ) && victimHeroAbilityName === abilityToCheck )
			{
				processScoreEvent( "kill_enemy_with_their_hero_ability", attacker, victim, weapon );
			}			
		}
		
		if ( victimWasLungingWithArmBlades )
		{
			processScoreEvent( "end_enemy_armblades_attack", attacker, victim, weapon );
		}

		if ( isdefined( data.victimWeapon ) )
		{
			killedHeroWeaponEnemy( attacker, victim, weapon, data.victimWeapon, victimGadgetPower, victimGadgetWasActiveLastDamage );
			
			if ( data.victimWeapon.name == "minigun" )
			{
				processScoreEvent( "killed_death_machine_enemy", attacker, victim, weapon );
			}
			else if ( data.victimWeapon.name == "m32" )
			{
				processScoreEvent( "killed_multiple_grenade_launcher_enemy", attacker, victim, weapon );
			}
			
			// armblade is special case since the victimWeapon can be a primary or secondary weapon
			is_hero_armblade_and_active = ( isdefined( victim.heroweapon ) && victim.heroweapon.name == "hero_armblade" && victimGadgetWasActiveLastDamage );
			
			if ( ( data.victimWeapon.inventorytype == "hero" || is_hero_armblade_and_active ) && victimGadgetPower < 100 )
			{
				if ( victimHeroWeaponKillsThisActivation == 0 )
				{
					attacker AddPlayerStat( "kill_before_specialist_weapon_use", 1 );
				}
				
				if ( weapon.inventorytype == "hero" )
				{
					attacker AddPlayerStat( "kill_specialist_with_specialist", 1 );
				}
				
				// add here
				attacker_is_thief = ( isdefined( attacker.heroweapon ) && attacker.heroweapon.name == "gadget_thief" );
				if ( !attacker_is_thief )
				{
					processScoreEvent( "end_enemy_specialist_weapon", attacker, victim, weapon );
				}
			}
		}
		
		if ( weapon.rootweapon.name == "frag_grenade" )
		{
			attacker thread updateSingleFragMultiKill( victim, weapon, weaponClass, killstreak );
		}
		
		attacker thread updateMultiKills( weapon, weaponClass, killstreak, victim );
	
		if ( level.numKills == 1 )
		{
			victim RecordKillModifier("firstblood");
			processScoreEvent( "first_kill", attacker, victim, weapon );
		}
		else
		{
			if ( isdefined( attacker.lastKilledBy ) )
			{
				if ( attacker.lastKilledBy == victim )
				{
					level.globalPaybacks++;
					processScoreEvent( "revenge_kill", attacker, victim, weapon );
					attacker AddWeaponStat( weapon, "revenge_kill", 1 );
					victim RecordKillModifier("revenge");
					attacker.lastKilledBy = undefined;
				}	
			}
			if ( victim killstreaks::is_an_a_killstreak() )
			{
				level.globalBuzzKills++;
				processScoreEvent( "stop_enemy_killstreak", attacker, victim, weapon );
				victim RecordKillModifier("buzzkill");
			}
			if ( isdefined( victim.lastManSD ) && victim.lastManSD == true )
			{
				processScoreEvent( "final_kill_elimination", attacker, victim, weapon );
				if ( isdefined( attacker.lastManSD ) && attacker.lastManSD == true )
				{
					processScoreEvent( "elimination_and_last_player_alive", attacker, victim, weapon );
				}
			}
		}
	
		if ( is_weapon_valid( meansOfDeath, weapon, weaponClass, killstreak ) )
		{
			if ( isdefined( victim.vAttackerOrigin ) )
				attackerOrigin = victim.vAttackerOrigin;
			else
				attackerOrigin = attacker.origin;
			distToVictim = distanceSquared( victim.origin, attackerOrigin );
			weap_min_dmg_range = get_distance_for_weapon( weapon, weaponClass );
			if ( distToVictim > weap_min_dmg_range )
			{
				attacker challenges::longDistanceKillMP( weapon );
				if ( weapon.rootweapon.name == "hatchet" )
				{
					attacker challenges::longDistanceHatchetKill();
				}
				processScoreEvent( "longshot_kill", attacker, victim, weapon );
				attacker.pers["longshots"]++;
				attacker.longshots = attacker.pers["longshots"];	
				victim RecordKillModifier("longshot");
			}
	
			// Record kill distances and num of entries
			killdistance = distance( victim.origin, attackerOrigin );
			attacker.pers["kill_distances"] += killdistance;
			attacker.pers["num_kill_distance_entries"]++;
		}
	
		if ( isAlive( attacker ) )
		{
			if ( attacker.health < ( attacker.maxHealth * 0.35 ) ) 
			{
				attacker.lastKillWhenInjured = time;
				processScoreEvent( "kill_enemy_when_injured", attacker, victim, weapon );
	
				attacker AddWeaponStat( weapon, "kill_enemy_when_injured", 1 );
				if ( attacker util::has_toughness_perk_purchased_and_equipped() )
				{
					attacker AddPlayerStat( "perk_bulletflinch_kills", 1 );
				}
			}
		}
		else
		{
			if ( isdefined( attacker.deathtime ) && ( ( attacker.deathtime + 800 ) < time ) && !attacker IsInVehicle() )
			{
				level.globalAfterlifes++;
				processScoreEvent( "kill_enemy_after_death", attacker, victim, weapon );
				victim RecordKillModifier("posthumous");
			}
		}
		
		if( attacker.cur_death_streak >= SCORE_EVENT_DEATH_STREAK_COUNT_REQUIRED )
		{
			level.globalComebacks++;
			processScoreEvent( "comeback_from_deathstreak", attacker, victim, weapon );
			victim RecordKillModifier("comeback");
		}
	
		if ( isdefined( victim.lastMicrowavedBy ) ) 
		{
			foreach( beingMicrowavedBy in victim.beingMicrowavedBy )
			{
				if ( isdefined( beingMicrowavedBy ) && ( attacker util::IsEnemyPlayer( beingMicrowavedBy ) == false ) )
				{
					if ( beingMicrowavedBy != attacker ) 
					{ 
						scoreGiven = processScoreEvent( "microwave_turret_assist", beingMicrowavedBy, victim, weapon );
						if ( isdefined ( scoreGiven ) )
						{
							beingMicrowavedBy challenges::earnedMicrowaveAssistScore( scoreGiven );
						}
					}
					else
					{
						attackerMicrowavedVictim = true;
					}
				}
			}
			
			if ( attackerMicrowavedVictim === true && weapon.name != "microwave_turret" )
			{
				attacker challenges::killWhileDamagingWithHPM();
			}
		}
		
		if ( weapon_utils::isMeleeMOD( meansOfDeath ) && !weapon.isRiotShield )
		{
			// "stabs" are now "melees"
			attacker.pers["stabs"]++;
			attacker.stabs = attacker.pers["stabs"];
			
			if ( meansOfDeath == "MOD_MELEE_WEAPON_BUTT" && weapon.name != "ball" )
			{
				processScoreEvent( "kill_enemy_with_gunbutt", attacker, victim, weapon );
			}
			else if ( weapon_utils::isPunch( weapon ) )
			{
				processScoreEvent( "kill_enemy_with_fists", attacker, victim, weapon );
			}
			else if ( weapon_utils::isNonBareHandsMelee( weapon ) )
			{
				vAngles = victim.anglesOnDeath[1];
				pAngles = attacker.anglesOnKill[1];
				angleDiff = AngleClamp180( vAngles - pAngles );
		
				if ( angleDiff > -30 && angleDiff < 70 )
				{
					level.globalBackstabs++;
					processScoreEvent( "backstabber_kill", attacker, victim, weapon );

					weaponPickedUp = false;
					if( isdefined( attacker.pickedUpWeapons ) && isdefined( attacker.pickedUpWeapons[weapon] ) )
					{
						weaponPickedUp = true;
					}

					attacker AddWeaponStat( weapon, "backstabber_kill", 1, attacker.class_num, weaponPickedUp, undefined, attacker.primaryLoadoutGunSmithVariantIndex, attacker.secondaryLoadoutGunSmithVariantIndex );
					attacker.pers["backstabs"]++;
					attacker.backstabs = attacker.pers["backstabs"];	
				}
			}
		}
		else
		{
			if ( isdefined ( victim.firstTimeDamaged ) && victim.firstTimeDamaged == time && !IS_TRUE( weapon.isHeroWeapon ) )
			{
				if ( attackerShotVictim )
				{
					attacker thread updateOneShotMultiKills( victim, weapon, victim.firstTimeDamaged );
					attacker AddWeaponStat( weapon, "kill_enemy_one_bullet", 1 );
				}
			}
		}
		
		if ( isdefined( attacker.tookWeaponFrom[ weapon ] ) && isdefined( attacker.tookWeaponFrom[ weapon ].previousOwner ) )
		{
			pickedUpWeapon = attacker.tookWeaponFrom[ weapon ];
			if ( pickedUpWeapon.previousOwner == victim )
			{
				processScoreEvent( "kill_enemy_with_their_weapon", attacker, victim, weapon );
				attacker AddWeaponStat( weapon, "kill_enemy_with_their_weapon", 1 );
				if ( isdefined( pickedUpWeapon.sWeapon ) && isdefined( pickedUpWeapon.sMeansOfDeath ) && weapon_utils::isMeleeMOD( pickedUpWeapon.sMeansOfDeath ) )
				{
					foreach( meleeWeapon in level.meleeWeapons )
					{
						if ( weapon != meleeWeapon && pickedUpWeapon.sWeapon.rootweapon == meleeWeapon )
						{
							attacker AddWeaponStat( meleeWeapon, "kill_enemy_with_their_weapon", 1 );
							break; // once found and handled, no need to continue
						}					
					}
				}
			}
		}

		if ( wasDefusing )
		{
			processScoreEvent( "killed_bomb_defuser", attacker, victim, weapon );
		}
		else if ( wasPlanting )
		{
			processScoreEvent( "killed_bomb_planter", attacker, victim, weapon );
		}
		
		heroWeaponKill( attacker, victim, weapon );

	}	// end if ( !isdefined( killstreak ) )

	specificWeaponKill( attacker, victim, weapon, killstreak, inflictor );
	
	if( isdefined( level.vtol ) && isdefined( level.vtol.owner ) && ( weapon.name == "helicopter_gunner_turret_secondary" || weapon.name == "helicopter_gunner_turret_tertiary" ) )
	{
		attacker addplayerstat( "kill_as_support_gunner", 1 );
		
		processScoreEvent( "mothership_assist_kill", level.vtol.owner, victim, weapon );
	}
	
	if ( isdefined( attackerInVehicleArchetype ) )
	{
		if ( attackerInVehicleArchetype == "siegebot" )
		{
			if ( meansOfDeath == "MOD_CRUSH" )
			{
				processScoreEvent( "kill_enemy_with_siegebot_crush", attacker, victim, weapon );
			}
			
			DEFAULT( attacker.siegebot_kills, 0 );
			
			attacker.siegebot_kills++;
			
			if ( attacker.siegebot_kills % 5 == 0 )
			{
				processScoreEvent( "siegebot_killstreak_5", attacker, victim, weapon );
			}
		}
	}
	
	switch ( weapon.rootweapon.name )
	{
		case "hatchet":
			{
				attacker.pers["tomahawks"]++;
				attacker.tomahawks = attacker.pers["tomahawks"];
		
				processScoreEvent( "hatchet_kill", attacker, victim, weapon );
		
				if ( isdefined( data.victim.explosiveInfo["projectile_bounced"] ) && data.victim.explosiveInfo["projectile_bounced"] == true )
				{
					level.globalBankshots++;

					processScoreEvent( "bounce_hatchet_kill", attacker, victim, weapon );
				}
			}
			break;
		case "supplydrop":
		case "inventory_supplydrop":
		case "supplydrop_marker":
		case "inventory_supplydrop_marker":
			{
				if ( meansOfDeath == "MOD_HIT_BY_OBJECT" || meansOfDeath == "MOD_CRUSH" )
				{
					processScoreEvent( "kill_enemy_with_care_package_crush", attacker, victim, weapon );
				}
				else
				{
					processScoreEvent( "kill_enemy_with_hacked_care_package", attacker, victim, weapon );
				}
			}
			break;

	}

	if( isdefined( killstreak ) )
	{
		attacker thread updateMultiKills( weapon, weaponClass, killstreak, victim );
		
		victim RecordKillModifier("killstreak");
	}

	attacker.cur_death_streak = 0;
	attacker disabledeathstreak();
}

function get_equipped_hero_ability( ability_name )
{
	if ( !isdefined( ability_name ) )
		return undefined;
	
	return GetWeapon( ability_name );
}

function heroWeaponKill( attacker, victim, weapon )
{
	if ( !isdefined( weapon ) )
	{
		return;
	}

	if ( isdefined( weapon.isHeroWeapon ) && !weapon.isHeroWeapon )
	{
		return;
	}

	switch( weapon.name ) 
	{
		case "hero_minigun":
		case "hero_minigun_body3":
			event = "minigun_kill";
			break;
		case "hero_flamethrower":
			event = "flamethrower_kill";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			event = "lightninggun_kill";
			break;
		case "hero_chemicalgelgun":
		case "hero_firefly_swarm":
			event = "gelgun_kill";
			break;
		case "hero_pineapplegun":
		case "hero_pineapple_grenade":
			event = "pineapple_kill";
			break;
		case "hero_armblade": 
			event = "armblades_kill";
			break;
		case "hero_bowlauncher": 
		case "hero_bowlauncher2": 
		case "hero_bowlauncher3": 
		case "hero_bowlauncher4": 
			event = "bowlauncher_kill";
			break;
		case "hero_gravityspikes":
			event = "gravityspikes_kill";
			break;
		case "hero_annihilator":
			event = "annihilator_kill";
			break;		
		default:
			return;
	}

	processScoreEvent( event, attacker, victim, weapon );
}

function killedHeroWeaponEnemy( attacker, victim, weapon, victim_weapon, victim_gadget_power, victimGadgetWasActiveLastDamage )
{	
	if ( !isdefined( victim_weapon ) )
	{
		return;
	}
	
	if ( victim_gadget_power >= 100 )
		return;
		
	switch( victim_weapon.name ) 
	{
		case "hero_minigun":
		case "hero_minigun_body3":
			event = "killed_minigun_enemy";
			break;
		case "hero_flamethrower":
			event = "killed_flamethrower_enemy";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			event = "killed_lightninggun_enemy";
			break;
		case "hero_chemicalgelgun":
			event = "killed_gelgun_enemy";
			break;
		case "hero_pineapplegun":
			event = "killed_pineapple_enemy";
			break;
		case "hero_bowlauncher": 
		case "hero_bowlauncher2": 
		case "hero_bowlauncher3": 
		case "hero_bowlauncher4": 
			event = "killed_bowlauncher_enemy";
			break;
		case "hero_gravityspikes":
			event = "killed_gravityspikes_enemy";
			break;
		case "hero_annihilator":
			event = "killed_annihilator_enemy";
			break;
			
		default:
			if ( isdefined( victim.heroWeapon ) && victim.heroWeapon.name == "hero_armblade" && victimGadgetWasActiveLastDamage )
			{
				event = "killed_armblades_enemy";
			}
			else
			{
				return;
			}
	}
	
	processScoreEvent( event, attacker, victim, weapon );
	attacker util::player_contract_event( "killed_hero_weapon_enemy" );
}

function specificWeaponKill( attacker, victim, weapon, killstreak, inflictor )
{
	switchWeapon = weapon.name;

	if( isdefined( killstreak ) ) 
	{
		switchWeapon = killstreak;
	}
	switch( switchWeapon ) 
	{
		case "remote_missile":
		case "inventory_remote_missile":
			event = "remote_missile_kill";
			break;
		case "autoturret":
		case "inventory_autoturret":
			event = "sentry_gun_kill";
			break;
		case "planemortar":
		case "inventory_planemortar":
			event = "plane_mortar_kill";
			break;
		case "ai_tank_drop":
		case "inventory_ai_tank_drop":
			event = "aitank_kill";
				if ( isdefined( inflictor ) && isdefined( inflictor.controlled ) )
				{
					if ( inflictor.controlled == true )
					{
						attacker addPlayerStat( "kill_with_controlled_ai_tank", 1 );
					}
				}
			break;
		case "microwave_turret":
		case "inventory_microwave_turret":
		case "microwaveturret":
		case "inventory_microwaveturret":
			event = "microwave_turret_kill";
			break;
		case "raps":
		case "inventory_raps":
			event = "raps_kill";
			break;
		case "sentinel":
		case "inventory_sentinel":
			{
				event = "sentinel_kill";
				if ( isdefined( inflictor ) && isdefined( inflictor.controlled ) )
				{
					if ( inflictor.controlled == true )
					{
						attacker addPlayerStat( "kill_with_controlled_sentinel", 1 );
					}
				}
			}
			break;
		case "combat_robot":
		case "inventory_combat_robot":
			event = "combat_robot_kill";
			break;
		case "rcbomb":
		case "inventory_rcbomb":
			event = "hover_rcxd_kill";
			break;
		case "helicopter_gunner":
		case "helicopter_gunner_assistant":
		case "inventory_helicopter_gunner":
		case "inventory_helicopter_gunner_assistant":
			event = "vtol_mothership_kill";
			break;
		case "helicopter_comlink":
		case "inventory_helicopter_comlink":
			event = "helicopter_comlink_kill";
			break;
		case "drone_strike":
		case "inventory_drone_strike":
			event = "drone_strike_kill";
			break;
		case "dart":
		case "inventory_dart":
		case "dart_turret":
			event = "dart_kill";
			break;			
		default:
			return;
	}

	if ( isdefined( inflictor ) )
	{
		if ( isdefined( inflictor.killstreak_id ) && isdefined( level.matchRecorderKillstreakKills[inflictor.killstreak_id] ) )
		{
			level.matchRecorderKillstreakKills[inflictor.killstreak_id]++;
		}
		else if ( isdefined( inflictor.killcament ) && isdefined( inflictor.killcament.killstreak_id ) && isdefined( level.matchRecorderKillstreakKills[inflictor.killcament.killstreak_id] ) )
		{
			level.matchRecorderKillstreakKills[inflictor.killcament.killstreak_id]++;
		}
	}
	
	processScoreEvent( event, attacker, victim, weapon );
}

function multiKill( killCount, weapon )
{
	assert( killCount > 1 );
	
	self challenges::multiKill( killCount, weapon );

	if ( killCount > 8 ) 
	{
		processScoreEvent( "multikill_more_than_8", self, undefined, weapon );
	}
	else
	{
		processScoreEvent( "multikill_" + killCount, self, undefined, weapon );
	}
	
	if ( killCount > 2 )
	{
		if ( isdefined( self.challenge_objectiveDefensiveKillcount ) && self.challenge_objectiveDefensiveKillcount > 0 )
		{
			self.challenge_objectiveDefensiveTripleKillMedalOrBetterEarned = true;
		}
	}
	
	self RecordMultiKill( killCount );
}

function multiHeroAbilityKill( killCount, weapon )
{
	if ( killcount > 1 )
	{
		self addPlayerStat( "multikill_2_with_heroability", int( killCount / 2 ) );
		self AddWeaponStat( weapon, "heroability_doublekill", int( killCount / 2 ) );
		self addPlayerStat( "multikill_3_with_heroability", int( killCount / 3 ) );
		self AddWeaponStat( weapon, "heroability_triplekill", int( killCount / 3 ) );
	}
}

function is_weapon_valid( meansOfDeath, weapon, weaponClass, killstreak )
{
	valid_weapon = false;
	
	if ( isdefined( killstreak ) ) 
		valid_weapon = false;
	else if ( get_distance_for_weapon( weapon, weaponClass ) == 0 )
		valid_weapon = false;
	else if ( meansOfDeath == "MOD_PISTOL_BULLET" || meansOfDeath == "MOD_RIFLE_BULLET" )
		valid_weapon = true;
	else if ( meansOfDeath == "MOD_HEAD_SHOT" )
		valid_weapon = true;
	else if ( weapon.rootweapon.name == "hatchet" && meansOfDeath == "MOD_IMPACT" )
		valid_weapon = true;
	else
	{
		baseWeapon = challenges::getBaseWeapon( weapon );
		if ( baseWeapon == level.weaponSpecialCrossbow && meansOfDeath == "MOD_IMPACT" )
			valid_weapon = true;
		else if ( baseWeapon == level.weaponBallisticKnife && meansOfDeath == "MOD_IMPACT" )
			valid_weapon = true;
		else if ( ( baseWeapon.forceDamageHitLocation || baseWeapon == level.weaponShotgunEnergy || baseWeapon == level.weaponSpecialDiscGun ) && meansofDeath == "MOD_PROJECTILE" )
			valid_weapon = true;
	}

	return valid_weapon;
}


function updateSingleFragMultiKill( victim, weapon, weaponClass, killstreak )
{
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self notify ( "updateSingleFragMultiKill" );
	self endon ( "updateSingleFragMultiKill" );
	
	if ( !isdefined (self.recent_SingleFragMultiKill) || self.recent_SingleFragMultiKillID != victim.explosiveinfo["damageid"] )
		self.recent_SingleFragMultiKill = 0;
	
	self.recent_SingleFragMultiKillID = victim.explosiveinfo["damageid"];
	self.recent_SingleFragMultiKill++;
	
	self waitTillTimeoutOrDeath( 0.05 );
	
	if ( self.recent_SingleFragMultiKill >= 2 )
	{
		processScoreEvent( "frag_multikill", self, victim, weapon );
	}

	self.recent_SingleFragMultiKill = 0;
}
	
function updatemultikills( weapon, weaponClass, killstreak, victim )
{
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self notify ( "updateRecentKills" );
	self endon ( "updateRecentKills" );

	baseWeaponParam = [[ level.get_base_weapon_param ]]( weapon );
	baseWeapon = GetWeapon( GetRefFromItemIndex( GetBaseWeaponItemIndex( baseWeaponParam ) ) );

	if ( !isdefined( self.recentKillVariables ) )
	{
		self resetRecentKillVariables();
	}

	if ( !isdefined( self.recentKillCountWeapon ) || self.recentKillCountWeapon != baseWeapon )
	{
		self.recentKillCountSameWeapon = 0;
		self.recentKillCountWeapon = baseWeapon;
	}

	if (!isdefined(killstreak))
	{
		self.recentKillCountSameWeapon++;
		self.recentKillCount++;
	}
		
	if ( isdefined( weaponClass ) )
	{
		if ( weaponClass == "weapon_lmg" || weaponClass == "weapon_smg" )
		{
			if ( self PlayerAds() < 1.0 ) 
			{
				self.recent_LMG_SMG_KillCount++;
			}
		}
		if ( weaponClass == "weapon_grenade" )
		{
			self.recentLethalCount++;
		}
	}
	
	if ( weapon.name == "satchel_charge" )
	{
		self.recentC4KillCount++;
	}
	
	if ( isdefined( level.killstreakWeapons ) && isdefined( level.killstreakWeapons[weapon] ) )
	{
		switch( level.killstreakWeapons[weapon] )
		{
			case "remote_missile":
			case "inventory_remote_missile":
				{
					self.recentRemoteMissileCount++;
				}
				break;
			case "rcbomb":
			case "inventory_rcbomb":
				{
					self.recentRCBombCount++;
				}
				break;
		}
	}
	    	
	    	
	if ( isdefined( weapon.isHeroWeapon ) && weapon.isHeroWeapon == true )
	{
		self.recentHeroKill = getTime();
		self.recentHeroWeaponKillCount++;
		if ( isdefined( victim ) )
		{
			self.recentHeroWeaponVictims[ victim GetEntityNumber() ] = victim;
		}
		switch( weapon.name )
		{
			case "hero_annihilator":
				self.recentAnihilatorCount++;
				break;
			case "hero_minigun":
			case "hero_minigun_body3":
				self.recentMiniGunCount++;
				break;
			case "hero_bowlauncher":
			case "hero_bowlauncher2": 
			case "hero_bowlauncher3": 
			case "hero_bowlauncher4": 
				self.recentBowLauncherCount++;
				break;
			case "hero_flamethrower":
				self.recentFlameThrowerCount++;
				break;
			case "hero_gravityspikes":
				self.recentGravitySpikesCount++;
				break;
			case "hero_lightninggun":
			case "hero_lightninggun_arc":
				self.recentLightningGunCount++;
				break;
			case "hero_pineapplegun":
			case "hero_pineapple_grenade":
				self.recentPineappleGunCount++;
				break;
			case "hero_chemicalgun":
			case "hero_firefly_swarm":
				self.recentGelGunCount++;
				break;
			case "hero_armblade":
				self.recentArmBladeCount++;
				break;
		}
	}
	
	if ( isdefined( self.heroAbility ) && isdefined( victim ) )
	{
		if ( victim ability_player::gadget_CheckHeroAbilityKill( self ) )
		{
			if ( isdefined( self.recentHeroAbilityKillWeapon ) && self.recentHeroAbilityKillWeapon != self.heroAbility ) 
			{
				self.recentHeroAbilityKillCount = 0;
			}
			self.recentHeroAbilityKillWeapon = self.heroAbility;	
			self.recentHeroAbilityKillCount++;
		}
	}
	
	if ( isdefined ( killstreak ) ) 
	{
		switch( killstreak ) 
		{
		case "remote_missile":
			self.recentRemoteMissileKillCount++;
			break;
		case "rcbomb":
			self.recentRCBombKillCount++;
			break;
		case "inventory_m32":
		case "m32":
			self.recentMGLKillCount++;
			break;
		}
	}

	if ( self.recentKillCountSameWeapon == 2 )
	{
		self AddWeaponStat( weapon, "multikill_2", 1 );
	}
	else if ( self.recentKillCountSameWeapon == 3 )
	{
		self AddWeaponStat( weapon, "multikill_3", 1 );
	}
	
	self waitTillTimeoutOrDeath( 4.0 );

	if ( self.recent_LMG_SMG_KillCount >= 3 )
		self challenges::multi_LMG_SMG_Kill();	

	if ( self.recentRCBombKillCount >= 2 )
		self challenges::multi_RCBomb_Kill();	

	if ( self.recentMGLKillCount >= 3 )
		self challenges::multi_MGL_Kill();	

	if ( self.recentRemoteMissileKillCount >= 3 )
		self challenges::multi_RemoteMissile_Kill();	
	
	
	if ( self.recentHeroWeaponKillCount > 1 )
	{
		self scoreevents::hero_weapon_multikill_event( self.recentHeroWeaponKillCount, weapon );
	}
	
	if ( self.recentHeroWeaponKillCount > 5 )
	{
		ArrayRemoveValue( self.recentHeroWeaponVictims, undefined );
		if ( self.recentHeroWeaponVictims.size > 5 )
		{
			self addPlayerStat( "kill_entire_team_with_specialist_weapon", 1 );
		}
	}

	if ( self.recentAnihilatorCount >= 3 )
	{
		processScoreEvent( "annihilator_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentAnihilatorCount == 2 )
	{
		processScoreEvent( "annihilator_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentMiniGunCount >= 3 )
	{
		processScoreEvent( "minigun_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentMiniGunCount == 2 )
	{
		processScoreEvent( "minigun_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentBowLauncherCount >= 3 )
	{
		processScoreEvent( "bowlauncher_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentBowLauncherCount == 2 )
	{
		processScoreEvent( "bowlauncher_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentFlameThrowerCount >= 3 )
	{
		processScoreEvent( "flamethrower_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentFlameThrowerCount == 2 )
	{
		processScoreEvent( "flamethrower_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentGravitySpikesCount >= 3 )
	{
		processScoreEvent( "gravityspikes_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentGravitySpikesCount == 2 )
	{
		processScoreEvent( "gravityspikes_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentLightningGunCount >= 3 )
	{
		processScoreEvent( "lightninggun_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentLightningGunCount == 2 )
	{
		processScoreEvent( "lightninggun_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentPineappleGunCount >= 3 )
	{
		processScoreEvent( "pineapple_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentPineappleGunCount == 2 )
	{
		processScoreEvent( "pineapple_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentGelGunCount >= 3 )
	{
		processScoreEvent( "gelgun_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentGelGunCount == 2 )
	{
		processScoreEvent( "gelgun_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	if ( self.recentArmBladeCount >= 3 )
	{
		processScoreEvent( "armblades_multikill", self, undefined, weapon );
		self multikillMedalAchievement();
	}
	else if ( self.recentArmBladeCount == 2 )
	{
		processScoreEvent( "armblades_multikill_2", self, undefined, weapon );
		self multikillMedalAchievement();		
	}
	
	if ( self.recentC4KillCount >= 2 )
	{
		processScoreEvent( "c4_multikill", self, undefined, weapon );
	}
	if ( self.recentRemoteMissileCount >= 3 ) 
	{
		self addPlayerStat( "multikill_3_remote_missile", 1 );
	}
	if ( self.recentRCBombCount >= 2 ) 
	{
		self addPlayerStat( "multikill_2_rcbomb", 1 );
	}
	if ( self.recentLethalCount >= 2 )
	{
		if ( !isdefined( self.pers["challenge_kills_double_kill_lethal"] ) )
		{
			self.pers["challenge_kills_double_kill_lethal"] = 0;
		}
		    
		self.pers["challenge_kills_double_kill_lethal"]++;
		if ( self.pers["challenge_kills_double_kill_lethal"] >= 3 )
		{
			self addPlayerStat( "kills_double_kill_3_lethal", 1 );
		}
	}
	
	if ( self.recentKillCount > 1 )
		self multiKill( self.recentKillCount, weapon );
	
	if ( self.recentHeroAbilityKillCount > 1 )
	{
		self multiHeroAbilityKill( self.recentHeroAbilityKillCount, self.recentHeroAbilityKillWeapon );
		self scoreevents::hero_ability_multikill_event( self.recentHeroAbilityKillCount, self.recentHeroAbilityKillWeapon );
	}
	
	self resetRecentKillVariables();
}

function resetRecentKillVariables()
{
	self.recent_LMG_SMG_KillCount = 0;
	self.recentAnihilatorCount = 0;
	self.recentArmBladeCount = 0;
	self.recentBowLauncherCount = 0;
	self.recentC4KillCount = 0;
	self.recentFlameThrowerCount = 0;
	self.recentGelGunCount = 0;
	self.recentGravitySpikesCount = 0;
	self.recentHeroAbilityKillCount = 0;
	self.recentHeroWeaponKillCount = 0;
	self.recentHeroWeaponVictims = [];
	self.recentKillCount = 0;
	self.recentKillCountSameWeapon = 0;
	self.recentKillCountWeapon = undefined;
	self.recentLethalCount = 0;
	self.recentLightningGunCount = 0;
	self.recentMGLKillCount = 0;
	self.recentMiniGunCount = 0;
	self.recentPineappleGunCount = 0;
	self.recentRCBombCount = 0;
	self.recentRCBombKillCount = 0;
	self.recentRemoteMissileCount = 0;
	self.recentRemoteMissileKillCount = 0;
	
	self.recentKillVariables = true;
}

function waitTillTimeoutOrDeath( timeout )
{
	self endon( "death" );
	wait( timeout );
}

function updateoneshotmultikills( victim, weapon, firstTimeDamaged )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "updateoneshotmultikills" + firstTimeDamaged );
	self endon( "updateoneshotmultikills" + firstTimeDamaged );
	if ( !isdefined( self.oneshotmultikills ) || firstTimeDamaged > VAL( self.oneshotmultikillsdamagetime, 0 ) )
	{
		self.oneshotmultikills = 0;
	}

	self.oneshotmultikills++;
	self.oneshotmultikillsdamagetime = firstTimeDamaged;

	wait( 1.0 );
	if ( self.oneshotmultikills > 1 )
	{
		processScoreEvent( "kill_enemies_one_bullet", self, victim, weapon );
	}
	else
	{
		processScoreEvent( "kill_enemy_one_bullet", self, victim, weapon );
	}
	self.oneshotmultikills = 0;
}

function get_distance_for_weapon( weapon, weaponClass )
{
	// this is special for the long shot medal
	// need to do this on a per weapon category basis, to better control it

	distance = 0;
	
	if( !isdefined( weaponClass ) )
	{
		return 0;
	}
	
	// special case weapons
	if ( weapon.rootweapon.name == "pistol_shotgun" )
	{
		weaponClass = "weapon_cqb"; // per design
	}
	
	
	switch ( weaponClass )
	{
		case "weapon_smg":
			distance = 1500 * 1500;
			break;

		case "weapon_assault":
			distance = 1750 * 1750;
			break;

		case "weapon_lmg":
			distance = 1750 * 1750;
			break;

		case "weapon_sniper":
			distance = 2000 * 2000;
			break;

		case "weapon_pistol":
			distance = 1000 * 1000;
			break;
			
		case "weapon_cqb":
			distance = 550 * 550;
			break;


		case "weapon_special":
			{
				baseWeapon = challenges::getBaseWeapon( weapon );
				if ( baseWeapon == level.weaponBallisticKnife || baseWeapon == level.weaponSpecialCrossbow || baseWeapon == level.weaponSpecialDiscGun )
				{
					distance = 1500 * 1500;	
				}
			}
			break;
		case "weapon_grenade":
			if ( weapon.rootweapon.name == "hatchet" ) 
			{
				distance = 1500 * 1500;
			}
			break;
		default:
			distance = 0;
			break;
	}

	return distance;
}


function onGameEnd( data )
{
	player = data.player;
	winner = data.winner;
	
	if ( isdefined( winner ) ) 
	{	
		if ( level.teambased )
		{
			if ( winner != "tie" && player.team == winner )
			{
				processScoreEvent( "won_match", player );
				return;
			}
		}
		else
		{
			placement = level.placement["all"];
			topThreePlayers = min( 3, placement.size );
			
			for ( index = 0; index < topThreePlayers; index++ )
			{
				if ( level.placement["all"][index] == player )
				{
					processScoreEvent( "won_match", player );
						return;
				}
			}
		}
	}
	processScoreEvent( "completed_match", player );
}


function specialistMedalAchievement()
{
	if( level.rankedMatch )
	{
		if ( !isdefined( self.pers["specialistMedalAchievement"] ) )
		{
			self.pers["specialistMedalAchievement"] = 0;
		}
		self.pers["specialistMedalAchievement"]++;
		if ( self.pers["specialistMedalAchievement"] == 5 )
		{
			self GiveAchievement( "MP_SPECIALIST_MEDALS" ); // Get 5 Medals based on a Specialist Ability in a single game. 
		}
		
		self util::player_contract_event( "earned_specialist_ability_medal" );
	}
}

function specialistStatAbilityUsage( usageSingleGame, multiTrackPerLife )
{
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self notify ( "updatethread specialistStatAbilityUsage" );
	self endon ( "updatethread specialistStatAbilityUsage" );
	
	isRoulette = ( self.isRoulette === true );
	if ( isdefined( self.heroAbility ) && !isRoulette )
	{
		self addWeaponStat( self.heroAbility, "combatRecordStat", 1 );
	}
	
	self challenges::processSpecialistChallenge( "kills_ability" );
	if ( !isdefined( self.pers["specialistUsagePerGame"] ) )
	{
		self.pers["specialistUsagePerGame"] = 0;
	}
	self.pers["specialistUsagePerGame"]++;
	if ( self.pers["specialistUsagePerGame"] >= usageSingleGame )
	{
		self challenges::processSpecialistChallenge( "kill_one_game_ability" );
		self.pers["specialistUsagePerGame"] = 0;
	}
	
	if ( multiTrackPerLife )
	{
		self.pers["specialistStatAbilityUsage"]++;
		if ( self.pers["specialistStatAbilityUsage"] >= 2 )
		{
			self challenges::processSpecialistChallenge( "multikill_ability" );
		}
	}
	else
	{
		if ( !isdefined( self.specialistStatAbilityUsage ) )
		{
			self.specialistStatAbilityUsage = 0;
		}
		
		self.specialistStatAbilityUsage++;
		self waitTillTimeoutOrDeath( 4.0 );
		if ( self.specialistStatAbilityUsage >= 2 )
		{
			self challenges::processSpecialistChallenge( "multikill_ability" );
		}
		self.specialistStatAbilityUsage = 0;
	}
}

function multikillMedalAchievement()
{
	if ( level.rankedMatch )
	{
		self GiveAchievement( "MP_MULTI_KILL_MEDALS" ); // Get a Specialist-based medal that requires 3 or more rapid kills while using any Specialist Weapon. 
		self challenges::processSpecialistChallenge( "multikill_weapon" );
	}
}

