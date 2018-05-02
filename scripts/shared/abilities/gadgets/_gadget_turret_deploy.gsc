#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hackable;
#using scripts\shared\turret_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_deploy_turret;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#define GADGET_FLAG "gadget_turret_deploy_on"
#define GADGET_READY_FLAG "gadget_turret_deploy_ready"
#define GADGET_RECOVER_FLAG "gadget_turret_recover_ready"

#using scripts\shared\system_shared;

#define TURRET_EXPLODE "weapon/fx_betty_exp"
#define TURRET_SPAWN "vehicle/fx_elec_teleport_escort_drone"
	
#precache( "fx", TURRET_SPAWN );
#precache( "fx", TURRET_EXPLODE );

#precache( "triggerstring", "WEAPON_GADGET_TURRET_RECOVER_LB" );
#precache( "triggerstring", "WEAPON_GADGET_TURRET_RECOVER_RB" );

REGISTER_SYSTEM( "gadget_deploy_turret", &__init__, undefined )

#define TURRET_MODEL "wpn_t7_sentry_gun_gadget"
#define TURRET_MODEL_RED "wpn_t7_sentry_gun_gadget_red" 
#define TURRET_OFFSET (0,0,0)

// misc	
#define TURRET_RECOVERY_DISTANCE 		GetDvarFloat("scr_turret_recovery_distance")
#define TURRET_RECOVERY_ANGLEDOT 		0.7
#define TURRET_RECOVERY_HOLDTIME 		GetDvarInt( "g_useholdtime" )
#define TURRET_RECOVERY_PROMPT_0		&"WEAPON_GADGET_TURRET_RECOVER_RB"
#define TURRET_RECOVERY_PROMPT_1		&"WEAPON_GADGET_TURRET_RECOVER_LB"
#define TURRET_TIMEOUT_SELF_DESTRUCT 	GetDvarFloat("scr_turret_timeout_self_destruct")
//hacking	
#define TURRET_HACK_TIMER 				GetDvarFloat("scr_turret_hack_timer")
#define TURRET_HACKER_TIME 				GetDvarFloat("scr_turret_hack_time")
#define TURRET_HACKER_COST 				GetDvarFloat("scr_turret_hack_power_mult")
	
// power use
#define TURRET_DRAIN_POWER_USE 			GetDvarFloat("scr_turret_drain_power_use")
#define TURRET_BURST_POWER_USE 			GetDvarFloat("scr_turret_burst_power_use")
#define TURRET_BURST_POWER_CUTOFF 		GetDvarFloat("scr_turret_burst_power_cutoff")
#define TURRET_BURST_POWER_RESUME 		GetDvarFloat("scr_turret_burst_power_resume")
#define TURRET_DROP_POWER_USE 			GetDvarFloat("scr_turret_drop_power_use")
#define TURRET_RECOVER_POWER_USE 		GetDvarFloat("scr_turret_recover_power_use")

#define TURRET_FOV_COS					GetDvarFloat("scr_turret_fov_cos")
#define TURRET_FOV_COS_BUSY				GetDvarFloat("scr_turret_fov_cos_busy")
#define TURRET_MAX_SIGHT_DIST_SQ		(GetDvarFloat("scr_turret_max_sight_dist") * GetDvarFloat("scr_turret_max_sight_dist"))
#define TURRET_SIGHT_LATENCY			GetDvarInt("scr_turret_sight_latency")
	
	
	
function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_on, &gadget_turret_deploy_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_on_give, &gadget_turret_deploy_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_is_flickering );
	ability_player::register_gadget_failed_activate_callback( GADGET_TYPE_TURRET_DEPLOY, &gadget_turret_deploy_failed_activate );
	
	callback::on_connect( &gadget_turret_deploy_on_connect );
	
	turret_precache();

	clientfield::register( "vehicle", "retrievable",	VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "unplaceable",	VERSION_SHIP, 1, "int" );

	clientfield::register( "vehicle", "toggle_keyline",	VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "dt_damage_state",	VERSION_SHIP, 2, "int" );
	clientfield::register( "vehicle", "vehicle_hack",	VERSION_SHIP, 1, "int" );

	level.gadgetTurretDeploy = GetWeapon( get_gadget_name() );
	level.gadgetTurretRecover = GetWeapon( get_gadget_recover_name() );
	
	setup_turret_damage_states();
}

