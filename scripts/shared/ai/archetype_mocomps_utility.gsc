#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

//*****************************************************************************
// NOTE! When adding a new motion compensator you must also declare the 
// mocomp within the ast_definitions file found at:
//
// //t7/main/game/share/raw/animtables/ast_definitions.json
//
// You should add the new mocomp to the list of "possibleValues" for the
// "_animation_mocomp" animation selector table column.
//
// This allows the AI Editor to know about all possible mocomps that can be
// used.
//
//*****************************************************************************

function autoexec RegisterDefaultAnimationMocomps()
{
	// mocomps have been moved into code now, although you can still add new ones here
	
	ASM_REGISTER_MOCOMP( "adjust_to_cover", &mocompAdjustToCoverInit, &mocompAdjustToCoverUpdate, &mocompAdjustToCoverTerminate );
	ASM_REGISTER_MOCOMP( "locomotion_explosion_death", &mocompLocoExplosionInit, undefined, undefined );
	ASM_REGISTER_MOCOMP( "mocomp_flank_stand", &mocompFlankStandInit, undefined, undefined );
}

#define COVER_ANY		"cover_any"
#define STANCE_ANY		"stance_any"

function autoexec InitAdjustToCoverParams()
{
	// These values represent the normalized time the motion compensator should start procedurally orienting toward the node's forward offset.
	// Since only four adjust animations exist, a lot of care in choosing the correct normalized time has to be taken to cover the full 360 degree range.
	
	// Adjust animations should end promptly as soon as the cover pose is reached.  If additional "settle" frames exist at the end of the animation
	// this will cause the adjust to cover mocomp to overshoot the desired angle.
	
	// If a normalized time is set too low, this can cause animations to rotate in the wrong direction.
	
	//	3	32 	2 	21	1
	//	63				14
	//	6		X		4
	//	96				47
	//	9	89	8	78	7

	// directions																2		32		3		63		6		96		9		89		8		78		7		47		4		14		1		21
	_AddAdjustToCover( "human",				COVER_ANY,			STANCE_ANY,		0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.9,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8 );
	
	_AddAdjustToCover( "human",				COVER_STAND,		STANCE_ANY,		0.4,	0.8,	0.6,	0.4,	0.6,	0.3,	0.3,	0.6,	0.9,	0.6,	0.3,	0.4,	0.7,	0.6,	0.6,	0.6 );
	_AddAdjustToCover( "human",				COVER_CROUCH,		STANCE_ANY,		0.4,	0.4,	0.4,	0.4,	0.8,	0.5,	0.2,	0.7,	0.9,	0.4,	0.2,	0.4,	0.5,	0.5,	0.5,	0.5 );
	
	_AddAdjustToCover( "human",				COVER_LEFT,			STANCE_STAND,	0.8,	0.4,	0.4,	0.4,	0.4,	0.7,	0.3,	0.5,	0.8,	0.8,	0.8,	0.9,	0.6,	0.6,	0.4,	0.4 );
	_AddAdjustToCover( "human",				COVER_LEFT,			STANCE_CROUCH,	0.8,	0.4,	0.4,	0.4,	0.4,	0.4,	0.4,	0.4,	0.4,	0.8,	0.8,	0.7,	0.6,	0.6,	0.4,	0.4 );
	
	_AddAdjustToCover( "human",				COVER_RIGHT,		STANCE_STAND,	0.8,	0.4,	0.3,	0.4,	0.6,	0.8,	0.4,	0.4,	0.4,	0.4,	0.3,	0.4,	0.6,	0.6,	0.5,	0.4 );
	_AddAdjustToCover( "human",				COVER_RIGHT,		STANCE_CROUCH,	0.8,	0.4,	0.2,	0.4,	0.4,	0.7,	0.2,	0.3,	0.3,	0.5,	0.5,	0.7,	0.6,	0.6,	0.5,	0.4 );
	
	_AddAdjustToCover( "human",				COVER_PILLAR,		STANCE_ANY,		0.8,	0.7,	0.6,	0.7,	0.6,	0.5,	0.4,	0.4,	0.4,	0.6,	0.4,	0.3,	0.7,	0.5,	0.1,	0.7 );
	
	_AddAdjustToCover( "robot",				COVER_ANY,			STANCE_ANY,		0.4,	0.4,	0.4,	0.4,	0.4,	0.4,	0.4,	0.6,	0.7,	0.5,	0.5,	0.5,	0.5,	0.4,	0.4,	0.4 );
	_AddAdjustToCover( "robot",				COVER_EXPOSED,		STANCE_ANY,		0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.9,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8,	0.8 );
}

