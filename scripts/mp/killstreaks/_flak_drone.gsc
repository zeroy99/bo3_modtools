#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_shared;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\teams\_teams;
#using scripts\shared\weapons\_heatseekingmissile;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#precache( "fx", "explosions/fx_vexp_wasp_gibb_death" );

#namespace flak_drone;
	
#define FLAK_DRONE_NAME "flak_drone"
#define FLAK_DRONE_MISSILE_TOO_CLOSE_TO_PARENT_DISTANCE		1000

function init()
{
	clientfield::register( "vehicle", "flak_drone_camo", VERSION_SHIP, 3, "int" );
	
	vehicle::add_main_callback( FLAK_DRONE_VEHICLE_NAME, &InitFlakDrone );
}

function InitFlakDrone()
{
	self.health = self.healthdefault;
	self vehicle::friendly_fire_shield();
	self EnableAimAssist();
	self SetNearGoalNotifyDist( FLAK_DRONE_NEAR_GOAL_NOTIFY_DIST );
	self SetHoverParams( FLAK_DRONE_HOVER_RADIUS, FLAK_DRONE_HOVER_SPEED, FLAK_DRONE_HOVER_ACCELERATION );
	self SetVehicleAvoidance( true );
	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0;	//+/- 55 degrees = 110 fov
	self.vehAirCraftCollisionEnabled = true;
	self.goalRadius = 999999;
	self.goalHeight = 999999;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	self thread vehicle_ai::nudge_collision();
	
	self.overrideVehicleDamage = &FlakDroneDamageOverride;
	
	self vehicle_ai::init_state_machine_for_role( "default" );
    self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &state_combat_enter;
    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
   	self vehicle_ai::get_state_callbacks( "off" ).enter_func = &state_off_enter;
   	self vehicle_ai::get_state_callbacks( "off" ).update_func = &state_off_update;
    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;
    
	self vehicle_ai::StartInitialState( "off" );
}
	
function state_off_enter( params )
{
}

function state_off_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	while( !isdefined( self.parent ) )
	{
		wait( 0.1 ); //Wait for parent to be setup
	}
	
	self.parent endon( "death" );
	
	while( true )
	{
		self SetSpeed( FLAK_DRONE_MOVE_SPEED );
		
		if( IS_TRUE( self.inpain ) )
		{
			wait( FLAK_DRONE_STUN_DURATION );
		}
		
		self ClearLookAtEnt();
		
		self.current_pathto_pos = undefined;
		
		queryOrigin = self.parent.origin + ( 0, 0, FLAK_DRONE_HOVER_HEIGHT );
		queryResult = PositionQuery_Source_Navigation( queryOrigin, 
		                                               FLAK_DRONE_HOVER_INNER_RADIUS, 
		                                               FLAK_DRONE_HOVER_OUTTER_RADIUS, 
		                                               FLAK_DRONE_HOVER_HEIGHT_VARIANCE, 
		                                               FLAK_DRONE_HOVER_POINT_SPACING, 
		                                               self );
		
		if( isdefined( queryResult ) )
		{
			PositionQuery_Filter_DistanceToGoal( queryResult, self );
			vehicle_ai::PositionQuery_Filter_OutOfGoalAnchor( queryResult );
		
			best_point = undefined;
			best_score = -999999;
		
			foreach ( point in queryResult.data )
			{
				randomScore = randomFloatRange( 0, 100 );
				distToOriginScore = point.distToOrigin2D * 0.2;
				
				point.score += randomScore + distToOriginScore;
				ADD_POINT_SCORE( point, "distToOrigin", distToOriginScore );
				
				if ( point.score > best_score )
				{
					best_score = point.score;
					best_point = point;
				}
			}
		
			self vehicle_ai::PositionQuery_DebugScores( queryResult );
		
			if( isdefined( best_point ) )
			{
				self.current_pathto_pos = best_point.origin;	
			}
		}
		
		if( IsDefined( self.current_pathto_pos ) )
		{
			self UpdateFlakDroneSpeed();
			if( self SetVehGoalPos( self.current_pathto_pos, true, false ) )
			{
				self playsound ("veh_wasp_vox");
			}
			else
			{
				self SetSpeed( FLAK_DRONE_MOVE_SPEED * 3 );
				self.current_pathto_pos = self GetClosestPointOnNavVolume( self.origin, 999999 );
				self SetVehGoalPos( self.current_pathto_pos, true, false );
			}
		}
		else
		{
			if( isDefined( self.parent.heliGoalPos ) )
			{
				self.current_pathto_pos = self.parent.heliGoalPos;
			}
			else
			{
				self.current_pathto_pos = queryOrigin;
			}
			self UpdateFlakDroneSpeed();
			self SetVehGoalPos( self.current_pathto_pos, true, false );
		}
			
		wait RandomFloatRange( FLAK_DRONE_TIME_AT_SAME_POSITION_MIN, FLAK_DRONE_TIME_AT_SAME_POSITION_MAX );
	}
}

