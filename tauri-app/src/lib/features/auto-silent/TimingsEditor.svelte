<script lang="ts">
    import { ArrowLeft, Minus, Plus, RotateCcw } from "@lucide/svelte";
    import { formatClock, formatDuration, formatOffset } from "./service";
    import type { EngineMode } from "./engine";
    import {
        durationRange, offsetRange, silencedPrayers,
        type AutoSilentSettings, type SilencedPrayer
    } from "./storage";

    let { settings, mode, times, onOffsetChange, onDurationChange, onBack }: {
        settings: AutoSilentSettings;
        /** Which mode's timings are being edited -- the two need different controls. */
        mode: EngineMode;
        /** Calculated prayer time per prayer, so each row can show the resulting times. */
        times: Partial<Record<SilencedPrayer, Date>>;
        onOffsetChange: (prayer: SilencedPrayer, minutes: number) => void;
        onDurationChange: (prayer: SilencedPrayer, minutes: number) => void;
        onBack: () => void;
    } = $props();

    const labels: Record<SilencedPrayer, string> = {
        fajr: "Fajr", dhuhr: "Dhuhr", asr: "Asr", maghrib: "Maghrib", isha: "Isha"
    };

    let byTime = $derived(mode === "manual");

    function clampTo(range: { min: number; max: number }, value: number) {
        return Math.min(range.max, Math.max(range.min, value));
    }

    function nudgeOffset(prayer: SilencedPrayer, by: number) {
        onOffsetChange(prayer, clampTo(offsetRange, settings.offsets[prayer] + by));
    }

    function nudgeDuration(prayer: SilencedPrayer, by: number) {
        onDurationChange(prayer, clampTo(durationRange, settings.durations[prayer] + by));
    }

    /** In detection mode the lead time pulls the wake earlier; in time mode nothing does. */
    function startsAt(prayer: SilencedPrayer): Date | null {
        const at = times[prayer];
        if (!at) return null;
        const shift = byTime ? settings.offsets[prayer] : settings.offsets[prayer] - settings.leadMinutes;
        return new Date(at.getTime() + shift * 60_000);
    }

    function endsAt(prayer: SilencedPrayer): Date | null {
        const start = startsAt(prayer);
        return start ? new Date(start.getTime() + settings.durations[prayer] * 60_000) : null;
    }

    let anyOffset = $derived(silencedPrayers.some((id) => settings.offsets[id] !== 0));

    function resetAll() {
        silencedPrayers.forEach((id) => onOffsetChange(id, 0));
    }
</script>

<header class="mb-4 flex items-center gap-2">
    <button class="icon-button shrink-0" onclick={onBack} aria-label="Back">
        <ArrowLeft size={20} />
    </button>
    <div class="min-w-0 flex-1">
        <h2 class="truncate font-semibold">Adjust timings</h2>
        <p class="truncate text-xs text-zinc-500">
            {byTime ? "When the phone goes silent, and for how long" : "When the engine starts listening"}
        </p>
    </div>
    {#if anyOffset}
        <button class="icon-button shrink-0" onclick={resetAll} aria-label="Reset all offsets">
            <RotateCcw size={18} />
        </button>
    {/if}
</header>

<!-- design: says plainly that this does not move the prayer times themselves. People read
     calculated prayer times as authoritative, and quietly shifting them to suit a phone setting
     would be the wrong trade -- so the nudge only ever moves the engine. -->
<p class="surface mb-4 p-3 text-xs leading-relaxed text-zinc-400">
    Calculated times are when a prayer begins, which is rarely the minute you actually start.
    Nudging a prayer here moves only
    {byTime ? "when your phone goes silent" : "when Auto Silent begins listening for it"} — the
    times shown in Prayer Times do not change.
</p>

<ul class="flex flex-col gap-2">
    {#each silencedPrayers as prayer}
        {@const at = times[prayer]}
        {@const start = startsAt(prayer)}
        {@const end = endsAt(prayer)}
        <li class="surface p-3" class:opacity-50={!settings.prayers[prayer]}>
            <div class="flex items-center gap-3">
                <div class="min-w-0 flex-1">
                    <p class="text-sm font-semibold">{labels[prayer]}</p>
                    <p class="mt-0.5 text-xs text-zinc-500">
                        {#if !settings.prayers[prayer]}
                            Not selected
                        {:else if at && start}
                            {formatClock(at)} →
                            {#if byTime && end}
                                silent {formatClock(start)}–{formatClock(end)}
                            {:else}
                                listens at {formatClock(start)}
                            {/if}
                        {:else}
                            {formatOffset(settings.offsets[prayer])}
                        {/if}
                    </p>
                </div>

                <div class="stepper">
                    <button
                        onclick={() => nudgeOffset(prayer, -1)}
                        disabled={settings.offsets[prayer] <= offsetRange.min}
                        aria-label={`${labels[prayer]} one minute earlier`}
                    ><Minus size={15} /></button>

                    <span class="stepper__value">{formatOffset(settings.offsets[prayer])}</span>

                    <button
                        onclick={() => nudgeOffset(prayer, 1)}
                        disabled={settings.offsets[prayer] >= offsetRange.max}
                        aria-label={`${labels[prayer]} one minute later`}
                    ><Plus size={15} /></button>
                </div>
            </div>

            <!-- design: duration only exists in time mode. Detection works out its own ending
                 from when you stop moving, so offering a length there would be a control that
                 quietly does nothing. -->
            {#if byTime}
                <div class="mt-2 flex items-center gap-3 border-t border-white/5 pt-2">
                    <p class="min-w-0 flex-1 text-xs text-zinc-500">Stay silent for</p>
                    <div class="stepper">
                        <button
                            onclick={() => nudgeDuration(prayer, -5)}
                            disabled={settings.durations[prayer] <= durationRange.min}
                            aria-label={`${labels[prayer]} five minutes shorter`}
                        ><Minus size={15} /></button>

                        <span class="stepper__value">{formatDuration(settings.durations[prayer])}</span>

                        <button
                            onclick={() => nudgeDuration(prayer, 5)}
                            disabled={settings.durations[prayer] >= durationRange.max}
                            aria-label={`${labels[prayer]} five minutes longer`}
                        ><Plus size={15} /></button>
                    </div>
                </div>
            {/if}
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
