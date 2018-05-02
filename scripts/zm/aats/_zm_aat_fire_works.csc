#using scripts\shared\aat_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\aats\_zm_aat_fire_works.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", ZM_AAT_FIRE_WORKS_SUMMON_FX );
#precache( "client_fx", ZM_AAT_FIRE_WORKS_SUMMON_TRAIL_FX );
#precache( "client_fx", ZM_AAT_FIRE_WORKS_SUMMON_BURST_FX );

#namespace zm_aat_fire_works;

REGISTER_SYSTEM( ZM_AAT_FIRE_WORKS_NAME, &__init__, undefined )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}
	
	aat::register( ZM_AAT_FIRE_WORKS_NAME, ZM_AAT_FIRE_WORKS_LOCALIZED_STRING, ZM_AAT_FIRE_WORKS_ICON );
	
	clientfield::register( "scriptmover", ZM_AAT_FIRE_WORKS_NAME, VERSION_SHIP, 1, "int", &zm_aat_fire_works_summon, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level._effect[ ZM_AAT_FIRE_WORKS_NAME ] = ZM_AAT_FIRE_WORKS_SUMMON_FX;
}

// self == targeted zombie
function zm_aat_fire_works_summon( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal )
	{
		self.aat_fire_works_fx = PlayFX( localClientNum, ZM_AAT_FIRE_WORKS_SUMMON_FX, self.origin, AnglesToForward( self.angles ) );
		PlaySound( localClientNum, ZM_AAT_FIRE_WORKS_EXPLODE_SOUND, self.origin );
		if ( IsDemoPlaying() )
		{
			self thread kill_fx_on_demo_jump(localClientNum);
		}
	}
	else
	{
		if ( isdefined( self.aat_fire_works_fx ) )
	    {
			self notify( "kill_fx_on_demo_jump" );
			StopFX( localClientNum, self.aat_fire_works_fx );
			self.aat_fire_works_fx = undefined;
		}
	}
}


function kill_fx_on_demo_jump(localClientNum)
{
	self notify( "kill_fx_on_demo_jump" );
	self endon(	"kill_fx_on_demo_jump" );
	level waittill("demo_jump");
	if ( isdefined( self.aat_fire_works_fx ) )
    {
		StopFX( localClientNum, self.aat_fire_works_fx );
		self.aat_fire_works_fx = undefined;
	}
}
