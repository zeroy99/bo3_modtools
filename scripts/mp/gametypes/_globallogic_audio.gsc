	
#namespace globallogic_audio;
	

function set_leader_gametype_dialog( startGameDialogKey, startHcGameDialogKey, offenseOrderDialogKey, defenseOrderDialogKey ) {}

function flush_objective_dialog( objectiveKey ) {}

function leader_dialog_for_other_teams( dialogKey, skipTeam, objectiveKey, killstreakId, dialogBufferKey ) {}

function leader_dialog( dialogKey, team, excludeList, objectiveKey, killstreakId, dialogBufferKey ) {}

function leader_dialog_on_player( dialogKey, objectiveKey, killstreakId, dialogBufferKey, introDialog ) {}

function play_2d_on_team( alias, team ) {}

function set_music_on_team( state, team = "both", wait_time = 0, save_state = false, return_state = false ) {}
