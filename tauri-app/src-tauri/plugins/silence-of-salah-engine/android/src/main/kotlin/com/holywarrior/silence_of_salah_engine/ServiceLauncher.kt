package com.holywarrior.silence_of_salah_engine

import android.content.Context
import android.content.Intent
import android.os.Build
import com.holywarrior.silence_of_salah_engine.foreground_service.SilenceOfSalahEngineForegroundService

object ServiceLauncher {
    private const val COMPONENT = "ServiceLauncher"

    fun start(context: Context, reason: String, alarmId: Int? = null) {
        val intent = Intent(context, SilenceOfSalahEngineForegroundService::class.java).apply {
            action = Config.ACTION_START
            putExtra(Config.EXTRA_START_REASON, reason)
            alarmId?.let { putExtra(Config.EXTRA_ALARM_ID, it) }
        }
        EngineLog.i(COMPONENT, "Starting service. reason=$reason alarmId=$alarmId")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    fun stop(context: Context, reason: String) {
        val intent = Intent(context, SilenceOfSalahEngineForegroundService::class.java).apply {
            action = Config.ACTION_STOP
            putExtra(Config.EXTRA_START_REASON, reason)
        }
        EngineLog.i(COMPONENT, "Stopping service. reason=$reason")
        context.startService(intent)
    }

    fun requestWakeLockTimeoutShutdown(context: Context) {
        val intent = Intent(context, SilenceOfSalahEngineForegroundService::class.java).apply {
            action = Config.ACTION_WAKELOCK_TIMEOUT
            putExtra(Config.EXTRA_START_REASON, "WakeLock timed out after ${Config.WAKE_LOCK_TIMEOUT_MS}ms")
        }
        EngineLog.w(COMPONENT, "Requesting service shutdown because WakeLock timeout elapsed.")
        context.startService(intent)
    }
}
