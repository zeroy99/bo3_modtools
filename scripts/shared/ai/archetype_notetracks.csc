#using scripts\shared\ai_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace Notetracks;

function autoexec main()
{
	if ( SessionModeIsZombiesGame() && GetDvarInt( "splitscreen_playerCount" ) > 2 )
		return; 
		
	if ( SessionModeIsCampaignDeadOpsGame() && GetDvarInt( "splitscreen_playerCount" ) > 2 )
		return; 
	
	ai::add_ai_spawn_function( &InitializeNotetrackHandlers );
}

function private InitializeNotetrackHandlers( localClientNum )
{
	// AI Footsteps defined by the surfacefxtable_footstep table are handled in code.
	AddSurfaceNotetrackFXHandler( localClientNum, "jumping", "surfacefxtable_jumping" );
	AddSurfaceNotetrackFXHandler( localClientNum, "landing", "surfacefxtable_landing" );
	AddSurfaceNotetrackFXHandler( localClientNum, "vtol_landing", "surfacefxtable_vtollanding" );
}

function private AddSurfaceNotetrackFXHandler( localClientNum, notetrack, surfaceTable )
{
	entity = self;
	
	entity thread HandleSurfaceNotetrackFX( localClientNum, notetrack, surfaceTable );
}

function private HandleSurfaceNotetrackFX( localClientNum, notetrack, surfaceTable )
{
	entity = self;
	
	entity endon( "entityshutdown" );
	
	while ( true )
	{
		entity waittill( notetrack );
		
		fxName = entity GetAIFxName( localClientNum, surfaceTable );
		
		if ( IsDefined( fxName ) )
		{
			PlayFx( localClientNum, fxName, entity.origin );
		}
	}
}
