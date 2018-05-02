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
#using scripts\shared\ai\margwa;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statemachine.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\vehicles\_glaive.gsh;

#namespace glaive;

REGISTER_SYSTEM( "glaive", &__init__, undefined )

#using_animtree( "generic" );

#define SWORD_MODE_MINPOWER				0.0

function __init__()
{	
	vehicle::add_main_callback( "glaive", &glaive_initialize );
	clientfield::register( "vehicle", GLAIVE_BLOOD_FX, VERSION_SHIP, 1, "int" );
}

function glaive_initialize()
{
	self useanimtree( #animtree );

	//Target_Set( self, ( 0, 0, 0 ) );

	self.health = self.healthdefault;

	self vehicle::friendly_fire_shield();

	//self EnableAimAssist();
	self SetNearGoalNotifyDist( GLAIVE_NEAR_GOAL_DIST );

	self SetHoverParams( 0, 0, 40 );
	self playloopsound( "wpn_sword2_looper" );

	if ( isdefined( self.scriptbundlesettings ) )
	{
		self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}
	
	// AI SPECIFIC INITIALIZATION
	blackboard::CreateBlackBoardForEntity( self );
	self Blackboard::RegisterVehicleBlackBoardAttributes();

	self.fovcosine = 0; // +/-90 degrees = 180
	self.fovcosinebusy = 0.574;	//+/- 55 degrees = 110 fov

	self.vehAirCraftCollisionEnabled = false;

	self.goalRadius = 9999999;
	self.goalHeight = 512;
	self SetGoal( self.origin, false, self.goalRadius, self.goalHeight );

	self.overrideVehicleDamage = &glaive_callback_damage;
	self.allowFriendlyFireDamageOverride = &glaive_AllowFriendlyFireDamage;

	self.ignoreme = true;
	self._glaive_settings_lifetime = self.settings.lifetime;

	//self thread vehicle_ai::nudge_collision();

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
	self vehicle_ai::get_state_callbacks( "combat" ).enter_func = &state_combat_enter;
    self vehicle_ai::add_state( "slash",
		undefined,
		&state_slash_update,
		undefined );
    /#
	SetDvar( "debug_sword_threat_selection", 1 );
	#/
	//kick off target selection
	self thread glaive_target_selection();
	
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
	
	if( IS_TRUE( target._glaive_ignoreme ) )
	{
		return false;
	}
	
	if( IsDefined( target.archetype ) && target.archetype == ARCHETYPE_MARGWA )
	{
		if( !target margwaserverutils::margwaCanDamageAnyHead() )
		{
			return false;
		}
	}
	
	if( IsDefined( target.archetype ) && target.archetype == ARCHETYPE_ZOMBIE && !IS_TRUE( target.completed_emerging_into_playable_area ) )
	{
		return false;
	}

	if( DistanceSquared( self.owner.origin, target.origin ) > SQR( self.settings.guardradius ) )
	{
		return false;	
	}
	
	if( !SightTracePassed( self.origin, target.origin + ( 0, 0, 16 ), false, target ) )
	{
		return false;
	}
	
	return true;
}

//sets the glaive enemy
function private get_glaive_enemy()
{
	glaive_enemies = GetAITeamArray( "axis" );
	ArraySortClosest( glaive_enemies, self.owner.origin );
	
	foreach( glaive_enemy in glaive_enemies )
	{
		if( is_enemy_valid( glaive_enemy ) )
		{
			return glaive_enemy;
		}
	}
}

//thread that sets the enemy if no valid one exists currently
function private glaive_target_selection()
{
	self endon( "death" );
	
	for( ;; )
	{
		//glaive should always have an owner to do target selection
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
		if( GetDvarInt( "debug_sword_threat_selection", 0 ) )
		{
			if( IsDefined( self.glaiveEnemy ) )
			{
				line( self.origin, self.glaiveEnemy.origin, ( 1, 0, 0 ), 1.0, false, 5 );
			}
		}
		#/
		
		if( self is_enemy_valid( self.glaiveEnemy ) )
		{
			wait 0.25;
			continue;
		}
		
		if( IS_TRUE( self._glaive_must_return_to_owner ) )
		{
			wait 0.25;
			continue;
		}
		
		//decide who the enemy should be
		target = get_glaive_enemy();

		if( !isDefined( target ) )
		{
			self.glaiveEnemy = undefined;		
		}
		else
		{
			self.glaiveEnemy = target;
		}
		
		wait 0.25;
	}
}

function should_go_to_owner()
{
	b_is_lifetime_over = GetTime() - self.starttime > self._glaive_settings_lifetime * 1000;
		
	/*
		if( isDefined( self.owner ) )
		{
			if( IS_TRUE( self.owner.swordpreserve) )
			{
				b_is_lifetime_over = false;
			}
		}
	*/
	
	if( IS_TRUE( b_is_lifetime_over ) )
	{
		return true;
	}
	
	if( self.owner.sword_power <= SWORD_MODE_MINPOWER)
	{
		return true;
	}
	return false;
}

function should_go_to_near_owner()
{
	if( IsDefined( self.owner ) && DistanceSquared( self.origin, self.owner.origin ) > SQR( self.settings.guardradius ) )
	{
		return true;
	}
	if( IsDefined( self.owner ) && !self is_enemy_valid( self.glaiveEnemy ) )
	{
		if( Distance2DSquared( self.origin, self.owner.origin ) > SQR( 2 * GLAIVE_FOLLOW_DIST ) )
		{
			return true;
		}
		if( !util::within_fov( self.owner.origin, self.owner.angles, self.origin, cos( GLAIVE_FOV_ANGLE ) ) )
		{
			return true;
		}
	}
	return false;
}

// ----------------------------------------------
// State: combat
// ----------------------------------------------
function state_combat_enter( params )
{
	self ASMRequestSubstate( "idle@movement" );
}

function state_combat_update( params )
{
	self endon( "change_state" );
	self endon( "death" );

	pathfailcount = 0;

	while ( !isdefined( self.owner ) )
	{
		wait 0.1;

		if ( !isdefined( self.owner ) )
		{
			self.owner = GetPlayers( self.team )[0];
		}
	}

	for( ;; )
	{	
		if( self should_go_to_owner() || IS_TRUE( self._glaive_must_return_to_owner ) )
		{
			self._glaive_must_return_to_owner = true;
			//make sure the glaive kills its last enemy before returning
			if( !IsAlive( self.glaiveEnemy ) )
			{
				self go_to_owner();
			}
		}
		if( self should_go_to_near_owner() )
		{
			self go_to_near_owner();
		}
		else if( IsDefined( self.glaiveEnemy ) )
		{
			foundpath = false;

			targetPos = vehicle_ai::GetTargetPos( self.glaiveEnemy, true );
			
			//special location for margwa
			if( IsDefined( self.glaiveEnemy.archetype ) && self.glaiveEnemy.archetype == ARCHETYPE_MARGWA )
			{
				targetPos = self.glaiveEnemy GetTagOrigin( GLAIVE_MARGWA_AIM_TAG );
			}
			
			//add a little prediction to help the sword track better
			targetPos = targetPos + ( self.glaiveEnemy GetVelocity() * 0.4 );
			
			if ( isdefined( targetPos ) )
			{
				if( Distance2DSquared( self.origin, self.glaiveEnemy.origin ) < SQR( GLAIVE_MELEE_DIST ) )
				{
					self vehicle_ai::set_state( "slash" );
				}
				else if( IsDefined( self.owner ) && self is_enemy_valid( self.glaiveEnemy ) && self check_glaive_playable_area_conditions() )
				{
					go_back_on_navvolume();
					
					queryResult = PositionQuery_Source_Navigation( targetPos, 0, GLAIVE_MOVE_DIST_MAX, GLAIVE_MOVE_DIST_HEIGHT, GLAIVE_RADIUS * 0.4, self );
					
					if( IsDefined( self.glaiveEnemy ) )
					{
						PositionQuery_Filter_Sight( queryResult, targetPos, self GetEye() - self.origin, self, 0, self.glaiveEnemy );
					}
					
					if( IS_TRUE( queryResult.centerOnNav ) )
					{
						foreach ( point in queryResult.data )
						{
							if ( IS_TRUE( point.visibility ) )
							{
								self.current_pathto_pos = point.origin;

								foundpath = self SetVehGoalPos( self.current_pathto_pos, true, true );
								if ( foundpath )
								{
									//start playing locomotion
									self ASMRequestSubstate( "forward@movement" );
									self util::waittill_any( "near_goal", "goal" );
									//movement done go back to idle
									self ASMRequestSubstate( "idle@movement" );
									break;
								}
							}
						}
					}
					else
					{
						//special case for the elementals on the ground
						foreach ( point in queryResult.data )
						{
							if ( IS_TRUE( point.visibility ) )
							{
								self.current_pathto_pos = point.origin;

								foundpath = self SetVehGoalPos( self.current_pathto_pos, true, false );
								if ( foundpath )
								{
									//start playing locomotion
									self ASMRequestSubstate( "forward@movement" );
									self util::waittill_any( "near_goal", "goal" );
									//movement done go back to idle
									self ASMRequestSubstate( "idle@movement" );
									break;
								}
							}
						}
					}
				}
			}

			if ( !foundpath && self is_enemy_valid( self.glaiveEnemy ) )
			{
				go_back_on_navvolume();

				pathfailcount++;

				if ( pathfailcount > 3 )
				{
					if ( isdefined( self.owner ) )
					{
						self go_to_near_owner();
					}
				}
				wait 0.1;
			}
			else
			{
				pathfailcount = 0;
			}
		}

		wait 0.2;
	}
}

function check_glaive_playable_area_conditions()
{
	if( IsDefined( self.glaiveEnemy.archetype ) && self.glaiveEnemy.archetype != ARCHETYPE_ZOMBIE )
	{
		return true;
	}
	else if( IsDefined( self.glaiveEnemy.archetype ) && self.glaiveEnemy.archetype == ARCHETYPE_ZOMBIE && IS_TRUE( self.glaiveEnemy.completed_emerging_into_playable_area ) )
	{
		return true;
	}
	
	return false;
}

function go_back_on_navvolume()
{
	// try to path straight to a nearby position on the nav volume
	queryResult = PositionQuery_Source_Navigation( self.origin, 0, 100, GLAIVE_MOVE_DIST_HEIGHT, GLAIVE_RADIUS * 0.4, self );

	multiplier = 2;
	while ( queryResult.data.size < 1 )
	{
		queryResult = PositionQuery_Source_Navigation( self.origin, 0, 100 * multiplier, GLAIVE_MOVE_DIST_HEIGHT * multiplier, GLAIVE_RADIUS * multiplier, self );
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
				self util::waittill_any( "goal", "near_goal" );
			}
			
			self SetNearGoalNotifyDist( GLAIVE_NEAR_GOAL_DIST );
		}
	}
}

