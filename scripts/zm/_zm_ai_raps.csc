
#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\vehicle_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_ai_raps.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;

#namespace zm_ai_raps;

// elemental round fx
#precache( "client_fx", "zombie/fx_meatball_round_tell_zod_zmb" );

REGISTER_SYSTEM( "zm_ai_raps", &__init__, undefined )
	
function __init__()
{
	clientfield::register( "toplayer", "elemental_round_fx", VERSION_SHIP, 1, "counter", &elemental_round_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "toplayer", ELEMENTAL_ROUND_RING_FX, VERSION_SHIP, 1, "counter", &elemental_round_ring_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	visionset_mgr::register_visionset_info( ZM_ELEMENTAL_ROUND_VISIONSET, VERSION_SHIP, ZM_ELEMENTAL_VISION_LERP_COUNT, undefined, ZM_ELEMENTAL_ROUND_VISION_FILE );

	// elemental round fx
	level._effect[ "elemental_round" ]	= "zombie/fx_meatball_round_tell_zod_zmb";
	
	vehicle::add_vehicletype_callback( "raps", &_setup_ );
}

function _setup_( localClientNum )
{
	//set code field to get notifies to play impact effects
	self.notifyOnBulletImpact = true;
	self thread wait_for_bullet_impact( localClientNum );
	//kick off the elemental animation
	self SetAnim( ZM_ELEMENTAL_LOOPING_ANIM, 1.0 );

	if( IS_TRUE(level.debug_keyline_zombies) )
	{
		self duplicate_render::set_dr_flag( "keyline_active", 1 );
		self duplicate_render::update_dr_filters(localClientNum);
	}
}

function elemental_round_fx( n_local_client, n_val_old, n_val_new, b_ent_new, b_initial_snap, str_field, b_demo_jump )
{
	self endon( "disconnect" );

	if ( IsSpectating( n_local_client ) )
		return; 
	
	self.n_elemental_round_fx_id = PlayFXOnCamera( n_local_client, level._effect[ "elemental_round" ] );
		
	wait 3.5; // the time it takes to play the fx
		
	DeleteFX( n_local_client, self.n_elemental_round_fx_id );
}

function elemental_round_ring_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "disconnect" );

	if ( IsSpectating( localClientNum ) )
		return; 
	
	self thread postfx::playPostFxBundle( "pstfx_ring_loop" );
	wait( ZM_ELEMENTAL_RING_LOOP_DURATION );
	self postfx::exitPostfxBundle();
}

function wait_for_bullet_impact( localClientNum )
{
	self endon( "entityshutdown" );
	
	if( isdefined( self.scriptbundlesettings ) )
	{
		settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}
	else
	{
		return;
	}
	
	while( 1 )
	{
		self waittill( "damage", attacker, impactPos, effectDir, partname );
		PlayFx( localClientNum, settings.weakspotfx, impactPos, effectDir );
	}
}