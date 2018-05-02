#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\challenges_shared;
#using scripts\shared\drown;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapon_utils;

#using scripts\mp\gametypes\_loadout;

#insert scripts\shared\shared.gsh;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_counteruav;
#using scripts\mp\killstreaks\_emp;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_satellite;
#using scripts\mp\killstreaks\_uav;



#insert scripts\mp\_bonuscard.gsh;

#define KILL_NEAR_PLANT_ENGINEER_HARDWIRED_CLOSE_ENOUGH_DISTANCE		400

#namespace challenges;

REGISTER_SYSTEM( "challenges", &__init__, undefined )

function __init__()
{
	callback::on_start_gametype( &start_gametype );
	callback::on_spawned( &on_player_spawn );
	level.heroAbilityActivateNearDeath = &heroAbilityActivateNearDeath;
	level.callbackEndHeroSpecialistEMP = &callbackEndHeroSpecialistEMP;
	level.capturedObjectiveFunction = &capturedObjectiveFunction;
}

function start_gametype()
{
	if ( !isdefined( level.ChallengesCallbacks ) )
	{
		level.ChallengesCallbacks = [];
	}
	
	waittillframeend;
	
	if ( isdefined ( level.scoreEventGameEndCallback ) )
	{
		challenges::registerChallengesCallback( "gameEnd",level.scoreEventGameEndCallback );
	}
	
	if ( canProcessChallenges() )
	{
		challenges::registerChallengesCallback( "playerKilled",&challengeKills );	
		challenges::registerChallengesCallback( "gameEnd",&challengeGameEndMP );
	}

	callback::on_connect( &on_player_connect );
}

function on_player_connect()
{
	initChallengeData();
	self addSpecialistUsedStatOnConnect();
	self thread spawnWatcher();	
	self thread monitorReloads();
	self thread monitorGrenadeFire();
}

function initChallengeData()
{	
	self.pers["bulletStreak"] = 0;
	self.pers["lastBulletKillTime"] = 0;
	self.pers["stickExplosiveKill"] = 0;
	self.pers["carepackagesCalled"] = 0;
	self.pers["challenge_destroyed_air"] = 0;
	self.pers["challenge_destroyed_ground"] = 0;
	self.pers["challenge_anteup_earn"] = 0;
	self.pers["specialistStatAbilityUsage"] = 0;
	self.pers["canSetSpecialistStat"] = self isSpecialistUnlocked();
	self.pers["activeKillstreaks"] = [];
}

function addSpecialistUsedStatOnConnect()
{
	if ( !isdefined(self.pers["challenge_heroweaponkills"]) )
	{
		// intentionally using "used" hero weapon on connect to determine frequency of specialist usage
		// which is the sum of "specialist ability" usage and "specialist weapon" usage.
		heroWeaponName = self GetLoadoutItemRef( 0, "heroWeapon" );
		heroWeapon = GetWeapon( heroWeaponName );
		if ( heroWeapon == level.weaponNone )
		{
			heroAbilityName = self GetHeroAbilityName();
			heroWeapon = GetWeapon( heroAbilityName );
		}
		if ( heroWeapon != level.weaponNone )
		{
			self addweaponstat( heroWeapon, "used", 1 );
		}
		
		self.pers["challenge_heroweaponkills"] = 0;
	}
}

function spawnWatcher()
{
	self endon( "disconnect" );

	self.pers["killNemesis"] = 0;
	self.pers["killsFastMagExt"] = 0;
	self.pers["longshotsPerLife"] = 0;
	self.pers["specialistStatAbilityUsage"] = 0;
	self.challenge_defenderkillcount = 0;
	self.challenge_offenderkillcount = 0;
	self.challenge_offenderProjectileMultiKillcount = 0;
	self.challenge_offenderComlinkKillcount = 0;
	self.challenge_offenderSentryTurretKillCount = 0;
	self.challenge_objectiveDefensiveKillcount = 0;
	self.challenge_objectiveOffensiveKillcount = 0;
	self.challenge_scavengedCount = 0;
	self.challenge_resuppliedNameKills = 0;
	self.challenge_objectiveDefensive = undefined;
	self.challenge_objectiveOffensive = undefined;	
	self.challenge_lastsurvivewithflakfrom = undefined;	
	self.explosiveInfo = [];
	
	for(;;)
	{
		self waittill("spawned_player");
		
		self.weaponKillsThisSpawn = [];
		self.attachmentKillsThisSpawn = [];
		self.challenge_hatchetTossCount = 0;
		self.challenge_hatchetkills = 0;
		self.retreivedBlades = 0;
		self.challenge_combatRobotAttackClientID = [];
		
		self thread watchDoubleJump();
		self thread watchJump();
		self thread watchSwimming();
		self thread watchWallrun();
		self thread watchSlide();
		self thread watchSprint();
		self thread watchScavengeLethal();
		self thread watchWallRunTwoOppositeWallsNoGround();
		self thread watchWeaponChangeComplete();
	}
}

function watchScavengeLethal()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	self.challenge_scavengedCount = 0;
	
	for(;;)
	{
		self waittill( "scavenged_primary_grenade" );
		self.challenge_scavengedCount++;
	}
}

function watchDoublejump()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_doublejump_begin = 0;
	self.challenge_doublejump_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "doublejump_begin", "doublejump_end", "disconnect" );
		switch( ret )
		{
			case "doublejump_begin":
			self.challenge_doublejump_begin = gettime();
			break;
			case "doublejump_end":
			self.challenge_doublejump_end = gettime();
			break;
		}
	}
}

function watchJump()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_jump_begin = 0;
	self.challenge_jump_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "jump_begin", "jump_end", "disconnect" );
		switch( ret )
		{
			case "jump_begin":
			self.challenge_jump_begin = gettime();
			break;
			case "jump_end":
			self.challenge_jump_end = gettime();
			break;
		}
	}
}

function watchSwimming()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_swimming_begin = 0;
	self.challenge_swimming_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "swimming_begin", "swimming_end", "disconnect" );
		switch( ret )
		{
			case "swimming_begin":
			self.challenge_swimming_begin = gettime();
			break;
			case "swimming_end":
			self.challenge_swimming_end = gettime();
			break;
		}
	}
}

function watchWallrun()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_wallrun_begin = 0;
	self.challenge_wallrun_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "wallrun_begin", "wallrun_end", "disconnect" );
		switch( ret )
		{
			case "wallrun_begin":
			self.challenge_wallrun_begin = gettime();
			break;
			case "wallrun_end":
			self.challenge_wallrun_end = gettime();
			break;
		}
	}
}

function watchSlide()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_slide_begin = 0;
	self.challenge_slide_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "slide_begin", "slide_end", "disconnect" );
		switch( ret )
		{
			case "slide_begin":
			self.challenge_slide_begin = gettime();
			break;
			case "slide_end":
			self.challenge_slide_end = gettime();
			break;
		}
	}
}


function watchSprint()
{
	self endon( "death" );
	self endon( "disconnect" );

	self.challenge_sprint_begin = 0;
	self.challenge_sprint_end = 0;
	for(;;)
	{
		ret = util::waittill_any_return( "sprint_begin", "sprint_end", "disconnect" );
		switch( ret )
		{
			case "sprint_begin":
			self.challenge_sprint_begin = gettime();
			break;
			case "sprint_end":
			self.challenge_sprint_end = gettime();
			break;
		}
	}
}



