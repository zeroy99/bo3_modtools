#using scripts\shared\system_shared;
#using scripts\shared\vehicle_shared;

#insert scripts\shared\shared.gsh;

#define ANIMTREE	"generic"

#namespace civ_pickup;

REGISTER_SYSTEM( "civ_pickup", &__init__, undefined )
	
function __init__()
{
	vehicle::add_main_callback( "civ_pickup",&main );
}

function main()
{
//	if( IsSubStr( self.vehicletype, "wturret" ) )
//	{
//		vehicle::build_ai_anims(&set_50cal_gunner_anims ,&set_50cal_vehicle_anims );
//	}	
//	else
//	{
//		vehicle::build_ai_anims(&setanims ,&set_vehicle_anims );
//	}
//
//	vehicle::build_unload_groups(&unload_groups );
}

#using_animtree( ANIMTREE );
function set_50cal_vehicle_anims( positions )
{
	positions[ 0 ].sittag = "tag_driver";
	positions[ 1 ].sittag = "tag_passenger";	 
	positions[ 2 ].sittag = "tag_gunner1";
	
	positions[ 0 ].vehicle_getoutanim_clear = true;
	positions[ 1 ].vehicle_getoutanim_clear = true;
	
	positions[ 0 ].vehicle_getinanim = %v_crew_pickup_truck_driver_door_enter;
	
	positions[ 0 ].vehicle_getoutanim = %v_crew_pickup_truck_left_frontdoor_open;
	positions[ 1 ].vehicle_getoutanim = %v_crew_pickup_truck_right_frontdoor_open;

	return positions;
}


#using_animtree( ANIMTREE );
function set_50cal_gunner_anims()
{
	positions = [];
	const num_positions = 3;
	
	for( i = 0; i < num_positions; i++ )
	{
		positions[ i ] = spawnstruct();
	}
	
	positions[0].sittag = "tag_driver";
	positions[1].sittag = "tag_passenger";	
	positions[2].sittag = "tag_gunner1";
	positions[2].vehiclegunner = 1;
	/*positions[2].idle = %ai_50cal_gunner_aim;//TODO T7 - need to get added into animtree
	positions[2].aimup = %ai_50cal_gunner_aim_up;
	positions[2].aimdown = %ai_50cal_gunner_aim_down;
	positions[2].fire 	 = %ai_50cal_gunner_fire;
	positions[2].fireup  = %ai_50cal_gunner_fire_up;
	positions[2].firedown = %ai_50cal_gunner_fire_down;
	positions[2].stunned = %ai_50cal_gunner_stunned;
	
	positions[ 0 ].getin = %ai_crew_pickup_truck_driver_enter;
	
	positions[ 0 ].getout = %ai_crew_pickup_truck_driver_exit;
	positions[ 1 ].getout = %ai_crew_pickup_truck_passenger_exit;
	
	positions[ 0 ].idle = %ai_crew_pickup_truck_driver_idle;
	positions[ 1 ].idle = %ai_crew_pickup_truck_passenger_idle;*/
	
	return positions;
}

#using_animtree (ANIMTREE);
function set_vehicle_anims(positions)
{
	positions[ 0 ].sittag = "tag_driver";
	positions[ 1 ].sittag = "tag_passenger";	 
	positions[ 2 ].sittag = "tag_passenger1";
	positions[ 3 ].sittag = "tag_passenger2";
	positions[ 4 ].sittag = "tag_passenger3";
	positions[ 5 ].sittag = "tag_passenger4";

	positions[ 0 ].vehicle_getoutanim_clear = true;
	positions[ 1 ].vehicle_getoutanim_clear = true;
	//TODO T7 - need to get added into animtree
	/*positions[ 0 ].vehicle_getinanim = %v_crew_pickup_truck_driver_door_enter;
	
	positions[ 0 ].vehicle_getoutanim = %v_crew_pickup_truck_left_frontdoor_open;
	positions[ 1 ].vehicle_getoutanim = %v_crew_pickup_truck_right_frontdoor_open;*/

	return positions;
}

#using_animtree (ANIMTREE);
function setanims ()
{
	positions = [];
	const num_positions = 6;
	
	for( i = 0; i < num_positions; i++ )
	{
		positions[ i ] = spawnstruct();
	}

	positions[ 0 ].sittag = "tag_driver";
	positions[ 1 ].sittag = "tag_passenger";	 
	positions[ 2 ].sittag = "tag_passenger1";
	positions[ 3 ].sittag = "tag_passenger2";
	positions[ 4 ].sittag = "tag_passenger3";
	positions[ 5 ].sittag = "tag_passenger4";
  	//TODO T7 - need to get added into animtree
	/*positions[ 0 ].getin = %ai_crew_pickup_truck_driver_enter;
	
	positions[ 0 ].getout = %ai_crew_pickup_truck_driver_exit;
	positions[ 1 ].getout = %ai_crew_pickup_truck_passenger_exit;
	positions[ 2 ].getout = %ai_crew_pickup_truck_passenger1_exit;
	positions[ 3 ].getout = %ai_crew_pickup_truck_passenger2_exit;
	positions[ 4 ].getout = %ai_crew_pickup_truck_passenger3_exit;
	positions[ 5 ].getout = %ai_crew_pickup_truck_passenger4_exit;
	
	positions[ 0 ].idle = %ai_crew_pickup_truck_driver_idle;
	positions[ 1 ].idle = %ai_crew_pickup_truck_passenger_idle;
	positions[ 2 ].idle = %ai_crew_pickup_truck_passenger1_idle;
	positions[ 3 ].idle = %ai_crew_pickup_truck_passenger2_idle;
	positions[ 4 ].idle = %ai_crew_pickup_truck_passenger3_idle;
	positions[ 5 ].idle = %ai_crew_pickup_truck_passenger4_idle;*/

	return positions;
}

function unload_groups()
{
	unload_groups = [];
	unload_groups[ "all" ] = [];
	
	group = "all";
	unload_groups[ group ][ unload_groups[ group ].size ] = 0;
	unload_groups[ group ][ unload_groups[ group ].size ] = 1;
	unload_groups[ group ][ unload_groups[ group ].size ] = 2;
	unload_groups[ group ][ unload_groups[ group ].size ] = 3;
	unload_groups[ group ][ unload_groups[ group ].size ] = 4;
	unload_groups[ group ][ unload_groups[ group ].size ] = 5;
	
	unload_groups[ "default" ] = unload_groups[ "all" ];
	
	
	unload_groups[ "driver" ] = [];
	
	group = "driver";
	unload_groups[ group ][ unload_groups[ group ].size ] = 0;	
	
	return unload_groups;	
}
