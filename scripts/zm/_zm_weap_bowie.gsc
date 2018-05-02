#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\shared\system_shared;

#using scripts\zm\_zm_melee_weapon;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_utility.gsh;

REGISTER_SYSTEM_EX( "bowie_knife", &__init__, &__main__, undefined )

function private __init__()
{
}

function private __main__()
{
	if( isdefined( level.bowie_cost ) )
	{
		cost = level.bowie_cost;
	}
	else
	{
		cost = 3000;
	}

	prompt = &"ZOMBIE_WEAPONCOSTONLY_CFILL"; 
	if (!IS_TRUE( level.weapon_cost_client_filled ))
	{
		prompt = &"ZOMBIE_WEAPON_BOWIE_BUY";
	}
	
	zm_melee_weapon::init( "bowie_knife", 
							"bowie_flourish",
							"knife_ballistic_bowie",
							"knife_ballistic_bowie_upgraded",
	                        cost,
							"bowie_upgrade",
							prompt,
							"bowie",
							undefined);
	
	zm_melee_weapon::set_fallback_weapon( "bowie_knife", "zombie_fists_bowie" );

	
	zm_weapons::add_retrievable_knife_init_name( "knife_ballistic_bowie" );
	zm_weapons::add_retrievable_knife_init_name( "knife_ballistic_bowie_upgraded" );
}

function init()
{
}
