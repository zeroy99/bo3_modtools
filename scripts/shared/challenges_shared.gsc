#using scripts\codescripts\struct;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\callbacks_shared;
#using scripts\shared\drown;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#namespace challenges;

function init_shared()
{
}
	
function pickedUpBallisticKnife()
{
	self.retreivedBlades++;
}

// used to be in _helicopter.gsc
function trackAssists( attacker, damage, isFlare )
{
	if ( !isdefined( self.flareAttackerDamage ) )
	{
		self.flareAttackerDamage = [];
	}

	if ( isdefined ( isFlare ) && isFlare == true ) 
	{
		self.flareAttackerDamage[attacker.clientid] = true;
	}
	else
	{
		self.flareAttackerDamage[attacker.clientid] = false;
	}
}

function destroyedEquipment( weapon )
{
	if ( IsDefined( weapon ) && weapon.isEmp )
	{
		if ( self util::is_item_purchased( "emp_grenade" ) )
		{
			self AddPlayerStat( "destroy_equipment_with_emp_grenade", 1 );
		}
		self AddWeaponStat( weapon, "combatRecordStat", 1 );
		if ( self util::has_hacker_perk_purchased_and_equipped() )
	    {
	    	self AddPlayerStat( "destroy_equipment_with_emp_engineer", 1 );
	    	self AddPlayerStat( "destroy_equipment_engineer", 1 );
	    }
	}
	else if ( self util::has_hacker_perk_purchased_and_equipped() )
	{
		self AddPlayerStat( "destroy_equipment_engineer", 1 );
	}
	self AddPlayerStat( "destroy_equipment", 1 );

	if ( IsDefined( weapon ) && weapon.isBulletWeapon )
	{
		self AddPlayerStat( "destroy_equipment_with_bullet", 1 );
	}

	self challenges::hackedOrDestroyedEquipment();
}

function destroyedTacticalInsert()
{
	if ( !isdefined( self.pers["tacticalInsertsDestroyed"] ) )
	{
		self.pers["tacticalInsertsDestroyed"] = 0;
	}
	self.pers["tacticalInsertsDestroyed"]++;
	if ( self.pers["tacticalInsertsDestroyed"] >= 5 ) 
	{
		self.pers["tacticalInsertsDestroyed"] = 0;
		self AddPlayerStat( "destroy_5_tactical_inserts", 1 );
	}
}

function addFlySwatterStat( weapon, aircraft )
{
		if ( !isdefined( self.pers[ "flyswattercount" ] ) )
		{
			self.pers[ "flyswattercount" ] = 0;
		}
		
		self AddWeaponStat( weapon, "destroyed_aircraft", 1 );
		
		self.pers[ "flyswattercount" ]++;
		
		if ( self.pers[ "flyswattercount" ] == 5 )
		{
			self AddWeaponStat( weapon, "destroyed_5_aircraft", 1 );
		}
		
		if ( isdefined( aircraft ) && isdefined( aircraft.birthTime ) )
		{
			if ( ( GetTime() - aircraft.birthTime ) < 20000 )
			{
				self AddWeaponStat( weapon, "destroyed_aircraft_under20s", 1 );
			}
		}

		if ( !isdefined( self.destroyedAircraftTime ) )
		{
			self.destroyedAircraftTime = [];
		}
		
		if ( ( isdefined( self.destroyedAircraftTime[ weapon ] ) ) && ( ( GetTime() - self.destroyedAircraftTime[ weapon ] ) < 10000 ) )
		{
			self AddWeaponStat( weapon, "destroyed_2aircraft_quickly", 1 );
			self.destroyedAircraftTime[ weapon ] = undefined;
		}
		else
		{
			self.destroyedAircraftTime[ weapon ] = GetTime();
		}
}

function destroyNonAirScoreStreak_PostStatsLock( weapon )
{
	// this function is being used to add weapon stat using "destroyed_aircraft" since we cannot change the statsmilestone3.csv

	self AddWeaponStat( weapon, "destroyed_aircraft", 1 );	// "destroyed_aircraft" now means any destroyed killstreak
}

function canProcessChallenges()
{
/#	
	if ( GetDvarInt( "scr_debug_challenges", 0 ) ) 
		return true;
#/

	if ( level.rankedMatch || level.arenaMatch || level.wagerMatch || SessionModeIsCampaignGame() )
	{
		return true;
	}
	
	return false;
}


function initTeamChallenges( team )
{
	if ( !isdefined( game["challenge"] ) ) 
	{
		game["challenge"] = [];
	}
	
	if ( !isdefined ( game["challenge"][team] ) )
	{
		game["challenge"][team] = [];
		game["challenge"][team]["plantedBomb"] = false;
		game["challenge"][team]["destroyedBombSite"] = false;
		game["challenge"][team]["capturedFlag"] = false;
	}
	game["challenge"][team]["allAlive"] = true;
}

function registerChallengesCallback(callback, func)
{
	if (!isdefined(level.ChallengesCallbacks[callback]))
		level.ChallengesCallbacks[callback] = [];
	level.ChallengesCallbacks[callback][level.ChallengesCallbacks[callback].size] = func;
}

function doChallengeCallback( callback, data )
{
	if ( !isdefined( level.ChallengesCallbacks ) )
		return;		
			
	if ( !isdefined( level.ChallengesCallbacks[callback] ) )
		return;
	
	if ( isdefined( data ) ) 
	{
		for ( i = 0; i < level.ChallengesCallbacks[callback].size; i++ )
			thread [[level.ChallengesCallbacks[callback][i]]]( data );
	}
	else 
	{
		for ( i = 0; i < level.ChallengesCallbacks[callback].size; i++ )
			thread [[level.ChallengesCallbacks[callback][i]]]();
	}
}

function on_player_connect()
{
	self thread initChallengeData();
	self thread spawnWatcher();
	self thread monitorReloads();
}

function monitorReloads()
{
	self endon("disconnect");
	self endon("killMonitorReloads");
	
	while(1)
	{
		self waittill("reload");
		currentWeapon = self getCurrentWeapon();
		if ( currentWeapon == level.weaponNone ) 
		{
			continue;
		}
		
		time = getTime();
		self.lastReloadTime = time;
		
		if ( WeaponHasAttachment( currentWeapon, "supply" ) || WeaponHasAttachment( currentWeapon, "dualclip" ) )
		{
			self thread reloadThenKill( currentWeapon );
		}
	}
}

function reloadThenKill( reloadWeapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "reloadThenKillTimedOut" );
	self notify( "reloadThenKillStart" ); // kill dupliate self and duplicate timeout
	self endon( "reloadThenKillStart" ); // Singleton

	self thread reloadThenKillTimeOut( 5 );	

	for( ;; )
	{
		self waittill ("killed_enemy_player", time, weapon );
		if ( reloadWeapon == weapon )
		{
			self AddPlayerStat( "reload_then_kill_dualclip", 1 );
		}
	}
}

	
function reloadThenKillTimeOut( time )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "reloadThenKillStart" );
	wait( time );
	self notify( "reloadThenKillTimedOut" );
}

function initChallengeData()
{	
	self.pers["bulletStreak"] = 0;
	self.pers["lastBulletKillTime"] = 0;
	self.pers["stickExplosiveKill"] = 0;
	self.pers["carepackagesCalled"] = 0;
	self.explosiveInfo = [];
}


