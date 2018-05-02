

#namespace callback;

function callback( event, localclientnum, params ) {}

function add_callback( event, func, obj ) {}

function remove_callback( event, func, obj ) {}

/@
"Name: on_localclient_connect(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when the local client connects"
"MandatoryArg: <func> the function you want to call on the new local client."
"Example: callback::on_localclient_connect(&on_player_connect);"
"SPMP: MP"
@/
function on_localclient_connect( func, obj ) {}

/@
"Name: on_localclient_shutdown(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when the local client connects"
"MandatoryArg: <func> the function you want to call on the new local client."
"Example: callback::on_localclient_connect(&on_player_connect);"
"SPMP: MP"
@/
function on_localclient_shutdown( func, obj ) {}


/@
"Name: on_finalize_initialization(<func>)"
"Module: Callbacks"
"Summary: Set a callback for afer final initialization"
"MandatoryArg: <func> the function you want to call."
"Example: callback::on_finalize_initialization( &foo );"
@/
function on_finalize_initialization( func, obj ) {}


/@
"Name: on_localplayer_spawned(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a local player spawns in the game"
"MandatoryArg: <func> the function you want to call on the local player."
"Example: callback::on_localplayer_spawned( &foo );"
@/
function on_localplayer_spawned( func, obj ) {}


/@
"Name: remove_on_localplayer_spawned(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a local player spawns in the game"
"MandatoryArg: <func> the function you want to call on the local player."
"Example: callback::remove_on_localplayer_spawned( &foo );"
@/
function remove_on_localplayer_spawned( func, obj ) {}



/@
"Name: on_spawned(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player spawns in the game"
"MandatoryArg: <func> the function you want to call on the player."
"Example: callback::on_spawned( &foo );"
@/
function on_spawned( func, obj ) {}



/@
"Name: remove_on_spawned(<func>)"
"Module: Callbacks"
"Summary: Remove a callback for when a player spawns in the game"
"MandatoryArg: <func> the function you want to call on the player."
"Example: callback::remove_on_spawned( &foo );"
@/
function remove_on_spawned( func, obj ) {}


/@
"Name: on_shutdown(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when an entity is shutdown"
"MandatoryArg: <func> the function you want to call on the entity."
"Example: callback::on_shutdown( &foo );"
@/
function on_shutdown( func, obj ) {}


/@
"Name: on_start_gametype(<func>)"
"Module: Callbacks"
"Summary: Set a callback for when a player starts a gametype"
"MandatoryArg: <func> the function you want to call on the player."
"Example: callback::on_start_gametype( &init );"
@/
function on_start_gametype( func, obj ) {}


