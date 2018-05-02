#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\flag_shared;

#using scripts\shared\abilities\_ability_power;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;

#insert scripts\shared\ai\utility.gsh;

#define DRONE_HUD_MARKED_TARGET "hud_proto_rts_secure_target"
#define DRONE_HUD_ELEM_CONSTANT_SIZE true	

#precache( "material", DRONE_HUD_MARKED_TARGET );
#precache( "fx", "_t6/electrical/fx_elec_sp_emp_stun_quadrotor" );

#namespace escort_drone;

REGISTER_SYSTEM( "escort_drone", &__init__, undefined )

function __init__()
{	
	level._effect[ "escort_drone_stun" ] 		= "_t6/electrical/fx_elec_sp_emp_stun_quadrotor";
}

function escort_drone_think( player )
{
	assert( IsDefined( player ) );
	
	self.n_tetherMax = player._gadgets_player.escortTetherMaxDist;
	self.n_tetherMin = player._gadgets_player.escortTetherMinDist;
	
	self.n_tetherMaxSq = self.n_tetherMax * self.n_tetherMax;
	self.n_tetherMinSq = self.n_tetherMin * self.n_tetherMin;
	
	self.n_target_time = player._gadgets_player.escortTargetAcquireTime;
	self.n_burstCountMin = player._gadgets_player.escortBurstCountMin;
	self.n_burstCountMax = player._gadgets_player.escortBurstCountMax;
	self.n_burstWaitTime = player._gadgets_player.escortBurstWaitTime;
	self.n_burstPowerLoss = player._gadgets_player.escortBurstPowerLoss;
	
	self.n_BulletPowerLoss = player._gadgets_player.escortBulletPowerLoss;
	self.n_ExplosionPowerLoss = player._gadgets_player.escortExplosionPowerLoss;
	self.n_MiscPowerLoss = player._gadgets_player.escortMiscPowerLoss;
	
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
		//self.heightAboveGround = 100;
		//making tune-able
		self.heightAboveGround = player._gadgets_player.escortHoverHeight;
	}
	
	if( !isdefined( self.goalradius ) )
	{
		self.goalradius = 300;
	}
	
	if( !isdefined( self.goalpos ) )
	{
		self.goalpos = self.origin;
	}
	
	self.original_vehicle_type = self.vehicletype;
	
	self.state_machine = statemachine::create( "edbrain", self );
	main 		= self.state_machine statemachine::add_state( "main", undefined, &escort_drone_main, undefined );
	scripted 	= self.state_machine statemachine::add_state( "scripted", undefined, &escort_drone_scripted, undefined );
	
	vehicle_ai::add_interrupt_connection( "main", "scripted", "enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "scripted" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "exit_vehicle" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "main" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "scripted_done" );
	
	self HidePart( "tag_viewmodel" );
	
	self.overrideVehicleDamage = &EscortDroneCallback_VehicleDamage;
		
	// Set the first state
	if ( isdefined( self.script_startstate ) )
	{
		if( self.script_startstate == "off" )
		{
			self escort_drone_off();
		}
		else
		{
			self.state_machine statemachine::set_state( self.script_startstate );
		}
	}
	else
	{
		// Set the first state
		self escort_drone_start_ai();
	}
	
	self thread escort_drone_set_team( self.team );
	
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

function escort_drone_start_scripted()
{
	self.state_machine statemachine::set_state( "scripted" );
}

function escort_drone_off()
{
	self.state_machine statemachine::set_state( "scripted" );
	self vehicle::lights_off();
	self vehicle::toggle_tread_fx( 0 );
	self vehicle::toggle_sounds( 0 );
	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
	self.off = true;
	
}

function escort_drone_on()
{
	self vehicle::lights_on();
	self vehicle::toggle_tread_fx( 1 );
	self vehicle::toggle_sounds( 1 );
	self EnableAimAssist();
	self.off = undefined;
	self escort_drone_start_ai();
}

function escort_drone_start_ai()
{
	self.goalpos = self.origin;
	self.state_machine statemachine::set_state( "main" );
}

function escort_drone_main()
{
	self thread escort_drone_blink_lights();
	self thread escort_drone_fireupdate();
	self thread escort_drone_movementupdate();
	self thread escort_drone_collision();
}

function escort_drone_fireupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	max_range = 2000;

	no_target_delay = 0.05;
	
	self thread hud_marker_create();

	while( 1 )
	{
		if ( IsDefined( self.enemy ) && self VehCanSee( self.enemy ) && self.enemy is_in_combat() )  //only shoot at guys who are engaging the player
		{			
			wait( self.n_target_time );  //Tune-able - Target Acquisition Time
			
			if ( IsDefined( self.enemy ) && DistanceSquared( self.enemy.origin, self.origin ) < max_range * max_range ) 
			{
				self SetTurretTargetEnt( self.enemy );
				self escort_drone_fire_for_time( RandomFloatRange( self.n_burstCountMin, self.n_burstCountMax ) );  //Tune-able - burst count			
			}
			
			wait ( self.n_burstWaitTime );  //Tune-able - Time between bursts
		}
		else
		{
			wait no_target_delay;
		}
	}
}

