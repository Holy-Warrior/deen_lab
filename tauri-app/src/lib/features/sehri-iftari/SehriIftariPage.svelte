<script lang="ts">
    import { onMount } from "svelte";
    import { Tabs } from "bits-ui";
    import { sehriIftariService, type FastingDay } from "./service";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
    import LocationStatusRow from "$lib/components/location/LocationStatusRow.svelte";
    import { fallbackLocation } from "$lib/components/location/cities";
    import type { Coordinates } from "$lib/services/location";

    const methods = [{ value: "1", label: "Karachi" }, { value: "3", label: "MWL" }, { value: "4", label: "Umm Al-Qura" }];
    const weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    let method = $state("1");
    let view: "list" | "grid" = $state("grid");
    let visibleMonth = $state(new Date(new Date().getFullYear(), new Date().getMonth()));
    let days: FastingDay[] = $state([]);
    let isLoading = $state(true);
    let error = $state("");
    let now = $state(new Date());
    let selectedDate: Date | null = $state(null);

    // svelte: mirrors DeviceLocation's resolved coordinates into real top-level state -- a
    // snippet body can't declare its own $effect, so this is what the $effect below reacts to
    let activeCoordinates: Coordinates | null = $state(null);

    let today = $derived(days.find(day => sameDate(day.date, now)) ?? null);
    let nextEvent = $derived(today ? calculateNextEvent(today, now) : null);
    let monthName = $derived(visibleMonth.toLocaleDateString("en", { month: "long", year: "numeric" }));
    // design: defaults to today (if it's in the visible month) until the user taps a grid
    // cell -- the detail panel is never empty for no reason when today is right there
    let selectedDay = $derived(selectedDate ? days.find(day => sameDate(day.date, selectedDate!)) ?? null : today);
    let weeks = $derived(buildCalendarWeeks(visibleMonth, days));

    onMount(() => {
        // design: every second, not every 30 -- the countdown shows seconds now, so it needs
        // to actually tick every second to look "live" instead of jumping every half-minute
        const interval = window.setInterval(() => now = new Date(), 1_000);
        return () => window.clearInterval(interval);
    });

    // svelte: re-fetches whenever coordinates, method, or visibleMonth change -- $effect
    // tracks all three automatically, so changing the calculation method or navigating months
    // triggers a fresh load with no submit button, same as DeviceLocation resyncing position
    $effect(() => {
        if (activeCoordinates) loadMonth(activeCoordinates);
    });

    async function loadMonth(coordinates: Coordinates) {
        isLoading = true;
        error = "";

        try {
            days = await sehriIftariService.month(coordinates, method, visibleMonth, (cachedDays) => {
                days = cachedDays;
                isLoading = false;
            });
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Unable to load Sehri and Iftari times.";
        } finally {
            isLoading = false;
        }
    }

    function changeMonth(delta: number) {
        visibleMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() + delta);
        selectedDate = null;
    }

    function sameDate(left: Date, right: Date) { return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate(); }
    function timeDate(time: string, date: Date) { const [hours, minutes] = time.split(":").map(Number); return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes); }
    function formatTime(time: string) { const target = timeDate(time, new Date()); return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(target); }
    // design: HH:MM:SS instead of HH:MM -- a moving seconds digit is what makes a countdown
    // read as live/ticking rather than a static estimate that happens to update sometimes
    function remaining(milliseconds: number) {
        const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    }

    // design: `type` drives which of today's three time slots gets highlighted (see the
    // .today-slot markup below) -- kept separate from `label` so that display wording can
    // change without silently breaking the highlight logic that used to match against it
    function calculateNextEvent(day: FastingDay, current: Date) {
        const sehri = timeDate(day.imsak, current); const iftar = timeDate(day.maghrib, current);
        if (current < sehri) return { type: "sehri" as const, label: "Sehri ends", time: day.imsak, remaining: remaining(sehri.getTime() - current.getTime()) };
        if (current < iftar) return { type: "iftar" as const, label: "Iftar", time: day.maghrib, remaining: remaining(iftar.getTime() - current.getTime()) };
        return { type: "nextSehri" as const, label: "Next Sehri", time: day.imsak, remaining: "Tomorrow" };
    }

    // design: pads the month's days into a 7-wide grid (leading/trailing blanks so dates
    // line up under the correct weekday column) -- the standard month-calendar layout
    function buildCalendarWeeks(month: Date, monthDays: FastingDay[]): (FastingDay | null)[][] {
        const byDayOfMonth = new Map(monthDays.map(day => [day.date.getDate(), day]));
        const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        const firstWeekday = new Date(month.getFullYear(), month.getMonth(), 1).getDay();

        const cells: (FastingDay | null)[] = Array(firstWeekday).fill(null);
        for (let dayOfMonth = 1; dayOfMonth <= daysInMonth; dayOfMonth++) {
            cells.push(byDayOfMonth.get(dayOfMonth) ?? null);
        }
        while (cells.length % 7 !== 0) cells.push(null);

        const weeks: (FastingDay | null)[][] = [];
        for (let index = 0; index < cells.length; index += 7) weeks.push(cells.slice(index, index + 7));
        return weeks;
    }

    // design: hijri is "18-02-1448 Şafar"-style from service.ts (Aladhan's hijri.date is a full
    // DD-MM-YYYY string, not a bare day number) -- the grid cell only has room for the day, so
    // pull just that out instead of storing it separately in FastingDay
    function hijriDayNumber(hijri: string) { return hijri.split("-")[0]; }
