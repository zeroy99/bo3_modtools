#using scripts\shared\system_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\music_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace audio;

REGISTER_SYSTEM( "audio", &__init__, undefined )

function __init__()
{	
	callback::on_spawned( &sndResetSoundSettings);
	callback::on_spawned(&missileLockWatcher);
	callback::on_spawned(&missileFireWatcher);
	callback::on_player_killed( &on_player_killed);
	callback::on_vehicle_spawned( &vehicleSpawnContext );
	level thread register_clientfields();
	level thread sndChyronWatcher();
	level thread sndIGCskipWatcher();
}

function register_clientfields()
{
	clientfield::register( "world", "sndMatchSnapshot", VERSION_SHIP, 2, "int" );
	clientfield::register( "world", "sndFoleyContext", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "sndRattle", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "sndMelee", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "sndSwitchVehicleContext", VERSION_SHIP, 3, "int" );
	clientfield::register( "toplayer", "sndCCHacking", VERSION_SHIP, 2, "int" );
	clientfield::register( "toplayer", "sndTacRig", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "sndLevelStartSnapOff", VERSION_SHIP, 1, "int" );
	clientfield::register( "world", "sndIGCsnapshot", VERSION_SHIP, 4, "int" );
	clientfield::register( "world", "sndChyronLoop", VERSION_SHIP, 1, "int" );	
	clientfield::register( "world", "sndZMBFadeIn", VERSION_SHIP, 1, "int" );
}
function sndChyronWatcher()
{
	level waittill( "chyron_menu_open" );
	level clientfield::set( "sndChyronLoop", 1 );	
		
	level waittill( "chyron_menu_closed" );
	level clientfield::set( "sndChyronLoop", 0 );		
}
function sndIGCskipWatcher()
{
	while(1)
	{
		level waittill( "scene_skip_sequence_started" );
		music::setmusicstate( "death" );
	}
}
function sndResetSoundSettings()
{
	self clientfield::set_to_player( "sndMelee", 0 );
	self util::clientnotify( "sndDEDe" );
}
function on_player_killed()
{
	if( !IS_TRUE(self.killcam) )
	{
		self util::clientnotify( "sndDED" );
	}
}
function vehicleSpawnContext()
{
	self clientfield::set( "sndSwitchVehicleContext", 1 );
}
function sndUpdateVehicleContext(added)
{
	if( !isdefined( self.sndOccupants ) )
	{
		self.sndOccupants = 0;
	}
	
	if( added )
	{
		self.sndOccupants++;
	}
	else
	{
		self.sndOccupants--;
		if( self.sndOccupants < 0 )
		{
			self.sndOccupants = 0;
		}
	}
		
	self clientfield::set( "sndSwitchVehicleContext", (self.sndOccupants+1) );
}

function PlayTargetMissileSound( alias, looping )
{
	self notify( "stop_target_missile_sound");
	self endon( "stop_target_missile_sound" );
	self endon( "disconnect" );
	self endon( "death" );
	
	if (IsDefined(alias))
	{
		time = SoundGetPlaybackTime(alias)*0.001;
		if (time>0)
		{
			do 
			{
				self playLocalSound( alias );
				wait(time);
			}
			while (looping);
		}
	}
}

function missileLockWatcher()
{	
	self endon("death");
	self endon("disconnect");

	if (!self flag::exists("playing_stinger_fired_at_me"))
	{
		self flag::init("playing_stinger_fired_at_me",false);
	}
	else
	{
		self flag::clear("playing_stinger_fired_at_me");
	}
	//plays lock on warning sounds for a player
	while (1)
	{
		self waittill("missile_lock", attacker, weapon);
		if (!flag::get("playing_stinger_fired_at_me"))
		{
			self thread PlayTargetMissileSound( weapon.lockonTargetLockedSound, weapon.lockonTargetLockedSoundLoops );
			self util::waittill_any("stinger_fired_at_me","missile_unlocked","death");
			self notify( "stop_target_missile_sound");
		}
	}
}

function missileFireWatcher()
{
	self endon("death");
	self endon("disconnect");
	
	//plays missile fired sounds for a player
	while (1)
	{
		self waittill("stinger_fired_at_me",missile, weapon ,attacker);
		waittillframeend;
		self flag::set("playing_stinger_fired_at_me");
		self thread PlayTargetMissileSound( weapon.lockonTargetFiredOnSound, weapon.lockonTargetFiredOnSoundLoops );
		missile util::waittill_any("projectile_impact_explode","death");
		self notify( "stop_target_missile_sound");
		self flag::clear("playing_stinger_fired_at_me");
	}
}

//TODO: Add all this back in when UnlockSongByAlias is in with exes
function unlockFrontendMusic(unlockName,allplayers=true)
{
	if( IS_TRUE( allplayers ) )
	{
		if( isdefined(level.players) && level.players.size > 0 )
		{
			foreach( player in level.players )
			{
				player UnlockSongByAlias(unlockName);
			}
		}
	}
	else
	{
		self UnlockSongByAlias(unlockName);
	}
}