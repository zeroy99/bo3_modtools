#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#using scripts\shared\ai\systems\ai_interface;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#using scripts\shared\ai\zombie_utility;

#define PARASITE_RADIUS									20

#define PARASITE_MAX_TIME_AT_SAME_POSITION				1.0
#define PARASITE_CHANGE_POSITION_TOATTACK_TARGET_DELAY	0.5

#define PARASITE_AWAY_FROM_CHARACTER					300

#define PARASITE_ENEMY_TOO_CLOSE_DIST					250
	
//reduce these defines to have the parasite make more movements close together
#define PARASITE_TOO_CLOSE_TO_SELF_DIST				    75	
#define PARASITE_MOVE_DIST_MAX							225
#define PARASITE_JUKE_MOVE_DIST_MAX						300

#define PARASITE_REPATH_RANGE							100
	
#define PARASITE_FIRE_CHANCE							30
#define PARASITE_MELEE_CHANCE							50
#define	PARASITE_MELEE_DIST								64
	
#namespace parasite;
	
REGISTER_SYSTEM( "parasite", &__init__, undefined )

#using_animtree( "generic" );	
	
function __init__()
{	
	vehicle::add_main_callback( "parasite", &parasite_initialize );
	
	clientfield::register( "vehicle", "parasite_tell_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "parasite_secondary_deathfx", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "parasite_damage", VERSION_SHIP, 1, "counter" );
	
	callback::on_spawned( &parasite_damage );
	
	ai::RegisterMatchedInterface(
		"parasite",
		"firing_rate",
		"slow",
		array( "slow", "medium", "fast" ) );
}

function parasite_damage()
{
	self notify( "parasite_damage_thread" );
	self endon( "parasite_damage_thread" );
	
	self endon( "death" );
	
	while ( true )
	{
		self waittill( "damage", n_ammount, e_attacker );
		
		if ( IsDefined( e_attacker ) && IS_TRUE( e_attacker.is_parasite ) && !IS_TRUE(e_attacker.squelch_damage_overlay) )
		{
			self clientfield::increment_to_player( "parasite_damage" );
		}
	}
}

function private is_target_valid( target )
{
	if( !IsDefined( target ) ) 
	{
		return false; 
	}

	if( !IsAlive( target ) )
	{
		return false; 
	} 
	
	if( IsPlayer( target ) && target.sessionstate == "spectator" )
	{
		return false; 
	}

	if( IsPlayer( target ) && target.sessionstate == "intermission" )
	{
		return false; 
	}
	
	if( IS_TRUE( target.ignoreme ) )
	{
		return false;
	}

	if( target IsNoTarget() )
	{
		return false;
	}

	if( IsDefined( self.is_target_valid_cb ) )
	{
		return self [[ self.is_target_valid_cb ]]( target );
	}
	
	return true; 
}

function get_parasite_enemy()
{
	parasite_targets = GetPlayers();
	least_hunted = parasite_targets[0];
	for( i = 0; i < parasite_targets.size; i++ )
	{
		if ( !isdefined( parasite_targets[i].hunted_by ) )
		{
			parasite_targets[i].hunted_by = 0;
		}

		if( !is_target_valid( parasite_targets[i] ) )
		{
			continue;
		}

		if( !is_target_valid( least_hunted ) )
		{
			least_hunted = parasite_targets[i];
		}
			
		if( parasite_targets[i].hunted_by < least_hunted.hunted_by )
		{
			least_hunted = parasite_targets[i];
		}

	}
	// do not return the default first player if he is invalid
	if( !is_target_valid( least_hunted ) )
	{
		return undefined;
	}
	else
	{
		return least_hunted;
	}
}

function set_parasite_enemy( enemy )
{
	if( !is_target_valid( enemy ) )
	{
		return;
	}
	
	if( IsDefined( self.parasiteEnemy ) )
	{
		if( !IsDefined( self.parasiteEnemy.hunted_by ) )
		{
			self.parasiteEnemy.hunted_by = 0;
		}
		if( self.parasiteEnemy.hunted_by > 0 )
		{
			self.parasiteEnemy.hunted_by--;
		}
	}
	
	self.parasiteEnemy = enemy;
	if( !IsDefined( self.parasiteEnemy.hunted_by ) )
	{
		self.parasiteEnemy.hunted_by = 0;
	}
	self.parasiteEnemy.hunted_by++;
	self SetLookAtEnt( self.parasiteEnemy );
	self SetTurretTargetEnt( self.parasiteEnemy );
}

function private parasite_target_selection()
{
	self endon( "change_state" );
	self endon( "death" );
	
	for( ;; )
	{
		if ( IS_TRUE( self.ignoreall ) )
		{
			wait 0.5;
			continue;
		}
		
		if( is_target_valid( self.parasiteEnemy ) )
		{
			wait 0.5;
			continue;
		}
		//decide who the enemy should be
		target = get_parasite_enemy();

		if( !isDefined( target ) )
		{
			self.parasiteEnemy = undefined;		
		}
		else
		{
			self.parasiteEnemy = target;
			//update hunted_by
			self.parasiteEnemy.hunted_by += 1;
			self SetLookAtEnt( self.parasiteEnemy );
			self SetTurretTargetEnt( self.parasiteEnemy );
		}

		wait 0.5;
	}
}

function parasite_initialize()
{
	self useanimtree( #animtree );
	
	// AI SPECIFIC INITIALIZATION
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();
	ai::CreateInterfaceForEntity( self );
	
	BB_REGISTER_ATTRIBUTE( PARASITE_FIRING_RATE, "slow", &getParasiteFiringRate );

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	self EnableAimAssist();
	self SetNearGoalNotifyDist( 25 );
	
	self SetDrawInfrared( true );
	
	self.fovcosine = 0;
	self.fovcosinebusy = 0;

	self.vehAirCraftCollisionEnabled = true;

	assert( isdefined( self.scriptbundlesettings ) );

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	self.goalRadius = 999999;
	self.goalHeight = 4000;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	
	self.is_parasite = true;

	self thread vehicle_ai::nudge_collision();
	
	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}
	
	defaultRole();
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &state_combat_enter;
    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;

    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;
    
    self vehicle_ai::call_custom_add_state_callbacks();
    
	vehicle_ai::StartInitialState( "combat" );
}

// ----------------------------------------------
//BB getter functions
// ----------------------------------------------
function getParasiteFiringRate()
{
	return self ai::get_behavior_attribute( "firing_rate" );
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function state_death_update( params )
{
	self endon( "death" );
	
	self ASMRequestSubstate( "death@stationary" );
	
	if( IsDefined( self.parasiteEnemy ) && IsDefined( self.parasiteEnemy.hunted_by ) )
	{
		self.parasiteEnemy.hunted_by--;
	}
	   	
	self SetPhysAcceleration( ( 0, 0, -300 ) );
	self.vehcheckforpredictedcrash = true;
	
	self thread vehicle_death::death_fx();
	self playsound( "zmb_parasite_explo" );
	
	self util::waittill_notify_or_timeout( "veh_predictedcollision", 4.0 );
	
	self clientfield::set( "parasite_secondary_deathfx", 1 );
	
	//make sure the client gets a chance to play the second fx before deleting
	wait 0.2;
	
	self Delete();
}

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_enter( params )
{
	if ( IsDefined( self.owner ) && IsDefined( self.owner.enemy ) )
	{
		self.parasiteEnemy = self.owner.enemy;
	}
	self thread parasite_target_selection();
}

function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	lastTimeChangePosition = 0;
	self.shouldGotoNewPosition = false;
	self.lastTimeTargetInSight = 0;
	self.lastTimeJuked = false;
	
	//request movement animations
	self ASMRequestSubstate( "locomotion@movement" );
	
	for( ;; )
	{
		if( IsDefined( self._override_parasite_combat_speed ) )
		{
			self SetSpeed( self._override_parasite_combat_speed );
		}
		else
		{
			self SetSpeed( self.settings.defaultMoveSpeed );
		}
		
		if ( IS_TRUE( self.inpain ) )
		{
			wait 0.1;
		}
		else if ( !IsDefined( self.parasiteEnemy ) )
		{
			//no enemy, do nothing
			wait( 0.25 );
		}
		else
		{
			if( self.goalforced )
			{
				returnData = [];
				returnData[ "origin" ] = self GetClosestPointOnNavVolume( self.goalpos, 100 );
				returnData[ "centerOnNav" ] = IsPointInNavVolume( self.origin, "navvolume_small" );
			}
			//prevent two consecutive forward jukes, and force juke if path was interrupted ( possibly due to collision )
			else if( ( RandomInt( 100 ) < self.settings.jukeprobability && !IS_TRUE( self.lastTimeJuked ) ) || IS_TRUE( self._override_juke ) )
			{
				returnData = GetNextMovePosition_forwardjuke();
				self.lastTimeJuked = true;
				self._override_juke = undefined;
			}
			else
			{
				returnData = GetNextMovePosition_tactical();
				self.lastTimeJuked = false;
			}
			self.current_pathto_pos = returnData[ "origin" ];
			if ( IsDefined( self.current_pathto_pos ) )
			{
				if( IsDefined( self.stuckTime ) )
				{
					self.stuckTime = undefined;
				}
				if ( self SetVehGoalPos( self.current_pathto_pos, true, returnData[ "centerOnNav" ] ) )
				{
					self thread path_update_interrupt();
					
					//AUDIO: Was on JUST the juke, but I've moved it for any movement to make it more interesting
					self playsound( "zmb_vocals_parasite_juke" );
					
					self vehicle_ai::waittill_pathing_done( 5 );
				}
				else
				{
					//failsafe, cannot pathfind
					wait( 0.1 );
				}
			}
			else
			{
				if( !IS_TRUE( returnData[ "centerOnNav" ] ) )
				{
					//not on navmesh, no valid goto points, kill parasite as failsafe
					if( !IsDefined( self.stuckTime ) )
					{
						self.stuckTime = GetTime();
					}
					if( GetTime() - self.stuckTime > 10000 )
					{
						self DoDamage( self.health + 100, self.origin );
					}
				}
			}
			
			if( IS_TRUE( self.lastTimeJuked ) )
			{
				if( RandomInt( 100 ) < PARASITE_MELEE_CHANCE && IsDefined( self.parasiteEnemy ) && Distance2DSquared( self.origin, self.parasiteEnemy.origin ) < SQR( PARASITE_MELEE_DIST ) )
				{
					//parasite melee bite
					self.parasiteEnemy DoDamage( self.settings.meleedamage, self.parasiteEnemy.origin, self );
				}
				else
				{
					self fire_pod_logic( self.lastTimeJuked );
				}
			}
			else
			{
				if( RandomInt( 100 ) < PARASITE_FIRE_CHANCE )
				{
					self fire_pod_logic( self.lastTimeJuked );
				}
			}
		}
	}
}

function fire_pod_logic( choseToJuke )
{
	if( IsDefined( self.parasiteEnemy ) && self VehCanSee( self.parasiteEnemy ) && Distance2DSquared( self.parasiteEnemy.origin, self.origin ) < SQR( 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax ) * 3 ) )
	{	
		//switch to fire animation
		self ASMRequestSubstate( "fire@stationary" );
		
		//do the tell		
		self PlaySound( "zmb_vocals_parasite_preattack" );
		self clientfield::set( "parasite_tell_fx", 1 );		
		
		//reached the point in the animation to adjust the turret
		self waittill( "pre_fire" );
		
		if( IsDefined( self.parasiteEnemy ) && self VehCanSee( self.parasiteEnemy ) && Distance2DSquared( self.parasiteEnemy.origin, self.origin ) < SQR( 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax ) * 3 ) )
		{
			//fire the projectile at the predicted player position
			self SetTurretTargetEnt( self.parasiteEnemy, self.parasiteEnemy GetVelocity() * 0.3 );
		}
		
		self vehicle_ai::waittill_asm_complete( "fire@stationary", 5 );
		
		//switch back to locomotion
		self ASMRequestSubstate( "locomotion@movement" );
		
		//cleanup the fx
		self clientfield::set( "parasite_tell_fx", 0 );
		
		if( !choseToJuke )
		{
			wait RandomFloatRange( 0.25, 0.5 );
		}
	}
	else
	{
		wait RandomFloatRange( 1, 2 );
	}
}

