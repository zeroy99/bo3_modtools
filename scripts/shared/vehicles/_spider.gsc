#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\clientfield_shared;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;

#insert scripts\shared\version.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#insert scripts\shared\ai\utility.gsh;

#namespace spider;

#define SPIDER_MOVE_DIST_MAX 300
#define SPIDER_MOVE_DIST_MIN 80

#using_animtree( "generic" );

REGISTER_SYSTEM( "spider", &__init__, undefined )

function __init__()
{	
	vehicle::add_main_callback( "spider", &spider_initialize );
	/#
	SetDvar( "debug_spider_noswitch", 0 );
	#/
}

function NO_SWITCH_ON()
{
	return GetDvarInt( "debug_spider_noswitch", 0 ) === 1;
}

function spider_initialize()
{
	self.fovcosine = 0;
	self.fovcosinebusy = 0;
	self.delete_on_death = true;
	self.health = self.healthdefault;
	
	self UseAnimTree( #animtree );
	
	self vehicle::friendly_fire_shield();

	assert( isdefined( self.scriptbundlesettings ) );
	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	self EnableAimAssist();
	
	self SetDrawInfrared( true );
	
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();
	
	self SetNearGoalNotifyDist( 40 );
	self.goalRadius = 999999;
	self.goalHeight = 999999;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	
	self SetOnTargetAngle( 3 );
	
	self.overrideVehicleDamage = &spider_callback_damage;
	
	self thread vehicle_ai::nudge_collision();
	
	//disable some cybercom abilities
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}
	
	self ASMRequestSubstate( "locomotion@movement" );
	
	defaultRole();
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_range_combat_update;
    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;
    self vehicle_ai::get_state_callbacks( "driving" ).update_func = &state_driving_update;
    
	self vehicle_ai::add_state( "meleeCombat",
		undefined,
		&state_melee_combat_update,
		undefined );

	vehicle_ai::add_utility_connection( "combat", "meleeCombat", &should_switch_to_melee );
	vehicle_ai::add_utility_connection( "meleeCombat", "combat", &should_switch_to_range );

    self vehicle_ai::call_custom_add_state_callbacks();	
    
	vehicle_ai::StartInitialState( "combat" );
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function state_death_update( params )
{
	self endon( "death" );

	self ASMRequestSubstate( "death@stationary" );
	vehicle_ai::waittill_asm_complete( "death@stationary", 2 );

	self vehicle_death::death_fx();

	vehicle_death::DeleteWhenSafe( 10 );
}

// ----------------------------------------------
// State: driving
// ----------------------------------------------
function state_driving_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	self ASMRequestSubstate( "locomotion@aggressive" );
}

// ----------------------------------------------
// State: range combat
// ----------------------------------------------
function GetNextMovePosition_ranged( enemy )
{
	if( self.goalforced )
	{
		return self.goalpos;
	}
	
	// distance based multipliers
	selfDistToTarget = Distance2D( self.origin, enemy.origin );

	goodDist = 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax );

	tooCloseDist = 150;
	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToTarget );
	
	preferedDistAwayFromOrigin = 300;
	randomness = 30;

	// query
	queryResult = PositionQuery_Source_Navigation( self.origin, SPIDER_MOVE_DIST_MIN, SPIDER_MOVE_DIST_MAX * queryMultiplier, 0.5 * SPIDER_MOVE_DIST_MAX, 2 * self.radius * queryMultiplier, self, 1 * self.radius * queryMultiplier );

	// filter
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	PositionQuery_Filter_InClaimedLocation( queryResult, self );
	vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, enemy, self.settings.engagementDistMin, self.settings.engagementDistMax );
	
	if ( isdefined( self.avoidEntities ) && isdefined( self.avoidEntitiesDistance ) )
	{
		vehicle_ai::PositionQuery_Filter_DistAwayFromTarget( queryResult, self.avoidEntities, self.avoidEntitiesDistance, -500 );
	}

	// score points
	best_point = undefined;
	best_score = -999999;

	foreach ( point in queryResult.data )
	{
		// distance from origin
		ADD_POINT_SCORE( point, "distToOrigin", MapFloat( 0, preferedDistAwayFromOrigin, 0, 300, point.distToOrigin2D ) );

		if( point.inClaimedLocation )
		{
			ADD_POINT_SCORE( point, "inClaimedLocation", -500 );
		}

		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, randomness ) );

		ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );

		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}
	
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/# self.debug_ai_move_to_points_considered = queryResult.data; #/

	if( !isdefined( best_point ) )
	{
		return undefined;
	}

