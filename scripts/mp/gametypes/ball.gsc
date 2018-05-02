#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\math_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\rank_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\sound_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\_oob;
#using scripts\shared\killstreaks_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#using scripts\shared\abilities\_ability_player;

#using scripts\mp\_armor;
#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_defaults;
#using scripts\mp\gametypes\_globallogic_player;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_ui;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_hud_message;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\teams\_teams;

#define CONST_MAX_PASS_DISTANCE						( 1000 * 1000 )

#define BALL_MODEL									"wpn_t7_uplink_ball_world" 
#define CLIENT_FIELD_BALL_CARRIER 					CLIENT_FIELD_CTF_CARRIER
#define CONST_BALL_WEAPON 							"ball"
#define CONST_BALL_WORLD_WEAPON 					"ball_world"
#define CONST_PASSING_BALL_WEAPON	 				"ball_world_pass"
	

#define TRAIL_FX									"ui/fx_uplink_ball_trail"
#define RESET_FX									"ui/fx_uplink_ball_vanish"

#define PHYSICS_TIME_LIMIT	15
	
#define OBJECTIVE_FLAG_NORMAL 0
#define OBJECTIVE_FLAG_UPLOADING 1
#define OBJECTIVE_FLAG_DOWNLOADING 2
	

#precache( "string", "OBJECTIVES_BALL" );
#precache( "string", "OBJECTIVES_BALL_HINT" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_1" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_1" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_2_WINNER" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_2_LOSER" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_2_TIE" );
#precache( "string", "MP_BALL_OVERTIME_ROUND_2_TIE" );
#precache( "string", "MPUI_BALL_OVERTIME_FASTEST_CAP_TIME" );
#precache( "string", "MPUI_BALL_OVERTIME_DEFEAT_TIMELIMIT" );
#precache( "string", "MPUI_BALL_OVERTIME_DEFEAT_DID_NOT_DEFEND" );

#precache( "string", "MP_BALL_PICKED_UP" );
#precache( "string", "MP_BALL_DROPPED" );
#precache( "string", "MP_BALL_CAPTURE" );

#precache( "fx", TRAIL_FX );
#precache( "fx", RESET_FX );

#precache( "objective", "ball_ball" );
#precache( "objective", "ball_goal_allies" );
#precache( "objective", "ball_goal_axis" );

/*
	BALL
	
	Level requirements
	------------------
		Allied Spawnpoints:
			classname		mp_sd_spawn_attacker
			Allied players spawn from these. Place at least 16 of these relatively close together.

		Axis Spawnpoints:
			classname		mp_sd_spawn_defender
			Axis players spawn from these. Place at least 16 of these relatively close together.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.

		Goal:
		Ball:
*/

REGISTER_SYSTEM( "ball", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "allplayers", "ballcarrier" , VERSION_SHIP, 1, "int" );
	clientfield::register( "allplayers", "passoption" , VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "ball_away" , VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "ball_score_allies" , VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "ball_score_axis" , VERSION_SHIP, 1, "int" );
}

function main()
{
	globallogic::init();
	
	util::registerTimeLimit( 0, 1440 );
	util::registerRoundLimit( 0, 10 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerRoundSwitch( 0, 9 );
	util::registerNumLives( 0, 100 );
	util::registerRoundScoreLimit( 0, 5000 );
	util::registerScoreLimit( 0, 5000 );
	
	level.scoreRoundWinBased = ( GetGametypeSetting( "cumulativeRoundScores" ) == false );

	level.teamKillPenaltyMultiplier = GetGametypeSetting( "teamKillPenalty" );
	level.enemyObjectivePingTime =  GetGametypeSetting( "objectivePingTime" );
	
	if ( level.roundScoreLimit )
	{
		level.carryScore = math::clamp( GetGametypeSetting( "carryScore" ), 0, level.roundScoreLimit );	
		level.throwScore = math::clamp( GetGametypeSetting( "throwScore" ), 0, level.roundScoreLimit );
	}
	else
	{
		level.carryScore = GetGametypeSetting( "carryScore" );	
		level.throwScore = GetGametypeSetting( "throwScore" );
	}
	
	level.carryArmor = GetGametypeSetting( "carrierArmor" );	
	
	level.ballCount = GetGametypeSetting( "ballCount" );	
 	level.enemyCarrierVisible = GetGametypeSetting( "enemyCarrierVisible" );
	level.idleFlagReturnTime = GetGametypeSetting( "idleFlagResetTime" );

	globallogic::registerFriendlyFireDelay( level.gameType, 15, 0, 1440 );

	level.teamBased = true;
	level.overrideTeamScore = true;
	level.clampScoreLimit = false;
	level.doubleOvertime = true;
		
	level.onPrecacheGameType =&onPrecacheGameType;
	level.onStartGameType =&onStartGameType;
	level.onSpawnPlayer =&onSpawnPlayer;
	level.onPlayerKilled =&onPlayerKilled;
	level.onRoundSwitch =&onRoundSwitch;
	level.onRoundScoreLimit = &onRoundScoreLimit;
	level.onEndGame =&onEndGame;
	level.onRoundEndGame =&onRoundEndGame;
	level.getTeamKillPenalty =&ball_getTeamKillPenalty;
	level.setMatchScoreHUDElemForTeam =&setMatchScoreHUDElemForTeam;
	level.shouldPlayOvertimeRound =&shouldPlayOvertimeRound;
	level.onTimeLimit = &ball_onTimeLimit;

	gameobjects::register_allowed_gameobject( level.gameType );

	globallogic_audio::set_leader_gametype_dialog ( "startUplink", "hcStartUplink", "uplOrders", "uplOrders" );
	
	// Sets the scoreboard columns and determines with data is sent across the network
	if ( !SessionModeIsSystemlink() && !SessionModeIsOnlineGame() && IsSplitScreen() )
		// local matches only show the first three columns
		globallogic::setvisiblescoreboardcolumns( "score", "kills", "carries", "throws", "deaths" );
	else
		globallogic::setvisiblescoreboardcolumns( "score", "kills", "deaths", "carries", "throws" );
}

function onPrecacheGameType()
{
	game["strings"]["score_limit_reached"] = &"MP_CAP_LIMIT_REACHED";
}

function onStartGameType()
{
	level.useStartSpawns = true;
	level.ballWorldWeapon = GetWeapon( CONST_BALL_WORLD_WEAPON );
	level.passingBallWeapon = GetWeapon( CONST_PASSING_BALL_WEAPON );
	
	if ( !isdefined( game["switchedsides"] ) )
	{
		game["switchedsides"] = false;
	}
	
	setClientNameMode("auto_change");

	if ( level.scoreRoundWinBased )
	{
		globallogic_score::resetTeamScores();
	}

	util::setObjectiveText( "allies", &"OBJECTIVES_BALL" );
	util::setObjectiveText( "axis", &"OBJECTIVES_BALL" );
	
	if ( level.splitscreen )
	{
		util::setObjectiveScoreText( "allies", &"OBJECTIVES_BALL" );
		util::setObjectiveScoreText( "axis", &"OBJECTIVES_BALL" );
	}
	else
	{
		util::setObjectiveScoreText( "allies", &"OBJECTIVES_BALL_SCORE" );
		util::setObjectiveScoreText( "axis", &"OBJECTIVES_BALL_SCORE" );
	}
	util::setObjectiveHintText( "allies", &"OBJECTIVES_BALL_HINT" );
	util::setObjectiveHintText( "axis", &"OBJECTIVES_BALL_HINT" );

	if ( isdefined( game["overtime_round"] ) )
	{
		// This is only necessary when cumulativeRoundScores is on so that the game doesn't immediately end due to scorelimit being set to 1 in OT
		if ( !isdefined( game["ball_game_score"] ) )
		{
			game["ball_game_score"] = [];
			game["ball_game_score"]["allies"] = [[level._getTeamScore]]( "allies" );
			game["ball_game_score"]["axis"] = [[level._getTeamScore]]( "axis" );
		}
		[[level._setTeamScore]]( "allies", 0 );
		[[level._setTeamScore]]( "axis", 0 );
		
		if ( isdefined( game["ball_overtime_score_to_beat"] ) )
		{
			util::registerScoreLimit( game["ball_overtime_score_to_beat"], game["ball_overtime_score_to_beat"] );
		}
		else
		{
			util::registerScoreLimit( 1, 1 );
		}
		
		if ( isdefined( game["ball_overtime_time_to_beat"] ) )
		{
			util::registerTimeLimit( game["ball_overtime_time_to_beat"] / 60000, game["ball_overtime_time_to_beat"] / 60000 );
		}
		else
		{
			util::registerTimeLimit( 0, 1440 );	// Reset the time limit from the round_time_to_beat
		}
		
		if ( game["overtime_round"] == 1 )
		{
			util::setObjectiveHintText( "allies", &"MP_BALL_OVERTIME_ROUND_1" );
			util::setObjectiveHintText( "axis", &"MP_BALL_OVERTIME_ROUND_1" );
		}
		else if ( isdefined( game["ball_overtime_first_winner"] ) )
		{
			level.onTimeLimit = &ballOvertimeRound2_onTimeLimit;
			game["teamSuddenDeath"][game["ball_overtime_first_winner"]] = true;
			util::setObjectiveHintText( game["ball_overtime_first_winner"], &"MP_BALL_OVERTIME_ROUND_2_WINNER" );
			util::setObjectiveHintText( util::getOtherTeam( game["ball_overtime_first_winner"] ), &"MP_BALL_OVERTIME_ROUND_2_LOSER" );
		}
		else
		{
			level.onTimeLimit = &ballOvertimeRound2_onTimeLimit;
			util::setObjectiveHintText( "allies", &"MP_BALL_OVERTIME_ROUND_2_TIE" );
			util::setObjectiveHintText( "axis", &"MP_BALL_OVERTIME_ROUND_2_TIE" );
		}
	}
	else if ( isdefined( game["round_time_to_beat"] ) )
	{
		util::registerTimeLimit( game["round_time_to_beat"] / 60000, game["round_time_to_beat"] / 60000 );
	}
	
	// Spawn Points
	
	spawning::create_map_placed_influencers();
	
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );	
	spawnlogic::place_spawn_points( "mp_ctf_spawn_allies_start" );
	spawnlogic::place_spawn_points( "mp_ctf_spawn_axis_start" );
	spawnlogic::add_spawn_points( "allies", "mp_ctf_spawn_allies" );
	spawnlogic::add_spawn_points( "axis", "mp_ctf_spawn_axis" );

	spawning::updateAllSpawnPoints();
	
	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );

	spawnpoint = spawnlogic::get_random_intermission_point();
	setDemoIntermissionPoint( spawnpoint.origin, spawnpoint.angles );
	
	level.spawn_axis = spawnlogic::get_spawnpoint_array( "mp_ctf_spawn_axis" );
	level.spawn_allies = spawnlogic::get_spawnpoint_array( "mp_ctf_spawn_allies" );

	level.spawn_start = [];
	
	foreach( team in level.teams )
	{
		level.spawn_start[ team ] =  spawnlogic::get_spawnpoint_array("mp_ctf_spawn_" + team + "_start");
	}
	
	level thread setup_objectives();
}

