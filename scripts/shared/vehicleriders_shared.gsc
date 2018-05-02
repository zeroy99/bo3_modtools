#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\colors_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\hostmigration_shared;

#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using_animtree( "generic" );

#namespace vehicle;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TODO:
//
// * Implement death anims
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

REGISTER_SYSTEM( "vehicleriders", &__init__, undefined )

function __init__()
{
	level.vehiclerider_groups = [];
	level.vehiclerider_groups[ "all" ] = "all";
	level.vehiclerider_groups[ "driver" ] = "driver";
	level.vehiclerider_groups[ "passengers" ] = "passenger";
	level.vehiclerider_groups[ "crew" ] = "crew";
	level.vehiclerider_groups[ "gunners" ] = "gunner";
	
	a_registered_fields = [];
	foreach ( bundle in struct::get_script_bundles( "vehicleriders" ) )
	{
		foreach ( object in bundle.objects )
		{
			if ( IsString( object.VehicleEnterAnim ) )
			{
				array::add( a_registered_fields, object.position + "_enter", false );
			}
			
			if ( IsString( object.VehicleExitAnim ) )
			{
				array::add( a_registered_fields, object.position + "_exit", false );
			}
			
			if ( IsString( object.VehicleRiderDeathAnim ) )
			{
				array::add( a_registered_fields, object.position + "_death", false );
			}
		}
	}
	
	foreach ( str_clientfield in a_registered_fields )
	{
		clientfield::register( "vehicle", str_clientfield, VERSION_SHIP, 1, "counter" );
	}
	
	
	level.vehiclerider_use_index = [];
	level.vehiclerider_use_index[ "driver" ] = 0;

	// Set up gunnner use indices.
	const MAX_USE_INDEX = 4;
	for ( i = 1; i <= MAX_USE_INDEX; i++ )
	{
		level.vehiclerider_use_index[ "gunner" + i ] = i;
	}
	
	// Setup passenger use indices
	const MAX_PASSENGER_INDEX = 10;
	passengerIndex = 1;
	for ( i = MAX_USE_INDEX + 1; i <= MAX_PASSENGER_INDEX; i++ )
	{
		level.vehiclerider_use_index[ "passenger" + passengerIndex ] = i;
		passengerIndex++;
	}
	
	/* FIX UP STUFF FROM THE GDT */
	foreach ( s in struct::get_script_bundles( "vehicleriders" ) )
	{
		DEFAULT( s.LowExitHeight, 0 );
		DEFAULT( s.HighExitLandHeight, 32 );
	}
	
	callback::on_vehicle_spawned( &on_vehicle_spawned );
	callback::on_ai_spawned( &on_ai_spawned );
	callback::on_vehicle_killed(&on_vehicle_killed);
}

function seat_position_to_index( str_position )
{
	return level.vehiclerider_use_index[ str_position ];
}

function on_vehicle_spawned()
{
	spawn_riders();
}

function on_ai_spawned()
{
	if ( IsVehicle( self ) )
	{
		self spawn_riders();
	}
}

function claim_position( vh, str_pos )
{
	array::add( vh.riders, self, false );
	vh flagsys::set( str_pos + "occupied" );
	self flagsys::set( "vehiclerider" );
	
	self thread _unclaim_position_on_death( vh, str_pos );
}

function unclaim_position( vh, str_pos )
{
	ArrayRemoveValue( vh.riders, self );
	vh flagsys::clear( str_pos + "occupied" );
	self flagsys::clear( "vehiclerider" );
}

function private _unclaim_position_on_death( vh, str_pos )
{
	vh endon( "death" );
	vh endon(  str_pos + "occupied" );
	
	self waittill( "death" );
	
	unclaim_position( vh, str_pos );
}

function find_next_open_position( ai )
{
	foreach ( s_rider in get_bundle_for_ai( ai ).objects )
	{
		seat_index = seat_position_to_index(s_rider.position);
		if( seat_index <= 4 )	// IsVehicleSeatOccupied only works on code seats and not passenger seats
		{
			if( self IsVehicleSeatOccupied( seat_index ) )
				continue;
		}
		   
		if ( !flagsys::get( s_rider.position + "occupied" ) )
		{
			return s_rider.position;
		}
	}
}

