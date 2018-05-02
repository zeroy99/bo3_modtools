#using scripts\codescripts\struct;

#using scripts\shared\popups_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\gametypes\_globallogic_audio;

#namespace killstreakrules;

function init()
{
	level.killstreakrules = [];
	level.killstreaktype = [];
	level.killstreaks_triggered = [];
	level.matchRecorderKillstreakKills = [];

	if( !isdefined( level.globalKillstreaksCalled ) )
	{
		level.globalKillstreaksCalled = 0;	
	}
	
	//			Rule name,  							max count	per team count
	createRule( "ai_tank",								4,			2);
	createRule( "airsupport", 							1,			1);
	createRule( "combatrobot", 							4,			2);
	createRule( "chopper", 								2,			1);
	createRule( "chopperInTheAir", 						2,			1);	
	createRule( "counteruav",							6,			3);
	createRule( "dart",									4,			2);
	createRule( "dogs",									1,			1);
	createRule( "drone_strike",							1,			1);
	createRule( "emp",									2,			1);
	createRule( "firesupport", 							1,			1);
	createRule( "missiledrone", 						3,			3);
	createRule( "missileswarm",							1,			1);
	createRule( "planemortar",							1,			1);
	createRule( "playercontrolledchopper", 				1,			1);
	createRule( "qrdrone",		 						3,			2);
	createRule( "uav",									10,			5);
	createRule( "raps"	,								2,			1);
	createRule( "rcxd", 								4,			2);
	createRule( "remote_missile",						2,			1);
	createRule( "remotemortar", 						1,			1);
	createRule( "satellite", 							2,			1);
	createRule( "sentinel",								4,			2);
	createRule( "straferun",							1,			1);
	createRule( "supplydrop", 							4,			4);
	createRule( "targetableent",						32,			32); 	
	createRule( "turret", 								8,			4);
	createRule( "vehicle", 								7,			7);
	createRule( "weapon", 								12,			6);

	// 					KILLSTREAK							Rule Name					adds 	checks 
	addKillstreakToRule( "ai_tank_drop",					"ai_tank",		 			true, 	true );
	addKillstreakToRule( "airstrike", 						"airsupport", 				true, 	true );
	addKillstreakToRule( "airstrike", 						"vehicle", 					true, 	true );
	addKillstreakToRule( "artillery", 						"firesupport", 				true, 	true );
	addKillstreakToRule( "auto_tow", 						"turret", 					true, 	true );
	addKillstreakToRule( "autoturret", 						"turret", 					true, 	true );
	addKillstreakToRule( "combat_robot", 					"combatrobot",	 			true, 	true );
	addKillstreakToRule( "counteruav", 						"counteruav",	 			true, 	true );
	addKillstreakToRule( "counteruav", 						"targetableent", 			true, 	true );
	addKillstreakToRule( "dart", 							"dart", 					true, 	true );
	addKillstreakToRule( "dogs", 							"dogs", 					true, 	true );
	addKillstreakToRule( "dogs_lvl2",						"dogs", 					true, 	true );
	addKillstreakToRule( "dogs_lvl3",						"dogs", 					true, 	true );
	addKillstreakToRule( "drone_strike",					"drone_strike",				true, 	true );
	addKillstreakToRule( "emp",								"emp",			 			true, 	true );
	addKillstreakToRule( "helicopter", 						"chopper", 					true, 	true );
	addKillstreakToRule( "helicopter", 						"chopperInTheAir", 			true, 	false );
	addKillstreakToRule( "helicopter", 						"playercontrolledchopper", 	false, 	true );
	addKillstreakToRule( "helicopter", 						"targetableent", 			true, 	true );
	addKillstreakToRule( "helicopter", 						"vehicle", 					true, 	true );
	
	addKillstreakToRule( "helicopter_comlink", 				"chopper", 					true, 	true );
	addKillstreakToRule( "helicopter_comlink", 				"chopperInTheAir", 			true, 	false );	
	addKillstreakToRule( "helicopter_comlink", 				"targetableent", 			true, 	true );	
	addKillstreakToRule( "helicopter_comlink", 				"vehicle", 					true, 	true );
	
	addKillstreakToRule( "helicopter_guard", 				"airsupport",				true, 	true );
	
	addKillstreakToRule( "helicopter_gunner", 				"chopperInTheAir", 			true, 	false );
	addKillstreakToRule( "helicopter_gunner", 				"playercontrolledchopper", 	true, 	true );
	addKillstreakToRule( "helicopter_gunner", 				"targetableent", 			true, 	true );
	addKillstreakToRule( "helicopter_gunner", 				"vehicle", 					true, 	true );
	
	addKillstreakToRule( "helicopter_gunner_assistant", 	"chopperInTheAir", 			true, 	false );
	addKillstreakToRule( "helicopter_gunner_assistant", 	"playercontrolledchopper", 	true, 	true );
	addKillstreakToRule( "helicopter_gunner_assistant", 	"targetableent", 			true, 	true );
	addKillstreakToRule( "helicopter_gunner_assistant", 	"vehicle", 					true, 	true );
	
	addKillstreakToRule( "helicopter_player_firstperson",	"vehicle", 					true, 	true );
	addKillstreakToRule( "helicopter_player_firstperson", 	"chopperInTheAir", 			true, 	true );	
	addKillstreakToRule( "helicopter_player_firstperson", 	"playercontrolledchopper", 	true, 	true );
	addKillstreakToRule( "helicopter_player_firstperson", 	"targetableent", 			true, 	true );		
	addKillstreakToRule( "helicopter_player_gunner", 		"chopperInTheAir", 			true, 	true );
	addKillstreakToRule( "helicopter_player_gunner", 		"playercontrolledchopper", 	true, 	true );
	addKillstreakToRule( "helicopter_player_gunner", 		"targetableent", 			true, 	true );
	addKillstreakToRule( "helicopter_player_gunner", 		"vehicle", 					true, 	true );
	addKillstreakToRule( "helicopter_x2", 					"chopper", 					true, 	true );
	addKillstreakToRule( "helicopter_x2", 					"chopperInTheAir", 			true, 	false );	
	addKillstreakToRule( "helicopter_x2", 					"playercontrolledchopper", 	false, 	true );
	addKillstreakToRule( "helicopter_x2", 					"targetableent", 			true, 	true );	
	addKillstreakToRule( "helicopter_x2", 					"vehicle", 					true, 	true );
	addKillstreakToRule( "m202_flash",						"weapon", 					true, 	true );
	addKillstreakToRule( "m220_tow", 						"weapon", 					true, 	true );
	addKillstreakToRule( "m220_tow_drop",					"supplydrop", 				true, 	true );
	addKillstreakToRule( "m220_tow_drop",					"vehicle", 					true, 	true );
	addKillstreakToRule( "m220_tow_killstreak",				"weapon",					true,	true );
	addKillstreakToRule( "m32", 							"weapon", 					true, 	true );
	addKillstreakToRule( "m32_drop", 						"weapon", 					true, 	true );
	addKillstreakToRule( "microwave_turret",				"turret", 					true, 	true );
	addKillstreakToRule( "minigun", 						"weapon", 					true, 	true );
	addKillstreakToRule( "minigun_drop", 					"weapon", 					true, 	true );
	addKillstreakToRule( "missile_drone",					"missiledrone", 			true, 	true );
	addKillstreakToRule( "missile_swarm",					"missileswarm", 			true, 	true );
	addKillstreakToRule( "mortar", 							"firesupport", 				true, 	true );
	addKillstreakToRule( "mp40_drop", 						"weapon", 					true, 	true );
	addKillstreakToRule( "napalm", 							"airsupport", 				true, 	true );
	addKillstreakToRule( "napalm", 							"vehicle", 					true, 	true );
	addKillstreakToRule( "planemortar", 					"planemortar",				true, 	true );
	addKillstreakToRule( "qrdrone",							"qrdrone",				 	true, 	true );
	addKillstreakToRule( "qrdrone",							"vehicle", 					true, 	true );
	addKillstreakToRule( "uav", 							"uav",			 			true, 	true );
	addKillstreakToRule( "uav", 							"targetableent", 			true, 	true );
	addKillstreakToRule( "satellite", 						"satellite", 				true, 	true );
	addKillstreakToRule( "raps", 							"raps", 					true, 	true );
	addKillstreakToRule( "rcbomb", 							"rcxd", 					true, 	true );
	addKillstreakToRule( "remote_missile",					"targetableent", 			true, 	true );
	addKillstreakToRule( "remote_missile",					"remote_missile", 			true, 	true );
	addKillstreakToRule( "remote_mortar",					"remotemortar", 			true, 	true );
	addKillstreakToRule( "remote_mortar",					"targetableent", 			true, 	true );
	addKillstreakToRule( "sentinel", 						"sentinel", 				true, 	true );
	addKillstreakToRule( "straferun", 						"straferun",				true, 	true );
	addKillstreakToRule( "supply_drop", 					"supplydrop", 				true, 	true );
	addKillstreakToRule( "supply_drop", 					"targetableent",			true, 	true );
	addKillstreakToRule( "supply_drop", 					"vehicle", 					true, 	true );
	addKillstreakToRule( "supply_station", 					"supplydrop", 				true, 	true );
	addKillstreakToRule( "supply_station", 					"targetableent", 			true, 	true );
	addKillstreakToRule( "supply_station", 					"vehicle", 					true, 	true );
	addKillstreakToRule( "tow_turret_drop", 				"supplydrop", 				true, 	true );
	addKillstreakToRule( "tow_turret_drop", 				"vehicle", 					true, 	true );
	addKillstreakToRule( "turret_drop", 					"supplydrop", 				true, 	true );
	addKillstreakToRule( "turret_drop", 					"vehicle", 					true, 	true );
}
	