function challengeKills( data )
{
	victim = data.victim;
	attacker = data.attacker;
	time = data.time;
	level.numKills++;
	attacker.lastKilledPlayer			= victim;
	attackerDoubleJumping				= data.attackerDoubleJumping;
	attackerflashbackTime				= data.attackerflashbackTime;
	attackerHeroAbility					= data.attackerHeroAbility;
	attackerHeroAbilityActive			= data.attackerHeroAbilityActive;
	attackerSliding						= data.attackerSliding;
	attackerSpeedburst					= data.attackerSpeedburst;
	attackerTraversing					= data.attackerTraversing;
	attackerVisionPulseActivateTime		= data.attackerVisionPulseActivateTime;
	attackerVisionPulseArray			= data.attackerVisionPulseArray;
	attackerVisionPulseOrigin			= data.attackerVisionPulseOrigin;
	attackerVisionPulseOriginArray		= data.attackerVisionPulseOriginArray;
	attackerWallRunning					= data.attackerWallRunning;
	attackerWasConcussed				= data.attackerWasConcussed;
	attackerWasFlashed					= data.attackerWasFlashed;
	attackerWasHeatWaveStunned			= data.attackerWasHeatWaveStunned;
	attackerWasOnGround					= data.attackerOnGround;
	attackerWasUnderwater				= data.attackerWasUnderwater;
	attackerLastFastReloadTime			= data.attackerLastFastReloadTime;
	lastWeaponBeforeToss				= data.lastWeaponBeforeToss;
	meansOfDeath						= data.sMeansOfDeath;
	ownerWeaponAtLaunch					= data.ownerWeaponAtLaunch;
	victimBedOut						= data.bledOut;
	victimOrigin						= data.victimOrigin;
	victimCombatEfficiencyLastOnTime	= data.victimCombatEfficiencyLastOnTime;
	victimCombatEfficieny				= data.victimCombatEfficieny;
	victimElectrifiedBy					= data.victimElectrifiedBy;
	victimflashbackTime					= data.victimflashbackTime;
	victimHeroAbility					= data.victimHeroAbility;
	victimHeroAbilityActive				= data.victimHeroAbilityActive;
	victimSpeedburst					= data.victimSpeedburst;
	victimSpeedburstLastOnTime			= data.victimSpeedburstLastOnTime;
	victimVisionPulseActivateTime		= data.victimVisionPulseActivateTime;
	victimVisionPulseActivateTime		= data.victimVisionPulseActivateTime;
	victimVisionPulseArray				= data.victimVisionPulseArray;
	victimVisionPulseOrigin				= data.victimVisionPulseOrigin;
	victimVisionPulseOriginArray		= data.victimVisionPulseOriginArray;
	victimAttackersThisSpawn			= data.victimAttackersThisSpawn;
	victimWasDoubleJumping				= data.victimWasDoubleJumping;
	victimWasInSlamState				= data.victimWasInSlamState;
	victimWasLungingWithArmBlades		= data.victimWasLungingWithArmBlades;
	victimWasOnGround					= data.victimOnGround;
	victimWasUnderwater					= data.wasUnderwater;
	victimWasWallRunning				= data.victimWasWallRunning;
	victimLastStunnedBy					= data.victimLastStunnedBy;
	victimActiveProximityGrenades		= data.victim.activeProximityGrenades;
	victimActiveBouncingBetties			= data.victim.activeBouncingBetties;
	attackerLastFlashedBy				= data.attackerLastFlashedBy;
	attackerLastStunnedBy				= data.attackerLastStunnedBy;
	attackerLastStunnedTime				= data.attackerLastStunnedTime;
	attackerWasSliding					= data.attackerWasSliding;
	attackerWasSprinting				= data.attackerWasSprinting;
	wasDefusing							= data.wasDefusing;
	wasPlanting							= data.wasPlanting;
	inflictorOwnerWasSprinting			= data.inflictorOwnerWasSprinting;
	player 								= data.attacker;
	playerOrigin						= data.attackerOrigin;
	weapon 								= data.weapon;
	
	victim_doublejump_begin				= data.victim_doublejump_begin;
	victim_doublejump_end				= data.victim_doublejump_end;
	victim_jump_begin					= data.victim_jump_begin;
	victim_jump_end						= data.victim_jump_end;
	victim_swimming_begin				= data.victim_swimming_begin;
	victim_swimming_end					= data.victim_swimming_end;
	victim_slide_begin					= data.victim_slide_begin;
	victim_slide_end					= data.victim_slide_end;
	victim_wallrun_begin				= data.victim_wallrun_begin;
	victim_wallrun_end					= data.victim_wallrun_end;
	victim_was_drowning					= data.victim_was_drowning;
	
	attacker_doublejump_begin			= data.attacker_doublejump_begin;
	attacker_doublejump_end				= data.attacker_doublejump_end;
	attacker_jump_begin					= data.attacker_jump_begin;
	attacker_jump_end					= data.attacker_jump_end;
	attacker_swimming_begin				= data.attacker_swimming_begin;
	attacker_swimming_end				= data.attacker_swimming_end;
	attacker_slide_begin				= data.attacker_slide_begin;
	attacker_slide_end					= data.attacker_slide_end;
	attacker_wallrun_begin				= data.attacker_wallrun_begin;
	attacker_wallrun_end				= data.attacker_wallrun_end;
	attacker_was_drowning				= data.attacker_was_drowning;
	attacker_sprint_end 				= data.attacker_sprint_end;
	attacker_sprint_begin 				= data.attacker_sprint_begin;
	
	attacker_wallRanTwoOppositeWallsNoGround	= data.attacker_wallRanTwoOppositeWallsNoGround;
	
	inflictorIsCooked = data.inflictorIsCooked;
	inflictorChallenge_hatchetTossCount = data.inflictorChallenge_hatchetTossCount;
	inflictorOwnerWasSprinting = data.inflictorOwnerWasSprinting;
	inflictorPlayerHasEngineerPerk = data.inflictorPlayerHasEngineerPerk;
	
	inflictor =	data.eInflictor; // MAY ALREADY BE REMOVED	


	if ( !isdefined( data.weapon ) )
	{
		return;
	}
	
	if ( !isdefined( player ) || !isplayer( player ) || ( weapon == level.weaponNone ) )
	{
		return;
	}

	// getting the altweapon name is not ideal, but acceptable for BO3's current weapons in MP;
	// TODO: add code-based accessor to parentWeaponName ("Stat Name" in APE)
	weaponClass = util::getWeaponClass( weapon );
	baseWeapon = getBaseWeapon( weapon );
	baseWeaponItemIndex = GetBaseWeaponItemIndex( baseWeapon );
	weaponPurchased = player isItemPurchased( baseWeaponItemIndex );
	victimSupportIndex = victim.team;
	playerSupportIndex = player.team;
	if ( !level.teambased )
	{
		playerSupportIndex = player.entnum;
		victimSupportIndex = victim.entnum;
	}

	if ( meansOfDeath == "MOD_HEAD_SHOT" || meansOfDeath == "MOD_PISTOL_BULLET" || meansOfDeath == "MOD_RIFLE_BULLET" )
	{
		bulletKill = true;
	}
	else
	{
		bulletKill = false;
	}
	
	if ( level.teambased ) 
	{
		if ( player.team == victim.team )
		{
			return;
		}
	}
	else
	{
		if ( player == victim )
		{
			return;
		}
	}
	
	killstreak = killstreaks::get_from_weapon( data.weapon );
	
	if ( !isdefined( killstreak ) )
	{
		player processSpecialistChallenge( "kills" );
		if (  weapon.isheroWeapon == true )
		{
			player processSpecialistChallenge( "kills_weapon" );
			player.heroWeaponKillsThisActivation++;
			player.pers["challenge_heroweaponkills"]++;
			if ( player.pers["challenge_heroweaponkills"] >= 6 )
			{
				player processSpecialistChallenge( "kill_one_game_weapon" );
				player.pers["challenge_heroweaponkills"] = 0;
			}
		}
	}
	
	if ( bulletKill ) 
	{
		if ( weaponPurchased )
		{
			if ( weaponclass == "weapon_sniper" )
			{
				if ( isdefined ( victim.firstTimeDamaged ) && victim.firstTimeDamaged == time )
				{
					player AddPlayerStat( "kill_enemy_one_bullet_sniper", 1 );
					player AddWeaponStat( weapon, "kill_enemy_one_bullet_sniper", 1 );
				}
			}
			else if ( weaponclass == "weapon_cqb" )
			{
				if ( isdefined ( victim.firstTimeDamaged ) && victim.firstTimeDamaged == time )
				{
					player AddPlayerStat( "kill_enemy_one_bullet_shotgun", 1 );
					player AddWeaponStat( weapon, "kill_enemy_one_bullet_shotgun", 1 );
				}
			}
		}
		
		if ( ( time - data.attacker_swimming_end <= 2000 ) && ( time - data.attacker_doublejump_begin <= 2000 ) )
		{
			player AddPlayerStat( "kill_after_doublejump_out_of_water", 1 );
		}

		if ( attackerWasSliding )
		{
			if ( attacker_doublejump_end == attacker_slide_begin )
			{
				player AddPlayerStat( "kill_while_sliding_from_doublejump", 1 );
			}
		}
		
		if ( ( player IsBonusCardActive( BONUSCARD_PRIMARY_GUNFIGHTER_3, player.class_num ) ) && player IsItemPurchased( GetItemIndexFromRef( "bonuscard_primary_gunfighter_3" ) ) )
		{
			if ( isdefined( weapon.attachments ) && weapon.attachments.size == 6 )
			{
				player AddPlayerStat( "kill_with_gunfighter", 1 );
			}
		}

		//Check for the killstreak 5 challenge completion
		checkkillstreak5( baseWeapon, player );
		
		if ( weapon.isDualWield && weaponPurchased )
		{
			checkDualWield( baseWeapon, player, attacker, time, attackerwassprinting, attacker_sprint_end );
		}
		
		if ( isdefined( weapon.attachments ) && weapon.attachments.size > 0 )
		{
			attachmentName = player GetWeaponOptic( weapon );
	
			if ( isdefined( attachmentName ) && attachmentName != "" && player WeaponHasAttachmentAndUnlocked( weapon, attachmentName ) )
			{
				if ( weapon.attachments.size > 5 && player AllWeaponAttachmentsUnlocked( weapon ) && !isdefined( attacker.tookWeaponFrom[ weapon ] ) )
				{
					player AddPlayerStat( "kill_optic_5_attachments", 1 );
				}
				if ( isdefined( player.attachmentKillsThisSpawn[ attachmentName ] ) )
				{
					player.attachmentKillsThisSpawn[ attachmentName ]++;
					if ( player.attachmentKillsThisSpawn[ attachmentName ] == 5 )
					{
						player AddWeaponStat( weapon, "killstreak_5_attachment", 1 );
					}
				}
				else
				{
					player.attachmentKillsThisSpawn[ attachmentName ] = 1;
				}
				
				if ( weapon_utils::isPistol( weapon.rootweapon ) )
				{
					if ( player weaponHasAttachmentAndUnlocked( weapon, "suppressed", "extbarrel" ) )
					{
						player AddPlayerStat( "kills_pistol_lasersight_suppressor_longbarrel", 1 );
					}
				}
			}
			
			if ( player weaponHasAttachmentAndUnlocked( weapon, "suppressed" ) )
			{
				if ( attacker util::has_hard_wired_perk_purchased_and_equipped() // hardwired
				    && attacker util::has_ghost_perk_purchased_and_equipped() // ghost
				    && attacker util::has_jetquiet_perk_purchased_and_equipped() ) // blast suppressor
				{
					player AddPlayerStat( "kills_suppressor_ghost_hardwired_blastsuppressor", 1 );
				}
			}
			
			if ( player PlayerAds() == 1 )
			{
				if ( isdefined( player.smokeGrenadeTime ) && isdefined( player.smokeGrenadePosition ) )
				{
					if ( player.smokeGrenadeTime + 14000 > time )
					{
						if ( player util::is_looking_at( player.smokeGrenadePosition ) || ( distancesquared( player.origin, player.smokeGrenadePosition ) < 200 * 200  ))
						{
							if ( player weaponHasAttachmentAndUnlocked( weapon, "ir" ) )
							{
								player AddPlayerStat( "kill_with_thermal_and_smoke_ads", 1 );
								player AddWeaponStat( weapon, "kill_thermal_through_smoke", 1 );
							}
						}
					}
				}
			}
				
			if ( weapon.attachments.size > 1 )
			{
				if ( player PlayerAds() == 1 )
				{
					if ( player weaponHasAttachmentAndUnlocked( weapon, "grip", "quickdraw" ) )
					{
						player AddPlayerStat( "kills_ads_quickdraw_and_grip", 1 );
					}
					if ( player weaponHasAttachmentAndUnlocked( weapon, "swayreduc", "stalker" ) )
					{
						player AddPlayerStat( "kills_ads_stock_and_cpu", 1 );
					}
				}
				else
				{
					if ( player weaponHasAttachmentAndUnlocked( weapon, "rf", "steadyaim" ) )
					{
						if ( attacker util::has_fast_hands_perk_purchased_and_equipped() )
						{
							player AddPlayerStat( "kills_hipfire_rapidfire_lasersights_fasthands", 1 );	
						}
					}
				}
				if ( player weaponHasAttachmentAndUnlocked( weapon, "fastreload", "extclip" ) )
				{
					player.pers["killsFastMagExt"]++;
					if ( player.pers["killsFastMagExt"] > 4 ) 
					{
						player AddPlayerStat( "kills_one_life_fastmags_and_extclip", 1 );
						player.pers["killsFastMagExt"] = 0;
					}
				}
			}
			
			if ( weapon.attachments.size > 2 )
			{
				if (  meansOfDeath == "MOD_HEAD_SHOT" ) 
				{
					if ( player weaponHasAttachmentAndUnlocked( weapon, "fmj", "damage", "extbarrel" ) )
					{
						player AddPlayerStat( "headshot_fmj_highcaliber_longbarrel", 1 );
					}
				}
			}
			
			if ( weapon.attachments.size > 4 )
			{
				if ( player weaponHasAttachmentAndUnlocked( weapon, "extclip", "grip", "fastreload", "quickdraw", "stalker" ) )
				{
					player AddPlayerStat( "kills_extclip_grip_fastmag_quickdraw_stock", 1 );
				}
			}
		}
		
		if ( victim_was_drowning && attacker_was_drowning )
		{
			player AddPlayerStat( "dr_lung", 1 );
		}
		
		if ( isdefined( attackerLastFastReloadTime ) && ( time - attackerLastFastReloadTime <= 5000 ) && player WeaponHasAttachmentAndUnlocked( weapon, "fastreload" ) )
		{
			player AddPlayerStat( "kills_after_reload_fastreload", 1 );
		}

		if ( victim.iDFlagsTime == time )
		{
			if ( victim.iDFlags & IDFLAGS_PENETRATION )
			{
				player AddPlayerStat( "kill_enemy_through_wall", 1 );
				if ( player weaponHasAttachmentAndUnlocked( weapon, "fmj" ) )
				{
					player AddPlayerStat( "kill_enemy_through_wall_with_fmj", 1 );		
				}
			}
		}
	
		if ( attacker_wallRanTwoOppositeWallsNoGround === true )
		{
			player AddPlayerStat( "kill_while_wallrunning_2_walls", 1 );
		}	
		
		// end if ( bulletkill )
	}
	else if ( weapon_utils::isMeleeMOD( meansOfDeath ) && !isdefined( killstreak ) )
	{
		player AddPlayerStat( "melee", 1 );
		if ( weapon_utils::isPunch( weapon ) )
		{
			player AddPlayerStat( "kill_enemy_with_fists", 1 );
		}
		
		//Check for the killstreak 5 challenge completion
		checkkillstreak5( baseWeapon, player );
	}
	else 
	{
		if ( weaponPurchased )
		{
			if ( weapon == player.grenadeTypePrimary )
			{
				if ( player.challenge_scavengedCount > 0 )
				{
					player.challenge_resuppliedNameKills++;
					if ( player.challenge_resuppliedNameKills >= 3 )
					{
						player AddPlayerStat( "kills_3_resupplied_nade_one_life", 1 );
						player.challenge_resuppliedNameKills = 0;
					}
					player.challenge_scavengedCount--;
				}
			}
			if ( isdefined( inflictorIsCooked ) )
			{
				if ( inflictorIsCooked == true && weapon.rootweapon.name != "hatchet" )
				{
					player AddPlayerStat( "kill_with_cooked_grenade", 1 );
				}
			}
	
			if ( victimLastStunnedBy === player )
			{
				if ( weaponclass == "weapon_grenade" )
				{
					player AddPlayerStat( "kill_stun_lethal", 1 );
				}
			}
			
			if ( baseWeapon == level.weaponSpecialCrossbow )
			{				
				if ( weapon.isDualWield ) // determined purchased
				{
					checkDualWield( baseWeapon, player, attacker, time, attackerwassprinting, attacker_sprint_end );
				}
			}
			
			// for "energy" shotgun
			if ( baseWeapon == level.weaponShotgunEnergy )
			{
				if ( isdefined ( victim.firstTimeDamaged ) && victim.firstTimeDamaged == time ) 
				{
					player AddPlayerStat( "kill_enemy_one_bullet_shotgun", 1 );
					player AddWeaponStat( weapon, "kill_enemy_one_bullet_shotgun", 1 );
				}
			}
		}
		
		if ( baseWeapon.forceDamageHitLocation || baseWeapon == level.weaponSpecialCrossbow || baseWeapon == level.weaponShotgunEnergy || baseWeapon == level.weaponSpecialDiscGun || baseWeapon == level.weaponBallisticKnife || baseWeapon == level.weaponLauncherEx41 )
		{
			//Check for the killstreak 5 challenge completion
			checkkillstreak5( baseWeapon, player );
		}
	}
	
	if ( isdefined( attacker.tookWeaponFrom[ weapon ] ) && isdefined( attacker.tookWeaponFrom[ weapon ].previousOwner ) )
	{
		if ( !isdefined( attacker.tookWeaponFrom[ weapon ].previousOwner.team ) || attacker.tookWeaponFrom[ weapon ].previousOwner.team != player.team )
		{
			player AddPlayerStat( "kill_with_pickup", 1 );
		}
	}
	
	awarded_kill_enemy_that_blinded_you = false;
	
	playerHasTacticalMask = loadout::hasTacticalMask( player );
	
	if ( attackerWasFlashed )
	{
		if ( attackerLastFlashedBy === victim && !playerHasTacticalMask )
		{
			player AddPlayerStat( "kill_enemy_that_blinded_you", 1 );		
			awarded_kill_enemy_that_blinded_you = true;
		}
	}
	
	if ( !awarded_kill_enemy_that_blinded_you && isdefined( attackerLastStunnedTime ) && attackerLastStunnedTime + 5000 > time ) 
	{
		if ( attackerLastStunnedBy === victim && !playerHasTacticalMask )
		{
			player AddPlayerStat( "kill_enemy_that_blinded_you", 1 );
			awarded_kill_enemy_that_blinded_you = true;
		}
	}
	
	killedStunnedVictim = false;
	if ( isdefined( victim.lastConcussedBy ) && victim.lastConcussedBy == attacker )
	{
		if ( victim.concussionEndTime > time )
		{
			if ( player util::is_item_purchased( "concussion_grenade" ) )
			{
				player AddPlayerStat( "kill_concussed_enemy", 1 );
			}
			killedStunnedVictim = true;
			player AddWeaponStat( GetWeapon( "concussion_grenade" ), "CombatRecordStat", 1 );
		}
	}
	
	if ( isdefined( victim.lastShockedBy ) && victim.lastShockedBy == attacker )
	{
		if ( victim.shockEndTime > time )
		{
			if ( player util::is_item_purchased( "proximity_grenade" ) )
			{
				player AddPlayerStat( "kill_shocked_enemy", 1 );
			}
			player AddWeaponStat( GetWeapon( "proximity_grenade" ), "CombatRecordStat", 1 );
			killedStunnedVictim = true;
			if ( weapon.rootweapon.name == "bouncingbetty" )
			{
				player AddPlayerStat( "kill_trip_mine_shocked", 1 );
			}
		}
		
	}

	if ( victim util::isFlashbanged() )
	{
		if ( isdefined( victim.lastFlashedBy ) && victim.lastFlashedBy == player )
		{
			killedStunnedVictim = true;
			if ( player util::is_item_purchased( "flash_grenade" ) )
			{
				player AddPlayerStat( "kill_flashed_enemy", 1 );
			}
			player AddWeaponStat( GetWeapon( "flash_grenade" ), "CombatRecordStat", 1 );
		}
	}		

	if ( level.teamBased )
	{
		if ( ( !isDefined( player.pers["kill_every_enemy_with_specialist"] ) ) &&  ( level.playerCount[victim.pers["team"]] > 3 && player.pers["killed_players_with_specialist"].size >= level.playerCount[victim.pers["team"]] ) )
		{
			player AddPlayerStat( "kill_every_enemy", 1 );
			player.pers["kill_every_enemy_with_specialist"] = true;
		}
		
		
		if ( isdefined( victimAttackersThisSpawn ) && IsArray( victimAttackersThisSpawn ) )
		{
			if ( victimAttackersThisSpawn.size > 5 )
			{
				attackerCount = 0;
				foreach( attacking_player in victimAttackersThisSpawn )
				{					
					if ( !isdefined( attacking_player ) )
						continue;
					
					if ( attacking_player == attacker )
						continue;
						
					if ( attacking_player.team != attacker.team )
						continue;
					
					attackerCount++;
				}
				
				if ( attackerCount > 4 )
				{
					// note: "kill_enemy_5_teammates_assists" should be awarded withing on life, not just assist
					player AddPlayerStat( "kill_enemy_5_teammates_assists", 1 );
				}
			}
		}
	}
	
	if ( isdefined( killstreak ) )
	{
		if ( killstreak == "rcbomb" || killstreak == "inventory_rcbomb" ) 
		{
			if ( !victimWasOnGround || victimWasWallRunning )
			{
				player AddPlayerStat( "kill_wallrunner_or_air_with_rcbomb", 1 );
			}
		}
		
		if ( killstreak == "autoturret" || killstreak == "inventory_autoturret" )
	    {
			if ( isdefined( inflictor ) && player util::is_item_purchased( "killstreak_auto_turret" ) )
			{
		    	if ( !isdefined( inflictor.challenge_killcount ) )
		    	{
		    		inflictor.challenge_killcount = 0;
		    	}
		    	
		    	inflictor.challenge_killcount++;
		    	if ( inflictor.challenge_killcount == 5 ) 
		    	{
		    		player AddPlayerStat( "kills_auto_turret_5", 1 );
		    	}
			}
	    }
	}
	
	if ( isdefined( victim.challenge_combatRobotAttackClientID[player.clientid] ) )
    {
		if ( !isdefined( inflictor ) || !isdefined( inflictor.killstreakType ) || !IsString( inflictor.killstreakType ) || ( inflictor.killstreakType != "combat_robot" ) )
		{
			player AddPlayerStat( "kill_enemy_who_damaged_robot", 1 );
		}
    }
	
	if ( player IsBonusCardActive( BONUSCARD_DANGER_CLOSE, player.class_num ) && player util::is_item_purchased( "bonuscard_danger_close" ) )
	{
		if ( weaponclass == "weapon_grenade" ) 
		{
			player AddBonusCardStat( BONUSCARD_DANGER_CLOSE, "kills", 1, player.class_num );
		}
		if ( weapon.rootweapon.name == "hatchet" && inflictorChallenge_hatchetTossCount <= 2 )
		{
			player.challenge_hatchetkills++;
			if ( player.challenge_hatchetkills == 2 )
			{
				player AddPlayerStat( "kills_first_throw_both_hatchets", 1 );
			}
		}
	}
	
	player trackKillstreakSupportKills( victim );
	
	// PERKS
	if ( !isdefined( killstreak ) )
	{
		if ( attackerWasUnderwater )
		{
			player AddPlayerStat( "kill_while_underwater", 1 );
		}

		if ( player util::has_purchased_perk_equipped( "specialty_jetcharger" ) ) // afterburner
		{
			if ( ( attacker_doublejump_begin > attacker_doublejump_end || attacker_doublejump_end + 3000 > time )
			    || ( attacker_slide_begin > attacker_slide_end || attacker_slide_end + 3000 > time ) )
			{
				player AddPlayerStat( "kills_after_jumping_or_sliding", 1 );	
				
				if ( player util::has_purchased_perk_equipped( "specialty_overcharge" ) )
				{
					{
						player AddPlayerStat( "kill_overclock_afterburner_specialist_weapon_after_thrust", 1 );
					}
				}
			}	
		}
		
		trackedPlayer = false;
		if ( player util::has_purchased_perk_equipped( "specialty_tracker" ) )
		{
			if ( !victim hasPerk ( "specialty_trackerjammer" ) ) // hardwired
			{
				player AddPlayerStat( "kill_detect_tracker", 1 );	
				trackedPlayer = true;
			}
		}
				
		if ( player util::has_purchased_perk_equipped( "specialty_detectnearbyenemies" ) ) // sixth sense
		{
			if ( !victim hasPerk ( "specialty_sixthsensejammer" ) )
			{
				player AddPlayerStat( "kill_enemy_sixth_sense", 1 );	
				
				if ( player util::has_purchased_perk_equipped( "specialty_loudenemies" ) ) // awareness
				{
					if ( !victim hasPerk ( "specialty_quieter" ) ) // dead silence
					{
						player AddPlayerStat( "kill_sixthsense_awareness", 1 );	
					}
				}	
			}
			
			if ( trackedPlayer )
			{
				player AddPlayerStat( "kill_tracker_sixthsense", 1 );	
			}
		}
		
		if ( weapon.isheroWeapon == true || attackerHeroAbilityActive )
		{
			if ( player util::has_purchased_perk_equipped( "specialty_overcharge" ) ) // overclock
			{		
				player AddPlayerStat( "kill_with_specialist_overclock", 1 );			
			}
		}

		if ( player util::has_purchased_perk_equipped( "specialty_gpsjammer" ) ) // ghost
		{
			if ( uav::HasUAV( victimSupportIndex ) )
			{
				player AddPlayerStat( "kill_uav_enemy_with_ghost", 1 );
			}
			
			if ( player util::has_blind_eye_perk_purchased_and_equipped() ) // blindeye
			{
				activeKillstreaks = victim killstreaks::getActiveKillstreaks();
			
				awarded_kill_blindeye_ghost_aircraft = false;
				foreach( activeStreak in activeKillstreaks )
				{
					if ( awarded_kill_blindeye_ghost_aircraft )
						break;
					
					switch( activeStreak.killstreakType ) 
					{
						case "sentinel":
						case "helicopter_comlink":
						case "drone_striked":
						case "uav":
							player AddPlayerStat( "kill_blindeye_ghost_aircraft", 1 );
							awarded_kill_blindeye_ghost_aircraft = true;
							break;
					}
				}
			}
		}
		if ( player util::has_purchased_perk_equipped( "specialty_flakjacket" ) )
		{
			if ( isdefined ( player.challenge_lastsurvivewithflakfrom ) && player.challenge_lastsurvivewithflakfrom == victim )
			{
				player AddPlayerStat( "kill_enemy_survive_flak", 1 );
			}
			
			
			if ( player util::has_tactical_mask_purchased_and_equipped() )
			{
				recentlySurvivedFlak = false;
				if ( isdefined ( player.challenge_lastsurvivewithflaktime ) )
				{
				 	if ( ( player.challenge_lastsurvivewithflaktime + 3000 ) > time )
				 	{
				 		recentlySurvivedFlak = true;
				 	}
				}
				recentlyStunned = false;
				if ( isdefined( player.lastStunnedTime ) )
				{
					if ( player.lastStunnedTime + 2000 > time )
					{
						recentlyStunned = true;
					}
				}
				if ( recentlySurvivedFlak
				    || ( player util::isFlashbanged() )
				    || recentlyStunned )
				{
					player AddPlayerStat( "kill_flak_tac_while_stunned", 1 );
				}
			}
		}
		
		if ( player util::has_hard_wired_perk_purchased_and_equipped() ) // hard wired
		{
			if ( victim counteruav::HasIndexActiveCounterUAV( victimSupportIndex ) || victim emp::hasactiveemp() )
			{
				player AddPlayerStat( "kills_counteruav_emp_hardline", 1 );
			}
		}
		
		if ( player util::has_scavenger_perk_purchased_and_equipped() )
		{
			if ( player.scavenged )
			{
				player AddPlayerStat( "kill_after_resupply", 1 );
				if ( trackedPlayer )
				{
					player AddPlayerStat( "kill_scavenger_tracker_resupply", 1 );
				}
			}
		}		
		
		if ( player util::has_fast_hands_perk_purchased_and_equipped() ) // fasthands
		{
			if ( bulletKill ) 
			{
				if ( attackerWasSprinting || attacker_sprint_end + 3000 > time )
				{
					player AddPlayerStat( "kills_after_sprint_fasthands", 1 );
					if ( player util::has_gung_ho_perk_purchased_and_equipped() ) // gungho
					{
						player AddPlayerStat( "kill_fasthands_gungho_sprint", 1 );
					}
				}
			}
		}
		
		if ( player util::has_hard_wired_perk_purchased_and_equipped() ) // hardwired
		{
			if ( player util::has_cold_blooded_perk_purchased_and_equipped() ) // cold blooded
			{
				player AddPlayerStat( "kill_hardwired_coldblooded", 1 );
			}
		}
		
		
		killedPlayerWithGungHo = false;
		if ( player util::has_gung_ho_perk_purchased_and_equipped() ) // gung ho
		{
			if ( bulletKill ) 
			{
				killedPlayerWithGungHo = true;
				if ( attackerWasSprinting && player PlayerAds() != 1 )
				{
					player AddPlayerStat( "kill_hip_gung_ho", 1 );
				}
			}
			if ( weaponclass == "weapon_grenade" )
			{
				if ( isdefined( inflictorOwnerWasSprinting ) && inflictorOwnerWasSprinting == true )
				{
					killedPlayerWithGungHo = true;
					player AddPlayerStat( "kill_hip_gung_ho", 1 );
				}
			}
		}
		
		if ( player util::has_jetquiet_perk_purchased_and_equipped() ) // blast surpressor
		{
			if ( attackerDoubleJumping || ( attacker_doublejump_end + 3000 > time ) )
			{
				player AddPlayerStat( "kill_blast_doublejump", 1 );
				if ( player util::has_ghost_perk_purchased_and_equipped() ) // ghost
				{
					if ( uav::HasUAV( victimSupportIndex ) )
					{
						player AddPlayerStat( "kill_doublejump_uav_engineer_hardwired", 1 );
					}
				}
			}
		}
		if ( player util::has_awareness_perk_purchased_and_equipped() ) // awareness
		{
			player AddPlayerStat( "kill_awareness", 1 );
		}
	
		if ( killedStunnedVictim ) 
		{
			if ( player util::has_tactical_mask_purchased_and_equipped() )  // tacmask
			{
				player AddPlayerStat( "kill_stunned_tacmask", 1 );
				if ( killedPlayerWithGungHo == true )
				{
					player AddPlayerStat( "kill_sprint_stunned_gungho_tac", 1 );
				}
			}
		}
		
		if ( player util::has_ninja_perk_purchased_and_equipped() ) // dead silence
		{
			player AddPlayerStat( "kill_dead_silence", 1 );
			
			if ( distanceSquared( playerOrigin, victimOrigin ) < 120 * 120 )
			{
				if ( player util::has_awareness_perk_purchased_and_equipped() ) // awareness
				{
					player AddPlayerStat( "kill_close_deadsilence_awareness", 1 );
				}
				
				if ( player util::has_jetquiet_perk_purchased_and_equipped() ) // blast suppressr
				{
					player AddPlayerStat( "kill_close_blast_deadsilence", 1 );
				}
			}
		}

		greedCardsActive = 0;
		if ( player IsBonusCardActive( BONUSCARD_PERK_1_GREED, player.class_num ) && player util::is_item_purchased( "bonuscard_perk_1_greed" ) )
		{
			greedCardsActive++;
		}
		if ( player IsBonusCardActive( BONUSCARD_PERK_2_GREED, player.class_num ) && player util::is_item_purchased( "bonuscard_perk_2_greed" ) )
		{
			greedCardsActive++;
		}
		if ( player IsBonusCardActive( BONUSCARD_PERK_3_GREED, player.class_num ) && player util::is_item_purchased( "bonuscard_perk_3_greed" ) )
		{
			greedCardsActive++;
		}

		if ( greedCardsActive >= 2 )
		{
			player AddPlayerStat( "kill_2_greed_2_perks_each", 1 );
		}

		if ( player BonusCardActiveCount( player.class_num ) >= 2 ) 
		{
			player AddPlayerStat( "kill_2_wildcards", 1 );
		}
		
		
		gunfighterOverkillActive = false;
		if ( player IsBonusCardActive( BONUSCARD_OVERKILL, player.class_num ) && player util::is_item_purchased( "bonuscard_overkill" ) )
		{
			primaryAttachmentsTotal = 0;			
			if ( isdefined( player.primaryLoadoutWeapon ) )
				primaryAttachmentsTotal = player.primaryLoadoutWeapon.attachments.size;

			secondaryAttachmentsTotal = 0;			
			if ( isdefined( player.secondaryLoadoutWeapon ) )
				secondaryAttachmentsTotal = player.secondaryLoadoutWeapon.attachments.size;

			if ( primaryAttachmentsTotal + secondaryAttachmentsTotal >= 5 )
			{
				gunfighterOverkillActive = true;
			}
		}
		
		if ( ( isdefined (player.primaryLoadoutWeapon ) && weapon == player.primaryLoadoutWeapon ) 
			||  ( isdefined (player.primaryLoadoutAltWeapon ) && weapon == player.primaryLoadoutAltWeapon ) )
		{
			if ( player IsBonusCardActive( BONUSCARD_PRIMARY_GUNFIGHTER, player.class_num ) && player util::is_item_purchased( "bonuscard_primary_gunfighter" ) )
			{
				player AddBonusCardStat( BONUSCARD_PRIMARY_GUNFIGHTER, "kills", 1, player.class_num );
				player AddPlayerStat( "kill_with_loadout_weapon_with_3_attachments", 1 );
			}
			if ( isdefined( player.secondaryWeaponKill ) && player.secondaryWeaponKill == true )
			{
				player.primaryWeaponKill = false;
				player.secondaryWeaponKill = false;
				if ( player IsBonusCardActive( BONUSCARD_OVERKILL, player.class_num ) && player util::is_item_purchased( "bonuscard_overkill" ) )
				{
					player AddBonusCardStat( BONUSCARD_OVERKILL, "kills", 1, player.class_num );
					player AddPlayerStat( "kill_with_both_primary_weapons", 1 );
					if ( gunfighterOverkillActive ) 
					{
						player AddPlayerStat( "kill_overkill_gunfighter_5_attachments", 1 );
					}
				}
			}
			else
			{
				player.primaryWeaponKill = true;
			}
		}
		else if ( ( isdefined( player.secondaryLoadoutWeapon ) && weapon == player.secondaryLoadoutWeapon )
			         || ( isdefined( player.secondaryLoadoutAltWeapon ) && weapon == player.secondaryLoadoutAltWeapon ) )
		{
			if ( player IsBonusCardActive( BONUSCARD_SECONDARY_GUNFIGHTER, player.class_num ) && player util::is_item_purchased( "bonuscard_secondary_gunfighter" ) )
			{
				player AddBonusCardStat( BONUSCARD_SECONDARY_GUNFIGHTER, "kills", 1, player.class_num );
			}
			if ( isdefined( player.primaryWeaponKill ) && player.primaryWeaponKill == true )
			{
				player.primaryWeaponKill = false;
				player.secondaryWeaponKill = false;
				if ( player IsBonusCardActive( BONUSCARD_OVERKILL, player.class_num ) && player util::is_item_purchased( "bonuscard_overkill" ) )
				{
					player AddBonusCardStat( BONUSCARD_OVERKILL, "kills", 1, player.class_num );
					player AddPlayerStat( "kill_with_both_primary_weapons", 1 );
					if ( gunfighterOverkillActive ) 
					{
						player AddPlayerStat( "kill_overkill_gunfighter_5_attachments", 1 );
					}
				}
			}
			else
			{
				player.secondaryWeaponKill = true;
			}
		}
		
		if ( player util::has_hacker_perk_purchased_and_equipped() && player util::has_hard_wired_perk_purchased_and_equipped() )
		{
			should_award_kill_near_plant_engineer_hardwired = false;
			
			if ( isdefined( victimActiveBouncingBetties ) )
			{
				foreach( bouncingBettyInfo in victimActiveBouncingBetties )
				{
					if ( !isdefined( bouncingBettyInfo ) || !isdefined( bouncingBettyInfo.origin ) )
						continue;
					
					if ( DistanceSquared( bouncingBettyInfo.origin, victimOrigin ) < SQR( KILL_NEAR_PLANT_ENGINEER_HARDWIRED_CLOSE_ENOUGH_DISTANCE ) )
					{
						should_award_kill_near_plant_engineer_hardwired = true;
						break;
					}
				}
			}
			
			if ( isdefined( victimActiveProximityGrenades ) && should_award_kill_near_plant_engineer_hardwired == false )
			{
				foreach( proximityGrenadeInfo in victimActiveProximityGrenades )
				{
					if ( !isdefined( proximityGrenadeInfo ) || !isdefined( proximityGrenadeInfo.origin ) )
						continue;
					
					if ( DistanceSquared( proximityGrenadeInfo.origin, victimOrigin ) < SQR( KILL_NEAR_PLANT_ENGINEER_HARDWIRED_CLOSE_ENOUGH_DISTANCE ) )
					{
						should_award_kill_near_plant_engineer_hardwired = true;
						break;
					}
				}
			}
			
			if ( should_award_kill_near_plant_engineer_hardwired )
			{
				player AddPlayerStat( "kill_near_plant_engineer_hardwired", 1 );
			}
		}
	}
	else // it was a killstreak
	{	
		if ( weapon.name == "supplydrop" ) 
		{
			if (isdefined( inflictorPlayerHasEngineerPerk ) )
			{
				player AddPlayerStat( "kill_booby_trap_engineer", 1 );	
			}
		}
	}
	
	if ( weapon.isHeroWeapon == true || attackerHeroAbilityActive || isdefined( killstreak ) )
	{
		if ( player util::has_purchased_perk_equipped( "specialty_overcharge" ) // overclock
		    && ( player util::has_purchased_perk_equipped( "specialty_anteup" ) ) ) // anteup
		{					
			player AddPlayerStat( "kill_anteup_overclock_scorestreak_specialist", 1 );					
		}
	}
}

