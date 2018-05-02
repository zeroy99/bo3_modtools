#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;


function enemy_highlight_display( localClientNum, materialName, size, fovPercent, traceTimeCheck, actorsOnly, allyMaterialName )
{
	self notify( "enemy_highlight_display" );
	
	self.enemy_highlight_display = true;

	self thread enemy_highlight_display_pulse( localClientNum, actorsOnly, allyMaterialName );
	self thread enemy_highlight_display_frame( localClientNum, materialName, size, fovPercent, traceTimeCheck, allyMaterialName );
}

function enemy_highlight_display_pulse( localClientNum, actorsOnly, allyMaterialName )
{
	self endon( "enemy_highlight_display" );
						
	if ( !isDefined( actorsOnly ) )
		actorsOnly = false;

	if ( !isDefined( self.enemy_highlight_elems ) )
		self.enemy_highlight_elems = [];

	while ( isDefined( self ) )
	{
		// Wipe menu handles when client menus are cleaned up internally due to save_restore		
		if ( !isDefined( GetLuiMenu( localClientNum, "HudElementImage" ) ) )
			self.enemy_highlight_elems = [];

		a_all_entities = GetEntArray( localClientNum );
		
		self.enemy_highlight_ents = [];

	 	foreach( entity in a_all_entities )
	 	{
	 		if( entity.type == "zbarrier" )
	 			continue;

			if ( actorsOnly && entity.type != "actor" && entity.type != "player" )
				continue;
	 		
			entNum = entity GetEntityNumber();
						
			isEnemy = isDefined( entity.team ) && entity.team == "axis";
			isAlly = !isEnemy && isDefined( allyMaterialName );
			showIt = isAlive( entity ) && (isEnemy || isAlly) && !IS_TRUE( entity.no_highlight );
			
			if ( showIt && !isDefined( self.enemy_highlight_ents[entNum] ) )
			{
				self.enemy_highlight_ents[entNum] = entity;
			}
			else if ( !showIt && isDefined( self.enemy_highlight_ents[entNum] ) )
			{
				self.enemy_highlight_ents[entNum] = undefined;
				
				if ( isDefined( self.enemy_highlight_elems[entNum] ) )
				{
					CloseLUIMenu( localclientnum, self.enemy_highlight_elems[entNum] );
	 				self.enemy_highlight_elems[entNum] = undefined;
				}
			}
	 	}
	 	
	 	wait 1.0;
	}	
}