function anyBallsInTheAir()
{
	foreach( ball in level.balls )
	{
		if ( isdefined( ball.carrier ) )
			continue;
		if ( isdefined( ball.projectile ) )
		{
			if ( !(ball.projectile IsOnGround()) )
				return ball;
		}
	}
	
	return;
}

function waitForBallToComeToRest()
{
	self endon("reset");
	self endon("pickup_object");
	
	if ( isdefined( self.projectile ) )
	{
		if ( self.projectile IsOnGround() )
			return;
			
		self.projectile endon("death");
		self.projectile endon("stationary");
		self.projectile endon("grenade_bounce");
		while(1)
		{
			wait(1);
		}
	}
}

function freezePlayersForRoundEnd()
{
	self endon("disconnect");
	
	self globallogic_player::freezePlayerForRoundEnd();
	self thread globallogic::roundEndDoF( 4.0 );
	
	// incase they were dead at the time
	self waittill( "spawned" );
	
	if ( self.sessionstate == "playing" )
	{
		self globallogic_player::freezePlayerForRoundEnd();
		self thread globallogic::roundEndDoF( 4.0 );
	}
}

function waitForAllBallsToComeToRest()
{
	// wait for the ball to hit the ground
	ball = anyBallsInTheAir();
	
	if ( isdefined( ball ) )
	{
		level notify ( "game_ended" );
		
		// partial implementation of endgame cleanup
		foreach( player in level.players )
		{
			player thread freezePlayersForRoundEnd();
		}
		
		ball waitForBallToComeToRest();
	}
}

function ball_onTimeLimit()
{
	waitForAllBallsToComeToRest();
	
	globallogic_defaults::default_onTimeLimit();
}

function ballOvertimeRound2_onTimeLimit()
{
	waitForAllBallsToComeToRest();

	winner = undefined;
	
	if ( level.teamBased )
	{
		foreach( team in level.teams )
		{
			if( game["teamSuddenDeath"][team] )
			{
				winner = team;
				break;
			}
		}
		
		if( !isDefined( winner ) )
		{
			winner = globallogic::determineTeamWinnerByGameStat( "teamScores" );
		}
	}
	else
	{
		winner = globallogic_score::getHighestScoringPlayer();

		/#
		if ( isdefined( winner ) )
			print( "time limit, win: " + winner.name );
		else
			print( "time limit, tie" );
		#/
	}
	
	thread globallogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

function onSpawnPlayer(predictedSpawn)
{
	self.isBallCarrier = false;
	self.ballCarried = undefined;
	self clientfield::set( CLIENT_FIELD_BALL_CARRIER, 0 );	
	
	self thread ballConsistencySwitchThread();
	
	spawning::onSpawnPlayer(predictedSpawn);
}

function ballConsistencySwitchThread()
{
	self endon( "death" );
	self endon( "delete" );
	// failsafe thread to watch if we have the ball but it is not primary 
	player = self;
	ball = GetWeapon( CONST_BALL_WEAPON );
	while( 1 )
	{
		if( isdefined( ball ) && player HasWeapon( ball ) )
		{
			curWeapon = player GetCurrentWeapon();
			if( isdefined( curWeapon ) && ( curWeapon != ball ) )
			{
				if( curWeapon.isHeroWeapon )
				{
					slot = self GadgetGetSlot( curWeapon );
					if( !self ability_player::gadget_is_in_use( slot ) )
					{
						WAIT_SERVER_FRAME;
						continue;
					}						
				}
				player switchToWeaponImmediate( ball );
				player DisableWeaponCycling();		
				player DisableOffhandWeapons();	
			}
		} 		
		WAIT_SERVER_FRAME;
	}
}

function onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( isdefined( self.carryObject ) )
	{
		otherTeam = util::getOtherTeam( self.team );
		
		if ( isdefined( attacker ) && IsPlayer( attacker ) && attacker != self )
		{
			if( attacker.team != self.team )
			{
				scoreevents::processScoreEvent( "kill_ball_carrier", attacker, undefined, weapon );
				attacker AddPlayerStat( "kill_carrier", 1 );
			}
			
			globallogic_audio::leader_dialog( "uplWeDrop", self.team, undefined, "uplink_ball" );
			globallogic_audio::leader_dialog( "uplTheyDrop", otherTeam, undefined, "uplink_ball" );
			
			globallogic_audio::play_2d_on_team( "mpl_balldrop_sting_friend", self.team );
			globallogic_audio::play_2d_on_team( "mpl_balldrop_sting_enemy", otherTeam );
			
			level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_DROPPED", self, self.team );
			level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_DROPPED", self, otherTeam );
		}
	}
	else if ( isdefined( attacker.carryObject ) && ( attacker.team != self.team ) )
	{		
		scoreevents::processScoreEvent( "kill_enemy_while_carrying_ball", attacker, undefined, weapon  );
	}
	
	foreach( ball in level.balls )
	{
		ballCarrier = ball.carrier;
		if ( isdefined( ballCarrier ) )
		{
			ballOrigin = ball.carrier.origin;
			isCarried = true;
		}
		else 
		{
			ballOrigin = ball.curorigin;
			isCarried = false;
		}	
	
		if ( isCarried && isdefined( attacker ) && isdefined( attacker.team ) && ( attacker != self ) && ( ballCarrier != attacker ) )
		{
			if ( attacker.team == ball.carrier.team )
			{
				dist = Distance2dSquared(self.origin, ballOrigin);
				if ( dist < level.defaultOffenseRadiusSQ )
				{
					attacker addplayerstat( "defend_carrier", 1 );
					break;
				}
			}
		}
	}
	
	victim = self;
	
}

