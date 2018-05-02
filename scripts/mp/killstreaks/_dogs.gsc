#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\system_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weapons;
#using scripts\shared\weapons\_weapon_utils;

#insert scripts\shared\shared.gsh;

#using scripts\mp\gametypes\_battlechatter;
#using scripts\mp\gametypes\_dev;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\gametypes\_spawnlogic;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_supplydrop;

#define DOG_MODEL_FRIENDLY			"german_shepherd_vest"
#define DOG_MODEL_ENEMY				"german_shepherd_vest_black"
#define DOG_SPAWN_TIME_DELAY_MIN	2
#define DOG_SPAWN_TIME_DELAY_MAX	5
#define DOG_MAX_DOG_ATTACKERS		2
#define DOG_HEALTH_REGEN_TIME		5

#define DOG_TIME					45
#define DOG_HEALTH					100
#define DOG_COUNT					10
#define DOG_COUNT_MAX_AT_ONCE		5

#precache( "string", "KILLSTREAK_EARNED_DOGS" );
#precache( "string", "KILLSTREAK_DOGS_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_DOGS_INBOUND" );
#precache( "string", "KILLSTREAK_DOGS_HACKED" );
#precache( "eventstring", "mpl_killstreak_dogs" ); 

#namespace dogs;

//Please note, the killstreak init is a separate call below
function init()
{
	level.dog_targets = [];
	level.dog_targets[ level.dog_targets.size ] = "trigger_radius";
	level.dog_targets[ level.dog_targets.size ] = "trigger_multiple";
	level.dog_targets[ level.dog_targets.size ] = "trigger_use_touch";

	level.dog_spawns = [];
	
	level.dogsOnFlashDogs = &flash_dogs;
}

function init_spawns()
{
	spawns = GetNodeArray( "spawn", "script_noteworthy" );

	if ( !IsDefined( spawns ) || !spawns.size )
	{
		/# println( "No dog spawn nodes found in map" ); #/
		return;
	}

	dog_spawner = GetEnt( "dog_spawner", "targetname" );

	if ( !IsDefined( dog_spawner ) )
	{
		/# println( "No dog_spawner entity found in map" ); #/
		return;
	}

	valid = spawnlogic::get_spawnpoint_array( "mp_tdm_spawn" );
	dog = dog_spawner SpawnFromSpawner();

	foreach( spawn in spawns )
	{
		valid = ArraySort( valid, spawn.origin, false );

		for( i = 0; i < 5; i++ )
		{
			if ( dog FindPath( spawn.origin, valid[i].origin, true, false ) )
			{
				level.dog_spawns[ level.dog_spawns.size ] = spawn;
				break;
			}
		}
	}

/#
	if ( !level.dog_spawns.size )
	{
		println( "No dog spawns connect to MP spawn nodes" ); 
	}
#/	
	
	dog delete();
}

function initKillstreak()
{
}

function useKillstreakDogs(hardpointType)
{
	if ( !dog_killstreak_init() )
		return false;

	if ( !self killstreakrules::isKillstreakAllowed( hardpointType, self.team ) )
		return false;

	killstreak_id = self killstreakrules::killstreakStart( "dogs", self.team );

	self thread ownerHadActiveDogs();
	
	if ( killstreak_id == -1 )
		return false;
		
	if ( level.teambased )
	{
		foreach( team in level.teams )
		{
			if ( team == self.team )
				continue;
		}
	}
	
	self killstreaks::play_killstreak_start_dialog( "dogs", self.team, true );
	self AddWeaponStat( GetWeapon( "dogs" ), "used", 1 );

	ownerDeathCount = self.deathCount;

	level thread dog_manager_spawn_dogs( self, ownerDeathCount, killstreak_id );
	level notify( "called_in_the_dogs" );
	return true;
}

function ownerHadActiveDogs()
{
	self endon( "disconnect" );
	self.dogsActive = true;
	self.dogsActiveKillstreak = 0;
	self util::waittill_any( "death", "game_over", "dogs_complete" );
	
	self.dogsActiveKillstreak = 0;
	self.dogsActive = undefined;
}

function dog_killstreak_init()
{
	dog_spawner = GetEnt( "dog_spawner", "targetname" );

	if( !isdefined( dog_spawner ) )
	{
	/#	println( "No dog spawners found in map" );	#/
		return false;
	}

	spawns = GetNodeArray( "spawn", "script_noteworthy" );	

	if ( level.dog_spawns.size <= 0 )
	{
	/#	println( "No dog spawn nodes found in map" );	#/
		return false;
	}

	exits = GetNodeArray( "exit", "script_noteworthy" );	

	if ( exits.size <= 0 )
	{
	/#	println( "No dog exit nodes found in map" );	#/
		return false;
	}

	return true;
}

