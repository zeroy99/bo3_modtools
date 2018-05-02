#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\entityheadicons_shared;
#using scripts\shared\killcam_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_tacticalinsertion;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\_burnplayer;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#namespace incendiary;

REGISTER_SYSTEM( "incendiary_grenade", &init_shared, undefined )


function init_shared()
{
	level.incendiaryfireDamage = GetDvarInt( "scr_incendiaryfireDamage", 35 ); // how much damage will the fire do each tick
	level.incendiaryfireDamageHardcore = GetDvarInt( "scr_incendiaryfireDamageHardcore", 15 ); // how much damage will the fire do each tick in hardcore
 	level.incendiaryfireDuration = GetDvarInt ("scr_incendiaryfireDuration", 5 ); // time damage triggers will last.
 	level.incendiaryfxDuration = GetDvarFloat( "scr_incendiaryfxDuration", 0.4 ); // Incendiary fx duration
	level.incendiaryDamageRadius = GetDvarInt( "scr_incendiaryDamageRadius", 125 ); // radius of individual damages
	level.incendiaryfireDamageTickTime = GetDvarFloat( "scr_incendiaryfireDamageTickTime", 1 ); // time between damage hits
	
	
 	level.incendiaryDamageThisTick = [];
 	
	callback::on_spawned( &create_incendiary_watcher );
}

function create_incendiary_watcher() // self == player
{
	watcher = self weaponobjects::createUseWeaponObjectWatcher( "incendiary_grenade", self.team );
	
	watcher.onSpawn = &incendiary_system_spawn;
}

function incendiary_system_spawn( watcher, player ) // self == incendiary grenade
{
	player endon( "death" );
	player endon( "disconnect" );
	level endon( "game_ended" );
	
	player AddWeaponStat( self.weapon, "used", 1 );	
	thread watchForExplode( player );
}


function watchForExplode( owner )
{
	self endon( "hacked" );
	self endon( "delete" );
	
	killCamEnt = spawn( "script_model", self.origin );
	killCamEnt util::deleteAfterTime( 15.0 );
	killCamEnt.startTime = gettime();
	killCamEnt linkto( self );
	killCamEnt setWeapon( self.weapon );

	killcamEnt killcam::store_killcam_entity_on_entity(self);
	
	self waittill( "projectile_impact_explode", origin, normal, surface );
	killCamEnt unlink();
	PlaySoundAtPosition ("wpn_incendiary_core_start" ,self.origin);
	
	generateLocations( origin, owner, normal, killCamEnt );
}

function getstepoutdistance( normal )
{
	if ( normal[2] < 0.5 )
	{
		stepoutdistance = normal * GetDvarInt( "scr_incendiary_stepout_wall", 50 );
	}
	else 
	{
		stepoutdistance = normal * GetDvarInt( "scr_incendiary_stepout_ground", 12 );
	}
	return stepoutdistance;
}

function generateLocations( position, owner, normal, killCamEnt )
{
	startPos = position + getstepoutdistance( normal );
	desiredEndPos = startPos + ( 0, 0, 60 );
	physTrace = PhysicsTrace( startPos, desiredEndPos, ( -4, -4, -4 ), ( 4, 4, 4 ), self, PHYSICS_TRACE_MASK_PHYSICS );
	goalPos = ( ( physTrace[ "fraction" ] < 1 ) ? physTrace[ "position"]  : desiredEndPos );
	
	killCamEnt moveto( goalPos, 0.5 );
	rotation = RandomInt( 360 );
	
	if ( normal[2] < 0.1 ) // vertical wall
	{
		black = ( 0.1, 0.1, 0.1 );
			
		trace = hitPos( startPos, startpos + ( -normal * 70 ) + ( 0,0, -1 ) * 70, black );
		tracePosition = trace["position"];	
		incendiaryGrenade = GetWeapon( "incendiary_fire" );
		
		if ( trace["fraction"] < 0.9 )
		{
			wallnormal = trace["normal"];
			SpawnTimedFX( incendiaryGrenade, trace["position"], wallnormal, level.incendiaryfireDuration, self.team  );
		}
	}

	fxCount = GetDvarInt( "scr_incendiary_fx_count", 6 );
	spawnAllLocs( owner, startPos, normal, 1, rotation, killcament, fxCount );
}

function getLocationForFX( startPos, fxIndex, fxCount, defaultDistance, rotation )
{
	currentAngle = ( ( 360 / fxCount ) * fxIndex );
	cosCurrent = cos( currentAngle + rotation );
	sinCurrent = sin( currentAngle + rotation );
	
	return startPos + ( defaultDistance * cosCurrent, defaultDistance * sinCurrent, 0 );
}

