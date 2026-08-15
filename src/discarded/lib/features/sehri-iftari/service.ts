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

export class SehriIftariService {
    async month(city: string, country: string, method: string, date: Date): Promise<FastingDay[]> {
        const url = new URL(`https://api.aladhan.com/v1/calendarByCity/${date.getFullYear()}/${date.getMonth() + 1}`);
        url.searchParams.set("city", city);
        url.searchParams.set("country", country);
        url.searchParams.set("method", method);
        const response = await fetch(url);
        if (!response.ok) throw new Error("The Sehri and Iftari calendar is currently unavailable.");
        const payload = await response.json() as { data?: Array<Record<string, any>> };
        return (payload.data ?? []).map(parseDay);
    }
}

export const sehriIftariService = new SehriIftariService();