function chooseSwordAnim( enemy )
{
	self endon( "change_state" );
	self endon( "death" );
	
	sword_anim = "o_zombie_zod_sword_projectile_melee_synced_a";
	self._glaive_linkToTag = "tag_origin";
	
	if( IsDefined( enemy.archetype ) )
	{
	   	switch( enemy.archetype )
		{
			case ARCHETYPE_PARASITE: 
				sword_anim = "o_zombie_zod_sword_projectile_melee_parasite_synced_a";
				break;
			case ARCHETYPE_RAPS:
				sword_anim = "o_zombie_zod_sword_projectile_melee_elemental_synced_a";
				break;
			case ARCHETYPE_MARGWA:
				sword_anim = "o_zombie_zod_sword_projectile_melee_margwa_m_synced_a";
				self._glaive_linkToTag = "tag_sync";
				break;
		}
	}
	
	return sword_anim;
}

function state_slash_update( params )
{
	self endon( "change_state" );
	self endon( "death" );
	
	enemy = self.glaiveEnemy;
	should_reevaluate_target = false;
	sword_anim = self chooseSwordAnim( enemy );

	self AnimScripted( "anim_notify", enemy GetTagOrigin( self._glaive_linkToTag ), enemy GetTagAngles( self._glaive_linkToTag ), sword_anim, "normal", undefined, undefined, 0.3, 0.3 );
	
	self clientfield::set( GLAIVE_BLOOD_FX, 1 );
	self waittill( "anim_notify" );
	
	if( IsAlive( enemy ) && IsDefined( enemy.archetype ) && enemy.archetype == ARCHETYPE_MARGWA )
	{
		if ( IsDefined( enemy.chop_actor_cb ) )
        {
			should_reevaluate_target = true;
			enemy._glaive_ignoreme = true;
			enemy thread glaive_ignore_cooldown( GLAIVE_IGNORE_ENT_COOLDOWN );
			self.owner [[ enemy.chop_actor_cb ]]( enemy, self, self.weapon );
        }
	}
	else
	{	
		target_enemies = GetAITeamArray( "axis" );
		foreach( target in target_enemies )
		{
			if( Distance2DSquared( self.origin, target.origin ) < SQR( 128 ) )
			{
				if( IsDefined( target.archetype ) && target.archetype == ARCHETYPE_MARGWA )
				{
					continue;
				}
				target DoDamage( target.health + 100, self.origin, self.owner, self, "none", "MOD_UNKNOWN", 0, self.weapon );
				self playsound( "wpn_sword2_imp" );
				if( IsActor( target ) )
				{
					target zombie_utility::gib_random_parts();
					target StartRagdoll();
					target LaunchRagdoll( 100 * VectorNormalize( target.origin - self.origin ) );
				}
			}
		}
	}	

	self waittill( "anim_notify", notetrack );
	while ( !isdefined( notetrack ) || notetrack != "end" )
	{
		self waittill( "anim_notify", notetrack );
	}
	
	self clientfield::set( GLAIVE_BLOOD_FX, 0 );
	
	if( should_reevaluate_target )
	{
		//decide who the enemy should be
		target = get_glaive_enemy();
		self.glaiveEnemy = target;		
	}
		
	self vehicle_ai::set_state( "combat" );
}

