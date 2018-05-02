#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_melee_weapon;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\_zm_powerup_ww_grenade;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;
#insert scripts\zm\_zm_perk_widows_wine.gsh;

#namespace zm_perk_widows_wine;

#precache( "material", WIDOWS_WINE_SHADER );
#precache( "string", "ZOMBIE_PERK_WIDOWS_WINE" );
#precache( "fx", WIDOWS_WINE_FX_FILE_MACHINE_LIGHT );
#precache( "fx", WIDOWS_WINE_FX_FILE_WRAP );
	
REGISTER_SYSTEM( "zm_perk_widows_wine", &__init__, undefined )	
	
//	WIDOWS WINE

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_widows_wine_perk_for_level();
}

function enable_widows_wine_perk_for_level()
{	
	// register widows wine perk for level
	zm_perks::register_perk_basic_info( PERK_WIDOWS_WINE, WIDOWS_WINE_NAME, WIDOWS_WINE_PERK_COST, &"ZOMBIE_PERK_WIDOWSWINE", GetWeapon( WIDOWS_WINE_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_WIDOWS_WINE, &widows_wine_precache );
	zm_perks::register_perk_clientfields( PERK_WIDOWS_WINE, &widows_wine_register_clientfield, &widows_wine_set_clientfield );
	zm_perks::register_perk_machine( PERK_WIDOWS_WINE, &widows_wine_perk_machine_setup );
	zm_perks::register_perk_host_migration_params( PERK_WIDOWS_WINE, WIDOWS_WINE_RADIANT_MACHINE_NAME, WIDOWS_WINE_FX_MACHINE_LIGHT );
	
	zm_perks::register_perk_threads( PERK_WIDOWS_WINE, &widows_wine_perk_activate, &widows_wine_perk_lost );
	
	if( IS_TRUE( level.custom_widows_wine_perk_threads ) )
	{
		level thread [[ level.custom_widows_wine_perk_threads ]]();
	}

	clientfield::register( "toplayer", "widows_wine_1p_contact_explosion", VERSION_SHIP, 1, "counter" );
	
	init_widows_wine();
}

function widows_wine_precache()
{
	if( isdefined(level.widows_wine_precache_override_func) )
	{
		[[ level.widows_wine_precache_override_func ]]();
		return;
	}
	
	level._effect[ WIDOWS_WINE_FX_MACHINE_LIGHT ]	= WIDOWS_WINE_FX_FILE_MACHINE_LIGHT;
	level._effect[ WIDOWS_WINE_FX_WRAP ]			= WIDOWS_WINE_FX_FILE_WRAP;
		
	level.machine_assets[PERK_WIDOWS_WINE] = SpawnStruct();
	level.machine_assets[PERK_WIDOWS_WINE].weapon = GetWeapon( WIDOWS_WINE_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_WIDOWS_WINE].off_model = WIDOWS_WINE_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_WIDOWS_WINE].on_model = WIDOWS_WINE_MACHINE_ACTIVE_MODEL;
}

function widows_wine_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_WIDOWS_WINE, VERSION_SHIP, 2, "int" );

	clientfield::register( "actor", CF_WIDOWS_WINE_WRAP, VERSION_SHIP, 1, "int" );
	
	clientfield::register( "vehicle", CF_WIDOWS_WINE_WRAP, VERSION_SHIP, 1, "int" );
}

function widows_wine_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_WIDOWS_WINE, state );
}

function widows_wine_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound	= "mus_perks_widow_jingle";
	use_trigger.script_string	= "widowswine_perk";
	use_trigger.script_label	= "mus_perks_widow_sting";
	use_trigger.target			= "vending_widowswine";
	perk_machine.script_string	= "widowswine_perk";
	perk_machine.targetname		= "vending_widowswine";
	
	if( isdefined( bump_trigger ) )
	{
		bump_trigger.script_string = "widowswine_perk";
	}
}

