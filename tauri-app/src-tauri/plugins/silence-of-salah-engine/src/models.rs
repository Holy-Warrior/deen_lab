use serde::{Deserialize, Serialize};

/// How the engine decides when to silence the phone.
///
/// The two working modes are mutually exclusive: they share one persisted
/// audio state on the native side, so running both would mean two owners
/// fighting over the ringer. Switching disarms the outgoing mode but keeps its
/// configuration, so flipping back does not require re-sending a schedule.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EngineMode {
    /// Nothing armed. Both schedules are kept.
    Disabled,
    /// Clock-driven. Silences for a fixed window around a time you supply; no
    /// sensors, no model, no foreground service.
    Manual,
    /// Sensor-driven. A wake alarm starts the foreground service and the
    /// on-device model decides. The plugin's original behaviour, and the
    /// default so that callers written before modes existed are unaffected.
    #[default]
    Ml,
}

/// When a mode switch should take effect.
///
/// Switching tears the outgoing mode down, and if that mode happens to be
/// holding the ringer silent, tearing it down means the phone starts ringing -
/// possibly mid-prayer, which is the one thing this plugin exists to prevent.
/// So the caller says what should happen instead.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ModeSwitchPolicy {
    /// Switch only if nothing is in session; otherwise change nothing and
    /// report what is running. The default, because a refusal is recoverable
    /// and an unexpected ring is not.
    #[default]
    IfIdle,
    /// Switch now regardless, ending whatever is running.
    Immediate,
    /// Leave the current session alone and switch the moment it finishes.
    AfterCurrentSession,
}

/// What the engine is busy doing right now.
///
/// `silencing` is the field a prompt should be worded around: it is the
/// difference between "your phone is silent right now" and "Auto Silent is
/// listening".
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActiveSession {
    pub kind: EngineMode,
    /// The ringer is being held silent at this moment.
    pub silencing: bool,
    /// Which prayer, when the plugin knows. Always `None` in ML mode - nothing
    /// records what started the service, so it reports nothing rather than a guess.
    pub label: Option<String>,
    pub ends_at_millis: Option<i64>,
}

/// The mode picture: what is active, what is queued behind it, and what is
/// currently running.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModeStatus {
    pub mode: EngineMode,
    /// A switch waiting for the active session to end. `None` when nothing is queued.
    pub pending_mode: Option<EngineMode>,
    pub active_session: Option<ActiveSession>,
}

/// The answer to a mode-switch request.
///
/// A blocked switch is not an error - it comes back with `applied: false` and
/// the blocking session in `status.active_session`, which is exactly what a UI
/// needs in order to ask the user whether to switch now or wait.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModeSwitchOutcome {
    /// Whether the requested mode is in effect now.
    pub applied: bool,
    pub status: ModeStatus,
}

/// Arguments for [`crate::SilenceOfSalahEngine::set_engine_mode`].
///
/// Requesting the mode already in effect cancels any pending switch, which is
/// how a UI undoes a deferred change without needing a command for it.
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SetEngineModeRequest {
    pub mode: EngineMode,
    #[serde(default)]
    pub policy: ModeSwitchPolicy,
}

