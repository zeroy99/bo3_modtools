#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\flagsys_shared;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;

REGISTER_SYSTEM( "gadget_multirocket", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_MULTI_ROCKET, &gadget_multirocket_on, &gadget_multirocket_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_MULTI_ROCKET, &gadget_multirocket_on_give, &gadget_multirocket_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_MULTI_ROCKET, &gadget_multirocket_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_MULTI_ROCKET, &gadget_multirocket_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_MULTI_ROCKET, &gadget_multirocket_is_flickering );
	
	callback::on_connect( &gadget_multirocket_on_connect );
	callback::on_actor_killed( &on_target_killed );
	
	level.weaponGadgetMultirocket = GetWeapon( get_gadget_name() );
}

function get_gadget_name()
{
	return "gadget_multirocket";
}

function get_gadget_weapon()
{
	return level.weaponGadgetMultirocket;
}

function gadget_multirocket_is_inuse()
{
	// returns true when the gadget is on
	return self flagsys::get( "gadget_multirocket_on" );
}

function gadget_multirocket_is_flickering()
{
	// returns true when the gadget is flickering
	return self flagsys::get( "gadget_multirocket_flickering" );
}

function gadget_multirocket_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_multirocket_flicker( 200 );	
}

function gadget_multirocket_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory
}

function gadget_multirocket_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
}

//self is the player
function gadget_multirocket_on_connect()
{
	// setup up stuff on player connect
}

function gadget_multirocket_on( slot, weapon )
{
	// excecutes when the gadget is turned on
	self flagsys::set( "gadget_multirocket_on" );
	//self playsound( "wpn_mrocket_ui_on" );
	self thread gadget_multirocket_target_acquire();
	self thread gadget_multirocket_weapon_watcher();
	self thread gadget_multirocket_fire_watcher();
}

function gadget_multirocket_off( slot, weapon )
{
	self notify( "gadget_multirocket_off" );
	//self playsound( "wpn_mrocket_ui_off" );
	// excecutes when the gadget is turned off
	
	self thread gadget_multirocket_fire_hint_off();
	
	self flagsys::clear( "gadget_multirocket_on" );
}

function set_gadget_multirocket_flicker_status( time, status )
{
	if ( IsDefined( status ) )
	{
		statusStr = " ^3" + status;
	}

	if ( IsDefined( time ) )
	{
		timeStr = " ^3" + ", time: " + time;
	}	
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Gadget Multirocket Flicker:" + statusStr + timeStr );
}

function gadget_multirocket_flicker( eventTime )
{
	self endon( "disconnect" );

	time = GetTime();	

	if ( self flagsys::get( "gadget_multirocket_flickering" ) )
	{
		// don't queue or extend flickers
		return;
	}	

	self flagsys::set( "gadget_multirocket_flickering" );

	self._gadget_multirocket_flicker_timeout = time + eventTime;	

	self set_gadget_multirocket_flicker_status( eventTime, "I'm flickering" );

	while( 1 )
	{		
		currentTime = GetTime();		

		if ( currentTime > self._gadget_multirocket_flicker_timeout )
		{
			self._gadget_multirocket_flicker_timeout = undefined;
			self flagsys::clear( "gadget_multirocket_flickering" );
			return;
		}

		wait( 0.5 );
	}
}

