import type { FeatureDefinition } from "./Feature";
import type { NavigationDefinition } from "../models/navigation";
import type { PageDefinition } from "../models/page";
import type { SectionDefinition } from "../models/section";
import type { ToolDefinition } from "../models/tool";

export class Registry {

    readonly features: FeatureDefinition[] = [];

    readonly pages = new Map<string, PageDefinition>();

    readonly sections = new Map<string, SectionDefinition>();

    readonly tools = new Map<string, ToolDefinition>();

    readonly navigation = new Map<string, NavigationDefinition>();



    register(feature: FeatureDefinition) {

        this.features.push(feature);

        feature.pages?.forEach(page => {
            this.pages.set(page.id, page);
        });

        feature.sections?.forEach(section => {
            this.sections.set(section.id, section);
        });

        feature.tools?.forEach(tool => {
            this.tools.set(tool.id, tool);
        });

        feature.navigation?.forEach(nav => {
            this.navigation.set(nav.id, nav);
        });

        return this;
    }



    page(id: string) {

        return this.pages.get(id);
    }



    tool(id: string) {

        return this.tools.get(id);
    }



    section(id: string) {

        return this.sections.get(id);
    }



    allTools() {

        return [...this.tools.values()];
    }



    allPages() {

        return [...this.pages.values()];
    }



    allSections() {

        return [...this.sections.values()];
    }



    allNavigation() {

        return [...this.navigation.values()];
    }



}
