#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\rank_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_globallogic;

#using scripts\mp\_util;

#precache( "menu", MENU_TEAM );
#precache( "menu", MENU_CLASS );
#precache( "menu", MENU_CHANGE_CLASS );
#precache( "menu", MENU_CONTROLS );
#precache( "menu", MENU_OPTIONS );
#precache( "menu", MENU_LEAVEGAME );
#precache( "menu", MENU_SPECTATE );
#precache( "string", "MP_HOST_ENDED_GAME" );
#precache( "string", "MP_HOST_ENDGAME_RESPONSE" );
#precache( "eventstring", "open_ingame_menu" );

#namespace menus;

REGISTER_SYSTEM( "menus", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
	callback::on_connect( &on_player_connect );
}

function init()
{
	game["menu_start_menu"] = MENU_START_MENU;
	game["menu_team"] = MENU_TEAM;
	game["menu_class"] = MENU_CLASS;
	game["menu_changeclass"] = MENU_CHANGE_CLASS;
	game["menu_changeclass_offline"] = MENU_CHANGE_CLASS;

	foreach( team in level.teams )
	{
		game["menu_changeclass_" + team ] = MENU_CHANGE_CLASS;
	}
	
	game["menu_controls"] = MENU_CONTROLS;
	game["menu_options"] = MENU_OPTIONS;
	game["menu_leavegame"] = MENU_LEAVEGAME;
}

function on_player_connect()
{	
	self thread on_menu_response();
}

function on_menu_response()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("menuresponse", menu, response);
		
		//println( self getEntityNumber() + " menuresponse: " + menu + " " + response );
		
		//iprintln("^6", response);
			
		if ( response == "back" )
		{
			self closeInGameMenu();

			if ( level.console )
			{
				if( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] || menu == game["menu_team"] || menu == game["menu_controls"] )
				{
	
					if( isdefined( level.teams[self.pers["team"]] ) )
						self openMenu( game[ "menu_start_menu" ] );
				}
			}
			continue;
		}
		
		if(response == "changeteam" && level.allow_teamchange == "1")
		{
			self closeInGameMenu();
			self openMenu(game["menu_team"]);
		}
							
		if(response == "endgame")
		{
			// TODO: replace with onSomethingEvent call 
			if(level.splitscreen)
			{
				//if ( level.console )
				//	endparty();
				level.skipVote = true;

				if ( !level.gameEnded )
				{
					level thread globallogic::forceEnd();
				}
			}
				
			continue;
		}
		
		if(response == "killserverpc")
		{
				level thread globallogic::killserverPc();
				
			continue;
		}

		if ( response == "endround" )
		{
			if ( !level.gameEnded )
			{
				self globallogic::gameHistoryPlayerQuit();
				level thread globallogic::forceEnd();
			}
			else
			{
				self closeInGameMenu();
				self iprintln( &"MP_HOST_ENDGAME_RESPONSE" );
			}			
			continue;
		}

		if(menu == game["menu_team"] && level.allow_teamchange == "1")
		{
			switch(response)
			{
			case "autoassign":
				self [[level.autoassign]]( true );
				break;

			case "spectator":
				self [[level.spectator]]();
				break;
				
			default:
				self [[level.teamMenu]](response);
				break;
			}
		}	// the only responses remain are change class events
		else if( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] )
		{
			if ( response != "cancel" )
			{
				self closeInGameMenu();
				
				if(  level.rankedMatch && isSubstr(response, "custom") )
				{
					if ( self IsItemLocked( rank::GetItemIndex( "feature_cac" ) ) )
					kick( self getEntityNumber() );
				}
	
				self.selectedClass = true;
				self [[level.curClass]](response);
			}
		}
		else if ( menu == "spectate" )
		{
			player = util::getPlayerFromClientNum( int( response ) );
			if ( isdefined ( player ) )
			{
				self SetCurrentSpectatorClient( player );
			}
		}
	}
}