function on_player_spawn()
{
	if ( canProcessChallenges() )
	{
		self fix_challenge_stats_on_spawn();
	}
}

function get_challenge_stat( stat_name )
{
	return self GetDStat( "playerstatslist", stat_name, "challengevalue" );
}

function force_challenge_stat( stat_name, stat_value )
{
	// make the stat value and challenge value identical
	self SetDStat( "playerstatslist", stat_name, "statvalue", stat_value );
	self SetDStat( "playerstatslist", stat_name, "challengevalue", stat_value );
}

function get_challenge_group_stat( group_name, stat_name )
{
	return self GetDStat( "groupstats", group_name, "stats", stat_name, "challengevalue" );
}

function fix_challenge_stats_on_spawn()
{
	// use this method to fix up any challenge inconsistencies at spawn

	player = self;
	
	if ( !isdefined( player ) )
		return;
	
	if ( player.fix_challenge_stats_performed === true )
		return;

	player fix_TU6_weapon_for_diamond( "special_crossbow_for_diamond" );
	player fix_TU6_weapon_for_diamond( "melee_crowbar_for_diamond" );
	player fix_TU6_weapon_for_diamond( "melee_sword_for_diamond" );
	player fix_TU6_ar_garand();
	player fix_TU6_pistol_shotgun();
	player TU7_fix_100_percenter();

	player.fix_challenge_stats_performed = true;
}

