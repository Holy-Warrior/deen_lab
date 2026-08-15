export interface PrayerTimes {
    fajr: string;
    sunrise: string;
    dhuhr: string;
    asr: string;
    maghrib: string;
    isha: string;
}

export type PrayerMethod = "1" | "3" | "4";

const dateFormatter = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "numeric",
    year: "numeric"
});

function apiTime(value: unknown): string {
    return String(value ?? "").split(" ")[0];
}

export class PrayerTimeService {
    async load(city: string, country: string, method: PrayerMethod): Promise<PrayerTimes> {
        const today = dateFormatter.format(new Date()).replaceAll("/", "-");
        const url = new URL(`https://api.aladhan.com/v1/timingsByCity/${today}`);
        url.searchParams.set("city", city);
        url.searchParams.set("country", country);
        url.searchParams.set("method", method);

        const controller = new AbortController();
        const timeout = window.setTimeout(() => controller.abort(), 10_000);

        try {
            const response = await fetch(url, { signal: controller.signal });

            if (!response.ok)
                throw new Error("Prayer times are currently unavailable.");

            const payload = await response.json() as { data?: { timings?: Record<string, unknown> } };
            const timings = payload.data?.timings;

            if (!timings)
                throw new Error("Prayer times returned invalid data.");

            return {
                fajr: apiTime(timings.Fajr),
                sunrise: apiTime(timings.Sunrise),
                dhuhr: apiTime(timings.Dhuhr),
                asr: apiTime(timings.Asr),
                maghrib: apiTime(timings.Maghrib),
                isha: apiTime(timings.Isha)
            };
        } catch (error) {
            if (error instanceof DOMException && error.name === "AbortError")
                throw new Error("Prayer times timed out. Please try again.");

            throw error;
        } finally {
            window.clearTimeout(timeout);
        }
    }
}

export const prayerTimeService = new PrayerTimeService();
