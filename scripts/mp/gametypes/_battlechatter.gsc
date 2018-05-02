#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\codescripts\struct;
#using scripts\shared\abilities\gadgets\_gadget_camo;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\mp\gametypes\_dev;

#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;

#using scripts\mp\killstreaks\_killstreaks;

#namespace battlechatter;

REGISTER_SYSTEM( "battlechatter", &__init__, undefined )

#define INCOMING_ALERT "incoming_alert"
#define INCOMING_DELAY "incoming_delay"
#define KILL_DIALOG "kill_dialog"

#define DIALOG_FLAG_TEAM				1
#define DIALOG_FLAG_ALL					2
#define DIALOG_FLAG_INTERRUPT			4
#define DIALOG_FLAG_UNDERWATER			8
#define DIALOG_FLAG_EXERT				16	// Plays when VO is turned off
#define DIALOG_FLAG_GADGET_READY		32
#define DIALOG_FLAG_STOLEN_GADGET_READY		64
	
#define DIALOG_FLAGS_SHOUT				6	// ALL + INTERRUPT
#define DIALOG_FLAGS_PAIN				30	// ALL + INTERRUPT + UNDERWATER + EXERT

#define STOLEN_GADGET_READY_LINE_COUNT 4
	
#define VOICE_TAG "J_Head"

#define NUM_BOOSTS 		4
#define PLAY_BOOST		"play_boost"
#define BOOST_START		1
#define BOOST_RESPONSE	2
	
function __init__()
{
	callback::on_joined_team( &on_joined_team );
	callback::on_connect( &on_player_connect );
	callback::on_spawned( &on_player_spawned );
	
	level.heroPlayDialog = &play_dialog;
	level.playGadgetReady = &play_gadget_ready;
	level.playGadgetActivate = &play_gadget_activate;
	level.playGadgetSuccess = &play_gadget_success;
	level.playPromotionReaction = &play_promotion_reaction;
	level.playThrowHatchet = &play_throw_hatchet;
	
	level.bcSounds = [];
	level.bcSounds[ INCOMING_ALERT ] = [];
	level.bcSounds[ INCOMING_ALERT ][ "frag_grenade" ] = "incomingFrag";
	level.bcSounds[ INCOMING_ALERT ][ "incendiary_grenade" ] = "incomingIncendiary";
	level.bcSounds[ INCOMING_ALERT ][ "sticky_grenade" ] = "incomingSemtex";
	level.bcSounds[ INCOMING_ALERT ][ "launcher_standard" ] = "threatRpg";
	
	
	level.bcSounds[ INCOMING_DELAY ] = [];
	level.bcSounds[ INCOMING_DELAY ][ "frag_grenade" ] = "fragGrenadeDelay";
	level.bcSounds[ INCOMING_DELAY ][ "incendiary_grenade" ] = "incendiaryGrenadeDelay";
	level.bcSounds[ INCOMING_ALERT ][ "sticky_grenade" ] = "semtexDelay";
	level.bcSounds[ INCOMING_DELAY ][ "launcher_standard" ] = "missileDelay";
	
	level.bcSounds[ KILL_DIALOG ] = [];
	level.bcSounds[ KILL_DIALOG ][ "assassin" ] =	"killSpectre";
	level.bcSounds[ KILL_DIALOG ][ "grenadier" ] =	"killGrenadier";
	level.bcSounds[ KILL_DIALOG ][ "outrider" ] = 	"killOutrider";
	level.bcSounds[ KILL_DIALOG ][ "prophet" ] = 	"killTechnomancer";
	level.bcSounds[ KILL_DIALOG ][ "pyro" ] = 		"killFirebreak";
	level.bcSounds[ KILL_DIALOG ][ "reaper" ] = 	"killReaper";
	level.bcSounds[ KILL_DIALOG ][ "ruin" ] =		"killMercenary";
	level.bcSounds[ KILL_DIALOG ][ "seraph" ] = 	"killEnforcer";
	level.bcSounds[ KILL_DIALOG ][ "trapper" ] = 	"killTrapper";
	level.bcSounds[ KILL_DIALOG ][ "blackjack" ] = 	"killBlackjack";
	
	if ( level.teambased && !isdefined( game["boostPlayersPicked"] ) )
	{
		game["boostPlayersPicked"] = [];
		foreach ( team in level.teams )
		{
			game["boostPlayersPicked"][ team ] = false;
		}
	}
	
	level.allowbattlechatter = GetGametypeSetting( "allowBattleChatter" );
		
	clientfield::register( "world", "boost_number", VERSION_SHIP, 2, "int" );
	clientfield::register( "allplayers", PLAY_BOOST, VERSION_SHIP, 2, "int" );	
	
	level thread pick_boost_number();
	
	playerDialogBundles = struct::get_script_bundles( "mpdialog_player" );
	foreach( bundle in playerDialogBundles )
	{
		count_keys( bundle, "killGeneric" );
		count_keys( bundle, "killSniper" );
		
		count_keys( bundle, "killSpectre" );
		count_keys( bundle, "killGrenadier");
		count_keys( bundle, "killOutrider" );
		count_keys( bundle, "killTechnomancer" );
		count_keys( bundle, "killFirebreak" );
		count_keys( bundle, "killReaper" );
		count_keys( bundle, "killMercenary" );
		count_keys( bundle, "killEnforcer" );
		count_keys( bundle, "killTrapper" );
		count_keys( bundle, "killBlackjack" );
	}
	
	level.allowSpecialistDialog = mpdialog_value( "enableHeroDialog", 	false ) && level.allowBattlechatter;
	level.playStartConversation = mpdialog_value( "enableConversation",	false ) && level.allowBattlechatter;
}

function pick_boost_number( )
{
	// Don't set client fields on the first frame
	wait( 5 );
	
	level clientfield::set( "boost_number", RandomInt( NUM_BOOSTS ) );
}