function spawn_riders()
{
	self endon("death");
	
	self.riders = [];
	if ( isdefined( self.script_vehicleride ) )
	{
		
		a_spawners = GetSpawnerArray( self.script_vehicleride, "script_vehicleride" );
		foreach ( sp in a_spawners )
		{
			ai_rider = sp spawner::spawn( true );
			//ai_rider = util::spawn_anim_model( "c_hro_hendricks_base_fb" );
			
			if ( isdefined( ai_rider ) )
			{
				ai_rider get_in( self, ai_rider.script_startingposition, true );
			}
		}
	}
}

function get_bundle_for_ai( ai )
{
	vh = self;
	if ( IS_ROBOT( ai ) )
	{
		bundle = vh get_robot_bundle();
	}
	else
	{
		bundle = vh get_bundle();
	}
	return bundle;
}

function get_rider_info( vh, str_pos = "driver" )
{
	ai = self;
	bundle = undefined;
	bundle = vh get_bundle_for_ai( ai );
	
	foreach ( s_rider in bundle.objects )
	{
		if ( s_rider.position == str_pos )
		{
			return s_rider;
		}
	}
}

/@
"Summary: Makes an AI get in a vehicle (with animation)"
"Name: get_in( vh, str_pos, b_teleport = false )"
"CallOn: AI"
"MandatoryArg: <vh> The vehicle to ride in"
"OptionalArg: [str_pos] The position to ride in.  If undefined, will choose next available position."
"OptionalArg: [b_teleport] If true, teleport to rider position and don't play get in animation."
"Example: ai vehicle::get_in( vh_truck, "driver" );"
@/
function get_in( vh, str_pos, b_teleport = false )
{
	self endon( "death" );	
	vh endon( "death" );
	
	if ( !isdefined( str_pos ) )
	{
		str_pos = vh find_next_open_position( self );
	}
	
	Assert( isdefined( str_pos ), "No unoccupied seats for vehicle rider." );
	
	if( !isdefined( str_pos ) )
	{
		return;
	}
	
	//return if the seat is not available
	if ( !isdefined( vh.ignore_seat_check ) || !vh.ignore_seat_check )
	{
		seat_index = level.vehiclerider_use_index[ str_pos ];
		if( seat_index <= 4 )	// IsVehicleSeatOccupied only works on code seats and not passenger seats
		{
			seat_available = !(vh IsVehicleSeatOccupied( seat_index ) );
			Assert( seat_available, "This seat is already occupied." );
		
			if(!seat_available)
			{
				return;
			}
		}
	}
	
	claim_position( vh, str_pos );

	if ( !b_teleport && self flagsys::get( "in_vehicle" ) )
	{
		get_out();
	}
	
	if ( colors::is_color_ai() )
	{
		colors::disable();
	}

	_init_rider( vh, str_pos );
	
	if ( !b_teleport )
	{
		self animation::set_death_anim( self.rider_info.EnterDeathAnim );
		animation::reach( self.rider_info.EnterAnim, self.vehicle, self.rider_info.AlignTag );
		
		// Animate the door on the client.
		if ( isdefined( self.rider_info.VehicleEnterAnim ) )
		{
			vh clientfield::increment( self.rider_info.position + "_enter", 1 );
			self SetAnim( self.rider_info.VehicleEnterAnim, 1, 0, 1 );
		}

		self animation::play( self.rider_info.EnterAnim, self.vehicle, self.rider_info.AlignTag );
	}
	
	if ( isdefined(self.rider_info) && isdefined( self.rider_info.RideAnim ) )
	{
		//disable unlink after the animation is done since this will be handled by UseVehicle
		self thread animation::play( self.rider_info.RideAnim, self.vehicle, self.rider_info.AlignTag, 1, 0.2, 0.2, 0, 0, false, false );
	}
	else if ( !isdefined( level.vehiclerider_use_index[ str_pos ] ) )
	{
		assert( "Rider is missing ride animation for seat: " + str_pos );
	}
	else if ( isdefined(self.rider_info) )
	{
		// HACK: teleport to align tag in the case of no ride animation being available (mainly for gunners)
		// Since UseVehicle doesn't put them on the vehicle properly.
		v_tag_pos = vh GetTagOrigin( self.rider_info.aligntag );
		v_tag_ang = vh GetTagAngles( self.rider_info.aligntag );
		if (isdefined(v_tag_pos))
			self ForceTeleport( v_tag_pos, v_tag_ang );
	}
	else
	{
		/# ErrorMsg( "Missing rider_info" ); #/
	}
	
	if ( IsActor( self ) )
	{
		// Disable pathing while inside a vehicle.
		self PathMode( "dont move" );
		
		// Disable dropping ammo/weapon inside a vehicle.
		self.disableAmmoDrop = true;
		self.dontDropWeapon = true;
	}
	
	// If there is an associated use index, call UseVehicle.
	//
	if ( isdefined( level.vehiclerider_use_index[ str_pos ] ) )
	{
		//double check that the seat is still available
		if ( !isdefined( self.vehicle.ignore_seat_check ) || !self.vehicle.ignore_seat_check )
		{
			seat_index = level.vehiclerider_use_index[ str_pos ];
			if( seat_index <= 4 )	// IsVehicleSeatOccupied only works on code seats and not passenger seats
			{
				if( self.vehicle IsVehicleSeatOccupied( seat_index ) )
				{
					get_out();
					return;
				}
			}
		}
		
		self.vehicle UseVehicle( self, level.vehiclerider_use_index[ str_pos ] );
	}
	
	self flagsys::set( "in_vehicle" );
	
	self thread handle_rider_death();
}

