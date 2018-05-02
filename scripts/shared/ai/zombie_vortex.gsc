#using scripts\shared\system_shared;
#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\zombie_vortex.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#namespace zombie_vortex;

REGISTER_SYSTEM_EX( "vortex_shared", &__init__, &__main__, undefined )

	
function __init__()
{
	DEFAULT( level.vsmgr_prio_visionset_zombie_vortex, VORTEX_VISIONSET_PRIORITY );
	DEFAULT( level.vsmgr_prio_overlay_zombie_vortex, VORTEX_OVERLAY_PRIORITY );
	
	visionset_mgr::register_info( "visionset", VORTEX_SCREEN_EFFECT_NAME + "_visionset", VERSION_SHIP, level.vsmgr_prio_visionset_zombie_vortex, VORTEX_VISIONSET_LERP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, false );
	visionset_mgr::register_info( "overlay", VORTEX_SCREEN_EFFECT_NAME + "_blur", VERSION_SHIP, level.vsmgr_prio_overlay_zombie_vortex, VORTEX_OVERLAY_LERP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, true );
	
	clientfield::register( "scriptmover", VORTEX_START_CLIENTFIELD, VERSION_SHIP, 2, "counter" );
	clientfield::register( "allplayers", "vision_blur", VERSION_SHIP, 1, "int" );
	
	level.vortex_manager = SpawnStruct();
	level.vortex_manager.count = 0;
	level.vortex_manager.a_vorticies = [];
	level.vortex_manager.a_active_vorticies = [];

	level.vortex_id = 0;
	
	init_vortices();
}

function __main__()
{
	level vehicle_ai::register_custom_add_state_callback( &idgun_add_vehicle_death_state );	
}


function init_vortices()
{
	i = 0;
	while( i < NUMBER_OF_VORTICES )
	{
		sVortex = Spawn( "script_model", (0,0,0) );
		ARRAY_ADD( level.vortex_manager.a_vorticies, sVortex );
		i++;
	}
}

function get_unused_vortex()
{
	foreach( vortex in level.vortex_manager.a_vorticies )
	{
		if( !IS_TRUE( vortex.in_use ) )
		{
			return vortex;			
		}
	}
	return level.vortex_manager.a_vorticies[0];
}

function get_active_vortex_count()
{
	count = 0;
	foreach( vortex in level.vortex_manager.a_vorticies )
	{
		if( IS_TRUE( vortex.in_use ) )
		{
			count++;
		}
	}
	return count;
}


function private stop_vortex_fx_after_time( vortex_fx_handle, vortex_position, vortex_explosion_fx, n_vortex_time )
{
	n_starttime = GetTime();
	n_curtime = GetTime() - n_starttime;
	
	while( n_curtime < n_vortex_time )
	{
		wait 0.05;
		n_curtime = GetTime() - n_starttime;
	}
	
	
}


