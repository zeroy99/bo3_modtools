#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\dev_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\loadout_shared;
#using scripts\shared\system_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_util;
#using scripts\shared\weapons\_weapon_utils;
#using scripts\shared\abilities\gadgets\_gadget_roulette;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statstable_shared.gsh;

#using scripts\mp\_armor;
#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_dev;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_weapons;
#using scripts\mp\killstreaks\_killstreak_weapons;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\teams\_teams;

#insert scripts\mp\_bonuscard.gsh;

#namespace loadout;

REGISTER_SYSTEM( "loadout", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
	callback::on_connect( &on_connect );
	
}

function on_connect()
{
}

function init()
{
	level.classMap["class_smg"] = "CLASS_SMG";
	level.classMap["class_cqb"] = "CLASS_CQB";	
	level.classMap["class_assault"] = "CLASS_ASSAULT";
	level.classMap["class_lmg"] = "CLASS_LMG";
	level.classMap["class_sniper"] = "CLASS_SNIPER";

	level.classMap["custom0"] = "CLASS_CUSTOM1";
	level.classMap["custom1"] = "CLASS_CUSTOM2";
	level.classMap["custom2"] = "CLASS_CUSTOM3";
	level.classMap["custom3"] = "CLASS_CUSTOM4";
	level.classMap["custom4"] = "CLASS_CUSTOM5";
	level.classMap["custom5"] = "CLASS_CUSTOM6";
	level.classMap["custom6"] = "CLASS_CUSTOM7";
	level.classMap["custom7"] = "CLASS_CUSTOM8";
	level.classMap["custom8"] = "CLASS_CUSTOM9";
	level.classMap["custom9"] = "CLASS_CUSTOM10";
	
	level.maxKillstreaks = 4;
	level.maxSpecialties = 6;
	level.maxBonuscards = 3;
	level.maxAllocation = GetGametypeSetting( "maxAllocation" );
	level.loadoutKillstreaksEnabled = GetGametypeSetting( "loadoutKillstreaksEnabled" );
	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		level.loadoutKillstreaksEnabled = 1;
	
	//override the base melee weapon from _weapons.gsc
	level.weaponBaseMeleeHeld = GetWeapon( "bare_hands" );
	level.weaponKnifeLoadout = GetWeapon( "knife_loadout" );
	level.weaponMeleeKnuckles = GetWeapon( "melee_knuckles" );
	level.weaponMeleeButterfly = GetWeapon( "melee_butterfly" );
	level.weaponMeleeWrench = GetWeapon( "melee_wrench" );
	level.weaponMeleeSword = GetWeapon( "melee_sword" );
	level.weaponMeleeCrowbar = GetWeapon( "melee_crowbar" );
	level.weaponSpecialCrossbow = GetWeapon( "special_crossbow" );
	level.weaponMeleeDagger = GetWeapon( "melee_dagger" );
	level.weaponMeleeBat = GetWeapon( "melee_bat" );
	level.weaponMeleeBowie = GetWeapon( "melee_bowie" );
	level.weaponMeleeMace = GetWeapon( "melee_mace" );
	level.weaponMeleeFireAxe = GetWeapon( "melee_fireaxe" );
	level.weaponMeleeBoneGlass = GetWeapon( "melee_boneglass" );
	level.weaponMeleeImprovise = GetWeapon( "melee_improvise" );
	level.weaponShotgunEnergy = GetWeapon( "shotgun_energy" );
	level.weaponPistolEnergy = GetWeapon( "pistol_energy" );
	level.weaponMeleeShockBaton = GetWeapon( "melee_shockbaton" );
	level.weaponMeleeNunchuks = GetWeapon( "melee_nunchuks" );
	level.weaponMeleeBoxing = GetWeapon( "melee_boxing" );
	level.weaponMeleeKatana = GetWeapon( "melee_katana" );
	level.weaponMeleeShovel = GetWeapon( "melee_shovel" );
	level.weaponMeleeProsthetic = GetWeapon( "melee_prosthetic" );
	level.weaponMeleeChainsaw = GetWeapon( "melee_chainsaw" );
	level.weaponSpecialDiscGun = GetWeapon( "special_discgun" );
	level.weaponSmgNailGun = GetWeapon( "smg_nailgun" );
	level.weaponLauncherMulti = GetWeapon( "launcher_multi" );
	level.weaponMeleeCrescent = GetWeapon( "melee_crescent" );
	level.weaponLauncherEx41 = GetWeapon( "launcher_ex41" );

	level.meleeWeapons = []; // intended for use with medals and challenges, namely "kill_enemy_with_their_weapon"
	ARRAY_ADD( level.meleeWeapons, level.weaponKnifeLoadout );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeKnuckles );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeButterfly );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeWrench );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeSword );	
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeCrowbar );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeDagger );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeBat );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeBowie );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeMace );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeFireAxe );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeBoneGlass );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeImprovise );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeShockBaton );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeNunchuks );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeBoxing );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeKatana );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeShovel );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeProsthetic );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeChainsaw );
	ARRAY_ADD( level.meleeWeapons, level.weaponMeleeCrescent );

	// placed here for easier integration
	level.weaponBouncingBetty = GetWeapon( "bouncingbetty" );
	
	level.PrestigeNumber = 5;
	
	level.defaultClass = "CLASS_ASSAULT";
	
	if ( tweakables::getTweakableValue( "weapon", "allowfrag" ) )
	{
		level.weapons["frag"] = GetWeapon( "frag_grenade" );
	}
	else	
	{
		level.weapons["frag"] = "";
	}

	if ( tweakables::getTweakableValue( "weapon", "allowsmoke" ) )
	{
		level.weapons["smoke"] = GetWeapon( "smoke_grenade" );
	}
	else	
	{
		level.weapons["smoke"] = "";
	}

	if ( tweakables::getTweakableValue( "weapon", "allowflash" ) )
	{
		level.weapons["flash"] = GetWeapon( "flash_grenade" );
	}
	else	
	{
		level.weapons["flash"] = "";
	}

	level.weapons["concussion"] = GetWeapon( "concussion_grenade" );

	if ( tweakables::getTweakableValue( "weapon", "allowsatchel" ) )
	{
		level.weapons["satchel_charge"] = GetWeapon( "satchel_charge" );
	}
	else	
	{
		level.weapons["satchel_charge"] = "";
	}

	if ( tweakables::getTweakableValue( "weapon", "allowbetty" ) )
	{
		level.weapons["betty"] = GetWeapon( "mine_bouncing_betty" );
	}
	else	
	{
		level.weapons["betty"] = "";
	}

	if ( tweakables::getTweakableValue( "weapon", "allowrpgs" ) )
	{
		level.weapons["rpg"] = GetWeapon( "rpg" );
	}
	else	
	{
		level.weapons["rpg"] = "";
	}
	
	create_class_exclusion_list();
	
	// initializes create a class settings
	cac_init();	
	
	load_default_loadout( "CLASS_SMG", 10 );
	load_default_loadout( "CLASS_CQB", 11 );
	load_default_loadout( "CLASS_ASSAULT", 12 );	
	load_default_loadout( "CLASS_LMG", 13 );
	load_default_loadout( "CLASS_SNIPER", 14 );

	// generating weapon type arrays which classifies the weapon as primary (back stow), pistol, or inventory (side pack stow)
	// using mp/statstable.csv's weapon grouping data ( numbering 0 - 149 )
	level.primary_weapon_array = [];
	level.side_arm_array = [];
	level.grenade_array = [];
	level.inventory_array = [];
	max_weapon_num = 99;
	for( i = 0; i < max_weapon_num; i++ )
	{
		if( !isdefined( level.tbl_weaponIDs[i] ) || level.tbl_weaponIDs[i]["group"] == "" )
		{
			continue;
		}
		if( !isdefined( level.tbl_weaponIDs[i] ) || level.tbl_weaponIDs[i]["reference"] == "" )
		{
			continue;
		}
	
		weapon_type = level.tbl_weaponIDs[i]["group"];
		weapon = level.tbl_weaponIDs[i]["reference"];
		attachment = level.tbl_weaponIDs[i]["attachment"];
	
		weapon_class_register( weapon, weapon_type );	
	
		if( isdefined( attachment ) && attachment != "" )
		{	
			attachment_tokens = strtok( attachment, " " );
			if( isdefined( attachment_tokens ) )
			{
				if( attachment_tokens.size == 0 )
					weapon_class_register( weapon+"_"+attachment, weapon_type );	
				else
				{
					// multiple attachment options
					for( k = 0; k < attachment_tokens.size; k++ )
						weapon_class_register( weapon+"_"+attachment_tokens[k], weapon_type );
				}
			}
		}
	}
	
	callback::on_connecting( &on_player_connecting );
	callback::add_weapon_damage( level.weaponSpecialDiscGun, &on_damage_special_discgun );
	
}
function on_damage_special_discgun( eAttacker, eInflictor, weapon, meansOfDeath, damage )
{
	if ( weapon != level.weaponSpecialDiscGun )
	{
	                return;
	}
	playsoundatposition ("wpn_disc_bounce_fatal", self.origin);
}