function spawnAllLocs( owner, startPos, normal, multiplier, rotation, killcament, fxCount )
{
	defaultDistance = GetDvarInt( "scr_incendiary_trace_distance", 220 ) * multiplier;
	defaultDropDistance = GetDvarInt( "scr_incendiary_trace_down_distance", 90 );
	
	// DROCHE:TODO
	// if we are going to keep this grenade this should be moved to code
	
	colorArray = [];
	colorArray[colorArray.size] = ( 0.9, 0.2, 0.2 );
	colorArray[colorArray.size] = ( 0.2, 0.9, 0.2 );
	colorArray[colorArray.size] = ( 0.2, 0.2, 0.9 );
	colorArray[colorArray.size] = ( 0.9, 0.9, 0.9 );


	locations = [];
	locations["color"] = [];
	locations["loc"] = [];
	locations["tracePos"] = [];
	locations["distSqrd"] = [];
	locations["fxtoplay"] = [];
	locations["radius"] = [];

	
	for( fxIndex = 0; fxIndex < fxCount; fxIndex++ )
	{
		locations["point"][fxIndex] = getLocationForFX( startPos, fxIndex, fxCount, defaultDistance, rotation );
		locations["color"][fxIndex] = colorArray[fxIndex % colorArray.size];
	}
		
	for ( count = 0; count < fxCount; count++ )
	{
		trace = hitPos( startPos, locations["point"][count], locations["color"][count] );
		tracePosition = trace["position"];
		locations["tracePos"][count] = tracePosition;
		 
		if ( trace["fraction"] < 0.7 )
		{
			locations["loc"][count] = tracePosition;
			locations["normal"][count] = trace["normal"];
			continue;
		}
		
		average = startPos/2 + tracePosition/2;

		trace = hitPos( average, average - ( 0, 0, defaultDropDistance ), locations["color"][count] );
		if ( trace["fraction"] != 1 )
		{
			locations["loc"][count] = trace["position"];
			locations["normal"][count] = trace["normal"];
		}
	}	

	// startPos = startPos - getstepoutdistance( normal ); // start pos is already a good position for fx, we are using a different sized trigger now.
	
	incendiaryGrenade = GetWeapon( "incendiary_fire" );

	SpawnTimedFX( incendiaryGrenade, startPos, normal, level.incendiaryfireDuration, self.team );
	
	level.incendiaryDamageRadius = GetDvarInt( "scr_incendiaryDamageRadius", level.incendiaryDamageRadius );
	
	thread damageEffectArea ( owner, startPos, level.incendiaryDamageRadius, level.incendiaryDamageRadius, killCamEnt );
	
	for ( count = 0; count < locations["point"].size; count++ )
	{
		if ( isdefined ( locations["loc"][count] ) )
		{
			normal = locations["normal"][count];
				
			SpawnTimedFX( incendiaryGrenade, locations["loc"][count], normal, level.incendiaryfireDuration, self.team );
		}
	}
}

function damageEffectArea ( owner, position, radius, height, killCamEnt )
{
	trigger_radius_position = position - ( 0 , 0, height );
	trigger_radius_height = height * 2;

	fireEffectArea = spawn( "trigger_radius", trigger_radius_position, 0, radius, trigger_radius_height );
	
	// Create head icon
//	objective = GetEquipmentHeadObjective( GetWeapon( "incendiary_grenade" ) );
//	killCamEnt entityheadicons::setEntityHeadIcon( owner.pers["team"], owner, (0,0,0), objective );


	// raps stuff
	if ( isdefined( level.rapsOnBurnRaps ) )
	{
		owner thread [[level.rapsOnBurnRaps]]( fireEffectArea );
	}

	// loop variables
	loopWaitTime = level.incendiaryFireDamageTickTime;
	durationOfIncendiary = level.incendiaryFireDuration;

	// loop for the duration of the effect
	while (durationOfIncendiary > 0)
	{
		durationOfIncendiary -= loopWaitTime;
		damageApplied = false;

		potential_targets = self getPotentialTargets( owner );
		foreach( target in potential_targets )
		{
			self tryToApplyFireDamage( target, owner, position, fireEffectArea, loopWaitTime, killcament );
		}

		wait (loopWaitTime);
	}
	
	// Delete head icon
	if ( isdefined( killCamEnt ) )
		killCamEnt entityheadicons::destroyEntityHeadIcons();
	// clean up
	fireEffectArea delete();	
}	

