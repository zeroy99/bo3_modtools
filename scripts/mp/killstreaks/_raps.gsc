#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_raps;
#using scripts\shared\weapons\_smokegrenade;

#using scripts\mp\gametypes\_battlechatter;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\mp\teams\_teams;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_airsupport;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace raps_mp;

#define RAPS_HURT_TRIGGER_IMMUNE_DURATION_MS	5000
#define RAPS_HELI_POST_DEATH_FX_GHOST_DELAY		0.1

#precache( "string", "KILLSTREAK_DESTROYED_RAPS_DEPLOY_SHIP");	
#precache( "string", "KILLSTREAK_EARNED_RAPS" );
#precache( "string", "KILLSTREAK_RAPS_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_RAPS_NOT_PLACEABLE" );
#precache( "string", "KILLSTREAK_RAPS_INBOUND" );
#precache( "string", "KILLSTREAK_RAPS_HACKED" );
#precache( "eventstring", "mpl_killstreak_raps" );
#precache( "fx", RAPS_HELI_FIRST_EXPLO_FX );
#precache( "fx", RAPS_HELI_DEATH_TRAIL_FX );
#precache( "fx", RAPS_HELI_DEATH_FX );

function init()
{	
	level.raps_settings = level.scriptbundles[ "vehiclecustomsettings" ][ "rapssettings_mp" ];
	assert( isdefined( level.raps_settings ) );
	
	level.raps = [];
	level.raps_helicopters = [];
	
	level.raps_force_get_enemies = &ForceGetEnemies;
	
	killstreaks::register( RAPS_NAME, RAPS_NAME, "killstreak_raps", "raps_used", &ActivateRapsKillstreak, true );
	killstreaks::register_strings( RAPS_NAME, &"KILLSTREAK_EARNED_RAPS", &"KILLSTREAK_RAPS_NOT_AVAILABLE", &"KILLSTREAK_RAPS_INBOUND", undefined, &"KILLSTREAK_RAPS_HACKED" );
	killstreaks::register_dialog( RAPS_NAME, "mpl_killstreak_raps", "rapsHelicopterDialogBundle", "rapsHelicopterPilotDialogBundle", "friendlyRaps", "enemyRaps", "enemyRapsMultiple", "friendlyRapsHacked", "enemyRapsHacked", "requestRaps", "threatRaps" );
	killstreaks::allow_assists( RAPS_NAME, true );
	
	killstreak_bundles::register_killstreak_bundle( RAPS_DRONE_NAME );

	InitHelicopterPositions();
	
	callback::on_connect( &OnPlayerConnect );
	
	clientfield::register( "vehicle", "monitor_raps_drop_landing", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "raps_heli_low_health", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "raps_heli_extra_low_health", VERSION_SHIP, 1, "int" );
		
	// level thread RapsHelicopterDynamicAvoidance(); // aku: disabling avoidance for now because it's avoidance technique does not "look right", going for different z heights for now
	
	level.raps_helicopter_drop_tag_names = [];
	level.raps_helicopter_drop_tag_names[0] = "tag_raps_drop_left";
	level.raps_helicopter_drop_tag_names[1] = "tag_raps_drop_right";
}

function OnPlayerConnect()
{
	self.entNum = self getEntityNumber();
	level.raps[ self.entNum ] = spawnstruct();
	level.raps[ self.entNum ].killstreak_id = INVALID_KILLSTREAK_ID;
	level.raps[ self.entNum ].raps = [];
	level.raps[ self.entNum ].helicopter = undefined;
}

/*	RapsHelicopterDynamicAvoidance
 * 
 * 	This method supports a simple avoidance system for the RAPS Helicopter (RAPS deploy ship).
 * 
 * 	The RAPS helicopters are required to fly at the same hight. To prevent overlapping, this system checks
 * 	the helicopters relative to each other and changes driving behavior based on different distances.
 *  The system will choose another deploy point based on distance, last pick time, and other factors.
 * 
 *	Note: tuning vars in _killstreaks.gsh using RAPS_HELAV where HELAV is short for Helicopter Avoidance
 * 
 *	The RAPS helicopter avoidance has been designed to function with at most two RAPS helicopters for now.
 * 
 *	Key concepts in use:
 * 		a. Forward Reference Point	-- distances are measured relative to this forward reference point ( RAPS_HELAV_FORWARD_OFFSET )
 * 		b. Other Forward Ref Point	-- this is the reference point used when testing distances from another helicopter ( RAPS_HELAV_OTHER_FORWARD_OFFSET )
 * 		c. Stop Distance			-- the helicopter stops when another helicopter is within this distance
 * 		d. Slow Down Distance		-- the helicopter slows down when another helicopter is within this distance
 * 		e. Pick New Goal Distance	-- the helicopter selects a new drop point when the other helicopter is within this distance
 * 		f. Backing Off				-- if a helicopter stops and the other helicopter is in front of it, it will pick a random point opposite 
 * 											the direction behind it and can pick a new goal (drop point) to go to after it backs off
 * 		g. Drive Mode				-- there are four different drive modes: expedient, cautious, more cautious, and stop.
 * 											Each has different speed, acceleration, and deceleration.
 * 
 */
function RapsHelicopterDynamicAvoidance()
{
	level endon( "game_ended" );
	
	index_to_update = 0;
	
	while( true )
	{
		RapsHelicopterDynamicAvoidanceUpdate( index_to_update );
		
		index_to_update++;
		if ( index_to_update >= level.raps_helicopters.size )
			index_to_update = 0;
			
		wait( RAPS_HELAV_TIME_BETWEEN_UPDATES );
	}
}

