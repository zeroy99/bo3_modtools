#using scripts\shared\gameobjects_shared;
#using scripts\shared\math_shared;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\mp\_pickup_items;
#using scripts\mp\gametypes\_globallogic;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_score;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;
#using scripts\mp\_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\gametypes\fr.gsh;

/*
	Freerun
	Objective: 	Make it to the goal the fastest
	Map ends:	When player quits
	Respawning:	Instant

	Level requirements
	------------------
		Spawnpoints:
			classname		mp_dm_spawn
			All players spawn from these. The spawnpoint chosen is dependent on the current locations of enemies at the time of spawn.
			Players generally spawn away from enemies.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.
*/

/*QUAKED mp_dm_spawn (1.0 0.5 0.0) (-16 -16 0) (16 16 72)
Players spawn away from enemies at one of these positions.*/

/*
	- down is reset to active checkpoint 
	- left/right change courses
	- up is to reset to start of course/reset timer
*/

#define FR_DEATH_PENALTY_SECONDS 5.0
#define FR_NUM_TRACKS 1
#define FR_SPAWN_Z_OFFSET 5.0

#define TUTORIAL_TEXT_HINT_TIME 4.0

#define HIGH_SCORE_COUNT 3

#precache( "string", "OBJECTIVES_FR" );
#precache( "string", "OBJECTIVES_FR_SCORE" );
#precache( "string", "OBJECTIVES_FR_HINT" );
#precache( "string", "OBJECTIVES_FR_NEW_RECORD" );
#precache( "string", "OBJECTIVES_FR_CHECKPOINT" );
#precache( "string", "OBJECTIVES_FR_FAULT" );
#precache( "string", "OBJECTIVES_FR_FAULTS" );
#precache( "string", "OBJECTIVES_FR_RETRY" );
#precache( "string", "OBJECTIVES_FR_RETRIES" );

#precache( "string", "FREERUN_TUTORIAL_01" );
#precache( "string", "FREERUN_TUTORIAL_02" );
#precache( "string", "FREERUN_TUTORIAL_03" );
#precache( "string", "FREERUN_TUTORIAL_04" );
#precache( "string", "FREERUN_TUTORIAL_05" );
#precache( "string", "FREERUN_TUTORIAL_06" );
#precache( "string", "FREERUN_TUTORIAL_07" );
#precache( "string", "FREERUN_TUTORIAL_08" );
#precache( "string", "FREERUN_TUTORIAL_09" );
#precache( "string", "FREERUN_TUTORIAL_10" );
#precache( "string", "FREERUN_TUTORIAL_11" );
#precache( "string", "FREERUN_TUTORIAL_12" );
#precache( "string", "FREERUN_TUTORIAL_13" );
#precache( "string", "FREERUN_TUTORIAL_14" );
#precache( "string", "FREERUN_TUTORIAL_14a" );
#precache( "string", "FREERUN_TUTORIAL_15" );
#precache( "string", "FREERUN_TUTORIAL_16" );
#precache( "string", "FREERUN_TUTORIAL_17" );
#precache( "string", "FREERUN_TUTORIAL_18" );
#precache( "string", "FREERUN_TUTORIAL_19" );
#precache( "string", "FREERUN_TUTORIAL_20" );
#precache( "string", "FREERUN_TUTORIAL_21" );
#precache( "string", "FREERUN_TUTORIAL_22" );
#precache( "string", "FREERUN_TUTORIAL_22a" );
#precache( "string", "FREERUN_TUTORIAL_23" );
#precache( "string", "FREERUN_TUTORIAL_24" );
#precache( "string", "FREERUN_TUTORIAL_25" );
#precache( "string", "FREERUN_TUTORIAL_26" );
#precache( "string", "FREERUN_WELCOME" );
#precache( "string", "FREERUN_CHECKPOINT" );
#precache( "string", "FREERUN_BEST_TIME" );
#precache( "string", "FREERUN_COMPLETE" );
#precache( "string", "FREERUN_BEST_RUN" );

#precache( "fx", "ui/fx_fr_target_demat" );
#precache( "fx", "ui/fx_fr_target_impact" );

#precache( "menu", MENU_FREERUN_RESTART );

