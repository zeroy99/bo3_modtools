#using scripts\shared\ai\zombie;
#using scripts\shared\ai\systems\ai_interface;

#namespace MannequinInterface;

function RegisterMannequinInterfaceAttributes()
{
	/*
	 * Name: can_juke
	 * Summary: Controls whether the zombie can juke.
	 * Initial Value: true
	 * Attribute true: Normal behavior, zombie will occasionally juke left or right.
	 * Attribute false: Disables zombie's ability to juke.
	 * Example: entity ai::set_behavior_attribute( "can_juke", true );"
	 */
	ai::RegisterMatchedInterface(
		"mannequin",
		"can_juke",
		false,
		array( true, false ) );
	
	/*
	 * Name: suicidal_behavior
	 * Summary: Controls whether the zombie is going to act as suicidal.
	 * Initial Value: false
	 * Attribute true: Will enable the suicidal behavior.
	 * Attribute false: Disables suicidal behavior.
	 * Example: entity ai::set_behavior_attribute( "suicidal_behavior", true );"
	 */
	ai::RegisterMatchedInterface(
		"mannequin",
		"suicidal_behavior",
		false,
		array( true, false ) );
	
	/*
	 * Name: spark_behavior
	 * Summary: Controls whether the zombie is going to act as spark zombie.
	 * Initial Value: false
	 * Attribute true: Will enable the spark behavior.
	 * Attribute false: Disables spark behavior.
	 * Example: entity ai::set_behavior_attribute( "spark_behavior", true );"
	 */
	ai::RegisterMatchedInterface(
		"mannequin",
		"spark_behavior",
		false,
		array( true, false ) );
}