function onRoundSwitch()
{
	if ( !isdefined( game["switchedsides"] ) )
		game["switchedsides"] = false;
	
	level.halftimeType = "halftime";
	game["switchedsides"] = !game["switchedsides"];
}

function onRoundScoreLimit()
{
	if ( !isdefined( game["overtime_round"] ) )
	{
		timeLimit = GetGametypeSetting( "timeLimit" ) * 60000;
		timeToBeat = globallogic_utils::getTimePassed();
		if ( timeLimit > 0 && timeToBeat < timeLimit )
		{
			game["round_time_to_beat"] = timeToBeat;
		}
	}
	
	return globallogic_defaults::default_onRoundScoreLimit();
}

function onEndGame( winningTeam )
{
	if ( !isdefined( winningTeam ) || ( winningTeam == "tie" ) )
    {
    	return;
    }
	
	if ( isdefined( game["overtime_round"] )  )
	{
		if ( game["overtime_round"] == 1 )
		{
			game["ball_overtime_first_winner"] = winningTeam;
			game["ball_overtime_score_to_beat"] = GetTeamScore( winningTeam );
			game["ball_overtime_time_to_beat"] = globallogic_utils::getTimePassed();
		}
		else
		{
			game["ball_overtime_second_winner"] = winningTeam;
			game["ball_overtime_best_score"] = GetTeamScore( winningTeam );
			game["ball_overtime_best_time"] = globallogic_utils::getTimePassed();
		}
	}
}

function updateTeamScoreByRoundsWon()
{
	if ( level.scoreRoundWinBased ) 
	{
		foreach( team in level.teams )
		{
			[[level._setTeamScore]]( team, game["roundswon"][team] );
		}
	}
}

function onRoundEndGame( winningTeam )
{
	if ( isdefined( game["overtime_round"] ) )
	{
		if ( isdefined( game["ball_overtime_first_winner"] ) )
		{
			losing_team_score = 0;
			if ( !isdefined( winningTeam ) || ( winningTeam == "tie" ) )
			{
				winningTeam = game["ball_overtime_first_winner"];
			}
			
			if ( game["ball_overtime_first_winner"] == winningTeam )
			{
				level.endVictoryReasonText = &"MPUI_BALL_OVERTIME_FASTEST_CAP_TIME";
				level.endDefeatReasonText = &"MPUI_BALL_OVERTIME_DEFEAT_TIMELIMIT";
			}
			else
			{
				level.endVictoryReasonText = &"MPUI_BALL_OVERTIME_FASTEST_CAP_TIME";
				level.endDefeatReasonText = &"MPUI_BALL_OVERTIME_DEFEAT_DID_NOT_DEFEND";
			}			
		}
		else if ( !isdefined( winningTeam ) || ( winningTeam == "tie" ) )
		{
			updateTeamScoreByRoundsWon();
			return "tie";
		}
		
		if ( level.scoreRoundWinBased ) 
		{
			foreach( team in level.teams )
			{
				score = game["roundswon"][team];
				if ( team === winningTeam )
				{
					score++;
				}
				[[level._setTeamScore]]( team, score );
			}			
		}
		else
		{
			if( isdefined( game["ball_overtime_score_to_beat"] ) && ( game["ball_overtime_score_to_beat"] > game["ball_overtime_best_score"] ) )
			{
				added_score = game["ball_overtime_score_to_beat"];
			}
			else
			{
				added_score = game["ball_overtime_best_score"];
			}				
			
			foreach( team in level.teams )
			{
				score = game["ball_game_score"][team];
				if ( team === winningTeam )
				{
					score += added_score;
				}
				[[level._setTeamScore]]( team, score );
			}						
		}
		return winningTeam;
	}
	
	if ( level.scoreRoundWinBased ) 
	{
		updateTeamScoreByRoundsWon();
	
		winner = globallogic::determineTeamWinnerByGameStat( "roundswon" );
	}
	else
	{
		winner = globallogic::determineTeamWinnerByTeamScore();
	}
	
	return winner;
}


function setMatchScoreHUDElemForTeam()
{
		self setText( &"" );
}

function shouldPlayOvertimeRound()
{
	if ( isdefined( game["overtime_round"] ) )
	{
		if ( game["overtime_round"] == 1 || !level.gameEnded ) // If we've only played 1 round or we're in the middle of the 2nd keep going
		{
			return true;
		}
		
		return false;
	}
	
	if ( !level.scoreRoundWinBased )
	{
		// Only go to overtime if both teams are tied and it's either the last round or both teams are one away from winning
		if ( ( game["teamScores"]["allies"] == game["teamScores"]["axis"] ) &&
		    ( util::hitRoundLimit() || ( game["teamScores"]["allies"] == level.scoreLimit-1 ) ) )
		{
			return true;
		}
	}
	else
	{
		// Only go to overtime if both teams are one round away from winning
		alliesRoundsWon = util::getRoundsWon( "allies" );
		axisRoundsWon = util::getRoundsWon( "axis" );
		if ( ( level.roundWinLimit > 0 ) && ( axisRoundsWon == level.roundWinLimit-1 ) && ( alliesRoundsWon == level.roundWinLimit-1 ) )
		{
			return true;
		}
		if ( util::hitRoundLimit() && ( alliesRoundsWon == axisRoundsWon ) )
		{
			return true;
		}
	}
	return false;
}

function ball_getTeamKillPenalty( eInflictor, attacker, sMeansOfDeath, weapon )
{
	teamkill_penalty = globallogic_defaults::default_getTeamKillPenalty( eInflictor, attacker, sMeansOfDeath, weapon );

	if ( ( isdefined( self.isBallCarrier ) && self.isBallCarrier ) )
	{
		teamkill_penalty = teamkill_penalty * level.teamKillPenaltyMultiplier;
	}
	
	return teamkill_penalty;
}

//////////////////////

function setup_objectives()
{
	level.ball_goals = [];
	level.ball_starts = [];
	level.balls = [];
	
	level.ball_starts = getEntArray( "ball_start" ,"targetname");
	
	foreach( ball_start in level.ball_starts )
	{
		level.balls[level.balls.size] = spawn_ball( ball_start );
	}
	
	foreach( team in level.teams )
	{
		if(	!game["switchedsides"] )
		{
			trigger = GetEnt( "ball_goal_" + team, "targetname" );
		}
		else
		{
			trigger = GetEnt( "ball_goal_" + util::getOtherTeam( team ), "targetname" );
		}
		
		level.ball_goals[team] = setup_goal( trigger, team );
	}
}

// Goals
//========================================

function setup_goal( trigger, team )
{	
	// Goal Object
	useObj = gameobjects::create_use_object( team, trigger, [], ( 0, 0, trigger.height * 0.5 ), istring("ball_goal_"+team) );
	useObj gameobjects::set_visible_team( "any" );
	useObj gameobjects::set_model_visibility( true );
	useObj gameobjects::allow_use( "enemy" );
	useObj gameobjects::set_use_time( 0 );
	useObj gameobjects::set_key_object( level.balls[0] );  // need to get array of key objects working
	
	useObj.canUseObj = &can_use_goal;
	useObj.onUse = &on_use_goal;

	useObj.ball_in_goal = false;
	useObj.radiusSq = trigger.radius * trigger.radius;
	useObj.center = trigger.origin + ( 0, 0, trigger.height * 0.5 );

	return useObj;
}

