#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_gadgets;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#using scripts\shared\_burnplayer;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace thief;

REGISTER_SYSTEM( "gadget_thief", &__init__, undefined )

#define THIEF_STATE_DEFAULT					0
#define THIEF_STATE_RECEIVED_NEW_GADGET		1
#define THIEF_STATE_DONE_FLIPING			2
#define THIEF_WEAPON_OPTION_NONE			0

#define THIEF_NEW_GADGET_ANIM_TIME			0.75
#define THIEF_PRE_FLIP_WAIT_TIME			0.85
#define THIEF_ACTIVATION_WAIT				1.1
	
#define THIEF_OVERCLOCK_POWER_THRESHOLD		80
	
#define BLACKJACK_BODY_INDEX				9
	
#define MIN_TIME_BETWEEN_GIVE_FLIP_AUDIO_MS	99

	
function __init__()
{
	clientfield::register( "toplayer", "thief_state", VERSION_TU11, 2, "int" );
	clientfield::register( "toplayer", "thief_weapon_option", VERSION_TU11, 4, "int" );

	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_THIEF, &gadget_thief_on_activate, &gadget_thief_on_deactivate );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_THIEF, &gadget_thief_on_give, &gadget_thief_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_THIEF, &gadget_thief_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_THIEF, &gadget_thief_is_inuse );
	ability_player::register_gadget_ready_callbacks( GADGET_TYPE_THIEF, &gadget_thief_is_ready );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_THIEF, &gadget_thief_is_flickering );

	clientfield::register( "scriptmover", "gadget_thief_fx", VERSION_TU11, 1, "int" );

	clientfield::register( "clientuimodel", "playerAbilities.playerGadget3.flashStart", VERSION_TU11, 3, "int" );
	clientfield::register( "clientuimodel", "playerAbilities.playerGadget3.flashEnd", VERSION_TU11, 3, "int" );

	callback::on_connect( &gadget_thief_on_connect );
	callback::on_spawned( &gadget_thief_on_player_spawn );
	
	setup_gadget_thief_array();
		
	level.gadgetThiefTimeCharge = false;
	level.gadgetThiefShutdownFullcharge = getDvarInt( "gadgetThiefShutdownFullCharge", 1 );
}

function setup_gadget_thief_array()
{
	weapons = EnumerateWeapons( "weapon" );
	level.gadgetthiefArray = [];
	
	for ( i = 0; i < weapons.size; i++ )
	{
		if ( weapons[i].isGadget && weapons[i].isheroweapon == true )
		{
			if ( weapons[i].name != "gadget_thief" &&
			    weapons[i].name != "gadget_roulette" &&
			    weapons[i].name != "hero_bowlauncher2" &&
			    weapons[i].name != "hero_bowlauncher3" &&
			    weapons[i].name != "hero_bowlauncher4" &&
			    weapons[i].name != "hero_pineapple_grenade" &&
			    weapons[i].name != "gadget_speed_burst" &&
			    weapons[i].name != "hero_minigun_body3" &&
			    weapons[i].name != "hero_lightninggun_arc" )
			{
				ArrayInsert( level.gadgetthiefArray, weapons[i], 0 );
			}
		}
	}
}

function gadget_thief_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self GadgetIsActive( slot );
}

function gadget_thief_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_thief_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_thief_flicker( slot, weapon );
}

