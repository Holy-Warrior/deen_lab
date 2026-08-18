package com.holywarrior.silence_of_salah_engine

import android.app.Activity
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.Plugin

// ─────────────────────────────────────────────
// Invoke argument shapes (Jackson-deserialized from the JS `payload` object)
// ─────────────────────────────────────────────

@InvokeArg
class StartNativeTaskArgs {
    var reason: String? = null
}

@InvokeArg
class ScheduleAlarmArg {
    var id: Int? = null
    var hour: Int = 0
    var minute: Int = 0
    var label: String? = null
    var enabled: Boolean? = null
}

@InvokeArg
class ScheduleDailyAlarmsArgs {
    var alarms: List<ScheduleAlarmArg> = emptyList()
}

@InvokeArg
class TriggerMlProcessingArgs {
    var features: List<Double> = emptyList()
}

@InvokeArg
class SubmitMlDecisionOutputArgs {
    var value: Boolean = false
}

/**
 * Tauri v2 plugin entry point. Every [Command] here is a 1:1 port of the
 * handlers that used to live in `EngineMethodRouter.kt` (Flutter
 * `MethodChannel`) - same error codes, same delegation to
 * [EngineNativeActions], same business logic underneath. Only the transport
 * (Invoke instead of MethodCall/MethodChannel.Result) changed.
 *
 * Unlike the Flutter plugin, Tauri hands us a single, stable [Activity] for
 * the plugin's lifetime, so there's no attach/detach dance needed to build
 * [EngineNativeActions].
 */
@TauriPlugin
class SilenceEnginePlugin(private val activity: Activity) : Plugin(activity) {

    private val actions: EngineNativeActions by lazy {
        EngineNativeActions(activity.applicationContext, activity)
    }

    @Command
    fun getPlatformVersion(invoke: Invoke) {
        runCatching { actions.getPlatformVersion() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "PLATFORM_VERSION_ERROR", it as? Exception) }
    }

    @Command
    fun startNativeTask(invoke: Invoke) {
        runCatching {
            val args = invoke.parseArgs(StartNativeTaskArgs::class.java)
            actions.startNativeTask(mapOf("reason" to args.reason))
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "START_TASK_ERROR", it as? Exception) }
    }

    @Command
    fun stopNativeTask(invoke: Invoke) {
        runCatching {
            actions.stopNativeTask()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "STOP_TASK_ERROR", it as? Exception) }
    }

    @Command
    fun getNativeStatus(invoke: Invoke) {
        runCatching { actions.getNativeStatus() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "STATUS_ERROR", it as? Exception) }
    }

    @Command
    fun scheduleDailyAlarms(invoke: Invoke) {
        runCatching {
            val args = invoke.parseArgs(ScheduleDailyAlarmsArgs::class.java)
            val rawAlarms = args.alarms.map { alarm ->
                mapOf(
                    "id" to alarm.id,
                    "hour" to alarm.hour,
                    "minute" to alarm.minute,
                    "label" to alarm.label,
                    "enabled" to alarm.enabled
                )
            }
            actions.scheduleDailyAlarms(rawAlarms)
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "SCHEDULE_ALARMS_ERROR", it as? Exception) }
    }

    @Command
    fun getScheduledAlarms(invoke: Invoke) {
        runCatching { actions.getScheduledAlarms() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "GET_ALARMS_ERROR", it as? Exception) }
    }

    @Command
    fun cancelAllAlarms(invoke: Invoke) {
        runCatching {
            actions.cancelAllAlarms()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "CANCEL_ALARMS_ERROR", it as? Exception) }
    }

    @Command
    fun triggerMlProcessing(invoke: Invoke) {
        runCatching {
            val args = invoke.parseArgs(TriggerMlProcessingArgs::class.java)
            actions.triggerMlProcessing(args.features)
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "TRIGGER_ML_ERROR", it as? Exception) }
    }

    @Command
    fun submitMlDecisionOutput(invoke: Invoke) {
        runCatching {
            val args = invoke.parseArgs(SubmitMlDecisionOutputArgs::class.java)
            actions.submitMlDecisionOutput(args.value)
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "SUBMIT_ML_OUTPUT_ERROR", it as? Exception) }
    }

    @Command
    fun debugSetAudioSilent(invoke: Invoke) {
        runCatching { actions.debugSetAudioSilent() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "DEBUG_AUDIO_SILENT_ERROR", it as? Exception) }
    }

    @Command
    fun debugRestoreAudioDefault(invoke: Invoke) {
        runCatching { actions.debugRestoreAudioDefault() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "DEBUG_AUDIO_DEFAULT_ERROR", it as? Exception) }
    }

    @Command
    fun getPermissionStatus(invoke: Invoke) {
        runCatching { actions.getPermissionStatus() }
            .onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "PERMISSION_STATUS_ERROR", it as? Exception) }
    }

    @Command
    fun requestExactAlarmPermission(invoke: Invoke) {
        runCatching {
            actions.requestExactAlarmPermission()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "REQUEST_EXACT_ALARM_ERROR", it as? Exception) }
    }

    @Command
    fun requestDndAccess(invoke: Invoke) {
        runCatching {
            actions.requestDndAccess()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "REQUEST_DND_ERROR", it as? Exception) }
    }

    @Command
    fun requestBatteryOptimization(invoke: Invoke) {
        runCatching {
            actions.requestBatteryOptimizationIgnore()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "REQUEST_BATTERY_ERROR", it as? Exception) }
    }

    @Command
    fun requestNotificationPermission(invoke: Invoke) {
        runCatching {
            actions.requestNotificationPermission()
            true
        }.onSuccess { invoke.resolveObject(it) }
            .onFailure { invoke.reject(it.message, "REQUEST_NOTIFICATION_ERROR", it as? Exception) }
    }
}
