#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_powerups.gsh;

// Client side powerups functionality

#precache( "client_fx", "zombie/fx_powerup_on_green_zmb" );
#precache( "client_fx", "zombie/fx_powerup_on_red_zmb" );
#precache( "client_fx", "zombie/fx_powerup_on_solo_zmb" );
#precache( "client_fx", "zombie/fx_powerup_on_caution_zmb" );

#namespace zm_powerups;

function init()
{
	//Powerups:

	//Random Drops
	add_zombie_powerup( "insta_kill_ug",		CLIENTFIELD_POWERUP_INSTANT_KILL_UG, VERSION_SHIP );

	level thread set_clientfield_code_callbacks();

	level._effect["powerup_on"] 					= "zombie/fx_powerup_on_green_zmb";
	if (IS_TRUE(level.using_zombie_powerups))
	{
		level._effect["powerup_on_red"] 				= "zombie/fx_powerup_on_red_zmb";
	}
	level._effect["powerup_on_solo"]				= "zombie/fx_powerup_on_solo_zmb";
	level._effect["powerup_on_caution"]				= "zombie/fx_powerup_on_caution_zmb";

	clientfield::register( "scriptmover", CLIENTFIELD_POWERUP_FX_NAME, VERSION_SHIP, 3, "int",&powerup_fx_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function add_zombie_powerup( powerup_name, client_field_name, clientfield_version = VERSION_SHIP )
{
	if( isdefined( level.zombie_include_powerups ) && !isdefined( level.zombie_include_powerups[powerup_name] ) )
	{
		return;
	}

	struct = SpawnStruct();

	if( !isdefined( level.zombie_powerups ) )
	{
		level.zombie_powerups = [];
	}
	
	struct.powerup_name = powerup_name;

	level.zombie_powerups[powerup_name] = struct;

	if( isdefined( client_field_name ) )
	{
		clientfield::register( "toplayer", client_field_name, clientfield_version, 2, "int", &powerup_state_callback, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
		struct.client_field_name = client_field_name;
	}
}

function set_clientfield_code_callbacks()
{
	wait(0.1);        // This won't run - until after all the client field registration has finished.

	powerup_keys = GetArrayKeys( level.zombie_powerups );
	powerup_clientfield_name = undefined;
	for ( powerup_key_index = 0; powerup_key_index < powerup_keys.size; powerup_key_index++ )
	{
		powerup_clientfield_name = level.zombie_powerups[powerup_keys[powerup_key_index]].client_field_name;
		if ( isdefined( powerup_clientfield_name ) )
		{
			SetupClientFieldCodeCallbacks( "toplayer", 1, powerup_clientfield_name );
		}
	}
}

function include_zombie_powerup( powerup_name )
{
	if( !isdefined( level.zombie_include_powerups ) )
	{
		level.zombie_include_powerups = [];
	}

	level.zombie_include_powerups[powerup_name] = true;
}

function powerup_state_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self notify( "powerup", fieldName, newVal ); 
}

function powerup_fx_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	switch ( newVal )
	{
	case CLIENTFIELD_POWERUP_FX_ON:
		fx = level._effect["powerup_on"];
		break;
	case CLIENTFIELD_POWERUP_FX_ONLY_AFFECTS_GRABBER_ON:
		fx = level._effect["powerup_on_solo"];
		break;
	case CLIENTFIELD_POWERUP_FX_ZOMBIE_GRABBABLE_ON:
		fx = level._effect["powerup_on_red"];
		break;
	case CLIENTFIELD_POWERUP_FX_ANY_TEAM_ON:
		fx = level._effect["powerup_on_caution"];
		break;		
	default:
		// do nothing
		return;
	}

	if (!isdefined(fx))
		return;
	self util::waittill_dobj( localClientNum );
	if ( !isdefined(self) )
		return;
	if( isdefined( self.fx ) )
	{
		StopFX( localClientNum, self.fx );
	}
	self.fx = PlayFXOnTag( localClientNum, fx, self, "tag_origin" );
}
