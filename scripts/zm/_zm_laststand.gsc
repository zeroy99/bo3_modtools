#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\version.gsh;
#insert scripts\shared\shared.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_laststand.gsh;
#insert scripts\zm\_zm_perks.gsh;

#precache( "triggerstring", "ZOMBIE_BUTTON_TO_REVIVE_PLAYER" ); 
#precache( "string", "ZOMBIE_REVIVING" );

#precache( "string", "ZOMBIE_PLAYER_IS_REVIVING_YOU", "ZOMBIE_PLAYER_NAME_0" );
#precache( "string", "ZOMBIE_PLAYER_IS_REVIVING_YOU", "ZOMBIE_PLAYER_NAME_1" );
#precache( "string", "ZOMBIE_PLAYER_IS_REVIVING_YOU", "ZOMBIE_PLAYER_NAME_2" );
#precache( "string", "ZOMBIE_PLAYER_IS_REVIVING_YOU", "ZOMBIE_PLAYER_NAME_3" );

#define SHOW_LAST_STAND_PROGRESS_BAR	false

#namespace zm_laststand;

#define N_REVIVE_VISIBILITY_DELAY	2.0		// Delay before a revived player becomes visible to zombies again
	
REGISTER_SYSTEM( "zm_laststand", &__init__, undefined )

function __init__()
{
	laststand_global_init();


	//register clientfield for each person
	level.laststand_update_clientfields = [];
	for( i = 0; i < 4; i++ )
	{
		level.laststand_update_clientfields[i] = "laststand_update" + i;
		clientfield::register( "world", level.laststand_update_clientfields[i], VERSION_SHIP, 5, "counter" );
	}



	level.weaponSuicide = GetWeapon( "death_self" );

	level.primaryProgressBarX = 0;
	level.primaryProgressBarY = 110;
	level.primaryProgressBarHeight = 4;
	level.primaryProgressBarWidth = 120;
	level.primaryProgressBarY_ss = 280;

	if( GetDvarString( "revive_trigger_radius" ) == "" )
	{
		SetDvar( "revive_trigger_radius", "40" ); 
	}

	level.lastStandGetupAllowed = false;

	DEFAULT( level.vsmgr_prio_visionset_zm_laststand, 1000 );
	visionset_mgr::register_info( "visionset", ZM_LASTSTAND_VISIONSET, VERSION_SHIP, level.vsmgr_prio_visionset_zm_laststand, 31, true, &visionset_mgr::ramp_in_thread_per_player, false );

	DEFAULT( level.vsmgr_prio_visionset_zm_death, 1100 );
	visionset_mgr::register_info( "visionset", ZM_DEATH_VISIONSET, VERSION_SHIP, level.vsmgr_prio_visionset_zm_death, 31, true, &visionset_mgr::ramp_in_thread_per_player, false );
}

function laststand_global_init()
{
	level.CONST_LASTSTAND_GETUP_COUNT_START				= 0;		// The number of laststands in type getup that the player starts with

	level.CONST_LASTSTAND_GETUP_BAR_START				= 0.5;		// Fill amount of the getup bar the first time it is used
	level.CONST_LASTSTAND_GETUP_BAR_REGEN				= 0.0025;	// Percent of the bar filled for auto fill logic
	level.CONST_LASTSTAND_GETUP_BAR_DAMAGE				= 0.1;		// Percent of the bar removed by AI damage
	
	level.player_name_directive=[];
	level.player_name_directive[0] = &"ZOMBIE_PLAYER_NAME_0";
	level.player_name_directive[1] = &"ZOMBIE_PLAYER_NAME_1";
	level.player_name_directive[2] = &"ZOMBIE_PLAYER_NAME_2";
	level.player_name_directive[3] = &"ZOMBIE_PLAYER_NAME_3";
}

function player_last_stand_stats( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	//stat tracking
	if ( isdefined( attacker ) && IsPlayer( attacker ) && attacker != self )
	{
		if ( "zcleansed" == level.gametype )
		{
			demo::bookmark( "kill", gettime(), attacker, self, 0, eInflictor );
		}
		
		if ( "zcleansed" == level.gametype )
		{
			if ( !IS_TRUE( attacker.is_zombie ) )
			{
				attacker.kills++;  // only a zombie kill increments the scoreboard, even though player stats are incremented normally
			}
			else 
			{
				attacker.downs++;  // only a human kill increments downs
			}
		} 
		else
		{
			attacker.kills++;
		}
		attacker zm_stats::increment_client_stat( "kills" );			//total kills
		attacker zm_stats::increment_player_stat( "kills" );
		attacker AddWeaponStat( weapon, "kills", 1 );

		if ( zm_utility::is_headshot( weapon, sHitLoc, sMeansOfDeath ))
		{
			attacker.headshots++;
			attacker zm_stats::increment_client_stat( "headshots" );	//headshots
			attacker AddWeaponStat( weapon, "headshots", 1 );
			attacker zm_stats::increment_player_stat( "headshots" );
		}
	}
	
	self increment_downed_stat();
	
	if( level flag::get( "solo_game" ) && !self.lives && GetNumConnectedPlayers() < 2 ) //the "solo_game" flag does not get cleared in hot join...so this would inflate the death stats in hot join
	{
		self zm_stats::increment_client_stat( "deaths" );	
		self zm_stats::increment_player_stat( "deaths" );
	}	
}

function increment_downed_stat()
{
	if ( "zcleansed" != level.gametype )
	{
		self.downs++;
	}

	self zm_stats::increment_global_stat( "TOTAL_DOWNS" );
	self zm_stats::increment_map_stat( "TOTAL_DOWNS" );
	
	self zm_stats::increment_client_stat( "downs" );	
	
	self zm_stats::increment_player_stat( "downs" );
	zoneName = self zm_utility::get_current_zone();
	if ( !isdefined( zoneName ) )
	{
		zoneName = "";
	}
	self RecordPlayerDownZombies( zoneName );
}

