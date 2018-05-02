#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\dev_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapon_utils;

#insert scripts\shared\shared.gsh;

#precache( "string", "MP_CANNOT_LOCKON_TO_TARGET" );

#precache( "fx", "killstreaks/fx_heli_chaff" );

#define MISSED_BY_FAR_DISTANCE		500
#define FLARE_DISTANCE				3500
	
#namespace heatseekingmissile;

function init_shared()
{
	game["locking_on_sound"] = "uin_alert_lockon_start";
	game["locked_on_sound"] = "uin_alert_lockon";
	
	callback::on_spawned( &on_player_spawned );

	level.fx_flare = "killstreaks/fx_heli_chaff";

	//Dvar is used with the dev gui so as to let the player target friendly vehicles with heat-seekers.
	/#
		SetDvar("scr_freelock", "0");
	#/
}

function on_player_spawned()
{
	self endon( "disconnect" );

	self ClearIRTarget();
	thread StingerToggleLoop();
	//thread TraceConstantTest();
	self thread StingerFiredNotify();
}

function ClearIRTarget()
{
	self notify( "stop_lockon_sound" );
	self notify( "stop_locked_sound" );
	self.stingerlocksound = undefined;
	self StopRumble( "stinger_lock_rumble" );

	self.stingerLockStartTime = 0;
	self.stingerLockStarted = false;
	self.stingerLockFinalized = false;
	self.stingerLockDetected = false;
	if( isdefined(self.stingerTarget) )
	{
		self.stingerTarget notify( "missile_unlocked" );
		self LockingOn(self.stingerTarget, false);
		self LockedOn(self.stingerTarget, false);
	}
	self.stingerTarget = undefined;

	self WeaponLockFree();
	self WeaponLockTargetTooClose( false );
	self WeaponLockNoClearance( false );

	self StopLocalSound( game["locking_on_sound"] );
	self StopLocalSound( game["locked_on_sound"] );

	self DestroyLockOnCanceledMessage();
}


function StingerFiredNotify()
{
	self endon( "disconnect" );
	self endon ( "death" );

	while ( true )
	{
		self waittill( "missile_fire", missile, weapon );

		/# thread debug_missile( missile ); #/

		if ( weapon.lockonType == "Legacy Single" )
		{
			if( isdefined(self.stingerTarget) && self.stingerLockFinalized )
			{
				self.stingerTarget notify( "stinger_fired_at_me", missile, weapon, self );
			}
		}
	}
}

/#
function debug_missile( missile )
{
	level notify( "debug_missile" );
	level endon( "debug_missile" );
	
	level.debug_missile_dots = [];
	
	while( 1 )
	{
		if ( GetDvarInt( "scr_debug_missile", 0 ) == 0 )
		{
			wait 0.5;
			continue;
		}

		if ( isdefined( missile ) )
		{
			missile_info = SpawnStruct();
			missile_info.origin = missile.origin;
			target = missile Missile_GetTarget();
			missile_info.targetEntNum = ( isdefined( target ) ? target GetEntityNumber() : undefined );
			ARRAY_ADD( level.debug_missile_dots, missile_info );
		}
		
		foreach( missile_info in level.debug_missile_dots )
		{
			dot_color = ( isdefined( missile_info.targetEntNum ) ? RED : GREEN );
			util::debug_sphere( missile_info.origin, 10, dot_color, 0.66, 1 );
		}
		
		WAIT_SERVER_FRAME;
	}
}
#/

function StingerWaitForAds()
{
	while( !self PlayerStingerAds() )
	{
		WAIT_SERVER_FRAME;

		currentWeapon = self GetCurrentWeapon();
		if ( currentWeapon.lockonType != "Legacy Single" )
		{
			return false;
		}
	}
	
	return true;
}

function StingerToggleLoop()
{
	self endon( "disconnect" );
	self endon ( "death" );
	
	for (;;)
	{
		self waittill( "weapon_change", weapon );

		while ( weapon.lockonType == "Legacy Single" )
		{
			if ( self GetWeaponAmmoClip( weapon ) == 0 )
			{
				WAIT_SERVER_FRAME;
				weapon = self GetCurrentWeapon();
				continue;
			}
		
			if ( !StingerWaitForAds() )
			{
				break;
			}

			self thread StingerIRTLoop( weapon );

			while( self PlayerStingerAds() )
			{
				WAIT_SERVER_FRAME;
			}

			self notify( "stinger_IRT_off" );
			self ClearIRTarget();

			weapon = self GetCurrentWeapon();
		}
	}
}

