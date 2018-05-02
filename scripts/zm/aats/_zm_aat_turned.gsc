#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\table_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;

#insert scripts\zm\aats\_zm_aat_turned.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "material", ZM_AAT_TURNED_DAMAGE_FEEDBACK_ICON );

#namespace zm_aat_turned;

REGISTER_SYSTEM( ZM_AAT_TURNED_NAME, &__init__, "aat" )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_TURNED_NAME, ZM_AAT_TURNED_PERCENTAGE, ZM_AAT_TURNED_COOLDOWN_ENTITY, ZM_AAT_TURNED_COOLDOWN_ATTACKER, ZM_AAT_TURNED_COOLDOWN_GLOBAL,
	               ZM_AAT_TURNED_OCCURS_ON_DEATH, &result, ZM_AAT_TURNED_DAMAGE_FEEDBACK_ICON, ZM_AAT_TURNED_DAMAGE_FEEDBACK_SOUND, &turned_zombie_validation );

	clientfield::register( "actor", ZM_AAT_TURNED_NAME, VERSION_SHIP, 1, "int" );
}

function result( death, attacker, mod, weapon )
{
	self thread clientfield::set( ZM_AAT_TURNED_NAME, 1 );
	
	self thread zombie_death_time_limit( attacker );
	
	self.team = "allies";
	self.aat_turned = true;
	self.n_aat_turned_zombie_kills = 0;
	self.allowDeath = false;
	self.allowpain = false;
	self.no_gib = true; 

	// make sure it's the fastest type of zombie
	self zombie_utility::set_zombie_run_cycle( "sprint" );
	if ( math::cointoss() )
	{
		if ( self.zombie_arms_position == "up" )
		{
			self.variant_type = ZM_AAT_TURNED_SPRINT_VARIANT_MAX_ARMS_UP - 1;
		}
		else
		{
			self.variant_type = ZM_AAT_TURNED_SPRINT_VARIANT_MAX_ARMS_DOWN - 1;
		}
	}
	else
	{
		if ( self.zombie_arms_position == "up" )
		{
			self.variant_type = ZM_AAT_TURNED_SPRINT_VARIANT_MAX_ARMS_UP;
		}
		else
		{
			self.variant_type = ZM_AAT_TURNED_SPRINT_VARIANT_MAX_ARMS_DOWN;
		}
	}

	if ( IsDefined( attacker ) && IsPlayer( attacker ) )
	{
		attacker zm_stats::increment_challenge_stat( "ZOMBIE_HUNTER_TURNED" );
	}

	self thread turned_local_blast( attacker );
	self thread zombie_kill_tracker( attacker );
}

//self == turned zombie
function turned_local_blast( attacker )
{
	v_turned_blast_pos = self.origin;
	
	a_ai_zombies = array::get_all_closest( v_turned_blast_pos, GetAITeamArray( "axis" ), undefined, undefined, ZM_AAT_TURNED_RANGE );
	if ( !isDefined( a_ai_zombies ) )
	{
		return;
	}

	f_turned_range_sq = ZM_AAT_TURNED_RANGE * ZM_AAT_TURNED_RANGE;
	
	n_flung_zombies = 0; // Tracks number of flung zombies, compares to ZM_AAT_TURNED_MAX_ZOMBIES_FLUNG
	for ( i = 0; i < a_ai_zombies.size; i++ )
	{
		// If current ai_zombie is already dead
		if ( !IsDefined( a_ai_zombies[i] ) || !IsAlive( a_ai_zombies[i] ) )
		{
			continue;
		}
		
		// If current ai_zombie is immune to indirect results from the AAT
		if ( IS_TRUE( level.aat[ ZM_AAT_TURNED_NAME ].immune_result_indirect[ a_ai_zombies[i].archetype ] ) )
		{
			continue;
		}
		
		// If current zombie is the one hit by Turned, bypass checks
		if ( a_ai_zombies[i] == self )
		{
			continue;
		}

		// Get current zombie's data
		v_curr_zombie_origin = a_ai_zombies[i] GetCentroid();
		if ( DistanceSquared( v_turned_blast_pos, v_curr_zombie_origin ) > f_turned_range_sq )
		{
			continue;
		}
		
		// Executes the fling.
		a_ai_zombies[i] DoDamage( a_ai_zombies[i].health, v_curr_zombie_origin, attacker, attacker, "none", "MOD_IMPACT" );

		// Adds a slight variance to the direction of the fling
		n_random_x = RandomFloatRange( -3, 3 );
		n_random_y = RandomFloatRange( -3, 3 );

		a_ai_zombies[i] StartRagdoll( true );
		a_ai_zombies[i] LaunchRagdoll ( ZM_AAT_TURNED_FORCE * VectorNormalize( v_curr_zombie_origin - v_turned_blast_pos + ( n_random_x, n_random_y, ZM_AAT_TURNED_UPWARD_ANGLE ) ), "torso_lower" );

		// Limits the number of zombies flung
		n_flung_zombies++;
		if ( ZM_AAT_TURNED_MAX_ZOMBIES_FLUNG != 0 && n_flung_zombies >= ZM_AAT_TURNED_MAX_ZOMBIES_FLUNG )
		{
			break;
		}
	}
}

// Checks to see if fire works is running
// self == zombie
function turned_zombie_validation()
{
	// Bypasses enemys who are immune to AAT results
	if ( IS_TRUE( level.aat[ ZM_AAT_TURNED_NAME ].immune_result_direct[ self.archetype ] ) )
	{
		return false;
	}
	
	if( IS_TRUE( self.barricade_enter ) )
	{
		return false;
	}
	
	if ( IS_TRUE( self.is_traversing ) )
	{
		return false;
	}

	if ( !IS_TRUE( self.completed_emerging_into_playable_area ) )
	{
		return false;
	}

	if ( IS_TRUE( self.is_leaping ) )
	{
		return false;
	}
	
    if ( IsDefined( level.zm_aat_turned_validation_override ) && !self [[level.zm_aat_turned_validation_override]]() )
    {
		return false;
    }
	
	return true;
}

// Sets Time Limit before zombie dies
// self == affected zombie
function zombie_death_time_limit( e_attacker )
{
	self endon( "death" );
	self endon( "entityshutdown" );
	
	wait ZM_AAT_TURNED_TIME_LIMIT;
	
	self clientfield::set( ZM_AAT_TURNED_NAME, 0 );
	self.allowDeath = true;
	self zombie_death_gib( e_attacker );
}

// self == zombie
function zombie_kill_tracker( e_attacker )
{
	self endon( "death" );
	self endon( "entityshutdown" );
	
	while ( self.n_aat_turned_zombie_kills < ZM_AAT_TURNED_KILL_LIMIT )
	{
		wait SERVER_FRAME;
	}
	
	wait .5; // Slight pause to complete any currently running swipe animations before death
	self clientfield::set( ZM_AAT_TURNED_NAME, 0 );
	self.allowDeath = true;
	self zombie_death_gib( e_attacker );
}

// Gibs and Kills zombie
// self == affected zombie
function zombie_death_gib( e_attacker )
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
	
	self DoDamage( self.health, self.origin );
}