function fix_TU6_weapon_for_diamond( stat_name )
{
	player = self;
	
	wepaon_for_diamond = player get_challenge_stat( stat_name );

	if ( wepaon_for_diamond == 1 )
	{
		// valid values for X_for_diamond are 0, 2, and 3; TU5 has an issue for some challenges
		// where only 1 point was awarded if pistol diamond was awarded ( and some challenges where any secondary diamond camo was awwarded )
		// this fixes the issue by setting it to either zero or two
		
		secondary_mastery = player get_challenge_stat( "secondary_mastery" );

		if ( secondary_mastery == 3 )
		{
			player force_challenge_stat( stat_name, 2 );
		}
		else
		{
			player force_challenge_stat( stat_name, 0 );
		}
	}
}

function fix_TU6_ar_garand()
{
	player = self;
	
	group_weapon_assault = player get_challenge_group_stat( "weapon_assault", "challenges" );
	weapons_mastery_assault = player get_challenge_stat( "weapons_mastery_assault" );
	
	// earning weapons mastery on assault rifles prior to TU6 will exhibit an issue of not being able to obtain diamond camo for ar_garand
	// this fixes the issue by awarding ar_garand_for_diamond if weapons_mastery_assault was not obtained

	// 49 obtained from challenge 648 in statsmilestones3.csv
	if ( group_weapon_assault >= 49 && weapons_mastery_assault < 1 )
	{
		player force_challenge_stat( "weapons_mastery_assault", 1 ); // intentionally forced stat here to avoid stat processing

		player AddPlayerStat( "ar_garand_for_diamond", 1 ); // now add stat with stat processing
	}
}

