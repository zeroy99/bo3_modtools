#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_util;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_weap_riotshield;

#using scripts\zm\craftables\_zm_craft_shield;

#insert scripts\zm\_zm_buildables.gsh;
#insert scripts\zm\_zm_utility.gsh;

#define HINT_ICON	"riotshield_zm_icon"
#define GROUND_LEVEL 0

#precache( "material", HINT_ICON );
#precache( "string", "ZOMBIE_EQUIP_RIOTSHIELD_PICKUP_HINT_STRING" );
#precache( "triggerstring", "ZOMBIE_PICKUP_BOTTLE" );

#namespace rocketshield;

REGISTER_SYSTEM_EX( "zm_weap_rocketshield", &__init__, &__main__, undefined )

	
#define ROCKETSHIELD_NAME				"craft_shield_zm"
#define ROCKETSHIELD_WEAPON				"zod_riotshield"
#define ROCKETSHIELD_WEAPON_UPGRADED	"zod_riotshield_upgraded"
#define ROCKETSHIELD_MODEL				"wpn_t7_zmb_zod_rocket_shield_world"

#define MODEL_SHIELD_RECHARGE 			"p7_zm_zod_nitrous_tank"
#precache( "model", MODEL_SHIELD_RECHARGE );

#define ROCKETSHIELD_REFILL_ON_MAX_AMMO true

function __init__()
{
	zm_craft_shield::init( ROCKETSHIELD_NAME, ROCKETSHIELD_WEAPON, ROCKETSHIELD_MODEL );

	clientfield::register( "allplayers", "rs_ammo",	VERSION_SHIP, 1, "int" );
	
	callback::on_connect( &on_player_connect);
	callback::on_spawned( &on_player_spawned );
	
	level.weaponRiotshield = GetWeapon( ROCKETSHIELD_WEAPON );
	zm_equipment::register( ROCKETSHIELD_WEAPON, &"ZOMBIE_EQUIP_RIOTSHIELD_PICKUP_HINT_STRING", &"ZOMBIE_EQUIP_RIOTSHIELD_HOWTO", undefined, "riotshield" ); //, &zm_equip_riotshield::riotshield_activation_watcher_thread, undefined, undefined, undefined ); //, &placeShield );
	level.weaponRiotshieldUpgraded = GetWeapon( ROCKETSHIELD_WEAPON_UPGRADED );
	zm_equipment::register( ROCKETSHIELD_WEAPON_UPGRADED, &"ZOMBIE_EQUIP_RIOTSHIELD_PICKUP_HINT_STRING", &"ZOMBIE_EQUIP_RIOTSHIELD_HOWTO", undefined, "riotshield" ); 
}


function __main__()
{

	zm_equipment::register_for_level( ROCKETSHIELD_WEAPON );
	zm_equipment::include( ROCKETSHIELD_WEAPON );
	zm_equipment::set_ammo_driven( ROCKETSHIELD_WEAPON, level.weaponRiotshield.startAmmo, ROCKETSHIELD_REFILL_ON_MAX_AMMO );
	
	zm_equipment::register_for_level( ROCKETSHIELD_WEAPON_UPGRADED );
	zm_equipment::include( ROCKETSHIELD_WEAPON_UPGRADED );
	zm_equipment::set_ammo_driven( ROCKETSHIELD_WEAPON_UPGRADED, level.weaponRiotshieldUpgraded.startAmmo, ROCKETSHIELD_REFILL_ON_MAX_AMMO );
	
	SetDvar( "juke_enabled", 1 );
	
	zombie_utility::set_zombie_var( "riotshield_fling_damage_shield",			100 ); 
	zombie_utility::set_zombie_var( "riotshield_knockdown_damage_shield",		15 );
	zombie_utility::set_zombie_var( "riotshield_juke_damage_shield",			0 ); 
	
	zombie_utility::set_zombie_var( "riotshield_fling_force_juke",				175 ); 
	
	zombie_utility::set_zombie_var( "riotshield_fling_range",					120 ); 
	zombie_utility::set_zombie_var( "riotshield_gib_range",						120 ); 
	zombie_utility::set_zombie_var( "riotshield_knockdown_range",				120 ); 

	level thread spawn_recharge_tanks(); 
	
	level.riotshield_damage_callback = &player_damage_rocketshield;
}


function on_player_connect()
{
	self thread watchFirstUse();
}

