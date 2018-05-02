#using scripts\codescripts\struct;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\hud_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\weapons\_weapons;

#using scripts\mp\_teamops;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_battlechatter;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_hud_message;
#using scripts\mp\gametypes\_loadout;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_ai_tank;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_combat_robot;
#using scripts\mp\killstreaks\_counteruav;
#using scripts\mp\killstreaks\_dart;
#using scripts\mp\killstreaks\_dogs;
#using scripts\mp\killstreaks\_drone_strike;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_flak_drone;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_helicopter_gunner;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_microwave_turret;
#using scripts\mp\killstreaks\_planemortar;
#using scripts\mp\killstreaks\_qrdrone;
#using scripts\mp\killstreaks\_raps;
#using scripts\mp\killstreaks\_rcbomb;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\killstreaks\_remotemissile;
#using scripts\mp\killstreaks\_satellite;
#using scripts\mp\killstreaks\_sentinel;
#using scripts\mp\killstreaks\_supplydrop;
#using scripts\mp\killstreaks\_turret;
#using scripts\mp\killstreaks\_uav;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\statstable_shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#define TAACOM_KILLSTREAK_READY_WAIT 2.4
	
#precache( "string", "MP_KILLSTREAK_N" );	

#namespace killstreaks;

REGISTER_SYSTEM( "killstreaks", &__init__, undefined )
	
function __init__()
{
	level.killstreaks = [];
	level.killstreakWeapons = [];
	level.dropLocations = [];
	level.zOffsetCounter = 0;
	
	clientfield::register( "vehicle", "timeout_beep", VERSION_SHIP, 2, "int" );
	
	callback::on_start_gametype( &init );
}	
	
function init()
{
	if ( GetDvarString( "scr_allow_killstreak_building") == "" )
	{
		SetDvar( "scr_allow_killstreak_building", "0" );
	}	
	
	level.menuReferenceForKillStreak = [];
	level.numKillstreakReservedObjectives = 0;
	level.killstreakCounter = 0;
	level.play_killstreak_firewall_being_hacked_dialog = &play_killstreak_firewall_being_hacked_dialog;
	level.play_killstreak_firewall_hacked_dialog = &play_killstreak_firewall_hacked_dialog;
	level.play_killstreak_being_hacked_dialog = &play_killstreak_being_hacked_dialog;
	level.play_killstreak_hacked_dialog = &play_killstreak_hacked_dialog;
	
	if( !isdefined(level.roundStartKillstreakDelay) )
	{
		level.roundStartKillstreakDelay = 0;
	}
	
	level.isKillstreakWeapon =&killstreaks::is_killstreak_weapon;
	
	level.killstreakCoreBundle = struct::get_script_bundle( "killstreak", "killstreak_core" );

	remote_weapons::init();
	
	ai_tank::init();
	airsupport::init();
	combat_robot::init();
	counteruav::init();
	dart::init();
	drone_strike::init();	
	emp::init();
	flak_drone::init();
	helicopter::init();
	helicopter_gunner::init();
	killstreakrules::init();
	microwave_turret::init();
	planemortar::init();
	qrdrone::init();
	raps_mp::init();
	rcbomb::init();
	remotemissile::init();
	satellite::init();
	sentinel::init();
	turret::init();
	uav::init();
	
	supplydrop::init();

	callback::on_spawned( &on_player_spawned );
	callback::on_joined_team( &on_joined_team );

	if( GetDvarint( "teamOpsEnabled" ) == 1 )
	{
		level teamops::main();
	}
}

function register( killstreakType, 			// killstreak name	
				   killstreakWeaponName, 	// weapon name associated with deploying this killstreak
				   killstreakMenuName,		// killstreak name from the cac loadout (could be merged with the type name)
				   killstreakUsageKey,		// variable that shows the usage for the killstreak ( could be merged with type name )
				   killstreakUseFunction,	// function that gets called when the killstreak gets activated	
				   killstreakDelayStreak,	// weather or not to delay the killstreak at round start
				   weaponHoldAllowed = false,		// if this killstreak weapon can be held by the player, as opposed to activate and remove (i.e. UAV)
				   killstreakStatsName = undefined,		// Stats name for killstreak weapons (optional)
				   registerDvars = true,
				   registerInventory = true )
{
	assert( isdefined(killstreakType), "Can not register a killstreak without a valid type name.");
	assert( !isdefined(level.killstreaks[killstreakType]), "Killstreak " + killstreakType + " already registered");
	assert( isdefined(killstreakUseFunction), "No use function defined for killstreak " + killstreakType);
		
	level.killstreaks[killstreakType] = SpawnStruct();
	
	statsTableName = util::getStatsTableName();

	// number of kills required to achieve killstreak
	level.killstreaks[killstreakType].killstreakLevel = int( tablelookup( statsTableName, STATS_TABLE_COL_REFERENCE, killstreakMenuName, STATS_TABLE_COL_COUNT ) );
	level.killstreaks[killstreakType].momentumCost = int( tablelookup( statsTableName, STATS_TABLE_COL_REFERENCE, killstreakMenuName, STATS_TABLE_COL_MOMENTUM ) );
	level.killstreaks[killstreakType].iconMaterial = tablelookup( statsTableName, STATS_TABLE_COL_REFERENCE, killstreakMenuName, STATS_TABLE_COL_IMAGE );
	level.killstreaks[killstreakType].quantity = int( tablelookup( statsTableName, STATS_TABLE_COL_REFERENCE, killstreakMenuName, STATS_TABLE_COL_COUNT ) );
	level.killstreaks[killstreakType].usageKey = killstreakUsageKey;
	level.killstreaks[killstreakType].useFunction = killstreakUseFunction;
	level.killstreaks[killstreakType].menuName = killstreakMenuName; 
	level.killstreaks[killstreakType].delayStreak = killstreakDelayStreak; 
	level.killstreaks[killstreakType].allowAssists = false;
	level.killstreaks[killstreakType].overrideEntityCameraInDemo = false;
	level.killstreaks[killstreakType].teamKillPenaltyScale = 1.0;

	if ( isdefined( killstreakWeaponName ) )
	{
		killstreakWeapon = GetWeapon( killstreakWeaponName );
		assert( killstreakWeapon != level.weaponNone );
		assert( !isdefined(level.killstreakWeapons[killstreakWeapon]), "Can not have a weapon associated with multiple killstreaks.");
		level.killstreaks[killstreakType].weapon = killstreakWeapon;
		level.killstreakWeapons[killstreakWeapon] = killstreakType;
	}

	if( isdefined( killstreakStatsName ) )
	{
		level.killstreaks[killstreakType].killstreakStatsName = killstreakStatsName;
	}

	level.killstreaks[killstreakType].weaponHoldAllowed = weaponHoldAllowed;

	if( IS_TRUE( registerInventory ) )
	{
		level.menuReferenceForKillStreak[killstreakMenuName] = killstreakType;
		killstreak_bundles::register_killstreak_bundle( killstreakType );
	}
	
	if( IS_TRUE( registerInventory ) )
	{
		if( IS_TRUE( registerDvars ) )
			register_dev_dvars( killstreakType );
		
		register( "inventory_" +  killstreakType,
				  "inventory_" +  killstreakWeaponName,
				   killstreakMenuName,
				   killstreakUsageKey,
				   killstreakUseFunction,
				   killstreakDelayStreak,
				   weaponHoldAllowed,
				   killstreakStatsName,
				   registerDvars,
				   false );
	}
}

function is_registered(killstreakType)
{
	return isdefined(level.killstreaks[killstreakType]);
}

function register_strings( killstreakType, receivedText, notUsableText, inboundText, inboundNearPlayerText, hackedText, utilizesAirspace = true, isInventory = false ) 
{
	assert( isdefined(killstreakType), "Can not register a killstreak without a valid type name.");
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak needs to be registered before calling register_strings.");
	
	level.killstreaks[killstreakType].receivedText = receivedText;
	level.killstreaks[killstreakType].notAvailableText = notUsableText;
	level.killstreaks[killstreakType].inboundText = inboundText;
	level.killstreaks[killstreakType].inboundNearPlayerText = inboundNearPlayerText;
	level.killstreaks[killstreakType].hackedText = hackedText;
	level.killstreaks[killstreakType].utilizesAirspace = utilizesAirspace; // does the killstreak utilize airspace when deployed or while active?
	
	if( !IS_TRUE( isInventory ) )
		register_strings( "inventory_" + killstreakType, receivedText, notUsableText, inboundText, inboundNearPlayerText, hackedText, utilizesAirspace, true );
}

function register_dialog( 
							killstreakType,
							informDialog,
							taacomDialogBundleKey,
							pilotDialogArrayKey,
							startDialogKey, 				// Commander
							enemyStartDialogKey,			// Commander
							enemyStartMultipleDialogKey,	// Commander							
							hackedDialogKey,				// Commander
							hackedStartDialogKey,			// Commander				
							requestDialogKey,		// Player
							threatDialogKey,		// Player
							isInventory
						)
{
	assert( isdefined(killstreakType), "Can not register a killstreak without a valid type name.");
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak needs to be registered before calling register_dialog.");

	level.killstreaks[killstreakType].informDialog = informDialog;
	
	level.killstreaks[killstreakType].taacomDialogBundleKey = taacomDialogBundleKey;
	
	level.killstreaks[killstreakType].startDialogKey = startDialogKey;
	level.killstreaks[killstreakType].enemyStartDialogKey = enemyStartDialogKey;
	level.killstreaks[killstreakType].enemyStartMultipleDialogKey = enemyStartMultipleDialogKey;
	
	level.killstreaks[killstreakType].hackedDialogKey = hackedDialogKey;
	level.killstreaks[killstreakType].hackedStartDialogKey = hackedStartDialogKey;
	
	level.killstreaks[killstreakType].requestDialogKey = requestDialogKey;
	level.killstreaks[killstreakType].threatDialogKey = threatDialogKey;
	
	if ( isdefined( pilotDialogarrayKey ) )
	{
		// Set up Pilot Dialog Arrays
		taacomBundles = struct::get_script_bundles( "mpdialog_taacom" );
		
		foreach ( bundle in taacomBundles )
		{
			if ( !isdefined( bundle.pilotBundles ) )
			{
				bundle.pilotBundles = [];
			}
			
			bundle.pilotBundles[killstreakType] = [];
		
			i = 0;
			field = pilotDialogArrayKey + i;
			fieldValue = GetStructField( bundle, field );
			
			while ( isdefined( fieldValue ) )
			{
				bundle.pilotBundles[killstreakType][i] = fieldValue;
				
				i++;
				field = pilotDialogArrayKey + i;
				fieldValue = GetStructField( bundle, field );
			}
		}
	}
	
	if( !IS_TRUE( isInventory ) )
		register_dialog( 
							"inventory_" + killstreakType,
							informDialog,
							taacomDialogBundleKey,
							pilotDialogArrayKey,
							startDialogKey,
							enemyStartDialogKey,
							enemyStartMultipleDialogKey,
							hackedDialogKey,
							hackedStartDialogKey,
							requestDialogKey,
							threatDialogKey,
							true );
		
}

