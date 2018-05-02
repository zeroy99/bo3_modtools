#using scripts\codescripts\struct;

#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_satellite;
#using scripts\mp\killstreaks\_planemortar;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\shared\weapons\_hacker_tool;
#using scripts\mp\killstreaks\_killstreak_hacking;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace drone_strike;
#define DRONE_STRIKE_NAME "drone_strike"

#precache( "locationselector", "map_directional_selector" );
#precache( "string", "KILLSTREAK_DRONE_STRIKE_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_DRONE_STRIKE_EARNED" );
#precache( "string", "KILLSTREAK_DRONE_STRIKE_INBOUND" );
#precache( "string", "KILLSTREAK_DRONE_STRIKE_INBOUND_NEAR_PLAYER" );
#precache( "string", "KILLSTREAK_DRONE_STRIKE_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_ROLLING_THUNDER_DRONE" );
#precache( "string", "KILLSTREAK_DESTROYED_ROLLING_THUNDER_ALL_DRONES" );

#precache( "eventstring", "mpl_killstreak_DRONE_STRIKE" );
#precache( "fx", "killstreaks/fx_rolling_thunder_thruster_trails" );
	
function init()
{
	killstreaks::register( DRONE_STRIKE_NAME, DRONE_STRIKE_NAME, "killstreak_drone_strike", "drone_strike_used", &ActivateDroneStrike, true );
	killstreaks::register_strings( DRONE_STRIKE_NAME, &"KILLSTREAK_DRONE_STRIKE_EARNED", &"KILLSTREAK_DRONE_STRIKE_NOT_AVAILABLE", &"KILLSTREAK_DRONE_STRIKE_INBOUND", &"KILLSTREAK_DRONE_STRIKE_INBOUND_NEAR_PLAYER", &"KILLSTREAK_DRONE_STRIKE_HACKED" );
	killstreaks::register_dialog( DRONE_STRIKE_NAME, "mpl_killstreak_drone_strike", "droneStrikeDialogBundle", undefined, "friendlyDroneStrike", "enemyDroneStrike", "enemyDroneStrikeMultiple", "friendlyDroneStrikeHacked", "enemyDroneStrikeHacked", "requestDroneStrike", "threatDroneStrike" );
	killstreaks::set_team_kill_penalty_scale( DRONE_STRIKE_NAME, level.teamKillReducedPenalty );
}

function ActivateDroneStrike()
{
	if ( self killstreakrules::isKillstreakAllowed( DRONE_STRIKE_NAME, self.team ) == false )
	{
		return false;
	}
	
	result = self SelectDroneStrikePath();
	
	if ( !isdefined( result ) || !result )
	{
		return false;
	}
	
	return true;
}

function SelectDroneStrikePath()
{
	self BeginLocationNapalmSelection( DRONE_STRIKE_LOCATION_SELECTOR );
	self.selectingLocation = true;
	self thread airsupport::EndSelectionThink();

	locations = [];
	if( !isdefined( self.pers["drone_strike_radar_used"] ) || !self.pers["drone_strike_radar_used"] )
	{
		self thread planemortar::SingleRadarSweep();
	}
	
	location = self WaitForLocationSelection();

	// if the player gets disconnected, self will be undefined
	if( !isdefined( self ) )
	{
	   return false;
	}
	   
	if ( !isdefined( location.origin ) )
	{
		self.pers["drone_strike_radar_used"] = true;
		self notify( "cancel_selection" );
		return false;
	}

	if ( self killstreakrules::isKillstreakAllowed( DRONE_STRIKE_NAME, self.team ) == false)
	{
		self.pers["drone_strike_radar_used"] = true;
		self notify("cancel_selection");
		return false;
	}

	self.pers["drone_strike_radar_used"] = false;
	return self airsupport::finishHardpointLocationUsage( location, &DroneStrikeLocationSelected );
}

function WaitForLocationSelection()
{
	self endon( "emp_jammed" );
	self endon( "emp_grenaded" );

	self waittill( "confirm_location", location, yaw );
	
	locationInfo = SpawnStruct();
	locationInfo.origin = location;
	locationInfo.yaw = yaw;
	
	return locationInfo;
}

