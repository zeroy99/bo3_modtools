#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "triggerstring", "MP_GENERIC_HACKING" );

#namespace hacker_tool;

function init_shared()
{
	level.weaponHackerTool = GetWeapon( "pda_hack" );

	level.hackerToolLostSightLimitMs = 1000;
	level.hackerToolLockOnRadius = 25;
	level.hackerToolLockOnFOV = 65;
	level.hackerToolHackTimeMs = 0.4;

	// equipment
	level.equipmentHackerToolRadius = 20;
	level.equipmentHackerToolTimeMs = 100;

	// care packages
	level.carePackageHackerToolRadius = 60;
	level.carePackageHackerToolTimeMs = GetGametypeSetting("crateCaptureTime") * 500;
	level.carePackageFriendlyHackerToolTimeMs = GetGametypeSetting("crateCaptureTime") * 2000 ;
	level.carePackageOwnerHackerToolTimeMs = 250;
	
	// vehicles
	level.vehicleHackerToolRadius = 80;
	level.vehicleHackerToolTimeMs = 5000;
	
	clientfield::register( "toplayer", "hacker_tool", VERSION_SHIP, 2, "int" );	
	//thread tunables();
	callback::on_spawned( &on_player_spawned );
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function on_player_spawned()
{
	self endon( "disconnect" );

	self clearHackerTarget( undefined, false, true);
	
	self thread watchHackerToolUse();
	self thread watchHackerToolFired();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function clearHackerTarget( weapon, successfulHack, spawned ) // self == player
{
	self notify( "stop_lockon_sound" );
	self notify( "stop_locked_sound" );
	self notify( "clearHackerTarget" );

	self.stingerlocksound = undefined;
	self StopRumble( "stinger_lock_rumble" );

	self.hackerToolLockStartTime = 0;
	self.hackerToolLockStarted = false;
	self.hackerToolLockFinalized = false;
	self.hackerToolLockTimeElapsed = 0.0;
	
	if ( isdefined( weapon ) )
	{
		if ( weapon.isHackToolWeapon )
		{
			self SetWeaponHackPercent( weapon, 0.0 );
		}
		
		if( isdefined( self.hackerToolTarget ))
		{
			heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );
		}
	}
	
	if ( successfulHack == false ) 
	{
		if ( spawned == false ) 
		{
			if( isdefined( self.hackerToolTarget ) )
				self playsoundtoplayer( "evt_hacker_hack_lost", self ); // hacking failed
		}
		self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_INACTIVE );
		self stopHackerToolSoundLoop();
	}
	
	if( isdefined( self.hackerToolTarget ))
	{
		heatseekingmissile::TargetingHacking( self.hackerToolTarget, false );
	}
	self.hackerToolTarget = undefined;

	self WeaponLockFree();
	self WeaponLockTargetTooClose( false );
	self WeaponLockNoClearance( false );

	self StopLocalSound( game["locking_on_sound"] );
	self StopLocalSound( game["locked_on_sound"] );

	self heatseekingmissile::DestroyLockOnCanceledMessage();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function watchHackerToolFired() // self == player
{
	self endon( "disconnect" );
	self endon ( "death" );
	self endon ("killHackerMonitor");

	while ( true )
	{
		self waittill( "hacker_tool_fired", hackerToolTarget, weapon );

		if( isdefined( hackerToolTarget ))
		{
			if ( isEntityHackableCarePackage( hackerToolTarget ) )
			{
				scoreevents::giveCrateCaptureMedal( hackerToolTarget, self );
				hackerToolTarget notify( "captured", self, true );
				
				if ( isdefined( hackerToolTarget.owner ) && isplayer( hackerToolTarget.owner ) && hackerToolTarget.owner.team != self.team && isdefined( level.play_killstreak_hacked_dialog ) )
				{
					hackerToolTarget.owner [[level.play_killstreak_hacked_dialog]]( hackerToolTarget.killstreakType,hackerToolTarget.killstreakId, self );
				}
			}
			else if ( isEntityHackableWeaponObject( hackerToolTarget ) && isdefined( hackerToolTarget.hackerTrigger ))
			{
				// turrets and weapon objects
				hackerToolTarget.hackerTrigger notify( "trigger", self, true );
				hackerToolTarget.previouslyHacked = true;
				self.throwinggrenade = false;
			}
			else if ( isdefined( hackerToolTarget.killstreak_hackedCallback ) && ( !isdefined( hackerToolTarget.killstreakTimedOut ) || hackerToolTarget.killstreakTimedOut == false ) )
			{
				if ( hackerToolTarget.killstreak_hackedProtection == false )
				{
					if ( isdefined( hackerToolTarget.owner ) && isplayer( hackerToolTarget.owner ) )
					{
						// Hack complete
						if ( isdefined( level.play_killstreak_hacked_dialog ) )
						{
							hackerToolTarget.owner [[level.play_killstreak_hacked_dialog]]( hackerToolTarget.killstreakType,hackerToolTarget.killstreakId, self );
						}
					}
					self playsoundtoplayer( "evt_hacker_fw_success", self ); // hacked firewall successfully
					hackerToolTarget notify( "killstreak_hacked", self );
					hackerToolTarget.previouslyHacked = true;
					hackerToolTarget [[ hackerToolTarget.killstreak_hackedCallback ]]( self );
					
					if ( self util::has_blind_eye_perk_purchased_and_equipped() || self util::has_hacker_perk_purchased_and_equipped() )
					{
						self AddPlayerStat( "hack_streak_with_blindeye_or_engineer", 1 );
					}
				}
				else
				{
					if ( isdefined( hackerToolTarget.owner ) && isplayer( hackerToolTarget.owner ) )
					{
						// Breach complete
						if ( isdefined( level.play_killstreak_firewall_hacked_dialog ) )
						{
							self.hackerToolTarget.owner [[level.play_killstreak_firewall_hacked_dialog]]( self.hackerToolTarget.killstreakType, self.hackerToolTarget.killstreakId );
						}
					}
					self playsoundtoplayer( "evt_hacker_ks_success", self ); // hacked killstreak successfully
					scoreevents::processscoreevent( "hacked_killstreak_protection", self, hackerToolTarget, level.weaponHackerTool );
				}
				hackerToolTarget.killstreak_hackedProtection = false;
			}
			else
			{
				if ( isdefined( hackerToolTarget.classname ) && hackerToolTarget.classname == "grenade" )
				{
					damage = 1;
				}
				else if ( isdefined( hackerToolTarget.hackerToolDamage ))
				{
					damage = hackerToolTarget.hackerToolDamage;
				}
				else if ( isdefined( hackerToolTarget.maxhealth ))
				{
					damage = hackerToolTarget.maxhealth + 1;
				}
				else
				{
					damage = 999999;
				}
								
				if ( isdefined( hackerToolTarget.numFlares ) && hackerToolTarget.numFlares > 0 )
				{
					damage = 1;
					hackerToolTarget.numFlares--;
					hackerToolTarget heatseekingmissile::MissileTarget_PlayFlareFx();
				}

				hackerToolTarget DoDamage( damage, self.origin, self, self, 0, "MOD_UNKNOWN", 0, weapon );
			}
			if ( self util::is_item_purchased( "pda_hack" ) )
			{
				self AddPlayerStat( "hack_enemy_target", 1 );
			}
			self AddWeaponStat( weapon, "used", 1 );
		}

		clearHackerTarget( weapon, true, false );
		self forceoffhandend();

		if ( GetDvarint( "player_sustainAmmo" ) == 0 )
		{
			clip_ammo = self GetWeaponAmmoClip( weapon );
			clip_ammo--;
			/#assert( clip_ammo >= 0);#/
	
			self setWeaponAmmoClip( weapon, clip_ammo );
		}
		

		self killstreaks::switch_to_last_non_killstreak_weapon(); // won't switch weapons while the shoulder button is held
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function watchHackerToolUse() // self == player
{
	self endon( "disconnect" );
	self endon ( "death" );
	
	for (;;)
	{
		self waittill ( "grenade_pullback", weapon );

		if ( weapon.rootWeapon == level.weaponHackerTool )
		{
			WAIT_SERVER_FRAME;
			currentOffhand = self getCurrentOffhand();
			if ( self isUsingOffhand() && ( currentOffhand.rootWeapon == level.weaponHackerTool ) )
			{
				self thread hackerToolTargetLoop( weapon );
				self thread watchHackerToolEnd( weapon );
				self thread watchForGrenadeFire( weapon );
				self thread watchHackerToolInterrupt(weapon );
			}
		}
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function watchHackerToolInterrupt( weapon ) // self == player
{
	self endon( "disconnect" );
	self endon( "hacker_tool_fired" );
	self endon( "death" );
	self endon( "weapon_change" );
	self endon( "grenade_fire" );

	while( true )
	{
		level waittill( "use_interrupt", interruptTarget );

		if( self.hackerToolTarget == interruptTarget )
		{
			clearHackerTarget( weapon, false, false );
		}
		WAIT_SERVER_FRAME;
	}
}


function watchHackerToolEnd( weapon ) // self == player
{
	self endon( "disconnect" );
	self endon( "hacker_tool_fired" );

	msg = self util::waittill_any_return( "weapon_change", "death", "hacker_tool_fired", "disconnect" );
	clearHackerTarget( weapon, false, false );
	self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_INACTIVE );
	self stopHackerToolSoundLoop();
}


function watchForGrenadeFire( weapon ) // self == player
{
	self endon( "disconnect" );
	self endon( "hacker_tool_fired" );
	self endon( "weapon_change" );
	self endon( "death" );

	while( true )
	{
		//This notify will be called when a weapon object gets hacked to reboot the watcher. We don't want to give the player ammo for this.
		self waittill( "grenade_fire", grenade_instance, grenade_weapon, respawnFromHack );

		if( isDefined( respawnFromHack ) && respawnFromHack )
			continue;

		clearHackerTarget( grenade_weapon, false, false );

		clip_ammo = self GetWeaponAmmoClip( grenade_weapon );
		clip_max_ammo = grenade_weapon.clipSize;
	
		if( clip_ammo < clip_max_ammo )
		{
			clip_ammo++;
		}
		self setWeaponAmmoClip( grenade_weapon, clip_ammo );
		break;
	}
}


function playHackerToolSoundLoop() // self == player
{
	if ( !isdefined( self.hacker_sound_ent ) || ( isdefined( self.hacker_alreadyhacked ) && self.hacker_alreadyhacked == true ) )
	{
		self playloopsound ("evt_hacker_device_loop");
		self.hacker_sound_ent = true;
		self.hacker_alreadyhacked = false;
	}
}

function stopHackerToolSoundLoop() // self == player
{
	self StopLoopSound( 0.5 );
	self.hacker_sound_ent = undefined;
	self.hacker_alreadyhacked = undefined;
}


function hackerToolTargetLoop( weapon ) // self == player
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "weapon_change" );
	self endon( "grenade_fire" );
	
	self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_ACTIVE );
	
	self playHackerToolSoundLoop();

	while ( true )
	{
		WAIT_SERVER_FRAME;
		WAIT_SERVER_FRAME;

		if ( self.hackerToolLockFinalized )
		{
			if ( !self isValidHackerToolTarget( self.hackerToolTarget, weapon, false ))
			{
				self clearHackerTarget( weapon, false, false );
				continue;
			}

			passed = self hackerSoftSightTest( weapon );

			if ( !passed )
			{
				continue;
			}
			self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_INACTIVE );
			self stopHackerToolSoundLoop();
			heatseekingmissile::TargetingHacking( self.hackerToolTarget, false);
			heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );

			thread heatseekingmissile::LoopLocalLockSound( game["locked_on_sound"], 0.75 );

			self notify( "hacker_tool_fired", self.hackerToolTarget, weapon );
			return;
		}

		if ( self.hackerToolLockStarted )
		{
			if ( !self isValidHackerToolTarget( self.hackerToolTarget, weapon, false ) )
			{
				self clearHackerTarget( weapon, false, false );
				continue;
			}
			
			lockOnTime = self getLockOnTime( self.hackerToolTarget, weapon );			
			
			if ( lockOnTime == 0 )
			{
				self clearHackerTarget( weapon, false, false );
				continue;
			}

			if ( self.hackerToolLockTimeElapsed == 0.0 )
			{
				self PlayLocalSound ( "evt_hacker_hacking" );

				if ( isdefined( self.hackerToolTarget.owner ) && isplayer( self.hackerToolTarget.owner ) )
				{
					if ( isdefined( self.hackerToolTarget.killstreak_hackedCallback ) && ( !isdefined( self.hackerToolTarget.killstreakTimedOut ) || self.hackerToolTarget.killstreakTimedOut == false ) )
					{
						if ( self.hackerToolTarget.killstreak_hackedProtection == false )
						{
							// hacking started, regular hack
							//self.hackerToolTarget.owner
							if ( isdefined( level.play_killstreak_being_hacked_dialog ) )
							{
								self.hackerToolTarget.owner [[level.play_killstreak_being_hacked_dialog]]( self.hackerToolTarget.killstreakType, self.hackerToolTarget.killstreakId );
							}
						}
						else
						{
							// breaching firewall started
							if ( isdefined( level.play_killstreak_firewall_being_hacked_dialog ) )
							{
								self.hackerToolTarget.owner [[level.play_killstreak_firewall_being_hacked_dialog]]( self.hackerToolTarget.killstreakType, self.hackerToolTarget.killstreakId );
							}
						}
					}
				}
			}

			self WeaponLockStart( self.hackerToolTarget );
			self playHackerToolSoundLoop();
			if ( isdefined( self.hackerToolTarget.killstreak_hackedProtection ) && self.hackerToolTarget.killstreak_hackedProtection == true )
			{
				self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_FIREWALL );
			}
			else
			{
				self clientfield::set_to_player( "hacker_tool", HACKER_TOOL_HACKING );
			}

			heatseekingmissile::TargetingHacking( self.hackerToolTarget, true );
			heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );

			passed = self hackerSoftSightTest( weapon );

			if ( !passed )
			{
				continue;
			}
			
			if ( self.hackerToolLostSightlineTime == 0 )
			{
				self.hackerToolLockTimeElapsed += 0.1 * hackingTimeScale( self.hackerToolTarget );
				hackPercentage = (self.hackerToolLockTimeElapsed / ( lockOnTime )) * 100;
				self SetWeaponHackPercent( weapon, hackPercentage );
				heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );
			}
			else
			{
				self.hackerToolLockTimeElapsed -= 0.1 * hackingTimeNoLineOfSightScale( self.hackerToolTarget );
				if ( self.hackerToolLockTimeElapsed < 0 )
				{
					self.hackerToolLockTimeElapsed = 0;
					self clearHackerTarget( weapon, false, false );
					continue;
				}
				hackPercentage = (self.hackerToolLockTimeElapsed / ( lockOnTime )) * 100;

				self SetWeaponHackPercent( weapon, hackPercentage );
				heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );				
			}

			if ( self.hackerToolLockTimeElapsed < lockOnTime )
			{
				continue;
			}

			assert( isdefined( self.hackerToolTarget ));

			self notify( "stop_lockon_sound" );
			self.hackerToolLockFinalized = true;

			self WeaponLockFinalize( self.hackerToolTarget );

			continue;
		}
		
		
		if ( self IsEMPJammed() )
		{
			self heatseekingmissile::DestroyLockOnCanceledMessage();
			continue;
		}

		bestTarget = self getBestHackerToolTarget( weapon );

		if ( !isdefined( bestTarget ))
		{
			self stopHackerToolSoundLoop();
			self heatseekingmissile::DestroyLockOnCanceledMessage();
			continue;
		}

		if ( !self heatseekingmissile::LockSightTest( bestTarget ) )
		{
			self stopHackerToolSoundLoop();
			self heatseekingmissile::DestroyLockOnCanceledMessage();
			continue;
		}

		//check for delay allowing helicopters to enter the play area
		if( self heatseekingmissile::LockSightTest( bestTarget ) && isdefined( bestTarget.lockOnDelay ) && bestTarget.lockOnDelay )
		{
			self stopHackerToolSoundLoop();
			self heatseekingmissile::DisplayLockOnCanceledMessage();
			continue;
		}
		
		self heatseekingmissile::DestroyLockOnCanceledMessage();

		if (  isEntityPreviouslyHacked( bestTarget ) )
		{
			if ( !isdefined( self.hacker_sound_ent ) || ( isdefined( self.hacker_alreadyhacked ) && self.hacker_alreadyhacked == false  ) )
			{
				self.hacker_sound_ent = true;
				self.hacker_alreadyhacked = true;
				self playloopsound( "evt_hacker_unhackable_loop" );
			}
			continue;
		}
		else 
		{
			self stopHackerToolSoundLoop();
		}

		heatseekingmissile::InitLockField( bestTarget );
		
		self.hackerToolTarget = bestTarget;
		
		self thread watchTargetEntityUpdate( bestTarget );
		self.hackerToolLockStartTime = getTime();
		self.hackerToolLockStarted = true;
		self.hackerToolLostSightlineTime = 0;
		self.hackerToolLockTimeElapsed = 0.0;
		self SetWeaponHackPercent( weapon, 0.0 );
		if ( isdefined( self.hackerToolTarget ) )
		{
			heatseekingmissile::setFriendlyFlags( weapon, self.hackerToolTarget );
		}
	}
}

