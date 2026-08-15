<script lang="ts">
    import { onMount } from "svelte";
    import { buildFeature } from "./service";
    import { loadFeatures, saveFeatures, type GeneratedFeature } from "./storage";

    let prompt = "";
    let features: GeneratedFeature[] = [];
    let selected: GeneratedFeature | null = null;
    let isSubmitting = false;
    let error = "";
    let notice = "";

    onMount(() => features = loadFeatures());

    async function submit() {
        if (!prompt.trim() || isSubmitting) return;

        isSubmitting = true;
        error = "";
        notice = "";

        try {
            const result = await buildFeature(prompt);

            if (result.decision === "decline") {
                notice = result.message;
                return;
            }

            const feature: GeneratedFeature = {
                id: crypto.randomUUID(),
                title: result.title.trim() || "Generated feature",
                prompt: prompt.trim(),
                message: result.message,
                html: result.html,
                createdAt: new Date().toISOString()
            };

            features = [feature, ...features];
            saveFeatures(features);
            selected = feature;
            prompt = "";
            notice = result.message;
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Feature generation failed.";
        } finally {
            isSubmitting = false;
        }
    }

    function removeFeature(id: string) {
        features = features.filter(feature => feature.id !== id);
        saveFeatures(features);
        if (selected?.id === id) selected = null;
    }
</script>

<svelte:head><title>Feature Studio · DeenLab</title></svelte:head>

<div class="app-shell"><main class="page-container">
    <header class="app-header">
        <a class="text-sm text-emerald-400 hover:text-emerald-300" href="/">← Home</a>
        <h1 class="mt-4 text-3xl font-bold">Feature Studio</h1>
        <p class="mt-2 max-w-2xl text-zinc-400">Describe a small Deen-related tool. It is generated as a self-contained, sandboxed mini-feature and kept only on this device.</p>
    </header>

    <section class="surface p-5 sm:p-6">
        <label class="mb-2 block font-semibold" for="feature-prompt">What should the feature do?</label>
        <textarea id="feature-prompt" class="control min-h-32 w-full resize-y" placeholder="Example: Create a Tasbeeh counter with common dhikr presets and a daily total." bind:value={prompt}></textarea>
        <div class="mt-4 flex flex-wrap items-center gap-3"><button class="button" onclick={submit} disabled={isSubmitting || !prompt.trim()}>{isSubmitting ? "Generating…" : "Generate feature"}</button><span class="text-sm text-zinc-400">No key is stored in the frontend.</span></div>
        {#if error}<p class="mt-4 text-sm text-red-300" role="alert">{error}</p>{/if}
        {#if notice}<p class="mt-4 text-sm text-emerald-300" aria-live="polite">{notice}</p>{/if}
    </section>

    <div class="mt-8 grid gap-6 lg:grid-cols-[18rem_1fr]">
        <aside>
            <h2 class="mb-3 text-lg font-bold">Your generated features</h2>
            <div class="space-y-2">
                {#each features as feature}
                    <div class="surface p-3">
                        <button class="w-full text-left font-semibold hover:text-emerald-300" onclick={() => selected = feature}>{feature.title}</button>
                        <p class="mt-1 line-clamp-2 text-sm text-zinc-400">{feature.prompt}</p>
                        <button class="mt-3 text-sm text-red-300 hover:text-red-200" onclick={() => removeFeature(feature.id)}>Delete</button>
                    </div>
                {:else}
                    <p class="surface p-4 text-sm text-zinc-400">Generated features will appear here.</p>
                {/each}
            </div>
        </aside>

        <section class="min-w-0">
            <h2 class="mb-3 text-lg font-bold">Preview</h2>
            {#if selected}
                <div class="surface overflow-hidden">
                    <div class="border-b border-zinc-700 p-4"><h3 class="font-semibold">{selected.title}</h3><p class="mt-1 text-sm text-zinc-400">{selected.message}</p></div>
                    <iframe class="h-[38rem] w-full bg-white" title={selected.title} srcdoc={selected.html} sandbox="allow-scripts" referrerpolicy="no-referrer"></iframe>
                </div>
            {:else}
                <p class="surface p-5 text-zinc-400">Choose or generate a feature to preview it here.</p>
            {/if}
        </section>
    </div>
</main></div>
