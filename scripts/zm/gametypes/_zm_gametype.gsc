#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\hud_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\music_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\gametypes\_globallogic;
#using scripts\zm\gametypes\_globallogic_defaults;
#using scripts\zm\gametypes\_globallogic_score;
#using scripts\zm\gametypes\_globallogic_spawn;
#using scripts\zm\gametypes\_globallogic_ui;
#using scripts\zm\gametypes\_globallogic_utils;
#using scripts\zm\gametypes\_hud_message;
#using scripts\zm\gametypes\_spawning;
#using scripts\zm\gametypes\_weapons;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_game_module;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

#precache( "menu", MENU_TEAM );
#precache( "menu", MENU_CLASS );
#precache( "menu", MENU_CHANGE_CLASS );
#precache( "menu", MENU_CONTROLS );
#precache( "menu", MENU_OPTIONS );
#precache( "menu", MENU_LEAVEGAME );
#precache( "menu", MENU_SPECTATE );
#precache( "menu", MENU_RESTART_GAME );
#precache( "menu", MENU_SCOREBOARD );
#precache( "menu", MENU_INIT_TEAM_ALLIES );
#precache( "menu", MENU_INIT_TEAM_AXIS );
#precache( "menu", MENU_WAGER_SIDE_BET );
#precache( "menu", MENU_WAGER_SIDE_BET_PLAYER );
#precache( "menu", MENU_CHANGE_CLASS_WAGER );
#precache( "menu", MENU_CHANGE_CLASS_CUSTOM );
#precache( "menu", MENU_CHANGE_CLASS_BAREBONES );
#precache( "string", "MP_HOST_ENDED_GAME" );
#precache( "string", "MP_HOST_ENDGAME_RESPONSE" );

#namespace zm_gametype;

//
// This function *only* sets default values - all gamemode specifics should be over-ridden in script in the gametype script - after the call to this function.
//

