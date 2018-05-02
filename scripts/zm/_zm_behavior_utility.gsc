#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\zm\_zm_spawner;

#insert scripts\zm\_zm_behavior.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\zombie.gsh; 

#namespace zm_behavior_utility;


/*
///ZmBehaviorUtilityDocBegin
"Name: zombieSetupAttackProperties \n"
"Summary: This is where zombies go into attack mode, and need different attributes set up.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///ZmBehaviorUtilityDocEnd
*/
function setupAttackProperties()
{
	// allows zombie to attack again
	self.ignoreall = false; 

	self.meleeAttackDist = ZM_MELEE_DIST;
}

/*
///ZmBehaviorUtilityDocBegin
"Name: enteredPlayableArea \n"
"Summary: Zombie is no longer behind a barricade.\n"
"MandatoryArg: \n"
"OptionalArg: \n"
"Module: Behavior \n"
///ZmBehaviorUtilityDocEnd
*/
function enteredPlayableArea()
{
	self zm_spawner::zombie_complete_emerging_into_playable_area();

	self.pushable = true;
	self setupAttackProperties();
}

