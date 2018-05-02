#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreaks;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\weapons\_hive_gun.gsh;

#namespace killstreak_bundles;

function register_killstreak_bundle( killstreakType )
{
	level.killstreakBundle[killstreakType] = struct::get_script_bundle( "killstreak",  "killstreak_" + killstreakType );
	level.killstreakBundle["inventory_" + killstreakType] = level.killstreakBundle[killstreakType];
	level.killstreakMaxHealthFunction = &killstreak_bundles::get_max_health;
	assert( isdefined( level.killstreakBundle[killstreakType] ) );
}

function get_bundle( killstreak )
{
	if( killstreak.archetype === "raps" )
		return level.killstreakBundle[RAPS_DRONE_NAME];
	else
		return level.killstreakBundle[killstreak.killstreakType];
}

function get_hack_timeout()
{
	killstreak = self;
	bundle = get_bundle( killstreak );
	
	return bundle.ksHackTimeout;
}

function get_hack_protection()
{
	killstreak = self;
	hackedProtection = false;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackProtection ) )
	{
		hackedProtection = bundle.ksHackProtection;
	}
	
	return hackedProtection;
}

function get_hack_tool_inner_time()
{
	killstreak = self;
	hackToolInnerTime = 10000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolInnerTime ) )
	{
		hackToolInnerTime = bundle.ksHackToolInnerTime;
	}
	
	return hackToolInnerTime;
}

function get_hack_tool_outer_time()
{
	killstreak = self;
	hackToolOuterTime = 10000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolOuterTime ) )
	{
		hackToolOuterTime = bundle.ksHackToolOuterTime;
	}
	
	return hackToolOuterTime;
}

function get_hack_tool_inner_radius()
{
	killstreak = self;
	hackedToolInnerRadius = 10000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolInnerRadius ) )
	{
		hackedToolInnerRadius = bundle.ksHackToolInnerRadius;
	}
	
	return hackedToolInnerRadius;
}


function get_hack_tool_outer_radius()
{
	killstreak = self;
	hackedToolOuterRadius = 10000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolOuterRadius ) )
	{
		hackedToolOuterRadius = bundle.ksHackToolOuterRadius;
	}
	
	return hackedToolOuterRadius;
}


function get_lost_line_of_sight_limit_msec()
{
	killstreak = self;
	hackedToolLostLineOfSightLimitMs = 1000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolLostLineOfSightLimitMs ) )
	{
		hackedToolLostLineOfSightLimitMs = bundle.ksHackToolLostLineOfSightLimitMs;
	}
	
	return hackedToolLostLineOfSightLimitMs;
}


function get_hack_tool_no_line_of_sight_time()
{
	killstreak = self;
	hackToolNoLineOfSightTime = 1000;

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackToolNoLineOfSightTime ) )
	{
		hackToolNoLineOfSightTime = bundle.ksHackToolNoLineOfSightTime;
	}
	
	return hackToolNoLineOfSightTime;
}



function get_hack_scoreevent()
{
	killstreak = self;
	hackedScoreEvent = undefined; 
	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackScoreEvent ) )
	{
		hackedScoreEvent = bundle.ksHackScoreEvent;
	}
	
	return hackedScoreEvent;	
}

function get_hack_fx()
{
	killstreak = self;
	hackFX = "";

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackFX ) )
	{
		hackFX = bundle.ksHackFX;
	}
	
	return hackFX;	
}

function get_hack_loop_fx()
{
	killstreak = self;
	hackLoopFX = "";

	bundle = get_bundle( killstreak );
	if ( isdefined( bundle.ksHackLoopFX ) )
	{
		hackLoopFX = bundle.ksHackLoopFX;
	}
	
	return hackLoopFX;	
} 

function get_max_health( killstreakType )
{
	bundle = level.killstreakBundle[killstreakType];
	
	return bundle.ksHealth;
}

function get_low_health( killstreakType )
{
	bundle = level.killstreakBundle[killstreakType];
	
	return bundle.ksLowHealth;
}

function get_hacked_health( killstreakType )
{
	bundle = level.killstreakBundle[killstreakType];
	
	return bundle.ksHackedHealth;
}

