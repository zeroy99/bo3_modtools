#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\music_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_audio.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_zonemgr;

#namespace zm_audio;

REGISTER_SYSTEM( "zm_audio", &__init__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "charindex", VERSION_SHIP, 3, "int" ); 
	clientfield::register( "toplayer", "isspeaking",VERSION_SHIP, 1, "int" ); 
	

	level.audio_get_mod_type = &get_mod_type;
	level zmbVox();
	callback::on_connect( &init_audio_functions );
	
	level thread sndAnnouncer_Init();
}

function SetExertVoice( exert_id )
{
	self.player_exert_id = exert_id; 
	self clientfield::set( "charindex", self.player_exert_id );
	
}

function playerExert( exert, notifywait = false )
{
	if(IS_TRUE(self.isSpeaking) || IS_TRUE(self.isexerting) )
	{
		return;
	}
	
	if( IS_TRUE( self.beastmode ) )
		return;
	
	id = level.exert_sounds[0][exert];
	if( isDefined(self.player_exert_id) )
	{
		if (!isdefined(level.exert_sounds) || !isdefined(level.exert_sounds[self.player_exert_id]) || !isdefined(level.exert_sounds[self.player_exert_id][exert]))
			return;
		if(IsArray(level.exert_sounds[self.player_exert_id][exert]))
		{
			id = array::random(level.exert_sounds[self.player_exert_id][exert]);
		}
		else
		{
			id = level.exert_sounds[self.player_exert_id][exert];
		}
	}
	
	if (isdefined(id))
	{
		self.isexerting = true;
		
		if (notifywait)
		{
			self playsoundwithnotify(id, "done_exerting" );
			self waittill( "done_exerting" );
			self.isexerting = false;
		}
		else
		{
			self thread exert_timer();
			self playsound (id);
		}
	}
}

function exert_timer()
{
	self endon("disconnect");
	//wait(1);	
	//self.isexerting = true;
	wait( randomfloatrange (1.5,3));
	self.isexerting = false;
	
}



//All Vox should be found in this section.
//If there is an Alias that needs to be changed, check here first.
function zmbVox()
{
	level.votimer = [];
	
	level.vox = zmbVoxCreate();

	//Init Level Specific Vox
	if( isdefined( level._zmbVoxLevelSpecific ) )
		level thread [[level._zmbVoxLevelSpecific]]();
	
	//Init Gametype Specific Vox
	if( isdefined( level._zmbVoxGametypeSpecific ) )
		level thread [[level._zmbVoxGametypeSpecific]]();
	
	announcer_ent = spawn( "script_origin", (0,0,0) );
	level.vox zmbVoxInitSpeaker( "announcer", "vox_zmba_", announcer_ent );

	// sniper hold breath
	level.exert_sounds[0]["burp"] = "evt_belch";

	// medium hit
	level.exert_sounds[0]["hitmed"] = "null";

	// large hit
	level.exert_sounds[0]["hitlrg"] = "null";

	// custom character exerts
	if (isdefined(level.setupCustomCharacterExerts))
		[[level.setupCustomCharacterExerts]]();
}

function init_audio_functions()
{
	self thread zombie_behind_vox();
	self thread player_killstreak_timer();
	
	if(isdefined(level._custom_zombie_oh_shit_vox_func))
	{
		self thread [[level._custom_zombie_oh_shit_vox_func]]();
	}
	else
	{
    	self thread oh_shit_vox();
	}
}

//Plays a specific Zombie vocal when they are close behind the player
//Self is the Player(s)
function zombie_behind_vox()
{
	level endon("unloaded");
	self endon("death_or_disconnect");
	
	if(!IsDefined(level._zbv_vox_last_update_time))
	{
		level._zbv_vox_last_update_time = 0;	
		level._audio_zbv_shared_ent_list = zombie_utility::get_zombie_array();
	}
	
	while(1)
	{
		wait(1);		
		
		t = GetTime();
		
		if(t > level._zbv_vox_last_update_time + 1000)
		{
			level._zbv_vox_last_update_time = t;
			level._audio_zbv_shared_ent_list = zombie_utility::get_zombie_array();
		}
		
		zombs = level._audio_zbv_shared_ent_list;
		
		played_sound = false;
		
		for(i=0;i<zombs.size;i++)
		{
			if(!isDefined(zombs[i]))
			{
				continue;
			}
			
			if(zombs[i].isdog)
			{
				continue;
			}
				
			dist = 150;	
			z_dist = 50;	
			alias = level.vox_behind_zombie;
					
			if(IsDefined(zombs[i].zombie_move_speed))
			{
				switch(zombs[i].zombie_move_speed)
				{
					case "walk": dist = 150;break;
					case "run": dist = 175;break;
					case "sprint": dist = 200;break;
				}	
			}			
			if(DistanceSquared(zombs[i].origin,self.origin) < dist * dist )
			{				
				yaw = self zm_utility::GetYawToSpot(zombs[i].origin );
				z_diff = self.origin[2] - zombs[i].origin[2];
				if( (yaw < -95 || yaw > 95) && abs( z_diff ) < 50 )
				{
					zombs[i] notify( "bhtn_action_notify", "behind" );
					played_sound = true;
					break;
				}			
			}
		}
		
		if(played_sound)
		{
			wait(3.5);		// Each player can only play one instance of this sound every 5 seconds - instead of the previous network storm.
		}
	}
}

function oh_shit_vox()
{
	self endon("death_or_disconnect");
	
	while(1)
	{
		wait(1);
		
		players = GetPlayers();
		zombs = zombie_utility::get_round_enemy_array();
	
		if( players.size >= 1 )
		{
			close_zombs = 0;
			for( i=0; i<zombs.size; i++ )
			{
				if( (isDefined(zombs[i].favoriteenemy) && zombs[i].favoriteenemy == self) || !isDefined(zombs[i].favoriteenemy) )
				{
					if( DistanceSquared( zombs[i].origin, self.origin ) < 250 * 250)
					{
						close_zombs ++;
					}
				}
			}
			if( close_zombs > 4 )
			{
				self zm_audio::create_and_play_dialog( "general", "oh_shit" );
				wait(4);	
			}
		}
	}
}

