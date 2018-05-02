#using scripts\codescripts\struct;

#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\rank_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_spawnlogic;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreaks;

#namespace globallogic_defaults;

function getWinningTeamFromLoser( losing_team )
{
	if ( level.multiTeam )
	{
		return "tie";
	}
	return util::getotherteam(losing_team);
}

// when a team leaves completely, that team forfeited, team left wins round, ends game
function default_onForfeit( team )
{
	level.gameForfeited= true;
	
	level notify ( "forfeit in progress" ); //ends all other forfeit threads attempting to run
	level endon( "forfeit in progress" );	//end if another forfeit thread is running
	level endon( "abort forfeit" );			//end if the team is no longer in forfeit status
	
	forfeit_delay = 20.0;						//forfeit wait, for switching teams and such
	
	announcement( game["strings"]["opponent_forfeiting_in"], forfeit_delay, 0 );
	wait (10.0);
	announcement( game["strings"]["opponent_forfeiting_in"], 10.0, 0 );
	wait (10.0);
	
	endReason = &"";
	if ( level.multiTeam )
	{
		SetDvar( "ui_text_endreason", game["strings"]["other_teams_forfeited"] );
		endReason = game["strings"]["other_teams_forfeited"];
		winner = team;
	}
	else if ( !isdefined( team ) )
	{
		SetDvar( "ui_text_endreason", game["strings"]["players_forfeited"] );
		endReason = game["strings"]["players_forfeited"];
		winner = level.players[0];
	}
	else if ( isdefined( level.teams[team] ) )
	{
		endReason = game["strings"][team+"_forfeited"];
		SetDvar( "ui_text_endreason", endReason );
		winner = getWinningTeamFromLoser( team );
	}
	else
	{
		//shouldn't get here
		assert( isdefined( team ), "Forfeited team is not defined" );
		assert( 0, "Forfeited team " + team + " is not allies or axis" );
		winner = "tie";
	}
	//exit game, last round, no matter if round limit reached or not
	level.forcedEnd = true;
	/#
	if ( isPlayer( winner ) )
		print( "forfeit, win: " + winner getXuid() + "(" + winner.name + ")" );
	else
		globallogic_utils::logTeamWinString( "forfeit", winner );
	#/
	thread globallogic::endGame( winner, endReason );
}


function default_onDeadEvent( team )
{
	if ( isdefined( level.teams[team] ) )
	{
		eliminatedString = game["strings"][team + "_eliminated"];
		iPrintLn( eliminatedString );
		//makeDvarServerInfo( "ui_text_endreason", eliminatedString );
		SetDvar( "ui_text_endreason", eliminatedString );

		winner = getWinningTeamFromLoser( team );
		globallogic_utils::logTeamWinString( "team eliminated", winner );
		
		thread globallogic::endGame( winner, eliminatedString );
	}
	else
	{
		//makeDvarServerInfo( "ui_text_endreason", game["strings"]["tie"] );
		SetDvar( "ui_text_endreason", game["strings"]["tie"] );

		globallogic_utils::logTeamWinString( "tie" );

		if ( level.teamBased )
			thread globallogic::endGame( "tie", game["strings"]["tie"] );
		else
			thread globallogic::endGame( undefined, game["strings"]["tie"] );
	}
}

function default_onLastTeamAliveEvent( team )
{
	if ( isdefined( level.teams[team] ) )
	{
		eliminatedString = game["strings"]["enemies_eliminated"];
		iPrintLn( eliminatedString );
		//makeDvarServerInfo( "ui_text_endreason", eliminatedString );
		SetDvar( "ui_text_endreason", eliminatedString );

		winner = globallogic::determineTeamWinnerByGameStat( "teamScores" );
		globallogic_utils::logTeamWinString( "team eliminated", winner );
		
		thread globallogic::endGame( winner, eliminatedString );
	}
	else
	{
		//makeDvarServerInfo( "ui_text_endreason", game["strings"]["tie"] );
		SetDvar( "ui_text_endreason", game["strings"]["tie"] );

		globallogic_utils::logTeamWinString( "tie" );

		if ( level.teamBased )
			thread globallogic::endGame( "tie", game["strings"]["tie"] );
		else
			thread globallogic::endGame( undefined, game["strings"]["tie"] );
	}
}

function default_onAliveCountChange( team )
{
}

function default_onRoundEndGame( winner )
{
	return winner;
}

// T8 - We should get rid of the return from onRoundEndGame in favor of this
function default_determineWinner( roundWinner )
{
	if ( isdefined( game["overtime_round"] ) )
	{
		if ( IS_TRUE( level.doubleOvertime ) &&
		     isdefined( roundWinner ) &&
		     roundWinner != "tie" )
		{
			return roundWinner;
		}
		
		return globallogic::determineTeamWinnerByGameStat( "overtimeroundswon" );
	}

	if ( level.scoreRoundWinBased )
	{	
		winner = globallogic::determineTeamWinnerByGameStat( "roundswon" );
	}
	else
	{
		winner = globallogic::determineTeamWinnerByTeamScore();
	}
	
	return winner;
}

