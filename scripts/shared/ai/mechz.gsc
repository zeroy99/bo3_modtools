#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\_burnplayer;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\archetype_mocomps_utility;

#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\mechz.gsh; 
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "xmodel", MECHZ_MODEL_ARMOR_KNEE_LEFT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_KNEE_RIGHT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_SHOULDER_LEFT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_SHOULDER_RIGHT );
#precache( "xmodel", MECHZ_MODEL_FACEPLATE );
#precache( "xmodel", MECHZ_MODEL_POWERSUPPLY );
#precache( "xmodel", MECHZ_MODEL_CLAW );

#define PERK_JUGGERNOG	"specialty_armorvest"

#namespace MechzBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitMechzBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_MECHZ, &ArchetypeMechzBlackboardInit );

	// INIT MECHZ ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_MECHZ, &MechzServerUtils::mechzSpawnSetup );

	clientfield::register( "actor", MECHZ_FT_CLIENTFIELD, VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_faceplate_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_powercap_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_claw_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_115_gun_firing", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_rknee_armor_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_lknee_armor_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_rshoulder_armor_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_lshoulder_armor_detached", VERSION_DLC1, 1, "int" );
	clientfield::register( "actor", "mechz_headlamp_off", VERSION_DLC1, 2, "int" );

	clientfield::register( "actor", MECHZ_FACE_CLIENTFIELD, VERSION_SHIP, 3, "int" );
}

function private InitMechzBehaviorsAndASM()
{
	// SERVICES
	BT_REGISTER_API( "mechzTargetService", 				&MechzBehavior::mechzTargetService );
	BT_REGISTER_API( "mechzGrenadeService", 			&MechzBehavior::mechzGrenadeService );
	BT_REGISTER_API( "mechzBerserkKnockdownService", 	&MechzBehavior::mechzBerserkKnockdownService );

	// CONDITIONS
	BT_REGISTER_API( "mechzShouldMelee", 				&MechzBehavior::mechzShouldMelee );
	BT_REGISTER_API( "mechzShouldShowPain", 			&MechzBehavior::mechzShouldShowPain );
	BT_REGISTER_API( "mechzShouldShootGrenade",			&MechzBehavior::mechzShouldShootGrenade );
	BT_REGISTER_API( "mechzShouldShootFlame",			&MechzBehavior::mechzShouldShootFlame );
	BT_REGISTER_API( "mechzShouldShootFlameSweep",		&MechzBehavior::mechzShouldShootFlameSweep );
	BT_REGISTER_API( "mechzShouldTurnBerserk",			&MechzBehavior::mechzShouldTurnBerserk );
	BT_REGISTER_API( "mechzShouldStun", 				&MechzBehavior::mechzShouldStun );
	BT_REGISTER_API( "mechzShouldStumble", 				&MechzBehavior::mechzShouldStumble );

	// ACTIONS
	BT_REGISTER_ACTION( "mechzStunLoop",				&MechzBehavior::mechzStunStart, &MechzBehavior::mechzStunUpdate, &MechzBehavior::mechzStunEnd );
	BT_REGISTER_ACTION( "mechzStumbleLoop",				&MechzBehavior::mechzStumbleStart, &MechzBehavior::mechzStumbleUpdate, &MechzBehavior::mechzStumbleEnd );
	BT_REGISTER_ACTION( "mechzShootFlameAction",		&MechzBehavior::mechzShootFlameActionStart, &MechzBehavior::mechzShootFlameActionUpdate, &MechzBehavior::mechzShootFlameActionEnd );

	// FUNCTIONS
	BT_REGISTER_API( "mechzShootGrenade",				&MechzBehavior::mechzShootGrenade );
	BT_REGISTER_API( "mechzShootFlame",					&MechzBehavior::mechzShootFlame );
	BT_REGISTER_API( "mechzUpdateFlame",				&MechzBehavior::mechzUpdateFlame );
	BT_REGISTER_API( "mechzStopFlame",					&MechzBehavior::mechzStopFlame );
	BT_REGISTER_API( "mechzPlayedBerserkIntro",			&MechzBehavior::mechzPlayedBerserkIntro );

	BT_REGISTER_API( "mechzAttackStart", 				&MechzBehavior::mechzAttackStart );
	BT_REGISTER_API( "mechzDeathStart", 				&MechzBehavior::mechzDeathStart );
	BT_REGISTER_API( "mechzIdleStart", 					&MechzBehavior::mechzIdleStart );
	BT_REGISTER_API( "mechzPainStart", 					&MechzBehavior::mechzPainStart );
	BT_REGISTER_API( "mechzPainTerminate", 				&MechzBehavior::mechzPainTerminate );

	// MOCOMPS

	// NOTETRACKS
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_MECHZ_MELEE_NOTETRACK, &MechzBehavior::mechzNotetrackMelee );
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_MECHZ_GRENADE_NOTETRACK, &MechzBehavior::mechzNotetrackShootGrenade );
}

function private ArchetypeMechzBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE MECHZ BLACKBOARD
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,		LOCOMOTION_SPEED_RUN,				undefined );
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SHOULD_TURN,		SHOULD_NOT_TURN,					&BB_GetShouldTurn );
	BB_REGISTER_ATTRIBUTE( ZOMBIE_DAMAGEWEAPON_TYPE,	ZOMBIE_DAMAGEWEAPON_REGULAR,		undefined );
	BB_REGISTER_ATTRIBUTE( MECHZ_PART,					MECHZ_PART_POWERCORE,				undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeMechzOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private ArchetypeMechzOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeMechzBlackboardInit();
}

function private BB_GetShouldTurn()
{
	if( IsDefined( self.should_turn ) && self.should_turn )
	{
		return SHOULD_TURN;
	}
	return SHOULD_NOT_TURN;
}

//----------------------------------------------------------------------------------------------------------------------------
// NOTETRACK HANDLERS
//----------------------------------------------------------------------------------------------------------------------------
function private mechzNotetrackMelee( entity )
{
	if( isDefined( entity.mechz_melee_knockdown_function ))
	{
		entity thread [[ entity.mechz_melee_knockdown_function ]]();
	}
	entity Melee();
}

