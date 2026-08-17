export type PrayerId = "tahajjud" | "fajr" | "shuruq" | "dhuhr" | "asr" | "maghrib" | "isha";

/**
 * What kind of thing this slot actually is:
 *   fard   -- one of the five obligatory daily prayers
 *   nafl   -- a voluntary prayer (Tahajjud)
 *   marker -- not a prayer at all, just a boundary in the day (sunrise)
 *
 * Drives how prominently a slot renders. The five fard prayers are the reason the feature
 * exists; the other two are context around them and must not read as equals in a list.
 */
export type PrayerKind = "fard" | "nafl" | "marker";

export interface PrayerMeta {
    id: PrayerId;
    /** Big line on the card. */
    label: string;
    arabic: string;
    kind: PrayerKind;
    /** Key inside Aladhan's `data.timings` object for this slot. */
    timingKey: string;
    /**
     * Small line above the label. Deliberately NOT "Next Prayer" for every slot: sunrise is
     * not a prayer at all (it's when the Fajr window closes, and praying then is discouraged),
     * and Tahajjud is voluntary rather than one of the five obligatory prayers -- calling
     * either one "Next Prayer" would be plainly wrong in an app people pray by.
     */
    eyebrow: string;
    /** Lives in static/, so it's a plain absolute URL rather than a Vite import. */
    image: string;
}

// design: chronological within a single calendar day, which is also the order Aladhan reports
// them in. Tahajjud comes FIRST, not last: Aladhan's `Lastthird` is a small-hours clock time
// (e.g. 01:58) belonging to the same calendar date, so a day runs Tahajjud -> Fajr -> Sunrise
// -> ... -> Isha with no midnight wraparound to special-case. Verified against the live API.
export const prayers: PrayerMeta[] = [
    { id: "tahajjud", label: "Tahajjud", arabic: "تهجد", kind: "nafl", timingKey: "Lastthird", eyebrow: "Voluntary night prayer", image: "/prayer/tahajjud.webp" },
    { id: "fajr", label: "Fajr", arabic: "الفجر", kind: "fard", timingKey: "Fajr", eyebrow: "Next Prayer", image: "/prayer/fajr.webp" },
    { id: "shuruq", label: "Sunrise", arabic: "الشروق", kind: "marker", timingKey: "Sunrise", eyebrow: "Fajr window closes", image: "/prayer/shuruq.webp" },
    { id: "dhuhr", label: "Dhuhr", arabic: "الظهر", kind: "fard", timingKey: "Dhuhr", eyebrow: "Next Prayer", image: "/prayer/dhuhr.webp" },
    { id: "asr", label: "Asr", arabic: "العصر", kind: "fard", timingKey: "Asr", eyebrow: "Next Prayer", image: "/prayer/asr.webp" },
    { id: "maghrib", label: "Maghrib", arabic: "المغرب", kind: "fard", timingKey: "Maghrib", eyebrow: "Next Prayer", image: "/prayer/maghrib.webp" },
    { id: "isha", label: "Isha", arabic: "العشاء", kind: "fard", timingKey: "Isha", eyebrow: "Next Prayer", image: "/prayer/isha.webp" }
];
