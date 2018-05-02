
#namespace zm_utility;

function approximate_path_dist( player ) {}
function is_player_valid( player, checkIgnoreMeFlag, ignore_laststand_players ) {}

function add_sound( ref, alias ) {}
function play_sound_2D(sound) {}
function get_specific_character( n_character_index ) {}

// LETHALS 
// register 
function register_lethal_grenade_for_level( weaponname ) {}
// is this a known tactical grenade
function is_lethal_grenade( weapon ) {}
// is this a the tactical grenade for the player (self) 
function is_player_lethal_grenade( weapon ) {}
// get tactical grenade for self
function get_player_lethal_grenade() {}
// set tactical grenade for self
function set_player_lethal_grenade( weapon ) {}
// init 
function init_player_lethal_grenade() {}

// TACTICALS 
function register_tactical_grenade_for_level( weaponname ) {}
function is_tactical_grenade( weapon ) {}
function is_player_tactical_grenade( weapon ) {}
function get_player_tactical_grenade() {}
function set_player_tactical_grenade( weapon ) {}
function init_player_tactical_grenade() {}

// CLAYMORES/BETTYS
function is_placeable_mine( weapon ) {}
function is_player_placeable_mine( weapon ) {}
function get_player_placeable_mine() {}
function set_player_placeable_mine( weapon ) {}
function init_player_placeable_mine() {}

// MELEE
function register_melee_weapon_for_level( weaponname ) {}
function is_melee_weapon( weapon ) {}
function is_player_melee_weapon( weapon ) {}
function get_player_melee_weapon() {}
function set_player_melee_weapon( weapon ) {}
function init_player_melee_weapon() {}


function give_start_weapon( switch_to_weapon ) {}

function is_magic_bullet_shield_enabled( ent ) {}




