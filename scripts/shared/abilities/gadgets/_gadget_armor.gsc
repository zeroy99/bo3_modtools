#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;

#using scripts\shared\abilities\_ability_player;
#using scripts\shared\abilities\_ability_power;
#using scripts\shared\abilities\_ability_util;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\abilities\_ability_util.gsh;

#define ARMOR_PROJECTILE_MULTIPLIER	GetDvarFloat( "scr_armor_mod_proj_mult", 1 )
#define ARMOR_MELEE_MULTIPLIER		GetDvarFloat( "scr_armor_mod_melee_mult", 2 )
#define ARMOR_EXPLOSIVE_MULTIPLIER	GetDvarFloat( "scr_armor_mod_expl_mult", 1 )
#define ARMOR_BULLET_MULTIPLIER		GetDvarFloat( "scr_armor_mod_bullet_mult", .7 )
#define ARMOR_MISC_MULTIPLIER		GetDvarFloat( "scr_armor_mod_misc_mult", 1 )
#define ARMOR_VIEW_KICK_MULTIPLIER	GetDvarFloat( "scr_armor_mod_view_kick_mult", .001 )

#namespace armor;

REGISTER_SYSTEM( "gadget_armor", &__init__, undefined )

function __init__()
{
	ability_player::register_gadget_activation_callbacks( GADGET_TYPE_ARMOR, &gadget_armor_on, &gadget_armor_off );
	ability_player::register_gadget_possession_callbacks( GADGET_TYPE_ARMOR, &gadget_armor_on_give, &gadget_armor_on_take );
	ability_player::register_gadget_flicker_callbacks( GADGET_TYPE_ARMOR, &gadget_armor_on_flicker );
	ability_player::register_gadget_is_inuse_callbacks( GADGET_TYPE_ARMOR, &gadget_armor_is_inuse );
	ability_player::register_gadget_is_flickering_callbacks( GADGET_TYPE_ARMOR, &gadget_armor_is_flickering );
	
	clientfield::register( "allplayers", "armor_status" , VERSION_SHIP, ARMOR_STATUS_FULL, "int" );
	clientfield::register( "toplayer", "player_damage_type" , VERSION_SHIP, 1, "int" );
	
	callback::on_connect( &gadget_armor_on_connect );
}

function gadget_armor_is_inuse( slot )
{
	// returns true when local script gadget state is on
	return self GadgetIsActive( slot );
}

function gadget_armor_is_flickering( slot )
{
	// returns true when local script gadget state is flickering
	return self GadgetFlickering( slot );
}

function gadget_armor_on_flicker( slot, weapon )
{
	// excuted when the gadget flickers
	self thread gadget_armor_flicker( slot, weapon );	
}

function gadget_armor_on_give( slot, weapon )
{
	// executed when gadget is added to the players inventory

	self clientfield::set( "armor_status", ARMOR_STATUS_OFF );
	
	self._gadget_armor_slot = slot;
	self._gadget_armor_weapon = weapon;
}

function gadget_armor_on_take( slot, weapon )
{
	// executed when gadget is removed from the players inventory
	
	self gadget_armor_off( slot, weapon );
}

//self is the player
function gadget_armor_on_connect()
{
	// setup up stuff on player connec
}

function gadget_armor_on( slot, weapon )
{
	if ( IsAlive(self) )
	{
		// excecutes when the gadget is turned on
		self flagsys::set( "gadget_armor_on" );	
		
		//armor section
		self.shock_onpain = 0;	
		
		//set the hitpoints
		self.gadgetHitPoints = ( ( IsDefined( weapon.gadget_max_hitpoints ) && weapon.gadget_max_hitpoints > 0 ) ? weapon.gadget_max_hitpoints : undefined );
		
		if ( isdefined( self.overridePlayerDamage ) )
		{
			self.originalOverridePlayerDamage = self.overridePlayerDamage;
		}
		
		self.overridePlayerDamage = &armor_player_damage;
		self thread gadget_armor_status( slot, weapon );
	}
}