function getPotentialTargets( owner ) // self == incendiary grenade
{
	// try getting team based targets first
	owner_team = ( isdefined( owner ) ? owner.team : undefined );
	if ( level.teambased && isdefined( owner_team ) && level.friendlyfire == 0 )
	{
		enemy_team = ( owner_team == "axis" ? "allies" : "axis" );
		potential_targets = [];
		potential_targets = ArrayCombine( potential_targets, GetPlayers( enemy_team ), false, false );
		potential_targets = ArrayCombine( potential_targets, GetAITeamArray( enemy_team ), false, false );
		potential_targets = ArrayCombine( potential_targets, GetVehicleTeamArray( enemy_team ), false, false );
		potential_targets[ potential_targets.size ] = owner;
		return potential_targets;
	}
	
	// now get all targets
	all_targets = [];
	all_targets = ArrayCombine( all_targets, level.players, false, false );
	all_targets = ArrayCombine( all_targets, GetAIArray(), false, false );
	all_targets = ArrayCombine( all_targets, GetVehicleArray(), false, false );

	// if this is hardcore, then every entity is a potential target
	if ( level.friendlyfire > 0 )
		return all_targets;

	// remove all targets not on the same team, except owner
	potential_targets = [];
	foreach( target in all_targets )
	{
		if ( !isdefined( target ) )
			continue;

		if( !isdefined( target.team ) )
			continue;
				
		if( isdefined( owner ) )
		{
			if( target != owner )				
			{
				if( !isdefined( owner_team ) )
					continue;
				
				if( target.team == owner_team )
					continue;
			}
		}
		else
		{
			if ( !isdefined( self ) )
				continue;

			if( !isdefined( self.team ) )
				continue;

			if( target.team == self.team )
				continue;
		}

		potential_targets[ potential_targets.size ] = target;
	}
	
	return potential_targets;
}

function tryToApplyFireDamage( target, owner, position, fireEffectArea, resetFireTime, killcament )  // self == incendiary grenade
{
	// see if we're not in the fire area
	if ( ( !isdefined(target.infireArea) ) || (target.infireArea == false) )
	{
		// since we're not in the poison area, now see if we're in the fire area
		if ( target istouching(fireEffectArea) && ( !isdefined(target.sessionstate) || target.sessionstate == "playing" ) )
		{
			trace = bullettrace( position, target GetShootAtPos(), false, target, true );

			if ( trace["fraction"] == 1 )
			{
				target.lastburnedBy = owner;
				target thread damageInFireArea( fireEffectArea, killcament, trace, position, resetFireTime );
			}
		}
	}
}

function damageInFireArea( fireEffectArea, killcament, trace, position, resetFireTime ) // self == player in fire area
{
	self endon( "disconnect" );
	self endon( "death" );

	timer = 0;

	damage = level.incendiaryfireDamage;
	if( level.hardcoreMode )
	{
		damage = level.incendiaryfireDamageHardcore;
	}
	
	if ( canDoFireDamage( killCamEnt, self, resetFireTime ) )
	{
		self DoDamage( damage, fireEffectArea.origin, self.lastburnedBy, killCamEnt, "none", "MOD_BURNED", 0, GetWeapon( "incendiary_fire" ) );
		
		entnum = self getentitynumber();

		self thread sndFireDamage();
	}
}


function sndFireDamage()
{	
	self notify( "sndFire" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "sndFire" );
	
	if( !isdefined( self.sndFireEnt ) )
	{
		self.sndFireEnt = spawn( "script_origin", self.origin );
		self.sndFireEnt linkto( self, "tag_origin" );
		self.sndFireEnt playsound( "chr_burn_start" );
		self thread sndFireDamage_DeleteEnt(self.sndFireEnt);
	}
	
	self.sndFireEnt playloopsound( "chr_burn_start_loop", .5 );
	wait(3);
	self.sndFireEnt delete();
	self.sndFireEnt = undefined;
}
function sndFireDamage_DeleteEnt(ent)
{
	self endon( "disconnect" );
	self waittill( "death" );
	
	if( isdefined( ent ) )
		ent delete(); //pfx_fire_incendiary
}


function hitPos( start, end, color )
{
	trace = bullettrace( start, end, false, undefined );
	
	return trace;
}

function canDoFireDamage( killCamEnt, victim, resetFireTime )
{
	entNum = victim getentitynumber();
	if ( !isdefined( level.incendiaryDamageThisTick[entNum] ) )
	{
		level.incendiaryDamageThisTick[entNum] = 0;
		level thread resetFireDamage( entnum, resetFireTime );
		return true;
	}
	
	return false;
}

function resetFireDamage( entnum, time  )
{
	if ( time > 0.05 )
	{
		wait( time - 0.05 );
	}
	level.incendiaryDamageThisTick[entnum] = undefined;
}

	