function can_use_goal( player )
{	
	return !self.ball_in_goal;
}

function on_use_goal(player)
{
	if ( !IsDefined(player) || !IsDefined(player.carryObject) )
		return;

	if ( isDefined( player.carryObject.scoreFrozenUntil ) && player.carryObject.scoreFrozenUntil > getTime() )
		return;
	
	self play_goal_score_fx();
	
	player.carryObject.scoreFrozenUntil = getTime() + 10000;

	ball_check_assist( player, true );
	
	team = self.team;
	otherTeam = util::getOtherTeam( team );

	globallogic_audio::flush_objective_dialog( "uplink_ball" );
	globallogic_audio::leader_dialog( "uplWeUplink", otherTeam );
	globallogic_audio::leader_dialog( "uplTheyUplink", team );
	
	globallogic_audio::play_2d_on_team( "mpl_ballcapture_sting_friend", otherTeam );
  globallogic_audio::play_2d_on_team( "mpl_ballcapture_sting_enemy", team );
    
	level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_CAPTURE", player, team );
	level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_CAPTURE", player, otherTeam );
    
	if(IsDefined(player.shoot_charge_bar))
	{
		player.shoot_charge_bar.inUse = false;
	}
	
	ball = player.carryObject;
	ball.lastCarrierScored = true;
	
	player gameobjects::take_carry_weapon( ball.carryWeapon );
	ball ball_set_dropped( true );
	ball thread upload_ball( self );
	
	if( isdefined(player.pers["carries"]) )
	{
		player.pers["carries"]++;
		player.carries = player.pers["carries"];
	}
	
	player AddPlayerStatWithGameType( "CARRIES", 1 );
	player AddPlayerStatWithGameType( "captures", 1 ); // counts towards Destroyer challenge
	scoreevents::processScoreEvent( "ball_capture_carry", player );
	ball_give_score( otherTeam, level.carryScore );
}

// Balls
//========================================

function spawn_ball( trigger )
{
	visuals = [];
	visuals[0] = spawn("script_model", trigger.origin );
	visuals[0] SetModel( BALL_MODEL );
	visuals[0] notsolid();
	
	trigger EnableLinkTo();
	trigger LinkTo( visuals[0] );
	trigger.no_moving_platfrom_unlink = true;
	
	ballObj = gameobjects::create_carry_object( "neutral", trigger, visuals, (0,0,0), istring("ball_ball"), "mpl_hit_alert_ballholder" );
	ballObj gameobjects::allow_carry( "any" );
	ballObj gameobjects::set_visible_team( "any" );
	ballObj gameobjects::set_drop_offset( 8 );  // the radius of the ball model so it looks like its on the ground

	ballObj.objectiveOnVisuals = true;
	ballObj.allowWeapons = false;
	ballObj.carryWeapon = GetWeapon( CONST_BALL_WEAPON );
	ballObj.keepCarryWeapon = true;
	ballObj.waterBadTrigger = false;
	ballObj.disallowRemoteControl = true;
	ballObj.disallowPlaceablePickup = true;
	//ballObj.requiresLOS = true;	I don't think this does anything
	
	ballObj gameobjects::update_objective();
	
	ballObj.canUseObject = &can_use_ball;
	ballObj.onPickup = &on_pickup_ball;
	ballObj.setDropped = &ball_set_dropped;
	ballObj.onReset = &on_reset_ball;
	ballObj.pickupTimeoutOverride  = &ball_physics_timeout;
	ballObj.carryWeaponThink = &carry_think_ball;

	ballObj.in_goal = false;	
	ballObj.lastCarrierScored = false;
	ballObj.lastCarrierTeam = "neutral";
	
	if ( level.enemyCarrierVisible == 2 )
	{
		ballObj.objIDPingFriendly = true;
	}

	if ( level.idleFlagReturnTime > 0 )
	{
		ballObj.autoResetTime = level.idleFlagReturnTime;
	}
	else
	{
		ballObj.autoResetTime = undefined;
	}		

	PlayFXOnTag( TRAIL_FX, ballObj.visuals[0], "tag_origin" );
	
	return ballObj;
}

// Ball Events
//========================================

function can_use_ball(player)
{
	if(!isDefined(player))
		return false;
	
	if ( !self gameobjects::can_interact_with( player ) )
		return false;
	
	if ( IsDefined(self.dropTime) && self.dropTime >= GetTime() )
		return false;
	
	if( isdefined( player.resurrect_weapon ) && ( player getcurrentweapon() == player.resurrect_weapon ) )
		return false;
	
	if ( player isCarryingTurret() )
		return false;
	
	currentWeapon = player GetCurrentWeapon();
	if(isDefined(currentWeapon))
	{
		if( !valid_ball_pickup_weapon( currentWeapon ) )
			return false;
	}
	
	nextWeapon = player.changingWeapon;
	if(IsDefined(nextWeapon) && player IsSwitchingWeapons() )
	{
		if( !valid_ball_pickup_weapon( nextWeapon ) )
			return false;
	}
	
	if ( player player_no_pickup_time() )
		return false;

	ball = self.visuals[0];
	thresh = 15;
	dist2 = Distance2DSquared( ball.origin, player.origin );
	if( dist2 < thresh * thresh )
		return true;
	
	ball = self.visuals[0];
	
	start = player getEye();
	
	end = ( self.curorigin[0], self.curorigin[1], self.curorigin[2] + 5 );
	if ( isdefined( self.carrier ) && isPlayer( self.carrier  ) )
	{ 
		end = self.carrier getEye();
	}

	if ( !SightTracePassed( end, start, false, ball ) && !SightTracePassed( end, player.origin, false, ball ) )
	{
		return false;
	}

	return true;
}

function chief_mammal_reset()
{
	self.isResetting = true;
	
	self notify ( "reset" );
	
	origin = self.curOrigin;
	if( isdefined( self.projectile ) )
		origin = self.projectile.origin;
	
	foreach( visual in self.visuals )
	{
		visual.origin = origin;
		visual.angles = visual.baseAngles;
		visual DontInterpolate();
		visual show();
	}	
	
	if( isdefined( self.projectile ) )
		self.projectile Delete();

	self gameobjects::clear_carrier();
	gameobjects::update_world_icons();
	gameobjects::update_compass_icons();
	gameobjects::update_objective();
	
	self.isResetting = false;
}

function on_pickup_ball( player )
{
	self gameobjects::set_flags( OBJECTIVE_FLAG_NORMAL );

	if( !isalive( player ) )
	{
		self chief_mammal_reset();
		return;
	}
	
	player DisableUsability();
	player DisableOffhandWeapons();	
	
	level.useStartSpawns = false;
	
	level clientfield::set( "ball_away", 1 );

	//Physics objects get linked to entities if they come to rest on them
	linkedParent = self.visuals[0] GetLinkedEnt();
	if(IsDefined(linkedParent))
		self.visuals[0] unlink();

	player resetflashback();
	
	pass = false;
	ball_velocity = 0.0;
	if(IsDefined(self.projectile))
	{
		pass = true;
		ball_velocity = self.projectile GetVelocity();		
		self.projectile Delete();
	}
	
	if( pass )
	{
		if( self.lastCarrierTeam == player.team )
		{
			if ( self.lastCarrier != player )
			{
				player.passTime = GetTime();
				player.passPlayer = self.lastcarrier;
				
				globallogic_audio::leader_dialog( "uplTransferred", player.team, undefined, "uplink_ball" );
			}
		}
		else
		{
			if ( Length( ball_velocity ) > 0.1 )
			{
				scoreevents::processScoreEvent( "ball_intercept", player );
			}
		}
	}
	
	otherTeam = util::getOtherTeam( player.team );
	
	if( self.lastCarrierTeam != player.team )
	{		
		globallogic_audio::leader_dialog( "uplWeTake", player.team, undefined, "uplink_ball" );
		globallogic_audio::leader_dialog( "uplTheyTake", otherTeam, undefined, "uplink_ball" );
	}

	globallogic_audio::play_2d_on_team( "mpl_ballget_sting_friend", player.team );
	globallogic_audio::play_2d_on_team( "mpl_ballget_sting_enemy", otherTeam );
	
	level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_PICKED_UP", player, player.team );
	level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_PICKED_UP", player, otherTeam );
	
	self.lastCarrierScored = false;
	self.lastcarrier = player;
	self.lastCarrierTeam = player.team;
	
	self gameobjects::set_owner_team( player.team );

	player.ballDropDelay = GetDvarInt( "scr_ball_water_drop_delay", 10 );	//server frames to wait while underwater before dropping the ball
	player.objective = 1;
	
	player.hasPerkSprintFire = player HasPerk("specialty_sprintfire" );
	player setPerk("specialty_sprintfire" );
	
	player clientfield::set( "ballcarrier", 1 );
	
	if ( level.carryArmor > 0 )
		player thread armor::setLightArmor(level.carryArmor);
	else
		player thread armor::unsetLightArmor();

	player thread player_update_pass_target(self);
}

