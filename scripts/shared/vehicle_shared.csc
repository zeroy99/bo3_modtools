#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\vehicleriders_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace vehicle;

REGISTER_SYSTEM( "vehicle_shared", &__init__, undefined )

function __init__()
{
	level._customVehicleCBFunc = &spawned_callback;
		
	clientfield::register( "vehicle", "toggle_lockon",						VERSION_SHIP, 1, "int", &field_toggle_lockon_handler, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_sounds", 						VERSION_SHIP, 1, "int", &field_toggle_sounds, 					!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "use_engine_damage_sounds", 			VERSION_SHIP, 2, "int", &field_use_engine_damage_sounds, 		!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_treadfx", 					VERSION_SHIP, 1, "int", &field_toggle_treadfx, 					!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_exhaustfx", 					VERSION_SHIP, 1, "int", &field_toggle_exhaustfx_handler,		!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_lights", 						VERSION_SHIP, 2, "int", &field_toggle_lights_handler, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_lights_group1", 				VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler1, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_lights_group2", 				VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler2, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_lights_group3", 				VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler3, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_lights_group4", 				VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler4, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_ambient_anim_group1",			VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler1, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_ambient_anim_group2",			VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler2, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_ambient_anim_group3",			VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler3, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_emp_fx",						VERSION_SHIP, 1, "int", &field_toggle_emp,						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "toggle_burn_fx",						VERSION_SHIP, 1, "int", &field_toggle_burn,						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "deathfx", 							VERSION_SHIP, 2, "int", &field_do_deathfx, 						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "alert_level", 						VERSION_SHIP, 2, "int", &field_update_alert_level, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "set_lighting_ent", 					VERSION_SHIP, 1, "int", &util::field_set_lighting_ent, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "use_lighting_ent", 					VERSION_SHIP, 1, "int", &util::field_use_lighting_ent, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "damage_level",						VERSION_SHIP, 3, "int", &field_update_damage_state,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "spawn_death_dynents",				VERSION_SHIP, 2, "int", &field_death_spawn_dynents,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
	clientfield::register( "vehicle", "spawn_gib_dynents",					VERSION_SHIP, 1, "int", &field_gib_spawn_dynents,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
	
	clientfield::register( "helicopter", "toggle_lockon",					VERSION_SHIP, 1, "int", &field_toggle_lockon_handler, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_sounds", 					VERSION_SHIP, 1, "int", &vehicle::field_toggle_sounds, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "use_engine_damage_sounds", 		VERSION_SHIP, 2, "int", &field_use_engine_damage_sounds, 		!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_treadfx", 					VERSION_SHIP, 1, "int", &field_toggle_treadfx, 					!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_exhaustfx", 				VERSION_SHIP, 1, "int", &field_toggle_exhaustfx_handler,		!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_lights", 					VERSION_SHIP, 2, "int", &field_toggle_lights_handler, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_lights_group1", 			VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler1, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_lights_group2", 			VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler2, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_lights_group3", 			VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler3, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_lights_group4", 			VERSION_SHIP, 1, "int", &field_toggle_lights_group_handler4, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_ambient_anim_group1",		VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler1, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_ambient_anim_group2",		VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler2, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_ambient_anim_group3",		VERSION_SHIP, 1, "int", &field_toggle_ambient_anim_handler3, 	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_emp_fx",					VERSION_SHIP, 1, "int", &field_toggle_emp,						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "toggle_burn_fx",					VERSION_SHIP, 1, "int", &field_toggle_burn,						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "deathfx", 						VERSION_SHIP, 1, "int", &field_do_deathfx, 						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "alert_level", 					VERSION_SHIP, 2, "int", &field_update_alert_level, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "set_lighting_ent", 				VERSION_SHIP, 1, "int", &util::field_set_lighting_ent, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "use_lighting_ent", 				VERSION_SHIP, 1, "int", &util::field_use_lighting_ent, 			!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "damage_level",					VERSION_SHIP, 3, "int", &field_update_damage_state,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "spawn_death_dynents",				VERSION_SHIP, 2, "int", &field_death_spawn_dynents,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
	clientfield::register( "helicopter", "spawn_gib_dynents",				VERSION_SHIP, 1, "int", &field_gib_spawn_dynents,				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
		
	clientfield::register( "plane", "toggle_treadfx", 						VERSION_SHIP, 1, "int", &field_toggle_treadfx, 					!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "toplayer", "toggle_dnidamagefx", 				VERSION_SHIP, 1, "int", &field_toggle_dnidamagefx, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "toplayer", "toggle_flir_postfx", 				VERSION_SHIP, 2, "int", &toggle_flir_postfxbundle, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );		
	
	clientfield::register( "toplayer", "static_postfx", 					VERSION_SHIP, 1, "int", &set_static_postfxbundle, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );		
}

function add_vehicletype_callback( vehicletype, callback )
{
	if ( !isdefined( level.vehicleTypeCallbackArray ) )
	{
		level.vehicleTypeCallbackArray = [];
	}
	
	level.vehicleTypeCallbackArray[vehicletype] = callback;
}

function spawned_callback( localClientNum )
{
	if ( isdefined( self.vehicleridersbundle ) )
	{
		set_vehicleriders_bundle( self.vehicleridersbundle );
	}
	
	vehicletype = self.vehicletype;
	if( isdefined( level.vehicleTypeCallbackArray ) )
	{
		if ( isdefined( vehicletype ) && isdefined( level.vehicleTypeCallbackArray[vehicletype] ) )
		{
			self thread [[level.vehicleTypeCallbackArray[vehicletype]]]( localClientNum );
		}
		else if( isdefined( self.scriptvehicletype ) && isdefined( level.vehicleTypeCallbackArray[self.scriptvehicletype] ) )
		{
			self thread [[level.vehicleTypeCallbackArray[self.scriptvehicletype]]]( localClientNum );
		}
	}
}

function rumble( localClientNum )
{
	self endon( "entityshutdown" ); 
			
	if( !isdefined( self.rumbletype ) || ( self.rumbleradius == 0 ) )
	{
		return; 
	}
	
	// Init undefined variables
	if( !isdefined( self.rumbleon ) )
	{
		self.rumbleon = true; 
	}		

	height = self.rumbleradius * 2; 
	zoffset = -1 * self.rumbleradius; 

	self.player_touching = 0; 

	// This is threaded on each vehicle, per local client - so we only need to be concerned with checking on
	// client that we've been threaded on.

	radius_squared = self.rumbleradius * self.rumbleradius; 
	
	wait 2;		// hack to let the getloaclplayers return a valid local player

	while( 1 )
	{
		if( !isdefined( level.localPlayers[localClientNum] ) || ( distancesquared( self.origin, level.localPlayers[localClientNum].origin ) > radius_squared ) || self getspeed() == 0 )
		{
			wait( 0.2 ); 
			continue; 
		}

		if( isdefined( self.rumbleon ) && !self.rumbleon )
		{
			wait( 0.2 ); 
			continue; 			
		}

		self PlayRumbleLoopOnEntity( localClientNum, self.rumbletype ); 

		while( isdefined( level.localPlayers[localClientNum] ) && ( distancesquared( self.origin, level.localPlayers[localClientNum].origin ) < radius_squared ) && ( self getspeed() > 0 ) )
		{
			self earthquake( self.rumblescale, self.rumbleduration, self.origin, self.rumbleradius ); // scale duration source radius
			time_to_wait = self.rumblebasetime + randomfloat( self.rumbleadditionaltime );
			if( time_to_wait <= 0 )
			{
				time_to_wait = 0.05;
			}
			wait( time_to_wait ); 
		}

		if ( isdefined( level.localPlayers[localClientNum] ) )
		{
			self StopRumble( localClientNum, self.rumbletype );
		}
		
		wait 0.05;
	}	
}

function kill_treads_forever()
{
	//PrintLn("****CLIENT:: killing the tread_fx");
	self notify( "kill_treads_forever" ); 
}

function play_exhaust( localClientNum )
{	
	if( isdefined(self.csf_no_exhaust) && self.csf_no_exhaust )
	{
		return;
	}
	
	if( !isdefined( self.exhaust_fx ) && isdefined( self.exhaustfxname ) )
	{
		if( !isdefined( level._effect ) )
		{
			level._effect = [];
		}
		
		if ( !isdefined( level._effect[self.exhaustfxname] ) )
		{
			level._effect[self.exhaustfxname] = self.exhaustfxname;
		}
		self.exhaust_fx = level._effect[self.exhaustfxname];
	}
	
	if( isdefined( self.exhaust_fx ) && isdefined( self.exhaustFxTag1 ) )
	{
		if( isalive(self) )
		{
			Assert( isdefined( self.exhaustFxTag1 ), self.vehicletype + " vehicle exhaust effect is set, but tag 1 is undefined. Please update the vehicle gdt entry" );
			
			self endon( "entityshutdown" );
			
			self wait_for_DObj( localClientNum );
			self.exhaust_id_left = PlayFXOnTag( localClientNum, self.exhaust_fx, self, self.exhaustFxTag1 );
			
			if( !isdefined( self.exhaust_id_right ) && IsDefined( self.exhaustFxTag2 ) )
			{
				self.exhaust_id_right = PlayFXOnTag( localClientNum, self.exhaust_fx, self, self.exhaustFxTag2 );				
			}
				
			self thread kill_exhaust_watcher( localClientNum );				
		}	
	}
}

function kill_exhaust_watcher( localClientNum )
{
	self waittill( "stop_exhaust_fx" );

	if ( isdefined( self.exhaust_id_left ) )
	{
		StopFX( localClientNum, self.exhaust_id_left );
		self.exhaust_id_left = undefined;
	}
	
	if ( isdefined( self.exhaust_id_right ) )
	{
		StopFX( localClientNum, self.exhaust_id_right );
		self.exhaust_id_right = undefined;		
	}
}

function stop_exhaust( localClientNum )
{
	self notify( "stop_exhaust_fx" );
}

function aircraft_dustkick()
{
	waittillframeend;
	
	self endon( "kill_treads_forever" );
	self endon( "entityshutdown" ); 

	if(!IsDefined(self))
	{
		return;
	}
	
	if( isdefined(self.csf_no_tread) && self.csf_no_tread ) //-- set by clientside flag
	{
		return;
	}
		
	const maxHeight = 1200; 
	const minHeight = 350; 

	const slowestRepeatWait = 0.2; 
	const fastestRepeatWait = 0.1; 
	
	if( IS_MIG( self ) ) //-- GLOCKE: added in just for jets for Flash Point
	{
		numFramesPerTrace = 1;
	}
	else
	{
		numFramesPerTrace = 3;
	}
	doTraceThisFrame = numFramesPerTrace; 

	const defaultRepeatRate = 1.0; 
	repeatRate = defaultRepeatRate; 

	trace = undefined; 
	d = undefined; 

	trace_ent = self; 
	
	while( isdefined( self ) )
	{
	
		if( repeatRate <= 0 )
		{
			repeatRate = defaultRepeatRate; 
		}

		if( IS_MIG( self ) ) //-- GLOCKE: added in just for jets for Flash Point
		{
			repeatRate = 0.02; 
		}
		
		waitrealtime( repeatRate ); 	
		
		if( !isdefined( self ) )
		{
			return;
		}
	
		doTraceThisFrame-- ; 

		if( doTraceThisFrame <= 0 )
		{
			doTraceThisFrame = numFramesPerTrace; 

			trace = tracepoint( trace_ent.origin, trace_ent.origin -( 0, 0, 100000 ) ); 

			d = distance( trace_ent.origin, trace["position"] ); 

			if( d > minHeight )
			{
				repeatRate = ( ( d - minHeight ) / ( maxHeight - minHeight ) ) * ( slowestRepeatWait - fastestRepeatWait ) + fastestRepeatWait;
			}
			else
			{
				repeatRate = fastestRepeatWait;
			}				
		}

		if( isdefined( trace ) )
		{
			if( d > maxHeight )
			{
				repeatRate = defaultRepeatRate;
				continue; 
			}

			if( !isdefined( trace["surfacetype"] ) )
			{
				trace["surfacetype"] = "dirt"; 
			}

		}
		
		
	}
}

function weapon_fired()
{
	self endon( "entityshutdown" ); 
	
	const shock_distance = 400 * 400; 
	const rumble_distance = 500 * 500; 
	while( true )
	{
		self waittill( "weapon_fired" ); 
//println( "<<<<<< CSC VEHICLE_WEAPON_FIRED START" );

		players = level.localPlayers; 
		for( i = 0; i < players.size; i++ )
		{
			player_distance = DistanceSquared( self.origin, players[i].origin ); 
//println( "<<<<<< CSC VEHICLE_WEAPON_FIRED PLAYER DISTANCE = " + player_distance );

			// RUMBLE ------------
			if( player_distance < rumble_distance )
			{
				if( isdefined(self.shootrumble) && self.shootrumble != "" )
				{
//println( "<<<<<< CSC VEHICLE_WEAPON_FIRED RUMBLE " + self.shootrumble );
					PlayRumbleOnPosition( i, self.shootrumble, self.origin + ( 0, 0, 32 ) ); 
				}
			}

			// SHOCK -------------
			if( player_distance < shock_distance )
			{
				fraction = player_distance / shock_distance; 
				time = 4 - ( 3 * fraction ); 
			
				if( isdefined( players[i] ) )
				{
					if( isdefined(self.shootshock) && self.shootshock != "" )
					{
//println( "<<<<<< CSC VEHICLE_WEAPON_FIRED SHELLSHOCK " + self.shootshock );
						players[i] ShellShock( i, self.shootshock, time ); 	
					}
				}
			}
		}
	}
}

function wait_for_DObj( localClientNum )
{
	count = 30;
	while( !self HasDObj( localClientNum ) )
	{
		if( count < 0 )
		{
			/#
				IPrintLnBold( "WARNING: Failing to turn on fx lights for vehicle because no DOBJ!" );
			#/
			return;
		}
		WAIT_CLIENT_FRAME;
		count -= 1;
	}
}

function lights_on( localClientNum, team )
{
	self endon( "entityshutdown" );
	
	lights_off( localClientNum );	// make sure we kill all of the old fx
	
	wait_for_DObj( localClientNum );
	
	if( isdefined( self.lightfxnamearray ) )
	{
		if( !isdefined( self.light_fx_handles ) )
		{
			self.light_fx_handles = [];
		}
		
		for( i = 0; i < self.lightfxnamearray.size; i++ )
		{
			self.light_fx_handles[ i ] = PlayFXOnTag( localClientNum, self.lightfxnamearray[i], self, self.lightfxtagarray[i] );
			SetFXIgnorePause( localClientNum, self.light_fx_handles[ i ], true );
			if( IsDefined( team ) )
			{
				SetFXTeam( localClientNum, self.light_fx_handles[ i ], team );
			}
		}
	}
}

function addAnimToList( animItem, &listOn, &listOff, playWhenOff, id, maxID )
{
	if ( isdefined( animItem ) && id <= maxID )
	{
		if ( playWhenOff === true )
		{
			ARRAY_ADD( listOff, animItem );
		}
		else
		{
			ARRAY_ADD( listOn, animItem );
		}
	}
}

function ambient_anim_toggle( localClientNum, groupID, isOn )
{
	self endon( "entityshutdown" );

	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	if ( !isdefined( settings ) )
	{
		return;
	}

	wait_for_DObj( localClientNum );

	listOn = [];
	listOff = [];

	switch ( groupID )
	{
	case 1:
		addAnimToList( settings.ambient_group1_anim1, listOn, listOff, settings.ambient_group1_off1, 1, settings.ambient_group1_numslots );
		addAnimToList( settings.ambient_group1_anim2, listOn, listOff, settings.ambient_group1_off2, 2, settings.ambient_group1_numslots );
		addAnimToList( settings.ambient_group1_anim3, listOn, listOff, settings.ambient_group1_off3, 3, settings.ambient_group1_numslots );
		addAnimToList( settings.ambient_group1_anim4, listOn, listOff, settings.ambient_group1_off4, 4, settings.ambient_group1_numslots );
		break;
	case 2:
		addAnimToList( settings.ambient_group2_anim1, listOn, listOff, settings.ambient_group2_off1, 1, settings.ambient_group2_numslots );
		addAnimToList( settings.ambient_group2_anim2, listOn, listOff, settings.ambient_group2_off2, 2, settings.ambient_group2_numslots );
		addAnimToList( settings.ambient_group2_anim3, listOn, listOff, settings.ambient_group2_off3, 3, settings.ambient_group2_numslots );
		addAnimToList( settings.ambient_group2_anim4, listOn, listOff, settings.ambient_group2_off4, 4, settings.ambient_group2_numslots );
		break;
	case 3:
		addAnimToList( settings.ambient_group3_anim1, listOn, listOff, settings.ambient_group3_off1, 1, settings.ambient_group3_numslots );
		addAnimToList( settings.ambient_group3_anim2, listOn, listOff, settings.ambient_group3_off2, 2, settings.ambient_group3_numslots );
		addAnimToList( settings.ambient_group3_anim3, listOn, listOff, settings.ambient_group3_off3, 3, settings.ambient_group3_numslots );
		addAnimToList( settings.ambient_group3_anim4, listOn, listOff, settings.ambient_group3_off4, 4, settings.ambient_group3_numslots );
		break;
	case 4:
		addAnimToList( settings.ambient_group4_anim1, listOn, listOff, settings.ambient_group4_off1, 1, settings.ambient_group4_numslots );
		addAnimToList( settings.ambient_group4_anim2, listOn, listOff, settings.ambient_group4_off2, 2, settings.ambient_group4_numslots );
		addAnimToList( settings.ambient_group4_anim3, listOn, listOff, settings.ambient_group4_off3, 3, settings.ambient_group4_numslots );
		addAnimToList( settings.ambient_group4_anim4, listOn, listOff, settings.ambient_group4_off4, 4, settings.ambient_group4_numslots );
		break;
	}

	if ( isOn )
	{
		weightOn = 1.0;
		weightOff = 0.0;
	}
	else
	{
		weightOn = 0.0;
		weightOff = 1.0;
	}

	for ( i = 0; i < listOn.size; i++ )
	{
		self SetAnim( listOn[i], weightOn, 0.2, 1.0 );
	}

	for ( i = 0; i < listOff.size; i++ )
	{
		self SetAnim( listOff[i], weightOff, 0.2, 1.0 );
	}
}

function field_toggle_ambient_anim_handler1( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self ambient_anim_toggle( localClientNum, 1, newVal );
}

function field_toggle_ambient_anim_handler2( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self ambient_anim_toggle( localClientNum, 2, newVal );
}

function field_toggle_ambient_anim_handler3( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self ambient_anim_toggle( localClientNum, 3, newVal );
}

function field_toggle_ambient_anim_handler4( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self ambient_anim_toggle( localClientNum, 4, newVal );
}

function lights_group_toggle( localClientNum, id, isOn )
{
	self endon( "entityshutdown" );

	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	if ( !isdefined( settings ) || !isdefined( settings.lightgroups_numGroups ) )
	{
		return;
	}

	wait_for_DObj( localClientNum );

	groupID = id - 1;

	// remove old fx
	if ( isdefined( self.lightfxgroups ) && groupID < self.lightfxgroups.size )
	{
		foreach( fx_handle in self.lightfxgroups[ groupID ] )
		{
			StopFX( localClientNum, fx_handle );
		}
	}

	if ( !isOn )
	{
		return;
	}

	// initialize
	if ( !isdefined( self.lightfxgroups ) )
	{
		self.lightfxgroups = [];
		for ( i = 0; i < settings.lightgroups_numGroups; i++ )
		{
			newfxhandlearray = [];
			ARRAY_ADD( self.lightfxgroups, newfxhandlearray );
		}
	}

	self.lightfxgroups[groupID] = [];

	fxList = [];
	tagList = [];

	switch ( groupID )
	{
	case 0:
		addFxAndTagToLists( settings.lightgroups_1_fx1, settings.lightgroups_1_tag1, fxList, tagList, 1, settings.lightgroups_1_numslots );
		addFxAndTagToLists( settings.lightgroups_1_fx2, settings.lightgroups_1_tag2, fxList, tagList, 2, settings.lightgroups_1_numslots );
		addFxAndTagToLists( settings.lightgroups_1_fx3, settings.lightgroups_1_tag3, fxList, tagList, 3, settings.lightgroups_1_numslots );
		addFxAndTagToLists( settings.lightgroups_1_fx4, settings.lightgroups_1_tag4, fxList, tagList, 4, settings.lightgroups_1_numslots );
		break;
	case 1:
		addFxAndTagToLists( settings.lightgroups_2_fx1, settings.lightgroups_2_tag1, fxList, tagList, 1, settings.lightgroups_2_numslots );
		addFxAndTagToLists( settings.lightgroups_2_fx2, settings.lightgroups_2_tag2, fxList, tagList, 2, settings.lightgroups_2_numslots );
		addFxAndTagToLists( settings.lightgroups_2_fx3, settings.lightgroups_2_tag3, fxList, tagList, 3, settings.lightgroups_2_numslots );
		addFxAndTagToLists( settings.lightgroups_2_fx4, settings.lightgroups_2_tag4, fxList, tagList, 4, settings.lightgroups_2_numslots );
		break;
	case 2:
		addFxAndTagToLists( settings.lightgroups_3_fx1, settings.lightgroups_3_tag1, fxList, tagList, 1, settings.lightgroups_3_numslots );
		addFxAndTagToLists( settings.lightgroups_3_fx2, settings.lightgroups_3_tag2, fxList, tagList, 2, settings.lightgroups_3_numslots );
		addFxAndTagToLists( settings.lightgroups_3_fx3, settings.lightgroups_3_tag3, fxList, tagList, 3, settings.lightgroups_3_numslots );
		addFxAndTagToLists( settings.lightgroups_3_fx4, settings.lightgroups_3_tag4, fxList, tagList, 4, settings.lightgroups_3_numslots );
		break;
	case 3:
		addFxAndTagToLists( settings.lightgroups_4_fx1, settings.lightgroups_4_tag1, fxList, tagList, 1, settings.lightgroups_4_numslots );
		addFxAndTagToLists( settings.lightgroups_4_fx2, settings.lightgroups_4_tag2, fxList, tagList, 2, settings.lightgroups_4_numslots );
		addFxAndTagToLists( settings.lightgroups_4_fx3, settings.lightgroups_4_tag3, fxList, tagList, 3, settings.lightgroups_4_numslots );
		addFxAndTagToLists( settings.lightgroups_4_fx4, settings.lightgroups_4_tag4, fxList, tagList, 4, settings.lightgroups_4_numslots );
		break;
	}

	for ( i = 0; i < fxList.size; i++ )
	{
		fx_handle = PlayFXOnTag( localClientNum, fxList[i], self, tagList[i] );
		ARRAY_ADD( self.lightfxgroups[groupID], fx_handle );
	}
}

function field_toggle_lights_group_handler1( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self lights_group_toggle( localClientNum, 1, newVal );
}
function field_toggle_lights_group_handler2( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self lights_group_toggle( localClientNum, 2, newVal );
}
function field_toggle_lights_group_handler3( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self lights_group_toggle( localClientNum, 3, newVal );
}
function field_toggle_lights_group_handler4( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self lights_group_toggle( localClientNum, 4, newVal );
}

function delete_alert_lights( localClientNum )
{
	if( isdefined( self.alert_light_fx_handles ) )
	{
		for( i = 0; i < self.alert_light_fx_handles.size; i++ )
		{
			StopFX( localClientNum, self.alert_light_fx_handles[ i ] );
		}
	}
	
	self.alert_light_fx_handles = undefined;
}

function lights_off( localClientNum )
{
	if( isdefined( self.light_fx_handles ) )
	{
		for( i = 0; i < self.light_fx_handles.size; i++ )
		{
			StopFX( localClientNum, self.light_fx_handles[ i ] );
		}
	}
	
	self.light_fx_handles = undefined;
	
	delete_alert_lights( localClientNum );
}

function field_toggle_emp( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self thread toggle_fx_bundle( localClientNum, "emp_base", newVal == 1 );
}

function field_toggle_burn( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self thread toggle_fx_bundle( localClientNum, "burn_base", newVal == 1 );
}

function toggle_fx_bundle( localClientNum, name, turnOn )
{
	if( !isdefined( self.settings ) && isdefined( self.scriptbundlesettings ) )
	{
		self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}

	if( !isdefined( self.settings ) )
	{
		return;
	}

	self endon( "entityshutdown" );
	self notify( "end_toggle_field_fx_" + name );
	self endon( "end_toggle_field_fx_" + name );
	wait_for_DObj( localClientNum );

	if ( !isdefined( self.fx_handles ) )
	{
		self.fx_handles = [];
	}

	if ( isdefined( self.fx_handles[ name ] ) )
	{
		handle = self.fx_handles[ name ];
		if ( IsArray( handle ) )
		{
			foreach( handleElement in handle )
			{
				StopFX( localClientNum, handleElement );
			}
		}
		else
		{
			StopFX( localClientNum, handle );
		}
	}
	
	if( turnOn )
	{
		for( i = 1; ; i++ )
		{
			fx = GetStructField( self.settings, name + "_fx_" + i );
			if ( !isdefined( fx ) )
			{
				return;
			}
			tag = GetStructField( self.settings, name + "_tag_" + i );
			delay = GetStructField( self.settings, name + "_delay_" + i );
			self thread delayed_fx_thread( localClientNum, name, fx, tag, delay );
		}
	}
}

function delayed_fx_thread( localClientNum, name, fx, tag, delay )
{
	self endon( "entityshutdown" );
	self endon( "end_toggle_field_fx_" + name );
	
	if ( !isdefined( tag ) )
	{
		return;
	}

	if ( isdefined( delay ) && delay > 0 )
	{
		wait delay;
	}

	fx_handle = PlayFxOnTag( localClientNum, fx, self, tag );
	ARRAY_ADD( self.fx_handles[ name ], fx_handle );
}

function field_toggle_sounds( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( IS_HELICOPTER( self ) )	
	{
		if(newVal)
		{
			self notify( "stop_heli_sounds" );
			self.should_not_play_sounds = true;			
		}
		else
		{
			self notify( "play_heli_sounds" );
			self.should_not_play_sounds = false;
		}
	}

	if(newVal)
	{
		self disablevehiclesounds();
	}
	else
	{
		self enablevehiclesounds();
	}
}

function field_toggle_dnidamagefx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{			
	if( newVal )
	{
		self thread postfx::PlayPostfxBundle( "pstfx_dni_vehicle_dmg" );
	}
}

function toggle_flir_postfxbundle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{		
	player = self;
	if( newval == oldVal )
		return;
	
	if( !isdefined( player ) || !( player IsLocalPlayer() ) )
		return;
	
	if( newVal == 0 )
	{
		player thread postfx::stopPlayingPostfxBundle();
		update_ui_fullscreen_filter_model( localClientNum, 0 );
	} 
	else if( newVal == 1 )
	{		    
		if ( player ShouldChangeScreenPostFx( localClientNum ) )
		{
			player thread postfx::PlayPostfxBundle( "pstfx_infrared" );
			update_ui_fullscreen_filter_model( localClientNum, 2 );
		}
	} 
	else if( newVal == 2 )
	{
		should_change = true;


		if ( player ShouldChangeScreenPostFx( localClientNum ) )
		{
			player thread postfx::PlayPostfxBundle( "pstfx_flir" );
			update_ui_fullscreen_filter_model( localClientNum, 1 );
		}
	}	
}

function ShouldChangeScreenPostFx( localClientNum )
{
	player = self;

	assert( isdefined( player ) );
	
	if ( player GetInKillCam( localClientNum ) )
	{
		killCamEntity = player GetKillCamEntity( localClientNum );
		if ( isdefined( killCamEntity ) && ( killCamEntity != player ) )
	    	return false;
	}
	
	return true;
}

function set_static_postfxbundle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = self;
	if( newval == oldVal )
		return;
	
	if( !isdefined( player ) || !( player IsLocalPlayer() ) )
		return;
	
	if( newVal == 0 )
	{
		player thread postfx::stopPlayingPostfxBundle();
	} 
	else if( newVal == 1 )
	{
		player thread postfx::PlayPostfxBundle( "pstfx_static" );
	} 
}

function update_ui_fullscreen_filter_model( localClientNum, vision_set_value )
{
	//note: use the VEHICLE_VISION_SET enum to determine values to use
	controllerModel = GetUIModelForController( localClientNum );
    model = GetUIModel( controllerModel, "vehicle.fullscreenFilter" );
    if ( isdefined( model ) )
    {
    	SetUIModelValue( model, vision_set_value );
    }
}

function field_toggle_treadfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	
	if( IS_HELICOPTER( self )  || IS_PLANE( self ) )
	{
		/#PrintLn("****CLIENT:: Vehicle Flag Plane");#/
		
		if(newVal)
		{
			if(isdefined(bNewEnt) && bNewEnt)
			{ 
			  self.csf_no_tread = true;
			}
			else
			{
				self kill_treads_forever();
			}			
		}
		else		// Flag being cleared.
		{
			if(isdefined(self.csf_no_tread))
			{
				self.csf_no_tread = false;
			}
			self kill_treads_forever();
			self thread aircraft_dustkick();
		}
	}
	else	// Non-helicopter version...
	{
		if(newVal)
		{
			/#PrintLn("****CLIENT:: Vehicle Flag Tread FX Set");#/
			if(isdefined(bNewEnt) && bNewEnt)
			{ 
				/#PrintLn("****CLIENT:: TreadFX NewEnt: " + self GetEntityNumber());#/
			  self.csf_no_tread = true;
			}
			else
			{
				/#PrintLn("****CLIENT:: TreadFX OldEnt"  + self GetEntityNumber());#/
				self kill_treads_forever();
			}
		}
		else	// Flag being cleared.
		{
			/#PrintLn("****CLIENT:: Vehicle Flag Tread FX Clear");#/
			if(isdefined(self.csf_no_tread))
			{
				self.csf_no_tread = false;
			}
			self kill_treads_forever();		
		}
	}
}

function field_use_engine_damage_sounds( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( IS_HELICOPTER( self ) )
	{
		switch ( newVal )
		{
			case 0:
				{
					self.engine_damage_low = false;
					self.engine_damage_high = false;
				} break;
			case 1: // Low
				{
					self.engine_damage_low = true;
					self.engine_damage_high = false;
				} break;
			case 1: // High
				{
					self.engine_damage_low = false;
					self.engine_damage_high = true;
				} break;
		}
		//TODO T7 - bring this over from SP if we need it
		//self helicopter_sounds::update_helicopter_sounds();
	}
}

function field_do_deathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "entityshutdown" );

	if ( newVal == 2 ) // EMP specific death
	{
		self field_do_empdeathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
	}
	else
	{
		self field_do_standarddeathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
	}
}

