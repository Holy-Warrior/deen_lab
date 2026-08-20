package com.holywarrior.silence_of_salah_engine.audio

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import com.holywarrior.silence_of_salah_engine.EngineLog

object AudioProfileManager {
    private const val COMPONENT = "Audio"

    fun isSilent(context: Context): Boolean {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return audioManager.ringerMode == AudioManager.RINGER_MODE_SILENT
    }

    fun getCurrentRingerMode(context: Context): Int {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return audioManager.ringerMode
    }

    fun hasDndAccess(context: Context): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    fun switchToSilent(context: Context) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val currentMode = audioManager.ringerMode

        if (currentMode == AudioManager.RINGER_MODE_SILENT) {
            EngineLog.d(COMPONENT, "Audio already silent. No profile change needed.")
            return
        }

        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        EngineLog.i(COMPONENT, "Audio profile changed to SILENT. previousMode=$currentMode")
    }

    fun restoreOriginalProfile(context: Context, originalRingerMode: Int?) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val previous = originalRingerMode ?: run {
            EngineLog.w(COMPONENT, "Original ringer mode unavailable. Skipping restore.")
            return
        }

        audioManager.ringerMode = previous
        EngineLog.i(COMPONENT, "Audio profile restored to original mode=$previous")
    }
}