function glaive_ignore_cooldown( duration )
{
	self endon( "death" );
	
	wait( duration );
	
	self._glaive_ignoreme = undefined;
}

function go_to_near_owner()
{
	self endon( "near_owner" );
	
	self thread back_to_near_owner_check();
	
	starttime = GetTime();
	
	//start playing locomotion animation
	self ASMRequestSubstate( "forward@movement" );
	
	while ( GetTime() - starttime < self._glaive_settings_lifetime * 1000 * 0.1 )
	{
		go_back_on_navvolume();

		ownerTargetPos = vehicle_ai::GetTargetPos( self.owner, true ) - ( 0, 0, 4 ); //slightly below eye level
		
		//get a desired target little ahead of the owner
		ownerForwardVec = AnglesToForward( self.owner.angles );
		targetPos = ownerTargetPos + GLAIVE_FOLLOW_DIST * ownerForwardVec;
		
		//get search center
		searchCenter = self GetClosestPointOnNavVolume( ownerTargetPos );
		if( IsDefined( searchCenter ) )
		{
			queryResult = PositionQuery_Source_Navigation( searchCenter, 0, GLAIVE_MOVE_DIST_MAX + GLAIVE_FOLLOW_DIST, GLAIVE_MOVE_DIST_HEIGHT * 0.5, GLAIVE_RADIUS * 0.6, self );
	
			foundPath = false;
	
			foreach ( point in queryResult.data )
			{	
				ADD_POINT_SCORE( point, "score", -DistanceSquared( point.origin, targetPos ) );
			}
			
			vehicle_ai::PositionQuery_PostProcess_SortScore( queryResult );
			self vehicle_ai::PositionQuery_DebugScores( queryResult );
				
			foreach( point in queryResult.data )
			{	
				self.current_pathto_pos = point.origin;
				foundpath = self SetVehGoalPos( self.current_pathto_pos, true, true );
				if ( foundpath )
				{
					break;
				}
			}
			
			if( !foundpath )
			{
				self.current_pathto_pos = searchCenter;
				self SetVehGoalPos( self.current_pathto_pos, true, true );
			}
		}
		
		wait 1;
	}
	//probably reached owner, go into idle
	self ASMRequestSubstate( "idle@movement" );
}