function get_gadget_name()
{
	return "gadget_turret_deploy";
}

function get_gadget_recover_name()
{
	return "gadget_turret_recover";
}

function turret_precache()
{
	level._effect["turret_spawn_fx"] = TURRET_SPAWN;
	level._effect["turret_explode"] = TURRET_EXPLODE;
}

function gadget_turret_deploy_is_inuse(slot)
{
	return self flagsys::get( GADGET_FLAG );
}

function gadget_turret_deploy_is_flickering(slot)
{
	return false;
}

function gadget_turret_deploy_on_flicker(slot)
{
}

function gadget_turret_deploy_on_give(slot, weapon)
{
}

function gadget_turret_deploy_on_take(slot)
{
	//self notify( "gadget_turret_deploy_taken" );
	// executed when gadget is removed from the players inventory
}

function gadget_turret_deploy_on_connect()
{
	// setup up stuff on player connect
}

function gadget_turret_deploy_failed_activate()
{
}

#define TURRET_CARRY_DIST 30

function gadget_turret_deploy_on(slot)
{
	carry_dist = TURRET_CARRY_DIST;
	carry_angles = (1,0,0);
	carry_offset = (carry_dist,0,0);
	
	self flagsys::clear( GADGET_READY_FLAG );
	self.pre_turret_weapon = self getcurrentweapon();
	if ( !self flagsys::get( GADGET_RECOVER_FLAG ) )
	{
		self flagsys::set( GADGET_FLAG );
		
		WAIT_SERVER_FRAME;
		while( self IsSwitchingWeapons() )
		{
			WAIT_SERVER_FRAME;
		}
		
		if ( self GadgetPowerChange( slot, 0 ) < TURRET_DROP_POWER_USE )
			return false; 
		
		if( self gadget_turret_deploy_is_inuse(slot) )
		{
			self endon( "gadget_turret_deploy_taken" );
	
			self flagsys::set( GADGET_READY_FLAG );
			
			self.turretAngles = self.angles;
			self.turretOrigin = self.origin + TURRET_OFFSET +AnglesToForward(self.angles) * TURRET_CARRY_DIST;
	
			self.temp_turret = vehicle::spawn( TURRET_MODEL, "td", "turret_gadget_deploy", self.turretOrigin, self.turretAngles );
			self.temp_turret SetModel( TURRET_MODEL );
			self.temp_turret NotSolid();
			self CarryTurret(self.temp_turret, carry_offset, carry_angles);

			util::wait_network_frame();
			util::wait_network_frame();
			
			while( self gadget_turret_deploy_is_inuse(slot) && IsDefined(self.temp_turret))
			{
				self.turret_placement = self canPlayerPlaceTurret();
				if( !IsDefined(self.turret_placement) || !self.turret_placement["result"] )
				{
					self.temp_turret clientfield::set( "unplaceable", 1 );
					//self.temp_turret SetModel( TURRET_MODEL_RED );
				}
				else
				{
					self.temp_turret clientfield::set( "unplaceable", 0 );
					//self.temp_turret SetModel( TURRET_MODEL );
				}

				WAIT_SERVER_FRAME;
			}
		
			WAIT_SERVER_FRAME;
		
			if (IsDefined(self.temp_turret) )
			{
				self stopCarryTurret(self.temp_turret); 
				self.temp_turret turret_delete();
				self.temp_turret=undefined;
			}
		}
	}
	else
	{
		self thread watch_turret_recovery(slot);
		self SwitchToWeapon(self.pre_turret_weapon);
	}
}

function can_recover_turret(turret)
{
	if ( IS_TRUE(turret.is_hacked) )
		return false; 

	if ( self GadgetPowerChange( self.turret_slot, 0 ) < TURRET_RECOVER_POWER_USE )
		return false; 
	
	origin = self.origin;
	forward = AnglesToForward( self.angles );
	
	if ( DistanceSquared( origin, turret.origin ) < ( TURRET_RECOVERY_DISTANCE * TURRET_RECOVERY_DISTANCE ) )
	{
		to_obj = VectorNormalize( turret.origin-origin );
		dot = VectorDot( to_obj, forward ); 
		if ( dot >= TURRET_RECOVERY_ANGLEDOT )
		{
			return true;
		}
	}
	return false;
}

function button_pressed(slot)
{
	if ( slot )
		return self secondaryoffhandbuttonpressed();
	return self fragbuttonpressed();
}

