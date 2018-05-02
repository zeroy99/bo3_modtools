#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#insert scripts\shared\version.gsh;

#namespace counteruav;

REGISTER_SYSTEM( "counteruav", &__init__, undefined )	

function __init__()
{	
	clientfield::register( "toplayer", "counteruav", VERSION_SHIP, 1, "int", &CounterUAVChanged, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function CounterUAVChanged( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = GetLocalPlayer( localClientNum );
	assert( isdefined( player ) );
	
	player SetEnemyGlobalScrambler( newVal );
}