</script>

<svelte:head><title>Sehri & Iftari · DeenLab</title></svelte:head>

<div class="feature-page space-y-6">
    <header>
        <h1 class="text-2xl font-bold">Sehri & Iftari</h1>
        <p class="mt-1 text-zinc-400">Daily fasting times and a full monthly calendar.</p>
    </header>

    <!-- svelte: same DeviceLocation + LocationStatusRow pairing as Qibla -- onCoordinatesChange
         mirrors DeviceLocation's own coordinates into activeCoordinates (from its script, not
         from this rendered snippet, since Svelte forbids mutating state during render) so the
         $effect above can react to them changing -->
    <DeviceLocation fallback={fallbackLocation} onCoordinatesChange={(coordinates) => activeCoordinates = coordinates}>
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

    {#if error}
        <ErrorBanner message={error} onRetry={() => activeCoordinates && loadMonth(activeCoordinates)} />
    {/if}

    {#if isLoading && days.length === 0}
        <p class="text-zinc-400" aria-live="polite">Loading calendar…</p>
    {:else}
        <!-- design: replaces what used to be 4 separate cards (a big "next event" banner +
             3 plain stat cards) with one card built the same way as the grid view's day-detail
             card below -- the slot that's actually relevant right now (in session: you can act
             on it, e.g. still eating Sehri; or coming: the next thing to wait for) is the one
             that stands out, instead of every number competing equally for attention -->
        {#if today}
            <article class="surface p-5">
                <p class="text-sm text-zinc-400">Today · {today.weekday} · {today.hijri}</p>
                <div class="mt-3 grid grid-cols-3 gap-2">
                    <div class="today-slot" class:today-slot--session={nextEvent?.type === "sehri"}>
                        <span class="today-slot__label">Sehri ends</span>
                        <span class="today-slot__time">{formatTime(today.imsak)}</span>
                        {#if nextEvent?.type === "sehri"}<span class="today-slot__countdown">{nextEvent.remaining}</span>{/if}
                    </div>
                    <div class="today-slot">
                        <span class="today-slot__label">Fajr</span>
                        <span class="today-slot__time">{formatTime(today.fajr)}</span>
                    </div>
                    <div class="today-slot" class:today-slot--upcoming={nextEvent?.type === "iftar"}>
                        <span class="today-slot__label">Iftar</span>
                        <span class="today-slot__time">{formatTime(today.maghrib)}</span>
                        {#if nextEvent?.type === "iftar"}<span class="today-slot__countdown">{nextEvent.remaining}</span>{/if}
                    </div>
                </div>
            </article>
        {/if}

        <div class="flex items-center justify-between">
            <button class="button button--secondary" onclick={() => changeMonth(-1)}>←</button>
            <h2 class="text-xl font-bold">{monthName}</h2>
            <button class="button button--secondary" onclick={() => changeMonth(1)}>→</button>
        </div>

        <!-- bits-ui: Tabs.Root just tracks which value is active -- List/Content pair up by
             matching `value`, and Content gets the tabpanel/tab ARIA wiring for free -->
        <Tabs.Root bind:value={view}>
            <Tabs.List class="view-tabs">
                <Tabs.Trigger value="grid" class="view-tabs__trigger">Grid</Tabs.Trigger>
                <Tabs.Trigger value="list" class="view-tabs__trigger">List</Tabs.Trigger>
            </Tabs.List>

            <!-- design: a traditional 7-column month grid -- each cell only fits a day number
                 plus a tiny Hijri number (no room for 3 prayer times at mobile width), so
                 tapping a cell shows that day's full times in the detail card below instead
                 of cramming them into the cell or opening a popup -->
            <Tabs.Content value="grid" class="mt-4 space-y-4">
                <div class="grid grid-cols-7 gap-1.5 text-center">
                    {#each weekdayLabels as label}
                        <span class="py-1 text-xs font-semibold text-zinc-500">{label}</span>
                    {/each}
                    {#each weeks as week, weekIndex (weekIndex)}
                        {#each week as day, dayIndex (day ? day.date.toISOString() : `blank-${weekIndex}-${dayIndex}`)}
                            {#if day}
                                {@const isSelected = selectedDay !== null && sameDate(day.date, selectedDay.date)}
                                <button
                                    class="calendar-cell"
                                    class:calendar-cell--selected={isSelected}
                                    class:calendar-cell--today={!isSelected && sameDate(day.date, now)}
                                    onclick={() => selectedDate = day.date}
                                >
                                    <span class="block text-sm font-bold">{day.date.getDate()}</span>
                                    <span class="block text-[0.625rem] text-zinc-500">{hijriDayNumber(day.hijri)}</span>
                                </button>
                            {:else}
                                <span></span>
                            {/if}
                        {/each}
                    {/each}
                </div>

                <p class="text-sm text-zinc-400">Tap a day to see details below.</p>

                {#if selectedDay}
                    <article class="surface p-5">
                        <p class="text-sm text-zinc-400">{selectedDay.weekday} · {selectedDay.hijri}</p>
                        <div class="mt-3 grid grid-cols-3 gap-2 text-sm">
                            <span>Sehri <b class="block text-emerald-300">{formatTime(selectedDay.imsak)}</b></span>
                            <span>Fajr <b class="block text-emerald-300">{formatTime(selectedDay.fajr)}</b></span>
                            <span>Iftar <b class="block text-emerald-300">{formatTime(selectedDay.maghrib)}</b></span>
                        </div>
                    </article>
                {/if}
            </Tabs.Content>

            <Tabs.Content value="list" class="mt-4">
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
            </Tabs.Content>
        </Tabs.Root>
    {/if}
</div>

<style>
    /* design: border is always 2px (just transparent/neutral by default) so a slot's box size
       never shifts when it becomes highlighted -- only the color changes */
    .today-slot {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 0.125rem;
        padding: 0.75rem 0.5rem;
        border: 2px solid var(--app-border);
        border-radius: 0.75rem;
        background: var(--app-canvas);
        text-align: center;
    }
    .today-slot__label { font-size: 0.75rem; color: var(--app-muted); }
    .today-slot__time { font-size: 1.125rem; font-weight: 700; }
    .today-slot__countdown { margin-top: 0.125rem; font-variant-numeric: tabular-nums; font-size: 0.75rem; font-weight: 700; }

    /* design: currently happening (e.g. still within the Sehri eating window) -- filled solid,
       like a pressed/active button, since it's something the user can act on right now */
    .today-slot--session {
        border-color: var(--app-accent-strong);
        background: var(--app-accent-strong);
    }
    .today-slot--session .today-slot__label,
    .today-slot--session .today-slot__time,
    .today-slot--session .today-slot__countdown { color: #022c22; }

    /* design: next up but not here yet (e.g. Iftar while still fasting) -- outlined only,
       like a pending/secondary state, distinct from the filled "acting now" look above */
    .today-slot--upcoming { border-color: var(--app-accent-strong); }
    .today-slot--upcoming .today-slot__time,
    .today-slot--upcoming .today-slot__countdown { color: var(--app-accent-strong); }

    .calendar-cell {
        aspect-ratio: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        border: 1px solid var(--app-border);
        border-radius: 0.625rem;
        background: var(--app-surface);
        cursor: pointer;
    }
    .calendar-cell:hover { background: var(--app-surface-hover); }
    .calendar-cell--today { border-color: var(--app-accent); }
    .calendar-cell--selected { border-color: var(--app-accent-strong); background: color-mix(in srgb, var(--app-accent-strong) 18%, var(--app-surface)); }
</style>
