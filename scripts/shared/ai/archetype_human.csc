#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;
#using scripts\shared\ai\systems\fx_character;
#using scripts\shared\ai\systems\gib;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using_animtree("generic");

function autoexec precache()
{
	
}

function autoexec main()
{
	clientfield::register(
		"actor",
		HUMAN_FACIAL_DIALOG_ACTIVE,
		VERSION_SHIP,
		1,
		"int",
		&HumanClientUtils::facialDialogueHandler,
		!CF_HOST_ONLY,
		CF_CALLBACK_ZERO_ON_NEW_ENT );
}

#namespace HumanClientUtils;

function facialDialogueHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump )
{
	if( newvalue )
	{
		self.facialDialogueActive = true;
	}
	else
	{
		if( IS_TRUE(self.facialDialogueActive) )
		{
			self ClearAnim( %faces, 0 );
		}
	}
}