function UpdateFlakDroneSpeed() // self == flak drone
{
	desiredSpeed = FLAK_DRONE_MOVE_SPEED;

	if ( isdefined( self.parent ) )
	{
		parentSpeed = self.parent GetSpeed();
		desiredSpeed = parentSpeed * 0.9; // lag a little back
		if ( Distance2DSquared( self.parent.origin, self.origin ) > SQR( 36 ) ) // match parent speed if too far from parent
		{
			if ( isdefined( self.current_pathto_pos ) )
			{
				flakDroneDistanceToGoalSquared = Distance2DSquared( self.origin, self.current_pathto_pos );
				parentDistanceToGoalSquared = Distance2DSquared( self.parent.origin, self.current_pathto_pos );
				if ( flakDroneDistanceToGoalSquared > parentDistanceToGoalSquared )
				{
					desiredSpeed = parentSpeed * 1.3;
				}
				else
				{
					desiredSpeed = parentSpeed * 0.8;					
				}
			}
		}
	}

	self SetSpeed( max( desiredSpeed, 10 ) );
}

function state_combat_enter( params )
{
}

function state_combat_update( params )
{
	drone = self;
	drone endon( "change_state" );
	drone endon( "death" );
	
	drone thread SpawnFlakRocket( drone.incoming_missile, drone.origin, drone.parent );
	drone Ghost();
}

function SpawnFlakRocket( missile, spawnPos, parent )
{
	drone = self;
	
	missile endon("death");
	missile Missile_SetTarget( parent );
	
	rocket = MagicBullet( GetWeapon( "flak_drone_rocket" ), spawnPos, missile.origin, parent, missile );
	rocket.team = parent.team;
	rocket setTeam( parent.team );
	rocket clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	rocket Missile_SetTarget( missile );
	missile thread CleanupAfterMissileDeath( rocket, drone ); // sometimes missile gets destroyed by the rocket
	
	curDist = Distance( missile.origin, rocket.origin ); // note: algorithm requires distance (not distance squared)

	tooCloseToPredictedParent = false;

/#
	debug_draw = GetDvarInt( "scr_flak_drone_debug_trails", 0 );
	debug_duration = GetDvarInt( "scr_flak_drone_debug_trails_duration", 20 * 20 ); // duration in number of server frames
#/

	while( true )
	{
		WAIT_SERVER_FRAME;
		
		prevDist = curDist;
		
		if ( isdefined( rocket ) )
		{
			curDist = Distance( missile.origin, rocket.origin ); // can't use DistanceSquared() here
			
			distDelta = prevDist - curDist;
			
			predictedDist = curDist - distDelta;
		}
		
/#
		if ( debug_draw && isdefined( missile ) )
			util::debug_sphere( missile.origin, 6, ( 0.9, 0, 0 ), 0.9, debug_duration ); // small red sphere for missile trail
		
		if ( debug_draw && isdefined( rocket ) )
			util::debug_sphere( rocket.origin, 6, ( 0, 0, 0.9 ), 0.9, debug_duration ); // small blue spheres for flak drone trail (as rocket)
#/

		if ( isdefined( parent ) )
		{
			parentVelocity = parent GetVelocity();
			parentPredictedLocation = parent.origin + ( parentVelocity * 0.05 );
			missileVelocity = missile GetVelocity();
			missilePredictedLocation = missile.origin + ( missileVelocity * 0.05 );
			if ( DistanceSquared( parentPredictedLocation, missilePredictedLocation ) < SQR( FLAK_DRONE_MISSILE_TOO_CLOSE_TO_PARENT_DISTANCE )
			    || DistanceSquared( parent.origin, missilePredictedLocation ) < SQR( FLAK_DRONE_MISSILE_TOO_CLOSE_TO_PARENT_DISTANCE ) )
			{
				tooCloseToPredictedParent = true;
			}
		}

		if( ( predictedDist < 0 ) || ( curDist > prevDist ) || tooCloseToPredictedParent || !isdefined( rocket ) )
		{
/#
			if ( debug_draw && isdefined( parent ) )
			{
				if ( tooCloseToPredictedParent && ! ( ( predictedDist < 0 ) || ( curDist > prevDist ) ) )
				{
					util::debug_sphere( parent.origin, 18, ( 0.9, 0, 0.9 ), 0.9, debug_duration ); // large purple sphere means too close to parent
				}
				else
				{
					util::debug_sphere( parent.origin, 18, ( 0, 0.9, 0 ), 0.9, debug_duration ); // large green sphere means intercepted
				}
			}
#/
			
			if ( isdefined( rocket ) )
			{
				rocket detonate();
			}
			missile thread heatseekingmissile::_missileDetonate( missile.target_attacker, missile.target_weapon, missile.target_weapon.explosionradius, 10, 20 );			
			return;
		}	
	}	
}