//-----------------------------------------------------------------------------------
// functionality
//-----------------------------------------------------------------------------------
function init_widows_wine()
{	
	zm_utility::register_lethal_grenade_for_level( WIDOWS_WINE_GRENADE );
	zm_spawner::register_zombie_damage_callback( &widows_wine_zombie_damage_response );
	zm_spawner::register_zombie_death_event_callback( &widows_wine_zombie_death_watch );
	zm::register_vehicle_damage_callback( &widows_wine_vehicle_damage_response );
	zm_perks::register_perk_damage_override_func( &widows_wine_damage_callback );
	level.w_widows_wine_grenade = GetWeapon( WIDOWS_WINE_GRENADE );

	zm_utility::register_melee_weapon_for_level( WIDOWS_WINE_KNIFE );
	level.w_widows_wine_knife = GetWeapon( WIDOWS_WINE_KNIFE );

	zm_utility::register_melee_weapon_for_level( WIDOWS_WINE_BOWIE_KNIFE );
	level.w_widows_wine_bowie_knife = GetWeapon( WIDOWS_WINE_BOWIE_KNIFE );
	
	zm_utility::register_melee_weapon_for_level( WIDOWS_WINE_SICKLE_KNIFE );
	level.w_widows_wine_sickle_knife = GetWeapon( WIDOWS_WINE_SICKLE_KNIFE );
}

//--------------------------------------------------------------------------
//	Functionality
//--------------------------------------------------------------------------


//	self is a player with widow's wine perk
function widows_wine_perk_activate()
{
	if ( level.w_widows_wine_grenade == self zm_utility::get_player_lethal_grenade() )
	{
		// they must've been given this again while they hadn't finished the lost function that takes all the special weapons away, don't do any of this
		return;
	}

	// replace your grenades with widows_wine grenades
	self.w_widows_wine_prev_grenade = self zm_utility::get_player_lethal_grenade();
	self TakeWeapon( self.w_widows_wine_prev_grenade );

	// Give the widow's wine grenade and wait for them to be thrown
	self GiveWeapon( level.w_widows_wine_grenade );
	self zm_utility::set_player_lethal_grenade( level.w_widows_wine_grenade );

	self.w_widows_wine_prev_knife = self zm_utility::get_player_melee_weapon();
	
	if ( isdefined( self.widows_wine_knife_override ) )
	{
		self [[self.widows_wine_knife_override]]();
	}
	else
	{
		// replace your knife with widows_wine knife
		self TakeWeapon( self.w_widows_wine_prev_knife );
		
		if( self.w_widows_wine_prev_knife.name == "bowie_knife" )
		{
			// Give the widow's wine bowie knife
			self GiveWeapon( level.w_widows_wine_bowie_knife );
			self zm_utility::set_player_melee_weapon( level.w_widows_wine_bowie_knife );
		}
		else if( self.w_widows_wine_prev_knife.name == "sickle_knife" )
		{
			// Give the widow's wine sickle knife
			self GiveWeapon( level.w_widows_wine_sickle_knife );
			self zm_utility::set_player_melee_weapon( level.w_widows_wine_sickle_knife );
		}
		else
		{
			// Give the widow's wine knife
			self GiveWeapon( level.w_widows_wine_knife );
			self zm_utility::set_player_melee_weapon( level.w_widows_wine_knife );
		}
	}

	assert( !IsDefined( self.check_override_wallbuy_purchase ) || self.check_override_wallbuy_purchase == &widows_wine_override_wallbuy_purchase );
	assert( !IsDefined( self.check_override_melee_wallbuy_purchase ) || self.check_override_melee_wallbuy_purchase == &widows_wine_override_melee_wallbuy_purchase );
	self.check_override_wallbuy_purchase = &widows_wine_override_wallbuy_purchase;
	self.check_override_melee_wallbuy_purchase = &widows_wine_override_melee_wallbuy_purchase;
	
	self thread grenade_bounce_monitor();
}

// if zombie hits player, auto-explodes grenade
function widows_wine_contact_explosion()
{
	self MagicGrenadeType( self.current_lethal_grenade, self.origin + ( 0, 0, 48 ), ( 0, 0, 0 ), 0.0 );
	self setWeaponAmmoClip( self.current_lethal_grenade, self getWeaponAmmoClip( self.current_lethal_grenade ) - 1 );
	self clientfield::increment_to_player( "widows_wine_1p_contact_explosion", 1 );
}

#define WW_MELEE_COCOON_CHANCE 0.50

