#using scripts\shared\array_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\bots\_bot.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\bots\_bot;
#using scripts\shared\bots\bot_buttons;

#define EXPLOSION_RADIUS_FRAG	256
#define EXPLOSION_RADIUS_FLASH	650
	
#namespace bot_combat;

// Combat Think
//========================================

function combat_think()
{	
	if ( self has_threat() )
	{
		// Assume the 'death' notification is always going to come up for threats
		if ( self threat_is_alive() )
		{
			self update_threat();
		}
		else
		{
			self thread [[level.botThreatDead]]();
		}
	}
	
	if ( !self has_threat() && !self get_new_threat() )
	{
		return;
	}
	else if ( self has_threat() )
	{
		if ( !self threat_visible() || self.bot.threat.lastDistanceSq > level.botSettings.threatRadiusMaxSq )
		{
			self get_new_threat( level.botSettings.threatRadiusMin );
		}
	}
	
	if ( self threat_visible() )
	{
		self thread [[level.botUpdateThreatGoal]]();
		self thread [[level.botThreatEngage]]();
	}
	else
	{
		self thread [[level.botThreatLost]]();
	}
}


// Default Combat Queries
//========================================

function is_alive( entity )
{
	// TODO: Add killstreak checks for mp
	return IsAlive( entity );
}

function get_bot_threats( maxDistance )
{
	DEFAULT( maxDistance, 0 );
	
	return self BotGetThreats( maxDistance );
}

function get_ai_threats()
{
	return GetAITeamArray( "axis" );
}

function ignore_none( entity )
{
	return false;
}

function ignore_non_sentient( entity )
{
	return !IsSentient( entity );
}

// Threat CRUD
//========================================

function has_threat()
{
	return ( isdefined( self.bot.threat.entity ) );
}

function threat_visible()
{
	return self has_threat() && self.bot.threat.visible;
}

function threat_is_alive()
{
	if ( !self has_threat() )
	{
		return false;
	}
	
	if ( isdefined( level.botThreatIsAlive) )
	{
		return self [[level.botThreatIsAlive]]( self.bot.threat.entity );
	}
	
	return IsAlive( self.bot.threat.entity );
}

function set_threat( entity )
{
	self.bot.threat.entity 			= entity;
	self.bot.threat.aimOffset 		= self get_aim_offset( entity );
	
	self update_threat( true );
}

function clear_threat()
{
	self.bot.threat.entity = undefined;
	self clear_threat_aim();
	self BotLookForward();
/*	
	self.bot.threat.lastPosition	= ( 0, 0, 0 );
	self.bot.threat.lastVisibleTime	= 0;
	self.bot.threat.lastUpdateTime	= 0;
*/
}

function update_threat( newThreat )
{	
	if ( IS_TRUE( newThreat ) )
	{
		self.bot.threat.wasVisible = false;
		self clear_threat_aim();
	}
	else
	{
		self.bot.threat.wasVisible = self.bot.threat.visible;
	}
	
	velocity = self.bot.threat.entity GetVelocity();
	distanceSq = DistanceSquared( self GetEye(), self.bot.threat.entity.origin );
	predictionTime = VAL( level.botSettings.thinkInterval, 0.05 );
	predictedPosition = self.bot.threat.entity.origin + ( velocity * predictionTime );
	aimPoint = predictedPosition + self.bot.threat.aimOffset;
	
	dot = self bot::fwd_dot( aimPoint );
	fov = self BotGetFov();
	
	if ( IS_TRUE( newThreat ) )
	{
		self.bot.threat.visible = true;
	}
	else if ( dot < fov || !self BotSightTrace( self.bot.threat.entity ) )
	{
		// TODO: Be able to pass the aimPoint into the trace
		self.bot.threat.visible = false;
		return;
	}

	self.bot.threat.visible = true;
	self.bot.threat.lastVisibleTime = GetTime();
	self.bot.threat.lastDistanceSq = distanceSq;
	self.bot.threat.lastVelocity = velocity;
	self.bot.threat.lastPosition = predictedPosition;
	self.bot.threat.aimPoint = aimPoint;
	self.bot.threat.dot = dot;
	
	weapon = self GetCurrentWeapon();
	
	weaponRange = weapon_range( weapon );
	self.bot.threat.inRange = distanceSq < ( weaponRange * weaponRange );
	
	weaponRangeClose = weapon_range_close( weapon );
	self.bot.threat.inCloseRange = distanceSq < ( weaponRangeClose * weaponRangeClose );
}


