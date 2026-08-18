<script lang="ts">
    import { ArrowLeft, Minus, Plus, RotateCcw } from "@lucide/svelte";
    import { formatClock, formatOffset } from "./service";
    import { offsetRange, silencedPrayers, type AutoSilentSettings, type SilencedPrayer } from "./storage";

    let { settings, times, onChange, onBack }: {
        settings: AutoSilentSettings;
        /** Calculated prayer time per prayer, so each row can show the resulting wake time. */
        times: Partial<Record<SilencedPrayer, Date>>;
        onChange: (prayer: SilencedPrayer, minutes: number) => void;
        onBack: () => void;
    } = $props();

    const labels: Record<SilencedPrayer, string> = {
        fajr: "Fajr", dhuhr: "Dhuhr", asr: "Asr", maghrib: "Maghrib", isha: "Isha"
    };

    function nudge(prayer: SilencedPrayer, by: number) {
        const next = Math.min(offsetRange.max, Math.max(offsetRange.min, settings.offsets[prayer] + by));
        onChange(prayer, next);
    }

    function wakeAt(prayer: SilencedPrayer): string | null {
        const at = times[prayer];
        if (!at) return null;
        const shift = settings.offsets[prayer] - settings.leadMinutes;
        return formatClock(new Date(at.getTime() + shift * 60_000));
    }
</script>

<header class="mb-4 flex items-center gap-2">
    <button class="icon-button shrink-0" onclick={onBack} aria-label="Back">
        <ArrowLeft size={20} />
    </button>
    <div class="min-w-0 flex-1">
        <h2 class="truncate font-semibold">Adjust timings</h2>
        <p class="truncate text-xs text-zinc-500">When the engine starts listening</p>
    </div>
    {#if silencedPrayers.some((id) => settings.offsets[id] !== 0)}
        <button class="icon-button shrink-0" onclick={() => silencedPrayers.forEach((id) => onChange(id, 0))} aria-label="Reset all offsets">
            <RotateCcw size={18} />
        </button>
    {/if}
</header>

<!-- design: says plainly that this does not move the prayer times themselves. People read
     calculated prayer times as authoritative, and quietly shifting them to suit a phone setting
     would be the wrong trade -- so the nudge only ever moves the engine. -->
<p class="surface mb-4 p-3 text-xs leading-relaxed text-zinc-400">
    Calculated times are when a prayer begins, which is rarely the minute you actually start.
    Nudging a prayer here moves only when Auto Silent begins listening for it — the times shown
    in Prayer Times do not change.
</p>

<ul class="flex flex-col gap-2">
    {#each silencedPrayers as prayer}
        {@const at = times[prayer]}
        <li class="surface flex items-center gap-3 p-3">
            <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold">{labels[prayer]}</p>
                <p class="mt-0.5 text-xs text-zinc-500">
                    {#if at}
                        {formatClock(at)} → listens at {wakeAt(prayer)}
                    {:else}
                        {formatOffset(settings.offsets[prayer])}
                    {/if}
                </p>
            </div>

            <div class="stepper">
                <button
                    onclick={() => nudge(prayer, -1)}
                    disabled={settings.offsets[prayer] <= offsetRange.min}
                    aria-label={`${labels[prayer]} one minute earlier`}
                ><Minus size={15} /></button>

                <span class="stepper__value">{formatOffset(settings.offsets[prayer])}</span>

                <button
                    onclick={() => nudge(prayer, 1)}
                    disabled={settings.offsets[prayer] >= offsetRange.max}
                    aria-label={`${labels[prayer]} one minute later`}
                ><Plus size={15} /></button>
            </div>
        </li>
    {/each}
</ul>

<style>
    .stepper {
        display: flex;
        align-items: center;
        flex-shrink: 0;
        gap: 0.125rem;
        border: 1px solid var(--app-border);
        border-radius: 9999px;
        background: var(--app-canvas);
    }

    .stepper button {
        display: grid;
        place-items: center;
        width: 2rem;
        height: 2rem;
        border-radius: 9999px;
        color: var(--app-text);
    }

    .stepper button:disabled { opacity: 0.3; }

    /* fixed width so the row doesn't jitter as the label grows from "on time" to "+120 min" */
    .stepper__value {
        min-width: 4.25rem;
        text-align: center;
        font-size: 0.75rem;
        font-variant-numeric: tabular-nums;
        color: var(--app-muted);
    }
</style>
