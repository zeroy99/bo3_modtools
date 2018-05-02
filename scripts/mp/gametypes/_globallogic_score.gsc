#using scripts\shared\bb_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\persistence_shared;
#using scripts\shared\rank_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_util;

#using scripts\shared\bots\_bot;

#insert scripts\mp\_contracts.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_loadout;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_wager;

#using scripts\mp\_challenges;
#using scripts\mp\_scoreevents;
#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreak_weapons;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_counteruav;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\_teamops;

#precache( "eventstring", "track_victim_death" );
#precache( "string", "SCORE_BLANK" );

#namespace globallogic_score;

function updateMatchBonusScores( winner )
{
	if ( !game["timepassed"] )
	{
		return;
	}
	if ( !level.rankedMatch )
	{
		updateCustomGameWinner( winner );
		return;
	}
	// dont give the bonus until the game is over
	if ( level.teamBased && isdefined( winner ) )
	{
		if ( winner == "endregulation" )
			return;
	}

	if ( !level.timeLimit || level.forcedEnd )
	{
		gameLength = globallogic_utils::getTimePassed() / 1000;		
		// cap it at 20 minutes to avoid exploiting
		gameLength = min( gameLength, 1200 );

		// the bonus for final fight needs to be based on the total time played
		if ( level.gameType == "twar" && game["roundsplayed"] > 0 )
			gameLength += level.timeLimit * 60;
	}
	else
	{
		gameLength = level.timeLimit * 60;
	}

	if ( level.teamBased )
	{
		winningTeam = "tie";
		
		// TODO MTEAM - not sure if this is absolutely necessary but I dont know
		// if "winner" is anything other then a valid team or "tie" at this point
		foreach ( team in level.teams )
		{
			if ( winner == team )
			{
				winningTeam = team;
				break;
			}
		}

		if ( winningTeam != "tie" )
		{
			winnerScale = 1.0;
			loserScale = 0.5;
		}
		else
		{
			winnerScale = 0.75;
			loserScale = 0.75;
		}
		
		players = level.players;
		for( i = 0; i < players.size; i++ )
		{
			player = players[i];
			
			if ( player.timePlayed["total"] < 1 || player.pers["participation"] < 1 )
			{
				player thread rank::endGameUpdate();
				continue;
			}
	
			totalTimePlayed = player.timePlayed["total"];
			
			// make sure the players total time played is no 
			// longer then the game length to prevent exploits
			if ( totalTimePlayed > gameLength )
			{
				totalTimePlayed = gameLength;
			}
			
			// no bonus for hosts who force ends
			if ( level.hostForcedEnd && player IsHost() )
				continue;

			// no match bonus if negative game score
			if ( player.pers["score"] < 0 )
				continue;
				
			spm = player rank::getSPM();				
			if ( winningTeam == "tie" )
			{
				playerScore = int( (winnerScale * ((gameLength/60) * spm)) * (totalTimePlayed / gameLength) );
				player thread giveMatchBonus( "tie", playerScore );
				player.matchBonus = playerScore;
			}
			else if ( isdefined( player.pers["team"] ) && player.pers["team"] == winningTeam )
			{
				playerScore = int( (winnerScale * ((gameLength/60) * spm)) * (totalTimePlayed / gameLength) );
				player thread giveMatchBonus( "win", playerScore );
				player.matchBonus = playerScore;
			}
			else if ( isdefined(player.pers["team"] ) && player.pers["team"] != "spectator" )
			{
				playerScore = int( (loserScale * ((gameLength/60) * spm)) * (totalTimePlayed / gameLength) );
				player thread giveMatchBonus( "loss", playerScore );
				player.matchBonus = playerScore;
			}
			player.pers["totalMatchBonus"] += player.matchBonus;
		}
	}
	else
	{
		if ( isdefined( winner ) )
		{
			winnerScale = 1.0; // win
			loserScale = 0.5; // loss
		}
		else
		{
			winnerScale = 0.75; // tie
			loserScale = 0.75; // tie
		}
		
		players = level.players;
		for( i = 0; i < players.size; i++ )
		{
			player = players[i];
			
			if ( player.timePlayed["total"] < 1 || player.pers["participation"] < 1 )
			{
				player thread rank::endGameUpdate();
				continue;
			}
			
			totalTimePlayed = player.timePlayed["total"];
			
			// make sure the players total time played is no 
			// longer then the game length to prevent exploits
			if ( totalTimePlayed > gameLength )
			{
				totalTimePlayed = gameLength;
			}
			
			spm = player rank::getSPM();

			isWinner = false;
			for ( pIdx = 0; pIdx < min( level.placement["all"][0].size, 3 ); pIdx++ )
			{
				if ( level.placement["all"][pIdx] != player )
					continue;
				isWinner = true;				
			}
			
			if ( isWinner )
			{
				playerScore = int( (winnerScale * ((gameLength/60) * spm)) * (totalTimePlayed / gameLength) );
				player thread giveMatchBonus( "win", playerScore );
				player.matchBonus = playerScore;
			}
			else
			{
				playerScore = int( (loserScale * ((gameLength/60) * spm)) * (totalTimePlayed / gameLength) );
				player thread giveMatchBonus( "loss", playerScore );
				player.matchBonus = playerScore;
			}
			player.pers["totalMatchBonus"] += player.matchBonus;
		}
	}
}

function updateCustomGameWinner( winner )
{
	if( !level.mpCustomMatch )
	{
		return;
	}
	
	for( i = 0; i < level.players.size; i++ )
	{
		player = level.players[i];
		
		if ( !IsDefined( winner ) )
		{
			player.pers["victory"] = 0;
		}
		else if ( level.teambased )
		{
			if( player.team == winner )
			{
				player.pers["victory"] = 2;
			}
			else if( winner == "tie")
			{
				player.pers["victory"] = 1;
			}
			else
			{
				player.pers["victory"] = 0;
			}
		}
		else
		{
			isWinner = false;
			for ( pIdx = 0; pIdx < min( level.placement["all"].size, 3 ); pIdx++ )
			{
				if ( level.placement["all"][pIdx] != player )
					continue;
				isWinner = true;
			}

			if( isWinner )
			{
				player.pers["victory"] = 2;
			}
			else
			{
				player.pers["victory"] = 0;
			}
		}
		
		player.victory = player.pers["victory"];
		player.pers["sbtimeplayed"] = player.timeplayed["total"];
		player.sbtimeplayed = player.pers["sbtimeplayed"];
	}
}

