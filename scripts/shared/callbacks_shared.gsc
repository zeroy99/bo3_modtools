
#namespace callback;

function callback( event, params ) {}

function add_callback( event, func, obj ) {}

function remove_callback( event, func, obj ) {}

function on_finalize_initialization( func, obj ) {}


/@
"Name: on_connect(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player connects"
"MandatoryArg: <func> the function you want to call on the new player."
"Example: callback::on_connect(&on_player_connect);"
"SPMP: singleplayer"
@/
function on_connect( func, obj ) {}


/@
"Name: remove_on_connect(<func>)"
"Summary: Remove a callback for when a player connects"
"MandatoryArg: <func> the function you want to Remove on the new player."
"Example: callback::remove_on_connect(&on_player_connect);"
@/
function remove_on_connect( func, obj ) {}


/@
"Name: on_connecting(<func>)"
"Summary: Set a callback for when a player is connecting"
"MandatoryArg: <func> the function you want to call on the new player."
"Example: callback::on_connecting(&on_player_connect);"
@/
function on_connecting( func, obj ) {}


/@
"Name: remove_on_connecting(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player is connecting"
"MandatoryArg: <func> the function you want to Remove on the new player."
"Example: callback::remove_on_connecting(&on_player_connect);"
@/
function remove_on_connecting( func, obj ) {}


function on_disconnect( func, obj ) {}


/@
"Name: remove_on_disconnect(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a player connects"
"MandatoryArg: <func> the function you want to remove when a player disconnects."
"Example: callback::remove_on_disconnect(&on_player_disconnect);"
@/
function remove_on_disconnect( func, obj ) {}


/@
"Name: on_spawned( <func> )"
"Summary: Set a callback for when a player spawns"
"MandatoryArg: <func> the function you want to call on the new player."
"Example: callback::on_connect( &on_player_spawned );"
@/
function on_spawned( func, obj ) {}


/@
"Name: remove_on_spawned(<func>)"
"Summary: Remove a callback for when a player spawns"
"MandatoryArg: <func> the function you want to remove on the new player."
"Example: callback::remove_on_spawned( &on_player_spawned );"
@/
function remove_on_spawned( func, obj ) {}


/@
"Name: on_loadout( <func> )"
"Summary: Set a callback for when a player gets their loadout set"
"MandatoryArg: <func> the function you want to call when a player gets their loadout set."
"Example: callback::on_loadout( &on_loadout );"
@/
function on_loadout( func, obj ) {}


/@
"Name: remove_on_loadout( <func> )"
"Summary: Remove a callback for when a player gets their loadout set"
"MandatoryArg: <func> the function you want to remove."
"Example: callback::remove_on_loadout( &on_loadout );"
@/
function remove_on_loadout( func, obj ) {}


/@
"Name: on_player_damage(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player get damaged"
"MandatoryArg: <func> the function you want to call on the damaged player."
"Example: callback::on_player_damage(&on_player_damage);"
@/
function on_player_damage( func, obj ) {}


/@
"Name: remove_on_player_damage(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a player get damaged"
"MandatoryArg: <func> the function you want to Remove on the damaged player."
"Example: callback::remove_on_player_damage(&on_player_damage);"
@/
function remove_on_player_damage( func, obj ) {}


/@
"Name: on_start_gametype(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player starts a gametype"
"MandatoryArg: <func> the function you want to call on the player."
"Example: callback::on_start_gametype( &init );"
@/
function on_start_gametype( func, obj ) {}


/@
"Name: on_joined_team(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player joins a team"
"MandatoryArg: <func> the function you want to call on the player joining a team."
"Example: callback::on_joined_team( &init );"
@/
function on_joined_team( func, obj ) {}


/@
"Name: on_joined_spectate(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player joins spectate"
"MandatoryArg: <func> the function you want to call on the player joining a team."
"Example: callback::on_joined_spectate( &init );"
@/
function on_joined_spectate( func, obj ) {}


/@
"Name: on_player_killed(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player dies"
"MandatoryArg: <func> the function you want to call when a player dies."
"Example: callback::on_player_killed(&on_player_killed);"
"SPMP: singleplayer"
@/
function on_player_killed( func, obj ) {}


/@
"Name: remove_on_player_killed(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a player dies"
"MandatoryArg: <func> the function you want to remove when a player dies."
"Example: callback::remove_on_player_killed(&on_player_killed);"
"SPMP: singleplayer"
@/
function remove_on_player_killed( func, obj ) {}


/@
"Name: on_ai_killed(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a ai dies"
"MandatoryArg: <func> the function you want to call when a ai dies."
"Example: callback::on_ai_killed(&on_ai_killed);"
@/
function on_ai_killed( func, obj ) {}


