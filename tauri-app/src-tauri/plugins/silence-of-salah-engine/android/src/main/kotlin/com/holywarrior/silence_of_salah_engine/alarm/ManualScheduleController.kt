package com.holywarrior.silence_of_salah_engine.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.EngineMode
import com.holywarrior.silence_of_salah_engine.EngineModeController
import com.holywarrior.silence_of_salah_engine.EngineStateStore
import com.holywarrior.silence_of_salah_engine.ManagedAudioState
import com.holywarrior.silence_of_salah_engine.audio.AudioProfileManager
import com.holywarrior.silence_of_salah_engine.foreground_service.NotificationHelper
import com.holywarrior.silence_of_salah_engine.permissions.PermissionManager

/**
 * Clock-driven silencing for `EngineMode.MANUAL`.
 *
 * Deliberately owns no service, no sensors and no model. Two exact alarms per
 * window - one to silence, one to restore - and the ringer change happens
 * inside the broadcast receiver itself, which takes microseconds. Nothing runs
 * between the two alarms, so a full day of windows costs roughly nothing in
 * battery, and there is no inference that can be wrong.
 *
 * The trade is honesty about coverage: the phone is silent for exactly the
 * window that was configured, whether or not anyone is actually praying.
 *
 * ## Restoring is the part that has to be right
 *
 * Failing to silence is a minor annoyance; failing to un-silence means a missed
 * call and a user who turns the feature off for good. So the restore deadline is
 * persisted rather than living only inside a pending alarm, and every entry
 * point into the plugin runs [enforceOverdueRestore] first. Opening the app,
 * rebooting, or the next window firing all recover a silence that was stranded
 * by a force-stop or a cancelled alarm.
 */
object ManualScheduleController {
    private const val COMPONENT = "Manual"

    // ─────────────────────────────────────────────
    // Configuration
    // ─────────────────────────────────────────────

    /** Replaces the whole window set and arms it. Disabled windows are dropped. */
    fun scheduleWindows(context: Context, windows: List<SilenceWindow>): List<SilenceWindow> {
        enforceOverdueRestore(context)
        cancelPendingIntents(context)

        val enabled = windows.filter { it.enabled }
        if (enabled.isEmpty()) {
            EngineStateStore.updateManualWindows(context, emptyList())
            // A window open right now still finishes; only future ones are dropped.
            rearmActiveEnd(context)
            EngineLog.i(COMPONENT, "No enabled manual windows; nothing scheduled.")
            return emptyList()
        }

        ensureExactAlarmCapability(context)
        val stored = EngineStateStore.updateManualWindows(context, enabled).manualWindows
        stored.forEach { scheduleStart(context, it) }
        rearmActiveEnd(context)
        EngineLog.i(COMPONENT, "Scheduled ${stored.size} manual silence window(s).")
        return stored
    }

    fun getWindows(context: Context): List<SilenceWindow> =
        EngineStateStore.load(context).manualWindows

    /**
     * Re-arms whatever is already persisted. Used after a reboot and when the
     * app switches back into manual mode, so the schedule survives without the
     * app having to re-send it.
     */
    fun rearm(context: Context) {
        enforceOverdueRestore(context)

        val windows = getWindows(context)
        if (windows.isEmpty()) {
            EngineLog.d(COMPONENT, "No persisted manual windows to re-arm.")
            return
        }

        if (!PermissionManager.hasExactAlarmPermission(context)) {
            EngineLog.w(COMPONENT, "Skipping manual re-arm because exact alarm permission is missing.")
            return
        }

        windows.forEach { scheduleStart(context, it) }
        rearmActiveEnd(context)
        EngineLog.i(COMPONENT, "Re-armed ${windows.size} manual silence window(s).")
    }

    /**
     * Cancels the alarms but keeps the configuration, so switching modes back
     * and forth does not make the user rebuild their schedule.
     */
    fun disarm(context: Context) {
        cancelPendingIntents(context)
        restoreNow(context, "manual mode disarmed")
    }

    /** The command-level "forget everything": cancel, clear config, hand the ringer back. */
    fun cancelAll(context: Context) {
        cancelPendingIntents(context)
        EngineStateStore.updateManualWindows(context, emptyList())
        restoreNow(context, "manual windows cancelled")
        EngineLog.i(COMPONENT, "Cancelled all manual silence windows.")
    }

