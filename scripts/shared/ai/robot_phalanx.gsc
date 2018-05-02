#using scripts\shared\ai_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\robot_phalanx.gsh;

#namespace RobotPhalanx;

function private _AssignPhalanxStance( robots, stance )
{
	assert( IsArray( robots ) );
	
	foreach ( index, robot in robots )
	{
		if ( IsDefined( robot) && IsAlive( robot ) )
		{
			robot ai::set_behavior_attribute( "phalanx_force_stance", stance );
		}
	}
}

function private _CreatePhalanxTier(
	phalanxType, tier, phalanxPosition, forward, maxTierSize, spawner = undefined )
{
	robots = [];

	if ( !IsSpawner( spawner ) )
	{
		spawner = _GetPhalanxSpawner( tier );
	}
	
	positions = _GetPhalanxPositions( phalanxType, tier );
	angles = VectorToAngles( forward );

	foreach ( index, position in positions )
	{
		if ( index >= maxTierSize )
		{
			break;
		}
	
		orientedPos = _RotateVec( position, angles[1] - PHALANX_ROTATION_OFFSET );
	
		navMeshPosition = GetClosestPointOnNavMesh(
			phalanxPosition + orientedPos, PHALANX_NAVMESH_TOLERANCE );

		// Make sure the spawner can actually spawn a robot.
		if ( !( spawner.spawnflags & SPAWNFLAG_ACTOR_SCRIPTINFINITESPAWN ) )
		{
			spawner.count++;
		}

		robot = spawner spawner::spawn( true, "", navMeshPosition, angles );
		
		if ( IsAlive( robot ) )
		{
			_InitializeRobot( robot );
		
			// Wait till all robots have been created.
			WAIT_SERVER_FRAME;
		
			robots[ robots.size ] = robot;
		}
	}
	
	return robots;
}

// Caps the maximum damage the phalanx takes from a single explosive entity.
function private _DampenExplosiveDamage(
	inflictor, attacker, damage, flags, meansOfDamage, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;

	isExplosive = IsInArray(
		array(
			"MOD_GRENADE",
			"MOD_GRENADE_SPLASH",
			"MOD_PROJECTILE",
			"MOD_PROJECTILE_SPLASH",
			"MOD_EXPLOSIVE" ),
		meansOfDamage );
		
	if ( isExplosive && IsDefined( inflictor ) && IsDefined( inflictor.weapon ) )
	{
		weapon = inflictor.weapon;
		
		distanceToEntity = Distance( entity.origin, inflictor.origin );
	
		// Linear falloff from grenade distance.
		fractionDistance = 1;
		
		if ( weapon.explosionradius > 0 )
		{
			fractionDistance = ( weapon.explosionradius - distanceToEntity ) / weapon.explosionradius;
		}
		
		// This causes near exponential damage falloff since the original damage already considers radius at a near linear falloff.
		return Int( Max( damage * fractionDistance, 1 ) );
	}
	
	return damage;
}

function private _GetPhalanxPositions( phalanxType, tier )
{
	switch ( phalanxType )
	{
		case PHALANX_WEDGE:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_WEDGE_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_WEDGE_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_WEDGE_TIER_THREE;
			}
			break;
		case PHALANX_DIAGONAL_LEFT:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_DIAGONAL_LEFT_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_DIAGONAL_LEFT_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_DIAGONAL_LEFT_TIER_THREE;
			}
			break;
		case PHALANX_DIAGONAL_RIGHT:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_DIAGONAL_RIGHT_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_DIAGONAL_RIGHT_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_DIAGONAL_RIGHT_TIER_THREE;
			}
			break;
		case PHALANX_FORWARD:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_FORWARD_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_FORWARD_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_FORWARD_TIER_THREE;
			}
			break;
		case PHALANX_COLUMN:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_COLUMN_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_COLUMN_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_COLUMN_TIER_THREE;
			}
			break;
		case PHALANX_COLUMN_RIGHT:
			switch( tier )
			{
				case PHALANX_TIER_ONE:
					return PHALANX_COLUMN_RIGHT_TIER_ONE;
				case PHALANX_TIER_TWO:
					return PHALANX_COLUMN_RIGHT_TIER_TWO;
				case PHALANX_TIER_THREE:
					return PHALANX_COLUMN_RIGHT_TIER_THREE;
			}
			break;
		default:
			assert( "Unknown phalanx type \"" + phalanxType + "\"." );
	}
	
	assert( "Unknown phalanx tier \"" + tier + "\"." );
}

