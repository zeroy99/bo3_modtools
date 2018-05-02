#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;

#precache( "client_fx", "killstreaks/fx_hrpy_single_light_red" );

#using_animtree( "mp_missile_drone" );

#namespace missile_drone;

REGISTER_SYSTEM( "missile_drone", &__init__, undefined )
	
function __init__()
{
	level._effect["missile_drone_enemy_light"] = "killstreaks/fx_hrpy_single_light_red";
	level._effect["missile_drone_friendly_light"] = "killstreaks/fx_hrpy_single_light_red";
	clientfield::register( "toplayer", "missile_drone_active", VERSION_SHIP, 2, "int",&missile_drone_active_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	clientfield::register( "missile", "missile_drone_projectile_active", VERSION_SHIP, 1, "int",&missile_drone_projectile_active_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	clientfield::register( "missile", "missile_drone_projectile_animate", VERSION_SHIP, 1, "int",&missile_drone_projectile_animate_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

function missile_drone_projectile_animate_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "entityshutdown" );
	self endon( "death" );
	wait( 0.1 );
	self util::waittill_dobj(localClientNum);
	self UseAnimTree( #animtree );
	self SetAnim( %o_drone_hunter_launch, 1.0, 0.0, 1.0 );
}

function missile_drone_projectile_active_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == 1 ) 
	{
	//	iprintlnbold( "ON" );
		self thread fx::blinky_light( localClientNum, "tag_target", level._effect["missile_drone_friendly_light"], level._effect["missile_drone_enemy_light"] );
	}
	else
	{
	//	iprintlnbold( "OFF" );
		self thread fx::stop_blinky_light( localClientNum );
	}
}

function missile_drone_active_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == 2 )
	{
		//iprintlnbold( "ENABLED" );
		self targetAcquired( localClientNum );
	}
	else if( newVal == 1 )
	{
		//iprintlnbold( "ON" );
		self targetScan( localClientNum );
	}
	else
	{
		//iprintlnbold( "OFF" );
		self targetLost( localClientNum );
	}
}

function targetLost( localClientNum ) 
{
	self notify( "targetLost" );
	
	//iprintlnbold( "target Lost" );
	
	if ( isdefined ( self.missile_drone_fx ) ) 
	{
		stopFX( localClientNum, self.missile_drone_fx );
	}
	// stop viewModelFX
	
}
function targetAcquired( localClientNum )
{
	self endon( "disconnect" );
	self endon( "targetLost" );
	self endon( "targetScanning" );
	self endon( "entityshutdown" );
	self notify( "targetAcquired" );
	
	soundPlayed = false;
	for( ;; )
	{
		currentweapon = GetCurrentWeapon( localclientnum ); 

		if ( currentweapon.name != "missile_drone" && currentweapon.name != "inventory_missile_drone" )
		{
			waitrealtime( 1 );
			continue;
		}
		
		if ( IsADS( localclientnum ) || IsThrowingGrenade( localclientnum ) || IsMeleeing( localclientnum ) || IsOnTurret( localclientnum ) )
		{
			waitrealtime( 1 );
			continue;
		}
		
		if ( GetWeaponAmmoClip( localclientnum, currentweapon ) <= 0 )
		{
			waitrealtime( 1 );
			continue;
		}
		
		self.missile_drone_fx = PlayViewmodelFX( localClientNum, level._effect["missile_drone_enemy_light"], "tag_target" );

		if ( !soundPlayed )
		{
			playsound( localClientNum, "fly_hunter_raise_plr", self.origin );
		}
		soundPlayed = true;
		
		waitrealtime( .5 );
	}
}

function targetScan( localClientNum )
{
	self endon( "disconnect" );
	self endon( "targetLost" );
	self endon( "targetAcquired" );
	self notify( "targetScanning" );
	
	soundPlayed = false;
	for( ;; )
	{
		currentweapon = GetCurrentWeapon( localclientnum ); 

		if ( currentweapon.name != "missile_drone" && currentweapon.name != "inventory_missile_drone" )
		{
			waitrealtime( 1 );
			continue;
		}

//		if ( !soundPlayed )
//		{
//			playsound( localClientNum, "mpl_hk_scan", self.origin );
//		}
		soundPlayed = true;
		
		waitrealtime( 1 );
	}
}