function giveMatchBonus( scoreType, score )
{
	self endon ( "disconnect" );

	level waittill ( "give_match_bonus" );
	
	if ( scoreevents::shouldAddRankXP( self ) )
	{
		self AddRankXPValue( scoreType, score );
	}
	
	self rank::endGameUpdate();
}

function getHighestScoringPlayer()
{
	players = level.players;
	winner = undefined;
	tie = false;
	
	for( i = 0; i < players.size; i++ )
	{
		if ( !isdefined( players[i].pointstowin ) )
			continue;
			
		if ( players[i].pointstowin < 1 )
			continue;
			
		if ( !isdefined( winner ) || players[i].pointstowin > winner.pointstowin )
		{
			winner = players[i];
			tie = false;
		}
		else if ( players[i].pointstowin == winner.pointstowin )
		{
			tie = true;
		}
	}
	
	if ( tie || !isdefined( winner ) )
		return undefined;
	else
		return winner;
}

function resetPlayerScoreChainAndMomentum( player )
{
	player thread _setPlayerMomentum( self, 0 );
	player thread resetScoreChain();
}

function resetScoreChain()
{
	self notify( "reset_score_chain" );
	
	//self LUINotifyEvent( &"score_event", 3, 0, 0, 0 );
	self.scoreChain = 0;
	self.rankUpdateTotal = 0;
}

function scoreChainTimer()
{
	self notify( "score_chain_timer" );
	self endon( "reset_score_chain" );
	self endon( "score_chain_timer" );
	self endon( "death" );
	self endon( "disconnect" );
	
	wait 20;
	
	self thread resetScoreChain();
}

function roundToNearestFive( score )
{
	rounding = score % 5;
	if ( rounding <= 2 )
	{
		return score - rounding;
	}
	else
	{
		return score + ( 5 - rounding );
	}
}

function givePlayerMomentumNotification( score, label, descValue, countsTowardRampage, weapon, combatEfficiencyBonus )
{
	if( !isDefined( combatEfficiencyBonus ) )
		combatEfficiencyBonus = 0;
	
	score = score + combatEfficiencyBonus;
	
	if ( score != 0 )
	{
		self LUINotifyEvent( &"score_event", 3, label, score, combatEfficiencyBonus );
		self LUINotifyEventToSpectators( &"score_event", 3, label, score, combatEfficiencyBonus );
	}

	score = score;
	
	if ( ( score > 0 ) && self HasPerk( "specialty_earnmoremomentum" ) ) 
	{ 
		score = roundToNearestFive( int( score * GetDvarFloat( "perk_killstreakMomentumMultiplier" ) + 0.5 ) ); 
	}	

	if ( IsAlive( self ) )
	{
		_setPlayerMomentum( self, self.pers["momentum"] + score );
	}
}

function resetPlayerMomentumOnSpawn()
{
	if ( isdefined( level.usingScoreStreaks ) && level.usingScoreStreaks )
	{
		_setPlayerMomentum( self, 0 );
		self thread resetScoreChain();
	}
}

function givePlayerMomentum( event, player, victim, descValue, weapon )
{
	if( isdefined(level.disableMomentum) && (level.disableMomentum==true) )
		return;
	
	score = rank::getScoreInfoValue( event );
	assert( isdefined( score ) );
	label = rank::getScoreInfoLabel( event );
	countsTowardRampage = rank::doesScoreInfoCountTowardRampage( event );

	combatEfficiencyEvent = rank::getCombatEfficiencyEvent( event );
	if( IsDefined( combatefficiencyevent ) && ( player ability_util::gadget_combat_efficiency_enabled() ) )
	{
		combatEfficiencyScore = rank::getScoreInfoValue( combatEfficiencyEvent );
		assert( isdefined( combatEfficiencyScore ) );
		player ability_util::gadget_combat_efficiency_power_drain( combatEfficiencyScore );
	}
	
	if ( event == "death" )
	{
		_setPlayerMomentum( victim, victim.pers["momentum"] + score );
	}
		
	if ( score == 0 )
	{
		return;
	}
	
	if ( level.gameEnded  )
	{
		return;
	}
	
	if ( !isdefined( label ) )
	{
/#
		errormsg( event + " score string is undefined, you need to add a string to the scoreinfo.csv table when you add a non zero score" );
#/
		player givePlayerMomentumNotification( score, &"SCORE_BLANK", descValue, countsTowardRampage, weapon, combatEfficiencyScore );
		return;
	}
	
	player givePlayerMomentumNotification( score, label, descValue, countsTowardRampage, weapon, combatEfficiencyScore );
}

function givePlayerScore( event, player, victim, descValue, weapon )
{
	scoreDiff = 0;
	momentum = player.pers["momentum"];
	givePlayerMomentum( event, player, victim, descValue, weapon );
	newMomentum = player.pers["momentum"];

	if ( level.overridePlayerScore )
		return 0;

	score = player.pers["score"];
	[[level.onPlayerScore]]( event, player, victim );
	newScore = player.pers["score"];	
	
	isusingheropower = 0;
	if ( player ability_player::is_using_any_gadget() )
		isusingheropower = 1;


	if ( score == newScore )
		return 0;
		
	recordPlayerStats( player, "score", newScore );
	
	scoreDiff = (newScore - score);

	challengesEnabled = !level.disableChallenges;
	
	player AddPlayerStatWithGameType( "score", scoreDiff );
	if ( challengesEnabled )
	{
		player AddPlayerStat( "CAREER_SCORE", scoreDiff );
	}
	
	if ( level.hardcoreMode )
	{
		player AddPlayerStat( "SCORE_HC", scoreDiff );
		if ( challengesEnabled )
		{
			player AddPlayerStat( "CAREER_SCORE_HC", scoreDiff );
		}
	}
	if ( level.multiTeam )
	{
		player AddPlayerStat( "SCORE_MULTITEAM", scoreDiff );
		if ( challengesEnabled )
		{
			player AddPlayerStat( "CAREER_SCORE_MULTITEAM", scoreDiff );
		}		
	}
	if ( !level.disableStatTracking && isdefined( player.pers["lastHighestScore"] ) && newScore > player.pers["lastHighestScore"] )
	{
		player setDStat( "HighestStats", "highest_score", newScore );
	}

	player persistence::add_recent_stat( false, 0, "score", scoreDiff );

	player util::player_contract_event( "score", scoreDiff );
	
	if ( isdefined( weapon ) && killstreaks::is_killstreak_weapon( weapon ) )
	{
		killstreak = killstreaks::get_from_weapon( weapon );
		killstreakPurchased = false;
		if ( isdefined( killstreak ) && isdefined( level.killstreaks[ killstreak ] ) )
		{
			killstreakPurchased = player util::is_item_purchased( level.killstreaks[ killstreak ].menuname );
		}
		player util::player_contract_event( "killstreak_score", scoreDiff, killstreakPurchased );
	}

	return scoreDiff;
}

