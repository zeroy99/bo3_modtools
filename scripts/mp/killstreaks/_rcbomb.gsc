#using scripts\codescripts\struct;

#using scripts\shared\_oob;
#using scripts\shared\array_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\hud_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_flashgrenades;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_utils;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_remote_weapons;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "KILLSTREAK_EARNED_RCBOMB" );
#precache( "string", "KILLSTREAK_RCBOMB_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_RCBOMB_INBOUND" );
#precache( "string", "KILLSTREAK_RCBOMB_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_RCBOMB" );
#precache( "string", "mpl_killstreak_rcbomb" );
#precache( "fx", "_t6/weapon/grenade/fx_spark_disabled_rc_car" );
#precache( "fx", "killstreaks/fx_rcxd_lights_grn" );
#precache( "fx", "killstreaks/fx_rcxd_lights_red" );
#precache( "fx", "killstreaks/fx_rcxd_exp" );

#namespace rcbomb;

#define RCBOMB_NAME "rcbomb"
#define RCBOMB_EMP_DEATH_HIDE_DELAY						( 0.2 )
#define RCBOMB_WATCH_DEATH_DURATION						( 0.3 )

function init()
{
	level._effect["rcbombexplosion"] = "killstreaks/fx_rcxd_exp";

	killstreaks::register( RCBOMB_NAME, RCBOMB_NAME, "killstreak_rcbomb", "rcbomb_used",&ActivateRCBomb );
	killstreaks::register_strings( RCBOMB_NAME, &"KILLSTREAK_EARNED_RCBOMB", &"KILLSTREAK_RCBOMB_NOT_AVAILABLE", &"KILLSTREAK_RCBOMB_INBOUND", undefined, &"KILLSTREAK_RCBOMB_HACKED", false );
	killstreaks::register_dialog( RCBOMB_NAME, "mpl_killstreak_rcbomb", "rcBombDialogBundle", undefined, "friendlyRcBomb", "enemyRcBomb",  "enemyRcBombMultiple", "friendlyRcBombHacked", "enemyRcBombHacked", "requestRcBomb" );
	killstreaks::allow_assists( RCBOMB_NAME, true);
	killstreaks::register_alt_weapon( RCBOMB_NAME, "killstreak_remote" );
	killstreaks::register_alt_weapon( RCBOMB_NAME, "rcbomb_turret" );
	remote_weapons::RegisterRemoteWeapon( RCBOMB_NAME, &"", &StartRemoteControl, &EndRemoteControl, RCBOMB_HIDE_COMPASS_ON_REMOTE_CONTROL );
	
	vehicle::add_main_callback( RCBOMB_VEHICLE, &InitRCBomb );
	
	clientfield::register( "vehicle", "rcbomb_stunned", VERSION_SHIP, 1, "int" );
}

function InitRCBomb()
{
	rcbomb = self;
	
	rcbomb clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );	
	rcbomb.allowFriendlyFireDamageOverride = &RCCarAllowFriendlyFireDamage;
	rcbomb EnableAimAssist();
	rcbomb SetDrawInfrared( true );
	rcbomb.delete_on_death = true;
	rcbomb.death_enter_cb = &waitRemoteControl;
	rcbomb.disableRemoteWeaponSwitch = true;
	rcbomb.overrideVehicleDamage = &OnDamage;
	rcbomb.overrideVehicleDeath = &OnDeath;
	//rcbomb.remoteWeaponShutdownDelay = RCBOMB_SHUTDOWN_DELAY;
	rcbomb.watch_remote_weapon_death = true;
	rcbomb.watch_remote_weapon_death_duration = RCBOMB_WATCH_DEATH_DURATION;
	
	if ( IsSentient( rcbomb ) == false )
		rcbomb MakeSentient(); // so other sentients will consider this as a potential enemy
}


