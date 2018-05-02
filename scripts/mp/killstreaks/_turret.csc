#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;

#using_animtree( "mp_autoturret" );

#namespace autoturret;

REGISTER_SYSTEM( "autoturret", &__init__, undefined )

function __init__()
{
	clientfield::register( "vehicle", "auto_turret_open", VERSION_SHIP, 1, "int", &turret_open, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "auto_turret_init", VERSION_SHIP, 1, "int", &turret_init_anim, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "auto_turret_close", VERSION_SHIP, 1, "int", &turret_close_anim, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	visionset_mgr::register_visionset_info( TURRET_VISIONSET_ALIAS, VERSION_SHIP, TURRET_VISIONSET_LERP_STEP_COUNT, undefined, TURRET_VISIONSET_FILE );
}

function turret_init_anim( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;
	
	self UseAnimTree( #animtree );
	self SetAnimRestart( %o_turret_sentry_close, 1.0, 0.0, 1.0 );
	self SetAnimTime( %o_turret_sentry_close, 1.0 );
}

function turret_open( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;

	self UseAnimTree( #animtree );
	self SetAnimRestart( %o_turret_sentry_deploy, 1.0, 0.0, 1.0 );
}

function turret_close_anim( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;

	self UseAnimTree( #animtree );
	self SetAnimRestart( %o_turret_sentry_close, 1.0, 0.0, 1.0 );
}
