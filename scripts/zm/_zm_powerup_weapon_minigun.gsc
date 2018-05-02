#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;

#using scripts\zm\_zm;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_melee_weapon;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", "zom_icon_minigun" );
#precache( "string", "ZOMBIE_POWERUP_MINIGUN" );

#namespace zm_powerup_weapon_minigun;

REGISTER_SYSTEM( "zm_powerup_weapon_minigun", &__init__, undefined )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	zm_powerups::register_powerup( "minigun", &grab_minigun );
	zm_powerups::register_powerup_weapon( "minigun", &minigun_countdown );
	zm_powerups::powerup_set_prevent_pick_up_if_drinking( "minigun", true );
	zm_powerups::set_weapon_ignore_max_ammo( "minigun" );

	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "minigun", "zombie_pickup_minigun", &"ZOMBIE_POWERUP_MINIGUN", &func_should_drop_minigun, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, CLIENTFIELD_POWERUP_MINI_GUN, "zombie_powerup_minigun_time", "zombie_powerup_minigun_on" );
		level.zombie_powerup_weapon[ "minigun" ] = GetWeapon( "minigun" );
	}
	
	callback::on_connect( &init_player_zombie_vars);
	zm::register_actor_damage_callback( &minigun_damage_adjust );


	
}

function grab_minigun( player )
{	
	level thread minigun_weapon_powerup( player );
	player thread zm_powerups::powerup_vo( "minigun" );

	if( IsDefined( level._grab_minigun ) )
	{
		level thread [[ level._grab_minigun ]]( player );
	}
}

//	Creates zombie_vars that need to be tracked on an individual basis rather than as
//	a group.
function init_player_zombie_vars()
{	
	self.zombie_vars[ "zombie_powerup_minigun_on" ] = false; // minigun
	self.zombie_vars[ "zombie_powerup_minigun_time" ] = 0;
}

function func_should_drop_minigun()
{
	if ( zm_powerups::minigun_no_drop() )
	{
		return false;
	}
	
	return true;
}

//******************************************************************************
// Minigun powerup
//******************************************************************************
function minigun_weapon_powerup( ent_player, time )
{
	ent_player endon( "disconnect" );
	ent_player endon( "death" );
	ent_player endon( "player_downed" );
	
	if ( !IsDefined( time ) )
	{
		time = 30;
	}
	if(isDefined(level._minigun_time_override))
	{
		time = level._minigun_time_override;
	}

	// Just replenish the time if it's already active
	if ( ent_player.zombie_vars[ "zombie_powerup_minigun_on" ] && 
		 (level.zombie_powerup_weapon[ "minigun" ] == ent_player GetCurrentWeapon() || (IsDefined(ent_player.has_powerup_weapon[ "minigun" ]) && ent_player.has_powerup_weapon[ "minigun" ]) ))
	{
		if ( ent_player.zombie_vars["zombie_powerup_minigun_time"] < time )
		{
			ent_player.zombie_vars["zombie_powerup_minigun_time"] = time;
		}
		return;
	}
	
	// make sure weapons are replaced properly if the player is downed
	level._zombie_minigun_powerup_last_stand_func = &minigun_powerup_last_stand;
	
	stance_disabled = false;
	//powerup cannot be switched to if player is in prone
	if( ent_player GetStance() === "prone" )
	{
		ent_player AllowCrouch( false );
		ent_player AllowProne( false );
		stance_disabled = true;
		
		while( ent_player GetStance() != "stand" )
		{
			WAIT_SERVER_FRAME;
		}
	}
	
	zm_powerups::weapon_powerup( ent_player, time, "minigun", true );
	
	if( stance_disabled )
	{
		ent_player AllowCrouch( true );
		ent_player AllowProne( true );
	}
}

function minigun_powerup_last_stand()
{
	zm_powerups::weapon_watch_gunner_downed( "minigun" );
}

function minigun_countdown( ent_player, str_weapon_time )
{
	while ( ent_player.zombie_vars[str_weapon_time] > 0)
	{
		WAIT_SERVER_FRAME;
		ent_player.zombie_vars[str_weapon_time] = ent_player.zombie_vars[str_weapon_time] - 0.05;
	}	
}

function minigun_weapon_powerup_off()
{
	self.zombie_vars["zombie_powerup_minigun_time"] = 0;
}

function minigun_damage_adjust(  inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType  ) //self is an enemy
{
	if ( weapon.name != "minigun" )
	{
		// Don't affect damage dealt if the weapon isn't the minigun, allow other damage callbacks to be evaluated - mbettelman 1/28/2016
		return -1;
	}
	if ( self.archetype == ARCHETYPE_ZOMBIE || self.archetype == ARCHETYPE_ZOMBIE_DOG || self.archetype == ARCHETYPE_ZOMBIE_QUAD )
	{		
		n_percent_damage = self.health * (RandomFloatRange(.34, .75) );
	}
	if ( isdefined (level.minigun_damage_adjust_override) )
	{
		n_override_damage = thread [[ level.minigun_damage_adjust_override ]](  inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType  );
		if( isdefined( n_override_damage ) )
		{
			n_percent_damage = n_override_damage;
		}
	}

	
	if( isdefined( n_percent_damage ) ) 
	{
		damage += n_percent_damage;	
	}
	return damage;
}

