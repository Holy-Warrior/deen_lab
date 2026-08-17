<script lang="ts">
    import { onMount } from "svelte";
    import { qiblaDirection } from "./service";
    import { fallbackLocation } from "$lib/components/location/cities";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
    import LocationStatusRow from "$lib/components/location/LocationStatusRow.svelte";
    import { startCompass, type CompassMode } from "$lib/services/compass";
    import MosqueIcon from "./MosqueIcon.svelte";

    // design: placement only, computed once and never touched again -- the ring's own live
    // rotation (see .compass__dial below) is what makes the whole set of ticks tilt together
    // as the phone turns, same as a real compass.
    const tickAngles = Array.from({ length: 24 }, (_, i) => i * 15);

    // svelte: null while tauri-plugin-compass hasn't reported back yet (still fine to render --
    // the needle just uses the static bearing until then, same as "none" mode)
    let compassMode: CompassMode | null = $state(null);
    let headingDegrees = $state(0);

    onMount(() => {
        let stop: (() => Promise<void>) | undefined;
        let cancelled = false;

        startCompass(heading => { headingDegrees = heading.degrees; })
            .then(started => {
                if (cancelled) { started.stop(); return; }
                compassMode = started.mode;
                stop = started.stop;
            })
            // design: an invoke failure is treated the same as "no sensor" -- either way the
            // static bearing is still correct, so this only affects whether the needle can
            // follow the phone's rotation, not whether Qibla's direction is shown accurately
            .catch(() => { if (!cancelled) compassMode = "none"; });

        return () => {
            cancelled = true;
            stop?.();
        };
    });
</script>

<svelte:head><title>Qibla · DeenLab</title></svelte:head>

