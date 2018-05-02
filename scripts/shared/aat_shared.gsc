// AAT stands for Alternative Ammunition Types

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;

#insert scripts\shared\aat_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace aat;
	
REGISTER_SYSTEM_EX( "aat", &__init__, &__main__, undefined )	

function private __init__()
{	
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	level.aat_initializing = true;
	
	level.aat = [];
	
	// Add "none" for HUD elements
	level.aat[ AAT_RESERVED_NAME ] = SpawnStruct();
	level.aat[ AAT_RESERVED_NAME ].name = AAT_RESERVED_NAME;
	
	level.aat_reroll = [];

	callback::on_connect( &on_player_connect );

	spawners = GetSpawnerArray();
	foreach ( spawner in spawners )
	{	
		spawner spawner::add_spawn_function( &aat_cooldown_init );
	}
	
	level.aat_exemptions = [];
	
	zm::register_vehicle_damage_callback( &aat_vehicle_damage_monitor );
	
	callback::on_finalize_initialization( &finalize_clientfields );
}

function __main__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	zm::register_zombie_damage_override_callback( &aat_response );
}

function private on_player_connect()
{
	self.aat = [];

	self.aat_cooldown_start = [];

	keys = GetArrayKeys( level.aat );
	foreach ( key in keys )
	{
		self.aat_cooldown_start[key] = 0;
	}
	
	self thread watch_weapon_changes();
}


// self = ai or vehicle actor
function aat_cooldown_init()
{
	self.aat_cooldown_start = [];

	keys = GetArrayKeys( level.aat );
	foreach ( key in keys )
	{
		self.aat_cooldown_start[key] = 0;
	}
}

// Returns damage for vehicle_damage_override function
// self = vehicle actor
function private aat_vehicle_damage_monitor( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	willBeKilled = ( self.health - iDamage ) <= 0;

	if ( IS_TRUE( level.aat_in_use ) )
	{
		self thread aat_response( willBeKilled, eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, vSurfaceNormal );
	}
	
	return iDamage;
}

function get_nonalternate_weapon( weapon )
{
	if ( IsDefined( weapon ) && weapon.isAltMode )
	{
		return weapon.altWeapon;
	}

	return weapon; 
}

