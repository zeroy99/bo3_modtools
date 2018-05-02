#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_ai_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\shared\ai\utility.gsh;

//#using scripts\sp\_util;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;

#define NUM_DAMAGE_STATES 4
#define DAMAGE_STATE_THRESHOLD_PCT_1 0.75
#define DAMAGE_STATE_THRESHOLD_PCT_2 0.5
#define DAMAGE_STATE_THRESHOLD_PCT_3 0.25
#define DAMAGE_STATE_THRESHOLD_PCT_4 0.1	

#define SCAN_HEIGHT_OFFSET 40
	
#define TURRET_STATE_SCAN_AT_ENEMY 0
#define TURRET_STATE_SCAN_FORWARD 1
#define TURRET_STATE_SCAN_RIGHT 2
#define TURRET_STATE_SCAN_FORWARD2 3
#define TURRET_STATE_SCAN_LEFT 4
#define NUM_TURRET_STATES 5
	
#define STR_VEHICLETYPE "drone_metalstorm"

#precache( "fx", "_t6/destructibles/fx_metalstorm_damagestate00" );
#precache( "fx", "_t6/destructibles/fx_metalstorm_damagestate01" );
#precache( "fx", "_t6/destructibles/fx_metalstorm_damagestate02" );
#precache( "fx", "_t6/destructibles/fx_metalstorm_damagestate03" );
#precache( "fx", "_t6/destructibles/fx_metalstorm_damagestate_back01" );
#precache( "fx", "_t6/destructibles/fx_metalstorm_death01a" );
#precache( "fx", "_t6/impacts/fx_metalstorm_hit01" );
#precache( "fx", "_t6/impacts/fx_metalstorm_hit02" );
#precache( "fx", "_t6/light/fx_vlight_metalstorm_eye_grn" );
#precache( "fx", "_t6/light/fx_vlight_metalstorm_eye_red" );
#precache( "fx", "_t6/electrical/fx_elec_sp_emp_stun_metalstorm" );

#namespace metal_storm;

REGISTER_SYSTEM( "metal_storm", &__init__, undefined )
	
	
function __init__()
{
	clientfield::register( "vehicle", "toggle_gas_freeze",						VERSION_SHIP, 1, "int" );
	
	vehicle::add_main_callback( "drone_metalstorm",&main );
	vehicle::add_main_callback( "drone_metalstorm_rts",&main );
	vehicle::add_main_callback( "drone_metalstorm_afghan_rts",&main );
	vehicle::add_main_callback( "drone_metalstorm_karma",&main );
	vehicle::add_main_callback( "drone_metalstorm_monsoon",&main );
	
	precache_damage_fx();
	
	level.difficultySettings[ "asd_burst_scale" ][ "easy" ]			= 1.15;
	level.difficultySettings[ "asd_burst_scale" ][ "normal" ]		= 1;
	level.difficultySettings[ "asd_burst_scale" ][ "hardened" ] 	= 0.85;
	level.difficultySettings[ "asd_burst_scale" ][ "veteran" ] 		= 0.7;

	level.difficultySettings[ "asd_health_boost" ][ "easy" ]		= -70;
	level.difficultySettings[ "asd_health_boost" ][ "normal" ]		= 0;
	level.difficultySettings[ "asd_health_boost" ][ "hardened" ] 	= 70;
	level.difficultySettings[ "asd_health_boost" ][ "veteran" ] 	= 140;
}

// Metal storm short hand commands!! Use these to give explicit orders

function precache_damage_fx()
{
	if ( !isdefined( level.fx_damage_effects ) )
	{
		level.fx_damage_effects = [];
	}
	
	if ( !isdefined( level.fx_damage_effects[ STR_VEHICLETYPE ] ) )
	{
		level.fx_damage_effects[ STR_VEHICLETYPE ] = [];
	}
	
	for ( i = 0; i < NUM_DAMAGE_STATES; i++ )
		level.fx_damage_effects[ STR_VEHICLETYPE ][i] = "_t6/destructibles/fx_metalstorm_damagestate0" + ( i + 1 );
	
	// final explosion fx
	level._effect[ "metalstorm_busted" ]	= "_t6/destructibles/fx_metalstorm_damagestate_back01";
	level._effect[ "metalstorm_explo" ]		= "_t6/destructibles/fx_metalstorm_death01a";
	
	level._effect[ "metalstorm_hit" ]		= "_t6/impacts/fx_metalstorm_hit01";
	level._effect[ "metalstorm_hit_back" ]	= "_t6/impacts/fx_metalstorm_hit02";
	
	level._effect[ "eye_light_friendly" ]	= "_t6/light/fx_vlight_metalstorm_eye_grn";
	level._effect[ "eye_light_enemy" ]		= "_t6/light/fx_vlight_metalstorm_eye_red";
	
	level._effect[ "metalstorm_stun" ] 		= "_t6/electrical/fx_elec_sp_emp_stun_metalstorm";
}

