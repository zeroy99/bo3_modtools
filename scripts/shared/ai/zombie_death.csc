
#using scripts\codescripts\struct;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#precache( "client_fx", "zombie/fx_fire_torso_zmb" );

function autoexec init_fire_fx()
{
	WAIT_CLIENT_FRAME; 
	DEFAULT(level._effect,[]);
	level._effect["character_fire_death_sm"]    = "zombie/fx_fire_torso_zmb";
	level._effect["character_fire_death_torso"] = "zombie/fx_fire_torso_zmb";
}


function on_fire_timeout( localClientNum )
{
	self endon ("death");
	self endon( "entityshutdown" );
	
	// about the length of the flame fx
	wait 12;

	if (isdefined(self) && IsAlive(self))
	{
		self.is_on_fire = false;
		self notify ("stop_flame_damage");
	}
	
}


function flame_death_fx( localClientNum )
{
	self endon( "death" );
	self endon( "entityshutdown" );

	if ( IS_TRUE(self.is_on_fire) )
	{
		return;
	}
	
	self.is_on_fire = true;
	
	self thread on_fire_timeout();

	if( isdefined( level._effect ) && isdefined( level._effect["character_fire_death_torso"] ) )
	{
		fire_tag = "j_spinelower";
		
		if( !isDefined( self GetTagOrigin( fire_tag)))  //allows effect to play on parasite and insanity elementals
		{
			fire_tag = "tag_origin";
		}
		
		if ( !isDefined( self.isdog) || !self.isdog )
		{
			PlayFxOnTag( localClientNum, level._effect["character_fire_death_torso"], self, fire_tag );
		}
	}
	else
	{
/#
		println( "^3ANIMSCRIPT WARNING: You are missing level._effect[\"character_fire_death_torso\"], please set it in your levelname_fx.gsc. Use \"env/fire/fx_fire_player_torso\"" ); 
#/
	}

	if( isdefined( level._effect ) && isdefined( level._effect["character_fire_death_sm"] ) )
	{
		if( self.archetype !== "parasite" && self.archetype !== "raps" )
		{
			wait 1;
	
			tagArray = []; 
			tagArray[0] = "J_Elbow_LE"; 
			tagArray[1] = "J_Elbow_RI"; 
			tagArray[2] = "J_Knee_RI"; 
			tagArray[3] = "J_Knee_LE"; 
			tagArray = randomize_array( tagArray ); 
	
			PlayFxOnTag( localClientNum, level._effect["character_fire_death_sm"], self, tagArray[0] ); 
	
			wait 1;
	
			tagArray[0] = "J_Wrist_RI"; 
			tagArray[1] = "J_Wrist_LE"; 
			if( !IS_TRUE(self.missinglegs) )
			{
				tagArray[2] = "J_Ankle_RI"; 
				tagArray[3] = "J_Ankle_LE"; 
			}
			tagArray = randomize_array( tagArray ); 
	
			PlayFxOnTag( localClientNum, level._effect["character_fire_death_sm"], self, tagArray[0] ); 
			PlayFxOnTag( localClientNum, level._effect["character_fire_death_sm"], self, tagArray[1] );
		}
	}
	else
	{
/#
		println( "^3ANIMSCRIPT WARNING: You are missing level._effect[\"character_fire_death_sm\"], please set it in your levelname_fx.gsc. Use \"env/fire/fx_fire_zombie_md\"" ); 
#/
	}	
}


// MikeD( 9/30/2007 ): Taken from maps\_utility "array_randomize:, for some reason maps\_utility is included in a animscript
// somewhere, but I can't call it within in this... So I made a new one.
function randomize_array( array )
{
    for( i = 0; i < array.size; i++ )
    {
        j = RandomInt( array.size ); 
        temp = array[i]; 
        array[i] = array[j]; 
        array[j] = temp; 
    }
    return array; 
}
