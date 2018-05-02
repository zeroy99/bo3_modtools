#using scripts\codescripts\struct;

#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\flag_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;

#insert scripts\shared\ai\utility.gsh;

#precache( "fx", "_t6/destructibles/fx_quadrotor_damagestate01" );
#precache( "fx", "_t6/destructibles/fx_quadrotor_damagestate02" );
#precache( "fx", "_t6/destructibles/fx_quadrotor_damagestate03" );
#precache( "fx", "_t6/destructibles/fx_quadrotor_damagestate04" );
#precache( "fx", "_t6/destructibles/fx_quadrotor_crash01" );
#precache( "fx", "_t6/destructibles/fx_quadrotor_nudge01" );
#precache( "fx", "_t6/electrical/fx_elec_sp_emp_stun_quadrotor" );

#namespace quadrotor;

REGISTER_SYSTEM( "quadrotor", &__init__, undefined )

function __init__()
{
	vehicle::add_main_callback( "heli_quadrotor",&quadrotor_think );
	vehicle::add_main_callback( "heli_quadrotor_rts",&quadrotor_think );
	
//	SetSavedDvar( "vehHelicopterLookaheadTime", .07 );
	
	level._effect[ "quadrotor_damage01" ]	= "_t6/destructibles/fx_quadrotor_damagestate01";
	level._effect[ "quadrotor_damage02" ]	= "_t6/destructibles/fx_quadrotor_damagestate02";
	level._effect[ "quadrotor_damage03" ]	= "_t6/destructibles/fx_quadrotor_damagestate03";
	level._effect[ "quadrotor_damage04" ]	= "_t6/destructibles/fx_quadrotor_damagestate04";
	
	level._effect[ "quadrotor_crash" ]		= "_t6/destructibles/fx_quadrotor_crash01";
	level._effect[ "quadrotor_nudge" ]		= "_t6/destructibles/fx_quadrotor_nudge01";
	
	level._effect[ "quadrotor_stun" ] 		= "_t6/electrical/fx_elec_sp_emp_stun_quadrotor";
	
}