/@
"Name: start_timed_vortex( <v_vortex_origin>, <n_vortex_radius>, <vortex_pull_duration> )"
"Summary: Spawns an interdimensional vortex at a given position."
"Module: Zombie Utility"
"CallOn: "
"MandatoryArg: <v_vortex_origin> Where the vortex should spawn."
"MandatoryArg: <n_vortex_radius> The radius of the vortex."
"MandatoryArg: <vortex_pull_duration> How long in seconds the vortex will continue pulling zombies into it."
"OptionalArg: [vortex_effect_duration] How long in seconds the vortex client_fx is. Used to determine how long to wait before exploding."
"OptionalArg: [n_vortex_explosion_radius] The radius of the vortex explosion."
"OptionalArg: [eAttacker] The entity responsible for the kill."
"OptionalArg: [weapon] The weapon responsible for the kill."
"OptionalArg: [should_shellshock_player] If the player should have the vortex visionset activated on them."
"OptionalArg: [visionset_func] Override for the vortex visionset function."
"OptionalArg: [should_shield] If the vortex should protect entity from incidental death so that complete effect can be seen."
"OptionalArg: [effect_version] The version of the effect to play (defined in zombie_utility.gsh."
"OptionalArg: [should_explode] If the vortex should explode after pulling zombies in."
"OptionalArg: [vortex_projectile] The entity that is responsible for the vortex kill."
"Example: start_timed_vortex( (1500, 900, 300), 100, 5, player );"
"SPMP: zombies"
@/ 
function start_timed_vortex( v_vortex_origin, n_vortex_radius, vortex_pull_duration, vortex_effect_duration, n_vortex_explosion_radius, eAttacker, weapon, should_shellshock_player = false, visionset_func = undefined, should_shield = false, effect_version = VORTEX_EFFECT_VERSION_NONE, should_explode = true, vortex_projectile = undefined )
{
	self endon("death");
	self endon("disconnect");
	
	assert( IsDefined( v_vortex_origin ), "Tried to create a vortex without an origin" );
	assert( IsDefined( n_vortex_radius ), "Tried to create a vortex without a radius" );
	assert( IsDefined( vortex_pull_duration ), "Tried to create a vortex without a duration" );
	
	n_starttime = GetTime();
	n_currtime = GetTime() - n_starttime;
	
	a_e_players = GetPlayers();
	
	if( !isDefined( n_vortex_explosion_radius ) )
	{
		n_vortex_explosion_radius = n_vortex_radius * 1.5;
	}

	sVortex = get_unused_vortex();
	sVortex.in_use = true;
	sVortex.attacker = eAttacker;
	sVortex.weapon = weapon;
	sVortex.angles = (0,0,0);
	sVortex.origin = v_vortex_origin;
	
	sVortex DontInterpolate();
	
	sVortex clientfield::increment( VORTEX_START_CLIENTFIELD, effect_version  );
	
	s_active_vortex = struct::spawn(v_vortex_origin);
	s_active_vortex.weapon = weapon;
	s_active_vortex.attacker = eAttacker;

	ARRAY_ADD( level.vortex_manager.a_active_vorticies, s_active_vortex );
	
	n_vortex_time_sv = vortex_pull_duration;
	n_vortex_time_cl = ( IsDefined( vortex_effect_duration ) ? vortex_effect_duration : vortex_pull_duration );
	
	n_vortex_time = n_vortex_time_sv * 1000;
	
	team = "axis";
	
	if( IsDefined( level.zombie_team ) )
   	{
   		team = level.zombie_team;
  	}
	
	while( n_currtime <= n_vortex_time )
	{
		a_ai_zombies = array::get_all_closest( v_vortex_origin, getAITeamArray( team ), undefined, undefined, n_vortex_radius );
		
		// Check for zombies below vortex
		a_ai_zombies = ArrayCombine( a_ai_zombies, vortex_z_extension( a_ai_zombies, v_vortex_origin, n_vortex_radius ), false, false );
		
		sVortex.zombies = a_ai_zombies;
		
		if( IS_TRUE( level.idgun_draw_debug ) )
		{
/# 
			Circle( v_vortex_origin, n_vortex_radius, ( 0, 0, 1 ), false, true, 1 );
#/
		}
			
		
		foreach( ai_zombie in a_ai_zombies )
		{
			if( IsVehicle( ai_zombie ) )
			{
				if(
					IsAlive( ai_zombie ) &&
					IsDefined( ai_zombie vehicle_ai::get_state_callbacks( "idgun_death" ) ) &&
				   	ai_zombie vehicle_ai::get_current_state() != "idgun_death" &&
				  	!ai_zombie.ignorevortices
				  )
				{
					params = SpawnStruct();
					params.vpoint = v_vortex_origin;
					params.attacker = eAttacker;
					params.weapon = weapon;
					if ( IsDefined( ai_zombie.idgun_death_speed ) )
					{
						params.idgun_death_speed = ai_zombie.idgun_death_speed;
					}
					ai_zombie vehicle_ai::set_state( "idgun_death", params );
				}
			}
			else
			{
				if( !IS_TRUE( ai_zombie.interdimensional_gun_kill ) && !ai_zombie.ignorevortices )
				{
					ai_zombie.damageOrigin = v_vortex_origin;
					if(IS_TRUE(should_shield))
					{
						ai_zombie.allowdeath = false;
						ai_zombie.magic_bullet_shield = true;
					}
					ai_zombie.interdimensional_gun_kill = true;
					ai_zombie.interdimensional_gun_attacker = eAttacker;
					ai_zombie.interdimensional_gun_inflictor = eAttacker;
					ai_zombie.interdimensional_gun_weapon = weapon;
					ai_zombie.interdimensional_gun_projectile = vortex_projectile;
				}
			}
		}
		
		if( should_shellshock_player )
		{
			foreach( e_player in a_e_players )
			{
				if( IsDefined( visionset_func ) )
				{
					e_player thread [[visionset_func]](v_vortex_origin, n_vortex_radius, n_starttime, n_vortex_time_sv, n_vortex_time_cl );
				}
				else
				{
					if( IsDefined(e_player) && !IS_TRUE( e_player.idgun_vision_on ) )
					{
						// If Player is within vortex range, apply vision overlay
						if( Distance( e_player.origin, v_vortex_origin ) < Float( n_vortex_radius / 2 ) )
						{
							e_player thread player_vortex_visionset( VORTEX_SCREEN_EFFECT_NAME );
						}
					}
				}
			}
		}
		
		wait 0.05;
		n_currtime = GetTime() - n_starttime;
	}	

	if( IS_TRUE( should_explode ) )
	{	
		n_time_to_wait_for_explosion = ( n_vortex_time_cl  -  n_vortex_time_sv ) + 0.35; //0.35 = time in which the vortex shrinks
		
		wait( n_time_to_wait_for_explosion );
		
		sVortex.in_use = false;
		ArrayRemoveValue( level.vortex_manager.a_active_vorticies, s_active_vortex );

		vortex_explosion( v_vortex_origin, eAttacker, n_vortex_explosion_radius );
	}
	else
	{
		//release zombies that didn't make it into the vortex
		foreach( zombie in sVortex.zombies )
		{
			if( !IsDefined( zombie ) || !IsAlive( zombie ) )
			{
				continue;
			}
			if( IsDefined( level.vortexResetCondition ) && [[level.vortexResetCondition]]( zombie ) )
			{
				continue;
			}
			
			zombie.interdimensional_gun_kill = undefined;
			zombie.interdimensional_gun_attacker = undefined;
			zombie.interdimensional_gun_inflictor = undefined;
			zombie.interdimensional_gun_weapon = undefined;
			zombie.interdimensional_gun_projectile = undefined;
			
			zombie PathMode( "move allowed" );
		}
		
		sVortex.in_use = false;
		ArrayRemoveValue( level.vortex_manager.a_active_vorticies, s_active_vortex );
	}
}

