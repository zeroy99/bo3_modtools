#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_weapons;

#namespace zm_utility;

/@
"Name: ignore_triggers( <timer> )"
"Summary: Makes the entity that this is threaded on not able to set off triggers for a certain length of time."
"Module: Utility"
"CallOn: an entity"
"Example: guy thread ignore_triggers( 0.2 );"
"SPMP: singleplayer"
@/ 
function ignore_triggers( timer )
{
	// ignore triggers for awhile so others can trigger the trigger we're in.
	self endon( "death" ); 
	self.ignoreTriggers = true; 
	if( IsDefined( timer ) )
	{
		wait( timer ); 
	}
	else
	{
		wait( 0.5 ); 
	}
	self.ignoreTriggers = false; 
}

////////////////////////////// Callbacks ////////////////////////////////////////////

function is_encounter()
{
	return false;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MATH
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function round_up_to_ten( score )
{
	new_score = score - score % 10; 
	if( new_score < score )
	{
		new_score += 10; 
	}
	return new_score; 
}

function round_up_score( score, value )
{
	score = int(score);	// Make sure it's an int or modulus will die

	new_score = score - score % value; 
	if( new_score < score )
	{
		new_score += value; 
	}
	return new_score; 
}

function halve_score( n_score )
{
	n_score = n_score / 2;
	n_score = zm_utility::round_up_score( n_score, 10 );
	
	return n_score; 
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// WEAPONS
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function spawn_weapon_model( localClientNum, weapon, model, origin, angles, options )
{
	if ( !isdefined( model ) )
	{
		model = weapon.worldModel;
	}
	
	weapon_model = spawn( localClientNum, origin, "script_model" ); 
	if ( isdefined( angles ) )
	{
		weapon_model.angles = angles;
	}

	if (isdefined(options))
	{
		weapon_model useweaponmodel( weapon, model, options );
	}
	else
	{
		weapon_model useweaponmodel( weapon, model );
	}

	return weapon_model;
}

function spawn_buildkit_weapon_model( localClientNum, weapon, camo, origin, angles )
{
	weapon_model = spawn( localClientNum, origin, "script_model" ); 
	if ( isdefined( angles ) )
	{
		weapon_model.angles = angles;
	}

	weapon_model UseBuildKitWeaponModel( localClientNum, weapon, camo, zm_weapons::is_weapon_upgraded( weapon ) );

	return weapon_model;
}

function is_classic()
{
	return true;
}

function is_gametype_active( a_gametypes )
{
	b_is_gametype_active = false;
	
	if ( !IsArray( a_gametypes ) )
	{
		a_gametypes = Array( a_gametypes );
	}
	
	for ( i = 0; i < a_gametypes.size; i++ )
	{
		if ( GetDvarString( "g_gametype" ) == a_gametypes[ i ] )
		{
			b_is_gametype_active = true;
		}
	}

	return b_is_gametype_active;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UI
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function setInventoryUIModels( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )  
{
	if ( IsSpectating( localClientNum ) )
	{
		return;	
	}
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "zmInventory." + fieldName ), newVal );
}

function setSharedInventoryUIModels( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )  
{
	// shared inventory models should show up even if you're spectating, so that they're there when you respawn.
	SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "zmInventory." + fieldName ), newVal );
}

function zm_ui_infotext( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "zmInventory.infoText" ), fieldName );
	}
	else
	{
		SetUIModelValue( CreateUIModel( GetUIModelForController( localClientNum ), "zmInventory.infoText" ), "" );
	}
}

function umbra_fix_logic( localClientNum )
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );

	umbra_settometrigger( localClientNum, "" );	//reset script umbra override
	while( 1 )
	{
		in_fix_area = 0;

		if( isdefined( level.custom_umbra_hotfix ) )
		{
			in_fix_area = self thread [[level.custom_umbra_hotfix]]( localClientNum );
		}

		//If not in any override volumns then set the script umbra override to empty (default behavour)
		if( in_fix_area == 0 )
		{
			umbra_settometrigger( localClientNum, "" );
		}
		WAIT_SERVER_FRAME;
	}
}

function umbra_fix_trigger( localClientNum, pos, height, radius, umbra_name )
{
	bottomY = pos[2];
	topY = pos[2] + height;

	if( (self.origin[2] > bottomY) && (self.origin[2] < topY) )
	{
		if( Distance2dSquared(self.origin, pos) < radius*radius )
		{
			//force draw umbra tome
			umbra_settometrigger( localClientNum, umbra_name );
			return true;
		}
	}
	return false;
}