function handle_rider_death()
{
	self endon( "exiting_vehicle" );
	self.vehicle endon( "death" );

	if ( IsDefined( self.rider_info.RideDeathAnim ) )
	{
		self animation::set_death_anim( self.rider_info.RideDeathAnim );
	}
	
	self waittill( "death" );
	
	if ( !IsDefined( self ) )
	{
		return;
	}

	if ( IsDefined( self.vehicle ) && IsDefined( self.rider_info ) && IsDefined( self.rider_info.VehicleRiderDeathAnim ) )
	{
		self.vehicle clientfield::increment( self.rider_info.position + "_death", 1 );
		self.vehicle SetAnimKnobRestart( self.rider_info.VehicleRiderDeathAnim, 1, 0, 1 );
	}
}

function delete_rider_asap( entity )
{
	wait SERVER_FRAME;
	
	if ( IsDefined( entity ) )
	{
		entity Delete();
	}
}

function kill_rider( entity )
{
	if( IsDefined( entity ) )
	{
		if( IsAlive( entity ) && !GibServerUtils::IsGibbed( entity, GIB_ANNIHILATE_FLAG ) )
		{
			if ( entity IsPlayingAnimScripted() )
			{
				entity StopAnimScripted();
			}
			
			if ( GetDvarInt( "tu1_vehicleRidersInvincibility", 1 ) )
			{
				// TU1 crash fix when killing a vehicle that had invincible riders.
				util::stop_magic_bullet_shield( entity );
			}
		
			GibServerUtils::GibLeftArm( entity );
			GibServerUtils::GibRightArm( entity );
			GibServerUtils::GibLegs( entity );
			GibServerUtils::Annihilate( entity );
			
			entity Unlink();
			entity Kill();
		}
		
		// Ragdoll typically goes insane, hide and delete the entity.
		entity Ghost();
		level thread delete_rider_asap( entity );
	}
}

function on_vehicle_killed( params )
{
	// "self" is a removed entity in this case and IsDefined( self ) will always return false, even though
	// script variables on that entity are still available.
	if ( /* IsDefined( self ) && */ IsDefined( self.riders ) )
	{
		foreach ( rider in self.riders )
		{
			kill_rider( rider );
		}
	}
}

function is_seat_available( vh, str_pos )
{
	if ( vh flagsys::get( str_pos + "occupied" ) )
	{
		return false;
	}
	
	if ( AnglesToUp( vh.angles )[2] < 0.3 )
	{
		// Vehicle is flipped
		return false;
	}
	
	seat_index = seat_position_to_index( str_pos );
	if( seat_index <= 4 )	// IsVehicleSeatOccupied only works on code seats and not passenger seats
	{
		if( vh IsVehicleSeatOccupied( seat_index ) )
		{
			return false;
		}
	}
	return true;
}

