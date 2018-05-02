#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_dev;
#using scripts\mp\gametypes\_globallogic_utils;

#using scripts\mp\_util;

#namespace gameadvertisement;

function init()
{
	level.gameAdvertisementRuleScorePercent = GetGametypeSetting( "gameAdvertisementRuleScorePercent" );
	level.gameAdvertisementRuleTimeLeft = ( 1000 * 60 ) * GetGametypeSetting( "gameAdvertisementRuleTimeLeft" );
	level.gameAdvertisementRuleRound = GetGametypeSetting( "gameAdvertisementRuleRound" );
	level.gameAdvertisementRuleRoundsWon = GetGametypeSetting( "gameAdvertisementRuleRoundsWon" );

	thread sessionAdvertisementCheck();
}


function setAdvertisedStatus( onOff )
{
	changeAdvertisedStatus( onOff );
}

function sessionAdvertisementCheck()
{
	if( SessionModeIsPrivate() )
		return;

	runRules = getGameTypeRules();

	if( !isdefined( runRules ) )
		return;
		
	level endon( "game_end" );
	
	level waittill( "prematch_over" );

	currentAdvertisedStatus = undefined;
	while( true )
	{
		sessionAdvertCheckwait = GetDvarInt( "sessionAdvertCheckwait", 1 );
		
		wait( sessionAdvertCheckwait );

		advertise = [[runRules]]();
		if ( !isdefined( currentAdvertisedStatus ) || ( isdefined( advertise ) && ( currentAdvertisedStatus != advertise ) ) )
		{
			setAdvertisedStatus( advertise );
		}
		currentAdvertisedStatus = advertise;
	}
}

function getGameTypeRules()
{
	gametype = level.gametype;

	switch( gametype )
	{
		case  "gun":
			return &gun_rules;
		default:
			return &default_rules;
	}

	return;
}

function teamScoreLimitCheck( ruleScorePercent )
{
	scoreLimit = 0;
	
	//====================================================================
	//	score check			
	
	if ( level.roundScoreLimit )
	{
		scoreLimit = util::get_current_round_score_limit();
	}
	else if ( level.scoreLimit )
	{
		scoreLimit = level.scoreLimit;
	}
	
	if ( scoreLimit )
	{
		minScorePercentageLeft = 100;

		foreach ( team in level.teams )
		{
			scorePercentageLeft = 100 - ( ( game[ "teamScores" ][ team ] / scoreLimit ) * 100 );

			if( minScorePercentageLeft > scorePercentageLeft )
				minScorePercentageLeft = scorePercentageLeft;

			if( ruleScorePercent >= scorePercentageLeft )
			{	
				return false;
			}
		}
	}
	

	return true;
}

function timeLimitCheck( ruleTimeLeft )
{
	maxTime = level.timeLimit;
		
	if( maxTime != 0 )
	{		
		timeLeft = globallogic_utils::getTimeRemaining();

		if( ruleTimeLeft >= timeLeft )
		{	
			return false;
		}
	}

	return true;
}

//========================================================================================================================================
//========================================================================================================================================
//========================================================================================================================================

function default_rules()
{

	//====================================================================
	
	currentRound = game[ "roundsplayed" ] + 1; 

	//====================================================================
	//	score check

	if( level.gameAdvertisementRuleScorePercent )
	{
		if ( level.teambased )
		{
			if ( (currentRound >= (level.gameAdvertisementRuleRound - 1)) )
			{
				if ( teamScoreLimitCheck( level.gameAdvertisementRuleScorePercent ) == false )
					return false;
			}
		}
		else
		{
			if ( level.scoreLimit )
			{
				highestScore = 0;
				players = GetPlayers();
		
				for( i = 0; i < players.size; i++)
				{
					if( players[i].pointstowin > highestScore )
						highestScore = players[i].pointstowin;
				}
		
				scorePercentageLeft = 100 - ( ( highestScore / level.scoreLimit ) * 100 );
		
				if( level.gameAdvertisementRuleScorePercent >= scorePercentageLeft )
				{	
					return false;
				}
			}
		}
	}
		
	//====================================================================
	//	time left check

	if( level.gameAdvertisementRuleTimeLeft && (currentRound >= (level.gameAdvertisementRuleRound - 1)) )
	{
		if ( timeLimitCheck( level.gameAdvertisementRuleTimeLeft ) == false )
			return false;
	}

	//====================================================================
	//	round check

	if( level.gameAdvertisementRuleRound )
	{
		if ( level.gameAdvertisementRuleRound <= currentRound )
			return false;
	}

	//====================================================================
	//	round won check

	if ( level.gameAdvertisementRuleRoundsWon )
	{
		maxRoundsWon = 0;
		foreach ( team in level.teams )
		{
			roundsWon = game[ "teamScores" ][ team ];
	
			if( maxRoundsWon < roundsWon )
				maxRoundsWon = roundsWon;
			
			if( level.gameAdvertisementRuleRoundsWon <= roundsWon )
			{	
				return false;
			}
		}
	}

	return true;
}

function gun_rules()
{
	// Any player is within 3 weapons from winning

	//====================================================================

	ruleWeaponsLeft = 3;						// within 3 weapons of winning

	//====================================================================

	//====================================================================
	//	weapons check
	minWeaponsLeft = level.gunProgression.size;
	
	foreach ( player in level.activePlayers )
	{
		if ( !isdefined( player ) )
			continue;

		if ( !isdefined( player.gunProgress ) )
			continue;

		weaponsLeft = level.gunProgression.size - player.gunProgress;
		
		if( minWeaponsLeft > weaponsLeft )
			minWeaponsLeft = weaponsLeft;
		
		if( ruleWeaponsLeft >= minWeaponsLeft )
		{
			return false;
		}
	}
	return true;
}

//========================================================================================================================================
//========================================================================================================================================
//========================================================================================================================================

