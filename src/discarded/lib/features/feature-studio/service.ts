import { invoke } from "@tauri-apps/api/core";

export interface FeatureBuildResult {
    decision: "generate" | "decline";
    title: string;
    message: string;
    html: string;
}

export function buildFeature(prompt: string): Promise<FeatureBuildResult> {
    return invoke<FeatureBuildResult>("build_feature", { prompt });
}
