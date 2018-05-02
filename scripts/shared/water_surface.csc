#using scripts\shared\system_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\postfx_shared;
#insert scripts\shared\shared.gsh;
#using scripts\shared\util_shared;

#namespace water_surface;

#precache( "client_fx", "player/fx_plyr_water_jump_in_bubbles_1p" );
#precache( "client_fx", "player/fx_plyr_water_jump_out_splash_1p" );

#define WATER_DIVE_OVERLAY_TIME 0.7
#define WATER_SHEETING_OVERLAY_TIME 2.0
	
//#define START_WATER_SHEETING { filter::enable_filter_water_sheeting( self, FILTER_INDEX_WATER_SHEET ); }
#define STOP_WATER_SHEETING { filter::disable_filter_water_sheeting( self, FILTER_INDEX_WATER_SHEET ); stop_player_fx( self ); }

//#define START_WATER_DIVE { filter::enable_filter_water_dive( self, FILTER_INDEX_WATER_SHEET ); }
#define STOP_WATER_DIVE { filter::disable_filter_water_dive( self, FILTER_INDEX_WATER_SHEET ); stop_player_fx( self );}
	
REGISTER_SYSTEM( "water_surface", &__init__, undefined )		

function __init__()
{
	level._effect["water_player_jump_in"] = "player/fx_plyr_water_jump_in_bubbles_1p";
	level._effect["water_player_jump_out"] = "player/fx_plyr_water_jump_out_splash_1p";
	
	if ( isdefined( level.disableWaterSurfaceFX ) && level.disableWaterSurfaceFX == true )
	{
		return;
	}
	
	callback::on_localplayer_spawned( &localplayer_spawned );
}

function localplayer_spawned( localClientNum )
{
	if( self != GetLocalPlayer( localClientNum ) )
		return;

	if ( isdefined( level.disableWaterSurfaceFX ) && level.disableWaterSurfaceFX == true )
	{
		return;
	}
	
	filter::init_filter_water_sheeting( self );
	filter::init_filter_water_dive( self );
	
	self thread underwaterWatchBegin();
	self thread underwaterWatchEnd();
	
	STOP_WATER_SHEETING;
}

function underwaterWatchBegin()
{
	self notify( "underwaterWatchBegin" );
	self endon( "underwaterWatchBegin" );
	self endon( "entityshutdown" );
	
	while( true )
	{
		self waittill( "underwater_begin", teleported );
		if ( teleported ) 
		{
			STOP_WATER_SHEETING;
			STOP_WATER_DIVE;
		}
		else
		{
			self thread underwaterBegin();
		}
	}
}

function underwaterWatchEnd()
{
	self notify( "underwaterWatchEnd" );
	self endon( "underwaterWatchEnd" );
	self endon( "entityshutdown" );
	
	while( true )
	{
		self waittill(  "underwater_end", teleported );
		if ( teleported ) 
		{
			STOP_WATER_SHEETING;
			STOP_WATER_DIVE;
		}
		else
		{
			self thread underwaterEnd();
		}
	}
}

function underwaterBegin()
{ 
	self notify( "water_surface_underwater_begin" );
	self endon( "water_surface_underwater_begin" );
	self endon( "entityshutdown" );
	
	localClientNum = self getlocalclientnumber();
	
	STOP_WATER_SHEETING;
	
	if ( islocalclientdead( localClientNum ) == false )
	{
		self.firstperson_water_fx = PlayFXOnCamera( localClientNum, level._effect["water_player_jump_in"], (0,0,0), (1,0,0), (0,0,1)  );
		if ( !isdefined( self.playingPostfxBundle ) || self.playingPostfxBundle != "pstfx_watertransition" )
		{
			self thread postfx::PlayPostfxBundle( "pstfx_watertransition" );	
		}
	}
}

function underwaterEnd()
{
	self notify( "water_surface_underwater_end" );
	self endon( "water_surface_underwater_end" );
	self endon( "entityshutdown" );
	
	localClientNum = self getlocalclientnumber();
	if ( islocalclientdead( localClientNum ) == false )
	{
		if ( !isdefined( self.playingPostfxBundle ) || self.playingPostfxBundle != "pstfx_water_t_out" )
		{
			self thread postfx::PlayPostfxBundle( "pstfx_water_t_out" );	
		}
	}
}


