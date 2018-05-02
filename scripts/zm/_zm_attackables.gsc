#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\table_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_attackables.gsh;
	
#namespace zm_attackables;

REGISTER_SYSTEM_EX( "zm_attackables", &__init__, &__main__, undefined )

function __init__()
{
	level.attackableCallback = &attackable_callback;

	level.attackables = struct::get_array( "scriptbundle_attackables", "classname" );

	foreach( attackable in level.attackables )
	{
		attackable.bundle = struct::get_script_bundle( "attackables", attackable.scriptbundlename );

		if ( isdefined( attackable.target ) )
		{
			attackable.slot = struct::get_array( attackable.target, "targetname" );
		}

		attackable.is_active = false;
		attackable.health = attackable.bundle.max_health;

		if ( GetDvarInt( "zm_attackables" ) > 0 )
		{
			attackable.is_active = true;
			attackable.health = 1000;
		}

	}
}

function __main__()
{
}

function get_attackable() // self = zombie AI
{
	foreach( attackable in level.attackables )
	{
		if ( !IS_TRUE( attackable.is_active ) )
		{
			continue;
		}

		dist = Distance( self.origin, attackable.origin );
		if ( dist < attackable.bundle.aggro_distance )
		{
			if ( attackable get_attackable_slot( self ) )
			{
				return attackable;
			}
		}
	}

	return undefined;
}

function get_attackable_slot( entity ) // self = attackble scriptbundle (struct)
{
	//self.slot = array::remove_dead( self.slot );

	//if ( self.slot.size < self.bundle.max_attackers )
	//{
	//	ARRAY_ADD( self.slot, entity );
	//	return true;
	//}

	self clear_slots();
 
	foreach( slot in self.slot )
	{
		if ( !isdefined( slot.entity ) )
		{
			slot.entity = entity;
			entity.attackable_slot = slot;
			return true;
		}
	}

	return false;
}

function private clear_slots() // self = attackble scriptbundle (struct)
{
	foreach( slot in self.slot )
	{
		if ( !IsAlive( slot.entity ) )
		{
			slot.entity = undefined;
		}
		else
		{
			if ( IS_TRUE( slot.entity.missingLegs ) )
			{
				slot.entity = undefined;
			}
		}
	}
}

function activate() // self = attackble scriptbundle (struct)
{
	self.is_active = true;
	
	// Re-set the attackable's health if it's 0
	// Allows the attackable to be re-used
	if( self.health <= 0 )
	{
		self.health = self.bundle.max_health;	
	}
}

function deactivate() // self = attackble scriptbundle (struct)
{
	self.is_active = false;
}

function do_damage( damage ) // self = attackble scriptbundle (struct)
{
	self.health -= damage;
	self notify( "attackable_damaged" );

	if ( self.health <= 0 )
	{
		self notify( "attackable_deactivated" );
		
		if( !IS_TRUE( self.b_deferred_deactivation ) )
		{
			self deactivate();	
		}
	}
}

function attackable_callback( entity )
{	
	self do_damage( entity.meleeWeapon.meleeDamage );
}
