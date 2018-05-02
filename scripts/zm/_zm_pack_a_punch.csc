#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\exploder_shared;

#using scripts\zm\_filter;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perks.gsh;

#precache( "client_fx", "dlc1/castle/fx_packapunch_castle" );

REGISTER_SYSTEM( "zm_pack_a_punch", &__init__, undefined )

function __init__()
{
	level._effect["pap_working_fx"]	= "dlc1/castle/fx_packapunch_castle"; 	
	
	clientfield::register( "zbarrier",	 	"pap_working_FX", 		VERSION_DLC1, 1, "int", &pap_working_FX_handler, 				!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function pap_working_FX_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump ) // self = z_barrier
{

	//send piece index and get it in function
	if ( newVal == 1 )
	{
		pap_play_fx(localClientNum, 0, "base_jnt" );
	}

	else 
	{
		if ( isdefined( self.n_pap_fx ) )
		{
			StopFx( localClientNum, self.n_pap_fx );
			self.n_pap_fx = undefined;
		}
		
		wait 1; // wait long enough for fx to clear

		if ( isdefined( self.mdl_fx ) )
		{
			self.mdl_fx Delete();
		}
	}
}

function private pap_play_fx( localClientNum, n_piece_index, str_tag ) // self = z_barrier
{
	mdl_piece = self ZBarrierGetPiece( n_piece_index );

	if ( isdefined( self.mdl_fx ) )
	{
		self.mdl_fx Delete();
	}
	
	if ( isdefined( self.n_pap_fx ) )
	{
		DeleteFX( localClientNum, self.n_pap_fx );
		self.n_pap_fx = undefined;
	}

	self.mdl_fx = util::spawn_model(localClientNum, "tag_origin", mdl_piece GetTagOrigin( str_tag ), mdl_piece GetTagAngles( str_tag ) );
	self.mdl_fx LinkTo( mdl_piece, str_tag );

	self.n_pap_fx = PlayFXOnTag( localClientNum, level._effect["pap_working_fx"], self.mdl_fx, "tag_origin" );
}

