<script lang="ts">
    import { Dialog } from "bits-ui";
    import { ArrowLeft } from "@lucide/svelte";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import FeaturePreview from "./FeaturePreview.svelte";
    import { upgradeFeature, type BuildProgress } from "./service";
    import { activeVersion, type FeatureVersion, type GeneratedFeature } from "./storage";

    // bits-ui: this has to be a real Dialog rather than plain markup laid over the preview.
    // An open bits-ui dialog blocks pointer events outside its own content, so a sibling panel
    // renders perfectly and then ignores every tap -- which is exactly what happened first time.
    let { feature, open = $bindable(), onKeep }: {
        feature: GeneratedFeature;
        open: boolean;
        onKeep: (version: FeatureVersion) => void;
    } = $props();

    let request = $state("");
    let isWorking = $state(false);
    let error = $state("");
    let notice = $state("");
    let status = $state("");

    // design: the result is held here rather than saved. Nothing about the tool changes until
    // "Keep this version" is pressed, so an upgrade that turns out worse costs only the request.
    let candidate = $state<FeatureVersion | null>(null);

    // short labels for the common asks; the full sentence goes into the box, same as the
    // suggestions on the build screen
    const suggestions = [
        { label: "Look nicer", request: "Improve the visual design and spacing, keeping everything it already does" },
        { label: "Bigger text", request: "Make the text and controls larger and easier to read on a phone" },
        { label: "Add a reset", request: "Add a reset button that clears the current progress, with a confirmation" },
        { label: "Remember it", request: "Save my progress so it is still here the next time I open this tool" },
        { label: "Add Arabic", request: "Show the Arabic text alongside what is already there, right-to-left" },
        { label: "Simplify", request: "Simplify the layout, keeping only what matters most" }
    ];

    function describeProgress(update: BuildProgress): string {
        if (update.kind === "waiting") {
            return `Every model is busy. Waiting ${update.seconds} seconds before trying again…`;
        }
        return update.attempt === 1 ? "Working on it…" : `Trying another model (${update.attempt} of ${update.total})…`;
    }

    async function submit() {
        const wanted = request.trim();
        if (!wanted || isWorking) return;

        isWorking = true;
        error = "";
        notice = "";
        candidate = null;
        status = "Working on it…";

        try {
            // always revises the version in use, not the newest -- if the user has stepped back
            // to an earlier version, that is the one they are looking at and asking about
            const result = await upgradeFeature(
                wanted,
                activeVersion(feature).html,
                update => { status = describeProgress(update); }
            );

            if (result.decision === "decline") {
                notice = result.message;
                return;
            }

            candidate = {
                id: crypto.randomUUID(),
                html: result.html,
                request: wanted,
                message: result.message,
                createdAt: new Date().toISOString()
            };
        } catch (cause) {
            // tauri: a Rust Err(String) arrives as a plain string, not an Error
            error = typeof cause === "string"
                ? cause
                : cause instanceof Error ? cause.message : "The change could not be made.";
        } finally {
            isWorking = false;
            status = "";
        }
    }

    function keep() {
        if (!candidate) return;
        onKeep(candidate);
        candidate = null;
        request = "";
        open = false;
    }

    function discard() {
        candidate = null;
        notice = "";
    }
</script>

<Dialog.Root bind:open>
    <Dialog.Portal>
        <Dialog.Content class="upgrade-panel">
    <header class="preview-bar">
        <Dialog.Close class="icon-button shrink-0" aria-label="Close">
            <ArrowLeft size={20} />
        </Dialog.Close>
        <div class="min-w-0 flex-1">
            <Dialog.Title class="truncate font-semibold">Change this tool</Dialog.Title>
            <p class="truncate text-xs text-zinc-500">{feature.title}</p>
        </div>
    </header>

    <div class="upgrade-body">
        <section class="surface p-4">
            <label class="block text-sm font-semibold" for="upgrade-request">What should change?</label>
            <textarea
                id="upgrade-request"
                class="control mt-2 min-h-24 w-full resize-y"
                placeholder="e.g. add a reset button"
                bind:value={request}
                disabled={isWorking}
            ></textarea>

            <div class="mt-3 flex flex-wrap gap-2">
                {#each suggestions as suggestion}
                    <button
                        class="example-chip"
                        type="button"
                        onclick={() => (request = suggestion.request)}
                        disabled={isWorking}
                    >{suggestion.label}</button>
                {/each}
            </div>

            <button class="button mt-4 w-full" onclick={submit} disabled={isWorking || !request.trim()}>
                {isWorking ? "Working…" : "Make the change"}
            </button>

            {#if isWorking && status}
                <p class="mt-3 text-center text-sm text-zinc-400" aria-live="polite">{status}</p>
            {/if}

            {#if error}
                <div class="mt-3"><ErrorBanner message={error} onRetry={submit} /></div>
            {/if}

            {#if notice}
                <p class="mt-3 text-sm text-emerald-300" aria-live="polite">{notice}</p>
            {/if}
        </section>

        <!-- design: the new version is shown here, working, before anything is decided. Reading a
             description of a change tells you very little; using it tells you everything. The
             tool you already have is untouched behind this panel until you keep the new one. -->
        {#if candidate}
            <section class="candidate">
                <div class="candidate__header">
                    <p class="text-sm font-semibold">Try the new version</p>
                    <p class="mt-0.5 text-xs text-zinc-400">{candidate.message}</p>
                </div>

                <div class="candidate__frame">
                    <FeaturePreview html={candidate.html} title="New version" featureId={feature.id} />
                </div>
            </section>
        {/if}
    </div>

    <!-- design: pinned outside the scrolling area on purpose. The candidate is a live iframe and
         swiping over it scrolls the tool, not the page, so actions placed under it can be
         genuinely hard to reach -- the decision must never be the thing you have to fight for. -->
    {#if candidate}
        <footer class="candidate__actions">
            <button class="button button--secondary flex-1" onclick={discard}>Discard</button>
            <button class="button flex-1" onclick={keep}>Keep this version</button>
        </footer>
    {/if}
        </Dialog.Content>
    </Dialog.Portal>
</Dialog.Root>

<style>
    /* .upgrade-panel itself lives in app.css -- the class lands on bits-ui's Dialog.Content,
       which this component's scoped-CSS hash never reaches. Everything below is markup this
       component renders directly, so scoping works normally for it. */
    .upgrade-body {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 1rem;
        padding: 1rem;
        overflow-y: auto;
    }

    .candidate {
        display: flex;
        flex-direction: column;
        border: 1px solid var(--app-accent-strong);
        border-radius: 0.75rem;
        overflow: hidden;
        /* tall enough to actually use the thing, not just glance at it */
        min-height: 22rem;
    }

    .candidate__header {
        padding: 0.75rem 1rem;
        background: var(--app-surface);
        border-bottom: 1px solid var(--app-border);
    }

    .candidate__frame {
        flex: 1;
        display: flex;
        min-height: 18rem;
    }

    .candidate__actions {
        display: flex;
        flex-shrink: 0;
        gap: 0.5rem;
        padding: 0.75rem;
        background: var(--app-surface);
        border-top: 1px solid var(--app-border);
    }

    .example-chip {
        border: 1px solid var(--app-border);
        border-radius: 9999px;
        padding: 0.375rem 0.6875rem;
        font-size: 0.8125rem;
        color: var(--app-muted);
        background: var(--app-canvas);
    }

    .example-chip:hover:not(:disabled) { background: var(--app-surface-hover); color: var(--app-text); }
    .example-chip:disabled { opacity: 0.5; }
</style>
