<script lang="ts">
    import { onMount } from "svelte";
    import {
        currentCoordinates, qiblaDirection, type QiblaDirection,
        LocationServicesDisabledError, LocationPermissionDeniedError, LocationUnavailableError
    } from "./service";
    import { fallbackLocation, type City } from "./cities";
    import { openLocationSettings, openAppSettings, showToast } from "$lib/services/deviceSettings";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import CitySelector from "./CitySelector.svelte";

    type FailureKind = "servicesDisabled" | "permissionDenied" | "unavailable" | "unknown" | null;

    let direction: QiblaDirection | null = $state(null);
    let locationName = $state(`${fallbackLocation.name}, ${fallbackLocation.country}`);
    let failureKind: FailureKind = $state(null);
    let failureMessage = $state("");
    let isLoading = $state(true);

    // design: Android stops showing its own permission dialog after a prior denial -- calling
    // requestPermissions() again just silently returns denied with no UI at all. This tracks
    // whether we've already tried that once for the *current* denial, so the button can escalate
    // to the app's own Settings screen on the next click instead of retrying something inert.
    let permissionRetryAttempted = $state(false);

    // svelte: $derived keeps these in sync with failureKind automatically -- no separate
    // booleans to remember to reset on every branch of refresh()
    let showRetry = $derived(failureKind === "servicesDisabled" || failureKind === "permissionDenied");
    let retryLabel = $derived(
        failureKind === "servicesDisabled" ? "Go to location settings" :
        failureKind === "permissionDenied" && permissionRetryAttempted ? "Open app settings" :
        "Grant permission"
    );
    let showCitySelector = $derived(
        failureKind === "permissionDenied" || failureKind === "unavailable" || failureKind === "unknown"
    );

    onMount(() => {
        refresh();

        // tauri: opening Android's Location Settings (or the OS permission prompt) backgrounds
        // the app -- there's no callback for "the user came back," so document visibility is
        // what tells us to silently retry instead of leaving a stale error banner up forever
        function handleVisibilityChange() {
            if (document.visibilityState === "visible" && failureKind !== null) {
                refresh();
            }
        }

        document.addEventListener("visibilitychange", handleVisibilityChange);
        return () => document.removeEventListener("visibilitychange", handleVisibilityChange);
    });

    async function refresh() {
        isLoading = true;
        failureKind = null;
        failureMessage = "";

        try {
            direction = qiblaDirection(await currentCoordinates());
            locationName = "Your current location";
            permissionRetryAttempted = false;
        } catch (cause) {
            // design: fall back to a known city either way, then branch on *why* it failed
            direction = qiblaDirection(fallbackLocation);
            locationName = `${fallbackLocation.name}, ${fallbackLocation.country}`;

            if (cause instanceof LocationServicesDisabledError) {
                failureKind = "servicesDisabled";
                failureMessage = "Location is turned off.";
                permissionRetryAttempted = false;
            } else if (cause instanceof LocationPermissionDeniedError) {
                failureKind = "permissionDenied";
                failureMessage = "Location permission was denied.";
                // note: permissionRetryAttempted is deliberately NOT reset here -- it needs to
                // survive repeated permissionDenied outcomes so the button can escalate
            } else if (cause instanceof LocationUnavailableError) {
                failureKind = "unavailable";
                failureMessage = "This device doesn't support automatic location.";
                permissionRetryAttempted = false;
            } else {
                failureKind = "unknown";
                failureMessage = cause instanceof Error ? cause.message : "Unable to get your location.";
                permissionRetryAttempted = false;
            }
        } finally {
            isLoading = false;
        }
    }

    // design: the banner's button means different things depending on the failure and how far
    // we've already gotten -- jump straight to Location Settings when it's off; for a denied
    // permission, try the automatic OS prompt once more first, and only escalate to the app's
    // own Settings screen (with a Toast explaining why) once that's proven not to work anymore
    async function retry() {
        if (failureKind === "servicesDisabled") {
            await openLocationSettings();
            return;
        }

        if (failureKind === "permissionDenied") {
            if (!permissionRetryAttempted) {
                permissionRetryAttempted = true;
                await refresh();
            } else {
                await showToast("Enable Location permission for DeenLab in Settings to use this automatically.");
                await openAppSettings();
            }
            return;
        }

        await refresh();
    }

    function selectCity(city: City) {
        direction = qiblaDirection(city);
        locationName = `${city.name}, ${city.country}`;
        failureKind = null;
        failureMessage = "";
    }
</script>

<svelte:head><title>Qibla · DeenLab</title></svelte:head>

<div class="space-y-5">
    <header>
        <h1 class="text-2xl font-bold">Qibla</h1>
        <p class="mt-1 text-zinc-400">Find the direction of the Kaaba from your location.</p>
    </header>

    {#if failureMessage}
        <ErrorBanner message={failureMessage} onRetry={showRetry ? retry : undefined} {retryLabel} />
    {/if}

    {#if isLoading}
        <p class="text-zinc-400" aria-live="polite">Finding Qibla direction…</p>
    {:else if direction}
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

    {#if showCitySelector}
        <section class="surface mx-auto max-w-xl p-5">
            <h2 class="mb-3 font-semibold">Or choose a city</h2>
            <CitySelector onSelect={selectCity} />
        </section>
    {/if}
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
