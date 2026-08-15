export type NavigationLocation =
    | "left"
    | "center"
    | "right";

export interface NavigationDefinition {

    id: string;

    name: string;

    page: string;

    icon: string;

    location: NavigationLocation;

    tooltip?: string;
}
