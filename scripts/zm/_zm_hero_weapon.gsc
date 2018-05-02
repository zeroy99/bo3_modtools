#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_utility.gsh;

#namespace zm_hero_weapon;

//
// General hero weapon support
//

#define HERO_STATE_HIDDEN				0
#define HERO_STATE_CHARGING				1
#define HERO_STATE_READY				2
#define HERO_STATE_INUSE				3
#define HERO_STATE_UNAVAILABLE			4

// Some of these values may need to be specified on a per-weapon basis at some point, but for now we're just using the values from the sword 	
	
#define HERO_MINPOWER				0
#define HERO_MAXPOWER				100

#define HERO_CLIENTFIELD_POWER			"zmhud.swordEnergy"
#define HERO_CLIENTFIELD_POWER_FLASH	"zmhud.swordChargeUpdate"
#define HERO_CLIENTFIELD_STATE			"zmhud.swordState"

#precache( "string", "ZOMBIE_HERO_WEAPON_HINT" );
	
REGISTER_SYSTEM( "zm_hero_weapons", &__init__, undefined )

function __init__()
{
	DEFAULT( level._hero_weapons, [] );

	callback::on_spawned( &on_player_spawned );

	// NOTE: should only be defined here all individual weapons should register using register_hero_recharge_event()
	level.hero_power_update = &hero_power_event_callback;

	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_HERO_WEAPON, &gadget_hero_weapon_on_activate, &gadget_hero_weapon_on_off );
}

function gadget_hero_weapon_on_activate( slot, weapon )
{
}

function gadget_hero_weapon_on_off( slot, weapon )
{
	self thread watch_for_glitches( slot, weapon );
}

function watch_for_glitches( slot, weapon )
{
	wait 1;
	if ( isdefined(self) )
	{
		w_current = self GetCurrentWeapon(); 
		
		if ( IsDefined(w_current) && zm_utility::is_hero_weapon( w_current ) )
		{
			self.hero_power = self GadgetPowerGet( 0 );		
			if ( self.hero_power <= 0 )
			{
				zm_weapons::switch_back_primary_weapon( undefined, true ); 
				self.i_tried_to_glitch_the_hero_weapon = 1; 
				//self playlocalsound( level.zmb_laugh_alias );
			}
		}
	}
}



function register_hero_weapon( weapon_name )
{
	weaponNone = GetWeapon( "none" ); 

	weapon = GetWeapon( weapon_name );
	
	if ( weapon != weaponNone )
	{
		hero_weapon = SpawnStruct();
		hero_weapon.weapon             = weapon;
		hero_weapon.give_fn            = &default_give;
		hero_weapon.take_fn            = &default_take;
		hero_weapon.wield_fn           = &default_wield;
		hero_weapon.unwield_fn         = &default_unwield;
		hero_weapon.power_full_fn      = &default_power_full;
		hero_weapon.power_empty_fn     = &default_power_empty;
	
		DEFAULT( level._hero_weapons, [] );
		level._hero_weapons[weapon] = hero_weapon;
		zm_utility::register_hero_weapon_for_level( weapon_name );
	}
}

function register_hero_weapon_give_take_callbacks( weapon_name, give_fn = &default_give, take_fn = &default_take )
{
	weaponNone = GetWeapon( "none" ); 
	weapon = GetWeapon( weapon_name );
	if ( weapon != weaponNone && IsDefined(level._hero_weapons[weapon]) )
	{
		level._hero_weapons[weapon].give_fn            = give_fn;
		level._hero_weapons[weapon].take_fn            = take_fn;
	}
}

function default_give( weapon )
{
	power = self GadgetPowerGet( 0 );	
	if( power < HERO_MAXPOWER )
	{
		self set_hero_weapon_state( weapon, HERO_STATE_CHARGING );
	}
	else
	{
		self set_hero_weapon_state( weapon, HERO_STATE_READY );
	}
}

function default_take( weapon )
{
	self set_hero_weapon_state( weapon, HERO_STATE_HIDDEN );
}

