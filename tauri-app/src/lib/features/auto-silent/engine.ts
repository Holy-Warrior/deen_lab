import { invoke } from "@tauri-apps/api/core";

// tauri: src-tauri/plugins/silence-of-salah-engine -- vendored in from the standalone
// tauri-plugin-silence-of-salah-engine repo. Android-only: every command compiles everywhere
// but rejects with "unsupported platform" off Android, so callers must tolerate a rejection
// rather than assume the engine exists. Commands are namespaced plugin:<name>|<command>, and
// the ones taking arguments wrap them in a single `payload` object.
const command = (name: string) => `plugin:silence-of-salah-engine|${name}`;

/** `default` = the phone's normal ringer. `silent` = the engine has silenced it. */
export type AudioState = "default" | "silent";

/**
 * Which of the plugin's two ways of deciding is armed.
 *
 * `ml` watches the motion sensors and lets the model decide -- accurate when it works, but it
 * can miss a prayer or misfire on stillness. `manual` ignores all of that and silences on the
 * clock for a fixed window. They are mutually exclusive natively: both write the same persisted
 * audio state, so running them together would mean two owners fighting over the ringer.
 *
 * Defaults to `ml` on a device that has never been told otherwise.
 */
export type EngineMode = "disabled" | "manual" | "ml";

/**
 * When a mode switch should take effect.
 *
 * Switching tears the outgoing mode down, and if that mode is holding the ringer silent at the
 * time, tearing it down means the phone starts ringing -- possibly mid-prayer, which is the one
 * thing this feature exists to prevent. So the caller says what should happen instead.
 *
 * `ifIdle` is the default: it refuses rather than interrupting, and hands back the session that
 * blocked it so the page can ask the user which they would rather do.
 */
export type ModeSwitchPolicy = "ifIdle" | "immediate" | "afterCurrentSession";

/** What the engine is busy doing right now. Null when it is idle. */
export interface ActiveSession {
    kind: EngineMode;
    /** The ringer is being held silent at this moment -- the difference between
     *  "your phone is silent right now" and "Auto Silent is listening". */
    silencing: boolean;
    /** Which prayer. Always null in ML mode: nothing records what started the service, and the
     *  plugin reports nothing rather than guessing. */
    label: string | null;
    endsAtMillis: number | null;
}

export interface ModeStatus {
    mode: EngineMode;
    /** A switch waiting for the active session to end. Null when nothing is queued. */
    pendingMode: EngineMode | null;
    activeSession: ActiveSession | null;
}

export interface ModeSwitchOutcome {
    /** Whether the requested mode is in effect now. */
    applied: boolean;
    status: ModeStatus;
}

/**
 * One clock-driven silence period for manual mode.
 *
 * `hour`/`minute` is the *resolved* start, offset already applied -- the plugin has no location
 * and no calendar, so it cannot work out when Asr is. That arithmetic stays in `service.ts`,
 * exactly as it already does for the wake alarms.
 */
export interface SilenceWindowInput {
    /** Defaults to `hour * 100 + minute` natively when omitted. Keep it stable per prayer. */
    id?: number;
    hour: number;
    minute: number;
    /** How long to stay silent, 1-240. Defaults to 30 natively when omitted. */
    durationMinutes?: number;
    label?: string;
}

export interface SilenceWindow {
    id: number;
    hour: number;
    minute: number;
    durationMinutes: number;
    label?: string | null;
    enabled: boolean;
    nextTriggerAtMillis: number;
    repeatDaily: boolean;
}

export interface ScheduleAlarmInput {
    /** Defaults to `hour * 100 + minute` natively when omitted. */
    id?: number;
    hour: number;
    minute: number;
    label?: string;
}

export interface ScheduledAlarm {
    id: number;
    hour: number;
    minute: number;
    label?: string | null;
    enabled: boolean;
    nextTriggerAtMillis: number;
    repeatDaily: boolean;
}

export interface PermissionStatus {
    exactAlarm: boolean;
    dnd: boolean;
    batteryOptimization: boolean;
    notifications: boolean;
    allGranted: boolean;
}

