#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\throttle_shared;
#using scripts\shared\util_shared;
#using scripts\shared\scene_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_hero_weapon;

#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\zombie_vortex;

#using scripts\shared\abilities\_ability_player;

#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\zm\_zm_utility.gsh;
#insert scripts\zm\_zm_weap_gravityspikes.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\zombie_vortex.gsh;

#precache( "string", "ZOMBIE_GRAVITYSPIKE_RECHARGED" );
#precache( "model", "wpn_zmb_dlc1_talon_spike_single_world" );

#namespace zm_weap_gravityspikes;

REGISTER_SYSTEM( "zm_weap_gravityspikes", &__init__, undefined )

#define V_GROUND_OFFSET_FUDGE 						( 0, 0, 32 )
	
#define N_GRAVITYSPIKES_ACTIVE_TIME					20
#define V_PHYSICSTRACE_CAPSULE_MIN					( -16, -16, -16 )
#define V_PHYSICSTRACE_CAPSULE_MAX					( 16, 16, 16 )

#define N_MAX_ZOMBIES_LIFTED_FOR_RAGDOLL			12
#define N_GRAVITYSPIKES_LOS_HEIGHT_OFFSET			50

#define N_GRAVITYSPIKES_MELEE_KILL_RADIUS 		200
#define N_GRAVITYSPIKES_KNOCKDOWN_RADIUS		 400

#define N_GRAVITYSPIKES_MELEE_HEIGHT 				96
#define N_GRAVITYSPIKES_MELEE_PUSH_AWAY				128
#define N_GRAVITY_MELEE_LIFT_HEIGHT_MIN 			128
#define N_GRAVITY_MELEE_LIFT_HEIGHT_MAX 			200
#define N_GRAVITY_MELEE_MIN_LIFT_SPEED			150
#define N_GRAVITY_MELEE_MAX_LIFT_SPEED			200

#define N_GRAVITY_TRAP_SEPERATION					24
#define N_GRAVITY_TRAP_HEIGHT 						96
#define N_GRAVITY_TRAP_PUSH_AWAY					0
#define N_GRAVITY_TRAP_LIFT_HEIGHT_MIN			184
#define N_GRAVITY_TRAP_LIFT_HEIGHT_MAX			284
#define N_GRAVITY_TRAP_MIN_LIFT_SPEED				64
#define N_GRAVITY_TRAP_MAX_LIFT_SPEED				128
#define N_GRAVITY_TRAP_MAX_LIFT_TIME				10
#define V_GRAVITY_TRAP_LIFT_AMOUNT_OFFSET			( 0, 0, -24 )

#define N_GRAVITYSPIKE_HINT_TIMER			 3

#define B_DISABLE_GIBBING							0
#define SPIKES_CHOP_CONE_RANGE						120
	
function __init__()
{
	level.n_zombies_lifted_for_ragdoll = 0;

	level.spikes_chop_cone_range = SPIKES_CHOP_CONE_RANGE;
	level.spikes_chop_cone_range_sq = level.spikes_chop_cone_range * level.spikes_chop_cone_range;

	// throttle used to spread the lifting behavior/reaction of the gravity spikes
	level.ai_gravity_throttle = new Throttle();
	[[ level.ai_gravity_throttle ]]->Initialize( 2, 0.1 );
	
	// throttle used for spreading chopping of actors 
	level.ai_spikes_chop_throttle = new Throttle();
	[[ level.ai_spikes_chop_throttle ]]->Initialize( 6, 0.1 );
	
	register_clientfields();	

	callback::on_connect( &on_connect_func_for_gravityspikes );
	
	zm_hero_weapon::register_hero_weapon( STR_GRAVITYSPIKES_NAME );	// prevents Gravity Spikes from replacing a weapon in player's inventory
	zm_hero_weapon::register_hero_weapon_wield_unwield_callbacks( STR_GRAVITYSPIKES_NAME, &wield_gravityspikes, &unwield_gravityspikes );
	zm_hero_weapon::register_hero_weapon_power_callbacks( STR_GRAVITYSPIKES_NAME, undefined, &gravityspikes_power_expired );
	zm::register_player_damage_callback( &player_invulnerable_during_gravityspike_slam );	// player's very vulnerable during slam

	zm_hero_weapon::register_hero_recharge_event( GetWeapon( STR_GRAVITYSPIKES_NAME ), &gravityspikes_power_override );
}

