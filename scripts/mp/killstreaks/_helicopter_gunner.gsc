#using scripts\codescripts\struct;

#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;
#using scripts\shared\_oob;
#using scripts\shared\popups_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\weapons\_hacker_tool;
#using scripts\shared\visionset_mgr_shared;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\teams\_teams;
#using scripts\mp\killstreaks\_remote_weapons;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "KILLSTREAK_EARNED_HELICOPTER_GUNNER" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUNNER_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUNNER_INBOUND" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUNNER_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_HELICOPTER_GUNNER" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUNNER_DAMAGED" );
#precache( "eventstring", "mpl_killstreak_osprey_strt" );

#namespace helicopter_gunner;
#define HELICOPTER_GUNNER_NAME 							"helicopter_gunner"
#define HELICOPTER_GUNNER_WEAPON_NAME					"helicopter_player_gunner"
#define HELICOPTER_GUNNER_ASSISTANT_NAME 				"helicopter_gunner_assistant"	
#define INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME 		"inventory_helicopter_gunner_assistant"	
	
#define INVALID_ASSISTANT_SEAT_INDEX 			-1
#define HELICOPTER_LEAVE_DELAY					2.0
	
#define REALLY_LONG_TIME_MS						9009009
	
function init()
{
	killstreaks::register( HELICOPTER_GUNNER_NAME, HELICOPTER_GUNNER_WEAPON_NAME, "killstreak_helicopter_player_gunner", "helicopter_used", &ActivateMainGunner, true );
	killstreaks::register_strings( HELICOPTER_GUNNER_NAME, &"KILLSTREAK_EARNED_HELICOPTER_GUNNER", &"KILLSTREAK_HELICOPTER_GUNNER_NOT_AVAILABLE", &"KILLSTREAK_HELICOPTER_GUNNER_INBOUND", undefined, &"KILLSTREAK_HELICOPTER_GUNNER_HACKED" );
	killstreaks::register_dialog( HELICOPTER_GUNNER_NAME, "mpl_killstreak_osprey_strt", "helicopterGunnerDialogBundle", "helicopterGunnerPilotDialogBundle", "friendlyHelicopterGunner", "enemyHelicopterGunner", "enemyHelicopterGunnerMultiple", "friendlyHelicopterGunnerHacked", "enemyHelecopterGunnerHacked", "requestHelicopterGunner", "threatHelicopterGunner" );
	killstreaks::register_alt_weapon( HELICOPTER_GUNNER_NAME, "helicopter_gunner_turret_rockets" );
	killstreaks::register_alt_weapon( HELICOPTER_GUNNER_NAME, "helicopter_gunner_turret_primary" );
	killstreaks::register_alt_weapon( HELICOPTER_GUNNER_NAME, "helicopter_gunner_turret_secondary" );
	killstreaks::register_alt_weapon( HELICOPTER_GUNNER_NAME, "helicopter_gunner_turret_tertiary" );
	killstreaks::set_team_kill_penalty_scale( HELICOPTER_GUNNER_NAME, level.teamKillReducedPenalty );
	
	killstreaks::register( HELICOPTER_GUNNER_ASSISTANT_NAME, HELICOPTER_GUNNER_ASSISTANT_NAME, "killstreak_" + HELICOPTER_GUNNER_ASSISTANT_NAME, "helicopter_used", &ActivateSupportGunner, true, undefined, false, false );
	killstreaks::register_strings( HELICOPTER_GUNNER_ASSISTANT_NAME, &"KILLSTREAK_EARNED_HELICOPTER_GUNNER", &"KILLSTREAK_HELICOPTER_GUNNER_NOT_AVAILABLE", &"KILLSTREAK_HELICOPTER_GUNNER_INBOUND", undefined, &"KILLSTREAK_HELICOPTER_GUNNER_HACKED" );
	killstreaks::register_dialog( HELICOPTER_GUNNER_ASSISTANT_NAME, "mpl_killstreak_osprey_strt", "helicopterGunnerDialogBundle", "helicopterGunnerPilotDialogBundle", "friendlyHelicopterGunner", "enemyHelicopterGunner", "enemyHelicopterGunnerMultiple", "friendlyHelicopterGunnerHacked", "enemyHelecopterGunnerHacked", "requestHelicopterGunner", "threatHelicopterGunner" );
	killstreaks::set_team_kill_penalty_scale( HELICOPTER_GUNNER_ASSISTANT_NAME, level.teamKillReducedPenalty );

	// TODO: Move to killstreak data
	level.killstreaks[HELICOPTER_GUNNER_NAME].threatOnKill = true;
	
	callback::on_connect( &OnPlayerConnect );
	callback::on_spawned( &UpdatePlayerState );
	callback::on_joined_team( &UpdatePlayerState );
	callback::on_joined_spectate( &UpdatePlayerState );
	callback::on_disconnect( &UpdatePlayerState );
	callback::on_player_killed( &UpdatePlayerState );
	
	clientfield::register( "vehicle", "vtol_turret_destroyed_0", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "vtol_turret_destroyed_1", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "mothership", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "vtol_update_client", VERSION_SHIP, 1, "counter" );
	clientfield::register( "toplayer", "fog_bank_2", VERSION_SHIP, 1, "int" );

	visionset_mgr::register_info( "visionset", MOTHERSHIP_VISIONSET_ALIAS, VERSION_SHIP, 70, 16, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false  );
		
	level thread WaitForGameEndThread();
	
	level.vtol = undefined;
}

function OnPlayerConnect()
{
	if( !isdefined( self.entNum ) )
	{
		self.entNum = self getEntityNumber();
	}
}

function UpdatePlayerState()
{
	player = self;
	UpdateAllKillstreakInventory();
}

function UpdateAllKillstreakInventory()
{
	foreach( player in level.players )
	{
		if( isdefined( player.sessionstate ) && player.sessionstate == "playing" )
			UpdateKillstreakInventory( player );
	}
}
	
function UpdateKillstreakInventory( player )
{
	if( !isdefined( player ) )
		return;
	
	heli_team = undefined;
	if( isdefined( level.vtol ) && isdefined( level.vtol.owner ) && !level.vtol.shuttingDown && ( level.vtol.totalRocketHits < HELICOPTER_GUNNER_HELICOPTER_MISSILES_TO_DESTROY ) )
		heli_team = level.vtol.owner.team;
	
	if( isdefined( heli_team ) && ( player.team == heli_team ) )
	{
		if( ( GetFirstAvailableSeat( player ) != INVALID_ASSISTANT_SEAT_INDEX ) && !isdefined( level.vtol.usage[player.entNum] ) )
		{
			if( !player killstreaks::has_killstreak( INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME ) )
				player killstreaks::give( INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME, undefined, undefined, true, true );
			return;
		}
	}

	if( player killstreaks::has_killstreak( INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME ) )
		player killstreaks::take( INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME );
}