function watch_turret_recovery(slot)
{
	hold_start = GetTime(); 
	while( IsDefined(self.turret) && button_pressed(slot))
	{
		if ( can_recover_turret(self.turret) )
		{
			if ( GetTime() - hold_start > TURRET_RECOVERY_HOLDTIME )
			{
				self turret_owner_power_callback( self.turret, 1, TURRET_RECOVER_POWER_USE );
				self.turret turret_delete();
				self.turret = undefined;
				return;
			}
		}
		else
		{
			hold_start = GetTime(); 
		}
		WAIT_SERVER_FRAME;
	}
}

function gadget_turret_deploy_off(slot)
{
	if( IsDefined(self.turret_placement) && self.turret_placement["result"] )
	{
		if ( self flagsys::get( GADGET_READY_FLAG ) )
		{
			self thread deploy_turret(slot);
		}
	}
	self flagsys::clear( GADGET_READY_FLAG );
	self notify( "gadget_turret_off" );
	self flagsys::clear( GADGET_FLAG );
}

#define HEADICON_OFFSET (0, 0, 70) 


function set_player_turret(turret)
{
	turret notify("owner_change");
	if (IsDefined(turret.owner))
	{
		old_owner = turret.owner;
		old_owner.turret = undefined;
	}
	if ( IsDefined( self.turret ) )
	{
		self.turret turret_delete();
	}
	self.turret = turret;
	if (IsDefined(turret))
	{
		turret.owner = self;
		turret SetTeam(self.team);
		if (IsDefined(level.setEntityHeadIcon) )
		{
			 turret [[level.setEntityHeadIcon]]( self.team, self, HEADICON_OFFSET );
		}
		turret thread watch_player_death(self);
		self thread switch_player_gadget();
	}
}

function switch_player_gadget()
{
	self endon("disconnect");
	self flagsys::set( GADGET_RECOVER_FLAG );
	if ( self HasWeapon( level.gadgetTurretDeploy ) )
	{
		self TakeWeapon( level.gadgetTurretDeploy );
		self GiveWeapon( level.gadgetTurretRecover );
	}
	
	self.turret waittill("death");
	
	if ( self HasWeapon( level.gadgetTurretRecover ) )
	{
		self TakeWeapon( level.gadgetTurretRecover );
		self GiveWeapon( level.gadgetTurretDeploy );
	}
	self flagsys::clear( GADGET_RECOVER_FLAG );
		
}



function watch_player_death( owner )
{
	self notify("owner_change");
	self endon("owner_change");
	self endon("death");
	
	//owner waittill("death_or_disconnect");
	owner waittill("disconnect");
	
	while( IS_TRUE(self.is_hacked) )
	{
		WAIT_SERVER_FRAME;
	}
	
	self turret_delete();
}


function drop_to_ground()
{
	trace = bullettrace( self.origin, self.origin + (0,0,-2000), false, self );
	if ( trace["fraction"] < 0.99 )
	{
		self.origin = trace["position"];
		return true;
	}
	return false;
}



