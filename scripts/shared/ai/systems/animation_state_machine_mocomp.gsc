#insert scripts\shared\shared.gsh;

#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;

// Created and Implemented by Sumeet Jakatdar
#define NULL 0
#define IS_NULL(variable) (IsInt(variable) && variable == 0)

#namespace AnimationStateNetwork;

// ------------- AnimationMocomp Initialization ----------- //
function autoexec InitAnimationMocomps()
{
	level._AnimationMocomps = [];
}


// ------------- AnimationMocomp Utility ----------- //
function RunAnimationMocomp( mocompName, mocompStatus, asmEntity, mocompAnim, mocompAnimBlendOutTime, mocompDuration )
{
	Assert( ( mocompStatus >= 0 && mocompStatus <= 2 ), "ASM - Unsupported MocompStatus " + mocompStatus + " for RunAnimationMocomp." );
	
	Assert( IsDefined( level._AnimationMocomps[mocompName] ), "BT - RegisterAnimationMocomps with " + mocompName + " does not exists." );

	if( mocompStatus == 0 )
		mocompStatus = ASM_MOCOMP_START;
	else if( mocompStatus == 1 )
		mocompStatus = ASM_MOCOMP_UPDATE;
	else
		mocompStatus = ASM_MOCOMP_TERMINATE;
			
	animationMocompResult = asmEntity [[level._AnimationMocomps[mocompName][mocompStatus]]]( asmEntity, mocompAnim, mocompAnimBlendOutTime, "", mocompDuration );
	
	return animationMocompResult;
}

// ------------- AnimationMocomp API ----------- //
function RegisterAnimationMocomp( mocompName, startFuncPtr, updateFuncPtr, terminateFuncPtr )
{
	mocompName = ToLower( mocompName );
	
	Assert( IsString( mocompName ), "ASM - mocompName for RegisterAnimationMocomps is not a string." );
	Assert( !IsDefined(level._AnimationMocomps[mocompName]), "mocomp with name " + mocompName + " is already registered." );
		
	level._AnimationMocomps[mocompName] = array();
	
	// ASM_MOCOMP_START
	Assert( IsDefined( startFuncPtr ) && IsFunctionPtr( startFuncPtr ), "BT - RegisterAnimationMocomps must have startFunctionPtr and it must be of type functionPtr." );
	level._AnimationMocomps[mocompName][ASM_MOCOMP_START] = startFuncPtr;
		
	// ASM_MOCOMP_UPDATE
	if( IsDefined( updateFuncPtr ) )
	{
		Assert( IsFunctionPtr( updateFuncPtr ), "BT - RegisterAnimationMocomps must have updateFuncPtr and it must be of type functionPtr." );
		level._AnimationMocomps[mocompName][ASM_MOCOMP_UPDATE] = updateFuncPtr;
	}
	else
	{
		level._AnimationMocomps[mocompName][ASM_MOCOMP_UPDATE] = &AnimationMocompEmptyFunc;
	}
	
	// ASM_MOCOMP_UPDATE
	if( IsDefined( terminateFuncPtr ) )
	{
		Assert( IsFunctionPtr( terminateFuncPtr ), "BT - RegisterAnimationMocomps must have terminateFuncPtr and it must be of type functionPtr." );
		level._AnimationMocomps[mocompName][ASM_MOCOMP_TERMINATE] = terminateFuncPtr;
	}
	else
	{
		level._AnimationMocomps[mocompName][ASM_MOCOMP_TERMINATE] = &AnimationMocompEmptyFunc;
	}
}

function AnimationMocompEmptyFunc( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	
}