function waitRemoteControl()
{
	remote_controlled = IS_TRUE( self.control_initiated ) || IS_TRUE( self.controlled );
	
	if( remote_controlled )
	{
		notifyString = self util::waittill_any_return( "remote_weapon_end", "rcbomb_shutdown" );		
		if( notifyString == "remote_weapon_end" )
			self waittill( "rcbomb_shutdown" );
		else
			self waittill( "remote_weapon_end" );
	}
	else
		self waittill( "rcbomb_shutdown" );
}

function toggleLightsOnAfterTime( time )
{
	self notify("toggleLightsOnAfterTime_singleton");
	self endon ("toggleLightsOnAfterTime_singleton");

	rcbomb = self;
	rcbomb endon( "death" );
	wait( time );
	rcbomb clientfield::set( "toggle_lights", CF_TOGGLE_LIGHTS_ON );
}

function HackedPreFunction( hacker )
{
	rcbomb = self;
	rcbomb clientfield::set( "toggle_lights", CF_TOGGLE_LIGHTS_OFF );
	rcbomb.owner unlink();	
	rcbomb clientfield::set( "vehicletransition", 0 );
	rcbomb.owner killstreaks::clear_using_remote();
	rcbomb MakeVehicleUnusable();
}

function HackedPostFunction( hacker )
{
	rcbomb = self;
	hacker remote_weapons::UseRemoteWeapon( rcbomb, RCBOMB_NAME, true, false );
	rcbomb MakeVehicleUnusable();
	hacker killstreaks::set_killstreak_delay_killcam( RCBOMB_NAME );
	hacker killstreak_hacking::set_vehicle_drivable_time_starting_now( rcbomb );
}

function ConfigureTeamPost( owner, isHacked )
{
	rcbomb = self;
	rcbomb thread WatchOwnerGameEvents();
}


function ActivateRCBomb( hardpointType )
{
	assert( IsPlayer( self ) );
	player = self;
	
	if( !player killstreakrules::isKillstreakAllowed( hardpointType, player.team ) )
	{
		return false;
	}
	
	if ( player UseButtonPressed() )
	{
		return false;
	}

	placement = CalculateSpawnOrigin( self.origin, self.angles );
	if( !isdefined( placement ) || !self IsOnGround() || self util::isUsingRemote() || killstreaks::is_interacting_with_object() || self oob::IsTouchingAnyOOBTrigger() || self killstreaks::is_killstreak_start_blocked() )
	{
		self iPrintLnBold( &"KILLSTREAK_RCBOMB_NOT_PLACEABLE" );
		return false;
	}
	
	killstreak_id = player killstreakrules::killstreakStart( RCBOMB_NAME, player.team, false, true );
	if( killstreak_id == INVALID_KILLSTREAK_ID )
	{
		return false;
	}
	
	rcbomb = SpawnVehicle( RCBOMB_VEHICLE, placement.origin, placement.angles, "rcbomb" );
	
	rcbomb killstreaks::configure_team( RCBOMB_NAME, killstreak_id, player, "small_vehicle", undefined, &ConfigureTeamPost );
	rcbomb killstreak_hacking::enable_hacking( RCBOMB_NAME, &HackedPreFunction, &HackedPostFunction );
	rcbomb.damageTaken = 0;
	rcbomb.abandoned = false;
	rcbomb.killstreak_id = killstreak_id;
	rcbomb.activatingKillstreak = true;
	rcbomb SetInvisibleToAll();
	
	rcbomb thread WatchShutdown();
	rcbomb.health = killstreak_bundles::get_max_health( hardpointType );
	rcbomb.maxhealth = killstreak_bundles::get_max_health( hardpointType );
	rcbomb.hackedhealth = killstreak_bundles::get_hacked_health( hardpointType );
	rcbomb.hackedHealthUpdateCallback = &rcbomb_hacked_health_update;
	rcbomb.ignore_vehicle_underneath_splash_scalar = true;
	
	self thread killstreaks::play_killstreak_start_dialog( RCBOMB_NAME, self.team, killstreak_id );
	self AddWeaponStat( GetWeapon( "rcbomb" ) , "used", 1 );
	
	remote_weapons::UseRemoteWeapon( rcbomb, RCBOMB_NAME, true, false );
	
	if ( !isdefined( player ) || !isAlive( player ) || IS_TRUE( player.laststand ) || player IsEMPJammed() )
	{
		if ( isdefined( rcbomb ) )
		{
			rcbomb notify( "remote_weapon_shutdown" );
			rcbomb notify( "rcbomb_shutdown" );
		}
		return false;
	}
		
	rcbomb SetVisibleToAll();
	rcbomb.activatingKillstreak = false;
	Target_Set( rcbomb );
	
	rcbomb thread WatchGameEnded();

	return true;
}