function quadrotor_think()
{
	self.maxhealth = 200;//TODO T7 - added this because the MP callbacks want it. Can probably get rid of this later
	self EnableAimAssist();
	self SetHoverParams( 25.0, 120.0, 80 );
	self SetNearGoalNotifyDist( 30 );
	
	self.flyheight = GetDvarFloat( "g_quadrotorFlyHeight" );

	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0.574;	//+/- 55 degrees = 110 fov
	
	self.vehAirCraftCollisionEnabled = true;
	
	if ( !IsDefined( self.heightAboveGround ) )
	{
		self.heightAboveGround = 100;
	}
	
	if( !isdefined( self.goalradius ) )
	{
		self.goalradius = 600;
	}
	
	if( !isdefined( self.goalpos ) )
	{
		self.goalpos = self.origin;
	}
	
	self.original_vehicle_type = self.vehicletype;
	
	self.state_machine = statemachine::create( "quadrotorbrain", self );
	main 		= self.state_machine statemachine::add_state( "main", undefined,&quadrotor_main, undefined );
	scripted 	= self.state_machine statemachine::add_state( "scripted", undefined, &quadrotor_scripted, undefined );
	
	vehicle_ai::add_interrupt_connection( "scripted", "main", "enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "scripted" );	
	vehicle_ai::add_interrupt_connection( "scripted", "main", "enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "exit_vehicle" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "main" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "scripted_done" );	
	
	self thread quadrotor_death();
	self thread quadrotor_damage();
	self HidePart( "tag_viewmodel" );
	
	self.overrideVehicleDamage =&QuadrotorCallback_VehicleDamage;
		
	// Set the first state
	if ( isdefined( self.script_startstate ) )
	{
		if( self.script_startstate == "off" )
		{
			self quadrotor_off();
		}
		else
		{
			self.state_machine statemachine::set_state( self.script_startstate );
		}
	}
	else
	{
		// Set the first state
		quadrotor_start_ai();
	}
	
	self thread quadrotor_set_team( self.team );
	
	// start the update
	// No need for this update any more since all connections are on notifies
	//self.state_machine statemachine::update( 0.05 );
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

function quadrotor_start_scripted()
{
	self.state_machine statemachine::set_state( "scripted" );
}

function quadrotor_off()
{
	self.state_machine statemachine::set_state( "scripted" );
	self vehicle::lights_off();
	self vehicle::toggle_tread_fx( 0 );
	self vehicle::toggle_sounds( 0 );
	self HidePart( "tag_rotor_fl" );
	self HidePart( "tag_rotor_fr" );
	self HidePart( "tag_rotor_rl" );
	self HidePart( "tag_rotor_rr" );
	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
	self.off = true;
}

function quadrotor_on()
{
	self vehicle::lights_on();
	self vehicle::toggle_tread_fx( 1 );
	self vehicle::toggle_sounds( 1 );
	self ShowPart( "tag_rotor_fl" );
	self ShowPart( "tag_rotor_fr" );
	self ShowPart( "tag_rotor_rl" );
	self ShowPart( "tag_rotor_rr" );
	self EnableAimAssist();
	self.off = undefined;
	quadrotor_start_ai();
}

function quadrotor_start_ai()
{
	self.goalpos = self.origin;
	self.state_machine statemachine::set_state( "main" );
}

function quadrotor_main()
{
	self thread quadrotor_blink_lights();
	self thread quadrotor_fireupdate();
	self thread quadrotor_movementupdate();
	self thread quadrotor_collision();
}

function quadrotor_fireupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	while( 1 )
	{
		if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
		{
			enemy_is_hind = false;
			if( isdefined( self.enemy ) && isdefined( self.enemy.vehicletype ) )
			{
				enemy_is_hind = self.enemy.vehicletype == "heli_hind_afghan_rts";
			}
			
			if( DistanceSquared( self.enemy.origin, self.origin ) < 1280 * 1280 || enemy_is_hind ) 
			{
				self SetTurretTargetEnt( self.enemy );
				self quadrotor_fire_for_time( RandomFloatRange( 0.3, 0.6 ) );
			}
			
			if( isdefined( self.enemy ) && IsAI( self.enemy ) )
			{
				wait( RandomFloatRange( 2, 2.5 ) );
			}
			else
			{
				wait( RandomFloatRange( 0.5, 1.5 ) );
			}
		}
		else
		{
			wait 0.4;
		}
	}
}

function quadrotor_check_move( position )
{
	results = PhysicsTraceEx( self.origin, position, (-15,-15,-5), (15,15,5), self );
	
	if( results["fraction"] == 1 )
	{
		return true;
	}
	
	return false;
}

function quadrotor_adjust_goal_for_enemy_height( goalpos )
{
	if( isdefined( self.enemy ) )
	{
		if( IsAI( self.enemy ) )
			offset = 45;
		else	// don't want quadrotors to fly above quadrotors
			offset = -100;
		
		if( self.enemy.origin[2] + offset > goalpos[2] )
		{
			goal_z = self.enemy.origin[2] + offset;
			if( goal_z > goalpos[2] + 400 )
			{
				goal_z = goalpos[2] + 400;
			}
			results = PhysicsTraceEx( goalpos, ( goalpos[0], goalpos[1], goal_z ), (-15,-15,-5), (15,15,5), self );
			
			if( results["fraction"] == 1 )
			{
				goalpos = ( goalpos[0], goalpos[1], goal_z );
			}
		}
	}
	
	return goalpos;
}

function make_sure_goal_is_well_above_ground( pos )
{
	start = pos + (0,0,self.flyheight);
	end = pos + (0,0,-self.flyheight);
	trace = BulletTrace( start, end, false, self, false, false );
	end =  trace["position"];
	
	pos = end + (0,0,self.flyheight);
	
	z = self GetHeliHeightLockHeight( pos );
	pos = ( pos[0], pos[1], z );
		
	return pos;
}

function waittill_pathing_done()
{
	self endon( "death" );
	self endon( "change_state" );
	
	if( self.vehonpath )
	{
		self flag::wait_till( "goal_reached" );
	}
}

function goal_flag_monitor()
{
	self endon( "death" );
	self endon( "change_state" );

	self flag::clear( "goal_reached" );
		self util::waittill_any( "near_goal", "reached_end_node", "force_goal" );
	self flag::set( "goal_reached" );
}

function quadrotor_movementupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	assert( IsAlive( self ) );
	
	// make sure when we start this that we get above the ground
	old_goalpos = self.goalpos;
	self.goalpos = self make_sure_goal_is_well_above_ground( self.goalpos );

	if( !self.vehonpath )
	{
		if( isdefined( self.attachedpath ) )
		{
			// Need to wait, we may be attached to a path but haven't started it yet and we don't want to give a new goal and mess up the path
			self util::script_delay();
		}
		// Make sure we get off the ground otherwise our lookahead will have issues
		else if( DistanceSquared( self.origin, self.goalpos ) < 100*100 && ( self.goalpos[2] > old_goalpos[2] + 10 || self.origin[2] + 10 < self.goalpos[2] ) )
		{
			self SetVehGoalPos( self.goalpos, true );
			self PathVariableOffset( (0,0,20), 2 );
			self util::waittill_any_timeout( 4, "near_goal", "force_goal" );
		}
		else
		{
			goalpos = self quadrotor_get_closest_node();
			self SetVehGoalPos( goalpos, true );
			self util::waittill_any_timeout( 2, "near_goal", "force_goal" );
		}
	}
	
	assert( IsAlive( self ) );
	
	if ( !self flag::exists( "goal_reached" ) )
	{
		self flag::init( "goal_reached" );
	}

	searchRadius = 100;
	goalfailures = 0;
	
	while( 1 )
	{
		self waittill_pathing_done();
		self thread goal_flag_monitor();
		
		goalpos = undefined;
		
		while ( !IsDefined(goalpos) )
		{
		goalpos = quadrotor_find_new_position();
		}

		if ( isdefined( level.ai_quadrotor_goal ) )
		{
			goalpos = level.ai_quadrotor_goal;
		}

		adjustedGoal = self GetClosestPointOnNavVolume( goalpos, searchRadius );
		if ( isdefined( adjustedGoal ) )
		{
			goalpos = adjustedGoal;
		}

		self.goalpos = goalpos;

		self thread quadrotor_blink_lights();		
		if( self SetVehGoalPos( goalpos, true, 2 ) )
		{
			goalfailures = 0;
			
			if( isdefined( self.goal_node ) )
				self.goal_node.quadrotor_claimed = true;
			
			if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				if( RandomInt( 100 ) > 50 )
				{
					self SetLookAtEnt( self.enemy );
				}
			}
			
			self util::waittill_any_timeout( 12, "near_goal", "force_goal", "reached_end_node" );
		
			if( isdefined( self.enemy ) && self VehCanSee( self.enemy ) )
			{
				self SetLookAtEnt( self.enemy );
				wait RandomFloatRange( 3, 6 );
				self ClearLookAtEnt();
			}
			
			if( isdefined( self.goal_node ) )
				self.goal_node.quadrotor_claimed = undefined;
		}
		else
		{
			goalfailures++;

			if( isdefined( self.goal_node ) )
			{
				self.goal_node.quadrotor_fails = true;
			}
			
			if( goalfailures == 1 )
			{
				wait 0.5;
				continue; // try again
			}
			else if( goalfailures == 2 )
			{
				// just go up and down, then try to find another goal
				goalpos = self.origin;
			}
			else if( goalfailures == 3 )
			{
				// try to fix our position and go up and down
				goalpos = self.origin;
				self SetVehGoalPos( goalpos, true );
				self waittill( "near_goal" );
			}
			else if( goalfailures > 3 )
			{
				/#
				println( "WARNING: Quadrotor can't find path to goal over 4 times." + self.origin + " " + goalpos );
				line( self.origin, goalpos, (1,1,1), 1, 100 );
				#/
				// assign a new goal position because the one we have is probably bad
				self.goalpos = make_sure_goal_is_well_above_ground( goalpos );
			}
			
			old_goalpos = goalpos;
			
			offset = ( RandomFloatRange(-50,50), RandomFloatRange(-50,50), RandomFloatRange(50, 150) );
			
			goalpos = goalpos + offset;
			
			goalpos = quadrotor_adjust_goal_for_enemy_height( goalpos );
			
			if( self quadrotor_check_move( goalpos ) )
			{
				self SetVehGoalPos( goalpos, true );
				self util::waittill_any( "near_goal", "force_goal", "start_vehiclepath" );
				
				wait RandomFloatRange( 1, 3 );
				
				if( !self.vehonpath )
				{
					self SetVehGoalPos( old_goalpos, true );
					self util::waittill_any( "near_goal", "force_goal", "start_vehiclepath" );					
				}
			}
			wait 0.5;
		}	
	}
}