function main()
{
	self thread metalstorm_think();
	self thread update_damage_states();
	self thread metalstorm_rocket_recoil();
	self thread metalstorm_death();
	/#self thread metalstorm_debug();#/
	self.overrideVehicleDamage =&MetalStormCallback_VehicleDamage;
}

function metalstorm_think()
{
	self EnableAimAssist();
	self SetNearGoalNotifyDist( 35 );
	self SetSpeed( 5, 5, 5 );
	
	// Set this on the metal storm to specify the cuttoff distance at which he can see
	self.turret_state = TURRET_STATE_SCAN_AT_ENEMY;
	self.turret_on_target = false;
	self.highlyawareradius = 80;
	
	if( !isdefined( self.goalradius ) )
	{
		self.goalradius = 600;
	}
	
	if( !isdefined( self.goalpos ) )
	{
		self.goalpos = self.origin;
	}
	
	self SetVehGoalPos( self.goalpos, true );

	self.state_machine = statemachine::create( "metalstormbrain", self );
	main = self.state_machine statemachine::add_state( "main", undefined,&metalstorm_main, undefined );
	scripted = self.state_machine statemachine::add_state( "scripted", undefined,&metalstorm_scripted, undefined );
	
	vehicle_ai::add_interrupt_connection( "scripted", "main", "enter_vehicle" );	
	vehicle_ai::add_interrupt_connection( "scripted", "main", "scripted" );	
	vehicle_ai::add_interrupt_connection( "main", "scripted", "exit_vehicle" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "main" );			
	vehicle_ai::add_interrupt_connection( "scripted", "main", "enter_vehicle" );		
	
	// Set the first state
	if ( isdefined( self.script_startstate ) )
	{
		//removed || self.script_startstate == "idle"- this was breaking all the audio on the metalstorms CDC
		if( self.script_startstate == "off" )
		{
			self metalstorm_off();
		}
		else
		{
			self.state_machine statemachine::set_state( self.script_startstate );
		}
	}
	else
	{
		// Set the first state
		metalstorm_start_ai();
	}	
	
	self thread metalstorm_set_team( self.team );
	
	waittillframeend;
	
//	if( self.team == "axis" )
//	{
//		self.health += gameskill::getCurrentDifficultySetting( "asd_health_boost" );
//	}
}

function can_enter_main()
{
	if( !IsAlive( self ) )
		return false;
	
	driver = self GetSeatOccupant( 0 );
	if( isdefined( driver ) )
		return false;
	
	return true;
}

function metalstorm_off()
{
	self.state_machine statemachine::set_state( "scripted" );
	self vehicle::lights_off();
	self LaserOff();
	self vehicle::toggle_tread_fx( 0 );
	self vehicle::toggle_sounds( 0 );
	self vehicle::toggle_exhaust_fx( 0 );
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	target_vec = target_vec + ( 0, 0, -700 );
	self SetTargetOrigin( target_vec );		
	self.off = true;
	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
}

function metalstorm_on()
{
	self vehicle::lights_on();
	self vehicle::toggle_tread_fx( 1 );
	self EnableAimAssist();
	self vehicle::toggle_sounds( 1 );
	self bootup();
	self playsound ("veh_metalstorm_boot_up");
	self vehicle::toggle_exhaust_fx( 1 );
	self.off = undefined;
	metalstorm_start_ai();
}

function bootup()
{
	for( i = 0; i < 6; i++ )
	{
		wait 0.1;
		vehicle::lights_off();
		wait 0.1;
		vehicle::lights_on();
	}
	
	angles = self GetTagAngles( "tag_flash" );
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	self.turretRotScale = 0.3;
	
	driver = self GetSeatOccupant( 0 );
	if( !isdefined(driver) )
	{
		self SetTargetOrigin( target_vec );
	}
	wait 1;
	self.turretRotScale = 1;
}

function metalstorm_turret_on_vis_target_thread()	// Used for grenade watching
{
	self endon( "death" );
	self endon( "change_state" );
	
	self.turret_on_target = false;
	
	while( 1 )
	{
		self waittill( "turret_on_vistarget" );
		self.turret_on_target = true;
		WAIT_SERVER_FRAME;
	}
}


function metalstorm_turret_on_target_thread()
{
	self endon( "death" );
	self endon( "change_state" );
	self notify( "turret_on_target_thread" );
	
	self endon( "turret_on_target_thread" );
	
	self.turret_on_target = false;
	
	while( 1 )
	{
		self waittill( "turret_on_target" );
		self.turret_on_target = true;
		wait 0.5;
	}
}

