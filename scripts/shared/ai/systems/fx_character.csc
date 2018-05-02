#using scripts\codescripts\struct;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\gib;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\destructible_character.gsh;
#insert scripts\shared\ai\systems\fx_character.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#namespace FxClientUtils;

function PlayFxBundle( localClientNum, entity, fxScriptBundle ) {}
function StopAllFXBundles( localClientNum, entity ) {}