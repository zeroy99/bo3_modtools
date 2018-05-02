#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\drown;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapon_utils;

#using scripts\mp\_util;
#using scripts\mp\_challenges;
#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_loadout;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;

#insert scripts\mp\_bonuscard.gsh;
#insert scripts\mp\_contracts.gsh;

#define DEFAULT_DAILY_CRYPTOKEYS			10 // look for dvar loot_cryptokeyCost
#define DEFAULT_WEEKLY_CRYPTOKEYS			30 // look for dvar loot_cryptokeyCost
#define DEFAULT_CRYPTOKEY_LOOTXP			100

#define ATTACHMENT_COUNT_FOR_LOADED_WEAPON_KILL		4
	
#define MAX_CONTRACT_SLOTS					10	// should coincide with contracts array size on mp_stats.ddl
#define FIRST_UNASSIGNED_CONTRACT_SLOT		3
#define DEFAULT_DEBUG_CONTRACT_SLOT			MAX_CONTRACT_SLOTS - 1

// contract string table and columns
#define CONTRACT_TABLE						"gamedata/tables/mp/mp_contractTable.csv"
#define INDEX_COL							0
#define TARGET_VALUE_COL					2
#define NAME_STRING_COL						3
#define TITLE_OVERRIDE_COL					4
#define CONTRACT_TYPE						5
#define CK_COST_COL							6
#define CALLING_CARD_STAT_COL				7	// mp_stats.ddl, PlayerStatsList[ <stat_name> ]
#define WEAPON_CAMO_STAT_COL				8	// mp_stats.ddl, PlayerStatsList[ <stat_name> ]
#define ABSOLUTE_STAT_PATH_COL				9	// mp_stats.ddl

// table index values from mp_contractTable.csv

// weekly contracts
#define BIG_TOTAL_WINS_INDEX					1
#define BIG_OBJECTIVE_WINS_INDEX				2
#define BIG_MEDALS_SPECIALIST_ABILITIES_INDEX	3
#define BIG_KILLS_INDEX							4
#define	BIG_SCORE_INDEX							5
#define ATTACKER_DEFENDER_KILLS_INDEX			6
#define BIG_KILLS_SPECIALIST_WEAPON_INDEX		7
#define BIG_KILLS_KILLSTREAK_INDEX				8
	
// daily contracts
#define TOTAL_WINS_INDEX						1000
#define ARENA_WINS_INDEX						1001
#define TDM_WINS_INDEX							1002
#define BALL_WINS_INDEX							1003
#define ESCORT_WINS_INDEX						1004
#define CONF_WINS_INDEX							1005
#define SD_WINS_INDEX							1006
#define KOTH_WINS_INDEX							1007
#define DOM_WINS_INDEX							1008
#define SCORE_INDEX								1009
#define KILLS_KILLSTREAK_INDEX					1010
#define KILLSTREAK_SCORE_INDEX					1011
#define KILLS_SPECIALIST_WEAPON_INDEX			1012
#define MEDALS_SPECIALIST_ABILITIES_INDEX		1013
#define SPECIALIST_KILLED_INDEX					1014
#define	KILLS_INDEX								1015
#define HEADSHOTS_INDEX							1016
#define KILLED_DEFENDER_INDEX					1017
#define KILLED_ATTACKER_INDEX					1018
#define AR_KILL_INDEX							1019
#define SMG_KILL_INDEX							1020
#define SNIPER_KILL_INDEX						1021
#define LMG_KILL_INDEX							1022
#define SHOTGUN_KILL_INDEX						1023
#define PISTOL_KILL_INDEX						1024
#define LOADED_WEAPON_KILL_INDEX				1025
#define CTF_WINS_INDEX							1026
#define DEM_WINS_INDEX							1027
#define DM_WINS_INDEX							1028
#define CLEAN_WINS_INDEX						1029
	
