#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace weapons_shared;
	
REGISTER_SYSTEM( "weapon_shared", &__init__, undefined )

#precache( "client_fx", "weapon/fx_hero_bow_lnchr_glow" );

function __init__()
{
}