function default_onPlayerScore( event, player, victim )
{
	score = rank::getScoreInfoValue( event );

	assert( isdefined( score ) );
	
	if ( level.wagerMatch )
	{
		player thread rank::updateRankScoreHUD( score );
	}
	
	_setPlayerScore( player, player.pers["score"] + score );
}


function _setPlayerScore( player, score )
{
	if ( score == player.pers["score"] )
		return;

	if ( !level.rankedMatch )
	{
		player thread rank::updateRankScoreHUD( score - player.pers["score"] );
	}

	player.pers["score"] = score;
	player.score = player.pers["score"];
	recordPlayerStats( player, "score" , player.pers["score"] );

	if ( level.wagerMatch )
		player thread wager::player_scored();
}


function _getPlayerScore( player )
{
	return player.pers["score"];
}

function playTop3Sounds()
{
	WAIT_SERVER_FRAME; // Let other simultaneous sounds play first
	
	globallogic::updatePlacement();
	for ( i = 0 ; i < level.placement["all"].size ; i++ )
	{
		prevScorePlace = level.placement["all"][i].prevScorePlace;
		if ( !isdefined( prevScorePlace ) )
			prevScorePlace = 1;
		currentScorePlace = i + 1;
		for ( j = i - 1 ; j >= 0 ; j-- )
		{
			if ( level.placement["all"][i].score == level.placement["all"][j].score )
				currentScorePlace--;
		}
		wasInTheMoney = ( prevScorePlace <= 3 );
		isInTheMoney = ( currentScorePlace <= 3 );
		
		level.placement["all"][i].prevScorePlace = currentScorePlace;
	}
}

function setPointsToWin( points )
{
	self.pers["pointstowin"] = math::clamp( points, 0, 65000 );
	self.pointstowin = self.pers["pointstowin"];
	self thread globallogic::checkScoreLimit();
	self thread globallogic::checkRoundScoreLimit();
	self thread globallogic::checkPlayerScoreLimitSoon();
	level thread playTop3Sounds();
}

function givePointsToWin( points )
{
	self setPointsToWin( self.pers["pointstowin"] + points );
}


#define MAX_MOMENTUM 2000

function _setPlayerMomentum( player, momentum, updateScore = true )
{
	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		return;
	
	momentum = math::clamp( momentum, 0, MAX_MOMENTUM );

	oldMomentum = player.pers["momentum"];
	if ( momentum == oldMomentum )
		return;
	
	if ( momentum > oldMomentum )
	{
		highestMomentumCost = 0;
		numKillstreaks = 0;
		if ( isdefined( player.killstreak ) )
		{
			numKillstreaks = player.killstreak.size;
		}
		killStreakTypeArray = [];
		
		for ( currentKillstreak = 0 ; currentKillstreak < numKillstreaks ; currentKillstreak++ )
		{	
			killstreakType = killstreaks::get_by_menu_name( player.killstreak[ currentKillstreak ] );
			if ( isdefined( killstreakType ) )
			{
				momentumCost = level.killstreaks[killstreakType].momentumCost;
				if ( momentumCost > highestMomentumCost ) 
				{
					highestMomentumCost = momentumCost;
				}
				killStreakTypeArray[killStreakTypeArray.size] = killstreakType;
			}
		}
		
		_givePlayerKillstreakInternal( player, momentum, oldMomentum, killStreakTypeArray );
		
		while ( highestMomentumCost > 0 && momentum >= highestMomentumCost )
		{
			oldMomentum = 0;
			momentum = momentum - highestMomentumCost;
			_givePlayerKillstreakInternal( player, momentum, oldMomentum, killStreakTypeArray );
		}
	}
		
	player.pers["momentum"] = momentum;
	player.momentum = player.pers["momentum"];
}

function _givePlayerKillstreakInternal( player, momentum, oldMomentum, killStreakTypeArray )
{
	for ( killstreakTypeIndex = 0 ; killstreakTypeIndex < killStreakTypeArray.size; killstreakTypeIndex++ )
	{
		killstreakType = killStreakTypeArray[killstreakTypeIndex];
		
		momentumCost = level.killstreaks[killstreakType].momentumCost;
		if ( momentumCost > oldMomentum && momentumCost <= momentum )
		{
			
			weapon = killstreaks::get_killstreak_weapon( killstreakType );
			was_already_at_max_stacking = false;
			if ( IS_TRUE( level.usingScoreStreaks ) )
			{
				if( weapon.isCarriedKillstreak )
				{
					if( !isdefined( player.pers["held_killstreak_ammo_count"][weapon] ) )
						player.pers["held_killstreak_ammo_count"][weapon] = 0;

					if( !isdefined( player.pers["killstreak_quantity"][weapon] ) )
						player.pers["killstreak_quantity"][weapon] = 0;

					currentWeapon = player getCurrentWeapon();

					//If the player is currently using the killstreak weapon, allow them to finish using it before replacing it otherwise give them max ammo
					if( currentWeapon == weapon )
					{
						if( player.pers["killstreak_quantity"][weapon] < level.scoreStreaksMaxStacking )
							player.pers["killstreak_quantity"][weapon]++;
					}
					else
					{
						player.pers["held_killstreak_clip_count"][weapon] = weapon.clipSize;
						player.pers["held_killstreak_ammo_count"][weapon] = weapon.maxAmmo;
						player loadout::setWeaponAmmoOverall( weapon, player.pers["held_killstreak_ammo_count"][weapon] );
					}
				}
				else
				{
					
					old_killstreak_quantity = player killstreaks::get_killstreak_quantity( weapon );
					new_killstreak_quantity = player killstreaks::change_killstreak_quantity( weapon, 1 );
					was_already_at_max_stacking = ( new_killstreak_quantity == old_killstreak_quantity );
					
					if ( !was_already_at_max_stacking )
					{
						player challenges::earnedKillstreak();
						if ( player ability_util::gadget_is_active( GADGET_TYPE_COMBAT_EFFICIENCY ) )
						{
							scoreevents::processScoreEvent( "focus_earn_scorestreak", player );
							player scoreevents::specialistMedalAchievement();
							player scoreevents::specialistStatAbilityUsage( 4, true );
							if ( player.heroAbility.name == "gadget_combat_efficiency" )
							{
								player addWeaponStat( player.heroAbility, "scorestreaks_earned", 1 );
								if ( !isdefined( player.scoreStreaksEarnedPerUse ) )
								{
									player.scoreStreaksEarnedPerUse = 0;
								}
								
								player.scoreStreaksEarnedPerUse++;
								if ( player.scoreStreaksEarnedPerUse >= 3 )
								{
									scoreevents::processScoreEvent( "focus_earn_multiscorestreak", player );
									player.scoreStreaksEarnedPerUse = 0;
								}
							}
						}
					}
				}
				
				if ( !was_already_at_max_stacking )
				{
					player killstreaks::add_to_notification_queue( level.killstreaks[killstreakType].menuname, new_killstreak_quantity, killstreakType );
				}
			}
			else
			{
				player killstreaks::add_to_notification_queue( level.killstreaks[killstreakType].menuname, 0, killstreakType );
				activeEventName = "reward_active";
				if ( isdefined( weapon ) )
				{
					newEventName = weapon.name + "_active";
					if ( scoreevents::isRegisteredEvent( newEventName ) )
					{
						activeEventName = newEventName;
					}
				}
				//scoreevents::processScoreEvent( activeEventName, player );
			}
		}
	}
}