function register_clientfields()
{
	clientfield::register( "actor", "gravity_slam_down", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "gravity_trap_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "gravity_trap_spike_spark", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "gravity_trap_destroy", VERSION_SHIP, 1, "counter" );
	clientfield::register( "scriptmover", "gravity_trap_location", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "gravity_slam_fx", VERSION_SHIP, 1, "int" );
	clientfield::register("toplayer", "gravity_slam_player_fx", VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", "sparky_beam_fx", VERSION_SHIP, 1, "int" );
	clientfield::register("actor", "sparky_zombie_fx", VERSION_SHIP, 1, "int" );
	clientfield::register("actor", "sparky_zombie_trail_fx", VERSION_SHIP, 1, "int" );
	clientfield::register("toplayer", "gravity_trap_rumble", VERSION_SHIP, 1, "int" );
	clientfield::register("actor", "ragdoll_impact_watch", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "gravity_spike_zombie_explode_fx", VERSION_TU12, 1, "counter" );
}	

function private on_connect_func_for_gravityspikes()	// self == a player
{
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "gravity_spike_expired" );
	
	w_gravityspike = GetWeapon( STR_GRAVITYSPIKES_NAME );
	self update_gravityspikes_state( GRAVITYSPIKES_STATE_NOT_PICKED_UP );
	self.b_gravity_trap_spikes_in_ground = false;
	self.disable_hero_power_charging = false;
	self.b_gravity_trap_fx_on  = false;

	// This will cleanup status of Gravity Spikes if player bleeeds out and loses all weapons
	self thread reset_after_bleeding_out();

	// Wait for player to pick up Gravity Spikes
	do
	{
		self waittill( "new_hero_weapon", weapon );	// from zm_utility::set_player_hero_weapon() which is called by zm_weapons::weapon_give()
	}
	while( weapon != w_gravityspike );
	
	if( isdefined( self.a_gravityspikes_prev_ammo_clip ) && isdefined( self.a_gravityspikes_prev_ammo_clip[ STR_GRAVITYSPIKES_NAME ] ) )
	{
		self SetWeaponAmmoClip( w_gravityspike, self.a_gravityspikes_prev_ammo_clip[ STR_GRAVITYSPIKES_NAME ] );
		self.a_gravityspikes_prev_ammo_clip = undefined;
	}
	else
	{
		self SetWeaponAmmoClip( w_gravityspike, w_gravityspike.clipSize );
	}

	if( isdefined( self.saved_spike_power ) )
	{	
		self GadgetPowerSet( self GadgetGetSlot( w_gravityspike ), self.saved_spike_power );
		self.saved_spike_power = undefined;	
	}
	else
	{
		self GadgetPowerSet( self GadgetGetSlot( w_gravityspike ), 100 );
	}

	self.gravity_trap_unitrigger_stub = undefined;
	
	self thread weapon_drop_watcher();
	self thread weapon_change_watcher();

}

// ------------------------------------------------------------------------------------------------------------
function reset_after_bleeding_out()		// self == a player
{
	self endon( "disconnect" );

	w_gravityspike = GetWeapon( STR_GRAVITYSPIKES_NAME );

	// Give back weapon if they had it when bled out and reset its ammo
	if( IS_TRUE( self.b_has_gravityspikes ) )
	{
		util::wait_network_frame(); // wait for connect function to wait.
		
		self zm_weapons::weapon_give( w_gravityspike, false, true );
		self update_gravityspikes_state( GRAVITYSPIKES_STATE_READY );
	}
		
	self waittill( "bled_out" ); //, "gravity_spike_expired" );
	
	// Upon bleeding out save ammo state and if have weapon.
	if ( self HasWeapon( w_gravityspike ) )
	{	
		self.b_has_gravityspikes = true;

		self.saved_spike_power = self GadgetPowerGet( self GadgetGetSlot( w_gravityspike ) );
		
		// if full power no need to save off.
		if( self.saved_spike_power >= 100 )
		{	
			self.saved_spike_power = undefined;
		}
		
		self.a_gravityspikes_prev_ammo_clip[ STR_GRAVITYSPIKES_NAME ] = self GetWeaponAmmoClip( w_gravityspike );
	}
	
	if( isdefined( self.gravity_trap_unitrigger_stub ) )
	{
		zm_unitrigger::unregister_unitrigger( self.gravity_trap_unitrigger_stub );
		self.gravity_trap_unitrigger_stub = undefined;
	}

	self waittill("spawned_player");
	
	self thread on_connect_func_for_gravityspikes();
}

// ------------------------------------------------------------------------------------------------------------
function gravityspikes_power_override( e_player, ai_enemy ) // self = level
{
	const N_HERO_MINPOWER = 0;
	const N_HERO_MAXPOWER = 100;	

	//no recharge in last stand
	if ( e_player laststand::player_is_in_laststand() )
	{
		return;	
	}

	// no recharge from the gravity spikes themselves
	if ( IS_EQUAL( ai_enemy.damageweapon, GetWeapon( STR_GRAVITYSPIKES_NAME ) ) )
	{
		return;	
	}
	
	// do not allow spikes to recharge if player has not picked up.
	if( IS_TRUE( e_player.disable_hero_power_charging ) )
	{
		return;
	}		
	
	if( isdefined( e_player ) && isdefined(e_player.hero_power) )
	{
		w_gravityspike = GetWeapon( STR_GRAVITYSPIKES_NAME );
		if( isdefined( ai_enemy.heroweapon_kill_power ) )
		{
			n_perk_factor = 1.0;
			if ( e_player hasperk( "specialty_overcharge" ) )
			{
				n_perk_factor = GetDvarFloat( "gadgetPowerOverchargePerkScoreFactor" ); 
			}
			
			//reduce elemental bow  power gains by 0.25
			if ( IsDefined(ai_enemy.damageweapon) && 
			    (IsSubStr( ai_enemy.damageweapon.name, "elemental_bow_demongate" ) || IsSubStr( ai_enemy.damageweapon.name, "elemental_bow_run_prison" ) ||
			     IsSubStr( ai_enemy.damageweapon.name, "elemental_bow_storm" ) || IsSubStr( ai_enemy.damageweapon.name, "elemental_bow_wolf_howl" )) )
			{
				n_perk_factor = 0.25;
			}	
			
			e_player.hero_power = e_player.hero_power + n_perk_factor * ( ai_enemy.heroweapon_kill_power );

			e_player.hero_power = math::clamp( e_player.hero_power, N_HERO_MINPOWER, N_HERO_MAXPOWER );	
			if ( e_player.hero_power >= e_player.hero_power_prev )
			{
				e_player GadgetPowerSet( e_player GadgetGetSlot( w_gravityspike ), e_player.hero_power );
				e_player clientfield::set_player_uimodel( "zmhud.swordEnergy", e_player.hero_power / 100 );
				e_player clientfield::increment_uimodel( "zmhud.swordChargeUpdate" );
			}
			
			if( e_player.hero_power >= 100 )
			{
				e_player update_gravityspikes_state( GRAVITYSPIKES_STATE_READY );
			}		
		}
	}	
}

// ------------------------------------------------------------------------------------------------------------
function wield_gravityspikes( wpn_gravityspikes ) //self = player
{
	self zm_hero_weapon::default_wield( wpn_gravityspikes );

	if( !IS_TRUE( self.b_used_spikes ) )
	{	
		if ( isdefined(self.hintelem) ) // if hint text still on screen destroy immediately
		{
			self.hintelem settext("");
			self.hintelem destroy();
		}
				
		self thread zm_equipment::show_hint_text( &"ZOMBIE_GRAVITYSPIKE_INSTRUCTIONS", N_GRAVITYSPIKE_HINT_TIMER );
		self.b_used_spikes = true;
	}	

	self update_gravityspikes_state( GRAVITYSPIKES_STATE_INUSE );

	self thread gravityspikes_attack_watcher( wpn_gravityspikes );	// RT attack
	self thread gravityspikes_stuck_above_zombie_watcher( wpn_gravityspikes ); //RT attack - stuck above zombies
	self thread gravityspikes_altfire_watcher( wpn_gravityspikes );	// LT attack
	self thread gravityspikes_swipe_watcher( wpn_gravityspikes );	// R3 attack
}

function unwield_gravityspikes( wpn_gravityspikes )
{
	self zm_hero_weapon::default_unwield( wpn_gravityspikes );
	
	self notify( "gravityspikes_attack_watchers_end" );
	
	if( IS_TRUE( self.b_gravity_trap_spikes_in_ground ) )
	{
		self.disable_hero_power_charging = true;
		self thread zm_hero_weapon::continue_draining_hero_weapon( wpn_gravityspikes );
		// Gravity Trap logic
		self thread gravity_trap_loop( self.v_gravity_trap_pos, wpn_gravityspikes );
	}
}

function weapon_drop_watcher() // self = player
{
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_switch_started", w_current );	
		if ( zm_utility::is_hero_weapon( w_current ) )
		{
			self SetWeaponAmmoClip( w_current, 0 );
		}
	}
}	