function quadrotor_get_closest_node()
{
	nodes = GetNodesInRadiusSorted( self.origin, 200, 0, 500, "Path" );
	
	if( nodes.size == 0 )
	{
		nodes = GetNodesInRadiusSorted( self.goalpos, 3000, 0, 2000, "Path" );
	}
	
	foreach( node in nodes )
	{
		if( node.type == "BAD NODE" )
		{
			continue;
		}
		
		return make_sure_goal_is_well_above_ground( node.origin );
	}
	
	return self.origin;
}

function quadrotor_find_new_position()
{
	position = undefined;
		
	while ( !isdefined( position ) )
   	{
		wait( 1 );
		position = self GetRandomPointOnNavVolume();
   	}
	
	goalpos = self.origin;// TODO need new way of find new position
	
	return goalpos;
}

function quadrotor_teleport_to_nearest_node()
{
	self.origin = self quadrotor_get_closest_node();
}

function quadrotor_exit_vehicle()
{
	self waittill( "exit_vehicle", player );
	
	player.ignoreme = false;
	player DisableInvulnerability();
	//TODO T7 - function port if needed
	//player SetClientDvar( "cg_fov", 65 );
	
	self ShowPart( "tag_turret" );
	self ShowPart( "body_animate_jnt" );
	self ShowPart( "tag_flaps" );
	self ShowPart( "tag_ammo_case" );
	self HidePart( "tag_viewmodel" );
	self SetHeliHeightLock( false );
	self EnableAimAssist();
	self SetVehicleType( self.original_vehicle_type );
	self.attachedpath = undefined;
	self quadrotor_teleport_to_nearest_node();
	self.goalpos = self.origin;
}