function field_do_standarddeathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal && !bInitialSnap )
	{
		wait_for_DObj( localClientNum );
		
		if( isdefined( self.deathfxname ) )
		{
			if ( isdefined( self.deathfxtag ) && self.deathfxtag != "" )
			{
				handle = PlayFXOnTag( localClientNum, self.deathfxname, self, self.deathfxtag );
			}
			else
			{
				handle = PlayFX( localClientNum, self.deathfxname, self.origin );
			}
			SetFXIgnorePause( localClientNum, handle, true );
		}
		
		self PlaySound( localClientNum, self.deathfxsound );
		
		if ( isdefined( self.deathquakescale ) && self.deathquakescale > 0 )
		{
			self Earthquake( self.deathquakescale, self.deathquakeduration, self.origin, self.deathquakeradius );
		}
	}
}

function field_do_empdeathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( !isdefined( self.settings ) && isdefined( self.scriptbundlesettings ) )
	{
		self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}

	if( !isdefined( self.settings ) )
	{
		self field_do_standarddeathfx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
		return;
	}	

	if( newVal && !bInitialSnap )
	{
		wait_for_DObj( localClientNum );
		
		s = self.settings;
		
		if( isdefined( s.emp_death_fx_1 ) )
		{
			if ( isdefined( s.emp_death_tag_1 ) && s.emp_death_tag_1 != "" )
			{
				handle = PlayFXOnTag( localClientNum, s.emp_death_fx_1, self, s.emp_death_tag_1 );
			}
			else
			{
				handle = PlayFX( localClientNum, s.emp_death_tag_1, self.origin );
			}
			SetFXIgnorePause( localClientNum, handle, true );
		}
		
		self PlaySound( localClientNum, s.emp_death_sound_1 );
		
		// TODO: perhaps we want to make emp death quake settings
		if ( isdefined( self.deathquakescale ) && self.deathquakescale > 0 )
		{
			self Earthquake( self.deathquakescale * 0.25, self.deathquakeduration * 2.0, self.origin, self.deathquakeradius );
		}
	}
}

