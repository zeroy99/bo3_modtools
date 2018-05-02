#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\postfx_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;
#using scripts\shared\water_surface;

#using scripts\mp\_load;
#using scripts\mp\_util;

#insert scripts\shared\shared.gsh;

#namespace waterfall;

function waterfallOverlay( localClientNum )
{
	triggers = GetEntArray( localClientNum, "waterfall", "targetname" );
	foreach( trigger in triggers )
	{
		trigger thread setupWaterfall( localClientNum );
	}
}

function waterfallMistOverlay( localClientNum )
{
	triggers = GetEntArray( localClientNum, "waterfall_mist", "targetname" );
	foreach( trigger in triggers )
	{
		trigger thread setupWaterfallMist( localClientNum );
	}
}

function waterfallMistOverlayReset( localClientNum )
{
	localPlayer = GetLocalPlayer( localClientNum );
	localPlayer.rainOpacity = 0.0;
}

function setupWaterfallMist( localClientNum )
{
	level notify( "setupWaterfallmist_waterfall_csc" + localclientnum );
	level endon ( "setupWaterfallmist_waterfall_csc" + localclientnum  );
	
	trigger = self;
	for(;;)
	{
		trigger waittill( "trigger", trigPlayer );
		
		if ( !trigPlayer islocalplayer() )
		{
			continue;
		}

		localclientnum = trigPlayer getlocalclientnumber();
		if ( isdefined( localclientnum ) )
		{
			localplayer = getlocalplayer( localclientnum );
		}
		else
		{
			localplayer = trigPlayer;
		}
		
		filter::init_filter_sprite_rain( localplayer );
		trigger thread trigger::function_thread( localplayer, &trig_enter_waterfall_mist, &trig_leave_waterfall_mist );
	}
}

function setupWaterfall( localClientNum, localowner )
{
	level notify( "setupWaterfall_waterfall_csc" + localclientnum  );
	level endon ( "setupWaterfall_waterfall_csc" + localclientnum  );

	trigger = self;
	for(;;)
	{
		trigger waittill( "trigger", trigPlayer );
		
		if ( !trigPlayer islocalplayer() )
		{
			continue;
		}
		
		localclientnum = trigPlayer getlocalclientnumber();
		if ( isdefined( localclientnum ) )
		{
			localplayer = getlocalplayer( localclientnum );
		}
		else
		{
			localplayer = trigPlayer;
		}

		trigger thread trigger::function_thread( localplayer, &trig_enter_waterfall, &trig_leave_waterfall );
	}
}

function trig_enter_waterfall( localplayer )
{
	trigger = self;
	localclientnum = localplayer.localclientnum;
	localplayer thread postfx::playPostfxBundle( "pstfx_waterfall" );

	playsound(0, "amb_waterfall_hit", (0,0,0));
			
	while ( trigger istouching( localplayer ) )
	{
		localplayer PlayRumbleOnEntity( localClientNum, "waterfall_rumble" );
		wait( 0.1 );
	}
}

function trig_leave_waterfall( localplayer )
{
	trigger = self;
	localClientNum = localplayer.localClientNum;
	localplayer postfx::StopPostfxBundle();
	if ( IsUnderwater( localClientNum ) == false )
	{
		localplayer thread water_surface::startWaterSheeting();
	}
}

function trig_enter_waterfall_mist( localPlayer )
{
	localPlayer endon( "entityshutdown" );
	trigger = self;
	
	if ( !isdefined( localPlayer.rainOpacity ) )
		localPlayer.rainOpacity = 0;
	
	if ( localPlayer.rainOpacity == 0 )
	{
		filter::set_filter_sprite_rain_seed_offset( localPlayer, FILTER_INDEX_WATER_MIST, RandomFloat( 1 ) );
	}

	filter::enable_filter_sprite_rain( localPlayer, FILTER_INDEX_WATER_MIST );
	while ( trigger istouching( localPlayer ) )
	{
		localClientNum = trigger.localClientNum;
		if ( !isdefined( localClientNum ) )
		{
			localClientNum = localPlayer getlocalclientnumber();
		}
		if ( IsUnderwater( localClientNum ) )
		{
			filter::disable_filter_sprite_rain( localPlayer, FILTER_INDEX_WATER_MIST );
			break;
		}
		
		localPlayer.rainOpacity += 0.003;
		if ( localPlayer.rainOpacity > 1 )
		{
			localPlayer.rainOpacity = 1;
		}
		filter::set_filter_sprite_rain_opacity( localPlayer, FILTER_INDEX_WATER_MIST, localPlayer.rainOpacity );
		filter::set_filter_sprite_rain_elapsed( localPlayer, FILTER_INDEX_WATER_MIST, localPlayer getClientTime() );
		
		WAIT_CLIENT_FRAME;
	}
	
}

function trig_leave_waterfall_mist( localPlayer )
{	
	localPlayer endon( "entityshutdown" );
	trigger = self;
	
	if ( isdefined( localPlayer.rainOpacity ) )
	{
		while ( !( trigger istouching( localPlayer ) ) && localPlayer.rainOpacity > 0.0 )
		{
			localClientNum = trigger.localClientNum;
			if ( IsUnderwater( localClientNum ) )
			{
				filter::disable_filter_sprite_rain( localPlayer, FILTER_INDEX_WATER_MIST );
				break;
			}
			
			localPlayer.rainOpacity -= 0.005;
			filter::set_filter_sprite_rain_opacity( localPlayer, FILTER_INDEX_WATER_MIST, localPlayer.rainOpacity );
			filter::set_filter_sprite_rain_elapsed( localPlayer, FILTER_INDEX_WATER_MIST, localPlayer getClientTime() );
			WAIT_CLIENT_FRAME;
		}
	}
	
	localPlayer.rainOpacity = 0;
	filter::disable_filter_sprite_rain( localPlayer, FILTER_INDEX_WATER_MIST );
}