//** Player Killstreaks: The following functions start a timer on each player whenever they begin killing zombies.
//** If they kill a certain amount of zombies within a certain time, they will get a Killstreak line
function player_killstreak_timer()
{
	self endon("disconnect");
	self endon("death");
	
	if(GetDvarString ("zombie_kills") == "") 
	{
		SetDvar ("zombie_kills", "7");
	}	
	if(GetDvarString ("zombie_kill_timer") == "") 
	{
		SetDvar ("zombie_kill_timer", "5");
	}

	kills = GetDvarInt( "zombie_kills");
	time = GetDvarInt( "zombie_kill_timer");

	if (!isdefined (self.timerIsrunning))	
	{
		self.timerIsrunning = 0;
		self.killcounter = 0;
	}

	while(1)
	{
		self waittill( "zom_kill", zomb );	
		
		if( IsDefined( zomb._black_hole_bomb_collapse_death ) && zomb._black_hole_bomb_collapse_death == 1 )
		{
		    continue;
		}
		
		if( IS_TRUE( zomb.microwavegun_death ) )
		{
			continue;
		}
		
		self.killcounter ++;

		if (self.timerIsrunning != 1)	
		{
			self.timerIsrunning = 1;
			self thread timer_actual(kills, time);			
		}
	}	
}

function player_zombie_kill_vox( hit_location, player, mod, zombie )
{
	weapon = player GetCurrentWeapon();
	dist = DistanceSquared( player.origin, zombie.origin );
	
	if( !isdefined(level.zombie_vars[player.team]["zombie_insta_kill"] ) )
		level.zombie_vars[player.team]["zombie_insta_kill"] = 0;
		
	instakill = level.zombie_vars[player.team]["zombie_insta_kill"];
	
	death = [[ level.audio_get_mod_type ]]( hit_location, mod, weapon, zombie, instakill, dist, player );
	if ( !isdefined(death))
	    {
	    	return undefined;
	    }

	if( !IS_TRUE(player.force_wait_on_kill_line) )
	{
		player.force_wait_on_kill_line = true;
		player create_and_play_dialog( "kill", death );
		wait(2);
		if(isdefined(player))	// Host migration or simple disconnection during this wait can lead to the following line causing an SRE.
		{
			player.force_wait_on_kill_line = false;
		}
	}
}

function get_response_chance( event )
{
	if(!isDefined(level.response_chances[event] ))
	{
		return 0;
	}
	return level.response_chances[event];
}

