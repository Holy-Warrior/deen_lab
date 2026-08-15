<script lang="ts">
    import { onMount } from "svelte";
    import { duaService, type Dua, type DuaCategory } from "./service";

    let categories: DuaCategory[] = [];
    let selectedCategory: DuaCategory | null = null;
    let duas: Dua[] = [];
    let selectedDua: Dua | null = null;
    let query = "";
    let isLoading = true;
    let error = "";

    $: filteredCategories = categories.filter(category => category.name.toLowerCase().includes(query.trim().toLowerCase()));
    $: filteredDuas = duas.filter(dua => dua.title.toLowerCase().includes(query.trim().toLowerCase()));

    onMount(loadCategories);

    async function loadCategories() {
        isLoading = true;
        error = "";
        try { categories = await duaService.categories(); }
        catch (cause) { error = cause instanceof Error ? cause.message : "Unable to load duas."; }
        finally { isLoading = false; }
    }

    async function openCategory(category: DuaCategory) {
        selectedCategory = category;
        selectedDua = null;
        query = "";
        isLoading = true;
        error = "";
        try { duas = await duaService.category(category.id); }
        catch (cause) { error = cause instanceof Error ? cause.message : "Unable to load this category."; }
        finally { isLoading = false; }
    }

    function goBack() {
        if (selectedDua) selectedDua = null;
        else { selectedCategory = null; query = ""; }
    }
</script>

<svelte:head><title>Duas · DeenLab</title></svelte:head>

<div class="app-shell"><main class="page-container">
    <header class="app-header">
        {#if selectedCategory}<button class="button button--secondary" onclick={goBack}>← Back</button>{:else}<a class="text-sm text-emerald-400 hover:text-emerald-300" href="/">← Home</a>{/if}
        <h1 class="mt-4 text-3xl font-bold">{selectedDua?.title ?? selectedCategory?.name ?? "Duas"}</h1>
        {#if !selectedDua}<p class="mt-2 text-zinc-400">{selectedCategory?.description ?? "Authentic supplications from the Quran and Sunnah."}</p>{/if}
    </header>

    {#if selectedDua}
        <article class="space-y-5">
            <section class="surface p-6"><p class="text-right text-2xl leading-[2] sm:text-3xl" lang="ar" dir="rtl">{selectedDua.arabic}</p></section>
            {#if selectedDua.transliteration}<section class="surface p-5"><h2 class="font-semibold text-emerald-300">Transliteration</h2><p class="mt-3 italic leading-7">{selectedDua.transliteration}</p></section>{/if}
            <section class="surface p-5"><h2 class="font-semibold text-emerald-300">Meaning</h2><p class="mt-3 leading-7 text-zinc-200">{selectedDua.translation}</p></section>
            {#if selectedDua.source}<p class="text-sm text-zinc-400">Source: {selectedDua.source}</p>{/if}
            {#if selectedDua.repeat > 1}<p class="text-sm text-zinc-400">Repeat {selectedDua.repeat} times.</p>{/if}
        </article>
    {:else}
        <input class="control mb-5 w-full" placeholder={selectedCategory ? "Search duas" : "Search categories"} bind:value={query} aria-label="Search" />
        {#if isLoading}<p class="text-zinc-400" aria-live="polite">Loading…</p>
        {:else if error}<div class="surface p-5" role="alert"><p>{error}</p><button class="button mt-4" onclick={selectedCategory ? () => openCategory(selectedCategory!) : loadCategories}>Try again</button></div>
        {:else if selectedCategory}<div class="space-y-3">{#each filteredDuas as dua}<button class="surface w-full p-5 text-left hover:bg-zinc-800" onclick={() => selectedDua = dua}><span class="block font-semibold">{dua.title}</span><span class="mt-2 block line-clamp-2 text-sm text-zinc-400">{dua.translation}</span></button>{:else}<p class="surface p-5 text-zinc-400">No duas match your search.</p>{/each}</div>
        {:else}<div class="grid gap-3 sm:grid-cols-2">{#each filteredCategories as category}<button class="surface p-5 text-left hover:bg-zinc-800" onclick={() => openCategory(category)}><span class="block font-semibold">{category.name}</span><span class="mt-2 block text-sm text-zinc-400">{category.description}</span><span class="mt-3 block text-sm text-emerald-300">{category.count} duas</span></button>{:else}<p class="surface p-5 text-zinc-400">No categories match your search.</p>{/each}</div>{/if}
    {/if}
</main></div>
