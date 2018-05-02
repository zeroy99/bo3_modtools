
#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\postfx_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_ai_wasp.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;

#namespace zm_ai_wasp;

// parasite round fx
#precache( "client_fx", "zombie/fx_parasite_round_tell_zod_zmb" );

REGISTER_SYSTEM( "zm_ai_wasp", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "toplayer", "parasite_round_fx", VERSION_SHIP, 1, "counter", &parasite_round_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "world", "toggle_on_parasite_fog", VERSION_SHIP, 2, "int", &parasite_fog_on, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "toplayer", PARASITE_ROUND_RING_FX, VERSION_SHIP, 1, "counter", &parasite_round_ring_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	visionset_mgr::register_visionset_info( ZM_WASP_ROUND_VISIONSET, VERSION_SHIP, ZM_WASP_VISION_LERP_COUNT, undefined, ZM_WASP_ROUND_VISION_FILE );
	// parasite round fx
	level._effect[ "parasite_round" ]	= "zombie/fx_parasite_round_tell_zod_zmb";
}

function parasite_fog_on( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//turn on parasite.
	if ( newVal == 1 )
	{
		for ( localClientNum = 0; localClientNum < level.localPlayers.size; localClientNum++ )
		{
			SetLitFogBank( localClientNum, -1, 1, -1 );
			SetWorldFogActiveBank( localClientNum, 2 );
		}
	}
	
	//turn off parasite.
	if ( newVal == 2 )
	{
		for ( localClientNum = 0; localClientNum < level.localPlayers.size; localClientNum++ )
		{
			SetLitFogBank( localClientNum, -1, 0, -1 );
			SetWorldFogActiveBank( localClientNum, 1 );	
		}
	}
}

function parasite_round_fx( n_local_client, n_val_old, n_val_new, b_ent_new, b_initial_snap, str_field, b_demo_jump )
{
	self endon( "disconnect" );
	self endon( "death" );

	if ( IsSpectating( n_local_client ) )
		return; 
	
	self.n_parasite_round_fx_id = PlayFXOnCamera( n_local_client, level._effect[ "parasite_round" ] );
		
	wait 3.5; // the time it takes to play the fx
		
	DeleteFX( n_local_client, self.n_parasite_round_fx_id );
}

function parasite_round_ring_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "disconnect" );

	if ( IsSpectating( localClientNum ) )
		return; 
	
	self thread postfx::playPostFxBundle( "pstfx_ring_loop" );
	wait( ZM_WASP_RING_LOOP_DURATION );
	self postfx::exitPostfxBundle();
}