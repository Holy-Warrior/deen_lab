<script lang="ts">
    import { onMount } from "svelte";
    import { goto, pushState } from "$app/navigation";
    import { ArrowLeft } from "@lucide/svelte";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import { buildFeature, type BuildProgress } from "./service";
    import {
        clearPending, loadFeatures, loadPending, savePending, saveFeatures,
        type GeneratedFeature
    } from "./storage";

    let prompt = $state("");
    let isBuilding = $state(false);
    let error = $state("");
    let notice = $state("");
    let status = $state("");

    // design: short labels, not the full sentence they insert. The prompts themselves are long
    // enough to wrap to three lines each on a 360dp phone, which turned the suggestions into the
    // largest thing on the screen -- the point of a suggestion is to be scannable.
    const examples = [
        { label: "Tasbeeh counter", prompt: "A tasbeeh counter with presets for SubhanAllah, Alhamdulillah and Allahu Akbar, showing a running total" },
        { label: "Zakat calculator", prompt: "A zakat calculator for cash, gold and silver" },
        { label: "Fasting tracker", prompt: "A 30-day Ramadan fasting tracker with a progress bar" },
        { label: "99 Names", prompt: "Flashcards for the 99 names of Allah, showing the Arabic and the meaning" },
        { label: "Dhikr after salah", prompt: "A guided counter for the dhikr said after each fard prayer" }
    ];

    onMount(() => {
        // an interrupted build left its prompt behind; arriving here (usually from "Finish it"
        // on the Studio screen) should land with it ready to go rather than retyped
        prompt = loadPending()?.prompt ?? "";
    });

    function describeProgress(update: BuildProgress): string {
        if (update.kind === "waiting") {
            return `Every model is busy. Waiting ${update.seconds} seconds before trying again…`;
        }
        return update.attempt === 1
            ? "Building…"
            : `Trying another model (${update.attempt} of ${update.total})…`;
    }

    async function generate() {
        const description = prompt.trim();
        if (!description || isBuilding) return;

        isBuilding = true;
        error = "";
        notice = "";
        status = "Building…";
        // held until after the `finally` below, because navigating inside the try block would
        // mount the Studio screen while the pending marker is still set -- it would read that
        // marker and announce an "unfinished build" for the build that just succeeded
        let built: GeneratedFeature | null = null;
        // written before the request and cleared in `finally`, so it only survives if this app
        // never got to run that `finally` -- see PendingBuild in storage.ts
        savePending({ prompt: description, startedAt: new Date().toISOString() });

        try {
            const result = await buildFeature(description, update => { status = describeProgress(update); });

            if (result.decision === "decline") {
                notice = result.message;
                return;
            }

            const createdAt = new Date().toISOString();
            const firstVersion = {
                id: crypto.randomUUID(),
                html: result.html,
                request: description,
                message: result.message,
                createdAt
            };
            const feature: GeneratedFeature = {
                id: crypto.randomUUID(),
                title: result.title.trim() || "Generated tool",
                createdAt,
                versions: [firstVersion],
                currentVersionId: firstVersion.id
            };

            const features = [feature, ...loadFeatures()];
            if (!saveFeatures(features)) {
                error = "The tool was built, but there was no room left to save it on this device.";
                return;
            }

            prompt = "";
            built = feature;
        } catch (cause) {
            // tauri: a Rust Err(String) arrives as a plain string, not an Error, so the usual
            // `cause instanceof Error` check alone would swallow every backend message
            error = typeof cause === "string"
                ? cause
                : cause instanceof Error ? cause.message : "The tool could not be built.";
        } finally {
            // whatever the outcome, the user has now seen it, so there is nothing left to resume
            clearPending();
            isBuilding = false;
            status = "";
        }

        // land back on the Studio screen with the finished tool already open -- the user just
        // waited for it, so making them find and tap it would be a poor reward
        if (built) {
            await goto("/feature-studio");
            pushState("", { feature: built });
        }
    }
</script>

<svelte:head><title>Build a tool · DeenLab</title></svelte:head>

<div class="feature-page space-y-5">
    <header>
        <a class="back-link" href="/feature-studio">
            <ArrowLeft size={16} />
            Studio
        </a>
        <h1 class="mt-3 text-2xl font-bold">Build a tool</h1>
        <p class="mt-1 text-zinc-400">Describe a small Deen tool and it will be built for you.</p>
    </header>

    <section class="surface p-5">
        <label class="block font-semibold" for="feature-prompt">What should it do?</label>
        <textarea
            id="feature-prompt"
            class="control mt-2 min-h-32 w-full resize-y"
            placeholder="e.g. a tasbeeh counter with a running total"
            bind:value={prompt}
            disabled={isBuilding}
        ></textarea>

        <p class="mt-4 text-xs font-semibold uppercase tracking-wide text-zinc-500">Or start from one of these</p>
        <div class="mt-2 flex flex-wrap gap-2">
            {#each examples as example}
                <button
                    class="example-chip"
                    type="button"
                    onclick={() => (prompt = example.prompt)}
                    disabled={isBuilding}
                >{example.label}</button>
            {/each}
        </div>

        <button class="button mt-5 w-full" onclick={generate} disabled={isBuilding || !prompt.trim()}>
            {isBuilding ? "Building…" : "Build it"}
        </button>

        <!-- svelte: aria-live so a screen reader announces a model switch or a wait, rather than
             the status silently changing under a spinner -->
        {#if isBuilding && status}
            <p class="mt-3 text-center text-sm text-zinc-400" aria-live="polite">{status}</p>
        {/if}

        {#if error}
            <div class="mt-4"><ErrorBanner message={error} onRetry={generate} /></div>
        {/if}

        {#if notice}
            <p class="mt-4 text-sm text-emerald-300" aria-live="polite">{notice}</p>
        {/if}
    </section>

    <!-- design: kept as a quiet footnote rather than part of the introduction. It matters when a
         build is refused, not when someone is deciding what to ask for. -->
    <p class="text-xs text-zinc-500">
        Tools are written by an AI model, so check anything that matters. Building is limited to a
        few tools each minute.
    </p>
</div>

<style>
    .back-link {
        display: inline-flex;
        align-items: center;
        gap: 0.375rem;
        color: var(--app-muted);
        font-size: 0.875rem;
        text-decoration: none;
    }

    .back-link:hover { color: var(--app-text); }

    .example-chip {
        border: 1px solid var(--app-border);
        border-radius: 9999px;
        padding: 0.4375rem 0.75rem;
        font-size: 0.8125rem;
        color: var(--app-muted);
        background: var(--app-canvas);
    }

    .example-chip:hover:not(:disabled) { background: var(--app-surface-hover); color: var(--app-text); }
    .example-chip:disabled { opacity: 0.5; }
</style>
