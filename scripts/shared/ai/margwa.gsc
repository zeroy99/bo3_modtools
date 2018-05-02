#using scripts\shared\ai_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\margwa;
#using scripts\shared\ai\zombie_utility;
#using scripts\codescripts\struct;
#using scripts\shared\ai\archetype_mocomps_utility;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\margwa.gsh; 
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace MargwaBehavior;

function autoexec init()
{
	// INIT BEHAVIORS
	InitMargwaBehaviorsAndASM();
	
	// INIT BLACKBOARD	
	spawner::add_archetype_spawn_function( ARCHETYPE_MARGWA, &ArchetypeMargwaBlackboardInit );

	// INIT MARGWA ON SPAWN
	spawner::add_archetype_spawn_function( ARCHETYPE_MARGWA, &MargwaServerUtils::margwaSpawnSetup );

	clientfield::register( "actor", MARGWA_HEAD_LEFT_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE );
	clientfield::register( "actor", MARGWA_HEAD_MID_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE );
	clientfield::register( "actor", MARGWA_HEAD_RIGHT_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_CLIENTFIELD_BITS, MARGWA_HEAD_CLIENTFIELD_TYPE );
	clientfield::register( "actor", MARGWA_FX_IN_CLIENTFIELD, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", MARGWA_FX_OUT_CLIENTFIELD, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", MARGWA_FX_SPAWN_CLIENTFIELD, VERSION_SHIP, MARGWA_FX_SPAWN_CLIENTFIELD_BITS, MARGWA_FX_SPAWN_CLIENTFIELD_TYPE );
	clientfield::register( "actor", MARGWA_SMASH_CLIENTFIELD, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", MARGWA_HEAD_LEFT_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", MARGWA_HEAD_MID_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter" );
	clientfield::register( "actor", MARGWA_HEAD_RIGHT_HIT_CLIENTFIELD, VERSION_SHIP, 1, "counter" );

	clientfield::register( "actor", MARGWA_HEAD_KILLED_CLIENTFIELD, VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", MARGWA_JAW_CLIENTFIELD, VERSION_SHIP, 6, "int" );

	clientfield::register( "toplayer", MARGWA_HEAD_EXPLODE_CLIENTFIELD, VERSION_SHIP, MARGWA_HEAD_EXPLODE_CLIENTFIELD_BITS, MARGWA_HEAD_EXPLODE_CLIENTFIELD_TYPE );
	clientfield::register( "scriptmover", MARGWA_FX_TRAVEL_CLIENTFIELD, VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", MARGWA_FX_TRAVEL_TELL_CLIENTFIELD, VERSION_SHIP, 1, "int" );

	clientfield::register( "actor", "supermargwa", VERSION_SHIP, 1, "int" ); // set this bit when spawning supermargwa for ee quest

	InitDirectHitWeapons();
}

function private InitDirectHitWeapons()
{
	if ( !IsDefined( level.dhWeapons ) )
	{
		level.dhWeapons = [];
	}

	level.dhWeapons[ level.dhWeapons.size ] = "ray_gun";
	level.dhWeapons[ level.dhWeapons.size ] = "ray_gun_upgraded";
	level.dhWeapons[ level.dhWeapons.size ] = "pistol_standard_upgraded";
	level.dhWeapons[ level.dhWeapons.size ] = "pistol_revolver38_upgraded";
	level.dhWeapons[ level.dhWeapons.size ] = "pistol_revolver38lh_upgraded";
	level.dhWeapons[ level.dhWeapons.size ] = "launcher_standard";
	level.dhWeapons[ level.dhWeapons.size ] = "launcher_standard_upgraded";
}

function AddDirectHitWeapon( weaponName )
{
	foreach( weapon in level.dhWeapons )
	{
		if ( weapon == weaponName )
		{
			return;
		}
	}

	level.dhWeapons[ level.dhWeapons.size ] = weaponName;
}

function private InitMargwaBehaviorsAndASM()
{
	// SERVICES
	BT_REGISTER_API( "margwaTargetService", 			&MargwaBehavior::margwaTargetService );

	// CONDITIONS
	BT_REGISTER_API( "margwaShouldSmashAttack", 		&MargwaBehavior::margwaShouldSmashAttack );
	BT_REGISTER_API( "margwaShouldSwipeAttack", 		&MargwaBehavior::margwaShouldSwipeAttack );
	BT_REGISTER_API( "margwaShouldShowPain", 			&MargwaBehavior::margwaShouldShowPain );
	BT_REGISTER_API( "margwaShouldReactStun", 			&MargwaBehavior::margwaShouldReactStun );
	BT_REGISTER_API( "margwaShouldReactIDGun", 			&MargwaBehavior::margwaShouldReactIDGun );
	BT_REGISTER_API( "margwaShouldReactSword", 			&MargwaBehavior::margwaShouldReactSword );
	BT_REGISTER_API( "margwaShouldSpawn", 				&MargwaBehavior::margwaShouldSpawn );
	BT_REGISTER_API( "margwaShouldFreeze", 				&MargwaBehavior::margwaShouldFreeze );
	BT_REGISTER_API( "margwaShouldTeleportIn", 			&MargwaBehavior::margwaShouldTeleportIn );
	BT_REGISTER_API( "margwaShouldTeleportOut", 		&MargwaBehavior::margwaShouldTeleportOut );
	BT_REGISTER_API( "margwaShouldWait", 				&MargwaBehavior::margwaShouldWait );

	// Consolidated condition checking to limit VM calls
	BT_REGISTER_API( "margwaShouldReset", 				&MargwaBehavior::margwaShouldReset );

	// ACTIONS
	BT_REGISTER_ACTION( "margwaReactStunAction",		&MargwaBehavior::margwaReactStunAction, undefined, undefined );
	BT_REGISTER_ACTION( "margwaSwipeAttackAction",		&MargwaBehavior::margwaSwipeAttackAction, &MargwaBehavior::margwaSwipeAttackActionUpdate, undefined );

	// FUNCTIONS
	BT_REGISTER_API( "margwaIdleStart", 				&MargwaBehavior::margwaIdleStart );
	BT_REGISTER_API( "margwaMoveStart", 				&MargwaBehavior::margwaMoveStart );
	BT_REGISTER_API( "margwaTraverseActionStart", 		&MargwaBehavior::margwaTraverseActionStart );
	BT_REGISTER_API( "margwaTeleportInStart", 			&MargwaBehavior::margwaTeleportInStart );
	BT_REGISTER_API( "margwaTeleportInTerminate",		&MargwaBehavior::margwaTeleportInTerminate );
	BT_REGISTER_API( "margwaTeleportOutStart", 			&MargwaBehavior::margwaTeleportOutStart );
	BT_REGISTER_API( "margwaTeleportOutTerminate",		&MargwaBehavior::margwaTeleportOutTerminate );
	BT_REGISTER_API( "margwaPainStart", 				&MargwaBehavior::margwaPainStart );
	BT_REGISTER_API( "margwaPainTerminate", 			&MargwaBehavior::margwaPainTerminate );
	BT_REGISTER_API( "margwaReactStunStart", 			&MargwaBehavior::margwaReactStunStart );
	BT_REGISTER_API( "margwaReactStunTerminate", 		&MargwaBehavior::margwaReactStunTerminate );
	BT_REGISTER_API( "margwaReactIDGunStart", 			&MargwaBehavior::margwaReactIDGunStart );
	BT_REGISTER_API( "margwaReactIDGunTerminate", 		&MargwaBehavior::margwaReactIDGunTerminate );
	BT_REGISTER_API( "margwaReactSwordStart", 			&MargwaBehavior::margwaReactSwordStart );
	BT_REGISTER_API( "margwaReactSwordTerminate", 		&MargwaBehavior::margwaReactSwordTerminate );
	BT_REGISTER_API( "margwaSpawnStart", 				&MargwaBehavior::margwaSpawnStart );
	BT_REGISTER_API( "margwaSmashAttackStart", 			&MargwaBehavior::margwaSmashAttackStart );
	BT_REGISTER_API( "margwaSmashAttackTerminate", 		&MargwaBehavior::margwaSmashAttackTerminate );

	BT_REGISTER_API( "margwaSwipeAttackStart", 			&MargwaBehavior::margwaSwipeAttackStart );
	BT_REGISTER_API( "margwaSwipeAttackTerminate", 		&MargwaBehavior::margwaSwipeAttackTerminate );

	// MOCOMPS
	ASM_REGISTER_MOCOMP( "mocomp_teleport_traversal@margwa", &mocompMargwaTeleportTraversalInit, &mocompMargwaTeleportTraversalUpdate, &mocompMargwaTeleportTraversalTerminate );

	// NOTETRACKS
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_MARGWA_SMASH_ATTACK_NOTETRACK, &MargwaBehavior::margwaNotetrackSmashAttack );
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_MARGWA_BODYFALL_NOTETRACK, &MargwaBehavior::margwaNotetrackBodyfall );	
	ASM_REGISTER_NOTETRACK_HANDLER( ASM_MARGWA_PAIN_MELEE_NOTETRACK, &MargwaBehavior::margwaNotetrackPainMelee );	
}

function private ArchetypeMargwaBlackboardInit()
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );
	
	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE MARGWA BLACKBOARD
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SPEED_TYPE,		LOCOMOTION_SPEED_WALK,				undefined );
	BB_REGISTER_ATTRIBUTE( BOARD_ATTACK_SPOT,			undefined, 							undefined );	
	BB_REGISTER_ATTRIBUTE( LOCOMOTION_SHOULD_TURN,		SHOULD_NOT_TURN,					&BB_GetShouldTurn );
	BB_REGISTER_ATTRIBUTE( ZOMBIE_DAMAGEWEAPON_TYPE,	ZOMBIE_DAMAGEWEAPON_REGULAR,		undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &ArchetypeMargwaOnAnimscriptedCallback;
	
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private ArchetypeMargwaOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;
	
	// REREGISTER BLACKBOARD
	entity ArchetypeMargwaBlackboardInit();
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
function private margwaNotetrackSmashAttack( entity )
{
	players = GetPlayers();
	foreach( player in players )
	{
		smashPos = entity.origin + VectorScale( AnglesToForward( self.angles ), MARGWA_SMASH_ATTACK_OFFSET );
		distSq = DistanceSquared( smashPos, player.origin );
		if ( distSq < MARGWA_SMASH_ATTACK_RANGE )
		{
			if ( !IsGodMode( player ) )
			{
				// riot shield can block damage from front or back
				if ( IS_TRUE( player.hasRiotShield ) )
				{
					damageShield = false;
					attackDir = player.origin - self.origin;

					if ( IS_TRUE( player.hasRiotShieldEquipped ) )
					{
						if ( player margwaServerUtils::shieldFacing( attackDir, MARGWA_RIOTSHIELD_FACING_TOLERANCE ) )
						{
							damageShield = true;
						}
					}
					else
					{
						if ( player margwaServerUtils::shieldFacing( attackDir, MARGWA_RIOTSHIELD_FACING_TOLERANCE, false ) )
						{
							damageShield = true;
						}
					}

					if ( damageShield )
					{
						self clientfield::increment( MARGWA_SMASH_CLIENTFIELD );
						shield_damage = level.weaponRiotshield.weaponstarthitpoints;
						if ( IsDefined( player.weaponRiotshield ) )
							shield_damage = player.weaponRiotshield.weaponstarthitpoints;
						player [[ player.player_shield_apply_damage ]]( shield_damage, false );
						continue;
					}
				}
				
				if ( isdefined( level.margwa_smash_damage_callback ) && IsFunctionPtr( level.margwa_smash_damage_callback ) )
				{
					if ( player [[ level.margwa_smash_damage_callback ]]( self ) )
					{
						continue;
					}
				}
				
				self clientfield::increment( MARGWA_SMASH_CLIENTFIELD );
				player DoDamage( MARGWA_SMASH_ATTACK_DAMAGE, self.origin, self );
			}
		}
	}

	if ( IsDefined( self.smashAttackCB ) )
	{
		self [[ self.smashAttackCB ]]();
	}
}

// Fx takes over after margwa hits the ground
function private margwaNotetrackBodyfall( entity )
{
	if( self.archetype == ARCHETYPE_MARGWA )
	{
		entity Ghost();

		if ( IsDefined( self.bodyfallCB ) )
		{
			self [[ self.bodyfallCB ]]();
		}
	}
}

function private margwaNotetrackPainMelee( entity )
{
	entity Melee();
}

//----------------------------------------------------------------------------------------------------------------------------
// BEHAVIOR TREE
//----------------------------------------------------------------------------------------------------------------------------
function private margwaTargetService( entity )
{
	if ( IS_TRUE( entity.ignoreall ) )
	{
		return false;
	}

	player = zombie_utility::get_closest_valid_player( self.origin, self.ignore_player );

	if( !IsDefined( player ) )
	{
		if( IsDefined( self.ignore_player ) )
		{
			if(isDefined(level._should_skip_ignore_player_logic) && [[level._should_skip_ignore_player_logic]]() )
			{
				return;
			}
			self.ignore_player = [];
		}

		self SetGoal( self.origin );		
		return false;
	}
	else
	{
		targetPos = GetClosestPointOnNavMesh( player.origin, MARGWA_NAVMESH_RADIUS, MARGWA_NAVMESH_BOUNDARY_DIST );
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

function margwaShouldSmashAttack( entity )
{
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if ( !entity MargwaServerUtils::inSmashAttackRange( entity.enemy ) )
	{
		return false;
	}

	yaw = abs( zombie_utility::getYawToEnemy() );
	if( ( yaw > MARGWA_MELEE_YAW ) )
	{
		return false;
	}

	return true;
}

function margwaShouldSwipeAttack( entity )
{
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if( DistanceSquared( entity.origin, entity.enemy.origin ) > MARGWA_SWIPE_DIST_SQ )
	{
		return false;
	}

	yaw = abs( zombie_utility::getYawToEnemy() );
	if( ( yaw > MARGWA_MELEE_YAW ) )
	{
		return false;
	}
	
	return true;
}

function private margwaShouldShowPain( entity )
{
	if ( IsDefined( entity.headDestroyed ) )
	{
		headInfo = entity.head[ entity.headDestroyed ];
		switch( headInfo.cf )
		{
			case MARGWA_HEAD_LEFT_CLIENTFIELD:
				Blackboard::SetBlackBoardAttribute( self, MARGWA_HEAD, MARGWA_HEAD_LEFT );
				break;
				
			case MARGWA_HEAD_MID_CLIENTFIELD:
				Blackboard::SetBlackBoardAttribute( self, MARGWA_HEAD, MARGWA_HEAD_MIDDLE );
				break;
					
			case MARGWA_HEAD_RIGHT_CLIENTFIELD:
				Blackboard::SetBlackBoardAttribute( self, MARGWA_HEAD, MARGWA_HEAD_RIGHT );
				break;
		}

		return true;
	}

	return false;
}

function private margwaShouldReactStun( entity )
{
	if ( IS_TRUE( entity.reactStun ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldReactIDGun( entity )
{
	if ( IS_TRUE( entity.reactIDGun ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldReactSword( entity )
{
	if ( IS_TRUE( entity.reactSword ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldSpawn( entity )
{
	if ( IS_TRUE( entity.needSpawn ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldFreeze( entity )
{
	if ( IS_TRUE( entity.isFrozen ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldTeleportIn( entity )
{
	if ( IS_TRUE( entity.needTeleportIn ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldTeleportOut( entity )
{
	if ( IS_TRUE( entity.needTeleportOut ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldWait( entity )
{
	if ( IS_TRUE( entity.waiting ) )
	{
		return true;
	}

	return false;
}

function private margwaShouldReset( entity )
{
	if ( IsDefined( entity.headDestroyed ) )
	{
		return true;
	}

	if ( IS_TRUE( entity.reactIDGun ) )
	{
		return true;
	}

	if ( IS_TRUE( entity.reactSword ) )
	{
		return true;
	}

	if ( IS_TRUE( entity.reactStun ) )
	{
		return true;
	}

	return false;
}

//----------------------------------------------------------------------------------------------------------------------------------
// ACTIONS
//----------------------------------------------------------------------------------------------------------------------------------
function private margwaReactStunAction( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	stunActionAST = entity ASTSearch( IString( asmStateName ) );
	stunActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( entity, stunActionAST[ ASM_ALIAS_ATTRIBUTE ] );

	closeTime = GetAnimLength( stunActionAnimation ) * 1000;

	entity MargwaServerUtils::margwaCloseAllHeads( closeTime );

	MargwaBehavior::margwaReactStunStart( entity );

	return BHTN_RUNNING;
}


function private margwaSwipeAttackAction( entity, asmStateName )
{
	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	if ( !isdefined( entity.swipe_end_time ) )
	{
		swipeActionAST = entity ASTSearch( IString( asmStateName ) );
		swipeActionAnimation = AnimationStateNetworkUtility::SearchAnimationMap( entity, swipeActionAST[ ASM_ALIAS_ATTRIBUTE ] );
		swipeActionTime = GetAnimLength( swipeActionAnimation ) * 1000;

		entity.swipe_end_time = GetTime() + swipeActionTime;
	}

	return BHTN_RUNNING;
}

function private margwaSwipeAttackActionUpdate( entity, asmStateName )
{
	if ( isdefined( entity.swipe_end_time ) && GetTime() > entity.swipe_end_time )
	{
		return BHTN_SUCCESS;
	}

	return BHTN_RUNNING;
}

function private margwaIdleStart( entity )
{
	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_IDLE );
	}
}

function private margwaMoveStart( entity )
{
	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		if ( entity.zombie_move_speed == "run" )
		{
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_RUN );
		}
		else
		{
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_RUN_CHARGE );
		}
	}
}

function private margwaDeathAction( entity )
{
	//insert anything that needs to be done right before zombie death
}

function private margwaTraverseActionStart( entity )
{
	Blackboard::SetBlackBoardAttribute( entity, TRAVERSAL_TYPE, entity.traverseStartNode.animscript );

	if( isdefined( entity.traverseStartNode.animscript ) )
	{
		if ( entity MargwaServerUtils::shouldUpdateJaw() )
		{
			switch ( entity.traverseStartNode.animscript )
			{
			case "jump_down_36":
				entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TRV_JUMP_DOWN_36 );
				break;
	
			case "jump_down_96":
				entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TRV_JUMP_DOWN_96 );
				break;
	
			case "jump_up_36":
				entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TRV_JUMP_UP_36 );
				break;
	
			case "jump_up_96":
				entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TRV_JUMP_UP_96 );
				break;
			}
		}
	}
}

function private margwaTeleportInStart( entity )
{
	entity Unlink();
	if ( IsDefined( entity.teleportPos ) )
	{
		entity ForceTeleport( entity.teleportPos );
	}
	entity Show();
	entity PathMode( "move allowed" );
	entity.needTeleportIn = false;
	Blackboard::SetBlackBoardAttribute( self, MARGWA_TELEPORT, MARGWA_TELEPORT_IN );

	if ( isdefined( self.traveler ) )
	{
		self.traveler clientfield::set( MARGWA_FX_TRAVEL_CLIENTFIELD, MARGWA_TELEPORT_OFF );
	}
	self clientfield::increment( MARGWA_FX_IN_CLIENTFIELD, MARGWA_TELEPORT_ON );

	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TELEPORT_IN );
	}
}

function margwaTeleportInTerminate( entity )
{
	if ( isdefined( self.traveler ) )
	{
		self.traveler clientfield::set( MARGWA_FX_TRAVEL_CLIENTFIELD, MARGWA_TELEPORT_OFF );
	}
	entity.isTeleporting = false;
}

function private margwaTeleportOutStart( entity )
{
	entity.needTeleportOut = false;
	entity.isTeleporting = true;
	entity.teleportStart = entity.origin;

	Blackboard::SetBlackBoardAttribute( self, MARGWA_TELEPORT, MARGWA_TELEPORT_OUT );
	self clientfield::increment( MARGWA_FX_OUT_CLIENTFIELD, MARGWA_TELEPORT_ON );

	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_TELEPORT_OUT );
	}
}

function private margwaTeleportOutTerminate( entity )
{
	if ( isdefined( entity.traveler ) )
	{
		entity.traveler.origin = entity GetTagOrigin( MARGWA_TAG_TELEPORT );
		entity.traveler clientfield::set( MARGWA_FX_TRAVEL_CLIENTFIELD, MARGWA_TELEPORT_ON );
	}

	entity Ghost();
	entity PathMode( "dont move" );

	if ( isdefined( entity.traveler ) )
	{
		entity LinkTo( entity.traveler );
	}

	if ( isdefined( entity.margwaWait ) )
	{
		entity thread [[ entity.margwaWait ]]();
	}
	else
	{
		entity thread MargwaServerUtils::margwaWait();
	}
}

function private margwaPainStart( entity )
{
	entity notify( "stop_head_update" );

	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		head = Blackboard::GetBlackBoardAttribute( self, MARGWA_HEAD );
		switch ( head )
		{
		case MARGWA_HEAD_LEFT:
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_HEAD_L_EXPLODE );
			break;

		case MARGWA_HEAD_MIDDLE:
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_HEAD_M_EXPLODE );
			break;

		case MARGWA_HEAD_RIGHT:
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_HEAD_R_EXPLODE );
			break;

		}
	}

	entity.headDestroyed = undefined;
	entity.canStun = false;
	entity.canDamage = false;
}

function private margwaPainTerminate( entity )
{
	entity.headDestroyed = undefined;
	entity.canStun = true;
	entity.canDamage = true;

	entity MargwaServerUtils::margwaCloseAllHeads( MARGWA_PAIN_CLOSE_TIME );

	entity ClearPath();

	if ( IsDefined( entity.margwaPainTerminateCB ) )
	{
		entity [[ entity.margwaPainTerminateCB ]]();
	}
}

function private margwaReactStunStart( entity )
{
	entity.reactStun = undefined;
	entity.canStun = false;

	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_REACT_STUN );
	}
}

function margwaReactStunTerminate( entity )
{
	entity.canStun = true;
}

function private margwaReactIDGunStart( entity )
{
	entity.reactIDGun = undefined;
	entity.canStun = false;

	isPacked = false;
	
	if( BlackBoard::GetBlackBoardAttribute( entity, ZOMBIE_DAMAGEWEAPON_TYPE ) == ZOMBIE_DAMAGEWEAPON_REGULAR )
	{
		if ( entity MargwaServerUtils::shouldUpdateJaw() )
		{
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_REACT_IDGUN );
		}
		entity MargwaServerUtils::margwaCloseAllHeads( MARGWA_PAIN_CLOSE_TIME );
	}
	else
	{
		if ( entity MargwaServerUtils::shouldUpdateJaw() )
		{
			entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_REACT_IDGUN_PACKED );
		}
		entity MargwaServerUtils::margwaCloseAllHeads( 2 * MARGWA_PAIN_CLOSE_TIME );

		isPacked = true;
	}

	if ( IsDefined( entity.idgun_damage ) )
	{
		entity [[ entity.idgun_damage ]]( isPacked );
	}
}

function margwaReactIDGunTerminate( entity )
{
	entity.canStun = true;
	Blackboard::SetBlackBoardAttribute( entity, ZOMBIE_DAMAGEWEAPON_TYPE, ZOMBIE_DAMAGEWEAPON_REGULAR );
}

function private margwaReactSwordStart( entity )
{
	entity.reactSword = undefined;
	entity.canStun = false;

	if ( IsDefined( entity.head_chopper ) )
	{
		entity.head_chopper notify( "react_sword" );
	}
}

function private margwaReactSwordTerminate( entity )
{
	entity.canStun = true;
}

function private margwaSpawnStart( entity )
{
	entity.needSpawn = false;
}

function private margwaSmashAttackStart( entity )
{
	entity MargwaServerUtils::margwaHeadSmash();

	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_SMASH_ATTACK );
	}
}

function margwaSmashAttackTerminate( entity )
{
	entity MargwaServerUtils::margwaCloseAllHeads();
}

function margwaSwipeAttackStart( entity )
{
	if ( entity MargwaServerUtils::shouldUpdateJaw() )
	{
		entity clientfield::set( MARGWA_JAW_CLIENTFIELD, MARGWA_JAW_SWIPE_PLAYER );
	}
}

function private margwaSwipeattackTerminate( entity )
{
	entity MargwaServerUtils::margwaCloseAllHeads();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MOCOMPS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function private mocompMargwaTeleportTraversalInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity OrientMode( "face angle", entity.angles[1] );
	entity AnimMode( AI_ANIM_MOVE_CODE );

	if ( isdefined( entity.traverseEndNode ) )
	{
		entity.teleportStart = entity.origin;
		entity.teleportPos = entity.traverseEndNode.origin;
		self clientfield::increment( MARGWA_FX_OUT_CLIENTFIELD, MARGWA_TELEPORT_ON );

		if ( isdefined( entity.traverseStartNode ) )
		{
			if ( isdefined( entity.traverseStartNode.speed ) )
			{
				self.margwa_teleport_speed = entity.traverseStartNode.speed;
			}
		}
	}
}

function private mocompMargwaTeleportTraversalUpdate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
}

function private mocompMargwaTeleportTraversalTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	margwaTeleportOutTerminate( entity );
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#namespace MargwaServerUtils;

function private margwaSpawnSetup()
{
	self DisableAimAssist();

	self.disableAmmoDrop = true;
	self.no_gib = true;
	self.ignore_nuke = true;
	self.ignore_enemy_count = true;
	self.ignore_round_robbin_death = true; 

	self.zombie_move_speed = "walk";

	self.overrideActorDamage = &margwaDamage;
	self.canDamage = true;

	self.headAttached = MARGWA_NUM_HEADS;
	self.headOpen = 0;

	self margwaInitHead( MARGWA_MODEL_HEAD_LEFT, MARGWA_TAG_CHUNK_LEFT );
	self margwaInitHead( MARGWA_MODEL_HEAD_MID, MARGWA_TAG_CHUNK_MID );
	self margwaInitHead( MARGWA_MODEL_HEAD_RIGHT, MARGWA_TAG_CHUNK_RIGHT );

	self.headHealthMax = MARGWA_HEAD_HEALTH_BASE;

	self margwaDisableStun();

	self.traveler = Spawn( "script_model", self.origin );
	self.traveler SetModel( "tag_origin" );
	self.traveler NotSolid();

	self.travelerTell = Spawn( "script_model", self.origin );
	self.travelerTell SetModel( "tag_origin" );
	self.travelerTell NotSolid();

	self thread margwaDeath();

	self.updateSight = false;
	self.ignoreRunAndGunDist = true;
}

