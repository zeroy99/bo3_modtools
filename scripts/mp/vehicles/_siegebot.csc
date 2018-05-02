#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\callbacks_shared;

#using scripts\shared\weapons\spike_charge_siegebot;

#namespace siegebot;

REGISTER_SYSTEM( "siegebot_mp", &__init__, undefined )

#using_animtree( "generic" );
	
function __init__()
{
	vehicle::add_vehicletype_callback( "siegebot_mp", &_setup_ );
	
	clientfield::register( "vehicle", "siegebot_retract_right_arm", VERSION_SHIP, 1, "int", &update_right_arm, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "siegebot_retract_left_arm", VERSION_SHIP, 1, "int", &update_left_arm, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function _setup_( localClientNum )
{
	if( isdefined( self.scriptbundlesettings ) )
	{
		settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}

	if ( !isdefined( settings ) )
	{
		return;
	}

	self thread player_enter_exit( localClientNum );
}

function player_enter_exit( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	player = undefined;

	while( 1 )
	{
		// perform exit steps here
		self player_exited( localClientNum, player );
		
		self waittill( "enter_vehicle", player );
		
		self player_entered( localClientNum, player );
		
		self waittill( "exit_vehicle", player );
	}
}

function player_entered( localClientNum, player )
{
	self playsound( localClientNum, "evt_siegebot_bootup_1" );
	
	local_player = GetLocalPlayer( localClientNum );

	if( self IsLocalClientDriver( localClientNum ) )
	{
		//self SetHighDetail( true );
	}
}

function player_exited( localClientNum, player )
{
	self playsound( localClientNum, "evt_siegebot_shutdown_1" );
	
	if( self IsLocalClientDriver( localClientNum ) )
	{
		//self SetHighDetail( false );
	}
}
	
function retract_left_arm()
{
	self UseAnimTree( #animtree );

	self ClearAnim( %ai_siegebot_base_mp_left_arm_extend, 0.2 );	
	self SetAnim( %ai_siegebot_base_mp_left_arm_retract, 1.0 );	
}

function extend_left_arm()
{
	self UseAnimTree( #animtree );

	self ClearAnim( %ai_siegebot_base_mp_left_arm_retract, 0.2 );
	self SetAnim( %ai_siegebot_base_mp_left_arm_extend, 1.0 );
	
	wait 0.1;

	if ( self clientfield::get( "siegebot_retract_left_arm" ) == 0 )
		self ClearAnim( %ai_siegebot_base_mp_left_arm_extend, 0.1 );	
}

function retract_right_arm()
{
	self UseAnimTree( #animtree );

	self ClearAnim( %ai_siegebot_base_mp_right_arm_extend, 0.2 );
	self SetAnim( %ai_siegebot_base_mp_right_arm_retract, 1.0 );	
}

function extend_right_arm()
{
	self UseAnimTree( #animtree );

	self ClearAnim( %ai_siegebot_base_mp_right_arm_retract, 0.2 );
	self SetAnim( %ai_siegebot_base_mp_right_arm_extend, 1.0 );
	
	wait 0.1;
	
	if ( self clientfield::get( "siegebot_retract_right_arm" ) == 0 )
		self ClearAnim( %ai_siegebot_base_mp_right_arm_extend, 0.1 );
}


function update_right_arm( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump  )
{
	self util::waittill_dobj( localClientNum );
	
	if ( !isdefined(self) )
		return;
	
	if ( newVal )
	{
		self thread retract_right_arm();
	}
	else
	{
		self thread extend_right_arm(); 
	}
}

function update_left_arm( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self util::waittill_dobj( localClientNum );
	
	if ( !isdefined(self) )
		return;
	
	if ( newVal )
	{
		self thread retract_left_arm();
	}
	else
	{
		self thread extend_left_arm();
	}
}