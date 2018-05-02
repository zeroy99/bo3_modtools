#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#namespace weapon_utils;

function getBaseWeaponParam( weapon )
{
	// figure out the weapon to pass as a parameter to GetBaseWeaponItemIndex()
	return ( ( weapon.rootweapon.altweapon != level.weaponNone ) ? weapon.rootweapon.altweapon.rootweapon :  weapon.rootweapon );
}
