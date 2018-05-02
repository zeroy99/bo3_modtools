#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;

#using scripts\mp\gametypes\_globallogic;

#insert scripts\shared\shared.gsh;

function main()
{
	callback::on_spawned( &on_player_spawned );
	if( GetGametypeSetting( "silentPlant" ) != 0 )
		setsoundcontext( "bomb_plant", "silent" );	
}

function on_player_spawned( localClientNum )
{
	self thread globallogic::watch_plant_sound( localClientNum );
}
