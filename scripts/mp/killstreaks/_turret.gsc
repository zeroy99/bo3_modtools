#using scripts\codescripts\struct;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_placeables;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\teams\_teams;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\turret_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "KILLSTREAK_EARNED_AUTO_TURRET" );
#precache( "string", "KILLSTREAK_AUTO_TURRET_INBOUND" );
#precache( "string", "KILLSTREAK_AUTO_TURRET_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_AUTO_TURRET_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_AUTO_TURRET" );
#precache( "triggerstring", "KILLSTREAK_AUTO_TURRET_PLACE_TURRET_HINT" );
#precache( "triggerstring", "KILLSTREAK_AUTO_TURRET_INVALID_TURRET_LOCATION" );
#precache( "triggerstring", "KILLSTREAK_SENTRY_TURRET_PICKUP" );
#precache( "triggerstring", "MP_REMOTE_USE_TURRET" );
#precache( "string", "mpl_killstreak_auto_turret" );

#using_animtree( "mp_autoturret" );

#define TURRET_NAME "autoturret"
#define TURRET_SCAN_ANGLE_BUFFER	10
#define TURRET_SCAN_WAIT			2.5
#define PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION_TU1	5000	// tu1: make sure this matches the same value in placeables.gsc

#namespace turret;

function init()
{
	killstreaks::register( "autoturret", "autoturret", "killstreak_auto_turret", "auto_turret_used", &ActivateTurret );
	killstreaks::register_alt_weapon( "autoturret", "auto_gun_turret" );
	killstreaks::register_remote_override_weapon( "autoturret", "killstreak_remote_turret" );
	killstreaks::register_strings( "autoturret", &"KILLSTREAK_EARNED_AUTO_TURRET", &"KILLSTREAK_AUTO_TURRET_NOT_AVAILABLE", &"KILLSTREAK_AUTO_TURRET_INBOUND", undefined, &"KILLSTREAK_AUTO_TURRET_HACKED", false );
	killstreaks::register_dialog( TURRET_NAME, "mpl_killstreak_auto_turret", "turretDialogBundle", undefined, "friendlyTurret", "enemyTurret", "enemyTurretMultiple", "friendlyTurretHacked", "enemyTurretHacked", "requestTurret", "threatTurret" );
			
	// TODO: Move to killstreak data
	level.killstreaks[TURRET_NAME].threatOnKill = true;

	clientfield::register( "vehicle", "auto_turret_open", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "auto_turret_init", VERSION_SHIP, 1, "int" ); // re-export model in close position to save this clientfield
	clientfield::register( "scriptmover", "auto_turret_close", VERSION_SHIP, 1, "int" );

	level.autoturretOpenAnim = %o_turret_sentry_deploy;
	level.autoturretCloseAnim = %o_turret_sentry_close;
	
	remote_weapons::RegisterRemoteWeapon( TURRET_NAME, TURRET_REMOTE_TEXT, &StartTurretRemoteControl, &EndTurretRemoteControl, TURRET_HIDE_COMPASS_ON_REMOTE_CONTROL );
	vehicle::add_main_callback( TURRET_VEHICLE_NAME, &InitTurret );
	
	visionset_mgr::register_info( "visionset", TURRET_VISIONSET_ALIAS, VERSION_SHIP, 81, TURRET_VISIONSET_LERP_STEP_COUNT, true, &visionset_mgr::ramp_in_out_thread_per_player, false  );
}

function InitTurret()
{
	turretVehicle = self;
	//turretVehicle.delete_on_death = undefined; // don't delete on death as we may need to support futz on death
	turretVehicle.dontfreeme = true; // don't allow the shared shutdown sequence until we are ready
	turretVehicle.damage_on_death = false; // never cause damage when auto turret dies
	turretVehicle.delete_on_death = undefined; // disallow the vehicle death's delete
	turretVehicle.watch_remote_weapon_death = true;
	turretVehicle.watch_remote_weapon_death_duration = TURRET_WATCH_DEATH_DURATION;
	
	turretVehicle.maxhealth = TURRET_HEALTH;
	turretVehicle.damageTaken = 0;
	
	tableHealth = killstreak_bundles::get_max_health( TURRET_NAME );
	
	if ( isdefined( tableHealth ) )
	{
		turretVehicle.maxhealth = tableHealth;

	}
	
	turretVehicle.health = turretVehicle.maxhealth;
	
	turretVehicle turret::set_max_target_distance( TURRET_MAX_TARGET_DISTANCE, 0 );
	// setting min dist squared prevents an exploit of drawing fire and not getting hurt when there is no collision on the turret
	turretVehicle turret::set_min_target_distance_squared( DistanceSquared( turretVehicle GetTagOrigin( "tag_flash" ), turretVehicle GetTagOrigin( "tag_barrel" ) ), 0 );
	turretVehicle turret::set_on_target_angle( TURRET_TARGET_ANGLE, 0 );
	turretVehicle clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	turretVehicle.soundmod = "drone_land";
	//turretVehicle NotSolid();
	
	turretVehicle.overrideVehicleDamage = &OnTurretDamage;
	turretVehicle.overrideVehicleDeath = &OnTurretDeath;
}

