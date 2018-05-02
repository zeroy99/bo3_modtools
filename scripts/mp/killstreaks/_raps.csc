#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\vehicles\_raps;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;

#insert scripts\mp\killstreaks\_killstreaks.gsh;

#precache( "client_fx", RAPS_HELI_DEATH_TRAIL_FX );

#namespace raps_mp;

#define RAPS_WHOOSH_BEFORE_IMPACT_TIME		( 0.15 )
#define RAPS_HALF_GRAVITY					( 386.088 / 2.0 )

REGISTER_SYSTEM( "raps_mp", &__init__, undefined )

function __init__()
{
	clientfield::register( "vehicle", "monitor_raps_drop_landing", VERSION_SHIP, 1, "int", &monitor__drop_landing_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "raps_heli_low_health", VERSION_SHIP, 1, "int", &heli_low_health_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "raps_heli_extra_low_health", VERSION_SHIP, 1, "int", &heli_extra_low_health_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}


function heli_low_health_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 0 )
		return;

	self endon( "entityshutdown" );

	vehicle::wait_for_DObj( localClientNum );
	
	PlayFxOnTag( localClientNum, RAPS_HELI_DEATH_TRAIL_FX, self, RAPS_HELI_DEATH_TRAIL_FX_TAG_B );
}

function heli_extra_low_health_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 0 )
		return;

	self endon( "entityshutdown" );

	vehicle::wait_for_DObj( localClientNum );
	
	PlayFxOnTag( localClientNum, RAPS_HELI_DEATH_TRAIL_FX, self, RAPS_HELI_DEATH_TRAIL_FX_TAG_C );
}

function monitor__drop_landing_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;
	
	self thread monitor_drop_landing( localClientNum );
}

function monitor_drop_landing( localClientNum )
{
	self endon( "entityshutdown" );
	
	self notify( "monitor_drop_landing_entity_singleton" );
	self endon( "monitor_drop_landing_entity_singleton" );

	a_trace = BulletTrace( self.origin + ( 0, 0, -200 ), self.origin + ( 0, 0, -5000 ), false, self, true );
	v_ground = a_trace[ "position" ];

	wait 0.5; // gain some speed
	whoosh_distance = 0;

	if( isdefined( v_ground ) )
	{
		// there is a "whoosh" sound just before the actual impact, so we need to detect the distance
		not_close_enough_to_ground = true;
		
		while( not_close_enough_to_ground )
		{
			velocity = self GetVelocity();
			whoosh_distance = max( whoosh_distance, ( Abs( velocity[2] ) * RAPS_WHOOSH_BEFORE_IMPACT_TIME ) + RAPS_HALF_GRAVITY * RAPS_WHOOSH_BEFORE_IMPACT_TIME * RAPS_WHOOSH_BEFORE_IMPACT_TIME );
			whoosh_distance_squared = whoosh_distance * whoosh_distance;

			distance_squared = DistanceSquared( self.origin, v_ground );

			not_close_enough_to_ground = ( distance_squared > whoosh_distance_squared );
			
			if ( not_close_enough_to_ground )
			{
				wait ( ( distance_squared > whoosh_distance_squared * 4 ) ? 0.1 : 0.05 );
			}	
		}
		
		self playsound( localClientNum, "veh_raps_first_land" );
	}

	// wait close enough to play fx, and rumble ( or z velocity hits zero )
	while( ( DistanceSquared( self.origin, v_ground ) > 24 * 24 ) || ( velocity[2] <= 0.0 ) )
	{
		velocity = self GetVelocity();
		WAIT_CLIENT_FRAME;
	}
	
	bundle = struct::get_script_bundle( "killstreak", "killstreak_" + RAPS_NAME );

	if ( isdefined( bundle ) && isdefined( bundle.ksDropDeployLandSurfaceFxTable ) && isdefined( a_trace[ "surfacetype" ] ) )
	{
		fx_to_play = GetFXFromSurfaceTable( bundle.ksDropDeployLandSurfaceFxTable, a_trace[ "surfacetype" ] );		
		if ( isdefined( fx_to_play ) )
		{
			PlayFX( localClientNum, fx_to_play, self.origin );	
		}
	}

	if ( isdefined( bundle ) && isdefined( bundle.ksDropDeployLandFx ) )
		PlayFX( localClientNum, bundle.ksDropDeployLandFx, self.origin );

	PlayRumbleOnPosition( localClientNum, "raps_land", self.origin );
}
