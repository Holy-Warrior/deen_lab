package com.holywarrior.silence_of_salah_engine.foreground_service

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog

object WakeLockHelper {
    private const val COMPONENT = "WakeLock"

    private var wakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    fun acquire(context: Context, onTimeout: () -> Unit) {
        if (wakeLock?.isHeld == true) {
            EngineLog.d(COMPONENT, "Acquire skipped because WakeLock is already held.")
            return
        }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "silence_of_salah_engine:wakelock"
        ).apply { acquire() }

        timeoutRunnable?.let(mainHandler::removeCallbacks)
        timeoutRunnable = Runnable {
            EngineLog.w(COMPONENT, "WakeLock timeout elapsed. Routing shutdown through service cleanup.")
            onTimeout()
        }.also { mainHandler.postDelayed(it, Config.WAKE_LOCK_TIMEOUT_MS) }

        EngineLog.i(COMPONENT, "WakeLock acquired for up to ${Config.WAKE_LOCK_TIMEOUT_MS}ms.")
    }

    fun release() {
        timeoutRunnable?.let(mainHandler::removeCallbacks)
        timeoutRunnable = null
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        EngineLog.i(COMPONENT, "WakeLock released.")
    }
}
