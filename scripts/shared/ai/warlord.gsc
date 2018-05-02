#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\gameobjects_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;

#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\archetype_mocomps_utility;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\archetype_warlord_interface;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\ai\warlord.gsh;

#namespace WarlordBehavior;

function autoexec RegisterBehaviorScriptFunctions() {}
function private ArchetypeWarlordBlackboardInit() {}
function private ArchetypeWarlordOnAnimscriptedCallback( entity )  {}
function private shouldHuntEnemyPlayer( entity ) {}
function private _warlordHuntEnemy( entity ) {}
function chooseBetterPositionService( entity ) {}
function canJukeCondition( behaviorTreeEntity )  {}
function canTacticalJukeCondition( behaviorTreeEntity ) {}
function warlordShouldNormalMelee( behaviorTreeEntity) {}
function canTakePainCondition( behaviorTreeEntity ) {}
function jukeAction( behaviorTreeEntity, asmStateName ) {}
function jukeActionTerminate( behaviorTreeEntity, asmStateName ) {}
function deathAction( behaviorTreeEntity, asmStateName ) {}
function exposedPainActionStart( behaviorTreeEntity ) {}
function shouldBeAngryCondition( behaviorTreeEntity ) {}
function WarlordAngryAttack( entity ) {}
function WarlordAngryAttack_ShootThemAll( entity, attackersArray ) {}

#namespace WarlordServerUtils;

function GetAlivePlayersCount(entity) {}
function SetWarlordAggressiveMode( entity, b_aggressive_mode ) {}
function AddPreferedPoint(entity, position, min_duration, max_duration, name) {}
function DeletePreferedPoint( entity, name ) {}
function ClearAllPreferedPoints(entity) {}
function ClearPreferedPointsOutsideGoal(entity) {}
function private SetPreferedPoint( entity, point) {}
function private ClearPreferedPoint( entity) {}
function private AtPreferedPoint(entity) {}
function private ReachingPreferedPoint(entity) {}
function private UpdatePreferedPoint(entity) {}
function private GetPreferedValidPoints( entity ) {}
function GetScaledForPlayers(val, scale2, scale3, scale4) {}
function warlordCanJuke( entity ) {}
function warlordCanTacticalJuke( entity ) {}
function IsEnemyTooLowToAttack( enemy ) {}
function HaveTooLowToAttackEnemy( entity ) {}
function SetEnemyTooLowToAttack( entity ) {}
function ComputeAttackerThreat( entity, attackerInfo) {}
function ShouldSwitchToNewThreat( entity, attacker, threat) {}
function UpdateAttackersList( entity, newAttacker, damage) {}
function CheckifWeShouldMove( entity ) {}
function WarlordDangerousEnemyAttack( entity, attacker, threat) {}
function warlordDamageOverride( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, vDamageOrigin, timeOffset, boneIndex, modelIndex, surfaceType, surfaceNormal ) {}
function warlordSpawnSetup() {}
function warlord_projectile_watcher() {}
function remove_repulsor() {}
function repulsor_fx() {}
function trigger_player_shock_fx() {}