// special contracts
#define HUGE_SMG_KILL_INDEX						3000
#define HUGE_AR_KILL_INDEX						3001
#define HUGE_SHOTGUN_KILL_INDEX					3002
#define HUGE_LMG_KILL_INDEX						3003
#define HUGE_SNIPER_KILL_INDEX					3004
#define HUGE_MELEE_WEAPON_KILL_INDEX			3005
#define HUGE_KILLS_SPECIALIST_WEAPON_INDEX		3006
#define HUGE_TOTAL_WINS_INDEX					3007
#define HUGE_TOTAL_WINS_INDEX_2					3008
#define HUGE_TOTAL_WINS_INDEX_3					3009
#define HUGE_TOTAL_WINS_INDEX_GRAND_SLAM		3010
#define HUGE_TOTAL_WINS_INDEX_4					3011
#define HUGE_TOTAL_WINS_INDEX_5					3012
#define HUGE_TOTAL_WINS_INDEX_6					3013
#define HUGE_TOTAL_WINS_INDEX_7					3014
#define HUGE_TOTAL_WINS_INDEX_8					3015

#namespace contracts;

#precache( "eventstring", "mp_daily_challenge_complete" );
#precache( "eventstring", "mp_weekly_challenge_complete" );
#precache( "eventstring", "mp_special_contract_complete" );

REGISTER_SYSTEM( "contracts", &__init__, undefined )

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
	
	util::init_player_contract_events(); // must always initialize

	waittillframeend;
		
	if ( can_process_contracts() )
	{
		challenges::registerChallengesCallback( "playerKilled",&contract_kills );	
		challenges::registerChallengesCallback( "gameEnd",&contract_game_ended );
		globallogic_score::registerContractWinEvent( &contract_win );
		scoreevents::register_hero_ability_kill_event( &on_hero_ability_kill );
		scoreevents::register_hero_ability_multikill_event( &on_hero_ability_multikill );
		scoreevents::register_hero_weapon_multikill_event( &on_hero_weapon_multikill );

		util::register_player_contract_event( "score", &on_player_score, 1 );
		util::register_player_contract_event( "killstreak_score", &on_killstreak_score, 2 );
		util::register_player_contract_event( "offender_kill", &on_offender_kill );
		util::register_player_contract_event( "defender_kill", &on_defender_kill );
		util::register_player_contract_event( "headshot", &on_headshot_kill );
		util::register_player_contract_event( "killed_hero_ability_enemy", &on_killed_hero_ability_enemy );
		util::register_player_contract_event( "killed_hero_weapon_enemy", &on_killed_hero_weapon_enemy );
		util::register_player_contract_event( "earned_specialist_ability_medal", &on_hero_ability_medal );
		
		// globallogic::registerOtherLootXPAwards( &award_loot_xp ); // intentionally commented out, will use mp_loot_xp_due instead for now
	}
	
	callback::on_connect( &on_player_connect );
}

function on_killed_hero_ability_enemy()
{
	self add_stat( SPECIALIST_KILLED_INDEX );
}

function on_killed_hero_weapon_enemy()
{
	self add_stat( SPECIALIST_KILLED_INDEX );	
}

function on_player_connect()
{
	player = self;
		
	if ( can_process_contracts() )
	{
		player setup_player_contracts();
	}
}

function can_process_contracts()
{
	if ( GetDvarInt( "contracts_enabled_mp", 1 ) == 0 ) // mp contracts kill switch
		return false;

	return challenges::canProcessChallenges();
}

