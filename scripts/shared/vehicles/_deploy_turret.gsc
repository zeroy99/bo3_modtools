#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\flag_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;

#insert scripts\shared\ai\utility.gsh;

#define TURRET_HUD_MARKED_TARGET "hud_proto_rts_secure_target"
#define TURRET_HUD_ELEM_CONSTANT_SIZE true	

#precache( "material", TURRET_HUD_MARKED_TARGET );

#namespace turret_gadget_deploy;

REGISTER_SYSTEM( "turret_gadget_deploy", &__init__, undefined )

function __init__()
{	
	//vehicle::add_main_callback( "turret_gadget_deploy",&turret_gadget_deploy_think );
}

function turret_gadget_deploy_think( player, power_callback, cutoff_power, resume_power )
{
	self.power_callback = power_callback; 
	self.cutoff_power = cutoff_power; 
	self.resume_power = resume_power; 
	
	self DisableAimAssist();
	
	self.state_machine = statemachine::create( "brain", self );
	
	main 		= self.state_machine statemachine::add_state( "main", undefined, undefined,&turret_gadget_deploy_main, undefined, undefined );
	scripted 	= self.state_machine statemachine::add_state( "scripted", undefined, undefined,&turret_gadget_deploy_scripted, undefined, undefined );
	
	vehicle_ai::add_interrupt_connection( "main", "scripted", "enter_vehicle" );
	vehicle_ai::add_interrupt_connection( "main", "scripted", "scripted" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "exit_vehicle" );
	vehicle_ai::add_interrupt_connection( "scripted", "main", "scripted_done" );
	
	self.overrideVehicleDamage =&TurretCallback_VehicleDamage;
	
	// Set the first state
	if ( isdefined( self.script_startstate ) )
	{
		if( self.script_startstate == "off" )
			self turret_gadget_deploy_off( self.angles );
		else
			self.state_machine statemachine::set_state( self.script_startstate );
	}
	else
	{
		// Set the first state
		turret_gadget_deploy_start_ai();
	}

	self laserOn();
}

function turret_gadget_deploy_start_scripted()
{
	self.state_machine statemachine::set_state( "scripted" );
}

function turret_gadget_deploy_start_ai()
{
	self.goalpos = self.origin;
	self.state_machine statemachine::set_state( "main" );
}

function turret_gadget_deploy_main()
{
	if( IsAlive( self ) )
	{
		self DisableAimAssist();
		self thread turret_gadget_deploy_fireupdate();
	}
}

function turret_gadget_deploy_off(angles)
{
	self.state_machine statemachine::set_state( "scripted" );
	self vehicle::lights_off();
	self LaserOff();
	self vehicle::toggle_sounds( 0 );
	self vehicle::toggle_exhaust_fx( 0 );
	
	if(!isdefined(angles))
		angles = self GetTagAngles( "tag_flash" );
		
	target_vec = self.origin + AnglesToForward( ( 0, angles[1], 0 ) ) * 1000;
	target_vec = target_vec + ( 0, 0, -1700 );
	self SetTargetOrigin( target_vec );		
	self.off = true;
	if( !isdefined( self.emped ) )
	{
		self DisableAimAssist();
	}
}

function turret_gadget_deploy_on()
{
	self vehicle::lights_on();
	self EnableAimAssist();
	self vehicle::toggle_sounds( 1 );
	
	self vehicle::toggle_exhaust_fx( 1 );
	self.off = undefined;
	
	turret_gadget_deploy_start_ai();
}

function turret_gadget_deploy_fireupdate_old()
{
	self endon( "death" );
	self endon( "change_state" );
	
	max_range = 1500;

	no_target_delay = 0.05;
	
	self.n_burstCountMin = 1;
	self.n_burstCountMax = 2;
	self.n_burstWaitTime = 1.5;
	
	self thread hud_marker_create();

	while( 1 )
	{
		if ( IsDefined( self.enemy ) && self VehCanSee( self.enemy ) )
		{			
			if ( IsDefined( self.enemy ) && DistanceSquared( self.enemy.origin, self.origin ) < max_range * max_range ) 
			{
				self SetTurretTargetEnt( self.enemy );
				self SetLookAtEnt(self.enemy);
				self turret_gadget_deploy_fire_for_time( RandomFloatRange( self.n_burstCountMin, self.n_burstCountMax ) );  //Tune-able - burst count			
				self ClearLookAtEnt();
			}
			
			wait ( self.n_burstWaitTime );
		}
		else
		{
			wait no_target_delay;
		}
	}
}