// Get Threats
//========================================

function get_new_threat( maxDistance )
{	
	// TODO: New threat Difficult delay
	entity = self get_greatest_threat( maxDistance );
	
	if ( isdefined( entity ) && entity !== self.bot.threat.entity )
	{
		self set_threat( entity );
		return true;
	}
	
	return false;
}

function get_greatest_threat( maxDistance )
{	
	// TODO: factor in current threat?
	// TODO: Factor in damage

	threats = self [[level.botGetThreats]]( maxDistance );
	
	if ( !isdefined( threats ) )
	{
		return undefined;
	}
	
	foreach( entity in threats )
	{
		if ( self [[level.botIgnoreThreat]]( entity ) )
		{
			continue;
		}
		
		return entity;
	}
	
	return undefined;
}


// Threat Engagement
//========================================

function engage_threat()
{
	if ( !self.bot.threat.wasVisible &&
	     self.bot.threat.visible &&
	     !self IsThrowingGrenade() &&
	     !self FragButtonPressed() &&
	     !self SecondaryOffhandButtonPressed() &&
	     !self IsSwitchingWeapons() )
	{
		visibleRoll = RandomInt( 100 );
		
		rollWeight = VAL( level.botSettings.lethalWeight, 0 );
		if ( visibleRoll < rollWeight &&
		     self.bot.threat.lastDistanceSq >= level.botSettings.lethalDistanceMinSq && 
		     self.bot.threat.lastDistanceSq <= level.botSettings.lethalDistanceMaxSq &&
		     self GetWeaponAmmoStock( self.grenadeTypePrimary ) )
		{
			self clear_threat_aim();
			self throw_grenade( self.grenadeTypePrimary, self.bot.threat.lastPosition );
			return;
		}
		visibleRoll -= rollWeight;
		
		rollWeight = VAL( level.botSettings.tacticalWeight, 0 );
		if ( visibleRoll >= 0 &&
		     visibleRoll < rollWeight &&
 		     self.bot.threat.lastDistanceSq >= level.botSettings.tacticalDistanceMinSq && 
		     self.bot.threat.lastDistanceSq <= level.botSettings.tacticalDistanceMaxSq &&
		     self GetWeaponAmmoStock( self.grenadeTypeSecondary ) )
		{
			self clear_threat_aim();
			self throw_grenade( self.grenadeTypeSecondary, self.bot.threat.lastPosition );
			return;
		}
		//visbileRoll -= rollWeight;
		// TODO: Fancier hero gadget stuff
		
		// Retarget
		self.bot.threat.aimOffset = self get_aim_offset( self.bot.threat.entity );
	}
	
	if ( self FragButtonPressed() )
	{
		self throw_grenade( self.grenadeTypePrimary, self.bot.threat.lastPosition );
		return;
	}
	else if ( self SecondaryOffhandButtonPressed() )
	{
		self throw_grenade( self.grenadeTypeSecondary, self.bot.threat.lastPosition );
		return;
	}
		
	self update_weapon_aim();
	
	if ( self IsReloading() ||
	     self IsSwitchingWeapons() || 
	     self IsThrowingGrenade() ||
	     self FragButtonPressed() ||
	     self SecondaryOffhandButtonPressed() ||
	     self IsMeleeing() )
	{
		return;
	}
	
	if ( melee_attack() )
	{
		return;
	}
	
	self update_weapon_ads();
	self fire_weapon();
}

