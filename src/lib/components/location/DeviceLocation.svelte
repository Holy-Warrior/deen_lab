<script lang="ts">
    import { onMount, untrack, type Snippet } from "svelte";
    import {
        currentCoordinates, type Coordinates,
        LocationServicesDisabledError, LocationPermissionDeniedError, LocationUnavailableError
    } from "$lib/services/location";
    import { openLocationSettings, openAppSettings, showToast } from "$lib/services/deviceSettings";
    import ErrorBanner from "$lib/components/common/ErrorBanner.svelte";
    import CitySelector from "./CitySelector.svelte";
    import type { City } from "./cities";

    type FailureKind = "servicesDisabled" | "permissionDenied" | "unavailable" | "unknown" | null;

    interface ChildProps {
        coordinates: Coordinates;
        locationName: string;
        isLoading: boolean;
        refresh: () => void;
    }

    // svelte: fallback is a City (not just Coordinates) so this component can build the
    // "Sydney, Australia"-style label itself -- every caller needs that same string, so it
    // isn't left for each feature to reimplement.
    let { fallback, children }: { fallback: City; children: Snippet<[ChildProps]> } = $props();

    // svelte: `untrack` marks this as "read fallback once, for the initial value only" --
    // without it, Svelte warns that $state(fallback) looks like it should stay in sync with the
    // fallback prop, which it deliberately doesn't (refresh()/selectCity own these afterwards)
    let coordinates: Coordinates = $state(untrack(() => fallback));
    let locationName = $state(untrack(() => `${fallback.name}, ${fallback.country}`));
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
            coordinates = await currentCoordinates();
            locationName = "Your current location";
            permissionRetryAttempted = false;
        } catch (cause) {
            // design: fall back to the given location either way, then branch on *why* it failed
            coordinates = fallback;
            locationName = `${fallback.name}, ${fallback.country}`;

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
        coordinates = city;
        locationName = `${city.name}, ${city.country}`;
        failureKind = null;
        failureMessage = "";
    }
</script>

{#if failureMessage}
    <ErrorBanner message={failureMessage} onRetry={showRetry ? retry : undefined} {retryLabel} />
{/if}

{@render children({ coordinates, locationName, isLoading, refresh })}

{#if showCitySelector}
    <section class="surface mx-auto max-w-xl p-5">
        <h2 class="mb-3 font-semibold">Or choose a city</h2>
        <CitySelector onSelect={selectCity} />
    </section>
{/if}
