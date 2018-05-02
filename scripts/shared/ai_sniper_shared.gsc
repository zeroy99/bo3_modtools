#using scripts\shared\util_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\codescripts\struct;
#using scripts\shared\ai\systems\blackboard;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;

#namespace ai_sniper;

REGISTER_SYSTEM( "ai_sniper", &ai_sniper::__init__, undefined )

function __init__()
{	
	thread init_node_scan();
}

/@
"Name: init_node_scan( [targetName] )"
"Summary: Initializes path nodes that should serve as a sniping action stopping point."
"Module: AI"
"CallOn: an actor"
"Example: ai_sniper::init_node_scan();"
"OptionalArg: [targetName] : targetname of script origins or structs to check (default "ai_sniper_node_scan")
"SPMP: singleplayer"
@/
function init_node_scan( targetName )
{
	WAIT_SERVER_FRAME;
	
	if ( !isDefined( targetName ) )
		targetName = "ai_sniper_node_scan";

	/* 
	   Snipers reach a node and the node connects to a lasing path
	   If the node targets another node, they will stop the behavior and move on when they finish one loop

      Simple point arrays - refer back to node
        [struct]
        targetname: ai_sniper_nodescan
        target: <targetname> of node they are part of

      Complex point paths - node refers to entry point
        [node] (sniping destination node)
        script_noteworthy: ai_sniper_nodescan
        script_linkto: <script_linkname> of a given node of a path
    
	 */
	
	// Lase points that refer directly back to node in a "dumb" array
	structList = struct::get_array( targetName, "targetname" );
	pointList =  GetEntArray( targetName, "targetname" );
	foreach ( struct in structList ) 
		pointList[pointlist.size] = struct;
	
	foreach ( point in pointList )
	{
		if ( isDefined( point.target ) )
		{
			node = getnode( point.target, "targetname" );
			if ( isDefined( node ) )
			{
				if ( !isDefined( node.lase_points ) )
					node.lase_points = [];
				node.lase_points[node.lase_points.size] = point;
			}
		}
	}

	// Nodes that refer to an entry point in a lasing path
	nodeList =  GetNodeArray( targetName, "script_noteworthy" );	
	foreach ( node in nodeList )
	{
		if ( isDefined( node.script_linkto ) )
		{
			node.lase_path = struct::get( node.script_linkto, "script_linkname" );
			if ( !isDefined( node.lase_path ) )
				node.lase_path = GetEnt( node.script_linkto, "script_linkname" );
		}
	}
}


/@
"Name: agent_init( )"
"Summary: Initializes an actor on spawn for support of ai_sniper behavior automatically based on node arrival."
"Module: AI"
"CallOn: an actor"
"SPMP: singleplayer"
@/
function agent_init( )
{
	self thread ai_sniper::patrol_lase_goal_waiter();
	self thread ai_sniper::goal_watcher_patrol();
	self thread ai_sniper::goal_watcher_target();
}

function goal_wait_notify_lase( node )
{
	if ( !isDefined( node )  )
		return;

	if ( !isDefined( node.lase_points ) && !isDefined( node.lase_path ) )
		return;

	self notify("goal_wait_notify_lase");
	self endon("goal_wait_notify_lase");
	self endon("death");
	self endon("lase_points");

	if ( IS_TRUE( self.patroller ) )
		self ai::end_and_clean_patrol_behaviors();

	// Wait till the guy arrives right on the goal
	goalPos = node.origin;
	if ( isDefined( self.pathGoalPos ) )
		goalPos = self.pathGoalPos;
	if( IsDefined( self.arrivalFinalPos ) )
		goalPos = self.arrivalFinalPos;
	while ( DistanceSquared( self.origin, goalPos ) > (16 * 16) )
		WAIT_SERVER_FRAME;
		
	self notify( "lase_goal", node );
}

function goal_watcher_patrol()
{
	self notify("goal_watcher_patrol");
	self endon("goal_watcher_patrol");
	self endon("death");
	
	while ( 1 )
	{
		self waittill ("patrol_goal", node );
		
		self goal_wait_notify_lase( node );
	}
}

