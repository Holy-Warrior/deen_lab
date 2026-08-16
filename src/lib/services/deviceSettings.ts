import { invoke } from "@tauri-apps/api/core";

// tauri: src-tauri/plugins/device-settings -- a small local (unpublished) plugin, since no
// installed package exposes a way to open native Android settings screens. Plugin commands are
// namespaced as plugin:<name>|<command>, matching the identifier passed to Builder::new(...)
// in that crate's lib.rs.
export function openLocationSettings(): Promise<void> {
    return invoke("plugin:device-settings|open_location_settings");
}

// tauri: the only way to grant a permission once Android stops showing its own request
// dialog (after a prior denial) -- opens this app's "App info" settings screen instead.
export function openAppSettings(): Promise<void> {
    return invoke("plugin:device-settings|open_app_settings");
}

// tauri: a native Android Toast -- the small system hint text shown right before handing
// the user off to a settings screen, so the redirect doesn't feel unexplained.
export function showToast(message: string): Promise<void> {
    return invoke("plugin:device-settings|show_toast", { message });
}