function gadget_multirocket_target_acquire()  //looks for enemy ai to target
{
	self endon( "death" );
	self endon( "weapon_fired" );
	self endon( "weapon_switch_started" );
	
	n_range = self._gadgets_player.multirocketRange;
	n_max = self._gadgets_player.multirocketTargetNumber;
	n_targetRadius = self._gadgets_player.multirocketTargetRadius;
	self.n_targets_marked = 0;

	while( 1 )
	{
		if ( self GetCurrentWeapon() == get_gadget_weapon() )
		{
			a_ai_enemies = GetAITeamArray( "axis" );
			
			if ( IsDefined( a_ai_enemies ) )
			{
				a_ai_targets = ArraySort( a_ai_enemies, self.origin, true, a_ai_enemies.size, n_range );
				
				for ( i = 0; i < a_ai_targets.size; i++ )
				{
					if ( IsAlive( a_ai_targets[i] ) )
					{
						if ( a_ai_targets[i] SightConeTrace( self GetEye(), self ) && Target_IsInCircle( a_ai_targets[i], self, 65, n_targetRadius ) )
						{
							if ( !IsDefined( a_ai_targets[i].targetFXEnt ) && ( self.n_targets_marked < n_max ) )  //only mark if max targets not met
							{
								a_ai_targets[i].targetFXEnt = spawn("script_model", a_ai_targets[i].origin + (0,0,80) );
								a_ai_targets[i].targetFXEnt SetModel( "p7_proto_stealth_diamond" );
								a_ai_targets[i].targetFXEnt linkto( a_ai_targets[i] );
								
								self.n_targets_marked++;
					
								self playsoundtoplayer( "wpn_mrocket_ui_tag", self );
								
								self thread gadget_multirocket_fire_hint_on();
								wait self._gadgets_player.multirocketAcquisitionTime;
							}
						}
						else if ( IsDefined( a_ai_targets[i].targetFXEnt ) )
						{
							a_ai_targets[i].targetFXEnt Delete();  //remove target mark if out of view, range, etc...
							
							self.n_targets_marked--;
							
							if ( self.n_targets_marked < 1 )
							{
								self thread gadget_multirocket_fire_hint_off();	
							}
						}
					}
				}
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}

function gadget_multirocket_weapon_watcher()  //marked targets are cleared when the gagdget is off
{
	self flagsys::wait_till_clear( "gadget_multirocket_on" );
	
	self thread gadget_multirocket_remove_targets();
}

function gadget_multirocket_fire_watcher()  //rockets fire at marked targets
{
	self endon( "death" );
		
	while( 1 )
	{
		self waittill( "weapon_fired", weapon );
		
		if ( weapon == get_gadget_weapon() )
		{
			self thread gadget_multirocket_fire();
			self thread gadget_multirocket_remove_targets();
			self thread gadget_multirocket_fire_hint_off();
		}
	}
}

function gadget_multirocket_fire()
{
	self endon( "death" );
	
	if ( !self flagsys::get( "gadget_multirocket_on" ) )
	{
		return;	
	}
	
	a_ai_enemies = GetAITeamArray( "axis" );
	a_ai_targets = [];
	
	foreach( ai_enemy in a_ai_enemies )
	{
		if ( IsAlive( ai_enemy ) && IsDefined( ai_enemy.targetFXEnt ) )
		{
			ArrayInsert( a_ai_targets, ai_enemy, 0 );
		}
	}
	
	for ( i = 0; i < a_ai_targets.size; i++ )
	{
		if ( IsAlive( a_ai_targets[i] ) )
		{
			if ( a_ai_targets[i].origin[2] > self.origin[2] + 72 )
			{
				v_target = a_ai_targets[i].origin + (0,0,50);
			}
			
			v_target = a_ai_targets[i] GetEye();
			
			v_angles = anglestoforward(self getPlayerAngles());
			v_vec = vectorNormalize(v_angles);
			//v_launch_spot = (v_vec * 50) + (0, 0, 72) ;
			v_launch_spot = (self.origin + (0, 0, 72) ) + (v_angles * 50)  ;
			
			e_rocket = MagicBullet( "smaw_gadget_multirocket", v_launch_spot, v_target, self );
			
			if ( IsDefined( e_rocket ) )
			{
				e_rocket thread gadget_multirocket_proximity_explode( a_ai_targets[i] );
			}
		
			self thread sndFakeFire();
				
			self ability_power::power_loss_event( undefined, self._gadgets_player.multirocketFirePowerLoss, "rocket_fired" );
				
			wait self._gadgets_player.multirocketFireInterval;
		}
	}

	wait 2;  //wait a bit to allow rockets to explode	
	
	self thread gadget_multirocket_target_acquire();
}

function sndFakeFire()
{
	num = 3;
	
	for(i=0;i<num;i++)
	{
		self playsound( "wpn_mrocket_fire" );
		wait(.15);
	}
}

function gadget_multirocket_remove_targets()
{
	self.n_targets_marked = 0;
	
	a_ai_targets = GetAITeamArray( "axis" );
	
	foreach( ai_target in a_ai_targets )
	{
		if ( IsDefined( ai_target.targetFXEnt ) )
		{
			ai_target.targetFXEnt Delete();
		}	
	}
}

function on_target_killed( params )
{
	if ( IsDefined( self.targetFXEnt ) )
	{
		self.targetFXEnt Delete();
	}
}

function gadget_multirocket_fire_hint_on()
{
	if ( !IsDefined( level.hud_gadget ) )
	{
		level.hud_gadget = NewHudElem();
		level.hud_gadget.alignX = "right";
		level.hud_gadget.alignY = "middle";
		level.hud_gadget.x = 660;
		level.hud_gadget.y = 320;
		level.hud_gadget.fontscale = 2.0;
		level.hud_gadget SetText( "RT: FIRE" );
	}
}

function gadget_multirocket_fire_hint_off()
{
	if ( IsDefined( level.hud_gadget ) )
	{
		level.hud_gadget Destroy();
	}
}

function gadget_multirocket_proximity_explode( ai_target )  //self = rocket
{
	self endon( "death" );
	ai_target endon( "death" );
	
	n_dist = 85;
	
	while( Distance2DSquared( self.origin, ai_target geteye() ) > n_dist * n_dist )
	{
		WAIT_SERVER_FRAME;	
	}
	
	self Detonate();
}