function ActivateMainGunner( killstreakType )
{
	player = self;
	
	while( isdefined( level.vtol ) && level.vtol.shuttingdown )
	{
		if( !player killstreakrules::isKillstreakAllowed( HELICOPTER_GUNNER_NAME, player.team ) )
			return false;
	}

	player util::freeze_player_controls( true );
	
	result = player SpawnHeliGunner();
	
	player util::freeze_player_controls( false );
	
	if( level.gameEnded )
		return true;	
	
	if( !isdefined( result ) )
		return false;

	return result;
}

function ActivateSupportGunner( killstreakType )
{
	player = self;
	
	if( isdefined( level.vtol ) && level.vtol.shuttingdown )
		return false;

	if( isdefined( level.vtol.usage[player.entNum] ) )
		return false;
	
	player util::freeze_player_controls( true );	

	result = player EnterHelicopter( false );
	
	player util::freeze_player_controls( false );	

	return result;
}
	
function GetFirstAvailableSeat( player )
{
	if( isdefined( level.vtol ) && ( !level.vtol.shuttingDown ) && ( level.vtol.team == player.team ) && ( level.vtol.owner != player ) )
	{
		for( i = 0; i < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; i++ )
		{
			if( !isdefined( level.vtol.assistants[i].occupant ) && !level.vtol.assistants[i].destroyed )
			{
				return i;
			}
		}
	}
	
	return INVALID_ASSISTANT_SEAT_INDEX;
}

function InitHelicopterSeat( index, destroyTag )
{
	level.vtol.assistants[index] = SpawnStruct();
	assistant = level.vtol.assistants[index];
	
	assistant.occupant = undefined;
	assistant.destroyed = false;
	assistant.rocketHits = 0;
	assistant.targetTag = destroyTag;
	
	assistant.targetEnt = spawn( "script_model", ( 0, 0, 0 ) );
	assistant.targetEnt.useVTOLTime = true;	
	assistant.targetEnt SetModel( "p7_dogtags_enemy" ); // hack to send ent to clients for targeting
	assistant.targetEnt LinkTo( level.vtol, assistant.targetTag, ( 0, 0, 0 ), ( 0, 0, 0 ) );
	assistant.targetEnt.team = level.vtol.team;
	Target_Set( assistant.targetEnt, ( 0, 0, 0 ) );
	Target_SetAllowHighSteering( assistant.targetEnt, true );
	assistant.targetEnt.parent = level.vtol;
	
	level.vtol vehicle::add_to_target_group( assistant.targetEnt );
}

function HackedPreFunction( hacker )
{
	heliGunner = self;
	heliGunner.owner unlink();
	level.vtol clientfield::set( "vehicletransition", 0 );
	visionset_mgr::deactivate( "visionset", MOTHERSHIP_VISIONSET_ALIAS, heliGunner.owner );
	heliGunner.owner SetModelLodBias( 0 );
	heliGunner.owner clientfield::set_to_player( "fog_bank_2", 0 );
	heliGunner.owner clientfield::set_to_player( "toggle_flir_postfx", 0 );
	heliGunner.owner notify( "gunner_left" );	
	heliGunner.owner killstreaks::clear_using_remote();
	heliGunner.owner killstreaks::unhide_compass();
	heliGunner.owner vehicle::stop_monitor_missiles_locked_on_to_me();
	heliGunner.owner vehicle::stop_monitor_damage_as_occupant();

	foreach( assistant in heliGunner.assistants )
	{
		if( isdefined( assistant.occupant ) )
			assistant.occupant iPrintLnBold( &"KILLSTREAK_HELICOPTER_GUNNER_DAMAGED" );
		LeaveHelicopter( assistant.occupant, false );
	}
		
	heliGunner MakeVehicleUnusable();
}

function HackedPostFunction( hacker )
{
	heliGunner = self;
	heliGunner clientfield::set( "enemyvehicle", ENEMY_VEHICLE_HACKED );
	heliGunner MakeVehicleUsable();
	heliGunner UseVehicle( hacker, 0 );
	level.vtol clientfield::set( "vehicletransition", 1 );
	heliGunner thread vehicle::monitor_missiles_locked_on_to_me( hacker );
	heliGunner thread vehicle::monitor_damage_as_occupant( hacker );

	hacker thread WatchVisionSwitchThread();
	hacker killstreaks::hide_compass();
	heliGunner thread WatchPlayerExitRequestThread( hacker );
	visionset_mgr::activate( "visionset", MOTHERSHIP_VISIONSET_ALIAS, hacker, 1, heliGunner killstreak_hacking::get_hacked_timeout_duration_ms(), 1 );
	hacker SetModelLodBias( VAL( level.mothership_lod_bias, 8 ) );
	heliGunner.owner GiveDedicatedShadow( level.vtol );
	heliGunner.owner clientfield::set_to_player( "fog_bank_2", 1 );
	
	hacker thread WatchPlayerTeamChangeThread( heliGunner );
	hacker killstreaks::set_killstreak_delay_killcam( HELICOPTER_GUNNER_NAME );
	
	if ( heliGunner.killstreak_timer_started )
	{
		heliGunner.killstreak_duration = heliGunner killstreak_hacking::get_hacked_timeout_duration_ms();
		heliGunner.killstreak_end_time = hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( heliGunner );
		heliGunner.killstreakEndTime = int( heliGunner.killstreak_end_time );
	}
	else
	{
		heliGunner.killstreak_timer_start_using_hacked_time = true;
	}
}
	
