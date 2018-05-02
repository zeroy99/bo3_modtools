#using scripts\codescripts\struct;

#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\math_shared;
#using scripts\shared\killstreaks_shared;

#using scripts\mp\gametypes\_battlechatter;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\teams\_teams;
#using scripts\mp\_util;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace satellite;

#define SATELLITE_NAME "satellite"
#define SATELLITE_KILLSTREAK_NAME "killstreak_satellite"
	
#precache( "string", "mpl_killstreak_satellite" );
#precache( "string", "KILLSTREAK_EARNED_SATELLITE" );
#precache( "string", "KILLSTREAK_SATELLITE_INBOUND" );
#precache( "string", "KILLSTREAK_DESTROYED_SATELLITE" );
#precache( "string", "KILLSTREAK_SATELLITE_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_SATELLITE_HACKED" );

function init()
{	
	if ( level.teamBased )
	{
		foreach( team in level.teams )
		{
			level.activeSatellites[ team ] = 0;
		}
	}
	else
	{	
		level.activeSatellites = [];
	}
	
	level.activePlayerSatellites = [];
	
	if ( tweakables::getTweakableValue( "killstreak", "allowradardirection" ) )
	{
		killstreaks::register( SATELLITE_NAME, SATELLITE_NAME, SATELLITE_KILLSTREAK_NAME, "uav_used", &ActivateSatellite );
		killstreaks::register_strings( SATELLITE_NAME, &"KILLSTREAK_EARNED_SATELLITE", &"KILLSTREAK_SATELLITE_NOT_AVAILABLE", &"KILLSTREAK_SATELLITE_INBOUND", undefined, &"KILLSTREAK_SATELLITE_HACKED" );
		killstreaks::register_dialog( SATELLITE_NAME, "mpl_killstreak_satellite", "satelliteDialogBundle", undefined, "friendlySatellite", "enemySatellite", "enemySatelliteMultiple", "friendlySatelliteHacked", "enemySatelliteHacked", "requestSatellite", "threatSatellite" );
	}
	
	callback::on_connect( &OnPlayerConnect );
	callback::on_spawned( &OnPlayerSpawned );
	
	level thread SatelliteTracker();
}

function OnPlayerConnect()
{
	self.entnum = self getEntityNumber();
	
	if ( !level.teamBased )
	{
		level.activeSatellites[ self.entnum ] = 0;
	}
	
	level.activePlayerSatellites[ self.entnum ] = 0;  // needed for satellite-related kill scores
}

function OnPlayerSpawned( local_client_num )
{
	if ( !level.teambased )
	{
		UpdatePlayerSatelliteForDM( self );
	}
}

