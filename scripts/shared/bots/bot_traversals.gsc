#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\weapons\_weapons;

#using scripts\shared\bots\_bot;
#using scripts\shared\bots\bot_buttons;

#insert scripts\shared\shared.gsh;

#define TRACE_DISTANCE	128
	
#define TRAVERSAL_TIMEOUT 	8

// Dconst wallrun_jumpheight
#define WALLRUN_JUMP_HEIGHT	40
// Dconst wallrun_jumpvelocity
#define WALLRUN_JUMP_VELOCITY	200

#define MANTLE_CHECK_HEIGHT	16

// AIPHYS_DEFAULT_HEIGHT
#define BOT_HEIGHT 72
#define BOT_RADIUS 15

// doubleJump_maxUpwardsVelocity = 225
#define DOUBLEJUMP_V_UP 80
#define BOT_MIN_JUMP_JET 0.7

#define BOT_JUMP_ALIGN_DOT 0.94
	
#namespace bot;

function Callback_BotEnteredUserEdge( startNode, endNode )
{
	zDelta = endNode.origin[2] - startNode.origin[2];
	xyDist = Distance2D( startNode.origin, endNode.origin );
	
/*	No ladders in BO 3
	result = BulletTrace( start, start + ( startDir * TRACE_DISTANCE ), false, self );
	
	if ( result["surfacetype"] == "ladder" )
	{
		self thread climb_traversal();
		return;
	}
 */
 
	standingViewHeight = GetDvarFloat( "player_standingViewHeight", 0 );
	swimWaterHeight = standingViewHeight * GetDvarFloat( "player_swimHeightRatio", 0 );
	
 	startWaterHeight = GetWaterHeight( startNode.origin );
 	startInWater = startWaterHeight != 0 && startWaterHeight > ( startNode.origin[2] + swimWaterHeight );
 	
 	endWaterHeight = GetWaterHeight( endNode.origin );
 	endInWater = endWaterHeight != 0 && endWaterHEight > ( endNode.origin[2] + swimWaterHeight );

	if ( IsWallrunNode( endNode ) )
	{
		self thread wallrun_traversal( startNode, endNode );
	}
	else if ( startInWater && !endInWater )
	{	
		self thread leave_water_traversal( startNode, endNode );
	}
	else if ( startInWater && endInWater )
	{
		self thread swim_traversal( startNode, endNode );
	}
	else if ( zDelta >= 0 )
	{
		self thread jump_up_traversal( startNode, endNode );
	}
	else if ( zDelta < 0 )
	{
		self thread jump_down_traversal( startNode, endNode );
	}
	else
	{
		//Can't figure out how to handle traversal
		self BotReleaseManualControl();
/#
		PrintLn( "Bot ", self.name, " can't handle traversal!" );
#/
	}
}

/* No ladders in BO3
function climb_traversal( start, end, startDir, endDir )
{
	self BotSetMoveAngleFromPoint( end );
	self thread wait_acrobatics_end();
}
*/

function traversing()
{
	// IsMantling also checks TRM
	return !self IsOnGround() || self IsWallRunning() || self IsDoubleJumping() || self IsMantling() || self IsSliding();
}


// Water traversals
//========================================

function leave_water_traversal( startNode, endNode )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );
	
	self thread watch_traversal_end();	// Start the timeout thread
	
	self BotSetMoveAngleFromPoint( endNode.origin );
	
	while ( self IsPlayerUnderWater() )
	{
		self bot::press_swim_up();
		
		WAIT_SERVER_FRAME;
	}
		
	while( 1 )
	{
		self bot::press_doublejump_button();
		
		WAIT_SERVER_FRAME;
	}
}

function swim_traversal( startNode, endNode )
{
	self endon( "death" );
	level endon( "game_ended" );
	self endon( "traversal_end" );
	
	self BotSetMoveAngleFromPoint( endNode.origin );
	
	wait 0.5;
	
	self traversal_end();
}

// Jump traversals
//========================================