function field_update_alert_level( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	vehicle::delete_alert_lights( localClientNum );
	
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}
	
	if( !isdefined( self.alert_light_fx_handles ) )
	{
		self.alert_light_fx_handles = [];
	}
	
	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	switch( newVal )
	{
		case 0: 
			break;
		case 1:
			if( isdefined( settings.unawarelightfx1 ) )
			{
				self.alert_light_fx_handles[ 0 ] = PlayFXOnTag( localClientNum, settings.unawarelightfx1, self, settings.lighttag1 );
			}
			break;
		case 2:
			if( isdefined( settings.alertlightfx1 ) )
			{
				self.alert_light_fx_handles[ 0 ] = PlayFXOnTag( localClientNum, settings.alertlightfx1, self, settings.lighttag1 );
			}
			break;
		case 3:
			if( isdefined( settings.combatlightfx1 ) )
			{
				self.alert_light_fx_handles[ 0 ] = PlayFXOnTag( localClientNum, settings.combatlightfx1, self, settings.lighttag1 );
			}
			break;
	}
	
}

function field_toggle_exhaustfx_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(newVal)
	{
		if(isdefined(bNewEnt) && bNewEnt)
		{ 
			self.csf_no_exhaust = true;
		}
		else
		{
			self stop_exhaust( localClientNum );
		}		
	}
	else
	{
		if(isdefined(self.csf_no_exhaust))
		{
			self.csf_no_exhaust = false;
		}
		self stop_exhaust( localClientNum );
		
		self play_exhaust( localClientNum );
	}
}

