#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perk_quick_revive.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "material", QUICK_REVIVE_SHADER );
#precache( "string", "ZOMBIE_PERK_QUICKREVIVE" );
#precache( "fx", "zombie/fx_perk_quick_revive_zmb" );

#namespace zm_perk_quick_revive;

REGISTER_SYSTEM( "zm_perk_quick_revive", &__init__, undefined )

// QUICK REVIVE ( QUICK REVIVE )

//-----------------------------------------------------------------------------------
// setup
//-----------------------------------------------------------------------------------
function __init__()
{
	enable_quick_revive_perk_for_level();
	level.check_quickrevive_hotjoin = &check_quickrevive_for_hotjoin;
}

function enable_quick_revive_perk_for_level()
{	
	// register quick revive perk for level
	zm_perks::register_perk_basic_info( PERK_QUICK_REVIVE, "revive", &revive_cost_override, &"ZOMBIE_PERK_QUICKREVIVE", GetWeapon( QUICK_REVIVE_PERK_BOTTLE_WEAPON ) );
	zm_perks::register_perk_precache_func( PERK_QUICK_REVIVE, &quick_revive_precache );
	zm_perks::register_perk_clientfields( PERK_QUICK_REVIVE, &quick_revive_register_clientfield, &quick_revive_set_clientfield );
	zm_perks::register_perk_machine( PERK_QUICK_REVIVE, &quick_revive_perk_machine_setup );
	zm_perks::register_perk_threads( PERK_QUICK_REVIVE, &give_quick_revive_perk, &take_quick_revive_perk );
	zm_perks::register_perk_host_migration_params( PERK_QUICK_REVIVE, QUICK_REVIVE_RADIANT_MACHINE_NAME, QUICK_REVIVE_MACHINE_LIGHT_FX );
	zm_perks::register_perk_machine_power_override( PERK_QUICK_REVIVE, &turn_revive_on );
	level flag::init( "solo_revive" );
	
}

function quick_revive_precache()
{
	if( IsDefined(level.quick_revive_precache_override_func) )
	{
		[[ level.quick_revive_precache_override_func ]]();
		return;
	}
	
	level._effect[QUICK_REVIVE_MACHINE_LIGHT_FX] = "zombie/fx_perk_quick_revive_zmb";
	
	level.machine_assets[PERK_QUICK_REVIVE] = SpawnStruct();
	level.machine_assets[PERK_QUICK_REVIVE].weapon = GetWeapon( QUICK_REVIVE_PERK_BOTTLE_WEAPON );
	level.machine_assets[PERK_QUICK_REVIVE].off_model = QUICK_REVIVE_MACHINE_DISABLED_MODEL;
	level.machine_assets[PERK_QUICK_REVIVE].on_model = QUICK_REVIVE_MACHINE_ACTIVE_MODEL;	
}

function quick_revive_register_clientfield()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_QUICK_REVIVE, VERSION_SHIP, 2, "int" );
}

function quick_revive_set_clientfield( state )
{
	self clientfield::set_player_uimodel( PERK_CLIENTFIELD_QUICK_REVIVE, state );
}

function quick_revive_perk_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound = "mus_perks_revive_jingle";
	use_trigger.script_string = "revive_perk";
	use_trigger.script_label = "mus_perks_revive_sting";
	use_trigger.target = QUICK_REVIVE_RADIANT_MACHINE_NAME;
	perk_machine.script_string = "revive_perk";
	perk_machine.targetname = QUICK_REVIVE_RADIANT_MACHINE_NAME;
	if(IsDefined(bump_trigger))
	{
		bump_trigger.script_string = "revive_perk";
	}
}

function revive_cost_override()
{
	solo = zm_perks::use_solo_revive();
	
	if( solo )
	{
		return 500;
	}
	else
	{
		return 1500;
	}	
}

