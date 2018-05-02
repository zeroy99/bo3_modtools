#namespace gameobjects;


function register_allowed_gameobject( gameobject ) {}

function clear_allowed_gameobjects() {}


/*
=============
create_carry_object

Creates and returns a carry object
=============
*/
function create_carry_object( ownerTeam, trigger, visuals, offset, objectiveName, hitSound ) {}

function ghost_visuals() {}


/*
=============
return_home

Resets a carryObject to it's default home position
=============
*/
function return_home() {}


/*
=============
is_object_away_from_home
=============
*/
function is_object_away_from_home() {}


/*
=============
set_position

set a carryObject to a new position
=============
*/
function set_position( origin, angles ) {}

function set_drop_offset( height ) {}

/*
=============
set_dropped

Sets this carry object as dropped and calculates dropped position
=============
*/
function set_dropped() {}

function update_icons_and_objective() {}

/*
=============
get_carrier

Returns the carrier entity for this gameobject
=============
*/

function get_carrier() {}


function clear_carrier() {}


function should_be_reset( minZ, maxZ, testHurtTriggers ) {}


function pickup_timeout( minZ, maxZ ) {}


function take_carry_weapon( weapon ) {}


/*
=============
create_use_object

Creates and returns a use object
In FFA gametypes, ownerTeam should be the player who owns the object
=============
*/
function create_use_object( ownerTeam, trigger, visuals, offset, objectiveName, allowInitialHoldDelay = false, allowWeaponCyclingDuringHold = false ) {}


/*
=============
set_key_object

function Sets this use object to require carry object(s)
=============
*/
function set_key_object( object ) {}

/*
=============
function set_claim_team ("proximity" only)

Sets this object as claimed by specified team including grace period to prevent 
object reset when claiming team leave trigger for short periods of time
=============
*/
function set_claim_team( newTeam ) {}

function get_num_touching_except_team( ignoreTeam ) {}

function update_objective() {}

function update_world_icons() {}

function update_world_icon( relativeTeam, showIcon ) {}

function update_compass_icons() {}

function set_owner_team( team ) {}

function get_owner_team() {}

function set_use_time( time ) {}

function set_use_text( text ) {}

function set_team_use_time( relativeTeam, time ) {}

function set_team_use_text( relativeTeam, text ) {}

function set_use_hint_text( text ) {}

function allow_carry( relativeTeam ) {}

function allow_use( relativeTeam ) {}

function set_visible_team( relativeTeam ) {}

function set_model_visibility( visibility ) {}

function set_2d_icon( relativeTeam, shader ) {}

function set_3d_icon( relativeTeam, shader ) {}

function set_objective_entity( entity ) {} 

function set_carry_icon( shader ) {}

function destroy_object( deleteTrigger, forceHide, b_connect_paths = false ) {}

function disable_object( forceHide ) {}

function enable_object( forceShow ) {}

function is_friendly_team( team ) {}

function can_interact_with( player ) {}

function get_label() {}

function must_maintain_claim( enabled ) {}

function can_contest_claim( enabled ) {}

function set_flags( flags ) {}

function get_flags( flags ) {}
