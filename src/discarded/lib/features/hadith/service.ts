export interface HadithCollection { key: string; name: string; arabic_name: string; author: string; reliability: string; total_hadiths: number; }
export interface Hadith { id: string; collection: string; collection_name: string; hadithnumber: number; arabic: string; english: string; grade: string; }
export interface HadithPage { hadiths: Hadith[]; page: number; totalPages: number; total: number; }

const baseUrl = "https://ummahapi.com/api/hadith";

async function request(path: string): Promise<unknown> {
    const response = await fetch(`${baseUrl}${path}`);
    if (!response.ok) throw new Error("The Hadith library is currently unavailable.");
    return response.json();
}

export class HadithService {
    async collections(): Promise<HadithCollection[]> {
        const payload = await request("/collections") as { data?: { collections?: HadithCollection[] } };
        return payload.data?.collections ?? [];
    }

    async browse(collection: string, page: number): Promise<HadithPage> {
        const payload = await request(`/${encodeURIComponent(collection)}?page=${page}&limit=20`) as { data?: { hadiths?: Hadith[]; page?: number; total_pages?: number; total?: number } };
        const data = payload.data;
        return { hadiths: data?.hadiths ?? [], page: data?.page ?? page, totalPages: data?.total_pages ?? 1, total: data?.total ?? 0 };
    }

    async search(query: string, collection?: string): Promise<Hadith[]> {
        const parameters = new URLSearchParams({ q: query, limit: "25" });
        if (collection) parameters.set("collection", collection);
        const payload = await request(`/search?${parameters}`) as { data?: { hadiths?: Hadith[] } };
        return payload.data?.hadiths ?? [];
    }
}

export const hadithService = new HadithService();