function private margwaDeath()
{
	self waittill( "death" );

	if( isdefined(self.e_head_attacker) )
	{
		self.e_head_attacker notify( "margwa_kill" );
	}

	if ( IsDefined( self.traveler ) )
	{
		self.traveler Delete();
	}

	if ( IsDefined( self.travelerTell ) )
	{
		self.travelerTell Delete();
	}
}

function margwaEnableStun()
{
	self.canStun = true;
}

function private margwaDisableStun()
{
	self.canStun = false;
}

function private margwaInitHead( headModel, headTag )
{	
	model = headModel;
	model_gore = undefined;
	
	switch ( headModel )
	{
	case MARGWA_MODEL_HEAD_LEFT:
		if( isdefined( level.margwa_head_left_model_override ))
		{
			model = level.margwa_head_left_model_override;
			model_gore = level.margwa_gore_left_model_override;
		}
		break;

	case MARGWA_MODEL_HEAD_MID:
		if( isdefined( level.margwa_head_mid_model_override ))
		{
			model = level.margwa_head_mid_model_override;
			model_gore = level.margwa_gore_mid_model_override;
		}
		break;

	case MARGWA_MODEL_HEAD_RIGHT:
		if( isdefined( level.margwa_head_right_model_override ))
		{
			model = level.margwa_head_right_model_override;
			model_gore = level.margwa_gore_right_model_override;
		}
		break;
	}
	
	self Attach( model );

	if ( !IsDefined( self.head ) )
	{
		self.head = [];
	}

	self.head[ model ] = SpawnStruct();
	self.head[ model ].model = model;
	self.head[ model ].tag = headTag;
	self.head[ model ].health = MARGWA_HEAD_HEALTH_BASE;
	self.head[ model ].canDamage = false;

	self.head[ model ].open = MARGWA_HEAD_OPEN;
	self.head[ model ].closed = MARGWA_HEAD_CLOSED;
	self.head[ model ].smash = MARGWA_HEAD_SMASH_ATTACK;

	switch ( headModel )
	{
	case MARGWA_MODEL_HEAD_LEFT:
		self.head[ model ].cf = MARGWA_HEAD_LEFT_CLIENTFIELD;
		self.head[ model ].impactCF = MARGWA_HEAD_LEFT_HIT_CLIENTFIELD;
		self.head[ model ].gore = MARGWA_MODEL_GORE_LEFT;
		if( isdefined( model_gore ))
		{
			self.head[ model ].gore = model_gore;
		}
		self.head[ model ].killIndex = MARGWA_HEAD_KILLED_LEFT;
		self.head_left_model = model;
		break;

	case MARGWA_MODEL_HEAD_MID:
		self.head[ model ].cf = MARGWA_HEAD_MID_CLIENTFIELD;
		self.head[ model ].impactCF = MARGWA_HEAD_MID_HIT_CLIENTFIELD;
		self.head[ model ].gore = MARGWA_MODEL_GORE_MID;
		if( isdefined( model_gore ))
		{
			self.head[ model ].gore = model_gore;
		}
		self.head[ model ].killIndex = MARGWA_HEAD_KILLED_MID;
		self.head_mid_model = model;
		break;

	case MARGWA_MODEL_HEAD_RIGHT:
		self.head[ model ].cf = MARGWA_HEAD_RIGHT_CLIENTFIELD;
		self.head[ model ].impactCF = MARGWA_HEAD_RIGHT_HIT_CLIENTFIELD;
		self.head[ model ].gore = MARGWA_MODEL_GORE_RIGHT;
		if( isdefined( model_gore ))
		{
			self.head[ model ].gore = model_gore;
		}
		self.head[ model ].killIndex = MARGWA_HEAD_KILLED_RIGHT;
		self.head_right_model = model;
		break;
	}

	self thread margwaHeadUpdate( self.head[ model ] );
}

