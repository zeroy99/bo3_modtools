#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_bouncingbetty;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_placeable_mine;

#namespace bouncingbetty;

REGISTER_SYSTEM( "bouncingbetty", &__init__, undefined )

function __init__()
{
	level._proximityWeaponObjectDetonation_override = &proximityWeaponObjectDetonation_override;

	bouncingbetty::init_shared();
	zm_placeable_mine::add_mine_type( "bouncingbetty", &"MP_BOUNCINGBETTY_PICKUP" );


	/*level.bettyDamageMax = 7250;
	level.bettyDamageMin = 7000;
	level.bettyJumpHeight = 55;*/

	level.bettyJumpHeight = 55;
	level.bettyDamageMax = 1000;
	level.bettyDamageMin = 800;

	level.bettyDamageHeight = level.bettyJumpHeight;

}

function proximityWeaponObjectDetonation_override( watcher )
{
	self endon( "death" );
	self endon( "hacked" );
	self endon( "kill_target_detection" );
	
	weaponobjects::proximityWeaponObject_ActivationDelay( watcher );
	
	damagearea = weaponobjects::proximityWeaponObject_CreateDamageArea( watcher );
	
	up = AnglesToUp( self.angles );
	traceOrigin = self.origin + up;
	
	if ( isdefined( level._bouncingBettyWatchForTrigger ) )
	{
		self thread [[level._bouncingBettyWatchForTrigger]]( watcher );
	}

	while(1)
	{
		damagearea waittill("trigger", ent);
	
		if ( !weaponobjects::proximityWeaponObject_ValidTriggerEntity( watcher, ent ) )
			continue;

		if ( weaponobjects::proximityWeaponObject_IsSpawnProtected( watcher, ent ) )
			continue;
			
		if ( ent damageConeTrace( traceOrigin, self ) > 0 )
		{
			//thread weaponobjects::proximityWeaponObject_WaitTillFrameEndAndDoDetonation( watcher, ent, traceOrigin );
			
			thread weaponobjects::proximityWeaponObject_DoDetonation( watcher, ent, traceOrigin );
		}
	}
}