function GetNextMovePosition_tactical() // has self.parasiteEnemy
{
	self endon( "change_state" );
	self endon( "death" );
	
	// distance based multipliers
	selfDistToTarget = Distance2D( self.origin, self.parasiteEnemy.origin );

	goodDist = 0.5 * ( self.settings.engagementDistMin + self.settings.engagementDistMax );

	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToTarget );
	
	//the preferred height range should be half the max possible difference to not exceed valid heights for points near the goalheight
	preferedHeightRange = 0.5 * ( self.settings.engagementHeightMax - self.settings.engagementHeightMin );
	randomness = 30;

	// query
	queryResult = PositionQuery_Source_Navigation( self.origin, PARASITE_TOO_CLOSE_TO_SELF_DIST, PARASITE_MOVE_DIST_MAX * queryMultiplier, 75, PARASITE_RADIUS * queryMultiplier, self, PARASITE_RADIUS * queryMultiplier );
	//turn off collision, we are not on the navvolume
	if( !IS_TRUE( queryResult.centerOnNav ) )
	{
		self.vehAirCraftCollisionEnabled = false;
	}
	else
	{
		self.vehAirCraftCollisionEnabled = true;
	}
	// filter
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	self vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, self.parasiteEnemy, self.settings.engagementDistMin, self.settings.engagementDistMax );

	goalHeight = self.parasiteEnemy.origin[2] + 0.5 * ( self.settings.engagementHeightMin + self.settings.engagementHeightMax );	
	
	// score points
	best_point = undefined;
	best_score = -999999;
	trace_count = 0;
	foreach ( point in queryResult.data )
	{
		if( !IS_TRUE( queryResult.centerOnNav ) )
		{
			if( SightTracePassed( self.origin, point.origin, false, undefined ) )
			{
				trace_count++;
				if( trace_count > 3 )
				{
					WAIT_SERVER_FRAME;
					trace_count = 0;
				}
				if( !BulletTracePassed( self.origin, point.origin, false, self ) )
				{
					continue;
				}
			}
			else
			{
				continue;
			}
		}
		
		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, randomness ) );

		ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );
		
		// height
		distFromPreferredHeight = abs( point.origin[2] - goalHeight );
		if ( distFromPreferredHeight > preferedHeightRange )
		{
			heightScore = MapFloat( 0, 500, 0, 2000, distFromPreferredHeight );
			ADD_POINT_SCORE( point, "height", -heightScore );
		}
		
		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/#
	if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
	{
		recordLine( self.origin, best_point.origin, (0.3,1,0) );
		recordLine( self.origin, self.parasiteEnemy.origin, (1,0,0.4) );
	}