function ball_carrier_cleanup( )
{
	self gameobjects::set_owner_team( "neutral" );
	
	if ( isdefined(self.carrier) )
	{
		self.carrier clientfield::set( "ballcarrier", 0 );
		self.carrier.ballDropDelay = undefined;
		self.carrier.noPickupTime = GetTime() + 500;
		
		self.carrier player_clear_pass_target();
		self.carrier notify("cancel_update_pass_target");
		
		self.carrier thread armor::unsetLightArmor();
	
		if ( !self.carrier.hasPerkSprintFire )
		{
			self.carrier unsetPerk( "specialty_sprintfire" );
		}
		
		self.carrier EnableUsability();
		self.carrier EnableOffhandWeapons();	
		
		self.carrier SetBallPassAllowed(false);
		self.carrier.objective = 0;
	}
}

function ball_set_dropped( skip_physics )
{	
	DEFAULT( skip_physics, false );
	
	self.isResetting = true;
	self.dropTime = GetTime();
	
	self notify ( "dropped" );

	dropAngles = (0,0,0);

	carrier = self.carrier;
	if(IsDefined(carrier) && carrier.team != "spectator")
	{
		dropOrigin = carrier.origin;
		dropAngles = carrier.angles;
	}
	else
	{
		dropOrigin = self.origin;
	}
	
	if( !isdefined( dropOrigin ) )
		dropOrigin = self.safeorigin;
	
	dropOrigin += ( 0, 0, 40 );
	
	if( isdefined( self.projectile ) )
		self.projectile Delete();
	
	self ball_carrier_cleanup();
	self gameobjects::clear_carrier();
	self gameobjects::set_position( dropOrigin, dropAngles );
	self gameobjects::update_icons_and_objective();
	self thread gameobjects::pickup_timeout( dropOrigin[2], dropOrigin[2] - 40);

	self.isResetting = false;
	
	if(!skip_physics)
	{
		angles = ( 0, dropAngles[1], 0 );
		forward = AnglesToForward( angles );
		velocity = 	forward * 200 + (0,0,80);
		ball_physics_launch(velocity);
	}

	return true;
}

function on_reset_ball( prev_origin )
{
	if ( IS_TRUE( level.gameEnded ) )
	{
		return;
	}
	
	visual = self.visuals[0];
	
	//Physics objects get linked to entities if they come to rest on them
	linkedParent = visual GetLinkedEnt();
	if( IsDefined(linkedParent) )
	{
		visual unlink();
	}
	
	if( IsDefined( self.projectile ) )
	{
		self.projectile Delete();
	}

	if( !self gameobjects::get_flags( OBJECTIVE_FLAG_UPLOADING ) )
	{
		PlayFx( RESET_FX, prev_origin );
		self play_return_vo();
	}
	self.lastCarrierTeam = "none";
	self thread download_ball();
}

// Ball Functions
//========================================

function reset_ball()
{
	self thread gameobjects::return_home();
}

function upload_ball( goal )
{
	self notify( "score_event" );
	
	self.in_goal = true;
	goal.ball_in_goal = true;	
		
	if(IsDefined(self.projectile))
	{
		self.projectile Delete();
	}
	
	self gameobjects::allow_carry( "none" );
	
	move_to_center_time = .4;
	move_up_time = 1.2;
	rotate_time = 1.0;
	
	in_enemyGoal_time = move_to_center_time + rotate_time;
	total_time = in_enemyGoal_time + move_up_time;
	
	self gameobjects::set_flags( OBJECTIVE_FLAG_UPLOADING );

	visual = self.visuals[0];
	
	visual MoveTo( goal.center, move_to_center_time, 0, move_to_center_time);
	visual RotateVelocity( (1080,1080,0), total_time, total_time, 0);
	
	wait in_enemyGoal_time;
	
	self.visibleTeam = "neutral";
	self gameobjects::update_world_icon( "friendly", false );
	self gameobjects::update_world_icon( "enemy", false );	
	self gameobjects::update_objective();
	
	visual MoveZ(4000, move_up_time, move_up_time*.1, 0);
	
	wait move_up_time;
	
	goal.ball_in_goal = false;
	
	self thread gameobjects::return_home();
}

function download_ball()
{
	self endon ( "pickup_object" );
	
	self gameobjects::allow_carry( "any" );
	self gameobjects::set_owner_team( "neutral" );	
	self gameobjects::set_flags( OBJECTIVE_FLAG_DOWNLOADING );
	
	visual = self.visuals[0];
	
	visual.origin = visual.baseOrigin + (0,0,4000);
	visual DontInterpolate();
	
	fall_time = 3;
	visual MoveTo( visual.baseOrigin, fall_time, 0, fall_time);
	
	visual RotateVelocity( (0,720,0), fall_time, 0, fall_time);
	
	self.visibleTeam = "any";
	self gameobjects::update_world_icon( "friendly", true );
	self gameobjects::update_world_icon( "enemy", true );	
	self gameobjects::update_objective();

	wait( fall_time );
		
	self gameobjects::set_flags( OBJECTIVE_FLAG_NORMAL );
	level clientfield::set( "ball_away", 0 ); 

	PlayFXOnTag( TRAIL_FX, visual, "tag_origin" );
	
	self thread ball_download_fx(visual, fall_time);
	
	self.in_goal = false;
}


// Ball Carry Watch
//========================================

function carry_think_ball()
{
	self endon("disconnect");
	
	self thread ball_pass_watch();
	self thread ball_shoot_watch();
	self thread ball_weapon_change_watch(); // change to hero weapons is allowed
}

function ball_pass_watch()
{
	level endon ( "game_ended" );

	self endon ( "disconnect" );
	self endon ( "death" );
	self endon ( "drop_object" );
	
	while( 1 )
	{
		self waittill( "ball_pass", weapon );
		
		if( !isDefined(self.pass_target) )
		{
			playerAngles = self GetPlayerAngles();
			playerAngles = ( math::Clamp( playerAngles[0], -85, 85 ), playerAngles[1], playerAngles[2] );
			dir = AnglesToForward( playerAngles );
			force = 90;
			self.carryObject thread ball_physics_launch_drop( dir * force, self );			
			return;
		}
		break;
	}

	if( isDefined( self.carryObject ) )
	{
		self thread ball_pass_or_throw_active();
		pass_target = self.pass_target;
		last_target_origin = self.pass_target.origin;
		wait .15;
		
		if( isdefined( self.pass_target ) )
		{ // pass the ball
			pass_target = self.pass_target;
			self.carryObject thread ball_pass_projectile( self, pass_target, last_target_origin );
		}
		else		
		{ // drop the ball
			playerAngles = self GetPlayerAngles();
			playerAngles = ( math::Clamp( playerAngles[0], -85, 85 ), playerAngles[1], playerAngles[2] );
			dir = AnglesToForward( playerAngles );
			force = 90;
			self.carryObject thread ball_physics_launch_drop( dir * force, self );						
		}
	}
}