function main()
{
	level.trackWeaponStats = false;
	globallogic::init();
	
	clientfield::register( "world", "freerun_state", VERSION_SHIP, 3, "int" );
	clientfield::register( "world", "freerun_retries", VERSION_SHIP, FR_RETRIES_BITS, "int" );
	clientfield::register( "world", "freerun_faults", VERSION_SHIP, FR_FAULTS_BITS, "int" );
	clientfield::register( "world", "freerun_startTime", VERSION_SHIP, FR_TIME_BITS, "int" );
	clientfield::register( "world", "freerun_finishTime", VERSION_SHIP, FR_TIME_BITS, "int" );
	clientfield::register( "world", "freerun_bestTime", VERSION_SHIP, FR_TIME_BITS, "int" );
	clientfield::register( "world", "freerun_timeAdjustment", VERSION_SHIP, FR_TIME_BITS, "int" );
	clientfield::register( "world", "freerun_timeAdjustmentNegative", VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "freerun_bulletPenalty", VERSION_SHIP, FR_BULLETPENALTY_BITS, "int" );
	clientfield::register( "world", "freerun_pausedTime", VERSION_SHIP, FR_TIME_BITS, "int" );
	clientfield::register( "world", "freerun_checkpointIndex", VERSION_SHIP, 7, "int" );
	
	util::registerTimeLimit( 0, 1440 );
	util::registerScoreLimit( 0, 50000 );
	util::registerRoundLimit( 0, 10 );
	util::registerRoundWinLimit( 0, 10 );
	util::registerNumLives( 0, 100 );
	
	globallogic::registerFriendlyFireDelay( level.gameType, 0, 0, 1440 );
	
	level.scoreRoundWinBased = ( GetGametypeSetting( "cumulativeRoundScores" ) == false );
	level.teamScorePerKill = GetGametypeSetting( "teamScorePerKill" );
	level.teamScorePerDeath = GetGametypeSetting( "teamScorePerDeath" );
	level.teamScorePerHeadshot = GetGametypeSetting( "teamScorePerHeadshot" );
	level.onStartGameType =&onStartGameType;
	level.onSpawnPlayer =&onSpawnPlayer;
	level.giveCustomLoadout = &giveCustomLoadout;

	//level.skipGameEnd = 1;
	level.postRoundTime = 0.5;
	level.doEndgameScoreboard = false;
	
	callback::on_connect( &on_player_connect );

	gameobjects::register_allowed_gameobject( "dm" );
	gameobjects::register_allowed_gameobject( level.gameType );

	if ( !IsDefined( level.fr_target_impact_fx ) )	
	{
		level.fr_target_impact_fx = "ui/fx_fr_target_impact";
	}
	if ( !IsDefined( level.fr_target_disable_fx ) )	
	{
		level.fr_target_disable_fx = "ui/fx_fr_target_demat";
	}
	if ( !IsDefined( level.fr_target_disable_sound ) )	
	{
		level.fr_target_disable_sound = "wpn_grenade_explode_default";
	}

	level.FRGame = SpawnStruct();

	level.FRGame.activeTrackIndex = 0;
	level.FRGame.tracks = [];
	
	for ( i = 0; i < FR_NUM_TRACKS; i++ )
	{
		level.FRGame.tracks[i] = SpawnStruct();

		level.FRGame.tracks[i].startTrigger = GetEnt( "fr_start_0" + i, "targetname" );
		assert( IsDefined( level.FRGame.tracks[i].startTrigger ));

		level.FRGame.tracks[i].goalTrigger = GetEnt( "fr_end_0" + i, "targetname" );
		assert( IsDefined( level.FRGame.tracks[i].goalTrigger ));

		level.FRGame.tracks[i].highScores = [];
	}

	level.FRGame.checkpointTriggers = GetEntArray( "fr_checkpoint", "targetname" );
	assert( level.FRGame.checkpointTriggers.size );

	// Sets the scoreboard columns and determines with data is sent across the network
	globallogic::setvisiblescoreboardcolumns( "pointstowin", "kills", "deaths", "headshots", "score" ); 

}

function setupTeam( team )
{
	util::setObjectiveText( team, &"OBJECTIVES_FR" );

	if ( level.splitscreen )
	{
		util::setObjectiveScoreText( team, &"OBJECTIVES_FR" );
	}
	else
	{
		util::setObjectiveScoreText( team, &"OBJECTIVES_FR_SCORE" );
	}
	util::setObjectiveHintText( team, &"OBJECTIVES_FR_SCORE" );

	spawnlogic::add_spawn_points( team, "mp_dm_spawn" );
}

function onStartGameType()
{
	setClientNameMode("auto_change");

	level.useXCamsForEndGame = false;
	level.can_set_aar_stat = false;
	level.disableBehaviorTracker = true;
	level.disableStatTracking = true;
	
	// now that the game objects have been deleted place the influencers
	spawning::create_map_placed_influencers();
	
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );

	foreach( team in level.teams )
	{
		setupTeam( team );
	}

	spawns = spawnlogic::get_spawnpoint_array( "mp_dm_spawn" );
	spawning::updateAllSpawnPoints();
	
	foreach( index, trigger in level.FRGame.checkpointTriggers )
	{
		level.FRGame.checkpointTimes[index] = 0;
		trigger.checkPointIndex = index;
		
		trigger thread watchCheckpointTrigger();

		closest = 99999999;
		foreach( spawn in spawns )
		{
			dist = DistanceSquared( spawn.origin, trigger.origin );
			if ( dist < closest )
			{
				closest = dist;
				trigger.spawnPoint = spawn;
			}
		}

		assert( IsDefined( trigger.spawnPoint ));
	}

	player_starts = spawnlogic::_get_spawnpoint_array( "info_player_start" );
	assert( player_starts.size );

	foreach( track in level.FRGame.tracks )
	{
		closest = 99999999;
		foreach( start in player_starts )
		{
			dist = DistanceSquared( start.origin, track.startTrigger.origin );
			if ( dist < closest )
			{
				closest = dist;
				track.playerStart = start;
			}
		}

		assert( IsDefined( track.playerStart ));
	}

	level.FRGame.deathTriggers = GetEntArray( "fr_die", "targetname" );
	assert( level.FRGame.deathTriggers.size );

	foreach( trigger in level.FRGame.deathTriggers )
	{
		trigger thread watchDeathTrigger();
	}

	setup_tutorial();
	
	if(!IsDefined (level.freerun)) // this keeps suspense music from the global mp system from playing
	{
		level.freerun = true;	
	}
	
	level.mapCenter = math::find_box_center( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );

	spawnpoint = spawnlogic::get_random_intermission_point();
	setDemoIntermissionPoint( spawnpoint.origin, spawnpoint.angles );
	
	// use the new spawn logic from the start
	level.useStartSpawns = false;
	level.displayRoundEndText = false;
	
	if ( !util::isOneRound() )
	{
		level.displayRoundEndText = true;
	}	
	
	foreach( item in level.pickup_items )
	{
		closest = 99999999;
		foreach( trigger in level.FRGame.checkpointTriggers )
		{
			dist = DistanceSquared( item.origin, trigger.origin );
			if ( dist < closest )
			{
				closest = dist;
				item.checkPoint = trigger;
			}
		}
		assert( IsDefined( item.checkPoint ));
		
		item.checkPoint.weapon = item.visuals[0].items[0].weapon;
		item.checkPoint.weaponObject = item;
		
		item.checkPoint setup_weapon_targets();
	}
	
	thread watch_for_game_end();
	
	level.FRGame.trackIndex = GetFreerunTrackIndex( );
	level.FRGame.mapUniqueId = GetMissionUniqueID( );
	level.FRGame.mapVersion = GetMissionVersion( );
}

