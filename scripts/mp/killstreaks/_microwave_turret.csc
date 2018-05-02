#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;

#precache( "client_fx", "killstreaks/fx_sg_distortion_cone_ash" );
#precache( "client_fx", "killstreaks/fx_sg_distortion_cone_ash_sm" );

#using_animtree( "mp_microwaveturret" );

#define MICROWAVE_TURRET_ROW_SPREAD					( 150 )
#define MICROWAVE_TURRET_FX_SIZE					( 200 )
#define MICROWAVE_TURRET_FX_HALF_SIZE				( 125 )
#define MICROWAVE_TURRET_FX_TRACE					( MICROWAVE_TURRET_RADIUS + 40 )
#define MICROWAVE_TURRET_FX							"killstreaks/fx_sg_distortion_cone_ash"
#define MICROWAVE_TURRET_FX_HALF					"killstreaks/fx_sg_distortion_cone_ash_sm"
#define MICROWAVE_TURRET_STUN_FX					"killstreaks/fx_sg_emp_stun"
#define MICROWAVE_TURRET_FX_TRACE_ANGLE				( 55 )
#define MICROWAVE_TURRET_FX_CHECK_TIME				( 1.0 )

#namespace microwave_turret;

REGISTER_SYSTEM( "microwave_turret", &__init__, undefined )

function __init__()
{
	clientfield::register( "vehicle", "turret_microwave_open", VERSION_SHIP, 1, "int", &microwave_open, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "turret_microwave_init", VERSION_SHIP, 1, "int", &microwave_init_anim, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "turret_microwave_close", VERSION_SHIP, 1, "int", &microwave_close_anim, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function turret_microwave_sounds( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == MICROWAVE_TURRET_START_SOUND )
	{
		self thread turret_microwave_sound_start( localClientNum );
	}
	else if( newVal == MICROWAVE_TURRET_STOP_SOUND )
	{
		self notify( "sound_stop" );
	}
}

function turret_microwave_sound_start( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "sound_stop" );
	
	if ( IS_TRUE( self.sound_loop_enabled ) )
		return;

	self playsound ( 0, "wpn_micro_turret_start");

	wait 0.7; // wait until deploy animation is finished
	
	origin = self GetTagOrigin( "tag_flash" );
	angles = self GetTagAngles( "tag_flash" );

	forward = AnglesToForward( angles );
	forward = VectorScale( forward, 750 );

	trace = BulletTrace( origin, origin + forward, false, self );

	start = origin;
	end = trace[ "position" ];
		
	self.microwave_audio_start = start;
	self.microwave_audio_end = end;
	self thread turret_microwave_sound_updater();
	
	if ( !IS_TRUE( self.sound_loop_enabled ) )
	{
		self.sound_loop_enabled = true;
		soundLineEmitter( "wpn_micro_turret_loop", self.microwave_audio_start, self.microwave_audio_end );
		self thread turret_microwave_sound_off_waiter( localClientNum );
	}
}

function turret_microwave_sound_off_waiter( localClientNum )
{
	msg = self util::waittill_any( "sound_stop", "entityshutdown" );
	
	if ( IS_EQUAL( msg, "sound_stop" ) )
		playsound (0, "wpn_micro_turret_stop", self.microwave_audio_start);
	
	soundStopLineEmitter ( "wpn_micro_turret_loop", self.microwave_audio_start, self.microwave_audio_end );
	
	if ( isdefined( self ) )
	{
		self.sound_loop_enabled = false;
	}
}

function turret_microwave_sound_updater()
{
	self endon( "beam_stop" );
	self endon( "entityshutdown" );
	
	while( 1 )
	{
		origin = self GetTagOrigin( "tag_flash" );

		if ( origin[0] != self.microwave_audio_start[0] || origin[1] != self.microwave_audio_start[1] || origin[2] != self.microwave_audio_start[2] )
		{
			previousStart = self.microwave_audio_start;
			previousEnd = self.microwave_audio_end;

			angles = self GetTagAngles( "tag_flash" );
		
			forward = AnglesToForward( angles );
			forward = VectorScale( forward, 750 );
		
			trace = BulletTrace( origin, origin + forward, false, self );
	
			self.microwave_audio_start = origin;
			self.microwave_audio_end = trace[ "position" ];

			soundUpdateLineEmitter( "wpn_micro_turret_loop", previousStart, previousEnd, self.microwave_audio_start, self.microwave_audio_end );
		}
		
		wait 0.1;
	}
}

