export interface DuaCategory { id: string; name: string; description: string; count: number; }
export interface Dua { id: number; title: string; arabic: string; transliteration: string; translation: string; source: string; repeat: number; }

const baseUrl = "https://ummahapi.com/api/duas";

async function request(path: string): Promise<unknown> {
    const response = await fetch(`${baseUrl}${path}`);

    if (!response.ok)
        throw new Error("Duas are currently unavailable.");

    return response.json();
}

export class DuaService {
    async categories(): Promise<DuaCategory[]> {
        const payload = await request("/categories") as { data?: { categories?: DuaCategory[] } };
        return payload.data?.categories ?? [];
    }

    async category(id: string): Promise<Dua[]> {
        const payload = await request(`/category/${encodeURIComponent(id)}`) as { data?: { duas?: Dua[] } };
        return payload.data?.duas ?? [];
    }
}

export const duaService = new DuaService();