function isDamageFromPlayerControlledAITank( eAttacker, eInflictor, weapon )
{
	if ( weapon.name == "ai_tank_drone_gun" ) 
	{
		if ( isdefined( eAttacker ) && isdefined( eAttacker.remoteWeapon ) && isdefined( eInflictor ) )
		{
			if ( IS_TRUE( eInflictor.controlled ) )
			{
				if ( eAttacker.remoteWeapon	== eInflictor )
				{
					return true;
				}
			}
		}
	}
	else if ( weapon.name == "ai_tank_drone_rocket" )
	{
		if ( isdefined( eInflictor ) && !isdefined( eInflictor.from_ai ) )
		{
			return true;
		}
	}
	return false;
}

function isDamageFromPlayerControlledSentry( eAttacker, eInflictor, weapon )
{
	if ( weapon.name == "auto_gun_turret" )
	{
		if ( isdefined( eAttacker ) && isdefined( eAttacker.remoteWeapon ) && isdefined( eInflictor ) )
		{
			if ( eAttacker.remoteWeapon	== eInflictor )
			{
				if ( IS_TRUE( eInflictor.controlled ) )
				{
					return true;
				}
			}
		}
	}
	return false;
}

function perkKills( victim, isStunned, time )
{
	player = self;
	if ( player hasPerk( "specialty_movefaster" ) )
	{
		player AddPlayerStat( "perk_movefaster_kills", 1 );
	}
	if ( player hasPerk( "specialty_noname" ) )
	{
		player AddPlayerStat( "perk_noname_kills", 1 );
	}
	if ( player hasPerk( "specialty_quieter" ) )
	{
		player AddPlayerStat( "perk_quieter_kills", 1 );
	}
	if ( player hasPerk( "specialty_longersprint" ) )
	{
		if ( isdefined ( player.lastSprintTime ) && ( GetTime() - player.lastSprintTime ) < 2500 )
		{
			player AddPlayerStat( "perk_longersprint", 1 );
		}
	}
	if ( player hasPerk( "specialty_fastmantle" ) )
	{
		if ( ( isdefined ( player.lastSprintTime ) && ( GetTime() - player.lastSprintTime ) < 2500 ) && ( player PlayerAds() >= 1 ) )
		{
			player AddPlayerStat( "perk_fastmantle_kills", 1 );
		}
	}
	if ( player hasPerk( "specialty_loudenemies" ) )
	{
		player AddPlayerStat( "perk_loudenemies_kills", 1 );
	}

	if ( isStunned == true && player hasPerk( "specialty_stunprotection" ) )
	{
		player AddPlayerStat( "perk_protection_stun_kills", 1 );
	}
	
	activeEnemyEmp = false;
	activeCUAV = false ;
	if ( level.teambased ) 
	{
		foreach( team in level.teams )
		{
			assert( isdefined( level.activeCounterUAVs[ team ] ) );
			assert( isdefined( level.ActiveEMPs[ team ] ) );

			if ( team == player.team )
			{
				continue;
			}
			
			if ( level.activeCounterUAVs[team] > 0 )
			{
				activeCUAV = true;
			}
			
			if( level.ActiveEMPs[ team ] > 0 )
			{
				activeEnemyEmp = true;
			}
		}
	}
	else
	{
		assert( isdefined( level.activeCounterUAVs[ victim.entNum ] ) );
		assert( isdefined( level.ActiveEMPs[ victim.entNum ] ) );
	
		players = level.players;
		for ( i = 0; i < players.size; i++ )
		{
			if ( players[i] != player ) 
			{	
				if ( isdefined( level.activeCounterUAVs[players[i].entNum] ) && level.activeCounterUAVs[players[i].entNum] > 0 )
				{
					activeCUAV = true;
				}
				
				if( isdefined( level.ActiveEMPs[ players[ i ].entNum ] ) && level.ActiveEMPs[ players[ i ].entNum ] > 0 )
				{
					activeEnemyEmp = true;
				}
			}
		}	
	}

	if ( activeCUAV == true || activeEnemyEmp == true )
	{
		if ( player hasPerk( "specialty_immunecounteruav" ) )
		{
			player AddPlayerStat( "perk_immune_cuav_kills", 1 );
		}
	}

	activeUAVVictim = false;
	if ( level.teambased ) 
	{
		if ( level.activeUAVs[victim.team] > 0 )
		{
			activeUAVVictim = true;
		}
	}
	else
	{
		activeUAVVictim = ( isdefined( level.activeUAVs[victim.entNum] ) && level.activeUAVs[victim.entNum] > 0 );
	}


	if ( activeUAVVictim == true )
	{
		if ( player hasPerk( "specialty_gpsjammer" ) )
		{
			player AddPlayerStat( "perk_gpsjammer_immune_kills", 1 );
		}
	}

	if ( player.lastWeaponChange + 5000 > time ) 
	{
		if ( player hasPerk( "specialty_fastweaponswitch" ) )
		{
			player AddPlayerStat( "perk_fastweaponswitch_kill_after_swap", 1 );
		}
	}
	
	if ( player.scavenged == true ) 
	{
		if ( player hasPerk( "specialty_scavenger" ) )
		{
			player AddPlayerStat( "perk_scavenger_kills_after_resupply", 1 );
		}
	}
}

function flakjacketProtected( weapon, attacker )
{
	if ( weapon.name == "claymore" )
	{
		self.flakJacketClaymore[ attacker.clientid ] = true;
	}
	self AddPlayerStat( "survive_with_flak", 1 );
	self.challenge_lastsurvivewithflakfrom = attacker;
	self.challenge_lastsurvivewithflaktime = getTime();
}

function earnedKillstreak()
{
	if ( self util::has_purchased_perk_equipped( "specialty_anteup" ) ) // anteup
	{
		self AddPlayerStat( "earn_scorestreak_anteup", 1 );
		if ( !isdefined( self.challenge_anteup_earned ) )
		{
			self.challenge_anteup_earned = 0;
		}		    	
		self.challenge_anteup_earned++;
		if ( self.challenge_anteup_earned >= 5 )
		{
			self AddPlayerStat( "earn_5_scorestreaks_anteup", 1 );
			self.challenge_anteup_earned = 0;
		}
	}
}

function genericBulletKill( data, victim, weapon ) 
{
	player = self;
	time = data.time;
	
	if ( player.pers["lastBulletKillTime"] == time )
		player.pers["bulletStreak"]++;
	else
		player.pers["bulletStreak"] = 1;
	
	player.pers["lastBulletKillTime"] = time;

	if ( data.victim.iDFlagsTime == time )
	{
		if ( data.victim.iDFlags & IDFLAGS_PENETRATION )
		{
			player AddPlayerStat( "kill_enemy_through_wall", 1 );
			if ( isdefined( weapon ) && weaponHasAttachment( weapon, "fmj" ) )
			{
				player AddPlayerStat( "kill_enemy_through_wall_with_fmj", 1 );		
			}
		}
	}
	
}


function isHighestScoringPlayer( player )
{
	if ( !isdefined( player.score ) || player.score < 1 )
		return false;

	players = level.players;
	if ( level.teamBased )
		team = player.pers["team"];
	else
		team = "all";

	highScore = player.score;

	for( i = 0; i < players.size; i++ )
	{
		if ( !isdefined( players[i].score ) )
			continue;
			
		if ( players[i] == player )
			continue;

		if ( players[i].score < 1 )
			continue;

		if ( team != "all" && players[i].pers["team"] != team )
			continue;
		// tied for first is no longer counted
		if ( players[i].score >= highScore )
			return false;
	}
	
	return true;
}