function createRule( rule, maxAllowable, maxAllowablePerTeam )
{	
	level.killstreakrules[rule] = spawnstruct();
	level.killstreakrules[rule].cur = 0;
	level.killstreakrules[rule].curTeam = [];
	level.killstreakrules[rule].max = maxAllowable;
	level.killstreakrules[rule].maxPerTeam = maxAllowablePerTeam;
}

function addKillstreakToRule( killstreak, rule, countTowards, checkAgainst, inventoryVariant )
{
	if ( !isdefined (level.killstreaktype[killstreak] ) )
		level.killstreaktype[killstreak] = [];
		
	keys = GetArrayKeys( level.killstreaktype[killstreak] );
	
	// you need to add a rule before adding it to a killstreak
	assert( isdefined(level.killstreakrules[rule] ) );

	if ( !isdefined( level.killstreaktype[killstreak][rule] ) )
		level.killstreaktype[killstreak][rule] = spawnstruct();

	level.killstreaktype[killstreak][rule].counts = countTowards;
	
	level.killstreaktype[killstreak][rule].checks = checkAgainst;
	
	if( !IS_TRUE( inventoryVariant ) )
		addKillstreakToRule( "inventory_" + killstreak, rule, countTowards, checkAgainst, true );
}

// returns killstreakid or  if killstreak is not allowed
function killstreakStart( hardpointType, team, hacked, displayTeamMessage )
{	
	/#
	assert( isdefined( team ), "team needs to be defined" );
	#/

	if ( self isKillstreakAllowed( hardpointType, team ) == false )
		return INVALID_KILLSTREAK_ID;
		
	assert ( isdefined ( hardpointType ) );
		
	if( !isdefined( hacked ) )
		hacked = false;

	if ( !isdefined( displayTeamMessage ) )
		displayTeamMessage = true;

	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		displayTeamMessage = false;
	
	if ( displayTeamMessage == true )
	{
		if ( !hacked )
			self displayKillstreakStartTeamMessageToAll( hardpointType );
	}

	keys = GetArrayKeys( level.killstreaktype[hardpointType] );

	foreach( key in keys )
	{
		// Check if killstreak is counted by this rule
		if ( !level.killstreaktype[hardpointType][key].counts )
			continue;
			
		assert( isdefined(level.killstreakrules[key] ) );
		level.killstreakrules[key].cur++;
		if ( level.teambased )
		{
			if ( !isdefined( level.killstreakrules[key].curTeam[team] ) )
				level.killstreakrules[key].curTeam[team] = 0;
			level.killstreakrules[key].curTeam[team]++;
		}
	}
	
	level notify( "killstreak_started", hardpointType, team, self );
	
	killstreak_id = level.globalKillstreaksCalled;
	level.globalKillstreaksCalled++;
	
	killstreak_data = [];
	killstreak_data[ "caller" ] = self GetXUID();
	killstreak_data[ "spawnid" ] = getplayerspawnid( self );
	killstreak_data[ "starttime" ] = gettime();
	killstreak_data[ "type" ] = hardpointType;
	killstreak_data[ "endtime" ] = 0;
	level.matchRecorderKillstreakKills[ killstreak_id ] = 0;

	level.killstreaks_triggered[ killstreak_id ] = killstreak_data;
	
	return killstreak_id;
}

