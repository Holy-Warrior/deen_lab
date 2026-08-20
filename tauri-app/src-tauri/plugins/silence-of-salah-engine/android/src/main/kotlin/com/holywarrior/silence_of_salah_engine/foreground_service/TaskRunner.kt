package com.holywarrior.silence_of_salah_engine.foreground_service

import com.holywarrior.silence_of_salah_engine.EngineLog
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.coroutines.coroutineContext

object TaskRunner {
    private const val COMPONENT = "TaskRunner"

    fun <T : Any> start(
        controller: ForegroundTaskController,
        task: BaseForegroundTask<T>,
        persistentController: T,
        isRecovery: Boolean = false
    ) {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val job = scope.launch {
            try {
                if (isRecovery) {
                    task.onRecover(controller, controller.notification, persistentController)
                } else {
                    task.onStart(controller, controller.notification, persistentController)
                }

                if (task.loopIntervalMillis > 0) {
                    while (coroutineContext.isActive) {
                        task.onLoop(controller, controller.notification, persistentController)
                        delay(task.loopIntervalMillis)
                    }
                }
            } catch (_: CancellationException) {
                EngineLog.d(COMPONENT, "Task execution cancelled.")
            } catch (error: Exception) {
                EngineLog.e(COMPONENT, "Task execution failed.", error)
            }
        }

        controller.attachExecution(job) {
            task.onDestroy(controller, controller.notification, persistentController)
            scope.coroutineContext.cancel()
        }
    }
}
