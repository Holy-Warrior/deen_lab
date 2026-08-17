# Frontend Architecture

How the current (non-discarded) front-end is put together: the app shell, routing, the tool
registry mechanism, and the shared conventions every feature follows. See
[`legacy-frontend.md`](./legacy-frontend.md) for what the first attempt did differently and why
it was set aside, and [`backend-api.md`](./backend-api.md) for everything this side calls into
on the Rust/Kotlin side.

## App shell

Every route renders inside `src/routes/+layout.svelte` → `AppShell.svelte`
(`src/lib/components/shell/`):

```text
AppShell
├── TopBar            fixed top bar: menu button · "DeenLab" title · notification bell
│   ├── MenuDrawer         bits-ui Dialog styled as a left off-canvas panel
│   └── NotificationsPanel bits-ui Popover, empty-state only (no notification backend yet)
├── <main class="shell-main"> page content, {@render children()}
└── BottomNav          fixed bottom bar: Home / Library / Studio, active tab from the route
```

Three bottom-nav tabs, matching the three top-level routes:

| Tab | Route | Purpose |
| --- | --- | --- |
| Home | `/` | Greeting, prayer-time card (still a placeholder), auto-rendered tool grid |
| Library | `/library` | Reading material — Quran, Hadith, Duas, etc. (placeholder page for now) |
| Studio | `/feature-studio` | AI Feature Studio (placeholder page for now) |

`TopBar`'s menu/notification buttons own their `Dialog`/`Popover` state internally (each is a
self-contained component with its own trigger button + content) rather than `AppShell` owning
shared open/closed state — simpler once bits-ui's Trigger/Content coupling is accounted for,
since the visual button *is* the bits-ui `Trigger`, not a separate element next to it.

**Safe-area insets**: `src/app.html`'s viewport meta includes `viewport-fit=cover`, which is
what makes `env(safe-area-inset-*)` resolve to real pixel values instead of `0` — required
because the Android WebView here renders edge-to-edge, under the status bar and gesture bar.
`.top-bar`/`.bottom-nav`/`.drawer-panel` in `src/app.css` all add the relevant inset to their
`height`/`padding` (not just padding alone — everything is `box-sizing: border-box`, so padding
without a matching height increase would shrink the visible content area instead of pushing it
clear of the system bar).

## The tool-registry mechanism

The empty-space area on the home tab auto-renders whatever tools are registered, with **no
central list to maintain**:

```text
src/lib/tools/
  types.ts      ToolDefinition: { id, name, description?, icon: Component, route }
  discover.ts   import.meta.glob("$lib/features/**/tool.ts", { eager: true }) at build time
```

To add a tool to the home grid, drop a `tool.ts` file next to a feature's other files:

```ts
// src/lib/features/<name>/tool.ts
import { Compass } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "qibla",
    name: "Qibla",
    description: "Find the direction of the Kaaba",
    icon: Compass,          // a real component, not a name string looked up elsewhere
    route: "/qibla"
} satisfies ToolDefinition;
```

`src/lib/components/home/ToolGrid.svelte` renders whatever `discover.ts` collects as tiles in a
2-column grid, falling back to empty dashed placeholder slots when nothing's registered yet.
This mirrors the glob-based auto-discovery trick from the original (discarded) feature kernel —
the one part of it worth keeping, per `legacy-frontend.md`'s verdict — minus the parts that
never actually worked there: icons are real `@lucide/svelte` components now instead of
unrendered name strings, and there's no unused `Backend`/`MockBackend`-style abstraction sitting
next to it.

**The Library tab has its own, identically-shaped registry** — `src/lib/library/discover.ts`
globs `$lib/features/**/library.ts` (not `tool.ts`) and `LibraryGrid.svelte`
(`src/lib/components/library/`) renders it the same way `ToolGrid` does. A feature drops a
`library.ts` file to appear in Library, a `tool.ts` file to appear on Home, both, or neither —
whichever fits what the feature actually is. Quick, time-sensitive actions (Qibla, Sehri &
Iftari) register `tool.ts`; reference/reading content (Duas, Quran) registers `library.ts`. Both
marker files export the same `ToolDefinition` shape from `$lib/tools/types`, reused rather than
duplicated since Library entries need nothing extra beyond `{ id, name, description?, icon,
route }`.

## Shared conventions every feature follows

**Error display** — a single convention, applied consistently: a dismissible-by-resolution
inline banner (`src/lib/components/common/ErrorBanner.svelte`, `.error-banner` in `app.css`)
placed above the content it failed to load/refresh, *not* a blocking dialog. Cached or
fallback content stays visible underneath while the banner explains what went wrong.
`onRetry` is optional (omit it when there's genuinely nothing to retry, e.g. a device with no
location hardware at all); `retryLabel` defaults to "Try again" but can be overridden
("Grant permission", "Go to location settings") when the retry action isn't a generic reload.

