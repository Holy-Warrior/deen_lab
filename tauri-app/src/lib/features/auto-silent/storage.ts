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

export interface AutoSilentSettings {
    /** Master switch. Off means no alarms are scheduled at all. */
    enabled: boolean;
    /** Which of the five to watch for. */
    prayers: Record<SilencedPrayer, boolean>;
    /**
     * How many minutes before the (offset-adjusted) prayer time the engine starts listening.
     * It needs to already be running when you begin, since it detects posture rather than
     * predicting it.
     */
    leadMinutes: number;
    /**
     * Per-prayer nudge in minutes, applied only to when the engine wakes up -- never to the
     * times the Prayer Times feature displays. Positive is later.
     */
    offsets: Record<SilencedPrayer, number>;
}

export const leadMinutesRange = { min: 0, max: 30 } as const;
export const offsetRange = { min: -60, max: 120 } as const;

function everyPrayer<T>(value: T): Record<SilencedPrayer, T> {
    return Object.fromEntries(silencedPrayers.map((id) => [id, value])) as Record<SilencedPrayer, T>;
}

export function defaultSettings(): AutoSilentSettings {
    return {
        enabled: false,
        prayers: everyPrayer(true),
        leadMinutes: 3,
        offsets: everyPrayer(0)
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
 * half-written or older record degrades into sane settings instead of throwing.
 */
function parse(raw: unknown): AutoSilentSettings {
    const settings = defaultSettings();
    if (typeof raw !== "object" || raw === null) return settings;
    const record = raw as Record<string, unknown>;

    if (typeof record.enabled === "boolean") settings.enabled = record.enabled;
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