function hud_marker_create()  // self = drone
{	
	hud_marked_target = NewHudElem();
	
	hud_marked_target.horzAlign = "right";
	hud_marked_target.vertAlign = "middle";

	hud_marked_target.sort = 2;	
	
	hud_marked_target.hidewheninmenu = true;
	hud_marked_target.immunetodemogamehudsettings = true;	
		
	const Z_OFFSET = 90;
	
	while ( isdefined( self ) )
	{
		if ( isdefined( self.enemy ) )
		{
			hud_marked_target.alpha = 1;
			
			hud_marked_target.x = self.enemy.origin[0];
			hud_marked_target.y = self.enemy.origin[1];
			hud_marked_target.z = self.enemy.origin[2] + Z_OFFSET;
			
			hud_marked_target SetShader( DRONE_HUD_MARKED_TARGET, 5, 5 );
			hud_marked_target SetWaypoint( DRONE_HUD_ELEM_CONSTANT_SIZE );	
		
		}
		else
		{
			hud_marked_target.alpha = 0;
		}
		
		WAIT_SERVER_FRAME;
	}
	
	hud_marked_target Destroy();
}

function escort_drone_check_move( position )
{
	results = PhysicsTraceEx( self.origin, position, (-15,-15,-5), (15,15,5), self );
	
	if( results["fraction"] == 1 )
	{
		return true;
	}
	
	return false;
}

function escort_drone_adjust_goal_for_enemy_height( goalpos )
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