function control_lights_groups( localClientNum, on )
{
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	if ( !isdefined( settings ) || !isdefined( settings.lightgroups_numGroups ) )
	{
		return;
	}

	if ( settings.lightgroups_numGroups >= 1 && settings.lightgroups_1_always_on !== true )
	{
		lights_group_toggle( localClientNum, 1, on );
	}
	if ( settings.lightgroups_numGroups >= 2 && settings.lightgroups_2_always_on !== true )
	{
		lights_group_toggle( localClientNum, 2, on );
	}
	if ( settings.lightgroups_numGroups >= 3 && settings.lightgroups_3_always_on !== true )
	{
		lights_group_toggle( localClientNum, 3, on );
	}
	if ( settings.lightgroups_numGroups >= 4 && settings.lightgroups_4_always_on !== true )
	{
		lights_group_toggle( localClientNum, 4, on );
	}
}

function field_toggle_lights_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//lights:
	//0 - turn on normal
	//1 - turn off
	//2 - override to allied color
	//3 - override to axis color
	
	if( newVal == 1 )
	{
		self lights_off( localClientNum );
	}
	else	// Flag being cleared.
	{
		if( newVal == 2 )
		{
			self lights_on( localClientNum, "allies" );
		}
		else if( newVal == 3 )
		{
			self lights_on( localClientNum, "axis" );
		}
		else
		{
			self lights_on( localClientNum );
		}
	}

	control_lights_groups( localClientNum, newVal != 1 );
}

