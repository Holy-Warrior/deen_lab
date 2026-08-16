<script lang="ts">
    import { onMount } from "svelte";
    import { pushState } from "$app/navigation";
    import { page } from "$app/state";
    import { ArrowLeft } from "@lucide/svelte";
    import { quranService, type SurahSummary, type Verse } from "./service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";

    interface QuranNavState { surah?: SurahSummary }

    let surahs: SurahSummary[] = $state([]);
    let verses: Verse[] = $state([]);
    let query = $state("");
    let isLoading = $state(true);
    let error = $state("");

    // sveltekit: same shallow-routing pattern as Duas (see docs/android-back-navigation.md) --
    // the phone's hardware back button steps out of an open surah instead of exiting the page
    let selectedSurah = $derived((page.state as QuranNavState).surah ?? null);

    let queryResetKey = $state<number | null>(null);
    $effect(() => {
        const key = selectedSurah?.number ?? null;
        if (key !== queryResetKey) {
            query = "";
            error = "";
            queryResetKey = key;
        }
    });

    let filteredSurahs = $derived.by(() => {
        const search = query.trim().toLowerCase();
        if (!search) return surahs;
        return surahs.filter(
            (surah) =>
                surah.nameEnglish.toLowerCase().includes(search) ||
                surah.nameTranslation.toLowerCase().includes(search) ||
                String(surah.number) === search
        );
    });

    onMount(loadSurahs);

    async function loadSurahs() {
        isLoading = true;
        error = "";
        try {
            surahs = await quranService.surahs((cached) => (surahs = cached));
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load surahs.";
        } finally {
            isLoading = false;
        }
    }

    async function openSurah(surah: SurahSummary) {
        pushState("", { surah: $state.snapshot(surah) } satisfies QuranNavState);
        isLoading = true;
        try {
            verses = await quranService.surah(surah.number, (cached) => (verses = cached));
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load this surah.";
        } finally {
            isLoading = false;
        }
    }

    function goBack() {
        history.back();
    }
</script>

<svelte:head><title>{selectedSurah ? `${selectedSurah.nameEnglish} · ` : ""}Quran · DeenLab</title></svelte:head>

<div class="feature-page space-y-6">
    {#if selectedSurah}
        <header class="flex items-center gap-3">
            <button class="icon-button shrink-0" onclick={goBack} aria-label="Back">
                <ArrowLeft size={20} />
            </button>
            <div>
                <h1 class="text-2xl font-bold">{selectedSurah.nameEnglish}</h1>
                <p class="mt-1 text-zinc-400">{selectedSurah.nameTranslation} · {selectedSurah.versesCount} verses</p>
            </div>
        </header>

        {#if error}
            <ErrorBanner message={error} onRetry={() => openSurah(selectedSurah!)} />
        {/if}

        {#if isLoading && verses.length === 0}
            <p class="text-zinc-400" aria-live="polite">Loading verses…</p>
        {:else}
            <div class="space-y-3">
                {#each verses as verse (verse.verseKey)}
                    <article class="surface p-4">
                        <p class="text-xs text-zinc-500">{verse.verseKey}</p>
                        <p class="mt-2 text-right text-xl leading-[1.9]" lang="ar" dir="rtl">{verse.arabic}</p>
                        <p class="mt-2 text-sm italic text-zinc-400">{verse.transliteration}</p>
                        <p class="mt-1.5 text-sm text-zinc-200">{verse.translation}</p>
                    </article>
                {/each}
            </div>
        {/if}
    {:else}
        <header>
            <h1 class="text-2xl font-bold">Quran</h1>
            <p class="mt-1 text-zinc-400">Read with translation and transliteration.</p>
        </header>

        <input class="control w-full" placeholder="Search surahs" bind:value={query} aria-label="Search surahs" />

        {#if error}
            <ErrorBanner message={error} onRetry={loadSurahs} />
        {/if}

        {#if isLoading && surahs.length === 0}
            <p class="text-zinc-400" aria-live="polite">Loading surahs…</p>
        {:else}
            <div class="space-y-2">
                {#each filteredSurahs as surah (surah.number)}
                    <button class="tool-card flex w-full items-center gap-3 text-left" onclick={() => openSurah(surah)}>
                        <span class="surah-number">{surah.number}</span>
                        <span class="min-w-0 flex-1">
                            <span class="block font-semibold">{surah.nameEnglish}</span>
                            <span class="block text-xs text-zinc-400">{surah.nameTranslation} · {surah.versesCount} verses</span>
                        </span>
                        <span class="shrink-0 text-lg" lang="ar" dir="rtl">{surah.nameArabic}</span>
                    </button>
                {:else}
                    <p class="surface p-5 text-zinc-400">No surahs match your search.</p>
                {/each}
            </div>
        {/if}
    {/if}
</div>

<style>
    .surah-number {
        display: grid;
        place-items: center;
        width: 2rem;
        height: 2rem;
        flex-shrink: 0;
        border-radius: 999px;
        background: var(--app-canvas);
        border: 1px solid var(--app-border);
        font-size: 0.75rem;
        font-weight: 700;
        color: var(--app-accent);
    }
</style>