function RapsHelicopterDynamicAvoidanceUpdate( index_to_update )
{
	helicopterRefOrigin = ( 0, 0, 0 );
	otherHelicopterRefOrigin = ( 0, 0, 0 );

	ArrayRemoveValue( level.raps_helicopters, undefined );
	
	if ( index_to_update >= level.raps_helicopters.size )
		index_to_update = 0;

	if( level.raps_helicopters.size >= 2 )
	{			
		helicopter = level.raps_helicopters[index_to_update];
		/#	helicopter.__action_just_made = false; #/
			
		for( i = 0; i < level.raps_helicopters.size; i++ )
		{
			if ( i == index_to_update )
				continue;
			
			if ( helicopter.droppingRaps )
				continue;
			
			if ( !isdefined( helicopter.lastNewGoalTime ) )
				helicopter.lastNewGoalTime = GetTime();
			
			helicopterForward = AnglesToForward( helicopter GetAngles() );
			helicopterRefOrigin = helicopter.origin + ( helicopterForward * RAPS_HELAV_FORWARD_OFFSET );
			otherHelicopterForward = AnglesToForward( level.raps_helicopters[i] GetAngles() );
			otherHelicopterRefOrigin = level.raps_helicopters[i].origin + ( otherHelicopterForward * RAPS_HELAV_OTHER_FORWARD_OFFSET );
			deltaToOther = otherHelicopterRefOrigin - helicopterRefOrigin;
			otherInFront = ( VectorDot( helicopterForward, VectorNormalize( deltaToOther ) ) > RAPS_HELAV_IN_FRONT_DOT );
			distanceSqr = Distance2DSquared( helicopterRefOrigin, otherHelicopterRefOrigin);

			if ( (distanceSqr < RAPS_HELAV_NEED_NEW_GOAL_DISTANCE_SQR || helicopter GetSpeed() == 0 )
					&& (GetTime() - helicopter.lastNewGoalTime) > RAPS_HELAV_MIN_PICK_NEW_GOAL_TIME_MS )
			{
				//
				//	pick a new goal based on distance, speed, and the last time picked
				//
				/#	helicopter.__last_dynamic_avoidance_action = 20;	/* new goal */ #/
				/#	helicopter.__action_just_made = true; #/
					
				helicopter UpdateHelicopterSpeed();
				if ( helicopter.isLeaving )
				{
					self.leaveLocation = GetRandomHelicopterLeaveOrigin( /*self.assigned_fly_height*/ 0, self.origin );
					helicopter setVehGoalPos( self.leaveLocation, 0 );
				}
				else
				{	
					self.targetDropLocation = GetRandomHelicopterPosition( self.lastDropLocation );
					helicopter setVehGoalPos( self.targetDropLocation, 1 );
				}
				helicopter.lastNewGoalTime = GetTime();
			}
			else if ( distanceSqr < RAPS_HELAV_FULL_STOP_DISTANCE_SQR
		         	&& otherInFront
		         	&& (GetTime() - helicopter.lastStopTime) > RAPS_HELAV_MIN_TIME_BETWEEN_FULL_STOPS_MS
				)
			{
				//
				//	do a full stop if the other helicopter is in front and is too close
				//
				/#	helicopter.__last_dynamic_avoidance_action = 10;	/* stop */ #/
				/#	helicopter.__action_just_made = true; #/
					
				helicopter StopHelicopter();
			}
			else if ( helicopter GetSpeed() == 0 && otherInFront && distanceSqr < RAPS_HELAV_FULL_STOP_DISTANCE_SQR )
			{
				//
				//	after a full stop, have the helicopter back off if the other helicopter is in front and too close
				//	and a new drop location may be picked based on the tuning vars
				//
				/#	helicopter.__last_dynamic_avoidance_action = 50;	/* back off */ #/
				/#	helicopter.__action_just_made = true; #/
			
				delta = otherHelicopterRefOrigin - helicopterRefOrigin;
				newGoalPosition = helicopter.origin -
				           	( deltaToOther[0] * RandomFloatRange( RAPS_HELAV_BACK_OFF_FACTOR_MIN, RAPS_HELAV_BACK_OFF_FACTOR_MAX ),
				              deltaToOther[1] * RandomFloatRange( RAPS_HELAV_BACK_OFF_FACTOR_MIN, RAPS_HELAV_BACK_OFF_FACTOR_MAX), 0 );
				helicopter UpdateHelicopterSpeed();
				helicopter setVehGoalPos( newGoalPosition, 0 );
				
				// pick a new drop location for use after the "back off" goal is reached
				if ( RAPS_HELAV_ALWAYS_PICK_NEW_GOAL_POST_BACK_OFF || (GetTime() - helicopter.lastNewGoalTime) > RAPS_HELAV_MIN_PICK_NEW_GOAL_TIME_MS )
				{
					/#	helicopter.__last_dynamic_avoidance_action = 51;	/* back off + new goal */ #/
					helicopter.targetDropLocation = GetClosestRandomHelicopterPosition( newGoalPosition, 8 );
					helicopter.lastNewGoalTime = GetTime();
				}
			}
			else if ( distanceSqr < RAPS_HELAV_SLOW_DOWN_DISTANCE_SQR && helicopter.driveModeSpeedScale == 1.0 )
			{
				//
				//	slow down the helicopter if within the configured distances and at full speed
				//	there is a cautious and a more cautious speed based on if the other helicopter is in front
				//
				/#	helicopter.__last_dynamic_avoidance_action = (( otherInFront ) ? 31 : 30);	/* cautious */ #/
				/#	helicopter.__action_just_made = true; #/	
					
				helicopter UpdateHelicopterSpeed( ( (otherInFront) ? RAPS_HELAV_DRIVE_MODE_MORE_CAUTIOUS : RAPS_HELAV_DRIVE_MODE_CAUTIOUS) );
			}
			else if ( distanceSqr >= RAPS_HELAV_SLOW_DOWN_DISTANCE_SQR && helicopter.driveModeSpeedScale < 1.0 )
			{
				//
				//	speed the helicopter back up if we are beyond the slow down distance and set to drive at full speed
				//
				/#	helicopter.__last_dynamic_avoidance_action = 40;	/* expedient */ #/
				/#	helicopter.__action_just_made = true; #/

				helicopter UpdateHelicopterSpeed( RAPS_HELAV_DRIVE_MODE_EXPEDIENT );
			}
			else if ( helicopter GetSpeed() == 0 && (GetTime() - helicopter.lastStopTime) > RAPS_HELAV_MIN_TIME_BETWEEN_FULL_STOPS_MS )
			{
				//
				// resume moving -- start mmoving again if we have stopped for too long
				//
				// devblock to report last action made intentionally left out.
				
				helicopter UpdateHelicopterSpeed();
			}
		}
		
		/#
		//================================================================================================
		//
		//	this code section is meant for visual debuggingof the RAPS Helicopter dynamic avoidance system
		//
		//------------------------------------------------------------------------------------------------
		//
		if ( RAPS_HELAV_DEBUG )
		{
			if ( isdefined( helicopter ) )
			{
				server_frames_to_persist = INT( (RAPS_HELAV_TIME_BETWEEN_UPDATES * 2) / SERVER_FRAME );
				
				Sphere( helicopterRefOrigin, 		10, ( 0, 0, 1 ), 1, false, 10, server_frames_to_persist );
				Sphere( otherHelicopterRefOrigin,	10, ( 1, 0, 0 ), 1, false, 10, server_frames_to_persist );
				
				circle( helicopterRefOrigin, RAPS_HELAV_SLOW_DOWN_DISTANCE, 	( 1, 1, 0 ), true, true, server_frames_to_persist );	
				circle( helicopterRefOrigin, RAPS_HELAV_NEED_NEW_GOAL_DISTANCE,	( 0, 0, 0 ), true, true, server_frames_to_persist );
				circle( helicopterRefOrigin, RAPS_HELAV_FULL_STOP_DISTANCE,		( 1, 0, 0 ), true, true, server_frames_to_persist );
				
				Print3d( helicopter.origin, "Speed: " + INT( helicopter GetSpeedMPH() ), (1,1,1), 1, 2.5, server_frames_to_persist );
				
				action_debug_color = ( 0.8, 0.8, 0.8 );
				debug_action_string = "";
				if ( helicopter.__action_just_made )
					action_debug_color = ( 0, 1, 0 );
					
				switch ( helicopter.__last_dynamic_avoidance_action )
				{
					case 0:		break;	// do nothing
					case 10:	debug_action_string = "stop";			break;
					case 20:	debug_action_string = "new goal";		break;
					case 30:	debug_action_string = "cautious";		break;
					case 31:	debug_action_string = "more cautious";	break;
					case 40:	debug_action_string = "expedient";		break;
					case 50:	debug_action_string = "back off";		break;
					case 51:	debug_action_string = "back off + new goal"; break;
					default:	debug_action_string = "unknown action";	break;
				}
				
				// display last action taken
				Print3d( helicopter.origin + ( 0, 0, -50 ), debug_action_string, action_debug_color, 1, 2.5, server_frames_to_persist );

			}
		}
		//
		//------------------------------------------------------------------------------------------------
		//
		//	end of visual debug section
		//
		//================================================================================================
		#/
	}
}

