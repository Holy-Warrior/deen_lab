package com.holywarrior.silence_of_salah_engine.task

import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.foreground_service.BaseForegroundTask
import com.holywarrior.silence_of_salah_engine.foreground_service.ForegroundTaskController
import com.holywarrior.silence_of_salah_engine.foreground_service.NotificationController
import com.holywarrior.silence_of_salah_engine.ml_inference.XGBoostInference
import com.holywarrior.silence_of_salah_engine.sensors.SensorsManager
import java.util.concurrent.atomic.AtomicBoolean

class Task : BaseForegroundTask<TaskStateController>() {
    companion object {
        private const val TAG = "Task"
    }

    override val loopIntervalMillis: Long = Config.SENSOR_LOOP_INTERVAL_MS

    private val isInferenceRunning = AtomicBoolean(false)
    private var skippedInferenceCount = 0
    private var lastInferenceStartTime = 0L

    override suspend fun onStart(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: TaskStateController
    ) {
        notificationController
            .setTitle(Config.NOTIFICATION_TITLE)
            .setText(Config.NOTIFICATION_TEXT_RUNNING)
            .update()

        stateController.decisionEngine.prepareFreshSession()
        SensorsManager.start()
        EngineLog.i(TAG, "Task started.")
    }

    override suspend fun onRecover(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: TaskStateController
    ) {
        notificationController
            .setTitle(Config.NOTIFICATION_TITLE)
            .setText(Config.NOTIFICATION_TEXT_RECOVERING)
            .update()

        SensorsManager.start()
        EngineLog.i(TAG, "Task recovered.")
    }

    override suspend fun onLoop(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: TaskStateController
    ) {
        stateController.decisionEngine.checkForDelayedShutdown(taskController)

        val buffer = stateController.sensorBuffer
        val (acc, gyr, mag) = SensorsManager.getLatestMagnitudes()
        buffer.addSample(acc, gyr, mag)

        if (!buffer.isFull()) {
            return
        }

        val now = System.currentTimeMillis()
        if (isInferenceRunning.get()) {
            val elapsed = now - lastInferenceStartTime
            if (elapsed > Config.INFERENCE_TIMEOUT_MS) {
                EngineLog.w(TAG, "Inference watchdog reset triggered after ${elapsed}ms.")
                isInferenceRunning.set(false)
                skippedInferenceCount = 0
            } else {
                skippedInferenceCount++
                return
            }
        }

        if (!isInferenceRunning.compareAndSet(false, true)) {
            skippedInferenceCount++
            return
        }

        lastInferenceStartTime = now

        try {
            if (!XGBoostInference.isLoaded()) {
                EngineLog.w(TAG, "Inference skipped because the model is not loaded.")
                return
            }

            val features = buffer.toFlatArray()
            val prediction = XGBoostInference.predictOrNull(features) ?: return
            val decisionSnapshot = stateController.decisionEngine.handlePrediction(prediction.isNimaz)

            EngineLog.d(
                TAG,
                "Prediction processed. detected=${prediction.isNimaz} label=${prediction.label} probability=${prediction.probability} skips=$skippedInferenceCount decision=$decisionSnapshot"
            )

            notificationController
                .setTitle(Config.NOTIFICATION_TITLE)
                .setText(Config.NOTIFICATION_TEXT_RUNNING)
                .update()

            skippedInferenceCount = 0
            buffer.popHalf()
        } catch (error: Exception) {
            EngineLog.e(TAG, "Task loop failed.", error)
        } finally {
            isInferenceRunning.set(false)
        }
    }

    override suspend fun onDestroy(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: TaskStateController
    ) {
        SensorsManager.stop()
        stateController.sensorBuffer.clear()
        stateController.decisionEngine.restoreAudioIfNeeded()

        notificationController
            .setTitle(Config.NOTIFICATION_TITLE)
            .setText("Service stopped")
            .update()

        EngineLog.i(TAG, "Task destroyed and cleaned up.")
    }
}

class TaskStateController(context: android.content.Context) {
    val sensorBuffer = SensorBuffer(windowSize = Config.SENSOR_WINDOW_SIZE)
    val decisionEngine = MlDecisionEngine(context.applicationContext)
}
