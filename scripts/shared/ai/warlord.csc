#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\warlord.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#namespace WarlordClientUtils;

function warlordDamageStateHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump ) {}

function warlordTypeHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump ) {}

function warlordThrusterHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump ) {}

function warlordLightsHandler( localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump ) {}

// end of #namespace WarlordClientUtils
