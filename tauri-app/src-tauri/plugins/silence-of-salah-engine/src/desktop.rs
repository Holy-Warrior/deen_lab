use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::*;
use crate::{Error, Result};

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> Result<SilenceOfSalahEngine<R>> {
    Ok(SilenceOfSalahEngine(app.clone()))
}

/// Non-Android stub so the crate compiles (and is unit-testable via `cargo
/// test`) on every host platform. Every method returns
/// [`Error::UnsupportedPlatform`] since this plugin wraps Android-only APIs
/// (a persistent foreground service, exact alarms, on-device sensors and
/// ringer-mode control) that have no desktop or iOS equivalent - the
/// original Flutter plugin never implemented iOS either.
///
/// Holds an `AppHandle<R>` (unused) rather than `PhantomData<R>` - Tauri
/// guarantees `AppHandle<R>` is `Send + Sync` for any `R: Runtime`, which a
/// bare `PhantomData<R>` is not, and this type gets stored via `app.manage()`
/// which requires `Send + Sync + 'static`.
pub struct SilenceOfSalahEngine<R: Runtime>(AppHandle<R>);

impl<R: Runtime> SilenceOfSalahEngine<R> {
    fn unsupported<T>() -> Result<T> {
        Err(Error::UnsupportedPlatform(
            "this plugin only runs on Android".into(),
        ))
    }

    pub fn get_platform_version(&self) -> Result<String> {
        Self::unsupported()
    }

    pub fn start_native_task(&self, _payload: StartNativeTaskRequest) -> Result<bool> {
        Self::unsupported()
    }

    pub fn stop_native_task(&self) -> Result<bool> {
        Self::unsupported()
    }

    pub fn get_native_status(&self) -> Result<NativeStatusResponse> {
        Self::unsupported()
    }

    pub fn schedule_daily_alarms(
        &self,
        _payload: ScheduleDailyAlarmsRequest,
    ) -> Result<Vec<ScheduledAlarm>> {
        Self::unsupported()
    }

    pub fn get_scheduled_alarms(&self) -> Result<Vec<ScheduledAlarm>> {
        Self::unsupported()
    }

    pub fn cancel_all_alarms(&self) -> Result<bool> {
        Self::unsupported()
    }

    pub fn trigger_ml_processing(
        &self,
        _payload: TriggerMlProcessingRequest,
    ) -> Result<MlPredictionResponse> {
        Self::unsupported()
    }

    pub fn submit_ml_decision_output(
        &self,
        _payload: SubmitMlDecisionRequest,
    ) -> Result<DecisionSnapshot> {
        Self::unsupported()
    }

    pub fn debug_set_audio_silent(&self) -> Result<DecisionSnapshot> {
        Self::unsupported()
    }

    pub fn debug_restore_audio_default(&self) -> Result<DecisionSnapshot> {
        Self::unsupported()
    }

    pub fn get_permission_status(&self) -> Result<PermissionStatus> {
        Self::unsupported()
    }

    pub fn request_exact_alarm_permission(&self) -> Result<bool> {
        Self::unsupported()
    }

    pub fn request_dnd_access(&self) -> Result<bool> {
        Self::unsupported()
    }

    pub fn request_battery_optimization(&self) -> Result<bool> {
        Self::unsupported()
    }

    pub fn request_notification_permission(&self) -> Result<bool> {
        Self::unsupported()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // tauri::test::mock_app() needs the `test` feature on the `tauri` dev-dependency
    // (see Cargo.toml [dev-dependencies]) - it gives us a real, lightweight
    // App<MockRuntime> without needing an actual webview.
    fn engine() -> SilenceOfSalahEngine<tauri::test::MockRuntime> {
        let app = tauri::test::mock_app();
        SilenceOfSalahEngine(app.handle().clone())
    }

    #[test]
    fn every_no_arg_command_reports_unsupported_platform() {
        assert!(engine().get_platform_version().is_err());
        assert!(engine().stop_native_task().is_err());
        assert!(engine().get_native_status().is_err());
        assert!(engine().get_scheduled_alarms().is_err());
        assert!(engine().cancel_all_alarms().is_err());
        assert!(engine().get_permission_status().is_err());
        assert!(engine().request_exact_alarm_permission().is_err());
        assert!(engine().request_dnd_access().is_err());
        assert!(engine().request_battery_optimization().is_err());
        assert!(engine().request_notification_permission().is_err());
        assert!(engine().debug_set_audio_silent().is_err());
        assert!(engine().debug_restore_audio_default().is_err());
    }

    #[test]
    fn every_payload_command_reports_unsupported_platform() {
        assert!(engine()
            .start_native_task(StartNativeTaskRequest { reason: None })
            .is_err());
        assert!(engine()
            .schedule_daily_alarms(ScheduleDailyAlarmsRequest { alarms: vec![] })
            .is_err());
        assert!(engine()
            .trigger_ml_processing(TriggerMlProcessingRequest { features: vec![] })
            .is_err());
        assert!(engine()
            .submit_ml_decision_output(SubmitMlDecisionRequest { value: true })
            .is_err());
    }

    #[test]
    fn the_error_variant_is_unsupported_platform_not_something_else() {
        let error = engine().get_platform_version().unwrap_err();
        assert!(matches!(error, Error::UnsupportedPlatform(_)));
    }
}
