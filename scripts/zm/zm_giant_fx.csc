#using scripts\codescripts\struct;

#using scripts\shared\exploder_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#precache( "client_fx", "zombie/fx_glow_eye_orange" );
#precache( "client_fx", "electric/fx_elec_sparks_burst_sm_circuit_os" );
#precache( "client_fx", "electric/fx_elec_sparks_directional_orange" );
#precache( "client_fx", "electric/fx_elec_sparks_burst_sm_circuit_os" );
#precache( "client_fx", "maps/zombie/fx_zombie_light_glow_green" );
#precache( "client_fx", "maps/zombie/fx_zombie_light_glow_red" );
#precache( "client_fx", "electrical/fx_elec_wire_spark_dl_oneshot" );
#precache( "client_fx", "electric/fx_elec_sparks_burst_sm_circuit_os" );
#precache( "client_fx", "zombie/fx_glow_eye_orange" );
#precache( "client_fx", "zombie/fx_powerup_on_green_zmb" );
#precache( "client_fx", "zombie/fx_bul_flesh_head_fatal_zmb" );
#precache( "client_fx", "zombie/fx_bul_flesh_head_nochunks_zmb" );
#precache( "client_fx", "zombie/fx_bul_flesh_neck_spurt_zmb" );
#precache( "client_fx", "zombie/fx_blood_torso_explo_zmb" ); 
#precache( "client_fx", "trail/fx_trail_blood_streak" ); 	
#precache( "client_fx", "env/fire/fx_embers_falling_sm" );
#precache( "client_fx", "zombie/fx_smk_stack_burning_zmb" );
#precache( "client_fx", "electric/fx_elec_sparks_burst_sm_circuit_os" );	
#precache( "client_fx", "zombie/fx_elec_gen_idle_zmb" );
#precache( "client_fx", "zombie/fx_moon_eclipse_zmb" );	
#precache( "client_fx", "zombie/fx_clock_hand_zmb" );
#precache( "client_fx", "zombie/fx_elec_pole_terminal_zmb" );	
#precache( "client_fx", "electric/fx_elec_sparks_burst_sm_circuit_os" );	
#precache( "client_fx", "dlc0/factory/fx_elec_trap_factory" );


// load fx used by util scripts
function precache_util_fx()
{	

}

function main()
{
	precache_util_fx();
	precache_createfx_fx();
	
	disableFX = GetDvarInt( "disable_fx" );
	if( !IsDefined( disableFX ) || disableFX <= 0 )
	{
		precache_scripted_fx();
	}

	// use this array to convert a teleport_pad index to a, b, or c
	level.teleport_pad_names = [];
	level.teleport_pad_names[0] = "a";
	level.teleport_pad_names[1] = "c";
	level.teleport_pad_names[2] = "b";
	
	level thread perk_wire_fx( "pw0", "pad_0_wire", "t01" );
	level thread perk_wire_fx( "pw1", "pad_1_wire", "t11" );
	level thread perk_wire_fx( "pw2", "pad_2_wire", "t21" );

	// Threads controlling the lights on the maps in the Teleporter rooms
	level thread teleporter_map_light( 0, "t01" );
	level thread teleporter_map_light( 1, "t11" );
	level thread teleporter_map_light( 2, "t21" );
	level.map_light_receiver_on = false;
	level thread teleporter_map_light_receiver();

	level thread light_model_swap( "smodel_light_electric",				"lights_indlight_on" );
	level thread light_model_swap( "smodel_light_electric_milit",		"lights_milit_lamp_single_int_on" );
	level thread light_model_swap( "smodel_light_electric_tinhatlamp",	"lights_tinhatlamp_on" );
}