function rcbomb_hacked_health_update( hacker )
{
	rcbomb = self;
	if ( rcbomb.health > rcbomb.hackedhealth )
	{
		rcbomb.health = rcbomb.hackedhealth;	
	}
}


function StartRemoteControl( rcbomb )
{
	player = self;
	
	rcbomb UseVehicle( player, 0 );
	rcbomb clientfield::set( "vehicletransition", 1 );
	
	rcbomb thread audio::sndUpdateVehicleContext(true);
	
	rcbomb thread WatchTimeout();
	rcbomb thread WatchDetonation();
	rcbomb thread WatchHurtTriggers();
	rcbomb thread WatchWater();
	
	player vehicle::set_vehicle_drivable_time_starting_now( RCBOMB_DURATION );
}

function EndRemoteControl( rcbomb, exitRequestedByOwner )
{
	if ( exitrequestedbyowner == false ) 
	{
		rcbomb notify( "rcbomb_shutdown" );
		rcbomb thread audio::sndUpdateVehicleContext(false);
	}
	rcbomb clientfield::set( "vehicletransition", 0 );
}

function WatchDetonation()
{
	rcbomb = self;
	rcbomb endon( "rcbomb_shutdown" );
	rcbomb endon( "death" );
	
	while( !rcbomb.owner attackbuttonpressed() ) 
	{
		WAIT_SERVER_FRAME;
	}
	
	rcbomb notify( "rcbomb_shutdown" );
}

#define RCBOMB_IN_WATER_TRACE_MINS		( -2, -2, -2 )
#define RCBOMB_IN_WATER_TRACE_MAXS		(  2,  2,  2 )
#define RCBOMB_IN_WATER_TRACE_MASK		( PHYSICS_TRACE_MASK_WATER )
#define RCBOMB_IN_WATER_TRACE_WAIT		( 0.5 )
	
function WatchWater()
{
	self endon( "rcbomb_shutdown" );
			
	inWater = false;
	while( !inWater )
	{
		wait RCBOMB_IN_WATER_TRACE_WAIT;
		trace = physicstrace( self.origin + ( 0, 0, 10 ), self.origin + ( 0, 0, 6 ), RCBOMB_IN_WATER_TRACE_MINS, RCBOMB_IN_WATER_TRACE_MAXS, self, RCBOMB_IN_WATER_TRACE_MASK);
		inWater = trace["fraction"] < 1.0;
	}

	self.abandoned = true;
	self notify( "rcbomb_shutdown" );
}

function WatchOwnerGameEvents()
{
	self notify("WatchOwnerGameEvents_singleton");
	self endon ("WatchOwnerGameEvents_singleton");
	
	rcbomb = self;
	rcbomb endon( "rcbomb_shutdown" );
	
	rcbomb.owner util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	
	rcbomb.abandoned = true;
	rcbomb notify( "rcbomb_shutdown" );
}

function WatchTimeout()
{
	rcbomb = self;
	rcbomb thread killstreaks::WaitForTimeout( RCBOMB_NAME, RCBOMB_DURATION, &rc_shutdown, "rcbomb_shutdown" );
}

function rc_shutdown()
{
	rcbomb = self;
	rcbomb notify( "rcbomb_shutdown" );
}

