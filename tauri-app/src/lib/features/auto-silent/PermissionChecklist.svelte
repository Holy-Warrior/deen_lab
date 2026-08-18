<script lang="ts">
    import { Check, ChevronRight, TriangleAlert } from "@lucide/svelte";
    import type { PermissionStatus } from "./engine";

    let { status, busy = false, onRequest }: {
        status: PermissionStatus | null;
        busy?: boolean;
        onRequest: (which: keyof Omit<PermissionStatus, "allGranted">) => void;
    } = $props();

    // design: each line says what the permission is actually for in this feature, not what
    // Android calls it. "Do Not Disturb access" means nothing on its own; "so the app is allowed
    // to change the ringer at all" is the part that explains why refusing it breaks everything.
    const entries = [
        { key: "notifications", name: "Notifications", why: "Android requires a visible notification for any service that keeps running in the background." },
        { key: "exactAlarm", name: "Exact alarms", why: "Lets the engine wake at the prayer minute instead of whenever the system feels like it." },
        { key: "dnd", name: "Do Not Disturb access", why: "Without this Android will not let the app change your ringer, so nothing can be silenced." },
        { key: "batteryOptimization", name: "Unrestricted battery", why: "Stops Android killing the engine part-way through a prayer." }
    ] as const;
</script>

<ul class="flex flex-col gap-2">
    {#each entries as entry}
        {@const granted = status?.[entry.key] ?? false}
        <li class="permission" data-granted={granted}>
            <span class="permission__mark" aria-hidden="true">
                {#if granted}<Check size={14} />{:else}<TriangleAlert size={14} />{/if}
            </span>

            <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold">{entry.name}</p>
                <p class="mt-0.5 text-xs leading-snug text-zinc-400">{entry.why}</p>
            </div>

            {#if !granted}
                <button
                    class="permission__grant"
                    onclick={() => onRequest(entry.key)}
                    disabled={busy}
                >
                    Allow <ChevronRight size={14} />
                </button>
            {/if}
        </li>
    {/each}
</ul>

<style>
    .permission {
        display: flex;
        align-items: flex-start;
        gap: 0.625rem;
        padding: 0.75rem;
        border: 1px solid var(--app-border);
        border-radius: 0.625rem;
        background: var(--app-canvas);
    }

    /* tailwind-ish: data-granted drives the whole row's colour from one attribute, so the mark
       and the border stay in step without a second piece of state to keep aligned */
    .permission[data-granted="true"] { border-color: color-mix(in srgb, var(--app-accent-strong) 45%, transparent); }

    .permission__mark {
        display: grid;
        place-items: center;
        flex-shrink: 0;
        width: 1.375rem;
        height: 1.375rem;
        margin-top: 0.0625rem;
        border-radius: 9999px;
        color: #fbbf24;
        background: color-mix(in srgb, #fbbf24 18%, transparent);
    }

    .permission[data-granted="true"] .permission__mark {
        color: var(--app-accent-strong);
        background: color-mix(in srgb, var(--app-accent-strong) 18%, transparent);
    }

    .permission__grant {
        display: inline-flex;
        align-items: center;
        gap: 0.125rem;
        flex-shrink: 0;
        padding: 0.3125rem 0.5rem 0.3125rem 0.625rem;
        border: 1px solid var(--app-border);
        border-radius: 9999px;
        font-size: 0.75rem;
        font-weight: 600;
        color: var(--app-text);
        background: var(--app-surface);
    }

    .permission__grant:disabled { opacity: 0.5; }
</style>
