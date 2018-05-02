#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;

#insert scripts\shared\ai\utility.gsh;

#define PROTOTYPE_SCOUT_HP_MOD					1
#define SCOUT_DEFAULT_RADIUS_FOR_DEFEND_ROLE	64
#define SCOUT_DEFAULT_RADIUS_FOR_GUARD_ROLE		64
#define SCOUT_DEFAULT_RADIUS_FOR_LOITER_ROLE	64
#define SCOUT_TRACK_DISTANCE					256 // distance that the scout tries to stay from the player while tracking it
#define SCOUT_DEFEND_HEIGHT						300
#define SCOUT_LOITER_HEIGHT						300
#define SCOUT_PATROL_HEIGHT						300
#define SCOUT_TRACK_HEIGHT						128
#define SCOUT_TRACK_TETHER						512
#define SCOUT_BASE_SPEED_MODIFIER				0.33

#precache( "fx", "_t6/destructibles/fx_quadrotor_crash01" );

#namespace scout_drone;

REGISTER_SYSTEM( "scout_drone", &__init__, undefined )

function __init__()
{
	vehicle::add_main_callback( "scout", &scout_drone_initialize );

	level._effect[ "quadrotor_crash" ]		= "_t6/destructibles/fx_quadrotor_crash01";
}

function scout_drone_initialize()
{
	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	self EnableAimAssist();
	self SetHoverParams( 25.0, 120.0, 80 );
	self SetNearGoalNotifyDist( 40 );

	self.flyheight = GetDvarFloat( "g_quadrotorFlyHeight" );

	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0.574;	//+/- 55 degrees = 110 fov

	self.vehAirCraftCollisionEnabled = true;

	self.original_vehicle_type = self.vehicletype;

	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	self.overrideVehicleDamage = &scout_callback_damage;

	self thread vehicle_ai::nudge_collision();

	self.goalpos = self.origin;
	self.goalradius = 40;
	
	// for testing
	patrol( undefined );
}

function defend( s_centerpoint, n_radius )
{
	Assert( false, "defend is not implemented for scout" );
}

function guard( v_centerpoint )
{
	Assert( false, "guard is not implemented for scout" );
}

function loiter( v_center, n_radius )
{
	Assert( false, "loiter is not implemented for scout" );
}

function patrol( start_node )
{
	self vehicle_ai::init_state_machine_for_role( "patrol" );

    self vehicle_ai::get_state_callbacks( "patrol", "unaware" ).enter_func = &state_unaware_enter;
    self vehicle_ai::get_state_callbacks( "patrol", "unaware" ).update_func = &state_unaware_update;
    self vehicle_ai::get_state_callbacks( "patrol", "low_alert" ).enter_func = &state_lowalert_enter;
    self vehicle_ai::get_state_callbacks( "patrol", "low_alert" ).update_func = &state_alert_update;
    self vehicle_ai::get_state_callbacks( "patrol", "high_alert" ).enter_func = &state_highalert_enter;
    self vehicle_ai::get_state_callbacks( "patrol", "high_alert" ).update_func = &state_alert_update;
    self vehicle_ai::get_state_callbacks( "patrol", "combat" ).enter_func = &state_combat_enter;
    self vehicle_ai::get_state_callbacks( "patrol", "combat" ).update_func = &state_combat_update;

    self vehicle_ai::get_state_callbacks( "patrol", "death" ).update_func = &vehicle_death::flipping_shooting_death;

	self vehicle_ai::set_role( "patrol" );

	set_patrol_path( start_node );
	self vehicle_ai::set_state( "unaware" );
}

// ----------------------------------------------
// State: unaware
// ----------------------------------------------
function set_patrol_path( patrol_path_start_node )
{
	self.patrol_path = patrol_path_start_node;
}

function state_unaware_enter()
{
	baseSpeed = 7;
	randomHalfRange = 2;
	self SetSpeed( RandomFloatRange( baseSpeed - randomHalfRange, baseSpeed + randomHalfRange ) );

/#	println( "^1WARNING: No patrol path defined, taking the nearest one" );	#/

	searchRadius = 256;
	while ( !isdefined( self.patrol_path ) )
	{
		searchRadius = searchRadius * 2;
		nodes = GetNodesInRadius( self.origin, searchRadius, 0, searchRadius, "Path", 1 );

		if ( nodes.size > 0 )
		{
			self.patrol_path = nodes[ 0 ];
		}
		wait 0.02;
	}
}

