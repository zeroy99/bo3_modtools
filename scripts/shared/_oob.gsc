#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hostmigration_shared;

#insert scripts\shared\clientfields.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


#namespace oob;

#define OOB_TIMELIMIT_MS_DEFAULT 6000 //Change the value in the _oob.csc file to match this one
#define OOB_DAMAGE_MS_DEFAULT 1000
#define OOB_DAMAGE_DEFAULT 5
#define OOB_EFFECT_MAX_DISTANCE_BEFORE_BLACK 400
#define OOB_EFFECT_TIME_REMAINING_BEFORE_BLACK 1000


#define OOB_TIMEKEEP_MP	3000  //Change the value in the _oob.csc file to match this one
#define OOB_TIMELIMIT_MS_DEFAULT_MP 3000  //Change the value in the _oob.csc file to match this one
#define OOB_DAMAGE_MS_DEFAULT_MP 3000
#define OOB_DAMAGE_DEFAULT_MP 999
#define OOB_EFFECT_MAX_DISTANCE_BEFORE_BLACK_MP 100000
#define OOB_EFFECT_TIME_REMAINING_BEFORE_BLACK_MP -1
	
#define OOB_INVALID_TIME -1

REGISTER_SYSTEM( "out_of_bounds", &__init__, undefined )		

function __init__()
{
	level.oob_triggers = [];
	
	if(SessionModeIsMultiplayerGame())
	{
		level.oob_timekeep_ms = GetDvarInt( "oob_timekeep_ms", OOB_TIMEKEEP_MP );
		level.oob_timelimit_ms = GetDvarInt( "oob_timelimit_ms", OOB_TIMELIMIT_MS_DEFAULT_MP );
		level.oob_damage_interval_ms = GetDvarInt( "oob_damage_interval_ms", OOB_DAMAGE_MS_DEFAULT_MP );
		level.oob_damage_per_interval = GetDvarInt( "oob_damage_per_interval", OOB_DAMAGE_DEFAULT_MP );
		level.oob_max_distance_before_black = GetDvarInt( "oob_max_distance_before_black", OOB_EFFECT_MAX_DISTANCE_BEFORE_BLACK_MP );
		level.oob_time_remaining_before_black = GetDvarInt( "oob_time_remaining_before_black", OOB_EFFECT_TIME_REMAINING_BEFORE_BLACK_MP );
	}
	else
	{
		level.oob_timelimit_ms = GetDvarInt( "oob_timelimit_ms", OOB_TIMELIMIT_MS_DEFAULT );
		level.oob_damage_interval_ms = GetDvarInt( "oob_damage_interval_ms", OOB_DAMAGE_MS_DEFAULT );
		level.oob_damage_per_interval = GetDvarInt( "oob_damage_per_interval", OOB_DAMAGE_DEFAULT );
		level.oob_max_distance_before_black = GetDvarInt( "oob_max_distance_before_black", OOB_EFFECT_MAX_DISTANCE_BEFORE_BLACK );
		level.oob_time_remaining_before_black = GetDvarInt( "oob_time_remaining_before_black", OOB_EFFECT_TIME_REMAINING_BEFORE_BLACK );
	}
	
	level.oob_damage_interval_sec = level.oob_damage_interval_ms / 1000;
	
	hurt_triggers = GetEntArray( "trigger_out_of_bounds","classname" );
	
	foreach( trigger in hurt_triggers )
	{
		trigger thread run_oob_trigger();
	}
	
	clientfield::register( "toplayer", "out_of_bounds", VERSION_SHIP, 5, "int" );
}

function run_oob_trigger()
{
	self.oob_players = [];
	ARRAY_ADD( level.oob_triggers, self );
	self thread waitForPlayerTouch();
	self thread waitForCloneTouch();
}

function IsOutOfBounds()
{
	if( !IsDefined( self.oob_start_time ) )
	{
		return false;
	}
	
	return self.oob_start_time != OOB_INVALID_TIME;
}

