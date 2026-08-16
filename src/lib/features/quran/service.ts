import { loadCacheThenNetwork } from "$lib/services/apiCache";

export interface SurahSummary {
    number: number;
    nameArabic: string;
    nameEnglish: string;
    nameTranslation: string;
    revelationPlace: string;
    versesCount: number;
}

export interface Verse {
    verseKey: string;
    ayah: number;
    arabic: string;
    transliteration: string;
    translation: string;
}

const baseUrl = "https://ummahapi.com/api/quran";

function parseSurahs(payload: { data?: { surahs?: any[] } }): SurahSummary[] {
    return (payload.data?.surahs ?? []).map((surah) => ({
        number: surah.number,
        nameArabic: surah.name_arabic,
        nameEnglish: surah.name_english,
        nameTranslation: surah.name_translation,
        revelationPlace: surah.revelation_place,
        versesCount: surah.verses_count
    }));
}

// design: sahih_international is the default translation shown alongside transliteration --
// UmmahAPI returns every language/translator it has per verse (see the `translations` dict),
// this app just picks one well-established English translation rather than adding a
// translation-picker for a first pass.
function parseVerses(payload: { data?: { verses?: any[] } }): Verse[] {
    return (payload.data?.verses ?? []).map((verse) => ({
        verseKey: verse.verse_key,
        ayah: verse.ayah,
        arabic: verse.arabic,
        transliteration: verse.transliteration,
        translation: verse.translations?.sahih_international ?? ""
    }));
}

export class QuranService {
    surahs(onCached: (surahs: SurahSummary[]) => void): Promise<SurahSummary[]> {
        return loadCacheThenNetwork(`${baseUrl}/surahs`, parseSurahs, onCached);
    }

    surah(number: number, onCached: (verses: Verse[]) => void): Promise<Verse[]> {
        return loadCacheThenNetwork(`${baseUrl}/surah/${number}`, parseVerses, onCached);
    }
}

export const quranService = new QuranService();