function setup_player_contracts()
{
	player = self;
	
	player.pers["contracts"] = [];

	// no need to setup active contracts for bots	
	if ( player util::is_bot() )
		return;

	for( slot = 0; slot < MAX_CONTRACT_SLOTS; slot++ )
	{
		if ( get_contract_stat( slot, "active" ) && !get_contract_stat( slot, "award_given" ) )
		{
			contract_index = get_contract_stat( slot, "index" );
			player.pers["contracts"][contract_index] = SpawnStruct();
			player.pers["contracts"][contract_index].slot = slot;
			table_row = TableLookupRowNum( CONTRACT_TABLE, INDEX_COL, contract_index );
			player.pers["contracts"][contract_index].table_row = table_row;
			player.pers["contracts"][contract_index].target_value =  int( TableLookupColumnForRow( CONTRACT_TABLE, table_row, TARGET_VALUE_COL ) );
			player.pers["contracts"][contract_index].calling_card_stat = TableLookupColumnForRow( CONTRACT_TABLE, table_row, CALLING_CARD_STAT_COL );
			player.pers["contracts"][contract_index].weapon_camo_stat = TableLookupColumnForRow( CONTRACT_TABLE, table_row, WEAPON_CAMO_STAT_COL );
			player.pers["contracts"][contract_index].absolute_stat_path = TableLookupColumnForRow( CONTRACT_TABLE, table_row, ABSOLUTE_STAT_PATH_COL );
		}
	}
}

function is_contract_active( challenge_index )
{
	if ( !isPlayer( self ) )
		return false;

	if ( !isdefined( self.pers["contracts"] ) )
		return false;
	
	if ( !isdefined( self.pers["contracts"][challenge_index] ) )
		return false;

	// sanity check... better than causing an SRE
	if ( self.pers["contracts"][challenge_index].table_row == -1 )
		return false;

	return true;
}

function on_hero_ability_kill( ability, victimAbility )
{
	player = self;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
}

function on_hero_ability_medal()
{
	player = self;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;

	player add_stat( MEDALS_SPECIALIST_ABILITIES_INDEX );
	player add_stat( BIG_MEDALS_SPECIALIST_ABILITIES_INDEX );
}

function on_hero_ability_multikill( killcount, ability )
{
	player = self;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
}

function on_hero_weapon_multikill( killcount, weapon )
{
	player = self;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
}

function on_player_score( delta_score )
{
	self add_stat( SCORE_INDEX, delta_score );
	self add_stat( BIG_SCORE_INDEX, delta_score );
}

function on_killstreak_score( delta_score, killstreak_purchased )
{
	if ( killstreak_purchased )
	{
		self add_stat( KILLSTREAK_SCORE_INDEX, delta_score );
	}
}

function contract_kills( data )
{		
	victim = data.victim;
	attacker = data.attacker;
	player = attacker;
	weapon = data.weapon;
	time = data.time;
	
	if ( !isdefined( weapon ) || ( weapon == level.weaponNone ) )
		return;
	
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	
	player add_stat( KILLS_INDEX );
	player add_stat( BIG_KILLS_INDEX );
	
	if ( weapon.isHeroWeapon === true )
	{
		player add_stat( KILLS_SPECIALIST_WEAPON_INDEX );
		player add_stat( BIG_KILLS_SPECIALIST_WEAPON_INDEX );
		player add_stat( HUGE_KILLS_SPECIALIST_WEAPON_INDEX );
	}
	
	isKillstreak = isdefined( data.eInflictor ) && isdefined( data.eInflictor.killstreakid );
	if ( !isKillstreak && isdefined( level.isKillstreakWeapon ) )
	{
		isKillstreakWeapon = [[level.isKillstreakWeapon]]( weapon );
	}
	
	if ( isKillstreak || ( isKillstreakWeapon === true ) )
	{
		player add_stat( KILLS_KILLSTREAK_INDEX );
		player add_stat( BIG_KILLS_KILLSTREAK_INDEX );
	}
	
	statItemIndex = weapon.statIndex;
	
	if ( player isItemPurchased( statItemIndex ) )
	{
		weaponClass = util::getWeaponClass( weapon );
	    
		switch ( weaponClass ) // aka group in mp_statsTable
		{
			case "weapon_assault":
				player add_stat( AR_KILL_INDEX );
				player add_stat( HUGE_AR_KILL_INDEX );
				break;
				
			case "weapon_smg":
				player add_stat( SMG_KILL_INDEX );
				player add_stat( HUGE_SMG_KILL_INDEX );
				break;
				
			case "weapon_sniper":
				player add_stat( SNIPER_KILL_INDEX );
				player add_stat( HUGE_SNIPER_KILL_INDEX );
				break;
				
			case "weapon_lmg":
				player add_stat( LMG_KILL_INDEX );
				player add_stat( HUGE_LMG_KILL_INDEX );
				break;
				
			case "weapon_cqb":
				player add_stat( SHOTGUN_KILL_INDEX );
				player add_stat( HUGE_SHOTGUN_KILL_INDEX );
				break;
				
			case "weapon_pistol":
				player add_stat( PISTOL_KILL_INDEX );
				break;
				
			case "weapon_knife":
				player add_stat( HUGE_MELEE_WEAPON_KILL_INDEX );
				break;
			
			default:
				break;
		}

		total_unlocked = player GetTotalUnlockedWeaponAttachments( weapon );
		if ( total_unlocked >= ATTACHMENT_COUNT_FOR_LOADED_WEAPON_KILL )
		{
			player add_stat( LOADED_WEAPON_KILL_INDEX );
		}
	} 
}

