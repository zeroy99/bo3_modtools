#insert scripts\shared\shared.gsh;

function AiPathingTest()
{
	level.pathNodeHints = GetNodeArray( "path_hint", "targetname" );
	
	foreach ( pathnode in level.pathNodeHints )
	{
		pathnode.connectionLinks = [];
		
		for( i=0; i<level.pathNodeHints.size; i++ )
		{
			if( pathnode != level.pathNodeHints[i] )
			{
				if( self FindPath( pathnode.origin, level.pathnodeHints[i].origin, true ) )
				{
					pathnode.connectionLinks[i] = true; 
				}
				else
				{
					pathnode.connectionLinks[i] = false;
				}
			}
		}
	}	
	
	while(1)
	{
		foreach ( pathnode in level.pathNodeHints )
		{
			for( i=0; i<level.pathNodeHints.size; i++ )
			{
				if( pathnode != level.pathNodeHints[i] )
				{
					if( pathnode.connectionLinks[i] )
					{
						/# recordLine( pathnode.origin, level.pathNodeHints[i].origin, GREEN, "Script" ); #/
					}
					else
					{
						/# recordLine( pathnode.origin, level.pathNodeHints[i].origin, RED, "Script" ); #/
					}
				}
			}
		}
		
		WAIT_SERVER_FRAME;
	}
}