function private mechzNotetrackShootGrenade( entity )
{
	if ( !IsDefined( entity.enemy ) )
	{
		return;
	}

//	shoot_angle = RandomIntRange( MECHZ_GRENADE_DEVIATION_YAW_MIN, MECHZ_GRENADE_DEVIATION_YAW_MAX );
//	up_angle = RandomIntRange( MECHZ_GRENADE_DEVIATION_PITCH_MIN, MECHZ_GRENADE_DEVIATION_PITCH_MAX );
	
	base_target_pos = entity.enemy.origin;
	v_velocity = entity.enemy GetVelocity();
	base_target_pos = base_target_pos + ( v_velocity * MECHZ_GRENADE_TARGET_PREDICTION_TIME );
	
	target_pos_offset_x = math::randomsign() * randomint( MECHZ_GRENADE_DEVIATION_RADIUS );
	target_pos_offset_y = math::randomsign() * randomint( MECHZ_GRENADE_DEVIATION_RADIUS );
	
	target_pos = base_target_pos + ( target_pos_offset_x, target_pos_offset_y, 0 );

	dir = VectorToAngles( target_pos - entity.origin );
//	dir = ( dir[0] - up_angle, dir[1] + shoot_angle, dir[2] );
	dir = AnglesToForward( dir );
	
	launch_offset = (dir * 5);
	
	launch_pos = entity GetTagOrigin( MECHZ_GRENADE_TAG ) + launch_offset;

	dist = Distance( launch_pos, target_pos );
	
	velocity = dir * dist;
	velocity = velocity + (0,0,120);
	
	val = 1;
	oldval = entity clientfield::get( "mechz_115_gun_firing" );
	if( oldval === val )
	{
		val = 0;
	}	
	
	entity clientfield::set( "mechz_115_gun_firing", val );
	

	entity MagicGrenadeType( GetWeapon(MECHZ_GRENADE_TYPE), launch_pos, velocity );
	PlaySoundAtPosition ("wpn_grenade_fire_mechz", entity.origin);
} 

//----------------------------------------------------------------------------------------------------------------------------
// BEHAVIOR TREE
//----------------------------------------------------------------------------------------------------------------------------
function mechzTargetService( entity )
{
	if ( IS_TRUE( entity.ignoreall ) )
	{
		return false;
	}

	if ( IsDefined( entity.destroy_octobomb ) )
	{
		return false;
	}

	player = zombie_utility::get_closest_valid_player( self.origin, self.ignore_player );

	entity.favoriteenemy = player;

	if( !IsDefined( player ) || player IsNoTarget() )
	{
		if( IsDefined( entity.ignore_player ) )
		{
			if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
			{
				return;
			}
			entity.ignore_player = [];
		}
		
		/#if ( IS_TRUE( level.b_mechz_true_ignore ) )
		{
			entity SetGoal( entity.origin );
			return false;
		}#/

		if( isdefined( level.no_target_override ) )
		{
			[[ level.no_target_override ]]( entity );			
		}
		else
		{
			entity SetGoal( entity.origin );
		}
				
		return false;
	}
	else
	{
		
		if( isDefined( level.enemy_location_override_func ))
		{
			enemy_ground_pos = [[level.enemy_location_override_func]]( entity, player);
			if( isDefined( enemy_ground_pos ))
			{
				entity SetGoal( enemy_ground_pos);
				return true;
			}
		}
		
		targetPos = GetClosestPointOnNavMesh( player.origin, MECHZ_NAVMESH_RADIUS, MECHZ_NAVMESH_BOUNDARY_DIST );
		if ( IsDefined( targetPos ) )
		{
			entity SetGoal( targetPos );		
			return true;
		}
		else
		{
			entity SetGoal( entity.origin );
			return false;
		}
	}
}

function private mechzGrenadeService( entity )
{
	if( !isDefined( entity.burstGrenadesFired ))
	{
		entity.burstGrenadesFired = 0;
	}
		   	
	if ( entity.burstGrenadesFired >= MECHZ_GRENADE_BURST_SIZE )
	{
		if ( GetTime() > entity.nextGrenadeTime ) 
		{
			entity.burstGrenadesFired = 0;
		}
	}
	
	if( isDefined( level.a_electroball_grenades ))
	{
		level.a_electroball_grenades = array::remove_undefined( level.a_electroball_grenades );
		
		a_active_grenades = array::filter( level.a_electroball_grenades, false, &mechzFilterGrenadesByOwner, entity );
		entity.activeGrenades = a_active_grenades.size;
	}
	else
	{
		entity.activeGrenades = 0;
	}
	
}

function private mechzFilterGrenadesByOwner( grenade, mechz )
{
	if( grenade.owner === mechz )
	{
		return true;
	}
	
	return false;
		
}

function private mechzBerserkKnockdownService( entity )
{
	velocity = entity GetVelocity();
	predict_time = 0.3;
	predicted_pos = entity.origin + ( velocity * predict_time );
	move_dist_sq = DistanceSquared( predicted_pos, entity.origin );
	speed = move_dist_sq /  predict_time;
	
	if( speed >= 10 )
	{
		a_zombies = GetAIArchetypeArray( ARCHETYPE_ZOMBIE );
		
		a_filtered_zombies = array::filter( a_zombies, false, &mechzZombieEligibleForBerserkKnockdown, entity, predicted_pos );
		
		if( a_filtered_zombies.size > 0 )
		{
			foreach( zombie in a_filtered_zombies )
			{
				zombie.knockdown = true;
				zombie.knockdown_type = KNOCKDOWN_SHOVED;
				zombie_to_mechz = entity.origin - zombie.origin;
				zombie_to_mechz_2d = VectorNormalize( ( zombie_to_mechz[0], zombie_to_mechz[1], 0 ) );
				
				zombie_forward = AnglesToForward( zombie.angles );
				zombie_forward_2d = VectorNormalize( ( zombie_forward[0], zombie_forward[1], 0 ) );
				
				zombie_right = AnglesToRight( zombie.angles );
				zombie_right_2d = VectorNormalize( ( zombie_right[0], zombie_right[1], 0 ) );
				
				dot = VectorDot( zombie_to_mechz_2d, zombie_forward_2d );
				
				if( dot >= 0.5 )
				{
					zombie.knockdown_direction = "front";
					zombie.getup_direction = GETUP_BACK;
				}
				else if ( dot < 0.5 && dot > -0.5 )
				{
					dot = VectorDot( zombie_to_mechz_2d, zombie_right_2d );
					if( dot > 0 )
					{
						zombie.knockdown_direction = "right";
			
						if ( math::cointoss() )
						{
							zombie.getup_direction = GETUP_BACK;
						}
						else
						{
							zombie.getup_direction = GETUP_BELLY;
						}
					}
					else
					{
						zombie.knockdown_direction = "left";
						zombie.getup_direction = GETUP_BELLY;
					}
				}
				else
				{
					zombie.knockdown_direction = "back";
					zombie.getup_direction = GETUP_BELLY;
				}
			}
		}
	}
}

