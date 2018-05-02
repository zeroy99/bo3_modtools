#using scripts\codescripts\struct;

#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\gametypes\_globallogic;
#using scripts\zm\gametypes\_globallogic_score;

#using scripts\zm\_zm;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_perks.gsh;

#define MATCH_FINISHED 4
	
#namespace zm_stats;

REGISTER_SYSTEM( "zm_stats", &__init__, undefined )

function __init__()
{
	// create a level function pointer, so that add_client_stat function can be called in non zm script file
	level.player_stats_init = &player_stats_init;
	level.add_client_stat = &add_client_stat;
	level.increment_client_stat = &increment_client_stat;
}

function player_stats_init()
{
	self  globallogic_score::initPersStat( "kills", false );
	self  globallogic_score::initPersStat( "suicides", false );
	self  globallogic_score::initPersStat( "downs", false );
	self.downs = self  globallogic_score::getPersStat( "downs" );

	self  globallogic_score::initPersStat( "revives", false );
	self.revives = self  globallogic_score::getPersStat( "revives" );

	self  globallogic_score::initPersStat( "perks_drank", false );
	self  globallogic_score::initPersStat( "bgbs_chewed", false );	
	self  globallogic_score::initPersStat( "headshots", false );

	self  globallogic_score::initPersStat( "melee_kills", false );
	self  globallogic_score::initPersStat( "grenade_kills", false );
	self  globallogic_score::initPersStat( "doors_purchased", false );
	
	self  globallogic_score::initPersStat( "distance_traveled", false );
	self.distance_traveled = self  globallogic_score::getPersStat( "distance_traveled" );

	self  globallogic_score::initPersStat( "total_shots", false );
	self.total_shots = self  globallogic_score::getPersStat( "total_shots" );

	self  globallogic_score::initPersStat( "hits", false );
	self.hits = self  globallogic_score::getPersStat( "hits" );

	self  globallogic_score::initPersStat( "misses", false );
	self.misses = self  globallogic_score::getPersStat( "misses" );

	self  globallogic_score::initPersStat( "deaths", false );
	self.deaths = self  globallogic_score::getPersStat( "deaths" );

	self  globallogic_score::initPersStat( "boards", false );
	
	self  globallogic_score::initPersStat( "failed_revives", false );	
	self  globallogic_score::initPersStat( "sacrifices", false );		
	self  globallogic_score::initPersStat( "failed_sacrifices", false );	
	self  globallogic_score::initPersStat( "drops", false );	
	//individual drops pickedup
	self  globallogic_score::initPersStat( "nuke_pickedup",false);
	self  globallogic_score::initPersStat( "insta_kill_pickedup",false);
	self  globallogic_score::initPersStat( "full_ammo_pickedup",false);
	self  globallogic_score::initPersStat( "double_points_pickedup",false);
	self  globallogic_score::initPersStat( "carpenter_pickedup",false);
	self  globallogic_score::initPersStat( "fire_sale_pickedup",false);
	self  globallogic_score::initPersStat( "minigun_pickedup",false);
	self  globallogic_score::initPersStat( "island_seed_pickedup",false);

	self  globallogic_score::initPersStat( "bonus_points_team_pickedup",false);
	self  globallogic_score::initPersStat( "ww_grenade_pickedup",false);
	
	self  globallogic_score::initPersStat( "use_magicbox", false );	
	self  globallogic_score::initPersStat( "grabbed_from_magicbox", false );		
	self  globallogic_score::initPersStat( "use_perk_random", false );	
	self  globallogic_score::initPersStat( "grabbed_from_perk_random", false );		
	self  globallogic_score::initPersStat( "use_pap", false );	
	self  globallogic_score::initPersStat( "pap_weapon_grabbed", false );	
	self  globallogic_score::initPersStat( "pap_weapon_not_grabbed", false );
	
	//individual perks drank
	self  globallogic_score::initPersStat( "specialty_armorvest_drank", false );	
	self  globallogic_score::initPersStat( "specialty_quickrevive_drank", false );
	self  globallogic_score::initPersStat( "specialty_fastreload_drank", false );	
	self  globallogic_score::initPersStat( "specialty_additionalprimaryweapon_drank", false );		
	self  globallogic_score::initPersStat( "specialty_staminup_drank", false );		
	self  globallogic_score::initPersStat( "specialty_doubletap2_drank", false );	
	self  globallogic_score::initPersStat( "specialty_widowswine_drank", false );
	self  globallogic_score::initPersStat( "specialty_deadshot_drank", false );	
	self  globallogic_score::initPersStat( "specialty_electriccherry_drank", false );	
	
	//weapons that can be planted/picked up ( claymores, ballistics...)
	self  globallogic_score::initPersStat( "claymores_planted", false );	
	self  globallogic_score::initPersStat( "claymores_pickedup", false );	

	self  globallogic_score::initPersStat( "bouncingbetty_planted", false );
	self  globallogic_score::initPersStat( "bouncingbetty_pickedup", false );
	
	self  globallogic_score::initPersStat( "bouncingbetty_devil_planted", false );
	self  globallogic_score::initPersStat( "bouncingbetty_devil_pickedup", false );

	self  globallogic_score::initPersStat( "bouncingbetty_holly_planted", false );
	self  globallogic_score::initPersStat( "bouncingbetty_holly_pickedup", false );

	self  globallogic_score::initPersStat( "ballistic_knives_pickedup", false );
	
	self  globallogic_score::initPersStat( "wallbuy_weapons_purchased", false );
	self  globallogic_score::initPersStat( "ammo_purchased", false );
	self  globallogic_score::initPersStat( "upgraded_ammo_purchased", false );
	
	self  globallogic_score::initPersStat( "power_turnedon", false );	
	self  globallogic_score::initPersStat( "power_turnedoff", false );
	self  globallogic_score::initPersStat( "planted_buildables_pickedup", false );	
	self  globallogic_score::initPersStat( "buildables_built", false );
	self  globallogic_score::initPersStat( "time_played_total", false );
	self  globallogic_score::initPersStat( "weighted_rounds_played", false ); 
	
	
	self  globallogic_score::initpersstat( "zdogs_killed", false );
	self  globallogic_score::initpersstat( "zspiders_killed", false );
	self  globallogic_score::initpersstat( "zthrashers_killed", false );
	self  globallogic_score::initpersstat( "zraps_killed", false );
	self  globallogic_score::initpersstat( "zwasp_killed", false );
	self  globallogic_score::initpersstat( "zsentinel_killed", false );
	self  globallogic_score::initpersstat( "zraz_killed", false );
	
	self  globallogic_score::initpersstat( "zdog_rounds_finished", false );
	self  globallogic_score::initpersstat( "zdog_rounds_lost", false );
	self  globallogic_score::initpersstat( "killed_by_zdog", false );
	
	//cheats
	self  globallogic_score::initPersStat( "cheat_too_many_weapons", false );	
	self  globallogic_score::initPersStat( "cheat_out_of_playable", false );	
	self  globallogic_score::initPersStat( "cheat_too_friendly",false);
	self  globallogic_score::initPersStat( "cheat_total",false);

	//DLC1 - castle
	self  globallogic_score::initPersStat( "castle_tram_token_pickedup",false);
	

	// Persistent system "player" globals
	//self zm_pers_upgrades::pers_abilities_init_globals();
	
	// some extra ... 
	self  globallogic_score::initPersStat( "total_points", false );
	self  globallogic_score::initPersStat( "rounds", false );
	if ( level.resetPlayerScoreEveryRound )
	{
		self.pers["score"] = 0;
	}
	
	self.pers["score"] = level.player_starting_points;
	self.score = self.pers["score"];
	self IncrementPlayerStat( "score", self.score );
	self add_map_stat( "score", self.score );

	self globallogic_score::initPersStat( "zteam", false );

	if ( IsDefined( level.level_specific_stats_init ) )
	{
		[[ level.level_specific_stats_init ]]();
	}

	if( !isDefined( self.stats_this_frame ) )
	{
		self.pers_upgrade_force_test = true;
		self.stats_this_frame = [];				// used to track if stats is update in current frame
		self.pers_upgrades_awarded = [];
	}
	
	//update daily challenge stats
	self globallogic_score::initPersStat( "ZM_DAILY_CHALLENGE_INGAME_TIME", true, true );
	self add_global_stat( "ZM_DAILY_CHALLENGE_GAMES_PLAYED", 1 );
}