function quadrotor_scripted()
{
	// do nothing state
	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self DisableAimAssist();
		self HidePart( "tag_turret" );
		self HidePart( "body_animate_jnt" );
		self HidePart( "tag_flaps" );
		self HidePart( "tag_ammo_case" );
		self ShowPart( "tag_viewmodel" );
		self SetHeliHeightLock( true );
		self thread vehicle_death::vehicle_damage_filter( "firestorm_turret" );
		self thread quadrotor_set_team( driver.team );
		driver.ignoreme = true;
		driver EnableInvulnerability();
		//TODO T7 - function port if needed
		//driver SetClientDvar( "cg_fov", 90 );
		self SetVehicleType( "heli_quadrotor_rts_player" );
		
		if( isdefined( self.vehicle_weapon_override ) )
		{
			self SetVehWeapon( self.vehicle_weapon_override );
		}
		
		self thread quadrotor_exit_vehicle();
		//self thread quadrotor_update_rumble();
		self thread quadrotor_collision_player();
		//self thread quadrotor_self_destruct();
	}
	
	if( isdefined( self.goal_node ) && isdefined( self.goal_node.quadrotor_claimed ) )
	{
		self.goal_node.quadrotor_claimed = undefined;
	}
	
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();
	self PathVariableOffsetClear();
	self PathFixedOffsetClear();
	self ClearLookAtEnt();
}

function quadrotor_get_damage_effect( health_pct )
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

function quadrotor_play_single_fx_on_tag( effect, tag )
{	
	if( isdefined( self.damage_fx_ent ) )
	{
		if( self.damage_fx_ent.effect == effect )
		{
			// already playing
			return;
		}
		self.damage_fx_ent delete();
	}
	
	
	ent = Spawn( "script_model", ( 0, 0, 0 ) );
	ent SetModel( "tag_origin" );
	ent.origin = self GetTagOrigin( tag );
	ent.angles = self GetTagAngles( tag );
	ent NotSolid();
	ent Hide();
	ent LinkTo( self, tag );
	ent.effect = effect;
	playfxontag( effect, ent, "tag_origin" );
	ent playsound("veh_qrdrone_sparks");

		
	self.damage_fx_ent = ent;
}

function quadrotor_update_damage_fx()
{
	max_health = self.healthdefault;
	if( isdefined( self.health_max ) )
	{
		max_health = self.health_max;
	}
	
	effect = quadrotor_get_damage_effect( self.health / max_health );
	if( isdefined( effect ) )
	{
		quadrotor_play_single_fx_on_tag( effect, "tag_origin" );	
	}
	else
	{
		if( isdefined( self.damage_fx_ent ) )
		{
			self.damage_fx_ent delete();
		}
	}
}

