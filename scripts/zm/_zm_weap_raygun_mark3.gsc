
//#using scripts\codescripts\struct;
//
#using scripts\shared\ai_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_utility.gsh;

#insert scripts\zm\_zm_weap_raygun_mark3.gsh;


#define N_RAYGUN_MARK3LH_VORTEX_DURATION			3000	// in ms
#define N_RAYGUN_MARK3LH_UPGRADED_VORTEX_DURATION	3000	// in ms

#define N_RAYGUN_MARK3LH_SLOWDOWN_RATE				0.7
#define N_RAYGUN_MARK3LH_UPGRADED_SLOWDOWN_RATE		0.5

#define N_RAYGUN_MARK3LH_SLOWDOWN_DURATION			2.0
#define N_RAYGUN_MARK3LH_UPGRADED_SLOWDOWN_DURATION	3.0

#define N_RAYGUN_MARK3LH_VORTEX_RANGE_SM			128
#define N_RAYGUN_MARK3LH_VORTEX_RANGE_LG			128

#define N_RAYGUN_MARK3LH_VORTEX_PULSE_INTERVAL		0.5
	
#define N_RAYGUN_MARK3LH_VORTEX_PULSE_DAMAGE_SM				  50
#define N_RAYGUN_MARK3LH_VORTEX_PULSE_DAMAGE_LG				1000
#define N_RAYGUN_MARK3LH_UPGRADED_VORTEX_PULSE_DAMAGE_SM	 100
#define N_RAYGUN_MARK3LH_UPGRADED_VORTEX_PULSE_DAMAGE_LG	5000

#define N_RAYGUN_MARK3_VORTEX_Z_OFFSET				 32	// How far off the ground we should default position the vortex
	
// Screen FX
// Prioritized below Beast mode and Parasite/Elemental round screen overlays
#define N_RAYGUN_MARK3_VORTEX_ENTER_DURATION 			0.25
#define N_RAYGUN_MARK3_VORTEX_LOOP_DURATION 			2.0
#define N_RAYGUN_MARK3_VORTEX_EXIT_DURATION 			0.25


#precache( "model", "p7_fxanim_zm_stal_ray_gun_ball_mod" );

#namespace _zm_weap_raygun_mark3;

REGISTER_SYSTEM_EX( "zm_weap_raygun_mark3", &__init__, &__main__, undefined )


function __init__()
{
	level.w_raygun_mark3			= GetWeapon( STR_RAYGUN_MARK3_WEAPON );
	level.w_raygun_mark3lh			= GetWeapon( STR_RAYGUN_MARK3LH_WEAPON );
	level.w_raygun_mark3_upgraded	= GetWeapon( STR_RAYGUN_MARK3_UPGRADED_WEAPON );
	level.w_raygun_mark3lh_upgraded	= GetWeapon( STR_RAYGUN_MARK3LH_UPGRADED_WEAPON );

	zm_utility::register_slowdown( STR_RAYGUN_MARK3LH_WEAPON,			N_RAYGUN_MARK3LH_SLOWDOWN_RATE,				N_RAYGUN_MARK3LH_SLOWDOWN_DURATION );
	zm_utility::register_slowdown( STR_RAYGUN_MARK3LH_UPGRADED_WEAPON,	N_RAYGUN_MARK3LH_UPGRADED_SLOWDOWN_RATE,	N_RAYGUN_MARK3LH_UPGRADED_SLOWDOWN_DURATION );

	zm_spawner::register_zombie_damage_callback( &raygun_mark3_damage_response );

	clientfield::register( "scriptmover",	"slow_vortex_fx",		VERSION_DLC3, 2, "int" );
	
	clientfield::register( "actor", 		"ai_disintegrate",		VERSION_DLC3, 1, "int" );
	clientfield::register( "vehicle", 		"ai_disintegrate",		VERSION_DLC3, 1, "int" );

	clientfield::register( "actor", 		"ai_slow_vortex_fx",	VERSION_DLC3, 2, "int" );
	clientfield::register( "vehicle", 		"ai_slow_vortex_fx",	VERSION_DLC3, 2, "int" );

	visionset_mgr::register_info( "visionset",	"raygun_mark3_vortex_visionset",	VERSION_DLC3, N_RAYGUN_MARK3_VORTEX_VISIONSET_PRIORITY, N_RAYGUN_MARK3_VORTEX_VISIONSET_LERP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, true );
	visionset_mgr::register_info( "overlay",	"raygun_mark3_vortex_blur",			VERSION_DLC3, N_RAYGUN_MARK3_VORTEX_VISIONSET_PRIORITY, N_RAYGUN_MARK3_VORTEX_VISIONSET_LERP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, true );

	callback::on_connect( &watch_raygun_impact);
}

