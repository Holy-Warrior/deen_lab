package com.holywarrior.silence_of_salah_engine

object Config {
    const val WAKE_LOCK_TIMEOUT_MS = 45 * 60 * 1000L
    const val ML_BUFFER_SIZE = 5
    const val SHUTDOWN_DELAY_MS = 10 * 60 * 1000L
    const val SENSOR_WINDOW_SIZE = 150
    const val SENSOR_LOOP_INTERVAL_MS = 100L
    const val INFERENCE_TIMEOUT_MS = 5_000L

    const val NOTIFICATION_CHANNEL_ID = "silence_engine_channel"
    const val NOTIFICATION_CHANNEL_NAME = "Silence Engine"
    const val NOTIFICATION_ID = 1
    const val NOTIFICATION_TITLE = "Silence of Salah"
    const val NOTIFICATION_TEXT_RUNNING = "Service is running"
    const val NOTIFICATION_TEXT_STARTING = "Preparing background service"
    const val NOTIFICATION_TEXT_RECOVERING = "Restoring background service"

    // Manual mode has no foreground service, so Android does not force a
    // notification on it. This one is posted anyway, on the same channel but a
    // separate id: a phone that has gone silent on its own with nothing on
    // screen to explain why is the exact thing people distrust.
    const val MANUAL_NOTIFICATION_ID = 2
    const val MANUAL_NOTIFICATION_TITLE = "Phone silenced for salah"

    const val ACTION_START = "com.holywarrior.silence_of_salah_engine.action.START"
    const val ACTION_STOP = "com.holywarrior.silence_of_salah_engine.action.STOP"
    const val ACTION_WAKELOCK_TIMEOUT =
        "com.holywarrior.silence_of_salah_engine.action.WAKELOCK_TIMEOUT"

    const val EXTRA_START_REASON = "start_reason"
    const val EXTRA_ALARM_ID = "alarm_id"
    const val EXTRA_ALARM_KIND = "alarm_kind"

    // Which of the three things an AlarmReceiver broadcast means. Absent is
    // treated as ML so alarms persisted by an older build still work.
    const val ALARM_KIND_ML_WAKE = "ml_wake"
    const val ALARM_KIND_MANUAL_START = "manual_start"
    const val ALARM_KIND_MANUAL_END = "manual_end"

    // PendingIntent identity ignores extras, so ML wakes and the two manual
    // alarms must live in disjoint request-code ranges or they would overwrite
    // each other. Alarm ids come from the app and are small (one per prayer).
    const val MANUAL_START_REQUEST_BASE = 100_000
    const val MANUAL_END_REQUEST_BASE = 200_000

    // Ids are used directly as PendingIntent request codes, so bounding them is
    // what actually keeps the three ranges above from overlapping.
    const val MAX_ALARM_ID = 99_999

    const val MANUAL_WINDOW_DEFAULT_MINUTES = 30
    const val MANUAL_WINDOW_MAX_MINUTES = 240

    // An exact alarm can fire a hair early; without this an end alarm could
    // decide it is not due yet and reschedule itself a few milliseconds out.
    const val MANUAL_RESTORE_TOLERANCE_MS = 1_000L

    const val STATE_FILE_NAME = "silence_engine_state.json"
}
