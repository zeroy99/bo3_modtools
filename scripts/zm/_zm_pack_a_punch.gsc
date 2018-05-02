#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_PERK_PACKAPUNCH" );
#precache( "string", "ZOMBIE_PERK_PACKAPUNCH_AAT" );
#precache( "triggerstring", "ZOMBIE_GET_UPGRADED_FILL" );

#define PAP_WEAPON_KNUCKLE_CRACK		"zombie_knuckle_crack"

#define PAP_INITIAL_PIECE	0
#define PAP_PACKING_PIECE	1
#define PAP_FLAG_PIECE		2
#define PAP_WEAPON_PIECE	3
#define PAP_POWERED_PIECE	4
#define PAP_TELEPORT_PIECE 		5

REGISTER_SYSTEM_EX( "zm_pack_a_punch", &__init__, &__main__, undefined )
	
function __init__()
{
	zm_pap_util::init_parameters();
	clientfield::register( "zbarrier",	 	"pap_working_FX", 		VERSION_DLC1, 1, "int" );
}

function __main__()
{
	if ( !isdefined( level.pap_zbarrier_state_func ) )
	{
		level.pap_zbarrier_state_func = &process_pap_zbarrier_state;
	}
	
		
	// Spawn models, triggers, clip, etc.
	spawn_init();
	
	vending_weapon_upgrade_trigger = zm_pap_util::get_triggers();
	
	if ( vending_weapon_upgrade_trigger.size >= 1 )
	{
		array::thread_all( vending_weapon_upgrade_trigger, &vending_weapon_upgrade );
	}
	
	// Add old style pack machines if necessary.
	old_packs = GetEntArray( "zombie_vending_upgrade", "targetname" );
	for( i = 0; i < old_packs.size; i++ )
	{
		vending_weapon_upgrade_trigger[vending_weapon_upgrade_trigger.size] = old_packs[i];
	}
	level flag::init("pack_machine_in_use");
}

function private spawn_init()
{
	zbarriers = GetEntArray("zm_pack_a_punch", "targetname");
	
	for ( i = 0; i < zbarriers.size; i++ )
	{
		if ( !zbarriers[i] IsZbarrier() )
		{
			continue;
		}

		// Create the use trigger.
		if (!IsDefined (level.pack_a_punch.interaction_height) )
		{
			level.pack_a_punch.interaction_height = 35;
		}
		if (!IsDefined (level.pack_a_punch.interaction_trigger_radius) )
		{
			level.pack_a_punch.interaction_trigger_radius = 40; //You cannot create a trigger with a radius smaller than 40
		}
		if (!IsDefined (level.pack_a_punch.interaction_trigger_height) )
		{
			level.pack_a_punch.interaction_trigger_height = 70;
		}
		use_trigger = Spawn( "trigger_radius_use", zbarriers[i].origin + (0, 0, level.pack_a_punch.interaction_height), 0, level.pack_a_punch.interaction_trigger_radius, level.pack_a_punch.interaction_trigger_height );
		use_trigger.script_noteworthy = "pack_a_punch";
		use_trigger TriggerIgnoreTeam();
		use_trigger thread pap_trigger_hintstring_monitor();

		use_trigger flag::init( "pap_offering_gun" ); // Flag that tracks when PaP is offering a gun
		
		// Create the collision model.
		collision = Spawn("script_model", zbarriers[i].origin, 1);
		collision.angles = zbarriers[i].angles;
		collision SetModel( "zm_collision_perks1" );
		collision.script_noteworthy = "clip";
		collision DisconnectPaths();

		// Connect all of the pieces for easy access.
		use_trigger.clip = collision;
		use_trigger.zbarrier = zbarriers[i];

		// Set up sounds
		use_trigger.script_sound = "mus_perks_packa_jingle";
		use_trigger.script_label = "mus_perks_packa_sting";
		use_trigger.longJingleWait = true;

		// Connect the trigger to the machine.
		use_trigger.target = "vending_packapunch";
		use_trigger.zbarrier.targetname = "vending_packapunch";

		// Set up power interactions.
		powered_on = get_start_state();
		use_trigger.powered = zm_power::add_powered_item( &turn_on, &turn_off, &get_range, &cost_func, ANY_POWER, powered_on, use_trigger );
		
		if ( IsDefined( level.pack_a_punch.custom_power_think ) )
		{
			use_trigger thread [[level.pack_a_punch.custom_power_think]]( powered_on );
		}
		else
		{
			use_trigger thread toggle_think( powered_on );
		}		

		ARRAY_ADD( level.pack_a_punch.triggers, use_trigger );
					
	}
}

