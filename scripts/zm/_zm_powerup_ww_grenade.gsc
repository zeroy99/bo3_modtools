#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;

#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_melee_weapon;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_POWERUP_BONUS_POINTS" );

#namespace zm_powerup_ww_grenade;

REGISTER_SYSTEM( "zm_powerup_ww_grenade", &__init__, undefined )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	zm_powerups::register_powerup( "ww_grenade", &grab_ww_grenade );
	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "ww_grenade",	"p7_zm_power_up_widows_wine", &"ZOMBIE_POWERUP_WW_GRENADE",	&zm_powerups::func_should_never_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE );
		zm_powerups::powerup_set_player_specific( "ww_grenade", POWERUP_FOR_SPECIFIC_PLAYER ); 
	}
}

function grab_ww_grenade( player )
{	
	level thread ww_grenade_powerup( self, player );
	player thread zm_powerups::powerup_vo( "bonus_points_solo" ); // TODO: Audio should uncomment this once the sounds have been set up
}

#define WW_GRENADES_PER_POWERUP 1

function ww_grenade_powerup( item, player )
{
	if ( !player laststand::player_is_in_laststand() && !(player.sessionstate == "spectator") )
	{
		if ( player HasPerk( PERK_WIDOWS_WINE ) )
		{
			//player GiveStartAmmo( player.current_lethal_grenade );
			change = WW_GRENADES_PER_POWERUP;
			
			oldammo = player getWeaponAmmoClip( player.current_lethal_grenade );
			maxammo = player.current_lethal_grenade.startAmmo; 
			newammo = int( min(maxammo, max(0, oldammo + change ) ) );
			player setWeaponAmmoClip( player.current_lethal_grenade, newammo );

		}
	}
}


