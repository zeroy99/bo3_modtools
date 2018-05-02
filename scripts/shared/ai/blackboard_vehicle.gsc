#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;

#namespace Blackboard;

//*****************************************************************************
// NOTE! When adding a new blackboard variable you must also declare the 
// blackboard variable within the ast_definitions file found at:
//
// //t7/main/game/share/raw/animtables/ast_definitions.json
//
// This allows the Animation Selector Table system to determine how to create
// queries based on the blackboard variable.
//
// Also, all blackboard values must be lowercased! No convert to lower is
// perform when assigning values to the blackboard.
//
//*****************************************************************************
function RegisterVehicleBlackBoardAttributes()
{	
	Assert(IsVehicle(self), "RegisterVehicleBlackBoardAttributes: Should only be called on vehicles");
	
	BB_REGISTER_ATTRIBUTE( SPEED, 		undefined,	&BB_GetSpeed );
	BB_REGISTER_ATTRIBUTE( ENEMY_YAW,	undefined,	&BB_VehGetEnemyYaw );
}

function BB_GetSpeed()
{
	velocity = self GetVelocity();
	return Length( velocity );
}

#define DEFAULT_ENEMY_YAW 0
function BB_VehGetEnemyYaw()
{	
	enemy = self.enemy;
	
	if( !IsDefined( enemy ) )
		return DEFAULT_ENEMY_YAW;
	
	toEnemyYaw = VehGetPredictedYawToEnemy( self, 0.2 );

	return toEnemyYaw;
}

function VehGetPredictedYawToEnemy( entity, lookAheadTime )
{
	// don't run this more than once per frame
	if( IsDefined(entity.predictedYawToEnemy) && IsDefined(entity.predictedYawToEnemyTime) && entity.predictedYawToEnemyTime == GetTime() )
		return entity.predictedYawToEnemy;

	selfPredictedPos = entity.origin;
	moveAngle = entity.angles[1] + entity getMotionAngle();
	selfPredictedPos += (cos( moveAngle ), sin( moveAngle ), 0) * 200.0 * lookAheadTime;

	yaw = VectorToAngles(entity.enemy.origin - selfPredictedPos)[1] - entity.angles[1];
	yaw = AbsAngleClamp360( yaw );
	
	// cache
	entity.predictedYawToEnemy = yaw;
	entity.predictedYawToEnemyTime = GetTime();
	
	return yaw;
}