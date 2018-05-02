#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#using scripts\zm\_zm;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "zombie/fx_dog_eyes_zmb" );
#precache( "client_fx", "zombie/fx_dog_fire_trail_zmb" );

#namespace zm_ai_dogs;

REGISTER_SYSTEM( "zm_ai_dogs", &__init__, undefined )

function __init__()
{
	init_dog_fx();
	
	clientfield::register( "actor", "dog_fx", VERSION_SHIP, 1, "int", &dog_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function init_dog_fx()
{
	level._effect[ "dog_eye_glow" ]			= "zombie/fx_dog_eyes_zmb";
	level._effect[ "dog_trail_fire" ]		= "zombie/fx_dog_fire_trail_zmb";	
}

function dog_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )//self = dog
{
	if( newVal )
	{
		self._eyeglow_fx_override = level._effect[ "dog_eye_glow" ];
		self zm::createZombieEyes( localClientNum );
		self mapshaderconstant( localClientNum, 0, "scriptVector2", 0, zm::get_eyeball_on_luminance(), self zm::get_eyeball_color() );
		self.n_trails_fx_id = PlayFxOnTag( localClientNum, level._effect[ "dog_trail_fire" ], self, "j_spine2" );
	}
	else
	{
		self mapshaderconstant( localClientNum, 0, "scriptVector2", 0, zm::get_eyeball_off_luminance(), self zm::get_eyeball_color() );
		self zm::deleteZombieEyes(localClientNum);
		if( isdefined( self.n_trails_fx_id ) )
		{
			DeleteFX( localClientNum, self.n_trails_fx_id );
		}		
	}
}