function StingerIRTLoop( weapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "stinger_IRT_off" );

	lockLength = self getLockOnSpeed();

	for (;;)
	{
		WAIT_SERVER_FRAME;

		//-------------------------
		// Four possible states:
		//      No missile in the tube, so CLU will not search for targets.
		//		CLU has a lock.
		//		CLU is locking on to a target.
		//		CLU is searching for a target to begin locking on to.
		//-------------------------

		if ( self.stingerLockFinalized )
		{
			passed = SoftSightTest();
			if ( !passed )
				continue;

			if ( ! self IsStillValidTarget( self.stingerTarget, weapon )  || self InsideStingerReticleLocked( self.stingerTarget, weapon ) == false )
			{
				self SetWeaponLockOnPercent( weapon, 0 );
				self ClearIRTarget();
				continue;
			}

			if ( !self.stingerTarget.locked_on )
			{
				self.stingerTarget notify( "missile_lock", self, self GetCurrentWeapon() );
			}
			
			self LockingOn(self.stingerTarget, false);
			self LockedOn(self.stingerTarget, true);
			if ( isdefined( weapon ) )
			{
				heatseekingmissile::setFriendlyFlags( weapon, self.stingerTarget );
			}

			thread LoopLocalLockSound( game["locked_on_sound"], 0.75 );

			
			//print3D( self.stingerTarget.origin, "* LOCKED!", (.2, 1, .3), 1, 5 );
			continue;
		}

		if ( self.stingerLockStarted )
		{
			if ( !self IsStillValidTarget( self.stingerTarget, weapon ) || self InsideStingerReticleLocked( self.stingerTarget, weapon ) == false )
			{
				self SetWeaponLockOnPercent( weapon, 0 );
				self ClearIRTarget();
				continue;
			}

			//print3D( self.stingerTarget.origin, "* locking...!", (.2, 1, .3), 1, 5 );
			
			self LockingOn(self.stingerTarget, true);
			self LockedOn(self.stingerTarget, false);
			if ( isdefined( weapon ) )
			{
				heatseekingmissile::setFriendlyFlags( weapon, self.stingerTarget );
			}

			passed = SoftSightTest();
			if ( !passed )
				continue;

			timePassed = getTime() - self.stingerLockStartTime;
			
			if ( isdefined( weapon ) )
			{
				self SetWeaponLockOnPercent( weapon, ( ( timePassed / lockLength ) * 100 ) );
				heatseekingmissile::setFriendlyFlags( weapon, self.stingerTarget );
			}
			
			if ( timePassed < lockLength )
				continue;

			assert( isdefined( self.stingerTarget ) );
			self notify( "stop_lockon_sound" );
			self.stingerLockFinalized = true;
			self WeaponLockFinalize( self.stingerTarget );

			continue;
		}
		

		bestTarget = self GetBestStingerTarget( weapon );
		if ( !isdefined( bestTarget ) || ( isdefined( self.stingerTarget ) && self.stingerTarget != bestTarget ) )
		{
			self DestroyLockOnCanceledMessage();
			if ( self.stingerLockDetected == true ) 
			{
				self WeaponLockFree();
				self.stingerLockDetected = false;
			}
			continue;
		}

		if ( !( self LockSightTest( bestTarget ) ) )
		{
			self DestroyLockOnCanceledMessage();
			continue;
		}

		//check for delay allowing helicopters to enter the play area
		if( isdefined( bestTarget.lockOnDelay ) && bestTarget.lockOnDelay )
		{
			self DisplayLockOnCanceledMessage();
			continue;
		}

		if( !TargetWithinRangeOfPlaySpace( bestTarget ) )
		{
			self DisplayLockOnCanceledMessage();
			continue;
		}
		
		self DestroyLockOnCanceledMessage();
		
		if ( self InsideStingerReticleLocked( bestTarget, weapon ) == false )
		{
			if ( self.stingerLockDetected == false ) 
			{
				self WeaponLockDetect( bestTarget );
			}
			self.stingerLockDetected = true;
			if ( isdefined( weapon ) )
			{
				heatseekingmissile::setFriendlyFlags( weapon, bestTarget );
			}
			continue;
		}
		
		self.stingerLockDetected = false;

		InitLockField( bestTarget );
		
		self.stingerTarget = bestTarget;
		self.stingerLockStartTime = getTime();
		self.stingerLockStarted = true;
		self.stingerLostSightlineTime = 0;

		self WeaponLockStart( bestTarget );

		self thread LoopLocalSeekSound( game["locking_on_sound"], 0.6 );
	}
}