// additional weapons associated with this killstreak
function register_alt_weapon( killstreakType, weaponName, isInventory )
{
	assert( isdefined(killstreakType), "Can not register a killstreak without a valid type name.");
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak needs to be registered before calling register_alt_weapon.");

	weapon = GetWeapon( weaponName );
	
	if( weapon == level.weaponNone )
		return;
	
	if ( level.killstreaks[killstreakType].weapon == weapon )
	{
		return;
	}

	if ( !isdefined( level.killstreaks[killstreakType].altWeapons ) )
	{
		level.killstreaks[killstreakType].altWeapons = [];
	}

	if( !isdefined( level.killstreakWeapons[weapon] ) )
	{
		level.killstreakWeapons[weapon] = killstreakType;
	}
	level.killstreaks[killstreakType].altWeapons[level.killstreaks[killstreakType].altWeapons.size] = weapon;
	
	if( !IS_TRUE( isInventory ) )
		register_alt_weapon( "inventory_" + killstreakType, weaponName, true );
}

// remote override weapons associated with this killstreak
function register_remote_override_weapon( killstreakType, weaponName, isInventory )
{
	assert( isdefined(killstreakType), "Can not register a killstreak without a valid type name.");
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak needs to be registered before calling register_remote_override_weapon.");

	weapon = GetWeapon( weaponName );
	if ( level.killstreaks[killstreakType].weapon == weapon )
	{
		return;
	}
		
	if ( !isdefined( level.killstreaks[killstreakType].remoteOverrideWeapons ) )
	{
		level.killstreaks[killstreakType].remoteOverrideWeapons = [];
	}

	if( !isdefined( level.killstreakWeapons[weapon] ) )
	{
		level.killstreakWeapons[weapon] = killstreakType;
	}
	level.killstreaks[killstreakType].remoteOverrideWeapons[level.killstreaks[killstreakType].remoteOverrideWeapons.size] = weapon;
	
	if( !IS_TRUE( isInventory ) )
		register_remote_override_weapon( "inventory_" + killstreakType, weaponName, true );
}

function is_remote_override_weapon( killstreakType, weapon )
{
	if ( isdefined( level.killstreaks[killstreakType].remoteOverrideWeapons ) )
	{
		for ( i=0; i<level.killstreaks[killstreakType].remoteOverrideWeapons.size; i++)
		{
			if ( level.killstreaks[killstreakType].remoteOverrideWeapons[i] == weapon)
			{
				return true;	
			}
		}
	}
	return false;
}

function register_dev_dvars( killstreakType )
{
}

function register_tos_dvar(dvar)
{
	level.teamops_dvar = dvar;
}

function allow_assists( killstreakType, allow )
{
	level.killstreaks[killstreakType].allowAssists = allow;	
}

function set_team_kill_penalty_scale( killstreakType, scale, isInventory )
{
	level.killstreaks[killstreakType].teamKillPenaltyScale = scale;	
	if( !IS_TRUE( isInventory ) )
		set_team_kill_penalty_scale( "inventory_" + killstreakType, scale, true );
}

function override_entity_camera_in_demo( killstreakType, value, isInventory )
{
	level.killstreaks[killstreakType].overrideEntityCameraInDemo = value;
	if( !IS_TRUE( isInventory ) )
		override_entity_camera_in_demo( "inventory_" + killstreakType, value, true );
}

function is_available( killstreak )
{
	if ( isdefined( level.menuReferenceForKillStreak[killstreak] ) )
	{
		return true;
	}
	else
	{
		return false;
	}
}

function get_by_menu_name( killstreak )
{
	return level.menuReferenceForKillStreak[killstreak];
}

function get_menu_name( killstreakType )
{
	Assert( isdefined(level.killstreaks[killstreakType] ) );
	return level.killstreaks[killstreakType].menuName;
}

function get_level( index, killstreak )
{
	killstreakLevel = level.killstreaks[ get_by_menu_name( killstreak ) ].killstreakLevel;
	if( GetDvarInt( "custom_killstreak_mode" ) == 2 )
	{
		if ( isdefined( self.killstreak[ index ] ) && ( killstreak == self.killstreak[ index ] ) )
		{
			killsRequired = GetDvarInt( "custom_killstreak_" + index + 1 + "_kills" );
			if ( killsRequired )
			{
				killstreakLevel = GetDvarInt( "custom_killstreak_" + index + 1 + "_kills" );
			}
		}
	}
	return killstreakLevel;
}

function give_if_streak_count_matches( index, killstreak, streakCount )
{
	if( self.pers["killstreaksEarnedThisKillstreak"] > index && util::isRoundBased() )
	{
		hasAlreadyEarnedKillstreak = true;
	}
	else
	{
		hasAlreadyEarnedKillstreak = false;
	}

	if ( isdefined( killstreak ) && is_available(killstreak) && !hasAlreadyEarnedKillstreak )
	{
		killstreakLevel = get_level( index, killstreak );

		if ( self HasPerk( "specialty_killstreak" ) )
		{
			reduction = GetDvarint( "perk_killstreakReduction" );
			killstreakLevel -= reduction;

			// a fix for custom game types being able to adjust the killstreak reduction perk
			if( killstreakLevel <= 0 )
			{
				killstreakLevel = 1;
			}
		}
		
		if ( killstreakLevel == streakCount )
		{
			self give( get_by_menu_name( killstreak ), streakCount );
			self.pers["killstreaksEarnedThisKillstreak"] = index + 1;
			return true;
		}
	}

	return false;
}

//Self is the player. This function looks at the player current killstreak and decides if he should be award a killstreak reward.
//It also manages the prompt that appears when the player  gets killstreaks at intervals of 5 kills once they reach 10 kills. -Leif
function give_for_streak()
{
	if ( !util::isKillStreaksEnabled() )
	{
		return;
	}

	//Equals total kills within one life
	if( !isdefined(self.pers["totalKillstreakCount"]) )
	{
		self.pers["totalKillstreakCount"] = 0;
	}
	
	// send the running tally to see what kill streak we should get
	given = false;
	
	for ( i = 0; i < self.killstreak.size; i++ )
	{
		given |= give_if_streak_count_matches( i, self.killstreak[i], self.pers["cur_kill_streak"] );
	}
}

function is_an_a_killstreak()
{
	onKillstreak = false;
	if( !isdefined( self.pers["kill_streak_before_death"] ) )
	{
		self.pers["kill_streak_before_death"] = 0;
	}
	
	streakPlusOne = self.pers["kill_streak_before_death"] + 1;
	
	if ( self.pers["kill_streak_before_death"] >= 5 ) 
	{
		onKillstreak = true;
	}


	return onKillstreak;
}

function give( killstreakType, streak, suppressNotification, noXP, toBottom )
{
	self endon("disconnect");
	level endon( "game_ended" );
	
	had_to_delay = false;
	
	killstreakGiven = false;
	if( isdefined( noXP ) )
	{
		if ( self give_internal( killstreakType, undefined, noXP, toBottom ) )
		{
			killstreakGiven = true;
			if ( self.just_given_new_inventory_killstreak === true )
			{
				self add_to_notification_queue( level.killstreaks[killstreakType].menuname, streak, killstreakType, noXP );
			}
		}
	}
	else if ( self give_internal( killstreakType, noXP ) )
	{
		killstreakGiven = true;
		if ( self.just_given_new_inventory_killstreak === true )
		{
			self add_to_notification_queue( level.killstreaks[killstreakType].menuname, streak, killstreakType, noXP );
		}
	}
}

function take( killstreak )
{
	self endon( "disconnect" );
	
	killstreak_weapon = get_killstreak_weapon( killstreak );
	remove_used_killstreak( killstreak );
	
	if ( self GetInventoryWeapon() == killstreak_weapon )
	{
		self SetInventoryWeapon( level.weaponNone );
	}

	waittillframeend;
	
	currentWeapon = self GetCurrentWeapon();
	if( currentWeapon != killstreak_weapon || killstreak_weapon.isCarriedKillstreak )
	{ 
		return;
	}
	
	killstreaks::switch_to_last_non_killstreak_weapon();
	activate_next();
}

function remove_oldest()
{
	if( isdefined( self.pers["killstreaks"][0] ) )
	{
		currentWeapon = self getCurrentWeapon();

		if( currentWeapon == get_killstreak_weapon( self.pers["killstreaks"][0] ) )
		{
			primaries = self GetWeaponsListPrimaries();

			if( primaries.size > 0 )
			{
				self SwitchToWeapon( primaries[0] );
			}
		}

		self notify("oldest_killstreak_removed", self.pers["killstreaks"][0], self.pers["killstreak_unique_id"][0] ); 
		self remove_used_killstreak( self.pers["killstreaks"][0], self.pers["killstreak_unique_id"][0], false );
	}
}

function give_internal( killstreakType, do_not_update_death_count, noXP, toBottom )
{
	self.just_given_new_inventory_killstreak = undefined;

	if ( level.gameEnded )
	{
		return false;
	}
		
	if ( !util::isKillStreaksEnabled() )
	{
		return false;
	}
		
	if ( !isdefined( level.killstreaks[killstreakType] ) )
	{
		return false;
	}

	if ( !isdefined( self.pers["killstreaks"] ) )
	{
		self.pers["killstreaks"] = [];
	}
	if( !isdefined( self.pers["killstreak_has_been_used"] ) )
	{
		self.pers["killstreak_has_been_used"] = [];
	}
	if( !isdefined( self.pers["killstreak_unique_id"] ) )
	{
		self.pers["killstreak_unique_id"] = [];
	}
	if( !isdefined( self.pers["killstreak_ammo_count"] ) )
	{
		self.pers["killstreak_ammo_count"] = [];
	}
	
	just_max_stack_removed_inventory_killstreak = undefined;

	if( isdefined( toBottom ) && toBottom )
	{
		size = self.pers["killstreaks"].size;
		
		if( self.pers["killstreaks"].size >= level.maxInventoryScoreStreaks )
		{
			self remove_oldest();
			just_max_stack_removed_inventory_killstreak = self.just_removed_used_killstreak;
		}		
		
		for( i = size; i > 0; i-- )
		{
			self.pers["killstreaks"][i] = self.pers["killstreaks"][i - 1];
			self.pers["killstreak_has_been_used"][i] = self.pers["killstreak_has_been_used"][i - 1];
			self.pers["killstreak_unique_id"][i] = self.pers["killstreak_unique_id"][i - 1];
			self.pers["killstreak_ammo_count"][i] = self.pers["killstreak_ammo_count"][i - 1];
		}
		self.pers["killstreaks"][0] = killstreakType;
		self.pers["killstreak_unique_id"][0] = level.killstreakCounter;
		level.killstreakCounter++;
		
		if( isdefined(noXP) )
		{
			self.pers["killstreak_has_been_used"][0] = noXP;
		}
		else
		{
			self.pers["killstreak_has_been_used"][0] = false;
		}
		
		
		if( size == 0 )
		{
			weapon = get_killstreak_weapon( killstreakType );
			ammoCount = give_weapon( weapon, true );
		}
	
		self.pers["killstreak_ammo_count"][0] = 0;
	}
	else
	{
		self.pers["killstreaks"][self.pers["killstreaks"].size] = killstreakType;
		self.pers["killstreak_unique_id"][self.pers["killstreak_unique_id"].size] = level.killstreakCounter;
		level.killstreakCounter++;
	
		if( self.pers["killstreaks"].size > level.maxInventoryScoreStreaks )
		{
			self remove_oldest();
			just_max_stack_removed_inventory_killstreak = self.just_removed_used_killstreak;
		}
		
		if( isdefined(noXP) )
		{
			self.pers["killstreak_has_been_used"][self.pers["killstreak_has_been_used"].size] = noXP;
		}
		else
		{
			self.pers["killstreak_has_been_used"][self.pers["killstreak_has_been_used"].size] = false;
		}
		
		weapon = get_killstreak_weapon( killstreakType );
		
		ammoCount = give_weapon( weapon, true );
	
		self.pers["killstreak_ammo_count"][self.pers["killstreak_ammo_count"].size] = ammoCount;
	}

	self.just_given_new_inventory_killstreak = ( killstreakType !== just_max_stack_removed_inventory_killstreak );

	return true;
}

