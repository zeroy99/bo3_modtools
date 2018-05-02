#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\zombie.gsh;

#namespace player;

#define PLAYER_RADIUS				15
#define PLAYER_HALF_HEIGHT			16
#define PLAYER_POS_SEARCH_RADIUS	100
#define LARGE_SEARCH_RADIUS			2048

REGISTER_SYSTEM( "player", &__init__, undefined )

function __init__()
{
	callback::on_spawned( &on_player_spawned );
	
	clientfield::register( "world", "gameplay_started", VERSION_TU4, 1, "int" );
}

function on_player_spawned()
{
	// No need of this callback in frontend
	mapname = GetDvarString( "mapname" );
	
	if( mapname === "core_frontend" )
	{
		return;
	}
	
	if( SessionModeIsZombiesGame() || SessionModeIsCampaignGame() )
	{	
		snappedOrigin = self get_snapped_spot_origin( self.origin );
		
		if( !(self flagsys::get( "shared_igc" )) )
		{
			self SetOrigin( snappedOrigin );
		}
	}

	isMultiplayer = !SessionModeIsZombiesGame() && !SessionModeIsCampaignGame();

	if ( !isMultiplayer || IS_TRUE( level._enableLastValidPosition ) )
	{
		self thread last_valid_position();
	}
}

// cached navmesh position for player
function last_valid_position()
{
	self endon( "disconnect" );

	self notify( "stop_last_valid_position" );
	self endon( "stop_last_valid_position" );

	// try to at least get a valid position
	while ( !isdefined( self.last_valid_position ) )
	{
		self.last_valid_position = GetClosestPointOnNavMesh( self.origin, LARGE_SEARCH_RADIUS, 0 );
		wait 0.1;
	}

	while ( 1 )
	{
		// if haven't moved very far, don't bother
		if ( Distance2DSquared( self.origin, self.last_valid_position ) < SQR( PLAYER_RADIUS ) && 
			SQR( self.origin[2] - self.last_valid_position[2] ) < SQR( PLAYER_HALF_HEIGHT ) )
		{
			wait 0.1;
			continue;
		}

		// position is already good
		if ( IsDefined( level.last_valid_position_override ) && self [[ level.last_valid_position_override ]]() )
		{
			wait 0.1;
			continue;
		}
		else if ( IsPointOnNavMesh( self.origin, self ) )
		{
			self.last_valid_position = self.origin;
		}
		else if( !IsPointOnNavmesh( self.origin, self ) 
		        && IsPointOnNavMesh( self.last_valid_position, self ) 
		        && ( Distance2DSquared( self.origin, self.last_valid_position ) < SQR( ZM_MELEE_DIST / 2 ) )
		       )
		{
			// dont update the self.last_valid_position
			wait 0.1;
			continue;
		}
		else 
		{
			position = GetClosestPointOnNavMesh( self.origin, PLAYER_POS_SEARCH_RADIUS, PLAYER_RADIUS );
			if ( isdefined( position ) )
			{
				self.last_valid_position = position;
			}
		}

		wait( 0.1 );
	}
}

function take_weapons()
{
	if ( !IS_TRUE( self.gun_removed ) )
	{
		self.gun_removed = true;
		
		self._weapons = [];
		
		// Update current weapon only if a valid weapon is returned from code.
		// If the player is in the proccess of switching weapons, it will be "none"
		// and we don't want to save that as the player's weapon.
		
		DEFAULT( self._current_weapon, level.weaponNone );
		
		w_current = self GetCurrentWeapon();
		if ( w_current != level.weaponNone )
		{
			self._current_weapon = w_current;
		}
		
		a_weapon_list = self GetWeaponsList();
		
		// If we still don't have a valid weapon saved off for current weapon, use the first weapon
		// in the player's weapon list
		
		if ( self._current_weapon == level.weaponNone )
		{
			if ( isdefined( a_weapon_list[ 0 ] ) )
			{
				self._current_weapon = a_weapon_list[ 0 ];
			}
		}
		
		foreach ( weapon in a_weapon_list )
		{
			if(IS_TRUE(weapon.dniweapon))	//DT#93790 
				continue;
			
			
			ARRAY_ADD( self._weapons, get_weapondata( weapon ) );
			
			self TakeWeapon( weapon );
		}
	}
}

