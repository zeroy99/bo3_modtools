#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_lightning_chain;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_weap_tesla.gsh;


#precache( "client_fx", "zombie/fx_tesla_rail_view_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view2_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view3_zmb" );

#precache( "client_fx", "zombie/fx_tesla_rail_view_ug_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view_ug_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view2_ug_zmb" );
#precache( "client_fx", "zombie/fx_tesla_tube_view3_ug_zmb" );

function init()
{
	level.weaponZMTeslaGun = GetWeapon( "tesla_gun" );
	level.weaponZMTeslaGunUpgraded = GetWeapon( "tesla_gun_upgraded" );
	if ( !zm_weapons::is_weapon_included( level.weaponZMTeslaGun ) && !(isdefined( level.uses_tesla_powerup ) && level.uses_tesla_powerup) )
	{
		return;
	}

	level._effect["tesla_viewmodel_rail"]	= "zombie/fx_tesla_rail_view_zmb";
	level._effect["tesla_viewmodel_tube"]	= "zombie/fx_tesla_tube_view_zmb";
	level._effect["tesla_viewmodel_tube2"]	= "zombie/fx_tesla_tube_view2_zmb";
	level._effect["tesla_viewmodel_tube3"]	= "zombie/fx_tesla_tube_view3_zmb";
	
	level._effect["tesla_viewmodel_rail_upgraded"]	= "zombie/fx_tesla_rail_view_ug_zmb";
	level._effect["tesla_viewmodel_tube_upgraded"]	= "zombie/fx_tesla_tube_view_ug_zmb";
	level._effect["tesla_viewmodel_tube2_upgraded"]	= "zombie/fx_tesla_tube_view2_ug_zmb";
	level._effect["tesla_viewmodel_tube3_upgraded"]	= "zombie/fx_tesla_tube_view3_ug_zmb";
	
	level thread player_init();
	level thread tesla_notetrack_think();
}

function player_init()
{
	util::waitforclient( 0 );
	level.tesla_play_fx = [];
	level.tesla_play_rail = true;
	
	players = GetLocalPlayers();
	for( i = 0; i < players.size; i++ )
	{
		level.tesla_play_fx[i] = false;
		players[i] thread tesla_fx_rail( i );
		players[i] thread tesla_fx_tube( i );
		players[i] thread tesla_happy( i );
		players[i] thread tesla_change_watcher( i );
	}
}

function tesla_fx_rail( localclientnum )
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	
	for( ;; )
	{
		waitrealtime( RandomFloatRange( 8, 12 ) );
		
		if ( !level.tesla_play_fx[localclientnum] )
		{
			continue;
		}
		if ( !level.tesla_play_rail )
		{			
			continue;
		}

		currentweapon = GetCurrentWeapon( localclientnum ); 
		if ( currentweapon != level.weaponZMTeslaGun && currentweapon != level.weaponZMTeslaGunUpgraded )
		{
			continue;
		}

		if ( IsADS( localclientnum ) || IsThrowingGrenade( localclientnum ) || IsMeleeing( localclientnum ) || IsOnTurret( localclientnum ) )
		{
			continue;
		}
		
		if ( GetWeaponAmmoClip( localclientnum, currentweapon ) <= 0 )
		{
			continue;
		}
		
		fx = level._effect["tesla_viewmodel_rail"];
		
		if ( currentweapon == level.weaponZMTeslaGunUpgraded )
		{
			fx = level._effect["tesla_viewmodel_rail_upgraded"];
		}
		
		PlayViewmodelFx( localclientnum, fx, "tag_flash" );
		playsound(localclientnum,"wpn_tesla_effects", (0,0,0));
	}
}

