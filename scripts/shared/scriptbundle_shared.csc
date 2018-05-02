#insert scripts\shared\shared.gsh;

#using scripts\shared\util_shared;

#namespace scriptbundle;

class cScriptBundleObjectBase
{
	var _s;					// struct that holds gdt data for object
	var _o_bundle;			// reference to parent bundle object
	var _e_array;			// entities associated with this bundle object
	var _n_clientnum;
		
	constructor()
	{
	}
	
	destructor()
	{
	}
	
	function init( s_objdef, o_bundle, e_ent, localclientnum )
	{
		_s = s_objdef;
		_o_bundle = o_bundle;
		
		if ( isdefined( e_ent ) )
		{
			Assert( !isdefined( localclientnum ) || ( e_ent.localclientnum == localclientnum ), "Local client number mismatch." );
			
			_n_clientnum = e_ent.localclientnum;
			_e_array[ _n_clientnum ] = e_ent;
		}
		else
		{
			_e_array = [];
			
			if ( isdefined( localclientnum ) )
			{
				_n_clientnum = localclientnum;
			}
		}
	}
	
	function log( str_msg )
	{
		/# PrintLn( [[ _o_bundle ]] -> get_type() + " " + [[ _o_bundle ]] -> get_name() + ": (" + STR_DEFAULT( _s.name, "no name" ) + ") " + str_msg ); #/
	}
	
	function error( condition, str_msg )
	{
		if ( condition )
		{
			if ( [[_o_bundle]]->is_testing() )
			{
				scriptbundle::error_on_screen( str_msg );
			}
			else
			{
				AssertMsg( [[ _o_bundle ]] -> get_type() + " " + [[ _o_bundle ]] -> get_name() + ": (" + STR_DEFAULT( _s.name, "no name" ) + ") " + str_msg );
			}
			
			thread [[_o_bundle]]->on_error();
			return true;
		}
				
		return false;
	}
	
	function get_ent( localClientNum )
	{
		return _e_array[localClientNum];
	}
}

class cScriptBundleBase
{
	var _s;			// struct that holds gdt data for bundle
	var _str_name;	// name of bundle
	var _a_objects;
	
	var _testing;
	
	function on_error( e ) { }	// IMPLEMENT IN DERIVED CLASS
	
	constructor()
	{
		_a_objects = [];
		_testing = false;
	}
	
	destructor()
	{
	}
	
	function init( str_name, s, b_testing )
	{
		_s = s;
		_str_name = str_name;
		_testing = b_testing;
	}
	
	function get_type()
	{
		return _s.type;
	}
	
	function get_name()
	{
		return _str_name;
	}
	
	function get_vm()
	{
		return _s.vmtype;
	}
	
	function get_objects()
	{
		return _s.objects;
	}
	
	function is_testing()
	{
		return _testing;
	}
	
	function add_object( o_object )
	{
		ARRAY_ADD( _a_objects, o_object );
	}
	
	function remove_object( o_object )
	{
		ArrayRemoveValue( _a_objects, o_object );
	}
	
	function log( str_msg )
	{
		/# PrintLn( _s.type + " " + _str_name + ": " + str_msg ); #/
	}
	
	function error( condition, str_msg )
	{
		if ( condition )
		{
			if ( _testing )
			{
//				scriptbundle::error_on_screen( str_msg );
			}
			else
			{
				AssertMsg( _s.type + " " + _str_name + ": " + str_msg );
			}
			
			thread [[self]]->on_error();
			return true;
		}
				
		return false;
	}
}

function error_on_screen( str_msg )
{
	if ( str_msg != "" )
	{
		if ( !isdefined( level.scene_error_hud ) )
		{
			level.scene_error_hud = CreateLUIMenu( 0, "HudElementText" );
			SetLuiMenuData( 0, level.scene_error_hud, "alignment", LUI_HUDELEM_ALIGNMENT_LEFT );
			SetLuiMenuData( 0, level.scene_error_hud, "x", 0 );
			SetLuiMenuData( 0, level.scene_error_hud, "y", 10 );
			SetLuiMenuData( 0, level.scene_error_hud, "width", 1920 );
			OpenLUIMenu( 0, level.scene_error_hud );
		}
		
		SetLuiMenuData( 0, level.scene_error_hud, "text", str_msg );
		self thread _destroy_error_on_screen();
	}
}

function _destroy_error_on_screen()
{
	level notify( "_destroy_error_on_screen" );
	level endon( "_destroy_error_on_screen" );
	
	self util::waittill_notify_or_timeout( "stopped", 5 );
	
	CloseLuiMenu( 0, level.scene_error_hud );
	level.scene_error_hud = undefined;
}
