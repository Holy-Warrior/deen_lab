# Frontend Architecture

How the current (non-discarded) front-end is put together: the app shell, routing, the tool
registry mechanism, and the shared conventions every feature follows. See
[`legacy-frontend.md`](./legacy-frontend.md) for what the first attempt did differently and why
it was set aside, and [`backend-api.md`](./backend-api.md) for everything this side calls into
on the Rust/Kotlin side.

## App shell

Every route renders inside `src/routes/+layout.svelte` → `AppShell.svelte`
(`src/lib/components/shell/`):

```
AppShell
├── TopBar            fixed top bar: menu button · "DeenLab" title · notification bell
│   ├── MenuDrawer         bits-ui Dialog styled as a left off-canvas panel
│   └── NotificationsPanel bits-ui Popover, empty-state only (no notification backend yet)
├── <main class="shell-main"> page content, {@render children()}
└── BottomNav          fixed bottom bar: Home / Library / Studio, active tab from the route
```

Three bottom-nav tabs, matching the three top-level routes:

| Tab | Route | Purpose |
|---|---|---|
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

```
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

## Getting the device's location: `DeviceLocation.svelte`

The whole acquire → classify-failure → retry/escalate → manual-fallback flow is long enough
that it was pulled out of Qibla (its first consumer) into a reusable, headless-ish component
any feature needing geolocation can drop in:

```text
src/lib/services/location.ts        Coordinates, currentCoordinates(), the 3 typed errors
src/lib/components/location/
  DeviceLocation.svelte              owns all the state/retry/fallback logic below
  CitySelector.svelte                bits-ui Combobox search-and-pick fallback
  cities.ts                          City type, fallbackLocation, the curated city list
```

`DeviceLocation` takes a `fallback: City` prop and a child snippet, and hands the snippet
`{ coordinates, locationName, isLoading, refresh }` — the feature only has to turn coordinates
into whatever it actually needs (a bearing, a lookup key, etc.):

```svelte
<DeviceLocation fallback={fallbackLocation}>
    {#snippet children({ coordinates, locationName, isLoading, refresh })}
        <!-- feature-specific rendering goes here -->
    {/snippet}
</DeviceLocation>
```

Internally it handles everything that made the original Qibla page long:
`currentCoordinates()` classifies every native geolocation rejection into one of three typed
errors (see `backend-api.md`'s geolocation section for the exact rejection strings matched);
a settings-redirect banner appears when Location services are off, auto-retrying via a
`document.visibilitychange` listener when the user returns to the app (there's no callback for
"user came back from Settings", so watching page visibility is the standard way to notice it);
a "Grant permission" banner escalates to the app's own Settings screen (plus a native Toast)
once Android stops showing its own permission prompt after one denial; and a `CitySelector`
fallback (search + pick from `cities.ts`) renders automatically whenever GPS genuinely can't
resolve. `fallbackLocation` is deliberately far from where this app is actually tested from
(Sydney), so a real GPS fix is visibly different from the fallback instead of looking identical
to it.

## Reference feature: Qibla

`src/lib/features/qibla/service.ts` is now just the pure bearing math (`qiblaDirection`) — all
device-location handling lives in `DeviceLocation.svelte` above. `QiblaPage.svelte` is a short
example of consuming it: wrap the compass markup in the child snippet and call
`qiblaDirection(coordinates)` inside it.