function private _AddAdjustToCover(
	archetype, node, stance, rot2, rot32, rot3, rot36, rot6, rot69, rot9, rot98, rot8, rot87, rot7, rot47, rot4, rot14, rot1, rot21 )
{
	if ( !IsDefined( level.adjustToCover ) )
	{
		level.adjustToCover = [];
	}
	
	if ( !IsDefined( level.adjustToCover[ archetype ] ) )
	{
		level.adjustToCover[ archetype ] = [];
	}
	
	if ( !IsDefined( level.adjustToCover[ archetype ][ node ] ) )
	{
		level.adjustToCover[ archetype ][ node ] = [];
	}
	
	directions = [];
	directions[ 2 ] = rot2;
	directions[ 32 ] = rot32;
	directions[ 3 ] = rot3;
	directions[ 63 ] = rot36;
	directions[ 6 ] = rot6;
	directions[ 96 ] = rot69;
	directions[ 9 ] = rot9;
	directions[ 89 ] = rot98;
	directions[ 8 ] = rot8;
	directions[ 78 ] = rot87;
	directions[ 7 ] = rot7;
	directions[ 47 ] = rot47;
	directions[ 4 ] = rot4;
	directions[ 14 ] = rot14;
	directions[ 1 ] = rot1;
	directions[ 21 ] = rot21;
	
	level.adjustToCover[ archetype ][ node ][ stance ] = directions;
}

// Angle to node within this angle [0, 360).
function private _GetAdjustToCoverRotation( archetype, node, stance, angleToNode )
{
	assert( IsArray( level.adjustToCover[ archetype ] ) );
	
	if ( !IsDefined( level.adjustToCover[ archetype ][ node ] ) )
	{
		node = COVER_ANY;
	}
	
	assert( IsArray( level.adjustToCover[ archetype ][ node ] ) );
	
	if ( !IsDefined( level.adjustToCover[ archetype ][ node ][ stance ] ) )
	{
		stance = STANCE_ANY;
	}
	
	assert( IsArray( level.adjustToCover[ archetype ][ node ][ stance ] ) );
	assert( angleToNode >= 0 && angleToNode < 360 );
	
	direction = undefined;
	
	// Convert angles to a direction on the keypad.
	// Direction 2 is forward, and 0 degrees.
	// Angles are counter clockwise.
	//
	//	3	32 	2 	21	1
	//	63				14
	//	6		X		4
	//	96				47
	//	9	89	8	78	7
	
	if ( angletonode < 11.25 )
		direction = 2;
	else if ( angletonode < 33.75 )
		direction = 32;
	else if ( angletonode < 56.25 )
		direction = 3;
	else if ( angletonode < 78.75 )
		direction = 63;
	else if ( angletonode < 101.25 )
		direction = 6;
	else if ( angletonode < 123.75 )
		direction = 96;
	else if ( angletonode < 146.25 )
		direction = 9;
	else if ( angletonode < 168.75 )
		direction = 89;
	else if ( angletonode < 191.25 )
		direction = 8;
	else if ( angletonode < 213.75 )
		direction = 78;
	else if ( angletonode < 236.25 )
		direction = 7;
	else if ( angletonode < 258.75 )
		direction = 47;
	else if ( angletonode < 281.25 )
		direction = 4;
	else if ( angletonode < 303.75 )
		direction = 14;
	else if ( angletonode < 326.25 )
		direction = 1;
	else if ( angletonode < 348.75 )
		direction = 21;
	else
		direction = 2;
		
	assert( IsDefined( level.adjustToCover[archetype][ node ][ stance ][ direction ] ) );
		
	adjustTime = level.adjustToCover[archetype][ node ][ stance ][ direction ];
	
	if ( IsDefined( adjustTime ) )
	{
		return adjustTime;
	}
	
	// Fallback in ship builds.
	return 0.8;
}

function private debugLocoExplosion( entity )
{
	entity endon( "death" );

	/#
	startOrigin = entity.origin;
	startYawForward = AnglesToForward( ( 0, entity.angles[1], 0 ) );
	damageYawForward = AnglesToForward( ( 0, entity.damageyaw - entity.angles[1], 0 ) );

	startTime = GetTime();
	
	while ( GetTime() - startTime < 10000 )
	{
		RecordSphere( startOrigin, 5, RED, "Animscript", entity );
		RecordLine( startOrigin, startOrigin + startYawForward * 100, BLUE, "Animscript", entity );
		RecordLine( startOrigin, startOrigin + damageYawForward * 100, RED, "Animscript", entity );
		
		WAIT_SERVER_FRAME;
	}
	#/
}

