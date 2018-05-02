#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#namespace weapon_utils;

function isPistol( weapon )
{
	return isdefined( level.side_arm_array[ weapon ] );
}


function isFlashOrStunWeapon( weapon )
{
	return weapon.isFlash || weapon.isStun;
}

function isFlashOrStunDamage( weapon, meansofdeath )
{
	return ( isFlashOrStunWeapon(weapon) && ( meansofdeath == "MOD_GRENADE_SPLASH" || meansofdeath == "MOD_GAS" ) );
}

function isMeleeMOD( mod )
{
	return ( mod == "MOD_MELEE" || mod == "MOD_MELEE_WEAPON_BUTT" || mod == "MOD_MELEE_ASSASSINATE" );
}

function isPunch( weapon )
{
	return weapon.type == "melee" && weapon.rootWeapon.name == "bare_hands";
}

function isKnife( weapon )
{
	return weapon.type == "melee" && weapon.rootWeapon.name == "knife_loadout";
}

function isNonBareHandsMelee( weapon )
{
	return (weapon.type == "melee" && weapon.rootWeapon.name != "bare_hands") || weapon.isBallisticKnife;
}