function TargetWithinRangeOfPlaySpace( target )
{
	
/#
	// for tuning
	if ( GetDvarInt( "scr_missilelock_playspace_extra_radius_override_enabled", 0 ) > 0 )
	{
		extraRadiusDvar = GetDvarInt( "scr_missilelock_playspace_extra_radius", 5000 );
		if ( extraRadiusDvar != VAL( level.missileLockPlaySpaceCheckExtraRadius, 0 ) )
		{
			level.missileLockPlaySpaceCheckExtraRadius = extraRadiusDvar;
			level.missileLockPlaySpaceCheckRadiusSqr = undefined;
		}
	}
#/
	
	// only allow targetting of targets that are within the play space by a specified radius
	// use level.missileLockPlaySpaceCheckExtraRadius to set it per level
	if ( level.missileLockPlaySpaceCheckEnabled === true )
	{
		if ( !isdefined( target ) )
			return false;
		
		if ( !isdefined( level.playSpaceCenter ) )
			level.playSpaceCenter = util::GetPlaySpaceCenter();
		
		if ( !isdefined( level.missileLockPlaySpaceCheckRadiusSqr ) )
			level.missileLockPlaySpaceCheckRadiusSqr = SQR( ( util::GetPlaySpaceMaxWidth() * 0.5 ) + level.missileLockPlaySpaceCheckExtraRadius );
		
		if ( Distance2DSquared( target.origin, level.playSpaceCenter ) > level.missileLockPlaySpaceCheckRadiusSqr )
			return false;
	}

	return true;
}

function DestroyLockOnCanceledMessage()
{
	if( isdefined( self.LockOnCanceledMessage ) )
		self.LockOnCanceledMessage destroy();
}

function DisplayLockOnCanceledMessage()
{
	if( isdefined( self.LockOnCanceledMessage ) )
		return;

	self.LockOnCanceledMessage = newclienthudelem( self );
	self.LockOnCanceledMessage.fontScale = 1.25;
	self.LockOnCanceledMessage.x = 0;
	self.LockOnCanceledMessage.y = 50; 
	self.LockOnCanceledMessage.alignX = "center";
	self.LockOnCanceledMessage.alignY = "top";
	self.LockOnCanceledMessage.horzAlign = "center";
	self.LockOnCanceledMessage.vertAlign = "top";
	self.LockOnCanceledMessage.foreground = true;
	self.LockOnCanceledMessage.hidewhendead = false;
	self.LockOnCanceledMessage.hidewheninmenu = true;
	self.LockOnCanceledMessage.archived = false;
	self.LockOnCanceledMessage.alpha = 1.0;
	self.LockOnCanceledMessage SetText( &"MP_CANNOT_LOCKON_TO_TARGET" );
}

function GetBestStingerTarget( weapon )
{
	targetsAll = [];
	
	if ( isdefined( self.get_stinger_target_override ) )
	{
		targetsAll = self [ [ self.get_stinger_target_override ] ]();
	}
	else
	{
		targetsAll = target_getArray();
	}
	
	targetsValid = [];

	for ( idx = 0; idx < targetsAll.size; idx++ )
	{
		/#
		//This variable is set and managed by the 'dev_friendly_lock' function, which works with the dev_gui
		if( GetDvarString( "scr_freelock") == "1" )
		{
			//If the dev_gui dvar is set, only check if the target is in the reticule. 
			if( self InsideStingerReticleNoLock( targetsAll[idx], weapon ) )
			{
				targetsValid[targetsValid.size] = targetsAll[idx];
			}
			continue;
		}
		#/		

		target = targetsAll[idx];

		if ( level.teamBased || level.use_team_based_logic_for_locking_on === true ) //team based game modes
		{
			if ( isdefined(target.team) && target.team != self.team) 
			{
				if ( self InsideStingerReticleDetect( target, weapon ) )
				{
					if ( !isdefined( self.is_valid_target_for_stinger_override ) || self [ [ self.is_valid_target_for_stinger_override ] ]( target ) )
					{
						hascamo = isdefined( target.camo_state ) && ( target.camo_state == 1 ) && !self hasPerk( "specialty_showenemyequipment" );
						if( !hascamo )
							targetsValid[targetsValid.size] = target;
					}
				}
			}
		}
		else
		{
			if( self InsideStingerReticleDetect( target, weapon ) ) //Free for all
			{
				if( ( isdefined( target.owner ) && self != target.owner ) || ( isplayer( target ) && self != target ) )
				{
					if ( !isdefined( self.is_valid_target_for_stinger_override ) || self [ [ self.is_valid_target_for_stinger_override ] ]( target ) )
						targetsValid[targetsValid.size] = target;
				}
			}
		}
	}

	if ( targetsValid.size == 0 )
		return undefined;

	bestTarget = targetsValid[0];
	if ( targetsValid.size > 1 )
	{
		closestRatio = 0.0;

		foreach( target in targetsValid ) 
		{
			ratio = RatioDistanceFromScreenCenter( target, weapon );
			if ( ratio > closestRatio )
			{
				closestRatio = ratio;
				bestTarget = target;
			}
		}
	}
	
	return bestTarget;
}