function tesla_fx_tube( localclientnum )//self = player
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );
		
	for( ;; )
	{
		waitrealtime( 0.1 );
		
		if ( !level.tesla_play_fx[localclientnum] )
		{
			continue;
		}

		w_current = GetCurrentWeapon( localclientnum ); 
		if ( w_current != level.weaponZMTeslaGun && w_current != level.weaponZMTeslaGunUpgraded )
		{
			continue;
		}

		if ( IsThrowingGrenade( localclientnum ) || IsMeleeing( localclientnum )  || IsOnTurret( localclientnum ) )
		{
			continue;
		}
		
		n_ammo = GetWeaponAmmoClip( localclientnum, w_current );
				
		if ( n_ammo <= 0 )
		{
			self clear_tesla_tube_effect( localclientnum );
			continue;
		}
		
		str_fx = level._effect["tesla_viewmodel_tube"];
		
		if ( w_current == level.weaponZMTeslaGunUpgraded )
		{
			switch( n_ammo )
			{
				case 1:
				case 2:
					str_fx = level._effect["tesla_viewmodel_tube3_upgraded"];
					n_tint = N_BULB_TINT_TWO_OFF;
					break;
					
				case 3:
				case 4:
					str_fx = level._effect["tesla_viewmodel_tube2_upgraded"];
					n_tint = N_BULB_TINT_ONE_OFF;
					break;
					
				default:
					str_fx = level._effect["tesla_viewmodel_tube_upgraded"];
					n_tint = N_BULB_TINT_ALL_ON;
					break;
			}
		}
		else // regular tesla gun
		{
			switch( n_ammo )
			{
				case 1:
					str_fx = level._effect["tesla_viewmodel_tube3"];
					n_tint = N_BULB_TINT_TWO_OFF;
					break;
					
				case 2:
					str_fx = level._effect["tesla_viewmodel_tube2"];
					n_tint = N_BULB_TINT_ONE_OFF;
					break;
					
				default:
					str_fx = level._effect["tesla_viewmodel_tube"];
					n_tint = N_BULB_TINT_ALL_ON;
					break;
			}
		}
		
		if( self.str_tesla_current_tube_effect === str_fx )
		{
			continue;	
		}
		else
		{
			if( isdefined( self.n_tesla_tube_fx_id ) )
			{
				DeleteFx( localClientNum, self.n_tesla_tube_fx_id, true );
			}
			self.str_tesla_current_tube_effect = str_fx;
			self.n_tesla_tube_fx_id = PlayViewmodelFx( localclientnum, str_fx, "tag_brass" );
			self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 1, n_tint, 0 );
		}
	}
}

function tesla_notetrack_think()
{
	for ( ;; )
	{
		level waittill( "notetrack", localclientnum, note );
		
		//println( "@@@ Got notetrack: " + note + " for client: " + localclientnum );
		
		switch( note )
		{
		case "tesla_play_fx_off":
			level.tesla_play_fx[localclientnum] = false;			
		break;	
			
		case "tesla_play_fx_on":
			level.tesla_play_fx[localclientnum] = true;			
		break;			
		
		}
	}
}

function tesla_happy( localclientnum )
{
	for(;;)
	{
		level waittill ("TGH");
		currentweapon = GetCurrentWeapon( localclientnum ); 
		if ( currentweapon == level.weaponZMTeslaGun || currentweapon == level.weaponZMTeslaGunUpgraded )
		{
			playsound(localclientnum,"wpn_tesla_happy", (0,0,0));
			level.tesla_play_rail = false;
			waitrealtime(2);
			level.tesla_play_rail = true;
		}
		
	}
}

//kill looping effect if player switches from tesla
function tesla_change_watcher( localclientnum )//self = player
{
	self endon( "disconnect" );
	
	while( true )
	{
		self waittill( "weapon_change" );

		self clear_tesla_tube_effect( localclientnum );
	}
}

function clear_tesla_tube_effect( localclientnum )//self = player
{
	if( isdefined( self.n_tesla_tube_fx_id ) )
	{
		DeleteFx( localClientNum, self.n_tesla_tube_fx_id, true );
		self.n_tesla_tube_fx_id = undefined;
		self.str_tesla_current_tube_effect = undefined;
		self MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 1, N_BULB_TINT_ALL_OFF, 0 );
	}	
}