function on_joined_team()
{
	self endon( "disconnect" );
	
	if ( level.teambased )
	{
		if ( self.team == "allies" )
		{
			self set_blops_dialog();
		}
		else
		{
			self set_cdp_dialog();
		}
	}
	else
	{
		if ( randomIntRange( 0, 2 ) )
		{
			self set_blops_dialog();
		}
		else
		{
			self set_cdp_dialog();
		}
	}
	
	self globallogic_audio::flush_dialog();
	
	if ( level.disablePrematchMessages === true )
	{
		return;
	}
	
	if ( IS_TRUE( level.inPrematchPeriod ) && !IS_TRUE( self.pers["playedGameMode"] ) && isdefined( level.leaderDialog ) )
	{
		if( level.hardcoreMode )
			self globallogic_audio::leader_dialog_on_player( level.leaderDialog.startHcGameDialog, undefined, undefined, undefined, true );
		else
			self globallogic_audio::leader_dialog_on_player( level.leaderDialog.startGameDialog, undefined, undefined, undefined, true );
		
		self.pers["playedGameMode"] = true;
	}
}

function set_blops_dialog()
{
	self.pers["mptaacom"] = "blops_taacom";
	self.pers["mpcommander"] = "blops_commander";
}

function set_cdp_dialog()
{
	self.pers["mptaacom"] = "cdp_taacom";
	self.pers["mpcommander"] = "cdp_commander";
}

function on_player_connect()
{
	self reset_dialog_fields();
}

function on_player_spawned()
{
	self reset_dialog_fields();

	// help players be stealthy in splitscreen by not announcing their intentions
	if ( level.splitscreen )
	{
		return;
	}
	
	self thread water_vox();
	
	self thread grenade_tracking();
	self thread missile_tracking();
	self thread sticky_grenade_tracking();
	
	// Don't bother with these in non-team games
	if ( level.teambased )
	{
		self thread enemy_threat();
		self thread check_boost_start_conversation();		
	}
}

function reset_dialog_fields()
{
	self.enemyThreatTime = 0;
	self.heartbeatsnd = false; 
	
	self.soundMod = "player";
	
	self.voxUnderwaterTime = 0;
	self.voxEmergeBreath = false;
	self.voxDrowning = false;
	
	self.pilotisSpeaking = false;
	self.playingDialog = false;
	self.playingGadgetReadyDialog = false;
	
	self.playedGadgetSuccess = true;
}

function dialog_chance( chanceKey )
{
	dialogChance = mpdialog_value( chanceKey );
	
	if ( !isdefined( dialogChance ) || dialogChance <= 0 )
	{
		return false;	
	}
	else if ( dialogChance >= 100 )
	{
		return true;
	}
	
	return ( RandomInt( 100 ) < dialogChance );
}

function mpdialog_value( mpdialogKey, defaultValue )
{
	if ( !isdefined( mpdialogKey ) )
	{
		return defaultValue;	
	}
	
	mpdialog = struct::get_script_bundle( "mpdialog", "mpdialog_default" );
	
	if ( !isdefined( mpdialog ) )
	{
		return defaultValue;
	}
	
	structValue = GetStructField( mpdialog, mpdialogKey );
	
	if ( !isdefined( structValue ) )
	{
		return defaultValue;
	}
	
	return structValue;
}

function water_vox()
{
	self endon ( "death" );
	level endon ( "game_ended" );

	while(1)
	{		
		interval = mpdialog_value( "underwaterInterval", SERVER_FRAME );
		
		if ( interval <= 0 )
		{
			assert( interval > 0, "underWaterInterval mpdialog scriptbundle value must be greater than 0" );
			return;
		}
		
		wait ( interval );
		
		if ( self IsPlayerUnderwater() )
		{
			if ( !self.voxUnderwaterTime && !self.voxEmergeBreath )
			{
				self StopSounds();
				self.voxUnderwaterTime = GetTime();
			}
			else if ( self.voxUnderwaterTime )
			{
				if ( GetTime() > self.voxUnderwaterTime + mpdialog_value( "underwaterBreathTime", 0 ) * 1000 )
				{
					self.voxUnderwaterTime = 0;
					self.voxEmergeBreath = true;				
				}
			}
		}
		else
		{
			if ( self.voxDrowning )
			{
				self thread play_dialog( "exertEmergeGasp", DIALOG_FLAG_INTERRUPT | DIALOG_FLAG_EXERT, mpdialog_value( "playerExertBuffer", 0 ) );
				
				self.voxDrowning = false;
				self.voxEmergeBreath = false;
			}
			else if ( self.voxEmergeBreath )
			{
				self thread play_dialog( "exertEmergeBreath", DIALOG_FLAG_INTERRUPT | DIALOG_FLAG_EXERT, mpdialog_value( "playerExertBuffer", 0 ) );
				self.voxEmergeBreath = false;
			}
		}
	}
}


function pain_vox(meansofDeath)
{
	if( dialog_chance( "smallPainChance" ) )
	{			
		if( meansOfDeath == "MOD_DROWN" )
		{
			dialogKey =  "exertPainDrowning";
			self.voxDrowning = true;					
		}
		else if ( meansofDeath == "MOD_FALLING" )
		{
			dialogKey = "exertPainFalling";
		}
		else if ( self IsPlayerUnderwater() )
		{
			dialogKey = "exertPainUnderwater";
		}
		else
		{
			dialogKey =  "exertPain";
		}
		
		exertBuffer = mpdialog_value( "playerExertBuffer", 0 );
		self thread play_dialog( dialogKey, DIALOG_FLAGS_PAIN, exertBuffer );
	}
}

