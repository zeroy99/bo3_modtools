#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#using scripts\shared\util_shared;
#namespace bb;



function init_shared() {}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************

function init() {}
function player_init() {}
function on_player_spawned() {}
function on_player_disconnect() {}
function on_player_death() {}
function commit_spawn_data()  {}// self == player
function commit_weapon_data( spawnid, currentWeapon, time0 ) {} // self == player
function add_to_stat( statName, delta ) {}
function recordBBDataForPlayer(breadcrumb_Table)  {}//self == player
function recordBlackBoxBreadcrumbData(breadcrumb_Table)  {}