function add_to_notification_queue( menuName, streakCount, hardpointType, noNotify )
{
	killstreakTableNumber = level.killStreakIndices[ menuName ];

	if ( !isdefined( killstreakTableNumber ) )
	{
		return;
	}
	
	if( isdefined( noNotify ) && noNotify )
	{
		return;
	}

	informDialog = get_killstreak_inform_dialog( hardpointType );
	
	if( GetDvarInt( "teamOpsEnabled" ) == 0 )
	{	
		self thread play_killstreak_ready_dialog( hardpointType, TAACOM_KILLSTREAK_READY_WAIT );
		self thread play_killstreak_ready_sfx ( hardpointType );
		self LUINotifyEvent( &"killstreak_received", 2, killstreakTableNumber, istring( informDialog ) );
		self LUINotifyEventToSpectators( &"killstreak_received", 2, killstreakTableNumber, istring( informDialog ) );
	}
	
}


function has_equipped( )
{
	currentWeapon = self getCurrentWeapon();

	keys = getarraykeys( level.killstreaks );
	for ( i = 0; i < keys.size; i++ )
	{
		if ( level.killstreaks[keys[i]].weapon == currentWeapon )
		{
			return true;
		}
	}

	return false;
}

function _get_from_weapon( weapon ) 
{
	keys = getarraykeys( level.killstreaks );

	foreach( key in keys )
	{
		killstreak = level.killstreaks[ key ];
		
		if ( killstreak.weapon == weapon )
		{
			return key;
		}
		
		if ( isdefined( killstreak.altweapons ) )
		{
			foreach( altweapon in killstreak.altweapons )
			{
				if ( altweapon == weapon ) 
				{
					return key;
				}
			}
		}
			
		if ( isdefined( killstreak.remoteoverrideweapons ) )
		{
			foreach( remoteOverrideWeapon in killstreak.remoteoverrideweapons )
			{
				if( remoteOverrideWeapon == weapon )
				{
					return key;
				}
			}	
		}
	}

	return undefined;
}


function get_from_weapon( weapon ) 
{
	if( weapon == level.weaponNone )
	{
		return undefined;
	}
	
	res = _get_from_weapon( weapon );
	if( !isdefined( res ) )
		return _get_from_weapon( weapon.rootweapon );
	else
		return res;
}

// dont need the isinventory it will be inventory they all are
function give_weapon( weapon, isinventory, useStoredAmmo )
{	
	currentWeapon = self GetCurrentWeapon();
	
	if ( currentWeapon != level.weaponNone && !IS_TRUE( level.usingMomentum ) )
	{
		weaponsList = self GetWeaponsList();
		for( idx = 0; idx < weaponsList.size; idx++ )
		{
		 	carriedWeapon = weaponsList[idx];
		 	
		 	if ( currentWeapon == carriedWeapon )
		 	{
		 		continue;
		 	}

			// special case weapons that are killstreak weapons but shouldn't be taken from the player
			switch ( carriedWeapon.name )
			{
			case "minigun":
			case "m32":
				continue;
			}
		 		
			if ( killstreaks::is_killstreak_weapon( carriedWeapon ) )
		 	{
		 		self TakeWeapon( carriedWeapon );
		 	}
		}
	}
	
	// take the weapon in-case we already have it.  
	// otherwise giveweapon will not give the weapon or ammo
	if( currentWeapon != weapon && ( self hasWeapon(weapon) == false ) )
	{
		self TakeWeapon( weapon );
		self GiveWeapon( weapon );
	}
	
	if ( IS_TRUE( level.usingMomentum ) )
	{
		self SetInventoryWeapon( weapon );

		if( weapon.isCarriedKillstreak )
		{
			if( !isdefined( self.pers["held_killstreak_ammo_count"][weapon] ) )
			{
				self.pers["held_killstreak_ammo_count"][weapon] = 0;
			}

			if( !isdefined( self.pers["held_killstreak_clip_count"][weapon] ) )
			{
				self.pers["held_killstreak_clip_count"][weapon] = weapon.clipSize;
			}

			if( !isdefined( self.pers["killstreak_quantity"][weapon] ) )
			{
				self.pers["killstreak_quantity"][weapon] = 0;
			}

			if( currentWeapon == weapon && !killstreaks::isHeldInventoryKillstreakWeapon( weapon ) )
			{
				return weapon.maxAmmo;
			}
			else if( IS_TRUE( useStoredAmmo ) && self.pers["killstreak_ammo_count"][self.pers["killstreak_ammo_count"].size - 1] > 0 )
			{
				switch( weapon.name )
				{
				case "inventory_minigun":
					if( IS_TRUE( self.minigunActive ) )
					{
						return self.pers["held_killstreak_ammo_count"][weapon];
					}
					break;
				case "inventory_m32":
					if( IS_TRUE( self.m32Active ) )
					{
						return self.pers["held_killstreak_ammo_count"][weapon];
					}
					break;
				default:
					break;
				}
				self.pers["held_killstreak_ammo_count"][weapon] = self.pers["killstreak_ammo_count"][self.pers["killstreak_ammo_count"].size - 1];
				self loadout::setWeaponAmmoOverall( weapon, self.pers["killstreak_ammo_count"][self.pers["killstreak_ammo_count"].size - 1] );
			}
			else
			{
				self.pers["held_killstreak_ammo_count"][weapon] = weapon.maxAmmo;
				self.pers["held_killstreak_clip_count"][weapon] = weapon.clipSize;
				self loadout::setWeaponAmmoOverall( weapon, self.pers["held_killstreak_ammo_count"][weapon] );
			}
			return self.pers["held_killstreak_ammo_count"][weapon];
		}
		else
		{
			switch ( weapon.name )
			{
			case "inventory_minigun_drop":
			case "inventory_m32_drop":
			case "inventory_missile_drone":
					
			case "combat_robot_marker":
			case "inventory_combat_robot_marker":
					
			case "dart":
			case "inventory_dart":
					
			case "ai_tank_marker":
			case "inventory_ai_tank_marker":
					
			case "supplydrop_marker":
			case "inventory_supplydrop_marker":
				delta = 1;
				break;
			default:
				delta = 0;
				break;
			}
		
			return change_killstreak_quantity( weapon, delta );	
		}
	}
	else
	{
		self setActionSlot( 4, "weapon", weapon );
		return 1;
	}
}

function activate_next( do_not_update_death_count )
{
	if ( level.gameEnded )
	{
		return false;
	}

	if ( IS_TRUE( level.usingMomentum ) )
	{
		self SetInventoryWeapon( level.weaponNone );
	}
	else
	{
		self setActionSlot( 4, "" );
	}

 	if ( !isdefined( self.pers["killstreaks"] ) || self.pers["killstreaks"].size == 0 )
 	{
 		return false;
 	}
 	
	killstreakType = self.pers["killstreaks"][self.pers["killstreaks"].size - 1];

	if ( !isdefined( level.killstreaks[killstreakType] ) )
	{
		return false;
	}
	
	weapon = level.killstreaks[killstreakType].weapon;
	WAIT_SERVER_FRAME;
	
	ammoCount = give_weapon( weapon, false, true );

	//Set the ammo now so we don't get a flash on the HUD when we use this weapon later
	if( weapon.isCarriedKillstreak )
	{
		self setWeaponAmmoClip( weapon, self.pers["held_killstreak_clip_count"][weapon] );
		self setWeaponAmmoStock( weapon, ammoCount - self.pers["held_killstreak_clip_count"][weapon] );
	}

	if ( !isdefined( do_not_update_death_count ) || do_not_update_death_count != false )
	{
		self.pers["killstreakItemDeathCount"+killstreakType] = self.deathCount;
	}	
	
	return true;
}

function give_owned()
{
	if ( isdefined( self.pers["killstreaks"] ) && self.pers["killstreaks"].size > 0 )
	{
		self activate_next( false );
	}
}

function get_killstreak_quantity( killstreakWeapon )
{
	return VAL( self.pers["killstreak_quantity"][killstreakWeapon], 0 );
}

function change_killstreak_quantity( killstreakWeapon, delta )
{
	quantity = get_killstreak_quantity( killstreakWeapon );
	
	previousQuantity = quantity;
	quantity += delta;

	if ( quantity > level.scoreStreaksMaxStacking )
	{
		quantity = level.scoreStreaksMaxStacking;
	}
	
	// take the weapon in-case we already have it.  
	// otherwise giveweapon will not give the weapon or ammo
	if(self hasWeapon( killstreakWeapon ) == false )
	{
		self TakeWeapon( killstreakWeapon );
		self GiveWeapon( killstreakWeapon );
		self SetEverHadWeaponAll( true );
	}

	self.pers["killstreak_quantity"][killstreakWeapon] = quantity;
	self SetWeaponAmmoClip( killstreakWeapon, quantity );
	return quantity;
}

function has_killstreak_in_class( killstreakMenuName )
{
	foreach ( equippedKillstreak in self.killstreak )
	{
		if ( equippedKillstreak == killstreakMenuName )
		{
			return true;
		}
	}
	return false;
}

function has_killstreak( killstreak )
{
	player = self;
	
	if( !isdefined( killstreak ) || !isdefined( player.pers["killstreaks"] ) )
		return false;
		
	for( i = 0; i < self.pers["killstreaks"].size; i++ )
	{
		if( player.pers["killstreaks"][i] == killstreak )
			return true;
	}
	return false;
}

function RecordKillstreakBeginDirect(recordStreakIndex)
{
	player = self;
	if(!isPlayer(player) || !isDefined(recordstreakindex))
	{
		return;
	}
	
	if( !isdefined(self.killstreakEvents) )
		player.killstreakEvents = associativeArray();
	
	// Already defined means the End happened first, so lets call both start and end.
	// Note that in this case, the killstreakEvents is storing the number of kills
	if(isDefined(self.killstreakEvents[recordStreakIndex]))
	{
		kills = player.killstreakEvents[recordStreakIndex];
		eventIndex = player RecordKillStreakEvent( recordStreakIndex );
		player killstreakrules::RecordKillstreakEndDirect(eventIndex, recordStreakIndex, kills);
		
		player.killstreakEvents[recordStreakIndex] = undefined;
	}
	else
	{
		// Should be called in correct order
		eventIndex = player RecordKillStreakEvent( recordStreakIndex );
		player.killstreakEvents[recordStreakIndex] = eventIndex;
	}
}

