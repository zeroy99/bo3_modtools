#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\weapons\_weapons;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_loadout;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\gametypes\_weapon_utils;
#using scripts\mp\gametypes\_weaponobjects;

#using scripts\mp\_challenges;
#using scripts\mp\_scoreevents;
#using scripts\mp\_util;
#using scripts\mp\killstreaks\_dogs;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_weapons;
#using scripts\mp\killstreaks\_supplydrop;

#namespace weapons;

REGISTER_SYSTEM( "weapons", &__init__, undefined )
	
function __init__()
{
	weapons::init_shared();
}


function bestweapon_kill( weapon )
{

}

function bestweapon_spawn( weapon, options, acvi )
{
}


function bestweapon_init( weapon, options, acvi )
{
	weapon_data = [];
	weapon_data["weapon"] = weapon;
	weapon_data["options"] = options;
	weapon_data["acvi"] = acvi;
	weapon_data["kill_count"] = 0;
	weapon_data["spawned_with"] = 0;
	key = self.pers["bestWeapon"][weapon.name].size;
	self.pers["bestWeapon"][weapon.name][key] = weapon_data;
	
	return key;
}

function bestweapon_find( weapon, options, acvi )
{
	if ( !isDefined( self.pers["bestWeapon"] ) )
	{
		self.pers["bestWeapon"] = [];
	}
	if ( !IsDefined( self.pers["bestWeapon"][weapon.name] ) )
	{
		self.pers["bestWeapon"][weapon.name] = [];
	}

	name = weapon.name;
	size = self.pers["bestWeapon"][name].size;
	for( index = 0; index < size; index++ )
	{
		if ( self.pers["bestWeapon"][name][index]["weapon"] == weapon 
		    && self.pers["bestWeapon"][name][index]["options"] == options && 
		    self.pers["bestWeapon"][name][index]["acvi"] == acvi )
		{
			return index;
		}
	}

	return undefined;
}


function bestweapon_get()
{
	most_kills = 0;
	most_spawns = 0;
	
	if ( !IsDefined( self.pers["bestWeapon"] ) )
	{
		return;
	}
	
	best_key = 0;
	best_index = 0;
	weapon_keys = GetArrayKeys( self.pers["bestWeapon"] );
	for( key_index = 0; key_index < weapon_keys.size; key_index++ )
	{
		key = weapon_keys[key_index];
		size = self.pers["bestWeapon"][key].size;
		for( index = 0; index < size; index++ )
		{
			kill_count = self.pers["bestWeapon"][key][index]["kill_count"];
			spawned_with = self.pers["bestWeapon"][key][index]["spawned_with"];
			
			if ( kill_count > most_kills )
			{
				best_index = index;
				best_key = key;
				most_kills = kill_count;
				most_spawns = spawned_with;
			}
			else if ( kill_count == most_kills && spawned_with > most_spawns )
			{
				best_index = index;
				best_key = key;
				most_kills = kill_count;
				most_spawns = spawned_with;
			}
		}
	}
	
	return self.pers["bestWeapon"][best_key][best_index];
}

function showcaseweapon_get()
{
	showcaseWeaponData = self GetPlayerShowcaseWeapon();
	
	if ( !isdefined( showcaseWeaponData ) )
	{
		return undefined;
	}
	
	showcase_weapon = [];
	
	showcase_weapon["weapon"] = showcaseWeaponData.weapon;
	
	attachmentNames = [];
	attachmentIndices = [];
	tokenizedAttachmentInfo = strtok( showcaseWeaponData.attachmentInfo, "," );
	for ( index = 0; index + 1 < tokenizedAttachmentInfo.size; index += 2 )
	{
		attachmentNames[ attachmentNames.size ] = tokenizedAttachmentInfo[ index ];
		attachmentIndices[ attachmentIndices.size ] = int( tokenizedAttachmentInfo[ index + 1 ] );
	}
	for ( index = tokenizedAttachmentInfo.size; index + 1 < 16; index += 2 )
	{
		attachmentNames[ attachmentNames.size ] = "none";
		attachmentIndices[ attachmentIndices.size ] = 0;
	}
	showcase_weapon["acvi"] = GetAttachmentCosmeticVariantIndexes( showcaseWeaponData.weapon,
	                                                       attachmentNames[ 0 ], attachmentIndices[ 0 ],
	                                                       attachmentNames[ 1 ], attachmentIndices[ 1 ],
	                                                       attachmentNames[ 2 ], attachmentIndices[ 2 ],
	                                                       attachmentNames[ 3 ], attachmentIndices[ 3 ],
	                                                       attachmentNames[ 4 ], attachmentIndices[ 4 ],
	                                                       attachmentNames[ 5 ], attachmentIndices[ 5 ],
	                                                       attachmentNames[ 6 ], attachmentIndices[ 6 ],
	                                                       attachmentNames[ 7 ], attachmentIndices[ 7 ] );
	
	camoIndex = 0;
	paintjobSlot = CUSTOMIZATION_INVALID_PAINTJOB_SLOT;
	paintjobIndex = CUSTOMIZATION_INVALID_PAINTJOB_INDEX;
	showPaintshop = false;
	tokenizedWeaponRenderOptions = strtok( showcaseWeaponData.weaponRenderOptions, "," );
	if ( tokenizedWeaponRenderOptions.size > 2 )
	{
		camoIndex = int( tokenizedWeaponRenderOptions[ 0 ] );
		paintjobSlot = int( tokenizedWeaponRenderOptions[ 1 ] );
		paintjobIndex = int( tokenizedWeaponRenderOptions[ 2 ] );
		showPaintshop = paintjobSlot != CUSTOMIZATION_INVALID_PAINTJOB_SLOT && paintjobIndex != CUSTOMIZATION_INVALID_PAINTJOB_INDEX;
	}
	
	showcase_weapon["options"] = self CalcWeaponOptions( camoIndex, 0, 0, false, false, showPaintshop, true );
	
	return showcase_weapon;
}