function CalcLockOnRadius( target, weapon )
{
	radius = self getLockOnRadius();
	
	if( isdefined( weapon ) && isdefined( weapon.lockOnScreenRadius ) && ( weapon.lockOnScreenRadius > radius ) )
	{
		radius = weapon.lockOnScreenRadius;
	}	
	
	if( isdefined( level.lockOnCloseRange ) && isdefined( level.lockOnCloseRadiusScaler ) )
	{
		dist2 = DistanceSquared( target.origin, self.origin );
		if( dist2 < level.lockOnCloseRange * level.lockOnCloseRange ) 
			radius = radius * level.lockOnCloseRadiusScaler;
	}
	
	return radius;
}

function CalcLockOnLossRadius( target, weapon )
{
	radius = self getLockOnLossRadius();
	
	if( isdefined( weapon ) && isdefined( weapon.lockOnScreenRadius ) && ( weapon.lockOnScreenRadius > radius ) )
	{
		radius = weapon.lockOnScreenRadius;
	}

	if( isdefined( level.lockOnCloseRange ) && isdefined( level.lockOnCloseRadiusScaler ) )
	{
		dist2 = DistanceSquared( target.origin, self.origin );
		if( dist2 < level.lockOnCloseRange * level.lockOnCloseRange ) 
			radius = radius * level.lockOnCloseRadiusScaler;
	}
	return radius;
}
	
function RatioDistanceFromScreenCenter( target, weapon )
{
	radius = CalcLockOnRadius( target, weapon );
	return Target_ScaleMinMaxRadius( target, self, 65, 0, radius );
}

function InsideStingerReticleDetect( target, weapon )
{
	radius = CalcLockOnRadius( target, weapon );
	return target_isincircle( target, self, 65, radius );
}

function InsideStingerReticleNoLock( target, weapon )
{
	radius = CalcLockOnRadius( target, weapon );
	return target_isincircle( target, self, 65, radius );
}

function InsideStingerReticleLocked( target, weapon )
{
	radius = CalcLockOnLossRadius( target, weapon );
	return target_isincircle( target, self, 65, radius );
}

function IsStillValidTarget( ent, weapon )
{
	if ( ! isdefined( ent ) )
		return false;
	
	if ( isdefined( self.is_still_valid_target_for_stinger_override ) )
		return self [ [ self.is_still_valid_target_for_stinger_override ] ]( ent, weapon );

	if ( ! target_isTarget( ent ) && !( isdefined( ent.allowContinuedLockonAfterInvis ) && ent.allowContinuedLockonAfterInvis ) )
		return false;

	if ( ! InsideStingerReticleDetect( ent, weapon ) )
		return false;

	return true;
}

function PlayerStingerAds()
{
	return ( self PlayerAds() == 1.0 );
}

function LoopLocalSeekSound( alias, interval )
{
	self endon ( "stop_lockon_sound" );
	self endon( "disconnect" );
	self endon ( "death" );
	
	for (;;)
	{
		self PlaySoundForLocalPlayer( alias );
		self PlayRumbleOnEntity( "stinger_lock_rumble" );

		wait interval/2;
	}
}

function PlaySoundForLocalPlayer( alias )
{
	if ( self IsInVehicle() )
	{
		sound_target = self GetVehicleOccupied();
		if ( isdefined( sound_target ) )
		{
			sound_target PlaySoundToPlayer( alias, self );
		}
	}
	else
	{
		self playLocalSound( alias );
	}
}

function LoopLocalLockSound( alias, interval )
{
	self endon ( "stop_locked_sound" );
	self endon( "disconnect" );
	self endon ( "death" );
	
	if ( isdefined( self.stingerlocksound ) )
		return;

	self.stingerlocksound = true;
	

	for (;;)
	{
		// TODO make lock loop audio work correctly  CDC
		
		self PlaySoundForLocalPlayer( alias );
		self PlayRumbleOnEntity( "stinger_lock_rumble" );
		wait interval/6;

		self PlaySoundForLocalPlayer( alias );
		self PlayRumbleOnEntity( "stinger_lock_rumble" );
		wait interval/6;

		self PlaySoundForLocalPlayer( alias );
		self PlayRumbleOnEntity( "stinger_lock_rumble" );
		wait interval/6;

		self StopRumble( "stinger_lock_rumble" );
	}
	self.stingerlocksound = undefined;
}
	