function create_class_exclusion_list()
{
	currentDvar = 0;
	
	level.itemExclusions = [];
	
	while( GetDvarInt( "item_exclusion_" + currentDvar ) )
	{
		level.itemExclusions[ currentDvar ] = GetDvarInt( "item_exclusion_" + currentDvar );
		currentDvar++;
	}
	
	level.attachmentExclusions = [];
	
	currentDvar = 0;
	while( GetDvarString( "attachment_exclusion_" + currentDvar ) !="" )
	{
		level.attachmentExclusions[ currentDvar ] = GetDvarString( "attachment_exclusion_" + currentDvar );
		currentDvar++;
	}

}

function is_attachment_excluded( attachment )
{
	numExclusions = level.attachmentExclusions.size;
	
	for ( exclusionIndex = 0; exclusionIndex < numExclusions; exclusionIndex++ )
	{
		if ( attachment == level.attachmentExclusions[ exclusionIndex ] )
		{
			return true;
		}
	}
	
	return false;
}

function set_statstable_id()
{
	if ( !isdefined( level.statsTableID ) )
	{
		statsTableName = util::getStatsTableName();
		level.statsTableID = TableLookupFindCoreAsset( statsTableName );
	}
}

function get_item_count( itemReference )
{
	set_statstable_id();
	
	itemCount = int( tableLookup( level.statsTableID, STATS_TABLE_COL_REFERENCE, itemReference, STATS_TABLE_COL_COUNT ) );
	if ( itemCount < 1 )
	{
		itemCount = 1;
	} 
	
	return itemCount;
}
	
function getDefaultClassSlotWithExclusions( className, slotName )
{
	itemReference = GetDefaultClassSlot( className, slotName );
	
	set_statstable_id();
	
	itemIndex = int( tableLookup( level.statsTableID, STATS_TABLE_COL_REFERENCE, itemReference, STATS_TABLE_COL_NUMBERING ) );
	
	if ( loadout::is_item_excluded( itemIndex ) )
	{
		itemReference = tableLookup( level.statsTableID, STATS_TABLE_COL_NUMBERING, 0, STATS_TABLE_COL_REFERENCE );
	}
	
	return itemReference;
}
	
function load_default_loadout( weaponclass, classNum )
{
	level.classToClassNum[ weaponclass ] = classNum;
}
			
function weapon_class_register( weaponName, weapon_type )
{
	if( isSubstr( "weapon_smg weapon_cqb weapon_assault weapon_lmg weapon_sniper weapon_shotgun weapon_launcher weapon_knife weapon_special", weapon_type ) )
		level.primary_weapon_array[GetWeapon( weaponName )] = 1;	
	else if( isSubstr( "weapon_pistol", weapon_type ) )
		level.side_arm_array[GetWeapon( weaponName )] = 1;
	else if( weapon_type == "weapon_grenade" )
		level.grenade_array[GetWeapon( weaponName )] = 1;
	else if( weapon_type == "weapon_explosive" )
		level.inventory_array[GetWeapon( weaponName )] = 1;
	else if( weapon_type == "weapon_rifle" ) // COD5 WEAPON TEST
		level.inventory_array[GetWeapon( weaponName )] = 1;
	else
		assert( false, "Weapon group info is missing from statsTable for: " + weapon_type );
}