function SpawnHeliGunner()
{
	player = self;
	player endon( "disconnect" );
	level endon( "game_ended" );
	
	if( !isdefined( level.heli_paths ) || !level.heli_paths.size )
		return false;

	if( !isdefined( level.Heli_primary_path ) || !level.heli_primary_path.size )
		return false;

	if( IS_TRUE( player.isPlanting ) || IS_TRUE( player.isDefusing ) || player util::isUsingRemote() || player IsWallRunning() || player oob::IsOutOfBounds() )
		return false;
	
	killstreak_id = player killstreakrules::killstreakStart( HELICOPTER_GUNNER_NAME, player.team, undefined, true );
	if( killstreak_id == INVALID_KILLSTREAK_ID )
		return false;
		
	startNode = level.heli_primary_path[0];
	
	level.vtol = SpawnVehicle( HELICOPTER_GUNNER_VEHICLE_NAME, startnode.origin, startnode.angles, "dynamic_spawn_ai" );
	level.vtol killstreaks::configure_team( HELICOPTER_GUNNER_NAME, killstreak_id, player, "helicopter" );
	level.vtol killstreak_hacking::enable_hacking( HELICOPTER_GUNNER_NAME, &HackedPreFunction, &HackedPostFunction );
	level.vtol.killstreak_id = killstreak_id;
	level.vtol.destroyFunc = &DeleteHelicopterCallback;
	level.vtol.hardpointType = HELICOPTER_GUNNER_NAME;
	level.vtol clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	level.vtol clientfield::set( "vtol_turret_destroyed_0", 0 );
	level.vtol clientfield::set( "vtol_turret_destroyed_1", 0 );	
	level.vtol clientfield::set( "mothership", 1 );	
	level.vtol vehicle::init_target_group();
	level.vtol.killstreak_timer_started = false;
	level.vtol.allowdeath = false;
	
	level.vtol.playerMovedRecently = false;
	level.vtol.soundmod = "default_loud";
	level.vtol hacker_tool::registerwithhackertool(HELICOPTER_GUNNER_HACKER_TOOL_RADIUS, HELICOPTER_GUNNER_HACKER_TOOL_DURATION );
	
	level.vtol.assistants = [];
	level.vtol.usage = [];
	
	InitHelicopterSeat( 0, HELICOPTER_GUNNER_ASSISTANT_0_TARGET_TAG );
	InitHelicopterSeat( 1, HELICOPTER_GUNNER_ASSISTANT_1_TARGET_TAG);
	
	level.destructible_callbacks["turret_destroyed"] = &VTOLDestructibleCallback;
	level.destructible_callbacks["turret1_destroyed"] = &VTOLDestructibleCallback;
	level.destructible_callbacks["turret2_destroyed"] = &VTOLDestructibleCallback;
	
	level.vtol.shuttingDown = false;
	level.vtol thread PlayLockOnSoundsThread( player, level.vtol );
	
	level.vtol thread helicopter::wait_for_killed();
	level.vtol thread wait_for_bda_dialog();
	
	level.vtol.maxhealth = HELICOPTER_GUNNER_HELICOPTER_HEALTH;
	tableHealth = killstreak_bundles::get_max_health( HELICOPTER_GUNNER_NAME );
	
	if ( isdefined( tableHealth ) )
	{
		level.vtol.maxhealth = tableHealth;
	}	
	level.vtol.original_health = level.vtol.maxhealth;
	level.vtol.health = level.vtol.maxhealth;
	
	level.vtol SetCanDamage( true );
	level.vtol thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "death" );
	level.vtol thread WatchMissilesThread();

	attack_nodes = GetEntArray( "heli_attack_area", "targetname" );
	if( attack_nodes.size )
	{
		level.vtol thread HelicopterThinkThread( startNode, attack_nodes );
		player thread WatchLocationChangeThread( attack_nodes );
	}
	else
	{
		level.vtol thread helicopter::heli_fly( startNode, 0.0, HELICOPTER_GUNNER_NAME );
	}
	
	level.vtol.totalRocketHits = 0;
	level.vtol.turretRocketHits = 0;
	level.vtol.targetEnt = undefined;
	
	level.vtol.overrideVehicleDamage = &HelicopterGunnerDamageOverride;	
	level.vtol.hackedHealthUpdateCallback = &HelicopterGunner_hacked_health_callback;
	level.vtol.DetonateViaEMP = &helicopteDetonateViaEMP;
	
	player thread killstreaks::play_killstreak_start_dialog( HELICOPTER_GUNNER_NAME, player.team, killstreak_id );
	level.vtol killstreaks::play_pilot_dialog_on_owner( "arrive", HELICOPTER_GUNNER_NAME, killstreak_id );
	
	player AddWeaponStat( GetWeapon( HELICOPTER_GUNNER_WEAPON_NAME ), "used", 1 );
		
	level.vtol thread WaitForVTOLShutdownThread();

	result = player EnterHelicopter( true );
	
	return result;
}

function HelicopterGunner_hacked_health_callback()
{
	helicopter = self;
	
	if ( helicopter.shuttingDown == true ) 
	{
		return;
	}
	
// Not sure what design wants here.  
//	for( seatIndex = 0; seatIndex < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; seatIndex++ )
//	{
//		assistant = helicopter.assistants[seatIndex];
//		if( !assistant.destroyed )
//		{
//			damage = 1000;
//			helicopter.noDamageFeedback = 1;
//			helicopter DoDamage( damage, assistant.targetEnt.origin, undefined, undefined, undefined, "MOD_UNKNOWN", 0, undefined, seatIndex + 8 );
//			helicopter.noDamageFeedback = 0;
//			
//			SupportTurretDestroyed( helicopter, seatIndex );
//		}
//	}
//	helicopter AllowMainTurretLockon();
	
	hackedHealth = killstreak_bundles::get_hacked_health( HELICOPTER_GUNNER_NAME );
	assert( isdefined( hackedHealth ) );
	if ( helicopter.health > hackedhealth )
	{
		helicopter.health = hackedhealth;	
	}
}


function WaitForGameEndThread()
{
	level waittill( "game_ended" );
	if( isdefined( level.vtol ) && isdefined( level.vtol.owner ))
		LeaveHelicopter( level.vtol.owner, true );
}

function WaitForVTOLShutdownThread()
{
	helicopter = self;
	helicopter waittill( "vtol_shutdown", attacker );
	
	if( isdefined( attacker ) )
	{
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_HELICOPTER_GUNNER", attacker.entnum );
	}
	
	if( isdefined( helicopter.targetEnt ) )
	{
		Target_Remove( helicopter.targetEnt );
		helicopter.targetEnt Delete();
		helicopter.targetEnt = undefined;
	}
	
	for( seatIndex = 0; seatIndex < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; seatIndex++ )
	{
		assistant = level.vtol.assistants[seatIndex];
		if( isdefined( assistant.targetEnt ) )
		{
			Target_Remove( assistant.targetEnt );
			assistant.targetEnt Delete();
			assistant.targetEnt = undefined;
		}
	}	
	
	killstreakrules::killstreakStop( HELICOPTER_GUNNER_NAME, helicopter.originalTeam, helicopter.killstreak_id );
	
	LeaveHelicopter( level.vtol.owner, true );	
	
	level.vtol = undefined;
	
	helicopter delete();
}

function DeleteHelicopterCallback()
{
	helicopter = self;
	helicopter notify( "vtol_shutdown", undefined );
}

function OnTimeoutCallback()
{
	for( i = 0; i < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; i++ )
	{
		if( isdefined(level.vtol.assistants[i].occupant )  )
		{
			level.vtol.assistants[i].occupant killstreaks::play_pilot_dialog( "timeout", HELICOPTER_GUNNER_NAME, undefined, level.vtol.killstreak_id );
		}
	}
	
	LeaveHelicopter( level.vtol.owner, true );
}

