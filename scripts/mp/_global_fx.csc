#using scripts\codescripts\struct;

#using scripts\shared\fx_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace global_fx;

REGISTER_SYSTEM_EX( "global_fx", &__init__, &main, undefined )

function __init__()
{
	wind_initial_setting();
}

function main()
{
	check_for_wind_override();
}

function wind_initial_setting()
{
	SetSavedDvar( "enable_global_wind", 0 );					// enable wind for your level
	SetSavedDvar( "wind_global_vector", "0 0 0" );				// change "0 0 0" to your wind vector
	SetSavedDvar( "wind_global_low_altitude", 0 );				// change 0 to your wind's lower bound
	SetSavedDvar( "wind_global_hi_altitude", 10000 );			// change 10000 to your wind's upper bound
	SetSavedDvar( "wind_global_low_strength_percent", 0.5 );	// change 0.5 to your desired wind strength percentage
}

function check_for_wind_override()
{
	//Allow for level overrides of global wind settings
	if( isdefined( level.custom_wind_callback ) )
	{
		level thread [[level.custom_wind_callback]]();
	}
}
	