// Combat Movment
//========================================
	
function update_threat_goal()
{
	if ( self BotUnderManualControl() )
	{
		return;
	}
	
	if ( self BotGoalSet() &&
	     ( self.bot.threat.wasVisible || !self.bot.threat.visible ) )
	{
		return;
	}

	radius = get_threat_goal_radius();
	radiusSq = radius * radius;
	
	threatDistSq = Distance2DSquared( self.origin, self.bot.threat.lastPosition );
	
	if ( threatDistSq < radiusSq || !self BotSetGoal( self.bot.threat.lastPosition, radius ) )
	{
		self combat_strafe();
	}
}

function get_threat_goal_radius( )
{	
	weapon = self GetCurrentWeapon();
	
	if ( RandomInt( 100 ) < 10 ||
		 weapon.weapClass == "melee" ||
		 ( !self GetWeaponAmmoClip( weapon ) && !self GetWeaponAmmoStock( weapon ) ) )
	{
		return level.botSettings.meleeRange;
	}
	
	return RandomIntRange( level.botSettings.threatRadiusMin, level.botSettings.threatRadiusMax );
}

// Attack
//========================================

function fire_weapon()
{		
	if ( !self.bot.threat.inRange )
	{
		return;
	}
	
	weapon = self GetCurrentWeapon();
			
	if ( weapon == level.weaponNone ||
	     !self GetWeaponAmmoClip( weapon ) ||
	     self.bot.threat.dot < weapon_fire_dot( weapon ) )
	{
		return;
	}
	
	if ( weapon.fireType == "Single Shot" ||
	     weapon.fireType == "Burst" ||
	     weapon.fireType == "Charge Shot" )
	{
		if ( self AttackButtonPressed() )
		{
			return;
		}
	}

	self bot::press_attack_button();
	
	if ( weapon.isDualWield )
	{
		self bot::press_throw_button();
	}
}

function melee_attack()
{
	// TODO: Check for shotgun/ammo and armblades
	
	if ( self.bot.threat.dot < level.botSettings.meleeDot )
	{
		return false;
	}
	
	if ( DistanceSquared( self.origin, self.bot.threat.lastPosition ) > level.botSettings.meleeRangeSq  )
	{		
		return false;
	}
	
	self bot::tap_melee_button();
	
	return true;
}


// Threat Chase
//========================================

function chase_threat()
{
	if ( self BotUnderManualControl() )
	{
		return;
	}
	
	// TODO: factor in HasPerk( "specialty_tracker" ) and threat HasPerk( "specialty_trackerjammer" )
	
	if ( self.bot.threat.wasVisible && !self.bot.threat.visible )
	{
		self clear_threat_aim();
		self BotSetGoal( self.bot.threat.lastPosition );
		self bot::sprint_to_goal();
		
		return;
	}
	
	if ( self.bot.threat.lastVisibleTime + VAL( level.botSettings.chaseThreatTime, 0 ) < GetTime() )
	{
		// Give up looking for this threat
		self clear_threat();
		
		return;
	}
	
	if ( !self BotGoalSet() )
	{
		self bot::navmesh_wander( self.bot.threat.lastVelocity, self.botSettings.chaseWanderMin, self.botSettings.chaseWanderMax, self.botSettings.chaseWanderSpacing, self.botSettings.chaseWanderFwdDot );
		self clear_threat();
		//self bot::sprint_to_goal();	
	}
}

// Aim
//========================================

function get_aim_offset( entity )
{
	if ( IsSentient( entity ) && RandomInt( 100 ) < VAL( level.botSettings.headshotWeight, 0 ) )
	{
		return entity GetEye() - entity.origin;
	}
	
	return entity GetCentroid() - entity.origin;
}