function giveTeamScore( event, team, player, victim )
{
	if ( level.overrideTeamScore )
		return;
		
	teamScore = game["teamScores"][team];
	[[level.onTeamScore]]( event, team );
	
	newScore = game["teamScores"][team];
	
	
	if ( teamScore == newScore )
		return;
	
	updateTeamScores( team );

	thread globallogic::checkScoreLimit();
	thread globallogic::checkRoundScoreLimit();
}

function giveTeamScoreForObjective_DelayPostProcessing( team, score )
{
	teamScore = game["teamScores"][team];

	onTeamScore_IncrementScore( score, team );

	newScore = game["teamScores"][team];
	
	
	if ( teamScore == newScore )
		return;
	
	updateTeamScores( team );
}

function postProcessTeamScores( teams )
{
	foreach( team in teams )
	{
		OnTeamScore_PostProcess( team );
	}
	
	thread globallogic::checkScoreLimit();
	thread globallogic::checkRoundScoreLimit();
}

function giveTeamScoreForObjective( team, score )
{
	if ( !isdefined( level.teams[team] ) )
		return;
		
	teamScore = game["teamScores"][team];

	onTeamScore( score, team );

	newScore = game["teamScores"][team];
	
	
	if ( teamScore == newScore )
		return;
	
	updateTeamScores( team );

	thread globallogic::checkScoreLimit();
	thread globallogic::checkRoundScoreLimit();
	thread globallogic::checkSuddenDeathScoreLimit( team );
}

function _setTeamScore( team, teamScore )
{
	if ( teamScore == game["teamScores"][team] )
		return;

	game["teamScores"][team] = math::clamp( teamScore, 0, 1000000 );
	
	updateTeamScores( team );
	
	thread globallogic::checkScoreLimit();
	thread globallogic::checkRoundScoreLimit();
}

function resetTeamScores()
{
	if ( level.scoreRoundWinBased || util::isFirstRound() )
	{
		foreach( team in level.teams )
		{
			game["teamScores"][team] = 0;
		}
	}
	
	globallogic_score::updateAllTeamScores();
}

function resetAllScores()
{
	resetTeamScores();
	resetPlayerScores();
	teamops::stopTeamops();
}

function resetPlayerScores()
{
	players = level.players;
	winner = undefined;
	tie = false;
	
	for( i = 0; i < players.size; i++ )
	{

		if ( isdefined( players[i].pers["score"] ) )
			_setPlayerScore( players[i], 0 );
		
	}
}

function updateTeamScores( team )
{
	setTeamScore( team, game["teamScores"][team] );
	level thread globallogic::checkTeamScoreLimitSoon( team );
}

function updateAllTeamScores( )
{
	foreach( team in level.teams )
	{
		updateTeamScores( team );
	}
}

function _getTeamScore( team )
{
	return game["teamScores"][team];
}

function getHighestTeamScoreTeam()
{
	score = 0;
	winning_teams = [];
	
	foreach( team in level.teams )
	{
		team_score = game["teamScores"][team];
		if ( team_score > score )
		{
			score = team_score;
			winning_teams = [];
		}
		
		if ( team_score == score )
		{
			winning_teams[team] = team;
		}
	}
	
	return winning_teams;
}

function areTeamArraysEqual( teamsA, teamsB )
{
	if ( teamsA.size != teamsB.size )
		return false;
		
	foreach( team in teamsA )
	{
		if ( !isdefined( teamsB[team] ) )
			return false;
	}
	
	return true;
}

function onTeamScore( score, team )
{
	onTeamScore_IncrementScore( score, team );
	onTeamScore_PostProcess( team );
}

function onTeamScore_IncrementScore( score, team )
{
	game["teamScores"][team] += score;
	if ( game["teamScores"][team] < 0 )
	{
		game["teamScores"][team] = 0;
	}
	
	if ( level.clampScoreLimit )
	{
		if ( level.scoreLimit && game["teamScores"][team] > level.scoreLimit )
			game["teamScores"][team] = level.scoreLimit;
			
		if ( level.roundScoreLimit && game["teamScores"][team] > util::get_current_round_score_limit() )
			game["teamScores"][team] = util::get_current_round_score_limit();
	}
}

