#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_tacticalinsertion;

#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\gametypes\_spawnlogic;


#using scripts\mp\_util;
#using scripts\mp\killstreaks\_airsupport;

#namespace spawning;

REGISTER_SYSTEM( "perks", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "flying", VERSION_SHIP, 1, "int" );
	
	callback::on_connect( &on_player_connect );
	callback::on_spawned( &on_player_spawned );
}

function on_player_connect( local_client_num )
{
}

function on_player_spawned( local_client_num )
{
	self thread monitorGPSJammer();
	self thread monitorSenGrenJammer();
	self thread monitorFlight();
}

function monitorFlight()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	self.flying = false; 
	while( IsDefined(self) )
	{
		flying = !( self isOnGround() );
		if ( self.flying != flying ) 
		{
			self clientfield::set("flying",flying);
			self.flying = flying;
		}

		WAIT_SERVER_FRAME;
	}
}

function monitorGPSJammer()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	
	require_perk = true; 
	
	if ( require_perk && self HasPerk( "specialty_gpsjammer" ) == false ) 
		return;

	self clientfield::set( CLIENT_FIELD_FLAG_GPS_JAMMER_ACTIVE, ( self HasPerk( "specialty_gpsjammer" ) ? 1 : 0 ) );
	gracePeriods = GetDvarInt( "perk_gpsjammer_graceperiods", 4 );
	minspeed = GetDvarInt( "perk_gpsjammer_min_speed", 100 );
	mindistance = GetDvarInt( "perk_gpsjammer_min_distance", 10 );
	timePeriod = GetDvarInt( "perk_gpsjammer_time_period", 200 );
	timePeriodSec = timePeriod/1000;
	minspeedSq = minspeed * minspeed;
	mindistanceSq = mindistance * mindistance;

	if ( minspeedSq == 0 ) // will never fail min speed check below so early out.  
		return;
	
	assert ( timePeriodSec >= 0.05 );
	if ( timePeriodSec < 0.05 ) 
		return;
	
	hasPerk = true;
	stateChange = false;
	failedDistanceCheck = false;
	currentFailCount = 0;
	timePassed = 0;
	timeSinceDistanceCheck = 0;
	previousOrigin = self.origin;
	GPSJammerProtection = false;

	while(1)
	{
		GPSJammerProtection = false;
		if ( util::isUsingRemote() || IS_TRUE( self.isPlanting ) || IS_TRUE( self.isDefusing ) )
		{
			GPSJammerProtection = true;
		}
		else
		{
			if ( timeSinceDistanceCheck > 1 )
			{
				timeSinceDistanceCheck = 0;
				if ( DistanceSquared( previousOrigin, self.origin ) < mindistanceSq )
				{
					failedDistanceCheck = true;
				}
				else
				{
					failedDistanceCheck = false;
				}
				previousOrigin = self.origin;
			}
			velocity = self GetVelocity();

			speedsq = lengthsquared( velocity );
		
			if ( speedSq > minspeedSq && failedDistanceCheck == false )
			{
				GPSJammerProtection = true;
			}
		}

		if ( GPSJammerProtection == true && self HasPerk( "specialty_gpsjammer" ) )
		{
			currentFailCount = 0;
			if ( hasPerk == false ) 
			{
				stateChange = false;
				hasPerk = true;
				self clientfield::set( CLIENT_FIELD_FLAG_GPS_JAMMER_ACTIVE, 1 );
			}
		}
		else
		{
			currentFailCount++;

			if ( hasPerk == true && currentFailCount >= gracePeriods ) 
			{
				stateChange = true;
				hasPerk = false;
				self clientfield::set( CLIENT_FIELD_FLAG_GPS_JAMMER_ACTIVE, 0 );
			}
		}
		if ( stateChange == true ) 
		{
			level notify("radar_status_change");
		}
		timeSinceDistanceCheck += timePeriodSec;
		wait( timePeriodSec );
	}
}

function monitorSenGrenJammer()
{
	self endon( "death" );
	self endon( "disconnect" );

	require_perk = true; 
	
	if ( require_perk && self HasPerk( "specialty_sengrenjammer" ) == false )
		return;

	self clientfield::set( CLIENT_FIELD_FLAG_SG_JAMMER_ACTIVE, ( self HasPerk( "specialty_sengrenjammer" ) ? 1 : 0 ) );
	gracePeriods = GetDvarInt( "perk_sgjammer_graceperiods", 4 );
	minspeed = GetDvarInt( "perk_sgjammer_min_speed", 100 );
	mindistance = GetDvarInt( "perk_sgjammer_min_distance", 10 );
	timePeriod = GetDvarInt( "perk_sgjammer_time_period", 200 );
	timePeriodSec = timePeriod/1000;
	minspeedSq = minspeed * minspeed;
	mindistanceSq = mindistance * mindistance;

	if ( minspeedSq == 0 ) // will never fail min speed check below so early out.  
		return;
	
	assert ( timePeriodSec >= 0.05 );
	if ( timePeriodSec < 0.05 ) 
		return;
	
	hasPerk = true;
	stateChange = false;
	failedDistanceCheck = false;
	currentFailCount = 0;
	timePassed = 0;
	timeSinceDistanceCheck = 0;
	previousOrigin = self.origin;
	SGJammerProtection = false;

	while(1)
	{
		SGJammerProtection = false;
		if ( util::isUsingRemote() || IS_TRUE( self.isPlanting ) || IS_TRUE( self.isDefusing ) )
		{
			SGJammerProtection = true;
		}
		else
		{
			if ( timeSinceDistanceCheck > 1 )
			{
				timeSinceDistanceCheck = 0;
				if ( DistanceSquared( previousOrigin, self.origin ) < mindistanceSq )
				{
					failedDistanceCheck = true;
				}
				else
				{
					failedDistanceCheck = false;
				}
				previousOrigin = self.origin;
			}
			velocity = self GetVelocity();

			speedsq = lengthsquared( velocity );
		
			if ( speedSq > minspeedSq && failedDistanceCheck == false )
			{
				SGJammerProtection = true;
			}
		}

		if ( SGJammerProtection == true && self HasPerk( "specialty_sengrenjammer" ) )
		{
			currentFailCount = 0;
			if ( hasPerk == false ) 
			{
				stateChange = false;
				hasPerk = true;
				self clientfield::set( CLIENT_FIELD_FLAG_SG_JAMMER_ACTIVE, 1 );
			}
		}
		else
		{
			currentFailCount++;

			if ( hasPerk == true && currentFailCount >= gracePeriods ) 
			{
				stateChange = true;
				hasPerk = false;
				self clientfield::set( CLIENT_FIELD_FLAG_SG_JAMMER_ACTIVE, 0 );
			}
		}
		if ( stateChange == true ) 
		{
			level notify("radar_status_change");
		}
		timeSinceDistanceCheck += timePeriodSec;
		wait( timePeriodSec );
	}
}

