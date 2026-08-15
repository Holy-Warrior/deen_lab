import { app } from "./app";
import type { ToolDefinition } from "../models/tool";

export interface ToolQuery {

    collections?: string[];

    includeGenerated?: boolean;

    hidden?: boolean;

    limit?: number;

    sort?: "name";
}

export function queryTools(
    query: ToolQuery = {}
): ToolDefinition[] {

    let tools = app.tools();

    if (query.hidden !== undefined) {

        tools = tools.filter(tool =>
            tool.hidden === query.hidden
        );

    }

    if (query.collections?.length) {

        tools = tools.filter(tool =>
            tool.collections.some(collection =>
                query.collections!.includes(collection)
            )
        );

    }

    if (!query.includeGenerated) {

        tools = tools.filter(tool =>
            !tool.generated
        );

    }

    switch (query.sort) {

        case "name":

            tools = [...tools].sort((a, b) =>
                a.name.localeCompare(b.name)
            );

            break;

    }

    if (query.limit) {

        tools = tools.slice(0, query.limit);

    }

    return tools;

}
