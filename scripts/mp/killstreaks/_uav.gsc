#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;

#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\teams\_teams;
#using scripts\mp\_util;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "eventstring", "mpl_killstreak_radar" );
#precache( "string", "KILLSTREAK_EARNED_RADAR" );
#precache( "string", "KILLSTREAK_RADAR_INBOUND" );
#precache( "string", "KILLSTREAK_RADAR_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_DESTROYED_UAV" );
#precache( "string", "KILLSTREAK_RADAR_HACKED" );

#precache( "fx", "killstreaks/fx_uav_damage_trail" );
#precache( "fx", "killstreaks/fx_uav_lights" ); 
#precache( "fx", "killstreaks/fx_uav_bunner" );

#define UAV_NAME "uav"
	
#namespace uav;
	
function init()
{	
	if ( level.teamBased )
	{
		foreach( team in level.teams )
		{
			level.activeUAVs[ team ] = 0;
		}
	}
	else
	{	
		level.activeUAVs = [];
	}
	
	level.activePlayerUAVs = [];
	level.spawnedUAVs = [];

	if ( tweakables::getTweakableValue( "killstreak", "allowradar" ) )
	{
		killstreaks::register( UAV_NAME, UAV_NAME, "killstreak_uav", "uav_used", &ActivateUAV );
		killstreaks::register_strings( UAV_NAME, &"KILLSTREAK_EARNED_RADAR", &"KILLSTREAK_RADAR_NOT_AVAILABLE", &"KILLSTREAK_RADAR_INBOUND", undefined, &"KILLSTREAK_RADAR_HACKED" );
		killstreaks::register_dialog( UAV_NAME, "mpl_killstreak_radar", "uavDialogBundle", "uavPilotDialogBundle", "friendlyUav", "enemyUav", "enemyUavMultiple", "friendlyUavHacked", "enemyUavHacked", "requestUav", "threatUav" );
	}
	
	level thread UAVTracker();
	
	callback::on_connect( &OnPlayerConnect );
	callback::on_spawned( &OnPlayerSpawned );
	callback::on_joined_team( &OnPlayerJoinedTeam );
	
	setMatchFlag( "radar_allies", 0 );
	setMatchFlag( "radar_axis", 0 );
}

function HackedPreFunction( hacker )
{
	uav = self;
	uav ResetActiveUAV();
}

function ConfigureTeamPost( owner, isHacked )
{
	uav = self;
	uav thread teams::WaitUntilTeamChangeSingleTon( owner, "UAV_watch_team_change", &OnTeamChange, owner.entNum, "delete", "death", "leaving" );
	if ( isHacked == false )
	{
		uav teams::HideToSameTeam();
	}
	else
	{
		uav SetVisibleToAll();
	}
	owner AddActiveUAV();
}

function ActivateUAV()
{
	assert( isdefined( level.players ) );
	
	if ( self killstreakrules::isKillstreakAllowed( UAV_NAME, self.team ) == false )
	{
		return false;
	}
	
	killstreak_id = self killstreakrules::killstreakStart( UAV_NAME, self.team );
	if (  killstreak_id == -1 )
	{
		return false;
	}
	
	rotator = level.airsupport_rotator;
	attach_angle = -90;
	
	uav = spawn( "script_model", rotator getTagOrigin( "tag_origin" ) );
	ARRAY_ADD( level.spawnedUAVs, uav );

	uav setModel( UAV_MODEL );
	
	uav.targetname = UAV_NAME;
	
	uav killstreaks::configure_team( UAV_NAME, killstreak_id, self, undefined, undefined, &ConfigureTeamPost );
	uav killstreak_hacking::enable_hacking( UAV_NAME, &HackedPreFunction, undefined );
	
	uav clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	killstreak_detect::killstreakTargetSet( uav );
	
	uav SetDrawInfrared( true );
	
	uav.killstreak_id = killstreak_id;
	uav.leaving = false;
	uav.health = 99999;
	
	uav.maxhealth = UAV_HEALTH;
	uav.lowhealth = UAV_LOW_HEALTH;
	
	uav SetCanDamage( true );
	uav thread killstreaks::MonitorDamage( UAV_NAME, uav.maxhealth, &DestroyUAV, uav.lowhealth, &OnLowHealth, 0, undefined, true );

	uav thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "crashing", undefined, true );
	uav.rocketDamage = uav.maxhealth + 1;
	
	minFlyHeight = int( airsupport::getMinimumFlyHeight() );
	zOffset = minFlyHeight + VAL( level.uav_z_offset, UAV_Z_OFFSET );
	
	angle = randomInt( 360 );
	radiusOffset = VAL( level.uav_rotation_radius, UAV_ROTATION_RADIUS ) + randomInt( VAL( level.uav_rotation_random_offset, UAV_ROTATION_RANDOM_OFFSET ) );
	xOffset = cos( angle ) * radiusOffset;
	yOffset = sin( angle ) * radiusOffset;
	angleVector = vectorNormalize( ( xOffset, yOffset, zOffset ) );
	angleVector = angleVector * zOffset;
	uav linkTo( rotator, "tag_origin", angleVector, ( 0, angle + attach_angle, 0 ) );
	
	self AddWeaponStat( GetWeapon( UAV_NAME ), "used", 1 );

	uav thread killstreaks::WaitForTimeout( UAV_NAME, UAV_DURATION, &OnTimeout, "delete", "death", "crashing" );
	uav thread killstreaks::WaitForTimecheck( UAV_DURATION_CHECK, &OnTimecheck, "delete", "death", "crashing" );
	
	uav thread StartUAVFx();
	
	self killstreaks::play_killstreak_start_dialog( UAV_NAME, self.team, killstreak_id );
	
	uav killstreaks::play_pilot_dialog_on_owner( "arrive", UAV_NAME, killstreak_id );
	uav thread killstreaks::player_killstreak_threat_tracking( UAV_NAME );
	
	return true;
}