function remove_when_done( killstreak, hasKillstreakBeenUsed, isFromInventory )
{
	self endon( "disconnect" );
	
	continue_wait = true;
	
	while( continue_wait )
	{
		self waittill( "killstreak_done", successful, killstreakType );
		
		if ( killstreakType == killstreak )
			continue_wait = false;
	}
	
	if ( successful )
	{	
		// good place to hook into killstreak usage
		killstreak_weapon = get_killstreak_weapon( killstreak );
		recordStreakIndex = undefined;
		if( isdefined( level.killstreaks[killstreak].menuname ) )
		{
			recordStreakIndex = level.killstreakindices[level.killstreaks[killstreak].menuname];
			self RecordKillstreakBeginDirect(recordStreakIndex);
		}
		
		if ( IS_TRUE( level.usingScoreStreaks ) )
		{
			if ( IS_TRUE( isFromInventory ) )
			{
				remove_used_killstreak( killstreak );
				if ( self GetInventoryWeapon() == killstreak_weapon )
				{
					self SetInventoryWeapon( level.weaponNone );
				}
			}
			else
			{
				self change_killstreak_quantity( killstreak_weapon, -1 );
			}
		}
		else if ( IS_TRUE( level.usingMomentum ) )
		{
			if ( IS_TRUE( isFromInventory ) && ( self GetInventoryWeapon() == killstreak_weapon ) )
			{
				remove_used_killstreak( killstreak );
				self SetInventoryWeapon( level.weaponNone );
			}
			else
			{
				globallogic_score::_setPlayerMomentum( self, self.momentum - level.killstreaks[killstreakType].momentumCost );
			}
		}
		else
		{
			remove_used_killstreak( killstreak );
		}

		if ( !IS_TRUE( level.usingMomentum ) )
		{
			self setActionSlot( 4, "" );
		}
	
		success = true;
	}

	waittillframeend;

	// each killstreak should hide the compass via this clientfield if so desired
	self unhide_compass();
	
	currentWeapon = self GetCurrentWeapon();
	killstreak_weapon = get_killstreak_weapon( killstreakType );
	if( currentWeapon == killstreak_weapon && killstreak_weapon.isCarriedKillstreak )
	{ 
		return;
	}
	
	if ( successful && ( !self has_killstreak_in_class( get_menu_name( killstreak ) ) || IS_TRUE( isFromInventory ) ) )
	{
		killstreaks::switch_to_last_non_killstreak_weapon();
	}
	else
	{
		// the killstreak could have failed because we switched to another killstreak weapon
		killstreakForCurrentWeapon = get_from_weapon( currentWeapon );
		
		if ( currentWeapon.isGameplayWeapon )
		{
			if ( IS_TRUE( self.isPlanting ) || IS_TRUE( self.isDefusing ) )
			{
				return;
			}
		}
		
		// not sure why we would switch when !isdefined( killstreakForCurrentWeapon ) so this is so we don't when we have switched to a HeroWeapon
		if ( !isdefined( killstreakForCurrentWeapon ) && currentWeapon.isHeroWeapon )
		{
			return;
		}		
		
		if ( successful || !isdefined( killstreakForCurrentWeapon ) || killstreakForCurrentWeapon == killstreak )
		{
			killstreaks::switch_to_last_non_killstreak_weapon();
		}
	}

	if ( !IS_TRUE( level.usingMomentum ) || IS_TRUE( isFromInventory ) )
	{
		if ( successful )
		{
			activate_next();
		}
	}
}

function useKillstreak( killstreak, isFromInventory )
{
	hasKillstreakBeenUsed = get_if_top_killstreak_has_been_used();
	
	if ( isdefined( self.selectingLocation ) )
	{
		return;
	}

	self thread remove_when_done( killstreak, hasKillstreakBeenUsed, isFromInventory );
	self thread trigger_killstreak( killstreak, isFromInventory );
}

function remove_used_killstreak( killstreak, killstreakId, take_weapon_after_use = true )
{
	self.just_removed_used_killstreak = undefined;

	if( !isdefined( self.pers["killstreaks"] ) )
		return;

	// the killstreak stack is a lifo stack
	// find the top most killstreak in the list 
	// remove it 
	killstreakIndex = undefined;
	
	for ( i = self.pers["killstreaks"].size - 1; i >= 0; i-- )
	{
		if ( self.pers["killstreaks"][i] == killstreak )
		{
			if( isdefined( killstreakId ) && self.pers["killstreak_unique_id"][i] != killstreakId )
			{
				continue;
			}
	  		
			killstreakIndex = i;
			break;
		}
	}

	if ( !isdefined(killstreakIndex) )
	{
		return false;
	}

	self.just_removed_used_killstreak = killstreak;

	if( take_weapon_after_use && !self has_killstreak_in_class( get_menu_name( killstreak ) ) )
	{
		self thread take_weapon_after_use( get_killstreak_weapon( killstreak ) );
	}
	
	arraySize = self.pers["killstreaks"].size;
	for ( i = killstreakIndex; i < arraySize - 1; i++ )
	{
		self.pers["killstreaks"][i] = self.pers["killstreaks"][i + 1];
		self.pers["killstreak_has_been_used"][i] = self.pers["killstreak_has_been_used"][i + 1];
		self.pers["killstreak_unique_id"][i] = self.pers["killstreak_unique_id"][i + 1];
		self.pers["killstreak_ammo_count"][i] = self.pers["killstreak_ammo_count"][i + 1];
	}
	
	self.pers["killstreaks"][arraySize-1] = undefined;
	self.pers["killstreak_has_been_used"][arraySize-1] = undefined;
	self.pers["killstreak_unique_id"][arraySize-1] = undefined;
	self.pers["killstreak_ammo_count"][arraySize-1] = undefined;
	
	return true;
}

function take_weapon_after_use( killstreakWeapon )
{
	self endon("disconnect");
	self endon("death");
	self endon( "joined_team" );
	self endon( "joined_spectators" );

	self waittill( "weapon_change" );
	
	inventoryWeapon = self GetInventoryWeapon();
 	if ( inventoryWeapon != killstreakWeapon ) 
	{
		self TakeWeapon( killstreakWeapon );
	}
}

function get_top_killstreak()
{
	if ( self.pers["killstreaks"].size == 0 )
	{
		return undefined;
	}
		
	return self.pers["killstreaks"][self.pers["killstreaks"].size-1];
}

function get_if_top_killstreak_has_been_used()
{
	if ( !IS_TRUE( level.usingMomentum ) )
	{
		if ( self.pers["killstreak_has_been_used"].size == 0 )
		{
			return undefined;
		}
		
		return self.pers["killstreak_has_been_used"][self.pers["killstreak_has_been_used"].size-1];
	}
}

function get_top_killstreak_unique_id()
{
	if ( self.pers["killstreak_unique_id"].size == 0 )
	{
		return undefined;
	}
		
	return self.pers["killstreak_unique_id"][self.pers["killstreak_unique_id"].size-1];
}

function get_killstreak_index_by_id( killstreakId )
{
	for( index = self.pers["killstreak_unique_id"].size - 1; index >= 0; index-- )
	{
		if( self.pers["killstreak_unique_id"][index] == killstreakId )
		{
			return index;
		}
	}

	return undefined;
}


function get_killstreak_momentum_cost( killstreak )
{
	if ( !IS_TRUE( level.usingMomentum ) )
	{
		return 0;
	}

	if ( !isdefined( killstreak ) )
	{
		return 0;
	}

	Assert( isdefined(level.killstreaks[killstreak]) );
	
	return level.killstreaks[killstreak].momentumCost;
}

function get_killstreak_for_weapon( weapon )
{
	if( isdefined( level.killstreakWeapons[weapon] ) )
		return level.killstreakWeapons[weapon];
	else
		return level.killstreakWeapons[weapon.rootweapon];
}

function get_killstreak_for_weapon_for_stats( weapon )
{
	prefix = "inventory_";
	
	killstreak = get_killstreak_for_weapon( weapon );
	
	if ( isdefined( killstreak ) )
	{
		if ( StrStartsWith( killstreak, prefix ) )
			killstreak = getSubStr( killstreak, prefix.size );
	}
	
	return killstreak;
}

function is_killstreak_weapon_assist_allowed( weapon )
{
	killstreak = get_killstreak_for_weapon( weapon );

	if ( !isdefined( killstreak ) )
	{
		return false;
	}
		
	if ( level.killstreaks[killstreak].allowAssists )
	{
		return true;
	}
		
	return false;
}

function get_killstreak_team_kill_penalty_scale( weapon )
{
	killstreak = get_killstreak_for_weapon( weapon );

	if ( !isdefined( killstreak ) )
	{
		return 1.0;
	}
		
	return level.killstreaks[killstreak].teamKillPenaltyScale;
}

function should_override_entity_camera_in_demo( player, weapon )
{
	killstreak = get_killstreak_for_weapon( weapon );

	if ( !isdefined( killstreak ) )
	{
		return false;
	}
		
	if ( level.killstreaks[killstreak].overrideEntityCameraInDemo )
	{
		return true;
	}
	
	if ( isdefined( player.remoteWeapon ) && IS_TRUE( player.remoteWeapon.controlled ) )
	{
		return true;
	}
			
	return false;
}

function wait_till_hero_weapon_is_fully_on( weapon )
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "weapon_change" );
	
	slot = self GadgetGetSlot( weapon );

	while (1)
	{
		if ( self ability_player::gadget_is_in_use( slot ) )
		{
			self.lastNonKillstreakWeapon = weapon;
			return;
		}
		WAIT_SERVER_FRAME;
	}
}

function track_weapon_usage()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.lastNonKillstreakWeapon = self GetCurrentWeapon();
	lastValidPimary = self GetCurrentWeapon();
	if ( self.lastNonKillstreakWeapon == level.weaponNone )
	{
		weapons = self GetWeaponsListPrimaries();
		if ( weapons.size > 0 )
		{
			self.lastNonKillstreakWeapon = weapons[0];
		}
		else
		{
			self.lastNonKillstreakWeapon = level.weaponBaseMelee;
		}
	}
	Assert( self.lastNonKillstreakWeapon != level.weaponNone );
	
	for ( ;; )
	{
		currentWeapon = self GetCurrentWeapon();
		self waittill( "weapon_change", weapon );
		
		if ( weapons::is_primary_weapon( weapon ) )
		{
			lastValidPimary = weapon;
		}

		if ( weapon == self.lastNonKillstreakWeapon || weapon == level.weaponNone || weapon == level.weaponBaseMelee )
		{
			continue;
		}

		if ( weapon.isGameplayWeapon )
		{
			continue;
		}
				
		if( isdefined( self.resurrect_weapon ) && ( weapon == self.resurrect_weapon ) )
		{
			continue;
		}

		name = get_killstreak_for_weapon( weapon );

		if ( isdefined( name ) && !weapon.isCarriedKillstreak )
		{
			killstreak = level.killstreaks[ name ];
			continue;
		}

		if ( currentWeapon.isEquipment )
		{
			if ( self.lastNonKillstreakWeapon.isCarriedKillstreak )
			{
				self.lastNonKillstreakWeapon = lastValidPimary;
			}
			continue;
		}

		if ( weapon.isHeroWeapon )
		{
			if ( weapon.gadget_heroversion_2_0 )
			{
				if ( weapon.isGadget && self GetAmmoCount(weapon ) > 0 )
				{
					self thread wait_till_hero_weapon_is_fully_on( weapon );
					continue;
				}
			}
		}
		
	
		self.lastNonKillstreakWeapon = weapon;
	}
}

function killstreak_waiter()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self thread track_weapon_usage();
	
	self give_owned();
	
	for ( ;; )
	{
		self waittill( "weapon_change", weapon );
		
		if( !killstreaks::is_killstreak_weapon( weapon ) )
		{
			continue;
		}
		
		killstreak = get_killstreak_for_weapon( weapon );
				
		if ( !IS_TRUE( level.usingMomentum ) )
		{
			killstreak = get_top_killstreak();
			if( weapon != get_killstreak_weapon(killstreak) )
				continue;
		}
		
		if( is_remote_override_weapon( killstreak, weapon ) )
		{
			continue;
		}
		
		inventoryButtonPressed = ( self InventoryButtonPressed() ) || ( isdefined( self.pers["isBot"] ) );

		waittillframeend;

		if( IS_TRUE( self.usingKillstreakHeldWeapon ) && weapon.isCarriedKillstreak )
		{
			continue;
		}
		
		isFromInventory = undefined;
		
		if ( IS_TRUE( level.usingScoreStreaks ) )
		{		
			if ( ( weapon == self GetInventoryWeapon() ) )
			{
				isFromInventory = true;
			}
			else if (( self GetAmmoCount( weapon ) <= 0 ) && (weapon.name != "killstreak_ai_tank"))
			{
				self killstreaks::switch_to_last_non_killstreak_weapon();
				continue;
			}
		}
		else if ( IS_TRUE( level.usingMomentum ) )
		{
			if ( ( weapon == self GetInventoryWeapon() ) && inventoryButtonPressed )
			{
				isFromInventory = true;
			}
			else if ( self.momentum < level.killstreaks[killstreak].momentumCost )
			{
				self killstreaks::switch_to_last_non_killstreak_weapon();
				continue;
			}
		}
		
		// this catches the between round cases
		if ( !isdefined( level.startTime ) && ( level.roundStartKillstreakDelay > 0 ) )
		{
			display_unavailable_time();
			continue;
		}
			
		thread useKillstreak( killstreak, isFromInventory );
	}
}