function private mechzZombieEligibleForBerserkKnockdown( zombie, mechz, predicted_pos )
{
	if( zombie.knockdown === true )
	{
		return false;
	}
	
	knockdown_dist_sq = 48*48;
	
	dist_sq = DistanceSquared( predicted_pos, zombie.origin );
	
	if( dist_sq > knockdown_dist_sq )
	{
		return false;
	}
	
	if( zombie.is_immune_to_knockdown === true )
	{
		return false;
	}
	   
	origin = mechz.origin;

	facing_vec = AnglesToForward( mechz.angles );
	enemy_vec = zombie.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < 0 )// is enemy behind mechz
	{
		return false;
	}
	
	return true;
	
}

//----------------------------------------------------------------------------------------------------------------------------------
// CONDITIONS
//----------------------------------------------------------------------------------------------------------------------------------
function mechzShouldMelee( entity )
{
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if( DistanceSquared( entity.origin, entity.enemy.origin ) > MECHZ_MELEE_DIST_SQ )
	{
		return false;
	}

	// don't do yaw check if on vehicle ( turret ). add any additional checks above this.
	if( IS_TRUE( entity.enemy.usingvehicle ) ) 
	{
		return true;
	}	
	
	yaw = abs( zombie_utility::getYawToEnemy() );
	if( ( yaw > MECHZ_MELEE_YAW ) )
	{
		return false;
	}
	
	return true;
}

function private mechzShouldShowPain( entity )
{
	if( entity.partDestroyed === true )
	{
		return true;
	}
	
	return false;
}

function private mechzShouldShootGrenade( entity )
{
	
	if( entity.berserk === true )
	{
		return false;
	}
		
	if( entity.gun_attached !== true )
	{
		return false;
	}
	
	if ( !IsDefined( entity.favoriteenemy ) )
	{
		return false;
	}

	if ( entity.burstGrenadesFired >= MECHZ_GRENADE_BURST_SIZE )
	{
		return false;
	}
	
	if( entity.activeGrenades >= MECHZ_GRENADE_MAX )
	{
		return false;
	}

	if ( !entity MechzServerUtils::mechzGrenadeCheckInArc() )
	{
		return false;
	}
	
	if( !entity CanSee( entity.favoriteenemy ) )
	{
		return false;
	}

	dist_sq = DistanceSquared( entity.origin, entity.favoriteenemy.origin );
	if ( dist_sq < MECHZ_GRENADE_DIST_SQ_MIN || dist_sq > MECHZ_GRENADE_DIST_SQ_MAX )
	{
		return false;
	}

	return true;
}

function private mechzShouldShootFlame( entity )
{
	/#
		if ( IS_TRUE( entity.shoot_flame ) )
		{
			return true;
		}
	#/

	if( entity.berserk === true )
	{
		return false;
	}

	if ( IS_TRUE( entity.isShootingFlame ) && GetTime() < entity.stopShootingFlameTime )
	{
		return true;
	}
	
	if ( !IsDefined( entity.favoriteenemy ) )
	{
		return false;
	}
	
	if( entity.isShootingFlame === true && entity.stopShootingFlameTime <= GetTime() )
	{
		return false;
	}

	if ( entity.nextFlameTime > GetTime() )
	{
		return false;
	}

	if ( !entity MechzServerUtils::mechzCheckInArc( MECHZ_FT_RIGHT_OFFSET, MECHZ_FT_TAG ) )
	{
		return false;
	}

	dist_sq = DistanceSquared( entity.origin, entity.favoriteenemy.origin );
	if ( dist_sq < MECHZ_FT_DIST_SQ_MIN || dist_sq > MECHZ_FT_DIST_SQ_MAX )
	{
		return false;
	}

	can_see = BulletTracePassed( entity.origin + ( 0, 0, 36 ), entity.favoriteenemy.origin + ( 0, 0, 36 ), false, undefined );
	if ( !can_see )
	{
		return false;
	}

	return true;
}

function private mechzShouldShootFlameSweep( entity )
{
	if( entity.berserk === true )
	{
		return false;
	}
	
	if ( !mechzShouldShootFlame( entity ) )
	{
		return false;
	}

	if ( RandomInt( 100 ) > MECHZ_FT_SWEEP_CHANCE )
	{
		return false;
	}

	near_players = 0;
	players = GetPlayers();
	
	foreach( player in players )
	{
		if ( Distance2DSquared( entity.origin, player.origin ) < MECHZ_FT_SWEEP_PLAYER_DIST_SQ )
		{
			near_players++;
		}
	}

	if ( near_players < 2 )
	{
		return false;
	}

	return true;
}

function private mechzShouldTurnBerserk( entity )
{
	if( entity.berserk === true && entity.hasTurnedBerserk !== true )
	{
		return true;
	}
	
	return false;
}

function private mechzShouldStun( entity )
{
	if ( IS_TRUE( entity.stun ) )
	{
		return true;
	}

	return false;
}

function private mechzShouldStumble( entity )
{
	if ( IS_TRUE( entity.stumble ) )
	{
		return true;
	}

	return false;
}

//----------------------------------------------------------------------------------------------------------------------------------
// ACTIONS
//----------------------------------------------------------------------------------------------------------------------------------
function private mechzShootGrenadeAction( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	entity.grenadeStartTime = GetTime() + 3000;

	return BHTN_RUNNING;
}

function private mechzShootGrenadeActionUpdate( entity, asmStateName )
{
	if ( !IS_TRUE( entity.shoot_grenade ) )
	{
		return BHTN_SUCCESS;
	}

	return BHTN_RUNNING;
}

function private mechzStunStart( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	entity.stunTime = GetTime() + MECHZ_STUN_TIME;

	return BHTN_RUNNING;
}

function private mechzStunUpdate( entity, asmStateName )
{
	if ( GetTime() > entity.stunTime )
	{
		return BHTN_SUCCESS;
	}

	return BHTN_RUNNING;
}