function deploy_turret(slot)
{
	self.turretOrigin = self.turret_placement["origin"];
	self.turretAngles = self.turret_placement["angles"];
	self stopCarryTurret(self.temp_turret); 

	if (!self.temp_turret drop_to_ground())
	{
		self.temp_turret turret_delete();
		return;
	}

	turret = self.temp_turret; //vehicle::spawn( TURRET_MODEL, "td", "turret_gadget_deploy", self.turretOrigin, self.turretAngles );
	
	turret DisconnectPaths();

	self.temp_turret = undefined; 
	self set_player_turret(turret);
	turret SetOwner(self);
	turret Solid();

	turret.fovcosine = TURRET_FOV_COS;
	turret.fovcosinebusy = TURRET_FOV_COS_BUSY;
	turret.maxsightdistsqrd = TURRET_MAX_SIGHT_DIST_SQ;
	turret.sightlatency = TURRET_SIGHT_LATENCY;
	
	turret endon( "death" );


	self.turret_slot = slot;	
	turret thread turret_gadget_deploy::turret_gadget_deploy_think( self, 
	                                                               &turret_owner_power_callback,
	                                                               TURRET_BURST_POWER_CUTOFF,
	                                                               TURRET_BURST_POWER_RESUME );
			
	vehicle::init( self.turret );
	self.turret vehicle::lights_off();
	
	turret.hackable_progress_prompt = &"WEAPON_HACKING_TURRET";
	turret.hackable_cost_mult = TURRET_HACKER_COST;
	turret.hackable_hack_time = TURRET_HACKER_TIME;
	hackable::add_hackable_object( turret, &turret_can_be_hacked, &turret_hack_start, &turret_hack_fail, &turret_hacked );

	self.turret.prompt_trigger = Spawn( "trigger_radius_use", self.turretOrigin + (0,0,30) , 0, TURRET_RECOVERY_DISTANCE, TURRET_RECOVERY_DISTANCE);
	if ( slot )
		self.turret.prompt_trigger SetHintString(TURRET_RECOVERY_PROMPT_1);	
	else
		self.turret.prompt_trigger SetHintString(TURRET_RECOVERY_PROMPT_0);	
	self.turret.prompt_trigger SetCursorHint( "HINT_NOICON" );
	self.turret.prompt_trigger setInvisibleToAll();
	self.turret.prompt_trigger SetTeamForTrigger( self.team );
	self.turret.prompt_trigger setVisibleToPlayer( self );
	self.turret.prompt_trigger UseTriggerRequireLookAt();

	self turret_owner_power_callback( self.turret, 1, TURRET_DROP_POWER_USE );
	if ( TURRET_DRAIN_POWER_USE > 0 )
	{
		self thread turret_drain_power();
	}
	
	util::wait_network_frame();
	util::wait_network_frame();
	
	self.turret vehicle::lights_on();
	self.turret clientfield::set( "toggle_keyline", 1 );
	self.turret clientfield::set( "retrievable", 1 );
	self.turret.dt_damage_callback = &turret_update_damage; 
	self.turret turret_update_damage();
	
	if ( TURRET_TIMEOUT_SELF_DESTRUCT > 0 )
	{
		wait TURRET_TIMEOUT_SELF_DESTRUCT;
			
		if ( IsDefined( turret ) )
		{
			turret turret_delete();
		}
	}
}

function turret_update_damage( )
{
	WAIT_SERVER_FRAME; 
	health_factor = self.health / self.healthmax;

	new_health = 0;
	while( new_health < level.deploy_turret_damage_states-1 &&
	      health_factor <= level.deploy_turret_damage_amt[new_health+1] )
	{
		new_health = new_health+1;
	}
	
	if ( !IS_EQUAL( self.dt_damage_state, new_health ) )
	{
		self clientfield::set( "dt_damage_state", new_health );
		self.dt_damage_state = new_health;
		if ( new_health >= level.deploy_turret_damage_states-1 )
			self thread turret_delete( 3.0, true );
			
	}
}

#define TURRET_DAMAGE_STATES 	2
#define TURRET_DAMAGE_AMT_1 	0.5
#define TURRET_DAMAGE_FX_1 		"destruct/fx_dest_turret_1"
#define TURRET_DAMAGE_AMT_2 	0.25
#define TURRET_DAMAGE_FX_2 		"destruct/fx_dest_turret_2"

function setup_turret_damage_states()
{
	level.deploy_turret_damage_states = TURRET_DAMAGE_STATES + 2; 
	level.deploy_turret_damage_amt = [];
	level.deploy_turret_damage_fx = [];
	level.deploy_turret_damage_amt[0] = 1.0;
	level.deploy_turret_damage_fx[0] = undefined;
	level.deploy_turret_damage_amt[1] = TURRET_DAMAGE_AMT_1;
	level.deploy_turret_damage_fx[1] = TURRET_DAMAGE_FX_1;
	level.deploy_turret_damage_amt[2] = TURRET_DAMAGE_AMT_2;
	level.deploy_turret_damage_fx[2] = TURRET_DAMAGE_FX_2;
	level.deploy_turret_damage_amt[3] = 0.0;
	level.deploy_turret_damage_fx[3] = undefined;
	
}


function turret_drain_power()
{
	self endon("disconnect");
	wait 0.5;
	while( IsDefined(self.turret) )
	{
		turret_owner_power_callback( self.turret, SERVER_FRAME, TURRET_DRAIN_POWER_USE );
		WAIT_SERVER_FRAME;
	}
}


