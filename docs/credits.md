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
- **Licensing / terms:** Verified directly against both `aladhan.com/credits-and-terms` and its
  duplicate at `islamic.network/terms-and-conditions.html` (Aladhan is operated by Islamic
  Network). Both pages are short and contain, in full, only:
  - A blanket warranty disclaimer: "made available in the hope that they will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
    PARTICULAR PURPOSE."
  - A note that prayer-time calculations are "based on the calculations, methods and formulas
    discussed on [praytimes.org](http://praytimes.org)" (the open-source Pray Times project by
    Hamid Zarrabi-Zadeh).
  - Neither page contains **any** clause on commercial use, attribution, rate limits, or
    caching/bundling of responses — those topics simply aren't addressed anywhere in Islamic
    Network's published terms. That silence cuts both ways: nothing here forbids this app's
    caching-to-disk behaviour, but nothing formally permits it either.
  - **On the "GPL-3.0" claim:** search results surface a GPL-3.0 license, but it belongs to
    `aladhan/api-client` — an abandoned, third-party-maintained **PHP client SDK** for calling the
    REST API (confirmed on its Packagist listing), not to the API service, its terms, or the data
    it returns. This app calls the REST API directly over HTTP via `reqwest` and does not use that
    SDK, so this GPL-3.0 license does not apply to or encumber this app in any way.
  - **Rate limits:** community discussion (Islamic Network's own forum) is reported elsewhere to
    mention per-IP throttling around 12 requests/second, but the forum is a JavaScript-rendered
    app whose content could not be retrieved directly to confirm the exact wording or attribute it
    to a maintainer. Treat any specific number as an unverified community report, not a documented
    policy — Islamic Network's actual terms pages state no rate limit at all.
  - **Net assessment:** this remains a free public data service used at the app's own risk, with
    no formal software/content license and no explicit commercial-use grant, but also with no
    explicit prohibition on the kind of moderate, cached, non-commercial-resale use this app makes
    of it.

### UmmahAPI

- **Provides:** Quran text, transliteration, and translation (`/api/quran`), and Duas
  (`/api/duas`).
- **Base URL:** `https://ummahapi.com/api/` — used as `https://ummahapi.com/api/quran/...`
  (`src/lib/features/quran/service.ts`) and `https://ummahapi.com/api/duas/...`
  (`src/lib/features/duas/service.ts`).
- **API key:** Not required for the endpoints this app calls — this app's requests carry no key,
  and UmmahAPI's own site states basic use needs no signup, subject to a shared rate limit (an
  optional free key raises that limit, which this app does not use).