    // ─────────────────────────────────────────────
    // Alarm handling
    // ─────────────────────────────────────────────

    /** A start alarm fired: go silent and arm the matching restore. */
    fun enterWindow(context: Context, windowId: Int) {
        // Clears a silence stranded by an earlier window before this one takes
        // ownership, so the ringer mode captured below is the user's own.
        enforceOverdueRestore(context)

        val state = EngineStateStore.load(context)
        if (state.mode != EngineMode.MANUAL) {
            EngineLog.w(COMPONENT, "Ignoring manual start for windowId=$windowId; mode is ${state.mode.wire()}.")
            return
        }

        val window = state.manualWindows.firstOrNull { it.id == windowId }
        if (window == null || !window.enabled) {
            EngineLog.w(COMPONENT, "Ignoring manual start for unknown/disabled windowId=$windowId.")
            return
        }

        // Re-arm for tomorrow first: if anything below throws, the daily repeat
        // still survives rather than the window firing only once.
        scheduleStart(context, window)

        val now = System.currentTimeMillis()
        val endsAt = window.endsAtMillis(now)

        val updated = if (state.audioState == ManagedAudioState.DEFAULT) {
            val originalRingerMode = AudioProfileManager.getCurrentRingerMode(context)
            AudioProfileManager.switchToSilent(context)
            EngineStateStore.update(context) {
                it.copy(
                    originalRingerMode = originalRingerMode,
                    audioState = ManagedAudioState.SILENT,
                    activeManualWindowId = windowId,
                    manualRestoreAtMillis = endsAt
                )
            }
        } else {
            // Already silent because an overlapping window is still open. Keep
            // the later of the two deadlines - whichever window ends last is the
            // one the user asked to be covered by.
            EngineStateStore.update(context) {
                it.copy(
                    manualRestoreAtMillis = maxOf(it.manualRestoreAtMillis ?: endsAt, endsAt)
                )
            }
        }

        val deadline = updated.manualRestoreAtMillis ?: endsAt
        scheduleEnd(context, windowId, deadline)
        NotificationHelper.showManualWindow(context, window.label, deadline)

        EngineLog.i(
            COMPONENT,
            "Entered manual window. id=$windowId label=${window.label} durationMinutes=${window.durationMinutes} restoreAtMillis=$deadline"
        )
    }

    /** An end alarm fired: restore, unless a longer overlapping window is still running. */
    fun exitWindow(context: Context, windowId: Int) {
        val state = EngineStateStore.load(context)
        val deadline = state.manualRestoreAtMillis

        if (state.audioState != ManagedAudioState.SILENT || deadline == null) {
            EngineLog.d(COMPONENT, "Manual end for windowId=$windowId ignored; no manual silence is active.")
            NotificationHelper.clearManualWindow(context)
            return
        }

        val now = System.currentTimeMillis()
        if (now < deadline - Config.MANUAL_RESTORE_TOLERANCE_MS) {
            // A window that opened later runs past this one's end. Push this
            // alarm out to the real deadline instead of cutting the silence short.
            EngineLog.d(COMPONENT, "Manual end for windowId=$windowId deferred to $deadline.")
            scheduleEnd(context, windowId, deadline)
            return
        }

        restoreNow(context, "manual window $windowId ended")
        // The session just ended, which is the moment a deferred mode switch
        // was waiting for.
        EngineModeController.applyPendingIfAny(context)
    }

    /**
     * The safety net. Hands the ringer back if a manual silence outlived its
     * deadline - which happens whenever the restore alarm never got to fire,
     * most commonly because the app was force-stopped (Android cancels every one
     * of an app's alarms when that happens, and tells nobody).
     */
    fun enforceOverdueRestore(context: Context) {
        val state = EngineStateStore.load(context)
        val deadline = state.manualRestoreAtMillis ?: return

        if (state.audioState != ManagedAudioState.SILENT) {
            // Deadline left over from a session that already ended cleanly.
            EngineStateStore.update(context) {
                it.copy(activeManualWindowId = null, manualRestoreAtMillis = null)
            }
            NotificationHelper.clearManualWindow(context)
            return
        }

        if (System.currentTimeMillis() < deadline - Config.MANUAL_RESTORE_TOLERANCE_MS) {
            return
        }

        EngineLog.w(COMPONENT, "Manual silence outlived its deadline ($deadline). Restoring now.")
        restoreNow(context, "overdue manual restore")
        EngineModeController.applyPendingIfAny(context)
    }