function PlayerLastStand( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	self notify("entering_last_stand");

	self DisableWeaponCycling();

	// check to see if we are in a game module that wants to do something with PvP damage
	if( isdefined( level._game_module_player_laststand_callback ) )
	{
		self [[ level._game_module_player_laststand_callback ]]( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
	}

	if( self laststand::player_is_in_laststand() )
	{
		return;
	}

	if (IS_TRUE(self.in_zombify_call))
	{
		return;
	}
			
	self thread player_last_stand_stats( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
	
	if( isdefined( level.playerlaststand_func ) )
	{
		[[level.playerlaststand_func]]( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
	}

	// vision set
	// moved to zm::player_laststand()
	//VisionSetLastStand( "zombie_last_stand", 1 );
	
	self.health = 1;
	self.laststand = true;
	self set_ignoreme( true );
	callback::callback( #"on_player_laststand" );
	self thread gameobjects::on_player_last_stand();
	//self thread zm_buildables::onPlayerLastStand();
	
	//self thread call_overloaded_func( "maps\_arcademode", "arcademode_player_laststand" );

	// revive trigger
	if ( !IS_TRUE( self.no_revive_trigger ) )
	{
		self revive_trigger_spawn();
	}
	else
	{
		self UndoLastStand(); // hide the overhead icon if there's no trigger
	}

	// laststand weapons
	if ( IS_TRUE( self.is_zombie ) )
	{
		self TakeAllWeapons();
		
		if ( isdefined( attacker ) && IsPlayer( attacker ) && attacker != self )
		{
			attacker notify( "killed_a_zombie_player", eInflictor, self, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
		}
	}
	else
	{
		self laststand_disable_player_weapons();
		self laststand_give_pistol();
	}

	if( IS_TRUE(level.playerSuicideAllowed ) && GetPlayers().size > 1 )
	{
		if (!isdefined(level.canPlayerSuicide) || self [[level.canPlayerSuicide]]() )
		{
			self thread suicide_trigger_spawn();
		}
	}
	
	// Reset Disabled Power Perks Array On Downed State
	//-------------------------------------------------
	if ( isdefined( self.disabled_perks ) )
	{
		self.disabled_perks = [];
	}

	if( level.lastStandGetupAllowed )
	{
		self thread laststand_getup();
	}
	else
	{
		// bleed out timer
		bleedout_time = GetDvarfloat( "player_lastStandBleedoutTime" );
		
		if( isdefined( self.n_bleedout_time_multiplier ) )
		{
			bleedout_time *= self.n_bleedout_time_multiplier;
		}

		level clientfield::increment( "laststand_update" + ( self GetEntityNumber() ), 30 );
		
		self thread laststand_bleedout( bleedout_time );
	}

	demo::bookmark( "player_downed", gettime(), self );

	self notify( "player_downed" );
	self thread refire_player_downed();
	
	//clean up revive trigger if he disconnects while in laststand
	self thread laststand::cleanup_laststand_on_disconnect();	
}

function refire_player_downed()
{
	self endon("player_revived");
	self endon("death");
	self endon("disconnect");
	wait(1.0);
	if(self.num_perks)
	{
		self notify("player_downed");
	}
}

// self = a player
function laststand_disable_player_weapons()
{
	self DisableWeaponCycling();

	weaponInventory = self GetWeaponsList( true );
	self.laststandPrimaryWeapons = self GetWeaponsListPrimaries();
	self.lastActiveWeapon = self GetCurrentWeapon();
	quickswitch = false; 
	if ( IsDefined(self) && self IsSwitchingWeapons() )
		quickswitch = true; 
	if ( self IsThrowingGrenade() && zm_utility::is_offhand_weapon( self.lastActiveWeapon ))
		quickswitch = true; 
	if ( zm_utility::is_hero_weapon( self.lastActiveWeapon ))
		quickswitch = true; 
	if ( self.lastActiveWeapon.isriotshield )
		quickswitch = true; 
	if ( quickswitch )
	{
		if ( isdefined( self.laststandPrimaryWeapons ) && self.laststandPrimaryWeapons.size > 0 )
		{
			self SwitchToWeaponImmediate();
		}
		else
		{
			self zm_weapons::give_fallback_weapon( true );
		}
		self util::waittill_any_timeout( 1, "weapon_change_complete" );
	}
	self.lastActiveWeapon = self GetCurrentWeapon();
	self SetLastStandPrevWeap( self.lastActiveWeapon );
	self.laststandpistol = undefined;

	self.hadpistol = false;

	for( i = 0; i < weaponInventory.size; i++ )
	{
		weapon = weaponInventory[i];
		
		wclass = weapon.weapClass;
		if ( weapon.isBallisticKnife )
		{
			wclass = "knife";
		}
		
		if ( ( wclass == "pistol" || wclass == "pistol spread"  || wclass == "pistolspread" ) && !isdefined( self.laststandpistol ) ) 
		{
			self.laststandpistol = weapon;
			self.hadpistol = true;

		}
		
		if ( weapon == level.weaponReviveTool || IS_EQUAL(weapon,self.weaponReviveTool) )
		{
			// this player was killed while reviving another player
			self zm_stats::increment_client_stat( "failed_sacrifices" );
			self zm_stats::increment_player_stat( "failed_sacrifices" );
			//iprintlnbold("failed the sacrifice - you died while reviving");			
		}
		else if ( weapon.isPerkBottle )
		{
			self TakeWeapon( weapon );
			self.lastActiveWeapon = level.weaponNone;
			continue;			
		}
	}
	
	if( IS_TRUE( self.hadpistol ) && isdefined( level.zombie_last_stand_pistol_memory ) )
	{
		self [ [ level.zombie_last_stand_pistol_memory ] ]();
	}

	if ( !isdefined( self.laststandpistol ) )
	{
		self.laststandpistol = level.laststandpistol;
	}
	
	self notify("weapons_taken_for_last_stand");
}


// self = a player
function laststand_enable_player_weapons()
{
	// return the player's additional primary weapon, if they retained the perk through laststand - Black Ops 3 TU1 fix
	if( self HasPerk( PERK_ADDITIONAL_PRIMARY_WEAPON ) && isdefined( self.weapon_taken_by_losing_specialty_additionalprimaryweapon ) )
 	{
		if ( isdefined(level.return_additionalprimaryweapon) )
		{
			self [[ level.return_additionalprimaryweapon ]]( self.weapon_taken_by_losing_specialty_additionalprimaryweapon );
		}
		else
		{
			self zm_weapons::give_build_kit_weapon( self.weapon_taken_by_losing_specialty_additionalprimaryweapon );
		}
	}
	else if ( isdefined(self.weapon_taken_by_losing_specialty_additionalprimaryweapon) && self.lastActiveWeapon == self.weapon_taken_by_losing_specialty_additionalprimaryweapon )
	{
		self.lastActiveWeapon = level.weaponNone;
	}
	
	if ( isdefined( self.hadpistol ) && !self.hadpistol && isdefined( self.laststandpistol ) )
	{
		self TakeWeapon( self.laststandpistol );
	}
	
	if( isdefined( self.hadpistol ) && self.hadpistol == true && isdefined( level.zombie_last_stand_ammo_return ) && isdefined( self.laststandpistol ) )
	{
		[ [ level.zombie_last_stand_ammo_return ] ]();
	}

	self EnableWeaponCycling();
	self EnableOffhandWeapons();

	// if we can't figure out what the last active weapon was, try to switch a primary weapon
	//CHRIS_P: - don't try to give the player back the mortar_round weapon ( this is if the player killed himself with a mortar round)
	if( self.lastActiveWeapon != level.weaponNone && self HasWeapon( self.lastActiveWeapon ) && !zm_utility::is_placeable_mine( self.lastActiveWeapon ) && !zm_equipment::is_equipment( self.lastActiveWeapon ) && !zm_utility::is_hero_weapon( self.lastActiveWeapon ) )
	{
		self SwitchToWeapon( self.lastActiveWeapon );
	}
	else
	{
		self SwitchToWeapon(); // Switch to any available primary
	}
	
	self.laststandpistol = undefined;
}

function laststand_has_players_weapons_returned( e_player )
{
	if( isdefined( e_player.laststandpistol ) )
	{
		return false;
	}		

	return true;
}	

function laststand_clean_up_on_disconnect( e_revivee, w_reviver, w_revive_tool )
{
	self endon( "do_revive_ended_normally" );

	reviveTrigger = e_revivee.revivetrigger;

	e_revivee waittill("disconnect");	
	
	if( isdefined( reviveTrigger ) )
	{
		reviveTrigger delete();
	}
	self laststand::cleanup_suicide_hud();
	
	if( isdefined( self.reviveProgressBar ) )
	{
		self.reviveProgressBar hud::destroyElem();
	}
	
	if( isdefined( self.reviveTextHud ) )
	{
		self.reviveTextHud destroy();
	}
	
	if ( isdefined ( w_reviver ) && isdefined( w_revive_tool ) ) // PORTIZ 8/4/16: support alternate revives that don't require a tool
	{
		self revive_give_back_weapons( w_reviver, w_revive_tool );
	}
}

function laststand_clean_up_reviving_any( e_revivee )
{
	self endon( "do_revive_ended_normally" );

	e_revivee util::waittill_any( "disconnect", "zombified", "stop_revive_trigger" );

	self.is_reviving_any--;
	if ( 0 > self.is_reviving_any )
	{
		self.is_reviving_any = 0;
	}
	
	if( isdefined( self.reviveProgressBar ) )
	{
		self.reviveProgressBar hud::destroyElem();
	}
	
	if( isdefined( self.reviveTextHud ) )
	{
		self.reviveTextHud destroy();
	}

}

function laststand_give_pistol()
{
	assert( isdefined( self.laststandpistol ) );
	assert( self.laststandpistol != level.weaponNone );

	if( isdefined( level.zombie_last_stand  ) )
	{
		[ [ level.zombie_last_stand ] ]();
	}
	else
	{
		self GiveWeapon( self.laststandpistol );
		self GiveMaxAmmo( self.laststandpistol );
		self SwitchToWeapon( self.laststandpistol );
	}
	
	// queue up a second switch to make sure it succeeds. 
	self thread wait_switch_weapon( 1, self.laststandpistol ); 
}

function wait_switch_weapon( n_delay, w_weapon )
{
	self endon ("player_revived");
	self endon ("player_suicide");
	self endon ("zombified");
	self endon ("disconnect");

	wait n_delay; 	
	self SwitchToWeapon( w_weapon );
}


function Laststand_Bleedout( delay )
{
	self endon ("player_revived");
	self endon ("player_suicide");
	self endon ("zombified");
	self endon ("disconnect");


	if ( IS_TRUE( self.is_zombie ) || IS_TRUE( self.no_revive_trigger ) )
	{
		self notify("bled_out"); 
		util::wait_network_frame(); //to guarantee the notify gets sent and processed before the rest of this script continues to turn the guy into a spectator
	
		self bleed_out();
	
		return;
	}

	//self PlayLoopSound("heart_beat",delay);	// happens on client now DSL

	// Notify client that we're in last stand.
	
	self clientfield::set( "zmbLastStand", 1 );

	self.bleedout_time = delay;

	n_default_bleedout_time = GetDvarfloat( "player_lastStandBleedoutTime" );
	n_bleedout_time = self.bleedout_time;
	n_start_time = gettime();

	while ( self.bleedout_time > Int( delay * 0.5 ) )
	{
		// If we lost the time override while down, maybe break out
		if( ( n_bleedout_time > n_default_bleedout_time ) && (!isdefined(self.n_bleedout_time_multiplier)) )
		{
			n_current_time = gettime();
			n_total_time = ( n_current_time - n_start_time ) / 1000;
			if( n_total_time > n_default_bleedout_time )
			{
				delay = 4;
				self.bleedout_time = 2;
				break;
			}
		}

		self.bleedout_time -= 1;
		wait( 1 );
	}

	visionset_mgr::activate( "visionset", ZM_DEATH_VISIONSET, self, delay * 0.5 );
	
	while ( self.bleedout_time > 0 )
	{
		self.bleedout_time -= 1;
		level clientfield::increment( "laststand_update" + ( self GetEntityNumber() ), self.bleedout_time + 1 );
		wait( 1 );
	}
	
	
	//VisionSetLastStand( "zombie_death", delay * 0.5 );

	//CODER_MOD: TOMMYK 07/13/2008
	while( isdefined( self.revivetrigger ) && isdefined( self.revivetrigger.beingRevived ) && self.revivetrigger.beingRevived == 1 )
	{
		wait( 0.1 );
	}
	
	self notify("bled_out"); 
	util::wait_network_frame(); //to guarantee the notify gets sent and processed before the rest of this script continues to turn the guy into a spectator

	self bleed_out();
	
}


function bleed_out()
{
	self laststand::cleanup_suicide_hud();
	if( isdefined( self.reviveTrigger ) )
		self.reviveTrigger delete();
	self.reviveTrigger=undefined;
	
	self clientfield::set( "zmbLastStand", 0 );
	//self AddPlayerStat( "zombie_deaths", 1 );
	self zm_stats::increment_client_stat( "deaths" );
	self zm_stats::increment_player_stat( "deaths" );
	self RecordPlayerDeathZombies();
	self.last_bleed_out_time = GetTime(); 

	self zm_equipment::take();
	self zm_hero_weapon::take_hero_weapon();

	level clientfield::increment( "laststand_update" + ( self GetEntityNumber() ), 1 );
		
	demo::bookmark( "zm_player_bledout", gettime(), self, undefined, 1 );
	
	level notify("bleed_out", self.characterindex);
	//clear the revive icon
	self UndoLastStand();
	
	visionset_mgr::deactivate( "visionset", ZM_LASTSTAND_VISIONSET, self );
	visionset_mgr::deactivate( "visionset", ZM_DEATH_VISIONSET, self );

	if (isdefined(level.is_zombie_level ) && level.is_zombie_level)
	{
		self thread [[level.player_becomes_zombie]]();
	}
	else if (isdefined(level.is_specops_level ) && level.is_specops_level)
	{
		self thread [[level.spawnSpectator]]();
	}
	else
	{
		self set_ignoreme( false );
	}
}

function suicide_trigger_spawn()
{
	radius = GetDvarint( "revive_trigger_radius" );

	self.suicidePrompt = newclientHudElem( self );
	
	self.suicidePrompt.alignX = "center";
	self.suicidePrompt.alignY = "middle";
	self.suicidePrompt.horzAlign = "center";
	self.suicidePrompt.vertAlign = "bottom";
	self.suicidePrompt.y = -170;
	if ( self IsSplitScreen() )
	{
		self.suicidePrompt.y = -132;
	}
	self.suicidePrompt.foreground = true;
	self.suicidePrompt.font = "default";
	self.suicidePrompt.fontScale = 1.5;
	self.suicidePrompt.alpha = 1;
	self.suicidePrompt.color = ( 1.0, 1.0, 1.0 );
	self.suicidePrompt.hidewheninmenu = true;

	self thread suicide_trigger_think();
}

// logic for the revive trigger
function suicide_trigger_think()
{
	self endon ( "disconnect" );
	self endon ( "zombified" );
	self endon ( "stop_revive_trigger" );
	self endon ( "player_revived");
	self endon ( "bled_out");
	self endon ("fake_death");
	level endon("end_game");
	level endon("stop_suicide_trigger");
	
	//in case the game ends while this is running
	self thread laststand::clean_up_suicide_hud_on_end_game();
	
	//in case user is holding UseButton while this is running
	self thread laststand::clean_up_suicide_hud_on_bled_out();
	
	// If player was holding use while going into last stand, wait for them to release it
	while ( self UseButtonPressed() )
	{
		wait ( 1 );
	}
	
	if(!isdefined(self.suicidePrompt))
	{
		return;
	}
	
	while( true )
	{
		wait ( 0.1 );
		
		if(!isdefined(self.suicidePrompt))
		{
			continue;
		}
					
		self.suicidePrompt setText( &"ZOMBIE_BUTTON_TO_SUICIDE" );
		
		if ( !self is_suiciding() )
		{
			continue;
		}

		self.pre_suicide_weapon = self GetCurrentWeapon();
		self GiveWeapon( level.weaponSuicide );
		self SwitchToWeapon( level.weaponSuicide );
		duration = self doCowardsWayAnims();

		suicide_success = suicide_do_suicide( duration );
		self.laststand = undefined;
		self TakeWeapon( level.weaponSuicide );

		if ( suicide_success )
		{
			self notify("player_suicide");

			util::wait_network_frame(); //to guarantee the notify gets sent and processed before the rest of this script continues to turn the guy into a spectator

			//Stat Tracking
			self zm_stats::increment_client_stat( "suicides" );
			
			self bleed_out();

			return;
		}

		self SwitchToWeapon( self.pre_suicide_weapon );
		self.pre_suicide_weapon = undefined;
	}
}

function suicide_do_suicide(duration)
{
	level endon("end_game");
	level endon("stop_suicide_trigger");
	
	suicideTime = duration; //1.5;

	timer = 0;

	suicided = false;
	
	self.suicidePrompt setText( "" );
	
	if( !isdefined(self.suicideProgressBar) )
	{
		self.suicideProgressBar = self hud::createPrimaryProgressBar();
	}

	if( !isdefined(self.suicideTextHud) )
	{
		self.suicideTextHud = newclientHudElem( self );
	}
	
	self.suicideProgressBar hud::updateBar( 0.01, 1 / suicideTime );

	self.suicideTextHud.alignX = "center";
	self.suicideTextHud.alignY = "middle";
	self.suicideTextHud.horzAlign = "center";
	self.suicideTextHud.vertAlign = "bottom";
	self.suicideTextHud.y = -173;
	if ( self IsSplitScreen() )
	{
		self.suicideTextHud.y = -147;
	}
	self.suicideTextHud.foreground = true;
	self.suicideTextHud.font = "default";
	self.suicideTextHud.fontScale = 1.8;
	self.suicideTextHud.alpha = 1;
	self.suicideTextHud.color = ( 1.0, 1.0, 1.0 );
	self.suicideTextHud.hidewheninmenu = true;
	self.suicideTextHud setText( &"ZOMBIE_SUICIDING" );
	
	while( self is_suiciding() )
	{
		WAIT_SERVER_FRAME;
		timer += 0.05;

		if( timer >= suicideTime)
		{
			suicided = true;
			break;
		}
	}
	
	if( isdefined( self.suicideProgressBar ) )
	{
		self.suicideProgressBar hud::destroyElem();
	}
	
	if( isdefined( self.suicideTextHud ) )
	{
		self.suicideTextHud destroy();
	}
	
	if ( isDefined(self.suicidePrompt) )
	{
		self.suicidePrompt setText( &"ZOMBIE_BUTTON_TO_SUICIDE" );
	}
	return suicided;
}

function can_suicide()
{
	if ( !isAlive( self ) )
	{
		return false;
	}

	if ( !self laststand::player_is_in_laststand() )
	{
		return false;
	}
		
	if ( !isdefined( self.suicidePrompt ) )
	{
		return false;
	}
	
	if ( IS_TRUE( self.is_zombie ) )
	{
		return false;
	}

	if ( IS_TRUE( level.intermission ) )
	{
		return false;
	}
		
	return true;
}

function is_suiciding( revivee )
{	
	return ( self UseButtonPressed() && can_suicide() );
}



// spawns the trigger used for the player to get revived
function revive_trigger_spawn()
{
	if ( isdefined( level.revive_trigger_spawn_override_link ) )
	{
		[[ level.revive_trigger_spawn_override_link ]]( self );
	}
	else
	{
		radius = GetDvarint( "revive_trigger_radius" );
		self.revivetrigger = spawn( "trigger_radius", (0.0,0.0,0.0), 0, radius, radius );
		self.revivetrigger setHintString( "" ); // only show the hint string if the triggerer is facing me
		self.revivetrigger setCursorHint( "HINT_NOICON" );
		self.revivetrigger SetMovingPlatformEnabled( true );
		self.revivetrigger EnableLinkTo();
		self.revivetrigger.origin = self.origin;
		self.revivetrigger LinkTo( self );
		self.revivetrigger SetInvisibleToPlayer( self );

		self.revivetrigger.beingRevived = 0;
		self.revivetrigger.createtime = gettime();
	}

	self thread revive_trigger_think();
	//self.revivetrigger thread revive_debug();
}


// logic for the revive trigger
function revive_trigger_think( t_secondary )
{
	self endon ( "disconnect" );
	self endon ( "zombified" );
	self endon ( "stop_revive_trigger" );
	level endon("end_game");
	self endon( "death" );
	
	while ( true )
	{
		WAIT_SERVER_FRAME;

		if( isdefined( t_secondary ) )
		{
			t_revive = t_secondary;
		}
		else
		{
			t_revive = self.revivetrigger;
		}		
		
		t_revive setHintString( "" );

		for ( i = 0; i < level.players.size; i++ )
		{
			n_depth = 0;
			n_depth = self depthinwater();			
			
			if( isdefined( t_secondary ) )
			{
				// ignore revive trigger touch check but use touch check with secondary
				if ( ( level.players[i] can_revive( self, true, true ) && level.players[i] IsTouching( t_revive ) ) || n_depth > 20 )
				{
					t_revive setReviveHintString( &"ZOMBIE_BUTTON_TO_REVIVE_PLAYER", self.team );
					break;			
				}
			}
			else
			{
				// PORTIZ 8/4/16: allow special revive overrides to be used
				if ( level.players[i] can_revive_via_override( self ) || level.players[i] can_revive( self ) || n_depth > 20)
				{
					// TODO: This will turn on the trigger hint for every player within
					// the radius once one of them faces the revivee, even if the others
					// are facing away. Either we have to display the hints manually here
					// (making sure to prioritize against any other hints from nearby objects),
					// or we need a new combined radius+lookat trigger type.						
					t_revive setReviveHintString( &"ZOMBIE_BUTTON_TO_REVIVE_PLAYER", self.team );
					break;			
				}
			}			
		}		

		for ( i = 0; i < level.players.size; i++ )
		{
			e_reviver = level.players[i];
			
			if( self == e_reviver || !e_reviver is_reviving( self, t_secondary ) )
			{
				continue;
			}
			
			// PORTIZ 8/4/16: if we're using a special revive override, check to see if the revive tool should be used
			if ( !isdefined( e_reviver.s_revive_override_used ) || e_reviver.s_revive_override_used.b_use_revive_tool )
			{
				w_revive_tool = level.weaponReviveTool; 
				if ( isdefined(e_reviver.weaponReviveTool) )
				{
					w_revive_tool = e_reviver.weaponReviveTool; 
				}
				
				// give the syrette
				w_reviver = e_reviver GetCurrentWeapon();
				assert( isdefined( w_reviver ) );
				if ( w_reviver == w_revive_tool )
				{
					//already reviving somebody
					continue;
				}
	
				e_reviver GiveWeapon( w_revive_tool );
				e_reviver SwitchToWeapon( w_revive_tool );
				e_reviver SetWeaponAmmoStock( w_revive_tool, 1 );
	
				e_reviver thread revive_give_back_weapons_when_done( w_reviver, w_revive_tool, self );
			}
			else
			{
				w_reviver = undefined;
				w_revive_tool = undefined; // make sure it's undefined after previous iteration of this loop
			}
			
			//CODER_MOD: TOMMY K
			b_revive_successful = e_reviver revive_do_revive( self, w_reviver, w_revive_tool, t_secondary );
			
			e_reviver notify("revive_done");
			
			//PI CHANGE: player couldn't jump - allow this again now that they are revived
			if ( IsPlayer( self ) )
			{
				self AllowJump(true);
			}
			//END PI CHANGE
			
			self.laststand = undefined;

			if( b_revive_successful )
			{
				if( isdefined( level.a_revive_success_perk_func ) )
				{
					foreach( func in level.a_revive_success_perk_func )
					{
						self [[ func ]]();
					}
				}
				
				self thread revive_success( e_reviver );
				self laststand::cleanup_suicide_hud();
					
				self notify( "stop_revive_trigger" ); // will endon primary or secondary as necessary
				return;
			}
		}
	}
}

function revive_give_back_weapons_wait( e_reviver, e_revivee )
{
	e_revivee endon ( "disconnect" );
	e_revivee endon ( "zombified" );
	e_revivee endon ( "stop_revive_trigger" );
	level endon("end_game");
	e_revivee endon( "death" );
	
	e_reviver waittill("revive_done");
}

function revive_give_back_weapons_when_done( w_reviver, w_revive_tool, e_revivee )
{
	revive_give_back_weapons_wait( self, e_revivee ); 
	
	self revive_give_back_weapons( w_reviver, w_revive_tool );
}

function revive_give_back_weapons( w_reviver, w_revive_tool )
{
	// take the syrette
	self TakeWeapon( w_revive_tool ); 

	// Don't switch to their old primary weapon if they got put into last stand while trying to revive a teammate
	if ( self laststand::player_is_in_laststand() )
	{
		return;
	}
	
	if( IsDefined( level.revive_give_back_weapons_custom_func ) && self [[ level.revive_give_back_weapons_custom_func ]] ( w_reviver ) )
	{
		return;
	}

	if ( w_reviver != level.weaponNone && !zm_utility::is_placeable_mine( w_reviver ) && !zm_equipment::is_equipment( w_reviver )&& !w_reviver.isFlourishWeapon && self HasWeapon( w_reviver ) )
	{
		self zm_weapons::switch_back_primary_weapon( w_reviver );
	}
	else 
	{
		self zm_weapons::switch_back_primary_weapon();
	}
}


function can_revive( e_revivee, ignore_sight_checks = false, ignore_touch_checks = false )
{
	if ( !isdefined( e_revivee.revivetrigger ) )
	{
		return false;
	}

	if ( !isAlive( self ) )
	{
		return false;
	}

	if ( self laststand::player_is_in_laststand() )
	{
		return false;
	}

	if( self.team != e_revivee.team ) 
	{
		return false;
	}

	if ( IS_TRUE( self.is_zombie ) )
	{
		return false;
	}

	if ( self zm_utility::has_powerup_weapon() )
	{
		return false;
	}

	if ( self zm_utility::has_hero_weapon() )
	{
		return false;
	}
	
	if ( IS_TRUE( level.can_revive_use_depthinwater_test ) && e_revivee depthinwater() > 10 )
	{
		return true;
	}

	if ( isdefined( level.can_revive ) && ![[ level.can_revive ]]( e_revivee ) )
	{
		return false;
	}

	if ( isdefined( level.can_revive_game_module ) && ![[ level.can_revive_game_module ]]( e_revivee ) )
	{
		return false;
	}

	if( !ignore_sight_checks && ( isdefined( level.revive_trigger_should_ignore_sight_checks ) ) )
	{
		ignore_sight_checks = [[ level.revive_trigger_should_ignore_sight_checks ]]( self );

		if( ignore_sight_checks && isdefined(e_revivee.revivetrigger.beingRevived) && (e_revivee.revivetrigger.beingRevived==1) )
		{
			ignore_touch_checks = true;
		}
	}

	if( !ignore_touch_checks )
	{
		if ( !self IsTouching( e_revivee.revivetrigger ) )
		{
			return false;
		}
	}

	if( !ignore_sight_checks )
	{
		if ( !self laststand::is_facing( e_revivee ) )
		{
			return false;
		}

		if ( !SightTracePassed( self.origin + ( 0, 0, 50 ), e_revivee.origin + ( 0, 0, 30 ), false, undefined ) )				
		{
			return false;
		}

		//chrisp - fix issue where guys can sometimes revive thru a wall	
		if ( !bullettracepassed( self.origin + (0, 0, 50), e_revivee.origin + (0, 0, 30), false, undefined ) )
		{
			return false;
		}	
	}

	//iprintlnbold("REVIVE IS GOOD");
	return true;
}

function is_reviving( e_revivee, t_secondary ) // self = reviver player
{
	if ( self is_reviving_via_override( e_revivee ) ) // PORTIZ 8/4/16: support special revive overrides
	{
		return true;
	}
		
	if( isdefined( t_secondary ) )
	{
		return( self UseButtonPressed() && self can_revive( e_revivee, true, true ) && self IsTouching( t_secondary ) );
	}		
	
	return ( self UseButtonPressed() && can_revive( e_revivee ) );
}

function is_reviving_any()
{	
	return IS_TRUE( self.is_reviving_any );
}

function revive_get_revive_time( e_revivee )
{
	// reviveTime used to be set from a Dvar, but this can no longer be tunable:
	// it has to match the length of the third-person revive animations for
	// co-op gameplay to run smoothly.
	reviveTime = 3;

	if ( self HasPerk( PERK_QUICK_REVIVE ) )
	{
		reviveTime = reviveTime / 2;
	}

	if ( isdefined(self.get_revive_time) )
	{
		reviveTime = self [[self.get_revive_time]](e_revivee);
	}
	
	return reviveTime;	
}

// self = reviver
function revive_do_revive( e_revivee, w_reviver, w_revive_tool, t_secondary )
{
	assert( self is_reviving( e_revivee, t_secondary ) );

	reviveTime = self revive_get_revive_time( e_revivee );

	timer = 0;
	revived = false;
	
	//CODER_MOD: TOMMYK 07/13/2008
	e_revivee.revivetrigger.beingRevived = 1;
	name = level.player_name_directive[self GetEntityNumber()];
	e_revivee.revive_hud setText( &"ZOMBIE_PLAYER_IS_REVIVING_YOU", name );
	e_revivee laststand::revive_hud_show_n_fade( 3.0 );
	
	e_revivee.revivetrigger setHintString( "" );
	
	if ( IsPlayer( e_revivee ) )
	{
		e_revivee startrevive( self );
	}

	if( SHOW_LAST_STAND_PROGRESS_BAR && !isdefined(self.reviveProgressBar) )
	{
		self.reviveProgressBar = self hud::createPrimaryProgressBar();
	}

	if( !isdefined(self.reviveTextHud) )
	{
		self.reviveTextHud = newclientHudElem( self );
	}
	
	self thread laststand_clean_up_on_disconnect( e_revivee, w_reviver, w_revive_tool );

	if ( !isdefined( self.is_reviving_any ) )
	{
		self.is_reviving_any = 0;
	}
	self.is_reviving_any++;
	self thread laststand_clean_up_reviving_any( e_revivee );
	
	if( isdefined(self.reviveProgressBar) )
	{
		self.reviveProgressBar hud::updateBar( 0.01, 1 / reviveTime );
	}

	self.reviveTextHud.alignX = "center";
	self.reviveTextHud.alignY = "middle";
	self.reviveTextHud.horzAlign = "center";
	self.reviveTextHud.vertAlign = "bottom";
	self.reviveTextHud.y = -113;
	if ( self IsSplitScreen() )
	{
		self.reviveTextHud.y = -347;
	}
	self.reviveTextHud.foreground = true;
	self.reviveTextHud.font = "default";
	self.reviveTextHud.fontScale = 1.8;
	self.reviveTextHud.alpha = 1;
	self.reviveTextHud.color = ( 1.0, 1.0, 1.0 );
	self.reviveTextHud.hidewheninmenu = true;
	self.reviveTextHud setText( &"ZOMBIE_REVIVING" );
	
	//stat tracking - failed revive
	self thread check_for_failed_revive(e_revivee);
	
	while( self is_reviving( e_revivee, t_secondary ) )
	{
		WAIT_SERVER_FRAME;
		timer += 0.05;

		if ( self laststand::player_is_in_laststand() )
		{
			break;
		}
		
		if( isdefined( e_revivee.revivetrigger.auto_revive ) && e_revivee.revivetrigger.auto_revive == true )
		{
			break;
		}

		if( timer >= reviveTime)
		{
			revived = true;
			break;
		}
	}
	
	if( isdefined( self.reviveProgressBar ) )
	{
		self.reviveProgressBar hud::destroyElem();
	}
	
	if( isdefined( self.reviveTextHud ) )
	{
		self.reviveTextHud destroy();
	}
	
	if( isdefined( e_revivee.revivetrigger.auto_revive ) && e_revivee.revivetrigger.auto_revive == true )
	{
		// ww: just fall through this part, no stoprevive
	}
	else if( !revived )
	{
		if ( IsPlayer( e_revivee ) )
		{
			e_revivee stoprevive( self );
		}
	}

	// CODER_MOD: TOMMYK 07/13/2008
	e_revivee.revivetrigger setHintString( &"ZOMBIE_BUTTON_TO_REVIVE_PLAYER" );
	e_revivee.revivetrigger.beingRevived = 0;

	self notify( "do_revive_ended_normally" );
	self.is_reviving_any--;

	// This player stopper reviving (kick of a thread to check to see if the player now bleeds out)
	if( !revived )
	{
		e_revivee thread checkforbleedout( self );
	}
	
	return revived;
}


//*****************************************************************************
// Persistent upgrade, revive upgrade lost check
//*****************************************************************************

// self = player who failed to revive a college
function checkforbleedout( player )
{
	self endon ( "player_revived" );
	self endon ( "player_suicide" );
	self endon ( "disconnect" );
	player endon( "disconnect" );

// MikeA: You now automatically lose the upgrade if you fail a revive
/*
	self waittill( "bled_out" );
*/
	
	// Only in classic mode
	if( isdefined(player) && zm_utility::is_Classic() )
	{
		DEFAULT(player.failed_revives,0);
		player.failed_revives++;
		player notify( "player_failed_revive" );
	}
}


//*****************************************************************************
//*****************************************************************************

function auto_revive( reviver, dont_enable_weapons )
{
	if( isdefined( self.revivetrigger ) )
	{
		self.revivetrigger.auto_revive = true;
		if( self.revivetrigger.beingRevived == 1 )
		{
			while( true )
			{
				if( !isdefined( self.revivetrigger ) || ( self.revivetrigger.beingRevived == 0 ) )
				{
					break;
				}
				util::wait_network_frame();
	
			}
		}
		
		if( isdefined( self.revivetrigger ) )
		{
			self.revivetrigger.auto_trigger = false;
		}
	}

	self reviveplayer();

	// Make sure max health is set back to default
	self zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );

	self clientfield::set( "zmbLastStand", 0 );
	
	self notify( "stop_revive_trigger" );
	if(isdefined(self.revivetrigger))
	{
		self.revivetrigger delete();
		self.revivetrigger = undefined;
	}
	self laststand::cleanup_suicide_hud();

	// make sure we're cleaning up visionsets when auto reviving
	visionset_mgr::deactivate( "visionset", ZM_LASTSTAND_VISIONSET, self );
	visionset_mgr::deactivate( "visionset", ZM_DEATH_VISIONSET, self );

	self notify("clear_red_flashing_overlay"); 

	self AllowJump( true );
	
	self util::delay( N_REVIVE_VISIBILITY_DELAY, "death", &set_ignoreme, false );
	self.laststand = undefined;

	//don't do this for Grief
	if(!IS_TRUE(level.isresetting_grief))
	{
		// ww: moving the revive tracking, wasn't catching below the auto_revive
		if( isPlayer( reviver ) ) //check for cases where robot companion is the reviver
		{
			reviver.revives++;
			//stat tracking
			reviver zm_stats::increment_client_stat( "revives" );
			reviver zm_stats::increment_player_stat( "revives" );
			self RecordPlayerReviveZombies( reviver );
			demo::bookmark( "zm_player_revived", gettime(), reviver, self );
		}
	}

	self notify ( "player_revived", reviver );

	// necessary wait to let bgb give back perks
	WAIT_SERVER_FRAME;

	if( !isdefined(dont_enable_weapons) || (dont_enable_weapons == false) )
	{
		self laststand_enable_player_weapons();
	}
}


function remote_revive( reviver )
{
	if ( !self laststand::player_is_in_laststand() )
	{
		return;
	}	
	self playsound( "zmb_character_remote_revived" );
	self thread auto_revive( reviver );

}


function revive_success( reviver, b_track_stats = true )
{
	// Maybe it was a whoswho corpse that was revived
	if( !IsPlayer(self) )
	{
		self notify ( "player_revived", reviver );
		return;
	}
	
	if( IS_TRUE( b_track_stats ) )
	{
		demo::bookmark( "zm_player_revived", gettime(), reviver, self );
	}
	
	self notify ( "player_revived", reviver );
	reviver notify ( "player_did_a_revive", self );
	self reviveplayer();
	
	// Make sure max health is set back to default
	self zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, false );

	//CODER_MOD: TOMMYK 06/26/2008 - For coop scoreboards
	
	//don't do this for Grief when the rounds reset
	if( !IS_TRUE(level.isresetting_grief) && IS_TRUE( b_track_stats ) )
	{
		reviver.revives++;
		//stat tracking
		reviver zm_stats::increment_client_stat( "revives" );
		reviver zm_stats::increment_player_stat( "revives" );
		reviver xp_revive_once_per_round( self );
		self RecordPlayerReviveZombies( reviver );		
		reviver.upgrade_fx_origin = self.origin;
	}
	
	if( IS_TRUE( b_track_stats ) )
	{
		reviver thread check_for_sacrifice(); //stat tracking 
	}
	
	// CODER MOD: TOMMY K - 07/30/08
	//reviver thread call_overloaded_func( "maps\_arcademode", "arcademode_player_revive" );
					
	//CODER_MOD: Jay (6/17/2008): callback to revive challenge
	if( isdefined( level.missionCallbacks ) )
	{
		// removing coop challenges for now MGORDON
		//maps\_challenges_coop::doMissionCallback( "playerRevived", reviver ); 
	}	
	
	self clientfield::set( "zmbLastStand", 0 );
	
	self.revivetrigger delete();
	self.revivetrigger = undefined;
	self laststand::cleanup_suicide_hud();

	self util::delay( N_REVIVE_VISIBILITY_DELAY, "death", &set_ignoreme, false );
  
	visionset_mgr::deactivate( "visionset", ZM_LASTSTAND_VISIONSET, self );
	visionset_mgr::deactivate( "visionset", ZM_DEATH_VISIONSET, self );

	// necessary wait to let bgb give back perks
	WAIT_SERVER_FRAME;
	self laststand_enable_player_weapons();
}

function xp_revive_once_per_round( player_being_revived )
{
	if( !isdefined(self.number_revives_per_round) )
	{
		self.number_revives_per_round = [];
	}
	
	if( !isdefined(self.number_revives_per_round[player_being_revived.characterIndex]) )
	{
		self.number_revives_per_round[player_being_revived.characterIndex] = 0;
	}

	if( self.number_revives_per_round[player_being_revived.characterIndex] == 0 )
	{
		scoreevents::processScoreEvent( "revive_an_ally", self );
	}
	self.number_revives_per_round[player_being_revived.characterIndex]++;
}


//  Function so this can be threaded and delayed.
function set_ignoreme( b_ignoreme )
{
	DEFAULT(self.laststand_ignoreme,false);
	if ( b_ignoreme != self.laststand_ignoreme )
	{
		self.laststand_ignoreme = b_ignoreme;
		if ( b_ignoreme )
			self zm_utility::increment_ignoreme();
		else
			self zm_utility::decrement_ignoreme();
	}
}


function revive_force_revive( reviver )
{
	assert( isdefined( self ) );
	assert( IsPlayer( self ) );
	assert( self laststand::player_is_in_laststand() );

	self thread revive_success( reviver );
}

function player_getup_setup()
{

	self.laststand_info = SpawnStruct();
	self.laststand_info.type_getup_lives = level.CONST_LASTSTAND_GETUP_COUNT_START;
}

function laststand_getup()
{
	self endon ("player_revived");
	self endon ("disconnect");


	self laststand::update_lives_remaining(false);

	self clientfield::set( "zmbLastStand", 1 );

	self.laststand_info.getup_bar_value = level.CONST_LASTSTAND_GETUP_BAR_START;

	self thread laststand::laststand_getup_hud();
	self thread laststand_getup_damage_watcher();

	while ( self.laststand_info.getup_bar_value < 1 )
	{
		self.laststand_info.getup_bar_value += level.CONST_LASTSTAND_GETUP_BAR_REGEN;
		WAIT_SERVER_FRAME;
	}

	self auto_revive( self );

	self clientfield::set( "zmbLastStand", 0 );
}

function laststand_getup_damage_watcher()
{
	self endon ("player_revived");
	self endon ("disconnect");

	while( true )
	{
		self waittill( "damage" );

		self.laststand_info.getup_bar_value -= level.CONST_LASTSTAND_GETUP_BAR_DAMAGE;

		if( self.laststand_info.getup_bar_value < 0 )
		{
			self.laststand_info.getup_bar_value = 0;
		}
	}
}

// a sacrifice is when a player sucessfully revives another player, but dies afterwards
function check_for_sacrifice()
{
	self util::delay_notify("sacrifice_denied",1); //dying within 1 second of reviving another player is considered to be a 'sacrifice' 
	self endon("sacrifice_denied");
	
	self waittill("player_downed");
	
	//stat tracking
	self zm_stats::increment_client_stat( "sacrifices" );
	self zm_stats::increment_player_stat( "sacrifices" );
	//iprintlnbold("sacrifice made");
}

//when a player is downed, any player that starts/stops reviving him will fail the revive if the player bleeds out
function check_for_failed_revive(e_revivee) 
{	
	self endon("disconnect");

	e_revivee endon("disconnect");	 //end if the player being revived disconnects
	e_revivee endon("player_suicide");
	
	self notify("checking_for_failed_revive"); //to prevent stacking this thread if the same player starts/stops reviving several times while the player is downed
	self endon("checking_for_failed_revive");
	
	e_revivee endon("player_revived"); //end if the player gets revived
		
	e_revivee waittill("bled_out"); // the player being revived bled out 
	
	//stat tracking
	self zm_stats::increment_client_stat( "failed_revives" );
	self zm_stats::increment_player_stat( "failed_revives" );
	//iprintlnbold("failed the revive");
}


function add_weighted_down()
{
}

//*****************************************************************************
//*****************************************************************************

// PORTIZ: allow special revive mechanics on a per player basis
// func_is_reviving: logic to check if the player is currently reviving
// func_can_revive: logic to check if the player can revive (by default, will be the same as func_is_reviving)
// b_use_revive_tool: whether or not this revive will give the player the revive tool
function register_revive_override( func_is_reviving, func_can_revive = undefined, b_use_revive_tool = false ) // self == player
{
	if ( !isdefined( self.a_s_revive_overrides ) )
	{
		self.a_s_revive_overrides = [];
	}
	
	s_revive_override = SpawnStruct();
	
	s_revive_override.func_is_reviving = func_is_reviving;
	
	if ( isdefined( func_can_revive ) )
	{
		s_revive_override.func_can_revive = func_can_revive;
	}
	else
	{
		s_revive_override.func_can_revive = func_is_reviving; // in some cases (like for zm_bgb_near_death_experience) these two cases will be the same
	}
	
	s_revive_override.b_use_revive_tool = b_use_revive_tool;
	
	self.a_s_revive_overrides[ self.a_s_revive_overrides.size ] = s_revive_override;
	
	return s_revive_override; // return the struct so it can be deregistered later
}

function deregister_revive_override( s_revive_override )
{
	if ( isdefined( self.a_s_revive_overrides ) )
	{
		ArrayRemoveValue( self.a_s_revive_overrides, s_revive_override );
	}
}

function can_revive_via_override( e_revivee ) // self == reviver player
{
	if ( isdefined( self.a_s_revive_overrides ) )
	{
		for ( i = 0; i < self.a_s_revive_overrides.size; i++ )
		{
			if ( self [[ self.a_s_revive_overrides[ i ].func_can_revive ]]( e_revivee ) )
			{
				return true;
			}
		}
	}
	
	return false;
}

function is_reviving_via_override( e_revivee ) // self == reviver player
{
	if ( isdefined( self.a_s_revive_overrides ) )
	{
		for ( i = 0; i < self.a_s_revive_overrides.size; i++ )
		{
			if ( self [[ self.a_s_revive_overrides[ i ].func_is_reviving ]]( e_revivee ) )
			{
				self.s_revive_override_used = self.a_s_revive_overrides[ i ];
				return true;
			}
		}
	}
	
	self.s_revive_override_used = undefined;
	return false;
}
