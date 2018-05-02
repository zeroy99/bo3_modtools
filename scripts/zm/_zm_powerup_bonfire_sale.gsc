#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;

#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_POWERUP_MAX_AMMO" );

#namespace zm_powerup_bonfire_sale;

//
// This powerup is deprecated - use it at your own risk 
//

REGISTER_SYSTEM_EX( "zm_powerup_bonfire_sale", &__init__, &__main__, undefined )


//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	zm_powerups::register_powerup( "bonfire_sale", &grab_bonfire_sale );
	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "bonfire_sale", "zombie_bonfiresale", &"ZOMBIE_POWERUP_MAX_AMMO", &zm_powerups::func_should_never_drop, !POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, CLIENTFIELD_POWERUP_BON_FIRE, "zombie_powerup_bonfire_sale_time", "zombie_powerup_bonfire_sale_on" );
		zm_powerups::powerup_set_statless_powerup( "bonfire_sale" );
	}
}

function __main__()
{
	level thread setup_bonfiresale_audio();
}

function grab_bonfire_sale( player )
{	
	level thread start_bonfire_sale( self );
	player thread zm_powerups::powerup_vo("firesale");
}

function start_bonfire_sale( item )
{
	level notify ("powerup bonfire sale");
	level endon ("powerup bonfire sale");
	
	temp_ent = spawn("script_origin", (0,0,0));
	temp_ent playloopsound ("zmb_double_point_loop");

	level.zombie_vars["zombie_powerup_bonfire_sale_on"] = true;
	level thread toggle_bonfire_sale_on();
	level.zombie_vars["zombie_powerup_bonfire_sale_time"] = N_POWERUP_DEFAULT_TIME;
	
	if( bgb::is_team_enabled( "zm_bgb_temporal_gift" ) )
	{
		level.zombie_vars["zombie_powerup_bonfire_sale_time"] += N_POWERUP_DEFAULT_TIME;//Doubles the amount of time
	}	

	while ( level.zombie_vars["zombie_powerup_bonfire_sale_time"] > 0)
	{
		WAIT_SERVER_FRAME;
		level.zombie_vars["zombie_powerup_bonfire_sale_time"] = level.zombie_vars["zombie_powerup_bonfire_sale_time"] - 0.05;
	}

	level.zombie_vars["zombie_powerup_bonfire_sale_on"] = false;
	level notify ( "bonfire_sale_off" );
	
	players = GetPlayers();
	for (i = 0; i < players.size; i++)
	{
		players[i] playsound("zmb_points_loop_off");
	}
	
	temp_ent Delete();
}

function toggle_bonfire_sale_on()
{
	level endon ("powerup bonfire sale");

	if( !isdefined ( level.zombie_vars["zombie_powerup_bonfire_sale_on"] ) )
	{
		return;
	}

	if( level.zombie_vars["zombie_powerup_bonfire_sale_on"] )
	{
		if ( isdefined( level.bonfire_init_func ) )
		{
			level thread [[ level.bonfire_init_func ]]();
		}
		level waittill( "bonfire_sale_off" );
	}
}

function setup_bonfiresale_audio()
{
	wait(2);
	
	intercom = getentarray ("intercom", "targetname");
	while(1)
	{	
		while( level.zombie_vars["zombie_powerup_fire_sale_on"] == false)
		{
			wait(0.2);		
		}	
		for(i=0;i<intercom.size;i++)
		{
			intercom[i] thread play_bonfiresale_audio();
			//PlaySoundatposition( "zmb_vox_ann_firesale", intercom[i].origin );			
		}	
		while( level.zombie_vars["zombie_powerup_fire_sale_on"] == true)
		{
			wait (0.1);		
		}
		level notify ("firesale_over");
	}
}

function play_bonfiresale_audio()
{
	if( IS_TRUE( level.sndFiresaleMusOff ) )
	{
		return;
	}
	
	if( IS_TRUE( level.sndAnnouncerIsRich ) )
	{
		self playloopsound ("mus_fire_sale_rich");
	}
	else
	{
		self playloopsound ("mus_fire_sale");
	}
	
	level waittill ("firesale_over");
	self stoploopsound ();	
}
