/*
	util.gsc
		
	This is a utility script common to all game modes. Don't add anything with calls to game type
	specific script API calls.
*/

#namespace util;


/@
"Name: empty( <a>, <b>, <c>, <d>, <e> )"
"Summary: Empty function mainly used as a place holder or default function pointer in a system."
"Module: Utility"
"CallOn: "
"OptionalArg: <a> : option arg"
"OptionalArg: <b> : option arg"
"OptionalArg: <c> : option arg"
"OptionalArg: <d> : option arg"
"OptionalArg: <e> : option arg"
"Example: default_callback = &empty;"
"SPMP: both"
@/
function empty( a, b, c, d, e ) {}

/@
"Name: wait_network_frame()"
"Summary: Wait until a snapshot is acknowledged.  Can help control having too many spawns in one frame."
"Module: Utility"
"Example: wait_network_frame();"
"SPMP: singleplayer"
@/
function wait_network_frame( n_count = 1 ) {}

function streamer_wait( n_stream_request_id, n_wait_frames = 0, n_timeout = 0, b_bonuszm_streamer_fallback = true ) {}

//-- Other / Unsorted --//
/#
function draw_debug_line(start, end, timer) {}

function debug_line( start, end, color, alpha, depthTest, duration ) {}


function debug_spherical_cone( origin, domeApex, angle, slices, color, alpha, depthTest, duration ) {}

function debug_sphere( origin, radius, color, alpha, time ) {}
#/
	
function waittillend(msg) {}

function track(spot_to_track) {}

function waittill_string( msg, ent ) {}

/@
"Name: waittill_multiple( <string1>, <string2>, <string3>, <string4>, <string5> )"
"Summary: Waits for all of the the specified notifies."
"MandatoryArg:	The notifies to wait on."
"Example: guy waittill_multiple( "goal", "pain", "near_goal", "bulletwhizby" );"
@/
function waittill_multiple( ... ) {}

/@
"Name: waittill_either( <string1>, <string2> )"
"Summary: Waits for one of the two specified notifies."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<string1> name of a notify to wait on"
"MandatoryArg:	<string2> name of a notify to wait on"
"Example: guy waittill_multiple( "goal", "near_goal" );"
"SPMP: both"
@/
function waittill_either( msg1, msg2 ) {}

/@
"Name: break_glass( n_radius )"
"Summary: Calls GlassRadiusDamage on the center position of an AI to break glass around him."
"Module: Utility"
"CallOn: Entity"
"OptionalArg: <n_radius> radius used for GlassRadiusDamage, defaults to 50"
"Example: guy break_glass();"
"SPMP: both"
@/
function break_glass( n_radius = 50 ) {}

/@
"Name: waittill_multiple_ents( ... )"
"Summary: Waits for all of the the specified notifies on their associated entities."
"MandatoryArg:	List of ents and the notifies to wait on."
"Example: waittill_multiple_ents( guy, "goal", guy, "pain", guy, "near_goal", player, "weapon_change" );"
@/
function waittill_multiple_ents( ... ) {}

function _waitlogic( s_tracker, notifies ) {}

/@
"Name: waittill_any_return( <string1>, <string2>, <string3>, <string4>, <string5> )"
"Summary: Waits for any of the the specified notifies and return which one it got."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<string1> name of a notify to wait on"
"OptionalArg:	<string2> name of a notify to wait on"
"OptionalArg:	<string3> name of a notify to wait on"
"OptionalArg:	<string4> name of a notify to wait on"
"OptionalArg:	<string4> name of a notify to wait on"
"OptionalArg:	<string6> name of a notify to wait on"
"OptionalArg:	<string7> name of a notify to wait on"
"Example: which_notify = guy waittill_any( "goal", "pain", "near_goal", "bulletwhizby" );"
"SPMP: both"
@/
function waittill_any_return( string1, string2, string3, string4, string5, string6, string7 ) {}

/@
"Name: waittill_any_array_return( <a_notifies> )"
"Summary: Waits for any of the the specified notifies and return which one it got."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<a_notifies> array of notifies to wait on"
"Example: str_which_notify = guy waittill_any_array_return( array( "goal", "pain", "near_goal", "bulletwhizby" ) );"
"SPMP: both"
@/
function waittill_any_array_return( a_notifies ) {}

/@
"Name: waittill_any( <str_notify1>, <str_notify2>, <str_notify3>, <str_notify4>, <str_notify5> )"
"Summary: Waits for any of the the specified notifies."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<str_notify1> name of a notify to wait on"
"OptionalArg:	<str_notify2> name of a notify to wait on"
"OptionalArg:	<str_notify3> name of a notify to wait on"
"OptionalArg:	<str_notify4> name of a notify to wait on"
"OptionalArg:	<str_notify5> name of a notify to wait on"
"OptionalArg:	<str_notify6> name of a notify to wait on"
"Example: guy waittill_any( "goal", "pain", "near_goal", "bulletwhizby" );"
"SPMP: both"
@/
function waittill_any( str_notify1, str_notify2, str_notify3, str_notify4, str_notify5, str_notify6 ) {}

/@
"Name: waittill_any_array( <a_notifies> )"
"Summary: Waits for any of the the specified notifies in the array."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<a_notifies> array of notifies to wait on"
"Example: guy waittill_any_array( array( "goal", "pain", "near_goal", "bulletwhizby" ) );"
"SPMP: both"
@/
function waittill_any_array( a_notifies ) {}

