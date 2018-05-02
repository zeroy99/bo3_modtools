#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_perk_additionalprimaryweapon.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", "specialty_extraprimaryweapon_zombies" );
#precache( "string", "ZOMBIE_PERK_ADDITIONALPRIMARYWEAPON" );
#precache( "fx", ADDITIONAL_PRIMARY_WEAPON_MACHINE_FX_FILE_MACHINE_LIGHT );


#namespace zm_perk_additionalprimaryweapon;

REGISTER_SYSTEM( "zm_perk_additionalprimaryweapon", &__init__, undefined )

// ADDITIONAL PRIMARY WEAPON ( MULE KICK )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	level.additionalprimaryweapon_limit = 3;

	enable_additional_primary_weapon_perk_for_level();
	
	callback::on_laststand( &on_laststand );
	level.return_additionalprimaryweapon = &return_additionalprimaryweapon;
}

function enable_additional_primary_weapon_perk_for_level()
{	
	// register sleight of hand perk for level
	zm_perks::register_perk_basic_info( PERK_ADDITIONAL_PRIMARY_WEAPON, "additionalprimaryweapon", ADDITIONAL_PRIMARY_WEAPON_PERK_COST, &"ZOMBIE_PERK_ADDITIONALPRIMARYWEAPON", GetWeapon( ADDITIONAL_PRIMARY_WEAPON_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_ADDITIONAL_PRIMARY_WEAPON, &additional_primary_weapon_precache );
	zm_perks::register_perk_clientfields( PERK_ADDITIONAL_PRIMARY_WEAPON, &additional_primary_weapon_register_clientfield, &additional_primary_weapon_set_clientfield );
	zm_perks::register_perk_machine( PERK_ADDITIONAL_PRIMARY_WEAPON, &additional_primary_weapon_perk_machine_setup );
	zm_perks::register_perk_threads( PERK_ADDITIONAL_PRIMARY_WEAPON, &give_additional_primary_weapon_perk, &take_additional_primary_weapon_perk );
	zm_perks::register_perk_host_migration_params( PERK_ADDITIONAL_PRIMARY_WEAPON, ADDITIONAL_PRIMARY_WEAPON_RADIANT_MACHINE_NAME, ADDITIONAL_PRIMARY_WEAPON_MACHINE_LIGHT_FX );
}

function additional_primary_weapon_precache()
{
	if( IsDefined(level.additional_primary_weapon_precache_override_func) )
	{
		[[ level.additional_primary_weapon_precache_override_func ]]();
		return;
	}
	
	level._effect[ADDITIONAL_PRIMARY_WEAPON_MACHINE_LIGHT_FX] = ADDITIONAL_PRIMARY_WEAPON_MACHINE_FX_FILE_MACHINE_LIGHT;
	
	level.machine_assets[PERK_ADDITIONAL_PRIMARY_WEAPON] = SpawnStruct();
	level.machine_assets[PERK_ADDITIONAL_PRIMARY_WEAPON].weapon = GetWeapon( ADDITIONAL_PRIMARY_WEAPON_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_ADDITIONAL_PRIMARY_WEAPON].off_model = ADDITIONAL_PRIMARY_WEAPON_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_ADDITIONAL_PRIMARY_WEAPON].on_model = ADDITIONAL_PRIMARY_WEAPON_MACHINE_ACTIVE_MODEL;
}

function additional_primary_weapon_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_ADDITIONAL_PRIMARY_WEAPON, VERSION_SHIP, 2, "int" );
}

function additional_primary_weapon_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_ADDITIONAL_PRIMARY_WEAPON, state );
}

function additional_primary_weapon_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_mulekick_jingle";
	use_trigger.script_string = "tap_perk";
	use_trigger.script_label = "mus_perks_mulekick_sting";
	use_trigger.target = ADDITIONAL_PRIMARY_WEAPON_RADIANT_MACHINE_NAME;
	perk_machine.script_string = "tap_perk";
	perk_machine.targetname = ADDITIONAL_PRIMARY_WEAPON_RADIANT_MACHINE_NAME;
	if(IsDefined(bump_trigger))
	{
		bump_trigger.script_string = "tap_perk";
	}
}

function give_additional_primary_weapon_perk()
{
}

function take_additional_primary_weapon_perk( b_pause, str_perk, str_result )
{
	if ( b_pause || str_result == str_perk )
	{
		self take_additionalprimaryweapon();
	}
}

function take_additionalprimaryweapon()
{
	weapon_to_take = level.weaponNone;

	if ( IS_TRUE( self._retain_perks ) || ( IsDefined( self._retain_perks_array ) && IS_TRUE( self._retain_perks_array[ PERK_ADDITIONAL_PRIMARY_WEAPON ] ) ) )
	{
		return weapon_to_take;
	}

	primary_weapons_that_can_be_taken = [];

	primaryWeapons = self GetWeaponsListPrimaries();
	for ( i = 0; i < primaryWeapons.size; i++ )
	{
		if ( zm_weapons::is_weapon_included( primaryWeapons[i] ) || zm_weapons::is_weapon_upgraded( primaryWeapons[i] ) )
		{
			primary_weapons_that_can_be_taken[primary_weapons_that_can_be_taken.size] = primaryWeapons[i];
		}
	}

	self.weapons_taken_by_losing_specialty_additionalprimaryweapon = [];
	pwtcbt = primary_weapons_that_can_be_taken.size;
	while ( pwtcbt >= 3 )
	{
		weapon_to_take = primary_weapons_that_can_be_taken[pwtcbt - 1];
		self.weapons_taken_by_losing_specialty_additionalprimaryweapon[weapon_to_take] = zm_weapons::get_player_weapondata( self, weapon_to_take );
		pwtcbt--;
		if ( weapon_to_take == self GetCurrentWeapon() )
		{
			self SwitchToWeapon( primary_weapons_that_can_be_taken[0] );
		}
		self TakeWeapon( weapon_to_take );
	}

	return weapon_to_take;
}

function on_laststand()
{
 	if ( self HasPerk( PERK_ADDITIONAL_PRIMARY_WEAPON ) )
 	{
		self.weapon_taken_by_losing_specialty_additionalprimaryweapon = take_additionalprimaryweapon();
 	}	
}

function return_additionalprimaryweapon( w_returning )
{
	if ( isdefined( self.weapons_taken_by_losing_specialty_additionalprimaryweapon[w_returning] ) )
	{
		self zm_weapons::weapondata_give( self.weapons_taken_by_losing_specialty_additionalprimaryweapon[w_returning] );
	}
	else
	{
		self zm_weapons::give_build_kit_weapon( w_returning );
	}
}