function update_weapon_aim()
{	
	if ( !isdefined( self.bot.threat.aimStartTime ) )
	{
		self start_threat_aim();
	}

	aimTime = GetTime() - self.bot.threat.aimStartTime;	
	
	if ( aimTime < 0 )
	{
		return;
	}
	
	if ( aimTime >= self.bot.threat.aimTime || !isdefined( self.bot.threat.aimError ) )
	{
		self BotLookAtPoint( self.bot.threat.aimPoint );
		return;
	}
	
	eyePoint = self GetEye();
	threatAngles = VectorToAngles( self.bot.threat.aimPoint - eyePoint );
	initialAngles = threatAngles + self.bot.threat.aimError;
	
	currAngles = VectorLerp( initialAngles, threatAngles, aimTime / self.bot.threat.aimTime );
	playerAngles = self GetPlayerAngles();
	self BotSetLookAngles( AnglesToForward( currAngles ) );
}

function start_threat_aim()
{
	self.bot.threat.aimStartTime = GetTime() + VAL( level.botSettings.aimDelay, 0 ) * 1000;
	self.bot.threat.aimTime = VAL( level.botSettings.aimTime, 0 ) * 1000;
	
	pitchError = angleError( VAL( level.botSettings.aimErrorMinPitch, 0 ),  VAL( level.botSettings.aimErrorMaxPitch, 0 ) );
	yawError = angleError( VAL( level.botSettings.aimErrorMinYaw, 0 ), VAL( level.botSettings.aimErrorMaxYaw, 0 ) );
	
	self.bot.threat.aimError = ( pitchError, yawError, 0 );
}

function angleError( angleMin, angleMax )
{
	angle = angleMax - angleMin;
	angle *= RandomFloatRange( -1, 1 );
	
	if ( angle < 0 )
	{
		angle -= angleMin;
	}
	else
	{
		angle += angleMin;
	}
	
	return angle;
}

function clear_threat_aim()
{
	if ( !isdefined( self.bot.threat.aimStartTime ) )
	{
		return;
	}
	
	self.bot.threat.aimStartTime = undefined;
	self.bot.threat.aimTime = undefined;
	self.bot.threat.aimError = undefined;
}

// Pre Combat
//========================================

function bot_pre_combat()
{
	if ( self has_threat() )
	{	
		return;
	}
	
	// Look for whoever is shooting at the bot
	if ( isdefined( self.bot.damage.time ) && self.bot.damage.time + 1500 > GetTime() )
	{	
		if ( self has_threat() && self.bot.damage.time > self.bot.threat.lastVisibleTime ) 
		{
			self clear_threat();
		}
		
		self bot::navmesh_wander( self.bot.damage.attackDir, level.botSettings.damageWanderMin, level.botSettings.damageWanderMax, level.botSettings.damageWanderSpacing, level.botSettings.damageWanderFwdDot );
		self bot::end_sprint_to_goal(); 
		self bot_combat::clear_damage();
	}
}

// Post Combat
//========================================

function bot_post_combat()
{
	
}

// Weapon Stuff
//========================================

function update_weapon_ads()
{	
	if ( !self.bot.threat.inRange || self.bot.threat.inCloseRange )
	{
		return;
	}
	
	weapon = self GetCurrentWeapon();
	
	if ( weapon == level.weaponNone ||
	     weapon.isDualWield ||
	     weapon.weapClass == "melee" ||
	     self GetWeaponAmmoClip( weapon ) <= 0 )
	{
		return;
	}
	
	if ( self.bot.threat.dot < weapon_ads_dot( weapon ) )
	{
		return;
	}
	
	// TODO: Set ADS time
	self bot::press_ads_button();
}

