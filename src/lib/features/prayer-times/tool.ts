import { Clock } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "prayer-times",
    name: "Prayer Times",
    description: "Today's times for every prayer",
    icon: Clock,
    route: "/prayer-times"
} satisfies ToolDefinition;