function dog_set_model()
{
	self SetModel( DOG_MODEL_FRIENDLY );
	self SetEnemyModel( DOG_MODEL_ENEMY );
}

function init_dog()
{
	assert( IsAi( self ) );

	self.targetname = "attack_dog";
	
	self.animTree = "dog.atr";
	self.type = "dog";
	self.accuracy = 0.2;
	self.health = DOG_HEALTH;
	self.maxhealth = DOG_HEALTH;  // this currently does not hook to code maxhealth
	self.secondaryweapon = "";
	self.sidearm = "";
	self.grenadeAmmo = 0;
	self.goalradius = 128;
	self.noDodgeMove = true;
	self.ignoreSuppression = true;
	self.suppressionThreshold = 1;
	self.disableArrivals = false;
	self.pathEnemyFightDist = 512;
	self.soundMod = "dog";

	self thread dog_health_regen();
	self thread selfDefenseChallenge();
}

function get_spawn_node( owner, team )
{
	assert( level.dog_spawns.size > 0 );
	return array::random( level.dog_spawns );
}

function get_score_for_spawn( origin, team )
{
	players = GetPlayers();
	score = 0;

	foreach( player in players )
	{
		if ( !isdefined( player ) )
		{
			continue;
		}

		if ( !IsAlive( player ) )
		{
			continue;
		}

		if ( player.sessionstate != "playing" )
		{
			continue;
		}

		if ( DistanceSquared( player.origin, origin ) > 2048 * 2048 )
		{
			continue;
		}

		if ( player.team == team )
		{
			score++;
		}
		else
		{
			score--;
		}
	}

	return score;
}

function dog_set_owner( owner, team, requiredDeathCount )
{
	self SetEntityOwner( owner );
	self.team = team;

	self.requiredDeathCount = requiredDeathCount;
}

function dog_create_spawn_influencer( team )
{
	self spawning::create_entity_enemy_influencer( "dog", team );
}

function dog_manager_spawn_dog( owner, team, spawn_node, requiredDeathCount )
{
	dog_spawner = GetEnt( "dog_spawner", "targetname" );
	
	dog = dog_spawner SpawnFromSpawner();
	dog ForceTeleport( spawn_node.origin, spawn_node.angles );
	
	dog init_dog();
	dog dog_set_owner( owner, team, requiredDeathCount );
	dog dog_set_model();
	dog dog_create_spawn_influencer( team );
	
	dog thread dog_owner_kills();
	dog thread dog_notify_level_on_death();
	dog thread dog_patrol();
	dog thread monitor_dog_special_grenades();

	return dog;
}


function monitor_dog_special_grenades() // self == dog
{
	// watch and see if the dog gets damage from a flash or concussion
	//	smoke and tabun handle themselves
	self endon("death");

	while(1)
	{
		self waittill( "damage", damage, attacker, direction_vec, point, type, modelName, tagName, partName, weapon, iDFlags );

		if( weapon_utils::isFlashOrStunWeapon( weapon ) )
		{
			damage_area = spawn( "trigger_radius", self.origin, 0, 128, 128 );
			attacker thread dogs::flash_dogs( damage_area );
			WAIT_SERVER_FRAME;
			damage_area delete();
		}
	}
}


function dog_manager_spawn_dogs( owner, deathCount, killstreak_id )
{
	requiredDeathCount = deathCount;
	team = owner.team;
	
	level.dog_abort = false;
	owner thread dog_manager_abort();
	level thread dog_manager_game_ended();

	for ( count = 0; count < DOG_COUNT; )
	{
		if ( level.dog_abort )
		{
			break;
		}

		dogs = dog_manager_get_dogs();

		while ( dogs.size < DOG_COUNT_MAX_AT_ONCE && count < DOG_COUNT && !level.dog_abort )
		{
			node = get_spawn_node( owner, team );
			level dog_manager_spawn_dog( owner, team, node, requiredDeathCount );
			count++;

			wait ( randomfloatrange( DOG_SPAWN_TIME_DELAY_MIN, DOG_SPAWN_TIME_DELAY_MAX ) );
			dogs = dog_manager_get_dogs();
		}

		level waittill( "dog_died" );
	}

	for ( ;; )
	{
		dogs = dog_manager_get_dogs();

		if ( dogs.size <= 0 )
		{
			killstreakrules::killstreakStop( "dogs", team, killstreak_id );
			if ( isdefined( owner ) )
			{
				owner notify( "dogs_complete" );
			}
			return;
		}

		level waittill( "dog_died" );
	}
}

