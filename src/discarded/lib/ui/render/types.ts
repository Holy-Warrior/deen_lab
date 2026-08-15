import type { PageDefinition } from "../models/page";
import type { SectionDefinition } from "../models/section";
import type { ToolDefinition } from "../models/tool";

export interface RenderedSection {

    definition: SectionDefinition;

    tools: ToolDefinition[];

}

export interface RenderedPage {

    definition: PageDefinition;

    sections: RenderedSection[];

}
