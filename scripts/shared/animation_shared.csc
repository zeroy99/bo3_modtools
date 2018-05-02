#using scripts\shared\animation_debug_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\shaderanim_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace animation;

#define ANIM_NOTIFY "_anim_notify_"
	
REGISTER_SYSTEM( "animation", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "cracks_on", VERSION_SHIP, GetMinBitCountForNum( 4 ), "int",	&cf_cracks_on, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "cracks_off", VERSION_SHIP, GetMinBitCountForNum( 4 ), "int",	&cf_cracks_off, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	setup_notetracks();
}

/@
"Name: first_frame( <ents>, <scene>, [str_tag], [animname_override] )"
"Summary: Puts the animating models or AI or vehicles into the first frame of the animated scene. The animation is played relative to the entity that calls the scene"
"Module: Animation"
"CallOn: The root entity that is the point of relativity for the scene, be it node, ai, vehicle, etc."
"MandatoryArg: <ents> Array of entities that will animate."
"MandatoryArg: <scene> The animation scene name."
"OptionalArg: [str_tag] The str_tag to animate relative to (must exist in the entity this function is called on)."
"OptionalArg: [animname_override] Animname to use instead of ent.animname"
"Example: node first_frame( guys, "rappel_sequence" );"
"SPMP: singleplayer"
@/
function first_frame( animation, v_origin_or_ent, v_angles_or_tag )
{
	self thread play( animation, v_origin_or_ent, v_angles_or_tag, 0 );
}

function play( animation, v_origin_or_ent, v_angles_or_tag, n_rate = 1, n_blend_in = .2, n_blend_out = .2, n_lerp, b_link = false )
{
	self endon( "entityshutdown" );
	self thread _play( animation, v_origin_or_ent, v_angles_or_tag, n_rate, n_blend_in, n_blend_out, n_lerp, b_link );
	self waittill( "scriptedanim" );
}

function _play( animation, v_origin_or_ent, v_angles_or_tag, n_rate = 1, n_blend_in = .2, n_blend_out = .2, n_lerp, b_link = false )
{
	self endon( "entityshutdown" );
	
	self notify( "new_scripted_anim" );
	self endon( "new_scripted_anim" );
	
	flagsys::set_val( "firstframe", n_rate == 0 );
	flagsys::set( "scripted_anim_this_frame" );
	flagsys::set( "scriptedanim" );
	
	DEFAULT( v_origin_or_ent, self );
	
	if ( IsVec( v_origin_or_ent ) && IsVec( v_angles_or_tag ) )
	{
		self AnimScripted( ANIM_NOTIFY, v_origin_or_ent, v_angles_or_tag, animation, n_blend_in, n_rate );
	}
	else
	{
		if ( IsString( v_angles_or_tag ) )
		{
			Assert( isdefined( v_origin_or_ent.model ), "Cannot align animation '" + animation + "' to tag '" + v_angles_or_tag + "' because the animation is not aligned to a model." );
			
			v_pos = v_origin_or_ent GetTagOrigin( v_angles_or_tag );
			v_ang = v_origin_or_ent GetTagAngles( v_angles_or_tag );
			
			self.origin = v_pos;
			self.angles = v_ang;
						
			b_link = true;
			
//			self LinkTo( v_origin_or_ent, v_angles_or_tag, ( 0, 0, 0 ), ( 0, 0, 0 ) ); // TODO: LinkTo with animation is broken client side and will mis-align the entities
			self AnimScripted( ANIM_NOTIFY, self.origin, self.angles, animation, n_blend_in, n_rate );
		}
		else
		{		
			v_angles = ( isdefined( v_origin_or_ent.angles ) ? v_origin_or_ent.angles : ( 0, 0, 0 ) );
			self AnimScripted( ANIM_NOTIFY, v_origin_or_ent.origin, v_angles, animation, n_blend_in, n_rate );
		}
	}
	
	if ( !b_link )
	{
		self Unlink();
	}
		
	self thread handle_notetracks();

	self waittill_end();
	
	if ( b_link )
	{
		self Unlink();
	}
	
	flagsys::clear( "scriptedanim" );
	flagsys::clear( "firstframe" );
	
	waittillframeend;
	
	flagsys::clear( "scripted_anim_this_frame" );
}

