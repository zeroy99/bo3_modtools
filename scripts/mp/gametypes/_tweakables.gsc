#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#namespace tweakables;

REGISTER_SYSTEM( "tweakables", &__init__, undefined )

function __init__() {}
function getTweakableDVarValue( category, name ) {}
function getTweakableDVar( category, name ) {}
function getTweakableValue( category, name ) {}
function getTweakableLastValue( category, name ) {}
function setTweakableValue( category, name, value ) {}
function setTweakableLastValue( category, name, value ) {}
function registerTweakable( category, name, dvar, value ) {}
function setClientTweakable( category, name ) {}
function updateUITweakables() {}
function updateServerDvar( dvar, value ) {}