function WatchPlayerTeamChangeThread( helicopter )
{
	helicopter notify( "mothership_team_change" );
	helicopter endon ( "mothership_team_change" );
	
	assert( IsPlayer( self ) );
	player = self;
	
	player endon( "gunner_left" );
	
	player util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	
	ownerLeft = helicopter.ownerEntNum == player.entNum;
	
	player thread LeaveHelicopter( player, ownerLeft ); // need to thread to prevent endon( "gunner_left" ) to terminate the LeaveHelicopter
	
	if( ownerLeft )
		helicopter notify( "vtol_shutdown", undefined );	
}

function WatchPlayerExitRequestThread( player )
{
	player notify( "WatchPlayerExitRequestThread_singleton" );
	player endon ( "WatchPlayerExitRequestThread_singleton" );
	assert( IsPlayer( player ) );
	mothership = self;
	
	level endon( "game_ended" );
	player endon( "disconnect" );
	player endon( "gunner_left" );

	owner = mothership.ownerEntNum == player.entNum;
	
	while( true )
	{
		timeUsed = 0;
		while( player UseButtonPressed() )
		{
			timeUsed += 0.05;
			if( timeUsed > 0.25 )
			{
				mothership killstreaks::play_pilot_dialog_on_owner( "remoteOperatorRemoved", HELICOPTER_GUNNER_NAME, level.vtol.killstreak_id );
				player thread LeaveHelicopter( player, owner ); // need to thread this so that endon( "gunner_left" ) does not self termniate in LeaveHelicopter()
				return;
			}
			WAIT_SERVER_FRAME;
		}
		WAIT_SERVER_FRAME;
	}	
}

function EnterHelicopter( isOwner )
{
	assert( IsPlayer( self ) );
	player = self;
	
	seatIndex = INVALID_ASSISTANT_SEAT_INDEX;
	if( !isOwner )
	{
		seatIndex = GetFirstAvailableSeat( player );
		if( seatIndex == INVALID_ASSISTANT_SEAT_INDEX )
		{
			return false;
		}
		level.vtol.assistants[ seatIndex ].occupant = player;
	}
	
	level.vtol.occupied = true; // needed for killcam to function properly

	player util::setUsingRemote( HELICOPTER_GUNNER_NAME );
	player.ignoreEMPJammed = true;
	result = player killstreaks::init_ride_killstreak( HELICOPTER_GUNNER_NAME );	
	player.ignoreEMPJammed = false;
	if( result != "success" )
	{
		if( result != "disconnect" )
		{
			player killstreaks::clear_using_remote();
		}
		
		if( !isOwner )
			level.vtol.assistants[ seatIndex ].occupant = undefined;
		
		if( isOwner )
		{
			level.vtol.failed2enter = true;
			level.vtol notify( "vtol_shutdown" );
		}

		return false;
	}
	
	if( isOwner )
	{
		level.vtol UseVehicle( player, 0 );
		level.vtol clientfield::set( "vehicletransition", 1 );
	}
	else
	{
		if( level.vtol.shuttingdown )
		{
			player killstreaks::clear_using_remote();
			return false;
		}
		level.vtol UseVehicle( player, seatIndex + HELICOPTER_GUNNER_ASSISTANT_SEAT_START_INDEX );
		level.vtol clientfield::set( "vehicletransition", 1 );
		
		level.vtol killstreaks::play_pilot_dialog_on_owner( "remoteOperatorAdd", HELICOPTER_GUNNER_NAME, level.vtol.killstreak_id );
	}

	killcament = spawn( "script_model", ( 0, 0, 0 ) );
	killcament SetModel( "tag_origin" );
	killcament.angles = ( 0, 0, 0 );
	killcament SetWeapon( GetWeapon( "helicopter_gunner_turret_primary" ) );
	killcament linkto( level.vtol, "tag_barrel", ( 370, 0, 25 ), ( 0, 0, 0 ) );		
	level.vtol.killcament = killcament;
	
	level.vtol.usage[player.entNum] = 1;
	
	level.vtol thread audio::sndUpdateVehicleContext(true);
	
	level.vtol thread vehicle::monitor_missiles_locked_on_to_me( player );
	level.vtol thread vehicle::monitor_damage_as_occupant( player );
	
	if ( level.vtol.killstreak_timer_started )
	{
		player vehicle::set_vehicle_drivable_time( level.vtol.killstreak_duration, level.vtol.killstreak_end_time );
	}
	else
	{
		player vehicle::set_vehicle_drivable_time( REALLY_LONG_TIME_MS, GetTime() + REALLY_LONG_TIME_MS );
	}
	
	update_client_for_player( player );
	
	UpdateAllKillstreakInventory();
	
	player thread WatchVisionSwitchThread();
	level.vtol thread WatchPlayerExitRequestThread( player );
	player thread WatchPlayerTeamChangeThread( level.vtol );
	
	visionset_mgr::activate( "visionset", MOTHERSHIP_VISIONSET_ALIAS, player, 1, HELICOPTER_GUNNER_DURATION, 1 );
	player SetModelLodBias( VAL( level.mothership_lod_bias, 8 ) );
	player GiveDedicatedShadow( level.vtol );
	player clientfield::set_to_player( "fog_bank_2", 1 );
	
	if ( HELICOPTER_GUNNER_HIDE_COMPASS_ON_REMOTE_CONTROL )
	{
		player thread HideCompassAfterWait( 0.1 ); // need to do this due to the way this scorestreak starts up
	}
	
	return true;
}

function HideCompassAfterWait( waittime )
{
	self endon( "death" );
	self endon( "disconnect" );
	
	wait waittime;
	
	self killstreaks::hide_compass();
}

function MainTurretDestroyed( helicopter, eAttacker, weapon )
{
	helicopter.owner iPrintLnBold( &"KILLSTREAK_HELICOPTER_GUNNER_DAMAGED" );
		
	if ( isdefined(helicopter.targetEnt))
    {
		Target_Remove( helicopter.targetEnt );
		helicopter.targetEnt Delete();
		helicopter.targetEnt = undefined;
    }
	helicopter.shuttingDown = true;
	UpdateAllKillstreakInventory();
	
	eAttacker = self [[ level.figure_out_attacker ]]( eAttacker );
	if( !isdefined( helicopter.destroyScoreEventGiven ) && isdefined( eAttacker ) && ( !isdefined( helicopter.owner ) || helicopter.owner util::IsEnemyPlayer( eAttacker ) ) )
	{
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_HELICOPTER_GUNNER_DAMAGED", eAttacker.entnum );
		challenges::destroyedAircraft( eAttacker, weapon, true );
		eAttacker challenges::addFlySwatterStat( weapon, helicopter );
		scoreevents::processScoreEvent( "destroyed_vtol_mothership", eAttacker, helicopter.owner, weapon );
		helicopter killstreaks::play_destroyed_dialog_on_owner( HELICOPTER_GUNNER_NAME, helicopter.killstreak_id );
		helicopter.destroyScoreEventGiven = 1;
	}

	helicopter thread PerformLeaveHelicopterFromDamage();
}

