export interface ToolDefinition {
    /**
     * Globally unique identifier.
     */
    id: string;

    /**
     * User visible title.
     */
    name: string;

    /**
     * Optional short description.
     */
    description?: string;

    /**
     * Icon identifier.
     * (lucide icon name for now)
     */
    icon: string;

    /**
     * Route to open.
     */
    route: string;

    /**
     * Collections determine where the tool appears.
     *
     * Examples:
     *  - knowledge
     *  - featured
     *  - generated
     *  - favorites
     */
    collections: string[];

    /**
     * Whether this tool is generated
     * by Feature Studio.
     */
    generated?: boolean;

    /**
     * Hide from UI while still existing.
     */
    hidden?: boolean;

    metadata?: Record<string, unknown>;
}
