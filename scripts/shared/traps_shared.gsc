/*
 * Created by ScriptDevelop.
 * User: hschmitt
 * Date: 11/20/2013
 * Time: 3:22 PM
 * 
 * To change this template use Tools | Options | Coding | Edit Standard Headers.
 */

#insert scripts\shared\shared.gsh;

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;


#define ALERT_NONE	0
#define ALERT_SCANNING	1
#define ALERT_SEE 2

#namespace traps;

#precache( "fx", "_t6/_prototype/fx_pro_temp_searchlight" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_searchlight_grn" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_searchlight_red" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_searchlight_ylw" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_explosion_md" );
#precache( "fx", "weapon/fx_muz_sm_gas_flash_3p" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_light_blink_red" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_sparks_elec_disabled" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_steam_cooldown" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_laser_beam_deathray" );
#precache( "fx", "_t6/_prototype/fx_pro_temp_laser_trail_deathray" );
	
REGISTER_SYSTEM( "traps", &__init__, undefined )

function __init__()
{
	precache_all();
	
	// custom fx
	level._effect["camera_light_fx"] = "_t6/_prototype/fx_pro_temp_searchlight"; // generic searchlight
	level._effect["camera_light_fx_grn"] = "_t6/_prototype/fx_pro_temp_searchlight_grn"; // security not alerted, player not in sight of this camera
	level._effect["camera_light_fx_red"] = "_t6/_prototype/fx_pro_temp_searchlight_red"; // player sighted by camera
	level._effect["camera_light_fx_ylw"] = "_t6/_prototype/fx_pro_temp_searchlight_ylw"; // security alerted, but player not in sight of this camera
	level._effect["temp_explosion_md"] = "_t6/_prototype/fx_pro_temp_explosion_md"; // generic explosion
	level._effect["railturret_muzzle_flash"] = "weapon/fx_muz_sm_gas_flash_3p"; // muzzle flash for rail turret
	level._effect["security_light_red"] = "_t6/_prototype/fx_pro_temp_light_blink_red"; // blinks red when security in an area is alerted
	level._effect["electrical_sparks"] = "_t6/_prototype/fx_pro_temp_sparks_elec_disabled"; // death effect for cameras (damage effect for turrets?)
	level._effect["steam_cooldown"] = "_t6/_prototype/fx_pro_temp_steam_cooldown"; // cooldown effect for turrets
	// deathray fx
	level._effect["deathray_beam"] = "_t6/_prototype/fx_pro_temp_laser_beam_deathray";
	level._effect["deathray_trail"] = "_t6/_prototype/fx_pro_temp_laser_trail_deathray";
	
	level thread setup_all_traps();
}

function setup_all_traps()
{
	level flag::wait_till( "all_players_connected" );
	
	// create all security systems (security systems will then spawn any associated traps)	
	level.prototype_secsystems = [];
	
	a_secsystem_structs = struct::get_array( "area_security", "targetname" );
	foreach( secsystem_struct in a_secsystem_structs )
	{
		Assert( isdefined( secsystem_struct.script_noteworthy ), "secsystem_struct.script_noteworthy not found" );

		str_secsystem_name = secsystem_struct.script_noteworthy;

		o_secsystem = new cSecuritySystem();
		[[ o_secsystem ]]->setup_secsystem( secsystem_struct );
		ARRAY_ADD( level.prototype_secsystems, o_secsystem );
	}
}

function precache_all()
{

}

//*****************************************************************************
// SECURITY SYSTEM OBJECT
//
// -handles security states for an area
// -security detectors, alert consequences, and interaction points are associated to a security system via script_noteworthy
// -to create a security system in the level, make a struct with the targetname "area_security", and a unique script_noteworthy
//
//*****************************************************************************

class cSecuritySystem
{
	// security stats
	var e_secsystem; // security system struct
	var str_secsystem_name; // name for the security area (script_noteworthy from the struct)
	var n_alert_level; // 0 - no alert, 1 - scanning area, 2 - high alert
	var n_alert_cooldown; // set number of seconds until security cools down
	var n_alert_remaining_cooldown; // seconds remaining on current cooldown
	var v_player_last_known_pos; // the last place the player was when detected by any security device (camera or turret scan, tripwire, pressure plate, etc.)
	var n_security_node_count; // number of security nodes
	var n_detector_count; // number of detectors (tripwires, cameras, active turrets, active robots)
	var b_secsystem_can_reactivate; // whether the security system can recover after a cooldown (gets set to false if the system has been disabled via panel, destroying security nodes, etc.
	
	// security assets
	var a_SecurityDoors; // security doors associated with the area
	var a_SecurityCrushers; // security crushers associated with the area
	var a_SecurityBlockers; // security blockers associated with the area
	var a_LaserTripwires; // laser tripwire objects associated with the area
	var a_Cameras; // security camera objects associated with the area
	var a_RailTurrets; // rail turrets associated with the area
	var a_SpiderBots; // spider bots - cling to wall in a radius around their spawner
	var a_Quadrotors; // security quadrotors
	var a_SecurityLights; // toggleable lights to convey security alert state
	var a_SecurityNodes; // security node brushmodels - destroy all to deactivate security (if there are no security nodes associated with the script_noteworthy, this doesn't apply)
	var a_SecurityPanels; // security panel triggers - use to deactivate security
	var a_SecurityReversePanels; // security reverse panels - use to reverse specific security elements' behavior
	
	constructor()
	{
		n_alert_level = 0; // 0 - no alert
		n_alert_cooldown = 10;
		n_security_node_count = 0;
		n_detector_count = 0;
		b_secsystem_can_reactivate = true;
		self flag::init( "secsystem_on" );
		self flag::init( "turrets_spawned" );
	}
	
	destructor()
	{
	}

	function setup_secsystem( secsystem )
	{
		Assert( isdefined( secsystem ), "cSecuritySystem->setup_secsystem - secsystem doesn't exist - error in calling function" );
		e_secsystem = secsystem;
		str_secsystem_name = e_secsystem.script_noteworthy;
		
		if ( isdefined( e_secsystem.script_int ) )
		{
			n_alert_cooldown = e_secsystem.script_int;
			
			// cooldown of 0 means that the security system is a once-off
			if ( n_alert_cooldown == 0 )
			{
				b_secsystem_can_reactivate = false;
			}
		}
		
		// set active flag
		self flag::set( "secsystem_on" );

		// setup detectors
		a_LaserTripwires = setup_in_array( "laser_tripwire" );
		a_Cameras = setup_in_array( "security_camera" );
		// setup consequences
		a_SecurityDoors = setup_in_array( "security_door" );
		a_SecurityCrushers = setup_in_array( "security_crusher" );
		a_SecurityLights = setup_in_array( "security_light" );
		a_SecurityBlockers = setup_in_array( "security_blocker" );
		// setup interactables
		a_SecurityPanels = setup_in_array( "security_shutdown_panel" );
		a_SecurityReversePanels = setup_in_array( "security_reverse_panel" );
		a_SecurityNodes = setup_in_array( "security_node" );

		// option to start security system on		
		if ( isdefined( e_secsystem.script_string ) )
		{
			if ( e_secsystem.script_string == "start" )
			{
				alert_security_system();
			}
		}
		else // ordinary security response thread
		{
			self thread respond_to_alert_level();
		}
	}
	
	function setup_in_array( str_targetname )
	{
		a_OutputArray = [];
		a_things = GetEntArray( str_targetname, "targetname" );
		// get struct if not using ents
		if ( a_things.size == 0 )
		{
			a_things = struct::get_array( str_targetname, "targetname" );
		}
		
		foreach ( thing in a_things )
		{
			if ( !isdefined( thing.script_noteworthy ) )
			{
				continue;
			}
			
			if ( thing.script_noteworthy != str_secsystem_name )
			{
				continue;
			}
			
			o_Thing = new_object_of_type( str_targetname );
			thread [[ o_Thing ]]->setup( thing, self );
			ARRAY_ADD( a_OutputArray, o_Thing );
			// increase security node count if applicable
			if ( str_targetname == "security_node" )
			{
				n_security_node_count++;
			}
			if ( ( str_targetname == "laser_tripwire" ) || ( str_targetname == "security_camera" ) )
			{
				n_detector_count++;
			}
		}
		
		return a_OutputArray;
	}
	
	function new_object_of_type( str_targetname )
	{
		switch( str_targetname )
		{
			case "security_door": 
				return new cSecurityDoor();
			case "security_crusher":
				return new cSecurityCrusher();
			case "security_shutdown_panel":
				return new cSecurityShutdownPanel();
			case "security_reverse_panel":
				return new cSecurityReversePanel();
			case "security_node":
				return new cSecurityNode();
			case "laser_tripwire":
				return new cLaserTripwire();
			case "security_camera":
				return new cSecurityCamera();
			case "security_light":
				return new cSecurityLight();
			case "security_blocker":
				return new cSecurityBlocker();
		}
	}

	// reverse all blockers
	function reverse_blockers()
	{
		foreach( o_blocker in a_SecurityBlockers )
		{
			[[ o_blocker ]]->reverse();
		}
	}
	
