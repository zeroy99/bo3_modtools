#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\mp\_util;


#insert scripts\mp\killstreaks\_killstreaks.gsh;

#namespace remotemissile;

REGISTER_SYSTEM( "remotemissile", &__init__, undefined )

function __init__()
{
	clientfield::register( "missile", "remote_missile_bomblet_fired", VERSION_SHIP, 1, "int",&bomblets_deployed, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "missile", "remote_missile_fired", VERSION_SHIP, 2, "int",&missile_fired, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function missile_fired( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if( newVal == REMOTE_MISSILE_FIRED )
	{
		player = getlocalplayer( localClientNum );
		owner = self GetOwner( localClientNum );

		clientObjID = util::getNextObjID( localClientNum );

		objective_add( localClientNum, clientObjID, "invisible", self.origin, self.team, owner );
		Objective_OnEntity( localClientNum, clientObjID, self, true, false, true );
		self.hellfireObjId = clientObjID;
		self thread destruction_watcher( localClientNum, clientObjID );


		objective_state( localClientNum, clientObjID, "active" );
		if( player hasPerk( localClientNum, "specialty_showenemyequipment" ) || self.team == player.team )
		{
			objective_SetIcon( localClientNum, clientObjID, "remotemissile_target" );
			objective_SetIconSize( localClientNum, clientObjID, 50 );
		}
		
		self thread hud_update( localClientNum );
	}
	else if ( newVal == REMOTE_MISSILE_PLAYER_DETONATED )
	{
		if( isdefined( self.hellfireObjId ) )
		{
			self notify( "hellfire_detonated" );
			objective_delete( localClientNum, self.hellfireObjId );
			util::releaseObjID( localClientNum, self.hellfireObjId );
		}
	}
	else
		self notify( "cleanup_objectives" );
	
	
	ammo_ui_data_model = GetUIModel( GetUIModelForController( localClientNum ), "vehicle.ammo" );
	if ( isdefined( ammo_ui_data_model ) )
		SetUIModelValue( ammo_ui_data_model, 1 );
}

function bomblets_deployed( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( bNewEnt && oldVal == newVal )
	{
		return;
	}

	if( newVal == REMOTE_MISSILE_BOMBLET_FIRED )
	{
		player = getlocalplayer( localClientNum );
		owner = self GetOwner( localClientNum );

		clientObjID = util::getNextObjID( localClientNum );

		objective_add( localClientNum, clientObjID, "invisible", self.origin, self.team, owner );
		Objective_OnEntity( localClientNum, clientObjID, self, true, false, true );
		self thread destruction_watcher( localClientNum, clientObjID );


		objective_state( localClientNum, clientObjID, "active" );
		if( player hasPerk( localClientNum, "specialty_showenemyequipment" ) || player.team == self.team )
			objective_SetIcon( localClientNum, clientObjID, "remotemissile_target" );
	}
	else
		self notify( "cleanup_objectives" );
	
	ammo_ui_data_model = GetUIModel( GetUIModelForController( localClientNum ), "vehicle.ammo" );
	if ( isdefined( ammo_ui_data_model ) )
		SetUIModelValue( ammo_ui_data_model, 0 );
}

function destruction_watcher( localClientNum, clientObjID )
{
	self util::waittill_any( "death", "entityshutdown", "cleanup_objectives" );
	wait( 0.1 );
	if( isdefined( clientObjID ) )
	{
		objective_delete( localClientNum, clientObjID );
		util::releaseObjID( localClientNum, clientObjID );
	}
}

function hud_update( localClientNum )
{
	self endon( "entityshutdown" );
	self notify( "remote_missile_singeton");
	self endon( "remote_missile_singeton");
	missile = self;
	
	altitude_ui_data_model = GetUIModel( GetUIModelForController( localClientNum ), "vehicle.altitude" );
	speed_ui_data_model = GetUIModel( GetUIModelForController( localClientNum ), "vehicle.speed" );
	
	if( !isdefined( altitude_ui_data_model ) || !isdefined( speed_ui_data_model ) )
		return;
	
	prev_z = missile.origin[2];
	
	fps = 20.0;
	delay = 1.0 / fps;
	
	while( 1 )
	{
		cur_z = missile.origin[2];
		SetUIModelValue( altitude_ui_data_model, cur_z );
		
		dist = ( prev_z - cur_z ) * fps;
		val = dist / MPH_TO_INCHES_PER_SEC;
		SetUIModelValue( speed_ui_data_model, val );
		
		prev_z = cur_z;

		wait ( delay );
	}
}
