#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace spawnlogic;

REGISTER_SYSTEM( "spawnlogic", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &main );
}

// called once at start of game
function main()
{
	// start keeping track of deaths
	level.spawnlogic_deaths = [];
	// DEBUG
	level.spawnlogic_spawnkills = [];
	level.players = [];
	level.grenades = [];
	level.pipebombs = [];

	level.spawnMins = (0,0,0);
	level.spawnMaxs = (0,0,0);
	level.spawnMinsMaxsPrimed = false;	
	if ( isdefined( level.safespawns ) )
	{
		for( i = 0; i < level.safespawns.size; i++ )
		{
			level.safespawns[i] spawnPointInit();
		}
	}
	
	if ( GetDvarString( "scr_spawn_enemyavoiddist") == "" )
		SetDvar("scr_spawn_enemyavoiddist", "800");
	if ( GetDvarString( "scr_spawn_enemyavoidweight") == "" )
		SetDvar("scr_spawn_enemyavoidweight", "0");
	
}

function findBoxCenter( mins, maxs )
{
	center = ( 0, 0, 0 );
	center = maxs - mins;
	center = ( center[0]/2, center[1]/2, center[2]/2 ) + mins;
	return center;
}

function expandMins( mins, point )
{
	if ( mins[0] > point[0] )
		mins = ( point[0], mins[1], mins[2] );
	if ( mins[1] > point[1] )
		mins = ( mins[0], point[1], mins[2] );
	if ( mins[2] > point[2] )
		mins = ( mins[0], mins[1], point[2] );
	return mins;
}

function expandMaxs( maxs, point )
{
	if ( maxs[0] < point[0] )
		maxs = ( point[0], maxs[1], maxs[2] );
	if ( maxs[1] < point[1] )
		maxs = ( maxs[0], point[1], maxs[2] );
	if ( maxs[2] < point[2] )
		maxs = ( maxs[0], maxs[1], point[2] );
	return maxs;
}


function addSpawnPointsInternal( team, spawnPointName )
{	
	oldSpawnPoints = [];
	if ( level.teamSpawnPoints[team].size )
		oldSpawnPoints = level.teamSpawnPoints[team];
	
	level.teamSpawnPoints[team] = getSpawnpointArray( spawnPointName );
	
	if ( !isdefined( level.spawnpoints ) )
		level.spawnpoints = [];
	
	for ( index = 0; index < level.teamSpawnPoints[team].size; index++ )
	{
		spawnpoint = level.teamSpawnPoints[team][index];
		
		if ( !isdefined( spawnpoint.inited ) )
		{
			spawnpoint spawnPointInit();
			level.spawnpoints[ level.spawnpoints.size ] = spawnpoint;
		}
	}
	
	for ( index = 0; index < oldSpawnPoints.size; index++ )
	{
		origin = oldSpawnPoints[index].origin;
		
		// are these 2 lines necessary? we already did it in spawnPointInit
		level.spawnMins = expandMins( level.spawnMins, origin );
		level.spawnMaxs = expandMaxs( level.spawnMaxs, origin );
		
		level.teamSpawnPoints[team][ level.teamSpawnPoints[team].size ] = oldSpawnPoints[index];
	}
	
	if ( !level.teamSpawnPoints[team].size )
	{	

		callback::abort_level();
		wait 1; // so we don't try to abort more than once before the frame ends
		return;
	}
}

function clearSpawnPoints()
{
	foreach( team in level.teams )
	{
		level.teamSpawnPoints[team] = [];
	}
	level.spawnpoints = [];
	level.unified_spawn_points = undefined;
}

function addSpawnPoints( team, spawnPointName )
{
	addSpawnPointClassName( spawnPointName );
	addSpawnPointTeamClassName( team, spawnPointName );
	
	addSpawnPointsInternal( team, spawnPointName );
}

function rebuildSpawnPoints( team )
{
	level.teamSpawnPoints[team] = [];
	
	for ( index = 0; index < level.spawn_point_team_class_names[team].size; index++ )
	{
		addSpawnPointsInternal( team, level.spawn_point_team_class_names[team][index] );
	}
}

function placeSpawnPoints( spawnPointName )
{
	addSpawnPointClassName( spawnPointName );

	spawnPoints = getSpawnpointArray( spawnPointName );
	
	if ( !spawnPoints.size )
	{

		callback::abort_level();
		wait 1; // so we don't try to abort more than once before the frame ends
		return;
	}
	
	for( index = 0; index < spawnPoints.size; index++ )
	{
		spawnPoints[index] spawnPointInit();
		// don't add this spawnpoint to level.spawnpoints,
		// because it's an unimportant one that we don't want to do sight traces to
		
	}
}

// just drops to ground
// needed for demolition because secondary attacker points do 
// not get used until mid round and therefore dont get processed
// this was making the rendered debug boxes appear to be floating
// and causing confusion amongst the masses.  Need the points to 
// be debug friendly.  Cant use the placeSpawnPoints function because
// that does somethings that we dont want to do until they are actually used
function dropSpawnPoints( spawnPointName )
{
		spawnPoints = getSpawnpointArray( spawnPointName );
	if ( !spawnPoints.size )
	{

		return;
	}
	
	for( index = 0; index < spawnPoints.size; index++ )
	{
		spawnPoints[index] placeSpawnpoint();
	}
}

function addSpawnPointClassName( spawnPointClassName )
{
	if ( !isdefined( level.spawn_point_class_names ) )
	{
		level.spawn_point_class_names = [];
	}
	
	level.spawn_point_class_names[ level.spawn_point_class_names.size ] = spawnPointClassName;
}
	
