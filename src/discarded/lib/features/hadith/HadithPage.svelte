<script lang="ts">
    import { onMount } from "svelte";
    import { hadithService, type Hadith, type HadithCollection } from "./service";

    let collections: HadithCollection[] = [];
    let selectedCollection: HadithCollection | null = null;
    let hadiths: Hadith[] = [];
    let selectedHadith: Hadith | null = null;
    let query = "";
    let page = 1;
    let totalPages = 1;
    let isLoading = true;
    let error = "";

    $: visibleCollections = collections.filter(collection => collection.name.toLowerCase().includes(query.trim().toLowerCase()));

    onMount(loadCollections);

    async function loadCollections() {
        isLoading = true; error = "";
        try { collections = await hadithService.collections(); }
        catch (cause) { error = cause instanceof Error ? cause.message : "Unable to load the Hadith library."; }
        finally { isLoading = false; }
    }

    async function openCollection(collection: HadithCollection, nextPage = 1) {
        selectedCollection = collection; selectedHadith = null; page = nextPage; query = ""; isLoading = true; error = "";
        try { const result = await hadithService.browse(collection.key, nextPage); hadiths = result.hadiths; page = result.page; totalPages = result.totalPages; }
        catch (cause) { error = cause instanceof Error ? cause.message : "Unable to load this collection."; }
        finally { isLoading = false; }
    }

    async function search() {
        if (!query.trim()) { if (selectedCollection) await openCollection(selectedCollection, 1); return; }
        isLoading = true; error = "";
        try { hadiths = await hadithService.search(query, selectedCollection?.key); totalPages = 1; }
        catch (cause) { error = cause instanceof Error ? cause.message : "Unable to search Hadith."; }
        finally { isLoading = false; }
    }

    function goBack() { if (selectedHadith) selectedHadith = null; else { selectedCollection = null; query = ""; } }
</script>

<svelte:head><title>Hadith · DeenLab</title></svelte:head>

<div class="app-shell"><main class="page-container">
    <header class="app-header">
        {#if selectedCollection}<button class="button button--secondary" onclick={goBack}>← Back</button>{:else}<a class="text-sm text-emerald-400 hover:text-emerald-300" href="/">← Home</a>{/if}
        <h1 class="mt-4 text-3xl font-bold">{selectedHadith ? `Hadith ${selectedHadith.hadithnumber}` : selectedCollection?.name ?? "Hadith"}</h1>
        {#if selectedCollection && !selectedHadith}<p class="mt-2 text-zinc-400">{selectedCollection.author} · {selectedCollection.reliability}</p>{/if}
    </header>

    {#if selectedHadith}
        <article class="space-y-5"><section class="surface p-6"><p class="text-right text-2xl leading-[2] sm:text-3xl" lang="ar" dir="rtl">{selectedHadith.arabic}</p></section><section class="surface p-6"><p class="leading-8">{selectedHadith.english}</p></section><p class="text-sm text-zinc-400">{selectedHadith.collection_name} · Hadith {selectedHadith.hadithnumber} · {selectedHadith.grade}</p></article>
    {:else}
        <form class="mb-5 flex gap-3" onsubmit={(event) => { event.preventDefault(); search(); }}><input class="control min-w-0 flex-1" placeholder={selectedCollection ? "Search this collection" : "Filter collections"} bind:value={query} /><button class="button" type="submit">Search</button></form>
        {#if isLoading}<p class="text-zinc-400" aria-live="polite">Loading…</p>
        {:else if error}<div class="surface p-5" role="alert"><p>{error}</p><button class="button mt-4" onclick={selectedCollection ? () => openCollection(selectedCollection!, page) : loadCollections}>Try again</button></div>
        {:else if selectedCollection}<div class="space-y-3">{#each hadiths as hadith}<button class="surface w-full p-5 text-left hover:bg-zinc-800" onclick={() => selectedHadith = hadith}><span class="text-sm text-emerald-300">Hadith {hadith.hadithnumber} · {hadith.grade}</span><span class="mt-2 block line-clamp-3 leading-7">{hadith.english}</span></button>{:else}<p class="surface p-5 text-zinc-400">No Hadith found.</p>{/each}</div>
            {#if !query.trim()}<nav class="mt-6 flex items-center justify-between"><button class="button button--secondary" disabled={page === 1} onclick={() => selectedCollection && openCollection(selectedCollection, page - 1)}>Previous</button><span class="text-sm text-zinc-400">Page {page} of {totalPages}</span><button class="button button--secondary" disabled={page === totalPages} onclick={() => selectedCollection && openCollection(selectedCollection, page + 1)}>Next</button></nav>{/if}
        {:else}<div class="grid gap-3 sm:grid-cols-2">{#each visibleCollections as collection}<button class="surface p-5 text-left hover:bg-zinc-800" onclick={() => openCollection(collection)}><span class="block font-semibold">{collection.name}</span><span class="mt-1 block text-zinc-400" lang="ar" dir="rtl">{collection.arabic_name}</span><span class="mt-3 block text-sm text-emerald-300">{collection.total_hadiths.toLocaleString()} hadiths</span></button>{:else}<p class="surface p-5 text-zinc-400">No collections match your search.</p>{/each}</div>{/if}
    {/if}
</main></div>