function weapon_change_watcher() // self = player
{
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_change", w_current, w_previous );	
		if ( isdefined( w_previous ) && zm_utility::is_hero_weapon( w_current ) )
		{
			self.w_gravityspikes_wpn_prev = w_previous;
		}
	}
}	

function gravityspikes_attack_watcher( wpn_gravityspikes )	// self == a player
{
	self endon( "gravityspikes_attack_watchers_end" );
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "gravity_spike_expired" );
	
	while ( true )
	{
		self waittill( "weapon_melee_power", weapon );

		if ( weapon == wpn_gravityspikes )
		{
			self PlayRumbleOnEntity( "talon_spike" );
			self thread knockdown_zombies_slam();
			self thread no_damage_gravityspikes_slam();	// prevent player from getting hurt while slamming
		}
	}
}

function gravityspikes_stuck_above_zombie_watcher( wpn_gravityspikes )
{
	self endon( "gravityspikes_attack_watchers_end" );
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "gravity_spike_expired" );
	
	first_half_traces = true;
		
	while ( zm_utility::is_player_valid( self ) )
	{
		if( !(self IsSlamming()) )
		{
			wait 0.05;
			continue;
		}

		while ( (self IsSlamming()) && (self GetCurrentWeapon()) == wpn_gravityspikes )
		{
			//Apply 6 traces around the player while he is slamming to detect if he is stuck
			player_angles = self GetPlayerAngles();
			
			forward_vec = AnglesToForward( (0, player_angles[1], 0) );
			
			if(forward_vec[0] == 0 && forward_vec[1] == 0 && forward_vec[2] == 0)
			{
				wait 0.05;
				continue;
			}
			
			forward_right_45_vec = RotatePoint(forward_vec, (0, 45, 0));
			forward_left_45_vec = RotatePoint(forward_vec, (0, -45, 0));
			
			right_vec = AnglesToRight(player_angles);
			
			//end_height = GetDvarInt("gravityspikes_stuck_end_height", -35);
			end_height = -35;
			
			start_point = self.origin + ( 0, 0, 50 );
			end_point =  self.origin + ( 0, 0, end_height );
			
			//end_radius = GetDvarInt("gravityspikes_stuck_end_radius", 30);
			end_radius = 30;
			
			trace_end_points = [];
			
			if(first_half_traces) //forward, right, left
			{
				trace_end_points[0] = end_point + VectorScale(forward_vec, end_radius);
				trace_end_points[1] = end_point + VectorScale(right_vec, end_radius);
				trace_end_points[2] = end_point - VectorScale(right_vec, end_radius);
				
				first_half_traces = false;
			}
			else				//forward_45_right, forward_45_left, backward
			{
				trace_end_points[0] = end_point + VectorScale(forward_right_45_vec, end_radius);
				trace_end_points[1] = end_point + VectorScale(forward_left_45_vec, end_radius);
				trace_end_points[2] = end_point - VectorScale(forward_vec, end_radius);
				
				
				first_half_traces = true;
			}
			
			for( i = 0; i < 3; i++ )
			{
				trace = BulletTrace(start_point, trace_end_points[i], true, self);
				
				if( trace["fraction"] < 1 )
				{
					if( IsActor(trace["entity"]) && (trace["entity"].Health > 0) && (trace["entity"].archetype == ARCHETYPE_ZOMBIE || trace["entity"].archetype == ARCHETYPE_ZOMBIE_DOG) )
					{
						self thread knockdown_zombies_slam();
						self thread no_damage_gravityspikes_slam();	// prevent player from getting hurt while slamming
						
						wait 1;
						break;
					}
				}
			}
			
			wait 0.05;
		}
		
		wait 0.05;
	}
}

function gravityspikes_altfire_watcher( wpn_gravityspikes )	// self == a player
{
	self endon( "gravityspikes_attack_watchers_end" );
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "gravity_spike_expired" );
	
	while ( true )
	{
		self waittill( "weapon_melee_power_left", weapon );

		if ( weapon == wpn_gravityspikes && self gravity_spike_position_valid() )
		{
			self thread plant_gravity_trap( wpn_gravityspikes );
		}
	}
}

//check to make sure position is valid
function gravity_spike_position_valid() // self = player
{
	if( isdefined( level.gravityspike_position_check ) )
	{
		return ( self [[level.gravityspike_position_check]]() );
	}
	else if( IsPointOnNavMesh( self.origin, self ) )
	{	
		return true;
	}
}	

function chop_actor( ai, leftswing, weapon = level.weaponNone )
{
	self endon( "disconnect" );

	const N_SPIKES_AUTOKILL_DAMAGE = 3594;	//round23

	if( !isdefined( ai ) || !IsAlive( ai ) )
	{
		// guy died on us 
		return;
	}
	
	if ( N_SPIKES_AUTOKILL_DAMAGE >= ai.health )
	{
		ai.ignoreMelee = true;
	}
	
	[[ level.ai_spikes_chop_throttle ]]->WaitInQueue( ai );
	
	ai DoDamage( N_SPIKES_AUTOKILL_DAMAGE, self.origin, self, self, "none", "MOD_UNKNOWN", 0, weapon );

	util::wait_network_frame();
}

function chop_zombies( first_time, leftswing, weapon = level.weaponNone )
{
	view_pos = self GetWeaponMuzzlePoint();
	forward_view_angles = self GetWeaponForwardDir();
	

	zombie_list = GetAITeamArray( level.zombie_team );
	foreach( ai in zombie_list )
	{
		if ( !IsDefined( ai ) || !IsAlive( ai ) )
		{
			continue;
		}

		if( first_time )
		{
			ai.chopped = false;	//reset on first swipe
		}
		else if( IS_TRUE(ai.chopped) )
		{
			continue;
		}

		test_origin = ai getcentroid();
		dist_sq = DistanceSquared( view_pos, test_origin );

		dist_to_check = level.spikes_chop_cone_range_sq;
		if ( dist_sq > dist_to_check )
		{
			continue;
		}
	
		normal = VectorNormalize( test_origin - view_pos );
		dot = VectorDot( forward_view_angles, normal );
		if (dot <= 0.0 )
		{
			continue;
		}
	
		if ( 0 == ai DamageConeTrace( view_pos, self ) )
		{
			// guy can't actually be hit from where we are
			continue;
		}
	
		ai.chopped = true;

		if ( isdefined( ai.chop_actor_cb ) )
		{
			self thread [[ ai.chop_actor_cb ]]( ai, self, weapon );
		}
		else
		{
			self thread chop_actor( ai, leftswing, weapon );
		}
	}
}

function spikesarc_swipe( player )
{
	player thread chop_zombies( true, true, self );
	wait( 0.3 );
	player thread chop_zombies( false, true, self );
	wait( 0.5 );
	player thread chop_zombies( false, false, self );
}

