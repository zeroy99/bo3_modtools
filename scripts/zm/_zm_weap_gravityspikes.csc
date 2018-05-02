#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_weap_gravityspikes.gsh;
#insert scripts\shared\ai\zombie_vortex.gsh;

#using scripts\shared\ai\zombie_vortex;

#define STR_GRAVITY_TRAP_BEAM "electric_arc_sm_tesla_beam_pap"

#precache( "client_fx", "electric/fx_elec_burst_lg_z270_os" );
#precache( "client_fx", "dlc1/castle/fx_weapon_gravityspike_location_glow" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_trap_start" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_trap_loop" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_trap_end" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit_1p" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_trap_handle_sparks" );
#precache( "client_fx", "electric/fx_ability_elec_surge_short_robot_optim" );
#precache( "client_fx", "light/fx_light_spark_chest_zombie_optim" );
#precache( "client_fx", "dlc1/zmb_weapon/fx_wpn_spike_torso_trail" );
#precache( "client_fx", "dlc1/castle/fx_tesla_trap_body_exp");

REGISTER_SYSTEM( "zm_weap_gravityspikes", &__init__, undefined )

function __init__( localClientNum )
{
	register_clientfields();	
	
	level._effect["gravityspikes_destroy"]		= "electric/fx_elec_burst_lg_z270_os";
	level._effect["gravityspikes_location"]		= "dlc1/castle/fx_weapon_gravityspike_location_glow";
	
	level._effect["gravityspikes_slam"]				= "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit";
	level._effect["gravityspikes_slam_1p"]				= "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit_1p";
	level._effect["gravityspikes_trap_start"]				= "dlc1/zmb_weapon/fx_wpn_spike_trap_start";
	level._effect["gravityspikes_trap_loop"]				= "dlc1/zmb_weapon/fx_wpn_spike_trap_loop";
	level._effect["gravityspikes_trap_end"]				= "dlc1/zmb_weapon/fx_wpn_spike_trap_end";
	
	level._effect["gravity_trap_spike_spark"]		= "dlc1/zmb_weapon/fx_wpn_spike_trap_handle_sparks";	
	
	level._effect["zombie_sparky"] = "electric/fx_ability_elec_surge_short_robot_optim";
	level._effect["zombie_spark_light"] = "light/fx_light_spark_chest_zombie_optim";
	level._effect["zombie_spark_trail"] = "dlc1/zmb_weapon/fx_wpn_spike_torso_trail";
	
	level._effect["gravity_spike_zombie_explode"] = "dlc1/castle/fx_tesla_trap_body_exp";
}

