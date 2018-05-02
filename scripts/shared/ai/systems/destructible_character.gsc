#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\array_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\destructible_character.gsh;

#namespace DestructServerUtils;

function CopyDestructState( originalEntity, newEntity ) {}
function ShowDestructedPieces( entity ) {}
function ReapplyDestructedPieces( entity ) {}
function DestructLeftArmPieces( entity ) {}
function DestructLeftLegPieces( entity ) {}
function DestructRightArmPieces( entity ) {}
function DestructRightLegPieces( entity ) {}
function ToggleSpawnGibs( entity, shouldSpawnGibs ) {}
function HandleDamage(
	eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime, boneIndex, modelIndex ) {}
function DestructNumberRandomPieces( entity, num_pieces_to_destruct=0 ) {}
function GetPieceCount( entity ) {}
function IsDestructed( entity, pieceNumber ) {}
function DestructPiece( entity, pieceNumber ) {}
function DestructRandomPieces( entity) {}