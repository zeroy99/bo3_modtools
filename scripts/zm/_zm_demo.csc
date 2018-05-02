
#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\aat_shared.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

REGISTER_SYSTEM( "zm_demo", &__init__, undefined )

function __init__()
{
	if ( IsDemoPlaying() )
	{
		DEFAULT(level.demolocalclients,[]);
		callback::on_localclient_connect( &player_on_connect );
	}
}

function player_on_connect( localClientNum )
{
	level thread watch_predicted_player_changes( localClientNum );
}


function watch_predicted_player_changes(localClientNum)
{
	level.demolocalclients[localClientNum] = spawnStruct();
	level.demolocalclients[localClientNum].nonpredicted_local_player = GetNonPredictedLocalPlayer( localClientNum ); 
	level.demolocalclients[localClientNum].predicted_local_player = GetLocalPlayer( localClientNum ); 
	while(1)
	{
		nonpredicted_local_player = GetNonPredictedLocalPlayer( localClientNum ); 
		predicted_local_player = GetLocalPlayer( localClientNum ); 
		if ( nonpredicted_local_player !== level.demolocalclients[localClientNum].nonpredicted_local_player )
		{
			level notify("demo_nplplayer_change", localClientNum, level.demolocalclients[localClientNum].nonpredicted_local_player, nonpredicted_local_player ); 
			level notify("demo_nplplayer_change"+localClientNum, level.demolocalclients[localClientNum].nonpredicted_local_player, nonpredicted_local_player ); 
			level.demolocalclients[localClientNum].nonpredicted_local_player = nonpredicted_local_player; 
		}
		if ( predicted_local_player !== level.demolocalclients[localClientNum].predicted_local_player )
		{
			level notify("demo_plplayer_change", localClientNum, level.demolocalclients[localClientNum].predicted_local_player, predicted_local_player ); 
			level notify("demo_plplayer_change"+localClientNum, level.demolocalclients[localClientNum].predicted_local_player, predicted_local_player ); 
			level.demolocalclients[localClientNum].predicted_local_player = predicted_local_player; 
		}
		WAIT_CLIENT_FRAME; 
	}
	
}