#define ROCKET_SHIELD_HINT_TEXT &"ZOMBIE_ROCKET_HINT"
#define ROCKET_SHIELD_HINT_TIMER 5

// this is rocket shield specific and shoud be moved to a different script
function watchFirstUse()
{
	self endon("disconnect");
	while ( IsDefined(self) )
	{
		self waittill ( "weapon_change", newWeapon );
		if ( newWeapon.isriotshield )
			break;
	}
	self.rocket_shield_hint_shown=1;
	zm_equipment::show_hint_text( ROCKET_SHIELD_HINT_TEXT, ROCKET_SHIELD_HINT_TIMER );
	
}

function on_player_spawned()
{
	self.player_shield_apply_damage = &player_damage_rocketshield;
	self thread player_watch_shield_juke();
	self thread player_watch_ammo_change();
	self thread player_watch_max_ammo();
	self thread player_watch_upgraded_pickup_from_table();
}

function player_watch_ammo_change()
{
	self notify("player_watch_ammo_change");
	self endon("player_watch_ammo_change");
	
	for ( ;; )
	{
		self waittill( "equipment_ammo_changed", equipment );
		if ( IsString(equipment) )
			equipment = GetWeapon(equipment);
		if ( equipment == GetWeapon(ROCKETSHIELD_WEAPON) || equipment == GetWeapon(ROCKETSHIELD_WEAPON_UPGRADED) )
		{
			self thread check_weapon_ammo( equipment );
		}
	}
}

function player_watch_max_ammo()
{
	self notify("player_watch_max_ammo");
	self endon("player_watch_max_ammo");
	
	for ( ;; )
	{
		self waittill( "zmb_max_ammo" );
		WAIT_SERVER_FRAME;
		if ( IS_TRUE(self.hasRiotShield)  )
		{
			self thread check_weapon_ammo( self.weaponRiotshield ); 
		}
	}
}


function check_weapon_ammo( weapon )
{
	WAIT_SERVER_FRAME;
	
	if ( IsDefined(self) )
	{
		ammo = self getWeaponAmmoClip( weapon );
		self clientfield::set( "rs_ammo", ammo ); 
	}
}

// if the player has gotten the upgraded shield from the side EE, give it to them whenever they pick up the shield from the crafting table
function player_watch_upgraded_pickup_from_table()
{
	self notify("player_watch_upgraded_pickup_from_table");
	self endon("player_watch_upgraded_pickup_from_table");
	
	// get the notify string for when the player picks up the shield
	str_wpn_name = level.weaponRiotshield.name;
	str_notify = str_wpn_name + "_pickup_from_table";
	
	for ( ;; )
	{
		self waittill( str_notify );
		if ( IS_TRUE( self.b_has_upgraded_shield ) )
		{
			self zm_equipment::buy( "zod_riotshield_upgraded" );
		}
	}
}


function player_damage_rocketshield( iDamage, bHeld, fromCode = false, smod = "MOD_UNKNOWN" )
{
	shieldDamage = iDamage; 
	if (IS_EQUAL(smod,"MOD_EXPLOSIVE"))
	{
		shieldDamage += iDamage * 2; 
	}
	self riotshield::player_damage_shield( shieldDamage, bHeld, fromCode, smod );
}

//*****************************************************************************
// JUKE
//*****************************************************************************

function player_watch_shield_juke() // self == player
{
	self notify("player_watch_shield_juke");
	self endon("player_watch_shield_juke");
	
	for ( ;; )
	{
		self waittill( "weapon_melee_juke", weapon );
		if ( weapon.isriotshield )
		{
			self DisableOffhandWeapons();
			self playsound( "zmb_rocketshield_start" );
			self riotshield_melee_juke(weapon);
			self playsound( "zmb_rocketshield_end" );
			self EnableOffhandWeapons();
			self thread check_weapon_ammo( weapon ); 
			self notify( "shield_juke_done" );
		}
	}
}

#define RS_JUKE_MELEE_DAMAGE_RADIUS (12*5)
#define RS_JUKE_MELEE_DAMAGE_AMOUNT 5000