function ActivateTurret()
{
	player = self;
	assert( IsPlayer( player ) );
	
	killstreakId = self killstreakrules::killstreakStart( TURRET_NAME, player.team, false, false );
	if( killstreakId == INVALID_KILLSTREAK_ID )
	{
		return false;
	}
	
	bundle = level.killstreakBundle[TURRET_NAME];

	turret = player placeables::SpawnPlaceable( TURRET_NAME, killstreakId,
	                                            &OnPlaceTurret, &OnCancelPlacement, &OnPickupTurret, &OnShutdown, undefined, undefined,
	                                           	TURRET_MODEL, TURRET_VALID_PLACEMENT_MODEL, TURRET_INVALID_PLACEMENT_MODEL, true,
	                                            TURRET_PICKUP_TEXT, TURRET_DURATION, undefined, 0, bundle.ksPlaceableHint, bundle.ksPlaceableInvalidLocationHint );
	
	turret thread WatchTurretShutdown( killstreakId, player.team );
	turret thread util::ghost_wait_show_to_player( player );
	turret.otherModel thread util::ghost_wait_show_to_others( player );
	turret clientfield::set( "auto_turret_init", 1 );
	turret.otherModel clientfield::set( "auto_turret_init", 1 );	
	
	event = turret util::waittill_any_return( "placed", "cancelled", "death" );
	if( event != "placed" )
	{
		return false;
	}
	
	turret playsound ("mpl_turret_startup");
	return true;
}

function OnPlaceTurret( turret )
{
	player = self;
	assert( IsPlayer( player ) );
	
	if( isdefined( turret.vehicle ) )
	{
		turret.vehicle.origin = turret.origin;
		turret.vehicle.angles = turret.angles;

		turret.vehicle thread util::ghost_wait_show( 0.05 );

		turret.vehicle playsound ("mpl_turret_startup");
	}
	else
	{
		turret.vehicle = SpawnVehicle( TURRET_VEHICLE_NAME, turret.origin, turret.angles, "dynamic_spawn_ai" );
		turret.vehicle.owner = player;
		turret.vehicle SetOwner( player );
		turret.vehicle.ownerEntNum = player.entNum;
		turret.vehicle.parentStruct = turret;
		turret.vehicle.controlled = false;
		turret.vehicle.treat_owner_damage_as_friendly_fire = true;
		turret.vehicle.ignore_team_kills = true;
		turret.vehicle.deal_no_crush_damage = true;
		
		turret.vehicle.team = player.team;
		turret.vehicle SetTeam( player.team );
		turret.vehicle turret::set_team( player.team, 0 );
		turret.vehicle turret::set_torso_targetting( 0 );
		turret.vehicle turret::set_target_leading( 0 );
		turret.vehicle.use_non_teambased_enemy_selection = true;
		turret.vehicle.waittill_turret_on_target_delay = 0.25;
		//turret.vehicle turret::set_see_from_tag_flash( true, 0 );
		//turret.vehicle turret::
		turret.vehicle.ignore_vehicle_underneath_splash_scalar = true;
		
		turret.vehicle killstreaks::configure_team( TURRET_NAME, turret.killstreakId, player, "small_vehicle" );
		turret.vehicle killstreak_hacking::enable_hacking( TURRET_NAME, &HackedCallbackPre, &HackedCallbackPost );

		turret.vehicle thread turret_watch_owner_events();
		turret.vehicle thread turret_laser_watch();
		turret.vehicle thread setup_death_watch_for_new_targets();
		
		turret.vehicle CreateTurretInfluencer( "turret" );
		turret.vehicle CreateTurretInfluencer( "turret_close" );
		
		turret.vehicle thread util::ghost_wait_show( 0.05 );

		if ( IsSentient( turret.vehicle ) == false )
			turret.vehicle MakeSentient(); // so other sentients will consider this as a potential enemy
	
		player killstreaks::play_killstreak_start_dialog( TURRET_NAME, player.pers["team"], turret.killstreakId );
		level thread popups::DisplayKillstreakTeamMessageToAll( TURRET_NAME, player );
		player AddWeaponStat( GetWeapon( TURRET_NAME ), "used", 1 );
			
		turret.vehicle.killstreak_end_time = GetTime() + TURRET_DURATION + PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION_TU1;
	}

	turret.vehicle turret::enable( 0, false );
	Target_Set( turret.vehicle, ( 0, 0, 36 ) );
	turret.vehicle Unlink();

	turret.vehicle vehicle::disconnect_paths( 0, false );
		
	turret.vehicle thread TurretScanning();
	
	turret play_deploy_anim();
	
	player remote_weapons::UseRemoteWeapon( turret.vehicle, TURRET_NAME, false );
}

