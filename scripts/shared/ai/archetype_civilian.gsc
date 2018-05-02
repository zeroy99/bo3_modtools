#using scripts\shared\ai_shared;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_state_machine;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\spawner_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\behavior_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\shared.gsh;

function autoexec main()
{
	ArchetypeCivilian::RegisterBehaviorScriptFunctions();
}

#namespace ArchetypeCivilian;

function RegisterBehaviorScriptFunctions()
{
	// ------- SPAWN FUNCTIONS ------------//
	spawner::add_archetype_spawn_function( ARCHETYPE_CIVILIAN, &civilianBlackboardInit );
	spawner::add_archetype_spawn_function( ARCHETYPE_CIVILIAN, &archetypeCivilianInit );

	// register some required ai interface attributes
	ai::RegisterMatchedInterface( ARCHETYPE_CIVILIAN, "sprint", false, array( true, false ) );
	ai::RegisterMatchedInterface( ARCHETYPE_CIVILIAN, "panic", false, array( true, false ) );

	// ------- CIVILIAN ACTIONS -----------//
	BT_REGISTER_ACTION( "civilianMoveAction",	&civilianMoveActionInitialize,	undefined,	&civilianMoveActionFinalize );
	BT_REGISTER_ACTION( "civilianCowerAction",	&civilianCowerActionInitialize,	undefined,	undefined );
	
	BT_REGISTER_API( "civilianIsPanicked",	&civilianIsPanicked );
	
	BT_REGISTER_API( "civilianPanic", &civilianPanic );
	BSM_REGISTER_API( "civilianPanic", &civilianPanic );
}

function private civilianBlackboardInit() // self = AI
{
	// CREATE BLACKBOARD
	Blackboard::CreateBlackBoardForEntity( self );

	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( self );

	// USE UTILITY BLACKBOARD
	self AiUtility::RegisterUtilityBlackboardAttributes();
	
	// CREATE CIVILIAN BLACKBOARD
	BB_REGISTER_ATTRIBUTE( PANIC, PANIC_NO, &BB_GetPanic );
	BB_REGISTER_ATTRIBUTE( HUMAN_LOCOMOTION_VARIATION, undefined, undefined );
	
	// REGISTER ANIMSCRIPTED CALLBACK
	self.___ArchetypeOnAnimscriptedCallback = &civilianOnAnimscriptedCallback;
		
	// ENABLE DEBUGGING IN ODYSSEY
	ENABLE_BLACKBOARD_DEBUG_TRACKING(self);
}

function private archetypeCivilianInit()
{
	entity = self;
	
	locomotionTypes = array( "alt1", "alt2", "alt3", "alt4" );
	altIndex = entity GetEntityNumber() % locomotionTypes.size;
	
	Blackboard::SetBlackBoardAttribute( entity, HUMAN_LOCOMOTION_VARIATION, locomotionTypes[ altIndex ] );
	
	entity SetAvoidanceMask( "avoid ai" );
}

function private BB_GetPanic()
{
	if ( ai::GetAiAttribute( self, "panic" ) )
		return PANIC_YES;
	return PANIC_NO;
}

function private civilianOnAnimscriptedCallback( entity )
{
	// UNREGISTER THE BLACKBOARD
	entity.__blackboard = undefined;

	// REREGISTER BLACKBOARD
	entity civilianBlackboardInit();
}

function private civilianMoveActionInitialize( entity, asmStateName )
{
	Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );

	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	return BHTN_RUNNING;
}

function private civilianMoveActionFinalize( entity, asmStateName )
{
	if ( Blackboard::GetBlackBoardAttribute( entity, STANCE ) != DEFAULT_MOVEMENT_STANCE )
	{
		Blackboard::SetBlackBoardAttribute( entity, DESIRED_STANCE, DEFAULT_MOVEMENT_STANCE );
	}

	return BHTN_SUCCESS;
}

function private civilianCowerActionInitialize( entity, asmStateName )
{
	if ( isdefined( entity.node ) )
	{
		highestStance = AiUtility::getHighestNodeStance( entity.node );
		if ( highestStance == "crouch" )
		{
			Blackboard::SetBlackBoardAttribute( entity, STANCE, STANCE_CROUCH );
		}
		else
		{
			Blackboard::SetBlackBoardAttribute( entity, STANCE, DEFAULT_MOVEMENT_STANCE );
		}
	}

	AnimationStateNetworkUtility::RequestState( entity, asmStateName );

	return BHTN_RUNNING;
}

function private civilianIsPanicked( entity )
{
	return Blackboard::GetBlackBoardAttribute( entity, PANIC ) == PANIC_YES;
}

function private civilianPanic( entity )
{
	entity ai::set_behavior_attribute( "panic", true );
	
	return true;
}

// end #namespace ArchetypeCivilian;