function goal_watcher_target()
{
	self notify("goal_watcher_target");
	self endon("goal_watcher_target");
	self endon("death");

	if ( isDefined( self.target ) && !IS_TRUE( self.patroller ) )
	{
		node = GetNode( self.target, "targetname" );
		
		if ( isDefined( node ) )
		{
			self waittill( "goal" );
			
			self goal_wait_notify_lase( node );
		}		
	}
}

function patrol_lase_goal_waiter()
{
	self notify("patrol_lase_goal_waiter");
	self endon("patrol_lase_goal_waiter");
	self endon("death");
	
	while ( 1 )
	{
		was_stealth = false;
		
		self waittill ("lase_goal", node );
		
		if ( isDefined( node.lase_path ) )
			self thread actor_lase_points_behavior( node.lase_path );
		else
			self thread actor_lase_points_behavior( node.lase_points );

		// Turn off stealth 
		if ( self ai::has_behavior_attribute( "stealth" ) )
		{
			was_stealth = self ai::get_behavior_attribute( "stealth" );
			self ai::set_behavior_attribute( "stealth", false );
		}
		
		if ( isDefined( self.currentgoal ) && isDefined( self.currentgoal.target ) && self.currentgoal.target != "" )
		{
			// Stop here 
			self SetGoal( node, true );
			self waittill( "lase_points_loop" );
			
			// Then continue patrolling after we finished the lasing loop
			self notify("lase_points");
			self LaserOff();			
			self.holdfire = false;
			self ai::stop_shoot_at_target();
			
			if ( isDefined( self.ai_sniper_prev_goal_radius ) )
			{
				self.goalradius = self.ai_sniper_prev_goal_radius;
				self.ai_sniper_prev_goal_radius = undefined;
			}
	
			if ( isDefined( self.currentgoal ) )
				self thread ai::patrol( self.currentgoal );

			if ( was_stealth && self ai::has_behavior_attribute( "stealth" ) )
				self ai::set_behavior_attribute( "stealth", self.awarenesslevelcurrent != "combat" );
		}
		else
		{
			// Lase forever
			break;
		}
	}
}

/@
"Name: actor_lase_points_behavior( <entity_or_point_array> )"
"Summary: Puts an actor into a state where they target an invisible entity that travels from point to point in a loop."
"Module: AI"
"CallOn: an actor"
"Example: guy thread actor_lase_points_behavior( sniper_target_points );"
"OptionalArg: <entity_or_point_array> : series of vector points or entities to lase - when not defined it will check self.targetname to find first struct - supports following a path"
"SPMP: singleplayer"
@/
function actor_lase_points_behavior( entity_or_point_array )
{
	self notify("lase_points");
	self endon("lase_points");
	self endon("death");
	
	// dont actually pull the trigger
	self.holdfire = true;		
	
	// aim at target even when visually obstructed
	self.blindaim = true;

	// dont relocate just stay put
	if ( !isDefined( self.ai_sniper_prev_goal_radius ) )
		self.ai_sniper_prev_goal_radius = self.goalradius;
	self.goalradius = 8;
	
	// Stand as still as possible
	if ( IsDefined( self.__blackboard ) && isDefined( self.script_parameters ) && self.script_parameters == "steady" )
		Blackboard::SetBlackBoardAttribute( self, CONTEXT, "steady" );
		
	if ( !isDefined( entity_or_point_array ) && isDefined( self.target ) )
		entity_or_point_array = struct::get( self.target, "targetname" );

	if ( !isDefined( entity_or_point_array ) || ( isArray( entity_or_point_array ) && entity_or_point_array.size == 0 ) )
	{
		/# IPrintLnBold( "actor_lase_points_behavior - invalid entity_or_point_array" ); #/
		return;
	}

	firstPoint = undefined;
	if ( isArray( entity_or_point_array ) )
		firstPoint = entity_or_point_array[0];
	else
		firstPoint = entity_or_point_array;
			
	if ( !isDefined( self.lase_ent ) )
	{
		self.lase_ent = Spawn( "script_model", lase_point( firstPoint ) );
		self.lase_ent SetModel("tag_origin");
		self.lase_ent.velocity = (100, 0, 0);
		self thread util::delete_on_death( self.lase_ent );
	}
	
	// so shoot_at_target doesnt think its dead and stop
	if ( self.lase_ent.health <= 0 )
		self.lase_ent.health = 1; 	
	self thread ai::shoot_at_target( "shoot_until_target_dead", self.lase_ent );

	self.lase_ent thread target_lase_points( entity_or_point_array, self );
	self.lase_ent thread target_lase_points_ally_track( self GetEye(), entity_or_point_array, self );
	
	self thread actor_lase_force_laser_on();
	self thread actor_lase_laser_off_on_death();
}

