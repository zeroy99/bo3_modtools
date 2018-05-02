#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_lightning_chain;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weap_tesla;
#using scripts\zm\_zm_weapons;

#precache( "fx", "zombie/fx_tesla_rail_view_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view2_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view3_zmb" );
#precache( "fx", "zombie/fx_tesla_rail_view_ug_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view_ug_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view2_ug_zmb" );
#precache( "fx", "zombie/fx_tesla_tube_view3_ug_zmb" );

// T7 TODO
// Restore Removed GDT Entries
// Trail Effect: fx\_t6\maps\zombie\fx_zombie_tesla_electric_bolt.efx
// Trail Effect (upgraded tesla gun): fx\_t6\maps\zombie\fx_zombie_tesla_ug_elec_bolt.efx

function init()
{
	level.weaponZMTeslaGun = GetWeapon( "tesla_gun" );
	level.weaponZMTeslaGunUpgraded = GetWeapon( "tesla_gun_upgraded" );
	if ( !zm_weapons::is_weapon_included( level.weaponZMTeslaGun ) && !IS_TRUE( level.uses_tesla_powerup ) )
	{
		return;
	}

	level._effect["tesla_viewmodel_rail"]	= "zombie/fx_tesla_rail_view_zmb";
	level._effect["tesla_viewmodel_tube"]	= "zombie/fx_tesla_tube_view_zmb";
	level._effect["tesla_viewmodel_tube2"]	= "zombie/fx_tesla_tube_view2_zmb";
	level._effect["tesla_viewmodel_tube3"]	= "zombie/fx_tesla_tube_view3_zmb";
	level._effect["tesla_viewmodel_rail_upgraded"]	= "zombie/fx_tesla_rail_view_ug_zmb";
	level._effect["tesla_viewmodel_tube_upgraded"]	= "zombie/fx_tesla_tube_view_ug_zmb";
	level._effect["tesla_viewmodel_tube2_upgraded"]	= "zombie/fx_tesla_tube_view2_ug_zmb";
	level._effect["tesla_viewmodel_tube3_upgraded"]	= "zombie/fx_tesla_tube_view3_ug_zmb";

	level._effect["tesla_shock_eyes"]		= "zombie/fx_tesla_shock_eyes_zmb";
	
	zm::register_zombie_damage_override_callback( &tesla_zombie_damage_response );
	zm_spawner::register_zombie_death_animscript_callback( &tesla_zombie_death_response );
	
	zombie_utility::set_zombie_var( "tesla_max_arcs",			5 );
	zombie_utility::set_zombie_var( "tesla_max_enemies_killed", 10 );
	zombie_utility::set_zombie_var( "tesla_radius_start",		300 );
	zombie_utility::set_zombie_var( "tesla_radius_decay",		20 );
	zombie_utility::set_zombie_var( "tesla_head_gib_chance",	75 );
	zombie_utility::set_zombie_var( "tesla_arc_travel_time",	0.11, true );
	zombie_utility::set_zombie_var( "tesla_kills_for_powerup",	10 );
	zombie_utility::set_zombie_var( "tesla_min_fx_distance",	128 );
	zombie_utility::set_zombie_var( "tesla_network_death_choke",4 );
	
	level.tesla_lightning_params = lightning_chain::create_lightning_chain_params( 	level.zombie_vars["tesla_max_arcs"],
	                                                                              level.zombie_vars["tesla_max_enemies_killed"],
	                                                                              level.zombie_vars["tesla_radius_start"],
	                                                                              level.zombie_vars["tesla_radius_decay"],
	                                                                              level.zombie_vars["tesla_head_gib_chance"],
	                                                                              level.zombie_vars["tesla_arc_travel_time"],
	                                                                              level.zombie_vars["tesla_kills_for_powerup"],
	                                                                              level.zombie_vars["tesla_min_fx_distance"],
	                                                                              level.zombie_vars["tesla_network_death_choke"],
	                                                                              undefined,
	                                                                              undefined,
																				  "wpn_tesla_bounce" );

	
	callback::on_spawned( &on_player_spawned );
}


function tesla_damage_init( hit_location, hit_origin, player )
{
	player endon( "disconnect" );

	if ( IS_TRUE( player.tesla_firing ) )
	{
		zm_utility::debug_print( "TESLA: Player: '" + player.name + "' currently processing tesla damage" );
		return;
	}

	if( IsDefined( self.zombie_tesla_hit ) && self.zombie_tesla_hit )
	{
		// can happen if an enemy is marked for tesla death and player hits again with the tesla gun
		return;
	}

	zm_utility::debug_print( "TESLA: Player: '" + player.name + "' hit with the tesla gun" );

	//TO DO Add Tesla Kill Dialog thread....
	
	player.tesla_enemies = undefined;
	player.tesla_enemies_hit = 1;
	player.tesla_powerup_dropped = false;
	player.tesla_arc_count = 0;
	player.tesla_firing = 1;
	
	self lightning_chain::arc_damage( self, player, 1, level.tesla_lightning_params );
	
	if( player.tesla_enemies_hit >= 4)
	{
		player thread tesla_killstreak_sound();
	}

	player.tesla_enemies_hit = 0;
	player.tesla_firing = 0;
}