function wait_for_bda_dialog( killstreakId )
{
	self endon( "vtol_shutdown" );
	
	while(true)
	{
		self waittill( "bda_dialog", dialogKey );
		
		for( i = 0; i < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; i++ )
		{
			if( isdefined( level.vtol.assistants[i].occupant )  )
			{
				level.vtol.assistants[i].occupant killstreaks::play_pilot_dialog( dialogKey, HELICOPTER_GUNNER_NAME, killstreakId, self.pilotIndex );
			}
		}
	}
}

function SupportTurretDestroyed( helicopter, seatIndex )
{
	assistant = helicopter.assistants[seatIndex];
	if( !assistant.destroyed )
	{
		Target_Remove( assistant.targetEnt );
		level.vtol vehicle::remove_from_target_group();

		assistant.targetEnt Delete();
		assistant.targetEnt = undefined;
		assistant.destroyed = true;
		
		if ( isdefined( helicopter.owner ) && isdefined( helicopter.hardpointType ) )
		{
			helicopter killstreaks::play_pilot_dialog_on_owner( "weaponDestroyed", helicopter.hardpointType, helicopter.killstreak_id );
		}
		
		if( isdefined( assistant.occupant ) )
		{
			assistant.occupant globallogic_audio::flush_killstreak_dialog_on_player( helicopter.killstreak_id );
			assistant.occupant killstreaks::play_pilot_dialog( "weaponDestroyed", helicopter.hardpointType, undefined, helicopter.pilotIndex );
			wait HELICOPTER_LEAVE_DELAY;
			LeaveHelicopter( assistant.occupant, false );
		}
	}
	
	// update destroyed states
	
	if ( seatIndex == 0 )
	{
		level.vtol clientfield::set( "vtol_turret_destroyed_0", 1 );
		level.vtol update_client_for_driver_and_occupants();
	}
	else if ( seatIndex == 1 )
	{
		level.vtol clientfield::set( "vtol_turret_destroyed_1", 1 );
		level.vtol update_client_for_driver_and_occupants();
	}
}

function update_client_for_driver_and_occupants() // self == vtol
{
	vtol = self;
	
	update_client_for_player( vtol.owner );

	foreach( assistant in vtol.assistants )
	{
		update_client_for_player( assistant.occupant );
	}
}

function update_client_for_player( player )
{
	if ( isdefined( player ) )
	{
		player clientfield::increment_to_player( "vtol_update_client", 1 );
	}
}

function VTOLDestructibleCallback( brokenNotify, eAttacker, weapon )
{
	helicopter = self;
	
	helicopter endon ( "delete" );
	helicopter endon ( "vtol_shutdown" );
	
	notifies = [];
	notifies[0] = "turret1_destroyed";
	notifies[1] = "turret2_destroyed";
	
	for( seatIndex = 0; seatIndex < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; seatIndex++ )
	{
		if( brokenNotify == notifies[seatIndex] )
		{
			SupportTurretDestroyed( helicopter, seatIndex );
			break;
		}
	}
	
	if( brokenNotify == "turret_destroyed" )
	{
		MainTurretDestroyed( helicopter, eAttacker, weapon );
		return;
	}
	
	helicopter AllowMainTurretLockon();
}

function AllowMainTurretLockon()
{	
	helicopter = self;
	
	// allow lockon on the main turrets
	if( helicopter.assistants[0].destroyed && helicopter.assistants[1].destroyed )
	{
		if( !isdefined( helicopter.targetEnt ) )
		{
			helicopter.targetEnt = spawn( "script_model", ( 0, 0, 0 ) );
			helicopter.targetEnt SetModel( "p7_dogtags_enemy" ); // hack to send ent to clients for targeting
			helicopter.targetEnt LinkTo( level.vtol, "tag_barrel", ( 0, 0, 0 ), ( 0, 0, 0 ) );
			helicopter.targetEnt.parent = level.vtol;
			helicopter.targetEnt.team = level.vtol.team;
			Target_Set( helicopter.targetEnt, ( 0, 0, 0 ) );	
			helicopter.targetEnt.useVTOLTime = true;
			Target_SetAllowHighSteering( helicopter.targetEnt, true );
			
			level.vtol vehicle::add_to_target_group( helicopter.targetEnt );
		} 
	}
}

function LeaveHelicopter( player, ownerLeft )
{
	if( !isdefined( level.vtol ) || level.vtol.completely_shutdown === true )
		return;

	if( isdefined( player ) )
	{
		player vehicle::stop_monitor_missiles_locked_on_to_me();
		player vehicle::stop_monitor_damage_as_occupant();
	}
	
	if( isdefined( player ) && isdefined( level.vtol ) && isdefined( level.vtol.owner ) )
	{
		if( isdefined( player.usingvehicle ) && player.usingvehicle )
		{
			player unlink();
			level.vtol clientfield::set( "vehicletransition", 0 );
			
			if( ownerLeft )
				player killstreaks::take( HELICOPTER_GUNNER_NAME );
			else
				player killstreaks::take( INVENTORY_HELICOPTER_GUNNER_ASSISTANT_NAME );
		}
	}
	
	if( ownerLeft )
	{
		level.vtol.shuttingDown = true;
		foreach( assistant in level.vtol.assistants )
		{
			if( isdefined( assistant.occupant ) )
			{
				assistant.occupant iPrintLnBold( &"KILLSTREAK_HELICOPTER_GUNNER_DAMAGED" );
				LeaveHelicopter( assistant.occupant, false );
			}
		}
		
		level.vtol.occupied = false;		
		level.vtol.hardpointType = HELICOPTER_GUNNER_NAME;
		level.vtol thread helicopter::heli_leave();
		level.vtol thread audio::sndUpdateVehicleContext(false);
	}
	else
	{
		if( isdefined( player ) )
		{
			player globallogic_audio::flush_killstreak_dialog_on_player( level.vtol.killstreak_id );
			
			foreach( assistant in level.vtol.assistants )
			{
				if( isdefined( assistant.occupant ) && assistant.occupant == player )
				{
					assistant.occupant = undefined;
					break;
				}		
			}		
		}
	}
	
	if( isdefined( player ) )
	{
		player clientfield::set_to_player( "toggle_flir_postfx", 0 );
		visionset_mgr::deactivate( "visionset", MOTHERSHIP_VISIONSET_ALIAS, player );
		player SetModelLodBias( 0 );
		player GiveDedicatedShadow( player );

		player clientfield::set_to_player( "fog_bank_2", 0 );
		player killstreaks::unhide_compass();
		
		player notify( "gunner_left" );	
		
		player killstreaks::clear_using_remote();
		
		if( level.gameEnded )
			player util::freeze_player_controls( true );
	}
	
	UpdateAllKillstreakInventory();

	if ( ownerLeft )
		level.vtol.completely_shutdown = true;
}