function can_get_in( vh, str_pos )
{
	if ( !is_seat_available( vh, str_pos ) )
	{
		return false;
	}
	
	rider_info = self get_rider_info( vh, str_pos );
	
	v_tag_org = vh GetTagOrigin( rider_info.AlignTag );
	v_tag_ang = vh GetTagAngles( rider_info.AlignTag );
	
	v_enter_pos = GetStartOrigin( v_tag_org, v_tag_ang, rider_info.EnterAnim );
	
	if ( !self FindPath( self.origin, v_enter_pos ) )
	{
		return false;
	}
	
	return true;
}

#define GROUND_HEIGHT 5

/@
"Summary: Makes an AI get out of a vehicle (with animation)"
"Name: get_out()"
"CallOn: AI"
"Example: ai vehicle::get_out();"
@/
function get_out( str_mode )
{
	ai = self;
	self endon( "death" );
	
	self notify( "exiting_vehicle" );
	
	Assert( IsAlive( self ), "Dead or undefined vehicle rider." );
	Assert( isdefined( self.vehicle ), "AI is not on vehicle." );
	
	if ( IS_HELICOPTER( self.vehicle ) || IS_PLANE( self.vehicle ) )
	{
		DEFAULT( str_mode, "variable" );
	}
	else
	{
		DEFAULT( str_mode, "ground" );
	}
	
	bundle = self.vehicle get_bundle_for_ai( ai );
	n_hover_height = bundle.LowExitHeight;
	
	// Animate the door on the client.
	if ( isdefined( self.rider_info.VehicleExitAnim ) )
	{
		self.vehicle clientfield::increment( self.rider_info.position + "_exit", 1 );
		self.vehicle SetAnim( self.rider_info.VehicleExitAnim, 1, 0, 1 );
	}

	switch ( str_mode )
	{
		case "ground":
			
			exit_ground();
			break;
			
		case "low":
			
			exit_low();
			break;
			
		case "variable":
			
			exit_variable();
			break;
			
		default: AssertMsg( "Invalid mode for vehicle unload." );
	}
	
	if ( IsActor( self ) )
	{
		// Re-enable pathing once an AI leaves a vehicle.
		self PathMode( "move allowed" );
		
		// Allow dropping ammo/weapon after leaving the vehicle.
		self.disableAmmoDrop = false;
		self.dontDropWeapon = false;
	}
	
	if( isdefined( self.vehicle ) )
	{
		unclaim_position( self.vehicle, self.rider_info.position );
		
		// If there is an associated use index, call UseVehicle.
		//
		if ( isdefined( level.vehiclerider_use_index[ self.rider_info.position ] ) && (self flagsys::get( "in_vehicle" )) )
		{
			self.vehicle UseVehicle( self, level.vehiclerider_use_index[ self.rider_info.position ] );
		}
	}
	
	self flagsys::clear( "in_vehicle" );

	self.vehicle = undefined;	
	self.rider_info = undefined;
	self animation::set_death_anim( undefined );
	
	set_goal();
	
	self notify( "exited_vehicle" );
}

function set_goal()
{
	if ( colors::is_color_ai() )
	{
		colors::enable();
	}
	else if ( !isdefined( self.target ) )
	{
		self SetGoal( self.origin );
	}
}

/@
"Summary: Unload riders from a vehicle"
"Name: unload( str_group )"
"CallOn: Vehicle"
"OptionalArg: [str_group] Unload a specific group instead of all riders (all, driver, passengers, crew, gunners)."
"Example: vh_truck vehicle::unload( "all" );"
"Example: vh_truck vehicle::unload( "gunners" );"
@/
function unload( str_group = "all", str_mode, remove_rider_before_unloading, remove_riders_wait_time )
{
	self notify( "unload", str_group );
	
	Assert( isdefined( level.vehiclerider_groups[ str_group ] ), str_group + " is not a valid unload group." );
	
	str_group = level.vehiclerider_groups[ str_group ]; // look up position subtring to use
	
	a_ai_unloaded = [];
	foreach ( ai_rider in self.riders )
	{
		if ( ( str_group == "all" ) || IsSubStr( ai_rider.rider_info.position, str_group ) )
		{
			ai_rider thread get_out( str_mode );
			ARRAY_ADD( a_ai_unloaded, ai_rider );
		}
	}

	if ( a_ai_unloaded.size > 0 )
	{
		if ( remove_rider_before_unloading === true )
		{
			remove_riders_after_wait( remove_riders_wait_time, a_ai_unloaded );
		}	

		array::flagsys_wait_clear( a_ai_unloaded, "in_vehicle", VAL( self.unloadTimeout, 4 ) );
		self notify( "unload", a_ai_unloaded );
	}
}