function private mechzStunEnd( entity, asmStateName )
{
	entity.stun = false;
	entity.stumble_stun_cooldown_time = GetTime() + MECHZ_STUN_STUMBLE_COOLDOWN;

	return BHTN_SUCCESS;
}

function private mechzStumbleStart( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	entity.stumbleTime = GetTime() + MECHZ_STUMBLE_TIME;

	return BHTN_RUNNING;
}

function private mechzStumbleUpdate( entity, asmStateName )
{
	if ( GetTime() > entity.stumbleTime )
	{
		return BHTN_SUCCESS;
	}

	return BHTN_RUNNING;
}

function private mechzStumbleEnd( entity, asmStateName )
{
	entity.stumble = false;
	
	entity.stumble_stun_cooldown_time = GetTime() + MECHZ_STUN_STUMBLE_COOLDOWN;

	return BHTN_SUCCESS;
}

function mechzShootFlameActionStart( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	mechzShootFlame( entity );

	return BHTN_RUNNING;
}

function mechzShootFlameActionUpdate( entity, asmStateName )
{
	if( IS_TRUE( entity.berserk ))
	{
		mechzStopFlame( entity );
		return BHTN_SUCCESS;
	}
	
	if( IS_TRUE( mechzShouldMelee( entity )) )
	{
		mechzStopFlame( entity );
		return BHTN_SUCCESS;
	}
	   	
	if ( IS_TRUE( entity.isShootingFlame ) )
	{
		if ( IsDefined( entity.stopShootingFlameTime ) && GetTime() > entity.stopShootingFlameTime )
		{
			mechzStopFlame( entity );
			return BHTN_SUCCESS;
		}
	
		mechzUpdateFlame( entity );
	}

	return BHTN_RUNNING;
}

function mechzShootFlameActionEnd( entity, asmStateName )
{
	mechzStopFlame( entity );

	return BHTN_SUCCESS;
}


//----------------------------------------------------------------------------------------------------------------------------------
// FUNCTIONS
//----------------------------------------------------------------------------------------------------------------------------------
function private mechzShootGrenade( entity )
{
	entity.burstGrenadesFired ++;
	if ( entity.burstGrenadesFired >= MECHZ_GRENADE_BURST_SIZE )
	{
		entity.nextGrenadeTime = GetTime() + MECHZ_GRENADE_DELAY;
	}
}

function private mechzShootFlame( entity )
{
	entity thread mechzDelayFlame();
}

function private mechzDelayFlame()
{
	self endon( "death" );

	self notify( "mechzDelayFlame" );
	self endon( "mechzDelayFlame" );

	wait( MECHZ_FT_BLEND_TIME );

	self clientfield::set( MECHZ_FT_CLIENTFIELD, MECHZ_FT_ON );
	self.isShootingFlame = true;
	self.stopShootingFlameTime = GetTime() + MECHZ_FT_RUN_DURATION;
}

function private mechzUpdateFlame( entity )
{
	if( IsDefined( level.mechz_flamethrower_player_callback ) )
	{
		[[level.mechz_flamethrower_player_callback]]( entity );
	}
	else
	{
		players = GetPlayers();
	
		foreach( player in players )
		{
			if ( !IS_TRUE( player.is_burning ) )
			{
				if ( player IsTouching( entity.flameTrigger ) )
				{
					if ( IsDefined( entity.mechzFlameDamage ) )
					{
						player thread [[ entity.mechzFlameDamage ]]();
					}
					else
					{
						player thread playerFlameDamage(entity);
					}
				}
			}
		}
	}
	
	if( IsDefined( level.mechz_flamethrower_ai_callback ) ) 
	{
		[[level.mechz_flamethrower_ai_callback]](entity);		
	}	
}

function playerFlameDamage(mechz)
{
	self endon( "death" );
	self endon( "disconnect" );
		
	if ( !IS_TRUE( self.is_burning ) && zombie_utility::is_player_valid( self, true ) )
	{
		self.is_burning = 1;
			
		if ( !self HasPerk( PERK_JUGGERNOG ) )
		{
			self burnplayer::setPlayerBurning( MECHZ_FT_PLAYER_BURN_TIME, MECHZ_FT_PLAYER_DAMAGE_DELAY, MECHZ_FT_PLAYER_DAMAGE, mechz, undefined );
		}
		else
		{
			self burnplayer::setPlayerBurning( MECHZ_FT_PLAYER_BURN_TIME, MECHZ_FT_PLAYER_DAMAGE_DELAY, MECHZ_FT_PLAYER_DAMAGE_JUGG, mechz, undefined );
		}

		wait( MECHZ_FT_PLAYER_BURN_TIME );
		
		self.is_burning = 0;
	}
}

function mechzStopFlame( entity )
{
	self notify( "mechzDelayFlame" );

	entity clientfield::set( MECHZ_FT_CLIENTFIELD, MECHZ_FT_OFF );
	entity.isShootingFlame = false;
	entity.nextFlameTime = GetTime() + MECHZ_FT_DELAY;
	entity.stopShootingFlameTime = undefined;
}

function mechzGoBerserk()
{
	entity = self;	
	g_time = GetTime();
	
//	entity ASMSetAnimationRate( 1.04 );
	
	entity.berserkEndTime = g_time + MECHZ_BERSERK_TIME;
	
	if( entity.berserk !== true )
	{
		entity.berserk = true;
		entity thread mechzEndBerserk();
		Blackboard::SetBlackBoardAttribute( entity, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
	}
}

function private mechzPlayedBerserkIntro( entity )
{
	entity.hasTurnedBerserk = true;
}

function private mechZEndBerserk()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	While( self.berserk === true )
	{
		if( GetTime() >= self.berserkEndTime )
		{
			self.berserk = false;
			self.hasTurnedBerserk = false;
			
			self ASMSetAnimationRate( 1.0 );
			
			Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );
		}
		
		wait 0.25;
	}		
}

function private mechzAttackStart( entity )
{
	entity clientfield::set( MECHZ_FACE_CLIENTFIELD, MECHZ_FACE_ATTACK );
}

function private mechzDeathStart( entity )
{
	entity clientfield::set( MECHZ_FACE_CLIENTFIELD, MECHZ_FACE_DEATH );
}

function private mechzIdleStart( entity )
{
	entity clientfield::set( MECHZ_FACE_CLIENTFIELD, MECHZ_FACE_IDLE );
}