function is_tesla_damage( mod, weapon )
{
	return ( (weapon == level.weaponZMTeslaGun || weapon == level.weaponZMTeslaGunUpgraded ) && (mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" ));
}

function enemy_killed_by_tesla()
{
	return IS_TRUE( self.tesla_death );
}


function on_player_spawned()
{
	self thread tesla_sound_thread(); 
	self thread tesla_pvp_thread();
	self thread tesla_network_choke();
}


function tesla_sound_thread()
{
	self endon( "disconnect" );
			
	for( ;; )
	{
		result = self util::waittill_any_return( "grenade_fire", "death", "player_downed", "weapon_change", "grenade_pullback", "disconnect" );

		if ( !IsDefined( result ) )
		{
			continue;
		}

		if( ( result == "weapon_change" || result == "grenade_fire" ) && (self GetCurrentWeapon() == level.weaponZMTeslaGun || self GetCurrentWeapon() == level.weaponZMTeslaGunUpgraded) )
		{
			if(!IsDefined (self.tesla_loop_sound))
			{
				self.tesla_loop_sound = spawn("script_origin", self.origin);
				self.tesla_loop_sound linkto(self);
				self thread cleanup_loop_sound( self.tesla_loop_sound );
			}
			self.tesla_loop_sound PlayLoopSound( "wpn_tesla_idle", 0.25 );
			self thread tesla_engine_sweets();

		}
		else
		{
			self notify ("weap_away");
			if(IsDefined (self.tesla_loop_sound))
			{
				self.tesla_loop_sound StopLoopSound(0.25);
			}
		}
	}
}

function cleanup_loop_sound( loop_sound )
{
	self waittill( "disconnect" );
	if ( IsDefined(loop_sound) )
		loop_sound delete();
}


function tesla_engine_sweets()
{

	self endon( "disconnect" ); 
	self endon ("weap_away");
	while(1)
	{
		wait(randomintrange(7,15));
		self play_tesla_sound ("wpn_tesla_sweeps_idle");
	}
}

function tesla_pvp_thread()
{
	self endon( "disconnect" );
	self endon( "death" );

	for( ;; )
	{
		self waittill( "weapon_pvp_attack", attacker, weapon, damage, mod );

		if( self laststand::player_is_in_laststand() )
		{
			continue;
		}

		if ( weapon != level.weaponZMTeslaGun && weapon != level.weaponZMTeslaGunUpgraded )
		{
			continue;
		}

		if ( mod != "MOD_PROJECTILE" && mod != "MOD_PROJECTILE_SPLASH" )
		{
			continue;
		}

		if ( self == attacker )
		{
			damage = int( self.maxhealth * .25 );
			if ( damage < 25 )
			{
				damage = 25;
			}

			if ( self.health - damage < 1 )
			{
				self.health = 1;
			}
			else
			{
				self.health -= damage;
			}
		}

		self setelectrified( 1.0 );	
		self shellshock( "electrocution", 1.0 );
		self playsound( "wpn_tesla_bounce" );
	}
}
function play_tesla_sound(emotion)
{
	self endon( "disconnect" );

	if(!IsDefined (level.one_emo_at_a_time))
	{
		level.one_emo_at_a_time = 0;
		level.var_counter = 0;	
	}
	if(level.one_emo_at_a_time == 0)
	{
		level.var_counter ++;
		level.one_emo_at_a_time = 1;
		org = spawn("script_origin", self.origin);
		org LinkTo(self);
		org PlaySoundWithNotify (emotion, "sound_complete"+ "_"+level.var_counter);
		org waittill("sound_complete"+ "_"+level.var_counter);
		org delete();
		level.one_emo_at_a_time = 0;
	}		
}

function tesla_killstreak_sound()
{
	self endon( "disconnect" );

	//TUEY Play some dialog if you kick ass with the Tesla gun

	self zm_audio::create_and_play_dialog( "kill", "tesla" );	
	wait(3.5);
	level util::clientNotify("TGH");
}


function tesla_network_choke()
{
	self endon( "disconnect" );
	self endon( "death" );

	self.tesla_network_death_choke = 0;

	for ( ;; )
	{
		util::wait_network_frame();
		util::wait_network_frame();
		self.tesla_network_death_choke = 0;
	}
}

function tesla_zombie_death_response()
{
	if( self enemy_killed_by_tesla() )
	{
		return true;
	}
	
	return false;
}

//mod, hit_location, hit_origin, player, amount, weapon
function tesla_zombie_damage_response( willBeKilled, inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	if( self is_tesla_damage( meansofdeath, weapon ) )
	{
		self thread tesla_damage_init( sHitLoc, vpoint, attacker );
		return true;
	}
	return false;
}
