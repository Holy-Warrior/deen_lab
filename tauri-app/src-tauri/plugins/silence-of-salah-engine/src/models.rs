use serde::{Deserialize, Serialize};

/// Arguments for [`crate::SilenceOfSalahEngine::start_native_task`].
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartNativeTaskRequest {
    /// Free-form tag recorded for diagnostics (e.g. `"manual_start"`, `"alarm:530"`).
    /// Defaults to `"tauri"` on the native side when omitted.
    pub reason: Option<String>,
}

/// A single alarm definition sent to [`crate::SilenceOfSalahEngine::schedule_daily_alarms`].
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleAlarmInput {
    /// Unique alarm id. Defaults to `hour * 100 + minute` when omitted.
    pub id: Option<i32>,
    /// 0-23.
    pub hour: u8,
    /// 0-59.
    pub minute: u8,
    pub label: Option<String>,
    /// Defaults to `true` when omitted.
    pub enabled: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleDailyAlarmsRequest {
    pub alarms: Vec<ScheduleAlarmInput>,
}

/// An alarm as reported back by the native layer, always fully resolved
/// (id/enabled defaults applied, `nextTriggerAtMillis` computed).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduledAlarm {
    pub id: i32,
    pub hour: u8,
    pub minute: u8,
    pub label: Option<String>,
    pub enabled: bool,
    pub next_trigger_at_millis: i64,
    pub repeat_daily: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TriggerMlProcessingRequest {
    /// Flattened `[ACC[0..N-1], GYR[0..N-1], MAG[0..N-1]]` sensor-window features.
    /// Must match the loaded model's expected feature count exactly (450 for the
    /// bundled 150-sample / 3-channel window).
    pub features: Vec<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MlPredictionResponse {
    pub label: i32,
    pub probability: f64,
    pub is_prayer_detected: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubmitMlDecisionRequest {
    pub value: bool,
}

/// Snapshot of the audio decision-engine state, returned by every command
/// that can move the engine between `default` and `silent`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DecisionSnapshot {
    pub recent_ml_outputs: Vec<bool>,
    /// `"default"` or `"silent"`.
    pub audio_state: String,
    pub original_ringer_mode: Option<i32>,
    pub has_entered_silent_once: bool,
    pub shutdown_deadline_millis: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionStatus {
    pub exact_alarm: bool,
    pub dnd: bool,
    pub battery_optimization: bool,
    pub notifications: bool,
    pub all_granted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NativeStatusResponse {
    pub platform_version: String,
    pub service_running: bool,
    pub model_loaded: bool,
    pub model_path: Option<String>,
    pub native_model_path: Option<String>,
    pub recent_ml_outputs: Vec<bool>,
    /// `"default"` or `"silent"`.
    pub audio_state: String,
    pub current_ringer_mode: i32,
    pub original_ringer_mode: Option<i32>,
    pub shutdown_deadline_millis: Option<i64>,
    pub scheduled_alarms: Vec<ScheduledAlarm>,
    pub permissions: PermissionStatus,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `ScheduleAlarmInput` is sent to Kotlin's `ScheduleAlarmArg` - field
    /// names and optionality (id/label/enabled all omittable) must match.
    #[test]
    fn schedule_alarm_input_serializes_with_camel_case_and_optional_fields() {
        let input = ScheduleAlarmInput {
            id: None,
            hour: 5,
            minute: 12,
            label: Some("Fajr".into()),
            enabled: None,
        };

        let json = serde_json::to_value(&input).unwrap();
        assert_eq!(json["hour"], 5);
        assert_eq!(json["minute"], 12);
        assert_eq!(json["label"], "Fajr");
        assert!(json["id"].is_null());
        assert!(json["enabled"].is_null());
    }

    /// `ScheduleDailyAlarmsRequest` must serialize as `{ "alarms": [...] }`
    /// since that's the single named parameter the Rust command takes and
    /// the shape Kotlin's `ScheduleDailyAlarmsArgs` expects.
    #[test]
    fn schedule_daily_alarms_request_wraps_alarms_in_a_named_field() {
        let request = ScheduleDailyAlarmsRequest {
            alarms: vec![ScheduleAlarmInput {
                id: Some(512),
                hour: 5,
                minute: 12,
                label: None,
                enabled: Some(true),
            }],
        };

        let json = serde_json::to_value(&request).unwrap();
        assert_eq!(json["alarms"][0]["id"], 512);
        assert_eq!(json["alarms"][0]["enabled"], true);
    }

    /// Round-trips a `ScheduledAlarm` the way it comes back from Kotlin's
    /// `EngineNativeActions.scheduleDailyAlarms` (camelCase keys, all fields
    /// always present).
    #[test]
    fn scheduled_alarm_round_trips_from_kotlin_shaped_json() {
        let json = serde_json::json!({
            "id": 512,
            "hour": 5,
            "minute": 12,
            "label": "Fajr",
            "enabled": true,
            "nextTriggerAtMillis": 1_800_000_000_000_i64,
            "repeatDaily": true
        });

        let alarm: ScheduledAlarm = serde_json::from_value(json).unwrap();
        assert_eq!(alarm.id, 512);
        assert_eq!(alarm.hour, 5);
        assert_eq!(alarm.minute, 12);
        assert_eq!(alarm.label.as_deref(), Some("Fajr"));
        assert!(alarm.enabled);
        assert_eq!(alarm.next_trigger_at_millis, 1_800_000_000_000);
        assert!(alarm.repeat_daily);

        // And serializing it back out should still be camelCase.
        let round_tripped = serde_json::to_value(&alarm).unwrap();
        assert!(round_tripped.get("nextTriggerAtMillis").is_some());
        assert!(round_tripped.get("next_trigger_at_millis").is_none());
    }

    /// `MlPredictionResponse` must accept the exact shape
    /// `EngineNativeActions.triggerMlProcessing` returns.
    #[test]
    fn ml_prediction_response_deserializes_kotlin_shaped_json() {
        let json = serde_json::json!({
            "label": 1,
            "probability": 0.987,
            "isPrayerDetected": true
        });

        let prediction: MlPredictionResponse = serde_json::from_value(json).unwrap();
        assert_eq!(prediction.label, 1);
        assert!((prediction.probability - 0.987).abs() < f64::EPSILON);
        assert!(prediction.is_prayer_detected);
    }

    /// `DecisionSnapshot` must round-trip the exact map shape
    /// `MlDecisionEngine.snapshot()` produces, including `null` optionals.
    #[test]
    fn decision_snapshot_round_trips_with_null_optionals() {
        let json = serde_json::json!({
            "recentMlOutputs": [true, true, false],
            "audioState": "silent",
            "originalRingerMode": null,
            "hasEnteredSilentOnce": true,
            "shutdownDeadlineMillis": null
        });

        let snapshot: DecisionSnapshot = serde_json::from_value(json).unwrap();
        assert_eq!(snapshot.recent_ml_outputs, vec![true, true, false]);
        assert_eq!(snapshot.audio_state, "silent");
        assert_eq!(snapshot.original_ringer_mode, None);
        assert!(snapshot.has_entered_silent_once);
        assert_eq!(snapshot.shutdown_deadline_millis, None);
    }

    /// `PermissionStatus` field names must match
    /// `EngineNativeActions.getPermissionStatus()` exactly.
    #[test]
    fn permission_status_field_names_match_kotlin() {
        let json = serde_json::json!({
            "exactAlarm": true,
            "dnd": false,
            "batteryOptimization": true,
            "notifications": false,
            "allGranted": false
        });

        let status: PermissionStatus = serde_json::from_value(json).unwrap();
        assert!(status.exact_alarm);
        assert!(!status.dnd);
        assert!(status.battery_optimization);
        assert!(!status.notifications);
        assert!(!status.all_granted);
    }

    /// A minimal end-to-end check that `NativeStatusResponse` (the biggest,
    /// most nested type) deserializes from a fully Kotlin-shaped payload.
    #[test]
    fn native_status_response_deserializes_full_kotlin_shaped_payload() {
        let json = serde_json::json!({
            "platformVersion": "Android 15",
            "serviceRunning": true,
            "modelLoaded": true,
            "modelPath": "/data/user/0/app/files/models/model.json",
            "nativeModelPath": "/data/user/0/app/files/models/model.json",
            "recentMlOutputs": [true, true, true, true, true],
            "audioState": "silent",
            "currentRingerMode": 0,
            "originalRingerMode": 2,
            "shutdownDeadlineMillis": null,
            "scheduledAlarms": [{
                "id": 512,
                "hour": 5,
                "minute": 12,
                "label": "Fajr",
                "enabled": true,
                "nextTriggerAtMillis": 1_800_000_000_000_i64,
                "repeatDaily": true
            }],
            "permissions": {
                "exactAlarm": true,
                "dnd": true,
                "batteryOptimization": true,
                "notifications": true,
                "allGranted": true
            }
        });

        let status: NativeStatusResponse = serde_json::from_value(json).unwrap();
        assert_eq!(status.platform_version, "Android 15");
        assert!(status.service_running);
        assert_eq!(status.scheduled_alarms.len(), 1);
        assert_eq!(status.scheduled_alarms[0].label.as_deref(), Some("Fajr"));
        assert!(status.permissions.all_granted);
    }
}
