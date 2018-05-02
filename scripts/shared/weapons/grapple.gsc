#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\weapons\grapple.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace grapple;

REGISTER_SYSTEM_EX( "grapple", &__init__, &__main__, undefined )

#define GRAPPLE_TARGET "grapple_target"	
#define GRAPPLE_RETARGET_DELAY 0.1

#define WEAPON_CHANGE_NOTIFY "grapple_weapon_change" 	
	

function __init__()
{
	callback::on_spawned( &watch_for_grapple );
}

function __main__()
{
	grapple_targets = GetEntArray( GRAPPLE_TARGET, "targetname" );
	foreach( target in grapple_targets ) 
	{
		target.grapple_type = GRAPPLE_TYPE_REELPLAYER;
		target SetGrapplableType( target.grapple_type );
	}
}

function translate_notify_1( from_notify, to_notify )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );

	while (IsDefined(self))
	{
		self waittill( from_notify, param1, param2, param3 );
		self notify( to_notify, from_notify, param1, param2, param3 );
	}
}


function watch_for_grapple()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );
	self endon("killReplayGunMonitor");

	self thread translate_notify_1( "weapon_switch_started", WEAPON_CHANGE_NOTIFY );
	self thread translate_notify_1( "weapon_change_complete", WEAPON_CHANGE_NOTIFY );
	
	while( 1 )
	{
		self waittill( WEAPON_CHANGE_NOTIFY, event, weapon );
		
		if ( IS_TRUE(weapon.grappleWeapon) )
		{
			self thread watch_lockon(weapon);
		}
		else
		{
			self notify( "grapple_unwield" );
		}
	}
}

function watch_lockon(weapon)
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );
	self endon( "grapple_unwield" );
	self notify( "watch_lockon" );
	self endon( "watch_lockon" );

	self thread watch_lockon_angles(weapon);
	self thread clear_lockon_after_grapple(weapon);

	// find an initial target quickly
	self.use_expensive_targeting = true;
	
	while(1)
	{
		WAIT_SERVER_FRAME;
		if ( !(self IsGrappling()) )
		{
			target = self get_a_target(weapon);
			if ( !(self IsGrappling()) && !IS_EQUAL(target,self.lockonentity) )
			{
				self WeaponLockNoClearance( !IS_EQUAL( target, self.dummy_target ) );
				self.lockonentity = target;
				wait GRAPPLE_RETARGET_DELAY;
			}
		}
	}
}

function clear_lockon_after_grapple(weapon)
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );
	self endon( "grapple_unwield" );
	self notify( "clear_lockon_after_grapple" );
	self endon( "clear_lockon_after_grapple" );
	
	while(1)
	{
		self util::waittill_any( "grapple_pulled", "grapple_landed" );
		if ( IsDefined( self.lockonentity ) )
		{
			self.lockonentity = undefined;
			self.use_expensive_targeting = true;
		}
	}
}

function watch_lockon_angles(weapon)
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );
	self endon( "grapple_unwield" );
	self notify( "watch_lockon_angles" );
	self endon( "watch_lockon_angles" );
	
	while(1)
	{
		WAIT_SERVER_FRAME;
		if ( !(self IsGrappling()) )
		{
			if ( IsDefined( self.lockonentity ) )
			{
				if ( IS_EQUAL( self.lockonentity, self.dummy_target ) )
				{
					self weaponlocktargettooclose( false );
				}
				else
				{
					testOrigin = get_target_lock_on_origin( self.lockonentity );
					if ( !self inside_screen_angles( testOrigin, weapon, false ) )
					{
						self weaponlocktargettooclose( true );
					}
					else
					{
						self weaponlocktargettooclose( false );
					}
				}
			}
			
		}
	}
}