function jump_up_traversal( startNode, endNode )
{	
	self endon( "death" );
	level endon( "game_ended" );
	self endon( "traversal_end" );
	
	self thread watch_traversal_end();
	
	ledgeTop = CheckNavMeshDirection( endNode.origin, self.origin - endNode.origin, 128, 1 );

	height = ledgeTop[2] - self.origin[2];
	
	// Do we need to check for an overhang?
	if ( height <= BOT_HEIGHT )
	{
		self thread jump_to( ledgeTop );
		return;
	}
	dist = Distance2D( self.origin, ledgeTop );
	ledgeBottom = CheckNavMeshDirection( self.origin, ledgeTop - self.origin, dist + BOT_RADIUS, 1 );
	bottomDist = Distance2D( self.origin, ledgeBottom );
	
	// No overhang since the navmesh on the bottom doesn't run under the top
	if ( bottomDist <= dist )
	{
		self thread jump_to( ledgeTop );
		return;
	}
	
	// Use the distance between the ledge and leading edge of the bot
	dist = dist - BOT_RADIUS;
	height = height - BOT_HEIGHT;
	
	t = height / DOUBLEJUMP_V_UP;
	speed2D = self bot_speed2D();
	speed = self GetPlayerSpeed();
	moveDist = t * speed2D;
	
	if ( !moveDist || dist > moveDist )
	{
		self thread jump_to( ledgeTop );
		return;
	}
	
	self BotSetMoveMagnitude( dist / moveDist );
	
	WAIT_SERVER_FRAME;
	
	self thread jump_to( ledgeTop );
	
	WAIT_SERVER_FRAME;
	
	while( ( self.origin[2] + BOT_HEIGHT ) < ledgeTop[2] )
	{
		WAIT_SERVER_FRAME;
	}
	
	self BotSetMoveMagnitude( 1 );
}

function jump_down_traversal( startNode, endNode )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );
	
	self thread watch_traversal_end();
	
	// Check for a barrier at the beginning
	fwd = ( endNode.origin[0] - startNode.origin[0], endNode.origin[1] - startNode.origin[1], 0 );
	fwd = VectorNormalize( fwd ) * TRACE_DISTANCE;
	
	// Don't scrape the trace along the ground
	start = startNode.origin + ( 0, 0, MANTLE_CHECK_HEIGHT );
	end = startNode.origin + fwd + ( 0, 0, MANTLE_CHECK_HEIGHT );
	
	result = BulletTrace( start, end, false, self );
	
	if ( result["surfacetype"] != "none" )
	{	
		self BotSetMoveAngleFromPoint( endNode.origin );
	
		WAIT_SERVER_FRAME;
		
		self bot::tap_jump_button();
		
		return;
	}
	
	// Check if we need to jump to get the distance we need
	dist = Distance2D( startNode.origin, endNode.origin );
	height = startNode.origin[2] - endNode.origin[2];
	
	gravity = self GetPlayerGravity();
	
	t = Sqrt( ( 2 * height ) / gravity );
	
	speed2D = self bot_speed2D();
	
	if ( t * speed2D < dist )
	{
		// We may be able to just fall
		ledgeTop = CheckNavMeshDirection( startNode.origin, endNode.origin - startNode.origin, TRACE_DISTANCE, 1 );
		
		bottomDist = dist - Distance2D( startNode.origin, ledgeTop );
		ledgeBottom = CheckNavMeshDirection( endNode.origin, startNode.origin - endNode.origin, bottomDist, 1 );
		
		meshDist = Distance2D( ledgeTop, ledgeBottom );
		
		if ( meshDist > ( 2 * BOT_RADIUS ) )
		{
			self thread jump_to( endNode.origin );
			return;
		}
	}
	
	self BotSetMoveAngleFromPoint( endNode.origin );
}

// Wallrun
//========================================

