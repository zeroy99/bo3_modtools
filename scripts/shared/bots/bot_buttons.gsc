#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace bot;

// From buttonbits.inl
#define BOT_BUTTON_ATTACK		0
#define BOT_BUTTON_SPRINT		1
#define BOT_BUTTON_MELEE		2
#define BOT_BUTTON_ACTIVATE		3
#define BOT_BUTTON_RELOAD		4
#define BOT_BUTTON_CROUCH		9
#define BOT_BUTTON_JUMP			10
#define BOT_BUTTON_WALKING		11
#define BOT_BUTTON_FRAG			14
#define BOT_BUTTON_OFFHAND		15
#define BOT_BUTTON_THROW		24
#define BOT_BUTTON_DOUBLEJUMP	65
#define BOT_BUTTON_SWIM_UP		67
#define BOT_BUTTON_SWIM_DOWN	68
#define BOT_BUTTON_OFFHAND_SPECIAL 70


// Buttons
//========================================
	
function tap_attack_button()
{
	self BotTapButton( BOT_BUTTON_ATTACK );
}

function press_attack_button()
{
	self BotPressButton( BOT_BUTTON_ATTACK );
}

function release_attack_button()
{
	self BotReleaseButton( BOT_BUTTON_ATTACK );
}

function tap_melee_button()
{
	self BotTapButton( BOT_BUTTON_MELEE );
}

function tap_reload_button()
{
	self BotTapButton( BOT_BUTTON_RELOAD );
}

function tap_use_button()
{
	self BotTapButton( BOT_BUTTON_ACTIVATE );
}

function press_crouch_button()
{
	self BotPressButton( BOT_BUTTON_CROUCH );
}

function press_use_button()
{
	self BotPressButton( BOT_BUTTON_ACTIVATE );
}

function release_use_button()
{
	self BotReleaseButton( BOT_BUTTON_ACTIVATE );
}

function press_sprint_button()
{
	self BotPressButton( BOT_BUTTON_SPRINT );
}

function release_sprint_button()
{
	self BotReleaseButton( BOT_BUTTON_SPRINT );
}

function press_frag_button()
{
	self BotPressButton( BOT_BUTTON_FRAG );
}

function release_frag_button()
{
	self BotReleaseButton( BOT_BUTTON_FRAG );
}

function tap_frag_button()
{
	self BotTapButton( BOT_BUTTON_FRAG );
}

function press_offhand_button()
{
	self BotPressButton( BOT_BUTTON_OFFHAND );
}

function release_offhand_button()
{
	self BotReleaseButton( BOT_BUTTON_OFFHAND );
}

function tap_offhand_button()
{
	self BotTapButton( BOT_BUTTON_OFFHAND );
}

function press_throw_button()
{
	self BotPressButton( BOT_BUTTON_THROW );
}

function release_throw_button()
{
	self BotReleaseButton( BOT_BUTTON_THROW );
}

function tap_jump_button()
{
	self BotTapButton( BOT_BUTTON_JUMP );
}

function press_jump_button()
{
	self BotPressButton( BOT_BUTTON_JUMP );
}

function release_jump_button()
{
	self BotReleaseButton( BOT_BUTTON_JUMP );
}

function tap_ads_button()
{
	self BotTapButton( BOT_BUTTON_WALKING );
}

function press_ads_button()
{
	self BotPressButton( BOT_BUTTON_WALKING );
}

function release_ads_button()
{
	self BotReleaseButton( BOT_BUTTON_WALKING );
}

function tap_doublejump_button()
{
	self BotTapButton( BOT_BUTTON_DOUBLEJUMP );
}

function press_doublejump_button()
{
	self BotPressButton( BOT_BUTTON_DOUBLEJUMP );
}

function release_doublejump_button()
{
	self BotReleaseButton( BOT_BUTTON_DOUBLEJUMP );
}

function tap_offhand_special_button()
{
	self BotTapButton( BOT_BUTTON_OFFHAND_SPECIAL );
}
 
function press_swim_up()
{
	self BotPressButton( BOT_BUTTON_SWIM_UP );
}

function release_swim_up()
{
	self BotReleaseButton( BOT_BUTTON_SWIM_UP );
}
 
function press_swim_down()
{
	self BotPressButton( BOT_BUTTON_SWIM_DOWN );
}

function release_swim_down()
{
	self BotReleaseButton( BOT_BUTTON_SWIM_DOWN );
}