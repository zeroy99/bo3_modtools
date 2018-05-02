#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

//TODO update these to proper settings
#define ELECTRIC_CHERRY_PERK_COST						10
#define ELECTRIC_CHERRY_PERK_BOTTLE_WEAPON				"zombie_perk_bottle_cherry"
#define ELECTRIC_CHERRY_SHADER							"specialty_quickrevive_zombies"
#define ELECTRIC_CHERRY_MACHINE_DISABLED_MODEL			"p7_zm_vending_nuke" // "p6_zm_vending_electric_cherry_off"
#define ELECTRIC_CHERRY_MACHINE_ACTIVE_MODEL			"p7_zm_vending_nuke" // "p6_zm_vending_electric_cherry_on"
#define ELECTRIC_CHERRY_RADIANT_MACHINE_NAME			"vending_electriccherry"
#define ELECTRIC_CHERRY_MACHINE_LIGHT_FX				"electric_cherry_light"	


// Global Attack Variables
#define ELECTRIC_CHERRY_STUN_CYCLES			4
// Last Stand Attack
#define ELECTRIC_CHERRY_DOWNED_ATTACK_RADIUS 500
#define ELECTRIC_CHERRY_DOWNED_ATTACK_DAMAGE 1000
#define ELECTRIC_CHERRY_DOWNED_ATTACK_POINTS 40
// Reload Attack
#define RELOAD_ATTACK_MIN_RADIUS 32
#define RELOAD_ATTACK_MAX_RADIUS 128
#define RELOAD_ATTACK_MIN_DAMAGE 1
#define RELOAD_ATTACK_MAX_DAMAGE 1045 // Max damage = zombie health at round 10
#define RELOAD_ATTACK_POINTS 40
#define RELOAD_ATTACK_COOLDOWN_TIMER 3

#precache( "fx", "_t6/misc/fx_zombie_cola_revive_on" );
#precache( "fx", "dlc1/castle/fx_castle_electric_cherry_down" );

#namespace zm_perk_electric_cherry;

REGISTER_SYSTEM( "zm_perk_electric_cherry", &__init__, undefined )

// ELECTRIC CHERRY ( ELECTRIC CHERRY )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_electric_cherry_perk_for_level();
}

function enable_electric_cherry_perk_for_level()
{	
	// register staminup perk for level
	zm_perks::register_perk_basic_info( PERK_ELECTRIC_CHERRY, "electric_cherry", ELECTRIC_CHERRY_PERK_COST, &"ZOMBIE_PERK_WIDOWSWINE", GetWeapon( ELECTRIC_CHERRY_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_ELECTRIC_CHERRY, &electric_cherry_precache );
	zm_perks::register_perk_clientfields( PERK_ELECTRIC_CHERRY, &electric_cherry_register_clientfield, &electric_cherry_set_clientfield );
	zm_perks::register_perk_machine( PERK_ELECTRIC_CHERRY, &electric_cherry_perk_machine_setup );
	zm_perks::register_perk_host_migration_params( PERK_ELECTRIC_CHERRY, ELECTRIC_CHERRY_RADIANT_MACHINE_NAME, ELECTRIC_CHERRY_MACHINE_LIGHT_FX );
	
	zm_perks::register_perk_threads( PERK_ELECTRIC_CHERRY, &electric_cherry_reload_attack , &electric_cherry_perk_lost  );
	
	if( IS_TRUE( level.custom_electric_cherry_perk_threads ) )
	{
		level thread [[ level.custom_electric_cherry_perk_threads ]]();
	}

	init_electric_cherry();
}

function electric_cherry_precache()
{
	if( IsDefined(level.electric_cherry_precache_override_func) )
	{
		[[ level.electric_cherry_precache_override_func ]]();
		return;
	}
	
	level._effect[ELECTRIC_CHERRY_MACHINE_LIGHT_FX] = "_t6/misc/fx_zombie_cola_revive_on";
	
	level.machine_assets[PERK_ELECTRIC_CHERRY] = SpawnStruct();
	level.machine_assets[PERK_ELECTRIC_CHERRY].weapon = GetWeapon( ELECTRIC_CHERRY_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_ELECTRIC_CHERRY].off_model = ELECTRIC_CHERRY_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_ELECTRIC_CHERRY].on_model = ELECTRIC_CHERRY_MACHINE_ACTIVE_MODEL;
}

