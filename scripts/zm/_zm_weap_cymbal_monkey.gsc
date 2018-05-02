#using scripts\codescripts\struct;

#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_clone;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#precache( "fx", "zombie/fx_cymbal_monkey_light_zmb" );
#precache( "fx", "zombie/fx_monkey_lightning_zmb" );
#precache( "fx", "dlc3/stalingrad/fx_cymbal_monkey_radial_pulse" );

#using_animtree( "zombie_cymbal_monkey" );

#define VALID_POI_MAX_RADIUS			200
#define VALID_POI_HALF_HEIGHT			100
#define VALID_POI_INNER_SPACING			2
#define VALID_POI_RADIUS_FROM_EDGES		15
#define VALID_POI_HEIGHT				36

#define N_MONKEY_PULSE_RADIUS			 128
#define N_MONKEY_PULSE_DAMAGE_MAX		1000
#define N_MONKEY_PULSE_DAMAGE_MIN		 500


function init()
{
	level.weaponZMCymbalMonkey = GetWeapon( "cymbal_monkey" );
	zm_weapons::register_zombie_weapon_callback( level.weaponZMCymbalMonkey, &player_give_cymbal_monkey );

	if( !cymbal_monkey_exists( level.weaponZMCymbalMonkey ) )
	{
		return;
	}

	level.w_cymbal_monkey_upgraded = GetWeapon( "cymbal_monkey_upgraded" );
	if( cymbal_monkey_exists( level.w_cymbal_monkey_upgraded) )
	{
		zm_weapons::register_zombie_weapon_callback( level.w_cymbal_monkey_upgraded, &player_give_cymbal_monkey_upgraded );
		level._effect["monkey_bass"] 	= "dlc3/stalingrad/fx_cymbal_monkey_radial_pulse";
	}

	if (IS_TRUE(level.legacy_cymbal_monkey))
	{
		level.cymbal_monkey_model = "weapon_zombie_monkey_bomb";
	}
	else
	{
		level.cymbal_monkey_model =  "wpn_t7_zmb_monkey_bomb_world";
	}
		
	level._effect["monkey_glow"] 	= "zombie/fx_cymbal_monkey_light_zmb";
	level._effect["grenade_samantha_steal"] 	= "zombie/fx_monkey_lightning_zmb";

	level.cymbal_monkeys = [];

	if ( !IsDefined( level.valid_poi_max_radius ) )
	{
		level.valid_poi_max_radius = VALID_POI_MAX_RADIUS;
	}

	if ( !IsDefined( level.valid_poi_half_height ) )
	{
		level.valid_poi_half_height = VALID_POI_HALF_HEIGHT;
	}

	if ( !IsDefined( level.valid_poi_inner_spacing ) )
	{
		level.valid_poi_inner_spacing = VALID_POI_INNER_SPACING;
	}

	if ( !IsDefined( level.valid_poi_radius_from_edges ) )
	{
		level.valid_poi_radius_from_edges = VALID_POI_RADIUS_FROM_EDGES;
	}

	if ( !IsDefined( level.valid_poi_height ) )
	{
		level.valid_poi_height = VALID_POI_HEIGHT;
	}
}

function player_give_cymbal_monkey()
{
	self giveweapon( level.weaponZMCymbalMonkey );
	self zm_utility::set_player_tactical_grenade( level.weaponZMCymbalMonkey );
	self thread player_handle_cymbal_monkey();
}

function player_give_cymbal_monkey_upgraded()
{
 // end any existing loop that gives infinite tactical ammo, or it will override the new weapon
		
	if ( isdefined( self zm_utility::get_player_tactical_grenade() ) )
	{
		self TakeWeapon( self zm_utility::get_player_tactical_grenade() ); // PORTIZ: was not correctly replacing the regular monkeys until they were manually taken
	}
		
	self giveweapon( level.w_cymbal_monkey_upgraded );
	self zm_utility::set_player_tactical_grenade( level.w_cymbal_monkey_upgraded );
	self thread player_handle_cymbal_monkey();
}


