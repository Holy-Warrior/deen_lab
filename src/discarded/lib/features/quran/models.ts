export interface Surah {
    number: number;
    name: string;
    englishName: string;
    ayahCount: number;
}

export interface Ayah {
    number: number;
    text: string;
    translation: string;
}