function register_hero_weapon_wield_unwield_callbacks( weapon_name, wield_fn = &default_wield, unwield_fn = &default_unwield )
{
	weaponNone = GetWeapon( "none" ); 
	weapon = GetWeapon( weapon_name );
	if ( weapon != weaponNone && IsDefined(level._hero_weapons[weapon]) )
	{
		level._hero_weapons[weapon].wield_fn            = wield_fn;
		level._hero_weapons[weapon].unwield_fn          = unwield_fn;
	}
}

function default_wield( weapon )
{
	self set_hero_weapon_state( weapon, HERO_STATE_INUSE );
}

function default_unwield( weapon )
{
	self set_hero_weapon_state( weapon, HERO_STATE_CHARGING );
}

function register_hero_weapon_power_callbacks( weapon_name, power_full_fn = &default_power_full, power_empty_fn = &default_power_empty )
{
	weaponNone = GetWeapon( "none" ); 
	weapon = GetWeapon( weapon_name );
	if ( weapon != weaponNone && IsDefined(level._hero_weapons[weapon]) )
	{
		level._hero_weapons[weapon].power_full_fn       = power_full_fn;
		level._hero_weapons[weapon].power_empty_fn      = power_empty_fn;
	}
}

function default_power_full( weapon )
{
	self set_hero_weapon_state( weapon, HERO_STATE_READY );
	self thread zm_equipment::show_hint_text( &"ZOMBIE_HERO_WEAPON_HINT", 2 );
}

function default_power_empty( weapon )
{
	self set_hero_weapon_state( weapon, HERO_STATE_CHARGING );
}

function set_hero_weapon_state( w_weapon, state )
{
	self.hero_weapon_state = state; 
	self clientfield::set_player_uimodel( HERO_CLIENTFIELD_STATE, state );
}

function on_player_spawned()
{
	self set_hero_weapon_state( undefined, HERO_STATE_HIDDEN );
	self thread watch_hero_weapon_give();
	self thread watch_hero_weapon_take();
	self thread watch_hero_weapon_change();
}

function watch_hero_weapon_give()
{
	self notify("watch_hero_weapon_give");
	self endon("watch_hero_weapon_give");
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_give", w_weapon );	
		if ( IsDefined(w_weapon) && zm_utility::is_hero_weapon( w_weapon ) )
		{
			self thread watch_hero_power( w_weapon ); 
			self [[level._hero_weapons[w_weapon].give_fn]]( w_weapon ); 
		}
	}
}

function watch_hero_weapon_take()
{
	self notify("watch_hero_weapon_take");
	self endon("watch_hero_weapon_take");
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_take", w_weapon );
		if ( IsDefined( w_weapon ) && zm_utility::is_hero_weapon( w_weapon ) )
		{
			self [[level._hero_weapons[w_weapon].take_fn]]( w_weapon ); 
			self notify("stop_watch_hero_power");
		}
	}
}

function watch_hero_weapon_change()
{
	self notify("watch_hero_weapon_change");
	self endon("watch_hero_weapon_change");
	self endon( "disconnect" );

	while ( true )
	{
		self waittill( "weapon_change", w_current, w_previous );	
		if ( self.sessionstate != "spectator" )
		{
			if ( IsDefined(w_previous) && zm_utility::is_hero_weapon( w_previous ) )
			{
				self [[level._hero_weapons[w_previous].unwield_fn]]( w_previous ); 
				
				if( self GadgetPowerGet( 0 ) == 100 ) //player didn't use any of the gadget power
				{
					if( self HasWeapon( w_previous ) )
					{
						self SetWeaponAmmoClip( w_previous, w_previous.clipSize );	
						self [[level._hero_weapons[w_previous].power_full_fn]]( w_previous );
					}
				}
			}
			if ( IsDefined(w_current) && zm_utility::is_hero_weapon( w_current ) )
			{
				self [[level._hero_weapons[w_current].wield_fn]]( w_current ); 
			}
		}
	}
}

