# Backend API Reference

What the Rust side (`src-tauri/`) exposes to the SvelteKit front-end: built-in commands, the
custom local plugin, and the installed platform plugins. Written so a front-end change knows
what it can call without re-reading the Rust/Kotlin source.

Two ways to reach native functionality from TypeScript:

1. **Tauri commands** — Rust functions registered in `invoke_handler![...]`, called from the
   front-end with `invoke("command_name", { ...args })` from `@tauri-apps/api/core`. Commands
   that belong to a *plugin* (rather than the main app crate) are namespaced
   `invoke("plugin:<name>|<command>")`.
2. **Plugin JS APIs** — installed Tauri plugins that ship their own `@tauri-apps/plugin-*`
   npm package and can be called directly from TypeScript, as long as the plugin is registered
   on the Rust side and the required permissions are granted in a capability file.

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

**Stale-while-revalidate pattern** — implemented once, reusably, in
[`src/lib/services/apiCache.ts`](../src/lib/services/apiCache.ts)'s `loadCacheThenNetwork()`:
call `get_cached_response(url)` first to paint instantly with whatever's on disk (if anything),
then **always** still call `api_request(url, ..., cache: true)` — the cache is a head start,
never a substitute for the real request. If the network call fails, the promise rejects with
that error; the caller decides whether to keep showing the already-delivered cached data
alongside it. First real consumer:
[`src/lib/features/sehri-iftari/service.ts`](../src/lib/features/sehri-iftari/service.ts).

---

## 2. Installed plugins

### `tauri-plugin-opener` (desktop + mobile)

Registered unconditionally in `.plugin(tauri_plugin_opener::init())`. Exposes
`@tauri-apps/plugin-opener` on the front-end (`openUrl`, `openPath`, `revealItemInDir`, etc.)
without any custom Rust command needed. Permission granted: `opener:default` in
`capabilities/default.json`. Not currently imported anywhere in the front-end.

### `tauri-plugin-geolocation` (Android only)

Registered only under `#[cfg(target_os = "android")]` in `lib.rs`'s `setup()`. Declared as an
`[target.'cfg(target_os = "android")'.dependencies]` entry in `Cargo.toml`, so it does not
build into the desktop binary at all — only test/ship this on an Android target.

Front-end package `@tauri-apps/plugin-geolocation` is installed. JS surface used:

```ts
import { checkPermissions, requestPermissions, getCurrentPosition } from "@tauri-apps/plugin-geolocation";

const permissions = await checkPermissions();          // { location: PermissionState, coarseLocation: PermissionState }
if (permissions.location !== "granted")
  await requestPermissions(["location"]);

const position = await getCurrentPosition(); // { coords: { latitude, longitude, ... }, timestamp }
```

**Rejection strings to match on**, confirmed by reading the plugin's own Android source
(`tauri-plugin-geolocation-2.3.2/android/src/main/java/{Geolocation,GeolocationPlugin}.kt` in
the local Cargo registry cache) rather than guessing:

- `"Location disabled."` / `"Location services are disabled."` — the OS Location toggle is off.
  `checkPermissions`/`requestPermissions` check this *before* the permission state itself, so
  this is usually what you see first, not a generic permission error.
- `"Google Play Services unavailable."` — device has no working fused location provider.
- Anything else — genuine permission denial (`location !== "granted"` after requesting) or an
  unclassified failure.

Reference implementation of classifying these into typed errors:
[`src/lib/features/qibla/service.ts`](../src/lib/features/qibla/service.ts) (`classify()`,
`LocationServicesDisabledError` / `LocationPermissionDeniedError` / `LocationUnavailableError`).
`QiblaPage.svelte` shows the corresponding UI pattern for each: settings-redirect banner,
grant-permission banner (escalating to app settings after one failed re-prompt — see the
`device-settings` plugin below), and a manual city-picker fallback.

Permissions granted in
[`src-tauri/capabilities/mobile.json`](../src-tauri/capabilities/mobile.json):
`geolocation:allow-check-permissions`, `geolocation:allow-request-permissions`,
`geolocation:allow-get-current-position`.

### `tauri-plugin-device-settings` (Android only, local/unpublished)

Source: [`src-tauri/plugins/device-settings/`](../src-tauri/plugins/device-settings/)

