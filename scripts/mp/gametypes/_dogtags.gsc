#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\objpoints_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spectating;

#namespace dogtags;

#define DOGTAG_VANISH_FX	"ui/fx_kill_confirmed_vanish"

#precache( "fx", DOGTAG_VANISH_FX );

function init()
{
	level.antiBoostDistance = GetGametypeSetting( "antiBoostDistance" );
	level.dogtags = [];
}

function spawn_dog_tag( victim, attacker, on_use_function, objectives_for_attacker_and_victim_only )
{
	if ( isdefined( level.dogtags[victim.entnum] ) )
	{
		PlayFx( DOGTAG_VANISH_FX, level.dogtags[victim.entnum].curOrigin );
		level.dogtags[victim.entnum] notify( "reset" );
	}
	else
	{
		visuals[0] = spawn( "script_model", (0,0,0) );
		visuals[0] setModel( victim GetEnemyDogTagModel() );
		visuals[1] = spawn( "script_model", (0,0,0) );
		visuals[1] setModel( victim GetFriendlyDogTagModel() );
		
		trigger = spawn( "trigger_radius", (0,0,0), 0, 32, 32 );
		
		level.dogtags[victim.entnum] = gameobjects::create_use_object( "any", trigger, visuals, (0,0,16) );
		
		level.dogtags[victim.entnum] gameobjects::set_use_time( 0 );
		level.dogtags[victim.entnum].onUse =&onUse;
		level.dogtags[victim.entnum].custom_onUse = on_use_function;
		level.dogtags[victim.entnum].victim = victim;
		level.dogtags[victim.entnum].victimTeam = victim.team;
		
		level thread clear_on_victim_disconnect( victim );
		victim thread team_updater( level.dogtags[victim.entnum] );

		foreach( team in level.teams )
		{
			objective_add( level.dogtags[victim.entnum].objId[team], "invisible", (0,0,0) );
			objective_icon( level.dogtags[victim.entnum].objId[team], "waypoint_dogtags" );	
			Objective_Team( level.dogtags[victim.entnum].objId[team], team );
			if ( team == attacker.team )
			{
				objective_setcolor( level.dogtags[victim.entnum].objId[team], &"EnemyOrange" );
			}
			else
			{
				objective_setcolor( level.dogtags[victim.entnum].objId[team], &"FriendlyBlue" );
			}
		}
	}	
	
	pos = victim.origin + (0,0,14);
	level.dogtags[victim.entnum].curOrigin = pos;
	level.dogtags[victim.entnum].trigger.origin = pos;
	level.dogtags[victim.entnum].visuals[0].origin = pos;
	level.dogtags[victim.entnum].visuals[1].origin = pos;
	
	level.dogtags[victim.entnum].visuals[0]	DontInterpolate();
	level.dogtags[victim.entnum].visuals[1]	DontInterpolate();
	
	level.dogtags[victim.entnum] gameobjects::allow_use( "any" );	
			
	level.dogtags[victim.entnum].visuals[0] thread show_to_team( level.dogtags[victim.entnum], attacker.team );
	level.dogtags[victim.entnum].visuals[1] thread show_to_enemy_teams( level.dogtags[victim.entnum], attacker.team );
	
	level.dogtags[victim.entnum].attacker = attacker;
	level.dogtags[victim.entnum].attackerTeam = attacker.team;
	level.dogtags[victim.entnum].unreachable = undefined;
	level.dogtags[victim.entnum].tacInsert = false;
	//level.dogtags[victim.entnum] thread time_out( victim );
	
	foreach( team in level.teams )
	{
		if ( IsDefined( level.dogtags[victim.entnum].objId[team] ) )
		{
			objective_position( level.dogtags[victim.entnum].objId[team], pos );
			objective_state( level.dogtags[victim.entnum].objId[team], "active" );
		}
	}
	
	if ( objectives_for_attacker_and_victim_only )
	{
		Objective_SetInvisibleToAll( level.dogtags[victim.entnum].objId[attacker.team] );

		if ( IsPlayer( attacker ) )
			Objective_SetVisibleToPlayer( level.dogtags[victim.entnum].objId[attacker.team], attacker );

		Objective_SetInvisibleToAll( level.dogtags[victim.entnum].objId[victim.team] );

		if ( IsPlayer( victim ) )
			Objective_SetVisibleToPlayer( level.dogtags[victim.entnum].objId[victim.team], victim );
	}	

	//PlaySoundAtPosition( "mpl_killconfirm_tags_drop", pos );
	
	level.dogtags[victim.entnum] thread bounce();
	level notify( "dogtag_spawned" );
}