function go_to_owner()
{	
	self thread back_to_owner_check();

	starttime = GetTime();
	
	//start playing locomotion animation
	self ASMRequestSubstate( "forward@movement" );
	
	while ( GetTime() - starttime < self._glaive_settings_lifetime * 1000 * 0.3 )
	{
		go_back_on_navvolume();

		targetPos = vehicle_ai::GetTargetPos( self.owner, true );
		queryResult = PositionQuery_Source_Navigation( targetPos, 0, GLAIVE_MOVE_DIST_MAX, GLAIVE_MOVE_DIST_HEIGHT, GLAIVE_RADIUS * 0.4, self );

		foundPath = false;
		trace_count = 0;
		foreach ( point in queryResult.data )
		{
			if( SightTracePassed( self.origin, point.origin, false, undefined ) )
			{
				trace_count++;
				if( trace_count > 3 )
				{
					WAIT_SERVER_FRAME; //this is to ensure we don't do more than 3 bullet traces a server frame
					trace_count = 0;
				}
				if( !BulletTracePassed( self.origin, point.origin, false, self ) )
				{
					continue;
				}
			}
			else
			{
				continue;
			}
				
			self.current_pathto_pos = point.origin;
			foundpath = self SetVehGoalPos( self.current_pathto_pos, true, true );
			if ( foundpath )
			{
				break;
			}
		}

		if ( !foundPath )
		{
			foreach ( point in queryResult.data )
			{
				self.current_pathto_pos = point.origin;
				foundpath = self SetVehGoalPos( self.current_pathto_pos, true, false );
				if ( foundpath )
				{
					break;
				}
			}
		}

		wait 1;
	}
	
	if ( isdefined( self.owner ) )
	{
		self.origin = self.owner.origin + ( 0, 0, GLAIVE_MELEE_DIST * 0.5 );
	}
	self notify( "returned_to_owner" );

	wait 2;
}

