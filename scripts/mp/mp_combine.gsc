#using scripts\codescripts\struct;

#using scripts\shared\compass;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_load;
#using scripts\mp\_util;

#using scripts\mp\mp_combine_fx;
#using scripts\mp\mp_combine_sound;

#precache( "model", "collision_clip_wall_128x128x10" );

function main()
{
	precache();
	
	mp_combine_fx::main();
	mp_combine_sound::main();
	
	level.add_raps_omit_locations = &add_raps_omit_locations;
	level.add_raps_drop_locations = &add_raps_drop_locations;

	level.remotemissile_kill_z = -680;
	
	load::main();

	SetDvar( "compassmaxrange", "2100" );	// Set up the default range of the compass

    compass::setupMiniMap("compass_map_mp_combine");
    
    link_traversals( "under_bridge", "targetname", true );
    
	//Spawning clip on roof near wall run side to prevent players from sitting on roof and shooting over middle bridge
	spawncollision("collision_clip_wall_128x128x10","collider",( 597.185 , -523.817 , 584.206 ), ( -5 , 90 , 0));
	
	level spawnKillTrigger();

	// Stockpile hub points
	level.cleanDepositPoints = Array ( ( 0 , 176.894 , 174.868 ),
                                  ( 715.139 , 1279.47 , 158.417 ),
                                  ( -825.34 , 171.066 , 106.517 ),
                                  ( -108.124 , -751.785 , 154.839 ),
                                  ( 1102.93 , 179.261 , 202.119 ) );
}

function link_traversals( str_value, str_key, b_enable )
{
	a_nodes = GetNodeArray( str_value, str_key );
	
	foreach ( node in a_nodes )
	{
		if ( b_enable )
		{
			LinkTraversal( node );
		}
		else 
		{
			UnlinkTraversal( node );
		}
	}
}

function precache()
{
	// DO ALL PRECACHING HERE
}

function add_raps_omit_locations( &omit_locations )
{
	ARRAY_ADD( omit_locations, ( 32, 710, 189 ) ); // omitting any points near west side of center bridge; there is a bad physics triangle blocking raps
	ARRAY_ADD( omit_locations, ( -960, 1020, 168 ) ); // omitting auto generated point near the entrance near "ZONE 2" sign, adding a better one below
}

function add_raps_drop_locations( &drop_candidate_array )
{
	ARRAY_ADD( drop_candidate_array, ( -1100, 860, 145 ) ); // near big "ZONE 2" sign, by a green top machine
	ARRAY_ADD( drop_candidate_array, ( 0, 520, 163 ) ); // west of the center bridge
}

function spawnKillTrigger()
{
	trigger = spawn( "trigger_radius", ( -480.116 , 3217.5 , 119.108 ), 0, 150, 200 );
	trigger thread watchKillTrigger();
	
	trigger = spawn( "trigger_radius", ( -480.115 , 3309.66 , 119.108 ), 0, 150, 200 );
	trigger thread watchKillTrigger();
}

 function watchKillTrigger()
{
	level endon( "game_ended" );
	
 	trigger = self;
	
 	while(1)
	{
		trigger waittill( "trigger", player );
		player DoDamage(1000, trigger.origin + (0, 0, 0), trigger, trigger, "none", "MOD_SUICIDE", 0 );
	}
}