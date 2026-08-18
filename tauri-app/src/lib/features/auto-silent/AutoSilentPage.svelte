<script lang="ts">
    import { onMount, untrack } from "svelte";
    import { pushState } from "$app/navigation";
    import { page } from "$app/state";
    import { BellOff, BellRing, ChevronRight, Ear, Minus, Plus, ShieldCheck } from "@lucide/svelte";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
    import { fallbackLocation } from "$lib/components/location/cities";
    import type { Coordinates } from "$lib/services/location";
    import { prayerTimesService, type PrayerDay } from "$lib/features/prayer-times/service";
    import OffsetsEditor from "./OffsetsEditor.svelte";
    import PermissionChecklist from "./PermissionChecklist.svelte";
    import {
        cancelAllAlarms, engineStatus, forceRestore, forceSilent, permissionStatus,
        requestBatteryOptimization, requestDnd, requestExactAlarm, requestNotifications,
        scheduleDailyAlarms, startEngine, stopEngine,
        type NativeStatus, type PermissionStatus
    } from "./engine";
    import { alarmsFor, formatClock, formatCountdown, likelyPrayerLabel, planWakes } from "./service";
    import {
        leadMinutesRange, loadSettings, saveSettings, silencedPrayers,
        type AutoSilentSettings, type SilencedPrayer
    } from "./storage";

    // design: Prayer Times does not persist its calculation method, so it falls back to Karachi
    // on every load. Matching that here keeps the two features agreeing about when Asr is,
    // which matters more than making this separately configurable.
    const method = "1";
    const labels: Record<SilencedPrayer, string> = {
        fajr: "Fajr", dhuhr: "Dhuhr", asr: "Asr", maghrib: "Maghrib", isha: "Isha"
    };

    let settings = $state<AutoSilentSettings>(loadSettings());
    let status = $state<NativeStatus | null>(null);
    let permissions = $state<PermissionStatus | null>(null);
    let today = $state<PrayerDay | null>(null);
    let activeCoordinates = $state<Coordinates | null>(null);

    /**
     * Two separate errors on purpose. `error` belongs to the background polling and is cleared
     * whenever a poll succeeds; `actionError` belongs to a button the user just pressed and must
     * survive that. Sharing one string meant the three-second poll wiped every action's error
     * before it could be read.
     */
    let error = $state("");
    let actionError = $state("");
    /** Set once the plugin reports it isn't on Android, so the page stops pretending otherwise. */
    let unsupported = $state(false);
    let busy = $state(false);
    let now = $state(new Date());

    // sveltekit: the offsets editor is a sub-view of this same route rather than its own page,
    // so it goes in page.state via shallow routing -- that puts a real entry in the WebView's
    // history and makes Android's hardware back button close it, which plain $state would not.
    let editingOffsets = $derived(Boolean((page.state as { editingOffsets?: boolean }).editingOffsets));

    let wakes = $derived(today ? planWakes(today, settings) : []);
    let enabledCount = $derived(silencedPrayers.filter((id) => settings.prayers[id]).length);

    let prayerTimes = $derived(
        Object.fromEntries(wakes.map((wake) => [wake.prayer, wake.prayerAt]))
    ) as Partial<Record<SilencedPrayer, Date>>;

    let nextWake = $derived(
        wakes
            .map((wake) => {
                // wakes are today's clock times; anything already past belongs to tomorrow
                const at = wake.wakeAt.getTime() > now.getTime()
                    ? wake.wakeAt
                    : new Date(wake.wakeAt.getTime() + 24 * 60 * 60_000);
                return { ...wake, at };
            })
            .sort((left, right) => left.at.getTime() - right.at.getTime())[0] ?? null
    );

    let isSilenced = $derived(status?.audioState === "silent");
    let isListening = $derived(Boolean(status?.serviceRunning));
    let countdown = $derived(
        status?.shutdownDeadlineMillis ? status.shutdownDeadlineMillis - now.getTime() : null
    );

    let phase = $derived(
        unsupported ? "unsupported"
        : isSilenced ? "silenced"
        : isListening ? "listening"
        : settings.enabled && permissions?.allGranted ? "armed"
        : "off"
    );

    const headline: Record<string, string> = {
        unsupported: "Android only",
        silenced: "Phone silenced",
        listening: "Listening",
        armed: "Ready",
        off: "Off"
    };

    function persist() {
        saveSettings(settings);
    }

    // tauri: a rejected invoke() arrives as a plain string from Rust, or an Error via the JS
    // bridge, so both shapes have to be unwrapped before the message can be read
    function messageFrom(cause: unknown, fallback: string): string {
        return typeof cause === "string"
            ? cause
            : cause instanceof Error ? cause.message : fallback;
    }

    // every plugin command rejects off Android; treating that as a scary error on desktop would
    // be misleading, so it flips the page into an honest "Android only" state instead
    function isUnsupported(message: string) {
        return /unsupported|not implemented|platform/i.test(message);
    }

    /**
     * Android's own wording for the most common failure here is "Not allowed to change Do Not
     * Disturb state", which tells you nothing about what to do about it. Everything else is
     * passed through unchanged rather than guessed at.
     */
    function explain(message: string): string {
        if (/do not disturb/i.test(message)) {
            return "Android blocked the ringer change: Do Not Disturb access hasn't been granted yet. Allow it in Permissions above, then try again.";
        }
        return message;
    }

    function handleFailure(cause: unknown, fallback: string) {
        const message = messageFrom(cause, fallback);
        if (isUnsupported(message)) {
            unsupported = true;
            return;
        }
        error = message;
    }

    async function refreshStatus() {
        if (unsupported) return;
        try {
            const snapshot = await engineStatus();
            status = snapshot;
            permissions = snapshot.permissions;
            error = "";
        } catch (cause) {
            handleFailure(cause, "Could not read the engine's status.");
        }
    }

    async function refreshPermissions() {
        if (unsupported) return;
        try {
            permissions = await permissionStatus();
        } catch (cause) {
            handleFailure(cause, "Could not check permissions.");
        }
    }

    /**
     * Pushes the current plan to the native alarm list, unconditionally.
     *
     * It used to skip the write when `status.scheduledAlarms` already matched the plan, which
     * seemed like a harmless optimisation and was not. That list is the plugin's own persisted
     * record, not a live query of AlarmManager, and Android silently cancels every one of an
     * app's alarms when it is force-stopped. The record therefore kept claiming five alarms
     * existed while AlarmManager held none, the comparison passed, nothing was rewritten, and the
     * page cheerfully reported "Ready" for a feature that could never fire. Verified on a device.
     *
     * Re-arming five exact alarms costs nothing, and `planSignature` already stops this running
     * on every render, so writing every time is both cheaper to reason about and self-healing.
     */
    async function syncAlarms() {
        if (unsupported || !today) return;

        try {
            if (!settings.enabled || !permissions?.allGranted) {
                await cancelAllAlarms();
                return;
            }

            await scheduleDailyAlarms(alarmsFor(wakes));
            await refreshStatus();
        } catch (cause) {
            handleFailure(cause, "Could not schedule the prayer alarms.");
        }
    }

    async function loadPrayerTimes(coordinates: Coordinates) {
        try {
            today = await prayerTimesService.day(
                coordinates, method, new Date(), (cached) => (today = cached)
            );
        } catch (cause) {
            error = cause instanceof Error ? cause.message : "Could not load today's prayer times.";
        }
    }

    async function run(action: () => Promise<unknown>, fallback: string) {
        busy = true;
        actionError = "";
        try {
            await action();
        } catch (cause) {
            const message = messageFrom(cause, fallback);
            if (isUnsupported(message)) unsupported = true;
            else actionError = explain(message);
        } finally {
            busy = false;
            // deliberately does not touch actionError -- refreshStatus clears `error` on success,
            // which is exactly what used to erase the failure the user was meant to read
            await refreshStatus();
        }
    }

    const requests = {
        notifications: requestNotifications,
        exactAlarm: requestExactAlarm,
        dnd: requestDnd,
        batteryOptimization: requestBatteryOptimization
    };

    function requestPermission(which: keyof typeof requests) {
        // acting on the advice clears the advice; otherwise the "grant DND" message would still
        // be sitting there after the user has just gone and granted it
        actionError = "";
        // these open a system screen and resolve straight away, so there is nothing to await
        // for the answer -- the visibilitychange listener below re-checks once we're back
        void run(requests[which], "Could not open that settings screen.");
    }

    async function toggleEnabled(value: boolean) {
        settings.enabled = value;
        persist();
        await syncAlarms();
    }

    function togglePrayer(prayer: SilencedPrayer, value: boolean) {
        settings.prayers[prayer] = value;
        persist();
        void syncAlarms();
    }

    function nudgeLead(by: number) {
        settings.leadMinutes = Math.min(
            leadMinutesRange.max, Math.max(leadMinutesRange.min, settings.leadMinutes + by)
        );
        persist();
        void syncAlarms();
    }

    function setOffset(prayer: SilencedPrayer, minutes: number) {
        settings.offsets[prayer] = minutes;
        persist();
        void syncAlarms();
    }

    onMount(() => {
        void refreshStatus();

        // design: one second, because the shutdown countdown is displayed in mm:ss. This also
        // re-derives `nextWake`, so the "next at" line rolls over on its own at midnight.
        const tick = setInterval(() => (now = new Date()), 1000);
        // the engine reports state by polling only -- the plugin emits no events, so a slow
        // poll is the only way to notice it silencing the phone while this page is open
        const poll = setInterval(() => void refreshStatus(), 3000);

        // returning from a system settings screen is a visibility change, not a navigation,
        // so this is the only reliable moment to find out whether permission was granted
        const onVisible = () => { if (document.visibilityState === "visible") void refreshPermissions(); };
        document.addEventListener("visibilitychange", onVisible);

        return () => {
            clearInterval(tick);
            clearInterval(poll);
            document.removeEventListener("visibilitychange", onVisible);
        };
    });

    $effect(() => {
        if (activeCoordinates) void loadPrayerTimes(activeCoordinates);
    });

    /**
     * Everything that should cause a reschedule, and nothing that shouldn't. Deriving a single
     * string means the effect below has exactly one dependency, which matters because syncAlarms
     * both reads and writes `status` -- letting it be tracked would make every three-second
     * status poll re-enter scheduling, and a plan the native side normalised even slightly
     * differently would then rewrite five alarms forever.
     */
    let planSignature = $derived(JSON.stringify({
        enabled: settings.enabled,
        granted: permissions?.allGranted ?? false,
        alarms: alarmsFor(wakes)
    }));

    let lastSynced = "";

    $effect(() => {
        const signature = planSignature;
        // svelte: untrack keeps syncAlarms' own reads out of this effect's dependencies, so the
        // derived signature above stays the single trigger
        untrack(() => {
            if (signature === lastSynced) return;
            lastSynced = signature;
            void syncAlarms();
        });
    });