function fix_TU6_pistol_shotgun()
{
	player = self;
	
	group_weapon_pistol = player get_challenge_group_stat( "weapon_pistol", "challenges" );
	secondary_mastery_pistol = player get_challenge_stat( "secondary_mastery_pistol" );

	// see comments in fix_TU6_ar_garand for more related details

	// 21 obtained from challenge 649 in statsmilestones3.csv
	if ( group_weapon_pistol >= 21 && secondary_mastery_pistol < 1 )
	{
		player force_challenge_stat( "secondary_mastery_pistol", 1 ); // intentionally forced stat here to avoid stat processing

		player AddPlayerStat( "pistol_shotgun_for_diamond", 1 ); // now add stat with stat processing
	}
}

function completed_specific_challenge( target_value, challenge_name )
{
	challenge_count = self get_challenge_stat( challenge_name );
	
	return ( challenge_count >= target_value );
}

function tally_completed_challenge( target_value, challenge_name )
{
	return ( ( self completed_specific_challenge( target_value, challenge_name ) ) ? 1 : 0 );
}

function TU7_fix_100_percenter()
{
	self TU7_fix_mastery_perk_2();
}

function TU7_fix_mastery_perk_2()
{
	player = self;
	
	// if mastery_perk_2 is compeleted, then no need to try to fix up
	mastery_perk_2 = player get_challenge_stat( "mastery_perk_2" );
	if ( mastery_perk_2 >= 12 )
		return;
	
	// if earn_scorestreak_anteup has not been completed, no need to try to fix up
	if ( player completed_specific_challenge( 200, "earn_scorestreak_anteup") == false )
		return;

	perk_2_tally = 1; // init to 1 because earn_scorestreak_anteup is already completed
	
	perk_2_tally += player tally_completed_challenge( 100, "destroy_ai_scorestreak_coldblooded" ); //destroy_ai_scorestreak_coldblooded
	perk_2_tally += player tally_completed_challenge( 100, "kills_counteruav_emp_hardline" ); //kills_counteruav_emp_hardline
	perk_2_tally += player tally_completed_challenge( 200, "kill_after_resupply" ); //kill_after_resupply
	perk_2_tally += player tally_completed_challenge( 100, "kills_after_sprint_fasthands" ); //kills_after_sprint_fasthands
	perk_2_tally += player tally_completed_challenge( 200, "kill_detect_tracker" ); //kill_detect_tracker
	//perk_2_tally += player tally_completed_challenge( 200, "earn_scorestreak_anteup" ); //earn_scorestreak_anteup
	perk_2_tally += player tally_completed_challenge( 10, "earn_5_scorestreaks_anteup" ); //earn_5_scorestreaks_anteup
	perk_2_tally += player tally_completed_challenge( 25, "kill_scavenger_tracker_resupply" ); //kill_scavenger_tracker_resupply
	perk_2_tally += player tally_completed_challenge( 25, "kill_hardwired_coldblooded" ); //kill_hardwired_coldblooded
	perk_2_tally += player tally_completed_challenge( 25, "kill_anteup_overclock_scorestreak_specialist" ); //kill_anteup_overclock_scorestreak_specialist
	perk_2_tally += player tally_completed_challenge( 50, "kill_fasthands_gungho_sprint" ); //kill_fasthands_gungho_sprint
	perk_2_tally += player tally_completed_challenge( 50, "kill_tracker_sixthsense" ); //kill_tracker_sixthsense

	if ( mastery_perk_2 < perk_2_tally )
	{
		// award "mastery_perk_2"
		player AddPlayerStat( "mastery_perk_2", 1 );
	}
}