function onTeamScore_PostProcess( team )
{
	if ( level.splitScreen )	
		return;
		
	if ( level.scoreLimit == 1 )
		return;
		
	isWinning = getHighestTeamScoreTeam();

	if ( isWinning.size == 0 )
		return;
		
	if ( getTime() - level.lastStatusTime < 5000 )
		return;
	
	if ( areTeamArraysEqual( isWinning, level.wasWinning )  )
		return;
	
	// dont say anything if they are the tied for the lead currently because they are not really winning
	if ( isWinning.size == 1 )
	{
		level.lastStatusTime = getTime();
		
		// looping because its easier but there is only one iteration (size == 1)
		foreach( team in isWinning )
		{
				// dont say anything if you were already winning
				if ( isdefined( level.wasWinning[team] ) )
				{
					// ... and there was no one tied with you
					if ( level.wasWinning.size == 1 )
						continue;
				}
	
			// you have just taken the lead and you are the only one in the lead
			globallogic_audio::leader_dialog( "lead_taken", team, undefined, "status" );
		}
	}
	else // This else statement makes it so that no one will hear 'loss' VO until one team has taken the lead
	{
		return;
	}
	
	// dont say anything if they were the tied for the lead previously because they were not really winning
	if ( level.wasWinning.size == 1)
	{
		// looping because its easier but there is only one iteration (size == 1)
		foreach( team in level.wasWinning )
		{
			// dont say anything if you are still winning  
			if ( isdefined( isWinning[team] ) )
			{
				// and you are not currently tied for the lead 
				if ( isWinning.size == 1 )
					continue;
					
				// or you were previously tied for the lead (already told)
				if ( level.wasWinning.size > 1 )
					continue; 
			}
			
			
			// you are either no longer winning or you were winning and now are tied for the lead
			globallogic_audio::leader_dialog( "lead_lost", team, undefined, "status" );
		}
	}
	
	level.wasWinning = isWinning;
}


function default_onTeamScore( event, team )
{
	score = rank::getScoreInfoValue( event );
	
	assert( isdefined( score ) );

	onTeamScore( score, team );	
}

function initPersStat( dataName, record_stats )
{
	if( !isdefined( self.pers[dataName] ) )
	{
		self.pers[dataName] = 0;
	}
	
	if ( !isdefined(record_stats) || record_stats == true )
	{
		recordPlayerStats( self, dataName, int(self.pers[dataName]) );
	}	
}


function getPersStat( dataName )
{
	return self.pers[dataName];
}


function incPersStat( dataName, increment, record_stats, includeGametype )
{
	self.pers[dataName] += increment;
	
	if ( isdefined( includeGameType ) && includeGameType )
	{
		self AddPlayerStatWithGameType( dataName, increment );
	}
	else
	{
		self AddPlayerStat( dataName, increment );
	}
	
	if ( !isdefined(record_stats) || record_stats == true )
	{
		self thread threadedRecordPlayerStats( dataName );
	}
}

function threadedRecordPlayerStats( dataName )
{
	self endon("disconnect");
	waittillframeend;
	
	recordPlayerStats( self, dataName, self.pers[dataName] );
}

function updateWinStats( winner )
{
	winner AddPlayerStatWithGameType( "losses", -1 );
	
	winner AddPlayerStatWithGameType( "wins", 1 );

	if ( level.hardcoreMode )
	{
		winner AddPlayerStat( "wins_HC", 1 );
	}
	if ( level.multiTeam )
	{
		winner AddPlayerStat( "wins_MULTITEAM", 1 );
	}
	winner UpdateStatRatio( "wlratio", "wins", "losses" );

	// restore winstreak, this is set to 0 on connect
	restoreWinStreaks( winner );

	winner AddPlayerStatWithGameType( "cur_win_streak", 1 );
	// This notify is used for the contracts system. It allows it to reset a contract's progress on this notify.
	winner notify( "win" );
	
	winner.lootXpMultiplier = true;
	
	cur_gamemode_win_streak = winner persistence::stat_get_with_gametype( "cur_win_streak" );
	gamemode_win_streak = winner persistence::stat_get_with_gametype( "win_streak" );

	cur_win_streak = winner GetDStat( "playerstatslist", "cur_win_streak", "StatValue" );
	if ( !level.disableStatTracking && cur_win_streak > winner getDStat( "HighestStats", "win_streak" ) )
	{
		winner setDStat( "HighestStats", "win_streak", cur_win_streak );
	}
	
	if ( cur_gamemode_win_streak > gamemode_win_streak )
	{
		winner persistence::stat_set_with_gametype( "win_streak", cur_gamemode_win_streak );
	}

	if( bot::is_bot_ranked_match() ) 
	{
		combatTrainingWins = winner GetDStat( "combatTrainingWins" );

		winner setDStat( "combatTrainingWins", combatTrainingWins + 1 );
	}

	updateWeaponContractWin( winner );
	
	updateContractWin( winner );
}

function canUpdateWeaponContractStats( player )
{
	if ( GetDvarInt( "enable_weapon_contract", 0 ) == 0 )
		return false;
	
	if ( !level.rankedMatch && !level.arenaMatch )
		return false;
	
	if ( player GetDStat( "contracts", MP_CONTRACT_SPECIAL_SLOT, "index" ) != 0 )
		return false;

	return true;
}

function updateWeaponContractStart( player )
{
	if ( !canUpdateWeaponContractStats( player ) )
		return;
	
	if ( player GetDStat( "weaponContractData", "startTimestamp" ) == 0 )
	{
		player SetDStat( "weaponContractData", "startTimestamp", GetUTC() );
	}
}

function updateWeaponContractWin( winner )
{
	if ( !canUpdateWeaponContractStats( winner ) )
		return;

	matchesWon = winner GetDStat( "weaponContractData", "currentValue" ) + 1;
	winner SetDStat( "weaponContractData", "currentValue", matchesWon );
	
	if ( VAL( winner GetDStat( "weaponContractData", "completeTimestamp" ), 0 ) == 0 )
	{
		targetValue = GetDvarInt( "weapon_contract_target_value", 100 );
		if ( matchesWon >= targetValue )
		{
			winner SetDStat( "weaponContractData", "completeTimestamp", GetUTC() );
		}
	}
}

function updateWeaponContractPlayed()
{
	foreach( player in level.players )
	{
		if ( !isdefined( player ) )
			continue;
		
		if ( !canUpdateWeaponContractStats( player ) )
			continue;

		// must at least spawned into a team to get matches played credit, otherwise players could potentially exploit this by never spawning in
		if ( !isdefined( player.pers["team"] ) )
			continue;
		
		matchesPlayed = player GetDStat( "weaponContractData", "matchesPlayed" ) + 1;
		player SetDStat( "weaponContractData", "matchesPlayed", matchesPlayed );
	}
}

