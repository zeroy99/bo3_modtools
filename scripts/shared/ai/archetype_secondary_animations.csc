#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\shared.gsh;

// SUMEET TODO
// A very temp secondary (facial only currently) system for AI's.
// Need to make it data driven and support many things after DPS
// We can possibly use this system for any archetype to animate some bones which are 
// purely for cosmetic reasons.

#define FACIAL_STATE_COMBAT 		"combat"
#define FACIAL_STATE_COMBAT_AIM		"combat_aim"
#define FACIAL_STATE_COMBAT_SHOOT 	"combat_shoot"
#define FACIAL_STATE_DEATH 			"death"
#define FACIAL_STATE_MELEE 			"melee"
#define FACIAL_STATE_PAIN 			"pain"
#define FACIAL_STATE_ANIMSCRIPTED	"animscripted"
	
#define FACIAL_STATE_INACTIVE 		"inactive"

#define FACIAL_SYSTEM_FADE_DIST		GetDvarInt( "ai_clientFacialCullDist", 2000 )

#using_animtree( "generic" );

function autoexec main()
{
	if ( SessionModeIsZombiesGame() && GetDvarInt( "splitscreen_playerCount" ) > 2 )
		return; 
	
	ai::add_archetype_spawn_function( ARCHETYPE_HUMAN, &SecondaryAnimationsInit );
	ai::add_archetype_spawn_function( ARCHETYPE_ZOMBIE, &SecondaryAnimationsInit );	

	ai::add_ai_spawn_function( &on_entity_spawn );
}

function private SecondaryAnimationsInit( localClientNum )
{
	if( !IsDefined( level.__facialAnimationsList ) )
	{
		BuildAndValidateFacialAnimationList( localClientNum );
	}
	
	self callback::on_shutdown( &on_entity_shutdown );

	// Handle facial animations
	self thread SecondaryFacialAnimationThink( localClientNum );
}

function private on_entity_spawn( localClientNum )
{
	if ( self HasDObj( localClientNum ) )
	{
		self ClearAnim( %faces, 0 );	// stale facial anims from the previous entity may still be running
	}
	self._currentFaceState = FACIAL_STATE_INACTIVE;
}

function private on_entity_shutdown( localClientNum )
{	
	if( isdefined( self ) )
	{
		self notify("stopFacialThread");
	
		if ( IS_TRUE( self.facialDeathAnimStarted ) )
			return;

		self ApplyDeathAnim( localClientNum );	
		self.facialDeathAnimStarted = true;
	}
}

function BuildAndValidateFacialAnimationList( localClientNum )
{
	assert( !IsDefined( level.__facialAnimationsList ) );
	
	level.__facialAnimationsList = [];
	
	// HUMANS
	level.__facialAnimationsList[ARCHETYPE_HUMAN] = [];
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_COMBAT] 			= array( "ai_face_male_generic_idle_1","ai_face_male_generic_idle_2","ai_face_male_generic_idle_3" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_COMBAT_AIM] 		= array( "ai_face_male_aim_idle_1","ai_face_male_aim_idle_2","ai_face_male_aim_idle_3" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_COMBAT_SHOOT] 	= array( "ai_face_male_aim_fire_1","ai_face_male_aim_fire_2","ai_face_male_aim_fire_3" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_DEATH] 			= array( "ai_face_male_death_1","ai_face_male_death_2","ai_face_male_death_3" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_MELEE] 			= array( "ai_face_male_melee_1" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_PAIN] 			= array( "ai_face_male_pain_1" );
	level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_ANIMSCRIPTED] 	= array( "ai_face_male_generic_idle_1" );
		
	// ZOMBIES
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE] = [];
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_COMBAT] 		= array( "ai_face_zombie_generic_idle_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_COMBAT_AIM] 	= array( "ai_face_zombie_generic_idle_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_COMBAT_SHOOT] 	= array( "ai_face_zombie_generic_idle_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_DEATH] 			= array( "ai_face_zombie_generic_death_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_MELEE] 			= array( "ai_face_zombie_generic_attack_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_PAIN] 			= array( "ai_face_zombie_generic_pain_1" );
	level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_ANIMSCRIPTED] 	= array( "ai_face_zombie_generic_idle_1" );
	
	
	// validate death animations against looping flag
	deathAnims = [];
	
	foreach( animation in level.__facialAnimationsList[ARCHETYPE_HUMAN][FACIAL_STATE_DEATH] )
	{
		array::add( deathAnims, animation );
	}
	
	foreach( animation in level.__facialAnimationsList[ARCHETYPE_ZOMBIE][FACIAL_STATE_DEATH] )
	{
		array::add( deathAnims, animation );
	}
	
	foreach( deathAnim in deathAnims )
	{
		assert( !IsAnimLooping( localClientNum, deathAnim ), "FACIAL ANIM - Death facial animation " + deathAnim + " is set to looping in the GDT. It needs to be non-looping." );
	}
}

