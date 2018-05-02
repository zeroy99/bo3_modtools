#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#namespace GibClientUtils;

function PlayerGibLeftArm( localClientNum ) {}
function PlayerGibRightArm( localClientNum ) {}
function PlayerGibLeftLeg( localClientNum ) {}
function PlayerGibRightLeg( localClientNum ) {}
function PlayerGibLegs( localClientNum ) {}
function PlayerGibTag( localClientNum, gibFlag ) {}
