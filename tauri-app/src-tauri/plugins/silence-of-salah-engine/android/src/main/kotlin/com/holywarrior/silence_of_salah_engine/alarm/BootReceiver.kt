package com.holywarrior.silence_of_salah_engine.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.EngineMode
import com.holywarrior.silence_of_salah_engine.EngineStateStore

/**
 * A reboot clears every pending alarm, so whichever mode is active has to be
 * armed again from what was persisted.
 *
 * The overdue-restore check runs first and matters most: if the phone was
 * silenced by a manual window and then rebooted before the restore alarm could
 * fire, that alarm is gone and nothing else would ever hand the ringer back.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        ManualScheduleController.enforceOverdueRestore(context)

        when (val mode = EngineStateStore.load(context).mode) {
            EngineMode.ML -> {
                EngineLog.i(COMPONENT, "BOOT_COMPLETED received. Restoring persisted ML alarms.")
                AlarmScheduler.restorePersistedAlarms(context)
            }

            EngineMode.MANUAL -> {
                EngineLog.i(COMPONENT, "BOOT_COMPLETED received. Re-arming manual silence windows.")
                ManualScheduleController.rearm(context)
            }

            EngineMode.DISABLED -> {
                EngineLog.i(COMPONENT, "BOOT_COMPLETED received but mode is ${mode.wire()}. Nothing to arm.")
            }
        }
    }

    private companion object {
        const val COMPONENT = "Alarm"
    }
}