function update_players_stats_at_match_end( players )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	// update the player stats at the end of match
	game_mode = GetDvarString( "ui_gametype" );
	game_mode_group = level.scr_zm_ui_gametype_group;
	map_location_name = level.scr_zm_map_start_location;

	// will be updated based on info from gametypesTable.csv 
	if ( map_location_name == "" )
		map_location_name = "default";
	if( IsDefined( level.gameModuleWinningTeam ) )
	{
		if( level.gameModuleWinningTeam == "B" )
		{
			MatchRecorderIncrementHeaderStat( "winningTeam", 1 );
		}
		else if ( level.gameModuleWinningTeam == "A" )
		{
			MatchRecorderIncrementHeaderStat( "winningTeam", 2 );
		}
	}
	RecordMatchSummaryZombieEndGameData( game_mode, game_mode_group, map_location_name, level.round_number );
	newTime = gettime();
	for ( i = 0; i < players.size; i++ ) 
	{	
		player = players[i];
		
		if ( player util::is_bot() )
			continue;

		distance = player get_stat_distance_traveled();
		
		player AddPlayerStat( "distance_traveled", distance );
		
		// Add the "time_played_total" to startlocation stats and map stats
		player IncrementPlayerStat(  "time_played_total", player.pers["time_played_total"] );
		player add_map_stat( "time_played_total", player.pers["time_played_total"] );

		RecordPlayerMatchEnd( player );
		RecordPlayerStats(player, "presentAtEnd", 1 );
		player zm_weapons::updateWeaponTimingsZM( newTime );

		if(isdefined(level._game_module_stat_update_func))
		{
			player [[level._game_module_stat_update_func]]();
		}

		//high score
		old_high_score = player get_global_stat("score");
		if(player.score_total > old_high_score)
		{
			player set_global_stat("score",player.score_total);
		}

		player set_global_stat("total_points", player.score_total);
		player set_global_stat("rounds", level.round_number);
		
		if ( level.onlineGame )
		{
			player highwater_global_stat( "HIGHEST_ROUND_REACHED", level.round_number );
			player highwater_map_stat( "HIGHEST_ROUND_REACHED", level.round_number );

			player add_global_stat( "TOTAL_ROUNDS_SURVIVED", level.round_number - 1 );
			player add_map_stat( "TOTAL_ROUNDS_SURVIVED", level.round_number - 1 );

			player add_global_stat( "TOTAL_GAMES_PLAYED", 1 );
			player add_map_stat( "TOTAL_GAMES_PLAYED", 1 );
		}

		if ( GameModeIsMode( GAMEMODE_PUBLIC_MATCH ) )
		{
			player GameHistoryFinishMatch( MATCH_FINISHED, 0, 0, 0, 0, 0 );
				
			if ( IsDefined( player.pers["matchesPlayedStatsTracked"] ) )
			{
				gameMode = util::GetCurrentGameMode();
				player globallogic::IncrementMatchCompletionStat( gameMode, "played", "completed" );
					
				if ( IsDefined( player.pers["matchesHostedStatsTracked"] ) )
				{
					player globallogic::IncrementMatchCompletionStat( gameMode, "hosted", "completed" );
					player.pers["matchesHostedStatsTracked"] = undefined;
				}
				
				player.pers["matchesPlayedStatsTracked"] = undefined;
			}
		}

		if ( !IsDefined( player.pers["previous_distance_traveled"] ) )
		{
			player.pers["previous_distance_traveled"] = 0;
		}
		distanceThisRound = int( player.pers["distance_traveled"] - player.pers["previous_distance_traveled"] );
		player.pers["previous_distance_traveled"] = player.pers["distance_traveled"];
		player IncrementPlayerStat("distance_traveled", distanceThisRound );
	}
}

