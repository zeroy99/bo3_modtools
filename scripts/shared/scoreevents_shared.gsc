#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\gameskill_shared;

#insert scripts\shared\shared.gsh;

#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\scoreevents_shared.gsh;


#namespace scoreevents;


function processScoreEvent( event, player, victim, weapon )
{
	pixbeginevent("processScoreEvent");
	
	scoreGiven = 0;
	if ( !isplayer(player) )
	{
		AssertMsg("processScoreEvent called on non player entity: " + event );				
		return scoreGiven;
	}

	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
	{
		if ( isdefined( level.teamopsOnProcessPlayerEvent ) )
		{
			level [[level.teamopsOnProcessPlayerEvent]]( event, player );
		}
	}

	if ( isdefined( level.challengesOnEventReceived ) )
	{
		player thread [[level.challengesOnEventReceived]]( event );
	}	
	
	if ( isRegisteredEvent( event ) && (!SessionModeIsZombiesGame() || level.onlineGame) )
	{
		allowPlayerScore = false;
			
		if ( !isdefined( weapon ) || !killstreaks::is_killstreak_weapon( weapon ) ) 
		{	
			allowPlayerScore = true;
		}
		else
		{
			allowPlayerScore = killstreakWeaponsAllowedScore( event );
		}
	
		if ( allowPlayerScore )
		{
			if ( isdefined( level.scoreOnGivePlayerScore ) )
			{
				 scoreGiven = [[level.scoreOnGivePlayerScore]]( event, player, victim, undefined, weapon );
				 isScoreEvent = ( scoreGiven > 0 );

				 if ( isScoreEvent )
				 {
				 	hero_restricted = is_hero_score_event_restricted( event );
				 	
				 	player ability_power::power_gain_event_score( victim, scoreGiven, weapon, hero_restricted );
				 }				
			}			
		}		
	}
		
	if ( shouldAddRankXP( player ) && ( GetDvarInt( "teamOpsEnabled" ) == 0 ) )
	{
		pickedup = false;
		if( isdefined( weapon) && isdefined( player.pickedUpWeapons ) && isdefined( player.pickedUpWeapons[weapon] ) )
		{
			pickedup = true;
		}
		
		// In CP, the player earns an XP multiplier by playing on harder difficulties.
		if (SessionModeIsCampaignGame())
		{
			// Determine game difficulty. Player receives an XP multiplier for harder difficulties.
			xp_difficulty_multiplier = player gameskill::get_player_xp_difficulty_multiplier();
		}
		else
		{
			// No multiplier if not in CP.
			xp_difficulty_multiplier = 1;
		}
		
		player AddRankXp( event, weapon, player.class_num, pickedup, isScoreEvent, xp_difficulty_multiplier );
	}
	
	pixendevent();
	
	// In campaign, use the same difficulty modifier and apply it to the player's score for killing enemies.
	if (SessionModeIsCampaignGame() && isdefined(xp_difficulty_multiplier))
	{
		// Only apply a score multiplier if we killed an enemy.
		if (isdefined(victim) && isdefined(victim.team))
		{
			if (victim.team == "axis" || victim.team == "team3")
			{
				scoreGiven *= xp_difficulty_multiplier;
			}
		}
	}
	
	return scoreGiven;
}


function shouldAddRankXP( player )
{
	if( IS_BONUSZM )
	{
		return false;
	}
	
	if( level.gametype == "fr" )
	{
		return false;
	}
	
	if ( !isdefined( level.rankCap ) || level.rankCap == 0 )
	{
		return true;
	}
	
	if ( ( player.pers[ "plevel" ] > 0 ) || ( player.pers[ "rank" ] > level.rankCap ) )
	{
		return false;
	}
	
	return true;
}


function uninterruptedObitFeedKills( attacker, weapon )
{
	self endon( "disconnect" );
	wait .1;
	util::WaitTillSlowProcessAllowed();
	wait .1;

	scoreevents::processScoreEvent( "uninterrupted_obit_feed_kills", attacker, self, weapon );
}


function isRegisteredEvent( type )
{
	if ( isdefined( level.scoreInfo[type] ) )
		return true;
	else
		return false;
}


function decrementLastObituaryPlayerCountAfterFade() 
{
	level endon( "reset_obituary_count" );
	wait( SCORE_EVENT_OBITUARY_CENTERTIME );
	level.lastObituaryPlayerCount--;
	assert( level.lastObituaryPlayerCount >= 0 );
}

function getScoreEventTableName()
{
	if ( SessionModeIsCampaignGame() )
	{
		return SCORE_EVENT_TABLE_NAME_CP;
	}
	else if ( SessionModeIsZombiesGame() )
	{
		return SCORE_EVENT_TABLE_NAME_ZM;
	}
	else
	{
		return SCORE_EVENT_TABLE_NAME_MP;
	}
}

function getScoreEventTableID()
{
	scoreInfoTableLoaded = false;
	scoreInfoTableID = TableLookupFindCoreAsset( getScoreEventTableName() );
		
	if ( isdefined( scoreInfoTableID ) )
	{
		scoreInfoTableLoaded = true;
	}
	assert( scoreInfoTableLoaded, "Score Event Table is not loaded: " + getScoreEventTableName() );
	return scoreInfoTableID;
}

function getScoreEventColumn( gameType )
{
	columnOffset = getColumnOffsetForGametype( gameType );
	assert( columnOffset >= 0 );
	if ( columnOffset >= 0 )
	{
		columnOffset += SCORE_EVENT_GAMETYPE_COLUMN_SCORE;
	}
	return columnOffset;	
}

