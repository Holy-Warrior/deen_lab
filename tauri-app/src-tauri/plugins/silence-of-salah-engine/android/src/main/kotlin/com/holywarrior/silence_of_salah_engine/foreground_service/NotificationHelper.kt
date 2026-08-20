package com.holywarrior.silence_of_salah_engine.foreground_service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import com.holywarrior.silence_of_salah_engine.Config

object NotificationHelper {
    const val CHANNEL_ID = Config.NOTIFICATION_CHANNEL_ID
    const val NOTIFICATION_ID = Config.NOTIFICATION_ID

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                Config.NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service status"
            }
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * Posted while a manual silence window is open.
     *
     * Not a foreground-service notification - manual mode runs no service at
     * all - so it is dismissible and purely informational. It exists because a
     * phone that silences itself with nothing on screen explaining why reads as
     * a fault rather than a feature, and because it gives the user a visible
     * end time to check against.
     */
    fun showManualWindow(context: Context, label: String?, restoreAtMillis: Long) {
        createChannel(context)

        val until = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(restoreAtMillis))
        val text = if (label.isNullOrBlank()) {
            "Ringer comes back at $until"
        } else {
            "$label - ringer comes back at $until"
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(Config.MANUAL_NOTIFICATION_TITLE)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()

        manager(context).notify(Config.MANUAL_NOTIFICATION_ID, notification)
    }

    fun clearManualWindow(context: Context) {
        manager(context).cancel(Config.MANUAL_NOTIFICATION_ID)
    }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
