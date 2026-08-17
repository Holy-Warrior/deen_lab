import { HandHeart } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "duas",
    name: "Duas",
    description: "Supplications for everyday moments",
    icon: HandHeart,
    route: "/duas"
} satisfies ToolDefinition;