export interface NativeStatus {
    platformVersion: string;
    serviceRunning: boolean;
    modelLoaded: boolean;
    /** Rolling window of the last five ML verdicts; drives the hysteresis below. */
    recentMlOutputs: boolean[];
    audioState: AudioState;
    currentRingerMode: number;
    originalRingerMode: number | null;
    /**
     * When the engine has stopped seeing prayer posture it sets a shutdown deadline rather than
     * stopping immediately, so a pause mid-prayer doesn't un-silence the phone. Null whenever no
     * shutdown is pending.
     */
    shutdownDeadlineMillis: number | null;
    scheduledAlarms: ScheduledAlarm[];
    mode: EngineMode;
    manualWindows: SilenceWindow[];
    /** Which window opened the silence currently in effect. A label only -- nothing depends on it. */
    activeManualWindowId: number | null;
    /** When manual mode will hand the ringer back. Null whenever nothing is silenced. */
    manualRestoreAtMillis: number | null;
    pendingMode: EngineMode | null;
    activeSession: ActiveSession | null;
    permissions: PermissionStatus;
}

/**
 * Starts the foreground service: sensors, model, and the 100ms inference loop.
 *
 * Rejects unless the engine is in `ml` mode -- the sensor service and manual mode both own the
 * same ringer state natively, so the plugin refuses rather than letting them collide.
 */
export function startEngine(reason: string): Promise<boolean> {
    return invoke(command("start_native_task"), { payload: { reason } });
}

/** Stops the service and restores the original ringer mode if it had been changed. */
export function stopEngine(): Promise<boolean> {
    return invoke(command("stop_native_task"));
}

export function engineStatus(): Promise<NativeStatus> {
    return invoke(command("get_native_status"));
}

/**
 * Replaces every scheduled alarm with this list -- there is no incremental add or remove, so
 * callers always send the complete set. Passing an empty list cancels everything.
 *
 * These are the plugin's own alarms, not app-managed ones: it owns the AlarmManager entries and
 * a BOOT_COMPLETED receiver, so they survive a reboot without the app having to re-arm them.
 */
export function scheduleDailyAlarms(alarms: ScheduleAlarmInput[]): Promise<ScheduledAlarm[]> {
    return invoke(command("schedule_daily_alarms"), { payload: { alarms } });
}

export function cancelAllAlarms(): Promise<boolean> {
    return invoke(command("cancel_all_alarms"));
}

export function engineMode(): Promise<ModeStatus> {
    return invoke(command("get_engine_mode"));
}

/**
 * Switches modes. The outgoing one is torn down -- service stopped, alarms cancelled, any
 * silence it owned undone -- and the incoming one is armed from what the plugin already has
 * stored. Neither schedule is cleared, so this is a toggle rather than a reset.
 *
 * A blocked switch is not a rejection: it resolves with `applied: false` and the session that
 * blocked it in `status.activeSession`, which is what the page needs to offer "switch now" or
 * "after this prayer". Re-requesting the mode already in effect cancels a queued switch.
 */
export function setEngineMode(
    mode: EngineMode,
    policy: ModeSwitchPolicy = "ifIdle"
): Promise<ModeSwitchOutcome> {
    return invoke(command("set_engine_mode"), { payload: { mode, policy } });
}

/**
 * Replaces every manual silence window with this list, same all-or-nothing contract as
 * scheduleDailyAlarms. An empty list cancels the lot.
 *
 * Scheduling windows does not by itself switch modes -- call setEngineMode("manual") for that.
 */
export function scheduleManualWindows(windows: SilenceWindowInput[]): Promise<SilenceWindow[]> {
    return invoke(command("schedule_manual_windows"), { payload: { windows } });
}

/** Cancels every window, forgets the schedule, and hands the ringer back. */
export function cancelManualWindows(): Promise<boolean> {
    return invoke(command("cancel_manual_windows"));
}

export function permissionStatus(): Promise<PermissionStatus> {
    return invoke(command("get_permission_status"));
}

// design: each of these opens a system settings screen and resolves immediately -- Android gives
// no callback for the user's answer, so nothing here tells you whether permission was granted.
// The only way to find out is to poll permissionStatus() again once the app is back in focus.
export function requestExactAlarm(): Promise<boolean> {
    return invoke(command("request_exact_alarm_permission"));
}

export function requestDnd(): Promise<boolean> {
    return invoke(command("request_dnd_access"));
}

export function requestBatteryOptimization(): Promise<boolean> {
    return invoke(command("request_battery_optimization"));
}

export function requestNotifications(): Promise<boolean> {
    return invoke(command("request_notification_permission"));
}

// design: these two bypass the ML decision engine entirely and force the ringer. They exist so
// the whole chain (DND access -> ringer control -> restore) can be proven in a few seconds,
// rather than only ever being exercised by actually standing up to pray.
export function forceSilent(): Promise<unknown> {
    return invoke(command("debug_set_audio_silent"));
}

export function forceRestore(): Promise<unknown> {
    return invoke(command("debug_restore_audio_default"));
}
