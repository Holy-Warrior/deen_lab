# Credits & Attribution

This document is the source content for DeenLab's in-app "About / Credits" screen. It lists
every external data source, third-party API, and open-source dependency the app relies on, plus a
short note on how Islamic content is presented. It was compiled by reading the app's own source
code and, where a license or terms question couldn't be settled from the code alone, by checking
the provider's own site. Anything that could not be confirmed is labelled "not verified" rather
than guessed.

---

## 1. Data sources and APIs

### Aladhan API

- **Provides:** Daily prayer times and Hijri (Islamic) calendar conversions, used by the Prayer
  Times and Sehri & Iftari features.
- **Base URL:** `https://api.aladhan.com/v1/` — specifically `/v1/timings/{date}` (Prayer Times,
  `src/lib/features/prayer-times/service.ts`) and `/v1/calendar/{year}/{month}` (Sehri & Iftari,
  `src/lib/features/sehri-iftari/service.ts`).
- **API key:** Not required. This app's own requests carry no key or auth header of any kind, and
  the endpoints respond to plain unauthenticated `GET` requests.
- **Licensing / terms:** Could not verify a formal license or terms-of-use document. Aladhan's own
  "credits and terms" page (aladhan.com/credits-and-terms) states the API is provided "WITHOUT ANY
  WARRANTY" and that its prayer-time calculations are based on the open-source
  [Pray Times](http://praytimes.org) project by Hamid Zarrabi-Zadeh, but it does not publish a
  named software license (e.g. MIT) covering API usage. Treat this as a free public data service
  used at the app's own risk rather than a formally licensed dependency.

### UmmahAPI

- **Provides:** Quran text, transliteration, and translation (`/api/quran`), and Duas
  (`/api/duas`).
- **Base URL:** `https://ummahapi.com/api/` — used as `https://ummahapi.com/api/quran/...`
  (`src/lib/features/quran/service.ts`) and `https://ummahapi.com/api/duas/...`
  (`src/lib/features/duas/service.ts`).
- **API key:** Not required for the endpoints this app calls — this app's requests carry no key,
  and UmmahAPI's own site states basic use needs no signup, subject to a shared rate limit (an
  optional free key raises that limit, which this app does not use).
- **Licensing / terms:** Could not verify a formal license. UmmahAPI describes itself as
  "Free Forever, Built for the Ummah" but its site does not publish a named software or content
  license governing reuse of the API's output.

### ipwho.is

- **Provides:** Approximate IP-based geolocation (city/coordinates), used as a fallback in
  `src-tauri/src/ip_location.rs` only when the device's GPS location is unavailable or denied.
- **Base URL:** `https://ipwho.is/` (called from Rust, not the frontend, so the provider URL and
  response shape stay out of the WebView).
- **API key:** Not required. Confirmed both by this app's request (no key/auth) and by the
  provider's own documentation (ipwhois.io/docs), which states "No API key required" for the free
  endpoint.
- **Licensing / terms:** No formal content/software license published. The provider's documented
  free-tier terms: commercial use allowed, no uptime SLA, and a limit of 1,000 requests per day
  per client IP.

### OpenStreetMap Nominatim

- **Provides:** Reverse geocoding — turning a coordinate pair into a human-readable place name —
  used in `src/lib/services/location.ts` to label the device's approximate/active location.
- **Base URL:** `https://nominatim.openstreetmap.org/reverse`.
- **API key:** Not required.
- **Licensing / terms:** Verified against the official Nominatim Usage Policy
  (operations.osmfoundation.org/policies/nominatim). The parts that bind this app:
  - **Data license:** Results are OpenStreetMap data, licensed under the **Open Database License
    (ODbL)**, which requires attribution "suitable for your medium."
  - **User-Agent:** A generic/default User-Agent is not acceptable — the request must identify
    the application. This app already sets one: `DeenLab/1.0 (Islamic prayer-time and Qibla
    utility app)` (see `location.ts`).
  - **Rate limit:** A hard cap of 1 request per second, enforced overall (not per user). Bulk or
    scripted use is restricted further and must run from a single thread/machine.
  - **Prohibited uses:** No autocomplete-style querying, no systematic/grid-based reverse lookups,
    no scraping of full result details, and no reselling of geocoding results. Any app whose
    primary function is geocoding is expected to run its own instance rather than lean on the
    public server — this app's usage (occasional reverse lookups tied to prayer-time/Qibla
    location) sits well inside normal, incidental use, but this is worth re-checking if reverse
    geocoding usage ever grows.
- **In-app attribution required:** Yes — the OpenStreetMap/ODbL attribution requirement above
  means the credits screen itself is part of complying with these terms, not just a courtesy.

### sunnah.com (via the `freococo/sunnah_dataset` HuggingFace dataset)