function has_enough_power(min_power)
{
	power = 100;
	if ( IsDefined( self.power_callback ) )
	{
		if ( IsDefined(self.owner) )
			power = self.owner [[self.power_callback]](self,0);
		else
			power = 0;
	}
	if ( power > min_power )
		return true;
	return false;
}


function boot_sound()
{
	self playsound ("veh_cic_turret_boot");	
}

function alert_sound()
{
	self playsound ("veh_turret_alert");
}

function scan_sound()
{
	self playloopsound( "veh_turret_servo" , .05 );
}

function has_visible_target()
{
	if( isdefined( self.enemy ) && IsAlive( self.enemy) && self VehCanSee( self.enemy ) && !IS_TRUE(self.enemy.ignoreme) )
		return true;
	return false;
}

//#define TURRET_BOOT_TIME 0.2
#define TURRET_BOOT_TIME 				GetDvarFloat("scr_turret_boot_timer")
#define TURRET_LOCK_TIME 				GetDvarFloat("scr_turret_lock_timer")
#define TURRET_BURST_MIN_DURATION		GetDvarFloat("scr_turret_burst_min_duration")
#define TURRET_BURST_MAX_DURATION		GetDvarFloat("scr_turret_burst_max_duration")
#define TURRET_BURST_MIN_DELAY			GetDvarFloat("scr_turret_burst_min_delay")
#define TURRET_BURST_MAX_DELAY			GetDvarFloat("scr_turret_burst_max_delay")
#define TURRET_BURST_MIN_DELAY_LONG		GetDvarFloat("scr_turret_burst_min_delay_long")
#define TURRET_BURST_MAX_DELAY_LONG		GetDvarFloat("scr_turret_burst_max_delay_long")
#define TURRET_ROT_SCALE_IDLE			GetDvarFloat("scr_turret_rot_scale_idle")
#define TURRET_ROT_SCALE_COMBAT			GetDvarFloat("scr_turret_rot_scale_combat")

function turret_gadget_deploy_fireupdate()
{
	self endon( "death" );
	self endon( "change_state" );
	
	cant_see_enemy_count = 0;

	DEFAULT(self.default_pitch,0);
	DEFAULT(self.scanning_arc,80);

	self boot_sound();
	
	wait TURRET_BOOT_TIME;

	origin = self GetTagOrigin( "tag_barrel" );
	
	if (!IsDefined(origin))
		origin = self.origin;
	
	left_look_at_pt = origin + AnglesToForward( self.angles + (self.default_pitch, self.scanning_arc, 0) ) * 1000;
	right_look_at_pt = origin + AnglesToForward( self.angles + (self.default_pitch, -self.scanning_arc, 0) ) * 1000;
	powerless_look_at_pt = origin + AnglesToForward( self.angles + (15.0, 0, 0) ) * 1000;
	
	self.min_power = self.cutoff_power;
	
	while( 1 )
	{
		if ( !self has_enough_power(self.min_power) )
		{
			self.min_power = self.resume_power;
			self SetTurretTargetVec( powerless_look_at_pt );
			wait 0.5;
		}
		else if( self has_visible_target() )
		{
			self.min_power = self.cutoff_power;
			self.turretRotScale = TURRET_ROT_SCALE_COMBAT;
			
			lock_time = 0.1;
			if( ( cant_see_enemy_count > 0 || !IS_EQUAL(self.last_enemy,self.enemy) ) && IsPlayer( self.enemy ) )
			{	
				self alert_sound();
				wait 0.1; 							//wait between alert sound and rotation
				lock_time = TURRET_LOCK_TIME;	
				self.last_enemy = self.enemy; 
			}
			
			cant_see_enemy_count = 0;
			
			for( i = 0; i < 3; i++ )
			{
				if ( self has_visible_target() )
				{
					self SetTurretTargetEnt( self.enemy );
					self util::waittill_notify_or_timeout( "turret_on_target", 1.0 );
					wait lock_time;                 //wait between rotation start and start firing
					lock_time = 0.1; 
					if ( self has_visible_target() )
					{
						self turret_gadget_deploy_fire_for_time( RandomFloatRange( TURRET_BURST_MIN_DURATION, TURRET_BURST_MAX_DURATION ) );
					}
					else
					{
						break;
					}
				}
				else
				{
					self ClearTargetEntity();
					break;
				}
				
				if( isdefined( self.enemy ) && IsPlayer( self.enemy ) )
					wait RandomFloatRange( TURRET_BURST_MIN_DELAY, TURRET_BURST_MAX_DELAY );
				else
					wait RandomFloatRange( TURRET_BURST_MIN_DELAY, TURRET_BURST_MAX_DELAY ) * 2;
			}
			
			if ( self has_visible_target() )
			{
				if( IsPlayer( self.enemy ) )
					wait RandomFloatRange( TURRET_BURST_MIN_DELAY_LONG, TURRET_BURST_MAX_DELAY_LONG );
				else
					wait RandomFloatRange( TURRET_BURST_MIN_DELAY_LONG, TURRET_BURST_MAX_DELAY_LONG ) * 2;
			}
		}
		else
		{
			self.min_power = self.cutoff_power;
			self.turretRotScale = TURRET_ROT_SCALE_IDLE;
			
			cant_see_enemy_count++;
			
			//wait 0.1;
			
			if( cant_see_enemy_count > 1 )
			{
				self.turret_state = 0;
				while( !isdefined( self.enemy ) || !(self VehCanSee( self.enemy )) )
				{
					if( self.turretontarget )
					{
						self.turret_state++;
						if( self.turret_state > 1 )
							self.turret_state = 0;
					}
					if( self.turret_state == 0 )
						self SetTurretTargetVec( left_look_at_pt );
					else 
						self SetTurretTargetVec( right_look_at_pt );
					
					wait 0.1;
				}
			}
			else
			{
				self ClearTargetEntity();
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}



function hud_marker_create()  // self = TURRET
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
			
			hud_marked_target SetShader( TURRET_HUD_MARKED_TARGET, 5, 5 );
			hud_marked_target SetWaypoint( TURRET_HUD_ELEM_CONSTANT_SIZE );	
		
		}
		else
		{
			hud_marked_target.alpha = 0;
		}
		
		WAIT_SERVER_FRAME;
	}
	
	hud_marked_target Destroy();
}