function place_dummy_target( origin, forward, weapon )
{
	if ( !IsDefined(self.dummy_target) )
	{
		self.dummy_target = Spawn( "script_origin", origin );
	}
	self.dummy_target SetGrapplableType( GRAPPLE_TYPE_TARGETONLY );

	start = origin; 
	
	distance = weapon.lockOnMaxRange * 0.9;
	if ( IsDefined( level.grapple_notarget_distance ) )
		distance = level.grapple_notarget_distance; 
	
	end = origin + forward * distance;
	
	if ( !(self IsGrappling()) )
	{
		self.dummy_target.origin = self trace( start, end, self.dummy_target );
	}

	minrange_sq = weapon.lockOnMinRange * weapon.lockOnMinRange; 
	if ( DistanceSquared( self.dummy_target.origin, origin ) < minrange_sq )
		return undefined; 
	
	return self.dummy_target;
}
	
function get_a_target(weapon)
{
	origin = self geteye(); 
	forward = self GetWeaponForwardDir();

	targets = GetGrappleTargetArray();

	if ( !IsDefined( targets ) )
		return undefined;

	if ( !IsDefined(weapon.lockOnScreenRadius) || weapon.lockOnScreenRadius< 1 )
		return undefined;

	validTargets = [];
	should_wait = 0;
	should_wait_limit = 2;

	if ( IS_TRUE( self.use_expensive_targeting ) )
	{
		should_wait_limit = 4;
		self.use_expensive_targeting = false;
	}
	
	for ( i = 0; i < targets.size; i++ )
	{
		if ( should_wait >= should_wait_limit )
		{
			WAIT_SERVER_FRAME; 
			origin = self GetWeaponMuzzlePoint();
			forward = self GetWeaponForwardDir();
			should_wait = 0;
		}
		
		testTarget = targets[i];

		if ( !is_valid_target( testTarget ) )
		{
			continue;
		}

		testOrigin = get_target_lock_on_origin( testTarget );
		//test_range_squared = DistanceSquared( origin, testOrigin );
		test_range = Distance( origin, testOrigin );
		//gun_range = self get_grapple_range(weapon);

		if ( test_range > weapon.lockOnMaxRange ||
			 test_range < weapon.lockOnMinRange )
		{
			continue;
		}

		normal = VectorNormalize( testOrigin - origin );
		dot = VectorDot( forward, normal );

		if ( 0 > dot )
		{
			// guy's behind us
			continue;
		}

		if ( !self inside_screen_angles( testOrigin, weapon, !IS_EQUAL(testTarget,self.lockonentity) ) )
		{
			continue;
		}
		
		canSee = self can_see( testTarget, testOrigin, origin, forward, 30 );
		should_wait++; // ^^ that's expensive

		if ( canSee )
		{
			validTargets[ validTargets.size ] = testTarget;
		}
	}

	best = pick_a_target_from( validTargets, origin, forward, weapon.lockOnMinRange, weapon.lockOnMaxRange );
	
	if ( IS_TRUE( level.grapple_notarget_enabled ) )
	{
		if (!IsDefined(best) || IS_EQUAL(best,self.dummy_target) )
		{
			best = place_dummy_target( origin, forward, weapon ); 
		}
	}
	
	return best; 
}

function get_target_type_score( target )
{
	if ( !IsDefined( target ) )
		return 0;
	
	if ( IS_EQUAL(target,self.dummy_target) )
		return 0; 
	
	if ( IS_EQUAL(target.grapple_type,GRAPPLE_TYPE_REELPLAYER) ) 
		return 1; 
	
	if ( IS_EQUAL(target.grapple_type,GRAPPLE_TYPE_PULLENTIN) ) 
		return 0.985; 
	
	if ( !IsDefined(target.grapple_type) ) 
		return 0.90; 
	
	if ( IS_EQUAL(target.grapple_type,GRAPPLE_TYPE_TARGETONLY) ) 
		return 0.75; 
	
	return 0;
}

// target selection tuning
//   0 = only consider distance
//   1 = only consider dot product
//   anything in the middle is some mixture of the two
#define GRAPPLE_TARGET_WEIGHT_DOT_OVER_DIST 0.85