function updateContractWin( winner )
{
	if ( !isdefined( level.updateContractWinEvents ) )
		return;
	
	foreach( contractWinEvent in level.updateContractWinEvents )
	{
		if ( !isdefined( contractWinEvent ) )
			continue;
		
		[[ contractWinEvent ]]( winner );
	}
}

function registerContractWinEvent( event )
{
	if ( !isdefined( level.updateContractWinEvents ) )
		level.updateContractWinEvents = [];
	
	ARRAY_ADD( level.updateContractWinEvents, event );
}

function updateLossStats( loser )
{	
	loser AddPlayerStatWithGameType( "losses", 1 );
	loser UpdateStatRatio( "wlratio", "wins", "losses" );
	// This notify is used for the contracts system. It allows it to reset a contract's progress on this notify.
	loser notify( "loss" );
}

function updateLossLateJoinStats( loser )
{	
	loser AddPlayerStatWithGameType( "losses", -1 );
	loser AddPlayerStatWithGameType( "losses_late_join", 1 );

	loser UpdateStatRatio( "wlratio", "wins", "losses" );
}

function updateTieStats( loser )
{	
	loser AddPlayerStatWithGameType( "losses", -1 );
	
	loser AddPlayerStatWithGameType( "ties", 1 );
	loser UpdateStatRatio( "wlratio", "wins", "losses" );
	
	if ( !level.disableStatTracking )
	{
		loser SetDStat( "playerstatslist", "cur_win_streak", "StatValue", 0 );		
	}
	// This notify is used for the contracts system. It allows it to reset a contract's progress on this notify.
	loser notify( "tie" );
}

function updateWinLossStats( winner )
{
	if ( !util::wasLastRound() && !level.hostForcedEnd )
		return;
		
	players = level.players;

	updateWeaponContractPlayed();
	
	if ( !isdefined( winner ) || ( isdefined( winner ) && !isPlayer( winner ) && winner == "tie" ) )
	{
		for ( i = 0; i < players.size; i++ )
		{
			if ( !isdefined( players[i].pers["team"] ) )
				continue;

			if ( level.hostForcedEnd && players[i] IsHost() )
				continue;
				
			updateTieStats( players[i] );
		}		
	} 
	else if ( isPlayer( winner ) )
	{
		if ( level.hostForcedEnd && winner IsHost() )
			return;
				
		updateWinStats( winner );
		
		if ( !level.teamBased )
		{
			placement = level.placement["all"];
			topThreePlayers = min( 3, placement.size );
				
			for ( index = 1; index < topThreePlayers; index++ )
			{
				nextTopPlayer = placement[index];
				
				updateWinStats( nextTopPlayer );
			}
			
			for ( i = 0; i < players.size; i++ )
			{			
				if( winner == players[i] )
					continue;
				
				index = 1;
				for( ; index < topThreePlayers; index++ )
				{
					if( players[i] == placement[index] )
						break;
				}					
				if( index < topThreePlayers )
					continue;
					
				if ( level.rankedMatch && !level.leagueMatch && ( players[i].pers["lateJoin"] === true ) )
				{
					updateLossLateJoinStats( players[i] );
				}
			}
		}
	}
	else
	{
		for ( i = 0; i < players.size; i++ )
		{
			if ( !isdefined( players[i].pers["team"] ) )
				continue;

			if ( level.hostForcedEnd && players[i] IsHost() )
				continue;

			if ( winner == "tie" )
				updateTieStats( players[i] );
			else if ( players[i].pers["team"] == winner )
				updateWinStats( players[i] );
			else
			{
				// need to add condition for arena late join loss prevention
				if ( level.rankedMatch && !level.leagueMatch && ( players[i].pers["lateJoin"] === true ) )
				{
					updateLossLateJoinStats( players[i] );
				}
			 
			 	if ( !level.disableStatTracking )
			 	{
					players[i] SetDStat( "playerstatslist", "cur_win_streak", "StatValue", 0 );	
				}
			}
		}
	}
}

// self is the player
function backupAndClearWinStreaks()
{
	if ( IS_TRUE( level.freerun ) )
		return;
	
	// Global
	self.pers[ "winStreak" ] = self GetDStat( "playerstatslist", "cur_win_streak", "StatValue" );
	if ( !level.disableStatTracking )
	{
		self SetDStat( "playerstatslist", "cur_win_streak", "StatValue", 0 );	
	}
	
	// Gametype
	self.pers[ "winStreakForGametype" ] = persistence::stat_get_with_gametype( "cur_win_streak" ); 
	self persistence::stat_set_with_gametype( "cur_win_streak", 0 );
}

function restoreWinStreaks( winner )
{
	if ( !level.disableStatTracking )
	{
		// Global
		winner SetDStat( "playerstatslist", "cur_win_streak", "StatValue", winner.pers[ "winStreak" ] );
	}
	
	// Gametype
	winner persistence::stat_set_with_gametype( "cur_win_streak", winner.pers[ "winStreakForGametype" ] );
}

function incKillstreakTracker( weapon )
{
	self endon("disconnect");
	
	waittillframeend;
	
	if( weapon.name == "artillery" )
		self.pers["artillery_kills"]++;
	
	if( weapon.name == "dog_bite" )
		self.pers["dog_kills"]++;
}