function private pap_trigger_hintstring_monitor()
{
	level endon( "Pack_A_Punch_off" );
	level waittill( "Pack_A_Punch_on" );
	
	self thread pap_trigger_hintstring_monitor_reset();
	
	while( true )
	{
		foreach( e_player in level.players )
		{
			if ( e_player istouching( self ) )
		    {
				self zm_pap_util::update_hint_string( e_player );
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}

function private pap_trigger_hintstring_monitor_reset()
{
	level waittill( "Pack_A_Punch_off" );
	
	self thread pap_trigger_hintstring_monitor();
}

function private third_person_weapon_upgrade( current_weapon, upgrade_weapon, packa_rollers, pap_machine, trigger )
{
	level endon("Pack_A_Punch_off");

	trigger endon("pap_player_disconnected");

	current_weapon = self GetBuildKitWeapon( current_weapon, false );
	upgrade_weapon = self GetBuildKitWeapon( upgrade_weapon, true );

	trigger.current_weapon = current_weapon;
	trigger.current_weapon_options = self GetBuildKitWeaponOptions( trigger.current_weapon );
	trigger.current_weapon_acvi = self GetBuildKitAttachmentCosmeticVariantIndexes( trigger.current_weapon, false );

	trigger.upgrade_weapon = upgrade_weapon;
	upgrade_weapon.pap_camo_to_use = zm_weapons::get_pack_a_punch_camo_index( upgrade_weapon.pap_camo_to_use );
	trigger.upgrade_weapon_options = self GetBuildKitWeaponOptions( trigger.upgrade_weapon, upgrade_weapon.pap_camo_to_use );
	trigger.upgrade_weapon_acvi = self GetBuildKitAttachmentCosmeticVariantIndexes( trigger.upgrade_weapon, true );

	trigger.zbarrier SetWeapon( trigger.current_weapon );
	trigger.zbarrier SetWeaponOptions( trigger.current_weapon_options );
	trigger.zbarrier SetAttachmentCosmeticVariantIndexes( trigger.current_weapon_acvi );

	trigger.zbarrier set_pap_zbarrier_state( "take_gun" );

	rel_entity = trigger.pap_machine;
	
	origin_offset = (0,0,0);
	angles_offset = (0,0,0);
	origin_base = self.origin;
	angles_base = self.angles;
	
	if( isDefined(rel_entity) )
	{
		origin_offset = (0, 0, level.pack_a_punch.interaction_height);
		angles_offset = (0, 90, 0);
		
		origin_base = rel_entity.origin;
		angles_base = rel_entity.angles;
	}
	else
	{
		rel_entity = self;
	}
	forward = anglesToForward( angles_base+angles_offset );
	interact_offset = origin_offset+(forward*-25);
	
	offsetdw = ( 3, 3, 3 );

	pap_machine [[ level.pack_a_punch.move_in_func ]]( self, trigger, origin_offset, angles_offset );
	
	self playsound( "zmb_perks_packa_upgrade" );
	wait( 0.35 );

	wait( 3 );

	trigger.zbarrier SetWeapon( upgrade_weapon );
	trigger.zbarrier SetWeaponOptions( trigger.upgrade_weapon_options );
	trigger.zbarrier SetAttachmentCosmeticVariantIndexes( trigger.upgrade_weapon_acvi );

	trigger.zbarrier set_pap_zbarrier_state( "eject_gun" );

	if ( IsDefined( self ) )
	{
		self playsound( "zmb_perks_packa_ready" );
	}
	else
	{
		return;		// player disconnected.  Get gone.
	}

	rel_entity thread [[ level.pack_a_punch.move_out_func ]]( self, trigger, origin_offset, interact_offset );
}


function private can_pack_weapon( weapon )
{
	if ( weapon.isriotshield )
	{
		return false;
	}

	if ( level flag::get("pack_machine_in_use") )
	{
		return true;
	}

	if( !IS_TRUE( level.b_allow_idgun_pap ) && isdefined( level.idgun_weapons ) )
	{
		if ( IsInArray( level.idgun_weapons, weapon ) )
			return false; 
	}

	weapon = self zm_weapons::get_nonalternate_weapon( weapon );
	if ( !zm_weapons::is_weapon_or_base_included( weapon ) )
	{
		return false;
	}

	if ( !self zm_weapons::can_upgrade_weapon( weapon ) )
	{
		return false;
	}

	return true;
}

function private player_use_can_pack_now()
{
	if ( self laststand::player_is_in_laststand() || IS_TRUE( self.intermission ) || self isThrowingGrenade() )
	{
		return false;
	}

	if( !self zm_magicbox::can_buy_weapon() || self bgb::is_enabled( "zm_bgb_disorderly_combat" ) )
	{
		return false;
	}

	if( self zm_equipment::hacker_active() )
	{
		return false;
	}

	current_weapon = self GetCurrentWeapon();
	if ( !self can_pack_weapon( current_weapon ) && !zm_weapons::weapon_supports_aat( current_weapon ) )
	{
		return false;
	}

	return true;
}

function private pack_a_punch_machine_trigger_think()
{
	self endon("death");
	self endon("Pack_A_Punch_off");
	self notify( "pack_a_punch_trigger_think" );
	self endon( "pack_a_punch_trigger_think" );
	
	while(1)
	{
		players = GetPlayers();
		
		for(i = 0; i < players.size; i ++)
		{
			if ( ( IsDefined( self.pack_player ) && self.pack_player != players[i] ) ||
			    !players[i] player_use_can_pack_now() || players[i] bgb::is_active("zm_bgb_ephemeral_enhancement") )
			{
				self SetInvisibleToPlayer( players[i], true );
			}
			else
			{
				self SetInvisibleToPlayer( players[i], false );
			}		
		}
		wait(0.1);
	}
}

//
//	Pack-A-Punch Weapon Upgrade
//
function private vending_weapon_upgrade()
{
	level endon("Pack_A_Punch_off");

	pap_machine = GetEnt( self.target, "targetname" );
	self.pap_machine = pap_machine;
	pap_machine_sound = GetEntarray ( "perksacola", "targetname");
	packa_rollers = spawn("script_origin", self.origin);
	packa_timer = spawn("script_origin", self.origin);
	packa_rollers LinkTo( self );
	packa_timer LinkTo( self );

	self UseTriggerRequireLookAt();
	self SetHintString( &"ZOMBIE_NEED_POWER" );
	self SetCursorHint( "HINT_NOICON" );
	
	power_off = !self is_on();

	if ( power_off )
	{
		pap_array = [];
		pap_array[0] = pap_machine;
		level waittill("Pack_A_Punch_on");
	}
	
	self TriggerEnable( true );
	
	if( IsDefined( level.pack_a_punch.power_on_callback ) )
	{
		pap_machine thread [[ level.pack_a_punch.power_on_callback ]]();
	}
	
	self thread pack_a_punch_machine_trigger_think();
	
	//self thread zm_magicbox::decide_hide_show_hint("Pack_A_Punch_off");
	
	pap_machine playloopsound("zmb_perks_packa_loop");
	self thread shutOffPAPSounds( pap_machine, packa_rollers, packa_timer );

	self thread vending_weapon_upgrade_cost();
	
	for( ;; )
	{
		self.pack_player = undefined;
		
		self waittill( "trigger", player );	

		if ( isdefined(pap_machine.state) && (pap_machine.state == "leaving") )
		{
			continue; //prevents player from using a PaP machine that is in the process of teleporting away
		}
				
		index = zm_utility::get_player_index(player);	

		current_weapon = player getCurrentWeapon();

		current_weapon = player zm_weapons::switch_from_alt_weapon( current_weapon );
		
		if( IsDefined( level.pack_a_punch.custom_validation ) )
 		{
 			valid = self [[ level.pack_a_punch.custom_validation ]]( player );
 			if( !valid )
 			{
 				continue;
 			}
 		}
		
		if( !player zm_magicbox::can_buy_weapon() ||
			player laststand::player_is_in_laststand() ||
			IS_TRUE( player.intermission ) ||
			player isThrowingGrenade() ||
			(!player zm_weapons::can_upgrade_weapon( current_weapon ) && !zm_weapons::weapon_supports_aat( current_weapon )) )
		{
			wait( 0.1 );
			continue;
		}

 		if( player isSwitchingWeapons() )
 		{		
			wait( 0.1 );
	 		if( player isSwitchingWeapons() )
	 			continue;
 		}

 		if ( !zm_weapons::is_weapon_or_base_included( current_weapon ) )
 		{
			continue;
 		}

 		current_cost = self.cost;
 		player.restore_ammo = undefined;
 		player.restore_clip = undefined;
 		player.restore_stock = undefined;
		player_restore_clip_size = undefined;
 		player.restore_max = undefined; 
 		
 		b_weapon_supports_aat = zm_weapons::weapon_supports_aat( current_weapon );
 		isRepack = false;
 		currentAATHashID = -1;
 		if ( b_weapon_supports_aat )
 		{
	 		current_cost = self.aat_cost;
	 		currentAAT = player aat::getAATOnWeapon(current_weapon);
	 		if (isDefined(currentAAT))
	 		{
	 			currentAATHashID = currentAAT.hash_id;		
	 		}
	 		player.restore_ammo = true;
	 		player.restore_clip = player GetWeaponAmmoClip( current_weapon );
	 		player.restore_clip_size = current_weapon.clipSize;
	 		player.restore_stock = player Getweaponammostock( current_weapon );
	 		player.restore_max = current_weapon.maxAmmo;
	 		isRepack = true;
 		}

		// If the persistent upgrade "double_points" is active, the cost is halved
		if( player zm_pers_upgrades_functions::is_pers_double_points_active() )
		{
			current_cost = player zm_pers_upgrades_functions::pers_upgrade_double_points_cost( current_cost );
		}
				
		if( !player zm_score::can_player_purchase( current_cost ) )
		{
			self playsound("zmb_perks_packa_deny");
			if(isDefined(level.pack_a_punch.custom_deny_func))
			{
				player [[level.pack_a_punch.custom_deny_func]]();
			}
			else
			{
				player zm_audio::create_and_play_dialog( "general", "outofmoney", 0 );
			}
			continue;
		}
		
		self.pack_player = player;
		level flag::set("pack_machine_in_use");
		
		demo::bookmark( "zm_player_use_packapunch", gettime(), player );

		//stat tracking
		player zm_stats::increment_client_stat( "use_pap" );
		player zm_stats::increment_player_stat( "use_pap" );
		weaponIdx = undefined;
		if (isDefined(current_weapon))
		{
			weaponIdx = MatchRecordGetWeaponIndex(current_weapon);
		}
		
		if (isDefined(weaponIdx))
		{
			if (!isRepack)
			{
				player RecordMapEvent(ZM_MAP_EVENT_PAP_USED, GetTime(), player.origin, level.round_number, weaponIdx, current_cost);
				player zm_stats::increment_challenge_stat( "ZM_DAILY_PACK_5_WEAPONS" );
				player zm_stats::increment_challenge_stat( "ZM_DAILY_PACK_10_WEAPONS" );
			}
			else
			{
				player RecordMapEvent(ZM_MAP_EVENT_PAP_REPACK_USED, GetTime(), player.origin, level.round_number, weaponIdx, currentAATHashID);
				player zm_stats::increment_challenge_stat( "ZM_DAILY_REPACK_WEAPONS" );
			}
		}
		self thread destroy_weapon_in_blackout(player);

		player zm_score::minus_to_player_score( current_cost ); 
//		sound = "evt_bottle_dispense";
//		playsoundatposition(sound, self.origin);
		
		self thread zm_audio::sndPerksJingles_Player(1);
		player zm_audio::create_and_play_dialog( "general", "pap_wait" );
		
		self TriggerEnable( false );
		
		player thread do_knuckle_crack();

		// Remember what weapon we have.  This is needed to check unique weapon counts.
		self.current_weapon = current_weapon;
		
		upgrade_weapon = zm_weapons::get_upgrade_weapon( current_weapon, b_weapon_supports_aat );
											
		player third_person_weapon_upgrade( current_weapon, upgrade_weapon, packa_rollers, pap_machine, self );
		
		self TriggerEnable( true );
		self SetCursorHint("HINT_WEAPON", upgrade_weapon);
		self flag::set( "pap_offering_gun" );
		if ( IsDefined( player ) )
		{
			self setinvisibletoall();
			self setvisibletoplayer( player );
		
			self thread wait_for_player_to_take( player, current_weapon, packa_timer, b_weapon_supports_aat, isRepack );
			
			self thread wait_for_timeout( current_weapon, packa_timer,player, isRepack );
			
			self util::waittill_any( "pap_timeout", "pap_taken", "pap_player_disconnected" );
		}
		else
		{
			self wait_for_timeout( current_weapon, packa_timer, player, isRepack );
		}


		self.zbarrier set_pap_zbarrier_state( "powered" );
		
		
		self SetCursorHint("HINT_NOICON");
		self.current_weapon = level.weaponNone;
		
		self flag::clear( "pap_offering_gun" );
		
		self thread pack_a_punch_machine_trigger_think(); // immediately reassess visibility

		self.pack_player = undefined;
		level flag::clear("pack_machine_in_use");

	}
}

function private shutOffPAPSounds( ent1, ent2, ent3 )
{
	while(1)
	{
		level waittill( "Pack_A_Punch_off" );
		level thread turnOnPAPSounds( ent1 );
		ent1 stoploopsound( .1 );
		ent2 stoploopsound( .1 );
		ent3 stoploopsound( .1 );
	}
}

function private turnOnPAPSounds( ent )
{
	level waittill( "Pack_A_Punch_on" );
	ent playloopsound( "zmb_perks_packa_loop" );
}

function private vending_weapon_upgrade_cost()
{
	level endon("Pack_A_Punch_off");
	while ( 1 )
	{
		self.cost = 5000;
		self.aat_cost = 2500;
		level waittill( "powerup bonfire sale" );

		self.cost = 1000;
		self.aat_cost = 500;
		level waittill( "bonfire_sale_off" );
	}
}

function private wait_for_player_to_take( player, weapon, packa_timer, b_weapon_supports_aat, isRepack )
{
	current_weapon = self.current_weapon;
	upgrade_weapon = self.upgrade_weapon;
	Assert( IsDefined( current_weapon ), "wait_for_player_to_take: weapon does not exist" );
	Assert( IsDefined( upgrade_weapon ), "wait_for_player_to_take: upgrade_weapon does not exist" );

	self endon( "pap_timeout" );
	level endon( "Pack_A_Punch_off" );
	
	while ( IsDefined( player ) )
	{
		packa_timer playloopsound( "zmb_perks_packa_ticktock" );
		self waittill( "trigger", trigger_player );
		if ( level.pack_a_punch.grabbable_by_anyone )
		{
			player = trigger_player;
		}
		
		packa_timer stoploopsound(.05);
		if( trigger_player == player ) 
		{

			player zm_stats::increment_client_stat( "pap_weapon_grabbed" );
			player zm_stats::increment_player_stat( "pap_weapon_grabbed" );

			current_weapon = player GetCurrentWeapon();
/#
if ( level.weaponNone == current_weapon )
{
	iprintlnbold( "WEAPON IS NONE, PACKAPUNCH RETRIEVAL DENIED" );
}
#/
			if( zm_utility::is_player_valid( player ) && 
				!IS_DRINKING(player.is_drinking) && 
				!zm_utility::is_placeable_mine( current_weapon )  && 
				!zm_equipment::is_equipment( current_weapon ) && 
			    !player zm_utility::is_player_revive_tool(current_weapon) && 
				level.weaponNone!= current_weapon  && 
				!player zm_equipment::hacker_active())
			{
				demo::bookmark( "zm_player_grabbed_packapunch", gettime(), player );

				self notify( "pap_taken" );
				player notify( "pap_taken" );
				player.pap_used = true;

				weapon_limit = zm_utility::get_player_weapon_limit( player );

				player zm_weapons::take_fallback_weapon();

				primaries = player GetWeaponsListPrimaries();
				if( isDefined( primaries ) && primaries.size >= weapon_limit )
				{
					upgrade_weapon = player zm_weapons::weapon_give( upgrade_weapon );
				}
				else
				{
					upgrade_weapon = player zm_weapons::give_build_kit_weapon( upgrade_weapon );
					player GiveStartAmmo( upgrade_weapon );
				}
				player notify( "weapon_give", upgrade_weapon );

				aatID = -1;
				if ( IS_TRUE( b_weapon_supports_aat ) )
				{
					player thread aat::acquire( upgrade_weapon );
					aatObj = player aat::getAATOnWeapon(upgrade_weapon);
					if (isDefined(aatObj))
					{
						aatID = aatObj.hash_id;
					}
				}
				else
				{
					player thread aat::remove( upgrade_weapon );
				}
				
				weaponIdx = undefined;
				if (isDefined(weapon))
				{
					weaponIdx = MatchRecordGetWeaponIndex(weapon);
				}
				
				if (isDefined(weaponIdx))
				{
					if (!isRepack)
					{
						player RecordMapEvent(ZM_MAP_EVENT_PAP_GRABBED, GetTime(), player.origin, level.round_number, weaponIdx, aatID);
					}
					else
					{
						player RecordMapEvent(ZM_MAP_EVENT_PAP_REPACK_GRABBED, GetTime(), player.origin, level.round_number, weaponIdx, aatID);
					}
				}
				
				player SwitchToWeapon( upgrade_weapon );

				if (IS_TRUE(player.restore_ammo))
				{
					new_clip = player.restore_clip + ( upgrade_weapon.clipSize - player.restore_clip_size );
					new_stock = player.restore_stock + ( upgrade_weapon.maxAmmo - player.restore_max );
					player SetWeaponAmmoStock( upgrade_weapon, new_stock );
					player SetWeaponAmmoClip( upgrade_weapon, new_clip );
				}
		 		player.restore_ammo = undefined;
		 		player.restore_clip = undefined;
		 		player.restore_stock = undefined;
 				player.restore_max = undefined;
		 		player.restore_clip_size = undefined;
		 		
				player zm_weapons::play_weapon_vo(upgrade_weapon);
				return;
			}
		}
		WAIT_SERVER_FRAME;
	}
}


//	Waiting for the weapon to be taken
//
function private wait_for_timeout( weapon, packa_timer,player, isRepack )
{
	self endon( "pap_taken" );
	self endon( "pap_player_disconnected" );
	
	self thread wait_for_disconnect( player );
	
	wait( level.pack_a_punch.timeout );
	
	self notify( "pap_timeout" );
	packa_timer stoploopsound(.05);
	packa_timer playsound( "zmb_perks_packa_deny" );

	//stat tracking
	if(isDefined(player))
	{
		player zm_stats::increment_client_stat( "pap_weapon_not_grabbed" );
		player zm_stats::increment_player_stat( "pap_weapon_not_grabbed" );
		weaponIdx = undefined;
		if (isDefined(weapon))
		{
			weaponIdx = MatchRecordGetWeaponIndex(weapon);
		}
		
		if (isDefined(weaponIdx))
		{
			if (!isRepack)
			{
				player RecordMapEvent(ZM_MAP_EVENT_PAP_NOT_GRABBED, GetTime(), player.origin, level.round_number, weaponIdx);
			}
			else
			{
				aatOnWeapon = player aat::getAATOnWeapon(weapon);
				aatHash = -1;
				if (isDefined(aatOnWeapon))
				{
					aatHash = aatOnWeapon.hash_id;	
				}
				player RecordMapEvent(ZM_MAP_EVENT_PAP_REPACK_NOT_GRABBED, GetTime(), player.origin, level.round_number, weaponIdx, aatHash);
			}
		}
	}
}

function private wait_for_disconnect( player )
{
	self endon( "pap_taken" );
	self endon( "pap_timeout" );
	
	while(isdefined(player))
	{
		wait(0.1);
	}
	
	/#	println("*** PAP : User disconnected."); #/
	
	self notify( "pap_player_disconnected" );
}

function private destroy_weapon_in_blackout( player )
{		
	self endon( "pap_timeout" );
	self endon( "pap_taken" );
	self endon ("pap_player_disconnected" );

	level waittill("Pack_A_Punch_off");

	self.zbarrier set_pap_zbarrier_state( "take_gun" );

	player playlocalsound( level.zmb_laugh_alias );

	wait( 1.5 );

	self.zbarrier set_pap_zbarrier_state( "power_off" );
}



//	Weapon has been inserted, crack knuckles while waiting
//
function private do_knuckle_crack()
{
	self endon("disconnect");
	self upgrade_knuckle_crack_begin();
	
	self util::waittill_any( "fake_death", "death", "player_downed", "weapon_change_complete" );
	
	self upgrade_knuckle_crack_end();
	
}


//	Switch to the knuckles
//
function private upgrade_knuckle_crack_begin()
{
	self zm_utility::increment_is_drinking();
	
	self zm_utility::disable_player_move_states(true);

	primaries = self GetWeaponsListPrimaries();

	original_weapon = self GetCurrentWeapon();
	weapon = GetWeapon( PAP_WEAPON_KNUCKLE_CRACK );
	
	if ( original_weapon != level.weaponNone && !zm_utility::is_placeable_mine( original_weapon ) && !zm_equipment::is_equipment( original_weapon ) )
	{
		self notify( "zmb_lost_knife" );
		self TakeWeapon( original_weapon );
	}
	else
	{
		return;
	}

	self GiveWeapon( weapon );
	self SwitchToWeapon( weapon );
}

//	Anim has ended, now switch back to something
//
function private upgrade_knuckle_crack_end()
{
	self zm_utility::enable_player_move_states();
	
	weapon = GetWeapon( PAP_WEAPON_KNUCKLE_CRACK );

	// TODO: race condition?
	if ( self laststand::player_is_in_laststand() || IS_TRUE( self.intermission ) )
	{
		self TakeWeapon(weapon);
		return;
	}

	self zm_utility::decrement_is_drinking();

	self TakeWeapon(weapon);
	primaries = self GetWeaponsListPrimaries();
	if( IS_DRINKING(self.is_drinking) )
	{
		return;
	}
	else
	{
		self zm_weapons::switch_back_primary_weapon();
	}
}

function private get_range( delta, origin, radius )
{
	if (IsDefined(self.target))
	{
		paporigin = self.target.origin; 
		if( IS_TRUE( self.target.trigger_off ) )
			paporigin = self.target.realorigin;
		else if( IS_TRUE( self.target.disabled ) )
			paporigin = paporigin + ( 0, 0, 10000 );
	
		if ( DistanceSquared( paporigin, origin ) < radius * radius )
			return true;
	}
	return false;
}

function private turn_on( origin, radius )
{
	/#	println( "^1ZM POWER: PaP on\n" );	#/
	level notify( "Pack_A_Punch_on" );
}

function private turn_off( origin, radius )
{
	/#	println( "^1ZM POWER: PaP off\n" );	#/

	// NOTE: This will cause problems if there is more than one pack-a-punch machine in the level
	level notify( "Pack_A_Punch_off" );
	self.target notify( "death" );
	self.target thread vending_weapon_upgrade();
}

function private is_on() // self == PaP trigger
{
	if (isdefined(self.powered))
		return self.powered.power;
	return false;
}

function private get_start_state()
{
	if ( IS_TRUE( level.vending_machines_powered_on_at_start ) )
	{
		return true;
	}

	return false;
}

function private cost_func()
{
	if (isdefined(self.one_time_cost))
	{
		cost = self.one_time_cost;
		self.one_time_cost=undefined;
		return cost;
	}
	if (IS_TRUE(level._power_global))
		return 0;
	if (IS_TRUE(self.self_powered))
		return 0;
	return 1;
}

function private toggle_think( powered_on )
{
	if ( !powered_on )
	{
		self.zbarrier set_pap_zbarrier_state( "initial" );

		level waittill( "Pack_A_Punch_on" );
	}

	for (;;)
	{
		self.zbarrier set_pap_zbarrier_state( "power_on" );

		level waittill( "Pack_A_Punch_off" );

		self.zbarrier set_pap_zbarrier_state( "power_off" );

		level waittill( "Pack_A_Punch_on" );
	}
}

function private pap_initial()
{
	self ZBarrierPieceUseAttachWeapon( PAP_WEAPON_PIECE );

	self SetZBarrierPieceState( PAP_INITIAL_PIECE, "closed" );
}

function private pap_power_off()
{
	self SetZBarrierPieceState( PAP_INITIAL_PIECE, "closing" );
}

function private pap_power_on()
{
	self endon( "zbarrier_state_change" );

	self SetZBarrierPieceState( PAP_INITIAL_PIECE, "opening" );
	while ( self GetZBarrierPieceState( PAP_INITIAL_PIECE ) == "opening" )
	{
		WAIT_SERVER_FRAME;
	}

	self playsound( "zmb_perks_power_on" );
	
	self thread set_pap_zbarrier_state( "powered" );
}

function private pap_powered()
{
	self endon( "zbarrier_state_change" );

	self SetZBarrierPieceState( PAP_POWERED_PIECE, "closed" );
	
	if( self.classname === "zbarrier_zm_castle_packapunch" || self.classname === "zbarrier_zm_tomb_packapunch" )
	{
		self clientfield::set("pap_working_FX", 0);
	}		
	
	while ( true )
	{
		wait( randomfloatrange( 180, 1800 ) );
		self SetZBarrierPieceState( PAP_POWERED_PIECE, "opening" );

		wait( randomfloatrange( 180, 1800 ) );
		self SetZBarrierPieceState( PAP_POWERED_PIECE, "closing" );
	}
}

function private pap_take_gun()
{
	self SetZBarrierPieceState( PAP_PACKING_PIECE, "opening" );
	self SetZBarrierPieceState( PAP_FLAG_PIECE, "opening" );
	self SetZBarrierPieceState( PAP_WEAPON_PIECE, "opening" );	
	wait .1;//let the right peices be shown first
	
	if( self.classname === "zbarrier_zm_castle_packapunch" || self.classname === "zbarrier_zm_tomb_packapunch" )
	{
		self clientfield::set("pap_working_FX", 1);
	}	
}

function private pap_eject_gun()
{
	self SetZBarrierPieceState( PAP_PACKING_PIECE, "closing" );
	self SetZBarrierPieceState( PAP_FLAG_PIECE, "closing" );
	self SetZBarrierPieceState( PAP_WEAPON_PIECE, "closing" );
}

function private pap_leaving()
{
	
	self SetZBarrierPieceState( PAP_TELEPORT_PIECE, "closing" );
	do
	{
		WAIT_SERVER_FRAME;
	}
	while ( self GetZBarrierPieceState( PAP_TELEPORT_PIECE ) == "closing" );
	self SetZBarrierPieceState( PAP_TELEPORT_PIECE, "closed" );
	self notify ("leave_anim_done");
		
}

function private pap_arriving()
{
	self endon( "zbarrier_state_change" );

	self SetZBarrierPieceState( PAP_INITIAL_PIECE, "opening" );
	while ( self GetZBarrierPieceState( PAP_INITIAL_PIECE ) == "opening" )
	{
		WAIT_SERVER_FRAME;
	}

	self playsound( "zmb_perks_power_on" );

	self thread set_pap_zbarrier_state( "powered" );
	
}

function private get_pap_zbarrier_state()
{
	return self.state;
}

function private set_pap_zbarrier_state( state )
{
	for ( i = 0; i < self GetNumZBarrierPieces(); i++ )
	{
		self HideZBarrierPiece( i );
	}

	self notify( "zbarrier_state_change" );
	
	self [[level.pap_zbarrier_state_func]]( state );
}

function private process_pap_zbarrier_state( state )
{
	switch ( state )
	{
		case "initial":
			self ShowZBarrierPiece( PAP_INITIAL_PIECE );
			self thread pap_initial();
			self.state = "initial";
			break;
		case "power_off":
			self ShowZBarrierPiece( PAP_INITIAL_PIECE );
			self thread pap_power_off();
			self.state = "power_off";
			break;
		case "power_on":
			self ShowZBarrierPiece( PAP_INITIAL_PIECE );
			self thread pap_power_on();
			self.state = "power_on";
			break;
		case "powered":
			self ShowZBarrierPiece( PAP_POWERED_PIECE );
			self thread pap_powered();
			self.state = "powered";
			break;
		case "take_gun":
			self ShowZBarrierPiece( PAP_PACKING_PIECE );
			self ShowZBarrierPiece( PAP_FLAG_PIECE );
			self ShowZBarrierPiece( PAP_WEAPON_PIECE );
			self thread pap_take_gun();
			self.state = "take_gun";
			break;
		case "eject_gun":
			self ShowZBarrierPiece( PAP_PACKING_PIECE );
			self ShowZBarrierPiece( PAP_FLAG_PIECE );
			self ShowZBarrierPiece( PAP_WEAPON_PIECE );
			self thread pap_eject_gun();
			self.state = "eject_gun";
			break;
		case "leaving":
			self ShowZBarrierPiece( PAP_TELEPORT_PIECE );
			self thread pap_leaving();
			self.state = "leaving";
			break;
		case "arriving":
			self ShowZBarrierPiece( PAP_INITIAL_PIECE );
			self thread pap_arriving();
			self.state = "arriving";
			break;
		case "hidden":
			self.state = "hidden";
			break;
		default:
			if ( IsDefined( level.custom_pap_state_handler ) )
			{
				self [[ level.custom_pap_state_handler ]]( state );
			}
			break;
	}
}

////////////////////////////////////////////
//Public state change functions
////////////////////////////////////////////

function set_state_initial()//self is a zbarrier
{
		self set_pap_zbarrier_state( "initial" );
}

function set_state_leaving()//self is a zbarrier
{
		self set_pap_zbarrier_state( "leaving" );
}

function set_state_arriving()//self is a zbarrier
{
		self set_pap_zbarrier_state( "arriving" );
}

function set_state_power_on()//self is a zbarrier
{
		self set_pap_zbarrier_state( "power_on" );
}

function set_state_hidden()//self is a zbarrier
{
		self set_pap_zbarrier_state( "hidden" );
}