// rotates the turret around until he can see his enemy
function metalstorm_turret_scan( scan_forever )
{
	self endon( "death" );
	self endon( "change_state" );
	
	self thread metalstorm_turret_on_target_thread();
	
	self.turretRotScale = 0.35;
	
	while( scan_forever || ( !isdefined( self.enemy ) || !(self VehCanSee( self.enemy )) ) )
	{
		if( self.turret_on_target )
		{
			self.turret_on_target = false;
			self.turret_state++;
			if( self.turret_state >= NUM_TURRET_STATES )
				self.turret_state = 0;
		}
		
		switch( self.turret_state )
		{	
			case TURRET_STATE_SCAN_AT_ENEMY:
				if( isdefined( self.enemy ) )
				{
					target_vec = ( self.enemy.origin[0], self.enemy.origin[1], self.origin[2] );
					break;
				}	// else fall through to FORWARD
				
			case TURRET_STATE_SCAN_FORWARD:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1], 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_RIGHT:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1] + 90, 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_FORWARD2:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1], 0 ) ) * 1000;
				break;
				
			case TURRET_STATE_SCAN_LEFT:
				target_vec = self.origin + AnglesToForward( ( 0, self.angles[1] - 90, 0 ) ) * 1000;
				break;
		}

		target_vec = target_vec + ( 0, 0, SCAN_HEIGHT_OFFSET );
		self SetTargetOrigin( target_vec );		
		
		wait 0.2;
	}
}


//TODO T7 - looks like this will need to get updated to support coop
function metalstorm_grenade_watcher()
{
	self endon( "death" );
	self endon( "change_state" );
	
	level flag::wait_till( "all_players_connected" );
	
	while( 1 )
	{	
		level.players[0] waittill( "grenade_fire", grenade );
		
		if (!IsDefined(grenade))
			continue;
		
		// coming at me?
		vel_towards_me = VectorDot( grenade GetVelocity(), VectorNormalize( self.origin - grenade.origin) );
		if( vel_towards_me < 100 || !self VehCanSee( grenade ) )
			continue;
		
		wait 0.15;
		
		distSq = 0;
		if( isdefined( grenade ) )
		{
			distSq = DistanceSquared( self.origin, grenade.origin );
			while( isdefined( grenade ) && ( distSq > 650 * 650 || distSq < 150 * 150 ) )
			{
				distSq = DistanceSquared( self.origin, grenade.origin );
				WAIT_SERVER_FRAME;
			}
		}
		
		if( !isdefined( grenade ) )
			continue;
		
		// double check that the granade is still coming towards me
		vel_towards_me = VectorDot( grenade GetVelocity(), VectorNormalize( self.origin - grenade.origin) );
		if( vel_towards_me < 100 )
			continue;
		
		self SetSpeed( 0 );
		self.turretRotScale = 2;
		self SetTurretTargetEnt( grenade );
		self thread metalstorm_turret_on_vis_target_thread();
		
		WAIT_SERVER_FRAME;
			
		for( i = 0; i < 6; i++ )
		{	
			self FireWeapon();
			
			if( RandomInt( 100 ) > 40 && self.turret_on_target )
			{
				if( isdefined( grenade ) )
				{
					grenade ResetMissileDetonationTime( 0 );
				}
				break;
			}
			
			wait 0.15;
		}
		
		self SetSpeed( 5, 5, 5 );
		self ClearTurretTarget();
	}
}

function metalstorm_weapon_think()
{
	self endon( "death" );
	self endon( "change_state" );
	
	cant_see_enemy_count = 0;
	
	self thread metalstorm_grenade_watcher();
	
	while ( 1 )
	{
		enemy_is_tank = false;
		enemy_is_hind = false;
		if( isdefined( self.enemy ) && isdefined( self.enemy.vehicletype ) )
		{
			enemy_is_tank = self.enemy.vehicletype == "tank_t72_rts" || self.enemy.vehicletype == "drone_claw_rts";
			enemy_is_hind = self.enemy.vehicletype == "heli_hind_afghan_rts";
		}

		if ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
		{
			self.turretRotScale = 1;
			self SetTurretTargetEnt( self.enemy );
			
			if( cant_see_enemy_count >= 2 )
			{
				// found enemy, react by changing goal positions
				self ClearVehGoalPos();
				self notify( "near_goal" );
			}
			cant_see_enemy_count = 0;
		
			//C. Ayers: Changing this to play only when locking onto a player
			if( IsPlayer( self.enemy ) )
			{
				self playsound ("wpn_metalstorm_lock_on");
			}
			self thread metalstorm_blink_lights();
			self LaserOn();
			
			wait 1.0;
			
			if ( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				if( isdefined( self.enemy ) && DistanceSquared( self.origin, self.enemy.origin ) > 800 * 800 || enemy_is_tank )
				{
					if( enemy_is_hind )	// setup the missile guidance
						self SetGunnerTargetEnt( self.enemy, (0,0,-40), 0 );

					// This is the missile
					self FireWeapon( 1, self.enemy );

					self ClearGunnerTarget( 0 );
				}
				else
				{
					self metalstorm_fire_for_time( RandomFloatRange( 1.5, 2.5 ) );
				}
			}
			
			self LaserOff();
			
			wait RandomFloatRange( 1.2, 2 );// * gameskill::getCurrentDifficultySetting( "asd_burst_scale" );
		}
		else
		{	
			cant_see_enemy_count++;
			
			wait 0.5;
			
			if( cant_see_enemy_count > 2 )
			{
				self metalstorm_turret_scan( false );
			}
			else if( cant_see_enemy_count > 1 )
			{
				self ClearTargetEntity();
			}
		}
	}
}