/@
"Name: actor_lase_stop( )"
"Summary: Removes an actor from state where they target an invisible entity that travels from point to point in a loop."
"Module: AI"
"CallOn: an actor"
"Example: guy actor_lase_stop();"
"SPMP: singleplayer"
@/
function actor_lase_stop()
{
	if ( !isDefined( self.lase_ent ) )
		return;
	
	self notify("lase_points");
		
	self.holdfire = false;
	
	self.blindaim = false;
	
	self.lase_ent delete();
	self.lase_ent = undefined;

	self clearentitytarget();
	
	if ( isDefined( self.ai_sniper_prev_goal_radius ) )
	{
		self.goalradius = self.ai_sniper_prev_goal_radius;
		self.ai_sniper_prev_goal_radius = undefined;
	}	

	self LaserOff();

	if ( IsDefined( self.__blackboard ) )
		Blackboard::SetBlackBoardAttribute( self, CONTEXT, undefined );
}

function actor_lase_force_laser_on()
{
	self endon("death");
	self endon("lase_points");
	
	lastTransition = GetTime();
	
	while ( 1 )
	{
		// Turn on laser all the time as long as actor is not currently turning to face new general direction
		if ( self asmIsTransDecRunning() )
		{
			// Playing turning animation etc
			lastTransition = GetTime();
			self LaserOff();
		}
		else if ( GetTime() - lastTransition > 350 )
		{
			self LaserOn();
		}
		
		WAIT_SERVER_FRAME;
	}
}

function actor_lase_laser_off_on_death()
{
	self endon("lase_points");
	
	self waittill("death");
	
	if ( isDefined( self ) )
		self LaserOff();
}

function lase_point( entity_or_point )
{
	if ( !isDefined( entity_or_point ) )
		return (0, 0, 0);
	
	result = entity_or_point;
	
	if ( !isVec( entity_or_point ) && isDefined( entity_or_point.origin ) )
	{
		result = entity_or_point.origin;
		
		if ( isPlayer( entity_or_point ) || isActor( entity_or_point ) )
			result = entity_or_point GetEye();
	}
	
	return result;
}

