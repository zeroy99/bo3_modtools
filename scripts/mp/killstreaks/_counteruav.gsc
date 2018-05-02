#using scripts\codescripts\struct;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_battlechatter;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_satellite;
#using scripts\mp\teams\_teams;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define COUNTER_UAV_NAME "counteruav"
#define COUNTER_UAV_VEHICLE_NAME "veh_counteruav_mp"
#define COUNTER_UAV_KILLSTREAK_NAME "killstreak_counteruav"

#namespace counteruav;

#precache( "string", "KILLSTREAK_COUNTERUAV_INBOUND" );
#precache( "string", "KILLSTREAK_COUNTERUAV_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_EARNED_COUNTERUAV" );
#precache( "string", "KILLSTREAK_DESTROYED_COUNTERUAV" );
#precache( "string", "KILLSTREAK_COUNTERUAV_HACKED" );
#precache( "string", "mpl_killstreak_radar" );

	
function init()
{	
	level.activeCounterUAVs = [];
	level.counter_uav_positions = GenerateRandomPoints( COUNTER_UAV_POSITION_COUNT );
	level.counter_uav_position_index = [];
	level.counter_uav_offsets = BuildOffsetList( ( 0, 0, 0 ), COUNTER_UAV_GROUP_SIZE, COUNTER_UAV_GROUP_OFFSET, COUNTER_UAV_GROUP_OFFSET );
	
	if ( level.teamBased )
	{
		foreach( team in level.teams )
		{
			level.activeCounterUAVs[ team ] = 0;
			level.counter_uav_position_index[ team ] = 0;

			level thread MovementManagerThink( team );
		}
	}
	else
	{
		level.activeCounterUAVs = [];
	}
	
	level.activePlayerCounterUAVs = [];
	
	level.counter_uav_entities = [];
			
	if( tweakables::getTweakableValue( "killstreak", "allowcounteruav" ) )
	{
		killstreaks::register( COUNTER_UAV_NAME, COUNTER_UAV_NAME, COUNTER_UAV_KILLSTREAK_NAME, "counteruav_used", &ActivateCounterUAV );
		killstreaks::register_strings( COUNTER_UAV_NAME, &"KILLSTREAK_EARNED_COUNTERUAV", &"KILLSTREAK_COUNTERUAV_NOT_AVAILABLE", &"KILLSTREAK_COUNTERUAV_INBOUND", undefined, &"KILLSTREAK_COUNTERUAV_HACKED" );
		killstreaks::register_dialog( COUNTER_UAV_NAME, "mpl_killstreak_radar", "counterUavDialogBundle", "counterUavPilotDialogBundle", "friendlyCounterUav", "enemyCounterUav", "enemyCounterUavMultiple", "friendlyCounterUavHacked", "enemyCounterUavHacked", "requestCounterUav", "threatCounterUav" );
	}

	clientfield::register( "toplayer", COUNTER_UAV_NAME, VERSION_SHIP, 1, "int" );
	level thread WatchCounterUAVs();
	
	callback::on_connect( &OnPlayerConnect );
	callback::on_spawned( &OnPlayerSpawned );
	callback::on_joined_team( &OnPlayerJoinedTeam );
	
}

function OnPlayerConnect()
{
	self.entNum = self getEntityNumber();
	
	if( !level.teamBased )
	{
		level.activeCounterUAVs[ self.entNum ] = 0;
		level.counter_uav_position_index[ self.entNum ] = 0;
		self thread MovementManagerThink( self.entnum );
	}
	
	level.activePlayerCounterUAVs[ self.entNum ] = 0;
}

function OnPlayerSpawned()
{
	if( self EnemyCounterUAVActive() )
	{
		self clientfield::set_to_player( COUNTER_UAV_NAME, 1 );
	}
	else
	{
		self clientfield::set_to_player( COUNTER_UAV_NAME, 0 );
	}
}