function remove_riders_after_wait( wait_time, a_riders_to_remove )
{
	wait wait_time;

	if ( isdefined( a_riders_to_remove ) )
	{
		foreach( ai in a_riders_to_remove )
		{
			ArrayRemoveValue( self.riders, ai );
		}
	}
}

function ragdoll_dead_exit_rider()
{
	self endon( "exited_vehicle" );

	self waittill( "death" );

	if ( IsActor( self ) && !self IsRagdoll() )
	{
		self Unlink();
		self StartRagdoll();
	}
}

function exit_ground()
{	
	self animation::set_death_anim( self.rider_info.ExitGroundDeathAnim );
	
	if ( !IsDefined( self.rider_info.ExitGroundDeathAnim ) )
	{
		self thread ragdoll_dead_exit_rider();
	}
	
	Assert( IsString( self.rider_info.ExitGroundAnim ), "No exit animation for '" + self.rider_info.position + "'. Can't unload specified group." );
	
	if ( IsString( self.rider_info.ExitGroundAnim ) )
	{
		animation::play( self.rider_info.ExitGroundAnim, self.vehicle, self.rider_info.AlignTag );
	}
}

function exit_low()
{
	self animation::set_death_anim( self.rider_info.ExitLowDeathAnim );
	Assert( isdefined( self.rider_info.ExitLowAnim ), "No exit animation for '" + self.rider_info.position + "'. Can't unload specified group." );
	animation::play( self.rider_info.ExitLowAnim, self.vehicle, self.rider_info.AlignTag );
}

function private handle_falling_death()
{
	self endon( "landed" );
	
	self waittill( "death" );
	
	if ( IsActor( self ) )
	{
		self Unlink();
		self StartRagdoll();
	}
}

function private forward_euler_integration( e_move, v_target_landing, n_initial_speed )
{
	// Sympletic euler integration.
	landed = false;
	integrationStep = 0.1;  // Seconds
	position = self.origin;
	velocity = (0, 0, -n_initial_speed);
	gravity = (0, 0, -385.8); // Gravity in inches/second^2 moving downward
	
	while ( !landed )
	{
		previousPosition = position;
	
		// Update the velocity and position based on the integration step.
		velocity = velocity + gravity * integrationStep;
		// Calculating velocity before position ensure sympletic integration.
		position = position + velocity * integrationStep;
		
		// If the next integration step will take us past our landing, just move to that position instead.
		if ( ( position[2] + velocity[2] * integrationStep ) <= v_target_landing[2] )
		{
			landed = true;
			
			position = v_target_landing;
		}
	
			
		hostmigration::waitTillHostMigrationDone();
		e_move MoveTo( position, integrationStep );
	
		if ( !landed )
		{
			wait integrationStep;
		}
	}
}

