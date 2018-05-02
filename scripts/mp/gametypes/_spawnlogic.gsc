#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_spawnlogic;
#insert scripts\mp\gametypes\_spawning.gsh;

#namespace spawnlogic;

REGISTER_SYSTEM( "spawnlogic", &__init__, undefined )
	
function __init__() {}
function init() {}
function add_spawn_points_internal( team, spawnpoints, list ) {}
function clear_spawn_points() {}
function add_spawn_points( team, spawnPointName ) {}
function rebuild_spawn_points( team ) {}
function place_spawn_points( spawnPointName ) {}
function drop_spawn_points( spawnPointName ) {}
function add_spawn_point_classname( spawnPointClassName ) {}
function add_spawn_point_team_classname( team, spawnPointClassName ) {}
function _get_spawnpoint_array( spawnpoint_name ) {}
function get_spawnpoint_array( classname ) {}
function spawnpoint_init() {}
function get_team_spawnpoints( team ) {}
function get_spawnpoint_final( spawnpoints, useweights, predictedSpawn, isIntermmissionSpawn = false ) {}
function finalize_spawnpoint_choice( spawnpoint, predictedSpawn ) {}
function get_best_weighted_spawnpoint( spawnpoints ) {}
function get_spawnpoint_random( spawnpoints, predictedSpawn, isIntermissionSpawn = false ) {}
function get_all_other_players() {}
function get_all_allied_and_enemy_players( obj ) {}
function init_weights(spawnpoints) {}
function get_spawnpoint_near_team( spawnpoints, favoredspawnpoints ) {}
function get_spawnpoint_dm(spawnpoints) {}
function begin() {}
function death_occured(dier, killer) {}
function check_for_similar_deaths(deathInfo) {}
function update_death_info() {}
function is_point_vulnerable(playerorigin) {}
function avoid_weapon_damage(spawnpoints) {}
function spawn_per_frame_update() {}
function get_non_team_sum( skip_team, sums ) {}
function get_non_team_min_dist( skip_team, minDists ) {}
function spawnpoint_update( spawnpoint ) {}
function get_los_penalty() {}
function last_minute_sight_traces( spawnpoint ) {}
function avoid_visible_enemies(spawnpoints, teambased) {}
function avoid_spawn_reuse(spawnpoints, teambased) {}
function avoid_same_spawn(spawnpoints) {}
function get_random_intermission_point() {}
function move_spawn_point( targetname, start_point, new_point, new_angles ) {}
