
#namespace array;

/@
@/
function filter( &array, b_keep_keys, func_filter, arg1, arg2, arg3, arg4, arg5  ) {}

/@
@/
function remove_undefined( array, b_keep_keys ) {}

function get_touching( &array, b_keep_keys ) {}

/@
"Name: array::remove_index( <array>, <index>, [b_keep_keys]  )"
"Summary: Removes a specified index from an array, returns a new array with the specified index removed."
"Module: Array"
"MandatoryArg: <array> : The array we will remove an index from."
"MandatoryArg: <index> : The index we will remove from the array."
"OptionalArg:  [b_keep_keys] : If true, retain existing keys. If false or undefined, existing keys of original array will be replaced by ints."
"Example: a_new = array::remove_index( array, 3 );"
"SPMP: both"
@/
function remove_index( array, index, b_keep_keys ) {}

/@
"Name: array::delete_all( <array> )"
"Summary: Delete all the elements in an array"
"Module: Array"
"MandatoryArg: <array> : The array whose elements to delete."
"Example: array::delete_all( GetAITeamArray( "axis" ) );"
"SPMP: both"
@/
function delete_all( &array, is_struct ) {}

/@
"Name: array::notify_all( <array>, <notify> )"
"Summary: Sends a notify to every element within the array"
"Module: Utility"
"MandatoryArg: <array>: the array of entities to wait on"
"MandatoryArg: <notify>: the string notify sent to the elements"
"Example: array::notify_all( soldiers, "fire" );"
"SPMP: both"
@/
function notify_all( &array, str_notify ) {}

/@
"Name: thread_all( <entities>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Threads the < func > function on every entity in the < entities > array. The entity will become "self" in the specified function."
"Module: Array"
"CallOn: "
"MandatoryArg: entities : array of entities to thread the function"
"MandatoryArg: func : pointer to a script function"
"OptionalArg: arg1: parameter 1 to pass to the func"
"OptionalArg: arg2 : parameter 2 to pass to the func"
"OptionalArg: arg3 : parameter 3 to pass to the func"
"OptionalArg: arg4 : parameter 4 to pass to the func"
"OptionalArg: arg5 : parameter 5 to pass to the func"
"OptionalArg: arg6 : parameter 6 to pass to the func"
"Example: array::thread_all( GetAITeamArray( "allies" ), &set_ignoreme, false );"
"SPMP: both"
@/
function thread_all( &entities, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: thread_all_ents( <entities>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5] )"
"Summary: Threads the <func> function on self for every entity in the <entities> array, passing the entity has the first argument."
"Module: Array"
"CallOn: NA"
"MandatoryArg: entities : array of entities to thread the function"
"MandatoryArg: func : pointer to a script function"
"OptionalArg: arg1 : parameter 1 to pass to the func (after the entity)"
"OptionalArg: arg2 : parameter 2 to pass to the func (after the entity)"
"OptionalArg: arg3 : parameter 3 to pass to the func (after the entity)"
"OptionalArg: arg4 : parameter 4 to pass to the func (after the entity)"
"OptionalArg: arg5 : parameter 5 to pass to the func (after the entity)"
"Example: array::thread_all_ents( GetAITeamArray( "allies" ), &do_something, false );"
"SPMP: both"
@/
function thread_all_ents( &entities, func, arg1, arg2, arg3, arg4, arg5 ) {}


/@
"Name: run_all( <entities>, <func>, [arg1], [arg2], [arg3], [arg4], [arg5], [arg6] )"
"Summary: Runs the < func > function on every entity in the < entities > array. The entity will become "self" in the specified function."
"Module: Array"
"CallOn: "
"MandatoryArg: entities : array of entities to run the function"
"MandatoryArg: func : pointer to a script function"
"OptionalArg: arg1: parameter 1 to pass to the func"
"OptionalArg: arg2 : parameter 2 to pass to the func"
"OptionalArg: arg3 : parameter 3 to pass to the func"
"OptionalArg: arg4 : parameter 4 to pass to the func"
"OptionalArg: arg5 : parameter 5 to pass to the func"
"OptionalArg: arg6 : parameter 6 to pass to the func"
"Example: array::run_all( GetAITeamArray( "allies" ), &set_ignoreme, false );"
"SPMP: both"
@/
function run_all( &entities, func, arg1, arg2, arg3, arg4, arg5, arg6 ) {}

