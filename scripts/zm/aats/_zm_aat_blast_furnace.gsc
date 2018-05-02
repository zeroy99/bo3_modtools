#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\gib;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\aats\_zm_aat_blast_furnace.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "material", ZM_AAT_BLAST_FURNACE_DAMAGE_FEEDBACK_ICON );

#namespace zm_aat_blast_furnace;

REGISTER_SYSTEM( ZM_AAT_BLAST_FURNACE_NAME, &__init__, "aat" )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_BLAST_FURNACE_NAME, ZM_AAT_BLAST_FURNACE_PERCENTAGE, ZM_AAT_BLAST_FURNACE_COOLDOWN_ENTITY, ZM_AAT_BLAST_FURNACE_COOLDOWN_ATTACKER, ZM_AAT_BLAST_FURNACE_COOLDOWN_GLOBAL,
	               ZM_AAT_BLAST_FURNACE_OCCURS_ON_DEATH, &result, ZM_AAT_BLAST_FURNACE_DAMAGE_FEEDBACK_ICON, ZM_AAT_BLAST_FURNACE_DAMAGE_FEEDBACK_SOUND );

	clientfield::register( "actor", ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION, VERSION_SHIP, 1, "counter" );
	clientfield::register( "vehicle", ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION_VEH, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", ZM_AAT_BLAST_FURNACE_CF_NAME_BURN, VERSION_SHIP, 1, "counter" );
	clientfield::register( "vehicle", ZM_AAT_BLAST_FURNACE_CF_NAME_BURN_VEH, VERSION_SHIP, 1, "counter" );
}


function result( death, attacker, mod, weapon )
{	
	self thread blast_furnace_explosion( attacker, weapon );
}

// Sets Time Limit before zombie dies
// if immune_result_direct, target does not get death gibbed by blast furnace
// if immune_result_indirect, target does not get affected by damage over time
// self == explosion point entity model
function blast_furnace_explosion( e_attacker, w_weapon )
{
	if ( IsVehicle( self ) )
	{
		self thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION_VEH );
	}
	else
	{
		self thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION );
	}
	
	// Get array of zombies 
	a_e_blasted_zombies = array::get_all_closest( self.origin, GetAITeamArray( "axis" ), undefined, undefined, ZM_AAT_BLAST_FURNACE_RANGE );
	
	if ( a_e_blasted_zombies.size > 0 )
	{
		i = 0;
		while ( i < a_e_blasted_zombies.size )
		{
			if ( IsAlive( a_e_blasted_zombies[i] ) )
			{
				
				// If current ai_zombie is immune to indirect results from the AAT
				if ( IS_TRUE( level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_indirect[ a_e_blasted_zombies[i].archetype ] ) )
				{
					ArrayRemoveValue( a_e_blasted_zombies, a_e_blasted_zombies[i] );
					continue;
				}
				
				if ( ( a_e_blasted_zombies[i] == self ) && !IS_TRUE( level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_direct[ a_e_blasted_zombies[i].archetype ] ) )
				{
					self thread zombie_death_gib( e_attacker, w_weapon );
					
					if ( IsVehicle( a_e_blasted_zombies[i] ) )
					{
						a_e_blasted_zombies[i] thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_BURN_VEH );
					}
					else
					{
						a_e_blasted_zombies[i] thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_BURN );
					}
					
					ArrayRemoveValue( a_e_blasted_zombies, a_e_blasted_zombies[i] );
					continue;
				}
				
				if ( IsVehicle( a_e_blasted_zombies[i] ) )
				{
					a_e_blasted_zombies[i] thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_BURN_VEH );
				}
				else
				{
					a_e_blasted_zombies[i] thread clientfield::increment( ZM_AAT_BLAST_FURNACE_CF_NAME_BURN );
				}
			}
			
			i++;
		}
		
		wait ZM_AAT_BLAST_FURNACE_DELAY;
		
		a_e_blasted_zombies = array::remove_dead( a_e_blasted_zombies );
		a_e_blasted_zombies = array::remove_undefined( a_e_blasted_zombies );
		array::thread_all( a_e_blasted_zombies, &blast_furnace_zombie_burn, e_attacker, w_weapon );
	}
}

// Does damage to burning szombies
// self == affected zombie
function blast_furnace_zombie_burn( e_attacker, w_weapon )
{
	self endon( "death" );
	
	n_damage = self.health / ZM_AAT_BLAST_FURNACE_DOT_NUM_TICKS;
	
	i = 0;
	while ( i <= ZM_AAT_BLAST_FURNACE_DOT_NUM_TICKS )
	{
		// if doing fatal damage, increment the stat
		if( self.health < n_damage )
		{
			e_attacker zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_BLAST_FURNACE" );
		}
		
		self DoDamage( n_damage, self.origin, e_attacker, undefined, "none", "MOD_UNKNOWN", 0, w_weapon );
		i++;
		wait ZM_AAT_BLAST_FURNACE_DOT_TICK_RATE;
	}
}

// Gibs and Kills zombie
// self == affected zombie
function zombie_death_gib( e_attacker, w_weapon )
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
	
	self DoDamage( self.health, self.origin, e_attacker );

	if ( IsDefined( e_attacker ) && IsPlayer( e_attacker ) )
	{
		e_attacker zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_BLAST_FURNACE" );
	}
}


