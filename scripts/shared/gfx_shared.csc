#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace gfx;


//-----------------------------------------------------------------------------------------------------------

function SetStage( localClientNum, bundle, filterid, stagePrefix, stageLength, accumTime, totalAccumTime, setConstants )
{
	num_consts = Gfx::GetStructFieldOrZero( bundle, stagePrefix + "num_consts" );
	for ( constIdx = 0 ; constIdx < num_consts ; constIdx++ )
	{
		constPrefix = stagePrefix + "c";
		if ( constIdx < 10 ) constPrefix += "0";
		constPrefix += constIdx + "_";

		startValue = gfx::getShaderConstantValue( bundle, constPrefix, "start", false );
		endValue   = gfx::getShaderConstantValue( bundle, constPrefix, "end",   false );
		delays     = gfx::getShaderConstantValue( bundle, constPrefix, "delay", true );

		channels = GetStructField( bundle, constPrefix + "channels" );
		isColor = IsString( channels ) && ( channels == "color" || channels == "color+alpha" );

		animName = GetStructField( bundle, constPrefix + "anm" );

		values = [];
		for ( i=0 ; i<4 ; i++ )
			values[i] = 0;

		// Ease in/out: http://gizma.com/easing/
		for ( chanIdx = 0 ; chanIdx < startValue.size ; chanIdx++ )
		{
			delayTime = delays[ ( isColor ? 0 : chanIdx ) ] * 1000;

			if ( accumTime > delayTime && stageLength > delayTime )
			{
				timeRatio = ( accumTime - delayTime ) / ( stageLength - delayTime );
				timeRatio = math::clamp( timeRatio, 0, 1 );

				lerpRatio = 0.0;
				delta = endValue[ chanIdx ] - startValue[ chanIdx ];

				switch ( animName )
				{
					case "linear":
						lerpRatio = timeRatio;
						break;

					case "step":
						lerpRatio = 1;
						break;

					case "ease in":
						// quadratic ease in
						lerpRatio = timeRatio * timeRatio;
						break;

					case "ease out":
						// quadratic ease out
						lerpRatio = -timeRatio * ( timeRatio - 2 );
						break;

					case "ease inout":
						// quadratic easing in/out
						timeRatio *= 2;
						if ( timeRatio < 1 )
						{
							lerpRatio = 0.5 * lerpRatio * lerpRatio;
						}
						else
						{
							timeRatio -= 1;
							lerpRatio = -0.5 * ( lerpRatio * ( lerpRatio - 2 ) - 1 );
						}
						break;

					case "linear repeat":
						lerpRatio = timeRatio;
						break;

					case "linear mirror":
						if ( timeRatio > 0.5 )
							lerpRatio = 1.0 - timeRatio;
						else
							lerpRatio = timeRatio;
						break;

					case "sin":
						lerpRatio = 0.5 - 0.5*cos( 360.0 * timeRatio );
						break;

					default: // "hold"
						break;
				}

				lerpRatio = math::clamp( lerpRatio, 0, 1 );

				values[ chanIdx ] = startValue[ chanIdx ] + lerpRatio * delta;
			}
			else
			{
				values[ chanIdx ] = startValue[ chanIdx ];
			}
		}

		[[ setConstants ]]( localClientNum, GetStructField( bundle, constPrefix + "name" ), filterid, values );
	}

	// Set the time variables in scriptvector7 (all in milliseconds):
	// x: total accumulated time (since the start of the postFX bundle)
	// y: current stage accumulated time
	// z: current stage length
	stageConstants = [];
	stageConstants[0] = totalAccumTime;
	stageConstants[1] = accumTime;
	stageConstants[2] = stageLength;
	stageConstants[3] = 0;

	[[ setConstants ]]( localClientNum, "scriptvector7", filterid, stageConstants );
}

//-----------------------------------------------------------------------------
function getShaderConstantValue( bundle, constPrefix, constName, delay )
{
	channels = GetStructField( bundle, constPrefix + "channels" );

	// Color has only single delay value
	if ( delay && IsString( channels ) && ( channels == "color" || channels == "color+alpha" ) )
		channels = "1";

	vals = [];

	switch ( channels )
	{
		case 1:
		case "1":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_x" );
			break;

		case 2:
		case "2":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_x" );
			vals[1] = GetStructFieldOrZero( bundle, constPrefix + constName + "_y" );
			break;

		case 3:
		case "3":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_x" );
			vals[1] = GetStructFieldOrZero( bundle, constPrefix + constName + "_y" );
			vals[2] = GetStructFieldOrZero( bundle, constPrefix + constName + "_z" );
			break;

		case 4:
		case "4":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_x" );
			vals[1] = GetStructFieldOrZero( bundle, constPrefix + constName + "_y" );
			vals[2] = GetStructFieldOrZero( bundle, constPrefix + constName + "_z" );
			vals[3] = GetStructFieldOrZero( bundle, constPrefix + constName + "_w" );
			break;

		case "color":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_r" );
			vals[1] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_g" );
			vals[2] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_b" );
			break;

		case "color+alpha":
			vals[0] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_r" );
			vals[1] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_g" );
			vals[2] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_b" );
			vals[3] = GetStructFieldOrZero( bundle, constPrefix + constName + "_clr_a" );
			break;
	}

	return vals;
}

//-----------------------------------------------------------------------------
function GetStructFieldOrZero( bundle, field )
{
	ret = GetStructField( bundle, field );
	if ( !isdefined( ret ) )
		ret = 0;

	return ret;
}

//-----------------------------------------------------------------------------
// Should be done in code?
function getShaderConstantIndex( codeConstName )
{
	switch ( codeConstName )
	{
		case "scriptvector0": return  0;
		case "scriptvector1": return  4;
		case "scriptvector2": return  8;
		case "scriptvector3": return 12;
		case "scriptvector4": return 16;
		case "scriptvector5": return 20;
		case "scriptvector6": return 24;
		case "scriptvector7": return 28;
	}

	return -1;
}

