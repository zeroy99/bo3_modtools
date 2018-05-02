#using scripts\codescripts\struct;

#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#precache( "fx", "destruct/fx_dest_k_rail" );

// ============================================================================
//										 Utility 
// ============================================================================

REGISTER_SYSTEM( "floor_collapse", &__init__, undefined )

function __init__()
{
	level thread precache_destruct_fx();

	positions = struct::get_array("dest_floor_panels","script_noteworthy");	
	
	level.floor_models = [];
		
	foreach(struct in positions)
	{	
		if(IsDefined(struct.model))
		{
			array::add(level.floor_models, struct.model, false);
			struct.modelname = struct.model;
		}
		else
		{
			array::add(level.floor_models, "p6_dest_floor", false);
			struct.modelname = "p6_dest_floor";
		}	
	}
	
	if(level.floor_models.size == 0)
	{
		level.floor_models = array("p6_dest_floor");
	}	
		
	level thread floor_collapse_init(positions);
}

// ============================================================================
function floor_collapse_init(positions)
{
	if(!IsDefined(level.floor_damage_percentage))
	{
		level.floor_damage_percentage = randomfloatrange(.4,.6);
	}	
		
	//positions = struct::get_array("dest_floor_panels","targetname");	
	positions = array::randomize(positions);
	flr_model = [];
	
	for( i = 0; i < positions.size; i++)
	{
		if(!IsDefined(positions[i].angles))
		{
			positions[i].angles = (0, 0, 0);
		}
		

		if(level.floor_damage_percentage >= ((i+1) / positions.size))
		{	
			if(!IsDefined(positions[i].script_width))
			{
				positions[i].script_width = 128;
			}
			if(!IsDefined(positions[i].script_length))
			{
				positions[i].script_length = 128;
			}
			if(!IsDefined(positions[i].hlth))
			{
				if(IsDefined(positions[i].script_float))
				{
					positions[i].hlth = positions[i].script_float;
				}
				else
				{	
					//will take 2 seconds to collapse unless sprinting
					positions[i].hlth = 20;
				}
			}
	
			flr_model[i] = spawn( "script_model", positions[i].origin, 1 );
			flr_model[i].angles = positions[i].angles;
			flr_model[i] SetModel( positions[i].modelname + "_damaged" );
			flr_model[i].modelname = positions[i].modelname;
			
			if(IsDefined(positions[i].target))
			{
				flr_model[i].clip = GetEnt(positions[i].target, "targetname");
				flr_model[i].clip SetMovingPlatformEnabled( true );
			}	
			//flr_model[i] ConnectPaths();
			
			flr_model[i].trig = Spawn( "trigger_box", positions[i].origin, 0, positions[i].script_width,  positions[i].script_length, 64);
			flr_model[i].hlth = positions[i].hlth;

			if(!Isdefined(flr_model[i].break_fx))
				flr_model[i].break_fx = level._effect[ "floor_destruct" ];
			
			flr_model[i] thread damage_floor_watcher();
			flr_model[i] thread walk_floor_watcher();
		}
		else
		{
			flr_model[i] = spawn( "script_model", positions[i].origin, 1 );
			flr_model[i].angles = positions[i].angles;
			flr_model[i] SetModel( positions[i].modelname );
			
			if(IsDefined(positions[i].target))
			{
				flr_model[i].clip = GetEnt(positions[i].target, "targetname");
				flr_model[i].clip SetMovingPlatformEnabled( true );
			}				
			//flr_model[i] ConnectPaths();
		}	
	}	
	
}

// ============================================================================
function walk_floor_watcher()
{
	self endon("destroyed");

	level waittill( "prematch_over" );

	waittime = 1.0;
	
	while(true)
	{
		self.trig waittill("trigger", who);

		//points of damage per second player in trigger
		amount = 10;  
		
		if(who GetStance() == "prone")
		{
			amount = 0;
		}
		else if(who GetStance() == "crouch")
		{
			amount = 1; //may add some damage for crouch.
		}		

		//if sprinting collapse immediately.
		if(isdefined( who.sprinting ) && who.sprinting == 1 )
		{
			amount = self.hlth;
			//do_shake = 1;
		}	

		self.hlth = self.hlth - amount;
		
		if(amount > 0)
		{
			if(self.hlth <=0)
			{
				nduration = (amount / 10);
			}	
			else
			{
				nduration = waittime;
			}	

			// Earthquake
			nMagnitude = (0.04 * amount);
			nRadius = 500;
			v_pos = self.origin;
			Earthquake( nMagnitude, nDuration, v_pos, nRadius );
		}
		
		if (self.hlth <= 0) 
		{
			self SetModel( self.modelname + "_destroyed" );

			Self.trig Delete();

			PlayFx(self.break_fx, self.origin);
			//self playsound(self.break_sound);				

			Self NotSolid();
			if(IsDefined(self.clip))
			{
				self.clip Delete();
			}	
			Self DisconnectPaths();

			self notify("destroyed");
			return;
		}
		wait(waittime);
	}
}
		
function damage_floor_watcher()
{
	self endon("destroyed");

	self setcandamage(true);
	
	while(true)
	{
		
		self waittill( "damage", amount, who, direction_vec, point, type, modelName, tagName, partName );
		
		self.hlth = self.hlth - amount;
		if (self.hlth <= 0) 
		{
			self SetModel( self.modelname + "_destroyed" );
			
			Self.trig Delete();

			PlayFx(self.break_fx, self.origin);
			//self playsound(self.break_sound);				

			Self NotSolid();
			if(IsDefined(self.clip))
			{
				self.clip Delete();
			}			
			Self DisconnectPaths();
			
			self notify("destroyed");
			return;
		}
		wait(1);
	}
}


// ============================================================================
function precache_destruct_fx()
{
	level._effect[ "floor_destruct" ]						= "destruct/fx_dest_k_rail";
}	