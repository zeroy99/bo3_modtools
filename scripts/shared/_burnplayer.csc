#using scripts\codescripts\struct;

#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace burnplayer;

REGISTER_SYSTEM( "burnplayer", &__init__, undefined )

// human burning effects
#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_arm_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_hip_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_left_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_left_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_right_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_leg_right_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_torso_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_torso_os" );
#precache( "client_fx", "fire/fx_fire_ai_human_head_loop" );
#precache( "client_fx", "fire/fx_fire_ai_human_head_os" );

function __init__()
{
	clientfield::register( "allplayers", "burn", VERSION_SHIP, 1, "int", &burning_callback, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "playercorpse", "burned_effect", VERSION_SHIP, 1, "int", &burning_corpse_callback, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	LoadEffects();
	callback::on_localplayer_spawned( &on_localplayer_spawned );
	callback::on_localclient_connect( &on_local_client_connect );
}


function LoadEffects()
{
	//fire fx
	level._effect["burn_j_elbow_le_loop"]		= "fire/fx_fire_ai_human_arm_left_loop";	// hand and forearm fires
	level._effect["burn_j_elbow_ri_loop"]		= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["burn_j_shoulder_le_loop"]	= "fire/fx_fire_ai_human_arm_left_loop";	// upper arm fires
	level._effect["burn_j_shoulder_ri_loop"]	= "fire/fx_fire_ai_human_arm_right_loop";
	level._effect["burn_j_spine4_loop"]			= "fire/fx_fire_ai_human_torso_loop";		// upper torso fires
	level._effect["burn_j_hip_le_loop"]			= "fire/fx_fire_ai_human_hip_left_loop";	// thigh fires
	level._effect["burn_j_hip_ri_loop"]			= "fire/fx_fire_ai_human_hip_right_loop";
	level._effect["burn_j_knee_le_loop"]		= "fire/fx_fire_ai_human_leg_left_loop";	// shin fires
	level._effect["burn_j_knee_ri_loop"]		= "fire/fx_fire_ai_human_leg_right_loop";
	level._effect["burn_j_head_loop"] 			= "fire/fx_fire_ai_human_head_loop";		// head fire

	level._effect["burn_j_elbow_le_os"]			= "fire/fx_fire_ai_human_arm_left_os";		// hand and forearm fires
	level._effect["burn_j_elbow_ri_os"]			= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["burn_j_shoulder_le_os"]		= "fire/fx_fire_ai_human_arm_left_os";		// upper arm fires
	level._effect["burn_j_shoulder_ri_os"]		= "fire/fx_fire_ai_human_arm_right_os";
	level._effect["burn_j_spine4_os"]			= "fire/fx_fire_ai_human_torso_os";			// upper torso fires
	level._effect["burn_j_hip_le_os"]			= "fire/fx_fire_ai_human_hip_left_os";		// thigh fire
	level._effect["burn_j_hip_ri_os"]			= "fire/fx_fire_ai_human_hip_right_os";
	level._effect["burn_j_knee_le_os"]			= "fire/fx_fire_ai_human_leg_left_os";		// shin fires
	level._effect["burn_j_knee_ri_os"]			= "fire/fx_fire_ai_human_leg_right_os";
	level._effect["burn_j_head_os"] 			= "fire/fx_fire_ai_human_head_os";			// head fire
	
	level.burnTags = array("j_elbow_le", "j_elbow_ri", "j_shoulder_le", "j_shoulder_ri", "j_spine4", "j_spinelower", "j_hip_le", "j_hip_ri", "j_head", "j_knee_le", "j_knee_ri" );
}

function on_local_client_connect( localClientNum )
{
	RegisterRewindFX( localClientNum, level._effect["burn_j_elbow_le_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_elbow_ri_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_shoulder_le_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_shoulder_ri_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_spine4_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_hip_le_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_hip_ri_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_knee_le_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_knee_ri_loop"]);
	RegisterRewindFX( localClientNum, level._effect["burn_j_head_loop"]);
}

function on_localplayer_spawned( localClientNum )
{

}

function burning_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self burn_on( localClientNum );
	}
	else
	{
		self burn_off( localClientNum );
	}
}

function burning_corpse_callback( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self set_corpse_burning( localClientNum );
	}
	else
	{
		self burn_off( localClientNum );
	}
}

function set_corpse_burning( localClientNum )
{
	self thread _burnBody( localClientNum );
}

function burn_off( localClientNum )
{
	self notify( "burn_off" );
	
	if( GetLocalPlayer( localClientNum ) == self )
	{
		self postfx::exitPostfxBundle();
	}
}

function burn_on( localClientNum )
{
	if( GetLocalPlayer( localClientNum ) != self || IsThirdPerson( localClientNum ) )
	{
		self thread _burnBody( localClientNum );
	}
	
	if( GetLocalPlayer( localClientNum ) == self && !IsThirdPerson( localClientNum ) )
	{
		self thread burn_on_postfx();
	}
}

function burn_on_postfx()
{
	self endon( "entityshutdown" );
	self endon( "burn_off" );
	self endon( "death" );
	self notify( "burn_on_postfx" );
	self endon( "burn_on_postfx" );
	
	self thread postfx::PlayPostfxBundle( "pstfx_burn_loop" );
}

function private _burnTag( localClientNum, tag, postfix )
{
	if( isDefined( self ) && self hasdobj( localclientnum ) )
	{
		fxname = "burn_" + tag + postfix;
		if( isDefined( level._effect[fxname] ) )
		{
			return PlayFXOnTag( localClientNum, level._effect[fxname], self, tag );
		}
	}
}

function private _burnTagsOn( localClientNum, tags )
{
	if( !isDefined( self ) )
		return;
		
	self endon( "entityshutdown" );
	self endon( "burn_off" );
	self notify( "burn_tags_on" );
	self endon( "burn_tags_on" );

	activeFx = [];
	for( i = 0; i < tags.size; i++ )
	{
		activeFx[activeFx.size] = self _burnTag( localClientNum, tags[i], "_loop" );
	}
	
	burnSound  = self playloopsound( "chr_burn_loop_overlay", .5);
	
	self thread _burnTagsWatchEnd( localClientNum, activeFx, burnSound );
	self thread _burnTagsWatchClear( localClientNum, activeFx, burnSound );
}

function private _burnBody(localClientNum)
{
	self endon("entityshutdown");
		
	self thread _burnTagsOn( localClientNum, level.burnTags );
}

function private _burnTagsWatchEnd( localClientNum, fxArray, burnSound )
{
	self endon ( "entityshutdown" );
	
	self waittill( "burn_off" );
	
	if( isdefined( burnSound ) )
	{
    	self stoploopsound( burnSound, 1 );
	}
	
	if( isDefined( fxArray ) )
	{
		foreach( fx in fxArray )
		{
			StopFx( localClientNum, fx );
		}
	}
}

function private _burnTagsWatchClear( localClientNum, fxArray, burnSound )
{
	self endon( "burn_off" ); 
	self waittill( "entityshutdown" );
	
	if( isdefined( burnSound ) )
	{
    	stopsound( burnSound );
	}
	
	if( isDefined( fxArray ) )
	{
		foreach( fx in fxArray )
		{
			StopFx( localClientNum, fx );
		}
	}
}