function dog_abort()
{
	level.dog_abort = true;

	dogs = dog_manager_get_dogs();

	foreach( dog in dogs )
	{
		dog notify( "abort" );
	}
	
	level notify( "dog_abort" );
}

function dog_manager_abort()
{
	level endon( "dog_abort" );
	self util::wait_endon( DOG_TIME, "disconnect", "joined_team", "joined_spectators" );
	dog_abort();
}

function dog_manager_game_ended()
{
	level endon( "dog_abort" );

	level waittill( "game_ended" );
	dog_abort();
}

function dog_notify_level_on_death()
{
	self waittill( "death" );
	level notify( "dog_died" );
}

function dog_leave()
{
	// have them run to an exit node
	self clearentitytarget();
	self.ignoreall = true;
	self.goalradius = 30;
	self SetGoal( self dog_get_exit_node() );
	
	self util::wait_endon( 20, "goal", "bad_path" );
	self delete();
}

function dog_patrol()
{
	self endon( "death" );

	for ( ;; )
	{
		if ( level.dog_abort )
		{
			self dog_leave();
			return;
		}

		if ( isdefined( self.enemy ) )
		{
			wait( RandomIntRange( 3, 5 ) );
			continue;
		}

		nodes = [];

		objectives = dog_patrol_near_objective();

		for ( i = 0; i < objectives.size; i++ )
		{
			objective = array::random( objectives );

			nodes = GetNodesInRadius( objective.origin, 256, 64, 512, "Path", 16 );

			if ( nodes.size )
			{
				break;
			}
		}
		
		if ( !nodes.size )
		{
			player = self dog_patrol_near_enemy();

			if ( isdefined( player ) )
			{
				nodes = GetNodesInRadius( player.origin, 1024, 0, 128, "Path", 8 );
			}
		}

		if ( !nodes.size && isdefined( self.script_owner ) )
		{
			if ( IsAlive( self.script_owner ) && self.script_owner.sessionstate == "playing" )
			{
				nodes = GetNodesInRadius( self.script_owner.origin, 512, 256, 512, "Path", 16 );
			}
		}

		if ( !nodes.size )
		{
			nodes = GetNodesInRadius( self.origin, 1024, 512, 512, "Path" );
		}

		if ( nodes.size )
		{
			nodes = array::randomize( nodes );

			foreach( node in nodes )
			{
				if ( isdefined( node.script_noteworthy ) )
				{
					continue;
				}

				if ( isdefined( node.dog_claimed ) && IsAlive( node.dog_claimed ) )
				{
					continue;
				}

				self SetGoal( node );
				node.dog_claimed = self;

				nodes = [];
				event = self util::waittill_any_return( "goal", "bad_path", "enemy", "abort" );

				if ( event == "goal" )
				{
					util::wait_endon( RandomIntRange( 3, 5 ), "damage", "enemy", "abort" );
				}

				node.dog_claimed = undefined;
				break;
			}
		}

		wait( 0.5 );
	}
}

function dog_patrol_near_objective()
{
	if ( !isdefined( level.dog_objectives ) )
	{
		level.dog_objectives = [];
		level.dog_objective_next_update = 0;
	}

	if ( level.gameType == "tdm" || level.gameType == "dm" )
	{
		return level.dog_objectives;
	}
	
	if ( GetTime() >= level.dog_objective_next_update )
	{
		level.dog_objectives = [];

		foreach( target in level.dog_targets )
		{
			ents = GetEntArray( target, "classname" );

			foreach( ent in ents )
			{
				if ( level.gameType == "koth" )
				{
					if ( isdefined( ent.targetname ) && ent.targetname == "radiotrigger" )
					{
						level.dog_objectives[ level.dog_objectives.size ] = ent;
					}

					continue;
				}

				if ( level.gameType == "sd" )
				{
					if ( isdefined( ent.targetname ) && ent.targetname == "bombzone" )
					{
						level.dog_objectives[ level.dog_objectives.size ] = ent;
					}

					continue;
				}

				if ( !isdefined( ent.script_gameobjectname ) )
				{
					continue;
				}

				if ( !IsSubStr( ent.script_gameobjectname, level.gameType ) )
				{
					continue;
				}

				level.dog_objectives[ level.dog_objectives.size ] = ent;
			}
		}

		level.dog_objective_next_update = GetTime() + RandomIntRange( 5000, 10000 );
	}

	return level.dog_objectives;
}