function gadget_armor_off( slot, weapon )
{
	armorOn =  flagsys::get( "gadget_armor_on" );
	
	self notify( "gadget_armor_off" );
	
	// excecutes when the gadget is turned off
	self flagsys::clear( "gadget_armor_on" );
	
	//armor section
	self.shock_onpain = 1; 
	self clientfield::set( "armor_status", ARMOR_STATUS_OFF );
	if ( isdefined( self.originalOverridePlayerDamage ) )
	{
		self.overridePlayerDamage = self.originalOverridePlayerDamage;
		self.originalOverridePlayerDamage = undefined;
	}
	
	if ( armorOn && IsAlive( self ) && isdefined( level.playGadgetSuccess ) )
    {
		self [[ level.playGadgetSuccess ]]( weapon );
	}
}

function gadget_armor_flicker( slot, weapon )
{
	self endon( "disconnect" );	

	if ( !self gadget_armor_is_inuse( slot ) )
	{
		return;
	}

	eventTime = self._gadgets_player[slot].gadget_flickertime;

	self set_gadget_status( "Flickering", eventTime );

	while( 1 )
	{		
		if ( !self GadgetFlickering( slot ) )
		{
			self set_gadget_status( "Normal" );
			return;
		}

		wait( 0.5 );
	}
}

function set_gadget_status( status, time )
{
	timeStr = "";

	if ( IsDefined( time ) )
	{
		timeStr = "^3" + ", time: " + time;
	}
	
	if ( GetDvarInt( "scr_cpower_debug_prints" ) > 0 )
		self IPrintlnBold( "Gadget Armor: " + status + timeStr );
}

function armor_damage_type_multiplier( sMeansOfDeath )
{
    switch(sMeansOfDeath)
    {
        case "MOD_CRUSH":
        case "MOD_TELEFRAG":
        case "MOD_SUICIDE":
        case "MOD_DROWN":
        case "MOD_HIT_BY_OBJECT":
        case "MOD_FALLING":
            return 0; // no protection - damage will fall through to player
            
            
        case "MOD_PROJECTILE":
            return ARMOR_PROJECTILE_MULTIPLIER;
            
        case "MOD_MELEE":
        case "MOD_MELEE_WEAPON_BUTT":
            return ARMOR_MELEE_MULTIPLIER;
            break;
            
        case "MOD_EXPLOSIVE":
        case "MOD_PROJECTILE_SPLASH":
        case "MOD_GRENADE": 
        case "MOD_GRENADE_SPLASH":
            return ARMOR_EXPLOSIVE_MULTIPLIER;
            break;
        
        case "MOD_PISTOL_BULLET":
        case "MOD_RIFLE_BULLET":
            return ARMOR_BULLET_MULTIPLIER;
            break;
            

        case "MOD_BURNED":
        case "MOD_UNKNOWN":
        case "MOD_TRIGGER_HURT":
        default:
            return ARMOR_MISC_MULTIPLIER;
    }
}

function armor_damage_mod_allowed( weapon, sMeansOfDeath )
{
	switch( weapon.name )
	{
		case "hero_lightninggun":
		case "hero_lightninggun_arc":
			return false;
			
		default:
			break;
	}
	
    switch(sMeansOfDeath)
    {
        case "MOD_CRUSH":
        case "MOD_TELEFRAG":
        case "MOD_SUICIDE":
        case "MOD_DROWN":
        case "MOD_HIT_BY_OBJECT":
        case "MOD_FALLING":
        case "MOD_MELEE":
        case "MOD_MELEE_WEAPON_BUTT":
        case "MOD_EXPLOSIVE":
        case "MOD_PROJECTILE_SPLASH":
        case "MOD_GRENADE": 
        case "MOD_GRENADE_SPLASH":
        case "MOD_BURNED":
        case "MOD_UNKNOWN":
        case "MOD_TRIGGER_HURT":
        	return false;
            
        case "MOD_PISTOL_BULLET":
        case "MOD_RIFLE_BULLET":
            return true;
            
        case "MOD_PROJECTILE":
			// if we are using this as a impact damage only projectile then we allow it
            if (weapon.explosionradius == 0 )
            {
            	return true;
            }
            return false;
		default:
            return false;
   
    }
    
    return false;
}