	// call this whenever the player is detected
	function set_player_last_known_pos()
	{
		player = level.players[0];
		v_player_last_known_pos = player.origin;
	}
	
	function decrement_detector_count()
	{
		n_detector_count--;
		if ( n_detector_count < 1 )
		{
			deactivate_security_system();
		}
	}
	
	function decrement_security_node_count()
	{
		n_security_node_count--;
		if ( n_security_node_count < 1 )
		{
			deactivate_security_system();
			deactivate_spawned(); // if we continue this, find a better way of handling security system state, differentiating between cooldown and deactivation, and cleanly handling deactivation of spawned patrolling entities post-cooldown
		}
	}

	function get_alert_level()
	{
		return n_alert_level;
	}
	
	function set_alert_level( n_target_alert_level )
	{
		if ( !isdefined( n_target_alert_level ) )
		{
			n_target_alert_level = n_alert_level + 1;
		}
		
		// clamp min/max
		if ( n_target_alert_level < 0 )
		{
			return;
		}
		else if ( n_target_alert_level > 2 )
		{
			return;
		}
		else
		{
			// reset cooldown
			if ( n_target_alert_level > 0 )
			{
				n_alert_remaining_cooldown = n_alert_cooldown;
			}
			
			// set alert level (do this after setting cooldown so we don't fall straight through)
			n_alert_level = n_target_alert_level;
		}

	}
	
	function respond_to_alert_level()
	{
		while ( true )
		{
			while ( n_alert_level == 0 )
			{
				WAIT_SERVER_FRAME;
			}
			
			raise_alert();
		}
	}
	
	function raise_alert()
	{
		self endon( "cooldown" );

		alert_security_system();
		
		// wait until cooldown is expended
		while ( n_alert_remaining_cooldown > 0 )
		{
			wait 1;
			n_alert_remaining_cooldown--;
		}
		
		reset_security_system();

		set_alert_level( ALERT_NONE ); // reset alert level
	}
	
	function alert_security_system()
	{
		set_alert_level( ALERT_SCANNING );
		
		if ( !self flag::get( "turrets_spawned" ) )
		{
			self flag::set( "turrets_spawned" );
			spawn_turrets();
		}
		
		// activate consequences
		activate_consequences();
	}
	
	function reset_security_system()
	{
		PlaySoundAtPosition( "vox_inter_security_reset_0", level.players[0].origin ); // "security reset" VO - play over intercom

		// deactivate consequences
		deactivate_consequences();
		
		// reactivate tripped detectors
		reactivate_all_in_array( a_LaserTripwires );
	}
	
	function deactivate_security_system()
	{
		set_alert_level( ALERT_NONE ); // reset alert level
		self flag::clear( "secsystem_on" );
		self notify( "cooldown" ); // end any existing alert-cooldown sequence
		
		PlaySoundAtPosition( "vox_inter_security_deactivated_0", level.players[0].origin ); // "security deactivated" VO - play over intercom
		
		deactivate_detectors();
		deactivate_consequences();

		deactivate_all_in_array( a_SecurityPanels );
	}

	function activate_consequences()
	{
		activate_all_in_array( a_SecurityDoors );
		activate_all_in_array( a_SecurityCrushers );
		activate_all_in_array( a_SecurityLights );
	}
	
	function deactivate_consequences()
	{
		deactivate_all_in_array( a_SecurityCrushers );
		deactivate_all_in_array( a_SecurityDoors );
		deactivate_all_in_array( a_SecurityLights );
	}

	function deactivate_detectors()
	{
		deactivate_all_in_array( a_LaserTripwires );
		deactivate_all_in_array( a_Cameras );
	}

	function deactivate_spawned()
	{
		deactivate_all_in_array( a_RailTurrets );
	}
	
	function reactivate_detectors()
	{
		if ( b_secsystem_can_reactivate )
		{
			reactivate_all_in_array( a_LaserTripwires );
			reactivate_all_in_array( a_Cameras );
		}
	}

	// functions for activating / deactivating / reactivating all in an array
	function activate_all_in_array( a_things )
	{
		foreach( o_thing in a_things )
		{
			[[ o_thing ]]->activate();
		}
	}

	function deactivate_all_in_array( a_things )
	{
		if ( !isdefined( a_things ) )
		{
			return;
		}
		
		foreach( o_thing in a_things )
		{
			[[ o_thing ]]->deactivate();
		}
	}

	function reactivate_all_in_array( a_things )
	{
		foreach( o_thing in a_things )
		{
			[[ o_thing ]]->reactivate();
		}
	}

	function set_security_lights( b_lights_on )
	{
		light_intensity = 0;

		if ( b_lights_on )
		{
			light_intensity = 1;
		}
		
		foreach( light in a_SecurityLights )
		{
			// server-side light functions deprecated
		}
	}

	function spawn_turrets()
	{
		a_RailTurrets = [];
		a_railturret_structs = struct::get_array( "railturret_spawn", "targetname" );
	
		foreach( railturret_struct in a_railturret_structs )
		{
			if ( !isdefined( railturret_struct.script_noteworthy ) )
			{
				/# PrintLn( "railturret_struct.script_noteworthy not found" ); #/
				continue;
			}
			
			if ( railturret_struct.script_noteworthy != str_secsystem_name )
			{
				continue;
			}
			
			if ( isdefined( railturret_struct.script_string ) && ( railturret_struct.script_string == "rocket" ) )
			{
				o_railturret = new cMissileTurret();
				[[ o_railturret ]]->spawn_at_struct( railturret_struct, self );
				ARRAY_ADD( a_RailTurrets, o_railturret );
			}
			else
			{
				o_railturret = new cRailTurret();
				[[ o_railturret ]]->spawn_at_struct( railturret_struct, self );
				ARRAY_ADD( a_RailTurrets, o_railturret );
			}
			
			
			
			// turret counts as a potential detector (can sight the player to bring you out of cooldown)
			n_detector_count++;
		}
	}
	
}

//
// Laser Tripwires
//
// For each laser tripwire, place a trigger volume and a script_brushmodel for the visible beam.
//
// The trigger volume needs:
//
// •	targetname “laser_tripwire”
// •	target = the targetname of the visible beam script_brushmodel(s), so we know which ones to turn off when triggered
// •	script_noteworthy = whatever name you put in for the security system
// •	Laser tripwires can move back and forth; set the script_vector kvp to set their movement displacement, and script_int to set the amount of time it takes
// •	If a laser tripwire uses a trigger_multiple, it will reactivate after the security system cools down; otherwise, it will be a one-off
//
class cLaserTripwire
{
	var t_laser; // trigger for the laser field
	var m_o_secsystem; // associated security system object
	var e_visible_laser; // script brushmodel representing the laser
	var b_visible_laser_exists; // whether we are using a visual laser or a script_origin brushmodel
	var b_laser_can_reactivate; // whether laser can reactivate on security system cooldown; is decided by whether the trigger is a trigger_multiple or not
	var b_camera_shake; // whether to play a camera shake upon activation
	// movement [optional]
	var v_laser_origin;
	var v_laser_destination;
	var n_laser_movement_duration; // time it takes for the laser to move to its duration and back
	
	constructor()
	{
		self flag::init( "laser_on" );
		b_camera_shake = false;
		b_laser_can_reactivate = false;
		b_visible_laser_exists = false;
		n_laser_movement_duration = 10; // default timing - overridden by .script_int on the trigger
	}
	
	destructor()
	{
	}
	
	function setup( trigger, secsystem )
	{
		self flag::set( "laser_on" );
		t_laser = trigger;
		m_o_secsystem = secsystem;
		
		if ( isdefined( t_laser.target ) )
		{
			e_visible_laser = GetEnt( t_laser.target, "targetname" );
			e_visible_laser playloopsound( "evt_laser_loop", 1 );
			b_visible_laser_exists = true;
		}
		else // still need the right type of entity to be able to move the laser
		{
			e_visible_laser = util::spawn_model( "script_origin", t_laser.origin, t_laser.angles );
			e_visible_laser Hide();
			b_visible_laser_exists = false;
		}
		
		if( isdefined( t_laser.script_vector ) )
		{
			self thread laser_movement();
		}
		
		if( isdefined( t_laser.script_string ) )
		{
			if ( t_laser.script_string == "shake" )
			{
				b_camera_shake = true;
			}
		}
		
		if( t_laser.classname == "trigger_multiple" )
		{
			b_laser_can_reactivate = true;
		}
		
		self thread laser_awareness();
	}
	
	function laser_awareness()
	{
		do
		{
			t_laser waittill( "trigger", e_other );
			if ( self flag::get( "laser_on" ) )
			{
				self flag::clear( "laser_on" );
				
				// optional camera shake, if script_string was set to "shake" (use for triggering pressure plates)
				if( b_camera_shake )
				{
					Earthquake( 1, 2, level.players[0].origin, 64 );
				}
				
				// only play VO and sfx if this is a visible trigger
				if ( b_visible_laser_exists )
				{
					PlaySoundAtPosition( "vox_inter_laser_tripped_0", level.players[0].origin );
					e_visible_laser stoploopsound( .1 );
					PlaySoundAtPosition( "evt_laser_tripped", e_visible_laser.origin );
					hide_laser();
				}
				
				// alert security system object
				[[ m_o_secsystem ]]->set_alert_level( ALERT_SCANNING );

				// laser resets when the security alert level returns to 0
				self flag::wait_till( "laser_on" );
			}
		}
		while( b_laser_can_reactivate );
	}
	
