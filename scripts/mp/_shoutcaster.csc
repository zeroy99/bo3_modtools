#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#namespace shoutcaster;

#define SHOUTCASTER_SETTING_TEAM_IDENTITY "shoutcaster_team_identity"
#define SHOUTCASTER_SETTING_ALLIES_COLOR_ID "shoutcaster_fe_team1_color"
#define SHOUTCASTER_SETTING_AXIS_COLOR_ID "shoutcaster_fe_team2_color"
#define SHOUTCASTER_SETTING_FLIP_SCORE_PANEL "shoutcaster_flip_scorepanel"

function is_shoutcaster(localClientNum)
{
	return IsShoutcaster(localClientNum);
}

function is_shoutcaster_using_team_identity(localClientNum)
{
	return (is_shoutcaster(localClientNum) && GetShoutcasterSetting(localClientNum, SHOUTCASTER_SETTING_TEAM_IDENTITY ));
}

function get_team_color_id( localClientNum, team )
{
	if ( team == "allies" )
	{
		return GetShoutcasterSetting(localClientNum, SHOUTCASTER_SETTING_ALLIES_COLOR_ID );
	}
	
	return GetShoutcasterSetting(localClientNum, SHOUTCASTER_SETTING_AXIS_COLOR_ID );
}

function get_team_color_fx( localClientNum, team, script_bundle )
{
	color = get_team_color_id( localClientNum, team );
	return 	script_bundle.objects[color].fx_colorid;
}

function get_color_fx( localClientNum, script_bundle )
{
	effects = [];
	effects["allies"] = get_team_color_fx( localClientNum, "allies", script_bundle );
	effects["axis"] = get_team_color_fx( localClientNum, "axis", script_bundle );
	return 	effects;
}

function is_friendly( localClientNum )
{
	localplayer = getlocalplayer( localClientNum );
	
	scorepanel_flipped = GetShoutcasterSetting(localClientNum, SHOUTCASTER_SETTING_FLIP_SCORE_PANEL );
	
	if ( !scorepanel_flipped )
		friendly = ( self.team == "allies" );	
	else
		friendly = ( self.team == "axis" );
	
	return friendly;
}