function state_unaware_update() // follow a path
{
	self endon( "change_state" );
	self endon( "death" );

	for( ;; )
	{
		// follow the .target kvp on the struct path		
		if ( isdefined( self.patrol_path ) )
		{
			nd_current = self.patrol_path;
			nd_first = nd_current; // save off the first node, so we know when we've made a full circuit

			v_height_offset = SCOUT_PATROL_HEIGHT;
			if ( isdefined( nd_current.script_height ) ) // designer can override patrol height on pathnode
			{
				v_height_offset = nd_current.script_height;
			}

			self SetVehGoalPos( nd_current.origin + ( 0, 0, v_height_offset ), 0, 2 );
			self vehicle_ai::waittill_pathing_done();
			self ClearVehGoalPos();
			nd_current util::script_wait();
			
			nd_detour_entry = undefined; // this will be used in the loop below for keeping track of when we get back from a detour
			b_currently_on_detour = false; // track whether we're on a detour or not
		
			while( isdefined( nd_current.target ) )
			{
				//CreateDynEntAndLaunch( self.model, self.origin, self.angles, self.origin, (0,0,100), level._effect[ "quadrotor_crash" ] );

				if ( nd_current == nd_first )
				{
					a_explored_sidepaths = []; // this array will hold nodes for detours and POIs that we have already explored; if we've made a full circuit, reset this
				}
			
				// check if we're back from a detour
				if ( isdefined( nd_detour_entry ) && ( nd_current == nd_detour_entry ) )
				{
					nd_detour_entry = undefined;
					b_currently_on_detour = false;
				}
	
				// save off nd_previous before updating nd_current
				nd_previous = nd_current;
	
				// get target nodes so we can start choosing the next nd_current			
				a_nodes = GetNodeArray( nd_current.target, "targetname" );
				
				// remove any already-explored nodes from consideration ( in-case we're coming back from a detour or POI )
				for( i = 0; i < a_nodes.size; i++ )
				{
					node = a_nodes[i];
				
					if ( isinarray( a_explored_sidepaths, node ) )
					{
						ArrayRemoveValue( a_nodes, node ); // remove any already-explored nodes 
						i = 0; // restart
					}
				}
			
				// assign a random node (even chances)
				nd_current = RANDOM( a_nodes );
	
				if ( isdefined( nd_current.script_string ) )
				{
					// if the node we're traveling to is a detour, add it to the explored nodes array
					if ( nd_current.script_string == "detour" )
					{
						ArrayInsert( a_explored_sidepaths, nd_current, 0 );
						nd_detour_entry = nd_previous;
						b_currently_on_detour = true;
					}
					// if the node we're traveling to is a detour, add it to the explored nodes array AND set it as the look ent
					else if ( nd_current.script_string == "poi" ) 
					{
						ArrayInsert( a_explored_sidepaths, nd_current, 0 );
						nd_detour_entry = nd_previous;
						b_currently_on_detour = true;
						//self SetLookAtEnt( nd_current );
					}
				}
	
				/*
				if ( b_currently_on_detour )
				{
					IPrintLn( "ON DETOUR" );
				}
				else
				{
					IPrintLn( "NOT ON DETOUR" );
				}
				*/
			
				// go to the node
				v_height_offset = SCOUT_PATROL_HEIGHT;
				if ( isdefined( nd_current.script_height ) ) // designer can override patrol height on pathnode
				{
					v_height_offset = nd_current.script_height;
				}
				self SetVehGoalPos( nd_current.origin + ( 0, 0, v_height_offset ), 0, 2 );
				self vehicle_ai::waittill_pathing_done();
				self ClearVehGoalPos();
				self SetVehGoalPos( self.origin, 0, 2 );
				// if the node is marked "nostop" or "detour", continue past without pausing
				if ( isdefined( nd_current.script_string ) && ( ( nd_current.script_string == "nostop" ) || ( nd_current.script_string == "detour" ) ) )
				{
				}
				else
				{
					nd_current util::script_wait();
				}
				
				// reset this
				self ClearLookAtEnt();
				wait 0.02;
			}
		}
		wait 0.1;
	}
}
// ----------------------------------------------

// ----------------------------------------------
// State: low alert and high alert
// ----------------------------------------------
function state_lowalert_enter()
{
	self SetSpeed( 5 );	
}