function field_toggle_lockon_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//TODO T7 - work with code to get this back if needed
	/*if(newVal)
	{
		self SetVehicleLockedOn( true );
	}
	else
	{
		self SetVehicleLockedOn( false );		
	}*/
}

function addFxAndTagToLists( fx, tag, &fxList, &tagList, id, maxID )
{
	if ( isdefined( fx ) && isdefined( tag ) && id <= maxID )
	{
		ARRAY_ADD( fxList, fx );
		ARRAY_ADD( tagList, tag );
	}
}

function field_update_damage_state( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );

	if ( isdefined( self.damage_state_fx_handles ) )
	{
		foreach( fx_handle in self.damage_state_fx_handles )
		{
			StopFX( localClientNum, fx_handle );
		}
	}

	self.damage_state_fx_handles = [];

	fxList = [];
	tagList = [];
	sound = undefined;

	switch( newVal )
	{
		case 0: 
			break;
		case 1:
			addFxAndTagToLists( settings.damagestate_lv1_fx1, settings.damagestate_lv1_tag1, fxList, tagList, 1, settings.damagestate_lv1_numslots );
			addFxAndTagToLists( settings.damagestate_lv1_fx2, settings.damagestate_lv1_tag2, fxList, tagList, 2, settings.damagestate_lv1_numslots );
			addFxAndTagToLists( settings.damagestate_lv1_fx3, settings.damagestate_lv1_tag3, fxList, tagList, 3, settings.damagestate_lv1_numslots );
			addFxAndTagToLists( settings.damagestate_lv1_fx4, settings.damagestate_lv1_tag4, fxList, tagList, 4, settings.damagestate_lv1_numslots );
			sound = settings.damagestate_lv1_sound;
			break;
		case 2:
			addFxAndTagToLists( settings.damagestate_lv2_fx1, settings.damagestate_lv2_tag1, fxList, tagList, 1, settings.damagestate_lv2_numslots );
			addFxAndTagToLists( settings.damagestate_lv2_fx2, settings.damagestate_lv2_tag2, fxList, tagList, 2, settings.damagestate_lv2_numslots );
			addFxAndTagToLists( settings.damagestate_lv2_fx3, settings.damagestate_lv2_tag3, fxList, tagList, 3, settings.damagestate_lv2_numslots );
			addFxAndTagToLists( settings.damagestate_lv2_fx4, settings.damagestate_lv2_tag4, fxList, tagList, 4, settings.damagestate_lv2_numslots );
			sound = settings.damagestate_lv2_sound;
			break;
		case 3:
			addFxAndTagToLists( settings.damagestate_lv3_fx1, settings.damagestate_lv3_tag1, fxList, tagList, 1, settings.damagestate_lv3_numslots );
			addFxAndTagToLists( settings.damagestate_lv3_fx2, settings.damagestate_lv3_tag2, fxList, tagList, 2, settings.damagestate_lv3_numslots );
			addFxAndTagToLists( settings.damagestate_lv3_fx3, settings.damagestate_lv3_tag3, fxList, tagList, 3, settings.damagestate_lv3_numslots );
			addFxAndTagToLists( settings.damagestate_lv3_fx4, settings.damagestate_lv3_tag4, fxList, tagList, 4, settings.damagestate_lv3_numslots );
			sound = settings.damagestate_lv3_sound;
			break;
		case 4:
			addFxAndTagToLists( settings.damagestate_lv4_fx1, settings.damagestate_lv4_tag1, fxList, tagList, 1, settings.damagestate_lv4_numslots );
			addFxAndTagToLists( settings.damagestate_lv4_fx2, settings.damagestate_lv4_tag2, fxList, tagList, 2, settings.damagestate_lv4_numslots );
			addFxAndTagToLists( settings.damagestate_lv4_fx3, settings.damagestate_lv4_tag3, fxList, tagList, 3, settings.damagestate_lv4_numslots );
			addFxAndTagToLists( settings.damagestate_lv4_fx4, settings.damagestate_lv4_tag4, fxList, tagList, 4, settings.damagestate_lv4_numslots );
			sound = settings.damagestate_lv4_sound;
			break;
		case 5:
			addFxAndTagToLists( settings.damagestate_lv5_fx1, settings.damagestate_lv5_tag1, fxList, tagList, 1, settings.damagestate_lv5_numslots );
			addFxAndTagToLists( settings.damagestate_lv5_fx2, settings.damagestate_lv5_tag2, fxList, tagList, 2, settings.damagestate_lv5_numslots );
			addFxAndTagToLists( settings.damagestate_lv5_fx3, settings.damagestate_lv5_tag3, fxList, tagList, 3, settings.damagestate_lv5_numslots );
			addFxAndTagToLists( settings.damagestate_lv5_fx4, settings.damagestate_lv5_tag4, fxList, tagList, 4, settings.damagestate_lv5_numslots );
			sound = settings.damagestate_lv5_sound;
			break;
		case 6:
			addFxAndTagToLists( settings.damagestate_lv6_fx1, settings.damagestate_lv6_tag1, fxList, tagList, 1, settings.damagestate_lv6_numslots );
			addFxAndTagToLists( settings.damagestate_lv6_fx2, settings.damagestate_lv6_tag2, fxList, tagList, 2, settings.damagestate_lv6_numslots );
			addFxAndTagToLists( settings.damagestate_lv6_fx3, settings.damagestate_lv6_tag3, fxList, tagList, 3, settings.damagestate_lv6_numslots );
			addFxAndTagToLists( settings.damagestate_lv6_fx4, settings.damagestate_lv6_tag4, fxList, tagList, 4, settings.damagestate_lv6_numslots );
			sound = settings.damagestate_lv6_sound;
			break;
	}

	for( i = 0; i < fxList.size; i++ )
	{
		fx_handle = PlayFXOnTag( localClientNum, fxList[i], self, tagList[i] );
		ARRAY_ADD( self.damage_state_fx_handles, fx_handle );
	}

	if ( isdefined( self ) && isdefined( sound ) )
	{
		self PlaySound( localClientNum, sound );
	}
}