function spawnWatcher()
{
	self endon("disconnect");
	self endon("killSpawnMonitor");
	self.pers["stickExplosiveKill"] = 0;
	self.pers["pistolHeadshot"] = 0;
	self.pers["assaultRifleHeadshot"] = 0;
	self.pers["killNemesis"] = 0;
	while(1)
	{
		self waittill("spawned_player");
		self.pers["longshotsPerLife"] = 0;
		self.flakJacketClaymore = [];
		self.weaponKills = [];
		self.attachmentKills = [];
		self.retreivedBlades = 0;
		self.lastReloadTime = 0;
		self.crossbowClipKillCount = 0;
		self thread watchForDTP();
		self thread watchForMantle();
		self thread monitor_player_sprint();
	}
}

function watchForDTP()
{
	self endon ( "disconnect" );
	self endon ( "death" );
	self endon ("killDTPMonitor");
	
	self.dtpTime = 0;
	while(1)
	{
		self waittill( "dtp_end" );
		self.dtpTime = getTime() + 4000;
	}
}


function watchForMantle()
{
	self endon ( "disconnect" );
	self endon ( "death" );
	self endon ("killMantleMonitor");

	self.mantleTime = 0;
	while(1)
	{
		self waittill( "mantle_start", mantleEndTime );
		self.mantleTime = mantleEndTime;
	}
}

function disarmedHackedCarepackage()
{
	self AddPlayerStat( "disarm_hacked_carepackage", 1 );	
}

function destroyed_car()
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;

	self AddPlayerStat( "destroy_car", 1 );	
}


function killedNemesis()
{
	self.pers["killNemesis"]++;
	if ( self.pers["killNemesis"] >= 5 )
	{
		self.pers["killNemesis"] = 0;
		self AddPlayerStat( "kill_nemesis", 1 );	
	}
}

function killWhileDamagingWithHPM()
{
	self AddPlayerStat( "kill_while_damaging_with_microwave_turret", 1 );	
}

function longDistanceHatchetKill()
{
	self AddPlayerStat( "long_distance_hatchet_kill", 1 );	
}

function blockedSatellite()
{
	self AddPlayerStat( "activate_cuav_while_enemy_satelite_active", 1 );	
}

function longDistanceKill()
{
	self.pers["longshotsPerLife"]++;
	if ( self.pers["longshotsPerLife"] >= 3 )
	{
		self.pers["longshotsPerLife"] = 0;
		self AddPlayerStat( "longshot_3_onelife", 1 );	
	}
}


function challengeRoundEnd( data )
{
	player = data.player;
	winner = data.winner;
	
	if ( endedEarly( winner ) )
		return;
	
	if ( level.teambased )
	{
		winnerScore = game["teamScores"][winner];
		loserScore = getLosersTeamScores( winner );
	}
	
	switch ( level.gameType )
	{

		case "sd":
			{
				if ( player.team == winner )
				{					
					if ( game["challenge"][winner]["allAlive"] ) 
					{
						player AddGameTypeStat( "round_win_no_deaths", 1 );	
					}	
					if ( isdefined ( player.lastManSDDefeat3Enemies ) ) 
					{
						player AddGameTypeStat( "last_man_defeat_3_enemies", 1 );
					}
				}
			}
			break;
		default:
			break;
	}
}


function roundEnd( winner )
{
	WAIT_SERVER_FRAME;
	data = spawnstruct();
	data.time = getTime();
	if ( level.teamBased )
	{
		if ( isdefined( winner ) && isdefined( level.teams[winner] ) ) 
		{
			data.winner = winner;
		}
	}
	else
	{
		if ( isdefined( winner ) ) 
		{
			data.winner = winner;
		}
	}
	
	
	for ( index = 0; index < level.placement["all"].size; index++ )
	{
		data.player = level.placement["all"][index];
		if ( isdefined( data.player ) )
		{
			data.place = index;
			doChallengeCallback( "roundEnd", data );
		}
	}		
}

function gameEnd( winner )
{
	WAIT_SERVER_FRAME;
	data = spawnstruct();
	data.time = getTime();
	if ( level.teamBased )
	{
		if ( isdefined( winner ) && isdefined( level.teams[winner] ) ) 
		{ 
			data.winner = winner;
		}
	}
	else
	{
		if ( isdefined( winner ) && isplayer( winner) ) 
		{
			data.winner = winner;
		}
	}
	
	
	for ( index = 0; index < level.placement["all"].size; index++ )
	{
		data.player = level.placement["all"][index];
		data.place = index;

		if ( isdefined( data.player ) )
		{
			doChallengeCallback( "gameEnd", data );
		}
		data.player.completedGame = true;
	}
	
	for( index = 0; index < level.players.size; index++ )
	{
		if ( !isdefined( level.players[index].completedGame ) || level.players[index].completedGame != true )
		{
			scoreevents::processScoreEvent( "completed_match", level.players[index] );
		}
	}
}

function getFinalKill( player )
{
	// if the crates in dockside get the final killcam. 
	if ( isplayer ( player ) ) 
	{
		player AddPlayerStat( "get_final_kill", 1 );
	}
}

function destroyRCBomb( weapon )
{
	if ( !IsPlayer( self ) )
		return;

	self destroyScoreStreak( weapon, true, true );
	if ( weapon.rootweapon.name == "hatchet" )
	{
		self AddPlayerStat( "destroy_hcxd_with_hatchet", 1 );
	}
}

function capturedCrate( owner )
{
	if ( isdefined ( self.lastRescuedBy ) && isdefined ( self.lastRescuedTime ) ) 
	{
		if ( self.lastRescuedTime + 5000 > getTime() )
		{
			self.lastRescuedBy AddPlayerStat( "defend_teammate_who_captured_package", 1 );
		}
	}
	
	if( owner != self && ((level.teambased && owner.team != self.team) || !level.teambased) )
	{
		self AddPlayerStat( "capture_enemy_carepackage", 1 );
	}
		
}

function destroyScoreStreak( weapon, playerControlled, groundBased, countAsKillstreakVehicle = true )
{
	if ( !IsPlayer( self ) )
		return;

	if ( isdefined( level.killstreakWeapons[weapon] ) )
	{
	    if ( level.killstreakWeapons[weapon] == "dart" )
	    {
			self AddPlayerStat( "destroy_scorestreak_with_dart", 1 );
	    }
	}
	else if ( isdefined( weapon.isHeroWeapon ) && weapon.isHeroWeapon == true )
	{
		self AddPlayerStat( "destroy_scorestreak_with_specialist", 1 );	
	}
	else if ( WeaponHasAttachment( weapon, "fmj", "rf" ) )
	{
		self AddPlayerStat( "destroy_scorestreak_rapidfire_fmj", 1 );	
	}
	
	if ( !isdefined( playerControlled ) || playerControlled == false )
	{
		if ( self util::has_cold_blooded_perk_purchased_and_equipped() )
		{
			if ( groundBased ) 
			{
				self addPlayerStat( "destroy_ai_scorestreak_coldblooded", 1 );
			}
			if ( self util::has_blind_eye_perk_purchased_and_equipped() )  
			{
				if ( groundBased ) 
				{
					self.pers["challenge_destroyed_ground"]++;
				}
				else
				{
					self.pers["challenge_destroyed_air"]++;
				}
				    
			    if ( self.pers["challenge_destroyed_ground"] > 0 && self.pers["challenge_destroyed_air"] > 0 )
			    {
					self addPlayerStat( "destroy_air_and_ground_blindeye_coldblooded", 1 );
					self.pers["challenge_destroyed_air"] = 0;
					self.pers["challenge_destroyed_ground"] = 0;
			    }
			}
		}
	}

	if ( !isdefined( self.pers["challenge_destroyed_killstreak"] ) )
	{
		self.pers["challenge_destroyed_killstreak"] = 0;
	}
	self.pers["challenge_destroyed_killstreak"]++;

	if ( self.pers["challenge_destroyed_killstreak"] >= 5 )
	{
		self.pers["challenge_destroyed_killstreak"] = 0;
		self addWeaponStat( weapon, "destroy_5_killstreak", 1 ); // keeping this just in case we need to award it for old stats
		self addWeaponStat( weapon, "destroy_5_killstreak_vehicle", 1 ); // the meaning of this has been changes to mean any scorestreak (including turrets)
	}

	self addWeaponStat( weapon, "destroy_killstreak", 1 );

	weaponPickedUp = false;
	if( isdefined( self.pickedUpWeapons ) && isdefined( self.pickedUpWeapons[weapon] ) )
	{
		weaponPickedUp = true;
	}
	self AddWeaponStat( weapon, "destroyed", 1, self.class_num, weaponPickedUp, undefined, self.primaryLoadoutGunSmithVariantIndex, self.secondaryLoadoutGunSmithVariantIndex ); 
	
	self thread watchForRapidDestroy( weapon );
}


