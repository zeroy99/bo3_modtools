#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_shield", &__init__, undefined )

function __init__()
{
callback::on_spawned( &on_player_spawned );

	clientfield::register( "toplayer", "shield_on", VERSION_SHIP, 1, "int", &has_shield_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function on_player_spawned( local_client_num )
{
	self._gadget_has_shield = false;
}

function has_shield_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self._gadget_has_shield = newVal;

	update_sound( localClientNum );
}

function update_sound( localClientNum )
{
	if ( !IsDefined( self._gadget_shield_snd_ent ) )
	{
		self._gadget_shield_snd_ent	= Spawn( localClientNum, self.origin, "script_origin" );
	}

	if ( IS_TRUE(self._gadget_has_shield) )
	{
		self._gadget_shield_snd_ent PlayLoopSound( "gdt_energy_shield_loop", 0.5 );
	}
	else
	{
		self._gadget_shield_snd_ent StopAllLoopSounds( 0.5 );
	}
}