function get_shots_to_kill( weapon, meansOfDeath, bundle )
{
	shotsToKill = undefined;
	
	switch( weapon.rootweapon.name )
	{
		case "remote_missile_missile":
			shotsToKill = bundle.ksRemote_missile_missile;
			break;
		case "hero_annihilator":
			shotsToKill = bundle.ksHero_annihilator;
			break;
		case "hero_armblade":
			shotsToKill = bundle.ksHero_armblade;
			break;
		case "hero_bowlauncher":
		case "hero_bowlauncher2":
		case "hero_bowlauncher3":
		case "hero_bowlauncher4":
			if ( meansOfDeath == "MOD_PROJECTILE_SPLASH" || meansOfDeath == "MOD_PROJECTILE" )
			{
				shotsToKill = bundle.ksHero_bowlauncher;
			}
			else
			{
				shotstoKill = -1;
			}
			break;
		case "hero_gravityspikes":
			shotsToKill = bundle.ksHero_gravityspikes;
			break;
		case "hero_lightninggun":
			shotsToKill = bundle.ksHero_lightninggun;
			break;
		case "hero_minigun":
		case "hero_minigun_body3":
			shotsToKill = bundle.ksHero_minigun;
			break;
		case "hero_pineapplegun":
			shotsToKill = bundle.ksHero_pineapplegun;
			break;
		case "hero_firefly_swarm":
			shotsToKill = VAL( bundle.ksHero_firefly_swarm, 0 ) * HIVE_POD_HITS_VS_KILLSTREAKS_AND_ROBOTS;
			break;
		case "dart_blade":
		case "dart_turret":
			shotsToKill = bundle.ksDartsToKill;
			break;			
		case "gadget_heat_wave":
			shotsToKill = bundle.ksHero_heatwave;
			break;
	}
	
	return VAL( shotsToKill, 0 );
}

function get_emp_grenade_damage( killstreakType, maxhealth )
{
	// weapon_damage returns as undefined if it is not handled here

	emp_weapon_damage = undefined;

	if ( isdefined( level.killstreakBundle[killstreakType] ) )
    {
		bundle = level.killstreakBundle[killstreakType];
		
		empGrenadesToKill = VAL( bundle.ksEmpGrenadesToKill, 0 );
		
		if ( empGrenadesToKill == 0 )
		{
			// not handled here
		}
		else if ( empGrenadesToKill > 0 )
		{
			emp_weapon_damage = maxhealth / empGrenadesToKill + 1;
		}
		else
		{
			// immune
			emp_weapon_damage = 0;
		}
	}
	
	return emp_weapon_damage;
}