function private GetFacialAnimOverride( localClientNum )
{
	if ( SessionModeIsCampaignGame() )
	{
		// get the primary delta anim and see if it has any notetracks
		primaryDeltaAnim = self GetPrimaryDeltaAnim();
		if ( isdefined( primaryDeltaAnim ) )
		{
			primaryDeltaAnimLength = GetAnimLength( primaryDeltaAnim );
			notetracks = GetNotetracksInDelta( primaryDeltaAnim, 0, 1 );
			foreach( notetrack in notetracks )
			{
				if ( notetrack[1] == "facial_anim" )
				{
					facialAnim = notetrack[2];
					facialAnimLength = GetAnimLength( facialAnim );

					/#
					if ( facialAnimLength < primaryDeltaAnimLength && !IsAnimLooping( localClientNum, facialAnim ) )
					{
						//println( "Found facial anim '" + facialAnim + "' that is shorter than the fullbody anim '" + primaryDeltaAnim + "' it will be played on." );
					}
					#/

					return facialAnim;
				}
			}
		}
	}

	return undefined;
}

function private SecondaryFacialAnimationThink( localClientNum )
{
	assert( IsDefined( self.archetype ) && ( self.archetype == ARCHETYPE_HUMAN || self.archetype == ARCHETYPE_ZOMBIE ) );
	
	self endon ("entityshutdown");
	self endon ("stopFacialThread");
	
	self._currentFaceState 	= FACIAL_STATE_INACTIVE;
	
	while(1)
	{	
		if( self.archetype == ARCHETYPE_HUMAN && self clientfield::get( HUMAN_FACIAL_DIALOG_ACTIVE ) )
		{
			self._currentFaceState = FACIAL_STATE_INACTIVE;
			self ClearCurrentFacialAnim(localClientNum);
				
			wait 0.5;
			continue;
		}

		animOverride = self GetFacialAnimOverride( localClientNum );

		asmStatus = self ASMGetStatus( localClientNum );
		forceNewAnim = false;

		switch(asmStatus)
		{
		case ASM_STATE_TERMINATED:
			//ClearCurrentFacialAnim(localClientNum);
			return;
		
		case ASM_STATE_INACTIVE:
			// we're in the animscripted state -- allow facial anims
			if ( isdefined( animOverride ) )
			{
				// did we just start playing a new primary delta anim?
				scriptedAnim = self GetPrimaryDeltaAnim();
				if ( isdefined( scriptedAnim ) && ( !isdefined( self._scriptedAnim ) || self._scriptedAnim != scriptedAnim ) )
				{
					self._scriptedAnim = scriptedAnim;
					forceNewAnim = true;
				}
				if ( isdefined( animOverride ) && animOverride !== self._currentFaceAnim )
				{
					forceNewAnim = true;
				}
			}
			else
			{
				if ( self._currentFaceState !== FACIAL_STATE_DEATH )
				{
					self._currentFaceState = FACIAL_STATE_INACTIVE;
					self ClearCurrentFacialAnim(localClientNum);
				}
			
				wait 0.5;
				continue;
			}
		}
		
		closestPlayer = ArrayGetClosest( self.origin, level.localPlayers, FACIAL_SYSTEM_FADE_DIST );
		
		if( !IsDefined( closestPlayer ) )
		{
			wait 0.5;
			continue;
		}
		
		if( !self HasDObj(localClientNum) || !self HasAnimTree() )
		{
			wait 0.5;
			continue;
		}
		
		currFaceState = self._currentFaceState;
		currentASMState = self ASMGetCurrentState( localClientNum );
		if( isdefined( currentASMState ) )
		{
			currentASMState = ToLower( currentASMState );
		}

		if( self ASMIsTerminating( localClientNum ) )
		{
			nextFaceState = FACIAL_STATE_DEATH;
		}
		else if( asmStatus == ASM_STATE_INACTIVE )
		{
			nextFaceState = FACIAL_STATE_ANIMSCRIPTED;
		}
		else if( IsDefined( currentASMState ) && IsSubStr( currentASMState, "pain" ) )
		{
			nextFaceState = FACIAL_STATE_PAIN;
		}
		else if( IsDefined( currentASMState ) && IsSubStr( currentASMState, "melee" ) )
		{
			nextFaceState = FACIAL_STATE_MELEE;
		}
		else if( self ASMIsShootLayerActive( localClientNum ) )
		{
			nextFaceState = FACIAL_STATE_COMBAT_SHOOT;
		}
		else if( self ASMIsAimLayerActive( localClientNum ) )
		{
			nextFaceState = FACIAL_STATE_COMBAT_AIM;
		}
		else
		{
			nextFaceState = FACIAL_STATE_COMBAT;
		}
		
		if(	currFaceState == FACIAL_STATE_INACTIVE || currFaceState != nextFaceState || forceNewAnim )
		{
			Assert( IsDefined( level.__facialAnimationsList[self.archetype][nextFaceState] ) );
			
			clearOnCompletion = false;
			
			if( nextFaceState == FACIAL_STATE_DEATH )
			{
				//clearOnCompletion = true;
			}

			animToPlay = array::random( level.__facialAnimationsList[self.archetype][nextFaceState] );
			if ( isdefined( animOverride ) )
			{
				animToPlay = animOverride;
				assert( nextFaceState != FACIAL_STATE_DEATH || !IsAnimLooping( localClientNum, animToPlay ), "FACIAL ANIM - Death facial animation " + animToPlay + " is set to looping in the GDT. It needs to be non-looping." );
			}

			ApplyNewFaceAnim( localClientNum, animToPlay, clearOnCompletion );
			self._currentFaceState = nextFaceState;
		}
		
		if( self._currentFaceState == FACIAL_STATE_DEATH )
			break;
				
		wait 0.25;
	}
}