function turn_revive_on()
{
	level endon("stop_quickrevive_logic");  

	level flag::wait_till( "start_zombie_round_logic" );

	solo_mode = 0;
	if ( zm_perks::use_solo_revive() )
	{
		solo_mode = 1;
	}
	
	if (solo_mode && !IS_TRUE(level.solo_revive_init))
	{
		level.solo_revive_init=true;
	}
	
	while ( true )
	{
		machine = getentarray("vending_revive", "targetname");
		machine_triggers = GetEntArray( "vending_revive", "target" );
		
		for( i = 0; i < machine.size; i++ )
		{
			if( level flag::exists("solo_game") && level flag::exists("solo_revive") && level flag::get("solo_game") && level flag::get("solo_revive") )
			{
				machine[i] Ghost();
				machine[i] NotSolid();
			}
			
			machine[i] SetModel(level.machine_assets[PERK_QUICK_REVIVE].off_model);
			
			if( isDefined(level.quick_revive_final_pos))
			{
				level.quick_revive_default_origin = level.quick_revive_final_pos;
			}
			
			if(!isDefined(level.quick_revive_default_origin))
			{
				level.quick_revive_default_origin = machine[i].origin;
				level.quick_revive_default_angles = machine[i].angles;
			}
			level.quick_revive_machine = machine[i];
		}
			
		array::thread_all( machine_triggers, &zm_perks::set_power_on, false );
		
		if ( IS_TRUE( level.initial_quick_revive_power_off ) )
		{
			level waittill("revive_on");	//quick revive is off at start of map (zod)
		}
		else if ( !solo_mode )
		{
			level waittill("revive_on");	//normal zombies map - quick revive is only off if COOP mode
		}
		
		for( i = 0; i < machine.size; i++ )
		{
			if(IsDefined(machine[i].classname) && machine[i].classname == "script_model")
			{
				if(IsDefined(machine[i].script_noteworthy) && machine[i].script_noteworthy == "clip")
				{
					machine_clip = machine[i];
				}
				else // then the model
				{	
					machine[i] SetModel(level.machine_assets[PERK_QUICK_REVIVE].on_model);
					machine[i] playsound("zmb_perks_power_on");
					machine[i] vibrate((0,-100,0), 0.3, 0.4, 3);
					machine_model = machine[i];
					machine[i] thread zm_perks::perk_fx( "revive_light" );
					exploder::exploder( "quick_revive_lgts" );
					machine[i] notify("stop_loopsound");
					machine[i] thread zm_perks::play_loop_on_machine();
					if (isdefined(machine_triggers[i]) )
						machine_clip = machine_triggers[i].clip;
					
					if (isdefined(machine_triggers[i]) )
						blocker_model = machine_triggers[i].blocker_model;
				}
			}
		}
		util::wait_network_frame();
		if ( solo_mode && isdefined( machine_model ) && !IS_TRUE(machine_model.ishidden) )
		{
			machine_model thread revive_solo_fx(machine_clip, blocker_model);
		}
		
		array::thread_all( machine_triggers, &zm_perks::set_power_on, true );
		if( IsDefined( level.machine_assets[ PERK_QUICK_REVIVE ].power_on_callback ) )
		{
			array::thread_all( machine, level.machine_assets[ PERK_QUICK_REVIVE ].power_on_callback );
		}
		
		level notify( "specialty_quickrevive_power_on" );
		
		if ( IsDefined( machine_model ) )
		{
			machine_model.ishidden = false;
		}
		
		notify_str = level util::waittill_any_return("revive_off","revive_hide", "stop_quickrevive_logic" );
		should_hide = false;
		if(notify_str == "revive_hide")
		{
			should_hide = true;
		}
		
		if( IsDefined( level.machine_assets[ PERK_QUICK_REVIVE ].power_off_callback ) )
		{
			array::thread_all( machine, level.machine_assets[ PERK_QUICK_REVIVE ].power_off_callback );
		}
		
		for( i = 0; i < machine.size; i++ )
		{
			if(IsDefined(machine[i].classname) && machine[i].classname == "script_model")
			{
				machine[i] zm_perks::turn_perk_off(should_hide);
			}
		}
	}
}

