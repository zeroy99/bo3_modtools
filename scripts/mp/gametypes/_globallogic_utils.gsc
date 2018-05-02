#using scripts\codescripts\struct;

#using scripts\shared\hostmigration_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\killstreaks_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_hud_message;

#using scripts\mp\killstreaks\_killstreaks;

#namespace globallogic_utils;

function testMenu()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	for ( ;; )
	{
		wait ( 10.0 );
		
		notifyData = spawnStruct();
		notifyData.titleText = &"MP_CHALLENGE_COMPLETED";
		notifyData.notifyText = "wheee";
		notifyData.sound = "mp_challenge_complete";

		self thread hud_message::notifyMessage( notifyData );
	}
}

function testShock()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	for ( ;; )
	{
		wait ( 3.0 );

		numShots = randomInt( 6 );
		
		for ( i = 0; i < numShots; i++ )
		{
			iPrintLnBold( numShots );
			self shellShock( "frag_grenade_mp", 0.2 );
			wait ( 0.1 );
		}
	}
}

function testHPs()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	hps = [];
	hps[hps.size] = "radar";
	hps[hps.size] = "artillery";
	hps[hps.size] = "dogs";

	for ( ;; )
	{
		hp = "radar";
		if ( self thread killstreaks::give( hp ) )
		{
			self playLocalSound( level.killstreaks[hp].informDialog );
		}

		wait ( 20.0 );
	}
}


// returns the best guess of the exact time until the scoreboard will be displayed and player control will be lost.
// returns undefined if time is not known
function timeUntilRoundEnd()
{
	if ( level.gameEnded )
	{
		timePassed = (getTime() - level.gameEndTime) / 1000;
		timeRemaining = level.postRoundTime - timePassed;
		
		if ( timeRemaining < 0 )
			return 0;
		
		return timeRemaining;
	}
	
	if ( level.inOvertime )
		return undefined;
	
	if ( level.timeLimit <= 0 )
		return undefined;
	
	if ( !isdefined( level.startTime ) )
		return undefined;
	
	timePassed = (getTimePassed() - level.startTime)/1000;
	timeRemaining = (level.timeLimit * 60) - timePassed;
	
	return timeRemaining + level.postRoundTime;
}


function getTimeRemaining()
{
	return level.timeLimit * 60 * 1000 - getTimePassed();
}

function registerPostRoundEvent( eventFunc )
{
	if ( !isdefined( level.postRoundEvents ) )
		level.postRoundEvents = [];
	
	level.postRoundEvents[level.postRoundEvents.size] = eventFunc;
}

function executePostRoundEvents()
{
	if ( !isdefined( level.postRoundEvents ) )
		return;
		
	for ( i = 0 ; i < level.postRoundEvents.size ; i++ )
	{
		[[level.postRoundEvents[i]]]();
	}
}

function getValueInRange( value, minValue, maxValue )
{
	if ( value > maxValue )
		return maxValue;
	else if ( value < minValue )
		return minValue;
	else
		return value;
}


function isValidClass( c )
{
	if ( SessionModeIsZombiesGame() )
	{
		assert( !isdefined( c ) );
		return true;
	}
	return isdefined( c ) && c != "";
}


function playTickingSound( gametype_tick_sound )
{
	self endon("death");
	self endon("stop_ticking");
	level endon("game_ended");
	
	time = level.bombTimer;
	
	while(1)
	{
		self playSound( gametype_tick_sound );
		
		if ( time > 10 )
		{
			time -= 1;
			wait 1;
		}
		else if ( time > 4 )
		{
			time -= .5;
			wait .5;
		}
		else if ( time > 1 )
		{
			time -= .4;
			wait .4;
		}
		else
		{
			time -= .3;
			wait .3;
		}
		hostmigration::waitTillHostMigrationDone();
	}
}

function stopTickingSound()
{
	self notify("stop_ticking");
}

function gameTimer()
{
	level endon ( "game_ended" );
	
	level waittill("prematch_over");
	
	level.startTime = getTime();
	level.discardTime = 0;
	
	if ( isdefined( game["roundMillisecondsAlreadyPassed"] ) )
	{
		level.startTime -= game["roundMillisecondsAlreadyPassed"];
		game["roundMillisecondsAlreadyPassed"] = undefined;
	}
	
	prevtime = gettime() - 1000; // need to subtract a second the first time prevtime is set
	
	while ( game["state"] == "playing" )
	{
		if ( !level.timerStopped )
		{
			// the wait isn't always exactly 1 second. dunno why.
			game["timepassed"] += gettime() - prevtime;
		}
		if ( !level.playableTimerStopped )
		{
			game["playabletimepassed"] += gettime() - prevtime;
		}
		prevtime = gettime();
		wait ( 1.0 );
	}
}

function DisablePlayerRoundStartDelay()
{
	player = self;
	
	player endon( "death" );
	player endon( "disconnect" );
	
	if( GetRoundStartDelay() )
	{
		wait( GetRoundStartDelay() );
	}
	
	player DisableRoundStartDelay();
}

function GetRoundStartDelay()
{
	waitTime = level.roundStartExplosiveDelay - ([[level.getTimePassed]]() / 1000);
 	if( waitTime > 0 )
 	{
 		return waitTime;
 	}
 	
 	return 0;
}

