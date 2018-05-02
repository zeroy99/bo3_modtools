#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;
#insert scripts\zm\_zm_perk_widows_wine.gsh;

#using scripts\zm\_zm_powerup_ww_grenade;

#precache( "client_fx", WIDOWS_WINE_FX_FILE_MACHINE_LIGHT );
#precache( "client_fx", WIDOWS_WINE_FX_FILE_WRAP );
#precache( "client_fx", WIDOWS_WINE_1P_EXPLOSION );

#namespace zm_perk_widows_wine;

REGISTER_SYSTEM( "zm_perk_widows_wine", &__init__, undefined )

// WIDOW'S WINE
	
function __init__()
{
	// register custom functions for hud/lua
	zm_perks::register_perk_clientfields( PERK_WIDOWS_WINE, &widows_wine_client_field_func, &widows_wine_code_callback_func );
	zm_perks::register_perk_effects( PERK_WIDOWS_WINE, WIDOWS_WINE_FX_MACHINE_LIGHT );
	zm_perks::register_perk_init_thread( PERK_WIDOWS_WINE, &init_widows_wine );
	
	// 1st Person Effects on Contact Explosion
	clientfield::register( "toplayer", "widows_wine_1p_contact_explosion", VERSION_SHIP, 1, "counter", &widows_wine_1p_contact_explosion, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}


function init_widows_wine()
{
	if( IS_TRUE(level.enable_magic) )
	{
		level._effect[WIDOWS_WINE_FX_MACHINE_LIGHT]	= WIDOWS_WINE_FX_FILE_MACHINE_LIGHT;
		level._effect[WIDOWS_WINE_FX_WRAP]			= WIDOWS_WINE_FX_FILE_WRAP;
	}
}


function widows_wine_client_field_func()
{
	clientfield::register( "clientuimodel", PERK_CLIENTFIELD_WIDOWS_WINE, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT ); 

	clientfield::register( "actor", CF_WIDOWS_WINE_WRAP, VERSION_SHIP, 1, "int", &widows_wine_wrap_cb, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "vehicle", CF_WIDOWS_WINE_WRAP, VERSION_SHIP, 1, "int", &widows_wine_wrap_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
}

function widows_wine_code_callback_func()
{
}

// self == zombie target
function widows_wine_wrap_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		if ( IsDefined( self ) && IsAlive( self ) )
		{
			if ( !isdefined( self.fx_widows_wine_wrap ) )
			{
				self.fx_widows_wine_wrap = PlayFxOnTag( localClientNum, level._effect[WIDOWS_WINE_FX_WRAP], self, "j_spineupper" );
			}
			
			if( !isdefined( self.sndWidowsWine ) )
			{
				self playsound( 0, "wpn_wwgrenade_cocoon_imp" );
				self.sndWidowsWine = self playloopsound( "wpn_wwgrenade_cocoon_lp", .1 );
			}
		}
	}
	else
	{
		if ( isdefined( self.fx_widows_wine_wrap ) )
		{
			StopFX( localClientNum, self.fx_widows_wine_wrap );
			self.fx_widows_wine_wrap = undefined;
		}
		
		if( isdefined( self.sndWidowsWine ) )
		{
			self playsound( 0, "wpn_wwgrenade_cocoon_stop" );
			self stoploopsound( self.sndWidowsWine, .1 );
		}
	}
}

// self == player
function widows_wine_1p_contact_explosion( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	owner = self GetOwner( localClientNum );
	if ( IsDefined(owner) && owner == GetLocalPlayer(localClientNum) )
	{
		thread widows_wine_1p_contact_explosion_play( localClientNum );
	}
}

function widows_wine_1p_contact_explosion_play( localClientNum )
{
	tag = "tag_flash";

	if ( !ViewmodelHasTag( localClientNum, tag ) )
	{
		tag = "tag_weapon";
		if ( !ViewmodelHasTag( localClientNum, tag ) )
		{
			return;
		}
	}

	fx_contact_explosion = PlayViewmodelFx( localClientNum, WIDOWS_WINE_1P_EXPLOSION, tag );
	wait 2.0;
	DeleteFx( localClientNum, fx_contact_explosion, true );
}

