package com.holywarrior.silence_of_salah_engine

import android.content.Context
import com.holywarrior.silence_of_salah_engine.alarm.AlarmScheduler
import com.holywarrior.silence_of_salah_engine.alarm.ManualScheduleController
import com.holywarrior.silence_of_salah_engine.foreground_service.SilenceOfSalahEngineForegroundService

/**
 * When a mode switch should take effect.
 *
 * Switching modes tears the outgoing one down, and if it happens to be holding
 * the ringer silent at that moment, tearing it down means the phone starts
 * ringing - possibly mid-prayer, which is the one thing this whole plugin
 * exists to prevent. So the caller has to say what it wants to happen instead.
 */
enum class ModeSwitchPolicy(val wire: String) {
    /**
     * Switch only if nothing is in session; otherwise report what is running and
     * change nothing. The default, because refusing is recoverable and yanking
     * the ringer is not.
     */
    IF_IDLE("ifIdle"),

    /** Switch now regardless, ending whatever is running and restoring the ringer. */
    IMMEDIATE("immediate"),

    /** Leave the current session alone and switch the moment it finishes. */
    AFTER_CURRENT_SESSION("afterCurrentSession");

    companion object {
        val DEFAULT = IF_IDLE

        fun fromWire(value: String?): ModeSwitchPolicy {
            if (value.isNullOrBlank()) return DEFAULT
            return values().firstOrNull { it.wire.equals(value, ignoreCase = true) }
                ?: throw IllegalArgumentException(
                    "Unknown mode switch policy \"$value\". Expected one of: ${values().joinToString(", ") { it.wire }}."
                )
        }
    }
}

/**
 * What the engine is busy doing right now, if anything.
 *
 * This is the thing a mode switch has to be careful of, and the thing a UI needs
 * in order to word its prompt: [silencing] is the difference between "your phone
 * is silent right now" and "Auto Silent is listening".
 */
data class ActiveSession(
    /** Which mode owns the session. */
    val kind: EngineMode,
    /** The ringer is being held silent at this moment. */
    val silencing: Boolean,
    /**
     * Which prayer, when the plugin knows. Manual mode does; ML mode does not -
     * nothing records what started the service, so this is null there rather
     * than a guess.
     */
    val label: String?,
    /** When the session is expected to end, when that is known. */
    val endsAtMillis: Long?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "kind" to kind.wire(),
        "silencing" to silencing,
        "label" to label,
        "endsAtMillis" to endsAtMillis
    )
}

/**
 * Owns the mode itself: what is active, what is queued, and the teardown/arm
 * dance of moving between them.
 *
 * Separate from [EngineNativeActions] because the foreground service has to
 * apply a deferred switch when it shuts down, and it has no Activity to build
 * that class around.
 */
object EngineModeController {
    private const val COMPONENT = "Mode"

    // ─────────────────────────────────────────────
    // Reading
    // ─────────────────────────────────────────────

    fun current(context: Context): EngineMode = EngineStateStore.load(context).mode

    fun activeSession(context: Context): ActiveSession? {
        val state = EngineStateStore.load(context)
        val silencing = state.audioState == ManagedAudioState.SILENT

        return when (state.mode) {
            // A manual session is defined by owing the ringer back, which is
            // exactly the condition that makes interrupting it harmful.
            EngineMode.MANUAL -> {
                val deadline = state.manualRestoreAtMillis ?: return null
                if (!silencing) return null
                val label = state.manualWindows
                    .firstOrNull { it.id == state.activeManualWindowId }
                    ?.label
                ActiveSession(EngineMode.MANUAL, silencing = true, label = label, endsAtMillis = deadline)
            }

            // The ML service counts as busy even before it has silenced anything:
            // it only runs because a prayer window is open, and cutting it short
            // wastes the wake for the rest of the day.
            EngineMode.ML -> {
                if (!SilenceOfSalahEngineForegroundService.isTaskRunning()) return null
                ActiveSession(
                    EngineMode.ML,
                    silencing = silencing,
                    label = null,
                    endsAtMillis = state.shutdownDeadlineMillis
                )
            }

            EngineMode.DISABLED -> null
        }
    }

    fun status(context: Context): Map<String, Any?> {
        val state = EngineStateStore.load(context)
        return mapOf(
            "mode" to state.mode.wire(),
            "pendingMode" to state.pendingMode?.wire(),
            "activeSession" to activeSession(context)?.toMap()
        )
    }

