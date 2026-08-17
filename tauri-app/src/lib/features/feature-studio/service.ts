import { Channel, invoke } from "@tauri-apps/api/core";

/**
 * Mirrors the Rust `FeatureBuildResult` in src-tauri/src/lib.rs.
 *
 * `html` is body-only markup, not a whole document -- see document.ts for why, and for what
 * wraps it before it reaches the preview.
 */
export interface FeatureBuildResult {
    decision: "generate" | "decline";
    title: string;
    message: string;
    html: string;
}

/**
 * Sent while the backend works through its model chain. Worth surfacing because a build can
 * legitimately pause: when every model is rate-limited the backend waits before trying again,
 * and an unexplained stall reads as a hang.
 */
export type BuildProgress =
    | { kind: "trying"; attempt: number; total: number }
    | { kind: "waiting"; seconds: number };

// tauri: a Channel is a one-way stream from Rust back into JS, for progress that arrives before
// the command resolves -- a plain invoke() only ever yields one final value
function progressChannel(onProgress?: (update: BuildProgress) => void) {
    const progress = new Channel<BuildProgress>();
    if (onProgress) progress.onmessage = onProgress;
    return progress;
}

// tauri: the Groq key never reaches the frontend. These cross into Rust, which holds the key
// and talks to Groq itself, so nothing secret is present in the WebView to be read out of it.
export function buildFeature(
    prompt: string,
    onProgress?: (update: BuildProgress) => void
): Promise<FeatureBuildResult> {
    return invoke<FeatureBuildResult>("build_feature", { prompt, progress: progressChannel(onProgress) });
}

/**
 * Asks for a revision of an existing tool. The result is a *candidate* -- the caller decides
 * whether it replaces anything, so a bad upgrade costs nothing but the request.
 */
export function upgradeFeature(
    request: string,
    currentHtml: string,
    onProgress?: (update: BuildProgress) => void
): Promise<FeatureBuildResult> {
    return invoke<FeatureBuildResult>("upgrade_feature", {
        request,
        currentHtml,
        progress: progressChannel(onProgress)
    });
}
