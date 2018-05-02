#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_driving_fx;

#namespace metal_storm;

REGISTER_SYSTEM( "metal_storm", &__init__, undefined )

function __init__()
{
	/# println("*** Client : _metalstorm running..."); #/
	
	clientfield::register( "vehicle", "toggle_gas_freeze",						VERSION_SHIP, 1, "int", &field_toggle_gas_freeze, 						!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	
	vehicle::add_vehicletype_callback( "drone_metalstorm", &metalstorm_setup );
	vehicle::add_vehicletype_callback( "drone_metalstorm_rts", &metalstorm_setup );
}

function metalstorm_setup( localClientNum )
{
	self thread driving_fx::collision_thread( localClientNum );
		
	self thread metalstorm_player_enter();
}

function metalstorm_player_enter( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	while ( 1 )
	{
		self waittill( "enter_vehicle", user );

		if ( user isplayer() )
		{
			level.player_metalstorm = self;
			wait( 0.1 );	// to prevent getting an early exit notify
			
			// Update feedback
			self thread metalstorm_update_rumble();									

			self waittill( "exit_vehicle" );

			level.player_metalstorm = undefined;
		}
	}
}

// Lots of gross hardcoded values! :( 
function metalstorm_update_rumble()
{
	self endon( "death" );
	self endon( "entityshutdown" );	
	self endon( "exit_vehicle" );

	while ( 1 )
	{
		vr = Abs( self GetSpeed() / self GetMaxSpeed() );
		
		if ( vr < 0.1 )
		{
			level.localplayers[0] PlayRumbleOnEntity( 0, "pullout_small" );		
			wait( 0.3 );						
		}
		else if ( vr > 0.01 && vr < 0.8 || Abs( self GetSteering() ) > 0.5 )
		{
			level.localplayers[0] Earthquake( 0.1, 0.1, self.origin, 200 );			
			level.localplayers[0] PlayRumbleOnEntity( 0, "pullout_small" );		
			wait( 0.1 );			
		}
		else if ( vr > 0.8 )
		{
			time = RandomFloatRange( 0.15, 0.2 );
			level.localplayers[0] Earthquake( RandomFloatRange( 0.1, 0.15 ), time, self.origin, 200 );
			level.localplayers[0] PlayRumbleOnEntity( 0, "pullout_small" );		
			wait( time );							
		}
		else
		{
			wait( 0.1 );
		}
	}
}

#define N_TRANSITION_ON_TIME		3
#define N_TRANSITION_OFF_TIME		3
#define N_UNUSED					0
function field_toggle_gas_freeze( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self endon( "death" );
	self endon( "entityshutdown" );
		
	self MapShaderConstant( localClientNum, 0, "ScriptVector0" );
	s_timer = util::new_timer();
	
	do
	{
		wait(0.01);
		
		n_current_time = s_timer util::get_time_in_seconds();
		n_delta_val = LerpFloat( 0, 0.85, n_current_time / N_TRANSITION_ON_TIME );
	
		self SetShaderConstant( localClientNum, 0, N_UNUSED, N_UNUSED, n_delta_val, N_UNUSED );
	}
	while ( n_current_time < N_TRANSITION_OFF_TIME );
}