function addSpawnPointTeamClassName( team, spawnPointClassName )
{
	level.spawn_point_team_class_names[team][ level.spawn_point_team_class_names[team].size ] = spawnPointClassName;
}

function getSpawnpointArray( classname )
{
	spawnPoints = getEntArray( classname, "classname" );
	
	if ( !isdefined( level.extraspawnpoints ) || !isdefined( level.extraspawnpoints[classname] ) )
		return spawnPoints;
	
	for ( i = 0; i < level.extraspawnpoints[classname].size; i++ )
	{
		spawnPoints[ spawnPoints.size ] = level.extraspawnpoints[classname][i];
	}
	
	return spawnPoints;
}

function spawnPointInit()
{
	spawnpoint = self;
	origin = spawnpoint.origin;
	
	// we need to properly prime the mins and maxs otherwise a level that is entirely
	// on one side of the zero line for any axis will have an invalid map center
	if ( !level.spawnMinsMaxsPrimed )
	{
		level.spawnMins = origin;
		level.spawnMaxs = origin;
		level.spawnMinsMaxsPrimed = true;
	}
	else
	{
		level.spawnMins = expandMins( level.spawnMins, origin );
		level.spawnMaxs = expandMaxs( level.spawnMaxs, origin );
	}
	
	spawnpoint placeSpawnpoint();
	spawnpoint.forward = anglesToForward( spawnpoint.angles );
	spawnpoint.sightTracePoint = spawnpoint.origin + (0,0,50);
	
	/*skyHeight = 500;
	spawnpoint.outside = true;
	if ( !bullettracepassed( spawnpoint.sightTracePoint, spawnpoint.sightTracePoint + (0,0,skyHeight), false, undefined) )
	{
		startpoint = spawnpoint.sightTracePoint + spawnpoint.forward * 100;
		if ( !bullettracepassed( startpoint, startpoint + (0,0,skyHeight), false, undefined) )
			spawnpoint.outside = false;
	}*/
	
	spawnpoint.inited = true;
}

function getTeamSpawnPoints( team )
{
	return level.teamSpawnPoints[team];
}

// selects a spawnpoint, preferring ones with heigher weights (or toward the beginning of the array if no weights).
// also does final things like setting self.lastspawnpoint to the one chosen.
// this takes care of avoiding telefragging, so it doesn't have to be considered by any other function.
function getSpawnpoint_Final( spawnpoints, useweights )
{
	
	bestspawnpoint = undefined;
	
	if ( !isdefined( spawnpoints ) || spawnpoints.size == 0 )
		return undefined;
	
	if ( !isdefined( useweights ) )
		useweights = true;
	
	if ( useweights )
	{
		// choose spawnpoint with best weight
		// (if a tie, choose randomly from the best)
		bestspawnpoint = getBestWeightedSpawnpoint( spawnpoints );
		thread spawnWeightDebug( spawnpoints );
	}
	else
	{
		// (only place we actually get here from is getSpawnpoint_Random() )
		// no weights. prefer spawnpoints toward beginning of array
		for ( i = 0; i < spawnpoints.size; i++ )
		{
			if( isdefined( self.lastspawnpoint ) && self.lastspawnpoint == spawnpoints[i] )
				continue;
			
			if ( positionWouldTelefrag( spawnpoints[i].origin ) )
				continue;
			
			bestspawnpoint = spawnpoints[i];
			break;
		}
		if ( !isdefined( bestspawnpoint ) )
		{
			// Couldn't find a useable spawnpoint. All spawnpoints either telefragged or were our last spawnpoint
			// Our only hope is our last spawnpoint - unless it too will telefrag...
			if ( isdefined( self.lastspawnpoint ) && !positionWouldTelefrag( self.lastspawnpoint.origin ) )
			{
				// (make sure our last spawnpoint is in the valid array of spawnpoints to use)
				for ( i = 0; i < spawnpoints.size; i++ )
				{
					if ( spawnpoints[i] == self.lastspawnpoint )
					{
						bestspawnpoint = spawnpoints[i];
						break;
					}
				}
			}
		}
	}
	
	if ( !isdefined( bestspawnpoint ) )
	{
		// couldn't find a useable spawnpoint! all will telefrag.
		if ( useweights )
		{
			// at this point, forget about weights. just take a random one.
			bestspawnpoint = spawnpoints[randomint(spawnpoints.size)];
		}
		else
		{
			bestspawnpoint = spawnpoints[0];
		}
	}
	
	self finalizeSpawnpointChoice( bestspawnpoint );
	
	return bestspawnpoint;
}

function finalizeSpawnpointChoice( spawnpoint )
{
	time = getTime();
	
	self.lastspawnpoint = spawnpoint;
	self.lastspawntime = time;
	spawnpoint.lastspawnedplayer = self;
	spawnpoint.lastspawntime = time;
}