function turret_owner_power_callback( turret, delta, use = TURRET_BURST_POWER_USE )
{
	if ( IS_TRUE(turret.is_hacked) )
		return 100;
	
	dpower = -1 * delta * use;
	
	power = self GadgetPowerChange( self.turret_slot, dpower );
	
	if (power <=0)
	{
		turret turret_delete();
	}
	
	return power;
}

function keep_power_constant()
{
	self notify("resume_turret_power");
	self endon("resume_turret_power");
	startpower = self GadgetPowerChange( self.turret_slot, 0 );
	while( IsDefined(self) && IsDefined(self.turret) )
	{
		curpower = self GadgetPowerChange( self.turret_slot, 0 );
		self GadgetPowerChange( self.turret_slot, startpower-curpower );
		
		WAIT_SERVER_FRAME;
	}
}



function turret_delete( time, explode )
{
	self clientfield::set( "toggle_keyline", 0 );
	self clientfield::set( "retrievable", 0 );
	if ( IsDefined(self.owner) )
	{
		self.owner.turret = undefined;
	}
	if ( IsDefined(self.prompt_trigger) )
	{
		self.prompt_trigger delete();
		self.prompt_trigger=undefined;
	}
	if (IsDefined(time))
	{
		wait time;
	}
	if ( IS_TRUE(explode) )
	{
		PlayFx( level._effect["turret_explode"], self.origin+(0,0,20) );
	}
	if (IsDefined(self))
	{
		self Ghost(); 
	}
	wait 1; 
	if (IsDefined(self))
	{
		self delete();
	}
}





function turret_can_be_hacked( player )
{
	if ( isdefined( player ) && isdefined( player.team ) && ( player.team == "spectator" ))
	{
		return false;
	}

	v_eye = player util::get_eye();
	b_can_see = SightTracePassed( v_eye, self.origin + (0,0,30), false, self );
	
	if ( !b_can_see )
	{
		return false;
	}

	if ( isdefined( player ) && isdefined( player.team ))
	{
		team = player.team;

		// using the player team to determine team base games
		if ( team == "free" )
		{
			owner = self.owner; 
			if ( IS_TRUE(self.is_hacked) )
				owner = self.hacker;

			if ( isdefined( owner ) && owner == player )
			{
				return false;
			}
		}
		else if ( self.team == team )
		{
			return false;
		}
	}
	
	return true;
}

function turret_hack_start( hacker )
{
	self.owner thread keep_power_constant();
	self clientfield::set( "vehicle_hack", 1 );
	self vehicle::lights_off();
}

function turret_hack_fail( hacker )
{
	self.owner notify( "resume_turret_power" );
	self vehicle::lights_on();
	self clientfield::set( "vehicle_hack", 0 );
}

function turret_hacked( hacker )
{
	self notify("turret_hacked");
	self endon("turret_hacked");
	self endon( "death" );
	if ( TURRET_HACK_TIMER <= 0  )
	{
		self.is_hacked = 1;
		self.hacker = hacker;
		hacker set_player_turret(self);
	}
	else
	{
		if (hacker != self.owner)
		{
			self.prompt_trigger setInvisibleToPlayer( self.owner );
			self SetTeam(hacker.team);
			if (IsDefined(level.setEntityHeadIcon) )
			{
				 self [[level.setEntityHeadIcon]]( hacker.team, self.owner, HEADICON_OFFSET );
			}
			self.hacker = hacker;
			self.is_hacked = 1;
			self vehicle::lights_on();
			self.owner thread keep_power_constant();
			self thread wait_and_clear_hack();
			wait TURRET_HACK_TIMER;
			self vehicle::lights_off();
			util::wait_network_frame();
			util::wait_network_frame();
		}
		self.owner notify( "resume_turret_power" );
		self clientfield::set( "vehicle_hack", 0 );
		self.is_hacked = 0;
		self.hacker = undefined;
		if (IsDefined(self.owner))
		{
			self.prompt_trigger setVisibleToPlayer( self.owner );
			self SetTeam(self.owner.team);
			if (IsDefined(level.setEntityHeadIcon) )
			{
				 self [[level.setEntityHeadIcon]]( self.owner.team, self.owner, HEADICON_OFFSET );
			}
		}
		else
		{
			self turret_delete();
		}
	}
	self vehicle::lights_on();

}

function wait_and_clear_hack()
{
	util::wait_network_frame();
	self clientfield::set( "vehicle_hack", 0 );
}