function metalstorm_fire_for_time( totalFireTime )
{
	self endon( "crash_done" );
	self endon( "death" );
	
	weapon = self SeatGetWeapon( 0 );
	if ( weapon == level.weaponNone )
		return; 
	
	fireTime = weapon.fireTime;
	time = 0;
	
	while( time < totalFireTime )
	{
		if( isdefined( self.enemy ) && isdefined(self.enemy.attackerAccuracy) && self.enemy.attackerAccuracy == 0 )
		{
			self FireWeapon( 0, self.enemy );
		}
		else
		{
			self FireWeapon();
		}
		wait fireTime;
		time += fireTime;
	}
}

function metalstorm_start_ai( state )
{
	self.goalpos = self.origin;
	
	if ( !isdefined( state ) )
		state = "main";
	
	self.state_machine statemachine::set_state( state );
}

function metalstorm_stop_ai()
{
	self.state_machine statemachine::set_state( "scripted" );
}

function metalstorm_main()
{
	while( isdefined( self.emped ) )
	{
		wait 1;
	}
	
	if (isdefined(self.vMaxAISpeedOverridge))
	{	
		self SetSpeed( self.vMaxAISpeedOverridge, 5, 5 );	
	}
	else
	{
		self SetSpeed( 5, 5, 5 );	
		self SetVehMaxSpeed( 0 );
	}
		
	self thread metalstorm_movementupdate();
	self thread metalstorm_weapon_think();	
}

/#
function metalstorm_debug()
{
	self endon( "death" );
	
	while ( 1 )
	{
		// no dvar, no debugging
		if( GetDvarInt( "metalstorm_debug" ) == 0 )
		{
			wait( 0.5 );
			continue;
		}
		
		if ( isdefined( self.goalpos ) )
		{
			DebugStar( self.goalpos, 10, ( 1, 0, 0 ) );
			Circle( self.goalpos, self.goalradius, ( 1, 0, 0 ), false, 10 );
		}
		
		if ( isdefined( self.enemy ) )
		{
			Line( self.origin + ( 0, 0, 30 ), self.enemy.origin + ( 0, 0, 30 ), ( 1, 0, 0 ), true, 1 );
		}
		
		WAIT_SERVER_FRAME;
	}
}
#/

function metalstorm_check_move( position )
{
	results = PhysicsTraceEx( self.origin, position, (-15,-15,-5), (15,15,5), self );
	
	if( results["fraction"] == 1 )
	{
		return true;
	}
	
	return false;
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
		if ( isdefined( self.enemy ) && isdefined( self.goal_node ) )
		{
			if( distance2dSquared( self.enemy.origin, self.origin ) < 150 * 150 )
			{
				self.move_now = true;
				self notify( "near_goal" );
			}
			if( distance2dSquared( self.enemy.origin, self.goal_node.origin ) < 150 * 150 )
			{
				self.move_now = true;
				self notify( "near_goal" );
			}
		}
		
		if( isdefined( self.goal_node ) )
		{
			if( distance2dSquared( self.goal_node.origin, self.goalpos ) > self.goalradius * self.goalradius )
			{
				wait 1;
				
				self.move_now = true;
				self notify( "near_goal" );
			}
		}
		
		wait 0.2;
	}
}

function waittill_enemy_too_close_or_timeout( time )
{
	self endon( "death" );
	self endon( "change_state" );
	
	while( time > 0 )
	{
		time -= 0.2;
		wait 0.2;
		
		if ( isdefined( self.enemy ) )
		{
			if( distance2dSquared( self.enemy.origin, self.origin ) < 150 * 150 )
			{
				return;
			}
			if ( !isdefined(self.goal_node))
				return;
			if( distance2dSquared( self.enemy.origin, self.goal_node.origin ) < 150 * 150 )
			{
				return;
			}
		}
	}
}

function metalstorm_movementupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	if( distance2dSquared( self.origin, self.goalpos ) > 20 * 20 )
		self SetVehGoalPos( self.goalpos, true, 2 );
	
	wait 0.5;
	
	goalfailures = 0;
	
	while( 1 )
	{
		goalpos = metalstorm_find_new_position();
		if( self SetVehGoalPos( goalpos, false, 2 ) )
		{
			self thread path_update_interrupt();
			
			goalfailures = 0;
			self util::waittill_any( "near_goal", "reached_end_node" );
			
			if( isdefined( self.move_now ) )
			{
				self.move_now = undefined;
				wait 0.1;
			}
			else if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				if( Abs( AngleClamp180( self.angles[0] ) ) > 6 || Abs( AngleClamp180( self.angles[2] ) ) > 6 )
				{
					self SetBrake( 1 );
				}
				waittill_enemy_too_close_or_timeout( RandomFloatRange( 3, 4 ) );
			}
			else
			{
				if( Abs( AngleClamp180( self.angles[0] ) ) > 6 || Abs( AngleClamp180( self.angles[2] ) ) > 6 )
				{
					self SetBrake( 1 );
				}
				wait 0.5;
			}
			self SetBrake( 0 );
		}
		else
		{
			goalfailures++;
			
			offset = ( RandomFloatRange(-70,70), RandomFloatRange(-70,70), 15 );
			goalpos = self.origin + offset;
			
			if( self metalstorm_check_move( goalpos ) )
			{
				self SetVehGoalPos( goalpos, false );
				self waittill( "near_goal" );
				
				wait 2;
			}
			wait 0.5;
		}	
	}
}