function player_handle_cymbal_monkey()
{
	self notify( "starting_monkey_watch" );
	self endon( "disconnect" );
	self endon( "starting_monkey_watch" );
	
	// Min distance to attract positions
	attract_dist_diff = level.monkey_attract_dist_diff;
	if( !isDefined( attract_dist_diff ) )
	{
		attract_dist_diff = 45;
	}
		
	num_attractors = level.num_monkey_attractors;
	if( !isDefined( num_attractors ) )
	{
		num_attractors = 96;
	}
	
	max_attract_dist = level.monkey_attract_dist;
	if( !isDefined( max_attract_dist ) )
	{
		max_attract_dist = 1536;
	}
	
	while( true )
	{
		grenade = get_thrown_monkey();
		self player_throw_cymbal_monkey(grenade,num_attractors,max_attract_dist,attract_dist_diff);
		WAIT_SERVER_FRAME;
	}
}

function watch_for_dud(model,actor)
{
	self endon("death");
	self waittill("grenade_dud");
	model.dud = 1;
	self playsound( "zmb_vox_monkey_scream" );
	self.monk_scream_vox = true;
	wait 3;
	if(isdefined(model))
		model delete();
	if(isdefined(actor))
		actor delete();
	if (isdefined(self.damagearea))
		self.damagearea delete();
	if(isdefined(self))
		self delete();
}

function watch_for_emp(model,actor)
{
	self endon("death");
	if (!zm_utility::should_watch_for_emp())
		return;
	while (1)
	{
		level waittill("emp_detonate",origin,radius);
		if ( DistanceSquared( origin, self.origin) < radius * radius )
		{
			break;
		}
	}
	self.stun_fx = true;
	if (isdefined(level._equipment_emp_destroy_fx))
	{
		PlayFX( level._equipment_emp_destroy_fx, self.origin + ( 0, 0, 5 ) , ( 0, RandomFloat( 360 ), 0 ) );
	}
	wait 0.15;
	self.attract_to_origin = false;
	self zm_utility::deactivate_zombie_point_of_interest();
	model ClearAnim( %o_monkey_bomb, 0 );
	wait 1;
	self Detonate();	
	wait 1;
	if(isdefined(model))
		model delete();
	if(isdefined(actor))
		actor delete();
	if (isdefined(self.damagearea))
		self.damagearea delete();
	if(isdefined(self))
		self delete();
}


function clone_player_angles(owner)
{
	self endon( "death" );
	owner endon( "death" );
	while (isdefined(self))
	{
		self.angles = owner.angles;
		WAIT_SERVER_FRAME;
	}
}


function show_briefly( showtime )
{
	self endon("show_owner");
	if (isdefined(self.show_for_time))
	{
		self.show_for_time = showtime;
		return;
	}
	self.show_for_time = showtime;
	self SetVisibleToAll();
	while ( self.show_for_time > 0 )
	{
		self.show_for_time -= 0.05;
		WAIT_SERVER_FRAME;
	}
	self SetVisibleToAllExceptTeam( level.zombie_team );
	self.show_for_time = undefined;
}


function show_owner_on_attack( owner )
{
	owner endon("hide_owner");
	owner endon("show_owner");
	self endon( "explode" );
	self endon( "death" );
	self endon( "grenade_dud" );
	
	owner.show_for_time = undefined;
	
	for( ;; )
	{
		owner waittill( "weapon_fired" );
		owner thread show_briefly(0.5);
	}
}