function dog_patrol_near_enemy()
{
	players = GetPlayers();
	
	closest = undefined;
	distSq = 99999999;
	
	foreach( player in players )
	{
		if ( !isdefined( player ) )
		{
			continue;
		}

		if ( !IsAlive( player ) )
		{
			continue;
		}

		if ( player.sessionstate != "playing" )
		{
			continue;
		}

		if ( isdefined( self.script_owner ) && player == self.script_owner )
		{
			continue;
		}

		if ( level.teambased )
		{
			if ( player.team == self.team )
			{
				continue;
			}
		}

		if ( GetTime() - player.lastFireTime > 3000 )
		{
			continue;
		}

		if ( !isdefined( closest ) )
		{
			closest = player;
			distSq = DistanceSquared( self.origin, player.origin );
			continue;
		}

		d = DistanceSquared( self.origin, player.origin );

		if ( d < distSq )
		{
			closest = player;
			distSq = d;
		}
	}

	return closest;
}

function dog_manager_get_dogs()
{
	dogs = GetEntArray( "attack_dog", "targetname" );
	return dogs;
}

function dog_owner_kills()
{
	if ( !isdefined( self.script_owner ) )
		return;
		
	self endon("clear_owner");
	self endon("death");
	self.script_owner endon("disconnect");
	
	while(1)
	{
		self waittill("killed", player);
		self.script_owner notify( "dog_handler" );
	}	
}

function dog_health_regen()
{
	self endon( "death" );

	interval = 0.5;
	regen_interval = Int( ( self.health / DOG_HEALTH_REGEN_TIME ) * interval );
	regen_start = 2;

	for ( ;; )
	{
		self waittill( "damage", damage, attacker, direction, point, type, tagName, modelName, partname, weapon, iDFlags );
		self trackAttackerDamage( attacker );
		
		self thread dog_health_regen_think( regen_start, interval, regen_interval );
	}
}

function trackAttackerDamage( attacker )
{
	if ( !isdefined( attacker ) || !isPlayer( attacker ) || !isdefined( self.script_owner ) )
	{
		return;
	}
	
	if ( ( level.teambased && attacker.team == self.script_owner.team ) || attacker == self ) 
	{
		return;
	}

	if ( !isdefined( self.attackerData ) || !isdefined( self.attackers ) ) 
	{
		self.attackerData = [];
		self.attackers = [];
	}
	if ( !isdefined( self.attackerData[attacker.clientid] ) )
	{
		self.attackerClientID[attacker.clientid] = spawnstruct();
		self.attackers[ self.attackers.size ] = attacker;
	}
}

function resetAttackerDamage()
{
	self.attackerData = [];
	self.attackers = [];
}

function dog_health_regen_think( delay, interval, regen_interval )
{
	self endon( "death" );
	self endon( "damage" );

	wait( delay );

	for ( step = 0; step <= DOG_HEALTH_REGEN_TIME; step += interval )
	{
		if ( self.health >= DOG_HEALTH )
		{
			break;
		}

		self.health += regen_interval;
		wait( interval );
	}

	self resetAttackerDamage();
	self.health = DOG_HEALTH;
}

function selfDefenseChallenge()
{
	self waittill ("death", attacker);

	if ( isdefined( attacker ) && isPlayer( attacker ) )
	{
		if (isdefined ( self.script_owner ) && self.script_owner == attacker)
			return;
		if ( level.teambased && isdefined ( self.script_owner ) && self.script_owner.team == attacker.team )
			return;

		if ( isdefined( self.attackers ) )
		{
			foreach ( player in self.attackers )
			{
				if ( player != attacker )
				{
					scoreevents::processScoreEvent( "killed_dog_assist", player );
				}
			}
		}
		attacker notify ("selfdefense_dog");	
	}
		
}

function dog_get_exit_node()
{
	exits = GetNodeArray( "exit", "script_noteworthy" );
	return ArrayGetClosest( self.origin, exits );
}

function flash_dogs( area )
{
	self endon("disconnect");

	dogs = dog_manager_get_dogs();

	foreach( dog in dogs )
	{
		if ( !isalive(dog) )
			continue;

		if ( dog istouching(area) )
		{
			do_flash = true;
			if ( isPlayer( self ) )
			{
				if ( level.teamBased && (dog.team == self.team) )
				{
					do_flash = false;
				}
				else if ( !level.teambased && isdefined(dog.script_owner) && self == dog.script_owner )
				{
					do_flash = false;
				}
			}

			if ( isdefined( dog.lastFlashed ) && dog.lastFlashed + 1500 > gettime()  )
			{	
				do_flash = false;
			}

			if ( do_flash )
			{
				dog setFlashBanged( true, 500 );
				dog.lastFlashed = gettime();
			}
		}	
	}
}

