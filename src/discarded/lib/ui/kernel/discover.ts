import { app } from "./app";
import type { FeatureDefinition } from "./Feature";

const modules = import.meta.glob(
    "$lib/features/**/feature.ts",
    {
        eager: true
    }
);

let initialized = false;

export function initializeApplication() {

    if (initialized)
        return;

    initialized = true;

    for (const module of Object.values(modules)) {

        const feature = (module as {
            default: FeatureDefinition;
        }).default;

        app.register(feature);

    }

}