function add_stat( contract_index, delta )
{
	if ( self is_contract_active( contract_index ) )
	{
		self add_active_stat( contract_index, delta );
	}
}

function add_active_stat( contract_index, delta = 1 )
{
	slot = self.pers["contracts"][contract_index].slot;
	target_value = self.pers["contracts"][contract_index].target_value;

	old_progress = get_contract_stat( slot, "progress" );
	new_progress = old_progress + delta;
	
	if ( new_progress > target_value )
		new_progress = target_value;
	
	if ( new_progress != old_progress )
		self set_contract_stat( slot, "progress", new_progress );
	
	just_completed = false;
	if ( old_progress < target_value && target_value <= new_progress )
	{
		just_completed = true;
		
		// notify contract achieved		
		event = &"mp_weekly_challenge_complete";
		display_rewards = false;

		if ( slot == MP_CONTRACT_DAILY_SLOT )
		{
			event = &"mp_daily_challenge_complete";
			display_rewards = true;
			
			self award_loot_xp_due( award_daily_contract() );
			self set_contract_stat( MP_CONTRACT_DAILY_SLOT, "award_given", 1 );			
		}
		else if ( slot == MP_CONTRACT_WEEKLY_SLOT_A || slot == MP_CONTRACT_WEEKLY_SLOT_B )
		{
			other_slot = MP_CONTRACT_WEEKLY_SLOT_B;
			if ( slot == MP_CONTRACT_WEEKLY_SLOT_B )
			{
				other_slot = MP_CONTRACT_WEEKLY_SLOT_A;
			}
			
			foreach ( c_index,c_data in self.pers["contracts"] )
			{
				if ( c_data.slot == other_slot )
				{
					if ( c_data.target_value <= get_contract_stat( other_slot, "progress" ) )
					{
						display_rewards = true;
						
						self award_loot_xp_due( award_weekly_contract() );
						self set_contract_stat( MP_CONTRACT_WEEKLY_SLOT_A, "award_given", 1 );
						self set_contract_stat( MP_CONTRACT_WEEKLY_SLOT_B, "award_given", 1 );
					}
					
					break;
				}
			}
		}
		else if ( slot == MP_CONTRACT_SPECIAL_SLOT )
		{
			event = &"mp_special_contract_complete";
			display_rewards = true;
			
			absolute_stat_path = self.pers["contracts"][contract_index].absolute_stat_path;
			if ( absolute_stat_path != "" )
			{
				set_contract_award_stat_from_path( absolute_stat_path, true );
			}
			
			calling_card_stat = self.pers["contracts"][contract_index].calling_card_stat;
			if ( calling_card_stat != "" )
			{
				set_contract_award_stat( "calling_card", calling_card_stat );
			}
			
			weapon_camo_stat = self.pers["contracts"][contract_index].weapon_camo_stat;
			if ( weapon_camo_stat != "" )
			{
				set_contract_award_stat( "weapon_camo", weapon_camo_stat );
			}
				
			self set_contract_stat( MP_CONTRACT_SPECIAL_SLOT, "award_given", 1 );
		}
		
		
		self LUINotifyEvent( event, 2, contract_index, display_rewards );
	}
}