function hide_owner( owner )
{
	owner notify("hide_owner");
	owner endon("hide_owner");

	owner SetPerk("specialty_immunemms");
	owner.no_burning_sfx = true;	
	owner notify( "stop_flame_sounds" );
	owner SetVisibleToAllExceptTeam( level.zombie_team );

	owner.hide_owner = true;

	if (isdefined(level._effect[ "human_disappears" ]))
		PlayFX( level._effect[ "human_disappears" ], owner.origin );

	self thread show_owner_on_attack( owner );
	
	evt = self util::waittill_any_ex( "explode", "death", "grenade_dud", owner, "hide_owner" );


	owner notify("show_owner");
	
	owner UnsetPerk("specialty_immunemms");
	if (isdefined(level._effect[ "human_disappears" ]))
		PlayFX( level._effect[ "human_disappears" ], owner.origin );
	owner.no_burning_sfx = undefined;
	owner SetVisibleToAll();

	owner.hide_owner = undefined;

	owner Show();
}

#define	PLAYER_RADIUS			15.0

function proximity_detonate( owner )
{
	//self endon("death");
	wait 1.5; // so it can't be used as a simple proximity grenade
	if ( !isdefined(self) )
		return;
	
	detonateRadius = 96;
	explosionRadius = detonateRadius * 2;
	
	damagearea = spawn( "trigger_radius", self.origin + (0,0,0 - detonateRadius), SPAWNFLAG_TRIGGER_AI_NEUTRAL, detonateRadius, detonateRadius * 1.5 );
	
	damagearea SetExcludeTeamForTrigger( owner.team );

	damagearea enablelinkto();
	damagearea linkto( self );

	self.damagearea = damagearea;

	while ( isdefined(self) )
	{
		damagearea waittill( "trigger", ent );
		
		if ( isdefined( owner ) && ent == owner )
			continue;

		if( isDefined( ent.team ) && ent.team == owner.team )
			continue;
		
		self playsound ("wpn_claymore_alert");
		
		dist = Distance( self.origin, ent.origin );
		
		RadiusDamage(self.origin + (0,0,12),explosionRadius,1,1,owner,"MOD_GRENADE_SPLASH",level.weaponZMCymbalMonkey);

		if ( isdefined( owner ) )
			self detonate( owner );
		else
			self detonate( undefined );
		
		break;		
	}
	
	if (isdefined(damagearea))
		damagearea delete();
}

// hack because grenades can't linkto 
function FakeLinkto(linkee)
{
	self notify("fakelinkto");
	self endon("fakelinkto");
	self.backlinked = 1;
	while (isdefined(self) && isdefined(linkee))
	{
		self.origin = linkee.origin;
		self.angles = linkee.angles;
		wait 0.05;
	}
}