    // ─────────────────────────────────────────────
    // Switching
    // ─────────────────────────────────────────────

    /**
     * Handles a mode-switch request according to [policy] and reports what
     * actually happened.
     *
     * Never rejects: a blocked switch comes back as `applied = false` with the
     * session that blocked it attached, because that is what a UI needs in order
     * to ask the user which they would prefer. An error would only tell the
     * caller that something went wrong, not what to offer next.
     */
    fun request(context: Context, mode: EngineMode, policy: ModeSwitchPolicy): Map<String, Any?> {
        // Any explicit request supersedes one that was queued earlier, so
        // re-selecting the mode already in effect is how a UI cancels a pending
        // switch without needing a command of its own.
        clearPending(context)

        val current = current(context)
        val session = activeSession(context)

        if (mode == current) {
            // Re-arming is what this would otherwise do, and re-arming ML means
            // stopping the service - not something to do to a live session.
            if (session == null) {
                apply(context, mode)
            } else {
                EngineLog.i(COMPONENT, "Mode is already ${mode.wire()}; left the running session alone.")
            }
            return outcome(context, applied = true)
        }

        if (session == null || policy == ModeSwitchPolicy.IMMEDIATE) {
            apply(context, mode)
            return outcome(context, applied = true)
        }

        if (policy == ModeSwitchPolicy.AFTER_CURRENT_SESSION) {
            EngineStateStore.update(context) { it.copy(pendingMode = mode) }
            EngineLog.i(
                COMPONENT,
                "Deferred switch to ${mode.wire()} until the current ${session.kind.wire()} session ends."
            )
            return outcome(context, applied = false)
        }

        EngineLog.i(
            COMPONENT,
            "Refused to switch to ${mode.wire()}: a ${session.kind.wire()} session is active (silencing=${session.silencing})."
        )
        return outcome(context, applied = false)
    }

    /**
     * Applies a switch that was deferred, once the session it was waiting on has
     * finished. Called from every point where a session can end - the manual
     * restore paths, the foreground service's teardown, and a status read as a
     * catch-up.
     *
     * Safe to call at any time: it does nothing unless a switch is queued *and*
     * the engine is genuinely idle.
     */
    fun applyPendingIfAny(context: Context) {
        val pending = EngineStateStore.load(context).pendingMode ?: return

        if (activeSession(context) != null) {
            EngineLog.d(COMPONENT, "Pending switch to ${pending.wire()} still waiting; a session is running.")
            return
        }

        // Cleared before applying, so the teardown below - which can reach back
        // here through the service shutting down - finds nothing left to do.
        clearPending(context)
        EngineLog.i(COMPONENT, "Applying the deferred switch to ${pending.wire()}.")
        apply(context, pending)
    }

    private fun clearPending(context: Context) {
        if (EngineStateStore.load(context).pendingMode != null) {
            EngineStateStore.update(context) { it.copy(pendingMode = null) }
        }
    }

    /**
     * The switch itself: tear the outgoing mode down, then arm the incoming one
     * from whatever is already persisted.
     *
     * Neither schedule is cleared, only disarmed, so moving between modes is a
     * toggle rather than a reset.
     */
    private fun apply(context: Context, mode: EngineMode) {
        val current = current(context)

        if (current == EngineMode.ML) {
            // Guarded so a switch applied from inside the service's own teardown
            // does not try to stop a service that is already going away.
            if (SilenceOfSalahEngineForegroundService.isTaskRunning()) {
                SilenceOfSalahEngineForegroundService.clearPendingStart()
                ServiceLauncher.stop(context, reason = "mode switch to ${mode.wire()}")
            }
            AlarmScheduler.disarm(context)
        }
        if (current == EngineMode.MANUAL) {
            ManualScheduleController.disarm(context)
        }

        EngineStateStore.setMode(context, mode)

        when (mode) {
            EngineMode.ML -> AlarmScheduler.restorePersistedAlarms(context)
            EngineMode.MANUAL -> ManualScheduleController.rearm(context)
            EngineMode.DISABLED -> EngineLog.i(COMPONENT, "Engine disabled. Nothing armed.")
        }

        EngineLog.i(COMPONENT, "Engine mode set. from=${current.wire()} to=${mode.wire()}")
    }

    private fun outcome(context: Context, applied: Boolean): Map<String, Any?> =
        mapOf("applied" to applied, "status" to status(context))
}
