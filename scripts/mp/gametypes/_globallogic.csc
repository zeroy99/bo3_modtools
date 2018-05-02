#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\weapons\_hive_gun;
#using scripts\shared\weapons\_weaponobjects;

#insert scripts\mp\gametypes\_globallogic.gsh;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "weapon/fx_hero_annhilatr_death_blood" );
#precache( "client_fx", "weapon/fx_hero_pineapple_death_blood" );

#namespace globallogic;

REGISTER_SYSTEM( "globallogic", &__init__, "visionset_mgr" )

function __init__()
{
	visionset_mgr::register_visionset_info( MPINTRO_VISIONSET_ALIAS, VERSION_SHIP, MPINTRO_VISIONSET_STEPS, undefined, MPINTRO_VISIONSET_NAME );

	//handles actor and  player corpse case
	clientfield::register( "world", "game_ended", VERSION_SHIP, 1, "int", &game_ended, true, true );
	clientfield::register( "world", "post_game", VERSION_SHIP, 1, "int", &post_game, true, true );
	RegisterClientField("playercorpse", "firefly_effect", VERSION_SHIP, 2, "int", &firefly_effect_cb, false);	
	RegisterClientField("playercorpse", "annihilate_effect", VERSION_SHIP, 1, "int", &annihilate_effect_cb, false);	
	RegisterClientField("playercorpse", "pineapplegun_effect", VERSION_SHIP, 1, "int", &pineapplegun_effect_cb, false);	
	RegisterClientField("actor", "annihilate_effect", VERSION_SHIP, 1, "int", &annihilate_effect_cb, false);	
	RegisterClientField("actor", "pineapplegun_effect", VERSION_SHIP, 1, "int", &pineapplegun_effect_cb, false);	

	level._effect[ "annihilate_explosion" ] = "weapon/fx_hero_annhilatr_death_blood";
	level._effect[ "pineapplegun_explosion" ] = "weapon/fx_hero_pineapple_death_blood";
	
	level.gameEnded = false;
	level.postGame = false;
}


function game_ended(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if( newVal && !level.gameEnded )
	{
		level notify("game_ended");
		level.gameEnded = true;
	}
}

function post_game(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if( newVal && !level.postGame )
	{
		level notify("post_game");
		level.postGame = true;
	}
}

function firefly_effect_cb(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if( bNewEnt && newVal)
	{
		self thread hive_gun::gib_corpse( localClientNum, newVal );
	}
}


function annihilate_effect_cb(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{

	if(newVal && !oldVal)
	{
		where = self GetTagOrigin( "J_SpineLower" );
		if (!isdefined(where))
			where = self.origin ;
		where = where + (0,0,-40);
		
		character_index = self GetCharacterBodyType();
		fields = GetCharacterFields( character_index, CurrentSessionMode() );
		if ( fields.fullbodyexplosion != "" )
		{
			if ( util::is_mature() && !util::is_gib_restricted_build() )
			{
				Playfx( localClientNum, fields.fullbodyexplosion, where );
			}
			Playfx( localClientNum, "explosions/fx_exp_grenade_default", where );
		}
	}
}


function pineapplegun_effect_cb(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
       if(newVal && !oldVal)
       {
	       where = self GetTagOrigin( "J_SpineLower" );
	       if (!isdefined(where))
	              where = self.origin;
	
	       if ( IsDefined( level._effect[ "pineapplegun_explosion" ] ) )
	       {
	              Playfx( localClientNum, level._effect["pineapplegun_explosion"], where );
	       }
	       
       }
}

#define PLANT_FIRST_SOUND			.25
#define PLANT_SOUND_INTERVAL		.15
	
function watch_plant_sound( localClientNum )
{
	self endon ( "entityshutdown" );
	
	while( 1 )
	{
		self waittill ( "start_plant_sound" );
		self thread play_plant_sound( localClientNum );
	}
}

function play_plant_sound( localClientNum )
{
	self notify ( "play_plant_sound" );
	self endon ( "play_plant_sound" );
	self endon ( "entityshutdown" );
	self endon ( "stop_plant_sound" );
	
	player = GetLocalPlayer( localClientNum );
	plantWeapon = GetWeapon( "briefcase_bomb" );
	defuseWeapon = GetWeapon( "briefcase_bomb_defuse" );
	
	wait PLANT_FIRST_SOUND;
	
	while( 1 )
	{
		if ( !isdefined( player ) ) // this happens when the player has not initially spawned in
		{
			return;
		}

		if( ( player.weapon != plantWeapon ) && ( player.weapon != defuseWeapon ) )
		{
			return;
		}
		
		if( ( player != self ) || IsThirdPerson( localClientNum ) )
		{
			self PlaySound( localClientNum, "fly_bomb_buttons_npc" );
		}
		
		wait PLANT_SOUND_INTERVAL;
	}
}


