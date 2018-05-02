#using scripts\codescripts\struct;

#using scripts\shared\_oob;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hud_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapons;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_amws;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_dev;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\mp\killstreaks\_dogs;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_remote_weapons;
#using scripts\mp\killstreaks\_satellite;
#using scripts\mp\killstreaks\_supplydrop;
#using scripts\mp\killstreaks\_uav;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define AI_TANK_WEAPON_NAME				"ai_tank_marker"
#define AI_TANK_HEALTH					1500
#define AI_TANK_PATH_TIMEOUT			45
#define AI_TANK_BULLET_MITIGATION		.8
#define AI_TANK_EXPLOSIVE_MITIGATION	1
#define AI_TANK_STUN_DURATION			4
#define AI_TANK_STUN_DURATION_PROXIMITY 1.5
#define AI_TANK_MISSILE_TURRET			0
#define AI_TANK_GUN_TURRET				1
#define AI_TANK_MISSILE_FLASH_TAG		"tag_flash"
#define AI_TANK_GUNNER_FLASH_TAG		"tag_flash_gunner1"
#define AI_TANK_GUNNER_AIM_TAG			"tag_gunner_aim1"
#define AI_TANK_GUNNER_AIM_OFFSET		-24
#define AI_TANK_THINK_DEBUG				GetDvarInt( "scr_ai_tank_think_debug" )
#define AI_TANK_TIME_TO_WAIT_FOR_LOST_TARGET	5
#define AI_TANK_FURTHEST_FROM_NAVMESH_ALLOWED	( 40 * 12 )
	
#define AI_TANK_NAV_MESH_VALID_LOCATION_BOUNDARY	16
#define AI_TANK_NAV_MESH_VALID_LOCATION_TOLERANCE	4

#precache( "string", "KILLSTREAK_EARNED_AI_TANK_DROP" );
#precache( "string", "KILLSTREAK_AI_TANK_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_AI_TANK_INBOUND" );
#precache( "string", "KILLSTREAK_AI_TANK_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_AI_TANK" );
#precache( "string", "mpl_killstreak_ai_tank" );
#precache( "triggerstring", "MP_REMOTE_USE_TANK" );
#precache( "fx", "killstreaks/fx_agr_emp_stun" );
#precache( "fx", "killstreaks/fx_agr_rocket_flash_1p" );
#precache( "fx", "killstreaks/fx_agr_rocket_flash_3p" );
#precache( "fx", "killstreaks/fx_agr_damage_state" );
#precache( "fx", "killstreaks/fx_agr_explosion" );
#precache( "fx", "killstreaks/fx_agr_drop_box" );

#using_animtree ( "mp_vehicles" );
	
#namespace ai_tank;

function init()
{
	bundle = struct::get_script_bundle( "killstreak",  "killstreak_" + AI_TANK_AGR_NAME );

	level.ai_tank_minigun_flash_3p = "killstreaks/fx_agr_rocket_flash_3p";

	killstreaks::register( AI_TANK_AGR_NAME, AI_TANK_WEAPON_NAME, "killstreak_ai_tank_drop", "ai_tank_drop_used",&useKillstreakAITankDrop );

	killstreaks::register_alt_weapon( AI_TANK_AGR_NAME, "amws_gun_turret" );
	killstreaks::register_alt_weapon( AI_TANK_AGR_NAME, "amws_launcher_turret" );
	killstreaks::register_alt_weapon( AI_TANK_AGR_NAME, "amws_gun_turret_mp_player" );
	killstreaks::register_alt_weapon( AI_TANK_AGR_NAME, "amws_launcher_turret_mp_player" );

	killstreaks::register_remote_override_weapon( AI_TANK_AGR_NAME, "killstreak_ai_tank" );
	killstreaks::register_strings( AI_TANK_AGR_NAME, &"KILLSTREAK_EARNED_AI_TANK_DROP", &"KILLSTREAK_AI_TANK_NOT_AVAILABLE", &"KILLSTREAK_AI_TANK_INBOUND", undefined, &"KILLSTREAK_AI_TANK_HACKED" );
	killstreaks::register_dialog( AI_TANK_AGR_NAME, "mpl_killstreak_ai_tank", "aiTankDialogBundle", "aiTankPilotDialogBundle", "friendlyAiTank", "enemyAiTank", "enemyAiTankMultiple", "friendlyAiTankHacked", "enemyAiTankHacked", "requestAiTank", "threatAiTank" );

	// TODO: Move to killstreak data
	level.killstreaks[AI_TANK_AGR_NAME].threatOnKill = true;
	
	remote_weapons::RegisterRemoteWeapon( "killstreak_ai_tank", &"MP_REMOTE_USE_TANK", &startTankRemoteControl, &endTankRemoteControl, AITANK_HIDE_COMPASS_ON_REMOTE_CONTROL );
	
	level.ai_tank_fov				= Cos( 160 );
	level.ai_tank_turret_weapon		= GetWeapon( "ai_tank_drone_gun" );
	level.ai_tank_turret_fire_rate	= level.ai_tank_turret_weapon.fireTime;
	level.ai_tank_remote_weapon		= GetWeapon( "killstreak_ai_tank" );

	spawns = spawnlogic::get_spawnpoint_array( "mp_tdm_spawn" );
	
	level.ai_tank_damage_fx = "killstreaks/fx_agr_damage_state";
	level.ai_tank_explode_fx = "killstreaks/fx_agr_explosion";
	level.ai_tank_crate_explode_fx = "killstreaks/fx_agr_drop_box";

	anims = [];
	anims[ anims.size ] = %o_drone_tank_missile1_fire;
	anims[ anims.size ] = %o_drone_tank_missile2_fire;
	anims[ anims.size ] = %o_drone_tank_missile3_fire;
	anims[ anims.size ] = %o_drone_tank_missile_full_reload;

	DEFAULT( bundle.ksMainTurretRecoilForceZOffset, 0 );
	DEFAULT( bundle.ksWeaponReloadTime, 0.5 );
	
	visionset_mgr::register_info( "visionset", AI_TANK_VISIONSET_ALIAS, VERSION_SHIP, 80, 16, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false  );
	
	thread register();
}

