#using scripts\codescripts\struct;

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
#insert scripts\shared\abilities\gadgets\_gadget_heat_wave.gsh;

#define HEATWAVE_DAMAGE_RATIO					.2
#define HEATWAVE_EFFECT_DURATION				2.5
#define HEATWAVE_GRACE_PERIOD					0
#define HEATWAVE_TRACE_Z_OFFSET					50
#define HEATWAVE_FX_HEIGHT						-30
#define HEATWAVE_DURATION						250
#define HEATWAVE_SPEED							2000
#define HEATWAVE_GLASS_DAMAGE					400
#define HEATWAVE_PROJECTILE_TRACE_Z				29

#namespace heat_wave;

REGISTER_SYSTEM( "gadget_heat_wave", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_HEAT_WAVE, &gadget_heat_wave_on_activate, &gadget_heat_wave_on_deactivate );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_HEAT_WAVE, &gadget_heat_wave_on_give, &gadget_heat_wave_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_HEAT_WAVE, &gadget_heat_wave_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_HEAT_WAVE, &gadget_heat_wave_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_HEAT_WAVE, &gadget_heat_wave_is_flickering );
	
	callback::on_connect( &gadget_heat_wave_on_connect );
	callback::on_spawned( &gadget_heat_wave_on_player_spawn );
	
	clientfield::register( "scriptmover", "heatwave_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "allplayers", "heatwave_victim", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "heatwave_activate", VERSION_SHIP, 1, "int" );
	
	if ( !IsDefined( level.vsmgr_prio_visionset_heatwave_activate ) )
	{
		level.vsmgr_prio_visionset_heatwave_activate = HEATWAVE_ACTIVATE_VISIONSET_PRIORITY;
	}
	
	if ( !IsDefined( level.vsmgr_prio_visionset_heatwave_charred ) )
	{
		level.vsmgr_prio_visionset_heatwave_charred = HEATWAVE_CHARRED_VISIONSET_PRIORITY;
	}
	
	visionset_mgr::register_info( "visionset", HEATWAVE_ACTIVATE_VISIONSET_ALIAS, VERSION_SHIP, level.vsmgr_prio_visionset_heatwave_activate, HEATWAVE_ACTIVATE_VISIONSET_STEPS, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false );
	visionset_mgr::register_info( "visionset", HEATWAVE_CHARRED_VISIONSET_ALIAS, VERSION_SHIP, level.vsmgr_prio_visionset_heatwave_charred, HEATWAVE_CHARRED_VISIONSET_STEPS, true, &visionset_mgr::ramp_in_out_thread_per_player_death_shutdown, false );
	
}

function updateDvars()
{
	while(1)
	{
		wait(1.0);
	}
}

function gadget_heat_wave_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self GadgetIsActive( slot );
}

function gadget_heat_wave_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_heat_wave_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_heat_wave_flicker( slot, weapon );
}

function gadget_heat_wave_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
}

function gadget_heat_wave_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
	self clientfield::set_to_player( "heatwave_activate", 0 );
}

//self is the player
function gadget_heat_wave_on_connect()
{
	// setup up stuff on player connec
}

function gadget_heat_wave_on_player_spawn()
{
	// setup up stuff on player spawned
	self clientfield::set( "heatwave_victim", 0 );
	self._heat_wave_stuned_end = 0;
	self._heat_wave_stunned_by = undefined;
	self thread watch_entity_shutdown();
}

function watch_entity_shutdown()
{
	self endon ( "disconnect" );
	self waittill( "death" );

	if ( self IsRemoteControlling() == false )
	{
		visionset_mgr::deactivate( "visionset", HEATWAVE_CHARRED_VISIONSET_ALIAS, self );
		visionset_mgr::deactivate( "visionset", HEATWAVE_ACTIVATE_VISIONSET_ALIAS, self );
	}
}

function gadget_heat_wave_on_activate( slot, weapon )
{
	self PlayRumbleOnEntity( "heat_wave_activate" );
	self thread toggle_activate_clientfields();
	visionset_mgr::activate( "visionset", HEATWAVE_ACTIVATE_VISIONSET_ALIAS, self, HEATWAVE_ACTIVATE_VISIONSET_RAMP_IN, HEATWAVE_ACTIVATE_VISIONSET_RAMP_HOLD, HEATWAVE_ACTIVATE_VISIONSET_RAMP_OUT );
	self thread heat_wave_think( slot, weapon );
}

function toggle_activate_clientfields()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	self clientfield::set_to_player( "heatwave_activate", 1 );
	
	util::wait_network_frame();
	
	self clientfield::set_to_player( "heatwave_activate", 0 );
}

function gadget_heat_wave_on_deactivate( slot, weapon )
{
}

function gadget_heat_wave_flicker( slot, weapon )
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
		self IPrintlnBold( "Gadget Heat Wave: " + status + timeStr );
}

