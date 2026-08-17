# Legacy Front-End Reference

The original front-end attempt was moved to [`src/discarded/`](../src/discarded/) — never wired
into the SvelteKit routes, never part of the app that builds today, kept only as a reference for
the rebuild. See [`frontend-architecture.md`](./frontend-architecture.md) for what the rebuild
actually looks like and which ideas from here made it in.

**That tree has now been pruned.** Once a feature was rebuilt, its old source stopped earning its
keep, and the whole `lib/ui` kernel plus the `lib/services` stub were superseded outright. Only
the two features that have **not** been rebuilt yet still exist as code:

```text
src/discarded/
  lib/features/
    hadith/          - service.ts + HadithPage.svelte
    feature-studio/  - service.ts + storage.ts + FeatureStudioPage.svelte
```

Everything else described below has been **deleted**, and this document is now the only record of
it. The descriptions are kept deliberately — they are the point of the file. Each section says
what replaced it, so a future rebuild can see both the original design and where its ideas landed.

Deleting the rest also took the project from 9 `svelte-check` errors to **zero**: every remaining
error was a dangling `$lib/ui` or `$lib/features/*` import inside these unbuilt files.

## Overall verdict

The **feature-kernel idea** (a registry that features plug into, so the home page renders
itself from declarative metadata instead of a hand-maintained list) is worth reusing in some
form — it kept `+page.svelte` files trivial and made adding a tool a one-file change. The
**data-fetching approach** is not worth reusing: every feature calls third-party HTTP APIs
directly from the browser with `fetch()`, none of them go through the Rust `api_request` /
`get_cached_response` commands documented in [`backend-api.md`](./backend-api.md), and the
Qibla feature reads geolocation via the browser API instead of `tauri-plugin-geolocation`. See
"Known architectural problems" at the end of this document.

---

## `lib/ui` — feature kernel *(deleted)*

> Replaced by [`src/lib/tools/discover.ts`](../src/lib/tools/discover.ts) and
> [`src/lib/library/discover.ts`](../src/lib/library/discover.ts), which keep the one genuinely
> good idea here — glob-based auto-discovery — and throw away the registry/page/section
> indirection layered on top of it. The rebuild's version is ~10 lines against this kernel's
> twelve files.

### Models (`lib/ui/models/*.ts`)

- **`ToolDefinition`** (`tool.ts`) — a single tool/card: `id`, `name`, `description?`, `icon`
  (lucide icon name string, lucide itself was never installed), `route`, `collections: string[]`
  (which sections it shows up in, e.g. `"knowledge"`, `"generated"`), `generated?`, `hidden?`,
  `metadata?`.
- **`SectionDefinition`** (`section.ts`) — a titled block on a page: `id`, `title`,
  `view: "grid" | "list" | "carousel" | "custom"` (only `"grid"` was ever implemented), an
  optional `source: { collections, includeGenerated? }` that selects which tools populate it,
  or an optional `component` + `props` for a custom-rendered section (never implemented).
- **`PageDefinition`** (`page.ts`) — `id`, `title`, and an ordered list of section `id`s.
- **`NavigationDefinition`** (`navigation.ts`) — `id`, `name`, target `page`, `icon`,
  `location: "left" | "center" | "right"`, optional `tooltip`. Declared by the `home` feature
  but never actually rendered by any component — there was no nav bar.

### Kernel (`lib/ui/kernel/*.ts`)

- **`FeatureDefinition`** (`Feature.ts`) — the unit a feature exports: `id`, `name`, and
  optional arrays of `navigation`, `pages`, `sections`, `tools`.
- **`defineFeature(feature)`** (`defineFeature.ts`) — identity function used purely for type
  inference/authoring ergonomics (`export default defineFeature({...})`).
- **`Registry`** (`registry.ts`) — holds every registered feature and flattens their
  `pages`/`sections`/`tools`/`navigation` into `Map`s keyed by `id`. Last write wins on id
  collisions (no collision detection).
- **`Application`** (`Application.ts`) — thin wrapper around a `Registry` instance; exposes
  `.register()`, `.page()`, `.section()`, `.navigation()`, `.pages()`, `.sections()`,
  `.tools()`, and `.queryTools` (re-exported from `query.ts`).
- **`app`** (`app.ts`) — the single shared `Application` singleton every other module imports.
- **`queryTools(query)`** (`query.ts`) — filters `app.tools()` by `hidden`, `collections`
  (any-match), excludes `generated` tools unless `includeGenerated` is passed, optional
  `sort: "name"`, optional `limit`.
- **`initializeApplication()`** (`discover.ts`) — the entry point a route calls once. Uses
  Vite's `import.meta.glob("$lib/features/**/feature.ts", { eager: true })` to auto-import every
  feature module and `app.register()` each one's `default` export. Idempotent (`initialized`
  flag guard). This auto-discovery-by-glob-pattern is the main reusable trick: adding a feature
  is just adding a `feature.ts` file, no central import list to maintain.