function main( )
{
	globallogic::init();

	GlobalLogic_SetupDefault_ZombieCallbacks();
	
	menu_init();
	
	//util::registerRoundLimit( minValue, maxValue )
	util::registerRoundLimit( 1, 1 );
	
	//util::registerTimeLimit( minValue, maxValue )
	util::registerTimeLimit( 0, 0 );
	
	//util::registerScoreLimit( minValue, maxValue )
	util::registerScoreLimit( 0, 0 );
	
	//util::registerRoundWinLimit( minValue, maxValue )
	util::registerRoundWinLimit( 0, 0 );
	
	//util::registerNumLives( minValue, maxValue )
	util::registerNumLives( 1, 1 );


	weapons::registerGrenadeLauncherDudDvar( level.gameType, 10, 0, 1440 );
	weapons::registerThrownGrenadeDudDvar( level.gameType, 0, 0, 1440 );
	weapons::registerKillstreakDelay( level.gameType, 0, 0, 1440 );

	globallogic::registerFriendlyFireDelay( level.gameType, 15, 0, 1440 );


	level.takeLivesOnDeath = true;
	level.teamBased = true;
	level.disablePrematchMessages = true;	//NEW
	level.disableMomentum = true;			//NEW
	
	level.overrideTeamScore = false;
	level.overridePlayerScore = false;
	level.displayHalftimeText = false;
	level.displayRoundEndText = false;
	
	level.allowAnnouncer = false;
	//level.allowZmbAnnouncer = true;
	
	level.endGameOnScoreLimit = false;
	level.endGameOnTimeLimit = false;
	level.resetPlayerScoreEveryRound = true;
	
	level.doPrematch = false;
	level.noPersistence = true;
	level.cumulativeRoundScores = true;
	
	level.forceAutoAssign = true;
	level.dontShowEndReason = true;
	level.forceAllAllies = true;			//NEW
	
	//DISABLE TEAM SWAP
	level.allow_teamchange = false;
	SetDvar( "scr_disable_team_selection", 1 );
	//makeDvarServerInfo( "scr_disable_team_selection", 1 );
	
	SetDvar( "scr_disable_weapondrop", 1 );
	
	level.onStartGameType = &onStartGameType;
//	level.onSpawnPlayer = &onSpawnPlayer;
	level.onSpawnPlayer = &globallogic::blank;
	level.onSpawnPlayerUnified = &onSpawnPlayerUnified;
	level.onRoundEndGame = &onRoundEndGame;
	//level.giveCustomLoadout = &giveCustomLoadout;
	level.playerMaySpawn = &maySpawn;

	zm_utility::set_game_var("ZM_roundLimit", 1);
	zm_utility::set_game_var("ZM_scoreLimit", 1);

	zm_utility::set_game_var("_team1_num", 0);
	zm_utility::set_game_var("_team2_num", 0);
	
	map_name = level.script;

	//level.gamemode_match = spawnstruct();	

	mode = GetDvarString( "ui_gametype" );
	
	if((!isdefined(mode) || mode == "") && isdefined(level.default_game_mode))
	{
		mode = level.default_game_mode;
	}
	
	zm_utility::set_gamemode_var_once("mode", mode);
	
	zm_utility::set_game_var_once("side_selection", 1);
	
	location = level.default_start_location;
	zm_utility::set_gamemode_var_once("location", location);
	

	//* level.gamemode_match.num_rounds = GetDvarInt("zm_num_rounds");
	//level.gamemode_match.rounds = [];
	zm_utility::set_gamemode_var_once("randomize_mode", GetDvarInt("zm_rand_mode"));
	zm_utility::set_gamemode_var_once("randomize_location", GetDvarInt("zm_rand_loc"));
	zm_utility::set_gamemode_var_once("team_1_score", 0);
	zm_utility::set_gamemode_var_once("team_2_score", 0);
	zm_utility::set_gamemode_var_once("current_round", 0);
	zm_utility::set_gamemode_var_once("rules_read", false);
	zm_utility::set_game_var_once("switchedsides", false);
	
	gametype = GetDvarString("ui_gametype");
	
	game["dialog"]["gametype"] = gametype + "_start";
	game["dialog"]["gametype_hardcore"] = gametype + "_start";
	game["dialog"]["offense_obj"] = "generic_boost";
	game["dialog"]["defense_obj"] = "generic_boost";
	
	zm_utility::set_gamemode_var("pre_init_zombie_spawn_func", undefined);
	zm_utility::set_gamemode_var("post_init_zombie_spawn_func", undefined);
	zm_utility::set_gamemode_var("match_end_notify", undefined);
	zm_utility::set_gamemode_var("match_end_func", undefined);
	
	// Sets the scoreboard columns and determines with data is sent across the network
	setscoreboardcolumns( "score", "kills", "downs", "revives", "headshots" ); 
	callback::on_connect( &onPlayerConnect_check_for_hotjoin);
	// level thread module_hud_connecting();
}

