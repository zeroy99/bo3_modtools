#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#using scripts\mp\_shoutcaster;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "ui/fx_koth_marker_blue" );
#precache( "client_fx", "ui/fx_koth_marker_orng" );
#precache( "client_fx", "ui/fx_koth_marker_neutral" );
#precache( "client_fx", "ui/fx_koth_marker_contested" );
#precache( "client_fx", "ui/fx_koth_marker_blue_window" );
#precache( "client_fx", "ui/fx_koth_marker_orng_window" );
#precache( "client_fx", "ui/fx_koth_marker_neutral_window" );
#precache( "client_fx", "ui/fx_koth_marker_contested_window" );
#precache( "client_fx", "ui/fx_koth_marker_white" );
#precache( "client_fx", "ui/fx_koth_marker_white_window" );

#define KS_NEUTRAL 0
#define KS_ALLIES 1
#define KS_AXIS 2
#define KS_CONTESTED 3
	
#define KS_FRIENDLY 1
#define KS_ENEMY 2

function main()
{
	level.current_zone = [];
	level.current_state = [];
	for( i = 0; i < 4; i++ )
	{
		level.current_zone[i] = 0;
		level.current_state[i] = 0;
	}
	
	level.hardPoints = [];
	level.visuals = [];
	level.hardPointFX = [];

	clientfield::register( "world", "hardpoint", VERSION_SHIP,  5, "int",&hardpoint, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "hardpointteam", VERSION_SHIP,  5, "int",&hardpoint_state, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	level.effect_scriptbundles = [];
	
	level.effect_scriptbundles["zoneEdgeMarker"] = struct::get_script_bundle( "teamcolorfx", "teamcolorfx_koth_edge_marker" );
	level.effect_scriptbundles["zoneEdgeMarkerWndw"] = struct::get_script_bundle( "teamcolorfx", "teamcolorfx_koth_edge_marker_window" );

	level._effect["zoneEdgeMarker"] = [];
	level._effect["zoneEdgeMarker"][KS_NEUTRAL] = "ui/fx_koth_marker_neutral";
	level._effect["zoneEdgeMarker"][KS_ALLIES] = "ui/fx_koth_marker_blue";
	level._effect["zoneEdgeMarker"][KS_AXIS] = "ui/fx_koth_marker_orng";
	level._effect["zoneEdgeMarker"][KS_CONTESTED] = "ui/fx_koth_marker_contested";
	
	level._effect["zoneEdgeMarkerWndw"] = [];
	level._effect["zoneEdgeMarkerWndw"][KS_NEUTRAL] = "ui/fx_koth_marker_neutral_window";
	level._effect["zoneEdgeMarkerWndw"][KS_ALLIES] = "ui/fx_koth_marker_blue_window";
	level._effect["zoneEdgeMarkerWndw"][KS_AXIS] = "ui/fx_koth_marker_orng_window";
	level._effect["zoneEdgeMarkerWndw"][KS_CONTESTED] = "ui/fx_koth_marker_contested_window";
}

function get_shoutcaster_fx(local_client_num)
{
	effects = [];
	effects["zoneEdgeMarker"][KS_NEUTRAL] = level._effect["zoneEdgeMarker"][KS_NEUTRAL];
	effects["zoneEdgeMarker"][KS_CONTESTED] = level._effect["zoneEdgeMarker"][KS_CONTESTED];
	effects["zoneEdgeMarkerWndw"][KS_NEUTRAL] = level._effect["zoneEdgeMarkerWndw"][KS_NEUTRAL];	
	effects["zoneEdgeMarkerWndw"][KS_CONTESTED] = level._effect["zoneEdgeMarkerWndw"][KS_CONTESTED];	
	
	if ( GetDvarInt("tu11_programaticallyColoredGameFX") )
	{
		effects["zoneEdgeMarker"][KS_ALLIES] = "ui/fx_koth_marker_white";
		effects["zoneEdgeMarker"][KS_AXIS] = "ui/fx_koth_marker_white";
		effects["zoneEdgeMarkerWndw"][KS_ALLIES] = "ui/fx_koth_marker_white_window";
		effects["zoneEdgeMarkerWndw"][KS_AXIS] = "ui/fx_koth_marker_white_window";
	}
	else
	{	
		caster_effects = [];
		caster_effects["zoneEdgeMarker"]  = shoutcaster::get_color_fx( local_client_num, level.effect_scriptbundles["zoneEdgeMarker"] );
		caster_effects["zoneEdgeMarkerWndw"]  = shoutcaster::get_color_fx( local_client_num, level.effect_scriptbundles["zoneEdgeMarkerWndw"] );

		effects["zoneEdgeMarker"][KS_ALLIES] = caster_effects["zoneEdgeMarker"]["allies"];
		effects["zoneEdgeMarker"][KS_AXIS] = caster_effects["zoneEdgeMarker"]["axis"];
		effects["zoneEdgeMarkerWndw"][KS_ALLIES] = caster_effects["zoneEdgeMarkerWndw"]["allies"];
		effects["zoneEdgeMarkerWndw"][KS_AXIS] = caster_effects["zoneEdgeMarkerWndw"]["axis"];
	}
	
	return effects;
}

function get_fx_state( local_client_num, state, is_shoutcaster )
{
	if ( is_shoutcaster )
		return state;
	
	if ( state == KS_ALLIES  )
	{
		if ( util::friend_not_foe_team( local_client_num, "allies" ) )
			return KS_FRIENDLY;
		else
			return KS_ENEMY;
	}
	else if ( state == KS_AXIS )
	{
		if ( util::friend_not_foe_team( local_client_num, "axis" ) )
			return KS_FRIENDLY;
		else
			return KS_ENEMY;
	}
	
	return state;
}

function get_fx( fx_name, fx_state, effects )
{
	return effects[fx_name][fx_state];
}

function setup_hardpoint_fx( local_client_num, zone_index, state )
{
	effects = [];
	
	if ( shoutcaster::is_shoutcaster_using_team_identity(local_client_num) )
	{
			effects = get_shoutcaster_fx(local_client_num);
	}
	else
	{
		effects["zoneEdgeMarker"] = level._effect["zoneEdgeMarker"];
		effects["zoneEdgeMarkerWndw"] = level._effect["zoneEdgeMarkerWndw"];	
	}
	
	if ( isdefined( level.hardPointFX[local_client_num] ) )
	{
		foreach ( fx in level.hardPointFX[local_client_num] )
		{
			StopFx( local_client_num, fx );
		}
	}
	level.hardPointFX[local_client_num] = [];
	
	if ( zone_index )
	{
		if ( isdefined( level.visuals[zone_index] ) )
		{
			fx_state = get_fx_state( local_client_num, state, shoutcaster::is_shoutcaster(local_client_num)  );
			
			foreach ( visual in level.visuals[zone_index] )
			{
				if ( !isdefined(visual.script_fxid ) )
					continue;
				
				fxid = get_fx( visual.script_fxid, fx_state, effects );
				
				if ( isdefined(visual.angles) )
					forward = AnglesToForward( visual.angles );
				else
					forward = ( 0,0,0 );
				
				fxHandle = PlayFX( local_client_num, fxid, visual.origin, forward );
				level.hardPointFX[local_client_num][level.hardPointFX[local_client_num].size] = fxHandle;
				if ( isdefined( fxHandle ) )
				{
					if ( state == KS_ALLIES  )
					{
						SetFxTeam( local_client_num, fxHandle, "allies" );	
					}
					else if ( state == KS_AXIS  )
					{
						SetFxTeam( local_client_num, fxHandle, "axis" );	
					}
					else
					{
						SetFxTeam( local_client_num, fxHandle, "free" );	
					}
				}
			}
		}
	}
	
	thread watch_for_team_change( local_client_num );
}

function hardpoint(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( level.hardPoints.size == 0 )
	{
		hardpoints = struct::get_array( "koth_zone_center", "targetname" );
		foreach( point in hardpoints )
		{
	   		level.hardPoints[point.script_index] = point;
		}
		
		foreach( point in level.hardPoints )
		{
			level.visuals[point.script_index] = struct::get_array( point.target, "targetname" );
		}
	}
	
	level.current_zone[localClientNum] = newVal;
	level.current_state[localClientNum] = 0;
	
	setup_hardpoint_fx( localClientNum, level.current_zone[localClientNum], level.current_state[localClientNum] );
}

function hardpoint_state(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if ( newVal != level.current_state[localClientNum] )
	{
		level.current_state[localClientNum] = newVal;
		setup_hardpoint_fx( localClientNum, level.current_zone[localClientNum], level.current_state[localClientNum] );
	}
}

function watch_for_team_change( localClientNum )
{
	level notify( "end_team_change_watch" );
	level endon( "end_team_change_watch" );

	level waittill( "team_changed" );
	
	wait(0.05);

	thread setup_hardpoint_fx( localClientNum, level.current_zone[localClientNum], level.current_state[localClientNum] );
}