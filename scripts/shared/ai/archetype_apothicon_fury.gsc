#using scripts\shared\ai_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_selector_table;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_shared;
#using scripts\codescripts\struct;
#using scripts\shared\ai\archetype_mocomps_utility;

// ZOMBIE (Apothicon shares some functionality with zombies)
#using scripts\shared\ai\zombie;

//INTERFACE
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\archetype_apothicon_fury_interface;

#insert scripts\shared\ai\archetype_damage_effects.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\zombie.gsh; 
#insert scripts\shared\ai\archetype_apothicon_fury.gsh; 
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "model", FURY_DEATH_MODEL_SWAP );

#namespace ApothiconFuryBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitApothiconFuryBehaviorsAndASM();
	
	// INTERFACE 
	ApothiconFuryInterface::RegisterApothiconFuryInterfaceAttributes();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_APOTHICON_FURY, &ApothiconFuryBlackboardInit );
			
	// INIT ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_APOTHICON_FURY, &zombie_utility::zombieSpawnSetup );	
	spawner::add_archetype_spawn_function( ARCHETYPE_APOTHICON_FURY, &ApothiconFurySpawnSetup );	
			
	// CLIENTFIELDS
	if( ai::shouldRegisterClientFieldForArchetype( ARCHETYPE_APOTHICON_FURY ) )
	{	
		clientfield::register( "actor", FURY_DAMAGE_CLIENTFIELD, 		VERSION_DLC4, GetMinBitCountForNum(7), "counter" );
		clientfield::register( "actor", FURY_FURIOUS_MODE_CLIENTFIELD,	VERSION_DLC4, 1, "int" );
		clientfield::register( "actor", FURY_BAMF_LAND_CLIENTFIELD,	VERSION_DLC4, 1, "counter" );
		clientfield::register( "actor", FURY_DEATH_CLIENTFIELD,		VERSION_DLC4, 2, "int" );
		clientfield::register( "actor", FURY_JUKE_CLIENTFIELD,			VERSION_DLC4, 1, "int" );
	}	
}

function private InitApothiconFuryBehaviorsAndASM()
{	
	// APOTHICON JUKE BEHAVIOR
	BT_REGISTER_API( "apothiconCanJuke",					&apothiconCanJuke );
	BT_REGISTER_API( "apothiconJukeInit",					&apothiconJukeInit );
	BT_REGISTER_API( "apothiconPreemptiveJukeService",		&apothiconPreemptiveJukeService );
	BT_REGISTER_API( "apothiconPreemptiveJukePending",		&apothiconPreemptiveJukePending );
	BT_REGISTER_API( "apothiconPreemptiveJukeDone",		&apothiconPreemptiveJukeDone );
	
	// APOTHICON MOVEMENT
	BT_REGISTER_API( "apothiconMoveStart",					&apothiconMoveStart );
	BT_REGISTER_API( "apothiconMoveUpdate",				&apothiconMoveUpdate );
	
	// APOTHICON MELEE/BAMF MELEE BEHAVIOR
	BT_REGISTER_API( "apothiconCanMeleeAttack",			&apothiconCanMeleeAttack );
	BT_REGISTER_API( "apothiconShouldMeleeCondition",		&apothiconShouldMeleeCondition );
	BT_REGISTER_API( "apothiconCanBamf",					&apothiconCanBamf );
	BT_REGISTER_API( "apothiconCanBamfAfterJuke",			&apothiconCanBamfAfterJuke );	
	BT_REGISTER_API( "apothiconBamfInit",					&apothiconBamfInit );
	
	// TAUNT BEHAVIOR
	BT_REGISTER_API( "apothiconShouldTauntAtPlayer",		&apothiconShouldTauntAtPlayer );
	BT_REGISTER_API( "apothiconTauntAtPlayerEvent",		&apothiconTauntAtPlayerEvent );	
						
	// APOTHICON FURIOUS MODE
	BT_REGISTER_API( "apothiconFuriousModeInit",			&apothiconFuriousModeInit );
	
	// APOTHICON KNOCKDOWN
	BT_REGISTER_API( "apothiconKnockdownService",			&apothiconKnockdownService );
	BT_REGISTER_API( "apothiconDeathStart",				&apothiconDeathStart );
	BT_REGISTER_API( "apothiconDeathTerminate",			&apothiconDeathTerminate );
		
		
	// APOTHICON MOCOMPS
	ASM_REGISTER_MOCOMP( "mocomp_teleport@apothicon_fury",  &mocompApothiconFuryTeleportInit, undefined, &mocompApothiconFuryTeleportTerminate );
	ASM_REGISTER_MOCOMP( "mocomp_juke@apothicon_fury", 	&mocompApothiconFuryJukeInit, &mocompApothiconFuryJukeUpdate, &mocompApothiconFuryJukeTerminate );
	ASM_REGISTER_MOCOMP( "mocomp_bamf@apothicon_fury", 	&mocompApothiconFuryBamfInit, &mocompApothiconFuryBamfUpdate, &mocompApothiconFuryBamfTerminate );
				
	// APOTHICON NOTETRACKS
	ASM_REGISTER_NOTETRACK_HANDLER( FURY_BAMF_NT_START, 		&apothiconBamfOut );
	ASM_REGISTER_NOTETRACK_HANDLER( FURY_BAMF_NT_STOP, 		&apothiconBamfIn );
	ASM_REGISTER_NOTETRACK_HANDLER( FURY_BAMF_NT_LAND, 		&apothiconBamfLand );
	ASM_REGISTER_NOTETRACK_HANDLER( FURY_DEATH_START_DISSOLVE_NT, 	&apothiconDeathDissolve );	
	ASM_REGISTER_NOTETRACK_HANDLER( FURY_DEATH_DISSOLVED_NT, 	&apothiconDeathDissolved );	
}

function private ApothiconFuryBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// APOTHICON SPECIFIC BLACKBOARD
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN, undefined );
	BB_REGISTER_ATTRIBUTE( FURY_BAMF_MELEE_DISTANCE_BB, undefined, &getBamfMeleeDistance );
	BB_REGISTER_ATTRIBUTE( IDGUN_DAMAGE_DIRECTION, DAMAGE_DIRECTION_BACK, &BB_IDGunGetDamageDirection );
	BB_REGISTER_ATTRIBUTE( VARIANT_TYPE, 0, undefined );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();

	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( self );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ApothiconFuryOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);	
}

function private ApothiconFurySpawnSetup()
{		
	self.entityRadius 		= FURY_RADIUS;
	
	// juking
	self.jukeMaxDistance 	= FURY_JUKE_MAX_DIST;
	
	// no need to update sight, slight increase in performance
	self.updateSight		= false;
	
	// To not appear floaty when on the sloped surfaces
	self AllowPitchAngle(1);
	self SetPitchOrient();
	
	// dont avoid anyone
	self PushActors( true ); 
	
	// no automatic ragdoll from collision 
	self.skipAutoRagdoll = true;
		
	// damage death callback
	AiUtility::AddAIOverrideDamageCallback( self, &apothiconDamageCallback );
	AiUtility::AddAIOverrideKilledCallback( self, &apothiconOnDeath );
	
	// zigzag setup
	self.zigzag_distance_min = FURY_ZIGZAG_MIN; 
	self.zigzag_distance_max = FURY_ZIGZAG_MAX;
	
	// furious mode
	self.isFurious = false;
	self.furiousLevel = 0;
	self.nextBamfMeleeTime	= GetTime();	
	
	self.nextJukeTime = GetTime();
	self.nextPreemptiveJukeAds = RandomFloatRange( 0.7, 0.95 );	
	
	// choose a random variant type for movement and pain animations
	Blackboard::SetBlackBoardAttribute( self, VARIANT_TYPE, RandomIntRange( 0, FURY_MOVEMENT_VARIANTS ) );
}

