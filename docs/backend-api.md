# Backend API Reference

What the Rust side (`src-tauri/`) currently exposes to the SvelteKit front-end, and what
platform capabilities are installed but not yet wired into any Rust command. Written so the
next front-end pass knows what it can call without re-reading the Rust source.

Two ways to reach native functionality from TypeScript:

1. **Tauri commands** — Rust functions in `src-tauri/src/*.rs`, registered in
   `invoke_handler![...]` in [`lib.rs`](../src-tauri/src/lib.rs), called from the front-end with
   `invoke("command_name", { ...args })` from `@tauri-apps/api/core`.
2. **Plugin JS APIs** — installed Tauri plugins that ship their own `@tauri-apps/plugin-*`
   package and can be called directly from TypeScript without a hand-written Rust command,
   as long as the plugin is registered on the Rust side and the required permissions are
   granted in `src-tauri/capabilities/default.json`.

---

## 1. Tauri commands (`invoke(...)`)

### `build_feature(prompt: string): Promise<FeatureBuildResult>`

Source: [`src-tauri/src/lib.rs`](../src-tauri/src/lib.rs)

Sends `prompt` to Groq (`llama-3.3-70b-versatile` by default) with a system prompt that
restricts it to generating small, self-contained Islamic-learning HTML mini-tools. Groq is
asked to reply with strict JSON and the command deserializes it into:

```ts
interface FeatureBuildResult {
  decision: "generate" | "decline";
  title: string;
  message: string;
  html: string; // complete, self-contained HTML document (no network/script/style refs)
}
```

Errors (rejected `Promise`, string message) when:
- `prompt` is empty/whitespace.
- `groq_config::API_KEY` is empty — i.e. `src-tauri/src/groq_config.rs` hasn't been created
  from [`groq_config.example.rs`](../src-tauri/src/groq_config.example.rs) with a real key.
  This file is gitignored; every developer/machine needs their own copy.
- The Groq request fails, returns a non-2xx status, or returns a `decision` outside
  `"generate" | "decline"`, or `decision: "generate"` with empty `html`.

Because the returned `html` is meant to be rendered (e.g. in a sandboxed `<iframe srcdoc>`),
treat it as untrusted content on the front-end regardless of the system prompt's constraints.

### `api_request(url, method?, headers?, body?, cache: boolean): Promise<unknown>`

Source: [`src-tauri/src/api_cache.rs`](../src-tauri/src/api_cache.rs)

Generic HTTP client command, backed by a `reqwest::Client` shared across calls
(`app.manage(api_cache::HttpClient::default())`). Always hits the network.

```ts
invoke("api_request", {
  url: "https://api.example.com/thing",
  method: "GET",        // GET | POST | PUT | PATCH | DELETE | HEAD, defaults to GET
  headers: { "Authorization": "Bearer ..." }, // optional Record<string,string>
  body: { some: "json" },                     // optional, sent as JSON
  cache: true            // if true, persist the parsed response to disk keyed by `url`
});
```

- Response body is parsed as JSON; if parsing fails, the raw text is returned as a JSON string
  instead (so callers should always get *something* JSON-shaped back).
- Non-2xx responses reject with `"Request failed with status {code}: {first 500 chars of body}"`.
- When `cache: true`, the parsed response is written to
  `app_data_dir/api_cache/{hash(url)}.json`, atomically (write to `.tmp`, then rename). Caching
  the same URL again **overwrites** the previous entry — one value per URL, no history.

### `get_cached_response(url: string): Promise<unknown | null>`

Source: [`src-tauri/src/api_cache.rs`](../src-tauri/src/api_cache.rs)

Reads whatever was last cached for `url` from disk. Never touches the network. Returns `null`
if nothing has been cached yet, or if the cache entry on disk was corrupt (and silently deletes
the corrupt file in that case) — so the front-end can treat "no cache" as a normal state, not
an error.

**Intended pattern** (not yet used anywhere in the front-end): call `get_cached_response(url)`
first to paint instantly with whatever's on disk, then call `api_request(url, ..., cache: true)`
in the background to refresh it. If `api_request` fails (offline, server down), the UI already
has the cached data and is unaffected.

> Every feature currently in the codebase (Quran, prayer times, duas, hadith, sehri/iftari)
> calls `fetch()` directly from the browser instead of going through `api_request` /
> `get_cached_response`. That means none of them get disk caching or offline fallback, and on
> Android they're subject to whatever WebView networking/CORS behavior applies instead of a
> native HTTP client. Routing these through the two commands above is the main reason this
> doc exists.

---

## 2. Installed plugins

### `tauri-plugin-opener` (desktop + mobile)

Registered unconditionally in `.plugin(tauri_plugin_opener::init())`. Exposes
`@tauri-apps/plugin-opener` on the front-end (`openUrl`, `openPath`, `revealItemInDir`, etc.)
without any custom Rust command needed. Permission granted: `opener:default`. Not currently
imported anywhere in the front-end.

### `tauri-plugin-geolocation` (Android only)

Registered only under `#[cfg(target_os = "android")]` in `lib.rs`'s `setup()`:
`app.handle().plugin(tauri_plugin_geolocation::init())?`. Declared as an
`[target.'cfg(target_os = "android")'.dependencies]` entry in `Cargo.toml`, so it does not
build into the desktop binary at all — only test/ship this on an Android target or emulator.

Front-end package `@tauri-apps/plugin-geolocation` is **not yet installed** in `package.json`;
add it before calling any of the JS API below.

Permissions already granted in
[`src-tauri/capabilities/default.json`](../src-tauri/capabilities/default.json):
`geolocation:allow-check-permissions`, `geolocation:allow-request-permissions`,
`geolocation:allow-get-current-position`.

Expected JS surface once the plugin package is added (from `@tauri-apps/plugin-geolocation`):

```ts
import { checkPermissions, requestPermissions, getCurrentPosition } from "@tauri-apps/plugin-geolocation";

const permissions = await checkPermissions();          // "granted" | "denied" | "prompt" | ...
if (permissions.location !== "granted")
  await requestPermissions(["location"]);

const position = await getCurrentPosition(); // { coords: { latitude, longitude, ... }, timestamp }
```

> The current Qibla feature (`src/lib/features/qibla/service.ts`, pre-move) calls the browser's
> `navigator.geolocation.getCurrentPosition` directly instead of this plugin. On Android inside
> a Tauri WebView, the browser geolocation API may not be backed by the OS location stack the
> way the native plugin is, and it bypasses the Tauri permission model declared in
> `capabilities/default.json`. Any Qibla/location-based rebuild should go through
> `tauri-plugin-geolocation` instead.

---

## 3. Adding a new command or plugin

- New Rust commands: add the `#[tauri::command]` function (own module if it's more than a
  handful of lines, following `api_cache.rs`'s pattern), then list it in
  `tauri::generate_handler![...]` in `lib.rs`.
- New plugins: add the dependency to `Cargo.toml` (guard with
  `[target.'cfg(target_os = "...")'.dependencies]` if platform-specific), register with
  `.plugin(...)` in `lib.rs`, add the required permission identifiers to
  `src-tauri/capabilities/default.json`, and install the matching `@tauri-apps/plugin-*`
  package if the plugin exposes its own JS API.
