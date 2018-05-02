#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace player;

REGISTER_SYSTEM( "player", &__init__, undefined )

function __init__()
{	
	clientfield::register( "world", "gameplay_started", VERSION_TU4, 1, "int", &gameplay_started_callback, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function gameplay_started_callback(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{	
	SetDvar("cg_isGameplayActive", newVal);
}