function private ApothiconFuryOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ApothiconFuryBlackboardInit();
}

// APOTHICON GENERIC NOTETRACKS
function apothiconDeathDissolve( entity )
{	
	if( entity.archetype != ARCHETYPE_APOTHICON_FURY )
		return;
	
	a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
	
	a_filtered_zombies = array::filter( a_zombies, false, &apothiconZombieEligibleForKnockdown, entity, entity.origin );
	
	if( a_filtered_zombies.size > 0 )
	{
		foreach( zombie in a_filtered_zombies )
		{
			apothiconKnockdownZombie( entity, zombie );
		}
	}
}

function apothiconDeathDissolved( entity )
{
		
}

// APOTHICON MOCOMPS
function private mocompApothiconFuryTeleportInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity SetRepairPaths( false );
	
	locomotionSpeed = Blackboard::GetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE );
	
	if( locomotionSpeed == LOCOMOTION_SPEED_WALK )
		rate = 1.6;
	else
		rate = 2;
	
	entity ASMSetAnimationRate( rate );
	
	Assert( IsDefined( entity.traverseEndNode ) );
		
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, false );	
		
	entity NotSolid();
	entity.blockingPain = true;
	entity.useGoalAnimWeight = true;
	entity.bgbIgnoreFearInHeadlights = true;
}

function private mocompApothiconFuryTeleportTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( !IsDefined(entity.traverseEndNode) )
	{
		return;
	}	

	entity ForceTeleport( entity.traverseEndNode.origin, entity.angles );
	entity ASMSetAnimationRate( 1 );
	entity Show();
	entity Solid();
	entity.blockingPain = false;
	entity.useGoalAnimWeight = false;
	entity.bgbIgnoreFearInHeadlights = false;
}

class AnimationAdjustmentInfoZ
{
	var startTime;	
	var stopTime;
	var stepSize;
	var adjustMentStarted;
	var reAdjustmentStarted;
	var landPosOnGround;
	var enemy;
	
	constructor()
	{
		adjustMentStarted = false;
		reAdjustmentStarted = false;
	}
}

class AnimationAdjustmentInfoXY
{
	var startTime;	
	var stopTime;
	var stepSize;
	var xyDirection; // normalized
	var adjustMentStarted;
		
	constructor()
	{
		adjustMentStarted = false;	
	}
} 

function mocompApothiconFuryJukeInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.isJuking = true;
	
	if( IsDefined( entity.jukeInfo ) )
		entity OrientMode( "face angle", entity.jukeInfo.jukeStartAngles );
	else
		entity OrientMode( "face angle", entity.angles[1] );
	
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, true );
	
	entity.usegoalanimweight = true;
	entity.blockingPain = true;
	entity PushActors( false );
	entity.pushable = false;
	
	moveDeltaVector = GetMoveDelta( mocompAnim, 0, 1, entity );
	landPos = entity LocalToWorldCoords( moveDeltaVector );
	
	velocity = entity GetVelocity();
	predictedPos = entity.origin + ( velocity * 0.1 );
	
	/#
	RecordCircle( landPos, 8, BLUE, "Script", entity );
	Record3DText( "" + Distance( predictedPos, landPos ), landPos, BLUE, "Script" );
	#/
	
	landPosOnGround = entity.jukeInfo.landPosOnGround;
	heightDiff = ( landPosOnGround[2] - landPos[2] );
		
	/#
	RecordCircle( landPosOnGround, 8, GREEN, "Script", entity );
	RecordLine( landPos, landPosOnGround, GREEN, "Script", entity );
	#/
	
	// start adjustment at this time		
	Assert( AnimHasNotetrack( mocompanim, FURY_BAMF_NT_START ) );
	startTime = GetNotetrackTimes( mocompanim, FURY_BAMF_NT_START )[0];
	vectorToStartTime = GetMoveDelta( mocompanim, 0, startTime, entity );
	startPos = entity LocalToWorldCoords( vectorToStartTime );
	
	// stop adjustment at this time
	Assert( AnimHasNotetrack( mocompanim, FURY_BAMF_NT_STOP ) );
	stopTime = GetNotetrackTimes( mocompanim, FURY_BAMF_NT_STOP )[0];
	vectorToStopTime = GetMoveDelta( mocompanim, 0, stopTime, entity );
	stopPos = entity LocalToWorldCoords( vectorToStopTime );
	
	/#
	RecordSphere( startPos, 3, BLUE, "Script", entity );
	RecordSphere( stopPos, 3, BLUE, "Script", entity );	
	RecordLine( predictedPos, startPos, BLUE, "Script", entity );
	RecordLine( startPos, stopPos, BLUE, "Script", entity );
	RecordLine( stopPos, landPos, BLUE, "Script", entity );
	#/
		
	newStopPos = stopPos + ( 0, 0, heightDiff );
		
	/#
	RecordLine( startPos, newStopPos, YELLOW, "Script", entity );
	RecordLine( newStopPos, landPosOnGround, YELLOW, "Script", entity );
	RecordSphere( newStopPos, 3, YELLOW, "Script", entity );	
	#/
		
	entity.AnimationAdjustmentInfoZ = undefined;
	entity.AnimationAdjustmentInfoZ = new AnimationAdjustmentInfoZ();
	entity.AnimationAdjustmentInfoZ.startTime = startTime;
	entity.AnimationAdjustmentInfoZ.stopTime = stopTime;
	entity.AnimationAdjustmentInfoZ.enemy = entity.enemy;
			
	animLength = GetAnimLength( mocompanim ) * 1000;
	startTime = startTime * animLength;
	stopTime = stopTime * animLength;
	startTime = Floor( startTime / 50 );
	stopTime = Floor( stopTime / 50 );
	adjustDuration = stopTime - startTime;
		
	entity.AnimationAdjustmentInfoZ.stepSize = ( heightDiff / adjustDuration );
	
	entity.AnimationAdjustmentInfoZ.landPosOnGround = landPosOnGround;
	
	/#
	if( heightDiff < 0 )
		Record3DText( "-" + Distance( landPos, landPosOnGround ) + ":" + entity.AnimationAdjustmentInfoZ.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
	else
		Record3DText( "+" + Distance( landPos, landPosOnGround ) + ":" + entity.AnimationAdjustmentInfoZ.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
	#/
}

function mocompApothiconFuryJukeUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	times = GetNotetrackTimes( mocompAnim, FURY_BAMF_NT_STOP );
		
	if( times.size )
		time = times[0];
		
	animTime = entity GetAnimTime( mocompanim );
		
	if( !entity.AnimationAdjustmentInfoZ.adjustMentStarted )
	{	
		if( animTime >= entity.AnimationAdjustmentInfoZ.startTime )
		{
			entity.AnimationAdjustmentInfoZ.adjustMentStarted = true;
		}
	}
	
	if( entity.AnimationAdjustmentInfoZ.adjustMentStarted && animTime < entity.AnimationAdjustmentInfoZ.stopTime )
	{
		adjustedOrigin = entity.origin + ( 0, 0, entity.AnimationAdjustmentInfoZ.stepSize );
		entity ForceTeleport( adjustedOrigin, entity.angles );		
	}
	else
	{
		if( IsDefined( entity.enemy ) )
		{
			entity OrientMode( "face direction", entity.enemy.origin - entity.origin );
		}
	}
		
	/#RecordCircle( entity.AnimationAdjustmentInfoZ.landPosOnGround, 8, GREEN, "Script", entity );#/	
}

function mocompApothiconFuryJukeTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingPain = false;
	entity Solid();
	entity PushActors( true );
	entity.isJuking = false;
	entity.usegoalanimweight = false;
	entity.pushable = true;
	
	entity.jukeInfo = undefined;
	
	/#RecordCircle( entity.AnimationAdjustmentInfoZ.landPosOnGround, 8, GREEN, "Script", entity );#/
		
	if( IsDefined( entity.enemy ) )
	{
		entity OrientMode( "face direction", entity.enemy.origin - entity.origin );
	}
}

function private RunBamfReAdjustmentAnalysis( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	assert( IS_TRUE( entity.AnimationAdjustmentInfoZ.adjustMentStarted ) );
	
	if( IS_TRUE( entity.AnimationAdjustmentInfoZ.reAdjustMentStarted ) )
		return;
	
	reAdjustMentAnimTime = 0.45;
	animTime = entity GetAnimTime( mocompanim );
	const reAdjustmentDistThresholdSq = 1024; // 32*32
	
	// make sure that the current enemy is same as to when bamfing started
	if( animTime >= reAdjustMentAnimTime && entity.enemy === entity.AnimationAdjustmentInfoZ.enemy )
	{		
		meleeStartPosition = entity.AnimationAdjustmentInfoZ.landPosOnGround;
		
		if( IsDefined( entity.enemy.last_valid_position ) )
		{
			meleeEndPosition = entity.enemy.last_valid_position;
		}
		else		
		{
			meleeEndPosition = entity.enemy.origin;
		
			enemyForwardDir = AnglesToForward( entity.enemy.angles );
			newMeleeEndPosition = meleeEndPosition + ( enemyForwardDir * RandomIntRange( 30, 50 ) );
			newMeleeEndPosition = GetClosestPointOnNavMesh( newMeleeEndPosition, 20, 50 );
			
			if( IsDefined( newMeleeEndPosition ) )
				meleeEndPosition = newMeleeEndPosition;
		}
		
		if( DistanceSquared( meleeStartPosition, meleeEndPosition ) < reAdjustmentDistThresholdSq )
			return;
		
		if( !util::within_fov( meleeEndPosition, entity.enemy.angles, entity.origin, FURY_BAMF_FOV ) )
			return;

		if( !util::within_fov( meleeStartPosition, entity.angles, meleeEndPosition, FURY_BAMF_FOV ) )
			return;
					
		if( !IsPointOnNavMesh( meleeStartPosition, entity ) ) 
			return;
				
		if( !IsPointOnNavMesh( meleeEndPosition, entity ) ) 
			return;
		
		if( !TracePassedOnNavMesh( meleeStartPosition, meleeEndPosition, entity.entityRadius ) )
			return;
		
		if( !entity FindPath( meleeStartPosition, meleeEndPosition ) )
			return;
				
		landPos = entity.AnimationAdjustmentInfoZ.landPosOnGround;
		
		/#
		RecordCircle( meleeEndPosition, 8, CYAN, "Script", entity );
		RecordCircle( landPos, 8, BLUE, "Script", entity );
		#/

		// Z Reajustment	
		zDiff = landPos[2] - meleeEndPosition[2];
		traceStart = undefined;
		traceEnd = undefined;
		
		if( zDiff < 0 )
		{
			// player is above, do a trace above
			traceOffsetAbove = -zDiff + (30);
			traceStart = meleeEndPosition + ( 0, 0, traceOffsetAbove );
			traceEnd = meleeEndPosition + ( 0, 0, -70 );
		}
		else
		{
			traceOffsetBelow = -zDiff - 30 ;
			traceStart = meleeEndPosition + ( 0, 0, 70 );
			traceEnd = meleeEndPosition + ( 0, 0, traceOffsetBelow );
		}
			
		trace = GroundTrace( traceStart, traceEnd, false, entity, true, true );
		landPosOnGround = trace[ "position" ];
		
		landPosOnGround = GetClosestPointOnNavMesh( landPosOnGround, 100, 50 );
				
		if( !IsDefined( landPosOnGround ) )
			return;
				
		/#
		RecordCircle( landPosOnGround, 8, GREEN, "Script", entity );
		RecordLine( landPos, landPosOnGround, GREEN, "Script", entity );
		#/
		
		assert( IsDefined( entity.AnimationAdjustmentInfoZ ) );			
		startTime = reAdjustMentAnimTime;	
		stopTime = entity.AnimationAdjustmentInfoZ.stopTime;												
		
		// Z 2nd adjustment
		entity.AnimationAdjustmentInfoZ2 = new AnimationAdjustmentInfoZ();
		entity.AnimationAdjustmentInfoZ2.startTime = reAdjustMentAnimTime;
		entity.AnimationAdjustmentInfoZ2.stopTime = stopTime;
		entity.AnimationAdjustmentInfoZ2.landPosOnGround = landPosOnGround;			
		
		animLength = GetAnimLength( mocompanim ) * 1000;
		startTime = startTime * animLength;
		stopTime = stopTime * animLength;
		startTime = Floor( startTime / 50 );
		stopTime = Floor( stopTime / 50 );
		adjustDuration = stopTime - startTime;
		
		heightDiff = ( landPosOnGround[2] - landPos[2] );	
		entity.AnimationAdjustmentInfoZ2.stepSize = ( heightDiff / adjustDuration );
		
		/#
		if( heightDiff < 0 )
			Record3DText( "- " + entity.AnimationAdjustmentInfoZ2.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
		else
			Record3DText( "+ " + entity.AnimationAdjustmentInfoZ2.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
		#/		
		
		// XY Reajustment (flattened Z)
		meleeEndPosition = ( meleeEndPosition[0], meleeEndPosition[1], landPos[2] );
		xyDirection = VectorNormalize( meleeEndPosition - landPos );
		xyDistance = Distance( meleeEndPosition, landPos );
					
		entity.AnimationAdjustmentInfoXY = new AnimationAdjustmentInfoXY();
		entity.AnimationAdjustmentInfoXY.startTime = startTime;
		entity.AnimationAdjustmentInfoXY.stopTime = stopTime;
		entity.AnimationAdjustmentInfoXY.stepSize = ( xyDistance / adjustDuration );
		entity.AnimationAdjustmentInfoXY.xyDirection = xyDirection;
		entity.AnimationAdjustmentInfoXY.adjustMentStarted = true;			
		
		/#
			Record3DText( "" + xyDistance + " (step:" + entity.AnimationAdjustmentInfoXY.stepSize + ")", meleeEndPosition, BLUE, "Script" );
		#/
		
		// Start Reajustment	
		entity.AnimationAdjustmentInfoZ.reAdjustMentStarted = true;		
	}
}	

function mocompApothiconFuryBamfInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	assert( IsDefined( entity.enemy ) );
		
	entity.AnimationAdjustmentInfoZ = undefined;
	entity.AnimationAdjustmentInfoZ2 = undefined;
	entity.AnimationAdjustmentInfoXY = undefined;
	
	entity ClearPath();
	entity PathMode( "dont move" ); // prevent pathfinding
	entity.blockingPain = true;
	entity.useGoalAnimWeight = true;
	self PushActors( false ); 
	entity.isBamfing = true;		
	entity.pushable = false;
	
	anglesToEnemy = FLAT_ANGLES( VectorToAngles( entity.enemy.origin - entity.origin ) );	
	entity ForceTeleport( entity.origin, anglesToEnemy );
	entity OrientMode( "face angle", anglesToEnemy[1] );
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_NOCLIP, true );
	
	moveDeltaVector = GetMoveDelta( mocompAnim, 0, 1, entity );
	landPos = entity LocalToWorldCoords( moveDeltaVector );
		
	/#
	RecordCircle( entity.enemy.origin, 8, CYAN, "Script", entity );
	RecordLine( landPos, entity.enemy.origin, CYAN, "Script", entity );
	
	RecordCircle( landPos, 8, BLUE, "Script", entity );
	Record3DText( "" + Distance( entity.origin, landPos ), landPos, BLUE, "Script" );
	#/
	
	zDiff = entity.origin[2] - entity.enemy.origin[2];
	traceStart = undefined;
	traceEnd = undefined;
	
	if( zDiff < 0 )
	{
		// player is above, do a trace above
		traceOffsetAbove = -zDiff + (30);
		traceStart = landpos + ( 0, 0, traceOffsetAbove );
		traceEnd = landPos + ( 0, 0, -70 );
	}
	else
	{
		traceOffsetBelow = -zDiff - 30 ;
		traceStart = landpos + ( 0, 0, 70 );
		traceEnd = landPos + ( 0, 0, traceOffsetBelow );
	}
		
	trace = GroundTrace( traceStart, traceEnd, false, entity, true, true );
	landPosOnGround = trace[ "position" ];
	
	landPosOnGround = GetClosestPointOnNavMesh( landPosOnGround, 100, 25 );
	
	if( !IsDefined( landPosOnGround ) )
		landPosOnGround = entity.enemy.origin;
	
	/#
	RecordCircle( landPosOnGround, 8, GREEN, "Script", entity );
	RecordLine( landPos, landPosOnGround, GREEN, "Script", entity );
	#/
		
	heightDiff = ( landPosOnGround[2] - landPos[2] );
			
	// start adjustment at this time		
	Assert( AnimHasNotetrack( mocompanim, FURY_BAMF_NT_START ) );
	startTime = GetNotetrackTimes( mocompanim, FURY_BAMF_NT_START )[0];
	vectorToStartTime = GetMoveDelta( mocompanim, 0, startTime, entity );
	startPos = entity LocalToWorldCoords( vectorToStartTime );
	
	// stop adjustment at this time
	Assert( AnimHasNotetrack( mocompanim, FURY_BAMF_NT_STOP ) );
	stopTime = GetNotetrackTimes( mocompanim, FURY_BAMF_NT_STOP )[0];
	vectorToStopTime = GetMoveDelta( mocompanim, 0, stopTime, entity );
	stopPos = entity LocalToWorldCoords( vectorToStopTime );
	
	/#
	RecordSphere( startPos, 3, BLUE, "Script", entity );
	RecordSphere( stopPos, 3, BLUE, "Script", entity );	
	RecordLine( entity.origin, startPos, BLUE, "Script", entity );
	RecordLine( startPos, stopPos, BLUE, "Script", entity );
	RecordLine( stopPos, landPos, BLUE, "Script", entity );
	#/
		
	newStopPos = stopPos + ( 0, 0, heightDiff );
		
	/#
	RecordLine( startPos, newStopPos, GREEN, "Script", entity );
	RecordLine( newStopPos, landPosOnGround, GREEN, "Script", entity );
	RecordSphere( newStopPos, 3, GREEN, "Script", entity );	
	#/
		
	entity.AnimationAdjustmentInfoZ = new AnimationAdjustmentInfoZ();
	entity.AnimationAdjustmentInfoZ.startTime = startTime;
	entity.AnimationAdjustmentInfoZ.stopTime = stopTime;
	entity.AnimationAdjustmentInfoZ.enemy = entity.enemy;
			
	animLength = GetAnimLength( mocompanim ) * 1000;
	startTime = startTime * animLength;
	stopTime = stopTime * animLength;
	startTime = Floor( startTime / 50 );
	stopTime = Floor( stopTime / 50 );
	adjustDuration = stopTime - startTime;
		
	entity.AnimationAdjustmentInfoZ.stepSize = ( heightDiff / adjustDuration );
	
	entity.AnimationAdjustmentInfoZ.landPosOnGround = landPosOnGround;
	
	/#
	if( heightDiff < 0 )
		Record3DText( "-" + Distance( landPos, landPosOnGround ) + ":" + entity.AnimationAdjustmentInfoZ.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
	else
		Record3DText( "+" + Distance( landPos, landPosOnGround ) + ":" + entity.AnimationAdjustmentInfoZ.stepSize + ":" + adjustDuration, landPosOnGround, ORANGE, "Script" );
	#/
}

function mocompApothiconFuryBamfUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	assert( IsDefined( entity.AnimationAdjustmentInfoZ ) );
	
	if( !IsDefined( entity.enemy ) )
		return;
	
	animTime = entity GetAnimTime( mocompanim );
	
	if( !entity.AnimationAdjustmentInfoZ.adjustMentStarted )
	{	
		if( animTime >= entity.AnimationAdjustmentInfoZ.startTime )
		{
			entity.AnimationAdjustmentInfoZ.adjustMentStarted = true;
		}
	}
	
	if( entity.AnimationAdjustmentInfoZ.adjustMentStarted && animTime < entity.AnimationAdjustmentInfoZ.stopTime )
	{
		// original Z adjustment
		adjustedOrigin = entity.origin + ( 0, 0, entity.AnimationAdjustmentInfoZ.stepSize );
		
		RunBamfReAdjustmentAnalysis( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration );
			
		if( IS_TRUE( entity.AnimationAdjustmentInfoZ.reAdjustMentStarted ) )
		{
			// 2nd Z adjustment
			if( IsDefined( entity.AnimationAdjustmentInfoZ2 ) )
			{
				adjustedOrigin = adjustedOrigin + ( 0, 0, entity.AnimationAdjustmentInfoZ2.stepSize );
			}
			
			// XY adjustment
			if( IsDefined( entity.AnimationAdjustmentInfoXY ) )
			{
				adjustedOrigin = adjustedOrigin + ( entity.AnimationAdjustmentInfoXY.xyDirection * entity.AnimationAdjustmentInfoXY.stepSize );
			}
		}
		
		entity ForceTeleport( adjustedOrigin, entity.angles );
	}
	else
	{
		if( IsDefined( entity.enemy ) )
		{
			entity OrientMode( "face direction", entity.enemy.origin - entity.origin );
		}
	}
}

function mocompApothiconFuryBamfTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity PathMode( "move allowed" );
	entity Solid();
	entity Show();
	entity.blockingPain = false;
	entity.useGoalAnimWeight = false;
		
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode( AI_ANIM_USE_BOTH_DELTAS );
	entity.isBamfing = false;		
	entity.pushable = true;
	self PushActors( true ); 
	
	entity.jukeInfo = undefined;
	
	if( !IsPointOnNavMesh( entity.origin ) )
	{
		clampToNavmeshLocation = GetClosestPointOnNavMesh( entity.origin, 100, 25 );
		
		if( IsDefined( clampToNavmeshLocation ) )
		{
			entity ForceTeleport( clampToNavmeshLocation );
		}
	}
}

// APOTHICON MELEE
function apothiconCanMeleeAttack( entity )
{
	return ( apothiconCanBamf( entity ) || apothiconShouldMeleeCondition( entity ) );
}

function apothiconShouldMeleeCondition( behaviorTreeEntity )
{
	if( IsDefined( behaviorTreeEntity.enemyoverride ) && IsDefined( behaviorTreeEntity.enemyoverride[1] ) )
	{
		return false;
	}
	
	if( !IsDefined( behaviortreeentity.enemy ) )
    {
		return false;
	}

	if( IsDefined( behaviorTreeEntity.marked_for_death ) )
	{
		return false;
	}

	if( IS_TRUE( behaviorTreeEntity.ignoreMelee ) )
	{
		return false;
	}
	
	if( DistanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.enemy.origin ) > FURY_MELEE_DIST_SQ )
	{
		return false;
	}
	
	yawToEnemy = AngleClamp180( behaviorTreeEntity.angles[ 1 ] - GET_YAW( behaviorTreeEntity, behaviorTreeEntity.enemy.origin ) );
	if( abs( yawToEnemy ) > ZM_MELEE_YAW )
	{
		return false;
	}
	
	return true;
}

