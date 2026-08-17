# DeenLab

A Tauri v2 mobile app (primary target: Android) for Islamic daily-practice tools — prayer
times, Qibla direction, Sehri & Iftari timings, and more, with an AI-assisted "Feature Studio"
for generating small self-contained tools on demand.

Frontend: SvelteKit 5 (runes) + Tailwind CSS 4 + bits-ui. Backend: Rust via Tauri 2, with a
small local native plugin for Android-specific functionality (see below).

## Docs

- [`docs/backend-api.md`](docs/backend-api.md) — every Rust command and plugin exposed to the
  front-end, and the capability files that gate them.
- [`docs/frontend-architecture.md`](docs/frontend-architecture.md) — the app shell, routing,
  the tool-registry mechanism (how a new tool gets added to the home grid), and the shared
  conventions (error display, cache-then-network data fetching) every feature follows.
- [`docs/legacy-frontend.md`](docs/legacy-frontend.md) — what the first-pass front-end did, and
  which of its ideas were carried into the rebuild. Most of that code has now been deleted as
  each feature got rebuilt, so this doc is the surviving record of it.

## Getting started

```sh
npm install
```

**Desktop dev** (fastest inner loop, no plugins that are Android-only will do anything):

```sh
npm run tauri dev
```

**Android dev** (real device or emulator connected via `adb`):

```sh
npm run tauri android dev
```

**Groq API key** (only needed for the Feature Studio tool): copy
`src-tauri/src/groq_config.example.rs` to `src-tauri/src/groq_config.rs` and fill in a real key.
That file is gitignored — every machine needs its own copy.

## Project layout

```text
src/
  routes/                 SvelteKit routes -- thin, just render a feature's page component
  lib/
    components/shell/     top bar, bottom nav, drawer, notifications -- see frontend-architecture.md
    components/home/      home-tab pieces (next-prayer card, tool grid)
    components/common/    shared UI (ErrorBanner)
    tools/                the tool-registry mechanism (types + glob-based discovery)
    services/             cross-feature helpers (apiCache, deviceSettings)
    features/<name>/      one folder per feature: service.ts, <Name>Page.svelte, tool.ts
  discarded/              only the not-yet-rebuilt first-pass features (hadith,
                            feature-studio) -- everything else deleted, see legacy-frontend.md

src-tauri/
  src/                    main Rust app crate (commands, setup)
  plugins/device-settings/  local Android-only plugin (Settings screens, Toast) -- see backend-api.md
  capabilities/           default.json (all platforms) + mobile.json (Android-only permissions)

docs/                     see above
```