function ActivateSatellite()
{
	if( self killstreakrules::isKillstreakAllowed( SATELLITE_NAME, self.team ) == false )
	{
		return false;
	}

	killstreak_id = self killstreakrules::killstreakStart( SATELLITE_NAME, self.team );
	if(  killstreak_id == -1 )
	{
		return false;
	}
	
	minFlyHeight = int( airsupport::getMinimumFlyHeight() );
	zOffset = minFlyHeight + SATELLITE_Z_OFFSET;
	
	// pick a random start point from map center
	travelAngle = RandomFloatRange( VAL( level.satellite_spawn_from_angle_min, SATELLITE_SPAWN_FROM_ANGLE_MIN ), VAL( level.satellite_spawn_from_angle_max, SATELLITE_SPAWN_FROM_ANGLE_MAX ) );
	travelRadius = airsupport::GetMaxMapWidth() * SATELLITE_TRAVEL_DISTANCE_SCALE;
	xOffset = sin( travelAngle ) * travelRadius;
	yOffset = cos( travelAngle ) * travelRadius;
	
	satellite = spawn( "script_model", airsupport::GetMapCenter() + ( xOffset, yOffset, zOffset ));
	satellite setModel( SATELLITE_MODEL );
	satellite SetScale( SATELLITE_MODEL_SCALE );
	
	satellite.killstreak_id = killstreak_id;
	satellite.owner = self;
	satellite.ownerEntNum = self GetEntityNumber();
	satellite.team = self.team;
	satellite setTeam( self.team );
	satellite setOwner( self );
	satellite killstreaks::configure_team( SATELLITE_NAME, killstreak_id, self, undefined, undefined, &ConfigureTeamPost );
	satellite killstreak_hacking::enable_hacking( SATELLITE_NAME, &HackedPreFunction, undefined );
	satellite.targetname = SATELLITE_NAME;
	satellite.maxhealth = SATELLITE_HEALTH;
	satellite.lowhealth = SATELLITE_LOW_HEALTH;	
	satellite.health = 99999;
	satellite.leaving = false;

	satellite SetCanDamage( true );
	satellite thread killstreaks::MonitorDamage( SATELLITE_NAME, satellite.maxhealth, &DestroySatellite, satellite.lowhealth, &OnLowHealth, 0, undefined, false );
	satellite thread killstreaks::WaitTillEMP( &DestroySatelliteByEMP );
	// satellite.overrideVehicleDamage = &SatelliteDamageOverride;	// satellite is not a vehicle right now
	satellite.killstreakDamageModifier = &killstreakDamageModifier;

	satellite.rocketDamage = ( satellite.maxhealth / SATELLITE_MISSILES_TO_DESTROY ) + 1;
	
	/#
	//Box( airsupport::GetMapCenter() + ( xOffset, yOffset, zOffset ), (-4, -4, 0 ), ( 4, 4, 5000 ), 0, ( 1, 0, 0 ), 0.6, false, 2000 );	
	//Box( airsupport::GetMapCenter() + ( -xOffset, -yoffset, zOffset ), (-4, -4, 0 ), ( 4, 4, 5000 ), 0, ( 0, 1, 0 ), 0.6, false, 2000 );	
	#/
	
	satellite MoveTo( airsupport::GetMapCenter() + ( -xOffset, -yoffset, zOffset ), SATELLITE_DURATION_MS * 0.001 );

	Target_Set( satellite );

	satellite clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	
	satellite thread killstreaks::WaitForTimeout( SATELLITE_NAME, SATELLITE_DURATION_MS, &OnTimeout, "death", "crashing" );
	
	satellite thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "death", undefined, true );
	
	satellite thread Rotate( SATELLITE_ROTATION_DURATION );
	
	self killstreaks::play_killstreak_start_dialog( SATELLITE_NAME, self.team, killstreak_id );
	satellite thread killstreaks::player_killstreak_threat_tracking( SATELLITE_NAME );
	self AddWeaponStat( GetWeapon( SATELLITE_NAME ), "used", 1 );

	return true;
}

function HackedPreFunction( hacker )
{
	satellite = self;
	satellite ResetActiveSatellite();
}

function ConfigureTeamPost( owner, isHacked )
{
	satellite = self;
	
	satellite thread teams::WaitUntilTeamChangeSingleTon( owner, "Satellite_watch_team_change", &OnTeamChange, self.entNum, "delete", "death", "leaving" );
	if ( isHacked == false )
	{
		satellite teams::HideToSameTeam();
	}
	else
	{
		satellite SetVisibleToAll();
	}
	satellite AddActiveSatellite();
}

function Rotate( duration )
{
	self endon( "death" );
	
	while( true )
	{
		self rotateyaw( -360, duration );
		wait( duration );
	}
}

function OnLowHealth( attacker, weapon )
{
}

function OnTeamChange( entNum, event )
{
	DestroySatellite( undefined, undefined );
}

function OnTimeout()
{
	self killstreaks::play_pilot_dialog_on_owner( "timeout", SATELLITE_NAME );
	
	self.leaving = true;
	self RemoveActiveSatellite();
	
	airsupport::Leave( UAV_EXIT_TIME );
	wait( UAV_EXIT_TIME );
	
	if( Target_IsTarget( self ) )
		Target_Remove( self );
	
	self delete();	
}

function DestroySatelliteByEMP( attacker, arg )
{
	DestroySatellite( attacker, GetWeapon( "emp" ) );
}