function precache_scripted_fx()
{
	level._effect["electric_short_oneshot"]			= "electrical/fx_elec_sparks_burst_sm_circuit_os";
	level._effect["switch_sparks"]					= "electric/fx_elec_sparks_directional_orange";
	
	level._effect["elec_trail_one_shot"]			= "electric/fx_elec_sparks_burst_sm_circuit_os";
	
	level._effect["zapper_light_ready"]				= "maps/zombie/fx_zombie_light_glow_green";
	level._effect["zapper_light_notready"]			= "maps/zombie/fx_zombie_light_glow_red";
	level._effect["wire_sparks_oneshot"]			= "electrical/fx_elec_wire_spark_dl_oneshot";

	level._effect["wire_spark"]						= "electric/fx_elec_sparks_burst_sm_circuit_os";

	level._effect["eye_glow"]				= "zombie/fx_glow_eye_orange";
	level._effect["headshot"]				= "zombie/fx_bul_flesh_head_fatal_zmb";
	level._effect["headshot_nochunks"]		= "zombie/fx_bul_flesh_head_nochunks_zmb";
	level._effect["bloodspurt"]				= "zombie/fx_bul_flesh_neck_spurt_zmb";

	level._effect["powerup_on"]						= "zombie/fx_powerup_on_green_zmb";

	level._effect["animscript_gib_fx"]				= "zombie/fx_blood_torso_explo_zmb"; 
	level._effect["animscript_gibtrail_fx"]			= "trail/fx_trail_blood_streak"; 	
}

function precache_createfx_fx()
{
	level._effect["a_embers_falling_sm"]			= "env/fire/fx_embers_falling_sm";
	level._effect["mp_smoke_stack"]					= "zombie/fx_smk_stack_burning_zmb";
	level._effect["mp_elec_spark_fast_random"]		= "electric/fx_elec_sparks_burst_sm_circuit_os";	
	level._effect["zombie_elec_gen_idle"]			= "zombie/fx_elec_gen_idle_zmb";
	level._effect["zombie_moon_eclipse"]			= "zombie/fx_moon_eclipse_zmb";	
	level._effect["zombie_clock_hand"]				= "zombie/fx_clock_hand_zmb";
	level._effect["zombie_elec_pole_terminal"]		= "zombie/fx_elec_pole_terminal_zmb";	
	level._effect["mp_elec_broken_light_1shot"]		= "electric/fx_elec_sparks_burst_sm_circuit_os";	
	level._effect["zapper"]							= "dlc0/factory/fx_elec_trap_factory";
}

function perk_wire_fx(notify_wait, init_targetname, done_notify )
{
	level waittill(notify_wait);
	
	players = getlocalplayers();
	for(i = 0; i < players.size;i++)
	{
		players[i] thread perk_wire_fx_client( i, init_targetname, done_notify );
	}
}

//	Actually Plays the FX along the wire
function perk_wire_fx_client( clientnum, init_targetname, done_notify )
{

	targ = struct::get(init_targetname,"targetname");
	if ( !IsDefined( targ ) )
	{
		return;
	}
	
	mover = spawn( clientnum, targ.origin, "script_model" );
	mover SetModel( "tag_origin" );	
	fx = PlayFxOnTag( clientnum, level._effect["wire_spark"], mover, "tag_origin" );
	
	playsound( 0, "tele_spark_hit", mover.origin );
	mover playloopsound( "tele_spark_loop");

	while(isDefined(targ))
	{
		if(isDefined(targ.target))
		{
		
			target = struct::get(targ.target,"targetname");
			
//			PlayFx( clientnum, level._effect["wire_spark"], mover.origin );
			mover MoveTo( target.origin, 0.1 );
			wait( 0.1 );

			targ = target;
		}
		else
		{
			break;
		}		
	}
	level notify( "spark_done" );
	mover Delete();
	
	// Link complete, light is green
	level notify( done_notify );
}


