#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#using scripts\shared\array_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\ai\zombie_shared;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\systems\gib;

#using scripts\shared\ai\systems\behavior_tree_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\zombie.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;

#using scripts\codescripts\struct;

#namespace zombie_utility;
	
function gib_random_parts() {}
function set_zombie_var( zvar, value, is_float = false, column = 1, is_team_based = false ) {}
function get_current_zombie_count() {}
function reset_attack_spot() {}
function zombie_head_gib( attacker, means_of_death ) {}
function get_round_enemy_array() {}