function GenerateRandomPoints( count )
{
	points = [];
	
	for( i = 0; i < count; i++ )
	{
		point = airsupport::GetRandomMapPoint( 
		                                      VAL( level.cuav_map_x_offset, 0 ), 
		                                      VAL( level.cuav_map_y_offset, 0 ),
		                                      VAL( level.cuav_map_x_percentage, COUNTER_UAV_MAP_PERCENTAGE ), 
		                                      VAL( level.cuav_map_y_percentage, COUNTER_UAV_MAP_PERCENTAGE ) );
		
		minFlyHeight = airsupport::getMinimumFlyHeight();
		point = point + ( 0, 0, minFlyHeight + VAL( level.counter_uav_position_z_offset, COUNTER_UAV_POSITION_Z_OFFSET ) );
		points[ i ] = point;
	}
	
	return points;
}

function MovementManagerThink( teamOrEntNum )
{
	while( true )
	{
		level waittill( "counter_uav_updated" );
		
		activeCount = 0;
		
		while( level.activeCounterUAVs[ teamOrEntNum ] > 0 )
		{
			if( activeCount == 0 )
			{
				activeCount = level.activeCounterUAVs[ teamOrEntNum ];
			}
			
			currentIndex = level.counter_uav_position_index[ teamOrEntNum ];
			newIndex = currentIndex;
			
			while( newIndex == currentIndex )
			{
				newIndex = RandomIntRange( 0, COUNTER_UAV_POSITION_COUNT );	
			}
			
			destination = level.counter_uav_positions[ newIndex ];
			level.counter_uav_position_index[ teamOrEntNum ] = newIndex;
			
			level notify( "counter_uav_move_" + teamOrEntNum );
			wait( COUNTER_UAV_SPEED + RandomIntRange( COUNTER_UAV_LOCATION_DURATION_MIN, COUNTER_UAV_LOCATION_DURATION_MAX ) );
		}
	}
}

function GetCurrentPosition( teamOrEntNum )
{
	basePosition = level.counter_uav_positions[ level.counter_uav_position_index[ teamOrEntNum ] ];
	offset = level.counter_uav_offsets[ self.cuav_offset_index ];
	
	return basePosition + offset;
}

function AssignFirstAvailableOffsetIndex()
{
	self.cuav_offset_index = GetFirstAvailableOffsetIndex();
	
	MaintainCouterUavEntities();
}

function GetFirstAvailableOffsetIndex()
{
	// init available offset array
	available_offsets = [];
	for( i = 0; i < level.counter_uav_offsets.size; i++ )
		available_offsets[ i ] = true;
	
	// update available offsets array
	foreach( cuav in level.counter_uav_entities )
	{
		if ( isdefined( cuav ) )
		{
			available_offsets[ cuav.cuav_offset_index ] = false;
		}
	}
	
	// return first available
	for( i = 0; i < available_offsets.size; i++ )
	{
		if ( available_offsets[ i ] )
			return i;
	}
	
	/#util::warning("Max counter-uav available offset slots reached. Using slot 0 for now.");#/
	
	return 0;
}

function MaintainCouterUavEntities()
{
	for( i = level.counter_uav_entities.size; i >= 0; i-- )
	{
		if ( !isdefined( level.counter_uav_entities[ i ] ) )
	    {
			ArrayRemoveIndex( level.counter_uav_entities, i );
	    }
	}
}


function BuildOffsetList( startOffset, depth, offset_x, offset_y )
{
	offsets = [];
	for( col = 0; col < depth; col++ )
	{
		itemCount = math::pow( 2, col );
		startingIndex = ( itemCount - 1 );
		
		for( i = 0; i < itemCount; i++ )
		{
			x = offset_x * col;

			y = 0;
			if( itemCount > 1 )
			{
				y = ( i * offset_y );
				total_y = offset_y * startingIndex;
				y -= ( total_y  / 2 );
			}
			
			offsets[ startingIndex + i ] = startOffset + ( x, y, 0 );
		}
	}
	
	return offsets;
}

