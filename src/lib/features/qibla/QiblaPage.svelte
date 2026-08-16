<script lang="ts">
    import { qiblaDirection } from "./service";
    import { fallbackLocation } from "$lib/components/location/cities";
    import DeviceLocation from "$lib/components/location/DeviceLocation.svelte";
</script>

<svelte:head><title>Qibla · DeenLab</title></svelte:head>

<div class="space-y-5">
    <header>
        <h1 class="text-2xl font-bold">Qibla</h1>
        <p class="mt-1 text-zinc-400">Find the direction of the Kaaba from your location.</p>
    </header>

    <!-- svelte: DeviceLocation owns the whole acquire/fail/retry/fallback flow and hands back
         just coordinates via this snippet -- Qibla only has to turn coordinates into a bearing -->
    <DeviceLocation fallback={fallbackLocation}>
        {#snippet children({ coordinates, locationName, isLoading, refresh })}
            {#if isLoading}
                <p class="text-zinc-400" aria-live="polite">Finding Qibla direction…</p>
            {:else}
                {@const direction = qiblaDirection(coordinates)}
                <section class="surface mx-auto max-w-xl p-6 text-center sm:p-8">
                    <p class="text-zinc-400">{locationName}</p>
                    <div class="compass mx-auto my-8" style:--qibla-angle={`${direction.degrees}deg`} aria-label={`Qibla is ${direction.degrees.toFixed(1)} degrees clockwise from north`}>
                        <span class="compass__north">N</span>
                        <span class="compass__east">E</span>
                        <span class="compass__south">S</span>
                        <span class="compass__west">W</span>
                        <span class="compass__needle">▲</span>
                        <span class="compass__center">{direction.label}</span>
                    </div>
                    <p class="text-3xl font-bold text-emerald-300">{direction.degrees.toFixed(1)}° {direction.label}</p>
                    <p class="mt-2 text-zinc-400">Measured clockwise from North.</p>
                    <button class="button mt-6" onclick={refresh}>Use my location</button>
                </section>
            {/if}
        {/snippet}
    </DeviceLocation>
</div>

<style>
    .compass {
        position: relative;
        width: 17rem;
        height: 17rem;
        border: 2px solid var(--app-border);
        border-radius: 999px;
        background: radial-gradient(circle, #27272a 0 34%, #18181b 35% 100%);
    }
    .compass__north, .compass__east, .compass__south, .compass__west { position: absolute; color: var(--app-muted); font-weight: 700; }
    .compass__north { top: 1rem; left: 50%; transform: translateX(-50%); }
    .compass__east { right: 1rem; top: 50%; transform: translateY(-50%); }
    .compass__south { bottom: 1rem; left: 50%; transform: translateX(-50%); }
    .compass__west { left: 1rem; top: 50%; transform: translateY(-50%); }
    .compass__needle { position: absolute; left: calc(50% - 0.8rem); top: 1.75rem; width: 1.6rem; color: var(--app-accent); font-size: 2rem; transform-origin: 0.8rem 6.75rem; transform: rotate(var(--qibla-angle)); }
    .compass__center { position: absolute; left: 50%; top: 50%; display: grid; width: 4.75rem; height: 4.75rem; place-items: center; border-radius: 999px; background: var(--app-canvas); font-size: 1.25rem; font-weight: 700; transform: translate(-50%, -50%); }
</style>
