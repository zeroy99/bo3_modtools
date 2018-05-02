#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#precache( "client_fx", "weapon/fx_trophy_light_enemy" );

#using_animtree ( "mp_trophy_system" );

#namespace trophy_system;

function init_shared( localClientNum )
{
	clientfield::register( "missile", "trophy_system_state", VERSION_SHIP, 2, "int",&trophy_state_change, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "trophy_system_state", VERSION_SHIP, 2, "int",&trophy_state_change_recon, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}


//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function trophy_state_change( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );

	if ( !isdefined(self) )
		return;
		
	switch( newVal )
	{
		case TROPHY_SYSTEM_ROLLING:
		{
			self thread trophy_rolling_anim( localClientNum );
			break;
		}
		case TROPHY_SYSTEM_STATIONARY:
		{
			self thread trophy_stationary_anim( localClientNum );
			break;
		}
		case TROPHY_SYSTEM_STUNNED:
		{
			break;
		}
		case TROPHY_SYSTEM_INIT:
		{
			break;
		}
	}
}


//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function trophy_state_change_recon( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon("entityshutdown");

	self util::waittill_dobj( localClientNum );

	if ( !isdefined(self) )
		return;
		
	switch( newVal )
	{
		case TROPHY_SYSTEM_ROLLING:
		{
			self thread trophy_rolling_anim( localClientNum );
			break;
		}
		case TROPHY_SYSTEM_STATIONARY:
		{
			self thread trophy_stationary_anim( localClientNum );
			break;
		}
		case TROPHY_SYSTEM_STUNNED:
		{
			break;
		}
		case TROPHY_SYSTEM_INIT:
		{
			break;
		}
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function trophy_rolling_anim( localClientNum )
{
	self endon("entityshutdown");

	self UseAnimTree( #animtree );
	self SetAnim( %o_trophy_deploy, 1.0 );
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function trophy_stationary_anim( localClientNum )
{
	self endon("entityshutdown");

	self UseAnimTree( #animtree );
	self SetAnim( %o_trophy_deploy, 0.0 );
	self SetAnim( %o_trophy_spin, 1.0 );
}