function show_to_team( gameObject, show_team )
{
	self show();

	foreach( team in level.teams )
	{
		self HideFromTeam( team );
	}
	self ShowToTeam( show_team );
}

function show_to_enemy_teams( gameObject, friend_team )
{
	self show();

	foreach( team in level.teams )
	{
		self ShowToTeam( team );
	}
	self HideFromTeam( friend_team );
}

function onUse( player )
{
	self.visuals[0] playSound( "mpl_killconfirm_tags_pickup" );
	tacInsertBoost = false;
	
	//	friendly pickup
	if ( player.team != self.attackerTeam )
	{
		player AddPlayerStat( "KILLSDENIED", 1 );
		player RecordGameEvent("return");

		if ( self.victim == player  )
		{
			if ( self.tacInsert == false )
			{
				event = "retrieve_own_tags";
			}
			else
			{
				tacInsertBoost = true;
			}
		}
		else
		{
			event = "kill_denied";
		}
				
		if ( !tacInsertBoost )
		{
			player.pers["killsdenied"]++;
			player.killsdenied = player.pers["killsdenied"];
		}
	}
	else
	{
		event = "kill_confirmed";

		player AddPlayerStat( "KILLSCONFIRMED", 1 );
		player RecordGameEvent("capture");

		if ( isdefined( self.attacker ) && self.attacker != player )
		{	
			self.attacker onPickup( "teammate_kill_confirmed" );
		}
	}
	
	if ( !tacInsertBoost && isdefined( player ) )
	{
		player onPickup( event );
	}
	
	[[self.custom_onUse]]( player );
	
	//	do all this at the end now so the location doesn't change before playing the sound on the entity
	self reset_tags();		
}


function reset_tags()
{
	self.attacker = undefined;
	self.unreachable = undefined;
	self notify( "reset" );
	self.visuals[0] hide();
	self.visuals[1] hide();
	self.curOrigin = (0,0,1000);
	self.trigger.origin = (0,0,1000);
	self.visuals[0].origin = (0,0,1000);
	self.visuals[1].origin = (0,0,1000);
	self.tacInsert = false;
	self gameobjects::allow_use( "none" );	
	
	foreach( team in level.teams )
	{
		objective_state( self.objId[team], "invisible" );	
	}
}


function onPickup( event )
{
	scoreevents::processScoreEvent( event, self );
}


function clear_on_victim_disconnect( victim )
{
	level endon( "game_ended" );	
	
	guid = victim.entnum;
	victim waittill( "disconnect" );
	
	if ( isdefined( level.dogtags[guid] ) )
	{
		//	block further use
		level.dogtags[guid] gameobjects::allow_use( "none" );
		
		//	play vanish effect, reset, and wait for reset to process
		PlayFx( DOGTAG_VANISH_FX, level.dogtags[guid].curOrigin );
		level.dogtags[guid] notify( "reset" );		
		WAIT_SERVER_FRAME;
		
		//	sanity check before removal
		if ( isdefined( level.dogtags[guid] ) )
		{
			//	delete objective and visuals
			foreach( team in level.teams )
			{
					objective_delete( level.dogtags[guid].objId[team] );
			}
			level.dogtags[guid].trigger delete();
			for ( i=0; i<level.dogtags[guid].visuals.size; i++ )
				level.dogtags[guid].visuals[i] delete();
			level.dogtags[guid] notify ( "deleted" );
			
			//	remove from list
			level.dogtags[guid] = undefined;		
		}	
	}	
}

function on_spawn_player()
{
	if ( level.rankedMatch || level.leagueMatch )
	{
		if ( isdefined(self.tacticalInsertionTime) && self.tacticalInsertionTime + 100 > GetTime() )
		{
			minDist = level.antiBoostDistance;
			minDistSqr = minDist * minDist;
			
			distSqr = DistanceSquared( self.origin, level.dogtags[self.entnum].curOrigin );
			
			// tac insert spawn
			if ( distSqr < minDistSqr )
			{
				level.dogtags[self.entnum].tacInsert = true;
			}
		}
	}
}

