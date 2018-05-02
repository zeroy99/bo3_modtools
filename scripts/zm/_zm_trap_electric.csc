#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_traps.gsh;

#namespace zm_trap_electric;

REGISTER_SYSTEM( "zm_trap_electric", &__init__, undefined )
	
function __init__()
{	
	visionset_mgr::register_overlay_info_style_electrified( "zm_trap_electric", VERSION_SHIP, 15, ZM_TRAP_ELECTRIC_MAX );
	
	a_traps = struct::get_array( "trap_electric", "targetname" );
	foreach( trap in a_traps )
	{
		clientfield::register( "world", trap.script_noteworthy, VERSION_SHIP, 1, "int", &trap_fx_monitor, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );			
	}
}

function trap_fx_monitor( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	exploder_name = "trap_electric_" + fieldName;
	if ( newVal )
	{
		exploder::exploder( exploder_name );
	}
	else
	{
		exploder::stop_exploder( exploder_name );
	}

	fire_points = struct::get_array( fieldName,"targetname" );
		
	foreach( point in fire_points )
	{
		if( !isdefined( point.script_noteworthy ) )
		{
			if( newVal )
			{
				point thread electric_trap_fx();
			}
			else
			{
				point thread stop_trap_fx();
			}
		}
	}
}

function electric_trap_fx()		// self == a single fire point of an electric trap
{	
	ang = self.angles;
	forward = AnglesToForward(ang);
	up = AnglesToUp(ang);
	
	if ( isdefined( self.loopFX ) && self.loopFX.size )
	{
		stop_trap_fx();
	}

	if(!isdefined(self.loopFX))
	{
		self.loopFX = [];
	}	
	
	players = getlocalplayers();
	
	for(i = 0; i < players.size; i++)
	{
		self.loopFX[i] = PlayFx( i, level._effect["zapper"], self.origin, forward, up, 0);
	}
}

function stop_trap_fx()		// self == a single fire point of an electric trap
{
	players = getlocalplayers();
	
	for(i = 0; i < players.size; i++)
	{
		if ( isdefined( self.loopFX[i] ) )
		{
			StopFx( i, self.loopFX[i] );
		}
	}
	
	self.loopFX = [];	
}
