import { loadCacheThenNetwork } from "$lib/services/apiCache";

export interface FastingDay { date: Date; weekday: string; hijri: string; imsak: string; fajr: string; maghrib: string; }

function normalizedTime(value: unknown) { return String(value ?? "").split(" ")[0]; }

function parseDay(value: Record<string, any>): FastingDay {
    const gregorian = value.date?.gregorian;
    const [day, month, year] = String(gregorian?.date ?? "").split("-").map(Number);
    return {
        date: new Date(year, month - 1, day),
        weekday: String(gregorian?.weekday?.en ?? ""),
        hijri: `${value.date?.hijri?.date ?? ""} ${value.date?.hijri?.month?.en ?? ""}`.trim(),
        imsak: normalizedTime(value.timings?.Imsak),
        fajr: normalizedTime(value.timings?.Fajr),
        maghrib: normalizedTime(value.timings?.Maghrib)
    };
}

function parseMonth(payload: { data?: Array<Record<string, any>> }): FastingDay[] {
    return (payload.data ?? []).map(parseDay);
}

export class SehriIftariService {
    // tauri: cache-then-network via the Rust api_request/get_cached_response commands
    // (docs/backend-api.md) instead of a raw fetch() -- onCached paints instantly from
    // disk if this exact URL was cached before, then the real network request always
    // still runs too and its result (or error) is what this method resolves/rejects with
    async month(
        city: string, country: string, method: string, date: Date,
        onCached: (days: FastingDay[]) => void
    ): Promise<FastingDay[]> {
        const url = new URL(`https://api.aladhan.com/v1/calendarByCity/${date.getFullYear()}/${date.getMonth() + 1}`);
        url.searchParams.set("city", city);
        url.searchParams.set("country", country);
        url.searchParams.set("method", method);

        return loadCacheThenNetwork(url.toString(), parseMonth, onCached);
    }
}

export const sehriIftariService = new SehriIftariService();
