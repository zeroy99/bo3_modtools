#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\weapons\_weaponobjects;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_placeables;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\killstreaks\_turret;
#using scripts\mp\teams\_teams;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "KILLSTREAK_EARNED_AUTO_TURRET" );
#precache( "string", "KILLSTREAK_AUTO_TURRET_NOT_AVAILABLE" );

#precache( "string", "KILLSTREAK_AUTO_TURRET_CRATE" );
#precache( "string", "KILLSTREAK_MICROWAVE_TURRET_CRATE" );
#precache( "string", "KILLSTREAK_EARNED_AUTO_TURRET" );
#precache( "string", "KILLSTREAK_AUTO_TURRET_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_AIRSPACE_FULL" );
#precache( "string", "KILLSTREAK_EARNED_MICROWAVE_TURRET" );
#precache( "string", "KILLSTREAK_MICROWAVE_TURRET_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_MICROWAVE_TURRET_HACKED" );
#precache( "string", "KILLSTREAK_MICROWAVE_TURRET_INBOUND" );
#precache( "string", "KILLSTREAK_DESTROYED_MICROWAVE_TURRET" );
#precache( "triggerstring", "KILLSTREAK_MICROWAVE_TURRET_PLACE_TURRET_HINT" );
#precache( "triggerstring", "KILLSTREAK_MICROWAVE_TURRET_INVALID_TURRET_LOCATION" );
#precache( "triggerstring", "KILLSTREAK_MICROWAVE_TURRET_PICKUP" );
#precache( "string", "mpl_killstreak_turret" );
#precache( "string", "mpl_killstreak_auto_turret" );
#precache( "fx", "killstreaks/fx_sentry_emp_stun" );
#precache( "fx", "killstreaks/fx_sentry_damage_state" );
#precache( "fx", "killstreaks/fx_sentry_death_state" );
#precache( "fx", "killstreaks/fx_sentry_exp" );
#precache( "fx", "killstreaks/fx_sentry_disabled_spark" );
#precache( "fx", "killstreaks/fx_sg_emp_stun" );
#precache( "fx", "killstreaks/fx_sg_damage_state" );
#precache( "fx", "killstreaks/fx_sg_death_state" );
#precache( "fx", "killstreaks/fx_sg_exp" );
#precache( "fx", "killstreaks/fx_sg_distortion_cone_ash" );
#precache( "fx", "killstreaks/fx_sg_distortion_cone_ash_sm" );
#precache( "fx", "explosions/fx_exp_equipment_lg" );
#precache( "model", MICROWAVE_TURRET_INVALID_PLACEMENT_MODEL );
#precache( "model", MICROWAVE_TURRET_VALID_PLACEMENT_MODEL );
#precache( "model", "wpn_t7_none_world" );

#using_animtree( "mp_microwaveturret" );

#define MICROWAVE_TURRET_NAME						"microwave_turret"
#define MICROWAVE_TURRET_WEAPON_NAME				"microwave_turret_deploy"
#define MICROWAVE_TURRET_ON_TARGET_ANGLE			(15)
#define MICROWAVE_TURRET_DELETE_ON_DEATH_DELAY		0.1

#define MICROWAVE_TURRET_FX_SIZE					( 135 )
#define MICROWAVE_TURRET_FX_HALF_SIZE_THRESHOLD		( 68 )
#define MICROWAVE_TURRET_FX_START_OFFSET			( 68 + 34 )
#define MICROWAVE_TURRET_FX							"killstreaks/fx_sg_distortion_cone_ash"
#define MICROWAVE_TURRET_FX_HALF					"killstreaks/fx_sg_distortion_cone_ash_sm"
#define MICROWAVE_TURRET_STUN_FX					"killstreaks/fx_sg_emp_stun"
#define MICROWAVE_TURRET_FX_TRACE_ANGLE				( 55 )
#define MICROWAVE_TURRET_FX_CHECK_TIME				( 1.0 )

#namespace microwave_turret;