function getBestWeightedSpawnpoint( spawnpoints )
{
	maxSightTracedSpawnpoints = 3;
	for ( try = 0; try <= maxSightTracedSpawnpoints; try++ )
	{
		bestspawnpoints = [];
		bestweight = undefined;
		bestspawnpoint = undefined;
		for ( i = 0; i < spawnpoints.size; i++ )
		{
			if ( !isdefined( bestweight ) || spawnpoints[i].weight > bestweight ) 
			{
				if ( positionWouldTelefrag( spawnpoints[i].origin ) )
					continue;
				
				bestspawnpoints = [];
				bestspawnpoints[0] = spawnpoints[i];
				bestweight = spawnpoints[i].weight;
			}
			else if ( spawnpoints[i].weight == bestweight ) 
			{
				if ( positionWouldTelefrag( spawnpoints[i].origin ) )
					continue;
				
				bestspawnpoints[bestspawnpoints.size] = spawnpoints[i];
			}
		}
		if ( bestspawnpoints.size == 0 )
			return undefined;
		
		// pick randomly from the available spawnpoints with the best weight
		bestspawnpoint = bestspawnpoints[randomint( bestspawnpoints.size )];
		
		if ( try == maxSightTracedSpawnpoints )
			return bestspawnpoint;
		
		if ( isdefined( bestspawnpoint.lastSightTraceTime ) && bestspawnpoint.lastSightTraceTime == gettime() )
			return bestspawnpoint;
		
		if ( !lastMinuteSightTraces( bestspawnpoint ) )
			return bestspawnpoint;
		
		penalty = getLosPenalty();
		bestspawnpoint.weight -= penalty;
		
		bestspawnpoint.lastSightTraceTime = gettime();
	}
}

function getSpawnpoint_Random(spawnpoints)
{
//	level endon("game_ended");

	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;

	// randomize order
	for(i = 0; i < spawnpoints.size; i++)
	{
		j = randomInt(spawnpoints.size);
		spawnpoint = spawnpoints[i];
		spawnpoints[i] = spawnpoints[j];
		spawnpoints[j] = spawnpoint;
	}
	
	return getSpawnpoint_Final(spawnpoints, false);
}

function getAllOtherPlayers()
{
	aliveplayers = [];

	// Make a list of fully connected, non-spectating, alive players
	for(i = 0; i < level.players.size; i++)
	{
		if ( !isdefined( level.players[i] ) )
			continue;
		player = level.players[i];
		
		if ( player.sessionstate != "playing" || player == self )
			continue;
		if ( IsDefined(level.customAliveCheck) )
			if ( ! [[level.customAliveCheck]]( player ) )
				continue;
		
		aliveplayers[aliveplayers.size] = player;
	}
	return aliveplayers;
}


function getAllAlliedAndEnemyPlayers( obj )
{
	if ( level.teambased )
	{
		assert( isdefined( level.teams[self.team] ) );
		
		obj.allies = [];
		obj.enemies = [];
		
		for(i = 0; i < level.players.size; i++)
		{
			if ( !isdefined( level.players[i] ) )
				continue;
			player = level.players[i];
			
			if ( player.sessionstate != "playing" || player == self )
				continue;
			if ( IsDefined(level.customAliveCheck) )
				if ( ! [[level.customAliveCheck]]( player ) )
					continue;

			if (player.team == self.team)
				obj.allies[obj.allies.size] = player;
			else
				obj.enemies[obj.enemies.size] = player;

		}
		
/*		
		obj.allies = level.alivePlayers[self.team];
		
		obj.enemies = undefined;
		foreach( team in level.teams )
		{
			if ( team == self.team )
				continue;
			
			if ( !isdefined( obj.enemies ) )
			{
				obj.enemies = level.alivePlayers[team];
			}
			else
			{
				foreach( player in level.alivePlayers[team] )
				{
					obj.enemies[obj.enemies.size] = player;
				}
			}
		}
*/		
	}
	else
	{
		obj.allies = [];
		obj.enemies = level.activePlayers;
	}
}

// weight array manipulation code
function initWeights(spawnpoints)
{
	for (i = 0; i < spawnpoints.size; i++)
		spawnpoints[i].weight = 0;
}


function spawnPointUpdate_zm( spawnpoint )
{
	foreach( team in level.teams )
	{
		spawnpoint.distSum[ team ]=0;
		spawnpoint.enemyDistSum[ team ]=0;
	}
	players = GetPlayers();
	spawnpoint.numPlayersAtLastUpdate = players.size;
	foreach(player in players)
	{
		if ( !isdefined( player ) )
			continue;
		if ( player.sessionstate != "playing" )
			continue;
		if ( IsDefined(level.customAliveCheck) )
			if ( ! [[level.customAliveCheck]]( player ) )
				continue;
		dist = distance( spawnpoint.origin, player.origin );
		spawnpoint.distSum[ player.team ]+=dist;
		foreach( team in level.teams )
		{
			if (team != player.team )
				spawnpoint.enemyDistSum[ team ]+=dist;
		}
	}
}

// ================================================


