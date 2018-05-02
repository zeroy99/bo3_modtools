#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_lightning_chain.gsh;

#namespace lightning_chain;

REGISTER_SYSTEM( "lightning_chain", &init, undefined )


#define FX_LC_BOLT 				"zombie/fx_tesla_bolt_secondary_zmb"
#define FX_LC_SHOCK 			"zombie/fx_tesla_shock_zmb"
#define FX_LC_SHOCK_SECONDARY 	"zombie/fx_tesla_bolt_secondary_zmb"
#define FX_LC_SHOCK_EYES	 	"zombie/fx_tesla_shock_eyes_zmb"
#define FX_LC_SHOCK_NONFATAL	"zombie/fx_bmode_shock_os_zod_zmb"
	

#precache( "fx", FX_LC_BOLT 			);
#precache( "fx", FX_LC_SHOCK 			);
#precache( "fx", FX_LC_SHOCK_SECONDARY 	);
#precache( "fx", FX_LC_SHOCK_NONFATAL	);
#precache( "fx", FX_LC_SHOCK_EYES	 	);


function init()
{
	level._effect["tesla_bolt"]				= FX_LC_BOLT;
	level._effect["tesla_shock"]			= FX_LC_SHOCK;
	level._effect["tesla_shock_secondary"]	= FX_LC_SHOCK_SECONDARY;
	level._effect["tesla_shock_nonfatal"]	= FX_LC_SHOCK_NONFATAL;

	level._effect["tesla_shock_eyes"]		= FX_LC_SHOCK_EYES;
	
	level.default_lightning_chain_params = create_lightning_chain_params(); 
	
	clientfield::register( "actor", "lc_fx", VERSION_SHIP, 2, "int" );
	clientfield::register( "vehicle", "lc_fx", VERSION_SHIP, 2, "int" );
	
	clientfield::register( "actor", "lc_death_fx", VERSION_SHIP, 2, "int" );
	clientfield::register( "vehicle", "lc_death_fx", VERSION_TU10, 2, "int" );	// Leave at VERSION_TU10

	callback::on_connect( &on_player_connect );
}

function create_lightning_chain_params(
				max_arcs = 5,
				max_enemies_killed = 10,
				radius_start = 300,
				radius_decay = 20,
				head_gib_chance = 75,
				arc_travel_time = 0.11,
				kills_for_powerup = 10,
				min_fx_distance = 128,
				network_death_choke = 4,
				should_kill_enemies = true, 
				clientside_fx = true,
				arc_fx_sound = undefined, 
				no_fx = false,
				prevent_weapon_kill_credit = false
				)
{
	lcp = SpawnStruct(); 
	lcp.max_arcs = max_arcs;
	lcp.max_enemies_killed = max_enemies_killed;
	lcp.radius_start = radius_start;
	lcp.radius_decay = radius_decay;
	lcp.head_gib_chance = head_gib_chance;
	lcp.arc_travel_time = arc_travel_time;
	lcp.kills_for_powerup = kills_for_powerup;
	lcp.min_fx_distance = min_fx_distance;
	lcp.network_death_choke = network_death_choke;
	lcp.should_kill_enemies = should_kill_enemies;
	lcp.clientside_fx = clientside_fx;
	lcp.arc_fx_sound = arc_fx_sound;
	lcp.no_fx = no_fx;
	lcp.prevent_weapon_kill_credit = prevent_weapon_kill_credit;
	
	return lcp;
}

function private on_player_connect()
{	
	self endon( "disconnect" );
	self endon( "death" );
	self waittill( "spawned_player" ); 

	self.tesla_network_death_choke = 0;

	for ( ;; )
	{
		util::wait_network_frame( 2 );
		self.tesla_network_death_choke = 0;
	}
}

// this enemy is in the range of the source_enemy's tesla effect
function arc_damage( source_enemy, player, arc_num, params = level.default_lightning_chain_params )
{
	// DO NOT ADD ENDONS HERE - any endon in this routine is likely to result in zombies that are immune to lightning damage
	player endon( "disconnect" );

	DEFAULT( player.tesla_network_death_choke, 0 ); 
	DEFAULT( player.tesla_enemies_hit, 0 ); 
	
	zm_utility::debug_print( "TESLA: Evaulating arc damage for arc: " + arc_num + " Current enemies hit: " + player.tesla_enemies_hit );

	lc_flag_hit( self, true );

	radius_decay = params.radius_decay * arc_num;
	origin = self GetTagOrigin( "j_head" );
	if ( !IsDefined( origin ) )
	{
		origin = self.origin;
	}
	enemies = lc_get_enemies_in_area( origin, params.radius_start - radius_decay, player );
	
	util::wait_network_frame();
	
	lc_flag_hit( enemies, true );

	self thread lc_do_damage( source_enemy, arc_num, player, params );

	zm_utility::debug_print( "TESLA: " + enemies.size + " enemies hit during arc: " + arc_num );

	for( i = 0; i < enemies.size; i++ )
	{
		if( !isdefined(enemies[i]) || enemies[i] == self )
		{
			continue;
		}
		
		if ( lc_end_arc_damage( arc_num + 1, player.tesla_enemies_hit, params ) )
		{			
			lc_flag_hit( enemies[i], false );
			continue;
		}

		player.tesla_enemies_hit++;
		
		enemies[i] arc_damage( self, player, arc_num + 1, params );
	}
}

