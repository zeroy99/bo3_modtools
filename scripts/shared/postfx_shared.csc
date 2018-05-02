#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\gfx_shared;
#using scripts\shared\duplicaterenderbundle; // Just so it will be included

#insert scripts\shared\shared.gsh;

#namespace postfx;

#define MAX_NUM_QUADS	2048

//-----------------------------------------------------------------------------
REGISTER_SYSTEM( "postfx_bundle", &__init__, undefined )

function __init__()
{
	callback::on_localplayer_spawned( &localplayer_postfx_bundle_init );
}

function localplayer_postfx_bundle_init( localClientNum )
{
	init_postfx_bundles();
}

//-----------------------------------------------------------------------------
function init_postfx_bundles()
{
	if ( isdefined( self.postfxBundelsInited ) )
		return;

	self.postfxBundelsInited = true;
	self.playingPostfxBundle = "";
	self.forceStopPostfxBundle = false;
	self.exitPostfxBundle = false;
}

//-----------------------------------------------------------------------------

function playPostfxBundle( playBundleName )
{
	self endon("entityshutdown");
	self endon("death");

	init_postfx_bundles();

	stopPlayingPostfxBundle();

	bundle = struct::get_script_bundle( "postfxbundle", playBundleName );
	if ( !isdefined( bundle ) )
	{
		/#
		println( "ERROR: postfx bundle '" + playBundleName + "' not found" );
		#/
		return;
	}

	filterid = 0;
	totalAccumTime = 0;

	filter::init_filter_indices();

	self.playingPostfxBundle = playBundleName;
	
	localClientNum = self.localClientNum;

	looping = false;
	enterStage = false;
	exitStage = false;
	finishLoopOnExit = false;
	firstPersonOnly = false;

	SET_IF_DEFINED( looping, bundle.looping );
	SET_IF_DEFINED( enterStage, bundle.enterStage );
	SET_IF_DEFINED( exitStage, bundle.exitStage );
	SET_IF_DEFINED( finishLoopOnExit, bundle.finishLoopOnExit );
	SET_IF_DEFINED( firstPersonOnly, bundle.firstPersonOnly );

	if ( looping )
	{
		num_stages = 1;
		if ( enterStage )
			num_stages++;
		if ( exitStage )
			num_stages++;
	}
	else
	{
		num_stages = bundle.num_stages;
	}

	self.captureImageName = undefined;
	if ( isDefined( bundle.screenCapture ) && bundle.screenCapture )
	{
		self.captureImageName = playBundleName;
		CreateSceneCodeImage( localClientNum, self.captureImageName );
		CaptureFrame( localClientNum, self.captureImageName );
		setFilterPassCodeTexture( localClientNum, filterid, 0, 0, self.captureImageName );
	}

	self thread watchEntityShutdown( localClientNum, filterid );
	for ( stageIdx = 0 ; stageIdx < num_stages && !self.forceStopPostfxBundle ; stageIdx++ )
	{
		stagePrefix = "s";
		if ( stageIdx < 10 ) stagePrefix += "0";
		stagePrefix += stageIdx + "_";

		stageLength = GetStructField( bundle, stagePrefix + "length" );
		if ( !isdefined( stageLength ) )
		{
			finishPlayingPostfxBundle( localClientNum, stagePrefix + "length not defined", filterid );
			return;
		}
		stageLength *= 1000;

		stageMaterial = GetStructField( bundle, stagePrefix + "material" );
		if ( !isdefined( stageMaterial ) )
		{
			finishPlayingPostfxBundle( localClientNum, stagePrefix + "material not defined", filterid );
			return;
		}

		filter::map_material_helper( self, stageMaterial );
		setFilterPassMaterial( localClientNum, filterid, 0, filter::mapped_material_id( stageMaterial ) );
		setFilterPassEnabled( localClientNum, filterid, 0, true, false, firstPersonOnly );

		stageCapture = GetStructField( bundle, stagePrefix + "screenCapture" );
		if ( isDefined( stageCapture ) && stageCapture )
		{
			if ( isDefined( self.captureImageName ) )
			{
				FreeCodeImage( localClientNum, self.captureImageName );
			 	self.captureImageName = undefined;
				setFilterPassCodeTexture( localClientNum, filterid, 0, 0, "" );
			}

			self.captureImageName = stagePrefix + playBundleName;
			CreateSceneCodeImage( localClientNum, self.captureImageName );
			captureFrame( localClientNum, self.captureImageName );
			setFilterPassCodeTexture( localClientNum, filterid, 0, 0, self.captureImageName );
		}

		stageSprite = GetStructField( bundle, stagePrefix + "spriteFilter" );
		if ( isDefined( stageSprite ) && stageSprite )
		{
			setfilterpassquads( localClientNum, filterid, 0, MAX_NUM_QUADS );
		}
		else
		{
			setfilterpassquads( localClientNum, filterid, 0, 0 );
		}

		thermal = GetStructField( bundle, stagePrefix + "thermal" );
		EnableThermalDraw( localClientNum, isDefined( thermal ) && thermal );

		loopingStage = looping && ( !enterStage && stageIdx == 0 || enterStage && stageIdx == 1 );

		accumTime = 0;
		prevTime = self GetClientTime();
		while ( ( loopingStage || accumTime < stageLength ) && !self.forceStopPostfxBundle )
		{

			gfx::SetStage( localClientNum, bundle, filterid, stagePrefix, stageLength, accumTime, totalAccumTime, &SetFilterConstants );

			WAIT_CLIENT_FRAME;
			
			currTime = self GetClientTime();
			deltaTime = currTime - prevTime;
			accumTime += deltaTime;
			totalAccumTime += deltaTime;

			prevTime = currTime;

			if ( loopingStage )
			{
				while ( accumTime >= stageLength )
					accumTime -= stageLength;

				if ( self.exitPostfxBundle )
				{
					loopingStage = false;
					if ( !finishLoopOnExit )
						break;
				}
			}
		}

		setFilterPassEnabled( localClientNum, filterid, 0, false );
	}

	finishPlayingPostfxBundle( localClientNum, "Finished " + playBundleName, filterid );
}