/@
"Name: array::exclude( <array> , <array_exclude> )"
"Summary: Returns an array excluding all members of < array_exclude > "
"Module: Array"
"CallOn: "
"MandatoryArg: <array> : Array containing all items"
"MandatoryArg: <array_exclude> : Array containing all items to remove or individual entity"
"Example: newArray = array::exclude( array1, array2 );"
"SPMP: both"
@/
function exclude( array, array_exclude ) {}

/@
"Name: array::add( <array> , <item>, <allow_dupes> )"
"Summary: Adds <item> to <array>.  Will not add the new value if undefined."
"Module: Array"
"MandatoryArg:	<array> The array to add <item> to."
"MandatoryArg:	<item> The item to be added. This can be anything."
"OptionalArg:	<allow_dupes> If true, will add the new value if it already exists."
"Example: array::add( nodes, new_node );"
"SPMP: both"
@/
function add( &array, item, allow_dupes = true ) {}

/@
"Name: array::add_sorted( <array> , <item>, <allow_dupes> )"
"Summary: Adds <item> to <array> in sorted order from smallest to biggest.  Will not add the new value if undefined."
"Module: Array"
"CallOn: "
"MandatoryArg:	<array> The array to add <item> to."
"MandatoryArg:	<item> The item to be added. This can be anything."
"OptionalArg:	<allow_dupes> If true, will add the new value if it already exists."
"Example: array::add_sorted( a_numbers, 4 );"
"SPMP: both"
@/
function add_sorted( &array, item, allow_dupes = true ) {}

/@
"Name: array::wait_till( <array>, <msg>, <n_timeout> )"
"Summary: waits for every entry in the <array> to recieve the <msg> notify, die, or n_timeout"
"Module: Utility"
"MandatoryArg: <array>: the array of entities to wait on"
"MandatoryArg: <msg>: the msg each array entity will wait on"
"OptionalArg: <n_timeout>: n_timeout to kill the wait prematurely"
"Example: array::wait_till( guys, "at the hq" );"
"SPMP: both"
@/
function wait_till( &array, msg, n_timeout ) {}

/@
@/
function flag_wait( &array, str_flag ) {}

/@
@/
function flagsys_wait( &array, str_flag ) {}

/@
@/
function flagsys_wait_any_flag( &array, ... ) {}

/@
@/
function flag_wait_clear( &array, str_flag ) {}

/@
@/
function flagsys_wait_clear( &array, str_flag ) {}

/@
"Name: wait_any( <array>, <msg>, <n_timeout> )"
"Summary: waits for any entry in the <array> to recieve the <msg> notify, die, or n_timeout"
"Module: Utility"
"MandatoryArg: <array>: the array of entities to wait on"
"MandatoryArg: <msg>: the msg each array entity will wait on"
"OptionalArg: <n_timeout>: n_timeout to kill the wait prematurely"
"Example: array_wait_any( guys, "at the hq" );"
"SPMP: both"
@/
function wait_any( array, msg, n_timeout ) {}

function flag_wait_any( array, str_flag ) {}

/@
"Name: random( <array> )"
"Summary: returns a random element from the passed in array "
"Module: Array"
"Example: random_spawner = random( event_1_spawners );"
"MandatoryArg: <array> : the array from which to pluck a random element"
"SPMP: both"
@/
function random( array ) {}

/@
@/
function randomize( array ) {}

/@
"Name: array::reverse( <array> )"
"Summary: Reverses the order of the array and returns the new array."
"Module: Array"
"CallOn: "
"MandatoryArg: <array> : Array to be reversed."
"Example: patrol_nodes = array::reverse( patrol_nodes );"
"SPMP: both"
@/
function reverse( array ) {}

/@
@/
function remove_keys( array ) {}

/@
@/
function swap( &array, index1, index2 ) {}

function pop( &array, index, b_keep_keys = true ) {}

function pop_front( &array, b_keep_keys = true ) {}

function push( &array, val, index ) {}

function push_front( &array, val ) {}

