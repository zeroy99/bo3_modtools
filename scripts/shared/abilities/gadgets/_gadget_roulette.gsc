#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\visionset_mgr_shared;

#using scripts\shared\abilities\_ability_gadgets;
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#using scripts\shared\_burnplayer;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace roulette;

REGISTER_SYSTEM( "gadget_roulette", &__init__, undefined )

#define ROULETTE_STATE_DEFAULT			0
#define ROULETTE_STATE_WAIT_FOR_RESPIN	1
#define ROULETTE_STATE_SPINNING			2
#define ROULETTE_STATE_RESPIN_PROMPT	3	//used in LUA

	
#define ROULETTE_ACTIVATION_WAIT		1.1
#define ROULETTE_PRE_RESPIN_WAIT_TIME	1.3
#define ROULETTE_RESPIN_ACTIVATION_WAIT 1.2

#define PRIMARY_CATEGORY			0
#define SECONDARY_CATEGORY			1
#define PRIMARY_CATEGORY_TOTAL		0
#define SECONDARY_CATEGORY_TOTAL	1

function __init__()
{
	clientfield::register( "toplayer", "roulette_state", VERSION_TU11, 2, "int" );
	
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_on_activate, &gadget_roulette_on_deactivate );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_on_give, &gadget_roulette_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_is_inuse );
	ability_player::register_gadget_ready_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_is_ready );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_ROULETTE, &gadget_roulette_is_flickering );
	ability_player::register_gadget_should_notify( GADGET_TYPE_ROULETTE, false );
	
	callback::on_connect( &gadget_roulette_on_connect );
	callback::on_spawned( &gadget_roulette_on_player_spawn );

	if ( SessionModeIsMultiplayerGame() )
	{
		level.gadgetRouletteProbabilities = [];
		level.gadgetRouletteProbabilities[PRIMARY_CATEGORY_TOTAL] = 0;
		level.gadgetRouletteProbabilities[SECONDARY_CATEGORY_TOTAL] = 0;
		
		level.weaponNone = getWeapon( "none" );
		level.gadget_roulette = GetWeapon( "gadget_roulette" );
		
		// Gadget roll weights							first roll 		second roll
		registerGadgetType( "gadget_flashback", 		1, 				1 );
		registerGadgetType( "gadget_combat_efficiency", 1, 				1 );
		registerGadgetType( "gadget_heat_wave", 		1, 				1 );
		registerGadgetType( "gadget_vision_pulse", 		1, 				1 );
		registerGadgetType( "gadget_speed_burst",		1, 				1 );
		registerGadgetType( "gadget_camo", 				1,		 		1 );
		registerGadgetType( "gadget_armor", 			1, 				1 );
		registerGadgetType( "gadget_resurrect", 		1, 				1 );
		registerGadgetType( "gadget_clone", 			1, 				1 );
		//registerGadgetType( "hero_bowlauncher", 		1, 				1 );
		//registerGadgetType( "hero_gravityspikes", 	1, 				1 );
		//registerGadgetType( "hero_lightninggun", 		1, 				1 );
		//registerGadgetType( "hero_pineapplegun", 		1, 				1 );
		//registerGadgetType( "hero_flamethrower", 		1, 				1 );
		//registerGadgetType( "hero_minigun", 			1, 				1 );
		//registerGadgetType( "hero_annihilator", 		1, 				1 );
		//registerGadgetType( "hero_chemicalgelgun", 	1, 				1 );
		//registerGadgetType( "hero_armblade", 			1, 				1 );
	}
}

function gadget_roulette_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self GadgetIsActive( slot );
}

function gadget_roulette_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_roulette_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_roulette_flicker( slot, weapon );
}

function gadget_roulette_on_give( slot, weapon )
{
	// setup up stuff on player spawned
	self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_DEFAULT );
	
	// executed when gadget is added to the players inventory
	
	if ( SessionModeIsMultiplayerGame() )
	{
		self.isRoulette = true;
	}
}

function gadget_roulette_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
}

//self is the player
function gadget_roulette_on_connect()
{
	// setup up stuff on player connect
	roulette_init_allow_spin();
}

