// matches the enum in bot.h
#define	PRIORITY_LOW		1
#define	PRIORITY_NORMAL		2
#define	PRIORITY_HIGH		3
#define	PRIORITY_URGENT		4

#define BOT_BUTTON_FRAG		1
#define BOT_BUTTON_FLASH	2

#define SERVER_FRAMES_PER_SEC	20

#define BOT_DEFAULT_GOAL_RADIUS	24
#define BOT_PREDICTION_FRAMES	4

#define BOT_FOV_EASY		0.4226		// 65 degrees
#define BOT_FOV_MEDIUM		0.0872		// 85 degrees
#define BOT_FOV_HARD		-0.1736		// 100 degrees
#define BOT_FOV_FU			-0.9396		// 160 degrees

#define BOT_CAN_SEE_NOTHING	( 0 )
#define BOT_CAN_SEE_HEAD	( 1 << 0 )
#define BOT_CAN_SEE_TORSO	( 1 << 1 )
#define BOT_CAN_SEE_FEET	( 1 << 2 )

#define BOT_THINK_INTERVAL_SECS_EASY	0.5
#define BOT_THINK_INTERVAL_SECS_MEDIUM	0.25
#define BOT_THINK_INTERVAL_SECS_HARD	0.2
#define BOT_THINK_INTERVAL_SECS_FU		0.1

#define BOT_ADS_DOT_EASY				0.9
#define BOT_ADS_DOT_MEDIUM				0.96
#define BOT_ADS_DOT_HARD				0.97
#define BOT_ADS_DOT_FU					0.98

#define BOT_AIM_CONVERGE_SECS_EASY		3.5
#define BOT_AIM_CONVERGE_SECS_MEDIUM	2
#define BOT_AIM_CONVERGE_SECS_HARD		1.5
#define BOT_AIM_CONVERGE_SECS_FU		0.1

#define BOT_AIM_CONVERGE_RATE_EASY		2
#define BOT_AIM_CONVERGE_RATE_MEDIUM	4
#define BOT_AIM_CONVERGE_RATE_HARD		5
#define BOT_AIM_CONVERGE_RATE_FU		7

#define BOT_AIM_ERROR_DIST_EASY		30
#define BOT_AIM_ERROR_DIST_MEDIUM	20
#define BOT_AIM_ERROR_DIST_HARD		15
#define BOT_AIM_ERROR_DIST_FU		2

#define BOT_SNIPER_FIRE_DELAY_EASY		2
#define BOT_SNIPER_FIRE_DELAY_MEDIUM	0.9
#define BOT_SNIPER_FIRE_DELAY_HARD		0.65
#define BOT_SNIPER_FIRE_DELAY_FU		0.5

#define BOT_MELEE_RANGE_SQ_EASY		40 * 40
#define BOT_MELEE_RANGE_SQ_MEDIUM	70 * 70
#define BOT_MELEE_RANGE_SQ_HARD		70 * 70
#define BOT_MELEE_RANGE_SQ_FU		70 * 70