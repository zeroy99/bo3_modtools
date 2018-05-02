#using scripts\codescripts\struct;

#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\weapons\_flashgrenades;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace empgrenade;
REGISTER_SYSTEM( "empgrenade", &__init__, undefined )		
	
	
function __init__()
{
	clientfield::register( "toplayer", "empd", VERSION_SHIP, 1, "int", &onEmpChanged, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "empd_monitor_distance", VERSION_SHIP, 1, "int", &onEmpMonitorDistanceChanged, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	callback::on_spawned( &on_player_spawned ); // TODO: utilize on_local_player_spawned when it becomes available
}

function onEmpChanged( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	localPlayer = GetLocalPlayer( localClientNum );

	if( newVal == 1 )
	{
		self StartEmpEffects( localPlayer );
	}
	else
	{
		already_distance_monitored = ( localPlayer clientfield::get_to_player( "empd_monitor_distance" ) == 1 );
		if ( !already_distance_monitored )
		{
			self StopEmpEffects( localPlayer, oldVal );
		}
	}
}

function StartEmpEffects( localPlayer, bWasTimeJump = false )
{
	filter::init_filter_tactical( localPlayer );
	
	filter::enable_filter_tactical( localPlayer, FILTER_INDEX_EMP );
	filter::set_filter_tactical_amount( localPlayer, FILTER_INDEX_EMP, 1.0 );
	
	if ( !bWasTimeJump )
		playsound( 0, "mpl_plr_emp_activate", (0,0,0) );

	audio::playloopat( "mpl_plr_emp_looper", (0,0,0) );
}

function StopEmpEffects( localPlayer, oldVal, bWasTimeJump = false )
{
	filter::init_filter_tactical( localPlayer );
	
	filter::disable_filter_tactical( localPlayer, FILTER_INDEX_EMP );
	
	if( oldVal != 0 && !bWasTimeJump )
		playsound( 0, "mpl_plr_emp_deactivate", (0,0,0) );
	
	audio::stoploopat( "mpl_plr_emp_looper", (0,0,0) );
}


function on_player_spawned( localClientNum )
{
	self endon( "disconnect" );
	
	localPlayer = GetLocalPlayer( localClientNum );

	if ( localPlayer != self )
		return;

	curVal = localPlayer clientfield::get_to_player( "empd_monitor_distance" );
	inKillCam = GetInKillcam( localClientNum );
	
	if ( curVal > 0 && localPlayer IsEMPJammed() )
	{
		StartEmpEffects( localPlayer, inKillCam ); // only start sound if we are not in killcam
		localPlayer MonitorDistance( localClientNum );	
	}
	else
	{
		StopEmpEffects( localPlayer, 0, true );	// never play the turn off sound when spawning in
		localPlayer notify( "end_emp_monitor_distance" );		
	}
}

function onEmpMonitorDistanceChanged( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	localPlayer = GetLocalPlayer( localClientNum );

	if ( newVal == 1 )
	{
		StartEmpEffects( localPlayer, bWasTimeJump );
		localPlayer MonitorDistance( localClientNum );
	}
	else
	{	
		StopEmpEffects( localPlayer, oldVal, bWasTimeJump );		
		localPlayer notify( "end_emp_monitor_distance" );
	}
}

function MonitorDistance( localClientNum )
{
	localPlayer = self;

	localPlayer endon( "entityshutdown" );
	localPlayer endon( "end_emp_monitor_distance" );
	localPlayer endon( "team_changed" );

	if ( localPlayer IsEMPJammed() == false )
		return;

	distance_to_closest_enemy_emp_ui_model = GetUIModel( GetUIModelForController( localClientNum ), "distanceToClosestEnemyEmpKillstreak" );

	new_distance = 0.0;
	
	max_static_value = GetDvarFloat( "ks_emp_fullscreen_maxStaticValue" );
	min_static_value = GetDvarFloat( "ks_emp_fullscreen_minStaticValue" );
	min_radius_max_static = GetDvarFloat( "ks_emp_fullscreen_minRadiusMaxStatic" );
	max_radius_min_static = GetDvarFloat( "ks_emp_fullscreen_maxRadiusMinStatic" );
			
	if ( isdefined( distance_to_closest_enemy_emp_ui_model ) )
	{
		while( true )
		{

			// calculate effect factor based on distance
			new_distance = GetUIModelValue( distance_to_closest_enemy_emp_ui_model );
			range = max_radius_min_static - min_radius_max_static;
			current_static_value = max_static_value - ( ( range <= 0.0 ) ? max_static_value : ( ( new_distance - min_radius_max_static ) / range ) );
			current_static_value = math::clamp( current_static_value, min_static_value, max_static_value );
				
			// emp grenaded has full screen effect
			emp_grenaded = ( localPlayer clientfield::get_to_player( "empd" ) == 1 );
			if ( emp_grenaded && current_static_value < 1.0 )
			{
				current_static_value = 1.0;
			}

			// update filter effects
			filter::set_filter_tactical_amount( localPlayer, FILTER_INDEX_EMP, current_static_value );

			wait 0.1;
		}
	}
}
