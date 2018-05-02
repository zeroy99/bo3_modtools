#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace art;

REGISTER_SYSTEM( "art", &__init__, undefined )

// This function should take care of grain and glow settings for each map, plus anything else that artists 
// need to be able to tweak without bothering level designers.

function __init__(){}
function setfogsliders(){}
function tweakart(){}
function fovslidercheck(){}
function dumpsettings(){}