function hero_register_dialog( weapon )
{
	readyVO = weapon.name + "_ready";
	
	game["dialog"][readyVO] = readyVO;
}

// create a class init
function cac_init()
{
	level.tbl_weaponIDs = [];
	level.heroWeaponsTable = [];
	
	set_statstable_id();

	for( i = 0; i < STATS_TABLE_MAX_ITEMS; i++ )
	{
		itemRow = tableLookupRowNum( level.statsTableID, STATS_TABLE_COL_NUMBERING, i );
		
		if ( itemRow > -1 )
		{
			group_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_GROUP );
			
			if ( isSubStr( group_s, "weapon_" ) || group_s == "hero" )
			{
				reference_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_REFERENCE );
				if( reference_s != "" )
				{
					weapon = GetWeapon( reference_s );

					if ( weapon.inventoryType == "hero" )
					{
						level.heroWeaponsTable[reference_s] = [];
						level.heroWeaponsTable[reference_s]["index"] = i;
						
						hero_register_dialog( weapon );
					}

					level.tbl_weaponIDs[i]["reference"] = reference_s;
					level.tbl_weaponIDs[i]["group"] = group_s;
					level.tbl_weaponIDs[i]["count"] = int( tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_COUNT ) );
					level.tbl_weaponIDs[i]["attachment"] = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_ATTACHMENTS );
				}				
			}
		}
	}
	
	level.perkNames = [];
	level.perkIcons = [];
	level.perkSpecialties = [];

	// generating perk data vars collected form statsTable.csv
	for( i = 0; i < STATS_TABLE_MAX_ITEMS; i++ )
	{
		itemRow = tableLookupRowNum( level.statsTableID, STATS_TABLE_COL_NUMBERING, i );
		
		if ( itemRow > -1 )
		{
			group_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_GROUP );
		
			if ( group_s == "specialty" )
			{
				reference_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_REFERENCE );
				
				if( reference_s != "" )
				{
					perkIcon = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_IMAGE );
					perkName  = tableLookupIString( level.statsTableID, STATS_TABLE_COL_NUMBERING, i, STATS_TABLE_COL_NAME );
									
					level.perkNames[ perkIcon ] = perkName;
					
					perk_name = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_NAME );
					level.perkIcons[ perk_name ] = perkIcon;
					level.perkSpecialties[ perk_name ] = reference_s;
				}
			}
		}
	}
	
	level.killStreakNames = [];
	level.killStreakIcons = [];
	level.KillStreakIndices = [];

	// generating kill streak data vars collected form statsTable.csv
	for( i = 0; i < STATS_TABLE_MAX_ITEMS; i++ )
	{
		itemRow = tableLookupRowNum( level.statsTableID, STATS_TABLE_COL_NUMBERING, i );
		
		if ( itemRow > -1 )
		{
			group_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_GROUP );
			
			if ( group_s == "killstreak" )
			{
				reference_s = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_REFERENCE );
				
				if( reference_s != "" )
				{
					level.tbl_KillStreakData[i] = reference_s;
					level.killStreakIndices[ reference_s ] = i;
					icon = tableLookupColumnForRow( level.statsTableID, itemRow, STATS_TABLE_COL_IMAGE );
					name = tableLookupIString( level.statsTableID, STATS_TABLE_COL_NUMBERING, i, STATS_TABLE_COL_NAME );

					level.killStreakNames[ reference_s ] = name;
					level.killStreakIcons[ reference_s ] = icon;
					level.killStreakIndices[ reference_s ] = i;
				}
			}
		}
	}
}

function getClassChoice( response )
{
	assert( isdefined( level.classMap[ response ] ) );
	
	return ( level.classMap[ response ] );
}


// ============================================================================


function getAttachmentString( weaponNum, attachmentNum )
{
	attachmentString = GetItemAttachment( weaponNum, attachmentNum );
	
	if ( attachmentString != "none" && ( !is_attachment_excluded( attachmentString ) ) )
	{
		attachmentString = attachmentString + "_";
	}
	else
	{
		attachmentString = "";
	}
	
	return attachmentString;
}

function getAttachmentsDisabled()
{
	if ( !isdefined( level.attachmentsDisabled ) )
	{
		return false;
	}
	
	return level.attachmentsDisabled;
	
}

function getKillStreakIndex( weaponclass, killstreakNum )
{
	killstreakNum++;
	
	killstreakString = "killstreak" + killstreakNum;
	
	// custom game mode killstreaks
	if ( GetDvarInt( "custom_killstreak_mode" ) == 2 )
	{
		return GetDvarInt( "custom_" + killstreakString );
	}
	else
	{
		return( self GetLoadoutItem( weaponclass, killstreakString ) );
	}
}

