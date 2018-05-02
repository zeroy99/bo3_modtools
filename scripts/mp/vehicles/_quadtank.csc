#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace quadtank;

REGISTER_SYSTEM( "quadtank", &__init__, undefined )

function __init__()
{
	vehicle::add_vehicletype_callback( "quadtank", &_setup_ );
	clientfield::register( "toplayer", "player_shock_fx", VERSION_SHIP, 1, "int", &player_shock_fx_handler, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "quadtank_trophy_state", VERSION_SHIP, 1, "int", &update_trophy_system_state, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT ); 
}

function _setup_( localClientNum )
{
	player = GetLocalPlayer( localClientNum );
	if( isdefined( player ) )
	{
		filter::init_filter_ev_interference( player );
	}
	//set code field to get notifies to play impact effects
	self.notifyOnBulletImpact = true;
	self thread wait_for_bullet_impact( localClientNum );
	
	//trophy state
	self.trophy_on = false;
	
	self thread player_enter( localClientNum );
	self thread player_exit( localClientNum );
}

function player_enter( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	while( 1 )
	{
		self waittill( "enter_vehicle", player );
		
		if( self IsLocalClientDriver( localClientNum ) )
		{
			self SetHighDetail( true );
		}
		
		wait CLIENT_FRAME;
	}
}

function player_exit( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	while( 1 )
	{
		self waittill( "exit_vehicle", player );
		if( isdefined( player ) && player islocalplayer() )
		{
			self SetHighDetail( false );
		}
		wait CLIENT_FRAME;
	}
}


function update_trophy_system_state( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
}

function player_shock_fx_handler( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isdefined( self ) )
	{
		self thread player_shock_fx_fade_off( localClientNum, 1.0, 1.0 );
	}
}

function player_shock_fx_fade_off( localClientNum, amount, fadeoutTime )
{
	// not ending on death or shutdown, cause we have to clean ourselves up
	self endon( "disconnect" );
	self notify( "player_shock_fx_fade_off_end" );	// kill previous threads
	self endon( "player_shock_fx_fade_off_end" );

	if ( !isAlive( self ) )
	{
		return;
	}

	startTime = GetTime();

	filter::set_filter_ev_interference_amount( self, FILTER_INDEX_PLAYER_SHOCK, amount );
	filter::enable_filter_ev_interference( self, FILTER_INDEX_PLAYER_SHOCK );

	while ( GetTime() <= startTime + fadeoutTime * 1000 && isAlive( self ) )
	{
		ratio = ( GetTime() - startTime ) / ( fadeoutTime * 1000 );
		currentValue = LerpFloat( amount, 0, ratio );
		setfilterpassconstant( localClientNum, FILTER_INDEX_PLAYER_SHOCK, 0, 0, currentValue ); // use code function instead of script wrapper cause player can be undefined

		wait CLIENT_FRAME;
	}

	setfilterpassenabled( localClientNum, FILTER_INDEX_PLAYER_SHOCK, 0, false );
}

function wait_for_bullet_impact( localClientNum )
{
	self endon( "entityshutdown" );
	
	if( isdefined( self.scriptbundlesettings ) )
	{
		settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
	}
	else
	{
		return;
	}
	
	while( 1 )
	{
		self waittill( "damage", attacker, impactPos, effectDir, partname );
		if( partName == "tag_target_lower" || partName == "tag_target_upper" || partName == "tag_defense_active" || partName == "tag_body_animate" )
		{
			if( self.trophy_on )
			{
				if( IsDefined( attacker ) && attacker IsPlayer() && attacker.team != self.team )
				{
					PlayFx( localClientNum, settings.weakspotfx, impactPos, effectDir );
					self playsound( 0, "veh_quadtank_panel_hit" );
				}
			}
		}
	}
}
