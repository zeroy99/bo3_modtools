#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\weapons\_flashgrenades;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define HACKING_PLAYER_WEAPON "pda_hack"
#define HACKER_MAX_RANGE 40
#define HACKER_SWEET_SPOT_RATIO 0.8

#namespace hacker_tool;

function init_shared()
{	
	clientfield::register( "toplayer", "hacker_tool", VERSION_SHIP, 2, "int", &player_hacking, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	level.hackingSoundId = [];
	level.hackingSweetSpotId = [];
	level.friendlyHackingSoundId = [];
	callback::on_localplayer_spawned( &on_localplayer_spawned );
}

function on_localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	player = self;

	if ( isdefined( level.hackingSoundId[localclientnum] ) )
	{
		player stopLoopSound( level.hackingSoundId[localclientnum] );
		level.hackingSoundId[localclientnum] = undefined;
	}
	if ( isdefined( level.hackingSweetSpotId[localclientnum] ) )
	{
		player stopLoopSound(level.hackingSweetSpotId[localclientnum] );
		level.hackingSweetSpotId[localclientnum] = undefined;
	}
	if ( isdefined( level.friendlyHackingSoundId[localclientnum] ) )
	{
		player stopLoopSound( level.friendlyHackingSoundId[localclientnum] );
		level.friendlyHackingSoundId[localclientnum] = undefined;
	}
}


function player_hacking( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self notify( "player_hacking_callback" );
	player = self;
	if ( isdefined( level.hackingSoundId[localclientnum] ) )
	{
		player stopLoopSound( level.hackingSoundId[localclientnum] );
		level.hackingSoundId[localclientnum] = undefined;
	}
	if ( isdefined( level.hackingSweetSpotId[localclientnum] ) )
	{
		player stopLoopSound(level.hackingSweetSpotId[localclientnum] );
		level.hackingSweetSpotId[localclientnum] = undefined;
	}
	if ( isdefined( level.friendlyHackingSoundId[localclientnum] ) )
	{
		player stopLoopSound( level.friendlyHackingSoundId[localclientnum] );
		level.friendlyHackingSoundId[localclientnum] = undefined;
	}
	if ( isdefined( player.targetEnt ) )
	{
		player.targetEnt duplicate_render::set_hacker_tool_hacking( localClientNum, false );
		player.targetEnt duplicate_render::set_hacker_tool_breaching( localClientNum,false );
		player.targetEnt.isbreachingfirewall = false;
		player.targetEnt = undefined;
	}

	if ( newVal == HACKER_TOOL_HACKING )
	{
		player thread watchHackSpeed( localClientNum, false );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_HACKING );
	}
	else if ( newVal == HACKER_TOOL_FIREWALL )
	{
		player thread watchHackSpeed( localClientNum, true );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_BREACHING );
	}
	else if ( newVal == HACKER_TOOL_ACTIVE )
	{	
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_SCANNING );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.perc" ), 0 );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.offsetShaderValue" ), 0  + " " + 0 + " 0 0" );	
		self thread watchForEMP( localClientNum );
	}
	else
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_SCANNING );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.perc" ), 0 );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.offsetShaderValue" ), 0  + " " + 0 + " 0 0" );
	}
}


function watchHackSpeed( localClientNum, isBreachingFirewall )
{
	self endon( "entityshutdown" );
	self endon( "player_hacking_callback" );
	player = self;

	for ( ;; )
	{
		targetEntArray = self GetTargetLockEntityArray(); 
		if ( targetEntArray.size > 0 )
		{
			targetEnt = targetEntArray[0];
			break;
		}
		wait ( 0.02 );
	}
	targetEnt watchTargetHack( localclientNum, player, isBreachingFirewall );
}

function watchTargetHack( localclientnum, player, isBreachingFirewall )
{
	self endon( "entityshutdown" );
	player endon( "entityshutdown" );
	self endon( "player_hacking_callback" );
	
	targetEnt = self;
	player.targetEnt = targetEnt;
	if ( isBreachingFirewall )
	{
		targetEnt.isbreachingfirewall = true;
		targetEnt duplicate_render::set_hacker_tool_breaching( localclientnum, true );
	}

	targetEnt thread watchHackerPlayerShutdown( localclientnum, player, targetEnt );
	
	for( ;; )
	{
		distanceFromCenter = targetent getDistanceFromScreenCenter( localClientNum );
		inverse = HACKER_MAX_RANGE - distancefromcenter;
		ratio = inverse / HACKER_MAX_RANGE;
		heatVal = GetWeaponHackRatio( localclientnum );
		ratio = ratio * ratio * ratio * ratio;
		if ( ratio > 1.0 || ratio < 0.001 ) 
		{
			ratio = 0;
			horizontal = 0;
		}
		else
		{
			horizontal = targetent getHorizontalOffsetFromScreenCenter( localClientNum, HACKER_MAX_RANGE );
		}

		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.offsetShaderValue" ), horizontal + " " + ratio + " 0 0" );
		
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.perc" ), heatVal );
		
		if ( ratio > HACKER_SWEET_SPOT_RATIO )
		{
			if ( !isdefined( level.hackingSweetSpotId[localclientnum] ) ) 
			{
				level.hackingSweetSpotId[localclientnum] = player playloopsound( "evt_hacker_hacking_sweet" );
			}
		}
		else
		{
			if ( isdefined( level.hackingSweetSpotId[localclientnum] ) ) 
			{
				player stopLoopSound( level.hackingSweetSpotId[localclientnum] );
				level.hackingSweetSpotId[localclientnum] = undefined;
			}
			if ( !isdefined( level.hackingSoundId[localclientnum] ) )
			{
				level.hackingSoundId[localclientnum] = player playloopsound( "evt_hacker_hacking_loop" );
			}
			if ( isdefined( level.hackingSoundId[localclientnum] ) )
			{
				setSoundPitch( level.hackingSoundId[localclientnum], ratio );
			}
		}

		if ( !isBreachingFirewall )
		{
			friendlyHacking = WeaponFriendlyHacking( localclientnum );
			
			if ( friendlyHacking && !isdefined( level.friendlyHackingSoundId[localclientnum] ) )
			{
				level.friendlyHackingSoundId[localclientnum] = player playloopsound( "evt_hacker_hacking_loop_mult" );
			}
			else if ( !friendlyHacking && isdefined( level.friendlyHackingSoundId[localclientnum] ) )
			{
				player stopLoopSound( level.friendlyHackingSoundId[localclientnum] );
				level.friendlyHackingSoundId[localclientnum] = undefined;
			}
		}
		
		wait ( 0.1 );
	}
}

function watchHackerPlayerShutdown( localClientNum, hackerPlayer, targetEnt )
{
	self endon( "entityshutdown" );
	killstreakEntity = self;
	hackerPlayer endon( "player_hacking_callback" );
		
	hackerPlayer waittill( "entityshutdown" );
	
	if ( isdefined( targetEnt ) )
	{
		targetEnt.isbreachingfirewall = true;
	}
	killstreakEntity duplicate_render::set_hacker_tool_hacking( localClientNum, false );
	killstreakEntity duplicate_render::set_hacker_tool_breaching( localClientNum, false );
}


function watchForEMP( localClientNum )
{
	self endon( "entityshutdown" );
	self endon( "player_hacking_callback" );
	
	while ( 1 ) 
	{
		if ( self IsEMPJammed() )
		{
			SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_EMPED );
		}
		else 
		{
			SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "hudItems.blackhat.status" ), HACKER_TOOL_STATUS_SCANNING );
		}
		wait( 0.1 );
	}
	
}
