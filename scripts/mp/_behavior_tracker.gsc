#using scripts\shared\math_shared;

#define LEARNING_RATE			0.1
#define MIN_TRAIT_VALUE 		0.0
#define MAX_TRAIT_VALUE 		1.0
#define DEFAULT_TRAIT_VALUE 	0.5

#namespace behaviorTracker;

/////////////////////////////////////////////////////
/////       Inititialize & Finaliize 			 ////
/////////////////////////////////////////////////////
function SetupTraits()
{
	if ( isDefined( self.behaviorTracker.traits ) )
		return;

	self.behaviorTracker.traits = [];
	// Define the traits with a default value. This default value will be used if we dont have stats.
	self.behaviorTracker.traits["effectiveCombat"]				= DEFAULT_TRAIT_VALUE;
	self.behaviorTracker.traits["effectiveWallRunCombat"]		= DEFAULT_TRAIT_VALUE;
	self.behaviorTracker.traits["effectiveDoubleJumpCombat"]	= DEFAULT_TRAIT_VALUE;
	self.behaviorTracker.traits["effectiveSlideCombat"]			= DEFAULT_TRAIT_VALUE;
	
	if ( self.behaviorTracker.version != 0 )
	{
		traits = getArrayKeys( self.behaviorTracker.traits );

		for ( i = 0; i < traits.size; i++ )
		{
			trait = traits[i];
			self.behaviorTracker.traits[trait] = float( self GetTraitStatValue( trait ) );
		}
	}
}

function Initialize()
{
	if ( isdefined( self.pers["isBot"] ) )
		return;

	if ( isDefined( self.behaviorTracker ) )
		return;
		
	if ( isdefined( level.disableBehaviorTracker ) && level.disableBehaviorTracker == true )
		return;
	
	self.behaviorTracker = spawnstruct();
	self.behaviorTracker.version = int( self GetTraitStatValue( "version" ) );
	self.behaviorTracker.numRecords = int( self GetTraitStatValue( "numRecords" ) ) + 1;
	self SetupTraits();

	self.behaviorTracker.valid = true;
}

function Finalize()
{
	if ( !( self IsAllowed() ) )
		return;

	self SetTraitStats();

	self PrintTrackerToBlackBox();
}

/////////////////////////////////////////////////////
/////          	  Utility Functions 		     ////
/////////////////////////////////////////////////////
function IsAllowed()
{
	if ( !isDefined( self ) )
		return false;

	if ( !isDefined( self.behaviorTracker ) )
		return false;

	if ( !self.behaviorTracker.valid )
		return false;
	
	if ( isdefined( level.disableBehaviorTracker ) && level.disableBehaviorTracker == true )
		return false;
	
	return true;
}

function PrintTrackerToBlackBox()
{

}

/////////////////////////////////////////////////////
/////          Set, Get & Update Trait 			 ////
/////////////////////////////////////////////////////
function GetTraitValue( trait )
{
	return self.behaviorTracker.traits[ trait ];
}

function SetTraitValue( trait, value )
{
	self.behaviorTracker.traits[trait] = value;
}

function UpdateTrait( trait, percent )
{
	if ( !( self IsAllowed() ) )
		return;

	math::clamp( percent, -1.0, 1.0 );
	
	currentValue = self GetTraitValue( trait );
	
	if ( percent >= 0 )
	{
		delta = ( MAX_TRAIT_VALUE - currentValue ) * percent;
	}
	else
	{
		delta = ( currentValue - MIN_TRAIT_VALUE ) * percent; 
	}

	weightedDelta = LEARNING_RATE * delta;
	
	newValue = currentvalue + weightedDelta;
	newValue = math::clamp( newValue, MIN_TRAIT_VALUE, MAX_TRAIT_VALUE );
	self SetTraitValue( trait, newValue );
}

/////////////////////////////////////////////////////
/////          		Game Side Hooks 			 ////
/////////////////////////////////////////////////////
function UpdatePlayerDamage( attacker, victim, damage )
{
	if ( isDefined( victim ) && victim IsAllowed() )
	{
		damageRatio = float( damage ) / float( victim.maxhealth );
		math::clamp( damageRatio, 0.0, 1.0 );
		
		damageRatio = damageRatio * -1.0; // Negative damage percent since this is the victim
		
		victim UpdateTrait( "effectiveCombat", damageRatio );
		
		if ( victim IsWallRunning() )
		{
			victim UpdateTrait( "effectiveWallRunCombat", damageRatio );
		}

		if ( victim IsSliding() )
		{
			victim UpdateTrait( "effectiveSlideCombat", damageRatio );
		}

		if ( victim IsDoubleJumping() )
		{
			victim UpdateTrait( "effectiveDoubleJumpCombat", damageRatio );
		}
	}
	
	if ( isDefined( attacker ) && ( attacker IsAllowed() ) && attacker != victim )
	{
		damageRatio = float( damage ) / float( attacker.maxhealth );
		math::clamp( damageRatio, 0.0, 1.0 );
		
		attacker UpdateTrait( "effectiveCombat", damageRatio );
		
		if ( attacker IsWallRunning() )
		{
			attacker UpdateTrait( "effectiveWallRunCombat", damageRatio );
		}

		if ( attacker IsSliding() )
		{
			attacker UpdateTrait( "effectiveSlideCombat", damageRatio );
		}

		if ( attacker IsDoubleJumping() )
		{
			attacker UpdateTrait( "effectiveDoubleJumpCombat", damageRatio );
		}
	}
}

function UpdatePlayerKilled( attacker, victim )
{
	if ( isDefined( victim ) && victim IsAllowed() )
	{
		// Passing -1.0 since to denote negative 100%.
		victim UpdateTrait( "effectiveCombat", -1.0 );
		
		if ( victim IsWallRunning() )
		{
			victim UpdateTrait( "effectiveWallRunCombat", -1.0 );
		}

		if ( victim IsSliding() )
		{
			victim UpdateTrait( "effectiveSlideCombat", -1.0 );
		}

		if ( victim IsDoubleJumping() )
		{
			victim UpdateTrait( "effectiveDoubleJumpCombat", -1.0 );
		}
	}
		
	if ( isDefined( attacker ) && ( attacker IsAllowed() ) && attacker != victim )
	{
		// Passing 1.0 since to denote positive 100%.
		attacker UpdateTrait( "effectiveCombat", 1.0 );
		
		if ( attacker IsWallRunning() )
		{
			attacker UpdateTrait( "effectiveWallRunCombat", 1.0 );
		}

		if ( attacker IsSliding() )
		{
			attacker UpdateTrait( "effectiveSlideCombat", 1.0 );
		}

		if ( attacker IsDoubleJumping() )
		{
			attacker UpdateTrait( "effectiveDoubleJumpCombat", 1.0 );
		}
	}
}


/////////////////////////////////////////////////////
/////          		Stats Related 				 ////
/////////////////////////////////////////////////////
 function SetTraitStats()
 {
	if ( self.behaviorTracker.version == 0 )
		return;
	
	self.behaviorTracker.numRecords = self.behaviorTracker.numRecords + 1;
 	self SetTraitStatValue( "numRecords", self.behaviorTracker.numRecords );
 	
	traits = getArrayKeys( self.behaviorTracker.traits );

	for ( i = 0; i < traits.size; i++ )
	{
		trait = traits[i];
		value = self.behaviorTracker.traits[trait];

		self SetTraitStatValue( trait, value );
	}
 }
 
function GetTraitStatValue( trait )
{
	return self getDStat( "behaviorTracker", trait );
}

function SetTraitStatValue( trait, value )
{
	self setDStat( "behaviorTracker", trait, value );
}