function GlobalLogic_SetupDefault_ZombieCallbacks()
{
	level.spawnPlayer = &globallogic_spawn::spawnPlayer;
	level.spawnPlayerPrediction = &globallogic_spawn::spawnPlayerPrediction;
	level.spawnClient = &globallogic_spawn::spawnClient;
	level.spawnSpectator = &globallogic_spawn::spawnSpectator;
	level.spawnIntermission = &globallogic_spawn::spawnIntermission;
	level.scoreOnGivePlayerScore = &globallogic_score::givePlayerScore;
	level.onPlayerScore = &globallogic::blank;
	level.onTeamScore = &globallogic::blank;
	
	level.waveSpawnTimer = &globallogic::waveSpawnTimer;
	
	level.onSpawnPlayer = &globallogic::blank;
	level.onSpawnPlayerUnified = &globallogic::blank;
	level.onSpawnSpectator = &onSpawnSpectator;
	level.onSpawnIntermission = &onSpawnIntermission;
	level.onRespawnDelay = &globallogic::blank;

	level.onForfeit = &globallogic::blank;
	level.onTimeLimit = &globallogic::blank;
	level.onScoreLimit = &globallogic::blank;
	level.onDeadEvent = &onDeadEvent;
	level.onOneLeftEvent = &globallogic::blank;
	level.giveTeamScore = &globallogic::blank;

	level.getTimePassed = &globallogic_utils::getTimePassed;
	level.getTimeLimit = &globallogic_defaults::default_getTimeLimit;
	level.getTeamKillPenalty = &globallogic::blank;
	level.getTeamKillScore = &globallogic::blank;

	level.isKillBoosting = &globallogic::blank;

	level._setTeamScore = &globallogic_score::_setTeamScore;
	level._setPlayerScore = &globallogic::blank;

	level._getTeamScore = &globallogic::blank;
	level._getPlayerScore = &globallogic::blank;
	
	level.onPrecacheGameType = &globallogic::blank;
	level.onStartGameType = &globallogic::blank;
	level.onPlayerConnect = &globallogic::blank;
	level.onPlayerDisconnect = &onPlayerDisconnect;
	level.onPlayerDamage = &globallogic::blank;
	level.onPlayerKilled = &globallogic::blank;
	level.onPlayerKilledExtraUnthreadedCBs = []; ///< Array of other CB function pointers

	level.onTeamOutcomeNotify = &hud_message::teamOutcomeNotifyZombie;
	level.onOutcomeNotify = &globallogic::blank;
	level.onTeamWagerOutcomeNotify = &globallogic::blank;
	level.onWagerOutcomeNotify = &globallogic::blank;
	level.onEndGame = &onEndGame;
	level.onRoundEndGame = &globallogic::blank;
	level.onMedalAwarded = &globallogic::blank;
	level.dogManagerOnGetDogs = &globallogic::blank;


	level.autoassign = &globallogic_ui::menuAutoAssign;
	level.spectator = &globallogic_ui::menuSpectator;
	level.curClass = &globallogic_ui::menuClass;
	level.allies = &menuAlliesZombies;
	level.teamMenu = &globallogic_ui::menuTeam;

	level.callbackActorKilled = &globallogic::blank;
	level.callbackVehicleDamage = &globallogic::blank;
	level.callbackVehicleKilled = &globallogic::blank;
}

function do_game_mode_shellshock()
{
	self endon("disconnect");
	
	self._being_shellshocked = true;
	self shellshock("grief_stab_zm",.75);
	wait(.75);
	self._being_shellshocked = false;		
}

function canPlayerSuicide()
{
	//Tombstone is currently used as Stampinup Light and will not be coming back,
	//just return false now
	return false;
}

function onPlayerDisconnect()
{
	if(isDefined(level.game_mode_custom_onPlayerDisconnect))
	{
		level [[level.game_mode_custom_onPlayerDisconnect]](self);
	}	
	if( isdefined( level.check_quickrevive_hotjoin ) )
	{
		level thread [[ level.check_quickrevive_hotjoin ]]();
	}	
	level zm::checkForAllDead(self);
}

function onDeadEvent( team )
{
	thread globallogic::endGame( level.zombie_team, "" );
}

function onSpawnIntermission()
{
	spawnpointname = "info_intermission"; 
	spawnpoints = getentarray( spawnpointname, "classname" ); 
	
	// CODER_MOD: TommyK (8/5/08)
	if(spawnpoints.size < 1)
	{

		return;
	}	
	
	spawnpoint = spawnpoints[RandomInt(spawnpoints.size)];	
	if( isDefined( spawnpoint ) )
	{
		self spawn( spawnpoint.origin, spawnpoint.angles ); 
	}
}

function onSpawnSpectator( origin, angles )
{
}


  	
function maySpawn()
{
	if ( IsDefined(level.customMaySpawnLogic) )
		return self [[ level.customMaySpawnLogic ]]();

	if ( self.pers["lives"] == 0 )
	{
		level notify( "player_eliminated" );
		self notify( "player_eliminated" );
		return false;
	}
	return true;
}

function onStartGameType()
{
	setClientNameMode("auto_change");

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	structs = struct::get_array("player_respawn_point", "targetname");
	foreach(struct in structs)
	{
		level.spawnMins = math::expand_mins( level.spawnMins, struct.origin );
		level.spawnMaxs = math::expand_maxs( level.spawnMaxs, struct.origin );
	}

	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs ); 
	setMapCenter( level.mapCenter );

	
	