function register()
{
	clientfield::register( "vehicle", "ai_tank_death", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "ai_tank_missile_fire", VERSION_SHIP, 2, "int" );	
	clientfield::register( "vehicle", "ai_tank_stun", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "ai_tank_update_hud", VERSION_SHIP, 1, "counter" );
}

function useKillstreakAITankDrop(hardpointType)
{	
	team = self.team;
	
	if( !self supplydrop::isSupplyDropGrenadeAllowed( hardpointType ) )
	{
		return false;
	}

	killstreak_id = self killstreakrules::killstreakStart( hardpointType, team, false, false );
	if ( killstreak_id == -1 )
	{
		return false;
	}
	
	context = SpawnStruct();
	if ( !isdefined( context ) )
	{
		killstreak_stop_and_assert( hardpointType, team, killstreak_id, "Failed to spawn struct for ai tank." );
		return false;
	}
	
	context.radius = level.killstreakCoreBundle.ksAirdropAITankRadius;
	context.dist_from_boundary = AI_TANK_NAV_MESH_VALID_LOCATION_BOUNDARY;
	context.max_dist_from_location = AI_TANK_NAV_MESH_VALID_LOCATION_TOLERANCE;
	context.perform_physics_trace = true;
	context.check_same_floor = true;
	context.isLocationGood = &is_location_good;
	context.objective = &"airdrop_aitank";
	context.killstreakRef = hardpointType;
	context.validLocationSound = level.killstreakCoreBundle.ksValidAITankLocationSound;	
	context.tracemask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_WATER;
	context.dropTag = "tag_attach";
	context.dropTagOffset = ( -35, 0, 10 );
	
	result = self supplydrop::useSupplyDropMarker( killstreak_id, context );
	
	// the marker is out but the chopper is yet to come
	self notify( "supply_drop_marker_done" );

	if ( !isdefined(result) || !result )
	{
		//if( !self.supplyGrenadeDeathDrop )
			killstreakrules::killstreakStop( hardpointType, team, killstreak_id );
		return false;
	}

	self killstreaks::play_killstreak_start_dialog( AI_TANK_AGR_NAME, self.team, killstreak_id );	
	self killstreakrules::displayKillstreakStartTeamMessageToAll( AI_TANK_AGR_NAME );
	self AddWeaponStat( GetWeapon( AI_TANK_WEAPON_NAME ), "used", 1 );

	return result;
}

function crateLand( crate, category, owner, team, context )
{
	// note: original context is being changed here
	context.perform_physics_trace = false;
	context.dist_from_boundary = 24;
	context.max_dist_from_location = 96;

	if ( !crate is_location_good( crate.origin, context ) || !isdefined( owner ) || team != owner.team || ( owner EMP::EnemyEMPActive() && !owner hasperk("specialty_immuneemp") ) )
	{
		killstreakrules::killstreakStop( category, team, crate.package_contents_id );
		wait( 10 );
		
		if ( isdefined( crate ) )
			crate delete();
		
		return;
	}

	origin = crate.origin;

	crateBottom = BulletTrace( origin, origin + (0, 0, -50), false, crate );
	if ( isdefined( crateBottom ) )
	{
		origin = crateBottom["position"] + (0,0,1);
	}
	
	PlayFX( level.ai_tank_crate_explode_fx, origin, (1, 0, 0), (0, 0, 1) );
	PlaySoundAtPosition( "veh_talon_crate_exp", crate.origin );

	level thread ai_tank_killstreak_start( owner, origin, crate.package_contents_id, category );

	crate delete();
}

function is_location_good( location, context )
{
	return supplydrop::IsLocationGood( location, context ) && valid_location( location );
}