function weapon_ads_dot( weapon )
{
	if ( weapon.isSniperWeapon )
	{
		return level.botSettings.sniperAds;
	}
	else if ( weapon.isRocketLauncher )
	{
		return level.botSettings.rocketLauncherAds;
	}
	
	switch( weapon.weapClass )
	{
		case "mg":
			return level.botSettings.mgAds;
		case "smg":
			return level.botSettings.smgAds;
		case "spread":
			return level.botSettings.spreadAds;
		case "pistol":
			return level.botSettings.pistolAds;
		case "rifle":
			return level.botSettings.rifleAds;
	}

	return level.botSettings.defaultAds;
}

function weapon_fire_dot( weapon )
{
	if ( weapon.isSniperWeapon )
	{
		return level.botSettings.sniperFire;
	}
	else if ( weapon.isRocketLauncher )
	{
		return level.botSettings.rocketLauncherFire;
	}
	
	switch( weapon.weapClass )
	{
		case "mg":
			return level.botSettings.mgFire;
		case "smg":
			return level.botSettings.smgFire;
		case "spread":
			return level.botSettings.spreadFire;
		case "pistol":
			return level.botSettings.pistolFire;
		case "rifle":
			return level.botSettings.rifleFire;
	}

	return level.botSettings.defaultFire;
}

function weapon_range( weapon )
{
	if ( weapon.isSniperWeapon )
	{
		return level.botSettings.sniperRange;
	}
	else if ( weapon.isRocketLauncher )
	{
		return level.botSettings.rocketLauncherRange;
	}
	
	switch( weapon.weapClass )
	{
		case "mg":
			return level.botSettings.mgRange;
		case "smg":
			return level.botSettings.smgRange;
		case "spread":
			return level.botSettings.spreadRange;
		case "pistol":
			return level.botSettings.pistolRange;
		case "rifle":
			return level.botSettings.rifleRange;
	}

	return level.botSettings.defaultRange;
}

function weapon_range_close( weapon )
{
	if ( weapon.isSniperWeapon )
	{
		return level.botSettings.sniperRangeClose;
	}
	else if ( weapon.isRocketLauncher )
	{
		return level.botSettings.rocketLauncherRangeClose;
	}
	
	switch( weapon.weapClass )
	{
		case "mg":
			return level.botSettings.mgRangeClose;
		case "smg":
			return level.botSettings.smgRangeClose;
		case "spread":
			return level.botSettings.spreadRangeClose;
		case "pistol":
			return level.botSettings.pistolRangeClose;
		case "rifle":
			return level.botSettings.rifleRangeClose;
	}

	return level.botSettings.defaultRangeClose;
}

function switch_weapon()
{
	currentWeapon = self GetCurrentWeapon();

	if ( self IsSwitchingWeapons() ||
	     currentWeapon.isHeroWeapon ||
	     currentWeapon.isItem )
	{
		return false;
	}
	
	weapon = bot::get_ready_gadget();
	
	if ( weapon != level.weaponNone )
	{
		if ( !isdefined( level.enemyEmpActive ) || !self [[level.enemyEmpActive]]() )
		{
			self bot::activate_hero_gadget( weapon );
			return true;
		}
	}
	
	weapons = self GetWeaponsListPrimaries();
	
	// Switch away from a 'sidearm'
	if ( currentWeapon == level.weaponNone || 
	     currentWeapon.weapClass == "melee" ||
	     currentWeapon.weapClass == "rocketLauncher" ||
	     currentWeapon.weapClass == "pistol" )
	{
		foreach( weapon in weapons )
		{
			if ( weapon == currentWeapon )
			{
				continue;
			}
			
			if ( self GetWeaponAmmoClip( weapon ) || self GetWeaponAmmoStock( weapon ) )
			{
				self BotSwitchToWeapon( weapon );
				return true;
			}
		}
		
		return false;
	}
	    
	currentAmmoStock = self GetWeaponAmmoStock( currentWeapon );
	if ( currentAmmoStock )
	{
		return false;
	}
	
	switchFrac = 0.3;
	
	currentClipFrac = self weapon_clip_frac( currentWeapon );
	if ( currentClipFrac > switchFrac )
	{
		return false;
	}
	
	foreach( weapon in weapons )
	{
		if ( self GetWeaponAmmoStock( weapon ) || self weapon_clip_frac( weapon ) > switchFrac )
		{
			self BotSwitchToWeapon( weapon );
			return true;
		}
	}
	
	return false;
}

