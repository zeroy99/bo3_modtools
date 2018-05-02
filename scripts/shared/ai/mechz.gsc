#using scripts\codescripts\struct;

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\_burnplayer;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\archetype_mocomps_utility;

#using scripts\shared\weapons\_weaponobjects;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\mechz.gsh; 
#insert scripts\shared\ai\utility.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "xmodel", MECHZ_MODEL_ARMOR_KNEE_LEFT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_KNEE_RIGHT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_SHOULDER_LEFT );
#precache( "xmodel", MECHZ_MODEL_ARMOR_SHOULDER_RIGHT );
#precache( "xmodel", MECHZ_MODEL_FACEPLATE );
#precache( "xmodel", MECHZ_MODEL_POWERSUPPLY );
#precache( "xmodel", MECHZ_MODEL_CLAW );

#namespace MechzBehavior;
