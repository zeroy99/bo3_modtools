#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;


#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\weapons\_weaponobjects.gsh;

#using scripts\shared\system_shared;

#precache( "client_fx", "weapon/fx_equip_light_os" );

#namespace weaponobjects;

function init_shared()
{
	callback::on_localplayer_spawned( &on_localplayer_spawned );
	
	clientfield::register( "toplayer", "proximity_alarm", VERSION_SHIP, 2, "int", &proximity_alarm_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	clientfield::register( "missile", "retrievable", VERSION_SHIP, 1, "int", &retrievable_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "retrievable", VERSION_SHIP, 1, "int", &retrievable_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "missile", "enemyequip", VERSION_SHIP, 2, "int", &enemyequip_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "scriptmover", "enemyequip", VERSION_SHIP, 2, "int", &enemyequip_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "missile", "teamequip", VERSION_SHIP, 1, "int", &teamequip_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	level._effect[ "powerLight" ] = "weapon/fx_equip_light_os";
	
	DEFAULT(level.retrievable,[]);
	DEFAULT(level.enemyequip,[]);
}

function on_localplayer_spawned( local_client_num )
{
	if( self != GetLocalPlayer( local_client_num ) )
		return;

	self thread watch_perks_changed(local_client_num);

	self thread watch_killstreak_tap_activation( local_client_num );	
}

function watch_killstreak_tap_activation( local_client_num )
{
	self notify( "watch_killstreak_tap_activation" );
	self endon( "watch_killstreak_tap_activation" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "entityshutdown" );

	while ( IsDefined( self ) ) 
	{
		self waittill( "notetrack", note );
		if ( note == "activate_datapad" )
		{
			uimodel = CreateUIModel( GetUIModelForController( local_client_num ), "hudItems.killstreakActivated" );
			SetUIModelValue( uimodel, 1 );
		}

		if ( note == "deactivate_datapad" )
		{
			uimodel = CreateUIModel( GetUIModelForController( local_client_num ), "hudItems.killstreakActivated" );
			SetUIModelValue( uimodel, 0 );
		}
	}
}


function proximity_alarm_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	update_sound( local_client_num, bNewEnt, newVal, oldVal );	
}

function update_sound( local_client_num, bNewEnt, newVal, oldVal )
{
	if ( newVal == PROXIMITY_ALARM_ON )
	{
		if ( !IsDefined( self._proximity_alarm_snd_ent ) )
		{
			self._proximity_alarm_snd_ent = Spawn( local_client_num, self.origin, "script_origin" );
			self thread sndProxAlert_EntCleanup(local_client_num, self._proximity_alarm_snd_ent);
		}
		
		playsound( local_client_num, "uin_c4_proximity_alarm_start", (0,0,0) );
		self._proximity_alarm_snd_ent PlayLoopSound( "uin_c4_proximity_alarm_loop", .1 );
	}
	else if ( newVal == PROXIMITY_ALARM_DEPLOYED )
	{
		//playsound( local_client_num, "uin_c4_proximity_alarm_deploy", (0,0,0) );
	}
	else if( newVal == PROXIMITY_ALARM_OFF && isdefined( oldVal ) && oldVal != newVal )
	{
		playsound( local_client_num, "uin_c4_proximity_alarm_stop", (0,0,0) );
		if ( IsDefined( self._proximity_alarm_snd_ent ) )
		{
			self._proximity_alarm_snd_ent StopAllLoopSounds( 0.5 );
		}
	}
}


function teamequip_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self updateTeamEquipment( local_client_num, newVal );
}

function updateTeamEquipment( local_client_num, newVal )
{	
	self checkTeamEquipment( local_client_num );
}

function retrievable_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self util::add_remove_list( level.retrievable, newVal );
	
	self updateRetrievable( local_client_num, newVal );
}

function updateRetrievable( local_client_num, newVal )
{
	if ( IsDefined(self.owner) && self.owner == getlocalplayer( local_client_num ) )
	{
		self duplicate_render::set_item_retrievable( local_client_num, newVal );
	}
	else
	{
		if ( IsDefined(self.currentdrfilter))
			self duplicate_render::set_item_retrievable( local_client_num, false );
	}	
}

function enemyequip_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	newVal = ( newVal != ENEMY_EQUIPMENT_SHADER_OFF );
	
	self util::add_remove_list( level.enemyequip, newVal );
	
	self updateEnemyEquipment( local_client_num, newVal );
}

function updateEnemyEquipment( local_client_num, newVal )
{
	watcher = GetLocalPlayer( local_client_num );
	friend = self util::friend_not_foe( local_client_num, true ); 
	
	if ( !friend && IsDefined( watcher ) && watcher HasPerk( local_client_num, "specialty_showenemyequipment" ) )
	{
		self duplicate_render::set_item_friendly_equipment( local_client_num, false );
		self duplicate_render::set_item_enemy_equipment( local_client_num, newVal );
	}
	else if( friend && isDefined( watcher ) && watcher duplicate_render::show_friendly_outlines(local_client_num) )
	{
		self duplicate_render::set_item_enemy_equipment( local_client_num, false );
		self duplicate_render::set_item_friendly_equipment( local_client_num, newVal );
	}
	else
	{
		self duplicate_render::set_item_enemy_equipment( local_client_num, false );
		self duplicate_render::set_item_friendly_equipment( local_client_num, false );
	}
}