function field_death_spawn_dynents( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	if( localClientNum == 0 )	// dynents are shared between clients
	{
		velocity = self GetVelocity();
		
		numDynents = VAL( settings.death_dynent_count, 0 );
		for( i = 0; i < numDynents; i++ )
		{
			model = GetStructField( settings, "death_dynmodel" + i );

			if( !isdefined( model ) )
				continue;
			
			gibpart = GetStructField( settings, "death_dynent_gib" + i );
			if ( self.gibbed === true && gibpart === true )
				continue;
			
			pitch = VAL( GetStructField( settings, "death_dynent_force_pitch" + i ), 0 );
			yaw = VAL( GetStructField( settings, "death_dynent_force_yaw" + i ), 0 );
			angles = ( RandomFloatRange( pitch - 15, pitch + 15 ), RandomFloatRange( yaw - 20, yaw + 20 ), RandomFloatRange( -20, 20 ) );
			direction = AnglesToForward( self.angles + angles );

			minscale = VAL( GetStructField( settings, "death_dynent_force_minscale" + i ), 0 );
			maxscale = VAL( GetStructField( settings, "death_dynent_force_maxscale" + i ), 0 );

			force = direction * RandomFloatRange( minscale, maxscale );

			offset = ( VAL( GetStructField( settings, "death_dynent_offsetX" + i ), 0 ),
					   VAL( GetStructField( settings, "death_dynent_offsetY" + i ), 0 ),
					   VAL( GetStructField( settings, "death_dynent_offsetZ" + i ), 0 ) );

			switch( newVal )
			{
			case 0: // no FX
				break;
			case 1:
				fx = GetStructField( settings, "death_dynent_fx" + i );
				break;
			case 2: // EMP FX
				fx = GetStructField( settings, "death_dynent_elec_fx" + i );
				break;
			case 3: // Burn FX
				fx = GetStructField( settings, "death_dynent_fire_fx" + i );
				break;
			}
			
			offset = RotatePoint( offset, self.angles );

			if ( newVal > 1 && isdefined( fx ) )
			{
				dynent = CreateDynEntAndLaunch( localClientNum, model, self.origin + offset, self.angles, (0,0,0), velocity * 0.8, fx );
			}
			else if ( newVal == 1 && isdefined( fx ) )
			{
				dynent = CreateDynEntAndLaunch( localClientNum, model, self.origin + offset, self.angles, (0,0,0), velocity * 0.8, fx );
			}
			else
			{
				dynent = CreateDynEntAndLaunch( localClientNum, model, self.origin + offset, self.angles, (0,0,0), velocity * 0.8 );
			}

			if ( isdefined( dynent ) )
			{
				hitOffset = ( randomFloatRange( -5, 5 ), randomFloatRange( -5, 5 ), randomFloatRange( -5, 5 ) );
				LaunchDynent( dynent, force, hitOffset );
			}
		}
	}
}

