
#namespace util;

/#
function error(msg) {}
#/

function warning( msg ) {}

/@
"Name: within_fov( <start_origin> , <start_angles> , <end_origin> , <fov> )"
"Summary: Returns true if < end_origin > is within the players field of view, otherwise returns false."
"Module: Vector"
"CallOn: "
"MandatoryArg: <start_origin> : starting origin for FOV check( usually the players origin )"
"MandatoryArg: <start_angles> : angles to specify facing direction( usually the players angles )"
"MandatoryArg: <end_origin> : origin to check if it's in the FOV"
"MandatoryArg: <fov> : cosine of the FOV angle to use"
"Example: qBool = within_fov( level.player.origin, level.player.angles, target1.origin, cos( 45 ) );"
"SPMP: multiplayer"
@/ 
function within_fov( start_origin, start_angles, end_origin, fov ) {}

function get_player_height() {}


function IsBulletImpactMOD( sMeansOfDeath ) {}

function waitRespawnButton() {}

function setLowerMessage( text, time, combineMessageAndTimer ) {}

function setLowerMessageValue( text, value, combineMessage ) {}

function clearLowerMessage( fadetime ) {}

function printOnTeam(text, team) {}

function printBoldOnTeam(text, team) {}

function printBoldOnTeamArg(text, team, arg) {}

function printOnPlayers( text, team ) {}

function printAndSoundOnEveryone( team, enemyteam, printFriendly, printEnemy, soundFriendly, soundEnemy, printarg ) {}

function getOtherTeam( team ) {}

function getTeamMask( team ) {}

function getOtherTeamsMask( skip_team ) {}

function wait_endon( waitTime, endOnString, endonString2, endonString3, endonString4 ) {}

function set_dvar_if_unset( dvar, value, reset) {}

function set_dvar_float_if_unset( dvar, value, reset) {}

function set_dvar_int_if_unset( dvar, value, reset) {}

function isStrStart( string1, subStr ) {}

function isKillStreaksEnabled() {}

function setUsingRemote( remoteName, set_killstreak_delay_killcam = true ) {}

function setObjectiveText( team, text ) {}

function setObjectiveScoreText( team, text ) {}

function setObjectiveHintText( team, text ) {}

function getObjectiveText( team ) {}

function getObjectiveScoreText( team ) {}

function getObjectiveHintText( team ) {}

function registerRoundSwitch( minValue, maxValue ) {}

function registerRoundLimit( minValue, maxValue ) {}

function registerRoundWinLimit( minValue, maxValue ) {}

function registerScoreLimit( minValue, maxValue ) {}

function registerRoundScoreLimit( minValue, maxValue ) {}

function registerTimeLimit( minValue, maxValue ) {}

function registerNumLives( minValue, maxValue ) {}

function getPlayerFromClientNum( clientNum ) {}

function isFlashbanged() {}

function DoMaxDamage( origin, attacker, inflictor, headshot, mod )  {} // self == entity to damage

/@
"Name: self_delete()"
"Summary: Just calls the delete() script command on self. Reason for this is so that we can use array::thread_all to delete entities"
"Module: Entity"
"CallOn: An entity"
"Example: ai[ 0 ] thread self_delete();"
"SPMP: singleplayer"
@/
function self_delete() {}


/@
"Name: screen_message_create(<string_message>)"
"Summary: Creates a HUD element at the correct position with the string or string reference passed in."
"Module: Utility"
"CallOn: N/A"
"MandatoryArg: <string_message_1> : A string or string reference to place on the screen."
"OptionalArg: <string_message_2> : A second string to display below the first."
"OptionalArg: <string_message_3> : A third string to display below the second."
"OptionalArg: <n_offset_y>: Optional offset in y direction that should only be used in very specific circumstances."
"OptionalArg: <n_time> : Length of time to display the message."
"Example: screen_message_create( &"LEVEL_STRING" );"
"SPMP: singleplayer"
@/
function screen_message_create( string_message_1, string_message_2, string_message_3, n_offset_y, n_time ) {}

/@
"Name: screen_message_delete()"
"Summary: Deletes the current message being displayed on the screen made using screen_message_create."
"Module: Utility"
"CallOn: N/A"
"Example: screen_message_delete();"
"SPMP: singleplayer"
@/
function screen_message_delete( delay ) {}

/@
"Name: ghost_wait_show()"
"Summary: ghosts an entity, waits, then shows the entity; mainly used to hide pops when setting up models poses via setanim"
"Module: Utility"
"CallOn: An entity"
"OptionalArg: <wait_time> : how long to wait before showing"
"Example: turret thread ghost_wait_show();"
"SPMP: multiplayer"
@/
function ghost_wait_show( wait_time = 0.1 ) {}

/@
"Name: ghost_wait_show_to_player()"
"Summary: ghosts an entity, waits, then shows the entity to a player; mainly used to hide pops when setting up models poses via setanim"
"Module: Utility"
"CallOn: An entity"
"MandatoryArg: <player> : the player to whom to show this entity"
"OptionalArg: <wait_time> : how long to wait before showing to the player"
"OptionalArg: <self_endon_string1> : sets up a self endon with this string"
"Example: turret thread ghost_wait_show_to_player( player );"
"SPMP: multiplayer"
@/
function ghost_wait_show_to_player( player, wait_time = 0.1, self_endon_string1 ) {}

/@
"Name: ghost_wait_show_to_others()"
"Summary: ghosts an entity, waits, then shows the entity to other players; mainly used to hide pops when setting up models poses via setanim"
"Module: Utility"
"CallOn: An entity"
"MandatoryArg: <player> : the player from whom to hide this entity"
"OptionalArg: <wait_time> : how long to wait before showing to others"
"OptionalArg: <self_endon_string1> : sets up a self endon with this string"
"Example: turret thread ghost_wait_show_to_others( player );"
"SPMP: multiplayer"
@/
function ghost_wait_show_to_others( player, wait_time = 0.1, self_endon_string1 ) {}

// button pressed wrappers
function use_button_pressed() {}


/@
"Name: waittill_use_button_pressed()"
"Summary: Waits until the player is pressing their use button."
"Module: Player"
"Example: level.player waittill_use_button_pressed()"
"SPMP: SP"
@/
function waittill_use_button_pressed() {}

/@
"Name: show_hint_text"
"Summary: Displays hint text for an amount of time. Can be turned off by sending a notify, or by calling hide_hint_text()."
"MandatoryArg: <str_text_to_show> : The text to display."
"OptionalArg: <b_should_blink> : Should this menu flash on and off?"
"OptionalArg: <str_turn_off_notify> : The use this notify to turn off the hint text."
"OptionalArg: <n_display_time> : Override how many seconds the text is displayed for."	
"Example: show_hint_text( "Your help text here!", "notify_hide_help_text" );"
@/
function show_hint_text(str_text_to_show, b_should_blink=false, str_turn_off_notify=HINT_TEXT_TURN_OFF_NOTIFY, n_display_time=HINT_TEXT_DISPLAY_TIME_DEFAULT) {}

/@
"Name: hide_hint_text"
"Summary: Hides any help text which may be on screen."
@/
function hide_hint_text(b_fade_before_hiding=true) {}

// Fade out hint text before its luimenu is destroyed.
// If a notify to hide hint text is passed, this will fade out the hint text as well.
function fade_hint_text_after_time(n_display_time, str_turn_off_notify) {}

// Listens for a notify to turn off the help text.
function hide_hint_text_listener(n_time) {}

function set_team_radar( team, value ) {}