function getBaseWeapon( weapon )
{
	// TODO: need to get weapon stat name available from script (and make sure all stat names are populated properly for weapons)
	base_weapon_param = [[ level.get_base_weapon_param ]]( weapon ); // we have a "root" weapon after this executes
	base_weapon_param_name = str_strip_lh_or_dw( base_weapon_param.name );
	base_weapon_param_name = str_strip_lh_from_crossbow( base_weapon_param_name ); // unique case because of poor naming convention
	return GetWeapon( GetRefFromItemIndex( GetBaseWeaponItemIndex( GetWeapon( base_weapon_param_name ) ) ) );
}

function str_strip_lh_from_crossbow( str )
{
	if ( StrEndsWith( str, "crossbowlh" ) )
	{
		return GetSubStr( str, 0, str.size - 2 );
	}

	return str;
}

function str_strip_lh_or_dw( str )
{
	if ( StrEndsWith( str, "_lh" ) || StrEndsWith( str, "_dw" ) )
	{
		return GetSubStr( str, 0, str.size - 3 );
	}

	return str;
}

function checkKillStreak5( baseWeapon, player )
{
	if ( isdefined( player.weaponKillsThisSpawn[ baseWeapon ] ) )
	{
		player.weaponKillsThisSpawn[ baseWeapon ]++;
		if ( ( player.weaponKillsThisSpawn[ baseWeapon ] ) % 5 == 0 )
		{
			player AddWeaponStat( baseWeapon, "killstreak_5", 1 );
		}
	}
	else
	{
		player.weaponKillsThisSpawn[ baseWeapon ] = 1;
	}
}

