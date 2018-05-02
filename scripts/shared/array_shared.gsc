#namespace array;

/@
@/
function filter( &array, b_keep_keys, func_filter, arg1, arg2, arg3, arg4, arg5  ) {}

/@
@/
function remove_dead( &array, b_keep_keys ) {}

/@
@/
function remove_undefined( &array, b_keep_keys ) {}

/@
@/
function filter_classname( &array, b_keep_keys, str_classname ) {}

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
"CallOn: "
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
"Name: array::wait_till( <array>, <str_notify>, [n_timeout] )"
"Summary: waits for every entry in the <array> to recieve the notify, die, or n_timeout"
"Module: Utility"
"MandatoryArg: <array>: the array of entities to wait on"
"MandatoryArg: <notifies>: the notify each array entity will wait on.  Can also be an array of notifies (will wait for *any* of the notifies)."
"OptionalArg: [n_timeout]: n_timeout to kill the wait prematurely"
"Example: array::wait_till( guys, "at the hq" );"
"SPMP: both"
@/
function wait_till( &array, notifies, n_timeout ) {}

/@
"Name: array::wait_till_match( <array>, <str_notify>, <str_match>, [n_timeout] )"
"Summary: waits for every entry in the <array> to recieve the notify with a match parameter, die, or n_timeout"
"Module: Utility"
"MandatoryArg: <array>: the array of entities to wait on"
"MandatoryArg: <str_notify>: the notify each array entity will wait on.  Can also be an array of notifies (will wait for *any* of the notifies)."
"MandatoryArg: <str_match>: the notify match value to wait for."
"OptionalArg: <n_timeout>: n_timeout to kill the wait prematurely"
"Example: array::wait_till( guys, "at the hq" );"
"SPMP: both"
@/
function wait_till_match( &array, str_notify, str_match, n_timeout ) {}

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
"Name: randomize( <array> )"
"Summary: returns a randomized new array from the passed in array "
"Module: Array"
"Example: a_spawn_pos = randomize( a_spawn_pos );"
"MandatoryArg: <array> : the array from which to create the new random array from"
"SPMP: both"
@/
function randomize( array ) {}

/@
"Name: clamp_size( <array>, <n_size> )"
"Summary: returns a chopped off version of the array with only n_count number of elements."
"Example: a_spawn_pos = clamp_size( a_spawn_pos, 255 );"
"MandatoryArg: <array> : the array from which to create the new array from"
"MandatoryArg: <n_size> : the size of the array to return"
@/
function clamp_size( array, n_size ) {}

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
"Example: friendly = array::get_closest( GetPlayers()[0].origin, allies );"
"SPMP: singleplayer"
@/
function get_closest( org, &array, dist ) {}

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
"Name: get_all_farthest( <org> , <array> , [a_exclude] , [n_max], [n_maxdist] )"
"Summary: Returns an array of all the entities in < array > sorted in order of farthest to closest."
"MandatoryArg: <org> : Origin to be farthest from."
"MandatoryArg: <array> : Array of entities (anything that contain .origin) to check distance on."
"OptionalArg: <a_exclude> : Array of entities to exclude from the check."
"OptionalArg: <n_max> : max size of the array to return"
"OptionalArg: <n_maxdist> : max distance from the origin to return acceptable entities"
"Example: allies_sort = get_all_farthest( originFC1.origin, allies );"
@/
function get_all_farthest( org, &array, a_exclude, n_max, n_maxdist )
{
	DEFAULT( n_max, array.size );
	
	a_ret = exclude( array, a_exclude );
	
	if ( isdefined( n_maxdist ) )
	{
		a_ret = ArraySort( a_ret, org, false, n_max, n_maxdist );
	}
	else
	{
		a_ret = ArraySort( a_ret, org, false, n_max );
	}
	
	return a_ret;
}