function displayKillstreakStartTeamMessageToAll( hardpointType )
{
	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		return;

	if ( isdefined( level.killstreaks[hardpointType] ) && isdefined( level.killstreaks[hardpointType].inboundtext ) )
		level thread popups::DisplayKillstreakTeamMessageToAll( hardpointType, self );
}

function RecordKillstreakEndDirect(eventIndex, recordStreakIndex, totalKills)
{
	player = self;
	
	player RecordKillstreakEndEvent( eventIndex, recordStreakIndex, totalKills );
   		
	player.killstreakEvents[recordStreakIndex] = undefined;
}

function RecordKillstreakEnd(recordStreakIndex, totalKills)
{
	player = self;
	
	if(!IsPlayer(player))
		return;
	
	if(!IsDefined(totalKills))
		totalkills = 0;
	
	if(!isDefined(player.killstreakEvents))
	{
		// This may store an eventIndex or number of kills, depending on whether a killstreak event or an end event happens first, respectively
		player.killstreakEvents = associativeArray();
	}
	eventIndex = player.killstreakEvents[recordStreakIndex];
	// Note that some killstreaks fire their end before their begin, so we need to check if the eventIndex is defined to determine that
	// Two cases - 1) KillstreakEvent happens first (correctly)
	if(isDefined(eventIndex))
	{
		player RecordKillstreakEndDirect(eventIndex, recordStreakIndex, totalKills);
	} 
	else
	{
		// KillstreakEndEvent happens first
		player.killstreakEvents[recordStreakIndex] = totalKills;
	}
}

