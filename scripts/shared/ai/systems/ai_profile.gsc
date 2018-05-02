#insert scripts\shared\shared.gsh;

class AIProfile_ScopedSampler_t
{
	function start( name ) { AIProfile_BeginEntry( name ); }
	destructor() { AIProfile_EndEntry(); }
}