function on_player_suicide_or_team_kill( player, type )
{
	self endon( "death" );
	level endon( "game_ended" );
	
	// make sure that this does not execute in the player killed callback time
	waittillframeend;

	if( !level.teamBased )
	{
		return;
	}
}

function on_player_near_explodable( object,  type )
{
	self endon( "death" );
	level endon( "game_ended" );
}

function enemy_threat()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill ( "weapon_ads" );
		
		if ( self HasPerk( "specialty_quieter" ) )
		{
			continue;
		}
		
		if( self.enemyThreatTime + ( mpdialog_value( "enemyContactInterval", 0 ) * 1000 )  >= getTime() )
		{
			continue;
		}
		
		closest_ally = self get_closest_player_ally( true );
				
		if ( !isdefined ( closest_ally ) )
		{
			continue;
		}
		
		allyRadius = mpdialog_value( "enemyContactAllyRadius", 0 );
		
		if ( DistanceSquared( self.origin, closest_ally.origin ) < allyRadius * allyRadius )
		{
			eyePoint = self getEye();
			dir = AnglesToForward( self GetPlayerAngles() );
			
			dir = dir * mpdialog_value( "enemyContactDistance", 0 );
			
			endPoint = eyePoint + dir;
			
			traceResult = BulletTrace( eyePoint, endPoint, true, self );
			
			if ( isdefined( traceResult["entity"] ) && traceResult["entity"].className == "player" && traceResult["entity"].team != self.team )
			{
				if( dialog_chance( "enemyContactChance" ) )
				{		
					self thread play_dialog( "threatInfantry", DIALOG_FLAG_TEAM );
					
					level notify ( "level_enemy_spotted", self.team);
					
					self.enemyThreatTime = GetTime();
				}	
			}
		}
	}
}	


// self is killed
function killed_by_sniper( sniper )
{
	self endon("disconnect");
	sniper endon("disconnect");
	level endon( "game_ended" );
	
	if ( !level.teamBased )
	{
		return false;
	}
	
	// make sure that this does not execute in the player killed callback time
	waittillframeend;
	
	if( dialog_chance( "sniperKillChance" ) )
	{
		closest_ally = self get_closest_player_ally();	
	
		allyRadius = mpdialog_value( "sniperKillAllyRadius", 0 );
		
		if( isdefined( closest_ally ) && DistanceSquared( self.origin, closest_ally.origin ) < allyRadius * allyRadius )
		{
			closest_ally thread play_dialog( "threatSniper", DIALOG_FLAG_TEAM );
			
			sniper.spottedTime = GetTime();
			sniper.spottedBy = [];
			
			players = self get_friendly_players();
			players = ArraySort( players, self.origin );
		
			voiceRadius = mpdialog_value( "playerVoiceRadius", 0 );
			voiceRadiusSq = voiceRadius * voiceRadius;
			
			foreach( player in players )
			{
				if ( DistanceSquared( closest_ally.origin, player.origin) <= voiceRadiusSq )
				{
					sniper.spottedBy[sniper.spottedBy.size] = player;
				}
			}
		}
	}
}

// self is killed
function player_killed( attacker, killstreakType )
{
	if ( !level.teamBased )
	{
		return;
	}
	
	if ( self === attacker )
	{
		// Play hilarious 'Stop killing yourself' dialog
		return;
	}
	
	// make sure that this does not execute in the player killed callback time
	waittillframeend;
	
	if( isdefined( killstreakType ) )
	{
		if ( !isdefined( level.killstreaks[killstreakType] ) || 
		    !isdefined( level.killstreaks[killstreakType].threatOnKill ) ||
			!level.killstreaks[killstreakType].threatOnKill ||
		    !dialog_chance( "killstreakKillChance" ) )
		{
			return;
		}
		
		ally = battlechatter::get_closest_player_ally( true );
		allyRadius = mpdialog_value( "killstreakKillAllyRadius", 0 );
		
		if ( isdefined( ally ) && DistanceSquared( self.origin, ally.origin ) < allyRadius * allyRadius )
		{
			ally play_killstreak_threat( killstreakType );
		}
	}
}

function say_kill_battle_chatter( attacker, weapon, victim, inflictor )
{
	if ( weapon.skipBattlechatterKill ||
	     !isdefined( attacker ) ||
	     !IsPlayer( attacker ) ||
	     !IsAlive( attacker ) || 
	     attacker IsRemoteControlling() ||
	     attacker IsInVehicle() ||
	     attacker IsWeaponViewOnlyLinked() ||
		 !isdefined( victim ) ||
	     !IsPlayer( victim ) )
	{
		return;
	}
	
	// Don't play kill chatter if the player died since initiating the attack
	if ( isdefined( inflictor ) && !IsPlayer( inflictor ) && inflictor.birthtime < attacker.spawntime )
	{
		return;
	}
	
	if ( weapon.inventorytype == "hero" )
	{
		DEFAULT( attacker.heroweaponKillCount, 0 );
		
		attacker.heroweaponKillCount++;

		if ( !IS_TRUE( attacker.playedGadgetSuccess ) && attacker.heroweaponKillCount === mpdialog_value( "heroWeaponKillCount", 0 ) )
		{
			// TODO: Keep trying to play on each kill until successful
			// TODO: Play to multiple enemies killed together
			attacker thread play_gadget_success( weapon, "enemyKillDelay", victim );
			attacker thread hero_weapon_success_reaction();
		}
	}
	else if ( IS_TRUE( attacker.speedburstOn ) )
	{
		if ( !IS_TRUE( attacker.speedburstKill ) )
		{
			speedBurstKillDist = mpdialog_value( "speedBurstKillDistance", 0 );
			if ( DistanceSquared( attacker.origin, victim.origin ) < speedBurstKillDist * speedBurstKillDist )
			{
				attacker.speedburstKill = true;
			}
		}
	}
	else if ( attacker _gadget_camo::camo_is_inuse( ) || 
	         ( isdefined( attacker.gadget_camo_off_time ) && attacker.gadget_camo_off_time + ( mpdialog_value( "camoKillTime", 0 ) * 1000 ) >= GetTime() ) )
	{
		if ( !IS_TRUE( attacker.playedGadgetSuccess ) )
		{
			attacker thread play_gadget_success( GetWeapon( "gadget_camo" ), "enemyKillDelay", victim );
		}
	}
	else if ( dialog_chance( "enemyKillChance" ) )
	{	
		if ( isdefined( victim.spottedTime ) &&
	         victim.spottedTime + mpdialog_value( "enemySniperKillTime", 0 ) >= GetTime() &&
	         array::contains( victim.spottedBy, attacker ) &&
	         dialog_chance( "enemySniperKillChance" ) )
		{
			killDialog = attacker get_random_key( "killSniper" );
		}
		else if ( dialog_chance( "enemyHeroKillChance" ) )
		{
			victimDialogName = victim GetMpDialogName();
			killDialog = attacker get_random_key( level.bcSounds[ KILL_DIALOG ][ victimDialogName ] );
		}
		else
		{
			killDialog = attacker get_random_key( "killGeneric" );
		}
	}

	// Clear sniper spotted fields
	victim.spottedTime = undefined;
	victim.spottedBy = undefined;
	
	if ( !isdefined( killDialog ) )
	{
		return;
	}

	attacker thread wait_play_dialog( mpdialog_value( "enemyKillDelay", 0 ), killDialog, DIALOG_FLAG_TEAM, undefined, victim, "cancel_kill_dialog" );
}


