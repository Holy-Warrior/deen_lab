import { loadCacheThenNetwork } from "$lib/services/apiCache";
import type { Coordinates } from "$lib/services/location";
import { prayers, type PrayerMeta } from "./prayers";

export interface PrayerSlot { meta: PrayerMeta; at: Date; }
export interface PrayerDay { date: Date; hijri: string; slots: PrayerSlot[]; }

interface TimingsPayload {
    data?: {
        timings?: Record<string, string>;
        date?: {
            gregorian?: { date?: string };
            hijri?: { date?: string; month?: { en?: string }; year?: string };
        };
    };
}

// aladhan sometimes appends the zone, e.g. "18:53 (PKT)" -- same normalisation the
// Sehri & Iftari service does
function normalizedTime(value: unknown) { return String(value ?? "").split(" ")[0]; }

// aladhan's path segment format for a single day's timings
function apiDate(date: Date) {
    const day = String(date.getDate()).padStart(2, "0");
    const month = String(date.getMonth() + 1).padStart(2, "0");
    return `${day}-${month}-${date.getFullYear()}`;
}

function parseDay(payload: TimingsPayload): PrayerDay {
    const data = payload.data ?? {};
    const [day, month, year] = String(data.date?.gregorian?.date ?? "").split("-").map(Number);

    // design: hijri.date is a full "03-03-1448" string, so take just the day number and pair it
    // with the English month name -- "3 Rabi al-awwal 1448" rather than a bare numeric date
    const hijriDay = String(data.date?.hijri?.date ?? "").split("-")[0];
    const hijri = `${hijriDay} ${data.date?.hijri?.month?.en ?? ""} ${data.date?.hijri?.year ?? ""}`.trim();

    const slots = prayers.flatMap((meta) => {
        const [hours, minutes] = normalizedTime(data.timings?.[meta.timingKey]).split(":").map(Number);
        // a missing/malformed timing would otherwise become an Invalid Date and silently sort
        // to the front of the timeline, so drop the slot instead of carrying a broken one
        if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return [];
        return [{ meta, at: new Date(year, month - 1, day, hours, minutes) }];
    });

    return { date: new Date(year, month - 1, day), hijri, slots };
}

export class PrayerTimesService {
    // tauri: cache-then-network via the Rust api_request/get_cached_response commands
    // (docs/backend-api.md), same as every other network call here. Keying by a per-day URL
    // means tomorrow's fetch becomes tomorrow's instant cache hit.
    async day(
        coordinates: Coordinates, method: string, date: Date,
        onCached: (day: PrayerDay) => void
    ): Promise<PrayerDay> {
        const url = new URL(`https://api.aladhan.com/v1/timings/${apiDate(date)}`);
        url.searchParams.set("latitude", coordinates.latitude.toFixed(4));
        url.searchParams.set("longitude", coordinates.longitude.toFixed(4));
        url.searchParams.set("method", method);

        return loadCacheThenNetwork(url.toString(), parseDay, onCached);
    }
}

export const prayerTimesService = new PrayerTimesService();

/**
 * First slot strictly after `now`, across all the days given. Pure, so the card can just
 * re-derive it every tick instead of tracking "which prayer are we on" as its own state.
 *
 * Callers pass today AND tomorrow: after Isha there is nothing left today, and the next slot
 * is tomorrow's Tahajjud a few hours later.
 */
export function nextPrayer(days: PrayerDay[], now: Date): PrayerSlot | null {
    return days
        .flatMap((day) => day.slots)
        .filter((slot) => slot.at.getTime() > now.getTime())
        .sort((left, right) => left.at.getTime() - right.at.getTime())[0] ?? null;
}