function private mocompFlankStandInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOGRAVITY, false );
	entity OrientMode( "face angle", entity.angles[1] );
	
	entity PathMode( "move delayed", false, RandomFloatRange( 0.5, 1.0 ) );
	
	if ( IsDefined( entity.enemy ) )
	{
		entity GetPerfectInfo( entity.enemy );
		entity.newEnemyReaction = false;
	}
}

function private mocompLocoExplosionInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOGRAVITY, false );
	entity OrientMode( "face angle", entity.angles[1] );
	
	/#
	if ( GetDvarInt( "ai_debugLocoExplosionMocomp" ) )
	{
		entity thread debugLocoExplosion( entity );
	}
	#/
}

#define MAX_MOVE_DISTANCE 1

function private mocompAdjustToCoverInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode( AI_ANIM_USE_ANGLE_DELTAS, false );
	entity.blockingPain = true;
	
	if ( IsDefined( entity.node ) )
	{
		entity.adjustNode = entity.node;
		entity.nodeOffsetOrigin = entity GetNodeOffsetPosition( entity.node );
		entity.nodeOffsetAngles = entity GetNodeOffsetAngles( entity.node );
		entity.nodeOffsetForward = AnglesToForward( entity.nodeOffsetAngles );
		entity.nodeForward = AnglesToForward( entity.node.angles );
		entity.nodeFinalStance = Blackboard::GetBlackBoardAttribute( entity, DESIRED_STANCE );
		coverType = Blackboard::GetBlackBoardAttribute( entity, COVER_TYPE );
		
		if ( !IsDefined( entity.nodeFinalStance ) )
		{
			entity.nodeFinalStance = AiUtility::getHighestNodeStance( entity.adjustNode );
		}
		
		// [0, 360) relative to the node.
		angleDifference = Floor( AbsAngleClamp360( entity.angles[1] - entity.node.angles[1] ) );
		
		entity.mocompAngleStartTime = _GetAdjustToCoverRotation( entity.archetype, coverType, entity.nodeFinalStance, angleDifference );
	}
}

function private mocompAdjustToCoverUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( !IsDefined( entity.adjustNode ) )
	{
		return;
	}
		
	moveVector = entity.nodeOffsetOrigin - entity.origin;
		
	if ( LengthSquared( moveVector ) > ( MAX_MOVE_DISTANCE * MAX_MOVE_DISTANCE ) )
	{
		// Scale the moveVector by the max move distance.
		moveVector = VectorNormalize( moveVector ) * MAX_MOVE_DISTANCE;
	}
	
	entity ForceTeleport( entity.origin + moveVector, entity.angles, false );
	
	normalizedTime = ( ( entity GetAnimTime( mocompAnim ) * GetAnimLength( mocompAnim ) ) + mocompAnimBlendOutTime ) / mocompDuration;

	if ( normalizedTime > entity.mocompAngleStartTime )
	{
		entity OrientMode( "face angle", entity.nodeOffsetAngles );
		entity AnimMode( AI_ANIM_MOVE_CODE, false );
	}
	
	/#
	if ( GetDvarInt( "ai_debugAdjustMocomp" ) )
	{
		record3DText( entity.mocompAngleStartTime, entity.origin + (0, 0, 5), GREEN, "Animscript" );
		
		hipTagOrigin = entity GetTagOrigin( "j_mainroot" );
		
		recordLine( entity.nodeOffsetOrigin, entity.nodeOffsetOrigin + entity.nodeOffsetForward * 30, ORANGE, "Animscript", entity );
		recordLine( entity.adjustNode.origin, entity.adjustNode.origin + entity.nodeForward * 20, GREEN, "Animscript", entity );
		recordLine( entity.origin, entity.origin + AnglesToForward( entity.angles ) * 10, RED, "Animscript", entity );
		
		recordLine( hipTagOrigin, ( hipTagOrigin[0], hipTagOrigin[1], entity.origin[2] ), BLUE, "Animscript", entity );
	}
	#/
}

function private mocompAdjustToCoverTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingPain = false;
	entity.mocompAngleStartTime = undefined;
	entity.nodeOffsetAngle = undefined;
	entity.nodeOffsetForward = undefined;
	entity.nodeForward = undefined;
	entity.nodeFinalStance = undefined;
	
	if( entity.adjustNode !== entity.node )
	{
		entity.nodeOffsetOrigin = undefined;
		entity.nodeOffsetAngles = undefined;
		entity.adjustNode = undefined;
		return;
	}

	entity ForceTeleport( entity.nodeOffsetOrigin, entity.nodeOffsetAngles, false );
	entity.nodeOffsetOrigin = undefined;
	entity.nodeOffsetAngles = undefined;
	entity.adjustNode = undefined;
}