function metalstorm_find_new_position()
{
	const sweet_spot_dist = 350;
	
	origin = self.goalpos;
	
	nodes = GetNodesInRadius( self.goalpos, self.goalradius, 0, 128, "Path" );
	
	/*
 	nodea = GetNode( "a", "targetname" );
	nodeb = GetNode( "b", "targetname" );	
	
	if( isdefined( self.goal_node ) )
	{ 
	   	if( self.goal_node == nodea )
	   	{
	   		self.goal_node = nodeb;
			return nodeb.origin;
	   	}
	   	else
	   	{
	   		self.goal_node = nodea;
			return nodea.origin;
	   	}
	}
	*/
	
	if( nodes.size == 0 )
	{
		self.goalpos = ( self.goalpos[0], self.goalpos[1], self.origin[2] );
		nodes = GetNodesInRadius( self.goalpos, self.goalradius + 500, 0, 500, "Path" );
	}
	
	best_node = undefined;
	best_score = -999999;
	
	if ( isdefined( self.enemy ) )
	{
		vec_enemy_to_self = VectorNormalize( FLAT_ORIGIN( self.origin ) - FLAT_ORIGIN( self.enemy.origin ) );
	
		foreach( node in nodes )
		{
			vec_enemy_to_node = ( FLAT_ORIGIN( node.origin ) - FLAT_ORIGIN( self.enemy.origin ) );
			
			dist_in_front_of_enemy = VectorDot( vec_enemy_to_node, vec_enemy_to_self );
			dist_away_from_sweet_line = Abs( dist_in_front_of_enemy - sweet_spot_dist );
			
			score = 1 + RandomFloat( .15 );

			if( dist_away_from_sweet_line > 100 )
			{
				score -= math::clamp( dist_away_from_sweet_line / 800, 0, 0.5 );
			}
			
			if( distance2dSquared( node.origin, self.enemy.origin ) > 550 * 550 )
			{
				score -= 0.2;
			}
			
			if( distance2dSquared( self.origin, node.origin ) < 120 * 120 )
			{
				score -= 0.2;
			}
			
			if( isdefined( node.metal_storm_previous_goal ) )
			{
				score -= 0.2;
				node.metal_storm_previous_goal--;
				if( node.metal_storm_previous_goal == 0 )
				{
					node.metal_storm_previous_goal = undefined;
				}
			}
			
			//DebugStar( node.origin, 100, ( 1, score, 1 ) );
			//Print3d( node.origin, "Score: " + score, ( 1, 1, 1 ), 1, 1, 100 );

			if ( score > best_score )
			{
				best_score = score;
				best_node = node;
			}
		}
	}
	else
	{
		foreach( node in nodes )
		{
			
			score = RandomFloat( 1 );			
			
			if( distance2dSquared( self.origin, node.origin ) < 100 )
			{
				score -= 0.5;
			}
			
			if( isdefined( node.metal_storm_previous_goal ) )
			{
				score -= 0.2;
				node.metal_storm_previous_goal--;
				if( node.metal_storm_previous_goal == 0 )
				{
					node.metal_storm_previous_goal = undefined;
				}
			}
			
			if( score > best_score )
			{
				best_score = score;
				best_node = node;
			}		
		}
	}
	
	if( isdefined( best_node ) )
	{
		best_node.metal_storm_previous_goal = 3;
		origin = best_node.origin;
		self.goal_node = best_node;
	}
	
	return origin;
}

// self is vehicle
function metalstorm_exit_vehicle()
{
	self waittill( "exit_vehicle", player );
	
	player.ignoreme = false;
	player DisableInvulnerability();
	
	self thread metalstorm_rocket_recoil();
	self ShowPart( "tag_pov_hide" );
	self.goalpos = self.origin;
}

function metalstorm_scripted()
{
	self endon( "change_state" );
	
	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self.turretRotScale = 1;
		self DisableAimAssist();
		self HidePart( "tag_pov_hide" );
		self thread vehicle_death::vehicle_damage_filter( "firestorm_turret" );
		self thread metalstorm_set_team( driver.team );
		self SetVehMaxSpeed( (isdefined(self.vMaxSpeedOverridge)?self.vMaxSpeedOverridge:7) );
		driver EnableInvulnerability();
		driver.ignoreme = true;
		self thread metalstorm_player_rocket_recoil( driver );
		self thread metalstorm_player_bullet_shake( driver );
		self thread metalstorm_player_hit_dudes_sound();
		self thread metalstorm_exit_vehicle();
		self SetBrake( 0 );
	}
	
	self LaserOff();
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();
}