function get_mod_type( impact, mod, weapon, zombie, instakill, dist, player )
{
	close_dist = 64 * 64;
	med_dist = 124 * 124;
	far_dist = 400 * 400;
	
	if( weapon.name == "hero_annihilator" )
	{
		return "annihilator";
	}
	
	if( zm_utility::is_placeable_mine( weapon ) )
	{
	    if( !instakill )
	        return "betty";
	    else
	        return "weapon_instakill";
	}
	
	if ( zombie.damageweapon.name ==  "cymbal_monkey" )
	{
		if(instakill)
			return "weapon_instakill";
		else
			return "monkey";
	}
	
	//RAYGUN & RAYGUN_INSTAKILL
	if( weapon.name == "ray_gun" && dist > far_dist )
	{
		if( !instakill )
			return "raygun";
		else
			return "weapon_instakill";
	}
	
	//HEADSHOT
	if( zm_utility::is_headshot(weapon,impact,mod) && dist >= far_dist )
	{
		return "headshot";
	}	
	
	//MELEE & MELEE_INSTAKILL
	if ( (mod == "MOD_MELEE" || mod == "MOD_UNKNOWN") && dist < close_dist )
	{
		if( !instakill )
			return "melee";
		else
			return "melee_instakill";
	}
	
	//EXPLOSIVE & EXPLOSIVE_INSTAKILL
	if( zm_utility::is_explosive_damage( mod ) && weapon.name != "ray_gun" && !IS_TRUE(zombie.is_on_fire) )
	{
		if( !instakill )
			return "explosive";
		else
			return "weapon_instakill";
	}
	
	//FLAME & FLAME_INSTAKILL
	if( weapon.doesFireDamage && ( mod == "MOD_BURNED" || mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" ) )
	{
		if( !instakill )
			return "flame";
		else
			return "weapon_instakill";
	}
		
	if (!isdefined(impact))
		impact = "";
	
	//BULLET & BULLET_INSTAKILL
	if( mod == "MOD_RIFLE_BULLET" ||   mod == "MOD_PISTOL_BULLET" )
	{
		if( !instakill )
			return "bullet";
		else
			return "weapon_instakill";
	}
	
	if(instakill)
	{
		return "default";
	}
	
	//CRAWLER
	if( mod != "MOD_MELEE" && zombie.missingLegs )
	{
		return "crawler";
	}
	
	//CLOSEKILL
	if( mod != "MOD_BURNED" && dist < close_dist  )
	{
		return "close";
	}
	
	return "default";
}

function timer_actual(kills, time)
{
	self endon("disconnect");
	self endon("death");
	
	timer = gettime() + (time * 1000);
	while(getTime() < timer)
	{
		if (self.killcounter > kills )
		{
			self create_and_play_dialog( "kill", "streak" );

			wait(1);
		
			//resets the killcounter and the timer 
			self.killcounter = 0;

			timer = -1;
		}
		wait(0.1);
	}
	wait(10); //10 seconds before he can say this again
	self.killcounter = 0;
	self.timerIsrunning = 0;
}	

function zmbVoxCreate()
{
	vox = SpawnStruct(); 
	vox.speaker = []; 
	return( vox );
}
function zmbVoxInitSpeaker( speaker, prefix, ent )
{
	ent.zmbVoxID = speaker;
	
	if( !isdefined( self.speaker[speaker] ) )
	{
		self.speaker[speaker] = SpawnStruct();
		self.speaker[speaker].alias = [];
	}
	
	self.speaker[speaker].prefix = prefix;
	self.speaker[speaker].ent = ent;
}

#define KILL_DAMAGE_VO_DURATION 2
function custom_kill_damaged_VO( player ) // self = zombie
{
	self notify( "sound_damage_player_updated" );
	
	self endon( "death" );
	self endon( "sound_damage_player_updated" );
	
	self.sound_damage_player = player;

	wait KILL_DAMAGE_VO_DURATION;

	self.sound_damage_player = undefined;	
}


/*
 * 		
 * 		UPDATED DIALOG SYSTEM SECTION
 * 		Contains new way of importing lines per level
 * 		Cleans up unneeded function and uses
 * 		Check out _zm_audio.gsh for definitions if unsure
 * 
 */

function loadPlayerVoiceCategories(table)
{
	level.votimer = [];
	level.sndPlayerVox = [];
	
	index = 0;
	row = TableLookupRow( table, index );
	
	while ( isdefined( row ) )
	{
		//Get this weapons data from the current tablerow
		category 		= checkStringValid( row[VOX_TABLE_COL_CATEGORY] );
		subcategory 	= checkStringValid( row[VOX_TABLE_COL_SUBCATEGORY] );
		suffix 			= checkStringValid( row[VOX_TABLE_COL_SUFFIX] );
		percentage 		= int( row[VOX_TABLE_COL_PERCENTAGE] );
		
		if( percentage <= 0 )
			percentage = 100;
		
		response		= checkStringTrue( row[VOX_TABLE_COL_RESPONSE] );
		
		if( IS_TRUE( response ) )
		{
			for (i=0; i<4; i++)
			{
				zmbVoxAdd( category, subcategory + RESPOND_APPEND + i, suffix + RESPOND_APPEND + i, RESPONSE_PERCENTAGE, false );
			}
		}
		
		delayBeforePlayAgain = checkIntValid( row[VOX_TABLE_COL_DELAYBEFOREPLAY] );
		
		zmbVoxAdd( category, subcategory, suffix, percentage, response, delayBeforePlayAgain );

		index++;
		row = TableLookupRow( table, index );
	}
}
function checkStringValid( str )
{
	if( str != "" )
		return str;
	return undefined;
}
function checkStringTrue( str )
{
	if( !isdefined( str ) )
		return false;
	
	if( str != "" )
	{
		if( ToLower( str ) == "true" )
			return true;
	}
	return false;
}
function checkIntValid( value, defaultValue = 0 )
{
	if( !isdefined( value ) )
		return defaultValue;
	
	if( value == "" )
		return defaultValue;
	
	return Int( value );
}
function zmbVoxAdd( category, subcategory, suffix, percentage, response, delayBeforePlayAgain = 0 )
{
	Assert( IsDefined( category ) );
	Assert( IsDefined( subcategory ) );
	Assert( IsDefined( suffix ) );
	Assert( IsDefined( percentage ) );
	Assert( IsDefined( response ) );
	Assert( IsDefined( delayBeforePlayAgain ) );
	
	vox = level.sndPlayerVox;
	
	if( !isdefined( vox[category] ) )
		vox[category] = [];
	
	vox[category][subcategory] = spawnstruct();
	vox[category][subcategory].suffix = suffix;
	vox[category][subcategory].percentage = percentage;
	vox[category][subcategory].response = response;
	vox[category][subcategory].delayBeforePlayAgain = delayBeforePlayAgain;
	
	zm_utility::create_vox_timer(subcategory);
}

function create_and_play_dialog( category, subcategory, force_variant )
{              
	if( !IsDefined( level.sndPlayerVox ) )
		return;
	
	if( !IsDefined( level.sndPlayerVox[category] ) )
		return;
	
	if( !IsDefined( level.sndPlayerVox[category][subcategory] ) )
	{
		return;
	}
	
	// Checks for total level sound override or whether the player is speaking (and isn't waiting to speak)
	if( IS_TRUE( level.sndVoxOverride ) || ( IS_TRUE( self.isSpeaking ) && !IS_TRUE( self.b_wait_if_busy ) ) )
	{
		return;
	}
	
	suffix =  level.sndPlayerVox[category][subcategory].suffix;
	percentage =  level.sndPlayerVox[category][subcategory].percentage;
	
	prefix = shouldPlayerSpeak(self, category, subcategory, percentage );
	if( !isdefined( prefix ) )
		return;
	
    sound_to_play = self zmbVoxGetLineVariant( prefix, suffix, force_variant );
    
    if( isdefined( sound_to_play ) )
    {	
		self thread do_player_or_npc_playvox( sound_to_play, category, subcategory );
    }
    else
    {
    }
}

function do_player_or_npc_playvox( sound_to_play, category, subcategory )
{
	self endon("death_or_disconnect");
	
	// If beastmode EXISTS and is on for me, cancel the speech. 
	// Not all levels have beast mode, so we need to check its existence before checking its setting.
	if ((self flag::exists( "in_beastmode" )) && (self flag::get( "in_beastmode" )))
	{
		return;
	}

	// Leaving this in for all the other legacy functions that use this boolean.
	if ( !isdefined( self.isSpeaking ) )
	{
		self.isSpeaking = false;
	}
	
	if ( self.isSpeaking ) 	// If already speaking, cancel the speech.
	{
		return;
	}
	
	waittime = 1;

	if ( !self areNearbySpeakersActive() || IS_TRUE( self.ignoreNearbySpkrs ) )
	{
		self.speakingLine = sound_to_play;
		
		self.isSpeaking = true;		// TODO: this will eventually be converted to a flag.
				
		if(isPlayer(self))
		{
			self clientfield::set_to_player( "isspeaking",1 ); 
		}

		playbackTime = soundgetplaybacktime( sound_to_play );
		
		if( !isdefined( playbackTime ) )
			return;
		
		if ( playbackTime >= 0 )
		{
			playbackTime = playbackTime * .001;
		}
		else
		{
			playbackTime = 1;
		}
		
		if( isdefined( level._do_player_or_npc_playvox_override ) )
		{
			self thread [[level._do_player_or_npc_playvox_override]](sound_to_play, playbackTime);
			wait(playbackTime);
		}
		else if ( !self IsTestClient() )
		{
			self PlaySoundOnTag( sound_to_play, "J_Head" );
			wait(playbackTime);
		}
		
		if( isPlayer(self) && isDefined(self.last_vo_played_time)  )
		{
			if( GetTime() < ( self.last_vo_played_time + 5000 ) )
			{
				self.last_vo_played_time = GetTime();
				waittime = 7;
			}
		}
		
		wait( waittime );
		
		self.isSpeaking = false;	// TODO: this will eventually be converted to a flag.
				
		if(isPlayer(self))
		{
			self clientfield::set_to_player( "isspeaking",0 ); 
		}
		
		if( !level flag::get( "solo_game" ) && IS_TRUE( level.sndPlayerVox[category][subcategory].response ) )
		{
			if( IS_TRUE( level.vox_response_override ) )
			{
				level thread setup_response_line_override( self, category, subcategory );
			}
			else
			{
				level thread setup_response_line( self, category, subcategory );
			}
		}
	}
}

function setup_response_line_override( player, category, subcategory )
{
	if(isdefined(level._audio_custom_response_line))
	{
		self thread [[level._audio_custom_response_line]]( player, category, subcategory );
	}
	else
	{
		switch( player.characterindex )
		{
			case DEMPSEY_CHAR_INDEX_R:
				level setup_hero_rival( player, NIKOLAI_CHAR_INDEX_R, RICHTOFEN_CHAR_INDEX_R, category, subcategory );
			break;
			
			case NIKOLAI_CHAR_INDEX_R:
				level setup_hero_rival( player, RICHTOFEN_CHAR_INDEX_R, TAKEO_CHAR_INDEX_R, category, subcategory );
			break;
			
			case TAKEO_CHAR_INDEX_R:
				level setup_hero_rival( player, DEMPSEY_CHAR_INDEX_R, NIKOLAI_CHAR_INDEX_R, category, subcategory );
			break;
			
			case RICHTOFEN_CHAR_INDEX_R:
				level setup_hero_rival( player, TAKEO_CHAR_INDEX_R, DEMPSEY_CHAR_INDEX_R, category, subcategory );
			break;
		}
	}
	return;
}

function setup_hero_rival( player, hero, rival, category, type )
{
	players = GetPlayers();
	
    hero_player = undefined;
    rival_player = undefined;
    
    foreach(ent in players)
    {
    	if(ent.characterIndex == hero )
    	{
    		hero_player = ent;
    	}
    	else if (ent.characterIndex == rival )
    	{
    		rival_player = ent;
    	}
    }    
	
    if(isDefined(hero_player) && isDefined(rival_player))
	{
    	if( randomint(100) > 50 )
		{
			hero_player = undefined;
		}
		else
		{
			rival_player = undefined;
		}
	}	
	if( IsDefined( hero_player ) && distancesquared (player.origin, hero_player.origin) < 500*500 )
	{	
		if( IS_TRUE( player.isSamantha ) )
		{
			hero_player create_and_play_dialog( category, type + "_s" );
		}
		else
		{
			hero_player create_and_play_dialog( category, type + "_hr" );
		}
	}		
	else if(IsDefined( rival_player ) && distancesquared (player.origin, rival_player.origin) < 500*500  )
	{
		if( IS_TRUE( player.isSamantha ) )
		{
			rival_player create_and_play_dialog( category, type + "_s" );
		}
		else
		{
			rival_player create_and_play_dialog( category, type + "_riv" );
		}
	}
}

function setup_response_line( player, category, subcategory )
{
	players = array::get_all_closest( player.origin, level.activeplayers );
	
	players_that_can_respond = array::exclude( players, player );
	
	if ( players_that_can_respond.size == 0 )
	{
		return;
	}
	
	player_to_respond = players_that_can_respond[0];

	if( distancesquared (player.origin, player_to_respond.origin) < RESPONSE_LINE_MAX_DIST )
	{		
		player_to_respond create_and_play_dialog( category, subcategory + RESPOND_APPEND + player.characterindex );
	}		
}

function shouldPlayerSpeak(player, category, subcategory, percentage )
{
	if ( !IsDefined(player) )
		return undefined;
	
	if( !player zm_utility::is_player() )
		return undefined;
		
	if( player zm_utility::is_player() )
	{
		if ( player.sessionstate != "playing" )
			return undefined;
		
		if( player laststand::player_is_in_laststand() && ( subcategory != "revive_down" || subcategory != "revive_up" ) )
			return undefined;
		
		if( player IsPlayerUnderwater() )
			return undefined;
	}
	
	if(IS_TRUE(player.dontspeak))
		return undefined;
	
	if( percentage < randomintrange(1,101) )
		return undefined;
	
	if( isVoxOnCooldown(player, category, subcategory) )
		return undefined;
	
	index = zm_utility::get_player_index(player);
	
	if( IS_TRUE( player.isSamantha ) )
		index = 4;
	
	return PLAYER_PREFIX + index + "_";
}
function isVoxOnCooldown(player, category, subcategory)
{
	if( level.sndPlayerVox[category][subcategory].delayBeforePlayAgain <= 0 )
		return false;
	
	fullName = category + subcategory;
	if( !isdefined( player.voxTimer ) )
	{
		player.voxTimer = [];
	}
	if( !isdefined( player.voxTimer[fullName] ) )
	{
		player.voxTimer[fullName] = GetTime();
		return false;
	}
	
	time = GetTime();
    if( ( time - player.voxTimer[fullName] ) <= ( level.sndPlayerVox[category][subcategory].delayBeforePlayAgain * 1000 ) )
	{
		return true;
	}
    
    player.voxTimer[fullName] = time;
    return false;
}
function zmbVoxGetLineVariant( prefix, suffix, force_variant )
{
	if( !IsDefined ( self.sound_dialog ) )
	{
		self.sound_dialog = [];
		self.sound_dialog_available = [];
	}
				
	if ( !IsDefined ( self.sound_dialog[ suffix ] ) )
	{
		num_variants = zm_spawner::get_number_variants( prefix + suffix );      
		
		if( num_variants <= 0 )
		{
		    return undefined;
		}     
		
		for( i = 0; i < num_variants; i++ )
		{
			self.sound_dialog[ suffix ][ i ] = i;     
		}	
		
		self.sound_dialog_available[ suffix ] = [];
	}
	
	if ( self.sound_dialog_available[ suffix ].size <= 0 )
	{
		for( i = 0; i < self.sound_dialog[ suffix ].size; i++ )
		{
			self.sound_dialog_available[ suffix ][i] = self.sound_dialog[ suffix ][i];
		}
	}
  
	variation = array::random( self.sound_dialog_available[ suffix ] );
	ArrayRemoveValue( self.sound_dialog_available[ suffix ], variation );
    
    if( IsDefined( force_variant ) )
    {
        variation = force_variant;
    }
    
    return (prefix + suffix + "_" + variation);
}
function areNearbySpeakersActive( radius = 1000 )
{
	// The radius by default is Twice Range Of Response Radius (Which Is Currently 500 Units)
	
	nearbySpeakerActive = false;
	
	speakers = GetPlayers();
	
	foreach ( person in speakers )
	{
		if ( self == person )
		{
			continue;
		}

		if ( person zm_utility::is_player() )
		{
			// Nearby Player Isn't Currently Playing
			//--------------------------------------
			if ( person.sessionstate != "playing" )
			{
				continue;
			}
			
			// Nearby Player In Last Stand
			//----------------------------
			if ( person laststand::player_is_in_laststand() )
			{
				continue;
			}
		}
		
		if ( IS_TRUE( person.isSpeaking ) && !IS_TRUE( person.ignoreNearbySpkrs ) )
		{
			if ( DistanceSquared( self.origin, person.origin ) < ( radius * radius ) )
			{
				nearbySpeakerActive = true;
			}
		}
	}
	
	return nearbySpeakerActive;
}

/*
 * 		
 * 		MUSIC
 * 		Encompasses both the standard Round Start/End Music system, and the updated system added in MOTD, Buried, Origins
 * 
 * 
 */

function musicState_Create( stateName, playType = PLAYTYPE_REJECT, musName1, musName2, musName3, musName4, musName5, musName6 )
{
	if( !isdefined( level.musicSystem ) )
	{
		level.musicSystem = spawnstruct();
		level.musicSystem.queue = false;
		level.musicSystem.currentPlaytype = PLAYTYPE_NONE;
		level.musicSystem.currentSet = undefined;
		level.musicSystem.states = [];
	}
	
	level.musicSystem.states[stateName] = spawnstruct();
	level.musicSystem.states[stateName].playType = playType;
	level.musicSystem.states[stateName].musArray = array();
	
	if( isdefined( musName1 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName1);
	if( isdefined( musName2 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName2);
	if( isdefined( musName3 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName3);
	if( isdefined( musName4 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName4);
	if( isdefined( musName5 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName5);
	if( isdefined( musName6 ) )
		array::add(level.musicSystem.states[stateName].musArray,musName6);
}

function sndMusicSystem_CreateState( state, stateName, playtype = PLAYTYPE_REJECT, delay = 0 )
{
	if( !isdefined( level.musicSystem ) )
	{
		level.musicSystem = spawnstruct();
		level.musicSystem.ent = spawn( "script_origin", (0,0,0) );
		level.musicSystem.queue = false;
		level.musicSystem.currentPlaytype = 0;
		level.musicSystem.currentState = undefined;
		level.musicSystem.states = [];
	}
	
	m = level.musicSystem;
	if( !isdefined( m.states[state] ) )
	{
		m.states[state] = spawnstruct();
		m.states[state] = array();
	}
	
	m.states[state][m.states[state].size].stateName = stateName;
	m.states[state][m.states[state].size].playtype = playtype;
}
function sndMusicSystem_PlayState( state )
{
	if( !isdefined( level.musicSystem ) )
		return;
	
	m = level.musicSystem;
	
	if( !isdefined( m.states[state] ) )
		return;
	
	s = level.musicSystem.states[state];
	playtype = s.playtype;
	
	if( m.currentPlaytype > 0 )
	{
		if( playtype == PLAYTYPE_REJECT )
		{
			break;
		}
		else if( playtype == PLAYTYPE_QUEUE )
		{
			level thread sndMusicSystem_QueueState(state);
		}
		else if( playtype > m.currentPlaytype || (playtype == PLAYTYPE_ROUND && m.currentPlaytype == PLAYTYPE_ROUND ) )
		{
			if( IS_TRUE( level.musicSystemOverride ) && playtype != PLAYTYPE_GAMEEND ) //Allowing me to go into a special music mode that prevents all other music from playing
				return;
			else
			{
				level sndMusicSystem_StopAndFlush();
				level thread playState( state );
			}
		}
	}
	else if( !IS_TRUE( level.musicSystemOverride ) || playtype == PLAYTYPE_GAMEEND )
	{
		level thread playState( state );
	}
}
function playState( state )
{
	level endon( "sndStateStop" );
	
	m = level.musicSystem;
	musArray = level.musicSystem.states[state].musArray;
	
	if( musArray.size <= 0 )
		return;
	
	musToPlay = musArray[randomintrange(0,musArray.size)];

	m.currentPlaytype = m.states[state].playtype;
	m.currentState = state;
	
	wait( .1 );
	
	if( isdefined( level.sndPlayStateOverride ) )
	{
		perPlayer = level [[level.sndPlayStateOverride]](state);
		if( !IS_TRUE(perPlayer) )
		{
			music::setmusicstate(musToPlay);
		}
	}
	else
	{
		music::setmusicstate(musToPlay);
	}
	
	aliasname = "mus_" + musToPlay + "_intro";
	playbacktime = soundgetplaybacktime( aliasname );
	if( !isdefined( playbacktime ) || playbacktime <= 0 )
		waittime = 1;
	else
		waittime = playbackTime * .001;
	
	wait(waittime);
	
	//music::setmusicstate("none");
	m.currentPlaytype = 0;
	m.currentState = undefined;
}
function sndMusicSystem_QueueState( state )
{
	level endon( "sndQueueFlush" );
	
	m = level.musicSystem;
	count = 0;
	
	if( IS_TRUE( m.queue ) )
	{
		return;
	}
	else
	{
		m.queue = true;
		
		while(m.currentPlaytype > 0)
		{
			wait(.5);
			count++;
			if( count >= 25 )
			{
				m.queue = false;
				return;
			}
		}
		
		level thread playState( state );
		
		m.queue = false;
	}
}
function sndMusicSystem_StopAndFlush()
{
	level notify( "sndQueueFlush" );
	level.musicSystem.queue = false;
	
	level notify( "sndStateStop" );
	//music::setmusicstate("none");
	level.musicSystem.currentPlaytype = 0;
	level.musicSystem.currentState = undefined;
}

function sndMusicSystem_IsAbleToPlay()
{
	if( !isdefined( level.musicSystem ) )
		return false;
	
	if( !isdefined( level.musicSystem.currentPlaytype ) )
		return false;
	
	if( level.musicSystem.currentPlaytype >= 4 )
		return false;
	
	return true;
}

#define LOCATION_NUM_UNTIL_REPEAT 3
function sndMusicSystem_LocationsInit(locationArray)
{
	if( !isdefined( locationArray ) || locationArray.size <= 0 )
		return;
	
	level.musicSystem.locationArray = locationArray;
	level thread sndMusicSystem_Locations(locationArray);
}
function sndMusicSystem_Locations(locationArray)
{	
	numCut = 0;
	level.sndLastZone = undefined;
	
	m = level.musicSystem;
	
	while(1)
	{
		level waittill( "newzoneActive", activeZone );
		
		wait(.1);
		
		if( !sndLocationShouldPlay( locationArray, activeZone ) )
		{
			continue;
		}
	   
		level thread sndMusicSystem_PlayState( activeZone );
		
		locationArray = sndCurrentLocationArray( locationArray, activeZone, numCut, LOCATION_NUM_UNTIL_REPEAT );
		level.sndLastZone = activeZone;
		
		if( numCut >= LOCATION_NUM_UNTIL_REPEAT )
			numCut = 0;
		else
			numCut++;
		
		level waittill( "between_round_over" );
	}
}
function sndLocationShouldPlay(array,activeZone)
{
	shouldPlay = false;
	
	if( level.musicSystem.currentPlaytype >= PLAYTYPE_ROUND )
	{
		level thread sndLocationQueue( activeZone );
		return shouldPlay;
	}

	foreach( place in array )
	{
		if( place == activeZone )
			shouldPlay = true;
	}
	
	if( shouldPlay == false )
		return shouldPlay;
	
	if( zm_zonemgr::any_player_in_zone( activeZone ) )
		shouldPlay = true;	
	else
		shouldPlay = false;
	
	return shouldPlay;
}
function sndCurrentLocationArray( current_array, activeZone, numCut, num )
{
	if( numCut >= num )
	{
		current_array = level.musicSystem.locationArray;
	}
	
	foreach( place in current_array )
	{
		if( place == activeZone )
		{
			arrayremovevalue( current_array, place );
			break;
		}
	}	
	return current_array;
}
function sndLocationQueue( zone )
{
	level endon( "newzoneActive" );
	
	while( level.musicSystem.currentPlaytype >= PLAYTYPE_ROUND )
		wait.5;
	
	level notify( "newzoneActive", zone );
}

function sndMusicSystem_EESetup(state, origin1, origin2, origin3, origin4, origin5)
{
}
function sndMusicSystem_EEWait( origin, state )
{
}
function sndMusicSystem_EEOverride(arg1,arg2)
{
}
function secretUse(notify_string, color, qualifier_func, arg1, arg2 )
{
}

/*
 * 
 * 		ANNOUNCER VOX: Don't need an overly complicated system, just a few simple functions
 * 		Will simply play announcer vox in 2d.  Prefix can be changed in level gsc if we need a new announcer
 * 		
 * 
 */ 
 
 #define ZOMBIE_ANNOUNCER_PREFIX "zmba"
function sndAnnouncer_Init()
{
	if( !isdefined( level.zmAnnouncerPrefix ) )
		level.zmAnnouncerPrefix = "vox_"+ZOMBIE_ANNOUNCER_PREFIX+"_";

	sndAnnouncerVoxAdd( "carpenter", "powerup_carpenter_0" );
	sndAnnouncerVoxAdd( "insta_kill", "powerup_instakill_0" );
	sndAnnouncerVoxAdd( "double_points", "powerup_doublepoints_0" );
	sndAnnouncerVoxAdd( "nuke", "powerup_nuke_0" );
	sndAnnouncerVoxAdd( "full_ammo", "powerup_maxammo_0" );
	sndAnnouncerVoxAdd( "fire_sale", "powerup_firesale_0" );
	sndAnnouncerVoxAdd( "minigun", "powerup_death_machine_0" );
	sndAnnouncerVoxAdd( "boxmove", "event_magicbox_0" );
	sndAnnouncerVoxAdd( "dogstart", "event_dogstart_0" );
}
function sndAnnouncerVoxAdd( type, suffix )
{
	if( !isdefined( level.zmAnnouncerVox ) )
	{
		level.zmAnnouncerVox = array();
	}
	
	level.zmAnnouncerVox[type] = suffix;
}
function sndAnnouncerPlayVox(type, player)
{
	if( !isdefined( level.zmAnnouncerVox[type] ) )
		return;
	
	prefix = level.zmAnnouncerPrefix;
	suffix = level.zmAnnouncerVox[type];
	
	if( !IS_TRUE( level.zmAnnouncerTalking ) )
	{
		if( !isdefined( player ) )
		{
			level.zmAnnouncerTalking = true;
			
			temp_ent = spawn("script_origin", (0,0,0));
			temp_ent PlaySoundWithNotify(prefix+suffix, prefix+suffix+"wait");
			temp_ent waittill(prefix+suffix+"wait");
			WAIT_SERVER_FRAME;
			temp_ent delete();
			
			level.zmAnnouncerTalking = false;
		}
		else
		{
			player playsoundtoplayer( prefix+suffix, player );
		}
	}
}

/*
 * 
 * 		ZOMBIE VOX: Moving to the notify system, most vox is still script based, but death and attack are from AI Editor
 * 
 */ 

function zmbAIVox_NotifyConvert()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	self thread zmbAIVox_PlayDeath();
	self thread zmbAIVox_PlayElectrocution();

	while (1)
{
		self waittill("bhtn_action_notify", notify_string);
		
		switch( notify_string )
		{	
			case "pain":
				level thread zmbAIVox_PlayVox( self, notify_string, true, 9 );
				break;				
			case "death":
				if( IS_TRUE( self.bgb_tone_death ) )
					level thread zmbAIVox_PlayVox( self, "death_whimsy", true, 10 );
				else
					level thread zmbAIVox_PlayVox( self, notify_string, true, 10 );
				break;				
			case "behind":
				level thread zmbAIVox_PlayVox( self, notify_string, true, 9 );
				break;
			case "attack_melee":
				if( !isdefined( self.animname ) || ( self.animname != "zombie" && self.animname != "quad_zombie" ) ) //Moving standard zombie attack vocals to anims, adding this check here as an easy way to keep them out of playing through script
                    level thread zmbAIVox_PlayVox( self, notify_string, true, 8, true );
                break;
            case "attack_melee_zhd": //Technically not just ZHD, but new way of hooking up attack vocals
                level thread zmbAIVox_PlayVox( self, "attack_melee", true, 8, true );
                break;
			case "electrocute":
				level thread zmbAIVox_PlayVox( self, notify_string, true, 7 );
				break;
			case "close":
				level thread zmbAIVox_PlayVox( self, notify_string, true, 6 );
				break;
			case "teardown":
			case "taunt":
			case "ambient":
			case "sprint":
			case "crawler":
				level thread zmbAIVox_PlayVox( self, notify_string, false );
				break;
			default:
			{
				if ( IsDefined( level._zmbAIVox_SpecialType ) )
				{
					if( isdefined( level._zmbAIVox_SpecialType[notify_string] ) )
					{
						level thread zmbAIVox_PlayVox( self, notify_string, false );
					}
				}
				break;
			}
		}
	}
}
function zmbAIVox_PlayVox( zombie, type, override, priority, delayAmbientVox = false )
{
    zombie endon( "death" ); 
    
    if( !isdefined( zombie ) )
    	return;
    
    if( !isdefined( zombie.voicePrefix ) )
    	return; 
    
    if( !isdefined( priority ) )
    	priority = 1;
    
    if( !isdefined( zombie.currentvoxpriority ) )
    	zombie.currentvoxpriority = 1;
    
    if( !isdefined( self.delayAmbientVox ) )
    	self.delayAmbientVox = false;
    
    if( ( type == "ambient" || type == "sprint" || type == "crawler" ) && IS_TRUE( self.delayAmbientVox ) ) //Prevents ambient/sprint/crawl vocals from playing immediately after a vox set with delayAmbientVox plays
    	return;
    
    if( delayAmbientVox ) 
    {
    	self.delayAmbientVox = true;
    	self thread zmbAIVox_AmbientDelay();
    }
     
   alias = "zmb_vocals_" + zombie.voicePrefix + "_" + type;
      
    if( sndIsNetworkSafe() )
	{
	    if( IS_TRUE( override ) )
	    {
	    	if (isdefined( zombie.currentvox ) && priority > zombie.currentvoxpriority )
	    	{
	    		zombie stopsound ( zombie.currentvox );
	    	}
	    	
	    	if( type == "death" || type == "death_whimsy" )
	    	{
	    		zombie PlaySound( alias );
	    		return;
	    	}
	    }

	   	if ( zombie.talking === true && priority < zombie.currentvoxpriority )
	   		return;
	    	
	   	zombie.talking = true;
	      
	    if( zombie is_last_zombie() && type == "ambient" )
	       	alias = alias + "_loud";
	        
	    zombie.currentvox = alias;
	    zombie.currentvoxpriority = priority;	  	        
	       
	    zombie PlaySoundOnTag( alias, "j_head" );
	    playbackTime = soundgetplaybacktime( alias );
			
		if( !isdefined( playbackTime ) )
			playbackTime = 1;
		
		if ( playbackTime >= 0 )
			playbackTime = playbackTime * .001;
		else
			playbackTime = 1;
			
		wait(playbacktime);
	    zombie.talking = false;
	    zombie.currentvox = undefined;
	    zombie.currentvoxpriority = 1;	        
    }
  
}
function zmbAIVox_PlayDeath()
{
	self endon ( "disconnect" );
	
	self waittill ( "death", attacker, meansOfDeath );
	
	if ( isdefined( self ) )
	{	
		if( IS_TRUE( self.bgb_tone_death ) )
			level thread zmbAIVox_PlayVox( self, "death_whimsy", true );
		else
			level thread zmbAIVox_PlayVox( self, "death", true );
	}
}
function zmbAIVox_PlayElectrocution()
{
	self endon ( "disconnect" );
	self endon( "death" );
	
	while(1)
	{
		self waittill( "damage", amount, attacker, direction_vec, point, type, tagName, ModelName, Partname, weapon );
		if( weapon.name == "zombie_beast_lightning_dwl" || weapon.name == "zombie_beast_lightning_dwl2" || weapon.name == "zombie_beast_lightning_dwl3" )
		{
			self notify( "bhtn_action_notify", "electrocute" );
		}
	}
}
function zmbAIVox_AmbientDelay()
{	
	self notify( "sndAmbientDelay" );
	self endon( "sndAmbientDelay" );
	self endon( "death" );
	self endon( "disconnect" );
	
	wait(2);
	
	self.delayAmbientVox = false;
}

function networkSafeReset()
{
	while(1)
	{
		level._numZmbAIVox = 0;
		util::wait_network_frame();
	}
}
function sndIsNetworkSafe()
{
	if ( !IsDefined( level._numZmbAIVox ) )
	{
	 	level thread networkSafeReset();
	}

	if ( level._numZmbAIVox >= 2 )
	{
	  	return false;
	}

	level._numZmbAIVox++;
	return true;
}

function is_last_zombie()
{
	if( zombie_utility::get_current_zombie_count() <= 1 )
		return true;
	
	return false;
}

/*		
 * 		Radio Easter Eggs (Or any sort of story asset)
 * 
 */ 
 
function sndRadioSetup(alias_prefix, is_sequential = false, origin1, origin2, origin3, origin4, origin5)
{
}
function sndRadioWait(origin, radio, is_sequential, num)
{	
}
function sndRadio_Override(arg1,arg2)
{
}


//Perksacola Jingle Stuff
function sndPerksJingles_Timer()
{
	self endon( "death" );
	
	if( isdefined( self.sndJingleCooldown ) )
	{
		self.sndJingleCooldown = false;
	}
	
	while(1)
	{
		wait(PERKSACOLA_WAIT_TIME);
		
		if( PERKSACOLA_PROBABILITY && !IS_TRUE(self.sndJingleCooldown) )
		{
			self thread sndPerksJingles_Player(PERKSACOLA_JINGLE);
		}
	}
}
function sndPerksJingles_Player(type)
{
	self endon( "death" );
	
	if( !isdefined( self.sndJingleActive ) )
	{
		self.sndJingleActive = false;
	}
	
	alias = self.script_sound;
	
	if( type == PERKSACOLA_STINGER )
		alias = self.script_label;
	
	if( isdefined( level.musicSystem ) && level.musicSystem.currentPlaytype >= PLAYTYPE_SPECIAL )
		return;
	
	self.str_jingle_alias = alias;
	
	if( !IS_TRUE( self.sndJingleActive ) )
	{
		self.sndJingleActive = true;
		self playsoundwithnotify( alias, "sndDone" );
		
		playbacktime = soundgetplaybacktime( alias );
		if( !isdefined( playbacktime ) || playbacktime <= 0 )
			waittime = 1;
		else
			waittime = playbackTime * .001;
	
		wait(waittime);
		
		if( type == PERKSACOLA_JINGLE )
		{
			self.sndJingleCooldown = true;
			self thread sndPerksJingles_Cooldown();
		}
		
		self.sndJingleActive = false;
	}
}
function sndPerksJingles_Cooldown()
{
	self endon( "death" );
	
	wait(45);
	self.sndJingleCooldown = false;
}

/*
 * 
 * 		CONVERSATIONS
 * 		These will shut off normal player lines for the duration of the conversation
 * 		Conversations can have Required Players.  If a certain player character isn't in the game, the conversation won't occur
 * 		If a Player has a line in a conversation, is NOT a required player, and is NOT currently in game, the line will just be skipped
 * 
 * 
 */

#define RANDOM_PLAYER 4
function sndConversation_Init( name, specialEndon = undefined )
{
	if( !isdefined( level.sndConversations ) )
	{
		level.sndConversations = array();
	}
	
	level.sndConversations[name] = spawnstruct();
	level.sndConversations[name].specialEndon = specialEndon;
}
function sndConversation_AddLine( name, line, player_or_random, ignorePlayer = 5 )
{
	thisConvo = level.sndConversations[name];
	
	if( !isdefined( thisConvo.line ) )
	{
		thisConvo.line = array();
	}
	
	if( !isdefined( thisConvo.player ) )
	{
		thisConvo.player = array();
	}
	
	if( !isdefined( thisConvo.ignorePlayer ) )
	{
		thisConvo.ignorePlayer = array();
	}
	
	ARRAY_ADD( thisConvo.line, line );
	ARRAY_ADD( thisConvo.player, player_or_random );
	ARRAY_ADD( thisConvo.ignorePlayer, ignorePlayer );
}
function sndConversation_Play( name )
{	
	thisConvo = level.sndConversations[name];
	
	level endon( "sndConvoInterrupt" );
	if( isdefined( thisConvo.specialEndon ) )
	{
		level endon( thisConvo.specialEndon );
	}
	
	while( isAnyoneTalking() )
		wait(.5);
	
	while( IS_TRUE( level.sndVoxOverride ) )
		wait(.5);
	
	level.sndVoxOverride = true;
	for(i=0;i<thisConvo.line.size;i++)
	{
		if( thisConvo.player[i] == RANDOM_PLAYER )
			speaker = getRandomCharacter(thisConvo.ignorePlayer[i]);
		else
			speaker = getSpecificCharacter(thisConvo.player[i]);
			
		if( !isdefined( speaker ) )
			continue;
			
		if( isCurrentSpeakerAbleToTalk(speaker) )
		{
			level.currentConvoPlayer = speaker;

			if( isdefined(level.vox_name_complete) )
			{
				level.currentConvoLine = thisConvo.line[i];
			}
			else
			{
				level.currentConvoLine = "vox_plr_"+speaker.characterIndex+"_"+thisConvo.line[i];
				speaker thread sndConvoInterrupt();
			}

			speaker PlaySoundOnTag( level.currentConvoLine, "J_Head" );
			
			waitPlaybackTime( level.currentConvoLine );
			level notify( "sndConvoLineDone" );
		}
	}
	level.sndVoxOverride = false;
	level notify( "sndConversationDone" );
	level.currentConvoLine = undefined;
	level.currentConvoPlayer = undefined;
}
function sndConvoStopCurrentConversation()
{
	level notify( "sndConvoInterrupt" );
	level notify( "sndConversationDone" );
	level.sndVoxOverride = false;
	
	if( isdefined( level.currentConvoPlayer ) && isdefined( level.currentConvoLine ) )
	{
		level.currentConvoPlayer stopsound( level.currentConvoLine );
		level.currentConvoLine = undefined;
		level.currentConvoPlayer = undefined;
	}
}
function waitPlaybackTime(alias)
{
	playbackTime = soundgetplaybacktime( alias );
			
	if( !isdefined( playbackTime ) )
		playbackTime = 1;
			
	if ( playbackTime >= 0 )
		playbackTime = playbackTime * .001;
	else
		playbackTime = 1;
			
	wait(playbacktime);
}
function isCurrentSpeakerAbleToTalk(player)
{
	if( !isdefined( player ) )
		return false;
	
	if ( player.sessionstate != "playing" )
		return false;
		
	if( IS_TRUE( player.laststand ) )
		return false;
	
	return true;
}
function getRandomCharacter(ignore)
{
	array = level.players;
	array::randomize( array );
	
	foreach( guy in array )
	{
		if( guy.characterIndex == ignore )
			continue;
		
		return guy;
	}
	return undefined;
}
function getSpecificCharacter(charIndex)
{
	foreach( guy in level.players )
	{
		if( guy.characterIndex == charIndex )
			return guy;
	}
	return undefined;
}
function isAnyoneTalking()
{
	foreach( player in level.players )
	{
		if( IS_TRUE( player.isSpeaking ) )
		{
			return true;
		}
	}
	
	return false;
}
function sndConvoInterrupt()
{
	level endon("sndConvoLineDone");
	
	while(1)
	{	
		if( !isdefined( self ) )
			return;
		
		max_dist_squared = 0;
		check_pos = self.origin;
		count = 0;
		
		foreach(player in level.players)
		{
			if( self == player )
				continue;
			
			if( distance2dsquared(player.origin, self.origin) >= 900*900 )
				count++;
		}
		
		if( count == (level.players.size-1))
			break;
		
		wait(0.25);
	}
	
	level thread sndConvoStopCurrentConversation();
}

function water_vox()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	level endon ( "end_game" );
	
	self.voxUnderwaterTime = 0;
	self.voxEmergeBreath = false;
	self.voxDrowning = false;

	while(1)
	{		
		if ( self IsPlayerUnderwater() )
		{
			if ( !self.voxUnderwaterTime && !self.voxEmergeBreath )
			{
				self vo_clear_underwater();
				self.voxUnderwaterTime = GetTime();
			}
			else if ( self.voxUnderwaterTime )
			{
				if ( GetTime() > self.voxUnderwaterTime + (3 * 1000) )
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
				self zm_audio::playerexert( "underwater_gasp" );
				
				self.voxDrowning = false;
				self.voxEmergeBreath = false;
			}
			if ( self.voxEmergeBreath )
			{
				self zm_audio::playerexert( "underwater_emerge" );
				self.voxEmergeBreath = false;
			}
			else
			{
				self.voxUnderwaterTime = 0;
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}

function vo_clear_underwater()
{
	self StopSounds();
	self notify( "stop_vo_convo" );
				
	self.str_vo_being_spoken = "";
	self.n_vo_priority = 0;
	self.isSpeaking = false;
	level.sndVoxOverride = false;
	
	// If self is in level.a_e_speakers, remove self from it.	
	b_in_a_e_speakers = false;
	foreach( e_checkme in level.a_e_speakers )
	{
		if ( e_checkme == self )
		{
			b_in_a_e_speakers = true;
			break;
		}
	}
	if (IS_TRUE( b_in_a_e_speakers ))
	{
		ArrayRemoveValue( level.a_e_speakers, self );
	}
}

function sndPlayerHitAlert( e_victim, str_meansofdeath, e_inflictor, weapon )
{
	if( !IS_TRUE( level.sndZHDAudio ) )
		return;
	
	if( !IsPlayer( self ) )
		return;
	
	if( !CheckForValidMod( str_meansofdeath ) )
		return;
	
	if( !CheckForValidWeapon( weapon ) )
		return;
	
	if( !CheckForValidAIType( e_victim ) )
		return;
	
	str_alias = "zmb_hit_alert";
	
	self thread sndPlayerHitAlert_PlaySound( str_alias );
}
function sndPlayerHitAlert_PlaySound( str_alias )
{
	self endon ("disconnect");
	
	if( self.hitSoundTracker )
	{
		self.hitSoundTracker = false;
		
		self playsoundtoplayer( str_alias, self );
		
		wait .05;
		
		self.hitSoundTracker = true;
	}
}
function CheckForValidMod( str_meansofdeath ) //TODO: Zombies will require less mods than MP to return true, find out which ones
{
	if ( !isdefined( str_meansofdeath ) )
		return false;
		
	switch( str_meansofdeath )
	{
		case "MOD_CRUSH":
		case "MOD_GRENADE_SPLASH":
		case "MOD_HIT_BY_OBJECT":
		case "MOD_MELEE_ASSASSINATE":
		case "MOD_MELEE":
		case "MOD_MELEE_WEAPON_BUTT":
			return false;
	}
	
	return true;
}
function CheckForValidWeapon( weapon ) //TODO: any weapons where this sound doesn't make sense, return with false
{
	return true;
}
function CheckForValidAIType( e_victim ) //TODO: any AI where this sound doesn't make sense, or would require a different sound (e.g. metal armor, etc), return with false
{
	return true;
}