function grenade_tracking()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	while(1)
	{
		self waittill ( "grenade_fire", grenade, weapon );

		if ( !isdefined( grenade.weapon ) ||
		     !isdefined( grenade.weapon.rootweapon ) ||
		     !dialog_chance( "incomingProjectileChance" ) )
		{
			continue;
		}
		
		dialogKey = level.bcSounds[ INCOMING_ALERT ][ grenade.weapon.rootweapon.name ];
		
		if ( isdefined( dialogKey ) )
		{
			waittime = mpdialog_value( level.bcSounds[ INCOMING_DELAY ][ grenade.weapon.rootweapon.name ], SERVER_FRAME );
			level thread incoming_projectile_alert( self, grenade, dialogKey, waittime );
		}
	}
}

function missile_tracking()
{
	self endon( "death" );
	level endon( "game_ended" );

	while(1)
	{	
		self waittill ( "missile_fire", missile, weapon );
		
		if ( !isdefined( missile.item ) ||
		     !isdefined( missile.item.rootweapon ) ||
		     !dialog_chance( "incomingProjectileChance" ) )
		{
			continue;
		}
		
		dialogKey = level.bcSounds[ INCOMING_ALERT ][ missile.item.rootweapon.name ];
		
		if ( isdefined ( dialogKey ) )
		{
			waittime = mpdialog_value( level.bcSounds[ INCOMING_DELAY ][ missile.item.rootweapon.name ], SERVER_FRAME );
			level thread incoming_projectile_alert( self, missile, dialogKey, waittime );	
		}
	}
}

function incoming_projectile_alert( thrower, projectile, dialogKey, waittime )
{	
	level endon( "game_ended" );
	if ( waittime <= 0 )
	{
		assert( waittime > 0, "incoming_projectile_alert waittime must be greater than 0" );
		return;
	}
		
	while(1)
	{
		wait( waittime );
		
		// HACK: This is a crazy way to try and trigger the warning more often
		if ( waittime > 0.2 )
		{
			waittime = waittime / 2;
		}
		
		// The projectile may have blown up or the like while waiting
		if ( !isdefined( projectile ) )
		{
			return;
		}
		
		//Check if player threw grenade and then quit or switched to spectator
		if( !isdefined( thrower ) || thrower.team == "spectator" )
		{
			return;
		}
	
		if( ( level.players.size ) )			
		{
			closest_enemy = thrower get_closest_player_enemy( projectile.origin );
	
			incomingProjectileRadius = mpdialog_value( "incomingProjectileRadius", 0 );
			
			if( isdefined( closest_enemy ) && DistanceSquared( projectile.origin, closest_enemy.origin ) < incomingProjectileRadius * incomingProjectileRadius )
			{		
				closest_enemy thread play_dialog( dialogKey, DIALOG_FLAGS_SHOUT );
				return;
			}
		}
	}
}

function sticky_grenade_tracking()
{
	self endon( "death" );
	level endon( "game_ended" );

	while(1)
	{
		self waittill ( "grenade_stuck", grenade );

		if ( IsAlive( self ) && isdefined( grenade ) && isdefined( grenade.weapon ) )
		{
			if ( grenade.weapon.rootweapon.name == "sticky_grenade" )
			{
				self thread play_dialog( "stuckSticky", DIALOG_FLAGS_SHOUT );
			}
		}
	}
}