function is_entity_valid( entity, heatwave )
{
	if( !IsPlayer( entity ) )
	{
		return false;
	}
	
	if( self GetEntityNumber() == entity GetEntityNumber() )
	{
		return false;
	}
	
	if ( !IsAlive( entity ) )
	{
		return false;
	}
	
	if ( !( entity util::mayApplyScreenEffect() ) )
	{	
		return false;
	}
	
	if( !heat_wave_trace_entity( entity, heatwave ) )
	{
		return false;
	}
	
	return true;
}

function heat_wave_trace_entity( entity, heatwave )
{
	entityPoint = entity.origin + ( 0, 0, HEATWAVE_TRACE_Z_OFFSET );
	if ( !BulletTracePassed( heatwave.origin, entityPoint, true, self, undefined, false, true ) ) 
	{
		return false;
	}

	return true;	
}

function heat_wave_fx_cleanup( fxOrg, direction )
{
	self util::waittill_any( "heat_wave_think", "heat_wave_think_finished" );
	if( isDefined( fxOrg ) )
	{
		fxOrg StopLoopSound();
		fxOrg PlaySound( "gdt_heatwave_dissipate" );
		fxOrg clientfield::set( "heatwave_fx", 0 );
		fxOrg delete();
	}
}

function heat_wave_fx( origin, direction )
{
	if ( direction == (0,0,0) )
	{
		direction = (0,0,1);
	}
	dirVec = VectorNormalize( direction );
	angles = VectorToAngles( dirVec );
	fxOrg = spawn( "script_model", origin+(0,0,HEATWAVE_FX_HEIGHT), 0, angles );
	fxOrg.angles = angles;
	fxOrg setowner( self );
	fxOrg SetModel( "tag_origin" );
	fxOrg clientfield::set( "heatwave_fx", 1 );
	fxOrg PlayLoopSound( "gdt_heatwave_3p_loop" );
	fxOrg.soundMod = "heatwave";
	fxOrg.hitsomething = false;
	self thread heat_wave_fx_cleanup( fxOrg, direction );
	return fxOrg;
}

function heat_wave_setup( weapon )
{
	heatwave = spawnStruct();
	heatwave.radius = weapon.gadget_shockfield_radius;
	heatwave.origin = self geteye();
	heatwave.direction = AnglesToForward( self GetPlayerAngles() );
	heatwave.up = AnglesToUp( self GetPlayerAngles() );
	heatwave.fxOrg = heat_wave_fx( heatwave.origin, heatwave.direction );
	
	return heatwave;
}

function heat_wave_think( slot, weapon )
{
	self endon( "disconnect" );
	
	self notify ( "heat_wave_think" );
	self endon( "heat_wave_think" );
	self.heroAbilityActive = true;
	heatwave = heat_wave_setup( weapon );
	
	GlassRadiusDamage( heatwave.origin, heatwave.radius, HEATWAVE_GLASS_DAMAGE, HEATWAVE_GLASS_DAMAGE, "MOD_BURNED" );
	
	self thread heat_wave_damage_entities( weapon, heatwave );
	self thread heat_wave_damage_projectiles( weapon, heatwave );
	
	wait( HEATWAVE_DURATION / 1000 );
	
	self.heroAbilityActive = false;
	
	self notify( "heat_wave_think_finished" );
}

function heat_wave_damage_entities( weapon, heatwave )
{
	self endon( "disconnect" );
	self endon( "heat_wave_think" );
	
	startTime = getTime();
	
	burnedEnemy = false;
	while( HEATWAVE_DURATION + startTime > getTime() )
	{
		entities = GetDamageableEntArray( heatwave.origin, heatwave.radius, true );
		foreach( entity in entities )
		{
			if( isDefined( entity._heat_wave_damaged_time ) && ( entity._heat_wave_damaged_time + HEATWAVE_DURATION + 1 > getTime() ) )
			{
				continue;
			}
	
			if( is_entity_valid( entity, heatwave ) )
			{
				burnedEnemy |= heat_wave_burn_entities( weapon, entity, heatwave );
			}
			else if( !isPlayer( entity ) )
			{
				entity DoDamage( 1, heatwave.origin, self, self, "none", "MOD_BURNED", 0, weapon );
				entity thread update_last_burned_by( heatwave );
			}
		}
		
		WAIT_SERVER_FRAME;
	}
	
	if ( IsAlive( self ) && IS_TRUE( burnedEnemy ) && isdefined( level.playGadgetSuccess ) )
    {
		self [[ level.playGadgetSuccess ]]( weapon, "heatwaveSuccessDelay" );
	}
}