function private waittill_end()
{
	level endon("demo_jump"); // end when theater mode rewinds
	
	self waittillmatch( ANIM_NOTIFY, "end" );
}

function _get_align_ent( e_align )
{
	e = self;
	if ( isdefined( e_align ) )
	{
		e = e_align;
	}
	
	DEFAULT( e.angles, ( 0, 0, 0 ) );
	return e;
}

function _get_align_pos( v_origin_or_ent, v_angles_or_tag )
{
	DEFAULT( v_origin_or_ent, self.origin );
	DEFAULT2( v_angles_or_tag, self.angles, ( 0, 0, 0 ) );
	
	s = SpawnStruct();
	
	if ( IsVec( v_origin_or_ent ) )
	{
		Assert( IsVec( v_angles_or_tag ), "Angles must be a vector if origin is." );
		
		s.origin = v_origin_or_ent;
		s.angles = v_angles_or_tag;
	}
	else
	{
		e_align = _get_align_ent( v_origin_or_ent );
					
		if ( IsString( v_angles_or_tag ) )
		{
			s.origin = e_align GetTagOrigin( v_angles_or_tag );
			s.angles = e_align GetTagAngles( v_angles_or_tag );
		}
		else
		{
			s.origin = e_align.origin;
			s.angles = e_align.angles;
		}			
	}
	
	DEFAULT( s.angles, ( 0, 0, 0 ) );
	
	return s;
}