function field_gib_spawn_dynents( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( !isdefined( self.scriptbundlesettings ) )
	{
		return;
	}

	settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	
	if( localClientNum == 0 )	// dynents are shared between clients
	{
		velocity = self GetVelocity();
		
		numDynents = 2;
		for( i = 0; i < numDynents; i++ )
		{
			model = GetStructField( settings, "servo_gib_model" + i );

			if( !isdefined( model ) )
			{
				return;
			}

			self.gibbed = true; // prevent gibbed death part from spawning on death

			origin = self.origin;
			angles = self.angles;
			hidetag = GetStructField( settings, "servo_gib_tag" + i );
			if ( isdefined( hidetag ) )
			{
				origin = self GetTagOrigin( hidetag );
				angles = self GetTagAngles( hidetag );
			}

			pitch = VAL( GetStructField( settings, "servo_gib_force_pitch" + i ), 0 );
			yaw = VAL( GetStructField( settings, "servo_gib_force_yaw" + i ), 0 );
			relative_angles = ( RandomFloatRange( pitch - 5, pitch + 5 ), RandomFloatRange( yaw - 5, yaw + 5 ), RandomFloatRange( -5, 5 ) );
			direction = AnglesToForward( angles + relative_angles );

			minscale = VAL( GetStructField( settings, "servo_gib_force_minscale" + i ), 0 );
			maxscale = VAL( GetStructField( settings, "servo_gib_force_maxscale" + i ), 0 );

			force = direction * RandomFloatRange( minscale, maxscale );

			offset = ( VAL( GetStructField( settings, "servo_gib_offsetX" + i ), 0 ),
				VAL( GetStructField( settings, "servo_gib_offsetY" + i ), 0 ),
				VAL( GetStructField( settings, "servo_gib_offsetZ" + i ), 0 ) );

			fx = GetStructField( settings, "servo_gib_fx" + i );

			offset = RotatePoint( offset, angles );

			if ( isdefined( fx ) )
			{
				dynent = CreateDynEntAndLaunch( localClientNum, model, origin + offset, angles, (0,0,0), velocity * 0.8, fx );
			}
			else
			{
				dynent = CreateDynEntAndLaunch( localClientNum, model, origin + offset, angles, (0,0,0), velocity * 0.8 );
			}

			if ( isdefined( dynent ) )
			{
				hitOffset = ( randomFloatRange( -5, 5 ), randomFloatRange( -5, 5 ), randomFloatRange( -5, 5 ) );
				LaunchDynent( dynent, force, hitOffset );
			}
		}
	}
}

