package com.holywarrior.deen_lab

import com.holywarrior.deen_lab.prayer_reminders.PrayerReminderScheduler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val prayerReminderChannel = "deen_lab/prayer_reminders"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            prayerReminderChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDailyReminders" -> {
                    runCatching {
                        @Suppress("UNCHECKED_CAST")
                        PrayerReminderScheduler.scheduleDailyReminders(
                            this,
                            call.arguments as? List<Map<String, Any?>> ?: emptyList()
                        )
                    }.onSuccess(result::success)
                        .onFailure { result.error("SCHEDULE_REMINDERS_ERROR", it.message, null) }
                }
                "cancelAllReminders" -> {
                    runCatching {
                        PrayerReminderScheduler.cancelAll(this)
                        true
                    }.onSuccess(result::success)
                        .onFailure { result.error("CANCEL_REMINDERS_ERROR", it.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