function enemy_highlight_display_frame( localClientNum, materialName, size, fovPercent, traceTimeCheck, allyMaterialName )
{
	self endon( "enemy_highlight_display" );
	
	const MENU_LIMIT = 32;
						
	if ( !isDefined( self.enemy_highlight_elems ) )
		self.enemy_highlight_elems = [];

	if ( !IsDefined( traceTimeCheck ) )
		traceTimeCheck = 1.0;
	traceTimeCheckHalfMs = int( traceTimeCheck * 500 );
	
	while ( isDefined( self ) )
	{
		// Wipe menu handles when client menus are cleaned up internally due to save_restore		
		if ( !isDefined( GetLuiMenu( localClientNum, "HudElementImage" ) ) )
			self.enemy_highlight_elems = [];
		
		// Get Player's eye and look angles
		eye = GetLocalClientEyePos( localClientNum );
		angles = GetLocalClientAngles( localClientNum );
		if ( isDefined( self.vehicle_camera_pos ) )
		{
			eye = self.vehicle_camera_pos;
			angles = self.vehicle_camera_ang;
		}

		dotLimit = cos( GetLocalClientFOV( localClientNum ) * fovPercent );
		viewDir = AnglesToForward( angles );
		
		visibleEnts = [];
		
	 	foreach( entNum, entity in self.enemy_highlight_ents )
	 	{
	 		if ( !isDefined( entity ) || !isDefined( entity.origin ) )
	 			continue;
	 		
			entPos = undefined;
			radialCoef = 0;
						
			isEnemy = isDefined( entity.team ) && entity.team == "axis";
			isAlly = !isEnemy && isDefined( allyMaterialName );
			showIt = isAlive( entity ) && (isEnemy || isAlly) && !IS_TRUE( entity.no_highlight ) && entity != self;

			if ( showIt && self.enemy_highlight_elems.size >= MENU_LIMIT && !isDefined( self.enemy_highlight_elems[entNum] ) )
				showIt = false;
						
			if ( showIt )
			{			
				if ( entity.type == "actor" || entity.type == "player" )
					entPos = entity GetTagOrigin( "J_Spine4" );
				if ( !isDefined( entPos ) )
					entPos = entity.origin + ( 0, 0, 40 );
				assert( isDefined( entPos ) );
				assert( isDefined( eye ) );
				deltaDir = VectorNormalize( entPos - eye );
				dot = VectorDot( deltaDir, viewDir );
				if ( dot < dotLimit )
					showIt = false;
				else
					radialCoef = max( ( ( 1.0 - dot ) / ( 1.0 - dotLimit ) ) - 0.5, 0.0 );
				
				if ( showIt && ( !isDefined( entity.highlight_trace_next ) || entity.highlight_trace_next <= GetServerTime( localClientNum ) ) )
				{
					from = eye + deltaDir * 100;
					to = entPos + deltaDir * -100;
					trace_point = TracePoint( from, to );
					entity.highlight_trace_result = ( trace_point["fraction"] >= 1.0 );
					entity.highlight_trace_next = GetServerTime( localClientNum ) + ( traceTimeCheckHalfMs ) + RandomIntRange( 0, traceTimeCheckHalfMs );
				}
			}
				 		
	 		if ( showIt && entity.highlight_trace_result )
	 		{			
				screenProj = Project3Dto2D( localClientNum, entPos );
				
				if ( !isDefined( self.enemy_highlight_elems[entNum] ) )
				{
					if ( isEnemy )
						self.enemy_highlight_elems[entNum] = self create_target_indicator( localClientNum, entity, materialName, size );
					else
						self.enemy_highlight_elems[entNum] = self create_target_indicator( localClientNum, entity, allyMaterialName, size );
				}

				elem = self.enemy_highlight_elems[entNum];
				
				if ( isDefined( elem ) )
				{					
					visibleEnts[entNum] = elem;

					SetLuiMenuData( localClientNum, elem, "x", screenProj[0] - ( size * 0.5 ) );
					SetLuiMenuData( localClientNum, elem, "y", screenProj[1] - ( size * 0.5 ) );
					SetLuiMenuData( localClientNum, elem, "alpha", 1.0 - radialCoef );
					if ( isEnemy )
					{
						// Enemy - white material
						SetLuiMenuData( localClientNum, elem, "red", 		1.0 );
						SetLuiMenuData( localClientNum, elem, "green", 		0.0 );
					}
					else
					{
						// Ally - pre-colored
						SetLuiMenuData( localClientNum, elem, "red", 		0.0 );
						SetLuiMenuData( localClientNum, elem, "green", 		1.0 );
					}
				}						
	 		}
	 	}
	 	
	 	// Cleanup icons that no longer have a visible entity for them
	 	removeEnts = [];
	 	foreach ( entNum, val in self.enemy_highlight_elems )
	 	{
	 		if ( !isDefined( visibleEnts[entNum] ) )
	 			removeEnts[entNum] = entNum;
	 	}
	 	foreach ( entNum, val in removeEnts )
	 	{
 			CloseLUIMenu( localclientnum, self.enemy_highlight_elems[entNum] );
 			self.enemy_highlight_elems[entNum] = undefined;
	 	}
		
		WAIT_CLIENT_FRAME;
	}	
}

function enemy_highlight_display_stop( localClientNum )
{
	self notify( "enemy_highlight_display" );
	self endon( "enemy_highlight_display" );
	
	WAIT_CLIENT_FRAME;
	
	if ( isDefined( self.enemy_highlight_elems ) )
	{
		foreach ( hudelem in self.enemy_highlight_elems )
			CloseLUIMenu( localclientnum, hudelem );

		self.enemy_highlight_elems = undefined;
	}

	self.enemy_highlight_display = undefined;
}

function create_target_indicator( localClientNum, entity, materialName, size ) // self = player
{
	hudelem = CreateLUIMenu( localClientNum, "HudElementImage" );
	
	if ( isDefined( hudelem ) )
	{
		// These must be set prior to calling OpenLUIMenu so that the values will be subscribed and updated each frame
		
		SetLuiMenuData( localClientNum, hudelem, "x", 			0 );
		SetLuiMenuData( localClientNum, hudelem, "y", 			0 );
		SetLuiMenuData( localClientNum, hudelem, "width", 		size );
		SetLuiMenuData( localClientNum, hudelem, "height", 		size );
		SetLuiMenuData( localClientNum, hudelem, "alpha", 		1.0 );
		SetLuiMenuData( localClientNum, hudelem, "material", 	materialName );
		SetLuiMenuData( localClientNum, hudelem, "red", 		1.0 );
		SetLuiMenuData( localClientNum, hudelem, "green", 		0.0 );
		SetLuiMenuData( localClientNum, hudelem, "blue", 		0.0 );
		SetLuiMenuData( localClientNum, hudelem, "zRot", 		0.0 );

		OpenLUIMenu( localclientnum, hudelem );
	}
		
	return hudelem;	
}