function gravityspikes_swipe_watcher( wpn_gravityspikes )	// self == a player
{
	self endon( "gravityspikes_attack_watchers_end" );
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "gravity_spike_expired" );
	
	while ( true )
	{
		self waittill( "weapon_melee", weapon );

		weapon thread spikesarc_swipe( self );
	}
}

//////////////////////////////////////////////////////////////////
//	Power Update - Recharges power as player kills zombies
//
//////////////////////////////////////////////////////////////////

function gravityspikes_power_update( player )	// self == level
{
	if( !IS_TRUE( player.disable_hero_power_charging ) )
	{
		player GadgetPowerSet( 0, 100 );
		
		player update_gravityspikes_state( GRAVITYSPIKES_STATE_READY );
	}
}

function gravityspikes_power_expired( weapon )
{
	self zm_hero_weapon::default_power_empty( weapon );
	self notify( "stop_draining_hero_weapon" );
	self notify( "gravityspikes_timer_end" );
}

//////////////////////////////////////////////////////////////////
//	Invulnerability - Special cases
//
//////////////////////////////////////////////////////////////////

function player_invulnerable_during_gravityspike_slam( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex )
{
	if( self.gravityspikes_state === GRAVITYSPIKES_STATE_INUSE && ( self IsSlamming() || IS_TRUE( self.gravityspikes_slam ) ) )
	{
		return 0;
	}
	else
	{
		return -1;
	}
}

function no_damage_gravityspikes_slam()	// self == a player
{
	self.gravityspikes_slam = true;
	wait 1.5;	// amount of invulnerability time for player
	self.gravityspikes_slam = false;
}

// ------------------------------------------------------------------------------------------------------------
//	Gravity Trap Planted - Player near
// ------------------------------------------------------------------------------------------------------------
function player_near_gravity_vortex( v_vortex_origin ) // self = player that planted trap
{
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );

	while( IS_TRUE( self.b_gravity_trap_spikes_in_ground ) && IS_EQUAL( self.gravityspikes_state, GRAVITYSPIKES_STATE_INUSE ) )
	{
		foreach( e_player in level.activeplayers )
		{
			if( isdefined(e_player) && !IS_TRUE( e_player.idgun_vision_on ) )
			{
				// If Player is within vortex range, apply vision overlay
				if( Distance( e_player.origin, v_vortex_origin ) < Float( N_GRAVITY_TRAP_RADIUS / 2 ) )
				{
					e_player thread zombie_vortex::player_vortex_visionset( VORTEX_SCREEN_EFFECT_NAME );
					if( !IS_TRUE( e_player.vortex_rumble ) )
					{	
						self thread player_vortex_rumble( e_player, v_vortex_origin );
					}
				}
			}
		}
		WAIT_SERVER_FRAME;
	}
}

function player_vortex_rumble( e_player, v_vortex_origin ) // self = player that planted trap
{
	e_player endon( "disconnect" );
	e_player endon( "bled_out" );
	e_player endon( "death" );
		
	e_player.vortex_rumble = true;
	
	e_player clientfield::set_to_player( "gravity_trap_rumble", 1 );
	
	while( Distance( e_player.origin, v_vortex_origin ) < Float( N_GRAVITY_TRAP_RADIUS / 2 ) && IS_EQUAL( self.gravityspikes_state, GRAVITYSPIKES_STATE_INUSE ) )
	{
		WAIT_SERVER_FRAME;
	}
	
	e_player clientfield::set_to_player( "gravity_trap_rumble", 0 );
	e_player.vortex_rumble = undefined;
}	

// ------------------------------------------------------------------------------------------------------------
//	Gravity Trap Planted - Alt fire
// ------------------------------------------------------------------------------------------------------------
function plant_gravity_trap( wpn_gravityspikes )	// self == a player
{
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );

	v_forward = AnglesToForward( self.angles );
	v_right = AnglesToRight( self.angles );
	// Set starting positions
	v_spawn_pos_right = self.origin + V_GROUND_OFFSET_FUDGE;
	v_spawn_pos_left = v_spawn_pos_right;
	// Trace to the right & left
	a_trace = PhysicsTraceEx( v_spawn_pos_right, v_spawn_pos_right + ( v_right * N_GRAVITY_TRAP_SEPERATION ), V_PHYSICSTRACE_CAPSULE_MIN, V_PHYSICSTRACE_CAPSULE_MAX, self );
	v_spawn_pos_right += ( v_right * ( a_trace[ "fraction" ] * N_GRAVITY_TRAP_SEPERATION ) );
	a_trace = PhysicsTraceEx( v_spawn_pos_left, v_spawn_pos_left + ( v_right * -N_GRAVITY_TRAP_SEPERATION ), V_PHYSICSTRACE_CAPSULE_MIN, V_PHYSICSTRACE_CAPSULE_MAX, self );
	v_spawn_pos_left += ( v_right * ( a_trace[ "fraction" ] * -N_GRAVITY_TRAP_SEPERATION ) );
	// Find the ground position
	v_spawn_pos_right = util::ground_position( v_spawn_pos_right, 1000, 24 );
	v_spawn_pos_left = util::ground_position( v_spawn_pos_left, 1000, 24 );
	// "Plant" spikes in ground
	a_v_spawn_pos = array( v_spawn_pos_right, v_spawn_pos_left );
	self create_gravity_trap_spikes_in_ground( a_v_spawn_pos );
	
	if( self IsOnGround() )
	{
		// If player's on the ground, use player's position as center of gravity trap
		v_gravity_trap_pos = self.origin + V_GROUND_OFFSET_FUDGE;
	}
	else
	{
		// Find position between planted spikes for FX
		v_gravity_trap_pos = util::ground_position( self.origin, 1000, Length( V_GROUND_OFFSET_FUDGE ) );
	}
	self gravity_trap_fx_on( v_gravity_trap_pos );

	self zm_weapons::switch_back_primary_weapon( self.w_gravityspikes_wpn_prev, true );
	
	self SetWeaponAmmoClip( wpn_gravityspikes, 0 );
	
	self.b_gravity_trap_spikes_in_ground = true;
	self.v_gravity_trap_pos = v_gravity_trap_pos;
	self notify( "gravity_trap_planted" );

	// will play blur if player gets near planted trap.
	self thread player_near_gravity_vortex( v_gravity_trap_pos );

	// Clean up: will wait for notify
	self thread destroy_gravity_trap_spikes_in_ground();
	
	self util::waittill_any( "gravity_trap_spikes_retrieved", "disconnect","bled_out" );

	if( isdefined( self ) )
	{	
		self.b_gravity_trap_spikes_in_ground = false;
		self.disable_hero_power_charging = false;
		self notify( "destroy_ground_spikes" );
	}
}