/#
	if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
	{
		recordLine( self.origin, best_point.origin, (0.3,1,0) );
		recordLine( self.origin, enemy.origin, (1,0,0.4) );
	}
#/
		
	return best_point.origin;
}

function state_range_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	self.pathfailcount = 0;
	self.foundpath = true;

	if ( params.playTransition === true )
	{
		self vehicle_ai::ClearAllMovement( true );
		self ASMRequestSubstate( "exit@aggressive" );
		self vehicle_ai::waittill_asm_complete( "exit@aggressive", 1.6 );
	}
	
	self vehicle_ai::Cooldown( "state_change", 15 ); 

	self thread prevent_stuck();
	self thread nudge_collision();
	self thread state_range_combat_attack();

	self SetSpeed( self.settings.defaultMoveSpeed );
	self ASMRequestSubstate( "locomotion@movement" );

	self.dont_move = undefined;

	for( ;; )
	{
		if ( !IsDefined( self.enemy ) )
		{
			self force_get_enemies();
			wait 0.1;
			continue;
		}
		else if ( self.dont_move === true )
		{
			wait 0.1;
			continue;
		}

		if ( IsDefined( self.can_reach_enemy ) )
		{
			if ( !self [[ self.can_reach_enemy ]]() )
			{
				wait 0.1;
				continue;
			}
		}
		
		if ( !self VehSeenRecently( self.enemy, 5 ) )
		{
			self.current_pathto_pos = spider_get_target_position();
		}
		else
		{
			self.current_pathto_pos = GetNextMovePosition_ranged( self.enemy ); 
		}

		if ( IsDefined( self.current_pathto_pos ) )
		{
			if ( self SetVehGoalPos( self.current_pathto_pos, false, true ) )
			{
				self vehicle_ai::waittill_pathing_done();
			}
		}

		WAIT_SERVER_FRAME;
	}
}

function state_range_combat_attack()
{
	self endon( "change_state" );
	self endon( "death" );

	for( ;; )
	{
		if ( !IsDefined( self.enemy ) )
		{
			wait 0.1;
			continue;
		}

		state_params = SpawnStruct();
		state_params.playTransition = true;
		self vehicle_ai::evaluate_connections( undefined, state_params );

		can_attack = true;
		foreach( player in level.players )
		{
			self GetPerfectInfo( player, false );
			if ( player.b_is_designated_target === true && self.enemy.b_is_designated_target !== true )
			{
				self GetPerfectInfo( player, true );
				self SetPersonalThreatBias( player, 100000, 2.0 );
				can_attack = false;
			}
		}

		if ( can_attack )
		{
			if ( self vehCanSee( self.enemy ) )
			{
				self SetLookAtEnt( self.enemy );
				self SetTurretTargetEnt( self.enemy );
			}

			if ( Distance2DSquared( self.origin, self.enemy.origin ) < SQR( self.settings.engagementDistMax * 1.5 ) && vehicle_ai::IsCooldownReady( "rocket" ) && self VehCanSee( self.enemy ) /*&& self.turretontarget*/ )
			{
				self do_ranged_attack( self.enemy );
				wait 0.5;
			}
		}

		wait 0.1;
	}
}

function do_ranged_attack( enemy )
{
	self notify( "near_goal" );
	self vehicle_ai::ClearAllMovement( true );
	self.dont_move = true;

	self SetLookAtEnt( enemy );
	self SetTurretTargetEnt( enemy );
	self SetVehGoalPos( enemy.origin, false, false );

	targetAngleDiff = 30;
	v_to_enemy = FLAT_ORIGIN( (enemy.origin - self.origin) );
	goalAngles = VectortoAngles( v_to_enemy );
	angleDiff = AbsAngleClamp180( self.angles[1] - goalAngles[1] );
	angleAdjustingStart = GetTime();
	while( angleDiff > targetAngleDiff && vehicle_ai::TimeSince( angleAdjustingStart ) < 0.8 )
	{
		angleDiff = AbsAngleClamp180( self.angles[1] - goalAngles[1] );
		WAIT_SERVER_FRAME;
	}

	self vehicle_ai::ClearAllMovement( true );

	if ( angleDiff <= targetAngleDiff )
	{
		self ASMRequestSubstate( "fire@stationary" );

		timedout = self util::waittill_notify_or_timeout( "spider_fire", 5 );
		if ( timedout !== true )
		{
			self FireWeapon();
			self vehicle_ai::Cooldown( "rocket", 3 ); 

			self vehicle_ai::waittill_asm_complete( "fire@stationary", 5 );
		}
	}

	self ASMRequestSubstate( "locomotion@movement" );
	self.dont_move = undefined;
}