- **Licensing / terms:** Confirmed there is **no discoverable Terms of Service, Privacy Policy, or
  License page anywhere on the site.** Every link in the homepage's navigation and footer was
  enumerated directly (`ummahapi.com`) — Services, Prayer Times, Tools, Widgets, Blog, Docs,
  Sponsor, Get API Key, Discord, Dashboard, API Status, and several individual free-tool pages —
  and none of them is a terms/privacy/license page; `/terms` returns a 404. UmmahAPI describes
  itself as "Free Forever, Built for the Ummah," and its docs/marketing pages state rate limits
  inconsistently (`/api/docs` states "up to 100 requests per minute" for anonymous use, while
  another page states "5,000 / 15 min" general and "300 / min" for calculations) — this
  inconsistency itself is a sign the service is informally run rather than governed by a fixed,
  published policy.
  - **This is itself the important finding, stated plainly:** this app depends on a single free
    service, run informally, with **no license, no SLA, no attribution requirement, and no
    published terms of any kind** — meaning there is also no written commitment that the service
    will keep existing, keep its current shape, or keep being free. The operational risk is not
    that the app is violating a term (there are none to violate) but that the dependency itself is
    unusually fragile for something a shipped app relies on for two entire features (Quran and
    Duas). If UmmahAPI disappears or changes its response shape without notice, both features break
    with no recourse, and there is no license to point to that would obligate advance notice.
  - **Underlying Quran translation copyright is a separate question from the API's terms**, and
    was checked independently:
    - **Sahih International:** its copyright/licensing terms could not be pinned to a single
      authoritative source — it is published by Dar Abul Qasim/Al-Muntada Al-Islami and is widely
      mirrored (Internet Archive, kalamullah.com, and others) as a freely downloadable text, but no
      page found states a formal redistribution license, and it was not possible to confirm from a
      primary source which upstream text UmmahAPI itself pulls from. Treat this translation's
      redistribution rights as **not resolved**, independent of UmmahAPI's own (nonexistent) terms.
    - **Pickthall** (*The Meaning of the Glorious Koran*, 1930): confirmed via Wikipedia's article
      on the translation that it is public domain in death-plus-70 jurisdictions (e.g. UK/EU, since
      2006) and death-plus-50 jurisdictions (e.g. Pakistan, Canada, Australia), since Pickthall died
      in 1936. However, the same source states it is "technically not in the public domain in the
      US, because it was published in India after 1922" — a US-specific wrinkle worth flagging
      since this app targets Google Play, whose store terms are anchored to US law. This was not
      independently verified against a copyright-registry source; treat it as a plausible but
      unconfirmed complication rather than a settled fact.
    - Net: even setting UmmahAPI's own missing terms aside, at least one of the translations it
      serves (Pickthall, for US distribution) and one other (Sahih International, sourcing
      unconfirmed) carry open copyright questions that this research pass could not close.

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
- **Licensing / terms:** The developer-facing **Groq Services Agreement**
  (`console.groq.com/docs/legal/services-agreement`) — the document the website Terms of Use
  defers to for actual API usage — was located and reviewed directly. Key points, quoted from the
  agreement:
  - **Who it binds:** acceptance happens "By clicking 'I agree,' accepting the Order Form, or
    using the Cloud Services" — i.e. it applies to anyone who uses the API, including an individual
    developer on a free console API key, not only enterprise customers with a signed contract. This
    matters for how this app is built: since **no Groq key ships with the repository** (it lives in
    the gitignored `src-tauri/src/groq_config.rs`, and Feature Studio is inert until a builder
    supplies their own key), it is each individual builder — not this project — who personally
    accepts this agreement when they create their own Groq account/key.
  - **Output ownership:** "As between the parties, Customer retains all Intellectual Property
    Rights in Customer Data (including in Inputs and Outputs)" — the app/builder, not Groq, owns
    the generated HTML mini-tools.
  - **Redistribution to end users is explicitly permitted:** the agreement grants the right "to use
    Groq's APIs to integrate the Cloud Services and AI Model Services into your Customer
    Application and to make the Cloud Services and AI Model Services available to End Users through
    your Customer Applications" — this covers exactly Feature Studio's model of generating content
    server-side (from Rust) and showing it to the app's own users.
  - **Provenance/attribution constraint:** Customer may not "modify, tamper with, remove, obscure,
    or otherwise alter any transparency or provenance information...associated with the Output
    generated by AI Model Services...that is used to identify it as being generated using a
    generative artificial intelligence model." In practice: if Groq attaches any AI-provenance
    metadata to a response, this app must not strip it — though nothing in the agreement requires
    a visible "Powered by Groq" credit, so listing Groq here remains a courtesy disclosure rather
    than a contractual requirement.
  - **Groq is restricted from training on the app's data:** "Groq is not permitted to use Inputs or
    Outputs for training or fine-tuning any AI Model Services or other models, unless explicitly
    granted permission or instructed by Customer" — this protects whatever prompts/outputs Feature
    Studio sends, rather than constraining the app.
  - **No warranty:** Groq "does not make and expressly disclaims to the fullest extent permitted by
    applicable law...any warranties of any kind, whether express, implied, statutory, or
    otherwise" — standard AS-IS terms, consistent with every other free API this app calls.
  - **Net assessment:** nothing in the Services Agreement blocks this app's use — output ownership
    and in-app redistribution to end users are both explicitly addressed and favorable. The only
    operational constraint is the provenance-metadata clause above, and the practical dependency
    risk is unchanged from before: **Feature Studio only works if the person building the app
    supplies their own Groq API key**, and that key is a paid-usage-capable Groq account (Groq does
    offer a free tier with usage limits per the agreement's "fee-free" services language, but any
    heavier use is billed to whoever's key it is, not to this project).

### QCF Quran fonts (reference only — not shipped)

- **What it is:** `docs/frontend-architecture.md` documents that a page-accurate Mushaf rendering
  mode was prototyped using the King Fahd Quran Complex's own QCF (Quran Complex Font) files and
  page-layout JSON, sourced from the GitHub repository
  [`MohamadHajjRabee/quran-qcf4`](https://github.com/MohamadHajjRabee/quran-qcf4).
- **Status in this app: not included.** That prototype was deliberately reverted and is not part
  of the current codebase or build — it exists only as external reference material on the project
  owner's own machine, kept in case the feature is revisited.
- **Licensing:** The repository's `LICENSE.md` was located and read directly (verified via the raw
  file at `github.com/MohamadHajjRabee/quran-qcf4`), and it turns out to split licensing explicitly
  by file type rather than leaving the fonts under only an informal note:
  - The **data files** (`pages/`, `index.json`, `verses.json`, `font-map.json`, `qbsml.json`) are
    MIT-licensed, copyright the repo's maintainer, Mohamad Hajj Rabee.
  - The **font files themselves** (`fonts/` and `fonts-woff2/` — the QCF4 fonts, based on the
    Madinah Mushaf, calligraphy by Uthman Taha, produced by the King Fahd Quran Complex, WOFF2/TTF
    conversion by Ahmad ElGharib) carry an **explicit restriction, not just an informal note**:
    the license states they are "provided solely for Quranic rendering purposes," and — this is
    the operative sentence — that **"redistribution, modification, or commercial use...without
    explicit permission...is not permitted."**
  - This resolves the open question from the previous pass: it is not merely an informal
    "for Quranic rendering purposes" aside with no stated terms — there is a written license, and
    it explicitly forbids exactly what shipping the fonts inside an app's assets would require
    (redistribution and, since this app is commercial-adjacent even if free, arguably commercial
    use) unless explicit permission is separately obtained from the rights holder.
  - Consistent with that, `docs/frontend-architecture.md` notes the fonts would need to be fetched
    live from the source per device, "never vendored into this repo." **This app currently
    distributes none of these font files**, which is the only posture compatible with the license
    as written; bundling them into a shipped APK without first obtaining explicit permission would
    not be.

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

## 4. Prayer-card artwork (AI-generated images, shipped as static assets)

- **What it is:** Seven illustrated night-scene mosque backgrounds used behind the Prayer Times
  home-screen cards, one per prayer — `static/prayer/fajr.webp`, `shuruq.webp`, `dhuhr.webp`,
  `asr.webp`, `maghrib.webp`, `isha.webp`, `tahajjud.webp` (about 127 KB total). Unlike every other
  entry in this document, these are not a live third-party API — they are static image files
  bundled into the app at build time.
- **Provenance:** The developer generated these images himself, from text prompts, using **Google
  Gemini's free consumer web interface** (`gemini.google.com`) — not the paid Gemini API or Google
  AI Studio, and not any stock-image library. The downloaded images were then resized and
  re-encoded to WebP for the app. This distinction matters because Google publishes **separate**
  terms for its consumer AI apps versus its paid developer/API products, and only the consumer
  terms govern this case.
- **Which terms actually apply:** The older **Generative AI Additional Terms of Service**
  (`policies.google.com/terms/generative-ai`) — the document most search results surface first —
  was checked directly and turns out to be superseded: it states plainly that "We updated the
  Google Terms of Service on May 22, 2024 to cover AI-related topics. As of that date, these
  Generative AI Additional Terms of Service no longer apply, unless you're a business partner with
  a signed agreement that references these terms." For an individual using the free consumer app,
  the governing documents today are the main **Google Terms of Service**
  (`policies.google.com/terms`), the **Gemini Apps Privacy Notice**
  (`support.google.com/gemini/answer/13594961`), and the **Generative AI Prohibited Use Policy**
  (`policies.google.com/terms/generative-ai/use-policy`), which the Privacy Notice references as
  applying to Gemini Apps.
- **1. Who owns the output:** Verified directly against `policies.google.com/terms`. Under the
  "Your content" heading it states, in full: **"Some of our services allow you to generate
  original content. Google won't claim ownership over that content."** — this sits alongside the
  general clause "Your content remains yours, which means that you retain any intellectual
  property rights that you have in your content." Google takes only the standard
  "worldwide, non-exclusive, royalty-free" operating license (to host/display/reformat content
  within its own services), not any ownership claim or right to prevent the developer's own
  downstream use. Net: the developer owns these seven images outright, as between him and Google.
- **2. Is commercial use permitted:** No clause restricting commercial use, distribution, or use in
  a paid product was found in either the main Terms of Service or the Generative AI Prohibited Use
  Policy (`policies.google.com/terms/generative-ai/use-policy`) — both were read in full for this
  question specifically. The Prohibited Use Policy's restrictions are about *content categories*
  (deception, illegal content, CSAM, etc.), not about commercial exploitation of legitimate output.
  This is consistent with Google's own public framing of the same May 2024 ToS change (reported by
  9to5Google and others) using the example that a user who generates a poem with Gemini can publish
  it in a book without a license from Google. Net: nothing found distinguishes free vs. paid apps —
  if DeenLab adds ads or in-app purchases later, this specific ownership/commercial-use grant does
  not appear to change, though it would be worth re-checking the live terms at that time in case
  they've been revised again.
