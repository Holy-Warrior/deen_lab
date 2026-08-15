<script lang="ts">
    import { onMount } from "svelte";
    import { quranService } from "./service";
    import type { Ayah, Surah } from "./models";

    let surahs: Surah[] = [];
    let selectedSurah: Surah | null = null;
    let ayahs: Ayah[] = [];
    let query = "";
    let isLoadingSurahs = true;
    let isLoadingAyahs = false;
    let error = "";
    let readerMode: "mushaf" | "study" = "mushaf";
    let fontSize = 24;

    $: normalizedQuery = query.trim().toLowerCase();
    $: filteredSurahs = surahs.filter(surah =>
        !normalizedQuery ||
        surah.englishName.toLowerCase().includes(normalizedQuery) ||
        surah.name.includes(query.trim()) ||
        String(surah.number).includes(normalizedQuery)
    );

    onMount(loadSurahs);

    async function loadSurahs() {
        isLoadingSurahs = true;
        error = "";

        try {
            surahs = await quranService.surahs();
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load the Quran.";
        } finally {
            isLoadingSurahs = false;
        }
    }

    async function openSurah(surah: Surah) {
        selectedSurah = surah;
        isLoadingAyahs = true;
        error = "";
        ayahs = [];

        try {
            ayahs = await quranService.ayahs(surah.number);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load this surah.";
        } finally {
            isLoadingAyahs = false;
        }
    }

    function closeReader() {
        selectedSurah = null;
        ayahs = [];
        error = "";
    }
</script>

<div class="app-shell">
    <main class="page-container">
        {#if selectedSurah}
            <header class="mb-6 flex flex-wrap items-center justify-between gap-4">
                <div>
                    <button class="button button--secondary" onclick={closeReader}>← All surahs</button>
                    <h1 class="mt-5 text-3xl font-bold">{selectedSurah.englishName}</h1>
                    <p class="mt-1 text-zinc-400" lang="ar" dir="rtl">{selectedSurah.name}</p>
                </div>

                <div class="flex flex-wrap items-center gap-3">
                    <label class="text-sm text-zinc-400" for="font-size">Arabic size</label>
                    <input id="font-size" class="accent-emerald-400" type="range" min="18" max="32" bind:value={fontSize} />
                    <button class="button button--secondary" onclick={() => readerMode = readerMode === "mushaf" ? "study" : "mushaf"}>
                        {readerMode === "mushaf" ? "Study mode" : "Mushaf mode"}
                    </button>
                </div>
            </header>

            {#if isLoadingAyahs}
                <p class="text-zinc-400" aria-live="polite">Loading surah…</p>
            {:else if error}
                <div class="surface p-5" role="alert">
                    <p>{error}</p>
                    <button class="button mt-4" onclick={() => selectedSurah && openSurah(selectedSurah)}>Try again</button>
                </div>
            {:else if readerMode === "mushaf"}
                <article class="surface p-6 sm:p-8">
                    <p class="leading-[2.25] text-right" lang="ar" dir="rtl" style:font-size={`${fontSize}px`}>
                        {#each ayahs as ayah}
                            {ayah.text} <span class="text-emerald-400">۝{ayah.number}</span>{" "}
                        {/each}
                    </p>
                </article>
            {:else}
                <div class="space-y-4">
                    {#each ayahs as ayah}
                        <article class="surface p-5">
                            <p class="text-right leading-[2]" lang="ar" dir="rtl" style:font-size={`${fontSize}px`}>
                                {ayah.text} <span class="text-emerald-400">۝{ayah.number}</span>
                            </p>
                            <p class="mt-4 border-t border-zinc-700 pt-4 leading-7 text-zinc-300">{ayah.translation}</p>
                        </article>
                    {/each}
                </div>
            {/if}
        {:else}
            <header class="app-header">
                <a class="text-sm text-emerald-400 hover:text-emerald-300" href="/">← Home</a>
                <h1 class="mt-4 text-3xl font-bold">Quran</h1>
                <p class="mt-2 text-zinc-400">Read the Quran in Arabic with an English translation.</p>
            </header>

            <label class="sr-only" for="surah-search">Search surah</label>
            <input id="surah-search" class="control mb-5 w-full" placeholder="Search by surah name or number" bind:value={query} />

            {#if isLoadingSurahs}
                <p class="text-zinc-400" aria-live="polite">Loading surahs…</p>
            {:else if error}
                <div class="surface p-5" role="alert">
                    <p>{error}</p>
                    <button class="button mt-4" onclick={loadSurahs}>Try again</button>
                </div>
            {:else}
                <div class="space-y-3">
                    {#each filteredSurahs as surah}
                        <button class="surface flex w-full items-center gap-4 p-4 text-left hover:bg-zinc-800" onclick={() => openSurah(surah)}>
                            <span class="grid size-10 shrink-0 place-items-center rounded-full bg-emerald-400/15 font-semibold text-emerald-300">{surah.number}</span>
                            <span class="min-w-0 flex-1">
                                <span class="block font-semibold">{surah.englishName}</span>
                                <span class="mt-1 block text-sm text-zinc-400" lang="ar" dir="rtl">{surah.name}</span>
                            </span>
                            <span class="text-sm text-zinc-400">{surah.ayahCount} ayahs</span>
                        </button>
                    {:else}
                        <p class="surface p-5 text-zinc-400">No surahs match “{query}”.</p>
                    {/each}
                </div>
            {/if}
        {/if}
    </main>
</div>