function watchForRapidDestroy( weapon )
{
	self endon( "disconnect" );
	if ( !isdefined( self.challenge_previousDestroyWeapon ) || self.challenge_previousDestroyWeapon != weapon )
	{
		self.challenge_previousDestroyWeapon = weapon;
		self.challenge_previousDestroyCount = 0;
	}
	else
	{
		self.challenge_previousDestroyCount++;
	}


	self waitTillTimeoutOrDeath( 4.0 );

	if ( self.challenge_previousDestroyCount > 1 )
	{
		self addWeaponStat( weapon, "destroy_2_killstreaks_rapidly", 1 );
	}
}

function capturedObjective( captureTime, objective )
{
	if ( isdefined( self.smokeGrenadeTime ) && isdefined( self.smokeGrenadePosition ) )
	{
		if ( self.smokeGrenadeTime + 14000 >  captureTime ) 
		{
			distSq = distanceSquared( self.smokeGrenadePosition, self.origin );

			if ( distSq < 57600 ) // 20 feet
			{
				if ( self util::is_item_purchased( "willy_pete" ) )
				{
					self AddPlayerStat( "capture_objective_in_smoke", 1 );
				}
				self AddWeaponStat( GetWeapon( "willy_pete" ), "CombatRecordStat", 1 );
				break;
			}
		}
	}
	
	if ( isdefined( level.capturedObjectiveFunction ) )
	{
		self [[level.capturedObjectiveFunction]]();
	}

	heroAbilityWasActiveRecently = ( isdefined( self.heroAbilityActive ) || ( isdefined( self.heroAbilityDectivateTime ) && self.heroAbilityDectivateTime > gettime() - 3000 ) );
	if ( heroAbilityWasActiveRecently && isdefined( self.heroAbility ) && self.heroAbility.name == "gadget_camo" )
	{
		scoreevents::processscoreevent( "optic_camo_capture_objective", self );
	}
	
	if ( isdefined( objective ) )
	{
		if ( self.challenge_objectiveDefensive === objective )
		{
			if ( ( VAL( self.challenge_objectiveDefensiveKillcount, 0 ) > 0 ) &&
			   ( ( VAL( self.recentKillCount, 0 ) > 2 ) || ( self.challenge_objectiveDefensiveTripleKillMedalOrBetterEarned === true ) ) )
			{
				self AddPlayerStat( "triple_kill_defenders_and_capture", 1 );
			}
			self.challenge_objectiveDefensiveKillcount = 0;
			self.challenge_objectiveDefensive = undefined;
			self.challenge_objectiveDefensiveTripleKillMedalOrBetterEarned = undefined;
		}
	}
}

function hackedOrDestroyedEquipment()
{
	if ( self util::has_hacker_perk_purchased_and_equipped() )
	{
		self AddPlayerStat( "perk_hacker_destroy", 1 );
	}
}

function bladeKill()
{
	if ( !isdefined( self.pers["bladeKills"] ) )
	{
		self.pers["bladeKills"] = 0;
	}
	self.pers["bladeKills"]++;
	if ( self.pers["bladeKills"] >= 15 ) 
	{
		self.pers["bladeKills"] = 0;
		self AddPlayerStat( "kill_15_with_blade", 1 );
	}
}
		
function destroyedExplosive( weapon )
{
	self destroyedEquipment( weapon );
	self AddPlayerStat( "destroy_explosive", 1 );
}

function assisted()
{
	self AddPlayerStat( "assist", 1 );
}

function earnedMicrowaveAssistScore( score )
{
	self AddPlayerStat( "assist_score_microwave_turret", score );
	self AddPlayerStat( "assist_score_killstreak", score );
	self AddWeaponStat( GetWeapon( "microwave_turret_deploy" ), "assists", 1 );
	self AddWeaponStat( GetWeapon( "microwave_turret_deploy" ), "assist_score", score );
}

function earnedCUAVAssistScore( score )
{
	self AddPlayerStat( "assist_score_cuav", score );
	self AddPlayerStat( "assist_score_killstreak", score );
	self AddWeaponStat( GetWeapon( "counteruav" ), "assists", 1 );
	self AddWeaponStat( GetWeapon( "counteruav" ), "assist_score", score );
}

function earnedUAVAssistScore( score )
{
	self AddPlayerStat( "assist_score_uav", score );
	self AddPlayerStat( "assist_score_killstreak", score );
	self AddWeaponStat( GetWeapon( "uav" ), "assists", 1 );
	self AddWeaponStat( GetWeapon( "uav" ), "assist_score", score );
}

function earnedSatelliteAssistScore( score )
{
	self AddPlayerStat( "assist_score_satellite", score );
	self AddPlayerStat( "assist_score_killstreak", score );
	self AddWeaponStat( GetWeapon( "satellite" ), "assists", 1 );
	self AddWeaponStat( GetWeapon( "satellite" ), "assist_score", score );
}

function earnedEMPAssistScore( score )
{
	self AddPlayerStat( "assist_score_emp", score );
	self AddPlayerStat( "assist_score_killstreak", score );
	self AddWeaponStat( GetWeapon( "emp_turret" ), "assists", 1 );
	self AddWeaponStat( GetWeapon( "emp_turret" ), "assist_score", score );
}



function teamCompletedChallenge( team, challenge ) 
{	
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if (isdefined( players[i].team ) && players[i].team == team )
		{		
			players[i] AddGameTypeStat( challenge, 1 );
		}
	}	
}

function endedEarly( winner )
{
	if ( level.hostForcedEnd )
		return true;
	
	if ( !isdefined( winner ) ) 
		return true;

	if ( level.teambased ) 
	{	
		if ( winner == "tie" )
			return true;
	}

	return false;
}

function getLosersTeamScores( winner )
{
	teamScores = 0;
	
	foreach ( team in level.teams )
	{
		if ( team == winner )
			continue;
			
		teamScores += game["teamScores"][team];
	}
	
	return teamScores;
}

function didLoserFailChallenge( winner, challenge )
{
	foreach ( team in level.teams )
	{
		if ( team == winner )
			continue;

		if ( game["challenge"][team][challenge] )
			return false;
	}
	
	return true;
}

