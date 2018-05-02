#using scripts\shared\array_shared;
#using scripts\shared\colors_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\init;
#using scripts\shared\ai\archetype_utility;
#namespace ai_puppeteer;

REGISTER_SYSTEM( "ai_puppeteer", &__init__, undefined )

function __init__()
{
}