- **3. Is attribution required:** No. Neither the Terms of Service, the Gemini Apps Privacy Notice,
  nor the Generative AI Prohibited Use Policy impose any requirement to credit Google or disclose
  AI-generation to the end users of a downstream product. (Google Play's *own* store policy is a
  separate question — see point 5.)
- **4. SynthID / watermarking:**
  - **(a) Obligation not to remove it:** No clause found, in any of the three governing documents,
    that prohibits a user from processing an image in a way that degrades or removes the invisible
    SynthID watermark. The only relevant clause in the Prohibited Use Policy is about *intent*, not
    the watermark itself: "Misrepresenting the provenance of generated content by claiming it was
    created solely by a human, in order to deceive." Ordinary resizing/re-encoding for a build
    pipeline, with no claim made anywhere that the art is human-made, does not match that clause.
    Separately, as of mid-August 2026, Google made its *visible* Gemini watermark icon optional via
    a user-facing toggle, while stating the invisible SynthID signal and C2PA metadata remain
    intact regardless — confirming Google treats SynthID as a detection/provenance layer it
    controls, not something it obligates end users to preserve.
  - **(b) Would this app's processing likely destroy it:** Google's own DeepMind page on SynthID
    (`deepmind.google/technologies/synthid`) states the watermark is "designed to stand up to
    modifications like cropping, adding filters, changing frame rates, or lossy compression" —
    i.e. built for resilience, but Google does not claim it as indestructible or give a quantified
    survival rate for any specific pipeline. This app's own processing (downscaling for a mobile UI
    card, then re-encoding to lossy WebP at aggressive compression — all 7 images together total
    only ~127 KB) is a heavier transformation than a single lossless format swap, and third-party
    (non-Google, unverified) write-ups on watermark robustness suggest survival is likely at
    moderate compression but degrades at low quality/aggressive resizing — those sources are not
    authoritative and are noted here only as directionally informative, not confirmed. **Whether the
    watermark actually survives this app's specific WebP output is not publicly documented and was
    not empirically tested in this pass** (Gemini itself can check a given image via its "ask
    Gemini" detection feature, which would be the way to close this if it matters practically). It
    does not appear to create a compliance problem either way: no clause found makes *destroying*
    the watermark through ordinary processing itself a violation — see (a).
- **5. Google Play policy on AI-generated content:** Two separate, non-overlapping Play policies
  were checked:
  - **Play's "AI-Generated Content" developer policy**
    (`support.google.com/googleplay/android-developer/answer/14094294`) governs apps whose
    *functionality* generates AI content for end users (e.g. chatbots, in-app image generators). It
    explicitly excludes apps outside that scope: "Apps that merely host AI-generated content and
    are unable to create content using AI, such as social media apps that do not contain AI content
    generation features." DeenLab has no in-app generation feature — these seven images are fixed,
    pre-made assets — so **this policy does not appear to apply** to the app.
  - **Play Console's separate AI-content self-declaration flow**
    (`support.google.com/googleplay/android-developer/answer/17262077`) is narrower and different in
    kind: it requires a self-declaration checkbox ("Regulations require that AI-generated content be
    labeled under certain circumstances") for **visual assets uploaded directly into Play Console's
    Store listing / promotional content flows** — screenshots, feature graphic, promo video, etc.
    This is not about in-app functionality at all; it's about what the developer uploads to the
    Play Console store-listing UI. Its documentation does **not** distinguish between "a standalone
    image that is itself wholly AI-generated" and "an ordinary screenshot of the app's real UI that
    happens to show some AI-made background art among genuine app content" — that specific nuance
    is not addressed either way. **Practical recommendation, not a documented requirement:** if any
    Play Console upload flow for this app's store listing prompts an AI-content declaration on an
    asset that shows this artwork, the safer choice is to declare it, since Google states declared
    assets simply get labeled on the Store (no stated penalty for declaring), whereas non-disclosure
    where required is a policy violation.
- **6. Depicting real, identifiable mosques — informational, not a blocker:** The seven images are
  stylised silhouette illustrations evoking real buildings (Quba, Masjid an-Nabawi, Badshahi,
  Hassan II, Sheikh Zayed, Masjid al-Haram, and a generic Tahajjud night scene), not photographs.
  Under U.S. copyright law, the **Architectural Works Copyright Protection Act** (17 U.S.C. § 120(a),
  confirmed via the U.S. Code text at `uscode.house.gov`) specifically carves out this situation:
  copyright in a constructed building "does not include the right to prevent the making,
  distributing, or public display of pictures, paintings, photographs, or other pictorial
  representations of the work, if the building...is located in or ordinarily visible from a public
  place." All of these are famous, publicly visible buildings, and the app's illustrations are
  stylised rather than literal reproductions, which further reduces any residual concern. No
  trademark registration covering any of these buildings' silhouettes was found (unlike, for
  example, some hotels that have separately trademarked a building's distinctive shape). Net: this
  is worth knowing about but nothing found here rises to a real risk for a free app.
- **Net assessment:** For a free app with no ads or IAP today, nothing found in Google's governing
  terms blocks shipping these images — the developer owns the output, no commercial-use
  restriction applies, and no attribution/disclosure is contractually required by Google itself.
  The two things actually worth doing are practical, not legal-compliance gaps: (1) treat Play
  Console's AI-content declaration checkbox as something to answer honestly if it ever surfaces
  for a store-listing asset that shows this artwork, and (2) if monetization is added later, this
  section's "no commercial-use restriction" finding is worth a quick re-check against whichever
  terms are live at that time, since none of these documents guarantee they won't change.

---

## What could not be verified

For transparency, the specific points in this document that could not be confirmed from an
authoritative source, and why. (A later research pass closed several previously-open items below —
Aladhan's terms, Groq's Services Agreement, and the QCF font license were all found and reviewed;
the OpenStreetMap Nominatim policy was re-checked against the live policy page and found unchanged
from what's written above. What remains genuinely open is narrower now.)

- **Aladhan API**: its full published terms were located and read in full (see above) — the gap is
  no longer "terms weren't found," it's that the terms themselves are minimal: no clause on
  commercial use, attribution, or caching exists to confirm either way. A specific per-IP rate
  limit (~12 req/s) is reported in secondhand summaries of Islamic Network's own community forum,
  but the forum is a JS-rendered app that could not be fetched directly to confirm the exact
  figure or source — this number should be treated as unverified. Whether an API key is technically
  optional or simply unenforced also still could not be confirmed beyond observing this app's own
  keyless requests work.
- **UmmahAPI**: confirmed (not just "not found") that no Terms of Service, Privacy Policy, or
  License page exists anywhere on the site — every nav/footer link was checked. What's genuinely
  unresolved: (1) which upstream source UmmahAPI itself draws its Sahih International translation
  text from, and that source's own redistribution license; (2) the US copyright status of the
  Pickthall translation specifically, which one source describes as unsettled due to its 1930
  India publication. Both would need the provider or a copyright specialist to resolve definitively.
- **ipwho.is**: no content/software license beyond its stated free-tier usage terms (rate limit,
  commercial use allowed, no SLA). Not re-checked in this pass.
- **QCF fonts**: still moot for this app specifically, since it ships or fetches none of these font
  files — but no longer an open licensing question in itself. The license was found and is
  explicit: font redistribution/commercial use is "not permitted" without permission obtained
  directly from the rights holder (see above).
- **Prayer-card artwork (the seven `static/prayer/*.webp` mosque images)**: the governing Google
  terms were located and read in full, and the ownership/commercial-use questions are resolved
  (see above) — what's left open is narrower and mostly empirical rather than legal: (1) whether
  the invisible SynthID watermark actually survives this app's specific resize-then-lossy-WebP
  pipeline was not tested and is not something Google documents for a specific pipeline, only that
  the watermark is "designed to stand up to" common transformations in general; this is flagged as
  low-stakes since no clause found makes incidental watermark loss through ordinary processing a
  violation in itself. (2) Whether Play Console's AI-content self-declaration checkbox
  (`answer/17262077`) would apply to an ordinary app screenshot that merely shows this artwork as
  part of the real UI, versus only to a standalone AI-generated promotional image, is not
  addressed in Google's own documentation either way — treat this as a "declare it if prompted"
  practical default rather than a resolved policy question.
