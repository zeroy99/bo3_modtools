
#namespace duplicate_render;

function set_dr_filter( filterset, name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 ) {}

function update_dr_flag( localClientNum, toset, setto=true ) {}

function set_dr_flag( toset, setto=true ) {}

function clear_dr_flag( toclear ) {}
	 
function change_dr_flags( localClientNum, toset, toclear ) {}

function update_dr_filters(localClientNum) {}

function set_item_retrievable( localClientNum, on_off ) {}

function set_item_unplaceable( localClientNum, on_off ) {}

function set_item_enemy_equipment( localClientNum, on_off ) {}

function set_item_friendly_equipment( localClientNum, on_off ) {}

function set_item_enemy_explosive( localClientNum, on_off ) {}

function set_item_friendly_explosive( localClientNum, on_off ) {}

function set_item_enemy_vehicle( localClientNum, on_off ) {}

function set_item_friendly_vehicle( localClientNum, on_off ) {}

function set_entity_thermal( localClientNum, on_off ) {}

function set_player_threat_detected( localClientNum, on_off ) {}

function set_hacker_tool_hacked( localClientNum,on_off ) {}

function set_hacker_tool_hacking( localClientNum, on_off ) {}

function set_hacker_tool_breaching( localClientNum, on_off ) {}

function show_friendly_outlines( local_client_num ) {}

