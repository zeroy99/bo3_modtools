#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\shared\util_shared;

#namespace multi_extracam;

function extracam_reset_index( localClientNum, index )
{
	if( !isdefined(level.camera_ents) || !isdefined(level.camera_ents[localClientNum]) )
	{
		return;
	}

	if( isdefined( level.camera_ents[localClientNum][index] ) )
	{
		level.camera_ents[localClientNum][index] ClearExtraCam();
		level.camera_ents[localClientNum][index] Delete();
		level.camera_ents[localClientNum][index] = undefined;
	}
}

function extracam_init_index( localClientNum, target, index )
{
	cameraStruct = struct::get( target, "targetname" );
	return extracam_init_item( localClientNum, cameraStruct, index );
}

function extracam_init_item( localClientNum, copy_ent, index )
{
	DEFAULT( level.camera_ents, [] );

	if( !isdefined(level.camera_ents[localClientNum]) )
	{
		level.camera_ents[localClientNum] = [];
	}

	if( isdefined( level.camera_ents[localClientNum][index] ) )
	{
		level.camera_ents[localClientNum][index] ClearExtraCam();
		level.camera_ents[localClientNum][index] Delete();
		level.camera_ents[localClientNum][index] = undefined;
	}
	
	if ( isdefined( copy_ent ) )
	{
		level.camera_ents[localClientNum][index] = Spawn( localClientNum, copy_ent.origin, "script_origin" );
		level.camera_ents[localClientNum][index].angles = copy_ent.angles;

		level.camera_ents[localClientNum][index] SetExtraCam( index );
		return level.camera_ents[localClientNum][index];
	}
	
	return undefined;
}