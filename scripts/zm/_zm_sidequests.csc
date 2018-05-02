#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace zm_sidequests;

function register_sidequest_icon( icon_name, version_number )
{
	clientfieldPrefix = "sidequestIcons." + icon_name + ".";
	
	clientfield::register( "clientuimodel", clientfieldPrefix + "icon", version_number, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", clientfieldPrefix + "notification", version_number, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}