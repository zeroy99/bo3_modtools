
#namespace flag;

/@
"Name: init( <str_flag> )"
"Summary: Initialize a str_flag to be used. All flags must be initialized before using set or wait.  Some flags for ai are set by default such as 'goal', 'death', and 'damage'"
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to create"
"Example: enemy init( "hq_cleared" );"
"SPMP: singleplayer"
@/
function init( str_flag, b_val = false, b_is_trigger = false ) {}

/@
"Name: exists( <str_flag> )"
"Summary: checks to see if a str_flag exists"
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to check"
"Example: if ( enemy exists( "hq_cleared" ) );"
"SPMP: singleplayer"
@/
function exists( str_flag ) {}

/@
"Name: set( <str_flag> )"
"Summary: Sets the specified str_flag on self, all scripts using wait on self will now continue."
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to set"
"Example: enemy set( "hq_cleared" );"
"SPMP: singleplayer"
@/
function set( str_flag ) {}

/@
"Name: clear( <str_flag> )"
"Summary: Clears the specified str_flag on self."
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to clear"
"Example: enemy clear( "hq_cleared" );"
"SPMP: singleplayer"
@/
function clear( str_flag ) {}

/@
"Name: toggle( <str_flag> )"
"Summary: Toggles the specified ent str_flag."
"Module: Flag"
"MandatoryArg: <str_flag> : name of the str_flag to toggle"
"Example: toggle( "hq_cleared" );"
"SPMP: SP"
@/
function toggle( str_flag ) {}

/@
"Name: get( <str_flag> )"
"Summary: Checks if the str_flag is set on self. Returns true or false."
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to check"
"Example: enemy get( "death" );"
"SPMP: singleplayer"
@/
function get( str_flag ) {}

/@
"Name: wait( <str_flag> )"
"Summary: Waits until the specified str_flag is set on self. Even handles some default flags for ai such as 'goal' and 'damage'"
"Module: Flag"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"MandatoryArg: <str_flag> : name of the str_flag to wait on"
"Example: enemy wait( "goal" );"
"SPMP: singleplayer"
@/
function wait_till( str_flag ) {}

