#using scripts\shared\ai\behavior_zombie_dog;
#using scripts\shared\ai\systems\ai_interface;

#namespace ZombieDogInterface;

function RegisterZombieDogInterfaceAttributes()
{
	/*
	 * Name: gravity
	 * Summary: Enables or disables low gravity animations for the zombie dog.
	 * Initial Value: normal
	 * Attribute normal: Normal animations.
	 * Attribute low: Low gravity animations.
	 * Example: entity ai::set_behavior_attribute( "gravity", "low" );
	 */
	ai::RegisterMatchedInterface(
		"zombie_dog",
		"gravity",
		"normal",
		array( "low", "normal" ),
		&ZombieDogBehavior::zombieDogGravity );


	/*
	 * Name: min_run_dist
	 * Summary: The minimum distance at which a zombie dog will decide to start running towards its target.
	 * Initial Value: 500
	 * Example: entity ai::set_behavior_attribute( "min_run_dist", 500 );
	 */
	ai::RegisterMatchedInterface(
		"zombie_dog",
		"min_run_dist",
		500 );


	/*
	 * Name: sprint
	 * Summary: If this is set to true, the zombie dog will sprint towards its target even without LOS.
	 * Initial Value: false
	 * Example: entity ai::set_behavior_attribute( "sprint", true );
	 */
	ai::RegisterMatchedInterface(
		"zombie_dog",
		"sprint",
		false,
		array( true, false ) );
}
