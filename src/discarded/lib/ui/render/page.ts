import { app } from "../kernel/app";
import type { RenderedPage } from "./types";

export function renderPage(
    pageId: string
): RenderedPage | null {

    const page = app.page(pageId);

    if (!page)
        return null;

    return {

        definition: page,

        sections: page.sections
            .map(id => {

                const section =
                    app.section(id);

                if (!section)
                    return null;

                return {

                    definition: section,

                    tools: app.queryTools({

                        collections:
                            section.source?.collections,

                        includeGenerated:
                            section.source?.includeGenerated,

                        sort: "name"

                    })

                };

            })
            .filter(Boolean)

    } as RenderedPage;

}