function private ApplyNewFaceAnim( localClientNum, animation, clearOnCompletion = false )
{
	ClearCurrentFacialAnim(localClientNum);
	
	if( IsDefined( animation ) )
	{
		self._currentFaceAnim = animation;
		
		if( self HasDObj(localClientNum) && self HasAnimTree() )
		{
			self SetFlaggedAnimKnob( "ai_secondary_facial_anim", animation, 1.0, 0.1, 1.0 );
		
			if( clearOnCompletion )
			{
				wait( GetAnimLength( animation ) );
				ClearCurrentFacialAnim(localClientNum);
			}
		}
	}
}

function private ApplyDeathAnim( localClientNum )
{
	if( IsDefined( self._currentFaceState ) && self._currentFaceState == FACIAL_STATE_DEATH )
		return;
	
	if ( GetMigrationStatus(localClientNum) ) 
		return; 
	
	if( IsDefined( self ) && 
	    IsDefined( level.__facialAnimationsList ) && 
	    IsDefined( level.__facialAnimationsList[self.archetype] ) && 
	    IsDefined( level.__facialAnimationsList[self.archetype][FACIAL_STATE_DEATH] ) )
	{
		animToPlay = array::random( level.__facialAnimationsList[self.archetype][FACIAL_STATE_DEATH] );
		animOverride = self GetFacialAnimOverride( localClientNum );
		if ( isdefined( animOverride ) )
		{
			animToPlay = animOverride;
		}

		self._currentFaceState = FACIAL_STATE_DEATH;
		ApplyNewFaceAnim( localClientNum, animToPlay );
	}
}

function private ClearCurrentFacialAnim(localClientNum)
{
	if( IsDefined( self._currentFaceAnim ) && self HasDObj(localClientNum) && self HasAnimTree() )
	{
		self ClearAnim( self._currentFaceAnim, 0.2 );
	}
	
	self._currentFaceAnim = undefined;
}
