use tauri::{command, AppHandle, Runtime};

use crate::models::*;
use crate::Result;
use crate::SilenceOfSalahEngineExt;

#[command]
pub(crate) async fn get_platform_version<R: Runtime>(app: AppHandle<R>) -> Result<String> {
    app.silence_of_salah_engine().get_platform_version()
}

#[command]
pub(crate) async fn start_native_task<R: Runtime>(
    app: AppHandle<R>,
    payload: StartNativeTaskRequest,
) -> Result<bool> {
    app.silence_of_salah_engine().start_native_task(payload)
}

#[command]
pub(crate) async fn stop_native_task<R: Runtime>(app: AppHandle<R>) -> Result<bool> {
    app.silence_of_salah_engine().stop_native_task()
}

#[command]
pub(crate) async fn get_native_status<R: Runtime>(
    app: AppHandle<R>,
) -> Result<NativeStatusResponse> {
    app.silence_of_salah_engine().get_native_status()
}

#[command]
pub(crate) async fn schedule_daily_alarms<R: Runtime>(
    app: AppHandle<R>,
    payload: ScheduleDailyAlarmsRequest,
) -> Result<Vec<ScheduledAlarm>> {
    app.silence_of_salah_engine()
        .schedule_daily_alarms(payload)
}

#[command]
pub(crate) async fn get_scheduled_alarms<R: Runtime>(
    app: AppHandle<R>,
) -> Result<Vec<ScheduledAlarm>> {
    app.silence_of_salah_engine().get_scheduled_alarms()
}

#[command]
pub(crate) async fn cancel_all_alarms<R: Runtime>(app: AppHandle<R>) -> Result<bool> {
    app.silence_of_salah_engine().cancel_all_alarms()
}

#[command]
pub(crate) async fn trigger_ml_processing<R: Runtime>(
    app: AppHandle<R>,
    payload: TriggerMlProcessingRequest,
) -> Result<MlPredictionResponse> {
    app.silence_of_salah_engine()
        .trigger_ml_processing(payload)
}

#[command]
pub(crate) async fn submit_ml_decision_output<R: Runtime>(
    app: AppHandle<R>,
    payload: SubmitMlDecisionRequest,
) -> Result<DecisionSnapshot> {
    app.silence_of_salah_engine()
        .submit_ml_decision_output(payload)
}

#[command]
pub(crate) async fn debug_set_audio_silent<R: Runtime>(
    app: AppHandle<R>,
) -> Result<DecisionSnapshot> {
    app.silence_of_salah_engine().debug_set_audio_silent()
}

#[command]
pub(crate) async fn debug_restore_audio_default<R: Runtime>(
    app: AppHandle<R>,
) -> Result<DecisionSnapshot> {
    app.silence_of_salah_engine().debug_restore_audio_default()
}

#[command]
pub(crate) async fn get_permission_status<R: Runtime>(
    app: AppHandle<R>,
) -> Result<PermissionStatus> {
    app.silence_of_salah_engine().get_permission_status()
}

#[command]
pub(crate) async fn request_exact_alarm_permission<R: Runtime>(app: AppHandle<R>) -> Result<bool> {
    app.silence_of_salah_engine()
        .request_exact_alarm_permission()
}

#[command]
pub(crate) async fn request_dnd_access<R: Runtime>(app: AppHandle<R>) -> Result<bool> {
    app.silence_of_salah_engine().request_dnd_access()
}

#[command]
pub(crate) async fn request_battery_optimization<R: Runtime>(app: AppHandle<R>) -> Result<bool> {
    app.silence_of_salah_engine().request_battery_optimization()
}

#[command]
pub(crate) async fn request_notification_permission<R: Runtime>(
    app: AppHandle<R>,
) -> Result<bool> {
    app.silence_of_salah_engine()
        .request_notification_permission()
}
