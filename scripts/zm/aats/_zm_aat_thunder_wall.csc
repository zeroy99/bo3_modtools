#using scripts\shared\aat_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\aats\_zm_aat_thunder_wall.gsh;

#insert scripts\zm\_zm_utility.gsh;

#namespace zm_aat_thunder_wall;

REGISTER_SYSTEM( ZM_AAT_THUNDER_WALL_NAME, &__init__, undefined )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	aat::register( ZM_AAT_THUNDER_WALL_NAME, ZM_AAT_THUNDER_WALL_LOCALIZED_STRING, ZM_AAT_THUNDER_WALL_ICON );
}