function margwaSetHeadHealth( health )
{
	self.headHealthMax = health;

	foreach( head in self.head )
	{
		head.health = health;
	}
}

function private margwaResetHeadTime( min, max )
{
	time = GetTime() + RandomIntRange( min, max );
	return time;
}

function private margwaHeadCanOpen()
{
	if ( self.headAttached > 1 )
	{
		if ( self.headOpen < (self.headAttached - 1) )
		{
			return true;
		}
	}
	else
	{
		return true;
	}

	return false;
}

function private margwaHeadUpdate( headInfo )
{
	self endon( "death" );
	self endon( "stop_head_update" );

	headInfo notify( "stop_head_update" );
	headInfo endon( "stop_head_update" );

	while ( 1 )
	{
		if ( self IsPaused() )
		{
			util::wait_network_frame();
			continue;
		}
	
		if ( !IsDefined( headInfo.closeTime ) )
		{
			if ( self.headAttached == 1 )
			{
				headInfo.closeTime = margwaResetHeadTime( MARGWA_SINGLE_HEAD_CLOSE_MIN, MARGWA_SINGLE_HEAD_CLOSE_MAX );
			}
			else
			{
				headInfo.closeTime = margwaResetHeadTime( MARGWA_HEAD_CLOSE_MIN, MARGWA_HEAD_CLOSE_MAX );
			}
		}

		if ( GetTime() > headInfo.closeTime && self margwaHeadCanOpen() )
		{
			self.headOpen++;
			headInfo.closeTime = undefined;
		}
		else
		{
			util::wait_network_frame();
			continue;
		}

		self margwaHeadDamageDelay( headInfo, true );
		self clientfield::set( headInfo.cf, headInfo.open );
		self playsoundontag( "zmb_vocals_margwa_ambient", headInfo.tag );

		while ( 1 )
		{
			if ( !IsDefined( headInfo.openTime ) )
			{
				headInfo.openTime = margwaResetHeadTime( MARGWA_HEAD_OPEN_MIN, MARGWA_HEAD_OPEN_MAX );
			}

			if ( GetTime() > headInfo.openTime )
			{
				self.headOpen--;
				headInfo.openTime = undefined;
				break;
			}
			else
			{
				util::wait_network_frame();
				continue;
			}
		}

		self margwaHeadDamageDelay( headInfo, false );
		self clientfield::set( headInfo.cf, headInfo.closed );
	}
}