function getSpawnpoint_NearTeam( spawnpoints, favoredspawnpoints, forceAllyDistanceWeight, forceEnemyDistanceWeight )
{
//	level endon("game_ended");

	/*if ( self.wantSafeSpawn )
	{
		return getSpawnpoint_SafeSpawn( spawnpoints );
	}*/
	
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;
	
	if ( GetDvarint( "scr_spawnsimple") > 0 )
		return getSpawnpoint_Random( spawnpoints );
	
	Spawnlogic_Begin();
	
	k_favored_spawn_point_bonus= 25000;
	
	initWeights(spawnpoints);
	
	obj = spawnstruct();
	getAllAlliedAndEnemyPlayers(obj);
	
	numplayers = obj.allies.size + obj.enemies.size;
	
	alliedDistanceWeight = 2;
	if (IsDefined(forceAllyDistanceWeight))
		alliedDistanceWeight = forceAllyDistanceWeight;
	
	enemyDistanceWeight = 1;
	if (IsDefined(forceEnemyDistanceWeight))
		enemyDistanceWeight = forceEnemyDistanceWeight;
	
	myTeam = self.team;
	for (i = 0; i < spawnpoints.size; i++)
	{
		spawnpoint = spawnpoints[i];
		
		spawnPointUpdate_zm( spawnpoint );
		
		if (!IsDefined(spawnpoint.numPlayersAtLastUpdate))
		{
			spawnpoint.numPlayersAtLastUpdate= 0;
		}
		
		if ( spawnpoint.numPlayersAtLastUpdate > 0 )
		{
			allyDistSum = spawnpoint.distSum[ myTeam ];
			enemyDistSum = spawnpoint.enemyDistSum[ myTeam ];
			
			// high enemy distance is good, high ally distance is bad
			spawnpoint.weight = (enemyDistanceWeight*enemyDistSum - alliedDistanceWeight*allyDistSum) / spawnpoint.numPlayersAtLastUpdate;
		}
		else
		{
			spawnpoint.weight = 0;
		}
	}
	
	if (isdefined(favoredspawnpoints))
	{
		for (i= 0; i < favoredspawnpoints.size; i++)
		{
			if (isdefined(favoredspawnpoints[i].weight))
			{
				favoredspawnpoints[i].weight+= k_favored_spawn_point_bonus;
			}
			else
			{
				favoredspawnpoints[i].weight= k_favored_spawn_point_bonus;
			}
		}
	}
	
	
	
	avoidSameSpawn(spawnpoints);
	avoidSpawnReuse(spawnpoints, true);
	// not avoiding spawning near recent deaths for team-based modes. kills the fast pace.
	//avoidDangerousSpawns(spawnpoints, true);
	avoidWeaponDamage(spawnpoints);
	avoidVisibleEnemies(spawnpoints, true);
	
	
	result = getSpawnpoint_Final(spawnpoints);
	
	return result;
}

/////////////////////////////////////////////////////////////////////////

function getSpawnpoint_DM(spawnpoints)
{
//	level endon("game_ended");

	/*if ( self.wantSafeSpawn )
	{
		return getSpawnpoint_SafeSpawn( spawnpoints );
	}*/
	
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;
	
	Spawnlogic_Begin();

	initWeights(spawnpoints);
	
	aliveplayers = getAllOtherPlayers();
	
	// new logic: we want most players near idealDist units away.
	// players closer than badDist units will be considered negatively
	idealDist = 1600;
	badDist = 1200;
	
	if (aliveplayers.size > 0)
	{
		for (i = 0; i < spawnpoints.size; i++)
		{
			totalDistFromIdeal = 0;
			nearbyBadAmount = 0;
			for (j = 0; j < aliveplayers.size; j++)
			{
				dist = distance(spawnpoints[i].origin, aliveplayers[j].origin);
				
				if (dist < badDist )
					nearbyBadAmount += (badDist - dist) / badDist;
				
				distfromideal = abs(dist - idealDist);
				totalDistFromIdeal += distfromideal;
			}
			avgDistFromIdeal = totalDistFromIdeal / aliveplayers.size;
			
			wellDistancedAmount = (idealDist - avgDistFromIdeal) / idealDist;
			// if (wellDistancedAmount < 0) wellDistancedAmount = 0;
			
			// wellDistancedAmount is between -inf and 1, 1 being best (likely around 0 to 1)
			// nearbyBadAmount is between 0 and inf,
			// and it is very important that we get a bad weight if we have a high nearbyBadAmount.
			
			spawnpoints[i].weight = wellDistancedAmount - nearbyBadAmount * 2 + randomfloat(.2);
		}
	}
	
	avoidSameSpawn(spawnpoints);
	avoidSpawnReuse(spawnpoints, false);
	//avoidDangerousSpawns(spawnpoints, false);
	avoidWeaponDamage(spawnpoints);
	avoidVisibleEnemies(spawnpoints, false);
	
	return getSpawnpoint_Final(spawnpoints);
}

/////////////////////////////////////////////////////////////////////////
//
// Hybrid of NearTeam and DM 
//


function getSpawnpoint_Turned( spawnpoints, idealDist, badDist, idealDistTeam, badDistTeam )
{
//	level endon("game_ended");

	/*if ( self.wantSafeSpawn )
	{
		return getSpawnpoint_SafeSpawn( spawnpoints );
	}*/
	
	// There are no valid spawnpoints in the map
	if(!isdefined(spawnpoints))
		return undefined;
	
	Spawnlogic_Begin();

	initWeights(spawnpoints);
	
	aliveplayers = getAllOtherPlayers();
	
	// new logic: we want most players near idealDist units away.
	// players closer than badDist units will be considered negatively
	if (!isDefined(idealDist))
		idealDist = 1600;
	if (!isDefined(idealDistTeam))
		idealDistTeam = 1200;
	if (!isDefined(badDist))
		badDist = 1200;
	if (!isDefined(badDistTeam))
		badDistTeam = 600;
	
	myTeam = self.team;
	if (aliveplayers.size > 0)
	{
		for (i = 0; i < spawnpoints.size; i++)
		{
			totalDistFromIdeal = 0;
			nearbyBadAmount = 0;
			for (j = 0; j < aliveplayers.size; j++)
			{
				dist = distance(spawnpoints[i].origin, aliveplayers[j].origin);
				distfromideal = 0;
				
				if ( aliveplayers[j].team == myTeam )
				{
					if (dist < badDistTeam )
						nearbyBadAmount += (badDistTeam - dist) / badDistTeam;
					distfromideal = abs(dist - idealDistTeam);
				}
				else
				{
					if (dist < badDist )
						nearbyBadAmount += (badDist - dist) / badDist;
					distfromideal = abs(dist - idealDist);
				}
				
				totalDistFromIdeal += distfromideal;
			}
			avgDistFromIdeal = totalDistFromIdeal / aliveplayers.size;
			
			wellDistancedAmount = (idealDist - avgDistFromIdeal) / idealDist;
			// if (wellDistancedAmount < 0) wellDistancedAmount = 0;
			
			// wellDistancedAmount is between -inf and 1, 1 being best (likely around 0 to 1)
			// nearbyBadAmount is between 0 and inf,
			// and it is very important that we get a bad weight if we have a high nearbyBadAmount.
			
			spawnpoints[i].weight = wellDistancedAmount - nearbyBadAmount * 2 + randomfloat(.2);
		}
	}
	
	avoidSameSpawn(spawnpoints);
	avoidSpawnReuse(spawnpoints, false);
	//avoidDangerousSpawns(spawnpoints, false);
	avoidWeaponDamage(spawnpoints);
	avoidVisibleEnemies(spawnpoints, false);
	
	return getSpawnpoint_Final(spawnpoints);
}

