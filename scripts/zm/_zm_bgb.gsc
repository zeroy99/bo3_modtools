
#namespace bgb;

function is_enabled( name ) {}
function actor_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType ) {}
function actor_death_override( attacker ) {}
function suspend_weapon_cycling() {}
function resume_weapon_cycling() {}
function is_active( name ) {}
function register_lost_perk_override( name, lost_perk_override_func, lost_perk_override_func_always_run ) {}
function lost_perk_override( perk ) {}
function is_team_active( str_name ) {}
function is_team_enabled( str_name ) {}
function add_to_player_score_override( n_points, str_awarded_by ) {}
function do_one_shot_use( skip_demo_bookmark = false ) {}
function give( name ) {}

