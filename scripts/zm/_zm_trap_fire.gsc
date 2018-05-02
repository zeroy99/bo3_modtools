#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\util_shared;
#using scripts\shared\_burnplayer;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_death;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_traps.gsh;

#namespace zm_trap_fire;

REGISTER_SYSTEM( "zm_trap_fire", &__init__, undefined )
	
function __init__()
{
	zm_traps::register_trap_basic_info( "fire", &trap_activate_fire, &trap_audio );
	zm_traps::register_trap_damage( "fire", &player_damage, &damage );
	
	a_traps = struct::get_array( "trap_fire", "targetname" );
	foreach( trap in a_traps )
	{
		clientfield::register( "world", trap.script_noteworthy, VERSION_DLC5, 1, "int" );			
	}	
}

function trap_activate_fire()
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
    sound_origin = Spawn( "script_origin", self.origin );
    sound_origin PlaySound( "wpn_zmb_inlevel_fire_trap_start" );
    sound_origin PlayLoopSound( "wpn_zmb_inlevel_fire_trap_loop" );
    self thread play_fire_sound( trap );

	trap util::waittill_any_timeout( trap._trap_duration, "trap_done");

	if(isdefined(sound_origin))
	{	
		PlaySoundAtPosition( "wpn_zmb_inlevel_fire_trap_stop", sound_origin.origin );	
		    
		sound_origin StopLoopSound();
		wait(.05);
		playsoundatposition ("zmb_fire_trap_cooldown", sound_origin.origin);
		sound_origin Delete();
	}	 
}

function play_fire_sound( trap )
{
	trap endon ("trap_done");
	while( 1 )
	{	
		wait( RandomFloatRange(0.1, 0.5) );
		playsoundatposition( "amb_flame", self.origin );//TODO T7 sound
	}
}

function player_damage()
{	
	self endon("death");
	self endon("disconnect");
	
	if( !IS_TRUE( self.is_burning ) && !self laststand::player_is_in_laststand() )
	{
		self.is_burning = 1;		
		if( IS_TRUE( level.trap_fire_visionset_registered ) )
		{
			visionset_mgr::activate( "overlay", "zm_trap_burn", self, ZM_TRAP_BURN_MAX, ZM_TRAP_BURN_MAX );
		}
		else
		{
			self burnplayer::setplayerburning( ZM_TRAP_BURN_MAX, .05, 0 );
		}
			
		self notify("burned");

		if(!self HasPerk( PERK_JUGGERNOG ) || self.health - 100 < 1)
		{
			RadiusDamage(self.origin,10,self.health + 100,self.health + 100);
			self.is_burning = undefined;
		}
		else
		{
			self DoDamage(50, self.origin);
			wait(.1);
			self playsound("zmb_ignite");  //TODO make custom sound later
			self.is_burning = undefined;
		}
	}
}

function damage( trap )
{
	self endon("death");
	
	n_param = RandomInt(100);
	
	self.marked_for_death = true;
	
	// Param is used as a random chance number

	if ( isdefined( self.animname ) && self.animname != "zombie_dog" )
	{
		// 10% chance the zombie will burn, a max of 6 burning zombs can be going at once
		// otherwise the zombie just gibs and dies
		if( (n_param > 90) && (level.burning_zombies.size < 6) )
		{
			level.burning_zombies[level.burning_zombies.size] = self;
			self thread zm_traps::zombie_flame_watch();
			self PlaySound("zmb_ignite");

			self thread zombie_death::flame_death_fx();
			PlayFxOnTag( level._effect["character_fire_death_torso"], self, "J_SpineLower" ); 

			wait( RandomFloat(1.25) );
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
			self.a.gib_ref = refs[RandomInt(refs.size)];
            
			PlaySoundAtPosition("zmb_ignite", self.origin);
			
			wait( RandomFloat(1.25) );
			self PlaySound("zmb_vocals_zombie_death_fire");
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
		self DoDamage(self.health + 666, self.origin, trap);
	}
}