// =============================================

// called at the start of every spawn
function Spawnlogic_Begin()
{
	//updateDeathInfo();

}

// DEBUG
function showDeathsDebug()
{
}
// DEBUG
function updateDeathInfoDebug()
{
	while(1)
	{
		if (GetDvarString( "scr_spawnpointdebug") == "0") {
			wait(3);
			continue;
		}
		updateDeathInfo();
		wait(3);
	}
}
// DEBUG
function spawnWeightDebug(spawnpoints)
{
	level notify("stop_spawn_weight_debug");
	level endon("stop_spawn_weight_debug");
}
// DEBUG
function profileDebug()
{
	while(1)
	{
		if (GetDvarString( "scr_spawnpointprofile") != "1") {
			wait(3);
			continue;
		}
		
		for (i = 0; i < level.spawnpoints.size; i++)
			level.spawnpoints[i].weight = randomint(10000);
		if (level.players.size > 0)
			level.players[randomint(level.players.size)] getSpawnpoint_NearTeam(level.spawnpoints);
		
		wait(.05);
	}
}
// DEBUG
function debugNearbyPlayers(players, origin)
{
}

function deathOccured(dier, killer)
{
	/*if (!isdefined(killer) || !isdefined(dier) || !isplayer(killer) || !isplayer(dier) || killer == dier)
		return;
	
	time = getTime();
	
	// DEBUG
	// check if there was a spawn kill
	if (time - dier.lastspawntime < 5*1000 && distance(dier.origin, dier.lastspawnpoint.origin) < 300)
	{
		spawnkill = spawnstruct();
		spawnkill.dierwasspawner = true;
		spawnkill.dierorigin = dier.origin;
		spawnkill.killerorigin = killer.origin;
		spawnkill.spawnpointorigin = dier.lastspawnpoint.origin;
		spawnkill.time = time;
		level.spawnlogic_spawnkills[level.spawnlogic_spawnkills.size] = spawnkill;
	}
	else if (time - killer.lastspawntime < 5*1000 && distance(killer.origin, killer.lastspawnpoint.origin) < 300)
	{
		spawnkill = spawnstruct();
		spawnkill.dierwasspawner = false;
		spawnkill.dierorigin = dier.origin;
		spawnkill.killerorigin = killer.origin;
		spawnkill.spawnpointorigin = killer.lastspawnpoint.origin;
		spawnkill.time = time;
		level.spawnlogic_spawnkills[level.spawnlogic_spawnkills.size] = spawnkill;
	}
	
	// record kill information
	deathInfo = spawnstruct();
	
	deathInfo.time = time;
	deathInfo.org = dier.origin;
	deathInfo.killOrg = killer.origin;
	deathInfo.killer = killer;
	
	checkForSimilarDeaths(deathInfo);
	level.spawnlogic_deaths[level.spawnlogic_deaths.size] = deathInfo;
	
	// keep track of the most dangerous players in terms of how far they have killed people recently
	dist = distance(dier.origin, killer.origin);
	if (!isdefined(killer.spawnlogic_killdist) || time - killer.spawnlogic_killtime > 1000*30 || dist > killer.spawnlogic_killdist)
	{
		killer.spawnlogic_killdist = dist;
		killer.spawnlogic_killtime = time;
	}*/
}
function checkForSimilarDeaths(deathInfo)
{
	// check if this is really similar to any old deaths, and if so, mark them for removal later
	for (i = 0; i < level.spawnlogic_deaths.size; i++)
	{
		if (level.spawnlogic_deaths[i].killer == deathInfo.killer)
		{
			dist = distance(level.spawnlogic_deaths[i].org, deathInfo.org);
			if (dist > 200) continue;
			dist = distance(level.spawnlogic_deaths[i].killOrg, deathInfo.killOrg);
			if (dist > 200) continue;
			
			level.spawnlogic_deaths[i].remove = true;
		}
	}
}