function vtol_shake()
{
	if( isdefined( level.vtol ) && isdefined( level.vtol.owner ) )
	{
		org = level.vtol GetTagOrigin( "tag_barrel" );

		magnitude = 0.3;
		duration = 2;
		radius = 500;
		v_pos = self.origin;
		Earthquake( magnitude, duration, org, 500 );
	}
}


function HelicopterGunnerDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	helicopter = self;
	
	if( sMeansOfDeath == "MOD_TRIGGER_HURT" )
		return 0;
	
	if( helicopter.shuttingDown )
		return 0;

	iDamage = self killstreaks::OnDamagePerWeapon( HELICOPTER_GUNNER_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, level.vtol.maxhealth, undefined, level.vtol.maxhealth*0.4, undefined, 0, undefined, true, 1.0 );
	if( iDamage == 0 )
		return 0;
	
	// handle rocket damage
	handleAsRocketDamage = ( ( sMeansOfDeath == "MOD_PROJECTILE" ) || ( sMeansOfDeath == "MOD_EXPLOSIVE" ) );
	if ( weapon.statIndex == level.weaponShotgunEnergy.statIndex || weapon.statIndex == level.weaponPistolEnergy.statIndex || weapon.statIndex == level.weaponSmgNailGun.statIndex )
		handleAsRocketDamage = false;

	if( handleAsRocketDamage )
	{
		updateInventory = 1;
		
		missileTarget = eInflictor missile_gettarget();
		
		vtol_shake();
		
		rocketHit = 1.0;
		if ( weapon.statIndex == level.weaponLauncherMulti.statIndex )
			rocketHit = 0.5;
					
		helicopter.totalRocketHits += rocketHit;
		
		if( isdefined( missileTarget ) ) 
		{
			// handle rocket damage to the support turrets
			for( seatIndex = 0; seatIndex < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; seatIndex++ )
			{
				assistant = helicopter.assistants[seatIndex];
				
				if( !assistant.destroyed && ( assistant.targetEnt == missileTarget ) )
				{
					assistant.rocketHits += rocketHit;
					
					if ( assistant.rocketHits >= 2 )
					{
						helicopter DoDamage( iDamage, assistant.targetEnt.origin, eAttacker, eInflictor, sHitLoc, "MOD_UNKNOWN", 0, weapon, seatIndex + 8 );
						iDamage = 0;
						SupportTurretDestroyed( helicopter, seatIndex );
					}
				}
			}	
	
			// handle rocket damage to the main turrets
			if( isdefined( helicopter.targetEnt ) && ( helicopter.targetEnt == missileTarget ) )
			{
				helicopter.turretRocketHits += rocketHit;
				
				// main turret need 2 rockets
				if( helicopter.turretRocketHits >= 2 )
				{
					Target_Remove( helicopter.targetEnt );
					helicopter.targetEnt Delete();
					helicopter.targetEnt = undefined;			
				}
			}
		}
		
		// allow lockon on the main turret
		if( helicopter.assistants[0].destroyed && helicopter.assistants[1].destroyed && ( !isdefined( helicopter.targetEnt ) ) )
		{
			helicopter.targetEnt = spawn( "script_model", ( 0, 0, 0 ) );
			helicopter.targetEnt SetModel( "p7_dogtags_enemy" ); // hack to send ent to clients for targeting
			helicopter.targetEnt LinkTo( level.vtol, "tag_barrel", ( 0, 0, 0 ), ( 0, 0, 0 ) );
			helicopter.targetEnt.parent = level.vtol;
			helicopter.targetEnt.team = level.vtol.team;
			Target_Set( helicopter.targetEnt, ( 0, 0, 0 ) );	
			helicopter.targetEnt.useVTOLTime = true;
			Target_SetAllowHighSteering( helicopter.targetEnt, true );
		}
		
		if( helicopter.totalRocketHits >= HELICOPTER_GUNNER_HELICOPTER_MISSILES_TO_DESTROY )
		{
			MainTurretDestroyed( helicopter, eAttacker, weapon );
			updateInventory = 0;
		}
		
		if ( updateInventory )
			UpdateAllKillstreakInventory();
	}
	
	if( iDamage >= level.vtol.health && !helicopter.shuttingDown )
	{
		helicopter.shuttingDown = true;
		UpdateAllKillstreakInventory();
		
		if ( !isdefined( helicopter.destroyScoreEventGiven ) && isdefined( eAttacker ) && ( !isdefined( helicopter.owner ) || helicopter.owner util::IsEnemyPlayer( eAttacker ) ) )
		{
			eAttacker = self [[ level.figure_out_attacker ]]( eAttacker );
			LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_HELICOPTER_GUNNER_DAMAGED", eAttacker.entnum );
			scoreevents::processScoreEvent( "destroyed_vtol_mothership", eAttacker, helicopter.owner, weapon );
			helicopter killstreaks::play_destroyed_dialog_on_owner( HELICOPTER_GUNNER_NAME, helicopter.killstreak_id );
			helicopter.destroyScoreEventGiven = 1;
		}
		
		helicopter thread PerformLeaveHelicopterFromDamage();
	}
	
	if( helicopter.shuttingDown )
	{
		if( iDamage >= helicopter.health )
			iDamage = helicopter.health - 1; // keep it alive. We want it to go away not explode
	}

	///#iprintln( partName + " health:" + helicopter.health + " damage:" + iDamage );#/
	return iDamage;
}

function PerformLeaveHelicopterFromDamage()
{
	helicopter = self;
	helicopter endon( "death" );

	if ( self.leave_by_damage_initiated === true )
		return;

	self.leave_by_damage_initiated = true;

	helicopter thread remote_weapons::do_static_fx();
	failsafe_timeout = 5.0;
	helicopter util::waittill_any_timeout( failsafe_timeout, "static_fx_done" );
	LeaveHelicopter( helicopter.owner, true );
}

function helicopteDetonateViaEMP( attacker, weapon )
{
	MainTurretDestroyed( level.vtol, attacker, weapon );
}

function MissileCleanupThread( missile )
{
	targetEnt = self;
	
	targetEnt endon( "delete" );
	targetEnt endon( "death" );
		
	missile util::waittill_any( "death", "delete" );
	
	targetEnt Delete();
}

