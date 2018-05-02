#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\table_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\flag_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\gametypes\_globallogic_score;

#insert scripts\zm\_zm_daily_challenges.gsh;
	
#define N_REACHED_ROUND_10 10
#define N_REACHED_ROUND_15 15
#define N_REACHED_ROUND_20 20
#define N_REACHED_ROUND_25 25
#define N_REACHED_ROUND_30 30
	
#define N_HEADSHOT_KILLS_IN_A_ROW_GOAL 20
	
#define STR_DAILY_CHALLENGE_FILENAME "gamedata/stats/zm/statsmilestones4.csv"

//If these two values are updated, the associated string must be updated as well
#define N_BARRIERS_REBUILT 5
#define N_REBUILD_TIME 45
	
#namespace zm_daily_challenges;

REGISTER_SYSTEM_EX( "zm_daily_challenges", &__init__, &__main__, undefined )

function __init__()
{
	callback::on_connect( &on_connect );
	callback::on_spawned( &on_spawned );
	callback::on_challenge_complete( &on_challenge_complete );
	
	zm_spawner::register_zombie_death_event_callback( &death_check_for_challenge_updates );
}

function __main__()
{
	level thread spent_points_tracking();
	level thread earned_points_tracking();
}

function on_connect()//self = player
{
	self thread round_tracking();
	self thread perk_purchase_tracking();
	self thread perk_drink_tracking();
	
	self.a_daily_challenges = [];
	self.a_daily_challenges[ N_HEADSHOT_KILLS_IN_A_ROW ] = 0;
	self.a_daily_challenges[ N_POINTS_SPENT ] = 0;
	self.a_daily_challenges[ N_POINTS_EARNED ] = 0;
	self.a_daily_challenges[ N_ROUNDS_COMPLETED ] = 0;
}

function on_spawned()
{
	self thread challenge_ingame_time_tracking();
}

function round_tracking()//self = player
{
	self endon( "disconnect" );
	
	while( true )
	{		
		level waittill( "end_of_round" );
		
		self.a_daily_challenges[ N_ROUNDS_COMPLETED ]++;
		
		switch( self.a_daily_challenges[ N_ROUNDS_COMPLETED ] )
        {
			case 10:
				self zm_stats::increment_challenge_stat( "ZM_DAILY_ROUND_10" );
				break;
				
			case 15:
				self zm_stats::increment_challenge_stat( "ZM_DAILY_ROUND_15" );
				break;
				
			case 20:
				self zm_stats::increment_challenge_stat( "ZM_DAILY_ROUND_20" );
				break;
				
			case 25:
				self zm_stats::increment_challenge_stat( "ZM_DAILY_ROUND_25" );
				break;
				
			case 30:
				self zm_stats::increment_challenge_stat( "ZM_DAILY_ROUND_30" );
				break;
        }
	}
}

