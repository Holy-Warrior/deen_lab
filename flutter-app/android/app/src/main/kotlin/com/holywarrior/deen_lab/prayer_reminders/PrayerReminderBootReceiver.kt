package com.holywarrior.deen_lab.prayer_reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            PrayerReminderScheduler.reschedulePersisted(context)
        }
    }
}