function ramp_fog_in_out()
{
	for ( localClientNum = 0; localClientNum < level.localPlayers.size; localClientNum++ )
	{
		SetLitFogBank( localClientNum, -1, 1, -1 );
		SetWorldFogActiveBank( localClientNum, 2 );	
	}

	wait( 2.5 );

	for ( localClientNum = 0; localClientNum < level.localPlayers.size; localClientNum++ )
	{
		SetLitFogBank( localClientNum, -1, 0, -1 );
		SetWorldFogActiveBank( localClientNum, 1 );	
	}
}

//
//  Replace the light models when the lights turn on and off
function light_model_swap( name, model )
{
	level waittill( "pl1" );	// Power lights on

	players = getlocalplayers();
	for ( p=0; p<players.size; p++ )
	{
		lamps = GetEntArray( p, name, "targetname" );
		for ( i=0; i<lamps.size; i++ )
		{
			lamps[i] SetModel( model );
		}
	}
}


//
//	This is some crap to get around my inability to get usable angles from a model in a prefab
function get_guide_struct_angles( ent )
{
	guide_structs = struct::get_array( "map_fx_guide_struct", "targetname" );
	if ( guide_structs.size > 0 )
	{
		guide = guide_structs[0];
		dist = DistanceSquared(ent.origin, guide.origin);
		for ( i=1; i<guide_structs.size; i++ )
		{
			new_dist = DistanceSquared(ent.origin, guide_structs[i].origin);
			if ( new_dist < dist )
			{
				guide = guide_structs[i];
				dist = new_dist;
			}
		}
		
		return guide.angles;
	}

	return (0, 0, 0);
}

//	Controls the lights on the teleporters
//		client-sided in case we do any flashing/blinking
function teleporter_map_light( index, on_msg )
{
	level waittill( "pl1" );	// power lights on

	exploder::exploder( "map_lgt_" + level.teleport_pad_names[index] + "_red" );

	// wait until it is linked
	level waittill( on_msg );

	exploder::stop_exploder( "map_lgt_" + level.teleport_pad_names[index] + "_red" );
	exploder::exploder( "map_lgt_" + level.teleport_pad_names[index] + "_green" );
	
	level thread scene::play( "fxanim_diff_engine_zone_" + level.teleport_pad_names[index] + "1", "targetname" );
	level thread scene::play( "fxanim_diff_engine_zone_" + level.teleport_pad_names[index] + "2", "targetname" );

	level thread scene::play( "fxanim_powerline_" + level.teleport_pad_names[index], "targetname" );
}

//
//	The map light for the receiver is special.  It acts differently than the teleporter lights
//
function teleporter_map_light_receiver()
{
	level waittill( "pl1" );	// power lights on

	level thread teleporter_map_light_receiver_flash();

	exploder::exploder( "map_lgt_pap_red" );

	level waittill( "pap1" );	// Pack-a-Punch On
	wait( 1.5 );	// dramatic pause

	exploder::stop_exploder( "map_lgt_pap_red" );
	exploder::stop_exploder( "map_lgt_pap_flash" );
	exploder::exploder( "map_lgt_pap_green" );
}


//
//	When the players try to link teleporters, we need to flash the light
//
function teleporter_map_light_receiver_flash()
{
	level endon( "pap1" );	// Pack-A-Punch machine is on
	level waittill( "TRf" );	// Teleporter Receiver map light flash
	
	// After you have started, then you can end when you get a stop command.
	//	Putting it after you start prevents premature stopping 
	level endon( "TRs" );		// Teleporter receiver map light stop 
	level thread teleporter_map_light_receiver_stop();
	
	exploder::stop_exploder( "map_lgt_pap_red" );
	exploder::exploder( "map_lgt_pap_flash" );
}


//
//	When you stop flashing, put the correct model back on
function teleporter_map_light_receiver_stop()
{
	level endon( "pap1" );	// Pack-A-Punch machine is on

	level waittill( "TRs" );	// teleporter receiver light stop 

	exploder::stop_exploder( "map_lgt_pap_flash" );
	exploder::exploder( "map_lgt_pap_red" );

	// listen for another flash message
	level thread teleporter_map_light_receiver_flash();
}