function LockSightTest( target )
{
	cameraPos = self getplayercamerapos();
	
	if ( !isdefined( target ) ) //targets can disapear during targeting.
		return false;
	
	if( isdefined( target.parent ) )
		passed = BulletTracePassed( cameraPos, target.origin, false, target, target.parent );
	else
		passed = BulletTracePassed( cameraPos, target.origin, false, target );
	if ( passed )
		return true;

	front = target GetPointInBounds( 1, 0, 0 );
	if( isdefined( target.parent ) )
		passed = BulletTracePassed( cameraPos, front, false, target, target.parent );
	else
		passed = BulletTracePassed( cameraPos, front, false, target );
	if ( passed )
		return true;

	back = target GetPointInBounds( -1, 0, 0 );
	if( isdefined( target.parent ) )
		passed = BulletTracePassed( cameraPos, back, false, target, target.parent );
	else
		passed = BulletTracePassed( cameraPos, back, false, target );
	if ( passed )
		return true;

	return false;
}

function SoftSightTest()
{
	LOST_SIGHT_LIMIT = 500;

	if ( self LockSightTest( self.stingerTarget ) )
	{
		self.stingerLostSightlineTime = 0;
		return true;
	}

	if ( self.stingerLostSightlineTime == 0 )
		self.stingerLostSightlineTime = getTime();

	timePassed = GetTime() - self.stingerLostSightlineTime;
	//PrintLn( "Losing sight of target [", timePassed, "]..." );

	if ( timePassed >= LOST_SIGHT_LIMIT )
	{
		//PrintLn( "Lost sight of target." );
		self ClearIRTarget();
		return false;
	}
	
	return true;
}

function InitLockField( target )
{
	if ( isdefined( target.locking_on ) )
		return;
		
	target.locking_on = 0;
	target.locked_on = 0;
	target.locking_on_hacking = 0;
}

function LockingOn( target, lock )
{
	Assert( isdefined( target.locking_on ) );
	
	clientNum = self getEntityNumber();
	if ( lock )
	{
		target notify( "locking on" );
		target.locking_on |= ( 1 << clientNum );
		
		self thread watchClearLockingOn( target, clientNum );
	}
	else
	{
		self notify( "locking_on_cleared" );
		target.locking_on &= ~( 1 << clientNum );
	}
}

function watchClearLockingOn( target, clientNum )
{
	target endon("death");
	self endon( "locking_on_cleared" );
	
	self util::waittill_any( "death", "disconnect" );
	
	target.locking_on &= ~( 1 << clientNum );
}

function LockedOn( target, lock )
{
	Assert( isdefined( target.locked_on ) );
	
	clientNum = self getEntityNumber();
	if ( lock )
	{
		target.locked_on |= ( 1 << clientNum );
		
		self thread watchClearLockedOn( target, clientNum );
	}
	else
	{
		self notify( "locked_on_cleared" );
		target.locked_on &= ~( 1 << clientNum );
	}
}


function TargetingHacking( target, lock )
{
	Assert( isdefined( target.locking_on_hacking ) );
	
	clientNum = self getEntityNumber();
	if ( lock )
	{
		target notify( "locking on hacking" );
		target.locking_on_hacking |= ( 1 << clientNum );
		
		self thread watchClearHacking( target, clientNum );
	}
	else
	{
		self notify( "locking_on_hacking_cleared" );
		target.locking_on_hacking &= ~( 1 << clientNum );
	}
}

function watchClearHacking( target, clientNum )
{
	target endon("death");
	self endon( "locking_on_hacking_cleared" );
	
	self util::waittill_any( "death", "disconnect" );
	
	target.locking_on_hacking &= ~( 1 << clientNum );
}


