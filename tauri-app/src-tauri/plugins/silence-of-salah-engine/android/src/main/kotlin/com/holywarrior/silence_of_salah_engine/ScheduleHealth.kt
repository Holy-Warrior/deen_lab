package com.holywarrior.silence_of_salah_engine

import android.content.Context
import com.holywarrior.silence_of_salah_engine.alarm.AlarmScheduler
import com.holywarrior.silence_of_salah_engine.alarm.ManualScheduleController
import com.holywarrior.silence_of_salah_engine.permissions.PermissionManager

/**
 * Checks that what the engine believes is armed is actually armed, and repairs
 * it when it is not.
 *
 * This exists because the persisted schedule and AlarmManager drift apart
 * silently. Android drops every one of an app's alarms on a force-stop and on
 * a reboot, and tells nobody; the boot receiver covers the reboot, nothing
 * covers the force-stop. Until now the only thing that noticed was opening the
 * Auto Silent page, which rewrites the schedule unconditionally - so a user who
 * opened the app, looked at prayer times and left still had a feature that
 * could never fire.
 *
 * Repair is deliberately blunt: rather than working out which alarms to fix,
 * it re-arms the whole persisted schedule. Re-arming is idempotent - the same
 * request code with `FLAG_UPDATE_CURRENT` replaces rather than duplicates - so
 * writing all of them costs nothing and cannot half-succeed.
 */
object ScheduleHealth {
    private const val COMPONENT = "Health"

    fun verify(context: Context): Map<String, Any?> {
        val before = EngineStateStore.load(context)

        // Worked out before the repair, because enforceOverdueRestore is about
        // to clear the very fields that prove it happened.
        val stranded = before.audioState == ManagedAudioState.SILENT &&
            before.manualRestoreAtMillis != null &&
            System.currentTimeMillis() >=
            before.manualRestoreAtMillis - Config.MANUAL_RESTORE_TOLERANCE_MS
        val hadPendingSwitch = before.pendingMode != null

        // Hand the ringer back if a silence outlived its deadline, then let a
        // switch that was queued behind that session finally land.
        ManualScheduleController.enforceOverdueRestore(context)
        EngineModeController.applyPendingIfAny(context)

        val mode = EngineStateStore.load(context).mode
        val expected = expectedIds(context, mode)
        val missingBefore = expected - armedIds(context, mode).toSet()

        // The single most consequential thing that can go missing: without it
        // an open window never ends and the phone stays silent indefinitely.
        val restoreLost = EngineStateStore.load(context).activeManualWindowId != null &&
            !ManualScheduleController.hasArmedRestore(context)

        // Reserved for a fault the probe actually caught, so the note shown to
        // the user stays quiet on the ordinary pass where nothing was wrong.
        var repaired = false
        var disarmed = false

        when (mode) {
            // Re-armed every time rather than only when something looks wrong.
            // The probe cannot be trusted to say a schedule is healthy - see
            // AlarmScheduler.armedAlarmIds - and on a real force-stop it says
            // exactly that while AlarmManager holds nothing. Writing regardless
            // costs one idempotent pass and cannot be fooled.
            EngineMode.ML -> if (expected.isNotEmpty()) {
                AlarmScheduler.restorePersistedAlarms(context)
                repaired = missingBefore.isNotEmpty()
            }

            EngineMode.MANUAL -> if (expected.isNotEmpty() || restoreLost) {
                ManualScheduleController.rearm(context)
                repaired = missingBefore.isNotEmpty() || restoreLost
            }

            // The inverse fault: nothing at all should be armed while the
            // feature is off, so anything still pending gets torn down.
            EngineMode.DISABLED -> {
                val stray = AlarmScheduler.armedAlarmIds(context) +
                    ManualScheduleController.armedWindowIds(context)
                if (stray.isNotEmpty()) {
                    AlarmScheduler.disarm(context)
                    ManualScheduleController.disarm(context)
                    disarmed = true
                }
            }
        }

        // Re-probed rather than assumed: a re-arm is skipped outright when the
        // exact-alarm permission has been revoked, and the caller deserves to
        // know the schedule is still broken instead of being told it was fixed.
        // Read it as the weaker claim it is - "nothing is provably missing".
        val missingAfter = expected - armedIds(context, mode).toSet()

        if (repaired || disarmed || stranded || restoreLost) {
            EngineLog.i(
                COMPONENT,
                "Verified schedule. mode=${mode.wire()} missingBefore=${missingBefore.size} " +
                    "missingAfter=${missingAfter.size} repaired=$repaired disarmed=$disarmed " +
                    "strandedSilence=$stranded restoreLost=$restoreLost"
            )
        }

        val permissions = PermissionManager.checkAll(context)

        return mapOf(
            "mode" to mode.wire(),
            "checkedAtMillis" to System.currentTimeMillis(),
            "expected" to expected.size,
            "missingBefore" to missingBefore,
            "missingAfter" to missingAfter,
            "repaired" to repaired,
            "disarmedWhileOff" to disarmed,
            "strandedSilenceRestored" to stranded,
            "restoreAlarmRearmed" to restoreLost,
            "pendingSwitchApplied" to
                (hadPendingSwitch && EngineStateStore.load(context).pendingMode == null),
            "exactAlarmPermission" to permissions.exactAlarm,
            "allPermissionsGranted" to permissions.allGranted(),
            "healthy" to missingAfter.isEmpty()
        )
    }

    /** What the persisted configuration says should currently be armed. */
    private fun expectedIds(context: Context, mode: EngineMode): List<Int> = when (mode) {
        EngineMode.ML -> AlarmScheduler.getAlarms(context).map { it.id }
        EngineMode.MANUAL -> ManualScheduleController.getWindows(context)
            .filter { it.enabled }
            .map { it.id }
        EngineMode.DISABLED -> emptyList()
    }

    private fun armedIds(context: Context, mode: EngineMode): List<Int> = when (mode) {
        EngineMode.ML -> AlarmScheduler.armedAlarmIds(context)
        EngineMode.MANUAL -> ManualScheduleController.armedWindowIds(context)
        EngineMode.DISABLED -> emptyList()
    }
}
