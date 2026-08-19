<script lang="ts">
    import { onMount, untrack } from "svelte";
    import { pushState } from "$app/navigation";
    import { page } from "$app/state";
    import { BellOff, BellRing, ChevronRight, Clock, Ear, Minus, Plus, ShieldCheck } from "@lucide/svelte";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
    import { fallbackLocation } from "$lib/components/location/cities";
    import type { Coordinates } from "$lib/services/location";
    import { prayerTimesService, type PrayerDay } from "$lib/features/prayer-times/service";
    import ModeSwitchDialog from "./ModeSwitchDialog.svelte";
    import PermissionChecklist from "./PermissionChecklist.svelte";
    import TimingsEditor from "./TimingsEditor.svelte";
    import {
        engineStatus, forceRestore, forceSilent, permissionStatus,
        requestBatteryOptimization, requestDnd, requestExactAlarm, requestNotifications,
        scheduleDailyAlarms, scheduleManualWindows, setEngineMode, startEngine, stopEngine,
        type ActiveSession, type EngineMode, type ModeSwitchPolicy,
        type NativeStatus, type PermissionStatus
    } from "./engine";
    import {
        alarmsFor, formatClock, formatCountdown, formatDuration, likelyPrayerLabel,
        planWakes, planWindows, windowsFor
    } from "./service";
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

    /** The switch the user asked for, waiting on their answer to the dialog. */
    let blockedTarget = $state<EngineMode | null>(null);
    let blockingSession = $state<ActiveSession | null>(null);
    let switchDialogOpen = $state(false);

    // sveltekit: the timings editor is a sub-view of this same route rather than its own page,
    // so it goes in page.state via shallow routing -- that puts a real entry in the WebView's
    // history and makes Android's hardware back button close it, which plain $state would not.
    let editingTimings = $derived(Boolean((page.state as { editingTimings?: boolean }).editingTimings));

    /**
     * The mode is read from the plugin, never stored here.
     *
     * It is the plugin that acts on the mode while this app is closed -- alarms fire, the boot
     * receiver re-arms, a deferred switch lands when a prayer ends -- so a second copy in
     * localStorage could only ever drift out of step with the thing actually doing the work.
     */
    let mode = $derived<EngineMode>(status?.mode ?? "disabled");
    /** A switch waiting for the running session to finish. Null when nothing is queued. */
    let queuedMode = $derived<EngineMode | null>(status?.pendingMode ?? null);
    let byTime = $derived(mode === "manual");

    let wakes = $derived(today ? planWakes(today, settings) : []);
    let windows = $derived(today ? planWindows(today, settings) : []);
    let enabledCount = $derived(silencedPrayers.filter((id) => settings.prayers[id]).length);

    let prayerTimes = $derived(
        Object.fromEntries(wakes.map((wake) => [wake.prayer, wake.prayerAt]))
    ) as Partial<Record<SilencedPrayer, Date>>;

    /** Anything already past today belongs to tomorrow, since both plans repeat daily. */
    function soonest<T extends { at: Date }>(entries: T[]): T | null {
        return entries
            .map((entry) => ({
                ...entry,
                at: entry.at.getTime() > now.getTime()
                    ? entry.at
                    : new Date(entry.at.getTime() + 24 * 60 * 60_000)
            }))
            .sort((left, right) => left.at.getTime() - right.at.getTime())[0] ?? null;
    }

    let nextWake = $derived(soonest(wakes.map((wake) => ({ ...wake, at: wake.wakeAt }))));
    let nextWindow = $derived(soonest(windows.map((window) => ({ ...window, at: window.startAt }))));

    let isSilenced = $derived(status?.audioState === "silent");
    let isListening = $derived(Boolean(status?.serviceRunning));
    /** Detection only: the ten-minute grace period before the service gives up and stops. */
    let countdown = $derived(
        status?.shutdownDeadlineMillis ? status.shutdownDeadlineMillis - now.getTime() : null
    );
    /** Time mode only: the fixed moment the ringer comes back. */
    let restoreAt = $derived(
        status?.manualRestoreAtMillis ? new Date(status.manualRestoreAtMillis) : null
    );

    let phase = $derived(
        unsupported ? "unsupported"
        : isSilenced ? "silenced"
        : isListening ? "listening"
        : mode !== "disabled" && permissions?.allGranted ? "armed"
        : "off"
    );

    const headline: Record<string, string> = {
        unsupported: "Android only",
        silenced: "Phone silenced",
        listening: "Listening",
        armed: "Ready",
        off: "Off"
    };

    const modeNames: Record<EngineMode, string> = {
        disabled: "Off",
        manual: "By time",
        ml: "Detection"
    };

    const modeOptions: EngineMode[] = ["disabled", "manual", "ml"];

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
     * Pushes one mode's plan to the plugin, unconditionally.
     *
     * The write used to be skipped when `status.scheduledAlarms` already matched the plan, which
     * seemed like a harmless optimisation and was not. That list is the plugin's own persisted
     * record, not a live query of AlarmManager, and Android silently cancels every one of an
     * app's alarms when it is force-stopped. The record therefore kept claiming five alarms
     * existed while AlarmManager held none, the comparison passed, nothing was rewritten, and the
     * page cheerfully reported "Ready" for a feature that could never fire. Verified on a device.
     *
     * Re-arming is cheap, `planSignature` already stops this running on every render, and writing
     * every time makes the whole thing self-healing: opening the page repairs it.
     */
    async function pushSchedule(forMode: EngineMode) {
        if (forMode === "ml") await scheduleDailyAlarms(alarmsFor(wakes));
        else if (forMode === "manual") await scheduleManualWindows(windowsFor(windows));
    }

    async function syncSchedule() {
        if (unsupported || !today || !permissions?.allGranted) return;

        try {
            await pushSchedule(mode);
            // A queued switch arms itself from whatever the plugin has stored, which for a mode
            // the user has never used is nothing at all. Sending its plan now means the switch
            // has something to arm whenever it lands, even if the app is closed by then.
            if (queuedMode && queuedMode !== mode) await pushSchedule(queuedMode);
            await refreshStatus();
        } catch (cause) {
            handleFailure(cause, "Could not save the schedule.");
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

    /**
     * Asks the plugin to change mode, and deals with it saying no.
     *
     * The default `ifIdle` policy refuses while the engine has the phone silent, because
     * switching tears the outgoing mode down and that would turn the ringer back on -- quite
     * possibly mid-prayer. The refusal comes back carrying the session that caused it, which is
     * what the dialog needs in order to offer a real choice rather than a shrug.
     */
    async function requestMode(next: EngineMode, policy: ModeSwitchPolicy = "ifIdle") {
        busy = true;
        actionError = "";
        try {
            const outcome = await setEngineMode(next, policy);
            if (!outcome.applied && outcome.status.activeSession && policy === "ifIdle") {
                blockedTarget = next;
                blockingSession = outcome.status.activeSession;
                switchDialogOpen = true;
            }
        } catch (cause) {
            const message = messageFrom(cause, "Could not change the mode.");
            if (isUnsupported(message)) unsupported = true;
            else actionError = explain(message);
        } finally {
            busy = false;
            await refreshStatus();
            // the schedule has to go out after the mode is actually in effect, since which plan
            // gets pushed depends on it
            await syncSchedule();
        }
    }

    function chooseMode(next: EngineMode) {
        // re-picking the mode already running is how a queued switch gets cancelled, so that
        // case still has to reach the plugin rather than being short-circuited here
        if (next === mode && !queuedMode) return;
        void requestMode(next);
    }

    function resolveSwitch(policy: ModeSwitchPolicy) {
        const target = blockedTarget;
        blockedTarget = null;
        blockingSession = null;
        if (target) void requestMode(target, policy);
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

    function togglePrayer(prayer: SilencedPrayer, value: boolean) {
        settings.prayers[prayer] = value;
        persist();
        void syncSchedule();
    }

    function nudgeLead(by: number) {
        settings.leadMinutes = Math.min(
            leadMinutesRange.max, Math.max(leadMinutesRange.min, settings.leadMinutes + by)
        );
        persist();
        void syncSchedule();
    }

    function setOffset(prayer: SilencedPrayer, minutes: number) {
        settings.offsets[prayer] = minutes;
        persist();
        void syncSchedule();
    }

    function setDuration(prayer: SilencedPrayer, minutes: number) {
        settings.durations[prayer] = minutes;
        persist();
        void syncSchedule();
    }

    /**
     * The plugin defaults to detection mode so that callers written before modes existed keep
     * working. That is the wrong default to inherit here -- a feature that silences your phone
     * should not arm itself before anyone has asked it to -- so the first run turns it off.
     */
    async function bootstrap() {
        await refreshStatus();
        if (unsupported || settings.initialised) return;

        try {
            await setEngineMode("disabled", "immediate");
            settings.initialised = true;
            persist();
            await refreshStatus();
        } catch (cause) {
            handleFailure(cause, "Could not set up the engine.");
        }
    }

    onMount(() => {
        void bootstrap();

        // design: one second, because the shutdown countdown is displayed in mm:ss. This also
        // re-derives the "next at" lines, so they roll over on their own at midnight.
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
     * string means the effect below has exactly one dependency, which matters because
     * syncSchedule both reads and writes `status` -- letting it be tracked would make every
     * three-second status poll re-enter scheduling, and a plan the native side normalised even
     * slightly differently would then rewrite the whole list forever.
     *
     * Only the modes actually in play contribute: editing a duration while in detection mode
     * should not re-arm anything, and switching to time mode pushes it anyway.
     */
    let planSignature = $derived(JSON.stringify({
        mode,
        queued: queuedMode,
        granted: permissions?.allGranted ?? false,
        alarms: mode === "ml" || queuedMode === "ml" ? alarmsFor(wakes) : null,
        windows: mode === "manual" || queuedMode === "manual" ? windowsFor(windows) : null
    }));

    let lastSynced = "";

    $effect(() => {
        const signature = planSignature;
        // svelte: untrack keeps syncSchedule's own reads out of this effect's dependencies, so
        // the derived signature above stays the single trigger
        untrack(() => {
            if (signature === lastSynced) return;
            lastSynced = signature;
            void syncSchedule();
        });
    });
</script>

{#if editingTimings}
    <TimingsEditor
        {settings}
        {mode}
        times={prayerTimes}
        onOffsetChange={setOffset}
        onDurationChange={setDuration}
        onBack={() => history.back()}
    />
{:else}
    <section class="hero" data-phase={phase}>
        <span class="hero__icon" aria-hidden="true">
            {#if phase === "silenced"}<BellOff size={30} />
            {:else if phase === "listening"}<Ear size={30} />
            {:else if phase === "armed"}
                {#if byTime}<Clock size={30} />{:else}<ShieldCheck size={30} />{/if}
            {:else}<BellRing size={30} />{/if}
        </span>

        <p class="hero__state">{headline[phase]}</p>

        <p class="hero__detail">
            {#if phase === "unsupported"}
                The engine runs as an Android foreground service, so it does nothing on desktop.
            {:else if phase === "silenced"}
                {#if byTime && restoreAt}
                    Your phone is silent until {formatClock(restoreAt)}.
                {:else}
                    Your phone is silenced. It goes back to normal on its own once you finish.
                {/if}
            {:else if phase === "listening"}
                Watching for prayer movement. Nothing is silenced yet.
            {:else if phase === "armed"}
                {#if byTime}
                    {#if nextWindow}
                        Silent for {nextWindow.label} from {formatClock(nextWindow.at)},
                        for {formatDuration(nextWindow.durationMinutes)}.
                    {:else}
                        No prayers selected, so nothing is scheduled.
                    {/if}
                {:else if nextWake}
                    Next listening for {nextWake.label} at {formatClock(nextWake.at)}.
                {:else}
                    No prayers selected, so nothing is scheduled.
                {/if}
            {:else if !permissions?.allGranted}
                Needs a few Android permissions before it can run.
            {:else}
                Pick how you want your phone silenced during salah.
            {/if}
        </p>

        {#if isSilenced && !byTime && countdown !== null && countdown > 0}
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
            <h2 class="text-sm font-semibold">How to silence</h2>
            <!-- design: three buttons rather than a toggle with a sub-choice. The two working
                 modes are genuinely different bargains, not a setting on one feature, and putting
                 them side by side is the only way that comparison is visible at all. -->
            <div class="mt-3 grid grid-cols-3 gap-2" role="group" aria-label="Silencing mode">
                {#each modeOptions as option}
                    <button
                        class="mode-chip"
                        data-on={mode === option}
                        data-queued={queuedMode === option}
                        disabled={busy || (option !== "disabled" && !permissions?.allGranted)}
                        onclick={() => chooseMode(option)}
                        aria-pressed={mode === option}
                    >{modeNames[option]}</button>
                {/each}
            </div>

            <p class="mt-3 text-xs leading-snug text-zinc-400">
                {#if !permissions?.allGranted}
                    Grant the permissions below first.
                {:else if mode === "manual"}
                    Silences your phone for a set stretch around each prayer time. Nothing is
                    watching, so it can't misfire — but it silences whether or not you're praying.
                {:else if mode === "ml"}
                    Wakes shortly before each prayer, watches for prayer movement, and silences
                    the phone only once it's fairly sure you've started.
                {:else}
                    Nothing is scheduled. Your settings are kept for when you turn it back on.
                {/if}
            </p>

            <!-- design: a queued switch is invisible otherwise, and the tap that queued it would
                 look like it simply hadn't registered. -->
            {#if queuedMode}
                <p class="action-result action-result--good">
                    Switching to {modeNames[queuedMode]} once this prayer finishes. Tap
                    {modeNames[mode]} to cancel.
                </p>
            {/if}
        </section>

        {#if !permissions?.allGranted}
            <section class="mb-4">
                <h2 class="mb-2 text-sm font-semibold">Permissions</h2>
                <PermissionChecklist status={permissions} {busy} onRequest={requestPermission} />
            </section>
        {/if}

        {#if mode !== "disabled"}
            <section class="surface mb-4 p-4">
                <h2 class="text-sm font-semibold">Prayers to {byTime ? "cover" : "watch"}</h2>
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
                <!-- design: lead time is detection-only. A clock-driven window has nothing to
                     warm up, so offering it in time mode would be a control that does nothing. -->
                {#if !byTime}
                    <div class="flex items-center gap-3 p-4">
                        <div class="min-w-0 flex-1">
                            <p class="text-sm font-semibold">Start listening early</p>
                            <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                                The engine detects movement rather than predicting it, so it has to
                                already be running when you begin.
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
                {/if}

                <button class="flex w-full items-center gap-3 p-4 text-left" onclick={() => pushState("", { editingTimings: true })}>
                    <div class="min-w-0 flex-1">
                        <p class="text-sm font-semibold">Adjust timings</p>
                        <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                            {#if byTime}
                                Shift each prayer to when you actually start, and set how long to
                                stay silent.
                            {:else}
                                Shift individual prayers if you usually pray later than the
                                calculated time.
                            {/if}
                        </p>
                    </div>
                    <ChevronRight size={18} class="shrink-0 text-zinc-500" />
                </button>
            </section>
        {/if}

        <!-- design: without this there is no way to know the permission chain works short of
             waiting for a real prayer and hoping. Forcing the ringer proves DND access and
             ringer control in a couple of seconds, which is the part that actually breaks. -->
        <section class="surface mb-4 p-4">
            <h2 class="text-sm font-semibold">Check it works</h2>
            <p class="mt-0.5 text-xs leading-snug text-zinc-400">
                Silences your phone right now, skipping the schedule entirely, so you can confirm
                the permissions are really in place. Restoring puts your ringer back.
            </p>
            <div class="mt-3 flex gap-2">
                <button class="button button--secondary flex-1" onclick={() => run(forceSilent, "Could not silence the phone.")} disabled={busy}>
                    Silence now
                </button>
                <button class="button button--secondary flex-1" onclick={() => run(forceRestore, "Could not restore the ringer.")} disabled={busy}>
                    Restore
                </button>
            </div>
            <!-- the plugin rejects start_native_task outside detection mode, so the button only
                 exists where it can actually do something -->
            {#if mode === "ml" && !isListening}
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
            {#if byTime}
                Your phone goes silent on the clock, whether or not you are praying, and comes back
                when the time is up. Nothing adapts — if you pray late, or take longer than the
                window, it will not notice.
            {:else}
                Detection is not perfect. It can miss a prayer, or silence your phone when you were
                only sitting still — so do not rely on it for anything you cannot afford to miss a
                call about.
            {/if}
            Your ringer is always restored automatically afterwards.
        </p>
    {/if}
{/if}

{#if blockingSession && blockedTarget}
    <ModeSwitchDialog
        session={blockingSession}
        target={blockedTarget}
        bind:open={switchDialogOpen}
        onChoose={resolveSwitch}
    />
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

    .mode-chip,
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

    .mode-chip[data-on="true"],
    .prayer-chip[data-on="true"] {
        color: var(--app-text);
        border-color: color-mix(in srgb, var(--app-accent-strong) 55%, transparent);
        background: color-mix(in srgb, var(--app-accent-strong) 14%, transparent);
    }

    /* design: a dashed outline for a queued mode -- clearly chosen, clearly not yet in effect.
       A solid fill would claim the switch had already happened. */
    .mode-chip[data-queued="true"] {
        color: var(--app-text);
        border-style: dashed;
        border-color: color-mix(in srgb, var(--app-accent-strong) 55%, transparent);
    }

    .mode-chip:disabled { opacity: 0.4; cursor: default; }

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