function checkDualWield( baseWeapon, player, attacker, time, attackerWasSprinting, attacker_sprint_end )
{
	// note: check weapon.isDualWield and weaponPurchased before calling checkDualWield for challenges.
	if ( attackerWasSprinting || ( attacker_sprint_end + 1000 > time ) )
	{
		if ( attacker util::has_gung_ho_perk_purchased_and_equipped() )
		{
			player AddPlayerStat( "kills_sprinting_dual_wield_and_gung_ho", 1 );
		}
	}
}

function challengeGameEndMP( data )
{
	player = data.player;
	winner = data.winner;
	
	if ( !isdefined( player ) )
		return;
	
	if ( endedEarly( winner ) )
		return;

	if ( level.teambased )
	{
		winnerScore = game["teamScores"][winner];
		loserScore = getLosersTeamScores( winner );
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
		if ( level.teambased )
		{
			playerIsWinner = ( player.team === winner );
		}
		else
		{
			// see if in top 3
			playerIsWinner = ( ( level.placement["all"][0] === winner ) || ( level.placement["all"][1] === winner ) || ( level.placement["all"][2] === winner ) );
		}
		
		if ( playerIsWinner )
		{
			player AddPlayerStat( "most_kills_least_deaths", 1 );
		}
	}
}

function killedBaseOffender( objective, weapon )
{
	self endon( "disconnect" );
	self AddPlayerStatWithGameType( "defends", 1 ); // awards the player for being a "defender" as they killed an offender
	
	self.challenge_offenderkillcount++;
	
	if ( !isdefined( self.challenge_objectiveOffensive ) || self.challenge_objectiveOffensive != objective )
	{
		self.challenge_objectiveOffensiveKillcount = 0;
	}
	
	self.challenge_objectiveOffensiveKillcount++;
	self.challenge_ObjectiveOffensive = objective;
	
	killstreak = killstreaks::get_from_weapon( weapon );

	if ( isdefined( killstreak ) ) 
	{
		switch ( killstreak )
		{
			case "planemortar":
			case "inventory_planemortar":
			case "remote_missile":
			case "inventory_remote_missile":
			case "drone_strike":
			case "inventory_drone_strike":
				self.challenge_offenderProjectileMultiKillcount++;
				break;
			case "helicopter_comlink":
			case "inventory_helicopter_comlink":
				self.challenge_offenderComlinkKillcount++;
				break;
			case "combat_robot":
			case "inventory_combat_robot":
				self AddPlayerStat( "kill_attacker_with_robot_or_tank", 1 );
				break;
			case "inventory_autoturret":
			case "autoturret":
				self.challenge_offenderSentryTurretKillCount++;
				self AddPlayerStat( "kill_attacker_with_robot_or_tank", 1 );
				break;
		}
	}

	if ( self.challenge_offenderComlinkKillcount == 2 )
	{
		self AddPlayerStat( "kill_2_attackers_with_comlink", 1 );
	}
	
	if ( self.challenge_objectiveOffensiveKillcount > 4 ) 
	{
		self AddPlayerStatWithGameType( "multikill_5_attackers", 1 );
		self.challenge_objectiveOffensiveKillcount = 0;
	}
	
	if ( self.challenge_offenderSentryTurretKillCount > 2 ) 
	{
		self AddPlayerStat( "multikill_3_attackers_ai_tank", 1 );
		self.challenge_offenderSentryTurretKillCount = 0;
	}

	self util::player_contract_event( "offender_kill" );

	self waitTillTimeoutOrDeath( 4.0 );
	
	if ( self.challenge_offenderkillcount > 1 )
	{
		self AddPlayerStat( "double_kill_attackers", 1 );
	}

	self.challenge_offenderkillcount = 0;
	
	if ( self.challenge_offenderProjectileMultiKillcount >= 2 )
	{
		self AddPlayerStat( "multikill_2_objective_scorestreak_projectile", 1 );
	}

	self.challenge_offenderProjectileMultiKillcount = 0;
}

