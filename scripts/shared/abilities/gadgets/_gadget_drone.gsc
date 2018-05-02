#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_escort_drone;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;


#using scripts\shared\system_shared;

#precache( "fx", "vehicle/fx_elec_teleport_escort_drone" );

REGISTER_SYSTEM( "gadget_drone", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_DRONE, &gadget_drone_on, &gadget_drone_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_DRONE, &gadget_drone_on_give, &gadget_drone_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_DRONE, &gadget_drone_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_DRONE, &gadget_drone_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_DRONE, &gadget_drone_is_flickering );
	callback::on_connect( &gadget_drone_on_connect );
	
	drone_precache();
	
}

function drone_precache()
{
	level._effect["drone_spawn_fx"] = "vehicle/fx_elec_teleport_escort_drone";
}

function gadget_drone_is_inuse( slot )
{
	// returns true when the gadget is on
	return self flagsys::get( "gadget_drone_on" );
}

function gadget_drone_is_flickering( slot )
{
	// returns true when the gadget is flickering
	return self GadgetFlickering( slot );
}

function gadget_drone_on_flicker( slot )
{
	// excuted when the gadget flickers
	self thread gadget_drone_flicker( slot );	
}

function gadget_drone_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
}

function gadget_drone_on_take( slot )
{
	// executed when gadget is removed from the players inventory
}

//self is the player
function gadget_drone_on_connect()
{
	// setup up stuff on player connect
}

function gadget_drone_on( slot )
{
	// excecutes when the gadget is turned on
	self flagsys::set( "gadget_drone_on" );	

	self thread gadget_drone_spawn();
}

function gadget_drone_off( slot )
{
	self notify( "gadget_drone_off" );
	// excecutes when the gadget is turned off
	self flagsys::clear( "gadget_drone_on" );
	
	if ( IsDefined( self.escort ) )
	{
		self thread gadget_drone_despawn();
	}
}

function set_gadget_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}	
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Gadget Drone:" + status + timeStr );
}

function gadget_drone_flicker( slot )
{
	self endon( "disconnect" );

	if ( !self gadget_drone_is_inuse( slot ) )
	{
		return;
	}

	eventTime = self._gadgets_player[slot].gadget_flickertime;

	self set_gadget_status( "Flickering", eventTime );

	while( 1 )
	{		
		if ( !self GadgetFlickering( slot ) )
		{
			self set_gadget_status( "Normal" );
			return;
		}

		wait( 0.5 );
	}
}

function gadget_drone_spawn()
{
	self endon( "disconnect" );
	self endon( "gadget_drone_off" );
	
	n_above_head = 40;
	n_ahead_dist = self._gadgets_player.escortLaunchDistance;
		
	v_player_angles = self GetPlayerAngles();
	
	self.escort = vehicle::spawn( "veh_t7_drone_escort", "ed", "escort_drone", (0,0,0), v_player_angles );
	self.escort.owner = self;
	self.escort.ignoreme = true;
	
	self.escort escort_drone::escort_drone_think( self );
	
	vehicle::init( self.escort );
	self.escort escort_drone::escort_drone_start_scripted();
			
	v_offset = self GetPlayerViewHeight() + n_above_head;
		
	self.escort.origin = ( self.origin[0], self.origin[1], self.origin[2] + v_offset );
	
	self.escort.goal = self.escort.origin + ( AnglesToForward( v_player_angles ) * n_ahead_dist );
	
	if ( self.escort SetVehGoalPos( self.escort.goal, true, 2 ) )
	{
		self.escort util::waittill_any_timeout( 2, "near_goal", "force_goal", "reached_end_node" );
		
		self.escort escort_drone::escort_drone_start_ai();
	}
}

function gadget_drone_despawn()
{
	//TODO - temp
	PlayFX( level._effect["drone_spawn_fx"], self.escort.origin );
	
	self.escort Delete();
}
