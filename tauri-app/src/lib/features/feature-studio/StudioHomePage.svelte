<script lang="ts">
    import { onMount } from "svelte";
    import { pushState, replaceState } from "$app/navigation";
    import { page } from "$app/state";
    import { ChevronRight, Sparkles, Wand2 } from "@lucide/svelte";
    import FeaturePreviewDialog from "./FeaturePreviewDialog.svelte";
    import {
        clearFeatureState, clearPending, loadFeatures, loadPending, saveFeatures,
        type FeatureVersion, type GeneratedFeature, type PendingBuild
    } from "./storage";

    interface StudioNavState { feature?: GeneratedFeature }

    let features = $state<GeneratedFeature[]>([]);
    let unfinished = $state<PendingBuild | null>(null);

    // sveltekit: shallow routing, per docs/android-back-navigation.md -- an open preview is a
    // real history entry, so the phone's back button closes it instead of leaving the app
    let openFeature = $derived((page.state as StudioNavState).feature ?? null);

    onMount(() => {
        features = loadFeatures();
        // a marker still here means a build never resolved -- the app closed mid-request
        unfinished = loadPending();
    });

    function openPreview(feature: GeneratedFeature) {
        // $state.snapshot: pushState structured-clones its argument, and a raw $state proxy
        // throws DataCloneError at runtime -- invisible to svelte-check, so it must be unwrapped
        pushState("", { feature: $state.snapshot(feature) } satisfies StudioNavState);
    }

    function removeFeature(id: string) {
        features = features.filter(feature => feature.id !== id);
        saveFeatures(features);
        // whatever the tool had saved goes with it -- ids are never reused, so leaving it behind
        // would just be an orphaned key nothing can ever read again
        clearFeatureState(id);
        if (openFeature?.id === id) history.back();
    }

    /**
     * Replaces the stored feature and, when it is the one on screen, the history entry driving
     * the preview. Without the second half the dialog would keep rendering the snapshot it was
     * opened with and the change would appear not to have happened.
     */
    function update(id: string, change: (feature: GeneratedFeature) => GeneratedFeature) {
        features = features.map(feature => (feature.id === id ? change(feature) : feature));
        saveFeatures(features);

        const updated = features.find(feature => feature.id === id);
        if (updated && openFeature?.id === id) {
            replaceState("", { feature: $state.snapshot(updated) } satisfies StudioNavState);
        }
    }

    function addVersion(id: string, version: FeatureVersion) {
        update(id, feature => ({
            ...feature,
            versions: [...feature.versions, version],
            currentVersionId: version.id
        }));
    }

    function selectVersion(id: string, versionId: string) {
        update(id, feature => ({ ...feature, currentVersionId: versionId }));
    }

    function discardUnfinished() {
        unfinished = null;
        clearPending();
    }

    function describeAge(value: string): string {
        const started = new Date(value).getTime();
        if (Number.isNaN(started)) return "";

        const minutes = Math.round((Date.now() - started) / 60000);
        if (minutes < 1) return "just now";
        if (minutes < 60) return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;

        const hours = Math.round(minutes / 60);
        if (hours < 24) return `${hours} hour${hours === 1 ? "" : "s"} ago`;

        const days = Math.round(hours / 24);
        return `${days} day${days === 1 ? "" : "s"} ago`;
    }
</script>

<svelte:head><title>Studio · DeenLab</title></svelte:head>

<div class="space-y-6">
    <header class="app-header">
        <h1 class="text-3xl font-bold">Studio</h1>
        <p class="mt-2 text-zinc-400">Tools you make yourself, for the way you practise.</p>
    </header>

    <!-- design: the entry point is a full-width card rather than a plain button so it reads as
         part of the same family as Home's and Library's tiles, just wider because it is the one
         action on this screen rather than one of several equals -->
    <a class="tool-card build-entry" href="/feature-studio/build">
        <span class="build-entry__icon"><Wand2 size={22} /></span>
        <span class="min-w-0 flex-1">
            <span class="block font-semibold">Build a new tool</span>
            <span class="mt-0.5 block text-sm text-zinc-400">Describe what you need and it gets made</span>
        </span>
        <ChevronRight size={20} class="shrink-0 text-zinc-500" />
    </a>

    {#if unfinished}
        <!-- design: shown here rather than on the build screen because this is the first thing
             opening Studio puts in front of you, and an interrupted build is only worth
             mentioning to someone who has not already moved on from it -->
        <section class="surface p-4">
            <p class="font-semibold">Unfinished build</p>
            <p class="mt-1 text-sm text-zinc-400">
                You asked for this {describeAge(unfinished.startedAt)}, but the app closed before it
                was ready.
            </p>
            <p class="mt-2 rounded-lg bg-zinc-950 p-3 text-sm text-zinc-300">{unfinished.prompt}</p>
            <div class="mt-3 flex flex-wrap gap-2">
                <a class="button" href="/feature-studio/build">Finish it</a>
                <button class="button button--secondary" onclick={discardUnfinished}>Discard</button>
            </div>
        </section>
    {/if}

    <section>
        <h2 class="mb-3 font-semibold">Your tools</h2>

        {#if features.length === 0}
            <p class="placeholder-slot">Nothing built yet. Your tools will appear here.</p>
        {:else}
            <!-- design: the same two-column tile grid as Home and Library, so a tool you made
                 sits in the app the same way a tool that shipped with it does. No delete button
                 on the tile -- deleting lives inside the preview, which keeps the grid clean -->
            <div class="grid grid-cols-2 gap-3">
                {#each features as feature (feature.id)}
                    <button class="tool-card min-h-[5.5rem]" onclick={() => openPreview(feature)}>
                        <Sparkles size={20} class="text-emerald-400" />
                        <span class="mt-2 block font-semibold">{feature.title}</span>
                    </button>
                {/each}
            </div>
        {/if}
    </section>
</div>

<FeaturePreviewDialog
    feature={openFeature}
    onDelete={removeFeature}
    onAddVersion={addVersion}
    onSelectVersion={selectVersion}
/>

<style>
    .build-entry {
        display: flex;
        align-items: center;
        gap: 0.875rem;
    }

    .build-entry__icon {
        display: grid;
        place-items: center;
        width: 2.75rem;
        height: 2.75rem;
        flex-shrink: 0;
        border-radius: 0.75rem;
        background: color-mix(in srgb, var(--app-accent-strong) 18%, transparent);
        color: var(--app-accent);
    }
</style>
