package com.holywarrior.silence_of_salah_engine.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.holywarrior.silence_of_salah_engine.EngineLog

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        EngineLog.i("Alarm", "BOOT_COMPLETED received. Restoring persisted alarms.")
        AlarmScheduler.restorePersistedAlarms(context)
    }
}