// self is a zombie
function widows_wine_zombie_damage_response( str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	if ( ( isdefined( self.damageweapon ) && self.damageweapon == level.w_widows_wine_grenade ) ||
	     ( IS_EQUAL(str_mod,"MOD_MELEE") && IsDefined(e_player) && IsPlayer(e_player) && e_player HasPerk( PERK_WIDOWS_WINE ) && RandomFloat(1.0) <= WW_MELEE_COCOON_CHANCE ) )
	{
		if(!IS_TRUE(self.no_widows_wine))
		{
			// if we have instakill, apply that
			self thread zm_powerups::check_for_instakill( e_player, str_mod, str_hit_location );
		
			n_dist_sq = DistanceSquared( self.origin, v_hit_origin );
	
			// Nearby zombies are cocooned
			if ( n_dist_sq <= WIDOWS_WINE_COCOON_RADIUS_SQ )
			{
				self thread widows_wine_cocoon_zombie( e_player );
			}
			// Further away is merely slow
			else
			{
				self thread widows_wine_slow_zombie( e_player );
			}
			
			if ( !IS_TRUE( self.no_damage_points ) && IsDefined(e_player) )
			{
				damage_type = "damage";
				e_player zm_score::player_add_points( damage_type, str_mod, str_hit_location, false, undefined, w_weapon );
			}
			
			return true;
		}
	}

	return false;
}

//self is a vehicle
function widows_wine_vehicle_damage_response( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if ( isdefined( weapon ) && weapon == level.w_widows_wine_grenade && !IS_TRUE( self.b_widows_wine_cocoon ) )
	{
		// Only apply stuck grenade monitor to Parasites
		if ( self.archetype === ARCHETYPE_PARASITE )
		{
			self thread vehicle_stuck_grenade_monitor();
		}
		self thread widows_wine_vehicle_behavior( eAttacker, weapon );

		if ( !IS_TRUE( self.no_damage_points ) && IsDefined(eAttacker) )
		{
			damage_type = "damage";
			eAttacker zm_score::player_add_points( damage_type, sMeansOfDeath, sHitLoc, false, undefined, weapon );
		}

		return 0;
	}
	return iDamage;
}

// Contact explosion function - When zombie hits player with Widow's Wine grenades, grenade will auto explode
// self is player
function widows_wine_damage_callback( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if ( sWeapon == level.w_widows_wine_grenade )
	{
		return 0;
	}
	
	// Contact explosion will only work if:
	//		Zombie melee's player
	//		Player carries widow's wine grenades
	// 		Player has more than 2 grenades
	//		Player does not have the Burned Out bubblegum buff
	if (	self.current_lethal_grenade == level.w_widows_wine_grenade
	     && self getWeaponAmmoClip( self.current_lethal_grenade ) > WIDOWS_WINE_CONTACT_EXPLOSION_COUNT
	     && !self bgb::is_enabled( "zm_bgb_burned_out" ) 			)
	{
		if ( ( sMeansOfDeath == "MOD_MELEE" && IsAI(eAttacker) ) || 
		     ( sMeansOfDeath == "MOD_EXPLOSIVE" && IsVehicle( eAttacker ) ) )
		{
			self thread widows_wine_contact_explosion();
			return iDamage;
		}
	}
}

#define WW_POWERUP_DROP_CHANCE_WEBBING 0.15
#define WW_POWERUP_DROP_CHANCE_NORMAL 0.20
#define WW_POWERUP_DROP_CHANCE_MELEE  0.25

function widows_wine_zombie_death_watch( attacker )
{
	if ( ( IS_TRUE( self.b_widows_wine_cocoon ) || IS_TRUE( self.b_widows_wine_slow ) ) && !IS_TRUE( self.b_widows_wine_no_powerup ) )
	{
		if ( IsDefined(self.attacker) && IsPlayer(self.attacker) && self.attacker HasPerk( PERK_WIDOWS_WINE ) )
		{
			chance = WW_POWERUP_DROP_CHANCE_NORMAL;			
			if ( isdefined( self.damageweapon ) && self.damageweapon == level.w_widows_wine_grenade )
			{
				chance = WW_POWERUP_DROP_CHANCE_WEBBING;
			}
			else if ( isdefined( self.damageweapon ) && ( self.damageweapon == level.w_widows_wine_knife || self.damageweapon == level.w_widows_wine_bowie_knife  || self.damageweapon == level.w_widows_wine_sickle_knife ) )
			{
				chance = WW_POWERUP_DROP_CHANCE_MELEE;
			}
			if ( RandomFloat( 1.0 ) <= chance )
			{
				self.no_powerups = true;
				level._powerup_timeout_override = &powerup_widows_wine_timeout;
				level thread zm_powerups::specific_powerup_drop( "ww_grenade", self.origin, undefined, undefined, undefined, self.attacker );
				level._powerup_timeout_override = undefined;
			}
		}
	}
}