function get_target_score( target, origin, forward, min_range, max_range )
{
	if ( !IsDefined( target ) )
		return -1;
	
	if ( IS_EQUAL(target,self.dummy_target) )
		return 0; 
	
	if ( is_valid_target( target ) )
	{
		testOrigin = get_target_lock_on_origin( target );
		normal = VectorNormalize( testOrigin - origin );
		dot = VectorDot( forward, normal );
		targetDistance =  Distance( self.origin, testOrigin );
		distance_score = 1-((targetDistance - min_range) / (max_range - min_range));
		
		type_score = get_target_type_score( target );
		
		return type_score * pow(dot,GRAPPLE_TARGET_WEIGHT_DOT_OVER_DIST) * pow(distance_score,1-GRAPPLE_TARGET_WEIGHT_DOT_OVER_DIST);
	}
	
	return -1;
}



function pick_a_target_from( targets, origin, forward, min_range, max_range )
{
	if ( !IsDefined( targets ) )
		return undefined;

	bestTarget = undefined;
	bestScore = undefined;
	
	for ( i = 0; i < targets.size; i++ )
	{
		target = targets[i];
		
		if ( is_valid_target( target ) )
		{
			score = get_target_score( target, origin, forward, min_range, max_range );
			
			if ( !IsDefined( bestTarget ) || !IsDefined( bestScore ) )
			{
				bestTarget = target;
				bestScore = score;
			}
			else if ( score > bestScore )
			{
				bestTarget = target;
				bestScore = score;
			}
		}
	}
	return bestTarget;
}

function trace( from, to, target )
{
	trace = bullettrace(from,to, false, self, true, false, target );
	return trace[ "position" ];
}



function can_see( target, target_origin, player_origin, player_forward, distance )
{
	start = player_origin + player_forward * distance; 
	end = target_origin - player_forward * distance; 
	
	collided = self trace( start, end, target );
	
	if ( Distance2DSquared(end,collided) > 3 * 3 )
	{
		/#
			if ( GetDvarInt( "scr_grapple_target_debug" ) )
			{
				Line(start,collided,(0,0,1),1,0,50);
				Line(collided,end,(1,0,0),1,0,50);
			}
		#/
		return false;
	}

	/# 
		if ( GetDvarInt( "scr_grapple_target_debug" ) )
		{
			Line(start,end,(0,1,0),1,0,30); 
		}
	#/
	return true;
}

function is_valid_target( ent )
{
	if ( IsDefined( ent ) && IsDefined( level.grapple_valid_target_check ) )
	{
		if ( ![[level.grapple_valid_target_check]](ent) )
			return false;
	}
	return IsDefined( ent ) && ( IsAlive( ent ) || !IsSentient(ent) );
}

function inside_screen_angles( testOrigin, weapon, newtarget )
{
	hang = weapon.lockonlossanglehorizontal; 
	if ( newtarget )
		hang = weapon.lockonanglehorizontal; 
	vang = weapon.lockonlossanglevertical; 
	if ( newtarget )
		vang = weapon.lockonanglevertical; 

	angles = self GetTargetScreenAngles( testOrigin );	

	return abs(angles[0]) < hang && abs(angles[1]) < vang; 
}

function inside_screen_crosshair_radius( testOrigin, weapon )
{
	radius = weapon.lockOnScreenRadius;

	return self inside_screen_radius( testOrigin, radius );
}

function inside_screen_lockon_radius( targetOrigin )
{
	radius = self getLockOnRadius();
	
	return self inside_screen_radius( targetOrigin, radius );
}

function inside_screen_radius( targetOrigin, radius )
{
	const useFov = 65;

	return Target_OriginIsInCircle( targetOrigin, self, useFov, radius );
}

function get_target_lock_on_origin( target )
{
	return self GetLockOnOrigin( target );	
}

	


