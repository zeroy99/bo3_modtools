#using scripts\codescripts\struct;

#using scripts\shared\math_shared;
#using scripts\shared\statemachine_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicle_death_shared;
#using scripts\shared\vehicle_ai_shared;

#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\blackboard_vehicle;
#using scripts\shared\animation_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#define DRAGON_FOV_ANGLE								60
	
#define DRAGON_MOVE_DIST_HEIGHT							90

#define DRAGON_FOLLOW_DIST								80
	
#define DRAGON_MELEE_DIST								400

#namespace dragon;

REGISTER_SYSTEM( "dragon", &__init__, undefined )

#using_animtree( "generic" );

function __init__()
{	
	vehicle::add_main_callback( "dragon", &dragon_initialize );
}

function dragon_initialize()
{
	self useanimtree( #animtree );

	//Target_Set( self, ( 0, 0, 0 ) );

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	if ( isdefined( self.scriptbundlesettings ) )
	{
		self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}

	assert( isdefined( self.settings ) );

	//self EnableAimAssist();
	self SetNearGoalNotifyDist( self.radius * 1.5 );
	self SetHoverParams( self.radius, self.settings.defaultMoveSpeed * 2, self.radius );
	self SetSpeed( self.settings.defaultMoveSpeed );
	
	// AI SPECIFIC INITIALIZATION
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();

	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0;	//+/- 55 degrees = 110 fov

	self.vehAirCraftCollisionEnabled = false;
	//self thread vehicle_ai::nudge_collision();

	self.goalRadius = 9999999;
	self.goalHeight = 512;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );
	self.delete_on_death = true;

	self.overrideVehicleDamage = &dragon_callback_damage;
	self.allowFriendlyFireDamageOverride = &dragon_AllowFriendlyFireDamage;

	self.ignoreme = true;

	if( IsDefined( level.vehicle_initializer_cb ) )
	{
    	[[level.vehicle_initializer_cb]]( self );
	}
	
	defaultRole();
}

function defaultRole()
{
	self vehicle_ai::init_state_machine_for_role( "default" );

    self vehicle_ai::get_state_callbacks( "combat" ).update_func = &state_combat_update;
    self vehicle_ai::get_state_callbacks( "death" ).update_func = &state_death_update;

    if ( SessionModeIsZombiesGame() )
    {
		self vehicle_ai::add_state( "power_up",
			undefined,
			&state_power_up_update,
			undefined );
	
		self vehicle_ai::add_utility_connection( "combat", "power_up", &should_go_for_power_up );
		self vehicle_ai::add_utility_connection( "power_up", "combat" );
    }

    /#
	SetDvar( "debug_dragon_threat_selection", 0 );
	#/

	//kick off target selection
	self thread dragon_target_selection();
	
	vehicle_ai::StartInitialState( "combat" );
	self.startTime = GetTime();
}

//function that validates if enemies are appropriate
function private is_enemy_valid( target )
{
	if( !IsDefined( target ) )
	{
		return false;
	}
	
	if( !IsAlive( target ) )
	{
		return false; 
	} 
	
	if( IS_TRUE(self.intermission) )
	{
		return false;
	}
	
	if( IS_TRUE( target.ignoreme ) )
	{
		return false;
	}
	
	if( target IsNoTarget() )
	{
		return false;
	}
	
	if( IS_TRUE( target._dragon_ignoreme ) )
	{
		return false;
	}
	
	/*
	if( IsDefined( target.archetype ) && target.archetype == ARCHETYPE_MARGWA )
	{
		if( !target margwaserverutils::margwaCanDamageAnyHead() )
		{
			return false;
		}
	}
	
	if( IsDefined( target.archetype ) && target.archetype == ARCHETYPE_ZOMBIE ) && !IS_TRUE( target.completed_emerging_into_playable_area ) )
	{
		return false;
	}
	*/

	if( DistanceSquared( self.owner.origin, target.origin ) > SQR( self.settings.guardradius ) )
	{
		return false;	
	}
	
	if ( self VehCanSee( target ) )
	{
		return true;
	}

	if ( IsActor( target ) && target CanSee( self.owner ) )
	{
		return true;
	}
	
	if ( IsVehicle( target ) && target VehCanSee( self.owner ) )
	{
		return true;
	}

	return false;
}