function private mechzPainStart( entity )
{
	entity clientfield::set( MECHZ_FACE_CLIENTFIELD, MECHZ_FACE_PAIN );
}

function private mechzPainTerminate( entity )
{
	entity.partDestroyed = false;
	entity.show_pain_from_explosive_dmg = undefined;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MOCOMPS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#namespace MechzServerUtils;

function private mechzSpawnSetup()
{
	self DisableAimAssist();

	self.disableAmmoDrop = true;
	self.no_gib = true;
	self.ignore_nuke = true;
	self.ignore_enemy_count = true;
	self.ignore_round_robbin_death = true; 

	self.zombie_move_speed = "run";
	Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );

	self.ignoreRunAndGunDist = true;
	
	self mechzAddAttachments();

	self.grenadeCount = MECHZ_GRENADE_MAX;

	self.nextFlameTime = GetTime();
	self.stumble_stun_cooldown_time = GetTime();

	/#
		self.debug_traversal_ast = "traverse@mechz";
	#/
		
	self.flameTrigger = Spawn( "trigger_box", self.origin, 0, 200, 50, 25 );
	self.flameTrigger EnableLinkTo();

	self.flameTrigger.origin = self GetTagOrigin( MECHZ_FT_TAG );
	self.flameTrigger.angles = self GetTagAngles( MECHZ_FT_TAG );
	
	self.flameTrigger LinkTo( self, MECHZ_FT_TAG );
	
	self thread weaponobjects::watchWeaponObjectUsage();
	
	// necessary array creation element for weapon watcher stuff used in the electroball grenade
	self.pers = [];
	self.pers["team"] = self.team;

	//self thread mechzFlameWatcher();
}

function private mechzFlameWatcher()
{
	self endon( "death" );

	while ( 1 )
	{
		if ( IsDefined( self.favoriteenemy ) )
		{
			if ( self.flameTrigger IsTouching( self.favoriteenemy ) )
			{
				/# PrintTopRightLn( "flame on" ); #/
			}
		}

		WAIT_SERVER_FRAME;
	}
}


function private mechzAddAttachments()
{
	self.has_left_knee_armor = true;
	self.left_knee_armor_health = MECHZ_ARMOR_KNEE_LEFT_HEALTH;
	
	self.has_right_knee_armor = true;
	self.right_knee_armor_health = MECHZ_ARMOR_KNEE_RIGHT_HEALTH;
	
	self.has_left_shoulder_armor = true;
	self.left_shoulder_armor_health = MECHZ_ARMOR_SHOULDER_LEFT_HEALTH;
	
	self.has_right_shoulder_armor = true;
	self.right_shoulder_armor_health = MECHZ_ARMOR_SHOULDER_RIGHT_HEALTH;

	org = self GetTagOrigin( MECHZ_TAG_CLAW );
	ang = self GetTagAngles( MECHZ_TAG_CLAW );

	self.gun_attached = true;

	self.has_faceplate = true;
	self.faceplate_health = MECHZ_FACEPLATE_HEALTH;
	
	self.has_powercap = true;
	self.powercap_covered = true;
	self.powercap_cover_health = MECHZ_POWERCAP_COVER_HEALTH;
	self.powercap_health = MECHZ_POWERCAP_HEALTH;
}

