use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::models::*;
use crate::Result;

const PLUGIN_IDENTIFIER: &str = "com.holywarrior.silence_of_salah_engine";

/// Initializes the Kotlin plugin class (`SilenceEnginePlugin`, see
/// `android/src/main/kotlin/.../SilenceEnginePlugin.kt`).
pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> Result<SilenceOfSalahEngine<R>> {
    let handle = api.register_android_plugin(PLUGIN_IDENTIFIER, "SilenceEnginePlugin")?;
    Ok(SilenceOfSalahEngine(handle))
}

/// Access to the silence-of-salah-engine APIs.
pub struct SilenceOfSalahEngine<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> SilenceOfSalahEngine<R> {
    pub fn get_platform_version(&self) -> Result<String> {
        self.0
            .run_mobile_plugin("getPlatformVersion", ())
            .map_err(Into::into)
    }

    pub fn start_native_task(&self, payload: StartNativeTaskRequest) -> Result<bool> {
        self.0
            .run_mobile_plugin("startNativeTask", payload)
            .map_err(Into::into)
    }

    pub fn stop_native_task(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("stopNativeTask", ())
            .map_err(Into::into)
    }

    pub fn get_native_status(&self) -> Result<NativeStatusResponse> {
        self.0
            .run_mobile_plugin("getNativeStatus", ())
            .map_err(Into::into)
    }

    pub fn schedule_daily_alarms(
        &self,
        payload: ScheduleDailyAlarmsRequest,
    ) -> Result<Vec<ScheduledAlarm>> {
        self.0
            .run_mobile_plugin("scheduleDailyAlarms", payload)
            .map_err(Into::into)
    }

    pub fn get_scheduled_alarms(&self) -> Result<Vec<ScheduledAlarm>> {
        self.0
            .run_mobile_plugin("getScheduledAlarms", ())
            .map_err(Into::into)
    }

    pub fn cancel_all_alarms(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("cancelAllAlarms", ())
            .map_err(Into::into)
    }

    pub fn trigger_ml_processing(
        &self,
        payload: TriggerMlProcessingRequest,
    ) -> Result<MlPredictionResponse> {
        self.0
            .run_mobile_plugin("triggerMlProcessing", payload)
            .map_err(Into::into)
    }

    pub fn submit_ml_decision_output(
        &self,
        payload: SubmitMlDecisionRequest,
    ) -> Result<DecisionSnapshot> {
        self.0
            .run_mobile_plugin("submitMlDecisionOutput", payload)
            .map_err(Into::into)
    }

    pub fn debug_set_audio_silent(&self) -> Result<DecisionSnapshot> {
        self.0
            .run_mobile_plugin("debugSetAudioSilent", ())
            .map_err(Into::into)
    }

    pub fn debug_restore_audio_default(&self) -> Result<DecisionSnapshot> {
        self.0
            .run_mobile_plugin("debugRestoreAudioDefault", ())
            .map_err(Into::into)
    }

    pub fn get_permission_status(&self) -> Result<PermissionStatus> {
        self.0
            .run_mobile_plugin("getPermissionStatus", ())
            .map_err(Into::into)
    }

    pub fn request_exact_alarm_permission(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("requestExactAlarmPermission", ())
            .map_err(Into::into)
    }

    pub fn request_dnd_access(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("requestDndAccess", ())
            .map_err(Into::into)
    }

    pub fn request_battery_optimization(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("requestBatteryOptimization", ())
            .map_err(Into::into)
    }

    pub fn request_notification_permission(&self) -> Result<bool> {
        self.0
            .run_mobile_plugin("requestNotificationPermission", ())
            .map_err(Into::into)
    }
}