function should_delay_killstreak( killstreakType )
{
	if( !isdefined(level.startTime) )
	{
		return false;
	}

	if( level.roundStartKillstreakDelay < ( ( ( gettime() - level.startTime ) - level.discardTime ) / 1000 ) )
	{
		return false;
	}

	if( !is_delayable_killstreak(killstreakType) )
	{
		return false;
	}

	killstreakWeapon = get_killstreak_weapon( killstreakType );
	if( killstreakWeapon.isCarriedKillstreak )
	{
		return false;
	}

	if ( util::isFirstRound() || util::isOneRound() )
	{
		return false;
	}

	return true;
}

//check if this is a killstreak we want to delay at the start of a round
function is_delayable_killstreak( killstreakType )
{
	if( isdefined( level.killstreaks[killstreakType] ) && IS_TRUE( level.killstreaks[killstreakType].delayStreak ) )
	{
		return true;
	}

	return false;
}

function get_xp_amount_for_killstreak( killstreakType )
{
	// looks like only the rcxd does this
	// all killstreaks need this?
	xpAmount = 0;
	switch( level.killstreaks[killstreakType].killstreakLevel )
	{
	case 1:
	case 2:
	case 3:
	case 4:
		xpAmount = 100;
		break;
	case 5:
		xpAmount = 150;
		break;
	case 6:
	case 7:
		xpAmount = 200;
		break;
	case 8:
		xpAmount = 250;
		break;
	case 9:
		xpAmount = 300;
		break;
	case 10:
	case 11:
		xpAmount = 350;
		break;
	case 12:
	case 13:
	case 14:
	case 15:
		xpAmount = 500;
		break;
	}

	return xpAmount;
}

function display_unavailable_time()
{
	timeLeft = Int( level.roundStartKillstreakDelay - (globallogic_utils::getTimePassed() / 1000) );
	
	if ( timeLeft <= 0 )
	{
		timeLeft = 1;
	}

	self iPrintLnBold( &"MP_UNAVAILABLE_FOR_N", " " + timeLeft + " ", &"EXE_SECONDS" );	
}

function trigger_killstreak( killstreakType, isFromInventory )
{
	assert( isdefined(level.killstreaks[killstreakType].useFunction), "No use function defined for killstreak " + killstreakType);
	
	self.usingKillstreakFromInventory = isFromInventory;

	if ( level.inFinalKillcam )
	{
		return false;
	}

	if( should_delay_killstreak( killstreakType ) )
	{
		display_unavailable_time();
	}
	else if ( [[level.killstreaks[killstreakType].useFunction]](killstreakType) )
	{
		//Killstreak of 3-4:+100, 5: +150, 6-7 +200, 8: +250, 9: +300, 11: +350, Above: +500

		if ( isdefined( self ) )
		{
			
			if ( !isdefined( self.pers[level.killstreaks[killstreakType].usageKey] ) )
			{
				self.pers[level.killstreaks[killstreakType].usageKey] = 0;
			}
			
			self.pers[level.killstreaks[killstreakType].usageKey]++;
			self notify( "killstreak_used", killstreakType );
			self notify( "killstreak_done", true, killstreakType );
		}
		
		self.usingKillstreakFromInventory = undefined;
		
		return true;
	}
	
	self.usingKillstreakFromInventory = undefined;
	
	if ( isdefined( self ) )
	{
		self notify( "killstreak_done", false, killstreakType );
	}
	return false;
}

function add_to_killstreak_count( weapon )
{
	if ( !isdefined( self.pers["totalKillstreakCount"] ) )
	{
		self.pers["totalKillstreakCount"] = 0;
	}
		
// The check is now done further up the stack to see if this should be counted
		self.pers["totalKillstreakCount"]++;
}

function get_first_valid_killstreak_alt_weapon( killstreakType )
{
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak not registered.");

	if( isdefined( level.killstreaks[killstreakType].altWeapons ) )
	{
		for( i = 0; i < level.killstreaks[killstreakType].altWeapons.size; i++ )
		{
			if( isdefined( level.killstreaks[killstreakType].altWeapons[i] ) )
			{
				return level.killstreaks[killstreakType].altWeapons[i];
			}
		}
	}
	
	return level.weaponNone;
}

function should_give_killstreak( weapon ) 
{
	if( GetDvarInt( "teamOpsEnabled" ) == 1 )
		return false;
	
	killstreakBuilding = GetDvarint( "scr_allow_killstreak_building" );
	
	if ( killstreakBuilding == 0 )
	{
		if ( killstreaks::is_weapon_associated_with_killstreak(weapon) )
		{
			return false;
		}
	}
	
	return true;
}

function point_is_in_danger_area( point, targetpos, radius )
{
	return distance2d( point, targetpos ) <= radius * 1.25;
}

function print_killstreak_start_text( killstreakType, owner, team, targetpos, dangerRadius )
{
	if ( !isdefined( level.killstreaks[killstreakType] ) )
	{
		return;
	}
	
	if ( level.teambased )
	{
		players = level.players;
		if ( !level.hardcoreMode && isdefined(level.killstreaks[killstreakType].inboundNearPlayerText))
		{
			for(i = 0; i < players.size; i++)
			{
				if(isalive(players[i]) && (isdefined(players[i].pers["team"])) && (players[i].pers["team"] == team)) 
				{
					if ( point_is_in_danger_area( players[i].origin, targetpos, dangerRadius ) )
					{
						players[i] iprintlnbold(level.killstreaks[killstreakType].inboundNearPlayerText);
					}
				}
			}
		}
		
		if ( isdefined(level.killstreaks[killstreakType]) )
		{
			for ( i = 0; i < level.players.size; i++ )
			{
				player = level.players[i];
				playerteam = player.pers["team"];
				if ( isdefined( playerteam ) )
				{
					if ( playerteam == team )
					{
						player iprintln( level.killstreaks[killstreakType].inboundText, owner );
					}
				}
			}
		}
	}
	else
	{
		if ( !level.hardcoreMode && isdefined(level.killstreaks[killstreakType].inboundNearPlayerText) )
		{
			if ( point_is_in_danger_area( owner.origin, targetpos, dangerRadius ) )
			{
				owner iprintlnbold(level.killstreaks[killstreakType].inboundNearPlayerText);
			}
		}
	}
}

function play_killstreak_firewall_being_hacked_dialog( killstreakType, killstreakId )
{
	if ( self globallogic_audio::killstreak_dialog_queued( "firewallBeingHacked", killstreakType, killstreakId ) )
	{
		return;
	}
	
	self globallogic_audio::play_taacom_dialog( "firewallBeingHacked", killstreakType, killstreakId );	
}

function play_killstreak_firewall_hacked_dialog( killstreakType, killstreakId )
{
	if ( self globallogic_audio::killstreak_dialog_queued( "firewallHacked", killstreakType, killstreakId ) )
	{
		return;
	}
	
	self globallogic_audio::play_taacom_dialog( "firewallHacked", killstreakType, killstreakId );	
}

function play_killstreak_being_hacked_dialog( killstreakType, killstreakId )
{
	if ( self globallogic_audio::killstreak_dialog_queued( "beingHacked", killstreakType, killstreakId ) )
	{
		return;
	}
	
	self globallogic_audio::play_taacom_dialog( "beingHacked", killstreakType, killstreakId );	
}

function play_killstreak_hacked_dialog( killstreakType, killstreakId, hacker )
{
	self globallogic_audio::flush_killstreak_dialog_on_player( killstreakId );
	self globallogic_audio::play_taacom_dialog( "hacked", killstreakType );
	
	excludeSelf = [];
	excludeSelf[0] = self;
	
	if ( level.teambased )
	{
		globallogic_audio::leader_dialog( level.killstreaks[killstreakType].hackedDialogKey, self.team, excludeSelf );
		globallogic_audio::leader_dialog_for_other_teams( level.killstreaks[killstreakType].hackedStartDialogKey, self.team, undefined, killstreakId );
	}
	else
	{
		self globallogic_audio::leader_dialog_on_player( level.killstreaks[killstreakType].hackedDialogKey );
		hacker globallogic_audio::leader_dialog_on_player( level.killstreaks[killstreakType].hackedStartDialogKey );
	}
}

function play_killstreak_start_dialog( killstreakType, team, killstreakId )
{
	if ( !isdefined( killstreakType ) || 
	     !isdefined( killstreakId ) )
	{
		return;
	}
	
	// Kill any waiting 'scorestreak ready' taacom threads
	self notify ( "killstreak_start_" + killstreakType );
	self notify ( "killstreak_start_inventory_" + killstreakType );
	
	dialogKey = level.killstreaks[killstreakType].requestDialogKey;
	
	if ( !isdefined( self.currentKillstreakDialog ) && isdefined( dialogKey ) && isdefined( level.heroPlayDialog ) )
    {		
		self thread [[level.heroPlayDialog]]( dialogKey );
    }
	
	excludeSelf = [];
	excludeSelf[0] = self;
	
	if ( level.teambased )
	{
		// Don't play the friendly incoming audio over your own request
		globallogic_audio::leader_dialog( level.killstreaks[killstreakType].startDialogKey, team, excludeSelf, undefined, killstreakId );
		
		globallogic_audio::leader_dialog_for_other_teams( level.killstreaks[killstreakType].enemyStartDialogKey, team, undefined, killstreakId );
	}
	else
	{
		globallogic_audio::leader_dialog( level.killstreaks[killstreakType].enemyStartDialogKey, undefined, excludeSelf, undefined, killstreakId  );
	}
}

function play_killstreak_ready_sfx (killstreaktype)
{
	if ( !isdefined( level.gameEnded ) || !level.gameEnded )
	{
		ready_sfx_alias = "mpl_killstreak_" + killstreaktype;
		
		if ( isdefined (ready_sfx_alias))
		{
			self playsoundtoplayer (ready_sfx_alias, self );
		}
	}
}	

function play_killstreak_ready_dialog( killstreakType, taacomWaitTime )
{
	self notify( "killstreak_ready_" + killstreakType );
	
	self endon( "death" );
	self endon( "killstreak_start_" + killstreakType );
	self endon( "killstreak_ready_" + killstreakType );

	level endon( "game_ended" );
	
	if ( isdefined( level.gameEnded ) && level.gameEnded )
	{
		return;
	}
	
	if ( globallogic_audio::killstreak_dialog_queued( "ready", killstreakType ) )
	{
		return;
	}
	
	if ( isdefined( taacomWaitTime ) )
	{
		wait ( taacomWaitTime );
	}
	
	self globallogic_audio::play_taacom_dialog( "ready", killstreakType );
}