function watchTargetEntityUpdate( bestTarget )
{
	self endon( "death" );
	self endon( "disconnect" );
	
	self notify( "watchTargetEntityUpdate" );
	self endon( "watchTargetEntityUpdate" );

	self endon( "clearHackerTarget" );

	bestTarget endon( "death" );
	
	bestTarget waittill( "hackertool_update_ent", newEntity );
	heatseekingmissile::InitLockField( newEntity );
	self.hackerToolTarget = newEntity;
}

function getBestHackerToolTarget( weapon )
{
	targetsValid = [];

	targetsAll = ArrayCombine( target_getArray(), level.MissileEntities, false, false );
	targetsAll = ArrayCombine( targetsAll, level.hackerToolTargets, false, false );

	for ( idx = 0; idx < targetsAll.size; idx++ )
	{
		target_ent = targetsAll[ idx ];

		if ( !isdefined( target_ent ) || !isdefined( target_ent.owner ) )
		{
			continue;
		}			
		
		/#
		//This variable is set and managed by the 'dev_friendly_lock' function, which works with the dev_gui
		if( GetDvarString( "scr_freelock") == "1" )
		{
			//If the dev_gui dvar is set, only check if the target is in the reticule. 
			if( self isWithinHackerToolReticle( targetsAll[idx], weapon ) )
			{
				targetsValid[targetsValid.size] = targetsAll[idx];
			}
			continue;
		}
		#/

		if ( level.teamBased || level.use_team_based_logic_for_locking_on === true ) //team based game modes
		{
			if ( isEntityHackableCarePackage( target_ent ))
			{
				if ( self canTargetEntity( target_ent, weapon ) )
				{
					targetsValid[ targetsValid.size ] = target_ent;
				}				
			}
			else if ( isdefined( target_ent.team ))
			{
				if ( target_ent.team != self.team )
				{
					if ( self canTargetEntity( target_ent, weapon ) )
					{
						targetsValid[ targetsValid.size ] = target_ent;
					}
				}
			}
			else if ( isdefined( target_ent.owner.team ) )
			{
				if ( target_ent.owner.team != self.team )
				{
					if ( self canTargetEntity( target_ent, weapon ) )
					{
						targetsValid[ targetsValid.size ] = target_ent;
					}
				}
			}
		}		
		else 
		{
			if( self isWithinHackerToolReticle( target_ent, weapon )) //Free for all
			{
				if ( isEntityHackableCarePackage( target_ent ))
				{
					if ( self canTargetEntity( target_ent, weapon ) )
					{
						targetsValid[ targetsValid.size ] = target_ent;		
					}
				}
				else if( isdefined( target_ent.owner ) && self != target_ent.owner )
				{
					if ( self canTargetEntity( target_ent, weapon ) )
					{
						targetsValid[ targetsValid.size ] = target_ent;
					}
				}
			}
		}
	}

	chosenEnt = undefined;

	if ( targetsValid.size != 0 )
	{
		//TODO: find the closest
		chosenEnt = targetsValid[0];
	}

	return chosenEnt;
}