/@
"Name: target_lase_points_ally_track( v_eye, entity_or_point_array, [a_owner] )"
"Summary: Interrupts normal point lasing behavior to track a particular ally (ai or player) when they come near and are in view."
"Module: AI"
"CallOn: an entity"
"Example: guy.targetEnt thread actor_lase_points_player_track();"
"SPMP: singleplayer"
@/
function target_lase_points_ally_track( v_eye, entity_or_point_array, a_owner )
{
	self notify("actor_lase_points_player_track");
	self endon("actor_lase_points_player_track");
	
	self endon("death");
	          
	if ( !isDefined( level.target_lase_allyList ) )
		level.target_lase_allyList = [];
	if ( !isDefined( level.target_lase_nextAllyListUpdate ) )
		level.target_lase_nextAllyListUpdate = 0;
	
	while ( 1 ) 
	{
		dirLaser = VectorNormalize( self.origin - v_eye );

		if ( GetTime() > level.target_lase_nextAllyListUpdate )	
		{
			level.target_lase_allyList = GetPlayers();
	
			actorList = GetAITeamArray( "allies" );		
			foreach ( actor in actorList ) 
			{
				if ( IS_TRUE( actor.ignoreme ) )
					continue;
				
				if ( isAlive( actor ) )
					level.target_lase_allyList[level.target_lase_allyList.size] = actor;
			}
			
			level.target_lase_nextAllyListUpdate = GetTime() + 1000;
		}

		for ( i = 0; i < level.target_lase_allyList.size; i++ )
		{
			ally = level.target_lase_allyList[i];
			
			if ( !isAlive( ally ) )
				continue;
			
			if ( ally IsNoTarget() || IS_TRUE( ally.ignoreme ) )
				continue;
			
			allyEye = lase_point( ally );
			
			// Make sure ally is in reasonable view
			dirAlly = VectorNormalize( allyEye - v_eye );
			if ( VectorDot( dirLaser, dirAlly ) < 0.7 )
				continue;
			
			// If ally is within a short distance from the laser 
			nearestPointAlongLaser = PointOnSegmentNearestToPoint( v_eye, self.origin, allyEye );
			if ( DistanceSquared( allyEye, nearestPointAlongLaser ) < 200 * 200 )
			{
				if ( SightTracePassed( v_eye, allyEye, false, undefined ) )
				{
					if ( isDefined( a_owner ) ) 
						a_owner notify( "alert", "combat", allyEye, ally );
					self target_lase_fire_at( v_eye, ally, a_owner );
					break;
				}
			}			
		}
		
		WAIT_SERVER_FRAME;
	}
}

function target_lase_fire_at( v_eye, entity_or_point, a_owner, allow_interrupts = true ) // self = laser targeting ent
{
	sight_timeout = 7;
	
	if ( IsDefined(self.a_owner) && IsDefined(self.a_owner.laser_sight_timeout) )
		sight_timeout = self.a_owner.laser_sight_timeout;
	
	self target_lase_override( v_eye, entity_or_point, sight_timeout, a_owner, true, allow_interrupts );
}

/@
"Name: target_lase_points( <entity_or_point_array>, [e_owner] )"
"Summary: Puts an targeting entity into a state where it travels from point to point pausing at each."
"Module: AI"
"CallOn: an entity"
"Example: guy.targetEnt thread target_lase_points( entity_or_point_array );"
"MandatoryArg: <entity_or_point_array> : series of vector points or entities to lase or single struct that follows a path"
"OptionalArg: <e_owner> : for notification when finished with each loop"
"SPMP: singleplayer"
@/
function target_lase_points( entity_or_point_array, e_owner )
{
	self notify("lase_points");
	self endon("lase_points");
	self endon("death");
	
	// Constants - turn into parameters?
	pauseTime = RandomFloatRange( 2.0, 4.0 );

	if ( isArray( entity_or_point_array ) &&  entity_or_point_array.size <= 0 )
		return;

	index = 0;
	start = entity_or_point_array;
	
	while ( 1 )
	{		
		while ( isDefined( self.lase_override ) )
		{
			WAIT_SERVER_FRAME;
			continue;
		}
		
		if ( isArray( entity_or_point_array ) )
		{
			self target_lase_transition( entity_or_point_array[index], e_owner );
			if ( !isVec( entity_or_point_array[index] ) && isDefined( entity_or_point_array[index].script_wait ) )
				wait entity_or_point_array[index].script_wait;
		}
		else
		{
			entity_or_point_array = target_lase_next( entity_or_point_array );
			self target_lase_transition( entity_or_point_array, e_owner );
			if ( !isVec( entity_or_point_array ) && isDefined( entity_or_point_array.script_wait ) )
				wait entity_or_point_array.script_wait;
		}
		
		looped = false;
		if ( isArray( entity_or_point_array ) )
		{
			index = index + 1;
			if ( index >= entity_or_point_array.size )
			{
				index = 0;
				looped = true;
			}
		}
		else if ( entity_or_point_array == start )
		{
			looped = true;
		}
		
		if ( looped )
		{
			self notify("lase_points_loop");
			if ( isDefined( e_owner ) )
				e_owner notify("lase_points_loop");				
		}
	}
}