// Self is killstreak
function play_destroyed_dialog_on_owner( killstreakType, killstreakId )
{
	if ( !isdefined( self.owner ) ||
	     !isdefined( self.team )  ||
	     self.team != self.owner.team )
	{
		return;
	}
	
	self.owner globallogic_audio::flush_killstreak_dialog_on_player( killstreakId );
	
	self.owner globallogic_audio::play_taacom_dialog( "destroyed", killstreakType );
}

// Self is killstreak
function play_taacom_dialog_on_owner( dialogKey, killstreakType, killstreakId )
{
	if ( !isdefined( self.owner ) ||
	     !isdefined( self.team )  ||
	     self.team != self.owner.team )
	{
		return;
	}
	
	self.owner globallogic_audio::play_taacom_dialog( dialogKey, killstreakType, killstreakId );
}

// Self is killstreak
function play_pilot_dialog_on_owner( dialogKey, killstreakType, killstreakId )
{
	if ( !isdefined( self.owner ) ||
	     !isdefined( self.owner.team ) ||
	     !isdefined( self.team ) ||
	     self.team != self.owner.team )
	{
		return;
	}
		
	self.owner play_pilot_dialog( dialogKey, killstreakType, killstreakId, self.pilotIndex );
}

// self is player
function play_pilot_dialog( dialogKey, killstreakType, killstreakId, pilotIndex )
{	
	if ( !isdefined( killstreakType ) || 
	     !isdefined( pilotIndex ) )
	{
		return;
	}
	
	self globallogic_audio::killstreak_dialog_on_player( dialogKey, killstreakType, killstreakId, pilotIndex );
}

// Self is killstreak
function play_taacom_dialog_response_on_owner( dialogKey, killstreakType, killstreakId )
{
	assert( isdefined( dialogKey ) );
	assert( isdefined( killstreakType ) );
	
	if ( !isdefined( self.owner ) ||
	     !isdefined( self.team ) ||
	     self.team != self.owner.team )
	{
		return;
	}
	
	self.owner play_taacom_dialog_response( dialogKey, killstreakType, killstreakId, self.pilotIndex );
}

// self is player
function play_taacom_dialog_response( dialogKey, killstreakType, killstreakId, pilotIndex )
{
	assert( isdefined( dialogKey ) );
	assert( isdefined( killstreakType ) );
	
	if ( !isdefined( pilotIndex ) )
	{
		return;
	}
	
	self globallogic_audio::play_taacom_dialog( dialogKey + pilotIndex, killstreakType, killstreakId );	
}


// Self is player
function get_random_pilot_index( killstreakType )
{
	if ( !isdefined( killstreakType ) )
	{
		return undefined;
	}
	
	taacomBundle = struct::get_script_bundle( "mpdialog_taacom", self.pers["mptaacom"] );
	
	if( !isdefined( taacomBundle.pilotBundles[killstreakType] ) )
	{
		return undefined;
	}
	
	numPilots = taacomBundle.pilotBundles[killStreakType].size;
	
	if ( numPilots <= 0 )
	{
		return undefined;
	}
	
	return RandomInt( numPilots );
}

// Self is killstreak
function player_killstreak_threat_tracking( killstreakType )
{
	assert( isdefined( killstreakType ) );
	
	self endon ( "death" );
	self endon ( "delete" );
	self endon ( "leaving" );
	level endon( "game_ended" );
	
	while( 1 )
	{
		if ( !isdefined( self.owner ) )
		{
			return;
		}
		
		players =  self.owner battlechatter::get_enemy_players();
		players = array::randomize( players );
		
		foreach( player in players )
		{
			if ( !player battlechatter::can_play_dialog( true ) )
			{
				continue;
			}
			
			lookAngles = player GetPlayerAngles();
			
			if ( lookAngles[0] < 270 || lookAngles[0] > 330 )
			{
				continue;
			}
			
			lookDir = AnglesToForward( lookAngles );
			eyePoint = player getEye();
			
			streakDir = VectorNormalize( self.origin - eyePoint );
			
			dot = VectorDot( streakDir, lookDir );
			
			if ( dot < 0.94 )
			{
				continue;
			}
			
			traceResult = BulletTrace( eyePoint, self.origin, true, player );
			if ( traceResult["fraction"] >= 1.0 || traceResult["entity"] === self )
			{
				if ( battlechatter::dialog_chance( "killstreakSpotChance" ) ) 
				{
					player battlechatter::play_killstreak_threat( killstreakType );
				}
				wait ( battlechatter::mpdialog_value( "killstreakSpotDelay", 0 ) );
				break;
			}
		}
		
		wait ( battlechatter::mpdialog_value( "killstreakSpotInterval", SERVER_FRAME ) );
	}
}

function get_killstreak_inform_dialog( killstreakType )
{
	// please add inform dialog to killstreak
	//assert( isdefined ( level.killstreaks[killstreakType].informDialog ) );
	
	if ( isdefined( level.killstreaks[killstreakType].informDialog ) )
	{
		return level.killstreaks[killstreakType].informDialog;
	}
	return "";
}

function get_killstreak_usage_by_killstreak(killstreakType)
{
	assert( isdefined(level.killstreaks[killstreakType]), "Killstreak needs to be registered before calling get_killstreak_usage.");
	
	return get_killstreak_usage( level.killstreaks[killstreakType].usageKey );
}

function get_killstreak_usage(usageKey)
{
	if ( !isdefined( self.pers[usageKey] ) )
	{
		return 0;
	}
	
	return self.pers[usageKey];
}

function on_player_spawned()
{
	self endon("disconnect");

	give_owned();
	
	if ( !isdefined( self.pers["killstreaks"] ) )
	{
		self.pers["killstreaks"] = [];
	}
	if ( !isdefined( self.pers["killstreak_has_been_used"] ) )
	{
		self.pers["killstreak_has_been_used"] = [];
	}
	if ( !isdefined( self.pers["killstreak_unique_id"] ) )
	{
		self.pers["killstreak_unique_id"] = [];
	}
	if( !isdefined( self.pers["killstreak_ammo_count"] ) )
	{
		self.pers["killstreak_ammo_count"] = [];
	}

	size = self.pers["killstreaks"].size;

	if ( size > 0 )
	{
		self thread play_killstreak_ready_dialog( self.pers["killstreaks"][size - 1] );
	}
	
	self.killcamKilledByEnt = undefined;
}

function on_joined_team()
{
	self endon("disconnect");
	
	self SetInventoryWeapon( level.weaponNone );
	self.pers["cur_kill_streak"] = 0;
	self.pers["cur_total_kill_streak"] = 0;		
	self setplayercurrentstreak( 0 );
	self.pers["totalKillstreakCount"] = 0;
	self.pers["killstreaks"] = [];
	self.pers["killstreak_has_been_used"] = [];
	self.pers["killstreak_unique_id"] = [];
	self.pers["killstreak_ammo_count"] = [];
	
	if ( IS_TRUE( level.usingScoreStreaks ) )
	{
		self.pers["killstreak_quantity"] = [];
		self.pers["held_killstreak_ammo_count"] = [];
		self.pers["held_killstreak_clip_count"] = [];
	}
}

function init_ride_killstreak( streak, always_allow = false )
{
	self disableUsability();
	result = self init_ride_killstreak_internal( streak, always_allow );

	if ( isdefined( self ) )
	{
		self enableUsability();
	}
		
	return result;
}

function watch_for_remove_remote_weapon()
{
	self endon( "endWatchForRemoveRemoteWeapon" );
	for ( ;; )
	{
		self waittill( "remove_remote_weapon" );
		self killstreaks::switch_to_last_non_killstreak_weapon();
		self enableUsability();
	}
}

function init_ride_killstreak_internal( streak, always_allow )
{	
	if ( isdefined( streak ) && ( ( streak == "qrdrone" ) || ( streak == "dart" ) || ( streak == "killstreak_remote_turret" ) || ( streak == "killstreak_ai_tank" ) || (streak == "qrdrone") || (streak == "sentinel") ) )
	{
		laptopWait = "timeout";
	}
	else
	{
		laptopWait = self util::waittill_any_timeout( 0.6, "disconnect", "death", "weapon_switch_started" );
	}
		
	hostmigration::waitTillHostMigrationDone();

	if ( laptopWait == "weapon_switch_started" )
	{
		return ( "fail" );
	}

	if ( !isAlive( self ) && !always_allow )
	{
		return "fail";
	}

	if ( laptopWait == "disconnect" || laptopWait == "death" )
	{
		if ( laptopWait == "disconnect" )
		{
			return ( "disconnect" );
		}

		if ( self.team == "spectator" )
		{
			return "fail";
		}

		return ( "success" );		
	}
	
	if ( self IsEMPJammed() && !IS_TRUE( self.ignoreEMPJammed ) )
	{
		return ( "fail" );
	}
	
	if ( self is_interacting_with_object() )
	{
		return "fail";
	}
	
	self thread hud::fade_to_black_for_x_sec( 0, 0.2, 0.4, 0.25 );
	self thread watch_for_remove_remote_weapon();
	blackOutWait = self util::waittill_any_timeout( 0.60, "disconnect", "death" );
	self notify( "endWatchForRemoveRemoteWeapon" );

	hostmigration::waitTillHostMigrationDone();

	if ( blackOutWait != "disconnect" ) 
	{
		self thread clear_ride_intro( 1.0 );
		
		if ( self.team == "spectator" )
		{
			return "fail";
		}
	}
	
	if ( always_allow )
	{
		if ( blackOutWait == "disconnect" )
		{
			return ( "disconnect" );
		}
		else
		{
			return ( "success" );		
		}
	}

	if ( self isOnLadder() )
	{
		return "fail";	
	}

	if ( !isAlive( self ) )
	{
		return "fail";
	}

	if ( self IsEMPJammed() && !IS_TRUE( self.ignoreEMPJammed ) )
	{
		return ( "fail" );
	}
	
	if ( IS_TRUE( self.laststand ) )
	{
		return "fail";
	}
	
	if ( self is_interacting_with_object() )
	{
		return "fail";
	}
	
	if ( blackOutWait == "disconnect" )
	{
		return ( "disconnect" );
	}
	else
	{
		return ( "success" );		
	}
}

function clear_ride_intro( delay )
{
	self endon( "disconnect" );

	if ( isdefined( delay ) )
		wait( delay );

	
	self thread hud::screen_fade_in( 0 );
}

function is_interacting_with_object()
{
	if ( self isCarryingTurret() )
	{
		return true;
	}
	if ( IS_TRUE( self.isPlanting ) )
	{
		return true;
	}
	if ( IS_TRUE( self.isDefusing ) )
	{
		return true;
	}

	return false;
}


function clear_using_remote( immediate, skipNotify )
{
	if ( !isdefined( self ) )
	{
		return;
	}
	
	self.dofutz = false;
	self.no_fade2black = false;
	self clientfield::set_to_player( "static_postfx", 0 );

	if ( isdefined( self.carryIcon ) )
	{
		self.carryIcon.alpha = 1;
	}

	self.usingRemote = undefined;
	self reset_killstreak_delay_killcam();
	self enableOffhandWeapons();
	self enableWeaponCycling();
	
	curWeapon = self getCurrentWeapon();
	
	if ( isalive( self ) )
	{
		self killstreaks::switch_to_last_non_killstreak_weapon( immediate );
	}
	
	if( !level.gameEnded )
		self util::freeze_player_controls( false );
	if( !IS_TRUE( skipNotify ))
		self notify( "stopped_using_remote" );
	
	thread hide_tablet();
}