</script>

{#if editingOffsets}
    <OffsetsEditor
        {settings}
        times={prayerTimes}
        onChange={setOffset}
        onBack={() => history.back()}
    />
{:else}
    <section class="hero" data-phase={phase}>
        <span class="hero__icon" aria-hidden="true">
            {#if phase === "silenced"}<BellOff size={30} />
            {:else if phase === "listening"}<Ear size={30} />
            {:else if phase === "armed"}<ShieldCheck size={30} />
            {:else}<BellRing size={30} />{/if}
        </span>

        <p class="hero__state">{headline[phase]}</p>

        <p class="hero__detail">
            {#if phase === "unsupported"}
                The engine runs as an Android foreground service, so it does nothing on desktop.
            {:else if phase === "silenced"}
                Your phone is silenced. It goes back to normal on its own once you finish.
            {:else if phase === "listening"}
                Watching for prayer movement. Nothing is silenced yet.
            {:else if phase === "armed"}
                {#if nextWake}
                    Next listening for {nextWake.label} at {formatClock(nextWake.at)}.
                {:else}
                    No prayers selected, so nothing is scheduled.
                {/if}
            {:else if !permissions?.allGranted}
                Needs a few Android permissions before it can run.
            {:else}
                Turn it on to silence your phone automatically during salah.
            {/if}
        </p>

        {#if isSilenced && countdown !== null && countdown > 0}
            <p class="hero__countdown">
                Restoring your ringer in <strong>{formatCountdown(countdown)}</strong> unless you keep praying
            </p>
        {/if}

        {#if isListening}
            {@const active = likelyPrayerLabel(status?.scheduledAlarms ?? [], now)}
            {#if active}<p class="hero__prayer">Woke for {active}</p>{/if}
            <button class="button button--secondary mt-4 w-full" onclick={() => run(stopEngine, "Could not stop the engine.")} disabled={busy}>
                End now
            </button>
        {/if}
    </section>

    {#if error}
        <div class="mb-4"><ErrorBanner message={error} onRetry={refreshStatus} /></div>
    {/if}

    {#if !unsupported}
        <section class="surface mb-4 p-4">
            <label class="flex items-start gap-3">
                <input
                    type="checkbox"
                    class="mt-0.5 size-5 shrink-0 accent-emerald-500"
                    checked={settings.enabled}
                    disabled={!permissions?.allGranted}
                    onchange={(event) => toggleEnabled(event.currentTarget.checked)}
                />
                <span class="min-w-0">
                    <span class="block text-sm font-semibold">Silence during salah</span>
                    <span class="mt-0.5 block text-xs leading-snug text-zinc-400">
                        {#if permissions?.allGranted}
                            Wakes shortly before each prayer, watches for prayer movement, and silences
                            the phone only once it is fairly sure you have started.
                        {:else}
                            Grant the permissions below first.
                        {/if}
                    </span>
                </span>
            </label>
        </section>

        {#if !permissions?.allGranted}
            <section class="mb-4">
                <h2 class="mb-2 text-sm font-semibold">Permissions</h2>
                <PermissionChecklist status={permissions} {busy} onRequest={requestPermission} />
            </section>
        {/if}

        <section class="surface mb-4 p-4">
            <h2 class="text-sm font-semibold">Prayers to watch</h2>
            <!-- tailwind: a fixed 3-column grid rather than flex-wrap. Five chips of unequal
                 width wrap to 4 + 1, which leaves Isha stranded on its own row looking like a
                 mistake; 3 + 2 with equal widths reads as deliberate. -->
            <div class="mt-3 grid grid-cols-3 gap-2">
                {#each silencedPrayers as prayer}
                    <label class="prayer-chip" data-on={settings.prayers[prayer]}>
                        <input
                            type="checkbox"
                            class="sr-only"
                            checked={settings.prayers[prayer]}
                            onchange={(event) => togglePrayer(prayer, event.currentTarget.checked)}
                        />
                        {labels[prayer]}
                    </label>
                {/each}
            </div>
            {#if enabledCount === 0}
                <p class="mt-3 text-xs text-amber-300">Pick at least one prayer, or nothing will be scheduled.</p>
            {/if}
        </section>

        <section class="surface mb-4 divide-y divide-white/5">
            <div class="flex items-center gap-3 p-4">
                <div class="min-w-0 flex-1">
                    <p class="text-sm font-semibold">Start listening early</p>
                    <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                        The engine detects movement rather than predicting it, so it has to already
                        be running when you begin.
                    </p>
                </div>
                <div class="stepper">
                    <button onclick={() => nudgeLead(-1)} disabled={settings.leadMinutes <= leadMinutesRange.min} aria-label="One minute less">
                        <Minus size={15} />
                    </button>
                    <span class="stepper__value">{settings.leadMinutes} min</span>
                    <button onclick={() => nudgeLead(1)} disabled={settings.leadMinutes >= leadMinutesRange.max} aria-label="One minute more">
                        <Plus size={15} />
                    </button>
                </div>
            </div>

            <button class="flex w-full items-center gap-3 p-4 text-left" onclick={() => pushState("", { editingOffsets: true })}>
                <div class="min-w-0 flex-1">
                    <p class="text-sm font-semibold">Adjust timings</p>
                    <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                        Shift individual prayers if you usually pray later than the calculated time.
                    </p>
                </div>
                <ChevronRight size={18} class="shrink-0 text-zinc-500" />
            </button>
        </section>

        <!-- design: without this there is no way to know the permission chain works short of
             waiting for a real prayer and hoping. Forcing the ringer proves DND access and
             ringer control in a couple of seconds, which is the part that actually breaks. -->
        <section class="surface mb-4 p-4">
            <h2 class="text-sm font-semibold">Check it works</h2>
            <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                Silences your phone right now, skipping the detection, so you can confirm the
                permissions are really in place. Restoring puts your ringer back.
            </p>
            <div class="mt-3 flex gap-2">
                <button class="button button--secondary flex-1" onclick={() => run(forceSilent, "Could not silence the phone.")} disabled={busy}>
                    Silence now
                </button>
                <button class="button button--secondary flex-1" onclick={() => run(forceRestore, "Could not restore the ringer.")} disabled={busy}>
                    Restore
                </button>
            </div>
            {#if !isListening}
                <button class="button mt-2 w-full" onclick={() => run(() => startEngine("manual_start"), "Could not start the engine.")} disabled={busy}>
                    Start detecting now
                </button>
            {/if}

            <!-- design: the outcome belongs here, beside the button that caused it. It used to
                 rely on the banner at the top of the page, which on a phone is well over a
                 screen away -- so a failed tap looked exactly like nothing happening. -->
            {#if actionError}
                <p class="action-result action-result--bad" role="alert">{actionError}</p>
            {:else if isSilenced}
                <p class="action-result action-result--good">Your phone is silenced right now.</p>
            {/if}
        </section>

        <section class="mb-4">
            <DeviceLocation fallback={fallbackLocation} onCoordinatesChange={(coordinates) => (activeCoordinates = coordinates)}>
                {#snippet children({ locationName })}
                    <p class="text-xs text-zinc-500">
                        Prayer times for {locationName}, calculated the same way as the Prayer Times tab.
                    </p>
                {/snippet}
            </DeviceLocation>
        </section>

        <p class="text-xs leading-relaxed text-zinc-500">
            Detection is not perfect. It can miss a prayer, or silence your phone when you were
            only sitting still — so do not rely on it for anything you cannot afford to miss a
            call about. Your ringer is always restored automatically afterwards.
        </p>
    {/if}
{/if}

<style>
    .hero {
        display: flex;
        flex-direction: column;
        align-items: center;
        text-align: center;
        gap: 0.375rem;
        margin-bottom: 1rem;
        padding: 1.75rem 1.25rem;
        border: 1px solid var(--app-border);
        border-radius: 1rem;
        background: var(--app-surface);
    }

    /* design: the ring only lights up when the phone is genuinely silenced. An always-on accent
       would make "armed" and "silenced" look alike, and those are the two states a user most
       needs to tell apart at a glance. */
    .hero[data-phase="silenced"] {
        border-color: color-mix(in srgb, var(--app-accent-strong) 55%, transparent);
        background: radial-gradient(120% 90% at 50% 0%, color-mix(in srgb, var(--app-accent-strong) 16%, transparent), var(--app-surface));
    }

    .hero__icon {
        display: grid;
        place-items: center;
        width: 4.5rem;
        height: 4.5rem;
        margin-bottom: 0.375rem;
        border-radius: 9999px;
        color: var(--app-muted);
        border: 1px solid var(--app-border);
        background: var(--app-canvas);
    }

    .hero[data-phase="silenced"] .hero__icon,
    .hero[data-phase="listening"] .hero__icon {
        color: var(--app-accent-strong);
        border-color: color-mix(in srgb, var(--app-accent-strong) 45%, transparent);
    }

    .hero__state {
        font-size: 1.25rem;
        font-weight: 700;
        letter-spacing: -0.01em;
    }

    .hero__detail {
        max-width: 22rem;
        font-size: 0.8125rem;
        line-height: 1.45;
        color: var(--app-muted);
    }

    .hero__countdown {
        margin-top: 0.5rem;
        font-size: 0.75rem;
        color: var(--app-muted);
    }

    .hero__countdown strong { font-variant-numeric: tabular-nums; color: var(--app-text); }

    .hero__prayer {
        margin-top: 0.25rem;
        font-size: 0.75rem;
        font-weight: 600;
        color: var(--app-accent-strong);
    }

    .action-result {
        margin-top: 0.75rem;
        padding: 0.625rem 0.75rem;
        border-radius: 0.5rem;
        font-size: 0.75rem;
        line-height: 1.45;
    }

    .action-result--bad {
        color: #fca5a5;
        border: 1px solid color-mix(in srgb, #f87171 35%, transparent);
        background: color-mix(in srgb, #f87171 12%, transparent);
    }

    .action-result--good {
        color: var(--app-accent-strong);
        border: 1px solid color-mix(in srgb, var(--app-accent-strong) 35%, transparent);
        background: color-mix(in srgb, var(--app-accent-strong) 12%, transparent);
    }

    .prayer-chip {
        display: grid;
        place-items: center;
        padding: 0.4375rem 0.5rem;
        border: 1px solid var(--app-border);
        border-radius: 9999px;
        font-size: 0.8125rem;
        color: var(--app-muted);
        background: var(--app-canvas);
        cursor: pointer;
    }

    .prayer-chip[data-on="true"] {
        color: var(--app-text);
        border-color: color-mix(in srgb, var(--app-accent-strong) 55%, transparent);
        background: color-mix(in srgb, var(--app-accent-strong) 14%, transparent);
    }

    /* keyboard focus still has to be visible even though the real checkbox is sr-only */
    .prayer-chip:focus-within { outline: 2px solid var(--app-accent-strong); outline-offset: 2px; }

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

    .stepper__value {
        min-width: 3.5rem;
        text-align: center;
        font-size: 0.75rem;
        font-variant-numeric: tabular-nums;
        color: var(--app-muted);
    }
</style>