function private _GetPhalanxSpawner( tier )
{
	spawner = GetSpawnerArray( tier, "targetname" );
	
	assert( spawner.size >= 0,
		"No spawners for the robot phalanx system were found, make sure you include " +
		"the \"game/map_source/_prefabs/ai/robot_phalanx.map\" prefab within your " +
		"map to use the system." );
	assert( spawner.size == 1,
		"Too many spawners for the robot phalanx system were found, make sure you " +
		"don't include multiple copies of the " +
		"\"game/map_source/_prefabs/ai/robot_phalanx.map\" prefab in your map." );
	
	return spawner[0];
}

function private _HaltAdvance( robots )
{
	assert( IsArray( robots ) );
	
	foreach ( index, robot in robots )
	{
		if ( IsDefined( robot) && IsAlive( robot ) && robot HasPath() )
		{
			navMeshPosition = GetClosestPointOnNavMesh(
				robot.origin, PHALANX_NAVMESH_TOLERANCE );
				
			robot UsePosition( navMeshPosition );
			robot ClearPath();
		}
	}
}

function private _HaltFire( robots )
{
	assert( IsArray( robots ) );
	
	foreach ( index, robot in robots )
	{
		if ( IsDefined( robot) && IsAlive( robot ) )
		{
			robot.ignoreall = true;
		}
	}
}

function private _InitializeRobot( robot )
{
	assert( IsActor( robot ) );

	robot ai::set_behavior_attribute( "phalanx", true );
	robot ai::set_behavior_attribute( "move_mode", "marching" );
	robot ai::set_behavior_attribute( "force_cover", true );
	// robot.allowPain = false;
	robot SetAvoidanceMask( "avoid none" );
	
	AiUtility::AddAIOverrideDamageCallback( robot, &_DampenExplosiveDamage, true );
}

function private _MovePhalanxTier( robots, phalanxType, tier, destination, forward )
{
	positions = _GetPhalanxPositions( phalanxType, tier );
	angles = VectorToAngles( forward );
	
	assert( robots.size <= positions.size,
		"There must be enough positions for the phalanx tier to move to." );
	
	foreach ( index, robot in robots )
	{
		if ( IsDefined( robot ) && IsAlive( robot ) )
		{
			assert( IsVec( positions[ index ] ),
				"Must have a formation position for position(" + index + ") in tier " +
				tier + " of formation " + phalanxType );
			
			orientedPos = _RotateVec( positions[ index ], angles[1] - PHALANX_ROTATION_OFFSET );
		
			navMeshPosition = GetClosestPointOnNavMesh(
				destination + orientedPos, PHALANX_NAVMESH_TOLERANCE );
				
			robot UsePosition( navMeshPosition );
		}
	}
}

function private _PruneDead( robots )
{
	liveRobots = [];
	
	// Removes dead robots and keeps living ones with the same array index.
	foreach ( index, robot in robots )
	{
		if ( IsDefined( robot ) && IsAlive( robot ) )
		{
			liveRobots[ index ] = robot;
		}
	}
	
	return liveRobots;
}

function private _ReleaseRobot( robot )
{
	if ( IsDefined( robot ) && IsAlive( robot ) )
	{
		robot ClearUsePosition();
		robot PathMode( "move delayed", true, RandomFloatRange( 0.5, 1 ) );
	
		robot ai::set_behavior_attribute( "phalanx", false );
		
		// Wait a frame to make sure robot's are released from the phalanx.
		WAIT_SERVER_FRAME;
		
		robot ai::set_behavior_attribute( "move_mode", "normal" );
		robot ai::set_behavior_attribute( "force_cover", false );
		// robot.allowPain = true;
		robot SetAvoidanceMask( "avoid all" );
		
		AiUtility::RemoveAIOverrideDamageCallback( robot, &_DampenExplosiveDamage );
	}
}

