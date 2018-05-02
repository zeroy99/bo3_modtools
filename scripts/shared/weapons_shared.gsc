#using scripts\codescripts\struct;

#using scripts\shared\gameobjects_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapons;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace weapons;

// weapon stowing logic ===================================================================

// weapon class boolean helpers
function is_primary_weapon( weapon )
{
	root_weapon = weapon.rootWeapon;
	return root_weapon != level.weaponNone && isdefined( level.primary_weapon_array[root_weapon] );
}
function is_side_arm( weapon )
{
	root_weapon = weapon.rootWeapon;
	return root_weapon != level.weaponNone && isdefined( level.side_arm_array[root_weapon] );
}
function is_inventory( weapon )
{
	root_weapon = weapon.rootWeapon;
	return root_weapon != level.weaponNone && isdefined( level.inventory_array[root_weapon] );
}
function is_grenade( weapon )
{
	root_weapon = weapon.rootWeapon;
	return root_weapon != level.weaponNone && isdefined( level.grenade_array[root_weapon] );
}

function force_stowed_weapon_update()
{
	detach_all_weapons();
	stow_on_back();
	stow_on_hip();
}

function detach_carry_object_model()
{
	if ( isdefined( self.carryObject ) && isdefined(self.carryObject gameobjects::get_visible_carrier_model())  )
	{
		if( isdefined( self.tag_stowed_back ) )
		{
			self detach( self.tag_stowed_back, "tag_stowed_back" );
			self.tag_stowed_back = undefined;
		}
	}
}

function detach_all_weapons()
{
	if( isdefined( self.tag_stowed_back ) )
	{
		clear_weapon = true;

		if ( isdefined( self.carryObject ))
		{
			carrierModel = self.carryObject gameobjects::get_visible_carrier_model();

			if ( isdefined( carrierModel ) && carrierModel == self.tag_stowed_back )
			{
				self detach( self.tag_stowed_back, "tag_stowed_back" );
				clear_weapon = false;
			}
		}

		if ( clear_weapon )
		{
			self ClearStowedWeapon();
		}
		
		self.tag_stowed_back = undefined;
	}
	else
	{
		self ClearStowedWeapon();
	}
	
	if( isdefined( self.tag_stowed_hip ) )
	{
		detach_model = self.tag_stowed_hip.worldModel;
		self detach( detach_model, "tag_stowed_hip_rear" );
		self.tag_stowed_hip = undefined;
	}
}

function stow_on_back(current)
{
	currentWeapon = self getCurrentWeapon();
	currentAltWeapon = currentWeapon.altWeapon;
	
	self.tag_stowed_back = undefined;
	weaponOptions = 0;
	index_weapon = level.weaponNone;

	//  carry objects take priority
	if ( isdefined( self.carryObject ) && isdefined(self.carryObject gameobjects::get_visible_carrier_model())  )
	{
		self.tag_stowed_back = self.carryObject gameobjects::get_visible_carrier_model();
		self attach( self.tag_stowed_back, "tag_stowed_back", true );
		return;
	}
	else if ( currentWeapon != level.weaponNone )
	{
		for ( idx = 0; idx < self.weapon_array_primary.size; idx++ )
		{

			temp_index_weapon = self.weapon_array_primary[idx];
			assert( isdefined( temp_index_weapon ), "Primary weapon list corrupted." );

			if ( temp_index_weapon == currentWeapon )
				continue;

			if ( temp_index_weapon == currentAltWeapon )
				continue;
			
			if ( temp_index_weapon.nonStowedWeapon )
				continue;

			index_weapon = temp_index_weapon;
		}
	}

	self SetStowedWeapon( index_weapon );
}

function stow_on_hip()
{
	currentWeapon = self getCurrentWeapon();

	self.tag_stowed_hip = undefined;

	for ( idx = 0; idx < self.weapon_array_inventory.size; idx++ )
	{
		if ( self.weapon_array_inventory[idx] == currentWeapon )
			continue;

		if ( !self GetWeaponAmmoStock( self.weapon_array_inventory[idx] ) )
			continue;
			
		self.tag_stowed_hip = self.weapon_array_inventory[idx];
	}

	if ( !isdefined( self.tag_stowed_hip ) )
		return;

	self attach( self.tag_stowed_hip.worldmodel, "tag_stowed_hip_rear", true );
}

function weaponDamageTracePassed(from, to, startRadius, ignore)
{
	trace = weaponDamageTrace(from, to, startRadius, ignore);	
	return (trace["fraction"] == 1);
}

function weaponDamageTrace(from, to, startRadius, ignore)
{
	midpos = undefined;
	
	diff = to - from;
	if ( lengthsquared( diff ) < startRadius*startRadius )
		midpos = to;
	dir = vectornormalize( diff );
	midpos = from + (dir[0]*startRadius, dir[1]*startRadius, dir[2]*startRadius);

	trace = bullettrace(midpos, to, false, ignore);
	
	if ( GetDvarint( "scr_damage_debug") != 0 )
	{
		if (trace["fraction"] == 1)
		{
			thread weapons::debugline(midpos, to, (1,1,1));
		}
		else
		{
			thread weapons::debugline(midpos, trace["position"], (1,.9,.8));
			thread weapons::debugline(trace["position"], to, (1,.4,.3));
		}
	}
	
	return trace;
}

function has_lmg()
{
	weapon = self GetCurrentWeapon();
	return ( weapon.weapClass == "mg" );
}

function has_launcher()
{
	weapon = self GetCurrentWeapon();
	return weapon.isRocketLauncher;
}

function has_hero_weapon()
{
	weapon = self GetCurrentWeapon();
	return ( weapon.gadget_type == GADGET_TYPE_HERO_WEAPON );
}

function has_lockon( target )
{
	player = self;
	clientNum = player getEntityNumber();
	return isdefined( target.locked_on ) && ( target.locked_on & ( 1 << clientNum ) );
}