function watch_for_game_end()
{
	level waittill("game_ended");

	if ( !end_game_state() )
	{
		level clientfield::set( "freerun_finishTime", 0 );
	}
	self stop_tutorial_vo();
	level clientfield::set( "freerun_state", FR_STATE_QUIT );
}

function on_player_connect()
{	
	self thread on_menu_response();
}

function on_menu_response()
{
	self endon("disconnect");
	
	for(;;)
	{
		self waittill("menuresponse", menu, response);
		if ( response == "fr_restart" )
		{
			self playsoundtoplayer( "uin_freerun_reset", self );
			self thread freerunMusic();
			activateTrack( level.FRGame.activeTrackIndex );
		}
	}
}

function onSpawnPlayer(predictedSpawn) // self == player
{
	spawning::onSpawnPlayer(predictedSpawn);
	
	if ( predictedSpawn )
		return;
	
	// if we are here a second time its because the player died.
	if ( IsDefined( self.FRInited ) )
	{
		self.body hide();
		faultDeath();
		return;
	}
	
	self.FRInited = true;
	
	self thread activate_tutorial_mode();
	self thread activateTrack( level.FRGame.activeTrackIndex );
	self thread watchTrackSwitch();
	self thread watchWeaponFire();
	self thread freerunMusic();
	
	self thread trackPlayerOrigin();
	
//	self.overridePlayerDamage = &on_player_damage;
	
	level.FRGame.lastPlayedFaultVOTime = 0;
	
	self DisableWeaponCycling();
}

function on_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	if ( iDamage >= self.health )
	{
		// damage function always applies at least 1 damage
		self.health = self.maxHealth + 1;
		faultDeath();
		return 0;
	}
	
	return iDamage;
}

function trackPlayerOrigin()
{
	self endon( "disconnect" );
	
	while( 1 )
	{
		self.prev_origin = self.origin;
		self.prev_time = GetTime();
		WAIT_SERVER_FRAME;
		waittillframeend;
	}
}

function readHighScores() // self == player
{
	get_top_scores_stats();

	updateHighScores();
}

function updateHighScores()
{
	self FreerunSetHighScores( level.FRGame.activeTrack.highScores[0].time, level.FRGame.activeTrack.highScores[1].time, level.FRGame.activeTrack.highScores[2].time );
	level clientfield::set( "freerun_bestTime", level.FRGame.activeTrack.highScores[0].time );
}

function activateTrack( trackIndex ) // self == player
{
	level notify( "activate_track" );

/#
		if ( level.FRGame.tracks.size > 1 )
	{
		IPrintLn( "Track " + trackIndex );	
	}
#/
		
	if ( !isdefined( level.FRGame.tutorials ) || !level.FRGame.tutorials )
	{
		// we are not doing tutorial mode so then play the main freerun vo
		self playlocalsound( "vox_tuto_tutorial_sequence_27" );
	}

	level.FRGame.lastPlayedFaultVOCheckpoint = -1;

	level.FRGame.activeTrackIndex = trackIndex;
	level.FRGame.activeTrack = level.FRGame.tracks[trackIndex];
	level.FRGame.activeSpawnPoint = level.FRGame.activeTrack.playerStart;
	level.FRGame.activeSpawnLocation = level.FRGame.activeTrack.playerStart.origin;
	level.FRGame.activeSpawnAngles = level.FRGame.activeTrack.playerStart.angles;
	level.FRGame.activeTrack.goalTrigger thread watchGoalTrigger();
	level.FRGame.activeSpawnPoint.checkpointIndex = 0;
	
	level.FRGame.faults = 0;
	level.FRGame.userSpawns = 0;
	level.FRGame.checkpointTimes = [];
	foreach( index, trigger in level.FRGame.checkpointTriggers )
	{
		level.FRGame.checkpointTimes[index] = 0;
	}
	
	level clientfield::set( "freerun_faults", 0 );
	level clientfield::set( "freerun_retries", 0 );
	level clientfield::set( "freerun_state", FR_STATE_PRESTART );
	level clientfield::set( "freerun_bulletPenalty", 0 );
	level clientfield::set( "freerun_pausedTime",  0 );
	level clientfield::set( "freerun_checkpointIndex", 0 );
	
	self readHighScores();

	self giveCustomLoadout();
	self SetOrigin( level.FRGame.activeTrack.playerStart.origin );
	self SetPlayerAngles( level.FRGame.activeTrack.playerStart.angles );
	self SetVelocity( (0,0,0) );
	self RecordGameEvent( "start" );
	
	ResetGlass();
	reset_all_targets();
	pickup_items::respawn_all_pickups();
	
	self unfreeze();
	self.respawn_position = undefined;
	
	enable_all_tutorial_triggers();
	take_players_out_of_tutorial_mode();
	
	level.FRGame.activeTrack.startTrigger thread watchStartRun( self );
}

function startRun() // self == player
{
	level.FRGame.totalPausedTime = 0;
	level.FRGame.pausedAtTime = 0;
	level.FRGame.bulletPenalty = 0;
	level.FRGame.hasBeenPaused = false;
	level.FRGame.trackStartTime = 0;
	level.FRGame.trackStartTime = get_current_track_time( self );

	level clientfield::set( "freerun_startTime",  level.FRGame.trackStartTime );
	level clientfield::set( "freerun_state", FR_STATE_RUNNING );
	
	self playsoundtoplayer( "uin_freerun_start", self );

	self thread watchUserRespawn();
}

