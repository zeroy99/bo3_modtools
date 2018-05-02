#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;
#insert scripts\shared\shared.gsh;

#namespace music;

REGISTER_SYSTEM( "music", &__init__, undefined )

function __init__()
{
	level.musicState = "";
	util::registerClientSys("musicCmd");
	
	if( SessionModeIsCampaignGame() )
	{
		callback::on_spawned( &on_player_spawned );	
	}	
}

function setMusicState(state, player)
{
	if (isdefined(level.musicState))
	{
		if( IS_TRUE( level.bonuszm_musicoverride ) )
			return;
		
		if( isdefined( player ) )
		{
				util::setClientSysState("musicCmd", state, player );
				//println ( "Music cl Number " + player getEntityNumber() );
				return;
		}
		else if(level.musicState != state)
		{
				util::setClientSysState("musicCmd", state );
		}
	}
	level.musicState = state;
}

function on_player_spawned()
{
	if(isdefined(level.musicState))
	{	
		if(issubstr(level.musicState, "_igc") || issubstr(level.musicState, "igc_"))
		{
			return;	
		}
		
		if(isdefined( self ))
		{
			setMusicState(level.musicState, self);
		}
		else
		{
			setMusicState(level.musicState);
		}
	}
}
