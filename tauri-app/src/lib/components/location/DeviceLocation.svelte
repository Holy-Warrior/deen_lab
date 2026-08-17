<script lang="ts">
    import { onMount, untrack, type Snippet } from "svelte";
    import {
        currentCoordinates, networkCoordinates, placeName, type Coordinates, type LocationStatus,
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
        status: LocationStatus;
        refresh: () => void;
    }

    // svelte: fallback is a City (not just Coordinates) so this component can build the
    // "Sydney, Australia"-style label itself -- every caller needs that same string, so it
    // isn't left for each feature to reimplement.
    //
    // onCoordinatesChange is optional, for consumers that need to *react* to a new position
    // (e.g. re-fetching a monthly calendar) rather than just reading it during their own
    // render. It's called from refresh()/selectCity() below -- plain script functions, not
    // template expressions -- because Svelte 5 forbids mutating $state from inside a snippet's
    // rendered output (the {@render children(...)} call is still just read-only rendering).
    let {
        fallback, children, onCoordinatesChange
    }: { fallback: City; children: Snippet<[ChildProps]>; onCoordinatesChange?: (coordinates: Coordinates) => void } = $props();

    // svelte: `untrack` marks this as "read fallback once, for the initial value only" --
    // without it, Svelte warns that $state(fallback) looks like it should stay in sync with the
    // fallback prop, which it deliberately doesn't (refresh()/selectCity own these afterwards)
    let coordinates: Coordinates = $state(untrack(() => fallback));
    let locationName = $state(untrack(() => `${fallback.name}, ${fallback.country}`));
    let failureKind: FailureKind = $state(null);
    let failureMessage = $state("");
    let isLoading = $state(true);

    // design: where the coordinates currently in hand actually came from, in descending order of
    // trust -- a real GPS fix, an approximate city from the IP lookup, or the hard-coded
    // fallback/a manually picked city. Replaces an earlier boolean, which couldn't express the
    // middle rung once network location was added.
    // svelte: the generic form, not `let source: CoordinateSource = $state("fallback")` -- the
    // annotation-on-the-let form makes svelte-check narrow this to the literal "fallback" and
    // then flag every later comparison as impossible. See docs/frontend-architecture.md.
    type CoordinateSource = "gps" | "network" | "fallback";
    let source = $state<CoordinateSource>("fallback");

    let status: LocationStatus = $derived(
        isLoading ? "loading" :
        source === "gps" ? "active" :
        source === "network" ? "approximate" :
        failureKind === "unavailable" ? "unavailable" :
        "inactive"
    );

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

    // design: refresh() can overlap itself -- a slow reverse-geocode lookup from an earlier
    // call could otherwise resolve after a newer refresh() has already moved on, flipping the
    // displayed name back to something stale. Each call captures its own token and checks it's
    // still the current one before touching state that a newer call may have already replaced.
    let requestToken = 0;

    async function refresh() {
        const token = ++requestToken;
        isLoading = true;
        failureKind = null;
        failureMessage = "";

        try {
            const resolvedCoordinates = await currentCoordinates();
            if (token !== requestToken) return;

            coordinates = resolvedCoordinates;
            source = "gps";
            permissionRetryAttempted = false;
            onCoordinatesChange?.(coordinates);
            // shown while the reverse-geocode lookup below is in flight, and kept as-is if it
            // fails -- the coordinates are live and correct either way, only the friendly name
            // is best-effort
            locationName = "Your current location";
            try {
                const resolved = await placeName(coordinates, name => { if (token === requestToken) locationName = name; });
                if (token === requestToken) locationName = resolved;
            } catch {
                // no-op: keep the "Your current location" fallback text set above
            }
        } catch (cause) {
            if (token !== requestToken) return;

            // design: GPS is out, so try the network (IP) lookup before giving up and dropping to
            // the hard-coded city. An approximate city is still a real place the user is near,
            // which beats showing them prayer times for the other side of the world.
            let approximate = false;
            try {
                const network = await networkCoordinates();
                if (token !== requestToken) return;

                coordinates = { latitude: network.latitude, longitude: network.longitude };
                // the lookup already returns a city/country label, so no reverse-geocode needed
                locationName = [network.city, network.country].filter(Boolean).join(", ") || "Approximate location";
                source = "network";
                approximate = true;
            } catch {
                if (token !== requestToken) return;

                coordinates = fallback;
                locationName = `${fallback.name}, ${fallback.country}`;
                source = "fallback";
            }

            onCoordinatesChange?.(coordinates);

            // design: the banner still appears even when the network lookup succeeded -- the
            // underlying problem is real and fixable, and the user deserves to know the times
            // they're reading are approximate. The wording just softens to match.
            const usingApproximate = approximate ? " Using an approximate location from your network." : "";

            if (cause instanceof LocationServicesDisabledError) {
                failureKind = "servicesDisabled";
                failureMessage = `Location is turned off.${usingApproximate}`;
                permissionRetryAttempted = false;
            } else if (cause instanceof LocationPermissionDeniedError) {
                failureKind = "permissionDenied";
                failureMessage = `Location permission was denied.${usingApproximate}`;
                // note: permissionRetryAttempted is deliberately NOT reset here -- it needs to
                // survive repeated permissionDenied outcomes so the button can escalate
            } else if (cause instanceof LocationUnavailableError) {
                failureKind = "unavailable";
                failureMessage = `This device doesn't support automatic location.${usingApproximate}`;
                permissionRetryAttempted = false;
            } else {
                failureKind = "unknown";
                failureMessage = cause instanceof Error ? cause.message : "Unable to get your location.";
                permissionRetryAttempted = false;
            }
        } finally {
            if (token === requestToken) isLoading = false;
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
        source = "fallback";
        failureKind = null;
        failureMessage = "";
        onCoordinatesChange?.(coordinates);
    }
</script>

{#if failureMessage}
    <ErrorBanner message={failureMessage} onRetry={showRetry ? retry : undefined} {retryLabel} />
{/if}

{@render children({ coordinates, locationName, isLoading, status, refresh })}

{#if showCitySelector}
    <section class="surface mx-auto max-w-xl p-5">
        <h2 class="mb-3 font-semibold">Or choose a city</h2>
        <CitySelector onSelect={selectCity} />
    </section>
{/if}
