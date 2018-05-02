// Client side craftable functionality

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_utility.gsh;
#insert scripts\zm\craftables\_zm_craftables.gsh;

#namespace zm_craftables;

REGISTER_SYSTEM( "zm_craftables", &__init__, undefined )
	
function __init__()
{
	level.craftable_piece_count = 0;
	callback::on_finalize_initialization( &set_craftable_clientfield );
}

function set_craftable_clientfield( localClientNum )
{
	if( !isdefined( level.zombie_craftables ) )
	{
		level.zombie_craftables = [];
	}
	set_piece_count( level.zombie_craftables.size + 1 );
}

function init()
{
	//Buidables:

	if (isdefined(level.init_craftables))
	{
		[[level.init_craftables]]();
	}
}

function add_zombie_craftable( craftable_name )
{
	if ( !IsDefined( level.zombie_include_craftables ) )
	{
		level.zombie_include_craftables = [];
	}
	
	if( IsDefined( level.zombie_include_craftables ) && !IsDefined( level.zombie_include_craftables[ craftable_name ] ) )
	{
		return;
	}

	craftable_name = level.zombie_include_craftables[ craftable_name ];

	if( !IsDefined( level.zombie_craftables ) )
	{
		level.zombie_craftables = [];
	}

	level.zombie_craftables[ craftable_name ] = craftable_name;
}

function set_clientfield_craftables_code_callbacks()
{
	wait(0.1);        // This won't run - until after all the client field registration has finished.

	if ( level.zombie_craftables.size > 0 )
	{
		SetupClientFieldCodeCallbacks( "toplayer", 1, CLIENTFIELD_CRAFTABLE );	
	}
}

function include_zombie_craftable( craftable_name )
{
	if ( !IsDefined( level.zombie_include_craftables ) )
	{
		level.zombie_include_craftables = [];
	}

	level.zombie_include_craftables[ craftable_name ] = craftable_name;
}

function set_piece_count( n_count )
{
	bits = GetMinBitCountForNum( n_count );
	RegisterClientField( "toplayer", CLIENTFIELD_CRAFTABLE,	VERSION_SHIP, bits, "int", undefined, false, true );	
}