	function laser_movement()
	{
		v_laser_origin = t_laser.origin;
		v_laser_destination = v_laser_origin + t_laser.script_vector;
		if ( isdefined( t_laser.script_float ) )
		{
			n_laser_movement_duration = t_laser.script_float;
		}
		else if ( isdefined( t_laser.script_int ) )
		{
			n_laser_movement_duration = t_laser.script_int;
		}
		
		t_laser EnableLinkTo();
		t_laser LinkTo( e_visible_laser );
		
		while( true )
		{
			e_visible_laser MoveTo( v_laser_destination, n_laser_movement_duration/2 );
			wait n_laser_movement_duration/2;
			e_visible_laser MoveTo( v_laser_origin, n_laser_movement_duration/2 );
			wait n_laser_movement_duration/2;
		}
	}

	function deactivate()
	{
		self flag::clear( "laser_on" );
		hide_laser();
	}

	function activate()
	{
		self flag::set( "laser_on" );
		show_laser();
	}
	
	function reactivate()
	{
		if( b_laser_can_reactivate )
		{
			activate();
		}
	}
	
	function show_laser()
	{
		if ( b_visible_laser_exists )
		{
			e_visible_laser Show();
		}
	}

	function hide_laser()
	{
		if ( b_visible_laser_exists )
		{
			e_visible_laser Hide();
		}
	}
	
}


// generic security mover class
// right now this is for simple things that define a script_vector to move along a set displacement
// potential children of this are things like doors, crushers, retractable bridges and dynamic cover
class cSecurityMover
{
	var e_mover; // script_brushmodel for the mover
	var m_o_secsystem; // associated security system object
	var e_mover_broken; // broken variant of script_brushmodel, if needed
	var e_rotation_origin; // script_origin spawned to be the rotation point, if script_linkto is defined
	// movement
	var v_startpos; // start position vector
	var v_endpos; // end position vector
	var v_startangles; // start position angles (used if b_is_rotator is true)
	var v_endangles; // end position angles (used if b_is_rotator is true)
	var n_delay_before_movement; // delay before movement
	var n_movement_duration; // how long the mover takes to go from v_startpos to v_endpos
	var n_resttime; // how long the mover rests at its destinations
	// pathing
	var a_pathstructs; // array of path structs, if defined by setting .target kvp
	var n_total_path_dist; // total distance from v_startpos to the end of the path
	var n_current_path_index; // which struct in a_pathstructs will the mover encounter next, if moving forwards along the path?
	// other
	var b_is_rotator; // whether to interpret movement as rotation along script_vector angles
	var b_is_breakable; // whether to allow the mover to be destroyed by explosive weapons
	var b_is_broken; // use to make sure we don't try to move a broken wall
	
	constructor()
	{
		n_resttime = 1;
		n_delay_before_movement = 0;
		n_total_path_dist = 0;
		n_current_path_index = 0;
		b_is_rotator = false;
		b_is_breakable = false;
		b_is_broken = false;
	}
	
	destructor()
	{
	}

	function setup_mover( mover )
	{
		Assert( isdefined( mover ), "cSecurityMover->setup_mover() - valid mover not passed in, error in calling function" );
		e_mover = mover;
		v_startpos = e_mover.origin;
		v_startangles = e_mover.angles;

		if ( isdefined( e_mover.script_string ) )
		{
			if ( IsSubStr( e_mover.script_string, "platform" ) ) // is the mover a platform? (needed for pushers and bridges)
			{
				e_mover SetMovingPlatformEnabled( true );
			}
			
			if ( IsSubStr( e_mover.script_string, "rotator" ) )
			{
				b_is_rotator = true;
			}
			
			if ( IsSubStr( e_mover.script_string, "breakable" ) )
			{
				b_is_breakable = true;
			}
		}
		
		// delay before beginning initial movement?
		if ( isdefined( e_mover.script_delay ) )
		{
			n_delay_before_movement = e_mover.script_delay;
		}
		
		// get movement duration
		if ( isdefined( e_mover.script_float ) )
		{
			n_movement_duration = e_mover.script_float;
		}
		else if ( isdefined( e_mover.script_int ) )
		{
			n_movement_duration = e_mover.script_int;
		}
		Assert( isdefined( n_movement_duration ), "cSecurityMover->setup_mover() - n_movement_duration not defined, set script_float or script_int on the script_brushmodel in the map" );
		
		// if target kvp is defined, load the path
		if ( isdefined( e_mover.target ) )
		{
			load_pathstructs();
		}
		else if ( isdefined( e_mover.script_vector ) ) // else if script_vector is defined, set the endpos
		{
			if ( b_is_rotator )
			{
				if ( isdefined( e_mover.script_linkto ) )
				{
					// find the rotation origin, and linkto
					e_rotation_struct = struct::get( e_mover.script_linkto, "script_linkname" );
					e_rotation_origin = util::spawn_model( "script_origin", e_rotation_struct.origin, e_rotation_struct.angles );
					e_rotation_origin Hide();
					// everything attaches to the e_rotation_origin
					e_mover LinkTo( e_rotation_origin );
					v_startangles = e_rotation_origin.angles; // get a different v_startangles before calculating v_endangles below
				}
				
				v_endangles = v_startangles + e_mover.script_vector;
			}
			else
			{
				v_endpos = v_startpos + e_mover.script_vector;
			}
		}
		else
		{
			AssertMsg( "cSecurityMover->setup_mover() - neither script_vector, nor target is defined" );
		}

		if ( b_is_breakable )
		{
			if ( isdefined( e_mover.target ) )
			{
				e_mover_broken = GetEnt( e_mover.target, "targetname" );
				Assert( isdefined( e_mover_broken ), "cBreakableWalls->setup_breakable_wall - wall_broken does not exist; targetname should be: " + e_mover.target );
				
				if ( isdefined( e_mover_broken ) )
				{
					e_mover_broken LinkTo( e_mover );
					e_mover_broken Hide();
					e_mover_broken SetPlayerCollision( false );
				}
			}
		
			e_mover.health = 10000;
			e_mover SetCanDamage( true );
			self thread breakable_wall_damage_watcher();
		}
	}

	// wall breaks only due to explosive damage
	function breakable_wall_damage_watcher()
	{
		while( true )
		{
			e_mover waittill( "damage", damage, attacker, direction_vec, point, type, modelName, tagName, partName, weapon, iDFlags );
			// wall breaks only due to explosive damage
			if ( type == "MOD_GRENADE" || type == "MOD_GRENADE_SPLASH" || type == "MOD_EXPLOSIVE" || type == "MOD_EXPLOSIVE_SPLASH" || type == "MOD_PROJECTILE" || type == "MOD_PROJECTILE_SPLASH" )
			{
				break_wall();
			}
			else
			{
				// restore health; so we don't chip away at it with a different weapon
				e_mover.health = 10000;
			}
		}
	}

	// effects of breaking wall
	function break_wall()
	{
		self notify( "stop_moving" );
		b_is_broken = true;
		
		// stop any previous movement
		e_mover MoveTo( e_mover.origin, 0.05 );
		WAIT_SERVER_FRAME;
		
		e_mover Delete();
		if ( isdefined( e_mover_broken ) )
		{
			e_mover_broken Show();
			e_mover_broken SetPlayerCollision( true );
		}
	}
	
	function move_to_endpos()
	{
		self endon( "stop_moving" );
		
		if ( b_is_broken )
		{
			WAIT_SERVER_FRAME;
			return;
		}
		
		if ( isdefined( e_mover.target ) ) // follow path, if path is defined
		{
			move_forward_along_path();
		}
		else if ( b_is_rotator )
		{
			if ( isdefined( e_rotation_origin ) )
			{
				e_rotation_origin RotateTo( v_endangles, n_movement_duration );
				timed_effects( true ); // play sounds and screen shake at appropriate times
			}
			else
			{
				e_mover RotateTo( v_endangles, n_movement_duration );
				timed_effects( true ); // play sounds and screen shake at appropriate times
			}
		}
		else
		{
			e_mover MoveTo( v_endpos, n_movement_duration );
			timed_effects( true ); // play sounds and screen shake at appropriate times
		}
	}
	
	function move_to_startpos()
	{
		self endon( "stop_moving" );
		
		if ( b_is_broken )
		{
			WAIT_SERVER_FRAME;
			return;
		}
		
		if ( isdefined( e_mover.target ) ) // follow path, if path is defined
		{
			move_backward_along_path();
		}
		else if ( b_is_rotator )
		{
			if ( isdefined( e_rotation_origin ) )
			{
				e_rotation_origin RotateTo( v_startangles, n_movement_duration );
				timed_effects( false ); // play sounds and screen shake at appropriate times
			}
			else
			{
				e_mover RotateTo( v_startangles, n_movement_duration );
				timed_effects( false ); // play sounds at appropriate times; no screen shake
			}
		}
		else
		{
			e_mover MoveTo( v_startpos, n_movement_duration );
			timed_effects( false ); // play sounds at appropriate times; no screen shake
			e_mover.origin = v_startpos;
		}
	}
	