function electric_cherry_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_ELECTRIC_CHERRY, VERSION_SHIP, 2, "int" );
}

function electric_cherry_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_ELECTRIC_CHERRY, state );
}

function electric_cherry_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_stamin_jingle";
	use_trigger.script_string = "marathon_perk";
	use_trigger.script_label = "mus_perks_stamin_sting";
	use_trigger.target = "vending_marathon";
	perk_machine.script_string = "marathon_perk";
	perk_machine.targetname = "vending_marathon";
	if( IsDefined( bump_trigger ) )
	{
		bump_trigger.script_string = "marathon_perk";
	}
}

//-----------------------------------------------------------------------------------
// functionality
//-----------------------------------------------------------------------------------
function init_electric_cherry()
{	
	level._effect[ "electric_cherry_explode" ]				= "dlc1/castle/fx_castle_electric_cherry_down";
	
	// Last Stand Attack
	level.custom_laststand_func = &electric_cherry_laststand;
	
	zombie_utility::set_zombie_var( "tesla_head_gib_chance", 50 );
	
	// Perk specific Client Fields
	clientfield::register( "allplayers", "electric_cherry_reload_fx",	VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "tesla_death_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "tesla_death_fx_veh", VERSION_TU10, 1, "int" );	// Leave at VERSION_TU10
	clientfield::register( "actor", "tesla_shock_eyes_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "tesla_shock_eyes_fx_veh", VERSION_TU10, 1, "int" );	// Leave at VERSION_TU10
}

function electric_cherry_perk_machine_think()
{	
	init_electric_cherry();

	while ( true )
	{
		machine = getentarray( "vendingelectric_cherry", "targetname" );
		machine_triggers = GetEntArray( "vending_electriccherry", "target" );
		
		// Show "inactive" models
		for( i = 0; i < machine.size; i++ )
		{
			machine[i] SetModel( ELECTRIC_CHERRY_MACHINE_DISABLED_MODEL );
		}
		
		level thread zm_perks::do_initial_power_off_callback( machine, "electriccherry" );
		array::thread_all( machine_triggers, &zm_perks::set_power_on, false );

		level waittill( "electric_cherry_on" );
	
		for( i = 0; i < machine.size; i++ )
		{
			machine[i] SetModel( ELECTRIC_CHERRY_MACHINE_ACTIVE_MODEL );
			machine[i] vibrate( ( 0, -100, 0 ), 0.3, 0.4, 3 );
			machine[i] playsound( "zmb_perks_power_on" );
			machine[i] thread zm_perks::perk_fx( "electriccherry" );
			machine[i] thread zm_perks::play_loop_on_machine();
		}
		
		level notify( "specialty_grenadepulldeath_power_on" );
		
		array::thread_all( machine_triggers, &zm_perks::set_power_on, true );

		level waittill( "electric_cherry_off" );
			
		array::thread_all( machine_triggers, &zm_perks::turn_perk_off );
	}
}

// when host migration occurs, fx don't carry over. If perk machine is on, turn the light back on.
function electric_cherry_host_migration_func()
{
	a_electric_cherry_perk_machines = GetEntArray( "vending_electriccherry", "targetname" );
	
	foreach( perk_machine in a_electric_cherry_perk_machines )
	{
		if( isDefined( perk_machine.model ) && perk_machine.model == ELECTRIC_CHERRY_MACHINE_ACTIVE_MODEL )
		{
			perk_machine zm_perks::perk_fx( undefined, true );
			perk_machine thread zm_perks::perk_fx( "electriccherry" );
		}
	}
}

//-----------------------------------------------------------------------------------
// downed player releases a boom
//-----------------------------------------------------------------------------------

function electric_cherry_laststand()  //self = player
{	
	VisionSetLastStand( "zombie_last_stand", 1 );
	
	if ( IsDefined( self ) )
	{
		PlayFX( level._effect[ "electric_cherry_explode" ], self.origin );
		self PlaySound( "zmb_cherry_explode" );
		self notify( "electric_cherry_start" );
		
		//time for notify to go out
		wait 0.05;
			
		a_zombies = zombie_utility::get_round_enemy_array();
		a_zombies = util::get_array_of_closest( self.origin, a_zombies, undefined, undefined, ELECTRIC_CHERRY_DOWNED_ATTACK_RADIUS );
		
		for ( i = 0; i < a_zombies.size; i++ )
		{
			if ( IsAlive( self ) && IsAlive( a_zombies[ i ] ) )
			{
				if ( a_zombies[ i ].health <= ELECTRIC_CHERRY_DOWNED_ATTACK_DAMAGE )
				{
					a_zombies[ i ] thread electric_cherry_death_fx();
					
					//for achievement tracking
					if( IsDefined( self.cherry_kills ) )
					{
						self.cherry_kills++;
					}
					
					self zm_score::add_to_player_score( ELECTRIC_CHERRY_DOWNED_ATTACK_POINTS );  //add points only if zombie is killed
				}
				
				else
				{
					a_zombies[ i ] thread electric_cherry_stun();
					a_zombies[ i ] thread electric_cherry_shock_fx();
				}
				
				wait 0.1;
				
				a_zombies[ i ] DoDamage( ELECTRIC_CHERRY_DOWNED_ATTACK_DAMAGE, self.origin, self, self, "none" );
			}
		}
		self notify( "electric_cherry_end" );
	}
}


function electric_cherry_death_fx()  //self = zombie
{
	self endon( "death" );
	
	self PlaySound( "zmb_elec_jib_zombie" );
	
	if ( !IS_TRUE( self.head_gibbed ) )
	{
		if( IsVehicle( self ) )
		{
			self clientfield::set( "tesla_shock_eyes_fx_veh", 1 );
		}
		else
		{
			self clientfield::set( "tesla_shock_eyes_fx", 1 );
		}
	}
	else
	{
		if( IsVehicle( self ) )
		{
			self clientfield::set( "tesla_death_fx_veh", 1 );
		}
		else
		{
			self clientfield::set( "tesla_death_fx", 1 );
		}
	}		
}


function electric_cherry_shock_fx()  //self = zombie
{
	self endon( "death" );
	
	if( IsVehicle( self ) )
	{
		self clientfield::set( "tesla_shock_eyes_fx_veh", 1 );
	}
	else
	{
		self clientfield::set( "tesla_shock_eyes_fx", 1 );
	}
	
	self PlaySound( "zmb_elec_jib_zombie" );
	
	self waittill( "stun_fx_end" );	

	if( IsVehicle( self ) )
	{
		self clientfield::set( "tesla_shock_eyes_fx_veh", 0 );
	}
	else
	{
		self clientfield::set( "tesla_shock_eyes_fx", 0 );
	}
}


function electric_cherry_stun()  //self = zombie
{
	self endon("death");

	self notify( "stun_zombie" );
	self endon( "stun_zombie" );

	if ( self.health <= 0 )
	{
		return;
	}
	
	//only stun the zombie if they are not in the find_flesh state
	if ( self.ai_state !== "zombie_think" )
	{
		return;	
	}
	
	// This immobilizes zombies because they're being shocked by electricity
	self.zombie_tesla_hit = true;		
	self.ignoreall = true;

	wait ELECTRIC_CHERRY_STUN_CYCLES; // wait time for stun to hold.

	if( isdefined( self ) )
	{	
		//set them back on course
		self.zombie_tesla_hit = false;		
		self.ignoreall = false;
		
		self notify( "stun_fx_end" );	
	}
}

//-----------------------------------------------------------------------------------
// Release an explosion when the player reloads
//-----------------------------------------------------------------------------------

function electric_cherry_reload_attack() // self = player
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( PERK_ELECTRIC_CHERRY + "_stop" );

	self.wait_on_reload = [];
	self.consecutive_electric_cherry_attacks = 0;
	
	while( true )
	{
		// Wait for the player to reload
		self waittill("reload_start");
		
		current_weapon = self GetCurrentWeapon();
		
		// Don't use the perk if the weapon is waiting to be reloaded
		if( IsInArray( self.wait_on_reload, current_weapon ) )
		{
			continue;	
		}
		
		// Add this weapon to the list so we know it needs to be reloaded before the perk can be used for again
		self.wait_on_reload[self.wait_on_reload.size] = current_weapon;
		
		self.consecutive_electric_cherry_attacks++;
		
		// Get the percentage of bullets left in the clip at the time the weapon is reloaded
//		n_clip_current = self GetWeaponAmmoClip( str_current_weapon );
//		n_clip_max = WeaponClipSize( str_current_weapon );
		n_clip_current = 1;
		n_clip_max = 10;
		n_fraction = n_clip_current/n_clip_max;
	
		perk_radius = math::linear_map( n_fraction, 1.0, 0.0, RELOAD_ATTACK_MIN_RADIUS, RELOAD_ATTACK_MAX_RADIUS );
		perk_dmg = math::linear_map( n_fraction, 1.0, 0.0, RELOAD_ATTACK_MIN_DAMAGE, RELOAD_ATTACK_MAX_DAMAGE );
		
		// Kick off a thread that will tell us when the weapon has been reloaded.
		self thread check_for_reload_complete( current_weapon );
		
		// Do the Electric Cherry Perk attack.  Logic should be the same as the "Laststand" attack.
		if ( IsDefined( self ) )
		{			
			// If the attack is being spammed, limit the number of zombies the attack can affect
			switch( self.consecutive_electric_cherry_attacks )
			{
			case 0:
			case 1:
				n_zombie_limit = undefined;
				break;
			
			case 2:
				n_zombie_limit = 8;
				break;
			
			case 3:
				n_zombie_limit = 4;
				break;
			
			case 4:
				n_zombie_limit = 2;
				break;
				
			default:
				n_zombie_limit = 0;
			}
			
			// Start the Cooldown Timer
			self thread electric_cherry_cooldown_timer( current_weapon );
			
			if( IsDefined(n_zombie_limit) && (n_zombie_limit == 0) )
			{
				// The player has spammed the attack too much
				// So don't actually perform the attack
				// This prevents us from seeing/hearing the attack when it won't affect any zombies
				continue;
			}
			
			self thread electric_cherry_reload_fx( n_fraction );
			self notify( "electric_cherry_start" );
			self PlaySound( "zmb_cherry_explode" );
			
			a_zombies = zombie_utility::get_round_enemy_array();
			a_zombies = util::get_array_of_closest( self.origin, a_zombies, undefined, undefined, perk_radius );
			
			n_zombies_hit = 0;
			
			for ( i = 0; i < a_zombies.size; i++ )
			{
				if ( IsAlive( self ) && IsAlive( a_zombies[ i ] ) )
				{
					// If the limit of zombies is undefined, keep going and hit all zombies we can
					if( IsDefined( n_zombie_limit ) )
					{
						// If the we're under the limit, increment the count of zombies
						if( n_zombies_hit < n_zombie_limit )
						{
							n_zombies_hit++;							
						}
						else
						{
							// If we're at the limit of zombies, don't kill any more zombies
							break;
						}
					}
					
					if ( a_zombies[ i ].health <= perk_dmg )
					{
						a_zombies[ i ] thread electric_cherry_death_fx();
						
						//for achievement tracking
						if( IsDefined( self.cherry_kills ) )
						{
							self.cherry_kills++;
						}
					
						self zm_score::add_to_player_score( RELOAD_ATTACK_POINTS );  //add points only if zombie is killed
					}
					else
					{
						if( !IsDefined(a_zombies[ i ].is_brutus) )
						{
							a_zombies[ i ] thread electric_cherry_stun();	
						}
						a_zombies[ i ] thread electric_cherry_shock_fx();
					}
					
					wait 0.1;
					
					if( isdefined( a_zombies[ i ] ) && IsAlive( a_zombies[ i ] ) ) // need to check again since we're post-wait
					{
						a_zombies[ i ] DoDamage( perk_dmg, self.origin, self, self, "none" );
					}
				}
			}
			
			self notify( "electric_cherry_end" );	
		}
	}
}

function electric_cherry_cooldown_timer( current_weapon ) // self = player
{
	self notify( "electric_cherry_cooldown_started" );
	self endon( "electric_cherry_cooldown_started" );
	self endon( "death" );
	self endon( "disconnect" );
	
	// Start the timer when the player reloads (when electric cherry attack starts)
	// Cooldown time is equal to the weapon's reload time plus the global cooldown
	//n_reload_time = WeaponReloadTime( current_weapon ); // TODO
	n_reload_time = 0.25;
	if( self HasPerk( "specialty_fastreload" ) )
	{
		n_reload_time *= GetDvarFloat( "perk_weapReloadMultiplier" );
	}
	
	n_cooldown_time = (n_reload_time + RELOAD_ATTACK_COOLDOWN_TIMER);
	
	wait n_cooldown_time;
	
	self.consecutive_electric_cherry_attacks = 0;
}

function check_for_reload_complete( weapon ) // self = player
{
	self endon( "death" );
	self endon( "disconnect" );
	//self endon( "weapon_change_complete" );
	self endon( "player_lost_weapon_" + weapon.name );
	
	// Thread to watch for the case where this weapon gets replaced
	self thread weapon_replaced_monitor( weapon );
	
	while( 1 )
	{
		// Wait for the player to complete a reload
		self waittill( "reload" );
		
		// If the weapon that just got reloaded is the same as the one that was used for the electric cherry perk
		// Kill off this thread and remove this weapon's name from the player's wait_on_reload list
		// This allows the player to use the Electric Cherry Reload Attack with this weapon again!
		current_weapon = self GetCurrentWeapon();
		if( current_weapon == weapon )
		{
			ArrayRemoveValue( self.wait_on_reload, weapon );
			self notify( "weapon_reload_complete_" + weapon.name );
			break;
		}
	}
}

function weapon_replaced_monitor( weapon ) // self = player
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "weapon_reload_complete_" + weapon.name );
	
	while( 1 )
	{
		// Wait for the player to change weapons (swap weapon, wall buy, magic box, etc.)
		self waittill( "weapon_change" );
		
		// If the weapon that we previously used for the Electric Cherry Reload Attack is no longer equipped
		// Kill off this thread and remove this weapon's name from the player's wait_on_reload list
		// This handles the case when a player cancels a reload, then replaces this weapon
		// Ensures that when the player re-aquires the weapon, he has a fresh start and can use the Electric Cherry perk immediately.
		primaryWeapons = self GetWeaponsListPrimaries();
		if( !IsInArray( primaryWeapons, weapon ) )
		{
			self notify( "player_lost_weapon_" + weapon.name );
			ArrayRemoveValue( self.wait_on_reload, weapon );
			break;
		}
	}
}

function electric_cherry_reload_fx( n_fraction )
{
	if( n_fraction >= 0.67 )
	{
		CodeSetClientField( self, "electric_cherry_reload_fx", 1 );	
	}
	else if( (n_fraction >= 0.33) && (n_fraction < 0.67) )
	{
		CodeSetClientField( self, "electric_cherry_reload_fx", 2 );	
	}
	else
	{
		CodeSetClientField( self, "electric_cherry_reload_fx", 3 );	
	}
	
	wait ( 1.0 );
	
	CodeSetClientField( self, "electric_cherry_reload_fx", 0 );
}

//////////////////////////////////////////////////////////////
//Perk lost func
//////////////////////////////////////////////////////////////
function electric_cherry_perk_lost( b_pause, str_perk, str_result )
{
	self notify( PERK_ELECTRIC_CHERRY + "_stop" );
}