//-----------------------------------------------------------------------------
//
// Generic Full-Screen Damage Filter System
//
//-----------------------------------------------------------------------------

#define MIN_FILTER_INTENSITY 0.5
#define MAX_FILTER_INTENSITY 1
#define FILTER_FADE_IN_TIME 0.1
#define FILTER_FADE_OUT_TIME 0.33
#define FILTER_FADE_IN_RATE MIN_FILTER_INTENSITY / FILTER_FADE_IN_TIME	
#define FILTER_FADE_OUT_RATE MAX_FILTER_INTENSITY / FILTER_FADE_OUT_TIME
#define FILTER_DT 0.016667

// yuck
function autoexec build_damage_filter_list()
{
	if ( !isdefined( level.vehicle_damage_filters ) )
	{
		level.vehicle_damage_filters = [];
	}

	level.vehicle_damage_filters[ 0 ] = "generic_filter_vehicle_damage";
	level.vehicle_damage_filters[ 1 ] = "generic_filter_sam_damage";	
	level.vehicle_damage_filters[ 2 ] = "generic_filter_f35_damage";		
   	level.vehicle_damage_filters[ 3 ] = "generic_filter_vehicle_damage_sonar";
   	level.vehicle_damage_filters[ 4 ] = "generic_filter_rts_vehicle_damage";
}
	
function init_damage_filter( materialid )
{
	level.localPlayers[0].damage_filter_intensity = 0;
	
	materialname = level.vehicle_damage_filters[ materialid ];
	
	filter::init_filter_vehicle_damage( level.localPlayers[0], materialname );
	filter::enable_filter_vehicle_damage( level.localPlayers[0], FILTER_INDEX_VEHICLE, materialname );	
	filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE, 0 );
	filter::set_filter_vehicle_sun_position( level.localPlayers[0], FILTER_INDEX_VEHICLE, 0, 0 );
}

function damage_filter_enable( localClientNum, materialid )
{
	filter::enable_filter_vehicle_damage( level.localPlayers[0], FILTER_INDEX_VEHICLE, level.vehicle_damage_filters[ materialid ] );	
	
	level.localPlayers[0].damage_filter_intensity = 0;
	filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE,	level.localPlayers[0].damage_filter_intensity );	
}

function damage_filter_disable( localClientNum )
{
	level notify( "damage_filter_off" );
	
	level.localPlayers[0].damage_filter_intensity = 0;
	filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE, level.localPlayers[0].damage_filter_intensity );		
	
	filter::disable_filter_vehicle_damage( level.localPlayers[0], FILTER_INDEX_VEHICLE );		

}

function damage_filter_off( localClientNum )
{
	level endon( "damage_filter" );
	level endon( "damage_filter_off" );	
	level endon( "damage_filter_heavy" );
	
	if(!isdefined(level.localPlayers[0].damage_filter_intensity ))
		return;
		
	while ( level.localPlayers[0].damage_filter_intensity > 0 )
	{
		level.localPlayers[0].damage_filter_intensity -= FILTER_FADE_OUT_RATE * FILTER_DT;
		if ( level.localPlayers[0].damage_filter_intensity < 0 )
			level.localPlayers[0].damage_filter_intensity = 0;
			
		filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE, level.localPlayers[0].damage_filter_intensity );		
			
		wait( FILTER_DT );
	}
}

function damage_filter_light( localClientNum )
{
	level endon( "damage_filter_off" );
	level endon( "damage_filter_heavy" );
	
	level notify( "damage_filter" );
	
	while ( level.localPlayers[0].damage_filter_intensity < MIN_FILTER_INTENSITY )
	{
		level.localPlayers[0].damage_filter_intensity += FILTER_FADE_IN_RATE * FILTER_DT;
		if ( level.localPlayers[0].damage_filter_intensity > MIN_FILTER_INTENSITY )
			level.localPlayers[0].damage_filter_intensity = MIN_FILTER_INTENSITY;
		
		filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE, level.localPlayers[0].damage_filter_intensity );				
		
		wait( FILTER_DT );
	}	
}

function damage_filter_heavy( localClientNum )
{
	level endon( "damage_filter_off" );	
	
	level notify( "damage_filter_heavy" );			
		
	while ( level.localPlayers[0].damage_filter_intensity < MAX_FILTER_INTENSITY )
	{
		level.localPlayers[0].damage_filter_intensity += FILTER_FADE_IN_RATE * FILTER_DT;
		if ( level.localPlayers[0].damage_filter_intensity > MAX_FILTER_INTENSITY )
			level.localPlayers[0].damage_filter_intensity = MAX_FILTER_INTENSITY;
		
		filter::set_filter_vehicle_damage_amount( level.localPlayers[0], FILTER_INDEX_VEHICLE, level.localPlayers[0].damage_filter_intensity );				
		
		wait( FILTER_DT );
	}		
}

