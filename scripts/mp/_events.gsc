#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic_utils;

#using scripts\mp\_util;

#namespace events;

/*------------------------------------
Adds an event based on the current value of the gametypes timer
------------------------------------*/
function add_timed_event( seconds, notify_string, client_notify_string )
{
	assert( seconds >= 0 );

	if ( level.timelimit > 0 )
	{
		level thread timed_event_monitor( seconds, notify_string, client_notify_string );
	}
}


/*------------------------------------
checks the game/level timer for timed events 
------------------------------------*/
function timed_event_monitor( seconds, notify_string, client_notify_string )
{
	for ( ;; )
	{
		wait( 0.5 );
		
		if( !isdefined( level.startTime ) )
		{
			continue;
		}
		
		//get the time remaining and see if events need to be fired off
		millisecs_remaining =  globallogic_utils::getTimeRemaining();
		seconds_remaining = millisecs_remaining / 1000;

		if( seconds_remaining <= seconds )
		{
			event_notify( notify_string, client_notify_string );
			return;
		}
	}
}


function add_score_event( score, notify_string, client_notify_string )
{
	assert( score >= 0 );

	if ( level.scoreLimit > 0 )
	{
		if ( level.teamBased )
		{
			level thread score_team_event_monitor( score, notify_string, client_notify_string );
		}
		else
		{
			level thread score_event_monitor( score, notify_string, client_notify_string );
		}
	}
}

function add_round_score_event( score, notify_string, client_notify_string )
{
	assert( score >= 0 );

	if ( level.roundScoreLimit > 0 )
	{
		roundScoreToBeat = ( level.roundScoreLimit * game[ "roundsplayed" ] ) + score;
		if ( level.teamBased )
		{
			level thread score_team_event_monitor( roundScoreToBeat, notify_string, client_notify_string );
		}
		else
		{
			level thread score_event_monitor( roundScoreToBeat, notify_string, client_notify_string );
		}
	}
}

function any_team_reach_score( score )
{
	foreach( team in level.teams )
	{
		if ( game["teamScores"][team] >= score )
			return true;
	}
	
	return false;
}

function score_team_event_monitor( score, notify_string, client_notify_string )
{
	for ( ;; )
	{
		wait( 0.5 );

		if ( any_team_reach_score( score ) )
		{
			event_notify( notify_string, client_notify_string );
			return;
		}
	}
}


function score_event_monitor( score, notify_string, client_notify_string )
{
	for ( ;; )
	{
		wait ( 0.5 );

		players = GetPlayers();

		for ( i = 0; i < players.size; i++ )
		{
			if ( isdefined( players[i].score ) && players[i].score >= score )
			{
				event_notify( notify_string, client_notify_string );
				return;
			}
		}
	}
}


function event_notify( notify_string, client_notify_string )
{
	if ( isdefined( notify_string ) )
	{
		level notify( notify_string );
	}

	if ( isdefined( client_notify_string ) )
	{
		util::clientNotify( client_notify_string );
	}
}