function canTargetEntity( target, weapon )
{
	if ( !self isWithinHackerToolReticle( target, weapon ) )
		return false;
	if ( !isValidHackerToolTarget( target, weapon, true ) )
		return false;
	
	return true;
}

function isWithinHackerToolReticle( target, weapon )
{
	radiusInner = getHackerToolInnerRadius( target );
	radiusOuter = getHackerToolOuterRadius( target );
	
	if( Target_ScaleMinMaxRadius( target, self, level.hackerToolLockOnFOV, radiusInner, radiusOuter ) > 0.0 )
	{
		return true;
	}
	
	return Target_BoundingIsUnderReticle( self, target, weapon.lockOnMaxRange );
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function hackingTimeScale( target )
{
	hackRatio = 1;
	radiusInner = getHackerToolInnerRadius( target );
	radiusOuter = getHackerToolOuterRadius( target );
	
	if ( radiusInner != radiusOuter )
	{
		
		scale = Target_ScaleMinMaxRadius( target, self, level.hackerToolLockOnFOV, radiusInner, radiusOuter );
		scale = scale * scale * scale * scale;
		hackTime = LerpFloat( getHackOuterTime( target ), getHackTime( target ), scale );
/#
		hackerToolDebugText = GetDvarInt( "hackertoolDebugText", 0 ) ;
		if ( hackerToolDebugText )
		{
			print3d( target.origin, "scale: " + scale + "\nInner: " + radiusInner + " Outer: " + radiusOuter, ( 0, 0, 0 ), 1, hackerToolDebugText, 2 );
		}
		assert( hacktime > 0 );
#/
		
		hackRatio = getHackTime( target ) / hackTime;
		if ( !isdefined( hackRatio ) )
		{
			hackRatio = 1;	
		}
	}
	
	return hackRatio;
}

function hackingTimeNoLineOfSightScale( target )
{
	hackRatio = 1;

	if ( isdefined( target.killstreakHackLostLineOfSightTimeMs ) && target.killstreakHackLostLineOfSightTimeMs > 0 )
	{
/#
		assert(  target.killstreakHackLostLineOfSightTimeMs > 0 );
#/			
		hackRatio = 1000 / target.killstreakHackLostLineOfSightTimeMs;
	}
	
	
	return hackRatio;
}

	
//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function isEntityHackableWeaponObject( entity )
{
	if ( isdefined( entity.classname ) && entity.classname == "grenade" )
	{
		if ( isdefined( entity.weapon ) )
		{
			watcher = weaponobjects::getWeaponObjectWatcherByWeapon( entity.weapon );
			if ( isdefined( watcher ))
			{
				if ( watcher.hackable )
				{
					/#
					assert( isdefined( watcher.hackerToolRadius ));
					assert( isdefined( watcher.hackerToolTimeMs ));
					#/

					return true;
				}
			}
		}
	}

	return false;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function getWeaponObjectHackerRadius( entity )
{
	/#
	assert( isdefined( entity.classname ));
	assert( isdefined( entity.weapon ));
	#/

	watcher = weaponobjects::getWeaponObjectWatcherByWeapon( entity.weapon );

	/#
	assert( watcher.hackable );
	assert( isdefined( watcher.hackerToolRadius ));
	#/

	return watcher.hackerToolRadius;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function getWeaponObjectHackTimeMs( entity )
{
	/#
	assert( isdefined( entity.classname ));
	assert( isdefined( entity.weapon ));
	#/

	watcher = weaponobjects::getWeaponObjectWatcherByWeapon( entity.weapon );

	/#
	assert( watcher.hackable );
	assert( isdefined( watcher.hackerToolTimeMs ));
	#/

	return watcher.hackerToolTimeMs;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function isEntityHackableCarePackage( entity )
{
	if ( isdefined( entity.model ))
	{
		return entity.model == "wpn_t7_care_package_world";
	}
	else
	{
		return false;
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function isValidHackerToolTarget( ent, weapon, allowHacked ) // self == hacking player
{
	if ( !isdefined( ent ))
	{
		return false;
	}
	
	if ( self util::isUsingRemote() )
	{
		return false;
	}

	if ( self IsEMPJammed() )
	{
		return false;
	}

	if ( !( target_isTarget( ent ) || isdefined( ent.allowHackingAfterCloak ) &&  ent.allowHackingAfterCloak == true ) 
	    && !isEntityHackableWeaponObject( ent ) 
	    && !IsInArray( level.hackerToolTargets, ent ) )
	{
		return false;
	}

	if ( isEntityHackableWeaponObject( ent ))
	{
		if ( DistanceSquared( self.origin, ent.origin ) > ( weapon.lockOnMaxRange * weapon.lockOnMaxRange ) )
		{
			return false;
		}
	}

	if ( allowHacked == false && isEntityPreviouslyHacked( ent ) )
	{
		return false;
	}

	return true;
}


function isEntityPreviouslyHacked( entity ) 
{
	if ( IS_TRUE( entity.previouslyHacked ) )
	{
		return true;
	}
	
	return false;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function hackerSoftSightTest( weapon ) // self == player
{
	passed = true;
	lockOnTime = 0;
	
	if ( isdefined( self.hackerToolTarget ) )
	{
		lockOnTime = self getLockOnTime( self.hackerToolTarget, weapon );
	}

	if ( lockOnTime == 0 || self IsEMPJammed() )
	{
		self clearHackerTarget( weapon, false, false );
		passed = false;
	}
	else
	{
		if ( isWithinHackerToolReticle( self.hackerToolTarget, weapon ) && self heatseekingmissile::LockSightTest( self.hackerToolTarget ) ) 
		{
			self.hackerToolLostSightlineTime = 0;
		}
		else
		{
			if ( self.hackerToolLostSightlineTime == 0 )
			{
				// pause the progress bar
				self.hackerToolLostSightlineTime = getTime();
			}

			timePassed = GetTime() - self.hackerToolLostSightlineTime;
			lostLineOfSightTimeLimitMsec = level.hackerToolLostSightLimitMs;
			if ( isdefined( self.hackerToolTarget.killstreakHackLostLineOfSightLimitMs ) )
			{
				lostLineOfSightTimeLimitMsec = self.hackerToolTarget.killstreakHackLostLineOfSightLimitMs;
			}

			if ( timePassed >= lostLineOfSightTimeLimitMsec )
			{
				self clearHackerTarget( weapon, false, false );
				passed = false;
			}
		}
	}

	return passed;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function registerWithHackerTool( radius, hackTimeMs ) // self == some hackable entity
{
	self endon( "death" );

	if ( isdefined( radius ))
	{
		self.hackerToolRadius = radius;
	}
	else
	{
		self.hackerToolRadius = level.hackerToolLockOnRadius;
	}

	if ( isdefined( hackTimeMs ))
	{
		self.hackerToolTimeMs = hackTimeMs;
	}
	else
	{
		self.hackerToolTimeMs = level.hackerToolHackTimeMs;
	}

	self thread watchHackableEntityDeath();
	level.hackerToolTargets[ level.hackerToolTargets.size ] = self;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function watchHackableEntityDeath()
{
	self waittill( "death" );
	ArrayRemoveValue( level.hackerToolTargets, self );	
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function getHackerToolInnerRadius( target )
{
	radius = level.hackerToolLockOnRadius;

	if ( isEntityHackableCarePackage( target ))
	{
		/#assert( isdefined( target.hackerToolRadius ));#/
		radius = target.hackerToolRadius;
	}
	else if ( isEntityHackableWeaponObject( target ))
	{
		radius = getWeaponObjectHackerRadius( target );
	}
	else if ( isdefined( target.hackerToolInnerRadius ))
	{
		radius = target.hackerToolInnerRadius;
	}
	else if ( isdefined( target.hackerToolRadius ))
	{
		radius = target.hackerToolRadius;
	}

	return radius;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function getHackerToolOuterRadius( target )
{
	radius = level.hackerToolLockOnRadius;

	if ( isEntityHackableCarePackage( target ))
	{
		/#assert( isdefined( target.hackerToolRadius ));#/
		radius = target.hackerToolRadius;
	}
	else if ( isEntityHackableWeaponObject( target ))
	{
		radius = getWeaponObjectHackerRadius( target );
	}
	else if ( isdefined( target.hackerToolOuterRadius ))
	{
		radius = target.hackerToolOuterRadius;
	}
	else if ( isdefined( target.hackerToolRadius ))
	{
		radius = target.hackerToolRadius;
	}

	return radius;
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function getHackTime( target ) // self == player
{
	time = 500;

	if ( isEntityHackableCarePackage( target )) 
	{
		/#assert( isdefined( target.hackerToolTimeMs ));#/
		//time = target.hackerToolTimeMs;

		if ( isdefined( target.owner ) && ( target.owner == self ))
		{
			time = level.carePackageOwnerHackerToolTimeMs;
		}
		else if ( isdefined(target.owner) && (target.owner.team == self.team) )
		{
			time = level.carePackageFriendlyHackerToolTimeMs;
		}
		else
		{
			time = level.carePackageHackerToolTimeMs;
		}
	}
	else if ( isEntityHackableWeaponObject( target ))
	{
		time = getWeaponObjectHackTimeMs( target );
	}
	else if ( isdefined( target.hackerToolInnerTimeMs ))
	{
		time = target.hackerToolInnerTimeMs;
	}
	else
	{
		// vehicles/targets from the target array
		time = level.vehicleHackerToolTimeMs;
	}

	return time;
}

function getHackOuterTime( target ) // self == player
{
	time = 500;

	if ( isEntityHackableCarePackage( target )) 
	{
		/#assert( isdefined( target.hackerToolTimeMs ));#/
		//time = target.hackerToolTimeMs;

		if ( isdefined( target.owner ) && ( target.owner == self ))
		{
			time = level.carePackageOwnerHackerToolTimeMs;
		}
		else if ( isdefined(target.owner) && (target.owner.team == self.team) )
		{
			time = level.carePackageFriendlyHackerToolTimeMs;
		}
		else
		{
			time = level.carePackageHackerToolTimeMs;
		}
	}
	else if ( isEntityHackableWeaponObject( target ))
	{
		time = getWeaponObjectHackTimeMs( target );
	}
	else if ( isdefined( target.hackerToolOuterTimeMs ))
	{
		time = target.hackerToolOuterTimeMs;
	}
	else
	{
		// vehicles/targets from the target array
		time = level.vehicleHackerToolTimeMs;
	}

	return time;
}


function getLockOnTime( target, weapon ) // self is the player, weapon is the hacker tool
{
	lockLengthMs = self getHackTime( self.hackerToolTarget );
	
	if ( lockLengthMs == 0 )
	{
		return 0;
	}
	
	lockOnSpeed = weapon.lockOnSpeed;	
			
	if ( lockOnSpeed <= 0 )
	{
		lockOnSpeed = 1000;	
	}
			
	return 	lockLengthMs / lockOnSpeed;
}

/#
function tunables()
{
	while(1)
	{
		level.hackerToolLostSightLimitMs = GetDvarInt( "scr_hackerToolLostSightLimitMs", 1000 );
		level.hackerToolLockOnRadius = GetDvarFloat( "scr_hackerToolLockOnRadius", 20 );
		level.hackerToolLockOnFOV = GetDvarInt( "scr_hackerToolLockOnFOV", 65 );
		
		wait(1.0);
	}
}
#/