function powerup_widows_wine_timeout()
{
	self endon( "powerup_grabbed" );
	self endon( "death" );
	self endon("powerup_reset");
	
	self zm_powerups::powerup_show( true );
	
	wait_time = 1;
	if (isDefined( level._powerup_timeout_custom_time ) )
	{
		time = [[level._powerup_timeout_custom_time]](self);
		if ( time == 0 )
		{
			return;
		}
		wait_time = time;
		
	}
	
	wait wait_time;

	for ( i = 20; i > 0; i-- )
	{
		// hide and show
		if ( i % 2 )
		{
			self zm_powerups::powerup_show( false );
		}
		else
		{
			self zm_powerups::powerup_show( true );
		}

		if( i > 15 )
		{
			wait( 0.3 );
		}
		if ( i > 10 )
		{
			wait( 0.25 );
		}
		else if ( i > 5 )
		{
			wait( 0.15 );
		}
		else
		{
			wait( 0.1 );			
		}
	}
	
	self notify( "powerup_timedout" );
	self zm_powerups::powerup_delete();
}


#define WIDOWS_WINE_COCOON_MAX_SCORE 10
#define WIDOWS_WINE_SLOW_MAX_SCORE 6
	
function widows_wine_cocoon_zombie_score( e_player, duration, max_score )
{
	self notify( "widows_wine_cocoon_zombie_score" );
	self endon( "widows_wine_cocoon_zombie_score" );
	self endon( "death" );
	
	DEFAULT(self.ww_points_given,0); 
	start_time = GetTime();
	end_time = start_time + (duration * 1000);
	while( GetTime() < end_time && self.ww_points_given < max_score )
	{
		e_player zm_score::add_to_player_score( 10 ); //player_add_points( "ww_webbed", "MOD_UNKNOWN", "none" ,false, level.zombie_team, damage_weapon );
		wait duration / max_score;		
	}
	
}

//	zombie is immobilized by web
// self is a zombie
function widows_wine_cocoon_zombie( e_player )
{
	// Multiple calls from subsequent grenades should extend the effect
	self notify( "widows_wine_cocoon" );
	
	self endon( "widows_wine_cocoon" );
	
	if ( IS_TRUE( self.kill_on_wine_coccon ) )
	{
		self Kill();
	}
	
	if ( !IS_TRUE( self.b_widows_wine_cocoon ) )
	{
		self.b_widows_wine_cocoon = true;
		self.e_widows_wine_player = e_player;
		
		if( isdefined(self.widows_wine_cocoon_fraction_rate) )
		{
			widows_wine_cocoon_fraction_rate = self.widows_wine_cocoon_fraction_rate;
		}
		else
		{
			widows_wine_cocoon_fraction_rate = WIDOWS_WINE_COCOON_FRACTION;
		}
		
		self ASMSetAnimationRate( widows_wine_cocoon_fraction_rate );

		self clientfield::set( CF_WIDOWS_WINE_WRAP, 1 );	// turn on wrap FX
	}
	
	if ( IsDefined(e_player) )
	{
		self thread widows_wine_cocoon_zombie_score( e_player, WIDOWS_WINE_COCOON_DURATION, WIDOWS_WINE_COCOON_MAX_SCORE );
	}
	
	self util::waittill_any_timeout( WIDOWS_WINE_COCOON_DURATION, "death", "widows_wine_cocoon" );

	if (!IsDefined(self))
		return; 
	
	self ASMSetAnimationRate( 1.0 );
	self clientfield::set( CF_WIDOWS_WINE_WRAP, 0 );	// turn off wrap FX
	
	if ( IsAlive( self ) )
	{
		self.b_widows_wine_cocoon = false;
	}
}


