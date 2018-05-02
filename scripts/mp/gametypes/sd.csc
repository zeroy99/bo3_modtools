#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;

#using scripts\mp\gametypes\_globallogic;

#insert scripts\shared\shared.gsh;

function main()
{
	callback::on_spawned( &on_player_spawned );
	//callback::on_start_gametype( &onStartGameType );
	if( GetGametypeSetting( "silentPlant" ) != 0 )
		setsoundcontext( "bomb_plant", "silent" );	
}

function onStartGameType()
{	
}

function on_player_spawned( localClientNum )
{
	self thread player_sound_context_hack();
	self thread globallogic::watch_plant_sound( localClientNum );
}

function player_sound_context_hack()
{
	if( GetGametypeSetting( "silentPlant" ) != 0 )
	{
		self endon("entityshutdown");
		
		self notify("player_sound_context_hack");
		self endon("player_sound_context_hack");
		
		while(1)
		{
			self setsoundentcontext( "bomb_plant", "silent" );	
			wait(1);
		}
	}
	
}