function valid_location( location )
{
	if ( !isdefined( location ) )
		location = self.origin;

	// only do this check if we are not the player, intended for deploy box only
	if ( !isPlayer( self ) )	
	{
		start = self GetCentroid();
		end = location + ( 0, 0, 16 );
	
		trace = PhysicsTrace( start, end, ( 0, 0, 0 ), ( 0, 0, 0 ), self, PHYSICS_TRACE_MASK_VEHICLE_CLIP );
	
		if ( trace["fraction"] < 1 )
			return false;
	}
	
	if( self oob::IsTouchingAnyOOBTrigger() )
	{
		return false;
	}
	
	return true;
}

function HackedCallbackPre( hacker )
{
	drone = self;
	drone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_HACKED );
	drone.owner stop_remote();
	drone.owner clientfield::set_to_player( "static_postfx", 0 );
	if( drone.controlled === true )
		visionset_mgr::deactivate( "visionset", AI_TANK_VISIONSET_ALIAS, drone.owner );
	drone.owner remote_weapons::RemoveAndAssignNewRemoteControlTrigger( drone.useTrigger );
	drone remote_weapons::EndRemoteControlWeaponUse( true );
	drone.owner unlink();	
	drone clientfield::set( "vehicletransition", 0 );
}

function HackedCallbackPost( hacker )
{
	drone = self;
	
	hacker remote_weapons::UseRemoteWeapon( drone, "killstreak_ai_tank", false );
	drone notify("WatchRemoteControlDeactivate_remoteWeapons");
	drone.killstreak_end_time = hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( drone );
}

function ConfigureTeamPost( owner, isHacked )
{
	drone = self;
	drone thread tank_watch_owner_events();
}

function ai_tank_killstreak_start( owner, origin, killstreak_id, category )
{
	team = owner.team;
	
	waittillframeend;

	if ( level.gameEnded )
		return;
	
	drone = SpawnVehicle( "spawner_bo3_ai_tank_mp", origin, (0, 0, 0), "talon" );

	if ( !isdefined( drone ) )
	{
		killstreak_stop_and_assert( category, team, killstreak_id, "Failed to spawn ai tank vehicle." );
		return;
	}
	
	drone.settings = struct::get_script_bundle( "vehiclecustomsettings", drone.scriptbundlesettings );

	drone.customDamageMonitor = true;	// Disable the default monitor_damage_as_occupant thread 
	drone.avoid_shooting_owner = true;
	drone.avoid_shooting_owner_ref_tag = AI_TANK_GUNNER_FLASH_TAG;

	drone killstreaks::configure_team( AI_TANK_AGR_NAME, killstreak_id, owner, "small_vehicle", undefined, &ConfigureTeamPost );
	drone killstreak_hacking::enable_hacking( AI_TANK_AGR_NAME, &HackedCallbackPre, &HackedCallbackPost );
	
	drone killstreaks::setup_health( AI_TANK_AGR_NAME, AI_TANK_HEALTH, 0 );
	drone.original_vehicle_type = drone.vehicletype;

	drone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	drone SetVehicleAvoidance( true );
	drone clientfield::set( "ai_tank_missile_fire", AI_TANK_MISSLE_COUNT_AFTER_RELOAD );
	drone.killstreak_id = killstreak_id;
	drone.type = "tank_drone";
	drone.dontDisconnectPaths = 1;
	drone.isStunned = false;
	drone.soundmod = "drone_land";
	drone.ignore_vehicle_underneath_splash_scalar = true;
	drone.treat_owner_damage_as_friendly_fire = true;
	drone.ignore_team_kills = true;

	drone.controlled = false;
	drone MakeVehicleUnusable();
	
	drone.numberRockets = AI_TANK_MISSLE_COUNT_AFTER_RELOAD;
	drone.warningShots = 3;
	drone SetDrawInfrared( true );
	
	//set up number for this drone
	if (!isdefined(drone.owner.numTankDrones))
		drone.owner.numTankDrones=1;
	else
		drone.owner.numTankDrones++;
	drone.ownerNumber = drone.owner.numTankDrones;
	
	// make the drone targetable
	Target_Set( drone, (0,0,20) );
	Target_SetTurretAquire( drone, false );
	
	// setup target group for missile lock on monitoring
	drone vehicle::init_target_group();
	drone vehicle::add_to_target_group( drone );
	
	drone setup_gameplay_think( category );
	
	drone.killstreak_end_time = GetTime() + AI_TANK_LIFETIME;
		
	owner remote_weapons::UseRemoteWeapon( drone, "killstreak_ai_tank", false );
	
	drone thread kill_monitor();
	drone thread deleteOnKillbrush( drone.owner );
	drone thread tank_rocket_watch_ai();
	level thread tank_game_end_think(drone);
}

function get_vehicle_name( vehicle_version )
{	
	switch( vehicle_version )
	{
		case 2:
		default:
			return "spawner_bo3_ai_tank_mp";
			break;
		
		case 1:
			return "ai_tank_drone_mp";
			break;
	}
}

function setup_gameplay_think( category )
{
	drone = self;
	
	drone thread tank_abort_think();
	drone thread tank_team_kill();
	drone thread tank_too_far_from_nav_mesh_abort_think();
	drone thread tank_death_think( category );
	drone thread tank_damage_think();
	drone thread WatchWater();
}