function ball_shoot_watch()
{
	level endon ( "game_ended" );

	self endon ( "disconnect" );
	self endon ( "death" );
	self endon ( "drop_object" );
	
	extra_pitch 	= GetDvarFloat("scr_ball_shoot_extra_pitch", 0);
	force			= GetDvarFloat("scr_ball_shoot_force", 900 );
	
	while(1)
	{
		self waittill("weapon_fired", weapon);
		
		if( weapon != GetWeapon( CONST_BALL_WEAPON ) )
		{
			continue;
		}
		
		break;
	}
		
	if ( IsDefined( self.carryObject ) )
	{
		playerAngles = self GetPlayerAngles();
		playerAngles += (extra_pitch,0,0);
		playerAngles = (math::Clamp(playerAngles[0], -85, 85), playerAngles[1], playerAngles[2]);
		dir = AnglesToForward(playerAngles);
		self thread ball_pass_or_throw_active();
		self thread ball_check_pass_kill_pickup( self.carryObject );
		self.carryObject ball_create_killcam_ent();
		self.carryObject thread ball_physics_launch_drop(dir*force, self, true );		
	}
}

function ball_weapon_change_watch()
{
	level endon ( "game_ended" );

	self endon ( "disconnect" );
	self endon ( "death" );
	self endon ( "drop_object" );

	ballWeapon = GetWeapon( CONST_BALL_WEAPON );
	while( 1 )
	{
		if( ballWeapon == self GetCurrentWeapon() )
			break;
		self waittill ( "weapon_change" );
	}	

	while( 1 )
	{
		self waittill ( "weapon_change", weapon, lastWeapon );
		if( isdefined( weapon ) && ( weapon.gadget_type == GADGET_TYPE_HERO_WEAPON ) )
			break;
		if( ( weapon === level.weaponNone ) && ( lastWeapon === ballWeapon ) ) // swtiching away from the ball for some reason - gravity spikes would be an example
			break;
	}	
	
	playerAngles = self GetPlayerAngles();
	playerAngles = ( math::Clamp( playerAngles[0], -85, 85 ), AbsAngleClamp360( playerAngles[1] + 20 ), playerAngles[2] );
	dir = AnglesToForward( playerAngles );
	force = 90;
	self.carryObject thread ball_physics_launch_drop( dir * force, self );
}

// Ball Pickup Helpers
//========================================

function valid_ball_pickup_weapon( weapon )
{
	if( weapon == level.weaponNone )
		return false;
	
	if( weapon == GetWeapon( CONST_BALL_WEAPON ) )
		return false;
	
	if( killstreaks::is_killstreak_weapon( weapon ) )
		return false;
	
	return true;
}

function player_no_pickup_time()
{
	return isDefined(self.noPickupTime) && self.noPickupTime > GetTime();
}


//self == player
function watchUnderwater( trigger )
{
	self endon ("death" );
	self endon ("disconnect" );
	
	while( 1 )
	{
		if( self isplayerunderwater() )
		{
			foreach(ball in level.balls)
			{
				if( isDefined(ball.carrier) && ball.carrier == self )
				{
					ball gameobjects::set_dropped();
					return;
				}
			}
		}
		
		self.ballDropDelay = undefined;
		WAIT_SERVER_FRAME;
	}
}

function ball_physics_launch_drop( force, droppingPlayer, switchWeapon )
{
	ball_set_dropped( true );
	ball_physics_launch( force, droppingPlayer );
	if( IS_TRUE( switchWeapon ) )
		droppingPlayer killstreaks::switch_to_last_non_killstreak_weapon( undefined, true );
}

function ball_check_pass_kill_pickup( carryObj )
{
	self endon("death");
	self endon("disconnect");
	
	carryObj endon("reset");
	
	timer = spawnStruct();
	timer endon("timer_done");
	
	timer thread timer_run(1.5);	
	carryObj waittill("pickup_object");
	timer timer_cancel();
	
	if(!IsDefined(carryObj.carrier) || carryObj.carrier.team == self.team)
	{
		return;
	}
	
	carryObj.carrier endon("disconnect");
	
	timer thread timer_run(5);
	carryObj.carrier waittill("death", attacker);
	timer timer_cancel();
	
	if(!IsDefined(attacker) || attacker != self)
	{
		return;
	}
	
	timer thread timer_run(2);
	carryObj waittill("pickup_object");
	timer timer_cancel();
}

function timer_run(time)
{
	self endon("cancel_timer");
	wait time;
	self notify("timer_done");
}

function timer_cancel()
{
	self notify("cancel_timer");
}

function adjust_for_stance( ball )
{
	target = self;
	target endon("pass_end");
		
	offs = 0;
	while( isdefined( target ) && isdefined( ball ) )
	{
		newoffs = 50;
		switch( target GetStance() )
		{
			case "crouch":
				newoffs = 30;
				break;
			case "prone":
				newoffs = 15;
				break;
		}			
		if( newoffs != offs )
		{
			ball ballsettarget( target, ( 0, 0, newoffs ) );	
			newoffs = offs;
		}
		WAIT_SERVER_FRAME;		
	}
}

function ball_pass_projectile(passer, target, last_target_origin)
{
	ball_set_dropped(true);
	
	if(IsDefined(target))
	{
		last_target_origin = target.origin;
	}
	
	offset = ( 0, 0, 60 );
	
	if ( target GetStance() == "prone" )
	{
		offset = ( 0, 0, 15 );
	}
	else if ( target GetStance() == "crouch" )
	{
		offset = ( 0, 0, 30 );
	}
		
	playerAngles = passer GetPlayerAngles();
	playerAngles = (0, playerAngles[1], 0 );
	dir = AnglesToForward(playerAngles);
	
	delta = dir * 50;
	origin = self.visuals[0].origin + delta;
	
	size = 5;
	trace = physicstrace( self.visuals[0].origin, origin, ( -size, -size, -size ), ( size, size, size ), passer, PHYSICS_TRACE_MASK_PHYSICS );
	
	if( trace["fraction"] < 1 )
	{
		t = 0.7 * trace["fraction"];
		self gameobjects::set_position( self.visuals[0].origin + delta * t, self.visuals[0].angles );
	}
	else 
	{
		self gameobjects::set_position( trace["position"], self.visuals[0].angles );
	}
	
	pass_dir = VectorNormalize((last_target_origin+offset) - self.visuals[0].origin);
	pass_vel = pass_dir * 850;

	
	self.projectile = passer MagicMissile( level.passingBallWeapon, self.visuals[0].origin, pass_vel  );
	
	target thread adjust_for_stance( self.projectile );
	
	self.visuals[0] LinkTo(self.projectile);
	self gameobjects::ghost_visuals();
	
	self ball_create_killcam_ent();
	
	self ball_clear_contents(); //Prevent magic grenade from hitting the ball visuals
	
	self thread ball_on_projectile_hit_client(passer);
	self thread ball_on_projectile_death();
	self thread ball_watch_touch_enemy_goal();
	
	passer killstreaks::switch_to_last_non_killstreak_weapon( undefined, true );
}

function ball_on_projectile_death()
{
	self.projectile waittill("death");
	ball = self.visuals[0];
	if(!IsDefined(self.carrier) && !self.in_goal)
	{
		// There's a bug where the ball will be reset during the same frame that the above trigger is notified,
		// but the notification is processed after the reset. This turns physics back on, overrides the MoveTo,
		// and causes the ball to bounce really hard in an arbitrary direction.  
		// This hack is a way to test whether the ball was just reset or not.  If it was just reset, don't fake bounce.
		if ( ball.origin != ball.baseOrigin + (0, 0, 4000) )
		{
			self ball_physics_launch((0,0,10));
		}
	}
	self ball_restore_contents();
	
	ball notify("pass_end");
}