function death_check_for_challenge_updates( e_attacker )//self = zombie
{
	if( !isdefined( e_attacker ) )//Make sure we aren't being recycled
	{
		return;
	}
	
	//Check for trap kill
	if( isdefined( e_attacker._trap_type ) )
	{
		if( isdefined( e_attacker.activated_by_player ) )
		{
			e_attacker.activated_by_player zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_TRAPS" );
		}
	}
	
	if( !IsPlayer( e_attacker ) )//Player checks only below
	{
		return;
	}
	
	if( IsVehicle( self ) )//workaround for issues with setting damagemod/damageweapon on vehicles
	{
		str_damagemod = self.str_damagemod;
		w_damage = self.w_damage;
	}
	else
	{
		str_damagemod = self.damagemod;
		w_damage = self.damageweapon;		
	}

	if ( w_damage.isDualWield )
	{
		w_damage = w_damage.dualWieldWeapon;
	}

	w_damage = zm_weapons::get_nonalternate_weapon( w_damage ); //switch_from_alt_weapon( w_damage );
	
	//Check for headshot kills
	if( zm_utility::is_headshot( w_damage, self.damagelocation, str_damagemod ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_HEADSHOTS" );
		
		e_attacker.a_daily_challenges[ N_HEADSHOT_KILLS_IN_A_ROW ]++;
		if( e_attacker.a_daily_challenges[ N_HEADSHOT_KILLS_IN_A_ROW ] == N_HEADSHOT_KILLS_IN_A_ROW_GOAL )
		{
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_HEADSHOTS_IN_ROW" );
		}
	}
	else
	{
		e_attacker.a_daily_challenges[ N_HEADSHOT_KILLS_IN_A_ROW ] = 0;
	}
	
	//Check for melee weapon kills
	if( str_damagemod == "MOD_MELEE" )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_MELEE" );
	}
	
	//Check for Instakill powerup kills
	if( isdefined( level.zombie_vars[e_attacker.team] ) && IS_TRUE( level.zombie_vars[e_attacker.team]["zombie_insta_kill"] ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_INSTAKILL" );
		return; //Insta-Kill strips the weapon data, no need to check for other challenges
	}	
	
	//Check for PaP kills
	if( zm_weapons::is_weapon_upgraded( w_damage ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED" );
		
		if( level.zombie_weapons[ level.start_weapon ].upgrade === w_damage )
		{
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_STARTING_PISTOL" );
		}
		
		//Check by weapon class
		switch( w_damage.weapclass )
		{
			case "mg":
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_MG" );
				break;
				
			case "pistol":
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_PISTOL" );
				break;
				
			case "smg":
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_SMG" );
				break;				
				
			case "spread":
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_SHOTGUN" );
				break;

			case "rifle":
				if( w_damage.issniperweapon )
				{
					e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_SNIPER" );
				}
				else
				{
					e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PACKED_RIFLE" );
				}
				break;
		}		
	}
	
	//Check by weapon class
	switch( w_damage.weapclass )
	{
		case "mg":
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_MG" );
			break;
				
		case "pistol":
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_PISTOL" );
			break;
			
		case "rifle":
			if( w_damage.issniperweapon )
			{
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_SNIPER" );
			}
			else
			{
				e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_RIFLE" );
			}
		break;			
			
		case "smg":
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_SMG" );
			break;			
			
		case "spread":
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_SHOTGUN" );
			break;
	}
	
	//Check for explosives
	switch( str_damagemod )
	{
		case "MOD_EXPLOSIVE":
		case "MOD_GRENADE":
		case "MOD_GRENADE_SPLASH":
		case "MOD_PROJECTILE":
		case "MOD_PROJECTILE_SPLASH":
			e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_EXPLOSIVE" );
			break;
	}	
	
	//Check specific weapons
	if( w_damage == GetWeapon( "bowie_knife" ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_BOWIE" );
	}
	
	if( w_damage == GetWeapon( "bouncingbetty" ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_BOUNCING_BETTY" );
	}
}

function spent_points_tracking()
{
	level endon( "end_game" );
	
	while( true )
	{
		level waittill( "spent_points", player, n_points );
		
		player.a_daily_challenges[ N_POINTS_SPENT ] += n_points;
		player zm_stats::increment_challenge_stat( "ZM_DAILY_SPEND_25K", n_points );
		player zm_stats::increment_challenge_stat( "ZM_DAILY_SPEND_50K", n_points );
	}
}

function earned_points_tracking()
{
	level endon( "end_game" );
	
	while( true )
	{
		level waittill( "earned_points", player, n_points );
		
		if( level.zombie_vars[player.team]["zombie_point_scalar"] == 2 )
		{
			player.a_daily_challenges[ N_POINTS_EARNED ] += n_points;
			player zm_stats::increment_challenge_stat( "ZM_DAILY_EARN_5K_WITH_2X", n_points );
		}
	}
}

function challenge_ingame_time_tracking()
{
	self endon( "disconnect" );
	self notify("stop_challenge_ingame_time_tracking");
	self endon("stop_challenge_ingame_time_tracking");

	level flag::wait_till( "start_zombie_round_logic" );
	
	for ( ;; )
	{
		wait ( 1.0 );
		zm_stats::increment_client_stat( "ZM_DAILY_CHALLENGE_INGAME_TIME" );
	}
}

//Track windows boarded up by player
function increment_windows_repaired( s_barrier )//self = player
{
	DEFAULT( self.n_dc_barriers_rebuilt, 0 );

	if( !IS_TRUE( self.b_dc_rebuild_timer_active ) )
	{
		self thread rebuild_timer();
		self.a_s_barriers_rebuilt = [];
	}
	
	if( !IsInArray( self.a_s_barriers_rebuilt, s_barrier ) )
	{
		ARRAY_ADD( self.a_s_barriers_rebuilt, s_barrier );
		self.n_dc_barriers_rebuilt++;
	}
}

function private rebuild_timer()//self = player
{
	self endon( "disconnect" );
	
	self.b_dc_rebuild_timer_active = true;
	
	wait N_REBUILD_TIME;//Wait for challenge time

	if( self.n_dc_barriers_rebuilt >= N_BARRIERS_REBUILT )
	{
		self zm_stats::increment_challenge_stat( "ZM_DAILY_REBUILD_WINDOWS" );
	}
	self.n_dc_barriers_rebuilt = 0;
	self.a_s_barriers_rebuilt = [];
	self.b_dc_rebuild_timer_active = undefined;
}

//Track magic box usage
function increment_magic_box()//self = player
{
	if( IS_TRUE( level.zombie_vars["zombie_powerup_fire_sale_on"] ) )
	{
		self zm_stats::increment_challenge_stat( "ZM_DAILY_PURCHASE_FIRE_SALE_MAGIC_BOX" );
	}
	self zm_stats::increment_challenge_stat( "ZM_DAILY_PURCHASE_MAGIC_BOX" );
}

function increment_nuked_zombie()
{
	foreach( player in level.players )
	{
		if( player.sessionstate != "spectator" )
		{
			player zm_stats::increment_challenge_stat( "ZM_DAILY_KILLS_NUKED" );
		}
	}
}

function perk_purchase_tracking()//self = player
{
	self endon( "disconnect" );
	
	while( true )
	{
		self waittill( "perk_purchased", str_perk );
		
		self zm_stats::increment_challenge_stat( "ZM_DAILY_PURCHASE_PERKS" );
	}
}

function perk_drink_tracking()//self = player
{
	self endon( "disconnect" );
	
	while( true )
	{
		self waittill( "perk_bought" );
		
		self zm_stats::increment_challenge_stat( "ZM_DAILY_DRINK_PERKS" );
	}
}

function debug_print( str_line )
{
}

function on_challenge_complete( params )
{
	n_challenge_index = params.challengeIndex;
	if( is_daily_challenge( n_challenge_index ) )
	{			
		if( isdefined( self ) )
		{
			UploadStats( self );
		}
		
		a_challenges = table::load( STR_DAILY_CHALLENGE_FILENAME, "a0" );
		str_current_challenge = a_challenges[ n_challenge_index ][ "e4" ];		
		n_players = level.players.size;
		n_time_played = game["timepassed"] / 1000;
		n_challenge_start_time = self zm_stats::get_global_stat( "zm_daily_challenge_start_time" );
		n_challenge_time_ingame = self globallogic_score::getPersStat( "ZM_DAILY_CHALLENGE_INGAME_TIME" );
		n_challenge_games_played = self zm_stats::get_global_stat( "zm_daily_challenge_games_played" );
	}	
}

function is_daily_challenge( n_challenge_index )
{
	n_row = TableLookupRowNum( STR_DAILY_CHALLENGE_FILENAME, 0, n_challenge_index );
		
	if( n_row > -1 )//Daily Challenge Check
	{
		return true;
	}
	
	return false;
}