/// One clock-driven silence period, as sent to
/// [`crate::SilenceOfSalahEngine::schedule_manual_windows`].
///
/// `hour`/`minute` are the *final* wall-clock start, with any prayer-time
/// offset already applied. The plugin cannot compute prayer times - it has no
/// location and no calendar - so the caller owns that arithmetic, the same way
/// it already does for [`ScheduleAlarmInput`].
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SilenceWindowInput {
    /// Unique window id. Defaults to `hour * 100 + minute` when omitted.
    pub id: Option<i32>,
    /// 0-23.
    pub hour: u8,
    /// 0-59.
    pub minute: u8,
    /// How long to stay silent, 1-240. Defaults to 30 when omitted.
    pub duration_minutes: Option<u16>,
    pub label: Option<String>,
    /// Defaults to `true` when omitted.
    pub enabled: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleManualWindowsRequest {
    pub windows: Vec<SilenceWindowInput>,
}

/// A silence window as reported back by the native layer, fully resolved.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SilenceWindow {
    pub id: i32,
    pub hour: u8,
    pub minute: u8,
    pub duration_minutes: u16,
    pub label: Option<String>,
    pub enabled: bool,
    pub next_trigger_at_millis: i64,
    pub repeat_daily: bool,
}

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
    // Defaulted rather than required so a status payload written by a state
    // file that predates manual mode still deserializes into something usable
    // instead of failing the whole call.
    #[serde(default)]
    pub mode: EngineMode,
    #[serde(default)]
    pub manual_windows: Vec<SilenceWindow>,
    /// Which window opened the silence currently in effect, if any.
    #[serde(default)]
    pub active_manual_window_id: Option<i32>,
    /// When manual mode will hand the ringer back. `None` when nothing is silenced.
    #[serde(default)]
    pub manual_restore_at_millis: Option<i64>,
    /// A mode switch waiting for the active session to end.
    #[serde(default)]
    pub pending_mode: Option<EngineMode>,
    #[serde(default)]
    pub active_session: Option<ActiveSession>,
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
            "mode": "manual",
            "manualWindows": [{
                "id": 1,
                "hour": 5,
                "minute": 12,
                "durationMinutes": 30,
                "label": "Fajr",
                "enabled": true,
                "nextTriggerAtMillis": 1_800_000_000_000_i64,
                "repeatDaily": true
            }],
            "activeManualWindowId": 1,
            "manualRestoreAtMillis": 1_800_000_060_000_i64,
            "pendingMode": "ml",
            "activeSession": {
                "kind": "manual",
                "silencing": true,
                "label": "Fajr",
                "endsAtMillis": 1_800_000_060_000_i64
            },
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
        assert_eq!(status.mode, EngineMode::Manual);
        assert_eq!(status.manual_windows.len(), 1);
        assert_eq!(status.manual_windows[0].duration_minutes, 30);
        assert_eq!(status.active_manual_window_id, Some(1));
        assert_eq!(status.manual_restore_at_millis, Some(1_800_000_060_000));
        assert_eq!(status.pending_mode, Some(EngineMode::Ml));
        let session = status.active_session.unwrap();
        assert_eq!(session.kind, EngineMode::Manual);
        assert!(session.silencing);
        assert_eq!(session.label.as_deref(), Some("Fajr"));
    }

    /// The wire form has to be exactly `"disabled" | "manual" | "ml"` - Kotlin
    /// produces those strings from `EngineMode.wire()` and the JS side compares
    /// against the same literals.
    #[test]
    fn engine_mode_serializes_to_the_lowercase_wire_strings() {
        assert_eq!(
            serde_json::to_value(EngineMode::Disabled).unwrap(),
            serde_json::json!("disabled")
        );
        assert_eq!(
            serde_json::to_value(EngineMode::Manual).unwrap(),
            serde_json::json!("manual")
        );
        // Not "Ml" - the derive lowercases the whole variant name.
        assert_eq!(
            serde_json::to_value(EngineMode::Ml).unwrap(),
            serde_json::json!("ml")
        );

        let round_tripped: EngineMode = serde_json::from_value(serde_json::json!("manual")).unwrap();
        assert_eq!(round_tripped, EngineMode::Manual);
    }

    /// ML is the default so a caller written before modes existed keeps getting
    /// the behaviour it has always had.
    #[test]
    fn engine_mode_defaults_to_ml() {
        assert_eq!(EngineMode::default(), EngineMode::Ml);
    }

    /// A status payload from a state file that predates manual mode omits every
    /// new field; it must still parse rather than failing the whole call.
    #[test]
    fn native_status_response_tolerates_a_payload_without_the_manual_fields() {
        let json = serde_json::json!({
            "platformVersion": "Android 15",
            "serviceRunning": false,
            "modelLoaded": false,
            "modelPath": null,
            "nativeModelPath": null,
            "recentMlOutputs": [],
            "audioState": "default",
            "currentRingerMode": 2,
            "originalRingerMode": null,
            "shutdownDeadlineMillis": null,
            "scheduledAlarms": [],
            "permissions": {
                "exactAlarm": false,
                "dnd": false,
                "batteryOptimization": false,
                "notifications": false,
                "allGranted": false
            }
        });

        let status: NativeStatusResponse = serde_json::from_value(json).unwrap();
        assert_eq!(status.mode, EngineMode::Ml);
        assert!(status.manual_windows.is_empty());
        assert_eq!(status.active_manual_window_id, None);
        assert_eq!(status.manual_restore_at_millis, None);
        assert_eq!(status.pending_mode, None);
        assert!(status.active_session.is_none());
    }

    /// `SilenceWindowInput` is sent to Kotlin's `SilenceWindowArg`: the
    /// omittable fields must serialize as null rather than being dropped, and
    /// `durationMinutes` must keep its camelCase spelling.
    #[test]
    fn silence_window_input_serializes_with_camel_case_and_optional_fields() {
        let input = SilenceWindowInput {
            id: Some(1),
            hour: 5,
            minute: 12,
            duration_minutes: Some(30),
            label: Some("Fajr".into()),
            enabled: None,
        };

        let json = serde_json::to_value(&input).unwrap();
        assert_eq!(json["id"], 1);
        assert_eq!(json["hour"], 5);
        assert_eq!(json["minute"], 12);
        assert_eq!(json["durationMinutes"], 30);
        assert_eq!(json["label"], "Fajr");
        assert!(json["enabled"].is_null());
        assert!(json.get("duration_minutes").is_none());
    }

    /// Must serialize as `{ "windows": [...] }` - the single named parameter
    /// the Rust command takes, and the shape `ScheduleManualWindowsArgs` expects.
    #[test]
    fn schedule_manual_windows_request_wraps_windows_in_a_named_field() {
        let request = ScheduleManualWindowsRequest {
            windows: vec![SilenceWindowInput {
                id: None,
                hour: 12,
                minute: 6,
                duration_minutes: None,
                label: None,
                enabled: Some(false),
            }],
        };

        let json = serde_json::to_value(&request).unwrap();
        assert_eq!(json["windows"][0]["hour"], 12);
        assert_eq!(json["windows"][0]["enabled"], false);
        assert!(json["windows"][0]["id"].is_null());
        assert!(json["windows"][0]["durationMinutes"].is_null());
    }

    /// Round-trips a `SilenceWindow` the way `SilenceWindow.toMap()` returns it
    /// from Kotlin.
    #[test]
    fn silence_window_round_trips_from_kotlin_shaped_json() {
        let json = serde_json::json!({
            "id": 4,
            "hour": 18,
            "minute": 33,
            "durationMinutes": 25,
            "label": "Maghrib",
            "enabled": true,
            "nextTriggerAtMillis": 1_800_000_000_000_i64,
            "repeatDaily": true
        });

        let window: SilenceWindow = serde_json::from_value(json).unwrap();
        assert_eq!(window.id, 4);
        assert_eq!(window.duration_minutes, 25);
        assert_eq!(window.label.as_deref(), Some("Maghrib"));
        assert!(window.repeat_daily);

        let round_tripped = serde_json::to_value(&window).unwrap();
        assert!(round_tripped.get("durationMinutes").is_some());
        assert!(round_tripped.get("duration_minutes").is_none());
    }

    /// `SetEngineModeRequest` must serialize as `{ "mode", "policy" }` to match
    /// Kotlin's `SetEngineModeArgs`.
    #[test]
    fn set_engine_mode_request_carries_the_mode_and_the_policy() {
        let json = serde_json::to_value(SetEngineModeRequest {
            mode: EngineMode::Manual,
            policy: ModeSwitchPolicy::AfterCurrentSession,
        })
        .unwrap();

        assert_eq!(json["mode"], "manual");
        assert_eq!(json["policy"], "afterCurrentSession");
    }

    /// Omitting the policy has to mean the cautious one. A caller that has not
    /// thought about it must not end up silently ending someone's prayer.
    #[test]
    fn an_omitted_policy_defaults_to_if_idle() {
        let request: SetEngineModeRequest =
            serde_json::from_value(serde_json::json!({ "mode": "ml" })).unwrap();

        assert_eq!(request.policy, ModeSwitchPolicy::IfIdle);
        assert_eq!(ModeSwitchPolicy::default(), ModeSwitchPolicy::IfIdle);
    }

    /// camelCase on the wire, matching `ModeSwitchPolicy.wire` in Kotlin and the
    /// TypeScript union.
    #[test]
    fn mode_switch_policy_serializes_to_camel_case() {
        assert_eq!(
            serde_json::to_value(ModeSwitchPolicy::IfIdle).unwrap(),
            serde_json::json!("ifIdle")
        );
        assert_eq!(
            serde_json::to_value(ModeSwitchPolicy::Immediate).unwrap(),
            serde_json::json!("immediate")
        );
        assert_eq!(
            serde_json::to_value(ModeSwitchPolicy::AfterCurrentSession).unwrap(),
            serde_json::json!("afterCurrentSession")
        );
    }

    /// A blocked switch is reported, not thrown: `applied` is false and the
    /// session that blocked it is attached, so the caller can prompt.
    #[test]
    fn a_blocked_mode_switch_outcome_carries_the_session_that_blocked_it() {
        let json = serde_json::json!({
            "applied": false,
            "status": {
                "mode": "ml",
                "pendingMode": null,
                "activeSession": {
                    "kind": "ml",
                    "silencing": true,
                    "label": null,
                    "endsAtMillis": null
                }
            }
        });

        let outcome: ModeSwitchOutcome = serde_json::from_value(json).unwrap();
        assert!(!outcome.applied);
        assert_eq!(outcome.status.mode, EngineMode::Ml);
        assert_eq!(outcome.status.pending_mode, None);

        let session = outcome.status.active_session.unwrap();
        assert_eq!(session.kind, EngineMode::Ml);
        assert!(session.silencing);
        // ML mode cannot say which prayer woke it, and must not invent one.
        assert_eq!(session.label, None);
    }

    /// A deferred switch reports the mode still in effect, with the queued one
    /// alongside it - not the other way round.
    #[test]
    fn a_deferred_mode_switch_reports_the_current_mode_and_the_queued_one() {
        let json = serde_json::json!({
            "applied": false,
            "status": {
                "mode": "ml",
                "pendingMode": "manual",
                "activeSession": {
                    "kind": "ml",
                    "silencing": true,
                    "label": null,
                    "endsAtMillis": 1_800_000_060_000_i64
                }
            }
        });

        let outcome: ModeSwitchOutcome = serde_json::from_value(json).unwrap();
        assert!(!outcome.applied);
        assert_eq!(outcome.status.mode, EngineMode::Ml);
        assert_eq!(outcome.status.pending_mode, Some(EngineMode::Manual));
    }

    /// Nothing running, so the switch went through and nothing is queued.
    #[test]
    fn an_applied_mode_switch_reports_no_session_and_nothing_pending() {
        let json = serde_json::json!({
            "applied": true,
            "status": {
                "mode": "manual",
                "pendingMode": null,
                "activeSession": null
            }
        });

        let outcome: ModeSwitchOutcome = serde_json::from_value(json).unwrap();
        assert!(outcome.applied);
        assert_eq!(outcome.status.mode, EngineMode::Manual);
        assert!(outcome.status.active_session.is_none());
    }
}