function WatchShutdown()
{
	rcbomb = self;
	rcbomb endon( "death" );
	
	rcbomb waittill( "rcbomb_shutdown" );

	if ( isdefined( rcbomb.activatingKillstreak ) && rcbomb.activatingKillstreak )
	{
		// we can delete since it should not have been made visible yet
		killstreakrules::killstreakStop( RCBOMB_NAME, rcbomb.originalteam, rcbomb.killstreak_id );
		rcbomb notify( "rcbomb_shutdown" );
		rcbomb delete(); // still need to delete here
	}
	else
	{
		attacker = ( isdefined( rcbomb.owner ) ? rcbomb.owner : undefined );
		rcbomb DoDamage( rcbomb.health + 1, rcbomb.origin + (0, 0, 10), attacker, attacker, "none", "MOD_EXPLOSIVE", 0 );
	}
}

function WatchHurtTriggers()
{
	rcbomb = self;
	rcbomb endon( "rcbomb_shutdown" );
	
	while( true )
	{
		rcbomb waittill ( "touch", ent );
		if( isdefined( ent.classname ) && ( ent.classname == "trigger_hurt" || ent.classname == "trigger_out_of_bounds" ) )
		{
			rcbomb notify( "rcbomb_shutdown" );
		}
	}
}

function OnDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if ( self.activatingKillstreak )
	{
		return 0.0;
	}
	
	if ( !isdefined( eAttacker ) || eAttacker != self.owner )
	{
		iDamage = killstreaks::OnDamagePerWeapon( RCBOMB_NAME, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, self.maxhealth, undefined, self.maxhealth*0.4, undefined, 0, undefined, true, 1.0 );
	}
	
	if( isdefined( eAttacker ) && isdefined( eAttacker.team ) && eAttacker.team != self.team )
	{
		if( weapon.isEmp )
		{
			self.damage_on_death = false;
			self.died_by_emp = true;
			iDamage = self.health + 1; // destroy if hit by emp
			//thread remote_weapons::do_static_fx();
		}
	}
	
	// C4 destroys the HC-XD with any damage (TODO: consider creating a more robust solution if need be)
	if ( weapon.name == "satchel_charge" && sMeansOfDeath == "MOD_EXPLOSIVE" )
	{
		iDamage = self.health + 1;
	}
	
	return iDamage;
}



function OnDeath( eInflictor, eAttacker, iDamage, sMeansOfDeath, weapon, vDir, sHitLoc, psOffsetTime )
{
	rcbomb = self;
	player = rcbomb.owner;
	
	player endon( "disconnect" );
	player endon( "joined_team" );
	player endon( "joined_spectators" );
	
	killstreakrules::killstreakStop( RCBOMB_NAME, rcbomb.originalTeam, rcbomb.killstreak_id );
	
	rcbomb clientfield::set( "enemyvehicle", ENEMY_VEHICLE_INACTIVE );

	//if( isdefined( player ) && ( !isdefined( eAttacker ) || ( eAttacker.team != rcbomb.team ) ) && !level.gameEnded )
		//rcbomb remote_weapons::do_static_fx();
	
	rcbomb Explode( eAttacker, weapon );
	
	hide_after_wait_time = ( ( rcbomb.died_by_emp === true ) ? RCBOMB_EMP_DEATH_HIDE_DELAY : RCBOMB_DEATH_HIDE_DELAY );
	if( isdefined( player ) )
	{
		player util::freeze_player_controls( true );
		rcbomb thread HideAfterWait( hide_after_wait_time );
		//rcbomb util::DeleteAfterTime( RCBOMB_SHUTDOWN_DELAY );
		wait( RCBOMB_SHUTDOWN_DELAY );
		player util::freeze_player_controls( false );
	}
	else
	{
		rcbomb thread HideAfterWait( hide_after_wait_time );
		//rcbomb util::DeleteAfterTime( RCBOMB_SHUTDOWN_DELAY_ABANDONED );
	}
	
	if ( isdefined( rcbomb ) )
		rcbomb notify( "rcbomb_shutdown" );
}