function ActivateRapsKillstreak( hardpointType )
{
	player = self;
	
	if ( !player killstreakrules::isKillstreakAllowed( RAPS_NAME, player.team ) )
	{
		return false;
	}
	
	if( game["raps_helicopter_positions"].size <= 0 )
	{
		/# IPrintLnBold( "RAPS helicopter position error, check NavMesh." ); #/
		self iPrintLnBold( &"KILLSTREAK_RAPS_NOT_AVAILABLE" );
		return false;
	}
	
	killstreakId = player killstreakrules::killstreakStart( RAPS_NAME, player.team );
	if( killstreakId == INVALID_KILLSTREAK_ID )
	{
		player iPrintLnBold( &"KILLSTREAK_RAPS_NOT_AVAILABLE" );
		return false;
	}

	player thread teams::WaitUntilTeamChange( player, &OnTeamChanged, player.entNum, "raps_complete" );

	level thread WatchRapsKillstreakEnd( killstreakId, player.entNum, player.team );
	
	helicopter = player SpawnRapsHelicopter( killstreakId );
	helicopter.killstreakId = killstreakId;
	
	player killstreaks::play_killstreak_start_dialog( RAPS_NAME, player.team, killstreakId );
	player AddWeaponStat( GetWeapon( RAPS_NAME ), "used", 1 );
		
	helicopter killstreaks::play_pilot_dialog_on_owner( "arrive", RAPS_NAME, killstreakId );
	
	level.raps[ player.entNum ].helicopter = helicopter;
	ARRAY_ADD( level.raps_helicopters, level.raps[ player.entNum ].helicopter );
	level thread UpdateKillstreakOnHelicopterDeath( level.raps[ player.entNum ].helicopter, player.entNum );
	
/#
	if ( RAPS_HELICOPTER_DEBUG_AUTO_REACTIVATE )
	{
		level thread AutoReactivateRapsKillstreak( player.entNum, player, hardpointType );
	}
#/
	
	return true;
}

/#
function AutoReactivateRapsKillstreak( ownerEntNum, player, hardpointType )
{
	while( true )
	{
		level waittill( "raps_updated_" + ownerEntNum );
		
		if( isdefined( level.raps[ ownerEntNum ].helicopter ) )
			continue;
		
		wait ( RandomFloatRange( 2.0, 5.0 ) );
		player thread ActivateRapsKillstreak( hardpointType );		
		
		return;
	}
}
#/
	
function WatchRapsKillstreakEnd( killstreakId, ownerEntNum, team )
{
	while( true )
	{
		level waittill( "raps_updated_" + ownerEntNum );
		
		if( isdefined( level.raps[ ownerEntNum ].helicopter ) )
		{
			continue;
		}
		
		killstreakrules::killstreakStop( RAPS_NAME, team, killstreakId );
		return;
	}
}

function UpdateKillstreakOnHelicopterDeath( helicopter, ownerEntEnum )
{
	helicopter waittill( "death" );
	
	level notify( "raps_updated_" + ownerEntEnum );
}

function OnTeamChanged( entNum, event )
{
	abandoned = true;
	DestroyAllRaps( entNum, abandoned );
}

function OnEMP( attacker, ownerEntNum )
{
	DestroyAllRaps( ownerEntNum );
}

function NoVehicleFaceThread( mapCenter, radius )
{
	level endon ("game_ended");
	wait 3; // wait arbitrary time so moving platform can be initialized
	MarkNoVehicleNavMeshFaces( mapCenter, radius, 21 );
}

/////////////////////////////////////////////////////////////////////////////////////////////////
//HELICOPTER
/////////////////////////////////////////////////////////////////////////////////////////////////
function InitHelicopterPositions()
{
		
	// - - - - -
	//
	// -- try to find a reasonable center point on the nav mesh as a starting point to start querying for more points
	//
	startSearchPoint = airsupport::GetMapCenter();
	mapCenter = GetClosestPointOnNavMesh( startSearchPoint, RAPS_HELICOPTER_NAV_MAP_CENTER_MAX_OFFSET );
	
	if ( !isdefined( mapCenter ) )
	{
		startSearchPoint = ( startSearchPoint[0], startSearchPoint[1], 0 );
	}

	remaining_attempts = 10;
	while ( !isdefined( mapCenter ) && remaining_attempts > 0 )
	{
		startSearchPoint += ( 100, 100, 0 );
		mapCenter = GetClosestPointOnNavMesh( startSearchPoint, RAPS_HELICOPTER_NAV_MAP_CENTER_MAX_OFFSET );
		remaining_attempts -= 1;		
	}
	
	if( !isdefined( mapCenter ) )
	{
		mapCenter = airsupport::GetMapCenter();
	}

	// - - - - -
	//
	// -- now query the nav mesh for some random, reasonably-spaced-out points
	//
	radius = airsupport::GetMaxMapWidth();
	if ( radius < 1 )
		radius = 1;

	// don't re-generate the points if they are already there
	if ( IsDefined( game["raps_helicopter_positions"] ) )
		return;
	
	lots_of_height = 1024;
	randomNavMeshPoints = util::PositionQuery_PointArray( mapCenter, RAPS_HELICOPTER_NAV_RADIUS_MIN, radius * 3, lots_of_height, RAPS_HELICOPTER_NAV_POINT_SPACING );
	// Hack fix for when the mapCenter cannot be found (mp_veiled / mp_sentosa)	
	if ( randomNavMeshPoints.size == 0 )
	{
		mapCenter = ( 0, 0, 39 );
		randomNavMeshPoints = util::PositionQuery_PointArray( mapCenter, RAPS_HELICOPTER_NAV_RADIUS_MIN, radius, 70, RAPS_HELICOPTER_NAV_POINT_SPACING );
	}
	
	/# position_query_drop_location_count = randomNavMeshPoints.size; #/

	// add level specific raps drop locations
	if ( isdefined( level.add_raps_drop_locations ) )
	{
		[[ level.add_raps_drop_locations ]]( randomNavMeshPoints );
	}

/#
	// debug draw level specific points
	if ( RAPS_HELICOPTER_NAV_POINT_TRACE_DEBUG )
	{
		boxHalfWidth = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.25; // draw a smaller box

		for( i = position_query_drop_location_count; i < randomNavMeshPoints.size; i++ )
		{
			// shows a short orange box 
			Box( randomNavMeshPoints[ i ], (-boxHalfWidth, -boxHalfWidth, 0), (boxHalfWidth, boxHalfWidth, 8.88 ), 0, ( 1.0, 0.53, 0.0 ), 0.9, false, 9999999 );
		}
	}
#/
		
	// get any level specific omit points
	omit_locations = [];
	if ( isdefined( level.add_raps_omit_locations ) )
	{
		[[ level.add_raps_omit_locations ]]( omit_locations ); // don't add too many of these.
	}
	
/#
	// debug draw level specific omit points
	if ( RAPS_HELICOPTER_NAV_POINT_TRACE_DEBUG )
	{
		debug_radius = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5; // draw a smaller box

		foreach( omit_location in omit_locations )
		{
			// shows a few dark grey circles 
			Circle( omit_location, debug_radius, ( 0.05, 0.05, 0.05 ), false, true, 9999999 );
			Circle( omit_location + ( 0, 0, 4 ), debug_radius, ( 0.05, 0.05, 0.05 ), false, true, 9999999 );
			Circle( omit_location + ( 0, 0, 8 ), debug_radius, ( 0.05, 0.05, 0.05 ), false, true, 9999999 );
		}
	}
#/	

	// - - - - -	
	//
	// -- collect the random points that can be used to drop raps (test points using box traces, etc.) 
	//
	game["raps_helicopter_positions"] = [];
	minFlyHeight = RAPS_HELICOPTER_FLY_HEIGHT;
	test_point_radius = 12;
	fit_radius = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5;
	fit_radius_corner = fit_radius * 0.7071;
	omit_radius = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5;
	
	foreach( point in randomNavMeshPoints )
	{
		// skip points in water
		start_water_trace = point + ( 0, 0, 6 );
		stop_water_trace = point + ( 0, 0, 8 );
		trace = physicstrace( start_water_trace, stop_water_trace, ( -2, -2, -2 ), ( 2, 2, 2 ) , undefined, PHYSICS_TRACE_MASK_WATER );
		if( trace["fraction"] < 1.0 )
		{
			/#
				if ( RAPS_HELICOPTER_NAV_POINT_TRACE_DEBUG )
				{
					DebugBoxWidth = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5;
					DebugBoxHeight = 10;
						
					// draw a blue box where water was found
					Box( start_water_trace, ( -DebugBoxWidth, -DebugBoxWidth, 0 ), ( DebugBoxWidth, DebugBoxWidth, DebugBoxHeight ), 0, ( 0.0, 0, 1.0 ), 0.9, false, 9999999 );
					Box( start_water_trace, ( -2, -2, -2 ), ( 2, 2, 2 ), 0, ( 0.0, 0, 1.0 ), 0.9, false, 9999999 );
				}
			#/
			continue;
		}
		
		// skip avoid points
		should_omit = false;

		foreach( omit_location in omit_locations )
		{
			if ( DistanceSquared( omit_location, point ) < ( omit_radius * omit_radius ) )
			{
				should_omit = true;
	
				/#
					if ( RAPS_HELICOPTER_NAV_POINT_TRACE_DEBUG )
					{
						DebugBoxWidth = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5;
						DebugBoxHeight = 10;
							
						// draw a dark grey box for omitted boxes
						Box( point, ( -DebugBoxWidth, -DebugBoxWidth, 0 ), ( DebugBoxWidth, DebugBoxWidth, DebugBoxHeight ), 0, ( 0.05, 0.05, 0.05 ), 1.0, false, 9999999 );
					}
				#/
				
				break;
			}
		}
		
		if (should_omit)
			continue;
		
		// for each random nav mesh point, test a few points near it to see if it works as a drop point
		randomTestPoints = util::PositionQuery_PointArray( point, 0, RAPS_HELICOPTER_NAV_SPACIOUS_POINT_BOUNDARY, lots_of_height, test_point_radius );
		max_attempts = 12;
		point_added = false;
		for ( i = 0; !point_added && i < max_attempts && i < randomTestPoints.size; i++ )
		{
			test_point =  randomTestPoints[ i ];
			
			//can_fit_on_nav_mesh = IsPointOnNavMesh( test_point, RAPS_HELICOPTER_NAV_SPACIOUS_POINT_BOUNDARY ); // this line should "work", but it doesn't, so we test some points individually
			can_fit_on_nav_mesh =  (	IsPointOnNavMesh( test_point + ( 0,  fit_radius, 0 ), 0 )
			                       	 && IsPointOnNavMesh( test_point + ( 0, -fit_radius, 0 ), 0 )
									 && IsPointOnNavMesh( test_point + (  fit_radius, 0, 0 ), 0 )
									 && IsPointOnNavMesh( test_point + ( -fit_radius, 0, 0 ), 0 )
									 && IsPointOnNavMesh( test_point + (  fit_radius_corner,  fit_radius_corner, 0 ), 0 ) // also include corners as there are cases where the above four are not sufficient for raps drones
			                       	 && IsPointOnNavMesh( test_point + (  fit_radius_corner, -fit_radius_corner, 0 ), 0 )
									 && IsPointOnNavMesh( test_point + ( -fit_radius_corner,  fit_radius_corner, 0 ), 0 )
									 && IsPointOnNavMesh( test_point + ( -fit_radius_corner, -fit_radius_corner, 0 ), 0 )
									);

			if ( can_fit_on_nav_mesh )
			{
				point_added = TryAddPointForHelicopterPosition( test_point, minFlyHeight );
			}
		}
	}

	if( game["raps_helicopter_positions"].size == 0 )
	{
		/# IPrintLnBold( "Error Finding Valid RAPS Helicopter Positions, Using Default Random NavMesh Points" ); #/
		game["raps_helicopter_positions"] = randomNavMeshPoints;
	}
	
	// find helicopter position closest to mapCenter to use as flood fill start point
	flood_fill_start_point = undefined;
	flood_fill_start_point_distance_squared = 9999999;
	foreach( point in game["raps_helicopter_positions"] )
	{
		if ( !isdefined( point ) )
			continue;
		
		distance_squared = DistanceSquared( point, mapCenter );
		if ( distance_squared < flood_fill_start_point_distance_squared )
		{
			flood_fill_start_point_distance_squared = distance_squared;
			flood_fill_start_point = point; 
		}
	}

	if ( !isdefined( flood_fill_start_point ) )
		flood_fill_start_point = mapCenter;

	level thread NoVehicleFaceThread( flood_fill_start_point, radius * 2 );
}