function onCheckpointTrigger( player, endOnString ) // self == trigger
{
	self endon( endOnString );

	level.FRGame.activeSpawnLocation = getGroundPointForOrigin( player.origin );
	level.FRGame.activeSpawnAngles = player.angles;
	
	if ( level.FRGame.activeSpawnPoint != self )
	{
		level.FRGame.activeSpawnPoint = self;

		player take_all_player_weapons( false, false );	
		
		if ( IsDefined(self.weaponObject) )
		{
			self.weaponObject reset_targets();
			self.weaponObject pickup_items::respawn_pickup();
		}
	}
}

function leaveCheckpointTrigger( player ) // self == trigger
{
	self thread watchCheckpointTrigger();
}

function get_current_track_time( player ) // self == checkpoint trigger 
{
	curtime = GetTime();
	dt = curtime - player.prev_time;

	frac = getfirsttouchfraction( player, self, player.prev_origin, player.origin );

	current_time = (curtime - level.FRGame.trackStartTime + (level.FRGame.bulletPenalty * 1000) + (level.FRGame.userSpawns * 5000) - level.FRGame.totalPausedTime);
	
	return int(current_time - dt * ( 1 - frac ));	
}

function watchCheckpointTrigger() // self == checkpoint trigger 
{
	self waittill( "trigger", player );

	if ( IsPlayer( player ))
	{
		if ( level.FRGame.activeSpawnPoint != self )
		{
			checkpoint_index = self.checkpointIndex;
			
			current_time = get_current_track_time( player );
			
			first_time = false;
			
			// make sure we dont double set this if they go backwards
			if ( !IsDefined( level.FRGame.checkpointTimes[ checkpoint_index ] ) || level.FRGame.checkpointTimes[ checkpoint_index ] == 0 )
			{
				level.FRGame.checkpointTimes[ checkpoint_index ] = current_time;
				first_time = true;
			}

			if ( first_time )
			{
				if ( IsDefined( level.FRGame.activeTrack.fastestRunCheckpointTimes ) )
				{
					if ( IsDefined( level.FRGame.activeTrack.fastestRunCheckpointTimes[checkpoint_index] ) && level.FRGame.activeTrack.fastestRunCheckpointTimes[checkpoint_index] )
					{
						delta_time = current_time - level.FRGame.activeTrack.fastestRunCheckpointTimes[checkpoint_index];
						
						if ( delta_time < 0 )
						{
							delta_time = -delta_time;
							sign = 1;
						}
						else
						{
							sign = 0;
						}
						
						level clientfield::set( "freerun_timeAdjustment", delta_time );
						level clientfield::set( "freerun_timeAdjustmentNegative", sign );
					}
					
					
				}

				//Set the checkpoint index to one above the actual checkpoint index in order to update on the first checkpoint ( 0 ), as
				//Clientfields can't handle negative numbers.
				level clientfield::set( "freerun_checkpointIndex", checkpoint_index + 1 );
				player playsoundtoplayer( "uin_freerun_checkpoint", player );
			}
		}
		self thread util::trigger_thread( player, &onCheckpointTrigger, &leaveCheckpointTrigger );
	}
}

function watchDeathTrigger() // self == death trigger 
{
	while( true )
	{
		self waittill( "trigger", player );

		if ( IsPlayer( player ))
		{
			player faultDeath();
		}
	}
}

function add_current_run_to_high_scores(player)
{
		active_track = level.FRGame.activeTrack;
		
		run_data = create_high_score_struct( get_current_track_time( player ), level.FRGame.faults, level.FRGame.userSpawns, level.FRGame.bulletPenalty );
	
		push_score = true;
		new_record = false;

		if ( active_track.highScores.size > 0 )
		{
			for ( i = 0; i < active_track.highScores.size; i++ )
			{
				if ( (run_data.time < active_track.highScores[i].time) || (active_track.highScores[i].time == 0) )
				{
					push_score = false;

					ArrayInsert( active_track.highScores, run_data, i );

					if ( i == 0 )
					{
						new_record = true;
					}

					if ( i < HIGH_SCORE_COUNT )
					{
						player write_high_scores_stats(i);
					}
					break;
				}
			}
		}
		else
		{
			new_record = true;
		}

		if ( push_score )
		{
			ArrayInsert( active_track.highScores, run_data, active_track.highScores.size );
			player write_high_scores_stats( active_track.highScores.size - 1 );
		}
		
		if ( new_record )
		{
			player write_checkpoint_times();
		}
		
		return new_record;
}

function watchGoalTrigger() // self == goal trigger
{
	level notify( "watch_goal_trigger" );
	level endon( "watch_goal_trigger" );	

	self waittill( "trigger", player );

	if ( IsPlayer( player ))
	{
		player playsoundtoplayer( "uin_freerun_finish", player );
		
		player take_all_player_weapons( true, false );	

		new_record = add_current_run_to_high_scores(player);
		
		tracksCompleted = player getDStat( "freerunTracksCompleted" );
		
		if ( tracksCompleted < level.FRGame.trackIndex )
		{
			player setDStat( "freerunTracksCompleted", level.FRGame.trackIndex );
		}

		player RecordGameEvent( "completion" );
		
		player.respawn_position = self.origin;
		player thread freeze();
		player thread freerunMusic(false);
		player updateHighScores();
		level clientfield::set( "freerun_finishTime", get_current_track_time( player ) );
		level clientfield::set( "freerun_state", FR_STATE_FINISHED );
		level notify( "finished_track" );
		
		// this profile setting will not work if someone can play on a remote server
		if ( player IsHost() )
		{
			level notify("stop_tutorials");
			take_players_out_of_tutorial_mode();	
			level.FRGame.tutorials = false;
			SetLocalProfileVar( "com_firsttime_freerun", 1 );
	
			highest_track = GetLocalProfileInt( "freerunHighestTrack" );
			
			if ( highest_track <  level.FRGame.trackIndex )
			{
				SetLocalProfileVar( "freerunHighestTrack",  level.FRGame.trackIndex );
			}
		}
		

		wait(1.5);		

		UploadStats();
		player uploadleaderboards();
		
		level clientfield::set( "freerun_state", FR_STATE_DIALOG );
	}
}