function apothiconCanBamfAfterJuke( entity )
{
	return apothiconCanBamfInternal( entity );
}

// APOTHICON BAMF MELEE
function apothiconCanBamf( entity )
{
	return apothiconCanBamfInternal( entity );
}

function apothiconCanBamfInternal( entity, bamfAfterJuke = false )
{
	if( !ai::GetAiAttribute( entity, "can_bamf" ) )
		return false;
	
	if( !IsDefined( entity.enemy ) )
		return false;
	
	if( !IsPlayer( entity.enemy ) )
		return false;
		
	if( IS_TRUE( entity.juking ) )
		return false;
	
	if( IS_TRUE( entity.isBamfing ) )
		return false;
	
	if( !bamfAfterJuke )
	{
		if( GetTime() < entity.nextBamfMeleeTime )
			return false;
		
		jukeEvents = Blackboard::GetBlackboardEvents( "apothicon_fury_bamf" );
		tooCloseJukeDistanceSqr = SQR( FURY_TOO_CLOSE_TO_BAMF_DIST );
		
		foreach ( event in jukeEvents )
		{
			if ( Distance2DSquared( entity.origin, event.data.origin ) <= tooCloseJukeDistanceSqr )
			{
				return false;
			}
		}
	}
	
	assert( IsDefined( entity.enemy ) );
	enemyOrigin = entity.enemy.origin;
	
	apothiconFurys = GetAIArchetypeArray( ARCHETYPE_APOTHICON_FURY );
	furiesNearPlayer = 0;
	
	foreach( apothiconFury in apothiconFurys )
	{
		if( DistanceSquared( enemyOrigin, apothiconFury.origin ) <= ( 80 * 80 ) )
			furiesNearPlayer++;
	}
	
	if( furiesNearPlayer >= 4 )
		return false;
	
	distanceToEnemySq = DistanceSquared( enemyOrigin, entity.origin );
	distanceMinThresholdSq = SQR( FURY_BAMF_MELEE_DIST_MIN );
	
	if( bamfAfterJuke )
		distanceMinThresholdSq = SQR( FURY_BAMF_MELEE_DIST_MIN_AFTER_JUKE );
	
	if( distanceToEnemySq > distanceMinThresholdSq && distanceToEnemySq < SQR( FURY_BAMF_MELEE_DIST_MAX ) )
	{	
		if( !util::within_fov( enemyOrigin, entity.enemy.angles, entity.origin, FURY_BAMF_FOV ) )
			return false;
	
		if( !util::within_fov( entity.origin, entity.angles, enemyOrigin, FURY_BAMF_FOV ) )
			return false;
	
		meleeStartPosition = entity.origin;
		meleeEndPosition = enemyOrigin;
				
		if( !IsPointOnNavMesh( meleeStartPosition, entity ) ) 
			return false;
				
		if( !IsPointOnNavMesh( meleeEndPosition, entity ) ) 
			return false;
		
		if( !TracePassedOnNavMesh( meleeStartPosition, meleeEndPosition, entity.entityRadius ) )
			return false;
		
		if( !entity FindPath( meleeStartPosition, meleeEndPosition ) )
			return false;
	
		return true;
	}
	
	return false;
}

function getBamfMeleeDistance( entity )
{
	distanceToEnemy = Distance( self.enemy.origin, self.origin );
	
	return distanceToEnemy;
}

function apothiconBamfInit( entity )
{
	jukeInfo = SpawnStruct();
	jukeInfo.origin = entity.origin;
	jukeInfo.entity = entity;
	
	Blackboard::AddBlackboardEvent( "apothicon_fury_bamf", jukeInfo, FURY_BAMF_GLOBAL_DELAY_MSEC );
	
	if( IsDefined( level.nextBamfMeleeTimeMin ) && IsDefined( level.nextBamfMeleeTimeMax ) )
	{
		entity.nextBamfMeleeTime = GetTime() + RandomFloatRange( level.nextBamfMeleeTimeMin, level.nextBamfMeleeTimeMax );
	}
	else
	{
		entity.nextBamfMeleeTime = GetTime() + RandomFloatRange( FURY_BAMF_COOLDOWN_MIN, FURY_BAMF_COOLDOWN_MAX );	
	}
}

// TAUNT BEHAVIOR
function apothiconShouldTauntAtPlayer( entity )
{
	tauntEvents = Blackboard::GetBlackboardEvents( "apothicon_fury_taunt" );
	
	if( IsDefined( tauntevents ) && tauntevents.size )
		return false;
	
	return true;
}

function apothiconTauntAtPlayerEvent( entity )
{
	jukeInfo = SpawnStruct();
	jukeInfo.origin = entity.origin;
	jukeInfo.entity = entity;
	
	Blackboard::AddBlackboardEvent( "apothicon_fury_taunt", jukeInfo, FURY_TAUNT_GLOBAL_DELAY_MSEC );
}

