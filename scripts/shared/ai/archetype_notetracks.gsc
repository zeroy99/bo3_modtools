#using scripts\shared\ai\archetype_human_cover;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\aivsaimelee.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;

#namespace AnimationStateNetwork;

function autoexec RegisterDefaultNotetrackHandlerFunctions()
{
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_FIRE_BULLET,				&notetrackFireBullet );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_DISABLE,				&notetrackGibDisable );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_HEAD,					&GibServerUtils::GibHead );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_ARM_LEFT,				&GibServerUtils::GibLeftArm );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_ARM_RIGHT,			&GibServerUtils::GibRightArm );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_LEG_LEFT,				&GibServerUtils::GibLeftLeg );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GIB_LEG_RIGHT,			&GibServerUtils::GibRightLeg );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_DROPGUN,					&notetrackDropGun );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_DROP_GUN_1,				&notetrackDropGun );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_DROP_SHIELD,				&notetrackDropShield );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_HIDE_WEAPON,				&notetrackHideWeapon );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_SHOW_WEAPON,				&notetrackShowWeapon );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_HIDE_AI,					&notetrackHideAI );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_SHOW_AI,					&notetrackShowAI );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_ATTACH_KNIFE,				&notetrackAttachKnife );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_DETACH_KNIFE,				&notetrackDetachKnife );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_GRENADE_THROW,			&notetrackGrenadeThrow );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_RAGDOLL,					&notetrackStartRagdoll );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_RAGDOLL_NODEATH,			&notetrackStartRagdollNoDeath );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_MELEE_UNSYNC,				&notetrackMeleeUnsync );
	
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_STAIRS_STEP1,				&notetrackStaircaseStep1 );
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_STAIRS_STEP2,				&notetrackStaircaseStep2 );
	
	ASM_REGISTER_NOTETRACK_HANDLER( NOTETRACK_MOVEMENT_STOP,			&notetrackAnimMovementStop );
	
	ASM_REGISTER_BLACKBOARD_NOTETRACK_HANDLER( NOTETRACK_STANCE_STAND, STANCE, STANCE_STAND );
	ASM_REGISTER_BLACKBOARD_NOTETRACK_HANDLER( NOTETRACK_STANCE_CROUCH, STANCE, STANCE_CROUCH );
	ASM_REGISTER_BLACKBOARD_NOTETRACK_HANDLER( NOTETRACK_STANCE_PRONE_FRONT, STANCE, STANCE_PRONE_ON_FRONT );
	ASM_REGISTER_BLACKBOARD_NOTETRACK_HANDLER( NOTETRACK_STANCE_PRONE_BACK, STANCE, STANCE_PRONE_ON_BACK );
}

function private notetrackAnimMovementStop( entity )
{
	if( entity HasPath() )
	{
		entity PathMode( "move delayed", true, RandomFloatRange( 2, 4 ) );
	}
}

function private notetrackStaircaseStep1( entity )
{
	numSteps = Blackboard::GetBlackBoardAttribute( entity, STAIRCASE_NUM_STEPS );
	numSteps++;
	
	Blackboard::SetBlackBoardAttribute( entity, STAIRCASE_NUM_STEPS, numSteps );
}

function private notetrackStaircaseStep2( entity )
{
	numSteps = Blackboard::GetBlackBoardAttribute( entity, STAIRCASE_NUM_STEPS );
	numSteps += 2;
	
	Blackboard::SetBlackBoardAttribute( entity, STAIRCASE_NUM_STEPS, numSteps );
}

function private notetrackDropGunInternal( entity )
{	
	if( entity.weapon == level.weaponNone )
		return;
	
	entity.lastWeapon	= entity.weapon;
	primaryweapon		= entity.primaryweapon;
	secondaryweapon		= entity.secondaryweapon;
	
	entity thread shared::DropAIWeapon();
}