function WatchMissilesThread()
{
	helicopter = self;
	player = helicopter.owner;
	
	player endon( "disconnect" );
	player endon( "gunner_left" );
	
	heliMissile = GetWeapon( "helicopter_gunner_turret_rockets" );
	
	while( true )
	{
		player waittill( "missile_fire", missile );

		trace_origin = level.vtol GetTagOrigin( "tag_flash" );
		trace_direction = level.vtol GetTagAngles( "tag_barrel" );
		trace_direction = AnglesToForward( trace_direction ) * 8000;
		trace = BulletTrace( trace_origin, trace_origin + trace_direction, false, level.vtol );
		end_origin = trace["position"];
		
		missiles  = getentarray( "rocket", "classname" );
		
		/#
		//Box( end_origin, (-4, -4, 0 ), ( 4, 4, 1000 ), 0, ( 0, 0.7, 0 ), 0.6, false, 9999999 );
		#/
			
		foreach( missile in missiles )
		{
			if( missile.item == heliMissile )
			{
				targetEnt = Spawn( "script_model", end_origin );
				missile Missile_SetTarget( targetEnt );
				targetEnt thread MissileCleanupThread( missile );
			}
		}
		
		// setup the "reload" time for the player's vehicle HUD
		weapon_wait_duration_ms = Int( heliMissile.fireTime * 1000 );
		player SetVehicleWeaponWaitDuration( weapon_wait_duration_ms );
		player SetVehicleWeaponWaitEndTime( GetTime() + weapon_wait_duration_ms );
	}
}

