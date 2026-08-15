export type SectionView =
    | "grid"
    | "list"
    | "carousel"
    | "custom";

export interface CollectionSource {
    collections: string[];
    includeGenerated?: boolean;
}

export interface SectionDefinition {

    /**
     * Unique identifier.
     */
    id: string;

    /**
     * User visible title.
     */
    title: string;

    /**
     * How the renderer should display
     * the tools.
     */
    view: SectionView;

    /**
     * Tool source.
     */
    source?: CollectionSource;

    /**
     * Optional custom component.
     */
    component?: string;

    props?: Record<string, unknown>;
}
