#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#namespace gadget_roulette;

REGISTER_SYSTEM( "gadget_roulette", &__init__, undefined )

function __init__()
{
	clientfield::register( "toplayer", "roulette_state", VERSION_TU11, 2, "int", &roulette_clientfield_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	callback::on_localplayer_spawned( &on_localplayer_spawned );
}


function roulette_clientfield_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	update_roulette( localClientNum, newVal );
}

function update_roulette( localClientNum, newVal )
{		
	controllerModel = GetUIModelForController( localClientNum );
	if ( isdefined( controllerModel ) )
	{
		rouletteStatusModel = GetUIModel( controllerModel, "playerAbilities.playerGadget3.rouletteStatus" );
		if ( isdefined( rouletteStatusModel ) )
		{
			SetUIModelValue( rouletteStatusModel, newVal );
		}
	}
}

function on_localplayer_spawned( localClientNum )
{
	roulette_state = 0;

	if ( getserverhighestclientfieldversion() >= VERSION_TU11 ) 
	{
		roulette_state = self clientfield::get_to_player( "roulette_state" );
	}
	
	update_roulette( localClientNum, roulette_state );
}