function quadrotor_damage()
{
	self endon( "crash_done" );
	
	while( isdefined(self) )
	{
		self waittill( "damage", damage, undefined /*attacker*/, dir, point, type );
		
		if( self.health > 0 && damage > 1 )			// emp does one damage and we don't want to look like it damaged us
		{
			quadrotor_update_damage_fx();
		}
		
		if( isdefined( self.off ) )
		{
			continue;
		}
		
		if( type == "MOD_EXPLOSIVE" || type == "MOD_GRENADE_SPLASH" || type == "MOD_PROJECTILE_SPLASH" )
		{
			self SetVehVelocity( self.velocity + VectorNormalize(dir) * 300 );
			ang_vel = self GetAngularVelocity();
			ang_vel += ( RandomFloatRange( -300, 300 ), RandomFloatRange( -300, 300 ), RandomFloatRange( -300, 300 ) );
			self SetAngularVelocity( ang_vel );
		}
		else
		{
			ang_vel = self GetAngularVelocity();
			yaw_vel = RandomFloatRange( -320, 320 );
		
			if( yaw_vel < 0 )
				yaw_vel -= 150;
			else
				yaw_vel += 150;
			
			ang_vel += ( RandomFloatRange( -150, 150 ), yaw_vel, RandomFloatRange( -150, 150 ) );
			self SetAngularVelocity( ang_vel );
		}
		
		wait 0.3;
	}
}

function quadrotor_cleanup_fx()
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

function quadrotor_death()
{
	wait 0.1;
	
	self notify( "nodeath_thread" );	// Kill off the vehicle_death::main thread
	
	self waittill( "death", attacker, damageFromUnderneath, weapon, point, dir );
	
	self notify( "nodeath_thread" );	// Kill off the vehicle_death::main thread, just making sure
	
	if( isdefined( self.goal_node ) && isdefined( self.goal_node.quadrotor_claimed ) )
	{
		self.goal_node.quadrotor_claimed = undefined;
	}
	
	if( isdefined( self.delete_on_death ) )
	{
		if ( isdefined( self ) )
		{
			self quadrotor_cleanup_fx();
			self delete();
		}
		
		return;
	}
	
	if ( !isdefined( self ) )
	{
		return;
	}
	
	self endon( "death" ); //quit thread if deleted
	
	self vehicle_death::death_cleanup_level_variables();			
	
	self DisableAimAssist();
	
	self death_fx();
	self thread vehicle_death::death_radius_damage();
	self thread vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	
	self vehicle::toggle_tread_fx( false );
	self vehicle::toggle_exhaust_fx( false );
	self vehicle::toggle_sounds( false );
	self vehicle::lights_off();
	self thread quadrotor_crash_movement( attacker, dir );
	
	self quadrotor_cleanup_fx();
	
	self waittill( "crash_done" );
	
	// A dynEnt will be spawned in the collision thread when it hits the ground and "crash_done" notify will be sent
	//self freeVehicle();
	//self Hide(); // Hide our self so the particle effect doesn't blink out
	//wait 5;
	self delete();
}

function death_fx()
{
	self vehicle::do_death_fx();
	self playsound("veh_qrdrone_sparks");
}