**Data fetching that goes over the network** — route it through
`src/lib/services/apiCache.ts`'s `loadCacheThenNetwork()` (paints from disk cache immediately if
present, then always still makes the real network request) rather than calling `fetch()`
directly from a Svelte component. See `backend-api.md` for the two Rust commands underneath it,
and `sehri-iftari/service.ts` for the reference usage.

**Svelte 5 runes throughout** — every component written in this pass uses `$state`/`$derived`/
`$props`/`$bindable`, not the legacy `let` + `$:` reactive style the original (discarded)
front-end used. `$derived.by(() => ...)` is used where the derivation needs more than a single
expression (e.g. `CitySelector.svelte`'s search filter).

**Route files are thin** — `src/routes/<name>/+page.svelte` just imports and renders
`src/lib/features/<name>/<Name>Page.svelte`. All the actual logic lives in the feature folder
under `lib/`, not in `routes/`.

**In-page drill-down state (list → detail inside one route) needs to opt in to the hardware back
button, or it exits the feature instead of stepping back one screen** — see
[`android-back-navigation.md`](./android-back-navigation.md) for why (Tauri's Android WebView
maps the back button to browser-style history, which plain `$state` never populates) and the
fix (SvelteKit shallow routing, `pushState`/`page.state`, not a hand-rolled `popstate`
listener). `DuasPage.svelte` is the reference implementation.

**Styling a bits-ui child component needs global CSS, not a scoped `<style>` block** — a
component's scoped-CSS hash class only ever lands on elements that component renders directly;
it never reaches inside a child component like `Tabs.Trigger` or `Combobox.Content`, even
though `class="..."` passed to one of those does reach the real DOM node underneath. A scoped
rule targeting it will look correct, pass Svelte's own unused-selector check, and simply never
match at runtime. `.popover-panel` (styling `Combobox.Content`, see `CitySelector.svelte`) and
`.view-tabs`/`.view-tabs__trigger` (styling `Tabs.List`/`Tabs.Trigger`, see
`SehriIftariPage.svelte`) both live in `app.css` for exactly this reason — anything styling a
bits-ui component (as opposed to a plain HTML element written directly in your own template)
belongs there too.

## Getting the device's location: `DeviceLocation.svelte`

The whole acquire → classify-failure → retry/escalate → manual-fallback flow is long enough
that it was pulled out of Qibla (its first consumer) into a reusable, headless-ish component
any feature needing geolocation can drop in:

```text
src/lib/services/location.ts        Coordinates, currentCoordinates(), placeName(), LocationStatus, the 3 typed errors
src/lib/components/location/
  DeviceLocation.svelte              owns all the state/retry/fallback logic below
  LocationStatusRow.svelte           name + color-coded sync icon, reads DeviceLocation's own props
  CitySelector.svelte                bits-ui Combobox search-and-pick fallback
  cities.ts                          City type, fallbackLocation, the curated city list
```

`DeviceLocation` takes a `fallback: City` prop, an optional `onCoordinatesChange` callback, and
a child snippet, and hands the snippet `{ coordinates, locationName, isLoading, status, refresh }`
— the feature only has to turn coordinates into whatever it actually needs (a bearing, a lookup
key, etc.):

```svelte
<DeviceLocation fallback={fallbackLocation} onCoordinatesChange={(coordinates) => ...}>
    {#snippet children({ coordinates, locationName, isLoading, status, refresh })}
        <!-- feature-specific rendering goes here -->
    {/snippet}
</DeviceLocation>
```

**`onCoordinatesChange`** is for a consumer that needs to *react* to a new position (e.g.
re-fetching a monthly calendar) rather than just reading it during its own render. It's called
from `refresh()`/`selectCity()` inside `DeviceLocation.svelte` — plain script functions, not
from the rendered snippet — because **Svelte 5 forbids mutating `$state` inside a template
expression** (`{@const _ = (someState = value)}` throws `state_unsafe_mutation` at runtime, not
compile time — it looks like it should work and doesn't). If a feature needs to trigger a side
effect (like a `$effect`-driven fetch) off DeviceLocation's coordinates, mirror them into the
feature's own `$state` via this callback instead of trying to assign state from inside the
snippet. See `SehriIftariPage.svelte` for the reference usage.

**`status`** (`LocationStatus`: `"loading" | "active" | "inactive" | "unavailable"`) is a
coarser signal than the failure banner — "is this the device's real, synced location right
now?" — meant for a status-colored affordance. `LocationStatusRow.svelte` is the standard
rendering of it: the location name on the left, a status-icon-button on the right
(grey/disabled while loading or unavailable, red/inactive when showing a fallback or manually
picked city, green/active when live and synced) that calls `refresh` on tap. Any feature
consuming `DeviceLocation` should reach for `LocationStatusRow` rather than re-rendering this
by hand:

```svelte
<LocationStatusRow {locationName} {isLoading} {status} onSync={refresh} />
```

Internally `DeviceLocation` handles everything that made the original Qibla page long:
`currentCoordinates()` classifies every native geolocation rejection into one of three typed
errors (see `backend-api.md`'s geolocation section for the exact rejection strings matched);
a settings-redirect banner appears when Location services are off, auto-retrying via a
`document.visibilitychange` listener when the user returns to the app (there's no callback for
"user came back from Settings", so watching page visibility is the standard way to notice it);
a "Grant permission" banner escalates to the app's own Settings screen (plus a native Toast)
once Android stops showing its own permission prompt after one denial; a `CitySelector`
fallback (search + pick from `cities.ts`) renders automatically whenever GPS genuinely can't
resolve; and once coordinates are live, `placeName()` reverse-geocodes them (OpenStreetMap
Nominatim, `accept-language=en` forced so results are Latin-script regardless of the locality's
own language) into a real name like "Peshawar, Pakistan" instead of a generic "Your current
location" label. `fallbackLocation` is deliberately far from where this app is actually tested
from (Sydney), so a real GPS fix is visibly different from the fallback instead of looking
identical to it.

## Reference feature: Qibla

`src/lib/features/qibla/service.ts` is now just the pure bearing math (`qiblaDirection`) — all
device-location handling lives in `DeviceLocation.svelte` above. `QiblaPage.svelte` wraps the
compass markup in the child snippet and calls `qiblaDirection(coordinates)` inside it.

The compass itself is a live, rotating dial (`services/compass.ts` + `tauri-plugin-compass`,
see `backend-api.md`), structured so only **one** element's transform changes per sensor tick:
`.compass__dial` rotates by `-heading`, and everything inside it (tick marks, the "N" mark, the
needle) rides along for free via ordinary CSS transform composition instead of each
recomputing its own screen angle every frame. `MosqueIcon.svelte` (a hand-drawn inline SVG
silhouette, not a raster asset) sits in a fixed badge *outside* `.compass__dial` deliberately —
early on it was inside the dial and spun with it, which read as visually distracting rather
than informative, so it was pulled out to stay upright. When `tauri-plugin-compass` reports
`"gyroscope"` or `"none"` mode, an inline caveat (never a popup) explains the needle is
approximate or static — see `.compass-note` in `QiblaPage.svelte`.

## Reference feature: Sehri & Iftari

`src/lib/features/sehri-iftari/service.ts` calls Aladhan's **coordinate-based** `calendar`
endpoint (not `calendarByCity`) so it can be driven directly by `DeviceLocation`'s coordinates,
the same as Qibla, with no separate manual city/country form — `DeviceLocation` already has its
own manual-city fallback built in for when GPS isn't usable.

Because fetching a month of data is an expensive network call that must *not* re-run on every
render (unlike Qibla's cheap, synchronous `qiblaDirection()`), `SehriIftariPage.svelte` mirrors
`DeviceLocation`'s coordinates into its own `$state` via the `onCoordinatesChange` callback
described above, then a top-level `$effect` (tracking that state plus the calculation method
and visible month) triggers the actual fetch. This is the reference example for "a feature
needs to react to a location change with a side effect," as opposed to Qibla's "just read the
coordinates during render."

The calendar has two views, toggled with a centered, enlarged bits-ui `Tabs` pill
(`.view-tabs`/`.view-tabs__trigger` in `app.css` — see the scoped-CSS-vs-child-component note
above for why they're global) defaulting to **Grid**:

- **Grid** — a traditional 7-column month grid. Each cell only has room for a day number and a
  small Hijri day number (not three prayer times at mobile width), so tapping a cell shows that
  day's full times in a detail card below the grid instead of cramming them into the cell or
  opening a popup.
- **List** — one card per day, all three times shown inline.

The "today" card (replacing what used to be four separate cards — a big banner plus three flat
stat cards, which took a lot of space to say very little) reuses the grid view's day-detail-card
layout, but with the one time slot that's actually relevant right now — `.today-slot--session`
(filled solid, "you can act on this right now," e.g. still inside the Sehri eating window) or
`.today-slot--upcoming` (outlined only, "next up but not here yet," e.g. Iftar while still
fasting) — visually distinct from the other two, plus a live `HH:MM:SS` countdown (ticking every
second, not every 30, specifically so the seconds digit moves and it reads as "live").

## Reference feature: Duas

`src/lib/features/duas/service.ts` calls UmmahAPI's `/api/duas/categories` and
`/api/duas/category/{id}` endpoints through `loadCacheThenNetwork`, the same cache-then-network
pattern as Sehri & Iftari. Registers only `library.ts` (no `tool.ts`) — a browse-and-read
feature, not a quick daily-glance one, so it belongs in Library, not Home.

`DuasPage.svelte` is a two-level drill-down (categories → duas-in-category → dua detail) inside
one route, using the shallow-routing pattern from `android-back-navigation.md` so the hardware
back button steps back one screen at a time. Category tiles reuse `.tool-card` (the same class
Home's `ToolGrid` uses) for visual consistency between an actual tool tile and a plain clickable
card. Two real bugs worth remembering if this pattern comes up again elsewhere:

- **`let x: T | null = $state(null)` (type annotation on the `let`) mis-narrows to `never`** in
  svelte-check at every later `x ? x.prop : ...`/`x?.prop` read — a reproducible tooling quirk,
  not a real type error. `let x = $state<T | null>(null)` (generic on `$state` itself) avoids it.
  Applies project-wide, not just to Duas.
- **`line-clamp-N` combined with Tailwind's `block` utility on the same element silently loses
  its clamp** — both set `display`, and `block` (whichever comes later in the generated
  stylesheet) wins over `line-clamp`'s own `display: -webkit-box`. Don't pair them.

## Reference feature: Quran

`src/lib/features/quran/service.ts` calls UmmahAPI's `/quran/surahs` and `/quran/surah/{n}`
endpoints — the latter returns Arabic text, transliteration, and a `translations` dict keyed by
translator per verse; this app picks `sahih_international` as the one English translation shown,
always alongside the transliteration, rather than adding a translation picker. `QuranPage.svelte`
is a single-level drill-down (surah list → verse-by-verse reading view), same shallow-routing
back-button pattern as Duas. Registers only `library.ts`, same reasoning as Duas.

**A Mushaf (page-accurate Arabic-only) reading mode was built, tested, and then deliberately
reverted** — not because it doesn't work, but because it took much longer to get right than the
task warranted, and the decision on which rendering approach to ship long-term wasn't settled.
Two approaches were built and are **not** in this codebase, kept only as external reference
material (a compressed PDF + a link to the font/data source, on the project owner's own machine,
outside the repo) in case either is picked back up:

- **QCF (Quran Complex Font)** — King Fahd Quran Complex's own per-page fonts + page-layout JSON
  ([MohamadHajjRabee/quran-qcf4](https://github.com/MohamadHajjRabee/quran-qcf4)), rendering each
  Mushaf page as real vector text (glyphs positioned to reproduce the exact printed line-breaks)
  rather than an image. Real body pages always have exactly 15 lines (confirmed against the page
  data itself — only the opening two pages have fewer). Small per-page payloads (a font is ~1MB,
  a page's JSON layout ~10-30KB), sharp at any zoom, but the font files are licensed "for
  Quranic rendering purposes" only — not for redistribution — so they'd need to be fetched live
  from the source per device, never vendored into this repo.
- **A scanned PDF** (a real, compressed ~57MB Uthmani Mushaf scan) rendered page-by-page via
  `pdfjs-dist`. Two real bugs were found and fixed before it was reverted, worth knowing if a
  similar pinch-zoom-on-a-fixed-frame UI is ever built again: (1) applying a zoom/pan action to
  the *same* element that has `overflow: hidden` scales the clip boundary right along with the
  content, so a zoomed-in view spills out over the surrounding UI instead of staying cropped —
  the transformed layer and the clipping viewport need to be two separate nested elements; (2)
  `pdfjs-dist`'s default chunked/Range-request PDF loading fails outright (`"Failed to fetch"`,
  no further detail surfaced to JS) when proxied through Tauri Android's dev-mode
  `http://tauri.localhost` asset layer, which doesn't forward HTTP Range semantics the way
  pdf.js's probe request expects — `disableRange`/`disableStream` in `pdfjs-dist`'s
  `DocumentInitParameters` forces one plain whole-file GET instead, sidestepping it.

Anyone picking this back up should start from the QCF link above, not the PDF — it's the better
long-term fit (smaller, sharper, no licensing question about vendoring), the PDF route was only
ever a "get something working today" compromise.