function ball_restore_contents()
{
	if(IsDefined(self.visuals[0].old_contents))
	{
		self.visuals[0] SetContents(self.visuals[0].old_contents);
		self.visuals[0].old_contents = undefined;
	}	
}

function ball_on_projectile_hit_client(passer)
{
	self endon("pass_end");
	self.projectile waittill( "projectile_impact_player", player );
	self.trigger notify( "trigger", player );
}

function ball_clear_contents()
{
	self.visuals[0].old_contents = self.visuals[0] SetContents(0);
}

function ball_create_killcam_ent()
{
	if(IsDefined(self.killcamEnt))
		self.killcamEnt Delete();
	self.killcamEnt = spawn( "script_model", self.visuals[0].origin );
	self.killcamEnt linkTo(self.visuals[0]);
	self.killcamEnt SetContents(0);
}
	
function ball_pass_or_throw_active()
{
	self endon("death");
	self endon("disconnect");
	
	self.pass_or_throw_active = true;
	
	self AllowMelee( false );
	while( GetWeapon( CONST_BALL_WEAPON ) == self GetCurrentWeapon() )
	{
		WAIT_SERVER_FRAME();
	}
	
	self AllowMelee( true );
	self.pass_or_throw_active = false;
}

function ball_download_fx(ball_model, waitTime)
{
	self.scoreFrozenUntil = 0;
}

function ball_assign_random_start()
{	
	new_start = undefined;
	
	rand_starts = array::randomize( level.ball_starts );
	foreach(start in rand_starts)
	{
		if(start.in_use)
			continue;
		
		new_start = start;
		break;
	}

	if(!isDefined(new_start))
		return;
	
	ball_assign_start(new_start);
}

function ball_assign_start(start)
{
	foreach(vis in self.visuals)
	{
		vis.baseOrigin = start.origin;
	}
	
	self.trigger.baseOrigin = start.origin;
	
	self.current_start = start;
	start.in_use = true;
}

function ball_physics_launch(force, droppingPlayer)
{
	visuals = self.visuals[0];

	visuals.origin_prev = undefined;
	
	origin = visuals.origin;
	owner = visuals;
	
	if( isDefined( droppingPlayer ) )
	{
		owner = droppingPlayer;
		
		origin = droppingPlayer getweaponmuzzlepoint();
		right = AnglesToRight( force );
		origin = origin + ( right[0], right[1], 0 ) * 7;
		startPos = origin;// + ( 0, 0, 20 );
		delta = VectorNormalize(force) * 80;
		
		size = 5;
		trace = physicstrace( startPos, startPos + delta, ( -size, -size, -size ), ( size, size, size ), droppingPlayer, PHYSICS_TRACE_MASK_PHYSICS );
		
		if( trace["fraction"] < 1 )
		{
			t = 0.7 * trace["fraction"];
			self gameobjects::set_position( startPos + delta * t, visuals.angles );
		}
		else 
		{
			self gameobjects::set_position( trace["position"], visuals.angles );
		}
	}
	
	grenade = owner MagicMissile( level.ballWorldWeapon, visuals.origin, force  );
	visuals linkto( grenade );
	self gameobjects::ghost_visuals();
	self.projectile = grenade;
	
	visuals DontInterpolate(); // This triggers teleport to avoid interpolation from the previous position. 

	self thread ball_physics_out_of_level();
	self thread ball_watch_touch_enemy_goal();
	self thread ball_physics_touch_cant_pickup_player(droppingPlayer);
	self thread ball_check_oob();

}

function ball_check_oob()
{
	self endon ( "reset" );
	self endon ( "pickup_object" );
	
	visual = self.visuals[0];
	
	while( 1 )
	{
		skip_oob_check = IS_TRUE( self.in_goal ) || IS_TRUE( self.isResetting );
		if( !skip_oob_check )
		{
			if( visual oob::IsTouchingAnyOOBTrigger() || self gameobjects::should_be_reset( visual.origin[2], visual.origin[2] + 10, true ) )
			{
				self reset_ball();
				return;
			}
		}

		WAIT_SERVER_FRAME;		
	}
}


function ball_physics_touch_cant_pickup_player(droppingPlayer)
{
	self endon ( "reset" );
	self endon ( "pickup_object" );
	
	ball = self.visuals[0];
	trigger = self.trigger;

	while(1)
	{
		trigger waittill("trigger", player);
		//Dont stop on the throwing player
		if ( IsDefined(droppingPlayer) && droppingPlayer == player && player player_no_pickup_time() )
		{
			continue;
		}
		
		if ( self.dropTime >= GetTime()  )
		{
			continue;
		}
		
		// There's a bug where the ball will be reset during the same frame that the above trigger is notified,
		// but the notification is processed after the reset. This turns physics back on, overrides the MoveTo,
		// and causes the ball to bounce really hard in an arbitrary direction.  
		// This hack is a way to test whether the ball was just reset or not.  If it was just reset, don't fake bounce.	
		if ( ball.origin == ball.baseOrigin + (0, 0, 4000) )
		{
			continue;
		}
		
		if(	!can_use_ball( player ) && ( self.dropTime + 200 < GetTime() ) )
		{
			//self thread ball_physics_fake_bounce();
		}
	}
}

function ball_physics_fake_bounce()
{
	ball = self.visuals[0];
	vel = ball GetVelocity();
	bounceForce = Length(vel)/10;
	bounceDir = -1*VectorNormalize(vel);
}

function ball_watch_touch_enemy_goal( )
{
	self endon ( "reset" );
	self endon ( "pickup_object" );
	
	enemyGoal = level.ball_goals[util::getotherteam( self.lastCarrierTeam )];
	
	while(1)
	{
		if ( !enemyGoal can_use_goal() )
		{
			WAIT_SERVER_FRAME;
			continue;	
		}

		ballVisual = self.visuals[0];
		
		distSq = DistanceSquared( ballVisual.origin, enemyGoal.center );
		if ( distSq <= enemyGoal.radiusSq )
		{
			self thread ball_touched_goal( enemyGoal );
			return;
		}
		
		if ( isdefined( ballVisual.origin_prev ) )
		{
			result = line_intersect_sphere( ballVisual.origin_prev, ballVisual.origin, enemyGoal.center, enemyGoal.trigger.radius );
			if ( result )
			{
				self thread ball_touched_goal( enemyGoal );
				return;
			}
			
		}
		
		WAIT_SERVER_FRAME;
	}
}

function line_intersect_sphere(line_start, line_end, sphere_center, sphere_radius)
{
	dir = VectorNormalize(line_end - line_start);
	
	a = VectorDot(dir,(line_start-sphere_center));
	a*=a;
	b = (line_start-sphere_center);
	b *= b;
	c = sphere_radius*sphere_radius;
	
	return (a-b+c)>=0;
}

function ball_touched_goal(goal)
{
	if ( isdefined( self.claimPlayer ) )	// We are about to give the ball to another player this frame
		return;
	
	if ( isDefined( self.scoreFrozenUntil ) && self.scoreFrozenUntil > getTime() )
		return;

	self gameobjects::allow_carry( "none" );
	
	goal play_goal_score_fx();
	
	self.scoreFrozenUntil = getTime() + 10000;

	team = goal.team;
	otherTeam = util::getOtherTeam( team );

	// TODO: Ball ID
	globallogic_audio::flush_objective_dialog( "uplink_ball" );
	globallogic_audio::leader_dialog( "uplWeUplinkRemote", otherTeam );
	globallogic_audio::leader_dialog( "uplTheyUplinkRemote", team );
	
	globallogic_audio::play_2d_on_team( "mpl_ballcapture_sting_friend", otherTeam );
    globallogic_audio::play_2d_on_team( "mpl_ballcapture_sting_enemy", team );
    
	if ( isDefined(self.lastCarrier) )
	{
		level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_CAPTURE", self.lastCarrier, team );
		level thread popups::DisplayTeamMessageToTeam( &"MP_BALL_CAPTURE", self.lastCarrier, otherTeam );
		
		if( isdefined(self.lastCarrier.pers["throws"]) )
		{
			self.lastCarrier.pers["throws"]++;
			self.lastCarrier.throws = self.lastCarrier.pers["throws"];
		}
		
		self.lastCarrier AddPlayerStatWithGameType( "THROWS", 1 );
		scoreevents::processScoreEvent( "ball_capture_throw", self.lastCarrier );
		self.lastCarrierScored = true;
		ball_check_assist( self.lastcarrier, false );
		
		self.lastCarrier AddPlayerStatWithGameType( "CAPTURES", 1 );
	}

	if(IsDefined(self.killcamEnt))
	{
		self.killcamEnt Unlink();
	}
	
	self thread upload_ball( goal );
	
	ball_give_score( otherTeam, level.throwScore );
}