function freeze()
{
	self util::freeze_player_controls( true );
}

function unfreeze()
{
		self util::freeze_player_controls( false );
}

function setup_weapon_targets() // self == checkpoint
{
	target_name = self.weaponObject.visuals[0].target;
	if ( !IsDefined(target_name) )
		return;
	
	self.weaponObject.targetShotTime = 0;
	self.weaponObject.targets = [];
	self.weaponObject.target_visuals = [];
	
	targets = GetEntArray( target_name, "targetname" );
	foreach( target in targets )
	{
		if ( target.script_noteworthy == "fr_target" )
		{
			self.weaponObject.targets[self.weaponObject.targets.size] = target;
		}
		if ( target.script_noteworthy == "fr_target_visual" )
		{
			self.weaponObject.target_visuals[self.weaponObject.target_visuals.size] = target;
		}
	}
	
	foreach ( target in self.weaponObject.targets )
	{
		foreach( visual in self.weaponObject.target_visuals )
		{
			if ( target.origin == visual.origin )
			{
				target.visual = visual;
			}
		}
	}
	
	foreach ( target in self.weaponObject.targets )
	{
		target.blocker = GetEnt( target.target, "targetname" );
		if ( IsDefined( target.blocker ) )
		{
			if ( !isdefined( target.blocker.targetCount ) )
			{
				target.blocker.targetCount = 0;
				target.blocker.activeTargetCount = 0;
			}
			
			target.blocker.targetCount++;
			target.blocker.activeTargetCount++;
			
			target.checkPoint = self;
			target.disabled = false;
			target thread watch_target_trigger_thread(self.weaponObject);
		}
	}
}

function watch_target_trigger_thread( weaponObject )
{
	self endon( "death" );		
	
	while(1)
	{
		self waittill ( "damage", damage, attacker, direction_vec, point, type, modelName, tagName, partName, weapon, iDFlags );		
	
		if ( level.FRGame.activeSpawnPoint != self.checkPoint )
			continue;
		
		if ( weapon == level.weaponBaseMeleeHeld )
			continue;
		
		if ( self.disabled )
			continue;
		
		self turn_off_target(weapon);
				
		PlayFx( level.fr_target_impact_fx, point, direction_vec );
		weaponObject.targetShotTime = GetTime();
	}
}

function turn_off_target(weapon)
{
	self.disabled = true;
	self.visual ghost();  // this will still stop bullet collision with ghost
	self.visual notsolid();
	
	self.blocker blocker_disable();
		
	Playfx( level.fr_target_disable_fx, self.origin );
	PlaySoundAtPosition( level.fr_target_disable_sound, self.origin );
}

function blocker_enable()
{
	self.activeTargetCount = self.targetCount;
	
	self.disabled = false;
	self show();
	self solid();
}

function blocker_disable()
{
	self.activeTargetCount--;

	if ( self.activeTargetCount == 0 )
	{
		self.disabled = true;
		self ghost();
		self notsolid();
	}
}

function reset_targets()
{
	foreach ( target in self.targets )
	{
		target.blocker blocker_enable();
		target.visual show();
		target.visual solid();
		target.disabled = false;
	}
}

function reset_all_targets()
{
	foreach( trigger in level.FRGame.checkpointTriggers )
	{
		if ( IsDefined( trigger.weaponObject ) )
		{
			trigger.weaponObject reset_targets();
		}
	}
}

function play_fault_VO()
{
	current_time = GetTime();
	fault_vo_interval = 20000;
	
	if ( current_time - level.FRGame.lastPlayedFaultVOTime < fault_vo_interval )
		return;
	
	if ( isdefined( self.lastTutorialVOPlayed ) )
		return;
	
	if ( level.FRGame.lastPlayedFaultVOCheckpoint == level.FRGame.activeSpawnPoint.checkpointIndex )
		return;
	
	level.FRGame.lastPlayedFaultVOCheckpoint = level.FRGame.activeSpawnPoint.checkpointIndex;
	level.FRGame.lastPlayedFaultVOTime = current_time;
	self playlocalsound( "vox_tuto_tutorial_fail" );
}

function faultDeath() // self == player
{
	self play_fault_VO();
	
	// do the fall deaths increase time in trials?
	level.FRGame.faults++;
	self RecordGameEvent( "fault" );
	level clientfield::set( "freerun_faults", level.FRGame.faults );
	self playsoundtoplayer( "uin_freerun_reset", self );
	self respawnAtActiveCheckpoint();
}

function dpad_up_pressed()
{
	return self ActionSlotOneButtonPressed();
}

function dpad_down_pressed()
{
	return self ActionSlotTwoButtonPressed();
}

function dpad_right_pressed()
{
	return self ActionSlotFourButtonPressed();
}

function dpad_left_pressed()
{
	return self ActionSlotThreeButtonPressed();
}

function end_game_state()
{
	state = level clientfield::get( "freerun_state" );
	if ( state == FR_STATE_FINISHED || state == FR_STATE_QUIT || state == FR_STATE_DIALOG )
	{
		return true;
	}
	
	return false;
}

