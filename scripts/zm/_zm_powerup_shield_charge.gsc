#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
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

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_POWERUP_SHIELD_CHARGE" );

#define MODEL_SHIELD_RECHARGE "p7_zm_zod_nitrous_tank"
#precache( "model", MODEL_SHIELD_RECHARGE );

#namespace zm_powerup_shield_charge;

REGISTER_SYSTEM( "zm_powerup_shield_charge", &__init__, undefined )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	zm_powerups::register_powerup( "shield_charge", &grab_shield_charge );
	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "shield_charge", MODEL_SHIELD_RECHARGE, &"ZOMBIE_POWERUP_SHIELD_CHARGE", &func_drop_when_players_own, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE );
		zm_powerups::powerup_set_statless_powerup( "shield_charge" );
	}
}

function func_drop_when_players_own()
{
	/*
	// only drop from pods
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( !players[i] laststand::player_is_in_laststand() && !(players[i].sessionstate == "spectator") )
		{
			if ( IS_TRUE(players[i].hasRiotShield)  )
			{
				return true;				
			}
		}
	}
	*/
	return false;
}

function grab_shield_charge( player )
{	
	level thread shield_charge_powerup( self, player );
	player thread zm_powerups::powerup_vo( "bonus_points_solo" ); // TODO: Audio should uncomment this once the sounds have been set up
}

function shield_charge_powerup( item, player )
{
	/*
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( !players[i] laststand::player_is_in_laststand() && !(players[i].sessionstate == "spectator") )
		{
			if ( IS_TRUE(players[i].hasRiotShield)  )
			{
				players[i] GiveStartAmmo( players[i].weaponRiotshield );
			}
		}
	}
	*/
	if ( IS_TRUE(player.hasRiotShield)  )
	{
		player GiveStartAmmo( player.weaponRiotshield );
	}
	level thread shield_on_hud( item, player.team );
}

function shield_on_hud( drop_item, player_team )
{
	self endon ("disconnect");

	// set up the hudelem
	hudelem = hud::createServerFontString( "objective", 2, player_team );
	hudelem hud::setPoint( "TOP", undefined, 0, level.zombie_vars["zombie_timer_offset"] - (level.zombie_vars["zombie_timer_offset_interval"] * 2));
	hudelem.sort = 0.5;
	hudelem.alpha = 0;
	hudelem fadeovertime(0.5);
	hudelem.alpha = 1;
	if (isdefined(drop_item))
		hudelem.label = drop_item.hint;

	// set time remaining for insta kill
	hudelem thread full_ammo_move_hud( player_team );
}

function full_ammo_move_hud( player_team )
{
	players = GetPlayers( player_team );
	
	players[0] playsoundToTeam ("zmb_full_ammo", player_team);

	wait 0.5;
	move_fade_time = 1.5;

	self FadeOverTime( move_fade_time ); 
	self MoveOverTime( move_fade_time );
	self.y = 270;
	self.alpha = 0;

	wait move_fade_time;

	self destroy();
}