function hide_tablet()
{
	self endon("disconnect");
	wait .2;
	self clientfield::set_player_uimodel( "hudItems.remoteKillstreakActivated", 0 );	
}

function set_killstreak_delay_killcam( killstreak_name )
{
	self.killstreak_delay_killcam = killstreak_name;
}

function reset_killstreak_delay_killcam() // self == player
{
	self.killstreak_delay_killcam = undefined;
}

function hide_compass()
{
	self clientfield::set( CLIENT_FIELD_KILLSTREAK_HIDES_COMPASS, 1 );
}

function unhide_compass()
{
	self clientfield::set( CLIENT_FIELD_KILLSTREAK_HIDES_COMPASS, 0 );
}

function setup_health( killstreak_ref, max_health, low_health )
{
	self.maxhealth = max_health;
	self.lowhealth = low_health;

	self.hackedHealthUpdateCallback = &defaultHackedHealthUpdateCallback;
	
	tableMaxHealth = killstreak_bundles::get_max_health( killstreak_ref );
	
	if ( isdefined( tableMaxHealth ) )
	{
		self.maxhealth = tableMaxHealth;
	}
	
	tableLowHealth = killstreak_bundles::get_low_health( killstreak_ref );
	
	if ( isdefined( tableLowHealth ) )
	{
		self.lowhealth = tableLowHealth;
	}	
	
	tableHackedHealth = killstreak_bundles::get_hacked_health( killstreak_ref );
	
	if ( isdefined( tableHackedHealth ) )
	{
		self.hackedHealth = tableHackedHealth;
	}	
	else
	{
		self.hackedHealth = self.maxhealth;
	}
}

function MonitorDamage( killstreak_ref, 
               			max_health, destroyed_callback, 
               			low_health, low_health_callback, 
               			emp_damage, emp_callback, 
               			allow_bullet_damage )
{
	self endon( "death" );
	self endon( "delete" );
	
	self.health = 9999999;
	self.damageTaken = 0;

	self setup_health( killstreak_ref, max_health, low_health );
	
	assert( ( !IsVehicle( self ) || !IsSentient( self ) ), "MonitorDamage should not be called on a sentient vehicle. For sentient vehicles, use overrideVehicleDamage instead.");

	while( true )
	{
		weapon_damage = undefined;
		// this damage is done to self.health which isnt used to determine the helicopter's health, damageTaken is.
		self waittill( "damage", damage, attacker, direction, point, type, tagName, modelName, partname, weapon, flags, inflictor, chargeLevel );		

		if( IS_TRUE( self.invulnerable ) )
		{
			continue;
		}
		
		if( !isdefined( attacker ) || !isplayer( attacker ) )
		{
			continue;
		}
		
		friendlyfire = weaponobjects::friendlyFireCheck( self.owner, attacker );
		if( !friendlyfire )
		{
			continue;			
		}
			
		if(	isdefined( self.owner ) && attacker == self.owner )
		{
			continue;
		}
		
		isValidAttacker = true;
		if( level.teambased )
		{
			isValidAttacker = ( isdefined( attacker.team ) && attacker.team != self.team );
		}

		if( !isValidAttacker )
		{
			continue;
		}
		
		if ( isdefined( self.killstreakDamageModifier ) )
		{
			damage = [[self.killstreakDamageModifier]]( damage, attacker, direction, point, type, tagName, modelName, partname, weapon, flags, inflictor, chargeLevel );
			if ( damage <= 0 )
				continue;
		}

		if( weapon.isEmp && type == "MOD_GRENADE_SPLASH" )
		{			
			emp_damage_to_apply = killstreak_bundles::get_emp_grenade_damage( killstreak_ref, self.maxhealth );
			
			if ( !isdefined( emp_damage_to_apply ) )
				emp_damage_to_apply = ( isdefined( emp_damage ) ? emp_damage : 1 );
		
			if( isdefined( emp_callback ) && emp_damage_to_apply > 0 )
			{
				self [[ emp_callback ]]( attacker );
			}

			weapon_damage = emp_damage_to_apply;
		}
		
		if ( IS_TRUE( self.selfDestruct ) )
		{
			weapon_damage = self.maxhealth + 1;
		}
		
		if ( !isdefined( weapon_damage ) )
		{
			weapon_damage = killstreak_bundles::get_weapon_damage( killstreak_ref, self.maxhealth, attacker, weapon, type, damage, flags, chargeLevel );

			if ( !isdefined( weapon_damage ) )
			{			
				weapon_damage = get_old_damage( attacker, weapon, type, damage, allow_bullet_damage );
			}
		}		
		
		if ( weapon_damage > 0 )
		{
			if( damagefeedback::doDamageFeedback( weapon, attacker ) )
			{
				attacker thread damagefeedback::update( type );
			}
			
			self challenges::trackAssists( attacker, weapon_damage, false );
		}		
		
		self.damageTaken += weapon_damage;
		
		if ( !IsSentient( self ) && weapon_damage > 0 )
			self.attacker = attacker;
				
		if( self.damageTaken > self.maxhealth )
		{
			weaponStatName = "destroyed";
			switch( weapon.name )
			{
				case "auto_tow":
				case "tow_turret":
				case "tow_turret_drop":
					weaponStatName = "kills";
					break;
			}
			
			level.globalKillstreaksDestroyed++;
			attacker AddWeaponStat( GetWeapon( killstreak_ref ), "destroyed", 1 );
			
			if( isdefined( destroyed_callback ) )
			{
				self thread [[ destroyed_callback ]]( attacker, weapon );
			}
			
			return;
		}
		
		remaining_health = ( max_health - self.damageTaken );
		
		if( ( remaining_health < low_health ) && weapon_damage > 0 )
		{
			if( isdefined( low_health_callback ) && ( !isdefined( self.currentState ) || self.currentState != "damaged" ) )
			{
				self [[ low_health_callback ]]( attacker, weapon );
			}
			
			self.currentstate = "damaged";
		}
		
		if( isdefined( self.extra_low_health ) && ( remaining_health < self.extra_low_health ) && weapon_damage > 0 )
		{
			if( isdefined( self.extra_low_health_callback ) && ( !isdefined( self.extra_low_damage_notified ) ) )
			{
				self [[ self.extra_low_health_callback ]]( attacker, weapon );
				
				self.extra_low_damage_notified = true;
			}
		}
	}
}

function defaultHackedHealthUpdateCallback( hacker )
{
	killstreak = self;

	assert( isdefined( self.maxHealth ) );
	assert( isdefined( self.hackedHealth ) );
	assert( isdefined( self.damageTaken ) );
		
	damageAfterHacking = self.maxHealth - self.hackedHealth;
	if ( self.damageTaken < damageAfterHacking ) 
	{
		self.damageTaken = damageAfterHacking;
	}
}

function OnDamagePerWeapon( killstreak_ref, 
                  		attacker, damage, flags, type, weapon,
               			max_health, destroyed_callback, 
               			low_health, low_health_callback, 
               			emp_damage, emp_callback, 
               			allow_bullet_damage, chargeLevel )
{	
	self.maxhealth = max_health;
	self.lowhealth = low_health;
	
	tableHealth = killstreak_bundles::get_max_health( killstreak_ref );
	
	if ( isdefined( tableHealth ) )
	{
		self.maxhealth = tableHealth;
	}
	
	tableHealth = killstreak_bundles::get_low_health( killstreak_ref );
	
	if ( isdefined( tableHealth ) )
	{
		self.lowhealth = tableHealth;
	}	
	
	if( IS_TRUE( self.invulnerable ) )
	{
		return 0;
	}
	
	if( !isdefined( attacker ) || !isplayer( attacker ) )
	{
		return get_old_damage( attacker, weapon, type, damage, allow_bullet_damage );
	}
	
	friendlyfire = weaponobjects::friendlyFireCheck( self.owner, attacker );
	if( !friendlyfire )
	{
		return 0;
	}	
	
	isValidAttacker = true;
	if( level.teambased )
	{
		isValidAttacker = ( isdefined( attacker.team ) && attacker.team != self.team );
	}

	if( !isValidAttacker )
	{
		return 0;
	}
	
	if( weapon.isEmp && type == "MOD_GRENADE_SPLASH" )
	{		
		emp_damage_to_apply = killstreak_bundles::get_emp_grenade_damage( killstreak_ref, self.maxhealth );
		
		if ( !isdefined( emp_damage_to_apply ) )
			emp_damage_to_apply = ( isdefined( emp_damage ) ? emp_damage : 1 );

		if( isdefined( emp_callback ) && emp_damage_to_apply > 0 )
		{
			self [[ emp_callback ]]( attacker, weapon );
		}
		
		return emp_damage_to_apply;
	}	

	weapon_damage = killstreak_bundles::get_weapon_damage( killstreak_ref, self.maxhealth, attacker, weapon, type, damage, flags, chargeLevel );

	if ( !isdefined( weapon_damage ) )
	{			
		weapon_damage = get_old_damage( attacker, weapon, type, damage, allow_bullet_damage );
	}
	
	if ( weapon_damage <= 0 )
	{
		return 0;
	}	
	
	iDamage = int( weapon_damage );
	if( iDamage > self.health )
	{
		if( isdefined( destroyed_callback ) )
		{
			self thread [[ destroyed_callback ]]( attacker, weapon );
		}
	}	
	
	return iDamage;
}

function get_old_damage( attacker, weapon, type, damage, allow_bullet_damage)
{
	switch( type )
	{
		case "MOD_RIFLE_BULLET":
		case "MOD_PISTOL_BULLET":
			{
				if( !allow_bullet_damage )
				{
					damage = 0;
					break;
				}
				
				if ( isdefined( attacker ) && isplayer( attacker ) )
				{
					hasFMJ = attacker HasPerk( "specialty_armorpiercing" );
				}				
	
				if ( IS_TRUE( hasFMJ ) )
				{
					damage = int( damage * level.cac_armorpiercing_data );
				}
			}
			break;
			
		case "MOD_PROJECTILE":
		case "MOD_EXPLOSIVE":
		case "MOD_PROJECTILE_SPLASH":
			if ( ( weapon.statIndex == level.weaponPistolEnergy.statIndex ) || ( weapon.statIndex != level.weaponShotgunEnergy.statIndex ) || ( weapon.statIndex == level.weaponSpecialCrossbow.statIndex ) )
				break;
			
			if( isdefined( self.remoteMissileDamage ) && isdefined( weapon ) && weapon.name == "remote_missile_missile")
			{
				 damage = self.remoteMissileDamage;
			}
			else if( isdefined( self.rocketDamage ) )
			{
				damage = self.rocketDamage;
			}
			break;
		default:			
			break;
	}
	
	return damage;
}



function configure_team( killstreakType, killstreakId, owner, influencerType, configureTeamPreFunction, configureTeamPostFunction, isHacked = false )
{
	killstreak = self;
	
	killstreak.killstreakType = killstreakType;
	killstreak.killstreakId = killstreakId;
	killstreak _setup_configure_team_callbacks( influencerType, configureTeamPreFunction, configureTeamPostFunction );
	killstreak configure_team_internal( owner, isHacked );

	owner thread trackActiveKillstreak( killstreak );
}


function trackActiveKillstreak( killstreak )
{
	self endon( "disconnect" );
	
	killstreakIndex = killstreak.killstreakID;
	if( isdefined( killstreakIndex ) )
	{
		self.pers["activeKillstreaks"][ killstreakIndex ] = killstreak;
		
		killstreak util::waittill_any( "killstreak_hacked", "death" );
	
		self.pers["activeKillstreaks"][ killstreakIndex ] = undefined;
	}
}