/@
"Name: waittill_any_timeout( <n_timeout>, <str_notify1>, [str_notify2], [str_notify3], [str_notify4], [str_notify5] )"
"Summary: Waits for any of the the specified notifies or times out."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<n_timeout> timeout in seconds"
"MandatoryArg:	<str_notify1> name of a notify to wait on"
"OptionalArg:	<str_notify2> name of a notify to wait on"
"OptionalArg:	<str_notify3> name of a notify to wait on"
"OptionalArg:	<str_notify4> name of a notify to wait on"
"OptionalArg:	<str_notify5> name of a notify to wait on"
"Example: guy waittill_any_timeout( 2, "goal", "pain", "near_goal", "bulletwhizby" );"
"SPMP: both"
@/
function waittill_any_timeout( n_timeout, string1, string2, string3, string4, string5 ) {}

function _timeout( delay ) {}


/@
"Name: waittill_any_ents( ent1, string1, ent2, string2, ent3, string3, ent4, string4 )"
"Summary: Waits for any of the the specified notifies on their associated entities."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<ent1> entity to wait for <string1> on"
"MandatoryArg:	<string1> notify to wait for on <ent1>"
"OptionalArg:	<ent2> entity to wait for <string2> on"
"OptionalArg:	<string2> notify to wait for on <ent2>"
"OptionalArg:	<ent3> entity to wait for <string3> on"
"OptionalArg:	<string3> notify to wait for on <ent3>"
"OptionalArg:	<ent4> entity to wait for <string4> on"
"OptionalArg:	<string4> notify to wait for on <ent4>"
"Example: guy waittill_any_ents( guy, "goal", guy, "pain", guy, "near_goal", player, "weapon_change" );"
"SPMP: both"
@/
function waittill_any_ents( ent1, string1, ent2, string2, ent3, string3, ent4, string4, ent5, string5, ent6, string6,ent7, string7 ) {}

/@
"Name: waittill_any_ents_two( ent1, string1, ent2, string2)"
"Summary: Waits for any of the the specified notifies on their associated entities [MAX TWO]."
"Module: Utility"
"CallOn: Entity"
"MandatoryArg:	<ent1> entity to wait for <string1> on"
"MandatoryArg:	<string1> notify to wait for on <ent1>"
"OptionalArg:	<ent2> entity to wait for <string2> on"
"OptionalArg:	<string2> notify to wait for on <ent2>"
"Example: guy waittill_any_ents_two( guy, "goal", guy, "pain");"
"SPMP: both"
@/
function waittill_any_ents_two( ent1, string1, ent2, string2 ) {}

/@
"Name: isFlashed()"
"Summary: Returns true if the player or an AI is flashed"
"Module: Utility"
"CallOn: An AI"
"Example: flashed = level.price isflashed();"
"SPMP: both"
@/
function isFlashed() {}

/@
"Name: isStunned()"
"Summary: Returns true if the player or an AI is Stunned/Concussed/Proximity"
"Module: Utility"
"CallOn: An AI"
"Example: stunned = level.price isStunned();"
"SPMP: both"
@/
function isStunned() {}