function tank_team_kill()
{
	self endon( "death" );
	self.owner waittill( "teamKillKicked" );
	self notify ( "death" );
}

function kill_monitor()
{
	self endon( "death" );
	
	last_kill_vo = 0;
	kill_vo_spacing = 4000;
	
	while(1)
	{
		self waittill( "killed", victim );		

		if ( !isdefined( self.owner ) || !isdefined( victim ) )
			continue;
			
		if ( self.owner == victim )
			continue;
		
		if ( level.teamBased && self.owner.team == victim.team )
			continue;
			
		if ( !self.controlled && last_kill_vo + kill_vo_spacing < GetTime() )
		{
			self killstreaks::play_pilot_dialog_on_owner( "kill", AI_TANK_AGR_NAME, self.killstreak_id );
		
			last_kill_vo = GetTime();	
		}
	}
}

function tank_abort_think()
{
	tank = self;	

	tank thread killstreaks::WaitForTimeout( AI_TANK_AGR_NAME, AI_TANK_LIFETIME, &tank_timeout_callback, "death", "emp_jammed" );
}

function tank_timeout_callback()
{
	self killstreaks::play_pilot_dialog_on_owner( "timeout", AI_TANK_AGR_NAME );
	
	self.timed_out = true;

	self notify( "death" );
}

function tank_watch_owner_events()
{
	self notify( "tank_watch_owner_events_singleton" );
	self endon ( "tank_watch_owner_events_singleton" );
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
	
	if ( isdefined( self.owner ) && ( self.controlled === true ) )
	{
		visionset_mgr::deactivate( "visionset", AI_TANK_VISIONSET_ALIAS, self.owner );
		self.owner stop_remote();
	}
	
	self.abandoned = true;

	self notify( "death" );
}

function tank_game_end_think(drone)
{
	drone endon( "death" );
	
	level waittill("game_ended");

	drone notify( "death" );
}


function stop_remote() // dead
{
	if ( !isdefined( self ) )
		return;

	self killstreaks::clear_using_remote();
	self remote_weapons::destroyRemoteHUD();	
	self util::clientNotify( "nofutz" );
}


function tank_hacked_health_update( hacker )
{
	tank = self;
	hackedDamageTaken = tank.defaultMaxHealth - tank.hackedHealth;
	assert ( hackedDamageTaken > 0 );
	if ( hackedDamageTaken > tank.damageTaken )
	{
		tank.damageTaken = hackedDamageTaken;
	}
}