#/
	returnData = [];
	returnData[ "origin" ] = ( ( IsDefined( best_point ) ) ? best_point.origin : undefined );
	returnData[ "centerOnNav" ] = queryResult.centerOnNav;
	return returnData;
}


function GetNextMovePosition_forwardjuke() // has self.parasiteEnemy
{
	self endon( "change_state" );
	self endon( "death" );
	
	// distance based multipliers
	selfDistToTarget = Distance2D( self.origin, self.parasiteEnemy.origin );
	
	goodDist = 0.5 * ( self.settings.forwardJukeEngagementDistMin + self.settings.forwardJukeEngagementDistMax );

	closeDist = 1.2 * goodDist;
	farDist = 3 * goodDist;

	queryMultiplier = MapFloat( closeDist, farDist, 1, 3, selfDistToTarget );
	
	preferedHeightRange = 0.5 * ( self.settings.forwardJukeEngagementHeightMax - self.settings.forwardJukeEngagementHeightMin );
	randomness = 30;

	// query
	queryResult = PositionQuery_Source_Navigation( self.origin, PARASITE_TOO_CLOSE_TO_SELF_DIST, PARASITE_JUKE_MOVE_DIST_MAX * queryMultiplier, 75, PARASITE_RADIUS * queryMultiplier, self, PARASITE_RADIUS * queryMultiplier );
	if( !IS_TRUE( queryResult.centerOnNav ) )
	{
		self.vehAirCraftCollisionEnabled = false;
	}
	else
	{
		self.vehAirCraftCollisionEnabled = true;
	}
	// filter
	PositionQuery_Filter_DistanceToGoal( queryResult, self );
	vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
	self vehicle_ai::PositionQuery_Filter_EngagementDist( queryResult, self.parasiteEnemy, self.settings.forwardJukeEngagementDistMin, self.settings.forwardJukeEngagementDistMax );

	goalHeight = self.parasiteEnemy.origin[2] + 0.5 * ( self.settings.forwardJukeEngagementHeightMin + self.settings.forwardJukeEngagementHeightMax );	
	
	// score points
	best_point = undefined;
	best_score = -999999;
	trace_count = 0;
	
	foreach ( point in queryResult.data )
	{
		if( !IS_TRUE( queryResult.centerOnNav ) )
		{
			if( SightTracePassed( self.origin, point.origin, false, undefined ) )
			{
				trace_count++;
				if( trace_count > 3 )
				{
					WAIT_SERVER_FRAME;
					trace_count = 0;
				}
				if( !BulletTracePassed( self.origin, point.origin, false, self ) )
				{
					continue;
				}
			}
			else
			{
				continue;
			}
		}
		
		ADD_POINT_SCORE( point, "random", randomFloatRange( 0, randomness ) );
		
		ADD_POINT_SCORE( point, "engagementDist", -point.distAwayFromEngagementArea );
		
		// height
		distFromPreferredHeight = abs( point.origin[2] - goalHeight );
		if ( distFromPreferredHeight > preferedHeightRange )
		{
			heightScore = MapFloat( 0, 500, 0, 2000, distFromPreferredHeight );
			ADD_POINT_SCORE( point, "height", -heightScore );
		}
		
		if ( point.score > best_score )
		{
			best_score = point.score;
			best_point = point;
		}
	}
	self vehicle_ai::PositionQuery_DebugScores( queryResult );

	/#
	if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
	{
		recordLine( self.origin, best_point.origin, (0.3,1,0) );
		recordLine( self.origin, self.parasiteEnemy.origin, (1,0,0.4) );
	}
#/
	
	returnData = [];
	returnData[ "origin" ] = ( ( IsDefined( best_point ) ) ? best_point.origin : undefined );
	returnData[ "centerOnNav" ] = queryResult.centerOnNav;
	return returnData;
}

