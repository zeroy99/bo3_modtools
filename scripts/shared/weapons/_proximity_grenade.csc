#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\postfx_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define TASER_MINE_ZAP_COUNT			   3
#define TASER_MINE_ZAP_CYCLE_COUNT	 2
#define TASER_MINE_ZAP_PERIOD_SECONDS	0.25
	
#define PROXIMITY_GRENADE_DAMAGE_RADIUS_SQ 40000 // 200 * 200
#define PROXIMITY_GRENADE_POSTFX	"pstfx_shock_charge"
	
#precache( "client_fx", "weapon/fx_prox_grenade_scan_blue" );
#precache( "client_fx", "weapon/fx_prox_grenade_wrn_grn" );
#precache( "client_fx", "weapon/fx_prox_grenade_scan_orng" );
#precache( "client_fx", "weapon/fx_prox_grenade_wrn_red" );
#precache( "client_fx", "weapon/fx_prox_grenade_impact_player_spwner" );
	
#namespace proximity_grenade;

function init_shared()
{	
	clientfield::register( "toplayer", "tazered", VERSION_SHIP, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	level._effect["prox_grenade_friendly_default"] = "weapon/fx_prox_grenade_scan_blue";
	level._effect["prox_grenade_friendly_warning"] = "weapon/fx_prox_grenade_wrn_grn";

	level._effect["prox_grenade_enemy_default"] = "weapon/fx_prox_grenade_scan_orng";
	level._effect["prox_grenade_enemy_warning"] = "weapon/fx_prox_grenade_wrn_red";

	level._effect["prox_grenade_player_shock"] = "weapon/fx_prox_grenade_impact_player_spwner";
	
	callback::add_weapon_type( "proximity_grenade", &proximity_spawned );
	
	level thread watchForProximityExplosion();
}

function proximity_spawned( localClientNum )
{	
	if ( self isGrenadeDud() ) 
		return; 

	self.equipmentFriendFX = level._effect["prox_grenade_friendly_default"];
	self.equipmentEnemyFX = level._effect["prox_grenade_enemy_default"];
	self.equipmentTagFX = "tag_fx";
	
	self thread weaponobjects::equipmentTeamObject( localClientNum );
}

function watchForProximityExplosion()
{
	if ( GetActiveLocalClients() > 1 )
		return;

	weapon_proximity = GetWeapon( "proximity_grenade" );

	while ( true )
	{
		level waittill( "explode", localClientNum, position, mod, weapon, owner_cent );
		
		if ( weapon.rootWeapon != weapon_proximity )
		{
			continue;
		}
		
		localPlayer = GetLocalPlayer( localClientNum );

		if ( ( !localPlayer util::is_player_view_linked_to_entity( localClientNum ) ) )
		{
			
			explosionRadius = weapon.explosionRadius;
				
			if ( DistanceSquared( localPlayer.origin, position ) < explosionRadius * explosionRadius )
			{
				if ( isdefined( owner_cent ) )
				{
					if ( ( owner_cent == localPlayer ) || !( owner_cent util::friend_not_foe( localClientNum, true ) ) )
					{
						//localPlayer thread taserHUDFX( localClientNum, position );
						localPlayer thread postfx::PlayPostfxBundle( PROXIMITY_GRENADE_POSTFX );
					}
				}
			}
			
		}
	}
}
