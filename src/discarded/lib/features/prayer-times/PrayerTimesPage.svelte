<script lang="ts">
    import { onMount } from "svelte";
    import { prayerTimeService, type PrayerMethod, type PrayerTimes } from "./service";

    const cities = ["Peshawar", "Lahore", "Karachi", "Islamabad"];
    const methods: Array<{ value: PrayerMethod; label: string }> = [
        { value: "1", label: "Karachi" },
        { value: "3", label: "MWL" },
        { value: "4", label: "Umm Al-Qura" }
    ];
    const prayerLabels: Array<[keyof PrayerTimes, string]> = [
        ["fajr", "Fajr"], ["sunrise", "Sunrise"], ["dhuhr", "Dhuhr"],
        ["asr", "Asr"], ["maghrib", "Maghrib"], ["isha", "Isha"]
    ];

    let city = "Peshawar";
    let method: PrayerMethod = "1";
    let times: PrayerTimes | null = null;
    let error = "";
    let isLoading = true;
    let now = new Date();

    $: nextPrayer = times ? findNextPrayer(times, now) : null;

    onMount(() => {
        loadTimes();
        const interval = window.setInterval(() => now = new Date(), 30_000);
        return () => window.clearInterval(interval);
    });

    async function loadTimes() {
        isLoading = true;
        error = "";

        try {
            times = await prayerTimeService.load(city, "Pakistan", method);
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load prayer times.";
        } finally {
            isLoading = false;
        }
    }

    function formatTime(rawTime: string) {
        const [hours, minutes] = rawTime.split(":").map(Number);

        if (Number.isNaN(hours) || Number.isNaN(minutes))
            return rawTime;

        return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" })
            .format(new Date(2000, 0, 1, hours, minutes));
    }

    function findNextPrayer(prayerTimes: PrayerTimes, currentTime: Date) {
        const prayers: Array<[string, string]> = [
            ["Fajr", prayerTimes.fajr], ["Dhuhr", prayerTimes.dhuhr], ["Asr", prayerTimes.asr],
            ["Maghrib", prayerTimes.maghrib], ["Isha", prayerTimes.isha]
        ];

        for (const [name, time] of prayers) {
            const target = dateForTime(time, currentTime);
            if (target > currentTime)
                return { name, time, remaining: formatRemaining(target.getTime() - currentTime.getTime()) };
        }

        const tomorrowFajr = dateForTime(prayerTimes.fajr, currentTime);
        tomorrowFajr.setDate(tomorrowFajr.getDate() + 1);
        return { name: "Fajr", time: prayerTimes.fajr, remaining: formatRemaining(tomorrowFajr.getTime() - currentTime.getTime()) };
    }

    function dateForTime(rawTime: string, date: Date) {
        const [hours, minutes] = rawTime.split(":").map(Number);
        return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes);
    }

    function formatRemaining(milliseconds: number) {
        const totalMinutes = Math.max(0, Math.floor(milliseconds / 60_000));
        return `${String(Math.floor(totalMinutes / 60)).padStart(2, "0")}:${String(totalMinutes % 60).padStart(2, "0")}`;
    }
</script>

<svelte:head><title>Prayer Times · DeenLab</title></svelte:head>

<div class="app-shell">
    <main class="page-container">
        <header class="app-header">
            <a class="text-sm text-emerald-400 hover:text-emerald-300" href="/">← Home</a>
            <h1 class="mt-4 text-3xl font-bold">Prayer Times</h1>
            <p class="mt-2 text-zinc-400">Daily salah timings for your selected city.</p>
        </header>

        <div class="mb-6 flex flex-wrap gap-3">
            <label class="sr-only" for="city">City</label>
            <select id="city" class="control" bind:value={city} onchange={loadTimes}>
                {#each cities as option}<option value={option}>{option}, Pakistan</option>{/each}
            </select>
            <label class="sr-only" for="method">Calculation method</label>
            <select id="method" class="control" bind:value={method} onchange={loadTimes}>
                {#each methods as option}<option value={option.value}>{option.label}</option>{/each}
            </select>
            <button class="button button--secondary" onclick={loadTimes} disabled={isLoading}>Refresh</button>
        </div>

        {#if isLoading}
            <p class="text-zinc-400" aria-live="polite">Loading prayer times…</p>
        {:else if error}
            <div class="surface p-5" role="alert">
                <p>{error}</p>
                <button class="button mt-4" onclick={loadTimes}>Try again</button>
            </div>
        {:else if times && nextPrayer}
            <section class="mb-6 rounded-xl bg-emerald-400 p-6 text-emerald-950">
                <p class="font-medium">Next prayer</p>
                <p class="mt-1 text-2xl font-bold">{nextPrayer.name} · {formatTime(nextPrayer.time)}</p>
                <p class="mt-2">In {nextPrayer.remaining}</p>
            </section>

            <section class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" aria-label="Prayer times">
                {#each prayerLabels as [key, label]}
                    <article class="surface flex items-center justify-between p-5">
                        <span class="font-semibold">{label}</span>
                        <span class="text-lg text-emerald-300">{formatTime(times[key])}</span>
                    </article>
                {/each}
            </section>
        {/if}
    </main>
</div>
