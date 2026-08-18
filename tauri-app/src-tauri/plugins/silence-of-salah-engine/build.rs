const COMMANDS: &[&str] = &[
    "get_platform_version",
    "start_native_task",
    "stop_native_task",
    "get_native_status",
    "schedule_daily_alarms",
    "get_scheduled_alarms",
    "cancel_all_alarms",
    "trigger_ml_processing",
    "submit_ml_decision_output",
    "debug_set_audio_silent",
    "debug_restore_audio_default",
    "get_permission_status",
    "request_exact_alarm_permission",
    "request_dnd_access",
    "request_battery_optimization",
    "request_notification_permission",
];

fn main() {
    let result = tauri_plugin::Builder::new(COMMANDS)
        .android_path("android")
        .try_build();

    // When building documentation (docs.rs) for an android target the plugin
    // build result can be Err() even though nothing is actually wrong, since
    // there is no real Android project around to link against.
    if !(cfg!(docsrs) && std::env::var("TARGET").unwrap_or_default().contains("android")) {
        result.unwrap();
    }
}