function threat_switch_weapon()
{
	currentWeapon = self GetCurrentWeapon();

	if ( self IsSwitchingWeapons() ||
	     self GetWeaponAmmoClip( currentWeapon ) ||
	     currentWeapon.isItem )
	{
		return;
	}
	
	currentAmmoStock = self GetWeaponAmmoStock( currentWeapon );
	weapons = self GetWeaponsListPrimaries();
	
	foreach( weapon in weapons )
	{
		// TODO: Check if the target is a scorestreak laong with .requireLockOnToFire
		if ( weapon == currentWeapon || weapon.requireLockOnToFire )
		{
			continue;
		}
		
		if ( weapon.weapClass == "melee" )
		{
			// if we have ammo, low chance to switch to melee weapon
			if ( currentAmmoStock && RandomIntRange( 0, 100 ) < 75 )
			{
				continue;
			}
		}
		else
		{	
			// Dont' switch if we'd have to reload the new weapon, and we can reload this one
			if( !self GetWeaponAmmoClip( weapon ) && currentAmmoStock )
			{
				continue;
			}
			
			weaponAmmoStock = self GetWeaponAmmoStock( weapon );
			
			// Don't switch if neither has any ammo
			if ( !currentAmmoStock && !weaponAmmoStock )
			{
				continue;
			}
			
			// Maybe don't switch if it's not to a pistol
			if ( weapon.weapClass != "pistol" && RandomIntRange( 0, 100 ) < 75 )
			{
				continue;
			}
		}
		
		self BotSwitchToWeapon( weapon );		
	}
}

function reload_weapon()
{
	weapon = self GetCurrentWeapon();
	
	if ( !self GetWeaponAmmoStock( weapon ) )
	{
		return false;
	}
	
	reloadFrac = 0.5;

	if ( weapon.weapClass == "mg" )
	{
		reloadFrac = 0.25;
	}

	if ( self weapon_clip_frac( weapon ) < reloadFrac )
	{
		self bot::tap_reload_button();
		return true;
	}
	
	return false;
}

function weapon_clip_frac( weapon )
{
	if ( weapon.clipSize <= 0 )
	{
		return 1;
	}
	
	clipAmmo = self GetWeaponAmmoClip( weapon );

	return ( clipAmmo /  weapon.clipSize );
}

// Grenades
//========================================


function throw_grenade( weapon, target )
{
	if ( !isdefined( self.bot.threat.aimStartTime ) )
	{
		self aim_grenade( weapon, target );
		self press_grenade_button( weapon );
		return;
	}
	
	if ( self.bot.threat.aimStartTime + self.bot.threat.aimTime > GetTime() )
	{
		return;
	}
	
	if ( self will_hit_target( weapon, target ) )
	{
		return;
	}
	
	self press_grenade_button( weapon );
}

function press_grenade_button( weapon )
{
	if ( weapon == self.grenadeTypePrimary )
	{
		self bot::press_frag_button();
	}
	else if ( weapon == self.grenadeTypeSecondary )
	{
		self bot::press_offhand_button();
	}
}

function aim_grenade( weapon, target )
{
	// Just look above the target some
	aimPeak = target + ( 0, 0, 100 );
	
	self.bot.threat.aimStartTime = GetTime();
	
	self.bot.threat.aimTime = 1500;
	
	self BotSetLookAnglesFromPoint( aimPeak );
}

