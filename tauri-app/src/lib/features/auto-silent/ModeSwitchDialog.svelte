<script lang="ts">
    import { AlertDialog } from "bits-ui";
    import { formatClock } from "./service";
    import type { ActiveSession, EngineMode, ModeSwitchPolicy } from "./engine";

    let { session, target, open = $bindable(), onChoose }: {
        /** What the engine is busy doing, straight from the blocked switch. */
        session: ActiveSession;
        /** The mode the user asked for. */
        target: EngineMode;
        open: boolean;
        onChoose: (policy: ModeSwitchPolicy) => void;
    } = $props();

    const names: Record<EngineMode, string> = {
        disabled: "Off",
        manual: "By time",
        ml: "Detection"
    };

    // design: the wording turns on `silencing` rather than on the mode. "Your phone is silent
    // right now" is the fact that makes switching a bad idea; whether a model or a clock decided
    // it is not something the user needs to think about at this moment.
    let heading = $derived(session.silencing ? "Your phone is silent right now" : "Auto Silent is running");

    let until = $derived(session.endsAtMillis ? formatClock(new Date(session.endsAtMillis)) : null);

    function choose(policy: ModeSwitchPolicy) {
        onChoose(policy);
        open = false;
    }
</script>

<AlertDialog.Root bind:open>
    <AlertDialog.Portal>
        <AlertDialog.Overlay class="confirm-overlay" />
        <AlertDialog.Content class="confirm-panel">
            <AlertDialog.Title class="text-lg font-bold">{heading}</AlertDialog.Title>
            <AlertDialog.Description class="mt-1 text-sm leading-relaxed text-zinc-400">
                {#if session.silencing}
                    {#if session.label && until}
                        Auto Silent has your phone silent for {session.label}, until {until}.
                    {:else if until}
                        Auto Silent has your phone silent until {until}.
                    {:else}
                        Auto Silent has your phone silent.
                    {/if}
                    Switching to <strong class="text-zinc-200">{names[target]}</strong> ends that
                    and turns your ringer back on.
                {:else}
                    Auto Silent is listening for prayer movement. Switching to
                    <strong class="text-zinc-200">{names[target]}</strong> stops it, so this prayer
                    would not be covered.
                {/if}
            </AlertDialog.Description>

            <!-- design: the safe option is first and visually primary. Switching immediately is
                 the one that can make a phone ring mid-prayer, so it does not get to be the
                 easiest thing to tap. -->
            <div class="mt-5 flex flex-col gap-2">
                <button class="button" onclick={() => choose("afterCurrentSession")}>
                    {session.silencing ? "Switch when this finishes" : "Switch after this prayer"}
                </button>
                <button class="button button--secondary" onclick={() => choose("immediate")}>
                    Switch now
                </button>
                <AlertDialog.Cancel class="button button--secondary">Keep as it is</AlertDialog.Cancel>
            </div>
        </AlertDialog.Content>
    </AlertDialog.Portal>
</AlertDialog.Root>