function private margwaHeadDamageDelay( headInfo, canDamage )
{
	self endon( "death" );

	wait( MARGWA_MOUTH_BLEND_TIME );

	headInfo.canDamage = canDamage;
}

function private margwaHeadSmash()
{
	self notify( "stop_head_update" );

	headAlive = [];
	foreach( head in self.head )
	{
		if ( head.health > 0 )
		{
			headAlive[ headAlive.size ] = head;
		}
	}

	headAlive = array::randomize( headAlive );
	open = false;

	foreach( head in headAlive )
	{
		if ( !open )
		{
			head.canDamage = true;
			self clientfield::set( head.cf, head.smash );
			open = true;
		}
		else
		{
			self margwaCloseHead( head );
		}
	}
}

function private margwaCloseHead( headInfo )
{
	headInfo.canDamage = false;
	self clientfield::set( headInfo.cf, headInfo.closed );
}

function private margwaCloseAllHeads( closeTime )
{
	if ( self IsPaused() )
	{
		return;
	}

	foreach ( head in self.head )
	{
		if ( head.health > 0 )
		{
			head.closeTime = undefined;
			head.openTime = undefined;

			if ( IsDefined( closeTime ) )
			{
				head.closeTime = GetTime() + closeTime;
			}

			self.headOpen = 0;

			self margwaCloseHead( head );
			self thread margwaHeadUpdate( head );
		}
	}
}