function init()
{
	killstreaks::register( MICROWAVE_TURRET_NAME, MICROWAVE_TURRET_WEAPON_NAME, "killstreak_" + MICROWAVE_TURRET_NAME, MICROWAVE_TURRET_NAME + "_used", &ActivateMicrowaveTurret, false, true );
	killstreaks::register_strings( MICROWAVE_TURRET_NAME, &"KILLSTREAK_EARNED_MICROWAVE_TURRET", &"KILLSTREAK_MICROWAVE_TURRET_NOT_AVAILABLE", &"KILLSTREAK_MICROWAVE_TURRET_INBOUND", undefined, &"KILLSTREAK_MICROWAVE_TURRET_HACKED", false );
	killstreaks::register_dialog( MICROWAVE_TURRET_NAME, "mpl_killstreak_turret", "microwaveTurretDialogBundle", undefined, "friendlyMicrowaveTurret", "enemyMicrowaveTurret", "enemyMicrowaveTurretMultiple", "friendlyMicrowaveTurretHacked", "enemyMicrowaveTurretHacked", "requestMicrowaveTurret", "threatMicrowaveTurret" );
	killstreaks::register_remote_override_weapon( MICROWAVE_TURRET_NAME, MICROWAVE_TURRET_NAME );
	
	level.microwaveOpenAnim = %o_turret_guardian_open;
	level.microwaveCloseAnim = %o_turret_guardian_close;
	
	clientfield::register( "vehicle", "turret_microwave_open", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "turret_microwave_init", VERSION_SHIP, 1, "int" ); // re-export model in close position to save this clientfield
	clientfield::register( "scriptmover", "turret_microwave_close", VERSION_SHIP, 1, "int" );
	
	vehicle::add_main_callback( MICROWAVE_TURRET_VEHICLE_NAME, &InitTurretVehicle );
	
	callback::on_spawned( &on_player_spawned );
	callback::on_vehicle_spawned( &on_vehicle_spawned );
}

function InitTurretVehicle()
{
	turretVehicle = self;
	//turretVehicle.delete_on_death = true;

	turretVehicle killstreaks::setup_health( MICROWAVE_TURRET_NAME );
	turretVehicle.damageTaken = 0;
	turretVehicle.deal_no_crush_damage = true;
	turretVehicle.health = turretVehicle.maxhealth;
	
	turretVehicle turret::set_max_target_distance( MICROWAVE_TURRET_RADIUS * 1.2, 0 );
	turretVehicle turret::set_on_target_angle( MICROWAVE_TURRET_ON_TARGET_ANGLE, 0 );
	turretVehicle clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	turretVehicle.soundmod = "hpm";
	
	turretVehicle.overrideVehicleDamage = &OnTurretDamage;
	turretVehicle.overrideVehicleDeath = &OnTurretDeath;
	turretVehicle.overrideVehicleDeathPostGame = &OnTurretDeathPostGame;
	
	turretVehicle.aim_only_no_shooting = true;
}

function on_player_spawned()
{
	// needs to reset this whenever a player spawns, could be switching teams and this var remains defined
	self reset_being_microwaved();
}

function on_vehicle_spawned()
{
	self reset_being_microwaved();
}

function reset_being_microwaved()
{
	self.lastMicrowavedBy = undefined;
	self.beingMicrowavedBy = undefined;
}

