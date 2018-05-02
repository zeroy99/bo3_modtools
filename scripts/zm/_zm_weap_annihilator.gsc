#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\systems\gib;

#define STR_ANNIHILATOR "hero_annihilator"

#namespace zm_weap_annihilator;

REGISTER_SYSTEM( "zm_weap_annihilator", &__init__, undefined )
	
function __init__()
{
	zm_spawner::register_zombie_death_event_callback( &check_annihilator_death );
	
	zm_hero_weapon::register_hero_weapon( STR_ANNIHILATOR );
	
	level.weaponAnnihilator = GetWeapon( STR_ANNIHILATOR );
}

function check_annihilator_death( attacker )//self = zombie
{
	if ( isdefined( self.damageweapon ) && !( self.damageweapon === level.weaponNone ))
	{
		if ( IS_EQUAL( self.damageweapon, level.weaponAnnihilator ) )
		{
			self zombie_utility::gib_random_parts();		
			GibServerUtils::Annihilate( self );			
		}
	}
}
