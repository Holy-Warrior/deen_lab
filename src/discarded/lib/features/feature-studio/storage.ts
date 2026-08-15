export interface GeneratedFeature {
    id: string;
    title: string;
    prompt: string;
    message: string;
    html: string;
    createdAt: string;
}

const storageKey = "deenlab.feature-studio.features";

export function loadFeatures(): GeneratedFeature[] {
    try {
        const raw = localStorage.getItem(storageKey);
        return raw ? JSON.parse(raw) as GeneratedFeature[] : [];
    } catch {
        return [];
    }
}

export function saveFeatures(features: GeneratedFeature[]) {
    localStorage.setItem(storageKey, JSON.stringify(features));
}
