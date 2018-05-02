#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#define ELECTRIC_CHERRY_MACHINE_LIGHT_FX	"electric_light"	

#precache( "client_fx", "_t6/misc/fx_zombie_cola_revive_on" );
#precache( "client_fx", "dlc1/castle/fx_castle_electric_cherry_down" );
#precache( "client_fx", "dlc1/castle/fx_castle_electric_cherry_trail" );
#precache( "client_fx", "zombie/fx_tesla_shock_zmb" );
#precache( "client_fx", "zombie/fx_tesla_shock_eyes_zmb"	);

#namespace zm_perk_electric_cherry;

REGISTER_SYSTEM( "zm_perk_electric_cherry", &__init__, undefined )

// ELECTRIC CHERRY ( ELECTRIC CHERRY )
	
function __init__()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_ELECTRIC_CHERRY, &electric_cherry_client_field_func, &electric_cherry_code_callback_func );
	zm_perks::register_perk_effects( PERK_ELECTRIC_CHERRY, ELECTRIC_CHERRY_MACHINE_LIGHT_FX );
	zm_perks::register_perk_init_thread( PERK_ELECTRIC_CHERRY, &init_electric_cherry );
}

function init_electric_cherry()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[ELECTRIC_CHERRY_MACHINE_LIGHT_FX]	= "_t6/misc/fx_zombie_cola_revive_on";
	}
	
	// Register Clientfields
	RegisterClientField( "allplayers", "electric_cherry_reload_fx",	VERSION_SHIP, 2, "int", &electric_cherry_reload_attack_fx, false );
	clientfield::register( "actor", "tesla_death_fx", VERSION_SHIP, 1, "int", &tesla_death_fx_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "tesla_death_fx_veh", VERSION_TU10, 1, "int", &tesla_death_fx_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	// Leave at VERSION_TU10
	clientfield::register( "actor", "tesla_shock_eyes_fx", VERSION_SHIP, 1, "int", &tesla_shock_eyes_fx_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "tesla_shock_eyes_fx_veh", VERSION_TU10, 1, "int", &tesla_shock_eyes_fx_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	// Leave at VERSION_TU10

	// Load FX	
	level._effect[ "electric_cherry_explode" ]				= "dlc1/castle/fx_castle_electric_cherry_down";
	level._effect[ "electric_cherry_trail" ]				= "dlc1/castle/fx_castle_electric_cherry_trail";
	level._effect["tesla_death_cherry"]					= "zombie/fx_tesla_shock_zmb";
	level._effect["tesla_shock_eyes_cherry"]		= "zombie/fx_tesla_shock_eyes_zmb";
	level._effect["tesla_shock_cherry"]		= "zombie/fx_bmode_shock_os_zod_zmb";

	//level._effect[ "electric_cherry_reload_small" ]			= "maps/zombie_alcatraz/fx_alcatraz_electric_cherry_sm";
	//level._effect[ "electric_cherry_reload_medium" ]		= "maps/zombie_alcatraz/fx_alcatraz_electric_cherry_player";
	//level._effect[ "electric_cherry_reload_large" ]			= "maps/zombie_alcatraz/fx_alcatraz_electric_cherry_lg";
}

function electric_cherry_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_ELECTRIC_CHERRY, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

function electric_cherry_code_callback_func()
{
}

function electric_cherry_reload_attack_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
	if ( IsDefined( self.electric_cherry_reload_fx ) )
	{	
		StopFX( localClientNum, self.electric_cherry_reload_fx );			
	}
	
	if ( newVal == 1 )
	{
		self.electric_cherry_reload_fx = PlayFXOnTag( localClientNum, level._effect[ "electric_cherry_explode" ], self, "tag_origin" );
	}
	else if ( newVal == 2 )
	{
		self.electric_cherry_reload_fx = PlayFXOnTag( localClientNum, level._effect[ "electric_cherry_explode" ], self, "tag_origin" );
	}
	else if ( newVal == 3 )
	{
		self.electric_cherry_reload_fx = PlayFXOnTag( localClientNum, level._effect[ "electric_cherry_explode" ], self, "tag_origin" );
	}
	else
	{
		if ( IsDefined( self.electric_cherry_reload_fx ) )
		{
			StopFX( localClientNum, self.electric_cherry_reload_fx );			
		}
		
		self.electric_cherry_reload_fx = undefined;
	}
}

function tesla_death_fx_callback(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump) // self = zombie
{
	if( newVal == 1 )
	{
		str_tag = "J_SpineUpper";

		if( isdefined( self.str_tag_tesla_death_fx ) )
		{
			str_tag = self.str_tag_tesla_death_fx;
		}
		else if ( IS_TRUE( self.isdog ) )
		{
			str_tag = "J_Spine1";
		}
		
		self.n_death_fx = PlayFXOnTag( localClientNum, level._effect["tesla_death_cherry"], self, str_tag );
		SetFXIgnorePause( localClientNum, self.n_death_fx, true );
	}
	else
	{
		if ( isdefined( self.n_death_fx ) )
		{
			DeleteFx( localClientNum, self.n_death_fx, true );
		}
		self.n_death_fx = undefined;
	}		
}

function tesla_shock_eyes_fx_callback(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump) // self = zombie
{
	if( newVal == 1 )
	{
		str_tag = "J_SpineUpper";

		if( isdefined( self.str_tag_tesla_shock_eyes_fx ) )
		{
			str_tag = self.str_tag_tesla_shock_eyes_fx;
		}
		else if ( IS_TRUE( self.isdog ) )
		{
			str_tag = "J_Spine1";
		}
		
		self.n_shock_eyes_fx = PlayFXOnTag( localClientNum, level._effect["tesla_shock_eyes_cherry"], self, "J_Eyeball_LE" );
		SetFXIgnorePause( localClientNum, self.n_shock_eyes_fx, true );
		
		self.n_shock_fx = PlayFXOnTag( localClientNum, level._effect["tesla_death_cherry"], self, str_tag );
		SetFXIgnorePause( localClientNum, self.n_shock_fx, true );
	}
	else
	{
		if ( isdefined( self.n_shock_eyes_fx ) )
		{
			DeleteFx( localClientNum, self.n_shock_eyes_fx, true );
			self.n_shock_eyes_fx = undefined;		
		}
		
		if ( isdefined( self.n_shock_fx ) )
		{
			DeleteFx( localClientNum, self.n_shock_fx, true );
			self.n_shock_fx = undefined;
		}
	}		
}