function ApplyRoundStartDelay()
{
	self endon("disconnect");
	self endon("joined_spectators");
	self endon("death");
	
	if( isDefined( level.prematch_over ) && level.prematch_over )
	{
		WAIT_SERVER_FRAME; // Delay one frame because the ps->weapFlags are geting cleared on spawn
	}
	else
	{
		level waittill("prematch_over");
	}
		
	self EnableRoundStartDelay();
	self thread globallogic_utils::DisablePlayerRoundStartDelay();
}

function getTimePassed()
{
	if ( !isdefined( level.startTime ) )
		return 0;
	
	if ( level.timerStopped )
		return (level.timerPauseTime - level.startTime) - level.discardTime;
	else
		return (gettime()            - level.startTime) - level.discardTime;

}


function pauseTimer( pausePlayableTimer = false )
{
	level.playableTimerStopped = pausePlayableTimer;

	if ( level.timerStopped )
		return;
	
	level.timerStopped = true;
	level.timerPauseTime = gettime();
}


function resumeTimer()
{	
	if ( !level.timerStopped )
		return;
	
	level.timerStopped = false;
	level.playableTimerStopped = false;
	level.discardTime += gettime() - level.timerPauseTime;
}

function resumeTimerDiscardOverride( discardTime )
{	
	if ( !level.timerStopped )
		return;
	
	level.timerStopped = false;
	level.discardTime = discardTime;
}

function getScoreRemaining( team )
{
	assert( IsPlayer( self ) || isdefined( team ) );
	
	scoreLimit = level.scoreLimit;
	
	if ( IsPlayer( self ) )
		return scoreLimit - globallogic_score::_getPlayerScore( self );
	else
		return scoreLimit - GetTeamScore( team );
}

function GetTeamScoreForRound( team )
{
	if ( level.cumulativeRoundScores && isdefined( game["lastroundscore"][team] ) )
	{
		return GetTeamScore( team ) - game["lastroundscore"][team];
	}
	
	return GetTeamScore( team );
}

function getScorePerMinute( team )
{
	assert( IsPlayer( self ) || isdefined( team ) );
	
	minutesPassed = ( getTimePassed() / ( 60 * 1000 ) ) + 0.0001;
	
	if ( IsPlayer( self ) )
		return globallogic_score::_getPlayerScore( self ) / minutesPassed;
	else
		return GetTeamScoreForRound( team ) / minutesPassed;
}


function getEstimatedTimeUntilScoreLimit( team )
{
	assert( IsPlayer( self ) || isdefined( team ) );
	
	scorePerMinute = self getScorePerMinute( team );
	scoreRemaining = self getScoreRemaining( team );
	
	if ( !scorePerMinute )
		return 999999;
	
	return scoreRemaining / scorePerMinute;
}


function rumbler()
{
	self endon("disconnect");
	while(1)
	{
		wait(0.1);
		self PlayRumbleOnEntity( "damage_heavy" );
	}
}


function waitForTimeOrNotify( time, notifyname )
{
	self endon( notifyname );
	wait time;
}


function waitForTimeOrNotifyNoArtillery( time, notifyname )
{
	self endon( notifyname );
	wait time;
	while( isdefined( level.artilleryInProgress ) )
	{
		assert( level.artilleryInProgress ); // undefined or true
		wait .25;
	}
}


function isHeadShot( weapon, sHitLoc, sMeansOfDeath, eInflictor )
{
	if( sHitLoc != "head" && sHitLoc != "helmet" )
	{
		return false;
	}

	switch( sMeansOfDeath )
	{
	case "MOD_MELEE":
	case "MOD_MELEE_ASSASSINATE":
		return false;
	case "MOD_IMPACT":
	   if( weapon.rootWeapon != level.weaponBallisticKnife )
			return false;
	}

	if ( killstreaks::is_killstreak_weapon( weapon )  ) 
	{
		if ( !isdefined( eInflictor ) || !isdefined( eInflictor.controlled ) || eInflictor.controlled  == false )
		{
			return false;
		}
	}

	return true;
}


function getHitLocHeight( sHitLoc )
{
	switch( sHitLoc )
	{
		case "helmet":
		case "head":
		case "neck":
			return 60;
		case "torso_upper":
		case "right_arm_upper":
		case "left_arm_upper":
		case "right_arm_lower":
		case "left_arm_lower":
		case "right_hand":
		case "left_hand":
		case "gun":
			return 48;
		case "torso_lower":
			return 40;
		case "right_leg_upper":
		case "left_leg_upper":
			return 32;
		case "right_leg_lower":
		case "left_leg_lower":
			return 10;
		case "right_foot":
		case "left_foot":
			return 5;
	}
	return 48;
}

function debugLine( start, end )
{
	/#
	for ( i = 0; i < 50; i++ )
	{
		line( start, end );
		wait .05;
	}
	#/
}


function isExcluded( entity, entityList )
{
	for ( index = 0; index < entityList.size; index++ )
	{
		if ( entity == entityList[index] )
			return true;
	}
	return false;
}


function waitForTimeOrNotifies( desiredDelay )
{
	startedWaiting = getTime();
	
	waitedTime = (getTime() - startedWaiting)/1000;
	
	if ( waitedTime < desiredDelay )
	{
		wait desiredDelay - waitedTime;
		return desiredDelay;
	}
	else
	{
		return waitedTime;
	}
}

function logTeamWinString( wintype, winner )
{
	/#
	log_string = wintype;
		
	if( isdefined( winner ) )
	{
		log_string = log_string +  ", win: " + winner;
	}
		
	foreach ( team in level.teams )
	{
		log_string = log_string + ", " + team + ": " + game["teamScores"][team];
	}
		
	print( log_string );
	#/
}