function quadrotor_crash_movement( attacker, hitdir )
{
	self endon( "crash_done" );
	self endon( "death" );
	
	self CancelAIMove();
	self ClearVehGoalPos();	
	self ClearLookAtEnt();
	
	self SetPhysAcceleration( ( 0, 0, -800 ) );
	self.vehcheckforpredictedcrash = true; // code field to get veh_predictedcollision notify
	
	if( !isdefined( hitdir ) )
	{
		hitdir = (1,0,0);
	}
	
	side_dir = VectorCross( hitdir, (0,0,1) );
	side_dir_mag = RandomFloatRange( -100, 100 );
	side_dir_mag += math::sign( side_dir_mag ) * 80;
	side_dir *= side_dir_mag;
	
	self SetVehVelocity( self.velocity + (0,0,100) + VectorNormalize( side_dir ) );

	ang_vel = self GetAngularVelocity();
	ang_vel = ( ang_vel[0] * 0.3, ang_vel[1], ang_vel[2] * 0.3 );
	
	yaw_vel = RandomFloatRange( 0, 210 ) * math::sign( ang_vel[1] );
	yaw_vel += math::sign( yaw_vel ) * 180;
	
	ang_vel += ( RandomFloatRange( -1, 1 ), yaw_vel, RandomFloatRange( -1, 1 ) );
	
	self SetAngularVelocity( ang_vel );
	
	self.crash_accel = RandomFloatRange( 75, 110 );
	
	if( !isdefined( self.off ) )
	{
		self thread quadrotor_crash_accel();
	}
	self thread quadrotor_collision();
	
	//drone death sounds JM - play 1 shot hit, turn off main loop, thread dmg loop
	self playsound("veh_qrdrone_dmg_hit");
	self vehicle::toggle_sounds( 0 );
	
	if( !isdefined( self.off ) )
	{
		self thread qrotor_dmg_snd();
	}

	wait 0.1;
	
	if( RandomInt( 100 ) < 40 && !isdefined( self.off ) )
	{
		self thread quadrotor_fire_for_time( RandomFloatRange( 0.7, 2.0 ) );
	}
	
	wait 15;
	
	// failsafe notify
	self notify( "crash_done" );
}


function qrotor_dmg_snd()
{
	dmg_ent = Spawn("script_origin", self.origin);
	dmg_ent linkto (self);
	dmg_ent PlayLoopSound ("veh_qrdrone_dmg_loop");
	self util::waittill_any("crash_done", "death");
	dmg_ent stoploopsound(1);
	wait (2);
	dmg_ent delete();
}


function quadrotor_fire_for_time( totalFireTime )
{
	self endon( "crash_done" );
	self endon( "change_state" );
	self endon( "death" );
	
	if( isdefined( self.emped ) )
		return;
	
	weapon = self SeatGetWeapon( 0 );
	fireTime = weapon.fireTime;
	time = 0;
	aiFireChance = 1;
	
	if( weapon.name == "quadrotor_turret_explosive" )
	{
		if( totalFireTime < fireTime * 2 )
			totalFireTime = fireTime * 2;
		
		// 1 in 2 bullets will be real
		aiFireChance = 1;
	}
	else
	{
		// fire less, unlees shooting player or a bigdog or mentioned specifically from level script
		if( ( isdefined( self.enemy ) && !IsPlayer( self.enemy ) && !IS_TRUE( self.enemy.isBigDog ) ) || 
		   isdefined( self.fire_half_blanks )  )
		{
			// 1 in 2 bullets will be real
			aiFireChance = 2;
		}
	}
	
	fireCount = 1;
	
	while( time < totalFireTime && !isdefined( self.emped ) )
	{
		if( isdefined( self.enemy ) && isdefined(self.enemy.attackerAccuracy) && self.enemy.attackerAccuracy == 0 )
		{
			self FireWeapon( 0, self.enemy );
		}
		else if( aiFireChance > 1 )
		{
			self FireWeapon();
		}
		else
		{
			self FireWeapon();
		}
		
		fireCount++;
		wait fireTime;
		time += fireTime;
	}
}

function quadrotor_crash_accel()
{
	self endon( "crash_done" );
	self endon( "death" );
	
	count = 0;
	
	while( 1 )
	{
		self SetVehVelocity( self.velocity + AnglesToUp( self.angles ) * self.crash_accel );
		self.crash_accel *= 0.98;
		
		wait 0.1;
		
		count++;
		if( count % 8 == 0 )
		{
			if( RandomInt( 100 ) > 40 )
			{
				if( self.velocity[2] > 150.0 )
				{
					self.crash_accel *= 0.75;
				}
				else if( self.velocity[2] < 40.0 && count < 60 )
				{
					if( Abs( self.angles[0] ) > 30 || Abs( self.angles[2] ) > 30 )
					{
						self.crash_accel = RandomFloatRange( 160, 200 );
					}
					else
					{
						self.crash_accel = RandomFloatRange( 85, 120 );
					}
				}
			}
		}
	}
}

function quadrotor_predicted_collision()
{
	self endon( "crash_done" );
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "veh_predictedcollision", velocity, normal );
		if( normal[2] >= 0.6 )
		{
			self notify( "veh_collision", velocity, normal );
		}
	}
}