function will_hit_target( weapon, target )
{
	velocity = get_throw_velocity( weapon );
	
	throwOrigin = self GetEye();
	
	xyDist = Distance2D( throwOrigin, target );
	xySpeed = Distance2D( velocity, ( 0, 0, 0 ) );
	
	t = xyDist / xySpeed;
	
	gravity = -GetDvarFloat( "bg_gravity" );
	
	tHeight = throwOrigin[2] + velocity[2] * t + ( gravity * t * t * .5 );
	
	return Abs( tHeight - target[2] ) < 20;
}

function get_throw_velocity( weapon )
{
	angles = self GetPlayerAngles();
	forward = AnglesToForward( angles );

	// Precomputed velocity of most grenades
	return forward * 928;
	
/*	TODO: These weapon values aren't actually accessable
	velocity = forward * weapon.projectileSpeed;
	
	velocity += AnglesToUp( angles ) * weapon.projectileSpeedRelativeUp;
	
	velocity = ( velocity[0], velocity[1], velocity[2] + weapon.projectileSpeedUp );
	
	if ( weapon.projectileSpeedForward )
	{
		xyForward = VectorNormalize( ( forward[0], forward[1], 0 ) );
		velocity += xyForward * weapon.projectileSpeedForward;
	}
	
	return velocity;
*/
}

function get_lethal_grenade()
{
	weaponsList = self GetWeaponsList();
	
	foreach( weapon in weaponsList )
	{
		if ( weapon.type == "grenade" && self GetWeaponAmmoStock( weapon ) )
		{
			return weapon;
		}
	}
	
	return level.weaponNone;
}


// Damage
//========================================

function wait_damage_loop()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	while( 1 )
	{
		self waittill( "damage", damage, attacker, direction, point, mod, unused1, unused2, unused3, weapon, flags, inflictor );
		
		self.bot.damage.entity = attacker;
		self.bot.damage.amount = damage;
		self.bot.damage.attackDir = VectorNormalize( attacker.origin - self.origin );
		self.bot.damage.weapon = weapon;
		self.bot.damage.mod = mod;
		self.bot.damage.time = GetTime();

		self thread [[level.onBotDamage]]();
	}
}

function clear_damage()
{
	self.bot.damage.entity = undefined;
	self.bot.damage.amount = undefined;
	self.bot.damage.direction = undefined;
	self.bot.damage.weapon = undefined;
	self.bot.damage.mod = undefined;
	self.bot.damage.time = undefined;
}


// Movement
//========================================
	
function combat_strafe( radiusMin, radiusMax, spacing, sideDotMin, sideDotMax )
{	
	DEFAULT( radiusMin, VAL( level.botSettings.strafeMin, 0 ) );
	DEFAULT( radiusMax, VAL( level.botSettings.strafeMax, 0 ) );
	DEFAULT( spacing, VAL( level.botSettings.strafeSpacing, 0 ) );
	DEFAULT( sideDotMin, VAL( level.botSettings.strafeSideDotMin, 0 ) );
	DEFAULT( sideDotMax, VAL( level.botSettings.strafeSideDotMax, 0 ) );
	
	fwd = AnglesToForward( self.angles );
	
	queryResult = PositionQuery_Source_Navigation( self.origin, radiusMin, radiusMax, 64, spacing, self );	
	
	best_point = undefined;
	
	foreach ( point in queryResult.data )
	{
		moveDir = VectorNormalize( point.origin - self.origin );
		dot = VectorDot( moveDir, fwd );
		
		// Don't even consider points outside of the strafe cones
		if ( dot >= sideDotMin && dot <= sideDotMax )
		{
			point.score = MapFloat( radiusMin, radiusMax, 0, 50, point.distToOrigin2D );
			point.score += randomFloatRange( 0, 50 );
		}
		if ( !isdefined( best_point ) || point.score > best_point.score )
		{
			best_point = point;
		}
	}
	
	if( isdefined( best_point ) )
	{
		self BotSetGoal( best_point.origin );
		self bot::end_sprint_to_goal();
	}
}