function watchEntityShutdown( localClientNum, filterid )
{
	self util::waittill_any( "entityshutdown", "death", "finished_playing_postfx_bundle" );
	
	finishPlayingPostfxBundle( localClientNum, "Entity Shutdown", filterid );
}

//-----------------------------------------------------------------------------------------------------------
function SetFilterConstants( localClientNum, shaderConstantName, filterid, values )
{
	baseShaderConstIndex = gfx::getShaderConstantIndex( shaderConstantName );
	setFilterPassConstant( localClientNum, filterid, 0, baseShaderConstIndex + 0, values[0] );
	setFilterPassConstant( localClientNum, filterid, 0, baseShaderConstIndex + 1, values[1] );
	setFilterPassConstant( localClientNum, filterid, 0, baseShaderConstIndex + 2, values[2] );
	setFilterPassConstant( localClientNum, filterid, 0, baseShaderConstIndex + 3, values[3] );
}

//-----------------------------------------------------------------------------

function finishPlayingPostfxBundle( localClientNum, msg, filterid )
{
	if( isDefined( self ) )
	{
		self notify ( "finished_playing_postfx_bundle" );
		self.forceStopPostfxBundle = false;
		self.exitPostfxBundle = false;
		self.playingPostfxBundle = "";
	}

	setFilterPassQuads( localClientNum, filterid, 0, 0 );
	setFilterPassEnabled( localClientNum, filterid, 0, false );
	EnableThermalDraw( localClientNum, false );

	if ( isDefined( self.captureImageName ) )
	{
		setFilterPassCodeTexture( localClientNum, filterid, 0, 0, "" );
		FreeCodeImage( localClientNum, self.captureImageName );
		self.captureImageName = undefined;
	}
}

//-----------------------------------------------------------------------------

function stopPlayingPostfxBundle()
{
	if ( self.playingPostfxBundle != "" )
	{
		stopPostfxBundle();
	}
}

function stopPostfxBundle()
{
	self notify( "stopPostfxBundle_singleton" );
	self endon( "stopPostfxBundle_singleton" );
	
	if ( isdefined( self.playingPostfxBundle ) && self.playingPostfxBundle != "" )
	{
		self.forceStopPostfxBundle = true;

		while ( self.playingPostfxBundle != "" )
		{
			WAIT_CLIENT_FRAME;
			
			if ( !isdefined( self ) )
			{
				return;
			}
		}
	}
}

function exitPostfxBundle()
{
	if ( !IS_TRUE( self.exitPostfxBundle ) && isdefined( self.playingPostfxBundle ) && self.playingPostfxBundle != "" )
	{
		self.exitPostfxBundle = true;
	}
}


function setFrontendStreamingOverlay( localClientNum, system, enabled )
{
	if( !isdefined( self.overlayClients ) )
	{
		self.overlayClients = [];
	}

	if( !isdefined( self.overlayClients[localClientNum] ) )
	{
		self.overlayClients[localClientNum] = [];
	}

	self.overlayClients[localClientNum][system] = enabled;

	foreach( _, en in self.overlayClients[localClientNum] )
	{
		if( en )
		{
			EnableFrontendStreamingOverlay( localClientNum, true );
			return;
		}
	}

	EnableFrontendStreamingOverlay( localClientNum, false );
}

