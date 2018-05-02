#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_decoy;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\duplicaterender_mgr;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace threat_detector;

REGISTER_SYSTEM( "threat_detector", &__init__, undefined )		

function __init__()
{
	level.sensorHandle = 1;
	level.sensors = [];
	
	clientfield::register( "missile", "threat_detector", VERSION_SHIP, 1, "int", &spawnedThreatDetector,!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}
 
function spawnedThreatDetector( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if( newVal != 1 )
	{
		return;
	}
	
	if( GetLocalPlayer( localClientNum ) != self.owner )
	{
		return;
	}
	
	sensorIndex = level.sensors.size;
	level.sensorHandle++;
	
	level.sensors[ sensorIndex ] = spawnstruct();
	level.sensors[ sensorIndex ].handle = level.sensorHandle;
	level.sensors[ sensorIndex ].cent = self;
	level.sensors[ sensorIndex ].team = self.team;
	level.sensors[ sensorIndex ].owner = self GetOwner( localClientNum );
	
	level.sensors[ sensorIndex ].owner AddSensorGrenadeArea( self.origin, level.sensorHandle );
	
	self.owner thread sensorGrenadeThink( self, level.sensorHandle, localClientNum );
	self.owner thread clearThreatDetectorOnDelete( self, level.sensorHandle, localClientNum );
}

function sensorGrenadeThink( sensorEnt, sensorHandle, localClientNum )
{
	sensorEnt endon( "entityshutdown" );
	
	if( isdefined( sensorEnt.owner ) == false )
	{
		return;
	}
		
	while( true )
	{
		players = GetPlayers( localClientNum );
		foreach( player in players )
		{
			if( self util::IsEnemyPlayer( player ) )
			{
				if( player hasPerk( localClientNum, "specialty_nomotionsensor" ) || player hasPerk( localClientNum, "specialty_sengrenjammer" ) )
				{
					player duplicate_render::set_player_threat_detected( localClientNum, false );
					continue;
				}
				
				threatDetectorRadius = GetDvarFloat( "cg_threatDetectorRadius", 0 );
				threatDetectorRadiusSqrd = threatDetectorRadius * threatDetectorRadius;
				
				if( DistanceSquared( player.origin, sensorEnt.origin ) < threatDetectorRadiusSqrd )
				{
					player duplicate_render::set_player_threat_detected( localClientNum, true );
				}
				else
				{
					player duplicate_render::set_player_threat_detected( localClientNum, false );
				}
			}
		}	
		
		wait( 1 );
	}
}

function clearThreatDetectorOnDelete( sensorEnt, sensorHandle, localClientNum )
{
	sensorEnt waittill( "entityshutdown" );
	
	entIndex = 0;
	for( i = 0; i < level.sensors.size; i++ ) 
	{
		size = level.sensors.size;
		if( sensorHandle == level.sensors[ i ].handle )
		{
			level.sensors[ i ].owner RemoveSensorGrenadeArea( sensorHandle );
			entIndex = 0;
			break;
		}
	}
	
	players = GetPlayers( localClientNum );
	foreach( player in players )
	{
		if( self util::IsEnemyPlayer( player ) )
		{
			player duplicate_render::set_player_threat_detected( localClientNum, false );
		}
	}
}
