import type { PrayerId } from "$lib/features/prayer-times/prayers";

/**
 * The five obligatory prayers, and the only ones this feature schedules. Sunrise and Tahajjud
 * are deliberately absent: sunrise is a boundary rather than a prayer, and Tahajjud is voluntary
 * and happens at an hour where silencing the phone unasked would be its own problem.
 */
export const silencedPrayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const;
export type SilencedPrayer = (typeof silencedPrayers)[number];

export function isSilencedPrayer(id: PrayerId): id is SilencedPrayer {
    return (silencedPrayers as readonly string[]).includes(id);
}

/**
 * Everything the plugin does not already persist itself.
 *
 * Notably absent is the mode. The plugin keeps that in its own state file and acts on it while
 * the app is closed -- alarms fire, the boot receiver re-arms -- so it is the source of truth
 * and this file would only be a second copy to drift out of sync with it.
 */
export interface AutoSilentSettings {
    /** Which of the five to watch for. */
    prayers: Record<SilencedPrayer, boolean>;
    /**
     * How many minutes before the (offset-adjusted) prayer time the engine starts listening.
     * It needs to already be running when you begin, since it detects posture rather than
     * predicting it.
     *
     * Detection mode only. A time-based window has nothing to warm up, so starting it early
     * would just be silence while you are not yet praying.
     */
    leadMinutes: number;
    /**
     * Per-prayer nudge in minutes, applied only to the engine -- never to the times the Prayer
     * Times feature displays. Positive is later.
     *
     * In detection mode it shifts when listening begins; in time mode it is the start of the
     * silence itself, which makes it the "when do I actually start praying" knob in both.
     */
    offsets: Record<SilencedPrayer, number>;
    /**
     * How long the phone stays silent in time mode, per prayer. Unused in detection mode, which
     * works out the end for itself from when you stop moving.
     */
    durations: Record<SilencedPrayer, number>;
}

export const leadMinutesRange = { min: 0, max: 30 } as const;
export const offsetRange = { min: -60, max: 120 } as const;
// upper bound matches the plugin's own MANUAL_WINDOW_MAX_MINUTES, which rejects anything longer
export const durationRange = { min: 1, max: 240 } as const;

/**
 * Long enough for a fard prayer with its sunnah and a congregation, short enough that a phone
 * left silent by a prayer you skipped is not silent for the rest of the hour. Erring long is the
 * safer direction -- ending early means the phone rings mid-prayer, which is the failure this
 * whole feature exists to prevent -- but only slightly, since every minute of it is a minute of
 * missed calls.
 */
const defaultDurationMinutes = 25;

function everyPrayer<T>(value: T): Record<SilencedPrayer, T> {
    return Object.fromEntries(silencedPrayers.map((id) => [id, value])) as Record<SilencedPrayer, T>;
}

export function defaultSettings(): AutoSilentSettings {
    return {
        prayers: everyPrayer(true),
        leadMinutes: 3,
        offsets: everyPrayer(0),
        durations: everyPrayer(defaultDurationMinutes)
    };
}

const settingsKey = "deenlab.auto-silent.settings";

function clamp(value: unknown, min: number, max: number, fallback: number): number {
    if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
    return Math.min(max, Math.max(min, Math.round(value)));
}

/**
 * Reads whatever is on disk back into a fully-formed settings object. Every field is rebuilt
 * from defaults and only overwritten when the stored value is actually the right shape, so a
 * half-written record degrades into sane settings instead of throwing.
 */
function parse(raw: unknown): AutoSilentSettings {
    const settings = defaultSettings();
    if (typeof raw !== "object" || raw === null) return settings;
    const record = raw as Record<string, unknown>;

    settings.leadMinutes = clamp(record.leadMinutes, leadMinutesRange.min, leadMinutesRange.max, settings.leadMinutes);

    const prayers = record.prayers;
    if (typeof prayers === "object" && prayers !== null) {
        for (const id of silencedPrayers) {
            const value = (prayers as Record<string, unknown>)[id];
            if (typeof value === "boolean") settings.prayers[id] = value;
        }
    }

    const offsets = record.offsets;
    if (typeof offsets === "object" && offsets !== null) {
        for (const id of silencedPrayers) {
            settings.offsets[id] = clamp(
                (offsets as Record<string, unknown>)[id], offsetRange.min, offsetRange.max, 0
            );
        }
    }

    const durations = record.durations;
    if (typeof durations === "object" && durations !== null) {
        for (const id of silencedPrayers) {
            settings.durations[id] = clamp(
                (durations as Record<string, unknown>)[id],
                durationRange.min, durationRange.max, defaultDurationMinutes
            );
        }
    }

    return settings;
}

export function loadSettings(): AutoSilentSettings {
    try {
        const raw = localStorage.getItem(settingsKey);
        if (!raw) return defaultSettings();
        return parse(JSON.parse(raw));
    } catch {
        return defaultSettings();
    }
}

export function saveSettings(settings: AutoSilentSettings): boolean {
    try {
        localStorage.setItem(settingsKey, JSON.stringify(settings));
        return true;
    } catch {
        // realistically only a quota error, and losing a preference is not worth interrupting
        // the user over -- the in-memory settings stay correct for this session either way
        return false;
    }
}