function path_update_interrupt()
{
	self endon( "death" );
	self endon( "change_state" );
	self endon( "near_goal" );
	self endon( "reached_end_node" );

	wait 1;
	
	while( 1 )
	{
		if( isdefined( self.current_pathto_pos ) )
		{
			if( distance2dSquared( self.current_pathto_pos, self.goalpos ) > SQR( self.goalradius ) )
			{
				wait 0.2;
				self._override_juke = true;
				self notify( "near_goal" );
			}
		}
		wait 0.2;
	}
}


// ----------------------------------------------
// pain/hit reaction
// ----------------------------------------------
function drone_pain_for_time( time, stablizeParam, restoreLookPoint )
{
	self endon( "death" );
	
	self.painStartTime = GetTime();

	if ( !IS_TRUE( self.inpain ) )
	{
		self.inpain = true;
		
		self PlaySound( "zmb_vocals_parasite_pain" );

		while ( GetTime() < self.painStartTime + time * 1000 )
		{
			self SetVehVelocity( self.velocity * stablizeParam );
			self SetAngularVelocity( self GetAngularVelocity() * stablizeParam );
			wait 0.1;
		}

		if ( isdefined( restoreLookPoint ) )
		{
			restoreLookEnt = Spawn( "script_model", restoreLookPoint );
			restoreLookEnt SetModel( "tag_origin" );

			self ClearLookAtEnt();
			self SetLookAtEnt( restoreLookEnt );
			self setTurretTargetEnt( restoreLookEnt );
			wait 1.5;

			self ClearLookAtEnt();
			self ClearTurretTarget();
			restoreLookEnt delete();
		}

		self.inpain = false;
	}
}

function drone_pain( eAttacker, damageType, hitPoint, hitDirection, hitLocationInfo, partName )
{
	if ( !IS_TRUE( self.inpain ) )
	{
		yaw_vel = math::randomSign() * RandomFloatRange( 280, 320 );

		ang_vel = self GetAngularVelocity();
		ang_vel += ( RandomFloatRange( -120, -100 ), yaw_vel, RandomFloatRange( -200, 200 ) );
		self SetAngularVelocity( ang_vel );

		self thread drone_pain_for_time( 0.8, 0.7 );
	}
}