#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hackable;
#using scripts\shared\hud_util_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace hacker;

#define FLAG_OWNED "hacker_owned"
#define FLAG_INUSE "hacker_on"

REGISTER_SYSTEM( "gadget_hacker", &__init__, undefined )

#define HACKABLE_DEFAULT_POWER_PER_FRAME (0.05 * GetDvarFloat("scr_hacker_power_per_second"))

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_HACKER, &gadget_hacker_on, &gadget_hacker_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_HACKER, &gadget_hacker_on_give, &gadget_hacker_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_HACKER, &gadget_hacker_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_HACKER, &gadget_hacker_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_HACKER, &gadget_hacker_is_flickering );
	
	clientfield::register( "toplayer", "hacker_on" , VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "hacker_active" , VERSION_SHIP, 1, "int" );
	
	callback::on_connect( &gadget_hacker_on_connect );
}

function gadget_hacker_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self flagsys::get( FLAG_INUSE );
}

function gadget_hacker_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_hacker_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_hacker_flicker( slot, weapon );	
}

function gadget_hacker_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
	flagsys::set( FLAG_OWNED ); 

	self clientfield::set_to_player( "hacker_on", 0 );
	self.shock_onpain=0;
	
	//self thread hacker_health_overlay( slot, weapon );
	if ( IsDefined(self.hackProgressBar) )
	{
		self.hackProgressBar hud::destroyElem();
		self.hackProgressBar=undefined;
	}
	if ( IsDefined(self.hackProgressText) )
	{
		self.hackProgressText hud::destroyElem();
		self.hackProgressText=undefined;
	}
}

function gadget_hacker_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
	flagsys::clear( FLAG_OWNED ); 
	
	self.originalOverridePlayerDamage = undefined;
	self.shock_onpain=1;
	
	self clientfield::set_to_player( "hacker_on", 0 );

	self notify( "end_hacker_hud" );

	if ( IsDefined(self.hackProgressBar) )
	{
		self.hackProgressBar hud::destroyElem();
		self.hackProgressBar=undefined;
	}
	if ( IsDefined(self.hackProgressText) )
	{
		self.hackProgressText hud::destroyElem();
		self.hackProgressText=undefined;
	}
}

//self is the player
function gadget_hacker_on_connect()
{
	// setup up stuff on player connec
}

function gadget_hacker_on( slot, weapon )
{
	// excecutes when the gadget is turned on
	self flagsys::set( FLAG_INUSE );	
	self.hacker_slot = slot;
	
	self endon( "gadget_hacker_off" );
	
	WAIT_SERVER_FRAME;
	while( self IsSwitchingWeapons() )
	{
		WAIT_SERVER_FRAME;
	}
	
	if( self flagsys::get( FLAG_INUSE ) )
	{
		//hacker section
		self clientfield::set_to_player( "hacker_on", 1 );
		
		self.hackProgressBar = hud::createPrimaryProgressBar();
		self.hackProgressBar hud::hideElem();
		self.hackProgressText = hud::createPrimaryProgressBarText();
		self.hackProgressText hud::hideElem();
		
	
		self thread hack_things();
	}
}

function gadget_hacker_off( slot, weapon )
{
	self notify( "gadget_hacker_off" );
	self.lockonentity=undefined;

	self.hacker_slot = undefined;
	
	// excecutes when the gadget is turned off
	self flagsys::clear( FLAG_INUSE );
	
	//hacker section
	self clientfield::set_to_player( "hacker_on", 0 );
	self clientfield::set_to_player( "hacker_active", 0 );
	
	if ( IsDefined(self.hackProgressBar) )
	{
		self.hackProgressBar hud::destroyElem();
		self.hackProgressBar=undefined;
	}
	if ( IsDefined(self.hackProgressText) )
	{
		self.hackProgressText hud::destroyElem();
		self.hackProgressText=undefined;
	}
}

function hack_things()
{
	self endon( "gadget_hacker_off" );
	
	target = undefined; 
	
	while( 1 )
	{
		if (!IsDefined(target))
		{
			self.lockonentity=undefined;
			target = self hackable::find_hackable_object();
		}
		if ( IsDefined(target) )
		{
			progress = self hackable::continue_hacking_object(target);
			if ( progress < 0 )
			{
				target = undefined; 
				self.hackProgressBar hud::hideElem();
				self.hackProgressBar hud::updateBar( 0.0, 0.0 );
				self.hackProgressText hud::hideElem();
				self.hackProgressText setText( "" );
				self clientfield::set_to_player( "hacker_active", 0 );
				self.lockonentity=undefined;
		
			}
			else
			{
				cost = target.hackable_cost_mult * HACKABLE_DEFAULT_POWER_PER_FRAME;
				if ( IsDefined(self.hacker_slot) )
				{
					self ability_power::power_loss_event( self.hacker_slot, undefined, cost, "hacker_drain" );
				}
				
				self clientfield::set_to_player( "hacker_active", 1 );
				self.hackProgressBar hud::updateBar( progress, 0.0 );
				self.hackProgressBar hud::showElem();
				if ( IsDefined( target.hackable_progress_prompt ) )
				{
					self.hackProgressText setText( target.hackable_progress_prompt );
					self.hackProgressText hud::showElem();
				}
			}
		}
		if ( IsEntity(target) ) 
		{
			// this will get it outlined
			self.lockonentity=target;
		}
		WAIT_SERVER_FRAME;
	}
	
}


function gadget_hacker_flicker( slot, weapon )
{
	self endon( "disconnect" );	

	if ( !self gadget_hacker_is_inuse( slot ) )
	{
		return;
	}

	eventTime = self._gadgets_player[slot].gadget_flickertime;

	self set_gadget_status( "Flickering", eventTime );

	while( 1 )
	{		
		if ( !self GadgetFlickering( slot ) )
		{
			self set_gadget_status( "Normal" );
			return;
		}

		wait( 0.5 );
	}
}

function set_gadget_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Vision Armor: " + status + timeStr );
}

