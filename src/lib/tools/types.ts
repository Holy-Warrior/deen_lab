import type { Component } from "svelte";

export interface ToolDefinition {
    /**
     * Globally unique identifier -- also used as the {#each} key.
     */
    id: string;

    /**
     * User-visible title shown on the tile.
     */
    name: string;

    /**
     * Optional one-line description shown under the title.
     */
    description?: string;

    /**
     * A lucide-svelte icon component, e.g. `import { Compass } from "@lucide/svelte"`.
     * Stored as the component itself (not a name string) so there's no lookup
     * table to keep in sync -- every tool file imports exactly the icon it uses.
     */
    icon: Component;

    /**
     * Route the tile links to.
     */
    route: string;
}