function OnLowHealth( attacker, weapon )
{
	self.is_damaged = true;
	params = level.killstreakBundle[UAV_NAME];
	if( isdefined( params.fxLowHealth ) )
		PlayFXOnTag( params.fxLowHealth, self, "tag_origin" );
}

function OnTeamChange( entNum, event )
{
	DestroyUAV( undefined, undefined );
}

function DestroyUAV( attacker, weapon )
{	
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if( isdefined( attacker ) && ( !isdefined( self.owner ) ||  self.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, false );
		scoreevents::processScoreEvent( "destroyed_uav", attacker, self.owner, weapon );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_UAV", attacker.entnum );
		attacker challenges::addFlySwatterStat( weapon, self );
	}
	
	if( !self.leaving )
	{
		self RemoveActiveUAV();
		
		self killstreaks::play_destroyed_dialog_on_owner( UAV_NAME, self.killstreak_id );
	}
	
	self notify( "crashing" );
	
	self playsound ( "evt_helicopter_midair_exp" );
	
	params = level.killstreakBundle[UAV_NAME];
	if( isdefined( params.ksExplosionFX ) )
		PlayFXOnTag( params.ksExplosionFX, self, "tag_origin" );
	
	self StopLoopSound();
	self setModel( "tag_origin" );
	Target_Remove( self );
	self unlink();

	wait( 0.5 );
	
	ArrayRemoveValue( level.spawnedUAVs, self );
	self notify( "delete" );
	self delete();
}

function OnPlayerConnect()
{
	self.entNum = self getEntityNumber();
	
	if ( !level.teambased )
	{
		level.activeUAVs[ self.entNum ] = 0;
	}
	
	level.activePlayerUAVs[ self.entNum ] = 0; // needed for UAV-related kill scores
}

function OnPlayerSpawned()
{
	self endon( "disconnect" );
	if( level.teambased == false || level.multiteam == true )
	{	
		level notify( "uav_update" );
	}
}

function OnPlayerJoinedTeam()
{
	HideAllUAVsToSameTeam();
}

function OnTimeout()
{
	PlayAfterburnerFx();
	
	if( IS_TRUE( self.is_damaged ) )
	{
		PlayFxOnTag( FX_UAV_DAMAGE_TRAIL, self, "tag_body" );
	}

	self killstreaks::play_pilot_dialog_on_owner( "timeout", UAV_NAME );
	
	self.leaving = true;
	self RemoveActiveUAV();	
	
	airsupport::Leave( UAV_EXIT_TIME );
	wait( UAV_EXIT_TIME );
	
	Target_Remove( self );
	ArrayRemoveValue( level.spawnedUAVs, self );
	self delete();
}

function OnTimecheck()
{
	self killstreaks::play_pilot_dialog_on_owner( "timecheck", UAV_NAME, self.killstreak_id );
}

