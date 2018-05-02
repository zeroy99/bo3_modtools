
#namespace zm_score;

function player_add_points( event, mod, hit_location ,is_dog, zombie_team, damage_weapon ) {}


//
//	Add points to the player's score
//	self is a player
//
function add_to_player_score( points, b_add_to_total = true ) {}

//
//	Subtract points from the player's score
//	self is a player
//
function minus_to_player_score( points ) {}

//check to see if player has enough points to purchase
//self = player
function can_player_purchase( n_cost ) {}
