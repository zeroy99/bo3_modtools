#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;


#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define PARASITE_BELLY_GLOW_MIN 0.1
#define PARASITE_BELLY_GLOW_MAX 1.0	

#namespace parasite;

function autoexec main()
{	
	clientfield::register( "vehicle", "parasite_tell_fx", VERSION_SHIP, 1, "int", &parasiteTellFxHandler, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "parasite_damage", VERSION_SHIP, 1, "counter", &parasite_damage, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "parasite_secondary_deathfx", VERSION_SHIP, 1, "int", &parasiteSecondaryDeathFxHandler, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	vehicle::add_vehicletype_callback( "parasite", &_setup_ );
}

function private parasiteTellFxHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{	
	if ( IsDefined( self.tellFxHandle ) )
	{
		StopFX( localClientNum, self.tellFxHandle );
		self.tellFxHandle = undefined;
		self MapShaderConstant( localClientNum, 0, "scriptVector2", PARASITE_BELLY_GLOW_MIN );
	}
	
	settings = struct::get_script_bundle( "vehiclecustomsettings", "parasitesettings" );
	
	if( IsDefined( settings ) )
	{
		if( newValue )
		{
			self.tellFxHandle = PlayFXOnTag( localClientNum, settings.weakspotfx, self, "tag_flash" );
			self MapShaderConstant( localClientNum, 0, "scriptVector2", PARASITE_BELLY_GLOW_MAX );
		}
	}
}

function private parasite_damage( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if ( newValue )
	{
		self postfx::PlayPostfxBundle( "pstfx_parasite_dmg" );
	}
}

function private parasiteSecondaryDeathFxHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	settings = struct::get_script_bundle( "vehiclecustomsettings", "parasitesettings" );
	
	if( IsDefined( settings ) )
	{
		if( newValue )
		{
			handle = PlayFX( localClientNum, settings.secondary_death_fx_1, self GetTagOrigin( settings.secondary_death_tag_1 ) );
			SetFXIgnorePause( localClientNum, handle, true );
		}
	}
}

function private _setup_( localClientNum )
{	
	self MapShaderConstant( localClientNum, 0, "scriptVector2", PARASITE_BELLY_GLOW_MIN );
	
	if( IS_TRUE(level.debug_keyline_zombies) )
	{
		self duplicate_render::set_dr_flag( "keyline_active", 1 );
		self duplicate_render::update_dr_filters(localClientNum);
	}
}