package com.holywarrior.silence_of_salah_engine.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.EngineStateStore
import com.holywarrior.silence_of_salah_engine.permissions.PermissionManager

object AlarmScheduler {
    private const val COMPONENT = "Alarm"

    fun scheduleDailyAlarms(
        context: Context,
        alarms: List<ScheduledAlarm>
    ): List<ScheduledAlarm> {
        if (alarms.isEmpty()) {
            cancelAll(context)
            return emptyList()
        }

        ensureExactAlarmCapability(context)
        cancelAll(context)

        val enabledAlarms = alarms.filter { it.enabled }
        enabledAlarms.forEach { scheduleExact(context, it) }
        EngineStateStore.updateAlarms(context, enabledAlarms)
        EngineLog.i(COMPONENT, "Scheduled ${enabledAlarms.size} daily alarm(s).")
        return enabledAlarms
    }

    fun getAlarms(context: Context): List<ScheduledAlarm> {
        return EngineStateStore.load(context).alarms
    }

    fun restorePersistedAlarms(context: Context) {
        val alarms = getAlarms(context)
        if (alarms.isEmpty()) {
            EngineLog.d(COMPONENT, "No persisted alarms to restore.")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !PermissionManager.hasExactAlarmPermission(context)
        ) {
            EngineLog.w(COMPONENT, "Skipping alarm restore because exact alarm permission is missing.")
            return
        }

        alarms.forEach { scheduleExact(context, it) }
        EngineLog.i(COMPONENT, "Restored ${alarms.size} persisted alarm(s).")
    }

    fun handleAlarmTrigger(context: Context, alarmId: Int) {
        val alarm = getAlarms(context).firstOrNull { it.id == alarmId }
        if (alarm == null) {
            EngineLog.w(COMPONENT, "Ignoring trigger for unknown alarmId=$alarmId")
            return
        }

        EngineLog.i(COMPONENT, "Rescheduling daily alarm after trigger. alarmId=$alarmId")
        scheduleExact(context, alarm)
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        getAlarms(context).forEach { alarm ->
            alarmManager.cancel(createPendingIntent(context, alarm))
        }
        EngineStateStore.updateAlarms(context, emptyList())
        EngineLog.i(COMPONENT, "Cancelled all scheduled alarms.")
    }

    private fun scheduleExact(context: Context, alarm: ScheduledAlarm) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val nextTriggerAtMillis = alarm.nextTriggerAtMillis()
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextTriggerAtMillis,
            createPendingIntent(context, alarm)
        )
        EngineLog.d(
            COMPONENT,
            "Exact alarm scheduled. alarmId=${alarm.id} nextTriggerAtMillis=$nextTriggerAtMillis"
        )
    }

    private fun createPendingIntent(context: Context, alarm: ScheduledAlarm): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(Config.EXTRA_ALARM_ID, alarm.id)
        }
        return PendingIntent.getBroadcast(
            context,
            alarm.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureExactAlarmCapability(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !PermissionManager.hasExactAlarmPermission(context)
        ) {
            throw IllegalStateException("Exact alarm permission is required before scheduling daily alarms.")
        }
    }
}
