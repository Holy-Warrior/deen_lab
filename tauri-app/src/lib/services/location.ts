import { checkPermissions, requestPermissions, getCurrentPosition } from "@tauri-apps/plugin-geolocation";
import { invoke } from "@tauri-apps/api/core";
import { loadCacheThenNetwork } from "./apiCache";

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

// design: a coarser status than the error classes above, for UI that just needs "is this the
// device's real, synced location right now?" rather than the specific failure reason -- e.g. a
// status-colored icon button. "loading" and "unavailable" both mean grey/disabled; anything that
// needs the finer-grained reason can still check DeviceLocation.svelte's internal failure state.
//
// "approximate" sits between active and inactive: a real, network-derived position from the
// user's IP (see networkCoordinates below) rather than a GPS fix. It's city-accurate, which is
// close enough for prayer times and a Qibla bearing, but it is NOT a position fix and gets its
// own colour so it can never be mistaken for one.
export type LocationStatus = "loading" | "active" | "approximate" | "inactive" | "unavailable";

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

export interface NetworkLocation extends Coordinates {
    city: string;
    country: string;
}

// tauri: goes through the `ip_location` Rust command (src-tauri/src/ip_location.rs) rather than
// a fetch() from here -- the provider URL, response shape, and success/failure semantics all
// stay in the backend, and it reuses the same shared reqwest client as every other backend
// request. The command already rejects responses with no usable coordinates, so anything that
// resolves here is safe to use directly.
//
// design: strictly a fallback for when currentCoordinates() has already failed. It resolves to
// roughly the right city, never a real position fix -- callers must surface it as approximate.
export async function networkCoordinates(): Promise<NetworkLocation> {
    return invoke<NetworkLocation>("ip_location");
}

interface NominatimAddress {
    city?: string;
    town?: string;
    village?: string;
    municipality?: string;
    county?: string;
    state?: string;
    country?: string;
}

interface NominatimResponse {
    address?: NominatimAddress;
    display_name?: string;
}

function parsePlaceName(data: NominatimResponse): string {
    const address = data.address ?? {};
    // design: OpenStreetMap doesn't tag every place with "city" -- rural/small-town results
    // often only have town/village/county, so fall through the options roughly biggest-to-
    // smallest rather than assuming "city" is always present
    const locality = address.city ?? address.town ?? address.village ?? address.municipality ?? address.county ?? address.state;

    if (locality && address.country) return `${locality}, ${address.country}`;
    return locality ?? address.country ?? data.display_name ?? "Unknown location";
}

// tauri: routed through the same cache-then-network Rust commands as every other network call
// here (docs/backend-api.md) rather than fetch() directly, so a repeated lookup at roughly the
// same spot paints instantly from disk while a fresh one still runs in the background.
// Coordinates are rounded to ~100m so nearby lookups actually share a cache entry instead of
// each decimal-place variation missing it.
export async function placeName(coordinates: Coordinates, onCached: (name: string) => void): Promise<string> {
    const lat = coordinates.latitude.toFixed(3);
    const lon = coordinates.longitude.toFixed(3);
    // accept-language=en: without it, Nominatim returns the name in the locality's own local
    // script/language (e.g. Urdu for a Pakistani city) rather than a consistent Latin-script name
    const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}&zoom=10&addressdetails=1&accept-language=en`;

    return loadCacheThenNetwork(url, parsePlaceName, onCached, {
        // nominatim's usage policy asks for an identifying User-Agent rather than a generic one
        headers: { "User-Agent": "DeenLab/1.0 (Islamic prayer-time and Qibla utility app)" }
    });
}