function wallrun_traversal( startNode, endNode, vector )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );
	
	self thread watch_traversal_end();
	
	// Navmesh wall normals get tilted
	wallNormal = GetNavMeshFaceNormal( endNode.origin, 30 );
	wallNormal = VectorNormalize( ( wallNormal[0], wallNormal[1], 0 ) );
	                             	
	traversalDir = ( startNode.origin[0] - endNode.origin[0], startNode.origin[1] - endNode.origin[1], 0 );
	
	cross = VectorCross( wallNormal, traversalDir );
	
	runDir = VectorCross( wallNormal, cross );
	
	self BotSetLookAngles( runDir );
		
	self thread jump_to( endNode.origin, vector );
	
	self thread wait_wallrun_begin( startNode, endNode, wallNormal, runDir );
}

function wait_wallrun_begin( startNode, endNode, wallNormal, runDir )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );
	
	self waittill( "wallrun_begin" );
	
	self thread watch_traversal_end();	// Reset the timeout
	
	self BotLookNone();
	self BotSetMoveAngle( runDir );
	
	self bot::release_doublejump_button();
	
	index = self GetNodeIndexOnPath( startNode );
	index++;
	
	exitStartNode = self GetNextTraversalNodeOnPath( index );
	if ( isdefined( exitStartNode ) )
	{
		exitEndNode = GetOtherNodeInNegotiationPair( exitStartNode );
			
		if ( isdefined( exitEndNode ) )
		{
			self thread exit_wallrun( exitStartNode, exitEndNode, wallNormal, VectorNormalize( runDir ) );	
		}
	}
}

function exit_wallrun( startNode, endNode, wallNormal, runNormal )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );	
	
	self thread watch_traversal_end();	// Reset the timeout
	
	gravity = self GetPlayerGravity();
	// TODO: gadget_speedBurstWallRunJumpVelocity
	         
	vUp = Sqrt( WALLRUN_JUMP_HEIGHT * 2 * gravity );
	tPeak = vUp / gravity;
	
	hPeak = self.origin[2] + WALLRUN_JUMP_HEIGHT;
	
	fallDist = hPeak - endNode.origin[2];
	
	if ( fallDist > 0 )
	{
		tFall = Sqrt( fallDist / ( 0.5 * gravity ) );
	}
	else
	{
		// Probably need to do something else here
		tFall = 0;
	}
	
	t = tPeak + tFall;
	
	exitDir = endNode.origin - startNode.origin;
	dNormal = VectorDot( exitDir, wallNormal );
	
	vNormal = dNormal / t;
	
	if ( vNormal <= WALLRUN_JUMP_VELOCITY )
	{
		dot = Sqrt( vNormal / WALLRUN_JUMP_VELOCITY );
		vForward = Sqrt( ( WALLRUN_JUMP_VELOCITY * WALLRUN_JUMP_VELOCITY * dot * dot ) - ( vNormal * vNormal ) );
	}
	else
	{
		vForward = 0;
	}
	
	// TODO: Handle the case where the solution fails
	while(1)
	{
		WAIT_SERVER_FRAME;
		
		endDir = endNode.origin - self.origin;
		endDist = VectorDot( endDir, runNormal );
	
		vRun = self bot_speed2D();
		
		dForward = ( vRun + vForward ) * t;	
		
/*#
		dorigin = (self.origin[0], self.origin[1], endNode.origin[2] );
		
		Line( dorigin, dorigin + ( wallNormal * dNormal ) );
		Line( dorigin, dorigin +  ( runNormal * dForward ) );
		Line( dorigin, dorigin + ( wallNormal * dNormal ) +  ( runNormal * dForward ) );
		line( dorigin, endNode.origin );
		
#*/	
		if ( endDist <= dForward )
		{
			jumpAngle = ( wallNormal * vNormal ) + ( runNormal * vForward );
			
			if ( IsWallrunNode( endNode ) )
			{
				self thread wallrun_traversal( startNode, endNode, jumpAngle );
			}
			else
			{
				self BotSetLookAnglesFromPoint( endNode.origin );
				self thread jump_to( endNode.origin, jumpAngle );
			}
			return;
		}
	}
}