/@
"Name: get_all_closest( <org> , <array> , [a_exclude] , [n_max], [n_maxdist] )"
"Summary: Returns an array of all the entities in < array > sorted in order of closest to farthest."
"CallOn: "
"MandatoryArg: <org> : Origin to be closest to."
"MandatoryArg: <array> : Array of entities to check distance on."
"OptionalArg: <a_exclude> : Array of entities to exclude from the check."
"OptionalArg: <n_max> : max size of the array to return"
"OptionalArg: <n_maxdist> : max distance from the origin to return acceptable entities"
"Example: allies_sort = get_all_closest( originFC1.origin, allies );"
@/ 
function get_all_closest( org, &array, a_exclude, n_max, n_maxdist )
{
	DEFAULT( n_max, array.size );
	
	a_ret = exclude( array, a_exclude );
	
	if ( isdefined( n_maxdist ) )
	{
		a_ret = ArraySort( a_ret, org, true, n_max, n_maxdist );
	}
	else
	{
		a_ret = ArraySort( a_ret, org, true, n_max );
	}
	
	return a_ret;
}

function alphabetize( &array )
{
	return sort_by_value( array, true );
}

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
function sort_by_value( &array, b_lowest_first = false )
{
	return merge_sort( array, &_sort_by_value_compare_func, b_lowest_first );
}

function _sort_by_value_compare_func( val1, val2, b_lowest_first )
{
	if ( b_lowest_first )
	{
		return val1 < val2;
	}
	else
	{
		return val1 > val2;
	}
}

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
function sort_by_script_int( &a_ents, b_lowest_first = false )
{
	return merge_sort( a_ents, &_sort_by_script_int_compare_func, b_lowest_first );
}

function _sort_by_script_int_compare_func( e1, e2, b_lowest_first )
{
	if ( b_lowest_first )
	{
		return e1.script_int < e2.script_int;
	}
	else
	{
		return e1.script_int > e2.script_int;
	}
}

function merge_sort( &current_list, func_sort, param )
{
	if ( current_list.size <= 1 )
	{
		return current_list;
	}
		
	left = [];
	right = [];
	
	middle = current_list.size / 2;
	
	for ( x = 0; x < middle; x++ )
	{
		ARRAY_ADD( left, current_list[ x ] );
	}
	
	for ( ; x < current_list.size; x++ )
	{
		ARRAY_ADD( right, current_list[ x ] );
	}
	
	left = merge_sort( left, func_sort, param );
	right = merge_sort( right, func_sort, param );
	
	result = merge( left, right, func_sort, param );

	return result;
}

function merge( left, right, func_sort, param )
{
	result = [];

	li = 0;
	ri = 0;
	while ( li < left.size && ri < right.size )
	{
		b_result = undefined;
		
		if ( isdefined( param ) )
		{
			b_result = [[ func_sort ]]( left[ li ], right[ ri ], param );
		}
		else
		{
			b_result = [[ func_sort ]]( left[ li ], right[ ri ] );
		}
		
		if ( b_result )
		{
			result[ result.size ] = left[ li ];
			li++;
		}
		else
		{
			result[ result.size ] = right[ ri ];
			ri++;
		}
	}

	while ( li < left.size )
	{
		result[ result.size ] = left[ li ];
		li++;
	}

	while ( ri < right.size )
	{
		result[ result.size ] = right[ ri ];
		ri++;
	}

	return result;
}

/@
"Name: insertion_sort( <array>, <compareFunc> , <val> )"
"Summary: performs and insertion sort into <array> of the value <val> based on result of <compareFunc>.  input <array> must already be sorted!  <array> must have integer keys.
"Module: Array"
"CallOn: "
"MandatoryArg: <array> : array to operate on, works in place"
"MandatoryArg: <compareFunc> : foo(a,b);  function that returns the results of comparison, <0 if a<b, 0 if a==b, >0 if a>b"
"MadatoryArg: <val> : the value to insert"
"Example: array::insertion_sort( a, foo, b );"
"SPMP: Both"
@/