- **Provides:** The Hadith corpus bundled into the app's offline database (see
  `tools/hadith/build_bundles.py` and `docs/hadith-data.md`).
- **Origin:** The Arabic text, English translations, and gradings originate from **sunnah.com**,
  which itself draws on hadith collections whose English translations are the copyrighted work of
  their respective translators and publishers — Darussalam is the most common publisher credited
  in the grading data (`docs/hadith-data.md` notes "Sahih/Darussalam" as the most frequent grading
  source), alongside individual scholars such as Al-Albani for other gradings.
- **Distribution path:** The data was pulled from the HuggingFace dataset
  `freococo/sunnah_dataset` (`https://huggingface.co/datasets/freococo/sunnah_dataset`) rather
  than scraped directly from sunnah.com.
- **Licensing:** Verified on the dataset's HuggingFace page — it is published under
  **CC BY-NC-SA 4.0** (Attribution, NonCommercial, ShareAlike). This is a **NonCommercial**
  license, which is a real constraint worth flagging explicitly to whoever ships this app: it
  permits sharing and adapting the data, with attribution, only for non-commercial use, and any
  redistribution must carry the same license. The underlying sunnah.com text and its translators'
  copyrights sit above this license and are not superseded by it.

### Groq (AI "Feature Studio")

- **Provides:** Powers an experimental "Feature Studio" tool that generates small, self-contained
  Islamic-learning HTML mini-tools from a prompt (`src-tauri/src/lib.rs`,
  `docs/backend-api.md`).
- **Base URL:** `https://api.groq.com/openai/v1/chat/completions`.
- **API key:** Required, and **not bundled with the app**. The key lives in
  `src-tauri/src/groq_config.rs`, a file that is `.gitignore`d and must be created locally by
  copying `src-tauri/src/groq_config.example.rs` (which ships with an empty key) and filling in a
  real one. Concretely: **as shipped from this repository, Feature Studio is inert** unless
  whoever builds the app supplies their own Groq key at build time.
- **Licensing / terms:** Could not fully verify. Groq's public "Terms of Use" page covers website
  access only and explicitly defers actual API/cloud-service usage to a separate "Groq Services
  Agreement," which was not reviewed here. No content-reuse license is published for API output.

### QCF Quran fonts (reference only — not shipped)

