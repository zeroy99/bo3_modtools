#using scripts\codescripts\struct;
#using scripts\shared\duplicaterender_mgr;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;

#using scripts\shared\system_shared;

#define CLONE_MATERIAL_ALLY 				"mc/ability_clone_ally" 
#define CLONE_MATERIAL_ENEMY 				"mc/ability_clone_enemy" 
#define CLONE_MATERIAL_DAMAGE_ALLY 			"mc/ability_clone_ally_damage" 
#define CLONE_MATERIAL_DAMAGE_ENEMY 		"mc/ability_clone_enemy_damage" 

#define CLONE_SHADER_RAMP_IN_SPEED			.04	// Units per network frame.  0 < speed <= 1.0
#define CLONE_SHADER_X_UNUSED				1	
#define CLONE_SHADER_Z_TINT_INDEX			0	
#define CLONE_SHADER_W_WIRE_BRIGHTNESS		0.04	
#define CLONE_SHADER_CONST					"scriptVector3"
	
REGISTER_SYSTEM( "gadget_clone_render", &__init__, undefined )
	
function __init__()
{
	duplicate_render::set_dr_filter_framebuffer( "clone_ally", 90, 
	                                "clone_ally_on", "clone_damage",                    
	                                DR_TYPE_FRAMEBUFFER, CLONE_MATERIAL_ALLY, DR_CULL_ALWAYS    );
	duplicate_render::set_dr_filter_framebuffer( "clone_enemy", 90, 
	                                "clone_enemy_on", "clone_damage",                    
	                                DR_TYPE_FRAMEBUFFER, CLONE_MATERIAL_ENEMY, DR_CULL_ALWAYS    );
	duplicate_render::set_dr_filter_framebuffer( "clone_damage_ally", 90, 
	                                "clone_ally_on,clone_damage", undefined,                    
	                                DR_TYPE_FRAMEBUFFER, CLONE_MATERIAL_DAMAGE_ALLY, DR_CULL_ALWAYS    );
	duplicate_render::set_dr_filter_framebuffer( "clone_damage_enemy", 90, 
	                                "clone_enemy_on,clone_damage", undefined,                    
	                                DR_TYPE_FRAMEBUFFER, CLONE_MATERIAL_DAMAGE_ENEMY, DR_CULL_ALWAYS    );
}

#namespace gadget_clone_render;

function transition_shader( localClientNum )
{
	self endon ( "entityshutdown" );
	self endon ( "clone_shader_off" );
	
	rampInShader = 0.0;
	while( rampInShader < 1.0 )
	{
		if( isDefined( self ) )
		{
			self MapShaderConstant( localClientNum, 0, CLONE_SHADER_CONST, CLONE_SHADER_X_UNUSED, rampInShader, CLONE_SHADER_Z_TINT_INDEX, CLONE_SHADER_W_WIRE_BRIGHTNESS ); 
		}
		rampInShader += CLONE_SHADER_RAMP_IN_SPEED;
		WAIT_CLIENT_FRAME;
	}
}