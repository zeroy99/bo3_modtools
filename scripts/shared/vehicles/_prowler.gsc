#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\shared\ai\utility.gsh;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
	
#namespace prowler;

REGISTER_SYSTEM( "prowler", &__init__, undefined )
	

function __init__()
{
	vehicle::add_main_callback( "prowler_quad", &main );
	vehicle::add_main_callback( "prowler_speed", &main );
}

function main()
{
	self.overrideVehicleDamage = &ProwlerCallback_VehicleDamage;
	
	self thread update();
}

function watch_transform( driver )
{
	self endon( "death" );
	self endon( "exit_vehicle" );
	driver endon( "death" );
	
	while( 1 )
	{
		wait 1.5;
		
		while ( !driver SprintButtonPressed() )
		{
			wait .05;
		}
		
		if( self.vehicletype == "prowler_quad" )
		{
			self.vehicletype = "prowler_speed";
			self SetVehicleType( "prowler_speed" );
		}
		else
		{
			self.vehicletype = "prowler_quad";
			self SetVehicleType( "prowler_quad" );
		}
	}
}

function update()
{
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "enter_vehicle", driver );
		self thread watch_transform( driver );
	}
}

function ProwlerCallback_VehicleDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime, damageFromUnderneath, modelIndex, partName )
{
	
	return iDamage;
}

