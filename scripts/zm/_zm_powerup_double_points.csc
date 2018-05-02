#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_powerups;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#namespace zm_powerup_double_points;

REGISTER_SYSTEM( "zm_powerup_double_points", &__init__, undefined )
	
function __init__()
{
	zm_powerups::include_zombie_powerup( "double_points" );
	if( ToLower( GetDvarString( "g_gametype" ) ) != "zcleansed" )
	{
		zm_powerups::add_zombie_powerup( "double_points", CLIENTFIELD_POWERUP_DOUBLE_POINTS );
	}
}
