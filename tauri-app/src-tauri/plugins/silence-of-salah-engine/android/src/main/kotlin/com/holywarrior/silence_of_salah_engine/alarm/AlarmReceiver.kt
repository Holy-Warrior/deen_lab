package com.holywarrior.silence_of_salah_engine.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.EngineMode
import com.holywarrior.silence_of_salah_engine.EngineStateStore
import com.holywarrior.silence_of_salah_engine.ServiceLauncher

/**
 * The single landing point for all three kinds of alarm this plugin sets.
 *
 * They are told apart by [Config.EXTRA_ALARM_KIND] rather than by separate
 * receiver classes, because PendingIntent identity ignores extras - what keeps
 * them from overwriting one another is the disjoint request-code ranges in
 * [Config], not the receiver they land in.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val alarmId = intent?.getIntExtra(Config.EXTRA_ALARM_ID, -1) ?: -1
        // Alarms persisted by a build that predates manual mode carry no kind.
        val kind = intent?.getStringExtra(Config.EXTRA_ALARM_KIND) ?: Config.ALARM_KIND_ML_WAKE
        EngineLog.i(COMPONENT, "Alarm fired. kind=$kind alarmId=$alarmId")

        if (alarmId < 0) {
            EngineLog.w(COMPONENT, "Ignoring alarm with no id.")
            return
        }

        when (kind) {
            Config.ALARM_KIND_MANUAL_START -> ManualScheduleController.enterWindow(context, alarmId)
            Config.ALARM_KIND_MANUAL_END -> ManualScheduleController.exitWindow(context, alarmId)
            else -> handleMlWake(context, alarmId)
        }
    }

    private fun handleMlWake(context: Context, alarmId: Int) {
        val mode = EngineStateStore.load(context).mode
        if (mode != EngineMode.ML) {
            // A wake alarm left over from before the user switched modes. It is
            // deliberately not rescheduled - letting it lapse is how it stops.
            EngineLog.w(COMPONENT, "Ignoring ML wake for alarmId=$alarmId; mode is ${mode.wire()}.")
            return
        }

        AlarmScheduler.handleAlarmTrigger(context, alarmId)
        ServiceLauncher.start(context, reason = "alarm:$alarmId", alarmId = alarmId)
    }

    private companion object {
        const val COMPONENT = "Alarm"
    }
}
