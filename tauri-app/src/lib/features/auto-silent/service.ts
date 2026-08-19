import type { PrayerDay, PrayerSlot } from "$lib/features/prayer-times/service";
import type { ScheduleAlarmInput, ScheduledAlarm, SilenceWindowInput } from "./engine";
import { isSilencedPrayer, silencedPrayers, type AutoSilentSettings, type SilencedPrayer } from "./storage";

export interface PlannedWake {
    prayer: SilencedPrayer;
    label: string;
    /** The prayer time as calculated, before this feature touches it. */
    prayerAt: Date;
    /** When the engine will actually start listening: prayerAt + offset - leadMinutes. */
    wakeAt: Date;
}

/**
 * Works out when the engine should wake for each enabled prayer on a given day.
 *
 * Pure on purpose: the page can re-derive the whole plan from (day, settings) on every change
 * and compare it against what is actually scheduled natively, rather than tracking a separate
 * "what did I schedule last time" state that can drift out of sync with reality.
 */
export function planWakes(day: PrayerDay, settings: AutoSilentSettings): PlannedWake[] {
    return day.slots.flatMap((slot: PrayerSlot) => {
        const id = slot.meta.id;
        if (!isSilencedPrayer(id) || !settings.prayers[id]) return [];

        const shift = settings.offsets[id] - settings.leadMinutes;
        const wakeAt = new Date(slot.at.getTime() + shift * 60_000);
        return [{ prayer: id, label: slot.meta.label, prayerAt: slot.at, wakeAt }];
    });
}

export interface PlannedWindow {
    prayer: SilencedPrayer;
    label: string;
    /** The prayer time as calculated, before this feature touches it. */
    prayerAt: Date;
    /** When the phone goes silent: prayerAt + offset. */
    startAt: Date;
    /** When the ringer comes back: startAt + duration. */
    endAt: Date;
    durationMinutes: number;
}

/**
 * The time-mode equivalent of [planWakes]: a fixed silent period per enabled prayer.
 *
 * `leadMinutes` deliberately plays no part here. It exists in detection mode because the service
 * has to already be running before you start moving; a clock-driven window has nothing to warm
 * up, so starting it early would only be silence while you are not yet praying. The offset alone
 * positions the window.
 */
export function planWindows(day: PrayerDay, settings: AutoSilentSettings): PlannedWindow[] {
    return day.slots.flatMap((slot: PrayerSlot) => {
        const id = slot.meta.id;
        if (!isSilencedPrayer(id) || !settings.prayers[id]) return [];

        const durationMinutes = settings.durations[id];
        const startAt = new Date(slot.at.getTime() + settings.offsets[id] * 60_000);
        const endAt = new Date(startAt.getTime() + durationMinutes * 60_000);
        return [{ prayer: id, label: slot.meta.label, prayerAt: slot.at, startAt, endAt, durationMinutes }];
    });
}

/**
 * Turns a plan into the window list the plugin expects.
 *
 * Ids match [alarmsFor] on purpose: they are per-prayer either way, so switching modes reuses the
 * same id for the same prayer rather than leaving a stale entry behind under a different number.
 */
export function windowsFor(windows: PlannedWindow[]): SilenceWindowInput[] {
    return windows.map((window) => ({
        id: silencedPrayers.indexOf(window.prayer) + 1,
        hour: window.startAt.getHours(),
        minute: window.startAt.getMinutes(),
        durationMinutes: window.durationMinutes,
        label: window.label
    }));
}

/**
 * Turns a plan into the alarm list the plugin expects.
 *
 * Alarms are a bare hour and minute repeating daily, so a wake time that has been nudged across
 * midnight simply lands on the neighbouring clock time -- there is no date to get wrong. Ids are
 * fixed per prayer rather than derived from the time, so two prayers pushed onto the same minute
 * by large offsets can't silently collapse into one alarm.
 */
export function alarmsFor(wakes: PlannedWake[]): ScheduleAlarmInput[] {
    return wakes.map((wake) => ({
        id: silencedPrayers.indexOf(wake.prayer) + 1,
        hour: wake.wakeAt.getHours(),
        minute: wake.wakeAt.getMinutes(),
        label: wake.label
    }));
}

/**
 * Which prayer the engine most likely woke for, inferred from the alarms rather than reported.
 *
 * The plugin tells us the service is running but not what started it, so this picks the alarm
 * whose time most recently passed. It is a best guess and is only ever used as a label -- no
 * behaviour depends on getting it right.
 */
export function likelyPrayerLabel(alarms: ScheduledAlarm[], now: Date): string | null {
    const minutesNow = now.getHours() * 60 + now.getMinutes();

    const elapsed = alarms
        .map((alarm) => ({ alarm, since: minutesNow - (alarm.hour * 60 + alarm.minute) }))
        // a negative gap means the alarm is later today, so wrap it to yesterday's firing
        .map((entry) => ({ ...entry, since: entry.since < 0 ? entry.since + 24 * 60 : entry.since }))
        .sort((left, right) => left.since - right.since)[0];

    // beyond a few hours the connection to any prayer is meaningless -- better to say nothing
    return elapsed && elapsed.since <= 180 ? (elapsed.alarm.label ?? null) : null;
}

export function formatClock(date: Date): string {
    return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

/** `mm:ss` for the shutdown countdown; clamps at zero rather than showing negatives. */
export function formatCountdown(millis: number): string {
    const total = Math.max(0, Math.floor(millis / 1000));
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

export function formatOffset(minutes: number): string {
    if (minutes === 0) return "on time";
    return minutes > 0 ? `+${minutes} min` : `${minutes} min`;
}

/** `1 hr 5 min` reads better than `65 min` once a window runs past the hour. */
export function formatDuration(minutes: number): string {
    if (minutes < 60) return `${minutes} min`;
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest === 0 ? `${hours} hr` : `${hours} hr ${rest} min`;
}