function ActivateMicrowaveTurret()
{
	player = self;
	assert( IsPlayer( player ) );
	
	killstreakId = self killstreakrules::killstreakStart( MICROWAVE_TURRET_NAME, player.team, false, false );
	if( killstreakId == INVALID_KILLSTREAK_ID )
	{
		return false;
	}
	
	bundle = level.killstreakBundle[MICROWAVE_TURRET_NAME];
	
	turret = player placeables::SpawnPlaceable( MICROWAVE_TURRET_NAME, killstreakId, 
	                                            &OnPlaceTurret, &OnCancelPlacement, &OnPickupTurret, &OnShutdown, undefined, &OnEMP,
	                                            MICROWAVE_TURRET_MODEL, MICROWAVE_TURRET_VALID_PLACEMENT_MODEL, MICROWAVE_TURRET_INVALID_PLACEMENT_MODEL, true,
	                                            MICROWAVE_TURRET_PICKUP_TEXT, MICROWAVE_TURRET_DURATION, undefined, MICROWAVE_TURRET_EMP_DAMAGE,
	                                            bundle.ksPlaceableHint, bundle.ksPlaceableInvalidLocationHint );
	turret killstreaks::setup_health( MICROWAVE_TURRET_NAME );
	turret.damageTaken = 0;
	turret.killstreakEndTime = getTime() + MICROWAVE_TURRET_DURATION;
	turret thread WatchKillstreakEnd( killstreakId, player.team );
	turret thread util::ghost_wait_show_to_player( player );
	turret.otherModel thread util::ghost_wait_show_to_others( player );
	turret clientfield::set( "turret_microwave_init", 1 );
	turret.otherModel clientfield::set( "turret_microwave_init", 1 );
	
	event = turret util::waittill_any_return( "placed", "cancelled", "death", "disconnect" );
	if( event != "placed" )
	{
		return false;
	}
	
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
		//turret.vehicle playsound ("wpn_micro_turret_start");
	}
	else
	{
		turret.vehicle = SpawnVehicle( MICROWAVE_TURRET_VEHICLE_NAME, turret.origin, turret.angles, "dynamic_spawn_ai" );
		turret.vehicle.owner = player;
		turret.vehicle SetOwner( player );
		turret.vehicle.ownerEntNum = player.entNum;
		turret.vehicle.parentStruct = turret;
		
		turret.vehicle.team = player.team;
		turret.vehicle SetTeam( player.team );
		turret.vehicle turret::set_team( player.team, 0 );
		turret.vehicle.ignore_vehicle_underneath_splash_scalar = true;
		turret.vehicle.use_non_teambased_enemy_selection = true;
		turret.vehicle.turret = turret;

		turret.vehicle thread util::ghost_wait_show( 0.05 );

		level thread popups::DisplayKillstreakTeamMessageToAll( MICROWAVE_TURRET_NAME, player );
		player AddWeaponStat( GetWeapon( MICROWAVE_TURRET_NAME ), "used", 1 );
		
		turret.vehicle killstreaks::configure_team( MICROWAVE_TURRET_NAME, turret.killstreakId, player );
		turret.vehicle killstreak_hacking::enable_hacking( MICROWAVE_TURRET_NAME, &HackedPreFunction, &HackedPostFunction );
		player killstreaks::play_killstreak_start_dialog( MICROWAVE_TURRET_NAME, player.pers["team"], turret.killstreakId );
	}

	turret.vehicle turret::enable( 0, false );
	Target_Set( turret.vehicle, ( 0, 0, 36 ) );
	
	turret.vehicle vehicle::disconnect_paths( 0, false );

	turret StartMicrowave();
}

function HackedPreFunction( hacker )
{
	turretVehicle = self;
	turretvehicle.turret notify( "hacker_delete_placeable_trigger" );
	turretvehicle.turret StopMicrowave();
	turretvehicle.turret killstreaks::configure_team( MICROWAVE_TURRET_NAME, turretvehicle.turret.killstreakId, hacker, undefined, undefined, undefined, true );
}

function HackedPostFunction( hacker )
{
	turretVehicle = self;
	turretvehicle.turret StartMicrowave();
}

function OnCancelPlacement( turret )
{
	turret notify( "microwave_turret_shutdown" );
}

function OnPickupTurret( turret )
{
	turret StopMicrowave();
	
	turret.vehicle thread GhostAfterWait( 0.05 );
	turret.vehicle turret::disable( 0 );
	turret.vehicle LinkTo( turret );
	Target_Remove( turret.vehicle );
	
	turret.vehicle vehicle::connect_paths();
	
	//turret.vehicle playsound ("wpn_micro_turret_stop");
}

function GhostAfterWait( wait_time )
{
	self endon( "death" );
	
	wait wait_time;
	self Ghost();
}

function OnEMP( attacker )
{
	turret = self;
	//TODO: Play Turret EMP FX
}

function OnTurretDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	empDamage = int( iDamage + ( self.healthdefault * TURRET_EMP_DAMAGE_PERCENTAGE ) + 0.5 );
	
	iDamage = self killstreaks::OnDamagePerWeapon( MICROWAVE_TURRET_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth*0.4, undefined, empDamage, undefined, true, 1.0 );
	self.damageTaken += iDamage;
	return iDamage;
}

function OnTurretDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	turretVehicle = self;
	
	eAttacker = self [[ level.figure_out_attacker ]]( eAttacker );

	if ( isdefined( turretVehicle.parentStruct ) )
	{
		turretVehicle.parentStruct placeables::ForceShutdown();
		
		if ( turretVehicle.parentStruct.killstreakTimedOut === true && isdefined( turretVehicle.owner ) )
		{
			turretVehicle.owner globallogic_audio::play_taacom_dialog( "timeout", turretVehicle.parentStruct.killstreakType );
		}
		else
		{
			if ( isdefined( eAttacker ) && IsPlayer( eAttacker ) && isdefined( turretVehicle.owner ) && ( eAttacker != turretVehicle.owner ) )
				turretVehicle.parentStruct killstreaks::play_destroyed_dialog_on_owner( turretVehicle.parentStruct.killstreakType, turretVehicle.parentStruct.killstreakId );
		}
	}

	if( isdefined( eAttacker ) && IsPlayer( eAttacker ) && ( !isdefined( self.owner ) || self.owner util::IsEnemyPlayer( eAttacker ) ) )
	{
		scoreevents::processScoreEvent( "destroyed_microwave_turret", eAttacker, self.owner, weapon );
		eAttacker challenges::destroyScoreStreak( weapon, false, true, false );
		eAttacker challenges::destroyNonAirScoreStreak_PostStatsLock( weapon );
		eAttacker AddPlayerStat( "destroy_turret", 1 );
		eAttacker AddWeaponStat( weapon, "destroy_turret", 1 );
		LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_MICROWAVE_TURRET", eAttacker.entnum );
	}
	
	if ( isdefined( turretVehicle.parentStruct ) )
	{
		turretVehicle.parentStruct notify( "microwave_turret_shutdown" );
	}
	
	turretVehicle vehicle_death::death_fx();
	
	wait MICROWAVE_TURRET_DELETE_ON_DEATH_DELAY;
	
	turretVehicle delete();
}

function OnTurretDeathPostGame( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	turretVehicle = self;
	
	if ( isdefined( turretVehicle.parentStruct ) )
	{
		turretVehicle.parentStruct placeables::ForceShutdown();
	}
	if ( isdefined( turretVehicle.parentStruct ) )
	{
		turretVehicle.parentStruct notify( "microwave_turret_shutdown" );
	}
	
	turretVehicle vehicle_death::death_fx();
	
	wait MICROWAVE_TURRET_DELETE_ON_DEATH_DELAY;
	
	turretVehicle delete();
}


function OnShutdown( turret )
{
	turret StopMicrowave();
	
	if ( isdefined( turret.vehicle ) )
	{
		turret.vehicle playsound ("mpl_m_turret_exp");
		turret.vehicle Kill();
	}

	turret notify( "microwave_turret_shutdown" );
}

function WatchKillstreakEnd( killstreak_id, team )
{
	turret = self;

	turret waittill( "microwave_turret_shutdown" );
	
	killstreakrules::killstreakStop( MICROWAVE_TURRET_NAME, team, killstreak_id );
}

function StartMicrowave()
{
	turret = self;
	if ( isdefined( turret.trigger ) ) 
	{
		turret.trigger delete();
	}
	turret.trigger = spawn("trigger_radius", turret.origin + (0,0,-MICROWAVE_TURRET_RADIUS), level.aiTriggerSpawnFlags | level.vehicleTriggerSpawnFlags, MICROWAVE_TURRET_RADIUS, MICROWAVE_TURRET_RADIUS*2);
	turret thread TurretThink();
	
	turret clientfield::set( "turret_microwave_close", 0 );
	turret.otherModel clientfield::set( "turret_microwave_close", 0 );
	
	if ( isdefined( turret.vehicle ))
	{
		turret.vehicle clientfield::set( "turret_microwave_open", 1 );
	}

	turret turret::CreateTurretInfluencer( "turret" );
	turret turret::CreateTurretInfluencer( "turret_close" );
	
	/#
		turret thread TurretDebugWatch();
	#/
}

function StopMicrowave()
{
	turret = self;
	turret spawning::remove_influencers();
	
	if( isdefined( turret ) )
	{
		turret clientfield::set( "turret_microwave_close", 1 );
		turret.otherModel clientfield::set( "turret_microwave_close", 1 );
		
		if ( isdefined( turret.vehicle ) )
		{
			turret.vehicle clientfield::set( "turret_microwave_open", 0 );
		}
		
		turret playsound ("mpl_microwave_beam_off");

		if( isdefined( turret.microwaveFXEnt ) )
		{
			turret.microwaveFXEnt delete();
			
			// /# IPrintLnBold( "Deleted Microwave Fx Ent: " + GetTime() ); #/
		}
		
		if( isdefined( turret.trigger ) )
		{
			turret.trigger notify( "microwave_end_fx" );
			turret.trigger Delete();
		}
		
		/#
			turret notify( "stop_turret_debug" );
		#/
	}
}

