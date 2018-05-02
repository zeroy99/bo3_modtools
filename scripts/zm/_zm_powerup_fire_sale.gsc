#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_bgb_machine;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", "specialty_firesale_zombies");
#precache( "string", "ZOMBIE_POWERUP_MAX_AMMO" );

#namespace zm_powerup_fire_sale;

REGISTER_SYSTEM( "zm_powerup_fire_sale", &__init__, undefined )


//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	zm_powerups::register_powerup( "fire_sale", &grab_fire_sale );
	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "fire_sale", "p7_zm_power_up_firesale", &"ZOMBIE_POWERUP_MAX_AMMO", &func_should_drop_fire_sale, !POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, CLIENTFIELD_POWERUP_FIRE_SALE, "zombie_powerup_fire_sale_time", "zombie_powerup_fire_sale_on" );
	}
}

function grab_fire_sale( player )
{	
	level thread start_fire_sale( self );
	player thread zm_powerups::powerup_vo("firesale");
}


function start_fire_sale( item )
{
	// If chests use a special leaving wait till it is away
	if( IS_TRUE( level.custom_firesale_box_leave ) )
	{
		while( firesale_chest_is_leaving() )
		{
			WAIT_SERVER_FRAME;
		}
	}
	
	if(level.zombie_vars["zombie_powerup_fire_sale_time"] > 0 && IS_TRUE(level.zombie_vars["zombie_powerup_fire_sale_on"] ) ) // firesale already going when a new one is picked up ..just add time
	{
		level.zombie_vars["zombie_powerup_fire_sale_time"] += N_POWERUP_DEFAULT_TIME;
		return;
	}

	level notify ("powerup fire sale");
	level endon ("powerup fire sale");
	
	level thread zm_audio::sndAnnouncerPlayVox("fire_sale");
    
	level.zombie_vars["zombie_powerup_fire_sale_on"] = true;
	level.disable_firesale_drop = true;
	
	level thread toggle_fire_sale_on();
	level.zombie_vars["zombie_powerup_fire_sale_time"] = N_POWERUP_DEFAULT_TIME;
	
	if( bgb::is_team_enabled( "zm_bgb_temporal_gift" ) )
	{
		level.zombie_vars["zombie_powerup_fire_sale_time"] += N_POWERUP_DEFAULT_TIME;//Doubles the amount of time
	}

	while ( level.zombie_vars["zombie_powerup_fire_sale_time"] > 0)
	{
		WAIT_SERVER_FRAME;
		level.zombie_vars["zombie_powerup_fire_sale_time"] = level.zombie_vars["zombie_powerup_fire_sale_time"] - 0.05;
	}

	level thread check_to_clear_fire_sale();

	level.zombie_vars["zombie_powerup_fire_sale_on"] = false;
	level notify ( "fire_sale_off" );	
}

function check_to_clear_fire_sale()
{
	while( firesale_chest_is_leaving() )
	{
		WAIT_SERVER_FRAME;		
	}
	
	level.disable_firesale_drop = undefined;
}

/@
"Summary: Check if a firesale chest is in the process of still leaving or active"
@/
function firesale_chest_is_leaving()
{
	// If chests use a special leaving wait till it is away
	for( i = 0; i < level.chests.size; i++ )
	{
		if( i !== level.chest_index )
		{	
			if( level.chests[ i ].zbarrier.state === "leaving" || level.chests[ i ].zbarrier.state === "open" || level.chests[ i ].zbarrier.state === "close" || level.chests[ i ].zbarrier.state === "closing" )
			{
				return true;
			}
		}
	}
	
	return false;
}	