/@
"Name: single_func( <entity>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Runs the < func > function on the entity. The entity will become "self" in the specified function."
"Module: Utility"
"CallOn: NA"
"MandatoryArg: entity : the entity to run through <func>"
"MandatoryArg: func> : pointer to a script function"
"OptionalArg: arg1 : parameter 1 to pass to the func"
"OptionalArg: arg2 : parameter 2 to pass to the func"
"OptionalArg: arg3 : parameter 3 to pass to the func"
"OptionalArg: arg4 : parameter 4 to pass to the func"
"OptionalArg: arg5 : parameter 5 to pass to the func"
"OptionalArg: arg6 : parameter 6 to pass to the func"
"Example: single_func( guy,&set_ignoreme, false );"
"SPMP: both"
@/
function single_func( entity, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: new_func( <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Creates a new func with the args stored on a struct that can be called with call_func."
"Module: Utility"
"CallOn: NA"
"MandatoryArg: func> : pointer to a script function"
"OptionalArg: arg1 : parameter 1 to pass to the func"
"OptionalArg: arg2 : parameter 2 to pass to the func"
"OptionalArg: arg3 : parameter 3 to pass to the func"
"OptionalArg: arg4 : parameter 4 to pass to the func"
"OptionalArg: arg5 : parameter 5 to pass to the func"
"OptionalArg: arg6 : parameter 6 to pass to the func"
"Example: s_callback = new_func(&set_ignoreme, false );"
"SPMP: both"
@/
function new_func( func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: call_func( <func_struct> )"
"Summary: Runs the func and args stored on a struct created with new_func."
"Module: Utility"
"CallOn: NA"
"MandatoryArg: func_struct> : struct return by new_func"
"Example: self call_func( s_callback );"
"SPMP: both"
@/
function call_func( s_func ) {}

/@
"Name: single_thread( <entity>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Threads the < func > function on the entity. The entity will become "self" in the specified function."
"Module: Utility"
"CallOn: "
"MandatoryArg: <entity> : the entity to thread <func> on"
"MandatoryArg: <func> : pointer to a script function"
"OptionalArg: [arg1] : parameter 1 to pass to the func"
"OptionalArg: [arg2] : parameter 2 to pass to the func"
"OptionalArg: [arg3] : parameter 3 to pass to the func"
"OptionalArg: [arg4] : parameter 4 to pass to the func"
"OptionalArg: [arg5] : parameter 5 to pass to the func"
"OptionalArg: [arg6] : parameter 6 to pass to the func"
"Example: single_func( guy,&special_ai_think, "some_string", 345 );"
"SPMP: both"
@/
function single_thread(entity, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

function script_delay() {}

/@
"Name: timeout( <n_time>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Run any function with a timeout.  The function will exit when the timeout is reached."
"Module: util"
"CallOn: any"
"MandatoryArg: <n_time> : the timeout"
"MandatoryArg: <func> : the function"
"OptionalArg: [arg1] : parameter 1 to pass to the func"
"OptionalArg: [arg2] : parameter 2 to pass to the func"
"OptionalArg: [arg3] : parameter 3 to pass to the func"
"OptionalArg: [arg4] : parameter 4 to pass to the func"
"OptionalArg: [arg5] : parameter 5 to pass to the func"
"OptionalArg: [arg6] : parameter 6 to pass to the func"
"Example: ent timeout( 10, &my_function, 12, "hi" );"
"SPMP: both"
@/
function timeout( n_time, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

function create_flags_and_return_tokens( flags ) {}

function fileprint_start( file ) {}

/@
"Name: fileprint_map_start( <filename> )"
"Summary: starts map export with the file trees\cod3\cod3\map_source\xenon_export\ < filename > .map adds header / worldspawn entity to the map.  Use this if you want to start a .map export."
"Module: Fileprint"
"CallOn: Level"
"MandatoryArg: <param1> : "
"OptionalArg: <param2> : "
"Example: fileprint_map_start( filename );"
"SPMP: both"
@/

function fileprint_map_start( file ) {}

function fileprint_chk( file , str ) {}

function fileprint_map_header( bInclude_blank_worldspawn ) {}

/@
"Name: fileprint_map_keypairprint( <key1> , <key2> )"
"Summary: prints a pair of keys to the current open map( by fileprint_map_start() )"
"Module: Fileprint"
"CallOn: Level"
"MandatoryArg: <key1> : "
"MandatoryArg: <key2> : "
"Example: fileprint_map_keypairprint( "classname", "script_model" );"
"SPMP: both"
@/

function fileprint_map_keypairprint( key1, key2 ) {}

/@
"Name: fileprint_map_entity_start()"
"Summary: prints entity number and opening bracket to currently opened file"
"Module: Fileprint"
"CallOn: Level"
"Example: fileprint_map_entity_start();"
"SPMP: both"
@/

function fileprint_map_entity_start() {}

/@
"Name: fileprint_map_entity_end()"
"Summary: close brackets an entity, required for the next entity to begin"
"Module: Fileprint"
"CallOn: Level"
"Example: fileprint_map_entity_end();"
"SPMP: both"
@/

function fileprint_map_entity_end() {}

/@
"Name: fileprint_end()"
"Summary: saves the currently opened file"
"Module: Fileprint"
"CallOn: Level"
"Example: fileprint_end();"
"SPMP: both"
@/
 
function fileprint_end() {}

/@
"Name: fileprint_radiant_vec( <vector> )"
"Summary: this converts a vector to a .map file readable format"
"Module: Fileprint"
"CallOn: An entity"
"MandatoryArg: <vector> : "
"Example: origin_string = fileprint_radiant_vec( vehicle.angles )"
"SPMP: both"
@/
function fileprint_radiant_vec( vector ) {}

// Facial animation event notify wrappers
function death_notify_wrapper( attacker, damageType ) {}

function damage_notify_wrapper( damage, attacker, direction_vec, point, type, modelName, tagName, partName, iDFlags ) {}

function explode_notify_wrapper() {}

function alert_notify_wrapper() {}

function shoot_notify_wrapper() {}

function melee_notify_wrapper() {}

function isUsabilityEnabled() {}


function _disableUsability() {}


function _enableUsability() {}


function resetUsability() {}


function _disableWeapon() {}

function _enableWeapon() {}

function isWeaponEnabled() {}

function orient_to_normal( normal ) {}

/@
"Name: delay(<time_or_notify>, [str_endon], <function>, [arg1], [arg2], [arg3], [arg4], [arg5])"
"Summary: Delay the execution of a thread."
"MandatoryArg: <time_or_notify> : Time to wait( in seconds ) or notify to wait for before sending the notify."
"OptionalArg: [str_endon] : endon to cancel the function call"
"MandatoryArg: <function> : The function to run."
"OptionalArg: [arg1] : parameter 1 to pass to the process"
"OptionalArg: [arg2] : parameter 2 to pass to the process"
"OptionalArg: [arg3] : parameter 3 to pass to the process"
"OptionalArg: [arg4] : parameter 4 to pass to the process"
"OptionalArg: [arg5] : parameter 5 to pass to the process"
"Example: delay( &flag::set, "player_can_rappel", 3 );"
@/
function delay( time_or_notify, str_endon, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

function _delay( time_or_notify, str_endon, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: delay_network_frames(<n_frames>, [str_endon], <function>, [arg1], [arg2], [arg3], [arg4], [arg5])"
"Summary: Delay the execution of a thread by specified number of network frames."
"MandatoryArg: <n_frames> : frames to wait."
"OptionalArg: [str_endon] : endon to cancel the function call"
"MandatoryArg: <function> : The function to run."
"OptionalArg: [arg1] : parameter 1 to pass to the process"
"OptionalArg: [arg2] : parameter 2 to pass to the process"
"OptionalArg: [arg3] : parameter 3 to pass to the process"
"OptionalArg: [arg4] : parameter 4 to pass to the process"
"OptionalArg: [arg5] : parameter 5 to pass to the process"
"Example: delay( &flag::set, "player_can_rappel", 3 );"
@/
function delay_network_frames( n_frames, str_endon, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

function _delay_network_frames( n_frames, str_endon, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: delay_notify( <n_delay>, <str_notify>, [str_endon] )"
"Summary: Notifies self the string after waiting the specified delay time"
"Module: Entity"
"CallOn: An entity"
"MandatoryArg: <time_or_notify> : Time to wait( in seconds ) or notify to wait for before sending the notify."
"MandatoryArg: <str_notify> : The string to notify"
"OptionalArg: <str_endon> : Endon to cancel the notify"
"OptionalArg: <arg1> : Optional notify parameter"
"OptionalArg: <arg2> : Optional notify parameter"
"OptionalArg: <arg3> : Optional notify parameter"
"OptionalArg: <arg4> : Optional notify parameter"
"OptionalArg: <arg5> : Optional notify parameter"
"Example: vehicle delay_notify( 3.5, "start_to_smoke" );"
"SPMP: singleplayer"
@/
function delay_notify( time_or_notify, str_notify, str_endon, arg1, arg2, arg3, arg4, arg5 ) {}

function _delay_notify( time_or_notify, str_notify, str_endon, arg1, arg2, arg3, arg4, arg5 ) {}

/*
=============
///ScriptDocBegin
"Name: ter_op( <statement> , <true_value> , <false_value> )"
"Summary: Functon that serves as a tertiary operator in C/C++"
"Module: Utility"
"CallOn: "
"MandatoryArg: <statement>: The statement to evaluate"
"MandatoryArg: <true_value>: The value that is returned when the statement evaluates to true"
"MandatoryArg: <false_value>: That value that is returned when the statement evaluates to false"
"Example: x = ter_op( x > 5, 2, 7 );"
"SPMP: both"
///ScriptDocEnd
=============
*/
/* DEAD CODE REMOVAL
function ter_op( statement, true_value, false_value )
{
	if ( statement )
		return true_value;
	return false_value;
}
*/

/@
"Name: get_closest_player( <org> , <str_team> )"
"Summary: Returns the closest player to the given origin."
"Module: Coop"
"MandatoryArg: <origin>: The vector to use to compare the distances to"
"MandatoryArg: <str_team>: The team to get players from."
"Example: closest_player = get_closest_player( objective.origin );"
"SPMP: singleplayer"
@/
function get_closest_player( org, str_team ) {}

function registerClientSys(sSysName) {}

function setClientSysState(sSysName, sSysState, player) {}

function getClientSysState(sSysName) {}

function clientNotify(event) {}

function coopGame() {}

/@
"Name: is_looking_at( <ent_or_org>, [n_dot_range], [do_trace] )"
"Summary: Checks to see if an entity is facing a point within a specified dot then returns true or false. Can use bullet trace."
"Module: Entity"
"CallOn: Entity"
"MandatoryArg: <ent_or_org> entity or origin to check against"
"OptionalArg: [n_dot_range] custom dot range. Defaults to 0.8"
"OptionalArg: [do_trace] does a bullet trace along with checking the dot. Defaults to false"
"Example: is_facing_woods = player util::is_looking_at( level.woods.origin );"
"SPMP: singleplayer"
@/
function is_looking_at( ent_or_org, n_dot_range = 0.67, do_trace = false, v_offset ) {}

/@
"Name: get_eye()"
"Summary: Get eye position accurately even on a player when linked to an entity."
"Module: Utility"
"CallOn: Player or AI"
"Example: eye_pos = player get_eye();"
"SPMP: singleplayer"
@/
function get_eye() {}

/@
"Name: is_ads()"
"Summary: Returns true if the player is more than 50% ads"
"Module: Utility"
"Example: player_is_ads = level.player is_ads();"
"SPMP: singleplayer"
@/
function is_ads() {}

/@
"Name: spawn_model(<model_name>, [origin], [angles], [spawnflags])"
"Summary: Spawns a model at an origin and angles."
"Module: Utility"
"MandatoryArg: <model_name> the model name."
"OptionalArg: [origin] the origin to spawn the model at."
"OptionalArg: [angles] the angles to spawn the model at."
"OptionalArg: [spawnflags] the spawnflags for the model."
"OptionalArg: [b_throttle] respect the global spawn throttle."
"Example: fx_model = spawn_model("tag_origin", org, ang);"
@/
function spawn_model( model_name, origin, angles, n_spawnflags = 0, b_throttle = false ) {}


/@
"Name: spawn_anim_model(<model_name>, [origin], [angles], [spawnflags])"
"Summary: Spawns a model ready for animation at an origin and angles."
"Module: Utility"
"MandatoryArg: <model_name> the model name."
"OptionalArg: [origin] the origin to spawn the model at."
"OptionalArg: [angles] the angles to spawn the model at."
"OptionalArg: [spawnflags] the spawnflags for the model."
"OptionalArg: [b_throttle] respect the global spawn throttle."
"Example: fx_model = spawn_anim_model("tag_origin", org, ang);"
@/
function spawn_anim_model( model_name, origin, angles, n_spawnflags = 0, b_throttle ) {}


/@
"Name: spawn_anim_player_model(<model_name>, [origin], [angles], [spawnflags])"
"Summary: Spawns a model ready for animation at an origin and angles using the player animtree."
"Module: Utility"
"MandatoryArg: <model_name> the model name."
"OptionalArg: [origin] the origin to spawn the model at."
"OptionalArg: [angles] the angles to spawn the model at."
"OptionalArg: [spawnflags] the spawnflags for the model."
"Example: fx_model = spawn_anim_model("tag_origin", org, ang);"
@/
function spawn_anim_player_model( model_name, origin, angles, n_spawnflags = 0 ) {}

/@
"Name: waittill_player_looking_at( <origin>, <dot>, <do_trace> )"
"Summary: Returns when the player can dot and trace to a point"
"Module: Player"
"CallOn: A Player"
"MandatoryArg: <org> The position you are waitting for player to look at"
"OptionalArg: <arc_angle_degrees> Optional arc in degrees from the leftmost limit to the rightmost limit. e.g. 90 is a quarter circle. Default is 90."
"OptionalArg: <do_trace> Set to false to skip the bullet trace check"
"OptionalArg: <e_ignore> Entity to ignore for optional bullet trace"
"Example: if ( GetPlayers()[0] waittill_player_looking_at( org.origin ) )"
"SPMP: singleplayer"
@/
function waittill_player_looking_at( origin, arc_angle_degrees = 90, do_trace, e_ignore ) {}

/@
"Name: waittill_player_not_looking_at( <origin>, <dot>, <do_trace> )"
"Summary: Returns when the player cannot dot and trace to a point"
"Module: Player"
"CallOn: A Player"
"MandatoryArg: <org> The position you're waitting for player to look at"
"OptionalArg: <dot> Optional override dot (between 0 and 1) the higher the number, the more the player has to be looking right at the spot."
"OptionalArg: <do_trace> Set to false to skip the bullet trace check"
"Example: if ( GetPlayers()[0] waittill_player_not_looking_at( org.origin ) )"
"SPMP: singleplayer"
@/
function waittill_player_not_looking_at( origin, dot, do_trace ) {}

/@
"Name: is_player_looking_at( <origin>, <dot>, <do_trace> )"
"Summary: Checks to see if the player can dot and trace to a point"
"Module: Player"
"CallOn: A Player"
"MandatoryArg: <org> The position you're checking if the player is looking at"
"OptionalArg: <dot> Optional override dot (between 0 and 1) the higher the number, the more the player has to be looking right at the spot."
"OptionalArg: <do_trace> Set to false to skip the bullet trace check"
"OptionalArg: <ignore_ent> Ignore ent passed to trace check"
"Example: if ( GetPlayers()[0] is_player_looking_at( org.origin ) )"
"SPMP: singleplayer"
@/
function is_player_looking_at(origin, dot, do_trace, ignore_ent) {}

function wait_endon( waitTime, endOnString, endonString2, endonString3, endonString4 ) {}

function WaitTillEndOnThreaded( waitCondition, callback, endCondition1, endCondition2, endCondition3 ) {}

// TIME

function new_timer( n_timer_length ) {}

function get_time() {}

function get_time_in_seconds() {}

function get_time_frac( n_end_time ) {}

function get_time_left() {}

function is_time_left() {}

function timer_wait( n_wait ) {}

// if primary weapon damage
function is_primary_damage( meansofdeath ) {}

function delete_on_death( ent ) {}

/@
"Name: delete_on_death_or_notify( <ent>, <msg>, <clientfield> )"
"Summary: Waits until the owner receives the specified notify message or a death notify, then deletes the entity.  Option to pass in a clientfield name which will be set to 0."
"Module: Util"
"MandatoryArg: <e_to_delete>: The entity you want deleted"
"MandatoryArg: <str_notify>: The notify to wait for"	
"OptionalArg: <clientfield>: The clientfield to zero out"
"Example: e_main_thing util::delete_on_death_or_notify( e_sub_thing, "delete_things", "thing_fx" )"
"SPMP: singleplayer"
@/
function delete_on_death_or_notify( e_to_delete, str_notify, str_clientfield = undefined ) {}

/@
"Name: wait_till_not_touching( <ent> )"
"Summary: Blocking function. Returns when entity one is no longer touching entity two or either entity dies."
"Module: Util"
"MandatoryArg: <e_to_check>: The entity you want to check"
"MandatoryArg: <e_to_touch>: The entity you want to touch"	
"Example: util::wait_till_not_touching( player, t_player_safe )"
"SPMP: singleplayer"
@/
function wait_till_not_touching( e_to_check, e_to_touch ) {}

/@
"Name: any_player_is_touching( <ent>, <team> )"
"Summary: Return true/false if any player is touching the given entity."
"MandatoryArg: <ent>: The entity to check against if a player is touching"
"MandatoryArg: <ent>: What team to check, if undefined, checks all players"
"Example: if ( any_player_is_touching( trigger, "allies" ) )"
@/
function any_player_is_touching( ent, str_team ) {}

/@
"Name: waittill_notify_or_timeout( <msg>, <timer> )"
"Summary: Waits until the owner receives the specified notify message or the specified time runs out. Do not thread this!"
"Module: Utility"
"CallOn: an entity"
"Example: tank waittill_notify_or_timeout( "turret_on_target", 10 ); "
"MandatoryArg: <msg> : The notify to wait for."
"MandatoryArg: <timer> : The amount of time to wait until overriding the wait statement."
"SPMP: singleplayer"
@/
function waittill_notify_or_timeout( msg, timer ) {}

function set_console_status() {}

//TODO T7 - remove this if gumps get cut
function waittill_asset_loaded( str_type, str_name ) {}

function script_wait( called_from_spawner = false ) {}

function is_killstreaks_enabled() {}

function is_flashbanged() {}

/@
"Name: magic_bullet_shield()"
"Summary: Makes an entity invulnerable to death. If it's an AI and it gets shot, it is temporarily ignored by enemies."
"Module: Entity"
"CallOn: Entity"
"Example: guy magic_bullet_shield();"
@/

function magic_bullet_shield( ent ) {}

function debug_magic_bullet_shield_death( guy ) {}

/@
"Name: spawn_player_clone( <player>, <animname> )"
"Summary: Spawns and returns a scriptmodel that is a clone of the player, and can start a player animation on the clone"
"Module: Player"
"CallOn: "
"MandatoryArg: <player> : the player that needs to be cloned"
"OptionalArg: <animname> : the animation to play on the clone"
"Example: playerClone = spawn_player_clone( player, "pb_rifle_run_lowready_f" );"
"SPMP: "
@/	

function spawn_player_clone( player, animname ) {}

/@
"Name: stop_magic_bullet_shield()"
"Summary: Stops magic bullet shield on an entity, making him vulnerable to death. Note the health is not set back."
"Module: Entity"
"CallOn: Entity"
"Example: friendly stop_magic_bullet_shield();"
@/

function stop_magic_bullet_shield( ent ) {}

//Round Functions
function is_one_round() {}

function is_first_round() {}

function is_lastround() {}

function get_rounds_won( team ) {}

function get_other_teams_rounds_won( skip_team ) {}

function get_rounds_played() {}

function is_round_based() {}

/@
"Name: within_fov( <start_origin> , <start_angles> , <end_origin> , <fov> )"
"Summary: Returns true if < end_origin > is within the players field of view, otherwise returns false."
"Module: Vector"
"CallOn: "
"MandatoryArg: <start_origin> : starting origin for FOV check( usually the players origin )"
"MandatoryArg: <start_angles> : angles to specify facing direction( usually the players angles )"
"MandatoryArg: <end_origin> : origin to check if it's in the FOV"
"MandatoryArg: <fov> : cosine of the FOV angle to use"
"Example: qBool = within_fov( level.player.origin, level.player.angles, target1.origin, cos( 45 ) );"
"SPMP: multiplayer"
@/ 
function within_fov( start_origin, start_angles, end_origin, fov ) {}

function button_held_think( which_button ) {}

/@
"Name: use_button_held()"
"Summary: Returns true if the player is holding down their use button."
"Module: Player"
"Example: if(player util::use_button_held())"
@/
function use_button_held() {}

/@
"Name: stance_button_held()"
"Summary: Returns true if the player is holding down their use button."
"Module: Player"
"Example: if(player util::stance_button_held())"
@/
function stance_button_held() {}

/@
"Name: ads_button_held()"
"Summary: Returns true if the player is holding down their ADS button."
"Module: Player"
"Example: if(player util::ads_button_held())"
@/
function ads_button_held() {}

/@
"Name: attack_button_held()"
"Summary: Returns true if the player is holding down their attack button."
"Module: Player"
"Example: if(player util::attack_button_held())"
@/
function attack_button_held() {}

/@
"Name: button_right_held()"
"Summary: Returns true if the player is holding down their dpad right button."
"Module: Player"
"Example: if(player util::button_right_held())"
@/
function button_right_held() {}

/@
"Name: waittill_use_button_pressed()"
"Summary: Waits until the player is pressing their use button."
"Module: Player"
"Example: player util::waittill_use_button_pressed()"
@/
function waittill_use_button_pressed() {}

/@
"Name: waittill_use_button_pressed()"
"Summary: Waits until the player is pressing their use button."
"Module: Player"
"Example: player util::waittill_use_button_pressed()"
@/
function waittill_use_button_held() {}

/@
"Name: waittill_stance_button_pressed()"
"Summary: Waits until the player is pressing their stance button."
"Module: Player"
"Example: player util::waittill_stance_button_pressed()"
@/
function waittill_stance_button_pressed() {}

/@
"Name: waittill_stance_button_held()"
"Summary: Waits until the player is pressing their stance button."
"Module: Player"
"Example: player util::waittill_stance_button_held()"
@/
function waittill_stance_button_held() {}

/@
"Name: waittill_attack_button_pressed()"
"Summary: Waits until the player is pressing their attack button."
"Module: Player"
"Example: player util::waittill_attack_button_pressed()"
@/
function waittill_attack_button_pressed() {}

/@
"Name: waittill_ads_button_pressed()"
"Summary: Waits until the player is pressing their ads button."
"Module: Player"
"Example: player util::waittill_ads_button_pressed()"
@/
function waittill_ads_button_pressed() {}

/@
"Name: waittill_vehicle_move_up_button_pressed()"
"Summary: Waits until the player is pressing their vehicle_move_up (set in GDT) button."
"Module: Player"
"Example: player util::waittill_vehicle_move_up_button_pressed()"
@/
function waittill_vehicle_move_up_button_pressed() {}

function init_button_wrappers() {}

/#	
function up_button_held() {}

function down_button_held() {}
	
function up_button_pressed() {}

function waittill_up_button_pressed() {}

function down_button_pressed() {}

function waittill_down_button_pressed() {}

#/

/@
"Name: freeze_player_controls( <boolean> )"
"Summary:  Freezes the player's controls with appropriate 'if' checks"
"Module: Player"
"CallOn: Player"
"MandatoryArg: <boolean> : true or false"
"Example: self util::freeze_player_controls( true )"
"SPMP: MP"
@/ 
function freeze_player_controls( b_frozen = true ) {}

function is_bot() {}

function isHacked() {}

function getLastWeapon() {}

function IsEnemyPlayer( player ) {}

// to be used with things that are slow.
// unfortunately, it can only be used with things that aren't time critical.
function WaitTillSlowProcessAllowed() {}

function mayApplyScreenEffect() {}

function waitTillNotMoving() {}


function waitTillRollingOrNotMoving() {}


function getStatsTableName() {}

function getWeaponClass( weapon ) {}

function isUsingRemote() {}

function deleteAfterTime( time ) {}

function deleteAfterTimeThread( time ) {}

function waitForTime( time ) {}

// waits for specified time and one acknowledged network frame
function waitForTimeAndNetworkFrame( time ) {}


function deleteAfterTimeAndNetworkFrame( time ) {}

function drawcylinder( pos, rad, height, duration, stop_notify, color, alpha ) {}

function drawcylinder_think( pos, rad, height, seconds, stop_notify, color, alpha ) {}

//entities_s.a[]
function get_team_alive_players_s( teamName ) {}

function get_other_teams_alive_players_s( teamNameToIgnore ) {}



function get_all_alive_players_s() {}

/@
"Name: spawn_array_struct()"
"Summary: Creates a struct with an attribute named "a" which is an empty array.  Array structs are useful for passing around arrays by reference."
"Module: Array"
"CallOn: "
"Example: fxemitters = spawn_struct_array(); fxemitters.a[ fxemitters.size ] = new_emitter;"
"SPMP: both"
@/ 
function spawn_array_struct() {}


function getHostPlayer() {}


function getHostPlayerForBots() {}



/@
"Name: get_array_of_closest( <org> , <array> , <excluders> , <max>, <maxdist> )"
"Summary: Returns an array of all the entities in < array > sorted in order of closest to farthest."
"Module: Distance"
"CallOn: "
"MandatoryArg: <org> : Origin to be closest to."
"MandatoryArg: <array> : Array of entities to check distance on."
"OptionalArg: <excluders> : Array of entities to exclude from the check."
"OptionalArg: <max> : Max size of the array to return"
"OptionalArg: <maxdist> : Max distance from the origin to return acceptable entities"
"Example: allies_sort = get_array_of_closest( originFC1.origin, allies );"
"SPMP: singleplayer"
@/
function get_array_of_closest( org, array, excluders, max, maxdist ) {}

/@
"Name: set_lighting_state( <n_state> )"
"Summary: Sets the lighting state for the level - for all players, and handles hot-join, or on a specific player."
"CallOn: level or player"
"MandatoryArg: <n_state> : Lighting state."
"Example: set_lighting_state( 2 );"
@/
function set_lighting_state( n_state ) {}

/@
"Name: set_sun_shadow_split_distance( <distance> )"
"Summary: Sets the sun shadow split distance  for the level - for all players, and handles hot-join, or on a specific player."
"CallOn: level or player"
"MandatoryArg: <n_state> : Lighting state."
"Example: set_lighting_state( 2 );"
@/
function set_sun_shadow_split_distance( f_distance ) {}


/@
"Name: auto_delete( n_mode, n_min_time_alive, n_dist_horizontal, n_dist_vertical )"
"Summary: Deletes an entity when it is determined to be safe to delete (sight checks, times alive, etc.)"

"CallOn: entity to delete"

"OptionalArg: [n_mode] can be DELETE_SAFE (default), DELETE_BEHIND, DELETE_BLOCKED, DELETE_BOTH, or DELETE_AGGRESSIVE (defined in shared.gsh)."
"OptionalArg: [n_min_time_alive] minimum time that the ent should be alive before deleting."
"OptionalArg: [n_dist_horizontal] minimum distance that the entity has to be at from players before deleting."
"OptionalArg: [n_dist_vertical] minimum distance that the entity has to be at from players before deleting."

"Example: ai thread auto_delete(); // DELETE_SAFE by default"
"Example: ai thread auto_delete( DELETE_BEHIND ); // delete if behind all players"
"Example: ai thread auto_delete( DELETE_BLOCKED ); // delete if no players can see"
"Example: ai thread auto_delete( DELETE_BOTH ); // delete if no players can see OR behind all players"
"Example: ai thread auto_delete( DELETE_AGGRESSIVE ); // aggressive version of DELETE_BOTH"
@/
function auto_delete( n_mode = DELETE_SAFE, n_min_time_alive = 0, n_dist_horizontal = 0, n_dist_vertical = 0 ) {}

/@
"Name: query_ents( <a_kvps_match>, [a_kvps_ingnore], [b_ignore_spawners = false], [b_match_substrings = false] )"
"Summary: Do complex lookups for entites based on matching or mot matching a list of KVPs"

"MandatoryArg: <a_kvps_match> An associative array of KVPs to match."
"MandatoryArg: [a_kvps_ingnore] An associative array of KVPs to not match (will not return any entities that match these)."
"OptionalArg: [b_ignore_spawners] Ignore spawners (defaults to false)."
"OptionalArg: [b_match_substrings] Matches substrings of the given KVP values (only supports specific KVPs)."
"OptionalArg: [b_match_all] Set to 'true' to match *all* keys, 'false' to match *any* key."

Example:

	a_ents = util::query_ents(
		AssociativeArray( "targetname", "targetname_i_want_to_get" ),
		AssociativeArray( "script_noteworthy", "i_dont_want_anything_with_this_script_noteworthy" ),
		false,
		true
	);
@/
function query_ents( &a_kvps_match, b_match_all = true, &a_kvps_ingnore, b_ignore_spawners = false, b_match_substrings = false ) {}

function _query_ents_by_substring_helper( &a_ents, str_value, str_key = "targetname", b_ignore_spawners = false ) {}

function get_weapon_by_name( weapon_name ) {}


function is_female() {}

function PositionQuery_PointArray( origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, reachableBy_Ent ) {}

function totalPlayerCount() {}

function isRankEnabled() {}

function isOneRound() {}

function isFirstRound() {}

function isLastRound() {}

function wasLastRound() {}

function hitRoundLimit() {}

function anyTeamHitRoundWinLimit() {}

function anyTeamHitRoundLimitWithDraws() {}

function getRoundWinLimitWinningTeam() {}

function hitRoundWinLimit() {}


function any_team_hit_score_limit() {}


function hitScoreLimit() {}

function get_current_round_score_limit() {}

function any_team_hit_round_score_limit() {}


function hitRoundScoreLimit() {}

function getRoundsWon( team ) {}

function getOtherTeamsRoundsWon( skip_team ) {}

function getRoundsPlayed() {}

function isRoundBased() {}

function GetCurrentGameMode() {}

/@
"Name: ground_position( <v_start>, [n_max_dist = 5000], [n_ground_offset = 0], [e_ignore], [b_ignore_water = false], [b_ignore_glass = false] )"
"Summary: Find a ground location from a starting position."

"MandatoryArg: <v_start> Starting position."
"OptionalArg: [n_max_dist] The max distance.  If the ground isn't found within this distance, the start position will be returned"
"OptionalArg: [n_ground_offset] Return the position that is this vertical offset from the ground."
"OptionalArg: [e_ignore] Optional entity to ignore in the trace."
"OptionalArg: [b_ignore_water] Ignore water."
"OptionalArg: [b_ignore_glass] Ignore glass."

Example:
	
	v_pos = util::ground_position( ent.origin );
@/

function ground_position( v_start, n_max_dist = 5000, n_ground_offset = 0, e_ignore, b_ignore_water = false, b_ignore_glass = false ) {}

/@
"Name: delayed_notify( <str_notify>, <f_delay_seconds> )"
"Summary: Notifies self object of event after a number of seconds"
"MandatoryArg: <str_notify> Notify event name."
"MandatoryArg: <f_delay_seconds> Seconds to wait."
Example: self thread util::delayed_notify( "terminate_all_the_things", 5.0 );
@/

function delayed_notify( str_notify, f_delay_seconds ) {}

/@
"Name: delayed_delete( <f_delay_seconds> )"
"Summary: Deletes an entity after a number of seconds"
"MandatoryArg: <f_delay_seconds> Seconds to wait."
Example: self thread util::delayed_delete( 5.0 );
@/
	
function delayed_delete( str_notify, f_delay_seconds ) {}

/@
"Name: do_chyron_text( str_1, str_2, str_3_full, str_3_short, str_4_full, str_4_short, str_5_full, str_5_short, n_duration )"
"Summary: Creates the chyron text display for the beginning of a campaign level. Must have a minimum of 4 full/short lines"
"Module: Utility"
"CallOn: level"
"MandatoryArg: <str_1_full> : String reference for the full version of the first line of text. E.g. Encryption# 6B-65-20-69. Protocol: Echo"
"MandatoryArg: <str_1_short> : String reference for the short version of the first line of text. E.g. Protocol: Echo. (This can be the same as the full line if not needed)"
"MandatoryArg: <str_2_full> : String reference for the full version of the second line of text. E.g. Considering the continued Rise and Fall of attacks in the region extreme caution is advised"
"MandatoryArg: <str_2_short> : String reference for the short version of the second line of text. E.g. Rise and Fall"
"MandatoryArg: <str_3_full> : String reference for the full version of the third line of text. E.g. Mission: Interrogate Dr Salim in Egypt, Ramses Station and determine the whereabouts of the targets"
"MandatoryArg: <str_3_short> : String reference for the short version of the third line of text. E.g. Egypt, Ramses Station"
"MandatoryArg: <str_4_full> : String reference for the full version of the fourth line of text. E.g. Active Mission - Day 4 "
"MandatoryArg: <str_4_short> : String reference for the short version of the fourth line of text. E.g. Active Mission - Day 4 "
"OptionalArg: <str_5_full> : String reference for the fifth line of text. E.g. Active Mission - Day 4. (Can be left blank as well)"
"OptionalArg: <str_5_full> : String reference for the fifth line of text. E.g. Active Mission - Day 4 (Can be left blank as well)"
"OptionalArg: <n_duration> : Optionally set the duration of the chyron text display. defaults to 12."	
"Example: level do_chyron_text( &"CP_MI_CAIRO_RAMSES_INTRO_LINE_1_FULL", &"CP_MI_CAIRO_RAMSES_INTRO_LINE_1_FULL",
								&"CP_MI_CAIRO_RAMSES_INTRO_LINE_2_FULL", &"CP_MI_CAIRO_RAMSES_INTRO_LINE_2_FULL",
		                        &"CP_MI_CAIRO_RAMSES_INTRO_LINE_3_FULL", &"CP_MI_CAIRO_RAMSES_INTRO_LINE_3_SHORT",
		                        &"CP_MI_CAIRO_RAMSES_INTRO_LINE_4_FULL", &"CP_MI_CAIRO_RAMSES_INTRO_LINE_4_SHORT" );"
"SPMP: server"
@/
function do_chyron_text( str_1_full , str_1_short , str_2_full , str_2_short , str_3_full , str_3_short , str_4_full , str_4_short , str_5_full = "", str_5_short = "" , n_duration ) {}

function player_set_chyron_menu( str_1_full , str_1_short , str_2_full , str_2_short , str_3_full , str_3_short , str_4_full , str_4_short , str_5_full = "", str_5_short = "" , n_duration ) {}

function get_next_safehouse( str_next_map ) {}

function is_safehouse() {}

function is_new_cp_map() {}

/#
function add_queued_debug_command( cmd ) {}

function queued_debug_commands() {}
#/

function player_lock_control() {}

function player_unlock_control() {}

function show_hud( b_show ) {}


/@
"Name: array_copy_if_array( <any_var> )"
"Summary: returns a copy of any_var if it is an array; otherwise returns any_var. Remember to only copy arrays if there is a good reason to do so."
"OptionalArg: <any_var> a var that could be an array or possibly undefined"
"Example: data.victimAttackersThisSpawn = util::array_copy_if_array( data.victimAttackersThisSpawn );"
"SPMP: both"
@/
function array_copy_if_array( any_var ) {}


function is_item_purchased( ref ) {}


function has_purchased_perk_equipped( ref ) {}


function has_purchased_perk_equipped_with_specific_stat( single_perk_ref, stats_table_ref ) {}


function has_flak_jacket_perk_purchased_and_equipped() {}


function has_blind_eye_perk_purchased_and_equipped(){}

function has_ghost_perk_purchased_and_equipped() {}


function has_tactical_mask_purchased_and_equipped() {}


function has_hacker_perk_purchased_and_equipped() {}


function has_cold_blooded_perk_purchased_and_equipped() {}


function has_hard_wired_perk_purchased_and_equipped() {}

function has_gung_ho_perk_purchased_and_equipped() {}


function has_fast_hands_perk_purchased_and_equipped() {}

function has_scavenger_perk_purchased_and_equipped() {}

function has_jetquiet_perk_purchased_and_equipped() {}

function has_awareness_perk_purchased_and_equipped() {}

function has_ninja_perk_purchased_and_equipped() {}

function has_toughness_perk_purchased_and_equipped() {}

function str_strip_lh( str ) {}


function trackWallRunningDistance() {}


function trackSprintDistance() {}


function trackDoubleJumpDistance() {}


function GetPlaySpaceCenter() {}


function GetPlaySpaceMaxWidth() {}