function escort_drone_movementupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	assert( IsAlive( self ) );
	
	while ( !isdefined( self.owner ) )
	{
		
		wait 2;
	}
	
	// make sure when we start this that we get above the ground
	old_goalpos = self.goalpos;
	self.goalpos = self make_sure_goal_is_well_above_ground( self.goalpos );
	
	if ( !self flag::exists( "goal_reached" ) )
	{
		self flag::init( "goal_reached" );
	}

	goalfailures = 0;
	
	while( 1 )
	{
		self thread goal_flag_monitor();
		
		goalpos = escort_drone_find_new_position();
		
		while ( !IsDefined( goalpos ) )
		{
			wait 3;
			goalpos = escort_drone_find_new_position();
		}
		
		self.goalpos = goalpos;

		self thread escort_drone_blink_lights();		
		if( self SetVehGoalPos( goalpos, true, 2 ) )
		{
			goalfailures = 0;
			
			if( isdefined( self.goal_node ) )
				self.goal_node.escort_drone_claimed = true;
			
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
				wait RandomFloatRange( 2, 3 );
				self ClearLookAtEnt();
			}
		}
		else
		{
			goalfailures++;

			if( isdefined( self.goal_node ) )
			{
				self.goal_node.escort_drone_fails = true;
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
			
			goalpos = escort_drone_adjust_goal_for_enemy_height( goalpos );
			
			if( self escort_drone_check_move( goalpos ) )
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

function escort_drone_get_closest_node()
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

function escort_drone_find_new_position()
{
	position = self.origin;
	
	if ( IsDefined( self.owner ) )
	{
		n_distToPlayerSq = Distance2DSquared( self.origin, self.owner.origin );
	
		if ( n_distToPlayerSq >= self.n_tetherMaxSq )
		{
			forward_vector = anglestoforward( self.owner.angles ) * self.n_tetherMin;
			position = self.owner.origin + ( forward_vector + (0,0,100) );
		}
	}
		
	adjustedgoalpos = position;
	
	if( isdefined( adjustedgoalpos ) )
	{
		position = adjustedgoalpos;
	}
	
	position = self GetClosestPointOnNavVolume( position, 200 );
	
	return position;
}

function escort_drone_teleport_to_nearest_node()
{
	self.origin = self escort_drone_get_closest_node();
}

function escort_drone_exit_vehicle()
{
	self waittill( "exit_vehicle", player );
	
	player.ignoreme = false;
	player DisableInvulnerability();
	
	self SetHeliHeightLock( false );
	self EnableAimAssist();
	self.attachedpath = undefined;
	self escort_drone_teleport_to_nearest_node();
	self.goalpos = self.origin;
}

function escort_drone_scripted()
{
	// do nothing state
	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self DisableAimAssist();
		self SetHeliHeightLock( true );
		self thread escort_drone_set_team( driver.team );
		driver.ignoreme = true;
		driver EnableInvulnerability();

		self thread escort_drone_exit_vehicle();
		self thread escort_drone_collision_player();
	}
	
	if( isdefined( self.goal_node ) && isdefined( self.goal_node.escort_drone_claimed ) )
	{
		self.goal_node.escort_drone_claimed = undefined;
	}
	
	self ClearTargetEntity();
	self CancelAIMove();
	self ClearVehGoalPos();
	self PathVariableOffsetClear();
	self PathFixedOffsetClear();
	self ClearLookAtEnt();
}

function escort_drone_play_single_fx_on_tag( effect, tag )
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

function escort_drone_cleanup_fx()
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

function escort_drone_fire_for_time( totalFireTime )
{
	self endon( "crash_done" );
	self endon( "change_state" );
	self endon( "death" );
	
	if( isdefined( self.emped ) )
		return;
	
	weapon = self SeatGetWeapon( 0 );
	fireTime = weapon.fireTime;
	time = 0;
	
	self.owner ability_power::power_loss_event( undefined, self.n_burstPowerLoss, "drone_fired" );
	
	fireCount = 1;
	
	while( time < totalFireTime && !isdefined( self.emped ) )
	{
		self FireWeapon();
		
		fireCount++;
		wait fireTime;
		time += fireTime;
	}
}


function escort_drone_predicted_collision()
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

function escort_drone_collision_player()
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

function escort_drone_collision()
{
	self endon( "change_state" );
	self endon( "crash_done" );
	self endon( "death" );
	
	if( !IsAlive( self ) )
	{
		self thread escort_drone_predicted_collision();
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
			self PlaySound( "veh_qrdrone_wall" );
			if( normal[2] < 0.6 )
			{
				fx_origin = self.origin - normal * 28;
			}
			else
			{
				fx_origin = self.origin - normal * 10;
			}
			//PlayFX( level._effect[ "escort_drone_nudge" ], fx_origin, normal );
		}
		else
		{
			
			if( isdefined( self.emped ) )
			{
				if( isdefined( self.bounced ) )
				{
					self playsound( "veh_qrdrone_wall" );
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
					self playsound( "veh_qrdrone_wall" );
					if( normal[2] < 0.6 )
					{
						fx_origin = self.origin - normal * 28;
					}
					else
					{
						fx_origin = self.origin - normal * 10;
					}
					//PlayFX( level._effect[ "escort_drone_nudge" ], fx_origin, normal );
				}
			}
			else
			{
				//CreateDynEntAndLaunch( self.deathmodel, self.origin, self.angles, self.origin, self.velocity * 0.01, level._effect[ "escort_drone_crash" ], 1 );
				self playsound( "veh_qrdrone_explo" );
				self notify( "crash_done" );
			}
		}
	}
}

