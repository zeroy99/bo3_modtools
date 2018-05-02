#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\vehicle_shared;

#namespace raps;
	
function autoexec main()
{
	// clientfield setup
	clientfield::register( "vehicle", "raps_side_deathfx", VERSION_SHIP, 1, "int", &do_side_death_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function adjust_side_death_dir_if_trace_fail( origin, side_dir, fxlength, up_dir )
{
	end = origin + side_dir * fxlength;
	trace = BulletTrace( origin, end, false, self, true );

	if ( trace["fraction"] < 1.0 )
	{
		new_side_dir = VectorNormalize( side_dir + up_dir );
		end = origin + new_side_dir * fxlength;
		new_trace = BulletTrace( origin, end, false, self, true );
		if ( new_trace["fraction"] > trace["fraction"] )
		{
			side_dir = new_side_dir;
		}
	}

	return side_dir;
}

function do_side_death_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{	
	self endon( "entityshutdown" );

	vehicle::wait_for_DObj( localClientNum );

	radius = 1;
	fxlength = 40;
	fxtag = "tag_body";

	if( newVal && !bInitialSnap )
	{
		if(!isdefined(self.settings))
		{
			self.settings = struct::get_script_bundle( "vehiclecustomsettings", self.scriptbundlesettings );
		}
		
		forward_direction = AnglesToForward( self.angles );
		up_direction = AnglesToUp( self.angles );
		
		origin = self GetTagOrigin( fxtag );
		if ( !isdefined( origin ) )
		{
			origin = self.origin + (0,0,15);
		}
		
		right_direction = VectorCross(forward_direction, up_direction);
		right_direction = VectorNormalize(right_direction);
		right_start = origin + right_direction * radius;
		right_direction = adjust_side_death_dir_if_trace_fail( right_start, right_direction, fxlength, up_direction );

		left_direction = -right_direction;
		left_start = origin + left_direction * radius;
		left_direction = adjust_side_death_dir_if_trace_fail( left_start, left_direction, fxlength, up_direction );

		if( isdefined( self.settings.sideExplosionFx ) )
		{
			playfx(localClientNum, self.settings.sideExplosionFx, right_start, right_direction );
			playfx(localClientNum, self.settings.sideExplosionFx, left_start, left_direction );
		}
		
		if( isdefined( self.settings.killedexplosionfx ) )
		{
			playfx(localClientNum, self.settings.killedexplosionfx, origin, (0,0,1) );
		}
		
		self PlaySound( localClientNum, self.deathfxsound );
		
		if ( isdefined( self.deathquakescale ) && self.deathquakescale > 0 )
		{
			self Earthquake( self.deathquakescale, self.deathquakeduration, origin, self.deathquakeradius );
		}
	}
}