function updateDeathInfo()
{
	
	time = getTime();
	for (i = 0; i < level.spawnlogic_deaths.size; i++)
	{
		// if the killer has walked away or enough time has passed, get rid of this death information
		deathInfo = level.spawnlogic_deaths[i];
		
		if (time - deathInfo.time > 1000*90 || // if 90 seconds have passed
			!isdefined(deathInfo.killer) ||
			!isalive(deathInfo.killer) ||
			(!isdefined( level.teams[deathInfo.killer.team] )) ||
			distance(deathInfo.killer.origin, deathInfo.killOrg) > 400) {
			level.spawnlogic_deaths[i].remove = true;
		}
	}
	
	// remove all deaths with remove set
	oldarray = level.spawnlogic_deaths;
	level.spawnlogic_deaths = [];
	
	// never keep more than the 1024 most recent entries in the array
	start = 0;
	if (oldarray.size - 1024 > 0) start = oldarray.size - 1024;
	
	for (i = start; i < oldarray.size; i++)
	{
		if (!isdefined(oldarray[i].remove))
			level.spawnlogic_deaths[level.spawnlogic_deaths.size] = oldarray[i];
	}

}	

/*
// uses death information to reduce the weights of spawns that might cause spawn kills
function avoidDangerousSpawns(spawnpoints, teambased) // (assign weights to the return value of this)
{
	// DEBUG
	if (GetDvarString( "scr_spawnpointnewlogic") == "0") {
		return;
	}

	// DEBUG
	
	deathpenalty = 100000;
	if (GetDvarString( "scr_spawnpointdeathpenalty") != "" && GetDvarString( "scr_spawnpointdeathpenalty") != "0")
		deathpenalty = GetDvarfloat( "scr_spawnpointdeathpenalty");
	
	maxDist = 200;
	if (GetDvarString( "scr_spawnpointmaxdist") != "" && GetDvarString( "scr_spawnpointmaxdist") != "0")
		maxdist = GetDvarfloat( "scr_spawnpointmaxdist");
	
	maxDistSquared = maxDist*maxDist;
	for (i = 0; i < spawnpoints.size; i++)
	{
		for (d = 0; d < level.spawnlogic_deaths.size; d++)
		{
			// (we've got a lotta checks to do, want to rule them out quickly)
			distSqrd = distanceSquared(spawnpoints[i].origin, level.spawnlogic_deaths[d].org);
			if (distSqrd > maxDistSquared)
				continue;
			
			// make sure the killer in question is on the opposing team
			player = level.spawnlogic_deaths[d].killer;
			if (!isalive(player)) continue;
			if (player == self) continue;
			if (teambased && player.team == self.team) continue;
			
			// (no sqrt, must recalculate distance)
			dist = distance(spawnpoints[i].origin, level.spawnlogic_deaths[d].org);
			spawnpoints[i].weight -= (1 - dist/maxDist) * deathpenalty; // possible spawn kills are *really* bad
		}
	}
	
	// DEBUG
}	
*/


// used by spawning; needs to be fast.
function isPointVulnerable(playerorigin)
{
	pos = self.origin + level.bettymodelcenteroffset;
	playerpos = playerorigin + (0,0,32);
	distsqrd = distancesquared(pos, playerpos);
	
	forward = anglestoforward(self.angles);
	
	if (distsqrd < level.bettyDetectionRadius*level.bettyDetectionRadius)
	{
		playerdir = vectornormalize(playerpos - pos);
		angle = acos(vectordot(playerdir, forward));
		if (angle < level.bettyDetectionConeAngle) {
			return true;
		}
	}
	return false;
}


function avoidWeaponDamage(spawnpoints)
{
	if (GetDvarString( "scr_spawnpointnewlogic") == "0") 
	{
		return;
	}
	
	
	weaponDamagePenalty = 100000;
	if (GetDvarString( "scr_spawnpointweaponpenalty") != "" && GetDvarString( "scr_spawnpointweaponpenalty") != "0")
		weaponDamagePenalty = GetDvarfloat( "scr_spawnpointweaponpenalty");

	mingrenadedistsquared = 250*250; // (actual grenade radius is 220, 250 includes a safety area of 30 units)

	for (i = 0; i < spawnpoints.size; i++)
	{
		for (j = 0; j < level.grenades.size; j++)
		{
			if ( !isdefined( level.grenades[j] ) )
				continue;

			// could also do a sight check to see if it's really dangerous.
			if (distancesquared(spawnpoints[i].origin, level.grenades[j].origin) < mingrenadedistsquared)
			{
				spawnpoints[i].weight -= weaponDamagePenalty;
			}
		}
	}

}	

function spawnPerFrameUpdate()
{
	spawnpointindex = 0;
		
	// each frame, do sight checks against a spawnpoint
	
	while(1)
	{
		wait .05;
		
		
		//time = gettime();
		
		if ( !isdefined( level.spawnPoints ) )
			return;
		
		spawnpointindex = (spawnpointindex + 1) % level.spawnPoints.size;
		spawnpoint = level.spawnPoints[spawnpointindex];
		
		spawnPointUpdate( spawnpoint );
		
	}	
}

function getNonTeamSum( skip_team, sums )
{
	value = 0;
	foreach( team in level.teams )
	{
		if ( team == skip_team )
			continue;
			
		value += sums[team];
	}
	
	return value;
}

function getNonTeamMinDist( skip_team, minDists )
{
	dist = 9999999;
	foreach( team in level.teams )
	{
		if ( team == skip_team )
			continue;
			
		if ( dist > minDists[team] )
			dist = minDists[team];
	}
	
	return dist;
}


