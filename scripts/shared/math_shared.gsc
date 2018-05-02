
#namespace math;

function cointoss() {}

/@
"Name: clamp(val, val_min, val_max)"
"Summary: Clamps a value between a min and max value."
"Module: Math"
"MandatoryArg: val: the value to clamp."
"MandatoryArg: val_min: the min value to clamp to."
"MandatoryArg: val_max: the mac value to clamp to."
"Example: clamped_val = clamp(8, 0, 5); // returns 5	*	clamped_val = clamp(-1, 0, 5); // returns 0"
"SPMP: both"
@/
function clamp( val, val_min, val_max ) {}

/@
"Name: linear_map(val, min_a, max_a, min_b, max_b)"
"Summary: Maps a value within one range to a value in another range."
"Module: Math"
"MandatoryArg: val: the value to map."
"MandatoryArg: min_a: the min value of the range in which <val> exists."
"MandatoryArg: max_a: the max value of the range in which <val> exists."
"MandatoryArg: min_b: the min value of the range in which the return value should exist."
"MandatoryArg: max_b: the max value of the range in which the return value should exist."
"Example: fov = linear_map(speed, min_speed, max_speed, min_fov, max_fov);"
"SPMP: both"
@/
function linear_map(num, min_a, max_a, min_b, max_b) {}

/@
"Name: lag(desired, curr, k, dt)"
"Summary: Changes a value from current to desired using 1st order differential lag."
"Module: Math"
"MandatoryArg: desired: desired value."
"MandatoryArg: curr: the current value."
"MandatoryArg: k: the strength of the lag ( lower = slower, higher = faster)."
"MandatoryArg: dt: time step to lag over ( usually 1 server frame )."
"Example: speed = lag(max_speed, speed, 1, 0.05);"
"SPMP: both"
@/
function lag(desired, curr, k, dt) {}

function find_box_center( mins, maxs ) {}

function expand_mins( mins, point ) {}

function expand_maxs( maxs, point ) {}

// ----------------------------------------------------------------------------------------------------
// -- Vectors -----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------

/@
"Name: vector_compare( <vec1>, <vec2> )"
"Summary: For 3D vectors.  Returns true if the vectors are the same"
"MandatoryArg: <vec1> : A 3D vector (origin)"
"MandatoryArg: <vec2> : A 3D vector (origin)"
"Example: if (vector_compare(self.origin, node.origin){print(\"yay, i'm on the node!\");}"
"SPMP: both"
@/
function vector_compare(vec1, vec2) {}

function random_vector(max_length) {}

function angle_dif(oldangle, newangle) {}

function sign( x ) {}

function randomSign() {}

/@
"Name: get_dot_direction( <v_point>, [b_ignore_z], [b_normalize], [str_direction], [ b_use_eye] )"
"Summary: Calculates and returns dot between an entity's directional vector and a point."
"Module: Math"
"CallOn: Entity. Must have origin and angles parameters."
"MandatoryArg: <v_point> vector position to check against entity origin and angles"
"OptionalArg: <b_ignore_z> specify if get_dot should consider 2d or 3d dot. Defaults to false for 3d dot."
"OptionalArg: <str_direction> specify which vector type to use on angles. Valid options are "forward", "backward", "right", "left", "up" and "down". Defaults to "forward"."
"OptionalArg: <b_normalize> specify if the function should normalize the vector to target point. Defaults to true."
"OptionalArg: <b_use_eye> if self a player or AI, use tag_eye rather than .angles. Defaults to true on players, defaults to false on everything else.
"Example: n_dot = player get_dot_direction( woods.origin );"
"SPMP: singleplayer"
@/
function get_dot_direction( v_point, b_ignore_z, b_normalize, str_direction, b_use_eye ) {}

/@
"Name: get_dot_right( <v_point>, [b_ignore_z], [b_normalize] )"
"Summary: Calculates and returns dot between an entity's right vector and a point."
"Module: Math"
"CallOn: Entity. Must have origin and angles parameters."
"MandatoryArg: <v_point> vector position to check against entity origin and angles"
"OptionalArg: <b_ignore_z> specify if get_dot should consider 2d or 3d dot. Defaults to false for 3d dot."
"OptionalArg: <b_normalize> specify if the function should normalize the vector to target point. Defaults to true."
"Example: n_dot = player get_dot_direction( woods.origin );"
"SPMP: singleplayer"
@/
function get_dot_right( v_point, b_ignore_z, b_normalize ) {}