	function load_pathstructs()
	{
		s_nextstruct = struct::get( e_mover.target, "targetname" );
		v_current_position = v_startpos;
		
		while ( isdefined( s_nextstruct ) )
		{
			// add to cumulative distance
			n_total_path_dist += Distance( v_current_position, s_nextstruct.origin );
			v_current_position = s_nextstruct.origin;
			// save struct in array
			ARRAY_ADD( a_pathstructs, s_nextstruct );

			if ( !isdefined( s_nextstruct.target ) )
			{
				return;
			}
			s_nextstruct = struct::get( s_nextstruct.target, "targetname" );
		}
	}
	
	// starts the mover moving along a trail of structs, or continues movement when stopped
	function move_forward_along_path()
	{
		self notify( "move_forward_along_path" );
		self endon( "move_forward_along_path" );
		self endon( "move_backward_along_path" );
		self endon( "stop_moving" );

		start_sounds();
		
		// slide to next node
		while( n_current_path_index <= ( a_pathstructs.size - 1 ) )
		{
			s_nextstruct = a_pathstructs[ n_current_path_index ];
			Assert( isdefined( s_nextstruct ), "cSecurityMover->move_along_path() s_nextstruct not defined" );
			n_dist = Distance( e_mover.origin, s_nextstruct.origin );
			n_duration = ( n_dist / n_total_path_dist ) * n_movement_duration; // scale duration by the ratio between the length of this leg of the path, and the cumulative length of the path
			// safety catch for n_duration
			if ( n_duration <= 0 )
			{
				n_duration = 0.05;
			}
			e_mover MoveTo( s_nextstruct.origin, n_duration );
			wait n_duration; // reach the destination
			n_current_path_index++; // try the next path index
		}

		stop_sounds();
	}
	
	function move_backward_along_path()
	{
		self notify( "move_backward_along_path" );
		self endon( "move_backward_along_path" );
		self endon( "move_forward_along_path" );
		self endon( "stop_moving" );

		start_sounds();

		// slide to previous node
		while( n_current_path_index > 0 )
		{
			s_nextstruct = a_pathstructs[ n_current_path_index - 1 ]; // slide to previous node
			Assert( isdefined( s_nextstruct ), "cSecurityMover->move_along_path() s_nextstruct not defined" );
			n_dist = Distance( e_mover.origin, s_nextstruct.origin );
			n_duration = ( n_dist / n_total_path_dist ) * n_movement_duration; // scale duration by the ratio between the length of this leg of the path, and the cumulative length of the path
			// safety catch for n_duration
			if ( n_duration <= 0 )
			{
				n_duration = 0.05;
			}
			e_mover MoveTo( s_nextstruct.origin, n_duration );
			wait n_duration; // reach the destination
			n_current_path_index--; // try the next path index
		}
		// slide to v_startpos
		n_dist = Distance( e_mover.origin, v_startpos );
		n_duration = ( n_dist / n_total_path_dist ) * n_movement_duration; // scale duration by the ratio between the length of this leg of the path, and the cumulative length of the path
		// safety catch for n_duration
		if ( n_duration <= 0 )
		{
			n_duration = 0.05;
		}
		e_mover MoveTo( v_startpos, n_duration );
		wait n_duration; // reach the destination

		stop_sounds();
	}

	function start_sounds()
	{
		// start sounds
		e_mover stoploopsound( .25 ); // safety catch if we interrupted previous movement
		e_mover playsound( "evt_door_close_start" );
		e_mover playloopsound( "evt_door_move", .25 );
	}
	
	function stop_sounds()
	{
		// stop sounds		
		e_mover stoploopsound( .25 );
		e_mover playsound( "evt_door_open_stop" );
	}

	function timed_effects( b_play_screen_shake )
	{
		self endon( "stop_moving" );
		
		start_sounds();
		wait n_movement_duration;
		if ( b_play_screen_shake )
		{
			Earthquake( 0.3, 1, e_mover.origin, 256 ); // screen shake for when mover hits its endpoint (may want to make this a conditional effect on a kvp later)
		}
		stop_sounds();
	}
}

// mover that rises into place as you approach within a radius of it, retracting as you retreat from the radius
class cSecurityBlocker : cSecurityMover
{
	var n_inner_radius; // radius at which the blocker is fully moved to its script_vector
	var n_outer_radius; // radius within which the blocker moves at all; amount that blocker moves is linearly scaled between inner and outer radii
	var b_reversed; // whether to reverse blocker behavior (have it at full extend when the player is outside of n_outer_radius, scale to fully retracted once player reaches n_inner_radius)
	
	function setup( blocker, secsystem )
	{
		m_o_secsystem = secsystem;
		self flag::init( "locking_down" );
		setup_mover( blocker );
		
		Assert( isdefined( blocker.radius ), "cSecurityBlocker->setup() - .radius kvp on blocker not defined" );
		
		n_inner_radius = blocker.radius;
		n_outer_radius = n_inner_radius * 2;
		b_reversed = false;
		
		self thread blocker_control_thread();
	}

	function reverse()
	{
		b_reversed = !b_reversed;
	}
	
	function blocker_control_thread()
	{
		Assert( isdefined( e_mover ), "cSecurityBlocker->blocker_control_thread() - e_mover not defined" );
		
		while ( true )
		{
			if ( [[ m_o_secsystem ]]->get_alert_level() == ALERT_SCANNING )
			{
				n_player_dist = Distance( level.player.origin, e_mover.origin );
				
				if ( n_player_dist < n_outer_radius )
				{
					if ( n_player_dist <= n_inner_radius )
					{
						if ( b_reversed )
						{
							e_mover.origin = v_startpos;
						}
						else
						{
							e_mover.origin = v_endpos;
						}
					}
					else
					{
						// move_amount - player's proximity between the inner and outer radii, on a 0-1 scale
						move_amount = 1 - ( ( n_player_dist - n_inner_radius ) / ( n_outer_radius - n_inner_radius ) );
						
						if ( b_reversed )
						{
							e_mover.origin = LerpVector( v_endpos, v_startpos, move_amount );
						}
						else
						{
							e_mover.origin = LerpVector( v_startpos, v_endpos, move_amount );
						}
					}
				}
				else
				{
					if ( b_reversed )
					{
						e_mover.origin = v_endpos;
					}
					else
					{
						e_mover.origin = v_startpos;
					}
				}
			}
			WAIT_SERVER_FRAME;
		}
	}

}

// DOOR activates on security alert, moves along script_vector, taking script_int seconds - if deactivated, it pauses and then returns to starting position (reopening door)
class cSecurityDoor : cSecurityMover
{
	var b_lockingdown; // whether door is currently locking/locked down
	
	function setup( door, secsystem )
	{
		m_o_secsystem = secsystem;
		self flag::init( "locking_down" );
		setup_mover( door );
		self thread door_control_thread();
	}
	
	function door_control_thread()
	{
		self endon( "stop_moving" );
		
		while( true )
		{
			self flag::wait_till( "locking_down" );
			wait n_delay_before_movement; // starting delay
			self thread cSecurityMover::move_to_endpos(); // thread this so we can interrupt the closing movement if we want
			self flag::wait_till_clear( "locking_down" );
			self thread cSecurityMover::move_to_startpos();
		}
	}
	
	function activate()
	{
		close_door();
	}

	function deactivate()
	{
		open_door();
	}
	
	function close_door()
	{
		self flag::set( "locking_down" );
	}
	
	function open_door()
	{
		self flag::clear( "locking_down" );
	}
}

// CRUSHER activates on security alert, moves along script_vector, taking script_int seconds, then returns the same way - does this repeatedly until deactivated, in which case it pauses and then returns to starting position
class cSecurityCrusher : cSecurityMover
{
	var b_crusher_is_active;
	
	function setup( crusher, secsystem )
	{
		m_o_secsystem = secsystem;
		setup_mover( crusher );
		b_crusher_is_active = false;
		self thread watch_for_player_touch();
	}
	
	function watch_for_player_touch()
	{
		self endon( "stop_moving" );

		while ( true )
		{
			e_mover waittill( "touch", player );
			if ( b_crusher_is_active )
			{
				player DoDamage( player.health, player.origin );
			}
		}
	}
	
	function looping_movement()
	{
		self endon( "stop_moving" );
		self endon( "deactivate" );
		self notify( "activate" );
		
		wait n_delay_before_movement; // starting delay
		
		b_crusher_is_active = true; // crusher can now do damage
		
		while( true )
		{
			cSecurityMover::move_to_endpos();
			cSecurityMover::move_to_startpos();
		}
	}
	
