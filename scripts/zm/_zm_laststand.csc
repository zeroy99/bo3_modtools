#using scripts\zm\_load;
#using scripts\zm\_util;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\version.gsh;
#insert scripts\shared\shared.gsh;

#insert scripts\zm\_zm_laststand.gsh;

#namespace zm_laststand;

REGISTER_SYSTEM( "zm_laststand", &__init__, undefined )

function __init__()
{
	level.laststands = [];
	for( i = 0; i < 4; i++ )
	{
		level.laststands[i] = SpawnStruct();
		level.laststands[i].bleedoutTime = 0;
		level.laststands[i].laststand_update_clientfields = "laststand_update" + i;
		level.laststands[i].lastBleedoutTime = 0;
		
		clientfield::register( "world", level.laststands[i].laststand_update_clientfields, VERSION_SHIP, 5, "counter", &update_bleedout_timer, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}

	
	level thread wait_and_set_revive_shader_constant();

	visionset_mgr::register_visionset_info( ZM_LASTSTAND_VISIONSET, VERSION_SHIP, 31, undefined, ZM_LASTSTAND_VISIONSET, 6 );
	visionset_mgr::register_visionset_info( ZM_DEATH_VISIONSET, VERSION_SHIP, 31, ZM_LASTSTAND_VISIONSET, ZM_DEATH_VISIONSET, 6 );
}

function wait_and_set_revive_shader_constant()
{
	while( 1 )
	{
		level waittill( "notetrack", localClientNum, note );
		if( note == "revive_shader_constant" )
		{
			//received startup notetrack on revive weapon anim
			player = GetLocalPlayer( localClientNum );
			//the time at the end tells the flipbook shader what time to play relative to
			player MapShaderConstant( localClientNum, 0, "scriptVector2", 0, 1, 0, GetServerTime( localClientNum ) / 1000.0 );
		}		
	}
}

function animation_update( model, oldValue, newValue )
{
	self endon( "new_val" );
	startTime = GetRealTime();
	timeSinceLastUpdate = 0;
	
	if( oldValue == newValue )
	{
		newValue = oldValue - 1;
	}
	
	while( timeSinceLastUpdate <= 1.0 )
	{
		timeSinceLastUpdate = ( ( GetRealTime() - startTime ) / 1000.0 );
		lerpValue = ( LerpFloat( oldValue, newValue, timeSinceLastUpdate ) / 30.0 );
		SetUIModelValue( model, lerpValue );
		WAIT_CLIENT_FRAME;
	}
}

function update_bleedout_timer( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	substr =  GetSubStr( fieldName, 16 ) ;
	playerNum = Int( substr );
	
	level.laststands[ playerNum ].lastBleedoutTime = level.laststands[ playerNum ].bleedoutTime;
	level.laststands[ playerNum ].bleedoutTime = newVal - 1;
	
	if( level.laststands[ playerNum ].lastBleedoutTime < level.laststands[ playerNum ].bleedoutTime )
	{
		level.laststands[ playerNum ].lastBleedoutTime = level.laststands[ playerNum ].bleedoutTime;
	}
	
	model = GetUIModel(GetUIModelForController(localClientNum), "WorldSpaceIndicators.bleedOutModel" + playerNum + ".bleedOutPercent" );
	if( isdefined( model ) )
	{
		if( newVal == 30 )
		{
			level.laststands[ playerNum ].bleedoutTime = 0;
			level.laststands[ playerNum ].lastBleedoutTime = 0;
			SetUIModelValue( model, 1.0 );
		}
		else if( newVal == 29 )
		{
			level.laststands[ playerNum ] notify( "new_val" );
			level.laststands[ playerNum ] thread animation_update( model, 30, 28 );
		}
		else
		{
			level.laststands[ playerNum ] notify( "new_val" );
			level.laststands[ playerNum ] thread animation_update( model, level.laststands[ playerNum ].lastBleedoutTime, level.laststands[ playerNum ].bleedoutTime );
		}
	}
}