function watchTrackSwitch() // self == player
{
	track_count = level.FRGame.tracks.size;
	
	while( true )
	{
		wait .05;

		switch_track = false;

		if ( end_game_state() )
		{
			continue;
		}
		
		if ( !switch_track && self dpad_up_pressed())
		{
			switch_track = true;
			curr_track_index = level.FRGame.activeTrackIndex;
			self thread freerunMusic();
		}

		if ( switch_track )
		{
			if ( curr_track_index == FR_NUM_TRACKS )
			{
				curr_track_index = 0;
			}
			else if ( curr_track_index < 0 )
			{
				curr_track_index = FR_NUM_TRACKS - 1;
			}

			self playsoundtoplayer( "uin_freerun_reset", self );
			activateTrack( curr_track_index );

			while ( true )
			{
				wait .05;

				if (!( self dpad_right_pressed() || self dpad_left_pressed() || self dpad_up_pressed() ))
				{
					break;
				}
			}
		}
	}
}

function watchUserRespawn() // self == player
{
	level endon( "activate_track" );
	level endon( "finished_track" );

	while( true )
	{
		wait .05;

		if ( end_game_state() )
		{
			continue;
		}

		if ( self dpad_down_pressed() )
		{
			level.FRGame.userSpawns++;
			self RecordGameEvent( "retry" );
			level clientfield::set( "freerun_retries", level.FRGame.userSpawns );
			self playsoundtoplayer( "uin_freerun_reset", self );
			self respawnAtActiveCheckpoint();
			
			while ( true )
			{
				wait .05;

				if (!( self dpad_down_pressed() ))
				{
					break;
				}
			}
		}
	}
}

function ignoreBulletsFired(weapon)
{
	if ( !IsDefined(level.FRGame.activespawnpoint) )
		return false;

	if ( !IsDefined(level.FRGame.activespawnpoint.weaponobject) )
		return false;
	
	grace_period = (weapon.fireTime * 4) * 1000;
	
	if ( (level.FRGame.activespawnpoint.weaponobject.targetShotTime + grace_period) >= GetTime() )
		return true;
	
	foreach( target in level.FRGame.activespawnpoint.weaponobject.targets )
	{
		if ( !target.disabled ) 
		{
			return false;
		}
	}
	
	return true;
}

function watchWeaponFire() // self == player
{
	self endon("disconnect");
	
	while(1)
	{
		self waittill( "weapon_fired", weapon ); 
		
		if ( weapon == level.weaponBaseMeleeHeld )
			continue;
		
		if ( ignoreBulletsFired(weapon) )
			continue;
		
		level.FRGame.bulletPenalty++;
		level clientfield::set( "freerun_bulletPenalty", level.FRGame.bulletPenalty );
	}
}

function getGroundPointForOrigin( position )
{
	trace = BulletTrace( position + (0,0,10), position - (0,0,1000), false, undefined );
	return trace["position"];
}

function watchStartRun( player ) // self == start trigger
{
	level endon( "activate_track" );

	self waittill( "trigger", trigger_ent );

	if ( trigger_ent == player )
	{
		player startRun();
	}
}

function respawnAtActiveCheckpoint() // self == player
{
	ResetGlass();
	reset_all_targets();
	pickup_items::respawn_all_pickups();
	take_players_out_of_tutorial_mode();
	
	self playsoundtoplayer( "evt_freerun_respawn", self );

	if ( IsDefined( self.respawn_position ) )
	{
		self SetOrigin( self.respawn_position );
		self SetVelocity( (0,0,0) );
	}
	else if ( IsDefined( level.FRGame.activeSpawnPoint.spawnPoint ))
	{
		self SetOrigin( level.FRGame.activeSpawnPoint.spawnPoint.origin );
		self SetPlayerAngles( level.FRGame.activeSpawnPoint.spawnPoint.angles );
		self SetVelocity( (0,0,0) );
	}
	else
	{
		// no spawn point for the track start triggers
		spawn_origin = level.FRGame.activeSpawnLocation;
		spawn_origin += ( 0,0, FR_SPAWN_Z_OFFSET );	

		self SetOrigin( spawn_origin );
		self SetPlayerAngles( level.FRGame.activeSpawnAngles );
		self SetVelocity( (0,0,0) );
	}

	self setdoublejumpenergy( 1.0 );
	self take_all_player_weapons( true, true );
}

function giveCustomLoadout()
{
	self TakeAllWeapons();
	self clearPerks();
	
	self SetPerk( "specialty_fallheight" );

	self GiveWeapon( level.weaponBaseMeleeHeld );
	self setSpawnWeapon( level.weaponBaseMeleeHeld );
	
	return level.weaponBaseMeleeHeld;
}

function set_high_score_stat( trackIndex, slot, stat, value )
{
	self setDStat( "freerunTrackTimes", "track", trackIndex, "topTimes", slot, stat, value );
}

function write_high_scores_stats(start_index)
{
	active_track = level.FRGame.activeTrack;
	
	self setDStat( "freerunTrackTimes", "track", level.FRGame.trackIndex, "mapUniqueId", level.FRGame.mapUniqueId );
	self setDStat( "freerunTrackTimes", "track", level.FRGame.trackIndex, "mapVersion", level.FRGame.mapVersion );

	for ( slot = start_index; slot < HIGH_SCORE_COUNT; slot++ )
	{
		set_high_score_stat( level.FRGame.trackIndex, slot, "time", active_track.highScores[slot].time );
		set_high_score_stat( level.FRGame.trackIndex, slot, "faults", active_track.highScores[slot].faults );
		set_high_score_stat( level.FRGame.trackIndex, slot, "retries", active_track.highScores[slot].retries );
		set_high_score_stat( level.FRGame.trackIndex, slot, "bulletPenalty", active_track.highScores[slot].bulletPenalty );
	}
}

function write_checkpoint_times()
{
	level.FRGame.activeTrack.fastestRunCheckpointTimes = level.FRGame.checkpointTimes;
	
	for ( i = 0; i < level.FRGame.checkpointTriggers.size; i++ )
	{
		self setDStat( "freerunTrackTimes", "track", level.FRGame.trackIndex, "checkPointTimes", "time", i, level.FRGame.checkpointTimes[i] );
	}
}