function update_playing_utc_time( matchEndUTCTime )
{
}

function survival_classic_custom_stat_update()
{
	// self set_global_stat( "combined_rank", self get_stat_combined_rank_value_survival_classic() );
}

function grief_custom_stat_update()
{
	// self set_global_stat( "combined_rank", self get_stat_combined_rank_value_grief() );
}

//**************************************************************
//**************************************************************
// DDL stats operation functions

function get_global_stat( stat_name )
{
	return ( self GetDStat( "PlayerStatsList", stat_name, "StatValue" ) );
}

function set_global_stat( stat_name, value )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self SetDStat( "PlayerStatsList", stat_name, "StatValue", value );
}

function add_global_stat( stat_name, value )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddDStat( "PlayerStatsList", stat_name, "StatValue", value );
}

function increment_global_stat( stat_name )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddDStat( "PlayerStatsList", stat_name, "StatValue", 1 );
}

function highwater_global_stat( stat_name, value )
{
	if ( value > get_global_stat( stat_name ) )
	{
		set_global_stat( stat_name, value );
	}
}

//**************************************************************
//**************************************************************

function add_client_stat( stat_name, stat_value,include_gametype )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	if(!isDefined(include_gametype))
	{
		include_gametype = true;
	}
	
	self globallogic_score::incPersStat( stat_name, stat_value, false, include_gametype );	
	self.stats_this_frame[stat_name] = true;
}