function TurretDebugWatch()
{
	turret = self;
	turret endon( "stop_turret_debug" );

	for(;;)
	{
		if ( GetDvarInt( "scr_microwave_turret_debug" ) != 0 )
		{
			turret TurretDebug();
			
			WAIT_SERVER_FRAME;
		}
		else
		{
			wait 1.0;
		}
	}
}

function TurretDebug()
{
	turret = self;

	debug_line_frames = 3;
	
	angles = turret.vehicle GetTagAngles( "tag_flash" );
	origin = turret.vehicle GetTagOrigin( "tag_flash" );
		
	cone_apex =	origin;
	forward = AnglesToForward( angles ) ;
	dome_apex = cone_apex + VectorScale( forward, MICROWAVE_TURRET_RADIUS );

	util::debug_spherical_cone( cone_apex, dome_apex, MICROWAVE_TURRET_CONE_ANGLE, 16, ( 0.95, 0.1, 0.1 ), 0.3, true, debug_line_frames );
}


function TurretThink()
{
	turret = self;
	turret endon( "microwave_turret_shutdown" );
	
	turret.trigger endon( "death" );
	turret.trigger endon( "delete" );

	turret.turret_vehicle_entnum = turret.vehicle GetEntityNumber();
		
	while( true )
	{
		turret.trigger waittill( "trigger", ent );
		
		if ( ent == turret )
			continue;

		if ( !isdefined( ent.beingMicrowavedBy ) )
		{
			ent.beingMicrowavedBy = [];
		}
		
		if( !isdefined( ent.beingMicrowavedBy[ turret.turret_vehicle_entnum ] ) )
		{
			turret thread MicrowaveEntity( ent );
		}
	}
}

function MicrowaveEntityPostShutdownCleanup( entity )
{
	entity endon( "disconnect" );
	entity endon( "end_MicrowaveEntityPostShutdownCleanup" );

	turret = self;
	
	turret_vehicle_entnum = turret.turret_vehicle_entnum;
		
	turret waittill( "microwave_turret_shutdown" );
	
	if ( isdefined(entity) )
	{		
		if ( isdefined( entity.beingMicrowavedBy ) && isdefined( entity.beingMicrowavedBy[ turret_vehicle_entnum ] ) )
		{
			entity.beingMicrowavedBy[ turret_vehicle_entnum ] = undefined;
		}
	}
}