// self = enemy ent
function arc_damage_ent( player, arc_num, params = level.default_lightning_chain_params )
{
	lc_flag_hit( self, true );
	self thread lc_do_damage( self, arc_num, player, params );
}

function private lc_end_arc_damage( arc_num, enemies_hit_num, params )
{
	if ( arc_num >= params.max_arcs )
	{
		zm_utility::debug_print( "TESLA: Ending arcing. Max arcs hit" );
		return true;
		//TO DO Play Super Happy Tesla sound
	}

	if ( enemies_hit_num >= params.max_enemies_killed )
	{
		zm_utility::debug_print( "TESLA: Ending arcing. Max enemies killed" );		
		return true;
	}

	radius_decay = params.radius_decay * arc_num;
	if ( params.radius_start - radius_decay <= 0 )
	{
		zm_utility::debug_print( "TESLA: Ending arcing. Radius is less or equal to zero" );
		return true;
	}

	return false;
	//TO DO play Tesla Missed sound (sad)
}


function private lc_get_enemies_in_area( origin, distance, player )
{
	distance_squared = distance * distance;
	enemies = [];

	if ( !IsDefined( player.tesla_enemies ) )
	{
		player.tesla_enemies = zombie_utility::get_round_enemy_array();
		if( player.tesla_enemies.size>0 )
		{
			player.tesla_enemies = array::get_all_closest( origin, player.tesla_enemies );
		}
	}

	zombies = player.tesla_enemies; 

	if ( IsDefined( zombies ) )
	{
		for ( i = 0; i < zombies.size; i++ )
		{
			if ( !IsDefined( zombies[i] ) )
			{
				continue;
			}

			if ( IS_TRUE( zombies[i].lightning_chain_immune ) )
			{
				continue;
			}

			test_origin = zombies[i] GetTagOrigin( "j_head" );
			if ( !IsDefined( test_origin ) )
			{
				test_origin = zombies[i].origin;
			}

			if ( IsDefined( zombies[i].zombie_tesla_hit ) && zombies[i].zombie_tesla_hit == true )
			{
				continue;
			}

			if ( zm_utility::is_magic_bullet_shield_enabled( zombies[i] ) )
			{
				continue;
			}

			if ( DistanceSquared( origin, test_origin ) > distance_squared )
			{
				continue;
			}

			if ( !BulletTracePassed( origin, test_origin, false, undefined ) )
			{
				continue;
			}

			enemies[enemies.size] = zombies[i];
		}
	}

	return enemies;
}


function private lc_flag_hit( enemy, hit )
{
	if( IsDefined( enemy ) )
	{
		if( IsArray( enemy ) )
		{
			for( i = 0; i < enemy.size; i++ )
			{ 
				if ( IsDefined(enemy[i]) )
					enemy[i].zombie_tesla_hit = hit;
			}
		}
		else
		{
			if ( IsDefined(enemy) )
				enemy.zombie_tesla_hit = hit;
		}
	}
}