function private _ReleaseRobots( robots )
{
	foreach ( index, robot in robots )
	{
		_ResumeFire( robot );
		_ReleaseRobot( robot );
		
		// Release robots slowly from their group.
		wait RandomFloatRange( 0.5, 5 );
	}
}

function private _ResumeFire( robot )
{
	if ( IsDefined( robot) && IsAlive( robot ) )
	{
		robot.ignoreall = false;
	}
}

function private _ResumeFireRobots( robots )
{
	assert( IsArray( robots ) );
	
	foreach ( index, robot in robots )
	{
		_ResumeFire( robot );
	}
}

function private _RotateVec( vector, angle )
{
	return ( vector[0] * Cos( angle ) - vector[1] * Sin( angle ),
		vector[0] * Sin( angle ) + vector[1] * Cos( angle ),
		vector[2] );
}

function private _UpdatePhalanxThread( phalanx )
{
	while ( [[ phalanx ]]->_UpdatePhalanx() )
	{
		wait PHALANX_UPDATE_RATE_SEC;
	}
}

class RobotPhalanx
{
	// Directly manage each tier of robots.
	var tier1Robots_;
	var tier2Robots_;
	var tier3Robots_;
	
	// Total starting robots in the formation.
	var startRobotCount_;
	// Current count of all robots in the formation.
	var currentRobotCount_;
	
	// Number of robots that must die for the formation to scatter.
	var breakingPoint_;
	
	// Phalanx move positions
	var startPosition_;
	var endPosition_;
	
	// Phalanx type
	var phalanxType_;
	
	// Mark whether the formation has already been scattered.
	var scattered_;

	constructor()
	{
		tier1Robots_ = [];
		tier2Robots_ = [];
		tier3Robots_ = [];
		
		startRobotCount_ = 0;
		currentRobotCount_ = 0;
		breakingPoint_ = 0;
		
		scattered_ = false;
	}
	
	destructor()
	{
	}
	
	function private _UpdatePhalanx()
	{
		if ( scattered_ )
		{
			// Terminate the phalanx if someone else has already scattered the formation.
			return false;
		}
	
		// Discard dead robots from the phalanx.
		tier1Robots_ = RobotPhalanx::_PruneDead( tier1Robots_ );
		tier2Robots_ = RobotPhalanx::_PruneDead( tier2Robots_ );
		tier3Robots_ = RobotPhalanx::_PruneDead( tier3Robots_ );
		
		currentRobotCount_ = tier1Robots_.size + tier2Robots_.size + tier2Robots_.size;
		
		// Break up the phalanx if enough robots died.
		if ( currentRobotCount_ <= ( startRobotCount_ - breakingPoint_ ) )
		{
			ScatterPhalanx();
			
			return false;
		}
		
		return true;
	}
	
	function HaltFire()
	{
		RobotPhalanx::_HaltFire( tier1Robots_ );
		RobotPhalanx::_HaltFire( tier2Robots_ );
		RobotPhalanx::_HaltFire( tier3Robots_ );
	}
	
	function HaltAdvance()
	{
		if ( !scattered_ )
		{
			RobotPhalanx::_HaltAdvance( tier1Robots_ );
			RobotPhalanx::_HaltAdvance( tier2Robots_ );
			RobotPhalanx::_HaltAdvance( tier3Robots_ );
		}
	}
	
