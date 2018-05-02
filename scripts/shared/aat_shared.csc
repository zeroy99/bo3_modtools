// AAT stands for Alternative Ammunition Types

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\aat_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace aat;
	
REGISTER_SYSTEM( "aat", &__init__, undefined )

function private __init__()
{		
	level.aat_initializing = true;
	level.aat_default_info_name = AAT_RESERVED_NAME;
	level.aat_default_info_icon = "blacktransparent";
	 
	level.aat = [];
	register( AAT_RESERVED_NAME, level.aat_default_info_name, level.aat_default_info_icon );
	
	callback::on_finalize_initialization( &finalize_clientfields );
}

/@
"Name: register_clientfield( <name>, <localized_string> )"
"Summary: Register an AAT
"Module: AAT"
"MandatoryArg: <name> Unique name to identify the AAT.
"MandatoryArg: <localized_string> local string reference.
"MandatoryArg: <icon> icon name.
"Example: level aat::register( ZM_AAT_BLAST_FURNACE_NAME, ZM_AAT_BLAST_FURNACE_LOCALIZED_STRING, ZM_AAT_BLAST_FURNACE_ICON );"
"SPMP: both"
@/
function register( name, localized_string, icon )
{
	assert( IS_TRUE( level.aat_initializing), "All info registration in the AAT system must occur during the first frame while the system is initializing" );
	
	assert( IsDefined( name ), "aat::register(): name must be defined" );
	assert( !IsDefined( level.aat[name] ), "aat::register(): AAT '" + name + "' has already been registered" );
	
	assert( IsDefined( localized_string ), "aat::register(): localized_string must be defined" );
	assert( IsDefined( icon ), "aat::register(): icon must be defined" );

	level.aat[name] = SpawnStruct();

	level.aat[name].name = name;
	level.aat[name].localized_string = localized_string;
	level.aat[name].icon = icon;
}

function aat_hud_manager( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( IsDefined( level.update_aat_hud ) )
	{
		[[level.update_aat_hud]]( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
	}
}


function finalize_clientfields()
{
	/#println( "AAT client registrations:" );#/

	if ( level.aat.size > 1 )
	{
		array::alphabetize( level.aat );
		
		i = 0;
		foreach ( aat in level.aat )
		{
			aat.n_index = i;
			i++;

			/#println( "    " + aat.name );#/
		}
		n_bits = GetMinBitCountForNum( level.aat.size - 1 );
		clientfield::register( "toplayer", AAT_CLIENTFIELD_NAME, VERSION_SHIP, n_bits, "int", &aat_hud_manager, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	}
	
	level.aat_initializing = false;
}

function get_string( n_aat_index )
{
	foreach ( aat in level.aat )
	{
		if ( aat.n_index == n_aat_index )
		{
			return aat.localized_string;
		}
	}
	return level.aat_default_info_name;
}

function get_icon( n_aat_index )
{
	foreach ( aat in level.aat )
	{
		if ( aat.n_index == n_aat_index )
		{
			return aat.icon;
		}
	}

	return level.aat_default_info_icon;
}

