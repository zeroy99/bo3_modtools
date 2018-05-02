#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\hackable;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

REGISTER_SYSTEM( "gadget_hacker", &__init__, undefined )

#define HACKER_OUTLINE_MATERIAL "mc/hud_outline_model_orange"	
	
function __init__()
{
//TODO:  ONCONNECT CANNOT USE THE ENTITY _ if this code every comes back (it's all commented out righ tnow - then you will need to deal with this::   	callback::on_localclient_connect( &on_player_connect );
	callback::on_spawned( &on_player_spawned );
	clientfield::register( "toplayer", "hacker_on", VERSION_SHIP, 1, "int", &has_hacker_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "hacker_active", VERSION_SHIP, 1, "int", &has_hacking_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );


}

function on_player_connect( localClientNum )
{
	if ( !IsDefined( self.hacker_sound_ent ) )
	{
		self.hacker_sound_ent = spawn( localClientNum, self.origin, "script_origin" );
		self.hacker_sound_ent linkto( self, "tag_origin" );
	}

}

function on_player_spawned( localClientNum )
{
	self notify("stop_hacking_sounds");
}

function has_hacker_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self._gadget_has_hacker = newVal;
	if ( newVal )
	{
		self thread watch_hack_ents(localClientNum);
	}
	else
	{
		self notify("watch_hack_ents");
		hackable::set_hacked_ent( localClientNum, undefined );
	}
	
}

function watch_hack_ents(localClientNum)
{
	self notify("watch_hack_ents");
	self endon("watch_hack_ents");
	self endon("death");
	
	while( IsDefined(self) && self._gadget_has_hacker )
	{
		targetArray = self GetTargetLockEntity(localClientNum); 
		if (targetArray.size>0)
		{
			hackable::set_hacked_ent( localClientNum, targetArray[0] );
		}
		WAIT_CLIENT_FRAME;
	}
	
	
}

function has_hacking_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self._gadget_is_hacking = newVal;
	if ( newVal != oldVal )
	{
		if ( newVal )
		{
	//		self thread play_hacking_sounds(localClientNum);
		}
		else
		{
	//		self notify("stop_hacking_sounds");
		}
	}
	
}

function play_hacking_sounds( localClientNum )
{
	self endon("death");
	self endon("disconnect");
	
	// SOUND CALLS TO BE MOVED TO GDT FIELDS
	//self PlaySound ( localClientNum, "gdt_hacker_on" );
	//PlayLoopSound( localClientNum, self.hacker_sound_ent, "gdt_hacker_loop", 0.5 );
	//self.hacker_sound_ent playloopsound( "gdt_hacker_loop", 0.5 );

	
	self waittill("stop_hacking_sounds");
	//self.hacker_sound_ent StopAllLoopSounds( 0.5 );
	//StopAllLoopSounds( localClientNum, self.hacker_sound_ent, 0.1 );
	//self PlaySound ( localClientNum, "gdt_hacker_off" );
}