function tank_damage_think()
{
	self endon( "death" );

	assert( isdefined( self.maxhealth ) );
	self.defaultMaxHealth = self.maxhealth;
	maxhealth = self.maxhealth; // actual max heath should be set now.

	self.maxhealth = 999999;
	self.health = self.maxhealth;
	self.isStunned = false;
	
	self.hackedHealthUpdateCallback = &tank_hacked_health_update;
	self.hackedHealth = killstreak_bundles::get_hacked_health( AI_TANK_AGR_NAME );
	
	low_health = false;
	self.damageTaken = 0;

	for ( ;; )
	{
		self waittill( "damage", damage, attacker, dir, point, mod, model, tag, part, weapon, flags, inflictor, chargeLevel );		
		
		self.maxhealth = 999999;
		self.health = self.maxhealth;

		if ( weapon.isEmp && (mod == "MOD_GRENADE_SPLASH"))
		{
			emp_damage_to_apply = killstreak_bundles::get_emp_grenade_damage( AI_TANK_AGR_NAME, maxhealth );
			
			if ( !isdefined( emp_damage_to_apply ) )
				emp_damage_to_apply = ( maxhealth / 2 );

			self.damageTaken += emp_damage_to_apply;
			damage = 0;
			if ( !self.isStunned && emp_damage_to_apply > 0 )
			{
				self.isStunned = true;
				challenges::stunnedTankWithEMPGrenade( attacker );
				self thread tank_stun( AI_TANK_STUN_DURATION );
			}
		}
		
		if ( !self.isStunned )
		{
			if ( weapon.doStun && (mod == "MOD_GRENADE_SPLASH" || mod == "MOD_GAS") )
			{
				self.isStunned = true;
				self thread tank_stun( AI_TANK_STUN_DURATION_PROXIMITY );
			}
		}
		
		weapon_damage = killstreak_bundles::get_weapon_damage( AI_TANK_AGR_NAME, maxhealth, attacker, weapon, mod, damage, flags, chargeLevel );		
		
		if ( !isdefined( weapon_damage ) )
		{
			if ( mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET" || weapon.name == "hatchet" || (mod == "MOD_PROJECTILE_SPLASH" && weapon.bulletImpactExplode) )
			{
				if ( isPlayer( attacker ) )
				    if ( attacker HasPerk( "specialty_armorpiercing" ) )
						damage += int( damage * level.cac_armorpiercing_data );
				
				if ( weapon.weapClass == "spread")
					damage = damage * 1.5;
				
				weapon_damage = damage * AI_TANK_BULLET_MITIGATION;
			}
			
			if ( ( mod == "MOD_PROJECTILE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_PROJECTILE_SPLASH" ) && damage != 0 && !weapon.isEmp && !weapon.bulletImpactExplode)
			{				
				weapon_damage = damage * AI_TANK_EXPLOSIVE_MITIGATION;
			}
			
			if ( !isdefined( weapon_damage ) )
			{
				weapon_damage = damage;
			}
		}		

		self.damageTaken += weapon_damage;

		if ( self.controlled )
		{
			self.owner SendKillstreakDamageEvent( int( weapon_damage ) );
			self.owner vehicle::update_damage_as_occupant( self.damageTaken, maxhealth );
		}
		
		if ( self.damageTaken >= maxhealth )
		{
			if( isdefined( self.owner ) )
				self.owner.dofutz = true;
			
			self.health = 0;
			self notify( "death", attacker, mod, weapon );
			return;
		}

		if ( !low_health && self.damageTaken > maxhealth / 1.8 )
		{
			self killstreaks::play_pilot_dialog_on_owner( "damaged", AI_TANK_AGR_NAME, self.killstreak_id );
			
			self thread tank_low_health_fx();
			low_health = true;
		}
	}
}

function tank_low_health_fx()
{
	self endon( "death" );
	
	self.damage_fx = spawn( "script_model", self GetTagOrigin("tag_origin") + (0,0,-14) );
	if ( !isdefined( self.damage_fx ) )
	{
		// intentionally not adding an AssertMsg() here
		return;
	}

	self.damage_fx SetModel( "tag_origin" );
	self.damage_fx LinkTo(self, "tag_turret", (0,0,-14), (0,0,0) );
	wait ( 0.1 );
	PlayFXOnTag( level.ai_tank_damage_fx, self.damage_fx, "tag_origin" );	
}

function deleteOnKillbrush(player)
{
	player endon("disconnect");
	self endon("death");
		
	killbrushes = GetEntArray( "trigger_hurt","classname" );

	while(1)
	{
		for (i = 0; i < killbrushes.size; i++)
		{
			if (self istouching(killbrushes[i]) )
			{
				if ( isdefined(self) )
				{
					self notify( "death", self.owner );
				}

				return;
			}
		}
		wait( 0.1 );
	}
	
}

function tank_stun( duration )
{	
	self endon( "death" );
	self notify( "stunned" );
	
	self ClearVehGoalPos();
	forward = AnglesToForward( self.angles );
	forward = self.origin + forward * 128;
	forward = forward - ( 0, 0, 64 );
	self SetTurretTargetVec( forward );
	self DisableGunnerFiring( 0, true );
	self LaserOff();
	
	if (self.controlled)
	{
		self.owner FreezeControls( true );
		
		self.owner SendKillstreakDamageEvent( 400 );
	}
	if (isdefined(self.owner.fullscreen_static))
	{
		self.owner thread remote_weapons::stunStaticFX( duration );
	}
	
	self clientfield::set( "ai_tank_stun", 1 );
	
	if( self.controlled )
		self.owner clientfield::set_to_player( "static_postfx", 1 );
	
	wait ( duration );
	
	self clientfield::set( "ai_tank_stun", 0 );
	
	if( self.controlled )
		self.owner clientfield::set_to_player( "static_postfx", 0 );

	if (self.controlled)
	{
		self.owner FreezeControls( false );
	}

	self DisableGunnerFiring( 0, false );
	self.isStunned = false;
}

function emp_crazy_death()
{
	self clientfield::set( "ai_tank_stun", 1 );
	self notify ("death");
	
	time = 0;
	randomAngle = RandomInt(360);
	while (time < 1.45)
	{
		self SetTurretTargetVec(self.origin + AnglesToForward((RandomIntRange(305, 315), int((randomAngle + time * 180)), 0)) * 100);
		if (time > 0.2)
		{
			self FireWeapon( AI_TANK_GUN_TURRET );
			if ( RandomInt(100) > 85)
			{
				rocket = self FireWeapon( AI_TANK_MISSILE_TURRET );

				if ( isdefined( rocket ) )
				{
					rocket.from_ai = true;
				}
			}
		}
		time += 0.05;
		WAIT_SERVER_FRAME;
	}
	self clientfield::set( "ai_tank_death", 1 );

	PlayFX( level.ai_tank_explode_fx, self.origin, (0, 0, 1) );
	PlaySoundAtPosition( "wpn_agr_explode", self.origin );
	WAIT_SERVER_FRAME;
	self hide();
}

function tank_death_think( hardpointName )
{	
	team = self.team;
	killstreak_id = self.killstreak_id;

	self waittill( "death", attacker, damageFromUnderneath, weapon );
	//	self waittill( "death", attacker, damageFromUnderneath, weapon, point, dir, modType );

	if ( !isdefined( self ) )
	{
		killstreak_stop_and_assert( hardpointName, team, killstreak_id, "Failed to handle death. A." );
		return;
	}

	self.dead = true;
	self LaserOff();
	
	self ClearVehGoalPos();
	
	not_abandoned = ( !isdefined( self.abandoned ) || !self.abandoned );

	if ( self.controlled == true )
	{
		self.owner SendKillstreakDamageEvent( 600 );
		self.owner remote_weapons::destroyRemoteHUD();	
	}

	self clientfield::set( "ai_tank_death", 1 );
	stunned = false;
	
	settings = self.settings;

	if ( isdefined( settings ) && ( self.timed_out === true || self.abandoned === true ) )
	{
		fx_origin = self GetTagOrigin( VAL( settings.timed_out_death_tag_1, "tag_origin" ) );
		PlayFx( VAL( settings.timed_out_death_fx_1, level.ai_tank_explode_fx ), VAL( fx_origin, self.origin ), ( 0, 0, 1 ) );
		PlaySoundAtPosition( VAL( settings.timed_out_death_sound_1, "wpn_agr_explode" ), self.origin );
	}
	else
	{
		PlayFX( level.ai_tank_explode_fx, self.origin, ( 0, 0, 1 ) );
		PlaySoundAtPosition( "wpn_agr_explode", self.origin );
	}


	if ( not_abandoned )
	{
		util::wait_network_frame();
		
		if ( !isdefined( self ) )
		{
			killstreak_stop_and_assert( hardpointName, team, killstreak_id, "Failed to handle death. B." );
			return;
		}
	}

	if ( self.controlled )
	{
		self Ghost(); // keep the view for player with the dead by using ghost, otherwise, will end up at feet of player
	}
	else
	{
		self Hide();
	}

	if (isdefined(self.damage_fx))
	{
		self.damage_fx delete();
	}
	
	attacker = self [[ level.figure_out_attacker ]]( attacker );

	if ( isdefined( attacker ) && IsPlayer( attacker ) && isdefined( self.owner ) && attacker != self.owner )
	{
		if ( self.owner util::IsEnemyPlayer( attacker ) )
		{
			
			scoreevents::processScoreEvent( "destroyed_aitank", attacker, self.owner, weapon );
			LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_AI_TANK", attacker.entnum );		
			attacker AddWeaponStat( weapon, "destroyed_aitank", 1 );
			controlled = false;
			if ( isdefined( self.wasControlledNowDead ) && self.wasControlledNowDead )
			{
				attacker AddWeaponStat( weapon, "destroyed_controlled_killstreak", 1 );
				controlled = true;
			}
			
			attacker challenges::destroyScoreStreak( weapon, controlled, true );
			attacker challenges::destroyNonAirScoreStreak_PostStatsLock( weapon );
			attacker AddWeaponStat( weapon, "destroy_aitank_or_setinel", 1 );
			
			self killstreaks::play_destroyed_dialog_on_owner( AI_TANK_AGR_NAME, self.killstreak_id );
		}
		else
		{
			//Destroyed Friendly Killstreak 
		}
	}

	if ( not_abandoned )
	{
		self util::waittill_any_timeout( 2.0, "remote_weapon_end" );
	
		if ( !isdefined( self ) )
		{
			killstreak_stop_and_assert( hardpointName, team, killstreak_id, "Failed to handle death. C." );
			return;
		}		
	}
		
	killstreakrules::killstreakStop( hardpointName, team, self.killstreak_id );

	if ( isdefined( self.aim_entity ) )
		self.aim_entity delete();

	self delete();
}

function killstreak_stop_and_assert( hardpoint_name, team, killstreak_id, assert_msg )
{
	killstreakrules::killstreakStop( hardpoint_name, team, killstreak_id );
	AssertMsg( assert_msg );
}
	
function tank_too_far_from_nav_mesh_abort_think()
{
	self endon( "death" );

	not_on_nav_mesh_count = 0;

	for ( ;; )
	{
		wait( 1 );

		not_on_nav_mesh_count = ( isdefined( GetClosestPointOnNavMesh( self.origin, AI_TANK_FURTHEST_FROM_NAVMESH_ALLOWED ) ) ? 0 : not_on_nav_mesh_count + 1 );

		if ( not_on_nav_mesh_count >= 4 )
		{
			self notify( "death" );
		}
	}
}

function tank_has_radar()
{
	if ( level.teambased )
	{
		return ( uav::HasUAV( self.team ) || satellite::HasSatellite( self.team ) );
	}

	return ( uav::HasUAV( self.entnum ) || satellite::HasSatellite( self.entnum ) );
}

function tank_get_player_enemies( on_radar )
{
	enemies = [];
	
	if ( !isdefined( on_radar ) )
	{
		on_radar = false;
	}

	if ( on_radar )
	{
		time = GetTime();
	}
	
	foreach( teamKey, team in level.alivePlayers )
	{
		if ( level.teambased && teamKey == self.team )
		{
			continue;
		}

		foreach( player in team )
		{
			if ( !valid_target( player, self.team, self.owner ) )
			{
				continue;
			}
			
			if ( on_radar )
			{
				if ( time - player.lastFireTime > 3000 && !tank_has_radar() )
				{
					continue;
				}
			}

			enemies[ enemies.size ] = player;
		}
	}

	return enemies;
}

function tank_compute_enemy_position()
{
	enemies = tank_get_player_enemies( false );
	position = undefined;

	if ( enemies.size )
	{
		x = 0;
		y = 0;
		z = 0;
		
		foreach( enemy in enemies )
		{
			x += enemy.origin[0];
			y += enemy.origin[1];
			z += enemy.origin[2];
		}

		x /= enemies.size;
		y /= enemies.size;
		z /= enemies.size;

		position = ( x, y, z );
	}

	return position;
}

function valid_target( target, team, owner )
{
	if ( !isdefined( target ) )
	{
		return false;
	}

	if ( !IsAlive( target ) )
	{
		return false;
	}

	if ( target == owner )
	{
		return false;
	}
	
	if ( IsPlayer( target ) )
	{
		if ( target.sessionstate != "playing" )
		{
			return false;
		}

		if ( isdefined( target.lastspawntime ) && GetTime() - target.lastspawntime < 3000 )
		{
			return false;
		}
		
		if ( target hasPerk( "specialty_nottargetedbyaitank" ) )
		{
			return false;
		}
	}

	if ( level.teambased )
	{
		if ( isdefined( target.team ) && team == target.team )
		{
			return false;
		}
	}

	if ( isdefined( target.owner ) && target.owner == owner )
	{
		return false;
	}

	if ( isdefined( target.script_owner ) && target.script_owner == owner )
	{
		return false;
	}
	
	if ( IS_TRUE( target.dead ) )
	{
		return false;
	}

	if ( isdefined( target.targetname ) && target.targetname == "riotshield_mp" )
	{
		if ( isdefined( target.damageTaken ) && target.damageTaken >= GetDvarInt( "riotshield_deployed_health" ) )
		{
			return false;
		}
	}

	return true;
}

function startTankRemoteControl( drone ) // self == player
{
	drone MakeVehicleUsable();
	drone ClearVehGoalPos();
	drone ClearTurretTarget();
	drone LaserOff();
	
	drone.treat_owner_damage_as_friendly_fire = false;
	drone.ignore_team_kills = false;
	
	if ( isdefined( drone.PlayerDrivenVersion ) )
		drone SetVehicleType( drone.PlayerDrivenVersion );

	drone usevehicle( self, 0 );
	drone clientfield::set( "vehicletransition", 1 );
	

	drone MakeVehicleUnusable();
	drone SetBrake( false );

	drone thread tank_rocket_watch( self );
	drone thread vehicle::monitor_missiles_locked_on_to_me( self );
	
	self vehicle::set_vehicle_drivable_time( AI_TANK_LIFETIME, drone.killstreak_end_time );
	self vehicle::update_damage_as_occupant( VAL( drone.damageTaken, 0 ), VAL( drone.defaultmaxhealth, 100 ) );
	drone update_client_ammo( drone.numberRockets, true );
	
	visionset_mgr::activate( "visionset", AI_TANK_VISIONSET_ALIAS, self, 1, 90000, 1 );
}

function endTankRemoteControl( drone, exitRequestedByOwner )
{
	not_dead = !IS_TRUE( drone.dead );

	if ( isdefined( drone.owner ) )	
	{
		drone.owner remote_weapons::destroyRemoteHUD();
	}
	
	drone.treat_owner_damage_as_friendly_fire = true;
	drone.ignore_team_kills = true;
	
	if( drone.classname == "script_vehicle")
		drone MakeVehicleUnusable();

	if ( isdefined( drone.original_vehicle_type ) && not_dead )
		drone SetVehicleType( drone.original_vehicle_type );
	
	if ( isdefined( drone.owner ) )
		drone.owner vehicle::stop_monitor_missiles_locked_on_to_me();

	if( exitRequestedByOwner && not_dead )
	{
		drone vehicle_ai::set_state( "combat" );
	}
	
	if ( drone.cobra === true && not_dead )
		drone thread amws::cobra_retract();

	if ( isdefined( drone.owner ) && ( drone.controlled === true ) )
		visionset_mgr::deactivate( "visionset", AI_TANK_VISIONSET_ALIAS, drone.owner );
	
	drone clientfield::set( "vehicletransition", 0 );
}

function perform_recoil_missile_turret( player ) // self == drone
{
	bundle = level.killstreakBundle[AI_TANK_AGR_NAME];
	Earthquake( 0.4, 0.5, self.origin, 200 );
	self perform_recoil( "tag_barrel",  ( ( IS_TRUE( self.controlled ) ? bundle.ksMainTurretRecoilForceControlled : bundle.ksMainTurretRecoilForce ) ), bundle.ksMainTurretRecoilForceZOffset );
	
	if ( self.controlled && isdefined( player ) )
	{
		player PlayRumbleOnEntity( "sniper_fire" );
	}
}

function perform_recoil( recoil_tag, force_scale_factor, force_z_offset ) // self == drone
{
	angles = self GetTagAngles( recoil_tag );
	dir = AnglesToForward( angles );
	self LaunchVehicle( dir * force_scale_factor, self.origin + ( 0, 0, force_z_offset ), false );
}

function update_client_ammo( ammo_count, driver_only_update = false ) // self == vehicle
{
	if ( !driver_only_update )
	{
		self clientfield::set( "ai_tank_missile_fire", ammo_count );
	}

	if ( self.controlled )
	{
		self.owner clientfield::increment_to_player( "ai_tank_update_hud", 1 );
	}
}

function tank_rocket_watch( player )
{
	self endon( "death" );
	player endon( "stopped_using_remote");

	if ( self.numberRockets <= 0 )
	{
		self reload_rockets( player );
	}

	if ( !self.isStunned )
	{
		self DisableDriverFiring( false );
	}
		
	while( true )
	{
		player waittill( "missile_fire", missile );
		missile.ignore_team_kills = self.ignore_team_kills;
		
		self.numberRockets--;
		self update_client_ammo( self.numberRockets );

		self perform_recoil_missile_turret( player );
		
		if ( self.numberRockets <= 0 )
		{
			self reload_rockets( player );
		}
	}
}

function tank_rocket_watch_ai()
{
	self endon( "death" );
	
	while( true )
	{
		self waittill( "missile_fire", missile );
		missile.ignore_team_kills = self.ignore_team_kills;
		missile.killCamEnt = self;
	}
}

function reload_rockets( player )
{
	bundle = level.killstreakBundle[AI_TANK_AGR_NAME];
	self DisableDriverFiring( true );
	
	// setup the "reload" time for the player's vehicle HUD
	weapon_wait_duration_ms = Int( bundle.ksWeaponReloadTime * 1000 );
	player SetVehicleWeaponWaitDuration( weapon_wait_duration_ms );
	player SetVehicleWeaponWaitEndTime( GetTime() + weapon_wait_duration_ms );

	wait ( bundle.ksWeaponReloadTime );

	self.numberRockets = AI_TANK_MISSLE_COUNT_AFTER_RELOAD;
	self update_client_ammo( self.numberRockets );

	wait (0.4);

	if ( !self.isStunned )
	{
		self DisableDriverFiring( false );
	}
}

#define AI_TANK_IN_WATER_TRACE_MINS		( -2, -2, -2 )
#define AI_TANK_IN_WATER_TRACE_MAXS		(  2,  2,  2 )
#define AI_TANK_IN_WATER_TRACE_MASK		( PHYSICS_TRACE_MASK_WATER )
#define AI_TANK_IN_WATER_TRACE_WAIT		( 0.3 )
#define AI_TANK_IN_WATER_TRACE_START	( 42 )
#define AI_TANK_IN_WATER_TRACE_REF		( 36 )
#define AI_TANK_IN_WATER_TRACE_END		( 12 )
#define AI_TANK_IN_WATER_TRACE_FRACTION	( (AI_TANK_IN_WATER_TRACE_START - AI_TANK_IN_WATER_TRACE_REF) / ( AI_TANK_IN_WATER_TRACE_START - AI_TANK_IN_WATER_TRACE_END ) )
#define AI_TANK_IN_WATER_TRACE_DISTANCE	( AI_TANK_IN_WATER_TRACE_START - AI_TANK_IN_WATER_TRACE_END )
#define AI_TANK_IN_WATER_REF_DISTANCE	( AI_TANK_IN_WATER_TRACE_REF - AI_TANK_IN_WATER_TRACE_END )
#define AI_TANK_IN_WATER_FUTZ_FRACTION	( 12 / AI_TANK_IN_WATER_TRACE_START )

function WatchWater()
{
	self endon( "death" );
			
	inWater = false;
	while( !inWater )
	{
		wait AI_TANK_IN_WATER_TRACE_WAIT;
		trace = physicstrace( self.origin + ( 0, 0, AI_TANK_IN_WATER_TRACE_START ), self.origin + ( 0, 0, AI_TANK_IN_WATER_TRACE_END ), AI_TANK_IN_WATER_TRACE_MINS, AI_TANK_IN_WATER_TRACE_MAXS, self, AI_TANK_IN_WATER_TRACE_MASK);
		inWater = ( trace["fraction"] < AI_TANK_IN_WATER_TRACE_FRACTION && trace["fraction"] != 1.0 );
		
		waterTraceDistanceFromEnd = AI_TANK_IN_WATER_TRACE_DISTANCE - ( trace["fraction"] * AI_TANK_IN_WATER_TRACE_DISTANCE );
		static_alpha = min( 1.0, waterTraceDistanceFromEnd / AI_TANK_IN_WATER_REF_DISTANCE );

		// design does not want beeping audio for when water is an issue, maybe a different kind of audio?
		if ( isdefined( self.owner ) && self.controlled )
			self.owner clientfield::set_to_player( "static_postfx", ( ( static_alpha > 0.0 ) ? 1 : 0 ) );
	}

	if( isdefined( self.owner ) )
		self.owner.dofutz = true;

	self notify( "death" );
}