// Include zombies whose bodies are inside the vortex radius, but have origins that are outside the vortex radius
function vortex_z_extension( a_ai_zombies, v_vortex_origin, n_vortex_radius )
{
	a_ai_zombies_extended = array::get_all_closest( v_vortex_origin, getAITeamArray( "axis" ), undefined, undefined, n_vortex_radius + 72 ); // 72 units is the standard AI character height
	a_ai_zombies_extended_filtered = array::exclude( a_ai_zombies_extended, a_ai_zombies );
	
	i = 0;
	while ( i < a_ai_zombies_extended_filtered.size )
	{
		if ( ( a_ai_zombies_extended_filtered[ i ].origin[2] < v_vortex_origin[2] )
		    && BulletTracePassed( a_ai_zombies_extended_filtered[ i ].origin + ( 0, 0, 5 ), v_vortex_origin + ( 0, 0, 20 ), false, self, undefined, false, false ) )
		{
			i++;
		}
		else
		{
			ArrayRemoveValue( a_ai_zombies_extended_filtered, a_ai_zombies_extended_filtered[i]);
		}
	}
	
	return a_ai_zombies_extended_filtered;
}

function private vortex_explosion( v_vortex_explosion_origin, eAttacker, n_vortex_radius )
{
	
	team = "axis";
	
	if( IsDefined( level.zombie_team ) )
   	{
   		team = level.zombie_team;
  	}
	
	a_ai_zombies = array::get_all_closest( v_vortex_explosion_origin, getAITeamArray( team), undefined, undefined, n_vortex_radius );
	
	if( IS_TRUE( level.idgun_draw_debug ) )
	{
/# 
		Circle( v_vortex_explosion_origin, n_vortex_radius, ( 1, 0, 0 ), false, true, 1000 );
#/	
	}
	foreach( ai_zombie in a_ai_zombies )
	{
		if( !ai_zombie.ignorevortices )
		{
			if( IS_TRUE( ai_zombie.interdimensional_gun_kill ) )
			{
				ai_zombie Hide();
			}
			else
			{	
				
				ai_zombie.interdimensional_gun_kill = undefined;
				ai_zombie.interdimensional_gun_kill_vortex_explosion = 1;
				ai_zombie.veh_idgun_allow_damage = true;
				if( IsDefined( eAttacker ) )
				{
					ai_zombie DoDamage( ai_zombie.health + 10000, ai_zombie.origin, eAttacker, undefined, undefined, "MOD_EXPLOSIVE" );
				}
				else
				{
					ai_zombie DoDamage( ai_zombie.health + 10000, ai_zombie.origin, undefined, undefined, undefined, "MOD_EXPLOSIVE" );
				}
				
				n_radius_sqr = n_vortex_radius * n_vortex_radius;
				n_distance_sqr = DistanceSquared( ai_zombie.origin, v_vortex_explosion_origin );
				
				n_dist_mult = n_distance_sqr / n_radius_sqr;
				
				v_fling = VectorNormalize( ai_zombie.origin - v_vortex_explosion_origin );
		
				v_fling = (v_fling[0], v_fling[1], abs( v_fling[2] ));
				v_fling = VectorScale( v_fling, 100 + 100 * n_dist_mult);
				
				if ( !IS_TRUE( level.ignore_vortex_ragdoll ) )
				{
					ai_zombie StartRagdoll();
					ai_zombie LaunchRagdoll( v_fling );
				}
			}
		}
	}
}

