#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;

#namespace hackable;

REGISTER_SYSTEM( "hackable", &init, undefined )

#define HACKER_OUTLINE_MATERIAL "mc/hud_keyline_orange"	
	
function init()
{
	callback::on_localclient_connect( &on_player_connect );
	
}

function on_player_connect( localClientNum )
{
	duplicate_render::set_dr_filter_offscreen( "hacking", 75, 
	                                "being_hacked",                        undefined,                    
	                                DR_TYPE_OFFSCREEN, HACKER_OUTLINE_MATERIAL, DR_CULL_NEVER  );
}



// called on a player to show what's being hacked

function set_hacked_ent( local_client_num, ent )
{
	if ( !IS_EQUAL(ent,self.hacked_ent) )
	{
		if ( IsDefined(self.hacked_ent) )
		{
		   	self.hacked_ent duplicate_render::change_dr_flags( local_client_num, undefined, "being_hacked" );
		}
		self.hacked_ent=ent;
		if ( IsDefined(self.hacked_ent) )
		{
		   	self.hacked_ent duplicate_render::change_dr_flags( local_client_num, "being_hacked", undefined );
		}
	}
}



