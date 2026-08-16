<script lang="ts">
    import { onMount } from "svelte";
    import { pushState } from "$app/navigation";
    import { page } from "$app/state";
    import { ArrowLeft } from "@lucide/svelte";
    import { duaService, type Dua, type DuaCategory } from "./service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";

    interface DuasNavState { category?: DuaCategory; dua?: Dua }

    let categories: DuaCategory[] = $state([]);
    let duas: Dua[] = $state([]);
    let query = $state("");
    let isLoading = $state(true);
    let error = $state("");

    // sveltekit: category/dua selection lives in page.state (shallow routing) instead of plain
    // component $state -- pushState below adds a real history entry without changing the URL,
    // so the phone's hardware back button (Tauri's Android WebView maps it to the WebView's own
    // history-back, which fires this same popstate machinery) steps back through
    // dua -> category -> categories one screen at a time instead of exiting the feature, the
    // same way SvelteKit's router already handles every other back-navigation in the app.
    // https://svelte.dev/docs/kit/shallow-routing
    let selectedCategory = $derived((page.state as DuasNavState).category ?? null);
    let selectedDua = $derived((page.state as DuasNavState).dua ?? null);

    // design: query only makes sense scoped to whichever list is on screen -- clear it whenever
    // the selected category changes, however that happened (a tap, or the back button popping
    // page.state back to a different level)
    let queryResetKey = $state<string | null>(null);
    $effect(() => {
        const key = selectedCategory?.id ?? null;
        if (key !== queryResetKey) {
            query = "";
            error = "";
            queryResetKey = key;
        }
    });

    // svelte: $derived.by recomputes automatically as `query`/`categories`/`duas` change --
    // same filter-in-place approach as CitySelector, just against whichever list is on screen
    let filteredCategories = $derived.by(() => {
        const search = query.trim().toLowerCase();
        if (!search) return categories;
        return categories.filter(category => category.name.toLowerCase().includes(search));
    });
    let filteredDuas = $derived.by(() => {
        const search = query.trim().toLowerCase();
        if (!search) return duas;
        return duas.filter(dua => dua.title.toLowerCase().includes(search));
    });

    let title = $derived(selectedDua?.title ?? selectedCategory?.name ?? "Duas");
    let subtitle = $derived(
        selectedDua ? selectedCategory?.name ?? "" :
        selectedCategory?.description ?? "Authentic supplications from the Quran and Sunnah."
    );
    // design: source and repeat count share one footnote line under the meaning card instead
    // of two near-empty lines -- most duas have one or the other, rarely neither
    let footnote = $derived.by(() => {
        if (!selectedDua) return "";
        const parts: string[] = [];
        if (selectedDua.source) parts.push(`Source: ${selectedDua.source}`);
        if (selectedDua.repeat > 1) parts.push(`Repeat ${selectedDua.repeat} times`);
        return parts.join(" · ");
    });

    onMount(loadCategories);

    async function loadCategories() {
        isLoading = true;
        error = "";
        try {
            categories = await duaService.categories(cached => categories = cached);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load duas.";
        } finally {
            isLoading = false;
        }
    }

    async function openCategory(category: DuaCategory) {
        // svelte: $state.snapshot() unwraps the reactive proxy `category` (an element read out
        // of the `categories` $state array) into a plain object -- the browser's native
        // history.pushState requires its `state` argument to be structured-cloneable, and a
        // Svelte 5 $state proxy isn't (throws DataCloneError), even though it looks/reads like
        // an ordinary object everywhere else.
        pushState("", { category: $state.snapshot(category) } satisfies DuasNavState);
        isLoading = true;
        try {
            duas = await duaService.category(category.id, cached => duas = cached);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load this category.";
        } finally {
            isLoading = false;
        }
    }

    function openDua(dua: Dua) {
        if (!selectedCategory) return;
        pushState("", { category: $state.snapshot(selectedCategory), dua: $state.snapshot(dua) } satisfies DuasNavState);
    }

    // sveltekit: history.back() (not a manual state reset) so the in-app button and the
    // phone's hardware back button are the exact same code path -- one pop of whichever
    // page.state entry pushState above added, never out of sync with each other
    function goBack() {
        history.back();
    }
</script>

<svelte:head><title>{selectedDua ? `${selectedDua.title} · ` : ""}Duas · DeenLab</title></svelte:head>

<div class="feature-page space-y-6">
    <header class="flex items-start gap-3">
        {#if selectedCategory}
            <button class="icon-button mt-0.5 shrink-0" onclick={goBack} aria-label="Back">
                <ArrowLeft size={20} />
            </button>
        {/if}
        <div>
            <h1 class="text-2xl font-bold">{title}</h1>
            <p class="mt-1 text-zinc-400">{subtitle}</p>
        </div>
    </header>

    {#if selectedDua}
        <article class="space-y-4">
            <section class="surface p-6">
                <p class="text-right text-2xl leading-[2] sm:text-3xl" lang="ar" dir="rtl">{selectedDua.arabic}</p>
            </section>

            {#if selectedDua.transliteration}
                <section class="surface p-5">
                    <h2 class="font-semibold text-emerald-300">Transliteration</h2>
                    <p class="mt-3 italic leading-7 text-zinc-200">{selectedDua.transliteration}</p>
                </section>
            {/if}

            <section class="surface p-5">
                <h2 class="font-semibold text-emerald-300">Meaning</h2>
                <p class="mt-3 leading-7 text-zinc-200">{selectedDua.translation}</p>
            </section>

            {#if footnote}
                <p class="text-sm text-zinc-400">{footnote}</p>
            {/if}
        </article>
    {:else}
        <input
            class="control w-full"
            placeholder={selectedCategory ? "Search duas" : "Search categories"}
            bind:value={query}
            aria-label="Search"
        />

        {#if error}
            <ErrorBanner message={error} onRetry={selectedCategory ? () => openCategory(selectedCategory!) : loadCategories} />
        {/if}

        {#if isLoading && (selectedCategory ? duas.length === 0 : categories.length === 0)}
            <p class="text-zinc-400" aria-live="polite">Loading…</p>
        {:else if selectedCategory}
            <div class="space-y-3">
                {#each filteredDuas as dua (dua.id)}
                    <button class="tool-card w-full text-left" onclick={() => openDua(dua)}>
                        <span class="block font-semibold">{dua.title}</span>
                        <!-- tailwind: line-clamp-2 sets its own display:-webkit-box -- pairing it with `block` here
                             would let `block`'s plain display win instead, silently disabling the clamp -->
                        <span class="mt-1 line-clamp-2 text-sm text-zinc-400">{dua.translation}</span>
                    </button>
                {:else}
                    <p class="surface p-5 text-zinc-400">No duas match your search.</p>
                {/each}
            </div>
        {:else}
            <div class="grid grid-cols-2 gap-3">
                {#each filteredCategories as category (category.id)}
                    <button class="tool-card text-left" onclick={() => openCategory(category)}>
                        <span class="block font-semibold">{category.name}</span>
                        <span class="mt-1 line-clamp-2 text-xs text-zinc-400">{category.description}</span>
                        <span class="mt-2 block text-xs font-semibold text-emerald-300">{category.count} {category.count === 1 ? "dua" : "duas"}</span>
                    </button>
                {:else}
                    <p class="surface p-5 text-zinc-400">No categories match your search.</p>
                {/each}
            </div>
        {/if}
    {/if}
</div>