function WatchGameEnded()
{
	rcbomb = self;
	rcbomb endon( "death" );
	
	level waittill("game_ended");

	rcbomb.abandoned = true;
	rcbomb.selfDestruct = true;
	rcbomb notify( "rcbomb_shutdown" );
}

function HideAfterWait( waitTime )
{
	self endon( "death" );

	wait waitTime;
	self SetInvisibleToAll();
}

function Explode( attacker, weapon )
{
	self endon ("death");
	owner = self.owner;
	 
	if ( !isdefined( attacker ) && isdefined( self.owner ) )
	{
		attacker = self.owner;
	}

	self vehicle_death::death_fx();
	self thread vehicle_death::death_radius_damage();
	self thread vehicle_death::set_death_model( self.deathmodel, self.modelswapdelay );
	
	self vehicle::toggle_tread_fx( false );
	self vehicle::toggle_exhaust_fx( false );
	self vehicle::toggle_sounds( false );
	self vehicle::lights_off();
	
	self PlayRumbleOnEntity( "rcbomb_explosion" );

	if ( !self.abandoned && attacker != self.owner && isPlayer( attacker ) )
	{	
		attacker challenges::destroyRCBomb( weapon );
		if ( self.owner util::IsEnemyPlayer( attacker ) )
		{
			scoreevents::processScoreEvent( "destroyed_hover_rcxd", attacker, self.owner, weapon );
			LUINotifyEvent( &"player_callout", 2, &"KILLSTREAK_DESTROYED_RCBOMB", attacker.entnum );	
			if ( isdefined( weapon ) && weapon.isValid )
			{
				weaponStatName = "destroyed";
				level.globalKillstreaksDestroyed++;
				// increment the destroyed stat for this, we aren't using the weaponStatName variable from above because it could be "kills" and we don't want that
				weapon_rcbomb = GetWeapon( "rcbomb" );
				attacker AddWeaponStat( weapon_rcbomb, "destroyed", 1 );
				attacker AddWeaponStat( weapon, "destroyed_controlled_killstreak", 1 );
			}
			
			self killstreaks::play_destroyed_dialog_on_owner( RCBOMB_NAME, self.killstreak_id );
		}
	}
}

function RCCarAllowFriendlyFireDamage( eInflictor, eAttacker, sMeansOfDeath, weapon )
{
	if ( isdefined( eAttacker ) && eAttacker == self.owner )
		return true;
		
	if ( isdefined( eInflictor ) && eInflictor islinkedto( self ) )
		return true;
	
	return false;
}

function GetPlacementStartHeight()
{
	startheight = RCBOMB_PLACEMENT_STAND_HEIGHT;
	
	switch( self GetStance() )
	{
		case "crouch":
			startheight = RCBOMB_PLACEMENT_CROUCH_HEIGHT;
			break;
		case "prone":
			startheight = RCBOMB_PLACEMENT_PRONE_HEIGHT;
			break;
	}
	return startheight;
}