function hero_weapon_success_reaction()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	if ( !level.teambased )
	{
		return;
	}
	
	allies = [];
	
	allyRadiusSq = mpdialog_value( "playerVoiceRadius", 0 );
	allyRadiusSq *= allyRadiusSq;
	
	foreach( player in level.players )
	{
		if ( !isdefined( player ) ||
			 !IsAlive( player )	||
			 player.sessionstate != "playing" ||
 			 player == self	||
			 player.team != self.team )
		{
			continue;
		}
	
		distSq = DistanceSquared( self.origin, player.origin );
		
		if ( distSq > allyRadiusSq )
		{
			continue;
		}
		
		allies[allies.size] = player;	
	}
	
	// First do the kill delay wait
	wait( mpdialog_value( "enemyKillDelay", 0 ) + 0.1 );
	
	// Wait for the player to finish talking
	while ( self.playingDialog )
	{
		wait( 0.5 );
	}
	
	allies = ArraySort( allies, self.origin );
	
	foreach( player in allies )
	{
		if ( !IsAlive( player ) ||
		     player.sessionstate != "playing" ||
		     player.playingDialog ||
		     player IsPlayerUnderwater() ||
		     player IsRemoteControlling() ||
		     player IsInVehicle() ||
		     player IsWeaponViewOnlyLinked() )
		{
			continue;
		}
		
		distSq = DistanceSquared( self.origin, player.origin );
		
		if ( distSq > allyRadiusSq )
		{
			break;
		}
		
		player play_dialog( "heroWeaponSuccessReaction", DIALOG_FLAG_TEAM );
		break;
	}
}

function play_promotion_reaction()
{
	self endon( "death" );
	level endon( "game_ended" );
	
	if ( !level.teambased )
	{
		return;
	}

	// Wait for the music cue to finish / start fading
	wait 9;
	
	players = self get_friendly_players();
	players = ArraySort( players, self.origin );

	selfDialog = self GetMpDialogName();
	voiceRadius = mpdialog_value( "playerVoiceRadius", 0 );
	voiceRadiusSq = voiceRadius * voiceRadius;
	
	foreach( player in players )
	{
		if ( player == self ||
		     player GetMpDialogName() == selfDialog ||
			 !player can_play_dialog( true ) ||
			 DistanceSquared( self.origin, player.origin ) >= voiceRadiusSq )
		{
			continue;
		}
		
		dialogAlias = player get_player_dialog_alias( "promotionReaction" );
		
		if ( !isdefined( dialogAlias ) )
		{
			continue;
		}
		
		ally = player;
		break;
	}
	
	if ( isdefined( ally ) )
	{
		ally PlaySoundOnTag( dialogAlias, VOICE_TAG, undefined, self );
		// The ally won't know why they can't talk, but they won't interrupt themselves either
		ally thread wait_dialog_buffer( mpdialog_value( "playerDialogBuffer", 0 ) );
	}
}

function gametype_specific_battle_chatter( event, team )
{
	self endon ( "death" );
	level endon( "game_ended" );
}

function play_death_vox( body, attacker, weapon, meansOfDeath )
{
	dialogKey = self get_death_vox( weapon, meansOfDeath );
	dialogAlias = self get_player_dialog_alias( dialogKey );
	
	if ( isdefined( dialogAlias ) )
	{
		body PlaySoundOnTag( dialogAlias, VOICE_TAG );
	}
}

function get_death_vox( weapon, meansOfDeath )
{
	// Always play drowned if underwater
	if ( self IsPlayerUnderwater() )
	{
		return "exertDeathDrowned";
	}
	
	if ( isdefined( meansOfDeath ) )
	{
		switch( meansOfDeath )
		{
			case "MOD_BURNED":
				return "exertDeathBurned";
			case "MOD_DROWN":
				return "exertDeathDrowned";
		}
	}
	
	if ( isdefined( weapon ) && meansOfDeath !== "MOD_MELEE_WEAPON_BUTT" )
	{
		switch( weapon.rootweapon.name )
		{
			case "knife_loadout":
			case "hatchet":
			case "hero_armblade":
				return "exertDeathStabbed";
			case "hero_firefly_swarm":
				return "exertDeathBurned";
			case "hero_lightninggun_arc":
				return "exertDeathElectrocuted";
		}
	}
	
	return "exertDeath";
}

function play_killstreak_threat( killstreakType )
{
	if ( !isdefined( killstreakType ) || !isdefined( level.killstreaks[killstreakType] ) )
	{
		return;
	}
	
	self thread play_dialog( level.killstreaks[killstreakType].threatDialogKey, DIALOG_FLAG_TEAM );
}

function wait_play_dialog( waitTime, dialogKey, dialogFlags, dialogBuffer, enemy, endNotify )
{
	self endon( "death" );
	level endon( "game_ended" );
	
	if (isdefined( waitTime) && waitTime > 0 )
	{
		if ( isdefined( endNotify ) )
		{
			self endon( endNotify );
		}
		
		wait ( waitTime );
	}
	
	self thread play_dialog( dialogKey, dialogFlags, dialogBuffer, enemy );
}

function play_dialog( dialogKey, dialogFlags, dialogBuffer, enemy )
{
	self endon( "death" );
	level endon( "game_ended" );
	
	if ( !isdefined( dialogKey ) ||
    	 !IsPlayer( self ) ||
    	 !IsAlive( self ) ||
		 level.gameEnded )
	{
		return;
	}
	
	if ( !isdefined( dialogFlags ) )
	{
		dialogFlags = 0;
	}
	
	if ( !level.allowSpecialistDialog && ( dialogFlags & DIALOG_FLAG_EXERT ) == 0 )
	{
		return;
	}
	
	if ( !isdefined( dialogBuffer ) )
	{
		dialogBuffer = mpdialog_value( "playerDialogBuffer", 0 );
	}
	
	dialogAlias = self get_player_dialog_alias( dialogKey );
	
 	if ( !isdefined( dialogAlias ) )
 	{
 		return;
 	}

 	if ( self IsPlayerUnderwater() && !( dialogFlags & DIALOG_FLAG_UNDERWATER ) )
	{
		return;
	}
	
	if ( self.playingDialog )
	{
		if ( !( dialogFlags & DIALOG_FLAG_INTERRUPT ) )
		{
			return;
		}
		
		self StopSounds();
		
		WAIT_SERVER_FRAME;
	}
	
	if ( dialogFlags & DIALOG_FLAG_GADGET_READY )
	{
		self.playingGadgetReadyDialog = true;
	}
	
	if ( dialogFlags & DIALOG_FLAG_STOLEN_GADGET_READY )
	{
		DEFAULT( self.stolenDialogIndex, 0 );
		
		dialogAlias = dialogAlias + "_0" + self.stolenDialogIndex;
		
		self.stolenDialogIndex++;
		self.stolenDialogIndex = self.stolenDialogIndex % STOLEN_GADGET_READY_LINE_COUNT;
	}
	
	if ( dialogFlags & DIALOG_FLAG_ALL )
	{
		// Plays to all teams
		self PlaySoundOnTag( dialogAlias, VOICE_TAG );	
	}
	else if ( dialogFlags & DIALOG_FLAG_TEAM )
	{
		// Plays to current team
		if ( isdefined( enemy ) )
		{
			// And the specified enemy
			self PlaySoundOnTag( dialogAlias, VOICE_TAG, self.team, enemy );
		}
		else
		{
			self PlaySoundOnTag( dialogAlias, VOICE_TAG, self.team );
		}
	}
	else
	{
		self PlayLocalSound( dialogAlias );
	}
	
	// FUTURE: Pass dialogKey, dialogBuffer if useful
	self notify( "played_dialog" );
	
	self thread wait_dialog_buffer( dialogBuffer );
}

