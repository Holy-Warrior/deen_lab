<script lang="ts">
    import { AlertDialog } from "bits-ui";
    import { Check } from "@lucide/svelte";
    import type { GeneratedFeature } from "./storage";

    let { feature, open = $bindable(), onSelect }: {
        feature: GeneratedFeature;
        open: boolean;
        onSelect: (versionId: string) => void;
    } = $props();

    // newest first, without mutating the stored order -- versions are appended chronologically
    // and that order is what makes "Original" meaningful
    let ordered = $derived([...feature.versions].reverse());

    function label(index: number): string {
        // `ordered` is reversed, so the last entry is the original build
        return index === ordered.length - 1 ? "Original" : `Version ${ordered.length - index}`;
    }

    function when(value: string): string {
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? "" : date.toLocaleString(undefined, {
            day: "numeric", month: "short", hour: "numeric", minute: "2-digit"
        });
    }

    function choose(versionId: string) {
        onSelect(versionId);
        open = false;
    }
</script>

<AlertDialog.Root bind:open>
    <AlertDialog.Portal>
        <AlertDialog.Overlay class="confirm-overlay" />
        <AlertDialog.Content class="confirm-panel">
            <AlertDialog.Title class="text-lg font-bold">Versions</AlertDialog.Title>
            <AlertDialog.Description class="mt-1 text-sm text-zinc-400">
                Every change is kept, so you can go back to any of them.
            </AlertDialog.Description>

            <div class="mt-4 max-h-[50vh] space-y-2 overflow-y-auto">
                {#each ordered as version, index (version.id)}
                    {@const current = version.id === feature.currentVersionId}
                    <button class="version-row" data-current={current} onclick={() => choose(version.id)}>
                        <div class="min-w-0 flex-1">
                            <p class="flex items-center gap-1.5 font-semibold">
                                {label(index)}
                                {#if current}<Check size={15} class="text-emerald-400" />{/if}
                            </p>
                            {#if version.request}
                                <p class="mt-0.5 line-clamp-2 text-xs text-zinc-400">{version.request}</p>
                            {/if}
                            <p class="mt-0.5 text-xs text-zinc-500">{when(version.createdAt)}</p>
                        </div>
                    </button>
                {/each}
            </div>

            <div class="mt-4 flex justify-end">
                <AlertDialog.Cancel class="button button--secondary">Close</AlertDialog.Cancel>
            </div>
        </AlertDialog.Content>
    </AlertDialog.Portal>
</AlertDialog.Root>

<style>
    .version-row {
        display: flex;
        width: 100%;
        align-items: center;
        gap: 0.75rem;
        padding: 0.625rem 0.75rem;
        border: 1px solid var(--app-border);
        border-radius: 0.625rem;
        background: var(--app-canvas);
        text-align: left;
        color: inherit;
    }

    .version-row:hover { background: var(--app-surface-hover); }
    .version-row[data-current="true"] { border-color: var(--app-accent-strong); }
</style>
