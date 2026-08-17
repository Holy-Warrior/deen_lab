package com.holywarrior.deen_lab.prayer_reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object PrayerReminderScheduler {
    private const val EXTRA_REMINDER_ID = "deen_lab.extra.REMINDER_ID"

    fun scheduleDailyReminders(
        context: Context,
        rawReminders: List<Map<String, Any?>>
    ): List<Map<String, Any?>> {
        val reminders = rawReminders.mapIndexed { index, rawReminder ->
            val hour = (rawReminder["hour"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Reminder[$index] is missing a valid hour.")
            val minute = (rawReminder["minute"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Reminder[$index] is missing a valid minute.")
            val id = (rawReminder["id"] as? Number)?.toInt() ?: (hour * 100 + minute)

            require(hour in 0..23) { "Reminder[$index] hour must be between 0 and 23." }
            require(minute in 0..59) { "Reminder[$index] minute must be between 0 and 59." }

            PrayerReminder(
                id = id,
                hour = hour,
                minute = minute,
                label = rawReminder["label"] as? String ?: "Prayer reminder",
                silenceEngineEnabled = rawReminder["silenceEngineEnabled"] as? Boolean ?: false
            )
        }

        val duplicateIds = reminders.groupBy { it.id }.filterValues { it.size > 1 }.keys
        require(duplicateIds.isEmpty()) {
            "Reminder ids must be unique. Duplicates: ${duplicateIds.joinToString(", ")}"
        }

        cancelScheduledIntents(context, PrayerReminderStore.load(context))
        PrayerReminderStore.save(context, reminders)
        reminders.forEach { scheduleExact(context, it) }

        return reminders.map {
            mapOf(
                "id" to it.id,
                "hour" to it.hour,
                "minute" to it.minute,
                "label" to it.label,
                "silenceEngineEnabled" to it.silenceEngineEnabled
            )
        }
    }

    fun reschedulePersisted(context: Context) {
        PrayerReminderStore.load(context).forEach { scheduleExact(context, it) }
    }

    fun rescheduleOne(context: Context, reminder: PrayerReminder) {
        scheduleExact(context, reminder)
    }

    fun cancelAll(context: Context) {
        cancelScheduledIntents(context, PrayerReminderStore.load(context))
        PrayerReminderStore.save(context, emptyList())
    }

    private fun cancelScheduledIntents(context: Context, reminders: List<PrayerReminder>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        reminders.forEach { reminder ->
            alarmManager.cancel(createPendingIntent(context, reminder))
        }
    }

    private fun scheduleExact(context: Context, reminder: PrayerReminder) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = nextTriggerAtMillis(reminder.hour, reminder.minute)
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            createPendingIntent(context, reminder)
        )
    }

    private fun createPendingIntent(
        context: Context,
        reminder: PrayerReminder
    ): PendingIntent {
        val intent = Intent(context, PrayerReminderReceiver::class.java).apply {
            putExtra(EXTRA_REMINDER_ID, reminder.id)
        }

        return PendingIntent.getBroadcast(
            context,
            reminder.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextTriggerAtMillis(hour: Int, minute: Int): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        return calendar.timeInMillis
    }

    fun reminderIdFromIntent(intent: Intent?): Int {
        return intent?.getIntExtra(EXTRA_REMINDER_ID, -1) ?: -1
    }
}