function jump_to( target, vector )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );
	
	if ( isdefined( vector ) )
	{
		self BotSetMoveAngle( vector );
		moveDir = VectorNormalize( ( vector[0], vector[1], 0 ) );
	}
	else
	{
		self BotSetMoveAngleFromPoint( target );
		targetDelta = target - self.origin;
		moveDir = VectorNormalize( ( targetDelta[0], targetDelta[1], 0 ) );
	}
	
	velocity = self GetVelocity( );
	velocityDir = VectorNormalize( ( velocity[0], velocity[1], 0 ) );
	
	if ( VectorDot( moveDir, velocityDir ) < BOT_JUMP_ALIGN_DOT )
	{
		WAIT_SERVER_FRAME;
	}
	
	self bot::tap_jump_button();
	
	WAIT_SERVER_FRAME;
	
	while ( !self IsOnGround() &&
	        !self IsMantling() &&
	        !self IsWallRunning() && 
	        !self bot_hit_target( target ) )
	{			
		bot::press_doublejump_button();
		
		if ( !isdefined( vector ) )
		{
			self BotSetMoveAngleFromPoint( target );
		}
		
		WAIT_SERVER_FRAME;
	}
	
	bot::release_doublejump_button();
}

function bot_update_move_angle( target )
{
	self endon( "death" );
	self endon( "traversal_end" );
	level endon( "game_ended" );	
	
	while ( !self IsMantling() )
	{
		self BotSetMoveAngleFromPoint( target );
		
		WAIT_SERVER_FRAME;
	}
}

function bot_hit_target( target )
{
	velocity = self GetVelocity();
	
	targetDir = target - self.origin;
	targetDir = ( targetDir[0], targetDir[1], 0 );
	
	// Check for 'overshoot' when going down
	if ( self.origin[2] > target[2] && VectorDot( velocity, targetDir ) <= 0 )
	{
		return true;
	}
	
	targetDist = Length( targetDir );
	
	targetSpeed = Length( velocity );
	
	if ( targetSpeed == 0 )
	{
		return false;
	}
	
	t = targetDist / targetSpeed;
	
	gravity = self GetPlayerGravity();
	
	height = self.origin[2] + velocity[2] * t - ( gravity * t * t * .5 );
	
	return height >= ( target[2] + 32 );
}

function bot_speed2D()
{
	velocity = self GetVelocity();
		
	speed2D = Distance2D( velocity, ( 0, 0, 0 ) );
	
	return speed2D;
}

// Traversal End
//========================================

function watch_traversal_end()
{
	self notify( "watch_travesal_end" );
	
	self endon( "death" );
	self endon( "traversal_end" );
	self endon( "watch_travesal_end" );
	level endon( "game_ended" );
	
	self thread wait_traversal_timeout();
	self thread watch_start_swimming();
	
	self waittill( "acrobatics_end" );

	self thread traversal_end();
}

function watch_start_swimming()
{
	self endon( "death" );
	self endon( "traversal_end" );
	self endon( "watch_travesal_end" );
	level endon( "game_ended" );
	
	while( self IsPlayerSwimming() )
	{
		WAIT_SERVER_FRAME;
	}
	
	WAIT_SERVER_FRAME;
	
	while( !self IsPlayerSwimming() )
	{
		WAIT_SERVER_FRAME;
	}
	
	self thread traversal_end();
}

function wait_traversal_timeout()
{
	self endon( "death" );
	self endon( "traversal_end" );
	self endon( "watch_travesal_end" );
	level endon( "game_ended" );
	
	wait( TRAVERSAL_TIMEOUT );
	
	self thread traversal_end();
	
	self BotRequestPath();
}

function traversal_end()
{
	self notify( "traversal_end" );
	
	self bot::release_doublejump_button();
	
	self BotLookForward();
	self BotSetMoveMagnitude( 1 );
	self BotReleaseManualControl();
}
