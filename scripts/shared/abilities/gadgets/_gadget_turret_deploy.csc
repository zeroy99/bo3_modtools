#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\duplicaterender.gsh;

REGISTER_SYSTEM( "gadget_deploy_turret", &__init__, undefined )

#define TURRET_OUTLINE_MATERIAL "mc/hud_keyline_green"	
#define TURRET_OUTLINE_MATERIAL_WARN "mc/hud_keyline_red"	
	
function __init__()
{
	callback::on_localclient_connect( &on_player_connect );
	
	clientfield::register( "vehicle", "retrievable",	VERSION_SHIP, 1, "int", &field_toggle_retrievable_handler, 		!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "unplaceable",	VERSION_SHIP, 1, "int", &field_toggle_unplaceable_handler, 		!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	clientfield::register( "vehicle", "toggle_keyline",	VERSION_SHIP, 1, "int", &field_toggle_keyline_handler, 		!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "dt_damage_state",	VERSION_SHIP, 2, "int", &field_damage_state_handler, 		!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "vehicle_hack",	VERSION_SHIP, 1, "int", &field_toggle_hack_handler, 		!CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	setup_turret_damage_states();
}

function on_player_connect( localClientNum )
{
/*
// rely on the retrievable filter
	duplicate_render::set_dr_filter_offscreen( "gdtur", 25, 
	                                			"gdtur_on", "gdtur_enemy,gdtur_hack",                    
	                                			DR_TYPE_OFFSCREEN, TURRET_OUTLINE_MATERIAL, DR_CULL_ALWAYS  );
	duplicate_render::set_dr_filter_offscreen( "gdtur_hax", 24, 
	                                			"gdtur_on", undefined,                    
	                                			DR_TYPE_OFFSCREEN, TURRET_OUTLINE_MATERIAL_WARN, DR_CULL_ALWAYS  );
*/
}

function field_toggle_retrievable_handler( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IsDefined(self.owner) && self.owner == getlocalplayer( local_client_num ) )
	{
		self duplicate_render::set_item_retrievable( local_client_num, newVal );
	}
}

function field_toggle_unplaceable_handler( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	// We need a way to tell that the turret is being carried by a local player
	//if ( IsDefined(self.owner) && self.owner == getlocalplayer( local_client_num ) )
	{
		self duplicate_render::set_item_unplaceable( local_client_num, newVal );
	}
}




function field_toggle_keyline_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = getnonpredictedlocalplayer( localClientNum );
	player2 = getlocalplayer( localClientNum );

	if ( isdefined( player ) )
	{
		if ( player GetInKillcam( localClientNum ) )
		{
			return;
		}
		else if ( player util::is_player_view_linked_to_entity( localClientNum ) )
		{
			return;
		}
		else if ( player != player2 )
		{
			return;
		}
			
	}
	
	if(newVal)
	{
		self thread watch_turret_keyline(localClientNum); 
	}
	else
	{
		self notify("end_turret_keyline");
   		self duplicate_render::change_dr_flags( localClientNum, undefined, "gdtur_on" );
	}
}

function watch_turret_keyline(localClientNum)
{
	self endon("end_turret_keyline");
	player = GetLocalPlayer( localClientNum );
	if( isdefined(self.owner) && self.owner == player )
	{
		self.original_team = self.team;
		self.last_team = self.team;
		while( IsDefined(self) )
		{
			player = GetLocalPlayer( localClientNum );
			if( isdefined(self.owner) && self.owner == player )
		   		self duplicate_render::change_dr_flags( localClientNum, "gdtur_on", undefined );
			else
		   		self duplicate_render::change_dr_flags( localClientNum, undefined, "gdtur_on" );
			if (IsDefined(player))
			{
				if( isdefined(self.team) && self.team == player.team )
		   			self duplicate_render::change_dr_flags( localClientNum, undefined, "gdtur_enemy" );
				else
				{
		   			self duplicate_render::change_dr_flags( localClientNum, "gdtur_enemy", undefined );
		   			if ( self.last_team != self.team )
		   			{
						if( self.team != self.original_team )
						{
							self.owner thread turret_hacked_fully();
						}
						self.last_team = self.team;
		   			}
				}
			}
			wait 0.05;		
		}
	}
	else
	{
   		self duplicate_render::change_dr_flags( localClientNum, undefined, "gdtur_on" );
	}
}