//sets the dragon enemy
function private get_dragon_enemy()
{
	dragon_enemies = GetAITeamArray( "axis" );
	
	distSqr = SQR( 10000 );
	best_enemy = undefined;
	foreach( enemy in dragon_enemies )
	{
		newDistSqr = Distance2DSquared( enemy.origin, self.owner.origin );
		if( is_enemy_valid( enemy ) )
		{
			if ( enemy.archetype === ARCHETYPE_RAZ )
			{
				newDistSqr = Max( Distance2D( enemy.origin, self.owner.origin ) - 700, 0 );
				newDistSqr = SQR( newDistSqr );
			}
			else if ( enemy.archetype === ARCHETYPE_SENTINEL_DRONE )
			{
				newDistSqr = Max( Distance2D( enemy.origin, self.owner.origin ) - 500, 0 );
				newDistSqr = SQR( newDistSqr );
			}
			else if ( enemy === self.dragonEnemy )
			{
				newDistSqr = Max( Distance2D( enemy.origin, self.owner.origin ) - 300, 0 );
				newDistSqr = SQR( newDistSqr );
			}

			if ( newDistSqr < distSqr )
			{
				distSqr = newDistSqr;
				best_enemy = enemy;
			}
		}
	}

	return best_enemy;
}

//thread that sets the enemy if no valid one exists currently
function private dragon_target_selection()
{
	self endon( "death" );
	
	for( ;; )
	{
		//dragon should always have an owner to do target selection
		if( !IsDefined( self.owner ) )
		{
			wait 0.25;
			continue;
		}
		
		if ( IS_TRUE( self.ignoreall ) )
		{
			wait 0.25;
			continue;
		}
		
		/#
		//debug sword threat selection
		if( GetDvarInt( "debug_dragon_threat_selection", 0 ) )
		{
			if( IsDefined( self.dragonEnemy ) )
			{
				line( self.origin, self.dragonEnemy.origin, ( 1, 0, 0 ), 1.0, false, 5 );
			}
		}
		#/
		
		//decide who the enemy should be
		target = get_dragon_enemy();

		if( !isDefined( target ) )
		{
			self.dragonEnemy = undefined;		
		}
		else
		{
			self.dragonEnemy = target;
		}
		
		wait 0.25;
	}
}

// ----------------------------------------------
// State: power_up
// ----------------------------------------------
function state_power_up_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	closest_distSqr = SQR( 10000 );
	closest = undefined;
	foreach( powerup in level.active_powerups )
	{
		powerup.navVolumeOrigin = self GetClosestPointOnNavVolume( powerup.origin, 100 );
		if ( !isdefined( powerup.navVolumeOrigin ) )
		{
			continue;
		}

		distSqr = DistanceSquared( powerup.origin, self.origin );
		if ( distSqr < closest_distSqr )
		{
			closest_distSqr = distSqr;
			closest = powerup;
		}
	}

	if ( isdefined( closest ) && distSqr < SQR( 2000 ) )
	{
		self SetVehGoalPos( closest.navVolumeOrigin, true, true );
		if ( vehicle_ai::waittill_pathresult() )
		{
			self vehicle_ai::waittill_pathing_done();
		}

		if ( isdefined( closest ) )
		{
			trace = BulletTrace( self.origin, closest.origin, false, self );
			if( trace["fraction"] == 1 )
			{
				self SetVehGoalPos( closest.origin, true, false );
			}
		}
	}

	self vehicle_ai::evaluate_connections();
}