function getActiveKillstreaks()
{
	return self.pers["activeKillstreaks"];
}

function configure_team_internal( owner, isHacked )
{
	killstreak = self;
	if ( isHacked == false )
	{
		killstreak.originalOwner = owner;
		killstreak.originalteam = owner.team;	
	}
	else
	{
		assert( killstreak.killstreakTeamConfigured, "configure_team must be called before a killstreak can be hacked" );
	}
	
	if ( isdefined( killstreak.killstreakConfigureTeamPreFunction ) )
	{
		killstreak thread [[killstreak.killstreakConfigureTeamPreFunction]]( owner, ishacked );
	}

	if ( isdefined( killstreak.killstreakInfluencerType ) )
	{
		killstreak spawning::remove_influencers();
	}
	
	killstreak SetTeam( owner.team );
	killstreak.team = owner.team;
	if ( !IsAI( killstreak ) )
	{
		killstreak SetOwner( owner );
	}
	killstreak.owner = owner;
	killstreak.ownerEntnum = owner.entnum;

	killstreak.pilotIndex = killstreak.owner get_random_pilot_index( killstreak.killstreakType );
	
	if ( isdefined( killstreak.killstreakInfluencerType ) )
	{
		killstreak spawning::create_entity_enemy_influencer( killstreak.killstreakInfluencerType, owner.team );
	}
	
	if ( isdefined( killstreak.killstreakConfigureTeamPostFunction ) )
	{
		killstreak thread [[killstreak.killstreakConfigureTeamPostFunction]]( owner, ishacked );
	}
}

function private _setup_configure_team_callbacks( influencerType, configureTeamPreFunction, configureTeamPostFunction )
{
	killstreak = self;
	
	killstreak.killstreakTeamConfigured = true;
	killstreak.killstreakInfluencerType = influencerType;
	killstreak.killstreakConfigureTeamPreFunction = configureTeamPreFunction;
	killstreak.killstreakConfigureTeamPostFunction = configureTeamPostFunction;
}

	
function WatchTeamChange( teamChangeNotify )
{
	self notify( teamChangeNotify+ "_Singleton" );
	self endon ( teamChangeNotify+ "_Singleton" );
	
	killstreak = self;
	killstreak endon( "death" );
	
	killstreak endon( teamChangeNotify );
	killstreak.owner util::waittill_any( "joined_team", "disconnect", "joined_spectators", "emp_jammed" );
	killstreak notify( teamChangeNotify );
}

function should_not_timeout( killstreak )
{
	return false;	
}

function WaitForTimeout( killstreak, duration, callback, endCondition1, endCondition2, endCondition3 )
{
	self endon( "killstreak_hacked" );
	
	if( isdefined( endCondition1 ) )
		self endon( endCondition1 );
	if( isdefined( endCondition2 ) )
		self endon( endCondition2 );
	if( isdefined( endCondition3 ) )
		self endon( endCondition3 );
	
	self thread waitForTimeoutHacked( killstreak, callback, endCondition1, endCondition2, endCondition3 );
	
	killstreakBundle = level.killstreakBundle[self.killstreakType];
	self.killstreakEndTime = getTime() + duration;
	if ( isdefined( killstreakBundle ) && isdefined( killstreakBundle.ksTimeoutBeepDuration ) )
	{
		self WaitForTimeoutBeep( killstreakBundle, duration );
	}
	else
	{
		hostmigration::MigrationAwareWait( duration );	
	}
	
	self notify( "kill_WaitForTimeoutHacked_thread" );
	self.killstreakTimedOut = true;
	self.killstreakEndTime = 0;
	self notify( "timed_out" );
	self [[ callback ]]();
}


function WaitForTimeoutBeep( killstreakBundle, duration )
{
	self endon("death");
	beepDuration = killstreakBundle.ksTimeoutBeepDuration * 1000;
	hostmigration::MigrationAwareWait( max( duration - beepDuration, 0 ) );
	
	if ( IsVehicle( self ) )
	{
		self clientfield::set( "timeout_beep", 1 );
	}
	
	if ( isdefined( killstreakBundle.ksTimeoutFastBeepDuration ) )
	{
		fastBeepDuration = killstreakBundle.ksTimeoutFastBeepDuration * 1000;
		hostmigration::MigrationAwareWait( max( beepDuration - fastBeepDuration, 0 ) );
		
		if ( IsVehicle( self ) )
		{
			self clientfield::set( "timeout_beep", 2 );
		}
		
		hostmigration::MigrationAwareWait( fastBeepDuration );
	}

	if ( IsVehicle( self ) )
	{
		self clientfield::set( "timeout_beep", 0 );
	}
}
		

function WaitForTimeoutHacked( killstreak, callback, endCondition1, endCondition2, endCondition3 )
{
	self endon( "kill_WaitForTimeoutHacked_thread" );
	
	if( isdefined( endCondition1 ) )
		self endon( endCondition1 );
	if( isdefined( endCondition2 ) )
		self endon( endCondition2 );
	if( isdefined( endCondition3 ) )
		self endon( endCondition3 );
	
	self waittill( "killstreak_hacked" );
	
	hackedDuration = self killstreak_hacking::get_hacked_timeout_duration_ms();
	self.killstreakEndTime = getTime() + hackedDuration;
	hostmigration::MigrationAwareWait( hackedDuration );
	self.killstreakEndTime = 0;
	self notify( "timed_out" );
	self  [[ callback ]]();	
}

function update_player_threat( player )
{
	heli = self;
	
	player.threatlevel = 0;
	
	// distance factor
	dist = distance( player.origin, heli.origin );
	player.threatlevel += ( ( level.heli_visual_range - dist ) / level.heli_visual_range ) * 100; // inverse distance % with respect to helicopter targeting range
	
	// behavior factor
	if( isdefined( heli.attacker ) && player == heli.attacker )
		player.threatlevel += 100;
	
	if( isdefined( player.carryObject ) )  //flag carrier
		player.threatlevel += 200;

	// player score factor
	if( isdefined( player.score ) )
		player.threatlevel += player.score * 2;
	
	if( player weapons::has_launcher() )
	{
		if( player weapons::has_lockon( heli ) )
			player.threatlevel += 1000;
		else 
			player.threatlevel += 500;
	}
	
	if( player weapons::has_hero_weapon() )
		player.threatlevel += 300;
	
	if( player weapons::has_lmg() )
		player.threatlevel += 200;
		
	if( isdefined( player.antithreat ) )
		player.threatlevel -= player.antithreat;
		
	if( player.threatlevel <= 0 )
		player.threatlevel = 1;
}

function update_non_player_threat( non_player )
{
	heli = self;
	
	non_player.threatlevel = 0;
	
	// distance factor
	dist = distance( non_player.origin, heli.origin );
	non_player.threatlevel += ( ( level.heli_visual_range - dist ) / level.heli_visual_range ) * 100; // inverse distance % with respect to helicopter targeting range
			
	if( non_player.threatlevel <= 0 )
		non_player.threatlevel = 1;
}

function update_actor_threat( actor )
{
	heli = self;
	actor.threatlevel = 0;
	
	// distance factor
	dist = distance( actor.origin, heli.origin );
	actor.threatlevel += ( ( level.heli_visual_range - dist ) / level.heli_visual_range ) * 100; // inverse distance % with respect to helicopter targeting range
	
	// player score factor
	if( isdefined( actor.owner ) )
    {
		// behavior factor
		if( isdefined( heli.attacker ) && actor.owner == heli.attacker )
			actor.threatlevel += 100;

		if( isdefined( actor.owner.carryObject ) )  //flag carrier
			actor.threatlevel += 200;

		if( isdefined( actor.owner.score ) )
			actor.threatlevel += actor.owner.score * 4;
	
		if( isdefined( actor.owner.antithreat ) )
			actor.threatlevel -= actor.owner.antithreat;
   }
		
	if( actor.threatlevel <= 0 )
		actor.threatlevel = 1;
}

function update_dog_threat( dog )
{
	heli = self;
	dog.threatlevel = 0;
	
	// distance factor
	dist = distance( dog.origin, heli.origin );
	dog.threatlevel += ( ( level.heli_visual_range - dist ) / level.heli_visual_range ) * 100; // inverse distance % with respect to helicopter targeting range
}

// check if missile is in hittable sight zone
function missile_valid_target_check( missiletarget )
{
	heli2target_normal = vectornormalize( missiletarget.origin - self.origin );
	heli2forward = anglestoforward( self.angles );
	heli2forward_normal = vectornormalize( heli2forward );

	heli_dot_target = vectordot( heli2target_normal, heli2forward_normal );
	
	if ( heli_dot_target >= level.heli_valid_target_cone )
	{
		return true;
	}
	return false;
}

function update_missile_player_threat( player )
{
	player.missilethreatlevel = 0;
	
	// distance factor
	dist = distance( player.origin, self.origin );
	player.missilethreatlevel += ( (level.heli_missile_range - dist)/level.heli_missile_range )*100; // inverse distance % with respect to helicopter targeting range
	
	
	if( self missile_valid_target_check( player ) == false )
	{
		player.missilethreatlevel = 1;
		return;
	}
		
	// behavior factor
	if ( isdefined( self.attacker ) && player == self.attacker )
		player.missilethreatlevel += 100;
	
	// player score factor
	player.missilethreatlevel += player.score*4;
		
	if( isdefined( player.antithreat ) )
		player.missilethreatlevel -= player.antithreat;
		
	if( player.missilethreatlevel <= 0 )
		player.missilethreatlevel = 1;
}

// threat missile factors
function update_missile_dog_threat( dog )
{
	dog.missilethreatlevel = 1;
}

function killstreak_assist(victim, assister, killstreak)
{
	victim RecordKillstreakAssist(victim, assister, killstreak);
}

function add_ricochet_protection( killstreak_id, owner, origin, ricochet_distance )
{
	testing = false;
	
	if ( !level.hardcoreMode && !testing )
		return;
	
	if ( !isdefined( ricochet_distance ) || ricochet_distance == 0 )
		return;

	DEFAULT( owner.ricochet_protection, [] );
	
	owner.ricochet_protection[ killstreak_id ] = SpawnStruct();
	owner.ricochet_protection[ killstreak_id ].origin = origin;
	owner.ricochet_protection[ killstreak_id ].distanceSq = SQR( ricochet_distance );
}

function set_ricochet_protection_endtime( killstreak_id, owner, endTime )
{
	if ( !isdefined( owner ) || !isdefined( owner.ricochet_protection ) || !isdefined( killstreak_id ) )
		return;
	
	if ( !isdefined( owner.ricochet_protection[ killstreak_id ] ) )
	    return;

	owner.ricochet_protection[ killstreak_id ].endTime = endTime;
}

function remove_ricochet_protection( killstreak_id, owner )
{
	if ( !isdefined( owner ) || !isdefined( owner.ricochet_protection ) || !isdefined( killstreak_id ) )
		return;

	owner.ricochet_protection[ killstreak_id ] = undefined;
}

function is_ricochet_protected( player )
{
	if ( !isdefined( player ) || !isdefined( player.ricochet_protection ) )
		return false;
	
	foreach( protection in player.ricochet_protection )
	{
		if ( !isdefined( protection ) )
			continue;
		
		if ( isdefined( protection.endTime ) && protection.endTime < GetTime() )
			continue;

		if ( DistanceSquared( protection.origin, player.origin ) < protection.distanceSq )
			return true;
	}
		
	return false;
}

function is_killstreak_start_blocked()
{
	return ( isdefined( self.dart_thrown_time ) && ( GetTime() - self.dart_thrown_time < 1500 ) );
}