function turret_gadget_deploy_scripted()
{
	// do nothing state
	driver = self GetSeatOccupant( 0 );
	if( isdefined(driver) )
	{
		self.turretRotScale = 1;
		self DisableAimAssist();
	}
	
	self ClearTargetEntity();
}

function turret_gadget_deploy_fire_for_time( totalFireTime )
{
	self endon( "crash_done" );
	self endon( "death" );
	
	if( isdefined( self.emped ) )
		return;
	
	weapon = self SeatGetWeapon( 0 );
	fireTime = weapon.fireTime;
	time = 0;
	
	
	fireCount = 1;
	power = 100; 
	
	if ( IsDefined( self.power_callback ) )
	{
		power = self.owner [[self.power_callback]](self,0.0);
	}
	
	while( time < totalFireTime && !isdefined( self.emped ) && power > 0)
	{
		if ( IsDefined( self.power_callback ) )
		{
			power = self.owner [[self.power_callback]](self,fireTime/totalFireTime);
		}
		if( !IS_EQUAL(self.last_enemy,self.enemy) && IsPlayer( self.enemy ) )
		{	
			self alert_sound();
			wait 0.1; 							//wait between alert sound and rotation
			self.last_enemy = self.enemy; 
		}
		self FireWeapon();
		fireCount++;
		wait fireTime;
		time += fireTime;
	}
}

function turret_gadget_deploy_emped()
{
	self endon( "death" );
	self notify( "emped" );
	self endon( "emped" );
	
	self.emped = true;
	PlaySoundAtPosition( "veh_cic_turret_emp_down", self.origin );
	self.turretRotScale = 0.2;
	self turret_gadget_deploy_off();
	if( !isdefined( self.stun_fx) )
	{
		self.stun_fx = Spawn( "script_model", self.origin );
		self.stun_fx SetModel( "tag_origin" );
		self.stun_fx LinkTo( self, "tag_fx", (0,0,0), (0,0,0) );
		if( isSubStr(self.vehicletype,"turret_sentry") )
			PlayFXOnTag( level._effect[ "sentry_turret_stun" ], self.stun_fx, "tag_origin" );
		else
			PlayFXOnTag( level._effect[ "cic_turret_stun" ], self.stun_fx, "tag_origin" );
	}
	
	wait RandomFloatRange( 6, 10 );
	
	self.stun_fx delete();
	
	self.emped = undefined;
	self turret_gadget_deploy_on();
}

function TurretCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	driver = self GetSeatOccupant( 0 );
	
	if( weapon.isEmp && sMeansOfDeath != "MOD_IMPACT" )
	{
		if( !isdefined( driver ) )
		{
			if( !isdefined( self.off ) )
			{
				self thread turret_gadget_deploy_emped();
			}
		}
	}
	if ( IsDefined(self.dt_damage_callback) )
	{
		self thread [[self.dt_damage_callback]]();
	}
	
	return iDamage;
}