// Called from _zm.gsc
// self = ai actor
function aat_response( death, inflictor, attacker, damage, flags, mod, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{	
	if ( !IsPlayer( attacker ) )
	{
		return;
	}

	if ( mod != "MOD_PISTOL_BULLET" && mod != "MOD_RIFLE_BULLET" && mod != "MOD_GRENADE" && mod != "MOD_PROJECTILE" && mod != "MOD_EXPLOSIVE" && mod != "MOD_IMPACT" )
	{
		return;
	}
	
	weapon = get_nonalternate_weapon( weapon );
	
	name = attacker.aat[weapon];
	if ( !IsDefined( name ) )
	{
		return;
	}
	
	if ( death && !level.aat[name].occurs_on_death )
	{
		return;
	}
	
	if ( !isdefined( self.archetype ) )
	{
		return;
	}
	
	// if self's archetype is registered in immune_trigger, AAT check is completely bypassed
	if ( IS_TRUE( level.aat[name].immune_trigger[ self.archetype ] ) )
	{
		return;
	}

	now = GetTime() / 1000;
	if ( now <= self.aat_cooldown_start[name] + level.aat[name].cooldown_time_entity )
	{
		return;
	}

	if ( now <= attacker.aat_cooldown_start[name] + level.aat[name].cooldown_time_attacker )
	{
		return;
	}
	
	if ( now <= level.aat[name].cooldown_time_global_start + level.aat[name].cooldown_time_global )
	{
		return;
	}

	if ( isdefined( level.aat[name].validation_func ) )
	{
		if ( !self [[level.aat[name].validation_func]]() )
		{
			return;
		}
	}
	
	success = false;
	reroll_icon = undefined;
	percentage = level.aat[name].percentage;
	

	if ( percentage >= RandomFloat( 1 ) )
	{
		success = true;
	}

	if ( !success )
	{
		keys = GetArrayKeys( level.aat_reroll );
		keys = array::randomize( keys );// randomize the keys so players don't assume one reroll is better than another just because of registration order
		foreach ( key in keys )
		{
			if ( attacker [[level.aat_reroll[key].active_func]]() )
			{
				for ( i = 0; i < level.aat_reroll[key].count; i++ )
				{
					if ( percentage >= RandomFloat( 1 ) )
					{
						success = true;
						reroll_icon = level.aat_reroll[key].damage_feedback_icon;

						break;
					}
				}
			}

			if ( success )
			{
				break;
			}
		}
	}

	if ( !success )
	{
		return;
	}

	level.aat[name].cooldown_time_global_start = now;
	attacker.aat_cooldown_start[name] = now;

	self thread [[level.aat[name].result_func]]( death, attacker, mod, weapon );
	attacker thread damagefeedback::update_override( level.aat[name].damage_feedback_icon, level.aat[name].damage_feedback_sound, reroll_icon );
}

/@
"Name: register( <name>, <percentage>, <cooldown_time_entity>, <cooldown_time_attacker>, <cooldown_time_global>, <occurs_on_death>, <result_func>, <damage_feedback_icon>, <damage_feedback_sound>, <validation_func> )"
"Summary: Register an AAT
"Module: AAT"
"MandatoryArg: <name> Unique name to identify the AAT.
"MandatoryArg: <percentage> Float value representing the percentage chance that the result occurs.
"MandatoryArg: <cooldown_time_entity> Cooldown time per entity where we don't check for the same result from the same player/AAT combo. To prevent particularly intense AATs from spamming. 0 is a valid value
"MandatoryArg: <cooldown_time_attacker> Cooldown time that applies per player where we check if the attacker has triggered the AAT. To prevent particularly intense AATs from spamming. 0 is a valid value
"MandatoryArg: <cooldown_time_global> Cooldown time across all entities where we don't check for the same result from the same player/AAT combo. To prevent particularly intense AATs from spamming. 0 is a valid value
"MandatoryArg: <occurs_on_death> Bool representing whether the AAT can occur on death
"MandatoryArg: <result_func> Function pointer to run in response to the result occurring. This is responsible for 3rd person FX, sounds, and other results.
"MandatoryArg: <damage_feedback_icon> Name of the icon to use for damage_feedback.
"MandatoryArg: <damage_feedback_sound> Name of the sound to use for damage_feedback.
"OptionalArg: [validation_func] Function pointer that, if defined, will run an AAT-specific check to see if the AAT should run.
"Example: level aat::register( ZM_AAT_FIRE_WORKS_NAME, ZM_AAT_FIRE_WORKS_PERCENTAGE, ZM_AAT_FIRE_WORKS_COOLDOWN_ENTITY, ZM_AAT_FIRE_WORKS_COOLDOWN_ATTACKER, ZM_AAT_FIRE_WORKS_COOLDOWN_GLOBAL, ZM_AAT_FIRE_WORKS_OCCURS_ON_DEATH, &result, ZM_AAT_FIRE_WORKS_DAMAGE_FEEDBACK_ICON, ZM_AAT_FIRE_WORKS_DAMAGE_FEEDBACK_SOUND, &fire_works_zombie_validation );"
"SPMP: both"
@/
function register( name, percentage, cooldown_time_entity, cooldown_time_attacker, cooldown_time_global, occurs_on_death, result_func, damage_feedback_icon, damage_feedback_sound, validation_func )
{
	assert( IS_TRUE( level.aat_initializing ), "All info registration in the AAT system must occur during the first frame while the system is initializing" );
	
	assert( IsDefined( name ), "aat::register(): name must be defined" );
	assert( AAT_RESERVED_NAME != name, "aat::register(): name cannot be '" + AAT_RESERVED_NAME + "', that name is reserved as an internal sentinel value" );
	assert( !IsDefined( level.aat[name] ), "aat::register(): AAT '" + name + "' has already been registered" );

	assert( IsDefined( percentage ), "aat::register(): AAT '" + name + "': percentage must be defined" );
	assert( 0 <= percentage && 1 > percentage, "aat::register(): AAT '" + name + "': percentage must be a value greater than or equal to 0 and less than 1" );

	assert( IsDefined( cooldown_time_entity ), "aat::register(): AAT '" + name + "': cooldown_time_entity must be defined" );
	assert( 0 <= cooldown_time_entity, "aat::register(): AAT '" + name + "': cooldown_time_entity must be a value greater than or equal to 0" );
	
	assert( IsDefined( cooldown_time_entity ), "aat::register(): AAT '" + name + "': cooldown_time_attacker must be defined" );
	assert( 0 <= cooldown_time_entity, "aat::register(): AAT '" + name + "': cooldown_time_attacker must be a value greater than or equal to 0" );

	assert( IsDefined( cooldown_time_global ), "aat::register(): AAT '" + name + "': cooldown_time_global must be defined" );
	assert( 0 <= cooldown_time_global, "aat::register(): AAT '" + name + "': cooldown_time_global must be a value greater than or equal to 0" );

	assert( IsDefined( occurs_on_death ), "aat::register(): AAT '" + name + "': occurs_on_death must be defined" );

	assert( IsDefined( result_func ), "aat::register(): AAT '" + name + "': result_func must be defined" );

	assert( IsDefined( damage_feedback_icon ), "aat::register(): AAT '" + name + "': damage_feedback_icon must be defined" );
	assert( IsString( damage_feedback_icon ), "aat::register(): AAT '" + name + "': damage_feedback_icon must be a string" );

	assert( IsDefined( damage_feedback_sound ), "aat::register(): AAT '" + name + "': damage_feedback_sound must be defined" );
	assert( IsString( damage_feedback_sound ), "aat::register(): AAT '" + name + "': damage_feedback_sound must be a string" );

	level.aat[name] = SpawnStruct();

	level.aat[ name ].name = name;
	level.aat[ name ].hash_id = HashString(name);
	level.aat[ name ].percentage = percentage;
	level.aat[ name ].cooldown_time_entity = cooldown_time_entity;
	level.aat[ name ].cooldown_time_attacker = cooldown_time_attacker;
	level.aat[ name ].cooldown_time_global = cooldown_time_global;
	level.aat[ name ].cooldown_time_global_start = 0;
	level.aat[ name ].occurs_on_death = occurs_on_death;
	level.aat[ name ].result_func = result_func;
	level.aat[ name ].damage_feedback_icon = damage_feedback_icon;
	level.aat[ name ].damage_feedback_sound = damage_feedback_sound;
	level.aat[ name ].validation_func = validation_func;
	level.aat[ name ].immune_trigger = [];
	level.aat[ name ].immune_result_direct = [];
	level.aat[ name ].immune_result_indirect = [];
}

/@
"Name: register( <name>, <archetype>, <immune_trigger>, <immune_result_direct>, <immune_result_indirect> )"
"Summary: Register an AAT
"Module: AAT"
"MandatoryArg: <name> Unique name to identify the AAT.
"MandatoryArg: <archetype> Archetype of enemy this immunity is registered for.
"MandatoryArg: <immune_trigger> Boolean that determines if the AAT can be triggered by shooting the Archetype. True == Archetype is immune
"MandatoryArg: <immune_result_direct> Boolean that determines if direct AAT effects 
"MandatoryArg: <immune_result_indirect> Cooldown time across all entities where we don't check for the same result from the same player/AAT combo. To prevent particularly intense AATs from spamming. 0 is a valid value
"Example: level aat::immunity_register( "burn_furnace", ARCHETYPE_MARGWA, false, true, true );"
"SPMP: both"
@/
function register_immunity( name, archetype, immune_trigger, immune_result_direct, immune_result_indirect )
{
	// Waits for AAT's to complete initialization, then begin immunity registration
	while ( level.aat_initializing !== false )
	{
		wait SERVER_FRAME;
	}
	
	// ASSERTS
	assert( isdefined( name ), "aat::register(): name must be defined" );
	assert( isdefined( archetype ), "aat::register(): archetype must be defined" );
	assert( isdefined( immune_trigger ), "aat::register(): immune_trigger must be defined" );
	assert( isdefined( immune_result_direct ), "aat::register(): immune_result_direct must be defined" );
	assert( isdefined( immune_result_indirect ), "aat::register(): immune_result_indirect must be defined" );
	
	if ( !isdefined( level.aat[ name ].immune_trigger ) )
    {
		level.aat[ name ].immune_trigger = [];
	}
	
	if ( !isdefined( level.aat[name].immune_result_direct ) )
    {
		level.aat[ name ].immune_result_direct = [];
	}
	
	if ( !isdefined( level.aat[name].immune_result_indirect ) )
    {
		level.aat[ name ].immune_result_indirect = [];
	}
	
	level.aat[ name ].immune_trigger[ archetype ] = immune_trigger;
	level.aat[ name ].immune_result_direct[ archetype ] = immune_result_direct;
	level.aat[ name ].immune_result_indirect[ archetype ] = immune_result_indirect;
}

function finalize_clientfields()
{	
	/#println( "AAT server registrations:" );#/

	if ( level.aat.size > 1 )
	{
		array::alphabetize( level.aat );
		
		i = 0;
		foreach ( aat in level.aat )
		{
	
			aat.clientfield_index = i;
			i++;

			/#println( "    " + aat.name );#/
		}
		
		n_bits = GetMinBitCountForNum( level.aat.size - 1 );
		clientfield::register( "toplayer", AAT_CLIENTFIELD_NAME, VERSION_SHIP, n_bits, "int" );
	}
	
	level.aat_initializing = false;
}

// Initializes weapon exemptions
function register_aat_exemption( weapon )
{	
	weapon = get_nonalternate_weapon( weapon );
	
	level.aat_exemptions[ weapon ] = true;
}

// Checks if weapon is exempt from gaining an AAT. Exemptions defined in array level.aat_exemptions
function is_exempt_weapon( weapon )
{	
	weapon = get_nonalternate_weapon( weapon );
	
	return isdefined( level.aat_exemptions[ weapon ] );
}

/@
"Name: register_reroll( <name>, <count>, <active_func>, <damage_feedback_icon> )"
"Summary: Register an AAT
"Module: AAT"
"MandatoryArg: <name> Unique name to identify the AAT.
"MandatoryArg: <count> Int value the number of rerolls.
"MandatoryArg: <active_func> Function pointer to run to test if the player has the reroll currently active.
"MandatoryArg: <damage_feedback_icon> Name of the icon to use for damage_feedback in addition to the AAT's icon, this signifies the AAT occurred thanks to this reroll.
"Example: level aat::register_reroll( "lucky_crit", 2, &_zm_bgb_lucky_crit::active, "t7_hud_zm_aat_bgb" );"
"SPMP: both"
@/
function register_reroll( name, count, active_func, damage_feedback_icon )
{
	assert( IsDefined( name ), "aat::register_reroll (): name must be defined" );
	assert( AAT_RESERVED_NAME != name, "aat::register_reroll(): name cannot be '" + AAT_RESERVED_NAME + "', that name is reserved as an internal sentinel value" );
	assert( !IsDefined( level.aat[name] ), "aat::register_reroll(): AAT Reroll'" + name + "' has already been registered" );

	assert( IsDefined( count ), "aat::register_reroll(): AAT Reroll '" + name + "': count must be defined" );
	assert( 0 < count, "aat::register_reroll(): AAT Reroll '" + name + "': count must be greater than 0" );

	assert( IsDefined( active_func ), "aat::register_reroll(): AAT Reroll '" + name + "': active_func must be defined" );

	assert( IsDefined( damage_feedback_icon ), "aat::register_reroll(): AAT Reroll '" + name + "': damage_feedback_icon must be defined" );
	assert( IsString( damage_feedback_icon ), "aat::register_reroll(): AAT Reroll '" + name + "': damage_feedback_icon must be a string" );

	level.aat_reroll[name] = SpawnStruct();

	level.aat_reroll[name].name = name;
	level.aat_reroll[name].count = count;
	level.aat_reroll[name].active_func = active_func;
	level.aat_reroll[name].damage_feedback_icon = damage_feedback_icon;
}

function getAATOnWeapon(weapon) //self == player
{
	weapon = get_nonalternate_weapon( weapon );
	
	if ( 		weapon == level.weaponNone
	 	    ||	!IS_TRUE( level.aat_in_use )
			|| 	is_exempt_weapon( weapon )
			|| 	(!isDefined(self.aat) || !isDefined(self.aat[weapon]))
			||	!isDefined( level.aat[self.aat[weapon]])
		)
	{
		return undefined;
	}
	
	return level.aat[self.aat[weapon]];
}


/@
"Name: acquire( <weapon>, <name> )"
"Summary: The player acquires the specified AAT on the specified weapon. If a specific AAT is not supplied, a random AAT is selected by the system, unless one alredy exists for that weapon, in which case no action is taken
"Module: AAT"
"MandatoryArg: <weapon> Weapon object to receive the AAT.
"OptionalArg: <name> Unique name to identify the AAT to receive, will be randomly selected if undefined.
"Example: self aat::acquire( ar_standard_upgraded_object );"
"SPMP: both"
@/
function acquire( weapon, name )
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	assert( IsDefined( weapon ), "aat::acquire(): weapon must be defined" );
	assert( weapon != level.weaponNone, "aat::acquire(): weapon must not be level.weaponNone" );
	
	weapon = get_nonalternate_weapon( weapon );
	
	if ( is_exempt_weapon( weapon ) )
	{
		return;
	}
	
	if ( IsDefined( name ) )
	{
		assert( AAT_RESERVED_NAME != name, "aat::acquire(): name cannot be '" + AAT_RESERVED_NAME + "', that name is reserved as an internal sentinel value" );
		assert( IsDefined( level.aat[name] ), "aat::acquire(): AAT '" + name + "' was never registered" );

		self.aat[weapon] = name;
	}
	else
	{
		keys = GetArrayKeys( level.aat );
		
		ArrayRemoveValue( keys, AAT_RESERVED_NAME );
		
		// If weapon has AAT, remove current AAT from possible rerolls
		if ( IsDefined( self.aat[ weapon ] ) )
		{
			ArrayRemoveValue( keys, self.aat[ weapon ] );
		}
		
		rand = RandomInt( keys.size );
		self.aat[weapon] = keys[rand];
	}

	if ( weapon == self GetCurrentWeapon() )
	{
		self clientfield::set_to_player( AAT_CLIENTFIELD_NAME, level.aat[self.aat[weapon]].clientfield_index );
	}
}


/@
"Name: remove( <weapon> )"
"Summary: Removes the AAT from the specified weapon for the player
"Module: AAT"
"MandatoryArg: <weapon> Weapon object to remove the AAT from.
"Example: self aat::remove( ar_standard_upgraded_object );"
"SPMP: both"
@/
function remove( weapon )
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	assert( IsDefined( weapon ), "aat::remove(): weapon must be defined" );
	assert( weapon != level.weaponNone, "aat::remove(): weapon must not be level.weaponNone" );
	
	weapon = get_nonalternate_weapon( weapon );
	
	self.aat[weapon] = undefined;
}

// Monitors weapon changes to detect AAT names, then sends the names to the clientside for HUD changes
function watch_weapon_changes()
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	
	while ( isdefined( self ) )
	{
		self waittill( "weapon_change", weapon );
		
		weapon = get_nonalternate_weapon( weapon );
		
		name = AAT_RESERVED_NAME;
		if ( IsDefined( self.aat[weapon] ) )
		{
			name = self.aat[weapon];
		}
		
		self clientfield::set_to_player( AAT_CLIENTFIELD_NAME, level.aat[name].clientfield_index );
	}
}