function __main__()
{

}


// Was Damage from the left-hand slow gun?
function is_slow_raygun( weapon )
{
	if ( weapon === level.w_raygun_mark3lh || weapon === level.w_raygun_mark3lh_upgraded )
	{
		return true;
	}
	
	return false;
}


// Was Damage was from the right-hand beam gun?
function is_beam_raygun( weapon )
{
	if ( weapon === level.w_raygun_mark3 || weapon === level.w_raygun_mark3_upgraded )
	{
		return true;
	}
	
	return false;
}


// Repositions Vortex damage origin if too close to a horizontal surface on the navmesh
function raygun_vortex_reposition( v_impact_origin )
{
	v_nearest_navmesh_point = GetClosestPointOnNavMesh( v_impact_origin, 50, 32 );
	if ( isdefined(v_nearest_navmesh_point) )
	{
		v_vortex_origin = v_nearest_navmesh_point + ( 0, 0, N_RAYGUN_MARK3_VORTEX_Z_OFFSET);
	}
	else
	{
		v_vortex_origin = v_impact_origin;
	}
	
	return v_vortex_origin;
}


//	Track left-hand projectile impact
// self is a player
function watch_raygun_impact()
{
	self endon("disconnect");
	
	while( true )
	{
		self waittill( "projectile_impact", w_weapon, v_pos, n_radius, e_projectile, v_normal );
		
		v_pos_final = raygun_vortex_reposition( v_pos + ( v_normal*N_RAYGUN_MARK3_VORTEX_Z_OFFSET ) );

		if( is_slow_raygun( w_weapon ) )
		{
			//TODO Adjust position if too low or too close to wall.  Look at idgun.
			self thread start_slow_vortex( w_weapon, v_pos, v_pos_final, n_radius, e_projectile, v_normal );
		}
	}
}


// spawn a slow vortex
// self is a player
function start_slow_vortex( w_weapon, v_pos, v_pos_final, n_radius, e_attacker, v_normal )
{
	self endon( "disconnect" );

	mdl_vortex = Spawn( "script_model", v_pos );
	mdl_vortex SetModel( "p7_fxanim_zm_stal_ray_gun_ball_mod" );
	playsoundatposition ("wpn_mk3_orb_created", mdl_vortex.origin);
	mdl_vortex.angles = ( 270, 0, 0 );
	mdl_vortex clientfield::set( "slow_vortex_fx", N_ZM_WEAP_RGM3_SLOW_VORTEX_SM );
	util::wait_network_frame();	// ensure this position is used over the network
	
	mdl_vortex MoveTo( v_pos_final, 0.1 );	// quickly move into position
	util::wait_network_frame();	// ensure this position is used over the network

	mdl_vortex.health = 100000;
	mdl_vortex.takedamage = true;

	mdl_vortex thread pulse_damage( self, w_weapon );
	mdl_vortex thread wait_for_beam_damage();
}

