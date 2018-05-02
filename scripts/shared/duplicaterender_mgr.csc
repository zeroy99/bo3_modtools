#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#using scripts\shared\system_shared;

#namespace duplicate_render;

#define FRAMEBUFFER_FILTER_SET "framebuffer"
#define FRAMEBUFFER_DUPLICATE_FILTER_SET "framebuffer_duplicate"
#define OFFSCREEN_FILTER_SET "offscreen"

REGISTER_SYSTEM( "duplicate_render", &__init__, undefined )

#define EQUIPMENT_RETRIEVABLE_MATERIAL "mc/hud_keyline_retrievable"	
#define EQUIPMENT_UNPLACEABLE_MATERIAL "mc/hud_keyline_unplaceable"	
#define EQUIPMENT_ENEMYEQUIP_MATERIAL  "mc/hud_outline_rim"	
#define EQUIPMENT_ENEMYVEHICLE_MATERIAL "mc/hud_outline_rim"	
#define EQUIPMENT_ENEMYEQUIP_DETECT_MATERIAL "mc/hud_outline_rim"
#define EQUIPMENT_FRIENDLYEQUIP_MATERIAL  "mc/hud_keyline_friendlyequip"	
#define EQUIPMENT_FRIENDLYVEHICLE_MATERIAL "mc/hud_keyline_friendlyequip"	
	
#define PLAYER_THREAT_DETECTOR_MATERIAL "mc/hud_keyline_enemyequip"

#define PLAYER_HACKER_TOOL_HACKED 		"mc/mtl_hacker_tool_hacked"
#define PLAYER_HACKER_TOOL_HACKING 		"mc/mtl_hacker_tool_hacking"
#define PLAYER_HACKER_TOOL_BREACHING 	"mc/mtl_hacker_tool_breaching"

#define PLAYER_BALL_OUTLINE 	"mc/hud_keyline_friendlyequip"
	