function play_siege( str_anim, str_shot = "default", n_rate = 1, b_loop = false )
{
	level endon("demo_jump"); // end when theater mode rewinds
	self endon( "entityshutdown" );
	
	DEFAULT( str_shot, "default" );
	
	if ( n_rate == 0 )
	{
		self SiegeCmd( "set_anim", str_anim, "set_shot", str_shot, "pause", "goto_start" );
	}
	else
	{
		self SiegeCmd( "set_anim", str_anim, "set_shot", str_shot, "unpause", "set_playback_speed", n_rate, "send_end_events", true, ( b_loop ? "loop" : "unloop" ) );
	}
	
	self waittill( "end" );
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Notetrack Handling
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function add_notetrack_func( funcname, func )
{
	DEFAULT( level._animnotifyfuncs, [] );

	Assert( !isdefined( level._animnotifyfuncs[ funcname ] ), "Notetrack function already exists." );
	
	level._animnotifyfuncs[ funcname ] = func;
}

function add_global_notetrack_handler( str_note, func, ... )
{
	DEFAULT( level._animnotetrackhandlers, [] );
	DEFAULT( level._animnotetrackhandlers[ str_note ], [] );
	
	ARRAY_ADD( level._animnotetrackhandlers[ str_note ], array( func, vararg ) );
}

function call_notetrack_handler( str_note )
{
	if ( isdefined( level._animnotetrackhandlers ) && isdefined( level._animnotetrackhandlers[ str_note ] ) )
	{
		foreach ( handler in level._animnotetrackhandlers[ str_note ] )
		{
			func = handler[0];
			args = handler[1];
			
			switch ( args.size )
			{
				case 6:
					self [[ func ]]( args[0], args[1], args[2], args[3], args[4], args[5] );
					break;
				case 5:
					self [[ func ]]( args[0], args[1], args[2], args[3], args[4] );
					break;
				case 4:
					self [[ func ]]( args[0], args[1], args[2], args[3] );
					break;
				case 3:
					self [[ func ]]( args[0], args[1], args[2] );
					break;
				case 2:
					self [[ func ]]( args[0], args[1] );
					break;
				case 1:
					self [[ func ]]( args[0] );
					break;
				case 0:
					self [[ func ]]();
					break;
				default: AssertMsg( "Too many args passed to notetrack handler." );
			}
		}
	}
}

function setup_notetracks()
{
	add_notetrack_func( "flag::set", &flag::set );
	add_notetrack_func( "flag::clear", &flag::clear );
	
	add_notetrack_func( "postfx::PlayPostFxBundle", &postfx::PlayPostFxBundle );
	add_notetrack_func( "postfx::StopPostFxBundle", &postfx::StopPostFxBundle );
	
	add_global_notetrack_handler( "red_cracks_on",		&cracks_on,		"red" );
	add_global_notetrack_handler( "green_cracks_on",	&cracks_on,		"green" );
	add_global_notetrack_handler( "blue_cracks_on",		&cracks_on,		"blue" );
	add_global_notetrack_handler( "all_cracks_on",		&cracks_on,		"all" );
	
	add_global_notetrack_handler( "red_cracks_off",		&cracks_off,	"red" );
	add_global_notetrack_handler( "green_cracks_off",	&cracks_off,	"green" );
	add_global_notetrack_handler( "blue_cracks_off",	&cracks_off,	"blue" );
	add_global_notetrack_handler( "all_cracks_off",		&cracks_off,	"all" );
}

function handle_notetracks()
{
	level endon("demo_jump"); // end when theater mode rewinds
	self endon( "entityshutdown" );
	
	while ( true )
	{
		self waittill( ANIM_NOTIFY, str_note );
		
		if ( str_note != "end" && str_note != "loop_end" )
		{
			self thread call_notetrack_handler( str_note );
		}
		else
		{
			return;
		}
	}
}

#define CF_CRACKS_RED 1
#define CF_CRACKS_BLUE 2
#define CF_CRACKS_GREEN 3
#define CF_CRACKS_ALL 4

#define SHADER_VEC_RED "scriptVector1"
#define SHADER_VEC_GREEN "scriptVector2"
#define SHADER_VEC_BLUE "scriptVector3"
	
function cracks_on( str_type )
{
	switch ( str_type )
	{
		case "red":
			cf_cracks_on( self.localClientNum, 0, CF_CRACKS_RED );
			break;
		case "green":
			cf_cracks_on( self.localClientNum, 0, CF_CRACKS_GREEN );
			break;
		case "blue":
			cf_cracks_on( self.localClientNum, 0, CF_CRACKS_BLUE );
			break;
		case "all":
			cf_cracks_on( self.localClientNum, 0, CF_CRACKS_ALL );
			break;
	}
}

function cracks_off( str_type )
{
	switch ( str_type )
	{
		case "red":
			cf_cracks_off( self.localClientNum, 0, CF_CRACKS_RED );
			break;
		case "green":
			cf_cracks_off( self.localClientNum, 0, CF_CRACKS_GREEN );
			break;
		case "blue":
			cf_cracks_off( self.localClientNum, 0, CF_CRACKS_BLUE );
			break;
		case "all":
			cf_cracks_off( self.localClientNum, 0, CF_CRACKS_ALL );
			break;
	}
}
	
function cf_cracks_on( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	const delay = 0;
	const duration = 3;
	const start = 0;
	const end = 1;
	
	switch ( newVal )
	{
		case CF_CRACKS_RED:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_RED, delay, duration, start, end );
			break;
		case CF_CRACKS_GREEN:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_GREEN, delay, duration, start, end );
			break;
		case CF_CRACKS_BLUE:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_BLUE, delay, duration, start, end );
			break;
		case CF_CRACKS_ALL:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_RED, delay, duration, start, end );
			shaderanim::animate_crack( localClientNum, SHADER_VEC_GREEN, delay, duration, start, end );
			shaderanim::animate_crack( localClientNum, SHADER_VEC_BLUE, delay, duration, start, end );
	}
}

function cf_cracks_off( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	const delay = 0;
	const duration = 0;
	const start = 1;
	const end = 0;
	
	switch ( newVal )
	{
		case CF_CRACKS_RED:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_RED, delay, duration, start, end );
			break;
		case CF_CRACKS_GREEN:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_GREEN, delay, duration, start, end );
			break;
		case CF_CRACKS_BLUE:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_BLUE, delay, duration, start, end );
			break;
		case CF_CRACKS_ALL:
			shaderanim::animate_crack( localClientNum, SHADER_VEC_RED, delay, duration, start, end );
			shaderanim::animate_crack( localClientNum, SHADER_VEC_GREEN, delay, duration, start, end );
			shaderanim::animate_crack( localClientNum, SHADER_VEC_BLUE, delay, duration, start, end );
	}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// !Notetrack Handling
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
