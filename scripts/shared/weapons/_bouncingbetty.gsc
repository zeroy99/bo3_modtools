#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define BETTY_DESTROYED_DAMAGE_RADIUS 128
#define BETTY_DESTROYED_DAMAGE_MAX 110
#define BETTY_DESTROYED_DAMAGE_MIN 10
	
#precache( "fx", "weapon/fx_betty_exp_destroyed" );
#precache( "fx", "weapon/fx_betty_light_blue" );
#precache( "fx", "weapon/fx_betty_light_orng" );
	
#precache( "model", "wpn_t7_grenade_incendiary_world" );


#using_animtree ( "bouncing_betty" );


#namespace bouncingbetty;

function init_shared()
{
	level.bettyDestroyedFX = "weapon/fx_betty_exp_destroyed";

	level._effect["fx_betty_friendly_light"] = "weapon/fx_betty_light_blue";
	level._effect["fx_betty_enemy_light"] = "weapon/fx_betty_light_orng";

	level.bettyMinDist = 20;
	level.bettyStunTime = 1;
	
	bettyExplodeAnim = %o_spider_mine_detonate;
	bettyDeployAnim = %o_spider_mine_deploy;

	level.bettyRadius = getDvarInt( "betty_detect_radius", 180 );
	level.bettyActivationDelay = getDvarFloat( "betty_activation_delay", 1 );
	level.bettyGracePeriod = getDvarFloat( "betty_grace_period", 0.0 );
	level.bettyDamageRadius = getDvarInt( "betty_damage_radius", 180 );
	level.bettyDamageMax = getDvarInt( "betty_damage_max", 180 );
	level.bettyDamageMin = getDvarInt( "betty_damage_min", 70 );
	level.bettyDamageHeight = getDvarInt( "betty_damage_cylinder_height", 200 );

	level.bettyJumpHeight = getDvarInt( "betty_jump_height_onground", 55 );
	level.bettyJumpHeightWall = getDvarInt( "betty_jump_height_wall", 20 );
	level.bettyJumpHeightWallAngle = getDvarInt( "betty_onground_angle_threshold", 30 );
	level.bettyJumpHeightWallAngleCos = cos( level.bettyJumpHeightWallAngle ); 
	level.bettyJumpTime = getDvarFloat( "betty_jump_time", 0.7 );
	
	level.bettyBombletSpawnDistance = 20;
	level.bettyBombletCount = 4;
	
	level thread register();
	
	callback::add_weapon_watcher( &createBouncingBettyWatcher );
}