function HackedCallbackPre( hacker )
{
	turretVehicle = self;
	turretVehicle clientfield::set( "enemyvehicle", ENEMY_VEHICLE_HACKED );
	turretVehicle.owner clientfield::set_to_player( "static_postfx", 0 );
	if( turretVehicle.controlled === true )
		visionset_mgr::deactivate( "visionset", TURRET_VISIONSET_ALIAS, turretVehicle.owner );
	turretVehicle.owner remote_weapons::RemoveAndAssignNewRemoteControlTrigger( turretVehicle.useTrigger );
	turretVehicle remote_weapons::EndRemoteControlWeaponUse( true );
	turretVehicle.owner unlink();	
	turretVehicle clientfield::set( "vehicletransition", 0 );
}

function HackedCallbackPost( hacker )
{
	turretVehicle = self;
	hacker remote_weapons::UseRemoteWeapon( turretVehicle, TURRET_NAME, false );
	turretVehicle notify( "WatchRemoteControlDeactivate_remoteWeapons" );
	turretVehicle.killstreak_end_time = hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( turretVehicle );
}

function play_deploy_anim_after_wait( wait_time )
{
	turret = self;
	turret endon( "death" );

	wait wait_time;
	
	turret play_deploy_anim();
}

function play_deploy_anim()
{
	turret = self;
	
	turret clientfield::set( "auto_turret_close", 0 );
	turret.otherModel clientfield::set( "auto_turret_close", 0 );
	
	if ( isdefined( turret.vehicle ))
	{
		turret.vehicle clientfield::set( "auto_turret_open", 1 );
	}
}

function OnCancelPlacement( turret )
{
	turret notify( "sentry_turret_shutdown" );
}

function OnPickupTurret( turret )
{
	player = self;
	turret.vehicle Ghost();
	turret.vehicle turret::disable( 0 );
	turret.vehicle LinkTo( turret );
	Target_Remove( turret.vehicle );

	turret clientfield::set( "auto_turret_close", 1 );
	turret.otherModel clientfield::set( "auto_turret_close", 1 );
	
	if ( isdefined( turret.vehicle ) )
	{
		turret.vehicle notify( "end_turret_scanning" );
		turret.vehicle  SetTurretTargetRelativeAngles( ( 0, 0, 0 ) );
		
		turret.vehicle clientfield::set( "auto_turret_open", 0 );
		
		if( isdefined( turret.vehicle.useTrigger ) )
		{
			turret.vehicle.useTrigger Delete();
			turret.vehicle playsound ("mpl_turret_down");
		}
		
		turret.vehicle vehicle::connect_paths();
	}
}

function OnTurretDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	empDamage = int( iDamage + ( self.healthdefault * TURRET_EMP_DAMAGE_PERCENTAGE ) + 0.5 );
	
	iDamage = self killstreaks::OnDamagePerWeapon( TURRET_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth*0.4, undefined, empDamage, undefined, true, 1.0 );
	self.damageTaken += iDamage;
	
	if ( self.controlled )
	{
		self.owner vehicle::update_damage_as_occupant( self.damageTaken, self.maxHealth );
	}
	
	// turret death
	if ( self.damageTaken > self.maxHealth && !isdefined( self.will_die ) )
	{
		self.will_die = true;
		self thread OnDeathAfterFrameEnd( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime );
	}
	
	return iDamage;
}

function OnTurretDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	// currently, OnTurretDeath is not getting called, so we call OnDeath directly from OnTurretDamage
	self OnDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime );
}

function OnDeathAfterFrameEnd( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	waittillframeend;

	if ( isdefined( self ) )
	{
		self OnDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime );
	}
}

function OnDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	turretVehicle = self;
	
	// only die once
	if ( turretVehicle.dead === true )
		return;
	
	turretVehicle.dead = true;

	turretVehicle DisableDriverFiring( true );
	turretvehicle turret::disable( 0 );

	turretvehicle vehicle::connect_paths();
			
	eAttacker = self [[ level.figure_out_attacker ]]( eAttacker );
	
	if( isdefined( turretVehicle.parentStruct ) )
	{
		turretVehicle.parentStruct placeables::ForceShutdown();
	
		if ( turretVehicle.parentStruct.killstreakTimedOut === true && isdefined( turretVehicle.owner ) )
		{
			turretVehicle.owner globallogic_audio::play_taacom_dialog( "timeout", turretVehicle.parentStruct.killstreakType );
		}
		else
		{
			if ( isdefined( eAttacker ) && isdefined( turretVehicle.owner ) && ( eAttacker != turretVehicle.owner ) )		
				turretVehicle.parentStruct killstreaks::play_destroyed_dialog_on_owner( turretVehicle.parentStruct.killstreakType, turretVehicle.parentStruct.killstreakId );
		}
	}

	if ( isdefined( eAttacker ) && IsPlayer( eAttacker ) && ( !isdefined( self.owner ) || self.owner util::IsEnemyPlayer( eAttacker ) ) )
	{
		scoreevents::processScoreEvent( "destroyed_sentry_gun", eAttacker, self, weapon );
		eAttacker challenges::destroyScoreStreak( weapon, turretVehicle.controlled, true, false );
		eAttacker challenges::destroyNonAirScoreStreak_PostStatsLock( weapon );
		eAttacker AddPlayerStat( "destroy_turret", 1 );
		eAttacker AddWeaponStat( weapon, "destroy_turret", 1 );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_AUTO_TURRET", eAttacker.entnum );
	}
	
	turretVehicle vehicle_death::death_fx();
	turretVehicle playsound ("mpl_m_turret_exp");
	
	// anticipating futz

	wait 0.1;
	
	turretVehicle Ghost();
	turretVehicle NotSolid();

	turretVehicle util::waittill_any_timeout( 2.0, "remote_weapon_end" );
	
	if ( isdefined( turretVehicle ) )
	{
		// wait until control is released, vehicle gets deleted, or owner disconnects 
		while ( isdefined( turretVehicle ) && ( turretVehicle.controlled || !isdefined( turretVehicle.owner ) ) )
			WAIT_SERVER_FRAME;

		turretVehicle.dontfreeme = undefined;	// allows vehicle shared shutdown to finish
		
		// we decided to be responsible for deleting the vehicle, so we delete here
		wait 0.5;
		if ( isdefined ( turretVehicle ) )
			turretVehicle delete();
	}
}

function OnShutdown( turret )
{
	turret notify( "sentry_turret_shutdown" );
}

function StartTurretRemoteControl( turretVehicle )
{
	player = self;
	assert( IsPlayer( player ) );
	
	turretVehicle turret::disable( 0 );
	turretVehicle UseVehicle( player, 0 );
	turretVehicle clientfield::set( "vehicletransition", 1 );
	turretVehicle.controlled = true;
	turretVehicle.treat_owner_damage_as_friendly_fire = false;
	turretVehicle.ignore_team_kills = false;
	
	player vehicle::set_vehicle_drivable_time( TURRET_DURATION + PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION_TU1, turretVehicle.killstreak_end_time );
	player vehicle::update_damage_as_occupant( VAL( turretVehicle.damageTaken, 0 ), VAL( turretVehicle.maxHealth, 100 ) );
		
	visionset_mgr::activate( "visionset", TURRET_VISIONSET_ALIAS, self, 1, 90000, 1 );
}

function EndTurretRemoteControl( turretVehicle, exitRequestedByOwner )
{
	if( exitRequestedByOwner )
	{
		turretVehicle thread EnableTurretAfterWait( 0.1 ); // currently, this must be called after the player leaves the vehicle
	}
	turretVehicle clientfield::set( "vehicletransition", 0 );

	if ( isdefined( turretVehicle.owner ) && ( turretVehicle.controlled === true ) )
		visionset_mgr::deactivate( "visionset", TURRET_VISIONSET_ALIAS, turretVehicle.owner );

	turretVehicle.controlled = false;
	turretVehicle.treat_owner_damage_as_friendly_fire = true;
	turretVehicle.ignore_team_kills = true;
}