function reenable_quickrevive(machine_clip,solo_mode)
{
	if(isDefined(level.revive_machine_spawned) && !IS_TRUE(level.revive_machine_spawned))
	{
		return;
	}
	
	wait(.1);
	power_state = 0;
	
	if(IS_TRUE(solo_mode) ) //machine never went away in solo mode or was not in solo mode previously
	{	
		power_state = 1;
		should_pause = true;
		
		players = GetPlayers();
		foreach( player in players)
		{
			if(isDefined(player.lives) && player.lives > 0 && power_state)
			{
				should_pause = false;
			}
			else if(isDefined(player.lives) && player.lives < 1)
			{
				should_pause = true;
			}
		}
		
		if(should_pause)
		{
			zm_perks::perk_pause(PERK_QUICK_REVIVE);
		}
		else
		{
			zm_perks::perk_unpause(PERK_QUICK_REVIVE);
		}
		
		
		if(IS_TRUE(level.solo_revive_init) && level flag::get("solo_revive")  ) //if the machine has already gone away in solo mode, then make sure it goes away again
		{		
			disable_quickrevive(machine_clip);
			return;
		}
		
		
		update_quickrevive_power_state(1);
		
		unhide_quickrevive();	
		
		restart_quickrevive();
		
		level notify("revive_off");
		wait(.1);
		level notify("stop_quickrevive_logic");			
	}
	else
	{
		if ( !IS_TRUE( level._dont_unhide_quickervive_on_hotjoin))
		{
			unhide_quickrevive();
			level notify("revive_off");
			wait(.1);
		}
		level notify( "revive_hide");
		level notify("stop_quickrevive_logic");
		
		restart_quickrevive();

		//DCS: Zone power, need to find zone quick revive is in.
		triggers = GetEntArray( "zombie_vending", "targetname" );		
		foreach(trigger in triggers)
		{
			if(!isDefined(trigger.script_noteworthy))
			 continue;
			
			if (trigger.script_noteworthy == PERK_QUICK_REVIVE )
			{
				if(IsDefined(trigger.script_int))
				{
					if(level flag::get("power_on" + trigger.script_int))
					{
						power_state = 1;
					}
				}
				else
				{
					if(level flag::get("power_on"))
					{
						power_state = 1;
					}
				}	
			}
		}		

		update_quickrevive_power_state(power_state);			
	}
	
	level thread turn_revive_on();
	if(power_state)
	{	
		zm_perks::perk_unpause(PERK_QUICK_REVIVE);
		level notify("revive_on");
		wait(.1);
		level notify("specialty_quickrevive_power_on");
	}
	else
	{
		zm_perks::perk_pause(PERK_QUICK_REVIVE);	
	}
	
	if(!IS_TRUE(solo_mode) )
	{
		return;
	}
	
	should_pause = true;
	players = GetPlayers();
	foreach(player in players)
	{
		if( !zm_utility::is_player_valid(player) )
			continue;
		if ( player HasPerk(PERK_QUICK_REVIVE) )
		{
			if(!isDefined(player.lives))
				player.lives = 0;
			
			if(!isDefined(level.solo_lives_given))
				level.solo_lives_given = 0;
				
			level.solo_lives_given++;
			player.lives++;
			
			if(isDefined(player.lives) && player.lives > 0 && power_state )
			{
				should_pause = false;
			}
			else
			{
				should_pause = true;
			}							
		}
	}
	
	if(should_pause)
	{
		zm_perks::perk_pause(PERK_QUICK_REVIVE);
	}
	else
	{
		zm_perks::perk_unpause(PERK_QUICK_REVIVE);
	}	
}

function update_quick_revive(solo_mode)
{
	if(!isDefined(solo_mode))
	{
		solo_mode = false;
	}
	
	clip = undefined;
	if(isDefined(level.quick_revive_machine_clip))
	{
		clip = level.quick_revive_machine_clip;
	}
	
	// Updates Quick Revive cost
	level._custom_perks[ PERK_QUICK_REVIVE ].cost = revive_cost_override();
	
	level.quick_revive_machine thread reenable_quickrevive(clip,solo_mode);
}

