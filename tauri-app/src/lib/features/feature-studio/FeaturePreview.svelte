<script lang="ts">
    import { composeDocument, loadTailwindRuntime, storageMessageSource } from "./document";
    import { loadFeatureState, sanitiseFeatureState, saveFeatureState } from "./storage";

    let { html, title, featureId }: { html: string; title: string; featureId: string } = $props();

    // svelte: written as $state<T>(null), not `let x: T | null = $state(null)` -- svelte-check
    // narrows the annotated form to the type of the initialiser alone and then rejects every
    // later assignment. See docs/frontend-architecture.md.
    let srcdoc = $state<string | null>(null);
    let error = $state<string | null>(null);
    let frame = $state<HTMLIFrameElement | null>(null);

    $effect(() => {
        // read the props up front so this effect re-runs when a different feature is previewed
        const markup = html;
        const id = featureId;
        let cancelled = false;

        srcdoc = null;
        error = null;

        loadTailwindRuntime()
            // the saved state is inlined into the document rather than sent afterwards, so the
            // feature's own script can read it synchronously on its very first line
            .then(runtime => { if (!cancelled) srcdoc = composeDocument(markup, runtime, loadFeatureState(id)); })
            .catch(cause => {
                if (!cancelled) error = cause instanceof Error ? cause.message : "The preview could not be prepared.";
            });

        return () => { cancelled = true; };
    });

    $effect(() => {
        const id = featureId;
        const element = frame;
        if (!element) return;

        function receive(event: MessageEvent) {
            // security: the frame has an opaque origin, so event.origin is the string "null" and
            // is useless for identifying it. The window reference is the only trustworthy check --
            // it proves the message came from this frame and not from any other page or frame.
            if (event.source !== element?.contentWindow) return;

            const message = event.data;
            if (message?.source !== storageMessageSource || message?.kind !== "storage") return;

            // the payload was built by model-written code, so it is validated, not trusted
            const state = sanitiseFeatureState(message.state);
            if (state) saveFeatureState(id, state);
        }

        window.addEventListener("message", receive);
        return () => window.removeEventListener("message", receive);
    });
</script>

{#if error}
    <div class="grid flex-1 place-items-center p-6 text-center">
        <p class="text-sm text-zinc-400">{error}</p>
    </div>
{:else if srcdoc}
    <!-- html: sandbox without allow-same-origin puts the feature on an opaque origin, so it can
         reach neither the app's storage nor its DOM. allow-scripts is the only capability
         granted, because both Tailwind's runtime and the feature's own behaviour need it.
         Deliberately NOT allow-same-origin: pairing it with allow-scripts would let the frame
         remove its own sandbox attribute and escape entirely. postMessage still crosses that
         boundary, which is how saving works without granting any of the above. -->
    <iframe
        bind:this={frame}
        class="preview-frame"
        {title}
        {srcdoc}
        sandbox="allow-scripts"
        referrerpolicy="no-referrer"
    ></iframe>
{:else}
    <div class="grid flex-1 place-items-center p-6">
        <p class="text-sm text-zinc-400" aria-live="polite">Preparing preview…</p>
    </div>
{/if}

<style>
    .preview-frame {
        flex: 1;
        width: 100%;
        border: 0;
        background: var(--app-canvas);
    }
</style>