function generate_weapon_data()
{
	self._generated_weapons = [];
		
	DEFAULT( self._generated_current_weapon, level.weaponNone );
		
	if( IS_TRUE( self.gun_removed ) && IsDefined( self._weapons ) )
	{
		self._generated_weapons = ArrayCopy( self._weapons );
		self._generated_current_weapon = self._current_weapon;
	}
	else
	{
		w_current = self GetCurrentWeapon();
		if ( w_current != level.weaponNone )
		{
			self._generated_current_weapon = w_current;
		}
		
		a_weapon_list = self GetWeaponsList();
		
		// If we still don't have a valid weapon saved off for current weapon, use the first weapon
		// in the player's weapon list
		
		if ( self._generated_current_weapon == level.weaponNone )
		{
			if ( isdefined( a_weapon_list[ 0 ] ) )
			{
				self._generated_current_weapon = a_weapon_list[ 0 ];
			}
		}
		
		foreach ( weapon in a_weapon_list )
		{
			if(IS_TRUE(weapon.dniweapon))	//DT#93790 
				continue;
			
			
			ARRAY_ADD( self._generated_weapons, get_weapondata( weapon ) );
		}
	}
}

function give_back_weapons( b_immediate = false )
{
	if ( isdefined( self._weapons ) )
	{
		foreach ( weapondata in self._weapons )
		{
			weapondata_give( weapondata );
		}
		
		if ( isdefined( self._current_weapon ) && ( self._current_weapon != level.weaponNone ) )
		{
			if ( b_immediate )
			{
				self SwitchToWeaponImmediate( self._current_weapon );
			}
			else
			{
				self SwitchToWeapon( self._current_weapon );
			}
		}
		else if ( isdefined( self.primaryloadoutweapon ) && self HasWeapon( self.primaryloadoutweapon ) ) //If current weapon is not set, let's try to switch to primary
		{
			switch_to_primary_weapon( b_immediate );
		}
	}
	
	self._weapons = undefined;
	self.gun_removed = undefined;
}

function get_weapondata( weapon )
{
	weapondata = [];

	if ( !isdefined( weapon ) )
	{
		weapon = self GetCurrentWeapon();
	}

	weapondata[ "weapon" ] = weapon.name;

	if ( weapon != level.weaponNone )
	{
		weapondata[ "clip" ] = self GetWeaponAmmoClip( weapon );
		weapondata[ "stock" ] = self GetWeaponAmmoStock( weapon );
		weapondata[ "fuel" ] = self GetWeaponAmmoFuel( weapon );
		weapondata[ "heat" ] = self IsWeaponOverheating( 1, weapon );
		weapondata[ "overheat" ] = self IsWeaponOverheating( 0, weapon );
		weapondata[ "renderOptions" ] = self GetWeaponOptions( weapon );
		weapondata[ "acvi" ] = self GetPlayerAttachmentCosmeticVariantIndexes( weapon );
		
		if ( weapon.isRiotShield )
		{
			weapondata[ "health" ] = self.weaponHealth;
		}
	}
	else
	{
		weapondata[ "clip" ] = 0;
		weapondata[ "stock" ] = 0;
		weapondata[ "fuel" ] = 0;
		weapondata[ "heat" ] = 0;
		weapondata[ "overheat" ] = 0;
	}
	
	if ( weapon.dualWieldWeapon != level.weaponNone )
	{
		weapondata[ "lh_clip" ] = self GetWeaponAmmoClip( weapon.dualWieldWeapon );
	}
	else
	{
		weapondata[ "lh_clip" ] = 0;
	}
	
	if ( weapon.altWeapon != level.weaponNone )
	{
		weapondata[ "alt_clip" ] = self GetWeaponAmmoClip( weapon.altWeapon );
		weapondata[ "alt_stock" ] = self GetWeaponAmmoStock( weapon.altWeapon );
	}
	else
	{
		weapondata[ "alt_clip" ] = 0;
		weapondata[ "alt_stock" ] = 0;
	}
	
	return weapondata;
}

