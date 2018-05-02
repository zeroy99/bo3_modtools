#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\_destructible.gsh;

#namespace destructible;

REGISTER_SYSTEM( "destructible", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", DESTRUCTIBLE_CLIENTFIELD, VERSION_SHIP, DESTRUCTIBLE_CLIENTFIELD_NUM_BITS, "int", &doExplosion, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function playGrenadeRumble(  localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
	PlayRumbleOnPosition( localClientNum, "grenade_rumble", self.origin );
	GetLocalPlayer( localClientNum ) Earthquake( 0.5, 0.5, self.origin, 800 );
}

function doExplosion( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == 0 )
	{
		return;
	}
	
	physics_explosion = false;
	
	if( newVal & ( 1 << ( DESTRUCTIBLE_CLIENTFIELD_NUM_BITS - 1 ) ) )
	{
		physics_explosion = true;
		
		newVal -= ( 1 << ( DESTRUCTIBLE_CLIENTFIELD_NUM_BITS - 1 ) ) ;
	}
	
	physics_force = 0.3;
		
	if( physics_explosion )
	{
		PhysicsExplosionSphere( localClientNum, self.origin, newVal, newVal - 1, physics_force, 25, 400 );
	}

	playGrenadeRumble( localClientNum, self.origin );
}