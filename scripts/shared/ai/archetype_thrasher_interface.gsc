#using scripts\shared\ai\archetype_thrasher;
#using scripts\shared\ai\systems\ai_interface;

#namespace ThrasherInterface;

function RegisterThrasherInterfaceAttributes()
{
	/*
	 * Name: stunned
	 * Summary: Controls whether the thrasher AI is stunned.
	 * Initial Value: false
	 * Attribute true: Thrasher is stunned.
	 * Attribute false: Normal thrasher behaviors.
	 * Example: entity ai::set_behavior_attribute( "thrasher", true );"
	 */
	ai::RegisterMatchedInterface(
		"thrasher",
		"stunned",
		false,
		array( true, false ) );
		
	ai::RegisterMatchedInterface(
		"thrasher",
		"move_mode",
		"normal",
		array( "normal", "friendly" ),
		&ThrasherServerUtils::thrasherMoveModeAttributeCallback );

	/*
	 * Name: use_attackable
	 * Summary: Controls whether the thrasher destroys attackable objects.
	 * Initial Value: false
	 * Attribute true: Will enable the attackable behavior.
	 * Attribute false: Disables attackable behavior.
	 * Example: entity ai::set_behavior_attribute( "use_attackable", true );"
	 */
	ai::RegisterMatchedInterface(
		"thrasher",
		"use_attackable",
		false,
		array( true, false ) );
}