function toggle_fire_sale_on()
{
	level endon ("powerup fire sale");
	
	if( !isdefined ( level.zombie_vars["zombie_powerup_fire_sale_on"] ) )
	{
		return;
	}

	level thread sndFiresaleMusic_Start();

	bgb_machine::turn_on_fire_sale();

	for ( i = 0; i < level.chests.size; i++ )
	{
		show_firesale_box = level.chests[i] [[level._zombiemode_check_firesale_loc_valid_func]]();

		if ( show_firesale_box )
		{
			level.chests[i].zombie_cost = 10;

			if ( level.chest_index != i )
			{
				level.chests[i].was_temp = true;
				if ( IS_TRUE( level.chests[i].hidden ) )
				{
					level.chests[i] thread apply_fire_sale_to_chest();
				}
			}
		}
	}
	
	level notify( "fire_sale_on");
	level waittill( "fire_sale_off" );

	//allow other level logic to handle notify before removing the .was_temp value on chests
	waittillframeend;

	level thread sndFiresaleMusic_Stop();

	bgb_machine::turn_off_fire_sale();

	for ( i = 0; i < level.chests.size; i++ )
	{
		show_firesale_box = level.chests[i] [[level._zombiemode_check_firesale_loc_valid_func]]();

		if ( show_firesale_box )
		{
			if ( level.chest_index != i && IsDefined( level.chests[i].was_temp ) )
			{
				level.chests[i].was_temp = undefined;
				level thread remove_temp_chest( i );
			}

			level.chests[i].zombie_cost = level.chests[i].old_cost;
		}
	}
}

// self = magic box
function apply_fire_sale_to_chest()
{
	// if we're using the elaborate chest-leaving anims, wait for it to be over before showing the chest again
	if(self.zbarrier GetZBarrierPieceState(1) == "closing")
	{
		while(self.zbarrier GetZBarrierPieceState(1) == "closing")
		{
			wait (0.1);
		}
		self.zbarrier waittill("left");
	}
	
	wait 0.1; // need extra wait to be able to correctly set the zbarrier
	
	self thread zm_magicbox::show_chest();
}

//	Bring the chests back to normal.
function remove_temp_chest( chest_index )
{
	level.chests[chest_index].being_removed = true;

	while( isdefined( level.chests[chest_index].chest_user ) || (IsDefined(level.chests[chest_index]._box_open) && level.chests[chest_index]._box_open == true))
	{
		util::wait_network_frame();
	}
	
	if ( level.zombie_vars["zombie_powerup_fire_sale_on"] ) // Grabbed a second FireSale while temp box was open and original FireSale ended
	{
		level.chests[chest_index].was_temp = true;
		level.chests[chest_index].zombie_cost = 10;
		level.chests[chest_index].being_removed = false;
		return;
	}
	
	for( i=0; i<chest_index; i++ )
	{
		util::wait_network_frame();
	}
	
	playfx(level._effect["poltergeist"], level.chests[chest_index].orig_origin);
	level.chests[chest_index].zbarrier playsound ( "zmb_box_poof_land" );
	level.chests[chest_index].zbarrier playsound( "zmb_couch_slam" );
	util::wait_network_frame();
	
	if ( IS_TRUE( level.custom_firesale_box_leave ) )
	{   
		level.chests[chest_index] zm_magicbox::hide_chest( true );
	}
	else
	{
		level.chests[chest_index] zm_magicbox::hide_chest();
	}

	level.chests[chest_index].being_removed = false;
}

function func_should_drop_fire_sale()
{
	if( level.zombie_vars["zombie_powerup_fire_sale_on"] == true || level.chest_moves < 1 || IS_TRUE(level.disable_firesale_drop))
	{
		return false;
	}
	return true;
}

function sndFiresaleMusic_Start()
{
	array = level.chests;
	
	foreach(struct in array)
	{
		if( !isdefined( struct.sndEnt ) )
		{
			struct.sndEnt = spawn( "script_origin", struct.origin+(0,0,100));
		}
		
		if( IS_TRUE( level.player_4_vox_override ) )
			struct.sndEnt playloopsound( "mus_fire_sale_rich", 1 );
		else
			struct.sndEnt playloopsound( "mus_fire_sale", 1 );
	}
}
function sndFiresaleMusic_Stop()
{
	array = level.chests;
	
	foreach(struct in array)
	{
		if( isdefined( struct.sndEnt ) )
		{
			struct.sndEnt delete();
			struct.sndEnt = undefined;
		}
	}
}