function spawnPointUpdate( spawnpoint )
{
	if ( level.teambased )
	{
		sights = [];
		foreach( team in level.teams )
		{
			spawnpoint.enemySights[team] = 0;
			sights[team] = 0;
			spawnpoint.nearbyPlayers[team] = [];
		}
	}
	else
	{
		spawnpoint.enemySights = 0;
		
		spawnpoint.nearbyPlayers["all"] = [];
	}
	
	spawnpointdir = spawnpoint.forward;
	
	debug = false;
	
	minDist = [];
	distSum = [];
	
	if ( !level.teambased )
	{
		minDist["all"] = 9999999;
	}

	foreach( team in level.teams )
	{
		spawnpoint.distSum[team] = 0;
		spawnpoint.enemyDistSum[team] = 0;
		spawnpoint.minEnemyDist[team] = 9999999;
		minDist[team] = 9999999;
	}
	
	spawnpoint.numPlayersAtLastUpdate = 0;
		
	for (i = 0; i < level.players.size; i++)
	{
		player = level.players[i];
		
		if ( player.sessionstate != "playing" )
			continue;
		
		diff = player.origin - spawnpoint.origin;
		diff = (diff[0], diff[1], 0);
		dist = length( diff ); // needs to be actual distance for distSum value
		
		team = "all";
		if ( level.teambased )
			team = player.team;
		
		if ( dist < 1024 )
		{
			spawnpoint.nearbyPlayers[team][spawnpoint.nearbyPlayers[team].size] = player;
		}
		
		if ( dist < minDist[team] )
			minDist[team] = dist;
	
		distSum[ team ] += dist;
		spawnpoint.numPlayersAtLastUpdate++;
		
		pdir = anglestoforward(player.angles);
		if (vectordot(spawnpointdir, diff) < 0 && vectordot(pdir, diff) > 0)
			continue; // player and spawnpoint are looking in opposite directions
		
		// do sight check
		losExists = bullettracepassed(player.origin + (0,0,50), spawnpoint.sightTracePoint, false, undefined);
		
		spawnpoint.lastSightTraceTime = gettime();
		
		if (losExists)
		{
			if ( level.teamBased )
				sights[player.team]++;
			else
				spawnpoint.enemySights++;
			
			// DEBUG
			//println("Sight check succeeded!");
			
			/*
			death info stuff is disabled right now
			// pretend this player killed a person at this spawnpoint, so we don't try to use it again any time soon.
			deathInfo = spawnstruct();
			
			deathInfo.time = time;
			deathInfo.org = spawnpoint.origin;
			deathInfo.killOrg = player.origin;
			deathInfo.killer = player;
			deathInfo.los = true;
			
			checkForSimilarDeaths(deathInfo);
			level.spawnlogic_deaths[level.spawnlogic_deaths.size] = deathInfo;
			*/
			
		}
		//else
		//	line(player.origin + (0,0,50), spawnpoint.sightTracePoint, (1,.5,.5));
	}
	
	if ( level.teamBased )
	{
		foreach( team in level.teams )
		{
			spawnpoint.enemySights[team] = getNonTeamSum( team, sights );
			spawnpoint.minEnemyDist[team] = getNonTeamMinDist( team, minDist );
			spawnpoint.distSum[team] = distSum[team];
			spawnpoint.enemyDistSum[team] = getNonTeamSum( team, distSum);
		}
	}
	else
	{
		spawnpoint.distSum["all"] = distSum["all"];
		spawnpoint.enemyDistSum["all"] = distSum["all"];
		spawnpoint.minEnemyDist["all"] = minDist["all"];
	}	

}

function getLosPenalty()
{
	if (GetDvarString( "scr_spawnpointlospenalty") != "" && GetDvarString( "scr_spawnpointlospenalty") != "0")
		return GetDvarfloat( "scr_spawnpointlospenalty");
	return 100000;
}

function lastMinuteSightTraces( spawnpoint )
{	
	if ( !isdefined( spawnpoint.nearbyPlayers ) )
		return false;
	
	closest = undefined;
	closestDistsq = undefined;
	secondClosest = undefined;
	secondClosestDistsq = undefined;
	
	foreach( team in spawnpoint.nearbyPlayers )
	{
		if ( team == self.team )
			continue;
			
		for ( i = 0; i < spawnpoint.nearbyPlayers[team].size; i++ )
		{
			player = spawnpoint.nearbyPlayers[team][i];
			
			if ( !isdefined( player ) )
				continue;
			if ( player.sessionstate != "playing" )
				continue;
			if ( player == self )
				continue;
			
			distsq = distanceSquared( spawnpoint.origin, player.origin );
			if ( !isdefined( closest ) || distsq < closestDistsq )
			{
				secondClosest = closest;
				secondClosestDistsq = closestDistsq;
				
				closest = player;
				closestDistSq = distsq;
			}
			else if ( !isdefined( secondClosest ) || distsq < secondClosestDistSq )
			{
				secondClosest = player;
				secondClosestDistSq = distsq;
			}
		}
	}
	
	if ( isdefined( closest ) )
	{
		if ( bullettracepassed( closest.origin       + (0,0,50), spawnpoint.sightTracePoint, false, undefined) )
			return true;
	}
	if ( isdefined( secondClosest ) )
	{
		if ( bullettracepassed( secondClosest.origin + (0,0,50), spawnpoint.sightTracePoint, false, undefined) )
			return true;
	}
	
	return false;
}



