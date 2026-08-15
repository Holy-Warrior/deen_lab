import type { Ayah, Surah } from "./models";

const apiBaseUrl = "https://api.alquran.cloud/v1";

async function fetchJson(path: string): Promise<unknown> {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 10_000);

    try {
        const response = await fetch(`${apiBaseUrl}${path}`, { signal: controller.signal });

        if (!response.ok)
            throw new Error("The Quran service is currently unavailable.");

        return response.json();
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError")
            throw new Error("The Quran service timed out. Please try again.");

        throw error;
    } finally {
        window.clearTimeout(timeout);
    }
}

export class QuranService {
    async surahs(): Promise<Surah[]> {
        const response = await fetchJson("/surah") as { data?: Array<Record<string, unknown>> };

        if (!response.data)
            throw new Error("The Quran service returned invalid data.");

        return response.data.map(surah => ({
            number: Number(surah.number),
            name: String(surah.name ?? ""),
            englishName: String(surah.englishName ?? ""),
            ayahCount: Number(surah.numberOfAyahs)
        }));
    }

    async ayahs(surahNumber: number): Promise<Ayah[]> {
        const [arabicResponse, translationResponse] = await Promise.all([
            fetchJson(`/surah/${surahNumber}`),
            fetchJson(`/surah/${surahNumber}/en.asad`)
        ]);
        const arabic = (arabicResponse as { data?: { ayahs?: Array<Record<string, unknown>> } }).data?.ayahs;
        const translation = (translationResponse as { data?: { ayahs?: Array<Record<string, unknown>> } }).data?.ayahs;

        if (!arabic || !translation)
            throw new Error("The Quran service returned invalid surah data.");

        return arabic.slice(0, translation.length).map((ayah, index) => ({
            number: Number(ayah.numberInSurah),
            text: String(ayah.text ?? ""),
            translation: String(translation[index].text ?? "")
        }));
    }
}

export const quranService = new QuranService();