function challengeGameEnd( data )
{
	player = data.player;
	winner = data.winner;
	
	if ( endedEarly( winner ) )
		return;

	if ( level.teambased )
	{
		winnerScore = game["teamScores"][winner];
		loserScore = getLosersTeamScores( winner );
	}
	
	switch ( level.gameType )
	{
		case "tdm":
			{
				if ( player.team == winner )
				{
					if ( winnerScore >= loserScore + 20 )
					{
						player AddGameTypeStat( "CRUSH", 1 );	
					}
				}

				mostKillsLeastDeaths = true;
								
				for ( index = 0; index < level.placement["all"].size; index++ )
				{
					if ( level.placement["all"][index].deaths < player.deaths )
					{
						mostKillsLeastDeaths = false;
					}
					if ( level.placement["all"][index].kills > player.kills )
					{
						mostKillsLeastDeaths = false;
					}
				}
				
				if ( mostKillsLeastDeaths && player.kills > 0 && level.placement["all"].size > 3 )
				{
					player AddGameTypeStat( "most_kills_least_deaths", 1 );	
				}
			}
			break;
		case "dm":
			{
				if ( player == winner )
				{
					if ( level.placement["all"].size >= 2 )
					{
						secondPlace = level.placement["all"][1];
						if ( player.kills >= ( secondPlace.kills + 7 ) )
						{
							player AddGameTypeStat( "CRUSH", 1 );	
						}
					}	
				}
			}
			break;
		case "ctf":
			{
				if ( player.team == winner )
				{
					if ( loserScore == 0 )
					{	
						player AddGameTypeStat( "SHUT_OUT", 1 );
					}	
				}
			}
			break;
		case "dom":
			{
				if ( player.team == winner )
				{
					if ( winnerScore >= loserScore + 70 )
					{
						player AddGameTypeStat( "CRUSH", 1 );	
					}
				}	
			}
			break;
		case "hq":
			{
				if ( player.team == winner && winnerScore > 0 )
				{
					if ( winnerScore >= loserScore + 70 )
					{
						player AddGameTypeStat( "CRUSH", 1 );	
					}
				}
			}
			break;
		case "koth":
			{
				if ( player.team == winner && winnerScore > 0 )
				{
					if ( winnerScore >= loserScore + 70 )
					{
						player AddGameTypeStat( "CRUSH", 1 );	
					}
				}
				if ( player.team == winner && winnerScore > 0 )
				{
					if ( winnerScore >= loserScore + 110 )
					{
						player AddGameTypeStat( "ANNIHILATION", 1 );	
					}
				}
			}
			break;
		case "dem":
			{
				if ( player.team == game["defenders"] && player.team == winner )
				{
					if ( loserScore == 0 )
					{	
						player AddGameTypeStat( "SHUT_OUT", 1 );
					}	
				}
			}
			break;
		case "sd":
			{
				if ( player.team == winner )
				{
					if ( loserScore <= 1 )
					{
						player AddGameTypeStat( "CRUSH", 1 );	
					}
				}
			}
		default:
			break;
	}
}

function multiKill( killCount, weapon )
{
	if ( killCount >= 3 && isdefined( self.lastKillWhenInjured ) )
	{
		if ( self.lastKillWhenInjured + 5000 > getTime() )
		{
			self AddPlayerStat( "multikill_3_near_death", 1 );
		}
	}

	self AddWeaponStat( weapon, "doublekill", int( killCount / 2 ) );
	self AddWeaponStat( weapon, "triplekill", int( killCount / 3 ) );
	
	if ( weapon.isheroweapon )
	{
		doubleKill = int( killCount / 2 );
		if ( doubleKill )
		{
			self AddPlayerStat( "MULTIKILL_2_WITH_HEROWEAPON", doubleKill );
		}
		tripleKill = int( killCount / 3 );
		if ( tripleKill )
		{
			self AddPlayerStat( "MULTIKILL_3_WITH_HEROWEAPON", tripleKill );
		}
	}
}

function domAttackerMultiKill( killCount )
{
	self AddGameTypeStat( "kill_2_enemies_capturing_your_objective", 1 );
}
	

function totalDomination( team ) 
{
	teamCompletedChallenge( team, "control_3_points_3_minutes" );
}

function holdFlagEntireMatch( team, label )
{
	switch( label )
	{
		case "_a":
			event = "hold_a_entire_match";
			break;
		case "_b":
			event = "hold_b_entire_match";
			break;
		case "_c":
			event = "hold_c_entire_match";
			break;
		default:
			return;
	}
			
	teamCompletedChallenge( team, event );
}

function capturedBFirstMinute()
{
	self AddGameTypeStat( "capture_b_first_minute", 1 );
}

function controlZoneEntirely( team )
{
	teamCompletedChallenge( team, "control_zone_entirely" ) ;
}

function multi_LMG_SMG_Kill()
{
	self AddPlayerStat( "multikill_3_lmg_or_smg_hip_fire", 1 );
}

function killedZoneAttacker( weapon )
{
	if ( weapon.name == "planemortar" || weapon.name ==  "remote_missile_missile" ||  weapon.name == "remote_missile_bomblet" )
	{
		self thread updatezonemultikills();
	}
}

function killedDog()
{
	origin = self.origin;
	if ( level.teambased )
	{
		teammates = util::get_team_alive_players_s( self.team );
		foreach( player in teammates.a )
		{
			if ( player == self )
				continue;
			distSq = distanceSquared( origin, player.origin );

			if ( distSq < 57600 ) // 20 feet
			{
				self AddPlayerStat( "killed_dog_close_to_teammate", 1 );
				break;
			}
		}
	}
}

function updatezonemultikills()
{
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self notify ( "updateRecentZoneKills" );
	self endon ( "updateRecentZoneKills" );
	if ( !isdefined (self.recentZoneKillCount) )
		self.recentZoneKillCount = 0;
	self.recentZoneKillCount++;

	wait ( 4.0 );

	if ( self.recentZoneKillCount > 1 )
	{
		self AddPlayerStat( "multikill_2_zone_attackers", 1 );
	}

	self.recentZoneKillCount = 0;
}

function multi_RCBomb_Kill()
{
	self AddPlayerStat( "multikill_2_with_rcbomb", 1 );
}

function multi_RemoteMissile_Kill()
{
	self AddPlayerStat( "multikill_3_remote_missile", 1 );
}


function multi_MGL_Kill()
{
	self AddPlayerStat( "multikill_3_with_mgl", 1 );
}


function immediateCapture()
{
	self AddGameTypeStat( "immediate_capture", 1 );	
}


function killedLastContester()
{
	self AddGameTypeStat( "contest_then_capture", 1 );	
}


function bothBombsDetonateWithinTime()
{
	self AddGameTypeStat( "both_bombs_detonate_10_seconds", 1 );	
}

function calledInCarePackage()
{
	self.pers["carepackagesCalled"]++;
	
	if ( self.pers["carepackagesCalled"] >= 3 )
	{
		self AddPlayerStat( "call_in_3_care_packages", 1 );
		self.pers["carepackagesCalled"] = 0;
	}
}

function destroyedHelicopter( attacker, weapon, damageType, playerControlled )
{
	if ( !IsPlayer( attacker ) )
		return;

	attacker destroyScoreStreak( weapon, playerControlled, false );
	if ( damageType == "MOD_RIFLE_BULLET" ||  damageType =="MOD_PISTOL_BULLET" )
	{
		attacker AddPlayerStat( "destroyed_helicopter_with_bullet", 1 );
	}
}