function IsTouchingAnyOOBTrigger()
{
	triggers_to_remove = [];
	result = false;
	
	foreach( trigger in level.oob_triggers )
	{
		if( !isdefined( trigger ) )
		{
			ARRAY_ADD(triggers_to_remove, trigger);
			continue;
		}
		
		if( !trigger IsTriggerEnabled() )
		{
			continue;
		}
		
		if( self IsTouching( trigger ) )
		{
			result = true;
			break;
		}
	}
	
	foreach( trigger in triggers_to_remove )
	{
		ArrayRemoveValue( level.oob_triggers, trigger );
	}
	
	triggers_to_remove = [];
	triggers_to_remove = undefined;
	
	return result;
}

function ResetOOBTimer( is_host_migrating, b_disable_timekeep)
{
	self.oob_lastValidPlayerLoc = undefined;
	self.oob_LastValidPlayerDir = undefined;
	self clientfield::set_to_player( "out_of_bounds", 0 );
	self util::show_hud( 1 );
	self.oob_start_time = OOB_INVALID_TIME;
	
	if( isdefined(level.oob_timekeep_ms))
	{
		if(IS_TRUE(b_disable_timekeep))
		{
			self.last_oob_timekeep_ms = undefined;
		}
		else
		{
			self.last_oob_timekeep_ms = GetTime();
		}
	}

	if(!IS_TRUE(is_host_migrating))
	{
		self notify( "oob_host_migration_exit" );
	}
	
	self notify( "oob_exit" );
}

function waitForCloneTouch()//self = trigger
{
	self endon( "death" );
	
	while( true )
	{
		self waittill( "trigger", clone );
	
		if( IsActor( clone ) && IsDefined( clone.isAiClone ) && clone.isAiClone && (!clone IsPlayingAnimScripted()) )
		{
			clone notify( "clone_shutdown" );
		}
	}
}

function GetAdjusedPlayer( Player )
{
	if( isdefined(player.hijacked_vehicle_entity) && IsAlive(player.hijacked_vehicle_entity) )
	{
		return player.hijacked_vehicle_entity;
	}
	
	return Player;
}

function waitForPlayerTouch()//self = trigger
{
	self endon( "death" );
	
	while( true )
	{
		if(SessionModeIsMultiplayerGame())
		{
			hostmigration::waitTillHostMigrationDone();
		}
		
		self waittill( "trigger", entity );
	
		if( !IsPlayer(entity) && !(IsVehicle(entity) && IS_TRUE(entity.hijacked) && isdefined(entity.owner) && IsAlive(entity)) )
			continue;
		
		if(IsPlayer(entity))
		{
			player = entity;
		}
		else
		{
			vehicle = entity;
			player = vehicle.owner;
		}
		
		if( !(player IsOutOfBounds()) && !(player IsPlayingAnimScripted()) && !IS_TRUE( player.OOBDisabled ) )
		{
			player notify( "oob_enter" );
			
			//Logic to pause/continue the OOB time for a certain duration if the player come out/in from it.
			if( isdefined(level.oob_timekeep_ms) && isdefined(player.last_oob_timekeep_ms) && isdefined(player.last_oob_duration_ms) &&
			   ((GetTime() - player.last_oob_timekeep_ms) < level.oob_timekeep_ms) )
			{
				player.oob_start_time = GetTime() - (level.oob_timelimit_ms - player.last_oob_duration_ms);
			}
			else
			{
				player.oob_start_time = GetTime();
			}
			
			player.oob_LastValidPlayerLoc = entity.origin;
			player.oob_LastValidPlayerDir = VectorNormalize( entity GetVelocity() ) ;
			
			player util::show_hud( 0 );
			player thread watchForLeave( self, entity );
			player thread watchForDeath( self, entity );
			
			if(SessionModeIsMultiplayerGame())
			{
				player thread watchForHostMigration( self, entity );
			}
		}
	}
}

