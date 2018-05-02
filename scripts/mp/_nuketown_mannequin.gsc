#using scripts\shared\ai_shared;
#using scripts\shared\ai\archetype_mannequin;
#using scripts\shared\music_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#define NUKETOWN_SPAWN_MANNEQUIN_FX							"dlc0/nuketown/fx_de_rez_man_spawn"

#precache( "fx", NUKETOWN_SPAWN_MANNEQUIN_FX );

#namespace NuketownMannequin;

function SpawnMannequin( origin, angles, gender = "male", speed = undefined, weepingAngel )
{
	if(!IsDefined ( level.mannequinspawn_music))
	{
		level.mannequinspawn_music = 1;
		music::setmusicstate( "mann" );		
	}
	
	if ( gender == "male" )
	{
		mannequin = SpawnActor( "spawner_bo3_mannequin_male", origin, angles, "", true, true );
	}
	else
	{
		mannequin = SpawnActor( "spawner_bo3_mannequin_female", origin, angles, "", true, true );
	}
	
	// Select an initial speed.
	rand = RandomInt( 100 );
	
	if( rand <= 35 )
	{
		mannequin.zombie_move_speed = "walk";
	}
	else if( rand <= 70 )
	{
		mannequin.zombie_move_speed = "run";
	}
	else
	{	
		mannequin.zombie_move_speed = "sprint";
	}
	
	if ( IsDefined( speed ) )
	{
		mannequin.zombie_move_speed = speed;
	}
	
	if( IsDefined( level.zm_variant_type_max ) )
	{
		// Don't select variant 0 since those animations don't have proper footstep notetracks.
		mannequin.variant_type = RandomIntRange( 1, level.zm_variant_type_max[ mannequin.zombie_move_speed ][ mannequin.zombie_arms_position ] );
	}
	
	mannequin ai::set_behavior_attribute( "can_juke", true );
	mannequin ASMSetAnimationRate( RandomFloatRange( 0.98, 1.02 ) );  // Slightly vary animation playback.
	mannequin.holdFire = true;  // No firing, performance gain
	
	// sjakatdar (10/24/2015) - Disabling the optimization for updating the sight. It will prevent ais from picking up 
	// new enemy. To be able to use this optimization, the script has to explicitly set favorite enemy, which is not being done
	// for mannequins. Fixes DT#139243.
	//mannequin.updateSight = false;  // No sight update 
	
	mannequin.canStumble = true;
	mannequin.should_turn = true;
	mannequin thread watch_game_ended();
	mannequin.team = "free";
	mannequin.overrideActorDamage = &mannequinDamage;  // prevent mannequins from deal accidental melee damage to each other.
	
	mannequins = GetAIArchetypeArray( "mannequin" );
	
	foreach ( otherMannequin in mannequins )
	{
		if ( otherMannequin.archetype == "mannequin" )
		{
			otherMannequin SetIgnoreEnt( mannequin, true );
			mannequin SetIgnoreEnt( otherMannequin, true );
		}
	}
	
	if( weepingAngel )
	{
		mannequin thread _mannequin_unfreeze_ragdoll();
		mannequin.is_looking_at_me = true;
		mannequin.was_looking_at_me = false;
		mannequin _mannequin_update_freeze( mannequin.is_looking_at_me );
	}
	
	PlayFx( NUKETOWN_SPAWN_MANNEQUIN_FX, mannequin.origin, AnglesToForward( mannequin.angles ) );
	       
	return mannequin;
}

function mannequinDamage( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if ( IsDefined( inflictor ) && IsActor( inflictor ) && inflictor.archetype == "mannequin" )
	{
		return 0;
	}
	
	return damage;
}

function private watch_game_ended()
{
	self endon ( "death" );
	
	level waittill ( "game_ended" );
	
	self SetEntityPaused( true );
	
	level waittill ( "endgame_sequence" );
	
	self Hide();
}

function private _mannequin_unfreeze_ragdoll()
{
	self waittill( "death" );
	
	if ( IsDefined( self ) )
	{
		self SetEntityPaused( false );
		
		if ( !self IsRagdoll() )
		{
			self StartRagdoll();
		}
	}
}

function private _mannequin_update_freeze( frozen )
{
	self.is_looking_at_me = frozen;
	
	if( self.is_looking_at_me && !self.was_looking_at_me )
	{
		self SetEntityPaused( true );
	}
	else if( !self.is_looking_at_me && self.was_looking_at_me )
	{
		self SetEntityPaused( false );
	}
	
	self.was_looking_at_me = self.is_looking_at_me;
}

function watch_player_looking()
{
	level endon ( "game_ended" );
	level endon ( "mannequin_force_cleanup" );
	
	while( 1 )
	{
		mannequins = GetAIArchetypeArray( "mannequin" );
		foreach( mannequin in mannequins )
		{
			mannequin.can_player_see_me = true;
		}
		
		players = GetPlayers();
		
		unseenMannequins = mannequins;
		foreach( player in players )
		{
			unseenMannequins = player CantSeeEntities( unseenMannequins, .67, false );
		}
		
		foreach( mannequin in unseenMannequins )
		{
			mannequin.can_player_see_me = false;
		}
		
		foreach( mannequin in mannequins )
		{
			mannequin _mannequin_update_freeze( mannequin.can_player_see_me );
		}
		
		WAIT_SERVER_FRAME;
	}
}

