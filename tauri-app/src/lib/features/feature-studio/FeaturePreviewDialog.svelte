<script lang="ts">
    import { AlertDialog, Dialog } from "bits-ui";
    import { ArrowLeft, History, Trash2, Wand2 } from "@lucide/svelte";
    import FeaturePreview from "./FeaturePreview.svelte";
    import UpgradePanel from "./UpgradePanel.svelte";
    import VersionPicker from "./VersionPicker.svelte";
    import { activeVersion, type FeatureVersion, type GeneratedFeature } from "./storage";

    // svelte: `feature` is the single source of open/closed -- non-null means open. Keeping the
    // dialog stateless like this is what lets the caller drive it straight from page.state.
    let { feature, onDelete, onAddVersion, onSelectVersion }: {
        feature: GeneratedFeature | null;
        onDelete: (id: string) => void;
        onAddVersion: (id: string, version: FeatureVersion) => void;
        onSelectVersion: (id: string, versionId: string) => void;
    } = $props();

    // design: deleting a generated tool is unrecoverable -- the markup only exists on this device
    // and rebuilding it costs a request and produces something different. So the confirm button
    // is held out for a few seconds: long enough that the second tap has to be a decision rather
    // than a continuation of the first.
    const holdSeconds = 4;

    let confirming = $state(false);
    let secondsLeft = $state(0);
    let upgrading = $state(false);
    let pickingVersion = $state(false);

    let current = $derived(feature ? activeVersion(feature) : null);

    $effect(() => {
        // reading `confirming` is what re-runs this; secondsLeft is only ever written here, never
        // read, so the countdown can't retrigger the effect that drives it
        if (!confirming) {
            secondsLeft = 0;
            return;
        }

        secondsLeft = holdSeconds;
        const timer = setInterval(() => {
            secondsLeft -= 1;
            if (secondsLeft <= 0) clearInterval(timer);
        }, 1000);

        return () => clearInterval(timer);
    });

    function confirmDelete() {
        if (!feature || secondsLeft > 0) return;

        confirming = false;
        onDelete(feature.id);
    }

    function keepVersion(version: FeatureVersion) {
        if (!feature) return;
        onAddVersion(feature.id, version);
    }
</script>

<!-- bits-ui: open comes from page.state rather than a local flag, so the hardware back button,
     the Escape key and the close button all run through the same history entry and cannot drift
     out of sync. onOpenChange only ever has to undo that entry. -->
<Dialog.Root open={feature !== null} onOpenChange={isOpen => { if (!isOpen) history.back(); }}>
    <Dialog.Portal>
        <Dialog.Overlay class="overlay" />
        <Dialog.Content class="preview-panel">
            {#if feature && current}
                <header class="preview-bar">
                    <Dialog.Close class="icon-button shrink-0" aria-label="Close">
                        <ArrowLeft size={20} />
                    </Dialog.Close>
                    <div class="min-w-0 flex-1">
                        <Dialog.Title class="truncate font-semibold">{feature.title}</Dialog.Title>
                        {#if feature.versions.length > 1}
                            <p class="truncate text-xs text-zinc-500">
                                {current.id === feature.versions[feature.versions.length - 1].id
                                    ? `${feature.versions.length} versions`
                                    : "Older version"}
                            </p>
                        {/if}
                    </div>

                    <button class="icon-button shrink-0" onclick={() => (upgrading = true)} aria-label="Change this tool">
                        <Wand2 size={18} />
                    </button>
                    <!-- design: only offered once there is something to choose between -- a
                         history button on a tool with one version is a dead end -->
                    {#if feature.versions.length > 1}
                        <button class="icon-button shrink-0" onclick={() => (pickingVersion = true)} aria-label="Version history">
                            <History size={18} />
                        </button>
                    {/if}
                    <button class="icon-button shrink-0" onclick={() => (confirming = true)} aria-label="Delete this tool">
                        <Trash2 size={18} />
                    </button>
                </header>

                <FeaturePreview html={current.html} title={feature.title} featureId={feature.id} />
            {/if}
        </Dialog.Content>
    </Dialog.Portal>
</Dialog.Root>

{#if feature}
    <UpgradePanel {feature} bind:open={upgrading} onKeep={keepVersion} />
{/if}

{#if feature}
    <VersionPicker {feature} bind:open={pickingVersion} onSelect={versionId => onSelectVersion(feature!.id, versionId)} />
{/if}

<!-- bits-ui: AlertDialog rather than Dialog -- it has no dismiss-on-outside-click and traps focus
     on the actions, which is the right behaviour for a destructive choice. -->
<AlertDialog.Root bind:open={confirming}>
    <AlertDialog.Portal>
        <AlertDialog.Overlay class="confirm-overlay" />
        <AlertDialog.Content class="confirm-panel">
            <AlertDialog.Title class="text-lg font-bold">Delete this tool?</AlertDialog.Title>
            <AlertDialog.Description class="mt-2 text-sm text-zinc-400">
                {feature ? `"${feature.title}" will be removed from this device` : ""}{feature && feature.versions.length > 1 ? `, along with all ${feature.versions.length} of its versions` : ""}. This can't be
                undone — building it again will produce something a little different.
            </AlertDialog.Description>

            <div class="mt-5 flex justify-end gap-2">
                <AlertDialog.Cancel class="button button--secondary">Keep it</AlertDialog.Cancel>
                <!-- svelte: not AlertDialog.Action -- that closes the dialog on any click, which
                     would dismiss it even while the button is still held out -->
                <button class="button button--danger" onclick={confirmDelete} disabled={secondsLeft > 0}>
                    {secondsLeft > 0 ? `Delete (${secondsLeft})` : "Delete"}
                </button>
            </div>

            {#if secondsLeft > 0}
                <p class="mt-2 text-right text-xs text-zinc-500" aria-live="polite">
                    Hold on a moment before confirming.
                </p>
            {/if}
        </AlertDialog.Content>
    </AlertDialog.Portal>
</AlertDialog.Root>