function get_contract_stat( slot, stat_name )
{
	return self GetDStat( "contracts", slot, stat_name );
}

function set_contract_stat( slot, stat_name, stat_value )
{
	return self SetDStat( "contracts", slot, stat_name, stat_value );
}

function set_contract_award_stat( award_type, stat_name, stat_value = 1 )
{
	// award_type is unused for now as we use PlayerStatsList for now
	
	return self AddPlayerStat( stat_name, stat_value );
}

function set_contract_award_stat_from_path( stat_path, stat_value )
{
	stat_path_array = StrTok( stat_path, " " );
	
	string_path_1 = "";
	string_path_2 = "";
	string_path_3 = "";
	string_path_4 = "";
	string_path_5 = "";
	
	switch( stat_path_array.size )
	{
		case 5:
			string_path_5 = stat_path_array[4];
			if( StrIsNumber( string_path_5 ) )
			{
				string_path_5 = Int( string_path_5 );
			}
		case 4:
			string_path_4 = stat_path_array[3];
			if( StrIsNumber( string_path_4 ) )
			{
				string_path_4 = Int( string_path_4 );
			}
		case 3:
			string_path_3 = stat_path_array[2];
			if( StrIsNumber( string_path_3 ) )
			{
				string_path_3 = Int( string_path_3 );
			}
		case 2:
			string_path_2 = stat_path_array[1];
			if( StrIsNumber( string_path_2 ) )
			{
				string_path_2 = Int( string_path_2 );
			}
		case 1:
			string_path_1 = stat_path_array[0];
			if( StrIsNumber( string_path_1 ) )
			{
				string_path_1 = Int( string_path_1 );
			}
	}
		
	switch( stat_path_array.size )
	{
		case 1:
			return self SetDStat( string_path_1, stat_value );
			break;
		case 2:
			return self SetDStat( string_path_1, string_path_2, stat_value );
			break;
		case 3:
			return self SetDStat( string_path_1, string_path_2, string_path_3, stat_value );
			break;
		case 4:
			return self SetDStat( string_path_1, string_path_2, string_path_3, string_path_4, stat_value );
			break;
		case 5:
			return self SetDStat( string_path_1, string_path_2, string_path_3, string_path_4, string_path_5, stat_value );
			break;
		default:
			AssertMsg( "Stat path depth of " + stat_path_array.size + " is too large. Limit to 5 deep" );
			break;
	}
}

function award_loot_xp_due( amount )
{
	if ( !isdefined( self ) )
		return;
	
	if ( amount <= 0 )
		return;

	current_amount = VAL( self GetDStat( "mp_loot_xp_due" ), 0 );
	new_amount = current_amount + amount;
	self SetDStat( "mp_loot_xp_due", new_amount );
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

function contract_game_ended( data )
{
	// TODO: award challenge award here: maybe
}

function contract_win( winner )
{
	winner add_stat( TOTAL_WINS_INDEX );
	winner add_stat( BIG_TOTAL_WINS_INDEX );
	winner add_stat( HUGE_TOTAL_WINS_INDEX );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_2 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_3 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_GRAND_SLAM );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_4 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_5 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_6 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_7 );
	winner add_stat( HUGE_TOTAL_WINS_INDEX_8 );
	
	if ( util::is_objective_game( level.gametype ) )
	{
		winner add_stat( BIG_OBJECTIVE_WINS_INDEX );
	}
	
	if ( IsArenaMode() )
	{
		winner add_stat( ARENA_WINS_INDEX );
	}
	
	gametype_win( winner );
}

