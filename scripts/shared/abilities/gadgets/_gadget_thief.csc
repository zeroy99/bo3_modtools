#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace gadget_thief;

REGISTER_SYSTEM( "gadget_thief", &__init__, undefined )

#precache( "client_fx", "weapon/fx_hero_blackjack_beam_source" );
#precache( "client_fx", "weapon/fx_hero_blackjack_beam_target" );

function __init__()
{
	clientfield::register( "scriptmover", "gadget_thief_fx", VERSION_TU11, 1, "int", &thief_clientfield_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "thief_state", VERSION_TU11, 2, "int", &thief_ui_model_clientfield_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "thief_weapon_option", VERSION_TU11, 4, "int", &thief_weapon_option_ui_model_clientfield_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "clientuimodel", "playerAbilities.playerGadget3.flashStart", VERSION_TU11, 3, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "playerAbilities.playerGadget3.flashEnd", VERSION_TU11, 3, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	level._effect["fx_hero_blackjack_beam_source"] = "weapon/fx_hero_blackjack_beam_source";
	level._effect["fx_hero_blackjack_beam_target"] = "weapon/fx_hero_blackjack_beam_target";
	
	callback::on_localplayer_spawned( &on_localplayer_spawned );
}

function thief_clientfield_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "entityshutdown" );
	
	playfxoncamera( localclientnum, level._effect["fx_hero_blackjack_beam_target"], (0,0,0), (1,0,0), (0,0,1)  );
	playfx( localclientnum, level._effect["fx_hero_blackjack_beam_source"], self.origin );
}

function thief_ui_model_clientfield_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	update_thief( localClientNum, newVal );
}

function thief_weapon_option_ui_model_clientfield_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	update_thief_weapon( localClientNum, newVal );
}

function update_thief( localClientNum, newVal )
{
	controllerModel = GetUIModelForController( localClientNum );
	if ( isdefined( controllerModel ) )
	{
		thiefStatusModel = GetUIModel( controllerModel, "playerAbilities.playerGadget3.thiefStatus" );
		if ( isdefined( thiefStatusModel ) )
		{
			SetUIModelValue( thiefStatusModel, newVal );
		}
	}
}

function update_thief_weapon( localClientNum, newVal )
{
	controllerModel = GetUIModelForController( localClientNum );
	if ( isdefined( controllerModel ) )
	{
		thiefStatusModel = GetUIModel( controllerModel, "playerAbilities.playerGadget3.thiefWeaponStatus" );
		if ( isdefined( thiefStatusModel ) )
		{
			SetUIModelValue( thiefStatusModel, newVal );
		}
	}
}

function on_localplayer_spawned( localClientNum )
{
	thief_state = 0;
	thief_weapon_option = 0;

	if ( getserverhighestclientfieldversion() >= VERSION_TU11 ) 
	{
		thief_state = self clientfield::get_to_player( "thief_state" );
		thief_weapon_option = self clientfield::get_to_player( "thief_weapon_option" );
	}

	
	update_thief( localClientNum, thief_state );
	update_thief_weapon( localClientNum, thief_weapon_option );
}