function setFriendlyFlags( weapon, target )
{
	if ( !self isinvehicle() )
	{
		self setFriendlyHacking( weapon, target );
		self setFriendlyTargetting( weapon, target );
		self setFriendlyTargetLocked( weapon, target );

		if ( isdefined( level.killstreakMaxHealthFunction ) )
		{
			if ( isdefined( target.useVTOLTime ) && isdefined( level.vtol ) )
			{
				killstreakEndTime = level.vtol.killstreakEndTime;
				if ( isdefined( killstreakEndTime ) )
				{
					self settargetedentityendtime( weapon, killstreakEndTime );
				}
			}
			else if ( isdefined( target.killstreakEndTime ) )
			{
				self settargetedentityendtime( weapon, target.killstreakEndTime );
			}
			else if ( isdefined( target.parentstruct ) && isdefined( target.parentStruct.killstreakEndTime ) )
			{
				self settargetedentityendtime( weapon, target.parentStruct.killstreakEndTime );
			}
			else
			{
				self settargetedentityendtime( weapon, 0 );
			}
			self settargetedmissilesremaining( weapon, 0 );

			killstreakType = target.killstreakType;
			if ( !isdefined( target.killstreakType ) && isdefined( target.parentstruct ) && isdefined( target.parentStruct.killstreakType ) )
			{
				killstreakType  = target.parentStruct.killstreakType;
			}
			else if ( isdefined( target.useVTOLTime ) && isdefined( level.vtol.killstreakType ) )
			{
				killstreakType = level.vtol.killstreakType;
			}
			
			if ( isdefined ( killstreakType ) && isdefined( level.killstreakbundle[killstreakType] ) )
			{
				if ( isdefined( target.forceOneMissile ) )
				{
					self settargetedmissilesremaining( weapon, 1 );
				}
				else if ( isdefined( target.useVTOLTime ) && isdefined( level.vtol ) && isdefined( level.vtol.totalRocketHits ) && isdefined( level.vtol.missileToDestroy ) )
				{
					self settargetedmissilesremaining( weapon, level.vtol.missileToDestroy - level.vtol.totalRocketHits );
				}
				else
				{
					maxHealth = [[level.killstreakMaxHealthFunction]]( killstreakType );
					damageTaken = target.damageTaken;
					if ( !isdefined( damageTaken )  && isdefined( target.parentstruct )  )
					{
						damageTaken = target.parentstruct.damageTaken;
					}
					if ( isdefined( target.missileTrackDamage ) ) 
					{
						damageTaken = target.missileTrackDamage;
					}
					
					if ( isdefined( damageTaken ) && isdefined( maxHealth ) )
					{
						damagePerRocket = ( maxHealth / level.killstreakbundle[killstreakType].ksRocketsToKill ) + 1;
						remainingHealth = maxHealth - damageTaken;
						if ( remaininghealth > 0 )
						{
							missilesRemaining = int( ceil( remainingHealth / damageperrocket ) );
							if ( isdefined( target.numflares ) && target.numflares > 0 )
							{
								missilesRemaining += target.numFlares;
							}
							if ( isdefined( target.flak_drone ) )
							{
								missilesRemaining += 1;
							}
							
							self settargetedmissilesremaining( weapon, missilesRemaining );
						}
					}
				}
			}
		}
	}
}

function setFriendlyHacking( weapon, target )
{
	if ( level.teambased ) 
	{
		friendlyHackingMask = target.locking_on_hacking;
		
		if ( isdefined( friendlyHackingMask ) )
		{
			friendlyHacking = false;
			clientNum = self getEntityNumber();
			friendlyHackingMask &= ~( 1 << clientNum );
			if ( friendlyHackingMask != 0 )
			{
				friendlyHacking = true;
			}
			self SetWeaponFriendlyHacking( weapon, friendlyHacking );
		}
	}
}

function setFriendlyTargetting( weapon, target )
{
	if ( level.teambased ) 
	{
		friendlyTargetingMask = target.locking_on;
		
		if ( isdefined( friendlyTargetingMask ) )
		{
			friendlyTargeting = false;
			clientNum = self getEntityNumber();
			friendlyTargetingMask &= ~( 1 << clientNum );
			if ( friendlyTargetingMask != 0 )
			{
				friendlyTargeting = true;
			}
			self SetWeaponFriendlyTargeting( weapon, friendlyTargeting );
		}
	}
}

function setFriendlyTargetLocked( weapon, target )
{
	if ( level.teambased ) 
	{
		friendlyTargetLocked = false;
		friendlyLockingOnMask = target.locked_on;
		
		if ( isdefined( friendlyLockingOnMask ) )
		{
			friendlyTargetLocked = false;
			clientNum = self getEntityNumber();
			friendlyLockingOnMask &= ~( 1 << clientNum );
			if ( friendlylockingonMask != 0 )
			{
				friendlyTargetLocked = true;
			}
		}
		if ( friendlyTargetLocked == false )
		{
			friendlyTargetLocked = target MissileTarget_isOtherPlayerMissileIncoming( self );
		}
		self SetWeaponFriendlyTargetLocked( weapon, friendlyTargetLocked );
	}
}

function watchClearLockedOn( target, clientNum )
{
	self endon( "locked_on_cleared" );
	
	self util::waittill_any( "death", "disconnect" );

	if ( isdefined( target ) )
	{
		target.locked_on &= ~( 1 << clientNum );
	}
}

