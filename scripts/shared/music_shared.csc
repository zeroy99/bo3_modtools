#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace music;

REGISTER_SYSTEM( "music", &__init__, undefined )

function __init__()
{
	level.activeMusicState = "";
	level.nextMusicState = "";
	level.musicStates = [];
	
	util::register_system( "musicCmd", &musicCmdHandler );					          					
}


function musicCmdHandler(clientNum, state, oldState)
{
	if (state != "death")
	{
		level._lastMusicState = state;
	}
	
	state = ToLower(state);
	soundsetmusicstate(state);
}