function DestroySatellite( attacker = undefined, weapon = undefined )
{
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if ( isdefined( attacker ) && ( !isdefined( self.owner ) || self.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, false );
		scoreevents::processScoreEvent( "destroyed_satellite", attacker, self.owner, weapon );
		attacker challenges::addFlySwatterStat( weapon, self );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_SATELLITE", attacker.entnum );
		if( !self.leaving )
			self killstreaks::play_destroyed_dialog_on_owner( SATELLITE_NAME, self.killstreak_id );
	}
	
	self notify( "crashing" );
	
	params = level.killstreakBundle[SATELLITE_NAME];
	if( isdefined( params.ksExplosionFX ) )	
		PlayFXOnTag( params.ksExplosionFX, self, "tag_origin" );
	
	self setModel( "tag_origin" );
	if( Target_IsTarget( self ) )
		Target_Remove( self );
	
	wait( 0.5 );
	
	if( !self.leaving )
		self RemoveActiveSatellite();
	
	self delete();
}

function HasSatellite( team_or_entnum )
{
	return level.activeSatellites[ team_or_entnum ] > 0;
}

function AddActiveSatellite()
{
	if ( level.teamBased )
	{
		level.activeSatellites[ self.team ]++;	
	}
	else
	{		
		level.activeSatellites[ self.ownerEntNum ]++;
	}
	
	level.activePlayerSatellites[ self.ownerEntNum ]++;

	level notify( "satellite_update" );
}

function RemoveActiveSatellite()
{
	self ResetActiveSatellite();

	killstreakrules::killstreakStop( SATELLITE_NAME, self.originalteam, self.killstreak_id );
}

function ResetActiveSatellite()
{
	if( level.teamBased )
	{
		level.activeSatellites[ self.team ]--;
		
		assert( level.activeSatellites[ self.team ] >= 0 );
		if( level.activeSatellites[ self.team ] < 0 )
		{
			level.activeSatellites[ self.team ] = 0;
		}
	}
	else if ( isdefined( self.ownerEntNum ) )
	{		
		level.activeSatellites[ self.ownerEntNum ]--;
		
		assert( level.activeSatellites[ self.ownerEntNum ] >= 0 );
		if( level.activeSatellites[ self.ownerEntNum ] < 0 )
		{
			level.activeSatellites[ self.ownerEntNum ] = 0;
		}
	}

	assert( isdefined( self.ownerEntNum ) );
	level.activePlayerSatellites[ self.ownerEntNum ]--;
	assert( level.activePlayerSatellites[ self.ownerEntNum ] >= 0 );

	level notify( "satellite_update" );
}

function SatelliteTracker()
{
	level endon ( "game_ended" );
	
	while( true )
	{
		level waittill ( "satellite_update" );
		
		// intentionally keeping both teambased and non-teambased logic for now
		// TODO: one "might" be able to change it to teambased only; when trying to do so, watch for knock-on effects
		
		if( level.teamBased )
		{
			foreach( team in level.teams )
			{
				activeSatellites = level.activeSatellites[ team ];
				activeSatellitesAndUAVs = activeSatellites + ( ( isdefined( level.activeUAVs ) ) ? level.activeUAVs[ team ] : 0 );

				SetTeamSatellite( team, ( activeSatellites > 0 ) );
				util::set_team_radar( team, ( activeSatellitesAndUAVs > 0 ) );	
			}
		}
		else
		{
			for( i = 0; i < level.players.size; i++ )
			{
				UpdatePlayerSatelliteForDM( level.players[ i ] );
			}
		}
	}
}

function UpdatePlayerSatelliteForDM( player )
{	
	if( !isdefined( player.entnum ) )
	{
		player.entnum = player getEntityNumber();
	}
	
	activeSatellites = level.activeSatellites[ player.entnum ];
	activeSatellitesAndUAVs = activeSatellites + ( ( isdefined( level.activeUAVs ) ) ? level.activeUAVs[ player.entnum ] : 0 );

	player SetClientUIVisibilityFlag( "radar_client", ( activeSatellitesAndUAVs > 0 ) );
	player.hasSatellite = ( activeSatellites > 0 );	
}

function killstreakDamageModifier( damage, attacker, direction, point, sMeansOfDeath, tagName, modelName, partname, weapon, flags, inflictor, chargeLevel )
{
	if( ( sMeansOfDeath == "MOD_PISTOL_BULLET" ) || ( sMeansOfDeath == "MOD_RIFLE_BULLET" ) )
		return 0;
	
	if ( sMeansOfDeath == "MOD_PROJECTILE_SPLASH" )
		return 0;
	
	return damage;
}
