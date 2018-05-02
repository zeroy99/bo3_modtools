#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

function init()
{
	if (IS_TRUE(level.legacy_cymbal_monkey))
	{
		level.cymbal_monkey_model = "weapon_zombie_monkey_bomb";
	}
	else
	{
		level.cymbal_monkey_model =  "wpn_t7_zmb_monkey_bomb_world";
	}

	if ( !zm_weapons::is_weapon_included( GetWeapon( "cymbal_monkey" ) ) )
	{
		return;
	}
}

