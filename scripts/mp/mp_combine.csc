#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_load;
#using scripts\mp\_util;

#using scripts\mp\mp_combine_fx;
#using scripts\mp\mp_combine_sound;

#precache( "client_fx", "ui/fx_dom_cap_indicator_neutral_r120" );
#precache( "client_fx", "ui/fx_dom_cap_indicator_team_r120" );
#precache( "client_fx", "ui/fx_dom_marker_neutral_r120" );
#precache( "client_fx", "ui/fx_dom_marker_team_r120" );
#precache( "client_fx", "ui/fx_dom_cap_indicator_neutral_r90" );
#precache( "client_fx", "ui/fx_dom_cap_indicator_team_r90" );
#precache( "client_fx", "ui/fx_dom_marker_neutral_r90" );
#precache( "client_fx", "ui/fx_dom_marker_team_r90" );

function main()
{
	// The meshes for the clock hands was authored in the wrong order, this renames them.
	{
		hour_hand =   GetEntArray(0, "hour_hand", "targetname");
		minute_hand = GetEntArray(0, "minute_hand", "targetname");
		second_hand = GetEntArray(0, "second_hand", "targetname");
		foreach(hand in hour_hand)
		{
			hand.targetname = "second_hand";
		}
		foreach(hand in minute_hand)
		{
			hand.targetname = "hour_hand";
		}
		foreach(hand in second_hand)
		{
			hand.targetname = "minute_hand";
		}
	}

	mp_combine_fx::main();
	mp_combine_sound::main();
	level.disableFXAnimInSplitscreenCount = 3;
	load::main();
	
	level.domFlagBaseFxOverride = &dom_flag_base_fx_override;
	level.domFlagCapFxOverride = &dom_flag_cap_fx_override;

	util::waitforclient( 0 );	// This needs to be called after all systems have been registered.

	level.endGameXCamName = "ui_cam_endgame_mp_sector";
}

function dom_flag_base_fx_override( flag, team )
{
	switch ( flag.name )
	{
		case "a":
			break;
		case "b":
			if ( team == "neutral" )
			{
				return "ui/fx_dom_marker_neutral_r90";
			}
			else
			{
				return "ui/fx_dom_marker_team_r90";
			}
			break;
		case "c":
			if ( team == "neutral" )
			{
				return "ui/fx_dom_marker_neutral_r120";
			}
			else
			{
				return "ui/fx_dom_marker_team_r120";
			}
			break;
	};
}

function dom_flag_cap_fx_override( flag, team )
{
	switch ( flag.name )
	{
		case "a":
			break;
		case "b":
			if ( team == "neutral" )
			{
				return "ui/fx_dom_cap_indicator_neutral_r90";
			}
			else
			{
				return "ui/fx_dom_cap_indicator_team_r90";
			}
			break;
		case "c":
			if ( team == "neutral" )
			{
				return "ui/fx_dom_cap_indicator_neutral_r120";
			}
			else
			{
				return "ui/fx_dom_cap_indicator_team_r120";
			}
			break;
	};
}