function DroneStrikeLocationSelected( location )
{
	team = self.team;
	killstreak_id = self killstreakrules::killstreakStart( DRONE_STRIKE_NAME, team, false, true );
	if( killstreak_id == INVALID_KILLSTREAK_ID )
	{
		return false;
	}
	
	self killstreaks::play_killstreak_start_dialog( DRONE_STRIKE_NAME, team, killstreak_id );
	self AddWeaponStat( GetWeapon( "drone_strike" ), "used", 1 );
	
	spawn_influencer = level spawning::create_enemy_influencer( "artillery", location.origin, team );
	
	self thread WatchForKillstreakEnd( team, spawn_influencer, killstreak_id );
	self thread StartDroneStrike( location.origin, location.yaw, team, killstreak_id );
	
	return true;
}

function WatchForKillstreakEnd( team, influencer, killstreak_id )
{
	self util::waittill_any( "disconnect", "joined_team", "joined_spectators", "drone_strike_complete", "emp_jammed" );
	killstreakrules::killstreakStop( DRONE_STRIKE_NAME, team, killstreak_id );
}

function StartDroneStrike( position, yaw, team, killstreak_id )
{
	self endon( "emp_jammed" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );
	self endon( "disconnect" );

	angles = ( 0, yaw, 0 );
	direction = AnglesToForward( angles );
	height = airsupport::getMinimumFlyHeight() + DRONE_STRIKE_Z_OFFSET;
	
	selectedPosition = ( position[0], position[1], height );
	startPoint = selectedPosition + VectorScale( direction, DRONE_STRIKE_START_OFFSET );
	endPoint = selectedPosition + VectorScale( direction, DRONE_STRIKE_END_OFFSET );
	
	// trace to get the target point
	traceStartPos = ( position[0], position[1], height );
	traceEndPos = ( position[0], position[1], -height ); 
	trace = BulletTrace( traceStartPos, traceEndPos, 0, undefined );
	targetPoint = ( ( trace[ "fraction" ] < 1.0 ) ? trace[ "position" ] : ( position[0], position[1], 0.0 ) );
	
	initialOffset = -VectorScale( direction, ( ( DRONE_STRIKE_COUNT * 0.5 ) - 1 ) * DRONE_STRIKE_FORWARD_OFFSET );
	
	for( i = 0; i < DRONE_STRIKE_COUNT; i++ )
	{
		right = AnglesToRight( angles );
		rightOffset = VectorScale( right, DRONE_STRIKE_RIGHT_OFFSET );
		leftOffset = VectorScale( right, DRONE_STRIKE_LEFT_OFFSET );
		forwardOffset = endPoint + initialOffset + VectorScale( direction, i * DRONE_STRIKE_FORWARD_OFFSET );
		
		self thread SpawnDrone( startPoint + rightOffset, forwardOffset + rightOffset, targetPoint, angles, self.team, killstreak_id );
		self thread SpawnDrone( startPoint - rightOffset, forwardOffset - rightOffset, targetPoint, angles, self.team, killstreak_id );
		self thread SpawnDrone( startPoint + leftOffset, forwardOffset + leftOffset, targetPoint, angles, self.team, killstreak_id );
		wait( DRONE_STRIKE_SPAWN_INTERVAL );
		
		self playsound ("mpl_thunder_flyover_wash");
	}
	
	wait( 3 ); //Wait for the last drone to explode
	self notify( "drone_strike_complete" );
}

