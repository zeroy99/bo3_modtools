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

#using scripts\zm\_zm_lightning_chain;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_utility;

#insert scripts\zm\aats\_zm_aat_dead_wire.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "material", ZM_AAT_DEAD_WIRE_DAMAGE_FEEDBACK_ICON );

#namespace zm_aat_dead_wire;

REGISTER_SYSTEM( ZM_AAT_DEAD_WIRE_NAME, &__init__, "aat" )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_DEAD_WIRE_NAME, ZM_AAT_DEAD_WIRE_PERCENTAGE, ZM_AAT_DEAD_WIRE_COOLDOWN_ENTITY, ZM_AAT_DEAD_WIRE_COOLDOWN_ATTACKER, ZM_AAT_DEAD_WIRE_COOLDOWN_GLOBAL,
	               ZM_AAT_DEAD_WIRE_OCCURS_ON_DEATH, &result, ZM_AAT_DEAD_WIRE_DAMAGE_FEEDBACK_ICON, ZM_AAT_DEAD_WIRE_DAMAGE_FEEDBACK_SOUND );

	clientfield::register( "actor", ZM_AAT_DEAD_WIRE_CF_NAME_ZAP, VERSION_SHIP, 1, "int" ); 
	clientfield::register( "vehicle", ZM_AAT_DEAD_WIRE_CF_NAME_ZAP_VEH, VERSION_SHIP, 1, "int" );

	level.zm_aat_dead_wire_lightning_chain_params = lightning_chain::create_lightning_chain_params( ZM_AAT_DEAD_WIRE_MAX_ARCS, ZM_AAT_DEAD_WIRE_MAX_ARCS + 1, ZM_AAT_DEAD_WIRE_RANGE );
	level.zm_aat_dead_wire_lightning_chain_params.head_gib_chance = 100;
	level.zm_aat_dead_wire_lightning_chain_params.network_death_choke = 4;
	level.zm_aat_dead_wire_lightning_chain_params.challenge_stat_name = "ZOMBIE_HUNTER_DEAD_WIRE";
}

function result( death, attacker, mod, weapon )
{
	if( !isdefined( level.zombie_vars[ "tesla_head_gib_chance" ] ) )
	{
		zombie_utility::set_zombie_var( "tesla_head_gib_chance", 50 );
	}		
	
	attacker.tesla_enemies = undefined;
	attacker.tesla_enemies_hit = 1;
	attacker.tesla_powerup_dropped = false;
	attacker.tesla_arc_count = 0;
	level.zm_aat_dead_wire_lightning_chain_params.weapon = weapon;
	
	self lightning_chain::arc_damage( self, attacker, 1, level.zm_aat_dead_wire_lightning_chain_params );
}