    fun activeWindow(context: Context): SilenceWindow? {
        val state = EngineStateStore.load(context)
        val id = state.activeManualWindowId ?: return null
        return state.manualWindows.firstOrNull { it.id == id }
    }

    // ─────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────

    /**
     * Puts back the restore alarm for a window that is open right now.
     *
     * Both callers have just wiped every pending alarm, which would otherwise
     * orphan a silence in progress - rescheduling from the app while praying,
     * or rebooting mid-window, would leave the deadline persisted but nothing
     * armed to act on it. The overdue check would still catch it eventually,
     * but only the next time something asked; this restores on time.
     */
    private fun rearmActiveEnd(context: Context) {
        val state = EngineStateStore.load(context)
        val deadline = state.manualRestoreAtMillis ?: return
        if (state.audioState != ManagedAudioState.SILENT) return

        val windowId = state.activeManualWindowId ?: return
        scheduleEnd(context, windowId, deadline)
        EngineLog.i(COMPONENT, "Re-armed the restore alarm for the open window. id=$windowId at=$deadline")
    }

    private fun restoreNow(context: Context, reason: String) {
        val state = EngineStateStore.load(context)

        // manualRestoreAtMillis is what marks a silence as manual-owned; without
        // that check this could yank the ringer out from under a running ML session.
        if (state.audioState == ManagedAudioState.SILENT && state.manualRestoreAtMillis != null) {
            AudioProfileManager.restoreOriginalProfile(context, state.originalRingerMode)
            EngineLog.i(COMPONENT, "Restored original ringer. reason=$reason")
        }

        if (state.manualRestoreAtMillis != null || state.activeManualWindowId != null) {
            EngineStateStore.update(context) {
                it.copy(
                    audioState = ManagedAudioState.DEFAULT,
                    activeManualWindowId = null,
                    manualRestoreAtMillis = null
                )
            }
        }

        NotificationHelper.clearManualWindow(context)
    }

    private fun scheduleStart(context: Context, window: SilenceWindow) {
        val triggerAtMillis = window.nextTriggerAtMillis()
        setExact(context, triggerAtMillis, startIntent(context, window.id))
        EngineLog.d(COMPONENT, "Manual start scheduled. id=${window.id} at=$triggerAtMillis")
    }

    private fun scheduleEnd(context: Context, windowId: Int, triggerAtMillis: Long) {
        setExact(context, triggerAtMillis, endIntent(context, windowId))
        EngineLog.d(COMPONENT, "Manual end scheduled. id=$windowId at=$triggerAtMillis")
    }

    private fun setExact(context: Context, triggerAtMillis: Long, pendingIntent: PendingIntent) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent
        )
    }

    private fun cancelPendingIntents(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        getWindows(context).forEach { window ->
            alarmManager.cancel(startIntent(context, window.id))
            alarmManager.cancel(endIntent(context, window.id))
        }
    }

    private fun startIntent(context: Context, windowId: Int): PendingIntent =
        broadcast(
            context,
            Config.MANUAL_START_REQUEST_BASE + windowId,
            windowId,
            Config.ALARM_KIND_MANUAL_START
        )

    private fun endIntent(context: Context, windowId: Int): PendingIntent =
        broadcast(
            context,
            Config.MANUAL_END_REQUEST_BASE + windowId,
            windowId,
            Config.ALARM_KIND_MANUAL_END
        )

    private fun broadcast(
        context: Context,
        requestCode: Int,
        windowId: Int,
        kind: String
    ): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(Config.EXTRA_ALARM_ID, windowId)
            putExtra(Config.EXTRA_ALARM_KIND, kind)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureExactAlarmCapability(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !PermissionManager.hasExactAlarmPermission(context)
        ) {
            throw IllegalStateException("Exact alarm permission is required before scheduling silence windows.")
        }
    }
}
