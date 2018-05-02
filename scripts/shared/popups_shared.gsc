#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\medals_shared;
#using scripts\shared\persistence_shared;
#using scripts\shared\rank_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons_shared;
#using scripts\shared\weapons\_weapons;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\statstable_shared.gsh;

#precache( "string", "KILLSTREAK_DESTROYED_UAV" );	
#precache( "string", "KILLSTREAK_DESTROYED_COUNTERUAV" );	
#precache( "string", "KILLSTREAK_DESTROYED_REMOTE_MORTAR" );	
#precache( "string", "KILLSTREAK_MP40_INBOUND" );	
#precache( "string", "KILLSTREAK_M220_TOW_INBOUND" );	
#precache( "string", "KILLSTREAK_MINIGUN_INBOUND" );	
#precache( "string", "KILLSTREAK_M202_FLASH_INBOUND" );	
#precache( "string", "KILLSTREAK_M32_INBOUND");	
#precache( "string", "MP_CAPTURED_THE_FLAG" );	
#precache( "string", "MP_KILLED_FLAG_CARRIER" );	
#precache( "string", "MP_FRIENDLY_FLAG_DROPPED" );
#precache( "string", "MP_ENEMY_FLAG_DROPPED" );
#precache( "string", "MP_FRIENDLY_FLAG_RETURNED" );
#precache( "string", "MP_ENEMY_FLAG_RETURNED" );
#precache( "string", "MP_FRIENDLY_FLAG_TAKEN" );
#precache( "string", "MP_ENEMY_FLAG_TAKEN" );
#precache( "string", "MP_ENEMY_FLAG_CAPTURED" );
#precache( "string", "MP_FRIENDLY_FLAG_CAPTURED" );
#precache( "string", "MP_EXPLOSIVES_BLOWUP_BY" );
#precache( "string", "MP_EXPLOSIVES_DEFUSED_BY" );	
#precache( "string", "MP_EXPLOSIVES_PLANTED_BY" );	
#precache( "string", "MP_HQ_DESTROYED_BY" );
#precache( "string", "KILLSTREAK_DESTROYED_HELICOPTER" );

#namespace popups;

// some common functions between all the air kill streaks

REGISTER_SYSTEM( "popups", &__init__, undefined )
	
function __init__()
{
	callback::on_start_gametype( &init );
}

function init()
{
	// if the column changes in the medalTable.csv 
	// these need to be changed too
	level.contractSettings = spawnstruct();
	level.contractSettings.waitTime = 4.2;
	level.killstreakSettings = spawnstruct();
	level.killstreakSettings.waitTime = 3;
	level.rankSettings = spawnstruct();
	level.rankSettings.waitTime = 3;
	level.startMessage = spawnstruct();
	level.startMessageDefaultDuration = 2.0;
	level.endMessageDefaultDuration = 2.0;
	level.challengeSettings = spawnstruct();
	level.challengeSettings.waitTime = 3;
	level.teamMessage = spawnstruct();
	level.teamMessage.waittime = 3;
	level.regularGameMessages = spawnstruct();
	level.regularGameMessages.waittime = 6;
	level.wagerSettings = spawnstruct();
	level.wagerSettings.waittime = 3;
	level.momentumNotifyWaitTime = 0;
	level.momentumNotifyWaitLastTime = 0;
	level.teamMessageQueueMax = 8;


	callback::on_connecting( &on_player_connect );
}

function on_player_connect()
{
	self.resetGameOverHudRequired = false;
	self thread displayPopupsWaiter();
	if ( !level.hardcoreMode )
	{
		self thread displayTeamMessageWaiter();
	}
}

function DisplayKillstreakTeamMessageToAll( killstreak, player )
{
	if ( !isdefined ( level.killstreaks[killstreak] ) )
		return;
	if ( !isdefined ( level.killstreaks[killstreak].inboundText ) )
		return;
		
	message = level.killstreaks[killstreak].inboundText;
	self DisplayTeamMessageToAll( message, player );
}

function DisplayKillstreakHackedTeamMessageToAll( killstreak, player )
{
	if ( !isdefined ( level.killstreaks[killstreak] ) )
		return;
	if ( !isdefined ( level.killstreaks[killstreak].hackedText ) )
		return;
	
	message = level.killstreaks[killstreak].hackedText;
	self DisplayTeamMessageToAll( message, player );
}

function shouldDisplayTeamMessages()
{
	// level.splitscreen is the local splitscreen mode only
	if ( level.hardcoreMode == true || level.splitscreen == true ) 
		return false;	
		
	return true;
}