function trackAttackerKill( name, rank, xp, prestige, xuid, weapon )
{
	self endon("disconnect");
	attacker = self;
	
	waittillframeend;

	if ( !isdefined( attacker.pers["killed_players"][name] ) )
		attacker.pers["killed_players"][name] = 0;

	if ( !isdefined( attacker.pers["killed_players_with_specialist"][name] ) )
		attacker.pers["killed_players_with_specialist"][name] = 0;

	if ( !isdefined( attacker.killedPlayersCurrent[name] ) )
		attacker.killedPlayersCurrent[name] = 0;

	if ( !isdefined( attacker.pers["nemesis_tracking"][name] ) )
		attacker.pers["nemesis_tracking"][name] = 0;

	attacker.pers["killed_players"][name]++;
	
		
	attacker.killedPlayersCurrent[name]++;
	attacker.pers["nemesis_tracking"][name] += 1.0;
	if ( attacker.pers["nemesis_name"] == name ) 
	{
		attacker challenges::killedNemesis();
	}

	if ( isdefined( weapon.isHeroWeapon ) && weapon.isHeroWeapon == true )
	{
		attacker.pers["killed_players_with_specialist"][name]++;
	}
	

	if( attacker.pers["nemesis_name"] == "" || attacker.pers["nemesis_tracking"][name] > attacker.pers["nemesis_tracking"][attacker.pers["nemesis_name"]] )
	{
		attacker.pers["nemesis_name"] = name;
		attacker.pers["nemesis_rank"] = rank;
		attacker.pers["nemesis_rankIcon"] = prestige;
		attacker.pers["nemesis_xp"] = xp;
		attacker.pers["nemesis_xuid"] = xuid;
	}
	else if( isdefined( attacker.pers["nemesis_name"] ) && ( attacker.pers["nemesis_name"] == name ) )
	{
		attacker.pers["nemesis_rank"] = rank;
		attacker.pers["nemesis_xp"] = xp;
	}

	if ( !isdefined( attacker.lastKilledVictim ) || !isdefined( attacker.lastKilledVictimCount ) ) 
	{
		 attacker.lastKilledVictim = name;
		 attacker.lastKilledVictimCount = 0;
	}

	if ( attacker.lastKilledVictim == name )
	{
		attacker.lastKilledVictimCount++;
		if ( attacker.lastKilledVictimCount >= 5 )
		{
			attacker.lastKilledVictimCount = 0;
			attacker AddPlayerStat( "streaker", 1 );
		}
	}
	else
	{
		attacker.lastKilledVictim = name;
		attacker.lastKilledVictimCount = 1;
	}
}

function trackAttackeeDeath( attackerName, rank, xp, prestige, xuid )
{
	self endon("disconnect");

	waittillframeend;

	if ( !isdefined( self.pers["killed_by"][attackerName] ) )
		self.pers["killed_by"][attackerName] = 0;

		self.pers["killed_by"][attackerName]++;

	if ( !isdefined( self.pers["nemesis_tracking"][attackerName] ) )
		self.pers["nemesis_tracking"][attackerName] = 0;
   
	self.pers["nemesis_tracking"][attackerName] += 1.5;

	if( self.pers["nemesis_name"] == "" || self.pers["nemesis_tracking"][attackerName] > self.pers["nemesis_tracking"][self.pers["nemesis_name"]] )
	{
		self.pers["nemesis_name"] = attackerName;
		self.pers["nemesis_rank"] = rank;
		self.pers["nemesis_rankIcon"] = prestige;
		self.pers["nemesis_xp"] = xp;
		self.pers["nemesis_xuid"] =xuid;
	}
	else if( isdefined( self.pers["nemesis_name"] ) && ( self.pers["nemesis_name"] == attackerName ) )
	{
		self.pers["nemesis_rank"] = rank;
		self.pers["nemesis_xp"] = xp;
	}
	
	//Nemesis Killcam - ( hopefully even with the wait it gets there with enough time not to cause a flicker)
	if( self.pers["nemesis_name"] == attackerName && self.pers["nemesis_tracking"][attackerName] >= 2 )
		self setClientUIVisibilityFlag( "killcam_nemesis", 1 );
	else
		self setClientUIVisibilityFlag( "killcam_nemesis", 0 );

	selfKillsTowardsAttacker = 0;

	if ( isDefined( self.pers["killed_players"][attackerName] ) )
	{
		selfKillsTowardsAttacker = self.pers["killed_players"][attackerName];
	}

	self LUINotifyEvent( &"track_victim_death", 2, self.pers["killed_by"][attackerName], selfKillsTowardsAttacker );
}

function default_isKillBoosting()
{
	return false;
}

function giveKillStats( sMeansOfDeath, weapon, eVictim )
{
	self endon("disconnect");
	
	// setting this now so the scoreboard gets updated immediatly
	self.kills = self.kills + 1;

	waittillframeend;

	if ( level.rankedMatch && self [[level.isKillBoosting]]() )	
	{
		return;
	}
		
	self globallogic_score::incPersStat( "kills", 1, true, true );
	self.kills = self globallogic_score::getPersStat( "kills" );
	self UpdateStatRatio( "kdratio", "kills", "deaths" );

	attacker = self;
	if ( sMeansOfDeath == "MOD_HEAD_SHOT" && !killstreaks::is_killstreak_weapon( weapon )  )
	{
		attacker thread incPersStat( "headshots", 1 , true, false );
		attacker.headshots = attacker.pers["headshots"];
		if ( isdefined( eVictim ) )
			eVictim RecordKillModifier("headshot");
	}
}

function incTotalKills( team )
{
	if ( level.teambased && isdefined( level.teams[team] ) )
	{
		game["totalKillsTeam"][team]++;				
	}	
	
	game["totalKills"]++;			
}

