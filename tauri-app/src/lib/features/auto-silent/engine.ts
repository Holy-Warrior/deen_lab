import { invoke } from "@tauri-apps/api/core";

// tauri: src-tauri/plugins/silence-of-salah-engine -- vendored in from the standalone
// tauri-plugin-silence-of-salah-engine repo. Android-only: every command compiles everywhere
// but rejects with "unsupported platform" off Android, so callers must tolerate a rejection
// rather than assume the engine exists. Commands are namespaced plugin:<name>|<command>, and
// the ones taking arguments wrap them in a single `payload` object.
const command = (name: string) => `plugin:silence-of-salah-engine|${name}`;

/** `default` = the phone's normal ringer. `silent` = the engine has silenced it. */
export type AudioState = "default" | "silent";

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
    permissions: PermissionStatus;
}

/** Starts the foreground service: sensors, model, and the 100ms inference loop. */
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
