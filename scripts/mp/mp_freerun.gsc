#using scripts\codescripts\struct;
#using scripts\shared\compass;
#using scripts\shared\util_shared;
#using scripts\mp\_load;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\shared.gsh;

function main()
{
	precache();
	
	load::main();

	compass::setupMiniMap("compass_map_mp_freerun");
	SetDvar( "compassmaxrange", "2100" );	// Set up the default range of the compass
	
	init();
}

function precache()
{
	// DO ALL PRECACHING HERE
}

function init()
{
}

// OLD STUFF ======================================================================================================

//Used in the map to test the speed of the player
function speed_test_init()
{
	trigger1 = GetEnt( "speed_trigger1","targetname" );
	trigger2 = GetEnt( "speed_trigger2","targetname" );
	trigger3 = GetEnt( "speed_trigger3","targetname" );
	trigger4 = GetEnt( "speed_trigger4","targetname" );
	trigger5 = GetEnt( "speed_trigger5","targetname" );
	trigger6 = GetEnt( "speed_trigger6","targetname" );
		
	trigger1 thread speed_test();
	trigger2 thread speed_test();	
	trigger3 thread speed_test();
	trigger4 thread speed_test();
	trigger5 thread speed_test();
	trigger6 thread speed_test();		
}

function speed_test()
{
	while( 1 )
	{	
		self waittill( "trigger", player );

		if( IsPlayer( player ) )
		{
			//Trigger thread runs one function when the player enters a trigger and the other on exit
			self thread util::trigger_thread( player, &player_on_trigger, &player_off_trigger );
		}

		wait .05;
	}	
}

//If the player has exited a speed trigger, compare that time to when the player entered a speed trigger
function player_on_trigger( player, endon_string )
{
	player endon ( "death" );
	player endon ( "disconnect" );
	player endon( endon_string );

	if( IsDefined( player._speed_test2 ))
	{
		player._speed_test1 = gettime();
		total_time = player._speed_test1 - player._speed_test2;
		IPrintLnBold( "" + ( total_time/1000 ) + "seconds" );
		player._speed_test2 = undefined;
	}
}

//Grab the time when the player exited a speed trigger
function player_off_trigger( player )
{
	player endon ( "death" );
	player endon ( "disconnect" );

	player._speed_test2 = gettime();
	
	if( IsDefined( player._speed_test1 ))
	{
		player._speed_test1 = undefined;
	}

}