// 	globallogic_ui::setObjectiveText( "allies", &"OBJECTIVES_ZSURVIVAL" );
// 	globallogic_ui::setObjectiveText( "axis", &"OBJECTIVES_ZSURVIVAL" );
// 	
// 	if ( level.splitscreen )
// 	{
// 		globallogic_ui::setObjectiveScoreText( "allies", &"OBJECTIVES_ZSURVIVAL" );
// 		globallogic_ui::setObjectiveScoreText( "axis", &"OBJECTIVES_ZSURVIVAL" );
// 	}
// 	else
// 	{
// 		globallogic_ui::setObjectiveScoreText( "allies", &"OBJECTIVES_ZSURVIVAL_SCORE" );
// 		globallogic_ui::setObjectiveScoreText( "axis", &"OBJECTIVES_ZSURVIVAL_SCORE" );
// 	}
// 	globallogic_ui::setObjectiveHintText( "allies", &"OBJECTIVES_ZSURVIVAL_HINT" );
// 	globallogic_ui::setObjectiveHintText( "axis", &"OBJECTIVES_ZSURVIVAL_HINT" );
	
//	level.spawnMins = ( 0, 0, 0 );
//	level.spawnMaxs = ( 0, 0, 0 );
// 	spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
// 	spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
// 	spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
// 	spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
// 	spawning::updateAllSpawnPoints();
// 
// 	level.spawn_axis_start= spawnlogic::getSpawnpointArray("mp_tdm_spawn_axis_start");
// 	level.spawn_allies_start= spawnlogic::getSpawnpointArray("mp_tdm_spawn_allies_start");
//	
//	level.mapCenter = spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
//	setMapCenter( level.mapCenter );
//
//	spawnpoint = spawnlogic::getRandomIntermissionPoint();
//	setDemoIntermissionPoint( spawnpoint.origin, spawnpoint.angles );
	
	//allowed[0] = "zsurvival";
	
	level.displayRoundEndText = false;
	//gameobjects::main(allowed);
	
	// now that the game objects have been deleted place the influencers
	spawning::create_map_placed_influencers();
	
	if ( !util::isOneRound() )
	{
		level.displayRoundEndText = true;
		if( level.scoreRoundWinBased )
		{
			globallogic_score::resetTeamScores();
		}
	}
}

function onSpawnPlayerUnified()
{
	onSpawnPlayer(false);
}


// coop_player_spawn_placement()
// {
// 	structs = struct::get_array( "initial_spawn_points", "targetname" ); 
// 
// 	temp_ent = Spawn( "script_model", (0,0,0) );
// 	for( i = 0; i < structs.size; i++ )
// 	{
// 		temp_ent.origin = structs[i].origin;
// 		temp_ent placeSpawnpoint();
// 		structs[i].origin = temp_ent.origin;
// 	}
// 	temp_ent Delete();
// 
// 	level flag::wait_till( "start_zombie_round_logic" ); 
// 
// 	//chrisp - adding support for overriding the default spawning method
// 
// 	players = GetPlayers(); 
// 
// 	for( i = 0; i < players.size; i++ )
// 	{
// 		players[i] setorigin( structs[i].origin ); 
// 		players[i] setplayerangles( structs[i].angles ); 
// 		players[i].spectator_respawn = structs[i];
// 	}
// }


function onFindValidSpawnPoint()
{

		
	if(level flag::get("begin_spawning"))
	{
		spawnPoint = zm::check_for_valid_spawn_near_team( self, true );
	}	
	
	if (!isdefined(spawnPoint))
	{ 
		match_string = "";
	
		location = level.scr_zm_map_start_location;
		if ((location == "default" || location == "" ) && IsDefined(level.default_start_location))
		{
			location = level.default_start_location;
		}		
		
		match_string = level.scr_zm_ui_gametype + "_" + location;
	
		spawnPoints = [];
		structs = struct::get_array("initial_spawn", "script_noteworthy");
		if(IsDefined(structs))
		{
			foreach(struct in structs)			
			{
				if(IsDefined(struct.script_string) )
				{
					
					tokens = strtok(struct.script_string," ");
					foreach(token in tokens)
					{
						if(token == match_string )
						{
							spawnPoints[spawnPoints.size] =	struct;
						}
					}
				}
				
			}			
		}
		
		if(!IsDefined(spawnPoints) || spawnPoints.size == 0) // old method, failed new method.
		{
			spawnPoints = struct::get_array("initial_spawn_points", "targetname");
		}	
						
		assert(IsDefined(spawnPoints), "Could not find initial spawn points!");

		spawnPoint = zm::getFreeSpawnpoint( spawnPoints, self );
	}
	
	return spawnPoint;
}




