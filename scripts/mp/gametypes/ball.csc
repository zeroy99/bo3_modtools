#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;

#using scripts\mp\_shoutcaster;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define GOAL_FX										"ui/fx_uplink_goal_marker"
#define GOAL_SCORE_FX							"ui/fx_uplink_goal_marker_flash"

#precache( "client_fx", GOAL_FX );
#precache( "client_fx", GOAL_SCORE_FX );

function main()
{	
	clientfield::register( "allplayers", "ballcarrier", VERSION_SHIP, 1, "int", &player_ballcarrier_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", "passoption", VERSION_SHIP, 1, "int", &player_passoption_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "ball_away" , VERSION_SHIP, 1, "int",  &world_ball_away_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "ball_score_allies" , VERSION_SHIP, 1, "int",  &world_ball_score_allies, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "ball_score_axis" , VERSION_SHIP, 1, "int",  &world_ball_score_axis, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	callback::on_localclient_connect( &on_localclient_connect );
	callback::on_spawned( &on_player_spawned );
	
	level.effect_scriptbundles = [];
	level.effect_scriptbundles["goal"] = struct::get_script_bundle( "teamcolorfx", "teamcolorfx_uplink_goal" );
	level.effect_scriptbundles["goal_score"] = struct::get_script_bundle( "teamcolorfx", "teamcolorfx_uplink_goal_score" );
}

function on_localclient_connect( localClientNum )
{	
	objective_ids = [];

	while ( !isdefined( objective_ids["allies"] ) )
	{
		objective_ids["allies"] = ServerObjective_GetObjective( localClientNum, "ball_goal_allies" );
		objective_ids["axis"] = ServerObjective_GetObjective( localClientNum, "ball_goal_axis" );
		wait(0.05);
	}
	
	foreach( key, objective in objective_ids )
	{
		level.goals[key] = SpawnStruct();
		level.goals[key].objectiveId = objective;
		setup_goal( localClientNum, level.goals[key] );
	}
	
	setup_fx( localClientNum );
}

function on_player_spawned( localClientNum )
{
	players = GetPlayers( localclientnum );
	foreach( player in players )
	{
		if( player util::IsEnemyPlayer( self ) )
		{
			player duplicate_render::update_dr_flag( localClientNum, "ballcarrier", 0 );
		}
	}
}

function setup_goal( localClientNum, goal )
{
	goal.origin = ServerObjective_GetObjectiveOrigin( localClientNum, goal.objectiveId );
	goal_entity = ServerObjective_GetObjectiveEntity( localClientNum, goal.objectiveId );
	
	if ( isdefined(goal_entity) )
	{
		goal.origin = goal_entity.origin;
	}
	
	goal.team = ServerObjective_GetObjectiveTeam( localClientNum, goal.objectiveId );
}

function setup_goal_fx( localClientNum, goal, effects )
{
	if ( isdefined( goal.base_fx ) )
	{
		StopFx( localClientNum,	goal.base_fx );
	}
	
	goal.base_fx = PlayFx(localClientNum, effects[goal.team], goal.origin );
	SetFxTeam( localClientNum, goal.base_fx, goal.team );
}

function setup_fx( localClientNum )
{
	effects = [];
	
	if ( shoutcaster::is_shoutcaster_using_team_identity(localClientNum) )
	{
		effects = shoutcaster::get_color_fx( localClientNum, level.effect_scriptbundles["goal"] );
	}
	else
	{
		effects["allies"] = GOAL_FX;
		effects["axis"] = GOAL_FX;
	}
	
	foreach( goal in level.goals)
	{
		thread setup_goal_fx(localClientNum, goal, effects );
		thread resetOnDemoJump( localClientNum, goal, effects );
	}
	
	thread watch_for_team_change( localClientNum );
}

function play_score_fx( localClientNum, goal)
{
	effects = [];
	
	if ( shoutcaster::is_shoutcaster_using_team_identity(localClientNum) )
	{
		effects = shoutcaster::get_color_fx( localClientNum, level.effect_scriptbundles["goal_score"] );
	}
	else
	{
		effects["allies"] = GOAL_SCORE_FX;
		effects["axis"] = GOAL_SCORE_FX;
	}

	fx_handle = PlayFx(localClientNum, effects[goal.team], goal.origin );
	SetFxTeam( localClientNum, fx_handle, goal.team );
}

function play_goal_score_fx( localClientNum, team, oldVal, newVal, bInitialSnap, bWasTimeJump )
{
	if( ( newVal != oldVal ) && !bInitialSnap && !bWasTimeJump )
	{
		play_score_fx( localClientNum, level.goals[team] );
	}
}

function world_ball_score_allies( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	play_goal_score_fx( localClientNum, "allies", oldVal, newVal, bInitialSnap, bWasTimeJump );
}

function world_ball_score_axis( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	play_goal_score_fx( localClientNum, "axis", oldVal, newVal, bInitialSnap, bWasTimeJump );
}

function player_ballcarrier_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	localplayer = getlocalplayer( localClientNum );
	
	if( localplayer == self )
	{
		if( newVal )
		{
			self._hasBall = true;
		}
		else
		{
			self._hasBall = false;
			SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.passOption" ), 0 );
		}
	}
	
	if( ( localplayer != self ) && self isFriendly( localClientNum ) )
	{
		self set_player_ball_carrier_dr( localClientNum, newVal );
	}
	else
	{	
		self set_player_ball_carrier_dr( localClientNum, false );
	}
}

function set_hud( localClientNum )
{
	level.ball_carrier = self;
	
	if ( shoutcaster::is_shoutcaster( localClientNum ) )
	{
		friendly = self shoutcaster::is_friendly( localclientnum );
	}
	else
	{
		friendly = self isFriendly( localClientNum );
	}
	
	if( isdefined( self.name ) )		
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballStatusText" ),  self.name );	
	else 
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballStatusText" ),  "" );	
	
	if( isdefined( friendly ) )
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByFriendly" ), friendly );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByEnemy" ), !friendly );
	}
	else
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByFriendly" ), 0 );
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByEnemy" ), 0 );
	}
}

function clear_hud( localClientNum )
{
	level.ball_carrier = undefined;

	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByEnemy" ), 0 );
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballHeldByFriendly" ), 0 );
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballStatusText" ),  &"MPUI_BALL_AWAY" );
}

function player_passoption_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	localplayer = getlocalplayer( localClientNum );
	
	if( ( localplayer != self ) && self isFriendly( localClientNum ) )
	{
		if( IS_TRUE( localplayer._hasBall ) )
		{
			SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.passOption" ), newVal );
		}
	}
}

function world_ball_away_changed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "ballGametype.ballAway" ), newVal );
}

function set_player_ball_carrier_dr( localClientNum, on_off )
{
	self duplicate_render::update_dr_flag( localClientNum, "ballcarrier", on_off );
}

function set_player_pass_option_dr( localClientNum, on_off )
{
	self duplicate_render::update_dr_flag( localClientNum, "passoption", on_off );
}

function resetOnDemoJump( localClientNum, goal, effects )
{
	for (;;)
	{
		level waittill( "demo_jump" + localClientNum ); 
		
		setup_goal_fx( localClientNum, goal, effects );
	}
}

function watch_for_team_change( localClientNum )
{
	level notify( "end_team_change_watch" );
	level endon( "end_team_change_watch" );

	level waittill( "team_changed" );
	
	thread setup_fx( localClientNum );
}