function EnableTurretAfterWait( wait_time ) // self == turretVehicle
{
	self endon ( "death" );
	if ( isdefined( self.owner ) )
	{
		self.owner endon( "joined_team" );
		self.owner endon( "disconnect" );
		self.owner endon( "joined_spectators" );
	}

	wait wait_time;
	self turret::enable( 0, false );	
}

function CreateTurretInfluencer( name )
{
	turret = self;
	
	preset = GetInfluencerPreset( name );
	
	if ( !IsDefined( preset ) )
	{
		return;
	}
		
	// place the influencer out infront of the turret
	projected_point = turret.origin + VectorScale( AnglesToForward( turret.angles ), preset["radius"] * 0.7 );
	return spawning::create_enemy_influencer( name, turret.origin, turret.team );
}

function turret_watch_owner_events()
{
	self notify( "turret_watch_owner_events_singleton" );
	self endon ( "tturet_watch_owner_events_singleton" );
	self endon( "death" );
	
	self.owner util::waittill_any( "joined_team", "disconnect", "joined_spectators" );

	self MakeVehicleUsable();
	self.controlled = false;
	
	if ( isdefined( self.owner ) )
	{
		self.owner unlink();
		self clientfield::set( "vehicletransition", 0 );
	}
	
	self MakeVehicleUnusable();
	
	if ( isdefined( self.owner ) )
	{
		self.owner killstreaks::clear_using_remote();
	}
	
	self.abandoned = true;

	OnShutdown( self );
}

function turret_laser_watch()
{
	turretVehicle = self;
	turretVehicle endon( "death" );

	while( 1 )
	{
		laser_should_be_on = ( !turretVehicle.controlled && turretVehicle turret::does_have_target( 0 ) );

		if ( laser_should_be_on )
		{
			if ( IsLaserOn( turretVehicle ) == false )
			{
				turretVehicle turret::enable_laser( true, 0 );
			}
		}
		else
		{
			if ( IsLaserOn( turretVehicle ) )
			{
				turretVehicle turret::enable_laser( false, 0 );
			}
		}

		wait 0.25;
	}
}

function setup_death_watch_for_new_targets()
{
	turretVehicle = self;
	
	turretVehicle endon( "death" );
	old_target = undefined;

	while( 1 )
	{
		turretVehicle waittill( "has_new_target", new_target );
		
		if ( isdefined( old_target ) )
			old_target notify( "abort_death_watch" );

		new_target thread target_death_watch( turretVehicle );
		old_target = new_target;
	}
}

function target_death_watch( turretVehicle )
{
	target = self;
	target endon( "abort_death_watch" );

	turretVehicle endon( "death" );

	target util::waittill_any( "death", "disconnect", "joined_team", "joined_spectators" );

	turretVehicle turret::stop( 0, true );
}

function TurretScanning()
{
	turretVehicle = self;

	turretVehicle endon( "death" );
	turretVehicle endon( "end_turret_scanning" );

	turret_data = turretVehicle _get_turret_data( 0 );
		
	turretVehicle.do_not_clear_targets_during_think = true; // don't let shared turret code clear targets; TurretScanning will clear targets
	// note: turret:clear_target() indirectly affects targetType which affects how SetTurretTargetRelativeAngles behaves.

	wait 0.8;

	while( 1 )
	{
		if ( turretVehicle.controlled )
		{
			wait 0.5;
			continue;
		}

		if ( turretVehicle turret::does_have_target( 0 ) )
		{
			wait 0.25;
			continue;
		}
		
		/#	turret_data = turretVehicle _get_turret_data( 0 ); #/ // for live update
		
		turretVehicle turret::clear_target( 0 );

		if ( turretVehicle.scanPos === "left" )
		{
			turretVehicle SetTurretTargetRelativeAngles( ( 0, ( turret_data.leftArc - TURRET_SCAN_ANGLE_BUFFER ), 0 ), 0 );
			turretVehicle.scanPos = "right";
		}
		else
		{
			turretVehicle SetTurretTargetRelativeAngles( ( 0, -( turret_data.rightArc - TURRET_SCAN_ANGLE_BUFFER ), 0 ), 0 );
			turretVehicle.scanPos = "left";
		}
		
		wait TURRET_SCAN_WAIT;
	}
}

function WatchTurretShutdown( killstreakId, team )
{
	turret = self;
	
	turret waittill( "sentry_turret_shutdown" );
	
	killstreakrules::killstreakStop( TURRET_NAME, team, killstreakId );
	
	if( isdefined( turret.vehicle ) )
	{
		turret.vehicle spawning::remove_influencers();
	}
}
