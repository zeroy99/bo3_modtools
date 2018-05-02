
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

function waitforallclients() {}

function waitforclient(client) {}

function get_dvar_float_default( str_dvar, default_val ) {}

function get_dvar_int_default( str_dvar, default_val ) {}

/@
"Name: spawn_model(<model_name>, [origin], [angles])"
"Summary: Spawns a model at an origin and angles."
"Module: Utility"
"MandatoryArg: <model_name> the model name."
"OptionalArg: [origin] the origin to spawn the model at."
"OptionalArg: [angles] the angles to spawn the model at."
"Example: fx_model = spawn_model("tag_origin", org, ang);"
"SPMP: SP"
@/
function spawn_model( n_client, str_model, origin = ( 0, 0, 0 ), angles = ( 0, 0, 0 ) ) {}

// ----------------------------------------------------------------------------------------------------
// -- Arrays ------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------

function waittill_string( msg, ent ) {}

/@
"Name: waittill_multiple( <string1>, <string2>, <string3>, <string4>, <string5> )"
"Summary: Waits for all of the the specified notifies."
"MandatoryArg:	The notifies to wait on."
"Example: guy waittill_multiple( "goal", "pain", "near_goal", "bulletwhizby" );"
@/
function waittill_multiple( ... ) {}

/@
"Name: waittill_multiple_ents( ... )"
"Summary: Waits for all of the the specified notifies on their associated entities."
"MandatoryArg:	List of ents and the notifies to wait on."
"Example: waittill_multiple_ents( guy, "goal", guy, "pain", guy, "near_goal", player, "weapon_change" );"
@/
function waittill_multiple_ents( ... ) {}


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
"Example: guy waittill_any( "goal", "pain", "near_goal", "bulletwhizby" );"
"SPMP: both"
@/
function waittill_any( str_notify1, str_notify2, str_notify3, str_notify4, str_notify5 ) {}

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

/@
"Name: waittill_notify_or_timeout( <msg>, <timer> )"
"Summary: Waits until the owner receives the specified notify message or the specified time runs out. Do not thread this!"
"CallOn: an entity"
"Example: tank waittill_notify_or_timeout( "turret_on_target", 10 ); "
"MandatoryArg: <msg> : The notify to wait for."
"MandatoryArg: <timer> : The amount of time to wait until overriding the wait statement."
@/
function waittill_notify_or_timeout( msg, timer ) {}

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
"Name: array_ent_thread( <entities>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5] )"
"Summary: Threads the <func> function on self for every entity in the <entities> array, passing the entity has the first argument."
"Module: Array"
"CallOn: NA"
"MandatoryArg: entities : array of entities to thread the process"
"MandatoryArg: func : pointer to a script function"
"OptionalArg: arg1 : parameter 1 to pass to the func (after the entity)"
"OptionalArg: arg2 : parameter 2 to pass to the func (after the entity)"
"OptionalArg: arg3 : parameter 3 to pass to the func (after the entity)"
"OptionalArg: arg4 : parameter 4 to pass to the func (after the entity)"
"OptionalArg: arg5 : parameter 5 to pass to the func (after the entity)"
"Example: array_ent_thread( GetAITeamArray("allies"),&do_something, false );"
"SPMP: both"
@/
function array_ent_thread( entities, func, arg1, arg2, arg3, arg4, arg5 ) {}

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

function add_listen_thread( wait_till, func, param1, param2, param3, param4, param5 ) {}

/@
"Name: timeout( <n_time>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Run any function with a timeout.  The function will exit when the timeout is reached."
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
@/
function timeout( n_time, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}


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


/@
"Name: delay_notify( <n_delay>, <str_notify>, [str_endon] )"
"Summary: Notifies self the string after waiting the specified delay time"
"Module: Entity"
"CallOn: An entity"
"MandatoryArg: <time_or_notify> : Time to wait( in seconds ) or notify to wait for before sending the notify."
"MandatoryArg: <str_notify> : The string to notify"
"OptionalArg: <str_endon> : Endon to cancel the notify"
"Example: vehicle delay_notify( 3.5, "start_to_smoke" );"
"SPMP: singleplayer"
@/
function delay_notify( time_or_notify, str_notify, str_endon ) {}

// Time

function new_timer( n_timer_length ) {}

function get_time() {}

function get_time_in_seconds() {}

function get_time_frac( n_end_time ) {}

function get_time_left() {}

function is_time_left() {}

function timer_wait( n_wait ) {}

function add_remove_list( &a, on_off ) {}

function clean_deleted( &array ) {}

/@
"Name: get_eye()"
"Summary: Get eye position accurately even on a player when linked to an entity."
"Module: Utility"
"CallOn: Player or AI"
"Example: eye_pos = player get_eye();"
"SPMP: both"
@/
function get_eye() {}

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

function register_system(sSysName, cbFunc) {}


function waittill_dobj(localClientNum) {}

function server_wait( localClientNum, seconds, waitBetweenChecks, level_endon ) {}

function friend_not_foe( localClientIndex, predicted ) {}

function friend_not_foe_team( localClientIndex, team, predicted ) {}


function IsEnemyPlayer( player ) {}

function is_player_view_linked_to_entity(localClientNum) {}

/@
"Name: within_fov( <start_origin> , <start_angles> , <end_origin> , <fov> )"
"Summary: Returns true if < end_origin > is within the players field of view, otherwise returns false."
"Module: Vector"
"CallOn: "
"MandatoryArg: <start_origin> : starting origin for FOV check( usually the players origin )"
"MandatoryArg: <start_angles> : angles to specify facing direction( usually the players angles )"
"MandatoryArg: <end_origin> : origin to check if it is in the FOV"
"MandatoryArg: <fov> : cosine of the FOV angle to use"
"Example: qBool = within_fov( level.player.origin, level.player.angles, target1.origin, cos( 45 ) );"
"SPMP: multiplayer"
@/ 
function within_fov( start_origin, start_angles, end_origin, fov ) {}

function is_mature() {}


function debug_line( from, to, color, time ) {}

function debug_star( origin, color, time ) {}

function serverTime() {}

function getNextObjID( localClientNum ) {}

function releaseObjID( localClientNum, objID ) {}