// ------------------------------------------------------------------------------------------------------------
function gravity_trap_loop( v_gravity_trap_pos, wpn_gravityspikes )	// self == a player
{
	self endon( "gravity_trap_spikes_retrieved" );
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	
	is_gravity_trap_fx_on = true;
	
	while( true )
	{
		// checking to make sure not only in use but has power
		if( self zm_hero_weapon::is_hero_weapon_in_use() && ( self.hero_power > 0 ) )
		{
			a_zombies = GetAITeamArray( level.zombie_team );
			a_zombies = array::filter( a_zombies, false, &gravityspikes_target_filtering );
			array::thread_all( a_zombies, &gravity_trap_check, self );			
		}
		else if( is_gravity_trap_fx_on  )
		{
			self gravity_trap_fx_off();
			is_gravity_trap_fx_on  = false;
			
			self update_gravityspikes_state( GRAVITYSPIKES_STATE_DEPLETED );

			util::wait_network_frame(); // wait to create unitrigger till all else set to avoid retrieved notify too soon
			
			// Create unitrigger so player can retrieve the planted spikes
			self create_gravity_trap_unitrigger( v_gravity_trap_pos, wpn_gravityspikes );

			// fix for hero weapon possibly set as still in use
			if( self zm_hero_weapon::is_hero_weapon_in_use() )
			{	
				self gravityspikes_power_expired( wpn_gravityspikes );
			}
			
			return;
		}
		
		wait 0.1;	// loop delay
	}
}

function gravity_trap_check( player )	// self == a zombie
{
	player endon( "gravity_trap_spikes_retrieved" );
	player endon( "disconnect" );
	player endon( "bled_out" );
	player endon( "death" );
	
	assert( IsDefined( level.ai_gravity_throttle ) );
	assert( IsDefined( player ) );
			
	n_gravity_trap_radius_sq = N_GRAVITY_TRAP_RADIUS * N_GRAVITY_TRAP_RADIUS;
	v_gravity_trap_origin = player.mdl_gravity_trap_fx_source.origin;
	
	// Don't do anything if zombie's dead or has already been caught by trap
	if( !isdefined( self ) || !IsAlive( self ) )
	{
		return;
	}

	if( self check_for_range_and_los( v_gravity_trap_origin, N_GRAVITY_TRAP_HEIGHT, n_gravity_trap_radius_sq ) )
	{	
		if( self.in_gravity_trap === true )
		{
			return;				
		}
		self.in_gravity_trap = true;
		
		// this zombie is in trap, wait for thottle to allow the zombie lifting behavior
		// level.ai_gravity_throttle will spread the gravity spike reaction over multiple frames for better network performace
		[[level.ai_gravity_throttle]]->WaitInQueue(self);
		
		if( IsDefined(self) && IsAlive(self) )
		{
			self zombie_lift( 	player, 
							v_gravity_trap_origin, 
							0, 
							RandomIntRange( N_GRAVITY_TRAP_LIFT_HEIGHT_MIN, N_GRAVITY_TRAP_LIFT_HEIGHT_MAX ), 
							V_GRAVITY_TRAP_LIFT_AMOUNT_OFFSET, 
							RandomIntRange( N_GRAVITY_TRAP_MIN_LIFT_SPEED, N_GRAVITY_TRAP_MAX_LIFT_SPEED ) );
		}
	}	
}


//////////////////////////////////////////////////////////////////
//	Gravity Trap util functions
//	TODO?: Spawning these models could also be client sided?
//////////////////////////////////////////////////////////////////

function create_gravity_trap_spikes_in_ground( a_v_spawn_pos )		// self == a player
{
	if( !isdefined( self.mdl_gravity_trap_spikes ) )
	{
		self.mdl_gravity_trap_spikes = [];
	}
	
	for( i = 0; i < a_v_spawn_pos.size; i++ )
	{
		if( !isdefined( self.mdl_gravity_trap_spikes[ i ] ) )
		{
			self.mdl_gravity_trap_spikes[ i ] = util::spawn_model( "wpn_zmb_dlc1_talon_spike_single_world", a_v_spawn_pos[ i ] );
		}
		
		self.mdl_gravity_trap_spikes[ i ].origin = a_v_spawn_pos[ i ];
		
		// angle spikes based on players angles when planted
		self.mdl_gravity_trap_spikes[ i ].angles = self.angles;
		self.mdl_gravity_trap_spikes[ i ] Show();

		WAIT_SERVER_FRAME;	// Need this wait here so the updated position gets used for clientside FX

		self.mdl_gravity_trap_spikes[ i ] thread gravity_spike_planted_play();
		self.mdl_gravity_trap_spikes[ i ] clientfield::set( "gravity_trap_spike_spark", 1 );

		// can trigger things off of placing the gravity trap spikes in level-specific override
		if( isdefined( level.gravity_trap_spike_watcher ) )
		{
			[[ level.gravity_trap_spike_watcher ]]( self.mdl_gravity_trap_spikes[ i ] );
		}
	}
}

function gravity_spike_planted_play() // self = gravity spike model.
{
	const N_TIME_INIT = 2;
	
	wait N_TIME_INIT; // wait till finished planted to open.

	self thread scene::play( "cin_zm_dlc1_spike_plant_loop", self );
}	


function destroy_gravity_trap_spikes_in_ground()		// self == a player
{
	mdl_spike_source = self.mdl_gravity_trap_fx_source;
	mdl_gravity_trap_spikes = self.mdl_gravity_trap_spikes;

	self util::waittill_any( "destroy_ground_spikes", "disconnect", "bled_out" );
	
	if( isdefined( mdl_spike_source ) )
	{
		mdl_spike_source clientfield::set( "gravity_trap_location", 0 );
		mdl_spike_source Ghost();
		
		if(!isdefined( self ) ) // if player disconnected or bled out delete.
		{
			mdl_spike_source Delete();
		}		
	}

	if( !isdefined( mdl_gravity_trap_spikes ) )
	{
		return;
	}
	
	for( i = 0; i < mdl_gravity_trap_spikes.size; i++ )
	{
		//self.mdl_gravity_trap_spikes[ i ] clientfield::increment( "gravity_trap_destroy" ); in case they decide to bring it back

		mdl_gravity_trap_spikes[ i ] thread scene::stop( "cin_zm_dlc1_spike_plant_loop" );
		mdl_gravity_trap_spikes[ i ] clientfield::set( "gravity_trap_spike_spark", 0 );
			
		mdl_gravity_trap_spikes[ i ] Ghost();
		
		if(!isdefined( self ) ) // if player disconnected or bled out delete.
		{
			mdl_gravity_trap_spikes[ i ] Delete();
		}
	}
}