/@
"Name: remove_on_ai_killed(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a ai dies"
"MandatoryArg: <func> the function you want to remove when a ai dies."
"Example: callback::remove_on_ai_killed(&on_ai_killed);"
@/
function remove_on_ai_killed( func, obj ) {}


/@
"Name: on_actor_killed(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a actor dies"
"MandatoryArg: <func> the function you want to call when a actor dies."
"Example: callback::on_actor_killed(&on_actor_killed);"
@/
function on_actor_killed( func, obj ) {}


/@
"Name: remove_on_actor_killed(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a actor dies"
"MandatoryArg: <func> the function you want to remove when a actor dies."
"Example: callback::remove_on_actor_killed(&on_actor_killed);"
@/
function remove_on_actor_killed( func, obj ) {}


/@
"Name: on_vehicle_spawned(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a vehicle spawns"
"MandatoryArg: <func> the function you want to call when a vehicle dies."
"Example: callback::on_vehicle_spawned(&on_vehicle_spawned);"
@/
function on_vehicle_spawned( func, obj ) {}


/@
"Name: remove_on_vehicle_spawned(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a vehicle spawns"
"MandatoryArg: <func> the function you want to remove when a vehicle dies."
"Example: callback::remove_on_vehicle_spawned(&on_vehicle_spawned);"
@/
function remove_on_vehicle_spawned( func, obj ) {}


/@
"Name: on_vehicle_killed(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a vehicle dies"
"MandatoryArg: <func> the function you want to call when a vehicle dies."
"Example: callback::on_vehicle_killed(&on_vehicle_killed);"
@/
function on_vehicle_killed( func, obj ) {}


/@
"Name: remove_on_vehicle_killed(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a vehicle dies"
"MandatoryArg: <func> the function you want to remove when a vehicle dies."
"Example: callback::remove_on_vehicle_killed(&on_vehicle_killed);"
@/
function remove_on_vehicle_killed( func, obj ) {}


/@
"Name: on_ai_damage(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when an ai takes damage"
"MandatoryArg: <func> the function you want to call when an ai takes damage."
"Example: callback::on_ai_damage(&on_ai_damage);"
@/
function on_ai_damage( func, obj ) {}


/@
"Name: remove_on_ai_damage(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a ai gets damaged"
"MandatoryArg: <func> the function you want to remove when a ai recieves damage."
"Example: callback::remove_on_ai_damage(&on_ai_killed);"
@/
function remove_on_ai_damage( func, obj ) {}


/@
"Name: on_ai_spawned(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when an ai spawns"
"MandatoryArg: <func> the function you want to call when an ai spawns."
"Example: callback::on_ai_spawned(&on_ai_spawned);"
@/
function on_ai_spawned( func, obj ) {}


/@
"Name: remove_on_ai_spawned(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a ai spawns"
"MandatoryArg: <func> the function you want to remove when a ai spawns."
"Example: callback::remove_on_ai_spawned(&on_ai_spawned);"
@/
function remove_on_ai_spawned( func, obj ) {}



/@
"Name: on_actor_damage(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when an actor takes damage"
"MandatoryArg: <func> the function you want to call when an actor takes damage."
"Example: callback::on_actor_damage(&on_actor_damage);"
@/
function on_actor_damage( func, obj ) {}


/@
"Name: remove_on_actor_damage(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a actor gets damaged"
"MandatoryArg: <func> the function you want to remove when a actor recieves damage."
"Example: callback::remove_on_actor_damage(&on_actor_killed);"
@/
function remove_on_actor_damage( func, obj ) {}



/@
"Name: on_vehicle_damage(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when an vehicle takes damage"
"MandatoryArg: <func> the function you want to call when an vehicle takes damage."
"Example: callback::on_vehicle_damage(&on_vehicle_damage);"
"SPMP: singleplayer"
@/
function on_vehicle_damage( func, obj ) {}


/@
"Name: remove_on_vehicle_damage(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a vehicle gets damaged"
"MandatoryArg: <func> the function you want to remove when a vehicle recieves damage."
"Example: callback::remove_on_vehicle_damage(&on_vehicle_killed);"
@/
function remove_on_vehicle_damage( func, obj ) {}


/@
"Name: on_laststand(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player goes into last stand"
"MandatoryArg: <func> the function you want to call when a player goes into last stand."
"Example: callback::on_laststand(&on_last_stand);"
"SPMP: singleplayer"
@/
function on_laststand( func, obj ) {}


/@
"Name: on_challenge_complete(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a challenge is completed"
"MandatoryArg: <func> the function you want to call when a player completes a challenge."
"Example: callback::on_challenge_complete(&on_challenge_complete);"
"SPMP: singleplayer"
@/
function on_challenge_complete( func, obj ) {}