function heat_wave_burn_entities( weapon, entity, heatwave )
{
	burn_self = false;
	burn_entity = true;
	burned_enemy = true;
	if( ( self.team == entity.team ) )
	{
		burned_enemy = false;
		switch ( level.friendlyfire )
		{
			case 0: // no FF
				burn_entity = false;
				break;
			case 1: // FF
				// burns ally
				break;
			case 2: // reflect
				burn_entity = false;
				burn_self = true;
				break;
			case 3: // share (both)
				burn_self = true;
				break;
				
		}
	}
	
	if( burn_entity )
	{
		apply_burn( weapon, entity, heatwave );
		entity thread update_last_burned_by( heatwave );
	}
	
	if( burn_self )
	{
		apply_burn( weapon, self, heatwave );
		self thread update_last_burned_by( heatwave );
	}
	
	return burned_enemy;
}

function heat_wave_damage_projectiles( weapon, heatwave )
{
	self endon( "disconnect" );
	self endon( "heat_wave_think" );
	
	owner = self;
	startTime = getTime();
	while( HEATWAVE_DURATION + startTime > getTime() )
	{
		if ( level.missileEntities.size < 1 )
		{
			WAIT_SERVER_FRAME;
			continue;
		}

		for ( index=0; index < level.missileEntities.size; index++ )
		{
			WAIT_SERVER_FRAME;
		
			grenade = level.missileEntities[index];
			
			if ( !isdefined (grenade ) )
				continue;

			if ( grenade.weapon.isTacticalInsertion )
			{
				// tagTMR<NOTE>: trophy systems will attack the scriptmover not the invisible ET_MISSILE for tac inserts
				continue;
			}

			switch( grenade.model )
			{
				case "t6_wpn_grenade_supply_projectile":
					continue;
			}
			
			if ( !isdefined( grenade.owner ) )
			{
				grenade.owner = GetMissileOwner( grenade );
			}

			if ( isdefined( grenade.owner ))
			{
				if ( level.teamBased )
				{
					if ( grenade.owner.team == owner.team )
					{
						continue;
					}
				}
				else
				{
					if ( grenade.owner == owner )
					{
						continue;
					}
				}

				grenadeDistanceSquared = DistanceSquared( grenade.origin, heatwave.origin );
			
				if ( grenadeDistanceSquared < ( heatwave.radius * heatwave.radius ))
				{
					if ( BulletTracePassed( grenade.origin, heatwave.origin + ( 0, 0, HEATWAVE_PROJECTILE_TRACE_Z ), false, owner, grenade, false, true ) )
					{
						owner projectileExplode( grenade, heatwave, weapon );
						index--;
					}
				}
			}
		}
	}
}

function projectileExplode( projectile, heatwave, weapon ) // self == trophy owning player
{
	projPosition = projectile.origin;
	playFX( level.trophyDetonationFX, projPosition );
	projectile notify ( "trophy_destroyed" );
	self RadiusDamage( projPosition, 128, 105, 10, self, "MOD_BURNED", weapon );
	projectile delete();
}


function apply_burn( weapon, entity, heatwave )
{
	damage = floor( entity.health * HEATWAVE_DAMAGE_RATIO );
	entity DoDamage( damage, self.origin + ( 0, 0, 30 ), self, heatwave.fxOrg, 0, "MOD_BURNED", 0, weapon );
	entity setdoublejumpenergy( 0 );
	entity clientfield::set( "heatwave_victim", 1 );
	visionset_mgr::activate( "visionset", HEATWAVE_CHARRED_VISIONSET_ALIAS, entity, HEATWAVE_CHARRED_VISIONSET_RAMP_IN, HEATWAVE_CHARRED_VISIONSET_RAMP_HOLD, HEATWAVE_CHARRED_VISIONSET_RAMP_OUT );
	entity thread watch_burn_clear();
	entity resetdoublejumprechargetime();
	shellshock_duration = HEATWAVE_EFFECT_DURATION;
	entity._heat_wave_stuned_end = getTime() + ( shellshock_duration * 1000 );
	DEFAULT( entity._heat_wave_stunned_by, [] );
	entity._heat_wave_stunned_by[self.clientid] = entity._heat_wave_stuned_end;
	entity shellshock( "heat_wave", shellshock_duration, true );
	entity thread heat_wave_burn_sound(shellshock_duration);
	burned = true;		
}

function watch_burn_clear()
{
	self endon ("disconnect");
	self endon ("death");
	
	util::wait_network_frame();
	
	self clientfield::set( "heatwave_victim", 0 );
}

function update_last_burned_by( heatwave )
{
	self endon ( "disconnect" );
	self endon ( "death" );
	
	self._heat_wave_damaged_time = getTime();
	
	wait( HEATWAVE_DURATION );
}

function heat_wave_burn_sound(shellshock_duration)
{
	fire_sound_ent = spawn( "script_origin", self.origin );
	fire_sound_ent linkto( self, "tag_origin", (0,0,0), (0,0,0) );
	fire_sound_ent playloopsound ("mpl_heatwave_burn_loop");
	wait( shellshock_duration );
	
	if ( isdefined( fire_sound_ent ) )
	{
		fire_sound_ent StopLoopSound( .5 );
		util::wait_network_frame();
		fire_sound_ent delete();
	}
}