function giveKillstreaks()
{
		self.killstreak = [];
		
		if ( !level.loadoutKillstreaksEnabled )
			return;
		
	classNum = self.class_num_for_global_weapons;

		sortedKillstreaks = [];
		currentKillstreak = 0;
		
		for ( killstreakNum = 0; killstreakNum < level.maxKillstreaks; killstreakNum++ )
		{
			killstreakIndex = getKillStreakIndex( classNum, killstreakNum );
			
			if ( isdefined( killstreakIndex ) && ( killstreakIndex > 0 ) )
			{
				assert( isdefined( level.tbl_KillStreakData[ killstreakIndex ] ), "KillStreak #:" + killstreakIndex + "'s data is undefined" );
				
				if ( isdefined( level.tbl_KillStreakData[ killstreakIndex ] ) )
				{
					self.killstreak[ currentKillstreak ] = level.tbl_KillStreakData[ killstreakIndex ];
					if ( isdefined( level.usingMomentum ) && level.usingMomentum )
					{
						killstreakType = killstreaks::get_by_menu_name( self.killstreak[ currentKillstreak ] );
						if ( isdefined( killstreakType ) )
						{
							weapon = killstreaks::get_killstreak_weapon( killstreakType );
							
							self GiveWeapon( weapon );

							if ( isdefined( level.usingScoreStreaks ) && level.usingScoreStreaks )
							{
								if( weapon.isCarriedKillstreak )
								{
									if( !isdefined( self.pers["held_killstreak_ammo_count"][weapon] ) )
										self.pers["held_killstreak_ammo_count"][weapon] = 0;

									if( !isDefined( self.pers["held_killstreak_clip_count"][weapon] ) )
										self.pers["held_killstreak_clip_count"][weapon] = 0;

									if( self.pers["held_killstreak_ammo_count"][weapon] > 0 )
									{
										self setWeaponAmmoClip( weapon, self.pers["held_killstreak_clip_count"][weapon] );
										self setWeaponAmmoStock( weapon, self.pers["held_killstreak_ammo_count"][weapon] - self.pers["held_killstreak_clip_count"][weapon] );
									}
									else
									{
										self setWeaponAmmoOverall( weapon, 0 );
									}
								}
								else
								{
									quantity = self.pers["killstreak_quantity"][weapon];
									if ( !isdefined( quantity ) )
									{
										quantity = 0;
									}
									self setWeaponAmmoClip( weapon, quantity );
							
								}
							}
							// Put killstreak in sorted order from lowest to highest momentum cost
							sortData = spawnstruct();
							sortData.cost = level.killstreaks[killstreakType].momentumCost;
							sortData.weapon = weapon;
							sortIndex = 0;
							for ( sortIndex = 0 ; sortIndex < sortedKillstreaks.size ; sortIndex++ )
							{
								if ( sortedKillstreaks[sortIndex].cost > sortData.cost )
									break;
							}
							for ( i = sortedKillstreaks.size ; i > sortIndex ; i-- )
							{
								sortedKillstreaks[i] = sortedKillstreaks[i-1];
							}
							sortedKillstreaks[sortIndex] = sortData;
						}
					}
					currentKillstreak++;
				}
			}
		}
		
		actionSlotOrder = [];
		actionSlotOrder[0] = 4;
		actionSlotOrder[1] = 2;
		actionSlotOrder[2] = 1;
		// action slot 3 ( left ) is for alt weapons
		if ( isdefined( level.usingMomentum ) && level.usingMomentum )
		{
			for ( sortIndex = 0 ; (sortIndex < sortedKillstreaks.size && sortIndex < actionSlotOrder.size) ; sortIndex++ )
			{
				if( sortedKillstreaks[sortIndex].weapon != level.weaponNone )
					self SetActionSlot( actionSlotOrder[sortIndex], "weapon", sortedKillstreaks[sortIndex].weapon );
			}
		}
}

function isPerkGroup( perkName )
{
	return ( isdefined( perkName ) && IsString( perkName ) );
}

// clears all player's custom class variables, prepare for update with new stat data
function reset_specialty_slots( class_num )
{
	self.specialty = [];		// clear all specialties
}

//------------------------------------------------------------------------------
// self = player
//------------------------------------------------------------------------------

function initStaticWeaponsTime()
{
	self.staticWeaponsStartTime = getTime();
}

function isEquipmentAllowed( equipment_name )
{
	if ( equipment_name == level.weapontacticalInsertion.name && level.disableTacInsert )
		return false;

	return true;
}

function isLeagueItemRestricted( item )
{
	if ( level.leagueMatch )
	{
		return ( IsItemRestricted( item ) );
	}

	return false;
}
							  	
function giveLoadoutLevelSpecific( team, weaponclass )	  
{
	if ( isdefined( level.giveCustomCharacters ) )
	{
		self [[level.giveCustomCharacters]]();
	}
	
	if ( isdefined( level.giveCustomLoadout ) )
	{
		self [[level.giveCustomLoadout]]();
	}
}

function giveLoadout_init( takeAllWeapons )
{
	if( takeAllWeapons )
	{
		self takeAllWeapons();	  	
	}
	
	// initialize specialty array
	self.specialty = [];
	self.killstreak = [];
	self.primaryWeaponKill = false;
	self.secondaryWeaponKill = false;	
	// reset offhand
	self.grenadeTypePrimary = level.weaponNone;
	self.grenadeTypePrimaryCount = 0;
	self.grenadeTypeSecondary = level.weaponNone;
	self.grenadeTypeSecondaryCount = 0;

				
	self notify( "give_map" );
}

function givePerks()
{
	self.specialty = self GetLoadoutPerks( self.class_num );
	
	
	// SJC: set the player state to have bonus card and primary/secondary weapon info, for codcaster to view it
	self SetPlayerStateLoadoutBonusCards( self.class_num );
	self SetPlayerStateLoadoutWeapons( self.class_num );
	
	if ( level.leagueMatch )
	{
		for ( i = 0; i < self.specialty.size; i++ )
		{
			if ( isLeagueItemRestricted( self.specialty[i] ) )
			{
				ArrayRemoveIndex( self.specialty, i );
				i--;
			}
		}
	}
	
	// re-registering perks to code since perks are cleared after respawn in case if players switch classes
	self register_perks();

	// now that perks are re-registered...
	// update player momentum taking into account anteup perk; any score less than the initial value is boosted to that value
	anteup_bonus = GetDvarInt( "perk_killstreakAnteUpResetValue" );
	momentum_at_spawn_or_game_end = VAL( self.pers["momentum_at_spawn_or_game_end"], 0 );
	hasNotDoneCombat = !( self.hasDoneCombat === true ); // fixes dev gui bot spawning in grace period
	if ( ( level.inPreMatchPeriod || ( level.inGracePeriod && hasNotDoneCombat ) ) && momentum_at_spawn_or_game_end < anteup_bonus )
	{
		new_momentum = ( self HasPerk( "specialty_anteup" ) ? anteup_bonus : momentum_at_spawn_or_game_end );
		globallogic_score::_setPlayerMomentum( self, new_momentum, false );
	}
}

