<script lang="ts">
    import { openUrl } from "@tauri-apps/plugin-opener";

    // design: mirrors docs/credits.md, which is the researched source of truth. Keep the two in
    // step -- every licence here was verified against the provider's own terms, so an
    // unreviewed edit in either place quietly turns a checked claim into an unchecked one.
    interface Entry { name: string; url?: string; use: string; terms: string }

    const dataSources: Entry[] = [
        { name: "Aladhan API", url: "https://aladhan.com", use: "Prayer times, Hijri dates, Sehri & Iftari", terms: "Free, no key. Prayer times calculated with Pray Times." },
        { name: "UmmahAPI", url: "https://ummahapi.com", use: "Quran text, translation and transliteration; Duas", terms: "Free, no key. Publishes no formal terms." },
        { name: "ipwho.is", url: "https://ipwho.is", use: "Approximate location when GPS is unavailable", terms: "Free tier, no key." },
        { name: "OpenStreetMap Nominatim", url: "https://nominatim.openstreetmap.org", use: "Turning coordinates into a place name", terms: "Data © OpenStreetMap contributors, ODbL." },
        { name: "Groq", url: "https://groq.com", use: "Feature Studio (optional; needs your own API key)", terms: "Inactive unless a key is configured." }
    ];

    const frontend = [
        { name: "Svelte & SvelteKit", license: "MIT" },
        { name: "Tailwind CSS", license: "MIT" },
        { name: "bits-ui", license: "MIT" },
        { name: "Lucide icons", license: "ISC" },
        { name: "Vite", license: "MIT" },
        { name: "TypeScript", license: "Apache-2.0" }
    ];

    const backend = [
        { name: "Tauri", license: "MIT / Apache-2.0" },
        { name: "reqwest", license: "MIT / Apache-2.0" },
        { name: "serde & serde_json", license: "MIT / Apache-2.0" },
        { name: "tauri-plugin-geolocation", license: "MIT / Apache-2.0" },
        { name: "tauri-plugin-opener", license: "MIT / Apache-2.0" }
    ];

    // tauri: opener plugin, not a bare href -- an external link inside the WebView would replace
    // the app's own page with no way back. This hands the URL to the system browser instead.
    function open(url: string) {
        openUrl(url).catch(() => {});
    }
</script>

<svelte:head><title>About · DeenLab</title></svelte:head>

<div class="feature-page space-y-6">
    <header>
        <h1 class="text-2xl font-bold">About DeenLab</h1>
        <p class="mt-1 text-zinc-400">Where the content comes from, and what the app is built on.</p>
    </header>

    <section class="surface p-5">
        <h2 class="font-semibold">Content and data</h2>
        <p class="mt-1 text-sm text-zinc-400">
            DeenLab relies on the services below. Our thanks to everyone who maintains them.
        </p>

        <div class="mt-4 space-y-3">
            {#each dataSources as source}
                <article class="credit-row">
                    <div class="min-w-0">
                        <p class="font-semibold">{source.name}</p>
                        <p class="text-sm text-zinc-400">{source.use}</p>
                        <p class="mt-0.5 text-xs text-zinc-500">{source.terms}</p>
                    </div>
                    {#if source.url}
                        <button class="button button--secondary shrink-0 text-sm" onclick={() => open(source.url!)}>
                            Visit
                        </button>
                    {/if}
                </article>
            {/each}
        </div>
    </section>

    <section class="surface p-5">
        <h2 class="font-semibold">Artwork</h2>
        <p class="mt-2 text-sm text-zinc-400">
            The mosque illustrations on the prayer card were generated with Google Gemini and
            edited for this app. They are stylised impressions of Quba Mosque, Al-Masjid an-Nabawi,
            Badshahi Mosque, Hassan II Mosque, Sheikh Zayed Grand Mosque and Masjid al-Haram — not
            photographs, and not affiliated with or endorsed by those institutions.
        </p>
    </section>

    <!-- design: the section most likely to be read by someone deciding whether to trust the
         times shown. Stated plainly rather than buried, and it defers to a local authority
         instead of implying the app is the last word. -->
    <section class="surface p-5">
        <h2 class="font-semibold">A note on accuracy</h2>
        <div class="mt-2 space-y-2 text-sm text-zinc-400">
            <p>
                Prayer times are <b class="text-zinc-200">calculated</b>, not fetched from your
                mosque. You can choose between the Karachi, Muslim World League and Umm al-Qura
                methods, and results will differ slightly between them. Where your local mosque's
                timetable differs, follow your local mosque.
            </p>
            <p>
                The Qibla direction is a great-circle bearing to the Ka'bah, and depends on your
                device's compass and location accuracy.
            </p>
            <p>
                Quran translations are the work of their respective translators, reproduced as
                supplied by the source above.
            </p>
        </div>
    </section>

    <section class="surface p-5">
        <h2 class="font-semibold">Open source</h2>
        <p class="mt-1 text-sm text-zinc-400">DeenLab is built with these projects.</p>

        <div class="mt-3 grid gap-4 sm:grid-cols-2">
            <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-zinc-500">App</p>
                <ul class="mt-1.5 space-y-1">
                    {#each frontend as item}
                        <li class="flex justify-between gap-3 text-sm">
                            <span>{item.name}</span>
                            <span class="shrink-0 text-zinc-500">{item.license}</span>
                        </li>
                    {/each}
                </ul>
            </div>
            <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Core</p>
                <ul class="mt-1.5 space-y-1">
                    {#each backend as item}
                        <li class="flex justify-between gap-3 text-sm">
                            <span>{item.name}</span>
                            <span class="shrink-0 text-zinc-500">{item.license}</span>
                        </li>
                    {/each}
                </ul>
            </div>
        </div>

        <p class="mt-4 text-xs text-zinc-500">
            Direct dependencies only. Each carries its own licence, held by its own authors.
        </p>
    </section>
</div>

<style>
    .credit-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 0.75rem;
        padding: 0.75rem;
        border: 1px solid var(--app-border);
        border-radius: 0.75rem;
        background: var(--app-canvas);
    }
</style>