function getXPEventColumn( gameType )
{
	columnOffset = getColumnOffsetForGametype( gameType );
	assert( columnOffset >= 0 );
	if ( columnOffset >= 0 )
	{
		columnOffset += SCORE_EVENT_GAMETYPE_COLUMN_XP;
	}
	return columnOffset;	
}

function getColumnOffsetForGametype( gameType )
{
	foundGameMode = false;
	if ( !isdefined ( level.scoreEventTableID ) ) 
	{
		level.scoreEventTableID = getScoreEventTableID();
	}

	assert( isdefined ( level.scoreEventTableID ) );
	if ( !isdefined ( level.scoreEventTableID ) ) 
	{
		return -1;
	}

	for ( gameModeColumn = SCOREINFOTABLE_GAMETYPE_SCORE; ; gameModeColumn += SCORE_EVENT_GAMETYPE_COLUMN_COUNT )
	{
		column_header = TableLookupColumnForRow( level.scoreEventTableID, 0, gameModeColumn );
		if ( column_header == "" )
		{
			gameModeColumn = SCOREINFOTABLE_GAMETYPE_SCORE;
			break;
		}
		
		if ( column_header == level.gameType + " score" )
		{
			foundGameMode = true;
			break;
		}
	}
	
	assert( foundGameMode, "Could not find gamemode in scoreInfo.csv:" + gameType );
	return gameModeColumn;
}

function killstreakWeaponsAllowedScore( type )
{
	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		return false;
	
	if( isdefined( level.scoreInfo[type]["allowKillstreakWeapons"] ) && level.scoreInfo[type]["allowKillstreakWeapons"] == true )
	{
		return true;
	}
	else
	{
		return false;
	}
}

function is_hero_score_event_restricted( event )
{
	if( !isdefined( level.scoreInfo[event]["allow_hero"] ) || level.scoreInfo[event]["allow_hero"] != true )
	{
		return true;
	}
	
	return false;
}

function giveCrateCaptureMedal( crate, capturer )
{
	if ( isdefined( crate ) && isdefined( capturer ) && isdefined( crate.owner ) && isplayer( crate.owner ) )
	{
		if ( level.teambased ) 
		{
			if ( capturer.team != crate.owner.team )
			{
				crate.owner playlocalsound( "mpl_crate_enemy_steals" );
				// don't give a medal for capturing a booby trapped crate
				if( !IsDefined( crate.hacker ) )
				{
					scoreevents::processScoreEvent( "capture_enemy_crate", capturer );
				}
			}
			else 
			{
				if ( isdefined ( crate.owner ) && ( capturer != crate.owner ) )
				{
					crate.owner playlocalsound( "mpl_crate_friendly_steals" );
					// don't give a medal for capturing a booby trapped crate
					if( !IsDefined( crate.hacker ) )
					{
						level.globalSharePackages++;
						scoreevents::processScoreEvent( "share_care_package", crate.owner );
					}
				}
			}
		}
		else
		{
			if ( capturer != crate.owner )
			{
				crate.owner playlocalsound( "mpl_crate_enemy_steals" );
				// don't give a medal for capturing a booby trapped crate
				if( !IsDefined( crate.hacker ) )
				{
					scoreevents::processScoreEvent( "capture_enemy_crate", capturer );
				}
			}
		}
	}
}

function register_hero_ability_kill_event( event_func )
{
	if ( !isdefined( level.hero_ability_kill_events ) )
		level.hero_ability_kill_events = [];
	
	level.hero_ability_kill_events[ level.hero_ability_kill_events.size ] = event_func;
}

function register_hero_ability_multikill_event( event_func )
{
	if ( !isdefined( level.hero_ability_multikill_events ) )
		level.hero_ability_multikill_events = [];
	
	level.hero_ability_multikill_events[ level.hero_ability_multikill_events.size ] = event_func;
}

function register_hero_weapon_multikill_event( event_func )
{
	if ( !isdefined( level.hero_weapon_multikill_events ) )
		level.hero_weapon_multikill_events = [];
	
	level.hero_weapon_multikill_events[ level.hero_weapon_multikill_events.size ] = event_func;
}

function register_thief_shutdown_enemy_event( event_func )
{
	if ( !isdefined( level.thief_shutdown_enemy_events ) )
		level.thief_shutdown_enemy_events = [];
	
	level.thief_shutdown_enemy_events[ level.thief_shutdown_enemy_events.size ] = event_func;
}

function hero_ability_kill_event( ability, victim_ability )
{
	if ( !isdefined( level.hero_ability_kill_events ) )
		return;

	foreach( event_func in level.hero_ability_kill_events )
	{
		if ( isdefined( event_func ) )
		{
			self [[ event_func ]]( ability, victim_ability );
		}
	}
}

function hero_ability_multikill_event( killcount, ability )
{
	if ( !isdefined( level.hero_ability_multikill_events ) )
		return;
	
	foreach( event_func in level.hero_ability_multikill_events )
	{
		if ( isdefined( event_func ) )
		{
			self [[ event_func ]]( killcount, ability );
		}
	}
}

function hero_weapon_multikill_event( killcount, weapon )
{
	if ( !isdefined( level.hero_weapon_multikill_events ) )
		return;
	
	foreach( event_func in level.hero_weapon_multikill_events )
	{
		if ( isdefined( event_func ) )
		{
			self [[ event_func ]]( killcount, weapon );
		}
	}
}

function thief_shutdown_enemy_event()
{
	if ( !isdefined( level.thief_shutdown_enemy_event ) )
		return;
	
	foreach( event_func in level.thief_shutdown_enemy_event )
	{
		if ( isdefined( event_func ) )
		{
			self [[ event_func ]]();
		}
	}
}