function MicrowaveEntity( entity )
{
	turret = self;
			
	turret endon( "microwave_turret_shutdown" );
	entity endon( "disconnect" );
	entity endon( "death" );
	
	if ( IsPlayer( entity ) )
	{
		entity endon( "joined_team" );
		entity endon( "joined_spectators" );
	}

	turret thread MicrowaveEntityPostShutdownCleanup( entity );

	entity.beingMicrowavedBy[ turret.turret_vehicle_entnum ] = turret.owner;
	entity.microwaveDamageInitialDelay = true;
	entity.microwaveEffect = 0;
	
	shellShockScalar = 1;
	viewKickScalar = 1;
	damageScalar = 1;
	
	if ( IsPlayer( entity ) && entity hasPerk( "specialty_microwaveprotection" ) )
	{
		shellShockScalar = getDvarFloat( "specialty_microwaveprotection_shellshock_scalar", 0.5 );
		viewKickScalar = getDvarFloat( "specialty_microwaveprotection_viewkick_scalar", 0.5 );
		damageScalar = getDvarFloat( "specialty_microwaveprotection_damage_scalar", 0.5 );
	}

	turretWeapon = GetWeapon( "microwave_turret" );
	
	while( true )
	{
		if( !isdefined( turret ) || !turret MicrowaveTurretAffectsEntity( entity ) || !isdefined( turret.trigger ) )
		{
			if( !isdefined(entity))
			{
				return;
			}

			entity.beingMicrowavedBy[ turret.turret_vehicle_entnum ] = undefined;
			
			if( isdefined( entity.microwavePoisoning ) && entity.microwavePoisoning )
			{
				entity.microwavePoisoning = false;
			}
			
			entity notify( "end_MicrowaveEntityPostShutdownCleanup" );
			
			return;
		}
		
		damage = MICROWAVE_TURRET_DAMAGE * damageScalar;
		
		if ( level.hardcoreMode )
		{
			damage = damage / 2;	
		}
		
		if ( !IsAi( entity ) && entity util::mayApplyScreenEffect() )
		{
			if ( !isdefined( entity.microwavePoisoning ) || !entity.microwavePoisoning )
			{
				entity.microwavePoisoning = true;
				entity.microwaveEffect = 0;
			}
		}
		
		// randomly wait a bit before applying intial damage to "stagger" it and prevent performance spikes
		if ( isdefined( entity.microwaveDamageInitialDelay ) )
		{
			wait RandomFloatRange( MICROWAVE_TURRET_INITIAL_DAMAGE_DELAY_MIN, MICROWAVE_TURRET_INITIAL_DAMAGE_DELAY_MAX );
			entity.microwaveDamageInitialDelay = undefined;
		}

		entity DoDamage( damage, 							// iDamage Integer specifying the amount of damage done
						 turret.origin, 					// vPoint The point the damage is from?
						 turret.owner, 						// eAttacker The entity that is attacking.
						 turret.vehicle, 					// eInflictor The entity that causes the damage.(e.g. a turret)
						 0, 
						 "MOD_TRIGGER_HURT", 				// sMeansOfDeath Integer specifying the method of death
						 0, 								// iDFlags Integer specifying flags that are to be applied to the damage
						 turretWeapon );						// Weapon The weapon used to inflict the damage

		entity.microwaveEffect++;
		entity.lastMicrowavedBy = turret.owner;
		time = GetTime();
	
		if( IsPlayer(entity) && !(entity IsRemoteControlling() ) )
		{
			if ( time - VAL( entity.microwaveShellshockAndViewKickTime, 0 ) > 950 ) // the time here ties in with the wait 0.5 below and the microwaveEffect % 2
			{
				if( entity.microwaveEffect % 2 == 1 )
				{
					if ( DistanceSquared( entity.origin, turret.origin ) > (MICROWAVE_TURRET_RADIUS * 2/3) * (MICROWAVE_TURRET_RADIUS * 2/3) )
					{			    
						entity shellshock( "mp_radiation_low", 1.5 * shellShockScalar );
						entity ViewKick( int( 25 * viewKickScalar ), turret.origin );
					}
					else if ( DistanceSquared( entity.origin, turret.origin ) > (MICROWAVE_TURRET_RADIUS * 1/3) * (MICROWAVE_TURRET_RADIUS * 1/3) )
					{			    
						entity shellshock( "mp_radiation_med", 1.5 * shellShockScalar );
						entity ViewKick( int( 50 * viewKickScalar ), turret.origin );
					}
					else
					{
						entity shellshock( "mp_radiation_high", 1.5 * shellShockScalar );
						entity ViewKick( int( 75 * viewKickScalar ), turret.origin );
					}
					
					entity.microwaveShellshockAndViewKickTime = time;
				}
			}
		}
		
		if( IsPlayer( entity ) && entity.microwaveEffect % 3 == 2 )
		{
			scoreevents::processScoreEvent( "hpm_suppress", turret.owner, entity, turretWeapon );
		}
		
		wait 0.5;
	}
}

function MicrowaveTurretAffectsEntity( entity )
{
	turret = self;
	
	if( !IsAlive( entity ) )
	{
		return false;
	}
		
	if( !IsPlayer( entity ) && !IsAi( entity ) )
	{
		return false;
	}

	if ( entity.ignoreme === true )
	{
		return false;
	}

		
	if( isdefined( turret.carried ) && turret.carried )
	{
		return false;
	}
		
	if( turret weaponobjects::isStunned() )
	{
		return false;
	}
	
	if( isdefined( turret.owner ) && entity == turret.owner )
	{
		return false;
	}
	
	if( !weaponobjects::friendlyFireCheck( turret.owner, entity, 0 ) )
	{
		return false;
	}
	
	if( DistanceSquared( entity.origin, turret.origin ) > MICROWAVE_TURRET_RADIUS * MICROWAVE_TURRET_RADIUS )
	{
		return false;
	}
	
	angles = turret.vehicle GetTagAngles( "tag_flash" );
	origin = turret.vehicle GetTagOrigin( "tag_flash" );	
	
	shoot_at_pos = entity GetShootAtPos( turret );

	entDirection = vectornormalize( shoot_at_pos - origin );
	forward = AnglesToForward( angles ) ;
	dot = vectorDot( entDirection, forward );
	if( dot < cos( MICROWAVE_TURRET_CONE_ANGLE ) )
	{
		return false;
	}
	
	if( entity damageConeTrace( origin, turret, forward ) <= 0 )
	{
		return false;
	}

	return true;
}