function destroyedQRDrone( damageType, weapon )
{
	self destroyScoreStreak( weapon, true, false );

	self AddPlayerStat( "destroy_qrdrone", 1 );

	if ( damageType == "MOD_RIFLE_BULLET" ||  damageType =="MOD_PISTOL_BULLET" )
	{
		self AddPlayerStat( "destroyed_qrdrone_with_bullet", 1 );
	}
	
	self destroyedPlayerControlledAircraft();
}

// chopper hunter challenge renamed aircraft hunter
function destroyedPlayerControlledAircraft()
{
	if ( self hasPerk( "specialty_noname" ) )
	{
		self AddPlayerStat( "destroy_helicopter", 1 );
	}
}

function destroyedAircraft( attacker, weapon, playerControlled )
{
	if ( !IsPlayer( attacker ) )
		return;

	attacker destroyScoreStreak( weapon, playerControlled, false );
	
	if ( isdefined( weapon ) )
	{
		if ( weapon.name == "emp" && attacker util::is_item_purchased( "killstreak_emp" ) ) // killstreak only, not grenade
		{
			attacker AddPlayerStat( "destroy_aircraft_with_emp", 1 );
		}
		else if ( weapon.name == "missile_drone_projectile" || weapon.name == "missile_drone" )
		{
			attacker AddPlayerStat( "destroy_aircraft_with_missile_drone", 1 );
		}
		else if ( weapon.isBulletWeapon )
		{
			attacker AddPlayerStat( "shoot_aircraft", 1 );
		}
	}

	if ( attacker util::has_blind_eye_perk_purchased_and_equipped() )
	{
		attacker AddPlayerStat( "perk_nottargetedbyairsupport_destroy_aircraft", 1 );
	}

	attacker AddPlayerStat( "destroy_aircraft", 1 );
	
	if ( isdefined( playerControlled ) && playerControlled == false )
	{
		if ( attacker util::has_blind_eye_perk_purchased_and_equipped() )
		{
			attacker AddPlayerStat( "destroy_ai_aircraft_using_blindeye", 1 );	
		}
	}
}

function killstreakTen()
{
	if ( !IsDefined( self.class_num ) )
	{
		return;
	}
	
	primary = self GetLoadoutItem( self.class_num, "primary" );
	if ( primary != 0 )
	{
		return;
	}
	secondary = self GetLoadoutItem( self.class_num, "secondary" );
	if ( secondary != 0 )
	{
		return;
	}
	primarygrenade = self GetLoadoutItem( self.class_num, "primarygrenade" );
	if ( primarygrenade != 0 )
	{
		return;
	}
	specialgrenade = self GetLoadoutItem( self.class_num, "specialgrenade" );
	if ( specialgrenade != 0 )
	{
		return;
	}

	for ( numSpecialties = 0; numSpecialties < level.maxSpecialties; numSpecialties++ )
	{
		perk = self GetLoadoutItem( self.class_num, "specialty" + ( numSpecialties + 1 ) );
		if ( perk != 0 )
		{
			return;
		}
	}

	self  AddPlayerStat( "killstreak_10_no_weapons_perks", 1 );
}

function scavengedGrenade()
{
	self endon("disconnect");
	self endon("death");
	self notify("scavengedGrenade");
	self endon("scavengedGrenade");

	
	self notify( "scavenged_primary_grenade" );
	for(;;)
	{
		self waittill( "lethalGrenadeKill" );	
		self AddPlayerStat( "kill_with_resupplied_lethal_grenade", 1 );
	}
}

function stunnedTankWithEMPGrenade( attacker )
{
	attacker AddPlayerStat( "stun_aitank_wIth_emp_grenade", 1 );
}


function playerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, weapon, sHitLoc, attackerStance, bledOut )
{
	
/#	print(level.gameType);	#/
	self.anglesOnDeath = self getPlayerAngles();
	if ( isdefined( attacker ) )
		attacker.anglesOnKill = attacker getPlayerAngles();
	if ( !isdefined( weapon ) )
		weapon = level.weaponNone;
	
	self endon("disconnect");

	data = spawnstruct();

	data.victim = self;
	data.victimOrigin = self.origin;
	data.victimStance = self getStance();
	data.eInflictor = eInflictor;
	data.attacker = attacker;
	data.attackerStance = attackerStance;
	data.iDamage = iDamage;
	data.sMeansOfDeath = sMeansOfDeath;
	data.weapon = weapon;
	data.sHitLoc = sHitLoc;
	data.time = gettime();
	data.bledOut = false;
	if ( isdefined( bledOut ) )
	{
		data.bledOut = bledOut;
	}
		
	if ( isdefined( eInflictor ) && isdefined( eInflictor.lastWeaponBeforeToss ) ) 
	{
		data.lastWeaponBeforeToss = eInflictor.lastWeaponBeforeToss;
	}
	if ( isdefined( eInflictor ) && isdefined( eInflictor.ownerWeaponAtLaunch ) ) 
	{
		data.ownerWeaponAtLaunch = eInflictor.ownerWeaponAtLaunch;
	}

	
	wasLockingOn = 0;
	washacked = false;
	if ( isdefined( eInflictor ) )
	{
		if ( isdefined ( eInflictor.locking_on ) )
		{
			wasLockingOn |= eInflictor.locking_on;
		}
	
		if ( isdefined ( eInflictor.locked_on ) )
		{
			wasLockingOn |= eInflictor.locked_on;
		}		
		
		wasHacked = einflictor util::isHacked();
	}
	
	wasLockingOn &= ( 1 << data.victim.entnum );
	if ( wasLockingOn != 0 )
	{	
		data.wasLockingOn = true;
	}
	else 
	{
		data.wasLockingOn = false;
	}
	data.wasHacked = washacked;
	data.wasPlanting = data.victim.isplanting;
	data.wasUnderwater = data.victim IsPlayerUnderwater();
	if ( !isdefined( data.wasPlanting ) ) 
	{
		data.wasPlanting = false;
	}
	data.wasDefusing = data.victim.isdefusing;
	if ( !isdefined( data.wasDefusing ) ) 
	{
		data.wasDefusing = false;
	}	
	data.victimWeapon = data.victim.currentWeapon;
	data.victimOnGround = data.victim isOnGround();
	data.victimWasWallRunning = data.victim isWallRunning();
	data.victimLastStunnedBy = data.victim.lastStunnedBy;
	data.victimWasDoubleJumping = data.victim IsDoubleJumping();
	data.victimCombatEfficiencyLastOnTime = data.victim.combatEfficiencyLastOnTime;
	data.victimSpeedburstLastOnTime = data.victim.speedburstLastOnTime;
	data.victimCombatEfficieny = data.victim ability_util::gadget_is_active( GADGET_TYPE_COMBAT_EFFICIENCY );
	data.victimflashbackTime = data.victim.flashbackTime;
	data.victimheroAbilityActive = ability_player::gadget_CheckHeroAbilityKill( data.victim );
	data.victimElectrifiedBy = data.victim.electrifiedBy;
	data.victimHeroAbility = data.victim.heroAbility;
	data.victimWasInSlamState = data.victim IsSlamming();
	data.victimWasLungingWithArmBlades = data.victim IsGadgetMeleeCharging();
	data.victimWasHeatWaveStunned = data.victim isHeatWaveStunned();
	data.victimPowerArmorLastTookDamageTime = data.victim.power_armor_last_took_damage_time;
	data.victimHeroWeaponKillsThisActivation = data.victim.heroWeaponKillsThisActivation;
	data.victimGadgetPower = data.victim GadgetPowerGet( 0 );
	data.victimGadgetWasActiveLastDamage = data.victim.gadget_was_active_last_damage;
	data.victimIsThiefOrRoulette = ( data.victim.isThief === true || data.victim.isRoulette === true );
	data.victimHeroAbilityName = data.victim.heroAbilityName;

	if ( !isdefined( data.victimflashbackTime ) ) 
	{
		data.victimflashbackTime = 0;
	}
	if ( !isdefined( data.victimCombatEfficiencyLastOnTime ) ) 
	{
		data.victimCombatEfficiencyLastOnTime = 0;
	}	
	if ( !isdefined( data.victimSpeedburstLastOnTime ) )
	{
		data.victimSpeedburstLastOnTime = 0;
	}
	data.victimVisionPulseActivateTime = data.victim.visionPulseActivateTime;
	if ( !isdefined( data.victimVisionPulseActivateTime ) )
	{
		data.victimVisionPulseActivateTime = 0;
	}
	data.victimVisionPulseArray = util::array_copy_if_array( data.victim.visionPulseArray );
	data.victimVisionPulseOrigin = data.victim.visionPulseOrigin;
	data.victimVisionPulseOriginArray = util::array_copy_if_array( data.victim.visionPulseOriginArray );
	data.victimAttackersThisSpawn = util::array_copy_if_array( data.victim.attackersThisSpawn );

	data.victim_doublejump_begin			= data.victim.challenge_doublejump_begin;
	data.victim_doublejump_end				= data.victim.challenge_doublejump_end;
	data.victim_jump_begin					= data.victim.challenge_jump_begin;
	data.victim_jump_end					= data.victim.challenge_jump_end;
	data.victim_swimming_begin				= data.victim.challenge_swimming_begin;
	data.victim_swimming_end				= data.victim.challenge_swimming_end;
	data.victim_slide_begin					= data.victim.challenge_slide_begin;
	data.victim_slide_end					= data.victim.challenge_slide_end;
	data.victim_wallrun_begin				= data.victim.challenge_wallrun_begin;
	data.victim_wallrun_end					= data.victim.challenge_wallrun_end;
	data.victim_was_drowning  				= data.victim drown::is_player_drowning();
	
	if ( isdefined( data.victim.activeProximityGrenades ) )
	{
		data.victimActiveProximityGrenades = [];
		
		ArrayRemoveValue( data.victim.activeProximityGrenades, undefined );
		
		foreach( proximityGrenade in data.victim.activeProximityGrenades )
		{
			proximityGrenadeInfo = SpawnStruct();
			proximityGrenadeInfo.origin = proximityGrenade.origin;
			data.victimActiveProximityGrenades[ data.victimActiveProximityGrenades.size ] = proximityGrenadeInfo;
		}
	}
	
	if ( isdefined( data.victim.activeBouncingBetties ) )
	{
		data.victimActiveBouncingBetties = [];
		
		ArrayRemoveValue( data.victim.activeBouncingBetties, undefined );
		
		foreach( bouncingBetty in data.victim.activeBouncingBetties )
		{
			bouncingBettyInfo = SpawnStruct();
			bouncingBettyInfo.origin = bouncingBetty.origin;
			data.victimActiveBouncingBetties[ data.victimActiveBouncingBetties.size ] = bouncingBettyInfo;
		}
	}	
	
	if ( isPlayer( attacker ) )
	{
		data.attackerOrigin = data.attacker.origin;
		data.attackerOnGround = data.attacker isOnGround();
		data.attackerWallRunning = data.attacker isWallRunning();
		data.attackerDoubleJumping = data.attacker IsDoubleJumping();
		data.attackerTraversing = data.attacker IsTraversing();
		data.attackerSliding = data.attacker IsSliding();
		data.attackerSpeedburst = data.attacker ability_util::gadget_is_active( GADGET_TYPE_SPEED_BURST );
		data.attackerflashbackTime = data.attacker.flashbackTime;
		data.attackerHeroAbilityActive = ability_player::gadget_CheckHeroAbilityKill( data.attacker );
		data.attackerHeroAbility = data.attacker.heroAbility;
		if ( !isdefined( data.attackerflashbackTime ) ) 
		{
			data.attackerflashbackTime = 0;
		}
		data.attackerVisionPulseActivateTime = attacker.visionPulseActivateTime;
		if ( !isdefined( data.attackerVisionPulseActivateTime ) )
		{
			data.attackerVisionPulseActivateTime = 0;
		}
		data.attackerVisionPulseArray = util::array_copy_if_array( attacker.visionPulseArray );
		data.attackerVisionPulseOrigin = attacker.visionPulseOrigin;
		if ( !isdefined( data.attackerStance ) ) 
		{
			data.attackerStance = data.attacker getStance();
		}
		data.attackerVisionPulseOriginArray = util::array_copy_if_array( attacker.visionPulseOriginArray );
		
		data.attackerWasFlashed = data.attacker isFlashbanged();
		data.attackerLastFlashedBy = data.attacker.lastFlashedBy;
		data.attackerLastStunnedBy = data.attacker.lastStunnedBy;
		data.attackerLastStunnedTime = data.attacker.lastStunnedTime;
		data.attackerWasConcussed = ( isdefined( data.attacker.concussionEndTime ) && data.attacker.concussionEndTime > gettime() );
		data.attackerWasHeatWaveStunned = data.attacker isHeatWaveStunned();
		data.attackerWasUnderwater = data.attacker IsPlayerUnderwater();
		data.attackerLastFastReloadTime = data.attacker.lastFastReloadTime;
		data.attackerWasSliding = data.attacker IsSliding();
		data.attackerWasSprinting = data.attacker issprinting();
		data.attackerIsThief = ( attacker.isThief === true );
		data.attackerIsRoulette = ( attacker.isRoulette === true );
		

		data.attacker_doublejump_begin			= data.attacker.challenge_doublejump_begin;
		data.attacker_doublejump_end			= data.attacker.challenge_doublejump_end;
		data.attacker_jump_begin				= data.attacker.challenge_jump_begin;
		data.attacker_jump_end					= data.attacker.challenge_jump_end;
		data.attacker_swimming_begin			= data.attacker.challenge_swimming_begin;
		data.attacker_swimming_end				= data.attacker.challenge_swimming_end;
		data.attacker_slide_begin				= data.attacker.challenge_slide_begin;
		data.attacker_slide_end					= data.attacker.challenge_slide_end;
		data.attacker_wallrun_begin				= data.attacker.challenge_wallrun_begin;
		data.attacker_wallrun_end				= data.attacker.challenge_wallrun_end;
		data.attacker_was_drowning  			= data.attacker drown::is_player_drowning();
		
		data.attacker_sprint_begin				= data.attacker.challenge_sprint_begin;
		data.attacker_sprint_end				= data.attacker.challenge_sprint_end;
		
		data.attacker_wallRanTwoOppositeWallsNoGround	= data.attacker.wallRanTwoOppositeWallsNoGround;
		
		if ( ( level.allow_vehicle_challenge_check === true ) && attacker IsInVehicle() )
		{
			vehicle = attacker GetVehicleOccupied();
		
			if ( isdefined( vehicle ) )
			{
				data.attackerInVehicleArchetype = vehicle.archetype;
			}
		}
	}
	else
	{
		data.attackerOnGround = false;
		data.attackerWallRunning = false;
		data.attackerDoubleJumping = false;
		data.attackerTraversing = false;
		data.attackerSliding = false;
		data.attackerSpeedburst = false;
		data.attackerflashbackTime = 0;
		data.attackerVisionPulseActivateTime = 0;
		data.attackerWasFlashed = false;
		data.attackerWasConcussed = false;
		data.attackerHeroAbilityActive = false;
		data.attackerWasHeatWaveStunned = false;
		data.attackerStance = "stand";
		data.attackerWasUnderwater = false;
		data.attackerWasSprinting = false;
		data.attackerIsThief = false;
		data.attackerIsRoulette = false;
	}
	
	if ( isdefined( eInflictor ) )
	{
		if ( isdefined( eInflictor.IsCooked ) )
		{
			data.inflictorIsCooked = eInflictor.IsCooked;
		}
		else 
		{
			data.inflictorIsCooked = false;
		}
		
		if ( isdefined( eInflictor.Challenge_hatchetTossCount ) ) 
		{
			data.inflictorChallenge_hatchetTossCount = eInflictor.Challenge_hatchetTossCount;
		}
		else 
		{
			data.inflictorChallenge_hatchetTossCount = 0;
		}
		if ( isdefined( eInflictor.OwnerWasSprinting ) )
		{
			data.inflictorOwnerWasSprinting = eInflictor.OwnerWasSprinting;
		}
		else
		{
			data.inflictorOwnerWasSprinting = false;
		}
		if ( isdefined( eInflictor.PlayerHasEngineerPerk ) )
		{
			data.inflictorPlayerHasEngineerPerk = eInflictor.PlayerHasEngineerPerk;
		}
		else
		{
			data.inflictorPlayerHasEngineerPerk = false;
		}
	}
	else
	{
		data.inflictorIsCooked = false;
		data.inflictorChallenge_hatchetTossCount = 0;
		data.inflictorOwnerWasSprinting = false;
		data.inflictorPlayerHasEngineerPerk = false;
	}

	
	waitAndProcessPlayerKilledCallback( data );
	
	data.attacker notify( "playerKilledChallengesProcessed" );
}

