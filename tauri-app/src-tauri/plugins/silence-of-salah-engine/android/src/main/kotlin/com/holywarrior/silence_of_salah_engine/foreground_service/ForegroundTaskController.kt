package com.holywarrior.silence_of_salah_engine.foreground_service

import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.ServiceLauncher
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import java.util.concurrent.atomic.AtomicBoolean

class ForegroundTaskController(
    private val service: SilenceOfSalahEngineForegroundService,
    val notification: NotificationController
) {
    private val component = "TaskController"
    private val stopRequested = AtomicBoolean(false)
    private val destroyHandled = AtomicBoolean(false)

    private var job: Job? = null
    private var wakeLockHeld = false
    private var cleanupBlock: (suspend () -> Unit)? = null

    fun attachExecution(job: Job, cleanupBlock: suspend () -> Unit) {
        this.job = job
        this.cleanupBlock = cleanupBlock
        SilenceOfSalahEngineForegroundService.setTaskActive(true)

        job.invokeOnCompletion { throwable ->
            SilenceOfSalahEngineForegroundService.setTaskActive(false)
            if (throwable != null && throwable !is CancellationException) {
                EngineLog.e(component, "Task execution completed with error.", throwable)
            } else {
                EngineLog.d(component, "Task execution completed.")
            }

            if (!stopRequested.get()) {
                requestStop("Task execution completed")
            }
        }
    }

    fun acquireWakeLock() {
        if (wakeLockHeld) {
            return
        }

        WakeLockHelper.acquire(service) {
            ServiceLauncher.requestWakeLockTimeoutShutdown(service)
        }
        wakeLockHeld = true
    }

    fun releaseWakeLockFromServiceDestroy() {
        if (!wakeLockHeld) {
            return
        }
        WakeLockHelper.release()
        wakeLockHeld = false
    }

    fun requestStop(reason: String) {
        if (!stopRequested.compareAndSet(false, true)) {
            return
        }

        EngineLog.i(component, "Stopping task. reason=$reason")
        job?.cancel(CancellationException(reason))
        service.stopSelfSafely()
    }

    fun handleServiceDestroy() {
        if (!destroyHandled.compareAndSet(false, true)) {
            return
        }

        EngineLog.i(component, "Handling service destroy cleanup.")
        job?.cancel()
        cleanupBlock?.let { cleanup ->
            runBlocking { cleanup() }
        }
        cleanupBlock = null
        releaseWakeLockFromServiceDestroy()
        SilenceOfSalahEngineForegroundService.setTaskActive(false)
    }

    fun isActive(): Boolean = job?.isActive == true
}