function equipmentDR( local_client_num )
{
}

function watch_perks_changed(local_client_num)
{
	self notify( "watch_perks_changed" );
	self endon( "watch_perks_changed" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	
	while(IsDefined(self))
	{
		WAIT_CLIENT_FRAME;
		util::clean_deleted(level.retrievable);
		util::clean_deleted(level.enemyequip);
		array::thread_all( level.retrievable, &updateRetrievable, local_client_num, 1 );
		array::thread_all( level.enemyequip, &updateEnemyEquipment, local_client_num, 1 );
		self waittill("perks_changed");
	}
}



function checkTeamEquipment( localClientNum )
{		
	if ( !isdefined( self.owner ) )
	{
		return;	
	}
	if ( !isdefined( self.equipmentOldTeam ) )
	{
		self.equipmentOldTeam = self.team;
	}
	
	if ( !isdefined( self.equipmentOldOwnerTeam ) )
	{
		self.equipmentOldOwnerTeam = self.owner.team;
	}
	
	watcher = GetLocalPlayer( localClientNum );
	
	if ( !isdefined( self.equipmentOldWatcherTeam ) )
	{
		self.equipmentOldWatcherTeam = watcher.team;
	}
	
	if ( self.equipmentOldTeam != self.team || self.equipmentOldOwnerTeam != self.owner.team || self.equipmentOldWatcherTeam != watcher.team)
	{
		self.equipmentOldTeam = self.team;
		self.equipmentOldOwnerTeam = self.owner.team;
		self.equipmentOldWatcherTeam = watcher.team;
		
		self notify( "team_changed" );		
	}
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function equipmentTeamObject( localClientNum ) 
{
	if ( IS_TRUE( level.disable_equipment_team_object ) )
	{
		return;
	}

	self endon( "entityshutdown" );	
	
	self util::waittill_dobj(localClientNum);
	
	wait( 0.05 );
	
	fx_handle = self thread playFlareFX( localClientNum );

	self thread equipmentWatchTeamFX( localClientNum, fx_handle );	
	
	self thread equipmentWatchPlayerTeamChanged( localClientNum, fx_handle );
	
	self thread equipmentDR();
}

//******************************************************************
//                                                                 *
//                                                                 *
//******************************************************************
function playFlareFX( localClientNum )  // self is the equipment entity
{
	self endon( "entityshutdown" );
	level endon( "player_switch" );
	
	if ( !isdefined( self.equipmentTagFX ) )
	{
		self.equipmentTagFX = "tag_origin";
	}
	
	if ( !isdefined( self.equipmentFriendFX ) )
	{
		self.equipmentTagFX = level._effect[ "powerLightGreen" ];
	}
	
	if ( !isdefined( self.equipmentEnemyFX ) )
	{
		self.equipmentTagFX = level._effect[ "powerLight" ];
	}
	
	if ( self util::friend_not_foe( localClientNum, true ) )
	{
		fx_handle = PlayFXOnTag( localClientNum, self.equipmentFriendFX, self, self.equipmentTagFX );
	}
	else
	{
		fx_handle = PlayFXOnTag( localClientNum, self.equipmentEnemyFX, self, self.equipmentTagFX );
	}

	return fx_handle;	
}

//******************************************************************
//	equipmentWatchTeamFX                                           *
//	handles notifies that may cause the FX to change               *
//******************************************************************
function equipmentWatchTeamFX( localClientNum, fxHandle ) // self is the equipment entity
{
	msg = self util::waittill_any_return( "entityshutdown", "team_changed", "player_switch" );
	
	if ( isdefined( fxHandle ) )
	{
		stopFx( localClientNum, fxHandle );
	}
	
	waittillframeend;

	if ( msg != "entityshutdown" && isdefined( self ) )
	{
		self thread equipmentTeamObject( localClientNum );
	}
}

//*****************************************************************
//	equipmentWatchPlayerTeamChanged                               *
//	handles the player changing teams and notifies the equipment  *
//*****************************************************************
function equipmentWatchPlayerTeamChanged( localClientNum, fxHandle ) // self is the equipment entity
{
	self endon( "entityshutdown" );	
	self notify( "team_changed_watcher" );
	self endon( "team_changed_watcher" );
	
	watcherPlayer = GetLocalPlayer( localClientNum );

	while ( 1 )
	{
		level waittill( "team_changed", clientNum );
		
		player =  GetLocalPlayer( clientNum );
		
		if ( watcherPlayer == player )
		{
			self notify( "team_changed" );
		}
	}	
}



function sndProxAlert_EntCleanup( localClientNum, ent )
{
	level util::waittill_any( "sndDEDe", "demo_jump", "player_switch", "killcam_begin", "killcam_end" );

	if ( isdefined(ent) )
	{		
		ent StopAllLoopSounds( 0.5 );
		ent delete();
	}
}