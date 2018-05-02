#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;

#using scripts\mp\_shoutcaster;

#insert scripts\shared\ai\archetype_robot.gsh;
#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#define ROBOT_STATE_IDLE 0
#define ROBOT_STATE_MOVING 1
#define ROBOT_STATE_SHUTDOWN 2
	
#define ROBOT_BURN_TAGFXSET			"escort_robot_burn"
	
#precache( "client_tagfxset", ROBOT_BURN_TAGFXSET );

function main()
{	
	clientfield::register( "actor", "robot_state" , VERSION_SHIP, 2, "int",  &robot_state_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "escort_robot_burn" , VERSION_SHIP, 1, "int",  &robot_burn, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	callback::on_localclient_connect( &on_localclient_connect );
}

function on_localclient_connect( localClientNum )
{
	// Initialize the ui model values
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.robotStatusText" ), &"MPUI_ESCORT_ROBOT_MOVING" );
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.robotStatusVisible" ), 0 );
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.enemyRobot" ), 0 );
	
	level wait_team_changed( localClientNum );
}

// Clientfield Callbacks
//========================================

function robot_burn( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal )
	{
		self endon( "entityshutdown" );
		self util::waittill_dobj( localClientNum );    

		fxHandles = PlayTagFXSet( localClientNum, ROBOT_BURN_TAGFXSET, self );
		self thread watch_fx_shutdown( localClientNum, fxHandles );
	}
}

function watch_fx_shutdown( localClientNum, fxHandles )
{
	wait( 3 );
	
	foreach( fx in fxHandles )
	{
		StopFX( localclientnum, fx );
	}
}

function robot_state_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( bNewEnt )
	{
		ARRAY_ADD( level.escortRobots, self );
		
		self thread update_robot_team( localClientNum );
	}
	
	if ( newVal == ROBOT_STATE_MOVING )
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.robotStatusVisible" ), 1 );
	}
	else
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.robotStatusVisible" ), 0 );
	}
}


// HUD Updates
//========================================

function wait_team_changed( localClientNum )
{
	while( 1 )
	{
		level waittill( "team_changed" );
		
		// the local player might not be valid yet and will cause the team detection functionality not to work
		while ( !isdefined(	GetNonPredictedLocalPlayer( localClientNum ) ) )
		{
			wait( SERVER_FRAME );
		}
	
		if ( !isdefined( level.escortRobots ) )
		{
			continue;
		}
		
		foreach ( robot in level.escortRobots )
		{
			robot thread update_robot_team( localClientNum );
		}
	}
}

function update_robot_team( localClientNum )
{
	localPlayerTeam = GetLocalPlayerTeam( localClientNum );
	
	if ( shoutcaster::is_shoutcaster( localClientNum ) )
	{
		friend = self shoutcaster::is_friendly( localclientnum );
	}
	else
	{
		friend = self.team == localPlayerTeam;
	}
	
	if ( friend )
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.enemyRobot" ), 0 );	
	}
	else
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "escortGametype.enemyRobot" ), 1 );	
	}
	
	// Update the robot friend/enemy material
	self duplicate_render::set_dr_flag( "enemyvehicle_fb", !friend );
	
	localPlayer = GetLocalPlayer( localClientNum );
	localPlayer duplicate_render::update_dr_filters(localClientNum);
}