function switch_to_melee()
{
	self.switch_to_melee = true;
}

function should_switch_to_melee( from_state, to_state, connection )
{
/#
	if ( NO_SWITCH_ON() )
	{
		return false;
	}
#/

	if ( !vehicle_ai::IsCooldownReady( "state_change" ) )
	{
		return false;
	}

	if ( !isdefined( self.enemy ) )
	{
		return false;
	}
		
	if ( self.switch_to_melee === true || 
		( Distance2DSquared( self.origin, self.enemy.origin ) < SQR( self.settings.meleedist ) && Abs( self.origin[2] - self.enemy.origin[2] ) < self.settings.meleedist ) )
	{
		return true;
	}
	
	return false;
}
// ----------------------------------------------

// ----------------------------------------------
// State: melee combat
// ----------------------------------------------
function state_melee_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	if ( params.playTransition === true )
	{
		self vehicle_ai::ClearAllMovement( true );
		self ASMRequestSubstate( "enter@aggressive" );
		self vehicle_ai::waittill_asm_complete( "enter@aggressive", 1.6 );
	}

	self vehicle_ai::Cooldown( "state_change", 8 ); 
	
	self thread prevent_stuck();
	self thread nudge_collision();
	self thread state_melee_combat_attack();

	self.pathfailcount = 0;
	self.switch_to_melee = undefined;

	self SetSpeed( self.settings.defaultMoveSpeed * 1.5 );

	self ASMRequestSubstate( "locomotion@aggressive" );

	self.dont_move = undefined;

	wait 0.5;

	for( ;; )
	{
		foreach( player in level.players )
		{
			self GetPerfectInfo( player, true );
			if ( player.b_is_designated_target === true )
			{
				self SetPersonalThreatBias( player, 100000, 3.0 );
			}
		}

		if ( !IsDefined( self.enemy ) )
		{
			self force_get_enemies();
			wait 0.1;
			continue;
		}
		else if ( self.dont_move === true )
		{
			wait 0.1;
			continue;
		}

		if ( IsDefined( self.can_reach_enemy ) )
		{
			if ( !self [[ self.can_reach_enemy ]]() )
			{
				wait 0.1;
				continue;
			}
		}

		self.foundpath = false;

		targetPos = spider_get_target_position();

		if ( isdefined( targetPos ) )
		{
			// Prevent training by not sending every raps to the same location unless they are getting close
			if( DistanceSquared( self.origin, targetPos ) > SQR( 1000 ) && self IsPosInClaimedLocation( targetPos ) )
			{	
				queryResult = PositionQuery_Source_Navigation( targetPos, 0, self.settings.max_move_dist, self.settings.max_move_dist, self.radius, self );

				PositionQuery_Filter_InClaimedLocation( queryResult, self.enemy );

				best_point = undefined;
				best_score = -999999;
				foreach ( point in queryResult.data )
				{
					ADD_POINT_SCORE( point, "distToOrigin", MapFloat( 0, 200, 0, -200, Distance( point.origin, queryResult.origin ) ) );
					ADD_POINT_SCORE( point, "heightToOrigin", MapFloat( 50, 200, 0, -200, Abs( point.origin[2] - queryResult.origin[2] ) ) );

					if( point.inClaimedLocation === true )
					{
						ADD_POINT_SCORE( point, "inClaimedLocation", -500 );
					}

					if ( point.score > best_score )
					{
						best_score = point.score;
						best_point = point;
					}
				}

				self vehicle_ai::PositionQuery_DebugScores( queryResult );

				if( isdefined( best_point ) )
				{
					targetPos = best_point.origin;
				}
			}

			self SetVehGoalPos( targetPos, false, true );
			self.foundpath = self vehicle_ai::waittill_pathresult();

			if ( self.foundpath )
			{	
				self.current_pathto_pos = targetPos;
				self thread path_update_interrupt_melee();

				self.pathfailcount = 0;

				self vehicle_ai::waittill_pathing_done();
			}
		}

		if ( !self.foundpath )
		{
			self.pathfailcount++;

			if ( self.pathfailcount > 2 )
			{
				if( IsDefined( self.enemy ) )
				{
					// Try to change enemies
					self SetPersonalThreatBias( self.enemy, -2000, 5.0 );
				}
			}

			wait 0.1;

			// just try to path strait to a nearby position on the path
			queryResult = PositionQuery_Source_Navigation( self.origin, 0, self.settings.max_move_dist, self.settings.max_move_dist, self.radius, self );

			if( queryResult.data.size )
			{
				point = queryResult.data[ randomint( queryResult.data.size ) ];

				self SetVehGoalPos( point.origin, false, false );
				self.current_pathto_pos = undefined;
				self thread path_update_interrupt_melee();
				wait 2;
				self notify( "near_goal" );				// kill the path_update_interrupt just in case
			}
		}

		wait 0.2;
	}
}