// Periodically pulse damage to grab zombies in the area.
// self is the vortex blob model
function pulse_damage( e_owner, w_weapon )
{
	self endon( "death" );
	
	self.n_damage_type = N_ZM_WEAP_RGM3_SLOW_VORTEX_SM;
	self.n_end_time = GetTime() + N_RAYGUN_MARK3LH_VORTEX_DURATION;
	self.e_owner = e_owner;
	
	if ( w_weapon == level.w_raygun_mark3lh )
	{
		//playsoundatposition ("wpn_mk3_orb_zark", self.origin);
	}
	else
	{
		playsoundatposition ("wpn_mk3_orb_zark_far", self.origin);
	}
	
	// Now periodically pulse damage	
	while ( GetTime() <= self.n_end_time )
	{
		if ( self.n_damage_type == N_ZM_WEAP_RGM3_SLOW_VORTEX_SM )
		{		
			n_radius = N_RAYGUN_MARK3LH_VORTEX_RANGE_SM;
			//playsoundatposition ("wpn_mk3_orb_zark", self.origin);
			
			if ( w_weapon == level.w_raygun_mark3lh )
			{
				n_pulse_damage = N_RAYGUN_MARK3LH_VORTEX_PULSE_DAMAGE_SM;
			}
			else
			{
				n_pulse_damage = N_RAYGUN_MARK3LH_UPGRADED_VORTEX_PULSE_DAMAGE_SM;
			}
		}
		else	// LG Vortex
		{
			n_radius = N_RAYGUN_MARK3LH_VORTEX_RANGE_LG;
			playsoundatposition ("wpn_mk3_orb_zark_far", self.origin);
			
			if ( w_weapon == level.w_raygun_mark3lh )
			{
				n_pulse_damage = N_RAYGUN_MARK3LH_VORTEX_PULSE_DAMAGE_LG;
			}
			else
			{
				n_pulse_damage = N_RAYGUN_MARK3LH_UPGRADED_VORTEX_PULSE_DAMAGE_LG;
			}
		}

		// Pulse Damage		
		n_radius_squared = n_radius * n_radius;
		a_ai = GetAITeamArray( "axis" );
		foreach( ai in a_ai )
		{
			if ( IS_TRUE( ai.b_ignore_mark3_pulse_damage ) )
			{
				continue;
			}
			
			if ( DistanceSquared( self.origin, ai.origin ) <= n_radius_squared )
			{
				ai thread apply_vortex_fx( self.n_damage_type, N_RAYGUN_MARK3LH_SLOWDOWN_DURATION );
				
				if ( ai.health > n_pulse_damage )
				{
					ai DoDamage( n_pulse_damage, self.origin, e_owner, self, undefined, "MOD_UNKNOWN", 0, w_weapon );
				}
				else if ( self.n_damage_type == N_ZM_WEAP_RGM3_SLOW_VORTEX_LG )
				{
					ai thread disintegrate_zombie( self, e_owner, w_weapon );
				}
			}
		}

		// Check to see if any players are in the radius
		foreach( e_player in level.activeplayers )
		{
			if( IsDefined(e_player) && !IS_TRUE( e_player.raygun_mark3_vision_on ) )
			{
				// If Player is within vortex range, apply vision overlay
				if( Distance( e_player.origin, self.origin ) < Float( n_radius / 2 ) )
				{
					e_player thread player_vortex_visionset();
				}
			}
		}
		
		wait N_RAYGUN_MARK3LH_VORTEX_PULSE_INTERVAL;
	}

	// Vortex expired
	self clientfield::set( "slow_vortex_fx", 0 );
	
	playsoundatposition ("wpn_mk3_orb_disappear", self.origin);
	self Delete();
}


// Vision overlay and blur when player enters vortex
// self == player
function player_vortex_visionset()
{
	self notify( "player_vortex_visionset" );
	self endon( "player_vortex_visionset" );

	self endon( "death" );
	
	thread visionset_mgr::activate( "visionset", "raygun_mark3_vortex_visionset",	self, N_RAYGUN_MARK3_VORTEX_ENTER_DURATION, N_RAYGUN_MARK3_VORTEX_LOOP_DURATION, N_RAYGUN_MARK3_VORTEX_EXIT_DURATION );
	thread visionset_mgr::activate( "overlay",	 "raygun_mark3_vortex_blur",		self, N_RAYGUN_MARK3_VORTEX_ENTER_DURATION, N_RAYGUN_MARK3_VORTEX_LOOP_DURATION, N_RAYGUN_MARK3_VORTEX_EXIT_DURATION );
	self.raygun_mark3_vision_on = true;
	wait 2.5;	// minimal amount of time to keep it up 
	
	self.raygun_mark3_vision_on = false;
}