// necessary for AI vs AI melees where soldiers need to stab each other
function private notetrackAttachKnife( entity )
{
	if( !IS_TRUE( entity._ai_melee_attachedKnife ) )
	{
		entity Attach( KNIFE_MODEL, "TAG_WEAPON_LEFT" );
		entity._ai_melee_attachedKnife = true;
	}
}

function private notetrackDetachKnife( entity )
{
	if( IS_TRUE( entity._ai_melee_attachedKnife ) )
	{
		entity Detach( KNIFE_MODEL, "TAG_WEAPON_LEFT" );
		entity._ai_melee_attachedKnife = false;
	}
}

function private notetrackHideWeapon( entity )
{
	entity ai::gun_remove();
}

function private notetrackShowWeapon( entity )
{
	entity ai::gun_recall();
}


function private notetrackHideAI( entity )
{
	entity Hide();
}

function private notetrackShowAI( entity )
{
	entity Show();
}

function private notetrackStartRagdoll( entity )
{
    if( IsActor( entity ) && entity IsInScriptedState() )
    {
    	entity.overrideActorDamage = undefined;
    	entity.allowdeath = true;//This ignores/overrides the scene setting if set
    	entity.skipdeath = true;
        entity Kill();
    }
	
	// SUMEET HACK - drop gun, if its not dropped already
	notetrackDropGunInternal( entity );
	entity StartRagdoll();
}

function _DelayedRagdoll( entity )
{
	wait 0.25;
	
	if ( IsDefined( entity ) && !entity IsRagdoll() )
	{
		entity StartRagdoll();
	}
}

function notetrackStartRagdollNoDeath( entity )
{
	if( IsDefined( entity._ai_melee_opponent ) )
	{
		entity._ai_melee_opponent Unlink();
	}
	
	// Delay ragdoll to let more of the animscripted to play out.
	entity thread _DelayedRagdoll( entity );
}

function private notetrackFireBullet( animationEntity )
{
	// Fire a MagicBullet in scripted animations
	if ( IsActor( animationEntity ) && animationEntity IsInScriptedState() )
	{
		if( animationEntity.weapon != level.weaponNone )
		{
			animationEntity notify("about_to_shoot");
			
			startPos	= animationEntity GetTagOrigin( "tag_flash" );
			endPos 		= startPos + VectorScale( animationEntity GetWeaponForwardDir(), 100 );
			MagicBullet( animationEntity.weapon, startPos, endPos, animationEntity );
			
			animationEntity notify("shoot");
			animationEntity.bulletsInClip--;
		}
	}
}

function private notetrackDropGun( animationEntity )
{
	notetrackDropGunInternal( animationEntity );
}

function private notetrackDropShield( animationEntity )
{
	AiUtility::dropRiotshield( animationEntity );
}

function private notetrackGrenadeThrow( animationEntity )
{
	if ( archetype_human_cover::shouldThrowGrenadeAtCoverCondition( animationEntity, true ) )
	{
		animationEntity GrenadeThrow();
	}
	else if ( IsDefined( animationEntity.grenadeThrowPosition ) )
	{
		// Fallback to throwing the grenade at the last valid position.
		arm_offset = archetype_human_cover::TEMP_get_arm_offset( animationEntity, animationEntity.grenadeThrowPosition );
		throw_vel = animationEntity CanThrowGrenadePos( arm_offset, animationEntity.grenadeThrowPosition );
	
		if ( IsDefined( throw_vel ) )
		{
			animationEntity GrenadeThrow();
		}
	}
}

function private notetrackMeleeUnsync( animationEntity )
{
	if( IsDefined( animationEntity ) && IsDefined( animationEntity.enemy ) )
	{
		if( IS_TRUE( animationEntity.enemy._ai_melee_markedDead ) )
		{
			animationEntity unlink();
		}
	}
}

function private notetrackGibDisable( animationEntity )
{
	if ( animationEntity ai::has_behavior_attribute( "can_gib" ) )
	{
		animationEntity ai::set_behavior_attribute( "can_gib", false );
	}
}