function DisplayTeamMessageToAll( message, player )
{
	if ( !shouldDisplayTeamMessages() )
		return;
		
	for ( i = 0; i < level.players.size; i++ )
	{		
		cur_player = level.players[i];

		if ( cur_player IsEMPJammed() )
			continue;

		size = cur_player.teamMessageQueue.size;

		if ( size >= level.teamMessageQueueMax )
			continue;
				
		cur_player.teamMessageQueue[size] = spawnStruct();
		cur_player.teamMessageQueue[size].message = message;
		cur_player.teamMessageQueue[size].player = player;
		
		cur_player notify ( "received teammessage" );
	}
}

function DisplayTeamMessageToTeam( message, player, team )
{ 
	if ( !shouldDisplayTeamMessages() ) 
		return;

	for ( i = 0; i < level.players.size; i++ ) 
	{
		cur_player = level.players[i]; 

		if ( cur_player.team != team ) 
			continue;

		if ( cur_player IsEMPJammed() )
			continue;

		size = cur_player.teamMessageQueue.size;

		if ( size >= level.teamMessageQueueMax )
			continue;

		cur_player.teamMessageQueue[size] = spawnStruct();
		cur_player.teamMessageQueue[size].message = message;
		cur_player.teamMessageQueue[size].player = player; 

		cur_player notify ( "received teammessage" ); 
	}
}

function displayTeamMessageWaiter()
{
	if ( !shouldDisplayTeamMessages() )
		return;

	self endon( "disconnect" );
	level endon( "game_ended" );
	
	self.teamMessageQueue = [];
	
	for ( ;; )
	{
		if ( self.teamMessageQueue.size == 0 )
			self waittill( "received teammessage" );
		
		if ( self.teamMessageQueue.size > 0 )
		{	
			nextNotifyData = self.teamMessageQueue[0];
			ArrayRemoveIndex( self.teamMessageQueue, 0, false );

			if ( !isdefined( nextNotifyData.player ) || !isplayer( nextNotifyData.player ) )
				continue;

			if ( self IsEMPJammed() )
				continue;
			
			self LUINotifyEvent( &"player_callout", 2, nextNotifyData.message, nextNotifyData.player.entnum );
		}
		wait ( level.teamMessage.waittime );
	}
}


function displayPopUpsWaiter()
{
	self endon( "disconnect" );
	
	self.rankNotifyQueue = [];
	if ( !isdefined( self.pers["challengeNotifyQueue"] ) )
	{		
		self.pers["challengeNotifyQueue"] = [];
	}
	if ( !isdefined( self.pers["contractNotifyQueue"] ) )
	{		
		self.pers["contractNotifyQueue"] = [];
	}

	self.messageNotifyQueue = [];
	self.startMessageNotifyQueue = [];
	self.wagerNotifyQueue = [];
				
	while( isdefined( level ) && isdefined( level.gameEnded ) && !level.gameEnded )
	{
		if ( self.startMessageNotifyQueue.size == 0 && self.messageNotifyQueue.size == 0 )
			self waittill( "received award" );
		
		waittillframeend;

		if ( !isdefined( level ) )
			break;
		
		if ( !isdefined( level.gameEnded ) )
			break;
		
		if ( level.gameEnded )
			break;
		
		if ( self.startMessageNotifyQueue.size > 0 )
		{
			nextNotifyData = self.startMessageNotifyQueue[0];
			ArrayRemoveIndex( self.startMessageNotifyQueue, 0, false );
			
			if ( isdefined( nextNotifyData.duration ) )
				duration = nextNotifyData.duration;
			else
				duration = level.startMessageDefaultDuration;
				
			self hud_message::showNotifyMessage( nextNotifyData, duration );
			wait ( duration );
		}
		else if ( self.messageNotifyQueue.size > 0 )
		{
			nextNotifyData = self.messageNotifyQueue[0];
			ArrayRemoveIndex( self.messageNotifyQueue, 0, false );
			
			if ( isdefined( nextNotifyData.duration ) )
				duration = nextNotifyData.duration;
			else
				duration = level.regularGameMessages.waittime;
			
			self hud_message::showNotifyMessage( nextNotifyData, duration );
		}
		else
		{	
			//assertmsg( "displayPopUpsWaiter not handling case" );
			wait( 1 );
		}
	}
}

function milestoneNotify( index, itemIndex, type, tier )
{
	level.globalChallenges++;
	
	if ( !isdefined( type ) )
	{
		type = "global";
	}
	size = self.pers["challengeNotifyQueue"].size;
	self.pers["challengeNotifyQueue"][size] = [];
	self.pers["challengeNotifyQueue"][size]["tier"] = tier;
	self.pers["challengeNotifyQueue"][size]["index"] = index;
	self.pers["challengeNotifyQueue"][size]["itemIndex"] = itemIndex;
	self.pers["challengeNotifyQueue"][size]["type"] = type;
		
	self notify( "received award" );
}