function state_melee_combat_attack()
{
	self endon( "change_state" );
	self endon( "death" );

	for( ;; )
	{
		state_params = SpawnStruct();
		state_params.playTransition = true;

		if ( !IsDefined( self.enemy ) )
		{
			wait 0.1;
			self vehicle_ai::evaluate_connections( undefined, state_params );
			continue;
		}

		self vehicle_ai::evaluate_connections( undefined, state_params );

		if ( self vehCanSee( self.enemy ) )
		{
			self SetLookAtEnt( self.enemy );
			self SetTurretTargetEnt( self.enemy );
		}

		if ( Distance2DSquared( self.origin, self.enemy.origin ) < SQR( self.settings.meleereach ) && self VehCanSee( self.enemy ) )
		{
			if ( BulletTracePassed( self.origin + (0,0,10), self.enemy.origin + (0,0,20), false, self, self.enemy, false, true ) )
			{
				self do_melee_attack( self.enemy );
				wait 0.5;
			}
		}

		wait 0.1;
	}
}

function do_melee_attack( enemy )
{
	self notify( "near_goal" );
	self vehicle_ai::ClearAllMovement( true ); // TODO: bug in quadtank movement causing it sliding and poping
	self.dont_move = true;
	self ASMRequestSubstate( "melee@stationary" );

	timedout = self util::waittill_notify_or_timeout( "spider_melee", 3 );
	if ( timedout !== true )
	{
		if ( isalive( enemy ) && Distance2DSquared( self.origin, enemy.origin ) < SQR( self.settings.meleereach * 1.2 ) )
		{
			enemy DoDamage( self.settings.meleedamage, self.origin, self, self );
		}

		self vehicle_ai::waittill_asm_complete( "melee@stationary", 2 );
	}

	self ASMRequestSubstate( "locomotion@aggressive" );
	self.dont_move = undefined;
}

function should_switch_to_range( from_state, to_state, connection )
{
/#
	if ( NO_SWITCH_ON() )
	{
		return false;
	}
#/

	if ( self.pathfailcount > 4 )
	{
		return true;
	}

	if ( !vehicle_ai::IsCooldownReady( "state_change" ) )
	{
		return false;
	}

	if ( IsAlive( self.enemy ) && Distance2DSquared( self.origin, self.enemy.origin ) > SQR( self.settings.meleedist * 4 ) )
	{
		return true;
	}

	if ( !isdefined( self.enemy ) )
	{
		return true;
	}

	return false;
}
// ----------------------------------------------

function prevent_stuck()
{
	self endon( "change_state" );
	self endon( "death" );
	self notify( "end_prevent_stuck" );
	self endon( "end_prevent_stuck" );

	wait 2;

	count = 0;
	previous_origin = undefined;

	// detonate if position hasn't change for N counts
	while( true )
	{
		if ( isdefined( previous_origin ) && DistanceSquared( previous_origin, self.origin ) < SQR( 0.1 ) && !IS_TRUE( level.bzm_worldPaused ) )
		{
			count++;
		}
		else
		{
			previous_origin = self.origin;
			count = 0;
		}

		if ( count > 10 )
		{
			self.pathfailcount = 10;
			// TODO: teleport (e.g. dig into the ground)
		}

		wait 1;
	}
}