// Vision overlay and blur when player enters vortex
// self == player
function player_vortex_visionset( name )
{
	thread visionset_mgr::activate( "visionset", name + "_visionset", self, VORTEX_ENTER_DURATION, VORTEX_LOOP_DURATION, VORTEX_EXIT_DURATION );
	thread visionset_mgr::activate( "overlay", name + "_blur", self, VORTEX_ENTER_DURATION, VORTEX_LOOP_DURATION, VORTEX_EXIT_DURATION );
	self.idgun_vision_on = true;
	wait 2.5;
	self.idgun_vision_on = false;
}

//self = vehicle
function idgun_add_vehicle_death_state()
{
	if( IsAirborne( self ) )
	{
		self vehicle_ai::add_state( "idgun_death",
		&state_idgun_flying_crush_enter,
		&state_idgun_flying_crush_update,
		undefined );
	}
	else
	{
		self vehicle_ai::add_state( "idgun_death",
		&state_idgun_crush_enter,
		&state_idgun_crush_update,
		undefined );
	}
}

// ----------------------------------------------
//vehicle idgun death state
// ----------------------------------------------

function state_idgun_crush_enter( params )
{
	self vehicle_ai::ClearAllLookingAndTargeting();
	self vehicle_ai::ClearAllMovement();
	self CancelAIMove();
}

function flyEntDelete(entToWatch)
{
	self endon("death");
	entToWatch waittill("death");
	self delete();
}

function state_idgun_crush_update( params )
{
	self endon( "death" );
	
	const veh_idgun_move_speed = 8.0;
	const veh_idgun_crush_dist_sqr = 40.0 * 40.0;
	
	black_hole_center = params.vpoint;
	attacker = params.attacker;
	weapon = params.weapon;
	
	if( self.archetype == ARCHETYPE_RAPS )
	{
		crush_anim = "ai_zombie_zod_raps_dth_f_id_gun_crush";
	}

	
	veh_to_black_hole_vec = VectorNormalize( black_hole_center - self.origin );
	
	fly_ent = Spawn( "script_origin", self.origin );
	fly_ent thread flyEntDelete(self);
	self LinkTo( fly_ent );
	
	while( 1 )
	{
		veh_to_black_hole_dist_sqr = DistanceSquared( self.origin, black_hole_center );
		
		if( veh_to_black_hole_dist_sqr < IDGUN_VEH_KILL_DIST_SQR )
		{
			self.veh_idgun_allow_damage = true;
			self DoDamage( self.health + 666, self.origin, attacker, undefined, "none", "MOD_UNKNOWN", 0, weapon );
			return;
		}
		else if( !IS_TRUE( self.crush_anim_started ) && veh_to_black_hole_dist_sqr < veh_idgun_crush_dist_sqr )
		{
			if(isDefined(crush_anim) )
			{
				self AnimScripted( "anim_notify", self.origin, self.angles, crush_anim, "normal", undefined, undefined, 0.2 );
			}
			self.crush_anim_started = true;			
		}
		
		fly_ent.origin += veh_to_black_hole_vec * veh_idgun_move_speed;
		wait( 0.1 );
	}
}

function state_idgun_flying_crush_enter( params )
{
	self vehicle_ai::ClearAllMovement();
	self CancelAIMove();
	
	self SetNearGoalNotifyDist( 4 );
	self.vehAirCraftCollisionEnabled = false;
}

function state_idgun_flying_crush_update( params )
{
	self endon( "death" );
	
	black_hole_center = params.vpoint;
	attacker = params.attacker;
	weapon = params.weapon;
	death_speed = 2;

	if ( IsDefined( params.idgun_death_speed ) )
	{
		death_speed = params.idgun_death_speed;
	}

	self SetSpeed( death_speed );

	self ASMRequestSubstate( "idgun@movement" );
	
	self thread switch_to_crush_asm( black_hole_center );
	self SetVehGoalPos( black_hole_center, false, false );
	self waittill( "near_goal" );
	
	self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_idgun_flying_death_update;
	self.veh_idgun_allow_damage = true;
	self DoDamage( self.health + 666, self.origin, attacker, undefined, "none", "MOD_UNKNOWN", 0, weapon );
}

function switch_to_crush_asm( black_hole_center )
{
	self endon( "death" );
	const veh_idgun_crush_dist_sqr = 30.0 * 30.0;
	
	while( 1 )
	{
		if( DistanceSquared( self.origin, black_hole_center ) < veh_idgun_crush_dist_sqr )
		{
			self ASMRequestSubstate( "idgun_crush@movement" );
			return;
		}
		wait 0.1;
	}
}

function state_idgun_flying_death_update( params )
{
	self endon( "death" );
		
	if( IsDefined( self.parasiteEnemy ) && IsDefined( self.parasiteEnemy.hunted_by ) )
	{
		self.parasiteEnemy.hunted_by--;
	}
	  
	self playsound( "zmb_parasite_explo" );
	
	//wait for sound/fx
	wait 0.2;
	
	self Delete();
}