function check_quickrevive_for_hotjoin()
{
	level notify( "notify_check_quickrevive_for_hotjoin" );
	level endon( "notify_check_quickrevive_for_hotjoin" );
	
	solo_mode = 0;
	should_update = 0;
	
	WAIT_SERVER_FRAME; // Wait until Disconnected player is removed from Player array
	
	players = GetPlayers();
	if ( players.size == 1 || IS_TRUE( level.force_solo_quick_revive ) )
	{
		solo_mode = 1;
		if(!level flag::get("solo_game"))
			should_update = 1;
		
		level flag::set("solo_game");
	}
	else
	{
		if(level flag::get("solo_game"))
			should_update = 1;
		
		level flag::clear("solo_game");
	}
	
	level.using_solo_revive = solo_mode;
	level.revive_machine_is_solo = solo_mode;
	
	zm::set_default_laststand_pistol(solo_mode);
	
	if(should_update && isDefined(level.quick_revive_machine))
	{
		update_quick_revive(solo_mode);	
	}
}

function revive_solo_fx(machine_clip, blocker_model)
{
	if( level flag::exists("solo_revive") && level flag::get("solo_revive") && !level flag::get("solo_game") )
	{
		return;
	}		
	
	if(isDefined(machine_clip))
	{
		level.quick_revive_machine_clip = machine_clip;
	}
	
	
	level notify("revive_solo_fx");
	level endon("revive_solo_fx");
	self endon("death");
	
	level flag::wait_till( "solo_revive" );

	if ( isdefined( level.revive_solo_fx_func ) )
	{
		level thread [[ level.revive_solo_fx_func ]]();
	}
	
	//DCS: make revive model fly away like a magic box.
	//self playsound( level.zmb_laugh_alias );

	wait(2.0);

	self playsound("zmb_box_move");

	playsoundatposition ("zmb_whoosh", self.origin );
	//playsoundatposition ("zmb_vox_ann_magicbox", self.origin );

	if(isdefined(self._linked_ent))
	{
		self Unlink();
	}
		
	self moveto(self.origin + (0,0,40),3);

	if( isDefined( level.custom_vibrate_func ) )
	{
		[[ level.custom_vibrate_func ]]( self );
	}
	else
	{
	   direction = self.origin;
	   direction = (direction[1], direction[0], 0);
	   
	   if(direction[1] < 0 || (direction[0] > 0 && direction[1] > 0))
	   {
            direction = (direction[0], direction[1] * -1, 0);
       }
       else if(direction[0] < 0)
       {
            direction = (direction[0] * -1, direction[1], 0);
       }
	   
        self Vibrate( direction, 10, 0.5, 5);
	}
	
	self waittill("movedone");
	PlayFX(level._effect["poltergeist"], self.origin);
	playsoundatposition ("zmb_box_poof", self.origin);

	//self SetModel(level.machine_assets[PERK_QUICK_REVIVE].off_model);
	if (isdefined(self.fx))
	{
		self.fx Unlink();
		self.fx delete();	
	}
	
	// DCS: remove the clip.
	if (isdefined(machine_clip))
	{
		machine_clip Hide();
		machine_clip ConnectPaths();	
	}
	
	if( IsDefined( blocker_model ) )
	{
		blocker_model Show();
	}
	
	level notify("revive_hide");
}