function should_go_for_power_up( from_state, to_state, connection )
{
	if ( level.whelp_no_power_up_pickup === true )
	{
		return false;
	}

	if ( isdefined( self.dragonEnemy ) )
	{
		return false;
	}

	if ( level.active_powerups.size < 1 )
	{
		return false;
	}

	return true;
}

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	idealDistToOwner = 300;

	self ASMRequestSubstate( "locomotion@movement" );

	while ( !isdefined( self.owner ) )
	{
		WAIT_SERVER_FRAME;
	}

	self thread attack_thread();

	for( ;; )
	{
		self SetSpeed( self.settings.defaultMoveSpeed );
		self ASMRequestSubstate( "locomotion@movement" );

		if ( IsDefined( self.owner ) && Distance2DSquared( self.origin, self.owner.origin ) < SQR( idealDistToOwner ) && IsPointInNavVolume( self.origin, "navvolume_small" ) )
		{
			if ( !isdefined( self.current_pathto_pos ) )
			{
				self.current_pathto_pos = self GetClosestPointOnNavVolume( self.origin, 100 );
			}

			self SetVehGoalPos( self.current_pathto_pos, true, false );
			wait 0.1;
			continue;
		}

		if( IsDefined( self.owner ) )
		{
			queryResult = PositionQuery_Source_Navigation( self.origin, 0, 256, DRAGON_MOVE_DIST_HEIGHT, self.radius, self );
			
			sightTarget = undefined;
			if ( isdefined( self.dragonEnemy ) )
			{
				sightTarget = self.dragonEnemy GetEye();
				PositionQuery_Filter_Sight( queryResult, sightTarget, (0,0,0), self, 4 );
			}
			
			if( IS_TRUE( queryResult.centerOnNav ) )
			{
				ownerOrigin = self.owner.origin;
				ownerForward = AnglesToForward( self.owner.angles );

				// score points
				best_point = undefined;
				best_score = -999999;

				foreach ( point in queryResult.data )
				{
					distSqr = Distance2DSquared( point.origin, ownerOrigin );
					if ( distSqr > SQR( idealDistToOwner ) )
					{
						ADD_POINT_SCORE( point, "distToOwner", -Sqrt( distSqr ) * 2 );
					}

					if ( IS_TRUE( point.visibility ) )
					{
						if ( BulletTracePassed( point.origin, sightTarget, false, self ) )
						{
							ADD_POINT_SCORE( point, "visibility", 400 );
						}
					}

					vecToOwner = point.origin - ownerOrigin;
					dirToOwner = VectorNormalize( FLAT_ORIGIN( vecToOwner ) );
					if ( VectorDot( ownerForward, dirToOwner ) > 0.34 ) // 0.34 = cos(70)
					{
						if ( Abs( vecToOwner[2] ) < 100 )
						{
							ADD_POINT_SCORE( point, "frontOfPlayer", 300 );
						}
						else if ( Abs( vecToOwner[2] ) < 200 )
						{
							ADD_POINT_SCORE( point, "frontOfPlayer", 100 );
						}
					}

					if ( point.score > best_score )
					{
						best_score = point.score;
						best_point = point;
					}
				}

				self vehicle_ai::PositionQuery_DebugScores( queryResult );

				if ( isdefined( best_point ) )
				{
					/#
					if ( IS_TRUE( GetDvarInt("hkai_debugPositionQuery") ) )
					{
						recordLine( self.origin, best_point.origin, (0.3,1,0) );
						recordLine( self.origin, self.owner.origin, (1,0,0.4) );
					}
					#/

					if ( DistanceSquared( self.origin, best_point.origin ) > SQR( 50 ) )
					{
						self.current_pathto_pos = best_point.origin;

						self SetVehGoalPos( self.current_pathto_pos, true, true );
						self vehicle_ai::waittill_pathing_done( 5 );
					}
					else
					{
						self vehicle_ai::Cooldown( "move_cooldown", 4 );
					}
				}
			}
			else
			{
				go_back_on_navvolume();
			}
		}

		wait 0.1;
	}
}