function wait_dialog_buffer( dialogBuffer )
{
	self endon( "death" );
	self endon( "played_dialog" );
	self endon( "stop_dialog" );
	level endon( "game_ended" );

	self.playingDialog = true;
	
	if ( isdefined( dialogBuffer ) && dialogBuffer > 0 )
	{
		wait ( dialogBuffer );
	}
	
	self.playingDialog = false;
	self.playingGadgetReadyDialog = false;
}

function stop_dialog()
{
	self notify( "stop_dialog" );
	
	self StopSounds();
	
	self.playingDialog = false;
	self.playingGadgetReadyDialog = false;
}

function wait_playback_time( soundAlias )
{
	//self endon( "death" );
	//level endon( "game_ended" );
}

function get_player_dialog_alias( dialogKey )
{
	if ( !IsPlayer( self ) )
	{
		return undefined;
	}
	
	bundleName = self GetMpDialogName();
	
	if ( !isdefined( bundleName ) )
	{
		return undefined;
	}
	
	playerBundle = struct::get_script_bundle( "mpdialog_player", bundleName );
	
	if ( !isdefined( playerBundle ) )
	{
		return undefined;
	}
	
	return globallogic_audio::get_dialog_bundle_alias( playerBundle, dialogKey );
}

function count_keys( bundle, dialogKey )
{
	i = 0;
	field = dialogKey + i;
	fieldValue = GetStructField( bundle, field );
	
	while ( isdefined( fieldValue ) )
	{
		aliasArray[i] = fieldValue;
		
		i++;
		field = dialogKey + i;
		fieldValue = GetStructField( bundle, field );
	}
	
	if ( !isdefined( bundle.keyCounts ) )
	{
		bundle.keyCounts = [];
	}
	
	bundle.keyCounts[dialogKey] = i;
}

function get_random_key( dialogKey )
{
	bundleName = self GetMpDialogName();
	
	if ( !isdefined( bundleName ) )
	{
		return undefined;
	}
	
	playerBundle = struct::get_script_bundle( "mpdialog_player", bundleName );
	
	if ( !isdefined( playerBundle ) ||
	     !isdefined( playerBundle.keyCounts ) ||
	     !isdefined( playerBundle.keyCounts[dialogKey] ) )
    {
		return dialogKey;
    }
	
	return dialogKey + RandomInt( playerBundle.keyCounts[dialogKey] );
}

