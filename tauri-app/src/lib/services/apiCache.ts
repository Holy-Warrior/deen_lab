import { invoke } from "@tauri-apps/api/core";

// tauri: thin wrapper around the two Rust commands documented in docs/backend-api.md.
// api_request always hits the network (and, with cache:true, saves the result to disk
// keyed by url); get_cached_response only ever reads that disk cache, never the network.
export interface ApiRequestOptions {
    method?: string;
    headers?: Record<string, string>;
    body?: unknown;
}

function getCachedResponse<T>(url: string): Promise<T | null> {
    return invoke<T | null>("get_cached_response", { url });
}

function apiRequest<T>(url: string, options: ApiRequestOptions = {}): Promise<T> {
    return invoke<T>("api_request", {
        url,
        method: options.method,
        headers: options.headers,
        body: options.body,
        cache: true
    });
}

/**
 * Stale-while-revalidate: reports cached data (if any) via `onCached` immediately,
 * without waiting on the network, then ALWAYS makes the real network request
 * afterwards -- cache is never treated as a substitute for it, only a head start.
 * Rejects with the network error if the network request fails; the caller decides
 * whether to keep showing the (already-delivered) cached data alongside that error.
 */
export async function loadCacheThenNetwork<Raw, T>(
    url: string,
    parse: (data: Raw) => T,
    onCached: (value: T) => void,
    options?: ApiRequestOptions
): Promise<T> {
    const cached = await getCachedResponse<Raw>(url).catch(() => null);

    if (cached !== null) {
        onCached(parse(cached));
    }

    const fresh = await apiRequest<Raw>(url, options);
    return parse(fresh);
}
