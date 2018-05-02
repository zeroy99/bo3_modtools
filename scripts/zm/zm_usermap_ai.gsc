#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;


//Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;

//Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;
#using scripts\zm\_zm_powerup_weapon_minigun;

// Weapons
#using scripts\zm\_zm_weap_bowie;
#using scripts\zm\_zm_weap_bouncingbetty;
#using scripts\zm\_zm_weap_cymbal_monkey;
#using scripts\zm\_zm_weap_tesla;

//Traps
#using scripts\zm\_zm_trap_electric;

// AI
#using scripts\shared\ai\zombie;
#using scripts\shared\ai\behavior_zombie_dog;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_ai_dogs;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\behavior_tree_utility;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;

#namespace zm_usermap_ai; 

//*****************************************************************************
//*****************************************************************************

function autoexec init()
{
	DEFAULT(level.pathdist_type,PATHDIST_ORIGINAL);
	
	// INIT BEHAVIORS
	InitZmFactoryBehaviorsAndASM();

	SetDvar( "scr_zm_use_code_enemy_selection", 0 );
	level.closest_player_override = &factory_closest_player;

	level thread update_closest_player();
	
	level.move_valid_poi_to_navmesh = true;
}

function private InitZmFactoryBehaviorsAndASM()
{
	// ------- SERVICES -----------//
	BT_REGISTER_API( "ZmFactoryTraversalService", &ZmFactoryTraversalService);
	
	BT_REGISTER_API( "shouldMoveLowg", &shouldMoveLowg );

	ASM_REGISTER_MOCOMP( "mocomp_idle_special_factory", &mocompIdleSpecialFactoryStart, undefined, &mocompIdleSpecialFactoryTerminate );
}

//*****************************************************************************
//*****************************************************************************

function ZmFactoryTraversalService( entity )
{
	if ( isdefined( entity.traverseStartNode ) )
	{
		entity PushActors( false );
		return true;
	}

	return false;
}	

function private mocompIdleSpecialFactoryStart( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	if( IsDefined( entity.enemyoverride ) && IsDefined( entity.enemyoverride[1] ) )
	{
		entity OrientMode( "face direction", entity.enemyoverride[1].origin - entity.origin );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
	else
	{
		entity OrientMode( "face current" );
		entity AnimMode( AI_ANIM_USE_BOTH_DELTAS_ZONLY_PHYSICS, false );
	}
}

function private mocompIdleSpecialFactoryTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	
}

function shouldMoveLowg( entity )
{
	return IS_TRUE( entity.low_gravity );
}

//*****************************************************************************
//*****************************************************************************

function private factory_validate_last_closest_player( players )
{
	if ( isdefined( self.last_closest_player ) && IS_TRUE( self.last_closest_player.am_i_valid ) )
	{
		return;
	}

	self.need_closest_player = true;

	foreach( player in players )
	{
		if ( IS_TRUE( player.am_i_valid ) )
		{
			self.last_closest_player = player;
			return;
		}
	}

	self.last_closest_player = undefined;
}

function private factory_closest_player( origin, players )
{
	if ( players.size == 0 )
	{
		return undefined;
	}

	if ( IsDefined( self.zombie_poi ) )
	{
		return undefined;
	}

	if ( players.size == 1 )
	{
		self.last_closest_player = players[0];
		return self.last_closest_player;
	}

	if ( !isdefined( self.last_closest_player ) )
	{
		self.last_closest_player = players[0];
	}

	if ( !isdefined( self.need_closest_player ) )
	{
		self.need_closest_player = true;
	}

	if ( isdefined( level.last_closest_time ) && level.last_closest_time >= level.time )
	{
		self factory_validate_last_closest_player( players );
		return self.last_closest_player;
	}

	if ( IS_TRUE( self.need_closest_player ) )
	{
		level.last_closest_time = level.time;

		self.need_closest_player = false;

		closest = players[0];
		closest_dist = self zm_utility::approximate_path_dist( closest );

		if ( !isdefined( closest_dist ) )
		{
			closest = undefined;
		}

		for ( index = 1; index < players.size; index++ )
		{
			dist = self zm_utility::approximate_path_dist( players[ index ] );
			if ( isdefined( dist ) )
			{
				if ( isdefined( closest_dist ) )
				{
					if ( dist < closest_dist )
					{
						closest = players[ index ];
						closest_dist = dist;
					}
				}
				else
				{
					closest = players[ index ];
					closest_dist = dist;
				}
			}
		}

		self.last_closest_player = closest;
	}

	if ( players.size > 1 && isdefined( closest ) )
	{
		self zm_utility::approximate_path_dist( closest );
	}
		
	self factory_validate_last_closest_player( players );
	return self.last_closest_player;
}

function private update_closest_player()
{
	level waittill( "start_of_round" );

	while ( 1 )
	{
		reset_closest_player = true;
		zombies = zombie_utility::get_round_enemy_array();
		foreach( zombie in zombies )
		{
			if ( IS_TRUE( zombie.need_closest_player ) )
			{
				reset_closest_player = false;
				break;
			}
		}

		if ( reset_closest_player )
		{
			foreach( zombie in zombies )
			{
				if ( isdefined( zombie.need_closest_player ) )
				{
					zombie.need_closest_player = true;
				}
			}
		}

		WAIT_SERVER_FRAME;
	}
}















