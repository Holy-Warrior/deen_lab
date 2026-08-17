<script lang="ts">
    import { onMount } from "svelte";
    import { currentCoordinates, networkCoordinates, type Coordinates } from "$lib/services/location";
    import { fallbackLocation } from "$lib/components/location/cities";
    import { prayerTimesService, nextPrayer, type PrayerDay } from "$lib/features/prayer-times/service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";

    // Karachi -- matches the default the Sehri & Iftari page ships with. The home card has no
    // settings UI of its own; the full Prayer Times page will own the method picker.
    const method = "1";

    // svelte: the two days are held separately rather than as one array so each can paint the
    // moment its own cached copy comes back, independently of the other's network request --
    // collapsing them into a single `await Promise.all` assignment would throw away the
    // instant-paint half of the cache-then-network pattern and leave the card on "Loading…"
    // until the slowest request landed
    let today = $state<PrayerDay | null>(null);
    let tomorrow = $state<PrayerDay | null>(null);
    let days = $derived([today, tomorrow].filter((day): day is PrayerDay => day !== null));

    let now = $state(new Date());
    let isLoading = $state(true);
    let error = $state("");

    // svelte: pure re-derivation every tick instead of storing "which prayer is next" -- the
    // rollover from one prayer to the next then just falls out of the clock, with no timer to
    // schedule at each boundary and no chance of the two drifting apart
    let slot = $derived(nextPrayer(days, now));

    let countdown = $derived.by(() => {
        if (!slot) return "--:--:--";
        const totalSeconds = Math.max(0, Math.floor((slot.at.getTime() - now.getTime()) / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    });

    let whenLabel = $derived.by(() => {
        if (!slot) return "";
        const time = new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(slot.at);
        const isToday = slot.at.toDateString() === now.toDateString();
        return `${time} · ${isToday ? "Today" : "Tomorrow"}`;
    });

    onMount(() => {
        load();

        // design: every second, matching the Sehri & Iftari countdown -- a moving seconds digit
        // is what makes this read as live rather than a stale estimate
        const interval = window.setInterval(() => (now = new Date()), 1_000);
        return () => window.clearInterval(interval);
    });

    // design: unlike the feature pages, home resolves location *silently* -- no ErrorBanner, no
    // city picker, no permission-escalation flow. A dashboard card shouldn't nag on every app
    // launch; it just shows the fallback city's times. DeviceLocation's full failure UX belongs
    // on the Prayer Times page, where fixing it is the point of being there.
    //
    // No reverse-geocode either: the card doesn't display a place name, so resolving one would
    // be a network round trip whose result is thrown away. The Prayer Times page shows it.
    async function load() {
        isLoading = true;
        error = "";

        // design: the same GPS -> network -> hard-coded city ladder DeviceLocation walks, just
        // without any of its UI. The card can't show a status icon or an "approximate" label, so
        // it silently takes the best position it can get and says nothing about which rung it
        // landed on -- the Prayer Times page is where that distinction is surfaced.
        let coordinates: Coordinates = fallbackLocation;
        try {
            coordinates = await currentCoordinates();
        } catch {
            try {
                const network = await networkCoordinates();
                coordinates = { latitude: network.latitude, longitude: network.longitude };
            } catch {
                // no-op: fall back to the default city's times rather than showing nothing
            }
        }

        const todayDate = new Date();
        const tomorrowDate = new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate() + 1);

        try {
            // both days are needed: after Isha, the next slot is tomorrow's Tahajjud
            await Promise.all([
                prayerTimesService
                    .day(coordinates, method, todayDate, (cached) => (today = cached))
                    .then((fresh) => (today = fresh)),
                prayerTimesService
                    .day(coordinates, method, tomorrowDate, (cached) => (tomorrow = cached))
                    .then((fresh) => (tomorrow = fresh))
            ]);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load prayer times.";
        } finally {
            isLoading = false;
        }
    }
</script>

<!-- design: the banner only appears when there is nothing at all to show. Everywhere else in the
     app a failed refresh always surfaces one, but home is the first thing seen on every launch --
     a red bar there each time the device happens to be offline, while perfectly good cached times
     sit right below it, would be noise rather than information. -->
{#if error && days.length === 0}
    <ErrorBanner message={error} onRetry={load} />
{:else if slot}
    <!-- sveltekit: a plain <a> rather than a button + goto() -- SvelteKit intercepts same-origin
         anchors and routes them client-side anyway, so this keeps real link semantics (focus,
         long-press, middle-click) for free -->
    <a class="prayer-card" href="/prayer-times" style:background-image={`url("${slot.meta.image}")`}>
        <div class="prayer-card__scrim"></div>

        <div class="prayer-card__body">
            <p class="prayer-card__eyebrow">{slot.meta.eyebrow}</p>
            <h2 class="prayer-card__name">
                {slot.meta.label}
                <span class="prayer-card__arabic" lang="ar" dir="rtl">{slot.meta.arabic}</span>
            </h2>
            <p class="prayer-card__countdown">{countdown}</p>
            <p class="prayer-card__when">{whenLabel}</p>
        </div>
    </a>
{:else}
    <div class="placeholder-slot" style:min-height="var(--config-prayer-card-min-height)" style:border-radius="1.25rem">
        {isLoading ? "Loading prayer times…" : "No upcoming prayer time"}
    </div>
{/if}

<style>
    .prayer-card {
        position: relative;
        /* design: the body is vertically centred rather than top-aligned -- the card's height is
           driven by the artwork (min-height), not by its four short lines of text, so anchoring
           them to the top would leave an obvious dead band along the bottom */
        display: flex;
        align-items: center;
        overflow: hidden;
        min-height: var(--config-prayer-card-min-height);
        border-radius: 1.25rem;
        border: 1px solid var(--app-border);
        color: inherit;
        text-decoration: none;
        transition: border-color 150ms ease;
        /* design: `right center` rather than `cover`'s default centring -- the mosque lives in
           the right third of every image, so anything cropped off has to come off the (empty)
           left. Centring would eat into the art at narrow widths. */
        background-position: right center;
        background-size: cover;
        background-repeat: no-repeat;
    }

    /* matches .tool-card's affordance in app.css, so both things on the home screen signal
       "tappable" the same way */
    .prayer-card:hover { border-color: var(--app-accent-strong); }
    .prayer-card:focus-visible { outline: 2px solid var(--app-accent); outline-offset: 2px; }

    /* design: measured, not eyeballed -- the generated art fails WCAG AA for white text on its
       own in three of the seven slots (Dhuhr 2.9:1, Isha 3.1:1, Maghrib 3.2:1). This scrim is
       kept as a separate layer rather than baked into the images so it stays tunable, and it
       fades out well before the right third so the mosque itself stays vivid. */
    .prayer-card__scrim {
        position: absolute;
        inset: 0;
        background: var(--config-prayer-card-scrim);
    }

    .prayer-card__body {
        position: relative;
        /* keeps the text clear of the mosque art, and inside the part of the scrim that is
           actually dark enough to carry it */
        max-width: 62%;
        padding: 1.25rem;
        /* belt-and-braces with the scrim: buys legibility over the brightest slots without
           needing a heavier overlay that would wash the art out */
        text-shadow: 0 1px 3px rgb(0 0 0 / 0.55);
    }

    .prayer-card__eyebrow {
        font-size: 0.8125rem;
        font-weight: 600;
        color: rgb(255 255 255 / 0.75);
    }

    /* design: 1.5rem/700 is Tailwind's text-2xl font-bold -- deliberately the exact same size and
       weight as the "Assalamu Alaikum!" greeting above the card, so the two read as one
       typographic level instead of the card shouting over the page's own heading */
    .prayer-card__name {
        margin-top: 0.125rem;
        font-size: 1.5rem;
        font-weight: 700;
        line-height: 1.2;
    }

    .prayer-card__arabic {
        margin-inline-start: 0.5rem;
        font-size: 1rem;
        font-weight: 500;
        color: rgb(255 255 255 / 0.7);
    }

    /* tailwind/css: tabular-nums keeps every digit the same width, so the seconds ticking over
       doesn't make the whole countdown jitter left and right once a second */
    .prayer-card__countdown {
        margin-top: 0.375rem;
        font-size: 1.5rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
        line-height: 1.2;
    }

    .prayer-card__when {
        margin-top: 0.25rem;
        font-size: 0.875rem;
        color: rgb(255 255 255 / 0.85);
    }
</style>