function BB_IDGunGetDamageDirection()
{
	if( IsDefined( self.damage_direction ) )
	{
		return self.damage_direction;
	}
	return self AiUtility::BB_GetDamageDirection();
}

function apothiconBamfLand( entity )
{	
	if( entity.archetype != ARCHETYPE_APOTHICON_FURY )
		return;
	
	if( IsDefined( entity.enemy ) )
	{
		entity OrientMode( "face direction", entity.enemy.origin - entity.origin );
	}
	
	entity clientfield::increment( FURY_BAMF_LAND_CLIENTFIELD );	
	
	if( IsDefined( entity.enemy ) && IsPlayer(entity.enemy) && DistanceSquared( entity.enemy.origin, entity.origin ) <= SQR( FURY_BAMF_MELEE_RANGE ) )
	{
		entity.enemy DoDamage( 25, entity.origin, entity, entity, undefined, "MOD_MELEE" );		
	}
	
	PhysicsExplosionSphere( entity.origin, FURY_BAMF_MELEE_DAMAGE_MAX, FURY_BAMF_MELEE_DAMAGE_MIN, 10 );	
}

function apothiconMoveStart( entity )
{
	entity.moveTime = GetTime();
	entity.moveOrigin = entity.origin;
}

function apothiconMoveUpdate(entity)
{
	if ( IsDefined( entity.move_anim_end_time ) && ( GetTime() >= entity.move_anim_end_time ) )
	{
		entity.move_anim_end_time = undefined;
		return;
	}
	
	if ( !IS_TRUE( entity.missingLegs ) && ( GetTime() - entity.moveTime > ZM_MOVE_TIME ) )
	{
		distSq = Distance2DSquared( entity.origin, entity.moveOrigin );
		
		if ( distSq < ZM_MOVE_DIST_SQ )
		{
			if ( IsDefined( entity.cant_move_cb ) )
			{
				entity [[ entity.cant_move_cb ]]();
			}
		}
		else
		{			
			entity.cant_move = false;
		}

		entity.moveTime = GetTime();
		entity.moveOrigin = entity.origin;
	}
}

// APOTHICON KNOCKDOWN
function apothiconKnockdownService( entity )
{	
	if( IS_TRUE(entity.isJuking) )
		return;
	
	if( IS_TRUE(entity.isBamfing) )
		return;
	
	velocity = entity GetVelocity();
	predict_time = 0.5;
	predicted_pos = entity.origin + ( velocity * predict_time );
	move_dist_sq = DistanceSquared( predicted_pos, entity.origin );
	speed = move_dist_sq /  predict_time;
	
	if( speed >= 10 )
	{
		a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
		
		a_filtered_zombies = array::filter( a_zombies, false, &apothiconZombieEligibleForKnockdown, entity, predicted_pos );
		
		if( a_filtered_zombies.size > 0 )
		{
			foreach( zombie in a_filtered_zombies )
			{
				apothiconKnockdownZombie( entity, zombie );
			}
		}
	}
}

function private apothiconZombieEligibleForKnockdown( zombie, thrasher, predicted_pos )
{
	if( zombie.knockdown === true )
	{
		return false;
	}
	
	if( IS_TRUE( zombie.missingLegs ) )
	{
		return false;
	}
    
	knockdown_dist_sq = 48*48;
	dist_sq = DistanceSquared( predicted_pos, zombie.origin );
	
	if( dist_sq > knockdown_dist_sq )
	{
		return false;
	}
	
	origin = thrasher.origin;

	facing_vec = AnglesToForward( thrasher.angles );
	enemy_vec = zombie.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < 0 )// is enemy behind thrasher
	{
		return false;
	}
	
	return true;
	
}

function apothiconKnockdownZombie( entity, zombie )
{
	zombie.knockdown = true;
	zombie.knockdown_type = KNOCKDOWN_SHOVED;
	zombie_to_thrasher = entity.origin - zombie.origin;
	zombie_to_thrasher_2d = VectorNormalize( ( zombie_to_thrasher[0], zombie_to_thrasher[1], 0 ) );
	
	zombie_forward = AnglesToForward( zombie.angles );
	zombie_forward_2d = VectorNormalize( ( zombie_forward[0], zombie_forward[1], 0 ) );
	
	zombie_right = AnglesToRight( zombie.angles );
	zombie_right_2d = VectorNormalize( ( zombie_right[0], zombie_right[1], 0 ) );
	
	dot = VectorDot( zombie_to_thrasher_2d, zombie_forward_2d );
	
	if( dot >= 0.5 )
	{
		zombie.knockdown_direction = "front";
		zombie.getup_direction = GETUP_BACK;
	}
	else if ( dot < 0.5 && dot > -0.5 )
	{
		dot = VectorDot( zombie_to_thrasher_2d, zombie_right_2d );
		if( dot > 0 )
		{
			zombie.knockdown_direction = "right";

			if ( math::cointoss() )
			{
				zombie.getup_direction = GETUP_BACK;
			}
			else
			{
				zombie.getup_direction = GETUP_BELLY;
			}
		}
		else
		{
			zombie.knockdown_direction = "left";
			zombie.getup_direction = GETUP_BELLY;
		}
	}
	else
	{
		zombie.knockdown_direction = "back";
		zombie.getup_direction = GETUP_BELLY;
	}
}

// APOTHICON FURIOUS MODE
function apothiconShouldSwitchToFuriousMode( entity )
{
	if( !ai::GetAiAttribute( entity, "can_be_furious" ) )
		return false;	
	
	if( IS_TRUE( entity.isFurious ) )
		return false;
		
	apothiconFurys = GetAIArchetypeArray( ARCHETYPE_APOTHICON_FURY );
	
	count = 0;
	
	foreach( apothiconFury in apothiconFurys )
	{
		if( IS_TRUE( apothiconFury.isFurious ) )
			count++;
	}
	
	if( count >= FURY_FURIOUS_MAX_AI )
		return false;
	
	furiousEvents = Blackboard::GetBlackboardEvents( "apothicon_furious_mode" );
	
	if( !furiousEvents.size && entity.furiousLevel >= FURY_FURIOUS_LEVEL_THRESHOLD )
		return true;	
	
	return false;
}

function apothiconFuriousModeInit( entity )
{	
	if( !apothiconShouldSwitchToFuriousMode( entity ) )
		return;
		
	furiousInfo = SpawnStruct();
	furiousInfo.origin = entity.origin;
	furiousInfo.entity = entity;
	
	Blackboard::AddBlackboardEvent( "apothicon_furious_mode", furiousInfo, RandomIntRange( FURY_FURIOUS_GLOBAL_DELAY_MIN_MSEC, FURY_FURIOUS_GLOBAL_DELAY_MAX_MSEC ) );
	
	entity PushActors(false);
	
	entity.isFurious = true;
	//entity ASMSetAnimationRate( 1.3 );
	Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SUPER_SPRINT );	
	
	entity clientfield::set( FURY_FURIOUS_MODE_CLIENTFIELD, 1 );	
	
	entity.health = entity.health * 2;
}