function field_damage_state_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = getnonpredictedlocalplayer( localClientNum );
	player2 = getlocalplayer( localClientNum );

	if ( isdefined( player ) )
	{
		if ( player GetInKillcam( localClientNum ) )
		{
			return;
		}
		else if ( player util::is_player_view_linked_to_entity( localClientNum ) )
		{
			return;
		}
		else if ( player != player2 )
		{
			return;
		}
			
	}
	
	if ( !IS_EQUAL( self.dt_damage_state, newVal ) )
	{
		if ( IsDefined( self.dt_damage_state_fx ) )
		{
			StopFX( localClientNum, self.dt_damage_state_fx );
			self.dt_damage_state_fx=undefined; 
		}
		if ( IsDefined(level.deploy_turret_damage_fx[newVal] ) )
		{
			self.dt_damage_state_fx = PlayFxOnTag( localClientNum, level.deploy_turret_damage_fx[newVal], self, "tag_fx" );
		}
		//PlayFXOnTag( level._effect[ "turbine_on" ]  , self.buildableTurbine, "tag_animate");
		self.dt_damage_state = newVal;
	}
}


#precache( "client_fx", "destruct/fx_dest_turret_1" );
#precache( "client_fx", "destruct/fx_dest_turret_2" );

#define TURRET_DAMAGE_STATES 	2
#define TURRET_DAMAGE_AMT_1 	0.5
#define TURRET_DAMAGE_FX_1 		"destruct/fx_dest_turret_1"
#define TURRET_DAMAGE_AMT_2 	0.25
#define TURRET_DAMAGE_FX_2 		"destruct/fx_dest_turret_2"

function setup_turret_damage_states()
{
	level.deploy_turret_damage_states = TURRET_DAMAGE_STATES + 2; 
	level.deploy_turret_damage_amt = [];
	level.deploy_turret_damage_fx = [];
	level.deploy_turret_damage_amt[0] = 1.0;
	level.deploy_turret_damage_fx[0] = undefined;
	level.deploy_turret_damage_amt[1] = TURRET_DAMAGE_AMT_1;
	level.deploy_turret_damage_fx[1] = TURRET_DAMAGE_FX_1;
	level.deploy_turret_damage_amt[2] = TURRET_DAMAGE_AMT_2;
	level.deploy_turret_damage_fx[2] = TURRET_DAMAGE_FX_2;
	level.deploy_turret_damage_amt[3] = 0.0;
	level.deploy_turret_damage_fx[3] = undefined;
	
}

function field_toggle_hack_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if(newVal)
	{
   		self duplicate_render::change_dr_flags( localClientNum, "gdtur_hack", undefined );
	}
	else
	{
   		self duplicate_render::change_dr_flags( localClientNum, undefined, "gdtur_hack" );
	}
	
	player = getnonpredictedlocalplayer( localClientNum );
	player2 = getlocalplayer( localClientNum );

	if ( !IS_EQUAL(player,player2) )
	{
		return;
	}

	player = GetLocalPlayer( localClientNum );
	if( isdefined(self.owner) && self.owner == player )
	{
		if ( newVal )
		{
			if( self.team == self.original_team )
			{
				IPrintLnBold("TURRET HACK IN PROGRESS");
				self thread play_beeps(localClientNum);
			}
			// otherwise hacking own turret
		}
		else
		{
			self notify("stop_beeping");
		}
	}
	
}

function play_beeps(localClientNum)
{
	self endon("stop_beeping");
	while( IsDefined(self) && IsDefined(self.owner))
	{
		self.owner PlaySound( localClientNum, "wpn_semtex_alert" );
		wait 1;
	}
}

function turret_hacked_fully()
{
	IPrintLnBold("TURRET HAS BEEN HACKED");
}