A small custom plugin, hand-written (mirroring `tauri-plugin-geolocation`'s own structure)
because no installed or published plugin exposes a way to open native Android settings
screens or show a system Toast. Android-only: depended on from `Cargo.toml` under
`[target.'cfg(target_os = "android")'.dependencies]`, so — like geolocation — it doesn't exist
in the desktop build at all.

No generated JS package (`--no-api`-style, hand-written invoke calls instead, same convention
as the main app's own commands); wrappers live in
[`src/lib/services/deviceSettings.ts`](../src/lib/services/deviceSettings.ts):

```ts
import { openLocationSettings, openAppSettings, showToast } from "$lib/services/deviceSettings";

await openLocationSettings();      // Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
await openAppSettings();           // Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS) for this app
await showToast("some message");   // native Android Toast, LENGTH_LONG
```

Commands (all resolve `void`, all Android-only):

- `open_location_settings` — jumps to the OS Location Settings screen. Used when
  `LocationServicesDisabledError` is caught (see Qibla above).
- `open_app_settings` — jumps to *this app's* own "App info" screen. Android stops showing its
  own permission-request dialog after a prior denial (silently returns denied, no UI at all on
  subsequent `requestPermissions()` calls) — this is the only remaining way for the user to
  grant it manually. `QiblaPage.svelte` escalates to this only after one automatic re-prompt
  attempt has already proven not to show anything.
- `show_toast(message: string)` — a native Toast, shown via `activity.runOnUiThread { ... }`
  since plugin commands don't run on the UI thread by default. Used right before
  `open_app_settings()` so the settings redirect doesn't feel unexplained.

Permissions (auto-generated per command by the plugin's own `build.rs` into
`permissions/autogenerated/commands/*.toml` — never hand-write these) granted in
`capabilities/mobile.json`: `device-settings:allow-open-location-settings`,
`device-settings:allow-open-app-settings`, `device-settings:allow-show-toast`.

**Gotcha already hit once**: the plugin's `Cargo.toml` `[package]` needs a `links = "<same as
package.name>"` field, or `tauri_plugin::Builder::try_build()` panics in `build.rs` with
`package.links field in the Cargo manifest is not set`. Not needed for anything else here
(no native/non-Kotlin build artifacts), but the build script requires it regardless.

---

## 3. Capabilities: `default.json` vs `mobile.json`

Two capability files, both applying to the `"main"` window:

- [`capabilities/default.json`](../src-tauri/capabilities/default.json) — `core:default`,
  `opener:default`. No `"platforms"` field, so it applies to **every** build target.
- [`capabilities/mobile.json`](../src-tauri/capabilities/mobile.json) — every
  `geolocation:*` and `device-settings:*` permission, scoped with `"platforms": ["android"]`.

They're split because a desktop build never depends on `tauri-plugin-geolocation` or
`tauri-plugin-device-settings` at all (see the `Cargo.toml` target-gating above), so those
permission identifiers **don't exist** in the desktop build's schema. Requesting them
unconditionally from one shared capability file broke every desktop `cargo run`/`tauri dev`
with `Permission geolocation:allow-check-permissions not found, expected one of core:default,
...` — confirmed by diffing `gen/schemas/desktop-schema.json` (no `geolocation:*` entries at
all) against `gen/schemas/android-schema.json` (has them). Any future Android-only plugin
permission goes in `mobile.json`, not `default.json`.

---

## 4. Adding a new command or plugin

- New Rust commands on the main app crate: add the `#[tauri::command]` function (own module if
  it's more than a handful of lines, following `api_cache.rs`'s pattern), then list it in
  `tauri::generate_handler![...]` in `lib.rs`.
- New **platform-specific native functionality** (anything needing real Kotlin/Swift, not just
  a Rust HTTP call): a local plugin crate under `src-tauri/plugins/<name>/`, following
  `device-settings`'s structure as the template — `tauri plugin new <name> --android
  --no-example --no-api -d src-tauri/plugins` scaffolds this correctly if you have a real
  interactive terminal available; otherwise copy the structure of an already-installed plugin
  from the local Cargo registry cache (`~/.cargo/registry/src/.../tauri-plugin-<name>-<ver>/`)
  as a proven reference rather than guessing at the Rust↔Kotlin wiring.
- New installed plugins: add the dependency to `Cargo.toml` (guard with
  `[target.'cfg(target_os = "...")'.dependencies]` if platform-specific), register with
  `.plugin(...)` in `lib.rs`, add the required permission identifiers to the appropriate
  capability file (`default.json` if it applies to every platform, `mobile.json` — or a new
  platform-scoped file — if it's platform-specific), and install the matching
  `@tauri-apps/plugin-*` package if the plugin exposes its own JS API.