function ball_give_score( team, score )
{
	level globallogic_score::giveTeamScoreForObjective( team, score );
	
	if ( isdefined( game["overtime_round"] ) )
	{
		if( game["overtime_round"] != 1 )
		{
			if ( game["ball_overtime_first_winner"] === team )
			{
				thread globallogic::endGame( team, game["strings"]["score_limit_reached"] );
			}
			
			team_score = [[level._getTeamScore]]( team );
			other_team_score = [[level._getTeamScore]]( util::getOtherTeam(team));
		}
	}
}


function should_record_final_score_cam(team, score_to_add)
{
	//Don't record kill cam if the team scoring would still be losing
	team_score = [[level._getTeamScore]]( team );
	other_team_score = [[level._getTeamScore]]( util::getOtherTeam(team));
	
	return (team_score + score_to_add) >= other_team_score;
}
	
function ball_check_assist( player, wasDunk )
{
	//Was the player passed to
	if(!IsDefined(player.passTime) || !IsDefined(player.passPlayer))
		return;

	//Was it a recent pass
	if(player.passTime+3000 < GetTime())
		return;
	
	scoreevents::processScoreEvent( "ball_capture_assist",player.passPlayer );
}
	

function ball_physics_timeout( )
{
	self endon( "reset" );
	self endon( "pickup_object" );
	self endon( "score_event" );
	
	if ( isdefined( self.autoResetTime ) && self.autoResetTime > PHYSICS_TIME_LIMIT )
	{
		physicsTime = self.autoResetTime;
	}
	else
	{
		physicsTime = PHYSICS_TIME_LIMIT;
	}
	
	if( isdefined( self.projectile ) )
	{
		timeoutReason = self.projectile util::waittill_any_timeout( physicsTime, "stationary" );
		iF( !isdefined( timeoutReason ) )
			return;
		
		if ( timeoutReason == "stationary" )
		{
			if ( isdefined( self.autoResetTime ) )
			{		
				wait self.autoResetTime;
			}
		}
	}
	
	self reset_ball();
}

function ball_physics_out_of_level()
{
	self endon ( "reset" );
	self endon ( "pickup_object" );
	
	ball = self.visuals[0];

	self waittill ( "entity_oob" );

	self reset_ball();
}

function player_update_pass_target(ballObj)
{
	self notify( "update_pass_target" );
	self endon( "update_pass_target" );
	self endon("disconnect");
	self endon("cancel_update_pass_target");
	
	test_dot = 0.8;
	while(1)
	{
		new_target = undefined;
		
		if ( !self IsOnLadder() )
		{
			playerDir = AnglesToForward( self GetPlayerAngles() );
			playerEye = self GetEye();
			
			possible_pass_targets = [];
			foreach(target in level.players)
			{
				if ( target.team != self.team )
					continue;
			
				if ( !isAlive( target ) )
					continue;
				
				if( !ballObj can_use_ball(target) )
					continue;
				
				targetEye = target GetEye();
				distSq = DistanceSquared( targetEye, playerEye );
				if ( distSq > CONST_MAX_PASS_DISTANCE )
					continue;

				dirToTarget = VectorNormalize( targetEye - playerEye );
				dot = VectorDot( playerDir, dirToTarget );
				if ( dot > test_dot )
				{
					target.pass_dot = dot;
					target.pass_origin = targetEye;
					possible_pass_targets[possible_pass_targets.size] = target;
				}
			}
			
			//possible_pass_targets = ArraySort(possible_pass_targets, self.origin );
			possible_pass_targets = array::quicksort( possible_pass_targets, &compare_player_pass_dot );
			
			foreach(target in possible_pass_targets)
			{
				if ( SightTracePassed(playerEye, target.pass_origin, false, target ) )
				{
					new_target = target;
					break;
				}
			}
		}
		
		self player_set_pass_target(new_target);
		
		WAIT_SERVER_FRAME();
	}
}

function play_return_vo()
{
	foreach( team in level.teams )
	{
		globallogic_audio::play_2d_on_team( "mpl_ballreturn_sting", team );
		
		globallogic_audio::leader_dialog( "uplReset", team, undefined, "uplink_ball" );
	}
}

function compare_player_pass_dot(left, right)
{
	return left.pass_dot>=right.pass_dot;
}

function player_set_pass_target(new_target)
{
	//No Change
	if ( IsDefined(self.pass_target) && IsDefined(new_target) && self.pass_target == new_target )
		return;
	
	if ( !IsDefined(self.pass_target) && !IsDefined(new_target) )
		return;
	
	self player_clear_pass_target();
	
	if(IsDefined(new_target))
	{
		offset = ( 0, 0, 80 );
	
		new_target clientfield::set( "passoption", 1 );
		self.pass_target = new_target;
		
		team_players = [];
		foreach(player in level.players)
		{
			if(player.team == self.team && player != self && player != new_target)
				team_players[team_players.size] = player;
		}
		
		self SetBallPassAllowed(true);
	}
}

function player_clear_pass_target()
{
	if(IsDefined(self.pass_icon))
		self.pass_icon Destroy();
	
	team_players = [];
	foreach(player in level.players)
	{
		if( player.team == self.team && player != self )
			team_players[team_players.size] = player;
	}
	
	if( isDefined( self.pass_target ) )
	{
		self.pass_target clientfield::set( "passoption", 0 );
	}
	self.pass_target = undefined;
	self SetBallPassAllowed(false);
}


function ball_create_start( minStartingBalls )
{
	ball_starts = getEntArray( "ball_start" ,"targetname");

	ball_starts = array::randomize( ball_starts );
	foreach(new_start in ball_starts)
	{
		ballAddStart(new_start.origin);
	}
	
	//Add a default start if none exist
	default_ball_height = 30;
	if( ball_starts.size==0 )
	{
		origin = level.default_ball_origin;
		if(!IsDefined(origin))
		{
			origin = (0,0,0);
		}

		ballAddStart(origin);
	}
	
	//Add extra default starts to support multi ball
	add_num = minStartingBalls - level.ball_starts.size;
	if( add_num <= 0 )
	{
		return;
	}
	
	default_start = level.ball_starts[0].origin;
	
	near_nodes = GetNodesInRadius(default_start, 200, 20, 50);
	near_nodes = array::randomize(near_nodes);
	
	for ( i = 0; i < add_num && i<near_nodes.size; i++ )
	{
		ballAddStart(near_nodes[i].origin);
	}
}

function ballAddStart(origin)
{
	ball_spawn_height = 30;
	
	new_start = SpawnStruct();
	new_start.origin = origin;
	new_start ballFindGround();
	new_start.origin = new_start.ground_origin + (0,0,ball_spawn_height);
	new_start.in_use = false;
	
	level.ball_starts[level.ball_starts.size] = new_start;
}

function ballFindGround(z_offset)
{
	traceStart 	= self.origin + (0,0,32);
	traceEnd 	= self.origin + (0,0,-1000);
	trace 		= bulletTrace( traceStart, traceEnd, false, undefined );

	self.ground_origin = trace["position"];
	
	return trace["fraction"] != 0 && trace["fraction"] != 1;
}

function play_goal_score_fx( )
{
	key = "ball_score_" + self.team;
	level clientfield::set( key, !(level clientfield::get( key )) );
}