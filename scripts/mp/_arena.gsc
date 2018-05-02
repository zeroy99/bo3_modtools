#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\teams\_teams;

#namespace arena;

REGISTER_SYSTEM( "arena", &__init__, undefined )
	
function __init__()
{
	callback::on_connect( &on_connect );
}

function on_connect()
{
	if( isdefined( self.pers["arenaInit"] ) && self.pers["arenaInit"] == 1 )
	{
		return;
	}

	draftEnabled = ( GetGametypeSetting( "pregameDraftEnabled" ) == 1 );
	voteEnabled =  ( GetGametypeSetting( "pregameItemVoteEnabled" ) == 1 );

	if( !draftEnabled && !voteEnabled )
	{
		self ArenaBeginMatch();
	}
	
	self.pers["arenaInit"] = 1;
}

function update_arena_challenge_seasons()
{
	perSeasonWins = self GetDStat( "arenaPerSeasonStats", "wins" );
	if( perSeasonWins >= GetDvarInt( "arena_seasonVetChallengeWins" ) )
	{
		arenaSlot = ArenaGetSlot();
		currentSeason = self GetDStat( "arenaStats", arenaSlot, "season" );
		seasonVetChallengeArrayCount = self GetDStatArrayCount( "arenaChallengeSeasons" );
		for( i = 0; i < seasonVetChallengeArrayCount; i++ )
		{
			challengeSeason = self GetDStat( "arenaChallengeSeasons", i );
			if( challengeSeason == currentSeason ) // don't add a single season more than once
			{
				return;
			}
			
			if( challengeSeason == 0 )
			{
				self SetDStat( "arenaChallengeSeasons", i, currentSeason );
				break;
			}
		}
	}
}

function match_end( winner )
{
	for( index = 0; index < level.players.size; index++ )
	{
		player = level.players[index];

		if( isdefined( player.pers["arenaInit"] ) && player.pers["arenaInit"] == 1 )
		{
			if( winner == "tie" )
			{
				player ArenaEndMatch( 0 );
			}
			else if( winner == player.pers["team"] )
			{
				player ArenaEndMatch( 1 );
				player arena::update_arena_challenge_seasons();
			}
			else
			{
				player ArenaEndMatch( -1 );
			}
		}
	}		
}


