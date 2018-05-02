#using scripts\codescripts\struct;

#using scripts\shared\damagefeedback_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#namespace burnplayer;

REGISTER_SYSTEM( "burnplayer", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "burn", VERSION_SHIP, 1, "int" );
	clientfield::register( "playercorpse", "burned_effect", VERSION_SHIP, 1, "int" );
}

//self is burning player
function SetPlayerBurning( duration, interval, damagePerInterval, attacker, weapon )
{
	self clientfield::set( "burn", 1 );

	self thread WatchBurnTimer( duration );
	self thread WatchBurnDamage( interval, damagePerInterval, attacker, weapon );
	self thread WatchForWater();
	self thread WatchBurnFinished();
	self playloopsound ("chr_burn_loop_overlay");
}

function TakingBurnDamage( eAttacker, weapon, sMeansOfDeath )
{
	// dont allow the damage to recurse
	if ( IsDefined(self.doing_scripted_burn_damage) )
	{
		// clear the flag here so its cleared if the player dies
		self.doing_scripted_burn_damage = undefined;
		return;
	}
		
	if ( weapon == level.weaponNone )
		return;
		
	if ( weapon.burnDuration == 0 )
		return;

	self burnplayer::SetPlayerBurning( ( weapon.burnDuration / 1000 ), ( weapon.burnDamageInterval / 1000 ), weapon.burnDamage, eAttacker, weapon );
}

function WatchBurnFinished()
{
	self endon( "disconnect" );
	
	self util::waittill_any( "death", "burn_finished" );
	
	self clientfield::set("burn", 0 );
	self stoploopsound(1);

}

function WatchBurnTimer( duration )
{
	self notify( "BurnPlayer_WatchBurnTimer" );
	self endon( "BurnPlayer_WatchBurnTimer" );
	self endon( "disconnect" );
	self endon( "death" );
	
	wait( duration );
	self notify( "burn_finished" );
}

function WatchBurnDamage( interval, damage, attacker, weapon )
{
	if ( damage == 0 )
		return;
		
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "BurnPlayer_WatchBurnTimer" ); // Prevent damage stacking
	
	self endon( "burn_finished" );
	
	while( 1 )
	{
		wait( interval );
		self.doing_scripted_burn_damage = true;
		self dodamage( damage, self.origin, attacker, undefined, undefined, "MOD_BURNED", 0,weapon );
		self.doing_scripted_burn_damage = undefined;
	}
}

function watchForWater()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	self endon( "burn_finished" );
	
	while( 1 )
	{
		if( self IsPlayerUnderwater() )
		{
			self notify( "burn_finished" );
		}
		
		wait( .05 );
	}
}