// APOTHICON JUKE BEHAVIOR
class jukeInfo
{
	var jukeStartAngles;
	var jukeDirection;
	var jukeDistance;
	var landPosOnGround;
}

function apothiconPreemptiveJukeService( entity )
{
	if( !IS_TRUE( entity.isFurious ) )
	{
		return false;
	}

	if ( IsDefined( entity.nextJukeTime ) && entity.nextJukeTime > GetTime() )
	{
		return false;
	}
	
	if ( IsDefined( entity.enemy ) )
	{
		if ( !IsPlayer( entity.enemy ) )
		{
			return false;
		}

		if ( entity.enemy PlayerADS() < entity.nextPreemptiveJukeAds )
		{
			return false;
		}
	}
	
	if( apothiconCanJuke( entity ) )
	{
		entity.apothiconPreemptiveJuke = true;
	}
}

function apothiconPreemptiveJukePending( entity )
{
	return IS_TRUE( entity.apothiconPreemptiveJuke );
}

function apothiconPreemptiveJukeDone( entity )
{
	entity.apothiconPreemptiveJuke = false;
}

function apothiconCanJuke( entity )
{
	if( !ai::GetAiAttribute( entity, "can_juke" ) )
		return false;

	if( !IsDefined( entity.enemy ) || !IsPlayer(entity.enemy) )
		return false;
	
	if( IS_TRUE( entity.isJuking ) )
	{
		return false;
	}
		
	if( IS_TRUE( entity.apothiconPreemptiveJuke ) )
	{
		return true;
	}
	
	if( IsDefined( entity.nextJukeTime ) && GetTime() < entity.nextJukeTime )
	{
		return false;
	}
			
	jukeEvents = Blackboard::GetBlackboardEvents( "apothicon_fury_juke" );
	tooCloseJukeDistanceSqr = SQR( FURY_TOO_CLOSE_TO_JUKE_DIST );
	
	foreach ( event in jukeEvents )
	{
		if ( Distance2DSquared( entity.origin, event.data.origin ) <= tooCloseJukeDistanceSqr )
		{
			return false;
		}
	}
	
	if ( Distance2DSquared( entity.origin, entity.enemy.origin ) < SQR( FURY_TOO_CLOSE_TO_JUKE_DIST ) )
	{
		return false;
	}
			
	if( !util::within_fov( entity.enemy.origin, entity.enemy.angles, entity.origin, FURY_BAMF_FOV ) )
		return false;
	
	if( !util::within_fov( entity.origin, entity.angles, entity.enemy.origin, FURY_BAMF_FOV ) )
		return false;
	
	if ( IsDefined( entity.jukeMaxDistance ) && IsDefined( entity.enemy ) )
	{
		maxDistSquared = entity.jukeMaxDistance * entity.jukeMaxDistance;
		
		if ( Distance2DSquared( entity.origin, entity.enemy.origin ) > maxDistSquared )
		{
			return false;
		}
	}
	
	jukeInfo = calculateJukeInfo( entity );

	if( IsDefined( jukeInfo ) )
	{
		return true;
	}
		
	return false;
}

function apothiconJukeInit( entity )
{
	jukeInfo = calculateJukeInfo( entity );
	assert( IsDefined( jukeInfo ) );
	
	Blackboard::SetBlackBoardAttribute( entity, JUKE_DISTANCE, jukeInfo.jukeDistance );
	Blackboard::SetBlackBoardAttribute( entity, JUKE_DIRECTION, jukeInfo.jukeDirection );
	
	entity ClearPath();
	entity notify( "bhtn_action_notify", "apothicon_fury_juke" );
	
	jukeInfo = SpawnStruct();
	jukeInfo.origin = entity.origin;
	jukeInfo.entity = entity;

	Blackboard::AddBlackboardEvent( "apothicon_fury_juke", jukeInfo, FURY_JUKE_GLOBAL_DELAY_MSEC );	
	
	entity.nextPreemptiveJukeAds = RandomFloatRange( 0.6, 0.8 );

	if( IsDefined( level.nextjukeMeleeTimeMin ) && IsDefined( level.nextjukeMeleeTimeMax ) )
	{
		entity.nextjukeMeleeTime = GetTime() + RandomFloatRange( level.nextjukeMeleeTimeMin, level.nextjukeMeleeTimeMax );
	}
	else
	{
		entity.nextJukeTime = GetTime() + RandomFloatRange( FURY_JUKE_COOLDOWN_MIN, FURY_JUKE_COOLDOWN_MAX );
	}
}

function validateJuke( entity, entityRadius, jukeVector )
{
	velocity = entity GetVelocity();
	predictedPos = entity.origin + ( velocity * 0.1 );
	jukeLandPos = predictedPos + jukeVector;
		
	if( !IsDefined( jukeLandPos ) )
		return undefined;
	
	traceStart = jukeLandPos + ( 0, 0, 70 );
	traceEnd = jukeLandPos + ( 0, 0, -70 );
	
	trace = GroundTrace( traceStart, traceEnd, false, entity, true, true );
	landPosOnGround = trace[ "position" ];
	
	if( !IsDefined( landPosOnGround ) )
		return undefined;	
	
	if( !IsPointOnNavMesh( landPosOnGround ) )
		return undefined;
	
	/#RecordLine( entity.origin, predictedPos, GREEN, "Script", entity );#/
	/#RecordSphere( jukeLandPos, 2, RED, "Script", entity );#/
	/#RecordLine( predictedPos, jukeLandPos, RED, "Script", entity );#/

	if( IsPointOnNavMesh( landPosOnGround, ( entity.entityRadius * 2.5 ) ) && TracePassedOnNavMesh( predictedPos, landPosOnGround, entity.entityRadius ) )
	{
		if( !entity IsPosInClaimedLocation( landPosOnGround ) && entity MayMoveFromPointToPoint( predictedPos, landPosOnGround, false, false ) )
		{
			/#RecordSphere( landPosOnGround, 2, GREEN, "Script", entity );#/
			/#RecordLine( predictedPos, landPosOnGround, GREEN, "Script", entity );#/
	
			return landPosOnGround;
		}
	}
				
	return undefined;	
}

function private getJukeVector( entity, jukeAnimAlias )
{
	jukeAnim = entity AnimMappingSearch( IString( jukeAnimAlias ) );
	localDeltaVector = GetMoveDelta( jukeAnim, 0, 1, entity );
	endPoint = entity LocalToWorldCoords( localDeltaVector );
	
	return ( endpoint - entity.origin );
}