	// crusher retracts - during this time, the crusher doesn't do damage
	function retract()
	{
		self endon( "activate" );
		self notify( "deactivate" );
		
		if ( !isdefined( e_mover ) )
		{
			return;
		}
		
		b_crusher_is_active = false; // turn off damage

		// scale time to return to starting pos by the current distance between the crusher and its starting pos
		n_distance_scale = Distance( e_mover.origin, v_startpos ) / Distance( v_endpos, v_startpos );
		n_adjusted_movement_duration = n_distance_scale * n_movement_duration;
		if ( n_adjusted_movement_duration <= 0 )
		{
			/# IPrintLn( "cSecurityCrusher->retract() - n_adjustment_movement_duration is zero or less" ); #/
			e_mover.origin = v_startpos;
		}
		else
		{
			e_mover MoveTo( v_startpos, n_adjusted_movement_duration );
		}
		e_mover stoploopsound( .25 );
	}
	
	function activate()
	{
		self thread looping_movement();
	}
	
	function deactivate()
	{
		self thread retract();
	}
}

// security light class for playing a red-blinking security light effect on a struct whenever the associated security system is alerted
class cSecurityLight
{
	var m_e_securitylight; // struct
	var m_o_secsystem; // associated security system object
	var fx_ent; // fx entity to play the effect on
	
	constructor()
	{
	}
	
	destructor()
	{
	}
	
	function setup( securitylight, secsystem )
	{
		Assert( isdefined( securitylight ), "cSecurityLight->setup() - securitynode not defined, error in the calling function" );
		Assert( isdefined( secsystem ), "cSecurityLight->setup() - secsystem not defined, error in the calling function" );
		m_o_secsystem = secsystem;
		m_e_securitylight = securitylight;
	}
	
	function activate()
	{
		fx_ent = util::spawn_model( "script_origin", m_e_securitylight.origin, m_e_securitylight.angles );
		fx_ent Hide();
		if ( isdefined( fx_ent ) )
		{
			PlayFXOnTag( level._effect["security_light_red"], fx_ent, "tag_origin" );
		}
	}
	
	function deactivate()
	{
		if ( isdefined( fx_ent ) )
		{
			fx_ent Delete();
		}
	}
}

// security node class for controlling security level via destructible script_brushmodels
class cSecurityNode
{
	var m_e_securitynode; // script_brushmodel
	var e_linkto_target; // entity that m_e_securitynode will be linked to
	var m_o_secsystem; // associated security system object
	var n_health; // hp
	
	constructor()
	{
		n_health = 10;
	}
	
	destructor()
	{
	}
	
	function setup( securitynode, secsystem )
	{
		Assert( isdefined( securitynode ), "cSecurityNode->setup_securitynode() - securitynode not defined, error in the calling function" );
		Assert( isdefined( secsystem ), "cSecurityNode->setup_securitynode() - secsystem not defined, error in the calling function" );
		m_o_secsystem = secsystem;
		m_e_securitynode = securitynode;

		// attach security node to a mover?		
		if ( isdefined( m_e_securitynode.target ) )
		{
			e_linkto_target = GetEnt( m_e_securitynode.target, "targetname" );
			m_e_securitynode LinkTo( e_linkto_target );
		}
		else if ( isdefined( m_e_securitynode.script_linkto ) )
		{
			e_linkto_target = GetEnt( m_e_securitynode.script_linkto, "script_linkname" );
			m_e_securitynode LinkTo( e_linkto_target );
		}

		// set security node health in map?
		if ( isdefined( m_e_securitynode.script_int ) )
		{
			n_health = m_e_securitynode.script_int;
		}
		m_e_securitynode.health = n_health;
		m_e_securitynode SetCanDamage( true );
		
		self thread watch_securitynode_death();
	}
	
	function watch_securitynode_death()
	{
		m_e_securitynode waittill( "death" );
		// play effect
		PlayFX( level._effect["temp_explosion_md"], m_e_securitynode.origin );
		m_e_securitynode Hide();
		m_e_securitynode SetPlayerCollision( false );
		[[ m_o_secsystem ]]->decrement_security_node_count();
	}
}

// generic security panel class so we can have different consequences for using panels (shutdown security, cooldown security, shut off specific subsystem, etc.)
class cSecurityPanel
{
	var t_panel; // use_trigger to activate the panel
	var m_o_secsystem; // parent security system
	
	constructor()
	{
	}
	
	destructor()
	{
	}

	function setup( trigger, secsystem )
	{
		Assert( isdefined( trigger ), "cSecurityPanel->setup_securitypanel - trigger not defined, error in calling function" );
		Assert( isdefined( secsystem ), "cSecurityPanel->setup_securitypanel - secsystem not defined, error in calling function" );
		t_panel = trigger;
		m_o_secsystem = secsystem;
	}
	
	function watch_security_panel_trigger()
	{
		t_panel waittill( "trigger", e_other );
	}
	
	function deactivate()
	{
		t_panel TriggerEnable( false );
	}
	
	function security_panel_consequences()
	{
	}
}

// security shutdown panel - deactivates the security system when used
class cSecurityShutdownPanel : cSecurityPanel
{
	function setup( trigger, secsystem )
	{
		cSecurityPanel::setup( trigger, secsystem );
		watch_security_panel_trigger(); // blocking call - waits for security panel to be activated
		security_panel_consequences(); // results of the player using the security panel
	}
	
	function security_panel_consequences()
	{
		[[ m_o_secsystem ]]->deactivate_security_system();
		t_panel TriggerEnable( false );
	}
}

// security reverse panel - reverses the effects of certain security elements (blockers to start with)
class cSecurityReversePanel : cSecurityPanel
{
	function setup( trigger, secsystem )
	{
		cSecurityPanel::setup( trigger, secsystem );
		watch_security_panel_trigger(); // blocking call - waits for security panel to be activated
		security_panel_consequences(); // results of the player using the security panel
	}
	
	function security_panel_consequences()
	{
		[[ m_o_secsystem ]]->reverse_blockers();
		t_panel TriggerEnable( false );
	}
}

// Missile Turret
//
// missile-firing variant of the rail turret
//
// the rail turret fires when the player is within view and the turret is finished with its cooldown
// the rail turret, while firing, attempts to track the player (and if it loses sight of the player, watches the player's last known location)
// the missile turret commits to firing when the player has been within its view frustrum for a specified duration
// the missile turret, once it commits to firing, locks down its position/orientation, plays a laser sight, waits n_pause_before_attack, then fires
class cMissileTurret : cRailTurret
{
	constructor()
	{
		w_weapon = GetWeapon( "ai_tank_drone_rocket" );
		n_pause_before_attack = 3;
		n_pause_between_shots = 5;
		n_shoot_duration = 5000;
		n_shoot_cooldown = 5;
		n_shoot_revtime = 3;
		n_turn_speed = 1.0;
		n_health = 1000;
		b_track_while_attacking = false;
	}
	
	destructor()
	{
	}

	function spawn_at_struct( str_struct, secsystem )
	{
		Assert( isdefined( str_struct ), "cMissileTurret->spawn_at_struct() str_struct not defined" );
		Assert( isdefined( secsystem ), "cMissileTurret->spawn_at_struct() secsystem not defined" );

		m_o_secsystem = secsystem;
		
		// "turret_acquired_target" flag is set when the turret locks onto a target 
		self flag::init( "turret_acquired_target" );
		self flag::init( "turret_moving_along_path" );
		
		self flag::init( "turret_ready_to_fire" );
		self flag::set( "turret_ready_to_fire" );
		
		// spawn model
		e_railturret = util::spawn_model( "t6_wpn_turret_cic_world", str_struct.origin, str_struct.angles );

		e_railturret_snd1 = spawn( "script_origin", str_struct.origin );
		e_railturret_snd1 linkto( e_railturret );
		e_railturret_snd2 = spawn( "script_origin", str_struct.origin );
		e_railturret_snd2 linkto( e_railturret );
		
		// setup model to take damage
		b_turret_alive = true; // b_turret_alive = the turret has not been destroyed
		e_railturret.health = n_health;
		e_railturret SetCanDamage( true );
		self thread cRailTurret::thread_watch_for_damage();
		self thread cRailTurret::thread_watch_for_death();

		// set turret to target player (will set e_target to player)		
		player = level.players[0];
		self cRailTurret::set_combat_target( player );
		
		// stats
		n_speed = 128;
		b_turret_active = true;
		
		// turret ai
		self thread cRailTurret::turret_awareness();
		self thread turret_behavior();
		s_nextdest = struct::get( str_struct.target, "targetname" );
		self thread turret_movement_behavior();
		self thread cRailTurret::face_player();
	}

	function turret_behavior()
	{
		do
		{
			self flag::wait_till( "turret_acquired_target" );
			fire_at_target();
		}
		while( b_turret_active && b_turret_alive );
	}

	function turret_movement_behavior()
	{
		self thread cRailTurret::move_along_path();
		
		while( b_turret_active && b_turret_alive )
		{
			if ( self flag::get( "turret_acquired_target" ) && ( self flag::get( "turret_moving_along_path" ) ) )
			{
				PlaySoundAtPosition( "vox_turr_target_sighted_0", e_railturret.origin ); // "target sighted" VO
				PlaySoundAtPosition( "evt_turret_target", e_railturret.origin );
				self thread cRailTurret::stop_moving();
				wait 5;
			}
			else if ( !self flag::get( "turret_moving_along_path" ) )
			{
				self thread cRailTurret::move_along_path();
			}
			wait 0.01;
		}
	}

}