function onSpawnPlayer(predictedSpawn)
{
	if(!IsDefined(predictedSpawn))
	{
		predictedSpawn = false;
	}
	
	pixbeginevent("ZSURVIVAL:onSpawnPlayer");
	self.usingObj = undefined;
	
	self.is_zombie = false; 

	zm::updatePlayerNum( self );

	//For spectator respawn
	if( IsDefined( level.custom_spawnPlayer ) && IS_TRUE(self.player_initialized))
	{
		self [[level.custom_spawnPlayer]]();
		return;
	}


	if( isdefined(level.customSpawnLogic) )
	{

		spawnPoint = self [[level.customSpawnLogic]](predictedSpawn);
		if (predictedSpawn)
			return;
	}
	else
	{

		
		spawnPoint = self onFindValidSpawnPoint();
					
		if ( predictedSpawn )
		{
			self predictSpawnPoint( spawnPoint.origin, spawnPoint.angles );
			return;
		}
/*		else if(game["switchedsides"])	// mid match.
		{
			self setorigin(spawnPoint.origin);
			self setplayerangles (spawnPoint.angles);
			self notify( "spawned_player" ); 
			return; 
		}*/
		else
		{
			self spawn( spawnPoint.origin, spawnPoint.angles, "zsurvival" );
		}
	}

	
	//Zombies player setup
	self.entity_num = self GetEntityNumber(); 
	self thread zm::onPlayerSpawned(); 
	self thread zm::player_revive_monitor();
	self freezecontrols( true );
	self.spectator_respawn = spawnPoint;

	self.score = self  globallogic_score::getPersStat( "score" ); 
	//self.pers["lives"] = 1;

	self.pers["participation"] = 0;
	
	self.score_total = self.score; 
	self.old_score = self.score; 

	self.player_initialized = false;
	self.zombification_time = 0;
	self.enableText = true;

	// DCS 090910: now that player can destroy some barricades before set.
	self thread zm_blockers::rebuild_barrier_reward_reset();
	
	if(!IS_TRUE(level.host_ended_game))
	{
		self util::freeze_player_controls( false );
		self enableWeapons();
	}
	if(isDefined(level.game_mode_spawn_player_logic))
	{
		spawn_in_spectate = [[level.game_mode_spawn_player_logic]]();
		if(spawn_in_spectate)
		{	
			self util::delay(.05, undefined, &zm::spawnSpectator);
		}
	}
	
	pixendevent();
}
//---------------------------------------------------------------------------------------------------
// check if ent or struct valid for gametype use.
// DCS 051512
//---------------------------------------------------------------------------------------------------
function get_player_spawns_for_gametype()
{
	match_string = "";

	location = level.scr_zm_map_start_location;
	if ((location == "default" || location == "" ) && IsDefined(level.default_start_location))
	{
		location = level.default_start_location;
	}		

	match_string = level.scr_zm_ui_gametype + "_" + location;

	player_spawns = [];
	structs = struct::get_array("player_respawn_point", "targetname");
	foreach(struct in structs)
	{
		if(IsDefined(struct.script_string) )
		{
			tokens = strtok(struct.script_string," ");
			foreach(token in tokens)
			{
				if(token == match_string )
				{
					player_spawns[player_spawns.size] =	struct;
				}
			}
		}
		else // no gametype defining string, add to array for all locations.
		{
			player_spawns[player_spawns.size] =	struct;
		}		
	}
	return player_spawns;			
}

function onEndGame( winningTeam )
{
	//Clean up this players crap
}

