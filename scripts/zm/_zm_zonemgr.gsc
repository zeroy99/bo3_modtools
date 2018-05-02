
#namespace zm_zonemgr;

function entity_in_active_zone( ignore_enabled_check = false ) {}

//	When the wait_flag gets set (like when a door opens), the add_flags will also get set.
//	This provides a slightly less clunky way to connect multiple contiguous zones within an area
//
//	wait_flag = flag to wait for
//	adj_flags = array of flag strings to set when flag is set
function add_zone_flags( wait_flag, add_flags ) {}

//
// Makes zone_b adjacent to zone_a.  If one_way is false, zone_a is also made "adjacent" to zone_b
//	Note that you may not always want zombies coming from zone B while you are in Zone A, but you 
//	might want them to come from A while in B.  It's a rare case though, such as a one-way traversal.
function add_adjacent_zone( zone_name_a, zone_name_b, flag_name, one_way, zone_tag_a, zone_tag_b ) {}

//--------------------------------------------------------------
//	This needs to be called when new zones open up via doors
//--------------------------------------------------------------
function connect_zones( zone_name_a, zone_name_b, one_way ) {}

//--------------------------------------------------------------
//	This one function will handle managing all zones in your map
//	to turn them on/off - probably the best way to handle this
//--------------------------------------------------------------
function manage_zones( initial_zone ) {}



