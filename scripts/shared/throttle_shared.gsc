#insert scripts\shared\shared.gsh;

#namespace Throttle;

function private _UpdateThrottleThread( throttle )
{
	while ( IsDefined( throttle ) )
	{
		[[ throttle ]]->_UpdateThrottle();
		
		wait throttle.updateRate_;
	}
}

class Throttle
{
	var queue_;
	var processed_;
	var processLimit_;
	var updateRate_;
	
	constructor()
	{
		queue_ = [];
		processed_ = 0;
		processLimit_ = 1;
		updateRate_ = SERVER_FRAME;
	}
	
	destructor()
	{
	}
	
	function private _UpdateThrottle()
	{
		processed_ = 0;
		currentQueue = queue_;
		queue_ = [];
		
		foreach( item in currentQueue )
		{
			if ( IsDefined( item ) )
			{
				queue_[ queue_.size ] = item;
			}
		}
	}
	
	function Initialize( processLimit = 1, updateRate = SERVER_FRAME )
	{
		processLimit_ = processLimit;
		updateRate_ = updateRate;
		
		self thread Throttle::_UpdateThrottleThread( self );
	}
	
	function WaitInQueue( entity )
	{
		if ( processed_ >= processLimit_ )
		{
			// Wait in the queue
			queue_[ queue_.size ] = entity;
			
			firstInQueue = false;
			
			while ( !firstInQueue )
			{
				if ( !IsDefined( entity ) )
				{
					return;
				}
			
				if ( processed_ < processLimit_ && queue_[ 0 ] === entity )
				{
					firstInQueue = true;
					queue_[ 0 ] = undefined;
				}
				else
				{
					wait updateRate_;
				}
			}
		}
		
		processed_++;
	}
}