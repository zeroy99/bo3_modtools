/*
 * AI VS AI MELEE SYSTEM
 * The AI vs AI Melee system is initiated from the behavior tree.
 * A set of conditions are used to check if an AI can initiate a scripted melee attack against its enemy.
 * If these pass, the AI designates itself as the initiator of the setup. The initiator then picks the two animations, and sets AnimScripted on both itself and its enemy from the AIvsAIMeleeAction
 * Threads are spawned on the entities to handle death during the sequence since it is outside the tree. The loser is killed and the survivor kicks back into the behavior tree.
TODO: 
- Rethink the initiator system to see if melee can be triggered without it
- Add support for few more animations, including close range melee without runup
- Add more archetypes
 */
 
#using scripts\codescripts\struct;

// COMMON AI SYSTEMS INCLUDES
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\archetype_utility;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\aivsaimelee.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