function gametype_win( winner )
{
	switch ( level.gametype )
	{
		case "tdm":
			winner add_stat( TDM_WINS_INDEX );
			break;
		
		case "ball":
			winner add_stat( BALL_WINS_INDEX );
			break;
			
		case "escort":
			winner add_stat( ESCORT_WINS_INDEX );
			break;
			
		case "conf":
			winner add_stat( CONF_WINS_INDEX );
			break;
			
		case "sd":
			winner add_stat( SD_WINS_INDEX );
			break;
			
		case "koth":
			winner add_stat( KOTH_WINS_INDEX );
			break;
			
		case "dom":
			winner add_stat( DOM_WINS_INDEX );
			break;
			
		case "ctf":
			winner add_stat( CTF_WINS_INDEX );
			break;
			
		case "dem":
			winner add_stat( DEM_WINS_INDEX );
			break;
			
		case "dm":
			winner add_stat( DM_WINS_INDEX );
			break;
			
		case "clean":
			winner add_stat( CLEAN_WINS_INDEX );
			break;
			
		default:
			break;
	}
}

function on_offender_kill()
{
	self add_stat( KILLED_ATTACKER_INDEX );
	self add_stat( ATTACKER_DEFENDER_KILLS_INDEX );
}

function on_defender_kill()
{
	self add_stat( KILLED_DEFENDER_INDEX );
	self add_stat( ATTACKER_DEFENDER_KILLS_INDEX );
}

function on_headshot_kill()
{
	self add_stat( HEADSHOTS_INDEX, 1 );	
}

function award_loot_xp()
{
	player = self;
	
	if ( !isdefined( player.pers["contracts"] ) )
		return 0;
	
	loot_xp = 0;

	//
	// daily contract
	//
	daily_slot = MP_CONTRACT_DAILY_SLOT;
	if ( get_contract_stat( daily_slot, "active" ) && !get_contract_stat( daily_slot, "award_given" ) )
	{
		if ( contract_slot_met( daily_slot ) )
		{
			loot_xp += player award_daily_contract();
			player set_contract_stat( daily_slot, "award_given", 1 );
		}
	}
	
	//
	// weekly contract
	//
	weekly_slot_A = MP_CONTRACT_WEEKLY_SLOT_A;
	weekly_slot_B = MP_CONTRACT_WEEKLY_SLOT_B;
	if ( get_contract_stat( weekly_slot_A, "active" ) && !get_contract_stat( weekly_slot_A, "award_given" ) &&
	  	 get_contract_stat( weekly_slot_B, "active" ) && !get_contract_stat( weekly_slot_B, "award_given" ) )
	{
		if ( contract_slot_met( weekly_slot_A ) && contract_slot_met( weekly_slot_B ) )
		{
			loot_xp += player award_weekly_contract();
			player set_contract_stat( weekly_slot_A, "award_given", 1 );
			player set_contract_stat( weekly_slot_B, "award_given", 1 );
		}
	}
	
	return loot_xp;
}

function contract_slot_met( slot )
{
	player = self;
	
	contract_index = get_contract_stat( slot, "index" );
	
	if ( !isdefined( player.pers["contracts"][contract_index] ) )
	    return false;

	progress = player get_contract_stat( slot, "progress" );
	target_value = player.pers["contracts"][contract_index].target_value;

	return ( progress >= target_value );
}

function award_daily_contract()
{
	return GetDvarInt( "daily_contract_cryptokey_reward_count", DEFAULT_DAILY_CRYPTOKEYS ) * GetDvarInt( "loot_cryptokeyCost", DEFAULT_CRYPTOKEY_LOOTXP );
}

function award_weekly_contract()
{
	self award_blackjack_contract();
	
	return GetDvarInt( "weekly_contract_cryptokey_reward_count", DEFAULT_WEEKLY_CRYPTOKEYS ) * GetDvarInt( "loot_cryptokeyCost", DEFAULT_CRYPTOKEY_LOOTXP ); 
}

function award_blackjack_contract()
{
	contract_count = self GetDStat( "blackjack_contract_count" );
	reward_count = GetDvarInt( "weekly_contract_blackjack_contract_reward_count", 1 );
	self SetDStat( "blackjack_contract_count", contract_count + reward_count );
}
