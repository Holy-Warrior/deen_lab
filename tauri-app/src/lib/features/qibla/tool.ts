import { Compass } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "qibla",
    name: "Qibla",
    description: "Find the direction of the Kaaba",
    icon: Compass,
    route: "/qibla"
} satisfies ToolDefinition;
