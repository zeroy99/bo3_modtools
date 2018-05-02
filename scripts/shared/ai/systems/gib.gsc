#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\throttle_shared;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#namespace GibServerUtils;

function Annihilate( entity ) {}
function CopyGibState( originalEntity, newEntity )  {}
function IsGibbed( entity, gibFlag ) {}
function GibHat( entity ) {}
function GibHead( entity ) {}
function GibLeftArm( entity ) {}
function GibRightArm( entity ) {}
function GibLeftLeg( entity ) {}
function GibRightLeg( entity ) {}
function GibLegs( entity ) {}
function PlayerGibLeftArm( entity ) {}
function PlayerGibRightArm( entity ) {}
function PlayerGibLeftLeg( entity ) {}
function PlayerGibRightLeg( entity ) {}
function PlayerGibLegs( entity ) {}
function PlayerGibLeftArmVel( entity, dir ) {}
function PlayerGibRightArmVel( entity, dir ) {}
function PlayerGibLeftLegVel( entity, dir ) {}
function PlayerGibRightLegVel( entity, dir ) {}
function PlayerGibLegsVel( entity, dir ) {}
function ReapplyHiddenGibPieces( entity ) {}
function ShowHiddenGibPieces( entity ) {}
function ToggleSpawnGibs( entity, shouldSpawnGibs ) {}
