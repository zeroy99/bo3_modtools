#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace client_flag;

REGISTER_SYSTEM( "client_flag", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "ctf_flag_away", VERSION_SHIP, 1, "int", &setCTFAway, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function setCTFAway( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	team = self.team;
	
	SetFlagAsAway( localClientNum, team, newVal );
	
	self thread clearCTFAway( localClientNum, team );
}

function clearCTFAway( localClientNum, team )
{
	self waittill( "entityshutdown" );

	SetFlagAsAway( localClientNum, team, 0 );
}