function riotshield_melee_juke(weapon)
{
	self endon( "weapon_melee" );
	self endon( "weapon_melee_power" );
	self endon( "weapon_melee_charge" );
	
	start_time = GetTime(); 

	DEFAULT(level.riotshield_knockdown_enemies,[]);
	DEFAULT(level.riotshield_knockdown_gib,[]);
	DEFAULT(level.riotshield_fling_enemies,[]);
	DEFAULT(level.riotshield_fling_vecs,[]);

	while( start_time + 3000 > GetTime() )
	{
		self PlayRumbleOnEntity( "zod_shield_juke" );
		forward = AnglesToForward(self GetPlayerAngles());
		shield_damage = 0;

		enemies = riotshield_get_juke_enemies_in_range();
		if ( isdefined( level.riotshield_melee_juke_callback ) && IsFunctionPtr( level.riotshield_melee_juke_callback ) )
		{
			[[ level.riotshield_melee_juke_callback ]]( enemies );
		}
	
		foreach( zombie in enemies )
		{
			self playsound( "zmb_rocketshield_imp" );
			zombie thread riotshield::riotshield_fling_zombie( self, zombie.fling_vec, 0 );
			shield_damage += level.zombie_vars["riotshield_juke_damage_shield"];
		}

		if (shield_damage)
			self riotshield::player_damage_shield( shield_damage, false );
		
		level.riotshield_knockdown_enemies = [];
		level.riotshield_knockdown_gib = [];
		level.riotshield_fling_enemies = [];
		level.riotshield_fling_vecs = [];

		
		//riotshield_melee(); 
		wait 0.1;
	}
}

#define RIOTSHIELD_JUKE_DISTANCE (10 * 12) 
#define RIOTSHIELD_JUKE_KILL_HALFWIDTH (3 * 12) 
#define RIOTSHIELD_JUKE_KILL_HALFWIDTH_SQ (RIOTSHIELD_JUKE_KILL_HALFWIDTH * RIOTSHIELD_JUKE_KILL_HALFWIDTH) 
#define RIOTSHIELD_JUKE_KILL_VERT_LIMIT (6 * 12) 

function riotshield_get_juke_enemies_in_range()
{
	view_pos = self.origin; // GetViewPos(); //GetWeaponMuzzlePoint();
	zombies = array::get_all_closest( view_pos, GetAITeamArray( level.zombie_team ), undefined, undefined, RIOTSHIELD_JUKE_DISTANCE );
	if ( !isDefined( zombies ) )
	{
		return;
	}

	forward = AnglesToForward(self GetPlayerAngles());
	up = AnglesToUp(self GetPlayerAngles());
	segment_start = view_pos + (RIOTSHIELD_JUKE_KILL_HALFWIDTH * forward);; 	
	segment_end = segment_start + ((RIOTSHIELD_JUKE_DISTANCE-RIOTSHIELD_JUKE_KILL_HALFWIDTH) * forward);

	fling_force = level.zombie_vars["riotshield_fling_force_juke"]; 
	fling_force_vlo = fling_force * 0.5; 
	fling_force_vhi = fling_force * 0.6; 
	
	enemies = [];
	
	for ( i = 0; i < zombies.size; i++ )
	{
		if ( !IsDefined( zombies[i] ) || !IsAlive( zombies[i] ) )
		{
			// guy died on us
			continue;
		}

		if ( zombies[i].archetype == ARCHETYPE_MARGWA )
		{
			continue;
		}
		
		test_origin = zombies[i] getcentroid();

		radial_origin = PointOnSegmentNearestToPoint( segment_start, segment_end, test_origin );
		lateral = test_origin - radial_origin;
		if ( abs(lateral[2]) > RIOTSHIELD_JUKE_KILL_VERT_LIMIT )
		{
			continue;
		}
		lateral = (lateral[0],lateral[1],0);
		len = Length(lateral);
		if ( len > RIOTSHIELD_JUKE_KILL_HALFWIDTH )
		{
			continue;
		}
	
		lateral = (lateral[0],lateral[1],0); 
		zombies[i].fling_vec = fling_force * forward + randomfloatrange(fling_force_vlo,fling_force_vhi) * up; // + randomfloatrange(0,50) * (len / RIOTSHIELD_JUKE_KILL_HALFWIDTH) *lateral;
		
		
		enemies[enemies.size] = zombies[i];
	}
	
	return enemies; 
}

//*****************************************************************************
// BOTTLES
//*****************************************************************************


#define MIN_CHARGES_IN_LEVEL 3