function killedBaseDefender( objective )
{
	self endon( "disconnect" );
	self AddPlayerStatWithGameType( "offends", 1 ); // awards the player for being an "offender" as they killed a defender
	
	if ( !isdefined( self.challenge_objectiveDefensive ) || self.challenge_objectiveDefensive != objective )
	{
		self.challenge_objectiveDefensiveKillcount = 0;
	}
	
	self.challenge_objectiveDefensiveKillcount++;
	self.challenge_ObjectiveDefensive = objective;


	self.challenge_defenderkillcount++;
	
	self util::player_contract_event( "defender_kill" );

	self waitTillTimeoutOrDeath( 4.0 );
	
	if ( self.challenge_defenderkillcount > 1 )
	{
		self AddPlayerStat( "double_kill_defenders", 1 );
	}
	
	self.challenge_defenderkillcount = 0;
}

function waitTillTimeoutOrDeath( timeout )
{
	self endon( "death" );
	wait( timeout );
}

function killstreak_30_noscorestreaks()
{
	if ( level.gameType == "dm" )
	{
		self AddPlayerStat( "killstreak_30_no_scorestreaks", 1 );
	}
}

function heroAbilityActivateNearDeath()
{
	if ( isdefined( self.heroAbility ) && self.pers["canSetSpecialistStat"] )
	{
		switch( self.heroAbility.name )
		{
			case "gadget_camo":
			case "gadget_armor":
			case "gadget_clone":
			case "gadget_speed_burst":
			case "gadget_vision_pulse":
			case "gadget_flashback":
			case "gadget_heat_wave":
				self thread checkForHeroSurvival();
				break;
		}
	}
}


function checkForHeroSurvival()
{
	self endon ("death");
	self endon ("disconnect");
	
	self util::waittill_any_timeout( 8.0, "challenge_survived_from_death", "disconnect" );
	
	self AddPlayerStat( "death_dodger", 1 );
}


function callbackEndHeroSpecialistEMP()
{
	empOwner = self emp::EnemyEMPOwner();
	if ( isdefined( empOwner ) && IsPlayer( empOwner ) )
    {
    	empOwner AddPlayerStat( "end_enemy_specialist_ability_with_emp", 1 );
    	return;
    }

	if ( isdefined(  self.empStartTime ) && self.empStartTime > ( getTime() - 100 ) )
	{
		if ( isdefined(self.empedBy) && IsPlayer( self.empedBy ) )
		{
			self.empedBy AddPlayerStat( "end_enemy_specialist_ability_with_emp", 1 );
			return;
		}
	}
}



function calledInComlinkChopper()
{
	self.challenge_offenderComlinkKillcount	= 0;
}


function combat_robot_damage( eAttacker, combatRobotOwner )
{
	if ( !isdefined( eAttacker.challenge_combatRobotAttackClientID[combatRobotOwner.clientid]  ) )
	{
		eAttacker.challenge_combatRobotAttackClientID[combatRobotOwner.clientid] = spawnstruct();
	}
}


function trackKillstreakSupportKills( victim )
{
	if ( level.activePlayerEMPs[ self.entNum ] > 0 )
	{
		self AddWeaponStat( GetWeapon( "emp" ), "kills_while_active", 1 );
	}
	
	if ( ( level.activePlayerUAVs[ self.entNum ] > 0 ) && ( !isdefined( level.forceradar ) || level.forceRadar == false ) )
	{
		self AddWeaponStat( GetWeapon( "uav" ), "kills_while_active", 1 );
	}
	
	if ( level.activePlayerSatellites[ self.entNum ] > 0 )
	{
		self AddWeaponStat( GetWeapon( "satellite" ), "kills_while_active", 1 );
	}
	
	if ( level.activePlayerCounterUAVs[ self.entNum ] > 0 )
	{ 
		self AddWeaponStat( GetWeapon( "counteruav" ), "kills_while_active", 1 );
	}
	
	if ( isdefined( victim.lastMicrowavedBy ) && victim.lastMicrowavedBy == self )
	{
		self AddWeaponStat( GetWeapon( "microwave_turret" ), "kills_while_active", 1 );
	}	
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
		
		if ( WeaponHasAttachment( currentWeapon, "fastreload" ) ) // aka fastmags or Fast Mags
		{
			self.lastFastReloadTime = time;
		}
	}
}

function monitorGrenadeFire()
{
	self notify( "grenadeTrackingStart" );
	
	self endon( "grenadeTrackingStart" );
	self endon( "disconnect" );
	
	for (;;)
	{
		self waittill ( "grenade_fire", grenade, weapon );
		
		if ( !isdefined( grenade ) )
		{
			continue;
		}
		
		if ( weapon.rootweapon.name == "hatchet" )
		{
			self.challenge_hatchetTossCount++;
			grenade.challenge_hatchetTossCount = self.challenge_hatchetTossCount;
		}
		if ( self issprinting() )
		{
			grenade.ownerWasSprinting = true;
		}
	}
}

function watchWeaponChangeComplete()
{
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );
			
	while( 1 )
	{
		self.heroWeaponKillsThisActivation = 0;
	
		self waittill( "weapon_change_complete" );
	}
}

function longDistanceKillMP( weapon )
{
	self AddWeaponStat( weapon, "longshot_kill", 1 );
	if ( self weaponHasAttachmentAndUnlocked( weapon, "extbarrel", "suppressed" ) )
	{
		if ( self GetWeaponOptic( weapon ) != "" )
		{
			self addPlayerStat( "long_shot_longbarrel_suppressor_optic", 1 );
		}
	}
}


function capturedObjectiveFunction()
{
	if ( self IsBonusCardActive( BONUSCARD_TWO_TACTICALS, self.class_num ) && self util::is_item_purchased( "bonuscard_two_tacticals" ) )
	{
		self AddPlayerStat( "capture_objective_tactician", 1 );
	}
}

function watchWallRunTwoOppositeWallsNoGround()
{
	player = self;
	player endon( "death" );
	player endon( "disconnect" );
	player endon( "joined_team" );
	player endon( "joined_spectators" );
	
	self.wallRanTwoOppositeWallsNoGround = false;

	while ( 1 )
	{
		if ( !player IsWallRunning() )
		{
			self.wallRanTwoOppositeWallsNoGround = false;
			player waittill( "wallrun_begin" );
		}

		ret = player util::waittill_any_return( "jump_begin", "wallrun_end", "disconnect", "joined_team", "joined_spectators" );
		if ( ret == "wallrun_end" )
			continue;
		
		wall_normal = player GetWallRunWallNormal();

		player waittill( "jump_end" );
		
		if ( !player IsWallRunning() )
			continue;
					
		last_wall_normal = wall_normal;
		wall_normal = player GetWallRunWallNormal();
		
		opposite_walls = ( VectorDot( wall_normal, last_wall_normal ) < -0.5 );
		if ( !opposite_walls )
			continue;

		player.wallRanTwoOppositeWallsNoGround = true;

		while ( player IsWallRunning() )
		{
			ret = player util::waittill_any_return( "jump_end", "wallrun_end", "disconnect", "joined_team", "joined_spectators" );
			
			if ( ret == "wallrun_end" )
				break;
		}

		WAIT_SERVER_FRAME;
		
		while ( !player IsOnGround() )
		{
			WAIT_SERVER_FRAME;
		}
	}
}

function processSpecialistChallenge( statName )
{
	if ( self.pers["canSetSpecialistStat"] )
	{
		self AddSpecialistStat( statName, 1 );
	}
}


function flakjacketProtectedMP( weapon, attacker )
{
	if ( weapon.name == "claymore" )
	{
		self.flakJacketClaymore[ attacker.clientid ] = true;
	}

	self AddPlayerStat( "survive_with_flak", 1 );
	self.challenge_lastsurvivewithflakfrom = attacker;
	self.challenge_lastsurvivewithflaktime = getTime();
}

