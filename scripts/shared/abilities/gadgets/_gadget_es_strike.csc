#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_es_strike", &__init__, undefined )

function __init__()
{
	callback::on_spawned( &on_player_spawned );
}

function on_player_spawned( local_client_num )
{

}