function __init__()
{
	DEFAULT(level.drfilters,[]);
	
	callback::on_spawned( &on_player_spawned );
	callback::on_localclient_connect( &on_player_connect );

	set_dr_filter_framebuffer( "none_fb", 0, undefined, undefined, DR_TYPE_FRAMEBUFFER, DR_METHOD_DEFAULT_MATERIAL, DR_CULL_ALWAYS );
	set_dr_filter_framebuffer_duplicate( "none_fbd", 0, undefined, undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, DR_METHOD_OFF, DR_CULL_ALWAYS );
	set_dr_filter_offscreen( "none_os", 0, undefined, undefined, DR_TYPE_OFFSCREEN, DR_METHOD_OFF, DR_CULL_ALWAYS );

	set_dr_filter_framebuffer( "enveh_fb", 8, "enemyvehicle_fb", undefined, DR_TYPE_FRAMEBUFFER, DR_METHOD_ENEMY_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_framebuffer( "frveh_fb", 8, "friendlyvehicle_fb", undefined, DR_TYPE_FRAMEBUFFER, DR_METHOD_DEFAULT_MATERIAL, DR_CULL_NEVER );

	set_dr_filter_offscreen( "retrv", 5, "retrievable", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_RETRIEVABLE_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "unplc", 7, "unplaceable", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_UNPLACEABLE_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "eneqp", 8, "enemyequip", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_ENEMYEQUIP_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "enexp", 8, "enemyexplo", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_ENEMYEQUIP_DETECT_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "enveh", 8, "enemyvehicle", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_ENEMYEQUIP_DETECT_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "freqp", 8, "friendlyequip", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_FRIENDLYEQUIP_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "frexp", 8, "friendlyexplo", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_FRIENDLYEQUIP_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "frveh", 8, "friendlyvehicle", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_FRIENDLYVEHICLE_MATERIAL, DR_CULL_NEVER );
		
	set_dr_filter_offscreen( "infrared", 9, "infrared_entity", undefined, DR_TYPE_OFFSCREEN, DR_METHOD_THERMAL_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "threat_detector_enemy", 10, "threat_detector_enemy", undefined, DR_TYPE_OFFSCREEN, PLAYER_THREAT_DETECTOR_MATERIAL, DR_CULL_NEVER );
	
	set_dr_filter_offscreen( "hthacked", 5, "hacker_tool_hacked", undefined, DR_TYPE_OFFSCREEN, PLAYER_HACKER_TOOL_HACKED, DR_CULL_NEVER );
	set_dr_filter_offscreen( "hthacking", 5, "hacker_tool_hacking", undefined, DR_TYPE_OFFSCREEN, PLAYER_HACKER_TOOL_HACKING, DR_CULL_NEVER );
	set_dr_filter_offscreen( "htbreaching", 5, "hacker_tool_breaching", undefined, DR_TYPE_OFFSCREEN, PLAYER_HACKER_TOOL_BREACHING, DR_CULL_NEVER );
	
	set_dr_filter_offscreen( "bcarrier", 9, "ballcarrier", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_FRIENDLYEQUIP_MATERIAL, DR_CULL_NEVER );
	set_dr_filter_offscreen( "poption", 9, "passoption", undefined, DR_TYPE_OFFSCREEN, EQUIPMENT_FRIENDLYEQUIP_MATERIAL, DR_CULL_NEVER );
	

	level.friendlyContentOutlines		= GetDvarInt( "friendlyContentOutlines", false );
}

function on_player_spawned( local_client_num )
{
	self.currentdrfilter=[];
	self change_dr_flags(local_client_num);
	
	if( !level flagsys::get( "duplicaterender_registry_ready" ) )
	{
		WAIT_CLIENT_FRAME;//We need a frame once player is valid to set up the materials 
		level flagsys::set( "duplicaterender_registry_ready" );
	}
}

function on_player_connect( localClientNum )
{
	level wait_team_changed( localClientNum );
}

function wait_team_changed( localClientNum )
{
	while( 1 )
	{
		level waittill( "team_changed" );
		
		// the local player might not be valid yet and will cause the team detection functionality not to work
		while ( !isdefined(	GetLocalPlayer( localClientNum ) ) )
		{
			wait( SERVER_FRAME );
		}
	
		player = GetLocalPlayer( localClientNum );
		player Codcaster_Keyline_Enable( false );
	}
}

function set_dr_filter( filterset, name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 )
{
	DEFAULT( level.drfilters, [] );
	if ( !IsDefined( level.drfilters[ filterset ] ) )
	{
		level.drfilters[filterset]=[];
	}
	if (!IsDefined(level.drfilters[filterset][name]))
	{
		level.drfilters[filterset][name] = spawnstruct(); 
	}
	filter = level.drfilters[filterset][name]; 
	filter.name = name;
	// set priority negative until the materials are registered. This will keep it from being used
	filter.priority = -priority;	
	if (!IsDefined(require_flags))
		filter.require = [];
	else if ( IsArray(require_flags) )
		filter.require = require_flags;	
	else
		filter.require = StrTok( require_flags, "," );
	if (!IsDefined(refuse_flags))
		filter.refuse = [];
	else if ( IsArray(refuse_flags) )
		filter.refuse = refuse_flags;	
	else
		filter.refuse = StrTok( refuse_flags, "," );
	filter.types = [];
	filter.values = [];
	filter.culling = [];
	if (IsDefined(drtype1))
	{
		idx = filter.types.size; 
		filter.types[idx]=drtype1;
		filter.values[idx]=drval1;
		filter.culling[idx]=drcull1;
	}
	if (IsDefined(drtype2))
	{
		idx = filter.types.size; 
		filter.types[idx]=drtype2;
		filter.values[idx]=drval2;
		filter.culling[idx]=drcull2;
	}
	if (IsDefined(drtype3))
	{
		idx = filter.types.size; 
		filter.types[idx]=drtype3;
		filter.values[idx]=drval3;
		filter.culling[idx]=drcull3;
	}

	thread register_filter_materials( filter );
}

function set_dr_filter_framebuffer( name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 )
{
	set_dr_filter( FRAMEBUFFER_FILTER_SET, name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 );
}

function set_dr_filter_framebuffer_duplicate( name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 )
{
	set_dr_filter( FRAMEBUFFER_DUPLICATE_FILTER_SET, name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 );
}

function set_dr_filter_offscreen( name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 )
{
	set_dr_filter( OFFSCREEN_FILTER_SET, name, priority, require_flags, refuse_flags, drtype1, drval1, drcull1, drtype2, drval2, drcull2, drtype3, drval3, drcull3 );
}

function register_filter_materials( filter )
{
	playerCount = undefined;
	opts = filter.types.size; 
	for ( i=0; i<opts; i++ )
	{
		value = filter.values[i];
		if ( IsString( value ) )
		{
			if ( !IsDefined(playerCount) )
			{
				while( !isDefined(level.localPlayers) && !isDefined(level.frontendClientConnected) )
				{
					WAIT_CLIENT_FRAME;
				}
				if( isDefined(level.frontendClientConnected) )
				{
					playerCount = 1;
				}
				else
				{
					util::waitforallclients();
					playerCount = level.localPlayers.size;
				}
			}
			if ( !IsDefined(filter::mapped_material_id( value ) ) )
			{
				for ( localClientNum = 0; localClientNum < playerCount; localClientNum++ )
				{
					filter::map_material_helper_by_localclientnum( localClientNum, value );
				}
			}
		}
	}

	// make it usable	
	filter.priority = abs( filter.priority );	
}

function update_dr_flag( localClientNum, toset, setto=true )
{
	if ( set_dr_flag( toset, setto ) )
	{
		update_dr_filters(localClientNum);
	}
}


function set_dr_flag_not_array( toset, setto=true )	
{
	if ( !IsDefined( self.flag ) || !IsDefined( self.flag[toset] ) )
	{
		self flag::init(toset);
	}
	
	if ( setto == self.flag[toset] )
	{
		return false;
	}
	if ( IS_TRUE(setto) )
	{
		self flag::set(toset);
	}
	else
	{
		self flag::clear(toset);
	}
	return true;
}
function set_dr_flag( toset, setto=true )
{
	Assert( IsDefined(setto) );
	
	if ( IsArray(toset))
	{
		foreach( ts in toset )
		{
			set_dr_flag( ts, setto );
		}
		return;
	}
	
	if ( !IsDefined( self.flag ) || !IsDefined( self.flag[toset] ) )
	{
		self flag::init(toset);
	}
	
	if ( setto == self.flag[toset] )
	{
		return false;
	}
	if ( IS_TRUE(setto) )
	{
		self flag::set(toset);
	}
	else
	{
		self flag::clear(toset);
	}
	return true;
}

function clear_dr_flag( toclear )
{
	set_dr_flag( toclear, false );
}
	
function change_dr_flags( localClientNum, toset, toclear )
{
	if ( IsDefined(toset) )
	{
		if( IsString( toset ) )
		{
			toset = StrTok( toset, "," );
		}
		self set_dr_flag(toset);
	}
	if ( IsDefined(toclear) )
	{
		if( IsString( toclear ) )
		{
			toclear = StrTok( toclear, "," );
		}	
		self clear_dr_flag(toclear);
	}
	
	update_dr_filters(localClientNum);
}

function _update_dr_filters(localClientNum)
{
	self notify("update_dr_filters");
	self endon("update_dr_filters");
	self endon("entityshutdown");
	
	waittillframeend;
	
	foreach( key, filterset in level.drfilters )
	{
		filter = self find_dr_filter(filterset);
		if ( isdefined(filter) && (!isdefined(self.currentdrfilter) || !IS_EQUAL(self.currentdrfilter[key],filter.name) ) )
		{
			self apply_filter( localClientNum, filter, key );
		}
	}
}

function update_dr_filters(localClientNum)
{
	self thread _update_dr_filters(localClientNum);
}

function find_dr_filter( filterset = level.drfilters[FRAMEBUFFER_FILTER_SET] )
{
	best = undefined; 
	foreach( filter in filterset )
	{
		if ( self can_use_filter( filter ) )
		{
			if (!IsDefined(best) || filter.priority > best.priority)
			{
				best = filter;
			}
		}
	}
	return best;
}

function can_use_filter( filter )
{
	for ( i = 0; i < filter.require.size; i++ )
	{
		if ( !self flagsys::get( filter.require[i] ))
			return false; 
	}
	for ( i = 0; i < filter.refuse.size; i++ )
	{
		if ( self flagsys::get( filter.refuse[i] ))
			return false; 
	}
	return true;
}

function apply_filter( localClientNum, filter, filterset = FRAMEBUFFER_FILTER_SET )
{
	if ( IsDefined( level.postGame ) && level.postGame && !IS_TRUE( level.showedTopThreePlayers ) )
	{
		player = GetLocalPlayer( localClientNum );
		if ( !(player GetInKillcam( localClientNum )) )
			return;
	}
	
	if (!IsDefined(self.currentdrfilter))
		self.currentdrfilter=[];
	self.currentdrfilter[filterset]=filter.name;
	opts = filter.types.size; 
	for ( i=0; i<opts; i++ )
	{
		type = filter.types[i];
		value = filter.values[i];
		culling = filter.culling[i];
		material = undefined;
		if ( IsString( value ) )
		{
			material = filter::mapped_material_id( value );
			value = DR_METHOD_CUSTOM_MATERIAL;
			if (IsDefined(value) && IsDefined(material))
			{
				// right now all duplicate rendering is see through walls
				self addduplicaterenderoption( type, value, material, culling );
			}
			else
			{
				self.currentdrfilter[filterset]=undefined;
			}
		}
		else
		{
			self addduplicaterenderoption( type, value, -1, culling );
		}
	}

	if( SessionModeIsMultiplayerGame() )	// Save client script vars for other game modes
	{
		self thread disable_all_filters_on_game_ended();
	}
}

function disable_all_filters_on_game_ended()
{
	self endon("entityshutdown");
	self notify("disable_all_filters_on_game_ended");
	self endon("disable_all_filters_on_game_ended");
	
	level waittill( "post_game" );

	self disableduplicaterendering();
}


//===================================================================================

function set_item_retrievable( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "retrievable", on_off );
}

