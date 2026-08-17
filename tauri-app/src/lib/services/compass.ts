import { Channel, invoke } from "@tauri-apps/api/core";

export type CompassMode = "sensor" | "gyroscope" | "none";

export interface CompassHeading {
    degrees: number;
    /** true when anchored to real (magnetic) north via the magnetometer+accelerometer;
     *  false when estimated by integrating the gyroscope from an arbitrary starting point
     *  (see the Kotlin plugin source, CompassPlugin.kt, for why). */
    absolute: boolean;
}

interface StartResult {
    mode: CompassMode;
}

// tauri: deliberately native (tauri-plugin-compass, Rust + Kotlin) rather than the browser's
// DeviceOrientationEvent -- WebView orientation events are inconsistent across Android OEMs and
// often don't fire at all without extra manifest/feature-policy setup, so raw OS sensor access
// through a real plugin is the only access worth trusting here.
export async function startCompass(onHeading: (heading: CompassHeading) => void): Promise<{ mode: CompassMode; stop: () => Promise<void> }> {
    // tauri: passing a Channel as an invoke arg is how a Tauri plugin streams many events back
    // over one call, instead of the request/response shape of a normal invoke() -- the Kotlin
    // side holds onto it and calls channel.send(...) every time a new sensor reading comes in
    const channel = new Channel<CompassHeading>();
    channel.onmessage = onHeading;

    const result = await invoke<StartResult>("plugin:compass|start", { channel });

    return {
        mode: result.mode,
        stop: () => invoke("plugin:compass|stop")
    };
}
