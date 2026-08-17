<script lang="ts">
    import { Globe, Locate, LocateFixed, LocateOff } from "@lucide/svelte";
    import type { LocationStatus } from "$lib/services/location";

    // svelte: plain lookup objects instead of a chain of ternaries in the markup -- one place
    // to see all the states side by side, and TypeScript flags it if a LocationStatus case
    // is ever added without updating both here (which is exactly what caught "approximate")
    const statusIcon: Record<LocationStatus, typeof Locate> = {
        loading: Locate,
        unavailable: LocateOff,
        inactive: Locate,
        // design: a globe, not a locate pin -- this position came from the network, and the icon
        // shouldn't imply the device pinned it
        approximate: Globe,
        active: LocateFixed
    };

    const statusLabel: Record<LocationStatus, string> = {
        loading: "Finding your location…",
        unavailable: "This device can't provide your location automatically",
        inactive: "Not using your device's location — tap to sync",
        approximate: "Approximate location from your network — tap to try your device's GPS",
        active: "Using your device's current location — tap to refresh"
    };

    // design: a small, standalone display for DeviceLocation's { locationName, isLoading,
    // status } -- the name on the left, a color-coded status-icon-button on the right that
    // triggers a resync. Deliberately not folded into DeviceLocation itself: this piece is
    // meant to be placed wherever a feature's own layout wants it (e.g. inside a styled card),
    // unlike DeviceLocation's ErrorBanner/CitySelector, which always render at its own top level.
    let { locationName, isLoading, status, onSync }: {
        locationName: string;
        isLoading: boolean;
        status: LocationStatus;
        onSync: () => void;
    } = $props();

    let StatusIcon = $derived(statusIcon[status]);
</script>

<div class="location-status">
    <span>{isLoading ? "Finding your location…" : locationName}</span>
    <button
        class="icon-button status-icon-button"
        data-status={status}
        disabled={status === "loading" || status === "unavailable"}
        onclick={onSync}
        aria-label={statusLabel[status]}
        title={statusLabel[status]}
    >
        <StatusIcon size={20} />
    </button>
</div>