// Rail Turret Spawners
// For each place you want a rail turret to spawn when security alerts, place a struct with these values:
// •	targetname “railturret_spawn”
// •	target = the targetname of the first struct in a chain describing the path you want the railturret to follow (ideally, create a loop of structs, each one targeting the next)
// •	script_noteworthy = whatever name you put in for the security system
//
class cRailTurret
{
	var e_railturret; // model
	var m_o_secsystem; // associated security system object
	var n_health; // hp
	var fx_ent; // play fx on this
	// combat
	var b_turret_alive; // whether turret is alive or not (turret has not been destroyed)
	var b_turret_active; // is the turret active or not (allows spawned turrets to be shutdown by security system or emps, hacking, etc.)
	var e_target;
	var w_weapon; // weapon used by the turret
	var n_pause_before_attack; // once a target is sighted, the turret waits this many seconds before attacking
	var n_pause_between_shots; // while firing, the turret waits this many seconds between shots
	var n_shoot_duration; // shoot duration in ms
	var n_shoot_cooldown; // cooldown time between attacks in seconds
	var n_shoot_revtime; // turret revving up time in seconds
	var b_track_while_attacking; // whether turret should continue to track its target while attacking (if false, turret stays locked in position once it starts to attack)
	var n_turn_speed; // speed of turning in place
	var n_stop_on_track_dist; // if the player is closer to the railturret than this distance, the railturret will stop moving
	// pathing
	var n_dist;
	var v_dest;
	var n_speed; // current speed of pathing
	var n_duration;
	// rail turret either follows a struct path or attaches to an ent
	var s_nextdest; // next struct on the track for the rail turret to move towards
	var e_gimbal; // script_origin for the turret to attach to (allows it to rotate independently while following the movement of an attachment entity)
	var e_attachpoint; // entity for the rail turret's gimbal to attach to
	
	var e_railturret_snd1;
	var e_railturret_snd2;
	
	constructor()
	{
		w_weapon = GetWeapon( "kard" );
		n_pause_before_attack = 0;
		n_pause_between_shots = 0.25;
		n_shoot_duration = 5000;
		n_shoot_cooldown = 2;
		n_shoot_revtime = 1;
		n_turn_speed = 5.0;
		n_health = 1000;
		n_stop_on_track_dist = 386;
		b_track_while_attacking = true;
	}

	destructor()
	{
	}

	function spawn_at_struct( str_struct, secsystem )
	{
		Assert( isdefined( str_struct ), "cRailTurret->spawn_at_struct() str_struct not defined" );
		Assert( isdefined( secsystem ), "cRailTurret->spawn_at_struct() secsystem not defined" );

		m_o_secsystem = secsystem;
		
		// "turret_acquired_target" flag is set when the turret locks onto a target 
		self flag::init( "turret_acquired_target" );
		self flag::init( "turret_moving_along_path" );
		
		self flag::init( "turret_ready_to_fire" );
		self flag::set( "turret_ready_to_fire" );
		
		// spawn model
		e_railturret = util::spawn_model( "t6_wpn_turret_cic_world", str_struct.origin, str_struct.angles );

		e_railturret_snd1 = spawn( "script_origin", str_struct.origin );
		e_railturret_snd1 linkto( e_railturret );
		e_railturret_snd2 = spawn( "script_origin", str_struct.origin );
		e_railturret_snd2 linkto( e_railturret );
		e_railturret playsound( "evt_turret_spawn" );
		
		// setup model to take damage
		b_turret_alive = true;
		e_railturret.health = n_health;
		e_railturret SetCanDamage( true );
		self thread thread_watch_for_damage();
		self thread thread_watch_for_death();

		// set turret to target player (will set e_target to player)		
		player = level.players[0];
		set_combat_target( player );
		e_railturret LaserOn(); // TODO: see if we can get this working
		
		// stats
		n_speed = 128;
		b_turret_active = true;
		
		// turret ai
		self thread turret_awareness();
		self thread turret_behavior();
		if ( isdefined( str_struct.script_linkto ) )
		{
			e_attachpoint = GetEnt( str_struct.script_linkto, "script_linkname" );
		}
		else if ( isdefined( str_struct.target ) )
		{
			s_nextdest = struct::get( str_struct.target, "targetname" );
		}
		self thread turret_movement_behavior();
		self thread face_player();
		self thread laser_sight_loop();
	}
	
	function thread_watch_for_damage()
	{
		e_railturret endon( "death" );

		while ( true )
		{
			e_railturret waittill( "damage", iDamage, sAttacker, vDirection, vPoint );
			// play effect
			PlayFX( level._effect["electrical_sparks"], vPoint );
			WAIT_SERVER_FRAME;
		}
	}
	
	function thread_watch_for_death()
	{
		e_railturret waittill( "death" );
		
		// play effect
		PlayFX( level._effect["temp_explosion_md"], e_railturret.origin );
		e_railturret_snd1 stoploopsound( .1 );
		e_railturret_snd2 stoploopsound( .1 );
		e_railturret playsound( "evt_turret_explode" );

		deactivation_effects();
	}

	function deactivate()
	{
		deactivation_effects();
	}

	function deactivation_effects()
	{
		// stop at current location (override previous MoveTo)
		e_railturret MoveTo( e_railturret.origin, 0.05 );
		e_railturret RotatePitch( 90, 1 ); // face down
		b_turret_alive = false;
		b_turret_active = false;
		
		//e_railturret Delete(); // don't need this anymore, as we're only spawning turret once per rail
		
		[[ m_o_secsystem ]]->decrement_detector_count();
	}
	
	function warp_to_struct( str_struct )
	{
		Assert( isdefined( str_struct ), "cRailTurret->warp_to_struct() str_struct not defined" );
		
		e_railturret.origin = str_struct.origin;
	}
	
	function turret_movement_behavior()
	{
		// move the turret along the path of structs, if defined
		if ( isdefined( s_nextdest ) )
		{
			self thread move_along_path();
		}
		else if ( isdefined( e_attachpoint ) ) // attach to the mover
		{
			//Assert( isdefined( e_attachpoint ), "cRailTurret->turret_movement_behavior - e_attachpoint is not defined" );
			self thread follow_mover();
			return; // no further movement behavior
		}
		
		while( b_turret_active && b_turret_alive )
		{
			// stop to attack target
			if ( ( self flag::get( "turret_acquired_target" ) ) && ( Distance( e_railturret.origin, e_target.origin ) < n_stop_on_track_dist ) && ( self flag::get( "turret_moving_along_path" ) ) )
			{
				PlaySoundAtPosition( "vox_turr_target_sighted_0", e_railturret.origin ); // "target sighted" VO
				PlaySoundAtPosition( "evt_turret_target", e_railturret.origin );
				self thread stop_moving();
				wait 5;
			}
			// resume movement
			else if ( ( !self flag::get( "turret_moving_along_path" ) ) && ( isdefined( s_nextdest ) ) ) // added check for is s_nextdest is defined, so we don't try to restart turret movement if it wasn't spawned on a path
			{
				self thread move_along_path();
			}
			wait 0.01;
		}
	}
	
	// follow the targeted mover at a fixed offset; doing this instead of LinkTo() because LinkTo() stomps on the turret's angle control
	function follow_mover()
	{
		// TODO: spawn a script_origin and use LinkTo between that and e_attachpoint, then keep the turret's origin at the script_origin
		e_gimbal = util::spawn_model( "script_origin", e_railturret.origin, e_railturret.angles );
		e_gimbal LinkTo( e_attachpoint );
		e_gimbal Hide();

		v_offset = e_railturret.origin - e_gimbal.origin;
		
		while ( isdefined( e_railturret ) )
		{
			e_railturret.origin = e_gimbal.origin + v_offset;
			WAIT_SERVER_FRAME;
		}
	}

	// starts the turret moving along a trail of structs, or continues movement when stopped
	function move_along_path()
	{
		self notify( "move_along_path" );
		self endon( "move_along_path" );
		self endon( "stop_moving" );
		e_railturret endon( "death" );
		
		self flag::set( "turret_moving_along_path" );
		e_railturret_snd1 playloopsound( "evt_turret_move", .25 );
		
		// slide to next node
		while( b_turret_active && b_turret_alive )
		{
			Assert( isdefined( s_nextdest ), "cRailTurret->move_along_path() s_nextdest not defined" );
			n_dist = Distance( e_railturret.origin, s_nextdest.origin );
			n_duration = n_dist / n_speed;
			// safety catch for n_duration
			if ( n_duration <= 0 )
			{
				n_duration = 0.05;
			}
			e_railturret MoveTo( s_nextdest.origin, n_duration );
			wait n_duration + 1; // pause at end
			// let us stop at the end of a path if there is no continuation
			if( !isdefined( s_nextdest.target ) )
			{
				return;
			}
			// else get the next struct in the path
			str_nextstruct = s_nextdest.target;
			s_nextdest = struct::get( str_nextstruct, "targetname" );
		}
	}
	