function metalstorm_update_damage_fx()
{
	next_damage_state = 0;
	
	max_health = self.healthdefault;
	if( isdefined( self.health_max ) )
	{
		max_health = self.health_max;
	}
	
	health_pct = self.health / max_health;
	
	if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_1 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_2 )
	{
		next_damage_state = 1;
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_2 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_3 )
	{
		next_damage_state = 2;			
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_3 && health_pct > DAMAGE_STATE_THRESHOLD_PCT_4 )
	{
		next_damage_state = 3;			
	}
	else if ( health_pct <= DAMAGE_STATE_THRESHOLD_PCT_4 )
	{
		next_damage_state = 4;
	}
	
	if ( next_damage_state != self.current_damage_state )
	{
		if ( isdefined( level.fx_damage_effects[ STR_VEHICLETYPE ][ next_damage_state - 1 ] ) )
		{
			fx_ent = self get_damage_fx_ent();
			
			PlayFXOnTag( level.fx_damage_effects[ STR_VEHICLETYPE ][ next_damage_state - 1 ], fx_ent, "tag_origin" );
		}
		else
		{
			// This will get rid of the fx ent
			get_damage_fx_ent();
		}
		
		self.current_damage_state = next_damage_state;
	}
}

function update_damage_states()
{
	self endon( "death" );
	
	self.current_damage_state = 0;
	
	if ( !isdefined( level.fx_damage_effects ) || !isdefined( level.fx_damage_effects[ STR_VEHICLETYPE ] ) )
		return;
	
	while ( 1 )
	{
		self waittill( "damage", damage, attacker, dir, point, mod, model, modelAttachTag, part );
		
		if ( !isdefined( self ) )
			return;
		
		if( mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET" || mod == "MOD_MELEE" )
		{
			if( part == "tag_control_panel" || part == "tag_body_panel" )
			{
				PlayFx( level._effect[ "metalstorm_hit_back" ], point, dir );
			}
			else
			{
				PlayFx( level._effect[ "metalstorm_hit" ], point, dir );
			}
		}
		
		// when taking damage let the turret know if it is scanning to look at our enemy
		// hopefully code will update our enemy
		self.turret_state = TURRET_STATE_SCAN_AT_ENEMY;
		self.turretRotScale = 1.0;
		self.turret_on_target = true;
		
		metalstorm_update_damage_fx();
	}
}

function get_damage_fx_ent()
{
	if ( isdefined( self.damage_fx_ent ) )
		self.damage_fx_ent Delete();

	self.damage_fx_ent = Spawn( "script_model", ( 0, 0, 0 ) );
	self.damage_fx_ent SetModel( "tag_origin" );
	self.damage_fx_ent.origin = self.origin;
	self.damage_fx_ent.angles = self.angles;
	self.damage_fx_ent LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
	
	return self.damage_fx_ent;
}

function cleanup_fx_ents()
{
	if( isdefined( self.damage_fx_ent ) )
	{
		self.damage_fx_ent delete();
	}
	
	if( isdefined( self.stun_fx ) )
	{
		self.stun_fx delete();
	}
}


function metalstorm_freeze_blink_lights()
{
	self endon( "death" );
	
	self vehicle::lights_off();
	wait 0.4;
	self vehicle::lights_on();
	wait 0.3;
	self vehicle::lights_off();
	wait 0.4;
	self vehicle::lights_on();
	wait 0.3;
	self vehicle::lights_off();
	wait 0.4;
	self vehicle::lights_on();
	wait 0.3;
	self vehicle::lights_off();
}

function metalstorm_freeze_death( attacker, mod )
{
	self endon( "death" );
	
	level notify( "asd_freezed" );
	
	// Just give the credit to the player for the freeze kill. Who else is going to be shooting the nitrogen containers.
	//level.player util::inc_general_stat( "mechanicalkills" );
	
	goalDist = RandomFloatRange( 350, 450 );
	deathGoal = self.origin + AnglesToForward( self.angles ) * goalDist;
	PlayFXOnTag( level._effect[ "freeze_short_circuit" ], self, "tag_origin" );
	self SetModel( "veh_t6_drone_tank_freeze" );
	self SetVehGoalPos( deathGoal, false );
	self thread metalstorm_freeze_blink_lights();
	self clientfield::set( "toggle_gas_freeze", 1 );
	
	self.turretRotScale = 0.3;
	self SetSpeed( 1 );
	
	if( !isdefined( self.stun_fx) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
		PlayFXOnTag( level._effect[ "metalstorm_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait 1;
	
	self.turretRotScale = 0.1;
	self SetSpeed( 0.5 );
	self LaserOff();
	
	wait 1;
	
	self.turretRotScale = 0.01;
	self SetSpeed( 0.0 );
	
	wait 1;
	
	self CancelAIMove();
	self ClearVehGoalPos();
	self ClearTurretTarget();
	//self SetBrake( 1 );
	
	wait 2;
	
	if( isdefined( self.stun_fx ) )
	{
		self.stun_fx delete();
	}
}

// Death 

function metalstorm_death()
{
	wait 0.1;
	
	self notify( "nodeath_thread" );	// Kill off the vehicle_death::main thread
	
	self waittill( "death", attacker, damageFromUnderneath, weapon, point, dir, mod );
	
	if( isdefined( self.eye_fx_ent ) )
	{
		self.eye_fx_ent delete();
	}
	
	if( isdefined( self.delete_on_death ) )
	{
		self cleanup_fx_ents();
		self delete();
		return;
	}
	
	if ( !isdefined( self ) )
	{
		return;
	}
	
	self vehicle_death::death_cleanup_level_variables();			
	
	self DisableAimAssist();
	self vehicle::toggle_sounds( false );
	self vehicle::lights_off();
	self LaserOff();
	self cleanup_fx_ents();
	self vehicle::toggle_tread_fx( false );
	self vehicle::toggle_exhaust_fx( false );
	
	
	if( isdefined(mod) && mod == "MOD_GAS" && isdefined( level.metalstorm_freeze_death ) )
	{
		self metalstorm_freeze_death( attacker, mod );
	}
	else
	{
		fx_ent = self get_damage_fx_ent();			
		PlayFXOnTag( level._effect[ "metalstorm_explo" ], fx_ent, "tag_origin" );
		self PlaySound( "veh_metalstorm_dying" );
		
		self metalstorm_crash_movement( attacker );
	}
	
	wait 5;
	
	//self NotSolid();
	
	if ( isdefined( self ) )
	{
		radius = 18;
		height = 50;
		badplace_box( "", 40, self.origin, radius, "all" );		
		self freeVehicle();
	}
	
	wait 40;
	
	if ( isdefined( self ) )
	{
		self delete();
	}
}


function death_fx()
{
	self vehicle::do_death_fx();
	self playsound("veh_metalstorm_sparks");
}

function metalstorm_crash_movement( attacker )
{
	self endon( "crash_done" );
	self endon( "death" );
	
	self CancelAIMove();
	self ClearVehGoalPos();	

	self.takedamage = 0;
	
	if( !isdefined( self.off ) )
	{
		self thread death_turret_rotate();
		self.turretRotScale = 1.0;
	
		self PlaySound( "wpn_turret_alert" );
		self thread metalstorm_fire_for_time( RandomFloatRange( 1.5, 4.0 ) );
		
		self SetSpeed( 7 );
	
		deathMove = RandomInt( 8 );
		
		if( deathMove == 0 )
		{
			goalDist = RandomFloatRange( 350, 450 );
			deathGoal = self.origin + AnglesToForward( self.angles ) * goalDist;
		}
		else if( deathMove == 1 )
		{
			goalDist = RandomFloatRange( 350, 450 );
			deathGoal = self.origin + AnglesToForward( self.angles ) * -goalDist;
		}
		else if( deathMove <= 4 )
		{
			self thread spin_crash();
		}
		else //if( deathMove >= 4 )
		{
			if( isdefined( attacker ) )
			{
				deathGoal = attacker.origin;
			}
			else
			{
				self thread spin_crash();
			}
		}
		
		if( isdefined( deathGoal ) )
		{
			self SetVehGoalPos( deathGoal, false );
		}
		
		wait 0.5;
		self util::waittill_any_timeout( 2.5, "near_goal", "veh_collision" );
	}
	
	if( !isdefined( self ) )
	{
		return;
	}
	
	self CancelAIMove();
	self ClearVehGoalPos();
	self ClearTurretTarget();
	self SetBrake( 1 );
	
	self thread vehicle_death::death_radius_damage();
	
	/*if( self.team == "allies" || IsSubStr( self.vehicletype, "karma" )  )//TODO T7 - self.team is undefined
	{
		self thread vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	}
	else*/
	{
		self thread vehicle_death::set_death_model( "veh_t6_drone_tank_alt_dead", self.modelswapdelay );
	}

	self death_fx();
	self LaunchVehicle( ( RandomFloatRange(-20,20), RandomFloatRange(-20,20), 32 ), (RandomFloatRange(-5,5),RandomFloatRange(-5,5),0), true, false );
	self playsound ("exp_metalstorm_vehicle");
	
	self notify( "crash_done" );
}

function spin_crash()
{
	self endon( "crash_done" );
	
	turn_rate = 5 + RandomFloatRange( 0, 20 );
	
	if( RandomInt( 100 ) > 50 )
	{
		turn_rate *= -1;
	}
	
	count = 0;
	
	while( isdefined( self ) )
	{
		deathGoal = self.origin + AnglesToForward( (0, self.angles[1] + turn_rate, 0) ) * 300;
		self SetVehGoalPos( deathGoal, false );
		WAIT_SERVER_FRAME;
	
		count++;
		if( count % 10 == 0 )
		{
			turn_rate += RandomFloatRange( -10, 10 );
		}
	}	
}


// rotates the turret around until he can see his enemy
function death_turret_rotate()
{
	self endon( "crash_done" );
	self endon( "death" );
	
	self.turretRotScale = 1.3;
	
	while( 1 )
	{
		pitch = RandomFloatRange( -60, 20 );
		target_vec = self.origin + AnglesToForward( ( pitch, RandomFloat( 360 ), 0 ) ) * 1000;
		
		driver = self GetSeatOccupant( 0 );
		if( !isdefined(driver) )	// can't set the target on the player's vehicle
		{
			self SetTargetOrigin( target_vec );
		}
		
		wait RandomFloatRange( 0.3, 0.6 );
		
		if( pitch < 0 && RandomInt( 100 ) > 50 )
		{
			self FireWeapon( 1 );
		}
	}
}

function metalstorm_emped()
{
	self endon( "death" );
	self notify( "emped" );
	self endon( "emped" );
	
	self.emped = true;
	PlaySoundAtPosition( "veh_asd_emp_down", self.origin );
	self.turretRotScale = 0.2;
	self metalstorm_off();
	if( !isdefined( self.stun_fx) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_turret", (0,0,0), (0,0,0) );
		PlayFXOnTag( level._effect[ "metalstorm_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait RandomFloatRange( 4, 8 );
	
	self.stun_fx delete();
	
	self.emped = undefined;
	self metalstorm_on();
	self playsound ("veh_qrdrone_boot_asd");
}

function MetalStormCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	is_damaged_by_grenade = weapon.weapClass == "grenade";
	is_damaged_by_god_rod = weapon.name == "god_rod";
	if ( is_damaged_by_grenade || is_damaged_by_god_rod )
	{
		iDamage = Int( iDamage * 3 );
	}
	
	if( sMeansOfDeath == "MOD_GAS" )
	{
		iDamage = self.health + 100;
	}
	
	driver = self GetSeatOccupant( 0 );
	
	if ( weapon.isEmp && sMeansOfDeath != "MOD_IMPACT" )
	{
		if( !isdefined(driver) )
		{
			self thread metalstorm_emped();
		}
	}
	
	if( isdefined( driver ) )
	{
		// Lets get some hit indicators
		//driver FinishPlayerDamage( eInflictor, eAttacker, 1, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, "none", 0, psOffsetTime );
	}
	
	return iDamage;
}


function metalstorm_set_team( team )
{
	self.team = team;
	if( isdefined( self.vehmodelenemy ) )
	{
		if( team == "allies" )
		{
			self SetModel( self.vehmodel );
		}
		else
		{
			self SetModel( self.vehmodelenemy );
		}
	}
	
	if( !isdefined( self.off ) )
	{
		metalstorm_blink_lights();
	}
}

function metalstorm_blink_lights()
{
	self endon( "death" );
	
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
	wait 0.1;
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
}

function metalstorm_player_bullet_shake( player )
{
	self endon( "death" );
	self endon( "recoil_thread" );
	
	while( 1 )
	{
		self waittill( "turret_fire" );
		angles = self GetTagAngles( "tag_barrel" );
		dir = AnglesToForward( angles );
		self LaunchVehicle( dir * -5, self.origin + (0,0,30), false );
		Earthquake( 0.2, 0.2, player.origin, 200 );
	}
}

function metalstorm_player_rocket_recoil( player )
{
	self notify( "recoil_thread" );
	self endon( "recoil_thread" );
	self endon( "death" );
	
	while( 1 )
	{
		player waittill( "missile_fire" );
		
		angles = self GetTagAngles( "tag_barrel" );
		dir = AnglesToForward( angles );
		
		self LaunchVehicle( dir * -30, self.origin + (0,0,70), false );
		Earthquake( 0.4, 0.3, player.origin, 200 );
		
		//self SetAnimRestart( %vehicles::o_drone_tank_missile_fire_sp, 1, 0, 0.4 );
	}
}

function metalstorm_rocket_recoil()
{
	self notify( "recoil_thread" );
	self endon( "recoil_thread" );
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "missile_fire" );
		
		angles = self GetTagAngles( "tag_barrel" );
		dir = AnglesToForward( angles );
		
		self LaunchVehicle( dir * -30, self.origin + (0,0,70), false );
		
		//self SetAnimRestart( %vehicles::o_drone_tank_missile_fire_sp, 1, 0, 0.4 );
	}
}

function metalstorm_player_hit_dudes_sound()
{
	self endon( "exit_vehicle" );
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "touch", enemy );
		
		if( isdefined( enemy ) && IsAI( enemy ) )
		{
			self playsound( "veh_rts_hit_npc" );
			wait 0.3;
		}
	}
}