// self == player
function watch_hero_power( w_weapon )
{
	self notify("watch_hero_power");
	self endon("watch_hero_power");
	self endon("stop_watch_hero_power");
	self endon( "disconnect" );

	DEFAULT( self.hero_power_prev, -1 ); 
	
	while ( true )
	{
		self.hero_power = self GadgetPowerGet( 0 );		
		self clientfield::set_player_uimodel( HERO_CLIENTFIELD_POWER, self.hero_power / 100 );
		if ( self.hero_power != self.hero_power_prev )
		{
			self.hero_power_prev = self.hero_power;
			if(self.hero_power >= HERO_MAXPOWER )
			{
				self [[level._hero_weapons[w_weapon].power_full_fn]]( w_weapon ); 
			}
			else if(self.hero_power <= HERO_MINPOWER )
			{
				self [[level._hero_weapons[w_weapon].power_empty_fn]]( w_weapon ); 
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}

// self == player
function continue_draining_hero_weapon( w_weapon )
{
	self endon( "stop_draining_hero_weapon" );
	
	self set_hero_weapon_state( w_weapon, HERO_STATE_INUSE );
	while ( isdefined( self )  )
	{
		n_rate = 1.0;
		
		if ( isdefined(w_weapon.gadget_power_usage_rate) )
			n_rate = w_weapon.gadget_power_usage_rate; 
		
		self.hero_power -= SERVER_FRAME * n_rate; 
		self.hero_power = math::clamp( self.hero_power, HERO_MINPOWER, HERO_MAXPOWER );	
		if ( self.hero_power != self.hero_power_prev )
		{
			self GadgetPowerSet( 0, self.hero_power );
		}
		
		WAIT_SERVER_FRAME;
	}
}

// ------------------------------------------------------------------------------------------------------------
//	Register hero weapon recharge function
// ------------------------------------------------------------------------------------------------------------
function register_hero_recharge_event( w_hero, func )
{
	if ( !isdefined( level.a_func_hero_power_update ) )
	{
		level.a_func_hero_power_update = [];
	}
	
	if ( !isdefined( level.a_func_hero_power_update[ w_hero ] ) )
	{
		level.a_func_hero_power_update[ w_hero ] = func;
	}
}

// level.hero_power_update callback function
function hero_power_event_callback( e_player, ai_enemy )
{
	w_hero = e_player.current_hero_weapon;
	
	if( isdefined( level.a_func_hero_power_update ) && isdefined( level.a_func_hero_power_update[ w_hero ] ) )
	{
		level [[ level.a_func_hero_power_update[ w_hero ] ]]( e_player, ai_enemy );
	}
	else
	{
		level hero_power_event(e_player, ai_enemy);
	}
}

function hero_power_event( player, ai_enemy )
{
	if( isdefined( player ) && player zm_utility::has_player_hero_weapon() && !IS_EQUAL( player.hero_weapon_state, HERO_STATE_INUSE ) && !IS_TRUE( player.disable_hero_power_charging ) )
	{
		player player_hero_power_event( ai_enemy );
	}
}

function player_hero_power_event( ai_enemy )
{
	if( isdefined( self ) ) //( !IS_TRUE( player.usingsword ) && !IS_TRUE( player.autokill_glaive_active) ) && isdefined( player.current_sword ) )
	{
		w_current = self zm_utility::get_player_hero_weapon();
		if( isdefined( ai_enemy.heroweapon_kill_power ) )
		{
			perkFactor = 1.0;
			if ( self hasperk( "specialty_overcharge" ) )
			{
				perkFactor = GetDvarFloat( "gadgetPowerOverchargePerkScoreFactor" ); 
			}
			if ( IS_TRUE( self.i_tried_to_glitch_the_hero_weapon ) )
			{
				//perkFactor *= 0.75;
			}
			
			self.hero_power = self.hero_power + perkFactor * ( ai_enemy.heroweapon_kill_power );
			self.hero_power = math::clamp( self.hero_power, HERO_MINPOWER, HERO_MAXPOWER );	
			if ( self.hero_power != self.hero_power_prev )
			{
				self GadgetPowerSet( 0, self.hero_power );
				self clientfield::set_player_uimodel( HERO_CLIENTFIELD_POWER, self.hero_power / 100 );
				self clientfield::increment_uimodel( HERO_CLIENTFIELD_POWER_FLASH );
			}
		}
	}
}

function take_hero_weapon()
{
	if( isdefined( self.current_hero_weapon ) )
	{
		self notify( "weapon_take", self.current_hero_weapon );
		self GadgetPowerSet( 0, 0 );
	}
}

function is_hero_weapon_in_use()
{
	return IS_EQUAL( self.hero_weapon_state, HERO_STATE_INUSE );
}