<div class="feature-page space-y-5">
    <header>
        <h1 class="text-2xl font-bold">Qibla</h1>
        <p class="mt-1 text-zinc-400">Find the direction of the Kaaba from your location.</p>
    </header>

    <!-- svelte: DeviceLocation owns the whole acquire/fail/retry/fallback flow and hands back
         just coordinates via this snippet -- Qibla only has to turn coordinates into a bearing -->
    <DeviceLocation fallback={fallbackLocation}>
        {#snippet children({ coordinates, locationName, isLoading, status, refresh })}
            <section class="surface mx-auto max-w-xl p-6 text-center sm:p-8">
                <LocationStatusRow {locationName} {isLoading} {status} onSync={refresh} />

                {#if isLoading}
                    <p class="mt-6 text-zinc-400" aria-live="polite">Finding Qibla direction…</p>
                {:else}
                    {@const direction = qiblaDirection(coordinates)}
                    <!-- design: only .compass__dial's own rotation changes on every sensor tick
                         (dialAngle, from live heading) -- everything inside it (the ticks, the
                         N mark) is plain, static-transform markup that rides along for free via
                         CSS transform inheritance instead of each recomputing its own angle
                         every frame. The needle's rotation is likewise static per render, only
                         changing when the GPS bearing itself changes, not per sensor tick. The
                         mosque badge sits outside .compass__dial entirely -- unlike the tick
                         ring, it reads better staying upright rather than spinning with the dial. -->
                    {@const dialAngle = compassMode && compassMode !== "none" ? (360 - headingDegrees) % 360 : 0}
                    <div class="compass mx-auto my-8" aria-label={`Qibla is ${direction.degrees.toFixed(1)} degrees clockwise from north`}>
                        <!-- design: fixed to the housing, not the dial -- always points "up the
                             screen," i.e. the direction the phone is currently facing, the
                             reference every rotating dial needs so the user knows what to align -->
                        <span class="compass__facing-mark" aria-hidden="true"></span>

                        <div class="compass__dial" style:transform={`rotate(${dialAngle}deg)`}>
                            {#each tickAngles as angle (angle)}
                                <span class="compass__tick" style:transform={`translate(-50%, -50%) rotate(${angle}deg) translateY(-7.9rem)`}></span>
                            {/each}

                            <span class="compass__north" aria-hidden="true">N</span>

                            <svg class="compass__needle" viewBox="0 0 100 100" style:transform={`rotate(${direction.degrees}deg)`} aria-hidden="true">
                                <polygon points="50,8 68,66 50,52 32,66" />
                            </svg>
                        </div>

                        <div class="compass__badge"><MosqueIcon size={40} /></div>
                    </div>
                    <p class="text-3xl font-bold text-emerald-300">{direction.degrees.toFixed(1)}° {direction.label}</p>
                    <p class="mt-2 text-zinc-400">Measured clockwise from North.</p>

                    {#if compassMode === "gyroscope"}
                        <p class="compass-note">Approximate compass — this device has no magnetic sensor, so the needle is estimated from motion only and may drift.</p>
                    {:else if compassMode === "none"}
                        <p class="compass-note">This device doesn't have a compass or motion sensor, so the needle can't follow how you turn — the direction above is still accurate.</p>
                    {/if}
                {/if}
            </section>
        {/snippet}
    </DeviceLocation>
</div>

<style>
    /* design: a plain, borderless caveat -- never a popup -- for the two cases where the
       needle can't (fully) follow the phone's real rotation */
    .compass-note {
        margin-top: 1rem;
        font-size: 0.8125rem;
        color: var(--app-muted);
    }

    /* design: .compass is the fixed housing -- only .compass__dial inside it rotates. Splitting
       them means the live per-tick rotation only ever touches one element; everything drawn
       inside .compass__dial (ticks, needle, mosque badge) rides along for free via ordinary CSS
       transform composition instead of each recomputing its own screen angle every frame. */
    .compass {
        position: relative;
        width: 17rem;
        height: 17rem;
        border: 2px solid var(--app-border);
        border-radius: 999px;
        background: radial-gradient(circle, #18181b 0 60%, #09090b 100%);
        overflow: hidden;
    }

    /* design: fixed to .compass, not .compass__dial -- stays pinned to the top regardless of
       how the dial has rotated, marking "the direction the phone is currently facing" */
    .compass__facing-mark {
        position: absolute;
        top: 0.5rem;
        left: 50%;
        width: 0;
        height: 0;
        border-left: 0.4rem solid transparent;
        border-right: 0.4rem solid transparent;
        border-top: 0.55rem solid var(--app-accent);
        transform: translateX(-50%);
    }

    .compass__dial {
        position: absolute;
        inset: 0;
    }

    .compass__tick {
        position: absolute;
        top: 50%;
        left: 50%;
        width: 2px;
        height: 0.55rem;
        background: color-mix(in srgb, var(--app-text) 55%, transparent);
    }

    /* design: the one labeled reference point on the dial -- sits at local angle 0 (dial-"up"),
       so it rotates along with the ring and always marks true north, the same as a real compass
       rose, without the clutter of the full N/E/S/W/... set */
    .compass__north {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%) translateY(-6.6rem);
        color: var(--app-text);
        font-size: 1rem;
        font-weight: 700;
    }

    /* design: rotates around the dial's own center by design (an SVG's default transform-origin
       is its own box center, which is exactly the dial's center here) -- no manual pivot-point
       math needed. Semi-transparent fill + a lighter stroke gives the glowing-arrow look instead
       of a flat solid triangle. */
    .compass__needle {
        position: absolute;
        inset: 1.75rem;
        fill: color-mix(in srgb, var(--app-accent) 55%, transparent);
        stroke: var(--app-accent);
        stroke-width: 2;
        stroke-linejoin: round;
    }

    /* design: deliberately outside .compass__dial (see the markup comment above) -- stays
       upright and centered instead of spinning with the ring */
    .compass__badge {
        position: absolute;
        top: 50%;
        left: 50%;
        display: grid;
        width: 4.5rem;
        height: 4.5rem;
        place-items: center;
        border-radius: 999px;
        background: var(--app-canvas);
        border: 1px solid var(--app-border);
        color: var(--app-accent);
        transform: translate(-50%, -50%);
    }
</style>