function onRoundEndGame( roundWinner )
{
	if ( game["roundswon"]["allies"] == game["roundswon"]["axis"] )
		winner = "tie";
	else if ( game["roundswon"]["axis"] > game["roundswon"]["allies"] )
		winner = "axis";
	else
		winner = "allies";
	
	return winner;
}

// giveCustomLoadout( takeAllWeapons, alreadySpawned )
// {
// 	self TakeAllWeapons();
// 	self giveWeapon( level.weaponBaseMelee );
// 	self giveWeapon( GetWeapon( "frag_grenade" ) );
//	self zm_utility::give_start_weapon( true );
// }

function menu_init()
{
	game["menu_team"] = MENU_TEAM;
	game["menu_changeclass_allies"] = MENU_CHANGE_CLASS;
	game["menu_initteam_allies"] = MENU_INIT_TEAM_ALLIES;
	game["menu_changeclass_axis"] = MENU_CHANGE_CLASS;
	game["menu_initteam_axis"] = MENU_INIT_TEAM_AXIS;
	game["menu_class"] = MENU_CLASS;
	game["menu_start_menu"] = MENU_START_MENU;
	game["menu_changeclass"] = MENU_CHANGE_CLASS;
	game["menu_changeclass_offline"] = MENU_CHANGE_CLASS;
	game["menu_wager_side_bet"] = MENU_WAGER_SIDE_BET;
	game["menu_wager_side_bet_player"] = MENU_WAGER_SIDE_BET_PLAYER;
	game["menu_changeclass_wager"] = MENU_CHANGE_CLASS_WAGER;
	game["menu_changeclass_custom"] = MENU_CHANGE_CLASS_CUSTOM;
	game["menu_changeclass_barebones"] = MENU_CHANGE_CLASS_BAREBONES;

	game["menu_controls"] = MENU_CONTROLS;
	game["menu_options"] = MENU_OPTIONS;
	game["menu_leavegame"] = MENU_LEAVEGAME;
	game["menu_restartgamepopup"] = MENU_RESTART_GAME;

	level thread menu_onPlayerConnect();
}

function menu_onPlayerConnect()
{
	for(;;)
	{
		level waittill("connecting", player);		
		player thread menu_onMenuResponse();
	}
}

