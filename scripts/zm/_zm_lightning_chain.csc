#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_lightning_chain.gsh;

#namespace lightning_chain;

REGISTER_SYSTEM( "lightning_chain", &init, undefined )

#define FX_LC_BOLT 				"zombie/fx_tesla_bolt_secondary_zmb"
#define FX_LC_SHOCK 			"zombie/fx_tesla_shock_zmb"
#define FX_LC_SHOCK_SECONDARY 	"zombie/fx_tesla_bolt_secondary_zmb"
#define FX_LC_SHOCK_EYES	 	"zombie/fx_tesla_shock_eyes_zmb"
#define FX_LC_SHOCK_NONFATAL	"zombie/fx_bmode_shock_os_zod_zmb"
	

#precache( "client_fx", FX_LC_BOLT 			);
#precache( "client_fx", FX_LC_SHOCK 			);
#precache( "client_fx", FX_LC_SHOCK_SECONDARY 	);
#precache( "client_fx", FX_LC_SHOCK_EYES	 	);
#precache( "client_fx", FX_LC_SHOCK_NONFATAL	 	);


function init()
{
	level._effect["tesla_bolt"]				= FX_LC_BOLT;
	level._effect["tesla_shock"]			= FX_LC_SHOCK;
	level._effect["tesla_shock_secondary"]	= FX_LC_SHOCK_SECONDARY;
	level._effect["tesla_shock_nonfatal"]	= FX_LC_SHOCK_NONFATAL;

	level._effect["tesla_shock_eyes"]		= FX_LC_SHOCK_EYES;
	
	clientfield::register( "actor", "lc_fx", VERSION_SHIP, 2, "int", &lc_shock_fx, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "lc_fx", VERSION_SHIP, 2, "int", &lc_shock_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	clientfield::register( "actor", "lc_death_fx", VERSION_SHIP, 2, "int", &lc_play_death_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	
	clientfield::register( "vehicle", "lc_death_fx", VERSION_TU8, 2, "int", &lc_play_death_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );	// Leave at VERSION_TU8, which will support the TU10 on the server, as well as the TU8's that shipped once already
}

function lc_shock_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self endon( "entityshutdown" );
	self util::waittill_dobj(localClientNum);
	
	if( newVal )
	{
		if ( !isdefined( self.lc_shock_fx ) )
		{
			str_tag = "J_SpineUpper";
			str_fx = "tesla_shock";

			if ( !self IsAI() )
			{
				str_tag = "tag_origin";
			}
				
			if ( newVal > 1 )
			{
				str_fx = "tesla_shock_secondary";
			}
			self.lc_shock_fx = PlayFxOnTag( localClientNum, level._effect[ str_fx ], self, str_tag );
			self playsound( 0, "zmb_electrocute_zombie" );
		}
	}
	else
	{
		if ( isdefined( self.lc_shock_fx ) )
		{
			StopFX( localClientNum, self.lc_shock_fx );
			self.lc_shock_fx = undefined;
		}
	}
}

function lc_play_death_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self endon( "entityshutdown" );
	self util::waittill_dobj(localClientNum);
	
	str_tag = "J_SpineUpper";

	if ( IS_TRUE(self.isdog)  )
	{
		str_tag = "J_Spine1";
	}
	
	if ( !IS_EQUAL( self.archetype, ARCHETYPE_ZOMBIE ) )
	{
		tag = "tag_origin";
	}	
	
	switch( newVal )
	{			
		case N_SECONDARY_SHOCK_EFFECT:
			str_fx = level._effect["tesla_shock_secondary"];
			break;
			
		case N_NONFATAL_SHOCK_EFFECT:
			str_fx = level._effect["tesla_shock_nonfatal"];
			break;

		default:
			str_fx = level._effect["tesla_shock"];
			break;
	}
	
	PlayFxOnTag( localClientNum, str_fx, self, str_tag );
}
