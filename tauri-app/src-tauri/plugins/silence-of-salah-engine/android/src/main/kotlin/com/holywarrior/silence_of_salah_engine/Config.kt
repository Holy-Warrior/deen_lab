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

    const val ACTION_START = "com.holywarrior.silence_of_salah_engine.action.START"
    const val ACTION_STOP = "com.holywarrior.silence_of_salah_engine.action.STOP"
    const val ACTION_WAKELOCK_TIMEOUT =
        "com.holywarrior.silence_of_salah_engine.action.WAKELOCK_TIMEOUT"

    const val EXTRA_START_REASON = "start_reason"
    const val EXTRA_ALARM_ID = "alarm_id"

    const val STATE_FILE_NAME = "silence_engine_state.json"
}