/@
"Name: get_dot_up( <v_point>, [b_ignore_z], [b_normalize] )"
"Summary: Calculates and returns dot between an entity's up vector and a point."
"Module: Math"
"CallOn: Entity. Must have origin and angles parameters."
"MandatoryArg: <v_point> vector position to check against entity origin and angles"
"OptionalArg: <b_ignore_z> specify if get_dot should consider 2d or 3d dot. Defaults to false for 3d dot."
"OptionalArg: <b_normalize> specify if the function should normalize the vector to target point. Defaults to true."
"Example: n_dot = player get_dot_direction( woods.origin );"
"SPMP: singleplayer"
@/
function get_dot_up( v_point, b_ignore_z, b_normalize ) {}

/@
"Name: get_dot_forward( <v_point>, [b_ignore_z], [b_normalize] )"
"Summary: Calculates and returns dot between an entity's forward vector and a point."
"Module: Math"
"CallOn: Entity. Must have origin and angles parameters."
"MandatoryArg: <v_point> vector position to check against entity origin and angles"
"OptionalArg: <b_ignore_z> specify if get_dot should consider 2d or 3d dot. Defaults to false for 3d dot."
"OptionalArg: <b_normalize> specify if the function should normalize the vector to target point. Defaults to true."
"Example: n_dot = player get_dot_direction( woods.origin );"
"SPMP: singleplayer"
@/
function get_dot_forward( v_point, b_ignore_z, b_normalize ) {}

/@
"Name: get_dot_from_eye( <v_point>, [b_ignore_z], [b_normalize], [str_direction] )"
"Summary: Calculates and returns dot between an entity's forward vector and a point based on tag_eye. Only use on players or AI"
"Module: Math"
"CallOn: Entity. Must have origin and angles parameters."
"MandatoryArg: <v_point> vector position to check against entity origin and angles"
"OptionalArg: [b_ignore_z] specify if get_dot should consider 2d or 3d dot. Defaults to false for 3d dot."
"OptionalArg: [b_normalize] specify if the function should normalize the vector to target point. Defaults to true."
"OptionalArg: [str_direction] specify which vector type to use on angles. Valid options are "forward", "backward", "right", "left", "up" and "down". Defaults to "forward"."
"Example: n_dot = player get_dot_from_eye( woods.origin );"
"SPMP: singleplayer"
@/
function get_dot_from_eye( v_point, b_ignore_z, b_normalize, str_direction ) {}

// ----------------------------------------------------------------------------------------------------
// -- Arrays ------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------

/@
"Name: array_average( <array> )"
"Summary: Given an array of numbers, returns the average (mean) value of the array"
"Module: Utility"
"MandatoryArg: <array>: the array of numbers which will be averaged"
"Example: array_average( numbers );"
"SPMP: both"
@/
function array_average( array ) {}

/@
"Name: array_std_deviation( <array>, <mean> )"
"Summary: Given an array of numbers and the average of the array, returns the standard deviation value of the array"
"Module: Utility"
"MandatoryArg: <array>: the array of numbers"
"MandatoryArg: <mean>: the average (mean) value of the array"
"Example: array_std_deviation( numbers, avg );"
"SPMP: both"
@/
function array_std_deviation( array, mean ) {}

/@
"Name: random_normal_distribution( <mean>, <std_deviation>, <lower_bound>, <upper_bound> )"
"Summary: Given the mean and std deviation of a set of numbers, returns a random number from the normal distribution"
"Module: Utility"
"MandatoryArg: <mean>: the average (mean) value of the array"
"MandatoryArg: <std_deviation>: the standard deviation value of the array"
"OptionalArg: <lower_bound> the minimum value that will be returned"
"OptionalArg: <upper_bound> the maximum value that will be returned"
"Example: random_normal_distribution( avg, std_deviation );"
"SPMP: both"
@/
function random_normal_distribution( mean, std_deviation, lower_bound, upper_bound ) {}

function closest_point_on_line( point, lineStart, lineEnd ) {}

function get_2d_yaw( start, end ) {}

function vec_to_angles( vector ) {}

function pow( base, exp ) {}