function CleanupAfterMissileDeath( rocket, flak_drone )
{
	missile = self;
	missile waittill( "death" );
	
	wait 0.5; // make sure explosions fire off before deleting
	
	if ( isdefined( rocket ) )
	{
		rocket delete();
	}
	
	if ( isdefined( flak_drone ) )
	{
		flak_drone delete();
	}
}

function state_death_update( params )
{
	self endon( "death" );
	doGibbedDeath = false;
	
	if( isdefined( self.death_info ) )
	{
		if( isdefined( self.death_info.weapon ) )
		{
			if( self.death_info.weapon.dogibbing || self.death_info.weapon.doannihilate )
			{
				doGibbedDeath = true;
			}
		}
		if( isdefined( self.death_info.meansOfDeath ) )
		{
			meansOfDeath = self.death_info.meansOfDeath;
			if( meansOfDeath == "MOD_EXPLOSIVE" || meansOfDeath == "MOD_GRENADE_SPLASH" || meansOfDeath == "MOD_PROJECTILE_SPLASH" || meansOfDeath == "MOD_PROJECTILE" )
			{
				doGibbedDeath = true;
			}
		}
	}
	
	if( doGibbedDeath )
	{
		self playsound ("veh_wasp_gibbed");
		PlayFxOnTag( "explosions/fx_vexp_wasp_gibb_death", self, "tag_origin" );
		self Ghost();
		self NotSolid();
		
		wait( 5 );
		if( isdefined( self ) )
		{
			self Delete();
		}
	}
	else
	{
		self vehicle_death::flipping_shooting_death();
	}
}

function drone_pain_for_time( time, stablizeParam, restoreLookPoint )
{
	self endon( "death" );
	
	self.painStartTime = GetTime();

	if ( !IS_TRUE( self.inpain ) )
	{
		self.inpain = true;

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

function FlakDroneDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if( sMeansOfDeath == "MOD_TRIGGER_HURT" )
		return 0;
	
	if( isdefined( eAttacker ) && isdefined( eAttacker.team ) && eAttacker.team != self.team )
	{
		drone_pain( eAttacker, sMeansOfDeath, vPoint, vDir, sHitLoc, partName );
	}

	return iDamage;
}

function Spawn( parent, onDeathCallback )
{
	if( !IsNavVolumeLoaded() )
	{
		/# IPrintLnBold( "Error: NavVolume Not Loaded" ); #/
		return undefined;
	}
	
	spawnPoint = parent.origin + FLAK_DRONE_SPAWN_OFFSET;
	
	drone = SpawnVehicle( FLAK_DRONE_VEHICLE_NAME, spawnPoint, parent.angles, "dynamic_spawn_ai" );
	drone.death_callback = onDeathCallback;
	drone configureTeam( parent, false );
	drone thread WatchGameEvents();
	drone thread WatchDeath();
	drone thread WatchParentDeath();
	drone thread WatchParentMissiles();
	return drone;
}

function configureTeam( parent, isHacked )
{
	drone = self;
	drone.team = parent.team;
	drone SetTeam( parent.team );
	if ( isHacked ) 
	{
		drone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_HACKED );
	}
	else
	{
		drone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	}
	drone.parent = parent;
	
}

function WatchGameEvents()
{
	drone = self;
	drone endon( "death" );
	
	drone.parent.owner util::waittill_any( "game_ended", "emp_jammed", "disconnect", "joined_team" );
	drone Shutdown( true );
}

function WatchDeath()
{
	drone = self;
	drone.parent endon( "death" );
	
	drone waittill( "death" );
	drone Shutdown( true );
}

function WatchParentDeath()
{
	drone = self;
	drone endon( "death" );
	
	drone.parent waittill( "death" );
	drone Shutdown( true );
}

function WatchParentMissiles()
{
	drone = self;
	drone endon( "death" );
	drone.parent endon( "death" );
	
	drone.parent waittill( "stinger_fired_at_me", missile, weapon, attacker );

	drone.incoming_missile = missile;
	drone.incoming_missile.target_weapon = weapon;
	drone.incoming_missile.target_attacker = attacker;
	drone vehicle_ai::set_state( "combat" );
}

function SetCamoState( state )
{
	self clientfield::set( "flak_drone_camo", state );
}

function Shutdown( explode )
{
	drone = self;
	
	if( isdefined( drone.death_callback ) )
	{
		drone.parent thread [[ drone.death_callback ]]();
	}
	
	if( isdefined( drone ) && !isdefined( drone.parent ) )
	{
		drone Ghost();
		drone NotSolid();
		wait( 5 );
		if( isdefined( drone ) )
			drone Delete();
	}
		
	if( isdefined( drone ) )
	{
		if( explode )
		{
			drone DoDamage( drone.health + 1000, drone.origin, drone, drone, "none", "MOD_EXPLOSIVE" );	
		}
		else
		{
			drone Delete();
		}
	}
}