function SpawnDrone( startPoint, endPoint, targetPoint, angles, team, killstreak_id )
{
	drone = SpawnPlane( self, "script_model", startPoint );
	drone.team = team;
	drone.targetname = "drone_strike";
	drone SetOwner( self );
	drone.owner = self;
	drone.owner thread WatchOwnerEvents( drone );
	drone killstreaks::configure_team( DRONE_STRIKE_NAME, killstreak_id, self );
	drone killstreak_hacking::enable_hacking( DRONE_STRIKE_NAME );
	Target_Set( drone );
	
	drone endon( "delete" );
	drone endon( "death" );
	
	drone.angles = angles;
	drone SetModel( DRONE_STRIKE_MODEL );
	drone SetEnemyModel( DRONE_STRIKE_MODEL );
	drone NotSolid();
	
	PlayFxOnTag( "killstreaks/fx_rolling_thunder_thruster_trails", drone, "tag_fx");
	drone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	
	drone SetupDamageHandling();
	drone thread WatchForEmp( self );
	
	drone MoveTo( endpoint, DRONE_STRIKE_FLIGHT_TIME, 0, 0 );				
	wait ( DRONE_STRIKE_FLIGHT_TIME );
	
	weapon = GetWeapon( "drone_strike" );
	velocity = drone GetVelocity();
	
	halfGravity = 386;
	dXY = Abs( DRONE_STRIKE_END_OFFSET );
	dZ = endPoint[2] - targetPoint[2];
	dVxy = dXY * sqrt( halfGravity / dZ );
	
	nvel = VectorNormalize( velocity );
	launchVel = nvel * dVxy;
	
	bomb = self LaunchBomb( weapon, drone.origin, launchVel );
	
	Target_Set( bomb );
	
	bomb killstreaks::configure_team( DRONE_STRIKE_NAME, killstreak_id, self );
	bomb killstreak_hacking::enable_hacking( DRONE_STRIKE_NAME );
	drone notify( "hackertool_update_ent", bomb );
	
	bomb clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );	
	bomb.targetname = "drone_strike";
	bomb SetOwner( self );
	bomb.owner = self;
	bomb.team = team;
	bomb playsound( "mpl_thunder_incoming_start" );
	bomb SetupDamageHandling();
	bomb thread WatchForEmp( self );
	
	bomb.owner thread WatchOwnerEvents( bomb );
	WAIT_SERVER_FRAME;
	
	drone Hide();
	
	WAIT_SERVER_FRAME;
	
	drone Delete();
}

function SetupDamageHandling()
{
	drone = self;
	drone SetCanDamage( true );
	drone.maxhealth = killstreak_bundles::get_max_health( DRONE_STRIKE_NAME );
	drone.lowhealth = killstreak_bundles::get_low_health( DRONE_STRIKE_NAME );
	drone.health = drone.maxhealth;
	drone thread killstreaks::MonitorDamage( DRONE_STRIKE_NAME, drone.maxhealth, &DestroyDronePlane, drone.lowhealth, undefined, 0, &EmpDamageDrone, true );
}

function DestroyDronePlane( attacker, weapon )
{	
	self endon( "death" );

	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if( isdefined( attacker ) && ( !isdefined( self.owner ) ||  self.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, false );
		attacker challenges::addFlySwatterStat( weapon, self );
		scoreevents::processScoreEvent( "destroyed_rolling_thunder_drone", attacker, self.owner, weapon );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_ROLLING_THUNDER_DRONE", attacker.entnum );
	}
	
	params = level.killstreakBundle[DRONE_STRIKE_NAME];
	if( isdefined( params.ksExplosionFX ) )
		PlayFXOnTag( params.ksExplosionFX, self, "tag_origin" );
	
	self setModel( "tag_origin" );

	wait( 0.5 );

	self delete();
}

function WatchOwnerEvents( bomb )
{
	player = self;
	
	bomb endon( "death" );
	
	player util::waittill_any( "disconnect", "joined_team", "joined_spectators" );
	
	if( isdefined( isalive( bomb ) ) )
		bomb delete();
}

function WatchForEmp( owner )
{
	self endon( "delete" );
	self endon( "death" );
	
	self waittill( "emp_deployed", attacker );

	thread DroneStrikeAwardEMPScoreEvent( attacker, self );
	self BlowUpDroneStrike();
}

function EmpDamageDrone( attacker )
{
	thread DroneStrikeAwardEMPScoreEvent( attacker, self );
	self BlowUpDroneStrike();
}

function DroneStrikeAwardEMPScoreEvent( attacker, victim )
{
	owner = self.owner;
	
	attacker endon( "disconnect" );
	attacker notify( "DroneStrikeAwardScoreEvent_singleton" );
	attacker endon( "DroneStrikeAwardScoreEvent_singleton" );
	waittillframeend;
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	scoreevents::processScoreEvent( "destroyed_rolling_thunder_all_drones", attacker, victim, GetWeapon( "emp" ) );
	challenges::destroyedAircraft( attacker, GetWeapon( "emp" ), false );
	attacker challenges::addFlySwatterStat( GetWeapon( "emp" ), self );
	LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_ROLLING_THUNDER_ALL_DRONES", attacker.entnum );

	owner globallogic_audio::play_taacom_dialog( "destroyed", DRONE_STRIKE_NAME );
}

function BlowUpDroneStrike()
{
	params = level.killstreakBundle[DRONE_STRIKE_NAME];
	if( isdefined( self ) && isdefined( params.ksExplosionFX ) )
		PlayFX( params.ksExplosionFX, self.origin );
	self delete();
}