function get_high_score_stat( trackIndex, slot, stat )
{
	return (self getDStat( "freerunTrackTimes", "track", trackIndex, "topTimes", slot, stat ));
}

function create_high_score_struct( time, faults, retries, bulletPenalty ) // self == player
{
	score_set = SpawnStruct();

	score_set.time = time;
	score_set.faults = faults;
	score_set.retries = retries;
	score_set.bulletPenalty = bulletPenalty;

	return score_set; 
}

function get_stats_for_track( trackIndex, slot ) // self == player
{
	time = self get_high_score_stat( trackIndex, slot, "time" );
	faults = self get_high_score_stat( trackIndex, slot, "faults" );
	retries = self get_high_score_stat( trackIndex, slot, "retries" );
	bulletPenalty = self get_high_score_stat( trackIndex, slot, "bulletPenalty" );

	return create_high_score_struct( time, faults, retries, bulletPenalty); 
}

function get_checkpoint_times_for_track( trackIndex ) // self == player
{
	for ( i = 0; i < level.FRGame.checkpointTriggers.size; i++ )
	{
		level.FRGame.activeTrack.fastestRunCheckpointTimes[i] = self getDStat( "freerunTrackTimes", "track", trackIndex, "checkPointTimes", "time", i );
	}
}

function get_top_scores_stats()
{
	if ( isdefined(level.FRGame.activeTrack.statsRead) )
		return;
	
	mapId = self getDStat( "freerunTrackTimes", "track", level.FRGame.trackIndex, "mapUniqueId" );
	mapVersion = self getDStat( "freerunTrackTimes", "track", level.FRGame.trackIndex, "mapVersion" );
	
	if ( level.FRGame.mapUniqueId != mapId || level.FRGame.mapVersion != mapVersion )
	{
		for( i = 0; i < HIGH_SCORE_COUNT; i++ )
		{
			level.FRGame.activeTrack.highScores[i] = create_high_score_struct( 0,0,0,0 );		
		}
		for ( i = 0; i < level.FRGame.checkpointTriggers.size; i++ )
		{
			level.FRGame.activeTrack.fastestRunCheckpointTimes[i] = 0;
		}
	}
	else
	{
		for( i = 0; i < HIGH_SCORE_COUNT; i++ )
		{
			level.FRGame.activeTrack.highScores[i] = get_stats_for_track( level.FRGame.trackIndex, i );		
		}
		get_checkpoint_times_for_track(level.FRGame.trackIndex);
	}
	
	level.FRGame.activeTrack.statsRead = true;
}

function take_all_player_weapons( only_default, immediate ) // self == player
{
	self endon("disconnect");
	self endon("death");
	
	keep_weapon = level.weaponNone;
	if ( isDefined(level.FRGame.activeSpawnPoint.weapon) && !only_default )
	{
		keep_weapon = level.FRGame.activeSpawnPoint.weapon;
	}
	
	if ( immediate )
	{
		self switchtoweaponimmediate(level.weaponBaseMeleeHeld);
	}
	else
	{
		while ( self isswitchingweapons() )
		{
			wait(0.05);
		}
			
		current_weapon = self GetCurrentWeapon();
	
		if ( current_weapon != level.weaponBaseMeleeHeld && keep_weapon != current_weapon )
		{
			self SwitchToWeapon(level.weaponBaseMeleeHeld);
			while( self GetCurrentWeapon() != level.weaponBaseMeleeHeld )
			{
				wait(0.05);
			}
		}
	}
	
	weaponsList = self GetWeaponsList();
	foreach( weapon in weaponsList )
	{
		if ( weapon != level.weaponBaseMeleeHeld && keep_weapon != weapon )
			self TakeWeapon( weapon );
	}
}

function freerunMusic(start=true)
{
	player = self;
        
	if( start && !IS_TRUE(player.musicStart) )
        {
		mapname = GetDvarString( "mapname" );
    	player globallogic_audio::set_music_on_player( mapname );
    	player.musicStart = true;
	}
	else if( !start )
            {
		player globallogic_audio::set_music_on_player( "mp_freerun_finish" );
		player.musicStart = false;
    }
}

function _tutorial_mode( b_tutorial_mode )
{
}

function take_players_out_of_tutorial_mode()
{
	if ( level.FRGame.tutorials )
	{
		foreach( player in level.players )
		{
			player _tutorial_mode( false );
		}
	}
}

function put_players_in_tutorial_mode()
{
	if ( level.FRGame.tutorials )
	{
		foreach( player in level.players )
		{
			player _tutorial_mode( true );
		}
	}
}

function enable_all_tutorial_triggers()
{
	if ( level.FRGame.tutorials )
	{
		foreach( trigger in level.FRGame.tutorialTriggers )
		{
			trigger TriggerEnable( true );
		}
	}
}

function activate_tutorial_mode()
{
	// profile var will be 0 if never run before
	// this profile setting will not work if someone can play on a remote server
	if (  (!(self IsHost()) || GetLocalProfileInt( "com_firsttime_freerun" )) && !GetDvarInt( "freerun_tutorial" ) )
	{
		return;
	}
	
	level.FRGame.tutorials = true;

	wait(1);
	
	foreach( trigger in level.FRGame.tutorialTriggers )
	{
		trigger thread watchTutorialTrigger();
	}
	
}

function setup_tutorial()
{
	level.FRGame.tutorials = false;

	level.FRGame.tutorialTriggers = GetEntArray( "fr_tutorial", "targetname" );
		
	level.FRGame.tutorialFunctions = [];
	
	register_tutorials();
}

function watchTutorialTrigger()
{
	level endon("stop_tutorials");
	
	while( true )
	{
		self waittill( "trigger", player );

		if ( IsPlayer( player ))
		{
			player thread start_tutorial(self.script_noteworthy);
			self TriggerEnable( false );
		}
	}
}

