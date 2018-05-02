#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\mp\teams\_teamset;

#define HEAD_ICON_ALLIES		"faction_allies"

#precache( "material", HEAD_ICON_ALLIES );
#precache( "string", "MP_BLACK_OPS_WIN_MATCH" );
#precache( "string", "MP_BLACK_OPS_WIN_ROUND" );
#precache( "string", "MP_BLACK_OPS_MISSION_ACCOMPLISHED" );
#precache( "string", "MP_BLACK_OPS_ELIMINATED" );
#precache( "string", "MP_BLACK_OPS_FORFEITED" );
#precache( "string", "MP_BLACK_OPS_NAME" );

function main()
{
	init( "free" );
	
	foreach( team in level.teams )
	{
		if ( team == "axis" )
			continue;
		
		init( team );
	}
	
	_teamset::customteam_init();
	precache();
}

function init( team )
{
	_teamset::init();

	game[team] = "allies";
	game["attackers"] = team;

	// head icons
	game["entity_headicon_" + team] = HEAD_ICON_ALLIES;
	game["headicon_" + team] = HEAD_ICON_ALLIES;

	// battle chatter
	level.teamPrefix[team] = "vox_st";
	level.teamPostfix[team] = "st6";

	// scoreboard
	SetDvar("g_TeamName_" + team, &"MPUI_ALLIES_SHORT");
	//SetDvar("g_TeamColor_" + team, "0.6 0.64 0.69");
	//SetDvar("g_ScoresColor_" + team, "0.6 0.64 0.69");
	SetDvar("g_FactionName_" + team, "allies" );

	game["strings"][team + "_win"] = &"MP_BLACK_OPS_WIN_MATCH";
	game["strings"][team + "_win_round"] = &"MP_BLACK_OPS_WIN_ROUND";
	game["strings"][team + "_mission_accomplished"] = &"MP_BLACK_OPS_MISSION_ACCOMPLISHED";
	game["strings"][team + "_eliminated"] = &"MP_BLACK_OPS_ELIMINATED";
	game["strings"][team + "_forfeited"] = &"MP_BLACK_OPS_FORFEITED";
	game["strings"][team + "_name"] = &"MP_BLACK_OPS_NAME";

	//Music
	game["music"]["spawn_" + team] = "SPAWN_ST6";
	game["music"]["spawn_short" + team] = "SPAWN_SHORT_ST6";
	game["music"]["victory_" + team] = "VICTORY_ST6";
	
	game["icons"][team] = HEAD_ICON_ALLIES;
	game["voice"][team] = "vox_st6_";
	SetDvar( "scr_" + team, "marines" );

	level.heli_vo[team]["hit"] = "vox_ops_2_kls_attackheli_hit";

	// flag assets
	game["flagmodels"][team] = "p7_mp_flag_allies";
	game["carry_flagmodels"][team] = "p7_mp_flag_allies_carry";
	game["flagmodels"]["neutral"] = "p7_mp_flag_neutral";
}

function precache()
{
}