function microwave_init_anim( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;
	
	self UseAnimTree( #animtree );
	self SetAnimRestart( %o_turret_guardian_close, 1.0, 0.0, 1.0 );
	self SetAnimTime( %o_turret_guardian_close, 1.0 );
}

function microwave_open( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
	{
		self UseAnimTree( #animtree );
		self SetAnim( %o_turret_guardian_open, 0.0 ); // stop open anim
		self SetAnimRestart( %o_turret_guardian_close, 1.0, 0.0, 1.0 );
	
		self notify( "beam_stop" );
		self notify( "sound_stop" );
		return;
	}

	self UseAnimTree( #animtree );
	self SetAnim( %o_turret_guardian_close, 0.0 ); // stop close anim
	self SetAnimRestart( %o_turret_guardian_open, 1.0, 0.0, 1.0 );

	self thread StartMicrowaveFx(localClientNum);
}

function microwave_close_anim( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !newVal )
		return;

	self UseAnimTree( #animtree );
	self SetAnimRestart( %o_turret_guardian_close, 1.0, 0.0, 1.0 );
}

/#
function debug_trace(origin, trace)
{
	if ( trace[ "fraction" ] < 1.0 )
	{
		color = ( 0.95, 0.05, 0.05 );
	}
	else
	{
			color = ( 0.05, 0.95, 0.05 );
	}
	
	Sphere( trace[ "position" ], 5, color, 0.75, true, 10, 100 );
	util::debug_line( origin, trace[ "position" ], color, 100 );
}
#/

function StartMicrowaveFx( localClientNum )
{
	turret = self;
	turret endon( "entityshutdown" );
	turret endon( "beam_stop" );
	
	turret.should_update_fx = true;

	self thread turret_microwave_sound_start( localClientNum );

	origin = turret GetTagOrigin( "tag_flash" );
	angles = turret GetTagAngles( "tag_flash" );
	microwaveFXEnt = spawn(localClientNum, origin, "script_model");
	microwaveFXEnt SetModel("tag_microwavefx");
	microwaveFXEnt.angles = angles;
	microwaveFXEnt linkto(turret, "tag_flash");
	
	microwaveFXEnt.fxHandles = [];
	microwaveFXEnt.fxNames = [];
	microwaveFXEnt.fxHashs = [];
	
	self thread UpdateMicrowaveAim( microwaveFXEnt );
	self thread CleanupFx( localClientNum, microwaveFXEnt );
	wait 0.3;
	
	while( true )
	{
/#
		if ( GetDvarInt( "scr_microwave_turret_fx_debug" )  )
		{
			turret.should_update_fx = true;
			microwaveFXEnt.fxHashs["center"] = 0;
		}
#/
		if ( turret.should_update_fx == false )
		{
			wait MICROWAVE_TURRET_FX_CHECK_TIME;
			continue;
		}
		
		// limit traces per frame when there are multiple microwave turrets on the field
		if ( isdefined( level.last_microwave_turret_fx_trace ) && level.last_microwave_turret_fx_trace == GetTime() )
		{
			wait(0.05);
			
			// /# IPrintLnBold( "Delaying microwave turret fx!  Time: " + GetTime() ); #/
			continue;
		}

		angles = turret GetTagAngles( "tag_flash" );
		origin = turret GetTagOrigin( "tag_flash" );
		forward = AnglesToForward( angles );
		forward = VectorScale( forward, MICROWAVE_TURRET_FX_TRACE );
		forwardRight = AnglesToForward( angles - (0, MICROWAVE_TURRET_FX_TRACE_ANGLE / 3, 0) );
		forwardRight = VectorScale( forwardRight, MICROWAVE_TURRET_FX_TRACE );
		forwardLeft = AnglesToForward( angles + (0, MICROWAVE_TURRET_FX_TRACE_ANGLE / 3, 0) );
		forwardLeft = VectorScale( forwardLeft, MICROWAVE_TURRET_FX_TRACE );
	
		trace = BulletTrace( origin, origin + forward, false, turret );
		traceRight = BulletTrace( origin, origin + forwardRight, false, turret );
		traceLeft = BulletTrace( origin, origin + forwardLeft, false, turret );
		
/#
		if ( GetDvarInt( "scr_microwave_turret_fx_debug" ) )
		{
			debug_trace( origin, trace );
			debug_trace( origin, traceRight );
			debug_trace( origin, traceLeft );
		}
#/

		need_to_rebuild = microwaveFXEnt MicrowaveFxHash( trace, origin, "center" );
		need_to_rebuild |= microwaveFXEnt MicrowaveFxHash( traceRight, origin, "right" );
		need_to_rebuild |= microwaveFXEnt MicrowaveFxHash( traceLeft, origin, "left" );
		
		level.last_microwave_turret_fx_trace = getTime();

		if( !need_to_rebuild )
		{
			wait MICROWAVE_TURRET_FX_CHECK_TIME;
			continue;
		}
		
		wait( 0.1 );
		
		microwaveFXEnt PlayMicrowaveFx( localClientNum, trace, traceRight, TraceLeft, origin );
	
		turret.should_update_fx = false;
		wait MICROWAVE_TURRET_FX_CHECK_TIME;
	}
}

function UpdateMicrowaveAim( microwaveFXEnt )
{
	turret = self;
	turret endon( "entityshutdown" );
	turret endon( "beam_stop" );

	last_angles = turret GetTagAngles( "tag_flash" );

	while( true )
	{
		angles = turret GetTagAngles( "tag_flash" );

		if ( last_angles != angles )
		{
			turret.should_update_fx = true;
			last_angles = angles;
		}
		
		wait 0.1;
	}
}

function MicrowaveFxHash( trace, origin, name )
{
	hash = 0;
	counter = 2;
	for ( i = 0; i < 5; i++ )
	{
		endOfHalfFxSq = SQR( ( i * MICROWAVE_TURRET_ROW_SPREAD ) + MICROWAVE_TURRET_FX_HALF_SIZE );
		endOfFullFxSq = SQR( ( i * MICROWAVE_TURRET_ROW_SPREAD ) + MICROWAVE_TURRET_FX_SIZE);

		traceDistSq = DistanceSquared( origin, trace[ "position" ] );
		if( traceDistSq >= endOfHalfFxSq || i == 0 )
		{
			if ( traceDistSq < endOfFullFxSq )
			{
				hash += 1;
			}
			else
			{
				hash += counter;
			}
		}
		
		counter *= 2;
	}
	
	if ( !isDefined( self.fxHashs[name] ) )
		self.fxHashs[name] = 0;
		
	last_hash = self.fxHashs[name];
	
	self.fxHashs[name] = hash;
	
	return last_hash != hash;
}

function CleanupFx( localClientNum, microwaveFXEnt )
{
		self util::waittill_any( "entityshutdown", "beam_stop" );
		
		foreach ( handle in microwaveFXEnt.fxHandles )
		{
			if ( isdefined( handle ) )
			{
				StopFx( localClientNum, handle );
			}
		}
		
		microwaveFXEnt delete();
}
 
function play_fx_on_tag( localClientNum, fxName, tag )
{
	if ( !isdefined( self.fxHandles[tag] ) || fxName != self.fxNames[tag] )
	{
		stop_fx_on_tag( localClientNum, fxName, tag );
		
		self.fxNames[tag] = fxName;
	 	self.fxHandles[tag] = PlayFxOnTag( localCLientNum, fxName, self, tag );
	}
}

function stop_fx_on_tag( localClientNum, fxName, tag )
{
	if ( isdefined( self.fxHandles[tag] ) )
	{
		  StopFx( localClientNum, self.fxHandles[tag] );
	  
		self.fxHandles[tag] = undefined;
		self.fxNames[tag] = undefined;
	}
}

/#
function render_debug_sphere( tag, color, fxName )
{
	if ( GetDvarInt( "scr_microwave_turret_fx_debug" ) )
	{
		origin = self GetTagOrigin( tag );
		
		Sphere( origin, 2, color, 0.75, true, 10, 100 );
	}
}
#/

function stop_or_start_fx( localClientNum, fxName, tag, start )
{
	if ( start )
	{
		self play_fx_on_tag( localClientNum, fxName, tag );
/#
		if ( fxName == MICROWAVE_TURRET_FX_HALF )
		{
			render_debug_sphere( tag, ( 0.5, 0.5, 0 ), fxName );
		}
		else
		{
			render_debug_sphere( tag, ( 0, 1, 0 ), fxName );
		}
#/
	}
	else
	{
		stop_fx_on_tag( localClientNum, fxName, tag );
/#
		render_debug_sphere( tag, ( 1, 0, 0 ), fxName );
#/
	}
}

function PlayMicrowaveFx( localCLientNum, trace, traceRight, traceLeft, origin )
{
	rows = 5;
	
	// /# IPrintLnBold( "Playing Microwave Fx: " + GetTime() ); #/
	
	for ( i = 0; i < rows; i++ )
	{
		endOfHalfFxSq = SQR( ( i * MICROWAVE_TURRET_ROW_SPREAD ) + MICROWAVE_TURRET_FX_HALF_SIZE );
		endOfFullFxSq = SQR( ( i * MICROWAVE_TURRET_ROW_SPREAD ) + MICROWAVE_TURRET_FX_SIZE);
		
		traceDistSq = DistanceSquared( origin, trace[ "position" ] );
		
		startFx = traceDistSq >= endOfHalfFxSq || i == 0;	
		fxName = ( ( traceDistSq < endOfFullFxSq ) ? MICROWAVE_TURRET_FX_HALF : MICROWAVE_TURRET_FX );

		switch ( i )
		{
			case 0:
				// we always want this one to play
				self play_fx_on_tag( localCLientNum, fxName, "tag_fx11" );
				break;					
			case 1:
				break;
			case 2:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx32", startFx );
				break;
			case 3:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx42", startFx );
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx43", startFx );
				break;
			case 4:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx53", startFx );
				break;
		}
		
		traceDistSq = DistanceSquared( origin, traceLeft[ "position" ] );
	
		startFx = traceDistSq >= endOfHalfFxSq;	
		fxName = ( ( traceDistSq < endOfFullFxSq ) ? MICROWAVE_TURRET_FX_HALF : MICROWAVE_TURRET_FX );

		switch ( i )
		{
			case 0:
				break;					
			case 1:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx22", startFx );
				break;
			case 2:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx33", startFx );
				break;
			case 3:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx44", startFx );
				break;
			case 4:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx54", startFx );
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx55", startFx );
				break;
		}
		
		traceDistSq = DistanceSquared( origin, traceRight[ "position" ] );

		startFx = traceDistSq >= endOfHalfFxSq;	
		fxName = ( ( traceDistSq < endOfFullFxSq ) ? MICROWAVE_TURRET_FX_HALF : MICROWAVE_TURRET_FX );

		switch ( i )
		{
			case 0:
				break;					
			case 1:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx21", startFx );
				break;
			case 2:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx31", startFx );
				break;
			case 3:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx41", startFx );
				break;
			case 4:
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx51", startFx );
				self stop_or_start_fx( localCLientNum, fxName, "tag_fx52", startFx );
			break;
		}
	}

	// /# IPrintLnBold( "Done playing Microwave Fx: " + GetTime() ); #/
}