function private calculateJukeInfo( entity )
{
	if( IsDefined( entity.jukeInfo ) )
		return entity.jukeInfo;
	
	// favor forward jukes if its gets away from shooting direction
	directionToEnemy = VectorNormalize( entity.enemy.origin - entity.origin );
	forwardDir = AnglesToForward( entity.angles );
	
	possibleJukes = [];
	jukeValidDistanceType = [];
	entityRadius = entity.entityRadius;
			
	// JUKE - LEFT
	jukeVector = getJukeVector( entity, "anim_zombie_juke_left_long" );
	landPosOnGround = validateJuke( entity, entityRadius, jukeVector );
	
	if( IsDefined( landPosOnGround ) )
	{
		jukeInfo = new jukeInfo();
		jukeInfo.jukeDirection = "left";
		jukeInfo.jukeDistance = FURY_JUKE_LONG;
		jukeInfo.landPosOnGround = landPosOnGround;
		
		ARRAY_ADD( possibleJukes, jukeInfo );				
	}	
		
	// JUKE - RIGHT
	jukeVector = getJukeVector( entity, "anim_zombie_juke_right_long" );
	landPosOnGround = validateJuke( entity, entityRadius, jukeVector );  
	
	if( IsDefined( landPosOnGround ) )
	{
		jukeInfo = new jukeInfo();
		jukeInfo.jukeDirection = "right";
		jukeInfo.jukeDistance = FURY_JUKE_LONG;
		jukeInfo.landPosOnGround = landPosOnGround;
		
		ARRAY_ADD( possibleJukes, jukeInfo );				
	}
	
	// DIAGONAL JUKE - LEFT
	jukeVector = getJukeVector( entity, "anim_zombie_juke_left_front_long" );
	landPosOnGround = validateJuke( entity, entityRadius, jukeVector );
	
	if( IsDefined( landPosOnGround ) )
	{
		jukeInfo = new jukeInfo();
		jukeInfo.jukeDirection = "left_front";
		jukeInfo.jukeDistance = FURY_JUKE_LONG;
		jukeInfo.landPosOnGround = landPosOnGround;
		
		ARRAY_ADD( possibleJukes, jukeInfo );				
	}
	
	// DIAGONAL JUKE - RIGHT
	jukeVector = getJukeVector( entity, "anim_zombie_juke_right_front_long" );
	landPosOnGround = validateJuke( entity, entityRadius, jukeVector );
	
	if( IsDefined( landPosOnGround ) )
	{
		jukeInfo = new jukeInfo();
		jukeInfo.jukeDirection = "right_front";
		jukeInfo.jukeDistance = FURY_JUKE_LONG;
		jukeInfo.landPosOnGround = landPosOnGround;
		
		ARRAY_ADD( possibleJukes, jukeInfo );				
	}
		
	if( possibleJukes.size )
	{
		jukeInfo = array::random( possibleJukes );			
		
		jukeInfo.jukeStartAngles = entity.angles;
		
		entity.lastJukeInfoUpdateTime = GetTime();
		entity.jukeInfo = jukeInfo;
	
		return jukeInfo;
	}
	
	return undefined;
}

// APOTHICON NOTETRACKS
function apothiconBamfOut( entity )
{
	if( entity.archetype != ARCHETYPE_APOTHICON_FURY )
		return;
	
	entity Ghost();
	entity NotSolid();
	
	self clientfield::set( FURY_JUKE_CLIENTFIELD, 0 );	
	
	a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
	
	a_filtered_zombies = array::filter( a_zombies, false, &apothiconZombieEligibleForKnockdown, entity, entity.origin );
	
	if( a_filtered_zombies.size > 0 )
	{
		foreach( zombie in a_filtered_zombies )
		{
			apothiconKnockdownZombie( entity, zombie );
		}
	}
}

function apothiconBamfIn( entity )
{	
	if( entity.archetype != ARCHETYPE_APOTHICON_FURY )
		return;
	
	if( IsDefined( entity.traverseEndNode ) )
	{
		entity ForceTeleport( entity.traverseEndNode.origin, entity.angles );
	
		// in case if this AI is furious, and bamfing, then we need to avoid any issues
		entity Unlink();	
		entity.isTraveling = false;
		entity notify( "travel_complete" );
		
		entity SetRepairPaths( true );
					
		entity.blockingPain = false;
		entity.useGoalAnimWeight = false;
		entity.bgbIgnoreFearInHeadlights = false;
	
		entity ASMSetAnimationRate( 1 );
		entity FinishTraversal();
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS, true );
	}
	
	entity Show();	
	entity Solid();	
	
	self clientfield::set( FURY_JUKE_CLIENTFIELD, 1 );	
		
	a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
	
	a_filtered_zombies = array::filter( a_zombies, false, &apothiconZombieEligibleForKnockdown, entity, entity.origin );
	
	if( a_filtered_zombies.size > 0 )
	{
		foreach( zombie in a_filtered_zombies )
		{
			apothiconKnockdownZombie( entity, zombie );
		}
	}
}

function apothiconDeathStart( entity )
{
	entity SetModel( FURY_DEATH_MODEL_SWAP );
	entity clientfield::set( FURY_DEATH_CLIENTFIELD, 2 );	
	entity NotSolid();
}

function apothiconDeathTerminate( entity )
{
	
}

function apothiconDamageClientFieldUpdate( entity, sHitLoc )
{
	increment = 0;
	
	if( IS_HITLOC_HEAD(sHitLoc) )
	{
		increment = IMPACT_HEAD;
	}
	else if( IS_HITLOC_CHEST(sHitLoc) )
	{
		increment = IMPACT_CHEST;	
	}
	else if( IS_HITLOC_HIPS(sHitLoc) )
	{
		increment = IMPACT_HIPS;	
	}
	else if( IS_HITLOC_RIGHT_ARM(sHitLoc) )
	{
		increment = IMPACT_R_ARM;	
	}
	else if( IS_HITLOC_LEFT_ARM(sHitLoc) )
	{
		increment = IMPACT_L_ARM;	
	}
	else if( IS_HITLOC_LEFT_LEG(sHitLoc) )
	{
		increment = IMPACT_L_LEG;	
	}
	else
	{
		increment = IMPACT_R_LEG;	
	}
	
	entity clientfield::increment( FURY_DAMAGE_CLIENTFIELD, increment );
}

// APOTHICON DAMAGE CALLBACK
function apothiconDamageCallback( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	//Wait for the spawn to be complete
	if( !IS_TRUE( self.zombie_think_done ) )
	{
		return 0;
	}
	
	if( IsDefined( eAttacker ) && IsPlayer( eAttacker ) && IsDefined( sHitLoc ) )
	{
		apothiconDamageClientFieldUpdate( self, sHitLoc );
	}
	
	if( IsDefined( sHitLoc ) )
	{
		if( !IS_TRUE( self.isFurious ) )
		{
			self.furiousLevel += FURY_FURIOUS_LEVEL_STEP;									
		}
	}
	
	eAttacker zombie_utility::show_hit_marker();
			
	return iDamage;
}

function apothiconOnDeath( inflictor, attacker, damage, meansOfDeath, weapon, dir, hitLoc, offsetTimes )
{
	self clientfield::set( FURY_DEATH_CLIENTFIELD, 1 );	
	
	self NotSolid();
	
	return damage;
}

// APOTHICON INTERFACE CALLBACKS
#namespace ApothiconFuryBehaviorInterface;

function moveSpeedAttributeCallback( entity, attribute, oldValue, value )
{
	if( IS_TRUE( entity.isFurious ) )
		return;
	
	switch ( value )
	{
		case "walk":
			Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_WALK );		
			break;
		case "run":
			Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );		
			break;
		case "sprint":
			Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );		
			break;
		case "super_sprint":
			Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SUPER_SPRINT );		
			break;
		default:
			break;
	}
}