function gravity_trap_fx_on( v_spawn_pos )	// self == a player
{
	if( !isdefined( self.mdl_gravity_trap_fx_source ) )
	{
		self.mdl_gravity_trap_fx_source = util::spawn_model( "tag_origin", v_spawn_pos );	
	}
	self.mdl_gravity_trap_fx_source.origin = v_spawn_pos;
	self.mdl_gravity_trap_fx_source Show();

	WAIT_SERVER_FRAME;	// Need this wait here so the updated position gets used for clientside FX
	
	self.mdl_gravity_trap_fx_source clientfield::set( "gravity_trap_fx", 1 );
}

function gravity_trap_fx_off()	// self == a player
{
	if( !isdefined( self.mdl_gravity_trap_fx_source ) )
	{
		return;
	}
	self.mdl_gravity_trap_fx_source clientfield::set( "gravity_trap_fx", 0 );
	
	self.mdl_gravity_trap_fx_source clientfield::set( "gravity_trap_location", 1 );
}

//////////////////////////////////////////////////////////////////
//	Gravity Trap unitrigger stuff
//
//////////////////////////////////////////////////////////////////

function create_gravity_trap_unitrigger( v_origin, wpn_gravityspikes )		// self == the player what created this here Gravity Trap
{
	// fix for jump and creating 2 triggers
	if( isdefined( self.gravity_trap_unitrigger_stub ) )
	{
		return;	
	}
	
	unitrigger_stub = spawnstruct();
	unitrigger_stub.origin = v_origin;
	unitrigger_stub.script_unitrigger_type = "unitrigger_radius_use";
	unitrigger_stub.cursor_hint = "HINT_NOICON";
	unitrigger_stub.radius = N_GRAVITY_TRAP_RADIUS;
	unitrigger_stub.require_look_at = false;
	unitrigger_stub.gravityspike_owner = self;
	unitrigger_stub.wpn_gravityspikes = wpn_gravityspikes;
	
	self.gravity_trap_unitrigger_stub = unitrigger_stub;

	zm_unitrigger::unitrigger_force_per_player_triggers(unitrigger_stub, true);

	unitrigger_stub.prompt_and_visibility_func = &gravity_trap_trigger_visibility;
	zm_unitrigger::register_static_unitrigger( unitrigger_stub, &gravity_trap_trigger_think );
}
	
// self = unitrigger
function gravity_trap_trigger_visibility( player )
{
	if( player == self.stub.gravityspike_owner )
	{
		self SetHintString( &"ZOMBIE_GRAVITYSPIKE_PICKUP" );
		return true;
	}
	else
	{
		self setInvisibleToPlayer( player );
		return false;
	}	
}

// self = unitrigger
function gravity_trap_trigger_think()
{
	while( true )
	{
		self waittill( "trigger", player ); // wait until someone uses the trigger

		if( player zm_utility::in_revive_trigger() ) // revive triggers override trap triggers
		{
			continue;
		}
		
		if( IS_DRINKING( player.is_drinking ) )
		{
			continue;
		}
	
		if( !zm_utility::is_player_valid( player ) ) // ensure valid player
		{
			continue;
		}
		
		level thread gravity_trap_trigger_activate( self.stub, player );
		
		break;
	}
}

function gravity_trap_trigger_activate( trig_stub, player )
{
	if( player == trig_stub.gravityspike_owner )
	{
		player notify( "gravity_trap_spikes_retrieved" );
		
		player playsound ("fly_talon_pickup");
		
		if( player.gravityspikes_state == GRAVITYSPIKES_STATE_INUSE )
		{
			player.w_gravityspikes_wpn_prev = player GetCurrentWeapon();
			player GiveWeapon( trig_stub.wpn_gravityspikes );
			player GiveMaxAmmo( trig_stub.wpn_gravityspikes );
			player SetWeaponAmmoClip( trig_stub.wpn_gravityspikes, trig_stub.wpn_gravityspikes.clipSize );
			player SwitchToWeapon( trig_stub.wpn_gravityspikes );
		}
		
		// remove this unitrigger, now that the object is picked up
		zm_unitrigger::unregister_unitrigger( trig_stub );
		player.gravity_trap_unitrigger_stub = undefined;
	}
}


// ------------------------------------------------------------------------------------------------------------
//	Utility Functions
// ------------------------------------------------------------------------------------------------------------
function update_gravityspikes_state( n_gravityspikes_state )	// self == a player
{
	self.gravityspikes_state = n_gravityspikes_state;
}

function update_gravityspikes_energy( n_gravityspikes_power )	// self == a player
{
	self.n_gravityspikes_power = n_gravityspikes_power;
	self clientfield::set_player_uimodel( "zmhud.swordEnergy", self.n_gravityspikes_power );
}

function check_for_range_and_los( v_attack_source, n_allowed_z_diff, n_radius_sq )	// self == a zombie
{
	if( IsAlive( self ) )
	{
		n_z_diff = self.origin[ 2 ] - v_attack_source[ 2 ];
		if( abs( n_z_diff ) < n_allowed_z_diff )
		{
			if( Distance2DSquared( self.origin, v_attack_source ) < n_radius_sq )
			{
				v_offset = ( 0, 0, N_GRAVITYSPIKES_LOS_HEIGHT_OFFSET );
				if( BulletTracePassed( self.origin + v_offset, v_attack_source + v_offset, false, self ) )
				{
					return true;
				}
			}
		}
	}
	return false;	
}

function gravityspikes_target_filtering( ai_enemy )
{
	b_callback_result = true;
	if( isdefined( level.gravityspikes_target_filter_callback ) )
	{
		b_callback_result = [[ level.gravityspikes_target_filter_callback ]]( ai_enemy );
	}
	return b_callback_result;
}

