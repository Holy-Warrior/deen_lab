package com.holywarrior.silence_of_salah_engine.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.ServiceLauncher

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val alarmId = intent?.getIntExtra(Config.EXTRA_ALARM_ID, -1) ?: -1
        EngineLog.i("Alarm", "Alarm fired. alarmId=$alarmId")
        if (alarmId >= 0) {
            AlarmScheduler.handleAlarmTrigger(context, alarmId)
        }
        ServiceLauncher.start(context, reason = "alarm:$alarmId", alarmId = alarmId.takeIf { it >= 0 })
    }
}