function mechzDamageCallback( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if( isDefined( self.b_flyin_done ) && !IS_TRUE( self.b_flyin_done ) )
	{
		return 0;
	}
	
	if ( isDefined( level.mechz_should_stun_override ) && !( IS_TRUE( self.stun ) || IS_TRUE( self.stumble ) ) )
	{
		if ( self.stumble_stun_cooldown_time < GetTime() && !IS_TRUE( self.berserk) )
		{
			self [[level.mechz_should_stun_override]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
		}
	}
	
	if ( IsSubStr( weapon.name, MECHZ_REACT_ELEMENTAL_BOW ) && isdefined( inflictor ) && inflictor.classname === "rocket" )
	{
		// AkiA: Damage from bow shots that hit Mechz directly is controlled in zm_weap_elemental_bow::mechz_direct_hit_impact_damage_check()
		return 0;
	}
	
	damage = mechzWeaponDamageModifier( damage, weapon );
	
	if( isdefined( level.mechz_damage_override ) )
	{
		damage = [[level.mechz_damage_override]]( attacker, damage );
	}
	
	// play audio pain if he hasn't been hit in a bit
	if( !isDefined( self.next_pain_time ) || GetTime() >= self.next_pain_time  )
	{
		self thread mechz_play_pain_audio();
		self.next_pain_time = GetTime() + 250 + RandomInt( 500 ); //will wait this long before playing a pain audio again
	}

	if( isDefined( self.damage_scoring_function ))
	{
		self [[ self.damage_scoring_function ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
	}
	
	if( IsDefined( level.mechz_staff_damage_override ) )
	{
		staffDamage = [[ level.mechz_staff_damage_override ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
		
		if( staffDamage > 0 )
		{
			n_mechz_damage_percent = 0.5;
			
			// Boost damage if his helmet is off and the weapon is a staff
			if( !IS_TRUE( self.has_faceplate ) && n_mechz_damage_percent < 1.0 )
			{
				n_mechz_damage_percent = 1.0;
			}
			
			staffDamage = staffDamage * n_mechz_damage_percent;
			
			if( IS_TRUE( self.has_faceplate ) )
			{
				self mechz_track_faceplate_damage( staffDamage );
			}
			
			/#iPrintLnBold( "Staff DMG: " + staffDamage + ". HP: " + ( self.health - staffDamage ) );#/
				
			DEFAULT( self.explosive_dmg_taken, 0 );
			self.explosive_dmg_taken += staffDamage;
			
			if( IsDefined( level.mechz_explosive_damage_reaction_callback ) )
			{
				self [[ level.mechz_explosive_damage_reaction_callback ]]();
			}
			
			return staffDamage;
		}
	}
	
	if( IsDefined( level.mechz_explosive_damage_reaction_callback ) )
	{
		if( isDefined( mod ) && mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" || mod == "MOD_EXPLOSIVE" )
		{
			n_mechz_damage_percentage = 0.5;
			if( isDefined( attacker ) && IsPlayer( attacker ) && IsAlive( attacker ) && ( level.zombie_vars[attacker.team]["zombie_insta_kill"] || IS_TRUE( attacker.personal_instakill )) ) //instakill does normal damage
			{
				n_mechz_damage_percentage = 1.0;
			}
			
			explosive_damage = damage * n_mechz_damage_percentage;
			
			DEFAULT( self.explosive_dmg_taken, 0 );
			self.explosive_dmg_taken += explosive_damage;
			
			if( IS_TRUE( self.has_faceplate ) )
			{
				self mechz_track_faceplate_damage( explosive_damage );
			}
			
			self [[ level.mechz_explosive_damage_reaction_callback ]]();
			
			/#iPrintLnBold( "Explosive DMG: " + explosive_damage + ". HP: " + ( self.health - explosive_damage ) );#/
			
			return explosive_damage;
		}
	}
	
	if ( hitLoc == "head" )
	{
		attacker show_hit_marker();
		/#iPrintLnBold( "Head DMG: " + damage + ". HP: " + ( self.health - damage ) );#/
		return damage;
	}

	if( hitloc !== "none" )
	{
		switch( hitLoc )
		{
		case "torso_upper":
			if( self.has_faceplate == true )
			{
				faceplate_pos = self GetTagOrigin( MECHZ_TAG_FACEPLATE );
				dist_sq = DistanceSquared( faceplate_pos, point );
				
				if( dist_sq <= 144 )
				{
					self mechz_track_faceplate_damage( damage );
					attacker show_hit_marker();
				}
					
				headlamp_dist_sq = DistanceSquared( point, self GetTagOrigin( "tag_headlamp_FX" ));
				if( headlamp_dist_sq <= 9 )
				{
					self MechzServerUtils::mechz_turn_off_headlamp( true );
				}		
			}		
			
			partName = GetPartName( MECHZ_MODEL_BODY, boneIndex );
			if( self.powercap_covered === true && ( partName === MECHZ_TAG_POWERSUPPLY || partName === MECHZ_TAG_POWERCORE ) )
			{
				self mechz_track_powercap_cover_damage( damage );
				attacker show_hit_marker();
				/#iPrintLnBold( "PowerCore/Supply DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
				return damage * MECHZ_BODY_DAMAGE_SCALE;
			}
			else if( self.powercap_covered !== true && self.has_powercap === true && ( partName === MECHZ_TAG_POWERSUPPLY || partName === MECHZ_TAG_POWERCORE ) )
			{
				self mechz_track_powercap_damage( damage );
				attacker show_hit_marker();
				/#iPrintLnBold( "PowerCore/Supply DMG: " + damage + ". HP: " + ( self.health - damage ) );#/
				return damage;
			}
			else if( self.powercap_covered !== true && self.has_powercap !== true && ( partName === MECHZ_TAG_POWERSUPPLY || partName === MECHZ_TAG_POWERCORE ) )
			{
				/#iPrintLnBold( "PowerCore/Supply DMG: " + ( damage * MECHZ_POWERCORE_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_POWERCORE_DAMAGE_SCALE ) ) );#/
				attacker show_hit_marker();
				return damage * MECHZ_POWERCORE_DAMAGE_SCALE;
			}
			
			if( self.has_right_shoulder_armor === true && partName === MECHZ_TAG_ARMOR_SHOULDER_RIGHT )
			{
				self mechz_track_rshoulder_armor_damage( damage );
				/#iPrintLnBold( "Torso Upper DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
				return damage * MECHZ_BODY_DAMAGE_SCALE;
			}
					
			if( self.has_left_shoulder_armor === true && partName === MECHZ_TAG_ARMOR_SHOULDER_LEFT )
			{
				self mechz_track_lshoulder_armor_damage( damage );
				/#iPrintLnBold( "Torso Upper DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
				return damage * MECHZ_BODY_DAMAGE_SCALE;
			}
			
			/#iPrintLnBold( "Torso Upper DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
			return damage * MECHZ_BODY_DAMAGE_SCALE;
			break;
			
		case "left_leg_lower":
			partName = GetPartName( MECHZ_MODEL_BODY, boneIndex );
			if( partName === MECHZ_TAG_ARMOR_KNEE_LEFT && self.has_left_knee_armor === true )
			{
				self mechz_track_lknee_armor_damage( damage );
			}
			
			/#iPrintLnBold( "HitLoc L Leg Lower DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
			return damage * MECHZ_BODY_DAMAGE_SCALE;
			break;
			
		case "right_leg_lower":
			partName = GetPartName( MECHZ_MODEL_BODY, boneIndex );
			if( partName === MECHZ_TAG_ARMOR_KNEE_RIGHT && self.has_right_knee_armor === true )
			{
				self mechz_track_rknee_armor_damage( damage );
			}
			
			/#iPrintLnBold( "HitLoc R Leg Lower DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
			return damage * MECHZ_BODY_DAMAGE_SCALE;
			break;

		case "left_hand":
		case "left_arm_lower":
		case "left_arm_upper":
			if ( IsDefined( level.mechz_left_arm_damage_callback ) )
			{
				self [[ level.mechz_left_arm_damage_callback ]]();
			}

			/#iPrintLnBold( "HitLoc L Arm DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
			return damage * MECHZ_BODY_DAMAGE_SCALE;
			break;
			
	
		default:
			/#iPrintLnBold( "HitLoc DEFAULT DMG: " + ( damage * MECHZ_BODY_DAMAGE_SCALE ) + ". HP: " + ( self.health - ( damage * MECHZ_BODY_DAMAGE_SCALE ) ) );#/
			return damage * MECHZ_BODY_DAMAGE_SCALE;
			break;
		}
	}

	if ( mod == "MOD_PROJECTILE" )
	{
		hit_damage = damage * MECHZ_PROJECTILE_DAMAGE_SCALE;
		
		if( self.has_faceplate !== true )
		{
			head_pos = self GetTagOrigin( "tag_eye" );
			dist_sq = DistanceSquared( head_pos, point );
			
			if( dist_sq <= 144 )
			{
				/#iPrintLnBold( "Projectile head DMG: " + damage + ". HP: " + ( self.health - damage ) );#/
				attacker show_hit_marker();
				return damage;
			}
			                             
		}
		
		if( self.has_faceplate === true )
		{
			faceplate_pos = self GetTagOrigin( MECHZ_TAG_FACEPLATE );
			dist_sq = DistanceSquared( faceplate_pos, point );
			
			if( dist_sq <= 144 )
			{
				self mechz_track_faceplate_damage( damage );
				attacker show_hit_marker();
			}
			
			headlamp_dist_sq = DistanceSquared( point, self GetTagOrigin( "tag_headlamp_FX" ));
			if( headlamp_dist_sq <= 9 )
			{
				self MechzServerUtils::mechz_turn_off_headlamp( true );
			}
		}
		
		
		power_pos = self GetTagOrigin( MECHZ_TAG_POWERCORE );
		power_dist_sq = DistanceSquared( power_pos, point );
		
		if( power_dist_sq <= 25 )
		{
			if( self.powercap_covered !== true && self.has_powercap !== true )
			{
				/#iPrintLnBold( "Projectile powercap DMG: " + damage + ". HP: " + ( self.health - damage ) );#/
				attacker show_hit_marker();
				return damage;
			}
								
			if( self.powercap_covered !== true && self.has_powercap === true )
			{
				self mechz_track_powercap_damage( damage );
				attacker show_hit_marker();
				/#iPrintLnBold( "Projectile powercap DMG: " + damage + ". HP: " + ( self.health - damage ) );#/
				return damage;
			}
			
			if( self.powercap_covered === true )
			{
				self mechz_track_powercap_cover_damage( damage );
				attacker show_hit_marker();
			}
		}
		
		if( self.has_right_shoulder_armor === true )
		{
			armor_pos = self GetTagOrigin( MECHZ_TAG_ARMOR_SHOULDER_RIGHT );
			dist_sq = DistanceSquared( armor_pos, point );
			
			if( dist_sq <= 64 )
			{
				self mechz_track_rshoulder_armor_damage( damage );
			}
		}
		
		if( self.has_left_shoulder_armor === true )
		{
			armor_pos = self GetTagOrigin( MECHZ_TAG_ARMOR_SHOULDER_LEFT );
			dist_sq = DistanceSquared( armor_pos, point );
			
			if( dist_sq <= 64 )
			{
				self mechz_track_lshoulder_armor_damage( damage );
			}
		}
				
		if( self.has_right_knee_armor === true )
		{
			armor_pos = self GetTagOrigin( MECHZ_TAG_ARMOR_KNEE_RIGHT );
			dist_sq = DistanceSquared( armor_pos, point );
			
			if( dist_sq <= 36 )
			{
				self mechz_track_rknee_armor_damage( damage );
			}
		}
		
		if( self.has_left_knee_armor === true )
		{
			armor_pos = self GetTagOrigin( MECHZ_TAG_ARMOR_KNEE_LEFT );
			dist_sq = DistanceSquared( armor_pos, point );
			
			if( dist_sq <= 36 )
			{
				self mechz_track_lknee_armor_damage( damage );
			}
		}
		
		/#iPrintLnBold( "Projectile DMG: " + hit_damage + ". HP: " + ( self.health - hit_damage ) );#/
		return hit_damage;
	}
	else if ( mod == "MOD_PROJECTILE_SPLASH" )
	{
		hit_damage = damage * MECHZ_PROJECTILE_SPLASH_DAMAGE_SCALE;
		
		//count number of armor pieces
		i_num_armor_pieces = 0;
		
		if( isDefined( level.mechz_faceplate_damage_override ))
		{
			self [[level.mechz_faceplate_damage_override]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
		}
		
		if( self.has_right_shoulder_armor === true )
		{
			i_num_armor_pieces += 1;
			right_shoulder_index = i_num_armor_pieces;
		}
		
		if( self.has_left_shoulder_armor === true )
		{
			i_num_armor_pieces += 1;
			left_shoulder_index = i_num_armor_pieces;
		}
				
		if( self.has_right_knee_armor === true )
		{
			i_num_armor_pieces += 1;
			right_knee_index = i_num_armor_pieces;
		}
					
		if( self.has_left_knee_armor === true )
		{
			i_num_armor_pieces += 1;
			left_knee_index = i_num_armor_pieces;
		}
		
		if( i_num_armor_pieces > 0 )
		{
			if( i_num_armor_pieces <= 1 )
			{
				i_random = 0;
			}
			else
			{
				i_random = RandomInt( i_num_armor_pieces - 1 );
			}
			
			i_random += 1;
			
			if( self.has_right_shoulder_armor === true && right_shoulder_index === i_random )
			{
				self mechz_track_rshoulder_armor_damage( damage );
			}
			
			if( self.has_left_shoulder_armor === true && left_shoulder_index === i_random )
			{
				self mechz_track_lshoulder_armor_damage( damage );
			}
			
			if( self.has_right_knee_armor === true && right_knee_index === i_random )
			{
				self mechz_track_rknee_armor_damage( damage );
			}
			
			if( self.has_left_knee_armor === true && left_knee_index === i_random )
			{
				self mechz_track_lknee_armor_damage( damage );
			}			
		}
		else
		{
			if( self.powercap_covered === true )
			{
				self mechz_track_powercap_cover_damage( damage * 0.5 );
			}
			
			if( self.has_faceplate == true )
			{
				self mechz_track_faceplate_damage( damage * 0.5 );
			}	
		}		
		
		/#iPrintLnBold( "Projectile Splash DMG: " + hit_damage + ". HP: " + ( self.health - hit_damage ) );#/
		return hit_damage;
	}

	return 0;
}

//used to step down the damage from some high-powered weapons
function private mechzWeaponDamageModifier( damage, weapon )
{
	if( isDefined( weapon) && isDefined( weapon.name ) )
	{
		if( isSubStr( weapon.name, "shotgun_fullauto") )
		{
			return damage * 0.5;	
		}
		
		if( isSubStr( weapon.name, "lmg_cqb") )
		{
			return damage * 0.65;	
		}
		
		if( isSubStr( weapon.name, "lmg_heavy") )
		{
			return damage * 0.65;	
		}
		
		if( isSubStr( weapon.name, "shotgun_precision") )
		{
			return damage * 0.65;	
		}
		
		if( isSubstr( weapon.name, "shotgun_semiauto") )
		{
			return damage * 0.75;	
		}
		
	}
		
	return damage;
}

function mechz_play_pain_audio()
{
	self playsound( "zmb_ai_mechz_destruction" );
}

function show_hit_marker()  // self = player
{
	if ( IsDefined( self ) && IsDefined( self.hud_damagefeedback ) )
	{
		self.hud_damagefeedback SetShader( "damage_feedback", 24, 48 );
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback FadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}	
}

function hide_part( strTag )
{
	if ( self HasPart(strTag) )
	{
		self HidePart(strTag);  
	}
}


function mechz_track_faceplate_damage( damage )
{
	self.faceplate_health = self.faceplate_health - damage;
	if( self.faceplate_health <= 0 )
	{
		self hide_part( MECHZ_TAG_FACEPLATE );
		self clientfield::set( "mechz_faceplate_detached", 1 );
		self.has_faceplate = false;
		self MechzServerUtils::mechz_turn_off_headlamp();
		self.partDestroyed = true;
		Blackboard::SetBlackBoardAttribute( self, MECHZ_PART, MECHZ_PART_FACEPLATE );
		
		self MechzBehavior::mechzGoBerserk();

		level notify( "mechz_faceplate_detached" );
	}	
}

function mechz_track_powercap_cover_damage( damage )
{
	self.powercap_cover_health = self.powercap_cover_health - damage;
	if( self.powercap_cover_health <= 0 )
	{
		self hide_part( MECHZ_TAG_POWERSUPPLY );
		self clientfield::set( "mechz_powercap_detached", 1 );		
		self.powercap_covered = false;
		self.partDestroyed = true;
		Blackboard::SetBlackBoardAttribute( self, MECHZ_PART, MECHZ_PART_POWERCORE );
		
		//self MechzBehavior::mechzGoBerserk();
	}
	
}

function mechz_track_powercap_damage( damage )
{
	self.powercap_health = self.powercap_health - damage;
	if( self.powercap_health <=0 )
	{
		if( IsDefined( level.mechz_powercap_destroyed_callback ) )
		{
			self [[level.mechz_powercap_destroyed_callback]]();
		}
		
		self hide_part( MECHZ_TAG_CLAW );
		self hide_part( "tag_gun_barrel1" );
		self hide_part( "tag_gun_barrel2" );
		self hide_part( "tag_gun_barrel3" );
		self hide_part( "tag_gun_barrel4" );
		self hide_part( "tag_gun_barrel5" );
		self hide_part( "tag_gun_barrel6" );
		self clientfield::set( "mechz_claw_detached", 1 );
		self.has_powercap = false;
		self.gun_attached = false;
		self.partDestroyed = true;
		Blackboard::SetBlackBoardAttribute( self, MECHZ_PART, MECHZ_PART_GUN );
		
		//self MechzBehavior::mechzGoBerserk();

		level notify( "mechz_gun_detached" );
	}
}

function mechz_track_rknee_armor_damage( damage )
{
	self.right_knee_armor_health = self.right_knee_armor_health - damage;
	if( self.right_knee_armor_health <= 0 )
	{
		self hide_part( MECHZ_TAG_ARMOR_KNEE_RIGHT );
		self clientfield::set( "mechz_rknee_armor_detached", 1 );		
		self.has_right_knee_armor = false;
	}
	
}

function mechz_track_lknee_armor_damage( damage )
{
	self.left_knee_armor_health = self.left_knee_armor_health - damage;
	if( self.left_knee_armor_health <= 0 )
	{
		self hide_part( MECHZ_TAG_ARMOR_KNEE_LEFT );
		self clientfield::set( "mechz_lknee_armor_detached", 1 );		
		self.has_left_knee_armor = false;
	}
	
}

function mechz_track_rshoulder_armor_damage( damage )
{
	self.right_shoulder_armor_health = self.right_shoulder_armor_health - damage;
	if( self.right_shoulder_armor_health <= 0 )
	{
		self hide_part( MECHZ_TAG_ARMOR_SHOULDER_RIGHT );
		self clientfield::set( "mechz_rshoulder_armor_detached", 1 );		
		self.has_right_shoulder_armor = false;
	}
	
}

function mechz_track_lshoulder_armor_damage( damage )
{
	self.left_shoulder_armor_health = self.left_shoulder_armor_health - damage;
	if( self.left_shoulder_armor_health <= 0 )
	{
		self hide_part( MECHZ_TAG_ARMOR_SHOULDER_LEFT );
		self clientfield::set( "mechz_lshoulder_armor_detached", 1 );		
		self.has_left_shoulder_armor = false;
	}
	
}

function mechzCheckInArc( right_offset, aim_tag )
{
	origin = self.origin;
	angles = self.angles;

	if ( IsDefined( aim_tag ) )
	{
		origin = self GetTagOrigin( aim_tag );
		angles = self GetTagAngles( aim_tag );
	}
	
	if ( IsDefined( right_offset ) )
	{
		right_angle = anglestoright( angles );
		origin = origin + (right_angle * right_offset);
	}

	facing_vec = AnglesToForward( angles );
	enemy_vec = self.favoriteenemy.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < MECHZ_AIM_YAW_COS )
	{
		return false;
	}
	
	enemy_angles = VectorToAngles( enemy_vec );
	
	if( abs( AngleClamp180( enemy_angles[0] ) ) > MECHZ_AIM_PITCH_MAX )
	{
		return false;
	}
	
	return true;
}

function private mechzGrenadeCheckInArc( right_offset )
{
	origin = self.origin;
	if ( IsDefined( right_offset ) )
	{
		right_angle = anglestoright( self.angles );
		origin = origin + (right_angle * right_offset);
	}

	facing_vec = AnglesToForward( self.angles );
	enemy_vec = self.favoriteenemy.origin - origin;
	
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	
	enemy_yaw_vec = VectorNormalize( enemy_yaw_vec );
	facing_yaw_vec = VectorNormalize( facing_yaw_vec );
	
	enemy_dot = VectorDot( facing_yaw_vec, enemy_yaw_vec );
	
	if( enemy_dot < MECHZ_AIM_YAW_COS )
	{
		return false;
	}
	
	enemy_angles = VectorToAngles( enemy_vec );
	
	if( abs( AngleClamp180( enemy_angles[0] ) ) > MECHZ_AIM_PITCH_MAX )
	{
		return false;
	}
	
	return true;
}


function mechz_turn_off_headlamp( headlamp_broken )
{
	if( headlamp_broken !== true )
	{
		self clientfield::set( "mechz_headlamp_off", 1 );
	}
	else
	{
		self clientfield::set( "mechz_headlamp_off", 2 );
	}
}