### Rendering (`lib/ui/render/*.ts`, `lib/ui/components/*.svelte`)

- **`renderPage(pageId)`** (`render/page.ts`) — looks up a `PageDefinition`, resolves each of
  its section ids to a `SectionDefinition`, and for each section runs `app.queryTools(...)`
  against `section.source` to get the actual `ToolDefinition[]` to display. Returns a
  `RenderedPage` (`render/types.ts`: `{ definition, sections: { definition, tools }[] }`) or
  `null` if the page id doesn't exist.
- **`PageRenderer.svelte`** — given a `page` id prop, calls `renderPage` and loops over
  `rendered.sections`, rendering a `Section.svelte` for each.
- **`Section.svelte`** — renders a section's title, and if `view === "grid"`, a `ToolGrid`.
  Every other `view` value was a no-op (silently renders nothing).
- **`ToolGrid.svelte`** — a responsive 1/2-column grid of `<a class="tool-card">` cards, one per
  tool, linking to `tool.route`. Icons were never actually rendered (a static "☪" placeholder
  was used instead of `tool.icon`), so the icon field was defined but dead.

### `lib/ui/index.ts`

Barrel file re-exporting the kernel (`app`, `Application`, `Feature`, `defineFeature`) and the
four models. Features imported `defineFeature` and the model types through this barrel.

---

## `lib/services` — unused backend abstraction *(deleted)*

`Backend` interface (`backend.ts`, just `initialize(): Promise<void>`), a `MockBackend`
(`mock.ts`, `initialize()` only logs to console), and `index.ts` exporting a singleton
`backend = new MockBackend()`. **Nothing in the app ever imported `backend` from this module** —
it's a stub for a service-locator pattern that was never connected to anything. Not worth
carrying forward as-is; if a similar seam is wanted in the rebuild, it should be designed around
the real Tauri `invoke` calls from day one rather than added as an afterthought.

---

## `lib/features/*` — one per tool

Each feature folder had (a) an optional `feature.ts` registering it with the kernel, (b) a
`service.ts` doing data fetching/business logic, (c) a `*Page.svelte` component, and (d) a
route file under `routes/<name>/+page.svelte` that just rendered the component. The route files
were one-line re-exports with no reference value of their own and were all deleted.

Rebuilt features keep the same folder shape today under `src/lib/features/<name>/`, minus the
kernel registration — a `tool.ts` (home grid) or `library.ts` (Library grid) replaces it.

### `home` *(deleted — superseded)*

`feature.ts` only (no page/service) — registers the `home` navigation entry, the `knowledge`
and `generated` sections, all six tool cards (Feature Studio, Duas, Hadith, Sehri & Iftari,
Prayer Times, Qibla), and the `home` page (`knowledge` + `generated` sections). This is the
feature that made the old `routes/+page.svelte` just call `<PageRenderer page="home" />`.

### `quran` *(deleted — rebuilt at `src/lib/features/quran/`)*

- `models.ts`: `Surah { number, name, englishName, ayahCount }`,
  `Ayah { number, text, translation }`.
- `service.ts` (`QuranService`, singleton `quranService`): hits `api.alquran.cloud/v1` directly
  via `fetch`. `surahs()` → `GET /surah`. `ayahs(surahNumber)` → parallel
  `GET /surah/{n}` (Arabic) and `GET /surah/{n}/en.asad` (Asad translation), zipped together.
  10s abort-controller timeout on every call, friendly error messages on timeout/HTTP failure.
- `QuranPage.svelte`: surah list with a search box (matches English name, Arabic name, or
  number), and a reader view with "mushaf" (continuous Arabic text) vs "study" (per-ayah
  Arabic + translation) modes and an adjustable Arabic font-size slider.

### `prayer-times` *(deleted — rebuilt at `src/lib/features/prayer-times/`)*

- `service.ts` (`PrayerTimeService`, singleton `prayerTimeService`): hits
  `api.aladhan.com/v1/timingsByCity/{DD-MM-YYYY}` with `city`, `country`, `method` query params
  (`PrayerMethod = "1" | "3" | "4"`, i.e. Karachi/MWL/Umm al-Qura). Returns
  `{ fajr, sunrise, dhuhr, asr, maghrib, isha }` as `HH:mm` strings.
- `PrayerTimesPage.svelte`: city dropdown (hardcoded to four Pakistani cities) + method
  dropdown, a "next prayer" hero card with a live countdown (recomputed every 30s via
  `setInterval`), and a grid of all six timings.

### `qibla` *(deleted — rebuilt at `src/lib/features/qibla/`)*