function player_throw_cymbal_monkey(grenade,num_attractors,max_attract_dist,attract_dist_diff)
{
	self endon( "disconnect" );
	self endon( "starting_monkey_watch" );
	
	if( IsDefined( grenade ) )
	{
		grenade endon( "death" );
		
		if( self laststand::player_is_in_laststand() )
		{
			if (isdefined(grenade.damagearea))
				grenade.damagearea delete();
			grenade delete();
			return;
		}
		grenade hide();
		model = spawn( "script_model", grenade.origin );
		model SetModel( level.cymbal_monkey_model );
		model UseAnimTree( #animtree );
		model linkTo( grenade );
		model.angles = grenade.angles;
		model thread monkey_cleanup( grenade );

		clone = undefined;
		
		if (IS_TRUE(level.cymbal_monkey_dual_view))
		{
			model SetVisibleToAllExceptTeam( level.zombie_team );

			// level.cymbal_monkey_clone_weapon may be undefined
			clone = zm_clone::spawn_player_clone( self, (0,0,-999), level.cymbal_monkey_clone_weapon, undefined );
			model.simulacrum = clone;
			clone zm_clone::clone_animate( "idle" );
			clone thread clone_player_angles( self );
			clone notsolid();
			clone ghost();
		}
		
		grenade thread watch_for_dud(model,clone);
		grenade thread watch_for_emp(model,clone);

		info = spawnStruct();
		info.sound_attractors = [];
		//grenade thread monitor_zombie_groans( info );
		
		grenade waittill("stationary");
		
		if ( IsDefined(level.grenade_planted) )
		{
			self thread [[level.grenade_planted]](grenade,model);
		}
		
		if( isDefined( grenade ) )
		{
			grenade.ground_ent = grenade GetGroundEnt();
			
			if (isdefined(model))
			{
				if ( isdefined(grenade.ground_ent) && !( grenade.ground_ent.classname === "worldspawn" ) )
				{
					model SetMovingPlatformEnabled( true );
					model LinkTo( grenade.ground_ent );
					grenade thread FakeLinkto(model);
				}
				else if (!IS_TRUE(grenade.backlinked))
				{
					model unlink();
					model.origin = grenade.origin;
					model.angles = grenade.angles;
				}
				//temp wait until we figure out why animscripted cannot be called right after unlink over here
				wait 0.1;
				model AnimScripted( "cymbal_monkey_anim", grenade.origin, grenade.angles, %o_monkey_bomb );
			}
			if (isdefined(clone))
			{
				clone ForceTeleport( grenade.origin, grenade.angles );
				clone thread hide_owner( self );
				grenade thread proximity_detonate( self );
				clone show();
				clone SetInvisibleToAll();
				clone SetVisibleToTeam(level.zombie_team);
			}
			
			grenade resetmissiledetonationtime();
			PlayFxOnTag( level._effect["monkey_glow"], model, "tag_origin_animate" );
			
			valid_poi = zm_utility::check_point_in_enabled_zone( grenade.origin, undefined, undefined );

			if ( IS_TRUE( level.move_valid_poi_to_navmesh ) )
			{
				valid_poi = grenade move_valid_poi_to_navmesh( valid_poi );
			}

			if ( isdefined( level.check_valid_poi ) )
			{
				valid_poi = grenade [[ level.check_valid_poi ]]( valid_poi );
			}
		
			if(valid_poi)
			{
				grenade zm_utility::create_zombie_point_of_interest( max_attract_dist, num_attractors, 10000 );
				grenade.attract_to_origin = true;

				grenade thread zm_utility::create_zombie_point_of_interest_attractor_positions( 4, attract_dist_diff );
				grenade thread zm_utility::wait_for_attractor_positions_complete();
			
				if ( grenade.weapon == level.w_cymbal_monkey_upgraded )
				{
					grenade thread pulse_damage( self, model );
				}
				grenade thread do_monkey_sound( model, info );

				level.cymbal_monkeys[ level.cymbal_monkeys.size ] = grenade;
			}
			else
			{
				grenade.script_noteworthy = undefined;
				level thread grenade_stolen_by_sam( grenade, model, clone );
			}
		}
		else
		{
			grenade.script_noteworthy = undefined;
			level thread grenade_stolen_by_sam( grenade, model, clone );
		}
	}
}

function move_valid_poi_to_navmesh( valid_poi )
{
	if ( !IS_TRUE( valid_poi ) )
	{
		return false;
	}

	if ( IsPointOnNavMesh( self.origin ) )
	{
		return true;
	}

	v_orig = self.origin;
	queryResult = PositionQuery_Source_Navigation(
					self.origin,		// origin
					0,					// min radius
					level.valid_poi_max_radius,				// max radius
					level.valid_poi_half_height,				// half height
					level.valid_poi_inner_spacing,					// inner spacing
					level.valid_poi_radius_from_edges					// radius from edges
				);
					
	if ( queryResult.data.size )
	{
		foreach ( point in queryResult.data )
		{
			height_offset = abs( self.origin[2] - point.origin[2] );
			if ( height_offset > level.valid_poi_height )
			{
				continue;
			}

			if ( BulletTracePassed( point.origin + ( 0, 0, 20 ), v_orig + ( 0, 0, 20 ), false, self, undefined, false, false ) )
			{
				self.origin = point.origin;
				return true;
			}
		}
	}

	return false;
}

// if the player throws it to an unplayable area samantha steals it
function grenade_stolen_by_sam( ent_grenade, ent_model, ent_actor )
{
	if( !IsDefined( ent_model ) )
	{
		return;
	}
	
	//ent_grenade notify( "sam_stole_it" );
	
	direction = ent_model.origin;
	direction = (direction[1], direction[0], 0);
 
	if(direction[1] < 0 || (direction[0] > 0 && direction[1] > 0))
	{
		direction = (direction[0], direction[1] * -1, 0);
	}
	else if(direction[0] < 0)
	{
		direction = (direction[0] * -1, direction[1], 0);
	}
	
	// Play laugh sound here, players should connect the laugh with the movement which will tell the story of who is moving it
	players = GetPlayers();
	for( i = 0; i < players.size; i++ )
	{
		if( IsAlive( players[i] ) )
		{
			players[i] playlocalsound( level.zmb_laugh_alias );
		}
	}
	
	// play the fx on the model
	PlayFXOnTag( level._effect[ "grenade_samantha_steal" ], ent_model, "tag_origin" );

	ent_model StopAnimScripted();
	
	// raise the model
	ent_model MoveZ( 60, 1.0, 0.25, 0.25 );

	// spin it
	ent_model Vibrate( direction, 1.5,  2.5, 1.0 );
	ent_model waittill( "movedone" );
	
	if (isdefined(self.damagearea))
		self.damagearea delete();
	
	// delete it
	ent_model Delete();
	
	if(isDefined(ent_actor))
	{
		ent_actor Delete();
	}
	
	if ( isdefined( ent_grenade ) )
	{
		if (isdefined(ent_grenade.damagearea))
			ent_grenade.damagearea delete();
		ent_grenade Delete();
	}
}

function monkey_cleanup( parent )
{
	while( true )
	{
		if( !isDefined( parent ) )
		{
			if (isdefined(self) && IS_TRUE(self.dud)) // wait for the screams to die out
				wait 6;
			if (isdefined(self.simulacrum))
				self.simulacrum delete();
			zm_utility::self_delete();
			return;
		}
		WAIT_SERVER_FRAME;
	}
}


function pulse_damage( e_owner, model )
{
	self endon( "explode" );
	
	util::wait_network_frame();		// space out from monkey_glow FX play
	PlayFxOnTag( level._effect["monkey_bass"], model, "tag_origin_animate" );
	
	n_damage_origin = self.origin + ( 0, 0, 12 );
	
	while ( true )
	{
		a_ai_targets = GetAITeamArray( "axis" );
		
		foreach( ai_target in a_ai_targets )
		{
			if ( isdefined( ai_target ) ) 
			{
				n_distance_to_target = Distance( ai_target.origin, n_damage_origin );
				
				if ( n_distance_to_target > N_MONKEY_PULSE_RADIUS )
				{
					continue;
				}
				
				n_damage = math::linear_map( n_distance_to_target, 0, N_MONKEY_PULSE_RADIUS, N_MONKEY_PULSE_DAMAGE_MIN, N_MONKEY_PULSE_DAMAGE_MAX );
				
				ai_target DoDamage( n_damage, ai_target.origin, e_owner, self, "none", "MOD_GRENADE_SPLASH", 0, level.w_cymbal_monkey_upgraded );
			}
		}
		
		wait 1.0;
	}
}


function do_monkey_sound( model, info )
{
	self.monk_scream_vox = false;
	
	if (isdefined(level.grenade_safe_to_bounce))
	{
		if (![[level.grenade_safe_to_bounce]](self.owner,level.weaponZMCymbalMonkey))
		{
			self playsound( "zmb_vox_monkey_scream" );
			self.monk_scream_vox = true;
		}
	}
	
	if (isdefined(level.monkey_song_override))
	{
		if ([[level.monkey_song_override]](self.owner,level.weaponZMCymbalMonkey))
		{
			self playsound( "zmb_vox_monkey_scream" );
			self.monk_scream_vox = true;
		}
	}

/*	
	if( isdefined( level.lava ) )
	{
		for ( i=0; i<level.lava.size; i++ )
		{
			if ( self IsTouching(level.lava[i]) )
			{
				self playsound( "zmb_vox_monkey_scream" );
				monk_scream_vox = true;
				break;
			}
		}
	}
*/	
	
	if( !self.monk_scream_vox && level.musicSystem.currentPlaytype < 4 )
	{
		if (IS_TRUE(level.cymbal_monkey_dual_view))
			self playsoundtoteam( "zmb_monkey_song", "allies" );
		else if( self.weapon.name == "cymbal_monkey_upgraded" ) 
			self playsound( "zmb_monkey_song_upgraded" );
		else
			self playsound( "zmb_monkey_song" );
	}
	
	if( !self.monk_scream_vox )
		self thread play_delayed_explode_vox();

	self waittill( "explode", position );
	level notify("grenade_exploded",position,100,5000,450);

	monkey_index = -1;
	for ( i = 0; i < level.cymbal_monkeys.size; i++ )
	{
		if ( !isdefined( level.cymbal_monkeys[i] ) )
		{
			monkey_index = i;
			break;
		}
	}
	if ( monkey_index >= 0 )
	{
		ArrayRemoveIndex( level.cymbal_monkeys, monkey_index );
	}
	
	if( isDefined( model ) )
	{
		model ClearAnim( %o_monkey_bomb, 0.2 );
	}
	
	for( i = 0; i < info.sound_attractors.size; i++ )
	{
		if( isDefined( info.sound_attractors[i] ) )
		{
			info.sound_attractors[i] notify( "monkey_blown_up" );
		}
	}
}

function play_delayed_explode_vox()
{
	wait(6.5);
	if(isdefined( self ) )
	{
		if( self.weapon.name == "cymbal_monkey_upgraded" )
		{
			self playsound( "zmb_vox_monkey_explode_upgraded" );
		}
		else
		{
			self playsound( "zmb_vox_monkey_explode" );
		}
	}
}

function get_thrown_monkey()
{
	self endon( "disconnect" );
	self endon( "starting_monkey_watch" );
	
	while( true ) 
	{
		self waittill( "grenade_fire", grenade, weapon );
		if( weapon == level.weaponZMCymbalMonkey || weapon == level.w_cymbal_monkey_upgraded )
			{
			grenade.use_grenade_special_long_bookmark = true;
			grenade.grenade_multiattack_bookmark_count = 1;
			grenade.weapon = weapon;
			return grenade;
		}
		
		WAIT_SERVER_FRAME;
	}
}

function monitor_zombie_groans( info )
{
	self endon( "explode" );
            
	while( true ) 
	{
		if( !isDefined( self ) )
		{
			return;
		}
		
		if( !isDefined( self.attractor_array ) )
		{
			WAIT_SERVER_FRAME;
			continue;
		}
		
		for( i = 0; i < self.attractor_array.size; i++ )
		{
			if( !IsInArray( info.sound_attractors, self.attractor_array[i] ) )
			{
				if ( isDefined( self.origin ) && isDefined( self.attractor_array[i].origin ) )
				{
					if( distanceSquared( self.origin, self.attractor_array[i].origin ) < 500 * 500 )
					{
						ARRAY_ADD( info.sound_attractors, self.attractor_array[i] );
						self.attractor_array[i] thread play_zombie_groans();
					}
				}
			}
		}
		WAIT_SERVER_FRAME;
	}
} 

function play_zombie_groans()
{
	self endon( "death" );
	self endon( "monkey_blown_up" );
            
	while(1)
	{
		if( isdefined ( self ) )
		{
			self playsound( "zmb_vox_zombie_groan" );
			wait randomfloatrange( 2, 3 );
		}
		else
		{
			return;
		}
	}
}

function cymbal_monkey_exists( w_weapon )
{
	return zm_weapons::is_weapon_included( w_weapon );
}