function increment_player_stat( stat_name )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self IncrementPlayerStat( stat_name, 1 );
}

function increment_root_stat(stat_name,stat_value)
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self  AddDStat( stat_name, stat_value );
}

function increment_client_stat( stat_name,include_gametype )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	add_client_stat( stat_name, 1,include_gametype );
}

function set_client_stat( stat_name, stat_value, include_gametype )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	current_stat_count = self  globallogic_score::getPersStat( stat_name );
	self globallogic_score::incPersStat( stat_name, stat_value - current_stat_count, false, include_gametype );	
	self.stats_this_frame[stat_name] = true;
}

function zero_client_stat( stat_name, include_gametype )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	current_stat_count = self  globallogic_score::getPersStat( stat_name );
	self globallogic_score::incPersStat( stat_name, -current_stat_count, false, include_gametype );	
	self.stats_this_frame[stat_name] = true;
}

//-------------------------------------------
function get_map_stat( stat_name )
{
	return ( self GetDStat( "PlayerStatsByMap", level.script, "stats", stat_name, "StatValue" ) );
}

function set_map_stat( stat_name, value )
{
	if ( !level.onlineGame || IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self SetDStat( "PlayerStatsByMap", level.script, "stats", stat_name, "StatValue", value );
}

function add_map_stat( stat_name, value )
{
	if ( !level.onlineGame || IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddDStat( "PlayerStatsByMap", level.script, "stats", stat_name, "StatValue", value );
}

function increment_map_stat( stat_name )
{
	if ( !level.onlineGame || IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddDStat( "PlayerStatsByMap", level.script, "stats", stat_name, "StatValue", 1 );
}

function highwater_map_stat( stat_name, value )
{
	if ( value > get_map_stat( stat_name ) )
	{
		set_map_stat( stat_name, value );
	}
}

function increment_map_cheat_stat( stat_name )
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddDStat( "PlayerStatsByMap", level.script, "cheats", stat_name, 1 );
}
//-------------------------------------------

function increment_challenge_stat( stat_name, amount = 1 )
{
	if ( !level.onlineGame || IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	self AddPlayerStat( stat_name, amount );
}


//**************************************************************
//**************************************************************

function get_stat_distance_traveled()
{
	miles = int( self.pers["distance_traveled"] / 63360 );
	
	remainder = (self.pers["distance_traveled"] / 63360) - miles;
	
	if(miles < 1 && ( remainder < 0.5 ) ) 
	{
		miles = 1;
	}	
	else if(remainder >= 0.5)
	{
		miles++;
	}
		
	return miles; //int( self.pers["distance_traveled"] / 63360 ); // upload distance in miles since current distance was to capture in inches, 
}

function get_stat_round_number()
{
	return ( zm::get_round_number() );
}

function get_stat_combined_rank_value_survival_classic()
{
	rounds = get_stat_round_number();
	kills = self.pers["kills"];

	if( rounds > 99 ) 
		rounds = 99;

	result = rounds*10000000 + kills;
	return result;
}

//**************************************************************
//**************************************************************
function update_global_counters_on_match_end()
{
	if ( IS_TRUE( level.zm_disable_recording_stats ) )
	{
		return;
	}

	deaths = 0;
	kills = 0;
	melee_kills = 0;
	headshots = 0;
	suicides = 0;
	downs = 0;
	revives = 0;
	perks_drank = 0;
	doors_purchased = 0;
	distance_traveled = 0;
	total_shots = 0;
	boards = 0;
	sacrifices = 0;
	drops = 0;
	nuke_pickedup = 0;
	insta_kill_pickedup = 0;
	full_ammo_pickedup = 0;
	double_points_pickedup = 0;
	meat_stink_pickedup = 0;
	carpenter_pickedup = 0;
	fire_sale_pickedup = 0;
	minigun_pickedup = 0;
	island_seed_pickedup = 0;
	bonus_points_team_pickedup = 0;
	ww_grenade_pickedup = 0;
	zombie_blood_pickedup = 0;
	use_magicbox = 0;
	grabbed_from_magicbox = 0;
	use_perk_random = 0;
	grabbed_from_perk_random = 0;
	use_pap = 0;
	pap_weapon_grabbed = 0;
	
	specialty_armorvest_drank = 0;
	specialty_quickrevive_drank = 0;
	specialty_fastreload_drank = 0;
	specialty_additionalprimaryweapon_drank = 0;	
	specialty_staminup_drank = 0;
	specialty_doubletap2_drank = 0;
	specialty_widowswine_drank = 0;
	specialty_deadshot_drank = 0;
	
	claymores_planted = 0;
	claymores_pickedup = 0;
	bouncingbetty_planted = 0;
	ballistic_knives_pickedup = 0;
	wallbuy_weapons_purchased = 0;
	power_turnedon = 0;
	power_turnedoff = 0;
	planted_buildables_pickedup = 0;
	ammo_purchased = 0;
	upgraded_ammo_purchased = 0;
	buildables_built = 0;
	time_played = 0;	
	cheat_too_many_weapons = 0;
	cheat_out_of_playable_area = 0;
	cheat_too_friendly = 0;
	cheat_total = 0;	
	
	players = GetPlayers();
	foreach(player in players)
	{
		deaths 										+= player.pers["deaths"];
		kills 										+= player.pers["kills"];		
		headshots 									+= player.pers["headshots"];
		suicides 									+= player.pers["suicides"];		
		melee_kills 								+= player.pers["melee_kills"];
		downs 										+= player.pers["downs"];
		revives										+= player.pers["revives"];
		perks_drank									+= player.pers["perks_drank"];		
		
		specialty_armorvest_drank					+= player.pers["specialty_armorvest_drank"];
		specialty_quickrevive_drank					+= player.pers["specialty_quickrevive_drank"];
		specialty_fastreload_drank					+= player.pers["specialty_fastreload_drank"];
		specialty_additionalprimaryweapon_drank		+= player.pers["specialty_additionalprimaryweapon_drank"];	
		specialty_staminup_drank					+= player.pers["specialty_staminup_drank"];
		specialty_doubletap2_drank					+= player.pers["specialty_doubletap2_drank"];
		specialty_widowswine_drank					+= player.pers["specialty_widowswine_drank"];
		specialty_deadshot_drank					+= player.pers["specialty_deadshot_drank"];
			
		doors_purchased								+= player.pers["doors_purchased"];
		distance_traveled							+= player get_stat_distance_traveled();
		boards										+= player.pers["boards"];
		sacrifices									+= player.pers["sacrifices"];
		drops										+= player.pers["drops"];
		nuke_pickedup 								+= player.pers["nuke_pickedup"];
		insta_kill_pickedup							+= player.pers["insta_kill_pickedup"];
		full_ammo_pickedup 							+= player.pers["full_ammo_pickedup"];
		double_points_pickedup 						+= player.pers["double_points_pickedup"];
		meat_stink_pickedup 						+= player.pers["meat_stink_pickedup"];
		carpenter_pickedup							+= player.pers["carpenter_pickedup"];
		fire_sale_pickedup							+= player.pers["fire_sale_pickedup"];
		minigun_pickedup							+= player.pers["minigun_pickedup"];
		island_seed_pickedup						+= player.pers["island_seed_pickedup"];
		bonus_points_team_pickedup					+= player.pers["bonus_points_team_pickedup"];
		ww_grenade_pickedup							+= player.pers["ww_grenade_pickedup"];
		use_magicbox								+= player.pers["use_magicbox"];
		grabbed_from_magicbox						+= player.pers["grabbed_from_magicbox"];
		use_perk_random								+= player.pers["use_perk_random"];
		grabbed_from_perk_random					+= player.pers["grabbed_from_perk_random"];
		use_pap										+= player.pers["use_pap"];
		pap_weapon_grabbed							+= player.pers["pap_weapon_grabbed"];
		claymores_planted							+= player.pers["claymores_planted"];
		claymores_pickedup							+= player.pers["claymores_pickedup"];
		bouncingbetty_planted						+= player.pers["bouncingbetty_planted"];
		ballistic_knives_pickedup					+= player.pers["ballistic_knives_pickedup"];
		wallbuy_weapons_purchased					+= player.pers["wallbuy_weapons_purchased"];
		power_turnedon								+= player.pers["power_turnedon"];
		power_turnedoff								+= player.pers["power_turnedoff"];
		planted_buildables_pickedup					+= player.pers["planted_buildables_pickedup"];
		buildables_built 							+= player.pers["buildables_built"];
		ammo_purchased								+= player.pers["ammo_purchased"];
		upgraded_ammo_purchased						+= player.pers["upgraded_ammo_purchased"];
		total_shots									+= player.total_shots;		
		time_played									+= player.pers["time_played_total"];	
		cheat_too_many_weapons 						+= player.pers["cheat_too_many_weapons"];
		cheat_out_of_playable_area 					+= player.pers["cheat_out_of_playable"];
		cheat_too_friendly 							+= player.pers["cheat_too_friendly"];
		cheat_total 								+= player.pers["cheat_total"];	
	}
	game_mode =  GetDvarString( "ui_gametype" );
	incrementCounter( "global_zm_" + game_mode ,1);	
	incrementCounter( "global_zm_games", 1 );

	if ( "zclassic" == game_mode || "zm_nuked" == level.script )
	{
		incrementCounter( "global_zm_games_" + level.script, 1 );
	}

	incrementCounter( "global_zm_killed", level.global_zombies_killed );
	incrementCounter( "global_zm_killed_by_players",kills );	
	incrementCounter( "global_zm_killed_by_traps",level.zombie_trap_killed_count);	

	incrementCounter( "global_zm_headshots", headshots );
	incrementCounter( "global_zm_suicides", suicides );
	incrementCounter( "global_zm_melee_kills", melee_kills );
	incrementCounter( "global_zm_downs", downs );
	incrementCounter( "global_zm_deaths", deaths );
	incrementCounter( "global_zm_revives", revives );	
	incrementCounter( "global_zm_perks_drank", perks_drank );
	
	incrementCounter( "global_zm_specialty_armorvest_drank", specialty_armorvest_drank );
	incrementCounter( "global_zm_specialty_quickrevive_drank", specialty_quickrevive_drank );
	incrementCounter( "global_zm_specialty_fastreload_drank", specialty_fastreload_drank );
	incrementCounter( "global_zm_specialty_additionalprimaryweapon_drank", specialty_additionalprimaryweapon_drank );
	incrementCounter( "global_zm_specialty_staminup_drank", specialty_staminup_drank );	
	incrementCounter( "global_zm_specialty_doubletap2_drank", specialty_doubletap2_drank );
	incrementCounter( "global_zm_specialty_widowswine_drank", specialty_widowswine_drank );
	incrementCounter( "global_zm_specialty_deadshot_drank", specialty_deadshot_drank );
		
	incrementCounter( "global_zm_distance_traveled", int(distance_traveled) );
	incrementCounter( "global_zm_doors_purchased", doors_purchased);	
	incrementCounter( "global_zm_boards", boards);
	incrementCounter( "global_zm_sacrifices", sacrifices);;
	incrementCounter( "global_zm_drops", drops);
	incrementCounter( "global_zm_total_nuke_pickedup",nuke_pickedup);
	incrementCounter( "global_zm_total_insta_kill_pickedup",insta_kill_pickedup);
	incrementCounter( "global_zm_total_full_ammo_pickedup",full_ammo_pickedup);
	incrementCounter( "global_zm_total_double_points_pickedup",double_points_pickedup);
	incrementCounter( "global_zm_total_meat_stink_pickedup",double_points_pickedup);
	incrementCounter( "global_zm_total_carpenter_pickedup",carpenter_pickedup);
	incrementCounter( "global_zm_total_fire_sale_pickedup",fire_sale_pickedup);
	incrementCounter( "global_zm_total_minigun_pickedup",minigun_pickedup);
	incrementCounter( "global_zm_total_island_seed_pickedup",island_seed_pickedup);
	incrementCounter( "global_zm_total_zombie_blood_pickedup",zombie_blood_pickedup);
	incrementCounter( "global_zm_use_magicbox", use_magicbox);
	incrementCounter( "global_zm_grabbed_from_magicbox", grabbed_from_magicbox);
	incrementCounter( "global_zm_use_perk_random", use_perk_random);
	incrementCounter( "global_zm_grabbed_from_perk_random", grabbed_from_perk_random);
	incrementCounter( "global_zm_use_pap", use_pap);
	incrementCounter( "global_zm_pap_weapon_grabbed", pap_weapon_grabbed);
	incrementCounter( "global_zm_claymores_planted", claymores_planted);
	incrementCounter( "global_zm_claymores_pickedup", claymores_pickedup);
	incrementCounter( "global_zm_ballistic_knives_pickedup", ballistic_knives_pickedup);
	incrementCounter( "global_zm_wallbuy_weapons_purchased", wallbuy_weapons_purchased);
	incrementCounter( "global_zm_power_turnedon", power_turnedon);
	incrementCounter( "global_zm_power_turnedoff", power_turnedoff);
	incrementCounter( "global_zm_planted_buildables_pickedup", planted_buildables_pickedup);
	incrementCounter( "global_zm_buildables_built", buildables_built);
	incrementCounter( "global_zm_ammo_purchased", ammo_purchased);
	incrementCounter( "global_zm_upgraded_ammo_purchased", upgraded_ammo_purchased);	
	incrementCounter( "global_zm_total_shots", total_shots);	
	incrementCounter( "global_zm_time_played", time_played);	
	incrementCounter( "global_zm_cheat_players_too_friendly",cheat_too_friendly);
	incrementCounter( "global_zm_cheats_cheat_too_many_weapons",cheat_too_many_weapons);
	incrementCounter( "global_zm_cheats_out_of_playable",cheat_out_of_playable_area);
	incrementCounter( "global_zm_total_cheats",cheat_total);
}

function get_specific_stat( stat_category,stat_name )
{
	return ( self GetDStat( stat_category, stat_name, "StatValue" ) );
}

function initializeMatchStats()
{
	if ( !level.onlineGame || !GameModeIsMode( GAMEMODE_PUBLIC_MATCH ) )
		return;

	self.pers["lastHighestScore"] =  self getDStat( "HighestStats", "highest_score" );

	currGameType = level.gametype;
	self GameHistoryStartMatch( getGameTypeEnumFromName( currGameType, false ) );
}

function adjustRecentStats()
{
	initializeMatchStats();
}

function uploadStatsSoon()
{
	self notify( "upload_stats_soon" );
	self endon( "upload_stats_soon" );
	self endon( "disconnect" );

	wait 1;
	UploadStats( self );
}

