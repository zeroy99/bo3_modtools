#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\gfx_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\duplicaterender.gsh;

#namespace duplicate_render_bundle;

//-----------------------------------------------------------------------------
REGISTER_SYSTEM( "duplicate_render_bundle", &__init__, undefined )

function __init__()
{
	callback::on_localplayer_spawned( &localplayer_duplicate_render_bundle_init );
}

function localplayer_duplicate_render_bundle_init( localClientNum )
{
	init_duplicate_render_bundles();
}

//-----------------------------------------------------------------------------
function init_duplicate_render_bundles()
{
	if ( isdefined( self.dupRenderBundelsInited ) )
		return;

	self.dupRenderBundelsInited = true;
	self.playingdupRenderBundle = "";
	self.forceStopdupRenderBundle = false;
	self.exitdupRenderBundle = false;
}


//-----------------------------------------------------------------------------

function playDupRenderBundle( playBundleName )
{
	self endon("entityshutdown");

	init_duplicate_render_bundles();

	stopPlayingdupRenderBundle();

	bundle = struct::get_script_bundle( "duprenderbundle", playBundleName );
	if ( !isdefined( bundle ) )
	{
		/#
		println( "ERROR: dupRender bundle '" + playBundleName + "' not found" );
		#/
		return;
	}

	totalAccumTime = 0;

	filter::init_filter_indices();

	self.playingdupRenderBundle = playBundleName;
	
	localClientNum = self.localClientNum;

	looping = false;
	enterStage = false;
	exitStage = false;
	finishLoopOnExit = false;

	SET_IF_DEFINED( looping, bundle.looping );
	SET_IF_DEFINED( enterStage, bundle.enterStage );
	SET_IF_DEFINED( exitStage, bundle.exitStage );
	SET_IF_DEFINED( finishLoopOnExit, bundle.finishLoopOnExit );

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

	for ( stageIdx = 0 ; stageIdx < num_stages && !self.forceStopdupRenderBundle ; stageIdx++ )
	{
		stagePrefix = "s";
		if ( stageIdx < 10 ) stagePrefix += "0";
		stagePrefix += stageIdx + "_";

		stageLength = GetStructField( bundle, stagePrefix + "length" );
		if ( !isdefined( stageLength ) )
		{
			finishPlayingdupRenderBundle( localClientNum, stagePrefix + " length not defined" );
			return;
		}
		stageLength *= 1000;

		// Set the duplicate render:
		AddDupMaterial( localClientNum, bundle, stagePrefix + "fb_", DR_TYPE_FRAMEBUFFER );
		AddDupMaterial( localClientNum, bundle, stagePrefix + "dupfb_", DR_TYPE_FRAMEBUFFER_DUPLICATE );
		AddDupMaterial( localClientNum, bundle, stagePrefix + "sonar_", DR_TYPE_OFFSCREEN );

		loopingStage = looping && ( !enterStage && stageIdx == 0 || enterStage && stageIdx == 1 );

		accumTime = 0;
		prevTime = self GetClientTime();
		while ( ( loopingStage || accumTime < stageLength ) && !self.forceStopdupRenderBundle )
		{
			gfx::SetStage( localClientNum, bundle, undefined, stagePrefix, stageLength, accumTime, totalAccumTime, &SetShaderConstants );

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

				if ( self.exitdupRenderBundle )
				{
					loopingStage = false;
					if ( !finishLoopOnExit )
						break;
				}
			}
		}

		self disableduplicaterendering();
	}

	finishPlayingdupRenderBundle( localClientNum, "Finished " + playBundleName );
}

//-----------------------------------------------------------------------------------------------------------
function AddDupMaterial( localClientNum, bundle, prefix, type )
{
	method = DR_METHOD_OFF;
	methodStr = GetStructField( bundle, prefix + "method" );
	if ( isDefined( methodStr ) )
	{
		switch( methodStr )
		{
			case "off": 
				method = DR_METHOD_OFF;
				break;
			case "default material": 
				method = DR_METHOD_DEFAULT_MATERIAL;
				break;
			case "custom material":
				method = DR_METHOD_CUSTOM_MATERIAL;
				break;
			case "force custom material":
				method = DR_METHOD_CUSTOM_MATERIAL;
				break;
			case "thermal":
				method = DR_METHOD_THERMAL_MATERIAL;
				break;
			case "enemy material":
				method = DR_METHOD_ENEMY_MATERIAL;
				break;
		}
	}

	materialName = GetStructField( bundle, prefix + "mc_material" );

	materialId = -1;
	if ( isDefined( materialName ) && materialName != "" )
	{
		materialName = "mc/" + materialName; // TODO: Don't hard code "mc"?
		materialId = filter::mapped_material_id( materialName );
		if ( !isDefined( materialId ) )
		{
			filter::map_material_helper_by_localclientnum( localClientNum, materialName );
			materialId = filter::mapped_material_id(  );
			if ( !isDefined( materialId ) )
				materialId = -1;
		}
	}

	self AddDuplicateRenderOption( type, method, materialId );
}

//-----------------------------------------------------------------------------------------------------------
function SetShaderConstants( localClientNum, shaderConstantName, filterid, values )
{
	self MapShaderConstant( localClientNum, 0, shaderConstantName, values[0], values[1], values[2], values[3] );
}

//-----------------------------------------------------------------------------

function finishPlayingDupRenderBundle( localClientNum, msg )
{
	/#
	if ( isdefined( msg ) )
	{
		println( msg );
	}
	#/

	self.forceStopdupRenderBundle = false;
	self.exitdupRenderBundle = false;
	self.playingdupRenderBundle = "";
}

//-----------------------------------------------------------------------------

function stopPlayingDupRenderBundle()
{
	if ( self.playingdupRenderBundle != "" )
	{
		stopdupRenderBundle();
	}
}

function stopDupRenderBundle()
{
	if ( !IS_TRUE( self.forceStopdupRenderBundle ) && isdefined( self.playingdupRenderBundle ) && self.playingdupRenderBundle != "" )
	{
		self.forceStopdupRenderBundle = true;

		while ( self.playingdupRenderBundle != "" )
		{
			WAIT_CLIENT_FRAME;
			
			if ( !isdefined( self ) )
			{
				return;
			}
		}
	}
}

function exitDupRenderBundle()
{
	if ( !IS_TRUE( self.exitdupRenderBundle ) && isdefined( self.playingdupRenderBundle ) && self.playingdupRenderBundle != "" )
	{
		self.exitdupRenderBundle = true;
	}
}
