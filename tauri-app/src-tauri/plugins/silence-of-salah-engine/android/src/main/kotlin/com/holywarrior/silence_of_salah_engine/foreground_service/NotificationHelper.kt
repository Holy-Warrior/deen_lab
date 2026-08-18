package com.holywarrior.silence_of_salah_engine.foreground_service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
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
}
