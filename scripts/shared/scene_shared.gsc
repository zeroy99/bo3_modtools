
#namespace scene;

/@
"Summary: Plays a scene or multiple scenes"
"SPMP: shared"


"Name: play( str_val, str_key, ents )"
"CallOn: level using KVP to specify the scene instances"
"MandatoryArg: <str_val> value of the KVP of the scene entity"
"MandatoryArg: <str_key> key of the KVP of the scene entity"
"OptionalArg: [ents] override the entities used for this scene"
"Example: level scene::play( "my_scenes", "targetname" );"


"Name: play( str_scenedef, ents )"
"CallOn: level"
"MandatoryArg: <str_scenedef> specify the scene name, will play all instances of this scene"
"OptionalArg: [ents] override the entities used for this scene"	
"Example: level scene::play( "level1_scene_3" );"

	
"Name: play( str_scenedef, ents )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"OptionalArg: [ents] override the entities used for this scene"	
"Example: e_scene_root scene::play( "level1_scene_3" );"


"Name: play( ents, str_scenedef )"
"CallOn: Any entity (script_origin, script_struct, ai, script_model, script_brushmodel, player)"
"OptionalArg: [ents] override the entities used for this scene"
"OptionalArg: [str_scenedef] specify the scene name if needed"
"Example: s_scene_object scene::play( array( e_guy1, e_guy2 ) );"
@/
function play( arg1, arg2, arg3, b_test_run = false, str_state, str_mode = "" ) {}

/@
"Summary: Adds a function to be called when a scene starts"
"SPMP: shared"


"Name: add_scene_func( str_scenedef, func, str_state = "play" )"
"CallOn: level"
"MandatoryArg: <str_scenedef> Name of scene"
"MandatoryArg: <func> function to call when scene starts"
"OptionalArg: [str_state] set to "init" or "done" if you want to the function to get called in one of those states"	
"Example: level scene::init( "my_scenes", "targetname" );"
@/
function add_scene_func( str_scenedef, func, str_state = "play", ... ) {}

/@
"Summary: Removes a function to be called when a scene starts"
"SPMP: shared"


"Name: remove_scene_func( str_scenedef, func, str_state = "play" )"
"CallOn: level"
"MandatoryArg: <str_scenedef> Name of scene"
"MandatoryArg: <func> function to remove"
"OptionalArg: [str_state] set to "init" or "done" if you want to the function to get removed from one of those states"
"Example: level scene::init( "my_scenes", "targetname" );"
@/

function remove_scene_func( str_scenedef, func, str_state = "play" ) {}