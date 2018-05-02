#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\drown;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapon_utils;

#using scripts\mp\_challenges;
#using scripts\mp\gametypes\_loadout;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#insert scripts\mp\_bonuscard.gsh;

#define BLACKJACK_SPECIALIST_INDEX				9
#define BLACKJACK_SPECIALIST_KILLS				4	// for blackjack challenge: kills while using a specialist weapon or ability
#define BLACKJACK_UNIQUE_SPECIALIST_KILLS		2	// for blackjack challenge: count of unique specialist weapons or abilities used to kill

#namespace blackjack_challenges;

REGISTER_SYSTEM( "blackjack_challenges", &__init__, undefined )

function __init__()
{
	callback::on_start_gametype( &start_gametype );
}

function start_gametype()
{
	if ( !isdefined( level.ChallengesCallbacks ) )
	{
		level.ChallengesCallbacks = [];
	}
	
	waittillframeend;
	
	if ( challenges::canProcessChallenges() )
	{
		challenges::registerChallengesCallback( "playerKilled",&challenge_kills );
		challenges::registerChallengesCallback( "roundEnd",&challenge_round_ended );
		challenges::registerChallengesCallback( "gameEnd",&challenge_game_ended );
		scoreevents::register_hero_ability_kill_event( &on_hero_ability_kill );
	}
	
	callback::on_connect( &on_player_connect );
}

function on_player_connect()
{
	player = self;
	if ( challenges::canProcessChallenges() )
	{
		specialistIndex = player GetSpecialistIndex();
		isBlackjack = ( specialistIndex == BLACKJACK_SPECIALIST_INDEX );
		if ( isBlackjack )
		{
			player thread track_blackjack_consumable();
			
			if ( !isdefined( self.pers[ "blackjack_challenge_active" ] ) )
			{
				remaining_time = player ConsumableGet( "blackjack", "awarded" ) - player ConsumableGet( "blackjack", "consumed" );
				
				if ( remaining_time > 0 )
				{
					special_card_earned = player get_challenge_stat( "special_card_earned" );
					if ( !special_card_earned )
					{
						player.pers[ "blackjack_challenge_active" ] = true;
						player.pers[ "blackjack_unique_specialist_kills" ] = 0;
						player.pers[ "blackjack_specialist_kills" ] = 0;
						player.pers[ "blackjack_unique_weapon_mask" ] = 0;
						player.pers[ "blackjack_unique_ability_mask" ] = 0;
					}
				}
			}
		}
	}
}

function is_challenge_active()
{
	return ( self.pers[ "blackjack_challenge_active" ] === true );
}

function on_hero_ability_kill( ability, victimAbility )
{
	player = self;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;	
	
	if ( !isdefined( player.isRoulette ) || !player.isRoulette )
		return;
	
	if ( player is_challenge_active() )
	{
		player.pers[ "blackjack_specialist_kills" ]++;
	
		currentHeroAbilityMask = player.pers[ "blackjack_unique_ability_mask" ];
		heroAbilityMask = get_hero_ability_mask( ability );
		newHeroAbilityMask = heroAbilityMask | currentHeroAbilityMask;
		if ( newHeroAbilityMask != currentHeroAbilityMask )
		{
			player.pers[ "blackjack_unique_specialist_kills" ]++;
			player.pers[ "blackjack_unique_ability_mask" ] = newHeroAbilityMask;
		}
		
		player check_blackjack_challenge();
	}
}

function check_blackjack_challenge()
{
	player = self;
		
	special_card_earned = player get_challenge_stat( "special_card_earned" );
	if ( special_card_earned )
	{
		return;
	}
	
	if ( ( player.pers[ "blackjack_specialist_kills" ] >= BLACKJACK_SPECIALIST_KILLS ) &&
		 ( player.pers[ "blackjack_unique_specialist_kills" ] >= BLACKJACK_UNIQUE_SPECIALIST_KILLS ) )
	{
		player set_challenge_stat( "special_card_earned", 1 );
		player AddPlayerStat( "blackjack_challenge", 1 );
	}
}

function challenge_kills( data )
{	
	attackerisThief						= data.attackerIsThief;
	attackerIsRoulette					= data.attackerIsRoulette;
	attackerIsThiefOrRoulette			= attackerisThief || attackerIsRoulette;

	if ( !attackerIsThiefOrRoulette )
		return;
	
	victim = data.victim;
	attacker = data.attacker;
	player = attacker;
	weapon = data.weapon;
	
	if ( !isdefined( weapon ) || ( weapon == level.weaponNone ) )
		return;

	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	
	if ( attackerIsThief )
	{
		if ( weapon.isHeroWeapon === true )
		{			
			if ( player is_challenge_active() )
			{
				player.pers[ "blackjack_specialist_kills" ]++;
			
				currentHeroWeaponMask = player.pers[ "blackjack_unique_weapon_mask" ];
				heroWeaponMask = get_hero_weapon_mask( attacker, weapon );
				newHeroWeaponMask = heroWeaponMask | currentHeroWeaponMask;
				if ( newHeroWeaponMask != currentHeroWeaponMask )
				{
					player.pers[ "blackjack_unique_specialist_kills" ] += 1;
					player.pers[ "blackjack_unique_weapon_mask" ] = newHeroWeaponMask;
				}
				
				player check_blackjack_challenge();
			}
		}
	}
	
	// ability kills are handled as events fired from score events
	// if ( attackerIsRoulette )
	// {	
	// }
}