	// call move_along_path() again to continue path movement
	function stop_moving()
	{
		self notify( "stop_moving" );
		self endon( "stop_moving" );
		self endon( "move_along_path" );
		
		self flag::clear( "turret_moving_along_path" );
		
		e_railturret_snd1 stoploopsound( .1 );

		// will override MoveTo on move_along_path()
		e_railturret MoveTo( e_railturret.origin, 0.05 );
	}
	
	
	// function to continuously check for various types of valid targets, including the player
	function turret_awareness()
	{
		do
		{
			check_for_target();
			wait 0.1;
		}
		while( b_turret_active && b_turret_alive );
	}
	
	// sets/clears "turret_acquired_target" flag
	function check_for_target()
	{
		b_seeplayer = false;
		
		if ( isdefined( e_railturret ) && isdefined( e_target ) )
		{
			//b_seeplayer = player SightConeTrace( e_railturret.origin, e_railturret, AnglesToForward( scan_angles ), 30 );
			b_seeplayer = BulletTracePassed( e_railturret.origin, e_target.origin + (0, 0, 60), true, undefined );
		}
		
		if ( b_seeplayer )
		{
//			IPrintLn( "TURRET ACQUIRED TARGET" );
			self flag::set( "turret_acquired_target" );
		}
		else
		{
//			IPrintLn( "TURRET LOST TARGET" );
			self flag::clear( "turret_acquired_target" );
		}
	}
	
	// if security is alerted, the turret will attempt to turn and face the player's last known location
	function face_player()
	{
		player = level.players[0];
		set_combat_target( player );
		
		while( b_turret_active && b_turret_alive )
		{	
			target_yaw = get_yaw_to_combat_target();
			//yaw = AngleLerp( e_railturret.angles[1], yaw, 0.5 );
			if ( isdefined( target_yaw ) )
			{
				turret_yaw = e_railturret.angles[1];
				yaw_diff = turret_yaw - target_yaw;
				//IPrintLn( "yaw diff: " + yaw_diff );
					
				// prevent overcorrection while turning to face player
				yaw_to_add = Min( Abs( yaw_diff ), n_turn_speed );
				
				// turn the correct direction
				if ( yaw_diff > 0 )
				{
					e_railturret.angles -= ( 0, yaw_to_add, 0 );
				}
				else
				{
					e_railturret.angles += ( 0, yaw_to_add, 0 );
				}
				
				if( yaw_diff == 0 )
				{
					e_railturret_snd2 stoploopsound( .1 );
				}
				else
				{
					e_railturret_snd2 playloopsound( "evt_turret_turn", .25 );
				}
			}
			WAIT_SERVER_FRAME;
		}
	}
	
	function turret_behavior()
	{
		do
		{
			self flag::wait_till( "turret_acquired_target" );
			fire_at_target();
		}
		while( b_turret_active && b_turret_alive );
	}
	
	function set_combat_target_as_player()
	{
		player = level.players[0];
		set_combat_target( player );
	}
	
	function set_combat_target( target )
	{
		Assert( isdefined( target ), "cRailTurret->set_combat_target() target not defined" );
		e_target = target;
	}
	
	function get_yaw_to_combat_target()
	{
		Assert( isdefined( e_target ), "cRailTurret->get_yaw_to_combat_target() e_target not defined" );
		Assert( isdefined( e_railturret ), "cRailTurret->get_yaw_to_combat_target() e_railturret not defined" );

		v_diff = e_target.origin - e_railturret.origin;
		x = v_diff[0];
		y = v_diff[1];
		
		if ( x != 0 )
		{
			n_slope = y / x;
			yaw = ATan( n_slope );
			if ( x < 0 )
			{
				yaw += 180;
			}
		}
		
		return yaw;
	}
	
	function laser_sight_loop()
	{
		e_railturret endon( "death" );
		
		while( b_turret_active && b_turret_alive )
		{
			// get firing angle
			v_fx_pos = e_railturret GetTagOrigin( "TAG_FLASH" );
			v_accurate_firing_angle = VectorNormalize( ( e_target.origin + (0, 0, 60) ) - e_railturret.origin );
			v_turret_yaw = AnglesToForward( e_railturret.angles );
			v_turret_firing_angle = ( v_accurate_firing_angle[0], v_turret_yaw[1], v_accurate_firing_angle[2] );
			// play beam effect during rev up
			PlayFX( level._effect["deathray_beam"], v_fx_pos, v_turret_firing_angle );
			PlayFX( level._effect["deathray_trail"], v_fx_pos, v_turret_firing_angle );
			wait 0.2;
		}
	}
	
	function fire_at_target()
	{
		e_railturret endon( "death" );
		
		Assert( isdefined( e_target ), "cRailTurret->fire_at_target() e_target not defined" );
		Assert( isdefined( e_railturret ), "cRailTurret->fire_at_target() e_railturret not defined" );
		
		PlaySoundAtPosition( "vox_turr_spin_up_0", e_railturret.origin );
		wait n_shoot_revtime;
		PlaySoundAtPosition( "vox_turr_fire_0", e_railturret.origin );
		
		curr_time = GetTime();
		time_started_shooting = curr_time;
		
		while ( curr_time < ( time_started_shooting + n_shoot_duration ) )
		{
			// get firing angle
			v_fx_pos = e_railturret GetTagOrigin( "TAG_FLASH" );
			v_accurate_firing_angle = VectorNormalize( ( e_target.origin + (0, 0, 60) ) - e_railturret.origin );
			v_turret_yaw = AnglesToForward( e_railturret.angles );
			v_turret_firing_angle = ( v_accurate_firing_angle[0], v_turret_yaw[1], v_accurate_firing_angle[2] );
			
			turret_firing_offset = ( v_turret_firing_angle * 100 );
			MagicBullet( w_weapon, v_fx_pos, v_fx_pos + turret_firing_offset );
			PlayFX( level._effect["railturret_muzzle_flash"], v_fx_pos, v_turret_firing_angle );
			
			wait n_pause_between_shots;
			curr_time = GetTime();
		}
		
		PlaySoundAtPosition( "vox_turr_cool_0", e_railturret.origin );
		self thread play_cooldown_fx();
		wait n_shoot_cooldown;
		self notify( "stop_cooldown_fx" );
	}

	function play_cooldown_fx()
	{
		self endon( "stop_cooldown_fx" );
		
		// spawn ent to play effect off of
		fx_ent = util::spawn_model( "script_origin", e_railturret.origin, e_railturret.angles );
		fx_ent Hide();

		while( true )
		{
			PlayFX( level._effect["steam_cooldown"], fx_ent.origin );
			wait 0.5;
		}
	}

}

//
// Security cameras can now be spawned off of structs. These are super easy to set up.
//
// 1.	Targetname on the struct is “security_camera”
// 2.	Script_noteworthy on the struct matches the local security system
// 3.	Script_int sets the total number of seconds that the camera takes to scan 90 degrees in both directions and return to starting position (including one second pauses at each extreme)
//
class cSecurityCamera
{
	// id
	var m_o_secsystem; // associated security system object
	// camera ents
	var e_camera; // camera model
	var e_camera_mount; // camera mount to wall
	var e_camera_sound;
	var fx_ent; // spotlight cone effect attached to the camera
	// camera frustrum
	var t_frustrum; // frustrum trigger
	var e_frustrum; // visual frustrum
	// camera scanangle
	var n_scanangle_left; // how far to rotate left from starting angle
	var n_scanangle_right; // how far to rotate right from starting angle
	// camera stats
	var n_scantime; // how long the camera takes to perform a complete left+right scan and return to starting angle
	var n_scanpausetime; // how long the camera pauses at each rotational extreme
	var n_viewrange; // how far away the camera can see
	var n_spotlighttype; // which spotlight should currently be playing
	// camera control
	var b_active; // the camera is active (will see and respond to entities of interest)
	var b_scanning; // the camera is scanning left and right (servos running)
	var b_scandir_right; // keep track of scan direction
	var b_start_scanyaw; // starting yaw
	var b_max_scanyaw; // max yaw
	var b_min_scanyaw; // min yaw
	// misc
	var n_camerapitch; // how pitched down the camera is
	var e_target; // the entity that the camera is currently following
	
	constructor()
	{
		/# PrintLn( "cSecurityCam->constructor()" ); #/
		n_scanangle_left = 90;
		n_scanangle_right = 90;
		n_scantime = 4;
		n_scanpausetime = 1;
		n_viewrange = 384;
		b_scanning = false;
		b_scandir_right = true;
		n_camerapitch = 20;
		b_active = true;
		n_spotlighttype = 0;
		self flag::init( "camera_on" );
	}
	
	destructor()
	{
		/# PrintLn( "cSecurityCam->destructor()" ); #/
	}