function setClassNum( weaponClass )
{
	if( isSubstr( weaponclass, "CLASS_CUSTOM" ) )
	{	
		// ============= custom class selected ==============
		// gets custom class data from stat bytes
		// obtains the custom class number
		self.class_num = int( weaponclass[weaponclass.size-1] )-1;

		//hacky patch to the system since when it was written it was never thought of that there could be 10 custom slots
		if( -1 == self.class_num )
		{
			self.class_num = 9;
		}

		
		self.class_num_for_global_weapons = self.class_num;
		
		// clear of specialty slots, repopulate the current selected class' setup
		self reset_specialty_slots( self.class_num );

		playerRenderOptions = self CalcPlayerOptions( self.class_num );
		self SetPlayerRenderOptions( playerRenderOptions );	
	}
	else
	{			
		// ============= selected one of the default classes ==============
			
		// load the selected default class's specialties
		assert( isdefined(self.pers["class"]), "Player during spawn and loadout got no class!" );
		
		self.class_num = level.classToClassNum[ weaponclass ];
		self.class_num_for_global_weapons = 0;
		
		self SetPlayerRenderOptions( 0 );	
	}
	
	self recordLoadoutIndex( self.class_num );
}

function giveBaseWeapon()
{
	//TODO - add melee weapon selection to the CAC stuff and default loadouts	
	self.spawnWeapon = level.weaponBaseMeleeHeld;
	
//	/#	println( "^5Loadout " + self.name + " GiveWeapon( " + level.weaponBaseMelee.name + " ) -- level.weaponBaseMelee 0" );	#/
	knifeWeaponOptions = self CalcWeaponOptions( self.class_num, 2 );
	self GiveWeapon( level.weaponBaseMeleeHeld, knifeWeaponOptions );

	self.pers["spawnWeapon"] = self.spawnWeapon;
	
	switchImmediate = isdefined( self.alreadySetSpawnWeaponOnce );
	self setSpawnWeapon( self.spawnWeapon, switchImmediate );
	self.alreadySetSpawnWeaponOnce = true;
}

function giveWeapons()
	{
	spawnWeapon = level.weaponNull;
	initialWeaponCount = 0;
	
	// weapon override for round based gametypes
	// TODO: if they switched to a sidearm, we shouldn't give them that as their primary!
	if ( isdefined( self.pers["weapon"] ) && self.pers["weapon"] != level.weaponNone && !self.pers["weapon"].isCarriedKillstreak )
	{
		primaryWeapon = self.pers["weapon"];
	}
	else
	{
		primaryWeapon = self GetLoadoutWeapon( self.class_num, "primary" );
	}

	if( primaryWeapon.isCarriedKillstreak )
	{
		primaryWeapon = level.weaponNull;
	}

	self.pers["primaryWeapon"] = primaryWeapon;
	
	// give primary weapon
	if ( primaryWeapon != level.weaponNull )
	{
		primaryWeaponOptions = self CalcWeaponOptions( self.class_num, 0 );

//		/#	println( "^5Loadout " + self.name + " GiveWeapon( " + primaryWeapon.name + " ) -- primary" );	#/
		
		acvi = self GetAttachmentCosmeticVariantForWeapon( self.class_num, "primary" );
		self GiveWeapon( primaryWeapon, primaryWeaponOptions, acvi );
		
		self weapons::bestweapon_spawn(primaryWeapon, primaryWeaponOptions, acvi);
		
		self.primaryLoadoutWeapon = primaryWeapon;
		self.primaryLoadoutAltWeapon = primaryWeapon.altWeapon;
		self.primaryLoadoutGunSmithVariantIndex = self GetLoadoutGunSmithVariantIndex( self.class_num, 0 );
		if( self HasPerk( "specialty_extraammo" ) )
		{
			self giveMaxAmmo( primaryWeapon );
		}

		spawnWeapon = primaryWeapon;
		initialWeaponCount++;
	}
		
	// give seconday weapon
	sidearm = self GetLoadoutWeapon( self.class_num, "secondary" );

	if( sidearm.isCarriedKillstreak )
		sidearm = level.weaponNull;
	
	if( sidearm.name == "bowie_knife" )
		sidearm = level.weaponNull;

	if ( sidearm != level.weaponNull )
	{
		secondaryWeaponOptions = self CalcWeaponOptions( self.class_num, 1 );

//		/#	println( "^5Loadout " + self.name + " GiveWeapon( " + sidearm.name + " ) -- sidearm" );	#/

		acvi = self GetAttachmentCosmeticVariantForWeapon( self.class_num, "secondary" );
		self GiveWeapon( sidearm, secondaryWeaponOptions, acvi );
		self.secondaryLoadoutWeapon = sidearm;
		self.secondaryLoadoutAltWeapon = sidearm.altWeapon;
		self.secondaryLoadoutGunSmithVariantIndex = self GetLoadoutGunSmithVariantIndex( self.class_num, 1 );
		
		if ( self HasPerk( "specialty_extraammo" ) )
		{
			self giveMaxAmmo( sidearm );
		}

		if ( spawnWeapon == level.weaponNull )
		{
			spawnWeapon = sidearm;
		}
		
		initialWeaponCount++;
	}
	
	if ( !self HasMaxPrimaryWeapons() )
	{
		if ( !isUsingT7Melee() )
		{
//			/#	println( "^5Loadout " + self.name + " GiveWeapon( " + level.weaponBaseMeleeHeld.name + " ) -- level.weaponBaseMeleeHeld 1" );	#/
			knifeWeaponOptions = self CalcWeaponOptions( self.class_num, 2 );
			self GiveWeapon( level.weaponBaseMeleeHeld, knifeWeaponOptions );
		}

		if ( initialWeaponCount == 0 )
		{
			spawnWeapon = level.weaponBaseMeleeHeld;
		}
	}
	
	if ( !isdefined( self.spawnWeapon ) && isdefined( self.pers["spawnWeapon"] ) )
	{
		self.spawnWeapon = self.pers["spawnWeapon"];
	}
	
	if ( isdefined( self.spawnWeapon ) && DoesWeaponReplaceSpawnWeapon( self.spawnWeapon, spawnWeapon ) && !self.pers["changed_class"] )
	{
		spawnWeapon = self.spawnWeapon;
	}
	
	self thread loadout::initWeaponAttachments( spawnWeapon );	

	self.pers["changed_class"] = false;
	self.spawnWeapon = spawnWeapon;
	self.pers["spawnWeapon"] = self.spawnWeapon;
	
	switchImmediate = isdefined( self.alreadySetSpawnWeaponOnce );
	self setSpawnWeapon( spawnWeapon, switchImmediate );
	self.alreadySetSpawnWeaponOnce = true;

	self initStaticWeaponsTime();
	
	self bbClassChoice( self.class_num, primaryWeapon, sidearm );
}