function stop_tutorial_when_restarting_track()
{
	self notify("stop_tutorial_when_restarting_track");
	self waittill("stop_tutorial_when_restarting_track");
	
	level waittill( "activate_track" );
	
	take_players_out_of_tutorial_mode();	
	self util::hide_hint_text(false);

	self stop_tutorial_vo();
	self stopsounds();
}

function start_tutorial( tutorial )
{
	self endon("death");
	self endon("disconnect");
	level endon( "game_ended" );
	level endon( "activate_track" );
	if (!isdefined(level.FRGame.tutorialFunctions[tutorial]))
		return;

	level notify( "playing_tutorial" );
	level endon( "playing_tutorial" );

	self thread stop_tutorial_when_restarting_track();
	
	put_players_in_tutorial_mode();
	wait( 0.5 );
	[[level.FRGame.tutorialFunctions[tutorial]]]();
	take_players_out_of_tutorial_mode();	
}

function stop_tutorial_vo()
{
	if ( isdefined( self.lastTutorialVOPlayed ) )
	{
		self stopsound(self.lastTutorialVOPlayed);
		self.lastTutorialVOPlayed = undefined;
	}
}

function play_tutorial_vo( aliasstring )
{
	self stop_tutorial_vo();
	
	self.lastTutorialVOPlayed = aliasstring;
	self playsoundwithnotify( aliasstring, "sounddone" );
	self waittill( "sounddone");
	wait( 1.0 );
}

function play_tutorial_vo_with_hint( aliasstring, text )
{
	self stop_tutorial_vo();
	
	self thread _show_tutorial_hint_with_vo( text );
	
	self.lastTutorialVOPlayed = aliasstring;
	self playsoundwithnotify( aliasstring, "sounddone" );
	self waittill( "sounddone");
	wait( 1.0 );
}

function _show_tutorial_hint_with_vo( text, time, unlock_player )
{
	wait (0.5);
	show_tutorial_hint( text, time, unlock_player );
}

function show_tutorial_hint( text, time, unlock_player )
{
	if ( isdefined( unlock_player ) )
	{
		take_players_out_of_tutorial_mode();		
	}
	
	if (!isdefined(time) )
	{
		time = TUTORIAL_TEXT_HINT_TIME;
	}
	self util::show_hint_text( text, false, "activate_track", TUTORIAL_TEXT_HINT_TIME);
	wait( TUTORIAL_TEXT_HINT_TIME + 0.5);
}

function show_tutorial_hint_with_full_movement( text, time )
{
	show_tutorial_hint( text, time, true );
}

function register_tutorials()
{
	level.FRGame.tutorialFunctions["tutorial_01"] = &tutorial_01;
	level.FRGame.tutorialFunctions["tutorial_02"] = &tutorial_02;
	level.FRGame.tutorialFunctions["tutorial_03"] = &tutorial_03;
	level.FRGame.tutorialFunctions["tutorial_06"] = &tutorial_06;
	level.FRGame.tutorialFunctions["tutorial_08"] = &tutorial_08;
	level.FRGame.tutorialFunctions["tutorial_09"] = &tutorial_09;
	level.FRGame.tutorialFunctions["tutorial_10"] = &tutorial_10;
	level.FRGame.tutorialFunctions["tutorial_10a"] = &tutorial_10a;
	level.FRGame.tutorialFunctions["tutorial_12"] = &tutorial_12;
	level.FRGame.tutorialFunctions["tutorial_12a"] = &tutorial_12a;
	level.FRGame.tutorialFunctions["tutorial_13"] = &tutorial_13;
	level.FRGame.tutorialFunctions["tutorial_14"] = &tutorial_14;
	level.FRGame.tutorialFunctions["tutorial_15"] = &tutorial_15;
	level.FRGame.tutorialFunctions["tutorial_16"] = &tutorial_16;
	level.FRGame.tutorialFunctions["tutorial_17"] = &tutorial_17;
	level.FRGame.tutorialFunctions["tutorial_17a"] = &tutorial_17a;
	level.FRGame.tutorialFunctions["tutorial_18"] = &tutorial_18;
	level.FRGame.tutorialFunctions["tutorial_19"] = &tutorial_19;
	level.FRGame.tutorialFunctions["tutorial_20"] = &tutorial_20;
}

function tutorial_01()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_1" );
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_2" );
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_6" );
}

function tutorial_02()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_02" );
}

function tutorial_03()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_03" );
}

function tutorial_06()
{
	self thread play_tutorial_vo( "vox_tuto_tutorial_sequence_11" );
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_09" );
}

function tutorial_08()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_11" );
}

function tutorial_09()
{
	self play_tutorial_vo_with_hint( "vox_tuto_tutorial_sequence_28", &"FREERUN_TUTORIAL_12" );
}

function tutorial_10()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_10" );
}

function tutorial_10a()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_13" );
}

function tutorial_12()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_16" );
}

function tutorial_12a()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_14" );
}

function tutorial_13()
{
	self play_tutorial_vo_with_hint( "vox_tuto_tutorial_sequence_17", &"FREERUN_TUTORIAL_14a" );
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_18" );
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_16" );	
}

function tutorial_14()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_19" );
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_18" );
}

function tutorial_15()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_20" );
}

function tutorial_16()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_29" );
}

function tutorial_17()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_21" );
}

function tutorial_17a()
{
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_22" );
}


function tutorial_18()
{
	self play_tutorial_vo_with_hint( "vox_tuto_tutorial_sequence_23", &"FREERUN_TUTORIAL_23" );
	self show_tutorial_hint_with_full_movement( &"FREERUN_TUTORIAL_22a" );
}

function tutorial_19()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_25" );
}

function tutorial_20()
{
	self play_tutorial_vo( "vox_tuto_tutorial_sequence_26" );
}