#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\filter_shared;
#using scripts\shared\util_shared;


#insert scripts\shared\duplicaterender.gsh;
#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\weapons\_weaponobjects.gsh;

#using scripts\shared\system_shared;

#namespace killstreak_detect;

REGISTER_SYSTEM( "killstreak_detect", &__init__, undefined )	


function __init__()
{
	callback::on_localplayer_spawned( &watch_killstreak_detect_perks_changed );
	
	clientfield::register( "scriptmover", "enemyvehicle", VERSION_SHIP, 2, "int", &enemyScriptMoverVehicle_changed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "vehicle", "enemyvehicle", VERSION_SHIP, 2, "int", &enemyvehicle_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "helicopter", "enemyvehicle", VERSION_SHIP, 2, "int", &enemyvehicle_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "missile", "enemyvehicle", VERSION_SHIP, 2, "int", &enemyMissileVehicle_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "enemyvehicle", VERSION_SHIP, 2, "int", &enemyvehicle_changed, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );

	clientfield::register( "vehicle", "vehicletransition", VERSION_SHIP, 1, "int", &vehicle_transition, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );	

	DEFAULT(level.enemyvehicles,[]);
	DEFAULT(level.enemymissiles,[]);
	
	level.emp_killstreaks = [];
}

function vehicle_transition( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	player = GetLocalPlayer( local_client_num );
	friend = self util::friend_not_foe( local_client_num, true );
	
	if( friend && isdefined( player ) && player duplicate_render::show_friendly_outlines( local_client_num ) )
	{
		showOutlines = !(self IsLocalClientDriver( local_client_num ) );
		self duplicate_render::set_item_friendly_vehicle( local_client_num, showOutlines );
	}	
}

function should_set_compass_icon( local_client_num )
{
	local_player = GetLocalPlayer( local_client_num );

	return ( isdefined( local_player ) && isdefined( self.team ) && ( local_player.team === self.team || local_player HasPerk( local_client_num, "specialty_showenemyvehicles" ) ) );
}

function enemyScriptMoverVehicle_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isdefined( level.scriptMoverCompassIcons ) && isdefined( self.model ) )
	{
		if ( isdefined( level.scriptMoverCompassIcons[self.model] ) )
		{
			if ( self should_set_compass_icon( local_client_num ) )
			{
				self setCompassIcon( level.scriptMoverCompassIcons[self.model] );
			}
		}
	}
	
	enemyvehicle_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
}

function enemyMissileVehicle_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isdefined( level.missileCompassIcons ) && isdefined( self.weapon ) )
	{
		if ( isdefined( level.missileCompassIcons[self.weapon] ) )
		{
			if ( self should_set_compass_icon( local_client_num ) )
			{
				self setCompassIcon( level.missileCompassIcons[self.weapon] );
			}
		}
	}
	
	enemymissile_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump );
}

function enemymissile_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self updateTeamMissiles( local_client_num, newVal );
	self util::add_remove_list( level.enemymissiles, newVal );
	self updateEnemyMissiles( local_client_num, newVal );
}
	
function enemyvehicle_changed( local_client_num, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self updateTeamVehicles( local_client_num, newVal );
	self util::add_remove_list( level.enemyvehicles, newVal );
	
	self updateEnemyVehicles( local_client_num, newVal );
	
	if ( isdefined( self.model ) && self.model == "wpn_t7_turret_emp_core" && self.type === "vehicle" )
	{
		ARRAY_ADD( level.emp_killstreaks, self );
	}
}

function updateTeamVehicles( local_client_num, newVal )
{	
	self checkTeamVehicles( local_client_num );
}

function updateTeamMissiles( local_client_num, newVal )
{	
	self checkTeamMissiles( local_client_num );
}

function updateEnemyVehicles( local_client_num, newVal )
{
	if ( !( isdefined( self ) ) )
	{
	    	return;
	}
	watcher = GetLocalPlayer( local_client_num );
	friend = self util::friend_not_foe( local_client_num, true ); 

	self duplicate_render::set_dr_flag( "enemyvehicle_fb", !friend );

	self duplicate_render::set_item_enemy_vehicle( local_client_num, false );
	self duplicate_render::set_item_friendly_vehicle( local_client_num, false );
	self.isEnemyVehicle = false; 
	if ( !friend && IsDefined( watcher ) && watcher HasPerk( local_client_num, "specialty_showenemyvehicles" ) )
	{
		if ( !isdefined( self.isbreachingfirewall ) || self.isbreachingfirewall == false ) 
		{
			self duplicate_render::set_item_enemy_vehicle( local_client_num, newVal );
		}
		self.isEnemyVehicle = true;
		self duplicate_render::set_item_friendly_vehicle( local_client_num, false );
	}
	else if( ( friend === true ) && isDefined( watcher ) && watcher duplicate_render::show_friendly_outlines(local_client_num) )
	{
		driver = ( self.type === "vehicle" ) && self IsLocalClientDriver( local_client_num );
		showOutlines = ( driver === false ) && ( newVal === ENEMY_VEHICLE_ACTIVE || newVal === ENEMY_VEHICLE_HACKED );
		self duplicate_render::set_item_friendly_vehicle( local_client_num, showOutlines );
	}
	else
	{
		self duplicate_render::set_item_friendly_vehicle( local_client_num, false );
	}
	
	if ( newVal == ENEMY_VEHICLE_HACKED )
	{
		self.killstreakIsHacked = true;
	}
	
	self duplicate_render::update_dr_filters( local_client_num );
}