//	zombie is slowed by webbing
// self is a zombie
function widows_wine_slow_zombie( e_player )
{
	// Multiple calls from subsequent grenades should extend the effect
	self notify( "widows_wine_slow" );
	
	self endon( "widows_wine_slow" );
	
	if ( IS_TRUE( self.b_widows_wine_cocoon ) )
	{
		// Should just increase cocoon time
		self thread widows_wine_cocoon_zombie( e_player );
		return;
	}

	if ( IsDefined(e_player) )
	{
		self thread widows_wine_cocoon_zombie_score( e_player, WIDOWS_WINE_SLOW_DURATION, WIDOWS_WINE_SLOW_MAX_SCORE );
	}
	
	if ( !IS_TRUE( self.b_widows_wine_slow ) )
	{
		if( isdefined(self.widows_wine_slow_fraction_rate) )
		{
			widows_wine_slow_fraction_rate = self.widows_wine_slow_fraction_rate;
		}
		else
		{
			widows_wine_slow_fraction_rate = WIDOWS_WINE_SLOW_FRACTION;
		}
		
		self.b_widows_wine_slow = true;
		self ASMSetAnimationRate( widows_wine_slow_fraction_rate );
		self clientfield::set( CF_WIDOWS_WINE_WRAP, 1 );	// turn on wrap FX
	}
	self util::waittill_any_timeout( WIDOWS_WINE_SLOW_DURATION, "death", "widows_wine_slow" );

	if (!IsDefined(self))
		return; 
	
	self ASMSetAnimationRate( 1.0 );
	self clientfield::set( CF_WIDOWS_WINE_WRAP, 0 );	// turn off wrap FX
	
	if ( IsAlive( self ) )
	{
		self.b_widows_wine_slow = false;
	}
}

// If the grenade strikes a Parasite, explode immediately
function vehicle_stuck_grenade_monitor()
{
	self endon( "death" );
	
	self waittill( "grenade_stuck", e_grenade );
	
	e_grenade Detonate(); 
}

// Monitors thrown grenades for Elementals
function grenade_bounce_monitor()
{
	self endon( "disconnect" );
	self endon( "stop_widows_wine" );
	
	while ( true )
	{
		self waittill( "grenade_fire", e_grenade );
		e_grenade thread grenade_bounces();
	}
}
	
// If grenade bounces off an Elemental, explode immediately
function grenade_bounces()
{
	self endon( "explode" );
	
	self waittill( "grenade_bounce", pos, normal, e_target );
	
	if ( IsDefined(e_target) )
	{
		if ( e_target.archetype === ARCHETYPE_PARASITE || e_target.archetype === ARCHETYPE_RAPS )
		{
			self Detonate(); 
		}
	}
}

//self is a vehicle
function widows_wine_vehicle_behavior( attacker, weapon )
{
	self endon( "death" );
	
	self.b_widows_wine_cocoon = true;
	
	if( IsDefined( self.archetype ) )
	{
		//If an Elemental, slows them down, applies FX, then kills them after a duration
		if( self.archetype == ARCHETYPE_RAPS )
		{
			self clientfield::set( CF_WIDOWS_WINE_WRAP, 1 );	// turn on wrap FX
			self._override_raps_combat_speed = WIDOWS_WINE_ELEMENTAL_SPEED_OVERRIDE;
			
			wait( 0.5 * WIDOWS_WINE_SLOW_DURATION );
	
			self DoDamage( self.health + 1000, self.origin, attacker, undefined, "none", "MOD_EXPLOSIVE", 0, weapon );		
		}
		// If a Parasite, automatically kills them
		else if( self.archetype == ARCHETYPE_PARASITE )
		{
			wait SERVER_FRAME; // Wait so that damage does not apply to Parasite stuck by grenade
			self DoDamage( self.maxhealth, self.origin );
		}
	}
}

//////////////////////////////////////////////////////////////
//Perk lost func
//////////////////////////////////////////////////////////////