function ActivateCounterUAV()
{
	if( self killstreakrules::isKillstreakAllowed( COUNTER_UAV_NAME, self.team ) == false )
	{
		return false;
	}

	killstreak_id = self killstreakrules::killstreakStart( COUNTER_UAV_NAME, self.team );
	if(  killstreak_id == -1 )
	{
		return false;
	}

	counterUav = SpawnCounterUAV( self, killstreak_id );
	if( !isdefined( counterUav ) )
	{
		return false;
	}
	
	counterUAV SetScale( COUNTER_UAV_MODEL_SCALE );
	
	counterUav clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	counterUav.killstreak_id = killstreak_id;
	
	counterUav thread killstreaks::WaitTillEMP( &DestroyCounterUavByEMP );
	counterUav thread killstreaks::WaitForTimeout( COUNTER_UAV_NAME, COUNTER_UAV_DURATION_MS, &OnTimeout, "delete", "death", "crashing" );
	counterUav thread killstreaks::WaitForTimecheck( COUNTER_UAV_DURATION_CHECK, &OnTimecheck, "delete", "death", "crashing" );
	counterUav thread util::WaitTillEndOnThreaded( "death", &DestroyCounterUav, "delete", "leaving" );
	
	counterUav SetCanDamage( true );
	counterUav thread killstreaks::MonitorDamage( COUNTER_UAV_NAME, COUNTER_UAV_HEALTH, &DestroyCounterUAV, COUNTER_UAV_LOW_HEALTH, &OnLowHealth, 0, undefined, true );
	
	counterUav PlayLoopSound( COUNTER_UAV_LOOP_SOUND, 1 );
	
	counterUav thread ListenForMove();
	
	self killstreaks::play_killstreak_start_dialog( COUNTER_UAV_NAME, self.team, killstreak_id );
	counterUav killstreaks::play_pilot_dialog_on_owner( "arrive", COUNTER_UAV_NAME, killstreak_id );
	counterUav thread killstreaks::player_killstreak_threat_tracking( COUNTER_UAV_NAME );
	self AddWeaponStat( GetWeapon( COUNTER_UAV_NAME ), "used", 1 );
	
	return true;
}

function HackedPreFunction( hacker )
{
	cuav = self;
	cuav ResetActiveCounterUAV();
}

function SpawnCounterUAV( owner, killstreak_id )
{
	minFlyHeight = airsupport::getMinimumFlyHeight();
	//cuav = spawn( "script_model", airsupport::GetMapCenter() + ( 0, 0, ( minFlyHeight + COUNTER_UAV_POSITION_Z_OFFSET ) ) );
	
	cuav = SpawnVehicle( COUNTER_UAV_VEHICLE_NAME, airsupport::GetMapCenter() + ( 0, 0, ( minFlyHeight + VAL( level.counter_uav_position_z_offset, COUNTER_UAV_POSITION_Z_OFFSET ) ) ), ( 0, 0, 0 ), COUNTER_UAV_NAME );
	cuav AssignFirstAvailableOffsetIndex();
	
	cuav killstreaks::configure_team( COUNTER_UAV_NAME, killstreak_id, owner, undefined, undefined, &ConfigureTeamPost );
	cuav killstreak_hacking::enable_hacking( COUNTER_UAV_NAME, &HackedPreFunction, undefined );
		
	cuav.targetname = COUNTER_UAV_NAME;
	
	killstreak_detect::killstreakTargetSet( cuav );
	
	cuav thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "crashing", undefined, true );
	
	cuav.maxhealth = COUNTER_UAV_HEALTH;
	cuav.health = 99999;
	cuav.rocketDamage = COUNTER_UAV_HEALTH + 1;
	
	cuav SetDrawInfrared( true );
	
	ARRAY_ADD( level.counter_uav_entities, cuav );
		
	return cuav;
}


function ConfigureTeamPost( owner, isHacked )
{
	cuav = self;

	if ( isHacked == false )
	{
		cuav teams::HideToSameTeam();
	}
	else
	{
		cuav SetVisibleToAll();
	}
	cuav thread teams::WaitUntilTeamChangeSingleton( owner, "CUAV_watch_team_change", &OnTeamChange, self.entNum, "death", "leaving", "crashing" );
	cuav AddActiveCounterUAV();
}