function CalculateSpawnOrigin( origin, angles )
{
	startheight = GetPlacementStartHeight();
	
	mins = (-5,-5,0); // keep the min z 0 so the return point is the exact height of the collision
	maxs = (5,5,10);
	
	startPoints = [];
	startAngles = [];
	wheelCounts = [];
	testCheck = [];
	largestCount = 0;
	largestCountIndex = 0;
	
	testangles = [];
	testangles[0] = (0,0,0);
	testangles[1] = (0,20,0);
	testangles[2] = (0,-20,0);
	testangles[3] = (0,45,0);
	testangles[4] = (0,-45,0);
	
	heightoffset = 5;
	
	for (i = 0; i < testangles.size; i++ )
	{
		testCheck[i] = false;

		startAngles[i] = ( 0, angles[1], 0 );
		startPoint = origin + VectorScale( anglestoforward( startAngles[i] + testangles[i]), RCBOMB_PLACMENT_FROM_PLAYER );
		endPoint = startPoint - (0,0,100);
		startPoint = startPoint + (0,0,startheight);

		// ignore water on this one
		mask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_VEHICLE;
			
		// using physicstrace so we dont slip through small cracks
		trace = physicstrace( startPoint, endPoint, mins, maxs, self, mask);
			
		// if any player intersection then skip
		if ( isdefined(trace["entity"]) && IsPlayer(trace["entity"]))
		{
			wheelCounts[i] = 0;
			continue;
		}
			 
		startPoints[i] = trace["position"] + (0,0,heightoffset);
		wheelCounts[i] = TestWheelLocations(startPoints[i],startAngles[i],heightoffset);
		
		if ( positionWouldTelefrag( startPoints[i] ) )
			continue;
	
		if ( largestCount < wheelCounts[i] )
		{
			largestCount = wheelCounts[i];
			largestCountIndex = i;
		}
		
		// going to early out on the first I find with valid tire positions
		if ( wheelCounts[i] >=  3 )
		{
			testCheck[i] = true;

			if ( TestSpawnOrigin( startPoints[i], startAngles[i] ) )
			{
				placement = SpawnStruct();
				placement.origin = startPoints[i];
				placement.angles = startAngles[i];
				return placement;
			}
		}
	}
	
	for (i = 0; i < testangles.size; i++ )
	{
		if ( !testCheck[i] )
		{
			if ( wheelCounts[i] >=  2 )
			{
				if ( TestSpawnOrigin( startPoints[i], startAngles[i] ) )
				{
					placement = SpawnStruct();
					placement.origin = startPoints[i];
					placement.angles = startAngles[i];
					return placement;
				}
			}
		}
	}
	
	return undefined;
}

function TestWheelLocations( origin, angles, heightoffset )
{
	forward = 13;
	side = 10;
	
	wheels = [];
	wheels[0] = ( forward, side, 0 );
	wheels[1] = ( forward, -1 * side, 0 );
	wheels[2] = ( -1 * forward, -1 * side, 0 );
	wheels[3] = ( -1 * forward, side, 0 );

	height = 5;
	touchCount = 0;
	
	yawangles = (0,angles[1],0);
	
	for (i = 0; i < 4; i++ )
	{
		wheel = RotatePoint( wheels[i], yawangles  );
		startPoint = origin + wheel;
		endPoint = startPoint + (0,0,(-1 * height) - heightoffset);
		startPoint = startPoint + (0,0,height - heightoffset) ;
	
		trace = bulletTrace( startPoint, endPoint, false, self );
		if ( trace["fraction"] < 1 )
		{
			touchCount++;
		}
	}
	
	return touchCount;
}

function TestSpawnOrigin( origin, angles )
{
	liftedorigin = origin + (0,0,5);
	size = 12;
	height = 15;
	mins = (-1 * size,-1 * size,0 );
	maxs = ( size,size,height );
	absmins = liftedorigin + mins;
	absmaxs = liftedorigin + maxs;
	
	if( BoundsWouldTelefrag( absmins, absmaxs ) )
	{
		return false;
	}
	
	startheight = getPlacementStartHeight();
	
	mask = PHYSICS_TRACE_MASK_PHYSICS | PHYSICS_TRACE_MASK_VEHICLE | PHYSICS_TRACE_MASK_WATER;
	
	// test the volume where we are going to place the car
	// note that this physics trace is not an  oriented box.
	trace = physicstrace( liftedorigin, (origin +(0,0,1)), mins, maxs, self, mask);

	if ( trace["fraction"] < 1 )
	{
		return false;
	}

	// swept trace of a small bounding box from head height to where we are placing the car
	// to make sure there is no wall between us and the car
	size = 2.5;
	height = size * 2;
	mins = (-1 * size,-1 * size,0 );
	maxs = ( size,size,height );
	
	sweeptrace = physicstrace( (self.origin + (0,0,startheight)), liftedorigin, mins, maxs, self, mask);

	if ( sweeptrace["fraction"] < 1 )
	{
		return false;
	}
	
	return true;
}