function team_updater( tags )
{
	level endon( "game_ended" );
	self endon( "disconnect" );
	
	while( true )
	{
		self waittill( "joined_team" );
		
		tags.victimTeam = self.team;
		tags reset_tags();
	}
}

function time_out( victim )
{
	level  endon( "game_ended" );
	victim endon( "disconnect" );
	self notify( "timeout" );
	self endon( "timeout" );
	
	level hostmigration::waitLongDurationWithHostMigrationPause( 30.0 );
	
	self.visuals[0] hide();
	self.visuals[1] hide();
	self.curOrigin = (0,0,1000);
	self.trigger.origin = (0,0,1000);
	self.visuals[0].origin = (0,0,1000);
	self.visuals[1].origin = (0,0,1000);
	self.tacInsert = false;
	self gameobjects::allow_use( "none" );			
}

function bounce()
{
	level endon( "game_ended" );
	self endon( "reset" );	
	
	bottomPos = self.curOrigin;
	topPos = self.curOrigin + (0,0,12);
	
	while( true )
	{
		self.visuals[0] moveTo( topPos, 0.5, 0.15, 0.15 );
		self.visuals[0] rotateYaw( 180, 0.5 );
		self.visuals[1] moveTo( topPos, 0.5, 0.15, 0.15 );
		self.visuals[1] rotateYaw( 180, 0.5 );
		
		wait( 0.5 );
		
		self.visuals[0] moveTo( bottomPos, 0.5, 0.15, 0.15 );
		self.visuals[0] rotateYaw( 180, 0.5 );	
		self.visuals[1] moveTo( bottomPos, 0.5, 0.15, 0.15 );
		self.visuals[1] rotateYaw( 180, 0.5 );
		
		wait( 0.5 );		
	}
}

function checkAllowSpectating()
{
	self endon("disconnect");
	
	WAIT_SERVER_FRAME;
	/*
	
	update = false;

	livesLeft = !(level.numLives && !self.pers["lives"]);

	if ( !level.aliveCount[ game["attackers"] ] && !livesLeft )
	{
		level.spectateOverride[game["attackers"]].allowEnemySpectate = 1;
		update = true;
	}
	if ( !level.aliveCount[ game["defenders"] ] && !livesLeft )
	{
		level.spectateOverride[game["defenders"]].allowEnemySpectate = 1;
		update = true;
	}
	if ( update )
	*/	
		spectating::update_settings();
}

//self is victim
function should_spawn_tags( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	if ( IsAlive( self ) )
		return false;
		
	//no on switching teams
	if ( IsDefined( self.switching_teams ) )
		return false;
	
	//no on suicide
	if ( isDefined( attacker ) && attacker == self )
		return false;
	
	//no on TK
	if ( level.teamBased && isDefined( attacker ) && isDefined( attacker.team ) && attacker.team == self.team )
		return false;
	
	//no on world suicides
	if( IsDefined( attacker ) && ( !IsDefined( attacker.team ) || attacker.team == "free" ) && ( attacker.classname == "trigger_hurt" || attacker.classname == "worldspawn" ) )
		return false;
	
	return true;
}

function onUseDogTag( player )
{
	//	friendly pickup
	if ( player.pers["team"] == self.victimTeam )
	{
		player.pers["rescues"]++;
		player.rescues = player.pers["rescues"];
	
		if ( isdefined( self.victim ) )
		{
			if ( !level.gameEnded )
				self.victim thread dt_respawn();
		}	
	}
}

function dt_respawn()
{
	// Need to count this player as alive immediately, because they can wait to spawn whenever they want.  If we don't increment this until they become alive,
	// then things get screwed up when level.aliveCount becomes 1.  The game thinks that there's only one player left alive, and yet there are multiple players
	// on the team with self.pers["lives"] greater than 0.
	self thread waitTillCanSpawnClient(); 
}

//fixes a potential race condition with spawning around the same frame as friendly tag pickup
function waitTillCanSpawnClient()
{
	for (;;)
	{
		wait ( .05 );
		if ( isDefined( self ) && ( self.sessionstate == "spectator" || !isAlive( self ) ) )
		{
			self.pers["lives"] = 1;
			self thread [[level.spawnClient]]();		
			
			//we need to continue here because spawn client can fail for up to 3 server frames in this instance
			continue;
		}
		
		//player either disconnected or has spawned
		return;
	}
}