// wait for damage
// self is a vortex model
function wait_for_beam_damage()
{
	self endon( "death" );
	self playloopsound ("wpn_mk3_orb_loop");
	while( true )
	{
		self waittill( "damage", n_damage, e_attacker, v_direction, v_point, str_means_of_death, str_tag_name, str_model_name, str_part_name, w_weapon );
	
		if ( is_beam_raygun( w_weapon ) )
		{
			self stoploopsound();
			self SetModel( "tag_origin" );	// remove the original vortex
			self playloopsound ("wpn_mk3_orb_loop_activated");
			self.takedamage = false;
			self.n_damage_type = N_ZM_WEAP_RGM3_SLOW_VORTEX_LG;
			self clientfield::set( "slow_vortex_fx", self.n_damage_type );
			self.n_end_time = GetTime() + N_RAYGUN_MARK3LH_UPGRADED_VORTEX_DURATION;
			wait N_RAYGUN_MARK3LH_UPGRADED_VORTEX_DURATION / 1000;
			playsoundatposition ("wpn_mk3_orb_disappear", self.origin);
			self Delete();
			return;
		}
		else
		{
			self.health = 100000;
		}
	}
}


//	Zombies damaged by the left-hand ray gun will beome slowed temporarily
// Self is a damaged entity
function raygun_mark3_damage_response( str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, v_direction, str_tag, str_model, str_part, n_flags, e_inflictor, n_chargeLevel )
{
	if ( isdefined( w_weapon ) )
	{
		if ( w_weapon == level.w_raygun_mark3lh || w_weapon == level.w_raygun_mark3lh_upgraded )
		{
			// Run override if available	
			if ( isdefined( self.func_raygun_mark3_damage_response ) )
		    {
				return [[ self.func_raygun_mark3_damage_response ]]( str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, v_direction, str_tag, str_model, str_part, n_flags, e_inflictor, n_chargeLevel );
		    }
		
			// Add slowdown effect
			if ( w_weapon == level.w_raygun_mark3lh )
			{
				self thread zm_utility::slowdown_ai( STR_RAYGUN_MARK3LH_WEAPON );
				return true;
			}
			else if ( w_weapon == level.w_raygun_mark3lh_upgraded )
			{
				self thread zm_utility::slowdown_ai( STR_RAYGUN_MARK3LH_UPGRADED_WEAPON );
				return true;
			}
		}
	}

	// Don't affect damage dealt
	return false;
}

	
//	Apply fx to affected AI
// self is an AI
function apply_vortex_fx( n_damage_type, n_time )
{
	self notify( "apply_vortex_fx" );
	self endon( "apply_vortex_fx" );
	self endon( "death" );

	if ( !IS_TRUE( self.b_vortex_fx_applied ) )
	{
		self.b_vortex_fx_applied = true;
		if ( IS_TRUE( self.allowPain ) )
		{
			self.b_old_allow_pain = true;
			self ai::disable_pain();
		}
		
		if ( n_damage_type == N_ZM_WEAP_RGM3_SLOW_VORTEX_SM )
		{
			self clientfield::set( "ai_slow_vortex_fx", N_ZM_WEAP_RGM3_SLOW_VORTEX_SM );
		}
		else
		{
			self clientfield::set( "ai_slow_vortex_fx", N_ZM_WEAP_RGM3_SLOW_VORTEX_LG );
		}
	}
	
	util::waittill_any_timeout( n_time, "death", "apply_vortex_fx" );
	
	if ( IS_TRUE( self.b_old_allow_pain ) )
	{
		self ai::enable_pain();
	}
	self clientfield::set( "ai_slow_vortex_fx", 0 );
}


function disintegrate_zombie( e_inflictor, e_attacker, w_weapon )
{
	self endon( "death" );
	
	if ( IS_TRUE( self.b_disintegrating ) )
	{
		return;
	}
	self.b_disintegrating = true;
	
	// these scenes prevent death
	self clientfield::set( "ai_disintegrate", 1 );
	
	if ( IsVehicle( self ) )
	{
		self ai::set_ignoreall( true );
		wait 1.1;
		
		self Ghost();
		self DoDamage( self.health, self.origin, e_attacker, e_inflictor, undefined, "MOD_UNKNOWN", 0, w_weapon );
	}
	else
	{
		self scene::play( "cin_zm_dlc3_zombie_dth_deathray_0" + RandomIntRange( 1, 5 ), self );
		self clientfield::set( "ai_slow_vortex_fx", 0 );
		util::wait_network_frame();
		
		self Ghost();	// The corpse will appear normal, so we need to hide it.
		self DoDamage( self.health, self.origin, e_attacker, e_inflictor, undefined, "MOD_UNKNOWN", 0, w_weapon );
	}
}