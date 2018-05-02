#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "zombie/fx_weapon_box_open_glow_zmb" );
#precache( "client_fx", "zombie/fx_weapon_box_closed_glow_zmb" );


#namespace zm_magicbox;
REGISTER_SYSTEM( "zm_magicbox", &__init__, undefined )

function __init__()
{
	level._effect["chest_light"] = "zombie/fx_weapon_box_open_glow_zmb"; 
	level._effect["chest_light_closed"] = "zombie/fx_weapon_box_closed_glow_zmb"; 

	// T8 TODO - combine these clientfields 
	clientfield::register( "zbarrier", "magicbox_open_glow", VERSION_SHIP, 1, "int", &magicbox_open_glow_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "zbarrier", "magicbox_closed_glow", VERSION_SHIP, 1, "int", &magicbox_closed_glow_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "zbarrier", "zbarrier_show_sounds", VERSION_SHIP, 1, "counter", &magicbox_show_sounds_callback, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	clientfield::register( "zbarrier", "zbarrier_leave_sounds", VERSION_SHIP, 1, "counter", &magicbox_leave_sounds_callback, CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);	
	
	clientfield::register( "scriptmover", "force_stream", VERSION_TU7, 1, "int", &force_stream_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

}

function force_stream_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		model = self.model; 
		if (isdefined(model))
		{
			thread stream_model_for_time( localClientNum, model, 15 );
			
		}
	}
}

function lock_weapon_model( model )
{
	if ( IsDefined(model) )
	{
		DEFAULT(level.model_locks,[]);
		DEFAULT(level.model_locks[model],0);
		if ( level.model_locks[model] < 1 )
			ForceStreamXModel( model ); //, -1, -1 );
		level.model_locks[model]++;
	}
}

function unlock_weapon_model( model )
{
	if ( IsDefined(model) )
	{
		DEFAULT(level.model_locks,[]);
		DEFAULT(level.model_locks[model],0);
		level.model_locks[model]--;
		if ( level.model_locks[model] < 1 )
			StopForceStreamingXModel( model ); 
	}
}



function stream_model_for_time( localClientNum, model, time )
{
	lock_weapon_model( model );
	wait time;
	unlock_weapon_model( model );
}



function magicbox_show_sounds_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	playsound( localClientNum, "zmb_box_poof_land", self.origin  );
	playsound( localClientNum, "zmb_couch_slam", self.origin  );
	playsound( localClientNum, "zmb_box_poof", self.origin );
}

function magicbox_leave_sounds_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	playsound(localClientNum, "zmb_box_move", self.origin);
	playsound(localClientNum, "zmb_whoosh", self.origin );		
}

function magicbox_open_glow_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self thread magicbox_glow_callback( localClientNum, newVal, level._effect["chest_light"] );
}

function magicbox_closed_glow_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self thread magicbox_glow_callback( localClientNum, newVal, level._effect["chest_light_closed"] );
}

function magicbox_glow_callback( localClientNum, newVal, fx )
{
	DEFAULT( self.glow_obj_array, [] );
	DEFAULT( self.glow_fx_array, [] );

	if ( !isdefined( self.glow_obj_array[localClientNum] ) )
	{
		fx_obj = spawn( localClientNum, self.origin, "script_model" ); 
		fx_obj setmodel( "tag_origin" ); 
		fx_obj.angles = self.angles;
		self.glow_obj_array[localClientNum] = fx_obj;
		WAIT_CLIENT_FRAME;
	}

	self glow_obj_cleanup( localClientNum );
	
	if ( newVal )
	{
		self.glow_fx_array[localClientNum] = PlayFXOnTag( localClientNum, fx, self.glow_obj_array[localClientNum], "tag_origin" );
		self glow_obj_demo_jump_listener( localClientNum );
	}
}


function glow_obj_demo_jump_listener( localClientNum )
{
	self endon( "end_demo_jump_listener" );

	level waittill( "demo_jump" );

	if ( isdefined(self) )
		self glow_obj_cleanup( localClientNum );
}


function glow_obj_cleanup( localClientNum )
{
	if ( isdefined( self.glow_fx_array[localClientNum] ) )
	{
		StopFX( localClientNum, self.glow_fx_array[localClientNum] );
		self.glow_fx_array[localClientNum] = undefined; 
	}
	
	self notify( "end_demo_jump_listener" );
}

