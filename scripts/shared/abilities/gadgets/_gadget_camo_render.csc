#using scripts\codescripts\struct;
#using scripts\shared\duplicaterender_mgr;

#insert scripts\shared\duplicaterender.gsh;
#insert scripts\shared\shared.gsh;

#using scripts\shared\system_shared;

#define OUTLINE_PREDATOR_BREAK "mc/hud_outline_predator_break" 
#define OUTLINE_PREDATOR "mc/hud_outline_predator" 
	
#define OUTLINE_ALLY_NORMAL "mc/hud_outline_predator_camo_active_ally" 
#define OUTLINE_ALLY_DISRUPT "mc/hud_outline_predator_camo_disruption_ally" 

#define OUTLINE_ENEMY_NORMAL "mc/hud_outline_predator_camo_active_enemy" 
#define OUTLINE_ENEMY_DISRUPT "mc/hud_outline_predator_camo_disruption_enemy" 

#define CAMO_REVEAL_TIME 	0.35
#define CAMO_TURNOFF_MODEL_RENDER .5

REGISTER_SYSTEM( "gadget_camo_render", &__init__, undefined )

function __init__()
{
	duplicate_render::set_dr_filter_framebuffer_duplicate( "camo_rev_dr", 90, 
	                                "gadget_camo_reveal,",                        				"gadget_camo_flicker,gadget_camo_break,hide_model",                    
	                                DR_TYPE_FRAMEBUFFER_DUPLICATE, OUTLINE_PREDATOR, DR_CULL_ALWAYS    );
	
	duplicate_render::set_dr_filter_framebuffer( "camo_rev", 90, 
	                                "gadget_camo_reveal,hide_model",                        	"gadget_camo_flicker,gadget_camo_break",                    
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_PREDATOR, DR_CULL_ALWAYS    );
	
   	duplicate_render::set_dr_filter_framebuffer( "camo_fr", 90, 
	                                "gadget_camo_on,gadget_camo_friend,hide_model",             "gadget_camo_flicker,gadget_camo_break",                    
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_ALLY_NORMAL, DR_CULL_ALWAYS    );
	
	duplicate_render::set_dr_filter_framebuffer( "camo_en", 90, 
	                                "gadget_camo_on,hide_model",                                "gadget_camo_flicker,gadget_camo_break,gadget_camo_friend", 
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_ENEMY_NORMAL, DR_CULL_ALWAYS   );
	
	duplicate_render::set_dr_filter_framebuffer( "camo_fr_fl", 80, 
	                                "gadget_camo_on,gadget_camo_flicker,gadget_camo_friend",    "gadget_camo_break",                                        
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_ALLY_DISRUPT, DR_CULL_ALWAYS   );
	
	duplicate_render::set_dr_filter_framebuffer( "camo_en_fl", 80, 
	                                "gadget_camo_on,gadget_camo_flicker",                       "gadget_camo_break,gadget_camo_friend",                     
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_ENEMY_DISRUPT, DR_CULL_ALWAYS  );
	
	duplicate_render::set_dr_filter_framebuffer( "camo_brk", 70, 
	                                "gadget_camo_on,gadget_camo_break",                         undefined,                                                  
	                                DR_TYPE_FRAMEBUFFER, OUTLINE_PREDATOR_BREAK, DR_CULL_ALWAYS );
}

#namespace gadget_camo_render;


function forceOn( local_client_num )
{
	self notify( "kill_gadget_camo_render_doreveal" );

	self duplicate_render::update_dr_flag( local_client_num, "hide_model", true );
	self MapShaderConstant( local_client_num, 0, "scriptVector0", 1, 0, 0, 0 ); 
	self duplicate_render::set_dr_flag( "gadget_camo_reveal", false );      
	self duplicate_render::set_dr_flag( "gadget_camo_on", 1 ); 
	self duplicate_render::update_dr_filters(local_client_num);
}

function doReveal( local_client_num, direction )
{
	self notify( "kill_gadget_camo_render_doreveal" );
	self endon( "kill_gadget_camo_render_doreveal" );
	
	self endon( "entityshutdown" );
	
	if ( !isdefined( self ) )
		return;
			
	delta =  CLIENT_FRAME / CAMO_REVEAL_TIME;

	if( direction )
	{
		// start
		self duplicate_render::update_dr_flag( local_client_num, "hide_model", false );
		self MapShaderConstant( local_client_num, 0, "scriptVector0", 0, 0, 0, 0 );    
		
		// loop
		model_hidden = 0;
		for( currentValue = 0; currentValue < 1; currentValue += delta )
  		{
			self MapShaderConstant( local_client_num, 0, "scriptVector0", currentValue, 0, 0, 0 );    
			if( currentValue >= CAMO_TURNOFF_MODEL_RENDER && model_hidden == 0 )
			{
				model_hidden = 1;
				self duplicate_render::update_dr_flag( local_client_num, "hide_model", true );
			}
			wait( CLIENT_FRAME );
		}

		// end
  		self MapShaderConstant( local_client_num, 0, "scriptVector0", 1, 0, 0, 0 );
   		self duplicate_render::set_dr_flag( "gadget_camo_reveal", false );	
		self duplicate_render::set_dr_flag( "gadget_camo_on", 1 );
		self duplicate_render::update_dr_filters(local_client_num);
 	}
	else
	{
		// start
 		self duplicate_render::update_dr_flag( local_client_num, "hide_model", true );
		self MapShaderConstant( local_client_num, 0, "scriptVector0", 1, 0, 0, 0 );    
	   
		// loop
		model_hidden = 1;
		for( currentValue = 1; currentValue > 0; currentValue -= delta )
		{
			self MapShaderConstant( local_client_num, 0, "scriptVector0", currentValue, 0, 0, 0 );
			if ( currentValue < CAMO_TURNOFF_MODEL_RENDER && model_hidden ) 
			{
	   			self duplicate_render::update_dr_flag( local_client_num, "hide_model", false );
				model_hidden = 0;
			}
	   		wait( CLIENT_FRAME );
		}

		// end
		self MapShaderConstant( local_client_num, 0, "scriptVector0", 0, 0, 0, 0 );
 		self duplicate_render::set_dr_flag( "gadget_camo_reveal", false );	 
	  self duplicate_render::set_dr_flag( "gadget_camo_on", 0 );
    self duplicate_render::update_dr_filters(local_client_num);
  	}	   
}