function spawn_recharge_tanks()
{
	level flag::wait_till( "all_players_spawned" );
	
	n_spawned = 0;
	n_charges = ( level.players.size + MIN_CHARGES_IN_LEVEL );
	a_e_spawnpoints = array::randomize( struct::get_array( "zod_shield_charge" ) );
	
	foreach ( e_spawnpoint in a_e_spawnpoints )
	{
		if ( IS_TRUE( e_spawnpoint.spawned ) )
		{
			n_spawned++;
		}
	}
	
	foreach ( e_spawnpoint in a_e_spawnpoints )
	{
		if ( n_spawned < n_charges )
		{
			if ( !IS_TRUE( e_spawnpoint.spawned ) )
			{
				e_spawnpoint thread create_bottle_unitrigger( e_spawnpoint.origin, e_spawnpoint.angles );
				n_spawned++;
			}
		}
		else
		{
			break;
		}
	}
	
	level waittill( "start_of_round" );
	level thread spawn_recharge_tanks();
}

function create_bottle_unitrigger( v_origin, v_angles )
{
	s_struct = self;
	
	if ( self == level )
	{
		s_struct = SpawnStruct();
		s_struct.origin = v_origin;
		s_struct.angles = v_angles;
	}
	
	width = 128;
	height = 128;
	length = 128;

	unitrigger_stub = SpawnStruct();
	unitrigger_stub.origin = v_origin;
	unitrigger_stub.angles = v_angles;
	unitrigger_stub.script_unitrigger_type = "unitrigger_box_use";
	unitrigger_stub.cursor_hint = "HINT_NOICON";
	unitrigger_stub.script_width = width;
	unitrigger_stub.script_height = height;
	unitrigger_stub.script_length = length;
	unitrigger_stub.require_look_at = false;
	
	// store the model of the bottle pickup
	unitrigger_stub.mdl_shield_recharge = Spawn( "script_model", v_origin );
	modelname = MODEL_SHIELD_RECHARGE;
	if ( isdefined( s_struct.model ) && IsString( s_struct.model )  )
		modelname = s_struct.model;
	unitrigger_stub.mdl_shield_recharge SetModel( modelname );
	unitrigger_stub.mdl_shield_recharge.angles = v_angles;
	
	s_struct.spawned = true;
	unitrigger_stub.shield_recharge_spawnpoint = s_struct;

	unitrigger_stub.prompt_and_visibility_func = &bottle_trigger_visibility;
	zm_unitrigger::register_static_unitrigger( unitrigger_stub, &shield_recharge_trigger_think );
	
	return unitrigger_stub;
}
	
// self = unitrigger
function bottle_trigger_visibility( player )
{
	self SetHintString( &"ZOMBIE_PICKUP_BOTTLE" );
	
	
	
	// visibility
	if ( !( IS_TRUE(player.hasRiotShield) ) || ( ( player GetAmmoCount( player.weaponRiotshield ) ) == player.weaponRiotshield.maxammo ) )
	{
		b_is_invis = true;
	}
	else
	{
		b_is_invis = false;
	}
	self setInvisibleToPlayer( player, b_is_invis );
	
	return !b_is_invis;
}

// self = unitrigger
function shield_recharge_trigger_think()
{
	while( true )
	{
		self waittill( "trigger", player ); // wait until someone uses the trigger

		if( player zm_utility::in_revive_trigger() ) // revive triggers override trap triggers
		{
			continue;
		}
		
		if( IS_DRINKING( player.is_drinking ) )
		{
			continue;
		}
	
		if( !zm_utility::is_player_valid( player ) ) // ensure valid player
		{
			continue;
		}
		
		level thread bottle_trigger_activate( self.stub, player );
		
		break;
	}
}

function bottle_trigger_activate( trig_stub, player )
{
	trig_stub notify( "bottle_collected" );
	
	if ( IS_TRUE(player.hasRiotShield) )
	{
		player zm_equipment::change_ammo( player.weaponRiotshield, 1 ); 
	}
	
	v_origin = trig_stub.mdl_shield_recharge.origin;
	v_angles = trig_stub.mdl_shield_recharge.angles;
	
	trig_stub.mdl_shield_recharge Delete();

	// remove this unitrigger, now that the object is picked up
	zm_unitrigger::unregister_unitrigger( trig_stub );
	
	trig_stub.shield_recharge_spawnpoint.spawned = undefined;
}


