#using scripts\codescripts\struct;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\gib;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\aats\_zm_aat_thunder_wall.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "material", ZM_AAT_THUNDER_WALL_DAMAGE_FEEDBACK_ICON );
#precache( "fx", ZM_AAT_THUNDER_WALL_BREAK_FX );

#namespace zm_aat_thunder_wall;

REGISTER_SYSTEM( ZM_AAT_THUNDER_WALL_NAME, &__init__, "aat" )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_THUNDER_WALL_NAME, ZM_AAT_THUNDER_WALL_PERCENTAGE, ZM_AAT_THUNDER_WALL_COOLDOWN_ENTITY, ZM_AAT_THUNDER_WALL_COOLDOWN_ATTACKER, ZM_AAT_THUNDER_WALL_COOLDOWN_GLOBAL,
	               ZM_AAT_THUNDER_WALL_OCCURS_ON_DEATH, &result, ZM_AAT_THUNDER_WALL_DAMAGE_FEEDBACK_ICON, ZM_AAT_THUNDER_WALL_DAMAGE_FEEDBACK_SOUND );
	
	level._effect[ ZM_AAT_THUNDER_WALL_CF_NAME_BREAK_FX ]	= ZM_AAT_THUNDER_WALL_BREAK_FX;
}


function result( death, attacker, mod, weapon )
{
	self thread thunder_wall_blast( attacker );
}

// if immune_result_direct, self is unaffected by thunder wall.
// if immune_result_indirect (and !immune_result_direct), self is damaged by thunder wall, but not flung
// self == target zombie
function thunder_wall_blast( attacker )
{
	v_thunder_wall_blast_pos = self.origin; // Stores origin point of Thunder Wall
	v_attacker_facing_forward_dir = VectorToAngles( v_thunder_wall_blast_pos - attacker.origin ); // Stores player's facing when they fired
	v_attacker_facing = attacker GetWeaponForwardDir(); // Angle of blast
	v_attacker_orientation = attacker.angles; // Angle of blast fx
	
	a_ai_zombies = array::get_all_closest( v_thunder_wall_blast_pos, GetAITeamArray( "axis" ), undefined, undefined, 2 * ZM_AAT_THUNDER_WALL_RANGE );
	if ( !isDefined( a_ai_zombies ) )
	{
		return;
	}

	f_thunder_wall_range_sq = ZM_AAT_THUNDER_WALL_RANGE * ZM_AAT_THUNDER_WALL_RANGE;
	f_thunder_wall_effect_area_sq = ZM_AAT_THUNDER_WALL_RANGE * ZM_AAT_THUNDER_WALL_RANGE * 9;
	
	end_pos = v_thunder_wall_blast_pos + VectorScale( v_attacker_facing, ZM_AAT_THUNDER_WALL_RANGE );

	self PlaySound( ZM_AAT_THUNDER_WALL_EXPLOSION_SOUND );
	
	level thread thunder_wall_blast_fx( v_thunder_wall_blast_pos, v_attacker_orientation );

	n_flung_zombies = 0; // Tracks number of flung zombies, compares to ZM_AAT_THUNDER_WALL_MAX_ZOMBIES_FLUNG
	for ( i = 0; i < a_ai_zombies.size; i++ )
	{
		// If current ai_zombie is already dead
		if ( !IsDefined( a_ai_zombies[i] ) || !IsAlive( a_ai_zombies[i] ) )
		{
			continue;
		}
		
		// If current ai_zombie is immune to direct results from the AAT
		if ( IS_TRUE( level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_direct[ a_ai_zombies[i].archetype ] ) )
		{
			continue;
		}
		
		// If current zombie is the one hit by Thunder Wall, bypass checks
		if ( a_ai_zombies[i] == self )
		{
			v_curr_zombie_origin = self.origin;
			v_curr_zombie_origin_sq = 0;
		}
		else
		{
			// Get current zombie's data
			v_curr_zombie_origin = a_ai_zombies[i] GetCentroid();
			v_curr_zombie_origin_sq = DistanceSquared( v_thunder_wall_blast_pos, v_curr_zombie_origin );
			v_curr_zombie_to_thunder_wall = VectorNormalize( v_curr_zombie_origin - v_thunder_wall_blast_pos );
			v_curr_zombie_facing_dot = VectorDot( v_attacker_facing, v_curr_zombie_to_thunder_wall );
	
			// If the current zombie is in front of the zombie hit by Thunder Wall, is unaffected
			if ( v_curr_zombie_facing_dot < 0 )
			{
				continue;
			}
	
			// If current zombie is out of range
			radial_origin = PointOnSegmentNearestToPoint( v_thunder_wall_blast_pos, end_pos, v_curr_zombie_origin );
			if ( DistanceSquared( v_curr_zombie_origin, radial_origin ) > f_thunder_wall_effect_area_sq )
			{
				continue;
			}
		}
		
		// Executes the fling. If the zombie is the one hit by the bullet, will fling automatically
		if ( v_curr_zombie_origin_sq < f_thunder_wall_range_sq )
		{
			a_ai_zombies[i] DoDamage( a_ai_zombies[i].health, v_curr_zombie_origin, attacker, attacker, "none", "MOD_IMPACT" );

			if ( IsDefined( attacker ) && IsPlayer( attacker ) )
			{
				attacker zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_THUNDER_WALL" );
			}
			
			// If current ai_zombie is not immune to indirect results from the AAT, ragdoll
			if ( !IS_TRUE( level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_indirect[ self.archetype ] ) )
			{
				// Adds a slight variance to the direction of the fling
				n_random_x = RandomFloatRange( -3, 3 );
				n_random_y = RandomFloatRange( -3, 3 );
				
				a_ai_zombies[i] StartRagdoll( true );
				a_ai_zombies[i] LaunchRagdoll ( ZM_AAT_THUNDER_WALL_FORCE * VectorNormalize( v_curr_zombie_origin - v_thunder_wall_blast_pos + ( n_random_x, n_random_y, ZM_AAT_THUNDER_WALL_UPWARD_ANGLE ) ), "torso_lower" );
			}
			
			n_flung_zombies++;
		}
		
		// Limits the number of zombies flung by the bullet
		if ( ZM_AAT_THUNDER_WALL_MAX_ZOMBIES_FLUNG != 0 && n_flung_zombies >= ZM_AAT_THUNDER_WALL_MAX_ZOMBIES_FLUNG )
		{
			break;
		}
	}
}

function thunder_wall_blast_fx( v_blast_origin, v_attacker_orientation )
{	
	fx::play( ZM_AAT_THUNDER_WALL_CF_NAME_BREAK_FX, v_blast_origin, v_attacker_orientation, ZM_AAT_THUNDER_WALL_FX_TIME );
}