function weapondata_give( weapondata )
{
	weapon = util::get_weapon_by_name( weapondata[ "weapon" ] );

	self GiveWeapon( weapon, weapondata[ "renderOptions" ], weapondata[ "acvi" ] );
	
	if ( weapon != level.weaponNone )
	{
		self SetWeaponAmmoClip( weapon, weapondata[ "clip" ] );
		self SetWeaponAmmoStock( weapon, weapondata[ "stock" ] );
		
		if ( IsDefined( weapondata[ "fuel" ] ) )
		{
			self SetWeaponAmmoFuel( weapon, weapondata[ "fuel" ] );
		}
		
		if ( IsDefined( weapondata[ "heat" ] ) && IsDefined( weapondata[ "overheat" ] ) )
		{
			self SetWeaponOverheating( weapondata[ "overheat" ], weapondata[ "heat" ], weapon );
		}
		
		if ( weapon.isRiotShield && IsDefined( weapondata[ "health" ] ) )
		{
			self.weaponHealth = weapondata[ "health" ];
		}
	}
	
	if ( weapon.dualWieldWeapon != level.weaponNone )
	{
		self SetWeaponAmmoClip( weapon.dualWieldWeapon, weapondata[ "lh_clip" ] );
	}
	
	if ( weapon.altWeapon != level.weaponNone )
	{
		self SetWeaponAmmoClip( weapon.altWeapon, weapondata[ "alt_clip" ] );
		self SetWeaponAmmoStock( weapon.altWeapon, weapondata[ "alt_stock" ] );
	}
}

function switch_to_primary_weapon( b_immediate = false )
{
	if ( is_valid_weapon( self.primaryloadoutweapon ) )
	{
		if ( b_immediate )
		{
			self SwitchToWeaponImmediate( self.primaryloadoutweapon );
		}
		else
		{
			self SwitchToWeapon( self.primaryloadoutweapon );
		}
	}
}

function fill_current_clip() //self = player
{
	w_current = self GetCurrentWeapon();
	if ( w_current.isheroweapon ) //We don't want to give the player more hero ammo
	{
		w_current = self.primaryloadoutweapon; //Let's give them primary weapon ammo instead
	}
	
	if ( isdefined( w_current ) && self HasWeapon( w_current ) ) // with "copycat" ability, the player might not have their primary loadout weapon
	{	
		self SetWeaponAmmoClip( w_current, w_current.clipsize );
	}
}

function is_valid_weapon( weaponObject )
{
	return ( isdefined( weaponObject ) && ( weaponObject != level.weaponNone ) );
}

function is_spawn_protected()
{	
	return ( GetTime() - VAL( self.spawntime, 0 ) <= level.spawnProtectionTimeMS );
}

/@
"Name: simple_respawn()"
"Summary: Respawn a player at whatever the current best spawn point is using the gamemodes base spawn function.  Most of the spawn logic is not included and this is mostly just a teleport using the spawn logic.  The player entity is untouched, and no spawn callbacks are called."
"CallOn: player"
"Example: e_player player::simple_respawn();"
@/
function simple_respawn()
{
	self [[ level.onSpawnPlayer ]]( false );
}

function get_snapped_spot_origin( spot_position )
{
	snap_max_height = 100;
	size = 15;
	height = size * 2;
	mins = (-1 * size, -1 * size, 0 );
	maxs = ( size, size, height );
	
	spot_position = (spot_position[0], spot_position[1], spot_position[2] + 5);
	new_spot_position = ( spot_position[0], spot_position[1], spot_position[2] - snap_max_height);
	
	trace = physicstrace( spot_position, new_spot_position, mins, maxs, self);

	if ( trace["fraction"] < 1 )
	{
		return trace["position"];
	}
	
	return spot_position;
}

function allow_stance_change( b_allow = true )
{
	if ( b_allow )
	{
		self AllowProne( true );
		self AllowCrouch( true );
		self AllowStand( true );
	}
	else
	{
		str_stance = self GetStance();
		
		switch ( str_stance )
		{
			case "prone":
				
				self AllowProne( true );
				self AllowCrouch( false );
				self AllowStand( false );
				
				break;
				
			case "crouch":
				
				self AllowProne( false );
				self AllowCrouch( true );
				self AllowStand( false );
				
				break;
				
			case "stand":
				
				self AllowProne( false );
				self AllowCrouch( false );
				self AllowStand( true );
				
				break;
		}
	}
}