function disable_quickrevive(machine_clip)
{
	if ( IS_TRUE( level.solo_revive_init ) && level flag::get( "solo_revive" ) && isdefined( level.quick_revive_machine ) )
	{	
		
		triggers = GetEntArray( "zombie_vending", "targetname" );		
		foreach(trigger in triggers)
		{
			if(!isDefined(trigger.script_noteworthy))
			 continue;
			
			if (trigger.script_noteworthy == PERK_QUICK_REVIVE )
			{
				//make sure it's triggered off 
				trigger TriggerEnable( false );
			}
		}		
		
		foreach(item in level.powered_items )
		{
			if(isDefined(item.target) && isDefined(item.target.script_noteworthy) && item.target.script_noteworthy == PERK_QUICK_REVIVE )
			{
				//update the power state
				item.power = 1;
				item.self_powered = 1;
			}
		}
		
		if(isDefined(level.quick_revive_machine.original_pos) )
		{
			level.quick_revive_default_origin = level.quick_revive_machine.original_pos;
			level.quick_revive_default_angles = level.quick_revive_machine.original_angles;
		}
	
		move_org = level.quick_revive_default_origin;
		
		if(isdefined(level.quick_revive_linked_ent))
		{
			move_org = level.quick_revive_linked_ent.origin;
			
			if(isdefined(level.quick_revive_linked_ent_offset))
			{
				move_org += level.quick_revive_linked_ent_offset;
			}
			
			level.quick_revive_machine unlink();
		}
		
		level.quick_revive_machine moveto(move_org + (0,0,40),3);

		direction = level.quick_revive_machine.origin;
		direction = (direction[1], direction[0], 0);
		   
	   	if(direction[1] < 0 || (direction[0] > 0 && direction[1] > 0))
	   	{
	        direction = (direction[0], direction[1] * -1, 0);
	   	}
	   	else if(direction[0] < 0)
	   	{
	        direction = (direction[0] * -1, direction[1], 0);
	   	}
		   
	    level.quick_revive_machine Vibrate( direction, 10, 0.5, 4);
	    level.quick_revive_machine waittill("movedone");		
		
		level.quick_revive_machine hide();
		level.quick_revive_machine.ishidden = true;			
		if(isDefined(level.quick_revive_machine_clip))
		{
			level.quick_revive_machine_clip Hide();
			level.quick_revive_machine_clip ConnectPaths();
		}
	
		
		PlayFX(level._effect["poltergeist"], level.quick_revive_machine.origin);
		if(isDefined(level.quick_revive_trigger) && isDefined(level.quick_revive_trigger.blocker_model))
		{
			level.quick_revive_trigger.blocker_model show();
		}
		level notify("revive_hide");
	}
}

function unhide_quickrevive()
{
	while ( zm_perks::players_are_in_perk_area(level.quick_revive_machine))
	{
		wait(.1);
	}
	
	if(isDefined(level.quick_revive_machine_clip))
	{
		level.quick_revive_machine_clip Show();
		level.quick_revive_machine_clip DisconnectPaths();		
	}
	
	if(isDefined(level.quick_revive_final_pos))
	{
		level.quick_revive_machine.origin = level.quick_revive_final_pos;
	}
	
	PlayFX(level._effect["poltergeist"], level.quick_revive_machine.origin);
	if(isDefined(level.quick_revive_trigger) && isDefined(level.quick_revive_trigger.blocker_model))
	{
		level.quick_revive_trigger.blocker_model hide();
	}
	
	level.quick_revive_machine Show();
	level.quick_revive_machine Solid();

	if(isDefined(level.quick_revive_machine.original_pos) )
	{
		level.quick_revive_default_origin = level.quick_revive_machine.original_pos;
		level.quick_revive_default_angles = level.quick_revive_machine.original_angles;
	}
		
	direction = level.quick_revive_machine.origin;
	direction = (direction[1], direction[0], 0);
   
	if(direction[1] < 0 || (direction[0] > 0 && direction[1] > 0))
	{
		direction = (direction[0], direction[1] * -1, 0);
	}
	else if(direction[0] < 0)
	{
		direction = (direction[0] * -1, direction[1], 0);
	}
		
	// machine._linked_ent = elevator;
	// machine._linked_ent_moves = true;
	// machine._linked_ent_offset = (machine.origin - elevator.origin);	
	
	org = level.quick_revive_default_origin;
	
	if(isdefined(level.quick_revive_linked_ent))
	{
		org = level.quick_revive_linked_ent.origin;
		
		if(isdefined(level.quick_revive_linked_ent_offset))
		{
			org += level.quick_revive_linked_ent_offset;
		}
	}
	
	if(!IS_TRUE(level.quick_revive_linked_ent_moves) && (level.quick_revive_machine.origin != org) )
	{
		level.quick_revive_machine moveto(org,3);
		
		level.quick_revive_machine Vibrate( direction, 10, 0.5, 2.9);
		level.quick_revive_machine waittill("movedone");
		
		level.quick_revive_machine.angles = level.quick_revive_default_angles;
	
	}
	else
	{
		if(isdefined(level.quick_revive_linked_ent))
		{
			org = level.quick_revive_linked_ent.origin;
			
			if(isdefined(level.quick_revive_linked_ent_offset))
			{
				org += level.quick_revive_linked_ent_offset;
			}
			
			level.quick_revive_machine.origin = org;
		}
		
		level.quick_revive_machine vibrate((0,-100,0), 0.3, 0.4, 3);
	}

	if(isdefined(level.quick_revive_linked_ent))
	{
		level.quick_revive_machine LinkTo(level.quick_revive_linked_ent);
	}
	
	level.quick_revive_machine.ishidden = false;
}