function menu_onMenuResponse()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("menuresponse", menu, response);
		
		//println( self getEntityNumber() + " menuresponse: " + menu + " " + response );
		
		//iprintln("^6", response);
			
		if ( response == "back" )
		{
			self closeInGameMenu();

			if ( level.console )
			{
				if( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] || menu == game["menu_team"] || menu == game["menu_controls"] )
				{
//					assert(self.pers["team"] == "allies" || self.pers["team"] == "axis");
	
					if( self.pers["team"] == "allies" )
						self openMenu( game[ "menu_start_menu" ] );
					if( self.pers["team"] == "axis" )
						self openMenu( game[ "menu_start_menu" ] );
				}
			}
			continue;
		}
		
		if(response == "changeteam" && level.allow_teamchange == "1")
		{
			self closeInGameMenu();
			self openMenu(game["menu_team"]);
		}
	
		if(response == "changeclass_marines" )
		{
			self closeInGameMenu();
			self openMenu( game["menu_changeclass_allies"] );
			continue;
		}

		if(response == "changeclass_opfor" )
		{
			self closeInGameMenu();
			self openMenu( game["menu_changeclass_axis"] );
			continue;
		}

		if(response == "changeclass_wager" )
		{
			self closeInGameMenu();
			self openMenu( game["menu_changeclass_wager"] );
			continue;
		}

		if(response == "changeclass_custom" )
		{
			self closeInGameMenu();
			self openMenu( game["menu_changeclass_custom"] );
			continue;
		}

		if(response == "changeclass_barebones" )
		{
			self closeInGameMenu();
			self openMenu( game["menu_changeclass_barebones"] );
			continue;
		}

		if(response == "changeclass_marines_splitscreen" )
			self openMenu( "changeclass_marines_splitscreen" );

		if(response == "changeclass_opfor_splitscreen" )
			self openMenu( "changeclass_opfor_splitscreen" );
							
		if(response == "endgame")
		{
			// TODO: replace with onSomethingEvent call 
			if(self IsSplitscreen() )
			{
				//if ( level.console )
				//	endparty();
				level.skipVote = true;

				if ( !IS_TRUE(level.gameended) )
				{
					self zm_stats::increment_client_stat( "deaths" );
					self zm_stats::increment_player_stat( "deaths" );
					self zm_pers_upgrades_functions::pers_upgrade_jugg_player_death_stat();

					level.host_ended_game = true;
					zm_game_module::freeze_players(true);
					level notify("end_game");
				}
			}
				
			continue;
		}
		
		if ( response == "restart_level_zm")
		{
			self zm_stats::increment_client_stat( "deaths" );
			self zm_stats::increment_player_stat( "deaths" );
			self zm_pers_upgrades_functions::pers_upgrade_jugg_player_death_stat();
			MissionFailed();
		}
		
		if(response == "killserverpc")
		{
			level thread globallogic::killserverPc();
				
			continue;
		}

		if ( response == "endround" )
		{
			if ( !IS_TRUE(level.gameEnded ))
			{
				self globallogic::gameHistoryPlayerQuit();
				
				self closeInGameMenu();

				level.host_ended_game = true;
				zm_game_module::freeze_players(true);
				level notify("end_game");
			}
			else
			{
				self closeInGameMenu();
				self iprintln( &"MP_HOST_ENDGAME_RESPONSE" );
			}			
			continue;
		}

		if(menu == game["menu_team"] && level.allow_teamchange == "1")
		{
			switch(response)
			{
			case "allies":
				//self closeInGameMenu();
				self [[level.allies]]();
				break;

			case "axis":
				//self closeInGameMenu();
				self [[level.teamMenu]](response);
				break;

			case "autoassign":
				//self closeInGameMenu();
				self [[level.autoassign]]( true );
				break;

			case "spectator":
				//self closeInGameMenu();
				self [[level.spectator]]();
				break;
			}
		}	// the only responses remain are change class events
		else if( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] || menu == game["menu_changeclass_wager"] || menu == game["menu_changeclass_custom"] || menu == game["menu_changeclass_barebones"] )
		{
			self closeInGameMenu();
			
			if(  level.rankedMatch && isSubstr(response, "custom") )
			{
				//if ( self IsItemLocked( _rank::GetItemIndex( "feature_cac" ) ) )
				//kick( self getEntityNumber() );
			}

			self.selectedClass = true;
			self [[level.curClass]](response);
		}
	}
}

function menuAlliesZombies()
{
	self globallogic_ui::closeMenus();
	
	if ( !level.console && level.allow_teamchange == "0" && (isdefined(self.hasDoneCombat) && self.hasDoneCombat) )
	{
			return;
	}
	
	if(self.pers["team"] != "allies")
	{
		// allow respawn when switching teams during grace period.
		if ( level.inGracePeriod && (!isdefined(self.hasDoneCombat) || !self.hasDoneCombat) )
			self.hasSpawned = false;
			
		if(self.sessionstate == "playing")
		{
			self.switching_teams = true;
			self.joining_team = "allies";
			self.leaving_team = self.pers["team"];
			self suicide();
		}

		self.pers["team"] = "allies";
		self.team = "allies";
		self.pers["class"] = undefined;
		self.curClass = undefined;
		self.pers["weapon"] = undefined;
		self.pers["savedmodel"] = undefined;

		self globallogic_ui::updateObjectiveText();

		self.sessionteam = "allies";

		self SetClientScriptMainMenu( game[ "menu_start_menu" ] );

		self notify("joined_team");
		level notify( "joined_team" );
		self callback::callback( #"on_joined_team" );
		self notify("end_respawn");
	}
	
	//self beginClassChoice();
}

function custom_spawn_init_func()
{
	array::thread_all(level.zombie_spawners, &spawner::add_spawn_function, &zm_spawner::zombie_spawn_init);
	array::thread_all(level.zombie_spawners, &spawner::add_spawn_function, level._zombies_round_spawn_failsafe);
}

function init()
{
	level flag::init( "pregame" );
	
	level flag::set( "pregame" );
	
	level thread onPlayerConnect();
}

function onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		player thread onPlayerSpawned();
		if(isDefined(level.game_module_onPlayerConnect))
		{
			player [[level.game_module_onPlayerConnect]]();
		}
	}
}

