<script lang="ts">
    import { onMount } from "svelte";
    import { prayerTimesService, nextPrayer, type PrayerDay } from "./service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
    import LocationStatusRow from "$lib/components/location/LocationStatusRow.svelte";
    import { fallbackLocation } from "$lib/components/location/cities";
    import type { Coordinates } from "$lib/services/location";

    const methods = [{ value: "1", label: "Karachi" }, { value: "3", label: "MWL" }, { value: "4", label: "Umm Al-Qura" }];

    let method = $state("1");
    let offset = $state(0);
    let day = $state<PrayerDay | null>(null);
    let tomorrow = $state<PrayerDay | null>(null);
    let isLoading = $state(true);
    let error = $state("");
    let now = $state(new Date());

    // svelte: mirrors DeviceLocation's resolved coordinates into real top-level state -- a
    // snippet body can't declare its own $effect, so this is what the $effect below reacts to
    let activeCoordinates = $state<Coordinates | null>(null);

    let viewedDate = $derived(new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate() + offset));
    let isToday = $derived(offset === 0);

    let dateLabel = $derived(
        offset === 0 ? "Today" :
        offset === 1 ? "Tomorrow" :
        offset === -1 ? "Yesterday" :
        viewedDate.toLocaleDateString("en", { weekday: "long", day: "numeric", month: "short" })
    );

    // design: the highlight only makes sense on today -- "next" is meaningless while looking at
    // a past or future day, so those render as a plain list with nothing singled out
    let upcoming = $derived(
        isToday ? nextPrayer([day, tomorrow].filter((value): value is PrayerDay => value !== null), now) : null
    );

    // design: late at night every row is in the past, so nothing gets highlighted and the list
    // reads as uniformly dim with no answer to "what's next?" -- this is what that state needs,
    // since the answer has rolled over into tomorrow and isn't on screen at all
    let nextIsTomorrow = $derived(
        isToday && upcoming !== null && upcoming.at.toDateString() !== now.toDateString()
    );

    let countdown = $derived.by(() => {
        if (!upcoming) return "";
        const totalSeconds = Math.max(0, Math.floor((upcoming.at.getTime() - now.getTime()) / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    });

    onMount(() => {
        const interval = window.setInterval(() => (now = new Date()), 1_000);
        return () => window.clearInterval(interval);
    });

    // svelte: re-fetches whenever coordinates, method, or the viewed day change -- $effect tracks
    // all three automatically, same as the Sehri & Iftari page, so there's no submit button
    $effect(() => {
        if (activeCoordinates) load(activeCoordinates, method, offset);
    });

    async function load(coordinates: Coordinates, calculationMethod: string, dayOffset: number) {
        isLoading = true;
        error = "";

        const base = new Date();
        const target = new Date(base.getFullYear(), base.getMonth(), base.getDate() + dayOffset);
        const after = new Date(base.getFullYear(), base.getMonth(), base.getDate() + dayOffset + 1);

        try {
            // the following day is only needed to resolve "next prayer" once today's Isha has
            // passed -- after that the next slot is tomorrow's Tahajjud, a few hours later
            await Promise.all([
                prayerTimesService
                    .day(coordinates, calculationMethod, target, (cached) => (day = cached))
                    .then((fresh) => (day = fresh)),
                prayerTimesService
                    .day(coordinates, calculationMethod, after, (cached) => (tomorrow = cached))
                    .then((fresh) => (tomorrow = fresh))
            ]);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load prayer times.";
        } finally {
            isLoading = false;
        }
    }

    function formatTime(at: Date) {
        return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(at);
    }
</script>

<svelte:head><title>Prayer Times · DeenLab</title></svelte:head>

<div class="feature-page space-y-6">
    <header>
        <h1 class="text-2xl font-bold">Prayer Times</h1>
        <p class="mt-1 text-zinc-400">Every prayer for the day, wherever you are.</p>
    </header>

    <!-- svelte: same DeviceLocation + LocationStatusRow pairing as Qibla and Sehri & Iftari.
         Unlike the home card, the full failure UX (banner, permission escalation, city picker)
         belongs here -- fixing a bad location is the reason to be on this page. -->
    <DeviceLocation fallback={fallbackLocation} onCoordinatesChange={(coordinates) => (activeCoordinates = coordinates)}>
        {#snippet children({ locationName, isLoading: locationLoading, status, refresh })}
            <div class="surface space-y-4 p-5">
                <LocationStatusRow {locationName} isLoading={locationLoading} {status} onSync={refresh} />

                <label class="block">
                    <span class="mb-1.5 block text-sm text-zinc-400">Calculation method</span>
                    <select class="control w-full" bind:value={method}>
                        {#each methods as option}<option value={option.value}>{option.label}</option>{/each}
                    </select>
                </label>
            </div>
        {/snippet}
    </DeviceLocation>

    {#if error && !day}
        <ErrorBanner message={error} onRetry={() => activeCoordinates && load(activeCoordinates, method, offset)} />
    {/if}

    <div class="flex items-center justify-between gap-3">
        <button class="button button--secondary" onclick={() => offset--} aria-label="Previous day">←</button>
        <div class="text-center">
            <p class="font-bold">{dateLabel}</p>
            {#if day}<p class="text-sm text-zinc-400">{day.hijri}</p>{/if}
        </div>
        <button class="button button--secondary" onclick={() => offset++} aria-label="Next day">→</button>
    </div>

    {#if !isToday}
        <button class="button button--secondary w-full" onclick={() => (offset = 0)}>Back to today</button>
    {/if}

    {#if nextIsTomorrow && upcoming}
        <p class="surface p-4 text-sm text-zinc-300">
            Every prayer for today has passed. Next is
            <b class="text-emerald-300">{upcoming.meta.label}</b> at {formatTime(upcoming.at)} tomorrow,
            in <span class="tomorrow-countdown">{countdown}</span>.
        </p>
    {/if}

    {#if isLoading && !day}
        <p class="text-zinc-400" aria-live="polite">Loading prayer times…</p>
    {:else if day}
        <div class="space-y-2">
            {#each day.slots as slot (slot.meta.id)}
                {@const isNext = upcoming?.meta.id === slot.meta.id && upcoming.at.getTime() === slot.at.getTime()}
                {@const isPast = isToday && slot.at.getTime() <= now.getTime()}
                {@const isMinor = slot.meta.kind !== "fard"}
                <!-- design: deliberately no artwork here. The mosque images stay exclusive to the
                     home card, where only the next prayer's is ever shown, so the set is
                     discovered gradually across the day rather than laid out all at once. -->
                <article
                    class="prayer-row"
                    class:prayer-row--minor={isMinor}
                    class:prayer-row--next={isNext}
                    class:prayer-row--past={isPast}
                >
                    <div class="min-w-0 flex-1">
                        <p class="prayer-row__name">
                            {slot.meta.label}
                            <span class="prayer-row__arabic" lang="ar" dir="rtl">{slot.meta.arabic}</span>
                        </p>
                        <!-- design: only the two non-obligatory slots carry a caption. The five
                             fard prayers are the expected content of a prayer-times list and need
                             no explaining; captioning them too would flatten the distinction this
                             is here to draw. -->
                        {#if isMinor}<p class="prayer-row__note">{slot.meta.eyebrow}</p>{/if}
                    </div>

                    <div class="shrink-0 text-right">
                        <p class="prayer-row__time">{formatTime(slot.at)}</p>
                        {#if isNext}<p class="prayer-row__countdown">{countdown}</p>{/if}
                    </div>
                </article>
            {/each}
        </div>

        <!-- design: sunrise and Tahajjud sit in this list alongside the five obligatory prayers,
             so say plainly what they are rather than letting the list imply all seven are fard -->
        <p class="text-xs leading-relaxed text-zinc-500">
            Sunrise marks the end of the Fajr window rather than a prayer of its own, and Tahajjud
            is a voluntary night prayer beginning in the last third of the night.
        </p>
    {/if}
</div>

<style>
    .prayer-row {
        display: flex;
        align-items: center;
        gap: 0.875rem;
        padding: 0.875rem 1rem;
        border: 2px solid var(--app-border);
        border-radius: 0.75rem;
        background: var(--app-surface);
    }

    .prayer-row__name { font-weight: 600; }
    .prayer-row__time { font-weight: 700; }

    .prayer-row__arabic {
        margin-inline-start: 0.375rem;
        font-size: 0.875rem;
        font-weight: 500;
        color: var(--app-muted);
    }

    /* design: Tahajjud and Sunrise are not two of the five daily prayers -- one is voluntary and
       the other isn't a prayer at all -- so they deliberately stop being cards. Dropping the
       surface and border demotes them to annotations *between* the fard cards, and insetting
       them leaves the five obligatory prayers with an unbroken left edge of their own that the
       eye can follow straight down the list. */
    .prayer-row--minor {
        margin-inline: 1rem;
        padding: 0.4375rem 0.75rem;
        border: none;
        border-inline-start: 2px solid var(--app-border);
        border-radius: 0;
        background: transparent;
    }

    .prayer-row--minor .prayer-row__name,
    .prayer-row--minor .prayer-row__time {
        font-size: 0.875rem;
        font-weight: 600;
        color: var(--app-muted);
    }

    .prayer-row--minor .prayer-row__arabic { font-size: 0.75rem; }

    .prayer-row__note {
        font-size: 0.6875rem;
        color: var(--app-muted);
        opacity: 0.75;
    }

    /* design: border is always 2px (just neutral by default) so a row's box size never shifts
       when it becomes the highlighted one -- same convention as .today-slot in Sehri & Iftari */
    .prayer-row--next {
        border-color: var(--app-accent-strong);
        background: color-mix(in srgb, var(--app-accent-strong) 12%, var(--app-surface));
    }

    /* a minor row can still be the next one up (Tahajjud overnight, Sunrise after Fajr), so it
       needs its own highlight -- the shared rule above only sets border-color, which does nothing
       against `border-style: none` */
    .prayer-row--minor.prayer-row--next {
        border-inline-start-color: var(--app-accent-strong);
        background: transparent;
    }

    .prayer-row--minor.prayer-row--next .prayer-row__name,
    .prayer-row--minor.prayer-row--next .prayer-row__time { color: var(--app-text); }

    .tomorrow-countdown {
        font-variant-numeric: tabular-nums;
        font-weight: 700;
        color: var(--app-accent-strong);
    }

    .prayer-row__countdown {
        font-variant-numeric: tabular-nums;
        font-size: 0.75rem;
        font-weight: 700;
        color: var(--app-accent-strong);
    }

    /* design: dimmed rather than hidden -- a prayer whose time has passed is still worth being
       able to check, it just shouldn't compete with the ones still ahead */
    .prayer-row--past { opacity: 0.55; }
</style>