function gadget_thief_on_give( slot, weapon )
{
	self.gadget_thief_kill_callback = &gadget_thief_kill_callback;
	self.gadget_thief_slot = slot;
	// executed when gadget is added to the players inventory
	self thread gadget_thief_active( slot, weapon );
	
	if ( SessionModeIsMultiplayerGame() )
	{
		self.isThief = true;
	}

	self clientfield::set_to_player( "thief_state", THIEF_STATE_DEFAULT );

	currentPower = VAL( self gadgetPowerGet( slot ), 0 );
	
	savedPower = 0;
	if( isdefined( self.pers["held_gadgets_power"] ) && isdefined( self.pers[#"thiefWeapon"] ) && isdefined( self.pers["held_gadgets_power"][self.pers[#"thiefWeapon"]] ) )
	{
		savedPower = self.pers["held_gadgets_power"][self.pers[#"thiefWeapon"]];
	}

	if ( currentPower >= 100 || savedPower >= 100 )
	{
		self.giveStolenWeaponOnSpawn = true;
		self.giveStolenWeaponSlot = slot;
	}
}

function gadget_thief_kill_callback( victim, weapon )
{
	assert( isDefined( self.gadget_thief_slot ) );
	self thread handleThiefKill( self.gadget_thief_slot, weapon, victim );
}

function gadget_thief_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory

}

//self is the player
function gadget_thief_on_connect()
{
	// setup up stuff on player connect
	
	self.pers[#"thiefAllowFlip"] = true;
	
}

function gadget_thief_on_player_spawn()
{
	if ( self.isThief === true )
	{
		// setup up stuff on player spawned

		self thread watchHeroWeaponChanged();
		
		if ( self.giveStolenWeaponOnSpawn === true )
		{
			self givePreviouslyEarnedSpecialistWeapon( self.giveStolenWeaponSlot, true );
			self GadgetPowerSet( self.giveStolenWeaponSlot, 100 );
			self.giveStolenWeaponOnSpawn = undefined;
			self.giveStolenWeaponSlot = undefined;
		}
	}
}

function watch_entity_shutdown()
{
}

function gadget_thief_on_activate( slot, weapon )
{
}

function gadget_thief_is_ready( slot, weapon )
{
}

function gadget_thief_active( slot, weapon )
{
	waittillframeend;
	
	if ( isdefined( self.pers[#"thiefWeapon"] ) && weapon.name != "gadget_thief" )
	{
		self thread gadget_give_random_gadget( slot, weapon, self.pers[#"thiefWeaponStolenFrom"] );
	}
	self thread watchForHeroKill( slot );
}

function getStolenHeroWeapon( gadget )
{	
	if ( gadget.isheroweapon == false )
	{
		heroWeaponEquivalent = "";
		switch( gadget.name )
		{
			case "gadget_flashback":
				{
					heroWeaponEquivalent = "hero_lightninggun";
				}
				break;
			case "gadget_combat_efficiency":
				{
					heroWeaponEquivalent = "hero_annihilator";
				}
				break;
			case "gadget_heat_wave" :
				{
					heroWeaponEquivalent = "hero_flamethrower";
				}
				break;
			case "gadget_vision_pulse":
				{
					heroWeaponEquivalent = "hero_bowlauncher";
				}
				break;
			case "gadget_speed_burst":
				{
					heroWeaponEquivalent = "hero_gravityspikes";
				}
				break;
			case "gadget_camo":
				{
					heroWeaponEquivalent = "hero_armblade";
				}
				break;
			case "gadget_armor":
				{
					heroWeaponEquivalent = "hero_pineapplegun";
				}
				break;
			case "gadget_resurrect":
				{
					heroWeaponEquivalent = "hero_chemicalgelgun";
				}
				break;
			case "gadget_clone":
				{
					heroWeaponEquivalent = "hero_minigun";
				}
				break;
		}
		if ( heroWeaponEquivalent != "" )
		{
			heroweapon = getweapon( heroWeaponEquivalent );
		}
	}
	else
	{
		heroweapon = gadget;
	}
	
	return heroweapon;
}

function resetFlashStartAndEndAfterDelay( delay )
{
	self notify( "resetFlashStartAndEnd" );
	self endon ( "resetFlashStartAndEnd" );

	wait delay;

	self clientfield::set_player_uimodel( "playerAbilities.playerGadget3.flashStart", 0 );
	self clientfield::set_player_uimodel( "playerAbilities.playerGadget3.flashEnd", 0 );
}

function getThiefPowerGain()
{
	gadgetThiefKillPowerGain = getDvarFloat( "gadgetThiefKillPowerGain", 12.5 );
	thiefGametypeFactor = VAL( GetGametypeSetting( "scoreThiefPowerGainFactor" ), 1.0 );
	gadgetThiefKillPowerGain *= thiefGametypeFactor;
	return gadgetThiefKillPowerGain;
}

function handleThiefKill( slot, weapon, victim )
{
	if ( isdefined( weapon ) && !killstreaks::is_killstreak_weapon( weapon ) &&  !weapon.isHeroWeapon && IsAlive( self ) )
	{
		if ( self gadgetIsActive( slot ) == false )
		{
			power = self gadgetPowerGet( slot );
			gadgetThiefKillPowerGain = getThiefPowerGain();
			gadgetThiefKillPowerGainWithoutMultiplier = getThiefPowerGain();
			
			victimGadgetPower = VAL( victim gadgetPowerGet( 0 ), 0 );
			
			alwaysPerformGain = false; // if we want to hear power gains even at full power, set this to true
			
			if ( alwaysPerformGain || power < 100 )
			{
				if ( victimGadgetPower == 100 )
				{
					// aku-- removed PowerTap by commenting out for now
					
					// gadgetThiefKillPowerGain *= getDvarFloat( "gadgetThiefKillFullPowerMultiplier", 2.0 );
					
					// scoreevents::processScoreEvent( "kill_enemy_who_has_full_power", self );
					
					// self playsoundtoplayer ("mpl_bm_specialist_bar_extra", self);

					self playsoundtoplayer ("mpl_bm_specialist_bar_thief", self); // play "normal" earn audio
					
					// JMCCAWLEY
					// this is when you kill an enemy that has a full meter and you earn extra power
				}
				else
				{
					self playsoundtoplayer ("mpl_bm_specialist_bar_thief", self);
					// JMCCAWLEY
					// this is when you kill an enemy that has does not have a full meter
				}
			}
	
			currentPower = power + gadgetThiefKillPowerGain;
			
			if ( power < THIEF_OVERCLOCK_POWER_THRESHOLD && currentPower >= THIEF_OVERCLOCK_POWER_THRESHOLD && currentPower < 100 )
			{
				if ( self HasPerk( "specialty_overcharge" ) ) // overclock
				{
					currentPower = 100;
				}
			}

			if ( currentPower >= 100 )
			{
				wasFullyCharged = ( power >= 100 );
				
				self earnedSpecialistWeapon( victim, slot, wasFullyCharged );
			}

			// todo handle overlapping cases, delay animations when you get several in a row
			self clientfield::set_player_uimodel( "playerAbilities.playerGadget3.flashStart", Int(power / gadgetThiefKillPowerGainWithoutMultiplier) );
			self clientfield::set_player_uimodel( "playerAbilities.playerGadget3.flashEnd", Int(currentPower / gadgetThiefKillPowerGainWithoutMultiplier) );
			self thread resetFlashStartAndEndAfterDelay( 3.0 ); // 3 seconds

			self GadgetPowerSet( slot, currentPower );
		}
		else // the else for if ( self gadgetIsActive( slot ) == false )
		{
			if ( IsPlayer( victim ) && self.pers[#"thiefWeaponStolenFrom"] === victim.entNum && weapon.isHeroWeapon )
			{
				scoreevents::processScoreEvent( "kill_enemy_with_their_hero_weapon", self );
			}
		}
	}
}

function earnedSpecialistWeapon( victim, slot, wasFullyCharged, stolenHeroWeapon )
{
	if ( !isdefined( victim ) )
		return;

	heroWeapon = undefined;	
	victimIsBlackjack = ( ( victim.isThief === true ) || ( victim.isRoulette === true ) );
	
	if ( victimIsBlackjack )
	{
		if( isDefined( stolenHeroWeapon ) )
		{
			heroWeapon = stolenHeroWeapon;
		}
		else if ( isdefined( victim.pers[#"thiefWeapon"] ) && ( victim.pers[#"thiefWeapon"].isHeroWeapon === true ) )
		{
			heroWeapon = victim.pers[#"thiefWeapon"];
		}
	}

	if ( !isdefined( heroWeapon ) )
	{
		victimGadget = victim._gadgets_player[0];
		heroWeapon = getStolenHeroWeapon( victimGadget );
	}
	
	if ( wasFullyCharged )
	{
		if ( isdefined( heroWeapon ) && isdefined( self.pers[#"thiefWeapon"] ) && heroWeapon != self.pers[#"thiefWeapon"] && ( !isdefined( self.pers[#"thiefWeaponOption"] ) || heroWeapon != self.pers[#"thiefWeaponOption"] ) && self.pers[#"thiefAllowFlip"] )
		{
			self thread giveFlipWeapon( slot, victim, heroWeapon );
		}

		// JMCCAWLEY
		// this is when you kill an enemy and you have full power yourself.
	}
	else
	{
		self clientfield::set_to_player( "thief_state", THIEF_STATE_RECEIVED_NEW_GADGET );
		self clientfield::set_to_player( "thief_weapon_option", THIEF_WEAPON_OPTION_NONE );
		self thread gadget_give_random_gadget( slot, heroWeapon, victim.entNum );
		// self thread disable_hero_gadget_activation( GetDvarFloat( "src_thief_activation_wait", THIEF_ACTIVATION_WAIT ) );
		self.pers[#"thiefWeaponOption"] = undefined;
		self.thief_new_gadget_time = GetTime();
		
		if ( isdefined( self.pers[#"thiefWeapon"] ) && ( self.pers[#"thiefWeapon"].isHeroWeapon === true ) )
		{
			self handleStolenScoreEvent( self.pers[#"thiefWeapon"] );
		}
		
		self playsoundtoplayer( "mpl_bm_specialist_bar_filled", self ); // no need to play this here, handled elsewhere
		// JMCCAWLEY
		// this is when you kill an enemy and you did not have full power and this event caused you to get full power
	}
}

function giveFlipWeapon( slot, victim, heroWeapon )
{
	self notify( "give_flip_weapon_singleton" );
	self endon( "give_flip_weapon_singleton" );

	previousGiveFlipTime = VAL( self.last_thief_give_flip_time, 0 );
	self.last_thief_give_flip_time = GetTime();
	alreadyGivenFlipThisFrame = ( previousGiveFlipTime == self.last_thief_give_flip_time );
	
	self.pers[#"thiefWeaponOption"] = heroWeapon;
	victimBodyIndex = GetVictimBodyIndex( victim, heroWeapon );
	self handleStolenScoreEvent( heroWeapon );
	
	self notify( "thief_flip_activated" );
	
	if ( self.last_thief_give_flip_time - previousGiveFlipTime > MIN_TIME_BETWEEN_GIVE_FLIP_AUDIO_MS )
		self playsoundtoplayer( "mpl_bm_specialist_coin_place", self );

	// self DisableOffhandSpecial();
	// self thread failsafe_reenable_offhand_special();
	
	// wait for new gadget flip animation to finish before allowing second weapon flip
	elapsed_time = ( GetTime() - VAL( self.thief_new_gadget_time, 0 ) ) * 0.001;
	if ( elapsed_time < THIEF_NEW_GADGET_ANIM_TIME )
		wait ( THIEF_NEW_GADGET_ANIM_TIME - elapsed_time );
	
	self clientfield::set_to_player( "thief_state", THIEF_STATE_DONE_FLIPING );
	self thread watchForOptionUse( slot, victimBodyIndex, false );	
}

function givePreviouslyEarnedSpecialistWeapon( slot, justSpawned )
{
	
	if ( isdefined( self.pers[#"thiefWeapon"] ) )
	{
		self thread gadget_give_random_gadget( slot, self.pers[#"thiefWeapon"], self.pers[#"thiefWeaponStolenFrom"], justSpawned );
		
		if ( isdefined( self.pers[#"thiefWeaponOption"] ) )
		{
			self thread watchForOptionUse( slot, self.pers[#"thief_weapon_option_body_index"], justSpawned );
		}
	}
}

function disable_hero_gadget_activation( duration )
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "thief_flip_activated" );

	self DisableOffhandSpecial();
	
	wait duration;

	self EnableOffhandSpecial();
}

function failsafe_reenable_offhand_special()
{
	self endon( "end_failsafe_reenable_offhand_special" );
	
	wait 3.0;
	
	if ( isdefined( self ) )
	{
		self EnableOffhandSpecial();
	}
}


function handleStolenScoreEvent( heroweapon )
{
	switch( heroweapon.name )
	{
		case "hero_minigun":
		case "hero_minigun_body3":
			event = "minigun_stolen";
			label = "SCORE_MINIGUN_STOLEN";
			break;
		case "hero_flamethrower":
			event = "flamethrower_stolen";
			label = "SCORE_FLAMETHROWER_STOLEN";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			event = "lightninggun_stolen";
			label = "SCORE_LIGHTNINGGUN_STOLEN";
			break;
		case "hero_chemicalgelgun":
		case "hero_firefly_swarm":
			event = "gelgun_stolen";
			label = "SCORE_GELGUN_STOLEN";
			break;
		case "hero_pineapplegun":
		case "hero_pineapple_grenade":
			event = "pineapple_stolen";
			label = "SCORE_PINEAPPLE_STOLEN";
			break;
		case "hero_armblade":
			event = "armblades_stolen";
			label = "SCORE_ARMBLADES_STOLEN";
			break;
		case "hero_bowlauncher":
		case "hero_bowlauncher2":
		case "hero_bowlauncher3":
		case "hero_bowlauncher4":
			event = "bowlauncher_stolen";
			label = "SCORE_BOWLAUNCHER_STOLEN";
			break;
		case "hero_gravityspikes":
			event = "gravityspikes_stolen";
			label = "SCORE_GRAVITYSPIKES_STOLEN";
			break;
		case "hero_annihilator":
			event = "annihilator_stolen";
			label = "SCORE_ANNIHILATOR_STOLEN";
			break;
		default:
			return;
	}
	
	// note: score events with 0 score from scoreinfo.csv are considered "disabled"
	// thread scoreevents::processScoreEvent( event, self );
	
	// send as LUI notify instead
	self LUINotifyEvent( &"score_event", 5, iString( label ), 0 /*score*/, 0 /*combatEfficiencyBonus*/ , 0 /*rampageBonus*/, 1 /*thief score*/ );
}

function watchForHeroKill( slot )
{
	self notify( "watchForThiefKill_singleton" );
	self endon ( "watchForThiefKill_singleton" );
	
	self.gadgetThiefActive = true;
	
	while( 1 )
	{
		self waittill( "hero_shutdown_gadget", heroGadget, victim );

		stolenHeroWeapon = getStolenHeroWeapon( heroGadget );
		
		performClientSideEffect = false; // disabling client side effects for now
		if ( performClientSideEffect )
		{
			self spawnThiefBeamEffect( victim.origin );
			clientSideEffect = spawn( "script_model", victim.origin );
			clientSideEffect clientfield::set( "gadget_thief_fx", 1 );
			clientSideEffect thread waitthendelete( 5 );
		}
		
		// KSHERWOOD
		// This is when Blackjack Shuts down an Enemy to Steal their Weapon.

		if ( isdefined( level.gadgetThiefShutdownFullcharge ) && level.gadgetThiefShutdownFullcharge )
		{
			if ( self gadgetIsActive( slot ) == false )
			{
				scoreevents::processScoreEvent( "thief_shutdown_enemy", self );
				//self.pers[#"thiefWeaponOption"] = stolenHeroWeapon;
				
				//DROCHE
				
				//self thread gadget_give_random_gadget( slot, stolenHeroWeapon, victim.entNum );
				
				power = self gadgetPowerGet( slot );
				self GadgetPowerSet( slot, 100.0 );
				
				wasFullyCharged = ( power >= 100 );
				self earnedSpecialistWeapon( victim, slot, wasFullyCharged, stolenHeroWeapon );
			}
		}
	}
}

function spawnThiefBeamEffect( origin )
{
		clientSideEffect = spawn( "script_model", origin );
		clientSideEffect clientfield::set( "gadget_thief_fx", 1 );
		
		clientSideEffect thread waitthendelete( 5 );
}

function waitthendelete( time )
{
	wait ( time );
	self delete();
}

function gadget_give_random_gadget( slot, weapon, weaponStolenFromEntnum, justSpawned = false ) 
{
	previousGadget = undefined; // script compiler complains if this is not here

	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( isdefined( self._gadgets_player[i] ) )
		{
			if ( !isdefined( previousGadget ) )
			{
				previousGadget = self._gadgets_player[i];
			}
			self TakeWeapon( self._gadgets_player[i] );
		}
	}

	if( !isDefined( weapon ) )
	{
		weapon = array::random( level.gadgetthiefarray );
	}
	
	selectedWeapon = weapon;


	self GiveWeapon( selectedWeapon );

	self GadgetCharging( slot, level.gadgetThiefTimeCharge );
	self.gadgetThiefChargingSlot = slot;

	self.pers[#"thiefWeapon"] = selectedWeapon;
	self.pers[#"thiefWeaponStolenFrom"] = weaponStolenFromEntnum;
	
	if ( !isdefined( previousGadget ) || previousGadget != selectedWeapon )
	{
		self notify( "thief_hero_weapon_changed", justSpawned, selectedWeapon );
	}

	self thread watchGadgetActivated( slot );
}

function watchForOptionUse( slot, victimBodyIndex, justSpawned )
{
	self endon( "death" );
	self endon( "hero_gadget_activated" );
	self notify( "watchForOptionUse_thief_singleton" );
	self endon ( "watchForOptionUse_thief_singleton" );
	
	if ( self.pers[#"thiefAllowFlip"] == false )
		return;
	
	self clientfield::set_to_player( "thief_weapon_option", victimBodyIndex + 1 ); //sending this value to lua which uses 1-index
	self.pers[#"thief_weapon_option_body_index"] = victimBodyIndex;
	
	if ( !justSpawned )
	{
		wait THIEF_PRE_FLIP_WAIT_TIME; // wait until the "flip activated" animation is done

		self EnableOffhandSpecial();
		self notify( "end_failsafe_reenable_offhand_special" );
	}

	while( 1 )
	{
		if ( self dpad_left_pressed() )
		{
			self clientfield::set_to_player( "thief_state", THIEF_STATE_RECEIVED_NEW_GADGET );
			self clientfield::set_to_player( "thief_weapon_option", THIEF_WEAPON_OPTION_NONE );
			self.pers[#"thiefWeapon"] = self.pers[#"thiefWeaponOption"];
			self.pers[#"thiefWeaponOption"] = undefined;
			self.pers[#"thiefAllowFlip"] = false;
			self thread gadget_give_random_gadget( slot, self.pers[#"thiefWeapon"], self.pers[#"thiefWeaponStolenFrom"] );
			
			if ( isdefined( level.playGadgetReady ) )
			{
				self thread [[level.playGadgetReady]]( self.pers[#"thiefWeapon"], true );
			}
			
			return;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function dpad_left_pressed()
{
	return self ActionSlotThreeButtonPressed();
}

function watchHeroWeaponChanged()
{
	self notify( "watchHeroWeaponChanged_singleton" );
	self endon ( "watchHeroWeaponChanged_singleton" );
	
	self endon( "death" );
	self endon( "disconnect" );

	while( 1 )
	{
		self waittill( "thief_hero_weapon_changed", justSpawned, newWeapon );
		
		if ( justSpawned )
		{
			if ( isdefined( newWeapon ) && isdefined( newWeapon.gadgetReadySoundPlayer ) )
			{
				self playsoundtoplayer( newWeapon.gadgetReadySoundPlayer, self );
			}
		}
		else
		{
			self playsoundtoplayer( "mpl_bm_specialist_thief", self );
		}
	}
}

function watchGadgetActivated( slot )
{
	self notify( "watchGadgetActivated_singleton" );
	self endon ( "watchGadgetActivated_singleton" );
	
	self waittill( "hero_gadget_activated" );
	self clientfield::set_to_player( "thief_weapon_option", THIEF_WEAPON_OPTION_NONE );
	
	self.pers[#"thiefWeapon"] = undefined;
	self.pers[#"thiefWeaponOption"] = undefined;
	self.pers[#"thiefAllowFlip"] = true;
	
	self waittill( "heroAbility_off" );
	power = self gadgetPowerGet( slot );
	power = Int( power / getThiefPowerGain() ) * getThiefPowerGain();
	self GadgetPowerSet( slot, power );
	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( isdefined( self._gadgets_player[i] ) )
		{
			self TakeWeapon( self._gadgets_player[i] );
		}
	}
	self GiveWeapon( getweapon( "gadget_thief" ) );
	self clientfield::set_to_player( "thief_state", THIEF_STATE_DEFAULT );
}

function gadget_thief_on_deactivate( slot, weapon )
{
	self waittill( "heroAbility_off" );
	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( isdefined( self._gadgets_player[i] ) )
		{
			self TakeWeapon( self._gadgets_player[i] );
		}
	}
	self GiveWeapon( weapon );
	self GadgetCharging( slot, level.gadgetThiefTimeCharge  );
	self.gadgetThiefChargingSlot = slot;
	//self.pers[#"thiefWeapon"] = undefined;
}

function gadget_thief_flicker( slot, weapon )
{
}

function set_gadget_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
	{
		self IPrintlnBold( "Gadget thief: " + status + timeStr );
	}
}

function GetVictimBodyIndex( victim, heroWeapon )
{
	bodyIndex = victim GetCharacterBodyType();
	
	if ( bodyIndex == BLACKJACK_BODY_INDEX )
	{
		// we can't use Blackjack's body index, we need the body type associated with the weapon
		// pulled from mp_character_customization gdt (thus hardcoded for now)
		switch( heroWeapon.name )
		{
			case "hero_minigun":
			case "hero_minigun_body3":
				bodyIndex = 6;
				break;
			case "hero_flamethrower":
				bodyIndex = 8;
				break;
			case "hero_lightninggun":
				bodyIndex = 2;
				break;
			case "hero_chemicalgelgun":
				bodyIndex = 5;
				break;
			case "hero_pineapplegun":
				bodyIndex = 3;
				break;
			case "hero_armblade":
				bodyIndex = 7;
				break;
			case "hero_bowlauncher":
			case "hero_bowlauncher2":
			case "hero_bowlauncher3":
			case "hero_bowlauncher4":
				bodyIndex = 1;
				break;
			case "hero_gravityspikes":
				bodyIndex = 0;
				break;
			default:
			case "hero_annihilator":
				bodyIndex = 4;
				break;
		}
	}
	
	return bodyIndex;
}
