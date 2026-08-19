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

### `build_feature(prompt: string, progress: Channel<BuildProgress>): Promise<FeatureBuildResult>`

Source: [`src-tauri/src/lib.rs`](../src-tauri/src/lib.rs)

Sends `prompt` to Groq with a system prompt that restricts it to generating small, self-contained
Islamic-learning HTML mini-tools. Groq is asked to reply with strict JSON and the command
deserializes it into:

```ts
interface FeatureBuildResult {
  decision: "generate" | "decline";
  title: string;
  message: string;
  html: string; // body-only markup -- NOT a whole document, see below
}
```

`html` is **body-only markup**, not a complete document. The model is told Tailwind is already
loaded and must not link it; the front-end wraps the markup in a document that injects a
bundled Tailwind runtime plus a restrictive CSP. See
[`docs/feature-studio.md`](./feature-studio.md) for why the contract is split that way.

Rather than calling one model, it walks `MODEL_CHAIN` (`openai/gpt-oss-120b` →
`openai/gpt-oss-20b` → `qwen/qwen3.6-27b`), moving on whenever an attempt fails in a way another
model might survive. Groq's per-minute token allowance is **per model**, so a 429 from one says
nothing about the next and the chain runs with no delay between models. Only if all three are
exhausted does it wait (Groq's own retry hint, capped at 45s) and make one more pass.

`progress` is a Tauri `Channel` carrying updates while that happens, so a wait can be explained
instead of looking like a hang:

```ts
type BuildProgress =
  | { kind: "trying"; attempt: number; total: number }
  | { kind: "waiting"; seconds: number };
```

Errors (rejected `Promise`, string message) when:

- `prompt` is empty/whitespace.
- `groq_config::API_KEY` is empty — i.e. `src-tauri/src/groq_config.rs` hasn't been created
  from [`groq_config.example.rs`](../src-tauri/src/groq_config.example.rs) with a real key.
  This file is gitignored; every developer/machine needs their own copy.
- Groq rejects the key (HTTP 401/403). Fatal, not retried — no other model fixes a bad key.
- Every model in the chain failed on both passes. Reported as one plain sentence.

### `upgrade_feature(request: string, currentHtml: string, progress: Channel<BuildProgress>): Promise<FeatureBuildResult>`

Source: [`src-tauri/src/lib.rs`](../src-tauri/src/lib.rs)

Asks for a revision of an existing tool. Same return type, same model chain, same error handling
as `build_feature` — both call the shared `run_chain()` and differ only in their system prompt
(`system_prompt(Task::Upgrade)`) and user message, which carries the tool's current markup
alongside the requested change.

The result is a **candidate**, not a commitment: this command never writes anything, and the
front-end shows the new version running before the user chooses to keep it. See
[`feature-studio.md`](./feature-studio.md) for the versioning model.

Everything else — rate limits (429/413), a reply cut off by the token budget
(`finish_reason == "length"`, checked *before* parsing since a truncated reply is invalid JSON),
Groq rejecting its own JSON, network blips, a `decision` outside `"generate" | "decline"`, or
`decision: "generate"` with empty `html` — is treated as retryable and moves to the next model
rather than reaching the user.

Because the returned `html` is rendered in the app, treat it as untrusted content on the
front-end regardless of the system prompt's constraints — the sandbox and CSP applied in
`document.ts` are what actually contain it, not the prompt.

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
Also used for reverse geocoding (turning GPS coordinates into a place name) against OpenStreetMap's
Nominatim API — see [`src/lib/services/location.ts`](../src/lib/services/location.ts)'s
`placeName()` — and for Duas and Quran, both against UmmahAPI
([`duas/service.ts`](../src/lib/features/duas/service.ts),
[`quran/service.ts`](../src/lib/features/quran/service.ts)) — proof this pair of commands works
for any HTTP API, not just Aladhan.

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

### `tauri-plugin-compass` (Android only, local/unpublished)

Source: [`src-tauri/plugins/compass/`](../src-tauri/plugins/compass/)

Streams live device-heading updates for Qibla's rotating compass. Built the same way as
`device-settings` above, but for a genuinely different problem: a single request/response
`invoke()` can't deliver a continuous stream of sensor readings, so this mirrors the
already-installed `tauri-plugin-geolocation`'s `watchPosition` pattern instead — a
`tauri::ipc::Channel` passed as an invoke argument, held onto by the Kotlin side, which calls
`channel.send(...)` every time a new reading comes in.

```ts
import { startCompass } from "$lib/services/compass";

const { mode, stop } = await startCompass(heading => {
  // heading: { degrees: number, absolute: boolean }, called repeatedly until stop()
});
// mode: "sensor" | "gyroscope" | "none"
```

Two commands: `start` (registers sensor listeners, begins streaming, resolves with which mode
is actually available) and `stop` (unregisters listeners). No runtime permission needed —
`TYPE_ACCELEROMETER`/`TYPE_MAGNETIC_FIELD`/`TYPE_GYROSCOPE` are "normal" motion sensors, not the
`BODY_SENSORS` permission group.

Sensor fallback chain, decided once per `start()` call:

- **`"sensor"`** — `TYPE_ACCELEROMETER` + `TYPE_MAGNETIC_FIELD` fused via
  `SensorManager.getRotationMatrix`/`getOrientation`, the standard Android recipe for a real,
  north-anchored compass heading.
- **`"gyroscope"`** — no magnetometer, so `TYPE_GYROSCOPE`'s angular velocity is integrated over
  time into a heading that starts at 0 when `start()` is called. Accurate for *relative*
  rotation (how far the phone has turned since then), but not anchored to true north; the
  frontend seeds its initial needle angle from the GPS-computed bearing either way, so this
  degrades gracefully rather than pointing somewhere arbitrary.
- **`"none"`** — neither sensor exists; the caller falls back to a static (non-rotating) bearing
  display. See `QiblaPage.svelte`'s inline caveat text for each of these modes (never a popup).

Permissions granted in `capabilities/mobile.json`: `compass:allow-start`, `compass:allow-stop`.

### `tauri-plugin-silence-of-salah-engine` (Android only, local/vendored)

Source: [`src-tauri/plugins/silence-of-salah-engine/`](../src-tauri/plugins/silence-of-salah-engine/)

Silences the phone while you pray, either by recognising salah from on-device motion-sensor ML
inference or by the clock alone. Unlike `device-settings` and `compass`, this one was not written
for this app — it is vendored in
from the standalone
[`tauri-plugin-silence-of-salah-engine`](https://github.com/Holy-Warrior/silence_of_salah_engine)
repo, itself a port of the original Flutter plugin. It is copied in rather than referenced by an
out-of-tree path so a fresh clone still builds; when the upstream plugin changes, re-copy
`Cargo.toml`, `build.rs`, `src/`, `android/` and `permissions/` over the top.

It is much bigger than the other two: a foreground service, exact daily alarms, a boot receiver,
a sensor loop and a 1.5 MB bundled XGBoost model. None of that needs wiring here — the plugin's
own `AndroidManifest.xml` declares the service, receivers and ten permissions, and Gradle's
manifest merger folds them into the app automatically.

#### Three modes

`set_engine_mode` picks between them, and `get_native_status().mode` reports which is active.

| Mode | How it decides | Cost | Fails by |
| --- | --- | --- | --- |
| `ml` | Motion sensors and the model, inside a foreground service | A running service and a wakelock for as long as it listens | Missing a prayer, or silencing you for sitting still |
| `manual` | The clock. Silent from a supplied time until a fixed number of minutes later | Two exact alarms per window; nothing runs in between | Silencing you when you were not praying, or ending before you finished |
| `disabled` | Nothing is armed | None | — |

`manual` exists because the model is not reliable enough to be someone's only option. It cannot
adapt, but it cannot be wrong about what it was told to do either. The two working modes are
mutually exclusive: they share one persisted audio state on the native side, so running both
would mean two owners fighting over the ringer.

```ts
import { scheduleDailyAlarms, engineStatus, stopEngine } from "$lib/features/auto-silent/engine";

await scheduleDailyAlarms([{ id: 1, hour: 5, minute: 9, label: "Fajr" }]);
const status = await engineStatus();   // mode, serviceRunning, audioState, ...
```

Things worth knowing before using it:

- **It emits no events.** There is no channel and no callback — the only way to observe the
  engine is to poll `get_native_status`. `AutoSilentPage.svelte` polls every three seconds while
  the page is open, and not at all when it isn't.
- **`schedule_daily_alarms` replaces the entire alarm list.** There is no incremental add or
  remove, so callers always send the complete set; an empty list cancels everything.
- **The plugin owns alarm persistence.** Its `AlarmScheduler` plus a `BOOT_COMPLETED` receiver
  re-arm alarms after a reboot, so the app does not have to. (The original Flutter app bypassed
  all of this and built a parallel alarm system; this app deliberately does not.)
- **`schedule_manual_windows` is the manual-mode equivalent**, and behaves the same way: it
  replaces the whole list, ids must be unique, and an empty list cancels everything. `hour` and
  `minute` are the *final* wall-clock start with the offset already folded in — the plugin has no
  location and no calendar, so it cannot compute prayer times, and that arithmetic stays here.
- **Switching modes does not clear either schedule.** The outgoing mode is disarmed (service
  stopped, alarms cancelled, any silence it owned undone) but its configuration is kept, so
  flipping between modes is a toggle rather than a reset.
- **A mode switch will not end a prayer.** `set_engine_mode` takes a policy — `ifIdle` (the
  default, refuse while something is running), `immediate` (switch anyway) or
  `afterCurrentSession` (queue it). A blocked switch resolves with `applied: false` and the
  session that blocked it in `status.activeSession`, so the page can ask "switch now" or "after
  this prayer" rather than guessing. A queued switch is persisted, survives the app closing, and
  is applied by whichever path ends the session. Re-requesting the current mode cancels it.
- **Manual mode always hands the ringer back.** The restore deadline is persisted rather than
  living only in a pending alarm, and `get_native_status` checks it on every call. That matters
  because Android cancels every one of an app's alarms when the app is force-stopped and tells
  nobody — without the check, a force-stop mid-window would leave the phone silent indefinitely.
- **`start_native_task` now rejects outside `ml` mode.** Nothing in this app calls it outside
  that mode, but the plugin refuses rather than letting the sensor service and manual mode both
  own the ringer.
- **Four permissions, all fire-and-forget.** `request_*` opens a system settings screen and
  resolves immediately — Android reports no answer, so the only way to learn the outcome is to
  poll `get_permission_status` once the app is visible again.
- **The `debug` permission set is granted on purpose.** `debug_set_audio_silent` /
  `debug_restore_audio_default` force the ringer without the ML engine, which is what powers the
  "Check it works" buttons — otherwise the only way to test the permission chain is to wait for a
  real prayer.

Permissions granted in `capabilities/mobile.json`: the whole `silence-of-salah-engine:default`
set (seventeen commands) plus `silence-of-salah-engine:debug` (four more). These are permission
*sets* rather than individual `allow-*` identifiers — the plugin defines them in
`permissions/default.toml` and `permissions/debug.toml`.

---

## 3. Capabilities: `default.json` vs `mobile.json`

Two capability files, both applying to the `"main"` window:

- [`capabilities/default.json`](../src-tauri/capabilities/default.json) — `core:default`,
  `opener:default`. No `"platforms"` field, so it applies to **every** build target.
- [`capabilities/mobile.json`](../src-tauri/capabilities/mobile.json) — every
  `geolocation:*`, `device-settings:*`, and `compass:*` permission, scoped with
  `"platforms": ["android"]`.

They're split because a desktop build never depends on `tauri-plugin-geolocation`,
`tauri-plugin-device-settings`, or `tauri-plugin-compass` at all (see the `Cargo.toml`
target-gating above), so those permission identifiers **don't exist** in the desktop build's
schema. Requesting them
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