function MissileTarget_LockOnMonitor( player, endon1, endon2 )
{
	self endon( "death" );
	
	if ( isdefined(endon1) )
		self endon( endon1 );
	if ( isdefined(endon2) )
		self endon( endon2 );

	for( ;; )
	{

		if( target_isTarget( self ) )
		{	
			if ( self MissileTarget_isMissileIncoming() )
			{
				self clientfield::set( "heli_warn_fired", 1 );
				self clientfield::set( "heli_warn_locked", 0 );
				self clientfield::set( "heli_warn_targeted", 0 );
			}	
			else if( isdefined(self.locked_on) && self.locked_on )
			{
				self clientfield::set( "heli_warn_locked", 1 );
				self clientfield::set( "heli_warn_fired", 0 );
				self clientfield::set( "heli_warn_targeted", 0 );
			}
			else if( isdefined(self.locking_on) && self.locking_on )
			{
				self clientfield::set( "heli_warn_targeted", 1 );
				self clientfield::set( "heli_warn_fired", 0 );
				self clientfield::set( "heli_warn_locked", 0 );
			}
			else
			{
				self clientfield::set( "heli_warn_fired", 0 );
				self clientfield::set( "heli_warn_targeted", 0 );
				self clientfield::set( "heli_warn_locked", 0 );
			}
		}
		
		wait( 0.1 );
	}
}

function _incomingMissile( missile, attacker )
{
	if ( !isdefined(self.incoming_missile) )
	{
		self.incoming_missile = 0;
	}
	if ( !isdefined(self.incoming_missile_owner) )
	{
		self.incoming_missile_owner = [];
	}
	if ( !isdefined( self.incoming_missile_owner[attacker.entnum] ) )
	{
		self.incoming_missile_owner[attacker.entnum] = 0;
	}	
	
	self.incoming_missile++;
	self.incoming_missile_owner[attacker.entnum]++;
	
	attacker LockedOn(self, true);
	
	self thread _incomingMissileTracker( missile, attacker );
}

function _incomingMissileTracker( missile, attacker )
{
	self endon("death");
	
	attacker_entnum = attacker.entnum;
	
	missile waittill("death");
	
	self.incoming_missile--;
	self.incoming_missile_owner[attacker_entnum]--;
	if ( self.incoming_missile_owner[attacker_entnum] == 0 )
	{
		self.incoming_missile_owner[attacker_entnum] = undefined;
	}
	
	if ( isdefined( attacker ) )
	{
		attacker LockedOn( self, false );
	}
	
	assert( self.incoming_missile >= 0 );
}

function MissileTarget_isMissileIncoming()
{
	if ( !isdefined(self.incoming_missile) )
		return false;
		
	if ( self.incoming_missile )
		return true;
	
	return false;
}

function MissileTarget_isOtherPlayerMissileIncoming( attacker )
{
	if ( !isdefined(self.incoming_missile_owner) )
		return false;
	
	if ( self.incoming_missile_owner.size == 0 )
		return false;
	
	if ( self.incoming_missile_owner.size == 1 && isdefined( self.incoming_missile_owner[attacker.entnum] ) )
	    return false;
	
	return true;
}

function MissileTarget_HandleIncomingMissile(responseFunc, endon1, endon2, allowDirectDamage )
{
	level endon( "game_ended" );
	self endon( "death" );
	if ( isdefined(endon1) )
		self endon( endon1 );
	if ( isdefined(endon2) )
		self endon( endon2 );

	for( ;; )
	{
		self waittill( "stinger_fired_at_me", missile, weapon, attacker );
			
		_incomingMissile(missile, attacker);
		
		if ( isdefined(responseFunc) )
			[[responseFunc]]( missile, attacker, weapon, endon1, endon2, allowDirectDamage );
	}
}

function MissileTarget_ProximityDetonateIncomingMissile( endon1, endon2, allowDirectDamage )
{
	MissileTarget_HandleIncomingMissile(&MissileTarget_ProximityDetonate, endon1, endon2, allowDirectDamage );
}

function _missileDetonate( attacker, weapon, range, minDamage, maxDamage, allowDirectDamage )
{
	origin = self.origin;
	
	target = self Missile_GetTarget();

	self detonate();

	// guarantee a locked_on target is directly damaged if allowed and reasonably close enough
	if ( ( allowDirectDamage === true ) && isdefined( target ) && isdefined( target.origin ) )
	{
		minDistSq = VAL( target.locked_missile_min_distsq, SQR( range ) ); // sanity check distance for "bad" direct hits
		distSq = DistanceSquared( self.origin, target.origin );
		if ( distSq < minDistSq )
		{
			target DoDamage( maxDamage, origin, attacker, self, "none", "MOD_PROJECTILE", 0, weapon );
		}
	}

	radiusDamage( origin, range, maxDamage, minDamage, attacker, "MOD_PROJECTILE_SPLASH", weapon );
}

