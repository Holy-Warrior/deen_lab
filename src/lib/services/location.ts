import { checkPermissions, requestPermissions, getCurrentPosition } from "@tauri-apps/plugin-geolocation";

export interface Coordinates {
    latitude: number;
    longitude: number;
}

// design: three specific location failure modes, so a caller can react differently to each
// (settings-redirect vs. an inline banner, with or without a retry button) instead of lumping
// every failure into one generic message. See DeviceLocation.svelte for the reusable UI flow
// built around these.
export class LocationServicesDisabledError extends Error {}
export class LocationUnavailableError extends Error {}
export class LocationPermissionDeniedError extends Error {}

// tauri: the geolocation plugin's Android side (Geolocation.kt / GeolocationPlugin.kt) rejects
// with plain, literal strings -- "Location disabled." / "Location services are disabled." when
// the OS location toggle is off, "Google Play Services unavailable." when the device has no
// working location provider at all. Matching on those (rather than guessing) is what lets us
// tell these apart reliably.
function classify(cause: unknown): Error {
    const message = cause instanceof Error ? cause.message : typeof cause === "string" ? cause : "";

    if (message.toLowerCase().includes("disabled"))
        return new LocationServicesDisabledError(message);

    if (message.includes("Google Play Services"))
        return new LocationUnavailableError(message);

    return cause instanceof Error ? cause : new Error(message || "Unable to get your location.");
}

// tauri: uses the native OS location stack via tauri-plugin-geolocation (Android-only
// dependency, see docs/backend-api.md) instead of the browser's navigator.geolocation --
// keeps location access inside Tauri's own permission/capability system
// (capabilities/mobile.json) rather than the WebView's separate permission prompt.
export async function currentCoordinates(): Promise<Coordinates> {
    let location;

    try {
        location = (await checkPermissions()).location;
        if (location !== "granted") {
            location = (await requestPermissions(["location"])).location;
        }
    } catch (cause) {
        throw classify(cause);
    }

    if (location !== "granted") {
        throw new LocationPermissionDeniedError("Location access was not granted.");
    }

    try {
        const position = await getCurrentPosition({
            enableHighAccuracy: true,
            timeout: 10_000,
            maximumAge: 300_000
        });

        return { latitude: position.coords.latitude, longitude: position.coords.longitude };
    } catch (cause) {
        throw classify(cause);
    }
}