	function Initialize(
		phalanxType,
		origin,
		destination,
		breakingPoint,
		maxTierSize = PHALANX_MAX_TIER_SIZE,
		tierOneSpawner = undefined,
		tierTwoSpawner = undefined,
		tierThreeSpawner = undefined )
	{
		assert( IsString( phalanxType ) );
		assert( IsInt( breakingPoint ) );
		assert( IsVec( origin ) );
		assert( IsVec( destination ) );
		
		maxTierSize = math::clamp( maxTierSize, PHALANX_MIN_TIER_SIZE, PHALANX_MAX_TIER_SIZE );
		
		forward = VectorNormalize( destination - origin );
	
		tier1Robots_ = RobotPhalanx::_CreatePhalanxTier(
			phalanxType, PHALANX_TIER_ONE, origin, forward, maxTierSize, tierOneSpawner );
		tier2Robots_ = RobotPhalanx::_CreatePhalanxTier(
			phalanxType, PHALANX_TIER_TWO, origin, forward, maxTierSize, tierTwoSpawner );
		tier3Robots_ = RobotPhalanx::_CreatePhalanxTier(
			phalanxType, PHALANX_TIER_THREE, origin, forward, maxTierSize, tierThreeSpawner );
		
		// The first tier facing the enemy always crouches.
		RobotPhalanx::_AssignPhalanxStance( tier1Robots_, "crouch" );
		
		// Assign phalanx positions to all robot tiers.
		RobotPhalanx::_MovePhalanxTier(
			tier1Robots_, phalanxType, PHALANX_TIER_ONE, destination, forward );
		RobotPhalanx::_MovePhalanxTier(
			tier2Robots_, phalanxType, PHALANX_TIER_TWO, destination, forward );
		RobotPhalanx::_MovePhalanxTier(
			tier3Robots_, phalanxType, PHALANX_TIER_THREE, destination, forward );
		
		startRobotCount_ = tier1Robots_.size + tier2Robots_.size + tier3Robots_.size;
		breakingPoint_ = breakingPoint;
		startPosition_ = origin;
		endPosition_ = destination;
		phalanxType_ = phalanxType;
		
		// Initiate the main update loop, a single thread that updates the phalanx.
		self thread RobotPhalanx::_UpdatePhalanxThread( self );
	}
	
	function ResumeAdvance()
	{
		if ( !scattered_ )
		{
			RobotPhalanx::_AssignPhalanxStance( tier1Robots_, "stand" );
			
			// TODO(David Young 10-21-14): Too hardcoded, waiting for animation to complete.
			wait 1;
		
			forward = VectorNormalize( endPosition_ - startPosition_ );
			
			RobotPhalanx::_MovePhalanxTier(
				tier1Robots_, phalanxType_, PHALANX_TIER_ONE, endPosition_, forward );
			RobotPhalanx::_MovePhalanxTier(
				tier2Robots_, phalanxType_, PHALANX_TIER_TWO, endPosition_, forward );
			RobotPhalanx::_MovePhalanxTier(
				tier3Robots_, phalanxType_, PHALANX_TIER_THREE, endPosition_, forward );
				
			RobotPhalanx::_AssignPhalanxStance( tier1Robots_, "crouch" );
		}
	}
	
	function ResumeFire()
	{
		RobotPhalanx::_ResumeFireRobots( tier1Robots_ );
		RobotPhalanx::_ResumeFireRobots( tier2Robots_ );
		RobotPhalanx::_ResumeFireRobots( tier3Robots_ );
	}
	
	function ScatterPhalanx()
	{
		if ( !scattered_ )
		{
			scattered_ = true;
			
			RobotPhalanx::_ReleaseRobots( tier1Robots_ );
			tier1Robots_ = [];
			
			RobotPhalanx::_AssignPhalanxStance( tier2Robots_, "crouch" );
			
			// Settling time for the tier.
			wait RandomFloatRange( 5, 7 );
			
			RobotPhalanx::_ReleaseRobots( tier2Robots_ );
			tier2Robots_ = [];
			
			RobotPhalanx::_AssignPhalanxStance( tier3Robots_, "crouch" );
			
			// Settling time for the tier.
			wait RandomFloatRange( 5, 7 );
			
			RobotPhalanx::_ReleaseRobots( tier3Robots_ );
			tier3Robots_ = [];
		}
	}
}