function setInflictorStat( eInflictor, eAttacker, weapon )
{
	if ( !isdefined( eAttacker ) )
		return;

	weaponPickedUp = false;
	if( isdefined( eAttacker.pickedUpWeapons ) && isdefined( eAttacker.pickedUpWeapons[weapon] ) )
	{
		weaponPickedUp = true;
	}

	if ( !isdefined( eInflictor ) )
	{
		eAttacker AddWeaponStat( weapon, "hits", 1, eAttacker.class_num, weaponPickedUp );
		return;
	}

	if ( !isdefined( eInflictor.playerAffectedArray ) )
		eInflictor.playerAffectedArray = [];

	foundNewPlayer = true;
	for ( i = 0 ; i < eInflictor.playerAffectedArray.size ; i++ )
	{
		if ( eInflictor.playerAffectedArray[i] == self )
		{
			foundNewPlayer = false;
			break;
		}
	}

	if ( foundNewPlayer )
	{
		eInflictor.playerAffectedArray[eInflictor.playerAffectedArray.size] = self;
		if( weapon.rootweapon.name == "tabun_gas" )
		{
			eAttacker AddWeaponStat( weapon, "used", 1 );
		}
		eAttacker AddWeaponStat( weapon, "hits", 1, eAttacker.class_num, weaponPickedUp );
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function processShieldAssist( killedplayer ) // self == riotshield player
{
	self endon( "disconnect" );
	killedplayer endon( "disconnect" );

	wait .05; // don't ever run on the same frame as the playerkilled callback.
	util::WaitTillSlowProcessAllowed();

	if ( !isdefined( level.teams[ self.pers["team"] ] )  )
		return;
	
	if ( self.pers["team"] == killedplayer.pers["team"] )
		return;

	if ( !level.teambased )
		return;

	self globallogic_score::incPersStat( "assists", 1, true, true );

	self.assists = self globallogic_score::getPersStat( "assists" );

	 scoreevents::processScoreEvent( "shield_assist", self, killedplayer, "riotshield" );
}

function processAssist( killedplayer, damagedone, weapon )
{
	self endon("disconnect");
	killedplayer endon("disconnect");
	
	wait .05; // don't ever run on the same frame as the playerkilled callback.
	util::WaitTillSlowProcessAllowed();
	
	if ( !isdefined( level.teams[ self.pers["team"] ] )  )
		return;
	
	if ( self.pers["team"] == killedplayer.pers["team"] )
		return;

	if ( !level.teambased )
		return;
	
	assist_level = "assist";
	
	assist_level_value = int( ceil( damagedone / 25 ) );
	
	if ( assist_level_value < 1 )
	{
		assist_level_value = 1;
	}
	else if ( assist_level_value > 3 )
	{
		assist_level_value = 3;
	}
	assist_level = assist_level + "_" + ( assist_level_value * 25 );
	
	self globallogic_score::incPersStat( "assists", 1, true, true );

	self.assists = self  globallogic_score::getPersStat( "assists" );
	
	if ( isdefined( weapon ) )
	{
		weaponPickedUp = false;
		if( isdefined( self.pickedUpWeapons ) && isdefined( self.pickedUpWeapons[weapon] ) )
		{
			weaponPickedUp = true;
		}
		self AddWeaponStat( weapon, "assists", 1, self.class_num, weaponPickedUp );
	}

	switch( weapon.name )
	{
	case "concussion_grenade":
		assist_level = "assist_concussion";
		break;
	case "flash_grenade":
		assist_level = "assist_flash";
		break;
	case "emp_grenade":
		assist_level = "assist_emp";
		break;
	case "proximity_grenade":
	case "proximity_grenade_aoe":
		assist_level = "assist_proximity";
		break;
	}
	self challenges::assisted();
	scoreevents::processScoreEvent( assist_level, self, killedplayer, weapon );
}

function processKillstreakAssists( attacker, inflictor, weapon )
{
	if ( !isdefined( attacker ) || !isdefined( attacker.team ) || self util::IsEnemyPlayer( attacker ) == false )
		return;

	// if the player suicided, dont give the assist
	if ( self == attacker || ( attacker.classname == "trigger_hurt" || attacker.classname == "worldspawn" ) )
		return;

	enemyCUAVActive = false;
	if ( attacker hasperk( "specialty_immunecounteruav" ) == false )
	{
		foreach( team in level.teams )
		{
			if ( team == attacker.team )
			{
				continue;
			}
	
			if( counteruav::TeamHasActiveCounterUAV( team ) )
			{
				enemyCUAVActive = true;
			}
		}
	}

	foreach( player in level.players )
	{
		if ( player.team != attacker.team ) 
			continue;

		if ( player.team == "spectator" ) 
			continue;

		if ( player == attacker ) 
			continue;

		if ( player.sessionstate != "playing" )
			continue;

		assert( isdefined ( level.activePlayerCounterUAVs[ player.entNum ] ) );
		assert( isdefined ( level.activePlayerUAVs[ player.entNum ] ) );
		assert( isdefined ( level.activePlayerSatellites[ player.entNum ] ) );

		is_killstreak_weapon = killstreaks::is_killstreak_weapon( weapon );
		if ( level.activePlayerCounterUAVs[ player.entNum ] > 0 && !is_killstreak_weapon )
		{
			scoreGiven = scoreevents::processScoreEvent( "counter_uav_assist", player );
			if ( isdefined ( scoreGiven ) )
			{
				player challenges::earnedCUAVAssistScore( scoreGiven );
				killstreakIndex = level.killstreakindices["killstreak_counteruav"];
				killstreaks::killstreak_assist(player, self, killstreakIndex);
				player process_killstreak_assist_score( "counteruav", scoreGiven );
			}
		}

		if ( enemyCUAVActive == false )
		{
			activeUAV = level.activePlayerUAVs[ player.entNum ];
			if( level.forceRadar == 1 )
				activeUAV--;
				
			if( activeUAV > 0 && !is_killstreak_weapon )
			{
				scoreGiven = scoreevents::processScoreEvent( "uav_assist", player );
				if ( isdefined ( scoreGiven ) )
				{
					player challenges::earnedUAVAssistScore( scoreGiven );
					killstreakIndex = level.killstreakindices["killstreak_uav"];
					killstreaks::killstreak_assist(player, self, killstreakIndex);
					player process_killstreak_assist_score( "uav", scoreGiven );
				}
			}

			if ( level.activePlayerSatellites[ player.entNum ] > 0 && !is_killstreak_weapon )
			{
				scoreGiven = scoreevents::processScoreEvent( "satellite_assist", player );
				if ( isdefined ( scoreGiven ) )
				{
					player challenges::earnedSatelliteAssistScore( scoreGiven );
					killstreakIndex = level.killstreakindices["killstreak_satellite"];
					killstreaks::killstreak_assist(player, self, killstreakIndex);
					player process_killstreak_assist_score( "satellite", scoreGiven );
				}
			}
		}
		
		
		if( player EMP::HasActiveEMP() )
		{
			scoreGiven = scoreevents::processScoreEvent( "emp_assist", player );
			if ( isdefined ( scoreGiven ) )
			{
				player challenges::earnedEMPAssistScore( scoreGiven );
				killstreakIndex = level.killstreakindices["killstreak_emp"];
				killstreaks::killstreak_assist(player, self, killstreakIndex);
				player process_killstreak_assist_score( "emp", scoreGiven );
			}
		}
	}
}

function process_killstreak_assist_score( killstreak, scoreGiven )
{
	player = self;
	killstreakPurchased = false;
	if ( isdefined( killstreak ) && isdefined( level.killstreaks[ killstreak ] ) )
	{
		killstreakPurchased = player util::is_item_purchased( level.killstreaks[ killstreak ].menuname );
	}
	player util::player_contract_event( "killstreak_score", scoreGiven, killstreakPurchased );
}