function quadrotor_collision_player()
{
	self endon( "change_state" );
	self endon( "crash_done" );
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "veh_collision", velocity, normal );
		driver = self GetSeatOccupant( 0 );
		if( isdefined( driver ) && LengthSquared( velocity ) > 70*70 )
		{
			Earthquake( 0.25, 0.25, driver.origin, 50 );
			driver PlayRumbleOnEntity( "damage_heavy" );
		}
	}
}

function quadrotor_collision()
{
	self endon( "change_state" );
	self endon( "crash_done" );
	self endon( "death" );
	
	if( !IsAlive( self ) )
	{
		self thread quadrotor_predicted_collision();
	}
	
	while( 1 )
	{
		self waittill( "veh_collision", velocity, normal );
		ang_vel = self GetAngularVelocity() * 0.5;
		self SetAngularVelocity( ang_vel );
		
		// bounce off walls
		if( normal[2] < 0.6 || ( IsAlive( self ) && !isdefined( self.emped ) ) )
		{
			self SetVehVelocity( self.velocity + normal * 90 );
			self PlaySound( "veh_wasp_wall_imp" );
			if( normal[2] < 0.6 )
			{
				fx_origin = self.origin - normal * 28;
			}
			else
			{
				fx_origin = self.origin - normal * 10;
			}
			PlayFX( level._effect[ "quadrotor_nudge" ], fx_origin, normal );
		}
		else
		{
			
			if( isdefined( self.emped ) )
			{
				if( isdefined( self.bounced ) )
				{
					self playsound( "veh_wasp_wall_imp" );
					self SetVehVelocity( (0,0,0) );
					self SetAngularVelocity( (0,0,0) );
					if( self.angles[0] < 0 )
					{
						if( self.angles[0] < -15 )
						{
							self.angles = ( -15, self.angles[1], self.angles[2] );
						}
						else if( self.angles[0] > -10 )
						{
							self.angles = ( -10, self.angles[1], self.angles[2] );
						}
					}
					else
					{
						if( self.angles[0] > 15 )
						{
							self.angles = ( 15, self.angles[1], self.angles[2] );
						}
						else if( self.angles[0] < 10 )
						{
							self.angles = ( 10, self.angles[1], self.angles[2] );
						}
					}
					
					self.bounced = undefined;
					self notify( "landed" );
					return;
				}
				else
				{
					self.bounced = true;
					self SetVehVelocity( self.velocity + normal * 120 );
					self playsound( "veh_wasp_wall_imp" );
					if( normal[2] < 0.6 )
					{
						fx_origin = self.origin - normal * 28;
					}
					else
					{
						fx_origin = self.origin - normal * 10;
					}
					PlayFX( level._effect[ "quadrotor_nudge" ], fx_origin, normal );
				}
			}
			else
			{
				CreateDynEntAndLaunch( self.deathmodel, self.origin, self.angles, self.origin, self.velocity * 0.01, level._effect[ "quadrotor_crash" ] );
				self playsound( "veh_qrdrone_explo" );
				self thread death_fire_loop_audio();
				self notify( "crash_done" );
			}
		}
	}
}

function death_fire_loop_audio()
{
	sound_ent = Spawn( "script_origin", self.origin );
	sound_ent PlayLoopSound( "veh_qrdrone_death_fire_loop" , .1 ); 
	wait 11;
	sound_ent StopLoopSound( 1 );
	sound_ent delete();
}

function quadrotor_set_team( team )
{
	self.team = team;
	if( isdefined( self.vehmodelenemy ) )
	{
		if( isSubstr( level.script, "so_rts_" ) )
		{
		}
		else
		{
			if( team == "axis" )
			{
				self SetModel( self.vehmodelenemy );
				self SetVehWeapon( GetWeapon( "quadrotor_turret_enemy" ) );
			}
			else
			{
				self SetModel( self.vehmodel );
				self SetVehWeapon( GetWeapon( "quadrotor_turret" ) );
			}
		}
	}
	
	if( !isdefined( self.off ) )
	{
		quadrotor_blink_lights();
	}
}

function quadrotor_blink_lights()
{
	self endon( "death" );
	
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
}