// self is a player
function widows_wine_perk_lost( b_pause, str_perk, str_result )
{
	self notify( "stop_widows_wine" );
	self endon( "death" );
	
	if ( self laststand::player_is_in_laststand() )
	{
		self waittill( "player_revived" );

		if ( self HasPerk( PERK_WIDOWS_WINE ) )
		{
			// they must've gotten it back between when this function ran and when they got revived, we shouldn't do any of this anymore
			return;
		}
	}

	self.check_override_wallbuy_purchase = undefined;
	
	self TakeWeapon( level.w_widows_wine_grenade );
	if ( isdefined( self.w_widows_wine_prev_grenade ) )
	{
		// Redefines last stand grenade from zm::last_stand_grenade_save_and_return()
		self.lsgsar_lethal = self.w_widows_wine_prev_grenade;
		self GiveWeapon( self.w_widows_wine_prev_grenade );
		self zm_utility::set_player_lethal_grenade( self.w_widows_wine_prev_grenade );
	}
	else
	{
		self zm_utility::init_player_lethal_grenade(); 	
	}
	grenade = self zm_utility::get_player_lethal_grenade(); 
	self GiveStartAmmo( grenade );

	// widows wine knife can be bypassed by better melee weapon, ie. one inch punch
	if( isdefined( self.current_melee_weapon ) && !IsSubStr( self.current_melee_weapon.name, "widows_wine" ) )
	{
		self.w_widows_wine_prev_knife = self.current_melee_weapon;
	}
	else if( self.w_widows_wine_prev_knife.name == "bowie_knife" )
	{
		self TakeWeapon( level.w_widows_wine_bowie_knife );
	}
	else if( self.w_widows_wine_prev_knife.name == "sickle_knife" )
	{
		self TakeWeapon( level.w_widows_wine_sickle_knife );
	}
	else
	{
		self TakeWeapon( level.w_widows_wine_knife );
	}

	if ( isdefined( self.w_widows_wine_prev_knife ) )
	{
		self GiveWeapon( self.w_widows_wine_prev_knife );
		self zm_utility::set_player_melee_weapon( self.w_widows_wine_prev_knife );
	}
	else
	{
		self zm_utility::init_player_melee_weapon(); 	
	}
}

function widows_wine_override_wallbuy_purchase( weapon, wallbuy ) 
{
	// Can not buy ammo for Widows Wine from wall.
	if ( zm_utility::is_lethal_grenade( weapon ) )
	{
		wallbuy zm_utility::play_sound_on_ent( "no_purchase" );
		if ( isdefined( level.custom_generic_deny_vo_func ) )
		{
			self [[level.custom_generic_deny_vo_func]]();
		}
		else
		{
			self zm_audio::create_and_play_dialog( "general", "sigh" );
		}

		return true; 
	}
	
	return false; 
}

function widows_wine_override_melee_wallbuy_purchase( vo_dialog_id, flourish_weapon, weapon, ballistic_weapon, ballistic_upgraded_weapon, flourish_fn, wallbuy ) 
{	
	if ( zm_utility::is_melee_weapon( weapon ) )
	{
		if ( self.w_widows_wine_prev_knife != weapon )
		{
			cost = wallbuy.stub.cost;
			
			if ( self zm_score::can_player_purchase( cost ) )
			{
				if ( wallbuy.first_time_triggered == false )
				{
					model = getent( wallbuy.target, "targetname" ); 
					
					if ( isdefined( model ) )
					{
						model thread zm_melee_weapon::melee_weapon_show( self );
					}
					else if ( isdefined( wallbuy.clientFieldName ) )
					{
						level clientfield::set( wallbuy.clientFieldName, 1 );
					}
					
					wallbuy.first_time_triggered = true; 
					if ( isdefined( wallbuy.stub ) )
					{
						wallbuy.stub.first_time_triggered = true;
					}

				}

				self zm_score::minus_to_player_score( cost ); 
				

				assert( weapon.name == "bowie_knife" || weapon.name == "sickle_knife" ); 
				self.w_widows_wine_prev_knife = weapon;
				if( self.w_widows_wine_prev_knife.name == "bowie_knife" )
				{
					self thread zm_melee_weapon::give_melee_weapon( vo_dialog_id, flourish_weapon, weapon, ballistic_weapon, ballistic_upgraded_weapon, flourish_fn, wallbuy );
				}
				else if( self.w_widows_wine_prev_knife.name == "sickle_knife" )
				{
					self thread zm_melee_weapon::give_melee_weapon( vo_dialog_id, flourish_weapon, weapon, ballistic_weapon, ballistic_upgraded_weapon, flourish_fn, wallbuy );
				}
			}
			else
			{
				zm_utility::play_sound_on_ent( "no_purchase" );
				self zm_audio::create_and_play_dialog( "general", "outofmoney", 1 );
			}
		}
		return true; 
	}
	return false; 
}