function StartUAVFx()
{
	self endon( "death" );
	wait ( 0.1 );
	
	if( isdefined( self ) )
	{
		PlayFXOnTag( FX_UAV_LIGHTS, self, "tag_origin" );	
		PlayFXOnTag( FX_UAV_BURNER, self, "tag_origin" );		
		self PlayLoopSound ("veh_uav_engine_loop", 1);		
	}
}

function PlayAfterburnerFx()
{
	self endon( "death" );
	wait ( 0.1 );
	
	if( isdefined( self ) )
	{
		PlayFXOnTag( FX_UAV_BURNER, self, "tag_origin" );		
		self StopLoopSound();
		team = util::getOtherTeam( self.team );
		self playsoundtoteam ( "veh_kls_uav_afterburner" , team );
	}
}

function HasUAV( team_or_entnum )
{
	return level.activeUAVs[ team_or_entnum ] > 0;
}

function AddActiveUAV()
{
	if ( level.teamBased )
	{
		assert( isdefined( self.team ) );
		level.activeUAVs[self.team]++;	
	}
	else
	{
		assert( isdefined( self.entNum ) );
		if ( !isdefined( self.entNum ) )
		{
			self.entNum = self GetEntityNumber();
		}
		
		level.activeUAVs[ self.entNum ]++;
	}

	level.activePlayerUAVs[ self.entNum ]++;

	level notify ( "uav_update" );
}

function RemoveActiveUAV()
{
	uav = self;
	uav ResetActiveUAV();
	uav killstreakrules::killstreakStop( UAV_NAME, self.originalteam, self.killstreak_id );	
}

function ResetActiveUAV()
{
	if ( level.teamBased )
	{
		level.activeUAVs[self.team]--;
		assert( level.activeUAVs[self.team] >= 0 );
		
		if( level.activeUAVs[self.team] < 0 )
		{
			level.activeUAVs[self.team] = 0;
		}
	}
	else if( isdefined( self.owner ) )
	{
		assert( isdefined( self.owner.entNum ) );
		if( !isdefined( self.owner.entNum ) )
		{
			self.owner.entNum = self.owner getEntityNumber();
		}
		
		level.activeUAVs[self.owner.entNum]--;
		
		assert( level.activeUAVs[self.owner.entNum] >= 0 );
		if( level.activeUAVs[self.owner.entNum] < 0 )
		{
			level.activeUAVs[self.owner.entNum] = 0;
		}
	}
	
	if ( isdefined( self.owner ) )
	{		
		level.activePlayerUAVs[self.owner.entNum]--;
		assert( level.activePlayerUAVs[self.owner.entNum] >= 0 );
	}
	level notify ( "uav_update" );
}

function UAVTracker()
{
	level endon ( "game_ended" );
	
	while( true )
	{
		level waittill ( "uav_update" );
		
		// intentionally keeping both teambased and non-teambased logic for now
		// TODO: one "might" be able to change it to teambased only; when trying to do so, watch for knock-on effects

		if( level.teamBased )
		{
			foreach( team in level.teams )
			{
				activeUAVs = level.activeUAVs[ team ];
				activeUAVsAndSatellites = activeUAVs + ( ( isdefined( level.activeSatellites ) ) ? level.activeSatellites[ team ] : 0 );
			
				SetTeamSpyplane( team, int( min( activeUAVs, 2 ) ) );
				util::set_team_radar( team, ( activeUAVsAndSatellites > 0 ) );
			}
		}
		else
		{
			for( i = 0; i < level.players.size; i++ )
			{
				player = level.players[ i ];
				
				assert( isdefined( player.entNum ) );
				if( !isdefined( player.entNum ) )
				{
					player.entNum = player getEntityNumber();
				}
				
				activeUAVs = level.activeUAVs[ player.entNum ];
				activeUAVsAndSatellites = activeUAVs + ( ( isdefined( level.activeSatellites ) ) ? level.activeSatellites[ player.entnum ] : 0 );

				player SetClientUIVisibilityFlag( "radar_client", ( activeUAVsAndSatellites > 0  ) );
				player.hasSpyplane = int( min( activeUAVs, 2 ) );
			}
		}
	}
}

function HideAllUAVsToSameTeam()
{
	foreach( uav in level.spawnedUAVs )
	{
		if ( isdefined( uav ) )
		{
			
			uav teams::HideToSameTeam();
		}
	}
}