function MissileTarget_ProximityDetonate( missile, attacker, weapon, endon1, endon2, allowDirectDamage )
{
	level endon( "game_ended" );
	missile endon ( "death" );
	if ( isdefined(endon1) )
		self endon( endon1 );
	if ( isdefined(endon2) )
		self endon( endon2 );
	
	minDist = DistanceSquared( missile.origin, self.origin );
	lastCenter = self.origin;
	
	missile Missile_SetTarget( self, VAL( Target_GetOffset( self ), ( 0, 0, 0 ) ) );

	if ( isdefined( self.missileTargetMissDistance ) )
	{
		missedDistanceSq = self.missileTargetMissDistance * self.missileTargetMissDistance;
	}
	else
	{
		missedDistanceSq = MISSED_BY_FAR_DISTANCE * MISSED_BY_FAR_DISTANCE;
	}
	flareDistanceSq = FLARE_DISTANCE * FLARE_DISTANCE;
	
	for ( ;; )
	{
		// target already destroyed
		if ( !isdefined( self ) )
			center = lastCenter;
		else
			center = self.origin;
			
		lastCenter = center;		
		
		curDist = DistanceSquared( missile.origin, center );
		
		if( curDist < flareDistanceSq && isdefined(self.numFlares) && self.numFlares > 0 )
		{
			self.numFlares--;			

			self thread MissileTarget_PlayFlareFx();
			self challenges::trackAssists( attacker, 0, true );
			newTarget = self MissileTarget_DeployFlares(missile.origin, missile.angles);
			
			missile Missile_SetTarget( newTarget, VAL( Target_GetOffset( newTarget ), ( 0, 0, 0 ) ) );
			missileTarget = newTarget;
			
			return;
		}		
		
		if ( curDist < minDist )
			minDist = curDist;
		
		if ( curDist > minDist )
		{			
			if ( curDist > missedDistanceSq )
				return;

			missile thread _missileDetonate( attacker, weapon, MISSED_BY_FAR_DISTANCE, 600, 600, allowDirectDamage );
			return;
		}
		
		WAIT_SERVER_FRAME;
	}	
}

function MissileTarget_PlayFlareFx()
{
	if ( !isdefined( self ) )
		return;
	
	flare_fx = level.fx_flare;
	
	if ( isdefined( self.fx_flare ) )
	{
		flare_fx = self.fx_flare;
	}
	if( isdefined( self.flare_ent ) )
	{
		PlayFXOnTag( flare_fx, self.flare_ent, "tag_origin" );
	}
	else
	{
		PlayFXOnTag( flare_fx, self, "tag_origin" );
	}
	
	if ( isdefined( self.owner ) )
	{
		self playsoundtoplayer ( "veh_huey_chaff_drop_plr", self.owner );
	}
	self PlaySound ( "veh_huey_chaff_explo_npc" );
}

function MissileTarget_DeployFlares(origin, angles) // self == missile target
{
	vec_toForward = anglesToForward( self.angles );
	vec_toRight = AnglesToRight( self.angles );
	
	vec_toMissileForward = anglesToForward( angles );

	delta = self.origin - origin;
	dot = VectorDot(vec_toMissileForward,vec_toRight);
	
	sign = 1;
	if ( dot > 0 ) 
		sign = -1;
		
	// out to one side or the other slightly backwards
	flare_dir = VectorNormalize(VectorScale( vec_toForward, -0.5 ) + VectorScale( vec_toRight, sign ));
	velocity = VectorScale( flare_dir, RandomIntRange(200, 400));
	velocity = (velocity[0], velocity[1], velocity[2] - RandomIntRange(10, 100) );

	flareOrigin = self.origin;
	flareOrigin = flareOrigin + VectorScale( flare_dir, RandomIntRange(600, 800));
	
	// some height will allow a missle going twards a low hovering plane to 
	// have enough radius to turn to the new target
	flareOrigin = flareOrigin + ( 0, 0, 500 );
	
	if ( isdefined( self.flareOffset ) )
		flareOrigin = flareOrigin + self.flareOffset;
	
	flareObject = spawn( "script_origin", flareOrigin );
	flareObject.angles = self.angles;
	
	flareObject SetModel( "tag_origin" );
	flareObject MoveGravity( velocity, 5.0 );
	
	flareObject thread util::deleteAfterTime( 5.0 );
/#
	self thread debug_tracker( flareObject );
#/
	return flareObject;
}

/#
function debug_tracker( target )
{
	target endon( "death");
	
	while(1)
	{
		util::debug_sphere( target.origin, 10, (1,0,0), 1, 1 );
		WAIT_SERVER_FRAME;
	}
}
#/