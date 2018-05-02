#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

//AI VS AI MELEE BEHAVIOR
#using scripts\shared\ai\archetype_aivsaimelee;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;


#namespace AiUtility;

function AddAIOverrideDamageCallback( entity, callback, addToFront ) {}
