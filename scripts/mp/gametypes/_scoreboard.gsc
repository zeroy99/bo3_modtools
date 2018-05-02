#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace scoreboard;

REGISTER_SYSTEM( "scoreboard", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
}

function init()
{
	if ( SessionModeIsZombiesGame() )
	{
		SetDvar( "g_TeamIcon_Axis", "faction_cia" );
		SetDvar( "g_TeamIcon_Allies", "faction_cdc" );
	}
	else
	{
		SetDvar( "g_TeamIcon_Axis", game["icons"]["axis"] );
		SetDvar( "g_TeamIcon_Allies", game["icons"]["allies"] );
		// TODO MTEAM - setup the team icons for team3-8
	}
}