// Lots of gross hardcoded values! :( 
function quadrotor_update_rumble()
{
	self endon( "death" );
	self endon( "exit_vehicle" );

	while ( 1 )
	{
		vr = Abs( self GetSpeed() / self GetMaxSpeed() );
		
		if ( vr < 0.1 )
		{
			level.player PlayRumbleOnEntity( "quadrotor_fly" );		
			wait( 0.35 );						
		}
		else
		{
			time = RandomFloatRange( 0.1, 0.2 );
			Earthquake( RandomFloatRange( 0.1, 0.15 ), time, self.origin, 200 );
			level.player PlayRumbleOnEntity( "quadrotor_fly" );		
			wait( time );							
		}
	}
}

function quadrotor_self_destruct()
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	
	const max_self_destruct_time = 5;
	
	self_destruct = false;
	self_destruct_time = 0;
	
	while ( 1 )
	{
		if ( !self_destruct )
		{
			if ( level.player MeleeButtonPressed() )
			{
				self_destruct = true;
				self_destruct_time = max_self_destruct_time;				
			}
			
			WAIT_SERVER_FRAME;			
			continue;
		}
		else
		{
			IPrintLnBold( self_destruct_time );
			
			wait( 1 );
			
			self_destruct_time -= 1;
			if ( self_destruct_time == 0 )
			{
				driver = self GetSeatOccupant( 0 );
				if( isdefined(driver) )
				{
					driver DisableInvulnerability();
				}

				Earthquake( 3, 1, self.origin, 256 );
				RadiusDamage( self.origin, 1000, 15000, 15000, level.player, "MOD_EXPLOSIVE" );
				self DoDamage( self.health + 1000, self.origin );
			}
			
			continue;
		}
	}
}

function quadrotor_level_out_for_landing()
{
	self endon( "death" );
	self endon( "emped" );
	self endon( "landed" );
	
	while( isdefined( self.emped ) )
	{
		velocity = self.velocity;	// setting the angles clears the velocity so we save it off and set it back
		self.angles = ( self.angles[0] * 0.85, self.angles[1], self.angles[2] * 0.85 );
		ang_vel = self GetAngularVelocity() * 0.85;
		self SetAngularVelocity( ang_vel );
		self SetVehVelocity( velocity );
		WAIT_SERVER_FRAME;
	}
}

function quadrotor_emped()
{
	self endon( "death" );
	self notify( "emped" );
	self endon( "emped" );
	
	self.emped = true;
	
	PlaySoundAtPosition( "veh_qrdrone_emp_down", self.origin );
	self quadrotor_off();
	
	self SetPhysAcceleration( ( 0, 0, -600 ) );
	self thread quadrotor_level_out_for_landing();
	self thread quadrotor_collision();
	
	if( !isdefined( self.stun_fx ) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_origin", (0,0,0), (0,0,0) );
		PlayFXOnTag( level._effect[ "quadrotor_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait RandomFloatRange( 4, 7 );
	
	self.stun_fx delete();
	
	self.emped = undefined;
	self SetPhysAcceleration( ( 0, 0, 0 ) );
	self quadrotor_on();
	self playsound ("veh_qrdrone_boot_qr");
}

function quadrotor_temp_bullet_shield( invulnerable_time )
{
	self notify( "bullet_shield" );
	self endon( "bullet_shield" );
	
	self.bullet_shield = true;
	
	wait invulnerable_time;
	
	if( isdefined( self ) )
	{
		self.bullet_shield = undefined;
		wait 3;
		if( isdefined( self ) && self.health < 40 )
		{
			self.health = 40;
		}
	}
}

function QuadrotorCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	driver = self GetSeatOccupant( 0 );
	
	if( weapon.isEmp && sMeansOfDeath != "MOD_IMPACT" )
	{
		if( !isdefined( driver ) )
		{
			if( !isdefined( self.off ) )
			{
				self thread quadrotor_emped();
			}
		}
	}
	
	
	if( isdefined( driver ) )
	{
		if( sMeansOfDeath == "MOD_BULLET" )
		{
			if( isdefined( self.bullet_shield ) )
			{
				iDamage = 3;
			}
		}
		
		if( !isdefined( self.bullet_shield ) )
		{
			// Try not to let the play die suddenly
			self thread quadrotor_temp_bullet_shield( 0.35 );
		}
		
		// Lets get some hit indicators
		//driver FinishPlayerDamage( eInflictor, eAttacker, 1, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, "none", 0, psOffsetTime );
	}
	
	return iDamage;
}