function GetDistanceFromLastValidPlayerLoc(trigger, entity)
{
	if(isdefined(self.oob_LastValidPlayerDir) && self.oob_LastValidPlayerDir != (0, 0, 0))
	{
		vecToPlayerLocFromOrigin = entity.origin - self.oob_lastValidPlayerLoc;
		distance = VectorDot(vecToPlayerLocFromOrigin, self.oob_LastValidPlayerDir);
	}
	else
	{
		distance = Distance(entity.origin, self.oob_lastValidPlayerLoc);
	}
	
	if(distance < 0)
		distance = 0;
	
	if(distance > level.oob_max_distance_before_black)
		distance = level.oob_max_distance_before_black;
	
	return distance / level.oob_max_distance_before_black;
}

function UpdateVisualEffects( trigger, entity )
{
	timeRemaining = (level.oob_timelimit_ms - (GetTime() - self.oob_start_time));
	
	if( isdefined(level.oob_timekeep_ms) )
	{
	   	self.last_oob_duration_ms = timeRemaining;
	}
			
	oob_effectValue = 0;
	
	if(timeRemaining <= level.oob_time_remaining_before_black)
	{
		if(!isdefined(self.oob_lastEffectValue))
		{
			self.oob_lastEffectValue = GetDistanceFromLastValidPlayerLoc(trigger, entity);
		}
		
		time_val = 1 - (timeRemaining / level.oob_time_remaining_before_black);
		
		if(time_val > 1)
			time_val = 1;
		
		oob_effectValue = self.oob_lastEffectValue + (1 - self.oob_lastEffectValue) * time_val;
	}
	else
	{
		oob_effectValue = GetDistanceFromLastValidPlayerLoc(trigger, entity);
		
		if(oob_effectValue > 0.9)
		{
			oob_effectValue = 0.9;
		}
		else if(oob_effectValue < 0.05)
		{
			oob_effectValue = 0.05;
		}
		
		self.oob_lastEffectValue = oob_effectValue;
	}
	
	oob_effectValue = ceil(oob_effectValue * 31); //5 bits 2^5 = 32 (so 31 values)
	
	self clientfield::set_to_player( "out_of_bounds", int(oob_effectValue) );
}

function killEntity(entity)
{
	entity_to_kill = entity;
	
	if ( IsPlayer( entity ) && entity IsInVehicle() )
	{
		vehicle = entity GetVehicleOccupied();
		if ( isdefined( vehicle ) && ( vehicle.is_oob_kill_target === true ) )
			entity_to_kill = vehicle;
	}

	self ResetOOBTimer();
	entity_to_kill DoDamage( entity_to_kill.health + 10000, entity_to_kill.origin, undefined, undefined, "none", "MOD_TRIGGER_HURT" );
}

function watchForLeave( trigger, entity )
{
	self endon( "oob_exit" );
	entity endon( "death" );
	
	while( true )
	{
		if( entity IsTouchingAnyOOBTrigger() )
		{
			UpdateVisualEffects( trigger, entity );
			
			if( (level.oob_timelimit_ms - (GetTime() - self.oob_start_time)) <= 0 )
			{
				if( IsPlayer(entity) )
				{
					entity  DisableInvulnerability();
                    entity.ignoreme = false;
                    entity.laststand = undefined;
                    
                    if( isdefined( entity.revivetrigger ) )
                    {
                        entity.reviveTrigger delete();
                    } 
				}
				self thread killEntity( entity );
			}
		}
		else
		{
			self ResetOOBTimer();
		}
		
		wait( 0.1 );
	}
}

function watchForDeath( trigger, entity )
{
	self endon( "disconnect" );
	self endon( "oob_exit" );
	
	util::waittill_any_ents_two( self, "death", entity, "death" ); 

	self ResetOOBTimer();
}

function watchForHostMigration( trigger, entity )
{
	self endon( "oob_host_migration_exit" );
	
	level waittill("host_migration_begin");

	self ResetOOBTimer( true, true );
}

function disablePlayerOOB( disabled )
{
	if ( disabled )
	{
		self ResetOOBTimer();
		self.OOBDisabled = true;
	}
	else
	{
		self.OOBDisabled = false;
	}
}
