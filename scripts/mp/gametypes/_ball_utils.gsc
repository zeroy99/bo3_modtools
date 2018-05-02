
#namespace ball;

function add_ball_return_trigger( trigger )
{
	if ( !IsDefined( level.ball_return_trigger ) )
	{
		level.ball_return_trigger = [];
	}
	
	level.ball_return_trigger[level.ball_return_trigger.size] = trigger;
}

