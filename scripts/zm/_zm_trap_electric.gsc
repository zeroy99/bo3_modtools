#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_death;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_traps.gsh;

#namespace zm_trap_electric;

REGISTER_SYSTEM( "zm_trap_electric", &__init__, undefined )
	
function __init__()
{
	zm_traps::register_trap_basic_info( "electric", &trap_activate_electric, &trap_audio );
	zm_traps::register_trap_damage( "electric", &player_damage, &damage );
	
	if ( !IsDefined( level.vsmgr_prio_overlay_zm_trap_electrified ) )
	{
		level.vsmgr_prio_overlay_zm_trap_electrified = 60;
	}					
	visionset_mgr::register_info( "overlay", "zm_trap_electric", VERSION_SHIP, level.vsmgr_prio_overlay_zm_trap_electrified, 15, true, &visionset_mgr::duration_lerp_thread_per_player, false );				
	level.trap_electric_visionset_registered = true;
	
	a_traps = struct::get_array( "trap_electric", "targetname" );
	foreach( trap in a_traps )
	{
		clientfield::register( "world", trap.script_noteworthy, VERSION_SHIP, 1, "int" );			
	}	
}

function trap_activate_electric()
{
	self._trap_duration = 40;
	self._trap_cooldown_time = 60;
	
	if ( isdefined( level.sndTrapFunc ) )
	{
		level thread [[ level.sndTrapFunc ]]( self, 1 );
	}

	self notify("trap_activate");//TODO let's get rid of this and instead use the level notify
	level notify( "trap_activate", self );
	       

	level clientfield::set( self.target , 1 );

	// Kick off audio
	fx_points = struct::get_array( self.target,"targetname" );
	for( i=0; i<fx_points.size; i++ )
	{
		util::wait_network_frame();
		fx_points[i] thread trap_audio(self);		
	}
	
	// Do the damage
	self thread zm_traps::trap_damage();
	self util::waittill_notify_or_timeout( "trap_deactivate", self._trap_duration );

	// Shut down
	self notify ("trap_done");

	level clientfield::set( self.target , 0 );
}

function trap_audio( trap )
{
    sound_origin = spawn( "script_origin", self.origin );
    sound_origin playsound( "wpn_zmb_inlevel_trap_start" );
    sound_origin playloopsound( "wpn_zmb_inlevel_trap_loop" );
    self thread play_electrical_sound( trap );

	trap util::waittill_any_timeout( trap._trap_duration, "trap_done");

	if(isdefined(sound_origin))
	{	
		playsoundatposition( "wpn_zmb_inlevel_trap_stop", sound_origin.origin );	
		    
		sound_origin stoploopsound();
		wait(.05);
		sound_origin delete();
	}	 
}

function play_electrical_sound( trap )
{
	trap endon ("trap_done");
	while( 1 )
	{	
		wait( randomfloatrange(0.1, 0.5) );
		playsoundatposition( "amb_sparks", self.origin );
	}
}

function  player_damage()
{
	if( !IS_TRUE(self.b_no_trap_damage) )
	{
		self thread zm_traps::player_elec_damage();
	}
}

function damage( trap )
{
	self endon("death");
	
	n_param = randomint(100);
	
	self.marked_for_death = true;

	// consider it a trap kill at this point since we've already marked them for death (FIXED BO3 TU3 11/12/2015 - wasn't getting hit before because the zombie would die from trap damage, ending the thread)
	if ( IsDefined( trap.activated_by_player ) && IsPlayer( trap.activated_by_player ) )
	{
		trap.activated_by_player zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_KILL_TRAP" );
		
		if ( IsDefined ( trap.activated_by_player.zapped_zombies ) ) //achievement hookup
		{
			trap.activated_by_player.zapped_zombies++;	
			trap.activated_by_player notify ( "zombie_zapped" );
		}
	}
	
	// Param is used as a random chance number

	if ( isdefined( self.animname ) && self.animname != "zombie_dog" && IsActor( self ) )
	{
		// 10% chance the zombie will burn, a max of 6 burning zombs can be going at once
		// otherwise the zombie just gibs and dies
		if( (n_param > 90) && (level.burning_zombies.size < 6) )
		{
			level.burning_zombies[level.burning_zombies.size] = self;
			self thread zm_traps::zombie_flame_watch();
			self playsound("zmb_ignite");

			self thread zombie_death::flame_death_fx();
			PlayFxOnTag( level._effect["character_fire_death_torso"], self, "J_SpineLower" ); 

			wait( randomfloat(1.25) );
		}
		else
		{
			refs[0] = "guts";
			refs[1] = "right_arm"; 
			refs[2] = "left_arm"; 
			refs[3] = "right_leg"; 
			refs[4] = "left_leg"; 
			refs[5] = "no_legs";
			refs[6] = "head";
			self.a.gib_ref = refs[randomint(refs.size)];
            
			playsoundatposition("wpn_zmb_electrap_zap", self.origin);
			
			if(randomint(100) > 50 )
			{
				self thread zm_traps::electroctute_death_fx();
				//self thread zm_traps::play_elec_vocals();
			}
			
			self notify( "bhtn_action_notify", "electrocute" );
			
			wait(randomfloat(1.25));
			self playsound("wpn_zmb_electrap_zap");
		}
	}

	// custom damage
	if ( isdefined( self.fire_damage_func ) )
	{
		self [[ self.fire_damage_func ]]( trap );
	}
	else
	{
		level notify( "trap_kill", self, trap );
		self dodamage(self.health + 666, self.origin, trap);
	}
}