function TryAddPointForHelicopterPosition( spaciousPoint, minFlyHeight )
{
	traceHeight = minFlyHeight + RAPS_HELICOPTER_NAV_ADDITIONAL_TRACE_HEIGHT;
	traceBoxHalfWidth = RAPS_HELICOPTER_NAV_TRACE_BOX_WIDTH * 0.5;
	
	if ( IsTraceSafeForRapsDroneDropFromHelicopter( spaciousPoint, traceHeight, traceBoxHalfWidth ) )
	{
		ARRAY_ADD( game["raps_helicopter_positions"], spaciousPoint );
		return true;
	}
	
	return false;
}

function IsTraceSafeForRapsDroneDropFromHelicopter( spaciousPoint, traceHeight, traceBoxHalfWidth )
{
	start = ( spaciousPoint[0], spaciouspoint[1], traceHeight );
	end = ( spaciousPoint[0], spaciouspoint[1], spaciouspoint[2] + RAPS_HELICOPTER_NAV_END_POINT_TRACE_OFFSET );
	
	trace = PhysicsTrace( start, end, ( -traceBoxHalfWidth, -traceBoxHalfWidth, 0 ), ( traceBoxHalfWidth, traceBoxHalfWidth, traceBoxHalfWidth * 2.0 ), undefined, PHYSICS_TRACE_MASK_PHYSICS );


/#
	if ( RAPS_HELICOPTER_NAV_POINT_TRACE_DEBUG )
	{
		if (trace["fraction"] < 1.0 )
		{
			// shows the first trace hit, but from the end
			Box( end, (-traceBoxHalfWidth, -traceBoxHalfWidth, 0), (traceBoxHalfWidth, traceBoxHalfWidth, (start[2] - end[2]) * (1.0 - trace["fraction"])), 0, ( 1.0, 0, 0.0 ), 0.6, false, 9999999 );
		}
		else
		{
			// shows a small green box 
			Box( end, (-traceBoxHalfWidth, -traceBoxHalfWidth, 0), (traceBoxHalfWidth, traceBoxHalfWidth, 8.88), 0, ( 0.0, 1.0, 0.0 ), 0.6, false, 9999999 );
		}
	}
#/
		
	return ( trace["fraction"] == 1.0 && trace["surfacetype"] == "none" );
}

function GetRandomHelicopterStartOrigin( fly_height, firstDropLocation )
{
	best_node = helicopter::getValidRandomStartNode( firstDropLocation );
	return best_node.origin + ( 0, 0, fly_height );
}

function GetRandomHelicopterLeaveOrigin( fly_height, startLocationToLeaveFrom )
{
	best_node =  helicopter::getValidRandomLeaveNode( startLocationToLeaveFrom );
	return best_node.origin + ( 0, 0, fly_height );
}

function GetInitialHelicopterFlyHeight()
{
	// Note A: call this only once for each helicopter when spawned
	// Note B: this technique only works for two RAPS helicopters in play at any give time
	// Note C: this works regardless of team based or not

	ArrayRemoveValue( level.raps_helicopters, undefined ); // clean up array first

	minimum_fly_height = airsupport::getMinimumFlyHeight();
	
	if ( level.raps_helicopters.size > 0 )
	{
		already_assigned_height = level.raps_helicopters[0].assigned_fly_height;
		
		if ( already_assigned_height == ( minimum_fly_height + RAPS_HELICOPTER_FLY_HEIGHT ) )
			return minimum_fly_height + RAPS_HELICOPTER_FLY_HEIGHT + RAPS_HELICOPTER_Z_OFFSET_PER_HELI;
	}

	return minimum_fly_height + RAPS_HELICOPTER_FLY_HEIGHT;
}

function ConfigureChopperTeamPost( owner, isHacked )
{
	helicopter = self;
	helicopter thread WatchOwnerDisconnect( owner );
	helicopter thread CreateRapsHelicopterInfluencer();
}