function spider_get_target_position()
{
	if( self.goalforced )
	{
		return self.goalpos;
	}

	if( isdefined( self.settings.all_knowing ) )
	{
		if( isdefined( self.enemy ) )
		{
			target_pos = self.enemy.origin;
		}
	}
	else
	{
		target_pos = vehicle_ai::GetTargetPos( vehicle_ai::GetEnemyTarget() );
	}
	
	enemy = self.enemy;
	
	if( isdefined( target_pos ) )
	{
		target_pos_onnavmesh = GetClosestPointOnNavMesh( target_pos, self.settings.detonation_distance * 1.5, self.radius, NMMF_ALL & ~NMMF_NOVEHICLE );
	}
	
	// if we can't find a position on the navmesh then just keep going to the current position
	if( !isdefined( target_pos_onnavmesh ) )
	{
		if( isdefined( self.enemy ) )
		{
			self SetPersonalThreatBias( self.enemy, -2000, 5.0 );
		}

		if ( isdefined( self.current_pathto_pos ) && DistanceSquared( self.origin, self.current_pathto_pos ) > SQR( self.settings.meleereach ) )
		{
			return self.current_pathto_pos;
		}
		else
		{
			return undefined;
		}
	}
	else if ( isdefined( self.enemy ) )
	{
		if ( DistanceSquared( target_pos, target_pos_onnavmesh ) > SQR( self.settings.detonation_distance * 0.9 ) )
		{
			self SetPersonalThreatBias( self.enemy, -2000, 5.0 );
		}
	}
	
	if( isdefined( enemy ) && IsPlayer( enemy ) )
	{
		enemy_vel_offset = enemy GetVelocity() * 0.5;
		
		enemy_look_dir_offset = AnglesToForward( enemy.angles );
		if( distance2dSquared( self.origin, enemy.origin ) > SQR( 500 ) )
		{
			enemy_look_dir_offset *= 110;
		}
		else
		{
			enemy_look_dir_offset *= 35;
		}
		
		offset = enemy_vel_offset + enemy_look_dir_offset;
		offset = FLAT_ORIGIN( offset );	// just 2d
		
		if( TracePassedOnNavMesh( target_pos_onnavmesh, target_pos + offset ) )
		{
			target_pos += offset;
		}
		else
		{
			target_pos = target_pos_onnavmesh;
		}
	}
	else
	{
		target_pos = target_pos_onnavmesh;
	}
	
	return target_pos;
}

function path_update_interrupt_melee()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );
	
	//ensure only one path_update_interrupt is running
	self notify( "clear_interrupt_threads" );
	self endon( "clear_interrupt_threads" );

	wait .1; 	// sometimes endons may get fired off so wait a bit for the goal to get updated
	
	while( 1 )
	{	
		if( isdefined( self.current_pathto_pos ) )
		{
			if( distance2dSquared( self.current_pathto_pos, self.goalpos ) > SQR( self.goalRadius ) )
			{
				wait 0.5;
				
				self notify( "near_goal" );
			}

			targetPos = spider_get_target_position();
			if ( isdefined( targetPos ) )
			{
				// optimization, don't keep repathing as often when far away
				if( DistanceSquared( self.origin, targetPos ) > SQR( 1000 ) )
				{
					repath_range = self.settings.repath_range * 2;
					wait 0.1;
				}
				else
				{
					repath_range = self.settings.repath_range;
				}
				   
				if( distance2dSquared( self.current_pathto_pos, targetPos ) > SQR( repath_range ) )
				{
					self notify( "near_goal" );
				}
			}
			
			if( isdefined( self.enemy ) && IsPlayer( self.enemy ) )
			{
				forward = AnglesToForward( self.enemy GetPlayerAngles() );
				dir_to_raps = self.origin - self.enemy.origin;
				
				speedToUse = self.settings.defaultMoveSpeed * 2;
				if( VectorDot( forward, dir_to_raps ) > 0 )
				{
					self SetSpeed( speedToUse );
				}
				else
				{
					self SetSpeed( speedToUse * 0.75 );
				}
			}
			else
			{
				speedToUse = self.settings.defaultMoveSpeed * 2;
				self SetSpeed( speedToUse );
			}
			
			wait 0.2;
		}
		else
		{
			wait 0.4;
		}
	}
}

function nudge_collision()
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "end_nudge_collision" );
	self endon( "end_nudge_collision" );

	while ( 1 )
	{
		self waittill( "veh_collision", velocity, normal );
		ang_vel = self GetAngularVelocity() * 0.8;
		self SetAngularVelocity( ang_vel );
		
		// bounce off walls
		if ( IsAlive( self ) && VectorDot( normal, (0,0,1) ) < 0.5 ) // angle is more than 60 degree away from up direction
		{
			self SetVehVelocity( self.velocity + normal * 400 );
		}
	}
}


function force_get_enemies()
{
	foreach( player in level.players )
	{
		if( self util::IsEnemyPlayer( player ) && !player.ignoreme )
		{
			self GetPerfectInfo( player, true );
			return;
		}
	}
}

function spider_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if ( IsAlive( eAttacker ) && eAttacker.team === self.team )
	{
		return 0;
	}

	return iDamage;
}