function armor_should_take_damage( eAttacker, weapon, sMeansOfDeath, sHitLoc )
{
	if ( isdefined( eAttacker ) && !weaponobjects::friendlyFireCheck( self, eAttacker ) )
	{
		return false;
	}
	
	if ( !armor_damage_mod_allowed( weapon, sMeansOfDeath ) )
	{
		return false;
	}
	
	if( isDefined( sHitLoc ) && ( sHitLoc == "head" || sHitLoc == "helmet" ) )
	{
		return false;
	}
	
	return true;
}

function armor_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	damage = iDamage;
	self.power_armor_took_damage = false;
	if ( ( self armor_should_take_damage( eAttacker, weapon, sMeansOfDeath, sHitLoc ) ) && isdefined( self._gadget_armor_slot ) )
	{
		self clientfield::set_to_player( "player_damage_type", 1 );
		if ( self gadget_armor_is_inuse( self._gadget_armor_slot ) )
		{			
			armor_damage = damage * armor_damage_type_multiplier( sMeansOfDeath );			
			
			damage = 0;
			
			if ( armor_damage > 0 )
			{
				if( IsDefined( self.gadgetHitPoints ) )
				{
					hitPointsLeft = self.gadgetHitPoints;
				}
				else
				{
					hitPointsLeft = self GadgetPowerChange( self._gadget_armor_slot, 0.0 );
				}
				
				if ( weapon == level.weaponLightningGun || weapon == level.weaponLightningGunArc )
				{
					// lightning gun will take all armor but do no damage
					armor_damage = hitPointsLeft;
				}
				else if ( hitPointsLeft < armor_damage )
				{
					// will apply rest of damage back to player
					damage = armor_damage - hitPointsLeft;
				}
				
				if( IsDefined( self.gadgetHitPoints ) )
				{
					self hitpoints_loss_event( armor_damage );
				}
				else
				{
					self ability_power::power_loss_event( self._gadget_armor_slot, eAttacker, armor_damage, "armor damage" );
				}
				self.power_armor_took_damage = true;
				self.power_armor_last_took_damage_time = GetTime();
				self AddToDamageIndicator( int( armor_damage * ARMOR_VIEW_KICK_MULTIPLIER ), vDir);
			}			
		}
		else
		{
			self clientfield::set_to_player( "player_damage_type", 0 );
		}
	}
	else
	{
		self clientfield::set_to_player( "player_damage_type", 0 );
	}
	
	return damage;
}

function hitpoints_loss_event( val )
{
	if ( val > 0 )
	{
		self.gadgetHitPoints -= val;
	}
}

function gadget_armor_status( slot, weapon )
{
	self endon( "disconnect" );
	
	maxHitPoints = ( ( IsDefined( weapon.gadget_max_hitpoints ) && weapon.gadget_max_hitpoints > 0 ) ? weapon.gadget_max_hitpoints : 100 );
	
	while ( self flagsys::get( "gadget_armor_on" ) )
	{
		if( IsDefined( self.gadgetHitPoints ) && self.gadgetHitPoints <= 0 )
		{
			self playsoundtoplayer( "wpn_power_armor_destroyed_plr", self );
			self playsoundtoallbutplayer( "wpn_power_armor_destroyed_npc", self );
			
			self GadgetDeactivate( slot, weapon );
			self GadgetPowerSet( slot, 0.0 );
			break;
		}
		if( IsDefined( self.gadgetHitPoints ) )
		{
			hitPointsRatio = self.gadgetHitPoints / maxHitPoints;
		}
		else
		{
			hitPointsRatio = self GadgetPowerChange( self._gadget_armor_slot, 0.0 ) / maxHitPoints;
		}
		stage = 1 + int( hitPointsRatio * ARMOR_STATUS_FULL );
		
		if ( stage > ARMOR_STATUS_FULL )
		{
			stage = ARMOR_STATUS_FULL;
		}
		
		self clientfield::set( "armor_status", stage );
		
		WAIT_SERVER_FRAME;
	}
	
	self clientfield::set( "armor_status", ARMOR_STATUS_OFF );
}