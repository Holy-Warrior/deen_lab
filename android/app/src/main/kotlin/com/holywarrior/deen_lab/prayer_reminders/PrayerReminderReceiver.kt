package com.holywarrior.deen_lab.prayer_reminders

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.holywarrior.deen_lab.MainActivity
import com.holywarrior.silence_of_salah_engine.ServiceLauncher

class PrayerReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val reminderId = PrayerReminderScheduler.reminderIdFromIntent(intent)
        val reminder = PrayerReminderStore.find(context, reminderId) ?: return

        showReminderNotification(context, reminder)

        if (reminder.silenceEngineEnabled) {
            ServiceLauncher.start(
                context,
                reason = "prayer_reminder:${reminder.id}",
                alarmId = reminder.id
            )
        }

        PrayerReminderScheduler.rescheduleOne(context, reminder)
    }

    private fun showReminderNotification(context: Context, reminder: PrayerReminder) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ensureChannel(context)

        val launchIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            reminder.id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setContentTitle(reminder.label)
            .setContentText("About 3 minutes are left. Prepare for salah.")
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(reminder.id, notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Reminders before selected salah timings."
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "deen_lab_prayer_reminders"
    }
}
