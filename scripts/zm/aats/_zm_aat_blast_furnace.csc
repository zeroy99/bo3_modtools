#using scripts\shared\aat_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\aat_zm.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\aats\_zm_aat_blast_furnace.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache( "client_fx", ZM_AAT_BLAST_FURNACE_EXPLOSION_FX );
#precache( "client_fx", ZM_ATT_BLAST_FURNACE_BURN_FX );

#namespace zm_aat_blast_furnace;

REGISTER_SYSTEM( ZM_AAT_BLAST_FURNACE_NAME, &__init__, undefined )

function __init__()
{
	if ( !IS_TRUE( level.aat_in_use ) )
	{
		return;
	}

	aat::register( ZM_AAT_BLAST_FURNACE_NAME, ZM_AAT_BLAST_FURNACE_LOCALIZED_STRING, ZM_AAT_BLAST_FURNACE_ICON );
	
	clientfield::register( "actor", ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION, VERSION_SHIP, 1, "counter", &zm_aat_blast_furnace_explosion, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", ZM_AAT_BLAST_FURNACE_CF_NAME_EXPLOSION_VEH, VERSION_SHIP, 1, "counter", &zm_aat_blast_furnace_explosion_vehicle, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", ZM_AAT_BLAST_FURNACE_CF_NAME_BURN, VERSION_SHIP, 1, "counter", &zm_aat_blast_furnace_burn, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", ZM_AAT_BLAST_FURNACE_CF_NAME_BURN_VEH, VERSION_SHIP, 1, "counter", &zm_aat_blast_furnace_burn_vehicle, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	level._effect[ ZM_AAT_BLAST_FURNACE_NAME ] = ZM_AAT_BLAST_FURNACE_EXPLOSION_FX;
}

// self == targeted zombie
function zm_aat_blast_furnace_explosion( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	PlaySound( 0, ZM_AAT_BLAST_FURNACE_EXPLOSION_SOUND, self.origin );
	
	s_aat_blast_furnace_explosion = SpawnStruct();
	s_aat_blast_furnace_explosion.origin = self.origin;
	s_aat_blast_furnace_explosion.angles = self.angles;
	
	s_aat_blast_furnace_explosion thread zm_aat_blast_furnace_explosion_think( localClientNum );
}

// self == targeted vehicle
function zm_aat_blast_furnace_explosion_vehicle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	PlaySound( 0, ZM_AAT_BLAST_FURNACE_EXPLOSION_SOUND, self.origin );
	
	s_aat_blast_furnace_explosion = SpawnStruct();
	s_aat_blast_furnace_explosion.origin = self.origin;
	s_aat_blast_furnace_explosion.angles = self.angles;
	
	s_aat_blast_furnace_explosion thread zm_aat_blast_furnace_explosion_think( localClientNum );
}

// self == struct at explosion point
function zm_aat_blast_furnace_explosion_think( localClientNum )
{
	angles = self.angles; 
	if ( lengthsquared( angles ) < 0.001 )
		angles = (1,0,0);
	self.fx_aat_blast_furnace_explode = PlayFX( localClientNum, ZM_AAT_BLAST_FURNACE_EXPLOSION_FX, self.origin, angles );
	
	wait ZM_AAT_BLAST_FURNACE_EXPLOSION_TIME;
	
	StopFX( localClientNum, self.fx_aat_blast_furnace_explode );
	self.fx_aat_blast_furnace_explode = undefined;
}

// self == targeted zombie
function zm_aat_blast_furnace_burn( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
	tag = "j_spine4";
	
	// Checks if tag exists
	v_tag = self gettagorigin( tag );
	if ( !isdefined( v_tag ) )
	{
		tag = "tag_origin";
	}

	level thread zm_aat_blast_furnace_burn_think( localClientNum, self, tag );
}

// self == targeted vehicle
function zm_aat_blast_furnace_burn_vehicle( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{	
	tag = "tag_body";
	
	// Checks if tag exists
	v_tag = self gettagorigin( tag );
	if ( !isdefined( v_tag ) )
	{
		tag = "tag_origin";
	}
	
	level thread zm_aat_blast_furnace_burn_think( localClientNum, self, tag );
}

// self == level
function zm_aat_blast_furnace_burn_think( localClientNum, e_zombie, tag )
{
	e_zombie.fx_aat_blast_furnace_burn = PlayFxOnTag( localClientNum, ZM_ATT_BLAST_FURNACE_BURN_FX, e_zombie, tag );
	e_zombie playloopsound( "chr_burn_npc_loop1", .5 );
	
	e_zombie waittill( "entityshutdown" );
	
	if( isdefined(e_zombie) )
	{
		e_zombie StopAllLoopSounds( 1.5 );
		StopFX( localClientNum, e_zombie.fx_aat_blast_furnace_burn );
	}
}

