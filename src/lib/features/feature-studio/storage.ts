/**
 * Generated features live only on this device, in the WebView's own localStorage.
 *
 * Nothing is uploaded and there is no account: the prompt goes to Groq to be built, and the
 * result comes back here to stay. Clearing the app's data removes them.
 */

/** One revision of a tool. The first is the original build; each upgrade appends another. */
export interface FeatureVersion {
    id: string;
    /** Body-only markup as returned by the model, stored unwrapped so document.ts can evolve. */
    html: string;
    /** What was asked for: the original description for v1, the change requested for later ones. */
    request: string;
    /** The model's own note about what it made. */
    message: string;
    createdAt: string;
}

/**
 * A tool, as a list of versions rather than a single blob of markup.
 *
 * Upgrading never overwrites: a new version is appended and `currentVersionId` moves, so an
 * upgrade that turns out worse than what it replaced can always be stepped back from. Nothing
 * about a version is editable after the fact, which is what makes the history trustworthy.
 */
export interface GeneratedFeature {
    id: string;
    title: string;
    createdAt: string;
    versions: FeatureVersion[];
    currentVersionId: string;
}

/**
 * The version currently in use. Falls back to the newest if `currentVersionId` ever dangles,
 * so a corrupted pointer degrades to "show the latest" instead of rendering nothing.
 */
export function activeVersion(feature: GeneratedFeature): FeatureVersion {
    return feature.versions.find(version => version.id === feature.currentVersionId)
        ?? feature.versions[feature.versions.length - 1];
}

/**
 * A build that was started but never seen through to an outcome.
 *
 * Written before the request goes out and removed once it resolves either way, so it only
 * survives if the app never got the chance to clear it — killed by Android while backgrounded,
 * force-closed, or crashed. Finding one on load therefore means exactly one thing: a build was
 * interrupted, and the user never found out what happened to it.
 */
export interface PendingBuild {
    prompt: string;
    startedAt: string;
}

const storageKey = "deenlab.feature-studio.features";
const pendingKey = "deenlab.feature-studio.pending";

/** Whatever a generated tool has saved, keyed by the tool's id so tools can't read each other. */
const stateKey = (id: string) => `deenlab.feature-studio.state.${id}`;

/**
 * Ceiling on what one tool may keep. A counter or a tracker needs a few hundred bytes; anything
 * approaching this is a runaway loop writing on every frame, and the whole origin shares one
 * localStorage quota, so one tool must not be able to exhaust it for the app.
 */
const maxStateBytes = 32 * 1024;

export type FeatureState = Record<string, string>;

/**
 * Accepts only a flat object of strings, which is exactly what the Storage API stores.
 * The value crosses a postMessage boundary from sandboxed, model-written code, so it is treated
 * as untrusted input rather than as something already known to be the right shape.
 */
export function sanitiseFeatureState(value: unknown): FeatureState | null {
    if (typeof value !== "object" || value === null || Array.isArray(value)) return null;

    const state: FeatureState = {};
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
        if (typeof entry !== "string") return null;
        state[key] = entry;
    }

    if (JSON.stringify(state).length > maxStateBytes) return null;
    return state;
}

export function loadFeatureState(id: string): FeatureState {
    try {
        const raw = localStorage.getItem(stateKey(id));
        return raw ? sanitiseFeatureState(JSON.parse(raw)) ?? {} : {};
    } catch {
        return {};
    }
}

export function saveFeatureState(id: string, state: FeatureState): void {
    try {
        localStorage.setItem(stateKey(id), JSON.stringify(state));
    } catch {
        // out of quota: the tool keeps working from memory for this session, which is a better
        // outcome than interrupting someone mid-dhikr to report a storage problem
    }
}

/** Called when a tool is deleted, so its saved data doesn't outlive it. */
export function clearFeatureState(id: string): void {
    try {
        localStorage.removeItem(stateKey(id));
    } catch {
        // nothing useful to do; the orphaned key is harmless
    }
}

/**
 * Brings one stored entry up to the current shape.
 *
 * Tools saved before versioning existed are flat: `{ id, title, prompt, message, html }`. Those
 * are folded into a single-version history rather than discarded — someone's tools should not
 * vanish because the format moved on.
 */
function migrate(entry: unknown): GeneratedFeature | null {
    const record = entry as Record<string, unknown> | null;
    if (typeof record?.id !== "string") return null;

    if (Array.isArray(record.versions) && record.versions.length > 0 && typeof record.currentVersionId === "string") {
        return record as unknown as GeneratedFeature;
    }

    if (typeof record.html !== "string") return null;

    const createdAt = typeof record.createdAt === "string" ? record.createdAt : new Date().toISOString();
    const version: FeatureVersion = {
        id: crypto.randomUUID(),
        html: record.html,
        request: typeof record.prompt === "string" ? record.prompt : "",
        message: typeof record.message === "string" ? record.message : "",
        createdAt
    };

    return {
        id: record.id,
        title: typeof record.title === "string" ? record.title : "Generated tool",
        createdAt,
        versions: [version],
        currentVersionId: version.id
    };
}

export function loadFeatures(): GeneratedFeature[] {
    try {
        const raw = localStorage.getItem(storageKey);
        if (!raw) return [];

        const parsed: unknown = JSON.parse(raw);
        // guard the shape rather than trusting it -- this data survives app upgrades, so an
        // older or half-written entry shouldn't crash the page on mount
        if (!Array.isArray(parsed)) return [];

        return parsed.map(migrate).filter((entry): entry is GeneratedFeature => entry !== null);
    } catch {
        return [];
    }
}

export function loadPending(): PendingBuild | null {
    try {
        const raw = localStorage.getItem(pendingKey);
        if (!raw) return null;

        const parsed: unknown = JSON.parse(raw);
        return typeof (parsed as PendingBuild)?.prompt === "string" ? (parsed as PendingBuild) : null;
    } catch {
        return null;
    }
}

export function savePending(pending: PendingBuild): void {
    try {
        localStorage.setItem(pendingKey, JSON.stringify(pending));
    } catch {
        // a failed marker only costs the resume offer, never the build itself -- not worth
        // interrupting the user over
    }
}

export function clearPending(): void {
    try {
        localStorage.removeItem(pendingKey);
    } catch {
        // as above
    }
}

/** Returns false when the write failed, so the caller can tell the user honestly. */
export function saveFeatures(features: GeneratedFeature[]): boolean {
    try {
        localStorage.setItem(storageKey, JSON.stringify(features));
        return true;
    } catch {
        // realistically a quota error: each feature is a few KB of markup, so this only
        // happens after a great many of them
        return false;
    }
}