// These are called from shared scripts via function pointers
function play_gadget_ready( weapon, userFlip = false )
{
	if ( !isdefined( weapon ) )
		return;
	
	dialogKey = undefined;
	
	switch( weapon.name )
	{
		case "hero_gravityspikes":
			dialogKey = "gravspikesWeaponReady";
			break;
		case "gadget_speed_burst":
			dialogKey = "overdriveAbilityReady";
			break;
		case "hero_bowlauncher":
		case "hero_bowlauncher2":
		case "hero_bowlauncher3":
		case "hero_bowlauncher4":
			dialogKey = "sparrowWeaponReady";
			break;
		case "gadget_vision_pulse":
			dialogKey = "visionpulseAbilityReady";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			dialogKey = "tempestWeaponReady";
			break;
		case "gadget_flashback":
			dialogKey = "glitchAbilityReady";
			break;
		case "hero_pineapplegun":
			dialogKey = "warmachineWeaponREady";
			break;
		case "gadget_armor":
			dialogKey = "kineticArmorAbilityReady";
			break;
		case "hero_annihilator":
			dialogKey = "annihilatorWeaponReady";
			break;
		case "gadget_combat_efficiency":
			dialogKey = "combatfocusAbilityReady";
			break;
		case "hero_chemicalgelgun":
			dialogKey = "hiveWeaponReady";
			break;
		case "gadget_resurrect":
			dialogKey = "rejackAbilityReady";
			break;
		case "hero_minigun":
		case "hero_minigun_body3":
			dialogKey = "scytheWeaponReady";
			break;
		case "gadget_clone":
			dialogKey = "psychosisAbilityReady";
			break;
		case "hero_armblade":
			dialogKey = "ripperWeaponReady";
			break;
		case "gadget_camo":
			dialogKey = "activeCamoAbilityReady";
			break;
		case "hero_flamethrower":
			dialogKey = "purifierWeaponReady";
			break;
		case "gadget_heat_wave":
			dialogKey = "heatwaveAbilityReady";
			break;
		default:
			return;
	}
	
	// Just a regular ready
	if ( !IS_TRUE( self.isThief ) && !IS_TRUE( self.isRoulette ) )
	{
		self thread play_dialog( dialogKey );
		return;
	}
	
	waitTime = 0;
	dialogFlags = DIALOG_FLAG_GADGET_READY;
	
	if ( userFlip ) // User flipped or rerolled, kill the previous gadget dialog
	{	
		minWaitTime = 0;
		if ( self.playingGadgetReadyDialog )
		{
			self stop_dialog();
			minWaitTime = SERVER_FRAME; // Make sure dialog stops
		}
		
		if ( IS_TRUE( self.isThief ) )
		{
			delayKey = "thiefFlipDelay";
		}
		else
		{
			delayKey = "rouletteFlipDelay";
		}
		
		waitTime = mpdialog_value( delayKey, minWaitTime );
		dialogFlags += DIALOG_FLAG_STOLEN_GADGET_READY;
	}
	else // Initial roll or stolen weapon		
	{
		if ( IS_TRUE( self.isThief ) )
		{
			genericKey = "thiefWeaponReady";
			repeatKey = "thiefWeaponRepeat";
			repeatThresholdKey = "thiefRepeatThreshold";
			chanceKey = "thiefReadyChance";
			delayKey = "thiefRevealDelay";
		}
		else
		{
			genericKey = "rouletteAbilityReady";
			repeatKey = "rouletteAbilityRepeat";
			repeatThresholdKey = "rouletteRepeatThreshold";
			chanceKey = "rouletteReadyChance";
			delayKey = "rouletteRevealDelay";
		}
		
		if ( RandomInt( 100 ) < mpdialog_value( chanceKey, 0 ) )
		{
			// Play generic earned dialog
			dialogKey = genericKey;
		}
		else
		{
			waitTime = mpdialog_value( delayKey, 0 );
			
			if ( self.lastStolenGadget === weapon &&
			     ( self.lastStolenGadgetTime + mpdialog_value( repeatThresholdKey, 0 ) * 1000 ) > GetTime() )
			{
				// Play duplicate earned dialog
				dialogKey = repeatKey;
			}
			else
			{
				dialogFlags += DIALOG_FLAG_STOLEN_GADGET_READY;
			}
		}
	}
	
	self.lastStolenGadget = weapon;
	self.lastStolenGadgetTime = GetTime();
	
	if ( waitTime )	// Generic lines play instantly
	{
		// As long as we're not playing dialog, block any kill lines coming in to play the gadget ready
		self notify( "cancel_kill_dialog" );
	}
	
	self thread wait_play_dialog( waitTime, dialogKey, dialogFlags );
}

function play_gadget_activate( weapon )
{
	if ( !isdefined( weapon ) )
		return;
	
	dialogKey = undefined;
	
	switch( weapon.name )
	{
		case "hero_gravityspikes":
			dialogKey = "gravspikesWeaponUse";
			dialogFlags = DIALOG_FLAGS_SHOUT | DIALOG_FLAG_EXERT;
			dialogBuffer = 0.05;
			break;
		case "gadget_speed_burst":
			dialogKey = "overdriveAbilityUse";
			break;
		case "hero_bowlauncher":
		case "hero_bowlauncher2":
		case "hero_bowlauncher3":
		case "hero_bowlauncher4":
			dialogKey = "sparrowWeaponUse";
			break;
		case "gadget_vision_pulse":
			dialogKey = "visionpulseAbilityUse";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			dialogKey = "tempestWeaponUse";
			break;
		case "gadget_flashback":
			dialogKey = "glitchAbilityUse";
			break;
		case "hero_pineapplegun":
			dialogKey = "warmachineWeaponUse";
			break;
		case "gadget_armor":
			dialogKey = "kineticArmorAbilityUse";
			break;
		case "hero_annihilator":
			dialogKey = "annihilatorWeaponUse";
			break;
		case "gadget_combat_efficiency":
			dialogKey = "combatfocusAbilityUse";
			break;
		case "hero_chemicalgelgun":
			dialogKey = "hiveWeaponUse";
			break;
		case "gadget_resurrect":
			dialogKey = "rejackAbilityUse";
			break;
		case "hero_minigun":
		case "hero_minigun_body3":
			dialogKey = "scytheWeaponUse";
			break;
		case "gadget_clone":
			dialogKey = "psychosisAbilityUse";
			break;
		case "hero_armblade":
			dialogKey = "ripperWeaponUse";
			break;
		case "gadget_camo":
			dialogKey = "activeCamoAbilityUse";
			break;
		case "hero_flamethrower":
			dialogKey = "purifierWeaponUse";
			break;
		case "gadget_heat_wave":
			dialogKey = "heatwaveAbilityUse";
			break;
		default:
			return;
	}
	
	self thread play_dialog( dialogKey, dialogFlags, dialogBuffer );
}

