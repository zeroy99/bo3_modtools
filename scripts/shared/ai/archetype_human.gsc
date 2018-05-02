#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\util_shared;

// COMMON AI SYSTEMS INCLUDES
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_mocomps_utility;

// BLACKBOARD
#using scripts\shared\ai\archetype_human_blackboard;

// NOTETRACKS
#using scripts\shared\ai\archetype_notetracks;

// BEHAVIORS
#using scripts\shared\ai\archetype_human_exposed;
#using scripts\shared\ai\archetype_human_cover;
#using scripts\shared\ai\archetype_human_locomotion;

// INTERFACE
#using scripts\shared\ai\archetype_human_interface;

#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