function zombie_lift( player, v_attack_source, n_push_away, n_lift_height, v_lift_offset, n_lift_speed )	// self == a zombie
{
	wpn_gravityspikes = GetWeapon( STR_GRAVITYSPIKES_NAME );
	
	if( IsDefined( self.zombie_lift_override ) )
	{
		self thread [[ self.zombie_lift_override ]]( player, v_attack_source, n_push_away, n_lift_height, v_lift_offset, n_lift_speed );
		return;
	}

	if( IS_TRUE( self.isdog ) || IS_TRUE( self.ignore_zombie_lift ) )	// Just kill dogs since they can't do ragdoll
	{
		self.no_powerups = true; // don't drop powerups
		self DoDamage( self.health + 100, self.origin, player, player, undefined, "MOD_UNKNOWN", 0, wpn_gravityspikes );
		self playsound ("zmb_talon_electrocute_swt");
	}	
	else
	{
		// Control the number of zombies getting lifted up for ragdoll kill
		if( level.n_zombies_lifted_for_ragdoll < N_MAX_ZOMBIES_LIFTED_FOR_RAGDOLL )
		{
			self thread track_lifted_for_ragdoll_count();
			
			v_away_from_source = VectorNormalize( self.origin - v_attack_source );
			v_away_from_source = v_away_from_source * n_push_away;
			v_away_from_source = ( v_away_from_source[ 0 ], v_away_from_source[ 1 ], n_lift_height );
			// Determine how far up we can lift the zombie
			a_trace = PhysicsTraceEx( 	self.origin + V_GROUND_OFFSET_FUDGE, 	// The fudge prevents PhysicsTraceEx from colliding with the ground
										self.origin + v_away_from_source, 
										V_PHYSICSTRACE_CAPSULE_MIN, 
										V_PHYSICSTRACE_CAPSULE_MAX, 
										self );			
		
			v_lift = a_trace[ "fraction" ] * v_away_from_source;
			v_lift = ( v_lift + v_lift_offset );
			n_lift_time = Length( v_lift ) / n_lift_speed;
			

			// For slam just launch zombie
			if( isdefined( self ) && IS_TRUE( self.b_melee_kill ) )
			{
				self SetPlayerCollision( false );

				const N_FLING_FORCE = 150;

				if ( !IS_TRUE( level.ignore_gravityspikes_ragdoll ) )
				{
					self StartRagdoll();
					self LaunchRagdoll( N_FLING_FORCE * AnglesToUp( self.angles ) + ( v_away_from_source[ 0 ], v_away_from_source[ 1 ], 0 ) );
				}

				self clientfield::set( "ragdoll_impact_watch", 1 );

				self clientfield::set( "sparky_zombie_trail_fx", 1 );
			
				util::wait_network_frame();
			}
			// Only lift the zombie if the lift Z is positive and lift vector is longer than the lift offset
			else if( isdefined( self ) && v_lift[ 2 ] > 0 && Length( v_lift ) > Length( v_lift_offset ) )
			{
				// no player collision for rising zombies.
				self SetPlayerCollision( false );

				// play beam and sparky fx ( sparky fx may be used seperately )
				self clientfield::set( "sparky_beam_fx", 1 );
				self clientfield::set( "sparky_zombie_fx", 1 );
				self playsound ("zmb_talon_electrocute");

				if( IS_TRUE( self.missingLegs ) )
				{
					self thread scene::play( "cin_zm_dlc1_zombie_crawler_talonspike_a_loop", self );
				}
				else
				{
					self thread scene::play( "cin_zm_dlc1_zombie_talonspike_loop", self );
				}			

				self.mdl_trap_mover = util::spawn_model( "tag_origin", self.origin, self.angles );
				self thread util::delete_on_death( self.mdl_trap_mover );
				self LinkTo( self.mdl_trap_mover, "tag_origin" );
				
				self.mdl_trap_mover MoveTo(  self.origin + v_lift, n_lift_time, 0, n_lift_time * 0.4 );
				self thread zombie_lift_wacky_rotate( n_lift_time, player );
				
				// Wait 'til lift finishes, zombie is killed, or Gravity Trap expires, player disconnects, etc.
				self thread gravity_trap_notify_watcher( player );
				self waittill( "gravity_trap_complete" );
				
				// slam down
				if ( isdefined(self) )
				{
					self Unlink();
					
					self scene::stop();
					self StartRagdoll( true );
					self clientfield::set( "gravity_slam_down", 1 );
					self clientfield::set( "sparky_beam_fx", 0 );
					self clientfield::set( "sparky_zombie_fx", 0 );
					self clientfield::set( "sparky_zombie_trail_fx", 1 );

					self thread corpse_off_navmesh_watcher();
					self clientfield::set( "ragdoll_impact_watch", 1 );

					// Wait so zombie hitting ground and damage + gibbing are synced
					v_land_pos = util::ground_position( self.origin, 1000 );
					n_fall_dist = abs( self.origin[ 2 ] - v_land_pos[ 2 ] );
					n_slam_wait = ( n_fall_dist / GRAVITY_SLAM_SPEED ) * 0.75;
					if( n_slam_wait > 0 )
					{
						wait n_slam_wait;	// wait here so slam down and killing/gibbing are synced
					}
				}
			}

			if( IsAlive( self ) )
			{
				self zombie_kill_and_gib( player );
				self playsound ("zmb_talon_ai_slam");
			}	
		}			
		// If there's too many ragdoll zombies, just gib and die
		else
		{
			self zombie_kill_and_gib( player );
			self playsound ("zmb_talon_ai_slam");
		}
	}
}

function gravity_trap_notify_watcher( player ) // self = ai zombie
{
	self endon( "gravity_trap_complete" );

	self thread gravity_trap_timeout_watcher();

	util::waittill_any_ents( self, "death", 
		player, "gravity_trap_spikes_retrieved", 
		player, "gravityspikes_timer_end", 
		player, "disconnect", 
		player, "bled_out" );

	self notify( "gravity_trap_complete" );
}
	
function gravity_trap_timeout_watcher() // self = ai zombie
{
	self endon( "gravity_trap_complete" );

	self.mdl_trap_mover util::waittill_any_timeout( 4, "movedone", "gravity_trap_complete" );

	// float in the air a bit, slight pause when zombie reaches max lift height
	if( IsAlive( self ) && !IS_TRUE( self.b_melee_kill ) )
	{
		wait RandomFloatRange( 0.2, 1.0 );	
	}

	self notify( "gravity_trap_complete" );
}

function zombie_lift_wacky_rotate( n_lift_time, player )	// self == a zombie caught in Gravity Trap
{
	player endon( "gravityspikes_timer_end" );
	self endon( "death" );
	
	// Adding a bit of random rotation to zombies caught in Gravity Trap
	while( true )
	{
		negative_x = ( RandomIntRange( 0, 10 ) < 5 ? 1 : -1 );
		negative_z = ( RandomIntRange( 0, 10 ) < 5 ? 1 : -1 );
		
		self.mdl_trap_mover RotateTo( ( RandomIntRange( 90, 180 ) * negative_x, 
											RandomIntRange( -90, 90 ), 
											RandomIntRange( 90, 180 ) * negative_z ), 
											( n_lift_time > 2 ? n_lift_time : N_GRAVITY_TRAP_MAX_LIFT_TIME * 0.5 ), 
											0 );
		self.mdl_trap_mover waittill( "rotatedone" );
	}
}