function SpawnRapsHelicopter( killstreakId )
{
	player = self;

	assigned_fly_height = GetInitialHelicopterFlyHeight();
	prePickedDropLocation = PickNextDropLocation( undefined, 0, player.origin, assigned_fly_height );
	spawnOrigin = GetRandomHelicopterStartOrigin( /*fly_height*/ 0, prePickedDropLocation ); // update this
	
	helicopter = SpawnHelicopter( player, spawnOrigin, ( 0, 0, 0 ), RAPS_HELICOPTER_INFO, RAPS_HELICOPTER_MODEL );
	helicopter.prePickedDropLocation = prePickedDropLocation;
	helicopter.assigned_fly_height = assigned_fly_height;

	helicopter killstreaks::configure_team( RAPS_NAME, killstreakId, player, undefined, undefined, &ConfigureChopperTeamPost );
	helicopter killstreak_hacking::enable_hacking( RAPS_NAME );

	helicopter.droppingRaps = false;
	helicopter.isLeaving = false;
	helicopter.droppedRaps = false;
	helicopter.driveModeSpeedScale = 3.0;
	helicopter.driveModeAccel = RAPS_HELAV_EXPEDIENT_MODE_ACCEL * 5;
	helicopter.driveModeDecel = RAPS_HELAV_EXPEDIENT_MODE_DECEL * 5;
	helicopter.lastStopTime = 0;
	helicopter.targetDropLocation = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT;
	helicopter.lastDropLocation = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT;
	helicopter.firstDropReferencePoint = ( player.origin[0], player.origin[1], RAPS_HELICOPTER_FLY_HEIGHT);
	/#	helicopter.__last_dynamic_avoidance_action = 0;	#/
	
	helicopter clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );

	helicopter.health = 99999999;
	helicopter.maxhealth = killstreak_bundles::get_max_health( RAPS_NAME );
	helicopter.lowhealth = killstreak_bundles::get_low_health( RAPS_NAME );
	helicopter.extra_low_health = helicopter.lowhealth * 0.5; // hand craft for ship (no need to be tunable now per design, it's locked in)
	helicopter.extra_low_health_callback = &OnExtraLowHealth;

	helicopter SetCanDamage( true );
	helicopter thread killstreaks::MonitorDamage( RAPS_NAME, helicopter.maxhealth, &OnDeath, helicopter.lowhealth, &OnLowHealth, 0, undefined, true );

	helicopter.rocketDamage = helicopter.maxhealth / RAPS_HELICOPTER_MISSILES_TO_DESTROY + 1;
	helicopter.remoteMissileDamage = helicopter.maxhealth / RAPS_HELICOPTER_REMOTE_MISSILES_TO_DESTROY + 1;
	helicopter.hackerToolDamage = helicopter.maxhealth / RAPS_HELICOPTER_HACKS_TO_DESTROY + 1;
	helicopter.DetonateViaEMP = &raps::detonate_damage_monitored;	

	Target_Set( helicopter, ( 0, 0, 100 ) );
	helicopter SetDrawInfrared( true );
	helicopter thread WaitForHelicopterShutdown();
	helicopter thread HelicopterThink();
	helicopter thread WatchGameEnded();
/#	helicopter thread HelicopterThinkDebugVisitAll(); #/
		
	return helicopter;
}

function WaitForHelicopterShutdown()
{
	helicopter = self;
	helicopter waittill( "raps_helicopter_shutdown", killed );
	
	level notify( "raps_updated_" + helicopter.ownerEntNum );
	
	if ( Target_IsTarget( helicopter ) )
	{
		Target_Remove( helicopter );
	}
	
	if( killed )
	{
		wait( RandomFloatRange( 0.1, 0.2 ) );

		helicopter FirstHeliExplo();
		helicopter HeliDeathTrails();

		helicopter thread Spin();
		GoalX = RandomFloatRange( 650, 700 );
		GoalY = RandomFloatRange( 650, 700 );
		
		if ( RandomIntRange ( 0, 2 ) > 0 )
			GoalX = -GoalX;
	
		if ( RandomIntRange ( 0, 2 ) > 0 )
			GoalY = -GoalY;
		
		helicopter setVehGoalPos( helicopter.origin + ( GoalX, GoalY, -RandomFloatRange( 285, 300 ) ), false );
		wait( RandomFloatRange( 3.0, 4.0 ) );
		
		helicopter FinalHeliDeathExplode();

		// fx will not work if we delete too soon
		wait RAPS_HELI_POST_DEATH_FX_GHOST_DELAY; // ghost only after fx has covered up the drop ship
		helicopter ghost();
		self notify( "stop_death_spin" );
		wait 0.5;
	}
	else
	{
		helicopter HelicopterLeave();
	}
	
	helicopter delete();
}

function WatchOwnerDisconnect( owner )
{
	self notify( "WatchOwnerDisconnect_singleton" );
	self endon ( "WatchOwnerDisconnect_singleton" );
	
	helicopter = self;
	helicopter endon( "raps_helicopter_shutdown" );
	owner util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	helicopter notify( "raps_helicopter_shutdown", false );
}

function WatchGameEnded( )
{
	helicopter = self;
	helicopter endon( "raps_helicopter_shutdown" );
	helicopter endon( "death" );
	level waittill("game_ended");
	helicopter notify( "raps_helicopter_shutdown", false );
}

function OnDeath( attacker, weapon )
{
	helicopter = self;
	
	if ( isdefined( attacker ) && ( !isdefined( helicopter.owner ) || helicopter.owner util::IsEnemyPlayer( attacker ) ) )
	{
		challenges::destroyedAircraft( attacker, weapon, false );
		attacker challenges::addFlySwatterStat( weapon, self );
		scoreevents::processscoreevent( "destroyed_raps_deployship", attacker, helicopter.owner, weapon );
		if ( isdefined( helicopter.droppedRaps ) && helicopter.droppedRaps == false )
		{
			attacker addplayerstat( "destroy_raps_before_drop", 1 );
		}
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_RAPS_DEPLOY_SHIP", attacker.entnum );
		helicopter notify( "raps_helicopter_shutdown", true );
	}
	
	if ( helicopter.isleaving !== true )
	{
		helicopter killstreaks::play_pilot_dialog_on_owner( "destroyed", RAPS_NAME );
		helicopter killstreaks::play_destroyed_dialog_on_owner( RAPS_NAME, self.killstreakId );
	}
}

function OnLowHealth( attacker, weapon )
{
	helicopter = self;
	
	helicopter killstreaks::play_pilot_dialog_on_owner( "damaged", RAPS_NAME, helicopter.killstreakId );
	
	helicopter HeliLowHealthFx();
}

function OnExtraLowHealth( attacker, weapon )
{
	helicopter = self;
	helicopter HeliExtraLowHealthFx();	
}

