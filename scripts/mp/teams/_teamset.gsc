#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

function init()
{
	if ( !isdefined( game["flagmodels"] ) )
		game["flagmodels"] = [];

	if ( !isdefined( game["carry_flagmodels"] ) )
		game["carry_flagmodels"] = [];

	if ( !isdefined( game["carry_icon"] ) )
		game["carry_icon"] = [];

	game["flagmodels"]["neutral"] = "p7_mp_flag_neutral";
}

function customteam_init()
{
	if( GetDvarString( "g_customTeamName_Allies") != "" )
	{
		SetDvar("g_TeamName_Allies", GetDvarString( "g_customTeamName_Allies") );
	}
	
	if( GetDvarString( "g_customTeamName_Axis") != "" )
	{
		SetDvar("g_TeamName_Axis", GetDvarString( "g_customTeamName_Axis") );
	}
}