function givePrimaryOffhand()
{
	changedClass = self.pers["changed_class"];
	roundBased = !util::isOneRound();
	firstRound = util::isFirstRound();	

	primaryOffhand = level.weaponNone;
	primaryOffhandCount = 0;

	if ( GetDvarint( "gadgetEnabled") == 1 || GetDvarint( "equipmentAsGadgets") == 1 )
	{
		primaryOffhand = self GetLoadoutWeapon( self.class_num, "primaryGadget" );
		primaryOffhandCount = primaryOffhand.startammo;
	}
	else
	{
		primaryOffhandName = self GetLoadoutItemRef( self.class_num, "primarygrenade" );				

		if ( primaryOffhandName != "" && primaryOffhandName != "weapon_null" )
		{
			primaryOffhand = GetWeapon( primaryOffhand );
			primaryOffhandCount = self GetLoadoutItem( self.class_num, "primarygrenadecount" );
		}
	}

	if ( isLeagueItemRestricted( primaryOffhand.name ) || !isEquipmentAllowed( primaryOffhand.name ) )
	{
		primaryOffhand = level.weaponNone;
		primaryOffhandCount = 0;
	}

	if ( primaryOffhand == level.weaponNone )
	{
		primaryOffhand = GetWeapon( "null_offhand_primary" );
		primaryOffhandCount = 0;
	}	

	if ( primaryOffhand != level.weaponNull )
	{
	//	/#	println( "^5Loadout " + self.name + " GiveWeapon( " + primaryOffhand.name + " ) -- primaryOffhand" );	#/

		self GiveWeapon( primaryOffhand );
		
		self SetWeaponAmmoClip( primaryOffhand, primaryOffhandCount );
		self SwitchToOffhand( primaryOffhand );
		self.grenadeTypePrimary = primaryOffhand;
		self.grenadeTypePrimaryCount = primaryOffhandCount;

		self ability_util::gadget_reset( primaryOffhand, changedClass, roundBased, firstRound );
	}
}

function giveSecondaryOffhand( )
{
	changedClass = self.pers["changed_class"];
	roundBased = !util::isOneRound();
	firstRound = util::isFirstRound();	

	secondaryOffhand = level.weaponNone;
	secondaryOffhandCount = 0;

	if ( GetDvarint( "gadgetEnabled") == 1 || GetDvarint( "equipmentAsGadgets") == 1 )
	{
		secondaryOffhand = self GetLoadoutWeapon( self.class_num, "secondaryGadget" );
		secondaryOffhandCount = secondaryOffhand.startammo;
	}
	else
	{
		secondaryOffhandName = self GetLoadoutItemRef( self.class_num, "specialgrenade" );				

		if ( secondaryOffhandName != "" && secondaryOffhandName != "weapon_null" )
		{
			secondaryOffhand = GetWeapon( secondaryOffhand );
			secondaryOffhandCount = self GetLoadoutItem( self.class_num, "specialgrenadecount" );
		}
	}

	if ( isLeagueItemRestricted( secondaryOffhand.name ) || !isEquipmentAllowed( secondaryOffhand.name ) )
	{
		secondaryOffhand = level.weaponNone;
		secondaryOffhandCount = 0;
	}

	if ( secondaryOffhand == level.weaponNone )
	{
		secondaryOffhand = GetWeapon( "null_offhand_secondary" );
		secondaryOffhandCount = 0;
	}	

	if ( secondaryOffhand != level.weaponNull )
	{
		self GiveWeapon( secondaryOffhand );
		
		self SetWeaponAmmoClip( secondaryOffhand, secondaryOffhandCount );
		self SwitchToOffhand( secondaryOffhand );
		self.grenadeTypeSecondary = secondaryOffhand;
		self.grenadeTypeSecondaryCount = secondaryOffhandCount;

		self ability_util::gadget_reset( secondaryOffhand, changedClass, roundBased, firstRound );
	}
}