/@
"Name: get_closest( <org> , <array> , <dist> )"
"Summary: Returns the closest entity in < array > to location < org > "
"Module: Distance"
"CallOn: "
"MandatoryArg: <org> : Origin to be closest to."
"MandatoryArg: <array> : Array of entities to check distance on"
"OptionalArg: <dist> : Minimum distance to check"
"Example: friendly = util::get_closest( GetPlayers( localclientnum )[0].origin, allies );"
"SPMP: singleplayer"
@/
function get_closest( org, &array, dist = undefined) {}

/@
"Name: getFarthest( <org> , <array> , <dist> )"
"Summary: Returns the farthest entity in < array > to location < org > "
"Module: Distance"
"CallOn: "
"MandatoryArg: <org> : Origin to be farthest from."
"MandatoryArg: <array> : Array of entities to check distance on"
"OptionalArg: <dist> : Maximum distance to check"
"Example: target = getFarthest( level.player.origin, targets );"
"SPMP: singleplayer"
@/ 
function get_farthest( org, &array, dist = undefined ) {}

/@
"Name: get_all_farthest( <org> , <array> , <excluders> , <max> )"
"Summary: Returns an array of all the entities in < array > sorted in order of farthest to closest."
"MandatoryArg: <org> : Origin to be farthest from."
"MandatoryArg: <array> : Array of entities (anything that contain .origin) to check distance on."
"OptionalArg: <excluders> : Array of entities to exclude from the check."
"OptionalArg: <max> : Max size of the array to return"
"Example: allies_sort = get_all_farthest( originFC1.origin, allies );"
"SPMP: singleplayer"
@/
function get_all_farthest( org, &array, excluders, max ) {}

/@
"Name: get_all_closest( <org> , <array> , <excluders> , <max>, <maxdist> )"
"Summary: Returns an array of all the entities in < array > sorted in order of closest to farthest."
"Module: Distance"
"CallOn: "
"MandatoryArg: <org> : Origin to be closest to."
"MandatoryArg: <array> : Array of entities to check distance on."
"OptionalArg: <excluders> : Array of entities to exclude from the check."
"OptionalArg: <max> : Max size of the array to return"
"OptionalArg: <maxdist> : Max distance from the origin to return acceptable entities"
"Example: allies_sort = get_all_closest( originFC1.origin, allies );"
"SPMP: singleplayer"
@/ 
function get_all_closest( org, &array, excluders, max, maxdist ) {}

function alphabetize( &array ) {}

/@
function Name: sort_by_value( array, b_lowest_first = true )
Summary: sorts a list of ents by their value
Module: Utility
CallOn: n/a
ManditoryArg: <array>: array of values to sort
OptionalArg: [b_lowest_first]: sort from lowest to highest
function Example: list = array::sort_by_value( array );
SPMP: singleplayer
@/
//Use ArraySort for distance based sorting of entities
function sort_by_value( &array, b_lowest_first = false ) {}

/@
function Name: sort_by_script_int( a_ents, b_lowest_first = true )
Summary: sorts a list of ents by their script_int value
Module: Utility
CallOn: n/a
ManditoryArg: <a_ents>: array of entities to sort
OptionalArg: [b_lowest_first]: sort from lowest to highest
function Example: list = array::sort_by_script_int( a_ents );
SPMP: singleplayer
@/
//Use ArraySort for distance based sorting of entities
function sort_by_script_int( &a_ents, b_lowest_first = false ) {}


function merge_sort( &current_list, func_sort, param ) {}


function merge( left, right, func_sort, param ) {}

/@
"Name: spread_all( <entities> , <process> , <var1> , <var2> , <var3> )"
"Summary: Threads the < process > function on every entity in the < entities > array. Each thread is started 1 network frame apart from the next."
"Module: Array"
"CallOn: "
"MandatoryArg: <entities> : array of entities to thread the process"
"MandatoryArg: <process> : pointer to a script function"
"OptionalArg: <var1> : parameter 1 to pass to the process"
"OptionalArg: <var2> : parameter 2 to pass to the process"
"OptionalArg: <var3> : parameter 3 to pass to the process"
"Example: array::spread_all( GetAITeamArray( "allies" ),&set_ignoreme, false );"
"SPMP: Both"
@/

function spread_all( &entities, func, arg1, arg2, arg3, arg4, arg5 ) {}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