function get_weapon_damage( killstreakType, maxhealth, attacker, weapon, type, damage, flags, chargeShotLevel )
{
	// weapon_damage returns as undefined if it is not handled here

	weapon_damage = undefined;

	if ( isdefined( level.killstreakBundle[killstreakType] ) )
    {
		bundle = level.killstreakBundle[killstreakType];
		
		if ( isdefined( weapon ) )
		{
			shotsToKill = get_shots_to_kill( weapon, type, bundle );
			
			if ( shotsToKill == 0 )
			{
				// not handled here
			}
			else if ( shotsToKill > 0 )
			{
				if ( isdefined( chargeShotLevel ) && chargeShotLevel > 0 )
				{
					// chargeShotLevel should be between 0 and 1.
					// 1 = full charge
					// > 0 = fraction of charge
					shotsToKill = shotsToKill / chargeShotLevel;
				}
				
				weapon_damage = maxhealth / shotsToKill + 1;
			}
			else
			{
				// immune
				weapon_damage = 0;
			}
			
		}		
		
		if ( !isdefined( weapon_damage ) )
		{
			if ( type == "MOD_RIFLE_BULLET" || type == "MOD_PISTOL_BULLET" || type == "MOD_HEAD_SHOT" )
			{
				hasArmorPiercing =  isdefined( attacker ) && isPlayer( attacker ) && attacker HasPerk( "specialty_armorpiercing" );
				
				clipsToKill = VAL( bundle.ksClipsToKill,  0 );
				if( clipsToKill == -1 )
				{
					// immune
					weapon_damage = 0;
				}
				else if ( hasArmorPiercing && self.aitype !== "spawner_bo3_robot_grunt_assault_mp_escort" )	// HACK TU4 FFOTD DT 150126 - Don't apply FMJ damage to the escort robot
				{
					weapon_damage = damage + int( damage * level.cac_armorpiercing_data);
				}
				
				if ( weapon.weapClass == "spread" )
				{
					ksShotgunMultiplier = VAL( bundle.ksShotgunMultiplier, 1);
					
					if ( ksShotgunMultiplier == 0 )
					{
						// not handled here
					}
					else if ( ksShotgunMultiplier > 0 )
					{
						weapon_damage = VAL( weapon_damage, damage ) * ksShotgunMultiplier;
					}
				}
			}
			else if ( ( type == "MOD_PROJECTILE" || type == "MOD_EXPLOSIVE" )
			         && ( !isdefined( weapon.isEmpKillstreak ) || !weapon.isEmpKillstreak )
			         && ( weapon.statIndex != level.weaponPistolEnergy.statIndex )
			         && ( weapon.statIndex != level.weaponSpecialCrossbow.statIndex )
			         && ( weapon.statIndex != level.weaponSmgNailGun.statIndex )
			         && ( weapon.statIndex != level.weaponBouncingBetty.statIndex ) )
			{
				if (  weapon.statIndex == level.weaponShotgunEnergy.statIndex )
				{
					shotgunEnergyToKill = VAL( bundle.ksShotgunEnergyToKill, 0 );
					
					if ( shotgunEnergyToKill == 0 )
					{
						// not handled here
					}
					else if ( shotgunEnergyToKill > 0 )
					{
						weapon_damage = maxhealth / shotgunEnergyToKill + 1;
					}
					else
					{
						// immune
						weapon_damage = 0;
					}
				}
				else
				{		
					rocketsToKill = VAL( bundle.ksRocketsToKill, 0 );
					
					if ( rocketsToKill == 0 )
					{
						// not handled here
					}
					else if ( rocketsToKill > 0 )
					{
						if ( weapon.rootweapon.name == "launcher_multi" )
						{
							rocketsToKill *= 2;
						}
	
						weapon_damage = maxhealth / rocketsToKill + 1;
					}
					else
					{
						// immune
						weapon_damage = 0;
					}
				}
			}
			else if (( type == "MOD_GRENADE" || type == "MOD_GRENADE_SPLASH" ) && ( !isdefined( weapon.isEmpKillstreak ) || !weapon.isEmpKillstreak ) )
			{
				grenadeDamageMultiplier = VAL( bundle.ksGrenadeDamageMultiplier, 0 );
				
				if ( grenadeDamageMultiplier == 0 )
				{
					// not handled here
				}
				else if ( grenadeDamageMultiplier > 0 )
				{
					weapon_damage = damage * grenadeDamageMultiplier;
				}
				else
				{
					// immune
					weapon_damage = 0;
				}
			}
			else if ( type == "MOD_MELEE_WEAPON_BUTT" || type == "MOD_MELEE" )
			{
				ksMeleeDamageMultiplier = VAL( bundle.ksMeleeDamageMultiplier, 0 );
				
				if ( ksMeleeDamageMultiplier == 0 )
				{
					// not handled here
				}
				else if ( ksMeleeDamageMultiplier > 0 )
				{
					weapon_damage = damage * ksMeleeDamageMultiplier;
				}
				else
				{
					// immune
					weapon_damage = 0;
				}
			}
			else if ( type == "MOD_PROJECTILE_SPLASH" )
			{
				ksProjectileSpashMultiplier = VAL( bundle.ksProjectileSpashMultiplier, 0 );
				
				if ( ksProjectileSpashMultiplier == 0 )
				{
					// not handled here
				}
				else if ( ksProjectileSpashMultiplier > 0 )
				{
					weapon_damage = damage * ksProjectileSpashMultiplier;
				}
				else
				{
					// immune
					weapon_damage = 0;
				}
			}
		}
    }

	return weapon_damage;
}