function zombie_kill_and_gib( player )	// self == a zombie
{
	wpn_gravityspikes = GetWeapon( STR_GRAVITYSPIKES_NAME );
	
	self.no_powerups = true; // don't drop powerups
	// TODO: May not want to kill zombies in later rounds? But then we can't use ragdoll though...
	self DoDamage( self.health + 100, self.origin, player, player, undefined, "MOD_UNKNOWN", 0, wpn_gravityspikes );
	if( !B_DISABLE_GIBBING )
	{
		n_random = RandomInt( 100 );
		
/*		//Commenting out for now, seems to be going back and forth on full exploding death		
		if( n_random >= 60 )				// 40% full annhilator exploding
		{
			self zombie_utility::gib_random_parts();		
			GibServerUtils::Annihilate( self );				
		}
		else if( n_random <= 40 )		// 40% chance single limb gibbing
		{
			self zombie_utility::gib_random_parts();		
		}
*/		
		if( n_random >= 20 )				// 80% random gib
		{
			self zombie_utility::gib_random_parts();		
		}
		
		// 20% chance no gibbing
	}
}

function track_lifted_for_ragdoll_count()	// self == a lifted zombie
{
	level.n_zombies_lifted_for_ragdoll++;
	self waittill( "death" );
	level.n_zombies_lifted_for_ragdoll--;
	// TODO: Maybe reset this var to 0 every round, just in case something wacky happens?
}

function corpse_off_navmesh_watcher() // self = zombie
{
	self waittill( "actor_corpse", e_corpse );	// Wait until killed zombie turns into corpse

	v_pos = GetClosestPointOnNavMesh( e_corpse.origin, 256 );
	
	if( !isdefined( v_pos ) || ( e_corpse.origin[2] > ( v_pos[2] + 64 ) ) )
	{
		e_corpse thread do_zombie_explode();
	}
}

function private do_zombie_explode()	// self = zombie corpse
{
	util::wait_network_frame(); // wait for spawned ent for counter fx.
	
	if( isDefined( self ))
	{
		self zombie_utility::zombie_eye_glow_stop();
		
		self clientfield::increment( "gravity_spike_zombie_explode_fx" );
	
		self Ghost();
		self util::delay( 0.25, undefined, &zm_utility::self_delete );
	}
}

// ------------------------------------------------------------------------
//	Melee Attack
// ------------------------------------------------------------------------
function gravity_spike_melee_kill( v_position, player )	// self == ai zombie
{
	self.b_melee_kill = true;
	
	// Adjusting radius to be egg shaped, so it's longer in front of player and shorter behind player
	n_gravity_spike_melee_radius_sq = N_GRAVITYSPIKES_MELEE_KILL_RADIUS * N_GRAVITYSPIKES_MELEE_KILL_RADIUS;
	
	if( self check_for_range_and_los( v_position, N_GRAVITYSPIKES_MELEE_HEIGHT, n_gravity_spike_melee_radius_sq ) )
	{
		self zombie_lift( 	player, v_position, 
							N_GRAVITYSPIKES_MELEE_PUSH_AWAY, 
							RandomIntRange( N_GRAVITY_MELEE_LIFT_HEIGHT_MIN, N_GRAVITY_MELEE_LIFT_HEIGHT_MAX ), 
							( 0, 0, 0 ), 
							RandomIntRange( N_GRAVITY_MELEE_MIN_LIFT_SPEED, N_GRAVITY_MELEE_MAX_LIFT_SPEED ) );
	}
}

// ------------------------------------------------------------------------
//	Knockdown Zombies 
// ------------------------------------------------------------------------
function knockdown_zombies_slam() // self = player
{
	const N_DISTANCE_OFFSET = 24;
	
	//offset slam position in front of player 
	v_forward = AnglesToForward(self GetPlayerAngles());
	v_pos = self.origin + VectorScale( v_forward, N_DISTANCE_OFFSET );
	
	a_ai = GetAITeamArray( level.zombie_team );
	a_ai = array::filter( a_ai, false, &gravityspikes_target_filtering );
	a_ai_kill_zombies = ArraySortClosest( a_ai, v_pos, a_ai.size, 0, N_GRAVITYSPIKES_MELEE_KILL_RADIUS );
	array::thread_all( a_ai_kill_zombies, &gravity_spike_melee_kill, v_pos, self );	
	
	a_ai_slam_zombies = ArraySortClosest( a_ai, v_pos, a_ai.size, N_GRAVITYSPIKES_MELEE_KILL_RADIUS, N_GRAVITYSPIKES_KNOCKDOWN_RADIUS );
	array::thread_all( a_ai_slam_zombies, &zombie_slam_direction, v_pos );	
		
	self thread play_slam_fx( v_pos );
}

function play_slam_fx( v_pos ) // self = player
{
	mdl_fx_pos = util::spawn_model( "tag_origin", v_pos, ( -90, 0, 0 ) );
		
	WAIT_SERVER_FRAME; // wait to send to client
	
	mdl_fx_pos clientfield::set( "gravity_slam_fx", 1 );
	self clientfield::increment_to_player( "gravity_slam_player_fx" );

	WAIT_SERVER_FRAME; // wait to send to client
	
	mdl_fx_pos Delete();
}	

function zombie_slam_direction( v_position ) // self = ai zombie
{
	self endon( "death" );
	 
	if ( !IS_EQUAL(self.archetype,ARCHETYPE_ZOMBIE ) )
	{	
		return;
	}	
	
	self.knockdown = true;
	
	v_zombie_to_player = v_position - self.origin;
	v_zombie_to_player_2d = VectorNormalize( ( v_zombie_to_player[0], v_zombie_to_player[1], 0 ) );
	
	v_zombie_forward = AnglesToForward( self.angles );
	v_zombie_forward_2d = VectorNormalize( ( v_zombie_forward[0], v_zombie_forward[1], 0 ) );
	
	v_zombie_right = AnglesToRight( self.angles );
	v_zombie_right_2d = VectorNormalize( ( v_zombie_right[0], v_zombie_right[1], 0 ) );
	
	v_dot = VectorDot( v_zombie_to_player_2d, v_zombie_forward_2d );
	
	if( v_dot >= 0.5 )
	{
		self.knockdown_direction = "front";
		self.getup_direction = GETUP_BACK;
	}
	else if ( v_dot < 0.5 && v_dot > -0.5 )
	{
		v_dot = VectorDot( v_zombie_to_player_2d, v_zombie_right_2d );
		if( v_dot > 0 )
		{
			self.knockdown_direction = "right";

			if ( math::cointoss() )
			{
				self.getup_direction = GETUP_BACK;
			}
			else
			{
				self.getup_direction = GETUP_BELLY;
			}
		}
		else
		{
			self.knockdown_direction = "left";
			self.getup_direction = GETUP_BELLY;
		}
	}
	else
	{
		self.knockdown_direction = "back";
		self.getup_direction = GETUP_BELLY;
	}

	wait 1; // wait till knocked down then reset.

	self.knockdown = false;
}	