function velocity_approach( endPosition, totalTime, b_early_out ) // self = object with velocity and origin
{
	self notify("velocity_approach");
	self endon("velocity_approach");
	self endon( "death" );
	
	startPosition = self.origin;
	startVelocity = self.velocity;
	startVelocityDir = VectorNormalize( self.velocity );

	decelerateTime = totalTime * 4.0;
	phase = Length( self.velocity ) / (decelerateTime * 2);	
	startTime = GetTime();
	totalTimeMs = totalTime * 1000;
	timeEarlyOut = totalTimeMs * 0.75;
	notified = false;
	MAX_MAP = 65000;

	if ( !isDefined( b_early_out ) || b_early_out )
	{
		// Abort before getting all the way
		self endon( "velocity_approach_early_out" );
	}
		
	while ( (GetTime() - startTime) < totalTimeMs )
	{
		// Even if we are not aborting early we still do the notify so that external logic knows when it happens
		if ( !notified && (GetTime() - startTime) > timeEarlyOut )
		{
			self notify( "velocity_approach_early_out" );
			notified = true;
		}
		
		deltaTime = float(GetTime() - startTime) / 1000.0;
		
		// Brake the velocity to zero over decelerateTime
		decelDeltaTime = min( deltaTime, decelerateTime );
		posWithoutBraking = startPosition + (startVelocity * decelDeltaTime);
		posWithBraking = posWithoutBraking + (startVelocityDir * phase * -0.5 * decelDeltaTime * decelDeltaTime);	
		
		// Lerp that result to where we need to be over the total time
		coef = deltaTime / totalTime;
		coef = 1.0 - (0.5 + Cos( coef * 180 ) * 0.5); // Use Cos() to ramp it up and down at the ends
		actualEndPosition = endPosition;

		assert( IsDefined( actualEndPosition ) );
		
		newOrigin = VectorLerp( posWithBraking, actualEndPosition, coef );
		
		self.velocity = (newOrigin - self.origin) / SERVER_FRAME;
		if ( newOrigin[0] > -MAX_MAP && newOrigin[0] < MAX_MAP && newOrigin[1] > -MAX_MAP && newOrigin[1] < MAX_MAP && newOrigin[2] > -MAX_MAP && newOrigin[2] < MAX_MAP )
			self.origin = newOrigin;
		
		WAIT_SERVER_FRAME;
	}
}

/@
"Name: target_lase_next( <node>  )"
"Summary: Gets next node from a given route node."
"Module: AI"
"CallOn: an entity/struct"
"Example: guy.targetEnt thread target_lase_transition( point );"
"MandatoryArg: <entity_or_point> : new destination"
"OptionalArg: <sight_timeout> : after this many seconds without line of sight to the ent/point, terminate the thread"
"SPMP: singleplayer"
@/
function target_lase_next( node )
{
	if ( !isDefined( node ) )
		return undefined;
	
	nextA = undefined;
	nextB = undefined;
	
	// Path will randomly fork any time it encounters a node with both a target and a script_linkto
	// (choosing one or the other at random)

	if ( isDefined( node.target ) && isDefined( node.script_linkto ) )
	{
		nextA = struct::get( node.target, "targetname" );
		nextB = struct::get( node.script_linkto, "script_linkname" );
	}
	else if ( isDefined( node.target ) )
	{
		nextA = struct::get( node.target, "targetname" );
	}
	else if ( isDefined( node.script_linkto ) )
	{
		nextA = struct::get( node.script_linkto, "script_linkname" );
	}
	
	if ( isDefined( nextA ) && isDefined( nextB ) )
	{
		if ( RandomFloatRange( 0.0, 1.0 ) < 0.5 )
			return nextA;
		return nextB;
	}
	
	return nextA;
}