function register()
{
	clientfield::register( "missile", "bouncingbetty_state", VERSION_SHIP, 2, "int" );
	clientfield::register( "scriptmover", "bouncingbetty_state", VERSION_SHIP, 2, "int" );
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function createBouncingBettyWatcher() // self == player
{
	watcher = self weaponobjects::createProximityWeaponObjectWatcher( "bouncingbetty", self.team );
	
	watcher.onSpawn =&onSpawnBouncingBetty;
	watcher.watchForFire = true;
	watcher.onDetonateCallback =&bouncingBettyDetonate;
	//Eckert - playing sound later
	//watcher.activateSound = "fly_betty_exp";
	watcher.activateSound = "wpn_betty_alert";
	watcher.hackable = true;
	watcher.hackerToolRadius = level.equipmentHackerToolRadius;
	watcher.hackerToolTimeMs = level.equipmentHackerToolTimeMs;
	watcher.ownerGetsAssist = true;
	watcher.ignoreDirection = true;
	watcher.immediateDetonation = true;
	watcher.immunespecialty = "specialty_immunetriggerbetty";
	
	watcher.detectionMinDist = level.bettyMinDist;
	watcher.detectionGracePeriod = level.bettyGracePeriod;
	watcher.detonateRadius = level.bettyRadius;
	watcher.onFizzleOut = &bouncingbetty::onBouncingBettyFizzleOut;
	
	watcher.stun =&weaponobjects::weaponStun;
	watcher.stunTime = level.bettyStunTime;

	watcher.activationDelay = level.bettyActivationDelay;
}

function onBouncingBettyFizzleOut()
{
	if ( isdefined( self.mineMover ) )
	{
		if ( isdefined( self.mineMover.killcament ) )	
		{
			self.mineMover.killcament delete();
		}
		self.mineMover delete();
	}
	self delete();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function onSpawnBouncingBetty( watcher, owner ) // self == betty ent
{
	weaponobjects::onSpawnProximityWeaponObject( watcher, owner );
	self.originalOwner = owner;
	self thread spawnMineMover();
	self trackOnOwner( owner );
	self thread trackUsedStatOnDeath();
	self thread doNoTrackUsedStatOnPickup();
	self thread trackUsedOnHack();
}

function trackUsedStatOnDeath()
{
	self endon( "do_not_track_used" );
	self waittill( "death" );
	waittillframeend; // to compensate for timiing issues with notifies and death
	if ( isdefined( self.owner ) )
	{
		self.owner trackBouncingBettyAsUsed(); // since betties can be picked up or hacked, we track them as used on death
	}
	self notify( "end_doNoTrackUsedOnPickup" );
	self notify( "end_doNoTrackUsedOnHacked" );
}

function doNoTrackUsedStatOnPickup() // self == betty ent
{
	self endon( "end_doNoTrackUsedOnPickup" );
	self waittill( "picked_up" );
	self notify( "do_not_track_used" );
}

function trackUsedOnHack() // self == betty ent
{
	self endon( "end_doNoTrackUsedOnHacked" );
	self waittill( "hacked" );
	self.originalOwner trackBouncingBettyAsUsed(); // since betties can be picked up or hacked, we track them as used on hack too
	self notify( "do_not_track_used" ); // remove old one as it was hacked
}

function trackBouncingBettyAsUsed()
{
	if ( IsPlayer( self ) )
	{
		self AddWeaponStat( GetWeapon( "bouncingbetty" ), "used", 1 );
	}
}

function trackOnOwner( owner )
{
	if ( level.trackBouncingBettiesOnOwner === true )
	{
		if ( !isdefined( owner ) )
			return;
		
		if ( !isdefined( owner.activeBouncingBetties ) )
		{
			owner.activeBouncingBetties = [];
		}
		else
		{
			ArrayRemoveValue( owner.activeBouncingBetties, undefined );
		}

		owner.activeBouncingBetties[ owner.activeBouncingBetties.size ] = self;
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function spawnMineMover() // self == betty ent
{
	self endon( "death" );
	self util::waitTillNotMoving();
	self clientfield::set( "bouncingbetty_state", BOUNCINGBETTY_DEPLOYING );

	self UseAnimTree( #animtree );
	self SetAnim( %o_spider_mine_deploy, 1.0, 0.0, 1.0 );

	mineMover = spawn( "script_model", self.origin );
	mineMover.angles = self.angles;
	mineMover SetModel( "tag_origin" );
	mineMover.owner = self.owner;
	mineUp = AnglesToUp( mineMover.angles );
	z_offset = GetDvarFloat( "scr_bouncing_betty_killcam_offset", 18.0 );
	mineMover.killCamOffset = VectorScale( mineUp, z_offset );
	mineMover.weapon = self.weapon;
	mineMover playsound ("wpn_betty_arm");

	killcamEnt = spawn( "script_model", mineMover.origin + mineMover.killCamOffset );
	killcamEnt.angles = ( 0,0,0 );
	killcamEnt SetModel( "tag_origin" );
	killcamEnt SetWeapon( self.weapon );

	mineMover.killcamEnt = killcamEnt;
	
	self.mineMover = mineMover;

	self thread killMineMoverOnPickup();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function killMineMoverOnPickup() // self == betty ent
{
	self.mineMover endon( "death" );

	self util::waittill_any( "picked_up", "hacked" );
	
	self killMineMover();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function killMineMover() // self == betty ent
{
	if ( isdefined( self.mineMover ))
	{
		if ( isdefined( self.mineMover.killcamEnt ) )
		{
			self.mineMover.killcamEnt delete();
		}
		self.mineMover delete();
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function bouncingBettyDetonate( attacker, weapon, target ) // self == betty
{
	if ( IsDefined( weapon ) && weapon.isValid )
	{
		self.destroyedBy = attacker;
		if ( isdefined( attacker ) )
		{
			if ( self.owner util::IsEnemyPlayer( attacker ) )
			{
				attacker challenges::destroyedExplosive( weapon );
				scoreevents::processScoreEvent( "destroyed_bouncingbetty", attacker, self.owner, weapon );
			}
		}

		self bouncingBettyDestroyed();
	}
	else if ( isdefined( self.mineMover ))
	{
		self.mineMover.ignore_team_kills = true;
		self.mineMover SetModel( self.model );
		self.mineMover thread bouncingBettyJumpAndExplode();
		self delete();
	}
	else
	{
		// tagTMR<NOTE>: special case where betty hasn't settled yet but something has triggered a detonate
		// i.e. the moving platforms doors on drone, etc
		self bouncingBettyDestroyed();
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function bouncingBettyDestroyed(  ) // self == betty
{
	PlayFX( level.bettyDestroyedFX, self.origin );
	PlaySoundAtPosition ( "dst_equipment_destroy", self.origin );
	
	if ( isdefined( self.trigger ) )
	{
		self.trigger delete();
	}

	self killMineMover();

	self RadiusDamage( self.origin, BETTY_DESTROYED_DAMAGE_RADIUS, BETTY_DESTROYED_DAMAGE_MAX, BETTY_DESTROYED_DAMAGE_MIN, self.owner, "MOD_EXPLOSIVE", self.weapon );

	self delete();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function bouncingBettyJumpAndExplode() // self == script mover spawned at weaponobject location
{	
	jumpDir = VectorNormalize( AnglesToUp( self.angles ) );
	
	if ( jumpDir[2] > level.bettyJumpHeightWallAngleCos )
	{
		jumpHeight = level.bettyJumpHeight;
	}
	else
	{
		jumpHeight = level.bettyJumpHeightWall;
	}
	
	explodePos = self.origin + jumpDir * jumpHeight;
	
	self.killCamEnt MoveTo( explodePos + self.killCamOffset, level.bettyJumpTime, 0, level.bettyJumpTime );

	self clientfield::set( "bouncingbetty_state", BOUNCINGBETTY_DETONATING );

	wait( level.bettyJumpTime );	

	self thread mineExplode( jumpDir, explodePos );
}


function mineExplode( explosionDir, explodePos )
{
	if ( !isdefined( self ) || !isdefined( self.owner ) )
		return;
	
	self playsound( "wpn_betty_explo" );

	self clientfield::set( "sndRattle", 1 );
	
	WAIT_SERVER_FRAME; // needed or the effect doesn't play
	if ( !isdefined( self ) || !isdefined(self.owner) )
		return;
	
	self CylinderDamage( explosionDir * level.bettyDamageHeight, explodePos, level.bettyDamageRadius, level.bettyDamageRadius, level.bettyDamageMax, level.bettyDamageMin, self.owner, "MOD_EXPLOSIVE", self.weapon );
	self ghost();
	
	wait( 0.1 ); 
	
	
	if ( !isdefined( self ) || !isdefined(self.owner) )
		return;
	
	if ( isdefined( self.trigger ) )
		self.trigger delete();
	
	self.killCamEnt delete();
	self delete();
}

