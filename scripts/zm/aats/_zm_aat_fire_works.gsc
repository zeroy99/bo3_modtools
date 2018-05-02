#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\zm\_zm_spawner;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\aats\_zm_aat_fire_works.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "material", ZM_AAT_FIRE_WORKS_DAMAGE_FEEDBACK_ICON );

#namespace zm_aat_fire_works;

REGISTER_SYSTEM( ZM_AAT_FIRE_WORKS_NAME, &__init__, "aat" )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_FIRE_WORKS_NAME, ZM_AAT_FIRE_WORKS_PERCENTAGE, ZM_AAT_FIRE_WORKS_COOLDOWN_ENTITY, ZM_AAT_FIRE_WORKS_COOLDOWN_ATTACKER, ZM_AAT_FIRE_WORKS_COOLDOWN_GLOBAL,
	               ZM_AAT_FIRE_WORKS_OCCURS_ON_DEATH, &result, ZM_AAT_FIRE_WORKS_DAMAGE_FEEDBACK_ICON, ZM_AAT_FIRE_WORKS_DAMAGE_FEEDBACK_SOUND, &fire_works_zombie_validation );

	clientfield::register( "scriptmover", ZM_AAT_FIRE_WORKS_NAME, VERSION_SHIP, 1, "int" );
	
	zm_spawner::register_zombie_damage_callback( &zm_aat_fire_works_zombie_damage_response );
	zm_spawner::register_zombie_death_event_callback( &zm_aat_fire_works_death_callback );
}

function result( death, attacker, mod, weapon )
{	
	self fire_works_summon( attacker, weapon );
}

// Checks to see if fire works is running
// self == zombie
function fire_works_zombie_validation()
{
	if( IS_TRUE( self.barricade_enter ) )
	{
		return false;
	}
	
	if ( IS_TRUE( self.is_traversing ) )
	{
		return false;
	}

	if( !IS_TRUE( self.completed_emerging_into_playable_area ) && !IsDefined( self.first_node ) )
	{
		return false;
	}

	if ( IS_TRUE( self.is_leaping ) )
	{
		return false;
	}
	
	return true;
}

// Summons the player's current gun to pop up and fire in a circle for a period of time
// immune_result_direct == target is immune to death gib
// immune_result_indirect == target is immune to death gib on hit from the magic bullet
// self == target zombie
function fire_works_summon( e_player, w_weapon )
{
	w_summoned_weapon = e_player GetCurrentWeapon();
	v_target_zombie_origin = self.origin;
	
	// Checks if self is immune_result_direct == true. If so, do not kill self
	if ( !IS_TRUE( level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_direct[ self.archetype ] ) )
	{
		self thread zombie_death_gib( e_player, w_weapon, e_player );
	}

	// Spawns base model
	v_firing_pos = v_target_zombie_origin + ZM_AAT_FIRE_WORKS_ZOMBIE_GUN_HEIGHT;
	v_start_yaw = VectorToAngles( v_firing_pos - v_target_zombie_origin );
	v_start_yaw = (0, v_start_yaw[1], 0);
	mdl_weapon = zm_utility::spawn_weapon_model( w_summoned_weapon, undefined, v_target_zombie_origin, v_start_yaw );

	// Stat tracking definitions
	mdl_weapon.owner = e_player;
	mdl_weapon.b_aat_fire_works_weapon = true;
	mdl_weapon.allow_zombie_to_target_ai = true; // lets the zombie damage callbacks pass through damage from this
	
	// Fires FX
	mdl_weapon thread clientfield::set( ZM_AAT_FIRE_WORKS_NAME, 1 );
	
	// Moves weapon upwards to firing position
	mdl_weapon MoveTo( v_firing_pos, ZM_AAT_FIRE_WORKS_SUMMON_TIME );
	mdl_weapon waittill( "movedone" );

	// Starts firing
	for ( i = 0; i < ZM_AAT_FIRE_WORKS_FIRING_NUM_FRAMES; i++ )
	{
		zombie = mdl_weapon zm_aat_fire_works_get_target();
		if ( !IsDefined( zombie ) )
		{
			//if no target available, just pick a random yaw
			v_curr_yaw = (0, RandomIntRange( 0, 360 ), 0);
			v_target_pos = mdl_weapon.origin + VectorScale( AnglesToForward( v_curr_yaw ), 40 );
		}
		else
		{
			v_target_pos = zombie GetCentroid();
		}

		mdl_weapon.angles = VectorToAngles( v_target_pos - mdl_weapon.origin );
		v_flash_pos = mdl_weapon GetTagOrigin( "tag_flash" );
		mdl_weapon DontInterpolate();

		// MagicBullet shots are credited to the model rather than player, as MagicBullet causes recoil on player
		MagicBullet( w_summoned_weapon, v_flash_pos, v_target_pos, mdl_weapon );

		util::wait_network_frame();
	}

	mdl_weapon MoveTo( v_target_zombie_origin, ZM_AAT_FIRE_WORKS_SUMMON_TIME );
	mdl_weapon waittill( "movedone" );
	
	mdl_weapon clientfield::set( ZM_AAT_FIRE_WORKS_NAME, 0 );
	
	util::wait_network_frame(); // Waits for FX to complete
	util::wait_network_frame(); // extra waits for theater playback
	util::wait_network_frame(); // extra waits for theater playback
	
	mdl_weapon Delete();
	wait .25; // Delay for final projectile-based gun shots to finish firing
}

