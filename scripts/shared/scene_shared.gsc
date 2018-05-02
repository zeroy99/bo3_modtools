/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// http://tawiki/display/Design/Scene+System /////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\player_shared;
#using scripts\shared\scene_debug_shared;
#using scripts\shared\scriptbundle_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\util_shared;
#using scripts\shared\lui_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "lui_menu", "CPSkipSceneMenu" );
#precache( "lui_menu_data", "showSkipButton" );
#precache( "lui_menu_data", "hostIsSkipping" );
#precache( "lui_menu_data", "sceneSkipEndTime" );

#namespace scene;

#using_animtree( "all_player" );
function private prepare_player_model_anim( ent )
{
	if ( !IS_EQUAL( ent.animtree, "all_player" ) )
	{
		ent UseAnimTree( #animtree );
		ent.animtree = "all_player";
	}
}

#using_animtree( "generic" );
function private prepare_generic_model_anim( ent )
{
	if ( !IS_EQUAL( ent.animtree, "generic" ) )
	{
		ent UseAnimTree( #animtree );
		ent.animtree = "generic";
	}
}

#define TEST_SCENES array()

#define NEW_STATE(__state) flagsys::clear( "ready" );\
	flagsys::clear( "done" );\
	flagsys::clear( "main_done" );\
	_str_state = __state;\
	self notify( "new_state" );\
	self endon( "new_state" );\
	self notify(__state);\
	log( __state );\
	waittillframeend;
	
#define DAMAGE_STR(dmg) ( !isdefined( dmg ) || dmg == "none" ? "" : dmg )
	
// Player weapon animation indexes defined in code
#define WEAP_RAISE 30
#define WEAP_FIRST_RAISE 31
	
#define DEFAULT_ACTOR_WEAPON GetWeapon( "ar_standard" )

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  ___    ___   ___   _  _   ___      ___    ___      _   ___    ___   _____ 
// / __|  / __| | __| | \| | | __|    / _ \  | _ )  _ | | | __|  / __| |_   _|
// \__ \ | (__  | _|  | .` | | _|    | (_) | | _ \ | || | | _|  | (__    | |  
// |___/  \___| |___| |_|\_| |___|    \___/  |___/  \__/  |___|  \___|   |_|  
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class cSceneObject : cScriptBundleObjectBase
{
	var _b_spawnonce_used;
	var _is_valid;
	var _str_name; 
	var _str_state;
	var _player;
	var _str_death_anim;
	var _str_death_anim_loop;
	var _b_set_goal;
	
	constructor()
	{
		_is_valid = true;
		_b_spawnonce_used = false;
		_b_set_goal = true;
	}
	
	destructor()
	{
	}
	
	function first_init( s_objdef, o_scene, e_ent )
	{
		cScriptBundleObjectBase::init( s_objdef, o_scene, e_ent );
			
		_assign_unique_name();
						
		return self;
	}
	
	function initialize( b_force_first_frame = false )
	{
		if ( has_init_state() || b_force_first_frame )
		{
			NEW_STATE( "init" );
			
			//Exclude the player since now need to spawn or init him.
			if ( ( !IS_TRUE(_s.sharedIGC) && !IS_TRUE(_s.player) ) && IS_TRUE( _s.spawnoninit ) || b_force_first_frame )
			{
				_spawn( undefined, IS_TRUE( _s.firstframe ) || isdefined( _s.initanim ) || isdefined( _s.initanimloop ) );
			}
			
			if ( IS_TRUE( _s.firstframe ) || b_force_first_frame )
			{
				if ( !error( !isdefined( _s.mainanim ), "No animation defined for first frame." ) )
				{
					_str_death_anim = _s.mainanimdeath;
					_str_death_anim_loop = _s.mainanimdeathloop;
					
					_play_anim( _s.mainanim, 0, 0, 0 );
				}
			}
			else if ( isdefined( _s.initanim ) )
			{
				_str_death_anim = _s.initanimdeath;
				_str_death_anim_loop = _s.initanimdeathloop;
				
				_play_anim( _s.initanim, _s.initdelaymin, _s.initdelaymax, 1 );
				
				if ( is_alive() )
				{
					if ( isdefined( _s.initanimloop ) )
					{
						_str_death_anim = _s.initanimloopdeath;
						_str_death_anim_loop = _s.initanimloopdeathloop;
						
						_play_anim( _s.initanimloop, 0, 0, 1 );
					}
				}
			}
			else if ( isdefined( _s.initanimloop ) )
			{
				_str_death_anim = _s.initanimloopdeath;
				_str_death_anim_loop = _s.initanimloopdeathloop;
				
				_play_anim( _s.initanimloop, _s.initdelaymin, _s.initdelaymax, 1 );
			}
		}
		else
		{
			flagsys::set( "ready" );
		}
		
		if ( !_is_valid )
		{
			flagsys::set( "done" );
		}
	}
	
	function play()
	{
		NEW_STATE( "play" );
		
		if( IS_TRUE(_s.hide) && _is_valid )
		{
			_spawn( undefined, false, false );
			_e Hide();
		}
		else if ( isdefined( _s.mainanim ) && _is_valid )
		{
			_str_death_anim = _s.mainanimdeath;
			_str_death_anim_loop = _s.mainanimdeathloop;

			//if it is a starting of a scene and no value is provided, do a default 0.2 animation blend.
			if ( !IS_TRUE( _s.IsCutScene ) ) 
			{
				if( !isdefined( _s.MainBlend ) || _s.MainBlend == 0 )
				{
					_s.mainblend = 0.2;
				}
				else if(_s.MainBlend == 0.001) //MALI - A hack to enable 0 blending between cuts, this should be removed once we ship TU5 and _s.MainBlend = 0 should mean 0 not 0.2.
				{
					_s.MainBlend = 0;
				}
			}
			
			_play_anim( _s.mainanim, _s.maindelaymin, _s.maindelaymax, 1, _s.mainblend, _o_bundle.n_start_time );
			
			flagsys::set( "main_done" );
			
			if ( isdefined( _e ) && IS_TRUE( _s.DynamicPaths ) )
			{
				if ( Distance2DSquared( _e.origin, _e.scene_orig_origin ) > 4 )
				{
					_e DisconnectPaths( 2, false );
				}
			}
			
			if ( is_alive() )
			{
				if ( !isdefined( _s.EndBlend ) || _s.EndBlend == 0 )
				{
					_s.EndBlend = 0.2;
				}
			
				if ( isdefined( _s.endanim ) )
				{
					_str_death_anim = _s.endanimdeath;
					_str_death_anim_loop = _s.endanimdeathloop;
					
					_play_anim( _s.endanim, 0, 0, 1, _s.EndBlend );
					
					if ( is_alive() )
					{
						if ( isdefined( _s.endanimloop ) )
						{
							_str_death_anim = _s.endanimloopdeath;
							_str_death_anim_loop = _s.endanimloopdeathloop;
							
							_play_anim( _s.endanimloop, 0, 0, 1 );
						}
					}
				}
				else if ( isdefined( _s.endanimloop ) )
				{
					_str_death_anim = _s.endanimloopdeath;
					_str_death_anim_loop = _s.endanimloopdeathloop;
					
					_play_anim( _s.endanimloop, 0, 0, 1 );
				}
			}
		}
		
		thread finish();
	}
	
	function stop( b_clear = false, b_dont_clear_anim = false, b_finished = false )
	{
		if ( IsAlive( _e ) )
		{
			if ( is_shared_player() )
			{
				foreach ( player in level.players )
				{
					player StopAnimScripted( .2 );
				}
			}
			else if ( !IS_TRUE( _s.DieWhenFinished ) || !b_finished )
			{
				if ( !b_dont_clear_anim || IsPlayer( _e ) )
				{
					_e StopAnimScripted( .2 );
				}
			}
		}
		
		finish( b_clear, !b_finished );
	}
	
	function get_align_ent()
	{
		e_align = undefined;
		
		if ( isdefined( _s.aligntarget ) && !IS_EQUAL( _s.aligntarget, _o_bundle._s.aligntarget ) )
		{
			a_scene_ents = [[_o_bundle]]->get_ents();
			if ( isdefined( a_scene_ents[ _s.aligntarget ] ) )
			{
				e_align = a_scene_ents[ _s.aligntarget ];
			}
			else
			{
				e_align = scene::get_existing_ent( _s.aligntarget, false, true );
			}
			
			if ( !isdefined( e_align ) )
			{
				str_msg = "Align target '" + STR( _s.aligntarget ) + "' doesn't exist for scene object.";
				
				if ( !warning( _o_bundle._testing, str_msg ) )
				{
					error( GetDvarInt( "scene_align_errors", 1 ), str_msg );
				}
			}
		}
		
		if ( !isdefined( e_align ) )
		{
			e_align = [[scene()]]->get_align_ent();
		}
		
		return e_align;
	}
	
	function get_align_tag()
	{
		if ( isdefined( _s.AlignTargetTag ) )
		{
			return _s.AlignTargetTag;
		}
		else
		{
			if ( isdefined( _o_bundle._e_root.e_scene_link ) )
			{
				return "tag_origin";
			}
			else
			{
				return _o_bundle._s.AlignTargetTag;
			}
		}
	}
	
	/* Scene Helpers */
	
	function scene()
	{
		return _o_bundle;
	}
		
	/* internal functions */
	
	function _on_damage_run_scene_thread()
	{
		self endon( "play" );
		self endon( "done" );
		
		str_damage_types = DAMAGE_STR( _s.runsceneondmg0 ) + DAMAGE_STR( _s.runsceneondmg1 ) + DAMAGE_STR( _s.runsceneondmg2 ) + DAMAGE_STR( _s.runsceneondmg3 ) + DAMAGE_STR( _s.runsceneondmg4 );
		
		if ( str_damage_types != "" )
		{			
			b_run_scene = false;
			
			while ( !b_run_scene )
			{
				_e waittill( "damage", n_amount, e_attacker, v_org, v_dir, str_mod );
				
				switch ( str_mod )
				{
					case "MOD_PISTOL_BULLET":
					case "MOD_RIFLE_BULLET":
						
						if ( IsSubStr( str_damage_types, "bullet" ) )
						{
							b_run_scene = true;
						}
						
						break;
					
					case "MOD_GRENADE":
					case "MOD_GRENADE_SPLASH":
					case "MOD_EXPLOSIVE":
						
						if ( IsSubStr( str_damage_types, "explosive" ) )
						{
							b_run_scene = true;
						}
						
						break;
						
					case "MOD_PROJECTILE":
					case "MOD_PROJECTILE_SPLASH":
						
						if ( IsSubStr( str_damage_types, "projectile" ) )
						{
							b_run_scene = true;
						}
						
						break;
						
					case "MOD_MELEE":
						
						if ( IsSubStr( str_damage_types, "melee" ) )
						{
							b_run_scene = true;
						}
						
						break;
						
					default:
						
						if ( IsSubStr( str_damage_types, "all" ) )
						{
							b_run_scene = true;
						}
				}
			}
			
			thread [[scene()]]->play();
		}
	}
		
	function _assign_unique_name()
	{
		if ( is_player() )
		{
			_str_name = "player " + _s.player;
		}
		else
		{
			if ( [[scene()]]->allows_multiple() )
			{
				if ( isdefined( _s.name ) )
				{
					_str_name = _s.name + "_gen" + level.scene_object_id;
				}
				else
				{
					_str_name = [[scene()]]->get_name() + "_noname" + level.scene_object_id;
				}
				
				level.scene_object_id++;
			}
			else
			{
				if ( isdefined( _s.name ) )
				{
					_str_name = _s.name;
				}
				else
				{
					_str_name = [[scene()]]->get_name() + "_noname" + [[scene()]]->get_object_id();
				}
			}
		}
	}
	
	function get_name()
	{
		return _str_name;
	}
	
	function get_orig_name()
	{
		return _s.name;
	}
	
	function _spawn( e_spawner,  b_hide = true, b_set_ready_when_spawned = true )
	{
		if ( isdefined( e_spawner ) )
		{
			_e = e_spawner;
		}
		
		if ( isdefined( _e ) && IS_TRUE( _e.isDying ) )
		{
			_e Delete(); // previous ent is marked for cleanup, do it now so it doesn't delete a frame later when we don't want it to
		}
		
		if ( is_player() )
		{
			if ( IsPlayer( _e ) )
			{
				_player = _e;
			}
			else
			{
				n_player = GetDvarInt( "scene_debug_player", 0 );
				if ( n_player > 0 )
				{
					n_player--;
					
					if ( n_player == _s.player )
					{
						_player = level.activeplayers[ 0 ];
					}
				}
				else
				{
					_player = level.activeplayers[ _s.player ];
				}
			}
		}
		
		b_skip = IS_EQUAL( _s.type, "actor" ) && IsSubStr( _o_bundle._str_mode, "noai" );
		b_skip = b_skip || ( IS_EQUAL( _s.type, "player" ) && IsSubStr( _o_bundle._str_mode, "noplayers" ) );
		
		if(!b_skip && _should_skip_entity())
		{
			b_skip = true;
		}
		
		if ( !b_skip )
		{		
			if ( !isdefined( _e ) && is_player() && IS_TRUE( _s.newplayermethod ) )
			{
				_e = _player;
			}
			else if ( !isdefined( _e ) || IsSpawner( _e ) )
			{
				b_allows_multiple = [[scene()]]->allows_multiple();
				
				if ( /*error( !b_allows_multiple && !isdefined( _s.name ), "Scene that don't allow multiple instances must specify a name for all objects." )
				    || */error( b_allows_multiple && IS_TRUE( _s.nospawn ), "Scene that allow multiple instances must be allowed to spawn (uncheck 'Do Not Spawn')." ) )
				{
					return;
				}
				
				if ( !IsSpawner( _e ) )
				{
					e = scene::get_existing_ent( _str_name, b_allows_multiple );
					
					if ( !isdefined( e ) && isdefined( _s.name ) )
					{
						e = scene::get_existing_ent( _s.name, b_allows_multiple );
					}
					
					if ( IsPlayer( e ) )
					{
						if ( !IS_TRUE( _s.newplayermethod ) )
						{
							e = undefined;
						}
					}
					
					if ( ( !isdefined( e ) || IsSpawner( e ) ) && ( ( !IS_TRUE( _s.nospawn ) && !_b_spawnonce_used ) || _o_bundle._testing ) )
					{
						e_spawned = spawn_ent( e );
					}
				}
				else
				{
					e_spawned = spawn_ent( _e );
				}
				
				if ( isdefined( e_spawned ) )
				{
					if ( b_hide && !_o_bundle._s scene::is_igc() )
					{
						e_spawned Hide(); // Hide teleporting glitches and for any delay set on this object
					}
					
					e_spawned DontInterpolate();
					
					e_spawned.scene_spawned = _o_bundle._s.name;
	
					if ( !isdefined( e_spawned.targetname ) )
					{
						e_spawned.targetname = _s.name;
					}
					
					if ( is_player() )
					{
						e_spawned Hide();
					}
				}
				
				_e = ( isdefined( e_spawned ) ? e_spawned : e );
				
				if ( IS_TRUE( _s.spawnonce ) && _b_spawnonce_used )
				{
					 return;
				}
			}
			
			error( !is_player() && !IS_TRUE( _s.nospawn ) && ( !isdefined( _e ) || IsSpawner( _e ) ), "Object failed to spawn or doesn't exist." );
		}
		
		if ( isdefined( _e ) && !IsSpawner( _e ) )
		{
			[[self]]->_prepare();
			
			if ( b_set_ready_when_spawned )
			{
				flagsys::set( "ready" );
			}
			
			if ( IS_TRUE( _s.spawnonce ) )
			{
				_b_spawnonce_used = true;
			}
		}
		else
		{
			flagsys::set( "ready" );
			flagsys::set( "done" );
			finish();
		}
	}
	
	function _prepare()
	{
		if ( IS_TRUE( _s.DynamicPaths ) && ( _str_state == "play" ) )
		{
			_e.scene_orig_origin = _e.origin;
			_e ConnectPaths();
		}
		
		if ( IS_EQUAL( _e.current_scene, _o_bundle._str_name ) )
		{
			//Since we do not fire the "scene_sequence_started" on init state, we need to do so here.
			[[_o_bundle]]->trigger_scene_sequence_started( self, _e );
			
			return false; // already prepared this entity for this scene
		}
		
		_e endon( "death" );

		if ( !IS_TRUE( _s.IgnoreAliveCheck ) && error( IsAI( _e ) && !IsAlive( _e ), "Trying to play a scene on a dead AI." ) )
		{
			return;
		}
		
		// cleanup any current/previous scenes
		if ( isdefined( _e._o_scene ) )
        {
            foreach ( obj in _e._o_scene._a_objects )
            {
                if ( obj._e === _e )
                {
                    [[ obj ]]->finish();
                    break;
                }
            }
        }
		
		if ( !IsAI( _e ) && !IsPlayer( _e ) )
		{
			if ( !is_player() || !IS_TRUE( _s.newplayermethod ) )
			{
				if ( is_player_model() )
				{
					scene::prepare_player_model_anim( _e );
				}
				else
				{
					scene::prepare_generic_model_anim( _e );
				}
			}
		}
		
		if ( !is_player() )
		{
			if ( !isdefined( _e._scene_old_takedamage ) )
			{
				_e._scene_old_takedamage = _e.takedamage;
			}
			
			if ( IsSentient( _e ) )
			{
				// For sentients, don't override if damage/death is turned off
				_e.takedamage = IS_TRUE( _e.takedamage ) && IS_TRUE( _s.takedamage );
				
				if ( !IS_TRUE( _e.magic_bullet_shield ) )
				{
					_e.allowdeath = IS_TRUE( _s.allowdeath );
				}
				
				if ( IS_TRUE( _s.OverrideAICharacter ) )
				{
					_e DetachAll();
					_e SetModel( _s.model );
				}
			}
			else
			{
				_e.health = ( _e.health > 0 ? _e.health : 1 );
				
				if ( _s.type === "actor" )	// Drone
				{
					_e MakeFakeAI();
					
					if ( !IS_TRUE( _s.RemoveWeapon ) )
					{
						_e animation::attach_weapon( DEFAULT_ACTOR_WEAPON );
						// TODO: see if we can get the weapon from the aitype if using one for the character model
					}
				}
				
				_e.takedamage = IS_TRUE( _s.takedamage );
				_e.allowdeath = IS_TRUE( _s.allowdeath );
			}
			
			set_objective();
			
			if ( IS_TRUE( _s.DynamicPaths ) )
			{
				_e DisconnectPaths( 2, false );
			}
		}
		else if ( !is_shared_player() )
		{
			player = ( IsPlayer( _player ) ? _player : _e );
			
			_prepare_player( player );
		}
		
		if ( IS_TRUE( _s.RemoveWeapon ) )
		{
			if ( !IS_TRUE( _e.gun_removed ) )
			{
				if ( IsPlayer( _e ) )
				{
					_e player::take_weapons();
				}
				else
				{
					_e animation::detach_weapon();
				}
			}
			else
			{
				_e._scene_old_gun_removed = true;
			}
		}
		
		// TODO: refactor all of this stuff so it can be set/cleared on all players in a shared animation
		
		_e.animname = _str_name;
		_e.anim_debug_name = _s.name;
				
		_e flagsys::set( "scene" );
		_e flagsys::set( _o_bundle._str_name );
		_e.current_scene = _o_bundle._str_name;
		_e.finished_scene = undefined;
		_e._o_scene = scene();
		
		//only shared IGC can skip the scene if it is just started
		[[_o_bundle]]->trigger_scene_sequence_started( self, _e );
		
		if ( IS_TRUE( _e.takedamage ) )
		{
			thread _on_damage_run_scene_thread();
			thread _on_death();
		}
		
		if ( IsActor( _e ) )
		{
			thread _track_goal();
			
			if ( IS_TRUE( _s.LookAtPlayer ) )
			{
				_e LookAtEntity( level.activeplayers[0] );
			}
		}
		
		if ( _o_bundle._s scene::is_igc() || [[ _o_bundle ]]->has_player() )
		{
			if ( !IsPlayer( _e ) )  // players handled in _prepare_player
			{
				_e SetHighDetail( true );
			}
		}
		
		return true;
	}
	
	function _prepare_player( player )
	{
		if ( IS_TRUE( player.play_scene_transition_effect ) )
		{
			player.play_scene_transition_effect = undefined;			
			play_regroup_fx_for_scene( player );
		}

		if ( IS_EQUAL( player.current_player_scene, _o_bundle._str_name ) )
		{
			//Since we do not fire the "scene_sequence_started" on init state, we need to do so here.
			[[_o_bundle]]->trigger_scene_sequence_started( self, player );
			
			return false; // already prepared this entity for this scene
		}
		
		player SetHighDetail( true );

		// close the mobile armory if it's open
		if ( player flagsys::get( "mobile_armory_in_use" ) )
		{
			player flagsys::set("cancel_mobile_armory");
			player CloseMenu( "ChooseClass_InGame" );
			player notify( "menuresponse", "ChooseClass_InGame", "cancel" );
		}
		
		//if player was starting to interact with an armory and never finished
		if( player flagsys::get( "mobile_armory_begin_use" ) )
		{
			player util::_enableWeapon();
			player flagsys::clear( "mobile_armory_begin_use" );
		}
		
		if( GetDvarInt("scene_hide_player") > 0 )
		{
			player Hide();
		}
		
		player.current_player_scene = _o_bundle._str_name;
			
		if ( !IS_TRUE( player.magic_bullet_shield ) )
		{
			player.allowdeath = IS_TRUE( _s.allowdeath );
		}
			
		player.scene_takedamage = IS_TRUE( _s.takedamage );
		
		if ( isdefined( player.hijacked_vehicle_entity ) )
		{
			player.hijacked_vehicle_entity Delete();
		}
		else if ( player IsInVehicle() )
		{
			vh_occupied = player GetVehicleOccupied();
			n_seat = vh_occupied GetOccupantSeat( player );
			
			vh_occupied UseVehicle( player, n_seat ); // make player exit vehicle
		}
		
		revive_player( player );
				
		player thread scene::scene_disable_player_stuff( !IS_TRUE( _s.ShowHUD ) );
		
		if ( IS_TRUE( _s.FirstWeaponRaise ) )
		{
			//SetDvar( "playerWeaponRaisePostIGC", WEAP_FIRST_RAISE );
		}
		
		player.player_anim_look_enabled	= !IS_TRUE( _s.LockView );
		player.player_anim_clamp_right	= VAL( _s.viewClampRight, 0 );
		player.player_anim_clamp_left	= VAL( _s.viewClampLeft, 0 );
		player.player_anim_clamp_top	= VAL( _s.viewClampBottom, 0 );
		player.player_anim_clamp_bottom	= VAL( _s.viewClampBottom, 0 );
		
		if ( ( !IS_TRUE( _s.RemoveWeapon ) || IS_TRUE( _s.ShowWeaponInFirstPerson ) ) && !IS_TRUE( _s.DisablePrimaryWeaponSwitch ) )
		{
			player player::switch_to_primary_weapon( true );
		}
		
		set_player_stance( player );
	}
	
	function revive_player( player )
	{
		if ( player.sessionstate === "spectator" )
		{		
			player thread [[ level.spawnPlayer ]]();
		}
		else if ( player laststand::player_is_in_laststand() )
		{
			player notify( "auto_revive" ); // currently CP only
		}
	}
	
	function set_player_stance( player )
	{
		if ( _s.PlayerStance === "crouch" )
		{
			player AllowStand( false );
			player AllowCrouch( true );
			player AllowProne( false );
		}
		else if ( _s.PlayerStance === "prone" )
		{
			player AllowStand( false );
			player AllowCrouch( false );
			player AllowProne( true );
		}
		else // default to stand
		{
			player AllowStand( true );
			player AllowCrouch( false );
			player AllowProne( false );
		}
	}
	
	function finish( b_clear = false, b_canceled = false )
	{
		if ( isdefined( _str_state ) )
		{
			_str_state = undefined;
			self notify( "new_state" );
			
			if ( !is_shared_player() && !is_alive() ) //TU1: need to only skip this if SHARED scene, not just for !is_player
			{
				_cleanup();
				
				_e = undefined;			
				_is_valid = false;
			}
			else
			{
				if ( !is_player() )
				{
					if ( isdefined( _e._scene_old_takedamage ) )
					{
						_e.takedamage = _e._scene_old_takedamage;
					}
					
					if ( !IS_TRUE( _e.magic_bullet_shield ) )
					{
						_e.allowdeath = true;
					}
					
					_e._scene_old_takedamage = undefined;
					_e._scene_old_gun_removed = undefined;
				}
				else
				{
					if ( is_shared_player() )
					{
						foreach ( player in level.players )
						{
							if( player flagsys::get( "shared_igc" ) )
							{
								_finish_player( player );
							}
						}
					}
					else
					{
						player = ( IsPlayer( _player ) ? _player : _e );
						_finish_player( player );
					}
				}
				
				if ( IS_TRUE( _s.RemoveWeapon ) && !IS_TRUE( _e._scene_old_gun_removed ) )
				{
					if ( IsPlayer( _e ) )
					{
						_e player::give_back_weapons();
					}
					else
					{
						_e animation::attach_weapon();
					}
				}
				
				if ( !IsPlayer( _e ) ) // players are handled in _finish_player
				{
					if ( isdefined( _e ) )
					{
						_e SetHighDetail( false );
					}
				}
			}
			
			flagsys::set( "ready" );
			flagsys::set( "done" );
	
			if ( isdefined( _e ) )
			{
				if ( !is_player() )
				{
					if ( is_alive() && ( IS_TRUE( _s.DeleteWhenFinished ) || b_clear ) )
					{
						_e thread scene::synced_delete();
					}
					else if ( is_alive() && IS_TRUE( _s.DieWhenFinished ) && !b_canceled )
					{
						_e.skipdeath = true;
						_e.allowdeath = true;
						_e.skipscenedeath = true;
						
						_e Kill();
					}
				}
				
				if ( IsActor( _e ) && IsAlive( _e ) )
				{
					if ( IS_TRUE( _s.DelayMovementAtEnd ) )
					{
						_e PathMode( "move delayed", true, RandomFloatRange( 2, 3 ) );
					}
					else
					{
						_e PathMode( "move allowed" );
					}
					
					if ( IS_TRUE( _s.LookAtPlayer ) )
					{
						_e LookAtEntity();
					}
				}
			}
									
			_cleanup();
		}
	}
	
	function _finish_player( player )
	{
		player.scene_set_visible_time = level.time;
		player SetVisibleToAll();
		
		player flagsys::clear( "shared_igc" );
		
		if ( !IS_TRUE( player.magic_bullet_shield ) )
		{
			player.allowdeath = true;
		}
		
		player.current_player_scene = undefined;
		
		player.scene_takedamage = undefined;		
		player._scene_old_gun_removed = undefined;
		
		player thread scene::scene_enable_player_stuff( !IS_TRUE( _s.ShowHUD ) );
		
		//SetDvar( "playerWeaponRaisePostIGC", WEAP_RAISE );
		
		if(!([[_o_bundle]]->has_next_scene()) )
		{
			if([[_o_bundle]]->is_player_anim_ending_early())
			{
				if(![[_o_bundle]]->is_skipping_scene() && [[_o_bundle]]->is_scene_shared_sequence()) //if we are not skipping a scene then just notify that the scene sequence has ended
				{
					[[_o_bundle]]->init_scene_sequence_started(false);
				}
				_o_bundle thread cscene::_stop_camera_anim_on_player(player);
			}
			else if(_o_bundle._s scene::is_igc())
			{
				_o_bundle thread cscene::_stop_camera_anim_on_player(player);
			}
		}
		
		n_camera_tween_out = get_camera_tween_out();
		if ( n_camera_tween_out > 0 )
		{
			player StartCameraTween( n_camera_tween_out );
		}
		
		if ( !IS_TRUE( _s.DontReloadAmmo ) )
		{		
			player player::fill_current_clip();
		}
		
		player AllowStand( true );
		player AllowCrouch( true );
		player AllowProne( true );
		
		player SetHighDetail( false );
	}
	
	function set_objective()
	{
		if ( !isdefined( _e.script_objective ) )
		{
			if ( isdefined( _o_bundle._e_root.script_objective ) )
			{
				_e.script_objective = _o_bundle._e_root.script_objective;
			}
			else if ( isdefined( _o_bundle._s.script_objective ) )
			{
				_e.script_objective = _o_bundle._s.script_objective;
			}
		}
	}
	
	function _on_death()
	{
		self endon( "cleanup" );
		_e waittill( "death" );
		
		if ( isdefined( _e ) && !IS_TRUE( _e.skipscenedeath ) )
		{
			self thread do_death_anims();
		}
	}
	
	function do_death_anims()
	{
		ent = _e;
		
		if ( IsAI( ent ) && !isdefined( _str_death_anim ) && !isdefined( _str_death_anim_loop ) )
		{
			ent StopAnimScripted();
			
			if ( IsActor( ent ) )
			{
				ent StartRagDoll();
			}
		}
		
		if ( isdefined( _str_death_anim ) )
		{
			ent.skipdeath = true;
			ent animation::play( _str_death_anim, ent, undefined, 1, .2, 0 );
		}
		
		if ( isdefined( _str_death_anim_loop ) )
		{
			ent.skipdeath = true;
			ent animation::play( _str_death_anim_loop, ent, undefined, 1, 0, 0 );
		}
	}
	
	function _cleanup()
	{
		if ( isdefined( _e ) && isdefined( _e.current_scene ) )
		{
			_e flagsys::clear( _o_bundle._str_name );
			
			if ( _e.current_scene == _o_bundle._str_name )
			{
				_e flagsys::clear( "scene" );
				
				_e.finished_scene = _o_bundle._str_name;
				_e.current_scene = undefined;
				_e._o_scene = undefined;
				
				if ( is_player() )
				{
					if ( !IS_TRUE( _s.newplayermethod ) )
					{
						_e Delete();
						thread reset_player();
					}
					
					_e.animname = undefined;
				}
			}
		}
		
		self notify( "death" );
		self endon( "new_state" );
		
		waittillframeend; // allow death anims and other things to execute before killing those threads
		
		self notify( "cleanup" );
		
		if ( IsAI( _e ) )
		{
			_set_goal();
		}
		
		if ( isdefined( _o_bundle ) && IS_TRUE( _o_bundle.scene_stopping ) )	// don't clear this if the scene is looping
		{
			_o_bundle = undefined;
		}
	}
	
	function _set_goal()
	{
		if ( !( IS_EQUAL( _e.scene_spawned, _o_bundle._s.name ) && isdefined( _e.target ) ) )
		{
			if ( !isdefined( _e.script_forcecolor ) )
			{
				if ( !_e flagsys::get( "anim_reach" ) )
				{
					if ( isdefined( _e.scenegoal ) )
					{
						_e SetGoal( _e.scenegoal );	// use secene goal
						_e.scenegoal = undefined;
					}
					else if ( _b_set_goal )
					{
						_e SetGoal( _e.origin );	// default to current location
					}
				}
			}
		}
	}
	
	function _track_goal()
	{
		// disable setting goal when animation is done if goal is changed any time during animation
		// (assume scripter knows what they are doing and don't override it)
		self endon( "cleanup" );
		_e endon( "death" );
		_e waittill( "goal_changed" );
		_b_set_goal = false;
	}
	
	function _play_anim( animation, n_delay_min = 0, n_delay_max = 0, n_rate = 1, n_blend = 0.2, n_time = 0 )
	{
		if ( _should_skip_anim( animation ) )
		{
			return;
		}
			
		if ( n_time != 0 )
		{
			n_time = [[ _o_bundle ]]->get_anim_relative_start_time( animation, n_time );
		}
		
		n_delay = n_delay_min;
		if ( n_delay_max > n_delay_min )
		{
			n_delay = RandomFloatRange( n_delay_min, n_delay_max );
		}
		
		do_reach = ( ( n_time == 0 ) && ( IS_TRUE( _s.doreach ) && ( !IS_TRUE( _o_bundle._testing ) || GetDvarInt( "scene_test_with_reach", 0 ) ) ) );
		
		_spawn( undefined, !do_reach, !do_reach );
		
		if ( !IsActor( _e ) )
		{
			do_reach = false;
		}
		
		if ( n_delay > 0 )
		{
			if ( n_delay > 0 )
			{
				wait n_delay;
			}
		}
		
		if ( do_reach )
		{
			[[scene()]]->wait_till_scene_ready( self );
			
			if ( IS_TRUE( _s.DisableArrivalInReach ) )
			{
				_e animation::reach( animation, get_align_ent(), get_align_tag(), true );
			}				
			else 
			{
				_e animation::reach( animation, get_align_ent(), get_align_tag() );
			}
			
			flagsys::set( "ready" );
		}
		else if ( n_rate > 0 ) // Go ahead and first-frame the anim right away without waiting
		{
			[[scene()]]->wait_till_scene_ready();
		}
		else if ( isdefined( _s.aligntarget ) )
		{
			foreach ( o_obj in _o_bundle._a_objects )
			{
				// If align target is an object in this scene, wait for it to spawn
				if ( o_obj._str_name == _s.aligntarget )
				{
					o_obj flagsys::wait_till( "ready" );
					break;
				}
			}
		}

		if ( is_alive() )
		{
			align = get_align_ent();
			tag = get_align_tag();
			
			if ( align == level )
			{
				align = ( 0, 0, 0 );
				tag = ( 0, 0, 0 );
			}
			
			if ( is_shared_player() )
			{
				_play_shared_player_anim( animation, align, tag, n_rate, n_time );
			}
			else
			{
				if ( is_player() && !IS_TRUE( _s.newplayermethod ) )
				{
					thread link_player();
				}
				
				if ( ( /*!is_player() && */_o_bundle._s scene::is_igc() ) || ( _e.scene_spawned === _o_bundle._s.name ) )
				{
					_e DontInterpolate();
					_e Show();
				}
				
				// Lerping and camera tween
				n_lerp = get_lerp_time();
				
				if ( IsPlayer( _e ) && !_o_bundle._s scene::is_igc() )
				{
					n_camera_tween = get_camera_tween();
					if ( n_camera_tween > 0 )
					{
						_e StartCameraTween( n_camera_tween );
					}
				}
				///////////////////
				
				if ( ![[ _o_bundle ]]->has_next_scene() )
				{
					n_blend_out = ( IsAI( _e ) ? .2 : 0 );
				}
				else
				{
					n_blend_out = 0;
				}
				
				if ( IS_TRUE( _s.DieWhenFinished ) )
				{
					n_blend_out = 0;
				}
				
				self.current_playing_anim = animation;
				
				//skip the new animation if we are skipping the scene
				if ( IS_TRUE( [[ _o_bundle ]]->is_skipping_scene() ) && n_rate != 0 )
				{
					thread skip_scene( true );
				}
				
				_e animation::play( animation, align, tag, n_rate, n_blend, n_blend_out, n_lerp, n_time, _s.ShowWeaponInFirstPerson );
				
				if ( !isdefined( _e ) || !_e IsPlayingAnimScripted() )
				{
					self.current_playing_anim = undefined;
				}
			}
		}
		else
		{
			/# log( "No entity for animation '" + animation + "' so not playing it." ); #/
		}
		
		_is_valid = ( is_alive() && !in_a_different_scene() );
	}
	
	function spawn_ent( e )
	{
		b_disable_throttle = ( _o_bundle._s scene::is_igc() || IS_TRUE( _o_bundle._s.DontThrottle ) );
		
		if ( is_player() && !IS_TRUE( _s.newplayermethod ) )
		{
			system::wait_till( "loadout" );
			m_player = util::spawn_anim_model( level.player_interactive_model );
			return m_player;
		}
		else if ( isdefined( e ) )
		{
			if ( IsSpawner( e ) )
			{
				if ( !error( e.count < 1, "Trying to spawn AI for scene with spawner count < 1" ) )
				{
					return e spawner::spawn( true, undefined, undefined, undefined, b_disable_throttle );
				}
			}
		}
		else if ( isdefined( _s.model ) )
		{
			new_model = undefined;
			
			if ( is_player_model() )
			{
				new_model = util::spawn_anim_player_model( _s.model, _o_bundle._e_root.origin, _o_bundle._e_root.angles );
			}
			else
			{
				new_model = util::spawn_anim_model( _s.model, _o_bundle._e_root.origin, _o_bundle._e_root.angles, undefined, !b_disable_throttle );
			}
			
			return new_model;
		}
	}
	
	function _play_shared_player_anim( animation, align, tag, n_rate, n_time )
	{
		self.player_animation = animation;
		self.player_animation_notify = animation + "_notify";
		self.player_animation_length = GetAnimLength( animation );
		self.player_align = align;
		self.player_tag = tag;
		self.player_rate = n_rate;
		self.player_time_frac = n_time;
		self.player_start_time = GetTime();
		
		callback::on_loadout( &_play_shared_player_anim_for_player, self );
		
		foreach ( player in level.players )
		{
			if ( player flagsys::get( "loadout_given" ) && ( player.sessionstate !== "spectator" ) )
			{
				self thread _play_shared_player_anim_for_player( player );
			}
			else if( IS_TRUE(player.initialLoadoutGiven) )
			{
				revive_player( player );
			}
		}
		
		waittillframeend;
		
		do
		{
			b_playing = false;
			a_players = ArrayCopy( level.activeplayers );
			
			foreach ( player in a_players )
			{
				if ( isdefined( player ) && player flagsys::get( self.player_animation_notify ) )
				{
					b_playing = true;
					player flagsys::wait_till_clear( self.player_animation_notify );
					break;
				}
			}
		}
		while ( b_playing );
		
		callback::remove_on_loadout( &_play_shared_player_anim_for_player, self );
		
		thread [[_o_bundle]]->_call_state_funcs( "players_done" );
	}
	
	function _play_shared_player_anim_for_player( player )
	{
		player endon( "death" );
		
		if ( !isdefined( _o_bundle ) )
			return;

		player flagsys::set( "shared_igc" );
		
		//Do not clear the flag for the init state
		if( player flagsys::get( self.player_animation_notify ) )
		{
			player flagsys::set( self.player_animation_notify + "_skip_init_clear" );
		}
		
		player flagsys::set( self.player_animation_notify );
		
		if  ( isdefined( player GetLinkedEnt() ) )
		{
			player Unlink();
		}
		
		if ( !IS_TRUE( _s.DisableTransitionIn ) )
		{
			if ( ( player != _player ) || GetDvarInt( "scr_player1_postfx", 0 ) )
			{
				if ( !isdefined( player.screen_fade_menus ) )
				{
					if ( !IS_TRUE( level.chyron_text_active ) )
					{
						if ( !IS_TRUE( player.fullscreen_black_active ) )
						{
							player.play_scene_transition_effect = true;
						}
					}
				}
			}
		}
		
		player Show(); // Make sure the player is not hidden before hidding to the other players
		player SetInvisibleToAll();
		
		_prepare_player( player );
		
		n_time_passed = ( GetTime() - self.player_start_time ) / 1000;
		n_start_time = self.player_time_frac * self.player_animation_length;
		n_time_left = self.player_animation_length - n_time_passed - n_start_time;
		
		n_time_frac = 1 - ( n_time_left / self.player_animation_length );
		
		if ( isdefined( _e ) && ( player != _e ) )
		{
			// Teleport coop players to the player who is triggering this scene
			// so that the camera tween and lerping happens from the same place
			player DontInterpolate();
			player SetOrigin( _e.origin );
			player SetPlayerAngles( _e GetPlayerAngles() );
		}
		
		// Lerping and camera tween
		n_lerp = get_lerp_time();
		if ( !_o_bundle._s scene::is_igc() )
		{
			n_camera_tween = get_camera_tween();
			if ( n_camera_tween > 0 )
			{
				player StartCameraTween( n_camera_tween );
			}
		}
		///////////////////
		
		if ( n_time_frac < 1 )
		{		
			str_animation = self.player_animation;
			
			// load gender specific player animation
			if ( player util::is_female() )
			{
				if ( isdefined( _o_bundle._s.s_female_bundle ) )
				{
					s_bundle = _o_bundle._s.s_female_bundle;
				}
			}
			else
			{
				if ( isdefined( _o_bundle._s.s_male_bundle ) )
				{
					s_bundle = _o_bundle._s.s_male_bundle;
				}
			}
			
			if ( isdefined( s_bundle ) )
			{			
				foreach ( s_object in s_bundle.objects )
				{
					if ( isdefined( s_object ) && IS_EQUAL( s_object.type, "player" ) )
					{
						str_animation = s_object.mainanim;
						break;
					}
				}
			}
			
			player_num = player GetEntityNumber();
			
			if(!isdefined(self.current_playing_anim))
			{
				self.current_playing_anim = [];
			}
			
			self.current_playing_anim[player_num] = str_animation;
			
			//skip the new animation if we are skipping the scene
			if ( IS_TRUE( [[ _o_bundle ]]->is_skipping_scene() ) )
			{
				thread skip_scene( true );
			}
			
			//////////////////////////////////////////
			
			player animation::play( str_animation, self.player_align, self.player_tag, self.player_rate, 0, 0, n_lerp, n_time_frac, _s.ShowWeaponInFirstPerson );
			
			if( !(player flagsys::get( self.player_animation_notify + "_skip_init_clear" )) )
			{
				player flagsys::clear( self.player_animation_notify ); // all players use the same aniamtion name for the flag to track when they are done
			}
			else
			{
				player flagsys::clear( self.player_animation_notify + "_skip_init_clear" );
			}
			
			if ( !player IsPlayingAnimScripted() )
			{
				self.current_playing_anim[player_num] = undefined;
			}
		}
	}
	
	function play_regroup_fx_for_scene( e_player )
	{
		align = get_align_ent();
		v_origin = align.origin;
		v_angles = align.angles;
		
		tag = get_align_tag();
		if ( isdefined( tag ) )
		{
			v_origin = align GetTagOrigin( tag );
			v_angles = align GetTagAngles( tag );
		}
		
		v_start = GetStartOrigin( v_origin, v_angles, _s.mainanim );
		n_dist_sq = DistanceSquared( e_player.origin, v_start );
		
		if ( ( n_dist_sq > 500 * 500 || isdefined( e_player.hijacked_vehicle_entity ) ) && ( !IS_TRUE( e_player.force_short_scene_transition_effect ) ) )
		{
			self thread regroup_invulnerability( e_player );
			e_player clientfield::increment_to_player( "postfx_igc", 1 ); // full effect
		}
		else
		{
			e_player clientfield::increment_to_player( "postfx_igc", 3 ); // minimal effect
		}
		
		util::wait_network_frame(); // make sure postfx capture frame before we teleport
	}
	
	function regroup_invulnerability( e_player )
	{
		e_player endon( "disconnect" );
		
		e_player.ignoreme = true;
		e_player.b_teleport_invulnerability = true;
		
		e_player util::streamer_wait( undefined, 0, 7 );
		
		e_player.ignoreme = false;
		e_player.b_teleport_invulnerability = undefined;		
	}
	
	function get_lerp_time()
	{
		if ( IsPlayer( _e ) )
		{
			return ( isdefined( _s.LerpTime ) ? _s.LerpTime : 0 );
		}
		else
		{
			return ( isdefined( _s.EntityLerpTime ) ? _s.EntityLerpTime : 0 );
		}
	}
	
	function get_camera_tween()
	{
		return ( isdefined( _s.CameraTween ) ? _s.CameraTween : 0 );
	}
	
	function get_camera_tween_out()
	{
		return ( isdefined( _s.CameraTweenOut ) ? _s.CameraTweenOut : 0 );
	}
	
	function link_player()
	{
		self endon( "done" );
		
		level flag::wait_till( "all_players_spawned" );
		
		player = _player;
		player Hide();
		
		e_linked = player GetLinkedEnt();
		if ( isdefined( e_linked ) && ( e_linked == _e ) )
		{
			// Update link/clamp if linking to same entity
			
			if ( IS_TRUE( _s.lockview ) )
			{
				player PlayerLinkToAbsolute( _e, "tag_player" );
			}
			else
			{
				player LerpViewAngleClamp( .2, .1, .1, VAL( _s.viewclampright, 0), VAL( _s.viewclampleft, 0), VAL( _s.viewclamptop, 0), VAL( _s.viewclampbottom, 0) );
			}
			
			return;
		}
				
		player DisableUsability();
		player DisableOffhandWeapons();
//		player DisableWeapons( true );
		player DisableWeapons();			//TODO_CODE: QUICK weapon switch only supported for SP at the momement
			
		util::wait_network_frame();
		
		if ( _s.cameratween > 0 )
		{
//			player StartCameraTween( _s.cameratween );		//TODO_CODE: only supported for SP at the momement
		}
		
		player notify( "scene_link" );
		waittillframeend;	// allow level script to do custom stuff before linking
		
		if ( IS_TRUE( _s.lockview ) )
		{
			player PlayerLinkToAbsolute( _e, "tag_player" );
		}
		else
		{
			player PlayerLinkToDelta( _e, "tag_player", 1, VAL( _s.viewclampright, 0), VAL( _s.viewclampleft, 0), VAL( _s.viewclamptop, 0), VAL( _s.viewclampbottom, 0), 1, 1 );
//			player SetPlayerViewRateScale( 100 );	//TODO_CODE: only supported for SP at the momement
		}
		
		wait ( _s.cameratween > .2 ? _s.cameratween : .2 );
		
		_e Show();
	}
	
	function reset_player()
	{
		level flag::wait_till( "all_players_spawned" );
		
		player = _player;
		
//		player StartCameraTween( .2 );	//TODO_CODE: only supported for SP at the momement
//		player ShowViewModel();			//TODO_CODE: only supported for SP at the momement
//		player SetLowReady( false );		//TODO_CODE: only supported for SP at the momement
//		player ResetPlayerViewRateScale();	//TODO_CODE: only supported for SP at the momement
		player EnableUsability();
		player EnableOffhandWeapons();
		player EnableWeapons();
		
		player Show();
	}
		
	function has_init_state()
	{
		return _s scene::_has_init_state();
	}
	
	function is_alive()
	{
		return ( isdefined( _e ) && ( _e.health > 0 || _s.IgnoreAliveCheck === true ) );
	}
	
	function is_player()
	{
		return ( IsDefined( _s.player ) );
	}
	
	function is_player_model()
	{
		return _s.type === "player model";
	}
	
	function is_shared_player()
	{
		return ( IsDefined( _s.player ) && IS_TRUE( _s.SharedIGC ) );
	}
	
	function in_a_different_scene()
	{
		return ( isdefined( _e ) && isdefined( _e.current_scene ) && ( _e.current_scene != _o_bundle._str_name ) );
	}
	
	function _should_skip_anim( animation )
	{
		if(!IS_TRUE(_s.player) && !IS_TRUE(_s.sharedigc) && !IS_TRUE(_s.KeepWhileSkipping) && IS_TRUE([[_o_bundle]]->is_skipping_scene()) && IS_TRUE( _s.DeleteWhenFinished ))
		{
			if( !AnimHasImportantNotifies(animation) )
			{
				if ( !IsSpawner( _e ) )
				{
					b_allows_multiple = [[scene()]]->allows_multiple();
					e = scene::get_existing_ent( _str_name, b_allows_multiple );
						
					if( isdefined(e) )
					{
						return false;
					}
				}
			
				return true;
			}
		}
		
		return false;
	}
	
	function _should_skip_entity()
	{
		if(!IS_TRUE(_s.player) && !IS_TRUE(_s.sharedigc) && !IS_TRUE(_s.KeepWhileSkipping) && IS_TRUE([[_o_bundle]]->is_skipping_scene()) && IS_TRUE( _s.DeleteWhenFinished ))
		{
			if( isdefined(_s.initanim) && AnimHasImportantNotifies(_s.initanim) )
			{
				return false;
			}
			
			if( isdefined(_s.mainanim) && AnimHasImportantNotifies(_s.mainanim) )
			{
				return false;
			}
			
			if( isdefined(_s.endanim) && AnimHasImportantNotifies(_s.endanim) )
			{
				return false;
			}
			
			if ( !IsSpawner( _e ) )
			{
				b_allows_multiple = [[scene()]]->allows_multiple();
				e = scene::get_existing_ent( _str_name, b_allows_multiple );
					
				if( isdefined(e) )
				{
					return false;
				}
			}
			
			return true;
		}
		
		return false;
	}
	
	function private skip_anim_on_client(entity, anim_name)
	{
		if(!isdefined(anim_name))
			return;
		
		if(!isdefined(entity))
			return;
		
		if(!( entity IsPlayingAnimScripted()))
			return;
		
		is_looping = IsAnimLooping(anim_name);
		
		if(is_looping)
			return;
			
		entity clientfield::increment( "player_scene_animation_skip" );
	}
	
	function private skip_anim_on_server( entity, anim_name )
	{
		if(!isdefined(anim_name))
			return;
		
		if(!isdefined(entity))
			return;
		
		//@ToDo : change this to check on the anim_name
		if(!( entity IsPlayingAnimScripted()))
			return;
		
		is_looping = IsAnimLooping(anim_name);
	
		if(is_looping)
		{
			entity animation::stop();
		}
		else
		{	
			entity SetAnimTimebyName(anim_name, 1);
		}
		
		entity stopsounds();
	}
	
	function skip_scene_on_client()
	{
		if(isdefined(self.current_playing_anim))
		{
			if ( is_shared_player() )
			{
				foreach ( player in level.players )
				{
					skip_anim_on_client(player, self.current_playing_anim[player GetEntityNumber()]);
				}
			}
			else
			{
				skip_anim_on_client(_e, self.current_playing_anim );
			}
			
			return true;
		}
		
		return false;
	}
		
	function skip_scene_on_server()
	{
		if(isdefined(self.current_playing_anim))
		{
			if ( is_shared_player() )
			{
				foreach ( player in level.players )
				{
					skip_anim_on_server(player, self.current_playing_anim[player GetEntityNumber()]);
				}
			}
			else
			{
				skip_anim_on_server(_e, self.current_playing_anim );
			}
		}
	}
	
	function skip_scene(b_wait_one_frame)
	{
		if(isdefined(b_wait_one_frame)) //wait for the animation to start
		{
			wait 0.05;
		}
		
		if(skip_scene_on_client())
		{
			wait 0.05;
		}
		
		skip_scene_on_server();
	}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  ___    ___   ___   _  _   ___ 
// / __|  / __| | __| | \| | | __|
// \__ \ | (__  | _|  | .` | | _| 
// |___/  \___| |___| |_|\_| |___|
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class cScene : cScriptBundleBase
{
	var _e_root;
	var _str_state;
	var _n_object_id;
	var _str_mode;
	var _str_notify_name;
	var _n_request_time;
	var _n_streamer_req;

	constructor()
	{
		_n_object_id = 0;
		_str_mode = "";
		_n_streamer_req = -1;
	}
		
	destructor()
	{
	}
	
	function init( str_scenedef, s_scenedef, e_align, a_ents, b_test_run )
	{
		cScriptBundleBase::init( str_scenedef, s_scenedef, b_test_run );

		if( isdefined( s_scenedef.streamerhint ) && s_scenedef.streamerhint != "" && !is_skipping_scene())
		{
			_n_streamer_req = streamerRequest( "set", s_scenedef.streamerhint );
		}
		
		_str_notify_name = ( IsString( _s.MaleBundle ) ? _s.MaleBundle : _str_name );
		
		MAKE_ARRAY( a_ents );
		
		if ( !error( a_ents.size > _s.objects.size, "Trying to use more entities than scene supports." ) )
		{
			_e_root = e_align;
			
			ARRAY_ADD( level.active_scenes[ _str_name ], _e_root );
			ARRAY_ADD( _e_root.scenes, self );
			
			a_objs = get_valid_object_defs();
						
			foreach ( s_obj in a_objs )
			{
				add_object( [[ [[self]]->new_object() ]]->first_init( s_obj, self ) );
			}
			
			_n_request_time = GetTime();			
			if ( !IS_TRUE( _s.DontSync ) )
			{
				add_to_sync_list();
			}
				
			self thread initialize( a_ents );
		}
	}
	
	function add_to_sync_list()
	{
		DEFAULT( level.scene_sync_list, [] );
		DEFAULT( level.scene_sync_list[ _n_request_time ], [] );
		array::add( level.scene_sync_list[ _n_request_time ], self, false );		
	}
	
	function remove_from_sync_list()
	{
		if ( isdefined(level.scene_sync_list) && isdefined( level.scene_sync_list[ _n_request_time ] ) )
		{
			ArrayRemoveValue( level.scene_sync_list[ _n_request_time ], self );
			
			if ( !level.scene_sync_list[ _n_request_time ].size )
			{
				level.scene_sync_list[ _n_request_time ] = undefined;
			}
		}
	}
	
	function new_object()
	{
		return new cSceneObject();
	}
	
	function get_valid_object_defs()
	{
		a_obj_defs = [];
		foreach ( s_obj in _s.objects )
		{
			if ( _s.vmtype == "server" || s_obj.vmtype == "server" )
			{
				if ( isdefined( s_obj.name ) || isdefined( s_obj.model ) || isdefined( s_obj.initanim ) || isdefined( s_obj.mainanim ) )
				{
					if ( !IS_TRUE( s_obj.disabled ) )
					{
						ARRAY_ADD( a_obj_defs, s_obj );
					}
				}
			}
		}
		return a_obj_defs;
	}

	function initialize( a_ents, b_playing = false )
	{
		self notify( "new_state" );
		self endon( "new_state" );
		
		self thread sync_with_client_scene( "init", _testing );
		
		assign_ents( a_ents );
		
		if ( get_valid_objects().size > 0 )
		{
			level flagsys::set( _str_name + "_initialized" );
			_str_state = "init";
			
			foreach ( o_obj in _a_objects )
			{
				thread [[o_obj]]->initialize();
			}
		}
		
		if ( !b_playing )
		{
			thread _call_state_funcs( "init" );
		}
		
		wait_till_scene_ready();
			
		level flagsys::set( _str_notify_name + "_ready" );
		
		// stops the scene if all objects die in the initialize state
		array::flagsys_wait( _a_objects, "done" );
		thread stop();
	}
	
	function get_object_id()
	{
		_n_object_id++;
		return _n_object_id;
	}
	
	function sync_with_client_scene( str_state, b_test_run = false )
	{
		if ( _s.vmtype == "both" && !_s scene::is_igc() )
		{
			self endon( "new_state" );
		
			wait_till_scene_ready();
		
			n_val = undefined;
			
			if ( b_test_run )
			{
				switch ( str_state )
				{
					case "stop":
						n_val = 3;
						break;
					case "init":
						n_val = 4;
						break;
					case "play":
						n_val = 5;
						break;
				}
			}
			else
			{			
				switch ( str_state )
				{
					case "stop":
						n_val = 0;
						break;
					case "init":
						n_val = 1;
						break;
					case "play":
						n_val = 2;
						break;
				}
			}
			
			level clientfield::set( _s.name, n_val );
		}
	}
	
	function assign_ents( a_ents )
	{
		MAKE_ARRAY( a_ents );
		a_objects = ArrayCopy( _a_objects );
			
		if ( _assign_ents_by_name( a_objects, a_ents ) )
		{
			if ( _assign_ents_by_type( a_objects, a_ents, "player", &_is_ent_player ) )
			{
				if ( _assign_ents_by_type( a_objects, a_ents, "actor", &_is_ent_actor ) )
				{
					if ( _assign_ents_by_type( a_objects, a_ents, "vehicle", &_is_ent_vehicle ) )
					{
						if ( _assign_ents_by_type( a_objects, a_ents, "prop" ) )
						{
							foreach ( ent in a_ents )
							{
								obj = array::pop( a_objects );
								if ( !error( !isdefined( obj ), "No scene object to assign entity too.  You might have passed in more than the scene supports." ) )
								{
									obj._e = ent;
								}
							}
						}
					}
				}
			}
		}
	}
	
	function _assign_ents_by_name( &a_objects, &a_ents )
	{
		if ( a_ents.size )
		{
			foreach ( str_name, e_ent in ArrayCopy( a_ents ) )
			{
				foreach ( i, o_obj in ArrayCopy( a_objects ) )
				{
					if ( isdefined( o_obj._s.name ) && ( STR( o_obj._s.name ) == ToLower( STR( str_name ) ) ) )
					{
						o_obj._e = e_ent;
						
						ArrayRemoveIndex( a_ents, str_name, true );
						ArrayRemoveIndex( a_objects, i );
						
						break;
					}
				}
			}
			
			/#
				// Check for any remaining entities with specific names that don't have objects to assign them to
				foreach ( i, ent in a_ents )
				{
					error( IsString( i ), "No scene object with name '" + i + "'." );
				}
			#/
		}
		
		return a_ents.size;
	}
	
	function _assign_ents_by_type( &a_objects, &a_ents, str_type, func_test )
	{
		if ( a_ents.size )
		{
			a_objects_of_type = get_objects( str_type );
			
			if ( a_objects_of_type.size )
			{		
				foreach ( ent in ArrayCopy( a_ents ) )
				{
					if ( isdefined( func_test ) && [[ func_test ]]( ent ) )
					{
						obj = array::pop_front( a_objects_of_type );
						if ( isdefined( obj ) )
						{
							obj._e = ent;
						
							ArrayRemoveValue( a_ents, ent, true );
							ArrayRemoveValue( a_objects, obj );
						}
						else
						{
							break;
						}
					}
				}
			}
		}
		
		return a_ents.size;
	}
	
	function _is_ent_player( ent )
	{
		return ( IsPlayer( ent ) );
	}
	
	function _is_ent_actor( ent )
	{
		return ( IsActor( ent ) || IsActorSpawner( ent ) );
	}
	
	function _is_ent_vehicle( ent )
	{
		return ( IsVehicle( ent ) || IsVehicleSpawner( ent ) );
	}
		
	function get_objects( str_type )
	{
		a_ret = [];
		foreach ( obj in _a_objects )
		{
			if ( obj._s.type == str_type )
			{
				ARRAY_ADD( a_ret, obj );
			}
		}
		return a_ret;
	}
	
	function get_anim_relative_start_time(animation, n_time)
	{
		if(!isdefined(self.n_start_time) || self.n_start_time == 0 || !isdefined(self.longest_anim_length) || self.longest_anim_length == 0)
			return n_time;
		
		anim_length = GetAnimLength(animation);
		is_looping = IsAnimLooping(animation);
		
		n_time =  self.longest_anim_length / anim_length * n_time;
		
		if(is_looping)
		{
			if(n_time > 0.95)
				n_time = 0.95;
		}
		else
		{
			if(n_time > 0.99)
				n_time = 0.99;
		}
		
		return n_time;
	}
	
	function is_player_anim_ending_early()
	{
		max_anim_length = -1;
		player_anim_length = -1;
		
		foreach ( obj in _a_objects )
		{
			if(isdefined(obj._s.MainAnim))
			{
				anim_length = GetAnimLength( obj._s.MainAnim );
			}
			   
			if ( IS_EQUAL( obj._s.type, "player" ) )
			{
				player_anim_length = anim_length;
			}
			
			if(anim_length > max_anim_length)
			{
				max_anim_length = anim_length;
			}
		}
		
		return player_anim_length < max_anim_length;
	}

	function play( str_state = "play", a_ents, b_testing = false, str_mode = "" )
	{
		self notify( "new_state" );
		self endon( "new_state" );
		
		if(str_mode == "skip_scene")
		{
			thread skip_scene( true );
		}
		else if(str_mode == "skip_scene_player")
		{
			self.b_player_scene = true;
			thread skip_scene( true );
		}
		else if(!is_skipping_scene() && is_scene_shared_sequence() && !is_scene_shared()) //stop the shared sequence if the next (current) scene is not shared.
		{
			init_scene_sequence_started( false);
		}
		
		update_scene_sequence();
		
		_testing = b_testing;
		_str_mode = str_mode;
		
		if(IS_TRUE(_s.SpectateOnJoin))
		{
			level.scene_should_spectate_on_hot_join = true;
		}
		
		assign_ents( a_ents );
		
		if ( StrStartsWith( _str_mode, "capture" ) )
		{
			/* First-frame the scene and move player to align node to stream the scene */
			
			if ( get_valid_objects().size )
			{
				foreach ( o_obj in _a_objects )
				{
					thread [[o_obj]]->initialize( true );
				}
			}
			
			thread loop_camera_anim_to_set_up_for_capture(); // put player camera in a more accurate postiion for streaming
			
			// move the player to the align node and link them so they don't fall if there's nothing under them
			
			capture_player = level.players[ 0 ];
			
			v_origin = get_align_ent().origin;
			
			if ( !isdefined( capture_player.e_capture_link ) )
			{
				capture_player.e_capture_link = util::spawn_model( "tag_origin", v_origin );
				capture_player SetOrigin( v_origin );
				capture_player Linkto( level.players[ 0 ].e_capture_link );
			}
			else
			{
				capture_player.e_capture_link.origin = v_origin;
			}
			
			wait 15; // give scene time in the init state to load textures, also the code needs time in between captures
			
			thread _stop_camera_anims();
		}
		
		self thread sync_with_client_scene( "play", b_testing );
		
		/* Get animation start time from the mode string */
		
		self.n_start_time = 0;
		if ( IsSubStr( str_mode, "skipto" ) )
		{
			args = StrTok( str_mode, ":" );
			if ( isdefined( args[1] ) )
			{
				self.n_start_time = Float( args[1] );
			}
			else
			{
				// skip to end of animation - can't go all the way to 1 because looping animations will assert
				self.n_start_time = .95;
			}
			
			self.longest_anim_length = 0;
			
			foreach ( s_obj in _a_objects )
			{
				if ( isdefined( s_obj._s.MainAnim ) )
				{
					anim_length = GetAnimLength( s_obj._s.MainAnim );
				
					if ( anim_length > self.longest_anim_length )
					{
						self.longest_anim_length = anim_length;
					}
				}
			}
		}
		
		/* ---------------------------------------------- */
		
		if ( get_valid_objects().size || _s scene::is_igc() )
		{
			level flagsys::set( _str_name + "_playing" );
			_str_state = "play";
			
			foreach ( o_obj in _a_objects )
			{
				thread [[o_obj]]->play();
			}
			
			wait_till_scene_ready();
			
			level flagsys::set( _str_notify_name + "_ready" );
			
			if ( self.n_start_time == 0 )
			{			
				self thread _play_camera_anims();
			}
			
			if( _n_streamer_req != -1 && !is_skipping_scene())
			{
				streamerRequest( "play", _s.streamerhint );
			}

			thread _call_state_funcs( "play" );
			
			if ( _s scene::is_igc() )
			{
				if ( !IS_TRUE( _s.DisableSceneSkipping ) && _str_state != "init" )
				{
					trigger_scene_sequence_started(self); //send self as cscene to force triggering the sequnce
				}
				
				if ( IsString( _s.cameraswitcher ) )
				{
					_wait_for_camera_animation( _s.cameraswitcher, self.n_start_time );
				}
				else if ( IsString( _s.extraCamSwitcher1 ) )
				{
					_wait_for_camera_animation( _s.extraCamSwitcher1, self.n_start_time );
				}
				else if ( IsString( _s.extraCamSwitcher2 ) )
				{
					_wait_for_camera_animation( _s.extraCamSwitcher2, self.n_start_time );
				}
				else if ( IsString( _s.extraCamSwitcher3 ) )
				{
					_wait_for_camera_animation( _s.extraCamSwitcher3, self.n_start_time );
				}
				else if ( IsString( _s.extraCamSwitcher4 ) )
				{
					_wait_for_camera_animation( _s.extraCamSwitcher4, self.n_start_time );
				}
				
				foreach ( o_obj in _a_objects )
				{
					thread [[o_obj]]->stop( false, IS_TRUE( o_obj._s.DontClamp ), true );
				}
				
				_e_root notify( "scene_done", _str_notify_name );
				thread _call_state_funcs( "done" );
				
				if ( IS_TRUE( _s.SpectateOnJoin ) )
				{
					level.scene_should_spectate_on_hot_join = undefined;
				}
			}
			else
			{
				array::flagsys_wait_any_flag( _a_objects, "done", "main_done" );
				
				if ( isdefined( _e_root ) )
				{
					_e_root notify( "scene_done", _str_notify_name );
				}
				
				thread _call_state_funcs( "done" );
				
				if ( IS_TRUE( _s.SpectateOnJoin ) )
				{
					level.scene_should_spectate_on_hot_join = undefined;
				}
				
				array::flagsys_wait( _a_objects, "done" );
			}
			
			if ( is_looping() || ( StrEndsWith( _str_mode, "loop" ) ) )
			{
				if ( has_init_state() )
				{
					level flagsys::clear( _str_name + "_playing" );
					
					thread initialize();
				}
				else
				{
					level flagsys::clear( _str_name + "_initialized" );
					
					thread play( str_state, undefined, b_testing, str_mode );
				}
			}
			else
			{
				if ( !StrEndsWith( _str_mode, "single" ) )
				{
					thread run_next();
				}
				else
				{
					if( !is_skipping_scene() ) //if we are not skipping a scene then just notify that a scene sequence has ended
					{
						if(is_scene_shared_sequence())
						{
							init_scene_sequence_started(false);
						}
					}
					else if(isdefined(level.linked_scenes)) //if we are skipping a scene, remove it from the linked scenes if it exists
					{
						ArrayRemoveValue(level.linked_scenes, _s.name );
					}
					
					streamer_request_completed();
				}
				
				
				if ( !_s scene::is_igc() || !IS_TRUE( _s.holdCameraLastFrame ) )
				{
					// Scenes set to hold camera last frame must be stopped manually with scene::stop()
					thread stop( false, true );
				}
			}
		}
		else
		{
			thread stop( false, true );
		}
	}
	
	function _wait_server_time( n_time, n_start_time = 0 )
	{
		n_len = ( n_time - ( n_time * n_start_time ) ); // get the length we need to wait from the desired start time fraction
		n_len = n_len / .05;
		
		n_len_int = Int( n_len );
		if ( n_len_int != n_len )
		{
			n_len = Floor( n_len );
		}
	
		n_server_length = n_len * .05; // clamp to full server frames.
		
		wait n_server_length;
	}
	
	function _wait_for_camera_animation( str_cam, n_start_time )
	{
		self endon( "skip_camera_anims" );
		
		if ( IsCamAnimLooping( str_cam ) )
		{
			level waittill( "forever" );
		}
		else
		{
			_wait_server_time( GetCamAnimTime( str_cam ) / 1000, n_start_time );
		}
	}
	
	function _play_camera_anims()
	{
		level endon( "stop_camera_anims" );
		waittillframeend;
		
		e_align = get_align_ent();
			
		v_origin = ( isdefined( e_align.origin ) ? e_align.origin : ( 0, 0, 0 ) );
		v_angles = ( isdefined( e_align.angles ) ? e_align.angles : ( 0, 0, 0 ) );
		
		xcam_players = [];
		
		if(IS_TRUE(_s.LinkXCamToOnePlayer))
		{
			foreach ( o_obj in _a_objects )
			{
				if( isdefined(o_obj) && [[o_obj]]->is_player() && ![[o_obj]]->is_shared_player() )
				{
					ARRAY_ADD(xcam_players,o_obj._player);
				}
			}
			
			if(xcam_players.size == 0)
			{
				xcam_players = level.players;
			}
			else
			{
				self.a_xcam_players = xcam_players;
			}
		}
		else
		{
			xcam_players = level.players;
		}
		
		if ( IsString( _s.cameraswitcher ) )
		{
			if(!IS_TRUE(_s.LinkXCamToOnePlayer))
			{
				callback::on_loadout( &_play_camera_anim_on_player_callback, self );
			}
			  
			self.camera_v_origin = v_origin;
			self.camera_v_angles = v_angles;
			self.camera_start_time = GetTime();
		
			array::thread_all_ents( xcam_players, &_play_camera_anim_on_player, v_origin, v_angles, false );
		}
		
		if ( IsString( _s.extraCamSwitcher1 ) )
		{
			array::thread_all_ents( xcam_players, &_play_extracam_on_player, 0, _s.extraCamSwitcher1, v_origin, v_angles );
		}
		
		if ( IsString( _s.extraCamSwitcher2 ) )
		{
			array::thread_all_ents( xcam_players, &_play_extracam_on_player, 1, _s.extraCamSwitcher2, v_origin, v_angles );
		}
		
		if ( IsString( _s.extraCamSwitcher3 ) )
		{
			array::thread_all_ents( xcam_players, &_play_extracam_on_player, 2, _s.extraCamSwitcher3, v_origin, v_angles );
		}
		
		if ( IsString( _s.extraCamSwitcher4 ) )
		{
			array::thread_all_ents( xcam_players, &_play_extracam_on_player, 3, _s.extraCamSwitcher4, v_origin, v_angles );
		}
	}
	
	function _play_camera_anim_on_player_callback( player )
	{
		self thread _play_camera_anim_on_player(player, self.camera_v_origin, self.camera_v_angles, true);
	}
	
	function _play_camera_anim_on_player( player, v_origin, v_angles, ignore_initial_notetracks )
	{
		player notify( "new_camera_switcher" );
		player DontInterpolate();
		player thread scene::scene_disable_player_stuff();
		
		self.played_camera_anims = true;
		
		n_start_time = self.camera_start_time;
		
		if(!isdefined(_s.cameraSwitcherGraphicContents) || IsMature( player ))
		{
			//@ToDo - Enable once the new exe populated (8/14/2015)
			CamAnimScripted( player, _s.cameraswitcher, n_start_time, v_origin, v_angles );
			//CamAnimScripted( player, _s.cameraswitcher, n_start_time, v_origin, v_angles, 0, "", ignore_initial_notetracks );
		}
		else
		{
			//@ToDo - Enable once the new exe populated (8/14/2015)
			CamAnimScripted( player, _s.cameraSwitcherGraphicContents, n_start_time, v_origin, v_angles );
			//CamAnimScripted( player, _s.cameraSwitcherGraphicContents, n_start_time, v_origin, v_angles, 0, "", ignore_initial_notetracks );
		}
	}
	
	function loop_camera_anim_to_set_up_for_capture()
	{
		level endon( "stop_camera_anims" );
		
		while ( true )
		{
			_play_camera_anims();
			_wait_for_camera_animation( _s.cameraswitcher );
		}
	}
	
	function _play_extracam_on_player( player, n_index, str_camera_anim, v_origin, v_angles )
	{
		self.played_camera_anims = true;
		ExtraCamAnimScripted( player, n_index, str_camera_anim, GetTime(), v_origin, v_angles );
	}
	
	function _stop_camera_anims()
	{
		if(!IS_TRUE(self.played_camera_anims)) //no camera anims were played to be stopped
		{
			return;
		}
		
		level notify( "stop_camera_anims" );
		
		xcam_players = [];
		
		if(isdefined(self.a_xcam_players))
		{
			xcam_players = self.a_xcam_players;
		}
		else
		{
			xcam_players = GetPlayers();
		}
		
		foreach ( player in xcam_players )
		{
			if ( isdefined( player ) )
			{
				self thread _stop_camera_anim_on_player( player );
			}
		}
		
//		show_players();
	}
	
	function _stop_camera_anim_on_player( player )
	{
		player endon( "disconnect" );
		if ( IsString( _s.cameraswitcher ) )
		{
			player endon( "new_camera_switcher" );
			
			player DontInterpolate();
			EndCamAnimScripted( player );
			
			player thread scene::scene_enable_player_stuff();
			
			if(!IS_TRUE(_s.LinkXCamToOnePlayer))
			{
				callback::remove_on_loadout( &_play_camera_anim_on_player_callback, self );
			}
		}
		
		// TODO: do we want the extracam animations to stop?
		if ( IsString( _s.extraCamSwitcher1 ) )
		{		 
			EndExtraCamAnimScripted( player, 0 );
		}
		
		if ( IsString( _s.extraCamSwitcher2 ) )
		{		 
			EndExtraCamAnimScripted( player, 1 );
		}
		
		if ( IsString( _s.extraCamSwitcher3 ) )
		{		 
			EndExtraCamAnimScripted( player, 2 );
		}
		
		if ( IsString( _s.extraCamSwitcher4 ) )
		{		 
			EndExtraCamAnimScripted( player, 3 );
		}
	}
	
	function display_dev_info()
	{
	}
	
	function destroy_dev_info()
	{
	}
	
	function is_skipping_scene()
	{
		if( _s.name == "cin_ram_02_04_interview_part04" )
		{
			return false;	
		}

		return ( ( IS_TRUE(self.skipping_scene) || self._str_mode == "skip_scene" || self._str_mode == "skip_scene_player" )  );
	}
	
	function is_skipping_player_scene()
	{
		return ( IS_TRUE(self.b_player_scene) || self._str_mode == "skip_scene_player") && !array::contains(level.linked_scenes, _s.name);
	}
	
	function has_next_scene()
	{
		return isdefined(_s.nextscenebundle);
	}
	
	function run_next()
	{
		b_run_next_scene = false;
		
		if ( isdefined( _s.nextscenebundle ) )
		{     	       
			self waittill( "stopped", b_finished );
			
			if ( b_finished )
			{
				b_skip_scene = is_skipping_scene();
				
				if(b_skip_scene)
				{
					self util::waittill_any_timeout( 5, "scene_skip_completed");
				}
				
				if ( _s.scenetype == "fxanim" && IS_EQUAL( _s.nextscenemode, "init" ) )
				{
					if ( !error( !has_init_state(), "Scene can't init next scene '" + _s.nextscenebundle + "' because it doesn't have an init state." ) )
					{
						if ( allows_multiple() )
						{
							_e_root thread scene::init( _s.nextscenebundle, get_ents() );
						}
						else
						{
							_e_root thread scene::init( _s.nextscenebundle );
						}
					}
				}
				else
				{
					if(b_skip_scene)
					{
						if( is_skipping_player_scene() )
						{
							_str_mode = "skip_scene_player";
						}
						else
						{
							_str_mode = "skip_scene";
						}
					}
					else
					{
						b_run_next_scene = true;
					}
					
					if ( allows_multiple() )
					{
						_e_root thread scene::play( _s.nextscenebundle, get_ents(), undefined, undefined, undefined, _str_mode );
					}
					else
					{
						_e_root thread scene::play( _s.nextscenebundle, undefined, undefined, undefined, undefined, _str_mode );
					}
				}
			}
		}
		
		if( !IS_TRUE(b_run_next_scene) )
		{
			if(!is_skipping_scene()) //if we are not skipping a scene then just notify that the scene sequence has ended
			{
				if(is_scene_shared_sequence())
				{
					init_scene_sequence_started(false);
				}
			}
			else if(isdefined(level.linked_scenes)) //if we are skipping a scene, remove it from the linked scenes if it exists
			{
				ArrayRemoveValue(level.linked_scenes, _s.name );
			}

			streamer_request_completed();
		}
	}
	
	function streamer_request_completed()
	{
		if( IsString( _s._endStreamerHint ) )
		{
			if( GetDvarInt("scene_hide_player") > 0 )
			{
				foreach(player in level.players)
				{
					player Show();
				}
			}
			
			streamerRequest( "clear", _s._endStreamerHint );
		}
	}
		
	function stop( b_clear = false, b_finished = false )
	{
		if ( isdefined( _str_state ) )
		{
			if ( !b_finished )
			{
				streamer_request_completed();
			}
			
			//Handle the case where the scene was explicitly stopped
			if(!is_skipping_scene())
			{
				if ( !isdefined( _s.nextscenebundle ) && is_scene_shared_sequence())
				{
					init_scene_sequence_started(false);
				}
			}
			
			self thread sync_with_client_scene( "stop", b_clear );
			
			_str_state = undefined;
			
			self notify( "new_state" );
			self notify( "death" );
			
			level flagsys::clear( _str_name + "_playing" );
			level flagsys::clear( _str_name + "_initialized" );
			
			thread _call_state_funcs( "stop" );
			
			self.scene_stopping = true;
			
			if ( IsDefined( _a_objects ) && !b_finished )
			{
				foreach ( o_obj in _a_objects )
				{
					if ( isdefined( o_obj ) && ![[ o_obj ]]->in_a_different_scene() )
					{
						thread [[o_obj]]->stop( b_clear );
					}
				}
			}
			
			self thread _stop_camera_anims();
			
			self.scene_stopped = true;
			self notify( "stopped", b_finished );
			
			remove_from_sync_list();
									
			ArrayRemoveValue( level.active_scenes[ _str_name ], _e_root );
			
			if ( level.active_scenes[ _str_name ].size == 0 )
			{
				level.active_scenes[ _str_name ] = undefined;
			}
			
			if ( isdefined( _e_root ) )
			{
				ArrayRemoveValue( _e_root.scenes, self );
				
				if ( _e_root.scenes.size == 0 )
				{
					_e_root.scenes = undefined;
				}
				
				_e_root notify( "scene_done", _str_notify_name );
				_e_root.scene_played = true;
			}
		}
		
		if(IS_TRUE(_s.SpectateOnJoin))
		{
			level.scene_should_spectate_on_hot_join = undefined;
		}
		
		self thread _release_object();
	}
	
	function _release_object()
	{
		// HACK: Make sure all the objects release their handle to the scene
		WAIT_SERVER_FRAME;
		foreach ( o_obj in _a_objects )
		{
			o_obj._o_bundle = undefined;
		}
	}
	
	function has_init_state()
	{
		b_has_init_state = false;
		
		foreach ( o_scene_object in _a_objects )
		{
			if ( [[o_scene_object]]->has_init_state() )
			{
				b_has_init_state = true;
				break;
			}
		}
		
		return b_has_init_state;
	}
	
	function _call_state_funcs( str_state )
	{
		self endon( "stopped" );
		
		wait_till_scene_ready( undefined, true );
		
		if ( str_state == "play" )
		{
			waittillframeend;	// HACK: need to allow init callbacks to happen first if init and play happen on same frame
		}
		
		level notify( _str_notify_name + "_" + str_state );
		
		if ( isdefined( level.scene_funcs ) && isdefined( level.scene_funcs[ _str_notify_name ] ) && isdefined( level.scene_funcs[ _str_notify_name ][ str_state ] ) )
		{
			a_ents = get_ents();
		
			foreach ( handler in level.scene_funcs[ _str_notify_name ][ str_state ] )
			{
				func = handler[0];
				args = handler[1];
				
				switch ( args.size )
				{
					case 6:
						_e_root thread [[ func ]]( a_ents, args[0], args[1], args[2], args[3], args[4], args[5] );
						break;
					case 5:
						_e_root thread [[ func ]]( a_ents, args[0], args[1], args[2], args[3], args[4] );
						break;
					case 4:
						_e_root thread [[ func ]]( a_ents, args[0], args[1], args[2], args[3] );
						break;
					case 3:
						_e_root thread [[ func ]]( a_ents, args[0], args[1], args[2] );
						break;
					case 2:
						_e_root thread [[ func ]]( a_ents, args[0], args[1] );
						break;
					case 1:
						_e_root thread [[ func ]]( a_ents, args[0] );
						break;
					case 0:
						_e_root thread [[ func ]]( a_ents );
						break;
					default: AssertMsg( "Too many args passed to scene func." );
				}
			}
		}
	}
	
	function get_ents()
	{
		a_ents = [];
		foreach ( o_obj in _a_objects )
		{
			ent = [[o_obj]]->get_ent();
			
			if ( isdefined( o_obj._s.name ) )
			{
				a_ents[ o_obj._s.name ] = ent;
			}
			else
			{
				ARRAY_ADD( a_ents, ent );
			}
		}
		
		return a_ents;
	}
		
	function get_root()
	{
		return _e_root;
	}
	
	function get_align_ent()
	{
		e_align = _e_root;
		
		if ( isdefined( _s.aligntarget ) )
		{
			e_gdt_align = scene::get_existing_ent( _s.aligntarget, false, true );
			
			if ( isdefined( e_gdt_align ) )
			{
				e_align = e_gdt_align;
			}
			
			if ( !isdefined( e_gdt_align ) )
			{
				str_msg = "Align target '" + STR( _s.aligntarget ) + "' doesn't exist for scene.";
				
				if ( !warning( _testing, str_msg ) )
				{
					error( GetDvarInt( "scene_align_errors", 1 ), str_msg );
				}
			}
		}
		else if ( isdefined( _e_root.e_scene_link ) )
		{
			e_align = _e_root.e_scene_link;
		}
		
		return e_align;
	}
	
	function allows_multiple()
	{
		return IS_TRUE( _s.allowmultiple );
	}
	
	function is_looping()
	{
		return IS_TRUE( _s.looping );
	}
	
	function wait_till_scene_ready( o_exclude, b_ignore_streamer = false )
	{
		a_objects = [];
		
		if ( isdefined( o_exclude ) )
		{
			a_objects = array::exclude( _a_objects, o_exclude );
		}
		else
		{
			a_objects = _a_objects;
		}
		
		wait_till_objects_ready( a_objects );
		
		if ( _n_streamer_req != -1 )
		{
			if ( !b_ignore_streamer )
			{
				if ( isdefined( level.wait_for_streamer_hint_scenes ) )
				{
					if ( IsInArray( level.wait_for_streamer_hint_scenes, _s.name ) )
					{
						if ( !is_skipping_scene() )
						{
							level util::streamer_wait( _n_streamer_req, 0, 5 );
						}
					}
				}
			}
		}
		
		flagsys::set( "ready" );
		
		sync_with_other_scenes();
	}
	
	function wait_till_objects_ready( &array )
	{
		do
		{
			recheck = false;
		
			foreach ( ent in array )
			{
				if ( isdefined( ent ) && !ent flagsys::get( "ready" ) )
				{
					ent util::waittill_either( "death", "ready" );
					recheck = true;
					break;
				}
			}
		}
		while ( recheck );
	}
	
	function sync_with_other_scenes()
	{
		if ( !IS_TRUE( _s.DontSync ) && isdefined(level.scene_sync_list) && IsArray(level.scene_sync_list[ _n_request_time ]) )
		{
			// Wait for all scene objects that were requested to start on the same frame
			wait_till_objects_ready( level.scene_sync_list[ _n_request_time ] );
		}
	}
		
	function get_valid_objects()
	{
		a_obj = [];
		
		foreach ( obj in _a_objects )
		{
			if ( obj._is_valid )
			{
				ARRAY_ADD( a_obj, obj );
			}
		}
		
		return a_obj;
	}
	
	function on_error()
	{
		stop();
	}
	
	function get_state()
	{
		return _str_state;
	}
	
	function is_scene_shared()
	{
		if( !IS_TRUE(_s.skip_scene) && !(_s scene::is_igc()) )
		{
			foreach ( o_scene_object in _a_objects )
			{
				if ( o_scene_object._is_valid && [[o_scene_object]]->is_shared_player())
				{
					b_shared_player = true;
				}
			}
			
			if(!isdefined(b_shared_player))
			{
				self notify("scene_skip_completed");
				
				return false;
			}
		}
		
		return true;
	}
	
	function skip_scene( b_sequence )
	{
		if(IS_TRUE(b_sequence) && IS_TRUE(_s.DisableSceneSkipping))
		{
			finish_skip_scene();
			return;
		}
		
		if( !IS_TRUE(b_sequence) )
		{	
			if(_str_state == "init")
			{
				while(_str_state == "init")
				{
					wait 0.05;
				}
			}
			
			if( is_skipping_player_scene() )
			{
				b_skip_fading = false;
				if(!IS_TRUE(b_skip_fading))
		        {
					//Freeze player controls
					foreach(player in level.players)
					{
						player FreezeControls( true );
					}
					
					level.suspend_scene_skip_until_fade = true;
		          	level thread lui::screen_fade( 1, 1, 0, "black", false, "scene_system" );
		          	wait 1;
		          	level.suspend_scene_skip_until_fade = undefined;
		        }
				
				SetPauseWorld( false );
			}
			
			while(IS_TRUE(level.suspend_scene_skip_until_fade))
			{
				wait 0.05;
			}
		}
			
		if(isdefined( _s.nextscenebundle ))
		{
			bNextSceneExist = true;
		}
		else
		{
			bNextSceneExist = false;
		}
			
		wait_till_scene_ready();
		
		wait 0.05;
		
		_call_state_funcs("skip_started");

		thread _skip_scene();
		
		scene_skip_timeout = GetTime() + 4000;
		
		while( !IS_TRUE(self.scene_stopped) && GetTime() < scene_skip_timeout )
		{
			wait 0.05;
		}

		_call_state_funcs("skip_completed");
		self notify("scene_skip_completed");
		
		if(!bNextSceneExist)
		{
			if(is_skipping_player_scene())
			{
				if(isdefined(level.linked_scenes))
				{
					linked_scenes_timeout = GetTime() + 4000;
					while(level.linked_scenes.size > 0 && GetTime() < linked_scenes_timeout)
					{
						wait 0.05;
					}
				}
				
				finish_skip_scene();
			}
			else if(IS_TRUE(self.skipping_scene))
			{
				self.skipping_scene = undefined;
				
				if(isdefined(level.linked_scenes))
				{
					//level.skipping_linked_scenes--;
					ArrayRemoveValue(level.linked_scenes, _s.name );
				}
			}
		}
		else
		{
			if(is_skipping_player_scene())
			{
				if( _s scene::is_igc() )
				{
					foreach(player in level.players)
					{
						player stopsounds();
					}
				}
			}
		}
	}
	
	function private finish_skip_scene()
	{
		if(isdefined(level.player_skipping_scene))
		{
			//Send a notify to the client that the skipping is completed.
			foreach(player in level.players)
			{
				player clientfield::increment_to_player( "player_scene_skip_completed" );
				player FreezeControls( false );
				
				//Stop sounds on the player
				player stopsounds();
			}
			
			self.b_player_scene = undefined;
			self.skipping_scene = undefined;
			level.player_skipping_scene = undefined;
			level.linked_scenes = undefined;
			init_scene_sequence_started( false );
			level notify("scene_skip_sequence_ended");
			
			BONUSZM_SCENE_SEQUENCE_ENDED_CALLBACK(_s.name);
			
			b_skip_fading = false;
			if ( !IS_TRUE( b_skip_fading ) )
	        {
				if ( !IS_TRUE( level.level_ending ) )
				{
					level thread lui::screen_fade( 1, 0, 1, "black", false, "scene_system" );
				}
			}
		}
	}
	
	function private _skip_scene()
	{
		self endon( "stopped" );
		
		wait 0.05; //wait one frame to make sure all entities spawned since clientfields cannot be sent on the same spawn frame.
		
		//animations on clients
		foreach ( o_scene_object in _a_objects )
		{
			if ( o_scene_object._is_valid )
			{
				[[o_scene_object]]->skip_scene_on_client();
			}
		}
		
		wait 0.05; //wait one frame to give the clients a chance to process their animations
		
		//animations on server
		foreach ( o_scene_object in _a_objects )
		{
			if ( o_scene_object._is_valid )
			{
				[[o_scene_object]]->skip_scene_on_server();
			}
		}
		
		self notify( "skip_camera_anims" );
	}
	
	function should_skip_linked_to_players_scene()
	{
		if(isdefined(level.player_skipping_scene) && !IS_TRUE(_s.DisableSceneSkipping) && array::contains(level.linked_scenes, _s.name))
		{
			return true;
		}
		
		return false;
	}
	
	function private is_scene_shared_sequence()
	{
		return isdefined(level.shared_scene_sequence_started) && isdefined(_s.shared_scene_sequence);
	}
	
	function private update_scene_sequence()
	{
		if(isdefined(_s.shared_scene_sequence))
		{
			if(isdefined(level.shared_scene_sequence_started))
			{
				level.shared_scene_sequence_name = _s.name;
			}
			else
			{
				level.shared_scene_sequence_name = undefined;
			}
		}
	}
	
	function private init_scene_sequence_started( b_started)
	{		
		if(IS_TRUE(b_started))
		{
			scene::waittill_skip_sequence_completed();
			
			if(isdefined(level.shared_scene_sequence_started))
			{
				return;
			}
			
			_s.shared_scene_sequence = true;
			
			if(isdefined(_s.s_female_bundle))
			{
				_s.s_female_bundle.shared_scene_sequence = _s.shared_scene_sequence;
			}
			
			if ( IsString( _s.nextscenebundle ) )
			{
				s_cur_bundle = scene::get_scenedef( _s.nextscenebundle );
				while( true )
				{
					s_cur_bundle.shared_scene_sequence = _s.shared_scene_sequence;
					
					if(isdefined(s_cur_bundle.s_female_bundle))
					{
						s_cur_bundle.s_female_bundle.shared_scene_sequence = _s.shared_scene_sequence;
					}
					
					if ( IsString( s_cur_bundle.nextscenebundle ) )
					{
						s_cur_bundle = scene::get_scenedef( s_cur_bundle.nextscenebundle );
					}
					else
					{
						break;
					}
				}
			}
			
			level.shared_scene_sequence_started = true;
			update_scene_sequence();
			level notify("scene_sequence_started");
		}
		else
		{
			if(!isdefined(level.shared_scene_sequence_started))
			{
				return;
			}
			
			if(isdefined(_s.shared_scene_sequence))
			{
				level.shared_scene_sequence_started = undefined;
				update_scene_sequence();
				level notify("scene_sequence_ended", _s.name);
			}
		}
	}
		
	function private trigger_scene_sequence_started( scene_object, entity )
	{
		if(self === scene_object)
		{
			if(!is_skipping_scene())
			{
				init_scene_sequence_started( true );
			}
			
			return;
		}
		
		if ( IsPlayer( entity ) )
		{
			if ( !IS_TRUE( _s.DisableSceneSkipping ) && !is_skipping_scene())
			{
				if ( [[scene_object]]->is_shared_player() || (_s scene::is_igc()) )
				{
					if(_str_state != "init" || (isdefined(scene_object._s.initanim) || isdefined(scene_object._s.initanimloop)))
					{
						init_scene_sequence_started( true );
					}
				}
			}
		}
	}
	
	function has_player()
	{
		foreach ( obj in _a_objects )
		{
			if ( IS_EQUAL( obj._s.type, "player" ) )
			{
				return true;
			}
		}
		
		return false;
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    _    __      __    _     ___   ___   _  _   ___   ___   ___     ___    ___   ___   _  _   ___      ___    ___      _   ___    ___   _____ 
//   /_\   \ \    / /   /_\   | _ \ | __| | \| | | __| / __| / __|   / __|  / __| | __| | \| | | __|    / _ \  | _ )  _ | | | __|  / __| |_   _|
//  / _ \   \ \/\/ /   / _ \  |   / | _|  | .` | | _|  \__ \ \__ \   \__ \ | (__  | _|  | .` | | _|    | (_) | | _ \ | || | | _|  | (__    | |  
// /_/ \_\   \_/\_/   /_/ \_\ |_|_\ |___| |_|\_| |___| |___/ |___/   |___/  \___| |___| |_|\_| |___|    \___/  |___/  \__/  |___|  \___|   |_|  
//                                                                                                                                              
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class cAwarenessSceneObject : cSceneObject
{
	function play( str_alert_state )
	{
		NEW_STATE( "play" );
		
		switch ( str_alert_state )
		{
			case "low_alert":
				log( "LOW ALERT" );
				if ( isdefined( _s.LowAlertAnim ) )
				{
					_str_death_anim = _s.LowAlertAnimDeath;
					_str_death_anim_loop = _s.LowAlertAnimDeathLoop;
						
					_play_anim( _s.LowAlertAnim );
				}
				break;
			case "high_alert":
				log( "HIGH ALERT" );
				if ( isdefined( _s.HighAlertAnim ) )
				{
					_str_death_anim = _s.HighAlertAnimDeath;
					_str_death_anim_loop = _s.HighAlertAnimDeathLoop;
					
					_play_anim( _s.HighAlertAnim );
				}
				break;
			case "combat":
				log( "COMBAT ALERT" );
				if ( isdefined( _s.CombatAlertAnim ) )
				{
					_str_death_anim = _s.CombatAlertAnimDeath;
					_str_death_anim_loop = _s.CombatAlertAnimDeathLoop;
					
					_play_anim( _s.CombatAlertAnim );
				}
				break;
			default: error( 1, "Unsupported alert state" );
		}
		
		thread finish();
	}
	
	function _prepare()
	{
		if ( cSceneObject::_prepare() )
		{		
			if ( IsAI( _e ) )
			{
				thread _on_alert_run_scene_thread();
			}
		}
	}
	
	function _on_alert_run_scene_thread()
	{
		self endon( "play" );
		self endon( "done" );
	
		_e waittill( "alert", str_alert_state );
		
		thread [[scene()]]->play( str_alert_state );
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    _    __      __    _     ___   ___   _  _   ___   ___   ___     ___    ___   ___   _  _   ___ 
//   /_\   \ \    / /   /_\   | _ \ | __| | \| | | __| / __| / __|   / __|  / __| | __| | \| | | __|
//  / _ \   \ \/\/ /   / _ \  |   / | _|  | .` | | _|  \__ \ \__ \   \__ \ | (__  | _|  | .` | | _| 
// /_/ \_\   \_/\_/   /_/ \_\ |_|_\ |___| |_|\_| |___| |___/ |___/   |___/  \___| |___| |_|\_| |___|
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class cAwarenessScene : cScene
{
	function new_object()
	{
		return new cAwarenessSceneObject();
	}
	
	function init( str_scenedef, s_scenedef, e_align, a_ents, b_test_run )
	{
		cScene::init( str_scenedef, s_scenedef, e_align, a_ents, b_test_run );
	}
	
	function play( str_awareness_state = "low_alert" )
	{
		self notify( "new_state" );
		self endon( "new_state" );
		
		if ( get_valid_objects().size > 0 )
		{
			foreach ( o_obj in _a_objects )
			{
				thread [[o_obj]]->play( str_awareness_state );
			}
			
			level flagsys::set( _str_name + "_playing" );
			_str_state = "play";
			
			wait_till_scene_ready();

			thread _call_state_funcs( str_awareness_state );
			
			array::flagsys_wait_any_flag( _a_objects, "done", "main_done" );

			if ( is_looping() )
			{
				if ( has_init_state() )
				{
					// TODO: do this on return to unaware?
					//level flagsys::clear( _str_name + "_playing" );					
					//thread initialize();
				}
			}
			else
			{
				thread stop();
			}
		}
		else
		{
			thread stop( false, true );
		}
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  _  _   ___   _      ___   ___   ___   ___ 
// | || | | __| | |    | _ \ | __| | _ \ / __|
// | __ | | _|  | |__  |  _/ | _|  |   / \__ \
// |_||_| |___| |____| |_|   |___| |_|_\ |___/
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function get_existing_ent( str_name, b_spawner_only = false, b_nodes_and_structs = false )
{
	e = undefined;
	
	if ( b_spawner_only )
	{
		e_array = GetSpawnerArray( str_name, "script_animname" );	// a spawner exists with script_animname
		if ( e_array.size == 0 )
		{
			e_array = GetSpawnerArray( str_name, "targetname" );	// lastly grab any ent with targetname
		}
		
		Assert( e_array.size <= 1, "Multiple spawners found." );
		
		foreach ( ent in e_array )
		{
			if ( !isdefined( ent.isDying ) )
			{
				e = ent;
				break;
			}
		}
	}
	else
	{
		e = GetEnt( str_name, "animname", false );	// entity already exists
		if ( !is_valid_ent( e ) )
		{
			e = GetEnt( str_name, "script_animname" );	// a spawner exists with script_animname
			if ( !is_valid_ent( e ) )
			{
				e = GetEnt( str_name + "_ai", "targetname", true );	// any already spawned AI
				if ( !is_valid_ent( e ) )
				{
					e = GetEnt( str_name + "_vh", "targetname", true );	// any already spawned vehicles
					if ( !is_valid_ent( e ) )
					{
						e = GetEnt( str_name, "targetname", true );	// any spawned ents that don't have a targetname suffix
						if ( !is_valid_ent( e ) )
						{
							e = GetEnt( str_name, "targetname" );	// lastly grab any ent with targetname
							if ( !is_valid_ent( e ) && b_nodes_and_structs )
							{
								e = GetNode( str_name, "targetname" );	// if no ent, grab node with targetname
								if ( !is_valid_ent( e ) )
								{
									e = struct::get( str_name, "targetname" );	// if no node, grab struct with targetname
								}
							}
						}
					}
				}
			}
		}
	}
	
	if ( !is_valid_ent( e ) )
	{
		e = undefined;
	}
	
	return e;
}

function is_valid_ent( ent )
{
	return ( isdefined( ent ) && ( ( !isdefined( ent.isDying ) && !ent ai::is_dead_sentient() ) || self._s.IgnoreAliveCheck === true ) );
}

function synced_delete()
{
	self endon( "death" );
	
	self.isDying = true;
	
	if ( isdefined( self.targetname ) )
	{
		self.targetname = self.targetname + "_sync_deleting";
	}
	
	if ( isdefined( self.animname ) )
	{
		self.animname = self.animname + "_sync_deleting";
	}
	
	if ( isdefined( self.script_animname ) )
	{
		self.script_animname = self.script_animname + "_sync_deleting";
	}
	
	if(!IsPlayer(self))
	{
		SetHideonClientWhenScriptedAnimCompleted( self );
		self StopAnimScripted();
	}
	else
	{
		WAIT_SERVER_FRAME;
		self Ghost();
	}
	
	self NotSolid();
	
	if(isAlive(self))
	{
		if(isSentient( self ))
		{
			self.ignoreall = true;
		}
		
		if(IsActor(self))
		{
			self PathMode("dont move");
		}
	}
	
	wait 1; //this will make the server wait until the client syned the transition to the next shot
	
	self delete();
}
	
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  _   _   _____   ___   _      ___   _____  __   __
// | | | | |_   _| |_ _| | |    |_ _| |_   _| \ \ / /
// | |_| |   | |    | |  | |__   | |    | |    \ V / 
//  \___/    |_|   |___| |____| |___|   |_|     |_|  
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

REGISTER_SYSTEM_EX( "scene", &__init__, &__main__, undefined )

function __init__()
{
	/* INIT SYSTEM VARS */
	
	level.scene_object_id = 0;	
	level.active_scenes = [];
	level.sceneSkippedCount = 0;
	level.wait_for_streamer_hint_scenes = [];
	streamerRequest( "clear" );
	
	foreach ( s_scenedef in struct::get_script_bundles( "scene" ) )
	{
		s_scenedef.editaction = undefined;	// only used in the asset editor
		s_scenedef.newobject = undefined;	// only used in the asset editor
		
		if ( IsString( s_scenedef.FemaleBundle ) )
		{
			// Set the MaleBundle attribute of female bundles so they know which male bundle they are associated with
			s_female_bundle = struct::get_script_bundle( "scene", s_scenedef.FemaleBundle );
			s_female_bundle.MaleBundle = s_scenedef.name;
			
			s_scenedef.s_female_bundle = s_female_bundle;
			s_female_bundle.s_male_bundle = s_scenedef;
		}
		
		if ( IsString( s_scenedef.NextSceneBundle ) )
		{
			
			foreach ( i, s_object in s_scenedef.objects )
			{
				// Disable transition fx between shots in chained bundles
				if ( IS_EQUAL( s_object.type, "player" ) )
				{			
					s_object.DisableTransitionOut = true;
				}
			}
			
			s_next_bundle = struct::get_script_bundle( "scene", s_scenedef.NextSceneBundle );
						
			s_next_bundle.DontSync = true;
			
			foreach ( i, s_object in s_next_bundle.objects )
			{
				// Disable transition fx between shots in chained bundles
				if ( IS_EQUAL( s_object.type, "player" ) )
				{			
					s_object.DisableTransitionIn = true;
				}
				
				//let he next scene know that it is a isCutScene (a scene was played before it);
				s_object.isCutScene = true;
			}
			
			// Do the same for the female bundle if one exists
			
			if ( isdefined( s_next_bundle.FemaleBundle ) )
			{
				s_next_female_bundle = struct::get_script_bundle( "scene", s_next_bundle.FemaleBundle );
				
				if ( isdefined( s_next_female_bundle ) )
				{
					s_next_female_bundle.DontSync = true;
				
					foreach ( i, s_object in s_next_female_bundle.objects )
					{
						// Disable transition fx between shots in chained bundles
						if ( IS_EQUAL( s_object.type, "player" ) )
						{			
							s_object.DisableTransitionIn = true;
						}
						
						//let he next scene know that it is a isCutScene (a scene was played before it);
						s_object.isCutScene = true;
					}
				}
			}
		}

		// if this bundle has a streamer hint then loop through the next bundles
		// and give them the same streamer hint
		if ( IsString( s_scenedef.streamerHint ) )
		{
			s_cur_bundle = s_scenedef;
			while( true )
			{
				s_cur_bundle._endStreamerHint = s_scenedef.streamerHint;
				if ( IsString( s_cur_bundle.NextSceneBundle ) )
				{
					s_cur_bundle = struct::get_script_bundle( "scene", s_cur_bundle.NextSceneBundle );
				}
				else
				{
					break;
				}
			}
		}

		foreach ( i, s_object in s_scenedef.objects )
		{
			if ( IS_EQUAL( s_object.type, "player" ) )
			{
				DEFAULT( s_object.cameratween, 0 );
				
				if ( isdefined( s_object.player ) )
				{
					s_object.player--;	// adjust for zero-based level.players index
				}
				else
				{
					s_object.player = 0;
				}
				
				s_object.name = "player " + ( s_object.player + 1 );
				s_object.NewPlayerMethod = true; // Fully switching over to new method, no longer supporting ol-style player linkto method
			}
			else
			{
				s_object.player = undefined;
			}
		}
		
		if ( s_scenedef.vmtype == "both" && !s_scenedef is_igc() )
		{
			n_clientbits = GetMinBitCountForNum( 3 );
			
			clientfield::register( "world", s_scenedef.name, VERSION_SHIP, n_clientbits, "int" );
		}
	}
	
	clientfield::register( "toplayer", "postfx_igc", VERSION_SHIP, 2, "counter" );
	clientfield::register( "world", "in_igc", VERSION_SHIP, 4, "int" );
	
	clientfield::register( "toplayer", "player_scene_skip_completed", VERSION_SHIP, 2, "counter" );
	
	clientfield::register( "allplayers", "player_scene_animation_skip", VERSION_SHIP, 2, "counter" );
	clientfield::register( "actor", "player_scene_animation_skip", VERSION_SHIP, 2, "counter" );
	clientfield::register( "vehicle", "player_scene_animation_skip", VERSION_SHIP, 2, "counter" );
	clientfield::register( "scriptmover", "player_scene_animation_skip", VERSION_SHIP, 2, "counter" );
		
	callback::on_connect( &on_player_connect );
	callback::on_disconnect( &on_player_disconnect );
}

function remove_invalid_scene_objects( s_scenedef )
{
	a_invalid_object_indexes = [];
	
	foreach ( i, s_object in s_scenedef.objects )
	{
		if ( !isdefined( s_object.name ) && !isdefined( s_object.model ) && !IS_EQUAL( s_object.type, "player" ) )
		{
			ARRAY_ADD( a_invalid_object_indexes, i );
		}
	}
	
	for ( i = a_invalid_object_indexes.size - 1; i >= 0 ; i-- )
	{
		ArrayRemoveIndex( s_scenedef.objects, a_invalid_object_indexes[i] );
	}
	
	return s_scenedef;
}

function __main__()
{
	/* RUN INSTANCES */
	
	a_instances = ArrayCombine(
							struct::get_array( "scriptbundle_scene", "classname" ),
	                        struct::get_array( "scriptbundle_fxanim", "classname" ),
	                        false, false
	                       );
	
	foreach ( s_instance in a_instances )
	{
		if ( isdefined( s_instance.linkto ) )
		{
			s_instance thread _scene_link();
		}
		
		if ( isdefined( s_instance.script_flag_set ) )
		{
			level flag::init( s_instance.script_flag_set );
		}
		
		if ( isdefined( s_instance.scriptgroup_initscenes ) )
		{
			foreach ( trig in GetEntArray( s_instance.scriptgroup_initscenes, "scriptgroup_initscenes" ) )
			{
				s_instance thread _trigger_init( trig );
			}
		}
		
		if ( isdefined( s_instance.scriptgroup_playscenes ) )
		{
			foreach ( trig in GetEntArray( s_instance.scriptgroup_playscenes, "scriptgroup_playscenes" ) )
			{
				s_instance thread _trigger_play( trig );
			}
		}
		
		if ( isdefined( s_instance.scriptgroup_stopscenes ) )
		{
			foreach ( trig in GetEntArray( s_instance.scriptgroup_stopscenes, "scriptgroup_stopscenes" ) )
			{
				s_instance thread _trigger_stop( trig );
			}
		}
	}
	
	level thread on_load_wait();
	level thread run_instances();
}

function private _scene_link()
{
	self.e_scene_link = util::spawn_model( "tag_origin", self.origin, self.angles );
	
	e_linkto = GetEnt( self.linkto, "linkname" );
	self.e_scene_link LinkTo( e_linkto );
	
	util::waittill_any_ents_two( self, "death", e_linkto, "death" ); // Delete link ent when either the scene root entity dies or the entity that it's linked to
	
	self.e_scene_link Delete();
}

function on_load_wait()
{
	// wait for client script so "both" type scenes will work properly on load.
	util::wait_network_frame();
	util::wait_network_frame();
	level flagsys::set( "scene_on_load_wait" );
}

function run_instances()
{
	foreach ( s_instance in struct::get_script_bundle_instances( "scene" ) )
	{
		if ( SPAWNFLAG( s_instance, SPAWNFLAG_SCRIPTBUNDLE_PLAY ) )
		{
			s_instance thread play();
		}
		else if ( SPAWNFLAG( s_instance, SPAWNFLAG_SCRIPTBUNDLE_INIT ) )
		{
			s_instance thread init();
		}
	}
}

function _trigger_init( trig )
{
	trig endon( "death" );
	
	trig trigger::wait_till();
		
	a_ents = [];
	if ( get_player_count( self.scriptbundlename ) > 0 )
	{
		if ( IsPlayer( trig.who ) )
		{
			a_ents[ 0 ] = trig.who;
		}
	}

	self thread _init_instance( undefined, a_ents );
}

function _trigger_play( trig )
{
	trig endon( "death" );
	
	do
	{	
		trig trigger::wait_till();
		
		a_ents = [];
		if ( get_player_count( self.scriptbundlename ) > 0 )
		{
			if ( IsPlayer( trig.who ) )
			{
				a_ents[ 0 ] = trig.who;
			}
		}
	
		self thread play( a_ents );
	}
	while ( IS_TRUE( get_scenedef( self.scriptbundlename ).looping ) );
}

function _trigger_stop( trig )
{
	trig endon( "death" );
	trig trigger::wait_till();
	self thread stop();
}

/@
"Summary: Adds a function to be called when a scene starts"
"SPMP: shared"


"Name: add_scene_func( str_scenedef, func, str_state = "play" )"
"CallOn: level"
"MandatoryArg: <str_scenedef> Name of scene"
"MandatoryArg: <func> function to call when scene starts"
"OptionalArg: [str_state] set to "init" or "done" if you want to the function to get called in one of those states"	
"Example: level scene::init( "my_scenes", "targetname" );"
@/
function add_scene_func( str_scenedef, func, str_state = "play", ... )
{
	/#
	Assert( isdefined( get_scenedef( str_scenedef ) ), "Trying to add a scene function for scene '" + str_scenedef + "' that doesn't exist." );
	#/
	
	DEFAULT( level.scene_funcs, [] );
	DEFAULT( level.scene_funcs[ str_scenedef ], [] );
	DEFAULT( level.scene_funcs[ str_scenedef ][ str_state ], [] );
	
	array::add( level.scene_funcs[ str_scenedef ][ str_state ], Array( func, vararg ), false );
}

/@
"Summary: Removes a function to be called when a scene starts"
"SPMP: shared"


"Name: remove_scene_func( str_scenedef, func, str_state = "play" )"
"CallOn: level"
"MandatoryArg: <str_scenedef> Name of scene"
"MandatoryArg: <func> function to remove"
"OptionalArg: [str_state] set to "init" or "done" if you want to the function to get removed from one of those states"
"Example: level scene::init( "my_scenes", "targetname" );"
@/
function remove_scene_func( str_scenedef, func, str_state = "play" )
{
	/#
	Assert( isdefined( get_scenedef( str_scenedef ) ), "Trying to remove a scene function for scene '" + str_scenedef + "' that doesn't exist." );
	#/
	
	DEFAULT( level.scene_funcs, [] );
	
	if ( isdefined( level.scene_funcs[ str_scenedef ] ) && isdefined( level.scene_funcs[ str_scenedef ][ str_state ] ) )
	{
		for ( i = level.scene_funcs[ str_scenedef ][ str_state ].size - 1; i >= 0; i-- )
		{
			if ( level.scene_funcs[ str_scenedef ][ str_state ][ i ][ 0 ] == func )
			{
				ArrayRemoveIndex( level.scene_funcs[ str_scenedef ][ str_state ], i );
			}
		}
	}
}

function get_scenedef( str_scenedef )
{
	return struct::get_script_bundle( "scene", str_scenedef );
}

function get_scenedefs( str_type = "scene" )
{
	a_scenedefs = [];
	
	foreach ( s_scenedef in struct::get_script_bundles( "scene" ) )
	{
		if ( s_scenedef.sceneType == str_type )
		{
			ARRAY_ADD( a_scenedefs, s_scenedef );
		}
	}
	
	return a_scenedefs;
}

/@
"Summary: Spawns a scene"
"SPMP: shared"


"Name: spawn( str_scenedef, v_origin, v_angles, ents )"
"CallOn: NA
"MandatoryArg: <str_scenedef> Name of scene to spawn"
"OptionalArg: [v_origin] The origin to spawn the scene at - defaults to (0, 0, 0)"
"OptionalArg: [v_angles] The angles to spawn the scene at - defaults to (0, 0, 0)"
"OptionalArg: [a_ents] Entities to use for the scene"
"Example: level scene::spawn( "my_scene", (99, 45, 156) );"


"Name: spawn( str_scenedef, ents, v_origin, v_angles )"
"CallOn: NA
"MandatoryArg: <str_scenedef> Name of scene to spawn"
"OptionalArg: [a_ents] Entities to use for the scene"
"OptionalArg: [v_origin] The origin to spawn the scene at - defaults to (0, 0, 0)"
"OptionalArg: [v_angles] The angles to spawn the scene at - defaults to (0, 0, 0)"
"Example: level scene::spawn( "my_scene", array( my_ent1, my_ent2 ) );"
@/
function spawn( arg1, arg2, arg3, arg4, b_test_run )
{
	str_scenedef = arg1;
	
	Assert( isdefined( str_scenedef ), "Cannot create a scene without a scene def." );
	
	if ( IsVec( arg2 ) )
	{
		v_origin = arg2;
		v_angles = arg3;
		a_ents = arg4;
	}
	else	// overloaded the params so you can put them in different orders
	{
		a_ents = arg2;
		v_origin = arg3;
		v_angles = arg4;
	}
	
	s_instance = SpawnStruct();
	s_instance.origin = ( isdefined( v_origin ) ? v_origin : (0, 0, 0) );
	s_instance.angles = ( isdefined( v_angles ) ? v_angles : (0, 0, 0) );
	s_instance.classname = "scriptbundle_scene";
	s_instance.scriptbundlename = str_scenedef;
	s_instance struct::init();
	
	s_instance scene::init( str_scenedef, a_ents, undefined, b_test_run );
		
	return s_instance;
}

/@
"Summary: Initializes a scene or multiple scenes"
"SPMP: shared"
	

"Name: init( str_val, str_key, ents )"
"CallOn: level using KVP to specify the scene instances"
"MandatoryArg: <str_val> value of the KVP of the scene entity"
"MandatoryArg: <str_key> key of the KVP of the scene entity"
"OptionalArg: [ents] override the entities used for this scene"
"Example: level scene::init( "my_scenes", "targetname" );"
	

"Name: init( str_scenedef, ents )"
"CallOn: level"
"MandatoryArg: <str_scenedef> specify the scene name, will play all instances of this scene"
"OptionalArg: [ents] override the entities used for this scene"
"Example: level scene::init( "level1_scene_3" );"
	
	
"Name: init( str_scenedef, ents )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"OptionalArg: [ents] override the entities used for this scene"
"Example: e_scene_root scene::init( "level1_scene_3" );"
	
	
"Name: init( ents, str_scenedef )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [ents] override the entities used for this scene"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"Example: s_scene_object scene::init( array( e_guy1, e_guy2 ) );"
@/
function init( arg1, arg2, arg3, b_test_run )
{
	if ( self == level )
	{
		if ( IsString( arg1 ) )
		{
			if ( IsString( arg2 ) )
			{
				str_value	= arg1;
				str_key		= arg2;
				a_ents		= arg3;
			}
			else
			{
				str_value	= arg1;
				a_ents		= arg2;
			}
			
			if ( isdefined( str_key ) )
			{
				a_instances = struct::get_array( str_value, str_key );
				
				/#
					Assert( a_instances.size, "No scene instances with KVP '" + str_key + "'/'" + str_value + "'." );
				#/
			}
			else
			{
				a_instances = struct::get_array( str_value, "targetname" );
				if ( !a_instances.size )
				{
					a_instances = struct::get_array( str_value, "scriptbundlename" );
				}
			}
			
			if ( !a_instances.size )
			{
				_init_instance( str_value, a_ents, b_test_run );
			}
			else
			{
				foreach ( s_instance in a_instances )
				{
					if ( isdefined( s_instance ) )
					{
						s_instance thread _init_instance( undefined, a_ents, b_test_run );
					}
				}
			}
		}
	}
	else
	{
		if ( IsString( arg1 ) )
		{
			_init_instance( arg1, arg2, b_test_run );
		}
		else
		{		
			_init_instance( arg2, arg1, b_test_run );
		}
		
		return self;
	}
}

function _init_instance( str_scenedef, a_ents, b_test_run = false )
{
	level flagsys::wait_till( "scene_on_load_wait" );
	
	DEFAULT( str_scenedef, self.scriptbundlename );
	
	s_bundle = get_scenedef( str_scenedef );
	
	/#
	
	Assert( isdefined( str_scenedef ), "Scene at (" + ( isdefined( self.origin ) ? self.origin : "level" ) + ") is missing its scene def." );
	Assert( isdefined( s_bundle ), "Scene at (" + ( isdefined( self.origin ) ? self.origin : "level" ) + ") is using a scene name '" + str_scenedef + "' that doesn't exist." );
	
	#/
	
	o_scene = get_active_scene( str_scenedef );
	
	if ( !isdefined( o_scene ) )
	{
		if ( s_bundle.scenetype == "awareness" )
		{
			o_scene = new cAwarenessScene();
		}
		else
		{
			o_scene = new cScene();
		}
		
		s_bundle = _load_female_scene( s_bundle, a_ents );
		
		[[o_scene]]->init( s_bundle.name, s_bundle, self, a_ents, b_test_run );
	}
	else
	{
		thread [[o_scene]]->initialize( a_ents, true );
	}
	
	return o_scene;
}

function private _load_female_scene( s_bundle, a_ents )
{
	/* Check if this bundle has a player object */
	
	b_has_player = false;
	foreach ( s_object in s_bundle.objects )
	{
		if ( !isDefined( s_object ) )
			continue;
		
		if ( IS_EQUAL( s_object.type, "player" ) )
		{
			b_has_player = true;
			break;
		}
	}
	
	/* Check if if a player was passed in to use for the scene */
	
	if ( b_has_player )
	{
		e_player = undefined;	
		if ( IsPlayer( a_ents ) )
		{
			e_player = a_ents;
		}
		else if ( IsArray( a_ents ) )
		{
			foreach ( ent in a_ents )
			{
				if ( IsPlayer( ent ) )
				{
					e_player = ent;
					break;
				}
			}
		}
		
		/* Default to first player none are passed in */
		
		if ( !isdefined( e_player ) )
		{
			e_player = level.activeplayers[0];
		}
	
		if ( IsPlayer( e_player ) && e_player util::is_female() )
		{
			if ( isdefined( s_bundle.FemaleBundle ) )
			{
				s_female_bundle = struct::get_script_bundle( "scene", s_bundle.FemaleBundle );
				if ( isdefined( s_female_bundle ) )
				{
					return s_female_bundle;
				}
			}
		}
	}
	
	return s_bundle;
}

/@
"Summary: Plays a scene or multiple scenes"
"SPMP: shared"


"Name: play( str_val, str_key, ents )"
"CallOn: level using KVP to specify the scene instances"
"MandatoryArg: <str_val> value of the KVP of the scene entity"
"MandatoryArg: <str_key> key of the KVP of the scene entity"
"OptionalArg: [ents] override the entities used for this scene"
"Example: level scene::play( "my_scenes", "targetname" );"


"Name: play( str_scenedef, ents )"
"CallOn: level"
"MandatoryArg: <str_scenedef> specify the scene name, will play all instances of this scene"
"OptionalArg: [ents] override the entities used for this scene"	
"Example: level scene::play( "level1_scene_3" );"

	
"Name: play( str_scenedef, ents )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"OptionalArg: [ents] override the entities used for this scene"	
"Example: e_scene_root scene::play( "level1_scene_3" );"


"Name: play( ents, str_scenedef )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [ents] override the entities used for this scene"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"Example: s_scene_object scene::play( array( e_guy1, e_guy2 ) );"
@/
function play( arg1, arg2, arg3, b_test_run = false, str_state, str_mode = "" )
{
	if(isdefined(arg1) && IsString(arg1) && arg1 == "p7_fxanim_zm_castle_rocket_bell_tower_bundle")
	{
		arg1 = arg1;
	}
	
	
	s_tracker = SpawnStruct();
	s_tracker.n_scene_count = 1;
	
	if ( self == level )
	{
		if ( IsString( arg1 ) )
		{
			if ( IsString( arg2 ) )
			{
				str_value	= arg1;
				str_key		= arg2;
				a_ents		= arg3;
			}
			else
			{
				str_value	= arg1;
				a_ents		= arg2;
			}
			
			str_scenedef = str_value;
			
			if ( isdefined( str_key ) )
			{
				a_instances = struct::get_array( str_value, str_key );
				
				str_scenedef = undefined; // use struct scenedef
				
				/#
					Assert( a_instances.size, "No scene instances with KVP '" + str_key + "'/'" + str_value + "'." );
				#/
			}
			else
			{
				a_instances = struct::get_array( str_value, "targetname" );
				if ( !a_instances.size )
				{
					a_instances = struct::get_array( str_value, "scriptbundlename" );
				}
				else
				{
					str_scenedef = undefined; // use struct scenedef
				}
			}
			
			if ( isdefined( str_scenedef ) )
			{			
				a_active_instances = get_active_scenes( str_scenedef );
				a_instances = ArrayCombine( a_active_instances, a_instances, false, false );
			}
			
			if ( !a_instances.size )
			{
				self thread _play_instance( s_tracker, str_scenedef, a_ents, b_test_run, undefined, str_mode );
			}
			else
			{
				s_tracker.n_scene_count = a_instances.size;
					
				foreach ( s_instance in a_instances )
				{
					if ( isdefined( s_instance ) )
					{
						s_instance thread _play_instance( s_tracker, str_scenedef, a_ents, b_test_run, str_state, str_mode );
					}
				}
			}
		}
	}
	else
	{
		if ( IsString( arg1 ) )
		{
			self thread _play_instance( s_tracker, arg1, arg2, b_test_run, str_state, str_mode );
		}
		else
		{		
			self thread _play_instance( s_tracker, arg2, arg1, b_test_run, str_state, str_mode );
		}
	}
	
	for ( i = 0; i < s_tracker.n_scene_count; i++ )
	{	
		s_tracker waittill( "scene_done" );
	}
}

function _play_instance( s_tracker, str_scenedef, a_ents, b_test_run = false, str_state, str_mode )
{	
	DEFAULT( str_scenedef, self.scriptbundlename );
		
	if ( self.scriptbundlename === str_scenedef ) // Radiant placed scene, only play once unless specified to play more than once
	{
		if ( !IS_TRUE( self.script_play_multiple ) )
		{
			if ( IS_TRUE( self.scene_played ) && !b_test_run )
			{
				waittillframeend;
				while ( is_playing( str_scenedef ) )
				{
					WAIT_SERVER_FRAME;
				}
				
				s_tracker notify( "scene_done" );
				return;
			}
		}
		
		self.scene_played = true;
	}
		
	o_scene = _init_instance( str_scenedef, a_ents, b_test_run );

	if ( IsDefined(o_scene) )
	{
		
		if( (!isdefined(str_mode) || str_mode == "") && [[o_scene]]->should_skip_linked_to_players_scene() )
		{
			skip_scene( o_scene._s.name, false, false, true);
		}
		
		thread [[o_scene]]->play( str_state, a_ents, b_test_run, str_mode );
	}
		
	self waittillmatch( "scene_done", str_scenedef );
	
	if ( isdefined( self ) )
	{	
		if ( isdefined( self.scriptbundlename ) && IS_TRUE( get_scenedef( self.scriptbundlename ).looping ) )
		{
			self.scene_played = false;
		}
		
		if ( isdefined( self.script_flag_set ) )
		{
			level flag::set( self.script_flag_set );
		}
	}
	
	s_tracker notify( "scene_done" );
}

/@
"Summary: Skipts a scene or multiple scenes to the end state (last frame or looping animation).  Look at scene::play() for all the various ways this can be called."
"SPMP: shared"
"OptionalArg: [n_time] Value between 0 and 1 to only skip through a portion of the scene. 0 will start at the beginning of the scene, 1 skips completely to the end."	
"Example: level scene::skipto_end( "my_scene" );"
@/
function skipto_end( arg1, arg2, arg3, n_time, b_include_players = false )
{
	str_mode = "skipto";
	
	if ( !b_include_players )
	{
		str_mode += "_noplayers";
	}
	
	if ( isdefined( n_time ) )
	{
		str_mode += ":" + n_time;
	}
	
	play( arg1, arg2, arg3, false, undefined, str_mode );
}

/@
"Summary: Skipts a scene or multiple scenes to the end state (last frame or looping animation), but skips AI.  Look at scene::play() for all the various ways this can be called."
"SPMP: shared"
"OptionalArg: [n_time] Value between 0 and 1 to only skip through a portion of the scene. 0 will start at the beginning of the scene, 1 skips completely to the end."
"Example: level scene::skipto_end_noai( "my_scene" );"
@/
function skipto_end_noai( arg1, arg2, arg3, n_time )
{
	str_mode = "skipto_noai_noplayers";
	if ( isdefined( n_time ) )
	{
		str_mode += ":" + n_time;
	}
	
	play( arg1, arg2, arg3, false, undefined, str_mode );
}

/@
"Summary: Stops a scene or multiple scenes"
"SPMP: shared"


"Name: stop( str_val, str_key, b_clear )"
"CallOn: level using KVP to specify the scene instances"
"MandatoryArg: <str_val> value of the KVP of the scene entity"
"MandatoryArg: <str_key> key of the KVP of the scene entity"
"OptionalArg: [b_clear] optionally delete the ents if they were spawned by the scene, regardless of options in scene definition"	
"Example: level scene::stop( "my_scenes", "targetname" );"
	
	
"Name: stop( str_scenedef, b_clear )"
"CallOn: level"
"MandatoryArg: <str_scenedef> specify the scene name, will stop all instances of this scene"
"OptionalArg: [b_clear] optionally delete the ents if they were spawned by the scene, regardless of options in scene definition"
"Example: level scene::stop( "level1_scene_3" );"
	
	
"Name: stop( str_scenedef, b_clear )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [str_scenedef] specify the scene name if multiple scenes are running on the entity"
"OptionalArg: [b_clear] optionally delete the ents if they were spawned by the scene, regardless of options in scene definition"
"Example: e_my_scene scene::stop( "level1_scene_3" );"
	
	
"Name: stop( b_clear, str_scenedef )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [b_clear] optionally delete the ents if they were spawned by the scene, regardless of options in scene definition"
"OptionalArg: [str_scenedef] specify the scene name if multiple scenes are running on the entity"
"Example: s_scene_object scene::stop( true );"
@/
function stop( arg1, arg2, arg3 )
{
	if ( self == level )
	{
		if ( IsString( arg1 ) )
		{
			if ( IsString( arg2 ) )
			{
				str_value	= arg1;
				str_key		= arg2;
				b_clear		= arg3;
			}
			else
			{
				str_value	= arg1;
				b_clear		= arg2;
			}
			
			if ( isdefined( str_key ) )
			{
				a_instances = struct::get_array( str_value, str_key );
				
				/#
					Assert( a_instances.size, "No scene instances with KVP '" + str_key + "'/'" + str_value + "'." );
				#/
					
				str_value = undefined;
			}
			else
			{
				a_instances = struct::get_array( str_value, "targetname" );
				if ( !a_instances.size )
				{
					a_instances = get_active_scenes( str_value );
				}
				else
				{
					str_value = undefined;
				}
			}
			
			foreach ( s_instance in ArrayCopy( a_instances ) )
			{
				if ( isdefined( s_instance ) )
				{
					s_instance _stop_instance( b_clear, str_value );
				}
			}
		}
	}
	else
	{
		if ( IsString( arg1 ) )
		{
			_stop_instance( arg2, arg1 );
		}
		else
		{
			_stop_instance( arg1 );
		}
	}
}

function _stop_instance( b_clear = false, str_scenedef )
{
	if ( isdefined( self.scenes ) )
	{
		foreach ( o_scene in ArrayCopy( self.scenes ) )
		{
			str_scene_name = [[o_scene]]->get_name();
			
			if ( !isdefined( str_scenedef ) || ( str_scene_name == str_scenedef ) )
			{
				thread [[o_scene]]->stop( b_clear );
			}
		}
	}
}

function has_init_state( str_scenedef )
{
	s_scenedef = get_scenedef( str_scenedef );
	foreach ( s_obj in s_scenedef.objects )
	{
		if ( !IS_TRUE( s_obj.disabled ) && s_obj _has_init_state() )
		{
			return true;
		}
	}
	
	return false;
}

function _has_init_state()
{
	return ( IS_TRUE( self.spawnoninit ) || isdefined( self.initanim ) || isdefined( self.initanimloop ) || IS_TRUE( self.firstframe ) );
}

/@
"Summary: returns the number of props defined for a scene"
"SPMP: shared"


"Name: get_prop_count( str_scenedef )"
"CallOn: Any"
"MandatoryArg: <str_scenedef> scene definition name (from gdt)"
"Example: level scene::get_prop_count( "my_scene" );"

	
"Name: get_prop_count()"
"CallOn: scene object"
"Example: s_scene scene::get_prop_count();"
@/
function get_prop_count( str_scenedef )
{
	return _get_type_count( "prop", str_scenedef );
}

/@
"Summary: returns the number of vehicles defined for a scene"
"SPMP: shared"


"Name: get_vehicle_count( str_scenedef )"
"CallOn: Any"
"MandatoryArg: <str_scenedef> scene definition name (from gdt)"
"Example: level scene::get_vehicle_count( "my_scene" );"

	
"Name: get_vehicle_count()"
"CallOn: scene object"
"Example: s_scene scene::get_vehicle_count();"
@/
function get_vehicle_count( str_scenedef )
{
	return _get_type_count( "vehicle", str_scenedef );
}

/@
"Summary: returns the number of actors defined for a scene"
"SPMP: shared"


"Name: get_actor_count( str_scenedef )"
"CallOn: Any"
"MandatoryArg: <str_scenedef> scene definition name (from gdt)"
"Example: level scene::get_actor_count( "my_scene" );"

	
"Name: get_actor_count()"
"CallOn: scene object"
"Example: s_scene scene::get_actor_count();"
@/
function get_actor_count( str_scenedef )
{
	return _get_type_count( "actor", str_scenedef );
}

/@
"Summary: returns the number of players defined for a scene"
"SPMP: shared"


"Name: get_player_count( str_scenedef )"
"CallOn: Any"
"MandatoryArg: <str_scenedef> scene definition name (from gdt)"
"Example: level scene::get_player_count( "my_scene" );"

	
"Name: get_player_count()"
"CallOn: scene object"
"Example: s_scene scene::get_player_count();"
@/
function get_player_count( str_scenedef )
{
	return _get_type_count( "player", str_scenedef );
}

function _get_type_count( str_type, str_scenedef )
{
	s_scenedef = ( isdefined( str_scenedef ) ? get_scenedef( str_scenedef ) : get_scenedef( self.scriptbundlename ) );
	
	n_count = 0;
	foreach ( s_obj in s_scenedef.objects )
	{
		if ( isdefined( s_obj.type ) )
		{
			if ( ToLower( s_obj.type ) == ToLower( str_type ) )
			{
				n_count++;
			}
		}
	}
	
	return n_count;
}

/@
"Summary: Checks if a scene is playing"
"SPMP: shared"

"Name: is_active( str_scenedef )"
"CallOn: level or a scene instance"
"OptionalArg: [str_scenedef] The name of the scene to check"
"Example: level scene::is_active( "my_scene" );"
"Example: s_scene scene::is_active();"
@/
function is_active( str_scenedef )
{
	if ( self == level )
	{
		return ( get_active_scenes( str_scenedef ).size > 0 );
	}
	else
	{
		return ( isdefined( get_active_scene( str_scenedef ) ) );
	}
}

/@
"Summary: Checks if a scene is playing"
"SPMP: shared"

"Name: is_playing( str_scenedef )"
"OptionalArg: [str_scenedef] The name of the scene to check"
"Example: s_scene scene::is_playing( "my_scene" );"
"Example: s_scene scene::is_playing();"
@/
function is_playing( str_scenedef )
{
	if ( self == level )
	{
		return ( level flagsys::get( str_scenedef + "_playing" ) );
	}
	else
	{
		DEFAULT( str_scenedef, self.scriptbundlename );
		
		o_scene = get_active_scene( str_scenedef );
		if ( isdefined( o_scene ) )
		{
			return ( IS_EQUAL( o_scene._str_state, "play" ) );
		}
	}
	
	return false;
}

/@
"Summary: Checks if a scene is ready"
"SPMP: shared"

"Name: is_ready( str_scenedef )"
"OptionalArg: [str_scenedef] The name of the scene to check"
"Example: s_scene scene::is_ready( "my_scene" );"
"Example: s_scene scene::is_ready();"
@/
function is_ready( str_scenedef )
{
	if ( self == level )
	{
		return ( level flagsys::get( str_scenedef + "_ready" ) );
	}
	else
	{
		DEFAULT( str_scenedef, self.scriptbundlename );
		
		o_scene = get_active_scene( str_scenedef );
		if ( isdefined( o_scene ) )
		{
			return ( o_scene flagsys::get( "ready" ) );
		}
	}
	
	return false;
}

function get_active_scenes( str_scenedef )
{
	DEFAULT( level.active_scenes, [] );
	
	if ( isdefined( str_scenedef ) )
	{
		return ( isdefined( level.active_scenes[ str_scenedef ] ) ? level.active_scenes[ str_scenedef ] : [] );
	}
	else
	{
		a_active_scenes = [];
		foreach ( str_scenedef, _ in level.active_scenes )
		{
			a_active_scenes = ArrayCombine( a_active_scenes, level.active_scenes[ str_scenedef ], false, false );
		}
		
		return a_active_scenes;
	}
}

function get_active_scene( str_scenedef )
{
	if ( isdefined( str_scenedef ) && isdefined( self.scenes ) )
	{
		foreach ( o_scene in self.scenes )
		{			
			if ( [[o_scene]]->get_name() == str_scenedef )
			{
				return o_scene;
			}
		}
	}
}


//TODO: this should be turned into something more automatic and part of the system
function delete_scene_data( str_scenename )
{
	if(IsDefined( level.scriptbundles["scene"][str_scenename] ))
	{
		level.scriptbundles["scene"][str_scenename] = undefined;
	}
}

function is_igc()
{
	return ( IsString( self.cameraswitcher )
	        || IsString( self.extraCamSwitcher1 )
	        || IsString( self.extraCamSwitcher2 )
	        || IsString( self.extraCamSwitcher3 )
	        || IsString( self.extraCamSwitcher4 ) );
}

function scene_disable_player_stuff( b_hide_hud = true )
{
	self notify( "scene_disable_player_stuff" );

	self notify( "kill_hint_text" );
	
	self DisableOffhandWeapons();

	if ( b_hide_hud )
	{
		set_igc_active( true );
		
		level notify( "disable_cybercom", self, true );
		self util::show_hud( 0 );
		
		util::wait_network_frame(); // let "in_igc" get set so deleted weapon objects can bypass HUD effects
		self notify( "delete_weapon_objects" );
	}
}

function scene_enable_player_stuff( b_hide_hud = true )
{
	self endon( "scene_disable_player_stuff" );
	self endon( "disconnect" );
	
	wait .5;

	self EnableOffhandWeapons();

	if ( b_hide_hud )
	{
		set_igc_active( false );
		level notify( "enable_cybercom", self );
		self notify( "scene_enable_cybercom" ); //TU1: Need to track when the scene system is turning it on per player.
		self util::show_hud( 1 );
	}
}

function updateIGCViewtime(b_in_igc)
{
	if (b_in_igc && !isDefined(level.igcStartTime))
	{
		level.igcStartTime = GetTime();
	}
	else if (!b_in_igc && isDefined(level.igcStartTime))
	{
		igcViewtimeSec = GetTime() - level.igcStartTime;
		level.igcStartTime = undefined;
		foreach (player in level.players)
		{
			if (!isDefined(player.totalIGCViewtime))
			{
				player.totalIGCViewtime = 0;
			}
			player.totalIGCViewtime += int(igcViewtimeSec / 1000);
		}
	}
}

function set_igc_active( b_in_igc )
{
	n_ent_num = self GetEntityNumber();
	n_players_in_igc_field = level clientfield::get( "in_igc" );
	
	if ( b_in_igc )
	{
		n_players_in_igc_field |= ( 1 << n_ent_num );
	}
	else
	{
		n_players_in_igc_field &= ~( 1 << n_ent_num );
	}
	updateIGCViewtime(b_in_igc);
	level clientfield::set( "in_igc", n_players_in_igc_field );
}

function is_igc_active()
{
	n_players_in_igc = level clientfield::get( "in_igc" );
	n_entnum = self GetEntityNumber();
	return ( n_players_in_igc & ( 1 << n_entnum ) );
}

function is_capture_mode()
{
	str_mode = GetDvarString( "scene_menu_mode", "default" );
	
	if ( IsSubStr( str_mode, "capture" ) )
	{
		return true;
	}
	else
	{
		return false;
	}
}

function should_spectate_on_join()
{
	return IS_TRUE(level.scene_should_spectate_on_hot_join);
}

function wait_until_spectate_on_join_completes()
{
	while(IS_TRUE(level.scene_should_spectate_on_hot_join))
	{
		wait 0.05;
	}
}

//-----------------------------------------------------------------SCENE-SKIPPING--------------------------------------------------------------------------------

function skip_scene( scene_name, b_sequence, b_player_scene, b_check_linked_scene )
{
	if(!isdefined(scene_name))
	{
		if(isdefined(level.shared_scene_sequence_name))
		{
			scene_name = level.shared_scene_sequence_name;
		}
		
		if(!isdefined(scene_name))
		{
			if(isdefined(level.players) && isdefined(level.players[0].current_scene))
			{
				scene_name = level.players[0].current_scene;
			}
			
			if(!isdefined(scene_name))
			{
				foreach(player in level.players)
				{
					if(isdefined(player.current_scene))
					{
						scene_name = player.current_scene;
						break;
					}
				}
			}
		}
	}
	
	//check if it is a player scene
	if(!IS_TRUE(b_sequence) && !isdefined(b_player_scene) )
	{
		foreach(player in level.players)
		{
			if(isdefined(player.current_scene) && player.current_scene == scene_name)
			{
				b_player_scene = true;
				break;
			}
		}
	}
	
	//start skipping player scenes and the scenes linked to it.
	if(!IS_TRUE(b_sequence) && IS_TRUE(b_player_scene))
	{
		//start the player scene
		a_instances = get_active_scenes( scene_name );
		
		b_can_skip_player_scene = false;
		
		foreach ( s_instance in ArrayCopy( a_instances ) )
		{
			if ( isdefined( s_instance ) )
			{
				b_shared_scene = (s_instance _skip_scene( scene_name, b_sequence, true, false ));
				
				if(b_shared_scene == 2)
					break;
				
				if(b_shared_scene == 1)
				{
				   	b_can_skip_player_scene = true;
				   	break;
				}
			}
		}
		
		//if it is a player skippable scene, we need to skip all the scenes that are associated with it.
		if( IS_TRUE(b_can_skip_player_scene) )
		{
			a_instances = get_active_scenes();
			
			foreach ( s_instance in ArrayCopy( a_instances ) )
			{
				if ( isdefined( s_instance ) )
				{
					s_instance _skip_scene( scene_name, b_sequence, false, true );
				}
			}
		}
		else
		{
			level.shared_scene_sequence_started = undefined;
			level.shared_scene_sequence_name = undefined;
		}
		
		return;
	}
	
	
	a_instances = struct::get_array( scene_name, "targetname" );
	
	if ( !a_instances.size )
	{
		a_instances = get_active_scenes( scene_name );
	}
	
	foreach ( s_instance in ArrayCopy( a_instances ) )
	{
		if ( isdefined( s_instance ) )
		{
			s_instance _skip_scene( scene_name, b_sequence, b_player_scene, b_check_linked_scene );
		}
	}
}

function _skip_scene( skipped_scene_name, b_sequence, b_player_scene, b_check_linked_scene )
{
	b_shared_scene = 0;
	
	if ( isdefined( self.scenes ) )
	{
		foreach ( o_scene in ArrayCopy( self.scenes ) )
		{
			//scene is skipping already
			if( IS_TRUE(o_scene.skipping_scene) )
				continue;
			
			//If a player scene skipping is starting, we can only skip the shared IGCs ones
 			if( !IS_TRUE(b_sequence) && IS_TRUE(b_player_scene) && !IS_TRUE(b_check_linked_scene) )
			{
 				if(o_scene._s.name === skipped_scene_name)
 				{
					if(IS_TRUE(o_scene._s.DisableSceneSkipping))
 					{
 						return 2;
 					}
 					else
 					{
 						if(o_scene._str_state === "init")
 							continue;
 						
 						b_shared_scene = 1;
 					}
 				}
 				else if(!isdefined(skipped_scene_name))
 				{
	 				if([[o_scene]]->is_scene_shared())
	 				{
	 					if(IS_TRUE(o_scene._s.DisableSceneSkipping))
	 					{
	 						return 2;
	 					}
	 					else
	 					{
	 						if(o_scene._str_state === "init")
	 							continue;
	 						
	 						b_shared_scene = 1;
	 					}
	 				}
	 				else
	 				{
	 					continue;
	 				}
 				}
 				else
 				{
 					continue;
 				}
			}
			
			str_scene_name = [[o_scene]]->get_name();

			if( !IS_TRUE(b_sequence) )
			{	
				b_linked_scene = array::contains(level.linked_scenes, str_scene_name);
				
				//ignore non linked player scenes
				if( IS_TRUE(b_check_linked_scene) && (!b_linked_scene || IS_TRUE(o_scene._s.DisableSceneSkipping)) )
				{
					continue;
				}
				
				if( !b_linked_scene && o_scene._str_state === "init" )
				{
					continue;
				}
			
				if ( ( !isdefined(skipped_scene_name) || str_scene_name == skipped_scene_name ) || (b_linked_scene && !IS_TRUE(o_scene._s.DisableSceneSkipping)) )
				{
					if( ( !isdefined(skipped_scene_name) || str_scene_name == skipped_scene_name) && IS_TRUE(b_player_scene) && !IS_TRUE(b_check_linked_scene) && !b_linked_scene) //if player scene
					{
						b_shared_scene = 1;
						o_scene.b_player_scene = true;
						level.player_skipping_scene = str_scene_name;
					}

					o_scene.skipping_scene = true;
					thread [[o_scene]]->skip_scene( b_sequence );
				}
			}
			else
			{
				o_scene.b_player_scene = b_player_scene;
				o_scene.skipping_scene = true;
				thread [[o_scene]]->skip_scene( b_sequence);
			}
		}
	}
	
	return b_shared_scene;
}

function add_player_linked_scene(linked_scene_str)
{
	DEFAULT( level.linked_scenes, [] );
	
	array::add(level.linked_scenes, linked_scene_str);
}

function remove_player_linked_scene(linked_scene_str)
{
	if(isdefined(level.linked_scenes))
	{
		ArrayRemoveValue( level.linked_scenes, linked_scene_str );
	}
}


function waittill_skip_sequence_completed()
{
	while(isdefined(level.player_skipping_scene))
	{
		wait 0.05;
	}
}

function is_skipping_in_progress()
{
	return isdefined(level.player_skipping_scene);
}

function watch_scene_skip_requests()
{
	self endon( "disconnect" );
	
	while(1)
	{
		level waittill("scene_sequence_started");
		
		self thread should_skip_scene_loop();
		self thread watch_scene_ending();
		self thread watch_scene_skipping();
		
		level waittill( "scene_sequence_ended" );
	}
}

function clear_scene_skipping_ui()
{
	level endon("scene_sequence_started");
	
	if(isdefined(self.scene_skip_timer))
	{
		
		self.scene_skip_timer = undefined;
	}
	
	if(isdefined(self.scene_skip_start_time))
	{
		self.scene_skip_start_time = undefined;
	}
	
	foreach(player in level.players)
	{
		if(isdefined(player.skip_scene_menu_handle))
		{
			 player CloseLuiMenu( player.skip_scene_menu_handle );
			 player.skip_scene_menu_handle = undefined;
		}
	}
}

function watch_scene_ending()
{
	self endon( "disconnect" );
	self endon( "scene_being_skipped");
	
	level waittill( "scene_sequence_ended" );
	
	clear_scene_skipping_ui();
}

function watch_scene_skipping()
{
	self endon( "disconnect" );
	level endon( "scene_sequence_ended");
	
	self waittill( "scene_being_skipped");
	level.sceneSkippedCount++;	
	clear_scene_skipping_ui();
}

function should_skip_scene_loop()
{
	self endon( "disconnect" );
	level endon( "scene_sequence_ended" );
	
	b_skip_scene = false;
	clear_scene_skipping_ui();
	
	wait 0.05; //wait a frame for the menus to be closed
	
	foreach(player in level.players)
	{		
		if(isdefined(player.skip_scene_menu_handle))
		{
			 player CloseLuiMenu( player.skip_scene_menu_handle );
			 wait 0.05; //wait a frame for the menus to be closed
		}
		
		player.skip_scene_menu_handle = player OpenLuiMenu( "CPSkipSceneMenu" );
		
		player SetLUIMenuData( player.skip_scene_menu_handle, "showSkipButton", 0 );
		player SetLUIMenuData( player.skip_scene_menu_handle, "hostIsSkipping", 0 );
		player SetLUIMenuData( player.skip_scene_menu_handle, "sceneSkipEndTime", 0 );
	}
	
	while(1)
	{	
		if((self any_button_pressed()) && !IS_TRUE(level.chyron_text_active))
		{
			if(!isdefined(self.scene_skip_timer))
			{
				self SetLUIMenuData( self.skip_scene_menu_handle, "showSkipButton", 1 );
			}
			
			self.scene_skip_timer = GetTime();
		}
		else if(isdefined(self.scene_skip_timer))
		{
			if((GetTime() - self.scene_skip_timer) > 3000)
			{
				self SetLUIMenuData( self.skip_scene_menu_handle, "showSkipButton", 2 );
				
				self.scene_skip_timer = undefined;
			}
		}
		
		if((self PrimaryButtonPressedLocal()) && !IS_TRUE(level.chyron_text_active))
		{
			if( !isdefined(self.scene_skip_start_time) )
			{	
				foreach(player in level.players)
				{
					if(player IsHost())
					{
						player SetLUIMenuData( player.skip_scene_menu_handle, "sceneSkipEndTime", GetTime() + 2500 );
						continue;
					}
					
					if(isdefined(player.skip_scene_menu_handle))
					{
						player SetLUIMenuData( player.skip_scene_menu_handle, "hostIsSkipping", 1 );
					}
				}
				
				
				self.scene_skip_start_time = GetTime();
			}
			else if((GetTime() - self.scene_skip_start_time) > 2500)
			{
				b_skip_scene = true;
				break;
			}
		}
		else if( isdefined(self.scene_skip_start_time) )
		{
			foreach(player in level.players)
			{
				if(player IsHost())
				{
					player SetLUIMenuData( player.skip_scene_menu_handle, "sceneSkipEndTime", 0 );
					continue;
				}
				
				if(isdefined(player.skip_scene_menu_handle))
				{
					player SetLUIMenuData( player.skip_scene_menu_handle, "hostIsSkipping", 2 );
				}
			}
		
			self.scene_skip_start_time = undefined;
		}
		
		if(IS_TRUE(level.chyron_text_active))
		{
			while(IS_TRUE(level.chyron_text_active))
			{
				wait 0.05;
			}
			
			//give Chyron text a chance to fade out
			wait 3;
		}
			
		wait 0.05;
	}
	
	if(b_skip_scene)
	{
		
		self playsound( "uin_igc_skip" ); //C.Ayers: Plays a skip sound with a duck to cover up the switch
				
		self notify("scene_being_skipped");
		level notify("scene_skip_sequence_started");
		
		scene::skip_scene(level.shared_scene_sequence_name, false, true);
	}
}

function any_button_pressed()
{
	//DPad
	if( self ActionSlotOneButtonPressed() )
	{
		return true;
	}
	else if( self ActionSlotTwoButtonPressed() )
	{
		return true;
	}
	else if( self ActionSlotThreeButtonPressed() )
	{
		return true;
	}
	else if( self ActionSlotFourButtonPressed() )
	{
		return true;
	}
	
	//Action Buttons
	else if(self JumpButtonPressed() )
	{
		return true;
	}
	else if(self StanceButtonPressed() )
	{
		return true;
	}
	else if(self WeaponSwitchButtonPressed() )
	{
		return true;
	}
	else if(self ReloadButtonPressed() )
	{
		return true;
	}	
	
	//Triggers
	else if(self fragbuttonpressed() )
	{
		return true;
	}
	else if(self throwbuttonpressed() )
	{
		return true;
	}	
	else if(self AttackButtonPressed())
	{
		return true;
	}	
	else if(self secondaryoffhandbuttonpressed() )
	{
		return true;
	}	

	//Sticks
	else if(self meleebuttonpressed() )
	{
		return true;
	}
	
	return false;
}

function on_player_connect()
{
	if( self IsHost() )
	{
		self thread watch_scene_skip_requests();
	}
}

function on_player_disconnect()
{
	// Clear out the igc active level flag so if somebody hot joins in they don't think they are in an igc
	self set_igc_active( false );
}

//-------------------------------------------------------------------------------------------------------------------------------------------------


function add_scene_ordered_notetrack( group_name, str_note )
{
	DEFAULT( level.scene_ordered_notetracks, [] );
	
	group_obj = level.scene_ordered_notetracks[group_name];
	
	if(!isdefined( group_obj ))
	{
		group_obj = SpawnStruct();
		group_obj.count = 0;
		group_obj.current_count = 0;
		
		level.scene_ordered_notetracks[group_name] = group_obj;
	}
	
	group_obj.count++;
	
	self thread _wait_for_ordered_notify( group_obj.count - 1, group_obj, group_name, str_note );
}

function private _wait_for_ordered_notify( id, group_obj, group_name, str_note )
{
	self waittill(str_note);
	
	if( group_obj.current_count == id )
	{
		group_obj.current_count++;
		self notify("scene_" + str_note);
		wait 0.05;
		
		//if we fired all notifies, release all arrays
		if(group_obj.current_count == group_obj.count)
		{
			group_obj.pending_notifies = undefined;
			level.scene_ordered_notetracks[group_name] = undefined;
		}
		else if( isdefined(group_obj.pending_notifies) && ((group_obj.current_count + group_obj.pending_notifies.size)  == group_obj.count) )
		{
			self thread _fire_ordered_notitifes( group_obj, group_name);
		}
	}
	else
	{
		if( !isdefined(group_obj.pending_notifies) )
		{
			group_obj.pending_notifies = [];
		}
		
		//out of order notetrack fired...insert it in it's ordered position
		notetrack = SpawnStruct();
		notetrack.id = id;
		notetrack.str_note = str_note;

		i = 0;
		while(i < group_obj.pending_notifies.size && group_obj.pending_notifies[i].id < id)
		{
			i++;
		}
		
		ArrayInsert(group_obj.pending_notifies, notetrack, i);
		
		if( (group_obj.current_count + group_obj.pending_notifies.size)  == group_obj.count )
		{
			self thread _fire_ordered_notitifes( group_obj, group_name);
		}
	}
}

function private _fire_ordered_notitifes( group_obj, group_name )
{
	if( isdefined(group_obj.pending_notifies) )
	{
		while( group_obj.pending_notifies.size > 0)
		{
			self notify("scene_" + group_obj.pending_notifies[0].str_note);
			ArrayRemoveIndex(group_obj.pending_notifies, 0);
			wait 0.05;
		}
	}
	
	group_obj.pending_notifies = undefined;
	level.scene_ordered_notetracks[group_name] = undefined;
}

function add_wait_for_streamer_hint_scene( str_scene_name )
{
	DEFAULT( level.wait_for_streamer_hint_scenes, [] );
	array::add( level.wait_for_streamer_hint_scenes, str_scene_name );
}