function set_item_unplaceable( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "unplaceable", on_off );
}

function set_item_enemy_equipment( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "enemyequip", on_off );
}

function set_item_friendly_equipment( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "friendlyequip", on_off );
}

function set_item_enemy_explosive( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "enemyexplo", on_off );
}

function set_item_friendly_explosive( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "friendlyexplo", on_off );
}

function set_item_enemy_vehicle( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "enemyvehicle", on_off );
}

function set_item_friendly_vehicle( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "friendlyvehicle", on_off );
}

function set_entity_thermal( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "infrared_entity", on_off );
}

function set_player_threat_detected( localClientNum, on_off )
{
	self update_dr_flag( localClientNum, "threat_detector_enemy", on_off );
}


function set_hacker_tool_hacked( localClientNum,on_off )
{
	self update_dr_flag( localClientNum, "hacker_tool_hacked", on_off );
}


function set_hacker_tool_hacking( localClientNum, on_off )
{
	self update_dr_flag( localClientNum,"hacker_tool_hacking", on_off );
}


function set_hacker_tool_breaching( localClientNum, on_off )
{
	flags_changed = self set_dr_flag( "hacker_tool_breaching", on_off );
	if ( on_off )
	{
		flags_changed = self set_dr_flag( "enemyvehicle", false ) || flags_changed;
	}
	else
	{
		if ( IS_TRUE( self.isEnemyVehicle ) ) 
		{
			flags_changed = self set_dr_flag( "enemyvehicle", true ) || flags_changed;
		}
	}
	
	if ( flags_changed )
	{
		update_dr_filters(localClientNum);
	}
}

function show_friendly_outlines( local_client_num )
{
	if ( !IS_TRUE( level.friendlyContentOutlines ) )
		return false;

	if ( IsShoutcaster( local_client_num ) )
		return false;
				
	return true;
}