function GetRandomHelicopterPosition( avoidPoint = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT, otherAvoidPoint = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT, avoidRadiusSqr = RAPS_HEDEPS_AVOID_RADIUS_SQR )
{
	flyHeight = RAPS_HELICOPTER_FLY_HEIGHT;
	found = false;
	tries = 0;

	// try picking a location outside the avoid circle, if not possible, reduce the circle size and try again
	for( i = 0; i <= RAPS_HEDEPS_REDUCE_RADIUS_RETRIES; i++ )	// intentionally using "<=" to get N+1 attemmpts
	{
		// for the very last attempt, make radius negative to make any point valid as a fail safe
		if ( i == RAPS_HEDEPS_REDUCE_RADIUS_RETRIES )
			avoidRadiusSqr = -1.0;
		
/#		if ( RAPS_HEDEPS_DEBUG > 0 )
		{
			server_frames_to_persist = INT( 3.0 / SERVER_FRAME );
			circle( avoidPoint, RAPS_HEDEPS_AVOID_RADIUS, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
			circle( avoidPoint, RAPS_HEDEPS_AVOID_RADIUS - 1, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
			circle( avoidPoint, RAPS_HEDEPS_AVOID_RADIUS - 2, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
			
			circle( otherAvoidPoint, RAPS_HEDEPS_AVOID_RADIUS, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
			circle( otherAvoidPoint, RAPS_HEDEPS_AVOID_RADIUS - 1, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
			circle( otherAvoidPoint, RAPS_HEDEPS_AVOID_RADIUS - 2, 	( 1, 0, 0 ), true, true, server_frames_to_persist );
		}
#/
			
		while( !found && tries < game["raps_helicopter_positions"].size )
		{
			index = RandomIntRange( 0, game["raps_helicopter_positions"].size );
			randomPoint = ( game["raps_helicopter_positions"][ index ][0], game["raps_helicopter_positions"][ index ][1], flyHeight );
			found = ( ( Distance2DSquared( randomPoint, avoidPoint ) > avoidRadiusSqr ) && ( Distance2DSquared( randomPoint, otherAvoidPoint ) > avoidRadiusSqr ) );
			tries++;
		}
		
		if (!found)
		{
			avoidRadiusSqr *= 0.25;
			tries = 0;
		}
	}

	// note: the -1 avoid radius should force the selection of a point
	Assert( found, "Failed to find a RAPS deploy point!" );
	
	return randomPoint;
}

function GetClosestRandomHelicopterPosition( refPoint, pickCount, avoidPoint = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT, otherAvoidPoint = RAPS_HEDEPS_UNSPECIFIED_AVOID_POINT )
{
	bestPosition = GetRandomHelicopterPosition( avoidPoint, otherAvoidPoint );
	bestDistanceSqr = Distance2DSquared( bestPosition, refPoint );
	
	for ( i = 1; i < pickCount; i++ )
	{
		candidatePosition = GetRandomHelicopterPosition( avoidPoint, otherAvoidPoint );
		candidateDistanceSqr = Distance2DSquared( candidatePosition, refPoint );
		
		if ( candidateDistanceSqr < bestDistanceSqr )
		{
			bestPosition = candidatePosition;
			bestDistanceSqr = candidateDistanceSqr;
		}
	}
	
	return bestPosition;
}

function WaitForStoppingMoveToExpire()
{
	elapsedTimeStopping = GetTime() - self.lastStopTime;
	if ( elapsedTimeStopping < RAPS_HELAV_STOP_WAIT_BEFORE_NEXT_DROP_POINT_MS )
	{
		wait ( (RAPS_HELAV_STOP_WAIT_BEFORE_NEXT_DROP_POINT_MS - elapsedTimeStopping) * 0.001 );
	}
}

function GetOtherHelicopterPointToAvoid() //self == raps helicopter
{
	avoid_point = undefined;
	
	ArrayRemoveValue( level.raps_helicopters, undefined ); // clean up array first
	
	foreach( heli in level.raps_helicopters )
	{
		if ( heli != self )
		{
			avoid_point = heli.targetDropLocation;
			break;
		}
	}
	
	return avoid_point;
}

function PickNextDropLocation( heli, drop_index, firstDropReferencePoint, assigned_fly_height, lastDropLocation )
{
	avoid_point = self GetOtherHelicopterPointToAvoid();
	
	// if we have a pre-picked drop location, use that first and reset it
	if ( isdefined( heli ) && isdefined( heli.prePickedDropLocation ) )
	{
		targetDropLocation = heli.prePickedDropLocation;
		heli.prePickedDropLocation = undefined;
		return targetDropLocation;
	}
	
	targetDropLocation = ( ( drop_index == 0 ) ? GetClosestRandomHelicopterPosition(
													firstDropReferencePoint,
													INT(game["raps_helicopter_positions"].size * (RAPS_HEDEPS_FIRST_POINT_PERCENT_OF_TOTAL / 100.0) + 1),
													avoid_point )
										   : GetRandomHelicopterPosition( lastDropLocation, avoid_point ) );
	
	targetDropLocation = ( targetDropLocation[0], targetDropLocation[1], assigned_fly_height );
	
	return targetDropLocation;
}

function HelicopterThink()
{
/#
	if ( RAPS_HELICOPTER_NAV_DEBUG_VISIT_ALL )
	return;
#/

	self endon( "raps_helicopter_shutdown" );

	for( i = 0; i < RAPS_HELICOPTER_DROP_LOCATION_COUNT; i++ )
	{
		self.targetDropLocation = PickNextDropLocation( self, i, self.firstDropReferencePoint, self.assigned_fly_height, self.lastDropLocation );
		
		while ( Distance2DSquared( self.origin, self.targetDropLocation ) > RAPS_HELICOPTER_DROP_LOCATION_TOLERANCE_SQR )
		{
			self WaitForStoppingMoveToExpire();
			self UpdateHelicopterSpeed();
			self setVehGoalPos( self.targetDropLocation, 1 );
			self waittill( "goal" );
		}
		
		if ( isdefined( self.owner ) )
		{
			if ( ( i + 1 ) < RAPS_HELICOPTER_DROP_LOCATION_COUNT )
			{
				self killstreaks::play_pilot_dialog_on_owner( "waveStart", RAPS_NAME, self.killstreakId );
			}
			else
			{
				self killstreaks::play_pilot_dialog_on_owner( "waveStartFinal", RAPS_NAME, self.killstreakId );
			}
		}
		
		enemy = self.owner battlechatter::get_closest_player_enemy( self.origin, true );
		enemyRadius = battlechatter::mpdialog_value( "rapsDropRadius", 0 );
		
		if ( isdefined( enemy ) && Distance2DSquared( self.origin, enemy.origin ) < enemyRadius * enemyRadius )
		{
			enemy battlechatter::play_killstreak_threat( RAPS_NAME );
		}
		
		self DropRaps();
		
		wait( ( i + 1 >= RAPS_HELICOPTER_DROP_LOCATION_COUNT )
		     		? RAPS_HELICOPTER_DROP_DURATION_LAST + RandomFloatRange( -RAPS_HELICOPTER_DROP_DURATION_LAST_DELTA, RAPS_HELICOPTER_DROP_DURATION_LAST_DELTA )
		     		: RAPS_HELICOPTER_DROP_DURATION		 + RandomFloatRange( -RAPS_HELICOPTER_DROP_DURATION_DELTA	  , RAPS_HELICOPTER_DROP_DURATION_DELTA		 ) );
	}

	self notify( "raps_helicopter_shutdown", false );
}

/#
function HelicopterThinkDebugVisitAll()
{
	self endon( "death" );

	if ( RAPS_HELICOPTER_NAV_DEBUG_VISIT_ALL == 0 )
		return;

	for( i = 0; i < 100; i++ )
	{
		for( j = 0; j < game["raps_helicopter_positions"].size; j++ )
		{
			self.targetDropLocation = ( game["raps_helicopter_positions"][ j ][0], game["raps_helicopter_positions"][ j ][1],  self.assigned_fly_height );
			
			while ( Distance2DSquared( self.origin, self.targetDropLocation ) > RAPS_HELICOPTER_DROP_LOCATION_TOLERANCE_SQR )
			{
				self WaitForStoppingMoveToExpire();
				self UpdateHelicopterSpeed();
				self setVehGoalPos( self.targetDropLocation, 1 );
				self waittill( "goal" );
			}
			
			self DropRaps();
			
			wait( 1.0 );
			
			if ( RAPS_HELICOPTER_NAV_DEBUG_VISIT_ALL_FAKE_LEAVE > 0 )
			{
				if ( (j+1) % 3 == 0 )
				{
					
					// fake a leave and then return
					self.targetDropLocation = GetRandomHelicopterStartOrigin( self.assigned_fly_height, self.origin ); //TODO: make this debug function work at some point, not now, too close to ship
					while ( Distance2DSquared( self.origin, self.targetDropLocation ) > RAPS_HELICOPTER_DROP_LOCATION_TOLERANCE_SQR )
					{
						self WaitForStoppingMoveToExpire();
						self UpdateHelicopterSpeed();
						self setVehGoalPos( self.targetDropLocation, 1 );
						self waittill( "goal" );
					}					
				}
			}
		}
	}
		
	self notify( "raps_helicopter_shutdown", false );
}
#/

function DropRaps()
{
	level endon( "game_ended" );
	self endon( "death" );

	self.droppingRaps = true;
	self.lastDropLocation = self.origin;

	// reposition raps to a more precise drap location
	preciseDropLocation = 0.5 * ( self GetTagOrigin( level.raps_helicopter_drop_tag_names[0] ) + self GetTagOrigin( level.raps_helicopter_drop_tag_names[1] ) );
	preciseGoalLocation = self.targetDropLocation + (self.targetDropLocation - preciseDropLocation);
	preciseGoalLocation = ( preciseGoalLocation[0], preciseGoalLocation[1], self.targetDropLocation[2] );
	self setVehGoalPos( preciseGoalLocation, 1 );
	self waittill( "goal" );	
	self.droppedRaps = true;
	for( i = 0; i < level.raps_settings.spawn_count; i++ )
	{
		spawn_tag = level.raps_helicopter_drop_tag_names[ i % level.raps_helicopter_drop_tag_names.size ];
		
		origin = self GetTagOrigin( spawn_tag );
		angles = self GetTagAngles( spawn_tag );
		
		if ( !isdefined( origin ) || !isdefined( angles ) )
		{
			origin = self.origin;
			angles = self.angles;			
		}
		
		self.owner thread SpawnRaps( origin, angles );
		self playsound( "veh_raps_launch" );
		wait( RAPS_HELICOPTER_DROP_INTERVAL );
	}
	
	self.droppingRaps = false;
}

function Spin()
{
	self endon( "stop_death_spin" );
	
	speed = RandomIntRange( 180, 220 );
	self setyawspeed( speed, speed * 0.25, speed );	
	
	if ( RandomIntRange ( 0, 2 ) > 0 )
		speed = -speed;

	while ( isdefined( self ) )
	{
		self settargetyaw( self.angles[1]+(speed*0.4) );
		wait ( 1 );
	}
}

function FirstHeliExplo()
{
	PlayFxOnTag( RAPS_HELI_FIRST_EXPLO_FX, self, RAPS_HELI_FIRST_EXPLO_FX_TAG );
	self PlaySound( level.heli_sound["crash"] );
}

function HeliLowHealthFx()
{
	self clientfield::set( "raps_heli_low_health", 1 );
}

function HeliExtraLowHealthFx()
{
	self clientfield::set( "raps_heli_extra_low_health", 1 );
}

function HeliDeathTrails()
{
	PlayFxOnTag( RAPS_HELI_DEATH_TRAIL_FX, self, RAPS_HELI_DEATH_TRAIL_FX_TAG_A );
}

function FinalHeliDeathExplode()
{
	PlayFxOnTag( RAPS_HELI_DEATH_FX, self, RAPS_HELI_DEATH_FX_TAG );
	self PlaySound( level.heli_sound["crash"] );
}

function HelicopterLeave()
{
	self.isLeaving = true;

	self killstreaks::play_pilot_dialog_on_owner( "timeout", RAPS_NAME );
	self killstreaks::play_taacom_dialog_response_on_owner( "timeoutConfirmed", RAPS_NAME );

	self.leaveLocation = GetRandomHelicopterLeaveOrigin( /* self.assigned_fly_height */ 0, self.origin );
	while ( Distance2DSquared( self.origin, self.leaveLocation ) > RAPS_HELICOPTER_LEAVE_LOCATION_REACHED_SQR )
	{
		self UpdateHelicopterSpeed();
		self setVehGoalPos( self.leaveLocation, 0 );
		self waittill( "goal" );
	}
}
	
function UpdateHelicopterSpeed( driveMode )
{	
	if ( isdefined( driveMode ) )
	{
		switch ( driveMode )
		{
			case RAPS_HELAV_DRIVE_MODE_EXPEDIENT:
				self.driveModeSpeedScale = 1.0;
				self.driveModeAccel = RAPS_HELAV_EXPEDIENT_MODE_ACCEL;
				self.driveModeDecel = RAPS_HELAV_EXPEDIENT_MODE_DECEL;
				break;
			
			case RAPS_HELAV_DRIVE_MODE_CAUTIOUS:
			case RAPS_HELAV_DRIVE_MODE_MORE_CAUTIOUS:
				self.driveModeSpeedScale = ((driveMode == RAPS_HELAV_DRIVE_MODE_MORE_CAUTIOUS) ? RAPS_HELAV_SLOW_DOWN_MORE_SCALE_FACTOR : RAPS_HELAV_SLOW_DOWN_SPEED_SCALE_FACTOR);
				self.driveModeAccel = RAPS_HELAV_CAUTIOUS_MODE_ACCEL;
				self.driveModeDecel = RAPS_HELAV_CAUTIOUS_MODE_DECEL;
				break;
		}
	}

	desiredSpeed = (self GetMaxSpeed() / MPH_TO_INCHES_PER_SEC) * self.driveModeSpeedScale;
	
	// use Decel as Accel when the desired speed is less than the current speed; (it's a side effect of the system)
	if ( desiredspeed < self GetSpeedMPH() )
	{
		self SetSpeed( desiredSpeed, self.driveModeDecel, self.driveModeDecel );
	}
	else
	{
		self SetSpeed( desiredSpeed, self.driveModeAccel, self.driveModeDecel );		
	}
}

function StopHelicopter()
{
	//self SetSpeed( 0, RAPS_HELAV_FULL_STOP_MODE_ACCEL, RAPS_HELAV_FULL_STOP_MODE_DECEL );
	self SetSpeed( 0, RAPS_HELAV_FULL_STOP_MODE_DECEL, RAPS_HELAV_FULL_STOP_MODE_DECEL ); // using DECEL as accel due to way the current system works
	self.lastStopTime = GetTime();
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// RAPS
/////////////////////////////////////////////////////////////////////////////////////////////////
function SpawnRaps( origin, angles )
{
	originalOwner = self;
	originalOwnerEntNum = originalOwner.entNum;
	
	raps = SpawnVehicle( RAPS_VEHICLE, origin, angles, "dynamic_spawn_ai" );

	if ( !isdefined( raps ) )
		return;

	raps.forceOneMissile = true;
	raps.drop_deploying = true;
	raps.hurt_trigger_immune_end_time = GetTime() + VAL( level.raps_hurt_trigger_immune_duration_ms, RAPS_HURT_TRIGGER_IMMUNE_DURATION_MS );
	
	ARRAY_ADD( level.raps[ originalOwnerEntNum ].raps, raps );

	raps killstreaks::configure_team( RAPS_NAME, RAPS_NAME, originalOwner, undefined, undefined, &ConfigureTeamPost );
	raps killstreak_hacking::enable_hacking( RAPS_NAME );
	raps clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	raps.soundmod = "raps";
	raps.ignore_vehicle_underneath_splash_scalar = true;
	raps.detonate_sides_disabled = true;
	raps.treat_owner_damage_as_friendly_fire = true;
	raps.ignore_team_kills = true;

	raps SetInvisibleToAll();
	raps thread AutoSetVisibleToAll();

	raps vehicle::toggle_sounds( 0 );
	//raps thread sndAndRumbleWaitUntilLanding( originalOwner ); // now in client script as monitor_drop_landing

	raps thread WatchRapsKills( originalOwner );
	raps thread WatchRapsDeath( originalOwner );
	raps thread killstreaks::WaitForTimeout( RAPS_NAME, raps.settings.max_duration * 1000, &OnRapsTimeout, "death" );
}


function ConfigureTeamPost( owner, isHacked )
{
	raps = self;
	raps thread CreateRapsInfluencer();	
	raps thread InitEnemySelection( owner );
	raps thread WatchRapsTippedOver( owner );
}



function AutoSetVisibleToAll()
{
	self endon( "death" );

	// intent: hide the visual glitches when first spawning raps mid air
	
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	
	self SetVisibleToAll();
}

function OnRapsTimeout()
{
	self SelfDestruct( self.owner );
}

function SelfDestruct( attacker ) // self == raps
{
	self.selfDestruct = true;
	self raps::detonate( attacker );
}

function WatchRapsKills( originalOwner )
{
	originalOwner endon( "raps_complete" );
	self endon( "death" );
	
	if( self.settings.max_kill_count == 0 )
	{
		return;
	}
	
	while( true )
	{
		self waittill( "killed", victim );
	
		if( isdefined( victim ) && IsPlayer( victim ) )
		{
			if( !isdefined( self.killCount ) )
			{
				self.killCount = 0;	
			}
			
			self.killCount++;
			if( self.killCount >= self.settings.max_kill_count )
			{
				self raps::detonate( self.owner );
			}
		}
	}
}

function WatchRapsTippedOver( owner )
{
	owner endon( "disconnect" );
	self endon( "death" );

	// if the raps manage to tip over and get stuck, it should detonate
	while( true )
	{
		wait 3.5;
		
		if ( Abs( self.angles[2] ) > 75 )
		{
			self raps::detonate( owner );			
		}
	}
}

function WatchRapsDeath( originalOwner )
{
	originalOwnerEntNum = originalOwner.entnum;
	self waittill( "death", attacker, damageFromUnderneath, weapon );
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );

	if( isdefined( attacker ) && isPlayer( attacker ) )
	{
		if( isdefined( self.owner ) && self.owner != attacker && ( self.owner.team != attacker.team ) )
		{
			scoreevents::processScoreEvent( "killed_raps", attacker );
			attacker challenges::destroyScoreStreak( weapon, true );
			attacker challenges::destroyNonAirScoreStreak_PostStatsLock( weapon );
							
			if( isdefined( self.attackers ) )
			{
				foreach( player in self.attackers )
				{
					if( isPlayer( player ) && ( player != attacker ) && ( player != self.owner ) )
					{
						scoreevents::processScoreEvent( "killed_raps_assist", player );
					}
				}
			}
		}
	}
	
	ArrayRemoveValue( level.raps[ originalOwnerEntNum ].raps, self );
}

function InitEnemySelection( owner ) //self == raps
{
	owner endon( "disconnect" );
	self endon( "death" );
	self endon( "hacked" );

	self vehicle_ai::set_state( "off" );
	util::wait_network_frame(); // wait needed to get drop deploy mode to work
	util::wait_network_frame(); // need two to make sure fast forward works
	self SetVehicleForDropDeploy();
	self clientfield::set( "monitor_raps_drop_landing", 1 );
	wait( RAPS_SLEEP_DURATION );
	if ( self InitialWaitUntilSettled() )
	{
		self ResetVehicleFromDropDeploy();
		self SetGoal( self.origin );
		self vehicle_ai::set_state( "combat" );
		self vehicle::toggle_sounds( 1 );

		self.drop_deploying = undefined;
		self.hurt_trigger_immune_end_time = undefined;
		Target_Set( self );
		
		// try not to target the same enemy
		for( i = 0; i < level.raps[ owner.entNum ].raps.size; i++ )
		{
			raps = level.raps[ owner.entNum ].raps[ i ];
			if( isdefined( raps ) && isdefined( raps.enemy ) && isdefined( self ) && isdefined( self.enemy ) && ( raps != self ) && ( raps.enemy == self.enemy ) )
			{
				self SetPersonalThreatBias( self.enemy, -2000, 5.0 );
			}
		}
	}
	else
	{
		// could not settle, then self destruct
		self SelfDestruct( self.owner );
	}
}

#define RAPS_IWUS_WAIT_INTERVAL 			( 0.2 )
#define RAPS_IWUS_Z_SPEED_THRESHOLD			( 0.1 )
#define RAPS_IWUS_Z_SETTLE_TIMEOUT			( 5.0 )
#define RAPS_IWUS_SETTLE_ON_MESH_TIMEOUT	( RAPS_IWUS_Z_SETTLE_TIMEOUT + 5.0 )
#define RAPS_IWUS_FORCE_TIMEOUT_TEST		( false )
#define RAPS_IWUS_RAPS_RADIUS				( 36 )

function InitialWaitUntilSettled()
{
	// settle z speed first	
	waitTime = 0;
	while ( Abs( self.velocity[2] ) > RAPS_IWUS_Z_SPEED_THRESHOLD && waitTime < RAPS_IWUS_Z_SETTLE_TIMEOUT )
	{
		wait RAPS_IWUS_WAIT_INTERVAL;
		waitTime += RAPS_IWUS_WAIT_INTERVAL;
	}

	// wait until settled on nav mesh
	while( ( !IsPointOnNavMesh( self.origin, RAPS_IWUS_RAPS_RADIUS ) || ( Abs( self.velocity[2] ) > RAPS_IWUS_Z_SPEED_THRESHOLD ) ) && waitTime < RAPS_IWUS_SETTLE_ON_MESH_TIMEOUT )
	{
		wait RAPS_IWUS_WAIT_INTERVAL;
		waitTime += RAPS_IWUS_WAIT_INTERVAL;
	}

/#
	if ( RAPS_IWUS_FORCE_TIMEOUT_TEST )
		waitTime += RAPS_IWUS_SETTLE_ON_MESH_TIMEOUT;
#/
	
	// return true if raps settled without timing out
	return ( waitTime < RAPS_IWUS_SETTLE_ON_MESH_TIMEOUT );
}


function DestroyAllRaps( entNum, abandoned = false )
{
	foreach( raps in level.raps[ entNum ].raps )
	{
		if( IsAlive( raps ) )
		{
			raps.owner = undefined;
			raps.abandoned = abandoned; // note: abandoned vehicles do not cause damage radius damage
			raps raps::detonate( raps );	
		}
	}
}

//Override for scripts/shared/vehicles/_raps.gsc:force_get_enemies()
function ForceGetEnemies()
{
	foreach( player in level.players )
	{
		if( isdefined( self.owner ) && self.owner util::IsEnemyPlayer( player ) && ( !player smokegrenade::IsInSmokeGrenade() )  && !player hasPerk( "specialty_nottargetedbyraps" ) )
		{
			self GetPerfectInfo( player );
			return;
		}
	}
}

function CreateRapsHelicopterInfluencer()
{
	level endon( "game_ended" );
		
	helicopter = self;
	
	if ( isdefined( helicopter.influencerEnt ) )
	{
		helicopter.influencerEnt Delete();
	}
	
	influencerEnt = spawn( "script_model", helicopter.origin - ( 0, 0, self.assigned_fly_height ) );
	helicopter.influencerEnt = influencerEnt;
	helicopter.influencerEnt.angles = ( 0, 0, 0 );
	helicopter.influencerEnt LinkTo( helicopter );
	
	preset = GetInfluencerPreset( "helicopter" );
	if( !IsDefined( preset ) )
	{
		return;
	}
		
	enemy_team_mask = helicopter spawning::get_enemy_team_mask( helicopter.team );
	helicopter.influencerEnt spawning::create_entity_influencer( "helicopter", enemy_team_mask );
	
	helicopter waittill( "death" );
	if ( isdefined( influencerEnt ) )
	{
		influencerEnt delete();	
	}
}

function CreateRapsInfluencer()
{
	raps = self;
	
	preset = GetInfluencerPreset( RAPS_NAME );
	if( !IsDefined( preset ) )
	{
		return;
	}
		
	enemy_team_mask = raps spawning::get_enemy_team_mask( raps.team );
	raps spawning::create_entity_influencer( RAPS_NAME, enemy_team_mask );
}