function ListenForMove()
{
	self endon( "death" );
	self endon( "leaving" );
	
	while( true )
	{
		self thread CounterUAVMove();
		level util::waittill_any( "counter_uav_move_" + self.team, "counter_uav_move_" + self.ownerEntNum );
	}
}

function CounterUAVMove()
{
	self endon( "death" );
	self endon( "leaving" );
	level endon( "counter_uav_move_" + self.team );
	
	destination = ( 0, 0, 0 );
	
	if( level.teamBased )
	{
		destination = self GetCurrentPosition( self.team );
	}
	else
	{
		destination = self GetCurrentPosition( self.ownerEntNum );
	}
	
	lookAngles = VectorToAngles( destination - self.origin );
	rotationAccelerationDuration = COUNTER_UAV_ROTATION_DURATION * COUNTER_UAV_ROTATION_ACCELERATION_PERCENTAGE;
	rotationDecelerationDuration = COUNTER_UAV_ROTATION_DURATION *COUNTER_UAV_ROTATION_ACCELERATION_PERCENTAGE;
	
	// as a vehicle, we cannot use RotateTo anymore; we'll figure this out soon
	// self RotateTo( lookAngles, COUNTER_UAV_ROTATION_DURATION, rotationAccelerationDuration, rotationDecelerationDuration );
	// self waittill( "rotatedone" );
	
	travelAccelerationDuration = COUNTER_UAV_SPEED * COUNTER_UAV_ACCELERATION_PERCENTAGE;
	travelDecelerationDuration = COUNTER_UAV_SPEED * COUNTER_UAV_DECELERATION_PERCENTAGE;
	//self MoveTo( destination, COUNTER_UAV_SPEED, travelAccelerationDuration, travelDecelerationDuration );
	self SetVehGoalPos( destination, true, false );
}

function PlayFx( name )
{
	self endon( "death" );
	wait ( 0.1 );
	
	if ( isdefined( self ) )
	{
		PlayFXOnTag( name, self, "tag_origin" );
	}
}

function OnLowHealth( attacker, weapon )
{
	self.is_damaged = true;
	params = level.killstreakBundle[COUNTER_UAV_NAME];
	if( isdefined( params.fxLowHealth ) )
		PlayFXOnTag( params.fxLowHealth, self, "tag_origin" );
}

function OnTeamChange( entNum, event )
{
	DestroyCounterUAV( undefined, undefined );
}

function OnPlayerJoinedTeam()
{
	HideAllCounterUAVsToSameTeam();
}

function OnTimeout()
{
	self.leaving = true;
	
	self killstreaks::play_pilot_dialog_on_owner( "timeout", COUNTER_UAV_NAME );
	
	self airsupport::Leave( COUNTER_UAV_SPEED );
	wait( COUNTER_UAV_SPEED );
	self RemoveActiveCounterUAV();
	Target_Remove( self );
	self delete();
}

function OnTimecheck()
{
	self killstreaks::play_pilot_dialog_on_owner( "timecheck", COUNTER_UAV_NAME, self.killstreak_id );
}

function DestroyCounterUavByEMP( attacker, arg )
{
	DestroyCounterUav( attacker, GetWeapon( "emp" ) );
}

function DestroyCounterUAV( attacker, weapon )
{
	if ( self.leaving !== true )
	{
		self killstreaks::play_destroyed_dialog_on_owner( COUNTER_UAV_NAME, self.killstreak_id );
	}
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );
	if( isdefined( attacker ) && ( !isdefined( self.owner ) ||  self.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, false );
		scoreevents::processScoreEvent( "destroyed_counter_uav", attacker, self.owner, weapon );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_COUNTERUAV", attacker.entnum );
		attacker challenges::addFlySwatterStat( weapon, self );
	}

	self PlaySound( "evt_helicopter_midair_exp" );
	self RemoveActiveCounterUAV();
	
	if ( Target_IsTarget( self ) )
	{
		Target_Remove( self );
	}

	self thread DeleteCounterUAV();
}