function roulette_init_allow_spin()
{
	if ( self.isRoulette === true )
	{
		if ( !isdefined( self.pers[#"rouletteAllowSpin"] ) )
		{
			self.pers[#"rouletteAllowSpin"] = true;
		}
	}
}

function gadget_roulette_on_player_spawn()
{
	roulette_init_allow_spin();
}

function watch_entity_shutdown()
{
}

function gadget_roulette_on_activate( slot, weapon )
{
	gadget_roulette_give_earned_specialist( weapon, true );
}

function gadget_roulette_is_ready( slot, weapon )
{
	if ( self GadgetIsActive( slot ) )
		return;
	gadget_roulette_give_earned_specialist( weapon, false );
}

function gadget_roulette_give_earned_specialist( weapon, playSound )
{
	self giveRandomWeapon( weapon, true );
	
	if( playSound )
	{
		self playsoundtoplayer ("mpl_bm_specialist_roulette", self);
	}

	// self thread disable_hero_gadget_activation( GetDvarFloat( "src_roulette_activation_wait", ROULETTE_ACTIVATION_WAIT ) );

	self thread watchGadgetActivated( weapon );
	self thread watchRespin( weapon );
}

function disable_hero_gadget_activation( duration )
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "roulette_respin_activate" );
	
	self DisableOffhandSpecial();
	
	wait duration;
	
	self EnableOffhandSpecial();
}

function watchRespinGadgetActivated()
{
	self endon( "watchRespinGadgetActivated" );
	self endon( "death" );
	self endon( "disconnect" );
	
	self waittill( "hero_gadget_activated" );
	
	self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_DEFAULT );
}


function watchRespin( weapon )
{
	self endon( "hero_gadget_activated" );
	
	self notify( "watchRespin" );
	self endon( "watchRespin" );
	
	if ( !isdefined( self.pers[#"rouletteAllowSpin"] ) || self.pers[#"rouletteAllowSpin"] == false )
	{
		return;
	}
	
	self thread watchRespinGadgetActivated();
	
	self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_WAIT_FOR_RESPIN );

	wait GetDvarFloat( "scr_roulette_pre_respin_wait_time", ROULETTE_PRE_RESPIN_WAIT_TIME ); // wait until the "respin activated" animation is done
	
	//respinTime = ROULETTE_RESPIN_TIME_SECONDS;

	while( 1 )
	{
		if ( !isdefined( self ) )
			break;
		
		if ( self dpad_left_pressed() )
		{
			self.pers[#"rouletteWeapon"] = undefined;
			self giveRandomWeapon( weapon, false );
			self.pers[#"rouletteAllowSpin"] = false;
			
			self notify( "watchRespinGadgetActivated" );
			self notify( "roulette_respin_activate" );
			self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_SPINNING );
			self playsoundtoplayer ("mpl_bm_specialist_roulette", self);
			self thread reset_roulette_state_to_default();
			
			// self DisableOffhandSpecial();
			// self thread failsafe_reenable_offhand_special();
			
			// wait GetDvarFloat( "src_roulette_respin_activation_wait", ROULETTE_RESPIN_ACTIVATION_WAIT );
			
			// if ( isdefined( self ) )
			// {
			// 	self notify( "end_failsafe_reenable_offhand_special" );
			//	self EnableOffhandSpecial();
			//}
			break;
		}
		
		WAIT_SERVER_FRAME;
		
		//respinTime -= SERVER_FRAME;
	}
	
	if ( isdefined( self ) )
	{
		self notify( "watchRespinGadgetActivated" );
	}
}

function failsafe_reenable_offhand_special()
{
	self endon( "end_failsafe_reenable_offhand_special" );
	
	wait 3.0;
	
	if ( isdefined( self ) )
	{
		self EnableOffhandSpecial();
	}
}

function reset_roulette_state_to_default()
{
	self endon( "death" );
	self endon( "disconnect" );

	wait( 0.50 );
	self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_DEFAULT );
}

function watchGadgetActivated( weapon )
{
	self endon( "death" );
	
	self notify( "watchGadgetActivated" );
	self endon ( "watchGadgetActivated" );
	
	self waittill( "hero_gadget_activated" );

	self.pers[#"rouletteAllowSpin"] = true;
	
	if ( isdefined( weapon ) || weapon.name != "gadget_roulette" )
	{
		self clientfield::set_to_player( "roulette_state", ROULETTE_STATE_DEFAULT );
	}
}

function giveRandomWeapon( weapon, isPrimaryRoll )
{
	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( isdefined( self._gadgets_player[i] ) )
		{
			self TakeWeapon( self._gadgets_player[i] );
		}
	}

	randomWeapon = weapon;
	
	if ( isdefined( self.pers[#"rouletteWeapon"] ) )
	{
		randomWeapon = self.pers[#"rouletteWeapon"];
	}
	else if ( isdefined( self.pers[#"previousRouletteWeapon1"] ) || isdefined( self.pers[#"previousRouletteWeapon2"] ) )
	{
		randomWeapon = getRandomGadget( isPrimaryRoll );
		while ( randomWeapon == self.pers[#"previousRouletteWeapon1"] || 
		       ( isdefined( self.pers[#"previousRouletteWeapon2"] ) && randomWeapon == self.pers[#"previousRouletteWeapon2"] ) )
		{
			randomWeapon = getRandomGadget( isPrimaryRoll );
		}
	}
	else
	{
		randomWeapon = getRandomGadget( isPrimaryRoll );
	}

	if ( isdefined( level.playGadgetReady ) && !isPrimaryRoll )
	{
		// The standard 'gadget ready' callbacks trigger the dialog just fine for roulette
		self thread [[level.playGadgetReady]]( randomWeapon, !isPrimaryRoll );
	}
	
	self thread gadget_roulette_on_deactivate_helper( weapon );
	
	self GiveWeapon( randomWeapon );
	
	self.pers[#"rouletteWeapon"] = randomWeapon;
	self.pers[#"previousRouletteWeapon2"] = self.pers[#"previousRouletteWeapon1"];
	self.pers[#"previousRouletteWeapon1"] = randomWeapon;
}

function gadget_roulette_on_deactivate( slot, weapon )
{
	thread gadget_roulette_on_deactivate_helper( weapon );
}

function gadget_roulette_on_deactivate_helper( weapon )
{
	self notify( "gadget_roulette_on_deactivate_helper" );
	self endon( "gadget_roulette_on_deactivate_helper" );

	self waittill( "heroAbility_off", weapon_off );
	if ( isdefined( weapon_off ) && ( weapon_off.name == "gadget_speed_burst" ) )
	{
		self waittill( "heroAbility_off", weapon_off );
	}
	for ( i = GADGET_HELD_0; i < GADGET_HELD_COUNT; i++ )
	{
		if ( isdefined( self ) && isdefined( self._gadgets_player[i] ) )
		{
			self TakeWeapon( self._gadgets_player[i] );
		}
	}

	if ( isdefined( self ) )
	{
		self GiveWeapon( level.gadget_roulette );
		self.pers[#"rouletteWeapon"] = undefined;
	}
}

function gadget_roulette_flicker( slot, weapon )
{
}

function set_gadget_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Gadget Roulette: " + status + timeStr );
}

function dpad_left_pressed()
{
	return self ActionSlotThreeButtonPressed();
}

function getRandomGadget( isPrimaryRoll )
{
	if ( isprimaryroll )
	{
		category = PRIMARY_CATEGORY;
		totalCategory = PRIMARY_CATEGORY_TOTAL;
	}
	else
	{
		category =SECONDARY_CATEGORY;
		totalCategory = SECONDARY_CATEGORY_TOTAL;
	}
	
	randomGadgetNumber = randomIntRange( 1, level.gadgetRouletteProbabilities[totalCategory] + 1 );
	gadgetNames = GetArrayKeys( level.gadgetRouletteProbabilities );
	
	
	selectedGadget = "";
	foreach( gadget in gadgetNames )
	{
		randomGadgetNumber -= level.gadgetRouletteProbabilities[gadget][category];
		if ( randomgadgetnumber <= 0 )
		{
			selectedGadget = gadget;
			break;
		}
	}
	return selectedGadget;
}

function registerGadgetType( gadgetNameString, primaryWeight, secondaryWeight )
{
	gadgetWeapon = GetWeapon( gadgetNameString );
	assert( isdefined( gadgetWeapon ) );
	if ( gadgetWeapon == level.weaponNone) 
	{
		assertmsg( gadgetNameString + " is not a gadget, _gadget_roulette.gsc" );
	}
	
	if ( !isdefined(level.gadgetRouletteProbabilities[gadgetWeapon]) )
	{
		level.gadgetRouletteProbabilities[gadgetWeapon] = [];
	}
	
	level.gadgetRouletteProbabilities[gadgetWeapon][PRIMARY_CATEGORY] = primaryWeight;
	level.gadgetRouletteProbabilities[gadgetWeapon][SECONDARY_CATEGORY] = secondaryWeight;
	
	level.gadgetRouletteProbabilities[PRIMARY_CATEGORY_TOTAL] += primaryWeight;
	level.gadgetRouletteProbabilities[SECONDARY_CATEGORY_TOTAL] += secondaryWeight;
}