/@
"Name: target_lase_transition( <entity_or_point>, [sight_timeout]  )"
"Summary: Moves the lase target from where it is to a destination point or entity."
"Module: AI"
"CallOn: an entity"
"Example: guy.targetEnt thread target_lase_transition( point );"
"MandatoryArg: <entity_or_point> : new destination"
"OptionalArg: <sight_timeout> : after this many seconds without line of sight to the ent/point, terminate the thread"
"SPMP: singleplayer"
@/
function target_lase_transition( entity_or_point, owner )
{
	self notify("target_lase_transition");
	self endon("target_lase_transition");
	self endon("death");	
	
	if ( isEntity( entity_or_point ) )
	{
		// Lock onto entity and follow it around
		entity_or_point endon("death");
		
		while ( 1 ) 
		{
			point = lase_point( entity_or_point );
			
			delta = point - self.origin;
			delta = delta * 0.2;
			self.origin += delta;
			
			WAIT_SERVER_FRAME;
		}
	}
	else
	{
		// Move over to point/struct
		speed = 200.0;
		point = lase_point( entity_or_point );
		time = Distance( point, self.origin ) / speed;
		
		early_out = false;
		if ( IsDefined(owner) && IsDefined(owner.max_laser_transition_time) )
		{
			early_out = true;
			time = Min(time, owner.max_laser_transition_time);
		}
			
		if ( time > 0 )
		{
			self thread velocity_approach( point, time, early_out );
			self waittill( "velocity_approach_early_out" );
		}
	}
}

/@
"Name: target_lase_override( <v_eye>, <entity_or_point>, [sight_timeout], [a_owner], [fire_weapon] )"
"Summary: Puts targeting entity to lock onto a given entiry or point pausing any target_lase_points() sequence."
"Module: AI"
"CallOn: an entity"
"Example: guy.targetEnt thread target_lase_override( player2, 8.0 );"
"MandatoryArg: <v_eye> : the eye point to check for line of sight"	
"MandatoryArg: <entity_or_point> : an entity to track or a point to track"
"OptionalArg: <sight_timeout> : after this many seconds without line of sight to the ent/point, terminate the thread"
"OptionalArg: <fire_weapon> : should fire weapon at override (default false)"
"SPMP: singleplayer"
@/
function target_lase_override( v_eye, entity_or_point, sight_timeout, a_owner, fire_weapon, allow_interrupts = true )
{
	if ( (IsDefined(self.lase_override) && ( !allow_interrupts || self.lase_override == entity_or_point) ))
		return;
			
	self notify("target_lase_override");
	self endon("target_lase_override");
	self endon("death");
	
	self.lase_override = entity_or_point;
	
	self thread target_lase_transition( entity_or_point, a_owner );
	
	outOfSightTime = 0.0;
	reTargetTime = 0.0;

	delayBeforeFiring = 0.0;

	if ( IsDefined(a_owner.lase_fire_delay) )
	{
		delayBeforeFiring = a_owner.lase_fire_delay;
	}
	
	if ( !isDefined( fire_weapon ) )
		fire_weapon = true;
	
	while ( 1 )
	{
		if ( reTargetTime >= delayBeforeFiring )
		{
			if ( isActor( a_owner ) )
			{
				a_owner.holdfire = !fire_weapon;
	
				if ( fire_weapon )
					a_owner.sniper_last_fire = GetTime();
			}
		}

		if ( !isDefined( entity_or_point ) || outOfSightTime >= sight_timeout )
		{
			self notify("target_lase_transition");
			break;
		}			

		if ( !SightTracePassed( v_eye, lase_point( entity_or_point ), false, undefined ) )
			outOfSightTime += SERVER_FRAME;
		else
			outOfSightTime = 0.0;


		reTargetTime += SERVER_FRAME;
		
		WAIT_SERVER_FRAME;
	}
	
	if ( isActor( a_owner ) )
		a_owner.holdfire = true;
	
	self.lase_override = undefined;
}

/@
"Name: is_firing( a_owner )"
"Summary: Returns true if this actor is sniper firing at something via ai_sniper_shared logic."
"Module: AI"
"CallOn: an actor"
"Example: if ( ai_sniper::is_firing( guy ) )"
"MandatoryArg: <a_owner> : the actor in question"
"SPMP: singleplayer"
@/
function is_firing( a_owner )
{
	if ( !isDefined( a_owner ) )
		return false;
	
	if ( !isDefined( a_owner.sniper_last_fire ) )
		return false;

	return ( GetTime() - a_owner.sniper_last_fire ) < 3000;
}