function WatchVisionSwitchThread()
{
	assert( IsPlayer( self ) );
	player = self;
	
	player endon( "disconnect" );
	player endon( "gunner_left" );
	
	inverted = false;
	player clientfield::set_to_player( "toggle_flir_postfx", 2 );

	while( true )
	{
		if( player JumpButtonPressed() )
		{
			if( inverted )
			{
				player clientfield::set_to_player( "toggle_flir_postfx", 2 );
				player PlaySoundToPlayer( "mpl_cgunner_flir_off", player );
			}
			else
			{
				player clientfield::set_to_player( "toggle_flir_postfx", 1 );
				player PlaySoundToPlayer( "mpl_cgunner_flir_on", player );
			}

			inverted = !inverted;
			
			while( player JumpButtonPressed() )
				WAIT_SERVER_FRAME;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function PlayLockOnSoundsThread( player, heli )
{
	player endon( "disconnect" );
	player endon( "gunner_left" );
	
	heli endon( "death" );
	heli endon ( "crashing" );
	heli endon ( "leaving" );
	
	heli.lockSounds = spawn( "script_model", heli.origin );
	wait ( 0.1 );
	heli.lockSounds LinkTo( heli, "tag_player" );
	
	while( true )
	{
		heli waittill( "locking on" );
		
		while( true )
		{
			if( EnemyIsLocking( heli ) )
			{
				heli.lockSounds PlaySoundToPlayer( "uin_alert_lockon", player );
				wait ( 0.125 );
			}
			
			if( EnemyLockedOn( heli ) )
			{
				heli.lockSounds PlaySoundToPlayer( "uin_alert_lockon", player );
				wait ( 0.125 );
			}
			
			if( !EnemyIsLocking( heli ) && !EnemyLockedOn( heli ) )
			{
				heli.lockSounds StopSounds();
				break;
			}			
		}
	}
}

function EnemyIsLocking( heli )
{
	return ( isdefined( heli.locking_on ) && heli.locking_on );
}

function EnemyLockedOn( heli )
{
	return ( isdefined( heli.locked_on ) && heli.locked_on );
}

function HelicopterThinkThread( startNode, destNodes )
{
	self notify( "flying");
	self endon( "flying" );

	self endon ( "death" );
	self endon ( "crashing" );
	self endon ( "leaving" );

	nextnode = getent( startNode.target, "targetname" );
	assert( isdefined( nextnode ), "Next node in path is undefined, but has targetname" );
	self SetSpeed( 150, 80 );	
	self setvehgoalpos( nextnode.origin + ( 0, 0, HELICOPTER_GUNNER_Z_OFFSET ), 1 );
	self waittill( "near_goal" );
	
	firstpass = true;
	//while( true )
	{
		if( !self.playerMovedRecently )
		{
			node = self UpdateAreaNodes( destNodes, false );
			level.vtol.currentNode = node;
			targetNode = getEnt( node.target, "targetname" );
		
			TravelToNode( targetNode );
			
			if( isdefined( targetNode.script_airspeed ) && isdefined( targetNode.script_accel ) )
			{
				heli_speed = targetNode.script_airspeed;
				heli_accel = targetNode.script_accel;
			}
			else
			{
				heli_speed = 150+randomInt(20);
				heli_accel = 40+randomInt(10);
			}
			
			self SetSpeed( heli_speed, heli_accel );	
			self setvehgoalpos( targetNode.origin + ( 0, 0, HELICOPTER_GUNNER_Z_OFFSET ), 1 );
			self setgoalyaw( targetNode.angles[ 1 ] + HELICOPTER_GUNNER_ANGLE_OFFSET );	
		}

		if( HELICOPTER_GUNNER_FORCED_WAIT != 0 )
		{
			self waittill( "near_goal" );
			waitTime = HELICOPTER_GUNNER_FORCED_WAIT;
		}
		else if( !isdefined( targetNode.script_delay ) )
		{
			self waittill( "near_goal" );
			waitTime = 10 + randomInt( 5 );
		}
		else
		{				
			self waittillmatch( "goal" );				
			waitTime = targetNode.script_delay;
		}
		
		if( firstpass )
		{
			self.killstreak_duration = ( ( self.killstreak_timer_start_using_hacked_time === true ) ? self killstreak_hacking::get_hacked_timeout_duration_ms() : HELICOPTER_GUNNER_DURATION );
			self.killstreak_end_time = GetTime() + self.killstreak_duration;
			self.killstreakEndTime = int( self.killstreak_end_time );
			self thread killstreaks::WaitForTimeout( HELICOPTER_GUNNER_NAME, self.killstreak_duration, &OnTimeoutCallback, "delete", "death" );
			self.killstreak_timer_started = true;
			self UpdateDrivableTimeForAllOccupants( self.killstreak_duration, self.killstreak_end_time );
	
			firstpass = false;
		}

		wait( waitTime );
	}
}

function UpdateDrivableTimeForAllOccupants( duration_ms, end_time_ms ) // self == vtol
{
	if ( isdefined( self.owner ) )
	{
		self.owner vehicle::set_vehicle_drivable_time( duration_ms, end_time_ms );
	}
	
	for( i = 0; i < HELICOPTER_GUNNER_ASSISTANT_SEAT_COUNT; i++ )
	{
		if( isdefined( self.assistants[i].occupant ) && !self.assistants[i].destroyed )
		{
			 self.assistants[i].occupant vehicle::set_vehicle_drivable_time( duration_ms, end_time_ms );
		}
	}
}

function WatchLocationChangeThread( destNodes )
{
	player = self;
	
	player endon( "disconnect" );
	player endon( "gunner_left" );

	helicopter = level.vtol;
	
	helicopter endon ( "delete" );
	helicopter endon ( "vtol_shutdown" );
	
	player.moves = 0;
	helicopter waittill ( "near_goal" );
	helicopter waittill ( "goal" );
	
	while( true )
	{
		if( self SecondaryOffhandButtonPressed() )
		{
			player.moves++;
			player thread SetPlayerMovedRecentlyThread();
			node = self UpdateAreaNodes( destNodes, true );
			helicopter.currentNode = node;
			targetNode = getEnt( node.target, "targetname" );
			
			player playlocalsound ( "mpl_cgunner_nav" );
			helicopter TravelToNode( targetNode );
			
			if( isdefined( targetNode.script_airspeed ) && isdefined( targetNode.script_accel ) )
			{
				heli_speed = targetNode.script_airspeed;
				heli_accel = targetNode.script_accel;
			}
			else
			{
				heli_speed = 80+randomInt(20);
				heli_accel = 40+randomInt(10);
			}
			
			helicopter SetSpeed( heli_speed, heli_accel );	
			helicopter setvehgoalpos( targetNode.origin + ( 0, 0, HELICOPTER_GUNNER_Z_OFFSET ), 1 );
			helicopter setgoalyaw( targetNode.angles[ 1 ] + HELICOPTER_GUNNER_ANGLE_OFFSET );
	
			helicopter waittill( "goal" );
						
			// wait for the button to release:
			while ( self SecondaryOffhandButtonPressed() )
			{
				WAIT_SERVER_FRAME;
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}

function SetPlayerMovedRecentlyThread()
{
	player = self;
	
	player endon( "disconnect" );
	player endon( "gunner_left" );

	helicopter = level.vtol;
	
	helicopter endon ( "delete" );
	helicopter endon ( "vtol_shutdown" );
	
	myMove = self.moves;
	level.vtol.playerMovedRecently = true;
	wait ( 100 );
	
	//only remove the flag if I am still the most recent move
	if( myMove == self.moves && isdefined( level.vtol ) )
	{
		level.vtol.playerMovedRecently = false;
	}
}

function UpdateAreaNodes( areaNodes, forceMove )
{
	validEnemies = [];

	foreach( node in areaNodes )
	{
		node.validPlayers = [];
		node.nodeScore = 0;
	}
	
	foreach( player in level.players )
	{
		if( !isAlive( player ) )
		{
			continue;
		}

		if( player.team == self.team )
		{
			continue;
		}
		
		foreach( node in areaNodes )
		{
			if( distanceSquared( player.origin, node.origin ) > 1048576 )
			{
				continue;
			}
								
			node.validPlayers[node.validPlayers.size] = player;
		}
	}
	
	bestNode = undefined;
	foreach ( node in areaNodes )
	{
		if( isdefined( level.vtol.currentNode ) && ( node == level.vtol.currentNode ) )
		{
			continue;
		}
		
		heliNode = getEnt( node.target, "targetname" );
		foreach( player in node.validPlayers )
		{
			node.nodeScore += 1;
			
			if( bulletTracePassed( player.origin + (0,0,32), heliNode.origin, false, player ) )
			{
				node.nodeScore += 3;
			}
		}
				
		if( forceMove && ( distance( level.vtol.origin, heliNode.origin ) < 200 ) )
		{
			node.nodeScore = -1;
		}
		
		if( !isdefined( bestNode ) || ( node.nodeScore > bestNode.nodeScore ) )
		{
			bestNode = node;
		}
	}
	
	return bestNode;
}

function TravelToNode( goalNode )
{
	originOffets = GetOriginOffsets( goalNode );
	
	if( originOffets["start"] != self.origin )
	{
		if( isdefined( goalNode.script_airspeed ) && isdefined( goalNode.script_accel ) )
		{
			heli_speed = goalNode.script_airspeed;
			heli_accel = goalNode.script_accel;
		}
		else
		{
			heli_speed = 30 + randomInt(20);
			heli_accel = 15 + randomInt(15);
		}
		
		self SetSpeed( heli_speed, heli_accel );
		self setvehgoalpos( originOffets["start"] + (0,0,30), 0 );
		self setgoalyaw( goalNode.angles[ 1 ] + HELICOPTER_GUNNER_ANGLE_OFFSET );
		
		self waittill ( "goal" );
	}
	
	if( originOffets["end"] != goalNode.origin )
	{
		if( isdefined( goalNode.script_airspeed ) && isdefined( goalNode.script_accel ) )
		{
			heli_speed = goalNode.script_airspeed;
			heli_accel = goalNode.script_accel;
		}
		else
		{
			heli_speed = 30+randomInt(20);
			heli_accel = 15+randomInt(15);
		}
		
		self SetSpeed( heli_speed, heli_accel );
		self setvehgoalpos( originOffets["end"] + (0,0,30), 0 );
		self setgoalyaw( goalNode.angles[ 1 ] + HELICOPTER_GUNNER_ANGLE_OFFSET );
		
		self waittill ( "goal" );
	}
}

function GetOriginOffsets( goalNode )
{
	startOrigin = self.origin;
	endOrigin = goalNode.origin;
	
	numTraces = 0;
	maxTraces = 40;
	
	traceOffset = (0,0,-196);
	
	traceOrigin = BulletTrace( startOrigin+traceOffset, endOrigin+traceOffset, false, self );

	while( DistanceSquared( traceOrigin[ "position" ], endOrigin+traceOffset ) > 10 && numTraces < maxTraces )
	{	
		/#println( "trace failed: " + DistanceSquared( traceOrigin[ "position" ], endOrigin+traceOffset ) );#/
			
		if( startOrigin[2] < endOrigin[2] )
		{
			startOrigin += (0,0,128);
		}
		else if( startOrigin[2] > endOrigin[2] )
		{
			endOrigin += (0,0,128);
		}
		else
		{	
			startOrigin += (0,0,128);
			endOrigin += (0,0,128);
		}

		numTraces++;
		traceOrigin = BulletTrace( startOrigin+traceOffset, endOrigin+traceOffset, false, self );
	}
	
	offsets = [];
	offsets["start"] = startOrigin;
	offsets["end"] = endOrigin;
	return offsets;
}