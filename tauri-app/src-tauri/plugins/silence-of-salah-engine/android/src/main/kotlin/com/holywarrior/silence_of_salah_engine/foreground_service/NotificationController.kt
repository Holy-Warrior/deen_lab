package com.holywarrior.silence_of_salah_engine.foreground_service

import android.app.NotificationManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.holywarrior.silence_of_salah_engine.Config

class NotificationController(
    private val context: Context
) {
    private val manager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val builder = NotificationCompat.Builder(
        context,
        NotificationHelper.CHANNEL_ID
    ).apply {
        setContentTitle(Config.NOTIFICATION_TITLE)
        setContentText(Config.NOTIFICATION_TEXT_STARTING)
        setSmallIcon(android.R.drawable.ic_lock_silent_mode)
        setOngoing(true)
        priority = NotificationCompat.PRIORITY_LOW
        setOnlyAlertOnce(true)
        setSilent(true)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastText: String? = null
    private var lastTitle: String? = null

    fun setTitle(title: String): NotificationController {
        if (title != lastTitle) {
            builder.setContentTitle(title)
            lastTitle = title
        }
        return this
    }

    fun setText(text: String): NotificationController {
        if (text != lastText) {
            builder.setContentText(text)
            lastText = text
        }
        return this
    }

    fun update() {
        mainHandler.post {
            manager.notify(NotificationHelper.NOTIFICATION_ID, builder.build())
        }
    }

    fun build() = builder.build()
}