// Death callback for zombies killed by summoned Fire Works weapon
function zm_aat_fire_works_get_target()
{
	a_ai_zombies = array::randomize( GetAiTeamArray( "axis" ) );

	los_checks = 0;
	for ( i = 0; i < a_ai_zombies.size; i++ )
	{
		zombie = a_ai_zombies[i];
		test_origin = zombie getcentroid();
		if ( DistanceSquared( self.origin, test_origin ) > ZM_AAT_FIRE_WORKS_RANGE_SQ )
		{
			continue;
		}

		if ( los_checks < ZM_AAT_FIRE_WORKS_MAX_LOS_CHECKS && !zombie DamageConeTrace( self.origin ) )
		{
			los_checks++;
			continue;
		}

		return zombie;
	}

	if ( a_ai_zombies.size )
	{
		// just return the first one, so that we at least change direction
		return a_ai_zombies[0];
	}

	return undefined;
}

// self is a zombie
function zm_aat_fire_works_zombie_damage_response( str_mod, str_hit_location, v_hit_origin, e_attacker, n_amount, w_weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	if ( IS_TRUE( level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_indirect[ self.archetype ] ) )
	{
		return false;
	}

	if ( IS_TRUE( e_attacker.b_aat_fire_works_weapon ) )
	{
		self thread zombie_death_gib( e_attacker, w_weapon, e_attacker.owner );
		return true;
	}

	return false;
}

// Death callback for zombies killed by summoned Fire Works weapon
function zm_aat_fire_works_death_callback( attacker )
{
	if ( isdefined( attacker ) )
	{
		if ( IS_TRUE( attacker.b_aat_fire_works_weapon ) )
		{
			// Checks if player has disconnected
			if ( isdefined( attacker.owner ) )
			{
				e_attacking_player = attacker.owner;
				// TODO set up stat tracking
			}
		}
	}
}

// Gibs and Kills zombie
// self == affected zombie
// e_attacker == the script_model of the gun (needs to do the damage, so the player doesn't receive kickback)
// w_weapon == the weapon to apply damage using
// e_owner == the owner of the gun (for awarding challenge stat progress)
function zombie_death_gib( e_attacker, w_weapon, e_owner )
{
	gibserverutils::gibhead( self );
	
	if ( math::cointoss() )
	{
		gibserverutils::gibleftarm( self );
	}
	else
	{
		gibserverutils::gibrightarm( self );
	}
	
	gibserverutils::giblegs( self );
	
	self DoDamage( self.health, self.origin, e_attacker, w_weapon, "torso_upper" );

	if ( IsDefined( e_owner ) && IsPlayer( e_owner ) )
	{
		e_owner zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_FIRE_WORKS" );
	}
}