function margwaKillHead( modelHit, attacker )
{
	headInfo = self.head[ modelHit ];

	headInfo.health = 0;
	headInfo notify( "stop_head_update" );

	if ( IS_TRUE( headInfo.canDamage ) )
	{
		self margwaCloseHead( headInfo );
		self.headOpen--;
	}

	self margwaUpdateMoveSpeed();

	if ( IsDefined( self.destroyHeadCB ) )
	{
		self thread [[ self.destroyHeadCB ]]( modelHit, attacker );
	}

	self clientfield::set( MARGWA_HEAD_KILLED_CLIENTFIELD, headInfo.killIndex );

	self Detach( headInfo.model );
	self Attach( headInfo.gore );
	self.headAttached--;

	if ( self.headAttached <= 0 )
	{
		self.e_head_attacker = attacker;
		return true;
	}
	else
	{
		self.headDestroyed = modelHit;
	}

	return false;
}

function margwaCanDamageAnyHead()
{
	foreach( head in self.head )
	{
		if ( IsDefined( head ) && head.health > 0 && IS_TRUE( head.canDamage ) )
		{
			return true;
		}
	}
	
	return false;
}

function margwaCanDamageHead()
{
	if ( IsDefined( self ) && self.health > 0 && IS_TRUE( self.canDamage ) )
	{
		return true;
	}

	return false;
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

function private isDirectHitWeapon( weapon )
{
	foreach( dhWeapon in level.dhWeapons )
	{
		if ( weapon.name == dhWeapon )
		{
			return true;
		}

		if ( isdefined( weapon.rootweapon ) && isdefined( weapon.rootweapon.name ) && weapon.rootweapon.name == dhWeapon )
		{
			return true;
		}
	}

	return false;
}


// uses the bone name to figure out which head was hit
function margwaDamage( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if ( IS_TRUE( self.is_kill ) )
	{
		return damage;
	}

	if( isdefined(attacker) && isdefined(attacker.n_margwa_head_damage_scale) )
	{
	   	damage = damage * attacker.n_margwa_head_damage_scale;
	}
	
	if( isdefined( level._margwa_damage_cb ) )
	{
		n_result = [[ level._margwa_damage_cb ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
		
		if( isdefined( n_result ) )
		{
			return n_result;
		}
	}
	
	damageOpen = false;		// mouth was open during damage
	
	if ( !IS_TRUE( self.canDamage ) )
	{
		self.health += 1;	// impact fx only work when damage is applied
		return 1;
	}

	if ( isDirectHitWeapon( weapon ) )
	{
		headAlive = [];
		foreach ( head in self.head )
		{
			if ( head margwaCanDamageHead() )
			{
				headAlive[ headAlive.size ] = head;
			}
		}

		if ( headAlive.size > 0 )
		{
			max = 100000;
			headClosest = undefined;
			foreach ( head in headAlive )
			{
				distSq = DistanceSquared( point, self GetTagOrigin( head.tag ) );
				if ( distSq < max )
				{
					max = distSq;
					headClosest = head;
				}
			}
			if ( IsDefined( headClosest ) )
			{
				if ( max < MARGWA_HEAD_DAMAGE_RANGE )
				{
					if ( isdefined( level.margwa_damage_override_callback ) && IsFunctionPtr( level.margwa_damage_override_callback ) )
					{
						damage = attacker [[ level.margwa_damage_override_callback ]]( damage );
					}
					
					headClosest.health -= damage;
					damageOpen = true;
					self clientfield::increment( headClosest.impactCF );
					attacker show_hit_marker();

					if ( headClosest.health <= 0 )
					{
						if( isdefined(level.margwa_head_kill_weapon_check) )
						{
							[[level.margwa_head_kill_weapon_check]]( self, weapon );
						}
						
						if ( self margwaKillHead( headClosest.model, attacker ) )
						{
							return self.health;
						}
					}
				}
			}
		}
	}
	
	partName = GetPartName( self.model, boneIndex );
	if ( IsDefined( partName ) )
	{
		/#
			if ( IS_TRUE( self.debugHitLoc ) )
			{
				PrintTopRightLn( partName + " damage: " + damage );
			}
		#/
		modelHit = self margwaHeadHit( self, partName );
		if ( IsDefined( modelHit ) )
		{
			headInfo = self.head[ modelHit ];
			if ( headInfo margwaCanDamageHead() )
			{
				if ( isdefined( level.margwa_damage_override_callback ) && IsFunctionPtr( level.margwa_damage_override_callback ) )
				{
					damage = attacker [[ level.margwa_damage_override_callback ]]( damage );
				}
				
				if( isdefined( attacker ) )
				{
					attacker notify( "margwa_headshot", self );
				}
				
				headInfo.health -= damage;
				damageOpen = true;
				self clientfield::increment( headInfo.impactCF );
				attacker show_hit_marker();

				if ( headInfo.health <= 0 )
				{
					if( isdefined(level.margwa_head_kill_weapon_check) )
					{
						[[level.margwa_head_kill_weapon_check]]( self, weapon );
					}

					if ( self margwaKillHead( modelHit, attacker ) )
					{
						return self.health;
					}
				}
			}
		}
	}

	if ( damageOpen )
	{
		return 0;		// custom fx when damaging head
	}

	self.health += 1;	// impact fx only work when damage is applied to ent
	return 1;
}

function private margwaHeadHit( entity, partName )
{
	switch ( partName )
	{
	case MARGWA_TAG_CHUNK_LEFT:
	case MARGWA_TAG_JAW_LEFT:
		return self.head_left_model;

	case MARGWA_TAG_CHUNK_MID:
	case MARGWA_TAG_JAW_MID:
		return self.head_mid_model;

	case MARGWA_TAG_CHUNK_RIGHT:
	case MARGWA_TAG_JAW_RIGHT:
		return self.head_right_model;
	}

	return undefined;
}

function private margwaUpdateMoveSpeed()
{
	if ( self.zombie_move_speed == "walk" )
	{
		self.zombie_move_speed = "run";
		//self ASMSetAnimationRate( 0.8 );
		Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_RUN );
	}
	else if ( self.zombie_move_speed == "run" )
	{
		self.zombie_move_speed = "sprint";
		//self ASMSetAnimationRate( 1.0 );
		Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
	}
}

function margwaForceSprint()
{
	self.zombie_move_speed = "sprint";
	Blackboard::SetBlackBoardAttribute( self, LOCOMOTION_SPEED_TYPE, LOCOMOTION_SPEED_SPRINT );
}

function private margwaDestroyHead( modelHit )
{
}

function shouldUpdateJaw()
{
	if ( !IS_TRUE( self.jawAnimEnabled ) )
	{
		return false;
	}

	if ( self.headAttached < MARGWA_NUM_HEADS )
	{
		return true;
	}

	return false;
}

function margwaSetGoal( origin, radius, boundaryDist )
{
	pos = GetClosestPointOnNavMesh( origin, MARGWA_NAVMESH_RADIUS, MARGWA_NAVMESH_BOUNDARY_DIST );
	if ( IsDefined( pos ) )
	{
		self SetGoal( pos );
		return true;
	}

	self SetGoal( self.origin );
	return false;
}

function private margwaWait()
{
	self endon( "death" );

	self.waiting = true;
	self.needTeleportIn = true;

	destPos = self.teleportPos + ( 0, 0, MARGWA_TRAVELER_HEIGHT_OFFSET );
	dist = Distance( self.teleportStart, destPos );
	time = dist / MARGWA_TRAVELER_SPEED;

	if ( isdefined( self.margwa_teleport_speed ) )
	{
		if ( self.margwa_teleport_speed > 0 )
		{
			time = dist / self.margwa_teleport_speed;
		}
	}

	if ( isdefined( self.traveler ) )
	{
		self thread margwaTell();

		self.traveler MoveTo( destPos, time );
		self.traveler util::waittill_any_ex( ( time + 0.1 ), "movedone", self, "death" );

		self.travelerTell clientfield::set( MARGWA_FX_TRAVEL_TELL_CLIENTFIELD, MARGWA_TELEPORT_OFF );
	}

	self.waiting = false;
	self.needTeleportOut = false;

	if ( isdefined( self.margwa_teleport_speed ) )
	{
		self.margwa_teleport_speed = undefined;
	}
}

function margwaTell()
{
	self endon( "death" );

	self.travelerTell.origin = self.teleportPos;

	util::wait_network_frame();

	self.travelerTell clientfield::set( MARGWA_FX_TRAVEL_TELL_CLIENTFIELD, MARGWA_TELEPORT_ON );
}

function private shieldFacing( vDir, limit, front = true )
{
	orientation = self getPlayerAngles();
	forwardVec = anglesToForward( orientation );
	if ( !front )
	{
		forwardVec = -forwardVec;
	}
	forwardVec2D = ( forwardVec[0], forwardVec[1], 0 );
	unitForwardVec2D = VectorNormalize( forwardVec2D );

	toFaceeVec = -vDir;
	toFaceeVec2D = ( toFaceeVec[0], toFaceeVec[1], 0 );
	unitToFaceeVec2D = VectorNormalize( toFaceeVec2D );
	
	dotProduct = VectorDot( unitForwardVec2D, unitToFaceeVec2D );
	return ( dotProduct > limit ); // more or less in front
}

function private inSmashAttackRange( enemy )
{
	smashPos = self.origin;
	
	heightOffset = abs( self.origin[2] - enemy.origin[2] );
	if ( heightOffset > MARGWA_SMASH_ATTACK_HEIGHT )
	{
		return false;
	}
	
	distSq = DistanceSquared( smashPos, enemy.origin );
	range = MARGWA_SMASH_ATTACK_START;

	if ( distSq < range )
	{
		return true;
	}

	return false;
}