function get_challenge_stat( stat_name )
{
	return self GetDStat( "tenthspecialistcontract", stat_name );
}

function set_challenge_stat( stat_name, stat_value )
{
	return self SetDStat( "tenthspecialistcontract", stat_name, stat_value );
}

function get_hero_weapon_mask( attacker, weapon )
{
	if ( !isdefined( weapon ) )
		return 0;

	if ( isdefined( weapon.isHeroWeapon ) && !weapon.isHeroWeapon )
		return 0;

	switch( weapon.name ) 
	{
		case "hero_minigun":
		case "hero_minigun_body3":
			return 1; // note: heroWeaponMask needs to stay unique and consistent for function across TUs and FFOTDs
			break;
		case "hero_flamethrower":
			return 1 << 1;
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			return 1 << 2;
			break;
		case "hero_chemicalgelgun":
		case "hero_firefly_swarm":
			return 1 << 3;
			break;
		case "hero_pineapplegun":
		case "hero_pineapple_grenade":
			return 1 << 4;
			break;
		case "hero_armblade": 
			return 1 << 5;
			break;
		case "hero_bowlauncher": 
		case "hero_bowlauncher2": 
		case "hero_bowlauncher3": 
		case "hero_bowlauncher4": 
			return 1 << 6;
			break;
		case "hero_gravityspikes":
			return 1 << 7;
			break;
		case "hero_annihilator":
			return 1 << 8;
			break;		
		default:
			return 0;
	}
}

function get_hero_ability_mask( ability )
{
	if ( !isdefined( ability ) )
		return 0;

	switch( ability.name ) 
	{
		case "gadget_clone":
			return 1; // note: heroAbilityMask needs to stay unique and consistent for functions across TUs and FFOTDs
			break;
		case "gadget_heat_wave":
			return 1 << 1;
			break;
		case "gadget_flashback":
			return 1 << 2;
			break;
		case "gadget_resurrect":
			return 1 << 3;
			break;
		case "gadget_armor":
			return 1 << 4;
			break;
		case "gadget_camo": 
			return 1 << 5;
			break;
		case "gadget_vision_pulse":
			return 1 << 6;
			break;
		case "gadget_speed_burst":
			return 1 << 7;
			break;
		case "gadget_combat_efficiency":
			return 1 << 8;
			break;		
		default:
			return 0;
	}
}

function challenge_game_ended( data )
{
	if ( !isdefined( data ) )
		return;

	player = data.player;
	if ( !isdefined( player ) )
		return;
	
	if ( !isPlayer( player ) )
		return;

	if ( player util::is_bot() )
		return;
	
	if ( !player is_challenge_active() )
		return;

	player report_consumable();
}

function challenge_round_ended( data )
{
	if ( !isdefined( data ) )
		return;

	player = data.player;
	if ( !isdefined( player ) )
		return;
	
	if ( !isPlayer( player ) )
		return;

	if ( player util::is_bot() )
		return;
	
	if ( !player is_challenge_active() )
		return;

	player report_consumable();
}

function track_blackjack_consumable()
{
	level endon( "game_ended" );
	self notify( "track_blackjack_consumable_singleton" );
	self endon( "track_blackjack_consumable_singleton" );
	self endon( "disconnect" );

	player = self;
	
	if ( !isdefined( player.last_blackjack_consumable_time ) )
		player.last_blackjack_consumable_time = 0;

	while ( isdefined( player ) )
	{
		random_wait_time = GetDvarFloat( "mp_blackjack_consumable_wait", 20.0 ) + RandomFloatRange( -5.0, 5.0 );
		wait random_wait_time;
		
		player report_consumable();
	}
}

function report_consumable()
{
	player = self;

	if ( !isdefined( player ) )
		return;
	
	if ( !isdefined( player.timePlayed ) || !isdefined( player.timePlayed["total"] ) )
		return;
	
	current_time_played = player.timePlayed["total"];
	
	time_to_report = current_time_played - player.last_blackjack_consumable_time;
	
	if ( time_to_report > 0 )
	{
		max_time_to_report = player ConsumableGet( "blackjack", "awarded" ) - player ConsumableGet( "blackjack", "consumed" );
		consumable_increment = int( min( time_to_report, max_time_to_report ) );
		if ( consumable_increment > 0 )
		{
			player ConsumableIncrement( "blackjack", "consumed", consumable_increment ); // so we don't go over awarded time
		}
	}
	
	player.last_blackjack_consumable_time = current_time_played;
}
