#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_weap_octobomb.gsh;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#precache( "client_fx", "zombie/fx_octobomb_explo_death_zod_zmb" );

#precache( "client_fx", "zombie/fx_octobomb_spore_burn_leg_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_spore_burn_torso_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_sporesplosion_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_sporesplosion_tell_zod_zmb" );

#precache( "client_fx", "zombie/fx_octobomb_spore_burn_leg_ee_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_spore_burn_torso_ee_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_sporesplosion_ee_zod_zmb" );
#precache( "client_fx", "zombie/fx_octobomb_sporesplosion_tell_ee_zod_zmb" );

#precache( "client_fx", "impacts/fx_flesh_hit_knife_lg_zmb" );
#precache( "client_fx", "zombie/fx_bmode_attack_grapple_zod_zmb" );

REGISTER_SYSTEM_EX( "zm_weap_octobomb", &__init__, &__main__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "octobomb_fx", VERSION_SHIP, 2, "int", &octobomb_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "octobomb_spores_fx", VERSION_SHIP, 2, "int", &octobomb_spores_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "octobomb_tentacle_hit_fx", VERSION_SHIP, 1, "int", &octobomb_tentacle_hit_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "zombie_explode_fx", VERSION_SHIP, 1, "counter", &octobomb_zombie_explode_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "zombie_explode_fx", VERSION_TU8_OBSOLETE, 1, "counter", &octobomb_zombie_explode_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "octobomb_zombie_explode_fx", VERSION_TU8, 1, "counter", &octobomb_zombie_explode_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "missile", "octobomb_spit_fx", VERSION_SHIP, 2, "int", &octobomb_spit_fx, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", 	"octobomb_state",				VERSION_SHIP,	3,	"int",		undefined,						!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	SetupClientFieldCodeCallbacks( "toplayer", 1, "octobomb_state" );
}

function __main__()
{
	if ( !zm_weapons::is_weapon_included( GetWeapon( STR_WEAP_OCTOBOMB ) ) )
	{
		return;
	}
	
	level._effect[ "octobomb_explode_fx" ]			= "zombie/fx_octobomb_explo_death_zod_zmb";
	
	level._effect[ "octobomb_spores" ]				= "zombie/fx_octobomb_sporesplosion_zod_zmb";
	level._effect[ "octobomb_spores_spine" ]		= "zombie/fx_octobomb_spore_burn_torso_zod_zmb";
	level._effect[ "octobomb_spores_legs" ]			= "zombie/fx_octobomb_spore_burn_leg_zod_zmb";
	level._effect[ "octobomb_sporesplosion" ]		= "zombie/fx_octobomb_sporesplosion_tell_zod_zmb";

	level._effect[ "octobomb_ug_spores" ]			= "zombie/fx_octobomb_sporesplosion_ee_zod_zmb";
	level._effect[ "octobomb_ug_spores_spine" ]		= "zombie/fx_octobomb_spore_burn_torso_ee_zod_zmb";
	level._effect[ "octobomb_ug_spores_legs" ]		= "zombie/fx_octobomb_spore_burn_leg_zod_zmb";
	level._effect[ "octobomb_ug_sporesplosion" ]	= "zombie/fx_octobomb_sporesplosion_tell_ee_zod_zmb";

	level._effect[ "octobomb_tentacle_hit" ]		= "impacts/fx_flesh_hit_knife_lg_zmb";
	level._effect[ "zombie_explode" ]				= "zombie/fx_bmode_attack_grapple_zod_zmb";
}

// self == zombie target
function octobomb_tentacle_hit_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self.fx_octobomb_tentacle_hit = PlayFXOnTag( localClientNum, level._effect[ "octobomb_tentacle_hit" ], self, "j_spineupper" );
	}
	else
	{
		if ( isdefined( self.fx_octobomb_tentacle_hit ) )
		{
			StopFX( localClientNum, self.fx_octobomb_tentacle_hit );
			self.fx_octobomb_tentacle_hit = undefined;
		}
	}
}

// self == zombie target
function octobomb_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	switch ( newVal )
	{
		case CF_OCTOBOMB_EXPLODE_FX:
			PlayFX( localClientNum, level._effect[ "octobomb_explode_fx" ], self.origin, AnglesToUp( self.angles ) );
			break;
		case CF_OCTOBOMB_UG_FX:
			fx_octobomb = level._effect[ "octobomb_ug_spores" ];
			PlayFXOnTag( localClientNum, fx_octobomb, self, "tag_origin" );
			break;
		default:
			fx_octobomb = level._effect[ "octobomb_spores" ];
			PlayFXOnTag( localClientNum, fx_octobomb, self, "tag_origin" );
			break;
	}
}


// self == zombie target
function octobomb_spores_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self thread octobomb_spore_fx_on( localClientNum, newVal );
	}
}


// self == zombie target
function octobomb_spore_fx_on( localClientNum, n_fx_type )
{
	self endon( "entityshutdown" );
	
	if ( n_fx_type == CF_OCTOBOMB_UG_FX )
	{
		//TODO Replace with upgraded FX when made
		fx_spine = level._effect[ "octobomb_ug_spores_spine" ];
		fx_legs = level._effect[ "octobomb_ug_spores_legs" ];
	}
	else
	{
		fx_spine = level._effect[ "octobomb_spores_spine" ];
		fx_legs = level._effect[ "octobomb_spores_legs" ];
	}
	
	self.fx_octobomb_spores_spine = PlayFXOnTag( localClientNum, fx_spine, self, "j_spine4" );
	
	wait ( OCTOBOMB_DAMAGE_TIME / 2 );
	
	self.fx_octobomb_spores_leg_ri = PlayFXOnTag( localClientNum, fx_legs, self, "j_hip_ri" );
	self.fx_octobomb_spores_leg_le = PlayFXOnTag( localClientNum, fx_legs, self, "j_hip_le" );
	
	wait ( OCTOBOMB_DAMAGE_TIME / 2 );
	
	StopFX( localClientNum, self.fx_octobomb_spores_spine );
    StopFX( localClientNum, self.fx_octobomb_spores_leg_ri );
    StopFX( localClientNum, self.fx_octobomb_spores_leg_le );
}

// self == zombie target
function octobomb_zombie_explode_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( util::is_mature() && !util::is_gib_restricted_build() )
	{
		PlayFXOnTag( localClientNum, level._effect["zombie_explode"], self, "j_spinelower" );
	}
}

// self == octobomb
function octobomb_spit_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == CF_OCTOBOMB_UG_FX )
	{
		fx_spit = level._effect[ "octobomb_ug_sporesplosion" ];
	}
	else
	{
		fx_spit = level._effect[ "octobomb_sporesplosion" ];
	}
	level thread octobomb_spit_fx_and_cleanup( localClientNum, self.origin, self.angles, fx_spit );
}

// octobomb spit fx are only ever timed the same way; cleaning them up here to prevent case where the margwa would kill octobomb before the clientfield was reset
function octobomb_spit_fx_and_cleanup( localClientNum, v_origin, v_angles, fx_spit )
{
	fx_id = PlayFX( localClientNum, fx_spit, v_origin, AnglesToUp( v_angles ) );
	wait 3.416675; // amount of time the octobomb was previously calculating to wait before killing the effect
	StopFx( localClientNum, fx_id );
}

