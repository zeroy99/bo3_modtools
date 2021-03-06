#using scripts\shared\ai\archetype_human;
#using scripts\shared\ai\systems\ai_interface;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#namespace HumanInterface;

function RegisterHumanInterfaceAttributes()
{
	/*
	 * Name: can_be_meleed
	 * Summary: Controls whether other AI will choose to melee the human.
	 * Initial Value: true
	 * Attribute true: Normal behavior, humans will be meleed when close to their enemy.
	 * Attribute false: Forces other AI to shoot the AI instead of melee them at
	 *     close distances.
	 * Example: entity ai::set_behavior_attribute( "can_be_meleed", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"can_be_meleed",
		true,
		array( true, false ) );

	/*
	 * Name: can_melee
	 * Summary: Controls whether the human AI is able to melee their enemies.
	 * Initial Value: true
	 * Attribute true: Normal behavior, will melee when close to their enemy.
	 * Attribute false: Forced to shoot even when they are within melee distance.
	 * Example: entity ai::set_behavior_attribute( "can_melee", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"can_melee",
		true,
		array( true, false ) );
	
		/*
	 * Name: can_initiateaivsaimelee
	 * Summary: Controls whether the human AI are able to initiate synced melee with their enemies.
	 * Initial Value: true
	 * Attribute true: Normal behavior, will do synced melee when appropriate conditions are met.
	 * Attribute false: Will never initiate synced melee even if it is possible.
	 * Example: entity ai::set_behavior_attribute( "can_initiateaivsaimelee", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"can_initiateaivsaimelee",
		true,
		array( true, false ) );

	/*
	 * Name: coverIdleOnly
	 * Summary: Forces humans to only choose the idle behavior when at cover.
	 * Initial Value: false
	 * Attribute true : Forces a human to only idle at cover.
	 * Attribute false : Disables forcing idle.
	 * Example: entity ai::set_behavior_attribute( "coverIdleOnly", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"coverIdleOnly",
		false,
		array( true, false ) );

	/*
	 * Name: cqb
	 * Summary: Controls whether humans will use their close quarter battle
	 *     animation set.  CQB animations are tailored for indoor combat distances.
	 *     NOTE: This is only supported for male human characters.
	 * Initial Value: false
	 * Attribute true : Forces a human to use cqb animations.
	 * Attribute false : Uses the normal animation set.
	 * Example: entity ai::set_behavior_attribute( "cqb", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"cqb",
		false,
		array( true, false ),
		&HumanSoldierServerUtils::cqbAttributeCallback );
	
	/*
	 * Name: forceTacticalWalk
	 * Summary: Controls whether humans will forcefully tactical walk while moving.
	 * Initial Value: false
	 * Attribute true : Forces a human to tactical walk when moving.
	 * Attribute false : Disables forcing tactical walk.
	 * Example: entity ai::set_behavior_attribute( "forceTacticalWalk", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"forceTacticalWalk",
		false,
		array( true, false ),
		&HumanSoldierServerUtils::forceTacticalWalkCallback );
	
	/*
	 * Name: move_mode
	 * Summary: Controls how humans choose to move to their goal position.
	 * Initial Value normal
	 * Attribute normal: Adheres to normal movement and combat.
	 * Attribute rambo: Runs to goal position, allowed to shoot at enemies, but doesn't stop and
	 *     fight enemies.
	 * Example: entity ai::set_behavior_attribute( "move_mode", "rambo" );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"move_mode",
		"normal",
		array( "normal", "rambo" ),
		&HumanSoldierServerUtils::moveModeAttributeCallback );
	
	/*
	 * Name: useAnimationOverride
	 * Summary: Controls whether humans will use their specific animation set
	 *     This set is meant to be used for level specific animation override
	 *     NOTE: This is only supported for male human characters.
	 * 	   NOTE: Talk to Sumeet before using this attribute.
	 * Initial Value: false
	 * Attribute true : Forces a human to use specific animation set.
	 * Attribute false : Uses the normal animation set.
	 * Example: entity ai::set_behavior_attribute( "useAnimationOverride", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"useAnimationOverride",
		false,
		array( true, false ),
		&HumanSoldierServerUtils::UseAnimationOverrideCallback );

	/*
	 * Name: sprint
	 * Summary: Controls whether humans will forcefully sprint while moving,
	 *     this prevents shooting while moving.
	 * Initial Value: false
	 * Attribute true : Forces a human to sprint when moving.
	 * Attribute false : Disables forcing sprint.
	 * Example: entity ai::set_behavior_attribute( "sprint", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"sprint",
		false,
		array( true, false ) );
	
	/*
	 * Name: patrol
	 * Summary: Controls whether humans will use their patrol walking
	 *     animation set.  Patrol walks are meant for non-combat situations.
	 *     NOTE: This is only supported for male human characters.
	 * Initial Value: false
	 * Attribute true : Non combat movement uses patrol walk animations.
	 * Attribute false : Non combat movement uses default animations.
	 * Example: entity ai::set_behavior_attribute( "patrol", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"patrol",
		false,
		array( true, false ) );
	
	/*
	 * Name: disablearrivals
	 * Summary: Controls whether humans will use their arrival transitions while moving 
	 *     NOTE: This is only supported for male human characters.
	 * Initial Value: false
	 * Attribute true : when set to true, AI's will not use arrival transitions.
	 * Attribute false : AI will use arrival transitions.
	 * Example: entity ai::set_behavior_attribute( "disablearrivals", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"disablearrivals",
		false,
		array( true, false ) );
		
	/*
	 * Name: disablesprint
	 * Summary: Controls whether humans will use their sprint locomotion.
	 * Initial Value: false
	 * Attribute true : when set to true, AI's will not use sprint locomotion.
	 * Attribute false : AI will use sprint locomotion when applicable.
	 * Example: entity ai::set_behavior_attribute( "disablesprint", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"disablesprint",
		false,
		array( true, false ) );

	/*
	 * Name: stealth
	 * Summary: Controls whether humans will use stealth behavior or not.
	 * Initial Value: false
	 * Attribute true : Using stealth behavior.
	 * Attribute false : Not using stealth behavior (default).
	 * Example: entity ai::set_behavior_attribute( "stealth", true );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"stealth",
		false,
		array( true, false ) );
	
	/*
	 * Name: vignette_mode
	 * Summary: Overrides the actor's default settings to handle controlled scripted
	 *     situations.  Normal AI in combat should not be placed in a vignette mode.
	 *     Vignette modes change low level attributes on an AI, such as being able
	 *     to push players, ignore avoidance with obstacles, and change steering behaviors.
	 * Initial Value: off
	 * Attribute off : Returns the AI to normal settings.
	 * Attribute slow : Configures the actor to handle slow paced vignettes prioritizing
	 *     smooth movement while attempting to avoid other obstacles.
	 * Attribute fast : Configures the actor to handle fast paced vignettes prioritizing
	 *      movement, with expectations that other AI will attempt to avoid them.
	 * Example: entity ai::set_behavior_attribute( "vignette", "slow" );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"vignette_mode",
		"off",
		array( "off", "slow", "fast" ),
		&HumanSoldierServerUtils::VignetteModeCallback );
	
		
	/*
	 * Name: useGrenades
	 * Summary: Controls whether humans will use their a grenades.
	 *     NOTE: This is only supported for human archetypes.
	 * Initial Value: true
	 * Attribute true : when set to true, AI's will throw grenades at enemies.
	 * Attribute false : AI will not throw grendades at enemies.
	 * Example: entity ai::set_behavior_attribute( "useGrenades", false );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_HUMAN,
		"useGrenades",
		true,
		array( true, false ) );
}