function giveSpecialOffhand()
{
	changedClass = self.pers["changed_class"];
	roundBased = !util::isOneRound();
	firstRound = util::isFirstRound();	

	classNum = self.class_num_for_global_weapons;

	specialOffhand = level.weaponNone;
	specialOffhandCount = 0;
	
	specialOffhand = self GetLoadoutWeapon( self.class_num_for_global_weapons, "herogadget" );
	specialOffhandCount = specialOffhand.startammo;
	
	if ( isdefined( self.pers[#"rouletteWeapon"] ) )
	{
		assert( specialOffhand.name == "gadget_roulette" );
		specialOffhand = self.pers[#"rouletteWeapon"];
		roulette::gadget_roulette_give_earned_specialist( specialOffhand, false ) ;
	}

	if ( isLeagueItemRestricted( specialOffhand.name ) || !isEquipmentAllowed( specialOffhand.name ) )
	{
		specialOffhand = level.weaponNone;
		specialOffhandCount = 0;
	}

	if ( specialOffhand == level.weaponNone )
	{
		specialOffhand = level.weaponNull;
		specialOffhandCount = 0;
	}

	if ( specialOffhand != level.weaponNull )
	{
		self GiveWeapon( specialOffhand );
		
		self SetWeaponAmmoClip( specialOffhand, specialOffhandCount );
		self SwitchToOffhand( specialOffhand );
		self.grenadeTypeSpecial = specialOffhand;
		self.grenadeTypeSpecialCount = specialOffhandCount;

		self ability_util::gadget_reset( specialOffhand, changedClass, roundBased, firstRound );
	}
}

function giveHeroWeapon()
{
	changedClass = self.pers["changed_class"];
	roundBased = !util::isOneRound();
	firstRound = util::isFirstRound();	

	classNum = self.class_num_for_global_weapons;
	heroWeapon = level.weaponNone;
	heroWeaponName = self GetLoadoutItemRef( self.class_num_for_global_weapons, "heroWeapon" );
	
	if ( heroWeaponName != "" && heroWeaponName != "weapon_null" )
	{
		if ( heroWeaponName == "hero_minigun" )
		{
			model = self GetCharacterBodyModel();
			if ( IsDefined( model ) &&  IsSubStr(model, "body3") )
			{
				heroWeaponName = "hero_minigun_body3";
			}
		}
		
		heroWeapon = GetWeapon( heroWeaponName );		
	}
	
	if ( heroWeapon != level.weaponNone )
	{
		self.heroWeapon = heroWeapon;
		self GiveWeapon( heroWeapon );
		
		self ability_util::gadget_reset( heroWeapon, changedClass, roundBased, firstRound );
	}
}

function giveLoadout( team, weaponclass )	  
{
	if ( isdefined( level.giveCustomLoadout ) )
	{
		spawnWeapon = self [[level.giveCustomLoadout]]();
		if( isdefined( spawnWeapon ) )
		{
			self thread loadout::initWeaponAttachments( spawnWeapon );
		}
		self.spawnWeapon = spawnWeapon;
		}
		else
		{
		self giveLoadout_init( true );

		setClassNum( weaponClass );
	
		self SetActionSlot( 3, "altMode" );
		self SetActionSlot( 4, "" );
	
		allocationSpent = self GetLoadoutAllocation( self.class_num );
		overAllocation = ( allocationSpent > level.maxAllocation );
	
	
		if( !overAllocation )
		{
			//Perks must come first in case other give-functions check for perks
			givePerks();

			giveWeapons();	
			givePrimaryOffhand();
		}
		else
	{
			giveBaseWeapon();
		}
	
		giveSecondaryOffhand();
		
		if ( GetDvarint( "tu11_enableClassicMode") == 0 )
		{
			giveSpecialOffhand();
			giveHeroWeapon();
		}
		
		giveKillStreaks();
	}

	self teams::set_player_model( undefined, undefined );
	
	if( isdefined( self.movementSpeedModifier ) )
	{
		self setMoveSpeedScale( self.movementSpeedModifier * self getMoveSpeedScale() );
	}
	
	// cac specialties that require loop threads
	self cac_selector();
	
	self giveLoadout_finalize( self.spawnWeapon, self.pers["primaryWeapon"] );
}

function giveLoadout_finalize(spawnWeapon, primaryWeapon)
{
	// tagTMR<NOTE>: force first raise anim on initial spawn of match
	if ( !isdefined( self.firstSpawn ) )
	{
		if ( isdefined( spawnWeapon ) )
			self InitialWeaponRaise( spawnWeapon );
		else
			self InitialWeaponRaise( primaryWeapon );
	}	
	else
	{
		// ... and eliminate first raise anim for all other spawns
		self SetEverHadWeaponAll( true );
	}
		
	self.firstSpawn = false;
	self.switchedTeamsResetGadgets = false;

	self flagsys::set( "loadout_given" );
}

// sets the amount of ammo in the gun.
// if the clip maxs out, the rest goes into the stock.
function setWeaponAmmoOverall( weapon, amount )
{
	if ( weapon.isClipOnly )
	{
		self setWeaponAmmoClip( weapon, amount );
	}
	else
	{
		self setWeaponAmmoClip( weapon, amount );
		diff = amount - self getWeaponAmmoClip( weapon );
		assert( diff >= 0 );
		self setWeaponAmmoStock( weapon, diff );
	}
}

function on_player_connecting()
{
	if ( !isdefined( self.pers["class"] ) )
	{
		self.pers["class"] = "";
	}
	self.curClass = self.pers["class"];
	self.lastClass = "";

	self.detectExplosives = false;
	self.bombSquadIcons = [];
	self.bombSquadIds = [];	
	self.reviveIcons = [];
	self.reviveIds = [];
}


function fadeAway( waitDelay, fadeDelay )
{
	wait waitDelay;
	
	self fadeOverTime( fadeDelay );
	self.alpha = 0;
}


function setClass( newClass )
{
	self.curClass = newClass;
}

// ============================================================================================
// =======																				=======
// =======						 Create a Class Specialties 							=======
// =======																				=======
// ============================================================================================

function initPerkDvars()
{
	level.cac_armorpiercing_data = GetDvarInt( "perk_armorpiercing", 40 ) / 100;// increased bullet damage by this %
	level.cac_bulletdamage_data = GetDvarInt( "perk_bulletDamage", 35 );		// increased bullet damage by this %
	level.cac_fireproof_data = GetDvarInt( "perk_fireproof", 20 );				// reduced flame damage by this %
	level.cac_armorvest_data = GetDvarInt( "perk_armorVest", 80 );				// multipy damage by this %	
	level.cac_flakjacket_data = GetDvarInt( "perk_flakJacket", 35 );			// explosive damage is this % of original
	level.cac_flakjacket_hardcore_data = GetDvarInt( "perk_flakJacket_hardcore", 9 );	// explosive damage is this % of original for hardcore
}

// CAC: Selector function, calls the individual cac features according to player's class settings
// Info: Called every time player spawns during loadout stage
function cac_selector()
{

	self.detectExplosives = false;
	
	
	if ( IsDefined( self.specialty ) )
	{
		perks = self.specialty;
	for( i=0; i<perks.size; i++ )
	{
		perk = perks[i];
		// run scripted perk that thread loops
		if( perk == "specialty_detectexplosive" )
			self.detectExplosives = true;
	}
}
}
	
function register_perks()
{
	perks = self.specialty;
	self ClearPerks();
	for( i=0; i<perks.size; i++ )
	{
		perk = perks[i];

		// TO DO: ask code to register the inventory perks and null perk
		// not registering inventory and null perks to code
		if ( perk == "specialty_null" || isSubStr( perk, "specialty_weapon_" ) || perk == "weapon_null" )
			continue;
			
		if ( !level.perksEnabled )
			continue;

		self setPerk( perk );
	}
}

function cac_modified_vehicle_damage( victim, attacker, damage, meansofdeath, weapon, inflictor )
{
	// skip conditions
	if ( !isdefined( victim) || !isdefined( attacker ) || !isplayer( attacker ) )
		return damage;
	if ( !isdefined( damage ) || !isdefined( meansofdeath ) || !isdefined( weapon ) )
		return damage;

	old_damage = damage;
	final_damage = damage;

	// Perk version
	
	if ( attacker HasPerk( "specialty_bulletdamage" ) && isPrimaryDamage( meansofdeath ) )
	{
		final_damage = damage*(100+level.cac_bulletdamage_data)/100;
	}
	else
	{
		final_damage = old_damage;
	}	
	
	// return unchanged damage
	return int( final_damage );
}

function cac_modified_damage( victim, attacker, damage, mod, weapon, inflictor, hitloc )
{
	assert( isdefined( victim ) );
	assert( isdefined( attacker ) );
	assert( IsPlayer( victim ) );

	attacker_is_player = IsPlayer( attacker );

	if ( damage <= 0 )
	{
		return damage;
	}

	final_damage = damage;
	
	if ( victim != attacker )
	{
		if ( attacker_is_player && attacker HasPerk( "specialty_bulletdamage" ) && isPrimaryDamage( mod ) )
		{
			// if victim has armor then do not change damage, it is cancelled out, else damage is increased
			if( victim HasPerk( "specialty_armorvest" ) && !isHeadDamage( hitloc ) )
			{
			}
			else
			{
				final_damage = damage * ( 100 + level.cac_bulletdamage_data ) / 100;
			}
		}
		else if ( victim HasPerk( "specialty_armorvest" ) && isPrimaryDamage( mod ) && !isHeadDamage( hitloc ) )
		{	
			//If victim has body armor, reduce the damage by the cac armor vest value as a percentage
			final_damage = damage * ( level.cac_armorvest_data * .01 );
		}
		else if ( victim HasPerk( "specialty_fireproof" ) && isFireDamage( weapon, mod ) )
		{
			final_damage = damage  * ( level.cac_fireproof_data * .01 );
		}
		else if ( victim HasPerk( "specialty_flakjacket" ) && isExplosiveDamage( mod ) && !weapon.ignoresFlakJacket && !victim grenadeStuck( inflictor ) )
		{
			// put these back in to make FlakJacket a perk again (for easy tuning of system when not body type specfic)
			cac_data = ( level.hardcoreMode ? level.cac_flakjacket_hardcore_data : level.cac_flakjacket_data );
	
			if ( victim util::has_flak_jacket_perk_purchased_and_equipped() )
			{
			if ( level.teambased && attacker.team != victim.team )
			{
					victim thread challenges::flakjacketProtectedMP( weapon, attacker );
			}
			else if ( attacker != victim )
			{
					victim thread challenges::flakjacketProtectedMP( weapon, attacker );
				}
			}
	
			final_damage = int( damage * ( cac_data / 100 ) );
		}
	}

	final_damage = int( final_damage );

	if ( final_damage < 1 )
	{
		final_damage = 1;
	}

	return ( final_damage );
}

// including grenade launcher, grenade, bazooka, betty, satchel charge
function isExplosiveDamage( meansofdeath )
{
	switch( meansofdeath )
	{
		case "MOD_GRENADE":
		case "MOD_GRENADE_SPLASH":
		case "MOD_PROJECTILE":
		case "MOD_PROJECTILE_SPLASH":
		case "MOD_EXPLOSIVE":
			return true;
	}

	return false;
}

function hasTacticalMask( player )
{
	return ( player HasPerk( "specialty_stunprotection" ) || player HasPerk( "specialty_flashprotection" ) || player HasPerk( "specialty_proximityprotection" ) );
}

// if primary weapon damage
function isPrimaryDamage( meansofdeath )
{
	return( meansofdeath == "MOD_RIFLE_BULLET" || meansofdeath == "MOD_PISTOL_BULLET" );
}

function isBulletDamage( meansofdeath )
{
	return( meansofdeath == "MOD_RIFLE_BULLET" || meansofdeath == "MOD_PISTOL_BULLET" || meansofdeath == "MOD_HEAD_SHOT" );
}

function isFMJDamage( sWeapon, sMeansOfDeath, attacker )
{
	// The Bullet Penetration perk comes from the fmj attachment in the attachmentTable.csv or from the weapon in statstable.csv
	return IsDefined( attacker ) && IsPlayer( attacker ) && attacker HasPerk( "specialty_armorpiercing" ) && IsDefined( sMeansOfDeath ) && isBulletDamage( sMeansOfDeath );
}

function isFireDamage( weapon, meansofdeath )
{
	if ( weapon.doesFireDamage && (meansofdeath == "MOD_BURNED" || meansofdeath == "MOD_GRENADE" || meansofdeath == "MOD_GRENADE_SPLASH") )
		return true;

	return false;
}

function isHeadDamage( hitloc )
{
	return ( hitloc == "helmet" || hitloc == "head" || hitloc == "neck" );
}

function grenadeStuck( inflictor )
{
	return ( isdefined( inflictor ) && isdefined( inflictor.stucktoplayer ) && inflictor.stucktoplayer == self );
}