function escort_drone_set_team( team )
{
	self.team = team;
	
	if( !isdefined( self.off ) )
	{
		escort_drone_blink_lights();
	}
}

function escort_drone_blink_lights()
{
	self endon( "death" );
	
	self vehicle::lights_off();
	wait 0.1;
	self vehicle::lights_on();
}

function escort_drone_level_out_for_landing()
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

function escort_drone_emped()
{
	self endon( "death" );
	self notify( "emped" );
	self endon( "emped" );
	
	self.emped = true;
	
	PlaySoundAtPosition( "veh_qrdrone_emp_down", self.origin );
	self escort_drone_off();
	
	self SetPhysAcceleration( ( 0, 0, -600 ) );
	self thread escort_drone_level_out_for_landing();
	self thread escort_drone_collision();
	
	if( !isdefined( self.stun_fx ) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_origin", (0,0,0), (0,0,0) );
		PlayFXOnTag( level._effect[ "escort_drone_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait RandomFloatRange( 4, 7 );
	
	self.stun_fx delete();
	
	self.emped = undefined;
	self SetPhysAcceleration( ( 0, 0, 0 ) );
	self escort_drone_on();
	self playsound ("veh_qrdrone_boot_qr");
}

function escort_drone_temp_bullet_shield( invulnerable_time )
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

function EscortDroneCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	driver = self GetSeatOccupant( 0 );
	
	if( weapon.isEmp && sMeansOfDeath != "MOD_IMPACT" )
	{
		if( !isdefined( driver ) )
		{
			if( !isdefined( self.off ) )
			{
				self thread escort_drone_emped();
			}
		}
	}
	
	power_loss = iDamage * escort_drone_power_loss_multiplier( sMeansOfDeath );
				
	if ( self.owner.cclass_power.powerRemaining > power_loss )
	{
		self.owner ability_power::power_loss_event( undefined, power_loss, "shooter" );
	}
	else if ( self.owner.cclass_power.powerRemaining > 0 )
	{
		self.owner ability_power::power_loss_event( undefined, self.owner.cclass_power.powerRemaining, "shooter" );
	}
	
	iDamage = 1;
	
	return iDamage;
}

function escort_drone_power_loss_multiplier( sMeansOfDeath )
{
	switch(sMeansOfDeath)
	{
		case "MOD_CRUSH":
		case "MOD_TELEFRAG":
		case "MOD_SUICIDE":
		case "MOD_DROWN":
		case "MOD_HIT_BY_OBJECT":
		case "MOD_FALLING":
		case "MOD_PROJECTILE":
		case "MOD_BURNED":
		case "MOD_HEAD_SHOT":
		case "MOD_UNKNOWN":
		case "MOD_TRIGGER_HURT":
		case "MOD_MELEE":
		case "MOD_MELEE_WEAPON_BUTT":
			return self.n_MiscPowerLoss;
			break;
			
		case "MOD_EXPLOSIVE":
		case "MOD_PROJECTILE_SPLASH":
		case "MOD_GRENADE":
		case "MOD_GRENADE_SPLASH":
			return self.n_ExplosionPowerLoss;
			break;
			
		case "MOD_PISTOL_BULLET":
		case "MOD_RIFLE_BULLET":
		case "MOD_IMPACT":
			return self.n_BulletPowerLoss;
			break;
	}
}

function is_in_combat()
{
	if ( IsDefined( self.archetype ) && IsDefined ( self.str_awareness_state ) && self.str_awareness_state == STATE_COMBAT )
	{
		return true;
	}
	
	return false;
}
