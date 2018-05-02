#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_weap_thundergun.gsh;

#namespace zm_weap_thundergun;
	
REGISTER_SYSTEM_EX( "zm_weap_thundergun", &__init__, &__main__, undefined )

function __init__()
{
	level.weaponZMThunderGun = GetWeapon( "thundergun" );
	level.weaponZMThunderGunUpgraded = GetWeapon( "thundergun_upgraded" );		
}	

function __main__()
{	
	callback::on_localplayer_spawned( &localplayer_spawned );
}


function localplayer_spawned( localClientNum )
{
	self thread watch_for_thunderguns( localClientNum );
}


function watch_for_thunderguns( localclientnum )
{
	self endon( "disconnect" );
	self notify( "watch_for_thunderguns" );
	self endon( "watch_for_thunderguns" );

	while( isdefined(self) )
	{
		self waittill( "weapon_change", w_new_weapon, w_old_weapon ); 
		if ( w_new_weapon == level.weaponZMThunderGun || w_new_weapon == level.weaponZMThunderGunUpgraded )
		{
			self thread thundergun_fx_power_cell( localclientnum, w_new_weapon );
		}
	}
}


function thundergun_fx_power_cell( localclientnum, w_weapon )
{
	self endon( "disconnect" );
	self endon( "weapon_change" );
	self endon( "entityshutdown" );

	n_old_ammo = -1;
	n_shader_val = 0;	// 0 == 4 lights, 1 == 3 lights, 2 == 2 lights, 3 == 1 light
	const N_LIGHTS = 4;
	
	while ( true )
	{
		wait 0.1;

		if (!isdefined(self))
		{
			return; 
		}
		
		n_ammo = GetWeaponAmmoClip( localclientnum, w_weapon );
		if ( n_old_ammo > 0 && n_old_ammo != n_ammo )
		{
			thundergun_fx_fire( localclientnum );
		}
		n_old_ammo = n_ammo;

		// Ammo Counter indicator
		if ( n_ammo == 0 )
		{
			self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 0, 0, 0 );
		}
		else
		{
			n_shader_val = N_LIGHTS - n_ammo;
			self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 1, n_shader_val, 0 );
		}
	}
}


function thundergun_fx_fire( localclientnum )
{
	playsound(localclientnum,"wpn_thunder_breath", (0,0,0));
}