function killstreakStop( hardpointType, team, id )
{
	/#
	assert( isdefined( team ), "team needs to be defined" );
	#/

	assert ( isdefined ( hardpointType ) );
	//assert( isdefined( id ), "Must provide the associated killstreak_id for " + hardpointType );

	keys = GetArrayKeys( level.killstreaktype[hardpointType] );
	
	foreach( key in keys )
	{
		// Check if killstreak is counted by this rule
		if ( !level.killstreaktype[hardpointType][key].counts )
			continue;
			
		assert( isdefined(level.killstreakrules[key] ) );
		level.killstreakrules[key].cur--;
		
		assert (level.killstreakrules[key].cur >= 0 );
		
		if ( level.teambased )
		{
			assert( isdefined( team ) );
			assert( isdefined( level.killstreakrules[key].curTeam[team] ) );

			level.killstreakrules[key].curTeam[team]--;
			assert (level.killstreakrules[key].curTeam[team] >= 0 );
		}
	}

	if ( !isdefined(id) || (id == INVALID_KILLSTREAK_ID) )
	{
		return;
	}
	level.killstreaks_triggered[ id ][ "endtime" ] = GetTime();

	totalKillsWithThisKillstreak = level.matchRecorderKillstreakKills[ id ];

	level.killstreaks_triggered[ id ] = undefined;
	level.matchRecorderKillstreakKills[ id ] = undefined;
	
	if( isdefined( level.killstreaks[hardpointType].menuname ) )
	{
		recordStreakIndex = level.killstreakindices[level.killstreaks[hardpointType].menuname];
		if ( isdefined( self ) && isdefined( recordStreakIndex ) && ( !isdefined( self.activatingKillstreak ) || !self.activatingKillstreak ) )
		{
			entity = self;
			if(isDefined(entity.owner) )
		   	{
			   	entity = entity.owner;
			}
			
			entity RecordKillstreakEnd(recordstreakindex, totalkillswiththiskillstreak);
		}
	}
}

function isKillstreakAllowed( hardpointType, team )
{
	/#
	assert( isdefined( team ), "team needs to be defined" );
	#/

	assert ( isdefined ( hardpointType ) );
	
	// general failsafe for all scorestreaks
	if ( self killstreaks::is_killstreak_start_blocked() )
		return false;
	
	isAllowed = true;
	
	keys = GetArrayKeys( level.killstreaktype[hardpointType] );
	
	foreach( key in keys )
	{
		// Check if killstreak is restricted by this rule
		if ( !level.killstreaktype[hardpointType][key].checks )
			continue;
			
		if ( level.killstreakrules[key].max != 0 ) 
		{
			if (level.killstreakrules[key].cur >= level.killstreakrules[key].max)
			{
				isAllowed = false;	
				break;
			}
		}
			
		if ( level.teambased && level.killstreakrules[key].maxPerTeam != 0 )
		{
			if ( !isdefined( level.killstreakrules[key].curTeam[team] ) )
				level.killstreakrules[key].curTeam[team] = 0;
			
			if (level.killstreakrules[key].curTeam[team] >= level.killstreakrules[key].maxPerTeam)
			{
				isAllowed = false;	
				break;
			}
		}
	}
	
	
	if ( isdefined( self.lastStand ) && self.lastStand )
	{
		isAllowed = false;
	}

	isEMPed = false;
	// should only be needed in case of a hacked client, the client checks the EMP flag prior to switching to the killstreak weapon
	if ( self IsEMPJammed() ) 
	{
		isAllowed = false;
		isEMPed = true;
		if ( self EMP::EnemyEMPActive() )
		{
			if ( isdefined( level.empEndTime ) )
			{
				secondsLeft = int( ( level.empendtime - getTime() ) / 1000 );
				if ( secondsLeft > 0 )
				{
				    self iprintlnbold( &"KILLSTREAK_NOT_AVAILABLE_EMP_ACTIVE", secondsLeft );
				    return false;
				}
			}
		}
	}
	
	if ( isAllowed == false )
	{
		if ( isdefined( level.killstreaks[hardpointType] ) && isdefined( level.killstreaks[hardpointType].notAvailableText ) )
		{
			self iprintlnbold( level.killstreaks[hardpointType].notAvailableText );
			
			if ( !isdefined( self.currentKillstreakDialog ) && level.killstreaks[hardpointType].utilizesAirspace && isEMPed == false )
			{
				self globallogic_audio::play_taacom_dialog( "airspaceFull" );
			}
		}
	}

	return isAllowed;
}