function exit_variable()
{
	ai = self;
	self endon( "death" );
	
	self notify( "exiting_vehicle" );
	
	self thread handle_falling_death();
	
	self animation::set_death_anim( self.rider_info.ExitHighDeathAnim );
	Assert( isdefined( self.rider_info.ExitHighAnim ), "No exit animation for '" + self.rider_info.position + "'. Can't unload specified group." );
	animation::play( self.rider_info.ExitHighAnim, self.vehicle, self.rider_info.AlignTag, 1, 0, 0 );
	
	self animation::set_death_anim( self.rider_info.ExitHighLoopDeathAnim );
	
	n_cur_height = get_height( self.vehicle );
	
	bundle = self.vehicle get_bundle_for_ai( ai );
	n_target_height = bundle.HighExitLandHeight;
	
	if( IS_TRUE( self.rider_info.DropUnderVehicleOrigin ) || IS_TRUE( self.DropUnderVehicleOriginOverride ) )
		v_target_landing = ( self.vehicle.origin[0], self.vehicle.origin[1], self.origin[2] - n_cur_height + n_target_height );
	else
		v_target_landing = ( self.origin[0], self.origin[1], self.origin[2] - n_cur_height + n_target_height );
	
	if( isdefined( self.overrideDropPosition ) )
		v_target_landing = ( self.overrideDropPosition[0], self.overrideDropPosition[1], v_target_landing[2] );
	
	if( isdefined( self.targetAngles ) )
		angles = self.targetAngles;
	else
		angles = self.angles;
	
	// Create the tag origin
	e_move = util::spawn_model( "tag_origin", self.origin, angles );
	
	self thread exit_high_loop_anim( e_move );
	
	// Move the tag origin downward.
	distance = n_target_height - n_cur_height;
	initialSpeed = bundle.DropSpeed;
	acceleration = 385.8;  // Gravity in inches/second^2
	
	// Kinematic Equation to compute distance given, time, velocity, and acceleration.
	// distance = velocity(init) * time + (1/2) * acceleration * time^2;
	
	// Use the quadratic equation to solve for time.
	n_fall_time = ( -initialSpeed + Sqrt( Pow( initialSpeed, 2 ) - 2 * acceleration * distance ) ) / acceleration;
	
	self notify( "falling", n_fall_time );
	
	forward_euler_integration( e_move, v_target_landing, bundle.DropSpeed );
	
	e_move waittill( "movedone" );
	
	self notify( "landing" );
	
	self animation::set_death_anim( self.rider_info.ExitHighLandDeathAnim );
	animation::play( self.rider_info.ExitHighLandAnim, e_move, "tag_origin" );
	
	self notify( "landed" );
	
	self Unlink();
	
	WAIT_SERVER_FRAME;
	
	// Detach from tag origin and delete.
	e_move Delete();
}

function exit_high_loop_anim( e_parent )
{
	self endon( "death" );
	self endon( "landing" );
	
	while ( true )
	{
		animation::play( self.rider_info.ExitHighLoopAnim, e_parent, "tag_origin" );
	}
}

function get_height( e_ignore )
{
	DEFAULT( e_ignore, self );
	
	const height_diff = 10;
	trace = GroundTrace( self.origin + (0,0,height_diff), self.origin + ( 0, 0, -10000 ), false, e_ignore, false );
	
	return Distance( self.origin, trace[ "position" ] );
}

function get_bundle()
{
	Assert( isdefined( self.vehicleridersbundle ), "No vehicleriders bundle specified for this vehicle (in the vehiclesettings gdt)." );
	return struct::get_script_bundle( "vehicleriders", self.vehicleridersbundle );
}

function get_robot_bundle()
{
	Assert( isdefined( self.vehicleridersrobotbundle ), "No vehicleriders robot bundle specified for this vehicle (in the vehiclesettings gdt)." );
	return struct::get_script_bundle( "vehicleriders", self.vehicleridersrobotbundle );
}

/@
"Summary: Get a specific rider from a vehicle.  Look at vehiclerider GDT for possible positions."
"Name: get_rider( str_pos )"
"CallOn: Vehicle"
"MandatoryArg: <str_group> The rider position to unload."
"Example: ai_rider = vh_truck vehicle::get_rider( "passenger1" );"
@/
function get_rider( str_pos )  // self = vehicle
{
	if ( isdefined( self.riders ) )
	{
		foreach ( ai in self.riders )
		{
			if ( IsDefined( ai ) && ( ai.rider_info.position == str_pos ) )
			{
				return ai;
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Private
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function private _init_rider( vh, str_pos )
{
	Assert( isdefined( self.vehicle ) || isdefined( vh ), "No vehicle specified for rider." );
	Assert( isdefined( self.rider_info ) || isdefined( str_pos ), "No position specified for rider." );
	
	if ( isdefined( vh ) )
	{
		self.vehicle = vh;
	}
	
	DEFAULT( str_pos, self.rider_info.position );

	self.rider_info = self get_rider_info( self.vehicle, str_pos );
}