function updateEnemyMissiles( local_client_num, newVal )
{
	if ( !( isdefined( self ) ) )
	{
	    return;
	}
	watcher = GetLocalPlayer( local_client_num );
	friend = self util::friend_not_foe( local_client_num, true ); 

	self duplicate_render::set_dr_flag( "enemyvehicle_fb", !friend );

	self duplicate_render::set_item_enemy_explosive( local_client_num, false );
	self duplicate_render::set_item_friendly_explosive( local_client_num, false );
	self.isEnemyVehicle = false; 
	if ( !friend && IsDefined( watcher ) && watcher HasPerk( local_client_num, "specialty_showenemyvehicles" ) )
	{
		if ( !isdefined( self.isbreachingfirewall ) || self.isbreachingfirewall == false ) 
		{
			self duplicate_render::set_item_enemy_explosive( local_client_num, newVal );
		}
		self.isEnemyVehicle = true;
		self duplicate_render::set_item_friendly_explosive( local_client_num, false );
	}
	else if( ( friend === true ) && isDefined( watcher ) && watcher duplicate_render::show_friendly_outlines(local_client_num) )
	{
		showOutlines = ( newVal === ENEMY_VEHICLE_ACTIVE || newVal === ENEMY_VEHICLE_HACKED );
		self duplicate_render::set_item_friendly_explosive( local_client_num, showOutlines );
	}
	else
	{
		self duplicate_render::set_item_friendly_explosive( local_client_num, false );
	}
	
	if ( newVal == ENEMY_VEHICLE_HACKED )
	{
		self.killstreakIsHacked = true;
	}
	
	self duplicate_render::update_dr_filters( local_client_num );
}

function watch_killstreak_detect_perks_changed(local_client_num)
{
	if( self != GetLocalPlayer( local_client_num ) )
		return;

	self notify( "watch_killstreak_detect_perks_changed" );
	self endon( "watch_killstreak_detect_perks_changed" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	
	while(IsDefined(self))
	{
		WAIT_CLIENT_FRAME;
		util::clean_deleted(level.enemyvehicles);
		util::clean_deleted(level.enemymissiles);
		array::thread_all( level.enemyvehicles, &updateEnemyVehicles, local_client_num, 1 );
		array::thread_all( level.enemymissiles, &updateEnemyMissiles, local_client_num, 1 );
		self waittill("perks_changed");
	}
}


function checkTeamVehicles( localClientNum )
{	
	if ( !isdefined ( self.owner ) || !isdefined ( self.owner.team ) )
	{
		return;
	}
	
	if ( !isdefined( self.vehicleOldTeam ) )
	{
		self.vehicleOldTeam = self.team;
	}
	
	if ( !isdefined( self.vehicleOldOwnerTeam ) )
	{
		self.vehicleOldOwnerTeam = self.owner.team;
	}
	
	watcher = GetLocalPlayer( localClientNum );
	
	if ( !isdefined( self.vehicleOldWatcherTeam ) )
	{
		self.vehicleOldWatcherTeam = watcher.team;
	}
	
	if ( self.vehicleOldTeam != self.team || self.vehicleOldOwnerTeam != self.owner.team || self.vehicleOldWatcherTeam != watcher.team)
	{
		self.vehicleOldTeam = self.team;
		self.vehicleOldOwnerTeam = self.owner.team;
		self.vehicleOldWatcherTeam = watcher.team;
		
		self notify( "team_changed" );		
	}
}

function checkTeamMissiles( localClientNum )
{	
	if ( !isdefined ( self.owner ) || !isdefined ( self.owner.team ) )
	{
		return;
	}
	
	if ( !isdefined( self.missileOldTeam ) )
	{
		self.missileOldTeam = self.team;
	}
	
	if ( !isdefined( self.missileOldOwnerTeam ) )
	{
		self.missileOldOwnerTeam = self.owner.team;
	}
	
	watcher = GetLocalPlayer( localClientNum );
	
	if ( !isdefined( self.missileOldWatcherTeam ) )
	{
		self.missileOldWatcherTeam = watcher.team;
	}
	
	if ( self.missileOldTeam != self.team || self.missileOldOwnerTeam != self.owner.team || self.missileOldWatcherTeam != watcher.team)
	{
		self.missileOldTeam = self.team;
		self.missileOldOwnerTeam = self.owner.team;
		self.missileOldWatcherTeam = watcher.team;
		
		self notify( "team_changed" );		
	}
}