	function setup( str_struct, secsystem )
	{
		Assert( isdefined( str_struct ), "cSecurityCam->setup() str_struct not defined" );
		Assert( isdefined( secsystem ), "cSecurityCam->setup() secsystem not defined" );
		m_o_secsystem = secsystem;
		
		// spawn model
		e_camera = util::spawn_model( "p_int_security_camera", str_struct.origin, str_struct.angles );
		e_camera_mount = util::spawn_model( "p6_security_camera_mount", str_struct.origin, str_struct.angles );
		e_camera_sound = spawn( "script_origin", str_struct.origin );
		
		self flag::set( "camera_on" );
		e_camera.health = 10;
		e_camera SetCanDamage( true );
		self thread camera_death_watcher();

		// orient model so that it matches the angle of the struct visually in-editor
		e_camera.angles = ( e_camera.angles[0], e_camera.angles[1] + 90, e_camera.angles[2] );
		
		// angle downwards
		e_camera.angles = ( e_camera.angles[0], e_camera.angles[1], e_camera.angles[2] + n_camerapitch );
		// calculate relative yaws for min and max rotation
		b_start_scanyaw = e_camera.angles[1];
		b_max_scanyaw = b_start_scanyaw + n_scanangle_right;
		b_min_scanyaw = b_start_scanyaw - n_scanangle_left;
		
		Assert( isdefined( str_struct.script_noteworthy ), "cSecurityCamera->spawn_at_struct() - script_noteworthy not defined!" );
		
		// get timing off of struct
		if ( isdefined( str_struct.script_int ) )
		{
			n_scantime = str_struct.script_int;
		}

		// get detect distance on xy-plane off of radius
		if ( isdefined( str_struct.radius ) )
		{
			n_viewrange = str_struct.radius;
		}

		
		// activate camera
		self thread camera_awareness();
		
		// start camera scanning
		self thread camera_scan();
		
		// turn on camera light fx
		n_spotlighttype = 2; // green
		self thread camera_spotlight_controller();
	}
	
	function camera_spotlight_controller()
	{
		curr_spotlighttype = 0;
		
		while( b_active )
		{
			if ( curr_spotlighttype != n_spotlighttype )
			{
				curr_spotlighttype = n_spotlighttype;
				self thread activate_camera_light( curr_spotlighttype );
				self thread camera_debug( curr_spotlighttype );
			}
			WAIT_SERVER_FRAME;
		}
	}
	
	// play a spotlight effect off the camera
	// light_type selects type of spotlight: 1 - white, 2 - green, 3 - red, 4 - yellow
	function activate_camera_light( light_type )
	{
		// reset by deleting any previously existing spotlight effect
		if ( isdefined( fx_ent ) )
		{
			fx_ent Delete();
		}
		
		// spawn ent to play effect off of
		fx_ent = util::spawn_model( "script_origin", e_camera.origin, e_camera.angles );
		fx_ent Hide();
		
		// play appropriate effect
		if ( isdefined( fx_ent ) )
		{
			fx_ent LinkTo( e_camera, "tag_origin", (0,0,0), (0,-90,20) );
			
			switch( light_type )
			{
				case 1:
					camera_light_fx = PlayFXOnTag( level._effect["camera_light_fx"], fx_ent, "tag_origin" );
					break;
				case 2:
					camera_light_fx = PlayFXOnTag( level._effect["camera_light_fx_grn"], fx_ent, "tag_origin" );
					break;
				case 3:
					camera_light_fx = PlayFXOnTag( level._effect["camera_light_fx_red"], fx_ent, "tag_origin" );
					break;
				case 4:
					camera_light_fx = PlayFXOnTag( level._effect["camera_light_fx_ylw"], fx_ent, "tag_origin" );
					break;
			}
		}
	}
	
	function camera_debug( light_type )
	{
	}
	
	function camera_scan()
	{
		/# PrintLn( "cSecurityCam->camera_scan()" ); #/
		Assert( isdefined( e_camera ), "cSecurityCam->camera_scan() e_camera not defined" );

		b_scanning = true;
		
		// remove pauses at each end from total scan time, then weight the time for each half of the scan according to the relative amount of angle (so speed of rotation stays the same)
		// calculating this here so that we can specify the length of the total scan period to time out movement across the space, instead of guessing at speed
		n_scanlefttime = ( n_scantime - ( 2 * n_scanpausetime ) ) * ( n_scanangle_left / ( n_scanangle_left + n_scanangle_right ) );
		n_scanrighttime = ( n_scantime - ( 2 * n_scanpausetime ) ) * ( n_scanangle_right / ( n_scanangle_left + n_scanangle_right ) );
		n_scan_rotationpersecond = n_scanangle_left / n_scanlefttime; // rotation per second
		n_scan_rotationperframe = n_scan_rotationpersecond / 20; // rotation per 0.05 second frame
		
		// scan loop
		while ( true )
		{
			if( b_scanning ) // let us start/stop scanning on any frame
			{
				cam_angles = e_camera.angles;
				yaw = cam_angles[1];
				
				if ( b_scandir_right ) // which direction are we currently scanning?
				{
					if ( yaw < b_max_scanyaw )
					{
						e_camera.angles = cam_angles + ( 0, n_scan_rotationperframe, 0 );
						e_camera_sound playloopsound( "evt_camera_move", .5 );
					}
					else
					{
						b_scandir_right = false;
						e_camera_sound stoploopsound( .05 );
						e_camera playsound( "evt_camera_move_stop" );
					}
				}
				else
				{
					if ( yaw > b_min_scanyaw )
					{
						e_camera.angles = cam_angles - ( 0, n_scan_rotationperframe, 0 );
						e_camera_sound playloopsound( "evt_camera_move", .5 );
					}
					else
					{
						b_scandir_right = true;
						e_camera_sound stoploopsound( .05 );
						e_camera playsound( "evt_camera_move_stop" );
					}
				}
			}
			
			WAIT_SERVER_FRAME;
		}
		e_camera stoploopsound( .05 );
	}
	
	function camera_death_watcher()
	{
		e_camera waittill( "death" );
		deactivate();
		
		e_camera_sound stoploopsound( .05 ); // stop scanning noise
		
		// play death fx
		fx_ent = util::spawn_model( "script_origin", e_camera.origin, e_camera.angles );
		fx_ent Hide();
		if ( isdefined( fx_ent ) )
		{
			PlayFXOnTag( level._effect["electrical_sparks"], fx_ent, "tag_origin" );
		}
	}
	
	function camera_awareness()
	{
		// need player ref on hand
		player = level.players[0];
		
		// trigger things based on awareness of player or distraction objects (things the player can throw, hologram, etc.)
		while ( true )
		{
			if ( b_active ) // if the camera is currently looking for targets
			{
				// if the player is within the camera's view, set off an alert
				scan_angles = ( e_camera.angles[0], e_camera.angles[1] - 90, e_camera.angles[2] ); // need to turn 90 degrees because of the coordinates of the camera model
//				IPrintLn( scan_angles );
				b_cansee = player SightConeTrace( e_camera.origin, e_camera_mount, AnglesToForward( scan_angles ), 30 );
				if ( b_cansee == 1 )
				{
					v_camera_xy_origin = ( e_camera.origin[0], e_camera.origin[1], 0 );
					v_player_xy_origin = ( player.origin[0], player.origin[1], 0 );
					
					if ( Distance( v_camera_xy_origin, v_player_xy_origin ) < n_viewrange )
					{
						PlaySoundAtPosition( "vox_turr_target_camera_0", e_camera.origin ); // "target on camera" VO - play from camera
						PlaySoundAtPosition( "evt_camera_target", e_camera.origin );
						n_spotlighttype = 3;
						[[ m_o_secsystem ]]->set_alert_level( ALERT_SCANNING );
						e_target = player;
						yaw = get_yaw_to_target();
						if ( isdefined( yaw ) && ( b_min_scanyaw < yaw < b_max_scanyaw ) )
						{
							cam_angles = e_camera.angles;
							e_camera.angles = ( cam_angles[0], yaw + 90, cam_angles[2] );
						}
					}
				}
				else
				{
					if ( [[ m_o_secsystem ]]->get_alert_level() == ALERT_SCANNING )
					{
						n_spotlighttype = 4;
					}
					else
					{
						n_spotlighttype = 2;
					}
				}
			}
			WAIT_SERVER_FRAME;
		}
	}

	function get_yaw_to_target()
	{
		Assert( isdefined( e_target ), "cSecurityCamera->get_yaw_to_target() e_target not defined" );
		Assert( isdefined( e_camera ), "cSecurityCamera->get_yaw_to_target() e_camera not defined" );

		v_diff = e_target.origin - e_camera.origin;
		x = v_diff[0];
		y = v_diff[1];
		
		if ( x != 0 )
		{
			n_slope = y / x;
			yaw = ATan( n_slope );
			if ( x < 0 )
			{
				yaw += 180;
			}
		}
		
		return yaw;
	}
	
	function deactivate()
	{
		if ( !self flag::get( "camera_on" ) )
		{
			return;
		}
		
		self flag::clear( "camera_on" );
		b_scanning = false; // stop scanning
		b_active = false; // stop caring whether player is in front
		e_camera RotateRoll( 90 - n_camerapitch, 1 ); // rotate the rest of the way to pointing straight down
		// kill the camera light effect
		fx_ent Delete();
	}
	
	function reactivate()
	{
		// don't reactivate if already active
		if ( self flag::get( "camera_on" ) )
		{
			return;
		}
		
		self flag::set( "camera_on" );
		e_camera RotateRoll( -(90 - n_camerapitch) , 1 ); // rotate back to n_camerapitch
		wait 1; // wait for camera to rise again before reactivating
		b_scanning = true; // continue scanning
		b_active = true; // detect player
		n_spotlighttype = 2;
	}
}
