package com.holywarrior.silence_of_salah_engine

import android.app.Activity
import android.content.Context
import android.os.Build
import com.holywarrior.silence_of_salah_engine.alarm.AlarmScheduler
import com.holywarrior.silence_of_salah_engine.alarm.ScheduledAlarm
import com.holywarrior.silence_of_salah_engine.audio.AudioProfileManager
import com.holywarrior.silence_of_salah_engine.foreground_service.SilenceOfSalahEngineForegroundService
import com.holywarrior.silence_of_salah_engine.ml_inference.ModelAssetInstaller
import com.holywarrior.silence_of_salah_engine.ml_inference.XGBoostInference
import com.holywarrior.silence_of_salah_engine.permissions.PermissionManager
import com.holywarrior.silence_of_salah_engine.task.MlDecisionEngine
import com.holywarrior.silence_of_salah_engine.task.Task
import com.holywarrior.silence_of_salah_engine.task.TaskStateController

class EngineNativeActions(
    private val context: Context,
    private val activity: Activity? = null
) {
    private val decisionEngine by lazy { MlDecisionEngine(context.applicationContext) }

    fun getPlatformVersion(): String {
        return "Android ${Build.VERSION.RELEASE}"
    }

    fun startNativeTask(args: Map<*, *>?) {
        EngineLog.d(COMPONENT, "startNativeTask called with args=$args")

        if (SilenceOfSalahEngineForegroundService.isTaskRunning()) {
            EngineLog.d(COMPONENT, "Task start skipped because a task is already active or pending.")
            return
        }

        val task = Task()
        val stateController = TaskStateController(context.applicationContext)

        SilenceOfSalahEngineForegroundService.pendingTask = task
        SilenceOfSalahEngineForegroundService.pendingStateController = stateController

        try {
            ServiceLauncher.start(context, reason = (args?.get("reason") as? String) ?: "tauri")
        } catch (error: Exception) {
            EngineLog.e(COMPONENT, "Failed to start foreground service.", error)
            SilenceOfSalahEngineForegroundService.pendingTask = null
            SilenceOfSalahEngineForegroundService.pendingStateController = null
            throw error
        }
    }

    fun stopNativeTask() {
        EngineLog.d(COMPONENT, "stopNativeTask called")
        SilenceOfSalahEngineForegroundService.clearPendingStart()
        ServiceLauncher.stop(context, reason = "tauri")
    }

    fun getNativeStatus(): Map<String, Any?> {
        val persistentState = EngineStateStore.load(context)
        return mapOf(
            "platformVersion" to getPlatformVersion(),
            "serviceRunning" to SilenceOfSalahEngineForegroundService.isTaskRunning(),
            "modelLoaded" to XGBoostInference.isLoaded(),
            "modelPath" to ModelAssetInstaller.installedModelPath,
            "nativeModelPath" to ModelAssetInstaller.installedNativeModelPath,
            "recentMlOutputs" to persistentState.recentMlOutputs,
            "audioState" to persistentState.audioState.name.lowercase(),
            "currentRingerMode" to AudioProfileManager.getCurrentRingerMode(context),
            "originalRingerMode" to persistentState.originalRingerMode,
            "shutdownDeadlineMillis" to persistentState.shutdownDeadlineMillis,
            "scheduledAlarms" to AlarmScheduler.getAlarms(context).map { it.toMap() },
            "permissions" to getPermissionStatus()
        )
    }

    fun scheduleDailyAlarms(rawAlarms: List<Map<String, Any?>>): List<Map<String, Any?>> {
        val alarms = rawAlarms.mapIndexed { index, rawAlarm ->
            val hour = (rawAlarm["hour"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Alarm[$index] is missing a valid hour.")
            val minute = (rawAlarm["minute"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Alarm[$index] is missing a valid minute.")
            val id = (rawAlarm["id"] as? Number)?.toInt() ?: (hour * 100 + minute)
            require(hour in 0..23) { "Alarm[$index] hour must be between 0 and 23." }
            require(minute in 0..59) { "Alarm[$index] minute must be between 0 and 59." }
            ScheduledAlarm(
                id = id,
                hour = hour,
                minute = minute,
                label = rawAlarm["label"] as? String,
                enabled = rawAlarm["enabled"] as? Boolean ?: true
            )
        }

        val duplicateIds = alarms.groupBy { it.id }.filterValues { it.size > 1 }.keys
        require(duplicateIds.isEmpty()) {
            "Alarm ids must be unique. Duplicates: ${duplicateIds.joinToString(", ")}"
        }

        return AlarmScheduler.scheduleDailyAlarms(context, alarms).map { it.toMap() }
    }

    fun getScheduledAlarms(): List<Map<String, Any?>> {
        return AlarmScheduler.getAlarms(context).map { it.toMap() }
    }

    fun cancelAllAlarms() {
        AlarmScheduler.cancelAll(context)
    }

    fun triggerMlProcessing(features: List<Number>): Map<String, Any?> {
        if (!XGBoostInference.isLoaded()) {
            val modelPath = ModelAssetInstaller.ensureInstalled(context)
            ModelAssetInstaller.loadModel(modelPath)
        }

        val floatFeatures = FloatArray(features.size) { index -> features[index].toFloat() }
        val prediction = XGBoostInference.predictOrNull(floatFeatures)
            ?: throw IllegalStateException("ML inference failed or model is not loaded.")

        val result = mapOf(
            "label" to prediction.label,
            "probability" to prediction.probability.toDouble(),
            "isPrayerDetected" to prediction.isNimaz
        )
        EngineLog.d(COMPONENT, "triggerMlProcessing result=$result")
        return result
    }

    fun submitMlDecisionOutput(value: Boolean): Map<String, Any?> {
        val state = EngineStateStore.load(context)
        if (state.originalRingerMode == null) {
            decisionEngine.prepareFreshSession()
        }
        val snapshot = decisionEngine.handlePrediction(value)
        EngineLog.d(COMPONENT, "submitMlDecisionOutput snapshot=$snapshot")
        return snapshot
    }

    fun debugSetAudioSilent(): Map<String, Any?> {
        val state = EngineStateStore.load(context)
        val originalMode = state.originalRingerMode ?: AudioProfileManager.getCurrentRingerMode(context)
        AudioProfileManager.switchToSilent(context)
        EngineStateStore.update(context) {
            it.copy(
                originalRingerMode = originalMode,
                audioState = ManagedAudioState.SILENT,
                shutdownDeadlineMillis = null
            )
        }
        val snapshot = decisionEngine.snapshot()
        EngineLog.d(COMPONENT, "debugSetAudioSilent snapshot=$snapshot")
        return snapshot
    }

    fun debugRestoreAudioDefault(): Map<String, Any?> {
        val state = EngineStateStore.load(context)
        AudioProfileManager.restoreOriginalProfile(context, state.originalRingerMode)
        EngineStateStore.update(context) {
            it.copy(
                audioState = ManagedAudioState.DEFAULT,
                shutdownDeadlineMillis = null
            )
        }
        val snapshot = decisionEngine.snapshot()
        EngineLog.d(COMPONENT, "debugRestoreAudioDefault snapshot=$snapshot")
        return snapshot
    }

    fun getPermissionStatus(): Map<String, Any> {
        val status = PermissionManager.checkAll(context)

        return mapOf(
            "exactAlarm" to status.exactAlarm,
            "dnd" to status.dnd,
            "batteryOptimization" to status.batteryOptimization,
            "notifications" to status.notifications,
            "allGranted" to status.allGranted()
        )
    }

    fun requestExactAlarmPermission() {
        PermissionManager.requestExactAlarmPermission(context)
    }

    fun requestDndAccess() {
        PermissionManager.requestDndAccess(context)
    }

    fun requestBatteryOptimizationIgnore() {
        PermissionManager.requestIgnoreBatteryOptimizations(context)
    }

    fun requestNotificationPermission() {
        val act = activity ?: return
        PermissionManager.requestNotificationPermission(act, 1001)
    }

    companion object {
        private const val COMPONENT = "NativeActions"
    }
}