function private lc_do_damage( source_enemy, arc_num, player, params )
{
	player endon( "disconnect" );

	if ( arc_num > 1 )
	{
		wait( randomfloatrange( 0.2, 0.6 ) * arc_num );
	}

	if( !IsDefined( self ) || !IsAlive( self ) )
	{
		// guy died on us 
		return;
	}

	if ( params.clientside_fx )
	{
		if ( arc_num > 1 )
			clientfield::set( "lc_fx", 2 );
		else
			clientfield::set( "lc_fx", 1 );
	}
	
	if( !IsDefined( self ) || !IsAlive( self ) )
	{
		// guy died on us 
		return;
	}

	if( IsDefined( source_enemy ) && source_enemy != self )
	{
		if ( player.tesla_arc_count > 3 )
		{
			util::wait_network_frame();
			player.tesla_arc_count = 0;
		}
		
		player.tesla_arc_count++;
		source_enemy lc_play_arc_fx( self, params );
	}

	while ( player.tesla_network_death_choke > params.network_death_choke )
	{
		zm_utility::debug_print( "TESLA: Choking Tesla Damage. Dead enemies this network frame: " + player.tesla_network_death_choke );		
		WAIT_SERVER_FRAME; 
	}

	if( !IsDefined( self ) || !IsAlive( self ) )
	{
		// guy died on us 
		return;
	}

	player.tesla_network_death_choke++;
	
	self lc_play_death_fx( arc_num, params );

	self.tesla_death = params.should_kill_enemies;
	
	// use the origin of the arc orginator so it pics the correct death direction anim
	origin = player.origin;
	if ( IsDefined( source_enemy ) && source_enemy != self  )
	{
		origin = source_enemy.origin;
	}

	if( !IsDefined( self ) || !IsAlive( self ) )
	{
		// guy died on us 
		return;
	}
	if( params.should_kill_enemies )
	{
		if ( IsDefined( self.tesla_damage_func ) )
		{
			self [[ self.tesla_damage_func ]]( origin, player );
			return;
		}
		else if( IS_TRUE( params.prevent_weapon_kill_credit ) )
		{
			self DoDamage( self.health + 666, origin, player, undefined, "none", "MOD_UNKNOWN", 0, level.weaponNone );
		}		
		else	
		{
			weapon = level.weaponNone; 
			if ( isdefined(params.weapon) )
			{
				weapon = params.weapon; 
			}
			self DoDamage( self.health + 666, origin, player, undefined, "none", "MOD_UNKNOWN", 0, weapon );
		}
		if ( !IS_TRUE(self.deathpoints_already_given) && player zm_spawner::player_can_score_from_zombies() )
		{
			self.deathpoints_already_given = true;	
			player zm_score::player_add_points( "death", "", "" );
		}

		if ( IsDefined( params.challenge_stat_name ) && IsDefined( player ) && IsPlayer( player ) )
		{
			player zm_stats::increment_challenge_stat( params.challenge_stat_name );
		}
	}
// 	if ( !player.tesla_powerup_dropped && player.tesla_enemies_hit >= params.kills_for_powerup )
// 	{
// 		player.tesla_powerup_dropped = true;
// 		level.zombie_vars["zombie_drop_item"] = 1;
// 		level thread zm_powerups::powerup_drop( self.origin );
// 	}
}


function lc_play_death_fx( arc_num, params )
{
	tag = "J_SpineUpper";
	fx = "tesla_shock";
	n_fx = N_DEFAULT_SHOCK_EFFECT;
	
	b_can_clientside = true;

	if ( IS_TRUE(self.isdog)  )
	{
		tag = "J_Spine1";
	}
	
	if( isdefined(self.teslafxtag) )
	{
		b_can_clientside = false;
		tag = self.teslafxtag;
	}
	else if ( !IS_EQUAL(self.archetype,ARCHETYPE_ZOMBIE) )
	{
		tag = "tag_origin";
	}

	if ( arc_num > 1 )
	{
		fx = "tesla_shock_secondary";
		n_fx = N_SECONDARY_SHOCK_EFFECT;
	}

	if ( !params.should_kill_enemies )
	{
		fx = "tesla_shock_nonfatal";
		n_fx = N_NONFATAL_SHOCK_EFFECT;
	}
	
	if ( params.no_fx )
	{
	}
	else if ( params.clientside_fx && b_can_clientside )
	{
		clientfield::set( "lc_death_fx", n_fx );
	}
	else
	{
		zm_net::network_safe_play_fx_on_tag( "tesla_death_fx", 2, level._effect[fx], self, tag );
	}

	if ( IsDefined( self.tesla_head_gib_func ) && !self.head_gibbed && params.should_kill_enemies && !IS_TRUE(self.no_gib) )
	{
		[[ self.tesla_head_gib_func ]]();
	}
}


function lc_play_arc_fx( target, params )
{
	if ( !IsDefined( self ) || !IsDefined( target ) )
	{
		// TODO: can happen on dog exploding death
		wait( params.arc_travel_time );
		return;
	}
	
	tag = "J_SpineUpper";

	if ( IS_TRUE(self.isdog) )
	{
		tag = "J_Spine1";
	}
	else if ( !IS_EQUAL( self.archetype, ARCHETYPE_ZOMBIE ) )
	{
		tag = "tag_origin";
	}

	target_tag = "J_SpineUpper";

	if ( IS_TRUE(target.isdog) )
	{
		target_tag = "J_Spine1";
	}
	else if ( !IS_EQUAL( self.archetype, ARCHETYPE_ZOMBIE ) )
	{
		tag = "tag_origin";
	}
	
	origin = self GetTagOrigin( tag );
	target_origin = target GetTagOrigin( target_tag );
	distance_squared = params.min_fx_distance * params.min_fx_distance;

	if ( DistanceSquared( origin, target_origin ) < distance_squared )
	{
		zm_utility::debug_print( "TESLA: Not playing arcing FX. Enemies too close." );		
		return;
	}

	fxOrg = util::spawn_model( "tag_origin", origin );

	fx = PlayFxOnTag( level._effect["tesla_bolt"], fxOrg, "tag_origin" );
	if( isdefined( params.arc_fx_sound ) )
	{
		PlaySoundAtPosition( params.arc_fx_sound, fxOrg.origin );
	}
	
	fxOrg MoveTo( target_origin, params.arc_travel_time );
	fxOrg waittill( "movedone" );
	fxOrg delete();
}

function private lc_debug_arc( origin, distance )
{
}

