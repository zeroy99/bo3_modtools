#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\mp\gametypes\fr.gsh;

function main()
{
	callback::on_localclient_connect( &on_player_connect );

	clientfield::register( "world", "freerun_state", VERSION_SHIP, 3, "int", &freerunStateChanged, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_retries", VERSION_SHIP, FR_RETRIES_BITS, "int", &freerunRetriesUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_faults", VERSION_SHIP, FR_FAULTS_BITS, "int", &freerunFaultsUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_startTime", VERSION_SHIP, FR_TIME_BITS, "int", &freerunStartTimeUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_finishTime", VERSION_SHIP, FR_TIME_BITS, "int", &freerunFinishTimeUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_bestTime", VERSION_SHIP, FR_TIME_BITS, "int", &freerunBestTimeUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_timeAdjustment", VERSION_SHIP, FR_TIME_BITS, "int", &freerunTimeAdjustmentUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_timeAdjustmentNegative", VERSION_SHIP, 1, "int", &freerunTimeAdjustmentSignUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_bulletPenalty", VERSION_SHIP, FR_BULLETPENALTY_BITS, "int", &freerunbulletPenaltyUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_pausedTime", VERSION_SHIP, FR_TIME_BITS, "int", &freerunPausedTimeUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "world", "freerun_checkpointIndex", VERSION_SHIP, 7, "int", &freerunCheckPointUpdated, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function on_player_connect( localClientNum )
{
	AllowActionSlotInput( localClientNum );
	AllowScoreboard( localClientNum, false );
}

function freerunStateChanged( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    stateModel = CreateUIModel( controllerModel, "FreeRun.runState" );
    SetUIModelValue( stateModel, newVal );
}

function freerunRetriesUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    retriesModel = CreateUIModel( controllerModel, "FreeRun.freeRunInfo.retries" );
    SetUIModelValue( retriesModel, newVal );
}

function freerunFaultsUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    faultsModel = CreateUIModel( controllerModel, "FreeRun.freeRunInfo.faults" );
    SetUIModelValue( faultsModel, newVal );
}

function freerunStartTimeUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.startTime" );
    SetUIModelValue( model, newVal );
}

function freerunFinishTimeUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.finishTime" );
    SetUIModelValue( model, newVal );
}

function freerunBestTimeUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.freeRunInfo.bestTime" );
    SetUIModelValue( model, newVal );
}

function freerunTimeAdjustmentUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.timer.timeAdjustment" );
    SetUIModelValue( model, newVal );
}

function freerunTimeAdjustmentSignUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
 	model = CreateUIModel( controllerModel, "FreeRun.timer.timeAdjustmentNegative" );
  	SetUIModelValue( model, newVal );
}

function freerunbulletPenaltyUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
	bulletPenaltyModel = CreateUIModel( controllerModel, "FreeRun.freeRunInfo.bulletPenalty" );
	SetUIModelValue( bulletPenaltyModel, newVal );
}

function freerunPausedTimeUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.pausedTime" );
    SetUIModelValue( model, newVal );
}

function freerunCheckPointUpdated( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	controllerModel = GetUIModelForController( localClientNum );
    model = CreateUIModel( controllerModel, "FreeRun.freeRunInfo.activeCheckpoint" );
    SetUIModelValue( model, newVal );
}

function onPrecacheGameType()
{
}

function onStartGameType()
{	
}