function register_clientfields()
{
	clientfield::register( "actor", "gravity_slam_down", VERSION_SHIP, 1, "int", &gravity_slam_down, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "gravity_trap_fx", VERSION_SHIP, 1, "int", &gravity_trap_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "gravity_trap_spike_spark", VERSION_SHIP, 1, "int", &gravity_trap_spike_spark, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "gravity_trap_destroy", VERSION_SHIP, 1, "counter", &gravity_trap_destroy, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "gravity_trap_location", VERSION_SHIP, 1, "int", &gravity_trap_location, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "gravity_slam_fx", VERSION_SHIP, 1, "int", &gravity_slam_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("toplayer", "gravity_slam_player_fx", VERSION_SHIP, 1, "counter", &gravity_slam_player_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "sparky_beam_fx", VERSION_SHIP, 1, "int", &play_sparky_beam_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("actor", "sparky_zombie_fx", VERSION_SHIP, 1, "int", &sparky_zombie_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("actor", "sparky_zombie_trail_fx", VERSION_SHIP, 1, "int", &sparky_zombie_trail_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("toplayer", "gravity_trap_rumble", VERSION_SHIP, 1, "int", &gravity_trap_rumble_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("actor", "ragdoll_impact_watch", VERSION_SHIP, 1, "int", &ragdoll_impact_watch_start, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register("actor", "gravity_spike_zombie_explode_fx", VERSION_TU12, 1, "counter", &gravity_spike_zombie_explode, !!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function gravity_slam_down( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self LaunchRagdoll( ( 0, 0, -GRAVITY_SLAM_SPEED ) );
	}
}

function gravity_slam_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		if ( IsDefined( self.slam_fx ) )
		{
			DeleteFX( localClientNum, self.slam_fx, true );
		}
		PlayFxOnTag( localClientNum, level._effect["gravityspikes_slam"], self, "tag_origin" );
	}
}

function gravity_slam_player_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump ) // self = player
{
	PlayFXOnCamera(localClientNum, level._effect["gravityspikes_slam_1p"]); 
}		

function gravity_trap_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump ) // self = tag model for gravity trap
{
	if( newVal == 1 )
	{
		self.b_gravity_trap_fx = true;
		
		if ( !isdefined( level.a_mdl_gravity_traps ) )
		{
			level.a_mdl_gravity_traps = []; // create array to track all gravity spikes. used for beam source in zombie beam fx
		}
		
		if ( !IsInArray( level.a_mdl_gravity_traps, self ) )
		{
			ARRAY_ADD( level.a_mdl_gravity_traps, self ); // if this gravity spike is not listed in array, add it
		}
		
		PlayFxOnTag( localClientNum, level._effect["gravityspikes_trap_start"], self, "tag_origin" );
		
		wait 0.5; // wait to start up looping effect.

		if( IS_TRUE( self.b_gravity_trap_fx ) ) // won't start if already expired
		{
			self.n_gravity_trap_fx = PlayFxOnTag( localClientNum, level._effect["gravityspikes_trap_loop"], self, "tag_origin" );
		}
	}
	else
	{
		self.b_gravity_trap_fx = undefined;
		
		if ( isdefined( self.n_gravity_trap_fx ) )
		{
			DeleteFx( localClientNum, self.n_gravity_trap_fx, true );
			
			self.n_gravity_trap_fx = undefined;
		}
		
		ArrayRemoveValue( level.a_mdl_gravity_traps, self ); // gravity trap done, stop tracking this model
		
		PlayFxOnTag( localClientNum, level._effect["gravityspikes_trap_end"], self, "tag_origin" );
	}	
}

function gravity_trap_spike_spark( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self.spark_fx_id = PlayFxOnTag( localClientNum, level._effect["gravity_trap_spike_spark"], self, "tag_origin" );
	}
	else
	{
		if ( isdefined( self.spark_fx_id ) )
		{
			DeleteFx( localClientNum, self.spark_fx_id, true );
		}
	}		
}

function gravity_trap_location( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == 1 )
	{
		self.fx_id_location = PlayFxOnTag( localClientNum, level._effect["gravityspikes_location"], self, "tag_origin" );
	}
	else
	{
		if ( isdefined( self.fx_id_location ) )
		{
			DeleteFx( localClientNum, self.fx_id_location, true );
			self.fx_id_location = undefined;
		}
	}		
}

function gravity_trap_destroy( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	PlayFx( localClientNum, level._effect["gravityspikes_destroy"], self.origin );
}

// ------------------------------------------------------------------------------------------------------------
//	Ragdoll impact watcher
//	wait till impact to check height difference
// ------------------------------------------------------------------------------------------------------------
function ragdoll_impact_watch_start( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasDemoJump ) // self = zombie
{
	if( newVal == 1 )
	{
		self thread ragdoll_impact_watch(localClientNum);
	}
}

function ragdoll_impact_watch(localClientNum) // self = zombie
{
	self endon("entityshutdown");
 
 	self.v_start_pos = self.origin;
 
	n_wait_time = .05; //update rate (seconds)
	n_gib_speed = 20; //units/sec

	v_prev_origin = self.origin;
	waitrealtime( n_wait_time );

	v_prev_vel = self.origin - v_prev_origin;
	n_prev_speed = length( v_prev_vel );
	v_prev_origin = self.origin;
	waitrealtime( n_wait_time );

	b_first_loop = true;

	while( true )
	{
 		v_vel = self.origin - v_prev_origin;
		n_speed = length( v_vel );

		if( n_speed < n_prev_speed * 0.5 && n_speed <= n_gib_speed && !b_first_loop )
		{
			if( self.origin[2] > ( self.v_start_pos[2] + 128 ) )
			{
				if ( isdefined( level._effect[ "zombie_guts_explosion" ] ) && util::is_mature() )
				{
					PlayFX( localClientNum, level._effect["zombie_guts_explosion"], self.origin, AnglesToForward( self.angles ) );
				}				
				
				self Hide();
			} 
			
			break;
 		}

		v_prev_origin = self.origin;
		n_prev_speed = n_speed;
		b_first_loop = false;

		waitrealtime( n_wait_time );
	}      
}

// ------------------------------------------------------------------------------------------------------------
//	VORTEX RUMBLE ON PLAYER
// ------------------------------------------------------------------------------------------------------------
function gravity_trap_rumble_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump ) // self = player
{
	if( newVal == 1 ) 
	{
		self thread gravity_trap_rumble( localClientNum );
	}
	else
	{		
		self notify( "vortex_stop" );
	}
}	
	