function default_onOneLeftEvent( team )
{
	if ( !level.teamBased )
	{
		winner = globallogic_score::getHighestScoringPlayer();
		/#
		if ( isdefined( winner ) )
			print( "last one alive, win: " + winner.name );
		else
			print( "last one alive, win: unknown" );
		#/
		thread globallogic::endGame( winner, &"MP_ENEMIES_ELIMINATED" );
	}
	else
	{
		for ( index = 0; index < level.players.size; index++ )
		{
			player = level.players[index];
			
			if ( !isAlive( player ) )
				continue;
				
			if ( !isdefined( player.pers["team"] ) || player.pers["team"] != team )
				continue;
				
			player globallogic_audio::leader_dialog_on_player( "sudden_death" );
		}
	}
}


function default_onTimeLimit()
{
	winner = undefined;
	
	if ( level.teamBased )
	{
		winner = globallogic::determineTeamWinnerByGameStat( "teamScores" );

		globallogic_utils::logTeamWinString( "time limit", winner );
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
	
	// i think these two lines are obsolete
	//makeDvarServerInfo( "ui_text_endreason", game["strings"]["time_limit_reached"] );
	SetDvar( "ui_text_endreason", game["strings"]["time_limit_reached"] );
	
	thread globallogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

function default_onScoreLimit()
{
	if ( !level.endGameOnScoreLimit )
		return false;

	winner = undefined;
	
	if ( level.teamBased )
	{
		winner = globallogic::determineTeamWinnerByGameStat( "teamScores" );

		globallogic_utils::logTeamWinString( "scorelimit", winner );
	}
	else
	{
		winner = globallogic_score::getHighestScoringPlayer();
		/#
		if ( isdefined( winner ) )
			print( "scorelimit, win: " + winner.name );
		else
			print( "scorelimit, tie" );
		#/
	}
	
	//makeDvarServerInfo( "ui_text_endreason", game["strings"]["score_limit_reached"] );
	SetDvar( "ui_text_endreason", game["strings"]["score_limit_reached"] );
	
	thread globallogic::endGame( winner, game["strings"]["score_limit_reached"] );
	return true;
}


function default_onRoundScoreLimit()
{
	winner = undefined;
	
	if ( level.teamBased )
	{
		winner = globallogic::determineTeamWinnerByGameStat( "teamScores" );

		globallogic_utils::logTeamWinString( "roundscorelimit", winner );
	}
	else
	{
		winner = globallogic_score::getHighestScoringPlayer();
		/#
		if ( isdefined( winner ) )
			print( "roundscorelimit, win: " + winner.name );
		else
			print( "roundscorelimit, tie" );
		#/
	}
	
	//makeDvarServerInfo( "ui_text_endreason", game["strings"]["round_score_limit_reached"] );
	SetDvar( "ui_text_endreason", game["strings"]["round_score_limit_reached"] );
	
	thread globallogic::endGame( winner, game["strings"]["round_score_limit_reached"] );
	return true;
}


function default_onSpawnSpectator( origin, angles)
{
	if( isdefined( origin ) && isdefined( angles ) )
	{
		self spawn(origin, angles);
		return;
	}
	
	spawnpoints = spawnlogic::_get_spawnpoint_array( "mp_global_intermission" );
	assert( spawnpoints.size, "There are no mp_global_intermission spawn points in the map.  There must be at least one."  );
	spawnpoint = spawnlogic::get_spawnpoint_random(spawnpoints);

	self spawn(spawnpoint.origin, spawnpoint.angles);
}

function default_onSpawnIntermission( endGame )
{
	if ( IS_TRUE( endGame ) )
	{
		// The client camera is handled in client script via an xcam
		return; 
	}
	
	spawnpoint = spawnlogic::get_random_intermission_point();
	
	if( isdefined( spawnpoint ) )
	{
		self spawn( spawnpoint.origin, spawnpoint.angles );
	}
	else
	{
		/#
		println( "NO mp_global_intermission SPAWNPOINTS IN MAP" );
		#/
	}
}

function default_getTimeLimit()
{
	return math::clamp( GetGametypeSetting( "timeLimit" ), level.timeLimitMin, level.timeLimitMax );
}

function default_getTeamKillPenalty( eInflictor, attacker, sMeansOfDeath, weapon )
{
	teamkill_penalty = 1;
	
	if ( killstreaks::is_killstreak_weapon( weapon ) )
	{
		teamkill_penalty *= killstreaks::get_killstreak_team_kill_penalty_scale( weapon );
	}
	
	return teamkill_penalty;
}

function default_getTeamKillScore( eInflictor, attacker, sMeansOfDeath, weapon )
{
	return rank::getScoreInfoValue( "team_kill" );
}