function back_to_owner_check()
{
	self endon( "death" );

	while ( isdefined( self.owner ) && ( Abs( self.origin[2] - self.owner.origin[2] ) > SQR( GLAIVE_MELEE_DIST ) || Distance2DSquared( self.origin, self.owner.origin ) > SQR( GLAIVE_MELEE_DIST ) ) )
	{
		wait 0.1;
	}
	
	self notify( "returned_to_owner" );
}

function back_to_near_owner_check()
{
	self endon( "death" );

	while ( isdefined( self.owner ) && ( Abs( self.origin[2] - self.owner.origin[2] ) > SQR( 2 * GLAIVE_FOLLOW_DIST ) || Distance2DSquared( self.origin, self.owner.origin ) > SQR( 2 * GLAIVE_FOLLOW_DIST )  || !util::within_fov( self.owner.origin, self.owner.angles, self.origin, cos( GLAIVE_FOV_ANGLE ) ) ) )
	{
		wait 0.1;
	}
	
	//reached owner, go into idle
	self ASMRequestSubstate( "idle@movement" );
	self notify( "near_owner" );
}

function glaive_AllowFriendlyFireDamage( eInflictor, eAttacker, sMeansOfDeath, weapon )
{
	return false;
}

function glaive_callback_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, psOffsetTime, damageFromUnderneath, modelIndex, partName, vSurfaceNormal )
{
	return 1;
}