function avoidVisibleEnemies(spawnpoints, teambased)
{
	if (GetDvarString( "scr_spawnpointnewlogic") == "0") 
	{
		return;
	}

	// DEBUG
	
	lospenalty = getLosPenalty();
	
	minDistTeam = self.team;
	
	if ( teambased )
	{
		for ( i = 0; i < spawnpoints.size; i++ )
		{
			if ( !isdefined(spawnpoints[i].enemySights) )
				continue;
			
			penalty = lospenalty * spawnpoints[i].enemySights[self.team];
			spawnpoints[i].weight -= penalty;
		}
	}
	else
	{
		for ( i = 0; i < spawnpoints.size; i++ )
		{
			if ( !isdefined(spawnpoints[i].enemySights) )
				continue;

			penalty = lospenalty * spawnpoints[i].enemySights;
			spawnpoints[i].weight -= penalty;
		}
		
		minDistTeam = "all";
	}
	
	avoidWeight = GetDvarfloat( "scr_spawn_enemyavoidweight");
	if ( avoidWeight != 0 )
	{
		nearbyEnemyOuterRange = GetDvarfloat( "scr_spawn_enemyavoiddist");
		nearbyEnemyOuterRangeSq = nearbyEnemyOuterRange * nearbyEnemyOuterRange;
		nearbyEnemyPenalty = 1500 * avoidWeight; // typical base weights tend to peak around 1500 or so. this is large enough to upset that while only locally dominating it.
		nearbyEnemyMinorPenalty = 800 * avoidWeight; // additional negative weight for distances up to 2 * nearbyEnemyOuterRange
		
		lastAttackerOrigin = (-99999,-99999,-99999);
		lastDeathPos = (-99999,-99999,-99999);
		if ( isAlive( self.lastAttacker ) )
			lastAttackerOrigin = self.lastAttacker.origin;
		if ( isdefined( self.lastDeathPos ) )
			lastDeathPos = self.lastDeathPos;
		
		for ( i = 0; i < spawnpoints.size; i++ )
		{
			// penalty for nearby enemies
			mindist = spawnpoints[i].minEnemyDist[minDistTeam];
			if ( mindist < nearbyEnemyOuterRange*2 )
			{
				penalty = nearbyEnemyMinorPenalty * (1 - mindist / (nearbyEnemyOuterRange*2));
				if ( mindist < nearbyEnemyOuterRange )
					penalty += nearbyEnemyPenalty * (1 - mindist / nearbyEnemyOuterRange);
				if ( penalty > 0 )
				{
					spawnpoints[i].weight -= penalty;
				}
			}
			
			/*
			// additional penalty for being near the guy who just killed me
			distSq = distanceSquared( lastAttackerOrigin, spawnpoints[i].origin );
			if ( distSq < nearbyEnemyOuterRangeSq )
			{
				penalty = nearbyEnemyPenalty * (1 - sqrt( distSq ) / nearbyEnemyOuterRange);
				assert( penalty > 0 );
				spawnpoints[i].weight -= penalty;
			}
			*/
			
			/*
			// penalty for being near where i just died
			distSq = distanceSquared( lastDeathPos, spawnpoints[i].origin );
			if ( distSq < nearbyEnemyOuterRangeSq )
			{
				penalty = nearbyEnemyPenalty * (1 - sqrt( distSq ) / nearbyEnemyOuterRange);
				assert( penalty > 0 );
				spawnpoints[i].weight -= penalty;
			}
			*/
		}
	}
				
	// DEBUG
}	

function avoidSpawnReuse(spawnpoints, teambased)
{
	// DEBUG
	if (GetDvarString( "scr_spawnpointnewlogic") == "0") {
		return;
	}
	
	
	time = getTime();
	
	maxtime = 10*1000;
	maxdistSq = 1024 * 1024;

	for (i = 0; i < spawnpoints.size; i++)
	{
		spawnpoint = spawnpoints[i];
		
		if (!isdefined(spawnpoint.lastspawnedplayer) || !isdefined(spawnpoint.lastspawntime) ||
			!isalive(spawnpoint.lastspawnedplayer))
			continue;

		if (spawnpoint.lastspawnedplayer == self) 
			continue;
		if (teambased && spawnpoint.lastspawnedplayer.team == self.team) 
			continue;
		
		timepassed = time - spawnpoint.lastspawntime;
		if (timepassed < maxtime)
		{
			distSq = distanceSquared(spawnpoint.lastspawnedplayer.origin, spawnpoint.origin);
			if (distSq < maxdistSq)
			{
				worsen = 5000 * (1 - distSq/maxdistSq) * (1 - timepassed/maxtime);
				spawnpoint.weight -= worsen;
			}
			else
				spawnpoint.lastspawnedplayer = undefined; // don't worry any more about this spawnpoint
		}
		else
			spawnpoint.lastspawnedplayer = undefined; // don't worry any more about this spawnpoint
	}

}	

function avoidSameSpawn(spawnpoints)
{
	// DEBUG
	if (GetDvarString( "scr_spawnpointnewlogic") == "0") {
		return;
	}
	
	
	if (!isdefined(self.lastspawnpoint))
		return;
	
	for (i = 0; i < spawnpoints.size; i++)
	{
		if (spawnpoints[i] == self.lastspawnpoint) 
		{
			spawnpoints[i].weight -= 50000; // (half as bad as a likely spawn kill)
			break;
		}
	}
	
}	

function getRandomIntermissionPoint()
{
		spawnpoints = getentarray("mp_global_intermission", "classname");
		if ( !spawnpoints.size )
		{
			spawnpoints = getentarray("info_player_start", "classname");
		}
		assert( spawnpoints.size );
		spawnpoint = spawnlogic::getSpawnpoint_Random(spawnpoints);
	
		return spawnpoint;
}