function insertion_sort( &a, compareFunc, val )
{
	if (!IsDefined(a))
	{
		a=[];
		a[0]=val;
		return ;
	}
	
	for (i=0;i<a.size;i++)
	{
		if ([[compareFunc]](a[i],val)<=0)
		{
			ArrayInsert(a,val,i);
			return ;
		}
	}
	a[a.size]=val;
}

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

function spread_all( &entities, func, arg1, arg2, arg3, arg4, arg5 )
{
	Assert( isdefined( entities ), "Undefined entity array passed to array::spread_all_ents" );
	Assert( isdefined( func ), "Undefined function passed to array::spread_all_ents" );
	
	if ( IsArray( entities ) )
	{
		foreach ( ent in entities )
		{
			if( isdefined(ent) )
			{
				util::single_thread( ent, func, arg1, arg2, arg3, arg4, arg5 );
			}
			WAIT_ABOUT( .1 );
		}
	}
	else
	{
		util::single_thread( entities, func, arg1, arg2, arg3, arg4, arg5 );
		WAIT_ABOUT( .1 );
	}
}

/@
"Name: wait_till_touching( <array> , <volume> )"
"Summary: Waits until all entities in <array> are touching <volume> at the same time"
"Module: array"
"CallOn: "
"MandatoryArg:	<array> The array of entities."
"MandatoryArg:	<volume> The volume to check for touching"
"Example: array::wait_till_touching(a_group_of_dudes, e_volume_to_wait_for);"
@/
function wait_till_touching( &a_ents, e_volume )
{
	while ( !is_touching( a_ents, e_volume ) )
	{
		wait 0.05;
	}	
}

/@
"Name: is_touching( <array> , <volume> )"
"Summary: Returns true if all entities in <array> are touching <volume>"
"Module: array"
"CallOn: "
"MandatoryArg:	<array> The array of entities."
"MandatoryArg:	<volume> The volume to check for touching"
"Example: array::is_touching(a_group_of_dudes, e_volume);"
@/
function is_touching( &a_ents, e_volume )
{
	foreach ( e_ent in a_ents )
	{
		if ( !e_ent IsTouching( e_volume ) )
	    {
	        return false;
	    }
	}
	
	return true;
}

/@
"Name: contains( <array> , <value> )"
"Summary: Returns true if <value> is found in <array>"
"Module: array"
"MandatoryArg:	<array> The array of possible values. can be a single value."
"MandatoryArg:	<value> The value to search for"
"Example: array::contains(array_numbers_1_to_10, 5) || array::contains(8, 8);"
@/
function contains( array_or_val, value )
{
	if ( isArray ( array_or_val ) )
	{
		foreach( element in array_or_val )
		{
			if ( element === value )
			{
				return true;
			}
		}
		
		return false;
	}
	
	return array_or_val === value;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _filter_dead( val )
{
	return IsAlive( val );
}

function _filter_classname( val, arg )
{
	return IsSubStr( val.classname, arg );
}

// Quick Sort - pass it an array it will come back sorted
function quickSort(array, compare_func) 
{
    return quickSortMid(array, 0, array.size -1, compare_func);     
}

function quickSortMid(array, start, end, compare_func)
{
	i = start;
	k = end;

    if(!IsDefined(compare_func))
        compare_func = &quickSort_compare;
    
	if (end - start >= 1)
    {
        pivot = array[start];  

        while (k > i)         
        {
            while ( [[ compare_func ]](array[i], pivot) && i <= end && k > i)
	        	i++;                                 
            while ( ![[ compare_func ]](array[k], pivot) && k >= start && k >= i)
	            k--;                                      
	        if (k > i)                                 
	           swap(array, i, k);                    
        }
        swap(array, start, k);                                               
        array = quickSortMid(array, start, k - 1, compare_func); 
        array = quickSortMid(array, k + 1, end, compare_func);   
    }
	else
    	return array;
    
    return array;
}

function quicksort_compare(left, right)
{
    return left<=right;
}