function DeleteCounterUAV()
{
	self notify( "crashing" );
	
	params = level.killstreakBundle[COUNTER_UAV_NAME];
	if( isdefined( params.ksExplosionFX ) && isdefined( self ) )
		self thread PlayFx( params.ksExplosionFX );
	
	wait( 0.1 );
	
	if ( isdefined( self ) )
	{
		self setModel( "tag_origin" );
	}
	
	wait( 0.2 );
	
	if ( isdefined( self ) )
	{
		self notify( "delete" );
		self delete();
	}
}

function EnemyCounterUAVActive()
{
	if( level.teamBased )
	{
		foreach( team in level.teams )
		{
			if( team == self.team )
			{
				continue;
			}
			
			if( TeamHasActiveCounterUAV( team ) )
			{
				return true;
			}
		}
	}
	else
	{
		enemies = self teams::GetEnemyPlayers();
		foreach( player in enemies )
		{
			if( player HasActiveCounterUAV() )
			{
				return true;
			}
		}
	}
	
	return false;
}


function HasActiveCounterUAV()
{
	return ( level.activeCounterUAVs[ self.entNum ] > 0 );
}

function TeamHasActiveCounterUAV( team )
{
	return ( level.activeCounterUAVs[ team ] > 0 );
}

function HasIndexActiveCounterUAV( team_or_entnum )
{
	return ( level.activeCounterUAVs[ team_or_entnum ] > 0 );
}


function AddActiveCounterUAV()
{
	if ( level.teamBased )
	{
		level.activeCounterUAVs[ self.team ]++;	
		
		foreach( team in level.teams )
		{
			if ( team == self.team )
			{
				continue;
			}
			
			if( satellite::HasSatellite( team ) )
			{
				self.owner challenges::blockedSatellite();
			}
		}
	}
	else 
	{
		level.activeCounterUAVs[ self.ownerEntnum ]++;
		
		keys = getarraykeys( level.activeCounterUAVs );
		for ( i = 0; i < keys.size; i++ )
		{
			if( keys[i] == self.ownerEntNum )
			{
				continue;
			}

			if( satellite::HasSatellite( keys[i] ) )
			{
				self.owner challenges::blockedSatellite();
				break;
			}
		}
	}
	
	level.activePlayerCounterUAVs[ self.ownerEntNum ]++;

	level notify( "counter_uav_updated" );
}

function RemoveActiveCounterUAV()
{
	cuav = self;
	cuav ResetActiveCounterUAV();
	cuav killstreakrules::killstreakStop( "counteruav", self.originalteam, self.killstreak_id );
}

function ResetActiveCounterUAV()
{
	if ( level.teamBased )
	{
		level.activeCounterUAVs[ self.team ]--;
		assert( level.activeCounterUAVs[ self.team ] >= 0 );
		if ( level.activeCounterUAVs[ self.team ] < 0 ) 
		{
			level.activeCounterUAVs[ self.team ] = 0;
		}
	}
	else if ( isdefined( self.owner ) )
	{
		assert( isdefined( self.ownerEntNum ) );
		if ( !isdefined( self.ownerEntNum ) )
		{
			self.ownerEntNum = self.owner getEntityNumber();
		}
		
		level.activeCounterUAVs[self.ownerEntNum ]--;
		
		assert( level.activeCounterUAVs[ self.ownerEntNum ] >= 0 );
		if ( level.activeCounterUAVs[ self.ownerEntNum ] < 0 ) 
		{
			level.activeCounterUAVs[ self.ownerEntNum ] = 0;
		}
	}

	level.activePlayerCounterUAVs[ self.ownerEntNum ]--;

	level notify ( "counter_uav_updated" );
}


function WatchCounterUAVs()
{
	while( true )
	{
		level waittill( "counter_uav_updated" );
		
		foreach( player in level.players )
		{
			if( player EnemyCounterUAVActive() )
			{
				player clientfield::set_to_player( COUNTER_UAV_NAME, 1 );
			}
			else
			{
				player clientfield::set_to_player( COUNTER_UAV_NAME, 0 );
			}
		}
	}
}

function HideAllCounterUAVsToSameTeam()
{
	foreach( counteruav in level.counter_uav_entities )
	{
		if ( isdefined( counteruav ) )
		{
			counteruav teams::HideToSameTeam();
			
		}
	}
}
