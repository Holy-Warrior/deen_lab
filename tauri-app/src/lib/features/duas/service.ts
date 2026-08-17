import { loadCacheThenNetwork } from "$lib/services/apiCache";

export interface DuaCategory { id: string; name: string; description: string; count: number; }
export interface Dua { id: number; title: string; arabic: string; transliteration: string; translation: string; source: string; repeat: number; }

const baseUrl = "https://ummahapi.com/api/duas";

function parseCategories(payload: { data?: { categories?: DuaCategory[] } }): DuaCategory[] {
    return payload.data?.categories ?? [];
}

function parseDuas(payload: { data?: { duas?: Dua[] } }): Dua[] {
    return payload.data?.duas ?? [];
}

export class DuaService {
    // tauri: cache-then-network via the Rust api_request/get_cached_response commands
    // (docs/backend-api.md) instead of a raw fetch() -- same pattern as Qibla/Sehri & Iftari,
    // so categories/duas already seen once still render instantly offline.
    categories(onCached: (categories: DuaCategory[]) => void): Promise<DuaCategory[]> {
        return loadCacheThenNetwork(`${baseUrl}/categories`, parseCategories, onCached);
    }

    category(id: string, onCached: (duas: Dua[]) => void): Promise<Dua[]> {
        return loadCacheThenNetwork(`${baseUrl}/category/${encodeURIComponent(id)}`, parseDuas, onCached);
    }
}

export const duaService = new DuaService();