function doScoreEventCallback( callback, data )
{
	if ( !isdefined( level.scoreEventCallbacks ) )
		return;		
			
	if ( !isdefined( level.scoreEventCallbacks[callback] ) )
		return;
	
	if ( isdefined( data ) ) 
	{
		for ( i = 0; i < level.scoreEventCallbacks[callback].size; i++ )
			thread [[level.scoreEventCallbacks[callback][i]]]( data );
	}
	else 
	{
		for ( i = 0; i < level.scoreEventCallbacks[callback].size; i++ )
			thread [[level.scoreEventCallbacks[callback][i]]]();
	}
}

function waitAndProcessPlayerKilledCallback( data )
{
	if ( isdefined( data.attacker ) )
		data.attacker endon("disconnect");
	
	wait .05;
	util::WaitTillSlowProcessAllowed();
	
	level thread doChallengeCallback( "playerKilled", data );
	level thread doScoreEventCallback( "playerKilled", data );
}

function weaponIsKnife( weapon ) 
{
	if ( weapon == level.weaponBaseMelee || weapon == level.weaponBaseMeleeHeld || weapon == level.weaponBallisticKnife )
	{
		return true;
	}

	return false;
}

function eventReceived( eventName )
{
	self endon( "disconnect" );
	
	util::WaitTillSlowProcessAllowed();
	
	switch ( level.gameType )
	{
		case "tdm":
			{
				if ( eventName == "killstreak_10" )
				{
					self AddGameTypeStat( "killstreak_10", 1 );
				}
				else if ( eventName == "killstreak_15" )
				{
					self AddGameTypeStat( "killstreak_15", 1 );
				}
				else if ( eventName == "killstreak_20" )
				{
					self AddGameTypeStat( "killstreak_20", 1 );
				}
				else if ( eventName == "multikill_3" )
				{
					self AddGameTypeStat( "multikill_3", 1 );
				}
				else if ( eventName == "kill_enemy_who_killed_teammate" )
				{
					self AddGameTypeStat( "kill_enemy_who_killed_teammate", 1 );
				}
				else if ( eventName == "kill_enemy_injuring_teammate" )
				{
					self AddGameTypeStat( "kill_enemy_injuring_teammate", 1 );
				}
			}
			break;
		case "dm":
			{
				if ( eventName == "killstreak_10" )
				{
					self AddGameTypeStat( "killstreak_10", 1 );
				}
				else if ( eventName == "killstreak_15" )
				{
					self AddGameTypeStat( "killstreak_15", 1 );
				}
				else if ( eventName == "killstreak_20" )
				{
					self AddGameTypeStat( "killstreak_20", 1 );
				}
				else if ( eventName == "killstreak_30" )
				{
					self AddGameTypeStat( "killstreak_30", 1 );
				}
			}
			break;
		case "sd":
			{
				if ( eventName == "defused_bomb_last_man_alive" )
				{
					self AddGameTypeStat( "defused_bomb_last_man_alive", 1 );
				}
				else if ( eventName == "elimination_and_last_player_alive" )
				{
					self AddGameTypeStat( "elimination_and_last_player_alive", 1 );
				}
				else if ( eventName == "killed_bomb_planter" )
				{
					self AddGameTypeStat( "killed_bomb_planter", 1 );
				}
				else if ( eventName == "killed_bomb_defuser" )
				{
					self AddGameTypeStat( "killed_bomb_defuser", 1 );
				}
			}
			break;
		case "ctf":
			{
				if ( eventName == "kill_flag_carrier" )
				{
					self AddGameTypeStat( "kill_flag_carrier", 1 );
				}
				else if ( eventName == "defend_flag_carrier" )
				{
					self AddGameTypeStat( "defend_flag_carrier", 1 );
				}
			}
			break;
		case "dem":
			{
				if ( eventName == "killed_bomb_planter" )
				{
					self AddGameTypeStat( "killed_bomb_planter", 1 );
				}
				else if ( eventName == "killed_bomb_defuser" )
				{
					self AddGameTypeStat( "killed_bomb_defuser", 1 );
				}
			}
			break;
		default:
			break;
	}
}

function monitor_player_sprint()
{
	self endon("disconnect");
	self endon("killPlayerSprintMonitor");
	self endon ( "death" );
	
	self.lastSprintTime = undefined;
	
	while(1)
	{
		self waittill("sprint_begin");
        
		self waittill ("sprint_end");
        
		self.lastSprintTime = GetTime();
	}
}


function isFlashbanged()
{
	return isdefined( self.flashEndTime ) && gettime() < self.flashEndTime;
}

function isHeatWaveStunned()
{
	return isdefined( self._heat_wave_stuned_end ) && gettime() < self._heat_wave_stuned_end;
}


function trophy_defense( origin, radius )
{
	if ( isdefined( level.challenge_scorestreaksenabled ) && level.challenge_scorestreaksenabled == true ) 
	{
		entities = GetDamageableEntArray( origin, radius );
		foreach( entity in entities )
		{
			if ( isdefined( entity.challenge_isScoreStreak ) )
			{
				self AddPlayerStat( "protect_streak_with_trophy", 1 );
				break;
			}
		}
	}
}

function waitTillTimeoutOrDeath( timeout )
{
	self endon( "death" );
	wait( timeout );
}