- **What it is:** `docs/frontend-architecture.md` documents that a page-accurate Mushaf rendering
  mode was prototyped using the King Fahd Quran Complex's own QCF (Quran Complex Font) files and
  page-layout JSON, sourced from the GitHub repository
  [`MohamadHajjRabee/quran-qcf4`](https://github.com/MohamadHajjRabee/quran-qcf4).
- **Status in this app: not included.** That prototype was deliberately reverted and is not part
  of the current codebase or build — it exists only as external reference material on the project
  owner's own machine, kept in case the feature is revisited.
- **Licensing:** The font files are stated to be provided "for Quranic rendering purposes" only.
  This is a use-restriction, not a redistribution grant — the repository does not publish explicit
  terms permitting the fonts to be bundled/redistributed inside another app. Consistent with that,
  `docs/frontend-architecture.md` notes the fonts would need to be fetched live from the source
  per device, "never vendored into this repo." **This app currently distributes none of these font
  files.**

### Other external URLs found in the repository

A repository-wide search for `https://` across `src/`, `src-tauri/src/`, and `docs/` turned up no
additional third-party data/API endpoints beyond the ones above. The only other external links
found were documentation references (svelte.dev, v2.tauri.app, github.com/rust-lang/cargo,
praytimes.org as cited by Aladhan) rather than services the app calls at runtime.

---

## 2. Open-source software

Licenses below were read from each package's own metadata — `license` fields in
`node_modules/<pkg>/package.json` for npm packages, and the crates.io registry metadata for Rust
crates — not assumed from memory. This list covers **direct, top-level dependencies only**, not
their full transitive trees, and reflects `package.json` / `src-tauri/Cargo.toml` /
`src-tauri/plugins/*/Cargo.toml` as read on 2026-08-17. The Rust dependency list is expected to
change soon (a SQLite layer and a notification plugin were mid-integration at the time of this
reading) — refresh this section whenever dependencies change rather than trusting it to stay
current.

### Frontend (npm)

| Package | Role in this app | License |
|---|---|---|
| `svelte` | UI framework (Svelte 5, runes-based reactivity) | MIT |
| `@sveltejs/kit` | Application framework / routing, built on Svelte | MIT |
| `@sveltejs/adapter-static` | Builds the app as static output for Tauri to embed | MIT |
| `@sveltejs/vite-plugin-svelte` | Svelte integration for Vite | MIT |
| `vite` | Frontend build tool / dev server | MIT |
| `typescript` | Static typing for the frontend codebase | Apache-2.0 |
| `svelte-check` | Type-checking for `.svelte` files | MIT |
| `tailwindcss` | Utility-first CSS styling | MIT |
| `@tailwindcss/vite` | Vite integration for Tailwind CSS | MIT |
| `bits-ui` | Headless, accessible UI primitives (dialogs, selects, etc.) | MIT |
| `@lucide/svelte` | Icon set used throughout the UI | ISC |
| `@tauri-apps/api` | JS bindings for calling into the Tauri/Rust backend | Apache-2.0 OR MIT |
| `@tauri-apps/cli` | Tauri's build/dev CLI tooling | Apache-2.0 OR MIT |
| `@tauri-apps/plugin-geolocation` | JS bindings for the device GPS plugin | MIT OR Apache-2.0 |
| `@tauri-apps/plugin-opener` | JS bindings for opening external links/apps | MIT OR Apache-2.0 |

### Backend / Rust (`src-tauri`)

| Crate | Role in this app | License |
|---|---|---|
| `tauri` | Native application shell / webview host | Apache-2.0 OR MIT |
| `tauri-build` | Build-time codegen for Tauri | Apache-2.0 OR MIT |
| `tauri-plugin-opener` | Opens external links/apps from Rust | Apache-2.0 OR MIT |
| `tauri-plugin-notification` | Local device notifications | Apache-2.0 OR MIT |
| `tauri-plugin-geolocation` | Native Android GPS access (Android target only) | Apache-2.0 OR MIT |
| `serde` / `serde_json` | Data (de)serialization, used throughout the backend | MIT OR Apache-2.0 |
| `reqwest` | HTTP client shared by every backend network call (Aladhan, UmmahAPI, ipwho.is, Nominatim, Groq) | MIT OR Apache-2.0 |
| `rusqlite` (bundled SQLite) | Local database powering the offline Hadith bundles (compiled from source specifically to guarantee FTS5 full-text search is present, since Android's system SQLite can't be relied on for it) | MIT |
| `unicode-normalization` | Arabic text normalization (NFD) for Hadith search | MIT OR Apache-2.0 |
| `flate2` | Compression for the Hadith data bundles | MIT OR Apache-2.0 |
| `sha2` | Checksums/integrity for the Hadith data bundles | MIT OR Apache-2.0 |
| `futures-util` | Async utilities used alongside `reqwest`/`tauri` | MIT OR Apache-2.0 |

### First-party native plugins

Two small Tauri plugins under `src-tauri/plugins/` are written and maintained as part of this
project itself, not third-party dependencies, but are listed here for completeness since they
carry their own `Cargo.toml` and license declaration:

| Plugin | Role in this app | License |
|---|---|---|
| `tauri-plugin-compass` | Streams live device-heading updates (magnetometer/accelerometer, gyroscope fallback) for the rotating Qibla compass | MIT |
| `tauri-plugin-device-settings` | Opens native Android settings screens (e.g. Location) from within the app | MIT |

---

## 3. Islamic content notes

- **Prayer times are calculated, not authoritative.** This app computes prayer times using
  published astronomical calculation methods — Karachi, Muslim World League (MWL), and Umm
  al-Qura are the selectable options in the Prayer Times screen — via the Aladhan API. Calculated
  times can differ slightly from a local mosque's own printed timetable, particularly for Fajr and
  Isha, where different methods diverge most. Where a difference exists, a local mosque or
  authority's timetable should be preferred.
- **Qibla direction is a great-circle bearing.** The direction shown points along the shortest
  path over the Earth's curved surface from the device's current coordinates to the Kaaba in
  Makkah, computed from spherical trigonometry rather than a straight line on a flat map.
- **Hadith gradings are reproduced, not judged.** Any authenticity grading shown alongside a
  Hadith (e.g. Sahih, Hasan, Da'if) is the grading recorded in the underlying source data, most
  commonly attributed to Darussalam's published grading or to individual scholars such as
  Al-Albani. This app does not evaluate or assign gradings itself — it displays what the source
  material already records.

---

## What could not be verified

For transparency, the specific points in this document that could not be confirmed from an
authoritative source, and why:

- **Aladhan API**: no published software/content license was found, only a general "no warranty"
  disclaimer on its credits-and-terms page; whether an API key is technically optional or simply
  unenforced could not be confirmed beyond observing this app's own keyless requests work.
- **UmmahAPI**: no published software/content license was found on the provider's site.
- **ipwho.is**: no content/software license beyond its stated free-tier usage terms (rate limit,
  commercial use allowed, no SLA).
- **Groq**: the terms governing actual API usage (the "Groq Services Agreement") were not
  reviewed — only the general website Terms of Use, which explicitly says it doesn't cover cloud
  API usage.
- **QCF fonts**: no explicit redistribution license was found for the font files themselves,
  only the "for Quranic rendering purposes" restriction quoted in this app's own architecture
  docs — moot for now since this app does not ship or fetch these fonts.
