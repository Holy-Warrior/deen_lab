import type { FeatureDefinition } from "./Feature";
import { Registry } from "./registry";
import { queryTools } from "./query";

export class Application {

    readonly registry = new Registry();

    register(feature: FeatureDefinition) {

        this.registry.register(feature);

        return this;

    }

    page(id: string) {

        return this.registry.page(id);

    }

    section(id: string) {

        return this.registry.section(id);

    }

    navigation() {

        return this.registry.allNavigation();

    }

    pages() {

        return this.registry.allPages();

    }

    sections() {

        return this.registry.allSections();

    }

    tools() {

        return this.registry.allTools();

    }

    queryTools = queryTools;

}
