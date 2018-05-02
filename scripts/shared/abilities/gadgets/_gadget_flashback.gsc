#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;
#insert scripts\shared\abilities\gadgets\_gadget_flashback.gsh;

#namespace flashback;

#define FLASHBACK_TRAIL_IMPACT_FX	"player/fx_plyr_flashback_trail_impact"
	
#precache( "fx", FLASHBACK_TRAIL_IMPACT_FX );

REGISTER_SYSTEM( "gadget_flashback", &__init__, undefined )

function __init__()
{
	clientfield::register( "scriptmover", "flashback_trail_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "playercorpse", "flashback_clone" , VERSION_SHIP, 1, "int" );
	clientfield::register( "allplayers", "flashback_activated" , VERSION_SHIP, 1, "int" );
	
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_on, &gadget_flashback_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_on_give, &gadget_flashback_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_is_flickering );
	ability_player::register_gadget_primed_callbacks( GADGET_TYPE_FLASHBACK, &gadget_flashback_is_primed );
	
	callback::on_connect( &gadget_flashback_on_connect );
	callback::on_spawned( &gadget_flashback_spawned );
	
	if ( !IsDefined( level.vsmgr_prio_overlay_flashback_warp ) )
	{
		level.vsmgr_prio_overlay_flashback_warp = 27;
	}		
	visionset_mgr::register_info( "overlay", "flashback_warp", VERSION_SHIP, level.vsmgr_prio_overlay_flashback_warp, 1, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false );
}

function gadget_flashback_spawned()
{
	self clientfield::set( "flashback_activated", 0 );
}

function gadget_flashback_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self flagsys::get( "gadget_flashback_on" );
}

function gadget_flashback_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_flashback_on_flicker( slot, weapon )
{

}

function gadget_flashback_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
}

function gadget_flashback_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
}

//self is the player
function gadget_flashback_on_connect()
{
	// setup up stuff on player connect
}

function clone_watch_death()
{
	self endon ( "death" );
	
	wait( FLASHBACK_CLONE_DURATION );
	
	// do not delete the clones
	// player corpses should never get deleted
	self clientfield::set( "flashback_clone", 0 );

	self ghost();
}


#define MAX_RECURSION_DEPTH 8

function drop_unlinked_grenades( linkedGrenades )
{
	waittillframeend;
	
	foreach( grenade in linkedGrenades )
	{
		grenade launch( (RandomFloatRange( -5, 5 ),RandomFloatRange( -5, 5 ),5) );
	}
}
	
function unlink_grenades( oldpos )
{
	radius = 32;
	origin = oldpos;
	grenades = getentarray( "grenade", "classname" );
	radiusSq = radius * radius;
	linkedGrenades = [];

	foreach( grenade in grenades )
	{
		if( DistanceSquared( origin, grenade.origin ) < radiusSq )
		{
			if ( IsDefined( grenade.stuckToPlayer ) && ( grenade.stuckToPlayer == self ) )
			{
				grenade unlink();
				
				linkedGrenades[linkedGrenades.size] = grenade;
			}
		}
	}
	
	thread drop_unlinked_grenades( linkedGrenades );
}
	
function gadget_flashback_on( slot, weapon )
{
	// excecutes when the gadget is turned on
	self flagsys::set( "gadget_flashback_on" );	
	
	self GadgetSetActivateTime( slot, GetTime() );

	visionset_mgr::activate( "overlay", "flashback_warp", self, FLASHBACK_WARP_LENGTH, FLASHBACK_WARP_LENGTH );

	self.flashbackTime = GetTime();

	self notify("flashback");
	
	clone = self CreateFlashbackClone();
	clone thread clone_watch_death();
	clone clientfield::set( "flashback_clone", 1 );
	self thread watchClientfields();
	
	oldpos = self GetTagOrigin( "j_spineupper" );
	offset = oldpos - self.origin;
	self unlink_grenades( oldpos );
	newpos = self flashbackstart( weapon ) + offset;
	self NotSolid();
	
	if ( isdefined ( newpos ) && isdefined ( oldpos ) )
	{
		self thread flashbackTrailFx( slot, weapon, oldpos, newpos );
		flashbackTrailImpact( newpos, oldpos, MAX_RECURSION_DEPTH );
		flashbackTrailImpact( oldpos, newpos, MAX_RECURSION_DEPTH );
		
		if ( isdefined( level.playGadgetSuccess ) )
	    {
			self [[ level.playGadgetSuccess ]]( weapon, "flashbackSuccessDelay" );
		}
	}
	
	self thread deactivateFlashbackWarpAfterTime( FLASHBACK_WARP_LENGTH );
}

function watchClientfields()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	util::wait_network_frame();
	self clientfield::set( "flashback_activated", 1 );
	
	util::wait_network_frame();
	self clientfield::set( "flashback_activated", 0 );
}


function flashBackTrailImpact( startPos, endPos, recursionDepth ) 
{
	recursionDepth--;
	if ( recursionDepth <= 0 )
	{
		return;
	}
	trace = BulletTrace( startPos, endPos, false, self );
	if ( trace[ "fraction" ] < 1.0 && trace[ "normal" ] != ( 0,0,0 ) )
	{
		
		PlayFx( FLASHBACK_TRAIL_IMPACT_FX, trace[ "position" ], trace[ "normal" ] );
		newStartPos = trace[ "position" ] - trace[ "normal" ];
		flashBackTrailImpact( newStartPos, endPos, recursionDepth );
	}
}

function deactivateFlashbackWarpAfterTime( time )
{
	self endon( "disconnect" );
	
	self util::waittill_any_timeout( time, "death" );  

	visionset_mgr::deactivate( "overlay", "flashback_warp", self );
}

function flashbackTrailFx( slot, weapon, oldpos, newPos )
{
	dirVec = newPos - oldPos;
	if ( dirVec == (0,0,0) )
	{
		dirVec = (0,0,1);
	}
	dirVec = VectorNormalize( dirVec );
	angles = VectorToAngles( dirVec );
	fxOrg = spawn( "script_model", oldpos, 0, angles );
	fxOrg.angles = angles;
	fxOrg setowner( self );
	fxOrg SetModel( "tag_origin" );
	
	fxOrg clientfield::set( "flashback_trail_fx", 1 );
	util::wait_network_frame();
	tagPos = self GetTagOrigin( "j_spineupper" );
	fxOrg MoveTo( tagPos, 0.1 ); 
	fxOrg waittill( "movedone" );
	wait( 1 );
	fxOrg clientfield::set( "flashback_trail_fx", 0 );
	util::wait_network_frame();
	fxOrg delete();
}

function gadget_flashback_is_primed( slot, weapon )
{
}

function gadget_flashback_off( slot, weapon )
{
	// excecutes when the gadget is turned off
	self flagsys::clear( "gadget_flashback_on" );
	
	self Solid();
	self flashbackfinish();
	
	if( level.gameEnded )
	{
		self FreezeControls( true );
	}

}