function gravity_trap_rumble( localClientNum ) // self = player
{
	level endon("demo_jump"); // end when theater mode rewinds
	self endon( "vortex_stop" );
	self endon( "death" );
	
	while( isdefined(self) )
	{
		self PlayRumbleOnEntity( localClientNum, VORTEX_RUMBLE_INTERIOR );
		wait 0.075;
	}
}

// ------------------------------------------------------------------------------------------------------------
//	Beam for Spike planted
// ------------------------------------------------------------------------------------------------------------
function play_sparky_beam_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump ) // self = zombie
{
	if( newVal == 1 )
	{	
		ai_zombie = self;
	
		a_sparky_tags = Array( "J_Spine4", "J_SpineUpper", "J_Spine1" );
		str_tag = array::random( a_sparky_tags );
		
		if ( isdefined( level.a_mdl_gravity_traps ) )
		{
			mdl_gravity_trap = ArrayGetClosest( self.origin, level.a_mdl_gravity_traps ); // search all deployed gravity traps for the closest one
		}
	
		if( isdefined( mdl_gravity_trap ) ) // use closest gravity trap for the beam source
		{
			self.e_sparky_beam = BeamLaunch( localClientNum, mdl_gravity_trap, "tag_origin", ai_zombie, str_tag, STR_GRAVITY_TRAP_BEAM );
		}
	}
	else
	{
		if( isdefined( self.e_sparky_beam ) )
		{
			BeamKill( localclientnum, self.e_sparky_beam );
		}
	}			
}

function sparky_zombie_fx_cb(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump) // self = zombie
{
	if( newVal == 1 ) // sparks while running around
	{
		if( !isdefined( self.sparky_loop_snd ) )
		{
			self.sparky_loop_snd = self PlayLoopSound( "zmb_electrozomb_lp", 0.2 );
		}

		self.n_sparky_fx = PlayFXOnTag( localClientNum, level._effect["zombie_sparky"], self, "J_SpineUpper" );
		SetFXIgnorePause( localClientNum, self.n_sparky_fx, true );
		
		self.n_sparky_fx = PlayFXOnTag( localClientNum, level._effect["zombie_spark_light"], self, "J_SpineUpper" );
		SetFXIgnorePause( localClientNum, self.n_sparky_fx, true );
	}
	else
	{
		if ( isdefined( self.n_sparky_fx ) )
		{
			DeleteFx( localClientNum, self.n_sparky_fx, true );
		}
		self.n_sparky_fx = undefined;
	}		
}

function sparky_zombie_trail_fx_cb(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump) // self = zombie
{
	if( newVal == 1 ) // sparks while running around
	{
		self.n_trail_fx = PlayFXOnTag( localClientNum, level._effect["zombie_spark_trail"], self, "J_SpineUpper" );
		SetFXIgnorePause( localClientNum, self.n_trail_fx, true );
	}
	else
	{
		if ( isdefined( self.n_trail_fx ) )
		{
			DeleteFx( localClientNum, self.n_trail_fx, true );
		}
		self.n_trail_fx = undefined;
	}		
}

function gravity_spike_zombie_explode(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self endon( "entityshutdown" );
	
	self util::waittill_dobj( localClientNum );
	
	// one shot body explosion
	PlayFxOnTag( localClientNum, level._effect[ "gravity_spike_zombie_explode" ], self, "j_spine4" );
}