- `service.ts`: pure-math `qiblaDirection(coordinates)` (great-circle bearing to the Kaaba,
  `{21.4225, 39.8262}`, plus 8-point compass label) — this function has no I/O and is directly
  reusable regardless of how location is obtained. Also exports a hardcoded `peshawar` fallback
  coordinate and `currentCoordinates()`, which wraps **`navigator.geolocation`** (browser API,
  not the Tauri plugin — see "Known architectural problems" below).
  See [`backend-api.md`](./backend-api.md#tauri-plugin-geolocation-android-only) for the plugin
  this should use instead.
- `QiblaPage.svelte`: tries `currentCoordinates()`, falls back to the Peshawar coordinate with a
  visible notice if location fails; renders an animated compass (pure CSS, rotates a needle by
  `--qibla-angle`) plus the bearing in degrees and compass label.

### `duas` *(deleted — rebuilt at `src/lib/features/duas/`)*

- `service.ts` (`DuaService`, singleton `duaService`): hits `ummahapi.com/api/duas` — a
  third-party API endpoint that was never verified as a real/stable, publicly documented service.
  `categories()` → `GET /categories`, `category(id)` → `GET /category/{id}`. **Treat this
  base URL as unverified/placeholder before reusing it.**
- `DuasPage.svelte`: category grid → dua list (search-filterable at each level) → single dua
  detail view (Arabic, transliteration, translation, source, repeat count).

### `hadith` *(still present — not rebuilt yet)*

- `service.ts` (`HadithService`, singleton `hadithService`): also hits `ummahapi.com/api/hadith`
  (same caveat as duas above — unverified third-party API). `collections()`, paginated
  `browse(collection, page)` (20/page), and `search(query, collection?)`.
- `HadithPage.svelte`: collection grid (filterable) → paginated hadith list, or search results
  across the current collection or all collections → single hadith detail view.

### `sehri-iftari` *(deleted — rebuilt at `src/lib/features/sehri-iftari/`)*

- `service.ts` (`SehriIftariService`, singleton `sehriIftariService`): hits
  `api.aladhan.com/v1/calendarByCity/{year}/{month}` for a full month of timings, parses each
  day into `FastingDay { date, weekday, hijri, imsak, fajr, maghrib }`.
- `SehriIftariPage.svelte`: free-text city/country inputs + method dropdown, a "next event" hero
  card (Sehri-ends-soon vs. Iftar-soon vs. tomorrow, live countdown via `setInterval`), today's
  three key times, and a scrollable month calendar with prev/next navigation.

### `feature-studio` *(still present — not rebuilt yet)*

- `service.ts`: the one feature that actually calls into Rust —
  `buildFeature(prompt)` → `invoke("build_feature", { prompt })` (see
  [`backend-api.md`](./backend-api.md#build_featureprompt-string-promisefeaturebuildresult)).
- `storage.ts`: `loadFeatures()` / `saveFeatures()` — generated features persisted to
  `localStorage` under key `deenlab.feature-studio.features`, as `GeneratedFeature[]`
  (`{ id, title, prompt, message, html, createdAt }`). No use of any Tauri filesystem API.
- `FeatureStudioPage.svelte`: prompt textarea → calls the service → on `decision: "generate"`
  saves the result and shows it in a sandboxed `<iframe sandbox="allow-scripts" srcdoc=...>`;
  on `"decline"` shows the model's explanation instead. Sidebar lists previously generated
  features (delete button per entry) sourced from `localStorage`.

---

## Known architectural problems (why this got discarded)

These are the reasons the rebuild happened. Points 1–3 and 5 are resolved in the current
front-end; point 4 turned out to be a false alarm. They stay listed because the two features
still sitting in `src/discarded/` (`hadith`, `feature-studio`) were written under all of them,
and whoever rebuilds those needs to know what to fix on the way through.

1. **Every data-fetching feature bypasses the Rust backend.** Quran, prayer-times, duas,
   hadith, and sehri-iftari all call third-party APIs with the browser's `fetch()` directly,
   instead of going through the `api_request` / `get_cached_response` Tauri commands. That means
   none of them get disk-backed caching, offline fallback, or a native HTTP client on Android —
   only `feature-studio` actually uses `invoke(...)`.
2. **Qibla uses `navigator.geolocation` instead of `tauri-plugin-geolocation`,** even though the
   plugin is installed, registered for Android in `lib.rs`, and has permissions already granted
   in `capabilities/default.json`. The browser geolocation API inside an Android WebView isn't
   guaranteed to behave like the native plugin and bypasses the Tauri capability system.
3. **`lib/services` (the `Backend`/`MockBackend` abstraction) was dead code** — designed but
   never actually used by any feature, so it added an indirection layer with no payoff.
4. ~~**Two third-party API base URLs (`ummahapi.com` for duas and hadith) were never confirmed
   as real, stable, documented services.**~~ *Resolved:* `ummahapi.com` was verified live during
   the Duas and Quran rebuilds — it is a real, key-free API and both features ship against it
   today. Its `/hadith/*` endpoints should still be re-checked when Hadith is rebuilt, since only
   the `/duas/*` and `/quran/*` ones have actually been exercised.
5. **No navigation UI was ever built**, despite `NavigationDefinition` and a `location` field
   existing in the model — every page was reached only by direct link/URL.