function state_highalert_enter()
{
	self SetSpeed( 10 );	
}

function state_alert_update()
{
	self endon( "change_state" );
	self endon( "death" );

	for ( ;; )
	{
		if ( IsDefined( self.alertSource ) )
		{
			self ClearLookAtEnt();

			goalpos = self.alertSource;
			goalpos = self GetClosestPointOnNavVolume( goalpos, 128 );

			self.debugGoal = goalpos;

			if ( IsDefined( goalpos ) && self SetVehGoalPos( goalpos, true, 2 ) )
			{
				self vehicle_ai::waittill_pathing_done();

				// stop, look around
				wait 3;
			}
			else
			{
				wait 1;
			}
		}
	}
}
// ----------------------------------------------

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_enter()
{
	self SetSpeed( 12 );

	if ( !isdefined( self.enemy ) )
	{
		self vehicle_ai::set_state( "high_alert" );
		/# println("^1Error: Scout drone trying to enter combat state without an enemy as target."); #/
	}

	self.lockOnTarget = self.enemy;

	goalpos = _track_target_position( self.lockOnTarget );
	self SetVehGoalPos( goalpos, true, 2 );
}

function _track_target_position( target )
{
	targetForward = AnglesToForward( target.angles ) * SCOUT_TRACK_DISTANCE;
	return target.origin + targetForward + ( 0, 0, SCOUT_TRACK_HEIGHT );
}

function state_combat_update() // track player
{
	self endon( "change_state" );
	self endon( "death" );


	lastHasTargetTime = GetTime();

	for ( ;; )
	{
		if ( isAlive( self.lockOnTarget ) )
		{
			if ( Distance2DSquared( self.origin, self.lockOnTarget.origin ) > SQR( SCOUT_TRACK_TETHER ) )
			{
				self ClearLookAtEnt();

				goalpos = _track_target_position( self.lockOnTarget );

				if ( self SetVehGoalPos( goalpos, true, 2 ) )
				{
					self vehicle_ai::waittill_pathing_done();
				}
				else
				{
					wait 1;
				}
			}
			else
			{
				self SetLookAtEnt( self.lockOnTarget );
			}

			lastHasTargetTime = GetTime();
		}
		else if ( isAlive( self.enemy ) )
		{
			self.lockOnTarget = self.enemy;
		}
		else
		{
			if ( GetTime() - lastHasTargetTime > 4000 )
			{
			
			}
		}

		wait 0.01;
	}
}
// ----------------------------------------------

function get_custom_damage_effect( health_pct )
{
	if( health_pct < .25 )
	{
		return level._effect[ "quadrotor_damage04" ];
	}
	else if( health_pct < .5 )
	{
		return level._effect[ "quadrotor_damage03" ];
	}
	else if( health_pct < .75 )
	{
		return level._effect[ "quadrotor_damage02" ];
	}
	else if( health_pct < 0.9 )
	{
		return level._effect[ "quadrotor_damage01" ];
	}
	
	return undefined;
}

function scout_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	if ( self.health > 0 && iDamage > 1 ) // emp does one damage and we don't want to look like it damaged us
	{
		health_percent = ( self.health - iDamage ) / self.healthdefault;
		effect = get_custom_damage_effect( health_percent );
	}

	self vehicle_ai::throw_off_balance( sMeansOfDeath, vPoint, vDir,  sHitLoc );

	self notify ( "awareness_level_increase" );

	self.lockOnTarget = eAttacker;

	return iDamage;
}

function scout_find_new_position()
{
	patrolHeight = 140;

	if ( !isdefined( self.goalpos ) )
	{
		self.goalpos = self.origin;
	}

	origin = self.goalpos;

	points = []; // deprecated // self GetNavVolumePointsInBox( self.origin, 512, 128, 100, 64, 256, 32 );

	best_point = undefined;
	best_score = 0;

	foreach( point in points )
	{
		score = RandomFloat( 100 );

		pointAboveNavMesh = point;
		if ( IsDefined( pointAboveNavMesh ) )
		{
			score = score + 100 - Abs( pointAboveNavMesh[2] - point[2] ) * 0.1;
		}

		if ( score > best_score )
		{
			best_score = score;
			best_point = point;
		}
	}

	if ( isdefined( best_point ) )
	{
		origin = best_point + ( 0, 0, self.flyheight + RandomFloatRange( -30, 40 ) );
	}

	return origin;
}

