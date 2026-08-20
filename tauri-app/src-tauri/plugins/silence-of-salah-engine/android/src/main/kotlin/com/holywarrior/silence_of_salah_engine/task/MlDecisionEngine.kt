package com.holywarrior.silence_of_salah_engine.task

import android.content.Context
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.EnginePersistentState
import com.holywarrior.silence_of_salah_engine.EngineStateStore
import com.holywarrior.silence_of_salah_engine.ManagedAudioState
import com.holywarrior.silence_of_salah_engine.audio.AudioProfileManager
import com.holywarrior.silence_of_salah_engine.foreground_service.ForegroundTaskController

class MlDecisionEngine(
    private val context: Context
) {
    private val component = "Decision"

    fun prepareFreshSession() {
        val originalRingerMode = AudioProfileManager.getCurrentRingerMode(context)
        EngineStateStore.resetForFreshServiceStart(context, originalRingerMode)
        EngineLog.i(component, "Prepared fresh service session. originalRingerMode=$originalRingerMode")
    }

    fun handlePrediction(isPrayerDetected: Boolean): Map<String, Any?> {
        val stateWithOutput = EngineStateStore.appendMlOutput(context, isPrayerDetected)
        val anyTrue = stateWithOutput.recentMlOutputs.any { it }
        val allTrue = stateWithOutput.recentMlOutputs.size == Config.ML_BUFFER_SIZE &&
            stateWithOutput.recentMlOutputs.all { it }

        EngineLog.d(
            component,
            "ML output=$isPrayerDetected recent=${stateWithOutput.recentMlOutputs} anyTrue=$anyTrue allTrue=$allTrue audioState=${stateWithOutput.audioState}"
        )

        var updatedState = stateWithOutput

        when (stateWithOutput.audioState) {
            ManagedAudioState.DEFAULT -> {
                if (anyTrue) {
                    val shouldGoSilent = if (!stateWithOutput.hasEnteredSilentOnce) allTrue else true
                    if (shouldGoSilent) {
                        AudioProfileManager.switchToSilent(context)
                        updatedState = EngineStateStore.update(context) {
                            it.copy(
                                audioState = ManagedAudioState.SILENT,
                                hasEnteredSilentOnce = true,
                                shutdownDeadlineMillis = null
                            )
                        }
                        EngineLog.i(component, "Transitioned to SILENT state.")
                    } else {
                        EngineLog.d(
                            component,
                            "Silent transition deferred until the first full true buffer is collected."
                        )
                    }
                }
            }

            ManagedAudioState.SILENT -> {
                if (!anyTrue) {
                    AudioProfileManager.restoreOriginalProfile(context, stateWithOutput.originalRingerMode)
                    updatedState = EngineStateStore.update(context) {
                        it.copy(
                            audioState = ManagedAudioState.DEFAULT,
                            shutdownDeadlineMillis = System.currentTimeMillis() + Config.SHUTDOWN_DELAY_MS
                        )
                    }
                    EngineLog.i(
                        component,
                        "Transitioned to DEFAULT state. shutdownDeadlineMillis=${updatedState.shutdownDeadlineMillis}"
                    )
                } else if (stateWithOutput.shutdownDeadlineMillis != null) {
                    updatedState = EngineStateStore.update(context) {
                        it.copy(shutdownDeadlineMillis = null)
                    }
                    EngineLog.d(component, "Cleared pending shutdown deadline because prayer detection resumed.")
                }
            }
        }

        return snapshot(updatedState)
    }

    fun checkForDelayedShutdown(taskController: ForegroundTaskController) {
        val state = EngineStateStore.load(context)
        val deadline = state.shutdownDeadlineMillis ?: return
        if (state.audioState == ManagedAudioState.DEFAULT && System.currentTimeMillis() >= deadline) {
            EngineLog.i(component, "Shutdown delay elapsed. Stopping service.")
            taskController.requestStop("Shutdown delay elapsed after silent -> default transition")
        }
    }

    fun restoreAudioIfNeeded() {
        val state = EngineStateStore.load(context)
        if (state.audioState == ManagedAudioState.SILENT) {
            AudioProfileManager.restoreOriginalProfile(context, state.originalRingerMode)
            EngineLog.i(component, "Restored original audio profile during service cleanup.")
        }
        EngineStateStore.update(context) {
            it.copy(
                audioState = ManagedAudioState.DEFAULT,
                shutdownDeadlineMillis = null
            )
        }
    }

    fun snapshot(): Map<String, Any?> = snapshot(EngineStateStore.load(context))

    private fun snapshot(state: EnginePersistentState): Map<String, Any?> {
        return mapOf(
            "recentMlOutputs" to state.recentMlOutputs,
            "audioState" to state.audioState.name.lowercase(),
            "originalRingerMode" to state.originalRingerMode,
            "hasEnteredSilentOnce" to state.hasEnteredSilentOnce,
            "shutdownDeadlineMillis" to state.shutdownDeadlineMillis
        )
    }
}
