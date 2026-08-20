<script lang="ts">
    // vite: import.meta.env.DEV is replaced with a literal at build time, so the whole `{#if}`
    // that wraps this component folds away and the bundler drops the file from release output.
    // Nothing in here ships.
    import { scheduleManualWindows, type NativeStatus } from "./engine";

    let { status, onDone }: {
        status: NativeStatus | null;
        /** Puts the real schedule back after a test has trampled it. */
        onDone: () => void;
    } = $props();

    let note = $state("");
    let working = $state(false);

    /**
     * Schedules one throwaway window starting in about a minute.
     *
     * The point is to exercise the parts unit tests cannot reach: a real AlarmManager entry
     * firing, the broadcast receiver changing the ringer, the notification appearing, and the end
     * alarm restoring. Waiting for a genuine prayer would mean hours, and the offset range only
     * reaches two hours either side of one.
     *
     * Deliberately does not change the mode. Doing so moves `planSignature` on the page, whose
     * sync effect then pushes the real schedule straight over the top of this window -- which is
     * exactly what happened the first time. Pick "By time" yourself first.
     */
    async function fireTestWindow(startInSeconds: number, durationMinutes: number) {
        working = true;
        note = "";
        try {
            const start = new Date(Date.now() + startInSeconds * 1000);
            // the plugin schedules on hour/minute with seconds zeroed, so round up to the next
            // whole minute or the alarm would be set for a moment that has already passed
            if (start.getSeconds() > 0) start.setMinutes(start.getMinutes() + 1, 0, 0);

            const written = await scheduleManualWindows([{
                id: 99,
                hour: start.getHours(),
                minute: start.getMinutes(),
                durationMinutes,
                label: "Test window"
            }]);

            const at = written[0]
                ? `${String(written[0].hour).padStart(2, "0")}:${String(written[0].minute).padStart(2, "0")}`
                : "?";
            note = `Silent at ${at} for ${durationMinutes} min. Real schedule is replaced until you restore it.`;
        } catch (cause) {
            note = typeof cause === "string" ? cause : cause instanceof Error ? cause.message : "failed";
        } finally {
            working = false;
        }
    }

    async function restoreRealSchedule() {
        working = true;
        note = "";
        try {
            onDone();
            note = "Real schedule pushed back.";
        } finally {
            working = false;
        }
    }

    let summary = $derived(status ? {
        mode: status.mode,
        pendingMode: status.pendingMode,
        audioState: status.audioState,
        ringer: status.currentRingerMode,
        originalRinger: status.originalRingerMode,
        activeWindow: status.activeManualWindowId,
        restoreAt: status.manualRestoreAtMillis
            ? new Date(status.manualRestoreAtMillis).toLocaleTimeString()
            : null,
        windows: status.manualWindows.map((w) => `${w.id}:${w.hour}:${String(w.minute).padStart(2, "0")}+${w.durationMinutes}`),
        alarms: status.scheduledAlarms.map((a) => `${a.id}:${a.hour}:${String(a.minute).padStart(2, "0")}`),
        session: status.activeSession
    } : null);
</script>

<section class="debug">
    <h2 class="text-sm font-semibold text-amber-300">Debug — dev builds only</h2>

    {#if status && status.mode !== "manual"}
        <p class="mt-2 text-xs text-amber-200">Switch to "By time" first — a test window only fires in that mode.</p>
    {/if}

    <div class="mt-3 flex flex-wrap gap-2">
        <button
            class="button button--secondary flex-1"
            disabled={working || status?.mode !== "manual"}
            onclick={() => fireTestWindow(45, 2)}
        >
            Window in ~1 min
        </button>
        <button class="button button--secondary flex-1" disabled={working} onclick={() => restoreRealSchedule()}>
            Restore real schedule
        </button>
    </div>

    {#if note}<p class="mt-2 text-xs text-amber-200">{note}</p>{/if}

    {#if summary}
        <pre class="debug__json">{JSON.stringify(summary, null, 1)}</pre>
    {/if}
</section>

<style>
    .debug {
        margin-bottom: 1rem;
        padding: 1rem;
        border: 1px dashed color-mix(in srgb, #fbbf24 45%, transparent);
        border-radius: 0.75rem;
        background: color-mix(in srgb, #fbbf24 7%, transparent);
    }

    .debug__json {
        margin-top: 0.75rem;
        max-height: 14rem;
        overflow: auto;
        font-size: 0.6875rem;
        line-height: 1.35;
        color: var(--app-muted);
        white-space: pre-wrap;
        word-break: break-word;
    }
</style>