function onPlayerSpawned()
{
	level endon( "end_game" );	
	self endon( "disconnect" );

	for ( ;; )
	{
		self util::waittill_either( "spawned_player", "fake_spawned_player" );
		
		if ( IS_TRUE( level.match_is_ending) )
		{
			return;
		}
		
		if ( self laststand::player_is_in_laststand() )
		{
			self thread zm_laststand::auto_revive( self );
		}

		if ( IsDefined( level.custom_player_fake_death_cleanup ) )
		{
			self [[ level.custom_player_fake_death_cleanup ]]();
		}

		self SetStance( "stand" );
		self.zmbDialogQueue = [];
		self.zmbDialogActive = false;
		self.zmbDialogGroups = [];
		self.zmbDialogGroup = "";

		self TakeAllWeapons();

		if ( IsDefined( level.giveCustomCharacters ) )
		{
			self [[ level.giveCustomCharacters ]]();
			//TODO: Update the stat lookup to set the correct character index
			//self SetDStat( "characterContext", "characterIndex", self GetCharacterBodyType() );
		}

		self GiveWeapon( level.weaponBaseMelee );
		
		if(isDefined(level.onPlayerSpawned_restore_previous_weapons) && IS_TRUE(level.isresetting_grief)) //give players back their weapons if Grief is reset after a stalemate
		{
			weapons_restored = self [[level.onPlayerSpawned_restore_previous_weapons]]();
		}
		if(!IS_TRUE(weapons_restored))
		{
			self zm_utility::give_start_weapon( true );
		}
		
		weapons_restored = 0;
		
		if ( IsDefined( level._team_loadout ) )
		{
			self GiveWeapon( level._team_loadout );
			self SwitchToWeapon( level._team_loadout );
		}	
	
		if(isdefined(level.gamemode_post_spawn_logic))
		{
			self [[level.gamemode_post_spawn_logic]]();
		}
	}
}


function onPlayerConnect_check_for_hotjoin()
{
	map_logic_exists = level flag::exists( "start_zombie_round_logic" );
	map_logic_started = level flag::get( "start_zombie_round_logic" );
	
	if( map_logic_exists && map_logic_started )
	{
		self thread player_hotjoin();	
	}	
}

function player_hotjoin()
{
	self endon("disconnect");

	self initialBlack();
	
	self.rebuild_barrier_reward = 1; //to prevent losing this pers upgrade when he spawns in at the end of the round. It gets cleared for all players once the new round starts
	self.is_hotjoining = true;

	wait(.5);
	
	if ( IsDefined( level.giveCustomCharacters ) )
	{
		self [[ level.giveCustomCharacters ]]();
		//TODO: Update the stat lookup to set the correct character index
		//self SetDStat( "characterContext", "characterIndex", self GetCharacterBodyType() );
	}
	self zm::spawnSpectator();
	music::setmusicstate("none");//stops loadscreen music from looping indefinitely
	
	self.is_hotjoining = false;
	self.is_hotjoin = true;

	self thread wait_fade_in();
	
	if(IS_TRUE(level.intermission) || IS_TRUE(level.host_ended_game) )
	{
		self SetClientThirdPerson( 0 );
		self resetFov();
		
		self.health = 100; // This is needed so the player view doesn't get stuck
		self thread [[level.custom_intermission]]();	
		
	}	

}


function wait_fade_in( )
{
	self util::streamer_wait( undefined, 0, 30 );
	
	if ( isdefined( level.hotjoin_extra_blackscreen_time ) )
	{
		wait level.hotjoin_extra_blackscreen_time;  
	}
	
	initialBlackEnd(); 
}

function initialBlack()
{
	self CloseMenu( "InitialBlack" );	
	self OpenMenu( "InitialBlack" );	
}

function initialBlackEnd()
{
	self CloseMenu( "InitialBlack" );	
}
