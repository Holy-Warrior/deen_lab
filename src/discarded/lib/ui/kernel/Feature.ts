import type { NavigationDefinition } from "../models/navigation";
import type { PageDefinition } from "../models/page";
import type { SectionDefinition } from "../models/section";
import type { ToolDefinition } from "../models/tool";

export interface FeatureDefinition {

    id: string;

    name: string;

    navigation?: NavigationDefinition[];

    pages?: PageDefinition[];

    sections?: SectionDefinition[];

    tools?: ToolDefinition[];
}