function startWaterDive()
{
	// turn on the water dive PostFX
	filter::enable_filter_water_dive( self, FILTER_INDEX_WATER_SHEET );

	// allow the bubble clouds to proceed mostly straight upwards
	filter::set_filter_water_scuba_dive_speed( self, FILTER_INDEX_WATER_SHEET, 0.25 );

	// set the tint color of the wash bubble wash
	filter::set_filter_water_wash_color( self, FILTER_INDEX_WATER_SHEET, 0.16, 0.5, 0.9 );

	// set the wash reveal direction to down
	filter::set_filter_water_wash_reveal_dir( self, FILTER_INDEX_WATER_SHEET, -1 );
	// reveal the wash
	for ( i = 0; i < 0.05; i += 0.01 )
	{
		filter::set_filter_water_dive_bubbles( self, FILTER_INDEX_WATER_SHEET, i / 0.05 );
		wait 0.01;
	}
	filter::set_filter_water_dive_bubbles( self, FILTER_INDEX_WATER_SHEET, 1 );

	// set the bubble cloud fade direction to up
	filter::set_filter_water_scuba_bubble_attitude( self, FILTER_INDEX_WATER_SHEET, -1 );
	// start the bubble clouds
	filter::set_filter_water_scuba_bubbles( self, FILTER_INDEX_WATER_SHEET, 1 );

	// set the wash reveal direction to up
	filter::set_filter_water_wash_reveal_dir( self, FILTER_INDEX_WATER_SHEET, 1 );
	// hide the wash
	for ( i = 0.2; i > 0; i -= 0.01 )
	{
		filter::set_filter_water_dive_bubbles( self, FILTER_INDEX_WATER_SHEET, i / 0.2 );
		wait 0.01;
	}
	filter::set_filter_water_dive_bubbles( self, FILTER_INDEX_WATER_SHEET, 0 );

	// allow the bubble clouds to play
	wait 0.1;
	// hide the bubble clouds
	for ( i = 0.2; i > 0; i -= 0.01 )
	{
		filter::set_filter_water_scuba_bubbles( self, FILTER_INDEX_WATER_SHEET, i / 0.2 );
		wait 0.01;
	}
}

function startWaterSheeting()
{
	self notify( "startWaterSheeting_singleton" );
	self endon( "startWaterSheeting_singleton" );
	
	self endon( "entityshutdown" );
	
	// enabled the filter
	filter::enable_filter_water_sheeting( self, FILTER_INDEX_WATER_SHEET ); 

	// start everything revealed and scrolling
	filter::set_filter_water_sheet_reveal( self, FILTER_INDEX_WATER_SHEET, 1.0 );
	filter::set_filter_water_sheet_speed( self, FILTER_INDEX_WATER_SHEET, 1.0 );

	// taper down and hide
	for ( i = WATER_SHEETING_OVERLAY_TIME; i > 0.0; i -= 0.01 )
	{
		filter::set_filter_water_sheet_reveal( self, FILTER_INDEX_WATER_SHEET, i / 2.0 );
		filter::set_filter_water_sheet_speed( self, FILTER_INDEX_WATER_SHEET, i / 2.0 );
		// reveal the rivulets as well
		rivulet1 = (i/2.0) - 0.19;
		rivulet2 = (i/2.0) - 0.13;
		rivulet3 = (i/2.0) - 0.07;
		filter::set_filter_water_sheet_rivulet_reveal( self, FILTER_INDEX_WATER_SHEET, rivulet1, rivulet2, rivulet3 );
		// pause
		wait 0.01;
	}
	filter::set_filter_water_sheet_reveal( self, FILTER_INDEX_WATER_SHEET, 0.0 );
	filter::set_filter_water_sheet_speed( self, FILTER_INDEX_WATER_SHEET, 0.0 );
	filter::set_filter_water_sheet_rivulet_reveal( self, FILTER_INDEX_WATER_SHEET, 0.0, 0.0, 0.0 );
}

function stop_player_fx( localClient )
{
	if ( IsDefined( localClient.firstperson_water_fx ) )
	{
		localClientNum = localClient getlocalclientnumber();
		StopFx( localClientNum, localClient.firstperson_water_fx );
		localClient.firstperson_water_fx = undefined;
	}
}
