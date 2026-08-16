<script lang="ts">
    import { onMount } from "svelte";
    import { sehriIftariService, type FastingDay } from "./service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";

    const methods = [{ value: "1", label: "Karachi" }, { value: "3", label: "MWL" }, { value: "4", label: "Umm Al-Qura" }];
    let city = $state("Karachi");
    let country = $state("Pakistan");
    let method = $state("1");
    let visibleMonth = $state(new Date(new Date().getFullYear(), new Date().getMonth()));
    let days: FastingDay[] = $state([]);
    let isLoading = $state(true);
    let error = $state("");
    let now = $state(new Date());

    let today = $derived(days.find(day => sameDate(day.date, now)) ?? null);
    let nextEvent = $derived(today ? calculateNextEvent(today, now) : null);
    let monthName = $derived(visibleMonth.toLocaleDateString("en", { month: "long", year: "numeric" }));

    onMount(() => {
        loadMonth();
        const interval = window.setInterval(() => now = new Date(), 30_000);
        return () => window.clearInterval(interval);
    });

    async function loadMonth() {
        isLoading = true;
        error = "";

        try {
            days = await sehriIftariService.month(city, country, method, visibleMonth, (cachedDays) => {
                days = cachedDays;
                isLoading = false;
            });
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load Sehri and Iftari times.";
        } finally {
            isLoading = false;
        }
    }

    function changeMonth(delta: number) { visibleMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() + delta); loadMonth(); }
    function sameDate(left: Date, right: Date) { return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate(); }
    function timeDate(time: string, date: Date) { const [hours, minutes] = time.split(":").map(Number); return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes); }
    function formatTime(time: string) { const target = timeDate(time, new Date()); return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(target); }
    function remaining(milliseconds: number) { const minutes = Math.max(0, Math.floor(milliseconds / 60_000)); return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`; }
    function calculateNextEvent(day: FastingDay, current: Date) {
        const sehri = timeDate(day.imsak, current); const iftar = timeDate(day.maghrib, current);
        if (current < sehri) return { label: "Sehri ends", time: day.imsak, remaining: remaining(sehri.getTime() - current.getTime()) };
        if (current < iftar) return { label: "Iftar", time: day.maghrib, remaining: remaining(iftar.getTime() - current.getTime()) };
        return { label: "Next Sehri", time: day.imsak, remaining: "Tomorrow" };
    }
</script>

<svelte:head><title>Sehri & Iftari · DeenLab</title></svelte:head>

<div class="space-y-6">
    <header>
        <h1 class="text-2xl font-bold">Sehri & Iftari</h1>
        <p class="mt-1 text-zinc-400">Daily fasting times and a full monthly calendar.</p>
    </header>

    <form class="grid gap-3 sm:grid-cols-4" onsubmit={(event) => { event.preventDefault(); loadMonth(); }}>
        <input class="control" placeholder="City" bind:value={city} required />
        <input class="control" placeholder="Country" bind:value={country} required />
        <select class="control" bind:value={method}>{#each methods as option}<option value={option.value}>{option.label}</option>{/each}</select>
        <button class="button" type="submit" disabled={isLoading}>Update timings</button>
    </form>

    {#if error}
        <ErrorBanner message={error} onRetry={loadMonth} />
    {/if}

    {#if isLoading && days.length === 0}
        <p class="text-zinc-400" aria-live="polite">Loading calendar…</p>
    {:else}
        {#if today && nextEvent}
            <section class="rounded-xl bg-emerald-400 p-6 text-emerald-950">
                <p class="font-medium">{nextEvent.label}</p>
                <p class="mt-1 text-2xl font-bold">{formatTime(nextEvent.time)}</p>
                <p class="mt-2">{nextEvent.remaining === "Tomorrow" ? "Tomorrow" : `In ${nextEvent.remaining}`}</p>
            </section>

            <section class="grid gap-3 sm:grid-cols-3">
                <article class="surface p-5"><span class="text-sm text-zinc-400">Sehri ends</span><span class="mt-2 block text-xl text-emerald-300">{formatTime(today.imsak)}</span></article>
                <article class="surface p-5"><span class="text-sm text-zinc-400">Fajr</span><span class="mt-2 block text-xl text-emerald-300">{formatTime(today.fajr)}</span></article>
                <article class="surface p-5"><span class="text-sm text-zinc-400">Iftar</span><span class="mt-2 block text-xl text-emerald-300">{formatTime(today.maghrib)}</span></article>
            </section>
        {/if}

        <div class="flex items-center justify-between">
            <button class="button button--secondary" onclick={() => changeMonth(-1)}>←</button>
            <h2 class="text-xl font-bold">{monthName}</h2>
            <button class="button button--secondary" onclick={() => changeMonth(1)}>→</button>
        </div>

        <div class="space-y-3">
            {#each days as day (day.date.toISOString())}
                <article class={`surface grid grid-cols-[4rem_1fr] gap-4 p-4 ${sameDate(day.date, now) ? "border-emerald-400" : ""}`}>
                    <div class="text-center">
                        <span class="block text-xl font-bold">{day.date.getDate()}</span>
                        <span class="text-sm text-zinc-400">{day.weekday.slice(0, 3)}</span>
                    </div>
                    <div>
                        <span class="text-sm text-zinc-400">{day.hijri}</span>
                        <div class="mt-2 grid grid-cols-3 gap-2 text-sm">
                            <span>Sehri <b class="block text-emerald-300">{formatTime(day.imsak)}</b></span>
                            <span>Fajr <b class="block text-emerald-300">{formatTime(day.fajr)}</b></span>
                            <span>Iftar <b class="block text-emerald-300">{formatTime(day.maghrib)}</b></span>
                        </div>
                    </div>
                </article>
            {/each}
        </div>
    {/if}
</div>