function play_gadget_success( weapon, waitKey, victim )
{
	if ( !isdefined( weapon ) )
		return;
	
	dialogKey = undefined;
	
	switch( weapon.name )
	{
		case "hero_gravityspikes":
			dialogKey = "gravspikesWeaponSuccess";
			break;
		case "gadget_speed_burst":
			dialogKey = "overdriveAbilitySuccess";
			break;
		case "hero_bowlauncher":
		case "hero_bowlauncher2":
		case "hero_bowlauncher3":
		case "hero_bowlauncher4":
			dialogKey = "sparrowWeaponSuccess";
			break;
		case "gadget_vision_pulse":
			dialogKey = "visionpulseAbilitySuccess";
			break;
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			dialogKey = "tempestWeaponSuccess";
			break;
		case "gadget_flashback":
			dialogKey = "glitchAbilitySuccess";
			break;
		case "hero_pineapplegun":
			dialogKey = "warmachineWeaponSuccess";
			break;
		case "gadget_armor":
			dialogKey = "kineticArmorAbilitySuccess";
			break;
		case "hero_annihilator":
			dialogKey = "annihilatorWeaponSuccess";
			break;
		case "gadget_combat_efficiency":
			dialogKey = "combatfocusAbilitySuccess";
			break;
		case "hero_chemicalgelgun":
			dialogKey = "hiveWeaponSuccess";
			break;
		case "gadget_resurrect":
			dialogKey = "rejackAbilitySuccess";
			break;
		case "hero_minigun":
		case "hero_minigun_body3":
			dialogKey = "scytheWeaponSuccess";
			break;
		case "gadget_clone":
			dialogKey = "psychosisAbilitySuccess";
			break;
		case "hero_armblade":
			dialogKey = "ripperWeaponSuccess";
			break;
		case "gadget_camo":
			dialogKey = "activeCamoAbilitySuccess";
			break;
		case "hero_flamethrower":
			dialogKey = "purifierWeaponSuccess";
			break;
		case "gadget_heat_wave":
			dialogKey = "heatwaveAbilitySuccess";
			break;
		default:
			return;
	}
	
	if ( isdefined( waitKey ) )
	{
		waitTime = mpdialog_value( waitKey, 0 );
	}

	//dialogKey = get_random_key( dialogKey );
	dialogKey = dialogKey + "0";
	
	self.playedGadgetSuccess = true;
	self thread wait_play_dialog( waitTime, dialogKey, DIALOG_FLAG_TEAM, undefined, victim );
}

function play_throw_hatchet()
{
	self thread play_dialog( "exertAxeThrow", DIALOG_FLAG_TEAM | DIALOG_FLAG_INTERRUPT | DIALOG_FLAG_EXERT, mpdialog_value( "playerExertBuffer", 0 ) );
}

// Utils for getting enemies / allies

function get_enemy_players()
{
	players = [];
	
	if ( level.teambased )
	{
		foreach( team in level.teams )
		{
			if ( team == self.team )
			{
				continue;
			}
			
			foreach( player in level.alivePlayers[team] )
			{
				players[players.size] = player;
			}
		}
	}
	else
	{
		foreach( player in level.activeplayers )
		{
			if ( player != self )
			{
				players[players.size] = player;
			}
		}
	}
	
	return players;
}

function get_friendly_players()
{
	players = [];
	
	if ( level.teambased )
	{
		foreach( player in level.alivePlayers[self.team] )
		{
			players[players.size] = player;
		}
	}
	else
	{
		players[0] = self;
	}
	
	return players;
}

function can_play_dialog( teamOnly )
{
	if ( !IsPlayer( self ) ||
	     !IsAlive( self ) ||
	     self.playingDialog === true ||
	     self IsPlayerUnderwater() ||
	     self IsRemoteControlling() ||
	     self IsInVehicle() ||
	     self IsWeaponViewOnlyLinked() )
	{
		return false;
	}

	if ( isdefined( teamOnly ) && !teamOnly && self HasPerk( "specialty_quieter" ) )
	{
		return false;
	}
	
	return true;
}

// Call this on the owning/controlling/attacking player to keep them from being picked in non-team games
function get_closest_player_enemy( origin, teamOnly )
{
	DEFAULT( origin, self.origin );
	
	players = self get_enemy_players();
	players = ArraySort( players, origin );

	foreach( player in players )
	{
		if( !player can_play_dialog( teamOnly ) )
		{
			continue;
		}
		
		return player;
	}

	return undefined;
}

function get_closest_player_ally( teamOnly )
{
	if ( !level.teambased )
	{
		return undefined;
	}

	players = self get_friendly_players();
	players = ArraySort( players, self.origin );

	foreach( player in players )
	{
		if ( player == self ||
			!player can_play_dialog( teamOnly ) )
		{
			continue;
		}
		
		return player;
	}

	return undefined;
}

// Boost Start conversation

function check_boost_start_conversation()
{
	if ( !level.playStartConversation )
	{
		return;
	}
	
	if ( !level.inPrematchPeriod ||
	     !level.teambased ||
	     game["boostPlayersPicked"][ self.team ] )
	{
		return;
	}
	
	players = self get_friendly_players();
	
	// The spawned player isn't in level.alivePlayers yet
	array::add( players, self, false );

	players = array::randomize( players );
	
	playerIndex = 1;
	foreach( player in players )
	{	
		playerDialog = player GetMpDialogName();
		
		for( i = playerIndex; i < players.size; i++ )
		{
			playerI = players[i];
			
			if ( playerDialog != playerI GetMpDialogName() )
			{
				pick_boost_players( player, playerI );
				return;
			}
		}
		
		playerIndex++;
	}
}

function pick_boost_players( player1, player2 )
{	
	player1 clientfield::set( PLAY_BOOST, BOOST_START );
	player2 clientfield::set( PLAY_BOOST, BOOST_RESPONSE );
	
	game["boostPlayersPicked"][player1.team] = true;
}

// Game end dialog

function game_end_vox( winner )
{
	if ( !level.allowSpecialistDialog )
	{
		return;
	}
	
	gameIsDraw = !isdefined( winner ) || ( level.teamBased && winner == "tie" );
	
	foreach( player in level.players )
	{	
		if ( player IsSplitScreen() )
		{
			continue;
		}
		
		if ( gameIsDraw )
		{
			dialogKey = "boostDraw";
		}
		else if ( ( level.teamBased && isdefined( level.teams[ winner ] ) && player.pers["team"] == winner ) ||
		          ( !level.teamBased && player == winner ) )
		{
          	dialogKey = "boostWin";
		}
		else
		{
			dialogKey = "boostLoss";
		}
		
		dialogAlias = player get_player_dialog_alias( dialogKey );
		
		if ( isdefined( dialogAlias ) )
		{
			player PlayLocalSound( dialogAlias );
		}
	}
}

