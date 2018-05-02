#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\gameobjects_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#insert scripts\shared\ai\utility.gsh;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_ai_shared;
#using scripts\shared\vehicle_death_shared;

#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_bundles;
	
#define MECHTANK_BUNDLE "mechtank"
	
#namespace mechtank;

REGISTER_SYSTEM( "mechtank", &__init__, undefined )
	
#using_animtree( "generic" );

function __init__()
{
	vehicle::add_main_callback( "mechtank", &mechtank_initialize );
}

function mechtank_initialize() 
{
	self useanimtree( #animtree );
	
	self.targetOffset = ( 0, 0, 60 );
	
	self EnableAimAssist();
	
	self.fovcosine = 0; // +/-90 degrees = 180 fov, err 0 actually means 360 degree view
	self.fovcosinebusy = 0;
	self.maxsightdistsqrd = SQR( 10000 );
	self.allow_movement = true;
	
	assert( isdefined( self.scriptbundlesettings ) );
	
	self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	self.overrideVehicleDamage = &MechtankCallback_VehicleDamage;

	killstreak_bundles::register_killstreak_bundle( MECHTANK_BUNDLE );
	self.maxhealth = killstreak_bundles::get_max_health( MECHTANK_BUNDLE );
	self.heatlh = self.maxhealth;
}

function MechtankCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if ( isdefined( eAttacker ) && ( eAttacker == self || isplayer( eAttacker ) && eAttacker.usingvehicle && eAttacker.viewlockedentity === self ) )
	{
		return 0;
	}

	if ( sMeansOfDeath === "MOD_MELEE" || sMeansOfDeath === "MOD_MELEE_WEAPON_BUTT" || sMeansOfDeath === "MOD_MELEE_ASSASSINATE" || sMeansOfDeath === "MOD_ELECTROCUTED" || sMeansOfDeath === "MOD_CRUSH" || weapon.isEmp )
	{
		return 0;
	}
	
	iDamage = self killstreaks::OnDamagePerWeapon( MECHTANK_BUNDLE, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth * 0.4, undefined, 0, undefined, true, 1.0 );

	
	driver = self GetSeatOccupant( 0 );
	if ( isPlayer( driver ) )
	{
		driver vehicle::update_damage_as_occupant( self.maxhealth - ( self.health - iDamage ), self.maxhealth );
	}	
	
	return iDamage;
}
