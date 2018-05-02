#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;

#using scripts\zm\_zm_powerups;

#insert scripts\zm\_zm_utility.gsh;

#namespace zm_powerup_nuke;

REGISTER_SYSTEM( "zm_powerup_nuke", &__init__, undefined )
	
function __init__()
{
	zm_powerups::include_zombie_powerup( "nuke" );
	zm_powerups::add_zombie_powerup( "nuke" );
	
	clientfield::register( "actor", "zm_nuked", VERSION_TU1, 1, "counter", &zombie_nuked, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "zm_nuked", VERSION_TU1, 1, "counter", &zombie_nuked, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function zombie_nuked( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self zombie_death::flame_death_fx( localClientNum );
}