function attack_thread()
{
	self endon( "change_state" );
	self endon( "death" );

	for( ;; )
	{
		wait 0.1;

		self vehicle_ai::evaluate_connections();

		if ( !self vehicle_ai::IsCooldownReady( "attack" ) )
		{ 
			continue;
		}

		if ( !IsDefined( self.dragonEnemy ) )
		{
			continue;
		}

		self SetLookAtEnt( self.dragonEnemy );

		if ( !self VehCanSee( self.dragonEnemy ) )
		{
			continue;
		}
		
		if ( Distance2DSquared( self.dragonEnemy.origin, self.owner.origin ) > SQR( self.settings.guardradius ) )
		{
			continue;
		}

		eyeOffset = ( self.dragonEnemy GetEye() - self.dragonEnemy.origin ) * 0.6;

		if ( !BulletTracePassed( self.origin, self.dragonEnemy GetEye() - eyeOffset, false, self, self.dragonEnemy ) )
		{
			self.dragonEnemy = undefined;
			continue;
		}

		aimOffset = self.dragonEnemy GetVelocity() * 0.3 - eyeOffset;
		self SetTurretTargetEnt( self.dragonEnemy, aimOffset );

		wait 0.2;

		if ( isdefined( self.dragonEnemy ) )
		{
			self FireWeapon( 0, self.dragonEnemy, (0,0,0), self );
			self vehicle_ai::Cooldown( "attack", 1 );
		}

		//self util::waittill_notify_or_timeout( "wing_start", 1 );
		//self ASMRequestSubstate( "fire@stationary" );
		//self vehicle_ai::waittill_asm_complete( "fire@stationary", 3 );
		//self ASMRequestSubstate( "locomotion@movement" );

	}
}

function go_back_on_navvolume()
{
	// try to path straight to a nearby position on the nav volume
	queryResult = PositionQuery_Source_Navigation( self.origin, 0, 100, DRAGON_MOVE_DIST_HEIGHT, self.radius, self );

	multiplier = 2;
	while ( queryResult.data.size < 1 )
	{
		queryResult = PositionQuery_Source_Navigation( self.origin, 0, 100 * multiplier, DRAGON_MOVE_DIST_HEIGHT * multiplier, self.radius * multiplier, self );
		multiplier += 2;
	}

	if ( queryResult.data.size && !queryResult.centerOnNav )
	{
		best_point = undefined;
		best_score = 999999;

		foreach ( point in queryResult.data )
		{
			point.score = Abs( point.origin[2] - queryResult.origin[2] );

			if ( point.score < best_score )
			{
				best_score = point.score;
				best_point = point;
			}
		}
		
		if( IsDefined( best_point ) )
		{
			//force it to move to favorable point
			self SetNearGoalNotifyDist( 2 );
			
			point = best_point;

			self.current_pathto_pos = point.origin;

			foundpath = self SetVehGoalPos( self.current_pathto_pos, true, false );
			if( foundpath )
			{
				self vehicle_ai::waittill_pathing_done( 5 );
			}
			
			self SetNearGoalNotifyDist( self.radius );
		}
	}
}

function dragon_AllowFriendlyFireDamage( eInflictor, eAttacker, sMeansOfDeath, weapon )
{
	return false;
}

function dragon_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	if( self.dragon_recall_death !== true )
	{
		return 0;
	}
	
	return iDamage;
}

// ----------------------------------------------
// State: death
// ----------------------------------------------
function state_death_update( params )
{
	self endon ( "death" );

	attacker = params.inflictor;
	if( !isdefined( attacker ) )
	{
		attacker = params.attacker;
	}
	
	if( attacker !== self && ( !isdefined( self.owner ) || ( self.owner !== attacker ) ) && ( IsAI( attacker) || IsPlayer( attacker ) ) )
	{
		self.damage_on_death = false;
		WAIT_SERVER_FRAME;

		// need to retest for attacker validity because of the wait
		attacker = params.inflictor;
		if( !isdefined( attacker ) )
		{
			attacker = params.attacker;
		}
	}

	self vehicle_ai::defaultstate_death_update();
}
