#using scripts\shared\util_shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\archetype_apothicon_fury;

//INTERFACE
#using scripts\shared\ai\systems\ai_interface;

#insert scripts\shared\ai\archetype_apothicon_fury.gsh; 
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#namespace ApothiconFuryInterface;

function RegisterApothiconFuryInterfaceAttributes()
{
	/*
	 * Name: can_juke
	 * Summary: Controls whether the apothicon can juke.
	 * Initial Value: true
	 * Attribute true: Normal behavior, apothicon will occasionally juke left or right.
	 * Attribute false: Disables apothicon's ability to juke.
	 * Example: entity ai::set_behavior_attribute( "can_juke", true );"
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_APOTHICON_FURY,
		"can_juke",
		true,
		array( true, false ) );		
	
	/*
	 * Name: can_bamf
	 * Summary: Controls whether the apothicon can bamf.
	 * Initial Value: true
	 * Attribute true: Normal behavior, apothicon will occasionally bamf left or right.
	 * Attribute false: Disables apothicon's ability to bamf.
	 * Example: entity ai::set_behavior_attribute( "can_bamf", true );"
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_APOTHICON_FURY,
		"can_bamf",
		true,
		array( true, false ) );
	
	/*
	 * Name: can_be_furious
	 * Summary: Controls whether the apothicon can switch to furious mode.
	 * Initial Value: true
	 * Attribute true: Normal behavior, apothicon will occasionally switch to furious mode.
	 * Attribute false: Disables apothicon's ability to switch to furious mode.
	 * Example: entity ai::set_behavior_attribute( "can_be_furious", true );"
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_APOTHICON_FURY,
		"can_be_furious",
		true,
		array( true, false ) );

	/*
	 * Name: move_speed
	 * Summary: Controls the speed of the movement
	 * Initial Value walk
	 * Example: entity ai::set_behavior_attribute( "move_speed", "walk" );
	 */
	ai::RegisterMatchedInterface(
		ARCHETYPE_APOTHICON_FURY,
		"move_speed",
		"walk",
		array( "walk", "run", "sprint", "super_sprint" ),
		&ApothiconFuryBehaviorInterface::moveSpeedAttributeCallback );
}