function restart_quickrevive()
{
	triggers = GetEntArray( "zombie_vending", "targetname" );		
	foreach(trigger in triggers)
	{
		if(!isDefined(trigger.script_noteworthy))
		 continue;
		
		if ( trigger.script_noteworthy == PERK_QUICK_REVIVE )
		{
			trigger notify("stop_quickrevive_logic");
			trigger thread zm_perks::vending_trigger_think();
			trigger TriggerEnable( true );
		}
	}
}

function update_quickrevive_power_state(poweron)
{
	foreach(item in level.powered_items )
	{
		if(isDefined(item.target) && isDefined(item.target.script_noteworthy) && item.target.script_noteworthy == "specialty_quickrevive" )
		{
			if(item.power && !poweron)
			{
				if(!isDefined(item.powered_count))
				{
					item.powered_count = 0;
				}
				else if(item.powered_count > 0)
				{
					item.powered_count--;
				}
			}
			else if( !item.power && poweron )
			{
				if(!isDefined(item.powered_count))
				{
					item.powered_count = 0;
				}
				item.powered_count++;
			}

			
			if(!isDefined(item.depowered_count))
			{
				item.depowered_count = 0;
			}

			//update the power state
			item.power = poweron;
		}
	}
}

// ww: tracks the player's lives in solo, once a life is used then the revive trigger is moved back in to position
function solo_revive_buy_trigger_move( revive_trigger_noteworthy )
{
	self endon( "death" );
	
	revive_perk_triggers = GetEntArray( revive_trigger_noteworthy, "script_noteworthy" );
	
	foreach( revive_perk_trigger in revive_perk_triggers )
	{
		self thread solo_revive_buy_trigger_move_trigger( revive_perk_trigger );
	}
}

function solo_revive_buy_trigger_move_trigger( revive_perk_trigger )
{
	self endon( "death" );
	
	revive_perk_trigger SetInvisibleToPlayer( self );
	
	if( level.solo_lives_given >= 3 )
	{
		revive_perk_trigger TriggerEnable( false );
		exploder::stop_exploder( "quick_revive_lgts" );
		
		if(IsDefined(level._solo_revive_machine_expire_func))
		{
			revive_perk_trigger [[level._solo_revive_machine_expire_func]]();
		}

		return;
	}
	
	while( self.lives > 0 )
	{
		wait( 0.1 );
	}
	
	revive_perk_trigger SetVisibleToPlayer( self );
}

function give_quick_revive_perk()
{
	// quick revive in solo gives an extra life
	if ( zm_perks::use_solo_revive() )
	{
		self.lives = 1;
		
		if(!isDefined(level.solo_lives_given))
		{
			level.solo_lives_given = 0;
		}

		// Sometimes we want to gve the quick revive and not take a use away
		if( IsDefined(level.solo_game_free_player_quickrevive) )
		{
			level.solo_game_free_player_quickrevive = undefined;
		}
		else
		{
			level.solo_lives_given++;
		}
		
		if( level.solo_lives_given >= 3 )
		{
			level flag::set( "solo_revive" );
		}
		
		self thread solo_revive_buy_trigger_move( PERK_QUICK_REVIVE );
	}
}

function take_quick_revive_perk( b_pause, str_perk, str_result )
{
}


